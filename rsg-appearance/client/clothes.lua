local RSGCore = exports['rsg-core']:GetCoreObject()

-- ??? ???'s ??? - debugcloth /testequip ? F8 ???

local function RegisterDebugCommand(name, handler, restricted)
    if Config.Debug == true then
        RegisterCommand(name, handler, restricted)
    end
end

RegisterDebugCommand('debugcloth', function()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local mp_male_hash = GetHashKey('mp_male')
    local mp_female_hash = GetHashKey('mp_female')
    print('====== CLOTHING DEBUG ======')
    print('PedId: ' .. tostring(ped))
    print('Model hash: ' .. tostring(model))
    print('Is mp_male: ' .. tostring(model == mp_male_hash))
    print('Is mp_female: ' .. tostring(model == mp_female_hash))
    print('IsPedMale: ' .. tostring(IsPedMale(ped)))
    print('DoesEntityExist: ' .. tostring(DoesEntityExist(ped)))
    print('IsReadyToRender: ' .. tostring(Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped)))
    print('--- ClothesCache ---')
    local count = 0
    for k, v in pairs(ClothesCache or {}) do
        if type(v) == 'table' then
            print('  ' .. tostring(k) .. ': hash=' .. tostring(v.hash) .. ', model=' .. tostring(v.model) .. ', tex=' .. tostring(v.texture))
            count = count + 1
        end
    end
    print('Total cached: ' .. count)
    print('============================')
end, false)

RegisterDebugCommand('testequip', function()
    local ped = PlayerPedId()
    print('====== TEST EQUIP ======')
    -- ??? ?'s ?? ClothesCache ? ??? ?? ???
    local testHash = nil
    local testCat = nil
    for k, v in pairs(ClothesCache or {}) do
        if type(v) == 'table' and v.hash and v.hash ~= 0 then
            testHash = v.hash
            testCat = k
            break
        end
    end
    if testHash then
        print('Re-applying ' .. tostring(testCat) .. ' hash=' .. tostring(testHash))
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, testHash)
        print('  > 0x59BD177A1A48600A (Request) called')
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, testHash, true, true, true)
        print('  > 0xD3A7B003ED343FD9 (Apply, immediately=true) called')
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        print('  > 0x704C908E9C405136 (Finalize) called')
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        print('  > 0xCC8CA3E88256E58F (UpdateVariation) called')
        print('DONE! Check if the clothing item appeared visually.')
    else
        print('ClothesCache is empty! Equip something first, then run /debugcloth')
    end
    print('========================')
end, false)

RegisterDebugCommand('testremove', function(source, args)
    local ped = PlayerPedId()
    local category = args[1] or 'hats'
    print('====== TEST REMOVE ======')
    print('Removing category: ' .. category)
    local compHash = GetHashKey(category)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, compHash, 0)
    print('  > 0xD710A5007C2AC539 (Remove by name) called')
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    print('  > 0x704C908E9C405136 (Finalize) called')
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    print('  > 0xCC8CA3E88256E58F (UpdateVariation) called')
    print('DONE! Check if the item was removed visually.')
    print('=========================')
end, false)

-- ??? ??? ??????????????? ?

local ClothingCamera = nil
local c_zoom = 2.4
local c_offset = -0.15
local CurrentPrice = 0
local CurentCoords = {}
local playerHeading = nil
local RoomPrompts = GetRandomIntInRange(0, 0xffffff)
local ClothesCache = {}
-- ??? ????????? ?????????????? (??? ?????? ????? ?? ?????? ?'s ???????? ????? ?'s)
local lastClothingLoadTime = 0
local OldClothesCache = {}
local PromptsEnabled = false
local IsInCharCreation = false
local Skinkosong = false
local ScheduleClothingResyncFromInventory = nil
local Divider = "<img style='margin-top: 10px;margin-bottom: 10px; margin-left: -10px;'src='nui://rsg-appearance/img/divider_line.png'>"
local image = "<img style='max-height:250px;max-width:250px;float: center;'src='nui://rsg-appearance/img/%s.png'>"

-- ? ?'s ???: body morph + ?'s ??? nativepaint/?(?.'s ? ?'s ??????? ??? UpdatePedVariation)
-- ? FIX: ??? _PedStateFrozen ?? ??? - ReapplyBodyMorph ??? ?'s ??? UpdatePedVariation
local function ReapplyAppearanceAfterClothing(ped)
    if not ped or not DoesEntityExist(ped) then return end
    if _G._PedStateFrozen then return end
    if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
    TriggerEvent('rsg-appearance:client:clothingApplied', ped)
end

-- ? ????????? ?? ??? ?? (??? Ped ?'s)
local CategoryComponentHash = {
    ['hats'] = 0x9925C067,
    ['shirts_full'] = 0x2026C46D,  -- ? ?'s???!
    ['shirts'] = 0x2026C46D,
    ['pants'] = 0x1D4C528A,        -- ? ?'s???!
    ['boots'] = 0x777EC6EF,
    ['vests'] = 0x485EE834,
    ['coats'] = 0xE06D30CE,        -- ? ?'s???!
    ['coats_closed'] = 0x662AC34,  -- ? ?'s???!
    ['gloves'] = 0xEABE0032,
    ['neckwear'] = 0x7A96FACA,     -- ? ?'s???!
    ['neckties'] = 0x7A96FACA,
    ['masks'] = 0x7505EF42,
    ['eyewear'] = 0x5F1BE9EC,      -- ? ?'s???!
    ['gunbelts'] = 0xF1542D11,     -- ? ?'s???!
    ['satchels'] = 0x94504D26,
    ['suspenders'] = 0x877A2CF7,
    ['chaps'] = 0x3107499B,
    ['spurs'] = 0x18729F39,
    ['cloaks'] = 0x3C1A74CD,
    ['ponchos'] = 0xAF14310B,
    ['skirts'] = 0xA0E3AB7F,
    ['belts'] = 0x9B2C8B89,
    ['belt_buckles'] = 0xDA0E2C55,
    ['dresses'] = 0x0662AC34,
    ['corsets'] = 0x485EE834,
    ['loadouts'] = 0x83887E88,
    ['gauntlets'] = 0x91CE9B20,
    ['holsters_left'] = 0x7A6BBD0B,
    ['holsters_right'] = 0x0B3966C9,
    ['accessories'] = 0x79D7DF96,
    ['badges'] = 0x79D7DF96,
    -- ?????????????? ????????
    ['hair_accessories'] = 0x79D7DF96,
    ['boot_accessories'] = 0x18729F39,
    ['talisman_belt'] = 0x1AECF7DC,
    -- ????????? - ?'s ??? (rdr2mods)
    ['jewelry_bracelets'] = 0x7BC10759,
    ['jewelry_rings_left'] = 0xF16A1D23,
    ['jewelry_rings_right'] = 0x7A6BBD0B,
    ['rings_rh'] = 0x7A6BBD0B,
    ['rings_lh'] = 0xF16A1D23,
    ['bracelets'] = 0x7BC10759,
    -- ??? (???? 0x72E6EF74 - ??'s ????, ? ?'s ???/?????)
    ['earrings'] = 0x72E6EF74,
    ['armor'] = 0x72E6EF74,
}

local clothing = require 'data.clothing'
local hashToCache = require 'client.hashtocache'
-- ??? ??? RSG ???
if not RSG then
    print('[RSG-Clothing] ERROR: RSG config not loaded!')
    RSG = {}
end
local UseClothingInventory = RSG.UseClothingInventory ~= false

-- ??? ???
CreateThread(function()
    Wait(1000)
    if RSG.Price then
        print('[RSG-Clothing] Prices loaded: ' .. TableLength(RSG.Price) .. ' categories')
    else
        print('[RSG-Clothing] ERROR: RSG.Price not found!')
    end
end)

function TableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- ??? ??? ?????????? ?'s ??
function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, f)
    local i = 0
    local iter = function()
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

-- ??? ???????????? ?????????? ?'s ???
function GetMaxTexturesForModel(category, model, checkGender)
    if model <= 0 then return 0 end
    
    local isMale = IsPedMale(PlayerPedId())
    local gender = isMale and "male" or "female"
    
    -- Hair and beard come from hairs_list, not clothing
    if category == "hair" or category == "beard" then
        local ok, hairs = pcall(require, 'data.hairs_list')
        if ok and hairs and hairs[gender] and hairs[gender][category] and hairs[gender][category][model] then
            local count = 0
            for k, _ in pairs(hairs[gender][category][model]) do
                if k > count then count = k end
            end
            return count
        end
        return 0
    end

    if not clothing[gender] or not clothing[gender][category] then
        return 0
    end
    
    if not clothing[gender][category][model] then
        return 0
    end
    
    local count = 0
    for texture, _ in pairs(clothing[gender][category][model]) do
        if texture > count then
            count = texture
        end
    end
    
    return count
end
-- ==========================================
-- ??? ?????????????? ?'s ??
-- ==========================================

-- ?'s ?? '?????' ?'s ???
local LowerBodyCutoffCategories = {
    'boots',
    'chaps', 
    'spurs',
    'boot_accessories',
    'spats'
}

-- ?'s ?? '?????' ?'s ???
local UpperBodyCutoffCategories = {
    'vests',
    'coats',
    'coats_closed',
    'suspenders',
    'gunbelts',
    'loadouts',
    'ponchos',
    'cloaks'
}

-- ?'s ?? ????????? ?'s ???
local LowerBodyCoverCategories = {
    'pants',
    'skirts',
    'dresses'
}

-- ?'s ?? ????????? ?'s ?'s ????
local UpperBodyCoverCategories = {
    'shirts_full',
    'dresses',
    'vests',
    'corsets',  -- ? ?'s/?'s - ???? ????, ??? ?'s ????
}

-- ??? ???? ?'s ???
local function IsCategoryEquipped(category)
    if not ClothesCache or not ClothesCache[category] then
        return false
    end
    
    local data = ClothesCache[category]
    if type(data) ~= 'table' then
        return false
    end
    
    -- ????????? hash ??? model
    if data.hash and data.hash ~= 0 then
        return true
    end
    
    if data.model and data.model > 0 then
        return true
    end
    
    return false
end

-- ??? hash ?? ??? ?? ???? ????????? ?? ??????
local function HasAnyCategory(categoryList)
    for _, cat in ipairs(categoryList) do
        if IsCategoryEquipped(cat) then
            return true
        end
    end
    return false
end

-- ??? hash ???????? ?? rsg-appearance
local function GetBodyHash(bodyType)
    local success, hash = pcall(function()
        return exports['rsg-appearance']:GetBodyCurrentComponentHash(bodyType)
    end)
    
    if success and hash and hash ~= 0 then
        return hash
    end
    
    return nil
end

-- ?'s ?????????? ?'s ??? hash ???? ?'s ???
local function GetBodyHashNative(ped, bodyType)
    local categoryHash = GetHashKey(bodyType == "BODIES_UPPER" and "bodies_upper" or "bodies_lower")
    local currentHash = Citizen.InvokeNative(0xFB4891BD7578CDC1, ped, categoryHash)
    return currentHash
end

-- ? Fallback: hash ???? ?? clothes_list (????? naked overlay - GetBodyHashNative ??? 0)
local function GetBodyHashFromClothesList(ped, bodyType)
    local isMale = (IsPedMale(ped) == 1 or IsPedMale(ped) == true)
    local gender = isMale and "male" or "female"
    local skinTone = 1
    pcall(function()
        skinTone = exports['rsg-appearance']:GetCurrentSkinTone() or LoadedComponents and LoadedComponents.skin_tone or 1
    end)
    if not skinTone or skinTone < 1 then skinTone = 1 end
    local list = require 'data.clothes_list'
    local bodies = {}
    for _, item in ipairs(list) do
        if item.ped_type == gender and item.hash and item.hash ~= 0 and item.category_hashname == bodyType then
            if item.is_multiplayer then table.insert(bodies, item.hash) end
        end
    end
    -- ? FIX: ? male ??? BODIES_LOWER ? is_multiplayer=false - fallback ??? ???
    if #bodies == 0 then
        for _, item in ipairs(list) do
            if item.ped_type == gender and item.hash and item.hash ~= 0 and item.category_hashname == bodyType then
                table.insert(bodies, item.hash)
            end
        end
    end
    if #bodies > 0 then
        local idx = math.min(skinTone, #bodies)
        return bodies[idx]
    end
    return nil
end

-- ??? ???????: ?'s ??????????? ???
function EnsureBodyIntegrity(ped, forceUpdate)
    if _G.DisableAutomaticBodyFixes then return false end
    if not ped or not DoesEntityExist(ped) then
        ped = PlayerPedId()
    end
    
    -- ? ?'s: ?'s ?????????? ???? naked body
    -- ???? naked body ??????? - ?? ?'s ????!
    local nakedState = nil
    pcall(function()
        nakedState = exports['rsg-appearance']:GetNakedBodyState()
    end)
    
    -- ? ?'s ????????? ?????????? ?????????? (???? ?'s ?? ?????????)
    if not nakedState and NakedBodyState then
        nakedState = NakedBodyState
    end
    
    local needsUpdate = false
    
    -- ===============================
    -- ??? ???? ?'s ???
    -- ===============================
    
    -- ? ?'s ???? naked lower ?'s???
    local skipLower = nakedState and nakedState.lowerApplied
    
    if not skipLower then
        local hasLowerCutoff = HasAnyCategory(LowerBodyCutoffCategories)
        local hasLowerCover = HasAnyCategory(LowerBodyCoverCategories)
        
        if hasLowerCutoff and not hasLowerCover then
            local bodyHash = GetBodyHash("BODIES_LOWER")
            
            if not bodyHash or bodyHash == 0 then
                bodyHash = GetBodyHashNative(ped, "BODIES_LOWER")
            end
            
            if bodyHash and bodyHash ~= 0 then
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey("bodies_lower"))
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyHash, true, true, true)
                -- ? FIX: ??? ???? ?? ?'s ??? (? 300?? ?? 2?)
                local t = 0
                while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t < 100 do Wait(20) t = t + 1 end
                needsUpdate = true
            else
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey("bodies_lower"))
                needsUpdate = true
            end
        end
    end
    
    -- ===============================
    -- ??? ??????? ?'s ???
    -- ===============================
    
    -- ? ?'s ???? naked upper ?'s???
    local skipUpper = nakedState and nakedState.upperApplied
    
    if not skipUpper then
        local hasUpperCutoff = HasAnyCategory(UpperBodyCutoffCategories)
        local hasUpperCover = HasAnyCategory(UpperBodyCoverCategories)
        -- ? ?'s ???/????? ??? ?'s: ?? ?'s BODIES_UPPER - ?'s ?'s ?? ?'s ???, ??? ?'s?? ?'s ?'s???
        local vestOrCorsetOnly = (IsCategoryEquipped('vests') or IsCategoryEquipped('corsets')) and not IsCategoryEquipped('shirts_full') and not IsCategoryEquipped('dresses')
        local needUpperBody = (hasUpperCutoff and not hasUpperCover) and not vestOrCorsetOnly
        
        if needUpperBody then
            local bodyHash = GetBodyHash("BODIES_UPPER")
            
            if not bodyHash or bodyHash == 0 then
                bodyHash = GetBodyHashNative(ped, "BODIES_UPPER")
            end
            
            if bodyHash and bodyHash ~= 0 then
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey("bodies_upper"))
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyHash, true, true, true)
                -- ? FIX: ??? ???? ?? ???????? (? 300?? ?? 2?)
                local t = 0
                while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t < 100 do Wait(20) t = t + 1 end
                needsUpdate = true
            else
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey("bodies_upper"))
                needsUpdate = true
            end
            -- ? FIX: ???/????? ??? ?'s - ?'s bodies_upper ????????????? vest/corset ?'s
            if vestOrCorsetOnly then
                local item = (ClothesCache and ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0) and ClothesCache['vests']
                    or (ClothesCache and ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0) and ClothesCache['corsets']
                if item then
                    NativeSetPedComponentEnabledClothes(ped, item.hash, false, true, true)
                    needsUpdate = true
                end
            end
        elseif vestOrCorsetOnly then
            -- ? ?'s ???/?????: ???? ?? ?'s, ??? ?'s ?'s??? ??? ?'s ?'s (??? BODIES_UPPER)
            local item = (ClothesCache and ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0) and ClothesCache['vests']
                or (ClothesCache and ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0) and ClothesCache['corsets']
            if item then
                NativeSetPedComponentEnabledClothes(ped, item.hash, false, true, true)
                needsUpdate = true
            end
        end
    end
    
    -- ????????? ???????? ???? ?'s ?????
    if needsUpdate or forceUpdate then
        Wait(50)
        NativeUpdatePedVariation(ped, true)
        -- ? ?'s UpdatePedVariation ??/????? ?'s '??????' ??? ???? - ????????????? ?'s (??????????? ?'s ??????????)
        local vestOnly = (IsCategoryEquipped('vests') or IsCategoryEquipped('corsets')) and not IsCategoryEquipped('shirts_full') and not IsCategoryEquipped('dresses')
        if vestOnly then
            local item = (ClothesCache and ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0) and ClothesCache['vests']
                or (ClothesCache and ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0) and ClothesCache['corsets']
            if item then
                Wait(30)
                NativeSetPedComponentEnabledClothes(ped, item.hash, false, true, true)
                if NativeUpdatePedVariationClothes then NativeUpdatePedVariationClothes(ped) end
            end
        end
    end
    
    return needsUpdate
end

-- ??? ???????
exports('EnsureBodyIntegrity', EnsureBodyIntegrity)
exports('ReapplyVestIfEquipped', ReapplyVestIfEquipped)
exports('HasVestEquipped', function()
    -- ? vests ? corsets - ???? ???? (0x485EE834), ??? ?'s ???, chest_size ?'s??
    if ClothesCache and ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0 then return true end
    if ClothesCache and ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0 then return true end
    return false
end)
-- ==========================================
-- ????????? ??????????? ?'s
-- ==========================================

local ClothingModifications = {
    sleeves = false, -- false = ???????, true = ?'s???
    collar = false,  -- false = ?'s???, true = ?'s???
}

-- ==========================================
-- ????????? ??????????? ?'s
-- ==========================================

local ClothingModifications = {
    sleeves = false, -- false = ???????, true = ?'s???
    collar = false,  -- false = ?'s???, true = ?'s???
}

-- ??? ????????? ?'s ??????? (??????? ?'s)
local ShirtVariations = {
    -- ??? ???????
    male = {
        -- [??????? ?'s] = {sleeves = ?'s ?'s, collar = ?'s ?'s???}
        [0x339C7959] = {sleeves = 0x4B3D4EF5, collar = 0x1FCD2EAB}, -- Everyday Shirt
        [0x21A1A7A] = {sleeves = 0x5F622EED, collar = 0x12D463B0},  -- Work Shirt
        [0x5C43B130] = {sleeves = 0x7A96766B, collar = 0x2B3C5E3D}, -- French Dress Shirt
        -- ??? ?'s ?? ??? ?'s ?'s?????
    },
    -- ??? ???????
    female = {
        [0x4869A5] = {sleeves = 0x6AC3C4F5, collar = 0x8B5D2CAD},   -- Shirtwaist
        [0x3D88E07C] = {sleeves = 0x5E4D3B2F, collar = 0x7C2A1DEF}, -- Casual Shirtwaist
        -- ??? ?'s ???
    }
}
function GetTintCategoryHash(category)
    return CategoryTintHash[category] or CategoryComponentHash[category] or GetHashKey(category)
end
-- ==========================================
-- ??? ?????????
-- ==========================================

local CategoryIcons = {
    -- ???
    ['hats'] = 'hats',
    ['eyewear'] = 'eyewear',
    ['masks'] = 'masks',
    ['neckwear'] = 'neckwear',
    ['neckties'] = 'neckties',
    
    -- ???
    ['cloaks'] = 'cloaks',
    ['vests'] = 'vests',
    ['shirts_full'] = 'shirts_full',
    ['holsters_knife'] = 'holsters_knife',
    ['loadouts'] = 'loadouts',
    ['suspenders'] = 'suspenders',
    ['gunbelts'] = 'gunbelts',
    ['belts'] = 'belts',
    ['holsters_left'] = 'holsters_left',
    ['holsters_right'] = 'holsters_right',
    ['coats'] = 'coats',
    ['coats_closed'] = 'coats_closed',
    ['ponchos'] = 'ponchos',
    ['dresses'] = 'dresses',
    
    -- ??? (?????)
    ['pants'] = 'pants',
    ['chaps'] = 'chaps',
    ['skirts'] = 'skirts',
    
    -- ???
    ['boots'] = 'boots',
    ['spats'] = 'spats',
    ['boot_accessories'] = 'boot_accessories',
    
    -- ??????????
    ['jewelry_rings_right'] = 'jewelry_rings_right',
    ['jewelry_rings_left'] = 'jewelry_rings_left',
    ['jewelry_bracelets'] = 'jewelry_bracelets',
    ['gauntlets'] = 'gauntlets',
    ['gloves'] = 'gloves',
    
    -- ??? ??????????????
    ['talisman_wrist'] = 'talisman_wrist',
    ['talisman_holster'] = 'talisman_holster',
    ['belt_buckles'] = 'belt_buckles',
    ['holsters_crossdraw'] = 'holsters_crossdraw',
    ['aprons'] = 'aprons',
    ['bows'] = 'bows',
    ['hair_accessories'] = 'hair_accessories',
    
    -- ??? ?'s ?'s???
    ['head'] = 'head',
    ['torso'] = 'torso',
    ['legs'] = 'legs',
    ['foot'] = 'foot',
    ['hands'] = 'hands',
    ['accessories'] = 'accessories',
}

function GetCategoryIcon(category)
    return CategoryIcons[category] or category
end

-- ==========================================
-- ????????????? ?'s ???
-- ==========================================

local ConflictingCategories = {
    ['coats'] = 'coats_closed',
    ['coats_closed'] = 'coats',
    ['cloaks'] = 'ponchos',
    ['ponchos'] = 'cloaks',
}

-- Anti-clipping fix for outerwear from clothingstore:
-- 1) ???????????? ?'s ?????? ? ?'s ?'s ?'s?? (?? ?'s/?'s ??? ?'s ?'s?)
-- 2) Finalize + UpdatePedVariation
local function ApplyCoatAntiClipFix(ped, equippedCategory)
    if not ped or not DoesEntityExist(ped) then return end
    if equippedCategory ~= 'coats' and equippedCategory ~= 'coats_closed' then return end

    local shirtVar = joaat('BASE')
    if ClothesCache and ClothesCache['shirts_full'] and ClothesCache['shirts_full'].hash and ClothesCache['shirts_full'].hash ~= 0 then
        if ClothingModState and ClothingModState.sleeves_rolled_open then
            shirtVar = joaat(ClothingVariations and ClothingVariations.shirts and ClothingVariations.shirts.rolled_open or 'open_collar_rolled_sleeve')
        elseif ClothingModState and ClothingModState.sleeves_rolled then
            shirtVar = joaat(ClothingVariations and ClothingVariations.shirts and ClothingVariations.shirts.rolled_closed or 'Closed_Collar_Rolled_Sleeve')
        end
        Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, ClothesCache['shirts_full'].hash, shirtVar, 0, true, 1)
    end

    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end
exports('ApplyCoatAntiClipFix', ApplyCoatAntiClipFix)

local function IsClosedCoatVisualOverrideActive()
    return ClothesCache
        and ClothesCache['coats_closed']
        and type(ClothesCache['coats_closed']) == 'table'
        and ClothesCache['coats_closed'].hash
        and ClothesCache['coats_closed'].hash ~= 0
end

local function IsHiddenUnderClosedCoat(category)
    -- ??? ?'s ??? - ??? ?'s ??? ?'s ??? ?'s?
    return false
end
-- ==========================================
-- ??? ?'s ??
-- ==========================================

-- ? NativeFixMeshIssues (hate_framework): ???? ?'s/?? ?? ?????????? ?'s???
local function NativeFixMeshIssues(ped, categoryHash)
    if ped and DoesEntityExist(ped) and categoryHash then
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, categoryHash)
    end
end

function NativeSetPedComponentEnabledClothes(ped, hash, immediately, isMp01, isPlayer)
    local catHash = Citizen.InvokeNative(0x5FF9A878C3D115B8, hash, not IsPedMale(ped), true) -- NativeGetPedComponentCategory
    NativeFixMeshIssues(ped, catHash)
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
    -- ? ??????????: ?????? immediately=true, isMp=true, isMultiplayer=true
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
    NativeFixMeshIssues(ped, catHash)

    -- ? FIX: ???? ??? MetaPed ?'s ??????????? (????????? ??? ?'s ????)
    -- 0xA0BC8FAED8CFEB3C = IsPedReadyToRender - ???? ??? ??? MetaPed ?'s ?'s???
    -- ???: 50 * 10?? = 500??. ?????: 100 * 20?? = 2?
    local timeout = 0
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and timeout < 100 do
        Wait(20)
        timeout = timeout + 1
    end

    -- Wait for confirmation for 2? - Request+Apply
    if timeout >= 100 then
        print('[RSG-Clothing] Component streaming timeout (2s), retrying hash: ' .. tostring(hash))
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true)
        -- How to count (for 2?)
        local timeout2 = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and timeout2 < 100 do
            Wait(20)
            timeout2 = timeout2 + 1
        end
    end
    -- ? ??? ? hate_framework: UpdatePedVariation changes the appearance of the character (??? ReapplyBodyMorph - additional adjustments for body)
    if NativeUpdatePedVariationClothes then NativeUpdatePedVariationClothes(ped) end
end

-- ? This function is used: ??? ReapplyBodyMorph (??? ? hate_framework) - ??? equip ? ?? ? ? ?? ? ? ?
function NativeUpdatePedVariationClothes(ped)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    -- This "evolution" continues through the use of overlays (in the same way as battles).
    -- This function updates the ped variation: NativeUpdatePedVariation.
    if ped == PlayerPedId() then
        SetTimeout(120, function()
            TriggerEvent('shiw-tattoos:client:afterPedVariation')
            TriggerEvent('rsg-appearance:client:afterPedVariation')
        end)
    end
end

-- skipBodyMorph = true - ?? thanks ReapplyBodyMorph (?? current workaround ?? access ?? desired outcome)
function NativeUpdatePedVariation(ped, skipBodyMorph)
    -- ? ??????????: function 0x704C908E9C405136 (_FINAL_PED_META_CHANGE_APPLY)
    -- This script creates a MetaPed object for better customization options!
    -- ? type: string 0xCC8CA3E88256E58F return boolean (not integer)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    if not skipBodyMorph and ReapplyBodyMorph then ReapplyBodyMorph(ped) end
    -- ? Question: What will happen if we try to change something that is already there; how can we make a new - discover history of the one
    if ped == PlayerPedId() and IsPedOnMount(ped) then
        local reinsHash = joaat('WEAPON_REINS')
        if reinsHash and reinsHash ~= 0 then
            GiveWeaponToPed(ped, reinsHash, 0, false, true)
            SetCurrentPedWeapon(ped, reinsHash, true)
        end
    end
    -- ? : Create a new UpdatePedVariation function, shiw-tattoos allow to apply and add
    -- ? Function: UpdatePedVariation for overlays (shadows, blush, lipsticks, eyeliners) - ?????????????
    if ped == PlayerPedId() then
        SetTimeout(120, function()
            TriggerEvent('shiw-tattoos:client:afterPedVariation')
            TriggerEvent('rsg-appearance:client:afterPedVariation')
        end)
    end
