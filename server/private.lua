Private = Private or {}

--[[============================================================
    PRIVATE GARAGES

    A garage is private as soon as it has an owner. Everything else keeps
    working exactly as before, so an untouched server never notices this file.

    Access is granted to
      1. the owner (msk_garage_garages.owner, or the housing script when
         integration is enabled and knows the house), and
      2. everyone listed in msk_garage_private_access.

    TWO SPEEDS, ON PURPOSE:
      * The GATE (park in/out, vehicle list) asks the housing bridge, so a
        house sale takes effect at once even in pull-only setups.
      * VISIBILITY (which blips/points a client receives) is answered purely
        from RAM. Asking the housing script once per private garage per join
        would mean hundreds of queries on a server with hundreds of houses.
        The periodic sync below mirrors housing owners into our own column so
        both paths agree.
============================================================]]--

-- [garageId] = { [identifier] = true }
Private.access = {}

----------------------------------------------------------------
-- Loading
----------------------------------------------------------------
function Private.Load()
    Private.access = {}
    local rows = MySQL.query.await(
        'SELECT `garage_id`, `identifier` FROM `msk_garage_private_access`') or {}
    for _, row in ipairs(rows) do
        local g = Private.access[row.garage_id]
        if not g then g = {}; Private.access[row.garage_id] = g end
        g[row.identifier] = true
    end
end

----------------------------------------------------------------
-- Reading
----------------------------------------------------------------
function Private.IsPrivate(def)
    if type(def) ~= 'table' then return false end
    local owner = def.owner
    return type(owner) == 'string' and owner ~= ''
end

--- The owner that counts right now. The housing script wins when integration
--- is on AND actually answers; a stopped or silent housing script falls back
--- to the stored owner. Never the other way round: a housing outage must not
--- lock every player out of their own garage.
function Private.EffectiveOwner(def)
    if type(def) ~= 'table' then return nil end

    local ref = def.house_ref
    if type(ref) == 'string' and ref ~= '' then
        local fromHousing = Housing.GetOwner(ref)
        if fromHousing then return fromHousing end
    end

    return Private.IsPrivate(def) and def.owner or nil
end

--- Does `identifier` may use garage `def`? Public garages always return true,
--- so callers can ask unconditionally.
function Private.HasAccess(identifier, def)
    if not Private.IsPrivate(def) then return true end
    if type(identifier) ~= 'string' or identifier == '' then return false end

    if Private.EffectiveOwner(def) == identifier then return true end

    local granted = Private.access[def.id]
    if granted and granted[identifier] then return true end

    -- Housing scripts that track roommates themselves are treated as if the
    -- entries were ours. Optional part of the adapter contract, most return nil.
    local ref = def.house_ref
    if type(ref) == 'string' and ref ~= '' then
        local members = Housing.GetMembers(ref)
        if members then
            for _, id in ipairs(members) do
                if id == identifier then return true end
            end
        end
    end

    return false
end

--- RAM-only variant for visibility (blips, points, sync payloads). Deliberately
--- does NOT consult the housing bridge, see the header of this file.
function Private.HasAccessCached(identifier, def)
    if not Private.IsPrivate(def) then return true end
    if type(identifier) ~= 'string' or identifier == '' then return false end
    if def.owner == identifier then return true end
    local granted = Private.access[def.id]
    return (granted and granted[identifier]) == true
end

--- Strips the fields a CLIENT has no business seeing. `owner` is a framework
--- identifier (license:...), `house_ref` is the internal id of the housing
--- script; neither is needed to draw a blip or a point, and shipping the
--- identifier of every house owner to every client would be a plain data leak.
--- Shallow copy is enough, both are top-level scalars.
local function forClient(def)
    local copy = {}
    for k, v in pairs(def) do copy[k] = v end
    copy.owner = nil
    copy.house_ref = nil
    return copy
end

Private.ForClient = forClient

--- Every garage this identifier may see, ready to be sent. Used to build the
--- per-player payload.
function Private.GaragesFor(identifier)
    local out = {}
    for id, def in pairs(Config.Garages) do
        if Private.HasAccessCached(identifier, def) then
            out[id] = Private.IsPrivate(def) and forClient(def) or def
        end
    end
    return out
end

