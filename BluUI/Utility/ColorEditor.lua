local _, BUI = ...

local GROUPS = {
    { name = 'Power', colors = {
        { key = 'astral',     label = 'Astral Power',  def = { 0.30, 0.52, 0.90 } },
        { key = 'energy',     label = 'Energy',        def = { 1.00, 0.85, 0.10 } },
        { key = 'focus',      label = 'Focus',         def = { 1.00, 0.50, 0.25 } },
        { key = 'fury',       label = 'Fury',          def = { 0.79, 0.26, 0.99 } },
        { key = 'insanity',   label = 'Insanity',      def = { 0.40, 0.00, 0.80 } },
        { key = 'maelstrom',  label = 'Maelstrom',     def = { 0.00, 0.50, 1.00 } },
        { key = 'mana',       label = 'Mana',          def = { 0.20, 0.40, 0.95 } },
        { key = 'pain',       label = 'Pain',          def = { 1.00, 0.61, 0.00 } },
        { key = 'rage',       label = 'Rage',          def = { 0.78, 0.25, 0.25 } },
        { key = 'runicpower', label = 'Runic Power',   def = { 0.00, 0.82, 1.00 } },
    } },
    { name = 'Class Resources', colors = {
        { key = 'arcane',      label = 'Arcane Charges',   def = { 0.10, 0.45, 0.95 } },
        { key = 'cp_charged',  label = 'Charged Combo',    def = { 0.30, 0.55, 0.95 } },
        { key = 'chi',         label = 'Chi',              def = { 0.55, 0.90, 0.70 } },
        { key = 'combo',       label = 'Combo Points',     def = { 0.90, 0.30, 0.30 } },
        { key = 'essence',     label = 'Essence',          def = { 0.39, 0.78, 0.88 } },
        { key = 'holypower',   label = 'Holy Power',       def = { 0.95, 0.90, 0.60 } },
        { key = 'icicles',     label = 'Icicles',          def = { 0.455, 0.851, 0.965 } },
        { key = 'mw',          label = 'Maelstrom Weapon', def = { 0.00, 0.50, 1.00 } },
        { key = 'rune_ready',  label = 'Rune (Ready)',     def = { 0.85, 0.85, 0.90 } },
        { key = 'rune_charge', label = 'Rune (Recharging)',def = { 0.55, 0.55, 0.55 } },
        { key = 'soulfrag',    label = 'Soul Fragments',   def = { 0.74, 0.27, 0.99 } },
        { key = 'soulshards',  label = 'Soul Shards',      def = { 0.58, 0.36, 0.62 } },
    } },
    { name = 'Dispel Types', colors = {
        { key = 'dispel_bleed',   label = 'Bleed',   def = { 1.00, 0.20, 0.20 } },
        { key = 'dispel_curse',   label = 'Curse',   def = { 0.60, 0.00, 1.00 } },
        { key = 'dispel_disease', label = 'Disease', def = { 0.60, 0.40, 0.00 } },
        { key = 'dispel_magic',   label = 'Magic',   def = { 0.20, 0.60, 1.00 } },
        { key = 'dispel_poison',  label = 'Poison',  def = { 0.00, 0.60, 0.00 } },
    } },
}

local function GetColorStore()
    local db = BUI.GetDB()
    if not db then return nil end
    db.colors = db.colors or {}
    local store = db.colors
    for _, group in ipairs(GROUPS) do
        for _, entry in ipairs(group.colors) do
            if not store[entry.key] then
                local defaultColor = entry.def
                store[entry.key] = { r = defaultColor[1], g = defaultColor[2], b = defaultColor[3], a = defaultColor[4] or 1 }
            end
        end
    end
    return store
end

local function BuildCards()
    local store = GetColorStore()
    local cards = {}
    for groupIndex, group in ipairs(GROUPS) do
        local colors = {}
        for colorIndex, entry in ipairs(group.colors) do
            local key, defaultColor = entry.key, entry.def
            colors[colorIndex] = {
                label = entry.label,
                def = defaultColor,
                get = function()
                    local color = store[key]
                    return color.r, color.g, color.b, color.a
                end,
                set = function(red, green, blue, alpha)
                    local color = store[key]
                    color.r, color.g, color.b, color.a = red, green, blue, alpha
                end,
                reset = function()
                    local color = store[key]
                    color.r, color.g, color.b, color.a = defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4] or 1
                end,
            }
        end
        cards[groupIndex] = { name = group.name, colors = colors }
    end
    return cards
end

local PowerTypeEnum = Enum.PowerType
local POWER_KEY = {
    [PowerTypeEnum.Mana]       = 'mana',
    [PowerTypeEnum.Rage]       = 'rage',
    [PowerTypeEnum.Focus]      = 'focus',
    [PowerTypeEnum.Energy]     = 'energy',
    [PowerTypeEnum.RunicPower] = 'runicpower',
    [PowerTypeEnum.LunarPower] = 'astral',
    [PowerTypeEnum.Maelstrom]  = 'maelstrom',
    [PowerTypeEnum.Insanity]   = 'insanity',
    [PowerTypeEnum.Fury]       = 'fury',
    [PowerTypeEnum.Pain]       = 'pain',
}
local RESOURCE_KEY = {
    combo        = 'combo',
    holy         = 'holypower',
    arcane       = 'arcane',
    shard        = 'soulshards',
    soulFrags    = 'soulfrag',
    vengeanceFrags = 'soulfrag',
    chi          = 'chi',
    essence      = 'essence',
    mwStacks     = 'mw',
    icicles      = 'icicles',
    runes        = 'rune_ready',
}

local function Get(key)
    local store = GetColorStore()
    local color = store and key and store[key]
    if color then return color.r, color.g, color.b, color.a or 1 end
    return 1, 1, 1, 1
end

BUI.Colors = {
    GROUPS = GROUPS,
    GetStore = GetColorStore,
    BuildCards = BuildCards,
    Get = Get,
    ResetGroup = function(groupName)
        local store = GetColorStore()
        for _, group in ipairs(GROUPS) do
            if not groupName or group.name == groupName then
                for _, entry in ipairs(group.colors) do
                    local color, defaultColor = store[entry.key], entry.def
                    color.r, color.g, color.b, color.a = defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4] or 1
                end
            end
        end
    end,
    PowerKey = function(powerType) return POWER_KEY[powerType] end,
    ResourceKey = function(config)
        if not config then return nil end
        return RESOURCE_KEY[config.id] or (config.power and POWER_KEY[config.power]) or nil
    end,
}

function BUI.ApplyColors()
    local power = BUI.Power
    if power then
        if power.Primary and power.Primary.Apply then power.Primary.Apply() end
        if power.Secondary and power.Secondary.UpdateAppearance then power.Secondary.UpdateAppearance() end
        if power.Mods and power.Mods.Apply then power.Mods.Apply() end
    end
    local unitFrames = BUI.UnitFrames
    if unitFrames then
        if unitFrames.Refresh then unitFrames:Refresh() end
        if unitFrames.RefreshDispelPreview then unitFrames.RefreshDispelPreview() end
    end
    local groupFrames = BUI.GroupFrames
    if groupFrames then
        if groupFrames.RefreshColors then groupFrames.RefreshColors() end
        if groupFrames.RestyleAllDispelBadges then groupFrames.RestyleAllDispelBadges() end
    end
end

function BUI.ToggleColorEditor()
    if BUI.PageEngine.EnsureLoaded() and BUI.OpenAppearance then BUI.OpenAppearance('power') end
end

SLASH_BUICOLORS1 = '/buicolors'
SlashCmdList['BUICOLORS'] = function() BUI.ToggleColorEditor() end
