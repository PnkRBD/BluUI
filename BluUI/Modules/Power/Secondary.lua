local _, BUI = ...

BUI.Power.Secondary = {}
local SecondaryPower = BUI.Power.Secondary
local Pixel = BUI.Pixel
local ClassPowers = BUI.ClassPowers
local Shared = BUI.Power.Shared
local SafeNum = BUI.Tools.SafeNum

local frame, text
local PointBars = {}
local BarDisplay
local chargedScratch = {}

local function GetDB() return BUI.Power.GetSecondaryDB() end
local function GetFont() return BUI.GetSecondaryPowerFont() end
local function GetTexture() return BUI.GetGlobalTexture() end
local settingKeyMemo = {}
local function Setting(prefix, key)
    local prefixMemo = settingKeyMemo[prefix]
    if not prefixMemo then prefixMemo = {}; settingKeyMemo[prefix] = prefixMemo end
    local fullKey = prefixMemo[key]
    if not fullKey then fullKey = prefix .. key; prefixMemo[key] = fullKey end
    return GetDB()[fullKey]
end
local function IsAnchored(db) return BUI.ResolveAnchorFrame(db.anchorFrame) ~= nil end
local function IsStacked()
    if BUI.Power.Stack.IsEnabled() then return true end
    return BUI.Power.Container.HasMember('secondary')
end

local function ResourceColor(config)
    if config.id ~= "runes" then
        local key = BUI.Colors.ResourceKey(config)
        if key then
            local red, green, blue = BUI.Colors.Get(key)
            if red then return red, green, blue end
        end
    end
    return Setting(config.prefix, "ColorR") or 1, Setting(config.prefix, "ColorG") or 1, Setting(config.prefix, "ColorB") or 1
end

local function UpdateOpacity()
    if not frame then return end
    frame:SetAlpha(BUI.Visibility.GetContextualOpacity("SecondaryPower") / 100)
end

local runeOrder = {}
local runeRecharging = {}
for runeIndex = 1, 6 do
    runeOrder[runeIndex] = { ready = false, start = 0, dur = 0 }
    runeRecharging[runeIndex] = { index = 0, start = 0, dur = 0, rem = 0 }
end
local runesRecharging = false
local runesForceRefresh = false

local function RuneSort(left, right)
    if left.index == 0 then return false end
    if right.index == 0 then return true end
    return left.rem < right.rem
end

local staggerCache = { value = 0, max = 1, pct = 0, time = 0 }
local icicleMaxCache

local function UpdateStaggerCache()
    local now = GetTime()
    if now - staggerCache.time < 0.016 then return end
    local value = UnitStagger("player") or 0
    if issecretvalue(value) then
        staggerCache.time = now
        return
    end
    local max = UnitHealthMax("player") or 1
    if max == 0 then max = 1 end
    staggerCache.value = value
    staggerCache.max = max
    staggerCache.pct = (value / max) * 100
    staggerCache.time = now
end

local Configs = {
    {
        id = "runes", label = "Runes", classes = { "DEATHKNIGHT" }, mode = "point", prefix = "rune", max = 6,
        hasCooldown = true, trigger = "runes",
        check = ClassPowers.IsDeathKnight,
        getValue = function()
            local ready = 0
            for runeIndex = 1, 6 do
                local _, _, isReady = GetRuneCooldown(runeIndex)
                if isReady then ready = ready + 1 end
            end
            return ready, 6
        end,
    },
    {
        id = "combo", label = "Combo Points", classes = { "ROGUE", "DRUID" }, mode = "point", prefix = "combo", max = 7,
        power = Enum.PowerType.ComboPoints,
        check = function()
            return ClassPowers.IsRogue() or ClassPowers.IsDruidInCatForm()
        end,
    },
    {
        id = "holy", label = "Holy Power", classes = { "PALADIN" }, mode = "point", prefix = "holy", max = 5,
        power = Enum.PowerType.HolyPower,
        check = ClassPowers.IsPaladin,
    },
    {
        id = "arcane", label = "Arcane Charges", classes = { "MAGE" }, mode = "point", prefix = "arcane", max = 4,
        power = Enum.PowerType.ArcaneCharges,
        check = ClassPowers.IsArcane,
    },
    {
        id = "shard", label = "Soul Shards", classes = { "WARLOCK" }, mode = "point", prefix = "shard", max = 5,
        power = Enum.PowerType.SoulShards,
        check = ClassPowers.IsWarlock,
    },
    {
        id = "essence", label = "Essence", classes = { "EVOKER" }, mode = "point", prefix = "essence", max = 6,
        power = Enum.PowerType.Essence,
        check = ClassPowers.IsEvoker,
    },
    {
        id = "chi", label = "Chi", classes = { "MONK" }, mode = "point", prefix = "chi", max = 6,
        power = Enum.PowerType.Chi,
        check = ClassPowers.IsWindwalker,
    },
    {
        id = "mwStacks", label = "Maelstrom Weapon", classes = { "SHAMAN" }, mode = "point", prefix = "mwStacks", max = 10,
        check = ClassPowers.IsEnhancement,
        getValue = function()
            return BUI.Tools.GetAuraStacks('player', 344179) or 0, 10
        end,
    },
    {
        id = "icicles", label = "Icicles", classes = { "MAGE" }, mode = "point", prefix = "icicles", max = 5,
        trigger = "aura",
        check = ClassPowers.IsFrostMage,
        getValue = function()
            if not icicleMaxCache then
                icicleMaxCache = C_Spell.GetSpellMaxCumulativeAuraApplications(205473) or 5
            end
            return BUI.Tools.GetAuraStacks('player', 205473) or 0, icicleMaxCache
        end,
    },
    {
        id = "casterMana", label = "Mana", classes = { "PRIEST", "SHAMAN", "DRUID" }, mode = "bar", prefix = "casterMana",
        power = Enum.PowerType.Mana,
        check = function()
            return ClassPowers.IsShadow() or ClassPowers.IsElemental() or ClassPowers.IsBalance()
        end,
    },
    {
        id = "stagger", label = "Stagger", classes = { "MONK" }, mode = "bar", prefix = "stagger",
        trigger = "aura",
        check = ClassPowers.IsBrewmaster,
        getValue = function()
            UpdateStaggerCache()
            return staggerCache.value, staggerCache.pct, staggerCache.max
        end,
        getColor = function()
            UpdateStaggerCache()
            local db = GetDB()
            local percent = staggerCache.pct
            if percent >= 60 then
                return db.staggerHeavyColorR, db.staggerHeavyColorG, db.staggerHeavyColorB
            elseif percent >= 30 then
                return db.staggerModerateColorR, db.staggerModerateColorG, db.staggerModerateColorB
            end
            return db.staggerLightColorR, db.staggerLightColorG, db.staggerLightColorB
        end,
    },
    {
        id = "soulFrags", label = "Soul Fragments", classes = { "DEMONHUNTER" }, mode = "bar", prefix = "soulFrags",
        trigger = "aura",
        check = ClassPowers.IsDevourer,
        getValue = function()
            local stacks = BUI.Tools.GetAuraStacks('player', 1225789)
            if not stacks or stacks == 0 then
                stacks = BUI.Tools.GetAuraStacks('player', 1227702) or stacks
            end
            local maxStacks = C_SpellBook.IsSpellKnown(1247534) and 35 or 50
            return stacks or 0, maxStacks
        end,
    },
    {
        id = "vengeanceFrags", label = "Soul Fragments", classes = { "DEMONHUNTER" }, mode = "point", prefix = "vengeanceFrags", max = 6,
        trigger = "aura", secret = true,
        check = ClassPowers.IsVengeance,
        getValue = function()
            return C_Spell.GetSpellCastCount(228477) or 0, 6
        end,
    },
}