--- The access list of one garage, with resolved player names for the UI.
function Private.ListAccess(garageId)
    local out = {}
    local granted = Private.access[garageId]
    if not granted then return out end
    for identifier in pairs(granted) do
        out[#out + 1] = { identifier = identifier, name = Utils.GetOwnerName(identifier) }
    end
    table.sort(out, function(a, b) return (a.name or a.identifier) < (b.name or b.identifier) end)
    return out
end

----------------------------------------------------------------
-- Vehicle rescue
--
-- The one way a player can permanently lose a car: it sits in a private
-- garage they just lost access to. With Config.Parking = 'specific' the
-- garage column is part of the lookup, so the vehicle becomes invisible
-- everywhere. Before revoking anything, move those rows out.
--
-- Same idea as deleting a garage in the dashboard (server/admin/api.lua).
----------------------------------------------------------------
local function defaultGarageFor(def)
    local cat = AdminPerms.CategoryForType((def.type or {})[1])
    local replacement = (Config.DefaultGarages or {})[cat] or Config.DefaultGarage
    if not Config.Garages[replacement] then replacement = Config.DefaultGarage end
    return replacement
end

--- Moves the vehicles `identifier` has parked in `garageId` to the default
--- garage of their category. Returns how many rows were touched.
function Private.ReassignVehicles(garageId, identifier)
    local def = Config.Garages[garageId]
    if not def or type(identifier) ~= 'string' or identifier == '' then return 0 end

    local replacement = defaultGarageFor(def)
    if not replacement or replacement == garageId then return 0 end

    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `garage` = ? WHERE `garage` = ? AND `%s` = ?'):format(Config.MySQL.table, Config.MySQL.owner),
        { replacement, garageId, identifier }
    ) or 0

    if affected > 0 then
        Utils.Log('debug', ('[private] moved %d vehicle(s) of %s from %s to %s')
            :format(affected, identifier, garageId, replacement))
    end
    return affected
end

