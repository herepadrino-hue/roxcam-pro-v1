local Framework = nil
local Cameras = {}
local CameraIdCounter = 1
local CameraAlerts = {}
local BrokenCameras = {}

if Config.Framework == 'esx' then
    Framework = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    Framework = exports['qb-core']:GetCoreObject()
end

local function IsPolice(source)
    if Config.Framework == 'standalone' then
        return true
    elseif Config.Framework == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        if xPlayer then
            for _, job in ipairs(Config.PoliceJobs) do
                if xPlayer.job.name == job then
                    return true
                end
            end
        end
    elseif Config.Framework == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        if Player then
            for _, job in ipairs(Config.PoliceJobs) do
                if Player.PlayerData.job.name == job then
                    return true
                end
            end
        end
    end
    return false
end

local function CanViewCameras(source)
    if Config.Framework == 'standalone' then
        return true
    elseif Config.Framework == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        if xPlayer and xPlayer.job then
            local jobName = xPlayer.job.name
            local jobGrade = xPlayer.job.grade
            if Config.ViewCamerasGrades[jobName] then
                for _, allowedGrade in ipairs(Config.ViewCamerasGrades[jobName]) do
                    if jobGrade == allowedGrade then
                        return true
                    end
                end
            end
        end
    elseif Config.Framework == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        if Player and Player.PlayerData.job then
            local jobName = Player.PlayerData.job.name
            local jobGrade = Player.PlayerData.job.grade.level
            if Config.ViewCamerasGrades[jobName] then
                for _, allowedGrade in ipairs(Config.ViewCamerasGrades[jobName]) do
                    if jobGrade == allowedGrade then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function CanManageCameras(source)
    if Config.Framework == 'standalone' then
        return true
    elseif Config.Framework == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        if xPlayer and xPlayer.job then
            local jobName = xPlayer.job.name
            local jobGrade = xPlayer.job.grade
            if Config.ManageCamerasGrades[jobName] then
                for _, allowedGrade in ipairs(Config.ManageCamerasGrades[jobName]) do
                    if jobGrade == allowedGrade then
                        return true
                    end
                end
            end
        end
    elseif Config.Framework == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        if Player and Player.PlayerData.job then
            local jobName = Player.PlayerData.job.name
            local jobGrade = Player.PlayerData.job.grade.level
            if Config.ManageCamerasGrades[jobName] then
                for _, allowedGrade in ipairs(Config.ManageCamerasGrades[jobName]) do
                    if jobGrade == allowedGrade then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function LoadCamerasFromDB()
    if Config.Framework == 'standalone' then
        return
    end

    MySQL.Async.fetchAll('SELECT * FROM lspd_cameras', {}, function(result)
        if result and #result > 0 then
            for _, cam in ipairs(result) do
                Cameras[cam.id] = {
                    id = cam.id,
                    label = cam.label,
                    coords = json.decode(cam.coords),
                    rotation = json.decode(cam.rotation),
                    postal = cam.postal or "0000",
                    location = cam.location or "Unknown Location",
                    notes = cam.notes or "",
                    createdBy = cam.createdBy or "System",
                    createdAt = cam.createdAt or "Unknown"
                }
                CameraAlerts[cam.id] = {
                    status = "normal",
                    alertType = nil,
                    alertTime = 0
                }
                if cam.id >= CameraIdCounter then
                    CameraIdCounter = cam.id + 1
                end
            end
        end
    end)
end

local function SaveCameraToDB(camera)
    if Config.Framework == 'standalone' then
        return
    end

    MySQL.Async.execute(
        'INSERT INTO lspd_cameras (id, label, coords, rotation, postal, location, notes, createdBy, createdAt, screenshot) VALUES (@id, @label, @coords, @rotation, @postal, @location, @notes, @createdBy, @createdAt, @screenshot)',
        {
            ['@id'] = camera.id,
            ['@label'] = camera.label,
            ['@coords'] = json.encode(camera.coords),
            ['@rotation'] = json.encode(camera.rotation),
            ['@postal'] = camera.postal,
            ['@location'] = camera.location,
            ['@notes'] = camera.notes or "",
            ['@createdBy'] = camera.createdBy or "System",
            ['@createdAt'] = camera.createdAt or os.date("%Y-%m-%d %H:%M:%S"),
            ['@screenshot'] = camera.screenshot or ""
        }
    )
end

local function UpdateCameraInDB(camera)
    if Config.Framework == 'standalone' then
        return
    end

    MySQL.Async.execute(
        'UPDATE lspd_cameras SET label = @label, coords = @coords, rotation = @rotation, postal = @postal, location = @location, notes = @notes WHERE id = @id',
        {
            ['@id'] = camera.id,
            ['@label'] = camera.label,
            ['@coords'] = json.encode(camera.coords),
            ['@rotation'] = json.encode(camera.rotation),
            ['@postal'] = camera.postal,
            ['@location'] = camera.location,
            ['@notes'] = camera.notes or ""
        }
    )
end

