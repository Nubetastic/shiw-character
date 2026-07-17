-- ==========================================
-- RSG-APPEARANCE HTML UI v3.0
-- Unknown name rsg-menubase in HTML
-- ==========================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local clothing = require 'data.clothing'
local Data = require 'data.features'

local isUIOpen = false
local currentMode = nil -- 'creator' or 'shop'
local currentClothingCategory = nil
local isMouseDraggingPed = false
local lastMouseX = nil
local uiScale = 1.0
local SHARED_SCALE_KEY = 'rsg_clothingstore'
local LEGACY_SCALE_KEY = 'rsg_appearance'

local function ClampUiScale(scale)
    return math.max(0.25, math.min(3.0, tonumber(scale) or 1.0))
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function LoadSavedAppearanceScale()
    local playerData = RSGCore.Functions.GetPlayerData()
    local hudScale = playerData and playerData.metadata and playerData.metadata.hudScale
    local savedScales = type(hudScale) == 'table' and hudScale or {}
    local savedScale = savedScales[SHARED_SCALE_KEY]

    if savedScale == nil and savedScales[LEGACY_SCALE_KEY] ~= nil then
        savedScale = savedScales[LEGACY_SCALE_KEY]
        local migratedScales = CopyTable(savedScales)
        migratedScales[SHARED_SCALE_KEY] = ClampUiScale(savedScale)
        TriggerServerEvent('RSGCore:Server:SetMetaData', 'hudScale', migratedScales)
    end

    uiScale = ClampUiScale(savedScale or 1.0)
end

local function SaveAppearanceScale(scale)
    uiScale = ClampUiScale(scale)
    local playerData = RSGCore.Functions.GetPlayerData()
    local hudScale = playerData and playerData.metadata and playerData.metadata.hudScale
    local savedScales = CopyTable(type(hudScale) == 'table' and hudScale or {})
    savedScales[SHARED_SCALE_KEY] = uiScale
    TriggerServerEvent('RSGCore:Server:SetMetaData', 'hudScale', savedScales)
end

local function IsCursorOverPedArea(cursorX, cursorY)
    -- Character is centered in creator scene; this avoids rotating while clicking edge UI.
    return cursorX > 0.25 and cursorX < 0.75 and cursorY > 0.10 and cursorY < 0.92
end

-- This is the appropriate place for your code
-- (NativeUpdatePedVariation in creator.lua checks local variables in the local scope)
local function NativeUpdatePedVariation(ped)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

-- Perform a check to see if a CreatorPed or PlayerPed
local function GetTargetPed()
    if CreatorPed and DoesEntityExist(CreatorPed) then
        return CreatorPed
    end
    return PlayerPedId()
end

-- ==========================================
-- Loading user interface
-- ==========================================

function OpenCreatorHTML(step)
    if isUIOpen then return end
    LoadSavedAppearanceScale()
    
    isUIOpen = true
    currentMode = 'creator'
    
    local ped = GetTargetPed()
    
    -- To interact with the loaded components: verifying the data from LoadedComponents and CreatorCache,
    -- A check for invalid data in user input (name, modifications, other data and etc.)
    if step == 'customize' and LoadedComponents and type(LoadedComponents) == 'table' and (next(LoadedComponents) ~= nil) then
        for k, v in pairs(LoadedComponents) do
            if type(v) == 'table' then
                CreatorCache[k] = CreatorCache[k] or {}
                for k2, v2 in pairs(v) do CreatorCache[k][k2] = v2 end
            else
                CreatorCache[k] = v
            end
        end
    end
    
    SendNUIMessage({
        action = 'openCreator',
        step = step or 'gender',
        isMale = IsPedMale(ped),
        cache = CreatorCache or {},
        visualOnly = (step == 'customize' and KeepClothesOnSave),
        scale = uiScale,
        scaleModifier = tonumber(RSG.ScaleModifier) or 0
    })
    
    SetNuiFocus(true, true)
end

function OpenShopHTML()
    if isUIOpen then return end
    LoadSavedAppearanceScale()
    
    isUIOpen = true
    currentMode = 'shop'
    
    SendNUIMessage({
        action = 'openShop',
        clothesCache = ClothesCache or {},
        oldClothesCache = OldClothesCache or {},
        scale = uiScale,
        scaleModifier = tonumber(RSG.ScaleModifier) or 0
    })
    
    SetNuiFocus(true, true)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', LoadSavedAppearanceScale)

CreateThread(LoadSavedAppearanceScale)

function CloseHTML()
    if not isUIOpen then return end
    
    isUIOpen = false
    currentMode = nil
    currentClothingCategory = nil
    
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
end

-- ==========================================
-- Loaded rsg-menubase
-- ==========================================

-- Loaded FirstMenu
local _originalFirstMenu = FirstMenu
function FirstMenu()
    OpenCreatorHTML('gender')
end

-- Loaded MainMenu
local _originalMainMenu = MainMenu
function MainMenu()
    if isUIOpen then
        -- UI auto closure - timeout
        SendNUIMessage({
            action = 'setCache',
            cache = CreatorCache or {}
        })
    else
        OpenCreatorHTML('customize')
    end
end

