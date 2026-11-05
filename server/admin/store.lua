AdminStore = AdminStore or {}

-- In-memory permission matrix: [group_name] = { [perm] = true }
AdminStore.perms = {}
AdminStore.ready = false

----------------------------------------------------------------
-- JSON helpers
----------------------------------------------------------------
local function jdecode(s)
    if type(s) ~= 'string' then return false end
    local ok, v = pcall(json.decode, s)
    if not ok then return false end
    return true, v
end
AdminStore.Decode = jdecode

local function isEnabled(v)
    return tonumber(v) ~= 0
end

----------------------------------------------------------------
-- Load definitions from the DB into Config.* (the runtime source of truth used
-- by validation.lua, garages.lua, blips.lua, points.lua — all unchanged).
----------------------------------------------------------------
function AdminStore.LoadGarages()
    Config.Garages = {}
    local rows = MySQL.query.await(
        'SELECT `id`, `label`, `data`, `enabled`, `owner`, `house_ref` FROM `msk_garage_garages`') or {}
    for _, row in ipairs(rows) do
        if isEnabled(row.enabled) then
            local ok, def = jdecode(row.data)
            if ok and type(def) == 'table' then
                def.id = row.id
                def.label = row.label or def.label
                -- Private-garage columns. Kept out of `data` on purpose: they
                -- are per-player lookups and `data` goes to clients on sync.
                -- Empty strings become nil so IsPrivate() stays a plain check.
                def.owner     = (row.owner ~= '' and row.owner) or nil
                def.house_ref = (row.house_ref ~= '' and row.house_ref) or nil
                Config.Garages[row.id] = def
            end
        end
    end
end

function AdminStore.LoadImpounds()
    Config.Impounds = {}
    local rows = MySQL.query.await('SELECT `id`, `label`, `data`, `enabled` FROM `msk_garage_impounds`') or {}
    for _, row in ipairs(rows) do
        if isEnabled(row.enabled) then
            local ok, def = jdecode(row.data)
            if ok and type(def) == 'table' then
                def.impoundId = row.id
                def.label = row.label or def.label
                Config.Impounds[row.id] = def
            end
        end
    end
end

function AdminStore.LoadSettings()
    local rows = MySQL.query.await('SELECT `skey`, `svalue` FROM `msk_garage_settings`') or {}
    for _, row in ipairs(rows) do
        if row.skey ~= '__seeded__' then
            local ok, v = jdecode(row.svalue)
            if ok then Config[row.skey] = v end
        end
    end
    -- Keep the legacy single default in sync with the land category.
    if type(Config.DefaultGarages) == 'table' then
        Config.DefaultGarage = Config.DefaultGarages.land or Config.DefaultGarage
    end
end

function AdminStore.LoadPermissions()
    AdminStore.perms = {}
    local rows = MySQL.query.await('SELECT `group_name`, `perms` FROM `msk_garage_permissions`') or {}
    for _, row in ipairs(rows) do
        local ok, p = jdecode(row.perms)
        AdminStore.perms[row.group_name] = (ok and type(p) == 'table') and p or {}
    end
end

function AdminStore.LoadAll()
    AdminStore.LoadGarages()
    AdminStore.LoadImpounds()
    AdminStore.LoadSettings()
    AdminStore.LoadPermissions()
    AdminStore.ready = true
end
