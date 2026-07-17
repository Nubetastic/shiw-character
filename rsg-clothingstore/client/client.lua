local RSGCore = exports['rsg-core']:GetCoreObject()

local isStoreOpen = false
local currentStore = nil
local previewedItem = nil
local originalClothes = {}
local storeCam = nil
local camOffsetZ = 0.0
local savedPosition = nil
local savedHeading = nil
local currentCloakroom = nil
local sessionMode = 'shop'
local openingOutfit = {}
local previewOutfit = {}
local selectedByCategory = {}
local purchaseCart = {}
local purchaseTotal = 0
local boughtData = {}
local boughtLookup = {}
local outfitsData = {}
local sessionBusy = false
local temporaryOutfit = {}
local temporarySelectedByCategory = {}
local temporaryPurchaseCart = {}
local previewApplyTokens = {}
local uiScale = 1.0
local storeTargetZones = {}

local function DeepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do copy[DeepCopy(key, seen)] = DeepCopy(item, seen) end
    return copy
end

local function ClampUiScale(scale)
    return math.max(0.25, math.min(3.0, tonumber(scale) or 1.0))
end

local function LoadSavedStoreScale()
    local playerData = RSGCore.Functions.GetPlayerData()
    local hudScale = playerData and playerData.metadata and playerData.metadata.hudScale
    uiScale = ClampUiScale(type(hudScale) == 'table' and hudScale.rsg_clothingstore or 1.0)
end

local function SaveStoreScale(scale)
    uiScale = ClampUiScale(scale)
    local playerData = RSGCore.Functions.GetPlayerData()
    local savedScales = playerData and playerData.metadata and playerData.metadata.hudScale
    savedScales = type(savedScales) == 'table' and DeepCopy(savedScales) or {}
    savedScales.rsg_clothingstore = uiScale
    TriggerServerEvent('RSGCore:Server:SetMetaData', 'hudScale', savedScales)
end

local function CancelPendingItemPreviews()
    for category, token in pairs(previewApplyTokens) do
        previewApplyTokens[category] = token + 1
    end
end

local function NormalizeHash(value)
    if type(value) == 'number' then return value end
    if type(value) ~= 'string' or value == '' or value == '_' then return 0 end
    return tonumber(value:gsub('^0[xX]', ''), 16) or tonumber(value) or 0
end

local function BuildItemKey(item, isMale)
    if type(item) ~= 'table' then return '' end
    if item.key and item.key ~= '' then return item.key end
    local itemIsMale = item.isMale
    if itemIsMale == nil then itemIsMale = isMale end
    local sex = itemIsMale and 'male' or 'female'
    local category = item.category or item._c or 'unknown'
    if item.remove or item._remove then
        return table.concat({ sex, category, 'remove' }, ':'):lower()
    end
    local kaf = item.Kaf or item.kaf or item._kaf or 'Classic'
    local hash = NormalizeHash(item.Hash or item.hash or item._h)
    if kaf == 'Ped' then
        local tints = item.tints or item._tints or { item.palette1 or 0, item.palette2 or 0, item.palette3 or 0 }
        return table.concat({
            sex, category, kaf,
            item.Draw or item.draw or item._draw or '',
            item.alb or item.albedo or item._alb or '',
            item.norm or item.normal or item._norm or '',
            tostring(item.mat or item.material or item._mat or 0),
            item.pal or item.palette or item._p or 'tint_generic_clean',
            tostring(tints[1] or 0), tostring(tints[2] or 0), tostring(tints[3] or 0)
        }, ':'):lower()
    end
    return table.concat({ sex, category, kaf, string.format('%08X', hash & 0xFFFFFFFF) }, ':'):lower()
end

local function NormalizeClientItem(item, isMale)
    if type(item) ~= 'table' then return nil end
    local category = item.category or item._c
    if not category then return nil end
    local tints = item.tints or item._tints
    local itemIsMale = item.isMale
    if itemIsMale == nil then itemIsMale = isMale end
    local normalized = {
        key = BuildItemKey(item, isMale),
        name = item.name or item.label or category,
        category = category,
        hash = NormalizeHash(item.Hash or item.hash or item._h),
        model = tonumber(item.model or item._m) or 0,
        texture = tonumber(item.texture or item._t) or 1,
        palette = item.pal or item.palette or item._p or 'tint_generic_clean',
        tints = {
            tonumber(tints and tints[1] or item.palette1) or 0,
            tonumber(tints and tints[2] or item.palette2) or 0,
            tonumber(tints and tints[3] or item.palette3) or 0,
        },
        kaf = item.Kaf or item.kaf or item._kaf or 'Classic',
        draw = item.Draw or item.draw or item._draw or '',
        albedo = item.alb or item.albedo or item._alb or '',
        normal = item.norm or item.normal or item._norm or '',
        material = item.mat or item.material or item._mat or 0,
        isMale = itemIsMale,
        remove = item.remove == true or item._remove == true,
    }
    if normalized.hash == 0 and normalized.kaf == 'Ped' and normalized.draw ~= '' and normalized.draw ~= '_' then
        normalized.hash = GetHashKey(normalized.draw)
    end
    return normalized
