-- ==========================================
-- NAKED BODY SYSTEM v3.5 - MetaPed Fix
-- ==========================================

CurrentSkinData = CurrentSkinData or {}

local IsNaked = false
local SavedClothesBeforeNaked = {}

-- ! Please check it (look at clothes.lua!)
NakedBodyState = {
    lowerApplied = false,
    upperApplied = false,
    lastApplyTime = 0,
    isApplying = false,
    skinLoading = false,  -- in short: calling function ApplySkin does not work
    lastPedId = 0,        -- id of the last ped model naked body
    legsHiddenForSkirtBoots = false,  -- true = legs hidden (BODIES_LOWER) for (ex.: skirt/boots/overlays + decoration)
    lastLowerTex = nil,   -- last texture for naked body (on skin if skin tone is missing)
    lastUpperTex = nil,
}

-- in function UpdatePedVariation returning nil; otherwise, not allows to continue - selecting texture
local function RestoreReinsIfRiding(p)
    if p ~= PlayerPedId() or not IsPedOnMount(p) then return end
    local h = joaat('WEAPON_REINS')
    if h and h ~= 0 then
        GiveWeaponToPed(p, h, 0, false, true)
        SetCurrentPedWeapon(p, h, true)
    end
end

-- in function (unknown in creator.lua when SetPlayerModel)
function ResetNakedBodyFlags()
    NakedBodyState.lowerApplied = false
    NakedBodyState.upperApplied = false
    NakedBodyState.isApplying = false
    NakedBodyState.lastPedId = 0
    NakedBodyState.legsHiddenForSkirtBoots = false
    NakedBodyState.lastLowerTex = nil
    NakedBodyState.lastUpperTex = nil
    print('[NakedBody] Flags RESET (model changed)')
end

exports('ResetNakedBodyFlags', ResetNakedBodyFlags)

local TestTextureOverride = nil

local CategoryMetaHash = {
    ['shirts_full'] = 0x2026C46D,
    ['vests'] = 0x485EE834,
    ['coats'] = 0xE06D30CE,
    ['coats_closed'] = 0x662AC34,
    ['pants'] = 0x1D4C528A,
    ['skirts'] = 0xA0E3AB7F,
    ['dresses'] = 0x0662AC34,
    ['corsets'] = 0x485EE834,  -- FIX: submit = what about MetaPed and vests
    ['boots'] = 0x777EC6EF,    -- in short (what unknown: for naked lower - something returned is probably the issues)
    ['neckwear'] = 0x7A96FACA,  -- unknown/capture (shiw-medic: processing on overlays)
    ['neckties'] = 0x7A96FACA,  -- in short (what about this)
    ['masks'] = 0x7505EF42,     -- question (shiw-medic: processing on overlays)
}

local SkinToneToTexture = {
    [1] = "008",
    [2] = "001",
    [3] = "002",
    [4] = "003",
    [5] = "004",
    [6] = "005",
}

--- JSON not show public game on skin_tone ("4"). SkinToneToTexture["4"] == nil presented?
--- string.format("%03d",4) => "004", if that means other number 4 presented "003" returned - might becomes element code.
local function NormalizeSkinTone(raw)
    if raw == nil then return nil end
    local n = tonumber(raw)
    if not n then return nil end
    n = math.floor(n + 0.5)
    if n < 1 then n = 1 end
    if n > 6 then n = 6 end
    return n
end

function GetSkinTone(ped)
    local t
    local isCreatorPed = ped and ped ~= 0 and DoesEntityExist(ped) and ped ~= PlayerPedId()
    -- Character creation renders a separate preview ped. Its CreatorCache must
    -- win over the hidden live player's CurrentSkinData.
    if isCreatorPed and CreatorCache and CreatorCache.skin_tone ~= nil then
        t = NormalizeSkinTone(CreatorCache.skin_tone)
        if t then return t end
    end
    if CurrentSkinData and CurrentSkinData.skin_tone_override ~= nil then
        t = NormalizeSkinTone(CurrentSkinData.skin_tone_override)
        if t then return t end
    end
    if CurrentSkinData and CurrentSkinData.skin_tone ~= nil then
        t = NormalizeSkinTone(CurrentSkinData.skin_tone)
        if t then return t end
    end
    if CreatorCache and CreatorCache.skin_tone ~= nil then
        t = NormalizeSkinTone(CreatorCache.skin_tone)
        if t then return t end
    end
    if LoadedComponents and LoadedComponents.skin_tone ~= nil then
        t = NormalizeSkinTone(LoadedComponents.skin_tone)
        if t then return t end
    end
    return 1
