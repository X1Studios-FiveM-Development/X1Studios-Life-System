local previewCam = nil

local function genderModel(genderKey)
    for _, g in ipairs(Config.Character.genders) do
        if g.key == genderKey then return g.model end
    end
    return Config.Character.genders[1].model
end

local function loadModel(modelName)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    local attempts = 0
    while not HasModelLoaded(hash) and attempts < 200 do
        Wait(25)
        attempts = attempts + 1
    end
    return hash
end

local function applyAppearance(genderKey, skipModelSwap)
    local ped = PlayerPedId()
    local willSwap = not skipModelSwap and GetEntityModel(ped) ~= GetHashKey(genderModel(genderKey))
    print(('[X1S] applyAppearance: gender=%s skipModelSwap=%s willSwapModel=%s'):format(
        tostring(genderKey), tostring(skipModelSwap), tostring(willSwap)))

    if willSwap then
        local hash = loadModel(genderModel(genderKey))
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
        ped = PlayerPedId()
        SetPedDefaultComponentVariation(ped)
    end
end

X1S.ApplyCharacterAppearance = applyAppearance

local function positionAtCreatorStage()
    local c = Config.Character.creatorCoords
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
end

local function setCreatorCamera()
    local c = Config.Character.creatorCoords
    local camCfg = Config.Character.creatorCam
    local rad = math.rad(c.w + 180.0)
    local camX = c.x - camCfg.distance * math.sin(rad)
    local camY = c.y + camCfg.distance * math.cos(rad)
    local camZ = c.z + camCfg.height + 0.62

    if previewCam and DoesCamExist(previewCam) then DestroyCam(previewCam, false) end
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camX, camY, camZ, 0.0, 0.0, 0.0, camCfg.fov, false, 0)
    PointCamAtCoord(previewCam, c.x, c.y, c.z + 0.62)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 600, true, true)
end

local function destroyCreatorCamera()
    if previewCam then
        RenderScriptCams(false, false, 0, true, true)
        if DoesCamExist(previewCam) then DestroyCam(previewCam, false) end
        previewCam = nil
    end
end

RegisterNetEvent('x1s-char:client:openCreator', function(context)
    if GetInvokingResource() then return end
    positionAtCreatorStage()
    setCreatorCamera()
    applyAppearance(Config.Character.genders[1].key, false)

    SetNuiFocus(true, true)

    X1S.UI.Send({
        action = 'openCharacterCreator',
        context = context,
        locale = X1S.UI.Locale(),
        notificationConfig = Config.Notifications
    })
end)

RegisterNetEvent('x1s-char:client:openSelector', function(payload)
    if GetInvokingResource() then return end
    positionAtCreatorStage()
    setCreatorCamera()

    if payload.characters[1] then
        local first = payload.characters[1]
        applyAppearance(first.gender, true)
    end

    SetNuiFocus(true, true)

    X1S.UI.Send({
        action = 'openCharacterSelector',
        payload = payload,
        locale = X1S.UI.Locale(),
        notificationConfig = Config.Notifications
    })
end)

RegisterNetEvent('x1s-char:client:creatorError', function(message)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'characterCreatorError', message = message })
end)

RegisterNetEvent('x1s-char:client:selectorError', function(message)
    if GetInvokingResource() then return end
    X1S.UI.Notify('error', X1S.Translate('notification_system'), message)
end)

RegisterNetEvent('x1s-char:client:characterReady', function(character)
    if GetInvokingResource() then return end
    destroyCreatorCamera()

    X1S.Client.Character = character
    applyAppearance(character.gender, true)

    X1S.UI.Send({ action = 'characterLoaded', character = character })

    OpenSpawnSelector(true)
end)

RegisterNUICallback('previewAppearance', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = false }) return end
    applyAppearance(data.gender, data.gender == nil)
    cb({ ok = true })
end)

RegisterNUICallback('previewCharacterSlot', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = false }) return end
    applyAppearance(data.gender, true)
    cb({ ok = true })
end)

RegisterNUICallback('submitCharacter', function(data, cb)
    TriggerServerEvent('x1s-char:server:createCharacter', data)
    cb({ ok = true })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    local characterId = type(data) == 'table' and data.characterId or nil
    TriggerServerEvent('x1s-char:server:selectCharacter', characterId)
    cb({ ok = true })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    local characterId = type(data) == 'table' and data.characterId or nil
    TriggerServerEvent('x1s-char:server:deleteCharacter', characterId)
    cb({ ok = true })
end)

RegisterNUICallback('requestCreatorFromSelector', function(_, cb)
    TriggerServerEvent('x1s-char:server:requestCreatorScreen')
    cb({ ok = true })
end)

RegisterNUICallback('cancelCreatorToSelector', function(_, cb)
    TriggerServerEvent('x1s-char:server:requestCharacters')
    cb({ ok = true })
end)
