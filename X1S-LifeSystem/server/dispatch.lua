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

local function isValidPriority(value)
    return value == 'high' or value == 'medium' or value == 'low'
end

local function createDispatchAlert(data)
    if type(data) ~= 'table' or type(data.coords) ~= 'table' and type(data.coords) ~= 'vector3' then
        return false, 'invalid coords'
    end

    local title = cleanString(data.title, 96) or translate('emergency_received_title')
    local street = cleanString(data.street, 96) or translate('unknown_location')
    local coords = { x = data.coords.x + 0.0, y = data.coords.y + 0.0, z = data.coords.z + 0.0 }
    local createdAt = os.time()
    local alertId = ('EXT-%s-%s'):format(os.time(), math.random(1000, 9999))
    local priority = isValidPriority(data.priority) and data.priority
        or (X1S.Server.ClassifyCallPriority and X1S.Server.ClassifyCallPriority(title))
        or 'medium'

    local payload = {
        alertId = alertId,
        caller = cleanString(data.caller, 64) or translate('unknown'),
        id = 0,
        reason = title,
        street = street,
        coords = coords,
        createdAt = createdAt,
        receivedAt = os.date('!%Y-%m-%d %H:%M:%S UTC', createdAt),
        priority = priority,
        status = 'pending',
        acceptedBy = nil
    }

    State.Active911Calls[alertId] = payload
    X1S.Server.BroadcastToDuty('x1s-duty:client:received911', payload)

    return true, alertId
end

X1S.Server.CreateDispatchAlert = createDispatchAlert

exports('CreateDispatchAlert', function(data)
    return createDispatchAlert(data)
end)
