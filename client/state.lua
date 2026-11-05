----------------------------------------------------------------
-- Vehicle properties
--
-- The FORMAT has to match the framework: these properties are written back into
-- the framework's vehicle table, and every other garage on the server reads
-- them from there. ESX has its own layout, QBCore and Qbox use the ox_lib one.
-- Handing an ox_lib table to an ESX garage produces a car without mods, or none
-- at all.
--
-- ESX is fetched lazily, so this resource no longer needs it to start.
----------------------------------------------------------------
local esxCache

local function esx()
    if esxCache ~= nil then return esxCache or nil end

    local ok, core = pcall(function() return exports['es_extended']:getSharedObject() end)
    esxCache = (ok and core) or false

    return esxCache or nil
end

local function isEsx()
    return MSK.Bridge.Framework.Type == 'ESX' and esx() ~= nil
end

function GetVehicleProps(vehicle)
    if isEsx() then return esx().Game.GetVehicleProperties(vehicle) end

    return lib.getVehicleProperties(vehicle)
end

function SetVehicleProps(vehicle, props)
    if isEsx() then return esx().Game.SetVehicleProperties(vehicle, props) end

    return lib.setVehicleProperties(vehicle, props)
end

-- ESX.Game.GetVehiclesInArea has no ox_lib equivalent with the same signature,
-- so this is the native walk both of them do internally.
function GetVehiclesInArea(coords, radius)
    local found = {}

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if #(coords - GetEntityCoords(vehicle)) <= radius then
            found[#found + 1] = vehicle
        end
    end

    return found
end

State = State or {}

State.currentGarage   = nil  -- Config.Garages entry the player stands on
State.currentImpound  = nil  -- Config.Impounds entry the player stands on
State.customGarage    = nil  -- third-party openGarage() payload (UI-only)
State.customImpound   = nil  -- third-party openImpound() payload (UI-only)
State.isNuiOpen       = false
State.buttonPressed   = false
State.isDead          = false

-- Death check honouring third-party medical scripts that override the "is the player dead / downed" semantics.
function State.IsDead()
    local dead = State.isDead

    if GetResourceState('visn_are') ~= 'missing' then
        local buf = exports.visn_are:GetHealthBuffer()
        if buf and buf.unconscious then dead = true end
    end

    if GetResourceState('osp_ambulance') ~= 'missing' then
        local data = exports.osp_ambulance:GetAmbulanceData(GetPlayerServerId(PlayerId()))
        if data and (data.isDead or data.inLastStand) then dead = true end
    end

    return dead
end
