Classes = Classes or {}

-- Maps a GTA vehicle class id to the icon basename used by the NUI under `html/images/<name>.svg`.
local CLASS_TO_ICON = {
    [0]  = 'compact',
    [1]  = 'sedan',
    [2]  = 'suv',
    [3]  = 'coupe',
    [4]  = 'muscle',
    [5]  = 'classic',
    [6]  = 'sport',
    [7]  = 'supersport',
    [8]  = 'motorcycle',
    [9]  = 'offroad',
    [10] = 'industrial',
    [11] = 'utility',
    [12] = 'van',
    [13] = 'bicycle',
    [14] = 'boat',
    [15] = 'helicopter',
    [16] = 'plane',
    [17] = 'service',
    [18] = 'emergency',
    [19] = 'military',
    [20] = 'truck',
}

function Classes.IconForClass(classId)
    return CLASS_TO_ICON[classId] or 'car'
end

-- Synonyms for the owned_vehicles.type column. Vehicle shops disagree on what
-- they write here: some use class-based names ('car', 'truck', 'helicopter',
-- 'aircraft'), others the GetVehicleType() convention ('automobile', 'heli',
-- 'plane'). A garage's configured category must match ANY known synonym so e.g.
-- a heli garage isn't empty just because the shop stored 'heli' instead of
-- 'helicopter'. Add more values here if your shop uses a different convention.
local TYPE_SYNONYMS = {
    car        = { 'car', 'automobile' },
    truck      = { 'truck', 'automobile' },
    boat       = { 'boat' },
    helicopter = { 'helicopter', 'heli', 'air' },
    aircraft   = { 'aircraft', 'plane', 'airplane', 'air' },
    bike       = { 'bike', 'motorcycle', 'motorbike' },
    submarine  = { 'submarine', 'submarinecar' },
    trailer    = { 'trailer' },
    train      = { 'train' },
}

-- All DB type values that satisfy a single configured category.
function Classes.TypeSynonyms(category)
    return TYPE_SYNONYMS[tostring(category):lower()] or { category }
end

-- True if a stored owned_vehicles.type matches any synonym of any of the
-- garage's configured categories. Used for park-in eligibility checks.
function Classes.TypeMatches(categories, dbType)
    if not dbType then return false end
    dbType = tostring(dbType):lower()
    for _, category in ipairs(categories) do
        for _, syn in ipairs(Classes.TypeSynonyms(category)) do
            if syn == dbType then return true end
        end
    end
    return false
end

function GetVehicleClassName(class)
    return Classes.IconForClass(class)
end
