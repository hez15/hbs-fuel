fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hbs-fuel'
author 'OpenAI'
description 'QBX + ox_inventory fuel system with pump UX, refinery runtime, tanker roles, and networked nozzle carry'
version '0.6.1'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

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
    'client/nui.lua',
    'client/fuel_usage.lua',
    'client/pumps.lua',
    'client/jerrycan.lua',
    'client/tanker.lua',
    'client/industrial.lua',
    'client/contracts.lua',
    'client/ownership.lua',
    'client/zones.lua',
    'client/crime.lua',
    'client/rentals.lua',
    'client/charging.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/payments.lua',
    'server/persistence.lua',
    'server/fuel_state.lua',
    'server/stations.lua',
    'server/refinery.lua',
    'server/tanker.lua',
    'server/contracts.lua',
    'server/ownership.lua',
    'server/oilshops.lua',
    'server/crime.lua',
    'server/admin.lua'
}
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_scrap_items.ytyp'
dependencies {
    'ox_lib',
    'ox_inventory',
    'oxmysql',
    'ox_target'
}
