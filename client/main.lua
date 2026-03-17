local Framework = nil
local PlayerData = {}
local Cameras = {}
local CameraAlerts = {}
local CanManage = false
local IsPlacingCamera = false
local TempCamera = nil
local InMonitoringStation = false
local ViewingCamera = nil
local ManualPan = 0
local ManualTilt = 0
local CurrentZoom = Config.CameraFOV
local NightVisionActive = false
local ThermalVisionActive = false
local cameraCreationData = nil
local BrokenCameras = {}
local DamagedCameraEffects = {}
local CursorActiveInCamera = false

if Config.Framework == 'esx' then
    Framework = exports['es_extended']:getSharedObject()
    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
    end)
    RegisterNetEvent('esx:setJob', function(job)
        PlayerData.job = job
    end)
elseif Config.Framework == 'qbcore' then
    Framework = exports['qb-core']:GetCoreObject()
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        PlayerData = Framework.Functions.GetPlayerData()
    end)
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
        PlayerData.job = JobInfo
    end)
end

local function IsPolice()
    if Config.Framework == 'standalone' then
        return true
    elseif Config.Framework == 'esx' then
        return PlayerData.job and table.contains(Config.PoliceJobs, PlayerData.job.name)
    elseif Config.Framework == 'qbcore' then
        return PlayerData.job and table.contains(Config.PoliceJobs, PlayerData.job.name)
    end
    return false
end

function table.contains(tbl, element)
    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

local function GetReadableZoneName(coords)
    local zoneHash = GetNameOfZone(coords.x, coords.y, coords.z)
    
    local zoneNames = {
        ['AIRP'] = 'Los Santos International Airport',
        ['ALAMO'] = 'Alamo Sea',
        ['ALTA'] = 'Alta',
        ['ARMYB'] = 'Fort Zancudo',
        ['BANHAMC'] = 'Banham Canyon',
        ['BANNING'] = 'Banning',
        ['BEACH'] = 'Vespucci Beach',
        ['BHAMCA'] = 'Banham Canyon',
        ['BRADP'] = 'Braddock Pass',
        ['BRADT'] = 'Braddock Tunnel',
        ['BURTON'] = 'Burton',
        ['CALAFB'] = 'Calafia Bridge',
        ['CANNY'] = 'Raton Canyon',
        ['CCREAK'] = 'Cassidy Creek',
        ['CHAMH'] = 'Chamberlain Hills',
        ['CHIL'] = 'Vinewood Hills',
        ['CHU'] = 'Chumash',
        ['CMSW'] = 'Chiliad Mountain State Wilderness',
        ['CYPRE'] = 'Cypress Flats',
        ['DAVIS'] = 'Davis',
        ['DELBE'] = 'Del Perro Beach',
        ['DELPE'] = 'Del Perro',
        ['DELSOL'] = 'La Puerta',
        ['DESRT'] = 'Grand Senora Desert',
        ['DOWNT'] = 'Downtown',
        ['DTVINE'] = 'Downtown Vinewood',
        ['EAST_V'] = 'East Vinewood',
        ['EBURO'] = 'El Burro Heights',
        ['ELGORL'] = 'El Gordo Lighthouse',
        ['ELYSIAN'] = 'Elysian Island',
        ['GALFISH'] = 'Galilee',
        ['GOLF'] = 'GWC and Golfing Society',
        ['GRAPES'] = 'Grapeseed',
        ['GREATC'] = 'Great Chaparral',
        ['HARMO'] = 'Harmony',
        ['HAWICK'] = 'Hawick',
        ['HORS'] = 'Vinewood Racetrack',
        ['HUMLAB'] = 'Humane Labs and Research',
        ['JAIL'] = 'Bolingbroke Penitentiary',
        ['KOREAT'] = 'Little Seoul',
        ['LACT'] = 'Land Act Reservoir',
        ['LAGO'] = 'Lago Zancudo',
        ['LDAM'] = 'Land Act Dam',
        ['LEGSQU'] = 'Legion Square',
        ['LMESA'] = 'La Mesa',
        ['LOSPUER'] = 'La Puerta',
        ['MIRR'] = 'Mirror Park',
        ['MORN'] = 'Morningwood',
        ['MOVIE'] = 'Richards Majestic',
        ['MTCHIL'] = 'Mount Chiliad',
        ['MTGORDO'] = 'Mount Gordo',
        ['MTJOSE'] = 'Mount Josiah',
        ['MURRI'] = 'Murrieta Heights',
        ['NCHU'] = 'North Chumash',
        ['NOOSE'] = 'N.O.O.S.E',
        ['OCEANA'] = 'Pacific Ocean',
        ['PALCOV'] = 'Paleto Cove',
        ['PALETO'] = 'Paleto Bay',
        ['PALFOR'] = 'Paleto Forest',
        ['PALHIGH'] = 'Palomino Highlands',
        ['PALMPOW'] = 'Palmer-Taylor Power Station',
        ['PBLUFF'] = 'Pacific Bluffs',
        ['PBOX'] = 'Pillbox Hill',
        ['PROCOB'] = 'Procopio Beach',
        ['RANCHO'] = 'Rancho',
        ['RGLEN'] = 'Richman Glen',
        ['RICHM'] = 'Richman',
        ['ROCKF'] = 'Rockford Hills',
        ['RTRAK'] = 'Redwood Lights Track',
        ['SANAND'] = 'San Andreas',
        ['SANCHIA'] = 'San Chianski Mountain Range',
        ['SANDY'] = 'Sandy Shores',
        ['SKID'] = 'Mission Row',
        ['SLAB'] = 'Stab City',
        ['STAD'] = 'Maze Bank Arena',
        ['STRAW'] = 'Strawberry',
        ['TATAMO'] = 'Tataviam Mountains',
        ['TERMINA'] = 'Terminal',
        ['TEXTI'] = 'Textile City',
        ['TONGVAH'] = 'Tongva Hills',
        ['TONGVAV'] = 'Tongva Valley',
        ['VCANA'] = 'Vespucci Canals',
        ['VESP'] = 'Vespucci',
        ['VINE'] = 'Vinewood',
        ['WINDF'] = 'Ron Alternates Wind Farm',
        ['WVINE'] = 'West Vinewood',
        ['ZANCUDO'] = 'Zancudo River',
        ['ZP_ORT'] = 'Port of South Los Santos',
        ['ZQ_UAR'] = 'Davis Quartz'
    }
    
    local zoneName = zoneNames[zoneHash] or zoneHash
    
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    
    if streetName and streetName ~= "" then
        return zoneName .. " - " .. streetName
    end
    
    return zoneName
