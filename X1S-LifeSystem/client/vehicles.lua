local vehicleRegOpen = false

local function translate(key, ...)
    return X1S.Translate(key, ...)
end

local function openVehicleRegistration()
    if vehicleRegOpen then return end
    if not X1S.Client.Character then
        X1S.UI.Notify('error', translate('notification_system'), translate('veh_reg_no_character'))
        return
    end

    vehicleRegOpen = true
    SetNuiFocus(true, true)
    X1S.UI.StartTabletAnim()
    X1S.UI.Send({
        action = 'openVehicleRegistration',
        locale = X1S.UI.Locale(),
        notificationConfig = Config.Notifications
    })
end

local function closeVehicleRegistration()
    if not vehicleRegOpen then return end
    vehicleRegOpen = false
    SetNuiFocus(false, false)
    X1S.UI.StopTabletAnim()
    X1S.UI.Send({ action = 'close' })
end

RegisterCommand(Config.VehicleRegistration.command, function()
    if vehicleRegOpen then return end
    openVehicleRegistration()
end, false)

RegisterNUICallback('closeVehicleReg', function(_, cb)
    closeVehicleRegistration()
    cb({ ok = true })
end)

RegisterNUICallback('submitVehicleRegistration', function(data, cb)
    TriggerServerEvent('x1s-veh:server:registerVehicle', data)
    cb({ ok = true })
end)

RegisterNUICallback('requestMyVehicles', function(_, cb)
    TriggerServerEvent('x1s-veh:server:getMyVehicles')
    cb({ ok = true })
end)

RegisterNetEvent('x1s-veh:client:registrationResult', function(result)
    if GetInvokingResource() then return end
    if type(result) == 'table' and result.ok then
        closeVehicleRegistration()
    end
end)

RegisterNetEvent('x1s-veh:client:myVehicles', function(vehicles)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'myVehicles', vehicles = vehicles })
end)
