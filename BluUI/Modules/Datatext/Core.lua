local _, BUI = ...

local Datatext = {}
BUI.Datatext = Datatext

local WHITE, RESET = '|cffffffff', '|r'
Datatext.WHITE, Datatext.RESET = WHITE, RESET
Datatext.RED, Datatext.YELLOW = '|cffff3333', '|cffffb200'
Datatext.DIM = '|cff8a8a90'

local registry, registryList = {}, {}
Datatext.registry, Datatext.registryList = registry, registryList

local BAR_DEFAULTS = {
    kind         = 'TEXT',
    enabled      = false,
    fontSize     = 16,
    font         = 'GLOBAL',
    colorValue   = { r = 0, g = 0.9019608497619629, b = 0.4313725829124451, a = 1 },
    spacing      = 12,
    bgAlpha      = 0,
    bgColor      = { r = 0, g = 0, b = 0 },
    border       = false,
    borderColor  = { r = 0.2, g = 0.2, b = 0.24, a = 1 },
    orientation  = 'HORIZONTAL',
    align        = 'LEFT',
    width        = 0,
    height       = 0,
    title        = '',
    titleAnchor  = 'TOP',
    titleX       = 0,
    titleY       = -6,
    titleSize    = 12,
    titleColor   = { r = 1, g = 1, b = 1 },
    lock         = false,
    strata       = 'MEDIUM',
    frameLevel   = 2,
    mirrorChat   = false,
    alignMinimap = false,
    offsetBottom = 0,
    point        = 'BOTTOM',
    relPoint     = 'BOTTOM',
    x            = 0,
    y            = 0,
    hideLabels   = false,
}
Datatext.BAR_DEFAULTS = BAR_DEFAULTS

local function FillDefaults(destination, source)
    for key, default in pairs(source) do
        if type(default) == 'table' then
            if type(destination[key]) ~= 'table' then destination[key] = {} end
            FillDefaults(destination[key], default)
        elseif destination[key] == nil then
            destination[key] = default
        end
    end
end

local function ApplyBarDefaults(config)
    FillDefaults(config, BAR_DEFAULTS)
end
Datatext.ApplyBarDefaults = ApplyBarDefaults

local function GetBars()
    return BUI.GetDB().datatextBars
end

local function GetBarConfig(barIndex) return GetBars()[barIndex] end
local function GetConfig() return GetBarConfig(1) end
local function GetMinimapConfig() return BUI.GetDB().datatextMinimap end
local function ModuleEnabled() return BUI.GetDB().datatextEnabled ~= false end
local function IsPanel(config) return config and config.kind == 'PANEL' end

Datatext.GetBars = GetBars
Datatext.GetBarConfig = GetBarConfig
Datatext.GetDB = GetConfig
Datatext.GetMinimapDB = GetMinimapConfig
Datatext.ModuleEnabled = ModuleEnabled
Datatext.IsPanel = IsPanel

function Datatext.MigrateBars()
    local profile = BUI.GetDB()
    local list = GetBars()
    if type(profile.datatext) == 'table' then
        local first = {}
        for key, value in pairs(profile.datatext) do first[key] = value end
        if first.spacing == nil then first.spacing = 1 end
        ApplyBarDefaults(first)
        first.name = first.name or 'Bar 1'
        list[1] = first
        profile.datatext = nil
    end
    if type(profile.datatext2) == 'table' then
        if profile.datatext2.enabled and list[1] then
            local second = {}
            for key, value in pairs(profile.datatext2) do second[key] = value end
            if second.spacing == nil then second.spacing = 1 end
            ApplyBarDefaults(second)
            second.name = second.name or 'Bar 2'
            list[2] = second
        end
        profile.datatext2 = nil
    end
    if not profile.datatextBarsInit and #list == 0 then
        local first = { name = 'Bar 1', spacingPx = true }
        ApplyBarDefaults(first)
        list[1] = first
    end
    profile.datatextBarsInit = true
    Datatext.FixBarNames()
    for barIndex = 1, #list do
        local config = list[barIndex]
        if not config.spacingPx then
            config.spacing = (tonumber(config.spacing) or 1) + 12
            config.spacingPx = true
        end
        ApplyBarDefaults(config)
        config.name = config.name or ('Bar ' .. barIndex)
        if config.alignBottom then
            config.alignBottom = false
            config.point, config.relPoint = 'BOTTOM', 'BOTTOM'
            config.y = config.offsetBottom
        end
    end
