Garages = Garages or {}

-- May a vehicle of `jobName` be parked in/out at the PUBLIC (civilian) garage
-- `garageId`? Driven by the per-job policy managed in the dashboard's Job-Garages
-- tab (Config.JobGaragePolicy[jobName] = { mode = 'whitelist'|'blacklist',
-- garages = { id,... } }). No policy → no public access (default).
function Garages.JobAllowedAtPublicGarage(jobName, garageId)
    if not jobName or jobName == '' or not garageId then return false end
    local policy = (Config.JobGaragePolicy or {})[jobName]
    if type(policy) ~= 'table' then return false end

    local listed = false
    for _, gid in ipairs(policy.garages or {}) do
        if gid == garageId then listed = true; break end
    end

    if policy.mode == 'blacklist' then
        return not listed
    end
    -- whitelist (default): only the explicitly listed garages
    return listed
end

-- Safely decode a JSON column that may be NULL, empty, or corrupt. owned_vehicles
-- is a shared ESX table written by other resources, so one malformed row must not
-- abort the whole list build with an uncaught json.decode error.
local function safeDecode(value)
    if type(value) ~= 'string' or value == '' then return nil end
    local ok, decoded = pcall(json.decode, value)
    if not ok then return nil end
    return decoded
end

local function mapRow(row)
    return {
        -- Default to {} so downstream `vehicle.model` access never nil-derefs.
        -- The properties sit in `vehicle` on ESX and in `mods` on QBCore and
        -- Qbox, where `vehicle` holds the spawn name instead.
        vehicle     = Utils.RowProps(row),
        plate       = row.plate,
        -- Honour the configurable column mapping, same as the queries do.
        type        = row[Config.MySQL.type],
        job         = row[Config.MySQL.job],
        stored      = row[Config.MySQL.stored],
        fuel        = row.fuel,
        garage      = row.garage,
        name        = row.name,
        isFav       = Utils.GetIsStored(row.isFav),
        deformation = safeDecode(row.deformations),
    }
end

