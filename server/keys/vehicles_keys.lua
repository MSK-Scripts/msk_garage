Keys.RegisterAdapter('vehicles_keys', {
    HasKey = function(xPlayer, plate, _model)
        local keys = exports['vehicles_keys']:getPlayerIdKeys(xPlayer.source) or {}
        local trimmed = MSK.Trim(plate, true)
        for kPlate in pairs(keys) do
            if MSK.Trim(kPlate:upper(), true) == trimmed then return true end
        end
        return false
    end,

    GetKeys = function(xPlayer)
        local keys = exports['vehicles_keys']:getPlayerIdKeys(xPlayer.source) or {}
        local out = {}
        for plate in pairs(keys) do
            out[#out + 1] = { plate = plate:upper() }
        end
        return out
    end,

    -- vehicles_keys only exposes a per-identifier remove, so this drops the keys
    -- of the given owner only. Second-key holders of the same plate keep theirs.
    -- Used to clean up after deleted job vehicles (see the
    -- msk_garage:jobVehiclesDeleted hook in server/handler.lua).
    RemoveAllKeys = function(identifier, plate)
        exports['vehicles_keys']:removeKeysFromIdentifier(identifier, plate)
    end,
})
