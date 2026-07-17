-- ==========================================
-- RSG-CLOTHING SERVER v3.1 FIXED
-- Translate item types and related items
-- ==========================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local playerEquippedClothing = {}
local starterGivenTo = {}
local UseClothingInventory = not (RSG and RSG.UseClothingInventory == false)

-- ==========================================
-- Various clothing and accessories
-- ==========================================

local categoryToItem = {
    ['hats'] = 'clothing_hats',
    ['shirts_full'] = 'clothing_shirts_full',
    ['pants'] = 'clothing_pants',
    ['boots'] = 'clothing_boots',
    ['vests'] = 'clothing_vests',
    ['coats'] = 'clothing_coats',
    ['coats_closed'] = 'clothing_coats_closed',
    ['gloves'] = 'clothing_gloves',
    ['neckwear'] = 'clothing_neckwear',
    ['masks'] = 'clothing_masks',
    ['eyewear'] = 'clothing_eyewear',
    ['gunbelts'] = 'clothing_gunbelts',
    ['satchels'] = 'clothing_satchels',
    ['skirts'] = 'clothing_skirts',
    ['chaps'] = 'clothing_chaps',
    ['spurs'] = 'clothing_spurs',
    ['rings_rh'] = 'clothing_rings_rh',
    ['rings_lh'] = 'clothing_rings_lh',
    ['suspenders'] = 'clothing_suspenders',
    ['belts'] = 'clothing_belts',
    ['cloaks'] = 'clothing_cloaks',
    ['ponchos'] = 'clothing_ponchos',
    ['gauntlets'] = 'clothing_gauntlets',
    ['neckties'] = 'clothing_neckties',
    ['holsters_knife'] = 'clothing_holsters_knife',
    ['loadouts'] = 'clothing_loadouts',
    ['holsters_left'] = 'clothing_holsters_left',
    ['holsters_right'] = 'clothing_holsters_right',
    ['holsters_crossdraw'] = 'clothing_holsters_crossdraw',
    ['aprons'] = 'clothing_aprons',
    ['boot_accessories'] = 'clothing_boot_accessories',
    ['spats'] = 'clothing_spats',
    ['jewelry_rings_right'] = 'clothing_rings_rh',
    ['jewelry_rings_left'] = 'clothing_rings_lh',
    ['jewelry_bracelets'] = 'clothing_bracelets',
    ['talisman_holster'] = 'clothing_talisman_holster',
    ['talisman_wrist'] = 'clothing_talisman_wrist',
    ['talisman_belt'] = 'clothing_talisman_belt',
    ['belt_buckles'] = 'clothing_belt_buckles',
    ['bows'] = 'clothing_bows',
    ['hair_accessories'] = 'clothing_hair_accessories',
    ['dresses'] = 'clothing_dresses',
    ['earrings'] = 'clothing_earrings',
    ['armor'] = 'clothing_armor',
}

local itemToCategory = {}
for cat, item in pairs(categoryToItem) do
    itemToCategory[item] = cat
end

-- ==========================================
-- Various accessories
-- ==========================================

local categoryLabels = {
    ['hats'] = 'hat',
    ['shirts_full'] = 'shirts',
    ['pants'] = 'pants',
    ['boots'] = 'boots',
    ['vests'] = 'vests',
    ['coats'] = 'coats',
    ['coats_closed'] = 'coats (closed)',
    ['gloves'] = 'gloves',
    ['neckwear'] = 'neckwear type',
    ['masks'] = 'masks',
    ['eyewear'] = 'eyewear',
    ['gunbelts'] = 'gunbelts',
    ['satchels'] = 'satchels',
    ['skirts'] = 'skirts',
    ['chaps'] = 'chaps',
    ['spurs'] = 'spurs',
    ['rings_rh'] = 'rings (right hand)',
    ['rings_lh'] = 'rings (left)',
    ['suspenders'] = 'suspenders',
    ['belts'] = 'belts',
    ['cloaks'] = 'cloaks',
    ['ponchos'] = 'ponchos',
    ['gauntlets'] = 'gauntlets',
    ['neckties'] = 'neckties',
    ['dresses'] = 'dresses',
    ['holsters_knife'] = 'holster for knife',
    ['loadouts'] = 'loadouts',
    ['holsters_left'] = 'holsters (left)',
    ['holsters_right'] = 'holsters (right)',
    ['holsters_crossdraw'] = 'holsters (crossdraw)',
    ['aprons'] = 'aprons',
    ['boot_accessories'] = 'boot accessories for feet',
    ['spats'] = 'spats',
    ['jewelry_rings_right'] = 'rings (right)',
    ['jewelry_rings_left'] = 'rings (left)',
    ['jewelry_bracelets'] = 'bracelets',
    ['talisman_holster'] = 'talisman (holster)',
    ['talisman_wrist'] = 'talisman (wrist)',
    ['talisman_belt'] = 'talisman (belt)',
    ['belt_buckles'] = 'belt buckles',
    ['bows'] = 'bows',
    ['hair_accessories'] = 'hair accessories for head',
    ['earrings'] = 'earrings',
    ['armor'] = 'armor',
}

local conflictingCategories = {
    ['coats'] = 'coats_closed',
    ['coats_closed'] = 'coats',
    ['cloaks'] = 'ponchos',
    ['ponchos'] = 'cloaks',
}

local function ForceUnequipCategory(Player, src, category)
    if not Player or not category then return false end
    local changed = false

    for slot, invItem in pairs(Player.PlayerData.items) do
        if invItem and invItem.info then
            local invCategory = GetCategoryFromItem(invItem)
            if invCategory == category then
                local invData = GetClothingData(invItem.info)
                if invData and invData.equipped then
                    SetItemEquipped(invItem, false)
                    changed = true
                end
            end
        end
    end

    if playerEquippedClothing[src] then
        playerEquippedClothing[src][category] = nil
    end

    return changed
