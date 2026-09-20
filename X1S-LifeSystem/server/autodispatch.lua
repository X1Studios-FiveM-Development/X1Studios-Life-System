local State = X1S.Server

local function translate(key, ...)
    return X1S.Translate(key, ...)
end

local function cleanString(value, maxLength)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return nil end
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function cleanCoords(coords)
    local coordsType = type(coords)
    if coordsType ~= 'table' and coordsType ~= 'vector3' and coordsType ~= 'vector4' then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000 then return nil end
    return { x = x, y = y, z = z }
end

local function checkCooldown(src, action, duration)
    State.Cooldowns[src] = State.Cooldowns[src] or {}
    local now = os.time()
    local expires = State.Cooldowns[src][action] or 0
    if expires > now then return true end
    State.Cooldowns[src][action] = now + duration
    return false
end

local function getServerPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return nil end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function getRemoteSource()
    if GetInvokingResource() then return nil end
    local src = tonumber(source)
    if not src or src <= 0 then return nil end
    return src
end

local TRIGGERS = {
    carjacking = { configKey = 'carjacking', reasonKey = 'auto_dispatch_carjacking_reason' },
    shotsFired = { configKey = 'shotsFired', reasonKey = 'auto_dispatch_shots_fired_reason' },
    gunPulledPublic = { configKey = 'gunPulledPublic', reasonKey = 'auto_dispatch_gun_pulled_reason' },
    fightInProgress = { configKey = 'fightInProgress', reasonKey = 'auto_dispatch_fight_reason' }
}

RegisterNetEvent('x1s-duty:server:autoDispatch', function(triggerType, coords, street)
    local src = getRemoteSource()
    if not src then
        print(('[AutoDispatch] rejected: not a genuine client-triggered event (triggerType=%s)'):format(tostring(triggerType)))
        return
    end

    local cfg = Config.AutoDispatch
    local trigger = type(triggerType) == 'string' and TRIGGERS[triggerType] or nil
    if not cfg or not cfg.enabled then
        print(('[AutoDispatch:%s] rejected: Config.AutoDispatch.enabled is off'):format(tostring(triggerType)))
        return
    end
    if not trigger then
        print(('[AutoDispatch] rejected: unknown triggerType "%s"'):format(tostring(triggerType)))
        return
    end

    local triggerCfg = cfg[trigger.configKey]
    if not triggerCfg or not triggerCfg.enabled then
        print(('[AutoDispatch:%s] rejected: this trigger is disabled in Config.AutoDispatch'):format(triggerType))
        return
    end

    street = cleanString(street, 96) or translate('unknown_location')
    coords = cleanCoords(coords)
    if not coords then
        print(('[AutoDispatch:%s] rejected: invalid/out-of-range coords from client'):format(triggerType))
        return
    end

    local serverCoords = getServerPlayerCoords(src)
    if serverCoords then
        local distance = math.sqrt(((coords.x - serverCoords.x) ^ 2) + ((coords.y - serverCoords.y) ^ 2) + ((coords.z - serverCoords.z) ^ 2))
        if distance > 50.0 then coords = serverCoords end
    end

    if triggerCfg.cooldown and triggerCfg.cooldown > 0 then
        if checkCooldown(src, 'autoDispatch:' .. triggerType, triggerCfg.cooldown) then
            print(('[AutoDispatch:%s] rejected: src %s is still on cooldown'):format(triggerType, src))
            return
        end
    end

    local ok, alertId = X1S.Server.CreateDispatchAlert({
        title = translate(trigger.reasonKey, street),
        street = street,
        coords = coords,
        caller = translate('auto_dispatch_caller'),
        priority = triggerCfg.priority
    })

    print(('[AutoDispatch:%s] triggered by src %s @ %s (alert created: %s, id: %s)'):format(
        triggerType, src, street, tostring(ok), tostring(alertId)))
end)
