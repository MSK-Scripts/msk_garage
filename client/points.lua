PointsCtl = PointsCtl or {}

local registered = {}     -- [pointId] = MSK.Points handle
local insidePoints = {}   -- pointId -> def (active "I'm here" set)
local hotkeyTickRunning = false

local function startHotkeyTick()
    if hotkeyTickRunning then return end
    hotkeyTickRunning = true
    CreateThread(function()
        while next(insidePoints) do
            if not State.isNuiOpen
                and not Config.TargetSystem.enable
                and not State.IsDead()
                and not IsPedInAnyVehicle(PlayerPedId(), false) then

                -- Pick any inside point (typically only one anyway)
                local pointId, def = next(insidePoints)
                local label = def.label

                if Config.defaultTextUI then
                    MSK.HelpNotification(Utils.T('open_garage', label))
                else
                    Config.openTextUI(Utils.T('open_garage', label), Utils.T('open_garage_textui', label))
                end

                if IsControlJustReleased(0, Config.Hotkey) then
                    if def._kind == 'garage' then openGarage()
                    elseif def._kind == 'impound' then openImpound() end
                end
            end
            Wait(0)
        end

        if not Config.defaultTextUI then Config.closeTextUI() end
        hotkeyTickRunning = false
    end)
end

-- Registers a single point for a garage/impound location.
local function registerLocation(kind, def, location, index)
    local pointKey = ('%s:%s:%d'):format(kind, def.id or def.label, index)
    if registered[pointKey] then return end

    local coords = vector3(location.x, location.y, location.z)

    -- Pre-compute the per-frame visualisation distance.
    local pedDistance = def.pedmodel and def.pedmodel.enable and def.pedmodel.distance or 0.0
    local markerDistance = def.marker and def.marker.distance or 0.0
    local watchDistance = math.max(pedDistance, markerDistance, 2.5) + 1.0

    local handle
    handle = MSK.Points.Add({
        coords   = coords,
        distance = watchDistance,
        _kind    = kind,
        _def     = def,
        _location = location,

        onEnter = function(self)
            -- Job-gate: a civilian shouldn't have a job NPC spawn around them.
            if kind == 'garage' and def.jobs.enable then
                local job = MSK.GetPlayerJob()
                if not job or not Utils.JobMatches(def.jobs.jobs, job.name, job.grade) then return end
            end

            if def.pedmodel and def.pedmodel.enable then
                Peds.Spawn(pointKey, def.pedmodel.model, location, def.label, kind)
                Peds.Greet(pointKey)
            end

            if kind == 'garage' then
                State.currentGarage = def
            else
                State.currentImpound = def
            end

            insidePoints[pointKey] = self
            startHotkeyTick()
        end,

        onExit = function()
            Peds.Farewell(pointKey)
            Peds.Remove(pointKey)

            if kind == 'garage' and State.currentGarage == def then
                State.currentGarage = nil
            elseif kind == 'impound' and State.currentImpound == def then
                State.currentImpound = nil
            end

            insidePoints[pointKey] = nil
        end,
    })

    registered[pointKey] = handle
end

-- Builds all points from Config.Garages / Config.Impounds
function PointsCtl.Build()
    for _, garage in pairs(Config.Garages) do
        for i, location in ipairs(garage.locations) do
            registerLocation('garage', garage, location, i)
        end
    end

    if Config.enableImpound then
        for _, impound in pairs(Config.Impounds) do
            for i, location in ipairs(impound.locations) do
                registerLocation('impound', impound, location, i)
            end
        end
    end
end

function PointsCtl.RemoveAll()
    for _, handle in pairs(registered) do handle:Remove() end
    registered = {}
    insidePoints = {}
end

-- Optional: draw markers / 3D text for points without a target ped.
CreateThread(function()
    while true do
        local sleep = 500
        for _, point in pairs(insidePoints) do
            local def = point._def
            if not (def.pedmodel and def.pedmodel.enable) then
                local loc = point._location
                sleep = 0
                if def.marker and def.marker.enable then
                    -- NOTE: color.a/b/c are positional RGB (a=red, b=green, c=blue),
                    -- NOT alpha. Opacity is the optional color.alpha (default 100).
                    DrawMarker(def.marker.type, loc.x, loc.y, loc.z - 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        def.marker.size.a, def.marker.size.b, def.marker.size.c,
                        def.marker.color.a, def.marker.color.b, def.marker.color.c,
                        def.marker.color.alpha or 100, false, true, 0, false)
                end
                if def.text3d and def.text3d.enable then
                    MSK.Draw3DText(vector3(loc.x, loc.y, loc.z), def.text3d.label, def.text3d.size)
                end
            end
        end
        Wait(sleep)
    end
end)
