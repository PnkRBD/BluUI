local _, BUI = ...

local Datatext = BUI.Datatext
local RED, RESET = Datatext.RED, Datatext.RESET

local fps = 0

local function Read()
    local value = BUI.Round(GetFramerate())
    if value ~= fps then
        fps = value
        return true
    end
end

Datatext.Register('fps', {
    name = 'FPS', show = 'showFPS', label = 'FPS:',
    interval = 1,
    OnUpdate = function()
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        if fps <= 30 then
            return Datatext.Label(config, self) .. RED .. fps .. RESET
        end
        return Datatext.Label(config, self) .. Datatext.Colored(fps, valueHex)
    end,
    sample = function(config, label, colorize) return label .. colorize('60') end,
})
