-- ==========================================
-- RSG-APPEARANCE LOAD FUNCTIONS
-- ? BODY MORPH SYSTEM 3: BODY MORPH ? ?
-- ? ? ? ? _G._BodyMorphData
-- ? ? ? ? (body morph) body morph
-- ==========================================

local Data = require 'data.features'
local Overlays = require 'data.overlays'

function IsRicxSlimBodyEnabled()
    return type(RSG) == 'table' and RSG.RicxOutfitSlimBody and RSG.RicxOutfitSlimBody.enabled == true
end

function IsRicxOutfitBodyMeshHideEnabled()
    return type(RSG) == 'table' and RSG.RicxOutfitHideBodyMesh and RSG.RicxOutfitHideBodyMesh.enabled == true
end

local function ScheduleRicxOutfitBodyMeshHide()
    if not _G._RicxOutfitActive or not IsRicxOutfitBodyMeshHideEnabled() then return end
    CreateThread(function()
        Wait(80)
        TriggerEvent('rsg-appearance:client:applyRicxBodyMeshHide')
    end)
end

-- ? ? ? body morph (from 0-100 ? SetPedFaceFeature + ? ? ? ?)
_G._BodyMorphData = _G._BodyMorphData or {
    active = false,
    size_hash = nil,
    waist_hash = nil,
    chest_hash = nil,
    -- ? ? ? ? Face Feature (0-100), ? ? ? ? RDR2
    waist_value = nil,   -- 0-100 (waist / size)
    chest_value = nil,   -- 0-100 (chest)
    size_value = nil,    -- 0-100 (size, ?/?)
}

-- ==========================================
-- ?
-- ==========================================

local function SetPedFaceFeature(ped, feature, value)
    Citizen.InvokeNative(0x5653AB26C82938CF, ped, feature, value / 100.0)
end

-- ? ? ? UpdatePedVariation
local function SetPedBodyComponent(ped, hash)
    Citizen.InvokeNative(0x1902C4CFCC5BE57C, ped, hash)
end

local function SetPedComponent(ped, hash)
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
end

-- ? ? ? ? ? ? ? (from ? ? ? ? ped' ?).
-- ? ?/? ? ? ? sex: 1/2, 0/1, male/female.
local function ResolveGenderFromData(ped, data)
    if type(data) == 'table' and data.sex ~= nil then
        local sxNum = tonumber(data.sex)
        if sxNum ~= nil then
            -- ? rsg-appearance male=1, female=2; ? ? ? female=0.
            if sxNum == 1 then return 'male' end
            return 'female'
        end
        local sx = string.lower(tostring(data.sex))
        if sx == 'male' or sx == 'm' then return 'male' end
        if sx == 'female' or sx == 'f' then return 'female' end
    end
    return IsPedMale(ped) and 'male' or 'female'
end

--- RedM: ? mp_female ? ? ? ? ? ? 0 ? ?; ? ApplyHead ? ? 7 + p3=true (?. hate_style_clone.lua, forum Cfx).
function ApplyFemaleMpMetaBasePreset(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if IsPedMale(ped) then return end
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, 7, true)
    Wait(120)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    Wait(80)
end

--- 1 = male, 2 = female. ? ? sex ? ? JSON - ? charinfo.gender (rsg-core: 0=male, 1=female). 0 ? ? ? ? ?.
function NormalizeAppearanceSex(skinData)
    if type(skinData) ~= 'table' then return end
    local s = tonumber(skinData.sex)
    if s ~= nil then
        if s == 0 then skinData.sex = 2 end
        return
    end
    local ok, RSGCore = pcall(function() return exports['rsg-core']:GetCoreObject() end)
    if not ok or not RSGCore then
        skinData.sex = 1
        return
    end
    local pd = RSGCore.Functions.GetPlayerData()
    local g = pd and pd.charinfo and tonumber(pd.charinfo.gender)
    if g == 1 then
        skinData.sex = 2
    elseif g == 0 then
        skinData.sex = 1
    else
        skinData.sex = 1
    end
end

function IsAppearanceFemaleSkin(skinData)
    if type(skinData) ~= 'table' then return false end
    local s = tonumber(skinData.sex)
    if s == nil then return false end
    return s ~= 1
end

-- ==========================================
-- ? ? ?
-- ==========================================

function LoadHead(ped, data)
    if not ped or not DoesEntityExist(ped) then
        ped = CreatorPed
        if not ped or not DoesEntityExist(ped) then
            print('[RSG-Appearance] LoadHead: No valid ped')
            return
        end
    end

    local headIndex = tonumber(data.head) or 1
    local skinTone = tonumber(data.skin_tone) or 1
    local gender = ResolveGenderFromData(ped, data)

    print('[RSG-Appearance] LoadHead: head=' .. tostring(headIndex) .. ' skinTone=' .. tostring(skinTone))

    local clotheslist = require 'data.clothes_list'

    local heads = {}
    for _, item in ipairs(clotheslist) do
        if item.category_hashname == 'heads' and item.ped_type == gender and item.is_multiplayer then
            if item.hashname and item.hashname ~= "" then
                table.insert(heads, {hash = item.hash, hashname = item.hashname})
            end
        end
    end

    -- ? ? ? 20 ? ? ? (20 ? 6 ? = 120 ? ?)
    local maxHeadsPerGender = 20 * 6
    if #heads > maxHeadsPerGender then
        for i = maxHeadsPerGender + 1, #heads do heads[i] = nil end
    end

    print('[RSG-Appearance] LoadHead: Found ' .. #heads .. ' heads (max 20 face types)')

    if #heads > 0 then
        local tonesPerModel = 6
        headIndex = math.max(1, math.min(20, headIndex))
        skinTone = math.max(1, math.min(tonesPerModel, skinTone))
        local idx = ((headIndex - 1) * tonesPerModel) + skinTone
        if idx < 1 then idx = 1 end
        if idx > #heads then
            idx = math.min(idx, #heads)
        end

        local headData = heads[idx]
        if headData and headData.hash then
            print('[RSG-Appearance] LoadHead: Applying hash ' .. tostring(headData.hash) .. ' (idx=' .. idx .. ')')
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, headData.hash) -- ? FIX: Request ? Apply
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, headData.hash, true, true, true)

            -- ? FIX: ? ? ? ? 300 ? ? 2 ? ? ? ?
            local timeout = 0
            while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and timeout < 100 do
                Wait(20)
                timeout = timeout + 1
            end
            
            -- ? FIX: ? ? ? ? ?
            if timeout >= 100 then
                print('[RSG-Appearance] LoadHead: Streaming timeout, retrying...')
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, headData.hash)
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, headData.hash, true, true, true)
                local timeout2 = 0
                while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and timeout2 < 100 do
                    Wait(20)
                    timeout2 = timeout2 + 1
                end
            end

            Citizen.InvokeNative(0x704C908E9C405136, ped)
            if NativeUpdatePedVariation then NativeUpdatePedVariation(ped) else Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) end
            -- ? ? ? body morph ? ? UpdatePedVariation
            if _G._BodyMorphData and _G._BodyMorphData.active then
                ReapplyBodyMorph(ped)
            end
        end
    end
