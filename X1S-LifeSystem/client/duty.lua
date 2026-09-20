local dutyRequestPending = false
local dutyBlips = {}
local alertBlips = {}

local currentCallAlertId = nil

local function clearCurrentCallUi()
    currentCallAlertId = nil
    X1S.UI.Send({ action = 'currentCallClear' })
end

local function clearCurrentCallIfMatches(alertId)
    if currentCallAlertId and alertId == currentCallAlertId then
        clearCurrentCallUi()
    end
end

local function translate(key, ...)
    return X1S.Translate(key, ...)
end

local function toCoordinateTable(coords)
    return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
end

local function getCurrentLocation()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash and GetStreetNameFromHashKey(streetHash) or ''
    local crossing = crossingHash and GetStreetNameFromHashKey(crossingHash) or ''

    if street == '' then street = translate('unknown_location') end
    if crossing ~= '' and crossing ~= street then
        street = ('%s / %s'):format(street, crossing)
    end

    return toCoordinateTable(coords), street
end

local function clearBlipCollection(collection)
    for id, entry in pairs(collection) do
        local blip = type(entry) == 'table' and entry.blip or entry
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
        collection[id] = nil
    end
end

local function clearAlertBlip(alertId)
    if type(alertId) == 'string' then
        local blip = alertBlips[alertId]
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
        alertBlips[alertId] = nil
    end
    SetWaypointOff()
end

local function createTimedAlertBlip(data, options)
    if type(data) ~= 'table' or type(data.coords) ~= 'table' then return end

    local x = tonumber(data.coords.x)
    local y = tonumber(data.coords.y)
    local z = tonumber(data.coords.z)
    if not x or not y or not z then return end

    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, options.sprite)
    SetBlipColour(blip, options.color)
    SetBlipScale(blip, options.scale)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, options.flashes)
    if options.flashInterval then SetBlipFlashInterval(blip, options.flashInterval) end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(options.label)
    EndTextCommandSetBlipName(blip)

    local alertId = data.alertId or ('%s-%s'):format(options.label, GetGameTimer())
    alertBlips[alertId] = blip

    CreateThread(function()
        Wait(options.duration)
        if alertBlips[alertId] and DoesBlipExist(alertBlips[alertId]) then
            RemoveBlip(alertBlips[alertId])
        end
        alertBlips[alertId] = nil
    end)
end

RegisterCommand('dutymenu', function()
    if X1S.Client.OnDuty or IsNuiFocused() then return end

    local departments = {}
    for key, department in pairs(Config.Departments) do
        departments[#departments + 1] = { value = key, label = department.label }
    end

    local character = X1S.Client.Character
    local characterName = nil
    if character and character.firstName and character.lastName then
        characterName = ('%s %s'):format(character.firstName, character.lastName)
    end

    SetNuiFocus(true, true)
    X1S.UI.StartTabletAnim()
    X1S.UI.Send({
        action = 'openDuty',
        departments = departments,
        characterName = characterName,
        locale = X1S.UI.Locale(),
        notificationConfig = Config.Notifications
    })
end)

RegisterNUICallback('goOnDuty', function(data, callback)
    if dutyRequestPending or X1S.Client.OnDuty then
        callback({ ok = false, error = translate('duty_pending') })
        return
    end

    dutyRequestPending = true
    TriggerServerEvent('x1s-duty:server:onDuty', data)
    callback({ ok = true })
end)

local function goOffDuty()
    X1S.Client.OnDuty = false
    X1S.Client.Department = nil
    dutyRequestPending = false
    TriggerServerEvent('x1s-duty:server:offDuty')
    clearBlipCollection(dutyBlips)
    clearCurrentCallUi()
end

RegisterCommand('offduty', function()
    if X1S.Client.OnDuty then goOffDuty() end
end)

RegisterNUICallback('offDuty', function(_, callback)
    goOffDuty()
    callback({ ok = true })
end)

RegisterNetEvent('x1s-duty:client:dutyConfirmed', function(data)
    if GetInvokingResource() then return end
    local wasOnDuty = X1S.Client.OnDuty
    dutyRequestPending = false
    X1S.Client.OnDuty = true
    if type(data) == 'table' then
        X1S.Client.Department = data.department
        X1S.Client.CadAccess = data.cadAccess == true
    end
    if not wasOnDuty and not Config.Notifications.announceDutyChanges then
        X1S.UI.Notify('success', translate('notification_duty'), translate('duty_confirmed'))
    end
end)

RegisterNetEvent('x1s-duty:client:dutyDenied', function()
    if GetInvokingResource() then return end
    local wasPending = dutyRequestPending
    dutyRequestPending = false
    X1S.Client.OnDuty = false
    X1S.Client.CadAccess = false
    clearBlipCollection(dutyBlips)
    clearCurrentCallUi()
    if wasPending then
        X1S.UI.Notify('error', translate('notification_duty'), translate('duty_denied'))
    end
end)

RegisterNetEvent('x1s-duty:client:resetDutyState', function()
    if GetInvokingResource() then return end
    X1S.Client.OnDuty = false
    X1S.Client.CadAccess = false
    dutyRequestPending = false
    SetNuiFocus(false, false)
    X1S.UI.StopTabletAnim()
    X1S.UI.Send({ action = 'close' })
    clearBlipCollection(dutyBlips)
    clearBlipCollection(alertBlips)
    clearCurrentCallUi()
end)

RegisterNUICallback('close', function(_, callback)
    SetNuiFocus(false, false)
    X1S.UI.StopTabletAnim()
    callback({ ok = true })
end)

RegisterCommand('supervisormenu', function()
    if IsNuiFocused() then return end
    TriggerServerEvent('x1s-duty:server:requestSupervisorMenu')
end)

RegisterNetEvent('x1s-duty:client:openSupervisor', function(data)
    if GetInvokingResource() then return end
    SetNuiFocus(true, true)
    X1S.UI.StartTabletAnim()
    X1S.UI.Send({
        action = 'openSupervisor',
        players = data,
        locale = X1S.UI.Locale(),
        notificationConfig = Config.Notifications
    })
end)

RegisterNUICallback('forceOff', function(data, callback)
    TriggerServerEvent('x1s-duty:server:forceOffDuty', data)
    callback({ ok = true })
end)

RegisterNetEvent('x1s-duty:client:forceOffResult', function(data)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'forceOffResult', result = data })
end)

