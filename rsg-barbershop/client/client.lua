local RSGCore = exports['rsg-core']:GetCoreObject()

local isOpen = false
local currentShop = nil
local storeCam = nil
local camOffsetZ = 0.0
local savedPosition = nil
local savedHeading = nil
local originalHair = nil
local originalBeard = nil
local originalMakeup = nil  -- Makeup overlays (women only)
local originalEyebrows = nil  -- Eyebrows (overlays)
local originalSkin = nil
local looksData = {}
local currentPaidBarberStyle = nil
local uiScale = 1.0
local privateBucketActive = false

local function IsBarbershopOpen()
    if not Config.Hours or not Config.Hours.enable then return true end

    local hour = GetClockHours()
    if Config.Hours.open < Config.Hours.close then
        return hour >= Config.Hours.open and hour < Config.Hours.close
    end

    return hour >= Config.Hours.open or hour < Config.Hours.close
end

local function EnterPrivateBucket()
    if privateBucketActive then return end
    privateBucketActive = true
    TriggerServerEvent(GetCurrentResourceName() .. ':server:enterPrivateBucket')
end

local function LeavePrivateBucket()
    if not privateBucketActive then return end
    privateBucketActive = false
    TriggerServerEvent(GetCurrentResourceName() .. ':server:leavePrivateBucket')
end
-- Component hashes
local HAIR_HASH = 0x864B03AE      -- hair
local BEARD_HASH = 0xF8016BCA     -- beard (heads_accessories)

local function ClampUiScale(scale)
    return math.max(0.25, math.min(3.0, tonumber(scale) or 1.0))
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function DeepCopy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = DeepCopy(item) end
    return copy
end

local function LoadSharedUiScale()
    local playerData = RSGCore.Functions.GetPlayerData()
    local hudScale = playerData and playerData.metadata and playerData.metadata.hudScale
    uiScale = ClampUiScale(type(hudScale) == 'table' and hudScale.rsg_clothingstore or 1.0)
end

local function SaveSharedUiScale(scale)
    uiScale = ClampUiScale(scale)
    local playerData = RSGCore.Functions.GetPlayerData()
    local hudScale = playerData and playerData.metadata and playerData.metadata.hudScale
    local savedScales = CopyTable(type(hudScale) == 'table' and hudScale or {})
    savedScales.rsg_clothingstore = uiScale
    TriggerServerEvent('RSGCore:Server:SetMetaData', 'hudScale', savedScales)
end

-- ==========================================
-- HIDE OTHER PLAYERS IN BARBERSHOP
-- ==========================================
local hiddenPlayers = {}

local function HideOtherPlayers()
    local myPed = PlayerPedId()
    local myPlayer = PlayerId()
    local activePlayers = GetActivePlayers()

    for _, player in ipairs(activePlayers) do
        if player ~= myPlayer then
            local ped = GetPlayerPed(player)
            if ped and ped ~= 0 then
                SetEntityVisible(ped, false)
                SetEntityNoCollisionEntity(myPed, ped, false)
                hiddenPlayers[player] = ped
            end
        end
    end
end

local function ShowOtherPlayers()
    for player, ped in pairs(hiddenPlayers) do
        if DoesEntityExist(ped) then
            SetEntityVisible(ped, true)
        end
    end
    hiddenPlayers = {}
end

