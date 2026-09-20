local isSpawnMenuOpen = false
local previewCam = nil
local isMandatoryOpen = false

local function setPreviewCamera(loc)
    local coords = loc.coords
    local heading = loc.coords.w
    local cam = loc.cam or {}
    local dist = cam.distance or Config.Spawn.defaultCam.distance
    local height = cam.height or Config.Spawn.defaultCam.height
    local fov = cam.fov or Config.Spawn.defaultCam.fov

    local rad = math.rad(heading + 180.0)
    local camX = coords.x + dist * math.sin(rad)
    local camY = coords.y + dist * math.cos(rad)
    local camZ = coords.z + height

    local newCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camX, camY, camZ, 0.0, 0.0, 0.0, fov, false, 0)
    PointCamAtCoord(newCam, coords.x, coords.y, coords.z + 1.0)

    local outgoingCam = previewCam
    previewCam = newCam

    if outgoingCam then
        SetCamActiveWithInterp(newCam, outgoingCam, 1200, 1, 1)
        CreateThread(function()
            Wait(1250)
            if outgoingCam and DoesCamExist(outgoingCam) then DestroyCam(outgoingCam, false) end
        end)
    else
        SetCamActive(newCam, true)
        RenderScriptCams(true, true, 800, true, true)
    end
end

local function destroyPreviewCamera()
    if previewCam then
        RenderScriptCams(false, false, 0, true, true)
        if DoesCamExist(previewCam) then DestroyCam(previewCam, false) end
        previewCam = nil
    end
end

local function preloadLocation(loc)
    local c = loc.coords
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
end

local function buildLocationPayload()
    local list = {}
    for i, loc in ipairs(Config.Spawn.locations) do
        list[#list + 1] = {
            index = i,
            name = loc.name,
            district = loc.district,
            image = loc.image,
            coordsText = string.format('%.1f, %.1f', loc.coords.x, loc.coords.y)
        }
    end
    return list
end

function OpenSpawnSelector(mandatory)
    if isSpawnMenuOpen then return end
    isSpawnMenuOpen = true
    isMandatoryOpen = mandatory == true

    X1S.FreezePlayerForMenu()
    SetNuiFocus(true, true)

    X1S.UI.Send({ action = 'spawnLoading' })

    local first = Config.Spawn.locations[1]
    if first then preloadLocation(first) end

    CreateThread(function()
        Wait(Config.Spawn.loadingDuration or 1800)
        if not isSpawnMenuOpen then return end
        X1S.UI.Send({
            action = 'openSpawnSelector',
            locations = buildLocationPayload(),
            locale = X1S.UI.Locale(),
            notificationConfig = Config.Notifications,
            allowClose = (not isMandatoryOpen) and Config.Spawn.allowManualClose
        })
    end)
end

local function closeSpawnSelector()
    destroyPreviewCamera()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    ClearFocus()
    SetNuiFocus(false, false)
    DisplayRadar(true)
    X1S.UI.Send({ action = 'close' })
    isSpawnMenuOpen = false
end

RegisterNUICallback('previewSpawn', function(data, cb)
    local loc = Config.Spawn.locations[tonumber(data.index)]
    if loc then
        setPreviewCamera(loc)
        preloadLocation(loc)
    end
    cb({ ok = true })
end)

RegisterNUICallback('confirmSpawn', function(data, cb)
    local loc = Config.Spawn.locations[tonumber(data.index)]
    if not loc then
        cb({ ok = false })
        return
    end

    DoScreenFadeOut(400)
    Wait(450)

    destroyPreviewCamera()
    X1S.ReleasePlayerAt(loc.coords, loc.coords.w)
    SetNuiFocus(false, false)
    X1S.UI.Send({ action = 'close' })
    isSpawnMenuOpen = false

    Wait(200)
    DoScreenFadeIn(500)

    X1S.UI.SuppressSpawnEchoFor(4000)
    TriggerServerEvent('x1s-char:server:enteredWorld')
    TriggerEvent('x1s-lifesystem:playerSpawned', loc.name, loc.coords)

    cb({ ok = true })
end)

RegisterNUICallback('closeSpawnSelector', function(_, cb)
    if not isMandatoryOpen and Config.Spawn.allowManualClose then
        closeSpawnSelector()
    end
    cb({ ok = true })
end)

RegisterCommand(Config.Spawn.command, function()
    if isSpawnMenuOpen then return end
    OpenSpawnSelector(false)
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if isSpawnMenuOpen then
        destroyPreviewCamera()
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        SetEntityInvincible(ped, false)
        SetPlayerControl(PlayerId(), true, 0)
        ClearFocus()
    end
end)