local activeConfig
local editPreviewId
local cachedOverrideConfig

local function GetOverrideConfig()
    local source = GetDB().source
    if type(source) ~= "number" then return nil end
    if not cachedOverrideConfig or cachedOverrideConfig.power ~= source then
        cachedOverrideConfig = {
            id = "override", label = "Override", mode = "bar", prefix = "override",
            power = source, check = function() return true end,
        }
    end
    return cachedOverrideConfig
end

local function GetActiveConfig()
    local overrideConfig = GetOverrideConfig()
    if overrideConfig then return overrideConfig end
    for configIndex = 1, #Configs do
        if Configs[configIndex].check() then return Configs[configIndex] end
    end
end

local function GetDruidFormSecondaryOverride()
    if not ClassPowers.IsDruid() then return nil end
    if not ClassPowers.IsFormDataReady() then return nil end
    local formOverrides = GetDB().formOverrides
    return formOverrides and formOverrides[ClassPowers.NormalizeDruidForm(GetShapeshiftFormID())]
end

local function GetDisplayConfig()
    if GetDB().source == "none" then return nil end
    local overrideConfig = GetOverrideConfig()
    if overrideConfig then return overrideConfig end
    local formOverride = GetDruidFormSecondaryOverride()
    if formOverride == 'none' then return nil end
    if type(formOverride) == 'string' then
        for configIndex = 1, #Configs do
            if Configs[configIndex].id == formOverride then return Configs[configIndex] end
        end
    end
    if editPreviewId then
        for configIndex = 1, #Configs do
            if Configs[configIndex].id == editPreviewId then return Configs[configIndex] end
        end
    end
    return GetActiveConfig()
end

function SecondaryPower.GetActiveConfig() return GetActiveConfig() end
function SecondaryPower.GetDisplayConfig() return GetDisplayConfig() end

local function IsPreviewing()
    return editPreviewId ~= nil and activeConfig ~= nil
        and activeConfig.id == editPreviewId and not activeConfig.check()
end

