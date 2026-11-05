Vehicles = Vehicles or {}

-- owned_vehicles.type -> CreateVehicleServerSetter "type" parameter.
local VEHICLE_TYPE_MAP = VEHICLE_TYPE_MAP_DEFAULTS

local function setterType(vehicleType)
    return VEHICLE_TYPE_MAP[tostring(vehicleType):lower()] or 'automobile'
end

-- Pending spawn-claim registry. When a park-out succeeds the server writes a claim here; 
-- the client must confirm receipt or trigger a rollback. Unclaimed entries are reaped after CLAIM_TTL seconds.
local pendingClaims = {} -- [src..'#'..trimmedPlate] = {...}
local CLAIM_TTL = 30

local function claimKey(src, plate)
    return tostring(src) .. '#' .. MSK.Trim(plate, true)
end

local function recordClaim(src, plate, claim)
    claim.expiresAt = os.time() + CLAIM_TTL
    pendingClaims[claimKey(src, plate)] = claim
end

local function takeClaim(src, plate)
    local key = claimKey(src, plate)
    local claim = pendingClaims[key]
    pendingClaims[key] = nil
    if not claim or os.time() > claim.expiresAt then return nil end
    return claim
end

-- True while any player has an open spawn for this plate. In client mode the
-- plate lock is released before the client has spawned anything, so this keeps
-- a second request (impound rows stay stored=0) from handing the car out twice.
local function hasPendingClaim(plate)
    local suffix = '#' .. MSK.Trim(plate, true)
    local now = os.time()
    for key, claim in pairs(pendingClaims) do
        if key:sub(-#suffix) == suffix and now <= claim.expiresAt then return true end
    end
    return false
end

-- 'server' (default): CreateVehicleServerSetter, the server owns the spawn.
-- 'client': the client creates the car itself and owns it from the first frame,
-- so the tuning lands at once even on a slow PC. The server reserves the spawn,
-- then checks the entity the client reports (see Vehicles.ClaimSpawn).
local function clientSpawnMode()
    return Config.spawnMode == 'client'
end

local rollbackClaim -- defined further down, used by the reaper

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for k, claim in pairs(pendingClaims) do
            if now > claim.expiresAt then
                pendingClaims[k] = nil
                -- A client spawn that was never reported means nothing is in the
                -- world for this plate, so put the car back.
                if claim.clientSpawn then rollbackClaim(claim.src, claim.plate, claim) end
            end
        end
    end
end)

-- Spawns whose tuning the client has not confirmed yet. [trimmedPlate] = { src }.
--
-- The tuning of a park-out vehicle is written by the client after the server
-- spawned it, and the client is the only one who can read it back. On a slow PC
-- that write can fail for the whole session, the player then drives a stock car,
-- and the next park-in would store that stock state over the real tuning. While
-- a plate is listed here, park-in keeps the tuning from the database and only
-- takes the condition values from the client.
local unverifiedProps = {}

local function markUnverified(src, plate)
    unverifiedProps[MSK.Trim(plate, true)] = { src = src }
end

local function takeUnverified(plate)
    local key = MSK.Trim(plate, true)
    local entry = unverifiedProps[key]
    unverifiedProps[key] = nil
    return entry
end

-- Keys that describe the condition of the car rather than its tuning. These
-- always come from the client on park-in, both ESX and ox_lib spellings.
local CONDITION_KEYS = {
    'bodyHealth', 'engineHealth', 'tankHealth', 'dirtLevel', 'fuelLevel',
    'windowsBroken', 'doorsBroken', 'tyreBurst', -- ESX
    'windows', 'doors', 'tyres',                 -- ox_lib
}

-- Saved tuning plus the condition the car is in now.
local function keepSavedTuning(saved, incoming)
    local merged = {}
    for k, v in pairs(saved) do merged[k] = v end
    for _, key in ipairs(CONDITION_KEYS) do
        if incoming[key] ~= nil then merged[key] = incoming[key] end
    end
    if incoming.plate then merged.plate = incoming.plate end
    return merged
end

