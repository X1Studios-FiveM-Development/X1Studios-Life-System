local function translate(key, ...)
    return X1S.Translate(key, ...)
end

local blips = {}
local isBusy = false
local currentLocationId = nil

local BLIP_SPRITE = { bank = 108, atm = 277, store = 59 }
local BLIP_COLOR = { bank = 2, atm = 2, store = 2 }

local function createBlips()
    if not Config.Robbery.createBlips then return end
    for _, location in ipairs(Config.Robbery.locations) do
        local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
        SetBlipSprite(blip, BLIP_SPRITE[location.type] or 1)
        SetBlipColour(blip, BLIP_COLOR[location.type] or 0)
        SetBlipScale(blip, 0.65)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(location.label)
        EndTextCommandSetBlipName(blip)

        blips[#blips + 1] = blip
    end
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    createBlips()
end)
CreateThread(function() createBlips() end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)

local DISABLED_CONTROLS = { 30, 31, 32, 33, 34, 35, 24, 25, 257, 140, 141, 142, 143, 37, 21, 22 }

local function lockControlsTick()
    for _, control in ipairs(DISABLED_CONTROLS) do
        DisableControlAction(0, control, true)
    end
    DisableControlAction(0, Config.Robbery.cancelControl, true)
end

local function nearestLocation(playerCoords)
    local nearest, nearestDist = nil, Config.Robbery.markerDistance
    for _, location in ipairs(Config.Robbery.locations) do
        local dist = #(playerCoords - location.coords)
        if dist < nearestDist then
            nearest, nearestDist = location, dist
        end
    end
    return nearest, nearestDist
end

local promptLocationId = nil

local function hidePromptIfShown()
    if promptLocationId then
        promptLocationId = nil
        X1S.UI.Send({ action = 'robberyPromptHide' })
    end
end

local function showPromptFor(location)
    if promptLocationId ~= location.id then
        promptLocationId = location.id
        X1S.UI.Send({ action = 'robberyPromptShow', label = translate('robbery_prompt_label', location.label) })
    end
end

local function beginRobbery(location)
    hidePromptIfShown()
    TriggerServerEvent('x1s-robbery:server:start', location.id)
end

CreateThread(function()
    while true do
        local sleep = 750
        if Config.Robbery.enabled and not isBusy then
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local location, dist = nearestLocation(playerCoords)

            if location then
                sleep = 0
                DrawMarker(
                    1, location.coords.x, location.coords.y, location.coords.z - 0.95,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.6,
                    200, 30, 30, 140, false, true, 2, false, nil, nil, false
                )

                if dist < Config.Robbery.interactDistance then
                    showPromptFor(location)

                    if IsControlJustPressed(0, Config.Robbery.interactControl) then
                        beginRobbery(location)
                    end
                else
                    hidePromptIfShown()
                end
            else
                hidePromptIfShown()
            end
        else
            hidePromptIfShown()
        end
        Wait(sleep)
    end
end)

local DENIED_MESSAGES = {
    onDuty = 'robbery_denied_on_duty',
    tooFar = 'robbery_denied_too_far',
    cooldown = 'robbery_denied_location_cooldown',
    playerCooldown = 'robbery_denied_player_cooldown'
}

RegisterNetEvent('x1s-robbery:client:denied', function(reason, secondsLeft)
    if GetInvokingResource() then return end
    local key = DENIED_MESSAGES[reason] or 'robbery_denied_generic'
    if (reason == 'cooldown' or reason == 'playerCooldown') and type(secondsLeft) == 'number' and secondsLeft > 0 then
        local minutes = math.max(1, math.ceil(secondsLeft / 60))
        X1S.UI.Notify('error', translate('robbery_notification_title'), translate(key, minutes))
    else
        X1S.UI.Notify('error', translate('robbery_notification_title'), translate(key))
    end
end)

RegisterNetEvent('x1s-robbery:client:result', function(data)
    if GetInvokingResource() then return end
    data = type(data) == 'table' and data or {}

    if data.ok then
        X1S.UI.Notify('success', translate('robbery_notification_title'),
            translate('robbery_result_success', data.label or ''))
    elseif data.reason == 'cancelled' then
        X1S.UI.Notify('info', translate('robbery_notification_title'), translate('robbery_result_cancelled'))
    else
        X1S.UI.Notify('error', translate('robbery_notification_title'), translate('robbery_result_failed'))
    end
end)

local function endRobberyUi(uiCloseAction)
    isBusy = false
    currentLocationId = nil
    ClearPedTasks(PlayerPedId())
    FreezeEntityPosition(PlayerPedId(), false)
    if uiCloseAction then X1S.UI.Send({ action = uiCloseAction }) end
end