function SecondaryPower.GetConfigsForClass()
    local _, class = UnitClass("player")
    local matches = {}
    for _, config in ipairs(Configs) do
        if config.classes then
            for _, configClass in ipairs(config.classes) do
                if configClass == class then matches[#matches + 1] = config; break end
            end
        end
    end
    return matches
end

function SecondaryPower.HasSecondary()
    if not BUI.IsModuleEnabled("power") then return false end
    if GetDB().source == "none" then return false end
    if type(GetDB().source) == "number" then return true end
    if ClassPowers.IsHunter() then return false end
    ClassPowers.UpdateSpecID()
    return GetDisplayConfig() ~= nil
end

local function ShouldShow() return SecondaryPower.HasSecondary() end

local function HideAllBars()
    for barIndex = 1, #PointBars do PointBars[barIndex].container:Hide() end
    if BarDisplay then BarDisplay.container:Hide() end
end

local function CreatePointBar(parent, config)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:EnableMouse(false)

    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetStatusBarTexture(GetTexture())
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetStatusBarColor(ResourceColor(config))

    local cooldownText
    if config.hasCooldown then
        local overlay = CreateFrame("Frame", nil, container)
        overlay:SetAllPoints(container)
        overlay:SetFrameLevel(container:GetFrameLevel() + 20)
        cooldownText = overlay:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(cooldownText, 10, GetFont())
        cooldownText:SetPoint("CENTER")
        cooldownText:Hide()
    end
    return { container = container, bar = bar, cdText = cooldownText }
end

local function CreateBarDisplay(parent)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:EnableMouse(false)

    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetStatusBarTexture(GetTexture())
    bar:SetMinMaxValues(0, 100)

    local overlay = CreateFrame("Frame", nil, container)
    overlay:SetAllPoints(container)
    overlay:SetFrameLevel(container:GetFrameLevel() + 20)
    overlay:EnableMouse(false)
    local valueText = overlay:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(valueText, 14, GetFont())
    valueText:SetPoint("CENTER")

    return { container = container, bar = bar, valText = valueText }
end

local function GetDestroShardsRaw()
    local raw = SafeNum(UnitPower("player", Enum.PowerType.SoulShards, true))
    if not raw then return 0, 0 end
    local fullShards = math.floor(raw / 10)
    return fullShards, raw - fullShards * 10
end

local function IsDestroShard(config)
    return config.id == "shard" and ClassPowers.GetSpecID() == ClassPowers.Specs.DESTRUCTION
end

local function RefreshRuneState()
    local now = GetTime()
    local ready, recharging = 0, 0
    for runeIndex = 1, 6 do runeRecharging[runeIndex].index = 0 end

    for runeIndex = 1, 6 do
        local start, duration, isReady = GetRuneCooldown(runeIndex)
        if isReady or not start or not duration then
            ready = ready + 1
        else
            recharging = recharging + 1
            local entry = runeRecharging[recharging]
            entry.index = runeIndex
            entry.start = start
            entry.dur = duration
            entry.rem = (start + duration) - now
        end
    end

    local wasRecharging = runesRecharging
    runesRecharging = recharging > 0
    if runesForceRefresh then
        runesForceRefresh = false
    elseif not runesRecharging and not wasRecharging then
        return false
    end

    table.sort(runeRecharging, RuneSort)

    local slot = 0
    for _ = 1, ready do
        slot = slot + 1
        runeOrder[slot].ready = true
    end
    for rechargeIndex = 1, recharging do
        slot = slot + 1
        local entry = runeRecharging[rechargeIndex]
        local order = runeOrder[slot]
        order.ready = false
        order.start = entry.start
        order.dur = entry.dur
    end
    return true
end

local function PaintRune(pointBar, info, db, colorR, colorG, colorB)
    if info.ready then
        pointBar.bar:SetValue(1)
        pointBar.bar:SetStatusBarColor(colorR, colorG, colorB)
        if pointBar.cdText then pointBar.cdText:Hide() end
        return
    end
    local remaining = (info.start + info.dur) - GetTime()
    pointBar.bar:SetValue(math.max(0, math.min(1, 1 - remaining / info.dur)))
    pointBar.bar:SetStatusBarColor(db.runeRechargingColorR, db.runeRechargingColorG, db.runeRechargingColorB)
    if pointBar.cdText and db.showRuneCooldown then
        pointBar.cdText:SetFormattedText("%.1f", math.max(0, remaining))
        pointBar.cdText:Show()
    elseif pointBar.cdText then
        pointBar.cdText:Hide()
    end
end

local function UpdatePointDisplay(config)
    local current, max
    if config.getValue then
        current, max = config.getValue()
    else
        current = UnitPower("player", config.power)
        max = UnitPowerMax("player", config.power)
    end

    if config.secret then
        local pointCount = SafeNum(max) or config.max or 1
        if Setting(config.prefix, "NumberOnly") then
            HideAllBars()
            if Setting(config.prefix, "ShowMax") then
                text:SetText(string.format("%s/%s", AbbreviateNumbers(current), pointCount))
            else
                text:SetText(string.format("%s", AbbreviateNumbers(current)))
            end
            text:Show()
            return
        end
        text:Hide()
        if BarDisplay then BarDisplay.container:Hide() end
        local colorR, colorG, colorB = ResourceColor(config)
        for pointIndex = 1, pointCount do
            if not PointBars[pointIndex] then PointBars[pointIndex] = CreatePointBar(frame, config) end
            local pointBar = PointBars[pointIndex]
            pointBar.bar:SetMinMaxValues(pointIndex - 1, pointIndex)
            pointBar.bar:SetValue(current)
            pointBar.bar:SetStatusBarColor(colorR, colorG, colorB)
            pointBar.container:Show()
        end
        for pointIndex = pointCount + 1, #PointBars do PointBars[pointIndex].container:Hide() end
        return
    end

    current = SafeNum(current) or 0
    max = SafeNum(max) or config.max or 1
    if max == 0 then max = config.max or 1 end

    if IsPreviewing() then current = math.ceil(max * 0.6) end

    local numberOnly = Setting(config.prefix, "NumberOnly")

    if numberOnly then
        HideAllBars()
        if IsDestroShard(config) then
            local fullShards, fragments = GetDestroShardsRaw()
            if fragments > 0 then
                text:SetFormattedText(Setting(config.prefix, "ShowMax") and "%d.%d/%d" or "%d.%d", fullShards, fragments, max)
            else
                text:SetFormattedText(Setting(config.prefix, "ShowMax") and "%d/%d" or "%d", fullShards, max)
            end
        elseif Setting(config.prefix, "ShowMax") then
            text:SetFormattedText("%d/%d", current, max)
        else
            text:SetFormattedText("%d", current)
        end
        text:Show()
        return
    end

    text:Hide()
    if BarDisplay then BarDisplay.container:Hide() end

    local db = GetDB()
    local colorR, colorG, colorB = ResourceColor(config)

    local chargedSet, chargedRed, chargedGreen, chargedBlue
    if config.id == "combo" then
        local charged = GetUnitChargedPowerPoints("player")
        if charged and #charged > 0 then
            chargedSet = wipe(chargedScratch)
            for chargedIndex = 1, #charged do chargedSet[charged[chargedIndex]] = true end
            chargedRed = Setting(config.prefix, "ChargedColorR") or 0.96
            chargedGreen = Setting(config.prefix, "ChargedColorG") or 0.55
            chargedBlue = Setting(config.prefix, "ChargedColorB") or 0.73
        end
    end

    if config.id == "runes" and not RefreshRuneState() then return end

    local destroFull, destroFragments
    if IsDestroShard(config) then destroFull, destroFragments = GetDestroShardsRaw() end

    for pointIndex = 1, max do
        if not PointBars[pointIndex] then PointBars[pointIndex] = CreatePointBar(frame, config) end
        local pointBar = PointBars[pointIndex]

        if config.id == "runes" then
            PaintRune(pointBar, runeOrder[pointIndex], db, colorR, colorG, colorB)
        elseif destroFull then
            local fullShards, fragments = destroFull, destroFragments
            if pointIndex <= fullShards then
                pointBar.bar:SetValue(1)
                pointBar.bar:SetStatusBarColor(colorR, colorG, colorB)
            elseif pointIndex == fullShards + 1 and fragments > 0 then
                pointBar.bar:SetValue(fragments / 10)
                pointBar.bar:SetStatusBarColor(colorR, colorG, colorB)
            else
                pointBar.bar:SetValue(0)
            end
        else
            if chargedSet and chargedSet[pointIndex] and pointIndex <= current then
                pointBar.bar:SetValue(1)
                pointBar.bar:SetStatusBarColor(chargedRed, chargedGreen, chargedBlue)
            elseif pointIndex <= current then
                pointBar.bar:SetValue(1)
                pointBar.bar:SetStatusBarColor(colorR, colorG, colorB)
            else
                pointBar.bar:SetValue(0)
            end
        end
        pointBar.container:Show()
    end

    for pointIndex = max + 1, #PointBars do PointBars[pointIndex].container:Hide() end

    if not Setting(config.prefix, "HideBarText") and config.id ~= "runes" then
        if destroFull then
            if destroFragments > 0 then
                text:SetFormattedText("%d.%d", destroFull, destroFragments)
            else
                text:SetFormattedText("%d", destroFull)
            end
        else
            text:SetFormattedText("%d", current)
        end
        text:Show()
    else
        text:Hide()
    end
end

local function FormatBarText(target, staggerShowsPercent, showValue, showPercent, safeCurrent, current, percent, percentValue, hidePercentSign)
    local percentFormat = hidePercentSign and "%.0f" or "%.0f%%"
    if staggerShowsPercent and showValue then
        target:SetFormattedText(hidePercentSign and "%d (%.0f)" or "%d (%.0f%%)", safeCurrent or 0, percent or 0)
    elseif staggerShowsPercent then
        target:SetFormattedText(percentFormat, percent or 0)
    elseif showPercent and percentValue ~= nil then
        target:SetFormattedText(percentFormat, percentValue)
    elseif showValue and safeCurrent ~= nil then
        target:SetFormattedText("%s", AbbreviateNumbers(safeCurrent))
    elseif showValue and current ~= nil then
        target:SetFormattedText("%s", current)
    elseif showValue and percentValue ~= nil then
        target:SetFormattedText(percentFormat, percentValue)
    else
        target:SetText("")
    end
end

local function UpdateBarDisplay(config)
    local current, max, percent
    if config.getValue then
        local firstValue, secondValue, thirdValue = config.getValue()
        if thirdValue then current, percent, max = firstValue, secondValue, thirdValue else current, max = firstValue, secondValue end
        if config.getColor and BarDisplay then
            BarDisplay.bar:SetStatusBarColor(config.getColor())
        end
    else
        local powerType = config.power or UnitPowerType("player")
        current = UnitPower("player", powerType)
        max = UnitPowerMax("player", powerType)
    end

    local staggerLive = config.id == "stagger" and percent ~= nil
    local barMode = Setting(config.prefix, "BarMode")
    local showValue = Setting(config.prefix, "ShowValue") ~= false
    local showPercent = Setting(config.prefix, "ShowPercent") == true
    local hidePercentSign = Setting(config.prefix, "HidePercentSign") == true
    local safeCurrent, safeMax = SafeNum(current), SafeNum(max)

    if IsPreviewing() then
        if not (safeMax and safeMax > 0) then safeMax = 100 end
        safeCurrent = math.floor(safeMax * 0.7 + 0.5)
        if percent then percent = 25 end
    end

    local percentValue = percent
    if not percentValue then
        if safeCurrent and safeMax and safeMax > 0 then
            percentValue = safeCurrent / safeMax * 100
        elseif config.power then
            percentValue = UnitPowerPercent("player", config.power, true, CurveConstants.ScaleTo100)
        end
    end

    local staggerShowsPercent = staggerLive and Setting(config.prefix, "ShowPercent") ~= false

    if not barMode then
        HideAllBars()
        FormatBarText(text, staggerShowsPercent, showValue, showPercent, safeCurrent, current, percent, percentValue, hidePercentSign)
        text:Show()
        return
    end

    text:Hide()
    for barIndex = 1, #PointBars do PointBars[barIndex].container:Hide() end

    if not BarDisplay then BarDisplay = CreateBarDisplay(frame) end

    BarDisplay.bar:SetMinMaxValues(0, 100)
    BarDisplay.bar:SetValue(percentValue or 0)

    if config._lowPowerCurve and config.power then
        local color = UnitPowerPercent("player", config.power, false, config._lowPowerCurve)
        if color and color.GetRGB then
            BarDisplay.bar:GetStatusBarTexture():SetVertexColor(color:GetRGB())
        else

            BarDisplay.bar:GetStatusBarTexture():SetVertexColor(
                Setting(config.prefix, "ColorR") or 1, Setting(config.prefix, "ColorG") or 1, Setting(config.prefix, "ColorB") or 1)
        end
    end

    FormatBarText(BarDisplay.valText, staggerShowsPercent, showValue, showPercent, safeCurrent, current, percent, percentValue, hidePercentSign)
    BarDisplay.container:Show()
end

local function Update()
    if not frame then return end
    local config = activeConfig
    if not config then
        HideAllBars()
        text:Hide()
        return
    end
    if config.mode == "point" then UpdatePointDisplay(config) else UpdateBarDisplay(config) end
end

local function ApplyTextColor(config)
    local db = GetDB()
    local prefix = config.prefix
    if db.useClassColor then
        text:SetTextColor(ResourceColor(config))
    elseif config.id == "runes" then
        text:SetTextColor(db.runeTextColorR, db.runeTextColorG, db.runeTextColorB)
    elseif config.id == "stagger" then
        text:SetTextColor(db.staggerTextColorR, db.staggerTextColorG, db.staggerTextColorB)
    else
        local resourceRed, resourceGreen, resourceBlue = ResourceColor(config)
        text:SetTextColor(Setting(prefix, "TextColorR") or resourceRed, Setting(prefix, "TextColorG") or resourceGreen, Setting(prefix, "TextColorB") or resourceBlue)
    end
end

function SecondaryPower.GetBarColor(config)
    if not config then return 1, 1, 1 end
    if config.getColor then return config.getColor() end
    return ResourceColor(config)
end

function SecondaryPower.GetResourceColor(config)
    return ResourceColor(config)
end

local function StylePointBars(config)
    local db = GetDB()
    local prefix = config.prefix

    local _, max
    if config.getValue then _, max = config.getValue() else max = UnitPowerMax("player", config.power) end
    max = SafeNum(max) or config.max or 1
    if max == 0 then max = config.max or 1 end

    if Setting(prefix, "NumberOnly") then
        HideAllBars()
        text:ClearAllPoints()
        if Shared.IsAnchoredFor(db, true) then
            text:SetPoint("CENTER")
        elseif config.id == "runes" then
            text:SetPoint("CENTER", frame, "CENTER", db.runeTextOffsetX, db.runeTextOffsetY)
        else
            text:SetPoint("CENTER", frame, "CENTER", db.textOffsetX, db.textOffsetY)
        end
        local size = config.id == "runes" and db.runeTextSize or db.textSize
        Pixel.ApplyFont(text, size, GetFont())
        ApplyTextColor(config)
        text:Show()
        return
    end

    if BarDisplay then BarDisplay.container:Hide() end

    local texture = GetTexture()
    local borderSize = Pixel.ClampBorder(db.borderSize or 1)
    local borderColor = db.borderColor or { 0, 0, 0, 1 }
    local edge = Pixel.Scale(borderSize)

    local anchorWidth = BUI.Anchor.GetAnchorWidth(frame, db)
    local scaledTotalWidth, scaledWidth, scaledHeight, scaledGap
    local widths

    if anchorWidth then
        scaledTotalWidth = anchorWidth
        scaledHeight = Pixel.Scale(Setting(prefix, "Height") or 12)
        scaledGap = Pixel.Scale(Setting(prefix, "Spacing") or 0)
        local visualGap = scaledGap == 0 and -edge or scaledGap

        local contentWidth = scaledTotalWidth - (max - 1) * visualGap
        widths = {}
        local previousBoundary = 0
        for pointIndex = 1, max do
            local boundary = Pixel.Scale(pointIndex * contentWidth / max)
            widths[pointIndex] = boundary - previousBoundary
            previousBoundary = boundary
        end
        scaledWidth = widths[1] or 0
    else
        local totalWidth = Setting(prefix, "TotalWidth") or 200
        local gap = Setting(prefix, "Spacing") or 0
        scaledWidth = Pixel.Scale((totalWidth - (max - 1) * gap) / max)
        scaledHeight = Pixel.Scale(Setting(prefix, "Height") or 12)
        scaledGap = Pixel.Scale(gap)
        scaledTotalWidth = max * scaledWidth + (max - 1) * scaledGap
    end
    local function SegmentWidth(pointIndex) return widths and widths[pointIndex] or scaledWidth end

    local backgroundRed = Setting(prefix, "BgColorR") or 0.15
    local backgroundGreen = Setting(prefix, "BgColorG") or 0.15
    local backgroundBlue = Setting(prefix, "BgColorB") or 0.15
    local backgroundAlpha = Setting(prefix, "BgColorA") or 1

    for pointIndex = 1, max do
        if not PointBars[pointIndex] then PointBars[pointIndex] = CreatePointBar(frame, config) end
        local pointBar = PointBars[pointIndex]
        pointBar.container:SetSize(SegmentWidth(pointIndex), scaledHeight)
        Pixel.SetTemplate(pointBar.container, backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha, borderColor[1], borderColor[2], borderColor[3], borderColor[4], borderSize)

        pointBar.bar:ClearAllPoints()
        pointBar.bar:SetPoint("TOPLEFT", pointBar.container, "TOPLEFT", edge, -edge)
        pointBar.bar:SetPoint("BOTTOMRIGHT", pointBar.container, "BOTTOMRIGHT", -edge, edge)
        pointBar.bar:SetStatusBarTexture(texture)

        if pointBar.cdText then
            Pixel.ApplyFont(pointBar.cdText, db.runeCooldownSize, GetFont())
            pointBar.cdText:SetTextColor(db.runeCooldownColorR, db.runeCooldownColorG, db.runeCooldownColorB)
        end
    end

    local barOffsetX = config.id == "runes" and db.runeBarOffsetX or Setting(prefix, "BarOffsetX") or 0
    local barOffsetY = config.id == "runes" and db.runeBarOffsetY or Setting(prefix, "BarOffsetY") or 0

    local visualGap = scaledGap == 0 and -edge or scaledGap
    local anchored = IsAnchored(db) or IsStacked()
    local contentOffsetX = anchored and 0 or barOffsetX
    local contentOffsetY = anchored and 0 or barOffsetY

    if widths then
        local rowWidth = (max - 1) * visualGap
        for pointIndex = 1, max do rowWidth = rowWidth + widths[pointIndex] end
        local cursor = Pixel.Snap(-rowWidth / 2)
        for pointIndex = 1, max do
            PointBars[pointIndex].container:ClearAllPoints()
            PointBars[pointIndex].container:SetPoint("CENTER", frame, "CENTER", cursor + widths[pointIndex] / 2 + contentOffsetX, contentOffsetY)
            cursor = cursor + widths[pointIndex] + visualGap
            PointBars[pointIndex].container:Show()
        end
    else
        local visualTotalWidth = max * scaledWidth + (max - 1) * visualGap
        local startX = Pixel.Snap(-visualTotalWidth / 2 + scaledWidth / 2)
        for pointIndex = 1, max do
            PointBars[pointIndex].container:ClearAllPoints()
            PointBars[pointIndex].container:SetPoint("CENTER", frame, "CENTER", startX + (pointIndex - 1) * (scaledWidth + visualGap) + contentOffsetX, contentOffsetY)
            PointBars[pointIndex].container:Show()
        end
    end
    for pointIndex = max + 1, #PointBars do PointBars[pointIndex].container:Hide() end

    if not Setting(prefix, "HideBarText") and config.id ~= "runes" then
        text:ClearAllPoints()
        local valueOffsetX = Setting(prefix, "ValueOffsetX") or 0
        local valueOffsetY = Setting(prefix, "ValueOffsetY") or 0
        text:SetPoint("CENTER", frame, "CENTER", contentOffsetX + valueOffsetX, contentOffsetY + valueOffsetY)
        Pixel.ApplyFont(text, Setting(prefix, "CenterTextSize") or 14, GetFont())
        text:SetTextColor(Setting(prefix, "ValueColorR") or 1, Setting(prefix, "ValueColorG") or 1, Setting(prefix, "ValueColorB") or 1)
    end
end

local function StyleBarDisplay(config)
    local db = GetDB()
    local prefix = config.prefix

    if not Setting(prefix, "BarMode") then
        HideAllBars()
        text:ClearAllPoints()
        if Shared.IsAnchoredFor(db, true) then
            text:SetPoint("CENTER")
        else
            text:SetPoint("CENTER", frame, "CENTER", db.textOffsetX, db.textOffsetY)
        end
        Pixel.ApplyFont(text, db.textSize, GetFont())
        ApplyTextColor(config)
        text:Show()
        return
    end

    text:Hide()
    if not BarDisplay then BarDisplay = CreateBarDisplay(frame) end

    local texture = GetTexture()
    local borderSize = Pixel.ClampBorder(db.borderSize or 1)
    local borderColor = db.borderColor or { 0, 0, 0, 1 }
    local edge = Pixel.Scale(borderSize)

    local anchorWidth = BUI.Anchor.GetAnchorWidth(frame, db)
    local scaledWidth = anchorWidth or Pixel.Scale(Setting(prefix, "BarWidth") or 200)
    local scaledHeight = Pixel.Scale(Setting(prefix, "BarHeight") or 16)

    BarDisplay.container:SetSize(scaledWidth, scaledHeight)
    Pixel.SetTemplate(BarDisplay.container,
        Setting(prefix, "BgColorR") or 0.1, Setting(prefix, "BgColorG") or 0.1, Setting(prefix, "BgColorB") or 0.1, Setting(prefix, "BgColorA") or 1,
        borderColor[1], borderColor[2], borderColor[3], borderColor[4], borderSize)

    Shared.ApplyStackFlush(BarDisplay.container, BarDisplay.bar, db.stackFlushEdge, edge,
        Setting(prefix, "BgColorR") or 0.1, Setting(prefix, "BgColorG") or 0.1, Setting(prefix, "BgColorB") or 0.1, Setting(prefix, "BgColorA") or 1)
    BarDisplay.bar:SetStatusBarTexture(texture)

    local red, green, blue
    if config.getColor then
        red, green, blue = config.getColor()
    else
        red, green, blue = ResourceColor(config)
    end
    BarDisplay.bar:SetStatusBarColor(red, green, blue)

    if db.lowPowerEnabled and config.power and not config.getColor then
        config._lowPowerCurve = Shared.BuildLowPowerCurve(config._lowPowerCurve, db, ResourceColor(config))
    else
        config._lowPowerCurve = nil
    end

    BarDisplay.valText:ClearAllPoints()
    local valueOffsetX = Setting(prefix, "ValueOffsetX") or 0
    local valueOffsetY = Setting(prefix, "ValueOffsetY") or 0
    BarDisplay.valText:SetPoint("CENTER", BarDisplay.container, "CENTER", valueOffsetX, valueOffsetY)
    Pixel.ApplyFont(BarDisplay.valText, Setting(prefix, "ValueSize") or 14, GetFont())
    BarDisplay.valText:SetTextColor(Setting(prefix, "ValueColorR") or 1, Setting(prefix, "ValueColorG") or 1, Setting(prefix, "ValueColorB") or 1)
    BarDisplay.valText:SetShown(not Setting(prefix, "HideBarText"))

    Shared.StyleTicks(BarDisplay.bar, db, scaledWidth, scaledHeight, edge)

    BarDisplay.container:ClearAllPoints()
    if IsAnchored(db) or IsStacked() then
        BarDisplay.container:SetPoint("CENTER")
    else
        BarDisplay.container:SetPoint("CENTER", frame, "CENTER", Setting(prefix, "BarOffsetX") or 0, Setting(prefix, "BarOffsetY") or 0)
    end
end

local function ApplyTextStrata()
    local strata = GetDB().textStrata or 'HIGH'
    if text then text:GetParent():SetFrameStrata(strata) end
    if BarDisplay then BarDisplay.valText:GetParent():SetFrameStrata(strata) end
    for barIndex = 1, #PointBars do
        local pointBar = PointBars[barIndex]
        if pointBar.cdText then pointBar.cdText:GetParent():SetFrameStrata(strata) end
    end
end

local function IsTextActive(config)
    if not config then return false end
    local isBar = config.mode == "bar"
    if isBar and Setting(config.prefix, "BarMode") then return false end
    if config.id == "runes" then return GetDB().runeNumberOnly and true or false end
    if isBar then return true end
    return Setting(config.prefix, "NumberOnly") and true or false
end

local function Style()
    if not text then return end
    local db = GetDB()
    local config = activeConfig
    if config then
        if config.mode == "point" then StylePointBars(config) else StyleBarDisplay(config) end
    end

    local padding = (Shared.IsAnchoredFor(db, IsTextActive(config)) or IsStacked()) and 0 or 20
    local anchorWidth = BUI.Anchor.GetAnchorWidth(frame, db)
    local frameWidth, frameHeight = 120 + padding, 50 + padding

    if config then
        local prefix = config.prefix
        if config.mode == "point" and not Setting(prefix, "NumberOnly") then
            frameWidth = (anchorWidth or Pixel.Scale(Setting(prefix, "TotalWidth") or 120)) + padding
            frameHeight = Pixel.Scale(Setting(prefix, "Height") or 12) + padding
        elseif config.mode == "bar" and Setting(prefix, "BarMode") then
            frameWidth = (anchorWidth or Pixel.Scale(Setting(prefix, "BarWidth") or 200)) + padding
            frameHeight = Pixel.Scale(Setting(prefix, "BarHeight") or 16) + padding
        end
    end
    frame:SetSize(frameWidth, frameHeight)
    ApplyTextStrata()
end

local function Position()
    if not frame then return end
    local db = GetDB()
    BUI.Anchor.ApplyPosition(frame, BUI.Anchor.ModePos(db, IsTextActive(activeConfig)))
end

local function Build()
    if frame then return end

    frame = CreateFrame("Frame", "BUI_SecondaryPower", UIParent)
    frame:SetSize(Pixel.Scale(120), Pixel.Scale(50))
    frame:SetFrameStrata("LOW")
    frame:Hide()
    frame:EnableMouse(true)
    local function NotifyAnchorChange()
        if not BUI.Power.Stack.IsEnabled() then
            BUI.Anchor.OnAnchorSizeChanged()
        end
    end
    frame:HookScript("OnShow", NotifyAnchorChange)
    frame:HookScript("OnHide", NotifyAnchorChange)

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 100)
    overlay:EnableMouse(false)

    text = overlay:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")
    Pixel.ApplyFont(text, 26, GetFont())

    BUI.Dragging.MakeDraggable(frame, {
        showHint = true,
        showUnlockedBg = true,
        hintAnchor = "TOP",
        isLocked = function() return GetDB().locked end,
        onPositionChanged = function(x, y)
            local db = GetDB()
            local pos = BUI.Anchor.ModePos(db, IsTextActive(activeConfig))
            if pos.centerHorizontally then
                local _, centerY = BUI.Dragging.GetCenterOffset(frame)
                x, y = 0, centerY
            end
            pos.posX, pos.posY = x, y
            Position()
        end,
        onRightClick = function() SecondaryPower.SetLocked(true) end,
        usePointPosition = true,
    })
