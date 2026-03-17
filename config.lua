Config = {}

Config.Framework = 'standalone'

Config.ScreenshotWebhook = 'https://discord.com/api/webhooks/1448302693264134156/mQbyaIBAtv3OvDFJlyDhY89wnXyByjNNRJGmFLFzL-YQdSKQrSyWg1ysZghaWCTenZ8y'

Config.UIKeybind = 'E'

Config.MonitoringStation = {
    coords = vector3(441.05, -978.72, 30.69),
    markerType = 27,
    markerSize = { x = 1.5, y = 1.5, z = 1.0 },
    markerColor = { r = 0, g = 100, b = 255, a = 100 },
    drawDistance = 10.0,
    interactionDistance = 2.0
}

Config.PoliceJobs = {
    'police',
    'sheriff'
}

Config.ViewCamerasGrades = {
    ['police'] = { 0, 1, 2, 3, 4, 5, 6, 7 },
    ['sheriff'] = { 0, 1, 2, 3, 4, 5, 6, 7 },
}

Config.ManageCamerasGrades = {
    ['police'] = { 3, 4, 5, 6, 7 },
    ['sheriff'] = { 3, 4, 5, 6, 7 },
}

Config.CameraObject = 'prop_cctv_cam_01a'
Config.CameraRotationSpeed = 0.0
Config.CameraRotationRange = 90
Config.ManualRotationSpeed = 0.5
Config.ManualTiltRange = { min = -30, max = 30 }
Config.ManualPanRange = { min = -45, max = 45 }

Config.CameraDamage = {
    enabled = true,
    damageEffect = 'core',
    effectDuration = 3000,
    brokenDuration = 900000,
    screenshotOnDamage = true,
    damageParticle = {
        dict = 'core',
        name = 'ent_dst_elec_fire_sp',
        scale = 1.0
    }
}

Config.PlacementCommand = 'nycm'
Config.PlacementHeight = 3.0
Config.MaxCameras = 50

Config.CameraFOV = 50.0
Config.NightVisionKey = 78
Config.ThermalVisionKey = 84
Config.ZoomInKey = 96
Config.ZoomOutKey = 97
Config.ToggleCursorKey = 244

Config.AlertSystem = {
    enabled = true,
    checkInterval = 2000,
    detectionRadius = 50.0,
    
    alerts = {
        gunshot = { enabled = true, priority = 3, duration = 30000 },
        explosion = { enabled = true, priority = 3, duration = 45000 },
        vehicle_crash = { enabled = true, priority = 2, duration = 25000 },
        fire = { enabled = true, priority = 2, duration = 40000 },
        melee_fight = { enabled = true, priority = 1, duration = 20000 },
        dead_body = { enabled = true, priority = 2, duration = 60000 },
        speeding = { enabled = true, priority = 1, duration = 15000, speedLimit = 120.0 }
    },
    
    alertSound = {
        name = "TIMER_STOP",
        set = "HUD_MINI_GAME_SOUNDSET"
    }
}

Config.PostalCodes = {
    [1] = { coords = vector3(425.1, -979.5, 30.7), code = "3201" },
    [2] = { coords = vector3(1854.9, 3686.6, 34.3), code = "8072" },
}

Config.CameraPresets = {

}