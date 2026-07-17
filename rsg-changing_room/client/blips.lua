local cloakroomBlips = {}

local function GetBlipSprite(sprite)
    if type(sprite) == 'number' then return sprite end
    return GetHashKey(tostring(sprite or 'blip_shop_wardrobe'))
end

CreateThread(function()
    local settings = Config.CloakRoomBlips or {}
    local sprite = GetBlipSprite(settings.blipSprite)
    local scale = tonumber(settings.blipScale) or 1.0
    local name = tostring(settings.blipName or 'Changing Room')

    for _, cloakroom in ipairs(Config.Cloakrooms or {}) do
        local coords = cloakroom.coords
        if coords then
            local blipCoords = vector3(coords.x, coords.y, coords.z)
            local blip = BlipAddForCoords(1664425300, blipCoords.x, blipCoords.y, blipCoords.z)

            SetBlipSprite(blip, sprite, true)
            SetBlipScale(blip, scale)
            SetBlipName(blip, name)

            cloakroomBlips[#cloakroomBlips + 1] = blip
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, blip in ipairs(cloakroomBlips) do
        RemoveBlip(blip)
    end

    cloakroomBlips = {}
end)
