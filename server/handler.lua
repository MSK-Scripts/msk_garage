RegisterNetEvent('msk_garage:vehicleParkedIn', function(netId, plate, fuel, props, currGarage)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    -- hook for customer extensions
end)

RegisterNetEvent('msk_garage:vehicleParkedOut', function(netId, plate, fuel, props, currGarage)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    -- hook for customer extensions
end)

RegisterNetEvent('msk_garage:vehicleParkedOutImpound', function(netId, plate, fuel, props, currImpound)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    -- hook for customer extensions
end)

-- Fires after job vehicles were deleted because their owner left the job
-- (Config.deleteJobVehiclesOnJobChange). `plates` is the list of deleted plates.
-- Use this to clean up whatever else references them, e.g. vehicle keys.
-- Serverside only, therefore AddEventHandler and not RegisterNetEvent.
AddEventHandler('msk_garage:jobVehiclesDeleted', function(identifier, jobName, plates)
    for _, plate in ipairs(plates) do
        Keys.RemoveAllKeys(identifier, plate)
    end
end)