end

-- ==========================================
-- this is an example
-- ==========================================

local DurabilityConfig = {
    maxDurability = 100,
    totalHoursToBreak = 120,
    checkInterval = 60000,
    --- the state can be chosen to determine maximum durability.
    repairKitItem = 'clothing_repair_kit',
}

DurabilityConfig.degradePerMinute = DurabilityConfig.maxDurability / (DurabilityConfig.totalHoursToBreak * 60)

-- ==========================================
-- state of elements
-- ==========================================

function GetCategoryLabel(category)
    return categoryLabels[category] or category
end

function IsClothingItem(itemName)
    return itemName == 'clothing_item' or itemName == 'clothing_accessories' or itemToCategory[itemName] ~= nil
end

function GetCategoryFromItem(item)
    if not item then return nil end
    
    if itemToCategory[item.name] then
        return itemToCategory[item.name]
    end
    
    -- clothing_item ? clothing_accessories (rsg-clothingstore) - state ? info
    if (item.name == 'clothing_item' or item.name == 'clothing_accessories') and item.info then
        local data = GetClothingData(item.info)
        return data and data.category
    end
    
    return nil
end

function HasClothingInInventory(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then
        return false
    end
    for _, item in pairs(Player.PlayerData.items) do
        if item and IsClothingItem(item.name) then
            return true
        end
    end
    return false
end

function TableLength(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- ==========================================
-- this can affect things
-- ==========================================

function GetClothingData(info)
    if not info or type(info) ~= "table" then return nil end
    return {
        category = info._c or info._category or info.category,
        hash = info._h or info._hash or info.hash,
        model = info._m or info._model or info.model or 0,
        texture = info._t or info._texture or info.texture or 1,
        isMale = info._g or info._isMale or info.isMale,
        equipped = info._e or info._equipped or info.equipped or false,
        durability = info._d or info._durability or info.durability or DurabilityConfig.maxDurability,
        palette = info._p or info._palette or info.palette or 'tint_generic_clean',
        tints = info._tints or info.tints or {0, 0, 0},
        kaf = info._kaf or info.kaf or "Classic",
        draw = info._draw or info.draw or "",
        albedo = info._alb or info.albedo or "",
        normal = info._norm or info.normal or "",
        material = info._mat or info.material or 0,
    }
end

function SetItemEquipped(item, value)
    if not item or not item.info then return end
    
    if item.info._c ~= nil then
        item.info._e = value
    end
    if item.info._category ~= nil then
        item.info._equipped = value
    end
    item.info.equipped = value
end

function GetItemDurability(item)
    if not item or not item.info then return DurabilityConfig.maxDurability end
    local data = GetClothingData(item.info)
    return data and data.durability or DurabilityConfig.maxDurability
end

function GetClothingMetadata(category, durability)
    local quality = math.floor(durability or 100)
    local label = categoryLabels[category] or category
    
    local qualityText = ''
    if quality >= 80 then
        qualityText = 'quality'
    elseif quality >= 60 then
        qualityText = 'higher'
    elseif quality >= 40 then
        qualityText = 'upper'
    elseif quality >= 20 then
        qualityText = 'lower'
    else
        qualityText = 'good'
    end
    
    return {
        label = label,
        quality = quality,
        qualityText = qualityText,
        description = ''
    }
end

function CreateClothingItemInfo(category, hash, model, texture, isMale, equipped, durability, palette, tints)
    durability = durability or DurabilityConfig.maxDurability
    equipped = equipped or false
    palette = palette or 'tint_generic_clean'
    tints = tints or {0, 0, 0}
    
    local metadata = GetClothingMetadata(category, durability)
    
    return {
        _c = category,
        _h = hash,
        _m = model,
        _t = texture,
        _g = isMale,
        _e = equipped,
        _d = durability,
        _q = math.floor(durability),
        _p = palette,
        _tints = tints,
        category = category,
        hash = hash,
        model = model,
        texture = texture,
        isMale = isMale,
        equipped = equipped,
        durability = durability,
        quality = math.floor(durability),
        palette = palette,
        tints = tints,
        label = metadata.label .. ' (' .. math.floor(durability) .. '%)',
        description = metadata.description,
    }
end

function SetItemDurability(item, value)
    if not item or not item.info then return end
    value = math.max(0, math.min(DurabilityConfig.maxDurability, value))
    
    local data = GetClothingData(item.info)
    if not data then return end
    
    local metadata = GetClothingMetadata(data.category, value)
    
    if item.info._c ~= nil then
        item.info._d = value
        item.info._q = math.floor(value)
    elseif item.info._category ~= nil then
        item.info._durability = value
        item.info._quality = math.floor(value)
    else
        item.info.durability = value
    end
    
    item.info.quality = math.floor(value)
    item.info.label = metadata.label .. ' (' .. math.floor(value) .. '%)'
    item.info.description = metadata.description
end

function SetItemColor(item, palette, tints)
    if not item or not item.info then return end
    
    palette = palette or 'tint_generic_clean'
    tints = tints or {0, 0, 0}
    
    if item.info._c ~= nil then
        item.info._p = palette
        item.info._tints = tints
    end
    
    item.info.palette = palette
    item.info.tints = tints
end

-- ==========================================
-- something about ?
-- ==========================================

function SyncClothesToDatabase(src)
    if not UseClothingInventory then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local clothesFromInventory = {}
    for _, item in pairs(Player.PlayerData.items) do
        if item and IsClothingItem(item.name) and item.info then
            local data = GetClothingData(item.info)
            local category = GetCategoryFromItem(item)
            if data and data.equipped and category then
                clothesFromInventory[category] = {
                    hash = data.hash,
                    model = data.model,
                    texture = data.texture,
                    palette = data.palette,
                    tints = data.tints,
                    kaf = data.kaf or "Classic",
                    draw = data.draw or "",
                    albedo = data.albedo or "",
                    normal = data.normal or "",
                    material = data.material or 0,
                }
            end
        end
    end
    
    MySQL.execute('UPDATE playerskins SET clothes = @clothes WHERE citizenid = @citizenid', {
        ['@citizenid'] = Player.PlayerData.citizenid,
        ['@clothes'] = json.encode(clothesFromInventory),
    })
end

-- Syncs clothes to DB synchronously so that the equipped state persists across reloads.
-- Visual update is handled separately by the equipClothing/removeClothing client events.
function SyncClothesAndApply(src)
    if not UseClothingInventory then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local clothesFromInventory = {}
    for _, item in pairs(Player.PlayerData.items) do
        if item and IsClothingItem(item.name) and item.info then
            local data = GetClothingData(item.info)
            local category = GetCategoryFromItem(item)
            if data and data.equipped and category then
                clothesFromInventory[category] = {
                    hash = data.hash,
                    model = data.model,
                    texture = data.texture,
                    palette = data.palette,
                    tints = data.tints,
                    kaf = data.kaf or "Classic",
                    draw = data.draw or "",
                    albedo = data.albedo or "",
                    normal = data.normal or "",
                    material = data.material or 0,
                }
            end
        end
    end

    -- Synchronous save so the DB is current before the player can relog
    MySQL.Sync.execute('UPDATE playerskins SET clothes = @clothes WHERE citizenid = @citizenid', {
        ['@citizenid'] = Player.PlayerData.citizenid,
        ['@clothes'] = json.encode(clothesFromInventory),
    })
end

exports('SyncClothesAndApply', function(src)
    SyncClothesAndApply(src)
end)

-- ==========================================
-- something about quality
-- ==========================================

-- valuation of some kind
local clothingToggleLock = {}

function ToggleClothingItem(source, item, itemName)
    local src = source

    -- Title: character selection recommendations
    if clothingToggleLock[src] then return end
    clothingToggleLock[src] = true

    -- Recommended level is 1 level and 7 quests
    SetTimeout(1000, function()
        clothingToggleLock[src] = nil
    end)

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then clothingToggleLock[src] = nil return end

    -- Recommended quests for appearance (in case of specified callback)
    local currentItem = Player.PlayerData.items[item.slot]
    if not currentItem or currentItem.name ~= item.name then
        clothingToggleLock[src] = nil
        return
    end

    local category = GetCategoryFromItem(currentItem)
    if not category then
        local cData = GetClothingData(currentItem.info)
        if cData then
            category = cData.category
        end
    end
    
    if not category then 
        print('[RSG-Clothing] ERROR: No category found for item')
        clothingToggleLock[src] = nil
        return 
    end
    
    -- Want to share in recommended character options?
    local data = GetClothingData(currentItem.info)
    if not data then 
        print('[RSG-Clothing] ERROR: No clothing data')
        clothingToggleLock[src] = nil
        return 
    end
    
    local durability = data.durability or DurabilityConfig.maxDurability
    local qualityText = '(' .. math.floor(durability) .. '%)'
    
    if durability <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = GetCategoryLabel(category),
            description = 'What great character recommendations!',
            type = 'error'
        })
        clothingToggleLock[src] = nil
        return
    end
    
    if not playerEquippedClothing[src] then
        playerEquippedClothing[src] = {}
    end
    
    local currentSlot = item.slot
    local currentHash = data.hash
    -- Item equipped for recommended characters, in case of callback
    local isCurrentlyEquipped = data.equipped == true
    
    print('[RSG-Clothing] Toggle: category=' .. category .. ', slot=' .. currentSlot .. ', equipped=' .. tostring(isCurrentlyEquipped))
    
    -- Description says: you should see the world that's great too
    if not isCurrentlyEquipped then
        local playerPed = GetPlayerPed(src)
        local playerModel = GetEntityModel(playerPed)
        local playerIsMale = (playerModel == GetHashKey('mp_male'))
        
        if data.isMale ~= nil then
            local clothingIsMale = (data.isMale == true or data.isMale == 1)
            if clothingIsMale ~= playerIsMale then
                local genderName = playerIsMale and 'Male' or 'Female'
                TriggerClientEvent('ox_lib:notify', src, {
                    title = GetCategoryLabel(category),
                    description = 'What great to be ' .. genderName,
                    type = 'error'
                })
                clothingToggleLock[src] = nil
                return
            end
        end
    end
    
    if isCurrentlyEquipped then
        -- Additional options
        SetItemEquipped(Player.PlayerData.items[currentSlot], false)
        Player.Functions.SetInventory(Player.PlayerData.items)
        
        if playerEquippedClothing[src][category] then
            playerEquippedClothing[src][category] = nil
        end
        
        TriggerClientEvent('rsg-clothing:client:playClothingAnim', src, category)
        TriggerClientEvent('rsg-clothing:client:removeClothing', src, category)
        TriggerClientEvent('ox_lib:notify', src, {
            title = GetCategoryLabel(category),
            description = 'Quality ' .. qualityText,
            type = 'info'
        })
        
        print('[RSG-Clothing] Removed: ' .. category)
        SyncClothesAndApply(src)
        -- But recommended characters features in (e.g. equipped=false at some point)
        if GetResourceState('rsg-inventory') ~= 'missing' then
            exports['rsg-inventory']:SaveInventory(src)
        end
        
    else
        -- Recommended options
        -- Recommended replacement-character:
        -- Recommended equipped item other than recommended in favorites (e.g. recommended quest).
        local hasInventoryChanges = false
        for slot, invItem in pairs(Player.PlayerData.items) do
            if invItem and invItem.info then
                local invCategory = GetCategoryFromItem(invItem)
                if invCategory == category and slot ~= currentSlot then
                    local invData = GetClothingData(invItem.info)
                    if invData and invData.equipped then
                        SetItemEquipped(invItem, false)
                        hasInventoryChanges = true
                    end
                end
            end
        end

        -- This user's recommendation is rather informative than equipped in the market.
        local conflictCategory = conflictingCategories[category]
        if conflictCategory then
            for slot, invItem in pairs(Player.PlayerData.items) do
                if invItem and invItem.info then
                    local invCategory = GetCategoryFromItem(invItem)
                    if invCategory == conflictCategory then
                        local invData = GetClothingData(invItem.info)
                        if invData and invData.equipped then
                            SetItemEquipped(invItem, false)
                            hasInventoryChanges = true
                        end
                    end
                end
            end
            playerEquippedClothing[src][conflictCategory] = nil
        end

        SetItemEquipped(Player.PlayerData.items[currentSlot], true)
        hasInventoryChanges = true

        if hasInventoryChanges then
            Player.Functions.SetInventory(Player.PlayerData.items)
        end
        
        playerEquippedClothing[src][category] = {
            slot = currentSlot,
            hash = currentHash,
            itemName = itemName or item.name
        }
        
        TriggerClientEvent('rsg-clothing:client:playClothingAnim', src, category)
        
        TriggerClientEvent('rsg-clothing:client:equipClothing', src, {
            category = category,
            hash = data.hash,
            model = data.model,
            texture = data.texture,
            isMale = data.isMale,
            palette = data.palette,
            tints = data.tints,
            kaf = data.kaf,
            draw = data.draw,
            albedo = data.albedo,
            normal = data.normal,
            material = data.material,
        })
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = GetCategoryLabel(category),
            description = 'Quality ' .. qualityText,
            type = 'success'
        })
        
        print('[RSG-Clothing] Equipped: ' .. category)
        SyncClothesAndApply(src)
        -- But recommended characters have in (e.g. equipped=true at some point)
        if GetResourceState('rsg-inventory') ~= 'missing' then
            exports['rsg-inventory']:SaveInventory(src)
        end
    end