end

local function KindPrefix(kind)
    return kind == 'PANEL' and 'Panel ' or 'Bar '
end

local function AutoNumber(name, prefix)
    if type(name) == 'string' then return tonumber(name:match('^' .. prefix .. '(%d+)$')) end
    return nil
end

local function UsedNumbers(kind, skipIndex)
    local prefix, list, used = KindPrefix(kind), GetBars(), {}
    for barIndex = 1, #list do
        local config = list[barIndex]
        if barIndex ~= skipIndex and IsPanel(config) == (kind == 'PANEL') then
            local number = AutoNumber(config.name, prefix)
            if number then used[number] = true end
        end
    end
    return used
end

local function FreeName(kind, skipIndex)
    local used = UsedNumbers(kind, skipIndex)
    local number = 1
    while used[number] do number = number + 1 end
    return KindPrefix(kind) .. number
end

function Datatext.FixBarNames()
    local list = GetBars()
    for barIndex = 1, #list do
        local config = list[barIndex]
        local kind = IsPanel(config) and 'PANEL' or 'TEXT'
        local number = AutoNumber(config.name, KindPrefix(kind))
        if number and UsedNumbers(kind, barIndex)[number] then
            config.name = FreeName(kind, barIndex)
        end
    end
end

function Datatext.AddBar(kind)
    kind = kind == 'PANEL' and 'PANEL' or 'TEXT'
    local list = GetBars()
    local newIndex = #list + 1
    local config = {
        kind = kind,
        name = FreeName(kind),
        enabled = true, lock = false, spacingPx = true,
        point = 'CENTER', relPoint = 'CENTER',
        x = 0, y = -40 * (newIndex - 2),
    }
    if kind == 'PANEL' then
        config.width, config.height, config.bgAlpha = 260, 120, 0.6
    end
    ApplyBarDefaults(config)
    list[newIndex] = config
    Datatext.Apply()
    return newIndex
end

function Datatext.DeleteBar(index)
    local list = GetBars()
    if not list[index] then return false end
    table.remove(list, index)
    Datatext.Apply()
    return true
end

local function BarShows(config, key) return config.enabled and config[key] end

function Datatext.AnyShows(key)
    if BarShows(GetMinimapConfig(), key) then return true end
    if not ModuleEnabled() then return false end
    local list = GetBars()
    for barIndex = 1, #list do
        if BarShows(list[barIndex], key) then return true end
    end
    return false
end

local QueueApply = BUI.Dispatcher.New(function()
    if Datatext._initialized then Datatext.Apply() end
end, 'Datatext.Register')