-- LoadOwned: verifies a plate belongs to the player by identifier, job, or held key. 
-- requireStored filters by stored=1/0; nil skips.
function Vehicles.LoadOwned(xPlayer, plate, requireStored)
    local raw, trimmed = Validation.NormalisePlate(plate)
    if not trimmed then return nil, 'bad plate' end

    local row = MySQL.single.await(
        ('SELECT * FROM `%s` WHERE (`plate` = ? OR `plate` = ?) LIMIT 1'):format(Config.MySQL.table),
        { raw, trimmed }
    )
    if not row then return nil, 'not found' end

    -- The owner column is `owner` on ESX and `citizenid` on QBCore and Qbox.
    local owner = row[Config.MySQL.owner]

    local ownsByIdentifier = owner == xPlayer.identifier
    local ownsByKey = Keys.HasKey(xPlayer, trimmed, nil)
    local ownsByJob = false

    if row[Config.MySQL.job] and row[Config.MySQL.job] ~= '' and row[Config.MySQL.job] ~= Config.MySQL.civ then
        if xPlayer.job and xPlayer.job.name == row[Config.MySQL.job] then
            ownsByJob = true
        elseif owner == Utils.SocietyOwner(xPlayer.job and xPlayer.job.name) then
            ownsByJob = true
        end
    end

    if not (ownsByIdentifier or ownsByKey or ownsByJob) then
        return nil, 'not owned'
    end

    -- The stored flag is `stored` on ESX and `state` on QBCore and Qbox.
    if requireStored ~= nil and Utils.GetIsStored(row[Config.MySQL.stored]) ~= requireStored then
        return nil, requireStored == 1 and 'not stored' or 'already stored'
    end

    return row
end

-- Resolves the garage definition for a request. Order:
--   1. Canonical Config.Garages (validated position + job)
--   2. Server-registered custom session for this player
-- The client never gets to inject a garage definition.
local function resolveGarage(src, garageId)
    local def, err = Validation.RequireGarageAccess(src, garageId)
    if def then return def end

    local custom = CustomSessions.GetGarage(src)
    if custom then return custom end

    return nil, err or 'no custom session'
end

local function resolveImpound(src, impoundId)
    local def, err = Validation.RequireImpoundAccess(src, impoundId)
    if def then return def end

    local custom = CustomSessions.GetImpound(src)
    if custom then return custom end

    return nil, err or 'no custom session'
end

