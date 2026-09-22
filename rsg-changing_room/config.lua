Config = Config or {}

-- Prints the complete Dress Up flow to the client F8 console.
Config.Debug = false

-- Added to the player's shared appearance/clothing/barber/changing-room scale.
Config.ScaleModifier = 0.0

Config.CameraDistance = 2.4
Config.CameraHeight = 0.65
Config.CameraAimHeight = 0.45
Config.CameraFov = 35.0
Config.CameraVerticalStep = 0.20
Config.CameraVerticalMin = -0.60
Config.CameraVerticalMax = 1.20
Config.CharacterTurnStep = 15.0


Config.Cloakrooms = {
    { coords = vec4(-767.95, -1295.42, 43.83, 297.66), cam = vec4(-765.95, -1294.49, 44.35, 114.67) },   -- Blackwater
    { coords = vec4(1324.15, -1287.78, 77.02, 156.98), cam = vec4(1323.01, -1290.21, 77.54, 330.11) },  -- Rhodes
    { coords = vec4(2555.40, -1161.48, 53.71, 322.41), cam = vec4(2557.47, -1159.22, 54.21, 134.74) },  -- Saint Denis
    { coords = vec4(-5479.4795, -2933.3142, -0.3276, 132.8692), cam = vec4(-5481.4005, -2934.8130, 0.0568, 306.1696)}, -- Tumbleweed
	{ coords = vec4(-327.765, 807.769, 117.894, 254.593), cam = vec4(-325.5932, 807.4582, 118.4242, 84.8033)}, -- valentine
    { coords = vector4(-1794.2617, -395.3854, 160.3665, 328.7433), cam = vector4(-1792.7876, -393.2947, 160.8697, 144.2316)}, -- strawberry
}

Config.Hours = {
    open = 8,
    close = 17,
    enable = true,
}

Config.CloakRoomBlips = {
	blipSprite = "blip_shop_wardrobe",
	blipScale = 1,
	blipName = "Changing Room",
}

Config.Stores = {
	["blackwater"] = {
		coords = vector3(-761.8270, -1293.6558, 43.8655), -- NPC Coords vector4(-761.8270, -1293.6558, 43.8655, 1.8674) - s_m_m_tailor_01
		exitCoords = vector3(-762.895, -1291.97, 43.894),
		name = "Blackwater Changing Room",
		blip = false,
	},
	["rhodes"] = {
		coords = vector3(1330.227, -1293.41, 77.021),
		exitCoords = vector3(1323.2900390625, -1291.79296875, 77.09300231933594),
		name = "Rhodes Changing Room",
		blip = false,
	},
	["saint_denis"] = {
		coords = vector3(2554.8418, -1166.8208, 53.7135), -- NPC Cords vector4(2554.8418, -1166.8208, 53.7135, 172.8672)
		exitCoords = vector3(2554.494873046875, -1168.68994140625, 53.79299926757812),
		name = "Saint Denis Changing Room",
		blip = false,
	},
	["tumbleweed"] = {
		coords = vector3(-5485.70, -2938.08, -0.299),
		exitCoords = vector3(-5481.5537, -2934.9695, -0.3655),
		name = "Tumbleweed Changing Room",
		blip = false,
	},
	["valentine"] = {
		coords = vector3(-324.1257, 803.4514, 117.8817),
		exitCoords = vector3(-325.9504, 806.58251, 117.8897),
		name = "Valentine Changing Room",
		blip = false,
	},
    ["strawberry"] = {
		coords = vector3(-1789.66, -387.918, 160.32),
		exitCoords = vector3(-1792.1823, -391.6782, 160.2910),
		name = "Strawberry Changing Room",
		blip = false,
	},
}
