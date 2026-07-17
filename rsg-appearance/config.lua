RSG = {}

-- ★ Disable debug output. Set to true for debugging.
RSG.Debug = false

-- Use the normal streamed body components. Legacy body-fix helpers stay inert.
_G.DisableAutomaticBodyFixes = true

RSG.ScaleModifier = 0 -- added to the player's shared interface scale, -.25 reduces by 25%

-- Clothing ownership is stored by rsg-clothingstore in SQL instead of inventory items.
-- playerskins.clothes remains the active outfit loaded by rsg-appearance.
RSG.UseClothingInventory = false

-- Inventory equipment (/bandana or neckwear): to add a piece of clothing to the player and change it.
RSG.HideBandanaMeshInFirstPerson = true
-- On FP to the player: change motion follow-cam and rotation (on settings 4).
RSG.FirstPersonCamViewModes = { 4 }

--- When Z <= MaxZForTeleport, player character must be grounded. There can be variances to movements.
RSG.UnderMapSafety = {
    --- false = synchronization turned off (when animations execute for player Z and attachment 'link')
    Enabled = true,
    MaxZForTeleport = -7.0,
    --- false = not visible to player, can still teleport in case (on ground or FallbackCoords)
    UseFallbackCoords = false,
    --- Default two-module is UseFallbackCoords = true
    FallbackCoords = vector4(-275.72, 807.28, 119.38, 90.0),
    --- Default GetGroundZ function gets called to check (how player must react to player actions)
    WaitForCollisionMs = 2500,
}

--[[
  ricx_outfits / available outfits: 'Public' to choose from in game
  Object weights to calculate outfits: these are uniforms, suitable vertex weights in it,
  so outfits worked. Required object (slim)
  Equipment variations; types - continuities and variants, available models (Blender/OpenIV),
  and feature restoring/calling style to player (holster-equipped).
]]
RSG.RicxOutfitSlimBody = {
    -- true = Valid settings for ricx allowing MP-outfit (could be changed to player type, or system used).
    enabled = false,
}

-- Custom MP-line test on ricx-type. custom_id = Active variables to change (outfit_id_N) = WearOutfitWithCustomID.
-- Models: for shirts_full. Generated gloves_000 assigning to ricxBareHandsAfterUpperHideCustomIds (with extra + tint to effect).
RSG.RicxOutfitHideBodyMesh = {
    enabled = false,
    hideLower = true,
    hideUpper = true,
    ricxHideUpperBodyCustomIds = {
         -- Changes 1-2, Types 1-5
        'outfit_id_4', 'outfit_id_5',
        'outfit_id_6', 'outfit_id_7', 'outfit_id_8', 'outfit_id_9', 'outfit_id_10',
         -- Gender type 2 (M/F)
        'outfit_id_29', 'outfit_id_34',
         -- Assignable types 3, 5
        'outfit_id_40', 'outfit_id_42',
         -- HS variations 1-7
        'outfit_id_44', 'outfit_id_45', 'outfit_id_46', 'outfit_id_47', 'outfit_id_48', 'outfit_id_49', 'outfit_id_50',
         -- Guaranteed defaults (outfit_id_51)
        'outfit_id_51',
         -- Mandatory adjustments 1-5
        'outfit_id_52', 'outfit_id_53', 'outfit_id_54', 'outfit_id_55', 'outfit_id_56',
         -- Recommended types 2, 4
        'outfit_id_58', 'outfit_id_60',
         -- Options counted 2, 5
        'outfit_id_63', 'outfit_id_66',
    },
    ricxBareHandsAfterUpperHideCustomIds = {
        'outfit_id_29', 'outfit_id_34',
        'outfit_id_42',
         -- HS: added overlay nights even if showing items in BODIES_UPPER; HS?7 and commonly maintain - overlay to previous (but gloves)
        'outfit_id_44', 'outfit_id_45', 'outfit_id_46', 'outfit_id_47', 'outfit_id_48', 'outfit_id_49', 'outfit_id_50',
        'outfit_id_51',
        'outfit_id_58', 'outfit_id_60',
        'outfit_id_63', 'outfit_id_66',
    },
}

-- Customizable print out available types-calls
if not RSG.Debug then
    local _originalPrint = print
    print = function(...) end
end

RSG.ProfanityWords = {
    ['bad word'] = true,
    ['dick'] = true,
    ['ass'] = true
}

RSG.CameraPromptText = locale('camera_prompt_text')
RSG.RotatePromptText = locale('rotate_prompt_text')
RSG.ZoomPromptText = locale('zoom_prompt_text')
RSG.GroupPromptText = locale('group_prompt_text')