-- Thread to continuously hide other players while barbershop is open
CreateThread(function()
    while true do
        if isOpen then
            HideOtherPlayers()
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

-- Camera tracking for head (updates aim every frame)
local BONE_HEAD = 0x796E -- SKEL_Head
CreateThread(function()
    while true do
        if isOpen and camInFrontMode and storeCam and Config.CamTrackFace then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local headCoords = GetPedBoneCoords(ped, BONE_HEAD, 0.0, 0.0, 0.0)
                PointCamAtCoord(storeCam, headCoords.x, headCoords.y, headCoords.z)
            end
        end
        Wait(0)
    end
end)

-- ==========================================
-- CAMERA (in front of player when sitting in chair)
-- ==========================================
local camInFrontMode = false -- true = camera in front of face

local function CreateBarberCam()
    if not currentShop then return end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    storeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamFov(storeCam, Config.CameraSettings.fov or 35.0)
    SetCamActive(storeCam, true)
    RenderScriptCams(true, false, 500, true, true)

    if camInFrontMode then
        -- Camera higher, straight at face (in front of player)
        local h = GetEntityHeading(ped)
        local rad = math.rad(h)
        local dist = Config.CamDistanceFromPlayer or 1.5
        local heightOff = Config.CamHeightOffset or 0.5
        local camX = pedCoords.x - math.sin(rad) * dist
        local camY = pedCoords.y + math.cos(rad) * dist
        local camZ = pedCoords.z + heightOff
        SetCamCoord(storeCam, camX, camY, camZ)
        local aimZ = pedCoords.z + (Config.CamAimAtHeadOffset or 0.18)
        PointCamAtCoord(storeCam, pedCoords.x, pedCoords.y, aimZ)
    else
        local cam = currentShop.cam
        SetCamCoord(storeCam, cam.x, cam.y, cam.z)
        SetCamRot(storeCam, Config.CameraSettings.pitch, 0.0, cam.w, 2)
    end

    SetFocusPosAndVel(pedCoords.x, pedCoords.y, pedCoords.z, 0.0, 0.0, 0.0)
    camOffsetZ = 0.0
end

local function DestroyBarberCam()
    if storeCam then
        DestroyAllCams(true)
        RenderScriptCams(false, true, 500, true, true)
        storeCam = nil
        SetFocusEntity(PlayerPedId())
    end
end

local function MoveBarberCam(direction)
    if not storeCam then return end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    if direction == 'up' then
        camOffsetZ = math.min(camOffsetZ + 0.15, 0.5)
    elseif direction == 'down' then
        camOffsetZ = math.max(camOffsetZ - 0.15, -0.3)
    elseif direction == 'left' then
        local heading = GetEntityHeading(ped) + 15.0
        SetEntityHeading(ped, heading)
    elseif direction == 'right' then
        local heading = GetEntityHeading(ped) - 15.0
        SetEntityHeading(ped, heading)
    elseif direction == 'reset' then
        camOffsetZ = 0.0
        if currentShop and currentShop.coords then
            SetEntityHeading(ped, currentShop.coords.w or 0)
        end
    end

    if camInFrontMode then
        local h = GetEntityHeading(ped)
        local rad = math.rad(h)
        local dist = Config.CamDistanceFromPlayer or 1.5
        local heightOff = Config.CamHeightOffset or 0.5
        local camX = pedCoords.x - math.sin(rad) * dist
        local camY = pedCoords.y + math.cos(rad) * dist
        local camZ = pedCoords.z + heightOff + camOffsetZ
        SetCamCoord(storeCam, camX, camY, camZ)
        local aimZ = pedCoords.z + (Config.CamAimAtHeadOffset or 0.18) + camOffsetZ * 0.5
        PointCamAtCoord(storeCam, pedCoords.x, pedCoords.y, aimZ)
    elseif currentShop and currentShop.cam then
        local cam = currentShop.cam
        SetCamCoord(storeCam, cam.x, cam.y, cam.z + camOffsetZ)
    end
    SetFocusPosAndVel(pedCoords.x, pedCoords.y, pedCoords.z + camOffsetZ, 0.0, 0.0, 0.0)
end

-- ==========================================
-- SAVE/RESTORE
-- ==========================================
local function GetCurrentMakeupFromSkin()
    local skin = nil
    local ok = pcall(function()
        skin = exports['rsg-appearance']:GetCurrentSkinData()
    end)
    if not ok or not skin then return nil end
    local m = {}
    for k, v in pairs({'shadows_t','shadows_op','shadows_id','shadows_c1','blush_t','blush_op','blush_id','blush_c1','lipsticks_t','lipsticks_op','lipsticks_id','lipsticks_c1','lipsticks_c2','eyeliners_t','eyeliners_op','eyeliners_id','eyeliners_c1'}) do
        if skin[v] ~= nil then m[v] = skin[v] end
    end
    return next(m) and m or nil
end

local function GetCurrentSkinData()
    local skin = nil
    local ok = pcall(function()
        skin = exports['rsg-appearance']:GetCurrentSkinData()
    end)
    return ok and type(skin) == 'table' and CopyTable(skin) or {}
end

local function SkinFromBarberStyle(style)
    style = type(style) == 'table' and style or {}
    local hair = type(style.hair) == 'table' and style.hair or {}
    local beard = type(style.beard) == 'table' and style.beard or {}
    local skin = {
        hair = tonumber(hair.model) or 0,
        hair_color = tonumber(hair.color) or 0,
        hair_hashname = hair.hashname,
        beard = tonumber(beard.model) or 0,
        beard_color = tonumber(beard.color) or 0,
        beard_hashname = beard.hashname,
    }
    for key, value in pairs(style.eyebrows or {}) do skin[key] = value end
    for key, value in pairs(style.makeup or {}) do skin[key] = value end
    return skin
end

local function ApplyBarberStyle(style)
    if type(style) ~= 'table' then return end
    local skin = SkinFromBarberStyle(style)
    local ped = PlayerPedId()
    pcall(function() exports['rsg-appearance']:SetHair(ped, skin) end)
    pcall(function() exports['rsg-appearance']:SetBeard(ped, skin) end)
    pcall(function() exports['rsg-appearance']:SetFaceOverlays(ped, skin) end)
    pcall(function() exports['rsg-appearance']:SetCurrentSkinData(skin) end)
end

local function GetCurrentEyebrowsFromSkin()
    local skin = nil
    local ok = pcall(function()
        skin = exports['rsg-appearance']:GetCurrentSkinData()
    end)
    if not ok or not skin then return nil end
    local e = {}
    for _, k in ipairs({'eyebrows_t', 'eyebrows_op', 'eyebrows_id', 'eyebrows_c1'}) do
        if skin[k] ~= nil then e[k] = skin[k] end
    end
    return next(e) and e or nil
end

local function SaveCurrentAppearance(barberStyle)
    originalSkin = SkinFromBarberStyle(barberStyle)
    originalHair = originalSkin.hair_hashname and GetHashKey(originalSkin.hair_hashname) or 0
    originalBeard = originalSkin.beard_hashname and GetHashKey(originalSkin.beard_hashname) or 0
    originalMakeup = CopyTable(type(barberStyle) == 'table' and barberStyle.makeup or {})
    originalEyebrows = CopyTable(type(barberStyle) == 'table' and barberStyle.eyebrows or {})

    print('[RSG-Barbershop] Saved: hair=' .. tostring(originalHair) .. ' beard=' .. tostring(originalBeard))
end

local function RestoreOriginalAppearance()
    local ped = PlayerPedId()
    pcall(function() exports['rsg-appearance']:SetHair(ped, originalSkin or {}) end)
    pcall(function() exports['rsg-appearance']:SetBeard(ped, originalSkin or {}) end)

    -- Restore makeup (women)
    if originalMakeup then
        local ok = pcall(function()
            exports['rsg-appearance']:SetFaceOverlays(ped, originalMakeup)
        end)
        originalMakeup = nil
    end

    -- Restore eyebrows
    if originalEyebrows then
        local ok = pcall(function()
            exports['rsg-appearance']:SetFaceOverlays(ped, originalEyebrows)
        end)
        originalEyebrows = nil
    end

    if originalSkin then
        pcall(function()
            exports['rsg-appearance']:SetCurrentSkinData(CopyTable(originalSkin))
        end)
    end

    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

-- ==========================================
-- APPLY HAIRSTYLE/BEARD
-- ==========================================
local function RemoveHair()
    local ped = PlayerPedId()
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, HAIR_HASH, 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

local function ApplyHair(hashname)
    local ped = PlayerPedId()
    local hash = GetHashKey(hashname)

    print('[RSG-Barbershop] Applying hair: ' .. hashname .. ' (' .. hash .. ')')

    -- Remove current hair
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, HAIR_HASH, 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    Wait(50)

    -- Apply new
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

local function ApplyBeard(hashname)
    local ped = PlayerPedId()
    local hash = GetHashKey(hashname)

    print('[RSG-Barbershop] Applying beard: ' .. hashname .. ' (' .. hash .. ')')

    -- Remove current beard
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, BEARD_HASH, 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    Wait(50)

    -- Apply new
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

local function RemoveBeard()
    local ped = PlayerPedId()
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, BEARD_HASH, 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

-- ==========================================
-- LOAD HAIRSTYLE DATA
-- ==========================================
local function GetHairsDataForGender(isMale)
    local gender = isMale and 'male' or 'female'
    local prefix = isMale and 'M' or 'F'

    local data = {
        hair = {},
        beard = isMale and {} or nil
    }

    -- Load from rsg-appearance
    local hairsList = nil
    local success = pcall(function()
        hairsList = exports['rsg-appearance']:GetHairsList()
    end)

    if not success or not hairsList then
        -- Generate default data
        print('[RSG-Barbershop] Generating default hair data')

        -- Hair
        for i = 1, 30 do
            local styleNum = string.format("%03d", i)
            local style = {
                index = i,
                name = "Hairstyle " .. i,
                colors = {}
            }

            for _, colorSuffix in ipairs(HairColorOrder) do
                local hashname = string.format("CLOTHING_ITEM_%s_HAIR_%s_%s", prefix, styleNum, colorSuffix)
                table.insert(style.colors, {
                    name = HairColorNames[colorSuffix] or colorSuffix,
                    hashname = hashname,
                    hash = GetHashKey(hashname)
                })
            end

            table.insert(data.hair, style)
        end

        -- Beard (men only)
        if isMale then
            for i = 1, 20 do
                local styleNum = string.format("%03d", i)
                local style = {
                    index = i,
                    name = "Beard " .. i,
                    colors = {}
                }

                for _, colorSuffix in ipairs(HairColorOrder) do
                    local hashname = string.format("CLOTHING_ITEM_M_BEARD_%s_%s", styleNum, colorSuffix)
                    table.insert(style.colors, {
                        name = HairColorNames[colorSuffix] or colorSuffix,
                        hashname = hashname,
                        hash = GetHashKey(hashname)
                    })
                end

                table.insert(data.beard, style)
            end
        end

        return data
    end

    -- Transform data from hairs_list
    if hairsList[gender] then
        -- Hair
        if hairsList[gender].hair then
            for styleIdx, colors in pairs(hairsList[gender].hair) do
                local style = {
                    index = styleIdx,
                    name = "Hairstyle " .. styleIdx,
                    colors = {}
                }

                for colorIdx, colorData in pairs(colors) do
                    table.insert(style.colors, {
                        name = HairColorNames[string.match(colorData.hashname or "", "_([^_]+)$")] or ("Color " .. colorIdx),
                        hashname = colorData.hashname,
                        hash = colorData.hash
                    })
                end

                table.insert(data.hair, style)
            end
        end

        -- Beard
        if isMale and hairsList[gender].beard then
            for styleIdx, colors in pairs(hairsList[gender].beard) do
                local style = {
                    index = styleIdx,
                    name = "Beard " .. styleIdx,
                    colors = {}
                }

                for colorIdx, colorData in pairs(colors) do
                    table.insert(style.colors, {
                        name = HairColorNames[string.match(colorData.hashname or "", "_([^_]+)$")] or ("Color " .. colorIdx),
                        hashname = colorData.hashname,
                        hash = colorData.hash
                    })
                end

                table.insert(data.beard, style)
            end
        end
    end

    -- Sort by index
    table.sort(data.hair, function(a, b) return a.index < b.index end)
    if data.beard then
        table.sort(data.beard, function(a, b) return a.index < b.index end)
    end

    return data
end

local function FindCurrentSelection(styles, componentHash, fallbackStyle, fallbackColor)
    local function NormalizeHash(value)
        value = tonumber(value) or 0
        return value < 0 and value + 4294967296 or value
    end

    local targetHash = NormalizeHash(componentHash)
    if targetHash ~= 0 then
        for stylePosition, style in ipairs(styles or {}) do
            for colorPosition, color in ipairs(style.colors or {}) do
                local colorHash = color.hash or (color.hashname and GetHashKey(color.hashname)) or 0
                if NormalizeHash(colorHash) == targetHash then
                    return {
                        styleIndex = stylePosition - 1,
                        colorIndex = colorPosition - 1,
                        hashname = color.hashname,
                        absent = false
                    }
                end
            end
        end
    end

    local styleIndex = 0
    for stylePosition, style in ipairs(styles or {}) do
        if tonumber(style.index) == tonumber(fallbackStyle) then
            styleIndex = stylePosition - 1
            break
        end
    end

    local colors = styles and styles[styleIndex + 1] and styles[styleIndex + 1].colors or {}
    local colorIndex = math.max(0, math.min(#colors - 1, (tonumber(fallbackColor) or 1) - 1))
    local color = colors[colorIndex + 1]
    local absent = targetHash == 0 and (tonumber(fallbackStyle) or 0) <= 0

    return {
        styleIndex = styleIndex,
        colorIndex = colorIndex,
        hashname = color and color.hashname or nil,
        absent = absent
    }
end

-- ==========================================
-- OPEN/CLOSE
-- ==========================================
function OpenBarbershop(shopIndex, chairEntity)
    if isOpen then return end
    if not IsBarbershopOpen() then return end
    LoadSharedUiScale()

    local shop = Config.Barbershops[shopIndex]
    if not shop then return end

    currentShop = shop
    isOpen = true
    camInFrontMode = (chairEntity ~= nil)

    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local isMale = model == GetHashKey('mp_male')

    savedPosition = GetEntityCoords(ped)
    savedHeading = GetEntityHeading(ped)

    if chairEntity and DoesEntityExist(chairEntity) then
        -- Like in spooni-interactions: TaskStartScenarioAtPosition on chair without manual offsets
        local objCoords = GetEntityCoords(chairEntity)
        local objHeading = GetEntityHeading(chairEntity)
        local off = Config.BarberChairOffset or vec4(0, 0, 0.5, 180)
        local r = math.rad(objHeading)
        local cosr = math.cos(r)
        local sinr = math.sin(r)
        local x = (off.x or 0) * cosr - (off.y or 0) * sinr + objCoords.x
        local y = (off.y or 0) * cosr + (off.x or 0) * sinr + objCoords.y
        local z = (off.z or 0.5) + objCoords.z
        local h = (off.w or off[4] or 180) + objHeading

        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, true)
        local scenario = Config.BarberScenarios and Config.BarberScenarios.male or 'PROP_PLAYER_BARBER_SEAT'
        TaskStartScenarioAtPosition(ped, GetHashKey(scenario), x, y, z, h, -1, false, true)
        Wait(2000)
    else
        -- Legacy: teleport to coords
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(10) end
        FreezeEntityPosition(ped, true)
        SetEntityCoordsNoOffset(ped, shop.coords.x, shop.coords.y, shop.coords.z, false, false, false)
        SetEntityHeading(ped, shop.coords.w)
        Wait(300)
        DoScreenFadeIn(500)
        while not IsScreenFadedIn() do Wait(10) end
    end

    local PlayerData = RSGCore.Functions.GetPlayerData()
    local barberStyle = PlayerData.metadata and PlayerData.metadata.barberStyle or {}
    currentPaidBarberStyle = DeepCopy(barberStyle)
    SaveCurrentAppearance(barberStyle)
    HideOtherPlayers()
    CreateBarberCam()

    -- Get data
    local hairsData = GetHairsDataForGender(isMale)
    local currentSelections = {
        hair = FindCurrentSelection(hairsData.hair, originalHair, originalSkin.hair, originalSkin.hair_color)
    }
    if currentSelections.hair and currentSelections.hair.hashname then
        originalHair = GetHashKey(currentSelections.hair.hashname)
    end
    if isMale then
        currentSelections.beard = FindCurrentSelection(hairsData.beard, originalBeard, originalSkin.beard, originalSkin.beard_color)
        if currentSelections.beard and currentSelections.beard.hashname then
            originalBeard = GetHashKey(currentSelections.beard.hashname)
        end
    end
    local makeupData = (not isMale) and (MakeupData or {}) or nil
    local currentMakeup = (not isMale) and CopyTable(originalMakeup) or nil
    local eyebrowsData = EyebrowsData and EyebrowsData.eyebrows or { t_min = 1, t_max = 22, op_max = 100, id_max = 25, c1_max = 64 }
    local currentEyebrows = CopyTable(originalEyebrows)

    -- Get money
    local money = PlayerData.money.cash or 0

    RSGCore.Functions.TriggerCallback('rsg-barbershop:server:getLooks', function(savedLooks)
        if not isOpen then return end
        looksData = type(savedLooks) == 'table' and savedLooks or {}
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            isMale = isMale,
            money = money,
            shopName = shop.name,
            hairsData = hairsData,
            currentSelections = currentSelections,
            makeupData = makeupData,
            currentMakeup = currentMakeup,
            eyebrowsData = eyebrowsData,
            currentEyebrows = currentEyebrows,
            looks = looksData,
            currentBarberStyle = currentPaidBarberStyle,
            prices = Config.Prices,
            scale = uiScale,
            scaleModifier = tonumber(Config.ScaleModifier) or 0
        })
    end)
