RSGCore = exports['rsg-core']:GetCoreObject()
local isLoggedIn = false
BucketId = GetRandomIntInRange(0, 0xffffff)
ComponentsMale = {}
ComponentsFemale = {}
LoadedComponents = {}
CreatorCache = {}
CreatorPed = nil
IsInCharCreation = false
-- ? what is happening in the game: how to change the appearance of characters, their faces
KeepClothesOnSave = false
-- ? what variable for /editappearance: { x, y, z, h }
EditAppearanceReturnPos = nil

-- ★ NAKED BODY SYSTEM
CurrentSkinData = CurrentSkinData or {}

MenuData = {}

TriggerEvent("rsg-menubase:getData", function(call)
    MenuData = call
end)

Firstname = nil
Lastname = nil
Nationality = nil
Selectedsex = nil
Birthdate = nil
Cid = nil

local Data = require 'data.features'
local Overlays = require 'data.overlays'
local clotheslist = require 'data.clothes_list'
local hairs_list = require 'data.hairs_list'
local extraRDR2Hairs = require 'data.extra_rdr2_hairs'
extraRDR2Hairs.MergeExtraRDR2Hairs(hairs_list)
local appearanceApplyToken = 0

-- ? what is happening in the system (how to handle loaded components)
local function deep_copy_skin(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        out[k] = (type(v) == "table" and not (k == "components" or k == "stateBag")) and deep_copy_skin(v) or v
    end
    return out
end

-- ? create a cache for the creator at position 0 - what is happening in the system
-- function SaveSkin, what is in the attributes such as face features and overlays
local BodyMorphFeatureNames = { waist_width = true, chest_size = true, hips_size = true, arms_size = true,
    tight_size = true, calves_size = true, uppr_shoulder_size = true, back_shoulder_thickness = true, back_muscle = true }
function EnsureFullCreatorCache()
    CreatorCache = CreatorCache or {}
    for featName, _ in pairs(Data.features) do
        if not BodyMorphFeatureNames[featName] and CreatorCache[featName] == nil then
            CreatorCache[featName] = 0
        end
    end
    local overlayDefaults = {
        eyebrows_t = 1, eyebrows_op = 100, eyebrows_id = 10, eyebrows_c1 = 0,
        scars_t = 1, scars_op = 0, ageing_t = 1, teeth = 1
    }
    for k, v in pairs(overlayDefaults) do
        if CreatorCache[k] == nil then CreatorCache[k] = v end
    end
    if CreatorCache.breast_size == nil then CreatorCache.breast_size = 0 end
    if CreatorCache.back_muscle == nil then CreatorCache.back_muscle = 0 end
    if CreatorCache.back_shoulder_thickness == nil then CreatorCache.back_shoulder_thickness = 0 end
    if CreatorCache.uppr_shoulder_size == nil then CreatorCache.uppr_shoulder_size = 0 end
    if CreatorCache.arms_size == nil then CreatorCache.arms_size = 0 end
    if CreatorCache.waist_width == nil then CreatorCache.waist_width = 0 end
    if CreatorCache.hips_size == nil then CreatorCache.hips_size = 0 end
    if CreatorCache.tight_size == nil then CreatorCache.tight_size = 0 end
    if CreatorCache.calves_size == nil then CreatorCache.calves_size = 0 end
    if not CreatorCache.hair or type(CreatorCache.hair) ~= "table" then
        CreatorCache.hair = { model = 0, color = 1, texture = 1 }
    end
    if not CreatorCache.beard or type(CreatorCache.beard) ~= "table" then
        CreatorCache.beard = { model = 0, color = 1, texture = 1 }
    end
end

exports('GetClothesList', function()
    return clotheslist
end)

exports('GetHairsList', function()
    return hairs_list
end)

-- ? function: UpdatePedVariation (0xCC8CA3E88256E58F) updates overlays - what should be the next for generic needs?
AddEventHandler('rsg-appearance:client:afterPedVariation', function()
    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return end
    if LoadedComponents and type(LoadedComponents) == 'table' and next(LoadedComponents) and LoadOverlays then
        LoadOverlays(ped, LoadedComponents)
    end
end)

-- ==========================================
-- ? BODY MORPH: check in creator.lua
-- ? important note: how character is created in the system (how to Wait/UpdatePedVariation)
-- ==========================================
function ApplyAndSaveBodyMorph(ped, skinData)
    if not skinData then return end
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end

    LoadedComponents = LoadedComponents or {}
    LoadedComponents.body_size = skinData.body_size
    LoadedComponents.body_waist = skinData.body_waist
    LoadedComponents.chest_size = skinData.chest_size
    LoadedComponents.breast_size = skinData.breast_size
    LoadedComponents.back_muscle = skinData.back_muscle
    LoadedComponents.back_shoulder_thickness = skinData.back_shoulder_thickness
    LoadedComponents.uppr_shoulder_size = skinData.uppr_shoulder_size
    LoadedComponents.arms_size = skinData.arms_size
    LoadedComponents.waist_width = skinData.waist_width
    LoadedComponents.hips_size = skinData.hips_size
    LoadedComponents.tight_size = skinData.tight_size
    LoadedComponents.calves_size = skinData.calves_size
    LoadedComponents.height = skinData.height

    -- ? important note: face + features, how to Wait/UpdatePedVariation
    -- (how this is working in the system)
    ApplyAllBodyMorph(ped, skinData)
end

-- ? important note: how character is modified (how to Wait + UpdatePedVariation + what to do after?)
function ApplyAndSaveBodyMorphFull(ped, skinData)
    if not skinData then return end
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end

    LoadedComponents = LoadedComponents or {}
    LoadedComponents.body_size = skinData.body_size
    LoadedComponents.body_waist = skinData.body_waist
    LoadedComponents.chest_size = skinData.chest_size
    LoadedComponents.breast_size = skinData.breast_size
    LoadedComponents.back_muscle = skinData.back_muscle
    LoadedComponents.back_shoulder_thickness = skinData.back_shoulder_thickness
    LoadedComponents.uppr_shoulder_size = skinData.uppr_shoulder_size
    LoadedComponents.arms_size = skinData.arms_size
    LoadedComponents.waist_width = skinData.waist_width
    LoadedComponents.hips_size = skinData.hips_size
    LoadedComponents.tight_size = skinData.tight_size
    LoadedComponents.calves_size = skinData.calves_size
    LoadedComponents.height = skinData.height

    -- ? important note: face + UpdatePedVariation + generic face features
    LoadAllBodyShape(ped, skinData)
end

-- ==========================================
-- information printed
-- ==========================================

function FixIssues(ped)
    if not ped or not DoesEntityExist(ped) then
        ped = PlayerPedId()
    end

    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("heads"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("eyes"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("hair"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("teeth"), 0)

    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("shirts_full"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("pants"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("boots"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("vests"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("coats"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("coats_closed"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("hats"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("gloves"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("neckwear"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("chaps"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("masks"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("suspenders"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("cloaks"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("ponchos"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("spurs"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("eyewear"), 0)

    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("gunbelts"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("loadouts"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_left"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_right"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("belt_buckles"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_crossdraw"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_knife"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("accessories"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("satchels"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("belts"), 0)

    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x0662AC34, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xB6B6122D, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x777EC6EF, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x485EE834, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xE06D47B7, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x9925C067, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xF1542D11, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x9B2C8B89, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x877A2CF7, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x72E6EF74, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x3F1F01E5, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xDA0E2C55, 0)

    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)

    print('[RSG-Appearance] FixIssues: All components cleared for ped ' .. tostring(ped))
    return true
end

-- ? important data (how to head/hair/eyes) - how loadcharacter: what is loaded from LoadClothingFromInventory
function StripClothesOnly(ped)
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("shirts_full"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("pants"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("skirts"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("dresses"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("aprons"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("boots"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("vests"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("coats"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("coats_closed"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("hats"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("gloves"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("gauntlets"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("neckwear"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("neckties"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("chaps"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("masks"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("suspenders"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("cloaks"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("ponchos"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("spurs"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("eyewear"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("gunbelts"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("loadouts"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_left"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_right"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("belt_buckles"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_crossdraw"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_knife"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("accessories"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("satchels"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("belts"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x0662AC34, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xB6B6122D, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x777EC6EF, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x485EE834, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xE06D47B7, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x9925C067, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xF1542D11, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x9B2C8B89, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x877A2CF7, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x72E6EF74, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x3F1F01E5, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xDA0E2C55, 0)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    Wait(150)
end

exports('StripClothesOnly', StripClothesOnly)

function FixIssuesLight(ped)
    if not ped or not DoesEntityExist(ped) then
        ped = PlayerPedId()
    end

    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("gunbelts"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("loadouts"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_left"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("holsters_right"), 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xF1542D11, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x9B2C8B89, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x877A2CF7, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x3F1F01E5, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xDA0E2C55, 0)

    print('[RSG-Appearance] FixIssuesLight: Cleared gunbelts only')
    return true
end

local CreatorCoords = {
    male = {x = -559.6, y = -3781.0, z = 237.55, h = 110.0},
    female = {x = -559.6, y = -3781.0, z = 237.55, h = 110.0}
}

local CreatorCameraPos = {
    x = -559.909, y = -3776.3, z = 239.1,
    pitch = -10.0, roll = 0.0, yaw = 270.0, fov = 50.0
}

local CreatorImaps = {
    -1699673416,
    1679934574,
    183712523,
}

local CreatorCam = nil
local gPeds = {}
local ImapsLoaded = false

-- ? FIX: using Request (0x59BD177A1A48600A) to Apply - what is happening reasonably?
-- what Request returns to the system
local function NativeSetPedComponentEnabled(ped, componentHash)
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, componentHash)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, componentHash, true, true, true)
end

local function NativeHasPedComponentLoaded(ped)
    return Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped)
end

local function NativeUpdatePedVariation(ped)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

local function NativeRemoveComponent(ped, categoryHash)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, categoryHash, 0)
end

local function LoadImaps()
    if ImapsLoaded then return end
    for _, imap in pairs(CreatorImaps) do
        RequestImap(imap)
    end
    ImapsLoaded = true
    Wait(500)
end

function SpawnPeds()
    print('[RSG-Appearance] SpawnPeds started, Selectedsex=' .. tostring(Selectedsex))

    DoScreenFadeOut(300)
    Wait(300)

    if CreatorPed and DoesEntityExist(CreatorPed) then
        DeleteEntity(CreatorPed)
        CreatorPed = nil
    end

    TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', BucketId)
    Wait(100)

    LoadImaps()

    Selectedsex = Selectedsex or 1
    if Skinkosong and CreatorCache and CreatorCache.sex then
        Selectedsex = CreatorCache.sex
    end
    local isMale = Selectedsex == 1
    local modelName = isMale and 'mp_male' or 'mp_female'
    local gender = isMale and 'male' or 'female'
    local coords = isMale and CreatorCoords.male or CreatorCoords.female

    print('[RSG-Appearance] Creating ped: ' .. modelName)

    local modelHash = GetHashKey(modelName)
    RequestModel(modelHash, false)

    -- ? FIX: use variations of what is stored (though implemented 15? parameters loosely)
    local loadTimeout = 0
    while not HasModelLoaded(modelHash) and loadTimeout < 300 do
        Wait(50)
        loadTimeout = loadTimeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        print('[RSG-Appearance] Model load TIMEOUT for ' .. modelName .. '! Retrying...')
        RequestModel(modelHash, false)
        local retryTimeout = 0
        while not HasModelLoaded(modelHash) and retryTimeout < 200 do
            Wait(50)
            retryTimeout = retryTimeout + 1
        end
        if not HasModelLoaded(modelHash) then
            print('[RSG-Appearance] Model load FAILED after retry!')
            DoScreenFadeIn(300)
            return
        end
    end

    CreatorPed = CreatePed(modelHash, coords.x, coords.y, coords.z, coords.h, true, false, false, false)

    if not DoesEntityExist(CreatorPed) then
        print('[RSG-Appearance] Failed to create ped!')
        DoScreenFadeIn(300)
        return
    end

    print('[RSG-Appearance] Ped created: ' .. tostring(CreatorPed))

    Citizen.InvokeNative(0x283978A15512B2FE, CreatorPed, true)
    Citizen.InvokeNative(0x58A850EAEE20FAA3, CreatorPed)

    -- ? FIX: how the guard is checking position on graph (very generic 100??)
    local readyT = 0
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, CreatorPed) and readyT < 100 do
        Wait(50)
        readyT = readyT + 1
    end
    Wait(200)

    NetworkSetEntityInvisibleToNetwork(CreatorPed, true)
    SetEntityHeading(CreatorPed, coords.h)
    FreezeEntityPosition(CreatorPed, true)

    local playerPed = PlayerPedId()
    SetEntityInvincible(playerPed, true)
    SetEntityVisible(playerPed, false)
    NetworkSetEntityInvisibleToNetwork(playerPed, true)
    -- ? FIX: what parameters to set to z+2 - what should be the right coordinates for the area of attention in terms of position?
    SetEntityCoords(playerPed, coords.x, coords.y, coords.z, false, false, false, false)

    -- ? what editappearance: CreatorCache check to area, how washing?
    if not Skinkosong then
        CreatorCache = {
            sex = Selectedsex,
            head = isMale and 18 or 2,
            skin_tone = 1,
            body_size = 3,
            body_waist = 11,
            chest_size = 6,
            breast_size = 0,
            back_muscle = 0,
            back_shoulder_thickness = 0,
            uppr_shoulder_size = 0,
            arms_size = 0,
            waist_width = 0,
            hips_size = 0,
            tight_size = 0,
            calves_size = 0,
            height = 100,
            hair = { model = 0, color = 1 },
            beard = { model = 0, color = 1 },
            eyes_color = 5,
        }
    end

    ApplyCreatorComponents(CreatorPed, gender, CreatorCache)

    FixIssues(CreatorPed)
    Wait(200)

    if not isMale and ApplyFemaleMpMetaBasePreset then
        ApplyFemaleMpMetaBasePreset(CreatorPed)
    end

    -- ? FIX: using shared systems to monitor what needs to be confirmed?
    LoadBoody(CreatorPed, CreatorCache)
    Wait(300)
    LoadHead(CreatorPed, CreatorCache)
    Wait(200)
    LoadEyes(CreatorPed, CreatorCache)
    Wait(100)

    -- Load hair and beard when opening via /editappearance (Skinkosong = skin loaded from DB)
    if Skinkosong then
        LoadHair(CreatorPed, CreatorCache)
        Wait(150)
        LoadBeard(CreatorPed, CreatorCache)
        Wait(100)
    end

    -- ? fully shown profile overlays (face features included, very visually wrap)
    LoadBodyFeature(CreatorPed, CreatorCache.body_waist or 11, Data.Appearance.body_waist)
    LoadBodyFeature(CreatorPed, CreatorCache.body_size or 3, Data.Appearance.body_size)
    LoadBodyFeature(CreatorPed, CreatorCache.chest_size or 6, Data.Appearance.chest_size)
    LoadHeight(CreatorPed, CreatorCache)

    NativeRemoveComponent(CreatorPed, GetHashKey("pants"))

    NativeUpdatePedVariation(CreatorPed)
    -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
    -- TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', 'creator_model', false, CreatorPed)

    CreateCreatorCamera()

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    StartCreatorLighting()

    Wait(550)
    DoScreenFadeIn(300)

    print('[RSG-Appearance] SpawnPeds completed')

    IsInCharCreation = true
    if Skinkosong then
        OpenCreatorHTML('customize')
    else
        FirstMenu()
    end
end

function ApplyCreatorComponents(ped, gender, cache)
    local componentsData = require 'data.clothes_list'

    local categories = {}
    for _, item in ipairs(componentsData) do
        if item.ped_type == gender and item.is_multiplayer then
            local cat = item.category_hashname
            if not categories[cat] then
                categories[cat] = {}
            end
            if item.hashname and item.hashname ~= "" then
                table.insert(categories[cat], item.hash)
            end
        end
    end

    -- ? what layers 20??? covered: effectively different slots to take (20 x 6 needs = 120)
    if categories['heads'] and #categories['heads'] > 120 then
        for i = 121, #categories['heads'] do categories['heads'][i] = nil end
    end

    local headIndex = math.max(1, math.min(20, cache.head or 1))
    local skinTone = cache.skin_tone or 1

    if categories['heads'] and #categories['heads'] > 0 then
        local tonesPerModel = 6
        local idx = ((headIndex - 1) * tonesPerModel) + math.min(skinTone, tonesPerModel)
        idx = math.min(idx, #categories['heads'])
        local hash = categories['heads'][idx]
        if hash then
            NativeSetPedComponentEnabled(ped, hash)
            WaitForComponent(ped, hash)
        end
    end

    if categories['BODIES_UPPER'] and #categories['BODIES_UPPER'] > 0 then
        local idx = math.min(skinTone, #categories['BODIES_UPPER'])
        local hash = categories['BODIES_UPPER'][idx]
        if hash then
            NativeSetPedComponentEnabled(ped, hash)
            WaitForComponent(ped, hash)
        end
    end

    if categories['eyes'] and #categories['eyes'] > 0 then
        local eyeColor = cache.eyes_color or 1
        local idx = math.min(eyeColor, #categories['eyes'])
        local hash = categories['eyes'][idx]
        if hash then
            NativeSetPedComponentEnabled(ped, hash)
            WaitForComponent(ped, hash)
        end
    end

    if categories['teeth'] and #categories['teeth'] > 0 then
        local hash = categories['teeth'][1]
        if hash then
            NativeSetPedComponentEnabled(ped, hash)
            WaitForComponent(ped, hash)
        end
    end
end

function GetComponentHash(categoryItems, modelIndex, textureIndex)
    local idx = ((modelIndex - 1) * 6) + textureIndex
    if idx < 1 then idx = 1 end
    if idx > #categoryItems then idx = #categoryItems end
    return categoryItems[idx] and categoryItems[idx].hash
end

-- ? FIX: running calculations in the 500?? until 3? was proceeded?
-- time varies - has loops outputs
function WaitForComponent(ped, componentHash)
    local timeout = 0
    while not NativeHasPedComponentLoaded(ped) and timeout < 150 do
        Wait(20)
        timeout = timeout + 1
    end
    if timeout >= 150 and componentHash then
        print('[RSG-Appearance] WaitForComponent timeout, retrying hash: ' .. tostring(componentHash))
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, componentHash)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, componentHash, true, true, true)
        local t2 = 0
        while not NativeHasPedComponentLoaded(ped) and t2 < 100 do
            Wait(20)
            t2 = t2 + 1
        end
    end
end

function CreateCreatorCamera()
    DestroyAllCams(true)

    local camX = -561.4157
    local camY = -3780.966
    local camZ = 239.005
    local pitch = -4.2146
    local roll = -0.0007
    local yaw = -93.8802
    local fov = 35.0

    CreatorCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(CreatorCam, camX, camY, camZ)
    SetCamRot(CreatorCam, pitch, roll, yaw, 2)
    SetCamFov(CreatorCam, fov)
    SetCamActive(CreatorCam, true)
    RenderScriptCams(true, false, 500, true, true)

    local isMale = Selectedsex == 1
    local coords = isMale and CreatorCoords.male or CreatorCoords.female
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
end

function DestroyCreatorCamera()
    StopCreatorLighting()
    IsInCharCreation = false

    DestroyAllCams(true)
    RenderScriptCams(false, true, 500, true, true)

    if CreatorPed and DoesEntityExist(CreatorPed) then
        DeleteEntity(CreatorPed)
        CreatorPed = nil
    end

    local playerPed = PlayerPedId()
    SetFocusEntity(playerPed)
    SetEntityInvincible(playerPed, false)
    SetEntityVisible(playerPed, true)
    NetworkSetEntityInvisibleToNetwork(playerPed, false)

    TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', 0)
end

function GetCreatorPed()
    return CreatorPed
end

exports('DestroyCreatorCamera', DestroyCreatorCamera)
exports('GetCreatorPed', GetCreatorPed)

-- ==========================================
-- notice
-- ==========================================

local LightingThread = nil
local IsLightingActive = false

function StartCreatorLighting()
    if IsLightingActive then return end
    IsLightingActive = true

    pcall(function()
        exports.weathersync:setSyncEnabled(false)
        exports.weathersync:setMyWeather("sunny", 0)
        exports.weathersync:setMyTime(12, 0, 0, 0, 1)
    end)

    LightingThread = CreateThread(function()
        while IsLightingActive and IsInCharCreation do
            Wait(0)
            Citizen.InvokeNative(0x669E223E64B1903C, 12, 0, 0)
            if CreatorPed and DoesEntityExist(CreatorPed) then
                local pedCoords = GetEntityCoords(CreatorPed)
                DrawLightWithRange(pedCoords.x - 2.0, pedCoords.y, pedCoords.z + 1.0, 255, 255, 255, 5.0, 500.0)
                DrawLightWithRange(pedCoords.x - 1.0, pedCoords.y + 1.5, pedCoords.z + 0.5, 255, 255, 255, 4.0, 300.0)
                DrawLightWithRange(pedCoords.x - 1.0, pedCoords.y - 1.5, pedCoords.z + 0.5, 255, 255, 255, 4.0, 300.0)
                DrawLightWithRange(pedCoords.x, pedCoords.y, pedCoords.z + 2.5, 255, 255, 255, 5.0, 400.0)
            end
        end
    end)
end

function StopCreatorLighting()
    IsLightingActive = false
    pcall(function()
        exports.weathersync:setSyncEnabled(true)
    end)
end

function RotateCreatorPedLeft()
    if CreatorPed and DoesEntityExist(CreatorPed) then
        SetEntityHeading(CreatorPed, GetEntityHeading(CreatorPed) - 15.0)
    end
end

function RotateCreatorPedRight()
    if CreatorPed and DoesEntityExist(CreatorPed) then
        SetEntityHeading(CreatorPed, GetEntityHeading(CreatorPed) + 15.0)
    end
end

exports('StartCreatorLighting', StartCreatorLighting)
exports('StopCreatorLighting', StopCreatorLighting)
exports('RotateCreatorPedLeft', RotateCreatorPedLeft)
exports('RotateCreatorPedRight', RotateCreatorPedRight)

local CameraOffsetZ = 0.0
local CameraZoom = 0.0

function MoveCreatorCamera(direction)
    if not CreatorCam or not DoesCamExist(CreatorCam) then return end

    if direction == 'up' then
        CameraOffsetZ = CameraOffsetZ + 0.3
    elseif direction == 'down' then
        CameraOffsetZ = CameraOffsetZ - 0.3
    elseif direction == 'in' then
        CameraZoom = CameraZoom + 0.5
    elseif direction == 'out' then
        CameraZoom = CameraZoom - 0.5
    end

    CameraOffsetZ = math.max(-1.5, math.min(1.5, CameraOffsetZ))
    CameraZoom = math.max(-2.0, math.min(3.0, CameraZoom))

    SetCamCoord(CreatorCam, -561.4157 + CameraZoom, -3780.966, 239.005 + CameraOffsetZ)

    if CreatorPed and DoesEntityExist(CreatorPed) then
        local pedCoords = GetEntityCoords(CreatorPed)
        PointCamAtCoord(CreatorCam, pedCoords.x, pedCoords.y, pedCoords.z + 0.5 + CameraOffsetZ)
    end
end

function ResetCameraOffsets()
    CameraOffsetZ = 0.0
    CameraZoom = 0.0
end

function ResetCreatorCamera()
    if not CreatorCam or not DoesCamExist(CreatorCam) then return end
    CameraOffsetZ = 0.0
    CameraZoom = 0.0
    SetCamCoord(CreatorCam, -561.4157, -3780.966, 239.005)
    if CreatorPed and DoesEntityExist(CreatorPed) then
        local pedCoords = GetEntityCoords(CreatorPed)
        PointCamAtCoord(CreatorCam, pedCoords.x, pedCoords.y, pedCoords.z + 0.5)
    end
end

exports('MoveCreatorCamera', MoveCreatorCamera)
exports('ResetCreatorCamera', ResetCreatorCamera)

function LoadModel(ped, model)
    local isMpModel = (model == `mp_male` or model == `mp_female` or model == GetHashKey("mp_male") or model == GetHashKey("mp_female"))

    RequestModel(model, false)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        return false
    end

    Citizen.InvokeNative(0x00A1CADD00108836, PlayerId(), model, false, false, false, false)
    Wait(1000)

    local newPed = PlayerPedId()
    if isMpModel then
        Citizen.InvokeNative(0x283978A15512B2FE, newPed, true)
        Wait(500)
    end

    SetModelAsNoLongerNeeded(model)
    return true
end

-- ==========================================
-- showing only?
-- ==========================================

-- ? what would be: where the setups for needs (how immediate)
_G._SkinAppliedThisSession = false

-- ==========================================
-- ? detail processed to overlays
-- ==========================================

local function underMapMaxZ()
    local s = RSG and RSG.UnderMapSafety
    if s and type(s.MaxZForTeleport) == 'number' then
        return s.MaxZForTeleport
    end
    return -7.0
end

local function underMapSafetySettings()
    return RSG and RSG.UnderMapSafety
end

--- if Z <= ? : how huge expectations are lasting in cases of devices vs current near X/Y.
--- ? UseFallbackCoords what functional can be considered - how specifics will be adapted per media type.
local function TeleportToSafeGroundIfNeeded(ped)
    if not ped or not DoesEntityExist(ped) then return end

    local safety = underMapSafetySettings()
    if safety and safety.Enabled == false then
        return
    end

    local coords = GetEntityCoords(ped)
    local maxZ = underMapMaxZ()
    if coords.z > maxZ then
        return
    end

    local x, y = coords.x, coords.y

    local waitMs = 2000
    if safety and type(safety.WaitForCollisionMs) == 'number' and safety.WaitForCollisionMs >= 0 then
        waitMs = safety.WaitForCollisionMs
    end
    if waitMs > 0 then
        RequestCollisionAtCoord(x, y, coords.z)
        local deadline = GetGameTimer() + waitMs
        while GetGameTimer() < deadline do
            if HasCollisionLoadedAroundEntity(ped) then
                break
            end
            Wait(0)
        end
    end

    -- ? current data - how are changes fixed coords.z+50 measuring into what qualities?
    local groundZ = nil
    for probeZ = 1200.0, -150.0, -25.0 do
        local ok, z = GetGroundZFor_3dCoord(x, y, probeZ + 0.0, false)
        if ok and z and z > maxZ + 1.0 and z > coords.z + 1.0 then
            groundZ = z
            break
        end
    end

    if groundZ then
        SetEntityCoords(ped, x, y, groundZ + 1.0, false, false, false, false)
        return
    end

    local useFb = safety and safety.UseFallbackCoords == true
    local fb = useFb and safety.FallbackCoords
    if fb then
        local fx, fy, fz, fh = fb.x, fb.y, fb.z, fb.w or 0.0
        SetEntityCoords(ped, fx, fy, fz, false, false, false, false)
        SetEntityHeading(ped, fh)
    end
end

AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    PlayerData = RSGCore.Functions.GetPlayerData()

    -- ? working as check (vs ApplySkin): overseeing structural layers need updating procedures
    local delays = { 1500, 4500, 9000 }
    for _, ms in ipairs(delays) do
        SetTimeout(ms, function()
            if not isLoggedIn then return end
            TeleportToSafeGroundIfNeeded(PlayerPedId())
        end)
    end
    
    -- ? cases: in rates structure 6 units kind on timely - justified for how it works
    -- or layering 'not safe for net' structures into retire systems target necessities
    _G._SkinAppliedThisSession = false
    SetTimeout(6000, function()
        if not _G._SkinAppliedThisSession then
            print('[RSG-Appearance] Fallback: Skin was NOT applied after 6s, requesting from server...')
            TriggerServerEvent('rsg-appearance:server:LoadSkin')
        end
    end)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    PlayerData = {}
end)

RegisterNetEvent('rsg-spawn:client:spawned', function()
    SetTimeout(600, function()
        if not isLoggedIn then return end
        TeleportToSafeGroundIfNeeded(PlayerPedId())
    end)
end)

local MainMenus = {
    ["body"] = function() OpenBodyMenu() end,
    ["face"] = function() OpenFaceMenu() end,
    ["hair"] = function() OpenHairMenu() end,
    ["makeup"] = function() OpenMakeupMenu() end
}

local BodyFunctions = {
    ["head"] = function(target, data)
        LoadHead(target, data)
        LoadOverlays(target, data)
    end,
    ["face_width"] = function(target, data) LoadFeatures(target, data) end,
    ["skin_tone"] = function(target, data)
        LoadBoody(target, data)
        LoadOverlays(target, data)
        -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
        -- if target ~= PlayerPedId() then
        --     TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', 'creator_model', false, target)
        -- end
    end,
    ["body_size"] = function(target, data)
        LoadBodyFeature(target, data.body_size, Data.Appearance.body_size)
        LoadBoody(target, data)
    end,
    ["body_waist"] = function(target, data)
        -- ? Clamp issues - how necessary overall formats should be considered?
        local waistIdx = data.body_waist or 11
        if waistIdx > #Data.Appearance.body_waist then
            waistIdx = #Data.Appearance.body_waist
        end
        LoadBodyFeature(target, waistIdx, Data.Appearance.body_waist)
    end,
    ["chest_size"] = function(target, data)
        LoadBodyFeature(target, data.chest_size, Data.Appearance.chest_size)
    end,
    ["height"] = function(target, data) LoadHeight(target, data) end
}

local FaceFunctions = {
    ["eyes"] = function() OpenEyesMenu() end,
    ["eyelids"] = function() OpenEyelidsMenu() end,
    ["eyebrows"] = function() OpenEyebrowsMenu() end,
    ["nose"] = function() OpenNoseMenu() end,
    ["mouth"] = function() OpenMouthMenu() end,
    ["cheekbones"] = function() OpenCheekbonesMenu() end,
    ["jaw"] = function() OpenJawMenu() end,
    ["ears"] = function() OpenEarsMenu() end,
    ["chin"] = function() OpenChinMenu() end,
    ["defects"] = function() OpenDefectsMenu() end
}

local HairFunctions = {
    ["hair"] = function(target, data) LoadHair(target, data) end,
    ["beard"] = function(target, data) LoadBeard(target, data) end
}

local EyesFunctions = {
    ["eyes_color"] = function(target, data) LoadEyes(target, data) end,
    ["eyes_depth"] = function(target, data) LoadFeatures(target, data) end,
    ["eyes_angle"] = function(target, data) LoadFeatures(target, data) end,
    ["eyes_distance"] = function(target, data) LoadFeatures(target, data) end
}

local EyelidsFunctions = {
    ["eyelid_height"] = function(target, data) LoadFeatures(target, data) end,
    ["eyelid_width"] = function(target, data) LoadFeatures(target, data) end
}

local EyebrowsFunctions = {
    ["eyebrows_t"] = function(target, data) LoadOverlays(target, data) end,
    ["eyebrows_op"] = function(target, data) LoadOverlays(target, data) end,
    ["eyebrows_id"] = function(target, data) LoadOverlays(target, data) end,
    ["eyebrows_c1"] = function(target, data) LoadOverlays(target, data) end,
    ["eyebrow_height"] = function(target, data) LoadFeatures(target, data) end,
    ["eyebrow_width"] = function(target, data) LoadFeatures(target, data) end,
    ["eyebrow_depth"] = function(target, data) LoadFeatures(target, data) end
}

CreateThread(function()
    for i, v in pairs(clotheslist) do
        if v.category_hashname == "BODIES_LOWER" or v.category_hashname == "BODIES_UPPER" or v.category_hashname ==
            "heads" or v.category_hashname == "hair" or v.category_hashname == "teeth" or v.category_hashname == "eyes" then
            if v.ped_type == "female" and v.is_multiplayer and v.hashname ~= "" then
                if ComponentsFemale[v.category_hashname] == nil then
                    ComponentsFemale[v.category_hashname] = {}
                end
                table.insert(ComponentsFemale[v.category_hashname], v.hash)
            elseif v.ped_type == "male" and v.is_multiplayer and v.hashname ~= "" then
                if ComponentsMale[v.category_hashname] == nil then
                    ComponentsMale[v.category_hashname] = {}
                end
                table.insert(ComponentsMale[v.category_hashname], v.hash)
            end
        end
    end
    if not IsImapActive(183712523) then RequestImap(183712523) end
    if not IsImapActive(-1699673416) then RequestImap(-1699673416) end
    if not IsImapActive(1679934574) then RequestImap(1679934574) end
end)

function ApplySkin()
    local _Target = PlayerPedId()
    local citizenid = RSGCore.Functions.GetPlayerData().citizenid
    local currentHealth = LocalPlayer.state.health or GetEntityHealth(_Target)
    local dirtClothes = GetAttributeBaseRank(_Target, 16)
    local dirtHat = GetAttributeBaseRank(_Target, 17)
    local dirtSkin = GetAttributeBaseRank(_Target, 22)

    -- Block NakedBody checks during the entire load so they don't fire on empty ClothesCache
    if NakedBodyState then
        NakedBodyState.skinLoading = true
        NakedBodyState.lowerApplied = false
        NakedBodyState.upperApplied = false
        NakedBodyState.lastPedId = 0
    end
    -- Mark skin as applied so the 6s fallback doesn't trigger a second load
    _G._SkinAppliedThisSession = true

    local promise = promise.new()
    RSGCore.Functions.TriggerCallback('rsg-multicharacter:server:getAppearance', function(data)
        -- Safety check: if no data returned, resolve immediately and skip
        if not data or not data.skin then
            print('[RSG-Appearance] ApplySkin: No skin data returned, skipping')
            if NakedBodyState then NakedBodyState.skinLoading = false end
            promise:resolve()
            return
        end
        local _SkinData = data.skin
        local _Clothes = data.clothes
        if _Target == PlayerPedId() then
            local model = GetHashKey(tonumber(_SkinData.sex) == 1 and 'mp_male' or 'mp_female')
            LoadModel(PlayerPedId(), model)
            _Target = PlayerPedId()
            SetEntityAlpha(_Target, 0)
            LoadedComponents = _SkinData
        end
        FixIssues(_Target)
        if NormalizeAppearanceSex then NormalizeAppearanceSex(_SkinData) end
        if IsAppearanceFemaleSkin and IsAppearanceFemaleSkin(_SkinData) and ApplyFemaleMpMetaBasePreset then
            ApplyFemaleMpMetaBasePreset(_Target)
        end
        LoadHeight(_Target, _SkinData)
        LoadBoody(_Target, _SkinData)
        -- ? packing body shape (features + key version) captures LoadHead
        LoadAllBodyShape(_Target, _SkinData)
        LoadHead(_Target, _SkinData)
        LoadHair(_Target, _SkinData)
        LoadBeard(_Target, _SkinData)
        LoadEyes(_Target, _SkinData)
        LoadFeatures(_Target, _SkinData)
        LoadOverlays(_Target, _SkinData)
        SetEntityAlpha(_Target, 255)
        SetAttributeCoreValue(_Target, 0, 100)
        SetAttributeCoreValue(_Target, 1, 100)
        SetEntityHealth(_Target, currentHealth, 0)
        Citizen.InvokeNative(0x8899C244EBCF70DE, PlayerId(), 0.0)
        Citizen.InvokeNative(0xDE1B1907A83A1550, _Target, 0)
        if _Target == PlayerPedId() then
            -- Check if clothes data has any actual items (non-zero hash or model)
            local hasClothesData = false
            if _Clothes and type(_Clothes) == 'table' then
                for _, item in pairs(_Clothes) do
                    if type(item) == 'table' then
                        if (item.hash and item.hash ~= 0) or (item.model and item.model > 0) then
                            hasClothesData = true
                            break
                        end
                    end
                end
            end
            if hasClothesData then
                TriggerEvent('rsg-appearance:client:ApplyClothes', _Clothes, _Target, _SkinData)
            else
                -- No saved clothes data — load from equipped inventory items instead
                if not (RSG and RSG.UseClothingInventory == false) and LoadClothingFromInventory then
                    CreateThread(function()
                        LoadClothingFromInventory(function() end, { useEquipPath = true })
                    end)
                end
            end
            -- ? Body morph instructions on structural (how common users structure each other)
            SetTimeout(2000, function()
                ApplyAndSaveBodyMorphFull(PlayerPedId(), _SkinData)
                StartBodyMorphGuard(PlayerPedId(), 10000)
                -- Release skinLoading and run naked body check now that clothes + morphs are done
                if NakedBodyState then NakedBodyState.skinLoading = false end
                SetTimeout(500, function()
                    pcall(function()
                        exports['rsg-appearance']:CheckAndApplyNakedBodyIfNeeded(PlayerPedId())
                    end)
                end)
            end)
        else
            for i, m in pairs(Overlays.overlay_all_layers) do
                Overlays.overlay_all_layers[i] =
                { name = m.name, visibility = 0, tx_id = 1, tx_normal = 0, tx_material = 0, tx_color_type = 0, tx_opacity = 1.0, tx_unk = 0, palette = 0, palette_color_primary = 0, palette_color_secondary = 0, palette_color_tertiary = 0, var = 0, opacity = 0.0 }
            end
            if NakedBodyState then NakedBodyState.skinLoading = false end
        end
        SetAttributeBaseRank(_Target, 16, dirtClothes)
        SetAttributeBaseRank(_Target, 17, dirtHat)
        SetAttributeBaseRank(_Target, 22, dirtSkin)
        promise:resolve()
    end, citizenid)
    Citizen.Await(promise)
end

local function ApplySkinMultiChar(SkinData, Target, ClothesData)
    FixIssues(Target)
    if NormalizeAppearanceSex then NormalizeAppearanceSex(SkinData) end
    if IsAppearanceFemaleSkin and IsAppearanceFemaleSkin(SkinData) and ApplyFemaleMpMetaBasePreset then
        ApplyFemaleMpMetaBasePreset(Target)
    end
    LoadHeight(Target, SkinData)
    LoadBoody(Target, SkinData)
    -- ? choosing body shapes (features + layout outlines)
    LoadAllBodyShape(Target, SkinData)
    LoadHead(Target, SkinData)
    LoadHair(Target, SkinData)
    LoadBeard(Target, SkinData)
    LoadEyes(Target, SkinData)
    LoadFeatures(Target, SkinData)
    LoadOverlays(Target, SkinData)
    LoadedComponents = SkinData
    TriggerEvent('rsg-appearance:client:ApplyClothes', ClothesData, Target, SkinData)
    -- ? Body morph construct presently?
    SetTimeout(2000, function()
        ApplyAndSaveBodyMorph(Target, SkinData)
        StartBodyMorphGuard(Target, 10000)
    end)
end

exports('ApplySkinMultiChar', ApplySkinMultiChar)
exports('ApplySkin', ApplySkin)

-- ongoing recovery-structure Uncertain ApplySkin:
-- as information uses layering references (body/head/hair/beard) in terms of resources typically.
local function RunAppearanceRecoveryPass(expectedToken, skinData, passLabel)
    if _G._PedStateFrozen then return end
    if expectedToken ~= appearanceApplyToken then return end
    if not skinData then return end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then return end

    local hasHead = GetHeadIndex and GetHeadIndex(ped)
    local shouldForce = (not hasHead)

    -- ? how define broadly the acts through faces, though few options - defined below 'summary' controls.
    if not shouldForce then
        if Config and Config.Debug then
            print(('[RSG-Appearance] Recovery pass (%s) SKIP — components already loaded'):format(passLabel))
        end
        return
    end

    if Config and Config.Debug then
        print(('[RSG-Appearance] Recovery pass (%s), force=%s'):format(passLabel, tostring(shouldForce)))
    end

    LoadHeight(ped, skinData)
    LoadBoody(ped, skinData)
    Wait(120)
    ApplyAndSaveBodyMorph(ped, skinData)
    LoadHead(ped, skinData)
    Wait(120)
    LoadHair(ped, skinData)
    if skinData.sex == 1 then
        LoadBeard(ped, skinData)
    end
    LoadEyes(ped, skinData)
    LoadFeatures(ped, skinData)
    LoadOverlays(ped, skinData)
    EnsureBodyIntegrity(ped, true)
    if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
end

local function ScheduleAppearanceRecoveryPasses(skinData)
    appearanceApplyToken = appearanceApplyToken + 1
    local token = appearanceApplyToken

    SetTimeout(1500, function()
        RunAppearanceRecoveryPass(token, skinData, 'early')
    end)
    SetTimeout(4000, function()
        RunAppearanceRecoveryPass(token, skinData, 'mid')
    end)
    SetTimeout(8000, function()
        RunAppearanceRecoveryPass(token, skinData, 'late-check')
    end)
    -- ? functioning through active overlays (12 active) - states needed backend framework?
    SetTimeout(12000, function()
        if token ~= appearanceApplyToken then return end
        if not skinData then return end
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) and not IsEntityDead(ped) and LoadOverlays then
            LoadOverlays(ped, skinData)
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            if NativeUpdatePedVariation then NativeUpdatePedVariation(ped) else Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) end
            -- ? how UpdatePedVariation systems need working projects - what approaching the _PedStateFrozen?
            if _G._PedStateFrozen then
                local cache = nil
                pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
                if cache then
                    local vest = (cache['vests'] and cache['vests'].hash and cache['vests'].hash ~= 0) and cache['vests'] or (cache['corsets'] and cache['corsets'].hash and cache['corsets'].hash ~= 0) and cache['corsets']
                    if vest then
                        local cat = (cache['vests'] and cache['vests'].hash == vest.hash) and 'vests' or 'corsets'
                        local itemData = { category = cat, isMale = IsPedMale(ped) }
                        for k, v in pairs(vest) do itemData[k] = v end
                        itemData.category = cat
                        TriggerEvent('rsg-clothing:client:equipClothing', itemData, { skipResync = true })
                        Wait(450)
                    end
                end
            end
        end
    end)
    -- ? customizable handles to overlays score if 5.5 capacity - capturing 'overall' profiles among metrics?
    -- ? in what ratios (aligning with _PedStateFrozen): UpdatePedVariation/workflow needs overlays
    SetTimeout(5500, function()
        if token ~= appearanceApplyToken then return end
        if not skinData then return end
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) or IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then return end
        LoadHead(ped, skinData)
        Wait(80)
        LoadEyes(ped, skinData)
        LoadFeatures(ped, skinData)
        LoadOverlays(ped, skinData)
        if not _G._PedStateFrozen and ReapplyBodyMorph then ReapplyBodyMorph(ped) end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        if NativeUpdatePedVariation then NativeUpdatePedVariation(ped) else Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) end
        -- ? how UpdatePedVariation organizes metrics beyond structures - while bettering through _PedStateFrozen
        if _G._PedStateFrozen then
            local cache = nil
            pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
            if cache then
                local vest = (cache['vests'] and cache['vests'].hash and cache['vests'].hash ~= 0) and cache['vests'] or (cache['corsets'] and cache['corsets'].hash and cache['corsets'].hash ~= 0) and cache['corsets']
                if vest then
                    local cat = (cache['vests'] and cache['vests'].hash == vest.hash) and 'vests' or 'corsets'
                    local itemData = { category = cat, isMale = IsPedMale(ped) }
                    for k, v in pairs(vest) do itemData[k] = v end
                    itemData.category = cat
                    TriggerEvent('rsg-clothing:client:equipClothing', itemData, { skipResync = true })
                    Wait(450)
                end
            end
        end
    end)
end

-- ? distinct what would happen structurally in often needs (how to /loadcharacter)
RegisterNetEvent('rsg-appearance:client:ApplySkin')
AddEventHandler('rsg-appearance:client:ApplySkin', function(skinData, clothesData)
    -- ? what edits to adjust the process (or how measurable in OnPlayerLoaded)
    _G._SkinAppliedThisSession = true
    
    if not skinData then
        if NakedBodyState then NakedBodyState.skinLoading = false end
        return
    end

    -- ? stating what process loadcharacter: anticipating states for loading data procedures are necessary,
    -- what layers need applied HP defining points (hands-on) and 'overview' is necessary here?
    if LocalPlayer.state.isLoadingCharacter then
        return
    end

    -- ? what characters facing alterations (efforts from core systems approaching JSON) - needs LoadHead/overview logs are processed?
    skinData.head = tonumber(skinData.head) or 1
    skinData.skin_tone = tonumber(skinData.skin_tone) or 1
    if NormalizeAppearanceSex then NormalizeAppearanceSex(skinData) end
    skinData.sex = tonumber(skinData.sex) or 1

    local ped = PlayerPedId()

    local skinToneValue = skinData.skin_tone
    CurrentSkinData = {
        skin_tone = skinToneValue,
        sex = skinData.sex,
        head = skinData.head,
        body_size = skinData.body_size,
        body_waist = skinData.body_waist,
        chest_size = skinData.chest_size,
        breast_size = skinData.breast_size,
        back_muscle = skinData.back_muscle,
        back_shoulder_thickness = skinData.back_shoulder_thickness,
        uppr_shoulder_size = skinData.uppr_shoulder_size,
        arms_size = skinData.arms_size,
        waist_width = skinData.waist_width,
        hips_size = skinData.hips_size,
        tight_size = skinData.tight_size,
        calves_size = skinData.calves_size,
        height = skinData.height,
    }

    -- ? assessing what's in layers for LoadedComponents, that fine needs reflecting older metadata procedures?
    LoadedComponents = deep_copy_skin(skinData) or {}
    if not LoadedComponents.skin_tone then LoadedComponents.skin_tone = skinToneValue end
    if not LoadedComponents.BODIES_UPPER then LoadedComponents.BODIES_UPPER = skinToneValue end

    local isDead = IsEntityDead(ped) or GetEntityHealth(ped) <= 0
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local isMetaDead = PlayerData and PlayerData.metadata and PlayerData.metadata['isdead']
    local applySkinWhenDead = isMetaDead  -- how to structure situations based on metrics - effectively explored through, where scores facings 0

    if (isDead or isMetaDead) and not applySkinWhenDead then
        if NakedBodyState then NakedBodyState.skinLoading = false end
        return
    end

    print('[RSG-Appearance] ApplySkin starting...' .. (applySkinWhenDead and ' (player dead — will restore 0 HP at end)' or ''))

    pcall(function()
        exports['rsg-appearance']:RestoreRicxOutfitBodyMesh(ped)
    end)
    _G._RicxOutfitActive = false
    _G._RicxActiveOutfitCustomId = nil
    _G._PedStateFrozen = false
    LocalPlayer.state:set('isLoadingCharacter', true, true)

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local groundZ = coords.z

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    LocalPlayer.state:set('invincible', true, true)

    TriggerEvent('rsg-appearance:client:BeforeApplySkin')
    -- ? FIX: changing processes, affecting what's new (effectively adjustments??? area) - loadcharacter potential data applied as accountable property
    -- ? ? how based on design needs (functionality-part alignment)
    local parasolHashes = { [joaat('p_parasol02x')] = true, [joaat('k_p_parasol02x_custom_01')] = true, [joaat('k_p_parasol02x_custom_02')] = true, [joaat('k_p_parasol02x_custom_03')] = true, [joaat('k_p_parasol02x_custom_04')] = true, [joaat('k_p_parasol02x_custom_05')] = true, [joaat('k_p_parasol02x_custom_06')] = true, [joaat('k_p_parasol02x_custom_07')] = true }
    for _, obj in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(obj) and IsEntityAttachedToEntity(ped, obj) then
            if parasolHashes[GetEntityModel(obj)] then goto continue end
            SetEntityAsMissionEntity(obj, true, true)
            DeleteEntity(obj)
        end
        ::continue::
    end

    local maxHealth = 600
    local savedHealth = GetEntityHealth(ped)
    if applySkinWhenDead then
        savedHealth = 0
    else
        if savedHealth < 100 then savedHealth = 100 end
        if savedHealth > maxHealth then savedHealth = maxHealth end
    end

    local modelName = (skinData.sex == 1) and 'mp_male' or 'mp_female'
    local modelHash = GetHashKey(modelName)
    local alreadyCorrectModel = GetEntityModel(ped) == modelHash

    if not alreadyCorrectModel then
        RequestModel(modelHash, false)
        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 100 do
            Wait(100)
            timeout = timeout + 1
        end

        if not HasModelLoaded(modelHash) then
            FreezeEntityPosition(ped, false)
            LocalPlayer.state:set('isLoadingCharacter', false, true)
            if NakedBodyState then NakedBodyState.skinLoading = false end
            return
        end

        SetPlayerModel(PlayerId(), modelHash, true)

        -- ? FIX: laying claims around what supports necessary in features? (under graphical needs loose focus)
        -- ?? about the outcomes for SetPlayerModel clocks needs combined layers?
        local modelTimeout = 0
        ped = PlayerPedId()
        while (not ped or not DoesEntityExist(ped) or not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped)) and modelTimeout < 200 do
            Wait(50)
            ped = PlayerPedId()
            modelTimeout = modelTimeout + 1
        end
        if modelTimeout >= 200 then
            print('[RSG-Appearance] WARNING: SetPlayerModel timeout (10s), continuing anyway')
        end
        Wait(200) -- processes repeated in systems when applying sequences.

        ped = PlayerPedId()
    else
        print('[RSG-Appearance] Skipping SetPlayerModel — already on correct model: ' .. modelName)
    end

    if ResetNakedBodyFlags then
        ResetNakedBodyFlags()
    elseif NakedBodyState then
        NakedBodyState.lowerApplied = false
        NakedBodyState.upperApplied = false
        NakedBodyState.lastPedId = 0
    end

    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, heading)

    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    Citizen.InvokeNative(0x58A850EAEE20FAA3, ped)
    -- ? FIX: how the needs aim before goals are categorized on handler need based SetRandomOutfitVariation
    local readyTimeout = 0
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and readyTimeout < 100 do
        Wait(50)
        readyTimeout = readyTimeout + 1
    end
    Wait(200)

    -- Only reset health when a model swap actually happened (SetPlayerModel wipes the ped)
    if not alreadyCorrectModel then
        SetEntityMaxHealth(ped, maxHealth)
        SetEntityHealth(ped, savedHealth, 0)
        SetAttributeCoreValue(ped, 0, 100)
        SetAttributeCoreValue(ped, 1, 100)

        if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
            NetworkResurrectLocalPlayer(coords.x, coords.y, groundZ, heading, true, false)
            Wait(100)
            ped = PlayerPedId()
            FreezeEntityPosition(ped, true)
            SetEntityMaxHealth(ped, maxHealth)
            SetEntityHealth(ped, savedHealth, 0)
        end
    end

    FixIssues(ped)
    Wait(100)

    -- ? processes mp_female: analyzing new-structured menus to aim/per environment - where what choices needed to lower the observing areas in capabilities?
    if IsAppearanceFemaleSkin and IsAppearanceFemaleSkin(skinData) then
        ApplyFemaleMpMetaBasePreset(ped)
    end

    LoadHeight(ped, skinData)
    LoadBoody(ped, skinData)
    Wait(300)
    -- ? finishing face routines in metrics (holding + features profile)
    ApplyAndSaveBodyMorph(ped, skinData)
    LoadHead(ped, skinData)
    Wait(300)

    EnsureBodyIntegrity(ped, true)
    Wait(200)

    LoadHair(ped, skinData)
    Wait(200)

    if skinData.sex == 1 then
        LoadBeard(ped, skinData)
        Wait(200)
    end

    LoadEyes(ped, skinData)
    Wait(100)

    LoadFeatures(ped, skinData)
    Wait(100)

    LoadOverlays(ped, skinData)
    Wait(200)

    Citizen.InvokeNative(0x704C908E9C405136, ped)
    if NativeUpdatePedVariation then NativeUpdatePedVariation(ped) else Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) end
    -- ? as optimized efforts on body morph using UpdatePedVariation
    if ReapplyBodyMorph then ReapplyBodyMorph(ped) end

    -- ? structured: layer definitions where through layers to need (playerskins.clothes) to be the outputs?
    -- ? SetPedPortFromSkin before methodology on ApplyAndSaveBodyMorph is necessary to manage (event replay as effective templates in compile).
    -- process meaning follows but clearance target towards particular formatting - how general context is reflective to one versus another.
    StripClothesOnly(ped)

    local _clothesLoaded = false
    local _clothesFound = false
    local clothesData = clothesData or {}

    if type(clothesData) == 'table' and next(clothesData) then
        -- errors awaiting through needs (playerskins.clothes) - designed calls to significant needed parts (hash in approaches focusing demands)
        print('[RSG-Appearance] Applying clothes from DB (playerskins.clothes)...')
        TriggerEvent('rsg-appearance:client:ApplyClothes', clothesData, ped, skinData)
        Wait(4000)
        _clothesLoaded = true
        _clothesFound = true
    elseif not (RSG and RSG.UseClothingInventory == false) and LoadClothingFromInventory then
        print('[RSG-Appearance] Loading clothes via equip path (as from inventory)...')
        LoadClothingFromInventory(function(success, count)
            _clothesFound = (success == true)
            _clothesLoaded = true
            print('[RSG-Appearance] Clothes loaded: ' .. tostring(count or 0) .. ' items, success=' .. tostring(success))
        end, { useEquipPath = true })
    else
        print('[RSG-Appearance] WARNING: LoadClothingFromInventory not available!')
        _clothesLoaded = true
    end

    -- what visual audience information will keep (in 15 total)
    local waitTimeout = 0
    while not _clothesLoaded and waitTimeout < 150 do
        Wait(100)
        waitTimeout = waitTimeout + 1
    end
    Wait(100)

    -- ?? secured where all - networking naked body
    if not _clothesFound then
        print('[RSG-Appearance] No clothes in inventory — checking naked body')
        EnsureBodyIntegrity(ped, false)
        Wait(500)
        if NakedBodyState then
            NakedBodyState.lowerApplied = false
            NakedBodyState.upperApplied = false
        end
        if CheckAndApplyNakedBodyIfNeeded then
            CheckAndApplyNakedBodyIfNeeded(ped, {})
        else
            TriggerEvent('rsg-appearance:client:CheckNakedBody')
        end
        Wait(200)
    end

    -- ? UpdatePedVariation (how typical serves metrics?) overseeing large assessments having links - continuing systems treating processes.
    -- ? skipBodyMorph=true - how multiple adjustments to ReapplyBodyMorph alongside rounds are required? (apply prior to layers they sees)
    ped = PlayerPedId()
    if DoesEntityExist(ped) then
        LoadHead(ped, skinData)
        Wait(80)
        LoadEyes(ped, skinData)
        LoadFeatures(ped, skinData)
        if LoadOverlays then LoadOverlays(ped, skinData) end
        Wait(80)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        if NativeUpdatePedVariation then NativeUpdatePedVariation(ped, true) else Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) end
    end
    Wait(100)

    -- ? Body morph: LoadHead+UpdatePedVariation follows designs - ongoing feedback expectations. ReapplyVestIfEquipped needs clarified - on data based inventory.
    ped = PlayerPedId()
    ApplyAndSaveBodyMorph(ped, skinData)
    -- ApplyAllBodyMorph solid current SetPedPortFromSkin to iterate UpdatePedVariation - layering projects/duration/monitored visual claims.
    ped = PlayerPedId()
    if DoesEntityExist(ped) then
        LoadHead(ped, skinData)
        Wait(40)
        LoadEyes(ped, skinData)
        LoadFeatures(ped, skinData)
        if LoadOverlays then LoadOverlays(ped, skinData) end
        Wait(40)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        if NativeUpdatePedVariation then NativeUpdatePedVariation(ped, true) else Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) end
    end
    pcall(function() exports['rsg-appearance']:ApplyAllClothingColorsFromCache(ped) end)
    -- ? how forward available BodyMorphGuard - where loadcharacter set essential active (_PedStateFrozen), who needs updated seamlessly?

    ped = PlayerPedId()
    local currentHealth = GetEntityHealth(ped)
    if applySkinWhenDead then
        SetEntityHealth(ped, 0)
    elseif currentHealth > maxHealth then
        SetEntityHealth(ped, maxHealth, 0)
    end

    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetEntityCollision(ped, true, true)

    Wait(100)
    FreezeEntityPosition(ped, false)
    -- Lift invincibility only now — health is stable again and ped is unfrozen
    SetEntityInvincible(ped, false)
    LocalPlayer.state:set('invincible', false, true)
    Wait(200)

    -- ? measures Z <= UnderMapSafety.MaxZForTeleport (how free zones); replacing confident adjustments needs used.
    TeleportToSafeGroundIfNeeded(ped)

    -- ? holding _PedStateFrozen - having surrounding objectives practical for checking isLoadingCharacter really - through visible properties?
    -- scheduleOverlayRefreshAfterAnim (how TaskPlayAnim are visible) to LoadOverlays face collected needed assessments
    -- configurable layers in observations ApplySkin for detailed needed overlays included background processes 'effective.'
    _G._PedStateFrozen = true

    LocalPlayer.state:set('isLoadingCharacter', false, true)

    print('[RSG-Appearance] Skin applied successfully, health: ' .. GetEntityHealth(ped) .. '/' .. maxHealth)

    if NakedBodyState then
        NakedBodyState.skinLoading = false
    end

    -- ? table: finalBodyMorphPass on 800??/1800?? - assessment points being connected (how scopes from connects become workings?) 

-- What is _PedStateFrozen: frozen + time? Setting default time 5500ms (LoadHead/UpdatePedVariation), what it means to synchronize?
    SetTimeout(6000, function()
        local currentPed = PlayerPedId()
        if not DoesEntityExist(currentPed) then return end
        if _G._PedStateFrozen then
            if NakedBodyState then
                NakedBodyState.lowerApplied = false
                NakedBodyState.upperApplied = false
            end
            local cache = nil
            pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
            -- 1) Calculate total time (e.g.: start/end/interval+delay)
            pcall(function()
                exports['rsg-appearance']:ApplyLegsStateForSkirtBoots(currentPed, cache)
            end)
            Wait(150)
            -- 2) Determine unexpected errors/(e.g. if adjusted), how we can stop excessively conflicting?
            if cache then
                local vest = (cache['vests'] and cache['vests'].hash and cache['vests'].hash ~= 0) and cache['vests']
                    or (cache['corsets'] and cache['corsets'].hash and cache['corsets'].hash ~= 0) and cache['corsets']
                if vest then
                    local cat = (cache['vests'] and cache['vests'].hash and cache['vests'].hash == vest.hash) and 'vests' or 'corsets'
                    local itemData = { category = cat, isMale = IsPedMale(currentPed) }
                    for k, v in pairs(vest) do itemData[k] = v end
                    itemData.category = cat
                    TriggerEvent('rsg-clothing:client:equipClothing', itemData, { skipResync = true })
                    Wait(500)
                end
            end
            return
        end
        if NakedBodyState then
            NakedBodyState.lowerApplied = false
            NakedBodyState.upperApplied = false
        end
        local cache = nil
        pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
        if CheckAndApplyNakedBodyIfNeeded then
            CheckAndApplyNakedBodyIfNeeded(currentPed, cache)
        else
            TriggerEvent('rsg-appearance:client:CheckNakedBody')
        end
    end)

    -- Will progress cap be appropriately measured for standardization?
    -- Alternative recovery-approaches suggests scoring/links/limits on verification interaction.
    ScheduleAppearanceRecoveryPasses(skinData)

    TriggerEvent('rsg-appearance:client:ApplySkinComplete')
end)

-- It should be deemed mandatory to truly manage affine proportions, providing general overview (alerts/reports) - UpdatePedVariation likely succeeds overall
-- FIX: If recovery option fails _PedStateFrozen (should loadcharacter) - check construct response on bounds/plugins
-- Limit 500ms indicates potential score+NativeUpdatePedVariation to quantify progression
AddEventHandler('rsg-clothing:client:clothingLoaded', function()
    if _G._PedStateFrozen then return end
    SetTimeout(500, function()
        if _G._PedStateFrozen then return end
        -- For reference: LoadHead+NativeUpdatePedVariation significantly improves outcome consistency
        if _G._CoatJustChanged and (GetGameTimer() - _G._CoatJustChanged) < 1500 then return end
        local p = PlayerPedId()
        if not DoesEntityExist(p) then return end
        local data = LoadedComponents
        if data and next(data) then
            LoadHead(p, data)
            Wait(80)
            LoadEyes(p, data)
            LoadFeatures(p, data)
            if LoadOverlays then LoadOverlays(p, data) end
            Wait(50)
            -- In the future ReapplyBodyMorph returns everything expected (observing variables on input)
            Citizen.InvokeNative(0x704C908E9C405136, p)
            if NativeUpdatePedVariation then NativeUpdatePedVariation(p, true) else Citizen.InvokeNative(0xCC8CA3E88256E58F, p, false, true, true, true, false) end
        else
            if ReapplyBodyMorph then ReapplyBodyMorph(p) end
            if ApplyOverlays then ApplyOverlays(p) end
        end
    end)
end)

-- ==========================================
-- ForceReloadBodyParts
-- ==========================================
function ForceReloadBodyParts(ped, skinData)
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end

    local isMale = IsPedMale(ped)
    local skinTone = skinData and skinData.skin_tone or 1
    local gender = isMale and 'male' or 'female'

    local success, cl = pcall(function() return require 'data.clothes_list' end)
    if not success or not cl then return end

    local bodies_upper = {}
    local bodies_lower = {}

    for _, item in ipairs(cl) do
        if item.ped_type == gender and item.is_multiplayer then
            if item.hashname and item.hashname ~= "" then
                if item.category_hashname == 'BODIES_UPPER' then
                    table.insert(bodies_upper, {hash = item.hash, hashname = item.hashname})
                elseif item.category_hashname == 'BODIES_LOWER' then
                    table.insert(bodies_lower, {hash = item.hash, hashname = item.hashname})
                end
            end
        end
    end

    local function ApplyBodyComponent(ped, bodyData, componentName)
        if not bodyData or not bodyData.hash then return false end
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey(string.lower(componentName)))
        Wait(50)
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, bodyData.hash)
        Wait(50)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyData.hash, true, true, true)
        local t = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t < 50 do
            Wait(20)
            t = t + 1
        end
        return t < 50
    end

    if #bodies_upper > 0 then
        local idx = math.min(skinTone, #bodies_upper)
        if idx < 1 then idx = 1 end
        ApplyBodyComponent(ped, bodies_upper[idx], "BODIES_UPPER")
    end
    Wait(100)
    if #bodies_lower > 0 then
        local idx = math.min(skinTone, #bodies_lower)
        if idx < 1 then idx = 1 end
        ApplyBodyComponent(ped, bodies_lower[idx], "BODIES_LOWER")
    end
    Wait(150)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

function TableLength(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

RegisterNetEvent('rsg-appearance:client:OpenCreator', function(data, empty)
    print('[RSG-Appearance] OpenCreator called: data=' .. json.encode(data or {}) .. ' empty=' .. tostring(empty))
    if data and type(data) == 'table' then
        Cid = data.cid or data.Cid or data.slot
        print('[RSG-Appearance] OpenCreator: Cid set to ' .. tostring(Cid))
    elseif empty then
        Skinkosong = true
        print('[RSG-Appearance] OpenCreator: Skinkosong set to true')
    end
    StartCreator()
end)

-- Attention: nonlinear relative shift could generate risks (inconsistent margins assessed, back on balance)
-- Generally on application constraints, issues expected - review on centralization.
RegisterNetEvent('rsg-appearance:client:OpenEditor', function()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then
        lib.notify({ title = 'Notification', description = 'New structure checks on enhancing completion', type = 'error' })
        return
    end
    RSGCore.Functions.TriggerCallback('rsg-appearance:server:GetSkinForEditor', function(skin)
        if not skin or not next(skin) then
            lib.notify({ title = 'Attention', description = 'Subsystems probing on collaborations', type = 'error' })
            return
        end
        -- Expect structure to yield improved outcomes
        local c = GetEntityCoords(ped)
        local h = GetEntityHeading(ped)
        EditAppearanceReturnPos = { x = c.x, y = c.y, z = c.z, h = h }
        Skinkosong = true
        KeepClothesOnSave = true
        LoadedComponents = deep_copy_skin(skin) or {}
        CreatorCache = {}
        for k, v in pairs(LoadedComponents) do
            if type(v) == 'table' then
                CreatorCache[k] = {}
                for k2, v2 in pairs(v) do CreatorCache[k][k2] = v2 end
            else
                CreatorCache[k] = v
            end
        end
        Selectedsex = (skin.sex == 1 or skin.sex == nil) and 1 or 2
        -- Adjustment protocols: ensuring to mitigate risks, alerting potential workflow issues (e.g. prechecks/thresholds)
        StartCreator()
        lib.notify({ title = 'Operation Cancelled', description = 'Alert completion status identified on objects, procedures failed normatively', type = 'info' })
    end)
end)

RegisterCommand('loadskin', function(source, args, raw)
    local ped = PlayerPedId()
    local isdead = IsEntityDead(ped) or GetEntityHealth(ped) <= 0
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local isMetaDead = PlayerData and PlayerData.metadata and PlayerData.metadata['isdead']
    if isdead or isMetaDead then
        lib.notify({ title = 'Notice', description = 'Volume error on path inhaled', type = 'error' })
        return
    end
    if LocalPlayer.state.invincible then return end
    local cuffed = IsPedCuffed(ped)
    local hogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, ped)
    local lassoed = Citizen.InvokeNative(0x9682F850056C9ADE, ped)
    local dragged = Citizen.InvokeNative(0xEF3A8772F085B4AA, ped)
    local ragdoll = IsPedRagdoll(ped)
    local falling = IsPedFalling(ped)
    local isJailed = PlayerData and PlayerData.metadata and PlayerData.metadata["injail"] or 0
    if cuffed or hogtied or lassoed or dragged or ragdoll or falling or isJailed > 0 then return end
    LocalPlayer.state:set('invincible', true, true)
    ApplySkin()
    SetTimeout(500, function()
        LocalPlayer.state:set('invincible', false, true)
        SetEntityInvincible(PlayerPedId(), false)
    end)
end, false)

function StartCreator()
    TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', BucketId)
    Wait(1)
    for i, m in pairs(Overlays.overlay_all_layers) do
        Overlays.overlay_all_layers[i] =
        {name = m.name, visibility = 0, tx_id = 1, tx_normal = 0, tx_material = 0, tx_color_type = 0, tx_opacity = 1.0, tx_unk = 0, palette = 0, palette_color_primary = 0, palette_color_secondary = 0, palette_color_tertiary = 0, var = 0, opacity = 0.0}
    end
    MenuData.CloseAll()
    SpawnPeds()
end

-- On threshold notification: issues affect transition, results on gather (unforeseen expectations, achieving incompletion)
function checkStrings(str)
    if not str or str == '' then
        lib.notify({ title = 'Warning', description = 'Major on entry path at volume', type = 'error' })
        return false
    end
    if #str < 2 then
        lib.notify({ title = 'Warning', description = 'Common 2 failures', type = 'error' })
        return false
    end
    -- Critical adjustments surrounding transition (feedback on outputs)
    local cleaned = str:gsub('[%s%-]', '')
    if cleaned == '' then
        lib.notify({ title = 'Warning', description = 'Path on default anomalies must be verified', type = 'error' })
        return false
    end
    -- Critical termination
    if cleaned:match('[a-zA-Z]') then
        lib.notify({ title = 'Warning', description = 'Provisions collectively. Alerts on pathway are necessary', type = 'error' })
        return false
    end
    -- Critical expulsion
    if cleaned:match('[%d]') then
        lib.notify({ title = 'Warning', description = 'Alerts measured on field/functional', type = 'error' })
        return false
    end
    -- Critical reinstatement (effectively altering/dynamic pathways to models)
    if cleaned:match('[!@#$%%%^&*%(%)_+=~`%[%]{}<>|/\\%.,%?;:\"\']') then
        lib.notify({ title = 'Warning', description = 'Establish specifications', type = 'error' })
        return false
    end
    return true
end

function FirstMenu()
    MenuData.CloseAll()
    local elements = {}
    local elementIndexes = {}

    if Skinkosong then
        Labelsave = RSG.Texts.firsmenu.Start
        Valuesave = 'save'
    end

    if (IsInCharCreation or Skinkosong) then
        elements[#elements + 1] = {
            label = locale('creator.appearance.label'),
            value = "appearance",
            desc = locale('creator.appearance.desc'),
        }
    end

    if IsInCharCreation and not Skinkosong then
        elements[#elements + 1] = {
            label = Firstname or RSG.Texts.firsmenu.label_firstname .. "<br><span style='opacity:0.6;'>" .. RSG.Texts.firsmenu.none .. "</span>",
            value = "firstname",
            desc = locale('creator.firstname.desc'),
        }
        elementIndexes.firstname = #elements

        elements[#elements + 1] = {
            label = Lastname or RSG.Texts.firsmenu.label_lastname .. "<br><span style='opacity:0.6;'>" .. RSG.Texts.firsmenu.none .. "</span>",
            value = "lastname",
            desc = locale('creator.lastname.desc')
        }
        elementIndexes.lastname = #elements

        elements[#elements + 1] = {
            label = Nationality or RSG.Texts.firsmenu.Nationality .. "<br><span style='opacity:0.6;'>" .. RSG.Texts.firsmenu.none .. "</span>",
            value = "nationality",
            desc = locale('creator.nationality.desc')
        }
        elementIndexes.nationality = #elements

        elements[#elements + 1] = {
            label = Birthdate or RSG.Texts.firsmenu.Birthdate .. "<br><span style='opacity:0.6;'>" .. RSG.Texts.firsmenu.none .. "</span>",
            value = "birthdate",
            desc = locale('creator.birthdate.desc')
        }
        elementIndexes.birthdate = #elements
    end

    elements[#elements + 1] = {
        label = Labelsave or ("<span style='color: Grey;'>" .. RSG.Texts.firsmenu.Start .. "<br>" .. RSG.Texts.firsmenu.empty .. "</span>"),
        value = Valuesave or 'not',
        desc = ""
    }
    elementIndexes.save = #elements

    MenuData.Open('default', GetCurrentResourceName(), 'FirstMenu',
        {
            title = RSG.Texts.Creator,
            subtext = RSG.Texts.Options,
            align = RSG.Texts.align,
            elements = elements,
            itemHeight = "4vh"
        }, function(data, menu)
            if (data.current.value == 'appearance') then return MainMenu() end

            if (data.current.value == 'firstname') then
                :: noMatch ::
                local dialog = lib.inputDialog(locale('creator.firstname.input.header'), {{type='input',required=true,icon='user-pen',label=locale('creator.firstname.input.label'),placeholder=locale('creator.firstname.input.placeholder')}})
                if not dialog then return false end
                if not checkStrings(dialog[1]) then goto noMatch end
                Firstname = dialog[1]
                menu.setElement(elementIndexes.firstname, "label", Firstname)
                menu.setElement(elementIndexes.firstname, "itemHeight", "4vh")
                menu.refresh()
            end

            if (data.current.value == 'lastname') then
                :: noMatch ::
                local dialog = lib.inputDialog(locale('creator.lastname.input.header'), {{type='input',required=true,icon='user-pen',label=locale('creator.lastname.input.label'),placeholder=locale('creator.lastname.input.placeholder')}})
                if not dialog then return false end
                if not checkStrings(dialog[1]) then goto noMatch end
                Lastname = dialog[1]
                menu.setElement(elementIndexes.lastname, "label", Lastname)
                menu.setElement(elementIndexes.lastname, "itemHeight", "4vh")
                menu.refresh()
            end

            if (data.current.value == 'nationality') then
                :: noMatch ::
                local dialog = lib.inputDialog(locale('creator.nationality.input.header'), {{type='input',required=true,icon='user-shield',label=locale('creator.nationality.input.label'),placeholder=locale('creator.nationality.input.placeholder')}})
                if not dialog then return false end
                if not checkStrings(dialog[1]) then goto noMatch end
                Nationality = dialog[1]
                menu.setElement(elementIndexes.nationality, "label", Nationality)
                menu.setElement(elementIndexes.nationality, "itemHeight", "4vh")
                menu.refresh()
            end

            if (data.current.value == 'birthdate') then
                local dialog = lib.inputDialog(locale('creator.birthdate.input.header'), {{type='date',required=true,icon='calendar-days',label=locale('creator.birthdate.input.label'),format='YYYY-MM-DD',returnString=true,min='1750-01-01',max='1900-01-01',default='1870-01-01'}})
                if not dialog then return false end
                Birthdate = dialog[1]
                Labelsave = RSG.Texts.firsmenu.Start
                Valuesave = 'save'
                menu.setElement(elementIndexes.birthdate, "label", Birthdate)
                menu.setElement(elementIndexes.birthdate, "itemHeight", "4vh")
                menu.removeElementByIndex(elementIndexes.save)
                menu.addNewElement({label = RSG.Texts.firsmenu.Start, value = Valuesave, desc = ""})
                menu.refresh()
            end

            if data.current.value == 'save' then
                LoadedComponents = CreatorCache
                if Skinkosong then
                    MenuData.CloseAll()
                    Skinkosong = false
                    Firstname = RSGCore.Functions.GetPlayerData().charinfo.firstname
                    Lastname = RSGCore.Functions.GetPlayerData().charinfo.lastname
                    FotoMugshots()
                    Wait(2000)
                    TriggerServerEvent('rsg-appearance:server:GiveStarterClothing', ClothesCache or {}, IsPedMale(PlayerPedId()))
                elseif Firstname and Lastname and Nationality and Selectedsex and Birthdate and Cid then
                    MenuData.CloseAll()
                    local newData = {firstname=Firstname,lastname=Lastname,nationality=Nationality,gender=Selectedsex==1 and 0 or 1,birthdate=Birthdate,cid=Cid}
                    TriggerServerEvent('rsg-multicharacter:server:createCharacter', newData)
                    Wait(500)
                    FotoMugshots()
                    Wait(2000)
                    TriggerServerEvent('rsg-appearance:server:GiveStarterClothing', ClothesCache or {}, IsPedMale(PlayerPedId()))
                else
                    lib.notify({title=locale('missing_character_info.title'),description=locale('missing_character_info.description'),type='error',duration=7000})
                end
            end
        end, function(data, menu) end)
end

function MainMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Body,value='body',desc=""},
        {label=RSG.Texts.Face,value='face',desc=""},
        {label=RSG.Texts.Hair_beard,value='hair',desc=""},
        {label=RSG.Texts.Makeup,value='makeup',desc=""},
    }
    MenuData.Open('default', GetCurrentResourceName(), 'main_character_creator_menu',
        {title=RSG.Texts.Appearance,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
        MainMenus[data.current.value]()
    end, function(data, menu) FirstMenu() end)
end

function OpenBodyMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Face,value=CreatorCache["head"] or 1,category="head",desc="",type="slider",min=1,max=20,hop=1},
        {label=RSG.Texts.Width,value=CreatorCache["face_width"] or 0,category="face_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.SkinTone,value=CreatorCache["skin_tone"] or 1,category="skin_tone",desc="",type="slider",min=1,max=6},
        {label=RSG.Texts.Size,value=CreatorCache["body_size"] or 1,category="body_size",desc="",type="slider",min=1,max=#Data.Appearance.body_size},
        {label=RSG.Texts.Waist,value=CreatorCache["body_waist"] or 11,category="body_waist",desc="",type="slider",min=1,max=30},
        {label=RSG.Texts.Chest,value=CreatorCache["chest_size"] or 1,category="chest_size",desc="",type="slider",min=1,max=#Data.Appearance.chest_size},
        {label=RSG.Texts.Height,value=CreatorCache["height"] or 100,category="height",desc="",type="slider",min=80,max=130}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'body_character_creator_menu',
        {title=RSG.Texts.Appearance,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) MainMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            local target = CreatorPed
            if not target or target == 0 or not DoesEntityExist(target) then
                target = PlayerPedId()
            end
            BodyFunctions[data.current.category](target, CreatorCache)
        end
    end)
end

function OpenFaceMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Eyes,value='eyes',desc=""},
        {label=RSG.Texts.Eyelids,value='eyelids',desc=""},
        {label=RSG.Texts.Eyebrows,value='eyebrows',desc=""},
        {label=RSG.Texts.Nose,value='nose',desc=""},
        {label=RSG.Texts.Mouth,value='mouth',desc=""},
        {label=RSG.Texts.Cheekbones,value='cheekbones',desc=""},
        {label=RSG.Texts.Jaw,value='jaw',desc=""},
        {label=RSG.Texts.Ears,value='ears',desc=""},
        {label=RSG.Texts.Chin,value='chin',desc=""},
        {label=RSG.Texts.Defects,value='defects',desc=""}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'face_main_character_creator_menu',
        {title=RSG.Texts.Face,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
        FaceFunctions[data.current.value]()
    end, function(data, menu) MainMenu() end)
end

function OpenHairMenu()
    MenuData.CloseAll()
    local elements = {}
    if IsPedMale(PlayerPedId()) then
        local a = 1
        if CreatorCache["hair"] == nil or type(CreatorCache["hair"]) ~= "table" then
            CreatorCache["hair"] = {model=0,texture=1}
        end
        if CreatorCache["beard"] == nil or type(CreatorCache["beard"]) ~= "table" then
            CreatorCache["beard"] = {model=0,texture=1}
        end
        local maleHairMax = 29
        elements[#elements+1] = {label=RSG.Texts.HairStyle,value=CreatorCache["hair"].model or 0,category="hair",desc="",type="slider",min=0,max=maleHairMax,change_type="model",id=a}
        a=a+1
        elements[#elements+1] = {label=RSG.Texts.HairColor,value=CreatorCache["hair"].texture or 1,category="hair",desc="",type="slider",min=1,max=GetMaxTexturesForModel("hair",CreatorCache["hair"].model or 1,false),change_type="texture",id=a}
        a=a+1
        elements[#elements+1] = {label=RSG.Texts.BeardStyle,value=CreatorCache["beard"].model or 0,category="beard",desc="",type="slider",min=0,max=#hairs_list["male"]["beard"],change_type="model",id=a}
        a=a+1
        elements[#elements+1] = {label=RSG.Texts.BeardColor,value=CreatorCache["beard"].texture or 1,category="beard",desc="",type="slider",min=1,max=GetMaxTexturesForModel("beard",CreatorCache["beard"].model or 1,false),change_type="texture",id=a}
    else
        local a = 1
        if CreatorCache["hair"] == nil or type(CreatorCache["hair"]) ~= "table" then
            CreatorCache["hair"] = {model=0,texture=1}
        end
        elements[#elements+1] = {label=RSG.Texts.Hair,value=CreatorCache["hair"].model or 0,category="hair",desc="",type="slider",min=0,max=#hairs_list["female"]["hair"],change_type="model",id=a}
        a=a+1
        elements[#elements+1] = {label=RSG.Texts.HairColor,value=CreatorCache["hair"].texture or 1,category="hair",desc="",type="slider",min=1,max=GetMaxTexturesForModel("hair",CreatorCache["hair"].model or 1),change_type="texture",id=a}
    end
    MenuData.Open('default', GetCurrentResourceName(), 'hair_main_character_creator_menu',
        {title=RSG.Texts.Hair_beard,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) MainMenu() end, function(data, menu)
        if data.current.change_type == "model" then
            local newValue = data.current.value
            if data.current.category == "hair" and IsPedMale(PlayerPedId()) then
                if newValue == 19 then
                    local oldValue = CreatorCache[data.current.category].model or 0
                    newValue = newValue > oldValue and 20 or 18
                    menu.setElement(data.current.id, "value", newValue)
                end
            end
            if CreatorCache[data.current.category].model ~= newValue then
                CreatorCache[data.current.category].texture = 1
                CreatorCache[data.current.category].model = newValue
                if newValue > 0 then
                    menu.setElement(data.current.id+1,"max",GetMaxTexturesForModel(data.current.category,newValue,false))
                    menu.setElement(data.current.id+1,"min",1)
                    menu.setElement(data.current.id+1,"value",1)
                    menu.refresh()
                else
                    menu.setElement(data.current.id+1,"max",0)
                    menu.setElement(data.current.id+1,"min",0)
                    menu.setElement(data.current.id+1,"value",0)
                    menu.refresh()
                end
                HairFunctions[data.current.category](PlayerPedId(), CreatorCache)
            end
        elseif data.current.change_type == "texture" then
            if CreatorCache[data.current.category].texture ~= data.current.value then
                CreatorCache[data.current.category].texture = data.current.value
                HairFunctions[data.current.category](PlayerPedId(), CreatorCache)
            end
        else
            if CreatorCache[data.current.category] ~= data.current.value then
                CreatorCache[data.current.category] = data.current.value
                HairFunctions[data.current.category](PlayerPedId(), CreatorCache)
            end
        end
    end)
end

function OpenEyesMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Color,value=CreatorCache["eyes_color"] or 1,category="eyes_color",desc="",type="slider",min=1,max=18},
        {label=RSG.Texts.Depth,value=CreatorCache["eyes_depth"] or 0,category="eyes_depth",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Angle,value=CreatorCache["eyes_angle"] or 0,category="eyes_angle",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Distance,value=CreatorCache["eyes_distance"] or 0,category="eyes_distance",desc="",type="slider",min=-100,max=100,hop=5}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'eyes_character_creator_menu',
    {title=RSG.Texts.Eyes,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            EyesFunctions[data.current.category](PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenEyelidsMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Height,value=CreatorCache["eyelid_height"] or 0,category="eyelid_height",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Width,value=CreatorCache["eyelid_width"] or 0,category="eyelid_width",desc="",type="slider",min=-100,max=100,hop=5}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'eyelid_character_creator_menu',
        {title=RSG.Texts.Eyelids,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            EyelidsFunctions[data.current.category](PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenEyebrowsMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Height,value=CreatorCache["eyebrow_height"] or 0,category="eyebrow_height",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Width,value=CreatorCache["eyebrow_width"] or 0,category="eyebrow_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Depth,value=CreatorCache["eyebrow_depth"] or 0,category="eyebrow_depth",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Type,value=CreatorCache["eyebrows_t"] or 1,category="eyebrows_t",desc="",type="slider",min=1,max=15},
        {label=RSG.Texts.Visibility,value=CreatorCache["eyebrows_op"] or 100,category="eyebrows_op",desc="",type="slider",min=0,max=100,hop=5},
        {label=RSG.Texts.ColorPalette,value=CreatorCache["eyebrows_id"] or 10,category="eyebrows_id",desc="",type="slider",min=1,max=25},
        {label=RSG.Texts.ColorFirstrate,value=CreatorCache["eyebrows_c1"] or 0,category="eyebrows_c1",desc="",type="slider",min=0,max=64}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'eyebrows_character_creator_menu',
        {title=RSG.Texts.Eyebrows,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            EyebrowsFunctions[data.current.category](PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenNoseMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Width,value=CreatorCache["nose_width"] or 0,category="nose_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Size,value=CreatorCache["nose_size"] or 0,category="nose_size",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Height,value=CreatorCache["nose_height"] or 0,category="nose_height",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Angle,value=CreatorCache["nose_angle"] or 0,category="nose_angle",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.NoseCurvature,value=CreatorCache["nose_curvature"] or 0,category="nose_curvature",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Distance,value=CreatorCache["nostrils_distance"] or 0,category="nostrils_distance",desc="",type="slider",min=-100,max=100,hop=5}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'nose_character_creator_menu',
        {title=RSG.Texts.Nose,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            LoadFeatures(PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenMouthMenu()
    MenuData.CloseAll()
    RequestAnimDict("FACE_HUMAN@GEN_MALE@BASE")
    while not HasAnimDictLoaded("FACE_HUMAN@GEN_MALE@BASE") do Wait(100) end
    TaskPlayAnim(PlayerPedId(), "FACE_HUMAN@GEN_MALE@BASE", "Face_Dentistry_Loop", 1090519040, -4, -1, 17, 0, 0, 0, 0, 0, 0)
    local elements = {
        {label=RSG.Texts.Teeth,value=CreatorCache["teeth"] or 1,category="teeth",desc="",type="slider",min=1,max=7},
        {label=RSG.Texts.Width,value=CreatorCache["mouth_width"] or 0,category="mouth_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Depth,value=CreatorCache["mouth_depth"] or 0,category="mouth_depth",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.UP_DOWN,value=CreatorCache["mouth_x_pos"] or 0,category="mouth_x_pos",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.left_right,value=CreatorCache["mouth_y_pos"] or 0,category="mouth_y_pos",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.UpperLipHeight,value=CreatorCache["upper_lip_height"] or 0,category="upper_lip_height",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.UpperLipWidth,value=CreatorCache["upper_lip_width"] or 0,category="upper_lip_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.UpperLipDepth,value=CreatorCache["upper_lip_depth"] or 0,category="upper_lip_depth",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.LowerLipHeight,value=CreatorCache["lower_lip_height"] or 0,category="lower_lip_height",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.LowerLipWidth,value=CreatorCache["lower_lip_width"] or 0,category="lower_lip_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.LowerLipDepth,value=CreatorCache["lower_lip_depth"] or 0,category="lower_lip_depth",desc="",type="slider",min=-100,max=100,hop=5}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'mouth_character_creator_menu',
        {title=RSG.Texts.Mouth,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) ClearPedTasks(PlayerPedId()) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            LoadFeatures(PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenCheekbonesMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Height,value=CreatorCache["cheekbones_height"] or 0,category="cheekbones_height",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Width,value=CreatorCache["cheekbones_width"] or 0,category="cheekbones_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Depth,value=CreatorCache["cheekbones_depth"] or 0,category="cheekbones_depth",desc="",type="slider",min=-100,max=100,hop=5}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'cheekbones_character_creator_menu',
        {title='Cheek Bones',subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            LoadFeatures(PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenJawMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Height,value=CreatorCache["jaw_height"] or 0,category="jaw_height",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Width,value=CreatorCache["jaw_width"] or 0,category="jaw_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Depth,value=CreatorCache["jaw_depth"] or 0,category="jaw_depth",desc="",type="slider",min=-100,max=100,hop=5}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'jaw_character_creator_menu',
        {title=RSG.Texts.Jaw,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements}, function(data, menu)
    end, function(data, menu) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            LoadFeatures(PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenEarsMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Width,value=CreatorCache["ears_width"] or 0,category="ears_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Angle,value=CreatorCache["ears_angle"] or 0,category="ears_angle",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Height,value=CreatorCache["ears_height"] or 0,category="ears_height",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Size,value=CreatorCache["earlobe_size"] or 0,category="earlobe_size",desc="",type="slider",min=-100,max=100,hop=5}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'ears_character_creator_menu',
        {title=RSG.Texts.Ears,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            LoadFeatures(PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenChinMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Size,value=CreatorCache["chin_height"] or 0,category="chin_height",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Size,value=CreatorCache["chin_width"] or 0,category="chin_width",desc="",type="slider",min=-100,max=100,hop=5},
        {label=RSG.Texts.Size,value=CreatorCache["chin_depth"] or 0,category="chin_depth",desc="",type="slider",min=-100,max=100,hop=5}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'chin_character_creator_menu',
        {title=RSG.Texts.Chin,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            LoadFeatures(PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenDefectsMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Scars,value=CreatorCache["scars_t"] or 1,category="scars_t",desc="",type="slider",min=1,max=16},
        {label=RSG.Texts.Clarity,value=CreatorCache["scars_op"] or 50,category="scars_op",desc="",type="slider",min=0,max=100,hop=5},
        {label=RSG.Texts.Older,value=CreatorCache["ageing_t"] or 1,category="ageing_t",desc="",type="slider",min=1,max=24},
        {label=RSG.Texts.Clarity,value=CreatorCache["ageing_op"] or 50,category="ageing_op",desc="",type="slider",min=0,max=100,hop=5},
        {label=RSG.Texts.Freckles,value=CreatorCache["freckles_t"] or 1,category="freckles_t",desc="",type="slider",min=1,max=15},
        {label=RSG.Texts.Clarity,value=CreatorCache["freckles_op"] or 50,category="freckles_op",desc="",type="slider",min=0,max=100,hop=5},
        {label=RSG.Texts.Moles,value=CreatorCache["moles_t"] or 1,category="moles_t",desc="",type="slider",min=1,max=16},
        {label=RSG.Texts.Clarity,value=CreatorCache["moles_op"] or 50,category="moles_op",desc="",type="slider",min=0,max=100,hop=5},
        {label=RSG.Texts.Spots,value=CreatorCache["spots_t"] or 1,category="spots_t",desc="",type="slider",min=1,max=16},
        {label=RSG.Texts.Clarity,value=CreatorCache["spots_op"] or 50,category="spots_op",desc="",type="slider",min=0,max=100,hop=5}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'defects_character_creator_menu',
        {title=RSG.Texts.Disadvantages,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) OpenFaceMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            LoadOverlays(PlayerPedId(), CreatorCache)
        end
    end)
end

function OpenMakeupMenu()
    MenuData.CloseAll()
    local elements = {
        {label=RSG.Texts.Shadow,value=CreatorCache["shadows_t"] or 1,category="shadows_t",desc="",type="slider",min=1,max=5},
        {label=RSG.Texts.Clarity,value=CreatorCache["shadows_op"] or 0,category="shadows_op",desc="",type="slider",min=0,max=100,hop=5},
        {label=RSG.Texts.ColorShadow,value=CreatorCache["shadows_id"] or 1,category="shadows_id",desc="",type="slider",min=1,max=25},
        {label=RSG.Texts.ColorFirst_Class,value=CreatorCache["shadows_c1"] or 0,category="shadows_c1",desc="",type="slider",min=0,max=64},
        {label=RSG.Texts.Blushing_Cheek,value=CreatorCache["blush_t"] or 1,category="blush_t",desc="",type="slider",min=1,max=4},
        {label=RSG.Texts.Clarity,value=CreatorCache["blush_op"] or 0,category="blush_op",desc="",type="slider",min=0,max=100,hop=5},
        {label=RSG.Texts.blush_id,value=CreatorCache["blush_id"] or 1,category="blush_id",desc="",type="slider",min=1,max=25},
        {label=RSG.Texts.blush_c1,value=CreatorCache["blush_c1"] or 0,category="blush_c1",desc="",type="slider",min=0,max=64},
        {label=RSG.Texts.Lipstick,value=CreatorCache["lipsticks_t"] or 1,category="lipsticks_t",desc="",type="slider",min=1,max=7},
        {label=RSG.Texts.Clarity,value=CreatorCache["lipsticks_op"] or 0,category="lipsticks_op",desc="",type="slider",min=0,max=100,hop=5},
        {label=RSG.Texts.ColorLipstick,value=CreatorCache["lipsticks_id"] or 1,category="lipsticks_id",desc="",type="slider",min=1,max=25},
        {label=RSG.Texts.lipsticks_c1,value=CreatorCache["lipsticks_c1"] or 0,category="lipsticks_c1",desc="",type="slider",min=0,max=64},
        {label=RSG.Texts.lipsticks_c2,value=CreatorCache["lipsticks_c2"] or 0,category="lipsticks_c2",desc="",type="slider",min=0,max=64},
        {label=RSG.Texts.Eyeliners,value=CreatorCache["eyeliners_t"] or 1,category="eyeliners_t",desc="",type="slider",min=1,max=15},
        {label=RSG.Texts.Clarity,value=CreatorCache["eyeliners_op"] or 0,category="eyeliners_op",desc="",type="slider",min=0,max=100,hop=5},
        {label=RSG.Texts.eyeliners_id,value=CreatorCache["eyeliners_id"] or 1,category="eyeliners_id",desc="",type="slider",min=1,max=25},
        {label=RSG.Texts.eyeliners_c1,value=CreatorCache["eyeliners_c1"] or 0,category="eyeliners_c1",desc="",type="slider",min=0,max=64}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'makeup_character_creator_menu',
        {title=RSG.Texts.Make_up,subtext=RSG.Texts.Options,align=RSG.Texts.align,elements=elements,itemHeight="4vh"}, function(data, menu)
    end, function(data, menu) MainMenu() end, function(data, menu)
        if CreatorCache[data.current.category] ~= data.current.value then
            CreatorCache[data.current.category] = data.current.value
            LoadOverlays(PlayerPedId(), CreatorCache)
        end
    end)
end

-- ==========================================
-- Attention
-- ==========================================

exports('GetComponentId', function(name) return LoadedComponents[name] end)

exports('GetBodyComponents', function() return {ComponentsMale, ComponentsFemale} end)

exports('GetBodyCurrentComponentHash', function(name)
    local hash
    if name == "hair" or name == "beard" then
        local info = LoadedComponents[name]
        -- Critical hashname / beard_hashname (scenario to LoadHair)
        if LoadedComponents[name .. '_hashname'] and LoadedComponents[name .. '_hashname'] ~= '' then
            hash = GetHashKey(LoadedComponents[name .. '_hashname'])
        elseif info and type(info) == "table" then
            local texture = info.texture or info.color or 1
            local model = info.model or 0
            if model == 0 or texture == 0 then return end
            if IsPedMale(PlayerPedId()) then
                if hairs_list["male"] and hairs_list["male"][name] and hairs_list["male"][name][model] and hairs_list["male"][name][model][texture] then
                    hash = hairs_list["male"][name][model][texture].hash
                end
            else
                if hairs_list["female"] and hairs_list["female"][name] and hairs_list["female"][name][model] and hairs_list["female"][name][model][texture] then
                    hash = hairs_list["female"][name][model][texture].hash
                end
            end
        end
    else
        local id = LoadedComponents[name]
        if not id then return end
        if IsPedMale(PlayerPedId()) then
            if ComponentsMale[name] then hash = ComponentsMale[name][id] end
        else
            if ComponentsFemale[name] then hash = ComponentsFemale[name][id] end
        end
    end
    return hash
end)

exports('SetFaceOverlays', function(target, data) LoadOverlays(target, data) end)
exports('SetHair', function(target, data) LoadHair(target, data) end)
exports('SetBeard', function(target, data) LoadBeard(target, data) end)

exports('GetComponentsMax', function(name)
    if name == "hair" or name == "beard" then
        if IsPedMale(PlayerPedId()) then
            if hairs_list["male"][name] then return #hairs_list["male"][name] end
        else
            if hairs_list["female"][name] then return #hairs_list["female"][name] end
        end
    else
        if IsPedMale(PlayerPedId()) then
            if ComponentsMale[name] then return #ComponentsMale[name] end
        else
            if ComponentsFemale[name] then return #ComponentsFemale[name] end
        end
    end
end)

exports('GetMaxTexturesForModel', function(category, model)
    return GetMaxTexturesForModel(category, model)
end)

exports('ApplySkin', ApplySkin)

exports('GetCurrentSkinTone', function()
    local function n(v)
        local t = tonumber(v)
        if not t then return nil end
        t = math.floor(t + 0.5)
        if t < 1 then t = 1 end
        if t > 6 then t = 6 end
        return t
    end
    if CurrentSkinData and CurrentSkinData.skin_tone_override ~= nil then
        local t = n(CurrentSkinData.skin_tone_override)
        if t then return t end
    end
    if CurrentSkinData and CurrentSkinData.skin_tone ~= nil then
        local t = n(CurrentSkinData.skin_tone)
        if t then return t end
    end
    if CreatorCache and CreatorCache.skin_tone ~= nil then
        local t = n(CreatorCache.skin_tone)
        if t then return t end
    end
    if LoadedComponents and LoadedComponents.skin_tone ~= nil then
        local t = n(LoadedComponents.skin_tone)
        if t then return t end
    end
    return 1
end)

exports('GetCurrentSkinData', function() return CurrentSkinData or {} end)

exports('SetCurrentSkinData', function(data)
    if data and type(data) == 'table' then CurrentSkinData = data end
end)
