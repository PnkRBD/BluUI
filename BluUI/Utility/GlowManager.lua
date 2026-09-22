local _, BUI = ...

local GlowManager = {}
BUI.GlowManager = GlowManager

function GlowManager.CancelDeferred(frameData)
    if not frameData then return end
    local timer = frameData._glowTimer
    if timer then
        timer:Cancel()
        frameData._glowTimer = nil
    end
end

function GlowManager.ScheduleDeferred(frameData, delay, callback)
    if not frameData or not callback then return end
    GlowManager.CancelDeferred(frameData)
    frameData._glowTimer = BUI.Prof.NewTimer('Util.GlowManager', delay, function()
        frameData._glowTimer = nil
        callback()
    end)
end

function GlowManager.ResetIconState(frameData)
    if not frameData then return end
    GlowManager.CancelDeferred(frameData)
    frameData._deferredGlowCfg = nil
    frameData._deferredGlowSpellID = nil
end