-- Builds the dynamic WHERE clause for the main owned_vehicles query.
-- Returns (sql, params, ownerForKeyLookup).
local function buildQuery(xPlayer, garage, category, jobEntry)
    local synonyms = Classes.TypeSynonyms(category)
    local placeholders = {}
    local params = {}
    for _, syn in ipairs(synonyms) do
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = syn
    end

    local where = { ('`%s` IN (%s)'):format(Config.MySQL.type, table.concat(placeholders, ', ')) }
    local ownerForKeys = xPlayer.identifier

    if jobEntry then
        -- A job vehicle may be owned by the player's identifier OR by the society
        -- string (resolved via the shared helper so it matches LoadOwned and the
        -- impound list regardless of Config.useSocietyName). Emit an OR-list
        -- instead of a single equality so neither convention silently returns 0.
        local owners = { xPlayer.identifier }
        if garage.jobs.identifier == 'society' then
            local society = Utils.SocietyOwner(jobEntry.job)
            if society and society ~= xPlayer.identifier then owners[#owners + 1] = society end
            ownerForKeys = society or xPlayer.identifier
        end

        local ownerPlaceholders = {}
        for _, owner in ipairs(owners) do
            ownerPlaceholders[#ownerPlaceholders + 1] = '?'
            table.insert(params, owner)
        end
        table.insert(where, ('`%s` IN (%s)'):format(Config.MySQL.owner, table.concat(ownerPlaceholders, ', ')))
        table.insert(where, ('`%s` = ?'):format(Config.MySQL.job)); table.insert(params, jobEntry.job)
    else
        table.insert(where, ('`%s` = ?'):format(Config.MySQL.owner)); table.insert(params, xPlayer.identifier)
    end

    if Config.Parking == 'specific' and garage.id then
        table.insert(where, '`garage` = ?'); table.insert(params, garage.id)
    end

    local sql = ('SELECT * FROM `%s` WHERE '):format(Config.MySQL.table) .. table.concat(where, ' AND ')
    return sql, params, ownerForKeys
end

-- Owner names for the "Schlüssel von <Name>" badge. Resolved through
-- Utils.GetOwnerName (shared/utils.lua) and cached for a few minutes:
-- opening a garage re-runs the whole list build, and a character name changes
-- roughly never — but it CAN change, so this is a TTL cache, not a permanent one.
local NAME_TTL = 300000 -- 5 min
local nameCache = {}

function Garages.OwnerName(identifier)
    if not Config.showKeyOwnerName then return nil end
    if type(identifier) ~= 'string' or identifier == '' then return nil end

    local hit = nameCache[identifier]
    local now = GetGameTimer()
    if hit and now - hit.at < NAME_TTL then return hit.name end

    local ok, name = pcall(Utils.GetOwnerName, identifier)
    if not ok then
        Utils.Log('error', 'Utils.GetOwnerName failed:', tostring(name))
        name = nil
    end
    if type(name) ~= 'string' or name == '' then name = nil end

    nameCache[identifier] = { name = name, at = now }
    return name
end

local function appendKeyedVehicles(out, xPlayer, garage, category, ownedPlates, jobFilter, seen)
    if not Config.VehicleKeys.enable then return end

    local keys = Keys.GetKeys(xPlayer)
    Utils.Log('debug', ('[keys] %s returned %d key(s)'):format(Config.VehicleKeys.script, #keys))
    if #keys == 0 then return end

    seen = seen or {}
    for _, plate in ipairs(ownedPlates) do seen[plate] = true end

    for _, k in ipairs(keys) do
        local plate = k.plate
        if plate and not seen[plate] then
            seen[plate] = true

            local synonyms = Classes.TypeSynonyms(category)
            local placeholders = {}
            -- Match the plate three ways: raw, trimmed, and space-stripped on both
            -- sides (REPLACE). FiveM plates are 8 chars and often space-padded; the
            -- key script may hand back a trimmed plate that the owner query never
            -- has to care about (it matches on `owner`), but the keyed query lives
            -- or dies on plate equality. Without the REPLACE branch a padded DB
            -- plate vs a trimmed key plate silently matches nothing.
            local trimmed = MSK.Trim(plate, true)
            local params = { plate, trimmed, trimmed }
            for _, syn in ipairs(synonyms) do
                placeholders[#placeholders + 1] = '?'
                params[#params + 1] = syn
            end

            local sql = ('SELECT * FROM `%s` WHERE (`plate` = ? OR `plate` = ? OR REPLACE(`plate`, \' \', \'\') = ?) AND `'):format(Config.MySQL.table)
                .. Config.MySQL.type .. '` IN (' .. table.concat(placeholders, ', ') .. ')'

            if garage and Config.Parking == 'specific' and garage.id then
                sql = sql .. ' AND `garage` = ?'; table.insert(params, garage.id)
            end

            if jobFilter then
                sql = sql .. ' AND `' .. Config.MySQL.job .. '` = ?'
                table.insert(params, jobFilter)
            end

            local row = MySQL.single.await(sql, params)
            if row then
                Utils.Log('debug', 'Vehicle via key:', plate)
                -- Mark it as a key vehicle so the UI can badge it. The name is only
                -- resolved when the vehicle actually belongs to somebody else —
                -- your own car reached the list through the owner query anyway.
                local mapped = mapRow(row)
                mapped.keyed = true
                local rowOwner = row[Config.MySQL.owner]

                if rowOwner and rowOwner ~= xPlayer.identifier then
                    mapped.keyOwner = Garages.OwnerName(rowOwner)
                end
                out[#out + 1] = mapped
            else
                Utils.Log('debug', ('[keys] no matching owned_vehicles row for key plate "%s" (garage=%s, category=%s)')
                    :format(plate, tostring(garage and garage.id), category))
            end
        end
    end
end

function Garages.ForImpound(xPlayer, impound)
    local out = {}
    local seen = {} -- dedup across categories whose synonyms overlap (car/truck -> automobile)
    local jobName = xPlayer.job and xPlayer.job.name

    -- Acceptable owner strings: the player's identifier, the bare job name (legacy)
    -- and the society-prefixed owner resolved via the shared helper. Without the
    -- society form, impound listing missed society vehicles that the garage list
    -- showed (inconsistent owner resolution across read paths).
    local owners = { xPlayer.identifier }
    if jobName and jobName ~= '' then
        owners[#owners + 1] = jobName
        local society = Utils.SocietyOwner(jobName)
        if society and society ~= jobName then owners[#owners + 1] = society end
    end

    for _, category in ipairs(impound.type) do
        local params = {}
        local ownerPlaceholders = {}
        for _, owner in ipairs(owners) do
            ownerPlaceholders[#ownerPlaceholders + 1] = '?'
            params[#params + 1] = owner
        end

        local placeholders = {}
        for _, syn in ipairs(Classes.TypeSynonyms(category)) do
            placeholders[#placeholders + 1] = '?'
            params[#params + 1] = syn
        end

        local rows = MySQL.query.await(
            ('SELECT * FROM `%s` WHERE `%s` IN ('):format(Config.MySQL.table, Config.MySQL.owner) .. table.concat(ownerPlaceholders, ', ') .. ') AND `'
                .. Config.MySQL.type .. '` IN (' .. table.concat(placeholders, ', ') .. ')',
            params
        )

        local ownedPlates = {}
        for _, row in ipairs(rows) do
            ownedPlates[#ownedPlates + 1] = row.plate
            if Utils.GetIsStored(row[Config.MySQL.stored]) == 0 and not seen[row.plate] then
                seen[row.plate] = true
                out[#out + 1] = mapRow(row)
            end
        end

        if Config.parkoutWithKey then
            appendKeyedVehicles(out, xPlayer, nil, category, ownedPlates, nil, seen)
        end
    end

    -- Flag everything AdvancedParking still tracks so the UI can show it as locked.
    -- Purely cosmetic — the park-out itself is refused server-side as well.
    if Impound.ChecksAdvancedParking() then
        local plates = {}
        for _, v in ipairs(out) do plates[#plates + 1] = v.plate end

        local blocked = Impound.AdvancedParkedPlates(plates)
        for _, v in ipairs(out) do
            if blocked[v.plate] then v.apBlocked = true end
        end
    end

    return out
end

function Garages.ForGarage(xPlayer, garage)
    local out = {}
    local seen = {} -- dedup across categories whose synonyms overlap (car/truck -> automobile)

    if garage.jobs.enable then
        for _, jobEntry in ipairs(garage.jobs.jobs) do
            if not garage.jobs.ownJob or jobEntry.job == xPlayer.job.name then
                for _, category in ipairs(garage.type) do
                    local sql, params = buildQuery(xPlayer, garage, category, jobEntry)
                    local rows = MySQL.query.await(sql, params)

                    local plates = {}
                    for _, row in ipairs(rows) do
                        plates[#plates + 1] = row.plate
                        if not seen[row.plate] then
                            seen[row.plate] = true
                            Utils.Log('debug', 'Job vehicle:', row.plate, '@', row[Config.MySQL.job])
                            out[#out + 1] = mapRow(row)
                        end
                    end

                    appendKeyedVehicles(out, xPlayer, garage, category, plates, jobEntry.job, seen)
                end
            end
        end
        return out
    end

    for _, category in ipairs(garage.type) do
        local sql, params = buildQuery(xPlayer, garage, category, nil)
        local rows = MySQL.query.await(sql, params)

        local plates = {}
        for _, row in ipairs(rows) do
            local rowJob = row[Config.MySQL.job]
            -- Civilian vehicles always belong here; job vehicles only when the
            -- job's policy allows this specific public garage. The owner filter in
            -- buildQuery already restricts these rows to the player's own
            -- (identifier-owned) vehicles.
            if not rowJob or rowJob == '' or rowJob == Config.MySQL.civ
                or Garages.JobAllowedAtPublicGarage(rowJob, garage.id) then
                plates[#plates + 1] = row.plate
                if not seen[row.plate] then
                    seen[row.plate] = true
                    Utils.Log('debug', 'Civilian vehicle:', row.plate)
                    out[#out + 1] = mapRow(row)
                end
            end
        end

        appendKeyedVehicles(out, xPlayer, garage, category, plates, nil, seen)
    end

    return out
end

function Garages.GetNameFav(plate, trimmedPlate)
    local row = MySQL.single.await(
        ('SELECT `name`, `isFav`, `%s` AS vehtype FROM `%s` WHERE `plate` = ? OR `plate` = ?'):format(Config.MySQL.type, Config.MySQL.table),
        { plate, trimmedPlate }
    )
    if not row then return nil end
    return { name = row.name, isFav = row.isFav, type = row.vehtype }
end

function Garages.IsOwnedByPlayer(xPlayer, plate, jobs, model, garageId)
    if not plate then return false end
    local trimmed = MSK.Trim(plate, true)

    local isOwner, hasKey, isJobOwned, wrongJob = false, false, false, nil

    if not jobs.enable or jobs.identifier == 'player' then
        hasKey = Keys.HasKey(xPlayer, trimmed, model)

        local row = MySQL.single.await(
            ('SELECT * FROM `%s` WHERE `%s` = ? AND (`plate` = ? OR `plate` = ?)'):format(Config.MySQL.table, Config.MySQL.owner),
            { xPlayer.identifier, plate, trimmed }
        )

        if row then
            local jobOnRow = row[Config.MySQL.job]
            if not jobs.enable and (not jobOnRow or jobOnRow == '' or jobOnRow == Config.MySQL.civ) then
                isOwner = true
            elseif not jobs.enable and jobOnRow and jobOnRow ~= '' and Garages.JobAllowedAtPublicGarage(jobOnRow, garageId) then
                -- Public garage whose policy allows this job. The row is already
                -- bound to the player's identifier by the query above.
                isOwner = true
            elseif jobs.enable and Utils.JobMatches(jobs.jobs, jobOnRow) then
                isOwner = true
            else
                wrongJob = jobOnRow or 'not defined'
            end
        end
    elseif jobs.identifier == 'society' then
        -- Don't trust job membership alone: bind the plate to an actual society
        -- row of the player's job before declaring ownership, otherwise this
        -- returns true (and leaks GetNameFav) for any plate to any matching-job
        -- player. Mirrors the row check in Vehicles.LoadOwned.
        local jobName = xPlayer.job and xPlayer.job.name
        if jobName and Utils.JobMatches(jobs.jobs, jobName) then
            local society = Utils.SocietyOwner(jobName)
            local row = MySQL.single.await(
                ('SELECT `%s` AS rowjob, `%s` AS owner FROM `%s` WHERE `plate` = ? OR `plate` = ?'):format(Config.MySQL.job, Config.MySQL.owner, Config.MySQL.table),
                { plate, trimmed }
            )
            if row and (row.rowjob == jobName or (society and row.owner == society)) then
                isJobOwned = true
            end
        end
    end

    if wrongJob then
        Utils.Log('debug', ('Vehicle %s belongs to job %s — refused here'):format(trimmed, wrongJob))
    end

    if isOwner or hasKey or isJobOwned then
        return true, Garages.GetNameFav(plate, trimmed)
    end
    return false
end

-- Used by external scripts to ask "where does this car live?". 
-- Returns garage id + first marker location.
function Garages.GetVehicleGarage(plate)
    local garageId = Config.DefaultGarage
    local coords = Config.Garages[garageId] and Config.Garages[garageId].locations[1] or nil

    local row = MySQL.single.await(
        ('SELECT `garage` FROM `%s` WHERE `plate` = ?'):format(Config.MySQL.table),
        { MSK.Trim(plate, true) }
    )

    if row and row.garage and Config.Garages[row.garage] then
        garageId = row.garage
        coords = Config.Garages[garageId].locations[1]
    end

    return garageId, coords
end