end

local function CheckCameraAlerts()
    if not Config.AlertSystem.enabled then return end

    CreateThread(function()
        while true do
            Wait(Config.AlertSystem.checkInterval)

            for id, camera in pairs(Cameras) do
                local camCoords = vector3(camera.coords.x, camera.coords.y, camera.coords.z)
                local radius = Config.AlertSystem.detectionRadius

                if Config.AlertSystem.alerts.gunshot.enabled then
                    local peds = GetGamePool('CPed')
                    for _, ped in ipairs(peds) do
                        if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                            local pedCoords = GetEntityCoords(ped)
                            if #(camCoords - pedCoords) < radius then
                                if IsPedShooting(ped) then
                                    TriggerServerEvent('lspd_cameras:triggerAlert', id, 'gunshot')
                                    PlaySoundFrontend(-1, Config.AlertSystem.alertSound.name,
                                        Config.AlertSystem.alertSound.set, true)
                                    break
                                end
                            end
                        end
                    end
                end

                if Config.AlertSystem.alerts.explosion.enabled then
                    if IsExplosionInArea(-1, camCoords.x, camCoords.y, camCoords.z, radius) then
                        TriggerServerEvent('lspd_cameras:triggerAlert', id, 'explosion')
                        PlaySoundFrontend(-1, Config.AlertSystem.alertSound.name, Config.AlertSystem.alertSound.set, true)
                    end
                end

                if Config.AlertSystem.alerts.vehicle_crash.enabled then
                    local vehicles = GetGamePool('CVehicle')
                    for _, veh in ipairs(vehicles) do
                        if DoesEntityExist(veh) then
                            local vehCoords = GetEntityCoords(veh)
                            if #(camCoords - vehCoords) < radius then
                                if HasEntityCollidedWithAnything(veh) and GetEntitySpeed(veh) > 20.0 then
                                    TriggerServerEvent('lspd_cameras:triggerAlert', id, 'vehicle_crash')
                                    PlaySoundFrontend(-1, Config.AlertSystem.alertSound.name,
                                        Config.AlertSystem.alertSound.set, true)
                                    break
                                end
                            end
                        end
                    end
                end

                if Config.AlertSystem.alerts.fire.enabled then
                    if IsExplosionInArea(8, camCoords.x, camCoords.y, camCoords.z, radius) then
                        TriggerServerEvent('lspd_cameras:triggerAlert', id, 'fire')
                        PlaySoundFrontend(-1, Config.AlertSystem.alertSound.name, Config.AlertSystem.alertSound.set, true)
                    end
                end

                if Config.AlertSystem.alerts.dead_body.enabled then
                    local peds = GetGamePool('CPed')
                    for _, ped in ipairs(peds) do
                        if DoesEntityExist(ped) and IsPedDeadOrDying(ped, true) then
                            local pedCoords = GetEntityCoords(ped)
                            if #(camCoords - pedCoords) < radius then
                                TriggerServerEvent('lspd_cameras:triggerAlert', id, 'dead_body')
                                PlaySoundFrontend(-1, Config.AlertSystem.alertSound.name,
                                    Config.AlertSystem.alertSound.set, true)
                                break
                            end
                        end
                    end
                end

                if Config.AlertSystem.alerts.melee_fight.enabled then
                    local peds = GetGamePool('CPed')
                    for _, ped in ipairs(peds) do
                        if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                            local pedCoords = GetEntityCoords(ped)
                            if #(camCoords - pedCoords) < radius then
                                if IsPedInMeleeCombat(ped) then
                                    TriggerServerEvent('lspd_cameras:triggerAlert', id, 'melee_fight')
                                    PlaySoundFrontend(-1, Config.AlertSystem.alertSound.name,
                                        Config.AlertSystem.alertSound.set, true)
                                    break
                                end
                            end
                        end
                    end
                end

                if Config.AlertSystem.alerts.speeding.enabled then
                    local vehicles = GetGamePool('CVehicle')
                    for _, veh in ipairs(vehicles) do
                        if DoesEntityExist(veh) then
                            local vehCoords = GetEntityCoords(veh)
                            if #(camCoords - vehCoords) < radius then
                                local speed = GetEntitySpeed(veh) * 3.6
                                if speed > Config.AlertSystem.alerts.speeding.speedLimit then
                                    TriggerServerEvent('lspd_cameras:triggerAlert', id, 'speeding')
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function MonitorCameraDamage()
    if not Config.CameraDamage.enabled then return end
    
    CreateThread(function()
        while true do
            Wait(100)
            
            if not SpawnedCameraObjects or type(SpawnedCameraObjects) ~= "table" then
                Wait(1000)
                goto continue
            end
            
            for id, obj in pairs(SpawnedCameraObjects) do
                if DoesEntityExist(obj) and not BrokenCameras[id] then
                    SetEntityCanBeDamaged(obj, true)
                    
                    if HasEntityBeenDamagedByAnyWeapon(obj) then
                        ClearEntityLastWeaponDamage(obj)
                        
                        CreateCameraDamageEffect(obj)
                        
                        BrokenCameras[id] = true
                        
                        if Cameras[id] then
                            Cameras[id].broken = true
                        end
                        
                        SendNUIMessage({
                            action = "updateCameraStatus",
                            cameraId = id,
                            broken = true,
                            screenshot = nil
                        })
                        
                        if Config.CameraDamage.screenshotOnDamage and Cameras[id] then
                            TakeScreenshotOfCamera(id, Cameras[id])
                        else
                            TriggerServerEvent('lspd_cameras:cameraShot', id, nil)
                        end
                    end
                end
            end
            
            ::continue::
        end
    end)
end

function CreateCameraDamageEffect(cameraObj)
    local coords = GetEntityCoords(cameraObj)
    
    RequestNamedPtfxAsset(Config.CameraDamage.damageParticle.dict)
    while not HasNamedPtfxAssetLoaded(Config.CameraDamage.damageParticle.dict) do
        Wait(0)
    end
    
    UseParticleFxAssetNextCall(Config.CameraDamage.damageParticle.dict)
    local effect = StartParticleFxLoopedAtCoord(
        Config.CameraDamage.damageParticle.name,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        Config.CameraDamage.damageParticle.scale,
        false, false, false
    )
    
    table.insert(DamagedCameraEffects, effect)
    
    SetTimeout(Config.CameraDamage.effectDuration, function()
        StopParticleFxLooped(effect, 0)
        for i, fx in ipairs(DamagedCameraEffects) do
            if fx == effect then
                table.remove(DamagedCameraEffects, i)
                break
            end
        end
    end)
end

function TakeScreenshotDuringPlacement(callback)
end

local function StartCameraPlacement()
    if IsPlacingCamera then return end

    IsPlacingCamera = true
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    local forwardX = GetEntityForwardX(playerPed)
    local forwardY = GetEntityForwardY(playerPed)

    FreezeEntityPosition(playerPed, true)

    local model = GetHashKey(Config.CameraObject)

    if not HasModelLoaded(model) then
        RequestModel(model)
    end

    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(5)
        timeout = timeout + 1
        if timeout > 400 then
            IsPlacingCamera = false
            FreezeEntityPosition(playerPed, false)
            TriggerEvent('chat:addMessage', {
                color = { 255, 0, 0 },
                args = { "Law System", "Failed to load camera model." }
            })
            return
        end
    end

    TempCamera = CreateObject(model,
        coords.x + (forwardX * 5.0),
        coords.y + (forwardY * 5.0),
        coords.z + 3.0,
        false, false, false)
    SetEntityHeading(TempCamera, (heading + 180.0) % 360.0)
    SetEntityAlpha(TempCamera, 255, false)
    SetEntityCollision(TempCamera, false, false)

    local previewCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    local camCoords = GetEntityCoords(TempCamera)
    local camRot = GetEntityRotation(TempCamera, 2)

    SetCamCoord(previewCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(previewCam, camRot.x - 15.0, camRot.y, camRot.z, 2)
    SetCamFov(previewCam, Config.CameraFOV)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 0, true, false)

    SetNuiFocus(false, false)
    DisplayRadar(false)

    SendNUIMessage({
        action = "showPlacementHUD",
        show = true
    })

    CreateThread(function()
        while IsPlacingCamera do
            Wait(0)

            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)
            EnableControlAction(0, 245, true)

            local camCoords = GetEntityCoords(TempCamera)
            local camHeading = GetEntityHeading(TempCamera)
            local camRot = GetEntityRotation(TempCamera, 2)

            SetCamCoord(previewCam, camCoords.x, camCoords.y, camCoords.z)
            SetCamRot(previewCam, camRot.x - 15.0, camRot.y, camRot.z, 2)

            if IsDisabledControlPressed(0, 32) then
                local heading = math.rad(camHeading)
                SetEntityCoords(TempCamera,
                    camCoords.x + math.sin(heading) * 0.05,
                    camCoords.y + math.cos(heading) * 0.05,
                    camCoords.z, false, false, false, false)
            end
            if IsDisabledControlPressed(0, 33) then
                SetEntityCoords(TempCamera, camCoords.x, camCoords.y, camCoords.z - 0.05, false, false, false, false)
            end
            if IsDisabledControlPressed(0, 34) then
                local heading = math.rad(camHeading + 90)
                SetEntityCoords(TempCamera,
                    camCoords.x + math.sin(heading) * 0.05,
                    camCoords.y + math.cos(heading) * 0.05,
                    camCoords.z, false, false, false, false)
            end
            if IsDisabledControlPressed(0, 35) then
                local heading = math.rad(camHeading - 90)
                SetEntityCoords(TempCamera,
                    camCoords.x + math.sin(heading) * 0.05,
                    camCoords.y + math.cos(heading) * 0.05,
                    camCoords.z, false, false, false, false)
            end
            if IsDisabledControlPressed(0, 44) then
                local heading = math.rad(camHeading)
                SetEntityCoords(TempCamera,
                    camCoords.x - math.sin(heading) * 0.05,
                    camCoords.y - math.cos(heading) * 0.05,
                    camCoords.z, false, false, false, false)
            end
            if IsDisabledControlPressed(0, 20) then
                SetEntityCoords(TempCamera, camCoords.x, camCoords.y, camCoords.z + 0.05, false, false, false, false)
            end

            if IsDisabledControlPressed(0, 172) then
                local camRot = GetEntityRotation(TempCamera, 2)
                SetEntityRotation(TempCamera, camRot.x + 1.0, camRot.y, camRot.z, 2, true)
            end
            if IsDisabledControlPressed(0, 173) then
                local camRot = GetEntityRotation(TempCamera, 2)
                SetEntityRotation(TempCamera, camRot.x - 1.0, camRot.y, camRot.z, 2, true)
            end
            if IsDisabledControlPressed(0, 174) then
                SetEntityHeading(TempCamera, camHeading + 2.0)
            end
            if IsDisabledControlPressed(0, 175) then
                SetEntityHeading(TempCamera, camHeading - 2.0)
            end

            if IsDisabledControlJustPressed(0, 201) or IsDisabledControlJustPressed(0, 191) then
                SendNUIMessage({
                    action = "showPlacementHUD",
                    show = false
                })
                
                CreateThread(function()
                    ConfirmCameraPlacement()
                    
                    Wait(5000)
                    
                    if previewCam then
                        RenderScriptCams(false, false, 0, true, false)
                        DestroyCam(previewCam, false)
                    end
                end)
                
                break
            end

            if IsDisabledControlJustPressed(0, 194) then
                RenderScriptCams(false, false, 0, true, false)
                DestroyCam(previewCam, false)
                CancelCameraPlacement()
            end
        end
    end)
