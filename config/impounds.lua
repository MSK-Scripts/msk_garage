Config = Config or {}

--[[============================================================
    DASHBOARD-MANAGED IMPOUNDS  (seed defaults only)

    Imported into the database on the first start and managed from
    the in-game dashboard (/garageadmin) afterwards. The database
    wins at runtime, so entries here only decide what a FRESH
    install (empty DB) starts with.
============================================================]]--

local DEFAULT_PED    = { enable = true, model = 'csb_trafficwarden', distance = 20.0 }
local DEFAULT_TEXT3D = { enable = false, label = '~g~Open Impound', size = 0.8 }
local DEFAULT_MARKER = { enable = false, distance = 5.0, type = 27, size = { a = 1.0, b = 1.0, c = 1.0 }, color = { a = 255, b = 255, c = 255 } }

local function impound(id, label, types, location, parkOut, blipId, fee, warp)
    return {
        impoundId = id,
        label     = label,
        type      = types,
        pedmodel  = DEFAULT_PED,
        text3d    = DEFAULT_TEXT3D,
        marker    = DEFAULT_MARKER,
        blip      = { enable = true, id = blipId, color = 17, scale = 0.8 },
        locations = { location },
        park_dist = 5.0,
        park_out  = parkOut,
        warp      = warp == nil and false or warp,
        fee       = { enable = fee > 0, price = fee, account = 'money' },
    }
end

Config.Impounds = {
    ['impound_car'] = impound(
        'impound_car',
        'Impound | Car',
        { 'car', 'truck', 'bike' },
        vector4(409.0, -1622.75, 29.29, 231.88),
        {
            vector4(401.36, -1647.98, 29.29, 318.54),
            vector4(406.09, -1652.36, 29.29, 320.51),
        },
        524, 150, false
    ),

    ['impound_boat'] = impound(
        'impound_boat',
        'Impound | Boat',
        { 'boat', 'submarine' },
        vector4(-788.38, -1490.3, 1.6, 289.21),
        { vector4(-797.84, -1490.21, -0.47, 301.0) },
        410, 200, true
    ),

    ['impound_heli'] = impound(
        'impound_heli',
        'Impound | Aircrafts',
        { 'aircraft', 'helicopter' },
        vector4(-1070.57, -2867.78, 13.95, 152.85),
        { vector4(-1112.54, -2883.81, 13.95, 147.98) },
        569, 500, false
    ),
}