end

-- Recommended items drop, where we find the best spots for new quests
-- Recommended rsg-inventory has amazing clothing_* and other useful for otherplayer-XXX
RegisterNetEvent('rsg-clothing:server:OnGivenToOtherPlayer', function(playerId, fromSlot)
    local src = tonumber(playerId)
    if not src or not fromSlot then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return end

    local item = Player.PlayerData.items[fromSlot]
    if not item or not item.name or not item.info then return end

    if not IsClothingItem(item.name) then return end

    local data = GetClothingData(item.info)
    if not data or not data.equipped then return end

    local category = GetCategoryFromItem(item)
    if not category and data then
        category = data.category
    end
    if not category then return end

    -- equipment article equipped in the inventory of the player
    SetItemEquipped(item, false)

    if playerEquippedClothing[src] and playerEquippedClothing[src][category] then
        playerEquippedClothing[src][category] = nil
    end

    Player.PlayerData.items[fromSlot] = item
    Player.Functions.SetInventory(Player.PlayerData.items)

    -- armor item in the equipment and character characteristics of
    TriggerClientEvent('rsg-clothing:client:removeClothing', src, category)
    SyncClothesToDatabase(src)

    if GetResourceState('rsg-inventory') ~= 'missing' then
        exports['rsg-inventory']:SaveInventory(src)
    end
end)

