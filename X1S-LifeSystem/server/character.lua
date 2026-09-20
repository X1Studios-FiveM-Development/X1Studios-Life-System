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

local function formatCoordinates(coords)
    return ('X: `%.2f`\nY: `%.2f`\nZ: `%.2f`'):format(coords.x, coords.y, coords.z)
end

local function getServerPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return nil end
    local coords = GetEntityCoords(ped)
    if not coords then return nil end
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function getIdentifier(src, identifierType)
    local prefix = identifierType .. ':'
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, #prefix) == prefix then return identifier:sub(#prefix + 1) end
    end
    return nil
end

local function cleanName(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if #value < 2 or #value > 24 then return nil end
    if not value:match("^[%a][%a%s'%-]*$") then return nil end
    return value
end

local function isValidGender(key)
    for _, g in ipairs(Config.Character.genders) do
        if g.key == key then return g end
    end
    return nil
end

local function calculateAge(dobString)
    local y, m, d = dobString:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
    if not y then return nil end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or not m or not d then return nil end
    if m < 1 or m > 12 or d < 1 or d > 31 then return nil end

    local now = os.date('!*t')
    local age = now.year - y
    if now.month < m or (now.month == m and now.day < d) then age = age - 1 end
    return age, ('%04d-%02d-%02d'):format(y, m, d)
end

local function validateHeight(height)
    height = tonumber(height)
    if not height then return nil end
    height = math.floor(height)
    if height < Config.Character.minHeight or height > Config.Character.maxHeight then return nil end
    return height
end

local function makeStateId(id)
    return ('X1S-%05d'):format(id)
end

local function rowToClient(row)
    if not row then return nil end
    X1S.DB.NormalizeRowDates(row, { 'dob', 'last_played' })
    return {
        id = row.id,
        stateId = row.state_id,
        firstName = row.first_name,
        lastName = row.last_name,
        dob = row.dob,
        gender = row.gender,
        height = row.height,
        licenses = X1S.DB.DecodeJson(row.licenses, {}),
        lastPlayed = row.last_played
    }
end

local function getCharactersForIdentifier(identifier)
    local rows = X1S.DB.Select(
        [[SELECT id, state_id, first_name, last_name, dob, gender, height, last_played
          FROM x1s_characters WHERE identifier = ? AND deleted_at IS NULL
          ORDER BY last_played DESC, created_at DESC]],
        { identifier }
    )
    return X1S.DB.NormalizeRowsDates(rows, { 'dob', 'last_played' })
end

-- Exposed for duty.lua / cad.lua so officer records can be tied to a real
-- character id + name instead of free-typed strings.
State.ActiveCharacterRow = State.ActiveCharacterRow or {}

local function setActiveCharacter(src, row)
    State.ActiveCharacter[src] = row and row.id or nil
    State.ActiveCharacterRow[src] = row
end

function X1S.Server.GetActiveCharacterRow(src)
    return State.ActiveCharacterRow[src]
end

local function sendCreatorScreen(src, canCancel)
    TriggerClientEvent('x1s-char:client:openCreator', src, {
        minAge = Config.Character.minAge,
        maxAge = Config.Character.maxAge,
        minHeight = Config.Character.minHeight,
        maxHeight = Config.Character.maxHeight,
        genders = Config.Character.genders,
        canCancel = canCancel == true
    })
end

local function sendCharacterListOrCreator(src)
    local session = State.Sessions[src]
    if not session then return end

    local rows = getCharactersForIdentifier(session.license)
    if #rows == 0 then
        sendCreatorScreen(src, false)
        return
    end

    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = {
            id = row.id,
            stateId = row.state_id,
            firstName = row.first_name,
            lastName = row.last_name,
            dob = row.dob,
            gender = row.gender,
            lastPlayed = row.last_played,
            height = row.height
        }
    end

    TriggerClientEvent('x1s-char:client:openSelector', src, {
        characters = list,
        maxCharacters = Config.Character.maxCharacters,
        allowDelete = Config.Character.allowDelete,
        allowCreate = #rows < Config.Character.maxCharacters,
        creatorContext = {
            minAge = Config.Character.minAge,
            maxAge = Config.Character.maxAge,
            minHeight = Config.Character.minHeight,
            maxHeight = Config.Character.maxHeight,
            genders = Config.Character.genders
        }
    })
end

RegisterNetEvent('x1s-char:server:requestCharacters', function()
    local src = getRemoteSource()
    if not src then return end

    local identifier = getIdentifier(src, 'license')
    if not identifier then
        TriggerClientEvent('x1s-duty:client:notify', src, {
            type = 'error', title = translate('notification_system'), message = translate('no_license_identifier')
        })
        return
    end

    State.Sessions[src] = { license = identifier, stage = 'selecting' }
    sendCharacterListOrCreator(src)
end)

RegisterNetEvent('x1s-char:server:requestCreatorScreen', function()
    local src = getRemoteSource()
    if not src then return end
    local session = State.Sessions[src]
    if not session then return end

    local existing = getCharactersForIdentifier(session.license)
    if #existing >= Config.Character.maxCharacters then
        TriggerClientEvent('x1s-char:client:selectorError', src, translate('char_limit_reached'))
        return
    end

    sendCreatorScreen(src, true)
end)

RegisterNetEvent('x1s-char:server:createCharacter', function(data)
    local src = getRemoteSource()
    if not src then return end
    local session = State.Sessions[src]
    if not session then return end

    if type(data) ~= 'table' then
        TriggerClientEvent('x1s-char:client:creatorError', src, translate('char_invalid_data'))
        return
    end

    local existing = getCharactersForIdentifier(session.license)
    if #existing >= Config.Character.maxCharacters then
        TriggerClientEvent('x1s-char:client:creatorError', src, translate('char_limit_reached'))
        return
    end

    local firstName = cleanName(data.firstName)
    local lastName = cleanName(data.lastName)
    if not firstName or not lastName then
        TriggerClientEvent('x1s-char:client:creatorError', src, translate('char_invalid_name'))
        return
    end

    local age, normalizedDob = calculateAge(type(data.dob) == 'string' and data.dob or '')
    if not age or age < Config.Character.minAge or age > Config.Character.maxAge then
        TriggerClientEvent('x1s-char:client:creatorError', src, translate('char_invalid_dob', Config.Character.minAge, Config.Character.maxAge))
        return
    end

    local genderDef = isValidGender(data.gender)
    if not genderDef then
        TriggerClientEvent('x1s-char:client:creatorError', src, translate('char_invalid_gender'))
        return
    end

    local height = validateHeight(data.height)
    if not height then
        TriggerClientEvent('x1s-char:client:creatorError', src, translate('char_invalid_height', Config.Character.minHeight, Config.Character.maxHeight))
        return
    end

    local defaultLicenses = {}
    for _, lic in ipairs(Config.Character.Licenses) do
        defaultLicenses[lic.key] = (lic.key == 'driver') and 'valid' or 'none'
    end

    local newId = X1S.DB.Insert(
        [[INSERT INTO x1s_characters
          (state_id, identifier, first_name, last_name, dob, gender, height, licenses, last_played)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())]],
        {
            'PENDING', session.license, firstName, lastName, normalizedDob, genderDef.key, height,
            X1S.DB.EncodeJson(defaultLicenses)
        }
    )

    if not newId then
        TriggerClientEvent('x1s-char:client:creatorError', src, translate('char_save_failed'))
        return
    end

    X1S.DB.Mutate('UPDATE x1s_characters SET state_id = ? WHERE id = ?', { makeStateId(newId), newId })

    local row = X1S.DB.SelectOne('SELECT * FROM x1s_characters WHERE id = ?', { newId })
    if not row then
        TriggerClientEvent('x1s-char:client:creatorError', src, translate('char_save_failed'))
        return
    end

    setActiveCharacter(src, row)
    session.stage = 'spawning'

    X1S.DB.NormalizeRowDates(row, { 'dob' })

    local playerName, discordId = X1S.Log.PlayerIdentity(src)
    X1S.Log.Send('characterCreated', 'Character Created', 3066993, {
        { name = 'Character', value = ('%s %s'):format(row.first_name, row.last_name), inline = true },
        { name = 'State ID', value = row.state_id, inline = true },
        { name = 'Gender', value = row.gender, inline = true },
        { name = 'DOB', value = row.dob or 'Unknown', inline = true },
        { name = 'Height', value = ('%s cm'):format(row.height), inline = true },
        { name = 'Player', value = ('%s (`%s`)'):format(playerName, src), inline = true },
        { name = 'Discord', value = discordId and ('<@%s>'):format(discordId) or 'Not linked', inline = true }
    })

    TriggerClientEvent('x1s-char:client:characterReady', src, rowToClient(row))
end)