end

local lifecycleStarted, powerEventsStarted, tickerRunning, opacityStarted = false, false, false, false

local function OnLifecycleEvent(event)
    if event ~= "UPDATE_SHAPESHIFT_FORM" and event ~= "UPDATE_SHAPESHIFT_FORMS" and event ~= "PLAYER_ENTERING_WORLD" then
        editPreviewId = nil
    end
    SecondaryPower.Apply()
end

local function StartLifecycleEvents()
    if lifecycleStarted then return end
    lifecycleStarted = true
    local label = "SecondaryPowerLifecycle"
    BUI.Events:Register("PLAYER_ENTERING_WORLD", label, OnLifecycleEvent)
    BUI.Events:Register("PLAYER_SPECIALIZATION_CHANGED", label, OnLifecycleEvent)
    BUI.Events:Register("PLAYER_TALENT_UPDATE", label, OnLifecycleEvent)
    BUI.Events:Register("UPDATE_SHAPESHIFT_FORM", label, OnLifecycleEvent)
    BUI.Events:Register("UPDATE_SHAPESHIFT_FORMS", label, OnLifecycleEvent)
    BUI.Events:Register("ACTIVE_TALENT_GROUP_CHANGED", label, OnLifecycleEvent)
    BUI.Events:RegisterUnit("UNIT_DISPLAYPOWER", "player", label, function() SecondaryPower.Apply() end)