-- ==========================================
-- character items
-- ==========================================

--- Item 1 slot is assigned in player inventory: in function to remove from item.slot - RemoveItem(..., slot) gives to manipulate inventory.
local function RemoveOneClothingRepairKit(src, Player)
    local name = DurabilityConfig.repairKitItem
    if GetResourceState('rsg-inventory') == 'started' then
        if exports['rsg-inventory']:RemoveItem(src, name, 1, nil, 'clothing-repair') then
            return true
        end
    end
    if Player and Player.Functions and Player.Functions.RemoveItem then
        return Player.Functions.RemoveItem(name, 1, nil, 'clothing-repair') == true
    end
    return false
end

RSGCore.Functions.CreateCallback('rsg-clothing:server:canRepair', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then 
        cb(false) 
        return 
    end
    
    local hasKit = Player.Functions.GetItemByName(DurabilityConfig.repairKitItem)
    cb(hasKit ~= nil)
end)

RSGCore.Functions.CreateCallback('rsg-clothing:server:getClothingForRepair', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then 
        cb({}) 
        return 
    end
    
    local clothingList = {}
    
    for slot, item in pairs(Player.PlayerData.items) do
        if item and IsClothingItem(item.name) and item.info then
            local durability = GetItemDurability(item)
            local category = GetCategoryFromItem(item)
            local categoryLabel = GetCategoryLabel(category)
            
            if durability < DurabilityConfig.maxDurability then
                local data = GetClothingData(item.info)
                
                table.insert(clothingList, {
                    slot = slot,
                    name = item.name,
                    label = categoryLabel or item.label or item.name,
                    category = category,
                    durability = math.floor(durability),
                    equipped = data.equipped or false,
                    hash = data.hash or 0
                })
            end
        end
    end
    
    table.sort(clothingList, function(a, b)
        return a.durability < b.durability
    end)
    
    cb(clothingList)
end)

