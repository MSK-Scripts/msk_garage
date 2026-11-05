AdminSync = AdminSync or {}

-- Applies DB-authoritative definitions and rebuilds the world objects live.
local function applyDefs(defs)
    if type(defs) ~= 'table' then return end

    if type(defs.garages) == 'table' then Config.Garages = defs.garages end
    if type(defs.impounds) == 'table' then Config.Impounds = defs.impounds end
    if type(defs.settings) == 'table' then
        for k, v in pairs(defs.settings) do Config[k] = v end
        if type(Config.DefaultGarages) == 'table' then
            Config.DefaultGarage = Config.DefaultGarages.land or Config.DefaultGarage
        end
    end

    -- Drop stale references to (possibly deleted) defs before rebuilding.
    State.currentGarage = nil
    State.currentImpound = nil

    PointsCtl.RemoveAll()
    PointsCtl.Build()
    Blips.Refresh()
end

AdminSync.Apply = applyDefs

-- Server broadcast after any admin mutation.
RegisterNetEvent('msk_garage:syncDefinitions', function(defs)
    applyDefs(defs)
end)

-- Pull the authoritative definitions once on join (covers edits made before the
-- player connected; the static client config may otherwise be stale).
CreateThread(function()
    while not MSK.IsPlayerLoaded() do Wait(250) end
    Wait(1500) -- let client/main.lua bootstrap build first
    local defs = MSK.Trigger('msk_garage:admin:getDefinitions')
    applyDefs(defs)
end)
