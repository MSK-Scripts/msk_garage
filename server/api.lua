MSK.Register('msk_garage:getOwnedVehicles', function(source, currentGarage)
    local xPlayer = MSK.GetPlayer(source)
    if not xPlayer or type(currentGarage) ~= 'table' then return {} end
    if currentGarage.impoundId or not currentGarage.id then
        local def = Validation.GetImpound(currentGarage.impoundId) or CustomSessions.GetImpound(source)
        if not def then return {} end
        return Garages.ForImpound(xPlayer, def)
    end

    local def = Validation.GetGarage(currentGarage.id) or CustomSessions.GetGarage(source)
    if not def then return {} end

    -- A private garage must not list vehicles for anyone but its owner and the
    -- players they granted access to. The rows returned here are always the
    -- caller own vehicles, so this leaks nothing either way, but an outsider
    -- being able to browse a garage they cannot use is confusing on its own.
    if not Private.HasAccess(xPlayer.identifier, def) then return {} end

    return Garages.ForGarage(xPlayer, def)
end)

----------------------------------------------------------------
-- Private garages: the owner manages access from the garage UI.
--
-- Every callback re-checks ownership. The UI hides the button for everyone
-- else, but a client can trigger these directly, so hiding it is comfort and
-- not security. Deliberately no proximity check: managing your own garage from
-- anywhere is convenient and gives nothing away.
----------------------------------------------------------------
local function ownedGarage(source, garageId)
    local xPlayer = MSK.GetPlayer(source)
    if not xPlayer or type(garageId) ~= 'string' then return nil end

    local def = Config.Garages[garageId]
    if not def or not Private.IsPrivate(def) then return nil end
    if Private.EffectiveOwner(def) ~= xPlayer.identifier then return nil end

    return def, xPlayer
end

MSK.Register('msk_garage:private:canManage', function(source, garageId)
    return ownedGarage(source, garageId) ~= nil
end)

MSK.Register('msk_garage:private:list', function(source, garageId)
    if not ownedGarage(source, garageId) then return { ok = false, err = 'not_owner' } end
    return { ok = true, list = Private.ListAccess(garageId) }
end)

MSK.Register('msk_garage:private:grant', function(source, garageId, serverId)
    local _, xPlayer = ownedGarage(source, garageId)
    if not xPlayer then return { ok = false, err = 'not_owner' } end

    -- The UI sends the server id the player typed; what gets stored is always
    -- the identifier behind it.
    local target = MSK.GetPlayer(tonumber(serverId) or -1)
    if not target then return { ok = false, err = 'player_not_found' } end
    if target.identifier == xPlayer.identifier then return { ok = false, err = 'self' } end

    local ok, err = Private.GrantAccess(garageId, target.identifier, xPlayer.identifier)
    if not ok then return { ok = false, err = err or 'failed' } end

    if target.source then
        Config.Notification(target.source,
            Utils.T('private_granted_you', Config.Garages[garageId].label or garageId), 'success')
    end
    return { ok = true, list = Private.ListAccess(garageId) }
end)

MSK.Register('msk_garage:private:revoke', function(source, garageId, identifier)
    local _, xPlayer = ownedGarage(source, garageId)
    if not xPlayer then return { ok = false, err = 'not_owner' } end
    if type(identifier) ~= 'string' or identifier == '' then return { ok = false, err = 'bad_input' } end

    Private.RevokeAccess(garageId, identifier)

    local other = MSK.GetPlayerFromIdentifier(identifier)
    if other and other.source then
        Config.Notification(other.source,
            Utils.T('private_revoked_you', Config.Garages[garageId].label or garageId), 'error')
    end
    return { ok = true, list = Private.ListAccess(garageId) }
end)

MSK.Register('msk_garage:isOwned', function(source, plate, jobs, model, garageId)
    local xPlayer = MSK.GetPlayer(source)
    if not xPlayer then return false end
    return Garages.IsOwnedByPlayer(xPlayer, plate, jobs or { enable = false }, model, garageId)
end)

MSK.Register('msk_garage:getVehicleCoords', function(source, plate)
    return Vehicles.GetWorldCoords(source, plate)
end)

MSK.Register('msk_garage:getVehicleGarage', function(source, plate)
    -- Gate on ownership: without this any client could resolve the home garage of
    -- an arbitrary plate (info-disclosure). The server-side Garages.GetVehicleGarage
    -- stays ungated for trusted server-to-server callers.
    local xPlayer = MSK.GetPlayer(source)
    if not xPlayer then return end
    if not Vehicles.LoadOwned(xPlayer, plate, nil) then return end
    return Garages.GetVehicleGarage(plate)
end)

MSK.Register('msk_garage:parkIn', function(source, payload)
    if type(payload) ~= 'table' then return false end
    return Vehicles.ParkIn(source, payload) == true
end)

MSK.Register('msk_garage:parkOut', function(source, payload)
    if type(payload) ~= 'table' then return nil end
    return Vehicles.ParkOut(source, payload)
end)

MSK.Register('msk_garage:parkOutImpound', function(source, payload)
    if type(payload) ~= 'table' then return nil end
    return Vehicles.ParkOutFromImpound(source, payload)
end)

MSK.Register('msk_garage:claimSpawn', function(source, plate, netId)
    return Vehicles.ClaimSpawn(source, plate, netId)
end)

MSK.Register('msk_garage:confirmProps', function(source, plate)
    return Vehicles.ConfirmProps(source, plate)
end)

MSK.Register('msk_garage:rollbackSpawn', function(source, plate)
    return Vehicles.RollbackSpawn(source, plate)
end)

MSK.Register('msk_garage:rename', function(source, plate, nickname)
    Vehicles.Rename(source, plate, nickname)
    return true
end)

MSK.Register('msk_garage:toggleFav', function(source, plate, isFav)
    Vehicles.ToggleFav(source, plate, isFav)
    return true
end)

MSK.Register('msk_garage:deleteVehicle', function(source, netId, plate, model)
    return Vehicles.DeleteEntity(source, netId, plate, model)
end)