RegisterNetEvent('rsg-clothing:server:repairFromInventory', function(slot)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local item = Player.PlayerData.items[slot]
    if not item then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Helmet',
            description = 'Provides protection to player',
            type = 'error'
        })
        return
    end
    
    if not IsClothingItem(item.name) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Armor',
            description = 'Has high defense',
            type = 'error'
        })
        return
    end
    
    local repairKit = Player.Functions.GetItemByName(DurabilityConfig.repairKitItem)
    if not repairKit then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Shield',
            description = 'Provides additional defense',
            type = 'error'
        })
        return
    end
    
    local currentDurability = GetItemDurability(item)
    
    if currentDurability >= DurabilityConfig.maxDurability then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Boots',
            description = 'Enhances movement speed',
            type = 'info'
        })
        return
    end
    
    local removed = RemoveOneClothingRepairKit(src, Player)
    
    if not removed then
        print('[RSG-Clothing] ERROR: Failed to remove repair kit!')
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Ring',
            description = 'Increases character attributes significantly',
            type = 'error'
        })
        return
    end
    
    -- save game state for items
    local repairKitData = RSGCore.Shared.Items[DurabilityConfig.repairKitItem]
    if repairKitData then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, repairKitData, 'remove', 1)
    end
    
    -- durability set to 100% (SetItemDurability function item in Player.PlayerData.items[slot])
    local newDurability = DurabilityConfig.maxDurability
    SetItemDurability(item, newDurability)
    
    -- in player's inventory management system (in function GetInventory - in item management system)
    Player.Functions.SetInventory(Player.PlayerData.items)
    
    local category = GetCategoryFromItem(item)
    local categoryLabel = GetCategoryLabel(category) or item.label or item.name
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = categoryLabel,
        description = 'Durability: ' .. math.floor(currentDurability) .. '% to ' .. math.floor(newDurability) .. '%',
        type = 'success'
    })
    
    SetTimeout(100, function()
        TriggerClientEvent('rsg-inventory:client:updateInventory', src)
    end)
    
    print(string.format('[RSG-Clothing] %s repaired %s: %d%% -> %d%%',
        GetPlayerName(src), categoryLabel, math.floor(currentDurability), math.floor(newDurability)))
end)

RegisterNetEvent('rsg-clothing:server:repairClothing', function(slot)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local item = Player.PlayerData.items[slot]
    if not item or not IsClothingItem(item.name) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Gloves',
            description = 'Provides grip to player',
            type = 'error'
        })
        return
    end
    
    local repairKit = Player.Functions.GetItemByName(DurabilityConfig.repairKitItem)
    if not repairKit then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Title',
            description = 'This is a description',
            type = 'error'
        })
        return
    end
    
    local currentDurability = GetItemDurability(item)
    local newDurability = DurabilityConfig.maxDurability
    
    local removed = RemoveOneClothingRepairKit(src, Player)
    
    if not removed then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Title', 
            description = 'In this case, we can say what it is',
            type = 'error'
        })
        return
    end
    
    -- Example for demonstration
    local repairKitData = RSGCore.Shared.Items[DurabilityConfig.repairKitItem]
    if repairKitData then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, repairKitData, 'remove', 1)
    end
    
    SetItemDurability(item, newDurability)
    Player.Functions.SetInventory(Player.PlayerData.items)
    
    local category = GetCategoryFromItem(item)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = GetCategoryLabel(category),
        description = 'Durability: ' .. math.floor(currentDurability) .. '% and ' .. math.floor(newDurability) .. '%',
        type = 'success'
    })
    
    SetTimeout(100, function()
        TriggerClientEvent('rsg-inventory:client:updateInventory', src)
    end)
end)

-- ==========================================
-- Example
-- ==========================================

RegisterNetEvent('rsg-clothing:server:saveToInventory', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local category = data.category
    local hash = data.hash
    local model = data.model
    local texture = data.texture or 1
    local isMale = data.isMale
    local palette = data.palette or 'tint_generic_clean'
    local tints = data.tints or {0, 0, 0}

    if not hash or hash == 0 then return end
    if not model or model <= 0 then return end
    if not category or category == "" then return end

    local itemName = categoryToItem[category] or 'clothing_item'

    for _, item in pairs(Player.PlayerData.items) do
        if item and item.info then
            local itemData = GetClothingData(item.info)
            if itemData and 
               itemData.category == category and 
               itemData.model == model and 
               itemData.texture == texture then
                return
            end
        end
    end

    local info = CreateClothingItemInfo(category, hash, model, texture, isMale, true, 100, palette, tints)

    if Player.Functions.AddItem(itemName, 1, nil, info) then
        Wait(50)
        for slot, item in pairs(Player.PlayerData.items) do
            if item and item.name == itemName and item.info then
                local itemData = GetClothingData(item.info)
                if itemData and 
                   itemData.category == category and 
                   itemData.hash == hash then
                    
                    if not playerEquippedClothing[src] then
                        playerEquippedClothing[src] = {}
                    end
                    
                    if playerEquippedClothing[src][category] then
                        local oldSlot = playerEquippedClothing[src][category].slot
                        if Player.PlayerData.items[oldSlot] then
                            SetItemEquipped(Player.PlayerData.items[oldSlot], false)
                        end
                    end
                    
                    playerEquippedClothing[src][category] = {
                        slot = slot,
                        hash = hash,
                        itemName = itemName
                    }
                    
                    break
                end
            end
        end
    end
end)

RegisterNetEvent('rsg-clothing:server:syncInventoryToDatabase', function()
    SyncClothesToDatabase(source)
end)

RegisterNetEvent('rsg-clothing:server:checkInventorySync')
AddEventHandler('rsg-clothing:server:checkInventorySync', function()
    SyncClothesToDatabase(source)
end)

