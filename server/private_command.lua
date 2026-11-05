--[[============================================================
    PRIVATE GARAGE COMMANDS

    The owner normally manages access from the garage UI (the Access button,
    see web/src/components/AccessDialog.tsx). These commands do the same thing
    without opening a garage, which matters in three cases: from rcon or
    txAdmin, for an admin who has to fix a garage they do not own, and for
    players who cannot reach the garage right now.

      /<privateAccessCommand>                       list my private garages
      /<privateAccessCommand> <garageId>            list who may use it
      /<privateAccessCommand> <garageId> add <id>   grant, by server id
      /<privateAccessCommand> <garageId> remove <id>revoke, by server id
                                                    or by identifier

      /<privateOwnerCommand> <garageId> <serverId>  set the owner  (garage.edit)
      /<privateOwnerCommand> <garageId> clear       back to public (garage.edit)
============================================================]]--

local function notify(src, message, typ)
    Config.Notification(src, message, typ or 'info')
end

--- Server id -> identifier. Players type the id they see in the scoreboard;
--- what gets stored is always the identifier, because a server id belongs to
--- a session and is handed to somebody else after a reconnect.
local function identifierFromServerId(value)
    local id = tonumber(value)
    if not id then return nil end
    local xPlayer = MSK.GetPlayer(id)
    if not xPlayer then return nil end
    return xPlayer.identifier
end

local function nameOf(identifier)
    return Utils.GetOwnerName(identifier) or identifier
end

----------------------------------------------------------------
-- Player command
----------------------------------------------------------------
local function listOwnGarages(src, xPlayer)
    local found = 0
    for id, def in pairs(Config.Garages) do
        if Private.EffectiveOwner(def) == xPlayer.identifier then
            found = found + 1
            notify(src, ('%s  (%s)'):format(def.label or id, id))
        end
    end
    if found == 0 then
        notify(src, Utils.T('private_no_own_garage'), 'error')
    end
end

local function listAccess(src, garageId)
    local rows = Private.ListAccess(garageId)
    if #rows == 0 then
        notify(src, Utils.T('private_access_empty'))
        return
    end
    for _, row in ipairs(rows) do
        notify(src, ('%s  (%s)'):format(row.name or row.identifier, row.identifier))
    end
end

local function registerPlayerCommand(name)
    MSK.RegisterCommand(name, function(source, args)
        local src = source
        if src == 0 then
            print('^3[msk_garage]^0 This command can only be used in-game.')
            return
        end

        local xPlayer = MSK.GetPlayer(src)
        if not xPlayer then return end

        local garageId = args[1]
        if not garageId or garageId == '' then
            listOwnGarages(src, xPlayer)
            return
        end

        local def = Config.Garages[garageId]
        if not def then
            notify(src, Utils.T('private_unknown_garage'), 'error')
            return
        end

        -- Only the owner manages access. Someone who merely has access cannot
        -- pass it on, otherwise the first roommate could hand the house to the
        -- whole server.
        if Private.EffectiveOwner(def) ~= xPlayer.identifier then
            notify(src, Utils.T('private_not_owner'), 'error')
            return
        end

        local action = args[2]
        if not action then
            listAccess(src, garageId)
            return
        end

        local target = args[3]
        if not target then
            notify(src, Utils.T('private_usage', name), 'error')
            return
        end

        if action == 'add' then
            local identifier = identifierFromServerId(target)
            if not identifier then
                notify(src, Utils.T('private_player_not_found'), 'error')
                return
            end
            if identifier == xPlayer.identifier then
                notify(src, Utils.T('private_self'), 'error')
                return
            end

            local ok, err = Private.GrantAccess(garageId, identifier, xPlayer.identifier)
            if not ok then
                notify(src, Utils.T(err == 'limit_reached' and 'private_limit' or 'private_failed'), 'error')
                return
            end
            notify(src, Utils.T('private_granted', nameOf(identifier)), 'success')

            local other = MSK.GetPlayerFromIdentifier(identifier)
            if other and other.source then
                notify(other.source, Utils.T('private_granted_you', def.label or garageId), 'success')
            end

        elseif action == 'remove' then
            -- Accept an identifier too: the player being removed is usually
            -- offline, so there is no server id to type.
            local identifier = identifierFromServerId(target) or target

            if not (Private.access[garageId] and Private.access[garageId][identifier]) then
                notify(src, Utils.T('private_not_in_list'), 'error')
                return
            end

            Private.RevokeAccess(garageId, identifier)
            notify(src, Utils.T('private_revoked', nameOf(identifier)), 'success')

            local other = MSK.GetPlayerFromIdentifier(identifier)
            if other and other.source then
                notify(other.source, Utils.T('private_revoked_you', def.label or garageId), 'error')
            end

        else
            notify(src, Utils.T('private_usage', name), 'error')
        end
    end, {
        help = 'Manage access to your private garage',
        restricted = false,
    })
end

----------------------------------------------------------------
-- Admin command
----------------------------------------------------------------
local function registerOwnerCommand(name)
    MSK.RegisterCommand(name, function(source, args)
        local src = source

        -- Console counts as full admin: this is how a server owner fixes a
        -- garage nobody can reach any more.
        if src ~= 0 and not AdminPerms.Has(src, 'garage.edit') then
            notify(src, Utils.T('private_no_permission'), 'error')
            return
        end

        local garageId, target = args[1], args[2]
        if not garageId or not target then
            local usage = ('Usage: /%s <garageId> <serverId|clear>'):format(name)
            if src == 0 then print(usage) else notify(src, usage, 'error') end
            return
        end

        if not Config.Garages[garageId] then
            if src == 0 then print('Unknown garage: ' .. garageId)
            else notify(src, Utils.T('private_unknown_garage'), 'error') end
            return
        end

        if target == 'clear' then
            Private.SetOwner(garageId, nil)
            local msg = ('%s is public again.'):format(garageId)
            if src == 0 then print(msg) else notify(src, Utils.T('private_owner_cleared'), 'success') end
            return
        end

        local identifier = identifierFromServerId(target)
        if not identifier then
            if src == 0 then print('Player not online: ' .. tostring(target))
            else notify(src, Utils.T('private_player_not_found'), 'error') end
            return
        end

        Private.SetOwner(garageId, identifier)
        local msg = ('%s now belongs to %s.'):format(garageId, nameOf(identifier))
        if src == 0 then print(msg) else notify(src, Utils.T('private_owner_set', nameOf(identifier)), 'success') end
    end, {
        help = 'Set or clear the owner of a private garage',
        restricted = false, -- gated in the handler, same reasoning as the dashboard command
    })
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(1000) -- settings come from the DB
        registerPlayerCommand(Config.privateAccessCommand or 'garagezugriff')
        registerOwnerCommand(Config.privateOwnerCommand or 'garageowner')
    end)
end)