end

-- ==========================================
-- ? ? ?
-- ==========================================

function LoadBoody(ped, data)
    if not ped or not DoesEntityExist(ped) then
        ped = CreatorPed
        if not ped or not DoesEntityExist(ped) then
            print('[RSG-Appearance] LoadBoody: No valid ped')
            return
        end
    end

    local skinTone = data.skin_tone or 1
    local gender = ResolveGenderFromData(ped, data)

    print('[RSG-Appearance] LoadBoody: gender=' .. gender .. ' skinTone=' .. tostring(skinTone))

    local clotheslist = require 'data.clothes_list'

    local bodies_upper = {}
    local bodies_lower = {}

    for _, item in ipairs(clotheslist) do
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

    print('[RSG-Appearance] LoadBoody: Found ' .. #bodies_upper .. ' BODIES_UPPER, ' .. #bodies_lower .. ' BODIES_LOWER')

    -- ? FIX: ? ? ? ? ? ? ? ?
    if #bodies_upper > 0 then
        local idx = math.min(skinTone, #bodies_upper)
        if idx < 1 then idx = 1 end

        local bodyData = bodies_upper[idx]
        if bodyData and bodyData.hash then
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, bodyData.hash)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyData.hash, true, true, true)

            local timeout = 0
            while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and timeout < 100 do
                Wait(20)
                timeout = timeout + 1
            end

            if timeout >= 100 then
                print('[RSG-Appearance] LoadBoody upper: Streaming timeout, retrying...')
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, bodyData.hash)
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyData.hash, true, true, true)
                local t2 = 0
                while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t2 < 100 do
                    Wait(20)
                    t2 = t2 + 1
                end
            end
        end
    end

    if #bodies_lower > 0 then
        local idx = math.min(skinTone, #bodies_lower)
        if idx < 1 then idx = 1 end

        local bodyData = bodies_lower[idx]
        if bodyData and bodyData.hash then
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, bodyData.hash)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyData.hash, true, true, true)

            local timeout = 0
            while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and timeout < 100 do
                Wait(20)
                timeout = timeout + 1
            end

            if timeout >= 100 then
                print('[RSG-Appearance] LoadBoody lower: Streaming timeout, retrying...')
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, bodyData.hash)
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyData.hash, true, true, true)
                local t2 = 0
                while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t2 < 100 do
                    Wait(20)
                    t2 = t2 + 1
                end
            end
        end
    end

    Wait(50)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)

    if isMale then
        Wait(100)
        local componentsLoaded = Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped)
        if not componentsLoaded then
            if #bodies_upper > 0 then
                local idx = math.min(skinTone, #bodies_upper)
                local bodyData = bodies_upper[idx]
                if bodyData and bodyData.hash then
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, bodyData.hash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyData.hash, true, true, true)
                end
            end

            if #bodies_lower > 0 then
                local idx = math.min(skinTone, #bodies_lower)
                local bodyData = bodies_lower[idx]
                if bodyData and bodyData.hash then
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, bodyData.hash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyData.hash, true, true, true)
                end
            end

            Wait(100)
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        end
    end

    print('[RSG-Appearance] LoadBoody: Completed for ' .. gender)
    -- ? ? ? body morph ? ? LoadBoody (UpdatePedVariation ? ? face features)
    if _G._BodyMorphData and _G._BodyMorphData.active then
        ReapplyBodyMorph(ped)
    end
end

-- ==========================================
-- ? ? ?
-- ==========================================

function LoadHeight(ped, data)
    if not ped or not DoesEntityExist(ped) then return end

    local height = data.height or 100
    local scale = height / 100.0

    -- ? ? ? ? ? : 80-130
    scale = math.max(0.80, math.min(1.30, scale))
    SetPedScale(ped, scale)
end

-- ==========================================
-- ? ? ?
-- ==========================================

function LoadHair(ped, data)
    if not ped or not DoesEntityExist(ped) then
        ped = CreatorPed
        if not ped then return end
    end

    if data.hair_hashname and data.hair_hashname ~= "" then
        local hash = GetHashKey(data.hair_hashname)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("hair"), 0)
        Wait(50)
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
        -- ? FIX: ? ? ?
        local ht = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and ht < 100 do Wait(20) ht = ht + 1 end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        return
    end

    local hairData = data.hair or data
    local model = 0
    local color = 1

    if type(hairData) == 'table' then
        model = hairData.model or 0
        color = hairData.color or hairData.texture or 1
    elseif type(hairData) == 'number' then
        model = hairData
        color = data.hair_color or 1
    end

    if model == 0 then
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("hair"), 0)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        return
    end

    local gender = ResolveGenderFromData(ped, data)

    local hairs_list = nil
    pcall(function()
        hairs_list = require 'data.hairs_list'
    end)

    local targetHash = nil

    if hairs_list and hairs_list[gender] and hairs_list[gender]['hair'] then
        local hairModels = hairs_list[gender]['hair']
        if hairModels[model] and hairModels[model][color] then
            targetHash = hairModels[model][color].hash
        elseif hairModels[model] and hairModels[model][1] then
            targetHash = hairModels[model][1].hash
        end
    end

    if not targetHash then
        local clotheslist = require 'data.clothes_list'
        local hairs = {}
        for _, item in ipairs(clotheslist) do
            if item.category_hashname == 'hair' and item.ped_type == gender and item.is_multiplayer then
                table.insert(hairs, item.hash)
            end
        end
        if #hairs > 0 then
            local idx = ((model - 1) * 15) + color
            if idx < 1 then idx = 1 end
            if idx > #hairs then idx = math.min(model, #hairs) end
            targetHash = hairs[idx]
        end
    end

    if targetHash then
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, targetHash) -- ? FIX: Request ? Apply
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, targetHash, true, true, true)
        -- ? FIX: ? ? ?
        local ht = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and ht < 100 do Wait(20) ht = ht + 1 end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        -- ? FIX: ? ? ? - ? ? ? ? ? ? ? ?
        if not isMale then
            TriggerEvent('rsg-appearance:client:ReapplyHairAccessories', ped)
        end
    end
end

-- ==========================================
-- ? ? ?
-- ==========================================