-- Data received via user input - always in HTML
function OpenBodyMenu() MainMenu() end
function OpenFaceMenu() MainMenu() end
function OpenHairMenu() MainMenu() end
function OpenMakeupMenu() MainMenu() end
function OpenEyesMenu() MainMenu() end
function OpenNoseMenu() MainMenu() end
function OpenMouthMenu() MainMenu() end
function OpenJawMenu() MainMenu() end
function OpenChinMenu() MainMenu() end
function OpenEarsMenu() MainMenu() end
function OpenCheekbonesMenu() MainMenu() end
function OpenEyelidsMenu() MainMenu() end
function OpenEyebrowsMenu() MainMenu() end
function OpenDefectsMenu() MainMenu() end

-- ==========================================
-- NUI CALLBACKS - system functions
-- ==========================================

RegisterNUICallback('setUiScale', function(data, cb)
    SaveAppearanceScale(data and data.scale)
    cb({ scale = uiScale })
end)

RegisterNUICallback('selectGender', function(data, cb)
    local isMale = data.isMale
    local newSex = isMale and 1 or 2
    
    print('[RSG-Appearance] selectGender: isMale=' .. tostring(isMale) .. ' current=' .. tostring(Selectedsex))
    
    -- When they are initialized - pass the signals to native
    if Selectedsex == newSex then
        cb('ok')
        return
    end
    
    Selectedsex = newSex
    
    -- Verify data from user input
    CreateThread(function()
        DoScreenFadeOut(200)
        Wait(200)
        
        -- Load result of input
        if CreatorPed and DoesEntityExist(CreatorPed) then
            DeleteEntity(CreatorPed)
            CreatorPed = nil
        end
        
        local modelName = isMale and 'mp_male' or 'mp_female'
        local gender = isMale and 'male' or 'female'
        local coords = {x = -559.6, y = -3781.0, z = 237.55, h = 110.0}
        
        -- Processing data
        local modelHash = GetHashKey(modelName)
        RequestModel(modelHash, false)
        while not HasModelLoaded(modelHash) do
            Wait(10)
        end
        
        -- Receiving body morph
        CreatorPed = CreatePed(modelHash, coords.x, coords.y, coords.z, coords.h, true, false, false, false)
        
        Wait(100)
        
        -- Adjusting MP system
        Citizen.InvokeNative(0x283978A15512B2FE, CreatorPed, true)
        Citizen.InvokeNative(0x58A850EAEE20FAA3, CreatorPed)
        
        NetworkSetEntityInvisibleToNetwork(CreatorPed, true)
        FreezeEntityPosition(CreatorPed, true)
        
        Wait(200)
        
        -- Processing data and adjusting parameters accordingly
        CreatorCache = {
            sex = Selectedsex,
            head = isMale and 18 or 2,
            skin_tone = 1,
            body_size = 3,
            body_waist = 11,
            chest_size = 6,
            height = 100,
            hair = { model = 0, color = 1 },
            beard = { model = 0, color = 1 },
            eyes_color = 5,
        }
        
        -- Loading and verifying the initial graphical data
        FixIssues(CreatorPed)
        
        -- Confirmation that loading data to players works correctly!
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, GetHashKey("gunbelts"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, GetHashKey("loadouts"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, GetHashKey("holsters_left"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, GetHashKey("holsters_right"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, GetHashKey("belt_buckles"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, 0xF1542D11, 0)  -- gunbelts hash
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, 0x9B2C8B89, 0)  -- loadouts hash
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, 0x877A2CF7, 0)  -- ammo belts
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, 0x72E6EF74, 0)  -- accessories
        
        Wait(100)
        
        -- False: Input doesn't match, entry was ignored - further processing can continue!
        LoadBoody(CreatorPed, CreatorCache)
        Wait(150)
        LoadHead(CreatorPed, CreatorCache)
        Wait(100)
        LoadEyes(CreatorPed, CreatorCache)
        Wait(50)
        
        -- Processing time
        LoadBodyFeature(CreatorPed, CreatorCache.body_size, Data.Appearance.body_size)
        LoadBodyFeature(CreatorPed, CreatorCache.body_waist, Data.Appearance.body_waist)
        LoadBodyFeature(CreatorPed, CreatorCache.chest_size, Data.Appearance.chest_size)
        
        -- Entering more data
        Citizen.InvokeNative(0xD710A5007C2AC539, CreatorPed, GetHashKey("pants"), 0)
        
        Citizen.InvokeNative(0x704C908E9C405136, CreatorPed)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, CreatorPed, false, true, true, true, false)
        if ReapplyBodyMorph then ReapplyBodyMorph(CreatorPed) end
        -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
        -- TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', 'creator_model', false, CreatorPed)
        
        Wait(550)
        DoScreenFadeIn(200)
        
        print('[RSG-Appearance] Gender changed to: ' .. gender)
    end)
    
    cb('ok')
end)

RegisterNUICallback('confirmGender', function(data, cb)
    local isMale = data.isMale
    Selectedsex = isMale and 1 or 2
    
    print('[RSG-Appearance] confirmGender: isMale=' .. tostring(isMale))
    
    -- Comprehensive graphical settings
    CreatorCache = {
        sex = isMale and 1 or 2,
        head = 1,
        skin_tone = 1,
        body_size = 3,
        body_waist = 11,
        chest_size = 6,
        height = 100,
    }
    
    local ped = GetTargetPed()
    print('[RSG-Appearance] confirmGender applying to ped: ' .. tostring(ped))
    
    LoadHead(ped, CreatorCache)
    LoadBoody(ped, CreatorCache)
    NativeUpdatePedVariation(ped)
    -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
    -- TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', 'creator_model', false, ped)
    
    cb('ok')
end)

