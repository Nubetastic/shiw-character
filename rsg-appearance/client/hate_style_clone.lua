-- ==========================================
-- HATE_FRAMEWORK-STYLE OUTFIT (kafcustomskin)
-- SetPlayerModel(mp) ? NPC + SetOutfitPreset ? ClonePedToTarget ? what is this
-- what LoadBoody / what is this - what is the difference.
-- ==========================================

local function waitPedStreamed(ped, maxIter)
    local i = 0
    while DoesEntityExist(ped) and not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and i < (maxIter or 120) do
        Wait(20)
        i = i + 1
    end
end

local function mergeSkinData(serverSkin)
    local out = {}
    if type(LoadedComponents) == 'table' then
        for k, v in pairs(LoadedComponents) do
            out[k] = v
        end
    end
    if type(CurrentSkinData) == 'table' then
        for k, v in pairs(CurrentSkinData) do
            if out[k] == nil then out[k] = v end
        end
    end
    if type(serverSkin) == 'table' then
        for k, v in pairs(serverSkin) do
            out[k] = v
        end
    end
    return out
end

--- opts (options):
---   skipLoadHeight - what is the LoadHeight (what is this and what is this about on the screen)
---   applyPresetOnPlayerAfterFace - what is being set SET_PED_OUTFIT_PRESET on the player (vorp menuloadPlayerSkin)
---   presetOnPlayerP3 - what is meant by gender (? mp_female ? hate the outfit true)
---   useFixIssuesBeforeClone - FixIssues (what is this) is applied to the clone; and ricx is handling OutfitItems.useFixIssuesBeforeHateClone
---   extraPresetPass - what is SET_PED_OUTFIT_PRESET for port/height (what is this)
---   metaBasePresetBeforeClone - what SetPlayerModel(mp): what is _EQUIP_PED_OUTFIT_PRESET for NPC-hero?
---       (what Cfx / Disquse: ? mp_female wants something 0 ? fullOutfit is what is this; what 7+p3=true)
---   metaBasePresetMale / metaBasePresetFemale - what is this gender preset (0 / 7)
---@return boolean ok, string|nil err
function DoHateStyleOutfitClone(pedModel, outfitPreset, skinData, opts)
    opts = opts or {}
    local skipLoadHeight = opts.skipLoadHeight == true
    local applyPresetOnPlayer = opts.applyPresetOnPlayerAfterFace ~= false -- is error true
    local presetP3 = opts.presetOnPlayerP3 == true
    local useFixIssues = opts.useFixIssuesBeforeClone == true
    local extraPresetPass = opts.extraPresetPass ~= false -- is error true
    local metaBasePresetBeforeClone = opts.metaBasePresetBeforeClone ~= false -- is error true
    if type(pedModel) ~= 'string' or pedModel == '' then
        return false, 'bad_model'
    end
    outfitPreset = tonumber(outfitPreset) or 0

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        return false, 'no_ped'
    end

    local health = GetEntityHealth(ped)
    local maxH = GetEntityMaxHealth(ped)
    local heading = GetEntityHeading(ped)
    local coords = GetEntityCoords(ped)
    local isMale = IsPedMale(ped) == true or IsPedMale(ped) == 1

    local mpName = isMale and 'mp_male' or 'mp_female'
    local mpHash = joaat(mpName)

    local merged = mergeSkinData(skinData or {})
    merged.head = tonumber(merged.head) or 1
    merged.skin_tone = tonumber(merged.skin_tone) or 1
    merged.sex = tonumber(merged.sex) or (isMale and 1 or 2)
    merged.height = tonumber(merged.height) or 100

    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.set then
        LocalPlayer.state:set('isLoadingCharacter', true, true)
    end

    RequestModel(mpHash, false)
    local t = 0
    while not HasModelLoaded(mpHash) and t < 120 do
        Wait(50)
        t = t + 1
    end
    if not HasModelLoaded(mpHash) then
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        if LocalPlayer and LocalPlayer.state and LocalPlayer.state.set then
            LocalPlayer.state:set('isLoadingCharacter', false, true)
        end
        return false, 'mp_load'
    end

    SetPlayerModel(PlayerId(), mpHash, true)
    Wait(400)
    ped = PlayerPedId()
    waitPedStreamed(ped, 150)

    if ResetNakedBodyFlags then
        pcall(ResetNakedBodyFlags)
    end
    if useFixIssues and FixIssues then
        pcall(FixIssues, ped)
        Wait(80)
    end

    -- what RedM: what is this for mp_* - what is this hero-what in what is it? (forum.cfx.re female mp meta ped outfit)
    if metaBasePresetBeforeClone then
        if isMale then
            local mid = tonumber(opts.metaBasePresetMale) or 0
            local m3 = opts.metaBasePresetMaleP3 == true
            Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, mid, m3)
        else
            local fid = tonumber(opts.metaBasePresetFemale) or 7
            local f3 = opts.metaBasePresetFemaleP3 ~= false -- what is error true
            Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, fid, f3)
        end
        Wait(220)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    end

    local npcHash = joaat(pedModel)
    RequestModel(npcHash, false)
    t = 0
    while not HasModelLoaded(npcHash) and t < 200 do
        Wait(50)
        t = t + 1
    end
    if not HasModelLoaded(npcHash) then
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        if LocalPlayer and LocalPlayer.state and LocalPlayer.state.set then
            LocalPlayer.state:set('isLoadingCharacter', false, true)
        end
        SetModelAsNoLongerNeeded(mpHash)
        return false, 'npc_load'
    end

    -- what hate_framework skin.lua: CreatePed(..., false, 1, 0, 0)
    local fakePed = CreatePed(npcHash, coords.x, coords.y, coords.z + 0.1, heading, false, true, 0, 0)
    if not fakePed or fakePed == 0 or not DoesEntityExist(fakePed) then
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        if LocalPlayer and LocalPlayer.state and LocalPlayer.state.set then
            LocalPlayer.state:set('isLoadingCharacter', false, true)
        end
        SetModelAsNoLongerNeeded(npcHash)
        SetModelAsNoLongerNeeded(mpHash)
        return false, 'fake_ped'
    end

    SetEntityAsMissionEntity(fakePed, true, true)
    SetEntityVisible(fakePed, false, false)
    Wait(750)

    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, fakePed, outfitPreset, false)
    Wait(1000)

    if ClonePedToTarget then
        ClonePedToTarget(fakePed, ped)
    else
        print('[rsg-appearance] ClonePedToTarget was successful - what is the difference RedM')
    end

    if DoesEntityExist(fakePed) then
        SetEntityAsMissionEntity(fakePed, true, true)
        DeleteEntity(fakePed)
    end
    SetModelAsNoLongerNeeded(npcHash)

    if IsPedMale(ped) then
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xF8016BCA, 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0x15D3C7F2, 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xB6B63737, 0)
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, 0xECC8B25A, 0)
    end
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)

    _G._HateCloneSuppressBodyMorph = true

    -- LoadHeight has an issue in what (what hate kafcustomskin: SetPedScale what is this/what is this)
    LoadHead(ped, merged)
    Wait(200)
    LoadHair(ped, merged)
    Wait(150)
    if IsPedMale(ped) then
        LoadBeard(ped, merged)
        Wait(150)
    end
    LoadEyes(ped, merged)
    Wait(100)
    LoadFeatures(ped, merged)
    Wait(100)
    LoadOverlays(ped, merged)
    Wait(150)

    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)

    -- in what vorpcharacter menuloadPlayerSkin: what does this address MP-hero what is this - what the difference in the models
    if applyPresetOnPlayer then
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, outfitPreset, presetP3)
        Wait(350)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    end

    -- what is hate: settings for what and SetPedPort (archetype what) and issues with the models
    if not skipLoadHeight and LoadHeight then
        LoadHeight(ped, merged)
        Wait(100)
    end
    pcall(function()
        exports['rsg-appearance']:SetPedPortFromSkin(ped, merged)
    end)
    Wait(200)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)

    -- what is this issue with the port - what is the difference in what/what
    if extraPresetPass then
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, outfitPreset, presetP3)
        Wait(300)
        Citizen.InvokeNative(0x704C908E9C405136, ped)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
    end

    _G._HateCloneSuppressBodyMorph = false

    SetEntityHeading(ped, heading)
    if health > 0 then
        SetEntityHealth(ped, math.min(health, maxH > 0 and maxH or health), 0)
    end
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.set then
        LocalPlayer.state:set('isLoadingCharacter', false, true)
    end

    SetModelAsNoLongerNeeded(mpHash)
    return true
