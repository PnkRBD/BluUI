local _, BUI = ...

local CreateFrame = CreateFrame

local Dispatcher = {}
BUI.Dispatcher = Dispatcher

function Dispatcher.New(callback, name)
    local frame = CreateFrame('Frame', name and ('BUI_Dispatch_' .. name:gsub('%W', '')) or nil)
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
