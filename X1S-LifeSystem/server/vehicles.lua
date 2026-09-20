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

local function checkCooldown(src, action, duration)
    State.Cooldowns[src] = State.Cooldowns[src] or {}
    local now = os.time()
    local expires = State.Cooldowns[src][action] or 0
    if expires > now then return true, expires - now end
    State.Cooldowns[src][action] = now + duration
    return false, 0
end

local function cleanString(value, maxLength)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return nil end
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function notify(src, notificationType, message)
    TriggerClientEvent('x1s-duty:client:notify', src, {
        type = notificationType, title = translate('notification_system'), message = message
    })
end

RegisterNetEvent('x1s-veh:server:registerVehicle', function(data)
    local src = getRemoteSource()
    if not src then return end

    local character = X1S.Server.GetActiveCharacterRow(src)
    if not character then
        notify(src, 'error', translate('veh_reg_no_character'))
        return
    end

    local coolingDown, remaining = checkCooldown(src, 'vehicleRegister', ServerConfig.Cooldowns.vehicleRegister)
    if coolingDown then
        notify(src, 'warning', translate('wait_seconds', remaining))
        return
    end

    if type(data) ~= 'table' then
        notify(src, 'error', translate('veh_reg_invalid'))
        return
    end

    local cfg = Config.VehicleRegistration
    local brand = cleanString(data.brand, cfg.brandMaxLength)
    local vehType = cleanString(data.type, cfg.typeMaxLength)
    local model = cleanString(data.model, cfg.modelMaxLength)
    local color = cleanString(data.color, cfg.colorMaxLength) or ''
    local plate = cleanString(data.plate, cfg.plateMaxLength)
    local plateState = cleanString(data.plateState, cfg.plateStateMaxLength)
    local year = tonumber(data.year)
    if year and (year < cfg.yearMin or year > cfg.yearMax) then year = nil end

    if not brand or not model or not plate or #plate < cfg.plateMinLength then
        notify(src, 'error', translate('veh_reg_invalid'))
        return
    end

    if cfg.maxOwnedVehicles and cfg.maxOwnedVehicles > 0 then
        local owned = X1S.DB.SelectOne(
            'SELECT COUNT(*) AS total FROM x1s_vehicles WHERE owner_id = ?',
            { character.id }
        )
        if owned and tonumber(owned.total) and tonumber(owned.total) >= cfg.maxOwnedVehicles then
            notify(src, 'error', translate('veh_reg_limit_reached'))
            return
        end
    end

    local existing = X1S.DB.SelectOne('SELECT id FROM x1s_vehicles WHERE plate = ?', { plate })
    if existing then
        notify(src, 'error', translate('veh_reg_plate_taken'))
        return
    end

    local today = os.date('!%Y-%m-%d')
    local expiration = os.date('!%Y-%m-%d', os.time() + (cfg.registrationValidDays * 86400))

    local newId = X1S.DB.Insert(
        'INSERT INTO x1s_vehicles (plate, plate_state, owner_id, brand, vehicle_type, vehicle_year, model, color, registration, registration_date, expiration_date, insured, stolen) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { plate, plateState, character.id, brand, vehType, year, model, color, 'valid', today, expiration, 1, 0 }
    )

    if not newId then
        notify(src, 'error', translate('veh_reg_save_failed'))
        return
    end

    X1S.DB.Mutate(
        'INSERT INTO x1s_vehicle_history (vehicle_id, event_type, details, performed_by, performed_by_id) VALUES (?, ?, ?, ?, ?)',
        { newId, 'registered', translate('veh_history_self_registered', expiration), nil, character.id }
    )

    TriggerClientEvent('x1s-veh:client:registrationResult', src, { ok = true })
    notify(src, 'success', translate('veh_reg_success', plate))
end)

RegisterNetEvent('x1s-veh:server:getMyVehicles', function()
    local src = getRemoteSource()
    if not src then return end

    local character = X1S.Server.GetActiveCharacterRow(src)
    if not character then
        notify(src, 'error', translate('veh_reg_no_character'))
        return
    end

    local coolingDown, remaining = checkCooldown(src, 'vehicleList', ServerConfig.Cooldowns.vehicleList)
    if coolingDown then
        notify(src, 'warning', translate('wait_seconds', remaining))
        return
    end

    local vehicles = X1S.DB.Select('SELECT * FROM x1s_vehicles WHERE owner_id = ? ORDER BY created_at DESC', { character.id })
    X1S.DB.NormalizeRowsDates(vehicles, { 'created_at', 'updated_at', 'registration_date', 'expiration_date', 'retired_at' })

    TriggerClientEvent('x1s-veh:client:myVehicles', src, vehicles)
end)
