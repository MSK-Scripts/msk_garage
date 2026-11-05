Config = Config or {}

--[[============================================================
    DASHBOARD-MANAGED GARAGES  (seed defaults only)

    Imported into the database on the first start and managed from
    the in-game dashboard (/garageadmin) afterwards. The database
    wins at runtime, so entries here only decide what a FRESH
    install (empty DB) starts with.
============================================================]]--

----------------------------------------------------------------
-- Shared defaults, so the entries below stay short. Every garage can override
-- any of them through the last argument (opts).
----------------------------------------------------------------
local DEFAULT_PED       = { enable = true, model = 'csb_trafficwarden', distance = 20.0 }
local DEFAULT_TEXT3D    = { enable = false, label = '~g~Open Garage', size = 0.8 }
local DEFAULT_MARKER    = { enable = false, distance = 5.0, type = 27, size = { a = 1.0, b = 1.0, c = 1.0 }, color = { a = 255, b = 255, c = 255 } }
local DEFAULT_JOBS_OFF  = { enable = false, identifier = 'player', ownJob = true, jobs = {} }
local CAR_BLIP          = { enable = true, id = 524, color = 26, scale = 0.8 }
local BOAT_BLIP         = { enable = true, id = 427, color = 38, scale = 0.8 }
local HELI_BLIP         = { enable = true, id = 569, color = 30, scale = 0.8 }

local function garage(id, label, types, location, parkOut, blip, opts)
    opts = opts or {}
    return {
        id          = id,
        label       = label,
        type        = types,
        distance    = opts.distance or 40.0,
        jobs        = opts.jobs or DEFAULT_JOBS_OFF,
        pedmodel    = opts.pedmodel or DEFAULT_PED,
        text3d      = opts.text3d or DEFAULT_TEXT3D,
        marker      = opts.marker or DEFAULT_MARKER,
        blip        = blip or CAR_BLIP,
        locations   = { location },
        park_dist   = opts.park_dist or 5.0,
        park_out    = parkOut,
        warp        = opts.warp == nil and false or opts.warp,
    }
end

----------------------------------------------------------------

