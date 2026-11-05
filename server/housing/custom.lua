--[[============================================================
    CUSTOM ADAPTER  (Config.Housing.script = 'custom')

    For anything the db and export adapters cannot express: write the two
    functions yourself in config/static.lua (Config.HousingHooks), the same
    way Config.Notification and Config.openTextUI already work there.

    Both hooks run on the SERVER. Keep them cheap: GetOwner is called on
    park-in and park-out. The result is cached, see server/housing/init.lua.
============================================================]]--

local function hook(name)
    local hooks = Config.HousingHooks
    if type(hooks) ~= 'table' then return nil end
    local fn = hooks[name]
    if type(fn) ~= 'function' then return nil end
    return fn
end

Housing.RegisterAdapter('custom', {
    GetOwner = function(houseRef)
        local fn = hook('GetOwner')
        if not fn then return nil end
        local id = fn(houseRef)
        return (type(id) == 'string' and id ~= '') and id or nil
    end,

    GetMembers = function(houseRef)
        local fn = hook('GetMembers')
        if not fn then return nil end
        local list = fn(houseRef)
        if type(list) ~= 'table' then return nil end

        local out = {}
        for _, id in ipairs(list) do
            if type(id) == 'string' and id ~= '' then out[#out + 1] = id end
        end
        return out
    end,
})