end

local function BuildBoughtLookup()
    boughtLookup = {}
    for _, list in pairs(boughtData or {}) do
        if type(list) == 'table' then
            for _, item in ipairs(list) do
                if type(item) == 'table' and item.key then boughtLookup[item.key] = true end
            end
        end
    end
end

local function GetBoughtKeys()
    local keys = {}
    for key in pairs(boughtLookup) do keys[#keys + 1] = key end
    return keys
end

local function GetEquippedKeys(outfit, isMale)
    local keys = {}
    for category, item in pairs(outfit or {}) do
        if type(item) == 'table' then
            local copy = DeepCopy(item)
            copy.category = copy.category or category
            local key = BuildItemKey(copy, isMale)
            if key ~= '' then keys[category] = key end
        end
    end
    return keys
end

local function HasSelections()
    return next(selectedByCategory) ~= nil
end

local function RecalculateCart()
    purchaseTotal = 0
    for _, item in pairs(purchaseCart) do purchaseTotal = purchaseTotal + (tonumber(item.price) or 0) end
    SendNUIMessage({
        action = 'cartUpdated',
        total = purchaseTotal,
        buttonLabel = purchaseTotal > 0 and 'Buy' or 'Apply',
        canCommit = purchaseTotal > 0 or HasSelections(),
    })
end

local function ApplyCompleteOutfit(outfit)
    CancelPendingItemPreviews()
    TriggerEvent('rsg-appearance:client:ApplyCompleteOutfit', DeepCopy(outfit or {}), PlayerPedId())
end

-- What happens if you change parameter NPCs (mp_male)
local CategoryComponentHash = {
    ['hats'] = 0x9925C067,
    ['coats'] = 0xE06D47B7,
    ['coats_closed'] = 0xE06D47B7,
    ['vests'] = 0x485EE834,
    ['shirts_full'] = 0x0662AC34,
    ['shirts'] = 0x0662AC34,
    ['pants'] = 0xB6B6122D,
    ['boots'] = 0x777EC6EF,
    ['chaps'] = 0x3107499B,
    ['gloves'] = 0xEABE0032,
    ['neckwear'] = 0x5FC29285,
    ['suspenders'] = 0x877A2CF7,
    ['belts'] = 0xA6D134C6,
    ['belt_buckles'] = 0xDA0E2C55,
    ['beltbuckle'] = 0xDA0E2C55,
    ['satchels'] = 0x94504D26,
    ['gunbelts'] = 0x9B2C8B89,
    ['holsters_left'] = 0x7A6BBD0B,
    ['holsters_right'] = 0x0B3966C9,
    ['accessories'] = 0x79D7DF96,
    ['masks'] = 0x7505EF42,
    ['eyewear'] = 0x5E47CA6F,
    ['cloaks'] = 0x3C1A74CD,
    ['ponchos'] = 0xAF14310B,
    ['skirts'] = 0x1D4C528A,
    ['loadouts'] = 0x83887E88,
    ['spurs'] = 0x18729F39,
    ['gauntlets'] = 0x91CE9B20,
    ['neckties'] = 0x7A96FACA,
    ['dresses'] = 0x0662AC34,
    ['corsets'] = 0x485EE834,
    ['badges'] = 0x79D7DF96,
    ['hair_accessories'] = 0x79D7DF96,
    ['boot_accessories'] = 0x18729F39,
    ['necklaces'] = 0x79D7DF96,
    ['rings_rh'] = 0x79D7DF96,
    ['rings_lh'] = 0x79D7DF96,
    ['bracelets'] = 0x79D7DF96,
    ['earrings'] = 0x72E6EF74,  -- earrings (for males; and other things as equals)
    -- Default - appearance update (rdr2mods/jo_libs)
    ['jewelry_rings_right'] = 0x7A6BBD0B,
    ['jewelry_rings_left'] = 0xF16A1D23,
    ['jewelry_bracelets'] = 0x7BC10759,
    ['talisman_belt'] = 0x1AECF7DC,
}

-- What happens if you change (how other transitions appear when changed or added)
local AccessoryCategories = {
    ['accessories'] = true, ['badges'] = true, ['hair_accessories'] = true,
    ['necklaces'] = true, ['rings_rh'] = true, ['rings_lh'] = true, ['bracelets'] = true,
    ['earrings'] = true,
    ['jewelry_rings_right'] = true, ['jewelry_rings_left'] = true, ['jewelry_bracelets'] = true,
    ['talisman_belt'] = true,
}

-- What happens if you change this: male-specific to config; and female - changes to clothes_list (category accessories, ped_type female)
-- male 0x790DCD14, 0x17920A1E, 0x29A9AE4D, 0x5B5591A4 -> female appearance
local FemaleAccessoryHashOverride = {
    [0x790DCD14] = 0x54BE33DF,  -- value 1 (???)
    [0x17920A1E] = 0x56FD1F1F,  -- value 2 (???)
    [0x29A9AE4D] = 0x58B62291,  -- value 3 (???)
    [0x5B5591A4] = 0x5D34DEB3,  -- value 4 (???)
}

local function GetComponentHashForPed(ped, category)
    return CategoryComponentHash[category]
end

-- What happens if you change color/TINT (donât forget!)
local CategoryTintHash = {
    ['hats'] = 0x9925C067,
    ['shirts_full'] = 0x2026C46D,
    ['shirts'] = 0x2026C46D,
    ['pants'] = 0x1D4C528A,
    ['boots'] = 0x777EC6EF,
    ['vests'] = 0x485EE834,
    ['coats'] = 0xE06D30CE,
    ['coats_closed'] = 0x662AC34,
    ['gloves'] = 0xEABE0032,
    ['neckwear'] = 0x7A96FACA,
    ['neckties'] = 0x7A96FACA,
    ['masks'] = 0x7505EF42,
    ['eyewear'] = 0x5F1BE9EC,
    ['gunbelts'] = 0xF1542D11,
    ['satchels'] = 0x94504D26,
    ['suspenders'] = 0x877A2CF7,
    ['chaps'] = 0x3107499B,
    ['spurs'] = 0x18729F39,
    ['cloaks'] = 0x3C1A74CD,
    ['ponchos'] = 0xAF14310B,
    ['skirts'] = 0x1D4C528A,
    ['belts'] = 0xA6D134C6,
    ['belt_buckles'] = 0xDA0E2C55,
    ['dresses'] = 0x0662AC34,
    ['corsets'] = 0x485EE834,
    ['loadouts'] = 0x83887E88,
    ['gauntlets'] = 0x91CE9B20,
    ['holsters_left'] = 0x7A6BBD0B,
    ['holsters_right'] = 0x0B3966C9,
    ['accessories'] = 0x79D7DF96,
    ['badges'] = 0x79D7DF96,
    ['boot_accessories'] = 0x18729F39,
    ['earrings'] = 0x72E6EF74,
    ['talisman_belt'] = 0x1AECF7DC,
}

-- For visualization purposes (how in rsg-appearance)
local ConflictingCategories = {
    ['coats'] = 'coats_closed',
    ['coats_closed'] = 'coats',
}

-- ==========================================
-- BUCKET
-- ==========================================
local function GetNearestCloakroom()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local nearestDist = 9999
    local nearestRoom = Config.Cloakrooms[1]
    
    for _, room in ipairs(Config.Cloakrooms) do
        local dist = #(playerCoords - vector3(room.coords.x, room.coords.y, room.coords.z))
        if dist < nearestDist then
            nearestDist = dist
            nearestRoom = room
        end
    end
    
    return nearestRoom
end

local function TeleportToRoom()
    local ped = PlayerPedId()
    local room = GetNearestCloakroom()
    currentCloakroom = room
    
    savedPosition = GetEntityCoords(ped)
    savedHeading = GetEntityHeading(ped)
    
    -- desired appearance in changing (change to previous in main ones)
    TriggerEvent('rsg-horses:client:DespawnForClothingStore')
    
    local playerId = GetPlayerServerId(PlayerId())
    TriggerServerEvent('rsg-clothingstore:server:setPrivateBucket', playerId)
    
    -- What happens when you synchronize with resync applied to appearance (rsg-appearance)
    LocalPlayer.state:set('isInClothingStore', true, true)
    LocalPlayer.state:set('inClothingStore', true, true)
    
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    Wait(200)
    
    RequestCollisionAtCoord(room.coords.x, room.coords.y, room.coords.z)
    
    SetEntityCoords(ped, room.coords.x, room.coords.y, room.coords.z, false, false, false, false)
    SetEntityHeading(ped, room.coords.w)
    
    local timeout = 0
    while not HasCollisionLoadedAroundEntity(ped) and timeout < 200 do 
        Wait(10) 
        timeout = timeout + 1
    end
    
    Wait(500)
    
    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do Wait(10) end
end

local function TeleportBack()
    if not savedPosition then return end
    
    local ped = PlayerPedId()
    
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    Wait(200)
    
    TriggerServerEvent('rsg-clothingstore:server:setNormalBucket')
    
    -- What happens when updating appearance to synchronize with resync
    LocalPlayer.state:set('isInClothingStore', false, true)
    LocalPlayer.state:set('inClothingStore', false, true)
    
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(savedPosition.x, savedPosition.y, savedPosition.z)
    
    SetEntityCoordsNoOffset(ped, savedPosition.x, savedPosition.y, savedPosition.z, false, false, false)
    SetEntityHeading(ped, savedHeading)
    
    local timeout = 0
    while not HasCollisionLoadedAroundEntity(ped) and timeout < 100 do 
        Wait(10)
        timeout = timeout + 1
    end
    
    Wait(300)
    
    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do Wait(10) end
    
    Wait(100)
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    
    savedPosition = nil
    savedHeading = nil
    currentCloakroom = nil
end

-- ==========================================
-- Appearance
-- ==========================================
local function CreateStoreCam()
    if not currentCloakroom then return end
    
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local cam = currentCloakroom.cam
    
    storeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(storeCam, cam.x, cam.y, cam.z)
    SetCamRot(storeCam, -4.0, 0.0, cam.w or 0.0, 2)
    SetCamFov(storeCam, 35.0)
    SetCamActive(storeCam, true)
    RenderScriptCams(true, false, 500, true, true)
    
    SetFocusPosAndVel(pedCoords.x, pedCoords.y, pedCoords.z, 0.0, 0.0, 0.0)
    camOffsetZ = 0.0
end

local function DestroyStoreCam()
    if storeCam then
        DestroyAllCams(true)
        RenderScriptCams(false, true, 500, true, true)
        storeCam = nil
        SetFocusEntity(PlayerPedId())
    end
end

local function MoveStoreCam(direction)
    if not storeCam or not currentCloakroom then return end
    
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local cam = currentCloakroom.cam
    
    if direction == 'up' then
        camOffsetZ = math.min(camOffsetZ + 0.3, 1.5)
    elseif direction == 'down' then
        camOffsetZ = math.max(camOffsetZ - 0.3, -0.8)
    elseif direction == 'left' then
        SetEntityHeading(ped, GetEntityHeading(ped) + 15.0)
    elseif direction == 'right' then
        SetEntityHeading(ped, GetEntityHeading(ped) - 15.0)
    elseif direction == 'reset' then
        camOffsetZ = 0.0
        if currentCloakroom then
            SetEntityHeading(ped, currentCloakroom.coords.w)
        end
    end
    
    SetCamCoord(storeCam, cam.x, cam.y, cam.z + camOffsetZ)
    SetFocusPosAndVel(pedCoords.x, pedCoords.y, pedCoords.z + camOffsetZ, 0.0, 0.0, 0.0)
end

-- ==========================================
-- Preview/appearance preview
-- ==========================================
local function SaveCurrentClothes()
    originalClothes = {}
    local ped = PlayerPedId()
    
    for category, hash in pairs(CategoryComponentHash) do
        local compHash = GetComponentHashForPed(ped, category) or hash
        local drawable = Citizen.InvokeNative(0x77BA37622E22023B, ped, compHash)
        if drawable then
            originalClothes[category] = { hash = hash, drawable = drawable }
        end
    end
end

-- Recalling that requires all changes in stock
local function RestoreSlotToOriginal(category)
    local ped = PlayerPedId()
    local compHash = GetComponentHashForPed(ped, category) or CategoryComponentHash[category]
    if not compHash then return end
    
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, compHash, 0)
    if ConflictingCategories and ConflictingCategories[category] then
        local conflictCat = ConflictingCategories[category]
        local conflictHash = CategoryComponentHash[conflictCat]
        if conflictHash then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, conflictHash, 0)
        end
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(conflictCat), 0)
    end
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(category), 0)
    
    if originalClothes[category] and originalClothes[category].drawable and originalClothes[category].drawable ~= 0 then
        local orig = originalClothes[category]
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, compHash, orig.drawable, true, true, false)
    end
    
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