RegisterNUICallback('selectCategory', function(data, cb)
    currentClothingCategory = data.category or data.subcategory
    
    if currentMode == 'shop' and currentClothingCategory then
        -- Providing interface structure
        local ped = GetTargetPed()
        local isMale = IsPedMale(ped)
        local gender = isMale and 'male' or 'female'
        local maxModels = 0
        
        if clothing[gender] and clothing[gender][currentClothingCategory] then
            for model, _ in pairs(clothing[gender][currentClothingCategory]) do
                if type(model) == 'number' and model > maxModels then
                    maxModels = model
                end
            end
        end
        
        SendNUIMessage({ action = 'updateMax', id = 'model', max = maxModels })
    end
    
    cb('ok')
end)

RegisterNUICallback('updateValue', function(data, cb)
    local id = data.id
    local value = data.value
    local ped = GetTargetPed()
    
    print('[RSG-Appearance] updateValue: id=' .. tostring(id) .. ' value=' .. tostring(value) .. ' ped=' .. tostring(ped))
    
    -- Loading
    if id == 'hair_model' or id == 'hair_color' then
        if not CreatorCache['hair'] then
            CreatorCache['hair'] = { model = 0, color = 1 }
        end
        if id == 'hair_model' then
            CreatorCache['hair'].model = value
        else
            CreatorCache['hair'].color = value
        end
        CreatorCache['hair_color'] = CreatorCache['hair'].color
        LoadHair(ped, CreatorCache)
        
    elseif id == 'beard_model' or id == 'beard_color' then
        if not CreatorCache['beard'] then
            CreatorCache['beard'] = { model = 0, color = 1 }
        end
        if id == 'beard_model' then
            CreatorCache['beard'].model = value
        else
            CreatorCache['beard'].color = value
        end
        CreatorCache['beard_color'] = CreatorCache['beard'].color
        LoadBeard(ped, CreatorCache)
        
    else
        CreatorCache[id] = value
        
        -- Confirm beacon
        if id == 'head' then
            LoadHead(ped, CreatorCache)
        elseif id == 'skin_tone' then
            LoadHead(ped, CreatorCache)
            LoadBoody(ped, CreatorCache)
        elseif id == 'body_size' or id == 'body_waist' or id == 'chest_size' then
            -- A body morph: enables + facial features
            -- ApplyAllBodyMorph verifies the parameters used in the body morph (body + face features)
            -- No verify _G._BodyMorphData from guard/reapply
            ApplyAllBodyMorph(ped, CreatorCache)
            -- UpdatePedVariation with detailed checks for pointer-specific parameters
            NativeUpdatePedVariation(ped)
            -- TO UpdatePedVariation with verification of facial features - loading body
            Wait(50)
            ReapplyBodyMorph(ped)
        elseif id == 'height' then
            LoadHeight(ped, CreatorCache)
        elseif id == 'eyes_color' then
            LoadEyes(ped, CreatorCache)
        -- Processing data
        elseif id == 'shirt_model' then
            LoadStarterClothing(ped, 'shirts_full', value, 1)
        elseif id == 'pants_model' then
            LoadStarterClothing(ped, 'pants', value, 1)
        elseif id == 'boots_model' then
            LoadStarterClothing(ped, 'boots', value, 1)
        elseif string.find(id, '_t') or string.find(id, '_op') or string.find(id, '_c1') or string.find(id, 'eyebrows') then
            LoadOverlays(ped, CreatorCache)
        else
            -- Target area (eye_depth, eye_angle and etc.)
            LoadFeatures(ped, CreatorCache)
            
            -- Error: Confirm invalidations within provided content were unexpected!
            -- Searching for normal validation in the data
            Wait(50)
            if CreatorCache.body_size or CreatorCache.body_waist or CreatorCache.chest_size then
                ApplyAllBodyMorph(ped, CreatorCache)
                NativeUpdatePedVariation(ped)
                Wait(50)
                ReapplyBodyMorph(ped)
            end
        end
    end
    
    -- A signal: NativeUpdatePedVariation initialized with the expected parameters for format.
    -- Loading components (LoadHead, LoadBody, LoadEyes, LoadOverlays, LoadStarterClothing)
    -- Additional operations UpdatePedVariation confirmed executed.
    -- Body stored also regarding the new settings within the initialized settings.
    -- Height stage SetPedScale, confirming no invalidations in UpdatePedVariation.
    cb('ok')
end)

-- Validate: string contains only Latin letters, spaces and hyphens
local function isValidName(str)
    if not str or str == '' then return false end
    local cleaned = str:gsub('[%s%-]', '')
    if cleaned == '' then return false end
    if cleaned:match('[%d]') then return false end
    if cleaned:match('[!@#$%%%^&*%(%)_+=~`%[%]{}<>|/\\%.,%?;:\"\']') then return false end
    return true
end

