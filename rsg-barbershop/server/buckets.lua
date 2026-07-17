local resourceName = GetCurrentResourceName()
local privatePlayers = {}

RegisterNetEvent(resourceName .. ':server:enterPrivateBucket', function()
    local playerId = source
    privatePlayers[playerId] = true
    SetPlayerRoutingBucket(playerId, 1000 + playerId)
end)

RegisterNetEvent(resourceName .. ':server:leavePrivateBucket', function()
    local playerId = source
    privatePlayers[playerId] = nil
    SetPlayerRoutingBucket(playerId, 0)
end)

AddEventHandler('playerDropped', function()
    privatePlayers[source] = nil
end)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource ~= resourceName then return end

    for playerId in pairs(privatePlayers) do
        SetPlayerRoutingBucket(playerId, 0)
    end
end)
