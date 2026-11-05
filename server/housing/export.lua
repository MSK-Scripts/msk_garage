--[[============================================================
    GENERIC EXPORT ADAPTER  (Config.Housing.script = 'export')

    Calls an export on the housing resource, with the resource and export
    names taken from the config. This covers every housing script that offers
    some form of "who owns this house" export, without msk_garage shipping a
    hard-coded adapter per script and without guessing an API that may change
    with the next update of that script.

        Config.Housing = {
            enable   = true,
            script   = 'export',
            resource = 'qs-housing',
            export = {
                getOwner   = 'getHouseOwner',   -- (houseRef) -> identifier | table
                getMembers = nil,               -- optional, -> { identifier, ... }
                -- Some scripts return a table instead of a plain string. Name
                -- the field holding the identifier and it gets unwrapped.
                ownerField = nil,               -- e.g. 'owner' or 'identifier'
            },
        }

    Look the export name up in the documentation of your housing script. A
    wrong name is logged once and the adapter then stays quiet instead of
    spamming the console on every park-in.
============================================================]]--

local warned = {}

local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    print('^1[msk_garage]^0 ' .. message)
end

local function conf()
    local cfg = Config.Housing or {}
    local res = cfg.resource
    local exp = cfg.export
    if type(res) ~= 'string' or res == '' or type(exp) ~= 'table' then return nil end
    return res, exp
end

--- Housing scripts disagree on the return shape: some hand back the plain
--- identifier, some a whole house table. Unwrap when ownerField says so.
local function unwrap(value, field)
    if type(value) == 'string' then return value ~= '' and value or nil end
    if type(value) == 'table' then
        if type(field) == 'string' and field ~= '' then
            local v = value[field]
            return (type(v) == 'string' and v ~= '') and v or nil
        end
        -- Best effort for the field names virtually every script uses.
        local v = value.owner or value.identifier or value.citizenid
        return (type(v) == 'string' and v ~= '') and v or nil
    end
    return nil
end

local function call(res, name, arg)
    local target = exports[res]
    local fn = target and target[name]
    if not fn then
        warnOnce(res .. ':' .. name,
            ('[housing/export] %s has no export "%s" - check Config.Housing.export'):format(res, name))
        return nil
    end
    -- exports[res][name] is invoked with the export table as self, hence the
    -- leading nil. That is the documented FiveM calling convention.
    return fn(nil, arg)
end

Housing.RegisterAdapter('export', {
    requiresResource = true,

    GetOwner = function(houseRef)
        local res, exp = conf()
        if not res then return nil end
        local name = exp.getOwner
        if type(name) ~= 'string' or name == '' then return nil end

        return unwrap(call(res, name, houseRef), exp.ownerField)
    end,

    GetMembers = function(houseRef)
        local res, exp = conf()
        if not res then return nil end
        local name = exp.getMembers
        if type(name) ~= 'string' or name == '' then return nil end

        local raw = call(res, name, houseRef)
        if type(raw) ~= 'table' then return nil end

        local out = {}
        for _, entry in ipairs(raw) do
            local id = unwrap(entry, exp.ownerField)
            if id then out[#out + 1] = id end
        end
        return out
    end,
})
