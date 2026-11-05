VehiclesCtl = VehiclesCtl or {}

-- Vehicle-deformation bridge for the third-party VehicleDeformation script.
-- The export returns { { offset = vector3, damage = number }, ... }. A vector3
-- does NOT survive the server's json.encode/decode round-trip intact (it turns
-- into a plain array and loses .x/.y/.z), so we flatten the offsets to plain
-- numbers here and rebuild real vector3s on apply. Otherwise the saved dents
-- silently fail to reapply and the car comes out repaired.
function VehiclesCtl.GetDeformations(vehicle)
    if GetResourceState('VehicleDeformation') ~= 'started' then return false end

    local raw = exports['VehicleDeformation']:GetVehicleDeformation(vehicle)
    if type(raw) ~= 'table' then return false end

    local out = {}
    for i = 1, #raw do
        local d = raw[i]
        local o = d.offset
        if o then
            out[i] = { ox = o.x or o[1], oy = o.y or o[2], oz = o.z or o[3], d = d.damage }
        end
    end
    return out
end

function VehiclesCtl.SetDeformations(vehicle, deformation)
    if type(deformation) ~= 'table' or #deformation == 0 then return end
    if GetResourceState('VehicleDeformation') ~= 'started' then return end

    local rebuilt = {}
    for i = 1, #deformation do
        local d = deformation[i]
        if d.ox ~= nil then
            -- New flattened format.
            rebuilt[i] = { offset = vec3(d.ox, d.oy, d.oz), damage = d.d }
        elseif d.offset then
            -- Legacy format saved before the flattening fix.
            local o = d.offset
            rebuilt[i] = { offset = vec3(o.x or o[1], o.y or o[2], o.z or o[3]), damage = d.damage }
        end
    end

    if #rebuilt > 0 then
        exports['VehicleDeformation']:SetVehicleDeformation(vehicle, rebuilt)
    end
end

-- Wait for a server-spawned entity to replicate locally.
local function awaitNetEntity(netId, timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 2500)
    while GetGameTimer() < deadline do
        if NetworkDoesEntityExistWithNetworkId(netId) then
            local veh = NetToVeh(netId)
            if veh and veh ~= 0 and DoesEntityExist(veh) then return veh end
        end
        Wait(10)
    end
    return 0
end

-- Mod slots we can read back to tell whether the tuning actually landed on the
-- entity. Both ESX spellings of the armour field are listed on purpose: older
-- es_extended builds write modArmor, newer ones modArmour.
local MOD_SLOT_CHECKS = {
    modSpoilers = 0, modFrontBumper = 1, modRearBumper = 2, modSideSkirt = 3,
    modExhaust = 4, modFrame = 5, modGrille = 6, modHood = 7, modFender = 8,
    modRightFender = 9, modRoof = 10,
    modEngine = 11, modBrakes = 12, modTransmission = 13, modHorns = 14,
    modSuspension = 15, modArmor = 16, modArmour = 16,
    modFrontWheels = 23, modBackWheels = 24,
}

-- True when the saved tuning is really sitting on the vehicle. Used to detect the
-- silent no-op described in applyProperties below.
local function propertiesApplied(vehicle, p)
    if not p or not DoesEntityExist(vehicle) then return true end

    local primary, secondary = GetVehicleColours(vehicle)
    if p.color1 and p.color1 ~= primary then return false end
    if p.color2 and p.color2 ~= secondary then return false end
    if p.wheels and p.wheels ~= GetVehicleWheelType(vehicle) then return false end

    for key, slot in pairs(MOD_SLOT_CHECKS) do
        local want = p[key]
        -- -1 means "stock", there is nothing to prove for those slots.
        if want and want ~= -1 and GetVehicleMod(vehicle, slot) ~= want then
            -- A saved index the model does not offer (e.g. after an addon car was
            -- updated) can never land, so it must not keep the check failing.
            -- 0 mods means the mod kit is not loaded yet, that still counts as
            -- not applied.
            local count = GetNumVehicleMods(vehicle, slot)
            if count == 0 or want < count then return false end
        end
    end

    if p.modTurbo ~= nil and p.modTurbo ~= IsToggleModOn(vehicle, 18) then return false end

    return true
end