RSG.Prompt = {
    MalePrompt = 0xA65EBAB4,
    FemalePrompt = 0xDEB34313,
    ConfirmPrompt = 0x2CD5343E,
    CameraUp = 0x8FD015D8,
    CameraDown = 0xD27782E3,
    RotateLeft = 0x7065027D,
    RotateRight = 0xB4E465B4,
    Zoom1 = 0x62800C92,
    Zoom2 = 0x8BDE7443,
}

RSG.Texts = {
    Body = locale('texts.body'),
    Face = locale('texts.face'),
    Hair_beard = locale('texts.hair_beard'),
    HairStyle = locale('texts.hair_style'),
    HairColor = locale('texts.hair_color'),
    BeardStyle = locale('texts.beard_style'),
    BeardColor = locale('texts.beard_color'),
    Makeup = locale('texts.makeup'),
    Appearance = locale('texts.appearance'),
    Slim = locale('texts.slim'),
    Sporty = locale('texts.sporty'),
    Medium = locale('texts.medium'),
    Fat = locale('texts.fat'),
    Strong = locale('texts.strong'),
    FaceWidth = locale('texts.face_width'),
    SkinTone = locale('texts.skin_tone'),
    Eyes = locale('texts.eyes'),
    Eyelids = locale('texts.eyelids'),
    Eyebrows = locale('texts.eyebrows'),
    Nose = locale('texts.nose'),
    Mouth = locale('texts.mouth'),
    Teeth = locale('texts.teeth'),
    Cheekbones = locale('texts.cheekbones'),
    Jaw = locale('texts.jaw'),
    Ears = locale('texts.ears'),
    Chin = locale('texts.chin'),
    Defects = locale('texts.defects'),
    Hair = locale('texts.hair'),
    Beard = locale('texts.beard'),
    Type = locale('texts.type'),
    Visibility = locale('texts.visibility'),
    ColorPalette = locale('texts.color_palette'),
    ColorFirstrate = locale('texts.color_firstrate'),
    Eyebrow = locale('texts.eyebrow'),
    NoseCurvature = locale('texts.nose_curvature'),
    UP_DOWN = locale('texts.up_down'),
    left_right = locale('texts.left_right'),
    UpperLipHeight = locale('texts.upper_lip_height'),
    UpperLipWidth = locale('texts.upper_lip_width'),
    UpperLipDepth = locale('texts.upper_lip_depth'),
    LowerLipHeight = locale('texts.lower_lip_height'),
    LowerLipWidth = locale('texts.lower_lip_width'),
    LowerLipDepth = locale('texts.lower_lip_depth'),
    Make_up = locale('texts.make_up'),
    Older = locale('texts.older'),
    Scars = locale('texts.scars'),
    Freckles = locale('texts.freckles'),
    Moles = locale('texts.moles'),
    Disadvantages = locale('texts.disadvantages'),
    Spots = locale('texts.spots'),
    Shadow = locale('texts.shadow'),
    ColorShadow = locale('texts.color_shadow'),
    ColorFirst_Class = locale('texts.color_first_class'),
    Blushing_Cheek = locale('texts.blushing_cheek'),
    blush_id = locale('texts.blush_id'),
    blush_c1 = locale('texts.blush_c1'),
    Lipstick = locale('texts.lipstick'),
    ColorLipstick = locale('texts.color_lipstick'),
    lipsticks_c1 = locale('texts.lipsticks_c1'),
    lipsticks_c2 = locale('texts.lipsticks_c2'),
    Eyeliners = locale('texts.eyeliners'),
    eyeliners_id = locale('texts.eyeliners_id'),
    eyeliners_c1 = locale('texts.eyeliners_c1'),
    save = locale('texts.save'),
    Options = locale('texts.options'),
    align = locale('texts.align'),
    Style = locale('texts.style'),
    Color = locale('texts.color'),
    Size = locale('texts.size'),
    Width = locale('texts.width'),
    Height = locale('texts.height'),
    Depth = locale('texts.depth'),
    Waist = locale('texts.waist'),
    Chest = locale('texts.chest'),
    Distance = locale('texts.distance'),
    Angle = locale('texts.angle'),
    Clarity = locale('texts.clarity'),
    Color1 = "<img src='nui://rsg-appearance/img/skin1.png' height='20'>",
    Color2 = "<img src='nui://rsg-appearance/img/skin2.png' height='20'>",
    Color3 = "<img src='nui://rsg-appearance/img/skin3.png' height='20'>",
    Color4 = "<img src='nui://rsg-appearance/img/skin4.png' height='20'>",
    Color5 = "<img src='nui://rsg-appearance/img/skin5.png' height='20'>",
    Color6 = "<img src='nui://rsg-appearance/img/skin6.png' height='20'>",
    Creator = locale('texts.creator'),

    firsmenu = {
        label_firstname = locale('texts.first_menu.label_firstname'),
        label_lastname = locale('texts.first_menu.label_lastname'),
        desc = locale('texts.first_menu.desc'),
        none = locale('texts.first_menu.none'),
        Start = locale('texts.first_menu.start'),
        empty = locale('texts.first_menu.empty'),
        Nationality = locale('texts.first_menu.nationality'),
        Birthdate = locale('texts.first_menu.birthdate'),
    }
}