end

function GetTextureNumber(ped)
    if TestTextureOverride then
        return TestTextureOverride
    end
    local skinTone = GetSkinTone(ped)
    return SkinToneToTexture[skinTone] or string.format("%03d", skinTone)
end

function SetSkinToneOverride(tone)
    if not CurrentSkinData then CurrentSkinData = {} end
    local t = NormalizeSkinTone(tone)
    if t then CurrentSkinData.skin_tone_override = t end
end

local function IsMale(ped)
    local result = IsPedMale(ped)
    return result == true or result == 1
end

exports('GetSkinTone', GetSkinTone)
exports('GetTextureNumber', GetTextureNumber)
exports('SetSkinToneOverride', SetSkinToneOverride)

local function IsPedWearingCategory(ped, category)
    if not ped or not DoesEntityExist(ped) then return false end
    local metaHash = CategoryMetaHash[category]
    if not metaHash then return false end
    local currentHash = Citizen.InvokeNative(0xFB4891BD7578CDC1, ped, metaHash)
    return currentHash and currentHash ~= 0
end

local function IsPedWearingAnyCategory(ped, categories)
    for _, cat in ipairs(categories) do
        if IsPedWearingCategory(ped, cat) then
            return true, cat
        end
    end
    return false, nil
end

exports('IsPedWearingCategory', IsPedWearingCategory)
exports('IsPedWearingAnyCategory', IsPedWearingAnyCategory)

-- in function details in clothes.lua (where selects is not unknown)
local _clothesCacheRef = nil

RegisterNetEvent('rsg-clothing:client:clothingLoaded')
AddEventHandler('rsg-clothing:client:clothingLoaded', function(clothesCache)
    _clothesCacheRef = clothesCache
end)

-- available selection returns means (vasc/venv/unknown)
-- cacheOverride: method returns - shows info on current _clothesCacheRef
local function HasLowerBodyInClothesCache(cacheOverride)
    local cache = (cacheOverride and type(cacheOverride) == 'table') and cacheOverride or _clothesCacheRef
    if not cache then return false end
    for _, cat in ipairs({'pants', 'skirts', 'dresses'}) do
        if cache[cat] and type(cache[cat]) == 'table'
            and cache[cat].hash and cache[cat].hash ~= 0 then
            return true
        end
    end
    return false
end

-- FIX: check render method for returns (unknown/unknown/reference - if detecting unknown selection not applies)
-- on something vests/corsets - process path created: naked overlay UPPERTORSO_FR1_055_CORSET001
--    returns of vest/corset exported returning; vest/corset processed returns
local function HasUpperBodyInClothesCache(cacheOverride)
    local cache = (cacheOverride and type(cacheOverride) == 'table') and cacheOverride or _clothesCacheRef
    if not cache then return false end
    for _, cat in ipairs({'shirts_full', 'coats', 'coats_closed', 'dresses'}) do
        if cache[cat] and type(cache[cat]) == 'table'
            and cache[cat].hash and cache[cat].hash ~= 0 then
            return true
        end
    end
    return false
end

-- Vest/corset function returns - overlay unknown from stels cont. possible expanded CheckNakedBody for outputs work (unknown vest)
local function HasVestOrCorsetOnlyInCache(cacheOverride)
    local cache = (cacheOverride and type(cacheOverride) == 'table') and cacheOverride or _clothesCacheRef
    if not cache then return false end
    local hasVest = cache['vests'] and cache['vests'].hash and cache['vests'].hash ~= 0
    local hasCorset = cache['corsets'] and cache['corsets'].hash and cache['corsets'].hash ~= 0
    if not (hasVest or hasCorset) then return false end
    if HasUpperBodyInClothesCache(cacheOverride) then return false end  -- possible important/output/unknown
    return true
end

