local function isPlaceholder(value)
    return type(value) ~= 'string' or value == '' or value:find('_HERE', 1, true) ~= nil
end

X1S.Log = X1S.Log or {}

function X1S.Log.Send(key, title, color, fields)
    local webhook = ServerConfig.LogWebhooks and ServerConfig.LogWebhooks[key]
    if isPlaceholder(webhook) then return end

    PerformHttpRequest(
        webhook,
        function(statusCode)
            local code = tonumber(statusCode) or 0
            if code < 200 or code >= 300 then
                print(('^1[X1S][Log:%s] webhook failed with HTTP %s.^0'):format(key, tostring(statusCode)))
            end
        end,
        'POST',
        json.encode({
            username = 'X1S Activity Log',
            embeds = {{
                title = title,
                color = color,
                fields = fields,
                footer = { text = 'X1Studios Activity Log', icon_url = ServerConfig.FooterIcon },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
            }}
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

function X1S.Log.PlayerIdentity(src)
    local name = GetPlayerName(src) or 'Unknown'
    local discord = nil
    for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
        if identifier:sub(1, 8) == 'discord:' then discord = identifier:sub(9) end
    end
    return name, discord
end

function X1S.Log.FlagSummary(armed, violent, mentallyIll)
    local parts = {}
    if armed then parts[#parts + 1] = 'Armed' end
    if violent then parts[#parts + 1] = 'Violent' end
    if mentallyIll then parts[#parts + 1] = 'Mentally Ill' end
    if #parts == 0 then return 'None' end
    return table.concat(parts, ', ')
end
