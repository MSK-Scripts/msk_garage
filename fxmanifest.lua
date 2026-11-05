fx_version 'cerulean'
games { 'gta5' }

author 'Musiker15 - MSK Scripts'
name 'msk_garage'
description 'Advanced Garage System with Impounds'
version '5.7.0'

lua54 'yes'

-- ox_lib replaces @es_extended/imports.lua: vehicle properties are read and
-- written through it on QBCore and Qbox, and ESX is fetched lazily in
-- client/state.lua when it is actually the running framework. Importing ESX
-- here made the resource refuse to start on any server without it.
shared_scripts {
    '@ox_lib/init.lua',
    '@msk_core/import.lua',

    'shared/*.lua',
    'locales/*.lua',
    'config/*.lua',
}

client_scripts {
    'client/state.lua',
    'client/target.lua',
    'client/peds.lua',
    'client/blips.lua',
    'client/vehicles.lua',
    'client/nui.lua',
    'client/points.lua',
    'client/main.lua',
    'client/handler.lua',

    -- Admin dashboard
    'client/admin/main.lua',
    'client/admin/nui.lua',
    'client/admin/sync.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'server/main.lua',
    'server/customSessions.lua',
    'server/validation.lua',

    -- Housing bridge: registry first, then one adapter per file. Private
    -- garages need it loaded before server/private.lua uses it.
    'server/housing/init.lua',
    'server/housing/db.lua',
    'server/housing/export.lua',
    'server/housing/custom.lua',
    'server/private.lua',
    'server/private_command.lua',

    'server/keys/init.lua',
    'server/keys/msk_vehiclekeys.lua',
    'server/keys/VehicleKeyChain.lua',
    'server/keys/vehicles_keys.lua',
    'server/garages.lua',
    'server/impound.lua',
    'server/vehicles.lua',
    'server/api.lua',
    'server/handler.lua',
    'server/versionchecker.lua',

    -- Admin dashboard (boot.lua must stay LAST: it depends on all of the above)
    'server/admin/store.lua',
    'server/admin/permissions.lua',
    'server/admin/seed.lua',
    'server/admin/api.lua',
    'server/admin/command.lua',
    'server/admin/boot.lua',
}

ui_page 'html/index.html'

files {
    'html/**/*.*',
    -- Per-model vehicle images (optional, server-owner supplied). 
    'vehicle_images/**/*.*',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'msk_core',
}
