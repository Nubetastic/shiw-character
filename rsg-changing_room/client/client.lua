local RSGCore = exports['rsg-core']:GetCoreObject()

local SHARED_SCALE_KEY = 'rsg_clothingstore'
local LEGACY_SCALE_KVP = 'hudScale.rsg_clothingstore'

local menuOpen = false
local openingMenu = false
local applyingSelection = false
local changingRoomCamera = nil
local openingHeading = nil
local openingPosition = nil
local pendingTargetContext = nil
local activeCloakroom = nil
local cameraOffsetZ = 0.0
local uiScale = 1.0

local outfits = {}
local looks = {}
local selectedOutfitIndex = 0
local selectedLookIndex = 0
local baselineOutfit = {}
local baselineStyle = {}

local function Debug(message, ...)
    if Config.Debug ~= true then return end
    local formatted = message
    if select('#', ...) > 0 then
        local ok, result = pcall(string.format, message, ...)
        formatted = ok and result or message
    end
    print(('[rsg-changing_room:debug] %s | %s'):format(GetGameTimer(), formatted))
end

Debug('client.lua loaded; no freeze or NUI focus requested')

local function DeepCopy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, child in pairs(value) do
        copy[DeepCopy(key)] = DeepCopy(child)
    end
    return copy
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function SaveScale(value)
    uiScale = Clamp(tonumber(value) or uiScale, 0.25, 3.0)
    local playerData = RSGCore.Functions.GetPlayerData()
    local hudScale = playerData and playerData.metadata and playerData.metadata.hudScale
    local savedScales = type(hudScale) == 'table' and DeepCopy(hudScale) or {}
    savedScales[SHARED_SCALE_KEY] = uiScale
    TriggerServerEvent('RSGCore:Server:SetMetaData', 'hudScale', savedScales)
end

local function LoadScale()
    local playerData = RSGCore.Functions.GetPlayerData()
    local hudScale = playerData and playerData.metadata and playerData.metadata.hudScale
    local savedScale = type(hudScale) == 'table' and hudScale[SHARED_SCALE_KEY] or nil

    if savedScale == nil then
        local legacyScale = tonumber(GetResourceKvpString(LEGACY_SCALE_KVP))
        if legacyScale ~= nil then
            SaveScale(legacyScale)
            return
        end
    end

    uiScale = Clamp(tonumber(savedScale) or 1.0, 0.25, 3.0)
end

local function StyleToSkin(style)
    style = type(style) == 'table' and style or {}
    local hair = type(style.hair) == 'table' and style.hair or {}
    local beard = type(style.beard) == 'table' and style.beard or {}
    local skin = {
        hair = tonumber(hair.model) or 0,
        hair_color = tonumber(hair.color) or 0,
        hair_hashname = hair.hashname,
        beard = tonumber(beard.model) or 0,
        beard_color = tonumber(beard.color) or 0,
        beard_hashname = beard.hashname,
    }

    for key, value in pairs(type(style.eyebrows) == 'table' and style.eyebrows or {}) do
        skin[key] = value
    end
    for key, value in pairs(type(style.makeup) == 'table' and style.makeup or {}) do
        skin[key] = value
    end
    return skin
end

local function ApplyOutfit(outfit)
    if type(outfit) ~= 'table' then return end
    TriggerEvent('rsg-appearance:client:ApplyClothes', DeepCopy(outfit), PlayerPedId())
end

local function ApplyStyle(style)
    if type(style) ~= 'table' then return end
    local skin = StyleToSkin(style)
    local ped = PlayerPedId()
    pcall(function() exports['rsg-appearance']:SetHair(ped, skin) end)
    pcall(function() exports['rsg-appearance']:SetBeard(ped, skin) end)
    pcall(function() exports['rsg-appearance']:SetFaceOverlays(ped, skin) end)
    pcall(function() exports['rsg-appearance']:SetCurrentSkinData(skin) end)
end

local function GetSelectedOutfit()
    if selectedOutfitIndex == 0 then return baselineOutfit end
    local entry = outfits[selectedOutfitIndex]
    return type(entry) == 'table' and entry.clothes or baselineOutfit
end

local function GetSelectedStyle()
    if selectedLookIndex == 0 then return baselineStyle end
    local entry = looks[selectedLookIndex]
    return type(entry) == 'table' and entry.style or baselineStyle
end