local function DeleteCameraFromDB(id)
    if Config.Framework == 'standalone' then
        return
    end

    MySQL.Async.execute('DELETE FROM lspd_cameras WHERE id = @id', {
        ['@id'] = id
    })
end

local function GetNearestPostal(coords)
    local nearestPostal = "0000"
    local nearestDist = 999999.0

    for _, postal in ipairs(Config.PostalCodes) do
        local dist = #(vector3(coords.x, coords.y, coords.z) - postal.coords)
        if dist < nearestDist then
            nearestDist = dist
            nearestPostal = postal.code
        end
    end

    return nearestPostal
end

local function GetZoneName(coords)
    return "Unknown Location"
end

RegisterCommand(Config.PlacementCommand, function(source, args, rawCommand)
    if not CanManageCameras(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            multiline = true,
            args = { "Law System", "You don't have permission to place cameras." }
        })
        return
    end

    TriggerClientEvent('lspd_cameras:requestCameraName', source)
end, false)

RegisterNetEvent('lspd_cameras:saveCamera', function(cameraData)
    local source = source

    if not CanManageCameras(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "Law System", "You don't have permission to manage cameras." }
        })
        return
    end

    local cameraCount = 0
    for _ in pairs(Cameras) do
        cameraCount = cameraCount + 1
    end

    if cameraCount >= Config.MaxCameras then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "Law System", "Maximum camera limit reached!" }
        })
        return
    end

    local postal = GetNearestPostal(cameraData.coords)

    local camera = {
        id = CameraIdCounter,
        label = cameraData.label,
        coords = cameraData.coords,
        rotation = cameraData.rotation,
        postal = postal,
        location = cameraData.location or cameraData.label,
        notes = cameraData.notes or "",
        createdBy = cameraData.createdBy or "System",
        createdAt = os.date("%Y-%m-%d %H:%M:%S"),
        screenshot = cameraData.screenshot or ""
    }

    Cameras[CameraIdCounter] = camera
    CameraAlerts[CameraIdCounter] = {
        status = "normal",
        alertType = nil,
        alertTime = 0,
        broken = false
    }
    CameraIdCounter = CameraIdCounter + 1

    SaveCameraToDB(camera)

    local canManageList = {}
    for playerId = 0, GetNumPlayerIndices() - 1 do
        local playerSource = GetPlayerFromIndex(playerId)
        if playerSource then
            canManageList[playerSource] = CanManageCameras(playerSource)
        end
    end
    
    for playerId = 0, GetNumPlayerIndices() - 1 do
        local playerSource = GetPlayerFromIndex(playerId)
        if playerSource and CanViewCameras(playerSource) then
            TriggerClientEvent('lspd_cameras:updateCameras', playerSource, Cameras, CameraAlerts, canManageList[playerSource])
        end
    end

    TriggerClientEvent('chat:addMessage', source, {
        color = { 0, 255, 0 },
        args = { "Law System", "Camera placed successfully! ID: " .. camera.id }
    })
end)

RegisterNetEvent('lspd_cameras:updateCameraSettings', function(cameraId, newLabel, newLocation, newNotes)
    local source = source

    if not CanManageCameras(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "Law System", "You don't have permission to manage cameras." }
        })
        return
    end

    if Cameras[cameraId] then
        Cameras[cameraId].label = newLabel
        Cameras[cameraId].location = newLocation or newLabel
        Cameras[cameraId].notes = newNotes or ""
        
        UpdateCameraInDB(Cameras[cameraId])
        TriggerClientEvent('lspd_cameras:updateCameras', -1, Cameras, CameraAlerts)
        
        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "Law System", "Camera settings updated successfully!" }
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "Law System", "Camera not found!" }
        })
    end
end)

RegisterNetEvent('lspd_cameras:renameCamera', function(cameraId, newLabel)
    local source = source

    if not CanManageCameras(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "LSPD", "You don't have permission to manage cameras." }
        })
        return
    end

    if Cameras[cameraId] then
        Cameras[cameraId].label = newLabel
        Cameras[cameraId].location = newLabel
        UpdateCameraInDB(Cameras[cameraId])
        TriggerClientEvent('lspd_cameras:updateCameras', -1, Cameras, CameraAlerts)
        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "LSPD", "Camera renamed successfully!" }
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "LSPD", "Camera not found!" }
        })
    end
end)

