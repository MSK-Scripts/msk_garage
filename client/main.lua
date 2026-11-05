-- msk_core raises this on every framework, the two esx: events only ever
-- arrived on ESX.
AddEventHandler('msk_core:onPlayerDeath', function() State.isDead = true end)
AddEventHandler('esx:onPlayerSpawn', function() State.isDead = false end)
AddEventHandler('playerSpawned', function() State.isDead = false end)

local bootstrapped = false

local function bootstrap()
    if bootstrapped then return end
    bootstrapped = true

    while not MSK.IsPlayerLoaded() do Wait(200) end

    Blips.Refresh()
    PointsCtl.Build()
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    bootstrap()
end)

-- msk_core keeps the player data itself and raises these three on every
-- framework, so the local copy this file used to hold is gone. Whatever needs
-- the player asks MSK.GetPlayerData() or MSK.GetPlayerJob().
RegisterNetEvent('msk_core:playerLoaded', function()
    Wait(1000)
    Blips.Refresh()
end)

RegisterNetEvent('msk_core:playerLogout', function()
    Blips.RemoveAll()
    Peds.RemoveAll()
end)

RegisterNetEvent('msk_core:setJob', function()
    Blips.Refresh()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    PointsCtl.RemoveAll()
    Blips.RemoveAll()
    Peds.RemoveAll()
end)
