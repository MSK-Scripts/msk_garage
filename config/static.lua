Config = Config or {}

--[[============================================================
    STATIC / CODE CONFIGURATION  (not managed by DB / dashboard)

    Code hooks, adapters and column mappings. The dashboard and the
    database never touch this file. Changes apply on restart.
============================================================]]--

----------------------------------------------------------------
-- luxu_admin (dashboard access). Its v2 staff groups are internal and not ACE
-- principals, so IsPlayerAceAllowed cannot see them. When enabled, a player's
-- group is also resolved through the getPlayerStaffGroup export and matched
-- against your dashboard groups by name ('admin' always means full access).
Config.LuxuAdmin = {
    enable = 'auto',          -- 'auto' (on when the resource runs) | true | false
    resource = 'luxu_admin',  -- change if you renamed it
    requireDuty = false,      -- true = the staff member must be ON DUTY

    -- Optional: luxu_admin group -> dashboard group. Unmapped names are matched
    -- lowercased as they are.
    groupMap = {
        -- ['owner'] = 'admin',
    },
}
----------------------------------------------------------------
-- Notification (client AND server)
Config.Notification = function(source, message, typ)
    if IsDuplicityVersion() then
        MSK.Notification(source, { title = 'MSK Garage', message = message, type = typ })
    else
        MSK.Notification({ title = 'MSK Garage', message = message, type = typ })
    end
end
----------------------------------------------------------------
-- NPC voice lines (interaction peds)
Config.npcVoice = {
    enable = true,
    inRange = 5.0,
    outRange = 5.0,
}
----------------------------------------------------------------
-- TextUI adapter (clientside)
Config.openTextUI = function(coloredText, uncoloredText)
    MSK.TextUI.Show({ key = 'E', text = coloredText })
end

Config.closeTextUI = function()
    MSK.TextUI.Hide()
end
----------------------------------------------------------------
-- Table and column mapping for the framework's owned-vehicle table.
--
-- Filled from msk_core, which knows the layout of the running framework:
-- `owned_vehicles` keyed by `owner` on ESX, `player_vehicles` keyed by
-- `citizenid` on QBCore and Qbox, where the stored flag is `state` rather than
-- `stored`. Everything in this resource reads the table name from here, so
-- there is exactly one place that has to be right.
--
-- The values below are only the fallback for a server where msk_core cannot
-- answer (STANDALONE); they match ESX.
Config.MySQL = {
    table = 'owned_vehicles',
    owner = 'owner',
    props = 'vehicle',
    type = 'type',
    job = 'job',
    stored = 'stored',
    civ = 'civ',
    storedIn = 1,
    storedOut = 0,
}

-- Resolved right here, not inside a thread: the first query can run before a
-- thread would have gotten around to it, and it would then use the ESX fallback
-- on a Qbox server. msk_core starts before this resource, so the export answers.
if IsDuplicityVersion() then
    local schema = MSK.VehicleStore.GetSchema()

    if schema then
        Config.MySQL.table = schema.table
        Config.MySQL.owner = schema.owner
        Config.MySQL.props = schema.props
        Config.MySQL.type = schema.type
        Config.MySQL.job = schema.job
        Config.MySQL.stored = schema.stored
        Config.MySQL.storedIn = schema.storedIn
        Config.MySQL.storedOut = schema.storedOut
    end
end
----------------------------------------------------------------
-- Default garage id for an owned_vehicles.type value. Reads the DB-managed
-- Config.DefaultGarages at call time.
function Config.GetDefaultGarage(vehicleType)
    local cat = AdminPerms.CategoryForType(vehicleType)
    return Config.DefaultGarages[cat] or Config.DefaultGarages.land
end
----------------------------------------------------------------
-- AdvancedParking is auto-detected, there is no config flag.
Config.UsesAdvancedParking = function()
    return GetResourceState('AdvancedParking') == 'started'
end
----------------------------------------------------------------
-- Fuel adapter (clientside ONLY). Using msk_fuel? Leave as is. Another fuel
-- script? Swap in its get/set.
Config.UsesMskFuel = function()
    return GetResourceState('msk_fuel') == 'started'
end

-- Max tank volume (liters) for a model with no spawned vehicle (stored list).
Config.GetModelMaxFuel = function(model)
    if Config.UsesMskFuel() then
        local override = exports.msk_fuel:Config().PetrolTankVolume[model]
        if override then return override + 0.0 end
    end
    return Config.FuelTankDefaultVolume