-- Tagging letting show previous for appearance and changes
local function RestoreOriginalClothes()
    ApplyCompleteOutfit(openingOutfit)
    previewedItem = nil
end

-- ==========================================
-- What happens if review items PHOTO?
-- ==========================================
local function ApplyClothingItem(item)
    if not item then return end

    item.Kaf = item.Kaf or item.kaf or item._kaf
    item.Hash = item.Hash or item.hash or item._h
    item.Draw = item.Draw or item.draw or item._draw
    item.alb = item.alb or item.albedo or item._alb
    item.norm = item.norm or item.normal or item._norm
    item.mat = item.mat or item.material or item._mat
    item.pal = item.pal or item.palette or item._p
    local existingTints = item.tints or item._tints
    if existingTints then
        item.palette1 = item.palette1 or existingTints[1]
        item.palette2 = item.palette2 or existingTints[2]
        item.palette3 = item.palette3 or existingTints[3]
    end
    
    local ped = PlayerPedId()
    local category = item.category

    if item.Kaf == "BodyComponent" then
        local bh = item.Hash
        if type(bh) == "string" then bh = tonumber(bh, 16) end
        if bh and bh ~= 0 then
            Citizen.InvokeNative(0x1902C4CFCC5BE57C, ped, bh)
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        end
        return
    end

    local compHash = GetComponentHashForPed(ped, category) or CategoryComponentHash[category]
    
    if not compHash then
        print('[RSG-ClothingStore] Unknown category: ' .. tostring(category))
        return
    end
    
    -- What happening when observing for normal (coats/coats_closed)
    if ConflictingCategories and ConflictingCategories[category] then
        local conflictCat = ConflictingCategories[category]
        local conflictHash = CategoryComponentHash[conflictCat]
        if conflictHash then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, conflictHash, 0)
        end
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(conflictCat), 0)
        Wait(30)
    end
    
    -- What happens when monitor these changes (how is appearance item) - and Classic tagging guaranteed here
    if item.Kaf == "Classic" and AccessoryCategories[category] then
        local preHash = item.Hash
        if type(preHash) == "string" then preHash = tonumber(preHash, 16) end
        if preHash and preHash ~= 0 then
            local useHash = (not IsPedMale(ped) and FemaleAccessoryHashOverride[preHash]) or preHash
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, useHash)
            Wait(400)
        end
    end

    -- Denormalizing appearance (how are changes applied - while during last worth)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, compHash, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(category), 0)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    Wait(50)
    
    if item.Kaf == "Classic" then
        -- These CLASSIC values - overwrite of untouchable is tint!
        local hash = item.Hash
        if type(hash) == "string" then
            hash = tonumber(hash, 16)
        end
        -- Other values: wrong parameters while still worth it (out of reason and ??.)
        if not IsPedMale(ped) and AccessoryCategories[category] and FemaleAccessoryHashOverride[hash] then
            hash = FemaleAccessoryHashOverride[hash]
        end
        
        if hash and hash ~= 0 then
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
            local t = 0
            while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t < 100 do Wait(20) t = t + 1 end
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)

            -- What small change â TINT from CLASSIC!
            -- No rules happening at all
        end
    else
        -- What PED appearance - frequent appearance are tint
        -- Switching several types - what now the look at combinations (mostly here COMBOCOAT from ?.)
        local hashesToRequest = {}
        if item.Draw and item.Draw ~= "" and item.Draw ~= "_" then table.insert(hashesToRequest, GetHashKey(item.Draw)) end
        if item.alb and item.alb ~= "" then table.insert(hashesToRequest, GetHashKey(item.alb)) end
        if item.norm and item.norm ~= "" then table.insert(hashesToRequest, GetHashKey(item.norm)) end
        if item.mat and item.mat ~= 0 and item.mat ~= "" then
            local m = item.mat
            if type(m) == "string" then m = m:sub(1,2) == "0x" and tonumber(m,16) or GetHashKey(m) else m = m end
            if m and m ~= 0 then table.insert(hashesToRequest, m) end
        end
        for _, h in ipairs(hashesToRequest) do Citizen.InvokeNative(0x59BD177A1A48600A, ped, h) end
        Wait(350)
        
        local function ApplyPedComponent(hash)
            if not hash or hash == 0 then return end
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
            local t = 0
            while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t < 150 do Wait(20) t = t + 1 end
        end
        
        -- Draw
        if item.Draw and item.Draw ~= "" and item.Draw ~= "_" then
            ApplyPedComponent(GetHashKey(item.Draw))
        end
        
        -- Albedo
        if item.alb and item.alb ~= "" then
            ApplyPedComponent(GetHashKey(item.alb))
        end
        
        -- Normal
        if item.norm and item.norm ~= "" then
            ApplyPedComponent(GetHashKey(item.norm))
        end
        
        -- Material
        if item.mat and item.mat ~= 0 and item.mat ~= "" then
            local matHash = item.mat
            if type(matHash) == "string" then 
                if matHash:sub(1, 2) == "0x" then
                    matHash = tonumber(matHash, 16)
                else
                    matHash = GetHashKey(matHash)
                end
            end
            ApplyPedComponent(matHash)
        end
        
        -- Thought perhaps: yes _FINAL_PED_META_CHANGE_APPLY account MetaPed to autofix?
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        Wait(100)
        
        -- What trending will reflect about PED appearance?
        if item.pal and item.pal ~= " " and item.pal ~= "" then
            local palette = item.pal
            local paletteHash = GetHashKey(palette)
            
            if not string.find(palette:lower(), 'metaped_') then
                paletteHash = GetHashKey('metaped_' .. palette:lower())
            end
            
            local t0 = tonumber(item.palette1) or 0
            local t1 = tonumber(item.palette2) or 0
            local t2 = tonumber(item.palette3) or 0
            
            local tintHash = CategoryTintHash[category] or compHash
            
            print('[RSG-ClothingStore] Tint: ' .. palette .. ' Values: ' .. t0 .. ',' .. t1 .. ',' .. t2)
            
            Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, ped, tintHash, paletteHash, t0, t1, t2)
            Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
        end
    end
    
    -- What male-female: what caused situation appear universally stock, (never mind obvious proposal)
    if (category == 'coats' or category == 'coats_closed') and GetResourceState('rsg-appearance') == 'started' then
        pcall(function() exports['rsg-appearance']:ApplyCoatAntiClipFix(ped, category) end)
    end
    
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    previewedItem = item
end

