Config = Config or {}

--[[============================================================
    DASHBOARD-MANAGED SETTINGS  (seed defaults only)

    Imported into the database on the first start and managed from
    the in-game dashboard (/garageadmin) afterwards. The database
    wins at runtime, so values here only decide what a FRESH
    install (empty DB) starts with.

    Code hooks and adapters live in `config/static.lua`.
============================================================]]--

----------------------------------------------------------------
Config.Locale = 'de' -- de, en, hu, fr, es, pt, pl (see locales/)
Config.Debug = true
Config.VersionChecker = true
----------------------------------------------------------------
-- Interaction
Config.Hotkey = 38 -- E (the visible key comes from the locale)

Config.TargetSystem = {
    enable = true,
    -- Supported scripts: AdminPerms.TARGET_SCRIPTS (shared/admin_perms.lua),
    -- selectable in the dashboard. Own adapter -> client/target.lua.
    script = 'ox_target',
}

Config.defaultTextUI = true
----------------------------------------------------------------
Config.Parking = 'specific' -- 'all' | 'specific'

-- Who creates the vehicle on park-out.
-- 'server' (default) = CreateVehicleServerSetter. The server owns the spawn.
-- 'client' = the player's client creates the vehicle and owns it from the start,
-- so the tuning lands at once, also on slow PCs. The server reserves the spawn
-- and checks model, position and owner of the reported vehicle before the
-- park-out counts. Does NOT work with `sv_entityLockdown strict`.
Config.spawnMode = 'server' -- 'server' | 'client'

-- Default garage per category. Vehicles of a garage deleted in the dashboard are
-- moved to the default of their category.
Config.DefaultGarages = {
    land = 'A',      -- car / truck / bike / bicycle / trailer / train
    sea  = 'boat_A', -- boat / submarine
    air  = 'heli_A', -- helicopter / aircraft / plane
}
Config.DefaultGarage = Config.DefaultGarages.land -- legacy alias

-- Second keys
Config.VehicleKeys = {
    enable = true,
    -- Supported scripts: AdminPerms.VEHICLEKEY_SCRIPTS (shared/admin_perms.lua),
    -- selectable in the dashboard. Adapters -> server/keys/.
    script = 'msk_vehiclekeys',
}
----------------------------------------------------------------
-- Tank volume (liters) for the max-fuel display of STORED vehicles only.
-- Irrelevant without msk_fuel.
Config.FuelTankDefaultVolume = 65.0
----------------------------------------------------------------
-- Impound
Config.enableImpound = true
Config.parkoutWithKey = true
Config.needEnoughMoney = true

-- ON = a vehicle stays locked in the impound as long as AdvancedParking still has
-- a position for it, so until it really left the world.
-- OFF (default) = msk_garage removes it from AdvancedParking itself and hands it out.
Config.blockImpoundWhileAdvancedParked = false
----------------------------------------------------------------
-- ON = job vehicles belong to the society (e.g. 'society_police'), so the whole
-- job shares them and they survive the owner leaving the job or the server.
Config.useSocietyName = false

-- ON = when a player leaves a job, every vehicle they personally own on that job
-- is deleted from the vehicle table (serverside `msk_core:setJob`). A pure grade change
-- does nothing, society vehicles are never touched. IRREVERSIBLE.
Config.deleteJobVehiclesOnJobChange = false
----------------------------------------------------------------
-- Badge for vehicles you only see because you hold a key.
-- ON = "Key from <owner>" (name via Utils.GetOwnerName, shared/utils.lua)
-- OFF = just "Second key"
Config.showKeyOwnerName = true
----------------------------------------------------------------
-- Admin dashboard
Config.adminCommand = 'garageadmin' -- command that opens it
Config.dashboardGroups = { 'mod' }  -- ACE groups besides 'admin'; 'user' is always denied
Config.BrandTag = 'MSK'             -- badge next to the title (empty = hidden)

-- Per-model images from `vehicle_images/<spawnname>.<ext>`. A missing image falls
-- back to the vehicle-class icon, so a partial set is fine.
Config.VehicleImages = {
    enable = true,
    ext = 'png', -- 'png' | 'jpg' | 'webp'
}

-- Public-garage access per job, managed in the dashboard's Job Garages tab.
-- job -> { mode = 'whitelist'|'blacklist', garages = { '<publicGarageId>', ... } }
-- whitelist = only those garages, blacklist = all but those.
-- A job without an entry gets no public garage at all (default).
Config.JobGaragePolicy = {}

-- Brand colours (hex), applied live to dashboard, garage and impound. All shades
-- are derived from these five in the UI (web/src/lib/theme.ts).
Config.Theme = {
    accent = '#00E676',        -- MSK green
    bg = '#0a0b0d',            -- window background
    panel = '#131317',         -- panel surface
    textPrimary = '#f0ede8',
    textSecondary = '#b0adb8',
}