RegisterNetEvent('rsg-clothing:server:updateClothingColor', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local slot = data.slot
    local palette = data.palette or 'tint_generic_clean'
    local tints = data.tints or {0, 0, 0}
    
    local item = Player.PlayerData.items[slot]
    if not item or not IsClothingItem(item.name) then
        TriggerClientEvent('rsg-clothing-modifier:modificationFailed', src, 'Failed to modify')
        return
    end
    
    SetItemColor(item, palette, tints)
    Player.Functions.SetInventory(Player.PlayerData.items)
    Player.Functions.SaveInventory()
    SyncClothesToDatabase(src)
    
    TriggerClientEvent('rsg-clothing-modifier:modificationSuccess', src)
end)

-- ==========================================
-- Important information
-- ==========================================

function DegradeEquippedClothing(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not playerEquippedClothing[src] then return end
    
    local itemsToRemove = {}
    local needsUpdate = false
    
    for category, equipped in pairs(playerEquippedClothing[src]) do
        local slot = equipped.slot
        local item = Player.PlayerData.items[slot]
        
        if item and IsClothingItem(item.name) then
            local currentDurability = GetItemDurability(item)
            local newDurability = currentDurability - DurabilityConfig.degradePerMinute
            
            if newDurability <= 0 then
                table.insert(itemsToRemove, {
                    category = category,
                    slot = slot,
                    itemName = item.name
                })
            else
                SetItemDurability(item, newDurability)
                needsUpdate = true
                
                local floorValue = math.floor(newDurability)
                if floorValue == 20 or floorValue == 10 or floorValue == 5 then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = GetCategoryLabel(category),
                        description = 'Value: ' .. floorValue .. '% - very important!',
                        type = 'warning'
                    })
                end
            end
        end
    end
    
    for _, data in ipairs(itemsToRemove) do
        Player.Functions.RemoveItem(data.itemName, 1, data.slot)
        playerEquippedClothing[src][data.category] = nil
        
        TriggerClientEvent('rsg-clothing:client:removeClothing', src, data.category)
        TriggerClientEvent('ox_lib:notify', src, {
            title = GetCategoryLabel(data.category),
            description = 'Important message!',
            type = 'error'
        })
    end
    
    if needsUpdate then
        Player.Functions.SetInventory(Player.PlayerData.items)
    end
    
    if #itemsToRemove > 0 then
        SyncClothesToDatabase(src)
    end
end

function CheckPlayerClothing(src)
    if not playerEquippedClothing[src] then return end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then
        playerEquippedClothing[src] = nil
        return
    end
    
    local categoriesToRemove = {}
    
    for category, equipped in pairs(playerEquippedClothing[src]) do
        local expectedHash = equipped.hash
        local expectedItemName = equipped.itemName or 'clothing_item'
        
        local found = false
        local foundSlot = nil
        
        for slot, item in pairs(Player.PlayerData.items) do
            if item and item.name == expectedItemName and item.info then
                local data = GetClothingData(item.info)
                local itemCategory = GetCategoryFromItem(item)
                
                if data and itemCategory == category and data.hash == expectedHash then
                    found = true
                    foundSlot = slot
                    
                    if data.equipped ~= true then
                        SetItemEquipped(item, true)
                        Player.Functions.SetInventory(Player.PlayerData.items)
                    end
                    
                    break
                end
            end
        end
        
        if found then
            if playerEquippedClothing[src][category].slot ~= foundSlot then
                playerEquippedClothing[src][category].slot = foundSlot
            end
        else
            table.insert(categoriesToRemove, category)
        end
    end
    
    if #categoriesToRemove > 0 then
        for _, category in ipairs(categoriesToRemove) do
            playerEquippedClothing[src][category] = nil
            TriggerClientEvent('rsg-clothing:client:removeClothing', src, category)
        end
        SyncClothesToDatabase(src)
    end
end

-- ==========================================
-- CALLBACKS
-- ==========================================

RSGCore.Functions.CreateCallback('rsg-clothing:server:getEquippedClothing', function(source, cb)
    local ok, err = pcall(function()
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then
            cb({})
            return
        end

        local equippedClothes = {}
        local src = source

        local function addEquippedItem(category, data)
            if not category or not data then return end
            equippedClothes[category] = {
                hash = data.hash,
                model = data.model or 0,
                texture = data.texture or 1,
                palette = data.palette or 'tint_generic_clean',
                tints = data.tints or {0, 0, 0},
                kaf = data.kaf or "Classic",
                draw = data.draw or "",
                albedo = data.albedo or "",
                normal = data.normal or "",
                material = data.material or 0,
            }
        end

        -- 1) Important note: Check in playerskins.clothes
        local citizenid = Player.PlayerData.citizenid
        if citizenid then
            local rows = MySQL.Sync.fetchAll('SELECT clothes FROM playerskins WHERE citizenid = ?', { citizenid })
            if rows and rows[1] and rows[1].clothes then
                local okDecode, clothesFromDb = pcall(function()
                    return json.decode(rows[1].clothes or '{}')
                end)
                if okDecode and type(clothesFromDb) == 'table' then
                    for category, data in pairs(clothesFromDb) do
                        if type(data) == 'table' then
                            addEquippedItem(category, data)
                        end
                    end
                end
            end
        end

        if not UseClothingInventory then
            cb(equippedClothes)
            return
        end

        -- 2) Fallback: Use in case of unable to load, check in alternatives/fallback
        if next(equippedClothes) == nil then
            local items = Player.PlayerData.items or {}

            -- System - Check in data.equipped
            for _, item in pairs(items) do
                if item and IsClothingItem(item.name) and item.info then
                    local data = GetClothingData(item.info)
                    local category = GetCategoryFromItem(item)
                    if data and category and data.equipped then
                        addEquippedItem(category, data)
                    end
                end
            end

            -- Status - server-side playerEquippedClothing
            if playerEquippedClothing[src] then
                for category, equipped in pairs(playerEquippedClothing[src]) do
                    if not equippedClothes[category] then
                        local slot = equipped.slot
                        local item = items[slot]
                        if item and IsClothingItem(item.name) and item.info then
                            local data = GetClothingData(item.info)
                            local itemCategory = GetCategoryFromItem(item)
                            if data and itemCategory == category then
                                addEquippedItem(category, data)
                            end
                        end
                    end
                end
            end
        end

        cb(equippedClothes)
    end)
    if not ok then
        print('[rsg-appearance] getEquippedClothing callback error: ' .. tostring(err))
        cb({})
    end
