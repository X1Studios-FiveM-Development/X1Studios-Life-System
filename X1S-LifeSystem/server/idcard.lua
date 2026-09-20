local State = X1S.Server

local function translate(key, ...)
    return X1S.Translate(key, ...)
end

local function getRemoteSource()
    if GetInvokingResource() then return nil end
    local src = tonumber(source)
    if not src or src <= 0 then return nil end
    return src
end

local function cooldownGuard(src, action, duration)
    State.Cooldowns[src] = State.Cooldowns[src] or {}
    local now = os.time()
    local expires = State.Cooldowns[src][action] or 0
    if now < expires then return true, expires - now end
    State.Cooldowns[src][action] = now + (duration or 3)
    return false
end

local itemsByCommand = {}

local function registerItem(commandKey, item)
    if type(commandKey) ~= 'string' or commandKey == '' then return end
    itemsByCommand[commandKey] = item
end

registerItem(Config.IDCards.command, {
    isLicense = false,
    cardTitle = Config.IDCards.cardTitle,
    class = false,
    endorsement = false,
    color = Config.IDCards.color
})

for _, lic in ipairs(Config.Character.Licenses) do
    if lic.command then
        registerItem(lic.command, {
            isLicense = true,
            licenseKey = lic.key,
            licenseLabel = lic.label,
            cardTitle = lic.cardTitle or lic.label,
            class = lic.class or false,
            endorsement = lic.endorsement or false,
            color = lic.color
        })
    end
end

local function derivedWeightLb(heightCm, characterId)
    local base = math.floor((tonumber(heightCm) or 175) * 0.85)
    local variance = (characterId * 17) % 41 - 20
    return math.max(90, base + variance)
end

local function derivedDlNumber(characterId)
    return ('%07d'):format(characterId % 10000000)
end

local function formatHeightFtIn(heightCm)
    local totalInches = (tonumber(heightCm) or 0) / 2.54
    local feet = math.floor(totalInches / 12)
    local inches = math.floor((totalInches - feet * 12) + 0.5)
    if inches >= 12 then
        feet = feet + 1
        inches = 0
    end
    return ('%d\'%02d"'):format(feet, inches)
end

local function usDate(dateString)
    if type(dateString) ~= 'string' then return nil end
    local y, m, d = dateString:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)')
    if not y then return nil end
    return ('%s/%s/%s'):format(m, d, y)
end

local function addYears(dateString, years)
    if type(dateString) ~= 'string' then return nil end
    local y, m, d = dateString:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)')
    if not y then return nil end
    return ('%04d-%s-%s'):format(tonumber(y) + years, m, d)
end

local function buildCard(row, item)
    X1S.DB.NormalizeRowDates(row, { 'dob', 'created_at' })

    local issueDate = row.created_at and row.created_at:match('^(%d%d%d%d%-%d%d%-%d%d)') or nil
    local expirationDate = issueDate and addYears(issueDate, Config.IDCards.validityYears) or nil

    return {
        stateName = Config.IDCards.stateName,
        cardTitle = item.cardTitle,
        isLicense = item.isLicense,
        class = item.class,
        endorsement = item.endorsement,
        color = item.color,

        stateId = row.state_id,
        dlNumber = derivedDlNumber(row.id),
        firstName = row.first_name,
        lastName = row.last_name,
        dob = usDate(row.dob),
        sex = row.gender == 'female' and 'F' or 'M',
        gender = row.gender,
        height = formatHeightFtIn(row.height),
        weight = ('%d lb'):format(derivedWeightLb(row.height, row.id)),
        address = (type(row.address) == 'string' and row.address ~= '') and row.address or nil,
        restrictions = 'NONE',

        issueDate = issueDate and usDate(issueDate) or nil,
        expirationDate = expirationDate and usDate(expirationDate) or nil
    }
end

RegisterNetEvent('x1s-id:server:handCard', function(commandKey)
    local src = getRemoteSource()
    if not src then return end

    local item = itemsByCommand[commandKey]
    if not item then return end

    local coolingDown, remaining = cooldownGuard(src, 'handCard', ServerConfig.Cooldowns.handCard)
    if coolingDown then
        TriggerClientEvent('x1s-duty:client:notify', src, {
            type = 'error', title = translate('notification_system'),
            message = translate('id_card_cooldown', remaining)
        })
        return
    end

    local row = State.ActiveCharacterRow[src]
    if not row then
        TriggerClientEvent('x1s-duty:client:notify', src, {
            type = 'error', title = translate('notification_system'), message = translate('id_card_no_character')
        })
        return
    end

    if item.isLicense then
        local licenses = X1S.DB.DecodeJson(row.licenses, {})
        local status = licenses[item.licenseKey] or 'none'
        if status ~= 'valid' then
            TriggerClientEvent('x1s-duty:client:notify', src, {
                type = 'error', title = translate('notification_system'),
                message = translate('id_card_no_license', item.licenseLabel)
            })
            return
        end
    end

    local senderPed = GetPlayerPed(src)
    if not senderPed or senderPed <= 0 then return end
    local senderCoords = GetEntityCoords(senderPed)

    local card = buildCard(row, item)

    TriggerClientEvent('x1s-id:client:showCard', src, card)

    local radius = Config.IDCards.radius or 3.0
    local radiusSquared = radius * radius

    for _, targetSrcStr in ipairs(GetPlayers()) do
        local targetSrc = tonumber(targetSrcStr)
        if targetSrc and targetSrc ~= src and State.ActiveCharacterRow[targetSrc] then
            local targetPed = GetPlayerPed(targetSrc)
            if targetPed and targetPed > 0 then
                local targetCoords = GetEntityCoords(targetPed)
                local dx = senderCoords.x - targetCoords.x
                local dy = senderCoords.y - targetCoords.y
                local dz = senderCoords.z - targetCoords.z
                if (dx * dx + dy * dy + dz * dz) <= radiusSquared then
                    TriggerClientEvent('x1s-id:client:showCard', targetSrc, card)
                end
            end
        end
    end
end)