end

function ConfirmCameraPlacement()
    if not TempCamera or not DoesEntityExist(TempCamera) then return end
    
    local camCoords = GetEntityCoords(TempCamera)
    local camHeading = GetEntityHeading(TempCamera)
    local camRotation = GetEntityRotation(TempCamera, 2)
    local cameraName = "Camera #" .. (GetCameraCount() + 1)
    local cameraNotes = ""

    if cameraCreationData and cameraCreationData.name and cameraCreationData.name ~= "" then
        cameraName = cameraCreationData.name
        cameraNotes = cameraCreationData.notes or ""
    end
    
    SendNUIMessage({
        action = "showLoading",
        show = true
    })
    
    CreateThread(function()
        while IsPlacingCamera do
            Wait(0)
            DisableAllControlActions(0)
        end
    end)
    
    exports['screenshot-basic']:requestScreenshotUpload(
        Config.ScreenshotWebhook,
        'files[]',
        function(data)
            local imageUrl = nil
            
            if data then
                local response = json.decode(data)
                if response and response.attachments and response.attachments[1] then
                    imageUrl = response.attachments[1].proxy_url or response.attachments[1].url
                end
            end
            
            SendNUIMessage({
                action = "showLoading",
                show = false
            })
            
            local zoneName = GetReadableZoneName(camCoords)

            local cameraData = {
                label = cameraName,
                coords = { x = camCoords.x, y = camCoords.y, z = camCoords.z },
                rotation = { x = camRotation.x, y = camRotation.y, z = camHeading },
                location = zoneName,
                notes = cameraNotes,
                createdBy = GetPlayerName(PlayerId()),
                screenshot = imageUrl
            }

            TriggerServerEvent('lspd_cameras:saveCamera', cameraData)

            if TempCamera and DoesEntityExist(TempCamera) then
                DeleteObject(TempCamera)
            end

            IsPlacingCamera = false
            TempCamera = nil
            cameraCreationData = nil

            local playerPed = PlayerPedId()
            FreezeEntityPosition(playerPed, false)

            DisplayRadar(true)
            SendNUIMessage({
                action = "showPlacementHUD",
                show = false
            })
        end
    )