RegisterNetEvent('x1s-duty:client:forcedOff', function()
    if GetInvokingResource() then return end
    X1S.Client.OnDuty = false
    X1S.Client.CadAccess = false
    dutyRequestPending = false
    clearBlipCollection(dutyBlips)
    clearCurrentCallUi()
    X1S.UI.Notify('error', translate('notification_duty'), translate('forced_off'), 7000)
end)

RegisterNetEvent('x1s-duty:client:syncBlips', function(players)
    if GetInvokingResource() then return end
    if not X1S.Client.OnDuty or type(players) ~= 'table' then return end

    local myId = GetPlayerServerId(PlayerId())
    local seen = {}

    for serverId, data in pairs(players) do
        local id = tonumber(serverId)
        if id and id ~= myId and type(data) == 'table' and type(data.coords) == 'table' then
            local x, y, z = tonumber(data.coords.x), tonumber(data.coords.y), tonumber(data.coords.z)
            if x and y and z then
                seen[id] = true
                local entry = dutyBlips[id]
                local blip = entry and entry.blip

                if not blip or not DoesBlipExist(blip) then
                    blip = AddBlipForCoord(x, y, z)
                    SetBlipScale(blip, 0.9)
                    SetBlipAsShortRange(blip, false)
                    ShowHeadingIndicatorOnBlip(blip, true)
                    dutyBlips[id] = { blip = blip }
                else
                    SetBlipCoords(blip, x, y, z)
                end

                SetBlipSprite(blip, data.sprite or 1)
                SetBlipColour(blip, data.color or 0)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(('[%s] %s'):format(data.callsign or '000', data.name or translate('unknown')))
                EndTextCommandSetBlipName(blip)
            end
        end
    end

    for id, entry in pairs(dutyBlips) do
        if not seen[id] then
            if entry.blip and DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
            dutyBlips[id] = nil
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Sync.coordinateUpdateInterval)
        if X1S.Client.OnDuty then
            local coords = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('x1s-duty:server:updateCoords', toCoordinateTable(coords))
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(2000)
        TriggerServerEvent('x1s-duty:server:requestDutyState')
    end)
end)

RegisterCommand('911', function()
    if IsNuiFocused() then return end
    SetNuiFocus(true, true)
    X1S.UI.StartTabletAnim()
    X1S.UI.Send({
        action = 'openEmergency',
        locale = X1S.UI.Locale(),
        notificationConfig = Config.Notifications,
        maxLength = Config.Emergency.reportMaxLength
    })
end)

RegisterNUICallback('submitEmergency', function(data, callback)
    local reason = type(data) == 'table' and data.reason or nil
    if type(reason) ~= 'string' or reason:match('^%s*$') then
        callback({ ok = false, error = translate('missing_report') })
        return
    end

    local coords, street = getCurrentLocation()
    TriggerServerEvent('x1s-duty:server:911Call', reason, coords, street)
    callback({ ok = true })
end)

RegisterNetEvent('x1s-duty:client:911Confirmed', function()
    if GetInvokingResource() then return end
    X1S.UI.Notify('success', translate('notification_dispatch'), translate('emergency_sent'))
end)

RegisterNetEvent('x1s-duty:client:received911', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' then return end
    X1S.UI.Send({ action = 'calls911Added', call = data })
end)

RegisterNetEvent('x1s-cad:client:callAccepted', function(call)
    if GetInvokingResource() then return end
    if type(call) ~= 'table' or type(call.alertId) ~= 'string' then return end

    if not alertBlips[call.alertId] then
        createTimedAlertBlip(call, {
            sprite = 9, color = 1, scale = 0.7, flashes = true,
            label = translate('emergency_received_title'),
            duration = Config.Emergency.blipDuration
        })
    end

    currentCallAlertId = call.alertId
    X1S.UI.Send({ action = 'currentCallSet', call = call })
end)

