AdminSeed = AdminSeed or {}

----------------------------------------------------------------
-- vector4 -> plain {x,y,z,w}. The configs use the vector4 type which json.encode
-- can't serialise; the rest of the codebase reads coords via .x/.y/.z/.w so a
-- plain table is a drop-in replacement.
----------------------------------------------------------------
local function vecToTable(v)
    return {
        x = (v.x or 0.0) + 0.0,
        y = (v.y or 0.0) + 0.0,
        z = (v.z or 0.0) + 0.0,
        w = (v.w or v.h or 0.0) + 0.0,
    }
end

local function coordList(list)
    local out = {}
    for i, c in ipairs(list or {}) do out[i] = vecToTable(c) end
    return out
end

-- Shallow copy of a garage/impound def with coord lists converted for storage.
-- Nested config tables (jobs/blip/pedmodel/marker/text3d/fee) contain no
-- vectors, so sharing the references is safe for json.encode.
local function defForStorage(def)
    local copy = {}
    for k, v in pairs(def) do copy[k] = v end
    copy.locations = coordList(def.locations)
    copy.park_out = coordList(def.park_out)
    return copy
end

local function isSeeded()
    local row = MySQL.single.await("SELECT `skey` FROM `msk_garage_settings` WHERE `skey` = '__seeded__'")
    return row ~= nil
end

----------------------------------------------------------------
-- One-time import of the static config into the DB.
----------------------------------------------------------------
function AdminSeed.Run(force)
    if not force and isSeeded() then return false end

    -- Garages
    for id, def in pairs(Config.Garages) do
        local clean = defForStorage(def)
        MySQL.insert.await(
            'INSERT INTO `msk_garage_garages` (`id`, `label`, `data`, `enabled`) VALUES (?, ?, ?, 1) ' ..
            'ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `data` = VALUES(`data`)',
            { id, def.label, json.encode(clean) }
        )
    end

    -- Impounds
    for id, def in pairs(Config.Impounds) do
        local clean = defForStorage(def)
        MySQL.insert.await(
            'INSERT INTO `msk_garage_impounds` (`id`, `label`, `data`, `enabled`) VALUES (?, ?, ?, 1) ' ..
            'ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `data` = VALUES(`data`)',
            { id, def.label, json.encode(clean) }
        )
    end

    -- Settings (editable whitelist)
    for _, key in ipairs(AdminPerms.SETTINGS_KEYS) do
        if Config[key] ~= nil then
            MySQL.insert.await(
                'INSERT INTO `msk_garage_settings` (`skey`, `svalue`) VALUES (?, ?) ' ..
                'ON DUPLICATE KEY UPDATE `svalue` = VALUES(`svalue`)',
                { key, json.encode(Config[key]) }
            )
        end
    end
    -- dashboardGroups is permission-managed but still persisted as a setting.
    MySQL.insert.await(
        'INSERT INTO `msk_garage_settings` (`skey`, `svalue`) VALUES (?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `svalue` = VALUES(`svalue`)',
        { 'dashboardGroups', json.encode(Config.dashboardGroups or {}) }
    )

    -- Default permission groups: admin = all, mod = view-only.
    local adminPerms = AdminPerms.AllPerms()
    local modPerms = { ['garage.view'] = true, ['impound.view'] = true }
    MySQL.insert.await(
        'INSERT INTO `msk_garage_permissions` (`group_name`, `perms`) VALUES (?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `perms` = VALUES(`perms`)',
        { 'admin', json.encode(adminPerms) }
    )
    MySQL.insert.await(
        'INSERT INTO `msk_garage_permissions` (`group_name`, `perms`) VALUES (?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `perms` = VALUES(`perms`)',
        { 'mod', json.encode(modPerms) }
    )

    -- Mark as seeded.
    MySQL.insert.await(
        'INSERT INTO `msk_garage_settings` (`skey`, `svalue`) VALUES (?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `svalue` = VALUES(`svalue`)',
        { '__seeded__', json.encode(os.time()) }
    )

    print('^2[msk_garage]^0 Admin seed complete (garages/impounds/settings/permissions imported into DB).')
    return true
end