end

function CancelCameraPlacement()
    IsPlacingCamera = false

    if TempCamera and DoesEntityExist(TempCamera) then
        DeleteObject(TempCamera)
    end
    TempCamera = nil

    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)

    DisplayRadar(true)
    SendNUIMessage({
        action = "showPlacementHUD",
        show = false
    })
end

function GetCameraCount()
    local count = 0
    for _ in pairs(Cameras) do
        count = count + 1
    end
    return count
end

local SpawnedCameraObjects = {}

function SpawnCameraObjects()
    for _, obj in pairs(SpawnedCameraObjects) do
        if DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
    SpawnedCameraObjects = {}

    if not Cameras or type(Cameras) ~= "table" then
        return
    end

    local cameraCount = 0
    for _ in pairs(Cameras) do
        cameraCount = cameraCount + 1
    end

    if cameraCount == 0 then
        return
    end

    local model = GetHashKey(Config.CameraObject)
    if not HasModelLoaded(model) then
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) do
            Wait(10)
            timeout = timeout + 1
            if timeout > 300 then
                IsPlacingCamera = false
                FreezeEntityPosition(playerPed, false)
                TriggerEvent('chat:addMessage', {
                    color = { 255, 0, 0 },
                    args = { "Law System", "Failed to load camera model. Please try again." }
                })
                return
            end
        end
    end

    for id, camera in pairs(Cameras) do
        if camera and camera.coords then
            local obj = CreateObject(model, camera.coords.x, camera.coords.y, camera.coords.z, false, false, false)
            if DoesEntityExist(obj) then
                local objectRotZ = (camera.rotation.z - 210.0) % 360.0
                SetEntityRotation(obj, camera.rotation.x, camera.rotation.y, objectRotZ, 2, true)
                SetEntityCollision(obj, false, false)
                FreezeEntityPosition(obj, true)
                SetEntityCanBeDamaged(obj, true)
                SetEntityHealth(obj, 1000)
                SpawnedCameraObjects[id] = obj
            end
        end
    end

    SetModelAsNoLongerNeeded(model)