function LoadBeard(ped, data)
    if not ped or not DoesEntityExist(ped) then
        ped = CreatorPed
        if not ped then return end
    end

    if not IsPedMale(ped) then return end

    if data.beard_hashname and data.beard_hashname ~= "" then
        local hash = GetHashKey(data.beard_hashname)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_complete"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_stubble"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("mustache"), 0)
        Wait(50)
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
        -- ? FIX: ? ? ?
        local bt = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and bt < 100 do Wait(20) bt = bt + 1 end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        return
    end

    local beardData = data.beard or data
    local model = 0
    local color = 1

    if type(beardData) == 'table' then
        model = beardData.model or 0
        color = beardData.color or beardData.texture or 1
    elseif type(beardData) == 'number' then
        model = beardData
        color = data.beard_color or 1
    end

    if model == 0 then
        -- ? ? ? rsg-barbershop: ? ? ?
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beard"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_complete"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_stubble"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("mustache"), 0)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        return
    end

    local hairs_list = nil
    pcall(function()
        hairs_list = require 'data.hairs_list'
    end)

    local targetHash = nil

    -- ? ? ? rsg-barbershop: ? ? hairs_list['male']['beard'] (from ? + ?)
    local beardSource = (hairs_list and hairs_list['male'] and hairs_list['male']['beard']) or
                       (hairs_list and hairs_list['male'] and hairs_list['male']['mustache'])
    if beardSource and beardSource[model] then
        local colors = beardSource[model]
        if colors[color] then
            targetHash = colors[color].hash
        elseif colors[1] then
            targetHash = colors[1].hash
        end
    end

    if not targetHash then
        local clotheslist = require 'data.clothes_list'
        local beards = {}
        for _, item in ipairs(clotheslist) do
            if (item.category_hashname == 'beards_complete' or item.category_hashname == 'beard' or item.category_hashname == 'mustache')
               and item.ped_type == 'male' and item.is_multiplayer then
                table.insert(beards, item.hash)
            end
        end
        if #beards > 0 then
            local idx = ((model - 1) * 15) + color
            if idx < 1 then idx = 1 end
            if idx > #beards then idx = math.min(model, #beards) end
            targetHash = beards[idx]
        end
    end

    if targetHash then
        -- ? ? ? rsg-barbershop: ? ? ? ? ? ? ?
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beard"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_complete"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("beards_stubble"), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("mustache"), 0)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        Wait(50)
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, targetHash)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, targetHash, true, true, true)
        local bt = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and bt < 100 do Wait(20) bt = bt + 1 end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    end
end

-- ==========================================
-- ? ? ?
-- ==========================================

local EyesHashCache = { male = {}, female = {} }
local EyesCacheBuilt = false

local function BuildEyesCache()
    if EyesCacheBuilt then return end
    local clotheslist = require 'data.clothes_list'
    for _, item in ipairs(clotheslist) do
        if item.category_hashname == 'eyes' and item.is_multiplayer then
            if item.hashname and item.hashname ~= "" and string.find(item.hashname, "EYES_001_TINT") then
                local gender = item.ped_type
                if EyesHashCache[gender] then
                    table.insert(EyesHashCache[gender], { hash = item.hash, hashname = item.hashname })
                end
            end
        end
    end
    EyesCacheBuilt = true
end

function LoadEyes(ped, data)
    if not ped or not DoesEntityExist(ped) then
        ped = CreatorPed
        if not ped then return end
    end

    local eyeColor = data.eyes_color or data.eyes or 1
    local gender = ResolveGenderFromData(ped, data)

    BuildEyesCache()

    local targetHash = nil
    local eyesList = EyesHashCache[gender]
    if eyesList and #eyesList > 0 then
        local idx = math.max(1, math.min(eyeColor, #eyesList))
        targetHash = eyesList[idx].hash
    end

    if targetHash then
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("eyes"), 0)
        Wait(50)
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, targetHash) -- ? FIX: Request ? Apply
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, targetHash, true, true, true)
        -- ? FIX: ? ? ? ? ? ?
        local timeout = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and timeout < 100 do
            Wait(20)
            timeout = timeout + 1
        end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    end
end

-- ==========================================
-- ? ? ?
-- ? ? UpdatePedVariation v7: ? ? ? body morph features - ? ? ? ? ? LoadAllBodyShape
-- ==========================================

local BodyMorphFeatureNames = {
    waist_width = true,
    chest_size = true,
    hips_size = true,
    arms_size = true,
    tight_size = true,
    calves_size = true,
    uppr_shoulder_size = true,
    back_shoulder_thickness = true,
    back_muscle = true,
}

function LoadFeatures(ped, data)
    if not ped or not DoesEntityExist(ped) then return end
    if type(data) ~= 'table' then return end
    for featureName, featureHash in pairs(Data.features) do
        -- ? ? ? body morph features - ? ? ? ? ?
        if not BodyMorphFeatureNames[featureName] then
            -- ? ? ? ? ? ? ?.
            local value = tonumber(data[featureName])
            if value ~= nil then
                if value > 100 then value = 100 end
                if value < -100 then value = -100 end
                SetPedFaceFeature(ped, featureHash, value)
            end
        end
    end
    -- ? ? LoadFeatures - ? ? ? body morph
    if _G._BodyMorphData and _G._BodyMorphData.active then
        ReapplyBodyMorph(ped)
    end
end

-- ==========================================
-- ? ? ? ? ? ( ? UpdatePedVariation)
-- ==========================================

function LoadBodyFeature(ped, value, hashTable)
    if not ped or not DoesEntityExist(ped) then return end
    if not hashTable or not value then return end

    local index = math.floor(value)
    if index < 1 then index = 1 end
    if index > #hashTable then index = #hashTable end

    local hash = hashTable[index]
    if hash and hash ~= 0 then
        SetPedBodyComponent(ped, hash)
    end
end

-- ==========================================
-- ? BODY MORPH SYSTEM v7 - ? ? ?
-- ? ? ? ? ? :
-- 1. SetPedBodyComponent (0x1902C4CFCC5BE57C) - ? ? ? ? ?
-- 2. SetPedFaceFeature (0x5653AB26C82938CF) - face features ? ? ? ?
-- ==========================================

local F = Data.features

local function toPct(value, minVal, maxVal)
    if not value then return nil end
    local v = math.floor(value)
    if v < minVal then v = minVal end
    if v > maxVal then v = maxVal end
    return math.floor((v - minVal) / (maxVal - minVal) * 100)
end

-- ? ? ? waist: 1-21 ? 0-100, 22-30 ? 105-145
local function waistToPct(value)
    if not value then return nil end
    local v = math.floor(value)
    if v < 1 then v = 1 end
    if v > 30 then v = 30 end
    if v <= 21 then
        return math.floor((v - 1) / 20 * 100)
    else
        return 100 + math.floor((v - 21) / 9 * 45)
    end
end

