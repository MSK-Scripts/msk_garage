Blips = Blips or {}

local handles = {}

local function add(coord, blipDef, label)
    local blip = AddBlipForCoord(coord.x, coord.y, coord.z)
    SetBlipSprite(blip, blipDef.id)
    SetBlipScale(blip, blipDef.scale)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, blipDef.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    handles[#handles + 1] = blip
end

local function jobAllowsBlip(garage)
    if not garage.jobs.enable then return true end
    local job = MSK.GetPlayerJob()
    if not job then return false end
    if not Utils.JobMatches(garage.jobs.jobs, job.name, job.grade) then return false end
    return true
end

function Blips.Refresh()
    for i = 1, #handles do RemoveBlip(handles[i]) end
    handles = {}

    for _, garage in pairs(Config.Garages) do
        if garage.blip and garage.blip.enable and jobAllowsBlip(garage) then
            for _, loc in ipairs(garage.locations) do
                add(loc, garage.blip, garage.label)
            end
        end
    end

    if Config.enableImpound then
        for _, impound in pairs(Config.Impounds) do
            if impound.blip and impound.blip.enable then
                for _, loc in ipairs(impound.locations) do
                    add(loc, impound.blip, impound.label)
                end
            end
        end
    end
end

function Blips.RemoveAll()
    for i = 1, #handles do RemoveBlip(handles[i]) end
    handles = {}
end
