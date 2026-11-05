Validation = Validation or {}

-- Nickname sanitisation: whitelist + max length.
local NICK_MAX = 24
local NICK_PATTERN = '[^%w%s%.%-_äöüÄÖÜß]'

function Validation.SanitizeNickname(input)
    if type(input) ~= 'string' then return nil end
    local cleaned = input:gsub(NICK_PATTERN, ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #cleaned == 0 then return nil end
    if #cleaned > NICK_MAX then cleaned = cleaned:sub(1, NICK_MAX) end
    return cleaned
end

-- Plate normalisation. 
-- Owned-vehicles plates can be either trimmed ("MSK01") or whitespace-padded to 8 chars ("MSK01   "), so we carry both forms through every query.
function Validation.NormalisePlate(plate)
    if type(plate) ~= 'string' then return nil, nil end
    local trimmed = MSK.Trim(plate, true):upper()
    return plate, trimmed
end

-- Config lookups. Custom garages (registered via openGarage export) are not in Config and fall back to client-provided data —
-- but they still go through the source-checked exports flow, so a raw MSK.Trigger from a bad client can't impersonate one.
function Validation.GetGarage(garageId)
    if not garageId then return nil end
    return Config.Garages[garageId]
end

function Validation.GetImpound(impoundId)
    if not impoundId then return nil end
    return Config.Impounds[impoundId]
end

-- Distance helper. Returns (ok, distance) so callers can log.
function Validation.PlayerNearCoord(src, coord, allowed)
    if not src or not coord then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local distance = #(GetEntityCoords(ped) - vec3(coord.x, coord.y, coord.z))
    return distance <= (allowed or 6.0), distance
end

-- For ID-based requests: resolve the canonical Config entry AND verify the player actually stands near it. Returns (def|nil, err).
function Validation.RequireGarageAccess(src, garageId)
    local def = Validation.GetGarage(garageId)
    if not def then return nil, ('unknown garage id: %s'):format(tostring(garageId)) end

    local nearAny = false
    for _, loc in ipairs(def.locations) do
        local ok = Validation.PlayerNearCoord(src, loc, 8.0)
        if ok then nearAny = true; break end
    end

    if not nearAny then
        Utils.Log('warn', ('player %d tried %s but is not near it'):format(src, garageId))
        return nil, 'not near garage'
    end

    -- Job + grade check
    if def.jobs.enable then
        local xPlayer = MSK.GetPlayer(src)
        if not xPlayer or not xPlayer.job then return nil, 'no player' end
        if not Utils.JobMatches(def.jobs.jobs, xPlayer.job.name, xPlayer.job.grade) then
            return nil, 'wrong job'
        end
    end

    -- Private garage: the owner and everyone they granted access to. This is the
    -- single gate for park-in AND park-out, both reach it through
    -- resolveGarage() in server/vehicles.lua. A public garage (no owner) short
    -- circuits inside Private.HasAccess, so this costs nothing on normal setups.
    if Private.IsPrivate(def) then
        local xPlayer = MSK.GetPlayer(src)
        if not xPlayer then return nil, 'no player' end
        if not Private.HasAccess(xPlayer.identifier, def) then
            Utils.Log('warn', ('player %d tried private garage %s without access'):format(src, garageId))
            return nil, Utils.T('private_no_access')
        end
    end

    return def
end

function Validation.RequireImpoundAccess(src, impoundId)
    local def = Validation.GetImpound(impoundId)
    if not def then return nil, ('unknown impound id: %s'):format(tostring(impoundId)) end

    local nearAny = false
    for _, loc in ipairs(def.locations) do
        local ok = Validation.PlayerNearCoord(src, loc, 8.0)
        if ok then nearAny = true; break end
    end

    if not nearAny then
        Utils.Log('warn', ('player %d tried impound %s but is not near it'):format(src, impoundId))
        return nil, 'not near impound'
    end

    return def
end

-- Per-plate spawn lock. Held while a CreateVehicleServerSetter call is in flight, so spamming park-out can't produce two cars.
local locks = {}

function Validation.AcquirePlateLock(plate)
    local _, trimmed = Validation.NormalisePlate(plate)
    if not trimmed then return false end
    if locks[trimmed] then return false end
    locks[trimmed] = os.time()
    return true
end

function Validation.ReleasePlateLock(plate)
    local _, trimmed = Validation.NormalisePlate(plate)
    if not trimmed then return end
    locks[trimmed] = nil
end

-- Sweep stale locks every minute (defensive against early-returns that forget to release).
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for plate, acquiredAt in pairs(locks) do
            if now - acquiredAt > 30 then locks[plate] = nil end
        end
    end
end)