-- ? ? ? face features ? ? body morph ( ? ?)
-- ? v8: ? ? ? waist ? ? ? ? ? ? ?
function ApplyBodyMorphFaceFeatures(ped, waistVal, chestVal, sizeVal, fineData)
    if not ped or not DoesEntityExist(ped) then return end

    fineData = fineData or {}

    local function FineTune(value, adjustment, maximum)
        if value == nil then return nil end
        value = value + (tonumber(adjustment) or 0)
        return math.max(-100, math.min(maximum or 100, value))
    end

    -- ? ?/?
    if waistVal ~= nil and F.waist_width then
        SetPedFaceFeature(ped, F.waist_width, FineTune(waistVal, fineData.waist_width, 145))
    end

    -- ? ?
    if chestVal ~= nil then
        if F.chest_size then
            if IsPedMale(ped) then
                SetPedFaceFeature(ped, F.chest_size, chestVal)
            else
                SetPedFaceFeature(ped, F.chest_size, tonumber(fineData.breast_size) or 0)
            end
        end
        if F.back_muscle then SetPedFaceFeature(ped, F.back_muscle, FineTune(chestVal, fineData.back_muscle)) end
        if F.back_shoulder_thickness then SetPedFaceFeature(ped, F.back_shoulder_thickness, FineTune(math.floor(chestVal * 0.7), fineData.back_shoulder_thickness)) end
    end

    -- ? ? ? hips/thighs ? body_size ? waist ? ? ? ?
    -- ? > 50% ? ? ? ? ? ? ? ? ? ? ? ?
    local baseSize = sizeVal or 0
    local waistBonus = 0
    if waistVal and waistVal > 30 then
        waistBonus = math.floor((waistVal - 30) * 0.7)
    end

    local combinedHips = math.min(100, baseSize + waistBonus)
    local combinedThighs = math.min(100, math.floor(baseSize * 0.8) + math.floor(waistBonus * 0.4))

    if F.hips_size then SetPedFaceFeature(ped, F.hips_size, FineTune(combinedHips, fineData.hips_size)) end
    if F.tight_size then SetPedFaceFeature(ped, F.tight_size, FineTune(combinedThighs, fineData.tight_size)) end
    if F.calves_size then SetPedFaceFeature(ped, F.calves_size, FineTune(math.floor(baseSize * 0.6), fineData.calves_size)) end
    if F.arms_size then SetPedFaceFeature(ped, F.arms_size, FineTune(baseSize, fineData.arms_size)) end
    if F.uppr_shoulder_size then SetPedFaceFeature(ped, F.uppr_shoulder_size, FineTune(math.floor(baseSize * 0.7), fineData.uppr_shoulder_size)) end
end

-- ? SetPedPortAndWeight ( ? hate_framework): ? ? body archetype ? ? ? ? ? ? ? ?
-- body_waist 1-30 → porte index 132-150 (male) / 114-132 (female)
function SetPedPortFromSkin(ped, skinData)
    if not ped or not DoesEntityExist(ped) or not skinData then return end
    local bodyWaist = tonumber(skinData.body_waist) or 11
    bodyWaist = math.max(1, math.min(30, bodyWaist))
    local isMale = IsPedMale(ped)
    local offset = isMale and 131 or 113
    local porteIndex = offset + math.floor((bodyWaist - 1) / 29 * 18) + 1
    Citizen.InvokeNative(0xA5BAE410B03E7371, ped, porteIndex, false, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
end

-- ? ? ? ? ? : ? ? ? - chest_size ? ? ? ? ( ? ? ? ? ? ? ? ?)
local function HasVestEquipped()
    local ok, has = pcall(function() return exports['rsg-appearance']:HasVestEquipped() end)
    return ok and has
end

-- ? ? ? ? ? : ? ? body morph ? ? + face features + ? ? ? _G
function ApplyAllBodyMorph(ped, skinData)
    if not ped or not DoesEntityExist(ped) then return end
    if not skinData then return end

    local bodyWaist = skinData.body_waist or 11
    local bodySize = skinData.body_size or 3
    local chestSize = skinData.chest_size or 6
    local skipChest = HasVestEquipped()
    if skipChest then chestSize = 6 end -- ? ? ? ?

    -- ? ? face feature ? ?
    local waistVal = waistToPct(bodyWaist)
    local chestVal = skipChest and nil or toPct(chestSize, 1, 11)
    local sizeVal = toPct(bodySize, 1, 5)

    -- ? ? ? ? ? ? ? ? ? guard ? ReapplyBodyMorph
    _G._BodyMorphData = {
        active = true,
        body_waist = bodyWaist,
        body_size = bodySize,
        chest_size = chestSize,
        skip_chest = skipChest,
        waist_value = waistVal,
        chest_value = chestVal,
        size_value = sizeVal,
        breast_size = skinData.breast_size,
        back_muscle = skinData.back_muscle,
        back_shoulder_thickness = skinData.back_shoulder_thickness,
        uppr_shoulder_size = skinData.uppr_shoulder_size,
        arms_size = skinData.arms_size,
        waist_width = skinData.waist_width,
        hips_size = skinData.hips_size,
        tight_size = skinData.tight_size,
        calves_size = skinData.calves_size,
        size_hash = nil,
        waist_hash = nil,
        chest_hash = nil,
    }

    -- ? ? 0: SetPedPort ? ? hate_framework) - body archetype ? ? ? ? ? ?
    SetPedPortFromSkin(ped, skinData)

    -- ? ? 1: Hash-based body components
    local waistIdx = math.min(bodyWaist, #Data.Appearance.body_waist)
    if waistIdx < 1 then waistIdx = 1 end
    LoadBodyFeature(ped, waistIdx, Data.Appearance.body_waist)

    LoadBodyFeature(ped, bodySize, Data.Appearance.body_size)
    if not skipChest then
        LoadBodyFeature(ped, chestSize, Data.Appearance.chest_size)
    end

    -- ? ? 2: Face features (chest ? ? ?) ? ? ? ?
    ApplyBodyMorphFaceFeatures(ped, waistVal, chestVal, sizeVal, skinData)

    -- ? ? ? UpdatePedVariation - ? ? ? ? !

    print('[BodyMorph] Applied: waist=' .. tostring(bodyWaist) .. '→' .. tostring(waistVal) .. '% chest=' .. tostring(chestSize) .. (skipChest and ' (skip—vest)' or '→' .. tostring(chestVal) .. '%') .. ' size=' .. tostring(bodySize) .. '→' .. tostring(sizeVal) .. '%')
end

-- ? ? ? ? ? ? ricx_outfits ( ? ? ? ? ? ? ? ? ? ? ?)
-- ? data/features.lua: body_waist[1] ? chest_size[1] - ? ? ? ?; ? ? ? ?/ ? ? ?
local SLIM_WAIST, SLIM_SIZE, SLIM_CHEST = 1, 1, 1

-- ? ? ? ? ? ? ? ? ? ? ? ? ? ? ricx - ? MP *_BODIES_*_001_* ( ? ? ? ? ? ? 1-6).
local function getSkinToneClampedForSlimMesh()
    local t = 1
    if CurrentSkinData and CurrentSkinData.skin_tone ~= nil then
        t = tonumber(CurrentSkinData.skin_tone) or 1
    elseif LoadedComponents and LoadedComponents.skin_tone ~= nil then
        t = tonumber(LoadedComponents.skin_tone) or 1
    elseif CreatorCache and CreatorCache.skin_tone ~= nil then
        t = tonumber(CreatorCache.skin_tone) or 1
    end
    t = math.floor((t or 1) + 0.5)
    return math.max(1, math.min(6, t))
end

local function ApplySlimMultiplayerBodyMeshes(ped)
    if not ped or not DoesEntityExist(ped) then return end
    local okList, clotheslist = pcall(function() return require 'data.clothes_list' end)
    if not okList or type(clotheslist) ~= 'table' then return end
    local gender = IsPedMale(ped) and 'male' or 'female'
    local bodies_upper = {}
    local bodies_lower = {}
    for _, item in ipairs(clotheslist) do
        if item.ped_type == gender and item.is_multiplayer then
            if item.hashname and item.hashname ~= '' then
                if item.category_hashname == 'BODIES_UPPER' then
                    table.insert(bodies_upper, item.hash)
                elseif item.category_hashname == 'BODIES_LOWER' then
                    table.insert(bodies_lower, item.hash)
                end
            end
        end
    end
    local toneIdx = getSkinToneClampedForSlimMesh()
    if toneIdx > #bodies_upper then toneIdx = math.max(1, math.min(6, #bodies_upper)) end
    if toneIdx > #bodies_lower then toneIdx = math.max(1, math.min(6, #bodies_lower)) end
    if toneIdx < 1 then toneIdx = 1 end

    local function applyBodyMeshSlot(hash, slotName)
        if not hash or hash == 0 then return end
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey(string.lower(slotName)))
        Wait(15)
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
        Wait(15)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
        local t = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t < 60 do
            Wait(20)
            t = t + 1
        end
    end

    if bodies_upper[toneIdx] then applyBodyMeshSlot(bodies_upper[toneIdx], 'BODIES_UPPER') end
    Wait(40)
    if bodies_lower[toneIdx] then applyBodyMeshSlot(bodies_lower[toneIdx], 'BODIES_LOWER') end
