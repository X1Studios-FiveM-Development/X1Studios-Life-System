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

local function flagBool(v)
    return v == 1 or v == true
end

local function cleanString(value, maxLength)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return nil end
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function cleanDate(value)
    if type(value) ~= 'string' then return nil end
    if not value:match('^%d%d%d%d%-%d%d%-%d%d$') then return nil end
    return value
end

local function cleanYear(value)
    local year = tonumber(value)
    if not year then return nil end
    year = math.floor(year)
    if year < Config.VehicleRegistration.yearMin or year > Config.VehicleRegistration.yearMax then return nil end
    return year
end

local function logVehicleHistory(logKey, title, color, vehicleId, plate, eventType, details, ctx)
    X1S.DB.Mutate(
        'INSERT INTO x1s_vehicle_history (vehicle_id, event_type, details, performed_by, performed_by_id) VALUES (?, ?, ?, ?, ?)',
        { vehicleId, eventType, details, ctx.name, ctx.charId }
    )
    X1S.Log.Send(logKey, title, color, {
        { name = 'Plate', value = plate or ('#%d'):format(vehicleId), inline = true },
        { name = 'Details', value = details or '', inline = false },
        { name = 'By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true }
    })
end

local PENAL_CODE_TYPES = { Felony = true, Misdemeanor = true }

local function loadTenCodes()
    return X1S.DB.Select('SELECT id, code, label FROM x1s_ten_codes ORDER BY sort_order ASC, id ASC')
end

local function loadPenalCodes()
    local rows = X1S.DB.Select(
        [[SELECT id, code, title, type, bond_type AS bondType, bond_amount AS bondAmount, jail_time AS jailTime
          FROM x1s_penal_codes ORDER BY sort_order ASC, id ASC]]
    )
    for _, row in ipairs(rows) do
        row.bondAmount = tonumber(row.bondAmount) or 0
    end
    return rows
end

CreateThread(function()
    Wait(1500)

    local tcCount = X1S.DB.SelectOne('SELECT COUNT(*) AS total FROM x1s_ten_codes')
    if tcCount and tonumber(tcCount.total) == 0 then
        for i, tc in ipairs(Config.CAD.tenCodes) do
            X1S.DB.Insert('INSERT INTO x1s_ten_codes (code, label, sort_order) VALUES (?, ?, ?)', { tc.code, tc.label, i })
        end
        print(('^2[X1S][CAD] Seeded %d ten-codes from config.lua into x1s_ten_codes.^0'):format(#Config.CAD.tenCodes))
    end

    local pcCount = X1S.DB.SelectOne('SELECT COUNT(*) AS total FROM x1s_penal_codes')
    if pcCount and tonumber(pcCount.total) == 0 then
        for i, pc in ipairs(Config.CAD.penalCodes) do
            X1S.DB.Insert(
                [[INSERT INTO x1s_penal_codes (code, title, type, bond_type, bond_amount, jail_time, sort_order)
                  VALUES (?, ?, ?, ?, ?, ?, ?)]],
                { pc.code, pc.title, PENAL_CODE_TYPES[pc.type] and pc.type or 'Misdemeanor', pc.bondType, pc.bondAmount, pc.jailTime, i }
            )
        end
        print(('^2[X1S][CAD] Seeded %d penal codes from config.lua into x1s_penal_codes.^0'):format(#Config.CAD.penalCodes))
    end
end)

local function canAccessCad(src)
    local officer = State.DutyPlayers[src]
    if not officer then
        return false, translate('cad_must_be_on_duty')
    end

    local dept = Config.Departments[officer.department]
    if not dept or not dept.cad then
        return false, translate('cad_department_denied')
    end

    local allowed = false
    for _, key in ipairs(Config.CAD.accessDepartments) do
        if key == officer.department then allowed = true break end
    end
    if not allowed then
        return false, translate('cad_department_denied')
    end

    return true, {
        department = officer.department,
        departmentLabel = dept.label,
        callsign = officer.callsign,
        rank = officer.rank,
        name = officer.name,
        status = officer.status or 'active',
        charId = officer.charId,
        stateId = officer.stateId
    }
end

local function withCadAuth(handler)
    return function(...)
        local src = getRemoteSource()
        if not src then return end

        local ok, ctxOrReason = canAccessCad(src)
        if not ok then
            TriggerClientEvent('x1s-duty:client:notify', src, {
                type = 'error', title = translate('notification_system'), message = ctxOrReason
            })
            return
        end

        handler(src, ctxOrReason, ...)
    end
end

local function cooldownGuard(src, action, duration)
    local coolingDown = checkCooldown(src, action, duration)
    return coolingDown
end

RegisterNetEvent('x1s-cad:server:requestContext', withCadAuth(function(src, ctx)
    local deptCfg = Config.Departments[ctx.department]
    TriggerClientEvent('x1s-cad:client:context', src, {
        name = ctx.name,
        callsign = ctx.callsign,
        rank = ctx.rank,
        status = ctx.status,
        department = ctx.department,
        departmentLabel = ctx.departmentLabel,
        logo = deptCfg and deptCfg.logo or nil,
        serverId = src,
        isAdmin = X1S.Server.IsAdmin(src),
        tenCodes = loadTenCodes(),
        penalCodes = loadPenalCodes()
    })
end))

RegisterNetEvent('x1s-cad:server:setStatus', withCadAuth(function(src, ctx, status)
    if type(status) ~= 'string' then return end

    local allowed = false
    for _, s in ipairs(Config.CAD.statuses or {}) do
        if s.key == status then allowed = true break end
    end
    if not allowed then return end

    local officer = State.DutyPlayers[src]
    if not officer then return end
    officer.status = status
end))

RegisterNetEvent('x1s-cad:server:requestRoster', withCadAuth(function(src, ctx)
    local list = {}
    for _, officer in pairs(State.DutyPlayers) do
        local deptCfg = Config.Departments[officer.department]
        list[#list + 1] = {
            name = officer.name,
            callsign = officer.callsign,
            rank = officer.rank,
            department = officer.department,
            departmentLabel = deptCfg and deptCfg.label or officer.department,
            logo = deptCfg and deptCfg.logo or nil,
            status = officer.status or 'active'
        }
    end

    table.sort(list, function(a, b)
        if a.departmentLabel ~= b.departmentLabel then return a.departmentLabel < b.departmentLabel end
        return a.callsign < b.callsign
    end)

    TriggerClientEvent('x1s-cad:client:roster', src, list)
end))

local function characterSummary(row)
    X1S.DB.NormalizeRowDates(row, { 'dob' })
    return {
        id = row.id,
        stateId = row.state_id,
        firstName = row.first_name,
        lastName = row.last_name,
        dob = row.dob,
        gender = row.gender,
        height = row.height,
        isArmed = flagBool(row.is_armed),
        isViolent = flagBool(row.is_violent),
        isMentallyIll = flagBool(row.is_mentally_ill)
    }
end

RegisterNetEvent('x1s-cad:server:searchCitizens', withCadAuth(function(src, ctx, query)
    if cooldownGuard(src, 'cadSearch', ServerConfig.Cooldowns.cadSearch) then return end

    query = type(query) == 'table' and query or {}
    local firstName = cleanString(query.firstName, 32)
    local lastName = cleanString(query.lastName, 32)
    local dob = cleanString(query.dob, 10)
    local stateId = cleanString(query.stateId, 16)

    if not firstName and not lastName and not dob and not stateId then
        TriggerClientEvent('x1s-cad:client:searchResults', src, { type = 'citizen', results = {} })
        return
    end

    local where, params = {}, {}
    if firstName then where[#where + 1] = 'first_name LIKE ?'; params[#params + 1] = '%' .. firstName .. '%' end
    if lastName then where[#where + 1] = 'last_name LIKE ?'; params[#params + 1] = '%' .. lastName .. '%' end
    if dob then where[#where + 1] = 'dob = ?'; params[#params + 1] = dob end
    if stateId then where[#where + 1] = 'state_id LIKE ?'; params[#params + 1] = '%' .. stateId .. '%' end

    local rows = X1S.DB.Select(
        ('SELECT id, state_id, first_name, last_name, dob, gender, height, is_armed, is_violent, is_mentally_ill FROM x1s_characters WHERE deleted_at IS NULL AND %s ORDER BY last_name, first_name LIMIT %d')
            :format(table.concat(where, ' AND '), Config.CAD.maxSearchResults),
        params
    )

    local results = {}
    for _, row in ipairs(rows) do results[#results + 1] = characterSummary(row) end
    TriggerClientEvent('x1s-cad:client:searchResults', src, { type = 'citizen', results = results })
end))

local function sendCitizenProfile(src, characterId)
    local row = X1S.DB.SelectOne('SELECT * FROM x1s_characters WHERE id = ? AND deleted_at IS NULL', { characterId })
    if not row then
        TriggerClientEvent('x1s-cad:client:citizenProfile', src, nil)
        return
    end

    local vehicles = X1S.DB.Select('SELECT * FROM x1s_vehicles WHERE owner_id = ? ORDER BY created_at DESC', { characterId })
    local warrants = X1S.DB.Select('SELECT * FROM x1s_warrants WHERE character_id = ? ORDER BY created_at DESC', { characterId })
    local arrests = X1S.DB.Select('SELECT * FROM x1s_arrests WHERE character_id = ? ORDER BY created_at DESC', { characterId })
    local citations = X1S.DB.Select('SELECT * FROM x1s_citations WHERE character_id = ? ORDER BY created_at DESC', { characterId })

    X1S.DB.NormalizeRowDates(row, { 'dob', 'last_played' })
    X1S.DB.NormalizeRowsDates(vehicles, { 'created_at', 'updated_at', 'registration_date', 'expiration_date', 'retired_at' })
    X1S.DB.NormalizeRowsDates(warrants, { 'created_at', 'expires_at', 'closed_at' })
    X1S.DB.NormalizeRowsDates(arrests, { 'created_at' })
    X1S.DB.NormalizeRowsDates(citations, { 'created_at' })

    for _, a in ipairs(arrests) do a.charges = X1S.DB.DecodeJson(a.charges, {}); a.assisting = X1S.DB.DecodeJson(a.assisting, {}) end
    for _, c in ipairs(citations) do c.violations = X1S.DB.DecodeJson(c.violations, {}) end
    for _, w in ipairs(warrants) do w.charges = X1S.DB.DecodeJson(w.charges, {}) end

    TriggerClientEvent('x1s-cad:client:citizenProfile', src, {
        id = row.id,
        stateId = row.state_id,
        firstName = row.first_name,
        lastName = row.last_name,
        dob = row.dob,
        gender = row.gender,
        height = row.height,
        licenses = X1S.DB.DecodeJson(row.licenses, {}),
        notes = row.notes,
        licenseDefs = Config.Character.Licenses,
        isArmed = flagBool(row.is_armed),
        isViolent = flagBool(row.is_violent),
        isMentallyIll = flagBool(row.is_mentally_ill),
        vehicles = vehicles,
        warrants = warrants,
        arrests = arrests,
        citations = citations
    })
end

RegisterNetEvent('x1s-cad:server:getCitizenProfile', withCadAuth(function(src, ctx, characterId)
    characterId = tonumber(characterId)
    if not characterId then return end
    sendCitizenProfile(src, characterId)
end))

RegisterNetEvent('x1s-cad:server:updateCitizenNotes', withCadAuth(function(src, ctx, characterId, notes)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    characterId = tonumber(characterId)
    notes = cleanString(notes, 2000) or ''
    if not characterId then return end

    X1S.DB.Mutate('UPDATE x1s_characters SET notes = ? WHERE id = ?', { notes, characterId })

    local citizen = X1S.DB.SelectOne('SELECT state_id, first_name, last_name FROM x1s_characters WHERE id = ?', { characterId })
    if citizen then
        X1S.Log.Send('citizenNotesUpdated', 'Citizen Notes Updated', 9807270, {
            { name = 'Citizen', value = ('%s %s (%s)'):format(citizen.first_name, citizen.last_name, citizen.state_id), inline = true },
            { name = 'Updated By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true }
        })
    end

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

RegisterNetEvent('x1s-cad:server:updateCitizenLicense', withCadAuth(function(src, ctx, characterId, licenseKey, status)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    characterId = tonumber(characterId)
    if not characterId then return end

    local validKey = false
    for _, lic in ipairs(Config.Character.Licenses) do
        if lic.key == licenseKey then validKey = true break end
    end
    local validStatuses = { none = true, pending = true, valid = true, suspended = true, revoked = true }
    if not validKey or not validStatuses[status] then return end

    local row = X1S.DB.SelectOne('SELECT licenses FROM x1s_characters WHERE id = ?', { characterId })
    if not row then return end

    local licenses = X1S.DB.DecodeJson(row.licenses, {})
    licenses[licenseKey] = status
    X1S.DB.Mutate('UPDATE x1s_characters SET licenses = ? WHERE id = ?', { X1S.DB.EncodeJson(licenses), characterId })

    local citizen = X1S.DB.SelectOne('SELECT state_id, first_name, last_name FROM x1s_characters WHERE id = ?', { characterId })
    if citizen then
        local licenseLabel = licenseKey
        for _, lic in ipairs(Config.Character.Licenses) do
            if lic.key == licenseKey then licenseLabel = lic.label break end
        end
        X1S.Log.Send('citizenLicenseUpdated', 'Citizen License Updated', 1752220, {
            { name = 'Citizen', value = ('%s %s (%s)'):format(citizen.first_name, citizen.last_name, citizen.state_id), inline = true },
            { name = 'License', value = licenseLabel, inline = true },
            { name = 'New Status', value = status, inline = true },
            { name = 'Updated By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true }
        })
    end

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

RegisterNetEvent('x1s-cad:server:updateCitizenFlags', withCadAuth(function(src, ctx, characterId, flags)
    if cooldownGuard(src, 'cadFlagWrite', ServerConfig.Cooldowns.cadFlagWrite) then return end
    characterId = tonumber(characterId)
    if not characterId or type(flags) ~= 'table' then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = 'Flag update rejected - bad payload (mismatched client/server files?)' })
        return
    end

    local wantArmed = flags.isArmed == true and 1 or 0
    local wantViolent = flags.isViolent == true and 1 or 0
    local wantMentallyIll = flags.isMentallyIll == true and 1 or 0

    X1S.DB.Mutate(
        'UPDATE x1s_characters SET is_armed = ?, is_violent = ?, is_mentally_ill = ? WHERE id = ?',
        { wantArmed, wantViolent, wantMentallyIll, characterId }
    )

    local check = X1S.DB.SelectOne('SELECT is_armed, is_violent, is_mentally_ill FROM x1s_characters WHERE id = ?', { characterId })
    if not check or flagBool(check.is_armed) ~= (wantArmed == 1) or flagBool(check.is_violent) ~= (wantViolent == 1) or flagBool(check.is_mentally_ill) ~= (wantMentallyIll == 1) then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = 'Flag save failed - check server console (likely missing DB columns, run the SQL migration)' })
        return
    end

    local citizen = X1S.DB.SelectOne('SELECT state_id, first_name, last_name FROM x1s_characters WHERE id = ?', { characterId })
    if citizen then
        X1S.Log.Send('citizenFlagsUpdated', 'Citizen Flags Updated', 10181046, {
            { name = 'Citizen', value = ('%s %s (%s)'):format(citizen.first_name, citizen.last_name, citizen.state_id), inline = true },
            { name = 'Flags', value = X1S.Log.FlagSummary(wantArmed == 1, wantViolent == 1, wantMentallyIll == 1), inline = true },
            { name = 'Updated By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true }
        })
    end

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

RegisterNetEvent('x1s-cad:server:searchVehicles', withCadAuth(function(src, ctx, plate)
    if cooldownGuard(src, 'cadSearch', ServerConfig.Cooldowns.cadSearch) then return end
    plate = cleanString(plate, 16)
    if not plate then
        TriggerClientEvent('x1s-cad:client:searchResults', src, { type = 'vehicle', results = {} })
        return
    end

    local rows = X1S.DB.Select(
        [[SELECT v.*, c.first_name, c.last_name, c.state_id AS owner_state_id
          FROM x1s_vehicles v LEFT JOIN x1s_characters c ON c.id = v.owner_id
          WHERE v.plate LIKE ? ORDER BY v.created_at DESC LIMIT ?]],
        { '%' .. plate .. '%', Config.CAD.maxSearchResults }
    )
    X1S.DB.NormalizeRowsDates(rows, { 'created_at', 'updated_at', 'registration_date', 'expiration_date', 'retired_at' })
    TriggerClientEvent('x1s-cad:client:searchResults', src, { type = 'vehicle', results = rows })
end))

RegisterNetEvent('x1s-cad:server:createVehicle', withCadAuth(function(src, ctx, data)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    if type(data) ~= 'table' then return end

    local plate = cleanString(data.plate, 16)
    local plateState = cleanString(data.plateState, Config.VehicleRegistration.plateStateMaxLength)
    local brand = cleanString(data.brand, 32)
    local vehType = cleanString(data.type, 64)
    local year = cleanYear(data.year)
    local model = cleanString(data.model, 64)
    local color = cleanString(data.color, 32) or ''
    local ownerId = tonumber(data.ownerId)
    if not plate or not model then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_vehicle') })
        return
    end

    local existing = X1S.DB.SelectOne('SELECT id FROM x1s_vehicles WHERE plate = ?', { plate })
    if existing then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_plate_taken') })
        return
    end

    local registrationDate = cleanDate(data.registrationDate) or os.date('!%Y-%m-%d')
    local expirationDate = cleanDate(data.expirationDate)
        or os.date('!%Y-%m-%d', os.time() + (Config.VehicleRegistration.registrationValidDays * 86400))

    local newId = X1S.DB.Insert(
        [[INSERT INTO x1s_vehicles
          (plate, plate_state, owner_id, brand, vehicle_type, vehicle_year, model, color, registration, registration_date, expiration_date, insured, stolen)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { plate, plateState, ownerId, brand, vehType, year, model, color, 'valid', registrationDate, expirationDate, 1, 0 }
    )

    if newId then
        logVehicleHistory('vehicleRegistered', 'Vehicle Registered', 3447003, newId, plate, 'registered',
            translate('veh_history_registered', expirationDate), ctx)
    end

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

RegisterNetEvent('x1s-cad:server:updateVehicle', withCadAuth(function(src, ctx, data)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    if type(data) ~= 'table' then return end

    local vehicleId = tonumber(data.vehicleId)
    if not vehicleId then return end

    local existing = X1S.DB.SelectOne('SELECT id FROM x1s_vehicles WHERE id = ?', { vehicleId })
    if not existing then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_vehicle') })
        return
    end

    local plate = cleanString(data.plate, 16)
    local plateState = cleanString(data.plateState, Config.VehicleRegistration.plateStateMaxLength)
    local brand = cleanString(data.brand, 32)
    local vehType = cleanString(data.type, 64)
    local year = cleanYear(data.year)
    local model = cleanString(data.model, 64)
    local color = cleanString(data.color, 32) or ''
    local ownerId = tonumber(data.ownerId)
    if not plate or not model then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_vehicle') })
        return
    end

    local validRegistrations = { valid = true, expired = true, unregistered = true }
    local registration = validRegistrations[data.registration] and data.registration or 'valid'
    local registrationDate = cleanDate(data.registrationDate)
    local expirationDate = cleanDate(data.expirationDate)
    local insured = data.insured and 1 or 0

    local plateOwner = X1S.DB.SelectOne('SELECT id FROM x1s_vehicles WHERE plate = ? AND id != ?', { plate, vehicleId })
    if plateOwner then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_plate_taken') })
        return
    end

    X1S.DB.Mutate(
        [[UPDATE x1s_vehicles SET plate = ?, plate_state = ?, brand = ?, vehicle_type = ?, vehicle_year = ?, model = ?, color = ?,
          owner_id = ?, registration = ?, registration_date = ?, expiration_date = ?, insured = ? WHERE id = ?]],
        { plate, plateState, brand, vehType, year, model, color, ownerId, registration, registrationDate, expirationDate, insured, vehicleId }
    )

    local row = X1S.DB.SelectOne(
        [[SELECT v.*, c.first_name, c.last_name, c.state_id AS owner_state_id
          FROM x1s_vehicles v LEFT JOIN x1s_characters c ON c.id = v.owner_id
          WHERE v.id = ?]],
        { vehicleId }
    )
    X1S.DB.NormalizeRowDates(row, { 'created_at', 'updated_at', 'registration_date', 'expiration_date', 'retired_at' })

    TriggerClientEvent('x1s-cad:client:vehicleUpdated', src, row)
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

RegisterNetEvent('x1s-cad:server:setVehicleStolen', withCadAuth(function(src, ctx, vehicleId, stolen)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end

    local vehicle = X1S.DB.SelectOne('SELECT plate, brand, model FROM x1s_vehicles WHERE id = ?', { vehicleId })

    X1S.DB.Mutate('UPDATE x1s_vehicles SET stolen = ? WHERE id = ?', { stolen and 1 or 0, vehicleId })

    if vehicle then
        X1S.Log.Send('vehicleStolenToggled', stolen and 'Vehicle Marked Stolen' or 'Vehicle Stolen Status Cleared', stolen and 15158332 or 3066993, {
            { name = 'Plate', value = vehicle.plate, inline = true },
            { name = 'Vehicle', value = ('%s %s'):format(vehicle.brand or '', vehicle.model or ''), inline = true },
            { name = 'By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true }
        })
    end

    TriggerClientEvent('x1s-duty:client:notify', src, {
        type = stolen and 'warning' or 'success',
        title = translate('notification_system'),
        message = translate(stolen and 'cad_vehicle_marked_stolen' or 'cad_vehicle_cleared')
    })
end))

RegisterNetEvent('x1s-cad:server:setVehicleNotes', withCadAuth(function(src, ctx, vehicleId, notes)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    vehicleId = tonumber(vehicleId)
    notes = cleanString(notes, 2000) or ''
    if not vehicleId then return end

    X1S.DB.Mutate('UPDATE x1s_vehicles SET notes = ? WHERE id = ?', { notes, vehicleId })
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

local function pushVehicleUpdated(src, vehicleId)
    local row = X1S.DB.SelectOne(
        [[SELECT v.*, c.first_name, c.last_name, c.state_id AS owner_state_id
          FROM x1s_vehicles v LEFT JOIN x1s_characters c ON c.id = v.owner_id
          WHERE v.id = ?]],
        { vehicleId }
    )
    X1S.DB.NormalizeRowDates(row, { 'created_at', 'updated_at', 'registration_date', 'expiration_date', 'retired_at' })
    TriggerClientEvent('x1s-cad:client:vehicleUpdated', src, row)
    return row
end

RegisterNetEvent('x1s-cad:server:renewVehicleRegistration', withCadAuth(function(src, ctx, vehicleId, days)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    vehicleId = tonumber(vehicleId)
    days = tonumber(days)
    if not vehicleId or not days or days <= 0 or days > 3650 then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_vehicle') })
        return
    end

    local vehicle = X1S.DB.SelectOne('SELECT plate FROM x1s_vehicles WHERE id = ?', { vehicleId })
    if not vehicle then return end

    local today = os.date('!%Y-%m-%d')
    local expiration = os.date('!%Y-%m-%d', os.time() + (days * 86400))
    X1S.DB.Mutate(
        "UPDATE x1s_vehicles SET registration = 'valid', registration_date = ?, expiration_date = ? WHERE id = ?",
        { today, expiration, vehicleId }
    )

    logVehicleHistory('vehicleRegistrationRenewed', 'Vehicle Registration Renewed', 3447003, vehicleId, vehicle.plate,
        'renewed', translate('veh_history_renewed', expiration), ctx)

    pushVehicleUpdated(src, vehicleId)
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_vehicle_renewed') })
end))

RegisterNetEvent('x1s-cad:server:transferVehicleOwnership', withCadAuth(function(src, ctx, vehicleId, newOwnerId)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end

    local vehicle = X1S.DB.SelectOne(
        [[SELECT v.plate, v.owner_id, c.first_name, c.last_name FROM x1s_vehicles v
          LEFT JOIN x1s_characters c ON c.id = v.owner_id WHERE v.id = ?]],
        { vehicleId }
    )
    if not vehicle then return end

    newOwnerId = tonumber(newOwnerId)
    local newOwner = nil
    if newOwnerId then
        newOwner = X1S.DB.SelectOne('SELECT id, first_name, last_name FROM x1s_characters WHERE id = ? AND deleted_at IS NULL', { newOwnerId })
        if not newOwner then
            TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_owner') })
            return
        end
    end

    X1S.DB.Mutate('UPDATE x1s_vehicles SET owner_id = ? WHERE id = ?', { newOwner and newOwner.id or nil, vehicleId })

    local fromLabel = vehicle.first_name and ('%s %s'):format(vehicle.first_name, vehicle.last_name) or translate('cad_unowned')
    local toLabel = newOwner and ('%s %s'):format(newOwner.first_name, newOwner.last_name) or translate('cad_unowned')
    logVehicleHistory('vehicleOwnershipTransferred', 'Vehicle Ownership Transferred', 1752220, vehicleId, vehicle.plate,
        'transferred', translate('veh_history_transferred', fromLabel, toLabel), ctx)

    pushVehicleUpdated(src, vehicleId)
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_vehicle_transferred') })
end))

RegisterNetEvent('x1s-cad:server:setVehicleRetired', withCadAuth(function(src, ctx, vehicleId, retired)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end

    local vehicle = X1S.DB.SelectOne('SELECT plate FROM x1s_vehicles WHERE id = ?', { vehicleId })
    if not vehicle then return end

    X1S.DB.Mutate('UPDATE x1s_vehicles SET retired_at = ? WHERE id = ?', { retired and os.date('!%Y-%m-%d %H:%M:%S') or nil, vehicleId })

    logVehicleHistory('vehicleRetiredToggled', retired and 'Vehicle Retired' or 'Vehicle Reinstated', retired and 9871559 or 3066993,
        vehicleId, vehicle.plate, retired and 'retired' or 'reinstated',
        retired and translate('veh_history_retired') or translate('veh_history_reinstated'), ctx)

    pushVehicleUpdated(src, vehicleId)
    TriggerClientEvent('x1s-duty:client:notify', src, {
        type = retired and 'warning' or 'success',
        title = translate('notification_system'),
        message = translate(retired and 'cad_vehicle_retired' or 'cad_vehicle_reinstated')
    })
end))

RegisterNetEvent('x1s-cad:server:getVehicleHistory', withCadAuth(function(src, ctx, vehicleId)
    if cooldownGuard(src, 'cadSearch', ServerConfig.Cooldowns.cadSearch) then return end
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end

    local rows = X1S.DB.Select(
        'SELECT * FROM x1s_vehicle_history WHERE vehicle_id = ? ORDER BY created_at DESC LIMIT 100',
        { vehicleId }
    )
    X1S.DB.NormalizeRowsDates(rows, { 'created_at' })

    TriggerClientEvent('x1s-cad:client:vehicleHistory', src, { vehicleId = vehicleId, history = rows })
end))

RegisterNetEvent('x1s-cad:server:createWarrant', withCadAuth(function(src, ctx, data)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    if type(data) ~= 'table' then return end

    local characterId = tonumber(data.characterId)
    local reason = cleanString(data.reason, 255)
    local notes = cleanString(data.notes, 2000) or ''
    local signature = cleanString(data.signature, 64)
    if not characterId or not reason or not signature then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_warrant') })
        return
    end

    local citizen = X1S.DB.SelectOne('SELECT id, state_id, first_name, last_name FROM x1s_characters WHERE id = ? AND deleted_at IS NULL', { characterId })
    if not citizen then return end

    local sentCharges = type(data.charges) == 'table' and data.charges or {}
    local validCharges = {}
    for _, sent in ipairs(sentCharges) do
        if type(sent) == 'table' then
            for _, def in ipairs(Config.CAD.charges) do
                if def.code == sent.code then
                    validCharges[#validCharges + 1] = { code = def.code, label = def.label }
                    break
                end
            end
        end
    end

    local durationDays = tonumber(data.durationDays) or Config.CAD.warrantDefaultDurationDays
    durationDays = math.max(1, math.floor(durationDays))

    local isArmed = data.isArmed == true
    local isViolent = data.isViolent == true
    local isMentallyIll = data.isMentallyIll == true

    X1S.DB.Insert(
        [[INSERT INTO x1s_warrants (character_id, department, reason, charges, notes, status, issued_by, issued_by_id, signature, is_armed, is_violent, is_mentally_ill, expires_at)
          VALUES (?, ?, ?, ?, ?, 'active', ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))]],
        { characterId, ctx.department, reason, X1S.DB.EncodeJson(validCharges, true), notes, ctx.name, ctx.charId, signature,
          isArmed and 1 or 0, isViolent and 1 or 0, isMentallyIll and 1 or 0, durationDays }
    )

    X1S.Log.Send('warrantCreated', 'Warrant Created', 12597011, {
        { name = 'Subject', value = ('%s %s (%s)'):format(citizen.first_name, citizen.last_name, citizen.state_id), inline = true },
        { name = 'Issued By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Duration', value = ('%d days'):format(durationDays), inline = true },
        { name = 'Reason', value = reason, inline = false },
        { name = 'Flags', value = X1S.Log.FlagSummary(isArmed, isViolent, isMentallyIll), inline = true }
    })

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_warrant_created') })
end))

RegisterNetEvent('x1s-cad:server:closeWarrant', withCadAuth(function(src, ctx, warrantId)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    warrantId = tonumber(warrantId)
    if not warrantId then return end

    local warrant = X1S.DB.SelectOne(
        [[SELECT w.reason, c.state_id, c.first_name, c.last_name FROM x1s_warrants w
          JOIN x1s_characters c ON c.id = w.character_id WHERE w.id = ?]],
        { warrantId }
    )

    X1S.DB.Mutate("UPDATE x1s_warrants SET status = 'closed', closed_at = NOW() WHERE id = ?", { warrantId })

    if warrant then
        X1S.Log.Send('warrantClosed', 'Warrant Closed', 3066993, {
            { name = 'Subject', value = ('%s %s (%s)'):format(warrant.first_name, warrant.last_name, warrant.state_id), inline = true },
            { name = 'Closed By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
            { name = 'Original Reason', value = warrant.reason, inline = false }
        })
    end

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_warrant_closed') })
end))

RegisterNetEvent('x1s-cad:server:searchWarrants', withCadAuth(function(src, ctx, status)
    if cooldownGuard(src, 'cadSearch', ServerConfig.Cooldowns.cadSearch) then return end
    status = (status == 'closed') and 'closed' or 'active'

    local rows = X1S.DB.Select(
        [[SELECT w.*, c.first_name, c.last_name, c.state_id
          FROM x1s_warrants w JOIN x1s_characters c ON c.id = w.character_id
          WHERE w.status = ? ORDER BY w.created_at DESC LIMIT ?]],
        { status, Config.CAD.maxSearchResults }
    )
    X1S.DB.NormalizeRowsDates(rows, { 'created_at', 'expires_at', 'closed_at' })
    for _, w in ipairs(rows) do w.charges = X1S.DB.DecodeJson(w.charges, {}) end
    TriggerClientEvent('x1s-cad:client:searchResults', src, { type = 'warrant', results = rows })
end))

RegisterNetEvent('x1s-cad:server:createVehicleBolo', withCadAuth(function(src, ctx, data)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    if type(data) ~= 'table' then return end

    local plate = cleanString(data.plate, 16)
    local brand = cleanString(data.brand, 32)
    local vehType = cleanString(data.type, 64)
    local model = cleanString(data.model, 64)
    local color = cleanString(data.color, 32)
    local reason = cleanString(data.reason, 255)
    local notes = cleanString(data.notes, 2000) or ''
    local signature = cleanString(data.signature, 64)

    if not reason or not (plate or brand or vehType or model or color) or not signature then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_vehicle_bolo') })
        return
    end

    local priority = 'routine'
    for _, p in ipairs(Config.CAD.vehicleBoloPriorities or {}) do
        if p.key == data.priority then priority = p.key break end
    end

    local isArmed = data.isArmed == true
    local isViolent = data.isViolent == true
    local isMentallyIll = data.isMentallyIll == true

    X1S.DB.Insert(
        [[INSERT INTO x1s_vehicle_bolos (plate, brand, vehicle_type, model, color, reason, priority, is_armed, is_violent, is_mentally_ill, notes, status, issued_by, issued_by_id, signature, department)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?)]],
        { plate, brand, vehType, model, color, reason, priority, isArmed and 1 or 0, isViolent and 1 or 0, isMentallyIll and 1 or 0,
          notes, ctx.name, ctx.charId, signature, ctx.department }
    )

    X1S.Log.Send('vehicleBoloCreated', 'Vehicle BOLO Issued', 15105570, {
        { name = 'Vehicle', value = ('%s %s (%s) - plate %s'):format(brand or 'Unknown', model or '', color or 'unknown color', plate or 'unknown'), inline = false },
        { name = 'Priority', value = priority, inline = true },
        { name = 'Issued By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Reason', value = reason, inline = false },
        { name = 'Flags', value = X1S.Log.FlagSummary(isArmed, isViolent, isMentallyIll), inline = true }
    })

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_vehicle_bolo_created') })
end))

RegisterNetEvent('x1s-cad:server:closeVehicleBolo', withCadAuth(function(src, ctx, boloId)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    boloId = tonumber(boloId)
    if not boloId then return end

    local bolo = X1S.DB.SelectOne('SELECT plate, brand, model, reason FROM x1s_vehicle_bolos WHERE id = ?', { boloId })

    X1S.DB.Mutate("UPDATE x1s_vehicle_bolos SET status = 'closed', closed_at = NOW() WHERE id = ?", { boloId })

    if bolo then
        X1S.Log.Send('vehicleBoloClosed', 'Vehicle BOLO Closed', 3066993, {
            { name = 'Vehicle', value = ('%s %s (%s)'):format(bolo.brand or '', bolo.model or '', bolo.plate or 'no plate'), inline = true },
            { name = 'Closed By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
            { name = 'Original Reason', value = bolo.reason, inline = false }
        })
    end

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_vehicle_bolo_closed') })
end))

RegisterNetEvent('x1s-cad:server:searchVehicleBolos', withCadAuth(function(src, ctx, status)
    if cooldownGuard(src, 'cadSearch', ServerConfig.Cooldowns.cadSearch) then return end
    status = (status == 'closed') and 'closed' or 'active'

    local rows = X1S.DB.Select(
        'SELECT * FROM x1s_vehicle_bolos WHERE status = ? ORDER BY created_at DESC LIMIT ?',
        { status, Config.CAD.maxSearchResults }
    )
    X1S.DB.NormalizeRowsDates(rows, { 'created_at', 'closed_at' })
    TriggerClientEvent('x1s-cad:client:searchResults', src, { type = 'vehicleBolo', results = rows })
end))

RegisterNetEvent('x1s-cad:server:createArrest', withCadAuth(function(src, ctx, data)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    if type(data) ~= 'table' then return end

    local characterId = tonumber(data.characterId)
    local charges = type(data.charges) == 'table' and data.charges or {}
    local notes = cleanString(data.notes, 2000) or ''
    local signature = cleanString(data.signature, 64)
    if not characterId or #charges == 0 or not signature then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_arrest') })
        return
    end

    local citizen = X1S.DB.SelectOne('SELECT id, state_id, first_name, last_name FROM x1s_characters WHERE id = ? AND deleted_at IS NULL', { characterId })
    if not citizen then return end

    local validCharges, fineTotal, jailTotal = {}, 0, 0
    for _, sent in ipairs(charges) do
        if type(sent) == 'table' then
            for _, def in ipairs(Config.CAD.charges) do
                if def.code == sent.code then
                    local fine = tonumber(sent.fine)
                    local jailMinutes = tonumber(sent.jailMinutes)
                    fine = fine and math.floor(fine) or def.fine
                    jailMinutes = jailMinutes and math.floor(jailMinutes) or def.jailMinutes
                    fine = math.max(0, math.min(fine, Config.CAD.arrestChargeMaxFine))
                    jailMinutes = math.max(0, math.min(jailMinutes, Config.CAD.arrestChargeMaxJailMinutes))

                    validCharges[#validCharges + 1] = { code = def.code, label = def.label, fine = fine, jailMinutes = jailMinutes }
                    fineTotal = fineTotal + fine
                    jailTotal = jailTotal + jailMinutes
                    break
                end
            end
        end
    end
    if #validCharges == 0 then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_arrest') })
        return
    end

    local assisting = {}
    if type(data.assisting) == 'string' then
        assisting = { cleanString(data.assisting, 128) }
    end

    X1S.DB.Insert(
        [[INSERT INTO x1s_arrests (character_id, officer_name, officer_id, department, charges, fine_total, jail_minutes, notes, assisting, signature)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { characterId, ctx.name, ctx.charId, ctx.department, X1S.DB.EncodeJson(validCharges, true), fineTotal, jailTotal, notes, X1S.DB.EncodeJson(assisting, true), signature }
    )

    local chargeList = {}
    for _, c in ipairs(validCharges) do chargeList[#chargeList + 1] = c.label end
    X1S.Log.Send('arrestMade', 'Arrest Made', 15158332, {
        { name = 'Suspect', value = ('%s %s (%s)'):format(citizen.first_name, citizen.last_name, citizen.state_id), inline = true },
        { name = 'Officer', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Charges', value = table.concat(chargeList, ', '), inline = false },
        { name = 'Fine Total', value = ('$%d'):format(fineTotal), inline = true },
        { name = 'Jail Time', value = ('%d min'):format(jailTotal), inline = true }
    })

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_arrest_filed') })
end))

RegisterNetEvent('x1s-cad:server:createCitation', withCadAuth(function(src, ctx, data)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    if type(data) ~= 'table' then return end

    local characterId = tonumber(data.characterId)
    local notes = cleanString(data.notes, 2000) or ''
    local signature = cleanString(data.signature, 64)
    local sentViolations = type(data.violations) == 'table' and data.violations or {}
    if not characterId or #sentViolations == 0 or not signature then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_citation') })
        return
    end

    local citizen = X1S.DB.SelectOne('SELECT id, state_id, first_name, last_name FROM x1s_characters WHERE id = ? AND deleted_at IS NULL', { characterId })
    if not citizen then return end

    local validViolations, fineTotal = {}, 0
    for _, sent in ipairs(sentViolations) do
        if type(sent) == 'table' then
            local matched = nil
            if sent.code then
                for _, def in ipairs(Config.CAD.charges) do
                    if def.code == sent.code and def.citable then matched = def break end
                end
            end

            local code = matched and matched.code or nil
            local label = matched and matched.label or cleanString(sent.label, 128)
            local fine = tonumber(sent.fine)
            fine = fine and math.floor(fine) or (matched and matched.fine or 0)
            fine = math.max(0, math.min(fine, Config.CAD.citationLineMaxFine))

            if label then
                validViolations[#validViolations + 1] = { code = code, label = label, fine = fine }
                fineTotal = fineTotal + fine
            end
        end
    end
    if #validViolations == 0 then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_citation') })
        return
    end

    X1S.DB.Insert(
        [[INSERT INTO x1s_citations (character_id, officer_name, officer_id, department, violations, fine_total, signature, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
        { characterId, ctx.name, ctx.charId, ctx.department, X1S.DB.EncodeJson(validViolations, true), fineTotal, signature, notes }
    )

    local violationList = {}
    for _, v in ipairs(validViolations) do violationList[#violationList + 1] = v.label end
    X1S.Log.Send('citationIssued', 'Citation Issued', 15105570, {
        { name = 'Citizen', value = ('%s %s (%s)'):format(citizen.first_name, citizen.last_name, citizen.state_id), inline = true },
        { name = 'Officer', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Violations', value = table.concat(violationList, ', '), inline = false },
        { name = 'Fine Total', value = ('$%d'):format(fineTotal), inline = true }
    })

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_citation_filed') })
end))

local function makeCaseNumber()
    return ('CR-%s-%04d'):format(os.date('%Y%m%d'), math.random(0, 9999))
end

RegisterNetEvent('x1s-cad:server:createIncident', withCadAuth(function(src, ctx, data)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    if type(data) ~= 'table' then return end

    local title = cleanString(data.title, 128)
    local narrative = cleanString(data.narrative, 4000)
    if not title or not narrative then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_invalid_incident') })
        return
    end

    local officers = type(data.officers) == 'table' and data.officers or { ctx.name }
    local civilians = type(data.civilians) == 'table' and data.civilians or {}
    local evidence = cleanString(data.evidence, 2000) or ''
    local signingOfficer = cleanString(data.signingOfficer, 64)

    local caseNumber = makeCaseNumber()
    local newId = X1S.DB.Insert(
        [[INSERT INTO x1s_incidents (case_number, title, department, officers, civilians, narrative, evidence, signing_officer, status, created_by)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'open', ?)]],
        { caseNumber, title, ctx.department, X1S.DB.EncodeJson(officers, true), X1S.DB.EncodeJson(civilians, true), narrative, evidence, signingOfficer, ctx.name }
    )

    if not newId then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_save_failed') })
        return
    end

    X1S.Log.Send('incidentCreated', 'Incident Report Filed', 13853696, {
        { name = 'Case Number', value = caseNumber, inline = true },
        { name = 'Title', value = title, inline = true },
        { name = 'Filed By', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Officers', value = table.concat(officers, ', '), inline = false }
    })

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_incident_filed', caseNumber) })
end))

RegisterNetEvent('x1s-cad:server:updateIncident', withCadAuth(function(src, ctx, incidentId, data)
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    incidentId = tonumber(incidentId)
    if not incidentId or type(data) ~= 'table' then return end

    local status = (data.status == 'closed') and 'closed' or 'open'
    local narrative = cleanString(data.narrative, 4000)
    local evidence = cleanString(data.evidence, 2000)
    local signingOfficer = cleanString(data.signingOfficer, 64)

    local sets, params = { 'status = ?' }, { status }
    if narrative then sets[#sets + 1] = 'narrative = ?'; params[#params + 1] = narrative end
    if evidence then sets[#sets + 1] = 'evidence = ?'; params[#params + 1] = evidence end
    if signingOfficer then sets[#sets + 1] = 'signing_officer = ?'; params[#params + 1] = signingOfficer end
    params[#params + 1] = incidentId

    X1S.DB.Mutate(('UPDATE x1s_incidents SET %s WHERE id = ?'):format(table.concat(sets, ', ')), params)
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

RegisterNetEvent('x1s-cad:server:searchIncidents', withCadAuth(function(src, ctx, query)
    if cooldownGuard(src, 'cadSearch', ServerConfig.Cooldowns.cadSearch) then return end
    query = cleanString(query, 64)

    local rows
    if query then
        rows = X1S.DB.Select(
            'SELECT * FROM x1s_incidents WHERE title LIKE ? OR case_number LIKE ? ORDER BY created_at DESC LIMIT ?',
            { '%' .. query .. '%', '%' .. query .. '%', Config.CAD.maxSearchResults }
        )
    else
        rows = X1S.DB.Select('SELECT * FROM x1s_incidents ORDER BY created_at DESC LIMIT ?', { Config.CAD.maxSearchResults })
    end

    for _, row in ipairs(rows) do
        row.officers = X1S.DB.DecodeJson(row.officers, {})
        row.civilians = X1S.DB.DecodeJson(row.civilians, {})
    end
    X1S.DB.NormalizeRowsDates(rows, { 'created_at', 'updated_at' })

    TriggerClientEvent('x1s-cad:client:searchResults', src, { type = 'incident', results = rows })
end))

RegisterNetEvent('x1s-cad:server:requestDispatchState', withCadAuth(function(src, ctx)
    TriggerClientEvent('x1s-cad:client:dispatchState', src, X1S.Server.GetActive911CallsList())
end))

RegisterNetEvent('x1s-cad:server:requestPanicState', withCadAuth(function(src, ctx)
    TriggerClientEvent('x1s-cad:client:panicState', src, {
        alerts = X1S.Server.GetActivePanicAlertsList(),
        isSupervisor = X1S.Server.IsSupervisor(src)
    })
end))

RegisterNetEvent('x1s-cad:server:acceptCall', withCadAuth(function(src, ctx, alertId)
    if type(alertId) ~= 'string' then return end
    local call = State.Active911Calls[alertId]
    if not call then return end

    call.status = 'active'
    call.acceptedBy = ('%s [%s]'):format(ctx.name, ctx.callsign)

    call.responders = call.responders or {}
    local alreadyResponding = false
    for _, responder in ipairs(call.responders) do
        if responder.src == src then alreadyResponding = true break end
    end
    if not alreadyResponding then
        call.responders[#call.responders + 1] = { src = src, name = call.acceptedBy }
    end

    X1S.Server.BroadcastToDuty('x1s-cad:client:callUpdated', call)

    TriggerClientEvent('x1s-cad:client:callAccepted', src, call)
end))

RegisterNetEvent('x1s-cad:server:leaveCall', withCadAuth(function(src, ctx, alertId)
    if type(alertId) ~= 'string' then return end
    local call = State.Active911Calls[alertId]
    if not call then return end

    local responders = call.responders or {}
    local index = nil
    for i, responder in ipairs(responders) do
        if responder.src == src then index = i break end
    end
    if not index then return end
    table.remove(responders, index)
    call.responders = responders

    if #responders == 0 then
        call.status = 'pending'
        call.acceptedBy = nil
    end

    X1S.Server.BroadcastToDuty('x1s-cad:client:callUpdated', call)
    TriggerClientEvent('x1s-cad:client:callLeft', src, { alertId = alertId })
end))

RegisterNetEvent('x1s-cad:server:completeCall', withCadAuth(function(src, ctx, alertId)
    if type(alertId) ~= 'string' then return end
    if not State.Active911Calls[alertId] then return end

    State.Active911Calls[alertId] = nil
    X1S.Server.BroadcastToDuty('x1s-cad:client:callCleared', { alertId = alertId })
end))

local function requireAdmin(src)
    if X1S.Server.IsAdmin(src) then return true end
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_admin_denied') })
    return false
end

local RECORD_TYPES = {
    arrest = {
        table = 'x1s_arrests',
        lookup = [[SELECT a.*, c.state_id, c.first_name, c.last_name FROM x1s_arrests a
                   JOIN x1s_characters c ON c.id = a.character_id WHERE a.id = ?]],
        label = 'Arrest',
        summarize = function(row)
            local labels = {}
            for _, ch in ipairs(X1S.DB.DecodeJson(row.charges, {})) do labels[#labels + 1] = ch.label end
            return #labels > 0 and table.concat(labels, ', ') or ('$%d fine / %dm jail'):format(row.fine_total or 0, row.jail_minutes or 0)
        end,
        filedBy = function(row) return row.officer_name end
    },
    citation = {
        table = 'x1s_citations',
        lookup = [[SELECT ct.*, c.state_id, c.first_name, c.last_name FROM x1s_citations ct
                   JOIN x1s_characters c ON c.id = ct.character_id WHERE ct.id = ?]],
        label = 'Citation',
        summarize = function(row)
            local labels = {}
            for _, v in ipairs(X1S.DB.DecodeJson(row.violations, {})) do labels[#labels + 1] = v.label end
            return #labels > 0 and table.concat(labels, ', ') or (row.violation or ('$%d fine'):format(row.fine_total or row.fine or 0))
        end,
        filedBy = function(row) return row.officer_name end
    },
    warrant = {
        table = 'x1s_warrants',
        lookup = [[SELECT w.*, c.state_id, c.first_name, c.last_name FROM x1s_warrants w
                   JOIN x1s_characters c ON c.id = w.character_id WHERE w.id = ?]],
        label = 'Warrant',
        summarize = function(row) return row.reason end,
        filedBy = function(row) return row.issued_by end
    },
    incident = {
        table = 'x1s_incidents',
        lookup = 'SELECT * FROM x1s_incidents WHERE id = ?',
        label = 'Incident',
        summarize = function(row) return ('%s (%s)'):format(row.title, row.case_number) end,
        filedBy = function(row) return row.created_by end
    },
    vehicleBolo = {
        table = 'x1s_vehicle_bolos',
        lookup = 'SELECT * FROM x1s_vehicle_bolos WHERE id = ?',
        label = 'Vehicle BOLO',
        summarize = function(row) return row.reason end,
        filedBy = function(row) return row.issued_by end
    },
    vehicle = {
        table = 'x1s_vehicles',
        lookup = [[SELECT v.*, c.first_name, c.last_name, c.state_id FROM x1s_vehicles v
                   LEFT JOIN x1s_characters c ON c.id = v.owner_id WHERE v.id = ?]],
        label = 'Vehicle',
        summarize = function(row) return ('%s %s (%s)'):format(row.brand or '', row.model or '', row.plate or '') end,
        filedBy = function(row) return nil end
    }
}

local function recordSubject(recordType, row)
    if row.first_name and row.last_name then
        return ('%s %s (%s)'):format(row.first_name, row.last_name, row.state_id)
    end
    if recordType == 'incident' then return row.case_number end
    if recordType == 'vehicleBolo' or recordType == 'vehicle' then return row.plate or translate('cad_no_plate') end
    return ('#%d'):format(row.id)
end

RegisterNetEvent('x1s-cad:server:adminDeleteRecord', withCadAuth(function(src, ctx, data)
    if not requireAdmin(src) then return end
    if type(data) ~= 'table' then return end

    local def = RECORD_TYPES[data.type]
    local id = tonumber(data.id)
    if not def or not id then return end

    local row = def.lookup and X1S.DB.SelectOne(def.lookup, { id })
    if not row then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_save_failed') })
        return
    end

    X1S.DB.Mutate(('DELETE FROM %s WHERE id = ?'):format(def.table), { id })

    X1S.Log.Send('cadRecordDeleted', ('%s Removed (Admin)'):format(def.label), 15158332, {
        { name = 'Subject', value = recordSubject(data.type, row), inline = true },
        { name = 'Originally Filed By', value = def.filedBy(row) or 'Unknown', inline = true },
        { name = 'Removed By (Admin)', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Details', value = (def.summarize(row) or ''):sub(1, 500), inline = false },
        { name = 'Record ID', value = ('#%d'):format(id), inline = true }
    })

    local characterId = tonumber(data.characterId)
    if characterId then
        sendCitizenProfile(src, characterId)
    end

    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_record_removed') })
end))

local function broadcastReferenceData()
    X1S.Server.BroadcastToDuty('x1s-cad:client:referenceData', {
        tenCodes = loadTenCodes(),
        penalCodes = loadPenalCodes()
    })
end

RegisterNetEvent('x1s-cad:server:adminSaveTenCode', withCadAuth(function(src, ctx, data)
    if not requireAdmin(src) then return end
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    if type(data) ~= 'table' then return end

    local id = tonumber(data.id)
    local code = cleanString(data.code, 16)
    local label = cleanString(data.label, 128)
    if not code or not label then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_admin_invalid_tencode') })
        return
    end

    local dupe = X1S.DB.SelectOne('SELECT id FROM x1s_ten_codes WHERE code = ? AND id != ?', { code, id or 0 })
    if dupe then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_admin_duplicate_code') })
        return
    end

    if id then
        X1S.DB.Mutate('UPDATE x1s_ten_codes SET code = ?, label = ? WHERE id = ?', { code, label, id })
    else
        local maxOrder = X1S.DB.SelectOne('SELECT COALESCE(MAX(sort_order), 0) AS m FROM x1s_ten_codes')
        X1S.DB.Insert('INSERT INTO x1s_ten_codes (code, label, sort_order) VALUES (?, ?, ?)', { code, label, (maxOrder and tonumber(maxOrder.m) or 0) + 1 })
    end

    X1S.Log.Send('cadReferenceDataChanged', '10-Code Saved', 3901635, {
        { name = 'Admin', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Code', value = code, inline = true },
        { name = 'Label', value = label, inline = true }
    })

    broadcastReferenceData()
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

RegisterNetEvent('x1s-cad:server:adminDeleteTenCode', withCadAuth(function(src, ctx, data)
    if not requireAdmin(src) then return end
    local id = type(data) == 'table' and tonumber(data.id) or nil
    if not id then return end

    local existing = X1S.DB.SelectOne('SELECT code FROM x1s_ten_codes WHERE id = ?', { id })
    X1S.DB.Mutate('DELETE FROM x1s_ten_codes WHERE id = ?', { id })

    X1S.Log.Send('cadReferenceDataChanged', '10-Code Deleted', 15105570, {
        { name = 'Admin', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Code', value = existing and existing.code or ('#' .. id), inline = true }
    })

    broadcastReferenceData()
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

RegisterNetEvent('x1s-cad:server:adminSavePenalCode', withCadAuth(function(src, ctx, data)
    if not requireAdmin(src) then return end
    if cooldownGuard(src, 'cadWrite', ServerConfig.Cooldowns.cadWrite) then return end
    if type(data) ~= 'table' then return end

    local id = tonumber(data.id)
    local code = cleanString(data.code, 32)
    local title = cleanString(data.title, 128)
    local pcType = PENAL_CODE_TYPES[data.type] and data.type or 'Misdemeanor'
    local bondType = cleanString(data.bondType, 32) or 'Personal Recognizance'
    local bondAmount = math.max(0, math.floor(tonumber(data.bondAmount) or 0))
    local jailTime = cleanString(data.jailTime, 64) or ''

    if not code or not title then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_admin_invalid_penalcode') })
        return
    end

    local dupe = X1S.DB.SelectOne('SELECT id FROM x1s_penal_codes WHERE code = ? AND id != ?', { code, id or 0 })
    if dupe then
        TriggerClientEvent('x1s-duty:client:notify', src, { type = 'error', title = translate('notification_system'), message = translate('cad_admin_duplicate_code') })
        return
    end

    if id then
        X1S.DB.Mutate(
            'UPDATE x1s_penal_codes SET code = ?, title = ?, type = ?, bond_type = ?, bond_amount = ?, jail_time = ? WHERE id = ?',
            { code, title, pcType, bondType, bondAmount, jailTime, id }
        )
    else
        local maxOrder = X1S.DB.SelectOne('SELECT COALESCE(MAX(sort_order), 0) AS m FROM x1s_penal_codes')
        X1S.DB.Insert(
            'INSERT INTO x1s_penal_codes (code, title, type, bond_type, bond_amount, jail_time, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { code, title, pcType, bondType, bondAmount, jailTime, (maxOrder and tonumber(maxOrder.m) or 0) + 1 }
        )
    end

    X1S.Log.Send('cadReferenceDataChanged', 'Penal Code Saved', 3901635, {
        { name = 'Admin', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Code', value = code, inline = true },
        { name = 'Title', value = title, inline = true }
    })

    broadcastReferenceData()
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))

RegisterNetEvent('x1s-cad:server:adminDeletePenalCode', withCadAuth(function(src, ctx, data)
    if not requireAdmin(src) then return end
    local id = type(data) == 'table' and tonumber(data.id) or nil
    if not id then return end

    local existing = X1S.DB.SelectOne('SELECT code FROM x1s_penal_codes WHERE id = ?', { id })
    X1S.DB.Mutate('DELETE FROM x1s_penal_codes WHERE id = ?', { id })

    X1S.Log.Send('cadReferenceDataChanged', 'Penal Code Deleted', 15105570, {
        { name = 'Admin', value = ('%s (%s)'):format(ctx.name, ctx.department), inline = true },
        { name = 'Code', value = existing and existing.code or ('#' .. id), inline = true }
    })

    broadcastReferenceData()
    TriggerClientEvent('x1s-duty:client:notify', src, { type = 'success', title = translate('notification_system'), message = translate('cad_saved') })
end))
