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

local function report(triggerType)
    local coords, street = getCurrentLocation()
    print(('[AutoDispatch] client detected "%s" @ %s - reporting to server'):format(triggerType, street))
    TriggerServerEvent('x1s-duty:server:autoDispatch', triggerType, coords, street)
end

local FIREARM_GROUPS = {
    [`GROUP_PISTOL`] = true,
    [`GROUP_SMG`] = true,
    [`GROUP_SHOTGUN`] = true,
    [`GROUP_RIFLE`] = true,
    [`GROUP_MG`] = true,
    [`GROUP_SNIPER`] = true,
    [`GROUP_HEAVY`] = true
}

local function isFirearm(weaponHash)
    if not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then return false end
    return FIREARM_GROUPS[GetWeapontypeGroup(weaponHash)] == true
end

local MELEE_GROUPS = {
    [`GROUP_UNARMED`] = true,
    [`GROUP_MELEE`] = true
}

local function isMeleeStrike(weaponHash)
    if not weaponHash or weaponHash == 0 then return false end
    if weaponHash == `WEAPON_UNARMED` then return true end
    return MELEE_GROUPS[GetWeapontypeGroup(weaponHash)] == true
end

local function isInExcludedZone(coords, cfg)
    for _, zone in ipairs(cfg.excludeZones or {}) do
        local zoneCoords = zone.coords
        if zoneCoords then
            local dx, dy, dz = coords.x - zoneCoords.x, coords.y - zoneCoords.y, coords.z - zoneCoords.z
            local radius = zone.radius or 50.0
            if (dx * dx + dy * dy + dz * dz) <= (radius * radius) then return true end
        end
    end
    return false
end

local function hasNearbyNpc(radius)
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)

    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= myPed and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) then
            if #(GetEntityCoords(ped) - myCoords) <= radius then return true end
        end
    end

    return false
end

CreateThread(function()
    local cfg = Config.AutoDispatch
    local active = cfg and cfg.enabled and cfg.carjacking and cfg.carjacking.enabled
    print(('[AutoDispatch] carjacking watcher starting (active=%s)'):format(tostring(active)))
    if not active then return end

    while true do
        Wait(0)
        local ped = PlayerPedId()
        if IsPedBeingJacked(ped) then
            local jacker = GetPedsJacker(ped)
            if jacker and jacker ~= 0 then
                report('carjacking')
                Wait(5000)
            else
                print(('[AutoDispatch] IsPedBeingJacked was true but jacker check failed (jacker=%s)'):format(tostring(jacker)))
                Wait(1000)
            end
        end
    end
end)

CreateThread(function()
    local cfg = Config.AutoDispatch
    local active = cfg and cfg.enabled and cfg.carjacking and cfg.carjacking.enabled
    print(('[AutoDispatch] carjacking (perpetrator) watcher starting (active=%s)'):format(tostring(active)))
    if not active then return end

    while true do
        Wait(250)
        local myPed = PlayerPedId()

        for _, ped in ipairs(GetGamePool('CPed')) do
            if ped ~= myPed and not IsPedAPlayer(ped) and IsPedBeingJacked(ped) then
                local jacker = GetPedsJacker(ped)
                if jacker == myPed then
                    report('carjacking')
                    Wait(5000)
                    break
                end
            end
        end
    end
end)

CreateThread(function()
    local cfg = Config.AutoDispatch
    if not (cfg and cfg.enabled and cfg.shotsFired and cfg.shotsFired.enabled) then return end

    while true do
        Wait(300)
        local triggerCfg = cfg.shotsFired
        if not (triggerCfg.ignoreOnDutyOfficers and X1S.Client.OnDuty) then
            local ped = PlayerPedId()
            if IsPedShooting(ped) and isFirearm(GetSelectedPedWeapon(ped)) then
                report('shotsFired')
                Wait(3000)
            end
        end
    end
end)

CreateThread(function()
    local cfg = Config.AutoDispatch
    if not (cfg and cfg.enabled and cfg.gunPulledPublic and cfg.gunPulledPublic.enabled) then return end

    local wasDrawn = false
    while true do
        Wait(750)
        local triggerCfg = cfg.gunPulledPublic
        local ped = PlayerPedId()
        local drawn = isFirearm(GetSelectedPedWeapon(ped))

        if drawn and not wasDrawn then
            local skip = (triggerCfg.ignoreOnDutyOfficers and X1S.Client.OnDuty)
                or (triggerCfg.excludeInteriors and GetInteriorFromEntity(ped) ~= 0)

            if not skip then
                local coords = GetEntityCoords(ped)
                if not isInExcludedZone(coords, triggerCfg) then
                    local npcRequired = triggerCfg.requireNpcNearby
                    local npcNearby = not npcRequired
                        or hasNearbyNpc(triggerCfg.npcRadius or 15.0)
                    if npcNearby then
                        report('gunPulledPublic')
                    end
                end
            end
        end

        wasDrawn = drawn
    end
end)

CreateThread(function()
    local cfg = Config.AutoDispatch
    local active = cfg and cfg.enabled and cfg.fightInProgress and cfg.fightInProgress.enabled
    print(('[AutoDispatch] fightInProgress watcher starting (active=%s)'):format(tostring(active)))
    if not active then return end

    local MELEE_RANGE = 3.0

    while true do
        Wait(300)
        local triggerCfg = cfg.fightInProgress
        if not (triggerCfg.ignoreOnDutyOfficers and X1S.Client.OnDuty) then
            local ped = PlayerPedId()

            if isMeleeStrike(GetSelectedPedWeapon(ped)) then
                local myCoords = GetEntityCoords(ped)
                local hit = nil

                for _, playerId in ipairs(GetActivePlayers()) do
                    local targetPed = GetPlayerPed(playerId)
                    if targetPed ~= 0 and targetPed ~= ped
                        and #(GetEntityCoords(targetPed) - myCoords) <= MELEE_RANGE
                        and HasEntityBeenDamagedByEntity(targetPed, ped, true) then
                        hit = targetPed
                        break
                    end
                end

                if not hit then
                    for _, targetPed in ipairs(GetGamePool('CPed')) do
                        if targetPed ~= ped and not IsPedAPlayer(targetPed)
                            and #(GetEntityCoords(targetPed) - myCoords) <= MELEE_RANGE
                            and HasEntityBeenDamagedByEntity(targetPed, ped, true) then
                            hit = targetPed
                            break
                        end
                    end
                end

                if hit then
                    ClearEntityLastDamageEntity(hit)
                    report('fightInProgress')
                    Wait(2000)
                end
            end
        end
    end
end)
