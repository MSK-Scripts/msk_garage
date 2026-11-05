Keys.RegisterAdapter('msk_vehiclekeys', {
    HasKey = function(xPlayer, plate, model)
        return exports['msk_vehiclekeys']:HasPlayerKey({ identifier = xPlayer.identifier }, plate, model)
    end,

    GetKeys = function(xPlayer)
        local raw = exports['msk_vehiclekeys']:GetPlayerKeys({ identifier = xPlayer.identifier }) or {}
        local out = {}
        for i = 1, #raw do
            out[#out + 1] = { plate = raw[i].plate, model = raw[i].model, type = raw[i].type }
        end
        return out
    end,

    -- Drops every key type (primary/secondary/temporary) of ALL players for this
    -- plate, so the identifier is not needed. The export trims the plate itself.
    RemoveAllKeys = function(_identifier, plate)
        exports['msk_vehiclekeys']:RemoveAllExistingKeys(plate)
    end,
})