end

CreateThread(function()
    while true do
        Wait(0)

        if Config.Framework ~= 'standalone' then
            if not IsPolice() then
                Wait(1000)
                goto continue
            end
        end

        local playerCoords = GetEntityCoords(PlayerPedId())
        local stationCoords = Config.MonitoringStation.coords
        local distance = #(playerCoords - stationCoords)

        if distance < Config.MonitoringStation.drawDistance then
            DrawMarker(
                Config.MonitoringStation.markerType,
                stationCoords.x, stationCoords.y, stationCoords.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                Config.MonitoringStation.markerSize.x,
                Config.MonitoringStation.markerSize.y,
                Config.MonitoringStation.markerSize.z,
                Config.MonitoringStation.markerColor.r,
                Config.MonitoringStation.markerColor.g,
                Config.MonitoringStation.markerColor.b,
                Config.MonitoringStation.markerColor.a,
                false, true, 2, nil, nil, false
            )

            if distance < Config.MonitoringStation.interactionDistance then
                DrawText3D(stationCoords.x, stationCoords.y, stationCoords.z + 0.5,
                    "~b~[E]~w~ Access Camera System")

                if IsControlJustPressed(0, 38) then
                    OpenMonitoringStation()
                end
            end
        else
            Wait(500)
        end

        ::continue::
    end
end)

