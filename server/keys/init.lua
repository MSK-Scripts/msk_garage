Keys = Keys or {}

local adapters = {}

function Keys.RegisterAdapter(name, adapter)
    adapters[name] = adapter
end

local function current()
    if not Config.VehicleKeys.enable then return nil end
    local name = Config.VehicleKeys.script
    local adapter = adapters[name]
    if not adapter then return nil end
    if GetResourceState(name) ~= 'started' then return nil end
    return adapter
end

-- Returns whether the player holds a key for the given plate.
function Keys.HasKey(xPlayer, plate, model)
    local adapter = current()
    if not adapter then return false end
    local ok, result = pcall(adapter.HasKey, xPlayer, plate, model)
    if not ok then
        Utils.Log('error', 'Keys.HasKey adapter error:', tostring(result))
        return false
    end
    return result == true
end

-- Removes the keys of `plate` from the configured key script. Used to clean up
-- after vehicles that no longer exist (see the msk_garage:jobVehiclesDeleted hook
-- in server/handler.lua).
--
-- `identifier` is the owner the cleanup runs for. How far an adapter reaches
-- depends on what its script exposes: msk_vehiclekeys and VehicleKeyChain drop the
-- keys of ALL players for that plate and ignore the identifier, vehicles_keys only
-- offers a per-identifier remove and therefore leaves second-key holders alone.
--
-- RemoveAllKeys is OPTIONAL in the adapter contract: an adapter that does not
-- implement it makes this a no-op returning false, so nothing breaks on key
-- scripts whose remove-export isn't wired up.
function Keys.RemoveAllKeys(identifier, plate)
    if type(plate) ~= 'string' or plate == '' then return false end

    local adapter = current()
    if not adapter or not adapter.RemoveAllKeys then
        Utils.Log('debug', '[keys] adapter has no RemoveAllKeys - skipping key cleanup for', plate)
        return false
    end

    local ok, err = pcall(adapter.RemoveAllKeys, identifier, plate)
    if not ok then
        Utils.Log('error', 'Keys.RemoveAllKeys adapter error:', tostring(err))
        return false
    end
    return true
end

-- Returns the list of plates the player has keys for (no DB join - owned_vehicles join happens in server/garages.lua).
function Keys.GetKeys(xPlayer)
    local adapter = current()
    if not adapter then return {} end
    local ok, result = pcall(adapter.GetKeys, xPlayer)
    if not ok or type(result) ~= 'table' then return {} end
    return result
end
