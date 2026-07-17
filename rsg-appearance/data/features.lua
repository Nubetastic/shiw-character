local Data = {}

Data.features = {
    head_width = 0x84D6,
    face_width = 41396,
    face_depth = 12281,
    forehead_size = 13059,
    neck_width = 36277,
    neck_depth = 60890,
    eyebrow_height = 0x3303,
    eyebrow_width = 0x2FF9,
    eyebrow_depth = 0xC06D,
    ears_width = 0xC04F,
    ears_angle = 0xB6CE,
    ears_height = 0x2844,
    ears_size = 0xED30,
    cheekbones_height = 0x6A0B,
    cheekbones_width = 0xABCF,
    cheekbones_depth = 0x358D,
    jaw_height = 0x8D0A,
    jaw_width = 0xEBAE,
    jaw_depth = 0x1DF6,
    chin_height = 0x3C0F,
    chin_width = 0xC3B2,
    chin_depth = 0xE323,
    eyelid_height = 0x8B2B,
    eyelid_width = 0x1B6B,
    eyes_depth = 0xEE44,
    eyes_angle = 0xD266,
    eyes_distance = 0xA54E,
    eyes_height = 0xDDFB,
    nose_width = 0x6E7F,
    nose_size = 0x3471,
    nose_height = 0x03F5,
    nose_angle = 0x34B1,
    nose_curvature = 0xF156,
    nostrils_distance = 0x561E,
    mouth_width = 0xF065,
    mouth_depth = 0xAA69,
    mouth_y_pos = 0x7AC3,
    mouth_x_pos = 0x410D,
    upper_lip_height = 0x1A00,
    upper_lip_width = 0x91C1,
    upper_lip_depth = 0xC375,
    lower_lip_height = 0xBB4D,
    lower_lip_width = 0xB0B0,
    mouth_corner_left_width = 57350,
    mouth_corner_right_width = 60292,
    mouth_corner_left_depth = 40950,
    mouth_corner_right_depth = 49299,
    mouth_corner_left_height = 46661,
    mouth_corner_right_height = 55718,
    mouth_corner_left_lips_distance = 22344,
    mouth_corner_right_lips_distance = 9423,
    arms_size = 46032,
    uppr_shoulder_size = 50039,
    back_shoulder_thickness = 7010,
    back_muscle = 18046,
    chest_size = 27779,
    waist_width = 50460,
    hips_size = 49787,
    tight_size = 64834,
    calves_size = 42067,
}

Data.Appearance = {
    body_size = {
        -1241887289,
        61606861,
        -369348190,
        -20262001,
        32611963,
    },
    body_waist = {
        -2045421226,    -- 1: smallest
        -1745814259,    -- 2
        -325933489,     -- 3
        -1065791927,    -- 4
        -844699484,     -- 5
        -1273449080,    -- 6
        927185840,      -- 7
        149872391,      -- 8
        399015098,      -- 9
        -644349862,     -- 10
        1745919061,     -- 11: default
        1004225511,     -- 12
        1278600348,     -- 13
        502499352,      -- 14
        -2093198664,    -- 15
        -1837436619,    -- 16
        1736416063,     -- 17
        2040610690,     -- 18
        -1173634986,    -- 19
        -867801909,     -- 20
        1960266524,     -- 21: original biggest
    -- Synchronize appearance
        1960266524,     -- 22
        -867801909,     -- 23
        2040610690,     -- 24
        1960266524,     -- 25
        -867801909,     -- 26
        2040610690,     -- 27
        1960266524,     -- 28
        -867801909,     -- 29
        1960266524,     -- 30: maximum fat
    },
    chest_size = {
        1676751061,	-- upperbody size -- smallest
        1437242440,	-- upperbody size
        3025752508,	-- upperbody size
        3319526593,	-- upperbody size
        1492392695,	-- upperbody size
        1781382506,	-- upperbody size
        1824113282,	-- upperbody size
        2123392559,	-- upperbody size
        290229161,	-- upperbody size
        870174923,	-- upperbody size
        465805723,	-- upperbody size -- biggest
    }
}

return Data