Target = Target or {}

local function openGarageHook() openGarage() end
local function openImpoundHook() openImpound() end

function Target.RegisterEntity(label, entity, kind)
    if not Config.TargetSystem.enable then return end

    if Config.TargetSystem.script == 'ox_target' then
        exports.ox_target:addLocalEntity(entity, {
            label    = label,
            distance = 2.5,
            onSelect = kind == 'garage' and openGarageHook or openImpoundHook,
        })
    end
    -- Add additional adapters here (qb-target, qtarget, …)
end

function Target.UnregisterEntity(entity)
    if not Config.TargetSystem.enable then return end

    if Config.TargetSystem.script == 'ox_target' then
        exports.ox_target:removeLocalEntity(entity, false)
    end
end