function OpenMonitoringStation()
    if InMonitoringStation then return end

    InMonitoringStation = true
    TriggerServerEvent('lspd_cameras:requestCameras')

    local playerPed = PlayerPedId()
    RequestAnimDict("amb@code_human_in_bus_passenger_idles@female@tablet@base")
    while not HasAnimDictLoaded("amb@code_human_in_bus_passenger_idles@female@tablet@base") do
        Wait(0)
    end

    TaskPlayAnim(playerPed, "amb@code_human_in_bus_passenger_idles@female@tablet@base", "base", 8.0, 8.0, -1, 50, 0,
        false, false, false)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openMonitoring",
        cameras = Cameras,
        alerts = CameraAlerts,
        canManage = CanManage
    })
end

function CloseMonitoringStation()
    InMonitoringStation = false
    SetNuiFocus(false, false)

    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)

    SendNUIMessage({
        action = "closeMonitoring"
    })
end

function ViewCamera(cameraId)
    local camera = Cameras[cameraId]
    if not camera then return end
    
    if BrokenCameras[cameraId] then
        SendNUIMessage({
            action = "showNotification",
            message = "This camera is currently offline due to damage"
        })
        return
    end

    ViewingCamera = cameraId
    ManualPan = 0
    ManualTilt = 0
    CurrentZoom = Config.CameraFOV
    NightVisionActive = false
    ThermalVisionActive = false

    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)

    SetFocusPosAndVel(camera.coords.x, camera.coords.y, camera.coords.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(camera.coords.x, camera.coords.y, camera.coords.z)
    Wait(1000)

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camera.coords.x, camera.coords.y, camera.coords.z)
    SetCamRot(cam, camera.rotation.x - 15.0, camera.rotation.y, camera.rotation.z, 2)
    SetCamFov(cam, CurrentZoom)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = "enterCameraView",
        camera = camera
    })

    CreateThread(function()
        Wait(500)
        local startTime = GetGameTimer()
        
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)

        while ViewingCamera do
            Wait(0)
            local elapsedTime = GetGameTimer() - startTime
            
            if IsPauseMenuActive() then
                SetFrontendActive(false)
            end
            
            SetNuiFocus(false, false)

            DisableAllControlActions(0)
            
            EnableControlAction(0, 245, true)
            EnableControlAction(0, 249, true)
            
            DisableControlAction(0, 166, true)
            DisableControlAction(0, 167, true)
            DisableControlAction(0, 243, true)
            DisableControlAction(0, 244, true)
            DisableControlAction(0, 27, true)
            DisableControlAction(0, 311, true)
            DisableControlAction(0, 199, true)
            
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)

            if IsDisabledControlPressed(0, 174) then
                ManualPan = math.min(ManualPan + Config.ManualRotationSpeed, Config.ManualPanRange.max)
            end
            if IsDisabledControlPressed(0, 175) then
                ManualPan = math.max(ManualPan - Config.ManualRotationSpeed, Config.ManualPanRange.min)
            end
            if IsDisabledControlPressed(0, 172) then
                ManualTilt = math.min(ManualTilt + Config.ManualRotationSpeed, Config.ManualTiltRange.max)
            end
            if IsDisabledControlPressed(0, 173) then
                ManualTilt = math.max(ManualTilt - Config.ManualRotationSpeed, Config.ManualTiltRange.min)
            end

            if IsDisabledControlPressed(0, Config.ZoomInKey) then
                CurrentZoom = math.max(20.0, CurrentZoom - 0.5)
                SetCamFov(cam, CurrentZoom)
            end
            if IsDisabledControlPressed(0, Config.ZoomOutKey) then
                CurrentZoom = math.min(80.0, CurrentZoom + 0.5)
                SetCamFov(cam, CurrentZoom)
            end

            local finalRotX = camera.rotation.x - 15.0 + ManualTilt
            local finalRotZ = camera.rotation.z + ManualPan

            SetCamRot(cam, finalRotX, camera.rotation.y, finalRotZ, 2)

            if elapsedTime > 500 then
                if IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 202) then
                    ExitCameraView()
                    break
                end
            end
        end

        SetNightvision(false)
        SetSeethrough(false)
        ClearFocus()
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        FreezeEntityPosition(playerPed, false)
    end)
