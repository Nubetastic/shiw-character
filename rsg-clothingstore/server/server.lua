local RSGCore = exports['rsg-core']:GetCoreObject()

local StoreToCityMapping = {
    blackwater = 'blackwater',
    rhodes = 'saintdenis',
    sd = 'saintdenis',
}

local function DecodeTable(value, fallback)
    if type(value) == 'table' then return value end
    if not value or value == '' then return fallback or {} end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or (fallback or {})
end

local function NormalizeHash(value)
    if type(value) == 'number' then return value end
    if type(value) ~= 'string' or value == '' or value == '_' then return 0 end
    local cleaned = value:gsub('^0[xX]', '')
    return tonumber(cleaned, 16) or tonumber(value) or 0
end

local function NormalizeItem(item, isMale)
    if type(item) ~= 'table' then return nil end

    local category = item.category or item._c
    if not category then return nil end

    local kaf = item.Kaf or item.kaf or item._kaf or 'Classic'
    local draw = item.Draw or item.draw or item._draw or ''
    local hash = NormalizeHash(item.Hash or item.hash or item._h)
    if hash == 0 and kaf == 'Ped' and draw ~= '' and draw ~= '_' then
        hash = GetHashKey(draw)
    end

    local palette = item.pal or item.palette or item._p or 'tint_generic_clean'
    if palette == '' or palette == ' ' then palette = 'tint_generic_clean' end
    local sourceTints = item.tints or item._tints
    local tints = {
        tonumber(sourceTints and sourceTints[1] or item.palette1) or 0,
        tonumber(sourceTints and sourceTints[2] or item.palette2) or 0,
        tonumber(sourceTints and sourceTints[3] or item.palette3) or 0,
    }

    local itemIsMale = item.isMale
    if itemIsMale == nil then itemIsMale = isMale end
    local normalized = {
        key = item.key,
        name = item.name or item.label or category,
        category = category,
        hash = hash,
        model = tonumber(item.model or item._m) or 0,
        texture = tonumber(item.texture or item._t) or 1,
        palette = palette,
        tints = tints,
        kaf = kaf,
        draw = draw,
        albedo = item.alb or item.albedo or item._alb or '',
        normal = item.norm or item.normal or item._norm or '',
        material = item.mat or item.material or item._mat or 0,
        isMale = itemIsMale,
        price = tonumber(item.price) or 0,
    }

    if not normalized.key or normalized.key == '' then
        local sex = normalized.isMale and 'male' or 'female'
        local parts
        if kaf == 'Ped' then
            parts = {
                sex, category, kaf, draw, normalized.albedo, normalized.normal,
                tostring(normalized.material), palette,
                tostring(tints[1]), tostring(tints[2]), tostring(tints[3])
            }
        else
            parts = { sex, category, kaf, string.format('%08X', hash & 0xFFFFFFFF) }
        end
        normalized.key = table.concat(parts, ':'):lower()
    end

    return normalized
end

local function NormalizeOutfit(outfit, isMale)
    local result = {}
    if type(outfit) ~= 'table' then return result end
    for category, item in pairs(outfit) do
        if type(item) == 'table' then
            local copy = {}
            for key, value in pairs(item) do copy[key] = value end
            copy.category = copy.category or category
            local normalized = NormalizeItem(copy, isMale)
            if normalized then
                normalized.price = nil
                result[category] = normalized
            end
        end
    end
    return result
end

local function EnsurePlayerClothes(citizenid)
    MySQL.Sync.execute([[
        INSERT IGNORE INTO playerclothes (citizenid, bought, outfit)
        VALUES (?, ?, ?)
    ]], { citizenid, '{}', '[]' })
end