-- PARK-IN: server-side authoritative.
-- Client sends: { garageId, netId, plate, fuel, props, deformations }
function Vehicles.ParkIn(src, payload)
    local garage, gerr = resolveGarage(src, payload.garageId)
    if not garage then
        Config.Notification(src, gerr or 'access denied', 'error')
        return
    end

    if not payload.netId or type(payload.netId) ~= 'number' then
        Config.Notification(src, 'missing vehicle', 'error')
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(payload.netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        Config.Notification(src, 'vehicle not found', 'error')
        return
    end

    -- reject anything that isn't a vehicle
    if GetEntityType(vehicle) ~= 2 then
        Utils.Log('warn', ('player %d sent non-vehicle netId %d'):format(src, payload.netId))
        return
    end

    -- player must stand near the vehicle
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > (garage.distance or 40.0) then
        Utils.Log('warn', ('player %d tried to park a vehicle out of range'):format(src))
        Config.Notification(src, 'vehicle too far away', 'error')
        return
    end

    -- the plate the client claims MUST equal the entity's actual plate
    local actualPlate = GetVehicleNumberPlateText(vehicle)
    local trimmedActual = MSK.Trim(actualPlate or '', true)
    local trimmedClaimed = MSK.Trim(payload.plate or '', true)
    if trimmedClaimed ~= '' and trimmedClaimed ~= trimmedActual then
        Utils.Log('warn', ('player %d sent plate %s for vehicle with plate %s'):format(src, payload.plate, actualPlate))
        Config.Notification(src, 'plate mismatch', 'error')
        return
    end
    local plate = actualPlate

    local xPlayer = MSK.GetPlayer(src)
    -- Require stored=0: a vehicle physically in the world cannot already be
    -- "stored". Passing nil here let a player re-park an already-stored plate
    -- (e.g. a lingering duplicate) and overwrite its saved props/fuel.
    local row, oerr = Vehicles.LoadOwned(xPlayer, plate, 0)
    if not row then
        Utils.Log('warn', ('player %d tried to park plate %s (%s)'):format(src, plate, oerr))
        Config.Notification(src, oerr == 'already stored' and Utils.T('already_parked_in') or Utils.T('vehicle_not_owned'), 'error')
        return
    end

    -- type must match the garage (tolerant of shop type-naming conventions)
    if not Classes.TypeMatches(garage.type, row[Config.MySQL.type]) then
        Config.Notification(src, Utils.T('is_job_vehicle', '', plate), 'error')
        return
    end

    -- A job vehicle may only be parked in at a PUBLIC (canonical, non-job) garage
    -- when the job's policy allows this specific garage — otherwise it belongs in
    -- its job garage and would be unretrievable here. Job garages (jobs.enable)
    -- skip this; custom server-registered sessions are trusted and skip it too.
    local isCanonical = garage.id ~= nil and Config.Garages[garage.id] == garage
    if isCanonical and not (garage.jobs and garage.jobs.enable) then
        local rowJob = row[Config.MySQL.job]
        if rowJob and rowJob ~= '' and rowJob ~= Config.MySQL.civ
            and not Garages.JobAllowedAtPublicGarage(rowJob, garage.id) then
            Config.Notification(src, Utils.T('is_job_vehicle', '', plate), 'error')
            return
        end
    end

    local storedGarage = Config.Parking == 'specific' and garage.id or Config.DefaultGarage

    -- The props blob is fully client-supplied and CANNOT be trusted for the
    -- model: on park-out we spawn props.model via CreateVehicleServerSetter, so a
    -- spoofed model would let a player turn any car into a supercar. Force the
    -- stored model to the server-observed entity model — the only authoritative
    -- value we have. (Performance/visual mods still can't be read server-side in
    -- ESX; the model is the load-bearing anti-exploit guard.)
    local props = type(payload.props) == 'table' and payload.props or {}

    -- The client never confirmed that the saved tuning landed on this car, so
    -- what it sends now may be the stock state. Keep the tuning from the DB.
    -- Read from the row, not from the park-out time, so a mechanic script that
    -- wrote new tuning into the table in between is not undone.
    if takeUnverified(plate) then
        Utils.Log('warn', ('plate %s: tuning was never confirmed after park-out, keeping the saved tuning'):format(plate))
        props = keepSavedTuning(Utils.RowProps(row), props)
    end

    props.model = GetEntityModel(vehicle)

    -- Clamp fuel to a sane integer. Without msk_fuel this is a 0-100 percentage;
    -- with msk_fuel it is absolute liters (a large tank can exceed 100). The column
    -- is a signed SMALLINT, so cap at 32767 to guard against corrupt/spoofed values
    -- while still allowing any realistic tank volume.
    local fuel = math.floor(math.min(32767, math.max(0, tonumber(payload.fuel) or 100)))

    MySQL.update.await(
        ('UPDATE `%s` SET `%s` = ?, `fuel` = ?, `%s` = ?, `garage` = ?, `deformations` = ?' ..
            ' WHERE (`plate` = ? OR `plate` = ?)'):format(Config.MySQL.table, Config.MySQL.stored, Config.MySQL.props),
        {
            Config.MySQL.storedIn,
            fuel,
            json.encode(props),
            storedGarage,
            json.encode(payload.deformations or {}),
            plate,
            MSK.Trim(plate, true),
        }
    )

    if Config.UsesAdvancedParking() then
        exports['AdvancedParking']:DeleteVehicleUsingData(nil, payload.netId, plate)
    else
        DeleteEntity(vehicle)
    end

    TriggerEvent('msk_garage:vehicleParkedIn', payload.netId, plate, fuel, props, garage)
    Config.Notification(src, Utils.T('parked_in'), 'success')
    return true
end

-- Spawn helpers
local function findFreeSpot(spots, parkDist)
    if not spots then return nil end
    for _, spot in ipairs(spots) do
        local taken = false
        local center = vec3(spot.x, spot.y, spot.z)
        for _, veh in pairs(GetAllVehicles()) do
            if DoesEntityExist(veh) and #(GetEntityCoords(veh) - center) < (parkDist or 5.0) then
                taken = true; break
            end
        end
        if not taken then
            return { x = spot.x, y = spot.y, z = spot.z, h = Utils.Heading(spot) }
        end
    end
    return nil
end

-- Custom payloads from third-party scripts may use camelCase.
local function normaliseSpots(def)
    return def.park_out or def.parkOutCoords
end

local function serverSpawn(modelHash, vehicleType, spot, plate)
    local entity = CreateVehicleServerSetter(modelHash, setterType(vehicleType), spot.x, spot.y, spot.z, spot.h)
    if not entity or entity == 0 then return nil end

    local tries, ready = 0, false
    while tries < 50 do
        if DoesEntityExist(entity) then ready = true; break end
        Wait(20); tries = tries + 1
    end
    if not ready then
        if entity and entity ~= 0 then DeleteEntity(entity) end
        return nil
    end

    if SetVehicleNumberPlateText then
        pcall(SetVehicleNumberPlateText, entity, plate)
    end

    return entity
end

local function setEntityState(entity, row)
    local state = Entity(entity).state
    state.fuel = row.fuel
    state.deformations = row.deformations and json.decode(row.deformations) or nil
    state.plate = row.plate
end

-- What the client needs to finish a park-out. `entity` is nil in client mode,
-- the netId only exists once the client has spawned the car.
local function buildSpawnPayload(row, entity)
    -- The client applies this table through the property setter of the running
    -- framework, and that only sets the plate when props.plate is present, so it
    -- MUST be a decoded table and we force the canonical DB plate onto it.
    -- Sending the raw string here left the spawned vehicle with its random
    -- server-setter plate, which then failed park-in.
    local props = Utils.RowProps(row)
    props.plate = row.plate

    if entity then setEntityState(entity, row) end

    return {
        netId       = entity and NetworkGetNetworkIdFromEntity(entity) or nil,
        plate       = row.plate,
        props       = props,
        fuel        = row.fuel,
        deformation = row.deformations and json.decode(row.deformations) or nil,
    }
end

-- Updates owned_vehicles after a successful spawn. 
-- On DB failure the spawned entity is removed so the world and DB stay consistent. 
-- Returns true on success.
local function commitParkOut(plate, entity)
    local ok = pcall(function()
        MySQL.update.await(
            ('UPDATE `%s` SET `%s` = ? WHERE (`plate` = ? OR `plate` = ?)'):format(Config.MySQL.table, Config.MySQL.stored),
            { Config.MySQL.storedOut, plate, MSK.Trim(plate, true) }
        )
    end)
    if not ok then
        Utils.Log('error', 'park-out DB update failed, rolling back entity for plate', plate)
        if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
        return false
    end
    return true
end

-- PARK-OUT: server-side spawn via CreateVehicleServerSetter.
function Vehicles.ParkOut(src, payload)
    local garage, gerr = resolveGarage(src, payload.garageId)
    if not garage then
        Config.Notification(src, gerr or 'access denied', 'error')
        return
    end

    if hasPendingClaim(payload.plate) or not Validation.AcquirePlateLock(payload.plate) then
        Config.Notification(src, 'already spawning', 'error')
        return
    end

    local ok, result = pcall(function()
        local xPlayer = MSK.GetPlayer(src)
        local row, oerr = Vehicles.LoadOwned(xPlayer, payload.plate, 1)
        if not row then
            Config.Notification(src, oerr == 'already stored' and Utils.T('already_parked_out') or Utils.T('vehicle_not_owned'), 'error')
            return nil
        end

        -- Mirror the park-in type guard. The per-type UI filter is cosmetic and
        -- trivially bypassed by calling this callback directly, which would let a
        -- boat/heli park out of a car garage and spawn with the wrong setter type.
        if not Classes.TypeMatches(garage.type, row[Config.MySQL.type]) then
            Config.Notification(src, Utils.T('is_job_vehicle', '', payload.plate), 'error')
            return nil
        end

        -- Mirror the park-in public-garage job policy: a job vehicle may only be
        -- parked out at a public canonical garage the job's policy allows.
        local isCanonical = garage.id ~= nil and Config.Garages[garage.id] == garage
        if isCanonical and not (garage.jobs and garage.jobs.enable) then
            local rowJob = row[Config.MySQL.job]
            if rowJob and rowJob ~= '' and rowJob ~= Config.MySQL.civ
                and not Garages.JobAllowedAtPublicGarage(rowJob, garage.id) then
                Config.Notification(src, Utils.T('is_job_vehicle', '', payload.plate), 'error')
                return nil
            end
        end

        local spot = findFreeSpot(normaliseSpots(garage), garage.park_dist)
        if not spot then
            Config.Notification(src, Utils.T('spawnLocations_blocked'), 'error')
            return nil
        end

        local props = Utils.RowProps(row)
        local modelHash = Utils.RowModel(row, props)

        if clientSpawnMode() then
            -- Mark the car as out now, exactly like the server path does, so a
            -- second park-out of the same plate fails on stored=1. A client that
            -- never reports back is rolled back by ClaimSpawn or the reaper.
            if not commitParkOut(row.plate, nil) then
                Config.Notification(src, 'database error', 'error')
                return nil
            end

            recordClaim(src, row.plate, {
                kind = 'garage', clientSpawn = true, src = src, plate = row.plate,
                model = modelHash, spot = spot, row = row, def = garage,
            })
            markUnverified(src, row.plate)

            local out = buildSpawnPayload(row, nil)
            out.warp = garage.warp == true
            out.spawn = { model = modelHash, x = spot.x, y = spot.y, z = spot.z, h = spot.h }
            return out
        end

        local entity = serverSpawn(modelHash, row[Config.MySQL.type], spot, row.plate)
        if not entity then
            Config.Notification(src, 'spawn failed', 'error')
            return nil
        end

        if not commitParkOut(row.plate, entity) then
            Config.Notification(src, 'database error', 'error')
            return nil
        end

        recordClaim(src, row.plate, { kind = 'garage', entity = entity })
        markUnverified(src, row.plate)

        local out = buildSpawnPayload(row, entity)
        out.warp = garage.warp == true
        TriggerEvent('msk_garage:vehicleParkedOut', out.netId, row.plate, row.fuel, props, garage)
        Config.Notification(src, Utils.T('parked_out'), 'success')
        return out
    end)

    Validation.ReleasePlateLock(payload.plate)
    if not ok then
        Utils.Log('error', 'ParkOut crashed:', tostring(result))
        return nil
    end
    return result
end

function Vehicles.ParkOutFromImpound(src, payload)
    local impound, ierr = resolveImpound(src, payload.impoundId)
    if not impound then
        Config.Notification(src, ierr or 'access denied', 'error')
        return
    end

    -- AdvancedParking lock (opt-in, see Config.blockImpoundWhileAdvancedParked).
    -- As long as AdvancedParking still has a row for this plate the vehicle counts
    -- as standing in the world, so handing it out here would duplicate it. Checked
    -- BEFORE the fee so nobody pays for a refused park-out.
    if Impound.IsAdvancedParked(payload.plate) then
        Config.Notification(src, Utils.T('impound_blocked'), 'error')
        return nil
    end

    -- Fee is taken from the canonical impound def (or server-registered
    -- custom). The client cannot influence fee shape any more.
    if not Impound.ChargeFee(src, impound.fee) then
        return nil
    end

    if hasPendingClaim(payload.plate) or not Validation.AcquirePlateLock(payload.plate) then
        -- refund: charge was already taken
        if impound.fee and impound.fee.enable then
            local xPlayer = MSK.GetPlayer(src)
            if xPlayer then xPlayer.AddMoney(impound.fee.account, impound.fee.price) end
        end
        Config.Notification(src, 'already spawning', 'error')
        return
    end

    local ok, result = pcall(function()
        local xPlayer = MSK.GetPlayer(src)
        local row = Vehicles.LoadOwned(xPlayer, payload.plate, 0)
        if not row then
            -- refund: we charged but found nothing
            if impound.fee and impound.fee.enable then
                xPlayer.AddMoney(impound.fee.account, impound.fee.price)
            end
            Config.Notification(src, Utils.T('vehicle_not_owned'), 'error')
            return nil
        end

        -- Despawn any leftover world copy of this plate first.
        local target = MSK.Trim(row.plate, true)

        -- Delete any live copy currently in the server's scope.
        for _, veh in pairs(GetAllVehicles()) do
            if DoesEntityExist(veh) and MSK.Trim(GetVehicleNumberPlateText(veh), true) == target then
                DeleteEntity(veh)
            end
        end

        -- AdvancedParking keeps its own table and respawns vanished vehicles, so
        -- a plain delete just makes the old copy come back. Purge the plate from
        -- that table (keepInWorld=false = remove from world AND table, no
        -- respawn). Pass the raw DB plate — AP keys on the stored plate text.
        if Config.UsesAdvancedParking() then
            exports['AdvancedParking']:DeleteVehicleUsingData(nil, nil, row.plate, false)
        end

        local spot = findFreeSpot(normaliseSpots(impound), impound.park_dist)
        if not spot then
            if impound.fee and impound.fee.enable then
                xPlayer.AddMoney(impound.fee.account, impound.fee.price)
            end
            Config.Notification(src, Utils.T('spawnLocations_blocked'), 'error')
            return nil
        end

        local props = Utils.RowProps(row)
        local modelHash = Utils.RowModel(row, props)

        if clientSpawnMode() then
            recordClaim(src, row.plate, {
                kind = 'impound', clientSpawn = true, src = src, plate = row.plate,
                model = modelHash, spot = spot, row = row, def = impound,
                feeAccount = impound.fee and impound.fee.enable and impound.fee.account or nil,
                feeAmount  = impound.fee and impound.fee.enable and impound.fee.price or nil,
            })
            markUnverified(src, row.plate)

            local out = buildSpawnPayload(row, nil)
            out.warp = impound.warp == true
            out.spawn = { model = modelHash, x = spot.x, y = spot.y, z = spot.z, h = spot.h }
            return out
        end

        local entity = serverSpawn(modelHash, row[Config.MySQL.type], spot, row.plate)
        if not entity then
            if impound.fee and impound.fee.enable then
                xPlayer.AddMoney(impound.fee.account, impound.fee.price)
            end
            Config.Notification(src, 'spawn failed', 'error')
            return nil
        end

        recordClaim(src, row.plate, {
            kind = 'impound',
            entity = entity,
            feeAccount = impound.fee and impound.fee.enable and impound.fee.account or nil,
            feeAmount  = impound.fee and impound.fee.enable and impound.fee.price or nil,
        })
        markUnverified(src, row.plate)

        local out = buildSpawnPayload(row, entity)
        out.warp = impound.warp == true

        TriggerEvent('msk_garage:vehicleParkedOutImpound', out.netId, row.plate, row.fuel, props, impound)
        Config.Notification(src, Utils.T('parked_out'), 'success')
        return out
    end)

    Validation.ReleasePlateLock(payload.plate)
    if not ok then
        Utils.Log('error', 'ParkOutFromImpound crashed:', tostring(result))
        return nil
    end
    return result
end

-- Highest distance between the reserved spot and the car the client reports.
-- Generous on purpose: the car may roll a little or be put on the ground.
local CLIENT_SPAWN_MAX_DIST = 10.0

local function modelHashOf(model)
    if type(model) == 'string' then return joaat(model) end
    return tonumber(model)
end

-- Waits until the server knows the entity behind a netId the client just
-- registered. Creation and the first sync can arrive a few ticks apart.
local function awaitServerEntity(netId)
    for _ = 1, 50 do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then return entity end
        Wait(20)
    end
    return nil
end

-- Checks the car a client spawned itself against the reservation. Returns the
-- entity, or nil, a reason and the entity to delete.
local function verifyClientSpawn(src, claim, netId)
    if type(netId) ~= 'number' then return nil, 'missing netId' end

    local entity = awaitServerEntity(netId)
    if not entity then return nil, 'entity not found' end
    if GetEntityType(entity) ~= 2 then return nil, 'not a vehicle' end

    -- Only the reporting player's own car may be claimed, never someone else's.
    if NetworkGetEntityOwner(entity) ~= src then return nil, 'not the owner' end

    -- The anti-exploit guard: without it a client could spawn any model and
    -- claim it as the car from the database.
    if GetEntityModel(entity) ~= modelHashOf(claim.model) then return nil, 'model mismatch', entity end

    local spot = vec3(claim.spot.x, claim.spot.y, claim.spot.z)
    if #(GetEntityCoords(entity) - spot) > CLIENT_SPAWN_MAX_DIST then return nil, 'away from spot', entity end

    return entity
end

-- Client confirms the entity arrived locally. In server mode that only drops the
-- pending claim. In client mode the client reports the netId of the car it
-- spawned, which is checked before the park-out counts.
function Vehicles.ClaimSpawn(src, plate, netId)
    if not plate then return false end
    local claim = takeClaim(src, plate)
    if not claim then return false end
    if not claim.clientSpawn then return true end

    local entity, reason, badEntity = verifyClientSpawn(src, claim, netId)
    if not entity then
        Utils.Log('warn', ('player %d client spawn for plate %s rejected: %s'):format(src, plate, reason))
        if badEntity and DoesEntityExist(badEntity) then DeleteEntity(badEntity) end
        rollbackClaim(src, plate, claim)
        return false
    end

    -- The DB plate is the truth, whatever the client wrote onto the car.
    SetVehicleNumberPlateText(entity, claim.row.plate)
    -- A client-created entity is removed when its owner drops. A garage car has
    -- to stay in the world like one from the server setter does.
    if SetEntityOrphanMode then pcall(SetEntityOrphanMode, entity, 2) end
    setEntityState(entity, claim.row)

    local netIdOut = NetworkGetNetworkIdFromEntity(entity)
    local props = Utils.RowProps(claim.row)
    if claim.kind == 'impound' then
        TriggerEvent('msk_garage:vehicleParkedOutImpound', netIdOut, claim.row.plate, claim.row.fuel, props, claim.def)
    else
        TriggerEvent('msk_garage:vehicleParkedOut', netIdOut, claim.row.plate, claim.row.fuel, props, claim.def)
    end
    Config.Notification(src, Utils.T('parked_out'), 'success')
    return true
end


-- Client read the tuning back from the vehicle and it matches. Only the player
-- who parked the car out can clear the flag; a cheater faking this call only
-- turns off the protection for their own car.
function Vehicles.ConfirmProps(src, plate)
    if type(plate) ~= 'string' then return false end
    local key = MSK.Trim(plate, true)
    local entry = unverifiedProps[key]
    if not entry or entry.src ~= src then return false end
    unverifiedProps[key] = nil
    return true
end

-- Undoes a park-out: delete the spawned entity, set stored back to 1, refund fee if any.
rollbackClaim = function(src, plate, claim)
    if claim.entity and DoesEntityExist(claim.entity) then
        DeleteEntity(claim.entity)
    end
    takeUnverified(plate)

    -- Only a garage park-out set stored=0, so only that one is undone here. An
    -- impound car never left the impound; setting stored=1 for it handed the
    -- car back to the garage with the fee refunded, a free way out of the
    -- impound for anyone calling rollbackSpawn directly.
    if claim.kind ~= 'impound' then
        MySQL.update.await(
            ('UPDATE `%s` SET `%s` = ? WHERE (`plate` = ? OR `plate` = ?)'):format(Config.MySQL.table, Config.MySQL.stored),
            { Config.MySQL.storedIn, plate, MSK.Trim(plate, true) }
        )
    end

    if claim.feeAccount and claim.feeAmount and claim.feeAmount > 0 then
        local xPlayer = MSK.GetPlayer(src)
        if xPlayer then xPlayer.AddMoney(claim.feeAccount, claim.feeAmount) end
    end

    Utils.Log('warn', ('rolled back spawn for player %d plate %s'):format(src, plate))
    return true
end

-- Client failed to receive or spawn the entity.
function Vehicles.RollbackSpawn(src, plate)
    if not plate then return false end
    local claim = takeClaim(src, plate)
    if not claim then return false end
    return rollbackClaim(src, plate, claim)
end

-- Mutations on a row with ownership gating.
function Vehicles.Rename(src, plate, nickname)
    local xPlayer = MSK.GetPlayer(src)
    if not xPlayer then return end
    local row = Vehicles.LoadOwned(xPlayer, plate, nil)
    if not row then return end

    local cleaned = Validation.SanitizeNickname(nickname)
    MySQL.update(
        ('UPDATE `%s` SET `name` = ? WHERE (`plate` = ? OR `plate` = ?)'):format(Config.MySQL.table),
        { cleaned, plate, MSK.Trim(plate, true) }
    )
end

function Vehicles.ToggleFav(src, plate, isFav)
    local xPlayer = MSK.GetPlayer(src)
    if not xPlayer then return end
    local row = Vehicles.LoadOwned(xPlayer, plate, nil)
    if not row then return end

    MySQL.update(
        ('UPDATE `%s` SET `isFav` = ? WHERE (`plate` = ? OR `plate` = ?)'):format(Config.MySQL.table),
        { isFav and 1 or 0, plate, MSK.Trim(plate, true) }
    )
end

-- Deletes every vehicle that `identifier` personally owns and that is registered
-- on `jobName`. Called when a player leaves a job (see the msk_core:setJob handler in
-- server/main.lua) and only when Config.deleteJobVehiclesOnJobChange is on.
--
-- Society vehicles are never touched: those are owned by 'society_<job>', not by
-- the player, so the owner filter below can't match them.
-- Returns the list of deleted plates.
function Vehicles.PurgeJobVehicles(identifier, jobName)
    if type(identifier) ~= 'string' or identifier == '' then return {} end
    if type(jobName) ~= 'string' or jobName == '' then return {} end

    -- Never touch civilian rows, no matter what the job change looked like.
    if jobName == Config.MySQL.civ or jobName == 'unemployed' then return {} end

    local jobCol = Config.MySQL.job
    local rows = MySQL.query.await(
        ('SELECT `plate` FROM `%s` WHERE `%s` = ? AND `%s` = ?'):format(Config.MySQL.table, Config.MySQL.owner, jobCol),
        { identifier, jobName }
    ) or {}
    if #rows == 0 then return {} end

    local plates = {}
    for _, row in ipairs(rows) do plates[#plates + 1] = row.plate end

    MySQL.query.await(
        ('DELETE FROM `%s` WHERE `%s` = ? AND `%s` = ?'):format(Config.MySQL.table, Config.MySQL.owner, jobCol),
        { identifier, jobName }
    )

    -- Not debug-gated: this is destructive and admins need a trace of it.
    print(('^3[msk_garage]^0 Deleted %d job vehicle(s) of %s after leaving job "%s": %s')
        :format(#plates, identifier, jobName, table.concat(plates, ', ')))

    TriggerEvent('msk_garage:jobVehiclesDeleted', identifier, jobName, plates)
    return plates
end

-- GetWorldCoords with ownership gate so it can't be used as a tracking primitive against other players' vehicles.
function Vehicles.GetWorldCoords(src, plate)
    if src then
        local xPlayer = MSK.GetPlayer(src)
        if not xPlayer then return false end
        local row = Vehicles.LoadOwned(xPlayer, plate, nil)
        if not row then return false end
    end

    local target = MSK.Trim(plate, true)
    for _, vehicle in pairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and MSK.Trim(GetVehicleNumberPlateText(vehicle), true) == target then
            return GetEntityCoords(vehicle)
        end
    end
    return false
end

-- Delete by netId or plate with ownership + proximity check.
-- When `src` is nil this is an internal call (no checks) — only used by the ParkIn pathway, never reachable from an event.
function Vehicles.DeleteEntity(src, netId, plate, _model)
    if src then
        local xPlayer = MSK.GetPlayer(src)
        if not xPlayer then return end

        local actualPlate, vehicle

        if netId and type(netId) == 'number' then
            vehicle = NetworkGetEntityFromNetworkId(netId)
            if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
            if GetEntityType(vehicle) ~= 2 then return end

            local ped = GetPlayerPed(src)
            if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 50.0 then
                Utils.Log('warn', ('player %d tried to delete a vehicle out of range'):format(src))
                return
            end

            actualPlate = GetVehicleNumberPlateText(vehicle)
        elseif plate then
            actualPlate = plate
        else
            return
        end

        local row = Vehicles.LoadOwned(xPlayer, actualPlate, nil)
        if not row then
            Utils.Log('warn', ('player %d tried to delete unowned plate %s'):format(src, actualPlate))
            return
        end

        if vehicle then
            if Config.UsesAdvancedParking() then
                exports['AdvancedParking']:DeleteVehicleUsingData(nil, netId, actualPlate)
            else
                DeleteEntity(vehicle)
            end
            return Entity(vehicle).state.deformations
        end

        local target = MSK.Trim(actualPlate, true)
        local deformations
        for _, veh in pairs(GetAllVehicles()) do
            if DoesEntityExist(veh) and MSK.Trim(GetVehicleNumberPlateText(veh), true) == target then
                deformations = Entity(veh).state.deformations
                DeleteEntity(veh)
                break
            end
        end

        if Config.UsesAdvancedParking() then
            exports['AdvancedParking']:DeleteVehicleUsingData(nil, nil, actualPlate, true)
        end

        return deformations
    end

    -- Internal: trusted caller passed src=nil.
    if netId then
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if not vehicle or not DoesEntityExist(vehicle) then return end
        if Config.UsesAdvancedParking() then
            exports['AdvancedParking']:DeleteVehicleUsingData(nil, netId, plate)
        else
            DeleteEntity(vehicle)
        end
        return Entity(vehicle).state.deformations
    end

    if plate then
        local target = MSK.Trim(plate, true)
        local deformations
        for _, vehicle in pairs(GetAllVehicles()) do
            if DoesEntityExist(vehicle) and MSK.Trim(GetVehicleNumberPlateText(vehicle), true) == target then
                deformations = Entity(vehicle).state.deformations
                DeleteEntity(vehicle)
                break
            end
        end
        if Config.UsesAdvancedParking() then
            exports['AdvancedParking']:DeleteVehicleUsingData(nil, nil, plate, true)
        end
        return deformations
    end
end