-- Writes the saved ESX property blob onto the vehicle.
--
-- The natives behind SetVehicleProperties (SetVehicleMod, SetVehicleColours,
-- SetVehicleExtra, ...) only take effect on the client that OWNS the entity. A
-- park-out vehicle comes from CreateVehicleServerSetter, so it belongs to the
-- server for the first few hundred milliseconds and every one of those calls is
-- silently dropped — the car ends up stock. On top of that the game keeps
-- normalising a freshly created vehicle for another frame or two, which can wipe
-- a write that did land. That is why this runs after taking control and is
-- repeated until the values read back correctly.
local function applyProperties(vehicle, p)
    if not p or not DoesEntityExist(vehicle) then return end

    -- Required before any SetVehicleMod call; ESX sets it too, but not every
    -- es_extended build does so unconditionally.
    SetVehicleModKit(vehicle, 0)
    SetVehicleProps(vehicle, p)

    -- Condition values, re-asserted for the same reason (the setter hands out a
    -- vehicle at full health, so a single pass frequently leaves the car repaired).
    if p.engineHealth then SetVehicleEngineHealth(vehicle, p.engineHealth + 0.0) end
    if p.bodyHealth   then SetVehicleBodyHealth(vehicle, p.bodyHealth + 0.0) end
    if p.tankHealth   then SetVehiclePetrolTankHealth(vehicle, p.tankHealth + 0.0) end
    if p.dirtLevel    then SetVehicleDirtLevel(vehicle, p.dirtLevel + 0.0) end
end

-- How long a park-out keeps re-applying the tuning when the first second was not
-- enough. Only runs while the check fails, so it costs nothing on a good PC.
local PROPS_RETRY_MS = 30000

-- Applies the result payload from the server (props, fuel, deformation) to the local entity handle and triggers warp.
local function applySpawnResult(vehicle, result)
    SetVehRadioStation(vehicle, 'OFF')
    -- Lock via the adapter so a vehicle-keys script (msk_vehiclekeys) stays in
    -- sync; a raw SetVehicleDoorsLocked would desync it and block the owner.
    -- Stays synchronous: the vehicleParkedOut event fires right after this and a
    -- keys script unlocking there must not be overruled by a delayed lock.
    Config.LockVehicle(vehicle, true)
    -- DoesEntityExist guard: Config.SetFuel may call msk_fuel, which asserts on a
    -- missing entity. An unguarded throw here would abort park-out before the
    -- vehicleParkedOut event fires (keys/unlock), leaving the car locked.
    if result.fuel and DoesEntityExist(vehicle) then Config.SetFuel(vehicle, result.fuel) end

    CreateThread(function()
        -- Take control FIRST. Applying the properties before this is what made
        -- vehicles come out of the garage and the impound without their tuning.
        local deadline = GetGameTimer() + 2000
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
            NetworkRequestControlOfEntity(vehicle)
            Wait(0)
        end
        if not DoesEntityExist(vehicle) then return end

        -- Best effort even without control: another player may own the entity
        -- (spawn point inside their scope), and a stock car is worse than a try.
        applyProperties(vehicle, result.props)

        -- Verify and repeat while the vehicle is still settling. The first second
        -- runs tight, which is enough on most PCs.
        local applied = propertiesApplied(vehicle, result.props)
        for _ = 1, 10 do
            if applied then break end
            Wait(100)
            if not DoesEntityExist(vehicle) then return end
            applyProperties(vehicle, result.props)
            applied = propertiesApplied(vehicle, result.props)
        end

        -- Slow PCs (or another player holding the entity) can need far longer.
        -- Giving up after one second left those players in a stock car, and
        -- parking it in again stored the stock state. Keep asking for control and
        -- re-applying at a slower pace; once the player is in the driver seat they
        -- own the car anyway, so this catches up at the latest then.
        local slowDeadline = GetGameTimer() + PROPS_RETRY_MS
        while not applied and GetGameTimer() < slowDeadline do
            Wait(250)
            if not DoesEntityExist(vehicle) then return end
            NetworkRequestControlOfEntity(vehicle)
            if NetworkHasControlOfEntity(vehicle) then
                applyProperties(vehicle, result.props)
                applied = propertiesApplied(vehicle, result.props)
            end
        end

        -- Tell the server the tuning is really on the car. Without this call the
        -- next park-in keeps the tuning from the database instead of storing
        -- whatever this client reads off the vehicle.
        if applied then
            MSK.Trigger('msk_garage:confirmProps', result.plate)
        else
            Utils.Log('warn', ('plate %s: tuning could not be applied, park-in will keep the saved tuning'):format(result.plate))
        end

        if result.deformation then VehiclesCtl.SetDeformations(vehicle, result.deformation) end

        -- Only now let AdvancedParking snapshot the (correct) state.
        if Config.UsesAdvancedParking() then
            exports['AdvancedParking']:UpdateVehicle(vehicle)
        end
    end)
end

