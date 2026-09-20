X1S.DB = X1S.DB or {}

---@param query string
---@param params table|nil
---@return table rows
function X1S.DB.Select(query, params)
    local ok, result = pcall(function()
        return MySQL.query.await(query, params)
    end)
    if not ok then
        print(('^1[X1S][DB] Select failed: %s^0'):format(tostring(result)))
        return {}
    end
    return result or {}
end

---@param query string
---@param params table|nil
---@return table|nil
function X1S.DB.SelectOne(query, params)
    local ok, result = pcall(function()
        return MySQL.single.await(query, params)
    end)
    if not ok then
        print(('^1[X1S][DB] SelectOne failed: %s^0'):format(tostring(result)))
        return nil
    end
    return result
end

---@param query string
---@param params table|nil
---@return number|nil
function X1S.DB.Insert(query, params)
    local ok, result = pcall(function()
        return MySQL.insert.await(query, params)
    end)
    if not ok then
        print(('^1[X1S][DB] Insert failed: %s^0'):format(tostring(result)))
        return nil
    end
    return result
end

---@param query string
---@param params table|nil
---@return number
function X1S.DB.Mutate(query, params)
    local ok, result = pcall(function()
        return MySQL.update.await(query, params)
    end)
    if not ok then
        print(('^1[X1S][DB] Mutate failed: %s^0'):format(tostring(result)))
        return 0
    end
    return result or 0
end

function X1S.DB.EncodeJson(value, isArray)
    if value == nil then
        return isArray and '[]' or '{}'
    end
    local ok, encoded = pcall(json.encode, value)
    if not ok then return isArray and '[]' or '{}' end
    return encoded
end

function X1S.DB.DecodeJson(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if not ok or type(decoded) ~= 'table' then return fallback end
    return decoded
end

local function normalizeDateValue(value)
    local t = type(value)
    if t == 'string' then
        if value == '' or value:match('^0000%-00%-00') then return nil end
        return value
    end
    if t == 'number' then
        local seconds = value > 100000000000 and (value / 1000) or value
        local ok, formatted = pcall(os.date, '!%Y-%m-%d %H:%M:%S', math.floor(seconds))
        return ok and formatted or nil
    end
    return nil
end
X1S.DB.NormalizeDate = normalizeDateValue

function X1S.DB.NormalizeRowDates(row, fields)
    if not row then return row end
    for _, field in ipairs(fields) do
        if row[field] ~= nil then row[field] = normalizeDateValue(row[field]) end
    end
    return row
end

function X1S.DB.NormalizeRowsDates(rows, fields)
    for _, row in ipairs(rows or {}) do
        X1S.DB.NormalizeRowDates(row, fields)
    end
    return rows
end
