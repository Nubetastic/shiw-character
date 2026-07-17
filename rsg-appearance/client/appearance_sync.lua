--[[
    ★ Synchronize appearance to other players
    Applies head, face features, overlays and clothing to other players' peds
    based on Player State Bag (appearance).
]]

local appliedCache = {}
local Data = require 'data.features'

local function copySkinTable(skinData)
    if type(skinData) ~= 'table' then return skinData end
    local ok, encoded = pcall(json.encode, skinData)
    if ok and encoded then
        local ok2, decoded = pcall(json.decode, encoded)
        if ok2 and type(decoded) == 'table' then return decoded end
    end
    return skinData
end

local BodyMorphFeatureNames = {
    waist_width = true, chest_size = true, hips_size = true, arms_size = true,
    tight_size = true, calves_size = true, uppr_shoulder_size = true,
    back_shoulder_thickness = true, back_muscle = true,
}

-- ★ Only fill in a "full" skin from DB/JSON. If the table is trimmed (few keys), zeros instead of missing
-- morphs make the face wider/different than the owner's (e.g. face_width: locally -40, on another client 0).
local function EnsureFaceFeaturesForSync(skinData)
    if not skinData or type(skinData) ~= 'table' then return end
    local n = 0
    for featName, _ in pairs(Data.features) do
        if not BodyMorphFeatureNames[featName] and skinData[featName] ~= nil then
            n = n + 1
        end
    end
    if n < 12 then return end

    for featName, _ in pairs(Data.features) do
        if not BodyMorphFeatureNames[featName] and skinData[featName] == nil then
            skinData[featName] = 0
        end
    end
end

-- Apply appearance to another player's ped (without changing global state of the local player)
-- ★ After ApplyClothes, UpdatePedVariation is called — it resets face/overlays.
-- Re-apply the face (as for own character), otherwise other players will have a different face.
local function ApplyAppearanceToOtherPed(targetPed, skinData, clothesData)
    if not targetPed or not DoesEntityExist(targetPed) or not skinData then return end

    skinData = copySkinTable(skinData)
    if clothesData and type(clothesData) == 'table' then
        clothesData = copySkinTable(clothesData)
    end

    skinData.head = tonumber(skinData.head) or 1
    skinData.skin_tone = tonumber(skinData.skin_tone) or 1
    if NormalizeAppearanceSex then NormalizeAppearanceSex(skinData) end
    skinData.sex = tonumber(skinData.sex) or 1

    -- ★ Required: chin, nose, eyes — otherwise other players' faces are randomized
    EnsureFaceFeaturesForSync(skinData)

    local savedMorph = _G._BodyMorphData

    if IsAppearanceFemaleSkin and IsAppearanceFemaleSkin(skinData) and ApplyFemaleMpMetaBasePreset then
        ApplyFemaleMpMetaBasePreset(targetPed)
    end

    LoadHeight(targetPed, skinData)
    LoadBoody(targetPed, skinData)
    LoadAllBodyShape(targetPed, skinData)
    LoadHead(targetPed, skinData)
    LoadHair(targetPed, skinData)
    if skinData.sex == 1 then
        LoadBeard(targetPed, skinData)
    end
    LoadEyes(targetPed, skinData)
    LoadFeatures(targetPed, skinData)
    LoadOverlays(targetPed, skinData)

    _G._BodyMorphData = savedMorph

    if clothesData and next(clothesData) then
        TriggerEvent('rsg-appearance:client:ApplyClothes', clothesData, targetPed, skinData)
    end

    -- ★ CRITICAL: ApplyClothes/UpdatePedVariation reset the face (chin, nose, eyes) and overlays
    SetTimeout(1200, function()
        if not targetPed or not DoesEntityExist(targetPed) then return end
        LoadHead(targetPed, skinData)
        Wait(80)
        LoadEyes(targetPed, skinData)
        LoadFeatures(targetPed, skinData)
        LoadOverlays(targetPed, skinData)
        Citizen.InvokeNative(0x704C908E9C405136, targetPed)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, targetPed, false, true, true, true, false)
        -- UpdatePedVariation resets face features and overlays — re-applying them
        Wait(50)
        LoadFeatures(targetPed, skinData)
        LoadOverlays(targetPed, skinData)
    end)
end