function ApplyNakedLowerBody(ped, force)
    if not ped or not DoesEntityExist(ped) then
        ped = PlayerPedId()
    end
    if _G.DisableAutomaticBodyFixes then return false end
    
    local now = GetGameTimer()
    if not force and NakedBodyState.isApplying and (now - NakedBodyState.lastApplyTime) < 500 then
        return false
    end
    
    NakedBodyState.isApplying = true
    NakedBodyState.lastApplyTime = now
    
    local isMale = IsMale(ped)
    local texNum = GetTextureNumber(ped)
    
    print('[NakedBody] ApplyLower: male=' .. tostring(isMale) .. ' tex=' .. texNum)
    
    if isMale then
        local draw = GetHashKey("LOWERTORSO_MR1_000")
        local alb = GetHashKey("FEET_MR1_000_C0_" .. texNum .. "_AB")
        local norm = GetHashKey("FEET_MR1_000_C0_000_NM")
        local mati = GetHashKey("FEET_MR1_000_C0_000_M")
        
        local texture = Citizen.InvokeNative(0xC5E7204F322E49EB, alb, norm)
        if texture then Citizen.InvokeNative(0x92DAABA2C1C10B0E, texture) end
        Wait(100)
        Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, draw, alb, norm, mati, 0, 0, 0, 0)
    else
        local draw = GetHashKey("LOWERTORSO_FR1_003")
        local alb = GetHashKey("FEET_FR1_000_C0_" .. texNum .. "_AB")
        local norm = GetHashKey("FEET_FR1_000_C0_000_NM")
        local mati = GetHashKey("FEET_FR1_000_C0_000_M")
        
        local texture = Citizen.InvokeNative(0xC5E7204F322E49EB, alb, norm)
        if texture then Citizen.InvokeNative(0x92DAABA2C1C10B0E, texture) end
        Wait(100)
        Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, draw, alb, norm, mati, 0, 0, 0, 0)
    end
    
    Wait(50)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
    RestoreReinsIfRiding(ped)
    NakedBodyState.lowerApplied = true
    NakedBodyState.lastLowerTex = texNum
    NakedBodyState.lastPedId = ped
    NakedBodyState.isApplying = false
    
    print('[NakedBody] ApplyLower: completed (raw overlay) tex=' .. texNum)
    return true
end

function ApplyNakedUpperBody(ped, force)
    if not ped or not DoesEntityExist(ped) then
        ped = PlayerPedId()
    end
    if _G.DisableAutomaticBodyFixes then return false end
    
    if IsMale(ped) then
        return false
    end
    
    local now = GetGameTimer()
    if not force and NakedBodyState.isApplying and (now - NakedBodyState.lastApplyTime) < 500 then
        return false
    end
    
    NakedBodyState.isApplying = true
    NakedBodyState.lastApplyTime = now
    
    local texNum = GetTextureNumber(ped)
    
    print('[NakedBody] ApplyUpper: tex=' .. texNum)
    
    local draw = GetHashKey("UPPERTORSO_FR1_055_CORSET001")
    local alb = GetHashKey("HAND_FR1_000_C0_" .. texNum .. "_AB")
    local norm = GetHashKey("HAND_FR1_000_C0_000_NM")
    local mati = GetHashKey("HAND_FR1_000_C0_000_M")
    
    local texture = Citizen.InvokeNative(0xC5E7204F322E49EB, alb, norm)
    if texture then Citizen.InvokeNative(0x92DAABA2C1C10B0E, texture) end
    Wait(100)
    Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, draw, alb, norm, mati, 0, 0, 0, 0)
    
    Wait(50)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
    RestoreReinsIfRiding(ped)
    NakedBodyState.upperApplied = true
    NakedBodyState.lastUpperTex = texNum
    NakedBodyState.lastPedId = ped
    NakedBodyState.isApplying = false
    
    print('[NakedBody] ApplyUpper: completed (raw overlay) tex=' .. texNum)
    return true
end

exports('ApplyNakedLowerBody', ApplyNakedLowerBody)
exports('ApplyNakedUpperBody', ApplyNakedUpperBody)

-- v3.5: Naked body continuing raw overlay (0xBC6DF00D7A4A6819).
-- its unknown: someone informed about  depreciated structure with unsuitable MetaPed process.
-- includes description return - naked body receives corresponding returning raw overlay.

-- for your feedback naked body (what new details for information)
local NakedUpperDraw = GetHashKey("UPPERTORSO_FR1_055_CORSET001")
local NakedLowerDrawMale = GetHashKey("LOWERTORSO_MR1_000")
local NakedLowerDrawFemale = GetHashKey("LOWERTORSO_FR1_003")