end

-- ==========================================
-- Enhanced new module v3.0
-- ==========================================

function SetTextureOutfitTints(ped, categoryHash, paletteHash, tint0, tint1, tint2)
    Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, ped, categoryHash, paletteHash, tint0, tint1, tint2)
end

local function IsPedStyleItem(itemData)
    if type(itemData) ~= 'table' then return false end
    if itemData.kaf == 'Ped' or itemData._kaf == 'Ped' then return true end
    if itemData.draw and itemData.draw ~= '' and itemData.draw ~= '_' then return true end
    if itemData.albedo and itemData.albedo ~= '' and itemData.albedo ~= '_' then return true end
    if itemData.normal and itemData.normal ~= '' and itemData.normal ~= '_' then return true end
    if itemData.material and itemData.material ~= 0 and itemData.material ~= '' and itemData.material ~= '0' then return true end
    return false
end

local function IsPedCoatItem(category, itemData)
    return (category == 'coats' or category == 'coats_closed') and IsPedStyleItem(itemData)
end

function ApplyClothingColor(ped, category, palette, tints)
    if not category then return end
    
    -- Best practice for working
    local categoryHashes = {
    ['hats'] = 0x9925C067,
    ['shirts_full'] = 0x2026C46D,  -- This is shirts?!  
    ['shirts'] = 0x2026C46D,
    ['pants'] = 0x1D4C528A,        -- This is pants?!  
    ['boots'] = 0x777EC6EF,
    ['vests'] = 0x485EE834,
    ['coats'] = 0xE06D30CE,        -- This is coats?!  
    ['coats_closed'] = 0x662AC34,  -- This is coats?!  
    ['gloves'] = 0xEABE0032,
    ['neckwear'] = 0x7A96FACA,     -- This is neckwear?!  
    ['neckties'] = 0x7A96FACA,
    ['masks'] = 0x7505EF42,
    ['eyewear'] = 0x5F1BE9EC,      -- This is eyewear?!  
    ['gunbelts'] = 0xF1542D11,     -- This is gunbelts?!  
    ['satchels'] = 0x94504D26,
    ['suspenders'] = 0x877A2CF7,
    ['chaps'] = 0x3107499B,
    ['spurs'] = 0x18729F39,
    ['cloaks'] = 0x3C1A74CD,
    ['ponchos'] = 0xAF14310B,
    ['skirts'] = 0xA0E3AB7F,
    ['belts'] = 0x9B2C8B89,
    ['belt_buckles'] = 0xDA0E2C55,
    ['dresses'] = 0x0662AC34,
    ['corsets'] = 0x485EE834,
    ['loadouts'] = 0x83887E88,
    ['gauntlets'] = 0x91CE9B20,
    ['holsters_left'] = 0x7A6BBD0B,
    ['holsters_right'] = 0x0B3966C9,
    ['accessories'] = 0x79D7DF96,
    ['badges'] = 0x79D7DF96,
    }
    
    local categoryHash = categoryHashes[category] or GetHashKey(category)
    
    -- This is related to clothing
    local isDefaultPalette = (not palette or palette == 'tint_generic_clean' or palette == 'metaped_tint_generic_clean')
    local hasNonZeroTints = tints and (tints[1] > 0 or tints[2] > 0 or tints[3] > 0)
    -- This is necessary for drawing "shaders" based on the tint:
    -- This Classic-shaders need to hash, convert tint to input shaders (coordinate, alpha).
    if isDefaultPalette and not hasNonZeroTints then
        return
    end
    
    -- This is palette of clothes, which affect clothes
    if not palette then
        palette = 'tint_generic_clean'
    end
    
    local paletteHash = GetHashKey(palette)
    
    -- This is palette of metaped_, clothes
    if not string.find(palette, 'metaped_') then
        paletteHash = GetHashKey('metaped_' .. palette)
    end
    
    local tint0 = tints and tints[1] or 0
    local tint1 = tints and tints[2] or 0
    local tint2 = tints and tints[3] or 0
    
    print('[RSG-Clothing] ApplyColor: cat=' .. category .. ' catHash=' .. tostring(categoryHash) .. ' palette=' .. palette)
    
    SetTextureOutfitTints(ped, categoryHash, paletteHash, tint0, tint1, tint2)
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    -- This is shirts_full/vests/corsets - needed UpdatePedVariation (0,1,1,1,false) for shirts/kaf_bulletproof.
    -- Needed UpdatePedVariation give special effects to players in games (databases).
    if category == 'shirts_full' or category == 'vests' or category == 'corsets' then
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)
    else
        NativeUpdatePedVariation(ped, false)
    end
    
    print('[RSG-Clothing] Applied color: tints=' .. tint0 .. ',' .. tint1 .. ',' .. tint2)
end


-- ==========================================
-- This is clothing quality
-- ==========================================

local starterRequested = false
local isNewCharacter = false

RegisterNetEvent('rsg-clothing:client:applyStarterClothes', function(clothes)
    local ped = PlayerPedId()
    
    for _, item in ipairs(clothes) do
        if item.hash and item.hash ~= 0 then
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, item.hash)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, item.hash, true, true, true)
            
            ClothesCache[item.category] = {
                hash = item.hash,
                model = item.model or 1,
                texture = item.texture or 1
            }
        end
        Wait(100)
    end
    
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end)

RegisterNetEvent('rsg-appearance:client:finishedCreation', function()
    isNewCharacter = true
end)

RegisterNetEvent('rsg-spawn:client:spawned', function()
    if not UseClothingInventory then return end
    Wait(2000)
    
    if isNewCharacter then
        isNewCharacter = false
        if not starterRequested then
            starterRequested = true
            TriggerServerEvent('rsg-appearance:server:GiveStarterClothing', ClothesCache or {}, IsPedMale(PlayerPedId()))
        end
        return
    end
    
    -- This is necessary LoadClothingFromInventory for clothing quality?!  
    -- ApplySkin for clothes: SetPlayerModel as skin and ApplyClothes as delayed LoadClothingFromInventory.  
    -- This is need to enter this MetaPed and apply clothes into Meta.
    -- This is necessary: how to add key into database - which auto-loads.
    RSGCore.Functions.TriggerCallback('rsg-clothing:server:hasClothing', function(hasClothing)
        if not hasClothing and not starterRequested then
            starterRequested = true
            TriggerServerEvent('rsg-appearance:server:GiveStarterClothing', ClothesCache or {}, IsPedMale(PlayerPedId()))
        else
            print('[RSG-Clothing] spawned: skipping LoadClothingFromInventory (handled by ApplySkin)')
        end
    end)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(3000)
    starterRequested = false
    isNewCharacter = false
    -- This is necessary LoadClothingFromInventory!  
    -- ApplySkin (RSGCore:Server:PlayerLoaded ? 3s delay) ??? crashed:
    --   SetPlayerModel → skin → ApplyClothes → delayed LoadClothingFromInventory
    -- successfully returns successful MetaPed: behavior initialized in desktop mode
    -- ?? SetPlayerModel, ??? when it calls ApplyClothes ? etc. the player will be updated.
    print('[RSG-Clothing] OnPlayerLoaded: skipping LoadClothingFromInventory (handled by ApplySkin)')
end)

RegisterDebugCommand('requeststarter', function()
    starterRequested = false
    TriggerServerEvent('rsg-appearance:server:GiveStarterClothing', ClothesCache or {}, IsPedMale(PlayerPedId()))
end, false)

-- ==========================================
-- Additional notes ?? problems
-- ==========================================

function LoadClothingFromInventory(callback)
    RSGCore.Functions.TriggerCallback('rsg-clothing:server:getEquippedClothing', function(equippedItems)
        local ped = PlayerPedId()
        
        -- ? FIX: detected user interface (??? disabled) ??? tooltip, ???? on hover this part
        if not equippedItems or not equippedItems['hats'] then
            Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x9925C067)
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            if ClothesCache then ClothesCache['hats'] = nil end
        end
        
        if not equippedItems or not next(equippedItems) then
            if callback then callback(false) end
            return
        end
        
        local count = 0
        local isMale = IsPedMale(ped)
        local genderKey = isMale and 'male' or 'female'
        
        -- problems should ??? and maximum time required is ???
        ClothesCache = {}
        for category, data in pairs(equippedItems) do
            local hashToUse = nil
            
            -- ? Action 1: ?? implementation hash issues both now
            if data.hash and data.hash ~= 0 then
                hashToUse = data.hash
                print('[RSG-Clothing] LoadClothingFromInventory: ' .. category .. ' using direct hash=' .. tostring(hashToUse))
            
            -- ? Action 2: showcases hash ?? clothing.lua in model/texture
            elseif data.model and data.model > 0 then
                local model = data.model
                local texture = data.texture or 1
                
                if clothing[genderKey] and clothing[genderKey][category] then
                    if clothing[genderKey][category][model] then
                        if clothing[genderKey][category][model][texture] then
                            hashToUse = clothing[genderKey][category][model][texture].hash
                            print('[RSG-Clothing] LoadClothingFromInventory: ' .. category .. ' got hash from clothing[' .. model .. '][' .. texture .. ']=' .. tostring(hashToUse))
                        elseif clothing[genderKey][category][model][1] then
                            hashToUse = clothing[genderKey][category][model][1].hash
                            print('[RSG-Clothing] LoadClothingFromInventory: ' .. category .. ' got hash from clothing[' .. model .. '][1]=' .. tostring(hashToUse))
                        end
                    end
                end
            end
            
            if hashToUse and hashToUse ~= 0 then
                ClothesCache[category] = {
                    hash = hashToUse,
                    model = data.model or 0,
                    texture = data.texture or 0,
                    palette = data.palette or 'tint_generic_clean',
                    tints = data.tints or {0, 0, 0},
                    kaf = data.kaf or data._kaf or "Classic",
                    _kaf = data._kaf or data.kaf or "Classic",
                    draw = data.draw or "",
                    albedo = data.albedo or "",
                    normal = data.normal or "",
                    material = data.material or 0,
                }
            else
                print('[RSG-Clothing] LoadClothingFromInventory: WARNING - no hash for ' .. category)
            end
        end
        
        -- ?? simply replaces how profile manages characters
        EnsureBodyIntegrity(ped, true)
        Wait(100)
        
        -- ? ???: returns card ? handling properly and manager please identify Finalize+Update
        -- ? ? ? when triggering PED-incident: Ped-loading passes draw/albedo/normal/material
        local lowerOrder = {'pants', 'skirts', 'dresses'}
        local upperOrder = {'shirts_full', 'vests', 'coats', 'coats_closed'}
        local lateOrder = {'boots', 'boot_accessories', 'spurs', 'chaps', 'spats'}
        local applied = {}
        local phaseCount = 0

        -- ? FIX naked_body fix /pee /poo: draws naked overlay ? apply a feature (??? and equipClothing)
        local hasLowerToApply = false
        for _, cat in ipairs(lowerOrder) do
            if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                hasLowerToApply = true
                break
            end
        end
        if hasLowerToApply and RemoveNakedLowerBody then
            RemoveNakedLowerBody(ped, true)
            Wait(50)
        end

        -- ? remaining after switch body type (Classic ??? Ped)
        local function ApplyItemOriginal(cat, itemData)
            if itemData.kaf == "Ped" and itemData.draw and itemData.draw ~= "" then
                if itemData.draw ~= "" and itemData.draw ~= "_" then
                    local drawHash = GetHashKey(itemData.draw)
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, drawHash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, drawHash, true, true, true)
                end
                if itemData.albedo and itemData.albedo ~= "" then
                    local albHash = GetHashKey(itemData.albedo)
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, albHash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, albHash, true, true, true)
                end
                if itemData.normal and itemData.normal ~= "" then
                    local normHash = GetHashKey(itemData.normal)
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, normHash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, normHash, true, true, true)
                end
                if itemData.material and itemData.material ~= 0 then
                    local matHash = itemData.material
                    if type(matHash) == "string" then matHash = GetHashKey(matHash) end
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, matHash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, matHash, true, true, true)
                end
            else
                NativeSetPedComponentEnabledClothes(ped, itemData.hash, false, true, true)
            end
        end
        
        -- Note 1: check names (680, 850, 940)
        phaseCount = 0
        for _, category in ipairs(lowerOrder) do
            if ClothesCache[category] and ClothesCache[category].hash and ClothesCache[category].hash ~= 0 then
                ApplyItemOriginal(category, ClothesCache[category])
                applied[category] = true
                count = count + 1
                phaseCount = phaseCount + 1
            end
        end
        -- ? ??? update variation - issues should peek status, ? attachments retrieve bodymorph
        if phaseCount > 0 then
            Wait(200)
            print('[RSG-Clothing] Phase 1 (lower body): ' .. phaseCount .. ' items applied')
        end
        
        -- Note 2a: scenes (??? presents side)
        if ClothesCache['shirts_full'] and ClothesCache['shirts_full'].hash and ClothesCache['shirts_full'].hash ~= 0 then
            ApplyItemOriginal('shirts_full', ClothesCache['shirts_full'])
            applied['shirts_full'] = true
            count = count + 1
            Wait(150)
            print('[RSG-Clothing] Phase 2a (shirts): applied')
        end

        -- Note 2b: skins/items (??? name, if inside 0x485EE834)
        local cat = (ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0) and 'vests'
            or (ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0) and 'corsets'
        if cat then
            ApplyItemOriginal(cat, ClothesCache[cat])
            applied[cat] = true
            count = count + 1
            Wait(150)
            print('[RSG-Clothing] Phase 2b (' .. cat .. '): applied')
        end

        -- Note 2c: fades (??? applied)
        phaseCount = 0
        for _, cat in ipairs({'coats', 'coats_closed'}) do
            if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                ApplyItemOriginal(cat, ClothesCache[cat])
                applied[cat] = true
                count = count + 1
                phaseCount = phaseCount + 1
            end
        end
        if phaseCount > 0 then
            Wait(150)
            if applied['coats_closed'] then
                ApplyCoatAntiClipFix(ped, 'coats_closed')
            elseif applied['coats'] then
                ApplyCoatAntiClipFix(ped, 'coats')
            end
            print('[RSG-Clothing] Phase 2c (coats): ' .. phaseCount .. ' items applied')
        end
        
        -- Note 3: left unfinished (typical, use, typical ? .?.)
        phaseCount = 0
        for category, data in pairs(ClothesCache) do
            if not applied[category] and data.hash and data.hash ~= 0 then
                local isLate = false
                for _, lc in ipairs(lateOrder) do
                    if category == lc then isLate = true break end
                end
                if not isLate then
                    ApplyItemOriginal(category, data)
                    applied[category] = true
                    count = count + 1
                    phaseCount = phaseCount + 1
                end
            end
        end
        if phaseCount > 0 then
            Wait(200)
            print('[RSG-Clothing] Phase 3 (accessories): ' .. phaseCount .. ' items applied')
        end
        
        -- Note 4: item ? notifications to ?? ? particular settings (successful case)
        phaseCount = 0
        for _, category in ipairs(lateOrder) do
            if ClothesCache[category] and ClothesCache[category].hash and ClothesCache[category].hash ~= 0 and not applied[category] then
                ApplyItemOriginal(category, ClothesCache[category])
                applied[category] = true
                count = count + 1
                phaseCount = phaseCount + 1
            end
        end
        if phaseCount > 0 then
            Wait(200)
            print('[RSG-Clothing] Phase 4 (boots): ' .. phaseCount .. ' items applied')
        end
        
        -- Important note!
        for category, data in pairs(ClothesCache) do
            if data.palette and data.tints then
                local isPedCoat = IsPedCoatItem(category, data)
                if isPedCoat or
                   data.palette ~= 'tint_generic_clean' or 
                   (data.tints[1] and data.tints[1] > 0) or 
                   (data.tints[2] and data.tints[2] > 0) or 
                   (data.tints[3] and data.tints[3] > 0) then
                    ApplyClothingColor(ped, category, data.palette, data.tints)
                    Wait(50)
                end
            end
        end
        
        -- Important information
        Wait(100)
        EnsureBodyIntegrity(ped, false)
        
        -- ? What to do with UpdatePedVariation. skipBodyMorph=true - disable body scaling for players in different styles
        NativeUpdatePedVariation(ped, true)

        local hasLower = applied['pants'] or applied['skirts'] or applied['dresses']
        -- Reapply accessories that layer over lower-body clothing without
        -- selecting or removing a BODIES_LOWER component.
        if hasLower then
            local reapplyOverPants = {'boots', 'boot_accessories', 'spurs', 'chaps', 'spats', 'gunbelts', 'belts', 'satchels'}
            for _, cat in ipairs(reapplyOverPants) do
                if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, ClothesCache[cat].hash)
                    NativeSetPedComponentEnabledClothes(ped, ClothesCache[cat].hash, false, true, true)
                end
            end
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            Wait(100)
        end
        -- ? Updated naked/cloth appearance in rsg-appearance:client:ApplyClothesComplete to check if it confirms
        
        -- ? FIX: What happens on required reload - applying invisible parts on model.
        -- Action confirmation should be checked on server, adjusting body type and state (stack).
        if ClothesCache['hats'] and ClothesCache['hats'].hash and ClothesCache['hats'].hash ~= 0 then
            Wait(250)
            ped = PlayerPedId()
            if DoesEntityExist(ped) then
                Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x9925C067)
                Wait(50)
                NativeSetPedComponentEnabledClothes(ped, ClothesCache['hats'].hash, true, true, true)
                Wait(150)
                NativeUpdatePedVariation(ped, true)
                if ApplyClothingColor and ClothesCache['hats'].palette and ClothesCache['hats'].tints then
                    ApplyClothingColor(ped, 'hats', ClothesCache['hats'].palette, ClothesCache['hats'].tints)
                end
            end
        end
        
        -- ? Run method with parameters to affect players
        TriggerEvent('rsg-clothing:client:clothingLoaded', ClothesCache)
        -- ? Already defined variables (naked/clothes): how to handle, how players ApplyClothes
        TriggerEvent('rsg-appearance:client:ApplyClothesComplete', ped)
        
        if callback then callback(true, count) end
    end)
end

exports('LoadClothingFromInventory', LoadClothingFromInventory)

-- ==========================================
-- Confirmed appearance (naked/clothed)
-- ==========================================

function GetCurrentShirtHash()
    local ped = PlayerPedId()
    if not ClothesCache['shirts_full'] then return nil end
    return ClothesCache['shirts_full'].hash
end

function ToggleSleeves()
    local ped = PlayerPedId()
    local isMale = IsPedMale(ped)
    local gender = isMale and "male" or "female"
    
    -- Reviewed descriptions for characters
    if not ClothesCache['shirts_full'] or not ClothesCache['shirts_full'].model or ClothesCache['shirts_full'].model == 0 then
        TriggerEvent('ox_lib:notify', {
            title = 'Title',
            description = 'Detailed information about character position and background',
            type = 'error'
        })
        return
    end
    
    local currentModel = ClothesCache['shirts_full'].model
    local currentTexture = ClothesCache['shirts_full'].texture or 1
    
    -- Other confirmations for optional descriptions
    local clothingData = clothing[gender]['shirts_full']
    if not clothingData or not clothingData[currentModel] then
        TriggerEvent('ox_lib:notify', {
            title = 'unknown',
            description = 'the author of the interesting changes',
            type = 'error'
        })
        return
    end
    
    -- Author Info: Name: Your Name - Nickname, Version - 1.0
    local targetModel = currentModel
    if ClothingModifications.sleeves then
        -- This is the first line
        if currentModel % 2 == 1 then
            targetModel = currentModel - 1
        end
        ClothingModifications.sleeves = false
    else
        -- And the second line
        if currentModel % 2 == 0 and clothingData[currentModel + 1] then
            targetModel = currentModel + 1
        else
            TriggerEvent('ox_lib:notify', {
                title = 'Title',
                description = 'The conditions for the discount period are regular not very complex budgets',
                type = 'error'
            })
            return
        end
        ClothingModifications.sleeves = true
    end
    
    -- The store description
    if clothingData[targetModel] and clothingData[targetModel][currentTexture] then
        local newHash = clothingData[targetModel][currentTexture].hash
        
        -- Packages and how things work
        local savedPalette = ClothesCache['shirts_full'].palette
        local savedTints = ClothesCache['shirts_full'].tints
        
        -- Simple details
        PlayClothingAnimation('sleeves')
        
        Wait(1000)
        
        -- Four items on the store
        NativeSetPedComponentEnabledClothes(ped, newHash, false, true, true)
        NativeUpdatePedVariation(ped, true)
        
        -- Would you like to (type the key?!),
        ClothesCache['shirts_full'].model = targetModel
        ClothesCache['shirts_full'].hash = newHash
        ClothesCache['shirts_full'].palette = savedPalette
        ClothesCache['shirts_full'].tints = savedTints
        
        -- Would you want a walkthrough?!
        if savedPalette and savedTints then
            Wait(100)
            ApplyClothingColor(ped, 'shirts_full', savedPalette, savedTints)
        end
        TriggerEvent('rsg-appearance:client:clothingVariationChanged')
        SetTimeout(650, function()
            TriggerEvent('rsg-appearance:client:clothingVariationSettled')
        end)
        
        TriggerEvent('ox_lib:notify', {
            title = 'Title',
            description = ClothingModifications.sleeves and 'Additional clothing' or 'Standard clothing',
            type = 'success'
        })
    end
end

function ToggleCollar()
    local ped = PlayerPedId()
    local isMale = IsPedMale(ped)
    local gender = isMale and "male" or "female"
    
    -- A primary discount period? in the store
    if not ClothesCache['shirts_full'] or not ClothesCache['shirts_full'].model or ClothesCache['shirts_full'].model == 0 then
        TriggerEvent('ox_lib:notify', {
            title = 'Title',
            description = 'All interesting mechanics',
            type = 'error'
        })
        return
    end
    
    local currentModel = ClothesCache['shirts_full'].model
    local currentTexture = ClothesCache['shirts_full'].texture or 1
    
    -- How suitable is this description for store materials?
    local clothingData = clothing[gender]['shirts_full']
    if not clothingData or not clothingData[currentModel] then
        TriggerEvent('ox_lib:notify', {
            title = 'Title',
            description = 'The conditions for the discount period are regular functional packages',
            type = 'error'
        })
        return
    end
    
    -- Important and interesting (please do not misunderstand)
    -- Reminder: ranges 1-10 are for models, 11-20 are for models?
    local targetModel = currentModel
    if ClothingModifications.collar then
        -- New store integration
        if currentModel > 10 and currentModel <= 20 then
            targetModel = currentModel - 10
        end
        ClothingModifications.collar = false
    else
        -- Community styles.
        if currentModel <= 10 and clothingData[currentModel + 10] then
            targetModel = currentModel + 10
        else
            TriggerEvent('ox_lib:notify', {
                title = 'Title',
                description = 'The conditions for the discount period are regular functional packages',
                type = 'error'
            })
            return
        end
        ClothingModifications.collar = true
    end
    
    -- The store description
    if clothingData[targetModel] and clothingData[targetModel][currentTexture] then
        local newHash = clothingData[targetModel][currentTexture].hash
        
        -- Packages and how things work
        local savedPalette = ClothesCache['shirts_full'].palette
        local savedTints = ClothesCache['shirts_full'].tints
        
        -- Simple details
        PlayClothingAnimation('collar')
        
        Wait(800)
        
        -- Four items on the store
        NativeSetPedComponentEnabledClothes(ped, newHash, false, true, true)
        NativeUpdatePedVariation(ped, true)
        
        -- Would you like to (type the key?!),
        ClothesCache['shirts_full'].model = targetModel
        ClothesCache['shirts_full'].hash = newHash
        ClothesCache['shirts_full'].palette = savedPalette
        ClothesCache['shirts_full'].tints = savedTints
        
        -- Would you want a walkthrough?!
        if savedPalette and savedTints then
            Wait(100)
            ApplyClothingColor(ped, 'shirts_full', savedPalette, savedTints)
        end
        
        TriggerEvent('ox_lib:notify', {
            title = 'Title',
            description = ClothingModifications.collar and 'Extra collars' or 'Standard collars',
            type = 'success'
        })
        SetTimeout(80, function()
            pcall(function() exports['shiw-tattoos']:ReapplyTattoo() end)
        end)
    end
end

function PlayClothingAnimation(type)
    local ped = PlayerPedId()
    local dict, anim
    
    if type == 'sleeves' then
        dict = 'script_common@mech@clothing@gloves'
        anim = 'put_on_gloves'
    elseif type == 'collar' then
        dict = 'mech_inventory@clothing@shirt'
        anim = 'collar_check'
    else
        return
    end
    
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end
    
    if HasAnimDictLoaded(dict) then
        -- On mount/vehicle these anims can break rider pose; skip visual anim and keep clothing logic.
        if not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) then
            TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 51, 0, false, false, false)
        end
    end
end


-- ==========================================
 -- A popular project/version v2.0
 -- A NAKED BODY FIX: Actual clothing for naked/horrible models
-- ==========================================

 -- Read the condition regarding naked body (please refer to naked_body.lua)
local NakedLowerApplied = false
local NakedUpperApplied = false

 -- Important models for naked body
local function ResetNakedFlags(category)
    if category == 'pants' or category == 'skirts' or category == 'dresses' then
        NakedLowerApplied = false
        print('[RSG-Clothing] Reset NakedLowerApplied flag')
    end
    if category == 'shirts_full' or category == 'dresses' or category == 'coats' or category == 'coats_closed' or category == 'vests' or category == 'corsets' then
        NakedUpperApplied = false
        print('[RSG-Clothing] Reset NakedUpperApplied flag')
    end
end

