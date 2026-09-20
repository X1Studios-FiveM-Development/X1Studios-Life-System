local function translate(key, ...)
    return X1S.Translate(key, ...)
end

local function registerHandCommand(commandName)
    if type(commandName) ~= 'string' or commandName == '' then return end
    RegisterCommand(commandName, function()
        TriggerServerEvent('x1s-id:server:handCard', commandName)
    end, false)
end

registerHandCommand(Config.IDCards.command)

for _, lic in ipairs(Config.Character.Licenses) do
    registerHandCommand(lic.command)
end

local cardVisible = false

local function silhouetteFor(gender)
    local set = Config.IDCards.silhouettes or {}
    return (gender == 'female' and set.female) or set.male
end

RegisterNetEvent('x1s-id:client:showCard', function(card)
    if GetInvokingResource() then return end
    if type(card) ~= 'table' then return end

    X1S.UI.Send({
        action = 'showIdCard',
        card = card,
        silhouette = silhouetteFor(card.gender)
    })
end)

RegisterNUICallback('idCardVisibility', function(data, cb)
    cardVisible = type(data) == 'table' and data.visible == true
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if cardVisible then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 202, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202) then
                cardVisible = false
                X1S.UI.Send({ action = 'hideIdCard' })
            end

            Wait(0)
        else
            Wait(250)
        end
    end
end)