-- for show request BODIES_LOWER (what known) - too effective requests returns unknown forms what is seen. visible output + unknown
local BODIES_LOWER_CATEGORY = 0x823687F5

-- skipMetaPedRemoval = true returns structure that informs output - clears overlay, suggestion clothes.lua
function RemoveNakedLowerBody(ped, skipMetaPedRemoval, forceClear)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    if NakedBodyState.lowerApplied or forceClear then
        local draw = IsMale(ped) and NakedLowerDrawMale or NakedLowerDrawFemale
        Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, draw, 0, 0, 0, 0, 0, 0, 0)
        if not skipMetaPedRemoval then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x1D4C528A, 0)
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xA0E3AB7F, 0)
        end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        RestoreReinsIfRiding(ped)
        print('[NakedBody] RemoveLower: overlay cleared' .. (skipMetaPedRemoval and ' (clothing on)' or ''))
    end
    NakedBodyState.lowerApplied = false
    NakedBodyState.lastLowerTex = nil
end

function RemoveNakedUpperBody(ped, skipMetaPedRemoval, forceClear)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    if NakedBodyState.upperApplied or forceClear then
        Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, NakedUpperDraw, 0, 0, 0, 0, 0, 0, 0)
        if not skipMetaPedRemoval then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x2026C46D, 0)
        end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        RestoreReinsIfRiding(ped)
        print('[NakedBody] RemoveUpper: overlay cleared' .. (skipMetaPedRemoval and ' (clothing on)' or ''))
    end
    NakedBodyState.upperApplied = false
    NakedBodyState.lastUpperTex = nil
end

exports('RemoveNakedLowerBody', RemoveNakedLowerBody)
exports('RemoveNakedUpperBody', RemoveNakedUpperBody)

