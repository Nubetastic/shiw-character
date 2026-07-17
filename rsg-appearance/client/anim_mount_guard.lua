local NativeTaskPlayAnim = TaskPlayAnim

local function ScheduleOverlayRefreshIfLocalPlayer(ped)
    if ped ~= PlayerPedId() then return end
    TriggerEvent('rsg-appearance:client:scheduleOverlayRefreshAfterAnim')
end

local function ResolveMountedAnimFlags(ped, flags)
    local resolvedFlags = tonumber(flags) or 1
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return resolvedFlags
    end
    if not IsPedHuman(ped) or not IsPedOnMount(ped) then
        return resolvedFlags
    end

    -- Mounted-safe profile:
    -- 30 for one-shot anims, 31 for looped anims.
    local loopBit = (resolvedFlags & 1) == 1 and 1 or 0
    return 30 | loopBit
end

TaskPlayAnim = function(ped, animDict, animName, blendInSpeed, blendOutSpeed, duration, flags, playbackRate, lockX, lockY, lockZ, p11, p12)
    local resolvedFlags = ResolveMountedAnimFlags(ped, flags)
    local ret = NativeTaskPlayAnim(
        ped,
        animDict,
        animName,
        blendInSpeed,
        blendOutSpeed,
        duration,
        resolvedFlags,
        playbackRate,
        lockX,
        lockY,
        lockZ,
        p11,
        p12
    )
    ScheduleOverlayRefreshIfLocalPlayer(ped)
    return ret
end