end

local function StartPowerEvents()
    if powerEventsStarted then return end
    powerEventsStarted = true
    BUI.Events:RegisterUnit("UNIT_MAXPOWER", "player", "SecondaryPower", function() Style(); Update() end)
end

local function StopPowerEvents()
    if not powerEventsStarted then return end
    BUI.Events:Unregister("UNIT_MAXPOWER", "SecondaryPower")
    powerEventsStarted = false
end

local TICKER_INTERVAL = 0.05

local function StopTicker()
    if not tickerRunning then return end
    BUI.Scheduler.SetUpdateEnabled("SecondaryPower", false)
    tickerRunning = false
end

local function TickerTick()
    Update()
    if not runesRecharging then StopTicker() end
end

local function StartTicker()
    if tickerRunning then return end
    BUI.Scheduler.RegisterUpdate("SecondaryPower", TickerTick, TICKER_INTERVAL, true)
    tickerRunning = true
end

local function SyncRuneTicker()
    if runesRecharging and not GetDB().runeNumberOnly then
        StartTicker()
    else
        StopTicker()
    end
end

local function OnRuneEvent()
    Update()
    SyncRuneTicker()
end

local function OnAuraEvent()
    Update()
end

local function OnLivePowerEvent()
    if not activeConfig or activeConfig.trigger then return end
    Update()