RegisterNetEvent('rsg-clothing:client:equipClothing', function(data, options)
    CreateThread(function()
        options = options or {}
        local ped = PlayerPedId()

        -- Would you want to unlock (sv_clothing.lua ToggleClothingItem) or explore variations,
        -- Keep in consideration whether IsPedMale() ? data.isMale validations are present.
        -- (0/1 vs true/false? Lua 5.4), warnings might lead to changes

        print('[RSG-Clothing] equipClothing: cat=' .. tostring(data.category) .. ' hash=' .. tostring(data.hash) .. ' kaf=' .. tostring(data.kaf))

        local kafEarly = data.kaf or data._kaf or "Classic"
        if kafEarly == "BodyComponent" then
            local bh = data.hash
            if type(bh) == "string" then bh = tonumber(bh, 16) end
            if bh and bh ~= 0 then
                Citizen.InvokeNative(0x1902C4CFCC5BE57C, ped, bh)
                Citizen.InvokeNative(0x704C908E9C405136, ped)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
                if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
                ClothesCache[data.category] = {
                    hash = bh, model = data.model or 0, texture = data.texture or 0,
                    palette = data.palette or 'tint_generic_clean', tints = data.tints or {0, 0, 0},
                    kaf = "BodyComponent", _kaf = "BodyComponent",
                }
                TriggerEvent('rsg-clothing:client:clothingLoaded', ClothesCache)
            end
            return
        end

        -- Why do they use these models?
        if data.category == 'shirts_full' then
            ClothingModifications.sleeves = false
            ClothingModifications.collar = false
            if ResetClothingModState then ResetClothingModState('shirts_full') end
        end

        local hash = data.hash
        local isPedClothing = data.kaf == "Ped" and data.draw and data.draw ~= ""

        -- The next models are: shape, bodies_upper, ReapplyItem
        if data.category == 'shirts_full' or data.category == 'vests' or data.category == 'corsets' or 
           data.category == 'coats' or data.category == 'coats_closed' or data.category == 'dresses' then
            -- The request: Checking these models - sample item templates from bodies_upper/ReapplyItem (presuming there are further bases to add)
            local isCoatOnly = (data.category == 'coats' or data.category == 'coats_closed')
            if isCoatOnly then
                if RemoveNakedUpperBody then RemoveNakedUpperBody(ped, true) end
                Wait(50)
                if data.category == 'coats' then
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xE06D30CE, 0)
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x0662AC34, 0)
                else
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x0662AC34, 0)
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xE06D30CE, 0)
                end
                Citizen.InvokeNative(0x704C908E9C405136, ped)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
                Wait(50)
                 -- The unusual items presented to make models fit - refer interesting factors here
                if ClothesCache and ClothesCache['shirts_full'] and ClothesCache['shirts_full'].hash and ClothesCache['shirts_full'].hash ~= 0 then
                    NativeSetPedComponentEnabledClothes(ped, ClothesCache['shirts_full'].hash, false, true, true)
                    local shirtVar = 'BASE'
                    if ClothingModState and ClothingModState.sleeves_rolled_open then
                        shirtVar = (ClothingVariations and ClothingVariations.shirts and ClothingVariations.shirts.rolled_open) or 'open_collar_rolled_sleeve'
                    elseif ClothingModState and ClothingModState.sleeves_rolled then
                        shirtVar = (ClothingVariations and ClothingVariations.shirts and ClothingVariations.shirts.rolled_closed) or 'Closed_Collar_Rolled_Sleeve'
                    end
                    if SetPedComponentVariation then
                        SetPedComponentVariation(ped, ClothesCache['shirts_full'].hash, shirtVar)
                    end
                    Wait(80)
                end
                local vestItem = (ClothesCache and ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0) and ClothesCache['vests']
                    or (ClothesCache and ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0) and ClothesCache['corsets']
                if vestItem then
                    NativeSetPedComponentEnabledClothes(ped, vestItem.hash, false, true, true)
                    Wait(80)
                end
            else
                 -- Upscale, multiple versions, items - design decisions
                if (data.category == 'shirts_full' or data.category == 'coats' or data.category == 'coats_closed' or data.category == 'dresses')
                   and RemoveNakedUpperBody then
                    RemoveNakedUpperBody(ped, true)
                end
                Wait(50)
                if data.category == 'shirts_full' then
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x2026C46D, 0)
                elseif data.category == 'vests' or data.category == 'corsets' then
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x485EE834, 0)
                elseif data.category == 'coats' then
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xE06D30CE, 0)
                elseif data.category == 'coats_closed' or data.category == 'dresses' then
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x0662AC34, 0)
                    if data.category == 'dresses' then
                        Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x2026C46D, 0)
                        Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x485EE834, 0)
                    end
                end
                Citizen.InvokeNative(0x704C908E9C405136, ped)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
                 -- The issue: ReapplyItem('shirts_full') or vests/corsets with gradients of variants
                Wait(100)
            end
        end

        -- The naked overlay (removal) for ensuring further clothing/alterations
        if data.category == 'pants' or data.category == 'skirts' or data.category == 'dresses' then
            if RemoveNakedLowerBody then RemoveNakedLowerBody(ped, true) end
            Wait(50)
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x1D4C528A, 0)
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xA0E3AB7F, 0)
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x0662AC34, 0)
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x3107499B, 0)
            -- Important statement to ensure variations on clothing - ensure department dealing with clothes (models px as reference)
            for _, compHash in ipairs({0x777EC6EF, 0x3107499B, 0x18729F39}) do -- boots, chaps, spurs
                Citizen.InvokeNative(0xD710A5007C2AC539, ped, compHash, 0)
            end
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            Wait(80)
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            Wait(100)
        end

        -- Standard versions define naked body (unusual models, settings welcome?!
        if ResetNakedFlags then ResetNakedFlags(data.category) end

        -- ==========================================
        -- PED dashboards (Draw/Albedo/Normal/Material)
        -- ==========================================
        if isPedClothing then
            -- Data Draw
            if data.draw and data.draw ~= "" and data.draw ~= "_" then
                local drawHash = GetHashKey(data.draw)
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, drawHash)
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, drawHash, true, true, true)
            end
            -- Data Albedo
            if data.albedo and data.albedo ~= "" then
                local albHash = GetHashKey(data.albedo)
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, albHash)
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, albHash, true, true, true)
            end
            -- Data Normal
            if data.normal and data.normal ~= "" then
                local normHash = GetHashKey(data.normal)
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, normHash)
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, normHash, true, true, true)
            end
            -- Data Material
            if data.material and data.material ~= 0 then
                local matHash = data.material
                if type(matHash) == "string" then matHash = GetHashKey(matHash) end
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, matHash)
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, matHash, true, true, true)
            end

            -- Additional details + orientation (this topic expands further highlights)
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
            Wait(100)

            -- Focused models guidelines.
            if data.palette and data.palette ~= "" and data.palette ~= " " then
                local paletteHash = GetHashKey(data.palette)
                if not string.find(data.palette:lower(), 'metaped_') then
                    paletteHash = GetHashKey('metaped_' .. data.palette:lower())
                end
                local tintHash = GetTintCategoryHash(data.category)
                Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, ped, tintHash, paletteHash,
                    data.tints and data.tints[1] or 0,
                    data.tints and data.tints[2] or 0,
                    data.tints and data.tints[3] or 0)
                Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
                Citizen.InvokeNative(0x704C908E9C405136, ped)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            end

            -- Variants data
            ClothesCache[data.category] = {
                hash = hash, model = data.model or 0, texture = data.texture or 0,
                palette = data.palette or 'tint_generic_clean', tints = data.tints or {0, 0, 0},
                kaf = data.kaf, draw = data.draw, albedo = data.albedo,
                normal = data.normal, material = data.material,
            }
            if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
            -- The PED variable: UpdatePedVariation will lead to step returns - functional references
            if (data.category == 'coats' or data.category == 'coats_closed') and ApplyClothingColor then
                Wait(50)
                for _, cat in ipairs({'shirts_full', 'vests', 'corsets'}) do
                    if ClothesCache and ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                        local d = ClothesCache[cat]
                        if d.palette then
                            ApplyClothingColor(ped, cat, d.palette or 'tint_generic_clean', d.tints or {0, 0, 0})
                        end
                    end
                end
            end
            -- The PED item: asking for adjustable details + multi-assets
            if (data.category == 'pants' or data.category == 'skirts' or data.category == 'dresses') and data.draw and data.draw ~= "" then
                SetTimeout(350, function()
                    local p = PlayerPedId()
                    if DoesEntityExist(p) then
                        local drawHash = GetHashKey(data.draw)
                        Citizen.InvokeNative(0x59BD177A1A48600A, p, drawHash)
                        Citizen.InvokeNative(0xD3A7B003ED343FD9, p, drawHash, true, true, true)
                        Citizen.InvokeNative(0x704C908E9C405136, p)
                        if NativeUpdatePedVariation then NativeUpdatePedVariation(p, true) else Citizen.InvokeNative(0xCC8CA3E88256E58F, p, false, true, true, true, false) end
                        pcall(function() exports['rsg-appearance']:ReapplyBootsFromCache(p) end)
                    end
                end)
            end
            print('[RSG-Clothing] PED equipClothing completed')
            TriggerEvent('rsg-clothing:client:clothingLoaded', ClothesCache)
            if CheckAndApplyNakedBodyIfNeeded then
                SetTimeout(150, function()
                    CheckAndApplyNakedBodyIfNeeded(PlayerPedId(), ClothesCache)
                end)
            end
            return
        end

        -- ==========================================
        -- CLASSIC samples (hash)
        -- ==========================================
        if (not hash or hash == 0) and data.model and data.model > 0 then
            hash = GetHashFromModel(data.category, data.model, data.texture or 1, data.isMale)
        end

        if hash and hash ~= 0 then
            -- A sample: Important references about models pointing to alternatives (unusual uniforms from the department itself)
            if data.category == 'hats' then
                if ClearFloatingHatProp then ClearFloatingHatProp(ped, nil) end
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
            end
            -- Critical views (coats vs coats_closed ? ??.?)
            if ConflictingCategories and ConflictingCategories[data.category] then
                local conflictCategory = ConflictingCategories[data.category]
                Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(conflictCategory), 0)
                ClothesCache[conflictCategory] = nil
            end

            -- Club references: vivid contacts show how these modifications apply, automatic references shown?
            local jewelryCompHash = {
                ['jewelry_rings_right'] = 0x7A6BBD0B, ['jewelry_rings_left'] = 0xF16A1D23,
                ['jewelry_bracelets'] = 0x7BC10759,
                ['rings_rh'] = 0x7A6BBD0B, ['rings_lh'] = 0xF16A1D23, ['bracelets'] = 0x7BC10759,
            }
            local compHash = jewelryCompHash[data.category]
            if compHash then
                Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(data.category), 0)
                Citizen.InvokeNative(0xD710A5007C2AC539, ped, compHash, 0)
                Citizen.InvokeNative(0x704C908E9C405136, ped)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
                if NativeUpdatePedVariationClothes then NativeUpdatePedVariationClothes(ped) end
                Wait(150)
            end

            -- Request how navigations still appear (post-processing for bodies_lower forms)
            if data.category == 'pants' or data.category == 'skirts' or data.category == 'dresses' then
                Citizen.InvokeNative(0x59BD177A1A48600A, ped, hash)
                local t = 0
                while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t < 30 do Wait(20) t = t + 1 end
            end
            -- Advanced areas: Request Apply Update (this is ReapplyBodyMorph - returning hate_framework)
            NativeSetPedComponentEnabledClothes(ped, hash, false, true, true)

            -- Awareness
            local palette = data.palette or 'tint_generic_clean'
            local tints = data.tints or {0, 0, 0}
            local isClassic = (data.kaf == "Classic" or data._kaf == "Classic")
            local hasZeroTints = (tints[1] == 0 and tints[2] == 0 and tints[3] == 0)
            local isPedCoatCategory = IsPedCoatItem(data.category, data)
            if isPedCoatCategory or not (isClassic and hasZeroTints) then
                Wait(100)
                ApplyClothingColor(ped, data.category, palette, tints)
            end

            -- (modifications that could be operating exactly from underlying requests)
            ClothesCache[data.category] = {
                hash = hash, model = data.model or 0, texture = data.texture or 0,
                palette = data.palette or 'tint_generic_clean', tints = data.tints or {0, 0, 0},
                kaf = data.kaf or data._kaf or "Classic", _kaf = data._kaf or data.kaf or "Classic", draw = data.draw or "",
                albedo = data.albedo or "", normal = data.normal or "",
                material = data.material or 0,
            }

            -- The body: further options available (which tap references as to locations)
            if data.category == "pants" or data.category == "skirts" or data.category == "dresses" then
                Wait(100)
                NativeSetPedComponentEnabledClothes(ped, hash, false, true, true)
                local reapplyAfterLower = {
                    'boots', 'boot_accessories', 'spurs', 'chaps', 'spats',
                    'gunbelts', 'belts', 'satchels'
                }
                for _, cat in ipairs(reapplyAfterLower) do
                    if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                        NativeSetPedComponentEnabledClothes(ped, ClothesCache[cat].hash, false, true, true)
                    end
                end
            end

            -- A unique + options: presents unique naked lower sections ensuring offered pieces across unclassified (deeper reviews apply)
            if data.category == 'boots' and not IsPedMale(ped) and RemoveNakedLowerBody then
                Wait(80)
                RemoveNakedLowerBody(ped, true)
                if NakedBodyState then NakedBodyState.lowerApplied = false end
            end

            if data.category == 'coats' or data.category == 'coats_closed' then
                ApplyCoatAntiClipFix(ped, data.category)
                _G._CoatJustChanged = GetGameTimer()
                 -- A ApplyCoatAntiClipFix/UpdatePedVariation should close instances while ensuring clarifications/status hints/detailed results
                Wait(50)
                for _, cat in ipairs({'shirts_full', 'vests', 'corsets'}) do
                    if ClothesCache and ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                        local d = ClothesCache[cat]
                        if d.palette and ApplyClothingColor then
                            ApplyClothingColor(ped, cat, d.palette or 'tint_generic_clean', d.tints or {0, 0, 0})
                        end
                    end
                end
            end

            print('[RSG-Clothing] CLASSIC equipClothing completed: hash=' .. tostring(hash))
            TriggerEvent('rsg-clothing:client:clothingLoaded', ClothesCache)
             -- A wish: CheckAndApplyNakedBodyIfNeeded presents naked body forms holding variables
            if CheckAndApplyNakedBodyIfNeeded and data.category ~= 'coats' and data.category ~= 'coats_closed' then
                SetTimeout(150, function()
                    CheckAndApplyNakedBodyIfNeeded(PlayerPedId(), ClothesCache)
                end)
            end
        else
            print('[RSG-Clothing] ERROR: No hash for ' .. tostring(data.category))
        end

        -- Structures across assessments would result in previews:
        -- The best solutions clarify reviews leading to server equipped-references.
        -- A skipResync: ensure the loadcharacter continues leading to evaluations - negative hints bound to apply conflicting ranges
        -- A discovery: suggests closed registrations across series (reviews suggest beneficial implementations)
        if not options.skipResync and EnableToggleInventoryResync and ScheduleClothingResyncFromInventory then
            if data.category ~= 'coats' and data.category ~= 'coats_closed' then
                ScheduleClothingResyncFromInventory('equip:' .. tostring(data.category))
            end
        end

        -- And attendance: ReapplyAppearanceAfterClothing presents requests from members
        -- And announcements: requestModifierReapply showcases equip variations ApplyAllSavedColors as changing their request (naked body)
        -- Why isn't changes leading into equipClothing showing ApplyClothingColor
        -- SetTimeout(500, function()
        --     TriggerEvent('rsg-appearance:client:requestModifierReapply')
        -- end)
    end)
end)

 -- Further updates intended hash on models
function GetHashFromModel(category, model, texture, isMale)
    if isMale == nil then
        isMale = IsPedMale(PlayerPedId())
    end
    
    local gender = isMale and 'male' or 'female'
    
    if clothing[gender] and clothing[gender][category] then
        local categoryData = clothing[gender][category]
        if categoryData[model] then
            local tex = texture or 1
            if categoryData[model][tex] and categoryData[model][tex].hash then
                return categoryData[model][tex].hash
            elseif categoryData[model][1] and categoryData[model][1].hash then
                return categoryData[model][1].hash
            end
        end
    end
    
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
        local idx = ((model - 1) * 10) + (texture or 1)
        if idx < 1 then idx = 1 end
        if idx > #items then idx = model end
        if idx > #items then idx = #items end
        return items[idx]
    end
    
    return 0
end

 -- An inscription "Introductions" phrases their presentation (further details/options could apply - retract naturally here)
 local HAT_HEAD_RADIUS = 4.0   -- A measure typically showing up to 3-4? into learning?
 local HAT_HEAD_RADIUS_DAMAGE = 8.0  -- A common object of stock detailed assessments indicating interactions leading correctly
local HAT_Z_MAX = 5.0
local HAT_Z_MAX_DAMAGE = 10.0
local HAT_Z_MIN = 0.2 -- ?? unknown property in floor; 0.2?+ some value - interaction or something in the respective data
-- ? ?? unknown item (shiw-parasol) - ??? unknown object ???
local PARASOL_MODEL_HASHES = {
    [joaat('p_parasol02x')] = true,
    [joaat('k_p_parasol02x_custom_01')] = true, [joaat('k_p_parasol02x_custom_02')] = true,
    [joaat('k_p_parasol02x_custom_03')] = true, [joaat('k_p_parasol02x_custom_04')] = true,
    [joaat('k_p_parasol02x_custom_05')] = true, [joaat('k_p_parasol02x_custom_06')] = true,
    [joaat('k_p_parasol02x_custom_07')] = true,
}

local HAT_ANIM_DICT = 'mech_loco_m@character@arthur@fidgets@hat@normal@unarmed@normal@left_hand'
local HAT_ANIM_NAME = 'hat_lhand_b'

local function IsInHatInteraction(ped)
    if not ped or not DoesEntityExist(ped) then return false end
    if IsEntityPlayingAnim(ped, HAT_ANIM_DICT, HAT_ANIM_NAME, 3) then
        return true
    end
    if IsPedUsingAnyScenario and IsPedUsingAnyScenario(ped) then
        return true
    end
    return false
end
-- ? parameters get property ? it's interaction or something or something - ?? ? requires parameters here (tk_placeable ? ?.?.)
local function ClearFloatingHatProp(ped, hatModelHash, fromDamage)
    if not ped or not DoesEntityExist(ped) then return end
    if not hatModelHash or hatModelHash == 0 then return end
    if IsInHatInteraction(ped) then return end
    local headPos = GetEntityCoords(ped)
    local headPosHigh = vector3(headPos.x, headPos.y, headPos.z + 0.5)
    local radius = fromDamage and HAT_HEAD_RADIUS_DAMAGE or HAT_HEAD_RADIUS
    local zMax = fromDamage and HAT_Z_MAX_DAMAGE or HAT_Z_MAX
    local pool = GetGamePool and GetGamePool('CObject') or {}

    local weaponEntity = nil
    local _, wepHash = GetCurrentPedWeapon(ped, true, 0, true)
    if wepHash and wepHash ~= 0 and wepHash ~= GetHashKey("WEAPON_UNARMED") and wepHash ~= -1569615261 then
        local ei = GetCurrentPedWeaponEntityIndex and GetCurrentPedWeaponEntityIndex(ped, 0)
        if ei and ei ~= 0 and GetObjectIndexFromEntityIndex then
            weaponEntity = GetObjectIndexFromEntityIndex(ei)
        end
    end

    for _, obj in ipairs(pool) do
        if DoesEntityExist(obj) and obj ~= ped then
            if IsEntityAttachedToEntity(obj, ped) then
                goto next_obj
            end
            if weaponEntity and DoesEntityExist(weaponEntity) and obj == weaponEntity then
                goto next_obj
            end
            if PARASOL_MODEL_HASHES[GetEntityModel(obj)] then
                goto next_obj
            end
            if GetEntityModel(obj) ~= hatModelHash then goto next_obj end
            local objPos = GetEntityCoords(obj)
            local dist = #(headPosHigh - objPos)
            if dist > radius then goto next_obj end
            local zDelta = objPos.z - headPos.z
            if not (zDelta > HAT_Z_MIN and zDelta < zMax) then goto next_obj end
            DeleteEntity(obj)
            return
        end
        ::next_obj::
    end
end

local metaPedComponents = {
    ['hats'] = 0x9925C067,
    ['shirts_full'] = 0x2026C46D,
    ['pants'] = 0x1D4C528A,
    ['boots'] = 0x777EC6EF,
    ['vests'] = 0x485EE834,
    ['corsets'] = 0x485EE834,  -- ??? ?? item ??? vests
    ['coats'] = 0xE06D30CE,
    ['coats_closed'] = 0x662AC34,
    ['gloves'] = 0xEABE0032,
    ['neckwear'] = 0x7A96FACA,
    ['masks'] = 0x7505EF42,
    ['eyewear'] = 0x5F1BE9EC,
    ['gunbelts'] = 0xF1542D11,
    ['satchels'] = 0x94504D26,
    ['suspenders'] = 0x877A2CF7,
    ['chaps'] = 0x3107499B,
    ['spurs'] = 0x18729F39,
    ['cloaks'] = 0x3C1A74CD,
    ['ponchos'] = 0xAF14310B,
    ['skirts'] = 0xA0E3AB7F,
    ['belts'] = 0xA6D134C6,
    ['dresses'] = 0x0662AC34,
    -- unknown and unknown (??? ????)
    ['accessories'] = 0x79D7DF96,
    ['talisman_belt'] = 0x1AECF7DC,
    ['rings_rh'] = 0x7A6BBD0B,
    ['rings_lh'] = 0xF16A1D23,
    ['bracelets'] = 0x7BC10759,
    ['jewelry_rings_right'] = 0x7A6BBD0B,
    ['jewelry_rings_left'] = 0xF16A1D23,
    ['jewelry_bracelets'] = 0x7BC10759,
}

local clothingResyncToken = 0
local activeInventoryResyncPasses = 0
local EnableToggleInventoryResync = false

ScheduleClothingResyncFromInventory = function(reason)
    clothingResyncToken = clothingResyncToken + 1
    local token = clothingResyncToken

    local function runResync(label)
        if token ~= clothingResyncToken then return end
        if LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoadingCharacter then return end
        -- ? ?? ?unknown item ???? plant model ? factory rsg-clothingstore (unknown factory model)
        if LocalPlayer.state.inClothingStore or LocalPlayer.state.isInClothingStore then return end

        activeInventoryResyncPasses = activeInventoryResyncPasses + 1
        LoadClothingFromInventory(function(success)
            activeInventoryResyncPasses = math.max(0, (activeInventoryResyncPasses or 1) - 1)
            if token ~= clothingResyncToken then return end

            -- ??? unknown item "?????? ?? interaction?", unknown properties ?? interactions ??,
            -- ??? ?? ?interaction? "unknown?" ??? unknown? ? item.
            if not success then
                local ped = PlayerPedId()
                if not ped or not DoesEntityExist(ped) then return end

                ClothesCache = {}
                for cat, compHash in pairs(metaPedComponents) do
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(cat), 0)
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, compHash, 0)
                end
                Citizen.InvokeNative(0x704C908E9C405136, ped)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)

                if EnsureBodyIntegrity then EnsureBodyIntegrity(ped, false) end
                if CheckAndApplyNakedBodyIfNeeded then
                    CheckAndApplyNakedBodyIfNeeded(ped, {})
                end
                if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
            end

            if Config and Config.Debug then
                print(('[RSG-Clothing] Inventory resync pass (%s): %s success=%s'):format(
                    tostring(reason or 'unknown'), tostring(label), tostring(success)))
            end
        end)
    end

    -- ??? unknown: ??? and ??? (?? ? unknown categories/unknown unknown).
    SetTimeout(350, function() runResync('fast') end)
    SetTimeout(1200, function() runResync('late') end)
end