function CheckAndApplyNakedBodyIfNeeded(ped, clothesCache)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then
        ped = PlayerPedId()
    end
    
    -- for processing: maybe construction works ApplySkin does not work
    if NakedBodyState.skinLoading then
        print('[NakedBody] === CHECK SKIPPED (skinLoading=true) ===')
        return
    end
    
    -- on creation-request: someone will share questions (supplement SetPlayerModel), expects possible
    if NakedBodyState.lastPedId ~= 0 and NakedBodyState.lastPedId ~= ped then
        print('[NakedBody] Ped changed (' .. tostring(NakedBodyState.lastPedId) .. ' -> ' .. tostring(ped) .. '), resetting flags')
        NakedBodyState.lowerApplied = false
        NakedBodyState.upperApplied = false
        NakedBodyState.lastPedId = 0
        NakedBodyState.legsHiddenForSkirtBoots = false
        NakedBodyState.lastLowerTex = nil
        NakedBodyState.lastUpperTex = nil
    end
    
    local isMale = IsMale(ped)
    
    print('[NakedBody] === CHECK ===')
    
    local hasLower = IsPedWearingAnyCategory(ped, {'pants', 'skirts', 'dresses'})
    -- request feedback: can inquire - that/unknown/unknown requests naked body
    if not hasLower then
        hasLower = HasLowerBodyInClothesCache(clothesCache)
    end
    -- returns + overlay: possible detection naked lower - returning (FEET/LOWERTORSO) presents like someone affects expected returning
    local hasBoots = IsPedWearingCategory(ped, 'boots')
    if not hasBoots and clothesCache and type(clothesCache['boots']) == 'table' and clothesCache['boots'].hash and clothesCache['boots'].hash ~= 0 then
        hasBoots = true
    end
    -- Boots alone do not cover the hips/legs. Hiding the naked lower layer here
    -- made Pants 0 leave female characters with no lower body. The separate
    -- skirt/pants + boots rule below still hides the legs mesh when required.
    local hideNakedLower = hasLower
    
    -- returns + unknown/unknown/unknown + returns: someone displays processing receiving (BODIES_LOWER), indication where something makes expected processing
    local hasSkirtOrDress = IsPedWearingAnyCategory(ped, {'skirts', 'dresses'})
    if not hasSkirtOrDress and clothesCache then
        hasSkirtOrDress = (type(clothesCache['skirts']) == 'table' and clothesCache['skirts'].hash and clothesCache['skirts'].hash ~= 0)
            or (type(clothesCache['dresses']) == 'table' and clothesCache['dresses'].hash and clothesCache['dresses'].hash ~= 0)
    end
    local hasPants = IsPedWearingCategory(ped, 'pants')
    if not hasPants and clothesCache then
        hasPants = type(clothesCache['pants']) == 'table' and clothesCache['pants'].hash and clothesCache['pants'].hash ~= 0
    end
    local shouldHideLegsMesh = (not isMale and hasBoots and (hasSkirtOrDress or hasPants))
    
    if shouldHideLegsMesh then
        -- include naked overlay will expect anyone for feedback (BODIES_LOWER) - someone details on output
        if NakedBodyState.lowerApplied then
            RemoveNakedLowerBody(ped, true)
        end
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, BODIES_LOWER_CATEGORY, 0)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        NakedBodyState.legsHiddenForSkirtBoots = true
    else
        -- belonging importance unknown detail, see new decorations
        if NakedBodyState.legsHiddenForSkirtBoots then
            NakedBodyState.legsHiddenForSkirtBoots = false
            local ok, err = pcall(function()
                exports['rsg-appearance']:RestoreBodiesLower(ped)
            end)
            if not ok then
                print('[NakedBody] RestoreBodiesLower error: ' .. tostring(err))
            end
        end
        
    if not hideNakedLower then
        -- FIX: last town overlay value skin_tone updating (where unknown promotes in default=1 across loading)
        local currentTex = GetTextureNumber()
        local needApply = not NakedBodyState.lowerApplied or (NakedBodyState.lastLowerTex and NakedBodyState.lastLowerTex ~= currentTex)
        if needApply then
            if NakedBodyState.lowerApplied then RemoveNakedLowerBody(ped, true) end
            ApplyNakedLowerBody(ped, true)
        end
    else
        -- show/unknown/unknown returns comes something apart from so. - receiving naked overlay
        if NakedBodyState.lowerApplied then
            RemoveNakedLowerBody(ped, true)
        end
    end
    end
    
    if not isMale then
        -- question/unknown/unknown how expected requested returned concerning placeholder, receiving last process overlays from example staying variable
        local hasUpper = IsPedWearingAnyCategory(ped, {'shirts_full', 'dresses', 'coats', 'coats_closed'})
        if not hasUpper then
            hasUpper = HasUpperBodyInClothesCache(clothesCache)
        end
        local hasVestOnly = HasVestOrCorsetOnlyInCache(clothesCache)
        print('[NakedBody] hasUpper=' .. tostring(hasUpper) .. ' hasVestOnly=' .. tostring(hasVestOnly))
        
        if hasUpper or hasVestOnly then
            -- unknown/variable/standpoint get lined - qualified without receiving naked overlay (what coordinate with refreshing stays)
            if NakedBodyState.upperApplied then
                RemoveNakedUpperBody(ped, true)
            end
        else
            -- about what means show working along returns - that visible on regular overlay affect drawing skin_tone volumes
            local currentTex = GetTextureNumber()
            local needApply = not NakedBodyState.upperApplied or (NakedBodyState.lastUpperTex and NakedBodyState.lastUpperTex ~= currentTex)
            if needApply then
                if NakedBodyState.upperApplied then RemoveNakedUpperBody(ped, true) end
                ApplyNakedUpperBody(ped, true)
            end
        end
    end
end

exports('CheckAndApplyNakedBodyIfNeeded', CheckAndApplyNakedBodyIfNeeded)

-- offer to unknown returns (unknown/format/unknown+unknown): whoever displayed concerning BODIES_LOWER. hence naked upper/vest - before loadcharacter takes _PedStateFrozen
function ApplyLegsStateForSkirtBoots(ped, clothesCache)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    local isMale = IsMale(ped)
    if isMale then return end
    local cache = clothesCache
    if not cache then pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end) end
    local hasSkirtOrDress = IsPedWearingAnyCategory(ped, {'skirts', 'dresses'})
    if not hasSkirtOrDress and cache then
        hasSkirtOrDress = (type(cache['skirts']) == 'table' and cache['skirts'].hash and cache['skirts'].hash ~= 0)
            or (type(cache['dresses']) == 'table' and cache['dresses'].hash and cache['dresses'].hash ~= 0)
    end
    local hasPants = IsPedWearingCategory(ped, 'pants')
    if not hasPants and cache then
        hasPants = type(cache['pants']) == 'table' and cache['pants'].hash and cache['pants'].hash ~= 0
    end
    local hasBoots = IsPedWearingCategory(ped, 'boots')
    if not hasBoots and cache and type(cache['boots']) == 'table' and cache['boots'].hash and cache['boots'].hash ~= 0 then
        hasBoots = true
    end
    local shouldHideLegsMesh = hasBoots and (hasSkirtOrDress or hasPants)
    if shouldHideLegsMesh then
        if NakedBodyState.lowerApplied then RemoveNakedLowerBody(ped, true) end
        -- on unknown item arranging BODIES_LOWER - hence 0x704C/0xCC8CA, how requesting something to supporting condition where something will see
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, BODIES_LOWER_CATEGORY, 0)
        NakedBodyState.legsHiddenForSkirtBoots = true
    else
        if NakedBodyState.legsHiddenForSkirtBoots then
            NakedBodyState.legsHiddenForSkirtBoots = false
            pcall(function() exports['rsg-appearance']:RestoreBodiesLower(ped) end)
        end
    end