end

function CloseBarbershop(purchased)
    if not isOpen then return end

    isOpen = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    LeavePrivateBucket()

    DestroyBarberCam()

    -- Show other players
    ShowOtherPlayers()

    -- Always restore the session baseline. A successful purchase updates only
    -- the paid fields in this cache before the shop closes.
    RestoreOriginalAppearance()

    local ped = PlayerPedId()
    ClearPedTasks(ped)

    -- Standing up animation
    local standCfg = Config.BarberStandAnim
    if standCfg and standCfg.dict and standCfg.anim then
        local dict = standCfg.dict
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end
        if HasAnimDictLoaded(dict) then
            local dur = standCfg.duration or 2000
            TaskPlayAnim(ped, dict, standCfg.anim, 8.0, -8.0, dur, 0, 0, false, false, false)
            Wait(dur)
        end
    end

    FreezeEntityPosition(ped, false)

    -- Return to saved position
    if savedPosition then
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(10) end

        SetEntityCoordsNoOffset(ped, savedPosition.x, savedPosition.y, savedPosition.z, false, false, false)
        SetEntityHeading(ped, savedHeading)

        Wait(200)
        DoScreenFadeIn(500)
    end

    savedPosition = nil
    savedHeading = nil
    currentShop = nil
    originalHair = nil
    originalBeard = nil
    originalMakeup = nil
    originalEyebrows = nil
    originalSkin = nil
    looksData = {}
    currentPaidBarberStyle = nil
