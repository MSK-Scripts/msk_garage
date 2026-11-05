CustomSessions = CustomSessions or {}

local sessions = {} -- [src] = { garage = def, impound = def, expiresAt = number }

local SESSION_TTL = 60

local function touch(src)
    local s = sessions[src] or {}
    s.expiresAt = os.time() + SESSION_TTL
    sessions[src] = s
    return s
end

local function alive(src)
    local s = sessions[src]
    if not s then return nil end
    if os.time() > s.expiresAt then sessions[src] = nil; return nil end
    return s
end

function CustomSessions.RegisterGarage(src, def)
    if type(def) ~= 'table' then return false end
    touch(src).garage = def
    return true
end

function CustomSessions.RegisterImpound(src, def)
    if type(def) ~= 'table' then return false end
    touch(src).impound = def
    return true
end

function CustomSessions.GetGarage(src)
    local s = alive(src)
    return s and s.garage or nil
end

function CustomSessions.GetImpound(src)
    local s = alive(src)
    return s and s.impound or nil
end

function CustomSessions.Clear(src)
    sessions[src] = nil
end

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)

-- Periodic sweep so the table can't grow without bound on a busy server.
CreateThread(function()
    while true do
        Wait(120000)
        local now = os.time()
        for src, s in pairs(sessions) do
            if now > s.expiresAt then sessions[src] = nil end
        end
    end
end)

-- Public exports for third-party SERVER scripts
exports('RegisterCustomGarage', function(playerSrc, def)
    return CustomSessions.RegisterGarage(playerSrc, def)
end)
exports('RegisterCustomImpound', function(playerSrc, def)
    return CustomSessions.RegisterImpound(playerSrc, def)
end)
exports('ClearCustomSession', function(playerSrc)
    CustomSessions.Clear(playerSrc)
end)