RegisterNetEvent('rsg-clothing:client:removeClothing', function(category, options)
    CreateThread(function()
    options = options or {}
    local ped = PlayerPedId()
    print('[RSG-Clothing] Removing category: ' .. category)

    -- ??? unknown categories ?? unknown
    if category == 'shirts_full' then
        ClothingModifications.sleeves = false
        ClothingModifications.collar = false
    end
    if ResetNakedFlags then ResetNakedFlags(category) end

    -- ? ?unknown, ??? ?? category item "Ped" (raw overlay), ???? ??? ??? ???
    local wasPedType = false
    local pedDrawHash = nil
    if ClothesCache[category] and ClothesCache[category].kaf == "Ped" and ClothesCache[category].draw then
        wasPedType = true
        pedDrawHash = GetHashKey(ClothesCache[category].draw)
    end

    -- ? ??? item unknown hash ?? unknown ??? (????? unknown ??? ?? ????)
    local savedHatHash = (category == 'hats' and ClothesCache[category] and ClothesCache[category].hash) or nil

    -- unknown ?? ???
    ClothesCache[category] = nil

    -- ? unknown: ??? unknown ??? ?? unknown?
    -- ??? 1: ??? unknown ??? (??????, ??? unknown?)
    -- ??? 2: ?unknown, ?????? ?? unknown categories?
    -- ??? 3: some item - ?unknown, ??? (?????? ? unknown???)

    -- ??? 1: ??? ?? ??? Ped-??? (raw overlay) - ??? overlay ???
    if wasPedType and pedDrawHash then
        Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, pedDrawHash, 0, 0, 0, 0, 0, 0, 0)
    end

    -- unknown MetaPed ??
    -- ? ?unknown: RemoveShopItemFromPedByCategory - ??? ?? remove ??? these unknown categories (RemoveTag ??? unknown)
    if category == 'hats' then
        local hatsHash = metaPedComponents['hats'] or 0x9925C067
        Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, hatsHash)
    else
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(category), 0)
        if metaPedComponents[category] then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, metaPedComponents[category], 0)
        end
    end

    -- unknown item/unknown item (coats/coats_closed, cloaks/ponchos)
    if ConflictingCategories and ConflictingCategories[category] then
        local conflictCategory = ConflictingCategories[category]
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(conflictCategory), 0)
        if metaPedComponents[conflictCategory] then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, metaPedComponents[conflictCategory], 0)
        end
    end

    -- Finalize + Update
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    local t = 0
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t < 50 do Wait(10) t = t + 1 end
    Wait(100)

    -- ? category unknown: UpdatePedVariation ?? sharing/??/??? - ??? unknown
    if (category == 'coats' or category == 'coats_closed') and ApplyClothingColor then
        Wait(50)
        for _, cat in ipairs({'shirts_full', 'vests', 'corsets'}) do
            if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                local d = ClothesCache[cat]
                if d.palette then
                    ApplyClothingColor(ped, cat, d.palette or 'tint_generic_clean', d.tints or {0, 0, 0})
                end
            end
        end
    end

    -- ? ??? 2: ?unknown, ?????? ?? unknown items (0xFB4891BD7578CDC1)
    -- ??? unknown ?????? (coats, vests ? ?.?.) RemoveTag ?? unknown items ???
    -- ??? unknown categories ?? LoadClothingFromInventory
    local removalFailed = false
    if metaPedComponents[category] then
        local stillEquipped = Citizen.InvokeNative(0xFB4891BD7578CDC1, ped, metaPedComponents[category])
        if stillEquipped and stillEquipped ~= 0 then
            removalFailed = true
            print('[RSG-Clothing] Targeted removal failed for ' .. category .. ' (hash still present), using layer rebuild')
        end
    end

    -- ? ??? 3: ??? - ?unknown item ??? ? unknown that ? use.
    -- forceLayerRebuild ??? unknown categories: ?unknown item ? some unknown in ?? unknown -
    -- ??? unknown parameters ??? ?? unknown (???????/??? a ???).
    local forceLayerRebuild = false
    if removalFailed or forceLayerRebuild then
        -- ?unknown item ?? something unknown
        local layerGroup
        local upperGroup = {'shirts_full', 'vests', 'corsets', 'coats', 'coats_closed', 'cloaks', 'ponchos', 'suspenders'}
        local lowerGroup = {'pants', 'skirts', 'dresses', 'chaps'}

        local function isInGroup(cat, group)
            for _, g in ipairs(group) do if g == cat then return true end end
            return false
        end

        if isInGroup(category, upperGroup) then
            layerGroup = upperGroup
        elseif isInGroup(category, lowerGroup) then
            layerGroup = lowerGroup
        else
            -- ??? unknown (?????, ??? unknown ? ?.?.) - ??? ?? ???
            layerGroup = {category}
        end

        -- unknown for some unknown item
        for _, cat in ipairs(layerGroup) do
            if cat == 'hats' then
                Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, metaPedComponents['hats'] or 0x9925C067)
            else
                Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(cat), 0)
                if metaPedComponents[cat] then
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, metaPedComponents[cat], 0)
                end
            end
        end
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        t = 0
        while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and t < 50 do Wait(10) t = t + 1 end
        Wait(50)

        -- ? Vest/corset ??? ????: naked overlay ?? unknown (?????? ?? ???, ??? unknown)
        if (category == 'coats' or category == 'coats_closed') and not IsPedMale(ped) then
            local hasShirt = ClothesCache['shirts_full'] and ClothesCache['shirts_full'].hash and ClothesCache['shirts_full'].hash ~= 0
            local hasVest = ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0
            local hasCorset = ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0
            if (hasVest or hasCorset) and not hasShirt and ApplyNakedUpperBody then
                ApplyNakedUpperBody(ped, true)
                Wait(50)
            end
        end

        -- unknown functionality ?? ?? (????? unknown ? ? melody)
        local reapplied = 0
        for _, cat in ipairs(layerGroup) do
            if cat ~= category and ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                local itemData = ClothesCache[cat]
                if itemData.kaf == "Ped" and itemData.draw and itemData.draw ~= "" then
                    -- Ped-???
                    if itemData.draw ~= "_" then
                        local drawHash = GetHashKey(itemData.draw)
                        Citizen.InvokeNative(0x59BD177A1A48600A, ped, drawHash)
                        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, drawHash, true, true, true)
                    end
                    if itemData.albedo and itemData.albedo ~= "" then
                        Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey(itemData.albedo))
                        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, GetHashKey(itemData.albedo), true, true, true)
                    end
                else
                    -- Classic-???
                    NativeSetPedComponentEnabledClothes(ped, itemData.hash, false, true, true)
                end
                reapplied = reapplied + 1
            end
        end

        if reapplied > 0 then
            NativeUpdatePedVariation(ped, true)
            Wait(50)
            -- unknown item?
            for _, cat in ipairs(layerGroup) do
                if ClothesCache[cat] and ClothesCache[cat].palette and ClothesCache[cat].tints then
                    local d = ClothesCache[cat]
                    local hasTints = d.tints[1] ~= 0 or d.tints[2] ~= 0 or d.tints[3] ~= 0
                    local isPedCoat = IsPedCoatItem(cat, d)
                    if isPedCoat or hasTints or d.palette ~= 'tint_generic_clean' then
                        ApplyClothingColor(ped, cat, d.palette, d.tints)
                    end
                end
            end
        end

        print('[RSG-Clothing] Layer rebuild complete: reapplied ' .. reapplied .. ' items')
        if category == 'coats' or category == 'coats_closed' then
            _G._CoatJustChanged = GetGameTimer()
        end
    end

    -- ? item: ? loadcharacter RemoveShopItemFromPedByCategory ??? ?? remove ?? unknown - ???
    if category == 'hats' and savedHatHash and savedHatHash ~= 0 then
        CreateThread(function()
            for _, delay in ipairs({100, 400, 1000}) do
                Wait(delay)
                local p = PlayerPedId()
                if p and DoesEntityExist(p) and ClearFloatingHatProp then
                    ClearFloatingHatProp(p, savedHatHash, false)
                end
            end
        end)
    end

    -- Store/wardrobe Variant 0 asks this handler to finish component removal
    -- before the targeted body refresh runs. This avoids two competing naked
    -- body passes while the MetaPed variation is still settling.
    if not options.deferBodyRefresh and (category == "pants" or category == "skirts" or category == "dresses") then
        local hasLower = false
        for _, cat in ipairs({'pants', 'skirts', 'dresses'}) do
            if ClothesCache[cat] and type(ClothesCache[cat]) == 'table' then
                if (ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0) then hasLower = true break end
            end
        end
        if not hasLower then
            if ApplyNakedLowerBody then ApplyNakedLowerBody(ped) end
            Wait(150)
            -- unknown ?????????? ???? naked overlay
            pcall(function()
                exports['rsg-appearance']:ReapplyBootsFromCache(ped)
            end)
        end
    end
    if not options.deferBodyRefresh and (category == "shirts_full" or category == "dresses" or category == "coats" or category == "coats_closed" or category == "vests" or category == "corsets") then
        local isMale = IsPedMale(ped)
        if not isMale or isMale == false or isMale == 0 then
            -- ? ???? object/neck/type = ?? unknown ?? naked. Vest/corset ??? ??? - naked ??? (?????? ?? ???? ????)
            -- ? FIX: ??? vest/corset ?? unknown naked - overlay ??? shared item.
            local hasUpper = false
            for _, cat in ipairs({'shirts_full', 'dresses', 'coats', 'coats_closed'}) do
                if ClothesCache[cat] and type(ClothesCache[cat]) == 'table' then
                    if (ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0) then hasUpper = true break end
                end
            end
            local hasVestOnly = false
            for _, cat in ipairs({'vests', 'corsets'}) do
                if ClothesCache[cat] and type(ClothesCache[cat]) == 'table' and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                    hasVestOnly = true break
                end
            end
            if not hasUpper and not hasVestOnly then
                if ApplyNakedUpperBody then ApplyNakedUpperBody(ped) end
            end
        end
    end

    if not options.deferBodyRefresh then
        EnsureBodyIntegrity(ped, false)
    end
    -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
    -- if options.refreshBody then
    --     TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', category, true, ped)
    -- end
    -- ? ?unknown: ReapplyAppearanceAfterClothing ?? unknown?
    -- ? unknown: ?? ??? unknown ?? unknown ?? unknown
    if not options.skipResync and EnableToggleInventoryResync and ScheduleClothingResyncFromInventory and category ~= 'coats' and category ~= 'coats_closed' then
        ScheduleClothingResyncFromInventory('remove:' .. tostring(category))
    end
    print('[RSG-Clothing] Category removed: ' .. category)
    end) -- end CreateThread
end)

-- ==========================================
-- unknown item/unknown unknown
-- ==========================================

RegisterNetEvent('rsg-clothing:client:playClothingAnim')
AddEventHandler('rsg-clothing:client:playClothingAnim', function(category)
    CreateThread(function()
        local ped = PlayerPedId()
        local dict, anim
        if category == 'hats' then
            dict = 'mech_loco_m@character@arthur@fidgets@hat@normal@unarmed@normal@left_hand'
            anim = 'hat_lhand_b'
        else
            dict = 'mech_inventory@clothing@bandana'
            anim = 'neck_2_satchel'
        end
        
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 100 do
            Wait(50)
            timeout = timeout + 1
        end
        
        if HasAnimDictLoaded(dict) then
            if not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) then
                TaskPlayAnim(ped, dict, anim, 4.0, -4.0, 2000, 51, 0, false, false, false)
            end
        end
    end)
end)

print('[RSG-Clothing] Fixed equip/remove handlers loaded (v2.0)')

-- ? unknown category ??? ??? unknown (????? ? ??? ??? ? ??? - ??? unknown ??? ?????)
-- unknown ??? ??? categories: hasHat ??? ?? true, ??? ?? unknown ??? unknown ???
CreateThread(function()
    while true do
        Wait(800)
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then goto continue end
        if IsInHatInteraction(ped) then goto continue end
        if not ClothesCache or not ClothesCache['hats'] or not ClothesCache['hats'].hash then goto continue end
        if LocalPlayer.state.isLoadingCharacter then goto continue end
        local hatModelHash = ClothesCache['hats'].hash
        ClearFloatingHatProp(ped, hatModelHash, false)
        ::continue::
    end
end)

-- ? ??? unknown - ??? ??? unknown ??? (???? ????, ?? ??? ? unknown ?? ????)
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim = args[1]
    if victim ~= PlayerPedId() or not DoesEntityExist(victim) then return end
    if not ClothesCache or not ClothesCache['hats'] or not ClothesCache['hats'].hash then return end

    local ped = PlayerPedId()
    if IsInHatInteraction(ped) then return end
    local hatModelHash = ClothesCache['hats'].hash
    for _, delay in ipairs({0, 150, 400, 800}) do
        SetTimeout(delay, function()
            local p = PlayerPedId()
            if DoesEntityExist(p) and ClothesCache and ClothesCache['hats'] then
                ClearFloatingHatProp(p, hatModelHash, true)
            end
        end)
    end
end)

-- ==========================================
-- unknown categories ??? unknown
-- ==========================================

exports('IsCothingActive', function()
    return LocalPlayer.state.inClothingStore
end)

exports('GetClothesCache', function()
    return ClothesCache
end)

--- ??? unknown ricx-unknown: ??? ClothesCache + ??? ?? ??? unknown ? ???? (??? ???/unknown).
function PreparePedForRicxFullOutfit(ped)
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    if not DoesEntityExist(ped) then return end
    ClothesCache = {}
    if type(StripClothesOnly) == 'function' then
        StripClothesOnly(ped)
    end
end
exports('PreparePedForRicxFullOutfit', PreparePedForRicxFullOutfit)

-- ? ??? item ??? ??? ?? (BODIES_LOWER) - ??? unknown ??? (???.: ???/????/??+?????)
local BODIES_LOWER_CATEGORY = 0x823687F5
-- MP ??? unknown/unknown (clothes_list BODIES_UPPER)
local BODIES_UPPER_CATEGORY = 0x0B3966C9

function RestoreBodiesLower(ped)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then return end
    local bodyHash = GetBodyHashFromClothesList(ped, "BODIES_LOWER") or GetBodyHash("BODIES_LOWER") or GetBodyHashNative(ped, "BODIES_LOWER")
    if not bodyHash or bodyHash == 0 then return end
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey("bodies_lower"))
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyHash, true, true, true)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end
exports('RestoreBodiesLower', RestoreBodiesLower)

function RestoreBodiesUpper(ped)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then return end
    local bodyHash = GetBodyHashFromClothesList(ped, "BODIES_UPPER") or GetBodyHash("BODIES_UPPER") or GetBodyHashNative(ped, "BODIES_UPPER")
    if not bodyHash or bodyHash == 0 then return end
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey("bodies_upper"))
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, bodyHash, true, true, true)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end
exports('RestoreBodiesUpper', RestoreBodiesUpper)

-- Targeted replacement for using /loadskin after a clothing preview. Store and
-- creator sliders can change MetaPed components faster than body layers settle;
-- this restores only the affected body base/naked overlay and reapplies morphs.
local previewBodyRefreshTokens = {}
local PreviewUpperCategories = {
    shirts = true, shirts_full = true, vests = true, corsets = true,
    coats = true, coats_closed = true, dresses = true,
}
local PreviewLowerCategories = {
    pants = true, skirts = true, dresses = true, boots = true,
}

local function HasCachedClothing(categories)
    for _, category in ipairs(categories) do
        local item = ClothesCache and ClothesCache[category]
        if item and item.hash and item.hash ~= 0 then return true end
    end
    return false
end

local function RefreshClothingPreviewBody(category, removed, targetPed)
    local isCreatorModelRefresh = category == 'creator_model'
    -- The legacy implementation remains available for reference.
    if _G.DisableAutomaticBodyFixes then return end
    if category == 'outfit' or isCreatorModelRefresh then
        for key, value in pairs(previewBodyRefreshTokens) do
            previewBodyRefreshTokens[key] = value + 1
        end
    end
    local tokenKey = tostring(category or 'all')
    previewBodyRefreshTokens[tokenKey] = (previewBodyRefreshTokens[tokenKey] or 0) + 1
    local token = previewBodyRefreshTokens[tokenKey]

    CreateThread(function()
        Wait((isCreatorModelRefresh or removed) and 100 or 350)
        if token ~= previewBodyRefreshTokens[tokenKey] then return end
        local ped
        if targetPed ~= nil then
            if not DoesEntityExist(targetPed) then return end
            ped = targetPed
        else
            ped = PlayerPedId()
        end
        if not ped or not DoesEntityExist(ped) then return end

        local usesPlayerCache = ped == PlayerPedId()
        if removed and usesPlayerCache and ClothesCache then ClothesCache[category] = nil end

        local maleResult = IsPedMale(ped)
        local isMale = maleResult == true or maleResult == 1
        local isCompleteOutfitRefresh = category == 'outfit'
        local refreshesUpper = isCreatorModelRefresh or isCompleteOutfitRefresh or PreviewUpperCategories[category]
        local refreshesLower = isCreatorModelRefresh or isCompleteOutfitRefresh or PreviewLowerCategories[category]

        if isCompleteOutfitRefresh and usesPlayerCache then
            if RemoveNakedLowerBody then RemoveNakedLowerBody(ped, true, true) end
            if RemoveNakedUpperBody then RemoveNakedUpperBody(ped, true, true) end
        end

        local function ReapplyExpectedNakedLayers()
            if usesPlayerCache then
                if refreshesLower and not HasCachedClothing({ 'pants', 'skirts', 'dresses' }) and ApplyNakedLowerBody then
                    ApplyNakedLowerBody(ped, true)
                end
                if refreshesUpper and not isMale then
                    local hasUpperCover = HasCachedClothing({
                        'shirts_full', 'dresses', 'coats', 'coats_closed', 'vests', 'corsets'
                    })
                    if not hasUpperCover and ApplyNakedUpperBody then
                        ApplyNakedUpperBody(ped, true)
                    end
                end
                return
            end

            if refreshesLower and (isCreatorModelRefresh or removed or category == 'boots') and ApplyNakedLowerBody then
                ApplyNakedLowerBody(ped, true)
            end
            if refreshesUpper and not isMale and (isCreatorModelRefresh or removed) and ApplyNakedUpperBody then
                ApplyNakedUpperBody(ped, true)
            end
        end

        if isCreatorModelRefresh then
            -- A newly created MetaPed can report ready before both body bases and
            -- raw naked overlays have settled. Rebuild them together so the first
            -- model and every gender replacement start from the same known state.
            if RemoveNakedLowerBody then RemoveNakedLowerBody(ped, true, true) end
            if RemoveNakedUpperBody then RemoveNakedUpperBody(ped, true, true) end
            RestoreBodiesLower(ped)
            RestoreBodiesUpper(ped)
            Wait(60)
            if ApplyNakedLowerBody then ApplyNakedLowerBody(ped, true) end
            if not isMale and ApplyNakedUpperBody then ApplyNakedUpperBody(ped, true) end
        end

        if PreviewUpperCategories[category] and not isMale then
            local hasUpperCover = usesPlayerCache and HasCachedClothing({
                'shirts_full', 'dresses', 'coats', 'coats_closed', 'vests', 'corsets'
            }) or false
            if removed and not hasUpperCover then
                if RemoveNakedUpperBody then RemoveNakedUpperBody(ped, true, true) end
                RestoreBodiesUpper(ped)
                Wait(60)
                if ApplyNakedUpperBody then ApplyNakedUpperBody(ped, true) end
            elseif not removed and RemoveNakedUpperBody then
                RemoveNakedUpperBody(ped, true, true)
            end
        end

        if PreviewLowerCategories[category] then
            local hasLowerCover = usesPlayerCache and HasCachedClothing({ 'pants', 'skirts', 'dresses' }) or false
            if removed and not hasLowerCover then
                if RemoveNakedLowerBody then RemoveNakedLowerBody(ped, true, true) end
                RestoreBodiesLower(ped)
                Wait(60)
                if ApplyNakedLowerBody then ApplyNakedLowerBody(ped, true) end
            elseif not removed and RemoveNakedLowerBody then
                RemoveNakedLowerBody(ped, true, true)
            end
        end

        -- EnsureBodyIntegrity reads the player's ClothesCache, so it must not
        -- make cache-based decisions for the separate character-creator ped.
        if usesPlayerCache and EnsureBodyIntegrity then EnsureBodyIntegrity(ped, true) end
        if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
        NativeUpdatePedVariation(ped, true)
        if usesPlayerCache and CheckAndApplyNakedBodyIfNeeded then
            CheckAndApplyNakedBodyIfNeeded(ped, ClothesCache)
        end
        ReapplyExpectedNakedLayers()

        -- One late settle pass handles streamed components without reloading the
        -- model, head, overlays, or persistent appearance data.
        Wait(450)
        if token ~= previewBodyRefreshTokens[tokenKey] or not DoesEntityExist(ped) then return end
        if usesPlayerCache and EnsureBodyIntegrity then EnsureBodyIntegrity(ped, true) end
        if ReapplyBodyMorph then ReapplyBodyMorph(ped) end
        NativeUpdatePedVariation(ped, true)
        if usesPlayerCache and CheckAndApplyNakedBodyIfNeeded then
            CheckAndApplyNakedBodyIfNeeded(ped, ClothesCache)
        end
        ReapplyExpectedNakedLayers()
    end)
end

RegisterNetEvent('rsg-appearance:client:RefreshClothingPreviewBody', RefreshClothingPreviewBody)
exports('RefreshClothingPreviewBody', RefreshClothingPreviewBody)

local function _PedVariationRefresh(ped)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

local GLOVES_CATEGORY_HASH = 0xEABE0032

-- MP âunknown bodiesâ ? ??? ??? BODIES_UPPER (tint 1-6 ? skin_tone ?? clothes_list)
local BARE_HAND_GLOVES_MALE = {
    0x2C6BA43B, 0x88265BAF, 0x082ADBB6, 0x1A4A7FF5, 0xE5181591, 0xF5C6B6EE,
}
local BARE_HAND_GLOVES_FEMALE = {
    0x232BB82B, 0xDB37A860, 0xE9D8C5A2, 0xBF9DF12D, 0xCE640EB9, 0xA4123A16,
}

local function _RicxSkinToneForBareHands()
    if type(GetSkinTone) == 'function' then
        local t = tonumber(GetSkinTone())
        if t then return math.max(1, math.min(t, 6)) end
    end
    if type(CurrentSkinData) == 'table' and CurrentSkinData.skin_tone then
        local t = tonumber(CurrentSkinData.skin_tone)
        if t then return math.max(1, math.min(t, 6)) end
    end
    if type(CreatorCache) == 'table' and CreatorCache.skin_tone then
        local t = tonumber(CreatorCache.skin_tone)
        if t then return math.max(1, math.min(t, 6)) end
    end
    if type(LoadedComponents) == 'table' and LoadedComponents.skin_tone then
        local t = tonumber(LoadedComponents.skin_tone)
        if t then return math.max(1, math.min(t, 6)) end
    end
    return 1
end

local function _BareHandGloveHashForPed(ped)
    local tone = _RicxSkinToneForBareHands()
    if IsPedMale(ped) then
        return BARE_HAND_GLOVES_MALE[tone] or BARE_HAND_GLOVES_MALE[1]
    end
    return BARE_HAND_GLOVES_FEMALE[tone] or BARE_HAND_GLOVES_FEMALE[1]
end

local function _OutfitHasGlovesInCache()
    local g = ClothesCache and ClothesCache['gloves']
    return g and g.hash and tonumber(g.hash) and tonumber(g.hash) ~= 0
end

local function ApplyBareHandsGloveOverlayAfterUpperHide(ped)
    if not ped or not DoesEntityExist(ped) then return end
    if _OutfitHasGlovesInCache() then return end
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GLOVES_CATEGORY_HASH, 0)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    Wait(20)
    local h = _BareHandGloveHashForPed(ped)
    NativeSetPedComponentEnabledClothes(ped, h, false, true, true)
    -- unknown functionality to get skin_tone (??? on HS ? âunknown? per settingsâ ??? ?? LoadedComponents)
    local tone = _RicxSkinToneForBareHands()
    if ApplyClothingColor then
        ApplyClothingColor(ped, 'gloves', 'tint_generic_clean', { tone, 0, 0 })
    end
end

local function RestoreGlovesSlotFromCacheAfterRicx(ped)
    if not ped or not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GLOVES_CATEGORY_HASH, 0)
    _PedVariationRefresh(ped)
    local g = ClothesCache and ClothesCache['gloves']
    if g and g.hash and tonumber(g.hash) and tonumber(g.hash) ~= 0 then
        NativeSetPedComponentEnabledClothes(ped, g.hash, false, true, true)
        if g.palette and ApplyClothingColor then
            ApplyClothingColor(ped, 'gloves', g.palette or 'tint_generic_clean', g.tints or { 0, 0, 0 })
        end
    end
    _PedVariationRefresh(ped)
end

--- unknown MP-??? ??? (?????? ?? ??? + ??? and naked_body) - ??? ?? unknown category ??? ???
function HideBodiesLowerMesh(ped)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, BODIES_LOWER_CATEGORY, 0)
    _PedVariationRefresh(ped)
end
exports('HideBodiesLowerMesh', HideBodiesLowerMesh)

--- unknown MP-??? ?/??? - ??? ?? unknown ??? attribute?? unknown?? (????? ricx ? ?.?.
function HideBodiesUpperMesh(ped)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, BODIES_UPPER_CATEGORY, 0)
    _PedVariationRefresh(ped)
end
exports('HideBodiesUpperMesh', HideBodiesUpperMesh)

local function RicxCustomIdInList(id, list)
    if type(id) ~= 'string' or id == '' or type(list) ~= 'table' then return false end
    id = (id:match('^%s*(.-)%s*$') or id):lower()
    for _, v in ipairs(list) do
        if type(v) == 'string' and v:lower() == id then return true end
    end
    return false
end

local function RicxActiveOutfitHidesUpperBody(cfg)
    return RicxCustomIdInList(_G._RicxActiveOutfitCustomId, cfg.ricxHideUpperBodyCustomIds)
end

local function RicxActiveOutfitUsesBareHandsOverlay(cfg)
    return RicxCustomIdInList(_G._RicxActiveOutfitCustomId, cfg.ricxBareHandsAfterUpperHideCustomIds)
end

function ApplyRicxOutfitBodyMeshHide(ped)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    if not DoesEntityExist(ped) then return end
    local cfg = RSG.RicxOutfitHideBodyMesh
    if not cfg or cfg.enabled ~= true then return end
    _G._RicxDidApplyUpperBodyHide = false
    _G._RicxAppliedBareHandsRicxHide = false
    if cfg.hideLower then
        HideBodiesLowerMesh(ped)
    end
    if cfg.hideUpper and RicxActiveOutfitHidesUpperBody(cfg) then
        Wait(40)
        HideBodiesUpperMesh(ped)
        _G._RicxDidApplyUpperBodyHide = true
        if RicxActiveOutfitUsesBareHandsOverlay(cfg) then
            Wait(35)
            ApplyBareHandsGloveOverlayAfterUpperHide(ped)
            _G._RicxAppliedBareHandsRicxHide = true
            _PedVariationRefresh(ped)
        end
    end
end
exports('ApplyRicxOutfitBodyMeshHide', ApplyRicxOutfitBodyMeshHide)

function RestoreRicxOutfitBodyMesh(ped)
    if _G.DisableAutomaticBodyFixes then return end
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    if not DoesEntityExist(ped) then return end
    local cfg = RSG.RicxOutfitHideBodyMesh
    if not cfg or cfg.enabled ~= true then return end
    if cfg.hideLower then RestoreBodiesLower(ped) end
    if cfg.hideUpper and _G._RicxDidApplyUpperBodyHide then
        if _G._RicxAppliedBareHandsRicxHide then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, GLOVES_CATEGORY_HASH, 0)
            _PedVariationRefresh(ped)
            Wait(20)
        end
        RestoreBodiesUpper(ped)
        if _G._RicxAppliedBareHandsRicxHide then
            Wait(25)
            RestoreGlovesSlotFromCacheAfterRicx(ped)
        end
        _G._RicxDidApplyUpperBodyHide = false
        _G._RicxAppliedBareHandsRicxHide = false
    end
end
exports('RestoreRicxOutfitBodyMesh', RestoreRicxOutfitBodyMesh)

RegisterNetEvent('rsg-appearance:client:applyRicxBodyMeshHide', function()
    local ped = PlayerPedId()
    if DoesEntityExist(ped) and _G._RicxOutfitActive then
        ApplyRicxOutfitBodyMeshHide(ped)
    end
end)

CreateThread(function()
    for _,v in pairs(RSG.SetDoorState) do
        Citizen.InvokeNative(0xD99229FE93B46286, v.door, 1, 1, 0, 0, 0, 0)
        DoorSystemSetDoorState(v.door, v.state)
    end
end)

function GetDescriptionLayout(value, price)
    local desc = image:format(value.img) .. "<br><br>" .. value.desc .. "<br><br>" .. Divider ..
        "<br><span style='font-family:crock; float:left; font-size: 22px;'>" ..
        RSG.Label.total .. " </span><span style='font-family:crock;float:right; font-size: 22px;'>$" ..
        (price or CurrentPrice) .. "</span><br>" .. Divider
    return desc
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function GetPurchasedItems(newCache, oldCache, isMale)
    local purchasedItems = {}
    local gender = isMale and "male" or "female"
    
    if not newCache then return purchasedItems end
    if not oldCache then oldCache = {} end
    
    for category, newData in pairs(newCache) do
        if type(newData) ~= "table" then goto continue end
        
        local newModel = newData.model
        local newTexture = newData.texture or 1
        
        if not newModel or newModel < 1 then goto continue end
        
        local oldData = oldCache[category]
        local isNew = false
        
        if not oldData or type(oldData) ~= "table" then
            isNew = true
        elseif not oldData.model or oldData.model < 1 then
            isNew = true
        elseif newModel ~= oldData.model then
            isNew = true
        elseif newTexture ~= (oldData.texture or 1) then
            isNew = true
        end
        
        if isNew then
            local hash = nil
            
            if newData.hash and newData.hash ~= 0 then
                hash = newData.hash
            elseif clothing[gender] and clothing[gender][category] then
                if clothing[gender][category][newModel] and clothing[gender][category][newModel][newTexture] then
                    hash = clothing[gender][category][newModel][newTexture].hash
                end
            end
            
            if hash and hash ~= 0 then
                table.insert(purchasedItems, {
                    category = category,
                    hash = hash,
                    model = newModel,
                    texture = newTexture,
                    isMale = isMale
                })
            end
        end
        
        ::continue::
    end
    
    return purchasedItems
end

-- ==========================================
-- unknown functionality (unknown)
-- ==========================================

function OpenClothingMenu()
    MenuData.CloseAll()
    local elements = {}

    for categoryKey, categoryData in pairsByKeys(RSG.MenuElements) do
        local iconName = GetCategoryIcon(categoryKey)
        elements[#elements + 1] = {
            label = categoryData.label or categoryKey,
            value = categoryKey,
            category = categoryKey,
            desc = image:format(iconName) .. "<br><br>" .. Divider .. "<br> " .. locale('clothing_menu.category_desc'),
        }
    end
    
    if not (IsInCharCreation or Skinkosong) then
        local descLayout = GetDescriptionLayout(
            { img = "menu_icon_tick", desc = locale('clothing_menu.confirm_purhcase') },
            CurrentPrice
        )
        elements[#elements + 1] = {
            label = RSG.Label.save or "Save",
            value = "save",
            desc = descLayout
        }
    end
    
    MenuData.Open('default', GetCurrentResourceName(), 'clothing_store_menu',
        {
            title = RSG.Label.clothes,
            subtext = RSG.Label.shop .. ' - $' .. CurrentPrice,
            align = 'top-left',
            elements = elements,
            itemHeight = "4vh"
        },
        function(data, menu)
            if data.current.value ~= "save" then
                OpenSubcategoryMenu(data.current.value)
            else
                if CurrentPrice > 0 then
                    RSGCore.Functions.TriggerCallback('rsg-clothing:server:purchaseClothing', function(success)
                        if success then
                            menu.close()
                            destory()
                            
                            local ClothesHash = ConvertCacheToHash(ClothesCache)
                            local isMale = IsPedMale(PlayerPedId())
                            local purchasedItems = GetPurchasedItems(ClothesCache, OldClothesCache, isMale)
                            
                            if purchasedItems and #purchasedItems > 0 then
                                for _, item in ipairs(purchasedItems) do
                                    TriggerServerEvent('rsg-clothing:server:saveToInventory', item)
                                    Wait(100)
                                end
                            end
                            
                            TriggerServerEvent("rsg-appearance:server:saveOutfit", ClothesHash, isMale)
                            Wait(500)
                            TriggerServerEvent('rsg-clothing:server:equipAfterPurchase')
                            
                            if next(CurentCoords) == nil then
                                CurentCoords = RSG.Zones1[1]
                            end
                            TeleportAndFade(CurentCoords.quitcoords, true)
                            Wait(1000)
                            ExecuteCommand('loadskin')
                            
                            TriggerEvent('ox_lib:notify', {
                                 title = 'unknown item',
                                 description = 'unknown description! ???: $' .. CurrentPrice,
                                type = 'success'
                            })
                        else
                            TriggerEvent('ox_lib:notify', {
                                 title = 'unknown item',
                                 description = 'unknown word! ???: $' .. CurrentPrice,
                                type = 'error'
                            })
                        end
                    end, CurrentPrice)
                else
                    menu.close()
                    destory()
                    if next(CurentCoords) == nil then
                        CurentCoords = RSG.Zones1[1]
                    end
                    TeleportAndFade(CurentCoords.quitcoords, true)
                    Wait(1000)
                    ExecuteCommand('loadskin')
                end
            end
        end,
        function(data, menu)
            if (IsInCharCreation or Skinkosong) then
                menu.close()
                FirstMenu()
            else
                menu.close()
                destory()
                if next(CurentCoords) == nil then
                    CurentCoords = RSG.Zones1[1]
                end
                TeleportAndFade(CurentCoords.quitcoords, true)
                Wait(1000)
                ExecuteCommand('loadskin')
            end
        end)