local function GetPlayerClothes(citizenid)
    EnsurePlayerClothes(citizenid)
    local rows = MySQL.Sync.fetchAll(
        'SELECT bought, outfit FROM playerclothes WHERE citizenid = ? LIMIT 1',
        { citizenid }
    )
    local row = rows and rows[1] or {}
    local bought = DecodeTable(row.bought, {})
    local outfits = DecodeTable(row.outfit, {})
    local removedBarberData = false
    for _, entry in ipairs(outfits) do
        if type(entry) == 'table' and entry.barberStyle ~= nil then
            entry.barberStyle = nil
            removedBarberData = true
        end
    end
    if removedBarberData then
        MySQL.Sync.execute('UPDATE playerclothes SET outfit = ? WHERE citizenid = ?', {
            json.encode(outfits), citizenid
        })
    end
    return bought, outfits
end

local function SavePlayerClothes(citizenid, bought, outfits)
    EnsurePlayerClothes(citizenid)
    local ok = pcall(function()
        MySQL.Sync.execute(
            'UPDATE playerclothes SET bought = ?, outfit = ? WHERE citizenid = ?',
            { json.encode(bought or {}), json.encode(outfits or {}), citizenid }
        )
    end)
    return ok
end

local function GetActiveClothes(src)
    local ok, clothes = pcall(function()
        return exports['rsg-appearance']:GetActiveClothes(src)
    end)
    return ok and type(clothes) == 'table' and clothes or {}
end

local function SaveActiveClothes(src, clothes)
    local ok, saved = pcall(function()
        return exports['rsg-appearance']:SaveActiveClothes(src, clothes)
    end)
    return ok and saved == true
end

local function IsBought(bought, category, key)
    local list = bought[category]
    if type(list) ~= 'table' then return false end
    for _, item in ipairs(list) do
        if type(item) == 'table' and item.key == key then return true end
    end
    return false
end

