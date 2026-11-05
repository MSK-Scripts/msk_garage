-- Opens the admin dashboard NUI when the server grants access.
RegisterNetEvent('msk_garage:admin:open', function(payload)
    if State.isNuiOpen then return end
    State.isNuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAdmin', data = payload })
end)

-- Safety net: on (re)start, force-release any NUI focus left stuck from a
-- previous session (e.g. a frozen UI), so a `restart msk_garage` always frees
-- the cursor instead of leaving it captured on a blank screen.
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if State then State.isNuiOpen = false end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