end

Config.SetFuel = function(vehicle, fuel)
    if Config.UsesMskFuel() then
        exports.msk_fuel:SetVehicleFuel(vehicle, fuel)
        return
    end
    Entity(vehicle).state.fuel = fuel -- replace this with your fuel script exports
end

Config.GetFuel = function(vehicle)
    if Config.UsesMskFuel() then
        return exports.msk_fuel:GetVehicleFuel(vehicle)
    end
    return Entity(vehicle).state.fuel -- replace this with your fuel script exports
end
----------------------------------------------------------------
-- Lock adapter (uses the keys script's export when it is running)
Config.LockVehicle = function(vehicle, locked)
    if GetResourceState('msk_vehiclekeys') == 'started' then
        exports.msk_vehiclekeys:SetVehicleLockState(vehicle, locked)
    else
        SetVehicleDoorsLocked(vehicle, locked and 2 or 1)
    end
end
----------------------------------------------------------------
-- Vehicle images from an export or a CDN (client AND server)
--
-- Only used while Settings -> Vehicle Images is enabled in the dashboard.
-- The UI tries the URLs in order and shows the first one that loads, then the
-- local `vehicle_images/<model>.<ext>` folder, then the vehicle-class icon.
--
-- CDN link with tokens: {model} = spawn name lowercase, {MODEL} = uppercase,
-- {hash} = model hash. nil = no CDN. Default is the MSK Scripts CDN.
Config.VehicleImageCdn = 'https://cdn.msk-scripts.de/vehicles/{model}.png'

local function fillTokens(url, model, hash)
    return (url:gsub('{model}', model):gsub('{MODEL}', model:upper()):gsub('{hash}', tostring(hash)))
end

-- Returns one URL, a list of URLs, or nil for a vehicle model.
-- `model` = spawn name (lowercase), `hash` = model hash.
Config.GetVehicleImage = function(model, hash)
    local urls = {}

    -- JG Vehicle Studio: the stored photo first, then its configured fallbacks.
    if GetResourceState('jg-vehiclestudio') == 'started' then
        local ok, image, fallbacks = pcall(function()
            return exports['jg-vehiclestudio']:getImage(model)
        end)
        if ok then
            if type(image) == 'string' and image ~= '' then urls[#urls + 1] = image end
            if type(fallbacks) == 'table' then
                for _, url in ipairs(fallbacks) do urls[#urls + 1] = url end
            end
        end
    end

    if type(Config.VehicleImageCdn) == 'string' and Config.VehicleImageCdn ~= '' then
        urls[#urls + 1] = fillTokens(Config.VehicleImageCdn, model, hash)
    end

    return urls
end
----------------------------------------------------------------
--[[============================================================
    PRIVATE GARAGES  (v5.5.0)

    A garage becomes private the moment it has an owner. Nothing here needs
    changing for that: an admin can hand a garage to a player with
    /garageowner, and the player shares it with /privategarage.

    Everything in this block lives in static.lua ON PURPOSE. It is adapter
    and hook configuration, so it is NOT stored in the database and NOT
    editable from the dashboard, exactly like Config.LuxuAdmin above.
    Changes apply on restart.
============================================================]]--

-- Command names.
Config.privateAccessCommand = 'privategarage' -- player: share their own garage
Config.privateOwnerCommand  = 'garageowner'   -- admin: assign an owner (needs garage.edit)

-- 0 = unlimited. Caps how many people one owner can let into a single garage.
Config.PrivateGarageMaxMembers = 10

-- Look and feel of garages created by a housing script through
-- exports.msk_garage:CreatePrivateGarage(). A housing script only supplies
-- coordinates and the owner, everything cosmetic comes from here, otherwise
-- no third-party script could ever build a valid garage definition.
Config.PrivateGarageTemplate = {
    label     = 'Privatgarage',
    type      = { 'car', 'bike' },
    distance  = 40.0,
    park_dist = 5.0,
    warp      = false,
    pedmodel  = { enable = false, model = 'csb_trafficwarden', distance = 20.0 },
    text3d    = { enable = false, label = '~g~Garage', size = 0.8 },
    marker    = { enable = true, distance = 5.0, type = 27,
                  size = { a = 1.0, b = 1.0, c = 1.0 },
                  color = { a = 255, b = 255, c = 255 } },
    -- House blip, small and green. Only ever sent to players who may use it.
    blip      = { enable = true, id = 357, color = 2, scale = 0.7 },
}

----------------------------------------------------------------
--[[============================================================
    HOUSING INTEGRATION  (optional)

    Only needed when the housing script should stay the source of truth for
    who owns a house. Without it private garages still work, their owner is
    then whatever msk_garage was told (dashboard command or the exports).

    THE BETTER WAY IS PUSH: let the housing script call our exports when a
    house is bought or sold. No configuration, no polling, instant effect.

        exports.msk_garage:CreatePrivateGarage({
            houseRef = houseId,          -- the id YOUR housing script uses
            owner    = xPlayer.identifier,
            location = vector4(x, y, z, h),   -- where the garage marker sits
            parkOut  = { vector4(x, y, z, h) },
            label    = 'Haus 17',        -- optional
        })
        exports.msk_garage:SetPrivateGarageOwner(houseId, newOwnerIdentifier)
        exports.msk_garage:DeletePrivateGarage(houseId)
        exports.msk_garage:GrantPrivateGarageAccess(houseId, identifier)
        exports.msk_garage:RevokePrivateGarageAccess(houseId, identifier)
        exports.msk_garage:GetPrivateGarageAccess(houseId)
        exports.msk_garage:PlayerHasGarageAccess(identifier, houseId)

    PULL is for housing scripts you cannot patch. Pick ONE adapter:

      'db'     read the owner from the housing table. Works with every script,
               including escrow ones, because the table stays readable.
      'export' call an export of the housing resource.
      'custom' your own Lua, see Config.HousingHooks below.
============================================================]]--

Config.Housing = {
    enable = false,   -- leave false when you use the push exports
    script = 'db',    -- 'db' | 'export' | 'custom'

    -- Only for 'export': the resource the export lives on.
    resource = nil,

    -- How long an answer from the housing script is reused, in seconds. The
    -- push exports invalidate immediately, this is only a safety net.
    cacheSeconds = 60,

    -- Adapter 'db'. Open the housing table once and read off the two column
    -- names. Verified mapping for esx_property is listed in
    -- Config.HousingPresets below.
    db = {
        table       = 'owned_properties',
        houseColumn = 'name',
        ownerColumn = 'owner',

        -- Optional, only when the script keeps roommates in a second table.
        membersTable       = nil,
        membersHouseColumn = nil,
        membersOwnerColumn = nil,
    },

    -- Adapter 'export'. Look the names up in your housing documentation.
    export = {
        getOwner   = nil,   -- (houseRef) -> identifier or table
        getMembers = nil,   -- optional
        ownerField = nil,   -- set when the export returns a table
    },
}

-- How often the housing owners are mirrored into msk_garage, in minutes.
-- Pull setups only, 0 disables it. Push setups do not need this at all.
Config.HousingSyncMinutes = 15

--[[
    Known table layouts. These are starting points, not guarantees: a server
    owner may have migrated or renamed things, so verify against your own
    database before trusting an entry.

    esx_property   table = 'owned_properties', house = 'name',  owner = 'owner'
        (verified against the public esx_property schema)

    Other scripts (loaf_housing, qs-housing, bcs_housing, nc_housing, ...) ship
    their own SQL file. Open it, or look at the table in HeidiSQL, and copy the
    two column names in. It is deliberately NOT guessed here: a wrong column
    name that looks official is worse than no entry at all.
]]--
Config.HousingPresets = {
    esx_property = { table = 'owned_properties', houseColumn = 'name', ownerColumn = 'owner' },
}

-- Adapter 'custom'. Both run on the SERVER. GetOwner is called on park-in and
-- park-out, so keep it cheap (the result is cached, see Config.Housing.cacheSeconds).
Config.HousingHooks = {
    -- Which player owns this house? Return the framework identifier or nil.
    GetOwner = function(houseRef)
        -- return exports['my-housing']:GetOwner(houseRef)
        return nil
    end,

    -- Optional. Roommates/key holders tracked by the housing script itself.
    -- Return nil to let msk_garage manage its own access list instead.
    GetMembers = function(houseRef)
        return nil
    end,
}