CreateThread(function()
    MySQL.Sync.execute([[
        CREATE TABLE IF NOT EXISTS playerclothes (
            citizenid VARCHAR(50) NOT NULL,
            bought LONGTEXT NOT NULL,
            outfit LONGTEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], {})
end)

RSGCore.Functions.CreateCallback('rsg-clothingstore:server:getSessionData', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end
    local bought, outfits = GetPlayerClothes(Player.PlayerData.citizenid)
    cb({
        bought = bought,
        outfits = outfits,
        activeClothes = GetActiveClothes(source),
        money = Player.PlayerData.money.cash or 0,
    })
end)

RSGCore.Functions.CreateCallback('rsg-clothingstore:server:commitPurchase', function(source, cb, payload)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or type(payload) ~= 'table' then cb({ success = false, reason = 'Invalid purchase' }) return end

    local totalPrice = math.max(0, tonumber(payload.totalPrice) or 0)
    if (Player.PlayerData.money.cash or 0) < totalPrice then
        cb({ success = false, reason = 'Not enough money' })
        return
    end

    local ped = GetPlayerPed(source)
    local isMale = ped ~= 0 and GetEntityModel(ped) == GetHashKey('mp_male')
    local visibleOutfit = NormalizeOutfit(payload.visibleOutfit, isMale)
    local bought, outfits = GetPlayerClothes(Player.PlayerData.citizenid)
    local previousBought = DecodeTable(json.encode(bought), {})
    local added = {}

    for category, item in pairs(payload.items or {}) do
        local normalized = NormalizeItem(item, isMale)
        if normalized then
            category = normalized.category or category
            bought[category] = type(bought[category]) == 'table' and bought[category] or {}
            if not IsBought(bought, category, normalized.key) then
                table.insert(bought[category], normalized)
                table.insert(added, normalized)
            end
        end
    end

    local removed = totalPrice == 0 or Player.Functions.RemoveMoney('cash', totalPrice, 'clothing-purchase')
    if not removed then cb({ success = false, reason = 'Not enough money' }) return end

    if not SavePlayerClothes(Player.PlayerData.citizenid, bought, outfits) then
        if totalPrice > 0 then Player.Functions.AddMoney('cash', totalPrice, 'clothing-refund') end
        cb({ success = false, reason = 'Unable to save purchased clothing' })
        return
    end
    if not SaveActiveClothes(source, visibleOutfit) then
        SavePlayerClothes(Player.PlayerData.citizenid, previousBought, outfits)
        if totalPrice > 0 then Player.Functions.AddMoney('cash', totalPrice, 'clothing-refund') end
        cb({ success = false, reason = 'Unable to save clothing' })
        return
    end

    local cityId = StoreToCityMapping[payload.storeId]
    if cityId and totalPrice > 0 then
        local info = Player.PlayerData.charinfo
        TriggerEvent('shiw-government:server:shopPurchase', 'clothing-' .. tostring(payload.storeId), totalPrice,
            Player.PlayerData.citizenid, (info.firstname or '') .. ' ' .. (info.lastname or ''), cityId)
    end

    cb({
        success = true,
        bought = bought,
        outfits = outfits,
        activeClothes = visibleOutfit,
        added = added,
        newMoney = Player.PlayerData.money.cash or 0,
    })
end)

RSGCore.Functions.CreateCallback('rsg-clothingstore:server:applyOutfit', function(source, cb, outfit)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb({ success = false, reason = 'Player not found' }) return end
    local isMale = GetEntityModel(GetPlayerPed(source)) == GetHashKey('mp_male')
    local normalized = NormalizeOutfit(outfit, isMale)
    if not SaveActiveClothes(source, normalized) then
        cb({ success = false, reason = 'Unable to save clothing' })
        return
    end
    cb({ success = true, activeClothes = normalized, newMoney = Player.PlayerData.money.cash or 0 })
end)

RSGCore.Functions.CreateCallback('rsg-clothingstore:server:saveOutfit', function(source, cb, outfit)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb({ success = false, reason = 'Player not found' }) return end
    local isMale = GetEntityModel(GetPlayerPed(source)) == GetHashKey('mp_male')
    local normalized = NormalizeOutfit(outfit, isMale)
    local bought, outfits = GetPlayerClothes(Player.PlayerData.citizenid)
    outfits[#outfits + 1] = { clothes = normalized, createdAt = os.time() }
    if not SavePlayerClothes(Player.PlayerData.citizenid, bought, outfits) then
        cb({ success = false, reason = 'Unable to save outfit' })
        return
    end
    cb({ success = true, outfits = outfits, selectedIndex = #outfits - 1 })
end)

RSGCore.Functions.CreateCallback('rsg-clothingstore:server:deleteOutfit', function(source, cb, zeroBasedIndex)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb({ success = false, reason = 'Player not found' }) return end
    local bought, outfits = GetPlayerClothes(Player.PlayerData.citizenid)
    local index = (tonumber(zeroBasedIndex) or -1) + 1
    if index < 1 or index > #outfits then
        cb({ success = false, reason = 'Outfit not found' })
        return
    end
    table.remove(outfits, index)
    if not SavePlayerClothes(Player.PlayerData.citizenid, bought, outfits) then
        cb({ success = false, reason = 'Unable to delete outfit' })
        return
    end
    cb({ success = true, outfits = outfits, selectedIndex = math.max(0, math.min(index - 1, #outfits - 1)) })
end)

AddEventHandler('rsg-clothingstore:server:grantStarterClothing', function(src, clothesData, isMale)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(clothesData) ~= 'table' then return end
    local bought, outfits = GetPlayerClothes(Player.PlayerData.citizenid)
    for category, item in pairs(clothesData) do
        if type(item) == 'table' then
            local copy = {}
            for key, value in pairs(item) do copy[key] = value end
            copy.category = copy.category or category
            local normalized = NormalizeItem(copy, isMale)
            if normalized then
                bought[category] = type(bought[category]) == 'table' and bought[category] or {}
                if not IsBought(bought, category, normalized.key) then
                    table.insert(bought[category], normalized)
                end
            end
        end
    end

    -- A clean character should always begin with one reusable outfit. This is
    -- intentionally idempotent: creator/fallback events may repeat, but an
    -- existing outfit list is never overwritten or appended to here.
    if #outfits == 0 then
        local starterOutfit = NormalizeOutfit(clothesData, isMale)
        if next(starterOutfit) then
            outfits[1] = {
                clothes = starterOutfit,
                createdAt = os.time(),
            }
        end
    end

    SavePlayerClothes(Player.PlayerData.citizenid, bought, outfits)
end)