--Clothing store

RSG.Cloakroomtext = locale('prompts.cloakroom_text')
RSG.BlipName = locale('blips.clothing_store') -- Blip Name Showed on map
RSG.BlipNameCloakRoom = locale('blips.wardrobe') -- Blip Name Showed on map
RSG.BlipSprite = 1195729388	 -- Clothing shop sprite
RSG.BlipSpriteCloakRoom = 1496995379	 -- Clothing shop sprite
RSG.BlipScale = 0.2 -- Blip scale
RSG.OpenKey = 0xD9D0E1C0 -- Opening key hash
RSG.Keybind = 'ENTER' -- keybind
RSG.ShowPlayerBucket = true -- prints to server the player routing bucket

RSG.SetDoorState = {
    -- open = 0 / locked = 1
    { door = 3554893730, state = 1 }, -- valentine
    { door = 2432590327, state = 1 }, -- rhodes
    { door = 3804893186, state = 1 }, -- saint dennis
    { door = 3277501452, state = 1 }, -- blackwater
    { door = 94437577,   state = 1 }, -- strawberry
    { door = 3315914718, state = 1 }, -- armadillo
    { door = 3208189941, state = 1 }, -- tumbleweed
}

RSG.Zones1 = {
}

RSG.Cloakroom = {
}

RSG.Label = {
    boot_accessories    = locale('labels.boot_accessories'),
    pants               = locale('labels.pants'),
    cloaks              = locale('labels.cloaks'),
    hats                = locale('labels.hats'),
    vests               = locale('labels.vests'),
    chaps               = locale('labels.chaps'),
    shirts_full         = locale('labels.shirts_full'),
    badges              = locale('labels.badges'),
    masks               = locale('labels.masks'),
    spats               = locale('labels.spats'),
    neckwear            = locale('labels.neckwear'),
    boots               = locale('labels.boots'),
    accessories         = locale('labels.accessories'),
    jewelry_rings_right = locale('labels.jewelry_rings_right'),
    jewelry_rings_left  = locale('labels.jewelry_rings_left'),
    jewelry_bracelets   = locale('labels.jewelry_bracelets'),
    gauntlets           = locale('labels.gauntlets'),
    neckties            = locale('labels.neckties'),
    holsters_knife      = locale('labels.holsters_knife'),
    talisman_holster    = locale('labels.talisman_holster'),
    loadouts            = locale('labels.loadouts'),
    suspenders          = locale('labels.suspenders'),
    talisman_satchel    = locale('labels.talisman_satchel'),
    satchels            = locale('labels.satchels'),
    gunbelts            = locale('labels.gunbelts'),
    belts               = locale('labels.belts'),
    belt_buckles        = locale('labels.belt_buckles'),
    holsters_left       = locale('labels.holsters_left'),
    holsters_right      = locale('labels.holsters_right'),
    talisman_wrist      = locale('labels.talisman_wrist'),
    coats               = locale('labels.coats'),
    coats_closed        = locale('labels.coats_closed'),
    ponchos             = locale('labels.ponchos'),
    eyewear             = locale('labels.eyewear'),
    gloves              = locale('labels.gloves'),
    holsters_crossdraw  = locale('labels.holsters_crossdraw'),
    aprons              = locale('labels.aprons'),
    skirts              = locale('labels.skirts'),
    hair_accessories    = locale('labels.hair_accessories'),
    armor               = locale('labels.armor'),
    dresses             = locale('labels.dresses'),

    -- other

    save = locale('labels.save'),
    clothes = locale('labels.clothes'),
    options = locale('labels.options'),
    color = locale('labels.color'),
    choose = locale('labels.choose'),
    wear = locale('labels.wear'),
    wear_desc = locale('labels.wear_desc'),
    delete = locale('labels.delete'),
    delete_desc = locale('labels.delete_desc'),
    shop = locale('labels.shop'),
    total = locale('labels.total'),
}

