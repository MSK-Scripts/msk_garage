Peds = Peds or {}

local active = {} -- [pointId] = { entity, modelHash, voiced }

local function loadModel(hash)
    -- Already streamed in? Nothing to do — must return true (returning nil here
    -- made the caller treat an already-loaded model as a load failure).
    if HasModelLoaded(hash) then return true end
    -- Fast-fail on a model that doesn't exist in the game files (e.g. a typo in a
    -- ped model name) instead of blocking for the full timeout below.
    if not IsModelInCdimage(hash) then return false end

    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

function Peds.Spawn(pointId, modelName, location, label, kind)
    if active[pointId] then return active[pointId].entity end

    local hash = type(modelName) == 'number' and modelName or GetHashKey(modelName)
    if not loadModel(hash) then
        Utils.Log('error', 'failed to load ped model', modelName)
        return nil
    end

    local heading = Utils.Heading(location)
    local entity = CreatePed(4, hash, location.x, location.y, location.z - 1.0, heading, false, true)
    FreezeEntityPosition(entity, true)
    SetEntityHeading(entity, heading)
    SetEntityInvincible(entity, true)
    SetBlockingOfNonTemporaryEvents(entity, true)
    SetModelAsNoLongerNeeded(hash)

    active[pointId] = { entity = entity, modelHash = hash, voiced = false }

    if Config.TargetSystem.enable then
        Target.RegisterEntity(label, entity, kind)
    end

    Utils.Log('debug', 'spawned ped', pointId, 'entity', entity)
    return entity
end

function Peds.Remove(pointId)
    local rec = active[pointId]
    if not rec then return end

    Target.UnregisterEntity(rec.entity)

    if DoesEntityExist(rec.entity) then
        DeleteEntity(rec.entity)
    end

    active[pointId] = nil
    Utils.Log('debug', 'removed ped', pointId)
end

-- NPC voice ("Hi", "Bye"). 
function Peds.Greet(pointId)
    if not Config.npcVoice.enable then return end
    local rec = active[pointId]
    if not rec or rec.voiced then return end
    rec.voiced = true
    PlayPedAmbientSpeechNative(rec.entity, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE_NO_REPEAT_FRONTEND')
end

function Peds.Farewell(pointId)
    if not Config.npcVoice.enable then return end
    local rec = active[pointId]
    if not rec or not rec.voiced then return end
    rec.voiced = false
    PlayPedAmbientSpeechNative(rec.entity, 'GENERIC_BYE', 'SPEECH_PARAMS_FORCE_NO_REPEAT_FRONTEND')
end

function Peds.RemoveAll()
    for pointId in pairs(active) do
        Peds.Remove(pointId)
    end
end
