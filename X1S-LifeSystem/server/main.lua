CreateThread(function()
    if GetResourceState('oxmysql') ~= 'started' then
        print('^1[X1S] oxmysql is not running. This resource requires it for character/CAD persistence - add `ensure oxmysql` above this resource in server.cfg and configure its connection string.^0')
        return
    end

    local ok = pcall(function()
        MySQL.query.await('SELECT 1')
    end)

    if not ok then
        print('^1[X1S] Could not reach the database via oxmysql. Check your oxmysql connection string / mysql_connection_string convar.^0')
    else
        print('^2[X1S] Database connection OK.^0')
    end
end)

local resourceName = GetCurrentResourceName()
local currentVersion = GetResourceMetadata(resourceName, 'version', 0)

local versionUrl = "https://raw.githubusercontent.com/X1Studios-FiveM-Development/X1Studios-Life-System/main/version.txt"

local function CheckForUpdates()
    PerformHttpRequest(versionUrl, function(statusCode, responseText, headers)
        if statusCode ~= 200 then
            print("^1[Update Checker] Unable to check for updates (HTTP Error " .. statusCode .. ")^0")
            return
        end

        local latestVersion = responseText:gsub("%s+", "")

        if latestVersion == currentVersion then
            print("^2[Update Checker] " .. resourceName .. " is up to date! (v" .. currentVersion .. ")^0")
        else
            print("^3-------------------------------------------------------^0")
            print("^1[Update Checker] Update Available for " .. resourceName .. "!^0")
            print("^3Current Version:^0 " .. currentVersion)
            print("^2Latest Version:^0 " .. latestVersion)
            print("^5Download:^0 https://github.com/X1Studios-FiveM-Development/X1Studios-Life-System")
            print("^3-------------------------------------------------------^0")
        end
    end, "GET")
end

CreateThread(function()
    Wait(3000)
    CheckForUpdates()
end)
