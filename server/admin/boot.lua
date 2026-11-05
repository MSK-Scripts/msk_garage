-- Admin dashboard boot: create tables, seed once, load DB into Config, register
-- the command. Runs as its own onResourceStart handler AFTER server/main.lua's
-- (which migrates owned_vehicles), so oxmysql is ready.

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `msk_garage_garages` (
            `id` varchar(60) NOT NULL,
            `label` varchar(120) DEFAULT NULL,
            `data` longtext NOT NULL,
            `enabled` tinyint(1) NOT NULL DEFAULT 1,
            `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `msk_garage_impounds` (
            `id` varchar(60) NOT NULL,
            `label` varchar(120) DEFAULT NULL,
            `data` longtext NOT NULL,
            `enabled` tinyint(1) NOT NULL DEFAULT 1,
            `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `msk_garage_settings` (
            `skey` varchar(80) NOT NULL,
            `svalue` longtext DEFAULT NULL,
            PRIMARY KEY (`skey`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `msk_garage_permissions` (
            `group_name` varchar(80) NOT NULL,
            `perms` longtext DEFAULT NULL,
            PRIMARY KEY (`group_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Private garages (v5.5.0).
    --
    -- `owner` is what makes a garage private, `house_ref` links it to the id
    -- the housing script uses. Both live in columns rather than inside the
    -- `data` JSON: they are looked up per player, and `data` is shipped to
    -- clients on every sync.
    --
    -- Unlike the owned_vehicles migration in server/main.lua this one is safe
    -- to run blindly: our own table, both columns nullable, no MODIFY that
    -- would have to map existing rows onto a stricter definition.
    MySQL.query.await([[
        ALTER TABLE `msk_garage_garages`
            ADD COLUMN IF NOT EXISTS `owner`     varchar(60)  DEFAULT NULL,
            ADD COLUMN IF NOT EXISTS `house_ref` varchar(120) DEFAULT NULL
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `msk_garage_private_access` (
            `garage_id`  varchar(60) NOT NULL,
            `identifier` varchar(60) NOT NULL,
            `granted_by` varchar(60) DEFAULT NULL,
            `granted_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`garage_id`, `identifier`),
            KEY `idx_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    createTables()
    AdminSeed.Run(false)
    AdminStore.LoadAll()
    -- Needs the loaded permission matrix, so it has to run after LoadAll().
    AdminPerms.EnsureAces()
    AdminCommand.Register(Config.adminCommand)

    -- Private-garage access list into RAM. Must run after LoadGarages(), the
    -- reassign helpers look definitions up in Config.Garages.
    Private.Load()

    -- Pull setups only: mirror the housing owners into our own column so the
    -- RAM-based visibility path agrees with the gate. Push setups (housing
    -- calls our exports) find nothing to do here.
    CreateThread(function()
        Wait(5000) -- let the housing resource finish starting
        Private.SyncFromHousing()

        local every = tonumber(Config.HousingSyncMinutes) or 0
        while every > 0 do
            Wait(every * 60000)
            Private.SyncFromHousing()
            every = tonumber(Config.HousingSyncMinutes) or 0
        end
    end)

    -- On a live restart, push the freshly loaded definitions to everyone already
    -- connected so their blips/points match the DB.
    AdminApi.Broadcast()

    print(('^2[msk_garage]^0 Admin dashboard ready — command: ^5/%s^0'):format(Config.adminCommand or 'garageadmin'))
end)