-- ★ Full skin from server (JSON) — more reliable than state bag for face features on other peds
RegisterNetEvent('rsg-appearance:client:PeerAppearancePayload', function(targetSrc, skinJson, clothesJson, _nonce)
    if not targetSrc or type(skinJson) ~= 'string' then return end
    local myId = GetPlayerServerId(PlayerId())
    if targetSrc == myId then return end

    local ok, skinData = pcall(json.decode, skinJson)
    if not ok or type(skinData) ~= 'table' then return end
    local clothesData = {}
    if type(clothesJson) == 'string' and clothesJson ~= '' then
        local okC, dec = pcall(json.decode, clothesJson)
        if okC and type(dec) == 'table' then clothesData = dec end
    end

    CreateThread(function()
        local serverId = targetSrc
        local targetPed = 0
        for _ = 1, 35 do
            local playerIdx = GetPlayerFromServerId(serverId)
            if playerIdx ~= -1 then
                targetPed = GetPlayerPed(playerIdx)
                if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
                    break
                end
            end
            Wait(150)
        end

        if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
            ApplyAppearanceToOtherPed(targetPed, skinData, clothesData)
            appliedCache[serverId] = targetPed
        end
    end)
end)

local function decodeSkinFromAppearanceValue(value)
    if type(value) ~= 'table' then return nil end
    if type(value.skin_json) == 'string' and value.skin_json ~= '' then
        local ok, d = pcall(json.decode, value.skin_json)
        if ok and type(d) == 'table' then return copySkinTable(d) end
    end
    if value.skin and type(value.skin) == 'table' then
        return copySkinTable(value.skin)
    end
    return nil
end

local function decodeClothesFromAppearanceValue(value)
    if type(value) ~= 'table' then return {} end
    if type(value.clothes_json) == 'string' and value.clothes_json ~= '' then
        local ok, d = pcall(json.decode, value.clothes_json)
        if ok and type(d) == 'table' then return copySkinTable(d) end
    end
    if value.clothes and type(value.clothes) == 'table' then
        return copySkinTable(value.clothes)
    end
    return {}
end

-- ★ State Bag: for others — skin_json takes priority (full morphs); skin table is often trimmed
AddStateBagChangeHandler('appearance', nil, function(bagName, key, value)
    if type(value) ~= 'table' then return end

    local prefix, serverIdStr = string.match(bagName, '^(%w+):(%d+)$')
    if prefix ~= 'player' then return end

    local serverId = tonumber(serverIdStr)
    if not serverId then return end

    local myServerId = GetPlayerServerId(PlayerId())
    local skinData = decodeSkinFromAppearanceValue(value)
    local clothesData = decodeClothesFromAppearanceValue(value)

    if serverId == myServerId then
        if not skinData then return end
        TriggerEvent('rsg-appearance:client:ApplySkin', skinData, clothesData)
        return
    end

    -- Other player: skip trimmed skin — JSON only or wait for PeerAppearancePayload
    if type(value.skin_json) ~= 'string' or value.skin_json == '' then
        return
    end
    if not skinData then return end

    CreateThread(function()
        local targetPed = 0
        for _ = 1, 30 do
            local playerIdx = GetPlayerFromServerId(serverId)
            if playerIdx ~= -1 then
                targetPed = GetPlayerPed(playerIdx)
                if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
                    break
                end
            end
            Wait(200)
        end

        if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
            ApplyAppearanceToOtherPed(targetPed, skinData, clothesData)
            appliedCache[serverId] = targetPed
        end
    end)
end)

-- ★ Apply appearance on first player spawn (state may have been set before we connected)
CreateThread(function()
    while true do
        Wait(2000)
        local myServerId = GetPlayerServerId(PlayerId())
        for _, pid in ipairs(GetActivePlayers()) do
            if pid ~= PlayerId() then
                local serverId = GetPlayerServerId(pid)
                local ped = GetPlayerPed(pid)
                if serverId and serverId ~= myServerId and ped and ped ~= 0 and DoesEntityExist(ped) then
                    local appearance = nil
                    pcall(function()
                        local p = Player and Player(serverId)
                        if p and p.state and p.state.appearance then
                            appearance = p.state.appearance
                        end
                    end)
                    if appearance and type(appearance.skin_json) == 'string' and appearance.skin_json ~= '' then
                        local cached = appliedCache[serverId]
                        if cached ~= ped then
                            local ok, skinData = pcall(json.decode, appearance.skin_json)
                            local clothesData = {}
                            if type(appearance.clothes_json) == 'string' and appearance.clothes_json ~= '' then
                                local okC, cd = pcall(json.decode, appearance.clothes_json)
                                if okC and type(cd) == 'table' then clothesData = cd end
                            end
                            if ok and type(skinData) == 'table' then
                                ApplyAppearanceToOtherPed(ped, skinData, clothesData)
                                appliedCache[serverId] = ped
                            end
                        end
                    end
                end
            end
        end
    end
end)
