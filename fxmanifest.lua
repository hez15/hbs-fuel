fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hbs-fuel'
author 'OpenAI'
description 'QBX + ox_inventory fuel core with station stock, refinery, and tanker scaffolding'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/utils.lua',
    'shared/fueltypes.lua',
    'shared/vehicles.lua',
    'shared/stations.lua',
    'shared/refineries.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
    'client/fuel_usage.lua',
    'client/pumps.lua',
    'client/jerrycan.lua',
    'client/tanker.lua',
    'client/industrial.lua',
    'client/zones.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/payments.lua',
    'server/persistence.lua',
    'server/fuel_state.lua',
    'server/stations.lua',
    'server/refinery.lua',
    'server/jobs.lua',
    'server/tanker.lua',
    'server/admin.lua'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'oxmysql',
    'ox_target'
}