RegisterNetEvent('x1s-char:server:selectCharacter', function(characterId)
    local src = getRemoteSource()
    if not src then return end
    local session = State.Sessions[src]
    if not session then return end

    characterId = tonumber(characterId)
    if not characterId then return end

    local row = X1S.DB.SelectOne(
        'SELECT * FROM x1s_characters WHERE id = ? AND identifier = ? AND deleted_at IS NULL',
        { characterId, session.license }
    )
    if not row then
        TriggerClientEvent('x1s-char:client:selectorError', src, translate('char_not_found'))
        return
    end

    X1S.DB.Mutate('UPDATE x1s_characters SET last_played = NOW() WHERE id = ?', { row.id })

    setActiveCharacter(src, row)
    session.stage = 'spawning'

    TriggerClientEvent('x1s-char:client:characterReady', src, rowToClient(row))
end)

RegisterNetEvent('x1s-char:server:deleteCharacter', function(characterId)
    local src = getRemoteSource()
    if not src then return end
    local session = State.Sessions[src]
    if not session or not Config.Character.allowDelete then return end

    characterId = tonumber(characterId)
    if not characterId then return end

    local row = X1S.DB.SelectOne(
        'SELECT id, state_id, first_name, last_name FROM x1s_characters WHERE id = ? AND identifier = ? AND deleted_at IS NULL',
        { characterId, session.license }
    )
    if not row then return end

    X1S.DB.Mutate('UPDATE x1s_characters SET deleted_at = NOW() WHERE id = ?', { row.id })

    local playerName = X1S.Log.PlayerIdentity(src)
    X1S.Log.Send('characterDeleted', 'Character Deleted', 10038562, {
        { name = 'Character', value = ('%s %s'):format(row.first_name, row.last_name), inline = true },
        { name = 'State ID', value = row.state_id, inline = true },
        { name = 'Player', value = ('%s (`%s`)'):format(playerName, src), inline = true }
    })

    sendCharacterListOrCreator(src)
end)

