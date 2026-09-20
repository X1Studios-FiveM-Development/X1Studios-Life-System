RegisterNUICallback('cadAcceptCall', function(data, cb)
    if type(data) == 'table' and type(data.alertId) == 'string' then
        TriggerServerEvent('x1s-cad:server:acceptCall', data.alertId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadLeaveCall', function(data, cb)
    if type(data) == 'table' and type(data.alertId) == 'string' then
        TriggerServerEvent('x1s-cad:server:leaveCall', data.alertId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadCompleteCall', function(data, cb)
    if type(data) == 'table' and type(data.alertId) == 'string' then
        TriggerServerEvent('x1s-cad:server:completeCall', data.alertId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadSetWaypoint', function(data, cb)
    if type(data) == 'table' and type(data.coords) == 'table' then
        local x, y = tonumber(data.coords.x), tonumber(data.coords.y)
        if x and y then
            SetNewWaypoint(x, y)
        end
    end
    cb({ ok = true })
end)

RegisterNetEvent('x1s-cad:client:dispatchState', function(calls)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'cadDispatchState', calls = type(calls) == 'table' and calls or {} })
end)

RegisterNetEvent('x1s-cad:client:callUpdated', function(call)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'cadCallUpdated', call = call })
end)

RegisterNetEvent('x1s-cad:client:callCleared', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' then return end
    X1S.UI.Send({ action = 'cadCallCleared', alertId = data.alertId })
end)

RegisterNUICallback('cadClearPanic', function(data, cb)
    if type(data) == 'table' and type(data.alertId) == 'string' then
        TriggerServerEvent('x1s-duty:server:clearPanic', { alertId = data.alertId })
    end
    cb({ ok = true })
end)

RegisterNetEvent('x1s-cad:client:panicState', function(data)
    if GetInvokingResource() then return end
    data = type(data) == 'table' and data or {}
    X1S.UI.Send({
        action = 'cadPanicState',
        alerts = type(data.alerts) == 'table' and data.alerts or {},
        isSupervisor = data.isSupervisor == true
    })
end)

RegisterNetEvent('x1s-cad:client:panicUpdated', function(alert)
    if GetInvokingResource() then return end
    if type(alert) ~= 'table' then return end
    X1S.UI.Send({ action = 'cadPanicUpdated', alert = alert })
end)

RegisterNetEvent('x1s-duty:client:panicCleared', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' or type(data.alertId) ~= 'string' then return end
    X1S.UI.Send({ action = 'cadPanicCleared', alertId = data.alertId })
end)
