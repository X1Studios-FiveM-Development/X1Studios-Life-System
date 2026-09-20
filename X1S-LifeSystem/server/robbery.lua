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

local function cfg()
    return Config.Robbery
end

local function findLocation(locationId)
    if type(locationId) ~= 'string' then return nil end
    for _, location in ipairs(cfg().locations) do
        if location.id == locationId then return location end
    end
    return nil
end

local function locationState(locationId)
    State.RobberyLocations[locationId] = State.RobberyLocations[locationId] or { cooldownUntil = 0, activeSrc = nil }
    return State.RobberyLocations[locationId]
end

local function getServerPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return nil end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function distance(a, b)
    return math.sqrt(((a.x - b.x) ^ 2) + ((a.y - b.y) ^ 2) + ((a.z - b.z) ^ 2))
end

local function getStreetLabel(location)
    return location.label or translate('unknown_location')
end

local function minigameConfigFor(locationType)
    if locationType == 'bank' then return cfg().fingerprint.bank end
    if locationType == 'atm' then return cfg().fingerprint.atm end
    return nil
end

local function minimumPlausibleMs(location)
    if location.type == 'store' then
        return math.max((cfg().progressBar.durationMs or 0) - 1500, 0)
    end
    local mg = minigameConfigFor(location.type)
    if not mg then return 0 end
    return math.floor((mg.rings or 1) * 350)
end

local function isOnDuty(src)
    return State.DutyPlayers[src] ~= nil
end

local function clearActive(src)
    local active = State.RobberyActive[src]
    State.RobberyActive[src] = nil
    if active then
        local locState = locationState(active.locationId)
        if locState.activeSrc == src then
            locState.activeSrc = nil
        end
    end
    return active
end

RegisterNetEvent('x1s-robbery:server:start', function(locationId)
    local src = getRemoteSource()
    if not src then return end

    if not (cfg() and cfg().enabled) then return end

    if State.RobberyActive[src] then
        return
    end

    local location = findLocation(locationId)
    if not location then
        print(('[Robbery] rejected start: unknown locationId "%s" from src %s'):format(tostring(locationId), src))
        return
    end

    if cfg().blockOnDuty and isOnDuty(src) then
        TriggerClientEvent('x1s-robbery:client:denied', src, 'onDuty')
        return
    end

    local playerCoords = getServerPlayerCoords(src)
    if not playerCoords or distance(playerCoords, location.coords) > cfg().maxStartDistance then
        TriggerClientEvent('x1s-robbery:client:denied', src, 'tooFar')
        return
    end

    local locState = locationState(locationId)
    local now = os.time()
    if locState.activeSrc ~= nil or locState.cooldownUntil > now then
        TriggerClientEvent('x1s-robbery:client:denied', src, 'cooldown', locState.cooldownUntil - now)
        return
    end

    local cooldownKey = 'robbery:' .. location.type
    State.Cooldowns[src] = State.Cooldowns[src] or {}
    local playerCooldownExpires = State.Cooldowns[src][cooldownKey] or 0
    if playerCooldownExpires > now then
        TriggerClientEvent('x1s-robbery:client:denied', src, 'playerCooldown', playerCooldownExpires - now)
        return
    end

    locState.activeSrc = src
    State.RobberyActive[src] = { locationId = locationId, type = location.type, startedAt = now }

    local street = getStreetLabel(location)
    local reasonKey = location.type == 'bank' and 'robbery_dispatch_bank_reason'
        or location.type == 'atm' and 'robbery_dispatch_atm_reason'
        or 'robbery_dispatch_store_reason'

    X1S.Server.CreateDispatchAlert({
        title = translate(reasonKey, location.label),
        street = street,
        coords = location.coords,
        caller = translate('robbery_dispatch_caller'),
        priority = 'high'
    })

    local mg = minigameConfigFor(location.type)
    TriggerClientEvent('x1s-robbery:client:started', src, {
        locationId = locationId,
        type = location.type,
        label = location.label,
        fingerprint = mg,
        progressBarDurationMs = location.type == 'store' and cfg().progressBar.durationMs or nil
    })

    print(('[Robbery] src %s started a %s robbery at "%s" (%s)'):format(src, location.type, location.label, locationId))
end)

RegisterNetEvent('x1s-robbery:server:cancel', function(locationId)
    local src = getRemoteSource()
    if not src then return end

    local active = State.RobberyActive[src]
    if not active or active.locationId ~= locationId then return end

    clearActive(src)
    local locState = locationState(locationId)
    locState.cooldownUntil = os.time() + (cfg().cancelLocationCooldown or 60)

    TriggerClientEvent('x1s-robbery:client:result', src, { ok = false, reason = 'cancelled' })
end)

RegisterNetEvent('x1s-robbery:server:fail', function(locationId)
    local src = getRemoteSource()
    if not src then return end

    local active = State.RobberyActive[src]
    if not active or active.locationId ~= locationId then return end

    clearActive(src)
    local location = findLocation(locationId)
    local locState = locationState(locationId)
    locState.cooldownUntil = os.time() + (cfg().cancelLocationCooldown or 60)

    TriggerClientEvent('x1s-robbery:client:result', src, {
        ok = false,
        reason = 'failed',
        label = location and location.label or nil
    })
end)

RegisterNetEvent('x1s-robbery:server:complete', function(locationId)
    local src = getRemoteSource()
    if not src then return end

    local active = State.RobberyActive[src]
    if not active or active.locationId ~= locationId then
        print(('[Robbery] rejected complete: src %s has no matching active robbery for "%s"'):format(src, tostring(locationId)))
        return
    end

    local location = findLocation(locationId)
    if not location then
        clearActive(src)
        return
    end

    local playerCoords = getServerPlayerCoords(src)
    if not playerCoords or distance(playerCoords, location.coords) > cfg().maxStartDistance then
        clearActive(src)
        TriggerClientEvent('x1s-robbery:client:denied', src, 'tooFar')
        return
    end

    local elapsedMs = (os.time() - active.startedAt) * 1000
    if elapsedMs < minimumPlausibleMs(location) then
        print(('[Robbery] rejected complete: src %s finished "%s" implausibly fast (%dms)'):format(src, locationId, elapsedMs))
        clearActive(src)
        TriggerClientEvent('x1s-robbery:client:result', src, { ok = false, reason = 'failed', label = location.label })
        return
    end

    clearActive(src)

    local now = os.time()
    local locState = locationState(locationId)
    locState.cooldownUntil = now + (cfg().locationCooldown[location.type] or 900)

    State.Cooldowns[src] = State.Cooldowns[src] or {}
    State.Cooldowns[src]['robbery:' .. location.type] = now + (cfg().playerCooldown[location.type] or 600)

    -- NO CASH: nothing is granted here on purpose. This is the confirmation
    -- notification the client shows on success.
    TriggerClientEvent('x1s-robbery:client:result', src, { ok = true, label = location.label })

    print(('[Robbery] src %s completed a %s robbery at "%s"'):format(src, location.type, location.label))
end)

AddEventHandler('playerDropped', function()
    local src = source
    if State.RobberyActive[src] then
        clearActive(src)
    end
end)