end

function ApplySlimBodyForOutfit(ped)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    if not DoesEntityExist(ped) then return end
    ApplySlimMultiplayerBodyMeshes(ped)
    local waistVal = waistToPct(SLIM_WAIST)
    local chestVal = toPct(SLIM_CHEST, 1, 11)
    local sizeVal = toPct(SLIM_SIZE, 1, 5)
    SetPedPortFromSkin(ped, { body_waist = SLIM_WAIST })
    local wi = math.min(SLIM_WAIST, #Data.Appearance.body_waist)
    if wi < 1 then wi = 1 end
    local h = Data.Appearance.body_waist[wi]
    if h and h ~= 0 then SetPedBodyComponent(ped, h) end
    LoadBodyFeature(ped, SLIM_SIZE, Data.Appearance.body_size)
    LoadBodyFeature(ped, SLIM_CHEST, Data.Appearance.chest_size)
    -- ? ? ? : ? ? 0-5% ( ? ? ? ?/ ? ? ?)
    ApplyBodyMorphFaceFeatures(ped, waistVal, chestVal, sizeVal)
    if F.arms_size then SetPedFaceFeature(ped, F.arms_size, 0) end
    if F.uppr_shoulder_size then SetPedFaceFeature(ped, F.uppr_shoulder_size, 0) end
    if F.back_muscle then SetPedFaceFeature(ped, F.back_muscle, 0) end
    if F.back_shoulder_thickness then SetPedFaceFeature(ped, F.back_shoulder_thickness, 0) end
    -- ? ? ? ? ? ? ? ? ? ? ? ? ( ? ? ? ? ? ?)
    if F.chest_size then SetPedFaceFeature(ped, F.chest_size, 0) end
    if F.waist_width then SetPedFaceFeature(ped, F.waist_width, 0) end
    if F.hips_size then SetPedFaceFeature(ped, F.hips_size, 0) end
    if F.tight_size then SetPedFaceFeature(ped, F.tight_size, 0) end
    if F.calves_size then SetPedFaceFeature(ped, F.calves_size, 0) end
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)

    -- ? hate_framework (skinManager kafcustomskin / vorpcharacter): SET_PED_OUTFIT_PRESET + ? ? ?
    local tune = _G._RicxHateStyleTune
    if tune and tune.enabled then
        if tune.removeMaleFacialDecorations and IsPedMale(ped) then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xF8016BCA, 0)
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x15D3C7F2, 0)
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xB6B63737, 0)
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xECC8B25A, 0)
        end
        local preset, p3
        local byId = tune.presetByCustomId
        local cid = tune.customId
        if byId and cid and type(byId[cid]) == 'table' then
            local o = byId[cid]
            preset = tonumber(o.preset)
            p3 = o.p3 == true
        elseif IsPedMale(ped) then
            preset = tonumber(tune.presetMale)
            p3 = tune.presetMaleP3 == true
        else
            preset = tonumber(tune.presetFemale)
            p3 = tune.presetFemaleP3 == true
        end
        if preset ~= nil then
            Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, preset, p3)
        end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    end
    -- ? ? slim ? ? ? ? ? ? BODIES_* - ? ? ? ? ? ? ?
    ScheduleRicxOutfitBodyMeshHide()
end