local function DestroyChangingRoomCamera()
    if changingRoomCamera then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(changingRoomCamera, false)
        changingRoomCamera = nil
        SetFocusEntity(PlayerPedId())
    end
end

local function PositionChangingRoomCamera()
    if not changingRoomCamera then return end
    local ped = PlayerPedId()

    if activeCloakroom and activeCloakroom.cam then
        local cam = activeCloakroom.cam
        SetCamCoord(changingRoomCamera, cam.x, cam.y, cam.z + cameraOffsetZ)
        SetCamRot(changingRoomCamera, -4.0, 0.0, cam.w or 0.0, 2)
        local pedPosition = GetEntityCoords(ped)
        SetFocusPosAndVel(pedPosition.x, pedPosition.y, pedPosition.z + cameraOffsetZ, 0.0, 0.0, 0.0)
        return
    end

    local cameraPosition = GetOffsetFromEntityInWorldCoords(
        ped,
        0.0,
        tonumber(Config.CameraDistance) or 2.4,
        (tonumber(Config.CameraHeight) or 0.65) + cameraOffsetZ
    )
    local pedPosition = GetEntityCoords(ped)
    SetCamCoord(changingRoomCamera, cameraPosition.x, cameraPosition.y, cameraPosition.z)
    PointCamAtCoord(
        changingRoomCamera,
        pedPosition.x,
        pedPosition.y,
        pedPosition.z + (tonumber(Config.CameraAimHeight) or 0.45) + cameraOffsetZ
    )
end

local function CreateChangingRoomCamera()
    DestroyChangingRoomCamera()
    changingRoomCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not changingRoomCamera or changingRoomCamera == 0 then
        changingRoomCamera = nil
        return false
    end
    SetCamFov(changingRoomCamera, tonumber(Config.CameraFov) or 35.0)
    PositionChangingRoomCamera()
    SetCamActive(changingRoomCamera, true)
    if activeCloakroom then
        RenderScriptCams(true, false, 500, true, true)
    else
        RenderScriptCams(true, true, 300, true, true)
    end
    return true
end

local function TeleportToCloakroom(ped, cloakroom)
    local playerCoords = cloakroom.coords

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    Wait(200)

    RequestCollisionAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
    SetEntityCoords(ped, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false, false)
    SetEntityHeading(ped, playerCoords.w or GetEntityHeading(ped))

    local timeout = 0
    while not HasCollisionLoadedAroundEntity(ped) and timeout < 200 do
        Wait(10)
        timeout = timeout + 1
    end

    Wait(500)
    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do Wait(10) end
    Wait(300)
end

local function RestorePreview()
    ApplyOutfit(baselineOutfit)
    ApplyStyle(baselineStyle)
end

local function CloseChangingRoom(restorePreview)
    if not menuOpen then return end
    menuOpen = false
    applyingSelection = false

    if restorePreview then RestorePreview() end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    DestroyChangingRoomCamera()

    local ped = PlayerPedId()
    if openingHeading then SetEntityHeading(ped, openingHeading) end
    FreezeEntityPosition(ped, false)

    if activeCloakroom and openingPosition then
        SetEntityCoordsNoOffset(ped, openingPosition.x, openingPosition.y, openingPosition.z, false, false, false)
    end

    openingHeading = nil
    openingPosition = nil
    pendingTargetContext = nil
    activeCloakroom = nil
    cameraOffsetZ = 0.0
end

