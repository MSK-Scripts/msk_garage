AdminPerms = AdminPerms or {}

----------------------------------------------------------------
-- Permission keys (the 8 garage/impound rights + 2 management rights).
-- Order matters: the NUI renders the matrix in this order.
----------------------------------------------------------------
AdminPerms.PERMS = {
    'garage.view', 'garage.create', 'garage.edit', 'garage.delete',
    'impound.view', 'impound.create', 'impound.edit', 'impound.delete',
    'settings.manage', 'permissions.manage',
}

-- Settings that may be edited from the dashboard (requires `settings.manage`).
-- These are the DB-managed keys (see config/settings.lua). Static code hooks
-- (config/static.lua) are intentionally NOT here. AdvancedParking is auto-
-- detected and therefore not a managed setting either.
AdminPerms.SETTINGS_KEYS = {
    'Locale', 'Debug', 'VersionChecker', 'Hotkey', 'defaultTextUI',
    'Parking', 'spawnMode', 'FuelTankDefaultVolume', 'enableImpound',
    'parkoutWithKey', 'needEnoughMoney', 'useSocietyName',
    'blockImpoundWhileAdvancedParked',
    'deleteJobVehiclesOnJobChange', 'showKeyOwnerName',
    'TargetSystem', 'VehicleKeys', 'DefaultGarages', 'adminCommand',
    'Theme', 'BrandTag', 'VehicleImages',
}

-- Allowed file extensions for per-model vehicle images (vehicle_images/<model>.<ext>).
AdminPerms.IMAGE_EXTS = { 'png', 'jpg', 'webp' }

-- Editable UI colour keys (hex strings) managed via the dashboard's Settings tab.
-- Keep in sync with web/src/lib/theme.ts (DEFAULT_THEME / THEME_KEYS).
AdminPerms.THEME_KEYS = { 'accent', 'bg', 'panel', 'textPrimary', 'textSecondary' }
AdminPerms.DEFAULT_THEME = {
    accent = '#00E676',
    bg = '#0a0b0d',
    panel = '#131317',
    textPrimary = '#f0ede8',
    textSecondary = '#b0adb8',
}

-- Selectable script adapters exposed to the dashboard dropdowns. Keep in sync
-- with the adapters implemented in client/target.lua and server/keys/.
AdminPerms.TARGET_SCRIPTS = { 'ox_target' }
AdminPerms.VEHICLEKEY_SCRIPTS = { 'msk_vehiclekeys', 'VehicleKeyChain', 'vehicles_keys' }

-- Suggested group names shown in the UI when adding a new group.
AdminPerms.SUGGESTED_GROUPS = { 'admin', 'mod', 'dev' }

-- group.admin always has every right and can never be edited.
AdminPerms.PROTECTED_GROUPS = { admin = true }

-- group.user may NEVER open the dashboard and can never be granted rights.
AdminPerms.BLACKLIST_GROUPS = { user = true }

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
function AdminPerms.AllPerms()
    local t = {}
    for _, p in ipairs(AdminPerms.PERMS) do t[p] = true end
    return t
end

function AdminPerms.IsProtected(group)
    return AdminPerms.PROTECTED_GROUPS[tostring(group):lower()] == true
end

function AdminPerms.IsBlacklisted(group)
    return AdminPerms.BLACKLIST_GROUPS[tostring(group):lower()] == true
end

-- Maps an owned_vehicles.type value (or a garage's first configured type) to a
-- default-garage category. Keep in sync with shared/classes.lua TYPE_SYNONYMS.
local TYPE_CATEGORY = {
    car = 'land', automobile = 'land', truck = 'land', trailer = 'land',
    train = 'land', bike = 'land', motorcycle = 'land', motorbike = 'land',
    bicycle = 'land',
    boat = 'sea', submarine = 'sea', submarinecar = 'sea',
    helicopter = 'air', heli = 'air', aircraft = 'air', plane = 'air',
    airplane = 'air',
}

function AdminPerms.CategoryForType(vehicleType)
    return TYPE_CATEGORY[tostring(vehicleType):lower()] or 'land'
end