-- ? ? ? body morph ? ? _G._BodyMorphData
-- ? ? ? guard, LoadFeatures, clothes.lua, ricx_outfits ? ?.
function ReapplyBodyMorph(ped)
    if _G._PedStateFrozen then return end
    if _G._HateCloneSuppressBodyMorph then return end
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end

    -- ? ricx_outfits: ? ? ? ? ( ? ? RSG.RicxOutfitSlimBody - ? ? ? ? ? ?/ ? ? ?)
    if _G._RicxOutfitActive and IsRicxSlimBodyEnabled() then
        ApplySlimBodyForOutfit(ped)
        TriggerEvent('rsg-appearance:client:afterBodyMorph', ped)
        return
    end

    if not _G._BodyMorphData or not _G._BodyMorphData.active then
        if _G._RicxOutfitActive then
            ScheduleRicxOutfitBodyMeshHide()
        end
        return
    end
    local bm = _G._BodyMorphData
    SetPedPortFromSkin(ped, { body_waist = bm.body_waist or 11 })

    -- ★ Hash-based body components
    if bm.body_waist then
        local waistIdx = math.min(bm.body_waist, #Data.Appearance.body_waist)
        if waistIdx < 1 then waistIdx = 1 end
        local hash = Data.Appearance.body_waist[waistIdx]
        if hash and hash ~= 0 then
            SetPedBodyComponent(ped, hash)
        end
    end
    if bm.body_size then
        LoadBodyFeature(ped, bm.body_size, Data.Appearance.body_size)
    end
    local skipChest = bm.skip_chest or HasVestEquipped()
    if not skipChest and bm.chest_size then
        LoadBodyFeature(ped, bm.chest_size, Data.Appearance.chest_size)
    end

    -- ? Face features (chest ? ? ?) ? ? ? ?
    local chestVal = skipChest and nil or bm.chest_value
    ApplyBodyMorphFaceFeatures(ped, bm.waist_value, chestVal, bm.size_value, bm)

    -- Legacy ? ? ?
    if bm.size_hash then SetPedBodyComponent(ped, bm.size_hash) end
    if bm.waist_hash then SetPedBodyComponent(ped, bm.waist_hash) end
    if bm.chest_hash then SetPedBodyComponent(ped, bm.chest_hash) end

    -- ? ? : body morph ? ? ? ? - ? ? ? ? ? (clothes.lua ? ? ? throttle)
    TriggerEvent('rsg-appearance:client:afterBodyMorph', ped)
    if _G._RicxOutfitActive then
        ScheduleRicxOutfitBodyMeshHide()
    end
end

-- ? ? ? ? ? ? ? ? ( ? ? ? ? ? ? ? ? ? ?)
-- the display of appearance + UpdatePedVariation + update face features
function LoadAllBodyShape(ped, skinData)
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    if not skinData then return end

    -- overview of
    ApplyAllBodyMorph(ped, skinData)

    -- UpdatePedVariation updates the face features of a ped
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    Wait(50)

    -- applies additional face features through UpdatePedVariation
    -- (the display of UpdatePedVariation updates the face features)
    local bm = _G._BodyMorphData
    if bm and bm.active then
        local chestVal = bm.skip_chest and nil or bm.chest_value
        ApplyBodyMorphFaceFeatures(ped, bm.waist_value, chestVal, bm.size_value, bm)
    end

    print('[BodyMorph] LoadAllBodyShape complete')
end

-- Guard: overview (for 200?+1.5? - following additional matters). overview: 1 to 3?, outcome 5?
local _bodyMorphGuardActive = false
local _bodyMorphPersistentActive = false

function StartBodyMorphGuard(ped, duration_ms)
    if _G._PedStateFrozen then return end
    -- upper body to 3 (following overview 200?)
    if not _bodyMorphGuardActive then
        _bodyMorphGuardActive = true
        CreateThread(function()
            Wait(3000)
            local p = PlayerPedId()
            if DoesEntityExist(p) and not IsPedOnMount(p) and ((_G._BodyMorphData and _G._BodyMorphData.active) or (_G._RicxOutfitActive and IsRicxSlimBodyEnabled())) then
                ReapplyBodyMorph(p)
            end
            _bodyMorphGuardActive = false
        end)
    end

    -- additional guard: overview 5 to (for 1.5? - additional matters to explore)
    if not _bodyMorphPersistentActive then
        _bodyMorphPersistentActive = true
        CreateThread(function()
            while true do
                Wait(5000)
                if (_G._BodyMorphData and _G._BodyMorphData.active) or (_G._RicxOutfitActive and IsRicxSlimBodyEnabled()) then
                    local p = PlayerPedId()
                    if DoesEntityExist(p) and not IsPedOnMount(p) then
                        ReapplyBodyMorph(p)
                    end
                end
            end
        end)
    end
end

-- Guard over the overview:
-- additional overview (RMB/aim) face features overview.
-- body morph overview to aim to explore it in detail.
local _aimBodyMorphWasAiming = false
local _aimBodyMorphLastApplyAt = 0
local AIM_BODYMORPH_REAPPLY_MS = 900

CreateThread(function()
    while true do
        local sleepMs = 1200
        local hasMorph = (_G._BodyMorphData and _G._BodyMorphData.active) or (_G._RicxOutfitActive and IsRicxSlimBodyEnabled())

        if hasMorph and not _G._PedStateFrozen and not (LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoadingCharacter) then
            local ped = PlayerPedId()
            if ped and ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) and IsPedHuman(ped) then
                local aiming = IsPlayerFreeAiming(PlayerId()) == true

                if aiming then
                    sleepMs = 220
                    local now = GetGameTimer()
                    if not _aimBodyMorphWasAiming or (now - _aimBodyMorphLastApplyAt) >= AIM_BODYMORPH_REAPPLY_MS then
                        ReapplyBodyMorph(ped)
                        _aimBodyMorphLastApplyAt = now
                    end
                elseif _aimBodyMorphWasAiming then
                     -- applies overview for body morph to explore:
                     -- overview follows increasing detail based on how it responds to RMB.
                    SetTimeout(120, function()
                        if _G._PedStateFrozen then return end
                        if LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoadingCharacter then return end
                        local p = PlayerPedId()
                        if p and p ~= 0 and DoesEntityExist(p) and not IsEntityDead(p) and hasMorph then
                            ReapplyBodyMorph(p)
                        end
                    end)
                end

                _aimBodyMorphWasAiming = aiming
            end
        else
            _aimBodyMorphWasAiming = false
        end

        Wait(sleepMs)
    end
end)

-- ==========================================
-- summary overview
-- ==========================================

local textureId = -1

function ChangeOverlays(name, visibility, tx_id, tx_normal, tx_material, tx_color_type, tx_opacity, tx_unk, palette_id,
    palette_color_primary, palette_color_secondary, palette_color_tertiary, var, opacity)
    for k, v in pairs(Overlays.overlay_all_layers) do
        if v.name == name then
            v.visibility = visibility
            if visibility ~= 0 then
                v.tx_normal = tx_normal
                v.tx_material = tx_material
                v.tx_color_type = tx_color_type
                v.tx_opacity = tx_opacity
                v.tx_unk = tx_unk
                if tx_color_type == 0 then
                    v.palette = Overlays.color_palettes[palette_id] and Overlays.color_palettes[palette_id][1] or 0
                    v.palette_color_primary = palette_color_primary
                    v.palette_color_secondary = palette_color_secondary
                    v.palette_color_tertiary = palette_color_tertiary
                end
                if name == "shadows" or name == "eyeliners" or name == "lipsticks" then
                    v.var = var
                    v.tx_id = Overlays.overlays_info[name] and Overlays.overlays_info[name][1] and Overlays.overlays_info[name][1].id or 0
                else
                    v.var = 0
                    local entry = Overlays.overlays_info[name] and Overlays.overlays_info[name][tx_id]
                    if entry then
                        v.tx_id = entry.id or 0
                        v.tx_normal = entry.normal or 0
                        v.tx_material = entry.ma or 0
                    else
                        v.tx_id = 0
                    end
                end
                v.opacity = opacity
            end
        end
    end
end

function GetHeadIndex(ped)
    local numComponents = Citizen.InvokeNative(0x90403E8107B60E81, ped)
    if not numComponents then return false end
    for i = 0, numComponents - 1, 1 do
        local componentCategory = Citizen.InvokeNative(0x9b90842304c938a7, ped, i, 0, Citizen.ResultAsInteger())
        if componentCategory == GetHashKey('heads') then
            return i
        end
    end
    return false
end

function GetMetaPedAssetGuids(ped, index)
    return Citizen.InvokeNative(0xA9C28516A6DC9D56, ped, index, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
end

function ApplyOverlays(overlayTarget)
    if IsPedMale(overlayTarget) then
        Overlays.current_texture_settings = Overlays.texture_types["male"]
    else
        Overlays.current_texture_settings = Overlays.texture_types["female"]
    end

    if textureId ~= -1 then
        Citizen.InvokeNative(0xB63B9178D0F58D82, textureId)
        Citizen.InvokeNative(0x6BEFAA907B076859, textureId)
    end

    local index = GetHeadIndex(overlayTarget)
    if not index then return end

    local _, albedo, normal, material = GetMetaPedAssetGuids(overlayTarget, index)
    textureId = Citizen.InvokeNative(0xC5E7204F322E49EB, albedo, normal, material)

    for k, v in pairs(Overlays.overlay_all_layers) do
        if v.visibility ~= 0 then
            local overlay_id = Citizen.InvokeNative(0x86BB5FF45F193A02, textureId, v.tx_id, v.tx_normal, v.tx_material,
                v.tx_color_type, v.tx_opacity, v.tx_unk)
            if v.tx_color_type == 0 then
                Citizen.InvokeNative(0x1ED8588524AC9BE1, textureId, overlay_id, v.palette)
                Citizen.InvokeNative(0x2DF59FFE6FFD6044, textureId, overlay_id, v.palette_color_primary,
                    v.palette_color_secondary, v.palette_color_tertiary)
            end
            Citizen.InvokeNative(0x3329AAE2882FC8E4, textureId, overlay_id, v.var)
            Citizen.InvokeNative(0x6C76BC24F8BB709A, textureId, overlay_id, v.opacity)
        end
    end

    -- FIX: summary overview to 1? to 3? where overview follows
    local timeout = 0
    while not Citizen.InvokeNative(0x31DC8D3F216D8509, textureId) and timeout < 150 do
        Wait(20)
        timeout = timeout + 1
    end

    Citizen.InvokeNative(0x92DAABA2C1C10B0E, textureId)
    Citizen.InvokeNative(0x8472A1789478F82F, textureId)
    Citizen.InvokeNative(0x0B46E25761519058, overlayTarget, GetHashKey("heads"), textureId)
    Citizen.InvokeNative(0x704C908E9C405136, overlayTarget)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, overlayTarget, false, true, true, true, false)