function Datatext.Register(id, entry)
    if registry[id] then
        for listIndex = #registryList, 1, -1 do
            if registryList[listIndex].id == id then table.remove(registryList, listIndex) end
        end
    end
    entry.id = id
    entry.show = entry.show or ('show_' .. id)
    entry.label = entry.label or (entry.name .. ':')
    entry.labelText = WHITE .. entry.label .. RESET .. ' '
    entry.key = 'Datatext.' .. id
    entry.interactive = (entry.OnClick or entry.OnEnter) and true or false
    entry.active = false
    BAR_DEFAULTS[entry.show] = false
    if entry.defaults then
        for key, value in pairs(entry.defaults) do BAR_DEFAULTS[key] = value end
    end
    registry[id] = entry
    registryList[#registryList + 1] = entry
    if Datatext._initialized then
        local list = GetBars()
        for barIndex = 1, #list do ApplyBarDefaults(list[barIndex]) end
        QueueApply()
    end
    return entry
end

function Datatext.Get(id) return registry[id] end
function Datatext.List() return registryList end

function Datatext.Label(config, entry)
    if config.hideLabels then return '' end
    return entry.labelText
end

function Datatext.Colored(value, valueHex)
    return '|cff' .. valueHex .. value .. RESET
end

function Datatext.ResolveOrder(config)
    local result, seen = {}, {}
    local order = config and config.order
    if order then
        for orderIndex = 1, #order do
            local id = order[orderIndex]
            if registry[id] and not seen[id] then
                result[#result + 1] = id
                seen[id] = true
            end
        end
    end
    for listIndex = 1, #registryList do
        local id = registryList[listIndex].id
        if not seen[id] then result[#result + 1] = id end
    end
    return result
end

function Datatext.PanelFont() return BUI.GetGlobalFont() end

function Datatext.Tooltip(hit)
    local anchor = 'ANCHOR_TOP'
    local centerY = select(2, hit:GetCenter())
    if centerY and centerY > UIParent:GetHeight() / 2 then anchor = 'ANCHOR_BOTTOM' end
    GameTooltip:SetOwner(hit, anchor)
    GameTooltip:ClearLines()
    return GameTooltip
end

function Datatext.HoversBlocked()
    if InCombatLockdown() and BUI.GetDB().datatextHideHoversInCombat ~= false then return true end
    local menu = _G.BUI_MinimapMenu
    return menu and menu:IsShown() or false
end

function Datatext.OpenCurrencyUI()
    if BUI.Skinning.IsSkinEnabled('currencyManager') then
        BUI.CurrencyManager.Toggle()
        return
    end
    ToggleCharacter('TokenFrame')
end

function Datatext.FormatMoney(copper, goldOnly)
    copper = copper or 0
    local negative = copper < 0
    if negative then copper = -copper end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cents = copper % 100
    local goldText = BreakUpLargeNumbers(gold)
    local text
    if goldOnly or gold >= 1000 then
        text = goldText .. '|cffffd700g|r'
    elseif gold > 0 then
        text = string.format('%s|cffffd700g|r %d|cffc7c7cfs|r', goldText, silver)
    elseif silver > 0 then
        text = string.format('%d|cffc7c7cfs|r %d|cffeda55fc|r', silver, cents)
    else
        text = string.format('%d|cffeda55fc|r', cents)
    end
    if negative then text = '-' .. text end
    return text
end

function Datatext.BuildModuleOptions(getConfig, apply)
    local rows = {}
    for listIndex = 1, #registryList do
        local entry = registryList[listIndex]
        rows[#rows + 1] = {
            label = entry.name,
            get   = function() return getConfig()[entry.show] end,
            set   = function(value) getConfig()[entry.show] = value; apply() end,
        }
        if entry.options then
            local extra = entry.options(getConfig, apply)
            for extraIndex = 1, #extra do
                local row = extra[extraIndex]
                row.indent = row.indent or 1
                rows[#rows + 1] = row
            end
        end
    end
    return rows
end

function Datatext.BuildSampleParts(config)
    local valueColor = config.colorValue
    local valueHex = BUI.Hex(valueColor.r, valueColor.g, valueColor.b)
    local function colorize(text) return '|cff' .. valueHex .. text .. RESET end
    local parts = {}
    local order = Datatext.ResolveOrder(config)
    for orderIndex = 1, #order do
        local entry = registry[order[orderIndex]]
        if entry and config[entry.show] then
            local label = config.hideLabels and '' or entry.labelText
            local text
            if entry.sample then
                text = entry.sample(config, label, colorize)
            else
                text = label .. colorize('123')
            end
            if text and text ~= '' then parts[#parts + 1] = text end
        end
    end
    return parts
end