end

-- ==========================================
-- NUI CALLBACKS
-- ==========================================
RegisterNUICallback('setUiScale', function(data, cb)
    SaveSharedUiScale(data and data.scale)
    cb({ scale = uiScale })
end)

RegisterNUICallback('previewHair', function(data, cb)
    if data.remove then
        RemoveHair()
    elseif data.hashname then
        ApplyHair(data.hashname)
    end
    cb('ok')
end)

RegisterNUICallback('previewBeard', function(data, cb)
    if data.hashname then
        ApplyBeard(data.hashname)
    elseif data.remove then
        RemoveBeard()
    end
    cb('ok')
end)

RegisterNUICallback('previewMakeup', function(data, cb)
    if not data or type(data) ~= 'table' then cb('ok') return end
    local ped = PlayerPedId()
    local ok = pcall(function()
        exports['rsg-appearance']:SetFaceOverlays(ped, data)
    end)
    cb('ok')
end)

RegisterNUICallback('previewEyebrows', function(data, cb)
    if not data or type(data) ~= 'table' then cb('ok') return end
    local ped = PlayerPedId()
    local ok = pcall(function()
        exports['rsg-appearance']:SetFaceOverlays(ped, data)
    end)
    cb('ok')
end)

RegisterNUICallback('buyStyle', function(data, cb)
    -- Send to server for purchase
    TriggerServerEvent('rsg-barbershop:server:buyStyle', data)
    cb('ok')
end)