end

-- ??? unknown: ??? unknown categories (hats, eyewear, masks ? ?.?.)
function OpenSubcategoryMenu(mainCategory)
    MenuData.CloseAll()
    local elements = {}
    
    local categoryData = RSG.MenuElements[mainCategory]
    if not categoryData or not categoryData.category then
        OpenClothingMenu()
        return
    end
    
    -- unknown item ?unknown?
    for _, subcategory in ipairs(categoryData.category) do
        local isMale = IsPedMale(PlayerPedId())
        local gender = isMale and "male" or "female"
        
        -- ?unknown item ?? for ??? ??? unknown items
        if clothing[gender] and clothing[gender][subcategory] then
            local iconName = GetCategoryIcon(subcategory)
            elements[#elements + 1] = {
                label = RSG.Label[subcategory] or subcategory,
                value = subcategory,
                category = subcategory,
                desc = image:format(iconName) .. "<br><br>" .. Divider
            }
        end
    end
    
    if #elements == 0 then
        OpenClothingMenu()
        return
    end
    
    MenuData.Open('default', GetCurrentResourceName(), 'clothing_subcategory_menu',
        {
            title = categoryData.label or mainCategory,
            subtext = RSG.Label.options,
            align = 'top-left',
            elements = elements,
            itemHeight = "4vh"
        },
        function(data, menu)
            OpenItemMenu(data.current.category)
        end,
        function(data, menu)
            menu.close()
            OpenClothingMenu()
        end)
end

-- ??? unknown: ?????? unknown categories (??? ?? and ????)
function OpenItemMenu(category)
    MenuData.CloseAll()
    local elements = {}
    local isMale = IsPedMale(PlayerPedId())
    local gender = isMale and "male" or "female"
    
    if not clothing[gender] or not clothing[gender][category] then
        OpenClothingMenu()
        return
    end
    
    local categoryClothing = clothing[gender][category]
    
    -- unknown plugin ??
    if ClothesCache[category] == nil or type(ClothesCache[category]) ~= "table" then
        ClothesCache[category] = {}
        ClothesCache[category].model = 0
        ClothesCache[category].texture = 1
    end
    
    local price = RSG.Price[category] or 5
    local iconName = GetCategoryIcon(category)
    
    -- ? ??? unknown ??? ?? unknown???
    local oldModel = OldClothesCache[category] and OldClothesCache[category].model or 0
    local oldTexture = OldClothesCache[category] and OldClothesCache[category].texture or 0
    local currentModel = ClothesCache[category].model or 0
    local currentTexture = ClothesCache[category].texture or 1
    
    local modelChanged = (currentModel > 0 and currentModel ~= oldModel)
    local textureChanged = (currentModel > 0 and currentModel == oldModel and currentTexture ~= oldTexture)
    local needsPurchase = modelChanged or textureChanged
    
    local displayPrice = needsPurchase and price or 0
    
    -- unknown item ??
    local modelDesc = image:format(iconName) .. "<br><br>"
    if modelChanged then
        modelDesc = modelDesc .. "?? unknown:\\<span style='color:gold;'>$" .. price .. "</span>"
    elseif currentModel > 0 then
        modelDesc = modelDesc .. "?? unknown ??? unknown"
    else
        modelDesc = modelDesc .. "??? unknown"
    end
    modelDesc = modelDesc .. "<br>" .. Divider
    
    elements[#elements + 1] = {
        label = RSG.Label[category] or category,
        value = ClothesCache[category].model or 0,
        category = category,
        desc = modelDesc,
        type = "slider",
        min = 0,
        max = #categoryClothing,
        change_type = "model",
        id = 1
    }
    
    -- unknown item ???
    local textureDesc = ""
    if textureChanged then
        textureDesc = "?? unknown?: <span style='color:gold;'>$" .. price .. "</span>"
    elseif currentModel > 0 and currentTexture == oldTexture then
        textureDesc = "<span style='color:lime;'>?? unknown ##unknown?</span>"
    else
        textureDesc = "??? unknown"
    end
    
    elements[#elements + 1] = {
        label = RSG.Label.color .. " " .. (RSG.Label[category] or category),
        value = ClothesCache[category].texture or 1,
        category = category,
        desc = textureDesc,
        type = "slider",
        min = 1,
        max = GetMaxTexturesForModel(category, ClothesCache[category].model or 1, true),
        change_type = "texture",
        id = 2
    }
    
    MenuData.Open('default', GetCurrentResourceName(), 'clothing_item_menu',
        {
            title = RSG.Label[category] or category,
            subtext = '?? to unknown: $' .. price .. ' | ? unknown: $' .. CurrentPrice,
            align = 'top-left',
            elements = elements,
            itemHeight = "4vh"
        },
        function(data, menu)
            -- ??? ?? ?unknown?
        end,
        function(data, menu)
            menu.close()
            -- ??? unknown functionality?
            local mainCategory = nil
            for catKey, catData in pairs(RSG.MenuElements) do
                for _, subcat in ipairs(catData.category) do
                    if subcat == category then
                        mainCategory = catKey
                        break
                    end
                end
                if mainCategory then break end
            end
            
            if mainCategory then
                OpenSubcategoryMenu(mainCategory)
            else
                OpenClothingMenu()
            end
        end,
        function(data, menu)
            MenuUpdateClothes(data, menu)
        end)
end
-- ==========================================
-- ??? unknown item ?? (SLEEVES/COLLAR/BANDANA)
-- ==========================================

local ClothingModState = {
    sleeves_rolled = false,      -- ??? unknown functionality (???)
    sleeves_rolled_open = false, -- ??? unknown + ??? unknown functionality (???)
    bandana_up = false,          -- Bandana Up
}

    -- Debugging Info
local ClothingVariations = {
    shirts = {
        base = 'BASE',
        rolled_closed = 'Closed_Collar_Rolled_Sleeve',  -- Rolled Collar, Closed Sleeve
        rolled_open = 'open_collar_rolled_sleeve',       -- Rolled Collar, Open Sleeve
    },
    bandana = {
        up = 'BANDANA_ON_RIGHT_HAND',
        down = 'BANDANA_OFF_RIGHT_HAND',
        base = 'base',
    }
}

    -- What is the purpose of this?
function SetPedComponentVariation(ped, componentHash, variationName)
    Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, componentHash, joaat(variationName), 0, true, 1)
end

    -- What is happening here (for testing)
function PlayComponentChangeAnimation(ped, componentHash, variationName)
    Citizen.InvokeNative(0xAE72E7DF013AAA61, ped, componentHash, joaat(variationName), 1, 0, -1082130432)
end

    -- Debug messages here
    -- options.skipBodyMorph = true - what does ReapplyBodyMorph (for debugging?)
    -- options.skipFinalize = true - what does 0x704C908E9C405136 (for kaf_bulletproof, what is happening here?)
function UpdatePedVariation(ped, options)
    options = options or {}
    if not options.skipFinalize then Citizen.InvokeNative(0x704C908E9C405136, ped) end
        -- what is skipFinalize (debugging/testing) - (0,1,1,1,false) for kaf_bulletproof, what is happening here?
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, options.skipFinalize and 0 or false, options.skipFinalize and 1 or true, true, true, false)
        -- what is body morphing - for debugging body morph. Debug message here,
        -- what is ReapplyBodyMorph asking for here in debugging?
    if ReapplyBodyMorph and not options.skipBodyMorph then
        if options.deferBodyMorph then
            SetTimeout(350, function()
                local p = ped and DoesEntityExist(ped) and ped or PlayerPedId()
                if p and DoesEntityExist(p) then ReapplyBodyMorph(p) end
            end)
        else
            ReapplyBodyMorph(ped)
        end
    end
        -- what about: /sleeves ? /sleeves2 debugging what is happening (for NativeUpdatePedVariation) - includes shiw-tattoos debugging too
        -- what is: overlays for UpdatePedVariation
    if ped == PlayerPedId() then
        SetTimeout(120, function()
            TriggerEvent('shiw-tattoos:client:afterPedVariation')
            TriggerEvent('rsg-appearance:client:afterPedVariation')
        end)
    end
end

    -- Temporary or default name for testing (what about the debugging strategy/testing?)
local function ReapplyVestOverShirt(ped)
    if not ped or not DoesEntityExist(ped) then return end
    local item = (ClothesCache and ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0) and ClothesCache['vests']
        or (ClothesCache and ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0) and ClothesCache['corsets']
    if not item then return end
    NativeSetPedComponentEnabledClothes(ped, item.hash, false, true, true)
    if NativeUpdatePedVariationClothes then NativeUpdatePedVariationClothes(ped) end
end

    -- Note: afterBodyMorph -> ReapplyVestIfEquipped debugging what is happening with NativeUpdatePedVariation
-- AddEventHandler('rsg-appearance:client:afterBodyMorph', ...)

    -- Note/Guide: debugging here (testing what works without creator.lua but involves ApplySkin, and so forth)
function ReapplyVestIfEquipped(ped)
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    local item = (ClothesCache and ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0) and ClothesCache['vests']
        or (ClothesCache and ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0) and ClothesCache['corsets']
    if not item then return end
        -- Request Debug Apply - testing different methods (0x59BD177A1A48600A)
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, item.hash)
    NativeSetPedComponentEnabledClothes(ped, item.hash, false, true, true)
    if NativeUpdatePedVariationClothes then NativeUpdatePedVariationClothes(ped) end
end

    -- Temporary uses hash here
function GetCurrentShirtHash()
    if not ClothesCache then return nil end
    if not ClothesCache['shirts_full'] then return nil end
    if type(ClothesCache['shirts_full']) ~= 'table' then return nil end
    return ClothesCache['shirts_full'].hash
end

    -- Temporary uses hash for testing/description
function GetCurrentNeckwearHash()
    if not ClothesCache then return nil end
    if not ClothesCache['neckwear'] then return nil end
    if type(ClothesCache['neckwear']) ~= 'table' then return nil end
    return ClothesCache['neckwear'].hash
end

-- ==========================================
    -- Temporary stuff (testing 1 - debugging changes)
-- ==========================================
function ToggleSleeves()
    local ped = PlayerPedId()
    local shirtHash = GetCurrentShirtHash()
    
    if not shirtHash or shirtHash == 0 then
        TriggerEvent('ox_lib:notify', {
            title = 'Debug Title',
            description = 'Debugging Description Here',
            type = 'error'
        })
        return
    end
    
    -- Temporary controls debugging validation checks
    ClothingModState.sleeves_rolled_open = false
    
    -- Temporary debugging here
    ClothingModState.sleeves_rolled = not ClothingModState.sleeves_rolled
    
    -- Temporary Debugging
    PlayClothingModAnimation('sleeves')
    Wait(500)
    
    local variation = ClothingModState.sleeves_rolled 
        and ClothingVariations.shirts.rolled_closed 
        or ClothingVariations.shirts.base
    
    -- what is Debug Info for getEquippedClothing (for testing here, what is going on?)
    local fallbackPalette = ClothesCache and ClothesCache['shirts_full'] and ClothesCache['shirts_full'].palette
    local fallbackTints = ClothesCache and ClothesCache['shirts_full'] and ClothesCache['shirts_full'].tints
    RSGCore.Functions.TriggerCallback('rsg-clothing:server:getEquippedClothing', function(equipped)
        local pal, tnt = fallbackPalette, fallbackTints
        if equipped and equipped['shirts_full'] then
            local d = equipped['shirts_full']
            pal = d.palette or d._p or pal
            tnt = d.tints or d._tints or tnt
        end
        pal = pal or 'tint_generic_clean'
        tnt = tnt or {0, 0, 0}
            -- Request Debug Info for testing - what happens with load character checking what's wrong with debugging Loading Here,
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, shirtHash)
        Wait(80)
        SetPedComponentVariation(ped, shirtHash, variation)
            -- what is kaf_bulletproof: 0xCC8CA3E88256E58F for debugging (0,1,1,1,false) - checks what is wrong with testing?
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)
        if ApplyClothingColor then ApplyClothingColor(ped, 'shirts_full', pal, tnt) end
            -- what is Debugging Info Test - checking any discrepancies (testing differences)
        ReapplyVestOverShirt(ped)
        if ApplyClothingColor then
            local v = ClothesCache and (ClothesCache['vests'] or ClothesCache['corsets'])
            if v and v.palette and v.tints then ApplyClothingColor(ped, v == ClothesCache['vests'] and 'vests' or 'corsets', v.palette, v.tints) end
        end
        if ped == PlayerPedId() then
            SetTimeout(120, function()
                TriggerEvent('shiw-tattoos:client:afterPedVariation')
                TriggerEvent('rsg-appearance:client:afterPedVariation')
            end)
        end
        TriggerEvent('rsg-appearance:client:clothingVariationChanged')
        SetTimeout(650, function()
            TriggerEvent('rsg-appearance:client:clothingVariationSettled')
        end)
    end)

    -- Temporary Debug Info
    local message = ClothingModState.sleeves_rolled and 'Debugging Info On' or 'Debugging Info Off'
    TriggerEvent('ox_lib:notify', {
        title = 'Debug Title',
        description = message,
        type = 'success'
    })
    
    print('[Clothing] Sleeves toggled: ' .. variation .. ' for hash: 0x' .. string.format("%X", shirtHash))
    -- Note: Debugging Query on sleeves, what is noted here?
    SetTimeout(80, function()
        pcall(function() exports['shiw-tattoos']:ReapplyTattoo() end)
    end)
end

-- ==========================================
    -- Temporary uses hash (testing 2 - formatting for debugging)
-- ==========================================
function ToggleSleevesOpen()
    local ped = PlayerPedId()
    local shirtHash = GetCurrentShirtHash()
    
    if not shirtHash or shirtHash == 0 then
        TriggerEvent('ox_lib:notify', {
            title = 'Debug Title',
            description = 'Debugging Description Here',
            type = 'error'
        })
        return
    end
    
    -- Temporary controls debugging validation checks
    ClothingModState.sleeves_rolled = false
    
    -- Temporary debugging
    ClothingModState.sleeves_rolled_open = not ClothingModState.sleeves_rolled_open
    
    -- Temporary Debugging
    PlayClothingModAnimation('sleeves')
    Wait(500)
    
    local variation = ClothingModState.sleeves_rolled_open 
        and ClothingVariations.shirts.rolled_open 
        or ClothingVariations.shirts.base
    
    local fallbackPalette = ClothesCache and ClothesCache['shirts_full'] and ClothesCache['shirts_full'].palette
    local fallbackTints = ClothesCache and ClothesCache['shirts_full'] and ClothesCache['shirts_full'].tints
    RSGCore.Functions.TriggerCallback('rsg-clothing:server:getEquippedClothing', function(equipped)
        local pal, tnt = fallbackPalette, fallbackTints
        if equipped and equipped['shirts_full'] then
            local d = equipped['shirts_full']
            pal = d.palette or d._p or pal
            tnt = d.tints or d._tints or tnt
        end
        pal = pal or 'tint_generic_clean'
        tnt = tnt or {0, 0, 0}
            -- Request Debug Info for testing - what happens with load character checking what's wrong with debugging Loading Here,
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, shirtHash)
        Wait(80)
        SetPedComponentVariation(ped, shirtHash, variation)
            -- what is kaf_bulletproof: 0xCC8CA3E88256E58F for debugging (0,1,1,1,false) - checks what is wrong with testing?
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)
        if ApplyClothingColor then ApplyClothingColor(ped, 'shirts_full', pal, tnt) end
            -- what is Debugging Info Test - checking any discrepancies (testing differences)
        ReapplyVestOverShirt(ped)
        if ApplyClothingColor then
            local v = ClothesCache and (ClothesCache['vests'] or ClothesCache['corsets'])
            if v and v.palette and v.tints then ApplyClothingColor(ped, v == ClothesCache['vests'] and 'vests' or 'corsets', v.palette, v.tints) end
        end
        if ped == PlayerPedId() then
            SetTimeout(120, function()
                TriggerEvent('shiw-tattoos:client:afterPedVariation')
                TriggerEvent('rsg-appearance:client:afterPedVariation')
            end)
        end
        TriggerEvent('rsg-appearance:client:clothingVariationChanged')
        SetTimeout(650, function()
            TriggerEvent('rsg-appearance:client:clothingVariationSettled')
        end)
    end)

    -- Temporary Debug Info
    local message = ClothingModState.sleeves_rolled_open and 'Debugging Info Open, Debug Message Here' or 'Debugging Info Close, Debug Message Here'
    TriggerEvent('ox_lib:notify', {
        title = 'Debug Title',
        description = message,
        type = 'success'
    })
    SetTimeout(80, function()
        pcall(function() exports['shiw-tattoos']:ReapplyTattoo() end)
    end)
end

-- ==========================================
    -- Temporary (Testing)
-- ==========================================
function ToggleCollar()
    local ped = PlayerPedId()
    local shirtHash = GetCurrentShirtHash()
    
    if not shirtHash or shirtHash == 0 then
        TriggerEvent('ox_lib:notify', {
            title = 'Debug Title',
            description = 'Debugging Description Here',
            type = 'error'
        })
        return
    end
    
    -- Temporary Info in Debugging
    local savedPalette = nil
    local savedTints = nil
    if ClothesCache and ClothesCache['shirts_full'] then
        savedPalette = ClothesCache['shirts_full'].palette
        savedTints = ClothesCache['shirts_full'].tints
    end
    
    -- More details in debugging - what debugging info for testing?
    if ClothingModState.sleeves_rolled then
            -- Temporary looking at what testing debugging here
        ClothingModState.sleeves_rolled = false
        ClothingModState.sleeves_rolled_open = true
        
        PlayClothingModAnimation('collar')
        Wait(500)
        
        SetPedComponentVariation(ped, shirtHash, ClothingVariations.shirts.rolled_open)
        UpdatePedVariation(ped, { skipBodyMorph = true, skipFinalize = true })
        
            -- Temporary debugging!
        if savedPalette and savedTints then
            Wait(100)
            ApplyClothingColor(ped, 'shirts_full', savedPalette, savedTints)
        end
        TriggerEvent('rsg-appearance:client:clothingVariationChanged')
        SetTimeout(650, function()
            TriggerEvent('rsg-appearance:client:clothingVariationSettled')
        end)
            -- what is debugging requestModifierReapply - checking UpdatePedVariation how it works in testing?
        
        TriggerEvent('ox_lib:notify', {
            title = 'Debug Title',
            description = 'Debugging Message Here',
            type = 'success'
        })
        SetTimeout(80, function()
            pcall(function() exports['shiw-tattoos']:ReapplyTattoo() end)
        end)
    elseif ClothingModState.sleeves_rolled_open then
            -- debugging what is happening here
        ClothingModState.sleeves_rolled_open = false
        ClothingModState.sleeves_rolled = true
        
        PlayClothingModAnimation('collar')
        Wait(500)
        
        SetPedComponentVariation(ped, shirtHash, ClothingVariations.shirts.rolled_closed)
        UpdatePedVariation(ped, { skipBodyMorph = true, skipFinalize = true })
        
            -- debugging here!
        if savedPalette and savedTints then
            Wait(100)
            ApplyClothingColor(ped, 'shirts_full', savedPalette, savedTints)
        end
        TriggerEvent('rsg-appearance:client:clothingVariationChanged')
        SetTimeout(650, function()
            TriggerEvent('rsg-appearance:client:clothingVariationSettled')
        end)
            -- what is requestModifierReapply checking UpdatePedVariation how this works?
        
        TriggerEvent('ox_lib:notify', {
            title = 'Debug Title',
            description = 'Debugging Message Here',
            type = 'success'
        })
        SetTimeout(80, function()
            pcall(function() exports['shiw-tattoos']:ReapplyTattoo() end)
        end)
    else
            -- Title for update info - debugging validation
        TriggerEvent('ox_lib:notify', {
            title = 'Debug Title',
            description = 'Debugging Info Message (checking what about /sleeves or /sleeves2)',
            type = 'info'
        })
    end
end

-- ==========================================
    -- Debugging v4.0 (what is debugging: testing neckwear)
-- ==========================================

    -- Temporary checks for testing here
local BANDANA_ON_VARIATION = GetHashKey("BANDANA_ON_RIGHT_HAND")
local BANDANA_OFF_VARIATION = GetHashKey("BANDANA_OFF_RIGHT_HAND")
    local BANDANA_ON_COMPONENT = -1829635046  -- Temporary items: debugging what is on?
    local BANDANA_BASE_COMPONENT = GetHashKey("base") -- Temporary items: debugging what are materials?

local NECKWEAR_META_CATEGORY_FP = 0x5FC29285
local BANDANA_DRAWABLE_SLOT_FP = 0x7505EF42
local appearanceFpBandanaStripSession = false

local function RsgHideBandanaFpEnabled()
    return RSG and RSG.HideBandanaMeshInFirstPerson == true
end

local N_RSG_FP_FULL = 0xD1BA66940E94C547 -- _IS_IN_FULL_FIRST_PERSON_MODE
local N_RSG_GET_FOLLOW_MODE = 0x8D4D46230B2C353A -- GET_FOLLOW_PED_CAM_VIEW_MODE
local N_RSG_GET_FOLLOW_MODE_LEGACY = 0x8D4D46230B92C8A7

local function RsgFollowModeIsFp(mode)
    if mode == nil then return false end
    local list = RSG and RSG.FirstPersonCamViewModes
    if type(list) == 'table' and #list > 0 then
        for _, m in ipairs(list) do
            if tonumber(mode) == tonumber(m) then return true end
        end
        return false
    end
    return tonumber(mode) == 4
end

local function RsgIsFollowCamFirstPerson()
    local ok, v = pcall(function()
        return Citizen.InvokeNative(N_RSG_FP_FULL)
    end)
    if ok and v and v ~= 0 then
        return true
    end

    local mode
    ok = pcall(function()
        if type(GetFollowPedCamViewMode) == 'function' then
            mode = tonumber(GetFollowPedCamViewMode())
        end
    end)
    if ok and RsgFollowModeIsFp(mode) then
        return true
    end

    for _, hash in ipairs({ N_RSG_GET_FOLLOW_MODE, N_RSG_GET_FOLLOW_MODE_LEGACY }) do
        ok, mode = pcall(function()
            return tonumber(Citizen.InvokeNative(hash))
        end)
        if ok and RsgFollowModeIsFp(mode) then
            return true
        end
    end

    if type(GetCamViewModeForContext) == 'function' then
        for ctx = 0, 8 do
            ok, mode = pcall(function()
                return tonumber(GetCamViewModeForContext(ctx))
            end)
            if ok and RsgFollowModeIsFp(mode) then
                return true
            end
        end
    end

    return false
end

local function RsgStripNeckwearForFp(ped)
    if not ped or ped == 0 then return end
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, NECKWEAR_META_CATEGORY_FP, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, BANDANA_DRAWABLE_SLOT_FP, 0)
    pcall(function()
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey('masks'), 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey('neckwear'), 0)
    end)
    pcall(function()
        Citizen.InvokeNative(0x704C908E9C405136, ped)
    end)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

local function RsgRestoreBandanaUpVisual(ped)
    if not ped or ped == 0 then return end
    if not ClothingModState.bandana_up then return end
    local nh = ClothingModState.saved_neckwear_hash or GetCurrentNeckwearHash()
    if not nh or nh == 0 then return end
    Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, tonumber(nh), BANDANA_ON_COMPONENT, 0, true, 1)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

function ToggleBandana()
    local ped = PlayerPedId()
    local neckwearHash = GetCurrentNeckwearHash()

    if not neckwearHash or neckwearHash == 0 then
        TriggerEvent('ox_lib:notify', {
            title = 'Debug Title',
            description = 'Debugging Description Here/Testing',
            type = 'error'
        })
        return
    end

    -- Temporary debugging site
    ClothingModState.bandana_up = not ClothingModState.bandana_up

    if ClothingModState.bandana_up then
        -- ========== Debugging Notes ==========
        ClothingModState.saved_neckwear_hash = neckwearHash

        -- Temporary debugging input (what is about neckwear - some debugging)
        Citizen.InvokeNative(0xAE72E7DF013AAA61, ped, tonumber(neckwearHash), BANDANA_ON_VARIATION, 1, 0, -1082130432)
        Wait(700)

        -- Temporary debugging "What is happening here" ? but on neckwear
        Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, tonumber(neckwearHash), BANDANA_ON_COMPONENT, 0, true, 1)

        -- Temporary debugging notes
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        if RsgHideBandanaFpEnabled() and RsgIsFollowCamFirstPerson() then
            RsgStripNeckwearForFp(ped)
            appearanceFpBandanaStripSession = true
        else
            appearanceFpBandanaStripSession = false
        end
    else
        appearanceFpBandanaStripSession = false
        -- ========== Debugging Notes ==========
        local originalHash = ClothingModState.saved_neckwear_hash or neckwearHash

        -- Temporary hashes
        Citizen.InvokeNative(0xAE72E7DF013AAA61, ped, tonumber(originalHash), BANDANA_OFF_VARIATION, 1, 0, -1082130432)
        Wait(700)

        -- Check if there are temporary neckwear
        Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, tonumber(originalHash), BANDANA_BASE_COMPONENT, 0, true, 1)

        -- Temporary notes
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)

        -- Temporary looking at neckwear here
        Wait(100)
        if ClothesCache and ClothesCache['neckwear'] then
            local savedPalette = ClothesCache['neckwear'].palette
            local savedTints = ClothesCache['neckwear'].tints
            if savedPalette and savedTints then
                ApplyClothingColor(ped, 'neckwear', savedPalette, savedTints)
            end
        end

        ClothingModState.saved_neckwear_hash = nil
    end

    SetTimeout(650, function()
        TriggerEvent('rsg-appearance:client:requestModifierReapply')
    end)

    -- Attention
    local message = ClothingModState.bandana_up and 'wearing bandana' or 'taking off bandana'
    TriggerEvent('ox_lib:notify', {
        title = 'new title',
        description = message,
        type = 'success'
    })
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ClothingModState.bandana_up and RsgHideBandanaFpEnabled() and ped ~= 0 then
            local fp = RsgIsFollowCamFirstPerson()
            if fp then
                RsgStripNeckwearForFp(ped)
                appearanceFpBandanaStripSession = true
                Wait(0)
            else
                if appearanceFpBandanaStripSession then
                    RsgRestoreBandanaUpVisual(ped)
                    if ClothesCache and ClothesCache['neckwear'] then
                        local savedPalette = ClothesCache['neckwear'].palette
                        local savedTints = ClothesCache['neckwear'].tints
                        if savedPalette and savedTints then
                            ApplyClothingColor(ped, 'neckwear', savedPalette, savedTints)
                        end
                    end
                    appearanceFpBandanaStripSession = false
                end
                Wait(50)
            end
        else
            if appearanceFpBandanaStripSession and ped ~= 0 then
                RsgRestoreBandanaUpVisual(ped)
                appearanceFpBandanaStripSession = false
            end
            Wait(200)
        end
    end