RegisterNetEvent('x1s-char:server:enteredWorld', function()
    local src = getRemoteSource()
    if not src then return end
    local row = State.ActiveCharacterRow[src]
    if row then
        X1S.DB.Mutate('UPDATE x1s_characters SET last_played = NOW() WHERE id = ?', { row.id })

        local playerName, discordId = X1S.Log.PlayerIdentity(src)
        local fields = {
            { name = 'Character', value = ('%s %s'):format(row.first_name, row.last_name), inline = true },
            { name = 'State ID', value = row.state_id, inline = true },
            { name = 'Player', value = ('%s (`%s`)'):format(playerName, src), inline = true },
            { name = 'Discord', value = discordId and ('<@%s>'):format(discordId) or 'Not linked', inline = true }
        }

        local coords = getServerPlayerCoords(src)
        if coords then
            fields[#fields + 1] = { name = 'Location', value = formatCoordinates(coords), inline = true }
        end

        X1S.Log.Send('playerSpawn', 'Player Spawned In', 3447003, fields)
    end
    if State.Sessions[src] then State.Sessions[src].stage = 'in-world' end
end)

AddEventHandler('playerDropped', function()
    local src = source
    State.Sessions[src] = nil
    State.ActiveCharacter[src] = nil
    State.ActiveCharacterRow[src] = nil
end)