RegisterNUICallback('previewLook', function(data, cb)
    local index = tonumber(data and data.index) or 0
    local style = index == 0 and currentPaidBarberStyle or (looksData[index] and looksData[index].style)
    if type(style) ~= 'table' then cb('error') return end
    ApplyBarberStyle(style)
    cb('ok')
end)

RegisterNUICallback('saveLook', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-barbershop:server:saveLook', function(result)
        if not result or not result.success then
            SendNUIMessage({ action = 'purchaseFailed', reason = result and result.reason or 'Unable to save look' })
            cb('error')
            return
        end
        looksData = result.looks or looksData
        SendNUIMessage({ action = 'looksUpdated', looks = looksData, selectedIndex = result.selectedIndex or #looksData })
        cb('ok')
    end)
end)

RegisterNUICallback('deleteLook', function(data, cb)
    local index = (tonumber(data and data.index) or 0) - 1
    RSGCore.Functions.TriggerCallback('rsg-barbershop:server:deleteLook', function(result)
        if not result or not result.success then
            SendNUIMessage({ action = 'purchaseFailed', reason = result and result.reason or 'Unable to delete look' })
            cb('error')
            return
        end
        looksData = result.looks or {}
        SendNUIMessage({ action = 'looksUpdated', looks = looksData, selectedIndex = result.selectedIndex or 0 })
        cb('ok')
    end, index)
end)

RegisterNUICallback('applyLook', function(data, cb)
    local uiIndex = tonumber(data and data.index) or 0
    if uiIndex == 0 then
        ApplyBarberStyle(currentPaidBarberStyle)
        cb('ok')
        return
    end
    RSGCore.Functions.TriggerCallback('rsg-barbershop:server:applyLook', function(result)
        if not result or not result.success then
            SendNUIMessage({ action = 'purchaseFailed', reason = result and result.reason or 'Unable to apply look' })
            cb('error')
            return
        end
        currentPaidBarberStyle = DeepCopy(result.style)
        ApplyBarberStyle(currentPaidBarberStyle)
        SaveCurrentAppearance(currentPaidBarberStyle)
        SendNUIMessage({ action = 'lookApplied', style = currentPaidBarberStyle })
        cb('ok')
    end, uiIndex - 1)
end)

RegisterNUICallback('moveCamera', function(data, cb)
    MoveBarberCam(data.direction)
    cb('ok')
end)

RegisterNUICallback('closeShop', function(data, cb)
    CloseBarbershop(data.purchased or false)
    cb('ok')
end)

-- ==========================================
-- SERVER EVENTS
-- ==========================================
RegisterNetEvent('rsg-barbershop:client:purchaseSuccess', function(newMoney, hairData, beardData, eyebrowsData, makeupData, barberStyle)
    local skin = type(barberStyle) == 'table' and SkinFromBarberStyle(barberStyle) or GetCurrentSkinData()

    local function UpdateComponent(data, component, color, hashnameKey, pattern)
        if not data then return end
        if data.remove then
            skin[component] = 0
            skin[color] = 0
            skin[hashnameKey] = nil
            return
        end
        if not data.hashname then return end
        skin[hashnameKey] = data.hashname
        local styleNumber, colorSuffix = string.match(data.hashname, pattern)
        if styleNumber then
            skin[component] = tonumber(styleNumber) or skin[component]
            skin[color] = GetColorIndexFromSuffix(colorSuffix) or skin[color]
        end
    end

    UpdateComponent(hairData, 'hair', 'hair_color', 'hair_hashname', 'CLOTHING_ITEM_[MF]_HAIR_(%d+)_(.+)')
    UpdateComponent(beardData, 'beard', 'beard_color', 'beard_hashname', 'CLOTHING_ITEM_M_BEARD_(%d+)_(.+)')

    for key, value in pairs(eyebrowsData or {}) do skin[key] = value end
    for key, value in pairs(makeupData or {}) do skin[key] = value end

    if hairData then
        originalHair = hairData.remove and 0 or (hairData.hashname and GetHashKey(hairData.hashname) or originalHair)
    end
    if beardData then
        originalBeard = beardData.remove and 0 or (beardData.hashname and GetHashKey(beardData.hashname) or originalBeard)
    end
    if eyebrowsData then
        originalEyebrows = CopyTable(originalEyebrows or {})
        for key, value in pairs(eyebrowsData) do originalEyebrows[key] = value end
    end
    if makeupData then
        originalMakeup = CopyTable(originalMakeup or {})
        for key, value in pairs(makeupData) do originalMakeup[key] = value end
    end
    originalSkin = CopyTable(skin)
    if type(barberStyle) == 'table' then currentPaidBarberStyle = DeepCopy(barberStyle) end

    pcall(function()
        exports['rsg-appearance']:SetCurrentSkinData(skin)
    end)

    SendNUIMessage({
        action = 'purchaseSuccess',
        newMoney = newMoney,
        barberStyle = currentPaidBarberStyle
    })

    print('[RSG-Barbershop] Purchase successful!')
end)

RegisterNetEvent('rsg-barbershop:client:purchaseFailed', function(reason)
    SendNUIMessage({
        action = 'purchaseFailed',
        reason = reason
    })
end)

RegisterNetEvent('rsg-barbershop:client:openShop', function(shopIndex, chairEntity)
    OpenBarbershop(shopIndex, chairEntity)
end)

-- ==========================================
-- OX_TARGET on barber chairs (p_barberchair01x, 02x, 03x)
-- ==========================================
CreateThread(function()
    while RSGCore == nil do
        Wait(100)
    end
    if GetResourceState('ox_target') ~= 'started' then
        print('[RSG-Barbershop] ox_target not found, barbershop unavailable')
        return
    end
    Wait(1000)

    local barberOptions = {
        {
            name = 'barbershop_use',
            icon = 'fas fa-cut',
            label = 'Get a haircut',
            distance = 2.0,
            canInteract = function()
                return not isOpen and IsBarbershopOpen()
            end,
            onSelect = function(data)
                local entity = data.entity
                if not entity or not DoesEntityExist(entity) then return end

                local chairCoords = GetEntityCoords(entity)
                local closestIdx = 1
                local closestDist = 999999.0
                for i, shop in ipairs(Config.Barbershops or {}) do
                    local sc = shop.coords
                    local d = #(chairCoords - vector3(sc.x, sc.y, sc.z))
                    if d < closestDist then
                        closestDist = d
                        closestIdx = i
                    end
                end
                EnterPrivateBucket()
                TriggerEvent('rsg-barbershop:client:openShop', closestIdx, entity)
            end,
        },
    }
    for _, model in ipairs({'p_barberchair01x', 'p_barberchair02x', 'p_barberchair03x'}) do
        exports.ox_target:addModel(model, barberOptions)
    end

    -- Blips
    local barbershopBlips = {}
    local redBlipModifier = GetHashKey('BLIP_MODIFIER_MP_COLOR_10')
    local shopsOpen = IsBarbershopOpen()
    for i, shop in ipairs(Config.Barbershops or {}) do
        local blip = BlipAddForCoords(1664425300, shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, GetHashKey('blip_shop_barber'), true)
        SetBlipScale(blip, 0.2)
        SetBlipName(blip, shop.name)
        barbershopBlips[i] = blip

        if not shopsOpen then
            Citizen.InvokeNative(0x662D364ABF16DE2F, blip, redBlipModifier)
        end
    end

    while true do
        Wait(5000)
        local currentlyOpen = IsBarbershopOpen()
        if currentlyOpen ~= shopsOpen then
            shopsOpen = currentlyOpen
            for _, blip in ipairs(barbershopBlips) do
                if shopsOpen then
                    Citizen.InvokeNative(0xB059D7BD3D78C16F, blip, redBlipModifier)
                else
                    Citizen.InvokeNative(0x662D364ABF16DE2F, blip, redBlipModifier)
                end
            end
        end
    end
end)

-- ==========================================
-- CLEANUP ON STOP
-- ==========================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        LeavePrivateBucket()
        if isOpen then
            CloseBarbershop(false)
        end
        ShowOtherPlayers()
    end
end)
-- ==========================================
-- CONTROLS
-- ==========================================
CreateThread(function()
    while true do
        Wait(0)
        if isOpen then
            DisableAllControlActions(0)
            if IsControlJustPressed(0, 0x156F7119) then -- Backspace
                CloseBarbershop(false)
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isOpen then
            CloseBarbershop(false)
        end
    end
end)
