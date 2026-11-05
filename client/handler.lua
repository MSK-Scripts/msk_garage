-- This will be triggered after set to stored in database but before the vehicle gets deleted, you can add extra events here.
RegisterNetEvent('msk_garage:vehicleParkedIn', function(vehicle, plate, fuel, props, currGarage)
    -- Do something here
end)

-- This will be triggered after the vehicle is spawned, you can add extra events here.
RegisterNetEvent('msk_garage:vehicleParkedOut', function(vehicle, plate, fuel, props, currGarage)
    -- Do something here
end)

-- This will be triggered after the vehicle is spawned, you can add extra events here.
RegisterNetEvent('msk_garage:vehicleParkedOutImpound', function(vehicle, plate, fuel, props, currImpound)
    -- Do something here
end)