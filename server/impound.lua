Impound = Impound or {}

function Impound.ChargeFee(src, fee)
    if not fee or not fee.enable then return true end

    local xPlayer = MSK.GetPlayer(src)
    if not xPlayer then return false end

    -- RemoveMoney refuses on an insufficient balance and reports it, so the
    -- deduction itself decides rather than the check in front of it.
    if xPlayer.RemoveMoney(fee.account, fee.price, 'msk_garage: impound fee') then
        Config.Notification(src, Utils.T('paid_impound_fee', fee.price), 'info')
        return true
    end

    Config.Notification(src, Utils.T('not_enough_money'), 'error')
    return false
end

----------------------------------------------------------------
-- AdvancedParking lock
--
-- AdvancedParking knows every vehicle it keeps alive, spawned or only persisted.
-- With Config.blockImpoundWhileAdvancedParked enabled a plate that it still has a
-- position for may NOT be fetched from the impound — the vehicle has to leave the
-- world first (despawn / cleanup / manual delete).
--
-- The lookup runs through AdvancedParking's own serverside exports
-- (GetVehiclePosition / GetVehiclePositions), the same ones the impound list
-- already uses for the tracking waypoint. No table names and no schema
-- assumptions. Every call is guarded: if a build does not expose them, the lock
-- disables itself after one warning instead of erroring on every request.
----------------------------------------------------------------
local apExportMissing = false
local apBatchMissing = false

local function apLookupFailed(err)
    apExportMissing = true
    print(('^3[msk_garage]^0 AdvancedParking position lookup failed (%s), the impound lock ' ..
        '(blockImpoundWhileAdvancedParked) stays disabled until the next restart.'):format(tostring(err)))
end

-- Positions of the given plates, keyed by the plate AdvancedParking answered with.
-- Prefers the batch export and falls back to single lookups for builds that only
-- ship GetVehiclePosition (or whose batch export returns nothing). Returns nil when
-- neither works — that also disables the lock for good.
local function apPositions(plates)
    if not apBatchMissing then
        local ok, positions = pcall(function()
            return exports['AdvancedParking']:GetVehiclePositions(plates)
        end)
        if ok and type(positions) == 'table' then return positions end
        apBatchMissing = true
    end

    local out = {}
    for _, plate in ipairs(plates) do
        local ok, position = pcall(function()
            return exports['AdvancedParking']:GetVehiclePosition(plate)
        end)
        if not ok then
            apLookupFailed(position)
            return nil
        end
        if position then out[plate] = position end
    end
    return out
end

-- Is the lock active right now? (setting on + AdvancedParking running + exports usable)
function Impound.ChecksAdvancedParking()
    return Config.blockImpoundWhileAdvancedParked == true
        and Config.UsesAdvancedParking()
        and not apExportMissing
end

-- Returns a set { [plate] = true } of the given plates that AdvancedParking still
-- holds. Keys are the plates exactly as passed in, so callers can map back.
function Impound.AdvancedParkedPlates(plates)
    local blocked = {}
    if not Impound.ChecksAdvancedParking() or type(plates) ~= 'table' or #plates == 0 then
        return blocked
    end

    -- Plates go out exactly as they sit in owned_vehicles (that is what AP was fed
    -- on park-in), but the answer is matched space-stripped on both sides: FiveM
    -- plates are 8 chars and often space-padded, and AP hands back whatever plate
    -- text it has stored. A raw equality check would miss a padded/trimmed pair.
    local lookup, query = {}, {}
    for _, plate in ipairs(plates) do
        local trimmed = MSK.Trim(tostring(plate or ''), true)
        if trimmed ~= '' and not lookup[trimmed] then
            lookup[trimmed] = plate
            query[#query + 1] = plate
        end
    end
    if #query == 0 then return blocked end

    local positions = apPositions(query)
    if not positions then return blocked end

    for plate, position in pairs(positions) do
        if position then
            local original = lookup[MSK.Trim(tostring(plate or ''), true)]
            if original then blocked[original] = true end
        end
    end
    return blocked
end

function Impound.IsAdvancedParked(plate)
    if type(plate) ~= 'string' or plate == '' then return false end
    if not Impound.ChecksAdvancedParking() then return false end

    -- Only one plate went out, so any answer at all means AdvancedParking still
    -- holds it. No plate matching needed here.
    local positions = apPositions({ plate })
    return positions ~= nil and next(positions) ~= nil
end