RegisterNUICallback('confirmCreator', function(data, cb)
    local firstname = data.firstname
    local lastname = data.lastname
    local nationality = data.nationality
    local birthdate = data.birthdate
    
    -- ★ editappearance mode: skin only, no name validation needed
    if not KeepClothesOnSave then
    -- Validation
    if not firstname or #firstname < 2 then
        TriggerEvent('ox_lib:notify', {
            title = 'Error',
            description = 'Enter a first name (min. 2 characters)',
            type = 'error'
        })
        cb({ success = false })
        return
    end

    if not isValidName(firstname) then
        TriggerEvent('ox_lib:notify', {
            title = 'Error',
            description = 'First name must contain only letters',
            type = 'error'
        })
        cb({ success = false })
        return
    end

    if not lastname or #lastname < 2 then
        TriggerEvent('ox_lib:notify', {
            title = 'Error',
            description = 'Enter a last name (min. 2 characters)',
            type = 'error'
        })
        cb({ success = false })
        return
    end

    if not isValidName(lastname) then
        TriggerEvent('ox_lib:notify', {
            title = 'Error',
            description = 'Last name must contain only letters',
            type = 'error'
        })
        cb({ success = false })
        return
    end
    end
    
    -- Data processing system
    Firstname = firstname
    Lastname = lastname
    Nationality = nationality or ''
    Birthdate = birthdate or '1870-01-01'
    
    -- Verification with out
    CreatorCache.sex = Selectedsex
    CreatorCache.model = Selectedsex == 1 and 'mp_male' or 'mp_female'
    
    -- Loading body data to display
    local isMale = Selectedsex == 1
    local gender = isMale and 'male' or 'female'
    
    -- Ensure body data serves its purpose
    local function GetClothingHash(category, model, texture)
        texture = texture or 1
        if model <= 0 then return 0 end
        
        if clothing[gender] and clothing[gender][category] then
            if clothing[gender][category][model] and clothing[gender][category][model][texture] then
                return clothing[gender][category][model][texture].hash
            elseif clothing[gender][category][model] and clothing[gender][category][model][1] then
                return clothing[gender][category][model][1].hash
            end
        end
        return 0
    end
    
    local shirtModel = CreatorCache.shirt_model or 0
    local pantsModel = CreatorCache.pants_model or 0
    local bootsModel = CreatorCache.boots_model or 0
    
    local clothesData = {
        shirts_full = {
            model = shirtModel,
            texture = 1,
            hash = GetClothingHash('shirts_full', shirtModel, 1)
        },
        pants = {
            model = pantsModel,
            texture = 1,
            hash = GetClothingHash('pants', pantsModel, 1)
        },
        boots = {
            model = bootsModel,
            texture = 1,
            hash = GetClothingHash('boots', bootsModel, 1)
        },
    }
    
    print('[RSG-Appearance] Starter clothes with hashes:')
    print('  shirts_full: model=' .. shirtModel .. ' hash=' .. tostring(clothesData.shirts_full.hash))
    print('  pants: model=' .. pantsModel .. ' hash=' .. tostring(clothesData.pants.hash))
    print('  boots: model=' .. bootsModel .. ' hash=' .. tostring(clothesData.boots.hash))
    
    -- Adjusting UI
    CloseHTML()
    
    -- Confirm
    DoScreenFadeOut(500)
    Wait(500)
    
    DestroyCreatorCamera()
    
    -- A return function without excuses: verifying if everything works with parameters expected, for further validation proceeding.
    if KeepClothesOnSave then
        local playerPed = PlayerPedId()
        local isMale = Selectedsex == 1
        -- Verifying the final component in additional processing
        if CreatorPed and DoesEntityExist(CreatorPed) then
            DeleteEntity(CreatorPed)
            CreatorPed = nil
        end
        SetEntityVisible(playerPed, true)
        SetEntityInvincible(playerPed, false)
        NetworkSetEntityInvisibleToNetwork(playerPed, false)
        -- Speedrunning the update honestly /editappearance
        if EditAppearanceReturnPos then
            SetEntityCoords(playerPed, EditAppearanceReturnPos.x, EditAppearanceReturnPos.y, EditAppearanceReturnPos.z, false, false, false, false)
            SetEntityHeading(playerPed, EditAppearanceReturnPos.h)
            EditAppearanceReturnPos = nil
        end
        if not isMale and ApplyFemaleMpMetaBasePreset then
            ApplyFemaleMpMetaBasePreset(playerPed)
        end
        LoadHeight(playerPed, CreatorCache)
        LoadBoody(playerPed, CreatorCache)
        Wait(100)
        if ApplyAndSaveBodyMorph then ApplyAndSaveBodyMorph(playerPed, CreatorCache) end
        LoadHead(playerPed, CreatorCache)
        Wait(100)
        LoadHair(playerPed, CreatorCache)
        if CreatorCache.beard and isMale then LoadBeard(playerPed, CreatorCache) end
        LoadEyes(playerPed, CreatorCache)
        LoadFeatures(playerPed, CreatorCache)
        LoadOverlays(playerPed, CreatorCache)
        if ReapplyBodyMorph then ReapplyBodyMorph(playerPed) end
        Citizen.InvokeNative(0x704C908E9C405136, playerPed)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, playerPed, false, true, true, true, false)
        Skinkosong = false
        if EnsureFullCreatorCache then EnsureFullCreatorCache() end
        TriggerServerEvent('rsg-appearance:server:SaveSkin', CreatorCache, {}, true)
        KeepClothesOnSave = false
        TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', 0)
        DoScreenFadeIn(500)
        cb({ success = true })
        return
    end
    
    -- Loading data to display
    local modelName = Selectedsex == 1 and 'mp_male' or 'mp_female'
    local modelHash = GetHashKey(modelName)
    
    RequestModel(modelHash, false)
    while not HasModelLoaded(modelHash) do
        Wait(10)
    end
    
    SetPlayerModel(PlayerId(), modelHash, true)
    
    local playerPed = PlayerPedId()
    
    -- Adjusting MP parameters
    Citizen.InvokeNative(0x283978A15512B2FE, playerPed, true)
    Citizen.InvokeNative(0x58A850EAEE20FAA3, playerPed)
    
    Wait(200)
    
    -- Validating additional input to check if confirmed
    local isMale = Selectedsex == 1
    local gender = isMale and 'male' or 'female'
    
    ApplyCreatorComponents(playerPed, gender, CreatorCache)
    
    -- Confirmed processing input
    if CreatorCache.hair then
        LoadHair(playerPed, CreatorCache)
    end
    if CreatorCache.beard and isMale then
        LoadBeard(playerPed, CreatorCache)
    end
    
    -- Loading something expected for user guidance (advanced-processing)
    if not KeepClothesOnSave then
    -- Trigger setup for cleared parameters
    if clothesData.shirts_full.hash and clothesData.shirts_full.hash ~= 0 then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, playerPed, clothesData.shirts_full.hash, true, true, true)
        print('[RSG-Appearance] Applied shirt hash: ' .. tostring(clothesData.shirts_full.hash))
    elseif clothesData.shirts_full.model > 0 then
        LoadStarterClothing(playerPed, 'shirts_full', clothesData.shirts_full.model, 1)
    end
    
    if clothesData.pants.hash and clothesData.pants.hash ~= 0 then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, playerPed, clothesData.pants.hash, true, true, true)
        print('[RSG-Appearance] Applied pants hash: ' .. tostring(clothesData.pants.hash))
    elseif clothesData.pants.model > 0 then
        LoadStarterClothing(playerPed, 'pants', clothesData.pants.model, 1)
    end
    
    if clothesData.boots.hash and clothesData.boots.hash ~= 0 then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, playerPed, clothesData.boots.hash, true, true, true)
        print('[RSG-Appearance] Applied boots hash: ' .. tostring(clothesData.boots.hash))
    elseif clothesData.boots.model > 0 then
        LoadStarterClothing(playerPed, 'boots', clothesData.boots.model, 1)
    end
    end
    
    -- Detail confirmed
    Citizen.InvokeNative(0x704C908E9C405136, playerPed)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, playerPed, false, true, true, true, false)
    if ReapplyBodyMorph then ReapplyBodyMorph(playerPed) end
    
    Wait(500)

    print('[RSG-Appearance] saveConfirm: Skinkosong=' .. tostring(Skinkosong) .. ' Cid=' .. tostring(Cid) .. ' Firstname=' .. tostring(Firstname))

    -- Fallback: if we have character info but no Cid, generate one
    if not Skinkosong and not Cid and Firstname and Lastname then
        Cid = tostring(math.random(1, 9999))
        print('[RSG-Appearance] saveConfirm: Generated fallback Cid=' .. Cid)
    end

    if Skinkosong then
        -- Processing results with clean data
        Skinkosong = false
        if EnsureFullCreatorCache then EnsureFullCreatorCache() end
        if KeepClothesOnSave then
            -- A connector with optimization: data for loading anticipated, how it connects for further access
            TriggerServerEvent('rsg-appearance:server:SaveSkin', CreatorCache, {}, true)
            KeepClothesOnSave = false
        else
            TriggerServerEvent('rsg-appearance:server:SaveSkin', CreatorCache, clothesData, true)
        end
    elseif Cid then
        -- Clear settings initialized
        local newData = {
            firstname = Firstname,
            lastname = Lastname,
            nationality = Nationality,
            gender = Selectedsex == 1 and 0 or 1,
            birthdate = Birthdate,
            cid = Cid
        }

        print('[RSG-Appearance] Creating character: ' .. Firstname .. ' ' .. Lastname)
        TriggerServerEvent('rsg-multicharacter:server:createCharacter', newData)

        -- Wait for the server to finish creating the character
        -- Server's createCharacter waits for preloading which can take several seconds
        print('[RSG-Appearance] Waiting 5s for character creation...')
        Wait(5000)

        print('[RSG-Appearance] Calling SaveSkin...')
        if EnsureFullCreatorCache then EnsureFullCreatorCache() end
        TriggerServerEvent('rsg-appearance:server:SaveSkin', CreatorCache, clothesData, false)
        TriggerServerEvent('rsg-appearance:server:GiveStarterClothing', clothesData, isMale)
        print('[RSG-Appearance] SaveSkin and GiveStarterClothing triggered')

        -- For NEW characters: rsg-spawn:client:newplayer handles bucket reset, fade-in, and teleport
        -- Don't do it here or we'll race with the spawn event
        cb({ success = true })
        return
    end
    
    -- Processing with parameters confirmed
    TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', 0)
    
    DoScreenFadeIn(500)
    
    cb({ success = true })
