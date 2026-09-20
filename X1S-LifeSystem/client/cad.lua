local cadOpen = false

local function translate(key, ...)
    return X1S.Translate(key, ...)
end

local function openCad(focusAlertId)
    if cadOpen then
        if focusAlertId then
            X1S.UI.Send({ action = 'cadFocusCall', alertId = focusAlertId })
        end
        return
    end
    if not X1S.Client.OnDuty or not X1S.Client.CadAccess then
        X1S.UI.Notify('error', translate('notification_system'), translate('cad_must_be_on_duty'))
        return
    end

    cadOpen = true
    X1S.Client.CadOpen = true
    SetNuiFocus(true, true)
    X1S.UI.StartTabletAnim()
    X1S.UI.Send({
        action = 'openCad',
        context = {
            department = X1S.Client.Department,
            character = X1S.Client.Character,
            charges = Config.CAD.charges,
            tenCodes = Config.CAD.tenCodes,
            penalCodes = Config.CAD.penalCodes,
            licenseDefs = Config.Character.Licenses,
            citationMaxFine = Config.CAD.citationMaxFine,
            citationLineMaxFine = Config.CAD.citationLineMaxFine,
            arrestChargeMaxFine = Config.CAD.arrestChargeMaxFine,
            arrestChargeMaxJailMinutes = Config.CAD.arrestChargeMaxJailMinutes,
            warrantDurationPresets = Config.CAD.warrantDurationPresets,
            vehicleRegistrationRenewalPresets = Config.CAD.vehicleRegistrationRenewalPresets,
            vehicleBoloPriorities = Config.CAD.vehicleBoloPriorities,
            statuses = Config.CAD.statuses,
            focusCall = focusAlertId
        },
        locale = X1S.UI.Locale(),
        notificationConfig = Config.Notifications
    })
    TriggerServerEvent('x1s-cad:server:requestDispatchState')
    TriggerServerEvent('x1s-cad:server:requestPanicState')
    TriggerServerEvent('x1s-cad:server:requestContext')
end

local function closeCad()
    if not cadOpen then return end
    cadOpen = false
    X1S.Client.CadOpen = false
    SetNuiFocus(false, false)
    X1S.UI.StopTabletAnim()
    X1S.UI.Send({ action = 'close' })
end

RegisterCommand(Config.CAD.command, function()
    if cadOpen then closeCad() else openCad() end
end, false)
X1S.Client.OpenCad = openCad

RegisterKeyMapping(Config.CAD.command, 'Open X1S CAD/MDT', 'keyboard', Config.CAD.keybind)

RegisterNUICallback('closeCad', function(_, cb)
    closeCad()
    cb({ ok = true })
end)

RegisterNUICallback('requestDispatchState', function(_, cb)
    TriggerServerEvent('x1s-cad:server:requestDispatchState')
    cb({ ok = true })
end)

RegisterNUICallback('requestPanicState', function(_, cb)
    TriggerServerEvent('x1s-cad:server:requestPanicState')
    cb({ ok = true })
end)

RegisterNUICallback('cadRequestRoster', function(_, cb)
    TriggerServerEvent('x1s-cad:server:requestRoster')
    cb({ ok = true })
end)

RegisterNUICallback('cadSetStatus', function(data, cb)
    if type(data) == 'table' and type(data.status) == 'string' then
        TriggerServerEvent('x1s-cad:server:setStatus', data.status)
    end
    cb({ ok = true })
end)

RegisterNetEvent('x1s-cad:client:forceClose', function()
    if GetInvokingResource() then return end
    if cadOpen then closeCad() end
end)