local function runFingerprintHack(location, mgConfig)
    isBusy = true
    currentLocationId = location.id
    FreezeEntityPosition(PlayerPedId(), true)

    local rings = math.max(1, mgConfig.rings or 4)
    local mistakes = 0
    local maxMistakes = mgConfig.maxMistakes or 3
    local startTime = GetGameTimer()
    local timeoutMs = (mgConfig.timeoutSeconds or 45) * 1000

    X1S.UI.Send({
        action = 'robberyFingerprintOpen',
        label = location.label,
        totalRings = rings,
        maxMistakes = maxMistakes,
        timeoutSeconds = mgConfig.timeoutSeconds
    })

    local ring = 1
    local speedDeg = mgConfig.baseSpeedDegPerSec or 110
    local zoneDeg = mgConfig.zoneDegrees or 46
    local zoneStartDeg = math.random(0, 359)
    local ringStartTime = GetGameTimer()

    local function sendRingState(extra)
        local payload = {
            action = 'robberyFingerprintRing',
            ring = ring,
            speedDegPerSec = speedDeg,
            zoneStartDeg = zoneStartDeg,
            zoneDegrees = zoneDeg
        }
        if extra then for k, v in pairs(extra) do payload[k] = v end end
        X1S.UI.Send(payload)
    end

    sendRingState()

    local function nextRing()
        ring = ring + 1
        speedDeg = speedDeg + (mgConfig.speedStepDegPerSec or 25)
        zoneDeg = math.max(mgConfig.minZoneDegrees or 15, zoneDeg - (mgConfig.zoneShrinkDegrees or 4))
        zoneStartDeg = math.random(0, 359)
        ringStartTime = GetGameTimer()
        sendRingState()
    end

    local outcome = nil

    while outcome == nil do
        Wait(0)
        lockControlsTick()

        local elapsedTotal = GetGameTimer() - startTime
        if elapsedTotal >= timeoutMs then
            outcome = 'failed'
            break
        end

        if IsDisabledControlJustPressed(0, Config.Robbery.cancelControl) then
            outcome = 'cancelled'
            break
        end

        if IsDisabledControlJustPressed(0, Config.Robbery.hackControl) then
            local elapsedRing = (GetGameTimer() - ringStartTime) / 1000.0
            local angle = (elapsedRing * speedDeg) % 360
            local zoneEnd = (zoneStartDeg + zoneDeg) % 360
            local inZone
            if zoneStartDeg <= zoneEnd then
                inZone = angle >= zoneStartDeg and angle <= zoneEnd
            else
                inZone = angle >= zoneStartDeg or angle <= zoneEnd -- wraps past 360
            end

            if inZone then
                if ring >= rings then
                    outcome = 'success'
                    X1S.UI.Send({ action = 'robberyFingerprintHit', ring = ring, cleared = true })
                else
                    X1S.UI.Send({ action = 'robberyFingerprintHit', ring = ring, cleared = true })
                    nextRing()
                end
            else
                mistakes = mistakes + 1
                X1S.UI.Send({ action = 'robberyFingerprintMiss', mistakesLeft = maxMistakes - mistakes })
                if mistakes >= maxMistakes then
                    outcome = 'failed'
                end
            end
        end
    end

    if outcome == 'success' then
        X1S.UI.Send({ action = 'robberyFingerprintClose', success = true })
        endRobberyUi(nil)
        TriggerServerEvent('x1s-robbery:server:complete', location.id)
    elseif outcome == 'cancelled' then
        X1S.UI.Send({ action = 'robberyFingerprintClose', success = false })
        endRobberyUi(nil)
        TriggerServerEvent('x1s-robbery:server:cancel', location.id)
    else
        X1S.UI.Send({ action = 'robberyFingerprintClose', success = false })
        endRobberyUi(nil)
        TriggerServerEvent('x1s-robbery:server:fail', location.id)
    end
end

local function runProgressBar(location, durationMs)
    isBusy = true
    currentLocationId = location.id
    FreezeEntityPosition(PlayerPedId(), true)

    durationMs = durationMs or 20000
    local startTime = GetGameTimer()

    X1S.UI.Send({ action = 'robberyProgressOpen', label = location.label, durationMs = durationMs })

    local outcome = nil
    while outcome == nil do
        Wait(0)
        lockControlsTick()

        -- see the matching comment in runFingerprintHack() above - cancelControl
        -- is disabled every tick, so its press only shows up as "disabled".
        if IsDisabledControlJustPressed(0, Config.Robbery.cancelControl) then
            outcome = 'cancelled'
            break
        end

        if GetGameTimer() - startTime >= durationMs then
            outcome = 'success'
            break
        end
    end

    X1S.UI.Send({ action = 'robberyProgressClose' })
    endRobberyUi(nil)

    if outcome == 'success' then
        TriggerServerEvent('x1s-robbery:server:complete', location.id)
    else
        TriggerServerEvent('x1s-robbery:server:cancel', location.id)
    end
end

RegisterNetEvent('x1s-robbery:client:started', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' then return end
    if isBusy then return end

    local location = nil
    for _, loc in ipairs(Config.Robbery.locations) do
        if loc.id == data.locationId then location = loc break end
    end
    if not location then return end

    if location.type == 'bank' or location.type == 'atm' then
        CreateThread(function() runFingerprintHack(location, data.fingerprint or {}) end)
    else
        CreateThread(function() runProgressBar(location, data.progressBarDurationMs) end)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if isBusy and currentLocationId then
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)