end

local function StartOpacityEvents()
    if opacityStarted then return end
    opacityStarted = true
    BUI.Visibility.Register("SecondaryPower", UpdateOpacity, true)
end

local function StopOpacityEvents()
    if not opacityStarted then return end
    BUI.Visibility.Unregister("SecondaryPower")
    opacityStarted = false
end

local function Shutdown()
    StopTicker()
    StopPowerEvents()
    StopOpacityEvents()
    BUI.Events:UnregisterAll("SecPowerLive")
    if frame then frame:Hide() end
end

local function Activate()
    Build()
    StopTicker()
    StartPowerEvents()
    StartOpacityEvents()
    BUI.Events:Unregister("UNIT_POWER_FREQUENT",     "SecPowerLive")
    BUI.Events:Unregister("UNIT_POWER_POINT_CHARGE", "SecPowerLive")
    BUI.Events:Unregister("UNIT_AURA",               "SecPowerLive")
    BUI.Events:Unregister("RUNE_POWER_UPDATE",       "SecPowerLive")
    local trigger = activeConfig and activeConfig.trigger
    if trigger == "runes" then
        BUI.Events:Register("RUNE_POWER_UPDATE", "SecPowerLive", OnRuneEvent)
    elseif trigger == "aura" then
        BUI.Events:RegisterUnit("UNIT_AURA", "player", "SecPowerLive", OnAuraEvent)
    else
        BUI.Events:RegisterUnit("UNIT_POWER_FREQUENT",     "player", "SecPowerLive", OnLivePowerEvent)
        BUI.Events:RegisterUnit("UNIT_POWER_POINT_CHARGE", "player", "SecPowerLive", OnLivePowerEvent)
    end
    Position()
    Style()
    Update()
    if trigger == "runes" then SyncRuneTicker() end
    UpdateOpacity()
    BUI.Dragging.SetLocked(frame, GetDB().locked)
    frame:Show()
