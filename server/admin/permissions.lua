-- Server-side permission resolution. Extends the shared AdminPerms table.
AdminPerms = AdminPerms or {}

local cache = {}          -- [src] = { perms = {...}, at = ms }
local CACHE_TTL = 5000    -- ms

-- ESX groups are not always mirrored into FiveM's ACE system: the group lives in
-- the framework's `users` table (e.g. group = 'admin') with no matching
-- `add_principal ... group.admin` in server.cfg. So we resolve the framework
-- group too and treat membership as "ACE principal OR framework group".
--
-- NOTE: since msk_core 4.0.0 this works on every framework. `player.group` is a
-- plain string there: ESX hands over what it stores, QBCore and Qbox reduce
-- their permission table to the highest level found. Before 4.0.0 only ESX
-- carried a group at all.
function AdminPerms.GetFrameworkGroup(src)
    if not MSK.GetPlayer then return nil end
    local ok, xPlayer = pcall(MSK.GetPlayer, { source = src })
    if not ok or not xPlayer then return nil end
    -- getGroup() is gone since msk_core 4.0.0: the player object is no longer
    -- the raw xPlayer, and player.group is a plain string on every framework.
    if xPlayer.group then return tostring(xPlayer.group):lower() end
    return nil
end

-- luxu_admin v2 keeps its staff groups internally (not as FiveM ACE principals),
-- so a normal IsPlayerAceAllowed('group.x') check does not see them. When enabled
-- (see Config.LuxuAdmin), we resolve the player's staff group via its server export
-- getPlayerStaffGroup and map it onto a dashboard group name.
function AdminPerms.GetLuxuGroup(src)
    local cfg = Config.LuxuAdmin
    if type(cfg) ~= 'table' then return nil end

    local resource = cfg.resource or 'luxu_admin'
    local enabled = cfg.enable
    if enabled == false then return nil end
    if enabled ~= true then -- 'auto' (default): only when the resource is running
        if GetResourceState(resource) ~= 'started' then return nil end
    end

    local ok, group = pcall(function() return exports[resource]:getPlayerStaffGroup(src) end)
    if not ok or not group or group == false then return nil end
    group = tostring(group):lower()

    if cfg.requireDuty then
        local okDuty, duty = pcall(function() return exports[resource]:getPlayerStaffDutyState(src) end)
        if not okDuty or not duty then return nil end
    end

    if type(cfg.groupMap) == 'table' and cfg.groupMap[group] then
        return tostring(cfg.groupMap[group]):lower()
    end
    return group
end

-- QBCore keeps its staff levels ('god', 'admin', 'mod') as qbcore.<level>
-- principals and checks them with IsPlayerAceAllowed(src, '<level>'). The aces
-- registered in EnsureAce() already cover the normal case. This is the last
-- resort for servers whose server.cfg omits the qbcore.god -> qbcore.admin ->
-- qbcore.mod inheritance chain, where a 'god' would otherwise not count as
-- 'admin'. Cheap enough: only reached when every other check said no, and the
-- result of the whole permission lookup is cached for CACHE_TTL anyway.
function AdminPerms.GetQbPermission(src, group)
    if MSK.Bridge and MSK.Bridge.Framework and MSK.Bridge.Framework.Type ~= 'QBCore' then return false end

    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if not ok or type(core) ~= 'table' then return false end
    local fn = core.Functions and core.Functions.GetPermission
    if type(fn) ~= 'function' then return false end

    local ok2, perms = pcall(fn, src)
    if not ok2 or type(perms) ~= 'table' then return false end
    return perms[group] == true
end

----------------------------------------------------------------
-- ACE object registration
--
-- FiveM keeps PRINCIPALS and ACE OBJECTS apart. A line like
--     add_principal identifier.license:abc123 group.admin
-- only makes that player a MEMBER of the principal group.admin. It does NOT
-- grant them the ace object that happens to carry the same name. So
-- IsPlayerAceAllowed(src, 'group.admin') stays false until someone runs
--     add_ace group.admin group.admin allow
-- Most server.cfg templates never do that, they only hand out `command`
-- (add_ace group.admin command allow).
--
-- On top of that the frameworks disagree on how a group principal is even NAMED:
--   ESX / Qbox : add_principal identifier.license:abc123 group.admin
--   QBCore     : add_principal player.<src> qbcore.admin
--                (that is literally what QBCore.Functions.AddPermission runs)
-- QBCore's own setup guide only ever links qbcore.god to group.admin:
--     add_principal qbcore.god   group.admin
--     add_principal qbcore.god   qbcore.admin
--     add_principal qbcore.admin qbcore.mod
-- so qbcore.admin and qbcore.mod are members of NO group.* principal at all, and
-- group.mod does not exist on QBCore in the first place. That is why QBCore and
-- Qbox customers were locked out while ESX was fine: on ESX the framework-group
-- fallback above papers over it, on QBCore MSK.GetPlayer exposes no group at all.
--
-- Rather than probing a list of candidate names (IsPlayerAceAllowed(src, 'admin')
-- would false-positive on any unrelated ace that happens to be called 'admin'),
-- we register ONE private ace object per group and point every principal spelling
-- at it:
--     add_ace group.admin  msk.group.admin allow
--     add_ace qbcore.admin msk.group.admin allow
-- Principal inheritance keeps working on top of that (qbcore.god -> qbcore.admin,
-- group.admin -> group.mod), so a single IsPlayerAceAllowed(src, 'msk.group.admin')
-- covers ESX, Qbox and QBCore without guessing.
----------------------------------------------------------------
local aceRegistered = {}

