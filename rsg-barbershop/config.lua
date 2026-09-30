Config = {}

Config.ScaleModifier = 0 -- added to the player's shared interface scale

-- Barbershop Locations
Config.Barbershops = {
    {
        coords = vec4(-816.63, -1367.93, 43.75, 283.56),     -- Blackwater
        cam = vec4(-815.02, -1367.88, 44.30, 86.47),
        name = "Blackwater Barbershop"
    },
    {
        coords = vec4(2655.32, -1179.96, 53.28, 358.97),     -- Saint-Denis
        cam = vec4(2655.43, -1178.70, 54.00, 173.97),
        name = "Saint-Denis Barbershop"
    },
    {
        coords = vec4(-306.6630, 813.5593, 118.7440, 103.3177),     -- Valentine
        cam = vector4(-308.1042, 813.3577, 120.5554, 276.9615),
        name = "Saint-Denis Barbershop"
    },
    {
        coords = vector4(-3667.9290, -2596.1060, -13.5669, 186.7277),     -- Armadillo
        cam = vector4(-308.1042, 813.3577, 120.5554, 276.9615),
        name = "Armadillo Barbershop"
    },
}


Config.Hours = {
    open = 8,
    close = 20,
    enable = true,
}

-- Prices
Config.Prices = {
    hair = 5.00,         -- Price for haircut
    beard = 2.50,        -- Price for beard trim
    eyebrows = 1.00,      -- Eyebrows (type and color)
    makeup = 2.00,        -- Price for makeup (women only)
    hairShave = 3.00,     -- Price to shave hair (bald)
    hairColor = 2.00,    -- Price for hair color change
    beardColor = 1.00,   -- Price for beard color change
}

-- Hair color names
Config.HairColors = {
    { name = "Blonde",           suffix = "BLONDE" },
    { name = "Brown",            suffix = "BROWN" },
    { name = "Dark Brown",       suffix = "DARKEST_BROWN" },
    { name = "Dark Blonde",      suffix = "DARK_BLONDE" },
    { name = "Dark Red",         suffix = "DARK_GINGER" },
    { name = "Dark Gray",        suffix = "DARK_GREY" },
    { name = "Red",              suffix = "GINGER" },
    { name = "Gray",             suffix = "GREY" },
    { name = "Jet Black",        suffix = "JET_BLACK" },
    { name = "Light Blonde",     suffix = "LIGHT_BLONDE" },
    { name = "Red-Orange",       suffix = "RED_GINGER" },
}

-- Camera settings
Config.CameraSettings = {
    fov = 35.0,
    pitch = -4.0,
}

-- Offset relative to the chair (like in spooni-interactions): x, y, z, heading
-- GenericChairs: 0, 0, 0.5, 180 — chair center + seat height
Config.BarberChairOffset = vec4(0, 0, 0.6, 180)

-- Sitting scenario for barbershop (just sit — neutral customer pose)
Config.BarberScenarios = {
    male = 'PROP_PLAYER_BARBER_SEAT',
    female = 'PROP_PLAYER_BARBER_SEAT',
}

-- Standing up animation when leaving the chair
Config.BarberStandAnim = {
    dict = 'amb_generic@generic_seat_chair@ft_together@arthur@stand_exit@b_hands',
    anim = 'exit_front',
    duration = 2000,  -- ms delay
}

-- Camera higher, tracks face (directly on face)
Config.CamDistanceFromPlayer = 1.4
Config.CamHeightOffset = 0.7    -- Camera height (face level)
Config.CamAimAtHeadOffset = 0.5 -- Camera target: head/face
Config.CamTrackFace = true       -- Update camera aim every frame (track on face)