-- Store previews use rsg-appearance's canonical equip/remove paths so its
-- ClothesCache stays synchronized.
local function ApplyStorePreviewItem(item)
    if not item or not item.category then return end
    local category = item.category
    previewApplyTokens[category] = (previewApplyTokens[category] or 0) + 1
    local token = previewApplyTokens[category]
    local previewItem = DeepCopy(item)

    CreateThread(function()
        Wait(60)
        if previewApplyTokens[category] ~= token then return end
        if previewItem.remove or previewItem._remove then
            TriggerEvent('rsg-clothing:client:removeClothing', category, {
                deferBodyRefresh = true,
                refreshBody = false,
                skipResync = true,
            })
        else
            TriggerEvent('rsg-clothing:client:equipClothing', previewItem, { skipResync = true })
        end
    end)
    previewedItem = item
end

local function AddRemovalVariants(items, isMale)
    local categories = {}
    for _, item in ipairs(items) do
        local category = item.category or item._c
        if category then categories[category] = true end
    end

    for category in pairs(categories) do
        items[#items + 1] = {
            name = 'None',
            category = category,
            price = 0,
            owned = true,
            remove = true,
            _remove = true,
            isMale = isMale,
            key = BuildItemKey({ category = category, remove = true, isMale = isMale }, isMale),
        }
    end
    return items