-- Client spawn mode (Config.spawnMode = 'client'): this client creates the car
-- itself, so it owns the entity from the first frame and the tuning lands right
-- away. The server only reserved the spawn and checks the car in claimSpawn.
-- Needs entity creation by clients, so it does not work with
-- `sv_entityLockdown strict`.
local function spawnLocalVehicle(result)
    local spawn = result.spawn
    local model = type(spawn.model) == 'string' and joaat(spawn.model) or spawn.model
    if not IsModelInCdimage(model) then return 0 end

    RequestModel(model)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(model) then return 0 end

    local vehicle = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.h, true, false)
    SetModelAsNoLongerNeeded(model)
    if not vehicle or vehicle == 0 then return 0 end

    deadline = GetGameTimer() + 2500
    while not NetworkGetEntityIsNetworked(vehicle) and GetGameTimer() < deadline do
        NetworkRegisterEntityAsNetworked(vehicle)
        Wait(10)
    end
    if not NetworkGetEntityIsNetworked(vehicle) then
        Utils.Log('error', 'client spawn could not be networked, is sv_entityLockdown on? Use Config.spawnMode = \'server\'')
        DeleteEntity(vehicle)
        return 0
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, result.plate)
    -- First pass while nobody else can own the car yet; applySpawnResult checks
    -- and repeats it like in server mode.
    applyProperties(vehicle, result.props)

    return vehicle
end

-- Gets the park-out vehicle onto this client in either spawn mode, or 0 after a
-- rollback. In client mode the server checks the car before the park-out counts.
local function receiveVehicle(result, plate)
    if result.spawn then
        local vehicle = spawnLocalVehicle(result)
        if vehicle == 0 then
            MSK.Trigger('msk_garage:rollbackSpawn', plate)
            Config.Notification(nil, Utils.T('spawnLocations_blocked'), 'error')
            return 0
        end

        if not MSK.Trigger('msk_garage:claimSpawn', plate, VehToNet(vehicle)) then
            -- Rejected and rolled back by the server.
            if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
            return 0
        end
        return vehicle
    end

    local vehicle = awaitNetEntity(result.netId, 2500)
    if vehicle == 0 then
        MSK.Trigger('msk_garage:rollbackSpawn', plate)
        Config.Notification(nil, Utils.T('spawnLocations_blocked'), 'error')
        return 0
    end

    MSK.Trigger('msk_garage:claimSpawn', plate)
    return vehicle
end

-- PARK IN
function VehiclesCtl.ParkIn(vehicle, props, plate, fuel, _model, deformation)
    local garage = State.currentGarage or State.customGarage
    if not garage then return end

    local payload = {
        garageId     = garage.id,
        netId        = VehToNet(vehicle),
        plate        = plate,
        fuel         = fuel,
        props        = props,
        deformations = deformation,
    }

    local ok = MSK.Trigger('msk_garage:parkIn', payload)
    if not ok then return end

    TriggerEvent('msk_garage:vehicleParkedIn', vehicle, props, plate, fuel, garage)
    NUI.Refresh('parkin')
end

-- PARK OUT
function VehiclesCtl.ParkOut(plate, stored)
    if stored == 0 then
        Config.Notification(nil, Utils.T('already_parked_out'), 'error')
        return
    end

    local garage = State.currentGarage or State.customGarage
    if not garage then return end

    local result = MSK.Trigger('msk_garage:parkOut', { garageId = garage.id, plate = plate })
    if not result or not (result.netId or result.spawn) then return end

    local vehicle = receiveVehicle(result, plate)
    if vehicle == 0 then return end

    applySpawnResult(vehicle, result)

    TriggerEvent('msk_garage:vehicleParkedOut', vehicle, plate, result.fuel, result.props, garage)

    if result.warp then
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        NUI.Close()
    else
        NUI.Refresh('parkout')
    end
end


-- PARK OUT from Impound
function VehiclesCtl.ParkOutImpound(plate, stored)
    if stored == 1 then
        Utils.Log('debug', '[IMPOUND] vehicle is not in impound')
        return
    end

    local impoundDef = State.currentImpound or State.customImpound
    if not impoundDef then return end

    local result = MSK.Trigger('msk_garage:parkOutImpound', { impoundId = impoundDef.impoundId, plate = plate })
    if not result or not (result.netId or result.spawn) then return end

    local vehicle = receiveVehicle(result, plate)
    if vehicle == 0 then return end

    applySpawnResult(vehicle, result)

    TriggerEvent('msk_garage:vehicleParkedOutImpound', vehicle, plate, result.fuel, result.props, impoundDef)

    if result.warp then
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        NUI.Close()
    else
        NUI.Refresh('impound')
    end
end
