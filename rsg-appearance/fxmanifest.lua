fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-appearance v3.1 - HTML UI Edition with Naked Body System'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/functions.lua',
    'shared/starter_clothing.lua',
}

client_scripts {
    'client/load_functions.lua',
    'client/hashtocache.lua',
    'client/anim_mount_guard.lua',
'client/naked_body.lua',    -- ? ERROR: Undefined variable or function (creator of clothes!)
    'client/creator.lua',
    'client/hate_style_clone.lua',
    'client/clothes.lua',
'client/appearance_sync.lua', -- ? Synchronization of appearance/character creator data
    'client/html_ui.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_appearance.lua',
    'server/sv_clothing.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'data/features.lua',
    'data/overlays.lua',
    'data/clothing.lua',
    'data/hairs_list.lua',
    'data/extra_rdr2_hairs.lua',
    'data/clothes_list.lua',
    'locales/*.json',
    'locales/*.lua',
}

ox_libs {
    'locale',
}

dependencies {
    'rsg-core',
    'ox_lib',
    'rsg-menubase'
}
