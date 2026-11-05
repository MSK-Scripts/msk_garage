AdminApi = AdminApi or {}

----------------------------------------------------------------
-- Input sanitisation. NEVER trust client structures — every field is coerced
-- and whitelisted before it touches the DB.
----------------------------------------------------------------
local ID_PATTERN = '^[%w_%-]+$'
local MAX_COORDS = 20
local ALLOWED_TYPES = {
    car = true, truck = true, boat = true, helicopter = true, aircraft = true,
    bike = true, submarine = true, trailer = true, train = true,
}

local function num(v, default)
    local n = tonumber(v)
    if n == nil then return default end
    return n + 0.0
end

local function int(v, default)
    local n = tonumber(v)
    if n == nil then return default end
    return math.floor(n)
end

local function bool(v) return v == true end

local function str(v, max)
    if type(v) ~= 'string' then return nil end
    if #v > (max or 120) then v = v:sub(1, max or 120) end
    return v
end

-- Returns value if it is in the allowed list, otherwise the fallback.
local function oneOf(value, list, fallback)
    if type(value) == 'string' then
        for _, v in ipairs(list) do
            if v == value then return value end
        end
    end
    return fallback
end

local function coord(c)
    if type(c) ~= 'table' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    if not (x and y and z) then return nil end
    if math.abs(x) > 30000 or math.abs(y) > 30000 or z < -2000 or z > 20000 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = num(c.w, 0.0) }
end