end

function LoadOverlays(ped, data)
    if not ped or not DoesEntityExist(ped) then
        ped = CreatorPed
        if not ped then return end
    end

    -- FIX: summary overview to 5? to 10? where overview follows
    local timeout = 0
    local headIndex = GetHeadIndex(ped)
    while not headIndex and timeout < 100 do
        Wait(100)
        headIndex = GetHeadIndex(ped)
        timeout = timeout + 1
    end

    -- content follows overview for additional information overview details.
    -- each summary overview reflects detail (brightness, clarity, density and so on.)
    -- overview of the Overlays.overlay_all_layers and overview various details.
    for _, layer in pairs(Overlays.overlay_all_layers) do
        layer.visibility = 0
        layer.tx_id = 1
        layer.tx_normal = 0
        layer.tx_material = 0
        layer.tx_color_type = 0
        layer.tx_opacity = 1.0
        layer.tx_unk = 0
        layer.palette = 0
        layer.palette_color_primary = 0
        layer.palette_color_secondary = 0
        layer.palette_color_tertiary = 0
        layer.var = 0
        layer.opacity = 0.0
    end

    if tonumber(data.eyebrows_t) ~= nil and tonumber(data.eyebrows_op) ~= nil then
        ChangeOverlays("eyebrows", 1, tonumber(data.eyebrows_t), 0, 0, 0, 1.0, 0, tonumber(data.eyebrows_id) or 10,
            tonumber(data.eyebrows_c1) or 0, 0, 0, 0, tonumber(data.eyebrows_op) / 100)
    else
        ChangeOverlays("eyebrows", 1, 1, 0, 0, 0, 1.0, 0, 10, 0, 0, 0, 0, 1.0)
    end

    if tonumber(data.scars_t) ~= nil and tonumber(data.scars_op) ~= nil then
        ChangeOverlays("scars", 1, tonumber(data.scars_t), 0, 0, 1, 1.0, 0, 0, 0, 0, 0, 0, tonumber(data.scars_op) / 100)
    end

    if tonumber(data.ageing_t) ~= nil and tonumber(data.ageing_op) ~= nil then
        ChangeOverlays("ageing", 1, tonumber(data.ageing_t), 0, 0, 1, 1.0, 0, 0, 0, 0, 0, 0, tonumber(data.ageing_op) / 100)
    end

    if tonumber(data.freckles_t) ~= nil and tonumber(data.freckles_op) ~= nil then
        ChangeOverlays("freckles", 1, tonumber(data.freckles_t), 0, 0, 1, 1.0, 0, 0, 0, 0, 0, 0, tonumber(data.freckles_op) / 100)
    end

    if tonumber(data.moles_t) ~= nil and tonumber(data.moles_op) ~= nil then
        ChangeOverlays("moles", 1, tonumber(data.moles_t), 0, 0, 1, 1.0, 0, 0, 0, 0, 0, 0, tonumber(data.moles_op) / 100)
    end

    if tonumber(data.spots_t) ~= nil and tonumber(data.spots_op) ~= nil then
        ChangeOverlays("spots", 1, tonumber(data.spots_t), 0, 0, 1, 1.0, 0, 0, 0, 0, 0, 0, tonumber(data.spots_op) / 100)
    end

    -- each summary (hairov): 0 = black, 1-4 = bright overview
    if tonumber(data.hair_roots_t) ~= nil then
        local v = tonumber(data.hair_roots_t)
        if v >= 1 and v <= 4 then
            ChangeOverlays("hair", 1, v, 0, 0, 1, 1.0, 0, 0, 0, 0, 0, 0, 1.0)
        else
            ChangeOverlays("hair", 0, 1, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 0, 0.0)
        end
    end

    -- overview (of interface, brightness, density, integrity)
    if tonumber(data.shadows_t) ~= nil and tonumber(data.shadows_op) ~= nil then
        ChangeOverlays("shadows", 1, 1, 0, 0, 0, 1.0, 0, tonumber(data.shadows_id) or 1, tonumber(data.shadows_c1) or 0, 0, 0, tonumber(data.shadows_t) or 1, tonumber(data.shadows_op) / 100)
    end
    if tonumber(data.blush_t) ~= nil and tonumber(data.blush_op) ~= nil then
        ChangeOverlays("blush", 1, tonumber(data.blush_t), 0, 0, 0, 1.0, 0, tonumber(data.blush_id) or 1, tonumber(data.blush_c1) or 0, 0, 0, 0, tonumber(data.blush_op) / 100)
    end
    if tonumber(data.lipsticks_t) ~= nil and tonumber(data.lipsticks_op) ~= nil then
        ChangeOverlays("lipsticks", 1, 1, 0, 0, 0, 1.0, 0, tonumber(data.lipsticks_id) or 1, tonumber(data.lipsticks_c1) or 0, tonumber(data.lipsticks_c2) or 0, 0, tonumber(data.lipsticks_t) or 1, tonumber(data.lipsticks_op) / 100)
    end
    if tonumber(data.eyeliners_t) ~= nil and tonumber(data.eyeliners_op) ~= nil then
        ChangeOverlays("eyeliners", 1, 1, 0, 0, 0, 1.0, 0, tonumber(data.eyeliners_id) or 1, tonumber(data.eyeliners_c1) or 0, 0, 0, tonumber(data.eyeliners_t) or 1, tonumber(data.eyeliners_op) / 100)
    end

    ApplyOverlays(ped)
    -- applies additional body morph to ApplyOverlays (UpdatePedVariation updates face features)
    if _G._BodyMorphData and _G._BodyMorphData.active then
        ReapplyBodyMorph(ped)
    end
end

-- ==========================================
-- overview additional summary
-- ==========================================

