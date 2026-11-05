Utils = Utils or {}

--------------------------------------------------------------------------------
-- Reading a vehicle row
--
-- The property column is not called the same everywhere, and on QBCore and Qbox
-- the column named `vehicle` holds something else entirely:
--
--   ESX               `vehicle` = the properties as JSON, model inside them
--   QBCore and Qbox   `mods`    = the properties, `vehicle` = the spawn name,
--                                 `hash` = the model hash
--
-- Both helpers work off Config.MySQL, which is filled from msk_core on start.
-- Serverside only, because that is where the rows are read.
--------------------------------------------------------------------------------
function Utils.RowProps(row)
    if type(row) ~= 'table' then return {} end

    local value = row[Config.MySQL.props or 'vehicle']

    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end

    local ok, decoded = pcall(json.decode, value)

    return (ok and type(decoded) == 'table') and decoded or {}
end

-- What the vehicle spawns as. ESX keeps it inside the properties, QBCore and
-- Qbox in their own `hash` column with the spawn name beside it.
function Utils.RowModel(row, props)
    props = props or Utils.RowProps(row)

    local model = props.model

    if model == nil and type(row) == 'table' then
        model = row.hash or row.vehicle
    end

    return tonumber(model) or model
end

-- Normalises the various truthy representations the legacy owned_vehicles.stored column can hold (boolean, 0/1 string, int).
function Utils.GetIsStored(stored)
    if type(stored) == 'boolean' then
        return stored and 1 or 0
    elseif type(stored) == 'string' then
        return stored == '1' and 1 or 0
    elseif type(stored) == 'number' then
        return stored == 1 and 1 or 0
    end
    return 0
end

-- Resolves a normalised heading from either `vector4` (.w) or `{x,y,z,h}` table-style coords used throughout the configs.
function Utils.Heading(coord)
    return coord.w or coord.h or 0.0
end

function Utils.ToVec3(coord)
    return vec3(coord.x, coord.y, coord.z)
end

-- Translation accessor with safe fallback to the key itself.
function Utils.T(key, ...)
    local locale = Translation[Config.Locale] or Translation['en'] or {}
    local value = locale[key]
    if not value then return key end
    if select('#', ...) > 0 then return value:format(...) end
    return value
end

-- Resolves the canonical owner string for a job/society vehicle, honouring
-- Config.useSocietyName. Used by every ownership read path (garage list,
-- impound list, LoadOwned) so the 'society_<job>' convention can never drift.
-- Read at call time, so it works even though utils.lua loads before settings.lua.
function Utils.SocietyOwner(jobName)
    if not jobName or jobName == '' then return nil end
    return Config.useSocietyName and ('society_' .. jobName) or jobName
end

-- Resolves an owner identifier to the character name shown on the
-- "Key from <name>" badge of second-key vehicles. Serverside only, the client
-- never calls this. Return nil for anything you don't want to expose, the badge
-- then falls back to the neutral "Second key" label.
-- Using a framework or a `users` schema that doesn't match this? Rewrite the
-- body. The caller caches the result for a few minutes, so it needn't be cheap.
function Utils.GetOwnerName(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return nil end
    -- Societies are not people, so there is no name to show.
    if identifier:sub(1, 8) == 'society_' then return nil end

    local xPlayer = MSK.GetPlayerFromIdentifier(identifier)
    if xPlayer and xPlayer.getName then
        local name = xPlayer.getName()
        if name and name ~= '' then return name end
    end

    -- SELECT * because the column layout differs between ESX versions.
    local row = MySQL.single.await('SELECT * FROM users WHERE identifier = ?', { identifier })
    if not row then return nil end

    local full = MSK.Trim(('%s %s'):format(row.firstname or '', row.lastname or ''))
    if full ~= '' then return full end
    if row.name and row.name ~= '' then return row.name end
    return nil
end

-- Job / grade matching used by both client and server.
-- `entry.grades` (array of allowed ranks) → exact match against those ranks.
-- Otherwise legacy behaviour: `entry.grade` is the MINIMUM grade.
function Utils.JobMatches(jobsTable, jobName, grade)
    for _, entry in pairs(jobsTable) do
        if entry.job == jobName then
            if type(entry.grades) == 'table' and #entry.grades > 0 then
                for _, g in ipairs(entry.grades) do
                    if g == grade then return true end
                end
            elseif not grade or (entry.grade or 0) <= grade then
                return true
            end
        end
    end
    return false
end

-- Logging helper — respects Config.Debug.
function Utils.Log(code, ...)
    if not Config.Debug then return end
    MSK.Logging(code, ...)
end

-- Backwards-compat globals
function logging(code, ...) Utils.Log(code, ...) end
function getIsStored(stored) return Utils.GetIsStored(stored) end