end)

-- ==========================================
-- Attention
-- ==========================================
function PlayClothingModAnimation(animType)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    local dict, anim, duration
    
    if animType == 'sleeves' then
        dict = 'script_proc@town@tailor@shop_owner'
        anim = 'measure_arm_tailor'
        duration = 1500
    elseif animType == 'collar' then
        dict = 'amb_misc@world_human_lean_fence_inspect@leaningalt@male_a@idle_c'
        anim = 'idle_d'
        duration = 1000
    else
        return
    end
    
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end
    
    if HasAnimDictLoaded(dict) then
        if not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) then
            TaskPlayAnim(ped, dict, anim, 4.0, -4.0, duration, 49, 0, false, false, false)
        end
    end
end

-- ==========================================
-- After making this change, make sure everything works
-- ==========================================
function ResetClothingModState(category)
    if category == 'shirts_full' then
        ClothingModState.sleeves_rolled = false
        ClothingModState.sleeves_rolled_open = false
    elseif category == 'neckwear' then
        ClothingModState.bandana_up = false
        appearanceFpBandanaStripSession = false
    end
end

local function RestorePlayerVisibilitySafe()
    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return end
    if IsInCharCreation then return end
    -- ? FIX: Can someone tell me why this works?
    if IsEntityVisible(ped) and GetEntityAlpha(ped) >= 255 then return end

    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
end

-- How to comment properly
RegisterNetEvent('rsg-clothing:client:removeClothing')
AddEventHandler('rsg-clothing:client:removeClothing', function(category)
    ResetClothingModState(category)
end)

-- Use loadcharacter function for correctly reloading from/directory (there is likely some optimal way). You can find contribution here.
local _lastLoadCoatEquipPass = 0
local function ReapplyCoatsAfterLoadViaEquipPath()
    local now = GetGameTimer()
    if (now - (_lastLoadCoatEquipPass or 0)) < 1200 then
        return
    end
    _lastLoadCoatEquipPass = now

    RSGCore.Functions.TriggerCallback('rsg-clothing:server:getEquippedClothing', function(equippedItems)
        if not equippedItems then return end
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end

        -- Note: asking of this, how is someone able (equipClothing),
        -- Notes indicate the visual update applied/tint flow of loadcharacter.
        for _, cat in ipairs({'coats', 'coats_closed'}) do
            local item = equippedItems[cat]
            if item and type(item) == 'table' then
                local payload = {}
                for k, v in pairs(item) do payload[k] = v end
                payload.category = cat
                TriggerEvent('rsg-clothing:client:equipClothing', payload)
                Wait(120)
            end
        end
    end)
end

AddEventHandler('rsg-appearance:client:ApplySkinComplete', function()
    ResetClothingModState('shirts_full')
    ResetClothingModState('neckwear')

    -- ? includes description+author documentation of LoadClothingFromInventory - allows various additional changes, if unexpected

    -- Safety fix: use loadskin/update properly within correct boundaries (loading/unloading)
    -- Important updates here. Do not let players use visual, any future changes
    -- ? FIX: expecting defaults (300, 900, 2000, 4500) - bug fixes applied. RestorePlayerVisibilitySafe requires visual attention.
    RestorePlayerVisibilitySafe()
    SetTimeout(300, RestorePlayerVisibilitySafe)

    -- Coat color fix after loadcharacter:
    -- Many in this genre, any unexpected changes, and documentation changes
    -- Set Ped variation/update to character model.
    SetTimeout(700, ReapplyCoatsAfterLoadViaEquipPath)
    SetTimeout(1700, ReapplyCoatsAfterLoadViaEquipPath)
    -- FIX: Vest/corset model mismatch - incompatible with version 1.2 (check how to properly load character)
    SetTimeout(1200, function()
        local p = PlayerPedId()
        if not p or not DoesEntityExist(p) then return end
        if not IsPedMale(p) and ClothesCache then
            local vest = ClothesCache['vests'] or ClothesCache['corsets']
            if vest and vest.hash and vest.hash ~= 0 and not (ClothesCache['shirts_full'] and ClothesCache['shirts_full'].hash and ClothesCache['shirts_full'].hash ~= 0) then
                if EnsureBodyIntegrity then EnsureBodyIntegrity(p, true) end
                Wait(80)
                NativeSetPedComponentEnabledClothes(p, vest.hash, false, true, true)
                Citizen.InvokeNative(0x704C908E9C405136, p)
                if NativeUpdatePedVariation then NativeUpdatePedVariation(p, true) end
                -- To update PedVariation the model should be compatible with the current installed version - we have incompatible model versions
                Wait(40)
                NativeSetPedComponentEnabledClothes(p, vest.hash, false, true, true)
                if NativeUpdatePedVariationClothes then NativeUpdatePedVariationClothes(p) end
            end
        end
    end)
    -- Notice: requestModifierReapply has 3.5? issues ApplyAllSavedColors on naked body
    -- ReapplyCoatsAfterLoadViaEquipPath seems like incompatible equip for ApplyClothingColor
    -- SetTimeout(3500, function() TriggerEvent('rsg-appearance:client:requestModifierReapply') end)
end)

-- ==========================================
-- Loading
-- ==========================================
RegisterDebugCommand('sleeves', function()
    ToggleSleeves()
end, false)

RegisterDebugCommand('sleeves2', function()
    ToggleSleevesOpen()
end, false)

RegisterDebugCommand('collar', function()
    ToggleCollar()
end, false)

RegisterDebugCommand('bandana', function()
    ToggleBandana()
end, false)

-- ==========================================
-- DEBUG
-- ==========================================
RegisterDebugCommand('clothstate', function()
    print('=== CLOTHING MOD STATE ===')
    print('Sleeves rolled (closed): ' .. tostring(ClothingModState.sleeves_rolled))
    print('Sleeves rolled (open): ' .. tostring(ClothingModState.sleeves_rolled_open))
    print('Bandana up: ' .. tostring(ClothingModState.bandana_up))
    print('')
    print('Shirt hash: ' .. tostring(GetCurrentShirtHash()))
    print('Neckwear hash: ' .. tostring(GetCurrentNeckwearHash()))
end, false)

print('[RSG-Clothing] Sleeves/Collar/Bandana system loaded')
RegisterDebugCommand('debugcache', function()
    print('=== CLOTHES CACHE DEBUG ===')
    
    if not ClothesCache then
        print('ClothesCache is nil!')
        return
    end
    
    if next(ClothesCache) == nil then
        print('ClothesCache is EMPTY!')
        return
    end
    
    for category, data in pairs(ClothesCache) do
        if type(data) == 'table' then
            print(category .. ':')
            print('  hash: ' .. tostring(data.hash))
            print('  model: ' .. tostring(data.model))
            print('  texture: ' .. tostring(data.texture))
        else
            print(category .. ': ' .. tostring(data))
        end
    end
end, false)
-- GetCurrentShirtHash / GetCurrentNeckwearHash - provides current items, check if users have loaded this (check ClothesCache)
-- callback rsg-clothing:server:getEquippedClothingSync to sync - check rsg-clothing compatibility
function PlayClothingModAnimation()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    -- Compatibility check for character model
    local dict = 'mech_loco_m@character@arthur@fidgets@hat@normal@unarmed@normal@left_hand'
    local anim = 'hat_lhand_b'
    
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end
    
    if HasAnimDictLoaded(dict) then
        if not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) then
            TaskPlayAnim(ped, dict, anim, 4.0, -4.0, 1500, 51, 0, false, false, false)
        end
    end
end
-- ==========================================
-- What model to load (default)
-- ==========================================

RegisterNetEvent('rsg-clothing:client:openRepairMenu', function()
    RSGCore.Functions.TriggerCallback('rsg-clothing:server:getClothingForRepair', function(clothingList)
        if not clothingList or #clothingList == 0 then
            lib.notify({
                title = 'Character',
                description = 'I do not know what is wrong, need to check error in custom',
                type = 'info'
            })
            return
        end
        
        local menuOptions = {}
        
        for _, item in ipairs(clothingList) do
            local color = 'green'
            local icon = '✅'
            
            if item.durability < 20 then
                color = 'red'
                icon = '❌'
            elseif item.durability < 40 then
                color = 'orange'
                icon = '⚠️'
            elseif item.durability < 60 then
                color = 'yellow'
                icon = '👍'
            end
            
            local statusText = item.equipped and ' (equipped)' or ''
            
            table.insert(menuOptions, {
                title = icon .. ' ' .. item.label,
                description = 'Durability: ' .. item.durability .. '%' .. statusText .. '\nHealth status: 100% (1 active model)',
                metadata = {
                    {label = 'Durability percentage', value = item.durability .. '%'},
                    {label = 'Health status', value = '100%'},
                    {label = 'Equipped', value = item.equipped and 'Yes' or 'No'}
                },
                onSelect = function()
                    -- Compatibility check
                    if lib.progressBar({
                        duration = 5000,
                        label = 'Item ' .. item.label .. '...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = {
                            car = true,
                            combat = true,
                            move = true
                        },
                        anim = {
                            dict = 'mini_games@story@mud4@repair',
                            clip = 'Mud4_Repair_Player',
                            flags = 1
                        }
                    }) then
                        -- Model mismatch
                        TriggerServerEvent('rsg-clothing:server:repairClothing', item.slot)
                    else
                        -- Unknown  
                        lib.notify({
                            title = 'Unknown',  
                            description = 'Unknown Request',  
                            type = 'error'
                        })
                    end
                end,
                serverEvent = false
            })
        end
        
        -- Showing error message  
        table.insert(menuOptions, {
            title = 'Unknown',  
            description = 'Unknown New Request',  
            onSelect = function()
                lib.hideContext()
            end
        })
        
        lib.registerContext({
            id = 'clothing_repair_menu',
            title = 'Unknown new request',  
            options = menuOptions
        })
        
        lib.showContext('clothing_repair_menu')
    end)
end)
-- ==========================================
-- Unknown  
-- ==========================================

RegisterDebugCommand('sleeves', function()
    ToggleSleeves()
end, false)

RegisterDebugCommand('collar', function()
    ToggleCollar()
end, false)

-- ==========================================
-- DEBUG Unknown  
-- ==========================================

RegisterDebugCommand('shirtinfo', function()
    local model, texture = GetCurrentShirtData()
    local hash = 0
    
    if ClothesCache and ClothesCache['shirts_full'] and ClothesCache['shirts_full'].hash then
        hash = ClothesCache['shirts_full'].hash
    end
    
    if model and model > 0 then
        local isMale = IsPedMale(PlayerPedId())
        print('=== SHIRT INFO ===')
        print('Gender: ' .. (isMale and 'male' or 'female'))
        print('Model: ' .. tostring(model))
        print('Texture: ' .. tostring(texture or 1))
        print('Hash: 0x' .. string.format("%X", hash or 0))
        
        -- Showing file in other formats  
        local gender = isMale and 'male' or 'female'
        local hasSleeves = ShirtSleevesMap[gender] and ShirtSleevesMap[gender][model]
        print('Sleeves pair: ' .. tostring(hasSleeves or 'none'))
        
        TriggerEvent('ox_lib:notify', {
            title = 'Unknown',  
            description = 'Unknown: ' .. model .. ' | Unknown: ' .. (hasSleeves and 'Yes' or 'No'),  
            type = 'info'
        })
    else
        print('No shirt equipped')
        TriggerEvent('ox_lib:notify', {
            title = 'Unknown',  
            description = 'Unknown in Unknown',  
            type = 'error'
        })
    end
end, false)

RegisterDebugCommand('testshirt', function(source, args)
    if not args[1] then
        print('Usage: /testshirt [model] [texture]')
        return
    end
    
    local ped = PlayerPedId()
    local isMale = IsPedMale(ped)
    local gender = isMale and "male" or "female"
    local model = tonumber(args[1])
    local texture = tonumber(args[2]) or 1
    
    if not model then
        print('Invalid model number')
        return
    end
    
    if not clothing or not clothing[gender] or not clothing[gender]['shirts_full'] then
        print('Clothing data not found')
        return
    end
    
    local clothingData = clothing[gender]['shirts_full']
    
    if not clothingData[model] then
        print('Model ' .. model .. ' not found for ' .. gender)
        
        -- Changing Unknown response message  
        local available = {}
        for m in pairs(clothingData) do
            table.insert(available, m)
        end
        table.sort(available)
        print('Available models (first 20):')
        for i = 1, math.min(20, #available) do
            print('  ' .. available[i])
        end
        return
    end
    
    if not clothingData[model][texture] then
        print('Texture ' .. texture .. ' not found, trying texture 1')
        texture = 1
        if not clothingData[model][texture] then
            -- What are these errors?  
            for t in pairs(clothingData[model]) do
                texture = t
                break
            end
        end
    end
    
    if not clothingData[model][texture] then
        print('No valid texture found')
        return
    end
    
    local hash = clothingData[model][texture].hash
    
    if not hash or hash == 0 then
        print('Invalid hash')
        return
    end
    
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey("shirts_full"), 0)
    Wait(100)
    NativeSetPedComponentEnabledClothes(ped, hash, false, true, true)
    NativeUpdatePedVariation(ped, true)
    
    ClothesCache['shirts_full'] = {
        model = model,
        texture = texture,
        hash = hash
    }
    
    print('Applied shirt model: ' .. model .. ' texture: ' .. texture .. ' hash: 0x' .. string.format("%X", hash))
    TriggerEvent('ox_lib:notify', {
        title = 'Unknown Request',  
        description = 'Unknown: ' .. model,  
        type = 'success'
    })
end, false)

RegisterDebugCommand('listshirts', function()
    local ped = PlayerPedId()
    local isMale = IsPedMale(ped)
    local gender = isMale and "male" or "female"
    
    if not clothing or not clothing[gender] or not clothing[gender]['shirts_full'] then
        print('No shirts found')
        return
    end
    
    local clothingData = clothing[gender]['shirts_full']
    
    print('=== AVAILABLE SHIRT MODELS (' .. gender .. ') ===')
    local models = {}
    for model in pairs(clothingData) do
        table.insert(models, model)
    end
    table.sort(models)
    
    for _, model in ipairs(models) do
        local textureCount = 0
        for _ in pairs(clothingData[model]) do textureCount = textureCount + 1 end
        local hasSleeves = ShirtSleevesMap[gender] and ShirtSleevesMap[gender][model] and 'YES' or 'no'
        print('Model ' .. model .. ': ' .. textureCount .. ' textures, sleeves: ' .. hasSleeves)
    end
    print('Total: ' .. #models .. ' models')
end, false)

print('[RSG-Clothing] Sleeves/Collar commands loaded')
-- ==========================================
-- Unknown Unknown request  
-- ==========================================

-- Unknown in clothing_item  
function IsClothingItem(itemName)
    local clothingItems = {
        'clothing_item',
        'clothing_hats',
        'clothing_shirts_full',
        'clothing_pants',
        'clothing_boots',
        'clothing_vests',
        'clothing_coats',
        'clothing_coats_closed',
        'clothing_gloves',
        'clothing_neckwear',
        'clothing_masks',
        'clothing_eyewear',
        'clothing_gunbelts',
        'clothing_satchels',
        'clothing_skirts',
        'clothing_chaps',
        'clothing_spurs',
        'clothing_rings_rh',
        'clothing_rings_lh',
        'clothing_suspenders',
        'clothing_belts',
        'clothing_cloaks',
        'clothing_ponchos',
        'clothing_gauntlets',
        'clothing_neckties',
        'clothing_holsters_knife',
        'clothing_loadouts',
        'clothing_holsters_left',
        'clothing_holsters_right',
        'clothing_holsters_crossdraw',
        'clothing_aprons',
        'clothing_boot_accessories',
        'clothing_spats',
        'clothing_jewelry_rings_right',
        'clothing_jewelry_rings_left',
        'clothing_jewelry_bracelets',
        'clothing_talisman_holster',
        'clothing_talisman_wrist',
        'clothing_belt_buckles',
        'clothing_bows',
        'clothing_hair_accessories',
        'clothing_dresses',
        'clothing_earrings',
        'clothing_armor',
    }
    
    for _, item in ipairs(clothingItems) do
        if itemName == item then
            return true
        end
    end
    return false
end

-- What is the work of the core (QBCore/RSGCore)  
RegisterNetEvent('QBCore:Player:SetPlayerData', function(playerData)
    if not UseClothingInventory then return end
    CreateThread(function()
        Wait(500) -- Why do we need to perform a wait?  
        TriggerServerEvent('rsg-clothing:server:checkInventorySync')
    end)
end)

RegisterNetEvent('RSGCore:Player:SetPlayerData', function(playerData)
    if not UseClothingInventory then return end
    CreateThread(function()
        Wait(500)
        TriggerServerEvent('rsg-clothing:server:checkInventorySync')
    end)
end)

-- What about rsg-inventory (plugin) - How does the inventory work?  
RegisterNetEvent('rsg-inventory:client:ItemBox', function(itemData, type)
    if not UseClothingInventory then return end
    if type == "remove" and itemData and itemData.name then
        if IsClothingItem(itemData.name) then
            print('[RSG-Clothing] Item removed: ' .. itemData.name)
            CreateThread(function()
                Wait(100)
                TriggerServerEvent('rsg-clothing:server:checkInventorySync')
            end)
        end
    end
end)

-- What about ox_inventory (which is an extension)  
RegisterNetEvent('ox_inventory:updateInventory', function(changes)
    if not UseClothingInventory then return end
    local needCheck = false
    
    if changes then
        for _, change in ipairs(changes) do
            if change and change.name and IsClothingItem(change.name) then
                needCheck = true
                break
            end
        end
    end
    
    if needCheck then
        CreateThread(function()
            Wait(100)
            TriggerServerEvent('rsg-clothing:server:checkInventorySync')
        end)
    end
end)

-- What about the implementation logs?  
RegisterNetEvent('inventory:client:ItemDropped', function(item)
    if not UseClothingInventory then return end
    if item and item.name and IsClothingItem(item.name) then
        print('[RSG-Clothing] Item dropped: ' .. item.name)
        CreateThread(function()
            Wait(100)
            TriggerServerEvent('rsg-clothing:server:checkInventorySync')
        end)
    end
end)

-- The implementation needs to be debugged urgently  
RegisterNetEvent('inventory:refresh', function()
    if not UseClothingInventory then return end
    CreateThread(function()
        Wait(250)
        TriggerServerEvent('rsg-clothing:server:checkInventorySync')
    end)
end)

-- Debugging information is needed  
RegisterDebugCommand('debugclothes', function()
    print('=== CLOTHES CACHE (CLIENT) ===')
    for category, data in pairs(ClothesCache) do
        print(category, json.encode(data))
    end
end, false)

-- Problems with the plugin can occur  
RegisterDebugCommand('checkclothes', function()
    TriggerServerEvent('rsg-clothing:server:checkInventorySync')
    TriggerEvent('ox_lib:notify', {
        title = 'Title',  
        description = 'Description of the description...',  
        type = 'info'
    })
end, false)

print('[RSG-Clothing] Inventory hooks registered')


function MenuUpdateClothes(data, menu)
    if data.current.change_type == "model" then
        if ClothesCache[data.current.category].model ~= data.current.value then
            ClothesCache[data.current.category].texture = 1
            ClothesCache[data.current.category].model = data.current.value
            if data.current.value > 0 then
                menu.setElement(data.current.id + 1, "max", GetMaxTexturesForModel(data.current.category, data.current.value, true))
                menu.setElement(data.current.id + 1, "min", 1)
                menu.setElement(data.current.id + 1, "value", 1)
                menu.refresh()
                Change(data.current.value, data.current.category, data.current.change_type)
            else
                if data.current.category == 'cloaks' then
                    data.current.category = 'ponchos'
                end
                Citizen.InvokeNative(0xD710A5007C2AC539, PlayerPedId(), GetHashKey(data.current.category), 0)
                NativeUpdatePedVariation(PlayerPedId(), true)
				SetTimeout(300, function()
					pcall(function()
					exports['rsg-appearance']:CheckAndApplyNakedBodyIfNeeded(PlayerPedId())
					end)
				end)
                menu.setElement(data.current.id + 1, "max", 0)
                menu.setElement(data.current.id + 1, "min", 0)
                menu.setElement(data.current.id + 1, "value", 0)
                menu.refresh()
            end
            -- In case I forget this  
            if not (IsInCharCreation or Skinkosong) then
                CurrentPrice = CalculatePrice(ClothesCache, OldClothesCache, IsPedMale(PlayerPedId()))
            end
        end
    end
    if data.current.change_type == "texture" then
        if ClothesCache[data.current.category].texture ~= data.current.value then
            ClothesCache[data.current.category].texture = data.current.value
            Change(data.current.value, data.current.category, data.current.change_type)
            -- In case I forget this  
            if not (IsInCharCreation or Skinkosong) then
                CurrentPrice = CalculatePrice(ClothesCache, OldClothesCache, IsPedMale(PlayerPedId()))
            end
        end
    end
end
-- ==========================================
-- Let's go (request + response)  
-- ==========================================

function CalculatePrice(newClothes, oldClothes, isMale)
    local totalPrice = 0
    
    if not newClothes then return 0 end
    if not oldClothes then oldClothes = {} end
    if not RSG or not RSG.Price then return 0 end
    
    for category, newData in pairs(newClothes) do
        if type(newData) == "table" then
            local newModel = newData.model
            local newTexture = newData.texture or 1
            
            -- The request should return 0 or nil  
            if not newModel or newModel < 1 then
                goto continue
            end
            
            local oldData = oldClothes[category]
            local isNewItem = false
            
            if not oldData or type(oldData) ~= "table" then
                isNewItem = true
            elseif not oldData.model or oldData.model < 1 then
                isNewItem = true
            elseif newModel ~= oldData.model then
                isNewItem = true
            elseif newTexture ~= (oldData.texture or 1) then
                isNewItem = true
            end
            
            if isNewItem then
                local itemPrice = nil
                
                -- It would be better if you add something like this?  
                if RSG.ItemPrices and RSG.ItemPrices[category] and RSG.ItemPrices[category][newModel] then
                    itemPrice = RSG.ItemPrices[category][newModel][newTexture]
                end
                
                -- What if I want to delay the response?  
                if not itemPrice then
                    itemPrice = RSG.Price[category] or 5
                end
                
                totalPrice = totalPrice + itemPrice
            end
            
            ::continue::
        end
    end
    
    return totalPrice
end

function ConvertCacheToHash(cache)
    if not cache then 
        return {} 
    end
    
    local result = {}
    for category, data in pairs(cache) do
        if type(data) == "table" then
            -- The plugin will crash  
            result[category] = {
                hash = data.hash or 0,
                model = data.model or 0,
                texture = data.texture or 1
            }
        end
    end
    return result
end


function Change(id, category, change_type)
    local ped = PlayerPedId()
    local isMale = IsPedMale(ped)
    local gender = isMale and "male" or "female"
    
    -- Process your operational information  
    if ConflictingCategories[category] then
        local conflictCategory = ConflictingCategories[category]
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, GetHashKey(conflictCategory), 0)
        
        if ClothesCache[conflictCategory] then
            ClothesCache[conflictCategory].model = 0
            ClothesCache[conflictCategory].texture = 1
            ClothesCache[conflictCategory].hash = 0
        end
    end
    
    local hashToApply = nil
    
    if change_type == "model" then
        if clothing[gender][category] and clothing[gender][category][id] then
            hashToApply = clothing[gender][category][id][1].hash
            -- If everything is okay  
            ClothesCache[category] = {
                model = id,
                texture = 1,
                hash = hashToApply
            }
        end
    else
        if clothing[gender][category] and 
           ClothesCache[category] and 
           clothing[gender][category][ClothesCache[category].model] and
           clothing[gender][category][ClothesCache[category].model][id] then
            hashToApply = clothing[gender][category][ClothesCache[category].model][id].hash
            ClothesCache[category].texture = id
            ClothesCache[category].hash = hashToApply
        end
    end
    
    if hashToApply then
        -- Note: urgent operational information
        EnsureBodyIntegrity(ped, false)
        
        Wait(50)
        
        -- Model transfer method
        NativeSetPedComponentEnabledClothes(ped, hashToApply, false, true, true)
        NativeUpdatePedVariation(ped, true)
        
        -- Attempt to find
        Wait(100)
        EnsureBodyIntegrity(ped, false)
    end
end

function ClothingLight()
    while ClothingCamera do
        Wait(0)
        TogglePrompts({ "TURN_LR", "CAM_UD", "ZOOM_IO" }, true)
        if IsControlPressed(2, RSGCore.Shared.Keybinds['D']) then
            SetEntityHeading(PlayerPedId(), GetEntityHeading(PlayerPedId()) + 2)
        end
        if IsControlPressed(2, RSGCore.Shared.Keybinds['A']) then
            SetEntityHeading(PlayerPedId(), GetEntityHeading(PlayerPedId()) - 2)
        end
        if IsControlPressed(2, 0x8BDE7443) then
            if c_zoom + 0.25 < 2.5 and c_zoom + 0.25 > 0.7 then
                c_zoom = c_zoom + 0.25
                camera(c_zoom, c_offset)
            end
        end
        if IsControlPressed(2, 0x62800C92) then
            if c_zoom - 0.25 < 2.5 and c_zoom - 0.25 > 0.7 then
                c_zoom = c_zoom - 0.25
                camera(c_zoom, c_offset)
            end
        end
        if IsControlPressed(2, RSGCore.Shared.Keybinds['W']) then
            if c_offset + 0.5 / 7 < 1.2 and c_offset + 0.5 / 7 > -1.0 then
                c_offset = c_offset + 0.5 / 7
                camera(c_zoom, c_offset)
            end
        end
        if IsControlPressed(2, RSGCore.Shared.Keybinds['S']) then
            if c_offset - 0.5 / 7 < 1.2 and c_offset - 0.5 / 7 > -1.0 then
                c_offset = c_offset - 0.5 / 7
                camera(c_zoom, c_offset)
            end
        end
    end
end