end)

RSGCore.Functions.CreateCallback('rsg-clothing:server:hasClothing', function(source, cb)
    local ok, err = pcall(function()
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then cb(false) return end
        cb(HasClothingInInventory(Player))
    end)
    if not ok then
        print('[rsg-appearance] hasClothing callback error: ' .. tostring(err))
        cb(false)
    end
end)

RSGCore.Functions.CreateCallback('rsg-clothing:server:getInventoryClothing', function(source, cb)
    local ok, err = pcall(function()
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then cb({}) return end
        
        local inventoryClothes = {}
        local items = Player.PlayerData.items or {}
        
        for slot, item in pairs(items) do
        if item and IsClothingItem(item.name) and item.info then
            local data = GetClothingData(item.info)
            local category = GetCategoryFromItem(item)
            
            if data and category and data.model and data.model > 0 and data.equipped then
                inventoryClothes[category] = {
                    model = data.model,
                    texture = data.texture or 1,
                    hash = data.hash,
                    palette = data.palette,
                    tints = data.tints
                }
            end
        end
        end
        
        cb(inventoryClothes)
    end)
    if not ok then
        print('[rsg-appearance] getInventoryClothing callback error: ' .. tostring(err))
        cb({})
    end
end)

RSGCore.Functions.CreateCallback('rsg-clothing-modifier:getPlayerClothing', function(source, cb)
    local ok, err = pcall(function()
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then cb({}) return end
        
        local clothingItems = {}
        local items = Player.PlayerData.items or {}
        
        for slot, item in pairs(items) do
            if item and IsClothingItem(item.name) and item.info then
                local data = GetClothingData(item.info)
                local category = GetCategoryFromItem(item)
                
                if data and category then
                    table.insert(clothingItems, {
                        slot = slot,
                        name = item.name,
                        label = GetCategoryLabel(category),
                        category = category,
                        hash = data.hash,
                        model = data.model,
                        texture = data.texture,
                        palette = data.palette,
                        tints = data.tints,
                        equipped = data.equipped
                    })
                end
            end
        end
        
        table.sort(clothingItems, function(a, b)
            return a.category < b.category
        end)
        
        cb(clothingItems)
    end)
    if not ok then
        print('[rsg-appearance] getPlayerClothing callback error: ' .. tostring(err))
        cb({})
    end
end)

-- ==========================================
-- USEABLE ITEMS - This is important!
-- ==========================================

CreateThread(function()
    if not UseClothingInventory then return end
    Wait(2000)
    
    -- This is a generic clothing_item
    RSGCore.Functions.CreateUseableItem('clothing_item', function(source, item)
        ToggleClothingItem(source, item, 'clothing_item')
    end)
    
    -- clothing_accessories - Important in rsg-clothingstore (hair_accessories, accessories, boot_accessories)
    RSGCore.Functions.CreateUseableItem('clothing_accessories', function(source, item)
        ToggleClothingItem(source, item, 'clothing_accessories')
    end)
    
    -- Additional information about the item
    for category, itemName in pairs(categoryToItem) do
        RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
            ToggleClothingItem(source, item, itemName)
        end)
    end
    
    -- Important specific description
    RSGCore.Functions.CreateUseableItem(DurabilityConfig.repairKitItem, function(source, item)
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then return end
        
        local hasClothingToRepair = false
        for slot, invItem in pairs(Player.PlayerData.items) do
            if invItem and IsClothingItem(invItem.name) and invItem.info then
                local durability = GetItemDurability(invItem)
                if durability < DurabilityConfig.maxDurability then
                    hasClothingToRepair = true
                    break
                end
            end
        end
        
        if not hasClothingToRepair then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Model Name',
                description = 'This is the main interface to facilitate communication',
                type = 'info'
            })
            return
        end
        
        TriggerClientEvent('rsg-clothing:client:openRepairMenu', source)
    end)
    
    print('[RSG-Clothing] All items registered including repair kit')
end)

-- ==========================================
-- Settings
-- ==========================================

CreateThread(function()
    if not UseClothingInventory then return end
    Wait(10000)
    while true do
        Wait(DurabilityConfig.checkInterval)
        for src, _ in pairs(playerEquippedClothing) do
            local Player = RSGCore.Functions.GetPlayer(src)
            if Player then
                DegradeEquippedClothing(src)
            else
                playerEquippedClothing[src] = nil
            end
        end
    end
end)

CreateThread(function()
    if not UseClothingInventory then return end
    Wait(5000)
    while true do
        Wait(5000)
        for src, _ in pairs(playerEquippedClothing) do
            local Player = RSGCore.Functions.GetPlayer(src)
            if Player then
                CheckPlayerClothing(src)
            else
                playerEquippedClothing[src] = nil
            end
        end
    end
end)

-- ==========================================
-- LIB CALLBACKS
-- ==========================================

