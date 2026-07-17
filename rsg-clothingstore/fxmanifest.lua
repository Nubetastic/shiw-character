fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'RSG Clothing Store'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'configStore.lua',
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}

dependencies {
    'rsg-core',
    'ox_lib',
    'ox_target',
    'rsg-appearance'
}

lua54 'yes'
