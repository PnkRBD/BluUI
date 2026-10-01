local _, BUI = ...

local CreateFrame = CreateFrame
local Profiler = BUI.Profiler

local Dispatcher = {}
BUI.Dispatcher = Dispatcher

function Dispatcher.New(callback, name)
    local frame = CreateFrame('Frame', name and ('BUI_Dispatch_' .. name:gsub('%W', '')) or nil)
    frame:Hide()
    local pending = false
    local label = 'Next frame ' .. (name or tostring(callback))

    frame:SetScript('OnUpdate', function(self)
        self:Hide()
        pending = false
        Profiler.Run(label, callback)
    end)

    return function()
        if pending then return end
        pending = true
        frame:Show()
    end
end

function Dispatcher.NewDelayed(callback, delay, name)
    local pending = false
    local label = 'After ' .. delay .. 's ' .. name

    local function Run()
        pending = false
        Profiler.Run(label, callback)
    end

    return function()
        if pending then return end
        pending = true
        C_Timer.After(delay, Run)
    end
end
