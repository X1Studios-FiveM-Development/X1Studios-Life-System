fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'X1Studios'
description 'X1S Life System - Identity, Spawn, Duty, Dispatch, CAD/MDT, & Robberies'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/settings.js',
    'html/app.js',
    'html/duty.js',
    'html/robbery.js',
    'html/idcard.js',
    'html/logo.png',
    'html/banner.png',
    'html/x1scad.png',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/sound/*.mp3',
    'locales.json'
}

shared_script 'config.lua'

client_scripts {
    'client/main.lua',
    'client/character.lua',
    'client/spawn.lua',
    'client/duty.lua',
    'client/cad.lua',
    'client/dispatch.lua',
    'client/vehicles.lua',
    'client/autodispatch.lua',
    'client/robbery.lua',
    'client/idcard.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server_config.lua',
    'server/main.lua',
    'server/database.lua',
    'server/logging.lua',
    'server/character.lua',
    'server/duty.lua',
    'server/cad.lua',
    'server/dispatch.lua',
    'server/vehicles.lua',
    'server/autodispatch.lua',
    'server/robbery.lua',
    'server/idcard.lua'
}

dependency 'oxmysql'
