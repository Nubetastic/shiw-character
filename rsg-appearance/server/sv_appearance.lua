print('===========================================')
print('[RSG-Appearance] sv_appearance.lua LOADING')
print('===========================================')
RSGCore = exports['rsg-core']:GetCoreObject()
print('[RSG-Appearance] RSGCore loaded: ' .. tostring(RSGCore ~= nil))

-- Forward declaration so it can be called before its definition
local SetPlayerAppearanceState

-- What is the appropriate model?hash for synchronization (which kinds of models)
local _clothingTable = nil
local function GetClothingTable()
    if _clothingTable then return _clothingTable end
    local ok, tbl = pcall(function() return require('data.clothing') end)
    _clothingTable = ok and tbl or nil
    return _clothingTable
end

-- What is the appropriate model/texture and hash for synchronization (which types of models do exist)
local function ResolveClothesHashes(skin, clothes)
    if not clothes or next(clothes) == nil then return clothes end
    local clothing = GetClothingTable()
    if not clothing then return clothes end

    local isMale = (skin and tonumber(skin.sex) or 1) == 1
    local gender = isMale and 'male' or 'female'

    local function resolveHash(category, model, texture, hairModelForAccessories)
        if not model or tonumber(model) <= 0 then return 0 end
        model = tonumber(model)
        texture = tonumber(texture) or 1
        if category == 'hair_accessories' and not isMale and hairModelForAccessories and hairModelForAccessories >= 1 then
            model = hairModelForAccessories
        end
        if clothing[gender] and clothing[gender][category] then
            if clothing[gender][category][model] then
                if clothing[gender][category][model][texture] then
                    return clothing[gender][category][model][texture].hash
                elseif clothing[gender][category][model][1] then
                    return clothing[gender][category][model][1].hash
                end
            elseif category == 'hair_accessories' and clothing[gender][category][1] then
                if clothing[gender][category][1][texture] then
                    return clothing[gender][category][1][texture].hash
                elseif clothing[gender][category][1][1] then
                    return clothing[gender][category][1][1].hash
                end
            end
        end
        return 0
    end

    local hairModel = skin and skin.hair and type(skin.hair) == 'table' and tonumber(skin.hair.model) or nil
    for cat, data in pairs(clothes) do
        if type(data) == 'table' then
            local hash = data.hash or data._h or 0
            local model = data.model or data._m or 0
            local texture = data.texture or data._t or 1
            if (not hash or hash == 0) and model and tonumber(model) > 0 then
                local resolvedHash = resolveHash(cat, model, texture, hairModel)
                if resolvedHash and resolvedHash ~= 0 then
                    data.hash = resolvedHash
                    data._h = resolvedHash
                end
            end
        end
    end
    return clothes
end