RSG.MenuElements = {
    ["head"] = {
        label = locale('menu_elements.head.label'),
        category = {
            "hats",
            "eyewear",
            "masks",
            "neckwear",
            "neckties",
        }
    },

    ["torso"] = {
        label = locale('menu_elements.torso.label'),
        category = {
            "cloaks",
            "vests",
            "shirts_full",
            "holsters_knife",
            "loadouts",
            "suspenders",
            "gunbelts",
            "belts",
            "holsters_left",
            "holsters_right",
            "coats",
            "coats_closed",
            "ponchos",
            "dresses",
        }
    },

    ["legs"] = {
        label = locale('menu_elements.legs.label'),
        category = {
            "pants",
            "chaps",
            "skirts",
        }
    },
    ["foot"] = {
        label = locale('menu_elements.foot.label'),
        category = {
            "boots",
            "spats",
            "boot_accessories",
        }
    },

    ["hands"] = {
        label = locale('menu_elements.hands.label'),
        category = {
            "jewelry_rings_right",
            "jewelry_rings_left",
            "jewelry_bracelets",
            "gauntlets",
            "gloves",
        }
    },

    ["accessories"] = {
        label = locale('menu_elements.accessories.label'),
        category = {
            "talisman_wrist",
            "talisman_holster",
            "belt_buckles",
            "holsters_crossdraw",
            "aprons",
            "bows",
            "hair_accessories",
        }
    },
}


RSG.Price = {
    -- Default settings
    ['hats'] = 15,
    ['eyewear'] = 10,        -- or glasses
    ['masks'] = 12,
    ['neckwear'] = 10,       -- or scarf
    ['neckties'] = 8,
    
    -- others
    ['shirts_full'] = 20,    -- or shirts
    ['vests'] = 25,
    ['coats'] = 50,
    ['coats_closed'] = 50,
    ['suspenders'] = 12,     -- or straps
    ['gunbelts'] = 35,       -- or belts
    ['belts'] = 10,
    ['ponchos'] = 40,
    ['cloaks'] = 45,
    ['loadouts'] = 30,
    ['holsters_left'] = 25,
    ['holsters_right'] = 25,
    ['holsters_knife'] = 20,
    ['holsters_crossdraw'] = 30,
    ['gauntlets'] = 15,
    ['gloves'] = 8,
    
    -- others
    ['pants'] = 18,          -- or trousers
    ['boots'] = 22,          -- or shoes
    ['chaps'] = 30,
    ['skirts'] = 18,
    ['spurs'] = 15,
    ['spats'] = 12,
    ['boot_accessories'] = 8,
    
    -- Required
    ['jewelry_rings_right'] = 15,
    ['jewelry_rings_left'] = 15,
    ['jewelry_bracelets'] = 20,
    ['rings_rh'] = 15,
    ['rings_lh'] = 15,
    
    -- Consistent
    ['satchels'] = 25,
    ['aprons'] = 10,
    ['bows'] = 8,
    ['hair_accessories'] = 10,
    ['talisman_holster'] = 20,
    ['talisman_wrist'] = 20,
    ['belt_buckles'] = 15,
    ['dresses'] = 35,
}

-- Reference points: for player requirements inventory
RSG.ItemPrices = {
    ['coats'] = {
        [35] = {
            [1] = 30,  -- options
            [2] = 50,  -- numbers
            [3] = 40,  -- quantity
        },
    },
}

RSG.Prompts = {
    {
        label = locale('prompts.clothing_store_label'),
        id = "OPEN_CLOTHING_MENU"
    },
    {
        label = locale('prompts.zoom_label'),
        id = "ZOOM_IO",
        control = `INPUT_CURSOR_SCROLL_UP`,
        control2 = `INPUT_CURSOR_SCROLL_DOWN`,
        time = 0
    },
    {
        label = locale('prompts.camera_up_label'),
        id = "CAM_UD",
        control = `INPUT_MOVE_UP_ONLY`,
        control2 = `INPUT_MOVE_DOWN_ONLY`,
        time = 0
    },
    {
        label = locale('prompts.camera_turn_label'),
        id = "TURN_LR",
        control = `INPUT_MOVE_LEFT_ONLY`,
        control2 = `INPUT_MOVE_RIGHT_ONLY`,
        time = 0
    },
}

--INPUT_RADIAL_MENU_NAV_UD
RSG.CreatedEntries = {}
