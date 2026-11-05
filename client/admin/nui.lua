-- NUI callbacks for the admin dashboard. CRUD callbacks forward to the gated
-- server callbacks and return the server response verbatim.

local function round(n, dp)
    local m = 10 ^ (dp or 2)
    return math.floor(n * m + 0.5) / m
end

local function forward(event)
    return function(data, cb)
        local res = MSK.Trigger(event, data)
        cb(res or { ok = false, err = 'no_response' })
    end
end

-- Capture the player's current position for a coordinate field.
RegisterNUICallback('admin:getCurrentCoords', function(_data, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    cb({ x = round(c.x, 2), y = round(c.y, 2), z = round(c.z, 2), w = round(h, 2) })
end)

RegisterNUICallback('admin:close', function(_data, cb)
    SetNuiFocus(false, false)
    State.isNuiOpen = false
    cb('ok')
end)

RegisterNUICallback('admin:bootstrap', forward('msk_garage:admin:bootstrap'))
RegisterNUICallback('admin:garage:save', forward('msk_garage:admin:garage:save'))
RegisterNUICallback('admin:garage:delete', forward('msk_garage:admin:garage:delete'))
RegisterNUICallback('admin:impound:save', forward('msk_garage:admin:impound:save'))
RegisterNUICallback('admin:impound:delete', forward('msk_garage:admin:impound:delete'))
RegisterNUICallback('admin:settings:save', forward('msk_garage:admin:settings:save'))
RegisterNUICallback('admin:perms:saveGroup', forward('msk_garage:admin:perms:saveGroup'))
RegisterNUICallback('admin:perms:deleteGroup', forward('msk_garage:admin:perms:deleteGroup'))
RegisterNUICallback('admin:perms:dashboardGroups', forward('msk_garage:admin:perms:dashboardGroups'))
RegisterNUICallback('admin:perms:validateGroup', forward('msk_garage:admin:perms:validateGroup'))