end)

-- ==========================================
-- NUI CALLBACKS - systems
-- ==========================================

RegisterNUICallback('updateClothes', function(data, cb)
    local category = currentClothingCategory
    local valueType = data.type
    local value = data.value
    
    if not category then
        cb('ok')
        return
    end
    
    -- Loading supports
    if not ClothesCache[category] then
        ClothesCache[category] = { model = 0, texture = 1 }
    end
    
    local ped = PlayerPedId()
    local isMale = IsPedMale(ped)
    local gender = isMale and 'male' or 'female'
    
    if valueType == 'model' then
        ClothesCache[category].model = value
        ClothesCache[category].texture = 1
        
        -- A initialization status check
        local maxTex = GetMaxTexturesForModel(category, value, false)
        SendNUIMessage({ action = 'updateMax', id = 'texture', max = math.max(1, maxTex) })
    else
        ClothesCache[category].texture = value
    end
    
    -- Confirm input
    local model = ClothesCache[category].model
    local texture = ClothesCache[category].texture
    
    if model > 0 then
        if clothing[gender] and clothing[gender][category] and 
           clothing[gender][category][model] and clothing[gender][category][model][texture] then
            local hash = clothing[gender][category][model][texture].hash
            ClothesCache[category].hash = hash
            
            NativeSetPedComponentEnabledClothes(ped, hash, false, true, true)
            NativeUpdatePedVariation(ped)
        end
    else
        -- Load error notifications with data provided
        TriggerEvent('rsg-clothing:client:removeClothing', category, {
            deferBodyRefresh = true,
            refreshBody = true,
            skipResync = true,
        })
        ClothesCache[category].hash = nil
    end

    -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
    -- if model > 0 then
    --     TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', category, false, ped)
    -- end
    
    -- Essential functionality check
    local price = CalculatePrice(ClothesCache, OldClothesCache, isMale)
    CurrentPrice = price
    SendNUIMessage({ action = 'updatePrice', price = price })
    
    cb('ok')
end)