-- What is it (description of the possible features)
function TableLength(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- What is characterized /loadcharacter (load), which contains how characters are represented HP
local LoadCharacterCooldownSec = 3
local LoadCharacterLastTime = {}

-- What works with the model (description head, face features and other visual attributes)
local function DeepMergeSkin(target, source)
    if not target then target = {} end
    if not source then return target end
    for k, v in pairs(source) do
        if v ~= nil then
            if type(v) == "table" and not (k == "components" or k == "stateBag") then
                if type(target[k]) ~= "table" then target[k] = {} end
                DeepMergeSkin(target[k], v)
            else
                target[k] = v
            end
        end
    end
    return target
end

local EyebrowKeys = { 'eyebrows_t', 'eyebrows_op', 'eyebrows_id', 'eyebrows_c1' }
local MakeupKeys = {
    'shadows_t', 'shadows_op', 'shadows_id', 'shadows_c1',
    'blush_t', 'blush_op', 'blush_id', 'blush_c1',
    'lipsticks_t', 'lipsticks_op', 'lipsticks_id', 'lipsticks_c1', 'lipsticks_c2',
    'eyeliners_t', 'eyeliners_op', 'eyeliners_id', 'eyeliners_c1'
}

local function CopyStyleValues(skin, keys)
    local values = {}
    for _, key in ipairs(keys) do values[key] = tonumber(skin and skin[key]) or 0 end
    return values
end

local function BuildBarberStyle(skin)
    skin = type(skin) == 'table' and skin or {}
    local hair = type(skin.hair) == 'table' and skin.hair or {}
    local beard = type(skin.beard) == 'table' and skin.beard or {}
    return {
        version = 1,
        hair = {
            model = tonumber(hair.model or skin.hair) or 0,
            color = tonumber(hair.color or hair.texture or skin.hair_color) or 0,
            hashname = type(hair.hashname or skin.hair_hashname) == 'string' and (hair.hashname or skin.hair_hashname) ~= '' and (hair.hashname or skin.hair_hashname) or nil,
        },
        beard = {
            model = tonumber(beard.model or skin.beard) or 0,
            color = tonumber(beard.color or beard.texture or skin.beard_color) or 0,
            hashname = type(beard.hashname or skin.beard_hashname) == 'string' and (beard.hashname or skin.beard_hashname) ~= '' and (beard.hashname or skin.beard_hashname) or nil,
        },
        eyebrows = CopyStyleValues(skin, EyebrowKeys),
        makeup = CopyStyleValues(skin, MakeupKeys),
    }
end

local function NormalizeBarberStyle(style)
    if type(style) ~= 'table' then return nil end
    local flat = {
        hair = type(style.hair) == 'table' and style.hair.model or style.hair,
        hair_color = type(style.hair) == 'table' and style.hair.color or style.hair_color,
        hair_hashname = type(style.hair) == 'table' and style.hair.hashname or style.hair_hashname,
        beard = type(style.beard) == 'table' and style.beard.model or style.beard,
        beard_color = type(style.beard) == 'table' and style.beard.color or style.beard_color,
        beard_hashname = type(style.beard) == 'table' and style.beard.hashname or style.beard_hashname,
    }
    for _, key in ipairs(EyebrowKeys) do
        flat[key] = type(style.eyebrows) == 'table' and style.eyebrows[key] or style[key]
    end
    for _, key in ipairs(MakeupKeys) do
        flat[key] = type(style.makeup) == 'table' and style.makeup[key] or style[key]
    end
    return BuildBarberStyle(flat)
end

local function ApplyBarberStyleToSkin(skin, style)
    local normalized = NormalizeBarberStyle(style)
    if not normalized then return skin, nil end
    skin = type(skin) == 'table' and skin or {}
    skin.hair = normalized.hair.model
    skin.hair_color = normalized.hair.color
    skin.hair_hashname = normalized.hair.hashname
    skin.beard = normalized.beard.model
    skin.beard_color = normalized.beard.color
    skin.beard_hashname = normalized.beard.hashname
    for _, key in ipairs(EyebrowKeys) do skin[key] = normalized.eyebrows[key] end
    for _, key in ipairs(MakeupKeys) do skin[key] = normalized.makeup[key] end
    return skin, normalized
end

local function SetBarberStyleMetadata(Player, skin)
    local style = BuildBarberStyle(skin)
    Player.Functions.SetMetaData('barberStyle', style)
    return style
end

RegisterNetEvent('rsg-appearance:server:SaveSkin', function(skin, clothes, oldplayer)
    print('[RSG-Appearance] SaveSkin called: oldplayer=' .. tostring(oldplayer) .. ' source=' .. tostring(source))

    if not skin or type(skin) ~= "table" then
        print('[RSG-Appearance] SaveSkin FAILED: skin is nil or not a table')
        return
    end
    local clothesData = clothes
    if not clothesData or type(clothesData) ~= "table" then clothesData = {} end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        print('[RSG-Appearance] SaveSkin FAILED: Player is nil for source=' .. tostring(source))
        return
    end
    local citizenid = Player.PlayerData.citizenid
    print('[RSG-Appearance] SaveSkin: citizenid=' .. tostring(citizenid))

    if oldplayer then
        local result = MySQL.Sync.fetchAll('SELECT * FROM playerskins WHERE citizenid = ?', {citizenid})

        if result and #result > 0 then
            local existingSkin = json.decode(result[1].skin or '{}')
            local existingClothes = json.decode(result[1].clothes or '{}')
            if not existingSkin then existingSkin = {} end
            if not existingClothes then existingClothes = {} end

             -- What is applicable: described head, face features, overlays and others.
            DeepMergeSkin(existingSkin, skin)
            DeepMergeSkin(existingClothes, clothesData)
            SetBarberStyleMetadata(Player, existingSkin)

            MySQL.Async.execute('UPDATE playerskins SET skin = @skin, clothes = @clothes WHERE citizenid = @citizenid', {
                ['citizenid'] = citizenid,
                ['skin'] = json.encode(existingSkin),
                ['clothes'] = json.encode(existingClothes),
            }, function()
                SetPlayerAppearanceState(source, existingSkin, existingClothes)
            end)
        else
            SetBarberStyleMetadata(Player, skin)
             -- In short - it describes which elements are missing
            MySQL.Async.insert('INSERT INTO playerskins (citizenid, skin, clothes) VALUES (?, ?, ?)', {
                citizenid,
                json.encode(skin),
                json.encode(clothesData)
            }, function()
                SetPlayerAppearanceState(source, skin, clothesData)
            end)
        end
    else
        print('[RSG-Appearance] SaveSkin: Inserting NEW player skin for citizenid=' .. tostring(citizenid))
        local initialBarberStyle = SetBarberStyleMetadata(Player, skin)
        TriggerEvent('rsg-barbershop:server:saveInitialLook', source, initialBarberStyle)
        MySQL.Async.insert('INSERT INTO playerskins (citizenid, skin, clothes) VALUES (?, ?, ?)', {
            citizenid,
            json.encode(skin),
            json.encode(clothesData)
        }, function(insertId)
            print('[RSG-Appearance] SaveSkin INSERT complete: insertId=' .. tostring(insertId))
            SetPlayerAppearanceState(source, skin, clothesData)
        end)
        TriggerClientEvent('rsg-spawn:client:newplayer', source)
    end
end)

RegisterNetEvent('rsg-appearance:server:SetPlayerBucket', function(b, random)
    if random then
        local BucketID = RSGCore.Shared.RandomInt(1000, 9999)
        SetRoutingBucketPopulationEnabled(BucketID, false)
        SetPlayerRoutingBucket(source, BucketID)
    else
        SetPlayerRoutingBucket(source, b)
    end
end)

-- What is: processing for (playerskins.clothes). SyncClothesToDatabase returns how equip/unequip.
-- What State Bag + additional broadcast: for what request RedM can send `skin` and state as needed
--    Further description (what features). JSON is supplied to support additional visualization of face features.
-- What loadAt: contributes to the current state, which requires loadcharacter and is required to handle
local _loadCharacterNonce = 0
SetPlayerAppearanceState = function(src, skin, clothes)
    if not src or not skin then return end
    clothes = ResolveClothesHashes(skin, clothes or {})
    _loadCharacterNonce = _loadCharacterNonce + 1
    local okS, sJson = pcall(json.encode, skin)
    local okC, cJson = pcall(json.encode, clothes or {})
    local state = Player(src).state
    if state then
         -- skin_json / clothes_json: describes additional functionalities; necessary skin and relevant application descriptions.
         -- What EnsureFaceFeaturesForSync sends 0 for errors and options (subsequently which modifying models).
        local payload = {
            skin = skin,
            clothes = clothes,
            loadAt = _loadCharacterNonce,
        }
        if okS and sJson then payload.skin_json = sJson end
        if okC and cJson then payload.clothes_json = cJson end
        state:set('appearance', payload, true)
    end
    if okS and okC and sJson and cJson and (#sJson + #cJson) < 400000 then
        TriggerClientEvent('rsg-appearance:client:PeerAppearancePayload', -1, src, sJson, cJson, _loadCharacterNonce)
    end
end

RegisterNetEvent('rsg-appearance:server:LoadSkin')
AddEventHandler('rsg-appearance:server:LoadSkin', function()
    local _source = source
    local User = RSGCore.Functions.GetPlayer(_source)
    if not User then return end
    local citizenid = User.PlayerData.citizenid
    local skins = MySQL.Sync.fetchAll('SELECT * FROM playerskins WHERE citizenid = ?', {citizenid})
    if skins[1] then
        local skin = json.decode(skins[1].skin or '{}')
        local clothes = json.decode(skins[1].clothes or '{}')
        SetBarberStyleMetadata(User, skin)
        SetPlayerAppearanceState(_source, skin, clothes)
    else
        TriggerClientEvent('rsg-appearance:client:OpenCreator', _source)
    end
end)

exports('BuildBarberStyle', BuildBarberStyle)

exports('SaveBarberStyle', function(src, style)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local rows = MySQL.Sync.fetchAll('SELECT skin FROM playerskins WHERE citizenid = ? LIMIT 1', {
        Player.PlayerData.citizenid
    })
    if not rows or not rows[1] then return false end
    local ok, skin = pcall(json.decode, rows[1].skin or '{}')
    if not ok or type(skin) ~= 'table' then return false end
    local normalized
    skin, normalized = ApplyBarberStyleToSkin(skin, style)
    if not normalized then return false end
    local saved = MySQL.Sync.execute('UPDATE playerskins SET skin = ? WHERE citizenid = ?', {
        json.encode(skin), Player.PlayerData.citizenid
    })
    if saved == nil then return false end
    Player.Functions.SetMetaData('barberStyle', normalized)
    SetPlayerAppearanceState(src, skin, exports['rsg-appearance']:GetActiveClothes(src))
    return normalized
end)

-- What is the requested variable description (and anything interesting) - explains by length
RSGCore.Functions.CreateCallback('rsg-appearance:server:GetSkinForEditor', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end
    local citizenid = Player.PlayerData.citizenid
    local skins = MySQL.Sync.fetchAll('SELECT skin FROM playerskins WHERE citizenid = ?', {citizenid})
    if skins and skins[1] and skins[1].skin then
        cb(json.decode(skins[1].skin or '{}'))
    else
        cb(nil)
    end
end)


RegisterNetEvent('rsg-appearance:server:deleteSkin')
AddEventHandler('rsg-appearance:server:deleteSkin', function(license, Callback)
    local _source = source
    local id
    for k, v in ipairs(GetPlayerIdentifiers(_source)) do
        if string.sub(v, 1, string.len('steam:')) == 'steam:' then
            id = v
            break
        end
    end
    local Callback = callback
    MySQL.Async.fetchAll('DELETE FROM playerskins WHERE `citizenid`= ? AND`license`= ?;', {id, license})
end)

RegisterNetEvent('rsg-appearance:server:updategender', function(gender)
    local Player = RSGCore.Functions.GetPlayer(source)
    local citizenid = Player.PlayerData.citizenid
    local license = RSGCore.Functions.GetIdentifier(source, 'license')

    local result = MySQL.Sync.fetchAll('SELECT * FROM players WHERE citizenid = ? AND license = ?', {citizenid, license})
    local Charinfo = json.decode(result[1].charinfo)
    Charinfo.gender = gender
    MySQL.Async.execute('UPDATE players SET `charinfo` = ? WHERE `citizenid`= ? AND `license`= ?', {json.encode(Charinfo), citizenid, license})
    Player.Functions.Save()
end)

-- ==========================================
-- What characterizes avatar descriptors (which manipulates)
-- What is while processing the command (ExecuteCommand will synchronize with the given proposed examples)
-- ==========================================

local function DoLoadCharacter(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

     -- What additional options: describes alternatives available (which data manipulations know the HP)
    local now = os.time()
    local last = LoadCharacterLastTime[source] or 0
    if now - last < LoadCharacterCooldownSec then
        TriggerClientEvent('ox_lib:notify', source, {
             title = 'Description',
             description = 'There are still ' .. (LoadCharacterCooldownSec - (now - last)) .. ' seconds left to wait',
            type = 'error'
        })
        return
    end
    LoadCharacterLastTime[source] = now

     -- What is being reported: the emotion of those who act accordingly
    local isDead = Player.PlayerData.metadata and Player.PlayerData.metadata['isdead']
    if isDead then
        TriggerClientEvent('ox_lib:notify', source, {
             title = 'Failed',
             description = 'There are still ongoing adjustments to any components of the program initiation at locations',
            type = 'error'
        })
        return
    end

     -- What additional adjustments occur for the response by the original systems (which fixcharacter)
    if SyncClothesToDatabase then
        SyncClothesToDatabase(source)
    end

    local citizenid = Player.PlayerData.citizenid
    local skins = MySQL.Sync.fetchAll('SELECT * FROM playerskins WHERE citizenid = ?', {citizenid})

    if skins and skins[1] then
        local skin = json.decode(skins[1].skin or '{}')
        local clothes = json.decode(skins[1].clothes or '{}')
        SetPlayerAppearanceState(source, skin, clothes)
        --[[
        TriggerClientEvent('ox_lib:notify', source, {
             title = 'Updated',
             description = 'Successful transaction with communication updates on face completion',
            type = 'success'
        })
        ]]
    else
        TriggerClientEvent('ox_lib:notify', source, {
             title = 'Complete',
             description = 'Completed successfully given age restrictions',
            type = 'error'
        })
    end
end

-- What is related to skin fetching from hate-style ClonePedToTarget (otherwise similar to loadcharacter)
RegisterNetEvent('rsg-appearance:server:HateCloneGetSkin', function()
    local src = source
    local skin = {}
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData and Player.PlayerData.citizenid then
        local citizenid = Player.PlayerData.citizenid
        local rows = MySQL.Sync.fetchAll('SELECT skin FROM playerskins WHERE citizenid = ? LIMIT 1', { citizenid })
        if rows and rows[1] and rows[1].skin and rows[1].skin ~= '' then
            local ok, dec = pcall(json.decode, rows[1].skin)
            if ok and type(dec) == 'table' then
                skin = dec
            end
        end
    end
     -- Assignment from ongoing functionalities: defines _RicxHateCloneQueue describes a closer request from a devotee.
    TriggerClientEvent('rsg-appearance:client:HateCloneSkinResult', src, skin)
end)

RegisterNetEvent('rsg-appearance:server:LoadCharacter')
AddEventHandler('rsg-appearance:server:LoadCharacter', function()
    DoLoadCharacter(source)
end)

RSGCore.Commands.Add('loadcharacter', 'Introduces character operations', {}, false, function(source)
    DoLoadCharacter(source)
end)

-- ==========================================
-- What can improve: loadcharacter upon execution (whether conditions are being followed or if computational processes charge the topology)
-- ==========================================

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    local citizenid = Player.PlayerData.citizenid
     -- What DoLoadCharacter: SyncClothesToDatabase will retain those which affect playerskins and ApplySkin (useEquipPath)
    SetTimeout(6500, function()
        if not GetPlayerName(src) then return end
        local P = RSGCore.Functions.GetPlayer(src)
        if not P then return end
        local isDead = P.PlayerData.metadata and P.PlayerData.metadata['isdead']
        if isDead then
             -- What can also do: SetPlayerAppearanceState (DoLoadCharacter proceed on message passing)
            local skins = MySQL.Sync.fetchAll('SELECT * FROM playerskins WHERE citizenid = ?', {citizenid})
            if skins and skins[1] then
                local skin = json.decode(skins[1].skin or '{}')
                local clothes = json.decode(skins[1].clothes or '{}')
                SetPlayerAppearanceState(src, skin, clothes)
            end
        else
            DoLoadCharacter(src)
        end
    end)
end)

-- ==========================================
-- Reporting notes for applicable states
-- ==========================================

RegisterNetEvent('rsg-appearance:server:purchaseClothes')
AddEventHandler('rsg-appearance:server:purchaseClothes', function(clothesCache, totalPrice)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local cash = Player.Functions.GetMoney('cash')
    if cash < totalPrice then
        TriggerClientEvent('ox_lib:notify', src, {
             title = 'Loading...',
             description = 'Detailed report on usage',
            type = 'error'
        })
        return
    end
    
    Player.Functions.RemoveMoney('cash', totalPrice, 'clothing-purchase')
    
    TriggerClientEvent('ox_lib:notify', src, {
         title = 'Unlocking...',
         description = 'Transaction on report: $' .. totalPrice,
        type = 'success'
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    if src then LoadCharacterLastTime[src] = nil end
end)

-- What can exist as format: additional details regarding State Bag (and further developments)
exports('SetPlayerAppearance', function(src, skin, clothes)
    if not src or not skin then return end
    SetPlayerAppearanceState(src, skin, clothes or {})
end)

-- Exact active-outfit helpers used by the SQL wardrobe. These deliberately replace
-- playerskins.clothes instead of deep-merging so removed categories stay removed.
exports('GetActiveClothes', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return {} end

    local rows = MySQL.Sync.fetchAll('SELECT clothes FROM playerskins WHERE citizenid = ? LIMIT 1', {
        Player.PlayerData.citizenid
    })
    if not rows or not rows[1] then return {} end

    local ok, clothes = pcall(json.decode, rows[1].clothes or '{}')
    return ok and type(clothes) == 'table' and clothes or {}
end)

exports('SaveActiveClothes', function(src, clothes)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(clothes) ~= 'table' then return false end

    local citizenid = Player.PlayerData.citizenid
    local rows = MySQL.Sync.fetchAll('SELECT skin FROM playerskins WHERE citizenid = ? LIMIT 1', { citizenid })
    if not rows or not rows[1] then return false end

    local okSkin, skin = pcall(json.decode, rows[1].skin or '{}')
    if not okSkin or type(skin) ~= 'table' then skin = {} end

    local saved = pcall(function()
        MySQL.Sync.execute('UPDATE playerskins SET clothes = ? WHERE citizenid = ?', {
            json.encode(clothes), citizenid
        })
    end)
    if not saved then return false end
    SetPlayerAppearanceState(src, skin, clothes)
    return true
end)

print('[RSG-Appearance] Server loaded (State Bag sync, server-side hash resolution)')

-- What could indicate for furthering: describes general aspects and relations which this might entail
-- /editappearance - initiates problem; /editappearance [id] - activates alternative states
RSGCore.Commands.Add('editappearance', 'Exercises adjustments regardless of the state (format). /editappearance [id]',
     { { name = 'id', help = 'ID number (for modifications)' } }, false, function(source, args)
    if not RSGCore.Functions.HasPermission(source, 'admin') then
         TriggerClientEvent('ox_lib:notify', source, { title = 'Notice', description = 'Appropriate triggers for notifications', type = 'error' })
        return
    end
    local targetId = tonumber(args and args[1])
    local target = source
    if targetId then
        if not GetPlayerName(targetId) then
             TriggerClientEvent('ox_lib:notify', source, { title = 'Conflict', description = 'Linking with ID ' .. tostring(targetId) .. ' was interrupted', type = 'error' })
            return
        end
        target = targetId
    end
    TriggerClientEvent('rsg-appearance:client:OpenEditor', target)
    if target ~= source then
         TriggerClientEvent('ox_lib:notify', source, { title = 'Processed', description = 'Notification regarding transitions #' .. target, type = 'success' })
    end
end, 'admin')

-- ==========================================
-- NAKED BODY SYSTEM: detects skin_tone
-- ==========================================

-- What skin_tone recognizes which possible outputs
RegisterNetEvent('rsg-appearance:server:RequestSkinTone')
AddEventHandler('rsg-appearance:server:RequestSkinTone', function()
    local _source = source
    local Player = RSGCore.Functions.GetPlayer(_source)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.Sync.fetchAll('SELECT skin FROM playerskins WHERE citizenid = ?', {citizenid})
    
    if result and result[1] and result[1].skin then
        local skinData = json.decode(result[1].skin)
        local skinTone = tonumber(skinData.skin_tone) or 1
        if skinTone < 1 then skinTone = 1 end
        if skinTone > 6 then skinTone = 6 end
        print('[RSG-Appearance] Sending skin_tone=' .. skinTone .. ' to ' .. citizenid)
        TriggerClientEvent('rsg-appearance:client:SetSkinTone', _source, skinTone)
    end
end)

-- What indicators might determine skin_tone and visual similarities

RegisterNetEvent('rsg-appearance:server:FixSkinTone')
AddEventHandler('rsg-appearance:server:FixSkinTone', function(newSkinTone)
    local _source = source
    local Player = RSGCore.Functions.GetPlayer(_source)
    
    if not Player then
        print('[RSG-Appearance] FixSkinTone: Player not found')
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
     -- What additions occur from descriptions
    if not newSkinTone or newSkinTone < 1 or newSkinTone > 6 then
        print('[RSG-Appearance] FixSkinTone: Invalid skin_tone ' .. tostring(newSkinTone))
        return
    end
    
     -- Provides details from affected components
    local result = MySQL.Sync.fetchAll('SELECT skin FROM playerskins WHERE citizenid = ?', {citizenid})
    
    if result and result[1] and result[1].skin then
        local skinData = json.decode(result[1].skin)
        local oldTone = skinData.skin_tone
        
         -- What additional skin_tone faculties
        skinData.skin_tone = newSkinTone
        
         -- What is required consideration
        local encodedSkin = json.encode(skinData)
        MySQL.Async.execute('UPDATE playerskins SET skin = @skin WHERE citizenid = @citizenid', {
            ['citizenid'] = citizenid,
            ['skin'] = encodedSkin
        }, function(rowsChanged)
            print('[RSG-Appearance] FixSkinTone: Updated skin_tone from ' .. tostring(oldTone) .. ' to ' .. newSkinTone .. ' for ' .. citizenid)
            
            TriggerClientEvent('ox_lib:notify', _source, {
                 title = 'New Touch',
                 description = 'Diagnostics: skin_tone = ' .. newSkinTone,
                type = 'success'
            })
        end)
    else
        print('[RSG-Appearance] FixSkinTone: No skin data found for ' .. citizenid)
    end
end)