end

-- ==========================================
-- Summary/more obtained updates
-- ==========================================
local function BuildInterfaceItems(storeId, mode, isMale)
    local result = {}
    if mode == 'wardrobe' then
        for _, list in pairs(boughtData or {}) do
            if type(list) == 'table' then
                for _, item in ipairs(list) do
                    local copy = DeepCopy(item)
                    copy.key = BuildItemKey(copy, isMale)
                    copy.owned = true
                    copy.price = 0
                    result[#result + 1] = copy
                end
            end
        end
        return AddRemovalVariants(result, isMale)
    end

    local storeData = Config.Stores[storeId]
    if not storeData then return result end
    local sexKey = isMale and 'mp_male' or 'mp_female'
    for _, item in ipairs(ConfigStore.hashes[sexKey] or {}) do
        local copy = DeepCopy(item)
        copy.key = BuildItemKey(copy, isMale)
        copy.owned = boughtLookup[copy.key] == true
        result[#result + 1] = copy
    end
    return AddRemovalVariants(result, isMale)
end

local function OpenClothingInterface(storeId, mode)
    if isStoreOpen or sessionBusy then return end
    LoadSavedStoreScale()
    mode = mode or 'shop'
    local storeData = storeId and Config.Stores[storeId] or nil
    if mode == 'shop' and not storeData then return end

    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local isMale = model == GetHashKey('mp_male')

    sessionBusy = true
    RSGCore.Functions.TriggerCallback('rsg-clothingstore:server:getSessionData', function(data)
        sessionBusy = false
        if not data then
            RSGCore.Functions.Notify('Unable to load clothing data', 'error')
            return
        end

        boughtData = data.bought or {}
        outfitsData = data.outfits or {}
        BuildBoughtLookup()
        openingOutfit = DeepCopy(data.activeClothes or {})
        previewOutfit = DeepCopy(openingOutfit)
        selectedByCategory = {}
        purchaseCart = {}
        purchaseTotal = 0
        temporaryOutfit = DeepCopy(openingOutfit)
        temporarySelectedByCategory = {}
        temporaryPurchaseCart = {}
        sessionMode = mode
        currentStore = storeId
        isStoreOpen = true

        local items = BuildInterfaceItems(storeId, mode, isMale)
        if mode == 'shop' and #items == 0 then
            isStoreOpen = false
            RSGCore.Functions.Notify('No clothing is available', 'error')
            return
        end

        TeleportToRoom()
        Wait(300)
        CreateStoreCam()
        FreezeEntityPosition(PlayerPedId(), true)

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            items = items,
            outfits = outfitsData,
            money = data.money or 0,
            storeName = mode == 'wardrobe' and 'Wardrobe' or (storeData.name or 'Clothing Store'),
            isMale = isMale,
            mode = mode,
            total = 0,
            equippedKeys = GetEquippedKeys(openingOutfit, isMale),
            scale = uiScale,
            scaleModifier = tonumber(Config.ScaleModifier) or 0,
        })
    end)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', LoadSavedStoreScale)

