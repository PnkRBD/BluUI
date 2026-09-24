local _, BUI = ...

local LibCustomGlow = LibStub('LibCustomGlow-1.0')
local floor, min = math.floor, math.min

local GlowManager = {}
BUI.GlowManager = GlowManager

GlowManager.STYLES = { pixel = true, autocast = true, button = true, proc = true }

local function SpeedMultiplier(speed)
    local multiplier = speed / 100
    if multiplier < 0.01 then multiplier = 0.01 end
    return multiplier
end

function GlowManager.PixelLength(width, height, lineCount)
    if width < 1 or height < 1 then return nil end
    return min(floor((width + height) * (2 / lineCount - 0.1)), min(width, height))
end

local procOptions = { xOffset = 0, yOffset = 0 }

local Start = {
    pixel = function(frame, color, speed, lines, thickness, key, layer, length)
        LibCustomGlow.PixelGlow_Start(frame, color, lines, SpeedMultiplier(speed) * 0.25, length, thickness, 0, 0, false, key, layer)
    end,
    autocast = function(frame, color, speed, lines, _, key, layer)
        LibCustomGlow.AutoCastGlow_Start(frame, color, lines, SpeedMultiplier(speed) * 0.125, 1, 0, 0, key, layer)
    end,
    button = function(frame, color, speed, _, _, _, layer)
        LibCustomGlow.ButtonGlow_Start(frame, color, speed ~= 100 and SpeedMultiplier(speed) or nil, layer)
    end,
    proc = function(frame, color, speed, _, _, key, layer, _, startAnim)
        procOptions.color = color
        procOptions.duration = 1 / SpeedMultiplier(speed)
        procOptions.key = key
        procOptions.frameLevel = layer
        procOptions.startAnim = startAnim or false
        LibCustomGlow.ProcGlow_Start(frame, procOptions)
    end,
}

local Stop = {
    pixel = function(frame, key) LibCustomGlow.PixelGlow_Stop(frame, key) end,
    autocast = function(frame, key) LibCustomGlow.AutoCastGlow_Stop(frame, key) end,
    button = function(frame) LibCustomGlow.ButtonGlow_Stop(frame) end,
    proc = function(frame, key) LibCustomGlow.ProcGlow_Stop(frame, key) end,
}

function GlowManager.Start(frame, style, color, speed, lines, thickness, key, layer, length, startAnim)
    Start[style](frame, color, speed, lines, thickness, key, layer, length, startAnim)
end

function GlowManager.Stop(frame, style, key)
    Stop[style](frame, key)
end

function GlowManager.CancelDeferred(frameData)
    local timer = frameData._glowTimer
    if timer then
        timer:Cancel()
        frameData._glowTimer = nil
    end
end

function GlowManager.ScheduleDeferred(frameData, delay, callback)
    GlowManager.CancelDeferred(frameData)
    frameData._glowTimer = C_Timer.NewTimer(delay, function()
        frameData._glowTimer = nil
        callback()
    end)
end

function GlowManager.ResetIconState(frameData)
    GlowManager.CancelDeferred(frameData)
    frameData._deferredGlowCfg = nil
    frameData._deferredGlowSpellID = nil
    frameData._deferredGlowExpiry = nil
end