end

function ExitCameraView()
    if not ViewingCamera then return end

    ViewingCamera = nil
    SetNightvision(false)
    SetSeethrough(false)
    ClearFocus()

    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)

    SendNUIMessage({
        action = "exitCameraView"
    })

    SendNUIMessage({
        action = "openMonitoring",
        cameras = Cameras,
        alerts = CameraAlerts,
        canManage = CanManage
    })

    SetNuiFocus(true, true)
end

RegisterNUICallback('startCameraPlacement', function(data, cb)
    if data and data.name then
        cameraCreationData = {
            name = data.name,
            notes = data.notes or ""
        }
    end
    
    cb('ok')
    
    Wait(50)
    
    StartCameraPlacement()
end)

RegisterNUICallback('closeMonitoring', function(data, cb)
    CloseMonitoringStation()
    cb('ok')
end)

RegisterNUICallback('viewCamera', function(data, cb)
    ViewCamera(data.cameraId)
    cb('ok')
end)

RegisterNUICallback('exitCamera', function(data, cb)
    ExitCameraView()
    cb('ok')
end)

RegisterNUICallback('renameCamera', function(data, cb)
    if CanManage then
        TriggerServerEvent('lspd_cameras:renameCamera', data.cameraId, data.newLabel)
    end
    cb('ok')
end)

RegisterNUICallback('deleteCamera', function(data, cb)
    if CanManage then
        TriggerServerEvent('lspd_cameras:deleteCamera', data.cameraId)
    end
    cb('ok')
end)