-- ? FIX: Unhandled exception when trying to read the same textbox (description) - unlocked ? ??. address at text
AddEventHandler('rsg-appearance:client:ReapplyHairAccessories', function(ped)
    CreateThread(function()
        ped = ped or PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end
        if IsPedMale(ped) then return end
        if not ClothesCache or not ClothesCache['hair_accessories'] or not ClothesCache['hair_accessories'].hash or ClothesCache['hair_accessories'].hash == 0 then return end
        Wait(150) -- The next frame should be rendered
        ped = ped or PlayerPedId()
        if not DoesEntityExist(ped) then return end
        local h = ClothesCache['hair_accessories'].hash
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x79D7DF96, 0) -- Setting up the accessories
        Wait(80)
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, h)
        NativeSetPedComponentEnabledClothes(ped, h, true, true, true)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    end)
end)

local function ApplyCompleteOutfit(ClothesComponents, Target, SkinData)
    local ped = Target or PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return end

    if type(StripClothesOnly) == 'function' then
        StripClothesOnly(ped)
    end

    if ped == PlayerPedId() then
        ClothesCache = {}
        TriggerEvent('rsg-clothing:client:clothingLoaded', ClothesCache)
    end

    if type(ClothesComponents) == 'table' and next(ClothesComponents) then
        TriggerEvent('rsg-appearance:client:ApplyClothes', ClothesComponents, ped, SkinData)
    elseif ped == PlayerPedId() then
        EnsureBodyIntegrity(ped, true)
        if CheckAndApplyNakedBodyIfNeeded then
            CheckAndApplyNakedBodyIfNeeded(ped, {})
        end
        -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
        -- TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', 'outfit', false, ped)
    end
end

RegisterNetEvent('rsg-appearance:client:ApplyCompleteOutfit', ApplyCompleteOutfit)
exports('ApplyCompleteOutfit', ApplyCompleteOutfit)

RegisterNetEvent('rsg-appearance:client:ApplyClothes')
AddEventHandler('rsg-appearance:client:ApplyClothes', function(ClothesComponents, Target, SkinData)
    CreateThread(function()
        local _Target = Target or PlayerPedId()
-- ? FIX: ClothesCache - updates to clothing cache?! ??? additional data required for synchronization,
-- Retrieve the contents of inventory/item for items associated with main character models and textures.
        local isOwnPed = (_Target == PlayerPedId())
        
        print('[RSG-Clothing] ApplyClothes called' .. (isOwnPed and ' (own ped)' or ' (other player sync)'))
        print('[RSG-Clothing] ClothesComponents type: ' .. type(ClothesComponents))
        
        if type(ClothesComponents) ~= "table" or next(ClothesComponents) == nil then 
            print('[RSG-Clothing] ApplyClothes: No clothes data!')
            return 
        end
        
-- New clothing added
        for k, v in pairs(ClothesComponents) do
            if type(v) == 'table' then
                print('[RSG-Clothing] Category ' .. k .. ': hash=' .. tostring(v.hash) .. ' model=' .. tostring(v.model) .. ' texture=' .. tostring(v.texture) .. ' palette=' .. tostring(v.palette))
            else
                print('[RSG-Clothing] Category ' .. k .. ': ' .. tostring(v))
            end
        end
        
        SetEntityAlpha(_Target, 0)
        
        local isMale = IsPedMale(_Target)
        local genderKey = isMale and 'male' or 'female'
        
-- In the same: check existing models for items, output logs and documentation results
        local resolvedComponents = {}
        
        for k, v in pairs(ClothesComponents) do
            if v ~= nil and v ~= 0 then
                if type(v) ~= "table" then 
                    v = { hash = v }
                end
                
                local hashToApply = nil
                
-- Update 1: send update hash ? or 0, additional logs complete
                if v.hash and v.hash ~= 0 then
                    hashToApply = v.hash
                    print('[RSG-Clothing] Using direct hash for ' .. k .. ': ' .. tostring(hashToApply))
                    
-- Update 2: searching hash in clothing.lua for model/texture
                elseif v.model and tonumber(v.model) and tonumber(v.model) >= 1 then
                    local model = tonumber(v.model)
                    local texture = tonumber(v.texture) or 1
-- ? FIX: fetch hairstyle accessories - output = updated hairstyle model (previous data is retained for synchronization)
                    if k == 'hair_accessories' and not isMale and SkinData and SkinData.hair and type(SkinData.hair) == 'table' then
                        local hairModel = tonumber(SkinData.hair.model) or 1
                        if hairModel >= 1 and clothing[genderKey] and clothing[genderKey][k] and clothing[genderKey][k][hairModel] then
                            model = hairModel
                        end
                    end
-- New clothing for clothing category
                    if clothing[genderKey] and clothing[genderKey][k] then
                        if clothing[genderKey][k][model] then
                            if clothing[genderKey][k][model][texture] then
                                hashToApply = clothing[genderKey][k][model][texture].hash
                                print('[RSG-Clothing] Got hash from clothing[' .. genderKey .. '][' .. k .. '][' .. model .. '][' .. texture .. '] = ' .. tostring(hashToApply))
                            elseif clothing[genderKey][k][model][1] then
-- New character for category, output logs
                                hashToApply = clothing[genderKey][k][model][1].hash
                                print('[RSG-Clothing] Got hash from clothing[' .. genderKey .. '][' .. k .. '][' .. model .. '][1] (fallback) = ' .. tostring(hashToApply))
                            end
                        elseif k == 'hair_accessories' and clothing[genderKey][k][1] then
-- Fallback: hair_accessories model not found model 1 - include texture from previous
                            if clothing[genderKey][k][1][texture] then
                                hashToApply = clothing[genderKey][k][1][texture].hash
                            elseif clothing[genderKey][k][1][1] then
                                hashToApply = clothing[genderKey][k][1][1].hash
                            end
                        end
                    end
                    
-- Fallback for GetHashFromModel (current file loaded from clothing.lua)
                    if not hashToApply then
                        hashToApply = GetHashFromModel(k, model, texture, isMale)
                        print('[RSG-Clothing] Got hash from GetHashFromModel for ' .. k .. ': ' .. tostring(hashToApply))
                    end
                end
                
                if hashToApply and hashToApply ~= 0 then
                    resolvedComponents[k] = {
                        hash = hashToApply,
                        model = v.model or 0,
                        texture = v.texture or 0,
                        palette = v.palette or 'tint_generic_clean',
                        tints = v.tints or {0, 0, 0},
                        kaf = v.kaf or v._kaf or 'Classic',
                        _kaf = v._kaf or v.kaf or 'Classic',
                        draw = v.draw,
                        albedo = v.albedo,
                        normal = v.normal,
                        material = v.material,
                    }
                else
                    print('[RSG-Clothing] WARNING: No hash found for ' .. k)
                end
            end
        end
        
-- Provide details in intermediate logs for additional Finalize+Update
        local lowerOrder = {'pants', 'skirts', 'dresses'}
        local upperOrder = {'shirts_full', 'vests', 'coats', 'coats_closed'}
        local lateOrder = {'boots', 'boot_accessories', 'spurs', 'chaps', 'spats'}
        local applied = {}
        local phaseCount = 0

        -- Apply every stored representation used by the clothing data. Ped entries
        -- need their drawable assets; applying only their component hash loses the
        -- visible item after an outfit is restored.
        local function ApplyResolvedComponent(category, data)
            if data.kaf == 'BodyComponent' then
                Citizen.InvokeNative(0x1902C4CFCC5BE57C, _Target, data.hash)
            elseif data.kaf == 'Ped' and data.draw and data.draw ~= '' then
                local assets = { data.draw, data.albedo, data.normal, data.material }
                for assetIndex, asset in ipairs(assets) do
                    if asset and asset ~= '' and asset ~= '_' and asset ~= 0 then
                        local assetHash = asset
                        if type(assetHash) == 'string' then
                            if assetIndex == 4 and assetHash:sub(1, 2):lower() == '0x' then
                                assetHash = tonumber(assetHash, 16)
                            else
                                assetHash = GetHashKey(assetHash)
                            end
                        end
                        if assetHash and assetHash ~= 0 then
                            Citizen.InvokeNative(0x59BD177A1A48600A, _Target, assetHash)
                            Citizen.InvokeNative(0xD3A7B003ED343FD9, _Target, assetHash, true, true, true)
                        end
                    end
                end
            else
                NativeSetPedComponentEnabledClothes(_Target, data.hash, false, true, true)
            end

            if isOwnPed then ClothesCache[category] = data end
        end
        
-- Update 1: additional items
        phaseCount = 0
        for _, cat in ipairs(lowerOrder) do
            if resolvedComponents[cat] then
                ApplyResolvedComponent(cat, resolvedComponents[cat])
                applied[cat] = true
                phaseCount = phaseCount + 1
            end
        end
        if phaseCount > 0 then
            NativeUpdatePedVariation(_Target, true)
            Wait(100)
        end
        
-- Update 2: overall notes
        phaseCount = 0
        for _, cat in ipairs(upperOrder) do
            if resolvedComponents[cat] then
                ApplyResolvedComponent(cat, resolvedComponents[cat])
                applied[cat] = true
                phaseCount = phaseCount + 1
            end
        end
        if phaseCount > 0 then
            NativeUpdatePedVariation(_Target, true)
            Wait(100)
        end
        
-- Update 3: resolving glitches (previous results)
        phaseCount = 0
        for k, data in pairs(resolvedComponents) do
            if not applied[k] then
                local isLate = false
                for _, lc in ipairs(lateOrder) do
                    if k == lc then isLate = true break end
                end
                if not isLate then
                    ApplyResolvedComponent(k, data)
                    applied[k] = true
                    phaseCount = phaseCount + 1
                end
            end
        end
        if phaseCount > 0 then
            NativeUpdatePedVariation(_Target, true)
            Wait(100)
        end
        
-- Update 4: details cleared (all previous)
        phaseCount = 0
        for _, cat in ipairs(lateOrder) do
            if resolvedComponents[cat] and not applied[cat] then
                ApplyResolvedComponent(cat, resolvedComponents[cat])
                applied[cat] = true
                phaseCount = phaseCount + 1
            end
        end
        if phaseCount > 0 then
            NativeUpdatePedVariation(_Target, true)
            Wait(100)
        end
        
-- Determine new hash when transitioning!
        for k, v in pairs(ClothesComponents) do
            if type(v) == 'table' and v.palette and v.tints then
-- In the same: compare Classic models under specific tint - check logs ? hash!
-- Update kaf="Classic" and kaf=nil (local case) ? compare tones - adjustments needed
                local isClassic = (v.kaf == "Classic") or (v.kaf == nil and (not v.tints[1] or v.tints[1] == 0) and (not v.tints[2] or v.tints[2] == 0) and (not v.tints[3] or v.tints[3] == 0))
                local isPedCoatCategory = IsPedCoatItem(k, v)
                
                if isClassic and not isPedCoatCategory then
                    print('[RSG-Clothing] Skipping tint for ' .. k .. ' (Classic - color is in hash)')
                elseif isPedCoatCategory or
                   v.palette ~= 'tint_generic_clean' or 
                   (v.tints[1] and v.tints[1] > 0) or 
                   (v.tints[2] and v.tints[2] > 0) or 
                   (v.tints[3] and v.tints[3] > 0) then
                    ApplyClothingColor(_Target, k, v.palette, v.tints)
                    print('[RSG-Clothing] Applied color for ' .. k .. ': palette=' .. v.palette)
                    Wait(50)
                end
            end
        end
        
        SetEntityAlpha(_Target, 255)
        
-- ? FIX: retrieve hair_accessories that appear (previously in logs waiting for synchronization)
-- Reapply hair accessories to span concerns - ReapplyHairAccessories for updated ClothesCache
        if isOwnPed and not isMale and resolvedComponents['hair_accessories'] and resolvedComponents['hair_accessories'].hash and resolvedComponents['hair_accessories'].hash ~= 0 then
            SetTimeout(200, function()
                TriggerEvent('rsg-appearance:client:ReapplyHairAccessories', _Target)
            end)
        end
        
-- The file creator.lua, current computations processed within notes (for body morph)
        if isOwnPed then
            _G._ApplyClothesComplete = true
            TriggerEvent('rsg-appearance:client:ApplyClothesComplete', _Target, SkinData)
        end
        
-- From previous item to section detail - provide morphs for specific characters
        if ReapplyBodyMorph then ReapplyBodyMorph(_Target) end
        NativeUpdatePedVariation(_Target, true)
        -- LEGACY AUTOMATIC BODY CALLBACK DISABLED:
        -- if isOwnPed then
        --     TriggerEvent('rsg-appearance:client:RefreshClothingPreviewBody', 'outfit', false, _Target)
        -- end
        
        print('[RSG-Clothing] ApplyClothes completed with colors')
    end)
end)

function destory()
    OldClothesCache = {}
    SetCamActive(ClothingCamera, false)
    RenderScriptCams(false, true, 500, true, true)
    DisplayHud(true)
    DisplayRadar(true)
    DestroyAllCams(true)
    ClothingCamera = nil
    playerHeading = nil
    Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), true, 0, false)
end

function TeleportAndFade(coords4, resetCoords)
    DoScreenFadeOut(500)
    Wait(1000)
    Citizen.InvokeNative(0x203BEFFDBE12E96A, PlayerPedId(), coords4)
    SetEntityCoordsNoOffset(PlayerPedId(), coords4, true, true, true)
    LocalPlayer.state.inClothingStore = true
    Wait(1500)
    DoScreenFadeIn(1800)
    if resetCoords then
        CurentCoords = {}
        TogglePrompts({ "TURN_LR", "CAM_UD", "ZOOM_IO" }, false)
        LocalPlayer.state.inClothingStore = false
        TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', 0)
    end
end

function camera(zoom, offset)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local angle
    if playerHeading == nil then
        playerHeading = GetEntityHeading(playerPed)
    end
    angle = playerHeading * math.pi / 180.0
    local pos = {
        x = coords.x - (zoom * math.sin(angle)),
        y = coords.y + (zoom * math.cos(angle)),
        z = coords.z + offset
    }
    if not ClothingCamera then
        DestroyAllCams(true)
        ClothingCamera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z, 300.00, 0.00, 0.00, 50.00, false, 0)
        PointCamAtCoord(ClothingCamera, coords.x, coords.y, coords.z + offset)
        SetCamActive(ClothingCamera, true)
        RenderScriptCams(true, true, 1000, true, true)
        DisplayRadar(false)
    else
        local ClothingCamera2 = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z, 300.00, 0.00, 0.00, 50.00, false, 0)
        SetCamActive(ClothingCamera2, true)
        SetCamActiveWithInterp(ClothingCamera2, ClothingCamera, 750)
        PointCamAtCoord(ClothingCamera2, coords.x, coords.y, coords.z + offset)
        Wait(150)
        SetCamActive(ClothingCamera, false)
        DestroyCam(ClothingCamera)
        ClothingCamera = ClothingCamera2
    end
end

function Outfits()
    MenuData.CloseAll()
    local Result = lib.callback.await('rsg-appearance:server:getOutfits', false)
    local elements_outfits = {}
    for k, v in pairs(Result) do
        elements_outfits[#elements_outfits + 1] = {
            name = v.name,
            label = '#' .. k .. '. ' .. v.name,
            value = v.clothes,
            desc = RSG.Label.choose
        }
    end
    MenuData.Open('default', GetCurrentResourceName(), 'outfits_menu',
        {title = RSG.Label.clothes, subtext = RSG.Label.choose, align = 'top-left', elements = elements_outfits, itemHeight = "4vh"},
        function(data, menu)
            OutfitsManage(data.current.value, data.current.name)
        end, function(data, menu)
            menu.close()
        end)
end

function OutfitsManage(outfit, id)
    MenuData.CloseAll()
    local elements_outfits_manage = {
        {label = RSG.Label.wear, value = "SetOutfits", desc = RSG.Label.wear_desc},
        {label = RSG.Label.delete, value = "DeleteOutfit", desc = RSG.Label.delete_desc}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'outfits_menu_manage',
        {title = RSG.Label.clothes, subtext = RSG.Label.options, align = 'top-left', elements = elements_outfits_manage, itemHeight = "4vh"}, function(data, menu)
            menu.close()
        if data.current.value == 'SetOutfits' then
            TriggerEvent('rsg-appearance:client:ApplyClothes', outfit, PlayerPedId())
            TriggerServerEvent('rsg-appearance:server:saveUseOutfit', ConvertCacheToHash(outfit))
        end
        if data.current.value == 'DeleteOutfit' then
            TriggerServerEvent('rsg-appearance:server:DeleteOutfit', id)
        end
    end, function(data, menu)
        Outfits()
    end)
end

RegisterNetEvent('rsg-appearance:client:outfits', function() Outfits() end)

local Cloakroom = GetRandomIntInRange(0, 0xffffff)

function OpenCloakroom()
    local str = locale('cloack_room_prompt_button')
    CloakPrompt = PromptRegisterBegin()
    PromptSetControlAction(CloakPrompt, RSG.OpenKey)
    PromptSetText(CloakPrompt, CreateVarString(10, 'LITERAL_STRING', str))
    PromptSetEnabled(CloakPrompt, true)
    PromptSetVisible(CloakPrompt, true)
    PromptSetHoldMode(CloakPrompt, true)
    PromptSetGroup(CloakPrompt, Cloakroom)
    PromptRegisterEnd(CloakPrompt)
end

CreateThread(function()
    OpenCloakroom()
    while true do
        Wait(5)
        local sleep = true
        local coords = GetEntityCoords(PlayerPedId())
        for _, v in pairs(RSG.Cloakroom) do
            if #(coords - v) < 2.0 then
                sleep = false
                PromptSetActiveGroupThisFrame(Cloakroom, CreateVarString(10, 'LITERAL_STRING', RSG.Cloakroomtext))
                if PromptHasHoldModeCompleted(CloakPrompt) then
                    Outfits()
                    break
                end
            end
        end
        if sleep then Wait(1500) end
    end
end)

function GenerateMenu()
    TriggerEvent('rsg-horses:client:FleeHorse')
    TeleportAndFade(CurentCoords.fittingcoords, false)
    TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', 0, true)
    
    local ClothesComponents = lib.callback.await('rsg-appearance:server:LoadClothes', false)
    ClothesCache = hashToCache.PopulateClothingCache(ClothesComponents, IsPedMale(PlayerPedId()))
    
-- Check status for output ahead
    RSGCore.Functions.TriggerCallback('rsg-clothing:server:getInventoryClothing', function(inventoryClothes)
        OldClothesCache = inventoryClothes or {}
        CurrentPrice = 0
        
        camera(2.4, -0.15)
        CreateThread(ClothingLight)
        OpenClothingMenu()
    end)
end

CreateThread(function()
    LocalPlayer.state.inClothingStore = false
    CreateBlips()
    if RegisterPrompts() then
        while true do
            local room = GetClosestConsumer()
            if room then
                if not PromptsEnabled then TogglePrompts({ "OPEN_CLOTHING_MENU" }, true) end
                if PromptsEnabled and IsPromptCompleted("OPEN_CLOTHING_MENU") then
                    Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), false, 0, true)
                    GenerateMenu()
                end
            else
                if PromptsEnabled then TogglePrompts({ "OPEN_CLOTHING_MENU" }, false) end
                Wait(250)
            end
            Wait(100)
        end
    end
end)

function GetClosestConsumer()
    local coords = GetEntityCoords(PlayerPedId())
    for _,data in pairs(RSG.Zones1) do
        if (data.promtcoords and #(coords - data.promtcoords) < 1.0) or (data.epromtcoords and #(coords - data.epromtcoords) < 1.0) then
            CurentCoords = data
            return true
        end
    end
    return false
end

function RegisterPrompts()
    local newTable = {}
    for i=1, #RSG.Prompts do
        local prompt = Citizen.InvokeNative(0x04F97DE45A519419, Citizen.ResultAsInteger())
        Citizen.InvokeNative(0x5DD02A8318420DD7, prompt, CreateVarString(10, "LITERAL_STRING", RSG.Prompts[i].label))
        Citizen.InvokeNative(0xB5352B7494A08258, prompt, RSG.Prompts[i].control or RSGCore.Shared.Keybinds[RSG.Keybind])
        if RSG.Prompts[i].control2 then
            Citizen.InvokeNative(0xB5352B7494A08258, prompt, RSG.Prompts[i].control2)
        end
        Citizen.InvokeNative(0x94073D5CA3F16B7B, prompt, RSG.Prompts[i].time or 1000)
        if RSG.Prompts[i].control then
            Citizen.InvokeNative(0x2F11D3A254169EA4, prompt, RoomPrompts)
        end
        Citizen.InvokeNative(0xF7AA2696A22AD8B9, prompt)
        Citizen.InvokeNative(0x8A0FB4D03A630D21, prompt, false)
        Citizen.InvokeNative(0x71215ACCFDE075EE, prompt, false)
        table.insert(RSG.CreatedEntries, { type = "PROMPT", handle = prompt })
        newTable[RSG.Prompts[i].id] = prompt
    end
    RSG.Prompts = newTable
    return true
end

function TogglePrompts(data, state)
    for index,prompt in pairs((data ~= "ALL" and data) or RSG.Prompts) do
        if RSG.Prompts[(data ~= "ALL" and prompt) or index] then
            Citizen.InvokeNative(0x8A0FB4D03A630D21, (data ~= "ALL" and RSG.Prompts[prompt]) or prompt, state)
            Citizen.InvokeNative(0x71215ACCFDE075EE, (data ~= "ALL" and RSG.Prompts[prompt]) or prompt, state)
        end
    end
    PromptSetActiveGroupThisFrame(RoomPrompts, CreateVarString(10, 'LITERAL_STRING', RSG.Label.shop.. ' - ~t6~'..CurrentPrice..'$'))
    PromptsEnabled = state
end

function IsPromptCompleted(name)
    return RSG.Prompts[name] and Citizen.InvokeNative(0xE0F65F0640EF0617, RSG.Prompts[name])
end

function CreateBlips()
    for _, coordsList in pairs(RSG.Zones1) do
        if #coordsList.blipcoords > 0 and coordsList.showblip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coordsList.blipcoords)
            SetBlipSprite(blip, RSG.BlipSprite, 1)
            SetBlipScale(blip, RSG.BlipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, RSG.BlipName)
            table.insert(RSG.CreatedEntries, { type = "BLIP", handle = blip })
        end
    end
    for _, v in pairs(RSG.Cloakroom) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v)
        SetBlipSprite(blip, RSG.BlipSpriteCloakRoom, 1)
        SetBlipScale(blip, RSG.BlipScale)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, RSG.BlipNameCloakRoom)
        table.insert(RSG.CreatedEntries, { type = "BLIP", handle = blip })
    end
end
-- ==========================================
-- Output additional details for notes
-- ==========================================

local bodyIntegrityMonitorEnabled = true

CreateThread(function()
    Wait(5000) -- interim checks
    
    while bodyIntegrityMonitorEnabled do
        Wait(3000) -- ensure output for 3 seconds
        
-- ? FIX: address performance with 6 outputs visible - Avoid flicker
        if lastClothingLoadTime > 0 and (GetGameTimer() - lastClothingLoadTime) < 6000 then
            goto continue_body_monitor
        end
        
        local ped = PlayerPedId()
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            -- return values are accurate for documentation
            local hadChanges = EnsureBodyIntegrity(ped, false)
            if hadChanges then
            end
        end
        ::continue_body_monitor::
    end
end)

-- Consider clarifying all outputs clearly (previous notes)
RegisterDebugCommand('togglebodymonitor', function()
    bodyIntegrityMonitorEnabled = not bodyIntegrityMonitorEnabled
    print('[BodyMonitor] ' .. (bodyIntegrityMonitorEnabled and 'Enabled' or 'Disabled'))
end, false)

RegisterDebugCommand('fixbody', function()
    if _G.DisableAutomaticBodyFixes then
        print('[BodyMonitor] Body hash fixes are disabled; using streamed body components.')
        return
    end

    local ped = PlayerPedId()
    
    print('=== FIXING BODY ===')
    print('Current ClothesCache:')
    for cat, data in pairs(ClothesCache or {}) do
        if type(data) == 'table' then
            print('  ' .. cat .. ': model=' .. tostring(data.model) .. ', hash=0x' .. string.format("%X", data.hash or 0))
        end
    end
    
    -- process completed details but keep all items logged
    local upperHash = GetBodyHash("BODIES_UPPER") or 0
    local lowerHash = GetBodyHash("BODIES_LOWER") or 0
    
    print('Upper body hash: 0x' .. string.format("%X", upperHash))
    print('Lower body hash: 0x' .. string.format("%X", lowerHash))
    
    -- Returning
    if upperHash ~= 0 then
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey("bodies_upper"))
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, upperHash, true, true, true)
    end
    
    if lowerHash ~= 0 then
        Citizen.InvokeNative(0x59BD177A1A48600A, ped, GetHashKey("bodies_lower"))
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, lowerHash, true, true, true)
    end
    
    Wait(100)
    NativeUpdatePedVariation(ped, true)
    
    -- Output final requests but ensure care
    Wait(100)
    for cat, data in pairs(ClothesCache or {}) do
        if type(data) == 'table' and data.hash and data.hash ~= 0 then
            NativeSetPedComponentEnabledClothes(ped, data.hash, false, true, true)
            Wait(50)
        end
    end
    
    NativeUpdatePedVariation(ped, true)
    
    TriggerEvent('ox_lib:notify', {
        title = 'Body Fix',
        description = 'Return this additional information',
        type = 'success'
    })
end, false)
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    LocalPlayer.state.inClothingStore = false
    destory()
    for i=1, #RSG.CreatedEntries do
        if RSG.CreatedEntries[i].type == "BLIP" then
            RemoveBlip(RSG.CreatedEntries[i].handle)
        elseif RSG.CreatedEntries[i].type == "PROMPT" then
            Citizen.InvokeNative(0x00EDE88D4D13CF59, RSG.CreatedEntries[i].handle)
            PromptsEnabled = false
        end
    end
end)

RegisterNetEvent('rsg-appearance:client:LoadClothesAfterSkin', function()
    if not UseClothingInventory then return end
    Wait(500)
    LoadClothingFromInventory()
end)

RegisterNetEvent('rsg-appearance:client:ApplyClothesAfterRespawn', function()
    if not UseClothingInventory then return end
    Wait(1000)
    LoadClothingFromInventory()
end)

-- ? loadcharacter: ExecuteCommand to process these defined parameters - log TriggerServerEvent
RegisterDebugCommand('loadcharacter', function()
    TriggerServerEvent('rsg-appearance:server:LoadCharacter')
end, false)

-- fixcharacter - check while loadcharacter (previous notes in logs)
RegisterDebugCommand('fixcharacter', function()
    TriggerServerEvent('rsg-appearance:server:LoadCharacter')
end, false)