--- Same, but for every vehicle in the garage regardless of owner. Used when a
--- garage stops being private or changes hands.
function Private.ReassignAllVehicles(garageId, keepIdentifier)
    local def = Config.Garages[garageId]
    if not def then return 0 end

    local replacement = defaultGarageFor(def)
    if not replacement or replacement == garageId then return 0 end

    local sql = ('UPDATE `%s` SET `garage` = ? WHERE `garage` = ?'):format(Config.MySQL.table)
    local params = { replacement, garageId }
    if type(keepIdentifier) == 'string' and keepIdentifier ~= '' then
        sql = sql .. (' AND `%s` <> ?'):format(Config.MySQL.owner)
        params[#params + 1] = keepIdentifier
    end

    return MySQL.update.await(sql, params) or 0
end

----------------------------------------------------------------
-- Writing
----------------------------------------------------------------
local function notifyGarageChanged()
    -- Visibility depends on ownership, so the clients need a fresh payload.
    if AdminApi and AdminApi.Broadcast then AdminApi.Broadcast() end
end

--- Refreshes exactly one player instead of the whole server. Granting access
--- changes what a single client may see, so there is no reason to rebuild
--- blips and points for everyone else.
local function pushToIdentifier(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return end
    if not (AdminApi and AdminApi.PushTo) then return end

    local xPlayer = MSK.GetPlayerFromIdentifier(identifier)
    if xPlayer and xPlayer.source then AdminApi.PushTo(xPlayer.source) end
end

function Private.GrantAccess(garageId, identifier, grantedBy)
    if type(garageId) ~= 'string' or not Config.Garages[garageId] then return false, 'not_found' end
    if type(identifier) ~= 'string' or identifier == '' then return false, 'bad_identifier' end
    if not Private.IsPrivate(Config.Garages[garageId]) then return false, 'not_private' end

    local limit = tonumber(Config.PrivateGarageMaxMembers) or 0
    if limit > 0 then
        local granted = Private.access[garageId]
        local count = 0
        if granted then for _ in pairs(granted) do count = count + 1 end end
        if count >= limit and not (granted and granted[identifier]) then
            return false, 'limit_reached'
        end
    end

    MySQL.insert.await(
        'INSERT INTO `msk_garage_private_access` (`garage_id`, `identifier`, `granted_by`) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `granted_by` = VALUES(`granted_by`)',
        { garageId, identifier, grantedBy }
    )

    local g = Private.access[garageId]
    if not g then g = {}; Private.access[garageId] = g end
    g[identifier] = true

    pushToIdentifier(identifier)
    return true
end

function Private.RevokeAccess(garageId, identifier)
    if type(garageId) ~= 'string' or type(identifier) ~= 'string' then return false, 'bad_input' end

    -- Rescue first, delete second. The other order would leave the vehicles
    -- behind if the UPDATE failed.
    Private.ReassignVehicles(garageId, identifier)

    MySQL.query.await(
        'DELETE FROM `msk_garage_private_access` WHERE `garage_id` = ? AND `identifier` = ?',
        { garageId, identifier }
    )

    local g = Private.access[garageId]
    if g then g[identifier] = nil end

    pushToIdentifier(identifier)
    return true
end

--- Sets (or clears, with nil) the owner of a garage. Clearing turns it back
--- into a public garage.
function Private.SetOwner(garageId, identifier)
    local def = Config.Garages[garageId]
    if not def then return false, 'not_found' end

    local newOwner = (type(identifier) == 'string' and identifier ~= '') and identifier or nil
    local oldOwner = def.owner

    if newOwner == oldOwner then return true end

    -- Whenever a garage ends up private, everyone but the new owner loses it.
    -- Their cars must not stay locked inside, so move them out first.
    --
    -- This covers BOTH directions that lock people out: an owner change, and a
    -- public garage becoming private for the first time. The latter is easy to
    -- miss and would silently bury every car other players had parked there.
    --
    -- Clearing the owner (newOwner = nil) is the opposite: the garage becomes
    -- public and everyone may use it again, so nothing has to be rescued.
    if newOwner then
        Private.ReassignAllVehicles(garageId, newOwner)
    end

    -- The access list always belonged to the previous owner, so it goes either
    -- way: a new owner starts with a clean list, and a public garage has no use
    -- for one.
    if oldOwner then
        MySQL.query.await('DELETE FROM `msk_garage_private_access` WHERE `garage_id` = ?', { garageId })
        Private.access[garageId] = nil
    end

    MySQL.update.await('UPDATE `msk_garage_garages` SET `owner` = ? WHERE `id` = ?', { newOwner, garageId })
    def.owner = newOwner

    if def.house_ref then Housing.Invalidate(def.house_ref) end
    notifyGarageChanged()
    return true
end

function Private.SetHouseRef(garageId, houseRef)
    local def = Config.Garages[garageId]
    if not def then return false, 'not_found' end

    local ref = (type(houseRef) == 'string' and houseRef ~= '') and houseRef:sub(1, 120) or nil
    MySQL.update.await('UPDATE `msk_garage_garages` SET `house_ref` = ? WHERE `id` = ?', { ref, garageId })
    def.house_ref = ref
    if ref then Housing.Invalidate(ref) end
    return true
end

----------------------------------------------------------------
-- Housing sync
--
-- Only relevant in pull setups (db/export/custom adapter without the push
-- exports). Mirrors the housing owner into our own column so the RAM-only
-- visibility path agrees with the gate. Push setups keep the column current
-- anyway, so this then finds nothing to do.
----------------------------------------------------------------
function Private.SyncFromHousing()
    local cfg = Config.Housing
    if type(cfg) ~= 'table' or not cfg.enable then return 0 end
    if not Housing.Current() then return 0 end

    local changed = 0
    for id, def in pairs(Config.Garages) do
        local ref = def.house_ref
        if type(ref) == 'string' and ref ~= '' then
            Housing.Invalidate(ref)
            local owner = Housing.GetOwner(ref)
            if owner and owner ~= def.owner then
                Private.SetOwner(id, owner)
                changed = changed + 1
            end
        end
    end

    if changed > 0 then
        Utils.Log('debug', ('[private] housing sync updated %d garage owner(s)'):format(changed))
    end
    return changed
end

----------------------------------------------------------------
-- Creating and deleting from other resources
----------------------------------------------------------------
local ID_PATTERN = '^[%w_%-]+$'

--- Builds a garage id from a house reference. Housing scripts use UUIDs and
--- names with spaces, the garage id column is varchar(60) and restricted to
--- [%w_-], so anything else is folded down. The untouched reference stays in
--- house_ref, which is what every lookup uses.
local function garageIdFromRef(houseRef)
    local clean = tostring(houseRef):gsub('[^%w_%-]', '_')
    local id = 'house_' .. clean
    if #id > 60 then
        -- Keep it collision-resistant without pulling in a hash library: the
        -- tail of a UUID is the part that actually varies.
        id = 'house_' .. clean:sub(-52)
    end
    return id
end

--- Creates (or updates) a private garage. `def` needs at least location and
--- owner; everything cosmetic comes from Config.PrivateGarageTemplate so a
--- housing script does not have to build a full garage definition.
function Private.CreateGarage(input)
    if type(input) ~= 'table' then return false, 'bad_input' end

    local owner = input.owner
    if type(owner) ~= 'string' or owner == '' then return false, 'bad_owner' end

    local houseRef = input.houseRef or input.house_ref
    local id = input.id or (houseRef and garageIdFromRef(houseRef))
    if type(id) ~= 'string' or id == '' or #id > 60 or not id:match(ID_PATTERN) then
        return false, 'bad_id'
    end

    local location = input.location
    if type(location) ~= 'table' and type(location) ~= 'vector4' then return false, 'bad_location' end

    local template = Config.PrivateGarageTemplate or {}
    local function coord(c)
        return { x = (c.x or 0.0) + 0.0, y = (c.y or 0.0) + 0.0, z = (c.z or 0.0) + 0.0, w = (c.w or c.h or 0.0) + 0.0 }
    end

    local parkOut = {}
    for _, c in ipairs(input.parkOut or input.park_out or { location }) do
        parkOut[#parkOut + 1] = coord(c)
    end

    local def = {
        id        = id,
        label     = input.label or template.label or 'Privatgarage',
        type      = input.type or template.type or { 'car' },
        distance  = template.distance or 40.0,
        park_dist = template.park_dist or 5.0,
        warp      = template.warp == true,
        jobs      = { enable = false, identifier = 'player', ownJob = true, jobs = {} },
        pedmodel  = template.pedmodel or { enable = false, model = 'csb_trafficwarden', distance = 20.0 },
        text3d    = template.text3d or { enable = false, label = 'Garage', size = 0.8 },
        marker    = template.marker or { enable = true, distance = 5.0, type = 27,
                                         size = { a = 1.0, b = 1.0, c = 1.0 },
                                         color = { a = 255, b = 255, c = 255 } },
        blip      = template.blip or { enable = true, id = 357, color = 2, scale = 0.7 },
        locations = { coord(location) },
        park_out  = parkOut,
    }

    -- Housing scripts call this again for a house that already exists (a resale,
    -- or simply on every start). When that changes the owner it has the same
    -- consequence as SetOwner, so the previous tenants have to be dealt with
    -- BEFORE the row is overwritten, otherwise their cars stay behind in a
    -- garage they can no longer open.
    local existing = Config.Garages[id]
    if existing and existing.owner and existing.owner ~= owner then
        Private.ReassignAllVehicles(id, owner)
        MySQL.query.await('DELETE FROM `msk_garage_private_access` WHERE `garage_id` = ?', { id })
        Private.access[id] = nil
    end

    MySQL.insert.await(
        'INSERT INTO `msk_garage_garages` (`id`, `label`, `data`, `enabled`, `owner`, `house_ref`) ' ..
        'VALUES (?, ?, ?, 1, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `data` = VALUES(`data`), ' ..
        '`owner` = VALUES(`owner`), `house_ref` = VALUES(`house_ref`)',
        { id, def.label, json.encode(def), owner, houseRef }
    )

    if houseRef then Housing.Invalidate(houseRef) end
    AdminStore.LoadGarages()
    notifyGarageChanged()
    return true, id
end

function Private.DeleteGarage(garageId)
    local def = Config.Garages[garageId]
    if not def then return false, 'not_found' end

    -- Never let a car disappear with the house.
    Private.ReassignAllVehicles(garageId, nil)

    MySQL.query.await('DELETE FROM `msk_garage_private_access` WHERE `garage_id` = ?', { garageId })
    MySQL.query.await('DELETE FROM `msk_garage_garages` WHERE `id` = ?', { garageId })
    Private.access[garageId] = nil

    AdminStore.LoadGarages()
    notifyGarageChanged()
    return true
end

--- Resolves a garage by its id OR its house reference, so callers can use
--- whichever they have at hand.
function Private.Resolve(idOrRef)
    if type(idOrRef) ~= 'string' or idOrRef == '' then return nil end
    if Config.Garages[idOrRef] then return idOrRef end
    for id, def in pairs(Config.Garages) do
        if def.house_ref == idOrRef then return id end
    end
    return nil
end

----------------------------------------------------------------
-- Public server exports for housing scripts (the PUSH direction)
----------------------------------------------------------------
exports('CreatePrivateGarage', function(def)
    return Private.CreateGarage(def)
end)

exports('DeletePrivateGarage', function(idOrRef)
    local id = Private.Resolve(idOrRef)
    if not id then return false, 'not_found' end
    return Private.DeleteGarage(id)
end)

exports('SetPrivateGarageOwner', function(idOrRef, identifier)
    local id = Private.Resolve(idOrRef)
    if not id then return false, 'not_found' end
    return Private.SetOwner(id, identifier)
end)

exports('GrantPrivateGarageAccess', function(idOrRef, identifier, grantedBy)
    local id = Private.Resolve(idOrRef)
    if not id then return false, 'not_found' end
    return Private.GrantAccess(id, identifier, grantedBy)
end)

exports('RevokePrivateGarageAccess', function(idOrRef, identifier)
    local id = Private.Resolve(idOrRef)
    if not id then return false, 'not_found' end
    return Private.RevokeAccess(id, identifier)
end)

exports('GetPrivateGarageAccess', function(idOrRef)
    local id = Private.Resolve(idOrRef)
    if not id then return {} end
    return Private.ListAccess(id)
end)

--- Convenience for housing scripts that would rather ask than push.
exports('PlayerHasGarageAccess', function(identifier, idOrRef)
    local id = Private.Resolve(idOrRef)
    if not id then return false end
    return Private.HasAccess(identifier, Config.Garages[id])
end)