RegisterNUICallback('confirmShop', function(data, cb)
    local totalPrice = CurrentPrice or 0
    
    if totalPrice <= 0 then
        TriggerEvent('ox_lib:notify', { 
            title = 'Loading', 
            description = 'To process with verification', 
            type = 'info' 
        })
        cb({ success = false })
        return
    end
    
    -- Sound
    local purchasedItems = GetPurchasedItems(ClothesCache, OldClothesCache, IsPedMale(PlayerPedId()))
    
    TriggerServerEvent('rsg-appearance:server:buyClothes', purchasedItems, totalPrice)
    
    -- Loading OldClothesCache
    for category, data in pairs(ClothesCache) do
        if data.model and data.model > 0 then
            OldClothesCache[category] = {
                model = data.model,
                texture = data.texture,
                hash = data.hash
            }
        end
    end
    
    CurrentPrice = 0
    
    cb({ success = true })
end)

-- ==========================================
-- NUI CALLBACKS - systems
-- ==========================================

RegisterNUICallback('back', function(data, cb)
    -- Debug processes if initiated correctly
    if currentMode == 'creator' and IsInCharCreation then
        cb('blocked')
        return
    end
    
    if currentMode == 'shop' then
        CloseHTML()
    end
    
    cb('ok')
end)

RegisterNUICallback('close', function(data, cb)
    -- No confirmation in load procedures
    if currentMode == 'creator' and IsInCharCreation then
        cb('blocked')
        return
    end
    
    CloseHTML()
    cb('ok')
end)

-- Old settings
RegisterNUICallback('rotatePedLeft', function(data, cb)
    RotateCreatorPedLeft()
    cb('ok')
end)

RegisterNUICallback('rotatePedRight', function(data, cb)
    RotateCreatorPedRight()
    cb('ok')
end)

-- Loading components data
RegisterNUICallback('moveCamera', function(data, cb)
    local position = data.position or 'reset'
    
    if position == 'up' then
        MoveCreatorCamera('up')
    elseif position == 'down' then
        MoveCreatorCamera('down')
    elseif position == 'in' then
        MoveCreatorCamera('in')
    elseif position == 'out' then
        MoveCreatorCamera('out')
    elseif position == 'reset' then
-- Define settings for appearance
        ResetCreatorCamera()
    end
    
    cb('ok')
end)

-- ==========================================
-- Constants for clarification
-- ==========================================

