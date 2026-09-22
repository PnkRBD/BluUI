local _, BUI = ...

local Datatext = BUI.Datatext

local REFRESH_SEC = 5
local TOOLTIP_ROWS = 20

local memoryMB = 0

local function FormatMemory(megabytes)
    if megabytes >= 1000 then return string.format('%.1fGB', megabytes / 1024) end
    if megabytes >= 1 then return string.format('%.0fMB', megabytes) end
    return string.format('%.0fKB', megabytes * 1024)
end

local function Read()
    local value = collectgarbage('count') / 1024
    if value ~= memoryMB then
        memoryMB = value
        return true
    end
end

local function SortByMemory(first, second) return first.memory > second.memory end

local addonRows = {}

local function GatherAddons()
    UpdateAddOnMemoryUsage()
    wipe(addonRows)
    local total = 0
    for addonIndex = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.IsAddOnLoaded(addonIndex) then
            local memory = GetAddOnMemoryUsage(addonIndex) / 1024
            total = total + memory
            local name, title = C_AddOns.GetAddOnInfo(addonIndex)
            addonRows[#addonRows + 1] = { name = title or name, memory = memory }
        end
    end
    table.sort(addonRows, SortByMemory)
    return total
end

Datatext.Register('memory', {
    name = 'Memory', show = 'showMemory', label = 'Mem:',
    interval = REFRESH_SEC,
    OnUpdate = function()
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        return Datatext.Label(config, self) .. Datatext.Colored(FormatMemory(memoryMB), valueHex)
    end,
    OnClick = function(_, button)
        if button == 'LeftButton' and IsShiftKeyDown() then
            collectgarbage('collect')
            Read()
            Datatext.Refresh()
            return true
        end
    end,
    OnEnter = function(hit)
        local total = GatherAddons()
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine('AddOn Memory', 1, 1, 1)
        tooltip:AddDoubleLine('Total', FormatMemory(total), 0.7, 0.7, 0.7, 1, 1, 1)
        tooltip:AddLine(' ')
        for rowIndex = 1, math.min(#addonRows, TOOLTIP_ROWS) do
            local row = addonRows[rowIndex]
            local share = total > 0 and (row.memory / total) or 0
            tooltip:AddDoubleLine(row.name, FormatMemory(row.memory), 0.85, 0.85, 0.88, 0.5 + share, 1 - share * 0.6, 0.4)
        end
        if #addonRows > TOOLTIP_ROWS then
            tooltip:AddLine('+' .. (#addonRows - TOOLTIP_ROWS) .. ' more', 0.5, 0.5, 0.5)
        end
        tooltip:AddLine(' ')
        tooltip:AddLine('Shift+Left-Click  |cffffffffCollect Garbage|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    sample = function(config, label, colorize) return label .. colorize('512MB') end,
})