CreateThread(LoadSavedStoreScale)

function OpenClothingStore(storeId)
    OpenClothingInterface(storeId, 'shop')
end

function CloseClothingStore(force)
    if not isStoreOpen then return end
    if sessionBusy and not force then
        SendNUIMessage({ action = 'purchaseFailed', reason = 'Please wait for the clothing action to finish' })
        return false
    end
    
    isStoreOpen = false
    currentStore = nil
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    
    DestroyStoreCam()
    RestoreOriginalClothes()
    FreezeEntityPosition(PlayerPedId(), false)
    TeleportBack()
    return true
end

-- ==========================================
-- NUI CALLBACKS
-- ==========================================
RegisterNUICallback('setUiScale', function(data, cb)
    SaveStoreScale(data and data.scale)
    cb({ scale = uiScale })
end)

RegisterNUICallback('previewItem', function(data, cb)
    if data.item then
        local ped = PlayerPedId()
        local isMale = GetEntityModel(ped) == GetHashKey('mp_male')
        local normalized = NormalizeClientItem(data.item, isMale)
        if not normalized then cb('error') return end

        local category = normalized.category
        local conflict = ConflictingCategories[category]
        if conflict then
            previewOutfit[conflict] = nil
            selectedByCategory[conflict] = nil
            purchaseCart[conflict] = nil
        end

        ApplyStorePreviewItem(normalized)
        if normalized.remove then
            previewOutfit[category] = nil
        else
            previewOutfit[category] = normalized
        end

        local opening = openingOutfit[category]
        local openingConflict = conflict and openingOutfit[conflict] or nil
        local openingKey = opening and BuildItemKey(opening, isMale) or nil
        if (normalized.remove and not opening and not openingConflict) or (openingKey and openingKey == normalized.key) then
            selectedByCategory[category] = nil
            purchaseCart[category] = nil
        else
            selectedByCategory[category] = normalized.remove and { remove = true } or normalized
            if normalized.remove or boughtLookup[normalized.key] or data.item.owned or sessionMode == 'wardrobe' then
                purchaseCart[category] = nil
            else
                local cartItem = DeepCopy(data.item)
                cartItem.key = normalized.key
                purchaseCart[category] = cartItem
            end
        end
        RecalculateCart()
    end
    cb('ok')
end)