RegisterNUICallback('randomize', function(data, cb)
    local ped = GetTargetPed()
    local isMale = IsPedMale(ped)
    
    print('[RSG-Appearance] Randomizing appearance')
    
    -- Appearance type or how it should be rendered
    local skinTone = math.random(1, 6)
    
    -- Here - defines how to set up this element
    CreatorCache.head = math.random(1, 20)
    CreatorCache.skin_tone = skinTone
    
    -- List
    CreatorCache.body_size = math.random(1, 5)
    CreatorCache.body_waist = math.random(1, 21)
    CreatorCache.chest_size = math.random(1, 11)
    CreatorCache.height = math.random(95, 105)
    
    -- Ensure list
    local faceFeatures = {
        'head_width', 'face_width', 'jaw_width', 'jaw_height', 
        'chin_width', 'chin_height', 'chin_depth',
        'eyes_depth', 'eyes_angle', 'eyes_distance', 'eyes_height',
        'eyelid_height', 'eyelid_width',
        'nose_width', 'nose_size', 'nose_height', 'nose_angle', 'nose_curvature', 'nostrils_distance',
        'mouth_width', 'mouth_depth', 'mouth_x_pos', 'mouth_y_pos',
        'upper_lip_height', 'upper_lip_width', 'lower_lip_height', 'lower_lip_width',
        'ears_width', 'ears_height', 'ears_size', 'ears_angle',
        'cheekbones_width', 'cheekbones_height', 'cheekbones_depth',
        'eyebrow_height', 'eyebrow_width', 'eyebrow_depth'
    }
    
    for _, feature in ipairs(faceFeatures) do
        CreatorCache[feature] = math.random(-50, 50)
    end
    
    -- Events
    CreatorCache.eyes_color = math.random(5, 18)
    
    -- Help
    local maxHair = isMale and 29 or 35
    local hairModel = math.random(0, maxHair)
    -- Constants help
    if isMale and hairModel == 19 then hairModel = 20 end
    if not isMale and (hairModel == 21 or hairModel == 32) then hairModel = hairModel + 1 end
    
    if not CreatorCache.hair then CreatorCache.hair = {} end
    CreatorCache.hair.model = hairModel
    CreatorCache.hair.color = math.random(1, 15)
    
    -- Selected or highlighted
    if isMale then
        if not CreatorCache.beard then CreatorCache.beard = {} end
        CreatorCache.beard.model = math.random(0, 20)
        CreatorCache.beard.color = math.random(1, 15)
    end
    
    -- Preview
    CreatorCache.eyebrows_t = math.random(1, 15)
    CreatorCache.eyebrows_c1 = math.random(0, 23)
    CreatorCache.eyebrows_op = math.random(50, 100)
    
    -- Status: readjust settings correctly, change quickly in the UI!
    -- How to evaluate appearance settings
    
    -- 1. Add appearance
    FixIssues(ped)
    Wait(100)
    
    -- 2. Reminder list
    LoadBoody(ped, CreatorCache)
    Wait(150)
    
    -- 3. Options that affect skin_tone
    LoadHead(ped, CreatorCache)
    Wait(150)
    
    -- 4. Preview
    LoadEyes(ped, CreatorCache)
    Wait(50)
    LoadFeatures(ped, CreatorCache)
    Wait(50)
    LoadHair(ped, CreatorCache)
    if isMale then
        LoadBeard(ped, CreatorCache)
    end
    Wait(50)
    LoadOverlays(ped, CreatorCache)
    Wait(50)
    LoadHeight(ped, CreatorCache)
    
    -- 5. Adjust list
    LoadBodyFeature(ped, CreatorCache.body_size, Data.Appearance.body_size)
    LoadBodyFeature(ped, CreatorCache.body_waist, Data.Appearance.body_waist)
    LoadBodyFeature(ped, CreatorCache.chest_size, Data.Appearance.chest_size)
    
    Wait(100)
    
    -- 6. Appearance presets
    NativeUpdatePedVariation(ped)
    
    -- 7. Interactive when this behavior is active
    Wait(100)
    LoadBodyFeature(ped, CreatorCache.body_size, Data.Appearance.body_size)
    LoadBodyFeature(ped, CreatorCache.body_waist, Data.Appearance.body_waist)
    LoadBodyFeature(ped, CreatorCache.chest_size, Data.Appearance.chest_size)
    -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
    -- TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', 'creator_model', false, ped)
    
    print('[RSG-Appearance] Randomize complete, skin_tone=' .. tostring(skinTone))
    
    -- Remember to check the UI
    SendNUIMessage({
        action = 'openCreator',
        isMale = isMale,
        cache = CreatorCache,
        scale = uiScale,
        scaleModifier = tonumber(RSG.ScaleModifier) or 0
    })
    
    cb('ok')
end)

-- ==========================================
-- Indicate settings - callback CALLBACKS
-- ==========================================

RegisterNUICallback('selectShopCategory', function(data, cb)
    local category = data.category
    currentClothingCategory = category
    
    print('[RSG-Appearance] Shop category: ' .. tostring(category))
    
    cb('ok')
end)

RegisterNUICallback('updateShopClothes', function(data, cb)
    local category = data.category
    local valueType = data.type
    local value = data.value
    local ped = PlayerPedId()
    
    if not category then
        cb('ok')
        return
    end
    
    -- Read settings
    if not ClothesCache[category] then
        ClothesCache[category] = { model = 0, texture = 1 }
    end
    
    ClothesCache[category][valueType] = value
    
    -- Additional settings
    local model = ClothesCache[category].model or 0
    local texture = ClothesCache[category].texture or 1
    
    if model > 0 then
        local isMale = IsPedMale(ped)
        local hash = GetHashFromModelTexture(category, model, texture, isMale)
        
        if hash and hash ~= 0 then
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
        end
    else
        -- Adjust settings
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(category), 0)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
    end
    
    cb('ok')
end)

RegisterNUICallback('purchaseClothes', function(data, cb)
    local clothesCache = data.cache or {}
    local total = data.total or 0
    
    -- Transform to list those elements that are selected
    TriggerServerEvent('rsg-appearance:server:purchaseClothes', clothesCache, total)
    
    CloseHTML()
    cb('ok')
end)

RegisterNUICallback('exitShop', function(data, cb)
    -- Configuration options look
    if OldClothesCache then
        local ped = PlayerPedId()
        TriggerEvent('rsg-appearance:client:ApplyClothes', OldClothesCache, ped)
    end
    
    CloseHTML()
    cb('ok')
end)