RegisterDebugCommand('checkstructure', function()
    print('=== CHECKING CLOTHESCACHE STRUCTURE ===')
    
    if not ClothesCache then
        print('ClothesCache is nil!')
        return
    end
    
    for category, data in pairs(ClothesCache) do
        print('\nCategory: ' .. category)
        print('  Type: ' .. type(data))
        
        if type(data) == 'table' then
            print('  Keys in table:')
            for key, value in pairs(data) do
                print('    [' .. tostring(key) .. '] = ' .. tostring(value) .. ' (type: ' .. type(value) .. ')')
            end
        else
            print('  Value: ' .. tostring(data))
        end
    end
    
    print('\n=== TESTING CONVERT ===')
    local first = next(ClothesCache)
    if first then
        local v = ClothesCache[first]
        print('Testing ' .. first .. ':')
        print('  v = ' .. tostring(v))
        print('  v.model = ' .. tostring(v.model))
        print('  v["model"] = ' .. tostring(v["model"]))
        print('  rawget(v, "model") = ' .. tostring(rawget(v, "model")))
    end
end, false)
RegisterDebugCommand('shopdebug', function()
    print('=== SHOP DEBUG ===')
    print('CurrentPrice: $' .. tostring(CurrentPrice))
    
    print('\nClothesCache (current version):')
    if not ClothesCache or next(ClothesCache) == nil then
        print('  New!')
    else
        for cat, data in pairs(ClothesCache) do
            if type(data) == 'table' and data.model and data.model > 0 then
                print('  ' .. cat .. ': model=' .. tostring(data.model) .. ', texture=' .. tostring(data.texture or 1))
            end
        end
    end
    
    print('\nOldClothesCache (previously listed items in review):')
    if not OldClothesCache or next(OldClothesCache) == nil then
        print('  Old!')
    else
        for cat, data in pairs(OldClothesCache) do
            if type(data) == 'table' and data.model and data.model > 0 then
                print('  ' .. cat .. ': model=' .. tostring(data.model) .. ', texture=' .. tostring(data.texture or 1))
            end
        end
    end
    
    -- ongoing processes remain
    local calcPrice = CalculatePrice(ClothesCache, OldClothesCache, IsPedMale(PlayerPedId()))
    print('\nCalculation of price is finished: $' .. tostring(calcPrice))
end, false)
-- ==========================================
-- RSG-APPEARANCE PATCH: updates to changes anticipated
-- Verify that details are logged to confirm the main clothes.lua
-- ==========================================

-- ? Errors found: corrections required for additional items in ClothesCache (checking previous inputs)
exports('ReapplyBootsFromCache', function(ped)
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    if not ClothesCache then return end
    for _, cat in ipairs({'boots', 'boot_accessories', 'spurs', 'chaps', 'spats'}) do
        if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, ClothesCache[cat].hash)
            NativeSetPedComponentEnabledClothes(ped, ClothesCache[cat].hash, false, true, true)
        end
    end
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end)

-- ? Items: checking which hash belongs here
exports('GetClothingCategoryHash', function(category)
    if ClothesCache and ClothesCache[category] then
        return ClothesCache[category].hash or 0
    end
    return 0
end)

-- ? Examine preprocessing palette/tints for organization
exports('GetClothingColorData', function(category)
    if ClothesCache and ClothesCache[category] then
        return {
            palette = ClothesCache[category].palette or 'tint_generic_clean',
            tints = ClothesCache[category].tints or {0, 0, 0}
        }
    end
    return nil
end)

-- ? Return to confirm palette/tints from selections (if selected)
exports('SetClothingColorData', function(category, palette, tints)
    if ClothesCache and ClothesCache[category] then
        ClothesCache[category].palette = palette
        ClothesCache[category].tints = tints
        
        -- items correctly categorized
        ApplyClothingColor(PlayerPedId(), category, palette, tints)
        return true
    end
    return false
end)

-- ? Checking results while load character in ClothesCache (monitor loadcharacter, UpdatePedVariation for links)
function ApplyAllClothingColorsFromCache(ped)
    if not ped or not DoesEntityExist(ped) then ped = PlayerPedId() end
    if not ClothesCache then return end
    for category, data in pairs(ClothesCache) do
        if data and data.hash and data.hash ~= 0 and data.palette and ApplyClothingColor then
            ApplyClothingColor(ped, category, data.palette or 'tint_generic_clean', data.tints or {0, 0, 0})
        end
    end
end
exports('ApplyAllClothingColorsFromCache', ApplyAllClothingColorsFromCache)

-- ? Validating LoadClothingFromInventory outputs are retrieved correctly.
-- (new item interactions tracked under next, logging available)

local OriginalLoadClothingFromInventory = LoadClothingFromInventory

LoadClothingFromInventory = function(callback, options)
    if not UseClothingInventory then
        if callback then callback(false, 0) end
        return
    end
    -- item findings, ensuring notes provide concise logs related to rsg-clothingstore (verifications)
    if LocalPlayer.state.inClothingStore or LocalPlayer.state.isInClothingStore then
        if callback then callback(false) end
        return
    end
    options = options or {}
    -- item checks: overall progress with equipClothing (file "path/to/file") - noted details for man...
    local useEquipPath = (options.useEquipPath == nil) and true or options.useEquipPath
    local isLightResyncPass = (activeInventoryResyncPasses or 0) > 0
    RSGCore.Functions.TriggerCallback('rsg-clothing:server:getEquippedClothing', function(equippedItems)
        local ped = PlayerPedId()
        
        -- ? FIX: invalid processing innerhalb items possibly changing (previous notes available)
        if not equippedItems or not equippedItems['hats'] then
            Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x9925C067)
            Citizen.InvokeNative(0x704C908E9C405136, ped)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            if ClothesCache then ClothesCache['hats'] = nil end
        end
        
        if not equippedItems or not next(equippedItems) then
            if callback then callback(false) end
            return
        end
        
        local count = 0
        local isMale = IsPedMale(ped)
        local genderKey = isMale and 'male' or 'female'
        
        -- Output notes should stay on-line
        ClothesCache = {}
        
        for category, data in pairs(equippedItems) do
            local hashToUse = nil
            
            -- additional model hash
            if data.hash and data.hash ~= 0 then
                hashToUse = data.hash
            elseif data.model and data.model > 0 then
                local model = data.model
                local texture = data.texture or 1
                -- ? FIX: ensuring fetch hairstyle accessories - output = reviewed for latest adjustments
                if category == 'hair_accessories' and not isMale then
                    local hairInfo = exports['rsg-appearance']:GetComponentId('hair')
                    if hairInfo and type(hairInfo) == 'table' and hairInfo.model and hairInfo.model >= 1 and clothing[genderKey] and clothing[genderKey][category] and clothing[genderKey][category][hairInfo.model] then
                        model = hairInfo.model
                    end
                end
                if clothing[genderKey] and clothing[genderKey][category] then
                    if clothing[genderKey][category][model] then
                        if clothing[genderKey][category][model][texture] then
                            hashToUse = clothing[genderKey][category][model][texture].hash
                        elseif clothing[genderKey][category][model][1] then
                            hashToUse = clothing[genderKey][category][model][1].hash
                        end
                    elseif category == 'hair_accessories' and clothing[genderKey][category][1] then
                        if clothing[genderKey][category][1][texture] then
                            hashToUse = clothing[genderKey][category][1][texture].hash
                        elseif clothing[genderKey][category][1][1] then
                            hashToUse = clothing[genderKey][category][1][1].hash
                        end
                    end
                end
            end
            
            if hashToUse and hashToUse ~= 0 then
                -- Checking where location is affecting item for verification, noting kaf/draw/albedo/normal/material
                ClothesCache[category] = {
                    hash = hashToUse,
                    model = data.model or 0,
                    texture = data.texture or 0,
                    palette = data.palette or data._p or 'tint_generic_clean',
                    tints = data.tints or data._tints or {0, 0, 0},
                    kaf = data.kaf or data._kaf or "Classic",
                    _kaf = data._kaf or data.kaf or "Classic",
                    draw = data.draw or "",
                    albedo = data.albedo or "",
                    normal = data.normal or "",
                    material = data.material or 0,
                }
                
                print('[RSG-Clothing] Loaded: ' .. category .. ' kaf=' .. tostring(ClothesCache[category].kaf) .. ' palette=' .. tostring(ClothesCache[category].palette))
            end
        end
        
        -- process checks remain logout
        EnsureBodyIntegrity(ped, true)
        Wait(100)
        
        -- ? FIX naked_body restrictions /pee /poo: returns overlays impacting most recent general log (if on equipClothing)
        local lowerBodyCats = {'pants', 'skirts', 'dresses'}
        local hasLowerToApply = false
        for _, cat in ipairs(lowerBodyCats) do
            if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                hasLowerToApply = true
                break
            end
        end
        if hasLowerToApply and RemoveNakedLowerBody then
            RemoveNakedLowerBody(ped, true)
            Wait(50)
        end
        
        if useEquipPath then
            -- ? loadcharacter: confirm outputs are relayed - considering notes managing equipClothing with case exception
            -- Vest/corset observe notations: ensuring overlays positioned in jeering case (confirmation needed)
            local hasVest = (ClothesCache['vests'] or ClothesCache['corsets']) and ((ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0) or (ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0))
            local hasShirt = ClothesCache['shirts_full'] and ClothesCache['shirts_full'].hash and ClothesCache['shirts_full'].hash ~= 0
            local hasDress = ClothesCache['dresses'] and ClothesCache['dresses'].hash and ClothesCache['dresses'].hash ~= 0
            local hasCoat = (ClothesCache['coats'] and ClothesCache['coats'].hash and ClothesCache['coats'].hash ~= 0) or (ClothesCache['coats_closed'] and ClothesCache['coats_closed'].hash and ClothesCache['coats_closed'].hash ~= 0)
            if hasVest and not hasShirt and not hasDress and not hasCoat and not IsPedMale(ped) and ApplyNakedUpperBody then
                ApplyNakedUpperBody(ped, true)
                Wait(80)
            end
            -- outputs from caps (hats, neckties and checks in sequence) - pairs() additional outputs (verify/resources)
            local equipOrder = {'pants', 'skirts', 'dresses', 'shirts_full', 'neckwear', 'neckties', 'vests', 'corsets', 'coats', 'coats_closed', 'hats', 'gunbelts', 'belts', 'satchels', 'suspenders', 'gloves', 'eyewear', 'masks'}
            local lateOrder = {'boots', 'boot_accessories', 'spurs', 'chaps', 'spats'}
            -- ensuring output categories like 350?? - equipClothing status returnable, 180?? in checks on previous (resources linked back)
            for _, cat in ipairs(equipOrder) do
                if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                    local itemData = { category = cat, isMale = isMale }
                    for k, v in pairs(ClothesCache[cat]) do itemData[k] = v end
                    TriggerEvent('rsg-clothing:client:equipClothing', itemData, { skipResync = true })
                    Wait(350)
                end
            end
            for _, cat in ipairs(lateOrder) do
                if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                    local itemData = { category = cat, isMale = isMale }
                    for k, v in pairs(ClothesCache[cat]) do itemData[k] = v end
                    TriggerEvent('rsg-clothing:client:equipClothing', itemData, { skipResync = true })
                    Wait(300)
                end
            end
            for category, data in pairs(ClothesCache) do
                if data.hash and data.hash ~= 0 then
                    local alreadyDone = false
                    for _, c in ipairs(equipOrder) do if category == c then alreadyDone = true break end end
                    for _, c in ipairs(lateOrder) do if category == c then alreadyDone = true break end end
                    if not alreadyDone then
                        local itemData = { category = category, isMale = isMale }
                        for k, v in pairs(data) do itemData[k] = v end
                        TriggerEvent('rsg-clothing:client:equipClothing', itemData, { skipResync = true })
                        Wait(300)
                    end
                end
            end
            count = 0
            for _ in pairs(ClothesCache) do count = count + 1 end
            -- completion active UpdatePedVariation confirmed. skipBodyMorph=true - ensure checks still mark your requests
            if NativeUpdatePedVariation then NativeUpdatePedVariation(ped, true) end
        else
        -- return small: overlook items in transitioned categories (checks -> log off)
        -- ? marking DROP - harmful health keys draw/albedo/normal/material
        local priorityOrder2 = {'pants', 'skirts', 'dresses', 'shirts_full', 'vests', 'coats', 'coats_closed'}
        local lateOrder2 = {'boots', 'boot_accessories', 'spurs', 'chaps', 'spats'}
        local applied2 = {}
        -- Return notations regarding re-equip logs set items for charges before checking updates ClothesCache
        local reequipSkirtBootsPayload = nil

        -- these transitions remain spread clear (Classic case opened)
        local function ApplyItem(cat, itemData)
            if itemData.kaf == "Ped" and itemData.draw and itemData.draw ~= "" then
                -- See: review stance drawn from items for overall measure
                if itemData.draw ~= "" and itemData.draw ~= "_" then
                    local drawHash = GetHashKey(itemData.draw)
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, drawHash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, drawHash, true, true, true)
                end
                if itemData.albedo and itemData.albedo ~= "" then
                    local albHash = GetHashKey(itemData.albedo)
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, albHash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, albHash, true, true, true)
                end
                if itemData.normal and itemData.normal ~= "" then
                    local normHash = GetHashKey(itemData.normal)
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, normHash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, normHash, true, true, true)
                end
                if itemData.material and itemData.material ~= 0 then
                    local matHash = itemData.material
                    if type(matHash) == "string" then matHash = GetHashKey(matHash) end
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, matHash)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, matHash, true, true, true)
                end
            else
                -- Classic-path: details remain extended
                NativeSetPedComponentEnabledClothes(ped, itemData.hash, false, true, true)
            end
        end
        
-- ? FIX: ????????? ????? ????? ?????? ??? ???????? ?????
-- ? ???? 1: ?????? ????? ???? (pants, skirts, dresses)
        local lowerBody = {'pants', 'skirts', 'dresses'}
        local lowerApplied = false
        for _, cat in ipairs(lowerBody) do
            if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                ApplyItem(cat, ClothesCache[cat])
                applied2[cat] = true
                count = count + 1
                lowerApplied = true
                Wait(50)
            end
        end
        if lowerApplied then
            Wait(80)
        end

-- ? ???? 2: ??????? (??????? ??????? ????)
        if ClothesCache['shirts_full'] and ClothesCache['shirts_full'].hash and ClothesCache['shirts_full'].hash ~= 0 then
            ApplyItem('shirts_full', ClothesCache['shirts_full'])
            applied2['shirts_full'] = true
            count = count + 1
            Wait(80)
        end

-- ? ???? 3: ?????? ???? (??? ????????/??????)
        for _, cat in ipairs({'neckwear', 'neckties'}) do
            if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                ApplyItem(cat, ClothesCache[cat])
                applied2[cat] = true
                count = count + 1
                Wait(50)
            end
        end

-- ? ???? 3.5: ?????? ?? ????? ???? - ??? vest/corset ??? ??????? ????????? naked overlay ?? vest (????????? ?????)
        local vestOrCorset = ClothesCache['vests'] or ClothesCache['corsets']
        local hasVest = vestOrCorset and vestOrCorset.hash and vestOrCorset.hash ~= 0
        local hasShirt = ClothesCache['shirts_full'] and ClothesCache['shirts_full'].hash and ClothesCache['shirts_full'].hash ~= 0
        local hasDress = ClothesCache['dresses'] and ClothesCache['dresses'].hash and ClothesCache['dresses'].hash ~= 0
        local hasCoat = (ClothesCache['coats'] and ClothesCache['coats'].hash and ClothesCache['coats'].hash ~= 0)
            or (ClothesCache['coats_closed'] and ClothesCache['coats_closed'].hash and ClothesCache['coats_closed'].hash ~= 0)
        if hasVest and not hasShirt and not hasDress and not hasCoat and not IsPedMale(ped) and ApplyNakedUpperBody then
            ApplyNakedUpperBody(ped, true)
            Wait(50)
        end

-- ? ???? 4: ???????/??????? (??????? ???? - ?????? ???????/???
        if ClothesCache['vests'] and ClothesCache['vests'].hash and ClothesCache['vests'].hash ~= 0 then
            ApplyItem('vests', ClothesCache['vests'])
            applied2['vests'] = true
            count = count + 1
            Wait(80)
        end
        if ClothesCache['corsets'] and ClothesCache['corsets'].hash and ClothesCache['corsets'].hash ~= 0 then
            ApplyItem('corsets', ClothesCache['corsets'])
            applied2['corsets'] = true
            count = count + 1
            Wait(80)
        end

-- ? ???? 5: ?????? (??????? ???? - ?????? ???????)
        for _, cat in ipairs({'coats', 'coats_closed'}) do
            if ClothesCache[cat] and ClothesCache[cat].hash and ClothesCache[cat].hash ~= 0 then
                ApplyItem(cat, ClothesCache[cat])
                applied2[cat] = true
                count = count + 1
                Wait(50)
            end
        end

-- ? ???? 6: ????????? ?????????? (????? ?????)
        for category, data in pairs(ClothesCache) do
            if not applied2[category] and data.hash and data.hash ~= 0 then
                local isLate = false
                for _, lc in ipairs(lateOrder2) do
                    if category == lc then isLate = true break end
                end
                if not isLate then
-- ? FIX: ????????? - ????????? ??????????? ??????? ?? ?????????, ????????? ????????? (stack)
                    if category == 'hats' then
                        Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x9925C067)
                        Wait(50)
                    end
                    ApplyItem(category, data)
                    applied2[category] = true
                    count = count + 1
                    Wait(50)
                end
            end
        end

    -- ? ???? 7: ?????????????
        for _, category in ipairs(lateOrder2) do
            if ClothesCache[category] and ClothesCache[category].hash and ClothesCache[category].hash ~= 0 and not applied2[category] then
                ApplyItem(category, ClothesCache[category])
                applied2[category] = true
                count = count + 1
                Wait(50)
            end
        end

    -- ? ????????? ????????? ????? / ?????? / ????????? + ?????? ??? ??????????? re-equip (?? ????????? ?? ClothesCache ? SetTimeout)
        if (not IsPedMale(ped)) and (applied2['pants'] or applied2['skirts'] or applied2['dresses']) and (ClothesCache['boots'] and ClothesCache['boots'].hash and ClothesCache['boots'].hash ~= 0) then
            local lc = applied2['skirts'] and 'skirts' or (applied2['dresses'] and 'dresses' or 'pants')
            reequipSkirtBootsPayload = {
                lowerData = { category = lc, isMale = isMale },
                bootData = { category = 'boots', isMale = isMale }
            }
            for k, v in pairs(ClothesCache[lc]) do reequipSkirtBootsPayload.lowerData[k] = v end
            for k, v in pairs(ClothesCache['boots']) do reequipSkirtBootsPayload.bootData[k] = v end
        end

    -- ? ???? ??? ????????? ????????? ????? ????????? ????????? ???? ????? - skipBodyMorph ??????????? ?????????? ?? ????????????
        NativeUpdatePedVariation(ped, true)
        Wait(100)
        end  -- ????????? else (bulk apply)
        
    -- ? ????????? ?????????!
        for category, data in pairs(ClothesCache) do
            if data.palette and data.tints then
                local hasTints = data.tints[1] ~= 0 or data.tints[2] ~= 0 or data.tints[3] ~= 0
                local hasCustomPalette = data.palette ~= 'tint_generic_clean'
                local isPedCoat = IsPedCoatItem(category, data)
                
                if isPedCoat or hasTints or hasCustomPalette then
                    print('[RSG-Clothing] Applying color to ' .. category .. ': ' .. table.concat(data.tints, ','))
                    ApplyClothingColor(ped, category, data.palette, data.tints)
                    Wait(50)
                end
            end
        end

    -- ? Ped-???: ????????? ????????? (????? palette/tints)
        for category, data in pairs(ClothesCache) do
            if data.kaf == "Ped" and data.palette and data.palette ~= "" and data.palette ~= " " then
                local paletteHash = GetHashKey(data.palette)
                if not string.find(data.palette:lower(), 'metaped_') then
                    paletteHash = GetHashKey('metaped_' .. data.palette:lower())
                end
                local tintHash = GetTintCategoryHash and GetTintCategoryHash(category) or nil
                if tintHash then
                    Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, ped, tintHash, paletteHash,
                        data.tints and data.tints[1] or 0,
                        data.tints and data.tints[2] or 0,
                        data.tints and data.tints[3] or 0)
                    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
                end
            end
        end
        
    -- ????????? ????????
        Wait(100)
        EnsureBodyIntegrity(ped, false)
        
    -- ? ????? EnsureBodyIntegrity ???? ???? ?????????? - ????????????? ???? + ????????? (nativepaint)
        ReapplyAppearanceAfterClothing(ped)
        NativeUpdatePedVariation(ped, true)

    -- ? ??? ?????? ????????? (ApplySkin) ?????????? ?????????????? ?????? - ???? ?????? ?????? ? ??? UpdatePedVariation (????? ????? ? ????? ?????).
    -- ??? ?????? ?????????? (equip/remove) ??????????? ????????? / ??????????? ????? EnsureBodyIntegrity.
        if isLightResyncPass then
            Wait(150)
            ped = PlayerPedId()
            if DoesEntityExist(ped) then
                for _, cat in ipairs({'boots', 'boot_accessories', 'spurs', 'chaps', 'spats'}) do
                    local item = ClothesCache and ClothesCache[cat]
                    if item and item.hash and item.hash ~= 0 then
                        Citizen.InvokeNative(0x59BD177A1A48600A, ped, item.hash)
                        NativeSetPedComponentEnabledClothes(ped, item.hash, true, true, true)
                        Wait(50)
                    end
                end
                if not isMale and ClothesCache and ClothesCache['hair_accessories'] and ClothesCache['hair_accessories'].hash and ClothesCache['hair_accessories'].hash ~= 0 then
                    local h = ClothesCache['hair_accessories'].hash
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x79D7DF96, 0)
                    Wait(80)
                    Citizen.InvokeNative(0x59BD177A1A48600A, ped, h)
                    NativeSetPedComponentEnabledClothes(ped, h, true, true, true)
                    Wait(80)
                end
                NativeUpdatePedVariation(ped, true)
            end
        else
            lastClothingLoadTime = GetGameTimer()
            -- ? ?????????????? ?????????????? ?????????: ????? ???? ???? ? ?????? ?????????. ????????? ????????? ? ????????????? ??????.
            -- ? useEquipPath: ??? ????? ????? equip - ?? ????? refresh, ?????? ?????
            if useEquipPath then
                SetTimeout(400, function()
                    TriggerEvent('rsg-appearance:client:clothingVariationChanged')
                    SetTimeout(250, function()
                        TriggerEvent('rsg-appearance:client:clothingVariationSettled')
                        TriggerEvent('rsg-appearance:client:requestModifierReapply')
                    end)
                end)
            else
            SetTimeout(600, function()
                local p = PlayerPedId()
                if not p or not DoesEntityExist(p) then return end
                -- ? ???.+?????/????/??????+?????: ??? ?? ????, ??? "?????/?????? ????????? ?????????". ?????? ????? ?? ???????????? payload (?? ClothesCache - ?? ??? ?????????????? ??? ????????? ?????????)
                if reequipSkirtBootsPayload then
                    TriggerEvent('rsg-clothing:client:equipClothing', reequipSkirtBootsPayload.lowerData, { skipResync = true })
                    Wait(350)
                    TriggerEvent('rsg-clothing:client:equipClothing', reequipSkirtBootsPayload.bootData, { skipResync = true })
                    Wait(350)
                end
                local shirt = ClothesCache and ClothesCache['shirts_full']
                local shirtHash = shirt and shirt.hash and shirt.hash ~= 0 and shirt.hash or nil
                if shirtHash then
                    local catHash = GetHashKey('shirts_full')
                    Citizen.InvokeNative(0xD710A5007C2AC539, p, catHash, 0)
                    Citizen.InvokeNative(0x704C908E9C405136, p)
                    Citizen.InvokeNative(0xCC8CA3E88256E58F, p, false, true, true, true, false)
                    Wait(120)
                    Citizen.InvokeNative(0x59BD177A1A48600A, p, shirtHash)
                    NativeSetPedComponentEnabledClothes(p, shirtHash, false, true, true)
                    Citizen.InvokeNative(0x704C908E9C405136, p)
                    Citizen.InvokeNative(0xCC8CA3E88256E58F, p, false, true, true, true, false)
                    Wait(80)
                    -- ? FIX: ?????????? ?????????? ?? ClothingModState, ? ?? BASE - ????? ??????? ??????/???????
                    local shirtVar = ClothingVariations.shirts.base
                    if ClothingModState and ClothingModState.sleeves_rolled_open then
                        shirtVar = ClothingVariations.shirts.rolled_open
                    elseif ClothingModState and ClothingModState.sleeves_rolled then
                        shirtVar = ClothingVariations.shirts.rolled_closed
                    end
                    SetPedComponentVariation(p, shirtHash, shirtVar)
                    NativeUpdatePedVariation(p, true)
                    if shirt.palette and shirt.tints and ApplyClothingColor then
                        Wait(80)
                        ApplyClothingColor(p, 'shirts_full', shirt.palette, shirt.tints)
                    end
                else
                    -- ? FIX: Vest/corset ??? ??????? - ????????????? ????? ????? ~1.1 ??? (???????? ???? ?????? ??????)
                    -- RDR2 ????????? ?????????? "refresh" ???? ??? ??????????? ??????? (?? ????????? RDR2 modding)
                    local vest = ClothesCache and (ClothesCache['vests'] or ClothesCache['corsets'])
                    local vestHash = vest and vest.hash and vest.hash ~= 0 and vest.hash or nil
                    local vestCat = vest and (ClothesCache['vests'] and ClothesCache['vests'].hash == vest.hash and 'vests' or 'corsets') or nil
                    if vestHash and vestCat and not isMale then
                        SetTimeout(1100, function()
                            local ped = PlayerPedId()
                            if not ped or not DoesEntityExist(ped) then return end
                            if EnsureBodyIntegrity then EnsureBodyIntegrity(ped, true) end
                            Wait(80)
                            NativeSetPedComponentEnabledClothes(ped, vestHash, false, true, true)
                            Citizen.InvokeNative(0x704C908E9C405136, ped)
                            NativeUpdatePedVariation(ped, true)
                            if vest.palette and vest.tints and ApplyClothingColor then
                                Wait(50)
                                ApplyClothingColor(ped, vestCat, vest.palette, vest.tints)
                            end
                        end)
                    end
                    NativeUpdatePedVariation(p, true)
                end
                -- ReapplyAppearanceAfterClothing(p) -- ?????????: ????????? ?????
                TriggerEvent('rsg-appearance:client:clothingVariationChanged')
                SetTimeout(650, function()
                    TriggerEvent('rsg-appearance:client:clothingVariationSettled')
                    -- ? FIX: ????????? clothing-modifier ????????????? ????? - ????? ???????/????? ??????? ????? reload
                    TriggerEvent('rsg-appearance:client:requestModifierReapply')
                end)
            end)
            end  -- else (bulk apply)
        end

    -- ? ?????????? ??????????????? (5 ???) ????????? ??? ?????? ??????????? - ???? ?????? ?????? ??? ?????? ??????????????.
        
        print('[RSG-Clothing] Loaded ' .. count .. ' items (single apply, no extra re-applies)')
        if callback then callback(true, count) end
    end)
end

-- ? ?????????: ReapplyVestOverShirt ? beforeModifierReapply ????????? ?????????? NativeUpdatePedVariation ? ????? ??????
-- AddEventHandler('rsg-appearance:client:beforeModifierReapply', ...)

-- ?????????: ?????????????? vest/coat ? afterModifierReapply ?????????? ???? ?????? ? ?????? ???????
AddEventHandler('rsg-appearance:client:afterModifierReapply', function() end)

-- ? ??????? ?? clothing-modifier ??? ?????????? ????? ? ????
RegisterNetEvent('rsg-appearance:updateClothingColor', function(category, palette, tints)
    if ClothesCache and ClothesCache[category] then
        ClothesCache[category].palette = palette
        ClothesCache[category].tints = tints
        print('[RSG-Clothing] Updated cache color for ' .. category)
    end
end)

print('[RSG-Appearance] Color preservation patch loaded')
