local _, BUI = ...

local Datatext = BUI.Datatext
local WHITE, RED, RESET = Datatext.WHITE, Datatext.RED, Datatext.RESET
local SLASH = WHITE .. '/' .. RESET

local PING_SOURCES = {
    { value = 'world', text = 'World' },
    { value = 'home',  text = 'Home'  },
    { value = 'both',  text = 'Both'  },
}

local pingHome, pingWorld = 0, 0

local function Read()
    local _, _, home, world = GetNetStats()
    home, world = home or 0, world or 0
    if home ~= pingHome or world ~= pingWorld then
        pingHome, pingWorld = home, world
        return true
    end
end

local function PingText(value, valueHex)
    if value > 100 then return RED .. value .. RESET end
    return Datatext.Colored(value, valueHex)
end

Datatext.Register('ping', {
    name = 'Ping', show = 'showPing', label = 'MS:',
    interval = 1,
    defaults = { pingSource = 'world' },
    OnUpdate = function()
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        local label = Datatext.Label(config, self)
        if config.pingSource == 'both' then
            return label .. PingText(pingHome, valueHex) .. SLASH .. PingText(pingWorld, valueHex)
        elseif config.pingSource == 'home' then
            return label .. PingText(pingHome, valueHex)
        end
        return label .. PingText(pingWorld, valueHex)
    end,
    OnEnter = function(hit, bar)
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine('Latency', 1, 1, 1)
        local config = bar.getConfig()
        local valueColor = (config and config.colorValue) or { r = 0.9, g = 0.9, b = 0.95 }
        local function AddPingLine(label, value)
            local red, green, blue = valueColor.r, valueColor.g, valueColor.b
            if value > 100 then red, green, blue = 1, 0.2, 0.2 end
            tooltip:AddDoubleLine(label, value .. ' ms', 0.7, 0.7, 0.7, red, green, blue)
        end
        AddPingLine('Home', pingHome)
        AddPingLine('World', pingWorld)
        tooltip:Show()
    end,
    options = function(getConfig, apply)
        return {
            {
                kind = 'dropdown', label = 'Source', items = PING_SOURCES, controlWidth = 150,
                get = function() return getConfig().pingSource end,
                set = function(value) getConfig().pingSource = value; apply() end,
            },
        }
    end,
    sample = function(config, label, colorize)
        if config.pingSource == 'both' then return label .. colorize('35') .. SLASH .. colorize('42') end
        return label .. colorize(config.pingSource == 'home' and '35' or '42')
    end,
})