Config.Garages = {
    ----------------------------------------------------------------
    -- Civilian Garages (Cars & Trucks)
    ----------------------------------------------------------------
    ['A'] = garage('A', 'Garage | Meetingpoint', {'car', 'truck', 'bike'},
        vector4(213.98, -808.45, 31.01, 156.59),
        { vector4(232.98, -790.30, 30.60, 161.46) },
        CAR_BLIP),

    ['B'] = garage('B', 'Garage | Rockford Hills', {'car', 'truck', 'bike'},
        vector4(-899.275, -153.0, 41.88, 115.59),
        { vector4(-901.989, -159.28, 41.46, 204.0) },
        CAR_BLIP),

    ['C'] = garage('C', 'Garage | Alta', {'car', 'truck', 'bike'},
        vector4(275.182, -345.534, 45.17, 348.34),
        { vector4(266.498, -332.475, 43.43, 251.0) },
        CAR_BLIP),

    ['D'] = garage('D', 'Garage | LS Airport', {'car', 'truck', 'bike'},
        vector4(-951.63, -2708.07, 13.83, 68.09),
        { vector4(-967.41, -2703.67, 13.84, 71.3) },
        CAR_BLIP),

    ['E'] = garage('E', 'Garage | Cypress Flats', {'car', 'truck', 'bike'},
        vector4(721.95, -2016.379, 29.43, 262.25),
        { vector4(728.567, -2033.28, 28.87, 354.0) },
        CAR_BLIP),

    ['F'] = garage('F', 'Garage | Pacific Bluffs', {'car', 'truck', 'bike'},
        vector4(-2163.7, -376.16, 13.26, 126.81),
        { vector4(-2169.21, -372.25, 13.08, 158.18) },
        CAR_BLIP),

    ['G'] = garage('G', 'Garage | Observatorium', {'car', 'truck', 'bike'},
        vector4(-404.65, 1198.12, 325.97, 167.84),
        { vector4(-406.82, 1207.15, 325.664, 167.65) },
        CAR_BLIP),

    ['H'] = garage('H', 'Garage | Paleto Bay', {'car', 'truck', 'bike'},
        vector4(106.78, 6603.16, 31.98, 312.72),
        { vector4(115.81, 6599.34, 32.01, 265.81) },
        CAR_BLIP),

    ['I'] = garage('I', 'Garage | Baumarkt', {'car', 'truck', 'bike'},
        vector4(2766.96, 3463.65, 55.64, 71.4),
        { vector4(2772.88, 3472.32, 55.46, 241.84) },
        CAR_BLIP),

    ['J'] = garage('J', 'Garage | Grapeseed', {'car', 'truck', 'bike'},
        vector4(1951.79, 3750.95, 32.16, 0.0),
        { vector4(1949.57, 3759.33, 32.21, 34.16) },
        CAR_BLIP),

    ['K'] = garage('K', 'Garage | State Prison', {'car', 'truck', 'bike'},
        vector4(1852.28, 2615.23, 45.67, 271.07),
        { vector4(1875.88, 2595.20, 45.67, 267.31) },
        CAR_BLIP),

    ['L'] = garage('L', 'Garage | Diamond Casino', {'car', 'truck', 'bike'},
        vector4(906.67, -26.04, 78.89, 328.42),
        { vector4(886.12, -62.68, 78.76, 236.43) },
        CAR_BLIP),

    ['M'] = garage('M', 'Garage | La Puerta Beach', {'car', 'truck', 'bike'},
        vector4(-1184.43, -1509.74, 4.65, 297.27),
        { vector4(-1187.22, -1490.94, 4.38, 124.55) },
        CAR_BLIP),

    ['N'] = garage('N', 'Garage | Grand Senora Desert', {'car', 'truck', 'bike'},
        vector4(1108.02, 2659.36, 38.14, 0.0),
        { vector4(1112.26, 2654.10, 38.0, 269.12) },
        CAR_BLIP),

    ['O'] = garage('O', 'Garage | Cayo Perico', {'car', 'truck', 'bike'},
        vector4(4520.10, -4515.16, 4.5, 22.21),
        { vector4(4510.93, -4516.44, 4.12, 21.14) },
        CAR_BLIP),

    ----------------------------------------------------------------
    -- Boat Garages
    ----------------------------------------------------------------
    ['boat_A'] = garage('boat_A', 'Garage | LS Docks', {'boat', 'submarine'},
        vector4(-724.39, -1334.67, 1.6, 49.0),
        { vector4(-731.31, -1334.57, 2.07, 228.46) },
        BOAT_BLIP, { distance = 50.0, warp = true }),

    ['boat_B'] = garage('boat_B', 'Garage | Sandy Shores', {'boat', 'submarine'},
        vector4(1338.13, 4269.68, 31.5, 81.76),
        { vector4(1332.57, 4258.02, 32.15, 253.83) },
        BOAT_BLIP, { distance = 50.0, warp = true }),

    ['boat_C'] = garage('boat_C', 'Garage | Paleto Bay', {'boat', 'submarine'},
        vector4(-1604.42, 5256.20, 2.07, 22.78),
        { vector4(-1595.83, 5259.36, 3.07, 28.87) },
        BOAT_BLIP, { distance = 50.0, warp = true }),

    ['boat_D'] = garage('boat_D', 'Garage | Cayo Perico North', {'boat', 'submarine'},
        vector4(4931.42, -5146.21, 2.47, 62.92),
        { vector4(4938.64, -5139.09, 2.09, 64.75) },
        BOAT_BLIP, { distance = 50.0, warp = true }),

    ['boat_E'] = garage('boat_E', 'Garage | Cayo Perico South', {'boat', 'submarine'},
        vector4(3858.90, 4459.77, 1.83, 85.10),
        { vector4(3857.01, 4447.02, 0.10, 274.43) },
        { enable = true, id = 427, color = 3, scale = 0.7 },
        { distance = 50.0, warp = true, pedmodel = { enable = true, model = 'csb_trafficwarden', distance = 50.0 } }),

    ----------------------------------------------------------------
    -- Helicopter / Aircraft Garages
    ----------------------------------------------------------------
    ['heli_A'] = garage('heli_A', 'Garage | LS Airport Heli', {'helicopter', 'aircraft'},
        vector4(-1617.14, -3145.52, 13.99, 0.0),
        { vector4(-1646.9, -3136.06, 13.98, 330.0) },
        HELI_BLIP, { distance = 50.0 }),

    ['heli_B'] = garage('heli_B', 'Garage | Sandy Shores Airport', {'helicopter', 'aircraft'},
        vector4(1723.84, 3288.29, 40.16, 0.0),
        { vector4(1729.41, 3292.74, 40.22, 100.0) },
        HELI_BLIP, { distance = 50.0 }),

    ['heli_C'] = garage('heli_C', 'Garage | Grapeseed Airport', {'helicopter', 'aircraft'},
        vector4(2152.83, 4797.03, 40.19, 0.0),
        { vector4(2148.59, 4801.91, 40.86, 30.0) },
        HELI_BLIP, { distance = 50.0 }),

    ['heli_D'] = garage('heli_D', 'Garage | Cayo Perico Airport', {'helicopter', 'aircraft'},
        vector4(4459.91, -4478.10, 3.30, 0.0),
        { vector4(4453.45, -4475.05, 4.13, 290.0) },
        HELI_BLIP, { distance = 50.0 }),

    ----------------------------------------------------------------
    -- Job Garages
    ----------------------------------------------------------------
    ['police_mrpd_a'] = garage('police_mrpd_a', 'Garage | Police MRPD', {'car', 'truck', 'bike'},
        vector4(460.10, -986.74, 25.7, 92.28),
        { vector4(455.61, -980.50, 25.7, 90.34) },
        { enable = false, id = 524, color = 29, scale = 0.8 },
        {
            distance = 20.0,
            pedmodel = { enable = true, model = 's_m_y_cop_01', distance = 20.0 },
            jobs = {
                enable = true, identifier = 'society', ownJob = true,
                jobs = { { job = 'police', grade = 0 } },
            },
        }),
}