RegisterNetEvent('x1s-cad:client:callLeft', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' or type(data.alertId) ~= 'string' then return end
    clearAlertBlip(data.alertId)
    clearCurrentCallIfMatches(data.alertId)
end)

RegisterCommand('911calls', function()
    if IsNuiFocused() then return end
    TriggerServerEvent('x1s-duty:server:request911Calls')
end)

RegisterNetEvent('x1s-duty:client:open911Calls', function(calls, isSupervisor)
    if GetInvokingResource() then return end
    SetNuiFocus(true, true)
    X1S.UI.StartTabletAnim()
    X1S.UI.Send({
        action = 'openCalls911',
        calls = type(calls) == 'table' and calls or {},
        isSupervisor = isSupervisor == true,
        locale = X1S.UI.Locale(),
        notificationConfig = Config.Notifications
    })
end)

RegisterNUICallback('dismiss911Call', function(data, callback)
    local alertId = type(data) == 'table' and data.alertId or nil
    if type(alertId) ~= 'string' or alertId == '' then
        callback({ ok = false })
        return
    end
    TriggerServerEvent('x1s-duty:server:dismiss911Call', { alertId = alertId })
    callback({ ok = true })
end)

RegisterNetEvent('x1s-duty:client:911CallDismissed', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' or type(data.alertId) ~= 'string' then return end
    X1S.UI.Send({ action = 'calls911Dismissed', alertId = data.alertId })
    clearAlertBlip(data.alertId)
    clearCurrentCallIfMatches(data.alertId)
end)

local hasVisibleCallAlert = false

RegisterNUICallback('callAlertVisibility', function(data, callback)
    hasVisibleCallAlert = type(data) == 'table' and data.visible == true
    callback({ ok = true })
end)

RegisterNUICallback('callAlertRespond', function(data, callback)
    local alertId = type(data) == 'table' and data.alertId or nil
    if type(alertId) == 'string' and alertId ~= '' then
        TriggerServerEvent('x1s-cad:server:acceptCall', alertId)
    end

    local coords = type(data) == 'table' and data.coords or nil
    if type(coords) == 'table' then
        local x, y = tonumber(coords.x), tonumber(coords.y)
        if x and y then SetNewWaypoint(x, y) end
    end

    callback({ ok = true })
end)

RegisterNUICallback('callAlertOpenTablet', function(data, callback)
    local alertId = type(data) == 'table' and data.alertId or nil
    if X1S.Client.OpenCad then X1S.Client.OpenCad(alertId) end
    callback({ ok = true })
end)

local function sendCallAlertKeybind(key)
    if IsNuiFocused() or not hasVisibleCallAlert then return end
    SendNUIMessage({ action = 'callAlertKeybind', key = key })
end

RegisterCommand('x1s911_dismiss', function() sendCallAlertKeybind('dismiss') end, false)
RegisterCommand('x1s911_tablet', function() sendCallAlertKeybind('tablet') end, false)
RegisterCommand('x1s911_respond', function() sendCallAlertKeybind('respond') end, false)
RegisterCommand('x1s911_expand', function() sendCallAlertKeybind('expand') end, false)

RegisterKeyMapping('x1s911_dismiss', 'X1S 911 Alert: Dismiss', 'keyboard', 'P')
RegisterKeyMapping('x1s911_tablet', 'X1S 911 Alert: View in Tablet', 'keyboard', 'K')
RegisterKeyMapping('x1s911_respond', 'X1S 911 Alert: Respond', 'keyboard', 'Z')
RegisterKeyMapping('x1s911_expand', 'X1S 911 Alert: Expand', 'keyboard', 'I')

RegisterNetEvent('x1s-cad:client:callCleared', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' or type(data.alertId) ~= 'string' then return end
    clearAlertBlip(data.alertId)
    clearCurrentCallIfMatches(data.alertId)
end)

RegisterCommand('panic', function()
    if not X1S.Client.OnDuty then
        X1S.UI.Notify('error', translate('notification_panic'), translate('must_be_on_duty'))
        return
    end

    local coords, street = getCurrentLocation()
    TriggerServerEvent('x1s-duty:server:panic', coords, street)
end)

RegisterNetEvent('x1s-duty:client:panicConfirmed', function()
    if GetInvokingResource() then return end
    X1S.UI.Notify('success', translate('notification_panic'), translate('panic_sent'))
end)

RegisterNetEvent('x1s-duty:client:receivedPanic', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' then return end

    X1S.UI.Notify(
        'panic',
        translate('panic_received_title'),
        translate('panic_received', data.name or translate('unknown'), data.callsign or '000', data.street or translate('unknown_location')),
        Config.Notifications.panicDuration
    )

    createTimedAlertBlip(data, {
        sprite = 161, color = 1, scale = 1.35, flashes = true, flashInterval = 500,
        label = translate('panic_received_title'),
        duration = Config.Panic.blipDuration
    })
end)

RegisterNetEvent('x1s-duty:client:panicCleared', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' or type(data.alertId) ~= 'string' then return end
    clearAlertBlip(data.alertId)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearBlipCollection(dutyBlips)
    clearBlipCollection(alertBlips)
end)