-- FiveM checks add_ace against the resource that RUNS it, and no resource holds
-- `command.add_ace` by default. We cannot grant it to ourselves either, so the
-- aces are registered through msk_core: MSK.AddRawAce bounces through msk_core's
-- export, the command runs as `resource.msk_core`, and one line in the server.cfg
-- covers every MSK script at once:
--
--     add_ace resource.msk_core command.add_ace allow
--
-- Without it every call would be refused and the console would fill up with
-- "Access denied for command add_ace" on each start, so we ask once and skip the
-- registration entirely if we are not allowed. Everything else keeps working:
-- the framework group (ESX users table, QBCore permission list) and luxu_admin need no ace at all.
local mayAddAce = nil

local function canRegisterAces()
    if mayAddAce ~= nil then return mayAddAce end

    mayAddAce = MSK.CanAddAce and MSK.CanAddAce() or false

    if not mayAddAce then
        local resource = GetCurrentResourceName()
        print(('^3[%s]^0 Cannot register its ace objects: msk_core is not allowed to run add_ace.'):format(resource))
        print(('^3[%s]^0 Add this single line to your server.cfg and restart (it covers every MSK script):'):format(resource))
        print(('^3[%s]^0     ^5add_ace resource.msk_core command.add_ace allow^0'):format(resource))
        print(('^3[%s]^0 Until then group access falls back to your framework group (ESX users table / QBCore permissions) and luxu_admin.'):format(resource))
    end

    return mayAddAce
end

-- Private, collision-free ace object for a dashboard group.
function AdminPerms.GroupAce(group)
    return ('msk.group.%s'):format(tostring(group):lower())
end

function AdminPerms.EnsureAce(group)
    if not group then return end
    group = tostring(group):lower()
    if group == '' or aceRegistered[group] then return end
    if AdminPerms.IsBlacklisted(group) then return end
    if not canRegisterAces() then return end
    aceRegistered[group] = true

    local ace = AdminPerms.GroupAce(group)

    -- Plain object, so a hand-written `add_principal ... group.admin` works.
    MSK.AddRawAce(('group.%s'):format(group), ('group.%s'):format(group), true)

    -- ESX / Qbox spelling and QBCore spelling, both onto our own ace object.
    MSK.AddRawAce(('group.%s'):format(group), ace, true)
    MSK.AddRawAce(('qbcore.%s'):format(group), ace, true)
end

-- Covers 'admin' (always), the configured dashboard groups and every group in
-- the permission matrix. Runs on boot and after each change to those lists.
function AdminPerms.EnsureAces()
    AdminPerms.EnsureAce('admin')

    for _, group in ipairs(Config.dashboardGroups or {}) do
        AdminPerms.EnsureAce(group)
    end

    for group in pairs(AdminStore.perms or {}) do
        AdminPerms.EnsureAce(group)
    end
end

-- Group membership check, in order of cost:
--   1. our own ace object (covers group.<n> AND qbcore.<n>, see EnsureAce)
--   2. the plain group.<n> ace, for setups that granted it by hand
--   3. the ESX framework group from the users table
--   4. QBCore's own permission list
--   5. (when enabled) the player's luxu_admin staff group
function AdminPerms.PlayerInGroup(src, group)
    group = tostring(group):lower()
    if IsPlayerAceAllowed(src, AdminPerms.GroupAce(group)) then return true end
    if IsPlayerAceAllowed(src, ('group.%s'):format(group)) then return true end
    if AdminPerms.GetFrameworkGroup(src) == group then return true end
    if AdminPerms.GetQbPermission(src, group) then return true end
    if AdminPerms.GetLuxuGroup(src) == group then return true end
    return false
end

-- Full admin = ACE principal OR framework group 'admin'. Always all rights,
-- and the role can never be edited.
function AdminPerms.IsFullAdmin(src)
    return AdminPerms.PlayerInGroup(src, 'admin')
end

-- Effective permissions = union of every (non-blacklisted) group the player is
-- in. A full admin is a hard override: always ALL rights.
function AdminPerms.GetPlayerPerms(src)
    local c = cache[src]
    if c and (GetGameTimer() - c.at) < CACHE_TTL then return c.perms end

    local perms
    if AdminPerms.IsFullAdmin(src) then
        perms = AdminPerms.AllPerms()
    else
        perms = {}
        for group, matrix in pairs(AdminStore.perms) do
            if not AdminPerms.IsBlacklisted(group) and AdminPerms.PlayerInGroup(src, group) then
                for perm, allowed in pairs(matrix) do
                    if allowed then perms[perm] = true end
                end
            end
        end
    end

    cache[src] = { perms = perms, at = GetGameTimer() }
    return perms
end

function AdminPerms.Has(src, perm)
    return AdminPerms.GetPlayerPerms(src)[perm] == true
end

-- May the player open the dashboard at all? admin always; otherwise the player
-- must be in an allowed dashboard group (never 'user') AND have ≥1 right.
function AdminPerms.CanOpen(src)
    if AdminPerms.IsFullAdmin(src) then return true end

    local inAllowed = false
    for _, group in ipairs(Config.dashboardGroups or {}) do
        if not AdminPerms.IsBlacklisted(group) and AdminPerms.PlayerInGroup(src, group) then
            inAllowed = true
            break
        end
    end
    if not inAllowed then return false end

    return next(AdminPerms.GetPlayerPerms(src)) ~= nil
end

function AdminPerms.Invalidate(src)
    if src then cache[src] = nil else cache = {} end
end

AddEventHandler('playerDropped', function()
    if source then cache[source] = nil end
end)
