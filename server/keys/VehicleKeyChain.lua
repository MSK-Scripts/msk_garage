Keys.RegisterAdapter('VehicleKeyChain', {
    HasKey = function(xPlayer, plate, _model)
        return exports['VehicleKeyChain']:IsKeyOwnerUsingIdentifier(xPlayer.identifier, plate)
    end,

    GetKeys = function(xPlayer)
        local raw = exports['VehicleKeyChain']:GetPlayerKeys(xPlayer.source) or {}
        local out = {}
        for i = 1, #raw do
            out[#out + 1] = { plate = raw[i][1], model = raw[i][2] }
        end
        return out
    end,

    -- Drops the keys of ALL players for this plate, so the identifier is not
    -- needed. Used to clean up after deleted job vehicles (see the
    -- msk_garage:jobVehiclesDeleted hook in server/handler.lua).
    RemoveAllKeys = function(_identifier, plate)
        exports['VehicleKeyChain']:RemoveAllKeysUsingPlate(plate)
    end,
})
