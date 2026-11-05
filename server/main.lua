-- OneSync is a hard requirement: CreateVehicleServerSetter only works when one of the OneSync modes is active. 
local function assertOneSync()
    local mode = GetConvar('onesync', 'off')
    if mode == 'off' then
        local banner =
            '\n^1=============================================================\n' ..
            '^1[msk_garage]^0 ^3OneSync is OFF.^0\n' ..
            '^3msk_garage v4 requires OneSync (`set onesync on` or `set onesync infinity`).\n' ..
            '^3The resource will not function correctly with OneSync disabled.\n' ..
            '^1=============================================================^0\n'
        print(banner)
        return false
    end
    print(('^2[msk_garage]^0 OneSync mode: ^5%s^0'):format(mode))
    return true
end

-- Resource boot: idempotent column migration + locale parity check
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    assertOneSync()

    local defaultGarage = tostring(Config.DefaultGarage or 'A'):gsub("'", "''")

    -- Every statement here runs against the table of the running framework:
    -- owned_vehicles on ESX, player_vehicles on QBCore and Qbox. The columns
    -- are added additively, so an existing table keeps every row it has. On
    -- QBCore and Qbox `garage` already exists, ADD COLUMN IF NOT EXISTS simply
    -- leaves it alone.
    local vehicleTable = Config.MySQL.table

    MySQL.query.await(([[
        ALTER TABLE `%s`
            ADD COLUMN IF NOT EXISTS `garage`       varchar(60) NOT NULL DEFAULT '%s',
            ADD COLUMN IF NOT EXISTS `fuel`         SMALLINT NULL DEFAULT 100,
            ADD COLUMN IF NOT EXISTS `name`         varchar(60) DEFAULT NULL,
            ADD COLUMN IF NOT EXISTS `isFav`        TINYINT NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `deformations` longtext DEFAULT NULL
    ]]):format(vehicleTable, defaultGarage))

    -- Clean the column BEFORE it is switched to NOT NULL varchar(60). Servers that
    -- already had a `garage` column (v3, or a foreign garage script) keep it exactly
    -- as it was: nullable, sometimes wider than 60 chars. MODIFY has to map those
    -- rows onto the new definition, and with STRICT_TRANS_TABLES (MariaDB default
    -- since 10.2.4) that aborts with "Data truncated for column 'garage' at row N"
    -- instead of coercing silently. That is why the error only hits some servers.
    MySQL.update.await(([[
        UPDATE `%s`
           SET `garage` = CASE
               WHEN `garage` IS NULL OR `garage` = '' THEN '%s'
               ELSE LEFT(`garage`, 60)
           END
         WHERE `garage` IS NULL OR `garage` = '' OR CHAR_LENGTH(`garage`) > 60
    ]]):format(vehicleTable, defaultGarage))

    -- The default must be an inline SQL literal, not a bound parameter: placeholders
    -- are not allowed in a DDL DEFAULT clause, and newer oxmysql versions no longer
    -- substitute named placeholders (@name / :name) at all, which left
    -- `DEFAULT @default` as an unset user variable (NULL) and made MariaDB reject the
    -- NOT NULL column with "Column 'garage' cannot be null".
    MySQL.query.await(
        ("ALTER TABLE `%s` MODIFY `garage` varchar(60) NOT NULL DEFAULT '%s'"):format(vehicleTable, defaultGarage)
    )

    -- Migrate the fuel column from the old TINYINT (max 127) to SMALLINT so msk_fuel
    -- tanks larger than 100 L are stored without being capped. Idempotent.
    MySQL.query.await(('ALTER TABLE `%s` MODIFY `fuel` SMALLINT NULL DEFAULT 100'):format(vehicleTable))

    -- Warn loudly when locales drift (v3 had DE missing the rename keys).
    local de, en = Translation['de'] or {}, Translation['en'] or {}
    for k in pairs(de) do
        if en[k] == nil then print(('^3[msk_garage] Locale drift: key "%s" missing in EN^0'):format(k)) end
    end
    for k in pairs(en) do
        if de[k] == nil then print(('^3[msk_garage] Locale drift: key "%s" missing in DE^0'):format(k)) end
    end
end)

-- Job change: drop the player's own vehicles of the job they just left.
-- msk_core turns every framework's job event into this one, so it fires on ESX,
-- QBCore and Qbox alike; `esx:setJob` only ever arrived on ESX. It is
-- serverside-local (AddEventHandler, never a net event, so a client cannot fake
-- it) and fires on every job AND grade change.
AddEventHandler('msk_core:setJob', function(playerId, job, lastJob)
    if not Config.deleteJobVehiclesOnJobChange then return end
    if type(job) ~= 'table' or type(lastJob) ~= 'table' then return end

    -- Grade change inside the same job is not "leaving" it.
    if not lastJob.name or lastJob.name == '' or lastJob.name == job.name then return end

    local xPlayer = MSK.GetPlayer(playerId)
    if not xPlayer then return end

    Vehicles.PurgeJobVehicles(xPlayer.identifier, lastJob.name)
end)

RegisterServerEvent('msk_garage:renameVehicle', function(plate, nickname)
    Vehicles.Rename(source, plate, nickname)
end)

RegisterServerEvent('msk_garage:toggleFav', function(plate, isFav)
    Vehicles.ToggleFav(source, plate, isFav)
end)

RegisterServerEvent('msk_garage:deleteVehicle', function(netId, plate, model)
    Vehicles.DeleteEntity(source, netId, plate, model)
end)

local debugLastAt = {}
RegisterServerEvent('msk_garage:debug', function(...)
    local src = source
    local now = GetGameTimer()
    if debugLastAt[src] and now - debugLastAt[src] < 1000 then return end
    debugLastAt[src] = now
    Utils.Log('debug', ...)
end)
AddEventHandler('playerDropped', function() debugLastAt[source] = nil end)

VEHICLE_TYPE_MAP_DEFAULTS = {
    car        = 'automobile',
    truck      = 'automobile',
    automobile = 'automobile',
    boat       = 'boat',
    helicopter = 'heli',
    heli       = 'heli',
    aircraft   = 'plane',
    plane      = 'plane',
    airplane   = 'plane',
    bike       = 'bike',
    motorcycle = 'bike',
    motorbike  = 'bike',
    submarine  = 'submarine',
    submarinecar = 'submarine',
    trailer    = 'trailer',
    train      = 'train',
}