RegisterNUICallback('cancelCameraNameInput', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('updateCameraSettings', function(data, cb)
    if CanManage then
        TriggerServerEvent('lspd_cameras:updateCameraSettings', data.cameraId, data.label, data.location, data.notes)
    end
    cb('ok')
end)

RegisterNUICallback('requestScreenshot', function(data, cb)
    TriggerServerEvent('lspd_cameras:requestCameraScreenshot', data.cameraId)
    cb('ok')
end)

RegisterNetEvent('lspd_cameras:startPlacement', function()
    StartCameraPlacement()
end)

RegisterNetEvent('lspd_cameras:updateCameras', function(cameras, alerts, canManage)
    if cameras and type(cameras) == "table" then
        Cameras = cameras
    else
        Cameras = {}
    end
    
    if alerts and type(alerts) == "table" then
        CameraAlerts = alerts
    else
        CameraAlerts = {}
    end
    
    CanManage = canManage or false

    SpawnCameraObjects()

    SendNUIMessage({
        action = "updateCameraList",
        cameras = Cameras,
        alerts = CameraAlerts,
        canManage = CanManage
    })
end)

RegisterNetEvent('lspd_cameras:alertUpdate', function(cameraId, alertData)
    if CameraAlerts[cameraId] then
        CameraAlerts[cameraId] = alertData
        SendNUIMessage({
            action = "alertUpdate",
            cameraId = cameraId,
            alertData = alertData
        })
    end
end)

RegisterNetEvent('lspd_cameras:removeCamera', function(cameraId)
    if SpawnedCameraObjects and SpawnedCameraObjects[cameraId] then
        local obj = SpawnedCameraObjects[cameraId]
        if DoesEntityExist(obj) then
            SetEntityAsMissionEntity(obj, false, true)
            DeleteObject(obj)
            DeleteEntity(obj)
        end
        SpawnedCameraObjects[cameraId] = nil
    end
end)

RegisterNetEvent('lspd_cameras:destroyAllCameras', function()
    local cameraModels = {
        GetHashKey('prop_cctv_cam_01a'),
        GetHashKey('prop_cctv_cam_01b'),
        GetHashKey('prop_cctv_cam_02a'),
        GetHashKey('prop_cctv_cam_03a'),
        GetHashKey('prop_cctv_cam_04a'),
        GetHashKey('prop_cctv_cam_04b'),
        GetHashKey('prop_cctv_cam_05a'),
        GetHashKey('prop_cctv_cam_06a'),
        GetHashKey('prop_cctv_cam_07a'),
        GetHashKey(Config.CameraObject)
    }

    local allObjects = GetGamePool('CObject')
    for _, obj in ipairs(allObjects) do
        if DoesEntityExist(obj) then
            local objModel = GetEntityModel(obj)
            for _, cameraModel in ipairs(cameraModels) do
                if objModel == cameraModel then
                    SetEntityAsMissionEntity(obj, false, true)
                    DeleteObject(obj)
                    DeleteEntity(obj)
                    break
                end
            end
        end
    end

    if TempCamera and DoesEntityExist(TempCamera) then
        SetEntityAsMissionEntity(TempCamera, false, true)
        DeleteObject(TempCamera)
        DeleteEntity(TempCamera)
        TempCamera = nil
    end

    if ViewingCamera then
        ViewingCamera = nil
        RenderScriptCams(false, false, 0, true, false)
        SetNightvision(false)
        SetSeethrough(false)
        ClearFocus()
    end

    local playerPed = PlayerPedId()
    if DoesEntityExist(playerPed) then
        FreezeEntityPosition(playerPed, false)
    end

    IsPlacingCamera = false
    InMonitoringStation = false
    DisplayRadar(true)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeMonitoring" })

    Cameras = {}
    CameraAlerts = {}
    SpawnedCameraObjects = {}
end)

RegisterNetEvent('lspd_cameras:requestCameraName', function()
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = "requestCameraName"
    })
end)

RegisterNetEvent('lspd_cameras:cameraStatusUpdate', function(cameraId, brokenData, alertData)
    BrokenCameras[cameraId] = brokenData.broken
    
    if Cameras[cameraId] then
        Cameras[cameraId].broken = brokenData.broken
        Cameras[cameraId].screenshot = brokenData.screenshot
    end
    
    if CameraAlerts[cameraId] then
        CameraAlerts[cameraId] = alertData
    end
    
    SendNUIMessage({
        action = "updateCameraStatus",
        cameraId = cameraId,
        broken = brokenData.broken,
        screenshot = brokenData.screenshot,
        alert = alertData
    })
end)

RegisterNetEvent('lspd_cameras:cameraRepaired', function(cameraId)
    BrokenCameras[cameraId] = nil
    
    if Cameras[cameraId] then
        Cameras[cameraId].broken = false
        Cameras[cameraId].screenshot = nil
    end
    
    SendNUIMessage({
        action = "cameraRepaired",
        cameraId = cameraId
    })
end)

RegisterNetEvent('lspd_cameras:syncBrokenCameras', function(brokenCameras)
    for id, data in pairs(brokenCameras) do
        BrokenCameras[id] = data.broken
    end
end)

RegisterNetEvent('lspd_cameras:showCameraScreenshot', function(cameraId, screenshot)
    SendNUIMessage({
        action = "showScreenshotModal",
        cameraId = cameraId,
        screenshot = screenshot
    })
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
end

CreateThread(function()
    local model = GetHashKey(Config.CameraObject)
    RequestModel(model)
    
    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(50)
        timeout = timeout + 1
        if timeout > 100 then
            break
        end
    end
end)