fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-changing_room - outfit and looks menu'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/client.lua',
    'client/target.lua',
    'client/blips.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}

ox_libs {
    'locale',
}

dependencies {
    'rsg-core',
    'rsg-appearance',
    'rsg-clothingstore',
    'rsg-barbershop',
    'ox_lib',
    'ox_target',
}