RegisterNUICallback('cadSearchCitizens', function(data, cb)
    TriggerServerEvent('x1s-cad:server:searchCitizens', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadGetCitizenProfile', function(data, cb)
    TriggerServerEvent('x1s-cad:server:getCitizenProfile', data and data.characterId)
    cb({ ok = true })
end)

RegisterNUICallback('cadUpdateCitizenNotes', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:updateCitizenNotes', data.characterId, data.notes)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadUpdateCitizenLicense', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:updateCitizenLicense', data.characterId, data.license, data.status)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadUpdateCitizenFlags', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:updateCitizenFlags', data.characterId, data.flags)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadSearchVehicles', function(data, cb)
    TriggerServerEvent('x1s-cad:server:searchVehicles', data and data.plate)
    cb({ ok = true })
end)

RegisterNUICallback('cadCreateVehicle', function(data, cb)
    TriggerServerEvent('x1s-cad:server:createVehicle', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadUpdateVehicle', function(data, cb)
    TriggerServerEvent('x1s-cad:server:updateVehicle', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadSetVehicleStolen', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:setVehicleStolen', data.vehicleId, data.stolen == true)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadSetVehicleNotes', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:setVehicleNotes', data.vehicleId, data.notes)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadRenewVehicleRegistration', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:renewVehicleRegistration', data.vehicleId, data.days)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadTransferVehicleOwnership', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:transferVehicleOwnership', data.vehicleId, data.newOwnerId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadSetVehicleRetired', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:setVehicleRetired', data.vehicleId, data.retired == true)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadGetVehicleHistory', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:getVehicleHistory', data.vehicleId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadCreateWarrant', function(data, cb)
    TriggerServerEvent('x1s-cad:server:createWarrant', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadCloseWarrant', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:closeWarrant', data.warrantId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadSearchWarrants', function(data, cb)
    TriggerServerEvent('x1s-cad:server:searchWarrants', data and data.status)
    cb({ ok = true })
end)

RegisterNUICallback('cadCreateVehicleBolo', function(data, cb)
    TriggerServerEvent('x1s-cad:server:createVehicleBolo', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadCloseVehicleBolo', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:closeVehicleBolo', data.boloId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadSearchVehicleBolos', function(data, cb)
    TriggerServerEvent('x1s-cad:server:searchVehicleBolos', data and data.status)
    cb({ ok = true })
end)

RegisterNUICallback('cadCreateArrest', function(data, cb)
    TriggerServerEvent('x1s-cad:server:createArrest', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadCreateCitation', function(data, cb)
    TriggerServerEvent('x1s-cad:server:createCitation', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadCreateIncident', function(data, cb)
    TriggerServerEvent('x1s-cad:server:createIncident', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadUpdateIncident', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:updateIncident', data.incidentId, data)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadSearchIncidents', function(data, cb)
    TriggerServerEvent('x1s-cad:server:searchIncidents', data and data.query)
    cb({ ok = true })
end)

RegisterNUICallback('cadAdminDeleteRecord', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:adminDeleteRecord', data)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadAdminSaveTenCode', function(data, cb)
    TriggerServerEvent('x1s-cad:server:adminSaveTenCode', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadAdminDeleteTenCode', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:adminDeleteTenCode', data)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cadAdminSavePenalCode', function(data, cb)
    TriggerServerEvent('x1s-cad:server:adminSavePenalCode', data)
    cb({ ok = true })
end)

RegisterNUICallback('cadAdminDeletePenalCode', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('x1s-cad:server:adminDeletePenalCode', data)
    end
    cb({ ok = true })
end)

RegisterNetEvent('x1s-cad:client:searchResults', function(payload)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'cadSearchResults', payload = payload })
end)

RegisterNetEvent('x1s-cad:client:citizenProfile', function(profile)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'cadCitizenProfile', profile = profile })
end)

RegisterNetEvent('x1s-cad:client:context', function(context)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'cadContext', context = context })
end)

RegisterNetEvent('x1s-cad:client:roster', function(list)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'cadRoster', list = list })
end)

RegisterNetEvent('x1s-cad:client:referenceData', function(payload)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'cadReferenceData', payload = payload })
end)

RegisterNetEvent('x1s-cad:client:vehicleUpdated', function(vehicle)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'cadVehicleUpdated', vehicle = vehicle })
end)

RegisterNetEvent('x1s-cad:client:vehicleHistory', function(payload)
    if GetInvokingResource() then return end
    X1S.UI.Send({ action = 'cadVehicleHistory', payload = payload })
end)