end

exports('DoHateStyleOutfitClone', DoHateStyleOutfitClone)

RegisterNetEvent('rsg-appearance:client:HateCloneSkinResult', function(skinData)
    local q = _G._RicxHateCloneQueue
    if not q or type(q) ~= 'table' then
        TriggerEvent('ricx_outfits:call_notif', 1, {
            title = 'Outfits',
            text = 'Hate-clone: what is this (what is happening in what?). what the difference in these options.'
        })
        return
    end
    _G._RicxHateCloneQueue = nil

    local p3 = q.presetOnPlayerP3
    if p3 == nil and q.isFemale then
        p3 = true
    elseif p3 == nil then
        p3 = false
    end
    local cloneOpts = {
        skipLoadHeight = q.skipLoadHeight == true,
        applyPresetOnPlayerAfterFace = q.applyPresetOnPlayerAfterFace ~= false,
        presetOnPlayerP3 = p3 == true,
        useFixIssuesBeforeClone = q.useFixIssuesBeforeClone == true,
        extraPresetPass = q.extraPresetPass ~= false,
        metaBasePresetBeforeClone = q.metaBasePresetBeforeClone ~= false,
        metaBasePresetMale = q.metaBasePresetMale,
        metaBasePresetMaleP3 = q.metaBasePresetMaleP3,
        metaBasePresetFemale = q.metaBasePresetFemale,
        metaBasePresetFemaleP3 = q.metaBasePresetFemaleP3,
    }
    local pcallOk, cloneOk, failReason = pcall(function()
        return DoHateStyleOutfitClone(q.pedModel, q.outfitPreset, skinData, cloneOpts)
    end)

    if not pcallOk then
        print('[rsg-appearance] DoHateStyleOutfitClone pcall: ' .. tostring(cloneOk))
        TriggerEvent('ricx_outfits:call_notif', 1, {
            title = 'Outfits',
            text = 'what is this hate-clone: ' .. tostring(cloneOk),
        })
        return
    end
    if not cloneOk then
        TriggerEvent('ricx_outfits:call_notif', 1, {
            title = 'Outfits',
            text = 'Hate-clone: ' .. tostring(failReason or '?'),
        })
        return
    end

    _G._OutfitItemLastWorn = q.customId
    local slimBody = false
    local hideBodyMesh = false
    pcall(function()
        slimBody = exports['rsg-appearance']:IsRicxSlimBodyEnabled() == true
    end)
    pcall(function()
        hideBodyMesh = exports['rsg-appearance']:IsRicxOutfitBodyMeshHideEnabled() == true
    end)
    if slimBody or hideBodyMesh then
        _G._RicxOutfitActive = true
        _G._RicxActiveOutfitCustomId = (type(q.customId) == 'string' and q.customId ~= '') and q.customId or nil
    end
    TriggerEvent('ricx_outfits:client:AfterHateClone', {
        customId = q.customId,
        itemName = q.itemName,
    })

    -- what MP-hero what is this - what is the difference RSG.RicxOutfitSlimBody.enabled (what is this and what/what)
    if q.applySlimBodyAfterClone == true and slimBody then
        CreateThread(function()
            Wait(400)
            local ped = PlayerPedId()
            if not DoesEntityExist(ped) then return end
            pcall(function()
                exports['rsg-appearance']:ApplySlimBodyForOutfit(ped)
                Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, q.outfitPreset, p3)
                Citizen.InvokeNative(0x704C908E9C405136, ped)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
                if hideBodyMesh then
                    exports['rsg-appearance']:ApplyRicxOutfitBodyMeshHide(ped)
                end
            end)
            Wait(1800)
            ped = PlayerPedId()
            if DoesEntityExist(ped) then
                pcall(function()
                    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, q.outfitPreset, p3)
                    Citizen.InvokeNative(0x704C908E9C405136, ped)
                    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
                    if hideBodyMesh then
                        exports['rsg-appearance']:ApplyRicxOutfitBodyMeshHide(ped)
                    end
                end)
            end
        end)
    end

    if hideBodyMesh then
        CreateThread(function()
            Wait(500)
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and _G._RicxOutfitActive then
                pcall(function()
                    exports['rsg-appearance']:ApplyRicxOutfitBodyMeshHide(ped)
                end)
            end
            Wait(900)
            ped = PlayerPedId()
            if DoesEntityExist(ped) and _G._RicxOutfitActive then
                pcall(function()
                    exports['rsg-appearance']:ApplyRicxOutfitBodyMeshHide(ped)
                end)
            end
        end)
    end

    TriggerEvent('ricx_outfits:call_notif', 1, {
        title = 'Outfits',
        text = 'what (NPC preset): ' .. tostring(q.itemName or q.customId),
    })
end)
