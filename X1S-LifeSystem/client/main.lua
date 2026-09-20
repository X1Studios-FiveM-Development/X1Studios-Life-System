X1S.UI = X1S.UI or {}

local nuiReady = false
local pendingUiMessages = {}
local maxPendingUiMessages = 64
local hasBootstrapped = false
local suppressSpawnEventsUntil = 0

function X1S.UI.Send(message)
    if nuiReady then
        SendNUIMessage(message)
        return
    end
    if #pendingUiMessages >= maxPendingUiMessages then
        table.remove(pendingUiMessages, 1)
    end
    pendingUiMessages[#pendingUiMessages + 1] = message
end

function X1S.UI.SuppressSpawnEchoFor(ms)
    suppressSpawnEventsUntil = GetGameTimer() + ms
end

local function translate(key, ...)
    return X1S.Translate(key, ...)
end

local function getUiLocale()
    return Locales[Config.Locale] or Locales.en
end
X1S.UI.Locale = getUiLocale

function X1S.UI.Notify(notificationType, title, message, duration)
    X1S.UI.Send({
        action = 'notify',
        notification = {
            type = notificationType or 'info',
            title = title or translate('notification_system'),
            message = message or '',
            duration = duration or Config.Notifications.duration,
            position = Config.Notifications.position,
            maxVisible = Config.Notifications.maxVisible,
            sound = Config.Notifications.sound
        }
    })
end

RegisterNetEvent('x1s-duty:client:notify', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' then return end
    X1S.UI.Notify(data.type, data.title, data.message, data.duration)
end)

RegisterNUICallback('ready', function(_, callback)
    nuiReady = true
    for index = 1, #pendingUiMessages do
        SendNUIMessage(pendingUiMessages[index])
    end
    pendingUiMessages = {}
    callback({ ok = true })
end)

RegisterNUICallback('uiError', function(data, callback)
    local message = type(data) == 'table' and tostring(data.message or 'Unknown NUI error') or 'Unknown NUI error'
    print(('[X1S NUI] %s'):format(message))
    callback({ ok = true })
end)

function X1S.FreezePlayerForMenu()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    DisplayRadar(false)
    SetPlayerControl(PlayerId(), false, 0)
end

function X1S.ReleasePlayerAt(coords, heading)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading or 0.0)

    local attempts = 0
    repeat
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(50)
        attempts = attempts + 1
    until HasCollisionLoadedAroundEntity(ped) or attempts >= 20

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    ClearFocus()
    DisplayRadar(true)
end

local function beginBoot()
    if hasBootstrapped then return end
    hasBootstrapped = true

    X1S.FreezePlayerForMenu()
    SetNuiFocus(true, true)
    X1S.UI.Send({ action = 'bootLoading', locale = getUiLocale() })

    CreateThread(function()
        Wait(600)
        TriggerServerEvent('x1s-char:server:requestCharacters')
    end)
end

AddEventHandler('playerSpawned', function()
    if GetGameTimer() < suppressSpawnEventsUntil then return end
    beginBoot()
end)

RegisterCommand('switchcharacter', function()
    X1S.FreezePlayerForMenu()
    SetNuiFocus(true, true)
    X1S.UI.Send({ action = 'bootLoading', locale = getUiLocale() })
    TriggerServerEvent('x1s-char:server:requestCharacters')
end, false)

local tabletAnimActive = false
local tabletAnimGeneration = 0
local tabletPropObj = nil

local function loadModelWithTimeout(model, timeoutMs)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < timeoutMs do
        Wait(10)
        waited = waited + 10
    end
    return hash, HasModelLoaded(hash)
end

function X1S.UI.StartTabletAnim()
    local cfg = Config.TabletAnim
    if not cfg or not cfg.enabled then return end
    if tabletAnimActive then return end

    local ped = PlayerPedId()
    if cfg.playOnFoot ~= false and IsPedInAnyVehicle(ped, false) then return end

    tabletAnimActive = true
    tabletAnimGeneration = tabletAnimGeneration + 1
    local generation = tabletAnimGeneration

    CreateThread(function()
        RequestAnimDict(cfg.dict)
        local waited = 0
        while not HasAnimDictLoaded(cfg.dict) and waited < 2000 do
            Wait(10)
            waited = waited + 10
        end
        if generation ~= tabletAnimGeneration or not tabletAnimActive then return end
        if not HasAnimDictLoaded(cfg.dict) then return end

        ped = PlayerPedId()
        if cfg.clearWeapon ~= false then
            SetCurrentPedWeapon(ped, GetHashKey('weapon_unarmed'), true)
        end
        TaskPlayAnim(ped, cfg.dict, cfg.anim, 3.0, 3.0, -1, cfg.flag or 49, 0, false, false, false)

        local propCfg = cfg.prop
        if propCfg and propCfg.model then
            local hash, loaded = loadModelWithTimeout(propCfg.model, 2000)
            if generation == tabletAnimGeneration and tabletAnimActive and loaded then
                tabletPropObj = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
                local boneIndex = GetPedBoneIndex(ped, propCfg.bone or 60309)
                local offset = propCfg.boneOffset or vector3(0.0, 0.0, 0.0)
                local rotation = propCfg.boneRotation or vector3(0.0, 0.0, 0.0)
                AttachEntityToEntity(
                    tabletPropObj, ped, boneIndex,
                    offset.x, offset.y, offset.z,
                    rotation.x, rotation.y, rotation.z,
                    true, false, false, false, 2, true
                )
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end)
end

function X1S.UI.StopTabletAnim()
    if not tabletAnimActive then return end
    tabletAnimActive = false
    tabletAnimGeneration = tabletAnimGeneration + 1
    local generation = tabletAnimGeneration

    local cfg = Config.TabletAnim
    local ped = PlayerPedId()
    if cfg and DoesEntityExist(ped) then
        StopAnimTask(ped, cfg.dict, cfg.anim, -4.0)
    end

    local propToRemove = tabletPropObj
    tabletPropObj = nil
    if propToRemove then
        CreateThread(function()
            Wait(350)
            if generation ~= tabletAnimGeneration then return end
            if DoesEntityExist(propToRemove) then
                DetachEntity(propToRemove, true, false)
                DeleteObject(propToRemove)
            end
        end)
    end
end

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    nuiReady = false
    pendingUiMessages = {}
    X1S.UI.StopTabletAnim()
end)