RegisterNUICallback('cancelCreator', function(data, cb)
    print('[RSG-Appearance] cancelCreator called')
    
    -- Adjust UI
    CloseHTML()
    
    -- Read from filled array
    if CreatorPed and DoesEntityExist(CreatorPed) then
        DeleteEntity(CreatorPed)
        CreatorPed = nil
    end
    
    -- Initial settings
    if CreatorCam and DoesCamExist(CreatorCam) then
        SetCamActive(CreatorCam, false)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(CreatorCam, false)
        CreatorCam = nil
    end
    
    -- Adjusted state
    IsInCharCreation = false
    Skinkosong = false
    KeepClothesOnSave = false
    
    -- Requested settings
    local playerPed = PlayerPedId()
    SetEntityVisible(playerPed, true)
    SetEntityInvincible(playerPed, false)
    NetworkSetEntityInvisibleToNetwork(playerPed, false)
    FreezeEntityPosition(playerPed, false)
    
    -- For /editappearance: adjust settings from here, that is, get options quicker
    local wasEditAppearance = (EditAppearanceReturnPos ~= nil)
    if EditAppearanceReturnPos then
        SetEntityCoords(playerPed, EditAppearanceReturnPos.x, EditAppearanceReturnPos.y, EditAppearanceReturnPos.z, false, false, false, false)
        SetEntityHeading(playerPed, EditAppearanceReturnPos.h)
        EditAppearanceReturnPos = nil
    end
    
    -- Objective in different views
    TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', 0, false)
    
    if not wasEditAppearance then
        TriggerEvent('rsg-multicharacter:client:chooseChar')
    end
    
    cb('ok')
end)

-- Additional constants render hash
function GetHashFromModelTexture(category, model, texture, isMale)
    local gender = isMale and 'male' or 'female'
    
    if clothing[gender] and clothing[gender][category] then
        if clothing[gender][category][model] then
            if clothing[gender][category][model][texture] then
                return clothing[gender][category][model][texture].hash
            elseif clothing[gender][category][model][1] then
                return clothing[gender][category][model][1].hash
            end
        end
    end
    
    return 0
end

-- ==========================================
-- Reminder
-- ==========================================

exports('OpenCreatorHTML', OpenCreatorHTML)
exports('OpenShopHTML', OpenShopHTML)
exports('CloseHTML', CloseHTML)
exports('IsHTMLOpen', function() return isUIOpen end)

-- ==========================================
-- System accessing the function
-- ==========================================

-- Identifiers are practically identifiers set
RegisterNetEvent('rsg-appearance:client:openClothingShop', function()
    OpenShopHTML()
end)

-- Documentation help
AddEventHandler('rsg-clothing:client:openShop', function()
    OpenShopHTML()
end)

-- ==========================================
-- Helpful properties list
-- ==========================================

CreateThread(function()
    while true do
        Wait(0)
        
        if isUIOpen then
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            
            -- List
            EnableControlAction(0, 239, true) -- cursor x
            EnableControlAction(0, 240, true) -- cursor y
            EnableControlAction(0, 237, true) -- scroll up
            EnableControlAction(0, 238, true) -- scroll down
            EnableControlAction(0, 31, true)  -- mouse input

            -- Mouse wheel camera zoom in/out
            if currentMode == 'creator' then
                if IsDisabledControlJustPressed(0, 237) then
                    MoveCreatorCamera('in')
                elseif IsDisabledControlJustPressed(0, 238) then
                    MoveCreatorCamera('out')
                end
            end

            -- Hold LMB and drag to rotate ped around its axis
            if currentMode == 'creator' and CreatorPed and DoesEntityExist(CreatorPed) then
                local cursorX = GetDisabledControlNormal(0, 239)
                local cursorY = GetDisabledControlNormal(0, 240)
                local lmbPressed = IsDisabledControlPressed(0, GetHashKey("INPUT_ATTACK"))

                if lmbPressed then
                    if not isMouseDraggingPed then
                        if IsCursorOverPedArea(cursorX, cursorY) then
                            isMouseDraggingPed = true
                            lastMouseX = cursorX
                        end
                    else
                        if lastMouseX ~= nil then
                            local deltaX = cursorX - lastMouseX
                            if math.abs(deltaX) > 0.0005 then
                                local heading = GetEntityHeading(CreatorPed)
                                SetEntityHeading(CreatorPed, heading - (deltaX * 260.0))
                            end
                        end
                        lastMouseX = cursorX
                    end
                else
                    isMouseDraggingPed = false
                    lastMouseX = nil
                end
            else
                isMouseDraggingPed = false
                lastMouseX = nil
            end
            
            -- Instructions available
            -- A - Add settings
            if IsControlJustPressed(0, 0x7065027D) then -- INPUT_MOVE_LEFT_ONLY (A)
                RotateCreatorPedLeft()
            end
            
            -- D - Adjust list
            if IsControlJustPressed(0, 0xB4E465B4) then -- INPUT_MOVE_RIGHT_ONLY (D)
                RotateCreatorPedRight()
            end
            
            -- W - Help section
            if IsControlJustPressed(0, 0x8FD015D8) then -- INPUT_MOVE_UP_ONLY (W)
                MoveCreatorCamera('up')
            end
            
            -- S - List options
            if IsControlJustPressed(0, 0xD27782E3) then -- INPUT_MOVE_DOWN_ONLY (S)
                MoveCreatorCamera('down')
            end
            
            -- ESC while active - redirects to initial, so press multiple times
            if IsControlJustPressed(0, 0x156F7119) then -- INPUT_FRONTEND_CANCEL
                if currentMode == 'shop' then
                    CloseHTML()
                end
                -- List options for ESC throwback
            end
        end
    end
end)

print('[RSG-Appearance] HTML UI v3.0 loaded - rsg-menubase replaced')