lib.callback.register('rsg-appearance:server:LoadClothes', function(source)
    if not UseClothingInventory then return {} end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end
    
    local clothesData = {}
    
    for slot, item in pairs(Player.PlayerData.items) do
        if item and IsClothingItem(item.name) and item.info then
            local data = GetClothingData(item.info)
            local category = GetCategoryFromItem(item)
            
            if data and category then
                if not clothesData[category] then
                    clothesData[category] = {}
                end
                
                table.insert(clothesData[category], {
                    slot = slot,
                    model = data.model or 0,
                    texture = data.texture or 1,
                    hash = data.hash,
                    equipped = data.equipped or false,
                    durability = data.durability or 100,
                    palette = data.palette,
                    tints = data.tints
                })
            end
        end
    end
    
    return clothesData
end)

-- ==========================================
-- Additional and external settings
-- ==========================================

RegisterNetEvent('rsg-appearance:server:GiveStarterClothing')
AddEventHandler('rsg-appearance:server:GiveStarterClothing', function(clothesData, isMale)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not UseClothingInventory then
        TriggerEvent('rsg-clothingstore:server:grantStarterClothing', src, clothesData, isMale)
        return
    end
    
    local gender = isMale and 'male' or 'female'
    local clothing = nil
    
    pcall(function()
        clothing = require('data.clothing')
    end)
    
    local function GetHashFromClothing(category, model, texture)
        if not clothing then return 0 end
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
    
    local categories = {'shirts_full', 'pants', 'boots'}
    for _, cat in ipairs(categories) do
        if clothesData[cat] then
            local data = clothesData[cat]
            local model = type(data) == 'table' and (data.model or 0) or data
            local hash = type(data) == 'table' and (data.hash or 0) or 0
            local texture = type(data) == 'table' and (data.texture or 1) or 1
            
            if (not hash or hash == 0) and model > 0 then
                hash = GetHashFromClothing(cat, model, texture)
            end
            
            if model > 0 and hash and hash ~= 0 then
                local info = CreateClothingItemInfo(cat, hash, model, texture, isMale, true, 100)
                Player.Functions.AddItem(categoryToItem[cat] or 'clothing_item', 1, nil, info)
            end
        end
    end
end)

RegisterNetEvent('rsg-appearance:server:buyClothes')
AddEventHandler('rsg-appearance:server:buyClothes', function(purchasedItems, totalPrice)
    local src = source
    if not UseClothingInventory then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Clothing Store',
            description = 'Use the clothing store or /wardrobe for clothing changes.',
            type = 'error'
        })
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local playerMoney = Player.Functions.GetMoney('cash')
    if playerMoney < totalPrice then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Text',
            description = 'Detailed description',
            type = 'error'
        })
        return
    end
    
    Player.Functions.RemoveMoney('cash', totalPrice, 'clothing-purchase')
    
    if not playerEquippedClothing[src] then
        playerEquippedClothing[src] = {}
    end

    local inventoryStateChanged = false

    for _, item in ipairs(purchasedItems) do
        if item.category and item.hash then
            -- Replace-Text with the Toggle:
            -- A detailed overview of how this works (and options) can be found in documentation.
            if ForceUnequipCategory(Player, src, item.category) then
                inventoryStateChanged = true
            end
            local conflictCategory = conflictingCategories[item.category]
            if conflictCategory and ForceUnequipCategory(Player, src, conflictCategory) then
                inventoryStateChanged = true
            end

            local itemName = categoryToItem[item.category] or 'clothing_item'
            local info = CreateClothingItemInfo(
                item.category,
                item.hash,
                item.model or 0,
                item.texture or 1,
                item.isMale,
                true,
                100,
                item.palette or 'tint_generic_clean',
                item.tints or {0, 0, 0}
            )
            
            if Player.Functions.AddItem(itemName, 1, nil, info) then
                -- Additional text stating how the server equipped-cache.
                for slot, invItem in pairs(Player.PlayerData.items) do
                    if invItem and invItem.name == itemName and invItem.info then
                        local invData = GetClothingData(invItem.info)
                        local invCategory = GetCategoryFromItem(invItem)
                        if invData and invCategory == item.category and invData.equipped and invData.hash == item.hash then
                            playerEquippedClothing[src][item.category] = {
                                slot = slot,
                                hash = invData.hash,
                                itemName = itemName
                            }
                            break
                        end
                    end
                end
            end
        end
    end

    if inventoryStateChanged then
        Player.Functions.SetInventory(Player.PlayerData.items)
    end

    SyncClothesToDatabase(src)
    if GetResourceState('rsg-inventory') ~= 'missing' then
        exports['rsg-inventory']:SaveInventory(src)
    end
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Item Name',
        description = 'Purchase a total of $' .. totalPrice .. ' items',
        type = 'success'
    })
end)

-- ==========================================
-- Check whether playerEquippedClothing has specific items equipped
-- If certain conditions are met regarding required clothing,
-- CheckPlayerClothing/degradation to ensure optimal functioning.
-- ==========================================

RegisterNetEvent('RSGCore:Server:OnPlayerLoaded', function()
    local src = source
    if not UseClothingInventory then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    playerEquippedClothing[src] = {}

    for slot, item in pairs(Player.PlayerData.items) do
        if item and IsClothingItem(item.name) and item.info then
            local data = GetClothingData(item.info)
            local category = GetCategoryFromItem(item)

            if data and category and data.equipped then
                playerEquippedClothing[src][category] = {
                    slot = slot,
                    hash = data.hash,
                    itemName = item.name
                }
            end
        end
    end

    local count = TableLength(playerEquippedClothing[src])
    print('[RSG-Clothing] Restored ' .. count .. ' equipped items for player ' .. GetPlayerName(src))
end)

-- ==========================================
-- CLEANUP
-- ==========================================

AddEventHandler('playerDropped', function()
    playerEquippedClothing[source] = nil
    starterGivenTo[source] = nil
end)

print('[RSG-Clothing] Server v3.1 FIXED loaded')
