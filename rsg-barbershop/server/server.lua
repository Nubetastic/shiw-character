local RSGCore = exports['rsg-core']:GetCoreObject()

local function DecodeLooks(value)
    if type(value) == 'table' then return value end
    if not value or value == '' then return {} end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or {}
end

local function EnsureLooksRow(citizenid)
    MySQL.Sync.execute('INSERT IGNORE INTO playerbarberlooks (citizenid, looks) VALUES (?, ?)', {
        citizenid, '[]'
    })
end

local function GetLooks(citizenid)
    EnsureLooksRow(citizenid)
    local rows = MySQL.Sync.fetchAll('SELECT looks FROM playerbarberlooks WHERE citizenid = ? LIMIT 1', { citizenid })
    return DecodeLooks(rows and rows[1] and rows[1].looks)
end

local function SaveLooks(citizenid, looks)
    EnsureLooksRow(citizenid)
    local ok = pcall(function()
        MySQL.Sync.execute('UPDATE playerbarberlooks SET looks = ? WHERE citizenid = ?', {
            json.encode(looks or {}), citizenid
        })
    end)
    return ok
end

CreateThread(function()
    MySQL.Sync.execute([[
        CREATE TABLE IF NOT EXISTS playerbarberlooks (
            citizenid VARCHAR(50) NOT NULL,
            looks LONGTEXT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], {})
end)

AddEventHandler('rsg-barbershop:server:saveInitialLook', function(src, style)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(style) ~= 'table' then return end
    local looks = GetLooks(Player.PlayerData.citizenid)
    if #looks > 0 then return end
    looks[1] = {
        style = DecodeLooks(json.encode(style)),
        createdAt = os.time(),
        initial = true,
    }
    SaveLooks(Player.PlayerData.citizenid, looks)
end)

-- ==========================================
-- CONVERT COLOR FROM SUFFIX TO INDEX
-- ==========================================
local function GetColorIndexFromSuffix(suffix)
    local colorMap = {
        ["BLONDE"] = 1,
        ["BROWN"] = 2,
        ["DARKEST_BROWN"] = 3,
        ["DARK_BLONDE"] = 4,
        ["DARK_GINGER"] = 5,
        ["DARK_GREY"] = 6,
        ["GINGER"] = 7,
        ["GREY"] = 8,
        ["JET_BLACK"] = 9,
        ["LIGHT_BLONDE"] = 10,
        ["RED_GINGER"] = 11,
    }
    return colorMap[suffix] or 1
end

-- ==========================================
-- PURCHASE STYLE
-- ==========================================
RegisterNetEvent('rsg-barbershop:server:buyStyle', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player then return end

    data = type(data) == 'table' and data or {}
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.Sync.fetchAll('SELECT skin FROM playerskins WHERE citizenid = ?', { citizenid })
    local skin = result and result[1] and result[1].skin and json.decode(result[1].skin) or nil

    local function OverlayChanged(values, keys)
        if not skin or type(values) ~= 'table' then return values ~= nil end
        for _, key in ipairs(keys) do
            if values[key] ~= nil and tonumber(values[key]) ~= tonumber(skin[key]) then return true end
        end
        return false
    end

    local barberStyle = nil
    if skin then
        if data.hair then
            local alreadyRemoved = data.hair.remove and not skin.hair_hashname and (tonumber(skin.hair) or 0) == 0
            local sameHair = data.hair.hashname and data.hair.hashname == skin.hair_hashname
            if alreadyRemoved or sameHair then data.hair = nil end
        end
        if data.beard then
            local alreadyRemoved = data.beard.remove and not skin.beard_hashname and (tonumber(skin.beard) or 0) == 0
            local sameBeard = data.beard.hashname and data.beard.hashname == skin.beard_hashname
            if alreadyRemoved or sameBeard then data.beard = nil end
        end

        local eyebrowKeys = {'eyebrows_t', 'eyebrows_op', 'eyebrows_id', 'eyebrows_c1'}
        if not OverlayChanged(data.eyebrows, eyebrowKeys) then data.eyebrows = nil end

        local makeupKeys = {
            'shadows_t','shadows_op','shadows_id','shadows_c1',
            'blush_t','blush_op','blush_id','blush_c1',
            'lipsticks_t','lipsticks_op','lipsticks_id','lipsticks_c1','lipsticks_c2',
            'eyeliners_t','eyeliners_op','eyeliners_id','eyeliners_c1'
        }
        if not OverlayChanged(data.makeup, makeupKeys) then data.makeup = nil end
    end

    local totalPrice = 0

    if data.eyebrows and type(data.eyebrows) == 'table' and next(data.eyebrows) then
        totalPrice = totalPrice + (Config.Prices.eyebrows or 12.0)
    end
    if data.makeup and type(data.makeup) == 'table' and next(data.makeup) then
        totalPrice = totalPrice + (Config.Prices.makeup or 15.0)
    end
    if data.hair then
        if data.hair.remove then
            totalPrice = totalPrice + (Config.Prices.hairShave or Config.Prices.hair * 0.5 or 15.0)
        elseif data.hair.hashname then
            totalPrice = totalPrice + (Config.Prices.hair or 2.50)
        end
    end
    if data.beard and (data.beard.hashname or data.beard.remove) then
        totalPrice = totalPrice + (data.beard.remove and (Config.Prices.beard or 1.50) * 0.5 or (Config.Prices.beard or 1.50))
    end

    local playerMoney = Player.PlayerData.money.cash or 0

    if playerMoney < totalPrice then
        TriggerClientEvent('rsg-barbershop:client:purchaseFailed', src, 'Insufficient funds')
        return
    end

    local success = Player.Functions.RemoveMoney('cash', totalPrice, 'barbershop-service')

    if not success then
        TriggerClientEvent('rsg-barbershop:client:purchaseFailed', src, 'Payment error')
        return
    end

    local newMoney = Player.PlayerData.money.cash

    -- ==========================================
    -- UPDATE SKIN IN DATABASE
    -- ==========================================

    if skin then

        -- Update hair
        if data.hair then
            if data.hair.remove then
                skin.hair = 0
                skin.hair_color = 0
                skin.hair_hashname = nil
                print('[RSG-Barbershop] Removing hair (shave)')
            elseif data.hair.hashname then
                -- FIX: ALWAYS save hashname — it's the source of truth when loading
                -- LoadHair in rsg-appearance checks hair_hashname first
                skin.hair_hashname = data.hair.hashname

                -- Parse hashname to get model and color (fallback)
                -- Format: CLOTHING_ITEM_M_HAIR_001_BLONDE or CLOTHING_ITEM_F_HAIR_001_BLONDE
                local styleNum, colorSuffix = string.match(data.hair.hashname, "CLOTHING_ITEM_[MF]_HAIR_(%d+)_(.+)")

                if styleNum then
                    skin.hair = tonumber(styleNum) or 1
                    skin.hair_color = GetColorIndexFromSuffix(colorSuffix) or 1
                else
                    print('[RSG-Barbershop] WARNING: Could not parse hair hashname: ' .. tostring(data.hair.hashname))
                end

                print('[RSG-Barbershop] Saving hair: hashname=' .. tostring(data.hair.hashname) ..
                      ' model=' .. tostring(skin.hair) .. ' color=' .. tostring(skin.hair_color))
            end
        end

        -- Update eyebrows (overlays)
        if data.eyebrows and type(data.eyebrows) == 'table' and next(data.eyebrows) then
            for _, k in ipairs({'eyebrows_t', 'eyebrows_op', 'eyebrows_id', 'eyebrows_c1'}) do
                if data.eyebrows[k] ~= nil then
                    skin[k] = data.eyebrows[k]
                end
            end
            print('[RSG-Barbershop] Saving eyebrows overlays')
        end

        -- Update makeup (overlays)
        if data.makeup and type(data.makeup) == 'table' and next(data.makeup) then
            local overlayKeys = {
                'shadows_t','shadows_op','shadows_id','shadows_c1',
                'blush_t','blush_op','blush_id','blush_c1',
                'lipsticks_t','lipsticks_op','lipsticks_id','lipsticks_c1','lipsticks_c2',
                'eyeliners_t','eyeliners_op','eyeliners_id','eyeliners_c1'
            }
            for _, k in ipairs(overlayKeys) do
                if data.makeup[k] ~= nil then
                    skin[k] = data.makeup[k]
                end
            end
            print('[RSG-Barbershop] Saving makeup overlays')
        end

        -- Update beard
        if data.beard then
            if data.beard.remove then
                -- Remove beard
                skin.beard = 0
                skin.beard_color = 0
                skin.beard_hashname = nil
                print('[RSG-Barbershop] Removing beard')
            elseif data.beard.hashname then
                -- FIX: ALWAYS save hashname — it's the source of truth when loading
                -- LoadBeard in rsg-appearance checks beard_hashname first
                skin.beard_hashname = data.beard.hashname

                -- Parse hashname to get model and color (fallback)
                -- FIX: Support formats BEARD, MUSTACHE and BEARDS_COMPLETE
                local styleNum, colorSuffix = string.match(data.beard.hashname, "CLOTHING_ITEM_M_BEARD_(%d+)_(.+)")

                if not styleNum then
                    styleNum, colorSuffix = string.match(data.beard.hashname, "CLOTHING_ITEM_M_MUSTACHE_(%d+)_(.+)")
                end

                if not styleNum then
                    styleNum, colorSuffix = string.match(data.beard.hashname, "CLOTHING_ITEM_M_BEARDS_COMPLETE_(%d+)_(.+)")
                end

                if styleNum then
                    skin.beard = tonumber(styleNum) or 1
                    skin.beard_color = GetColorIndexFromSuffix(colorSuffix) or 1
                else
                    print('[RSG-Barbershop] WARNING: Could not parse beard hashname: ' .. tostring(data.beard.hashname))
                end

                print('[RSG-Barbershop] Saving beard: hashname=' .. tostring(data.beard.hashname) ..
                      ' model=' .. tostring(skin.beard) .. ' color=' .. tostring(skin.beard_color))
            end
        end

        -- Save updated skin
        local encodedSkin = json.encode(skin)
        MySQL.Async.execute('UPDATE playerskins SET skin = @skin WHERE citizenid = @citizenid', {
            ['@skin'] = encodedSkin,
            ['@citizenid'] = citizenid
        }, function(rowsChanged)
            print('[RSG-Barbershop] Updated skin in database, rows changed: ' .. tostring(rowsChanged))
        end)

        local ok, style = pcall(function()
            return exports['rsg-appearance']:BuildBarberStyle(skin)
        end)
        if ok and type(style) == 'table' then
            barberStyle = style
            Player.Functions.SetMetaData('barberStyle', barberStyle)
        end
    else
        print('[RSG-Barbershop] ERROR: No skin found for citizenid ' .. citizenid)
    end

    TriggerClientEvent('rsg-barbershop:client:purchaseSuccess', src, newMoney, data.hair, data.beard, data.eyebrows, data.makeup, barberStyle)

    print(string.format('[RSG-Barbershop] %s %s - services $%.2f',
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname,
        totalPrice
    ))
end)

-- ==========================================
-- CALLBACK TO GET PLAYER MONEY
-- ==========================================
RSGCore.Functions.CreateCallback('rsg-barbershop:server:getPlayerMoney', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        cb(Player.PlayerData.money.cash or 0)
    else
        cb(0)
    end
end)

RSGCore.Functions.CreateCallback('rsg-barbershop:server:getLooks', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    cb(GetLooks(Player.PlayerData.citizenid))
end)

RSGCore.Functions.CreateCallback('rsg-barbershop:server:saveLook', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb({ success = false, reason = 'Player not found' }) return end
    local style = Player.PlayerData.metadata and Player.PlayerData.metadata.barberStyle
    if type(style) ~= 'table' then
        cb({ success = false, reason = 'No paid barber style is available' })
        return
    end
    local looks = GetLooks(Player.PlayerData.citizenid)
    looks[#looks + 1] = {
        style = DecodeLooks(json.encode(style)),
        createdAt = os.time(),
    }
    if not SaveLooks(Player.PlayerData.citizenid, looks) then
        cb({ success = false, reason = 'Unable to save look' })
        return
    end
    cb({ success = true, looks = looks, selectedIndex = #looks })
end)

RSGCore.Functions.CreateCallback('rsg-barbershop:server:deleteLook', function(source, cb, zeroBasedIndex)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb({ success = false, reason = 'Player not found' }) return end
    local looks = GetLooks(Player.PlayerData.citizenid)
    local index = (tonumber(zeroBasedIndex) or -1) + 1
    if index < 1 or index > #looks then
        cb({ success = false, reason = 'Look not found' })
        return
    end
    table.remove(looks, index)
    if not SaveLooks(Player.PlayerData.citizenid, looks) then
        cb({ success = false, reason = 'Unable to delete look' })
        return
    end
    cb({ success = true, looks = looks, selectedIndex = #looks > 0 and math.min(index, #looks) or 0 })
end)

RSGCore.Functions.CreateCallback('rsg-barbershop:server:applyLook', function(source, cb, zeroBasedIndex)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb({ success = false, reason = 'Player not found' }) return end
    local looks = GetLooks(Player.PlayerData.citizenid)
    local index = (tonumber(zeroBasedIndex) or -1) + 1
    local entry = looks[index]
    if not entry or type(entry.style) ~= 'table' then
        cb({ success = false, reason = 'Look not found' })
        return
    end
    local ok, style = pcall(function()
        return exports['rsg-appearance']:SaveBarberStyle(source, entry.style)
    end)
    if not ok or type(style) ~= 'table' then
        cb({ success = false, reason = 'Unable to apply look' })
        return
    end
    cb({ success = true, style = style, selectedIndex = index })
end)