RegisterNUICallback('buyItem', function(data, cb)
    if sessionBusy or purchaseTotal <= 0 or not HasSelections() then cb('error') return end
    sessionBusy = true
    RSGCore.Functions.TriggerCallback('rsg-clothingstore:server:commitPurchase', function(result)
        sessionBusy = false
        if not result or not result.success then
            SendNUIMessage({ action = 'purchaseFailed', reason = result and result.reason or 'Purchase failed' })
            cb('error')
            return
        end

        boughtData = result.bought or boughtData
        BuildBoughtLookup()
        outfitsData = result.outfits or outfitsData
        openingOutfit = DeepCopy(result.activeClothes or previewOutfit)
        previewOutfit = DeepCopy(openingOutfit)
        selectedByCategory = {}
        purchaseCart = {}
        purchaseTotal = 0
        temporaryOutfit = DeepCopy(openingOutfit)
        temporarySelectedByCategory = {}
        temporaryPurchaseCart = {}
        SendNUIMessage({
            action = 'purchaseSuccess',
            newMoney = result.newMoney or 0,
            outfits = outfitsData,
            boughtKeys = GetBoughtKeys(),
            total = 0,
        })
        cb('ok')
    end, {
        items = purchaseCart,
        totalPrice = purchaseTotal,
        visibleOutfit = previewOutfit,
        storeId = currentStore,
    })
end)

RegisterNUICallback('previewOutfit', function(data, cb)
    local zeroBasedIndex = tonumber(data.index) or -1

    -- Outfit 0 is a local-only snapshot. Capturing it does not clear the cart,
    -- persist data, or automatically load Outfit 1.
    if zeroBasedIndex < 0 then
        if data.capture then
            temporaryOutfit = DeepCopy(previewOutfit)
            temporarySelectedByCategory = DeepCopy(selectedByCategory)
            temporaryPurchaseCart = DeepCopy(purchaseCart)
        else
            previewOutfit = DeepCopy(temporaryOutfit)
            selectedByCategory = DeepCopy(temporarySelectedByCategory)
            purchaseCart = DeepCopy(temporaryPurchaseCart)
            ApplyCompleteOutfit(previewOutfit)
        end
        RecalculateCart()
        cb('ok')
        return
    end

    local entry = outfitsData[zeroBasedIndex + 1]
    if not entry or type(entry.clothes) ~= 'table' then cb('error') return end
    selectedByCategory = { __outfit = true }
    purchaseCart = {}
    purchaseTotal = 0
    previewOutfit = DeepCopy(entry.clothes)
    ApplyCompleteOutfit(previewOutfit)
    RecalculateCart()
    cb('ok')
end)

RegisterNUICallback('applyOutfit', function(_, cb)
    if sessionBusy or not HasSelections() then cb('error') return end
    sessionBusy = true
    RSGCore.Functions.TriggerCallback('rsg-clothingstore:server:applyOutfit', function(result)
        sessionBusy = false
        if not result or not result.success then
            SendNUIMessage({ action = 'purchaseFailed', reason = result and result.reason or 'Unable to apply outfit' })
            cb('error')
            return
        end
        openingOutfit = DeepCopy(result.activeClothes or previewOutfit)
        previewOutfit = DeepCopy(openingOutfit)
        selectedByCategory = {}
        purchaseCart = {}
        purchaseTotal = 0
        temporaryOutfit = DeepCopy(openingOutfit)
        temporarySelectedByCategory = {}
        temporaryPurchaseCart = {}
        SendNUIMessage({ action = 'applySuccess', total = 0 })
        cb('ok')
    end, previewOutfit)
end)