RegisterNetEvent('lspd_cameras:deleteCamera', function(cameraId)
    local source = source

    if not CanManageCameras(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "LSPD", "You don't have permission to manage cameras." }
        })
        return
    end

    if Cameras[cameraId] then
        DeleteCameraFromDB(cameraId)
        
        Cameras[cameraId] = nil
        CameraAlerts[cameraId] = nil
        
        local cleanCameras = {}
        local cleanAlerts = {}
        
        for id, cam in pairs(Cameras) do
            if cam ~= nil then
                cleanCameras[id] = cam
                cleanAlerts[id] = CameraAlerts[id] or { status = "normal", alertType = nil }
            end
        end
        
        Cameras = cleanCameras
        CameraAlerts = cleanAlerts
        
        for playerId = 0, GetNumPlayerIndices() - 1 do
            local playerSource = GetPlayerFromIndex(playerId)
            if playerSource and CanViewCameras(playerSource) then
                local canManage = CanManageCameras(playerSource)
                TriggerClientEvent('lspd_cameras:updateCameras', playerSource, Cameras, CameraAlerts, canManage)
                TriggerClientEvent('lspd_cameras:removeCamera', playerSource, cameraId)
            end
        end

        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "LSPD", "Camera deleted successfully!" }
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "LSPD", "Camera not found!" }
        })
    end
end)

RegisterNetEvent('lspd_cameras:triggerAlert', function(cameraId, alertType)
    if not Cameras[cameraId] then return end

    if not CameraAlerts[cameraId] then
        CameraAlerts[cameraId] = {}
    end

    CameraAlerts[cameraId] = {
        status = "warning",
        alertType = alertType,
        alertTime = os.time()
    }

    TriggerClientEvent('lspd_cameras:alertUpdate', -1, cameraId, CameraAlerts[cameraId])

    local alertDuration = Config.AlertSystem.alerts[alertType].duration or 30000
    SetTimeout(alertDuration, function()
        if CameraAlerts[cameraId] and CameraAlerts[cameraId].alertTime == os.time() then
            CameraAlerts[cameraId] = {
                status = "normal",
                alertType = nil,
                alertTime = 0
            }
            TriggerClientEvent('lspd_cameras:alertUpdate', -1, cameraId, CameraAlerts[cameraId])
        end
    end)
end)

RegisterNetEvent('lspd_cameras:requestCameras', function()
    local source = source
    if CanViewCameras(source) then
        local canManage = CanManageCameras(source)
        TriggerClientEvent('lspd_cameras:updateCameras', source, Cameras, CameraAlerts, canManage)
        TriggerClientEvent('lspd_cameras:syncBrokenCameras', source, BrokenCameras)
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "LSPD", "You don't have permission to access cameras." }
        })
    end
end)

RegisterNetEvent('lspd_cameras:cameraShot', function(cameraId, screenshot)
    if not Cameras[cameraId] then return end
    
    BrokenCameras[cameraId] = {
        broken = true,
        timestamp = os.time(),
        screenshot = screenshot or nil,
        repairedAt = os.time() + (Config.CameraDamage.brokenDuration / 1000)
    }
    
    if not CameraAlerts[cameraId] then
        CameraAlerts[cameraId] = {}
    end
    
    CameraAlerts[cameraId].broken = true
    CameraAlerts[cameraId].screenshot = screenshot
    
    TriggerClientEvent('lspd_cameras:cameraStatusUpdate', -1, cameraId, BrokenCameras[cameraId], CameraAlerts[cameraId])
    
    SetTimeout(Config.CameraDamage.brokenDuration, function()
        if BrokenCameras[cameraId] then
            BrokenCameras[cameraId] = nil
            
            if CameraAlerts[cameraId] then
                CameraAlerts[cameraId].broken = false
            end
            
            TriggerClientEvent('lspd_cameras:cameraRepaired', -1, cameraId)
            TriggerClientEvent('lspd_cameras:updateCameras', -1, Cameras, CameraAlerts)
        end
    end)
end)

RegisterNetEvent('lspd_cameras:requestCameraScreenshot', function(cameraId)
    local source = source
    
    if BrokenCameras[cameraId] and BrokenCameras[cameraId].screenshot then
        TriggerClientEvent('lspd_cameras:showCameraScreenshot', source, cameraId, BrokenCameras[cameraId].screenshot)
    end
end)

CreateThread(function()
    if not Cameras then
        Cameras = {}
    end

    if not CameraAlerts then
        CameraAlerts = {}
    end

    if Config.Framework ~= 'standalone' then
        while GetResourceState('oxmysql') ~= 'started' do
            Wait(100)
        end

            MySQL.Async.execute([[
                CREATE TABLE IF NOT EXISTS lspd_cameras (
                    id INT PRIMARY KEY,
                    label VARCHAR(255),
                    coords TEXT,
                    rotation TEXT,
                    postal VARCHAR(10),
                    location VARCHAR(255),
                    notes TEXT,
                    createdBy VARCHAR(255),
                    createdAt DATETIME,
                    screenshot TEXT
                )
            ]], {}, function()
            Wait(1000)
            LoadCamerasFromDB()
        end)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    TriggerClientEvent('lspd_cameras:destroyAllCameras', -1)

    if Cameras then
        for id, _ in pairs(Cameras) do
            Cameras[id] = nil
        end
    end
    Cameras = {}
    CameraAlerts = {}
    CameraIdCounter = 1

    if Config.Framework ~= 'standalone' then
        MySQL.Async.execute('DELETE FROM lspd_cameras', {})
        MySQL.Async.execute('TRUNCATE TABLE lspd_cameras', {})
    end
end)