function LoadStarterClothing(ped, category, model, texture)
    if not ped or not DoesEntityExist(ped) then
        ped = CreatorPed
        if not ped then return end
    end

    local isMale = IsPedMale(ped)
    local gender = isMale and 'male' or 'female'

    if model == 0 then
        if ped == PlayerPedId() then
            TriggerEvent('rsg-clothing:client:removeClothing', category, {
                deferBodyRefresh = true,
                refreshBody = true,
                skipResync = true,
            })
        else
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(category), 0)
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
            -- TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', category, true, ped)
        end
        return
    end

    local clothing = require 'data.clothing'
    local targetHash = nil
    texture = texture or 1

    if clothing[gender] and clothing[gender][category] then
        local categoryData = clothing[gender][category]
        if categoryData[model] then
            if categoryData[model][texture] and categoryData[model][texture].hash then
                targetHash = categoryData[model][texture].hash
            elseif categoryData[model][1] and categoryData[model][1].hash then
                targetHash = categoryData[model][1].hash
            end
        end
    end

    if not targetHash then
        local clotheslist = require 'data.clothes_list'
        local items = {}
        for _, item in ipairs(clotheslist) do
            if item.category_hashname == category and item.ped_type == gender and item.is_multiplayer then
                if item.hashname and item.hashname ~= "" then
                    table.insert(items, item.hash)
                end
            end
        end
        if #items > 0 then
            local idx = ((model - 1) * 10) + texture
            if idx < 1 then idx = 1 end
            if idx > #items then idx = math.min(model, #items) end
            targetHash = items[idx]
        end
    end

    if targetHash then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, targetHash, true, true, true)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
        -- TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', category, false, ped)
    end
end

-- TaskPlayAnim (overview summary) updates face overlays; overview follows additional summary
local _overlayAnimRefreshToken = 0
local OVERLAY_ANIM_REFRESH_MS = 220
local OVERLAY_ANIM_EXTRA_PASSES = { 900, 1800 }

local function SafeReapplyOverlaysFromLoadedComponents(token)
    if token ~= _overlayAnimRefreshToken then return end
    if _G._PedStateFrozen then return end
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoadingCharacter then return end
    if NakedBodyState and NakedBodyState.skinLoading then return end
    if _G.IsInCharCreation then return end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if IsEntityDead(ped) or (GetEntityHealth(ped) or 0) <= 0 then return end
    if not IsPedHuman(ped) then return end
    TriggerEvent('rsg-appearance:client:afterPedVariation')
end

AddEventHandler('rsg-appearance:client:scheduleOverlayRefreshAfterAnim', function()
    if _G._PedStateFrozen then return end
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoadingCharacter then return end
    if NakedBodyState and NakedBodyState.skinLoading then return end
    if _G.IsInCharCreation then return end
    _overlayAnimRefreshToken = _overlayAnimRefreshToken + 1
    local token = _overlayAnimRefreshToken
    SetTimeout(OVERLAY_ANIM_REFRESH_MS, function()
        SafeReapplyOverlaysFromLoadedComponents(token)
    end)

    -- overview/taking breaks summary for updates overlays overview.
    -- applies overview 2 "overview" summary, but overview follows details.
    for _, delay in ipairs(OVERLAY_ANIM_EXTRA_PASSES) do
        SetTimeout(delay, function()
            SafeReapplyOverlaysFromLoadedComponents(token)
        end)
    end
end)

-- each overview follows the overview to explore - overview follows summary overview for exploring body morph
AddEventHandler('rsg-appearance:client:requestBodyMorphReapply', function()
    if _G._BodyMorphData and _G._BodyMorphData.active then
        local p = PlayerPedId()
        if DoesEntityExist(p) then
            ReapplyBodyMorph(p)
        end
    end
end)

-- ricx_outfits: overview of these supplies (following additional overview, and so on for detailed summaries)
AddEventHandler('rsg-appearance:client:applySlimBodyForOutfit', function()
    if not IsRicxSlimBodyEnabled() then return end
    local p = PlayerPedId()
    if DoesEntityExist(p) and _G._RicxOutfitActive then
        ApplySlimBodyForOutfit(p)
    end
end)

local function SetRicxOutfitMode(active, customId)
    _G._RicxOutfitActive = active == true
    if _G._RicxOutfitActive then
        _G._RicxActiveOutfitCustomId = (type(customId) == 'string' and customId ~= '') and customId or nil
    else
        _G._RicxActiveOutfitCustomId = nil
    end
    local p = PlayerPedId()
    if not DoesEntityExist(p) then return end
    if _G._RicxOutfitActive then
        if IsRicxSlimBodyEnabled() then
            ApplySlimBodyForOutfit(p)
        elseif IsRicxOutfitBodyMeshHideEnabled() then
            ScheduleRicxOutfitBodyMeshHide()
        end
        return
    end
    pcall(function()
        exports['rsg-appearance']:RestoreRicxOutfitBodyMesh(p)
    end)
    if _G._BodyMorphData and _G._BodyMorphData.active then
        ReapplyBodyMorph(p)
    elseif type(LoadedComponents) == 'table' and (LoadedComponents.body_waist or LoadedComponents.body_size or LoadedComponents.chest_size) then
        pcall(function()
            ApplyAllBodyMorph(p, LoadedComponents)
            Citizen.InvokeNative(0x704C908E9C405136, p)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, p, false, true, true, true, false)
        end)
    end
end

RegisterNetEvent('rsg-appearance:client:SetRicxOutfitActive', function(active, customId)
    SetRicxOutfitMode(active == true, customId)
end)

-- ==========================================
-- overview
-- ==========================================

exports('LoadHead', LoadHead)
exports('LoadBoody', LoadBoody)
exports('LoadHeight', LoadHeight)
exports('LoadHair', LoadHair)
exports('LoadBeard', LoadBeard)
exports('LoadEyes', LoadEyes)
exports('LoadFeatures', LoadFeatures)
exports('LoadBodyFeature', LoadBodyFeature)
exports('ApplyAllBodyMorph', ApplyAllBodyMorph)
exports('SetPedPortFromSkin', SetPedPortFromSkin)
exports('ReapplyBodyMorph', ReapplyBodyMorph)
exports('ApplySlimBodyForOutfit', ApplySlimBodyForOutfit)
exports('SetRicxOutfitActive', SetRicxOutfitMode)
exports('IsRicxSlimBodyEnabled', IsRicxSlimBodyEnabled)
exports('IsRicxOutfitBodyMeshHideEnabled', IsRicxOutfitBodyMeshHideEnabled)
exports('LoadAllBodyShape', LoadAllBodyShape)
exports('StartBodyMorphGuard', StartBodyMorphGuard)
exports('LoadOverlays', LoadOverlays)
exports('LoadStarterClothing', LoadStarterClothing)
exports('ApplyFemaleMpMetaBasePreset', ApplyFemaleMpMetaBasePreset)
exports('NormalizeAppearanceSex', NormalizeAppearanceSex)

exports('GetHairsList', function()
    local hairs_list = nil
    pcall(function()
        hairs_list = require 'data.hairs_list'
        local extraRDR2Hairs = require 'data.extra_rdr2_hairs'
        if extraRDR2Hairs and extraRDR2Hairs.MergeExtraRDR2Hairs then
            extraRDR2Hairs.MergeExtraRDR2Hairs(hairs_list)
        end
    end)
    return hairs_list
end)

print('[RSG-Appearance] Load functions initialized (v3 - global body morph)')
