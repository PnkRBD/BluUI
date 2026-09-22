local _, BUI = ...

local CreateFrame = CreateFrame

local Dispatcher = {}
BUI.Dispatcher = Dispatcher

local function Invoke(callback, name)
    local profiler = BUI.Prof
    if profiler.active then
        local startKB = collectgarbage('count')
        local startTime = debugprofilestop()
        callback()
        profiler.Add('dispatch#' .. (name or 'anon'), debugprofilestop() - startTime, collectgarbage('count') - startKB)
    else
        callback()
    end
end

function Dispatcher.New(callback, name)
    local frame = CreateFrame('Frame', name and ('BUI_Dispatch_' .. name:gsub('%W', '')) or nil)
    frame:Hide()
    local pending = false

    frame:SetScript('OnUpdate', function(self)
        self:Hide()
        pending = false
        Invoke(callback, name)
    end)

    return function()
        if pending then return end
        pending = true
        frame:Show()
    end
end

function Dispatcher.NewDelayed(callback, delay, name)
    local pending = false

    local function Run()
        pending = false
        Invoke(callback, name)
    end

    return function()
        if pending then return end
        pending = true
        C_Timer.After(delay, Run)
    end
end
