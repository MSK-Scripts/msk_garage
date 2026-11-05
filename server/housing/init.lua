Housing = Housing or {}

--[[============================================================
    HOUSING BRIDGE

    msk_garage never knows a single housing script by name. A private
    garage stores its owner itself (msk_garage_garages.owner), and this
    bridge is only consulted when the server wants the housing script to
    stay the source of truth (Config.Housing.enable).

    Two directions:
        PULL  - this file. Ask the housing script who owns a house.
        PUSH  - server/private.lua exports. The housing script tells us.

    PUSH is the better way and works with every script that can be
    patched or that fires an event. PULL exists for scripts that can be
    neither patched nor listened to, where reading their table or calling
    their export is the only option left.

    Adapters live one per file next to this one and are escrow-open, so a
    customer can add their own without waiting for a release.
============================================================]]--

local adapters = {}

--- Adapter contract:
---   GetOwner(houseRef)    -> identifier | nil          (REQUIRED)
---   GetMembers(houseRef)  -> { identifier, ... } | nil (optional)
---   requiresResource      -> true when the adapter calls into another
---                            resource, so we can skip it while that
---                            resource is not started.
function Housing.RegisterAdapter(name, adapter)
    if type(name) ~= 'string' or type(adapter) ~= 'table' then return end
    adapters[name] = adapter
end

function Housing.AdapterNames()
    local out = {}
    for name in pairs(adapters) do out[#out + 1] = name end
    table.sort(out)
    return out
end

--- Resolves the configured adapter, or nil when housing integration is off,
--- misconfigured, or the backing resource is not running. Every caller treats
--- nil as "no housing opinion", never as "access denied" -- a stopped housing
--- script must not lock every owner out of their own garage.
local function current()
    local cfg = Config.Housing
    if type(cfg) ~= 'table' or not cfg.enable then return nil end

    local adapter = adapters[cfg.script]
    if not adapter then
        print(('^3[msk_garage]^0 Housing: unknown adapter ^5%s^0 - integration disabled. Valid: %s')
            :format(tostring(cfg.script), table.concat(Housing.AdapterNames(), ', ')))
        return nil
    end

    if adapter.requiresResource then
        local res = cfg.resource
        if type(res) ~= 'string' or res == '' or GetResourceState(res) ~= 'started' then
            return nil
        end
    end

    return adapter
end

Housing.Current = current

----------------------------------------------------------------
-- Owner cache.
--
-- GetOwner sits in the park-in/park-out hot path. Without a cache every
-- attempt would hit the housing script's database. The TTL is a safety net
-- only: the push exports invalidate precisely, so a house sale takes effect
-- immediately instead of after the TTL.
----------------------------------------------------------------
local ownerCache = {} -- [houseRef] = { value = identifier|false, expires = number }

local function ttl()
    local cfg = Config.Housing or {}
    local n = tonumber(cfg.cacheSeconds)
    if not n or n < 0 then return 60 end
    return n
end

function Housing.Invalidate(houseRef)
    if houseRef then ownerCache[houseRef] = nil else ownerCache = {} end
end

--- Returns the owner identifier the housing script reports for `houseRef`,
--- or nil when there is no adapter, no answer, or the call failed.
function Housing.GetOwner(houseRef)
    if type(houseRef) ~= 'string' or houseRef == '' then return nil end

    local hit = ownerCache[houseRef]
    if hit and os.time() < hit.expires then
        return hit.value or nil
    end

    local adapter = current()
    if not adapter or type(adapter.GetOwner) ~= 'function' then return nil end

    local ok, result = pcall(adapter.GetOwner, houseRef)
    if not ok then
        Utils.Log('error', '[housing] GetOwner adapter error:', tostring(result))
        return nil
    end

    if type(result) ~= 'string' or result == '' then result = nil end
    ownerCache[houseRef] = { value = result or false, expires = os.time() + ttl() }
    return result
end

--- Optional. Housing scripts that track roommates/key holders themselves can
--- expose them here; msk_garage then treats them like its own access rows.
--- An adapter without GetMembers is not an error: msk_garage keeps its own
--- access list in that case, which is what most servers want anyway.
function Housing.GetMembers(houseRef)
    if type(houseRef) ~= 'string' or houseRef == '' then return nil end

    local adapter = current()
    if not adapter or type(adapter.GetMembers) ~= 'function' then return nil end

    local ok, result = pcall(adapter.GetMembers, houseRef)
    if not ok then
        Utils.Log('error', '[housing] GetMembers adapter error:', tostring(result))
        return nil
    end
    if type(result) ~= 'table' then return nil end

    local out = {}
    for _, id in ipairs(result) do
        if type(id) == 'string' and id ~= '' then out[#out + 1] = id end
    end
    return out
end

--- Startup banner. A silent housing integration that never fires is the
--- hardest thing to debug, so say out loud what is active.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(2000) -- settings come from the DB, let AdminStore finish first
        local cfg = Config.Housing
        if type(cfg) ~= 'table' or not cfg.enable then
            Utils.Log('debug', '[housing] integration disabled (private garages still work, owners are set manually)')
            return
        end
        if current() then
            print(('^2[msk_garage]^0 Housing bridge: ^5%s^0%s')
                :format(cfg.script, cfg.resource and (' -> ' .. cfg.resource) or ''))
        else
            print(('^3[msk_garage]^0 Housing bridge configured (^5%s^0) but not usable right now. '
                .. 'Check Config.Housing.script and that the resource is started.'):format(tostring(cfg.script)))
        end
    end)
end)