end

local function OnAnchorSizeChanged()
    if Shared.ShouldReanchor(frame, GetDB()) then
        Position()
        Style()
    end
end

function SecondaryPower.Initialize()
    StartLifecycleEvents()
    BUI.Anchor.RegisterCallback("SecondaryPower", OnAnchorSizeChanged)
    Pixel.OnScaleChange("SecondaryPower", function()
        if frame and GetDB().enabled and activeConfig then
            Style()
            Position()
        end
    end)
    if not ShouldShow() then return end

    activeConfig = GetDisplayConfig()
    runesRecharging = false
    if GetDB().enabled then Activate() end
end

function SecondaryPower.Toggle(on)
    GetDB().enabled = on
    if on and ShouldShow() then
        activeConfig = GetDisplayConfig()
        runesRecharging = false
        Activate()
    else
        Shutdown()
    end
end

function SecondaryPower.Apply()
    ClassPowers.UpdateSpecID()
    activeConfig = GetDisplayConfig()
    runesRecharging = false
    runesForceRefresh = true
    if not GetDB().enabled or not ShouldShow() then
        Shutdown()
        return
    end
    Activate()
end

function SecondaryPower.SetEditPreview(previewID)
    if editPreviewId == previewID then return end
    editPreviewId = previewID
    SecondaryPower.Apply()
end

function SecondaryPower.GetEditPreview()
    return editPreviewId
end

function SecondaryPower.UpdateAppearance()
    if not frame then return end
    Style()
end

function SecondaryPower.SetLocked(locked)
    if not frame then return end
    local db = GetDB()
    db.locked = locked
    BUI.Dragging.SetLocked(frame, locked)
    if SecondaryPower._lockToggle and SecondaryPower._lockToggle.SetValue then
        SecondaryPower._lockToggle:SetValue(not locked)
    end
end

BUI.Events:OnLogin("SecondaryPower", function()
    SecondaryPower.Initialize()
    Shared.DeferRefresh(function() return frame end, GetDB, function() Position() Style() end)
end)