local function ActivateChangingRoom(clothingData, savedLooks)
    Debug('ActivateChangingRoom reached clothingData=%s savedLooks=%s', type(clothingData), type(savedLooks))
    if menuOpen then return end

    local playerData = RSGCore.Functions.GetPlayerData()
    outfits = type(clothingData.outfits) == 'table' and clothingData.outfits or {}
    looks = type(savedLooks) == 'table' and savedLooks or {}
    baselineOutfit = DeepCopy(type(clothingData.activeClothes) == 'table' and clothingData.activeClothes or {})
    baselineStyle = DeepCopy(playerData.metadata and playerData.metadata.barberStyle or {})
    selectedOutfitIndex = 0
    selectedLookIndex = 0
    cameraOffsetZ = 0.0

    local ped = PlayerPedId()
    openingHeading = GetEntityHeading(ped)
    openingPosition = GetEntityCoords(ped)
    local targetContext = pendingTargetContext
    pendingTargetContext = nil

    if targetContext and targetContext.cloakroom then
        activeCloakroom = targetContext.cloakroom
        TeleportToCloakroom(ped, activeCloakroom)
    else
        activeCloakroom = nil
    end

    Debug('creating camera ped=%s heading=%s', tostring(ped), tostring(openingHeading))
    if not CreateChangingRoomCamera() then
        if activeCloakroom and openingPosition then
            SetEntityCoordsNoOffset(ped, openingPosition.x, openingPosition.y, openingPosition.z, false, false, false)
            if openingHeading then SetEntityHeading(ped, openingHeading) end
        end
        openingHeading = nil
        openingPosition = nil
        activeCloakroom = nil
        return
    end

    menuOpen = true
    Debug('camera created; freezing player')
    FreezeEntityPosition(ped, true)
    Debug('player frozen; setting NUI focus')
    SetNuiFocus(true, true)
    Debug('NUI focused; sending action=open outfits=%s looks=%s', tostring(#outfits), tostring(#looks))
    SendNUIMessage({
        action = 'open',
        outfits = outfits,
        looks = looks,
        scale = uiScale,
        scaleModifier = tonumber(Config.ScaleModifier) or 0.0,
    })
    Debug('action=open sent')
end

local function OpenChangingRoom(targetContext)
    Debug('OpenChangingRoom called menuOpen=%s openingMenu=%s applying=%s', tostring(menuOpen), tostring(openingMenu), tostring(applyingSelection))
    if menuOpen or openingMenu or applyingSelection then return end
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    openingMenu = true
    pendingTargetContext = targetContext
    LoadScale()

    RSGCore.Functions.TriggerCallback('rsg-clothingstore:server:getSessionData', function(clothingData)
        Debug('clothing callback returned type=%s', type(clothingData))
        if not clothingData then
            openingMenu = false
            pendingTargetContext = nil
            return
        end

        RSGCore.Functions.TriggerCallback('rsg-barbershop:server:getLooks', function(savedLooks)
            Debug('barber Looks callback returned type=%s', type(savedLooks))
            openingMenu = false
            ActivateChangingRoom(clothingData, savedLooks)
        end)
    end)
end

RegisterNetEvent('rsg-changing_room:client:open', function()
    Debug('radial open event received menuOpen=%s openingMenu=%s', tostring(menuOpen), tostring(openingMenu))
    if menuOpen or openingMenu then return end
        OpenChangingRoom()
end)

RegisterNetEvent('rsg-changing_room:client:openAtStore', function(storeId, cloakroomIndex)
    if menuOpen or openingMenu then return end

    local store = Config.Stores and Config.Stores[storeId]
    local cloakroom = Config.Cloakrooms and Config.Cloakrooms[tonumber(cloakroomIndex)]
    if not store or not cloakroom then
        Debug('target open rejected store=%s cloakroom=%s', tostring(storeId), tostring(cloakroomIndex))
        return
    end

    OpenChangingRoom({ cloakroom = cloakroom })
end)

RegisterNUICallback('setScale', function(data, cb)
    SaveScale(data and data.scale)
    cb({ scale = uiScale })
end)

RegisterNUICallback('debugReady', function(data, cb)
    Debug('HTML acknowledged action=open visible=%s', tostring(data and data.visible))
    cb('ok')
end)

RegisterNUICallback('previewOutfit', function(data, cb)
    if not menuOpen then cb('closed') return end
    selectedOutfitIndex = Clamp(math.floor(tonumber(data and data.index) or 0), 0, #outfits)
    ApplyOutfit(GetSelectedOutfit())
    cb('ok')
end)

RegisterNUICallback('previewLook', function(data, cb)
    if not menuOpen then cb('closed') return end
    selectedLookIndex = Clamp(math.floor(tonumber(data and data.index) or 0), 0, #looks)
    ApplyStyle(GetSelectedStyle())
    cb('ok')
end)

RegisterNUICallback('moveCamera', function(data, cb)
    if not menuOpen then cb('closed') return end
    local direction = data and data.direction
    local ped = PlayerPedId()

    if direction == 'up' then
        cameraOffsetZ = Clamp(
            cameraOffsetZ + (tonumber(Config.CameraVerticalStep) or 0.20),
            tonumber(Config.CameraVerticalMin) or -0.60,
            tonumber(Config.CameraVerticalMax) or 1.20
        )
        PositionChangingRoomCamera()
    elseif direction == 'down' then
        cameraOffsetZ = Clamp(
            cameraOffsetZ - (tonumber(Config.CameraVerticalStep) or 0.20),
            tonumber(Config.CameraVerticalMin) or -0.60,
            tonumber(Config.CameraVerticalMax) or 1.20
        )
        PositionChangingRoomCamera()
    elseif direction == 'left' then
        SetEntityHeading(ped, GetEntityHeading(ped) + (tonumber(Config.CharacterTurnStep) or 15.0))
    elseif direction == 'right' then
        SetEntityHeading(ped, GetEntityHeading(ped) - (tonumber(Config.CharacterTurnStep) or 15.0))
    elseif direction == 'reset' then
        cameraOffsetZ = 0.0
        if activeCloakroom and activeCloakroom.coords then
            SetEntityHeading(ped, activeCloakroom.coords.w or openingHeading)
        elseif openingHeading then
            SetEntityHeading(ped, openingHeading)
        end
        PositionChangingRoomCamera()
    end
    cb('ok')
end)

RegisterNUICallback('apply', function(_, cb)
    if not menuOpen or applyingSelection then cb('busy') return end
    applyingSelection = true

    local outfit = DeepCopy(GetSelectedOutfit())
    local lookIndex = selectedLookIndex
    RSGCore.Functions.TriggerCallback('rsg-clothingstore:server:applyOutfit', function(outfitResult)
        if not outfitResult or not outfitResult.success then
            applyingSelection = false
            SendNUIMessage({
                action = 'error',
                message = outfitResult and outfitResult.reason or 'Unable to apply outfit',
            })
            cb('error')
            return
        end

        local function CompleteApply(style)
            baselineOutfit = DeepCopy(outfitResult.activeClothes or outfit)
            baselineStyle = DeepCopy(style or baselineStyle)
            selectedOutfitIndex = 0
            selectedLookIndex = 0
            ApplyOutfit(baselineOutfit)
            ApplyStyle(baselineStyle)
            applyingSelection = false
            SendNUIMessage({ action = 'applied' })
            cb('ok')
        end

        if lookIndex == 0 then
            CompleteApply(baselineStyle)
            return
        end

        RSGCore.Functions.TriggerCallback('rsg-barbershop:server:applyLook', function(lookResult)
            if not lookResult or not lookResult.success then
                baselineOutfit = DeepCopy(outfitResult.activeClothes or outfit)
                selectedOutfitIndex = 0
                ApplyOutfit(baselineOutfit)
                ApplyStyle(baselineStyle)
                applyingSelection = false
                SendNUIMessage({
                    action = 'error',
                    message = lookResult and lookResult.reason or 'Unable to apply Look',
                })
                cb('error')
                return
            end
            CompleteApply(lookResult.style)
        end, lookIndex - 1)
    end, outfit)
end)

RegisterNUICallback('close', function(_, cb)
    CloseChangingRoom(true)
    cb('ok')
end)

RegisterCommand('dressclose', function()
    Debug('emergency /dressclose used menuOpen=%s openingMenu=%s', tostring(menuOpen), tostring(openingMenu))

    if menuOpen then RestorePreview() end

    menuOpen = false
    openingMenu = false
    applyingSelection = false
    selectedOutfitIndex = 0
    selectedLookIndex = 0

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    DestroyChangingRoomCamera()

    local ped = PlayerPedId()
    if openingHeading then SetEntityHeading(ped, openingHeading) end
    FreezeEntityPosition(ped, false)

    if activeCloakroom and openingPosition then
        SetEntityCoordsNoOffset(ped, openingPosition.x, openingPosition.y, openingPosition.z, false, false, false)
    end

    openingHeading = nil
    openingPosition = nil
    pendingTargetContext = nil
    activeCloakroom = nil
    cameraOffsetZ = 0.0

    Debug('emergency close complete; focus released, camera destroyed, player unfrozen')
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if menuOpen then RestorePreview() end
    SetNuiFocus(false, false)
    DestroyChangingRoomCamera()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    if activeCloakroom and openingPosition then
        SetEntityCoordsNoOffset(ped, openingPosition.x, openingPosition.y, openingPosition.z, false, false, false)
        if openingHeading then SetEntityHeading(ped, openingHeading) end
    end
end)