local function coordList(list)
    if type(list) ~= 'table' then return nil end
    local out = {}
    for i, c in ipairs(list) do
        if i > MAX_COORDS then break end
        local cc = coord(c)
        if not cc then return nil end
        out[#out + 1] = cc
    end
    if #out == 0 then return nil end
    return out
end

local function typeList(t)
    if type(t) ~= 'table' then return nil end
    local out, seen = {}, {}
    for _, v in ipairs(t) do
        local key = tostring(v):lower()
        if ALLOWED_TYPES[key] and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    if #out == 0 then return nil end
    return out
end

local function jobsTable(j)
    local out = { enable = false, identifier = 'player', ownJob = true, jobs = {} }
    if type(j) ~= 'table' then return out end
    out.enable = bool(j.enable)
    out.identifier = (j.identifier == 'society') and 'society' or 'player'
    out.ownJob = j.ownJob ~= false
    if type(j.jobs) == 'table' then
        for _, e in ipairs(j.jobs) do
            if type(e) == 'table' and type(e.job) == 'string' and #e.job > 0 then
                local entry = { job = e.job:sub(1, 50), grade = int(e.grade, 0) }
                if type(e.grades) == 'table' then
                    local grades, seen = {}, {}
                    for _, g in ipairs(e.grades) do
                        local gi = tonumber(g)
                        if gi then
                            gi = math.floor(gi)
                            if not seen[gi] then seen[gi] = true; grades[#grades + 1] = gi end
                        end
                    end
                    if #grades > 0 then entry.grades = grades end
                end
                out.jobs[#out.jobs + 1] = entry
            end
        end
    end
    return out
end

local function blipTable(b)
    if type(b) ~= 'table' then return { enable = false, id = 524, color = 0, scale = 0.8 } end
    return { enable = bool(b.enable), id = int(b.id, 524), color = int(b.color, 0), scale = num(b.scale, 0.8) }
end

local function pedTable(p)
    if type(p) ~= 'table' then return { enable = false, model = 'csb_trafficwarden', distance = 20.0 } end
    return { enable = bool(p.enable), model = str(p.model, 60) or 'csb_trafficwarden', distance = num(p.distance, 20.0) }
end

local function text3dTable(t)
    if type(t) ~= 'table' then return { enable = false, label = '', size = 0.8 } end
    return { enable = bool(t.enable), label = str(t.label, 80) or '', size = num(t.size, 0.8) }
end

local function markerTable(m)
    if type(m) ~= 'table' then
        return { enable = false, distance = 5.0, type = 27, size = { a = 1.0, b = 1.0, c = 1.0 }, color = { a = 255, b = 255, c = 255, alpha = 100 } }
    end
    local s = type(m.size) == 'table' and m.size or {}
    local c = type(m.color) == 'table' and m.color or {}
    return {
        enable = bool(m.enable),
        distance = num(m.distance, 5.0),
        type = int(m.type, 27),
        size = { a = num(s.a, 1.0), b = num(s.b, 1.0), c = num(s.c, 1.0) },
        color = { a = int(c.a, 255), b = int(c.b, 255), c = int(c.c, 255), alpha = int(c.alpha, 100) },
    }
end

local function feeTable(f)
    if type(f) ~= 'table' then return { enable = false, price = 0, account = 'money' } end
    local price = math.max(0, int(f.price, 0))
    return { enable = price > 0, price = price, account = str(f.account, 30) or 'money' }
end

function AdminApi.SanitizeGarage(input)
    if type(input) ~= 'table' then return nil, 'bad_input' end
    local id = input.id
    if type(id) ~= 'string' or #id == 0 or #id > 60 or not id:match(ID_PATTERN) then return nil, 'bad_id' end
    local types = typeList(input.type); if not types then return nil, 'bad_type' end
    local locs = coordList(input.locations); if not locs then return nil, 'bad_locations' end
    local outs = coordList(input.park_out); if not outs then return nil, 'bad_parkout' end
    return {
        id = id,
        label = str(input.label, 120) or id,
        type = types,
        distance = num(input.distance, 40.0),
        park_dist = num(input.park_dist, 5.0),
        warp = bool(input.warp),
        jobs = jobsTable(input.jobs),
        pedmodel = pedTable(input.pedmodel),
        text3d = text3dTable(input.text3d),
        marker = markerTable(input.marker),
        blip = blipTable(input.blip),
        locations = locs,
        park_out = outs,
    }
end

function AdminApi.SanitizeImpound(input)
    if type(input) ~= 'table' then return nil, 'bad_input' end
    local id = input.id
    if type(id) ~= 'string' or #id == 0 or #id > 60 or not id:match(ID_PATTERN) then return nil, 'bad_id' end
    local types = typeList(input.type); if not types then return nil, 'bad_type' end
    local locs = coordList(input.locations); if not locs then return nil, 'bad_locations' end
    local outs = coordList(input.park_out); if not outs then return nil, 'bad_parkout' end
    return {
        impoundId = id,
        label = str(input.label, 120) or id,
        type = types,
        park_dist = num(input.park_dist, 5.0),
        warp = bool(input.warp),
        pedmodel = pedTable(input.pedmodel),
        text3d = text3dTable(input.text3d),
        marker = markerTable(input.marker),
        blip = blipTable(input.blip),
        locations = locs,
        park_out = outs,
        fee = feeTable(input.fee),
    }
end

-- Validates a settings patch against the editable whitelist and DB integrity.
function AdminApi.SanitizeSettings(patch)
    local out = {}
    if type(patch) ~= 'table' then return out end

    local function allowGarageId(id)
        return type(id) == 'string' and Config.Garages[id] ~= nil
    end

    for _, key in ipairs(AdminPerms.SETTINGS_KEYS) do
        local v = patch[key]
        if v ~= nil then
            if key == 'Locale' then
                local LOCALES = { de = true, en = true, hu = true, fr = true, es = true, pt = true, pl = true }
                if LOCALES[v] then out[key] = v end
            elseif key == 'Parking' then
                if v == 'all' or v == 'specific' then out[key] = v end
            elseif key == 'spawnMode' then
                if v == 'server' or v == 'client' then out[key] = v end
            elseif key == 'Hotkey' then
                out[key] = int(v, Config.Hotkey)
            elseif key == 'FuelTankDefaultVolume' then
                out[key] = num(v, Config.FuelTankDefaultVolume)
            elseif key == 'adminCommand' then
                local cmd = str(v, 32)
                if cmd and cmd:match('^[%w_]+$') then out[key] = cmd end
            elseif key == 'BrandTag' then
                -- Short header badge text. Empty string hides the badge.
                local tag = str(v, 16)
                if tag ~= nil then out[key] = tag:gsub('[%c]', '') end
            elseif key == 'VehicleImages' then
                if type(v) == 'table' then
                    local cur = (type(Config.VehicleImages) == 'table') and Config.VehicleImages or {}
                    out[key] = {
                        enable = bool(v.enable),
                        ext = oneOf(v.ext, AdminPerms.IMAGE_EXTS, cur.ext or AdminPerms.IMAGE_EXTS[1]),
                    }
                end
            elseif key == 'DefaultGarages' then
                if type(v) == 'table' then
                    local cur = Config.DefaultGarages or {}
                    out[key] = {
                        land = allowGarageId(v.land) and v.land or cur.land,
                        sea  = allowGarageId(v.sea) and v.sea or cur.sea,
                        air  = allowGarageId(v.air) and v.air or cur.air,
                    }
                end
            elseif key == 'TargetSystem' then
                if type(v) == 'table' then
                    local cur = Config.TargetSystem or {}
                    out[key] = {
                        enable = bool(v.enable),
                        script = oneOf(v.script, AdminPerms.TARGET_SCRIPTS, cur.script or AdminPerms.TARGET_SCRIPTS[1]),
                    }
                end
            elseif key == 'VehicleKeys' then
                if type(v) == 'table' then
                    local cur = Config.VehicleKeys or {}
                    out[key] = {
                        enable = bool(v.enable),
                        script = oneOf(v.script, AdminPerms.VEHICLEKEY_SCRIPTS, cur.script or AdminPerms.VEHICLEKEY_SCRIPTS[1]),
                    }
                end
            elseif key == 'Theme' then
                if type(v) == 'table' then
                    local cur = (type(Config.Theme) == 'table') and Config.Theme or AdminPerms.DEFAULT_THEME
                    local theme = {}
                    for _, ck in ipairs(AdminPerms.THEME_KEYS) do
                        local hex = type(v[ck]) == 'string' and v[ck]:match('^#%x%x%x%x%x%x$')
                        theme[ck] = hex or cur[ck] or AdminPerms.DEFAULT_THEME[ck]
                    end
                    out[key] = theme
                end
            else
                -- Boolean flags: Debug, VersionChecker, defaultTextUI,
                -- enableImpound, parkoutWithKey, needEnoughMoney, useSocietyName
                out[key] = bool(v)
            end
        end
    end
    return out
end

----------------------------------------------------------------
-- Bootstrap / sync payloads
----------------------------------------------------------------
function AdminApi.SettingsPayload()
    local out = {}
    for _, key in ipairs(AdminPerms.SETTINGS_KEYS) do out[key] = Config[key] end
    out.dashboardGroups = Config.dashboardGroups or {}
    return out
end

function AdminApi.GaragesArray()
    local out = {}
    for _, def in pairs(Config.Garages) do out[#out + 1] = def end
    return out
end

function AdminApi.ImpoundsArray()
    local out = {}
    for _, def in pairs(Config.Impounds) do
        local c = {}
        for k, v in pairs(def) do c[k] = v end
        c.id = def.impoundId
        out[#out + 1] = c
    end
    return out
end

function AdminApi.GroupsArray()
    local out = {}
    -- admin first, always present + protected
    out[#out + 1] = { name = 'admin', protected = true, perms = AdminPerms.AllPerms() }
    for name, matrix in pairs(AdminStore.perms) do
        if name ~= 'admin' then
            out[#out + 1] = { name = name, protected = false, perms = matrix }
        end
    end
    return out
end

-- All framework jobs + their grades, for the dashboard's job/grade pickers.
-- msk_core answers this for every framework and hands the grades over already
-- normalised and sorted, so the per-framework grade handling is gone. It used
-- to read ESX directly and stayed empty on QBCore and Qbox.
function AdminApi.JobsList()
    local out = {}

    for name, job in pairs(MSK.GetJobs() or {}) do
        local grades = {}
        for _, g in pairs(job.grades or {}) do
            local gnum = tonumber(g.grade) or 0
            grades[#grades + 1] = { grade = math.floor(gnum), label = g.label or g.name or tostring(gnum) }
        end
        table.sort(grades, function(a, b) return a.grade < b.grade end)
        out[#out + 1] = { name = name, label = job.label or name, grades = grades }
    end
    table.sort(out, function(a, b) return (a.label or a.name):lower() < (b.label or b.name):lower() end)
    return out
end

function AdminApi.VehicleCounts()
    local rows = MySQL.query.await(('SELECT `garage`, COUNT(*) AS c FROM `%s` GROUP BY `garage`'):format(Config.MySQL.table)) or {}
    local out = {}
    for _, r in ipairs(rows) do out[r.garage] = r.c end
    return out
end

function AdminApi.BuildBootstrap(src)
    return {
        locale = Config.Locale,
        perms = AdminPerms.GetPlayerPerms(src),
        permKeys = AdminPerms.PERMS,
        garages = AdminApi.GaragesArray(),
        impounds = AdminApi.ImpoundsArray(),
        settings = AdminApi.SettingsPayload(),
        groups = AdminApi.GroupsArray(),
        suggestedGroups = AdminPerms.SUGGESTED_GROUPS,
        counts = AdminApi.VehicleCounts(),
        jobsList = AdminApi.JobsList(),
        jobGaragePolicy = (type(Config.JobGaragePolicy) == 'table') and Config.JobGaragePolicy or {},
        scripts = {
            target = AdminPerms.TARGET_SCRIPTS,
            vehicleKeys = AdminPerms.VEHICLEKEY_SCRIPTS,
        },
    }
end

-- The settings a CLIENT needs. Same as SettingsPayload minus dashboardGroups:
-- the client never reads that key, and the names of the admin groups are the
-- one part of this payload that is not already visible in the world anyway.
function AdminApi.ClientSettingsPayload()
    local out = AdminApi.SettingsPayload()
    out.dashboardGroups = nil
    return out
end

-- Every garage without an owner. Used for players we cannot resolve to an
-- identifier yet (still connecting), so they at least get the public world.
function AdminApi.PublicGarages()
    local out = {}
    for id, def in pairs(Config.Garages) do
        if not Private.IsPrivate(def) then
            -- A garage that was private once keeps its house_ref after the
            -- owner is cleared, so strip it here too.
            out[id] = def.house_ref and Private.ForClient(def) or def
        end
    end
    return out
end

-- Push the definitions (garages/impounds/settings) to the clients so they
-- rebuild blips/points live without a restart.
--
-- Private garages make this per player: a client must only ever learn about the
-- private garages it may actually use, otherwise every house on the server
-- would show up as a blip for everyone. Servers without a single private
-- garage keep the old single broadcast.
function AdminApi.Broadcast()
    local impounds = Config.Impounds
    local settings = AdminApi.ClientSettingsPayload()

    local hasPrivate = false
    for _, def in pairs(Config.Garages) do
        if Private.IsPrivate(def) then hasPrivate = true; break end
    end

    if not hasPrivate then
        TriggerClientEvent('msk_garage:syncDefinitions', -1, {
            garages = Config.Garages,
            impounds = impounds,
            settings = settings,
        })
        return
    end

    local fallback = AdminApi.PublicGarages()
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local xPlayer = src and MSK.GetPlayer(src)
        TriggerClientEvent('msk_garage:syncDefinitions', src, {
            garages  = xPlayer and Private.GaragesFor(xPlayer.identifier) or fallback,
            impounds = impounds,
            settings = settings,
        })
    end
end

-- Same payload for a single player. Used after granting or revoking access so
-- the change shows up without waiting for the next full broadcast.
function AdminApi.PushTo(src)
    local xPlayer = src and MSK.GetPlayer(src)
    TriggerClientEvent('msk_garage:syncDefinitions', src, {
        garages  = xPlayer and Private.GaragesFor(xPlayer.identifier) or AdminApi.PublicGarages(),
        impounds = Config.Impounds,
        settings = AdminApi.ClientSettingsPayload(),
    })
end

local function ok(src) return { ok = true, data = AdminApi.BuildBootstrap(src) } end
local function fail(err) return { ok = false, err = err } end

----------------------------------------------------------------
-- Callbacks (client -> server via MSK.Trigger). Every mutation is gated.
----------------------------------------------------------------

-- Public: client pulls the authoritative definitions on join (no perm needed —
-- this is the same garage data the client already ships in its config).
MSK.Register('msk_garage:admin:getDefinitions', function(src)
    -- Filtered per player: private garages only reach the players who may use
    -- them. Everything else here is world-visible data the client needs to
    -- build its blips and points.
    local xPlayer = src and MSK.GetPlayer(src)
    return {
        garages = xPlayer and Private.GaragesFor(xPlayer.identifier) or AdminApi.PublicGarages(),
        impounds = Config.Impounds,
        settings = AdminApi.ClientSettingsPayload(),
    }
end)

MSK.Register('msk_garage:admin:bootstrap', function(src)
    if not AdminPerms.CanOpen(src) then return fail('no_permission') end
    return ok(src)
end)

-- Garages -------------------------------------------------------
MSK.Register('msk_garage:admin:garage:save', function(src, data)
    local def, err = AdminApi.SanitizeGarage(type(data) == 'table' and data.garage or nil)
    if not def then return fail(err or 'bad_input') end

    local existing = Config.Garages[def.id] ~= nil
    if not AdminPerms.Has(src, existing and 'garage.edit' or 'garage.create') then return fail('no_permission') end

    MySQL.insert.await(
        'INSERT INTO `msk_garage_garages` (`id`, `label`, `data`, `enabled`) VALUES (?, ?, ?, 1) ' ..
        'ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `data` = VALUES(`data`)',
        { def.id, def.label, json.encode(def) }
    )
    AdminStore.LoadGarages()

    -- The private-garage columns are only touched when the payload actually
    -- carries them. Leaving them out MUST keep the garage as it is: the
    -- dashboard has no owner field yet, so a plain edit of a private garage
    -- would otherwise silently turn it public and dump every parked car into
    -- the default garage.
    local raw = (type(data) == 'table' and type(data.garage) == 'table') and data.garage or {}
    if raw.owner ~= nil then
        Private.SetOwner(def.id, type(raw.owner) == 'string' and raw.owner:sub(1, 60) or nil)
    end
    if raw.house_ref ~= nil then
        Private.SetHouseRef(def.id, type(raw.house_ref) == 'string' and raw.house_ref or nil)
    end

    AdminApi.Broadcast()
    return ok(src)
end)

MSK.Register('msk_garage:admin:garage:delete', function(src, data)
    if not AdminPerms.Has(src, 'garage.delete') then return fail('no_permission') end
    local id = type(data) == 'table' and data.id or nil
    if type(id) ~= 'string' or not Config.Garages[id] then return fail('not_found') end

    -- Default-garage protection: must be replaced first.
    for _, gid in pairs(Config.DefaultGarages or {}) do
        if gid == id then return fail('is_default_garage') end
    end

    -- Reassign vehicles to the matching category's default garage.
    local cat = AdminPerms.CategoryForType((Config.Garages[id].type or {})[1])
    local replacement = (Config.DefaultGarages or {})[cat] or Config.DefaultGarage
    if not Config.Garages[replacement] then replacement = Config.DefaultGarage end

    MySQL.update.await(('UPDATE `%s` SET `garage` = ? WHERE `garage` = ?'):format(Config.MySQL.table), { replacement, id })
    MySQL.query.await('DELETE FROM `msk_garage_garages` WHERE `id` = ?', { id })
    -- Access rows would otherwise outlive the garage and come back to life if
    -- the same id is ever created again.
    MySQL.query.await('DELETE FROM `msk_garage_private_access` WHERE `garage_id` = ?', { id })
    Private.access[id] = nil
    AdminStore.LoadGarages()
    AdminApi.Broadcast()
    return ok(src)
end)

-- Impounds ------------------------------------------------------
MSK.Register('msk_garage:admin:impound:save', function(src, data)
    local def, err = AdminApi.SanitizeImpound(type(data) == 'table' and data.impound or nil)
    if not def then return fail(err or 'bad_input') end

    local existing = Config.Impounds[def.impoundId] ~= nil
    if not AdminPerms.Has(src, existing and 'impound.edit' or 'impound.create') then return fail('no_permission') end

    MySQL.insert.await(
        'INSERT INTO `msk_garage_impounds` (`id`, `label`, `data`, `enabled`) VALUES (?, ?, ?, 1) ' ..
        'ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `data` = VALUES(`data`)',
        { def.impoundId, def.label, json.encode(def) }
    )
    AdminStore.LoadImpounds()
    AdminApi.Broadcast()
    return ok(src)
end)

MSK.Register('msk_garage:admin:impound:delete', function(src, data)
    if not AdminPerms.Has(src, 'impound.delete') then return fail('no_permission') end
    local id = type(data) == 'table' and data.id or nil
    if type(id) ~= 'string' or not Config.Impounds[id] then return fail('not_found') end

    MySQL.query.await('DELETE FROM `msk_garage_impounds` WHERE `id` = ?', { id })
    AdminStore.LoadImpounds()
    AdminApi.Broadcast()
    return ok(src)
end)

-- Settings ------------------------------------------------------
MSK.Register('msk_garage:admin:settings:save', function(src, data)
    if not AdminPerms.Has(src, 'settings.manage') then return fail('no_permission') end
    if type(data) ~= 'table' or type(data.settings) ~= 'table' then return fail('bad_input') end

    local clean = AdminApi.SanitizeSettings(data.settings)
    for k, v in pairs(clean) do
        MySQL.insert.await(
            'INSERT INTO `msk_garage_settings` (`skey`, `svalue`) VALUES (?, ?) ' ..
            'ON DUPLICATE KEY UPDATE `svalue` = VALUES(`svalue`)',
            { k, json.encode(v) }
        )
    end

    local oldCmd = Config.adminCommand
    AdminStore.LoadSettings()
    if Config.adminCommand ~= oldCmd then AdminCommand.Register(Config.adminCommand) end
    AdminApi.Broadcast()
    return ok(src)
end)

-- Permissions ---------------------------------------------------
local function normGroup(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower():gsub('^group%.', '')
    if not name:match(ID_PATTERN) then return nil end
    return name
end

MSK.Register('msk_garage:admin:perms:saveGroup', function(src, data)
    if not AdminPerms.Has(src, 'permissions.manage') then return fail('no_permission') end
    local name = normGroup(type(data) == 'table' and data.name or nil)
    if not name then return fail('bad_name') end
    if AdminPerms.IsProtected(name) then return fail('protected') end
    if AdminPerms.IsBlacklisted(name) then return fail('blacklisted') end

    local matrix = {}
    local incoming = type(data) == 'table' and type(data.perms) == 'table' and data.perms or {}
    for _, key in ipairs(AdminPerms.PERMS) do
        matrix[key] = incoming[key] == true
    end

    MySQL.insert.await(
        'INSERT INTO `msk_garage_permissions` (`group_name`, `perms`) VALUES (?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `perms` = VALUES(`perms`)',
        { name, json.encode(matrix) }
    )
    AdminStore.LoadPermissions()
    AdminPerms.EnsureAces()
    AdminPerms.Invalidate()
    return ok(src)
end)

MSK.Register('msk_garage:admin:perms:deleteGroup', function(src, data)
    if not AdminPerms.Has(src, 'permissions.manage') then return fail('no_permission') end
    local name = normGroup(type(data) == 'table' and data.name or nil)
    if not name then return fail('bad_name') end
    if AdminPerms.IsProtected(name) then return fail('protected') end

    MySQL.query.await('DELETE FROM `msk_garage_permissions` WHERE `group_name` = ?', { name })
    AdminStore.LoadPermissions()
    AdminPerms.Invalidate()
    return ok(src)
end)

MSK.Register('msk_garage:admin:perms:dashboardGroups', function(src, data)
    if not AdminPerms.Has(src, 'permissions.manage') then return fail('no_permission') end
    local list, seen = {}, {}
    if type(data) == 'table' and type(data.groups) == 'table' then
        for _, g in ipairs(data.groups) do
            local name = normGroup(g)
            if name and not AdminPerms.IsBlacklisted(name) and not AdminPerms.IsProtected(name) and not seen[name] then
                seen[name] = true
                list[#list + 1] = name
            end
        end
    end
    MySQL.insert.await(
        'INSERT INTO `msk_garage_settings` (`skey`, `svalue`) VALUES (?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `svalue` = VALUES(`svalue`)',
        { 'dashboardGroups', json.encode(list) }
    )
    AdminStore.LoadSettings()
    AdminPerms.EnsureAces()
    AdminPerms.Invalidate()
    return ok(src)
end)

-- Job garages -------------------------------------------------
-- Per-job whitelist/blacklist of PUBLIC garages the job's vehicles may use.
-- Stored as a single settings row 'JobGaragePolicy' (job -> {mode, garages}).
MSK.Register('msk_garage:admin:jobGarages:save', function(src, data)
    if not AdminPerms.Has(src, 'settings.manage') then return fail('no_permission') end
    if type(data) ~= 'table' or type(data.job) ~= 'string' or #data.job == 0 then return fail('bad_input') end
    local job = data.job:sub(1, 50)

    -- The job must be a real framework job (when the job list is resolvable).
    local jobs = MSK.GetJobs() or {}
    if next(jobs) ~= nil and not jobs[job] then return fail('unknown_job') end

    local mode = (data.mode == 'blacklist') and 'blacklist' or 'whitelist'
    local garages, seen = {}, {}
    if type(data.garages) == 'table' then
        for _, gid in ipairs(data.garages) do
            -- Only PUBLIC canonical garages (exist + jobs disabled) are valid here.
            local g = type(gid) == 'string' and Config.Garages[gid]
            if g and not (g.jobs and g.jobs.enable) and not seen[gid] then
                seen[gid] = true
                garages[#garages + 1] = gid
            end
        end
    end

    local map = {}
    if type(Config.JobGaragePolicy) == 'table' then
        for k, v in pairs(Config.JobGaragePolicy) do map[k] = v end
    end
    if mode == 'whitelist' and #garages == 0 then
        map[job] = nil -- no access -> drop the entry to keep the map clean
    else
        map[job] = { mode = mode, garages = garages }
    end

    MySQL.insert.await(
        'INSERT INTO `msk_garage_settings` (`skey`, `svalue`) VALUES (?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `svalue` = VALUES(`svalue`)',
        { 'JobGaragePolicy', json.encode(map) }
    )
    AdminStore.LoadSettings()
    return ok(src)
end)

-- Best-effort validation that an ACE group exists (FiveM can't enumerate groups).
MSK.Register('msk_garage:admin:perms:validateGroup', function(src, data)
    if not AdminPerms.Has(src, 'permissions.manage') then return fail('no_permission') end
    local name = normGroup(type(data) == 'table' and data.name or nil)
    if not name then return { ok = true, valid = false } end
    if AdminPerms.IsBlacklisted(name) then return { ok = true, valid = false, blacklisted = true } end

    -- A group that was never used before has no ace object yet, so the membership
    -- check below would come back empty for everyone. Register it first and give
    -- the command buffer a frame to catch up.
    AdminPerms.EnsureAce(name)
    Wait(0)

    local found = false
    for _, pid in ipairs(GetPlayers()) do
        if AdminPerms.PlayerInGroup(tonumber(pid), name) then found = true; break end
    end
    -- exists=false only means "no online player currently in it" — still allowed.
    return { ok = true, valid = true, exists = found }
end)