end
exports('ApplyLegsStateForSkirtBoots', ApplyLegsStateForSkirtBoots)

-- some conditions retained (naked/unknown): showing management details what from arising regarding wondering 
function RefreshCharacterNakedState(ped)
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    local cache = nil
    pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
    CheckAndApplyNakedBodyIfNeeded(ped, cache)
end
exports('RefreshCharacterNakedState', RefreshCharacterNakedState)

RegisterNetEvent('rsg-appearance:client:ApplyClothesComplete')
AddEventHandler('rsg-appearance:client:ApplyClothesComplete', function(targetPed, skinData)
    if NakedBodyState.skinLoading then return end
    if _G._PedStateFrozen then return end
    local ped = (targetPed and DoesEntityExist(targetPed)) and targetPed or PlayerPedId()
    if ped ~= PlayerPedId() then return end
    local cache = nil
    pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
    CheckAndApplyNakedBodyIfNeeded(ped, cache)
end)

exports('IsNakedLowerApplied', function() return NakedBodyState.lowerApplied end)
exports('IsNakedUpperApplied', function() return NakedBodyState.upperApplied end)
exports('GetNakedBodyState', function() return NakedBodyState end)

RegisterNetEvent('rsg-appearance:client:SetSkinTone')
AddEventHandler('rsg-appearance:client:SetSkinTone', function(skinTone)
    local tone = NormalizeSkinTone(skinTone)
    if tone then
        if not CurrentSkinData then CurrentSkinData = {} end
        CurrentSkinData.skin_tone = tone
        LoadedComponents = LoadedComponents or {}
        LoadedComponents.skin_tone = tone
        -- FIX: given update naked body and unforeseen concerns skin_tone (promising processing whether supported concern)
        SetTimeout(300, function()
            local cache = nil
            pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
            CheckAndApplyNakedBodyIfNeeded(PlayerPedId(), cache)
        end)
    end
end)

CreateThread(function()
    Wait(5000)
    TriggerServerEvent('rsg-appearance:server:RequestSkinTone')
    local timeout = 0
    while NakedBodyState.skinLoading and timeout < 30 do
        Wait(500)
        timeout = timeout + 1
    end
    Wait(2000)
    local cache = nil
    pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
    CheckAndApplyNakedBodyIfNeeded(PlayerPedId(), cache)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded')
AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    Wait(3000)
    TriggerServerEvent('rsg-appearance:server:RequestSkinTone')
    local timeout = 0
    while NakedBodyState.skinLoading and timeout < 30 do
        Wait(500)
        timeout = timeout + 1
    end
    Wait(2000)
    local cache = nil
    pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
    CheckAndApplyNakedBodyIfNeeded(PlayerPedId(), cache)
end)

RegisterNetEvent('rsg-appearance:client:ApplySkinComplete')
AddEventHandler('rsg-appearance:client:ApplySkinComplete', function()
    -- showing structure made thus housing what building plans - creator.lua exhibited existing design plans
    if NakedBodyState.skinLoading then
        print('[NakedBody] ApplySkinComplete: Skipped (skinLoading=true)')
        return
    end
    -- new processing for _PedStateFrozen (loadcharacter) - informing modulating creates concerned naked overlay returning vest
    if _G._PedStateFrozen then
        print('[NakedBody] ApplySkinComplete: Skipped (_PedStateFrozen)')
        return
    end
    Wait(1500)
    -- FIX: updating ClothesCache - revealing returns changed children without keeps returns presents false by structure process naked body
    local cache = nil
    pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
    CheckAndApplyNakedBodyIfNeeded(PlayerPedId(), cache)
end)

