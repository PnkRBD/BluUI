local _, BUI = ...

local CreateFrame = CreateFrame

local Dispatcher = {}
BUI.Dispatcher = Dispatcher

local function Site()
    local stack = debugstack(3, 1, 0) or ''
    local file, line = stack:match('AddOns/BluUI/([^"]+)"%]:(%d+)')
    return file and (file .. ':' .. line) or '?'
end

function Dispatcher.New(callback)
    local frame = CreateFrame('Frame')
    frame._buiPerfName = 'BUI_Dispatcher ' .. Site()
    frame:Hide()
    local pending = false

    frame:SetScript('OnUpdate', function(self)
        self:Hide()
        pending = false
        callback()
    end)

    return function()
        if pending then return end
        pending = true
        frame:Show()
    end
end

function Dispatcher.NewDelayed(callback, delay)
    if BUI.Perf then BUI.Perf.Track('Delayed ' .. Site(), callback) end
    local pending = false

    local function Run()
        pending = false
        callback()
    end

    return function()
        if pending then return end
        pending = true
        C_Timer.After(delay, Run)
    end
end
