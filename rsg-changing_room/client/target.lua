local targetZones = {}

local function findNearestCloakroom(storeCoords)
    local nearestIndex = nil
    local nearestDistance = math.huge

    for index, cloakroom in ipairs(Config.Cloakrooms or {}) do
        local coords = cloakroom.coords
        if coords then
            local distance = #(storeCoords - vector3(coords.x, coords.y, coords.z))
            if distance < nearestDistance then
                nearestDistance = distance
                nearestIndex = index
            end
        end
    end

    return nearestIndex
end

CreateThread(function()
    if GetResourceState('ox_target') ~= 'started' then
        print('[rsg-changing_room] ox_target is not started; changing-room target zones are unavailable')
        return
    end

    for storeId, store in pairs(Config.Stores or {}) do
        local ok, errorMessage = pcall(function()
            if not store.coords then
                error('missing store coords')
            end

            local targetStoreId = storeId
            local cloakroomIndex = findNearestCloakroom(store.coords)
            if not cloakroomIndex then
                error('no cloakroom configured')
            end

            local zoneId = exports.ox_target:addSphereZone({
                coords = store.coords,
                radius = 1.5,
                debug = false,
                drawSprite = false,
                options = {
                    {
                        name = ('rsg_changing_room_%s'):format(targetStoreId),
                        icon = 'fa-solid fa-user-pen',
                        label = 'Open Changing Room',
                        distance = 2.5,
                        onSelect = function()
                            TriggerEvent('rsg-changing_room:client:enterPrivateBucket')
                            TriggerEvent('rsg-changing_room:client:openAtStore', targetStoreId, cloakroomIndex)
                        end,
                    },
                },
            })

            targetZones[#targetZones + 1] = zoneId
        end)

        if not ok then
            print(('[rsg-changing_room] Failed target registration for store "%s": %s')
                :format(tostring(storeId), tostring(errorMessage)))
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, zoneId in ipairs(targetZones) do
        pcall(function()
            exports.ox_target:removeZone(zoneId)
        end)
    end

    targetZones = {}
end)