RegisterNetEvent('rsg-appearance:client:CheckNakedBody')
AddEventHandler('rsg-appearance:client:CheckNakedBody', function()
    Wait(300)
    local cache = nil
    pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
    CheckAndApplyNakedBodyIfNeeded(PlayerPedId(), cache)
end)

RegisterNetEvent('rsg-appearance:client:ApplyClothes')
AddEventHandler('rsg-appearance:client:ApplyClothes', function(clothesData, ped, skinData)
    if skinData and skinData.skin_tone ~= nil then
        local t = NormalizeSkinTone(skinData.skin_tone)
        if t then
            CurrentSkinData = CurrentSkinData or {}
            CurrentSkinData.skin_tone = t
        end
    end
    -- illustrating visibility structure housing what building realities - creator.lua exhibited existing design plans
    if NakedBodyState.skinLoading then
        print('[NakedBody] ApplyClothes: Skipped check (skinLoading=true)')
        return
    end
    SetTimeout(2000, function()
        local cache = nil
        pcall(function() cache = exports['rsg-appearance']:GetClothesCache() end)
        CheckAndApplyNakedBodyIfNeeded(PlayerPedId(), cache)
    end)
end)

-- RegisterNetEvent returns usage not to creator.lua - what hand shows existed, RegisterNetEvent exposes handling
RegisterNetEvent('rsg-appearance:client:ApplySkin')
AddEventHandler('rsg-appearance:client:ApplySkin', function(skinData, clothesData)
    if skinData and skinData.skin_tone ~= nil then
        local t = NormalizeSkinTone(skinData.skin_tone)
        if t then
            CurrentSkinData = CurrentSkinData or {}
            CurrentSkinData.skin_tone = t
        end
    end
    -- showing existing things mentioning without processing (creator.lua presents on those requests bringing exists)
    NakedBodyState.skinLoading = true
    -- existing methods from. SetPlayerModel fits requests operated thus over.
    NakedBodyState.lowerApplied = false
    NakedBodyState.upperApplied = false
    NakedBodyState.lastPedId = 0
    NakedBodyState.lastLowerTex = nil
    NakedBodyState.lastUpperTex = nil
    print('[NakedBody] ApplySkin received: skinLoading=true, flags RESET')
end)

if Config.Debug == true then
RegisterCommand('testnaked', function()
    local ped = PlayerPedId()
    print('=== NAKED TEST ===')
    print('SkinTone: ' .. GetSkinTone())
    print('IsMale: ' .. tostring(IsMale(ped)))
    print('lowerApplied: ' .. tostring(NakedBodyState.lowerApplied))
    print('upperApplied: ' .. tostring(NakedBodyState.upperApplied))
    print('--- Native check ---')
    for _, cat in ipairs({'pants', 'skirts', 'dresses', 'shirts_full', 'coats', 'vests'}) do
        print('  ' .. cat .. ': ' .. tostring(IsPedWearingCategory(ped, cat)))
    end
end, false)

RegisterCommand('checknaked', function()
    NakedBodyState.lowerApplied = false
    NakedBodyState.upperApplied = false
    CheckAndApplyNakedBodyIfNeeded(PlayerPedId())
end, false)

RegisterCommand('forcenaked', function()
    local ped = PlayerPedId()
    NakedBodyState.lowerApplied = false
    NakedBodyState.upperApplied = false
    ApplyNakedLowerBody(ped, true)
    Wait(300)
    if not IsMale(ped) then
        ApplyNakedUpperBody(ped, true)
    end
end, false)

RegisterCommand('resetnaked', function()
    NakedBodyState.lowerApplied = false
    NakedBodyState.upperApplied = false
    print('[NakedBody] Flags reset')
end, false)

RegisterCommand('fixskintone', function(src, args)
    local tone = tonumber(args[1])
    if tone and tone >= 1 and tone <= 6 then
        SetSkinToneOverride(tone)
        TriggerServerEvent('rsg-appearance:server:FixSkinTone', tone)
    else
        print('Usage: /fixskintone [1-6]')
    end
end, false)

end

print('[NakedBody] v3.5 loaded (raw overlay + active removal)')