RegisterNUICallback('saveOutfit', function(_, cb)
    if sessionBusy then cb('error') return end
    if next(purchaseCart) ~= nil then
        SendNUIMessage({ action = 'purchaseFailed', reason = 'Buy the pending clothing before saving this outfit' })
        cb('error')
        return
    end
    sessionBusy = true
    RSGCore.Functions.TriggerCallback('rsg-clothingstore:server:saveOutfit', function(result)
        sessionBusy = false
        if not result or not result.success then
            SendNUIMessage({ action = 'purchaseFailed', reason = result and result.reason or 'Unable to save outfit' })
            cb('error')
            return
        end
        outfitsData = result.outfits or outfitsData
        SendNUIMessage({
            action = 'outfitsUpdated',
            outfits = outfitsData,
            selectedIndex = (tonumber(result.selectedIndex) or 0) + 1,
        })
        cb('ok')
    end, previewOutfit)
end)

RegisterNUICallback('deleteOutfit', function(data, cb)
    if sessionBusy then cb('error') return end
    sessionBusy = true
    RSGCore.Functions.TriggerCallback('rsg-clothingstore:server:deleteOutfit', function(result)
        sessionBusy = false
        if not result or not result.success then
            SendNUIMessage({ action = 'purchaseFailed', reason = result and result.reason or 'Unable to delete outfit' })
            cb('error')
            return
        end
        outfitsData = result.outfits or {}
        local selectedIndex = #outfitsData > 0 and ((tonumber(result.selectedIndex) or 0) + 1) or 0
        SendNUIMessage({ action = 'outfitsUpdated', outfits = outfitsData, selectedIndex = selectedIndex })
        cb('ok')
    end, tonumber(data.index) or -1)
end)

RegisterNUICallback('moveCamera', function(data, cb)
    MoveStoreCam(data.direction)
    cb('ok')
end)

RegisterNUICallback('closeStore', function(data, cb)
    cb(CloseClothingStore() and 'ok' or 'busy')
end)

RegisterCommand('wardrobe', function()
    OpenClothingInterface(nil, 'wardrobe')
end, false)

-- ==========================================
-- OX_TARGET ZONES AND BLIPS
-- ==========================================
CreateThread(function()
    if GetResourceState('ox_target') ~= 'started' then
        print('[rsg-clothingstore] ox_target is not started; clothing-store interactions are unavailable')
        return
    end

    local promptPrefix = GetCurrentResourceName() .. ':'
    for storeId, storeData in pairs(Config.Stores) do
        local ok, err = pcall(function()
            if not (storeData and storeData.coords and storeData.coords.x and storeData.coords.y and storeData.coords.z) then
                error('invalid store coords')
            end

            local legacyPromptId = storeId .. '_clothing'
            local promptId = promptPrefix .. storeId .. '_clothing'

            -- Remove prompt entries left behind by older versions of this resource.
            pcall(function()
                exports['rsg-core']:deletePrompt(legacyPromptId)
                exports['rsg-core']:deletePrompt(promptId)
            end)

            local targetStoreId = storeId
            local targetStoreName = tostring(storeData.name or storeId)
            local zoneId = exports.ox_target:addSphereZone({
                coords = storeData.coords,
                radius = 3,
                debug = false,
                drawSprite = false,
                options = {
                    {
                        name = ('rsg_clothingstore_%s'):format(targetStoreId),
                        icon = 'fa-solid fa-shirt',
                        label = 'Open ' .. targetStoreName,
                        distance = 2.5,
                        canInteract = function()
                            return not isStoreOpen and not sessionBusy
                        end,
                        onSelect = function()
                            OpenClothingStore(targetStoreId)
                        end,
                    },
                },
            })
            storeTargetZones[#storeTargetZones + 1] = zoneId

            if storeData.blip == true then
                local blip = BlipAddForCoords(1664425300, storeData.coords.x, storeData.coords.y, storeData.coords.z)
                SetBlipSprite(blip, GetHashKey('blip_shop_tailor'), true)
                SetBlipScale(blip, 0.2)
                SetBlipName(blip, tostring(storeData.name or storeId))
            end
        end)

        if not ok then
            print(('[rsg-clothingstore] Failed target registration for store "%s": %s'):format(tostring(storeId), tostring(err)))
        end
    end
end)

RegisterNetEvent('rsg-clothingstore:client:openStore', function(storeId)
    OpenClothingStore(storeId)
end)

CreateThread(function()
    while true do
        if isStoreOpen then
            Wait(0)
            DisableAllControlActions(0)
            if IsControlJustPressed(0, 0x156F7119) then
                CloseClothingStore()
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, zoneId in ipairs(storeTargetZones) do
            pcall(function()
                exports.ox_target:removeZone(zoneId)
            end)
        end
        storeTargetZones = {}

        if isStoreOpen then
            CloseClothingStore(true)
        end
    end
end)
