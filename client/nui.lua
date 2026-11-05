NUI = NUI or {}

local function getVehicleClassName(class)
    return Classes.IconForClass(class)
end

-- Is this row a job/faction vehicle? Drives the "Fraktion" filter in the garage.
local function isJobVehicle(job)
    return job ~= nil and job ~= '' and job ~= Config.MySQL.civ
end

-- Spawn name (lower-case) used to resolve a per-model image in the NUI.
local function modelKey(model)
    return (GetDisplayNameFromVehicleModel(model) or ''):lower()
end

-- Per-model vehicle image config handed to the NUI. Images live in the resource
-- folder `vehicle_images/<spawnname>.<ext>` (served via nui://), so server owners
-- can drop their own without a rebuild. The UI falls back to the class icon when
-- a model image is missing or the feature is disabled.
local function vehicleImagesPayload()
    local vi = Config.VehicleImages or {}
    return {
        enable = vi.enable == true,
        base = ('nui://%s/vehicle_images/'):format(GetCurrentResourceName()),
        ext = vi.ext or 'png',
    }
end

local function focusOn()
    SetNuiFocus(true, true)
    State.isNuiOpen = true
end

local function focusOff()
    SetNuiFocus(false, false)
    State.isNuiOpen = false
    State.customGarage = nil
    State.customImpound = nil
end

function NUI.OpenGarage(label, garageId)
    focusOn()

    -- Private garages: may this player hand out access? The client cannot work
    -- this out on its own, the owner identifier is deliberately never sent to
    -- clients, so the server answers. Public garages skip the round trip.
    local canManageAccess = false
    if garageId then
        canManageAccess = MSK.Trigger('msk_garage:private:canManage', garageId) == true
    end

    SendNUIMessage({
        action = 'openUI',
        type = 'parkout',
        translation = Translation[Config.Locale],
        garageTitle = label,
        parkinButton = Utils.T('parkin'),
        parkoutButton = Utils.T('parkout'),
        theme = Config.Theme,
        vehicleImages = vehicleImagesPayload(),
        garageId = garageId,
        canManageAccess = canManageAccess,
    })
end

function NUI.OpenImpound(label)
    focusOn()
    SendNUIMessage({
        action = 'openUI',
        type = 'impound',
        translation = Translation[Config.Locale],
        garageTitle = label,
        theme = Config.Theme,
        vehicleImages = vehicleImagesPayload(),
    })
end

-- Image URLs from Config.GetVehicleImage (export or CDN, config/static.lua), as
-- a plain list for the NUI. A broken hook must never keep a car out of the list.
local function vehicleImageUrls(model, hash)
    if not (Config.VehicleImages and Config.VehicleImages.enable) then return nil end
    if type(Config.GetVehicleImage) ~= 'function' or not model or model == '' then return nil end

    if type(hash) == 'string' then hash = joaat(hash) end
    local ok, result = pcall(Config.GetVehicleImage, model, hash or joaat(model))
    if not ok then
        Utils.Log('error', 'Config.GetVehicleImage failed:', tostring(result))
        return nil
    end

    if type(result) == 'string' then result = { result } end
    if type(result) ~= 'table' then return nil end

    local urls = {}
    for _, url in ipairs(result) do
        if type(url) == 'string' and url ~= '' then urls[#urls + 1] = url end
    end
    return #urls > 0 and urls or nil
end

function NUI.AddVehicle(typ, vehicleData)
    vehicleData.images = vehicleImageUrls(vehicleData.model, vehicleData.modelHash)
    vehicleData.modelHash = nil

    SendNUIMessage({
        action = 'addVehicle',
        type = typ,
        vehicle = vehicleData,
    })
end

function NUI.Refresh(typ)
    SendNUIMessage({ action = 'refreshUI', type = typ })
end

function NUI.Close()
    SendNUIMessage({ action = 'closeUI' })
    -- The React 'closeUI' handler only hides the panel; it does NOT round-trip a
    -- 'closeGarage' callback the way the manual close button does. So when Lua
    -- closes the UI itself (e.g. the warp path after parking a boat out), we must
    -- release NUI focus here — otherwise the cursor stays stuck on screen.
    focusOff()
end

function NUI.NoVehicles(text)
    SendNUIMessage({ action = 'noVehiclesFound', text = text })
end

-- exports for external scripts wanting to open a custom garage
function openGarage(data)
    -- Guard against double-open from the ox_target onSelect path and external
    -- export callers (the hotkey path already gates on this). A re-open would
    -- reset search/fav/renameTarget and re-toggle NUI focus mid-session.
    if State.isNuiOpen then return end
    State.isNuiOpen = true
    local label = data and data.label or State.currentGarage and State.currentGarage.label or 'Garage'

    if data then
        State.customGarage = {
            label        = label,
            id           = data.garageId,
            parking      = data.parking or Config.Parking,
            parkInCoords = data.parkInCoords,
            parkOutCoords = data.parkOutCoords,
            distance     = data.distance or 40.0,
            type         = data.type or { 'car', 'truck' },
            warp         = data.warp,
            jobs         = { enable = false },
        }
    end

    NUI.OpenGarage(label, (data and data.garageId)
        or (State.currentGarage and State.currentGarage.id) or nil)
end
exports('openGarage', openGarage)

function openImpound(data)
    if State.isNuiOpen then return end
    State.isNuiOpen = true
    local label = data and data.label or State.currentImpound and State.currentImpound.label or 'Impound'

    if data then
        State.customImpound = {
            label         = label,
            parkOutCoords = data.parkOutCoords,
            type          = data.type or { 'car', 'truck' },
            warp          = data.warp,
            fee           = data.fee and { enable = true, price = data.fee } or { enable = false },
        }
    end

    NUI.OpenImpound(label)
end
exports('openImpound', openImpound)

-- Incoming NUI callbacks.
RegisterNUICallback('closeGarage', function(_data, cb)
    focusOff(); cb('ok')
end)

----------------------------------------------------------------
-- Private garage access, managed by the owner from the garage UI.
-- The server re-checks ownership on every one of these, see server/api.lua.
----------------------------------------------------------------
RegisterNUICallback('access-list', function(data, cb)
    cb(MSK.Trigger('msk_garage:private:list', data and data.garageId) or { ok = false })
end)

RegisterNUICallback('access-grant', function(data, cb)
    cb(MSK.Trigger('msk_garage:private:grant', data and data.garageId, data and data.serverId)
        or { ok = false })
end)

RegisterNUICallback('access-revoke', function(data, cb)
    cb(MSK.Trigger('msk_garage:private:revoke', data and data.garageId, data and data.identifier)
        or { ok = false })
end)

-- Park-out list: show what the player has stored here.
RegisterNUICallback('show-parkout', function(_data, cb)
    local garage = State.currentGarage or State.customGarage
    local owned = MSK.Trigger('msk_garage:getOwnedVehicles', garage)

    if not owned or #owned == 0 then
        NUI.NoVehicles(Utils.T('no_vehicles')); cb('ok'); return
    end

    for k, data in pairs(owned) do
        local model = type(data.vehicle) == 'table' and data.vehicle.model
        if model then
            local isStored = Utils.GetIsStored(data.stored)
            local label    = GetLabelText(GetDisplayNameFromVehicleModel(model))
            NUI.AddVehicle('parkout', {
                id       = k,
                plate    = data.plate,
                isStored = isStored,
                label    = data.name or label,
                fuel     = data.fuel,
                maxFuel  = Config.UsesMskFuel() and MSK.Round(Config.GetModelMaxFuel(model)) or nil,
                isFav    = data.isFav,
                type     = getVehicleClassName(GetVehicleClassFromName(model)),
                model    = modelKey(model),
                modelHash = model,
                isJob    = isJobVehicle(data.job),
                keyed    = data.keyed == true,
                keyOwner = data.keyOwner,
            })
        end
    end
    cb('ok')
end)

-- Park-in list: show eligible vehicles in spawn range.
RegisterNUICallback('show-parkin', function(_data, cb)
    -- The garage can go nil mid-session if the player is displaced out of the
    -- point (explosion/teleport) while the panel is open. Guard + pcall so this
    -- always reaches cb('ok') and never throws before releasing NUI focus.
    local garage = State.currentGarage or State.customGarage
    if not garage then
        NUI.NoVehicles(Utils.T('no_vehicles_found')); cb('ok'); return
    end

    local ok = pcall(function()
        local parkInLoc, range
        if State.customGarage then
            parkInLoc = vector3(State.customGarage.parkInCoords.x, State.customGarage.parkInCoords.y, State.customGarage.parkInCoords.z)
            range = State.customGarage.distance
        else
            local loc = garage.locations[1]
            parkInLoc = vector3(loc.x, loc.y, loc.z)
            range = garage.distance
        end

        local vehicles = GetVehiclesInArea(parkInLoc, range)
        if #vehicles == 0 then
            NUI.NoVehicles(Utils.T('no_vehicles_found')); return
        end

        local anyEligible = false
        for k, vehicle in pairs(vehicles) do
            local plate = GetVehicleNumberPlateText(vehicle)
            local isOwned, data = MSK.Trigger('msk_garage:isOwned', plate, garage.jobs, GetEntityModel(vehicle), garage.id)

            -- DoesEntityExist guard: the msk_garage:isOwned trigger above is a
            -- blocking server roundtrip, during which the streamed vehicle handle
            -- can go invalid. msk_fuel's exports assert on a missing entity, so we
            -- must not call Config.GetFuel / the fuel exports on a dead handle.
            if isOwned and data and DoesEntityExist(vehicle) and Classes.TypeMatches(garage.type, data.type) then
                anyEligible = true
                local label = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
                local fuel = MSK.Round(Config.GetFuel(vehicle))
                local maxFuel = Config.UsesMskFuel() and MSK.Round(exports.msk_fuel:GetVehicleMaxFuel(vehicle)) or nil
                NUI.AddVehicle('parkin', {
                    id    = k,
                    plate = plate,
                    label = data and data.name or label,
                    fuel  = fuel,
                    maxFuel = maxFuel,
                    isFav = data and data.isFav or 0,
                    type  = getVehicleClassName(GetVehicleClass(vehicle)),
                    model = modelKey(GetEntityModel(vehicle)),
                    modelHash = GetEntityModel(vehicle),
                })
            end
        end

        if not anyEligible then NUI.NoVehicles(Utils.T('no_vehicles_found')) end
    end)

    if not ok then NUI.NoVehicles(Utils.T('no_vehicles_found')) end
    cb('ok')
end)

-- Park-in submit (one vehicle at a time).
RegisterNUICallback('park-in', function(data, cb)
    if State.buttonPressed then cb('ok'); return end
    State.buttonPressed = true

    -- pcall so an error in the spawn pipeline can't leave buttonPressed stuck true (which would freeze the UI for the rest of the session).
    pcall(function()
        local garage = State.currentGarage or State.customGarage
        local parkInLoc

        if State.customGarage then
            parkInLoc = vector3(State.customGarage.parkInCoords.x, State.customGarage.parkInCoords.y, State.customGarage.parkInCoords.z)
        else
            local loc = garage.locations[1]
            parkInLoc = vector3(loc.x, loc.y, loc.z)
        end

        for _, vehicle in pairs(GetVehiclesInArea(parkInLoc, garage.distance)) do
            if GetVehicleNumberPlateText(vehicle) == data.plate then
                VehiclesCtl.ParkIn(vehicle, GetVehicleProps(vehicle), data.plate,
                    tonumber(data.fuel), GetEntityModel(vehicle), VehiclesCtl.GetDeformations(vehicle))
                break
            end
        end
    end)

    State.buttonPressed = false
    cb('ok')
end)

-- Park-out submit.
RegisterNUICallback('park-out', function(data, cb)
    if State.buttonPressed then cb('ok'); return end
    State.buttonPressed = true
    pcall(function()
        VehiclesCtl.ParkOut(data.plate, Utils.GetIsStored(data.isStored))
    end)
    State.buttonPressed = false
    cb('ok')
end)

-- Impound list: vehicles with stored=0 (lost on map).
RegisterNUICallback('show-impound', function(_data, cb)
    local impound = State.currentImpound or State.customImpound
    local owned = MSK.Trigger('msk_garage:getOwnedVehicles', impound)

    local fee
    if impound and impound.fee and impound.fee.enable then fee = impound.fee.price end

    if not owned or #owned == 0 then
        NUI.NoVehicles(Utils.T('no_vehicles')); cb('ok'); return
    end

    for k, data in pairs(owned) do
        local model = type(data.vehicle) == 'table' and data.vehicle.model
        if model and Utils.GetIsStored(data.stored) == 0 then
            local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
            local position
            if Config.UsesAdvancedParking() then
                position = exports['AdvancedParking']:GetVehiclePosition(data.plate)
            else
                position = MSK.Trigger('msk_garage:getVehicleCoords', data.plate)
            end

            NUI.AddVehicle('impound', {
                id       = k,
                plate    = data.plate,
                label    = data.name or label,
                canTrack = position,
                fuel     = data.fuel,
                maxFuel  = Config.UsesMskFuel() and MSK.Round(Config.GetModelMaxFuel(model)) or nil,
                type     = getVehicleClassName(GetVehicleClassFromName(model)),
                model    = modelKey(model),
                modelHash = model,
                fee      = fee,
                -- AdvancedParking still tracks this plate -> card renders locked.
                locked   = data.apBlocked == true,
                isJob    = isJobVehicle(data.job),
                keyed    = data.keyed == true,
                keyOwner = data.keyOwner,
            })
        end
    end
    cb('ok')
end)

RegisterNUICallback('impound-park-out', function(data, cb)
    if State.buttonPressed then cb('ok'); return end
    State.buttonPressed = true
    pcall(function()
        VehiclesCtl.ParkOutImpound(data.plate, Utils.GetIsStored(data.isStored))
    end)
    State.buttonPressed = false
    cb('ok')
end)

RegisterNUICallback('impound-track', function(data, cb)
    local position
    if Config.UsesAdvancedParking() then
        position = exports['AdvancedParking']:GetVehiclePosition(data.plate)
    else
        position = MSK.Trigger('msk_garage:getVehicleCoords', data.plate)
    end
    if position then SetNewWaypoint(position[1] or position.x, position[2] or position.y) end
    cb('ok')
end)

RegisterNUICallback('toggle-fav', function(data, cb)
    Utils.Log('debug', 'toggle-fav', data.plate, data.isFav)
    MSK.Trigger('msk_garage:toggleFav', data.plate, data.isFav)
    cb('ok')
end)

RegisterNUICallback('rename-vehicle', function(data, cb)
    Utils.Log('debug', 'rename', data.plate, data.nickname)
    MSK.Trigger('msk_garage:rename', data.plate, data.nickname)
    cb('ok')
end)

-- Public client export used by external scripts to look up the home garage of a plate.
function GetVehicleGarage(plate)
    return MSK.Trigger('msk_garage:getVehicleGarage', plate)
end
exports('GetVehicleGarage', GetVehicleGarage)
