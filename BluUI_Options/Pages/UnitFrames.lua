local BUI = BluUI
local SetScript, HookScript = BUI.Prof.Scripts('Pages.UnitFrames')

local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals
local Pixel = BUI.Pixel
local FONT = BUI.C.FONT_PATH
local Tabs = { "Global", "Reference", "Custom Tags", "Player", "Target", "ToT", "Focus", "Pet", "Boss", "Filters" }
local _currentTabIndex, _currentPage = 1, nil

local function ResolveShow(specific, fallback, defaultOn)
    if specific ~= nil then return specific == true end
    if defaultOn == false then return fallback == true end
    return fallback ~= false
end

local TagSuggestions = {
    { tag = "[name]", desc = "Unit name" }, { tag = "[name:short]", desc = "Name truncated (10 chars)" },
    { tag = "[name:short5]", desc = "Name truncated (5 chars)" }, { tag = "[hp]", desc = "Current HP or Dead" },
    { tag = "[hp:short]", desc = "HP abbreviated or Dead" }, { tag = "[maxhp]", desc = "Max HP (100000)" },
    { tag = "[maxhp:short]", desc = "Max HP abbreviated (100K)" }, { tag = "[perhp]", desc = "HP percent or Dead" },
    { tag = "[pp]", desc = "Current power (6000)" }, { tag = "[pp:short]", desc = "Power abbreviated (6K)" },
    { tag = "[maxpp]", desc = "Max power (10000)" }, { tag = "[maxpp:short]", desc = "Max power abbreviated (10K)" },
    { tag = "[perpp]", desc = "Power percent (60)" }, { tag = "[mana]", desc = "Current mana (8000)" },
    { tag = "[mana:short]", desc = "Mana abbreviated (8K)" }, { tag = "[maxmana]", desc = "Max mana (10000)" },
    { tag = "[maxmana:short]", desc = "Max mana abbreviated (10K)" }, { tag = "[permana]", desc = "Mana percent (80)" },
    { tag = "[powertype]", desc = "Power type (Mana)" }, { tag = "[absorbs]", desc = "Absorb shield (5K)" },
    { tag = "[hpabsorb]", desc = "HP + absorb shield (raw)" }, { tag = "[hpabsorb:short]", desc = "HP + absorb abbreviated (492K)" },
    { tag = "[level]", desc = "Unit level (80)" }, { tag = "[class]", desc = "Class uppercase (HUNTER)" },
    { tag = "[classname]", desc = "Class name (Hunter)" }, { tag = "[race]", desc = "Race (Night Elf)" },
    { tag = "[classification]", desc = "Elite/Rare/Boss" }, { tag = "[status]", desc = "Dead/Ghost/Offline" },
    { tag = "[dead]", desc = "Dead indicator" }, { tag = "[offline]", desc = "Offline indicator" },
    { tag = "[afk]", desc = "AFK indicator" }, { tag = "[dnd]", desc = "DND indicator" },
    { tag = "[resting]", desc = "Resting (zzz)" }, { tag = "[combat]", desc = "In combat (!)" },
    { tag = "[combattime]", desc = "Combat duration [01:23]" },
    { tag = "[creature]", desc = "Pet family or creature type" }, { tag = "[creaturefamily]", desc = "Pet family (Cat, Wolf)" },
    { tag = "[creaturetype]", desc = "Creature type (Beast)" }, { tag = "[server]", desc = "Server name" },
    { tag = "[target]", desc = "Target name" }, { tag = "[name:target]", desc = "Name > Target" },
    { tag = "[name5:target5]", desc = "Name > Target (both truncated)" },
    { tag = "[group]", desc = "Raid group number (1-8)" },
    { tag = "[itemlevel]", desc = "Item level (639)" },
    { tag = "[spec]", desc = "Specialization (Marksmanship)" },
    { tag = "[title]", desc = "Player title (the Exalted)" },
    { tag = "[difficulty]", desc = "Instance difficulty (Mythic)" },
    { tag = "[role]", desc = "Role icon (tank/healer/dps)" },
    { tag = "[role:text]", desc = "Role text (Tank/Healer/DPS)" },
    { tag = "[threat]", desc = "Threat % on target (42%)" },
    { tag = "[range]", desc = "Distance estimate (25-30)" },
}

local function GetTagSuggestionsForUnit(unitType)
    if not BUI.UnitFrames or not BUI.UnitFrames.IsTagValidForUnit then return TagSuggestions end
    local filtered = {}
    for _, item in ipairs(TagSuggestions) do
        local tagName = item.tag:match("%[([^%]]+)%]")
        if tagName and BUI.UnitFrames.IsTagValidForUnit(tagName, unitType) then
            filtered[#filtered + 1] = item
        end
    end
    return filtered
end

local pageHeaders, unitGrids = {}, {}

local function RefreshPageMocks()
    for _, header in pairs(pageHeaders) do
        if header.Update and header.stage and header.stage:IsVisible() then header.Update() end
    end
end

local function RefreshFrames()
    BUI.UnitFrames.InvalidateSettingsCache()
    BUI.UnitFrames:Refresh()
    BUI.UnitFrames.UpdatePreviews()
    RefreshPageMocks()
end

local function BuildFiltersTab(tab, RefreshAurasOnly)
    local function Filters() return BUI.GetDB().auraFilters end
    local AuraBlacklist = BUI.AuraBlacklist
    local shared = AuraBlacklist.IsShared()

    local function Apply()
        local UnitFrames = BUI.UnitFrames
        if UnitFrames and UnitFrames.InvalidateFilterCache then UnitFrames.InvalidateFilterCache() end
        if UnitFrames and UnitFrames.RefreshAuraLayout then
            if UnitFrames.targettarget then UnitFrames.RefreshAuraLayout(UnitFrames.targettarget, "targettarget") end
            if UnitFrames.pet then UnitFrames.RefreshAuraLayout(UnitFrames.pet, "pet") end
        end
        RefreshAurasOnly()
    end

    BUI.ShareBlacklistToggle(tab, 'Share Blacklists With Group Frames')

    BUI.SpellListSection(tab, {
        title = 'Pinned Buffs',
        desc = 'Always shown on every unit frame, on top of whatever the buff rules match.',
        get = function() return Filters().buffWhitelist end,
        onChange = Apply,
    })
    Layout.Toggle(tab, 'Only Show Pinned Buffs', Filters().buffWhitelistOnly == true, function(value)
        Filters().buffWhitelistOnly = value; Apply()
    end, 'Ignore the buff rules entirely and show nothing but the pinned list.')

    BUI.BlacklistSection(tab, {
        scope = 'unit', polarity = 'HELPFUL',
        title = 'Buff Blacklist',
        desc = shared and 'Buffs that never show anywhere, shared with Group Frames.'
            or 'Buffs that never show on unit frames.',
        onChange = Apply,
    })

    BUI.SpellListSection(tab, {
        title = 'Pinned Debuffs',
        desc = 'Always shown on every unit frame, on top of whatever the debuff rules match.',
        get = function() return Filters().debuffWhitelist end,
        onChange = Apply,
    })
    Layout.Toggle(tab, 'Only Show Pinned Debuffs', Filters().debuffWhitelistOnly == true, function(value)
        Filters().debuffWhitelistOnly = value; Apply()
    end, 'Ignore the debuff rules entirely and show nothing but the pinned list.')

    BUI.BlacklistSection(tab, {
        scope = 'unit', polarity = 'HARMFUL',
        title = 'Debuff Blacklist',
        desc = shared and 'Debuffs that never show anywhere, shared with Group Frames.'
            or 'Debuffs that never show on unit frames.',
        onChange = Apply,
    })
end

local function RefreshAurasOnly()
    if not BUI.UnitFrames then return end
    BUI.UnitFrames.InvalidateSettingsCache()
    local UnitFrames = BUI.UnitFrames
    if UnitFrames.player and UnitFrames.RefreshAuraLayout then UnitFrames.RefreshAuraLayout(UnitFrames.player, "player") end
    if UnitFrames.target and UnitFrames.RefreshAuraLayout then UnitFrames.RefreshAuraLayout(UnitFrames.target, "target") end
    if UnitFrames.focus and UnitFrames.RefreshAuraLayout then UnitFrames.RefreshAuraLayout(UnitFrames.focus, "focus") end
    for bossIndex = 1, 5 do
        local bossFrame = UnitFrames["boss" .. bossIndex]
        if bossFrame and UnitFrames.RefreshAuraLayout then UnitFrames.RefreshAuraLayout(bossFrame, "boss") end
    end
    for _, unitType in ipairs({"player", "target", "focus", "targettarget", "pet"}) do
        local preview = UnitFrames._previewFrames and UnitFrames._previewFrames[unitType]
        if preview and preview:IsShown() and UnitFrames.UpdatePreviewAurasOnly then
            UnitFrames.UpdatePreviewAurasOnly(preview, unitType)
        end
    end
    if UnitFrames._previewFrames and UnitFrames._previewFrames["boss"] and UnitFrames.UpdatePreviewAurasOnly then
        for bossIndex = 1, 5 do
            local bossFrame = UnitFrames["boss" .. bossIndex]
            if bossFrame and bossFrame:IsShown() then UnitFrames.UpdatePreviewAurasOnly(bossFrame, "boss", bossIndex) end
        end
    end
    RefreshPageMocks()
end

local function UnitFrameSettings()
    return BUI.GetDB().unitFrames
end

local function ResolveUnitFrameMedia(kind, key, fallback)
    if key and key ~= '' and key ~= 'GLOBAL' then
        local sharedMedia = LibStub('LibSharedMedia-3.0')
        local path = sharedMedia:Fetch(kind, key, true)
        if path then return path end
    end
    return fallback
end

local MOCK_DEBUFF_ICONS = {
    'Interface\\Icons\\Spell_Shadow_ShadowWordPain',
    'Interface\\Icons\\Spell_Fire_Immolation',
    'Interface\\Icons\\Ability_Rogue_Rupture',
    'Interface\\Icons\\Spell_Shadow_CurseOfSargeras',
    'Interface\\Icons\\Spell_Frost_FrostNova',
    'Interface\\Icons\\Ability_Warrior_Sunder',
    'Interface\\Icons\\Spell_Shadow_AbominationExplosion',
    'Interface\\Icons\\Spell_Nature_CorrosiveBreath',
}
local MOCK_BUFF_ICONS = {
    'Interface\\Icons\\Spell_Nature_Rejuvenation',
    'Interface\\Icons\\Spell_Holy_PowerWordShield',
    'Interface\\Icons\\Spell_Holy_Renew',
    'Interface\\Icons\\Ability_Warrior_BattleShout',
    'Interface\\Icons\\Spell_Nature_LightningShield',
    'Interface\\Icons\\Spell_Holy_DevotionAura',
    'Interface\\Icons\\Spell_Nature_ProtectionformNature',
    'Interface\\Icons\\INV_Potion_167',
}
local MOCK_DISPEL_COLORS = {
    { 0.2, 0.6, 1.0 },
    { 0.6, 0.0, 1.0 },
    { 0.0, 0.6, 0.0 },
    { 0.8, 0.0, 0.0 },
}

local function MockPointX(point, width)
    if point:find('LEFT') then return 0 end
    if point:find('RIGHT') then return width end
    return width / 2
end

local function MockPointY(point, height)
    if point:find('TOP') then return 0 end
    if point:find('BOTTOM') then return height end
    return height / 2
end

local function MockGrowthAnchor(growX, growY)
    local vertical = growY == 'UP' and 'BOTTOM' or 'TOP'
    local horizontal = growX == 'RIGHT' and 'LEFT' or 'RIGHT'
    return vertical .. horizontal
end

local function CreateUnitMock(stage)
    local WHITE = 'Interface\\Buttons\\WHITE8x8'
    local mock = CreateFrame('Frame', nil, stage)
    mock:SetPoint('CENTER')

    local borderTexture = mock:CreateTexture(nil, 'BACKGROUND', nil, 0)
    borderTexture:SetTexture(WHITE); borderTexture:SetAllPoints()
    local backgroundTexture = mock:CreateTexture(nil, 'BACKGROUND', nil, 1)
    backgroundTexture:SetTexture(WHITE)
    backgroundTexture:SetPoint('TOPLEFT', 1, -1); backgroundTexture:SetPoint('BOTTOMRIGHT', -1, 1)
    local healthTexture = mock:CreateTexture(nil, 'ARTWORK', nil, 0)
    local healthZone = CreateFrame('Frame', nil, mock)
    local absorbTexture = mock:CreateTexture(nil, 'ARTWORK', nil, 1)
    absorbTexture:SetTexture(WHITE)
    local powerBackgroundTexture = mock:CreateTexture(nil, 'ARTWORK', nil, 0)
    powerBackgroundTexture:SetTexture(WHITE)
    local powerTexture = mock:CreateTexture(nil, 'ARTWORK', nil, 1)
    local nameFontString = mock:CreateFontString(nil, 'OVERLAY')
    local healthFontString = mock:CreateFontString(nil, 'OVERLAY')
    local powerFontString = mock:CreateFontString(nil, 'OVERLAY')
    local raidIcon = mock:CreateTexture(nil, 'OVERLAY')
    raidIcon:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_8')
    local customFontStrings, auraIcons = {}, {}

    local function AuraIcon(index)
        if not auraIcons[index] then
            local icon = {}
            icon.border = mock:CreateTexture(nil, 'OVERLAY', nil, 1)
            icon.border:SetTexture(WHITE)
            icon.tex = mock:CreateTexture(nil, 'OVERLAY', nil, 2)
            icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            auraIcons[index] = icon
        end
        return auraIcons[index]
    end

    function mock:SetOffset(x, y)
        local scale = self:GetScale()
        self:ClearAllPoints()
        self:SetPoint('CENTER', stage, 'CENTER', x / scale, y / scale)
    end

    function mock:Render(unitKey, options)
        options = options or {}
        local settings = UnitFrameSettings()
        if not settings then self:Hide(); return 0, 0 end
        local unitSettings = settings[unitKey] or {}
        local isPet = unitKey == 'pet'
        local width = unitSettings.width or 200
        local height = unitSettings.height or 40

        local Parse = BUI.UnitFrames and BUI.UnitFrames.ParsePreviewTags
        local texture = ResolveUnitFrameMedia('statusbar', settings.texture, BUI.GetGlobalTexture())
        local font = ResolveUnitFrameMedia('font', settings.font, BUI.GetGlobalFont())

        local showDebuffs = unitSettings.showDebuffs == true
        local showBuffs = unitSettings.showBuffs == true
        local auraPadding = 0
        if showDebuffs then
            local count = math.min(unitSettings.maxDebuffs, 16)
            local perRow = math.max(1, math.min(unitSettings.debuffsPerRow or unitSettings.maxDebuffs, count))
            local rows = math.ceil(count / perRow)
            local size = unitSettings.debuffIconSize or unitSettings.auraIconSize
            local gap = unitSettings.debuffSpacing or unitSettings.auraSpacing
            auraPadding = math.max(auraPadding, rows * size + (rows - 1) * gap + 8)
        end
        if showBuffs then
            local count = math.min(unitSettings.maxBuffs, 16)
            local perRow = math.max(1, math.min(unitSettings.buffsPerRow or unitSettings.maxBuffs, count))
            local rows = math.ceil(count / perRow)
            local size = unitSettings.buffIconSize or unitSettings.auraIconSize
            local gap = unitSettings.buffSpacing or unitSettings.auraSpacing
            auraPadding = math.max(auraPadding, rows * size + (rows - 1) * gap + 8)
        end

        local scale = math.min(1, (options.maxW or 620) / width, (options.maxH or 150) / (height + auraPadding * 2))
        self:SetScale(scale)
        self:SetSize(width, height)

        local borderColor = (isPet and settings.petBorderColor) or settings.borderColor or { 0, 0, 0, 1 }
        borderTexture:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1)
        local backgroundColor = (isPet and settings.petBgColor) or settings.bgColor or { 0.1, 0.1, 0.1, 0.8 }
        backgroundTexture:SetVertexColor(backgroundColor[1] or 0.1, backgroundColor[2] or 0.1, backgroundColor[3] or 0.1, backgroundColor[4] or 1)

        local showPower = unitSettings.showPower
        local powerBarHeight = showPower and math.min(unitSettings.powerHeight, height - 6) or 0

        local innerWidth = width - 2
        local innerHeight = height - 2 - powerBarHeight - (powerBarHeight > 0 and 1 or 0)
        local _, class = UnitClass('player')
        local classColor = class and RAID_CLASS_COLORS[class]
        local healthRed, healthGreen, healthBlue = 0.2, 0.8, 0.2
        if settings.classColorHealth and classColor then
            healthRed, healthGreen, healthBlue = classColor.r, classColor.g, classColor.b
        else
            local color = (isPet and settings.petHealthColor) or settings.healthColor
            if color then healthRed, healthGreen, healthBlue = color[1] or healthRed, color[2] or healthGreen, color[3] or healthBlue end
        end
        healthTexture:SetTexture(texture)
        healthTexture:ClearAllPoints()
        healthTexture:SetPoint('TOPLEFT', 1, -1)
        healthTexture:SetSize(innerWidth * 0.72, innerHeight)
        healthTexture:SetVertexColor(healthRed, healthGreen, healthBlue, settings.transparentHealth and (settings.healthBarAlpha or 0.7) or 1)
        healthZone:ClearAllPoints()
        healthZone:SetPoint('TOPLEFT', 1, -1)
        healthZone:SetSize(innerWidth, innerHeight)

        if settings.shieldEnabled ~= false then
            local shieldColor = settings.shieldColor
            absorbTexture:ClearAllPoints()
            absorbTexture:SetPoint('TOPLEFT', healthTexture, 'TOPRIGHT', 0, 0)
            absorbTexture:SetSize(innerWidth * 0.1, innerHeight)
            absorbTexture:SetVertexColor(shieldColor[1] or 1, shieldColor[2] or 1, shieldColor[3] or 1, shieldColor[4] or 0.6)
            absorbTexture:Show()
        else
            absorbTexture:Hide()
        end

        if powerBarHeight > 0 then
            local powerRed, powerGreen, powerBlue
            if isPet and settings.petPowerColor then
                local color = settings.petPowerColor
                powerRed, powerGreen, powerBlue = color[1], color[2], color[3]
            elseif settings.classColorPower then
                powerRed, powerGreen, powerBlue = 0.25, 0.5, 1
            elseif settings.useClassColorPowerBar and classColor then
                powerRed, powerGreen, powerBlue = classColor.r, classColor.g, classColor.b
            end
            if not powerRed then
                local color = settings.powerColor
                powerRed, powerGreen, powerBlue = color[1] or 0.25, color[2] or 0.5, color[3] or 1
            end
            local powerBackgroundColor = (isPet and settings.petPowerBgColor) or settings.powerBgColor or backgroundColor
            powerBackgroundTexture:ClearAllPoints()
            powerBackgroundTexture:SetPoint('BOTTOMLEFT', 1, 1)
            powerBackgroundTexture:SetPoint('BOTTOMRIGHT', -1, 1)
            powerBackgroundTexture:SetHeight(powerBarHeight)
            powerBackgroundTexture:SetVertexColor(powerBackgroundColor[1] or 0.1, powerBackgroundColor[2] or 0.1, powerBackgroundColor[3] or 0.1, powerBackgroundColor[4] or 1)
            powerTexture:SetTexture(texture)
            powerTexture:ClearAllPoints()
            powerTexture:SetPoint('BOTTOMLEFT', 1, 1)
            powerTexture:SetSize(innerWidth * 0.6, powerBarHeight)
            powerTexture:SetVertexColor(powerRed, powerGreen, powerBlue, 1)
            powerBackgroundTexture:Show(); powerTexture:Show()
        else
            powerBackgroundTexture:Hide(); powerTexture:Hide()
        end

        local function PlaceText(fontString, show, format, fallback, size, position, offsetX, offsetY, region, color)
            if not show then fontString:Hide(); return end
            BUI.Pixel.ApplyFont(fontString, size or 12, font)
            local text = (format and format ~= '') and format or fallback
            fontString:SetText(Parse and Parse(text) or text)
            fontString:ClearAllPoints()
            local point = position or 'CENTER'
            local insetX = (point:find('LEFT') and 4) or (point:find('RIGHT') and -4) or 0
            local insetY = (point:find('TOP') and -1) or (point:find('BOTTOM') and 1) or 0
            fontString:SetPoint(point, region or self, point, insetX + (offsetX or 0), insetY + (offsetY or 0))
            fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
            fontString:Show()
        end

        local nameColor = { 1, 1, 1, 1 }
        if unitSettings.classColorName and classColor then
            nameColor = { classColor.r, classColor.g, classColor.b, 1 }
        elseif unitKey == 'target' or unitKey == 'boss' then
            nameColor = unitSettings.hostileNameColor or nameColor
        else
            nameColor = unitSettings.friendlyNameColor or nameColor
        end
        local showName = ResolveShow(unitSettings.showName, settings.showName)
        PlaceText(nameFontString, showName, unitSettings.nameFormat, settings.nameFormat or '[name]',
            unitSettings.nameTextSize, unitSettings.namePosition,
            unitSettings.nameOffsetX, unitSettings.nameOffsetY, healthZone, nameColor)

        local showHealth = ResolveShow(unitSettings.showHealthText, settings.showHealthText)
        PlaceText(healthFontString, showHealth, unitSettings.healthFormat, settings.healthFormat,
            unitSettings.healthTextSize, unitSettings.healthPosition,
            unitSettings.healthOffsetX, unitSettings.healthOffsetY, healthZone, { 1, 1, 1, 1 })

        local showPowerText = powerBarHeight > 0 and ResolveShow(unitSettings.showPowerText, settings.showPowerText, false)
        PlaceText(powerFontString, showPowerText, unitSettings.powerFormat, settings.powerFormat,
            unitSettings.powerTextSize, unitSettings.powerPosition,
            unitSettings.powerOffsetX, unitSettings.powerOffsetY, powerBackgroundTexture, { 1, 1, 1, 1 })

        local tagIndex = 0
        for _, entry in ipairs(unitSettings.customTags or {}) do
            if entry.tag and entry.tag ~= '' and entry.enabled ~= false then
                tagIndex = tagIndex + 1
                local fontString = customFontStrings[tagIndex]
                if not fontString then
                    fontString = mock:CreateFontString(nil, 'OVERLAY')
                    customFontStrings[tagIndex] = fontString
                end
                BUI.Pixel.ApplyFont(fontString, entry.fontSize or 12, ResolveUnitFrameMedia('font', entry.font, font))
                fontString:SetDrawLayer(entry.drawLayer or 'OVERLAY', entry.drawSubLevel or 0)
                fontString:ClearAllPoints()
                local point = entry.point or 'CENTER'
                fontString:SetPoint(point, self, point, entry.x or 0, entry.y or 0)
                local color = entry.color
                if color then fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1) else fontString:SetTextColor(1, 1, 1, 1) end
                fontString:SetText(Parse and Parse(entry.tag) or entry.tag)
                fontString:Show()
            end
        end
        for index = tagIndex + 1, #customFontStrings do customFontStrings[index]:Hide() end

        local usedIcons = 0
        local function AuraGrid(icons, count, perRow, size, gap, growX, growY, framePoint, offsetX, offsetY, typed)
            count = math.min(count, 16)
            perRow = math.max(1, math.min(perRow, count))
            local rows = math.ceil(count / perRow)
            local gridWidth = perRow * size + (perRow - 1) * gap
            local gridHeight = rows * size + (rows - 1) * gap
            local selfPoint = MockGrowthAnchor(growX, growY)
            local anchorX = MockPointX(framePoint, width) + (offsetX or 0)
            local anchorY = MockPointY(framePoint, height) - (offsetY or 0)
            local gridLeft = anchorX - MockPointX(selfPoint, gridWidth)
            local gridTop = anchorY - MockPointY(selfPoint, gridHeight)
            for auraIndex = 1, count do
                usedIcons = usedIcons + 1
                local icon = AuraIcon(usedIcons)
                local row = math.floor((auraIndex - 1) / perRow)
                local column = (auraIndex - 1) % perRow
                local x = growX == 'LEFT' and (gridWidth - size - column * (size + gap)) or (column * (size + gap))
                local y = growY == 'UP' and (gridHeight - size - row * (size + gap)) or (row * (size + gap))
                icon.border:SetSize(size + 2, size + 2)
                icon.border:ClearAllPoints()
                icon.border:SetPoint('TOPLEFT', self, 'TOPLEFT', gridLeft + x - 1, -(gridTop + y - 1))
                if typed then
                    local dispelColor = MOCK_DISPEL_COLORS[(auraIndex - 1) % #MOCK_DISPEL_COLORS + 1]
                    icon.border:SetVertexColor(dispelColor[1], dispelColor[2], dispelColor[3], 1)
                elseif typed == false and icons == MOCK_DEBUFF_ICONS then
                    icon.border:SetVertexColor(0.8, 0, 0, 1)
                else
                    icon.border:SetVertexColor(0, 0, 0, 1)
                end
                icon.tex:SetTexture(icons[(auraIndex - 1) % #icons + 1])
                icon.tex:SetSize(size, size)
                icon.tex:ClearAllPoints()
                icon.tex:SetPoint('CENTER', icon.border, 'CENTER', 0, 0)
                icon.border:Show(); icon.tex:Show()
            end
        end
        if showDebuffs then
            AuraGrid(MOCK_DEBUFF_ICONS,
                unitSettings.maxDebuffs,
                unitSettings.debuffsPerRow or unitSettings.maxDebuffs,
                unitSettings.debuffIconSize or unitSettings.auraIconSize,
                unitSettings.debuffSpacing or unitSettings.auraSpacing,
                unitSettings.debuffGrowthX, unitSettings.debuffGrowthY,
                unitSettings.debuffAnchorPoint,
                unitSettings.debuffOffsetX, unitSettings.debuffOffsetY,
                unitSettings.showDebuffType ~= false)
        end
        if showBuffs then
            AuraGrid(MOCK_BUFF_ICONS,
                unitSettings.maxBuffs,
                unitSettings.buffsPerRow or unitSettings.maxBuffs,
                unitSettings.buffIconSize or unitSettings.auraIconSize,
                unitSettings.buffSpacing or unitSettings.auraSpacing,
                unitSettings.buffGrowthX or 'RIGHT', unitSettings.buffGrowthY or 'DOWN',
                unitSettings.buffAnchorPoint or 'BOTTOMLEFT',
                unitSettings.buffOffsetX or 0, unitSettings.buffOffsetY or -4,
                false)
        end
        for index = usedIcons + 1, #auraIcons do
            auraIcons[index].border:Hide()
            auraIcons[index].tex:Hide()
        end

        if settings.raidIconMode ~= 'off' and not unitSettings.hideRaidIcon then
            local size = settings.raidIconSize
            raidIcon:SetSize(size, size)
            raidIcon:ClearAllPoints()
            raidIcon:SetPoint('CENTER', self, settings.raidIconPosition,
                settings.raidIconOffsetX, settings.raidIconOffsetY)
            raidIcon:Show()
        else
            raidIcon:Hide()
        end

        self:Show()
        return width * scale, height * scale
    end

    return mock
end

local function InstallHeader(page, tabIndex, options)
    local PageKit = BUILib.PageKit
    local tab = page:GetTab(tabIndex)
    local width = page.width
    local titleHeight, titleBar = PageKit.PageTitle(tab.pinned, options.title, width, {
        desc = options.desc, enable = options.enable, anchor = options.anchor, button = options.button,
    })
    local pinnedHeight = PageKit.PAD + titleHeight
    local header = { titleBar = titleBar }
    if options.preview then
        local band = PageKit.PreviewBand(tab.pinned, width, Layout.PAGE_PREVIEW_H, pinnedHeight)
        local _, stage = PageKit.PreviewStage(band)
        header.band, header.stage = band, stage
        pinnedHeight = pinnedHeight + Layout.PAGE_PREVIEW_H + PageKit.GAP
    end
    tab:SetPinnedHeight(pinnedHeight)
    pageHeaders[tabIndex] = header
    return header
end

BUI.PageEngine.RegisterPage("unitframes", {
    title = "Unit Frames",
    buttonText = "Unit Frames",
    OnBuild = function(pageFrame)
        local db = BUI.GetDB()
        local UnitFrames = BUI.UnitFrames
        if not UnitFrames._previewButtons then UnitFrames._previewButtons = {} end

        local settings = db.unitFrames
        local page = Layout.Page(pageFrame, Tabs)
        pageFrame._page = page
        _currentPage = page

        for tabIndex, content in pairs(page.tabContents) do
            if not content.frame._buiTabHooked then
                content.frame._buiTabHooked = true
                HookScript(content.frame, "OnShow", function() _currentTabIndex = tabIndex end)
            end
        end
        BUI.Prof.After('Pages.UnitFrames', 0.02, function()
            if _currentTabIndex > 1 then _currentPage:SetTab(_currentTabIndex) end
        end)

        local SYNC_BLOCKLIST = {
            enabled = true, width = true, height = true, position = true, spacing = true, growthDirection = true, targetBorder = true,
            anchorFrame = true, anchorPoint = true, anchorOffsetX = true, anchorOffsetY = true,
            matchAnchorWidth = true, matchAnchorHeight = true, customName = true,
        }
        local function MirrorKeys(source, destination)
            if not source or not destination then return end
            for key in pairs(source) do
                local internal = type(key) == "string" and key:sub(1, 1) == "_"
                if not SYNC_BLOCKLIST[key] and not internal then destination[key] = BUI.Tools.DeepCopy(source[key]) end
            end
        end
        local function CopyAppearance(fromKey, toKey) MirrorKeys(settings[fromKey], settings[toKey]) end

        local syncDirty = {}
        local function IsDriven(unitKey)
            return settings._syncStash ~= nil and settings._syncStash[unitKey] ~= nil
        end
        local function StashAppearance(unitKey)
            settings._syncStash = settings._syncStash or {}
            local snap = {}
            MirrorKeys(settings[unitKey], snap)
            settings._syncStash[unitKey] = snap
        end
        local function RestoreAppearance(unitKey)
            local stash = settings._syncStash and settings._syncStash[unitKey]
            if not stash then return end
            MirrorKeys(stash, settings[unitKey])
            settings._syncStash[unitKey] = nil
        end

        local function SetDriven(unitKey, driven)
            if driven and not IsDriven(unitKey) then
                settings[unitKey] = settings[unitKey] or {}
                StashAppearance(unitKey)
                CopyAppearance("player", unitKey)
                syncDirty[unitKey] = true
            elseif not driven and IsDriven(unitKey) then
                RestoreAppearance(unitKey)
                syncDirty[unitKey] = true
            end
        end

        local function ApplySyncState()
            local on = settings.syncPlayerTarget == true
            SetDriven("target", on)
            SetDriven("pet", on and not settings.excludePetFromSync)
        end

        local function PropagatePlayerAppearance()
            if IsDriven("target") then CopyAppearance("player", "target"); syncDirty.target = true end
            if IsDriven("pet") then CopyAppearance("player", "pet"); syncDirty.pet = true end
        end

        local textPositionItems = BUI.C.ANCHOR_POINT_OPTIONS
        local textPlacementItems = BUI.C.TEXT_PLACEMENT_OPTIONS

        local appearanceTab = page:GetTab(1)
        local appearanceGrid

        wipe(pageHeaders)
        wipe(unitGrids)

        local mark = pageFrame:CreateTexture(nil, 'BACKGROUND', nil, 1)
        mark:SetTexture(BUI.Tools.GetLogo())
        mark:SetSize(520, 520)
        mark:SetPoint('CENTER')
        mark:SetVertexColor(1, 1, 1, 0.06)

        do
            local header = InstallHeader(page, 1, {
                title = 'Unit Frames',
                desc = 'Health, power, names, tags and auras for every unit frame.',
                preview = true,
                enable = { value = settings.enabled, onToggle = function(value)
                    settings.enabled = value
                    appearanceGrid:SyncDim(value)
                    Modals.Confirm({
                        parent = BUI.PageEngine.window.frame,
                        title = value and "Enable Unit Frames" or "Disable Unit Frames",
                        message = "This change requires a UI reload.\n\nReload now?",
                        confirmText = "Reload", cancelText = "Later",
                        onConfirm = function() ReloadUI() end,
                    })
                end },
                button = { text = 'Toggle Test Mode', width = 130, onClick = function()
                    if UnitFrames and UnitFrames.TestMode then
                        UnitFrames.TestMode.Toggle()
                        if UnitFrames.TestMode.IsActive() then
                            Modals.Message({
                                parent = BUI.PageEngine.window.frame,
                                title = "Test Mode Active", message = "Type /buitest to close test mode.", buttonText = "Got it",
                            })
                        end
                    end
                end },
            })
            local mockPlayer = CreateUnitMock(header.stage)
            local mockTarget = CreateUnitMock(header.stage)
            local captionY = -(Layout.PAGE_PREVIEW_H / 2) + 16
            local function Caption(text)
                local fontString = header.stage:CreateFontString(nil, 'OVERLAY')
                fontString:SetFont(BUILib.Font, 10, 'OUTLINE')
                fontString:SetTextColor(0.5, 0.5, 0.55, 1)
                fontString:SetText(text)
                return fontString
            end
            local captionPlayer, captionTarget = Caption('PLAYER'), Caption('TARGET')
            header.Update = function()
                local playerWidth = mockPlayer:Render('player', { maxW = 340, maxH = 128 })
                local targetWidth = mockTarget:Render('target', { maxW = 340, maxH = 128 })
                local playerX, targetX = -(playerWidth / 2 + 18), targetWidth / 2 + 18
                mockPlayer:SetOffset(playerX, 0)
                mockTarget:SetOffset(targetX, 0)
                captionPlayer:ClearAllPoints()
                captionPlayer:SetPoint('CENTER', header.stage, 'CENTER', playerX, captionY)
                captionTarget:ClearAllPoints()
                captionTarget:SetPoint('CENTER', header.stage, 'CENTER', targetX, captionY)
            end
            header.Update()
        end

        InstallHeader(page, 2, {
            title = 'Tag Reference',
            desc = 'Every text tag with sample output. Click a field and press Ctrl+C to copy.',
        })
        InstallHeader(page, 3, {
            title = 'Custom Tags',
            desc = 'Attach extra tag-driven text elements to any unit frame.',
        })

        local UNIT_HEADERS = {
            { index = 4, key = 'player',       title = 'Player Frame',     desc = 'Position, texts, indicators and auras for your own frame.' },
            { index = 5, key = 'target',       title = 'Target Frame',     desc = 'Layout and auras for your current target.' },
            { index = 6, key = 'targettarget', title = 'Target of Target', desc = 'Compact frame showing your target\'s target.' },
            { index = 7, key = 'focus',        title = 'Focus Frame',      desc = 'Layout and auras for your focus unit.' },
            { index = 8, key = 'pet',          title = 'Pet Frame',        desc = 'Layout and colors for your pet.' },
            { index = 9, key = 'boss',         title = 'Boss Frames',      desc = 'Up to five stacked frames for boss encounters.' },
        }
        for _, headerDef in ipairs(UNIT_HEADERS) do
            local header
            local function SyncEye()
                if header and header.titleBar.anchorToggle and UnitFrames and UnitFrames.IsPreviewShown then
                    header.titleBar.anchorToggle:SetValue(UnitFrames.IsPreviewShown(headerDef.key))
                end
            end
            header = InstallHeader(page, headerDef.index, {
                title = headerDef.title, desc = headerDef.desc, preview = true,
                enable = { value = (settings[headerDef.key] and settings[headerDef.key].enabled) ~= false,
                    tooltip = 'Enable or disable this frame',
                    onToggle = function(value)
                        settings[headerDef.key] = settings[headerDef.key] or {}
                        settings[headerDef.key].enabled = value
                        local unitGrid = unitGrids[headerDef.key]
                        if unitGrid then unitGrid:SyncDim(value) end
                        RefreshFrames()
                    end },
                anchor = { value = UnitFrames and UnitFrames.IsPreviewShown and UnitFrames.IsPreviewShown(headerDef.key) or false,
                    tooltip = 'Show a movable in-world preview of this frame',
                    onToggle = function()
                        if UnitFrames and UnitFrames.TogglePreview then UnitFrames.TogglePreview(headerDef.key) end
                        SyncEye()
                    end },
            })
            if UnitFrames then
                UnitFrames._previewButtons[headerDef.key] = { SetText = function(_, text)
                    if header.titleBar.anchorToggle then
                        header.titleBar.anchorToggle:SetValue(text == 'Hide Preview')
                    end
                end }
            end
            if headerDef.key == 'boss' then
                local mock1 = CreateUnitMock(header.stage)
                local mock2 = CreateUnitMock(header.stage)
                header.Update = function()
                    local bossSettings = settings.boss
                    local _, mockHeight = mock1:Render('boss', { maxW = 620, maxH = 72 })
                    mock2:Render('boss', { maxW = 620, maxH = 72 })
                    local offset = (mockHeight + bossSettings.spacing * mock1:GetScale()) / 2
                    local top = bossSettings.growthDirection == 'DOWN' and offset or -offset
                    mock1:SetOffset(0, top)
                    mock2:SetOffset(0, -top)
                end
            else
                local mock = CreateUnitMock(header.stage)
                header.Update = function()
                    mock:Render(headerDef.key, { maxW = 620, maxH = 150 })
                end
            end
            local unitTab = page:GetTab(headerDef.index)
            HookScript(unitTab.frame, 'OnShow', function()
                local unitSettings = settings[headerDef.key]
                header.titleBar.enableToggle:SetValue((unitSettings and unitSettings.enabled) ~= false)
                SyncEye()
                header.Update()
            end)
            header.Update()
        end

        do
            local PageKit = BUILib.PageKit
            local appearanceGrids = {}
            local grid
            local function Section(title)
                if grid then grid:Flush() end
                Layout.Section(appearanceTab, title)
                grid = PageKit.RowGrid(appearanceTab)
                appearanceGrids[#appearanceGrids + 1] = grid
            end
            local function AddRow(config) return grid:Add(config) end

            appearanceGrid = {
                SyncDim = function(_, enabled)
                    for index = 1, #appearanceGrids do appearanceGrids[index]:SyncDim(enabled) end
                end,
            }

            Section('General')

            AddRow({
                title = 'Bar Texture',
                description = 'Statusbar fill for every frame.',
                controlWidth = 170,
                control = function(row)
                    return Controls.Dropdown(row, nil, BUI.BuildTextureDropdownItems("GLOBAL"), settings.texture, function(value) settings.texture = value; RefreshFrames() end, nil, 160)
                end,
            })

            AddRow({
                title = 'Font',
                description = 'Font for names, health and power text.',
                controlWidth = 170,
                control = function(row)
                    return Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems("GLOBAL"), settings.font, function(value) settings.font = value; RefreshFrames() end, nil, 160)
                end,
            })

            AddRow({
                title = 'Show Tooltips',
                description = 'Unit tooltip on mouseover.',
                checked = settings.showTooltips ~= false,
                callback = function(value) settings.showTooltips = value end,
            })

            AddRow({
                title = 'Click to Target',
                description = 'Clicking a frame targets its unit.',
                checked = settings.clickToTarget ~= false,
                callback = function(value) settings.clickToTarget = value; if BUI.UnitFrames and BUI.UnitFrames.ApplyClickToTarget then BUI.UnitFrames.ApplyClickToTarget() end end,
            })

            AddRow({
                title = 'Decimal Abbreviations',
                description = 'Abbreviate numbers with one decimal (7.5K).',
                checked = db.general.showDecimalAbbreviations == true,
                callback = function(value)
                    db.general.showDecimalAbbreviations = value
                    if BUI.UnitFrames then
                        if BUI.UnitFrames.RefreshAbbreviationSetting then BUI.UnitFrames.RefreshAbbreviationSetting() end
                        if BUI.UnitFrames.InvalidateTagCache then BUI.UnitFrames.InvalidateTagCache() end
                    end
                    RefreshFrames()
                end,
            })

            Section('Synchronization')

            AddRow({
                title = 'Sync Player to Target/Pet',
                description = 'Target and Pet copy the Player frame look.',
                checked = settings.syncPlayerTarget == true,
                callback = function(value)
                    settings.syncPlayerTarget = value
                    ApplySyncState()
                    RefreshFrames()
                end,
            })

            AddRow({
                title = 'Exclude Pet from Sync',
                description = 'Keep the Pet frame independent.',
                checked = settings.excludePetFromSync == true,
                callback = function(value)
                    settings.excludePetFromSync = value
                    ApplySyncState()
                    RefreshFrames()
                end,
            })

            Section('Health Bar')

            AddRow({
                title = 'Colors',
                description = 'Health, background and border.',
                plain = true,
                accessoryWidth = 92,
                accessories = function(row)
                    local healthColor = settings.healthColor
                    local healthSwatch = Controls.ColorSwatch(row, { r=healthColor[1], g=healthColor[2], b=healthColor[3], a=healthColor[4], callback=function(red, green, blue, alpha) settings.healthColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Health Bar' })
                    local bgColor = settings.bgColor
                    local bgSwatch = Controls.ColorSwatch(row, { r=bgColor[1], g=bgColor[2], b=bgColor[3], a=bgColor[4], callback=function(red, green, blue, alpha) settings.bgColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Background' })
                    local borderColor = settings.borderColor
                    local borderSwatch = Controls.ColorSwatch(row, { r=borderColor[1], g=borderColor[2], b=borderColor[3], a=borderColor[4], callback=function(red, green, blue, alpha) settings.borderColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Border' })
                    return { healthSwatch, bgSwatch, borderSwatch }
                end,
            })

            AddRow({
                title = 'Class Color Health',
                description = 'Fill health bars with class color.',
                checked = settings.classColorHealth,
                callback = function(value) settings.classColorHealth = value; RefreshFrames() end,
            })

            AddRow({
                title = 'Transparent Health',
                description = 'See-through health fill.',
                checked = settings.transparentHealth,
                callback = function(value) settings.transparentHealth = value; RefreshFrames() end,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, { title = 'TRANSPARENT HEALTH', tooltip = 'Fill opacity', options = {
                        { kind = 'slider', label = 'Fill Opacity %', min = 0, max = 100, step = 5,
                          get = function() return math.floor(settings.healthBarAlpha * 100) end,
                          set = function(value) settings.healthBarAlpha = value / 100; RefreshFrames() end },
                    } }) }
                end,
            })

            local ABSORB_TEXTURE_ITEMS = {
                { value = 'Solid',    text = 'Solid'            },
                { value = 'Stripes',  text = 'Diagonal Stripes' },
            }
            local ABSORB_DIRECTION_ITEMS = {
                { value = 'right', text = 'Fill Empty Area'     },
                { value = 'left',  text = 'Reverse Into Health' },
                { value = 'edge',  text = 'From Bar Edge'       },
            }

            local function AbsorbPreviewButton(parent)
                local button
                local function previewLabel()
                    return (UnitFrames.IsPreviewShown and UnitFrames.IsPreviewShown('player')) and 'Hide Preview' or 'Show Preview'
                end
                button = Controls.GhostButton(parent, previewLabel(), 120, function()
                    if UnitFrames and UnitFrames.TogglePreview then
                        UnitFrames.TogglePreview('player')
                        button.frame:SetText(previewLabel())
                    end
                end)
                return button
            end

            Section('Absorbs')

            AddRow({
                spanFull = true,
                title = 'Damage Absorb',
                description = 'Absorb shield overlay on the health bar.',
                checked = settings.shieldEnabled ~= false,
                callback = function(value) settings.shieldEnabled = value; RefreshFrames() end,
                accessoryWidth = 224,
                accessories = function(row)
                    local cog = PageKit.SettingsIcon(row, { title = 'DAMAGE ABSORB', tooltip = 'Texture & direction', options = {
                        { kind = 'dropdown', label = 'Texture', items = ABSORB_TEXTURE_ITEMS,
                          get = function() return settings.shieldOverlay end,
                          set = function(value) settings.shieldOverlay = value; RefreshFrames() end },
                        { kind = 'dropdown', label = 'Shield Direction', items = ABSORB_DIRECTION_ITEMS,
                          get = function() return settings.shieldDirection end,
                          set = function(value) settings.shieldDirection = value; RefreshFrames() end },
                    } })
                    local shieldColor = settings.shieldColor
                    local swatch = Controls.ColorSwatch(row, { r=shieldColor[1], g=shieldColor[2], b=shieldColor[3], a=shieldColor[4], callback=function(red, green, blue, alpha) settings.shieldColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Fill color' })
                    return { cog, swatch, AbsorbPreviewButton(row) }
                end,
            })

            AddRow({
                spanFull = true,
                title = 'Heal Absorb',
                description = 'Heal absorb overlay on the health bar.',
                checked = settings.healAbsorbEnabled ~= false,
                callback = function(value) settings.healAbsorbEnabled = value; RefreshFrames() end,
                accessoryWidth = 224,
                accessories = function(row)
                    local cog = PageKit.SettingsIcon(row, { title = 'HEAL ABSORB', tooltip = 'Texture & direction', options = {
                        { kind = 'dropdown', label = 'Texture', items = ABSORB_TEXTURE_ITEMS,
                          get = function() return settings.healAbsorbOverlay end,
                          set = function(value) settings.healAbsorbOverlay = value; RefreshFrames() end },
                        { kind = 'dropdown', label = 'Shield Direction', items = ABSORB_DIRECTION_ITEMS,
                          get = function() return settings.healAbsorbDirection end,
                          set = function(value) settings.healAbsorbDirection = value; RefreshFrames() end },
                    } })
                    local healAbsorbColor = settings.healAbsorbColor
                    local swatch = Controls.ColorSwatch(row, { r=healAbsorbColor[1], g=healAbsorbColor[2], b=healAbsorbColor[3], a=healAbsorbColor[4], callback=function(red, green, blue, alpha) settings.healAbsorbColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Fill color' })
                    return { cog, swatch, AbsorbPreviewButton(row) }
                end,
            })

            Section('Power Bar')

            AddRow({
                title = 'Colors',
                description = 'Power fill and background.',
                plain = true,
                accessoryWidth = 64,
                accessories = function(row)
                    local powerColor = settings.powerColor
                    local powerSwatch = Controls.ColorSwatch(row, { r=powerColor[1], g=powerColor[2], b=powerColor[3], a=powerColor[4], callback=function(red, green, blue, alpha) settings.powerColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Power Bar' })
                    local powerBackgroundColor = settings.powerBgColor or settings.bgColor
                    local powerBgSwatch = Controls.ColorSwatch(row, { r=powerBackgroundColor[1], g=powerBackgroundColor[2], b=powerBackgroundColor[3], a=powerBackgroundColor[4], callback=function(red, green, blue, alpha) settings.powerBgColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Background' })
                    return { powerSwatch, powerBgSwatch }
                end,
            })

            AddRow({
                title = 'Color by Resource Type',
                description = 'Mana blue, energy yellow, and so on.',
                checked = settings.classColorPower,
                callback = function(value) settings.classColorPower = value; RefreshFrames() end,
            })

            AddRow({
                title = 'Color by Class/Reaction',
                description = 'Power bar takes the class color.',
                checked = settings.useClassColorPowerBar,
                callback = function(value) settings.useClassColorPowerBar = value; RefreshFrames() end,
            })

            Section('Dispel')

            local UnitFramesModule = BUI.UnitFrames
            local playerSettings = settings.player

            local function RefreshDispel()
                RefreshFrames()
                if UnitFramesModule and UnitFramesModule.RefreshDispelPreview then UnitFramesModule.RefreshDispelPreview() end
            end

            local DISPEL_MODE_ITEMS = {
                { value = 'off',    text = 'Off'          },
                { value = 'border', text = 'Frame Border' },
                { value = 'bar',    text = 'Health Bar'   },
            }
            local DISPEL_SOURCE_ITEMS = {
                { value = 'mine', text = 'Dispellable By Me' },
                { value = 'all',  text = 'All Dispel Types'  },
            }
            local function dispelMode()
                if playerSettings.debuffHighlightBorder then return 'border' end
                if playerSettings.debuffHighlightBar then return 'bar' end
                return 'off'
            end

            AddRow({
                spanFull = true,
                title = 'Dispel Highlight',
                description = 'Color your player frame when a dispellable debuff lands.',
                controlWidth = 160,
                control = function(row)
                    return Controls.Dropdown(row, nil, DISPEL_MODE_ITEMS, dispelMode(), function(value)
                        playerSettings.debuffHighlightBorder = (value == 'border')
                        playerSettings.debuffHighlightBar = (value == 'bar')
                        RefreshDispel()
                    end, nil, 150)
                end,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, { title = 'DISPEL HIGHLIGHT', tooltip = 'Source & strength', options = {
                        { kind = 'dropdown', label = 'Show', items = DISPEL_SOURCE_ITEMS,
                          get = function() return playerSettings.debuffHighlightClassFilter ~= false and 'mine' or 'all' end,
                          set = function(value) playerSettings.debuffHighlightClassFilter = (value == 'mine'); RefreshDispel() end },
                        { kind = 'slider', label = 'Bar Tint Opacity %', min = 0, max = 100, step = 5,
                          get = function() return settings.dispelOpacity end,
                          set = function(value) settings.dispelOpacity = value; RefreshDispel() end },
                    } }) }
                end,
            })

            AddRow({
                title = 'Type Icons',
                description = 'Row of debuff type icons above your character.',
                checked = playerSettings.debuffHighlightBadge ~= false,
                callback = function(value) playerSettings.debuffHighlightBadge = value; RefreshDispel() end,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, { title = 'TYPE ICONS', tooltip = 'Size & position', options = {
                        { kind = 'slider', label = 'Size', min = 10, max = 48,
                          get = function() return playerSettings.debuffHighlightBadgeSize end,
                          set = function(value) playerSettings.debuffHighlightBadgeSize = value; RefreshDispel() end },
                        { kind = 'slider', label = 'X Offset', min = -600, max = 600,
                          get = function() return playerSettings.debuffHighlightBadgeOffsetX end,
                          set = function(value) playerSettings.debuffHighlightBadgeOffsetX = value; RefreshDispel() end },
                        { kind = 'slider', label = 'Y Offset', min = -400, max = 400,
                          get = function() return playerSettings.debuffHighlightBadgeOffsetY end,
                          set = function(value) playerSettings.debuffHighlightBadgeOffsetY = value; RefreshDispel() end },
                    } }) }
                end,
            })

            AddRow({
                title = 'Cleanse Callouts',
                description = 'Show FD / TURT / SF prompts when you can clear it yourself.',
                checked = playerSettings.debuffHighlightTypeText == true,
                callback = function(value) playerSettings.debuffHighlightTypeText = value; RefreshDispel() end,
            })

            AddRow({
                spanFull = true,
                title = 'Recolor Type Icons',
                description = 'Tint the Blizzard debuff icons to match your colors.',
                checked = settings.dispelRecolor == true,
                callback = function(value) settings.dispelRecolor = value; RefreshDispel() end,
            })

            AddRow({
                spanFull = true,
                title = 'Blend Multiple Types',
                description = 'With two debuffs up, mix both colors instead of showing the higher priority one.',
                checked = settings.dispelBlend == true,
                callback = function(value) settings.dispelBlend = value; RefreshDispel() end,
            })

            AddRow({
                title = 'Type Colors',
                description = 'Shared with the party and raid frames. Click a color to preview it live.',
                plain = true,
                accessoryWidth = 180,
                accessories = function(row)
                    local TYPE_COLOR_DEFS = {
                        { type = 'Bleed',   def = { 1.00, 0.20, 0.20, 1 } },
                        { type = 'Poison',  def = { 0.00, 0.60, 0.00, 1 } },
                        { type = 'Disease', def = { 0.60, 0.40, 0.00, 1 } },
                        { type = 'Curse',   def = { 0.60, 0.00, 1.00, 1 } },
                        { type = 'Magic',   def = { 0.20, 0.60, 1.00, 1 } },
                    }
                    local colorStore = BUI.Colors.GetStore()
                    local swatches = {}
                    local out = { Controls.Icon(row, {
                        texture = BUILib.GetLibMedia('reset'), tooltip = 'Reset to default',
                        onClick = function()
                            BUI.Colors.ResetGroup('Dispel Types')
                            for storeKey, swatch in pairs(swatches) do
                                local stored = colorStore[storeKey]
                                swatch:SetColor(stored.r, stored.g, stored.b, stored.a)
                            end
                            RefreshDispel()
                            BUI.ApplyColors()
                        end,
                    }) }
                    for _, typeDef in ipairs(TYPE_COLOR_DEFS) do
                        local storeKey = BUI.AuraEngine.DispelColorKey(typeDef.type)
                        local stored = colorStore[storeKey]
                        local color = stored and { stored.r, stored.g, stored.b, stored.a } or typeDef.def
                        local swatch = Controls.ColorSwatch(row, {
                            r = color[1], g = color[2], b = color[3], a = color[4] or 1,
                            callback = function(red, green, blue, alpha, cancelled, phase)
                                if stored then
                                    stored.r, stored.g, stored.b, stored.a = red, green, blue, alpha
                                end
                                if UnitFramesModule and UnitFramesModule.PinDispelPreview then
                                    if phase == 'commit' or phase == 'cancel' then
                                        UnitFramesModule.UnpinDispelPreview()
                                    else
                                        UnitFramesModule.PinDispelPreview(typeDef.type)
                                    end
                                end
                                RefreshDispel()
                            end,
                            tooltip = typeDef.type,
                        })
                        if stored then swatches[storeKey] = swatch end
                        out[#out + 1] = swatch
                    end
                    return out
                end,
            })

            Section('Default Tags')

            local nameTagControl, healthTagControl, powerTagControl

            AddRow({
                spanFull = true,
                title = 'Name Tag',
                description = 'Default name text for every frame.',
                plain = true,
                extra = function(row)
                    nameTagControl = Controls.Tags(row, nil, settings.nameFormat or "[name]", function(value) settings.nameFormat = value; RefreshFrames() end, 500, nil, TagSuggestions, "[name]")
                    return nameTagControl
                end,
            })

            AddRow({
                spanFull = true,
                title = 'Health Tag',
                description = 'Default health text for every frame.',
                plain = true,
                extra = function(row)
                    healthTagControl = Controls.Tags(row, nil, settings.healthFormat, function(value) settings.healthFormat = value; RefreshFrames() end, 500, nil, TagSuggestions, "[hp:short] • [perhp]%")
                    return healthTagControl
                end,
            })

            AddRow({
                spanFull = true,
                title = 'Power Tag',
                description = 'Default power text for every frame.',
                plain = true,
                extra = function(row)
                    powerTagControl = Controls.Tags(row, nil, settings.powerFormat, function(value) settings.powerFormat = value; RefreshFrames() end, 500, nil, TagSuggestions, "[perpp]%")
                    return powerTagControl
                end,
            })

            AddRow({
                spanFull = true,
                title = 'Reset Tags',
                description = 'Restore the default name, health and power tags.',
                plain = true,
                accessoryWidth = 130,
                accessories = function(row)
                    return { Controls.GhostButton(row, 'Reset', 110, function()
                        settings.nameFormat, settings.healthFormat, settings.powerFormat = "[name]", "[hp:short] • [perhp]%", "[perpp]%"
                        nameTagControl:SetValue("[name]"); healthTagControl:SetValue("[hp:short] • [perhp]%"); powerTagControl:SetValue("[perpp]%")
                        RefreshFrames()
                    end) }
                end,
            })

            Section('Indicators')

            AddRow({
                title = 'Raid Icon',
                description = 'Raid target marker on each frame.',
                checked = settings.raidIconMode ~= "off",
                callback = function(value) settings.raidIconMode = value and "icon" or "off"; RefreshFrames() end,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, { title = 'RAID ICON', tooltip = 'Position & size', options = {
                        { kind = 'dropdown', label = 'Position', items = textPositionItems, controlWidth = 120,
                          get = function() return settings.raidIconPosition end,
                          set = function(value) settings.raidIconPosition = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Size', min = 8, max = 50,
                          get = function() return settings.raidIconSize end,
                          set = function(value) settings.raidIconSize = value; RefreshFrames() end },
                        { kind = 'slider', label = 'X Offset', min = -50, max = 50,
                          get = function() return settings.raidIconOffsetX end,
                          set = function(value) settings.raidIconOffsetX = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Y Offset', min = -50, max = 50,
                          get = function() return settings.raidIconOffsetY end,
                          set = function(value) settings.raidIconOffsetY = value; RefreshFrames() end },
                    } }) }
                end,
            })

            AddRow({
                title = 'Party Leader Icon',
                description = 'Leader and assist crown on frames.',
                checked = settings.leaderIconEnabled ~= false,
                callback = function(value) settings.leaderIconEnabled = value; RefreshFrames() end,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, { title = 'LEADER ICON', tooltip = 'Position & size', options = {
                        { kind = 'dropdown', label = 'Position', items = textPositionItems, controlWidth = 120,
                          get = function() return settings.leaderIconPosition end,
                          set = function(value) settings.leaderIconPosition = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Size', min = 8, max = 32,
                          get = function() return settings.leaderIconSize end,
                          set = function(value) settings.leaderIconSize = value; RefreshFrames() end },
                        { kind = 'slider', label = 'X Offset', min = -50, max = 50,
                          get = function() return settings.leaderIconOffsetX end,
                          set = function(value) settings.leaderIconOffsetX = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Y Offset', min = -50, max = 50,
                          get = function() return settings.leaderIconOffsetY end,
                          set = function(value) settings.leaderIconOffsetY = value; RefreshFrames() end },
                    } }) }
                end,
            })

            grid:Flush()
        end
        appearanceGrid:SyncDim(settings.enabled)

        local referenceTab = page:GetTab(2)

        local ALL_TAGS = {
            { cat = "Names", tag = "[name]", desc = "Full name", example = "Bluetempest" },
            { cat = "Names", tag = "[name:short]", desc = "10 chars", example = "Bluetempes" },
            { cat = "Names", tag = "[name:short5]", desc = "5 chars", example = "Bluet" },
            { cat = "Names", tag = "[name:target>]", desc = "Name > Target", example = "Blue.. > Ragn.." },
            { cat = "Names", tag = "[name5:target5>]", desc = "Both 5 chars", example = "Bluet > Ragni" },
            { cat = "Names", tag = "[name8:target>]", desc = "8 chars > full", example = "Bluetemp > Ragnaros" },
            { cat = "Health", tag = "[hp]", desc = "Health", example = "75000" },
            { cat = "Health", tag = "[hp:short]", desc = "Abbreviated", example = "75K" },
            { cat = "Health", tag = "[maxhp]", desc = "Max", example = "100000" },
            { cat = "Health", tag = "[maxhp:short]", desc = "Max short", example = "100K" },
            { cat = "Health", tag = "[perhp]", desc = "Percent", example = "75" },
            { cat = "Power", tag = "[pp]", desc = "Power", example = "9000" },
            { cat = "Power", tag = "[pp:short]", desc = "Abbreviated", example = "9K" },
            { cat = "Power", tag = "[maxpp]", desc = "Max", example = "10000" },
            { cat = "Power", tag = "[maxpp:short]", desc = "Max short", example = "10K" },
            { cat = "Power", tag = "[perpp]", desc = "Percent", example = "60" },
            { cat = "Power", tag = "[powertype]", desc = "Type", example = "Mana" },
            { cat = "Mana", tag = "[mana]", desc = "Mana", example = "8000" },
            { cat = "Mana", tag = "[mana:short]", desc = "Abbreviated", example = "8K" },
            { cat = "Mana", tag = "[maxmana]", desc = "Max", example = "10000" },
            { cat = "Mana", tag = "[permana]", desc = "Percent", example = "80" },
            { cat = "Player", tag = "[class]", desc = "Class upper", example = "HUNTER" },
            { cat = "Player", tag = "[classname]", desc = "Class name", example = "Hunter" },
            { cat = "Player", tag = "[race]", desc = "Race", example = "Night Elf" },
            { cat = "Player", tag = "[level]", desc = "Level", example = "80" },
            { cat = "Player", tag = "[spec]", desc = "Specialization", example = "Marksmanship" },
            { cat = "Player", tag = "[itemlevel]", desc = "Item level", example = "639" },
            { cat = "Player", tag = "[title]", desc = "Player title", example = "the Exalted" },
            { cat = "Player", tag = "[role]", desc = "Role icon", example = "(icon)" },
            { cat = "Player", tag = "[role:text]", desc = "Role text", example = "DPS" },
            { cat = "Creature", tag = "[creature]", desc = "Pet family/type", example = "Cat" },
            { cat = "Creature", tag = "[creaturefamily]", desc = "Pet family", example = "Cat" },
            { cat = "Creature", tag = "[creaturetype]", desc = "Creature type", example = "Beast" },
            { cat = "Creature", tag = "[classification]", desc = "Classification", example = "Boss" },
            { cat = "Creature", tag = "[difficulty]", desc = "Instance difficulty", example = "Mythic" },
            { cat = "Status", tag = "[status]", desc = "Dead/Ghost/Offline", example = "Dead" },
            { cat = "Status", tag = "[dead]", desc = "Dead", example = "Dead" },
            { cat = "Status", tag = "[offline]", desc = "Disconnected", example = "Offline" },
            { cat = "Status", tag = "[afk]", desc = "Away", example = "AFK" },
            { cat = "Status", tag = "[combat]", desc = "In combat", example = "!" },
            { cat = "Status", tag = "[resting]", desc = "Resting", example = "zzz" },
            { cat = "Live", tag = "[combattime]", desc = "Combat timer", example = "[01:23]" },
            { cat = "Live", tag = "[threat]", desc = "Threat on target", example = "42%" },
            { cat = "Live", tag = "[range]", desc = "Distance to unit", example = "25-30" },
            { cat = "Other", tag = "[server]", desc = "Realm", example = "Kazzak" },
            { cat = "Other", tag = "[absorbs]", desc = "Absorb shield", example = "5K" },
            { cat = "Other", tag = "[hpabsorb]", desc = "HP + absorb raw", example = "492000" },
            { cat = "Other", tag = "[hpabsorb:short]", desc = "HP + absorb short", example = "492K" },
            { cat = "Other", tag = "[target]", desc = "Target name", example = "Ragnaros" },
            { cat = "Other", tag = "[group]", desc = "Raid group", example = "3" },
        }

        local function MakeTagBox(parent, text)
            local tagBox = Controls.TextBox(parent, nil, text, function() end, nil, 100)
            local editBox = tagBox.editbox
            SetScript(editBox, "OnTextChanged", function(self, userInput)
                if userInput then self:SetText(text) end
            end)
            SetScript(editBox, "OnEditFocusGained", function(self) self:HighlightText() end)
            return tagBox
        end

        local tagCategories = {}
        for _, tagInfo in ipairs(ALL_TAGS) do
            if not tagCategories[tagInfo.cat] then tagCategories[tagInfo.cat] = {} end
            tagCategories[tagInfo.cat][#tagCategories[tagInfo.cat] + 1] = tagInfo
        end

        do
            local PageKit = BUILib.PageKit
            for _, categoryName in ipairs({"Names", "Health", "Power", "Mana", "Player", "Creature", "Status", "Live", "Other"}) do
                local tags = tagCategories[categoryName]
                if tags then
                    Layout.Section(referenceTab, categoryName)
                    local referenceGrid = PageKit.RowGrid(referenceTab)
                    for _, tagInfo in ipairs(tags) do
                        local tag = tagInfo.tag
                        referenceGrid:Add({
                            title = tagInfo.desc,
                            description = (tagInfo.example and tagInfo.example ~= '') and ('|cff777777' .. tagInfo.example .. '|r') or nil,
                            controlWidth = 120,
                            control = function(row) return MakeTagBox(row, tag) end,
                        })
                    end
                    referenceGrid:Flush()
                end
            end
        end

        local function BuildUnitSettings(tab, unitKey)
            local unitSettings = settings[unitKey]
            if not unitSettings then settings[unitKey] = {}; unitSettings = settings[unitKey] end

            local BaseRefresh, BaseAuras = RefreshFrames, RefreshAurasOnly
            local RefreshFrames, RefreshAurasOnly = BaseRefresh, BaseAuras
            if unitKey == "player" then
                RefreshFrames    = function() PropagatePlayerAppearance(); BaseRefresh() end
                RefreshAurasOnly = function() PropagatePlayerAppearance(); BaseAuras() end
            end

            if IsDriven(unitKey) then
                Layout.Text(tab, {text = "|cffe5a52bSynced from the Player frame.|r Edits here are overwritten when you change the Player. Turn off \"Sync Player to Target/Pet\" on the Appearance tab to edit this frame independently."})
            end

            local PageKit = BUILib.PageKit

            local grids = {}
            local grid
            local function Section(title)
                if grid then grid:Flush() end
                Layout.Section(tab, title)
                grid = PageKit.RowGrid(tab)
                grids[#grids + 1] = grid
            end
            local function AddRow(config) return grid:Add(config) end

            local unitGrid = {
                SyncDim = function(_, enabled)
                    for index = 1, #grids do grids[index]:SyncDim(enabled) end
                end,
                Section = Section,
                AddRow = AddRow,
                Flush = function() if grid then grid:Flush() end end,
            }
            unitGrids[unitKey] = unitGrid

            Section('Layout')

            local function SizeIcon(row)
                return PageKit.SizeIcon(row, { title = 'FRAME SIZE', options = {
                    { kind = 'slider', label = 'Width', min = 50, max = 1500,
                      get = function() return unitSettings.width end,
                      set = function(value) unitSettings.width = value; RefreshFrames() end },
                    { kind = 'slider', label = 'Height', min = 1, max = 500,
                      get = function() return unitSettings.height end,
                      set = function(value) unitSettings.height = value; RefreshFrames() end },
                } })
            end

            if unitKey == "focus" or unitKey == "pet" or unitKey == "targettarget"
               or unitKey == "player" or unitKey == "target" then
                local selfFrame = UnitFrames[unitKey]
                local suggestions = BUI.AnchorFramesExcept("BUI_" .. unitKey:sub(1, 1):upper() .. unitKey:sub(2) .. "Frame")
                if unitKey == "targettarget" then
                    suggestions = {
                        { tag = "BUI_TargetFrame", desc = "Target Frame" },
                        { tag = "BUI_PlayerFrame", desc = "Player Frame" },
                        { tag = "BUI_FocusFrame", desc = "Focus Frame" },
                    }
                end

                if selfFrame and BUI.Anchor and BUI.Anchor.WouldCycle then
                    local pruned = {}
                    for _, suggestion in ipairs(suggestions) do
                        if not BUI.Anchor.WouldCycle(selfFrame, BUI.ResolveAnchorFrame(suggestion.tag)) then
                            pruned[#pruned + 1] = suggestion
                        end
                    end
                    suggestions = pruned
                end

                local defaultOffsetX = unitKey == "targettarget" and 5 or 0
                local positionProxy = setmetatable({}, {
                    __index = function(_, key)
                        if key == "posX" then return unitSettings.position.x end
                        if key == "posY" then return unitSettings.position.y end
                        if key == "anchorPoint" then return unitSettings.anchorPoint end
                        if key == "anchorOffsetX" then return unitSettings.anchorOffsetX or defaultOffsetX end
                        return unitSettings[key]
                    end,
                    __newindex = function(_, key, value)
                        if key == "posX" then
                            unitSettings.position = unitSettings.position or {}
                            unitSettings.position.x, unitSettings.position.point, unitSettings.position.relPoint = value, "CENTER", "CENTER"
                        elseif key == "posY" then
                            unitSettings.position = unitSettings.position or {}
                            unitSettings.position.y, unitSettings.position.point, unitSettings.position.relPoint = value, "CENTER", "CENTER"
                        elseif key == "anchorFrame" then
                            if value and value ~= "" and selfFrame and BUI.Anchor.WouldCycle(selfFrame, BUI.ResolveAnchorFrame(value)) then
                                BUI.Print("|cffff5555That frame already anchors to " .. unitKey .. ", would loop.|r")
                                return
                            end
                            unitSettings.anchorFrame = value
                        else
                            unitSettings[key] = value
                        end
                    end,
                })

                AddRow({
                    title = 'Position & Size',
                    description = 'Placement, anchoring, width and height.',
                    plain = true,
                    accessoryWidth = 64,
                    accessories = function(row)
                        local mover = BUI.AlertMover(row, positionProxy, RefreshFrames, {
                            noCenter = true,
                            frames = suggestions,
                            xyRange = { x = 4000, y = 3000 },
                            matchWidth = {
                                get = function() return unitSettings.matchAnchorWidth == true end,
                                set = function(value) unitSettings.matchAnchorWidth = value; BUI.Prof.After('Pages.UnitFrames', 0.1, RefreshFrames) end,
                            },
                            matchHeight = {
                                get = function() return unitSettings.matchAnchorHeight == true end,
                                set = function(value) unitSettings.matchAnchorHeight = value; BUI.Prof.After('Pages.UnitFrames', 0.1, RefreshFrames) end,
                            },
                        })
                        return { mover, SizeIcon(row) }
                    end,
                })
            else
                AddRow({
                    title = 'Position & Size',
                    description = 'Placement, width and height.',
                    plain = true,
                    accessoryWidth = 64,
                    accessories = function(row)
                        local mover = PageKit.PositionIcon(row, { title = 'POSITION', options = {
                            { kind = 'slider', label = 'X Position', min = -4000, max = 4000,
                              get = function() return unitSettings.position.x end,
                              set = function(value)
                                  unitSettings.position = unitSettings.position or {}
                                  unitSettings.position.x, unitSettings.position.point, unitSettings.position.relPoint = value, "CENTER", "CENTER"
                                  RefreshFrames()
                              end },
                            { kind = 'slider', label = 'Y Position', min = -3000, max = 3000,
                              get = function() return unitSettings.position.y end,
                              set = function(value)
                                  unitSettings.position = unitSettings.position or {}
                                  unitSettings.position.y, unitSettings.position.point, unitSettings.position.relPoint = value, "CENTER", "CENTER"
                                  RefreshFrames()
                              end },
                        } })
                        return { mover, SizeIcon(row) }
                    end,
                })
            end

            if UnitFrames and UnitFrames.RegisterPositionCallback then
                UnitFrames.RegisterPositionCallback(unitKey, function() RefreshPageMocks() end)
            end

            if not tab._buiUnitPosHook then
                tab._buiUnitPosHook = true
                HookScript(tab.frame, "OnHide", function() if UnitFrames and UnitFrames.UnregisterPositionCallback then UnitFrames.UnregisterPositionCallback(unitKey) end end)
            end

            Section('General')

            AddRow({
                title = 'Hide Raid Icon',
                description = 'No raid marker on this frame.',
                checked = unitSettings.hideRaidIcon == true,
                callback = function(value) unitSettings.hideRaidIcon = value; RefreshFrames() end,
            })

            AddRow({
                title = 'Hide Level Text',
                description = 'No level text on this frame.',
                checked = unitSettings.hideLevel == true,
                callback = function(value) unitSettings.hideLevel = value; RefreshFrames() end,
            })

            if unitKey == "boss" then
                AddRow({
                    title = 'Target Border',
                    description = 'Highlight the boss frame you have targeted.',
                    checked = unitSettings.targetBorder.enabled ~= false,
                    callback = function(value) unitSettings.targetBorder.enabled = value; RefreshFrames() end,
                    accessoryWidth = 80,
                    accessories = function(row)
                        local targetBorder = unitSettings.targetBorder
                        local thicknessCog = PageKit.SettingsIcon(row, { title = 'TARGET BORDER', tooltip = 'Thickness', options = {
                            { kind = 'slider', label = 'Thickness', min = 1, max = 4,
                              get = function() return targetBorder.thickness or 2 end,
                              set = function(value) targetBorder.thickness = value end, apply = RefreshFrames },
                        } })
                        local borderColor = targetBorder.color or { 1, 1, 1, 1 }
                        local swatch = Controls.ColorSwatch(row, { r=borderColor[1], g=borderColor[2], b=borderColor[3], a=borderColor[4], tooltip='Target border color', callback=function(red, green, blue, alpha) targetBorder.color = {red, green, blue, alpha}; RefreshFrames() end })
                        return { thicknessCog, swatch }
                    end,
                })
            end

            if unitKey == "player" then
                AddRow({
                    title = 'Power Prediction',
                    description = 'Preview the power cost of your cast.',
                    checked = unitSettings.powerPrediction == true,
                    callback = function(value) unitSettings.powerPrediction = value; RefreshFrames() end,
                    accessoryWidth = 36,
                    accessories = function(row)
                        local predictionColor = unitSettings.powerPredictionColor
                        return { Controls.ColorSwatch(row, { r=predictionColor[1], g=predictionColor[2], b=predictionColor[3], a=predictionColor[4], tooltip='Prediction color', callback=function(red, green, blue, alpha) unitSettings.powerPredictionColor = {red, green, blue, alpha}; RefreshFrames() end }) }
                    end,
                })

                AddRow({
                    title = 'Combat Border',
                    description = 'Recolor the border while in combat.',
                    checked = unitSettings.combatBorder == true,
                    callback = function(value) unitSettings.combatBorder = value; RefreshFrames() end,
                    accessoryWidth = 36,
                    accessories = function(row)
                        local combatBorderColor = unitSettings.combatBorderColor
                        return { Controls.ColorSwatch(row, { r=combatBorderColor[1], g=combatBorderColor[2], b=combatBorderColor[3], a=combatBorderColor[4], tooltip='Combat border color', callback=function(red, green, blue, alpha) unitSettings.combatBorderColor = {red,green,blue,alpha}; RefreshFrames() end }) }
                    end,
                })

                AddRow({
                    title = 'Aggro Border',
                    description = 'Recolor the border when you have aggro.',
                    checked = unitSettings.aggroBorder == true,
                    callback = function(value) unitSettings.aggroBorder = value; RefreshFrames() end,
                    accessoryWidth = 36,
                    accessories = function(row)
                        local aggroBorderColor = unitSettings.aggroBorderColor
                        return { Controls.ColorSwatch(row, { r=aggroBorderColor[1], g=aggroBorderColor[2], b=aggroBorderColor[3], a=aggroBorderColor[4], tooltip='Aggro border color', callback=function(red, green, blue, alpha) unitSettings.aggroBorderColor = {red,green,blue,alpha}; RefreshFrames() end }) }
                    end,
                })

            end

            Section('Name')

            local showNameValue = ResolveShow(unitSettings.showName, settings.showName)
            AddRow({
                spanFull = true,
                title = 'Name',
                description = 'Unit name on the health bar.',
                checked = showNameValue,
                callback = function(value) unitSettings.showName = value; RefreshFrames() end,
                accessoryWidth = 130,
                accessories = function(row)
                    local cog = PageKit.SettingsIcon(row, { title = 'NAME TEXT', tooltip = 'Color, position & size', options = {
                        { label = 'Class/Reaction Color',
                          get = function() return unitSettings.classColorName == true end,
                          set = function(value) unitSettings.classColorName = value; RefreshFrames() end },
                        { kind = 'dropdown', label = 'Position', items = textPlacementItems, controlWidth = 120,
                          get = function() return unitSettings.namePosition end,
                          set = function(value) unitSettings.namePosition = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Text Size', min = 8, max = 20,
                          get = function() return unitSettings.nameTextSize end,
                          set = function(value) unitSettings.nameTextSize = value; RefreshFrames() end },
                        { kind = 'slider', label = 'X Offset', min = -50, max = 50,
                          get = function() return unitSettings.nameOffsetX end,
                          set = function(value) unitSettings.nameOffsetX = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Y Offset', min = -50, max = 50,
                          get = function() return unitSettings.nameOffsetY end,
                          set = function(value) unitSettings.nameOffsetY = value; RefreshFrames() end },
                    } })
                    local friendlyColor = unitSettings.friendlyNameColor
                    local friendlySwatch = Controls.ColorSwatch(row, { r=friendlyColor[1], g=friendlyColor[2], b=friendlyColor[3], a=friendlyColor[4], callback=function(red, green, blue, alpha) unitSettings.friendlyNameColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Friendly' })
                    local neutralColor = unitSettings.neutralNameColor
                    local neutralSwatch = Controls.ColorSwatch(row, { r=neutralColor[1], g=neutralColor[2], b=neutralColor[3], a=neutralColor[4], callback=function(red, green, blue, alpha) unitSettings.neutralNameColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Neutral' })
                    local hostileColor = unitSettings.hostileNameColor
                    local hostileSwatch = Controls.ColorSwatch(row, { r=hostileColor[1], g=hostileColor[2], b=hostileColor[3], a=hostileColor[4], callback=function(red, green, blue, alpha) unitSettings.hostileNameColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Hostile' })
                    return { cog, friendlySwatch, neutralSwatch, hostileSwatch }
                end,
            })

            AddRow({
                title = 'Name Tag',
                description = 'Tag override for this frame.',
                controlWidth = 190,
                control = function(row)
                    return Controls.Tags(row, nil, unitSettings.nameFormat or "", function(value) unitSettings.nameFormat = value ~= "" and value or nil; RefreshFrames() end, 180, nil, GetTagSuggestionsForUnit(unitKey), "[name]")
                end,
            })

            if unitKey == "player" or unitKey == "pet" then
                AddRow({
                    title = 'Custom Name',
                    description = 'Shown instead of the real name.',
                    controlWidth = 170,
                    control = function(row)
                        return Controls.TextBox(row, nil, unitSettings.customName or "", function(value) unitSettings.customName = value; RefreshFrames() end, nil, 160)
                    end,
                })
            end

            Section('Health & Power')

            local showHealthTextValue = ResolveShow(unitSettings.showHealthText, settings.showHealthText)
            AddRow({
                title = 'Health Text',
                description = 'Health value on the bar.',
                checked = showHealthTextValue,
                callback = function(value) unitSettings.showHealthText = value; RefreshFrames() end,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, { title = 'HEALTH TEXT', tooltip = 'Position & size', options = {
                        { kind = 'dropdown', label = 'Position', items = textPlacementItems, controlWidth = 120,
                          get = function() return unitSettings.healthPosition end,
                          set = function(value) unitSettings.healthPosition = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Text Size', min = 8, max = 20,
                          get = function() return unitSettings.healthTextSize end,
                          set = function(value) unitSettings.healthTextSize = value; RefreshFrames() end },
                        { kind = 'slider', label = 'X Offset', min = -50, max = 50,
                          get = function() return unitSettings.healthOffsetX end,
                          set = function(value) unitSettings.healthOffsetX = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Y Offset', min = -50, max = 50,
                          get = function() return unitSettings.healthOffsetY end,
                          set = function(value) unitSettings.healthOffsetY = value; RefreshFrames() end },
                    } }) }
                end,
            })

            AddRow({
                title = 'Health Tag',
                description = 'Tag override for this frame.',
                controlWidth = 190,
                control = function(row)
                    return Controls.Tags(row, nil, unitSettings.healthFormat, function(value) unitSettings.healthFormat = value ~= "" and value or nil; RefreshFrames() end, 180, nil, GetTagSuggestionsForUnit(unitKey), "[hp:short] • [perhp]%")
                end,
            })

            local showPowerValue = unitSettings.showPower == true
            AddRow({
                title = 'Power Bar',
                description = 'Resource bar under the health bar.',
                checked = showPowerValue,
                callback = function(value)
                    unitSettings.showPower = value
                    RefreshFrames()
                end,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SizeIcon(row, { title = 'POWER BAR', options = {
                        { kind = 'slider', label = 'Bar Height', min = 1, max = 20,
                          get = function() return unitSettings.powerHeight end,
                          set = function(value) unitSettings.powerHeight = value; RefreshFrames() end },
                    } }) }
                end,
            })

            local showPowerTextValue = ResolveShow(unitSettings.showPowerText, settings.showPowerText, false)
            AddRow({
                title = 'Power Text',
                description = 'Resource value on the power bar.',
                checked = showPowerTextValue,
                callback = function(value) unitSettings.showPowerText = value; RefreshFrames() end,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, { title = 'POWER TEXT', tooltip = 'Position & size', options = {
                        { kind = 'dropdown', label = 'Position', items = textPlacementItems, controlWidth = 120,
                          get = function() return unitSettings.powerPosition end,
                          set = function(value) unitSettings.powerPosition = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Text Size', min = 8, max = 20,
                          get = function() return unitSettings.powerTextSize end,
                          set = function(value) unitSettings.powerTextSize = value; RefreshFrames() end },
                        { kind = 'slider', label = 'X Offset', min = -50, max = 50,
                          get = function() return unitSettings.powerOffsetX end,
                          set = function(value) unitSettings.powerOffsetX = value; RefreshFrames() end },
                        { kind = 'slider', label = 'Y Offset', min = -50, max = 50,
                          get = function() return unitSettings.powerOffsetY end,
                          set = function(value) unitSettings.powerOffsetY = value; RefreshFrames() end },
                    } }) }
                end,
            })

            AddRow({
                title = 'Power Tag',
                description = 'Tag override for this frame.',
                controlWidth = 190,
                control = function(row)
                    return Controls.Tags(row, nil, unitSettings.powerFormat, function(value) unitSettings.powerFormat = value ~= "" and value or nil; RefreshFrames() end, 180, nil, GetTagSuggestionsForUnit(unitKey))
                end,
            })

            if unitKey == "pet" then
                Section('Colors')

                AddRow({
                    title = 'Pet Colors',
                    description = 'Health, power, background and border.',
                    plain = true,
                    accessoryWidth = 150,
                    accessories = function(row)
                        local petHealthColor = settings.petHealthColor
                        local petHealthSwatch = Controls.ColorSwatch(row, { r=petHealthColor[1], g=petHealthColor[2], b=petHealthColor[3], a=petHealthColor[4], callback=function(red, green, blue, alpha) settings.petHealthColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Health' })
                        local petBackgroundColor = settings.petBgColor
                        local petBgSwatch = Controls.ColorSwatch(row, { r=petBackgroundColor[1], g=petBackgroundColor[2], b=petBackgroundColor[3], a=petBackgroundColor[4], callback=function(red, green, blue, alpha) settings.petBgColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Health background' })
                        local petPowerColor = settings.petPowerColor
                        local petPowerSwatch = Controls.ColorSwatch(row, { r=petPowerColor[1], g=petPowerColor[2], b=petPowerColor[3], a=petPowerColor[4], callback=function(red, green, blue, alpha) settings.petPowerColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Power' })
                        local petPowerBackgroundColor = settings.petPowerBgColor
                        local petPowerBgSwatch = Controls.ColorSwatch(row, { r=petPowerBackgroundColor[1], g=petPowerBackgroundColor[2], b=petPowerBackgroundColor[3], a=petPowerBackgroundColor[4], callback=function(red, green, blue, alpha) settings.petPowerBgColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Power background' })
                        local petBorderColor = settings.petBorderColor
                        local petBorderSwatch = Controls.ColorSwatch(row, { r=petBorderColor[1], g=petBorderColor[2], b=petBorderColor[3], a=petBorderColor[4], callback=function(red, green, blue, alpha) settings.petBorderColor = {red,green,blue,alpha}; RefreshFrames() end, tooltip='Border' })
                        return { petHealthSwatch, petBgSwatch, petPowerSwatch, petPowerBgSwatch, petBorderSwatch }
                    end,
                })
            end

            if unitKey == "player" or unitKey == "target" or unitKey == "focus" or unitKey == "targettarget" then
                local anchorPoints = BUI.C.ANCHOR_POINT_OPTIONS
                local growthItems = { { value = "LEFT", text = "Left" }, { value = "RIGHT", text = "Right" } }
                local verticalGrowthItems = { { value = "UP", text = "Up" }, { value = "DOWN", text = "Down" } }
                local stackPositionItems = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
                local sortMethodItems = BUI.AuraEngine.SortMethodItems()

                Section('Auras')

                AddRow({
                    spanFull = true,
                    title = 'Debuffs',
                    description = 'Debuff icons attached to the frame.',
                    checked = unitSettings.showDebuffs == true,
                    callback = function(value) unitSettings.showDebuffs = value; RefreshFrames() end,
                    accessoryWidth = 240,
                    accessories = function(row)
                        local mover = PageKit.PositionIcon(row, { title = 'DEBUFF POSITION', options = {
                            { kind = 'dropdown', label = 'Anchor Point', items = anchorPoints, controlWidth = 120,
                              get = function() return unitSettings.debuffAnchorPoint end,
                              set = function(value)
                                  unitSettings.debuffAnchorPoint = value
                                  if string.find(value, "RIGHT") then unitSettings.debuffGrowthX = "LEFT" elseif string.find(value, "LEFT") then unitSettings.debuffGrowthX = "RIGHT" end
                                  if string.find(value, "TOP") then unitSettings.debuffGrowthY = "UP" elseif string.find(value, "BOTTOM") then unitSettings.debuffGrowthY = "DOWN" end
                                  RefreshFrames()
                              end },
                            { kind = 'dropdown', label = 'Growth Direction', items = growthItems, controlWidth = 120,
                              get = function() return unitSettings.debuffGrowthX end,
                              set = function(value) unitSettings.debuffGrowthX = value; RefreshFrames() end },
                            { kind = 'dropdown', label = 'Vertical Growth', items = verticalGrowthItems, controlWidth = 120,
                              get = function() return unitSettings.debuffGrowthY end,
                              set = function(value) unitSettings.debuffGrowthY = value; RefreshFrames() end },
                            { kind = 'slider', label = 'X Offset', min = -500, max = 500,
                              get = function() return unitSettings.debuffOffsetX end,
                              set = function(value) unitSettings.debuffOffsetX = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Y Offset', min = -500, max = 500,
                              get = function() return unitSettings.debuffOffsetY end,
                              set = function(value) unitSettings.debuffOffsetY = value; RefreshAurasOnly() end },
                        } })
                        local size = PageKit.SizeIcon(row, { title = 'DEBUFF SIZE', options = {
                            { kind = 'slider', label = 'Icon Size', min = 12, max = 80,
                              get = function() return unitSettings.debuffIconSize or unitSettings.auraIconSize end,
                              set = function(value) unitSettings.debuffIconSize = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Spacing', min = 0, max = 10,
                              get = function() return unitSettings.debuffSpacing or unitSettings.auraSpacing end,
                              set = function(value) unitSettings.debuffSpacing = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Max Icons', min = 1, max = 16,
                              get = function() return unitSettings.maxDebuffs end,
                              set = function(value) unitSettings.maxDebuffs = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Per Row', min = 1, max = 16,
                              get = function() return unitSettings.debuffsPerRow end,
                              set = function(value) unitSettings.debuffsPerRow = value; RefreshAurasOnly() end },
                        } })
                        local cog = PageKit.SettingsIcon(row, { title = 'DEBUFFS', tooltip = 'Swipe, type color & text', options = {
                            { label = 'Reverse Swipe',
                              get = function() return unitSettings.auraReverseSwipe == true end,
                              set = function(value) unitSettings.auraReverseSwipe = value; RefreshFrames() end },
                            { label = 'Color by Type',
                              get = function() return unitSettings.showDebuffType ~= false end,
                              set = function(value) unitSettings.showDebuffType = value; RefreshFrames() end },
                            { kind = 'dropdown', label = 'Sort By', items = sortMethodItems, controlWidth = 120,
                              get = function() return unitSettings.debuffSortMethod end,
                              set = function(value) unitSettings.debuffSortMethod = value; RefreshAurasOnly() end },
                            { label = 'Show Stack Count',
                              get = function() return ResolveShow(unitSettings.debuffShowStack, unitSettings.auraShowStack) end,
                              set = function(value) unitSettings.debuffShowStack = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Stack Size', min = 6, max = 32,
                              get = function() return unitSettings.debuffStackSize or unitSettings.auraStackSize end,
                              set = function(value) unitSettings.debuffStackSize = value; RefreshAurasOnly() end },
                            { kind = 'dropdown', label = 'Stack Position', items = stackPositionItems, controlWidth = 120,
                              get = function() return unitSettings.debuffStackPos end,
                              set = function(value) unitSettings.debuffStackPos = value; RefreshAurasOnly() end },
                            { label = 'Show CD Text',
                              get = function() return ResolveShow(unitSettings.debuffShowCd, unitSettings.auraShowCd) end,
                              set = function(value) unitSettings.debuffShowCd = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'CD Size', min = 6, max = 32,
                              get = function() return unitSettings.debuffCdSize or unitSettings.auraCdSize end,
                              set = function(value) unitSettings.debuffCdSize = value; RefreshAurasOnly() end },
                        } })
                        local rules = BUI.AuraRuleEditor(row, {
                            getRules = function() return BUI.UnitFrames.GetAuraRules(unitSettings, true) end,
                            polarity = 'HARMFUL', unitFramesOnly = true,
                            onChanged = RefreshFrames,
                        })
                        return { mover, size, cog, rules }
                    end,
                })

                AddRow({
                    spanFull = true,
                    title = 'Buffs',
                    description = 'Buff icons attached to the frame.',
                    checked = unitSettings.showBuffs == true,
                    callback = function(value) unitSettings.showBuffs = value; RefreshFrames() end,
                    accessoryWidth = 240,
                    accessories = function(row)
                        local mover = PageKit.PositionIcon(row, { title = 'BUFF POSITION', options = {
                            { kind = 'dropdown', label = 'Anchor Point', items = anchorPoints, controlWidth = 120,
                              get = function() return unitSettings.buffAnchorPoint or "BOTTOMLEFT" end,
                              set = function(value)
                                  unitSettings.buffAnchorPoint = value
                                  if string.find(value, "RIGHT") then unitSettings.buffGrowthX = "LEFT" elseif string.find(value, "LEFT") then unitSettings.buffGrowthX = "RIGHT" end
                                  if string.find(value, "TOP") then unitSettings.buffGrowthY = "UP" elseif string.find(value, "BOTTOM") then unitSettings.buffGrowthY = "DOWN" end
                                  RefreshFrames()
                              end },
                            { kind = 'dropdown', label = 'Growth Direction', items = growthItems, controlWidth = 120,
                              get = function() return unitSettings.buffGrowthX or "RIGHT" end,
                              set = function(value) unitSettings.buffGrowthX = value; RefreshFrames() end },
                            { kind = 'dropdown', label = 'Vertical Growth', items = verticalGrowthItems, controlWidth = 120,
                              get = function() return unitSettings.buffGrowthY or "DOWN" end,
                              set = function(value) unitSettings.buffGrowthY = value; RefreshFrames() end },
                            { kind = 'slider', label = 'X Offset', min = -500, max = 500,
                              get = function() return unitSettings.buffOffsetX or 0 end,
                              set = function(value) unitSettings.buffOffsetX = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Y Offset', min = -500, max = 500,
                              get = function() return unitSettings.buffOffsetY or -4 end,
                              set = function(value) unitSettings.buffOffsetY = value; RefreshAurasOnly() end },
                        } })
                        local size = PageKit.SizeIcon(row, { title = 'BUFF SIZE', options = {
                            { kind = 'slider', label = 'Icon Size', min = 12, max = 80,
                              get = function() return unitSettings.buffIconSize or unitSettings.auraIconSize end,
                              set = function(value) unitSettings.buffIconSize = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Spacing', min = 0, max = 10,
                              get = function() return unitSettings.buffSpacing or unitSettings.auraSpacing end,
                              set = function(value) unitSettings.buffSpacing = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Max Icons', min = 1, max = 32,
                              get = function() return unitSettings.maxBuffs end,
                              set = function(value) unitSettings.maxBuffs = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Per Row', min = 1, max = 16,
                              get = function() return unitSettings.buffsPerRow or 8 end,
                              set = function(value) unitSettings.buffsPerRow = value; RefreshAurasOnly() end },
                        } })
                        local cog = PageKit.SettingsIcon(row, { title = 'BUFFS', tooltip = 'Stack & cooldown text', options = {
                            { kind = 'dropdown', label = 'Sort By', items = sortMethodItems, controlWidth = 120,
                              get = function() return unitSettings.buffSortMethod or 'default' end,
                              set = function(value) unitSettings.buffSortMethod = value; RefreshAurasOnly() end },
                            { label = 'Show Stack Count',
                              get = function() return ResolveShow(unitSettings.buffShowStack, unitSettings.auraShowStack) end,
                              set = function(value) unitSettings.buffShowStack = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'Stack Size', min = 6, max = 32,
                              get = function() return unitSettings.buffStackSize or unitSettings.auraStackSize end,
                              set = function(value) unitSettings.buffStackSize = value; RefreshAurasOnly() end },
                            { kind = 'dropdown', label = 'Stack Position', items = stackPositionItems, controlWidth = 120,
                              get = function() return unitSettings.buffStackPos or "BOTTOMRIGHT" end,
                              set = function(value) unitSettings.buffStackPos = value; RefreshAurasOnly() end },
                            { label = 'Show CD Text',
                              get = function() return ResolveShow(unitSettings.buffShowCd, unitSettings.auraShowCd) end,
                              set = function(value) unitSettings.buffShowCd = value; RefreshAurasOnly() end },
                            { kind = 'slider', label = 'CD Size', min = 6, max = 32,
                              get = function() return unitSettings.buffCdSize or unitSettings.auraCdSize end,
                              set = function(value) unitSettings.buffCdSize = value; RefreshAurasOnly() end },
                        } })
                        local rules = BUI.AuraRuleEditor(row, {
                            getRules = function() return BUI.UnitFrames.GetAuraRules(unitSettings, false) end,
                            polarity = 'HELPFUL', unitFramesOnly = true,
                            onChanged = RefreshFrames,
                        })
                        return { mover, size, cog, rules }
                    end,
                })
            end

            unitGrid.Flush()
            unitGrid:SyncDim(unitSettings.enabled ~= false)
            return unitGrid
        end

        local function LazyBuild(tab, builder)
            local built = false
            HookScript(tab.frame, "OnShow", function()
                if built then return end
                built = true; builder(); tab:Refresh()
            end)
        end

        local function SyncableBuild(tab, unitKey)
            local built = false
            HookScript(tab.frame, "OnShow", function()
                if built and not syncDirty[unitKey] then return end
                if built then tab:Clear() end
                built, syncDirty[unitKey] = true, false
                BuildUnitSettings(tab, unitKey)
                tab:Refresh()
            end)
        end

        LazyBuild(page:GetTab(3), function()
            local customTagsTab = page:GetTab(3)
            local selectedUnit = "player"

            local unitItems = {
                { value = "player", text = "Player" }, { value = "target", text = "Target" },
                { value = "targettarget", text = "Target of Target" }, { value = "focus", text = "Focus" },
                { value = "pet", text = "Pet" }, { value = "boss", text = "Boss" },
            }
            local anchorItems = BUI.C.ANCHOR_POINT_OPTIONS_SHORT

            local RebuildCustomTagGrid

            local function BuildMockUnitFrame(parent, width, height)
                local frame = CreateFrame('Frame', nil, parent)
                local background = frame:CreateTexture(nil, 'BACKGROUND')
                background:SetAllPoints()
                local health = frame:CreateTexture(nil, 'ARTWORK')
                health:SetPoint('TOPLEFT'); health:SetPoint('BOTTOMLEFT')
                local deficit = frame:CreateTexture(nil, 'ARTWORK')
                deficit:SetPoint('TOPRIGHT'); deficit:SetPoint('BOTTOMRIGHT')
                local WHITE8 = 'Interface\\Buttons\\WHITE8x8'
                local borders = {}
                for edgeIndex, edge in ipairs({
                    {'TOPLEFT', 'TOPRIGHT', 'width', 1, nil},
                    {'BOTTOMLEFT', 'BOTTOMRIGHT', 'width', 1, nil},
                    {'TOPLEFT', 'BOTTOMLEFT', 'height', nil, 1},
                    {'TOPRIGHT', 'BOTTOMRIGHT', 'height', nil, 1},
                }) do
                    local edgeTexture = frame:CreateTexture(nil, 'BORDER')
                    edgeTexture:SetTexture(WHITE8)
                    edgeTexture:SetPoint(edge[1]); edgeTexture:SetPoint(edge[2])
                    if edge[4] then edgeTexture:SetHeight(edge[4]) end
                    if edge[5] then edgeTexture:SetWidth(edge[5]) end
                    borders[edgeIndex] = edgeTexture
                end

                function frame:Restyle(width, height)
                    frame:SetSize(width, height)
                    health:SetTexture(BUI.GetGlobalTexture())
                    deficit:SetTexture(BUI.GetGlobalTexture())
                    local healthRed, healthGreen, healthBlue = 0.2, 0.8, 0.2
                    if settings.classColorHealth then
                        local _, class = UnitClass('player')
                        if class and RAID_CLASS_COLORS[class] then
                            local classColor = RAID_CLASS_COLORS[class]
                            healthRed, healthGreen, healthBlue = classColor.r, classColor.g, classColor.b
                        end
                    elseif settings.healthColor then
                        local healthColor = settings.healthColor
                        healthRed, healthGreen, healthBlue = healthColor[1] or healthRed, healthColor[2] or healthGreen, healthColor[3] or healthBlue
                    end
                    health:SetVertexColor(healthRed, healthGreen, healthBlue, 1)
                    health:SetWidth(width * 0.75)
                    local backgroundColor = settings.bgColor
                    deficit:SetVertexColor(backgroundColor[1] or 0.06, backgroundColor[2] or 0.06, backgroundColor[3] or 0.06, backgroundColor[4] or 0.8)
                    deficit:SetWidth(width * 0.25)
                    BUI.Tools.SetColorTex(background, backgroundColor[1] or 0.1, backgroundColor[2] or 0.1, backgroundColor[3] or 0.1, backgroundColor[4] or 0.8)
                    local borderColor = settings.borderColor
                    local borderRed, borderGreen, borderBlue, borderAlpha = borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1
                    for borderIndex = 1, #borders do
                        borders[borderIndex]:SetVertexColor(borderRed, borderGreen, borderBlue, borderAlpha)
                    end
                end
                frame:Restyle(width, height)

                frame._tagFs = nil
                function frame:UpdateTag(draft)
                    if not frame._tagFs then
                        frame._tagFs = frame:CreateFontString(nil, 'OVERLAY')
                    end
                    local fontString = frame._tagFs
                    local draftFont = draft.font
                    local font
                    if draftFont and draftFont ~= '' and draftFont ~= 'GLOBAL' then
                        local sharedMedia = LibStub('LibSharedMedia-3.0')
                        font = sharedMedia:Fetch('font', draftFont) or BUI.GetGlobalFont()
                    else
                        font = BUI.GetGlobalFont()
                    end
                    BUI.Pixel.ApplyFont(fontString, draft.fontSize or 12, font)
                    fontString:ClearAllPoints()
                    local point = draft.point or 'CENTER'
                    fontString:SetPoint(point, frame, point, draft.x or 0, draft.y or 0)
                    fontString:SetJustifyH(point:match('LEFT') and 'LEFT' or point:match('RIGHT') and 'RIGHT' or 'CENTER')
                    fontString:SetWordWrap(false); fontString:SetNonSpaceWrap(false)
                    local color = draft.color
                    if color then fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
                    else fontString:SetTextColor(1, 1, 1, 1) end
                    local resolved = UnitFrames.ParsePreviewTags and UnitFrames.ParsePreviewTags(draft.tag or '') or draft.tag or ''
                    fontString:SetText(resolved)
                    fontString:Show()
                end
                return frame
            end

            local preview = Layout.Preview(customTagsTab, {title = 'Preview', height = 120})
            local previewContent = preview:GetContent()
            local pageMock
            local previewTags = {}

            local function UpdatePreview()
                for _, fontString in pairs(previewTags) do fontString:Hide() end

                local unitSettings = settings[selectedUnit] or {}
                local width = unitSettings.width or 200
                local height = unitSettings.height or 40

                if not pageMock then
                    pageMock = BuildMockUnitFrame(previewContent, width, height)
                    pageMock:SetPoint('CENTER', previewContent, 'CENTER', 0, 0)
                else
                    pageMock:Restyle(width, height)
                end
                pageMock:Show()

                local entries = unitSettings.customTags or {}
                local font = BUI.GetGlobalFont()
                for index, entry in ipairs(entries) do
                    if entry.tag and entry.tag ~= '' and entry.enabled ~= false then
                        local fontString = previewTags[index]
                        if not fontString then
                            fontString = pageMock:CreateFontString(nil, 'OVERLAY')
                            previewTags[index] = fontString
                        else
                            fontString:SetParent(pageMock)
                        end
                        BUI.Pixel.ApplyFont(fontString, entry.fontSize or 12, font)
                        fontString:ClearAllPoints()
                        local point = entry.point or 'CENTER'
                        fontString:SetPoint(point, pageMock, point, entry.x or 0, entry.y or 0)
                        fontString:SetJustifyH(point:match('LEFT') and 'LEFT' or point:match('RIGHT') and 'RIGHT' or 'CENTER')
                        fontString:SetWordWrap(false); fontString:SetNonSpaceWrap(false)
                        local color = entry.color
                        if color then fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
                        else fontString:SetTextColor(1, 1, 1, 1) end
                        local resolved = UnitFrames.ParsePreviewTags and UnitFrames.ParsePreviewTags(entry.tag) or entry.tag
                        fontString:SetText(resolved)
                        fontString:Show()
                    end
                end
            end

            Layout.Section(customTagsTab, 'Unit Frame')
            local selectionGrid = BUILib.PageKit.RowGrid(customTagsTab)
            selectionGrid:Add({
                spanFull = true,
                title = 'Unit',
                description = 'Which frame these custom tags belong to.',
                controlWidth = 170,
                control = function(row)
                    return Controls.Dropdown(row, nil, unitItems, selectedUnit, function(value)
                        selectedUnit = value
                        RebuildCustomTagGrid()
                        UpdatePreview()
                    end, nil, 160)
                end,
            })
            selectionGrid:Flush()

            local anchorNames = {}
            for _, option in ipairs(BUI.C.ANCHOR_POINT_OPTIONS_SHORT) do anchorNames[option.value] = option.text end
            local installerParent = BUI.PageEngine.window.frame

            local function OpenTagEditor(entry, isNew, onSave)
                local suggestions = GetTagSuggestionsForUnit(selectedUnit)
                local draft = {
                    name = entry.name or '', tag = entry.tag or '[name]',
                    point = entry.point or 'CENTER', x = entry.x or 0, y = entry.y or 0,
                    fontSize = entry.fontSize or 12,
                    color = entry.color and {unpack(entry.color)} or {1,1,1,1},
                    enabled = isNew and true or (entry.enabled ~= false),
                    drawLayer = entry.drawLayer or 'OVERLAY',
                    drawSubLevel = entry.drawSubLevel or 0,
                }

                local buttons = {
                    { text = isNew and 'Create' or 'Save', color = Modals.BTN_CONFIRM, width = 100,
                        onClick = function(close)
                            if draft.name == '' then draft.name = nil end
                            entry.name = draft.name; entry.tag = draft.tag
                            entry.point = draft.point; entry.x = draft.x; entry.y = draft.y
                            entry.fontSize = draft.fontSize; entry.color = draft.color
                            entry.font = (draft.font ~= '' and draft.font ~= 'GLOBAL') and draft.font or nil
                            entry.enabled = draft.enabled
                            entry.drawLayer = draft.drawLayer
                            entry.drawSubLevel = draft.drawSubLevel
                            close()
                            if onSave then onSave(entry) end
                        end,
                    },
                    { text = 'Cancel', color = Modals.BTN_NEUTRAL, width = 80,
                        onClick = function(close) close() end,
                    },
                }
                if not isNew then
                    buttons[#buttons + 1] = { text = 'Delete', color = Modals.BTN_CANCEL, width = 80,
                        onClick = function(close)
                            close()
                            if onSave then onSave(nil) end
                        end,
                    }
                end

                draft.font = entry.font or 'GLOBAL'

                local content = Modals.Settings({
                    noTitle = true,
                    width = 560, height = 620,
                    parent = installerParent,
                    buttons = buttons,
                })

                local modalTabs = {'General'}
                local modalTabBar = Controls.TabLineBar(content.dialog, modalTabs, 1, nil, content.dialog:GetWidth() - 40)
                modalTabBar:SetPoint('TOPLEFT', Pixel.Scale(10), Pixel.Scale(-8))

                local child = content.child
                local modalWidth = content.contentWidth or 510
                local COLUMN_GAP = 12
                local HALF = math.floor((modalWidth - COLUMN_GAP) / 2)
                local THIRD = math.floor((modalWidth - COLUMN_GAP * 2) / 3)
                local COLUMN_2 = THIRD + COLUMN_GAP
                local COLUMN_3 = COLUMN_2 * 2
                local SPACING = 16

                local function Unwrap(widget) return type(widget) == 'table' and widget.frame or widget end

                local function Label(text, anchorTo, offsetX, offsetY)
                    local label = child:CreateFontString(nil, 'OVERLAY')
                    Pixel.ApplyFont(label, 10, FONT, '')
                    label:SetText(text)
                    label:SetTextColor(0.45, 0.45, 0.45)
                    label:SetPoint('TOPLEFT', Unwrap(anchorTo), 'BOTTOMLEFT', offsetX or 0, offsetY or -SPACING)
                    return label
                end

                local function Section(title, anchorTo, offsetY)
                    local frame = CreateFrame('Frame', nil, child)
                    frame:SetHeight(Pixel.Scale(18))
                    frame:SetPoint('TOPLEFT', Unwrap(anchorTo), 'BOTTOMLEFT', 0, offsetY or -SPACING)
                    frame:SetPoint('RIGHT', child, 'RIGHT', 0, 0)
                    local text = frame:CreateFontString(nil, 'OVERLAY')
                    Pixel.ApplyFont(text, 12, FONT, ''); text:SetText(title)
                    text:SetTextColor(0.7, 0.7, 0.7); text:SetPoint('LEFT', 0, 0)
                    frame._title = text
                    return frame
                end

                local unitSettings = settings[selectedUnit] or {}
                local mockWidth = unitSettings.width or 200
                local mockHeight = unitSettings.height or 40

                local modalPreview = Controls.Preview(child, nil, modalWidth, 70)
                local modalPreviewContent = modalPreview:GetContent()
                local modalMock = BuildMockUnitFrame(modalPreviewContent, mockWidth, mockHeight)
                modalMock:SetPoint('CENTER', modalPreviewContent, 'CENTER', 0, 0)
                modalPreview:ShowCrosshair(false)
                Layout.Add(content, modalPreview, 0)

                local function UpdateModalPreview()
                    local saved = unitSettings.customTags or {}
                    local font = BUI.GetGlobalFont()
                    local allEntries = {}
                    for index = 1, #saved do
                        local savedEntry = saved[index]
                        if not isNew and savedEntry == entry then savedEntry = draft end
                        allEntries[index] = savedEntry
                    end
                    if isNew then allEntries[#allEntries + 1] = draft end

                    local fontStringIndex = 0
                    for _, tagEntry in ipairs(allEntries) do
                        if tagEntry.tag and tagEntry.tag ~= '' and tagEntry.enabled ~= false then
                            fontStringIndex = fontStringIndex + 1
                            local fontString = modalMock._allFs and modalMock._allFs[fontStringIndex]
                            if not fontString then
                                fontString = modalMock:CreateFontString(nil, 'OVERLAY')
                                modalMock._allFs = modalMock._allFs or {}
                                modalMock._allFs[fontStringIndex] = fontString
                            end
                            BUI.Pixel.ApplyFont(fontString, tagEntry.fontSize or 12, font)
                            fontString:SetDrawLayer(tagEntry.drawLayer or 'OVERLAY', tagEntry.drawSubLevel or 0)
                            fontString:ClearAllPoints()
                            local point = tagEntry.point or 'CENTER'
                            fontString:SetPoint(point, modalMock, point, tagEntry.x or 0, tagEntry.y or 0)
                            fontString:SetJustifyH(point:match('LEFT') and 'LEFT' or point:match('RIGHT') and 'RIGHT' or 'CENTER')
                            fontString:SetWordWrap(false)
                            fontString:SetNonSpaceWrap(false)
                            local color = tagEntry.color
                            if color then fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
                            else fontString:SetTextColor(1, 1, 1, 1) end
                            local resolved = UnitFrames.ParsePreviewTags and UnitFrames.ParsePreviewTags(tagEntry.tag) or tagEntry.tag
                            fontString:SetText(resolved)
                            fontString:Show()
                        end
                    end
                    if modalMock._allFs then
                        for index = fontStringIndex + 1, #modalMock._allFs do
                            modalMock._allFs[index]:Hide()
                        end
                    end

                    UpdatePreview()
                end
                UpdateModalPreview()

                local detailsSection = Section('Details', modalPreview)

                local nameLabel = Label('Name', detailsSection, 0, -8)
                local enableLabel = Label('Enabled', detailsSection, modalWidth - 36, -8)
                local nameBox = Controls.TextBox(child, nil, draft.name, function(value) draft.name = value end, nil, modalWidth - 60)
                nameBox:SetPoint('TOPLEFT', nameLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

                local enableToggle = Controls.StatusToggle(child, nil, draft.enabled, function(value) draft.enabled = value end)
                enableToggle:SetPoint('TOPLEFT', enableLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

                local tagSection = Section('Tag', nameBox)
                local tagControl = Controls.Tags(child, nil, draft.tag, function(value)
                    draft.tag = value; UpdateModalPreview()
                end, modalWidth, 'Type [ for tags', suggestions)
                tagControl:SetPoint('TOPLEFT', tagSection, 'BOTTOMLEFT', 0, Pixel.Scale(-6))

                local appearanceSection = Section('Appearance', tagControl)
                local fontLabel = Label('Font', appearanceSection, 0, -8)
                local fontDropdown = Controls.Dropdown(child, nil, BUI.BuildFontDropdownItems('GLOBAL'), draft.font, function(value)
                    draft.font = value; UpdateModalPreview()
                end, nil, THIRD)
                fontDropdown:SetPoint('TOPLEFT', fontLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

                local anchorLabel = Label('Anchor', appearanceSection, COLUMN_2, -8)
                local pointDropdown = Controls.Dropdown(child, nil, anchorItems, draft.point, function(value)
                    draft.point = value; UpdateModalPreview()
                end, nil, THIRD)
                pointDropdown:SetPoint('TOPLEFT', anchorLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

                local colorLabel = Label('Color', appearanceSection, COLUMN_3, -8)
                local colorSwatch = Controls.ColorSwatch(child, { r=draft.color[1], g=draft.color[2], b=draft.color[3], a=draft.color[4], callback=function(red, green, blue, alpha)
                    draft.color = {red,green,blue,alpha}; UpdateModalPreview()
                end })
                colorSwatch:SetPoint('TOPLEFT', colorLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-6))

                local sizeLabel = Label('Size', fontDropdown, 0, -12)
                local sizeSlider = Controls.CompactSlider(child, nil, 6, 48, draft.fontSize, function(value)
                    draft.fontSize = math.floor(value + 0.5); UpdateModalPreview()
                end, 1, THIRD)
                sizeSlider:SetPoint('TOPLEFT', sizeLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

                local layerItems = {
                    { text = 'Background', value = 'BACKGROUND' },
                    { text = 'Border',     value = 'BORDER'     },
                    { text = 'Artwork',    value = 'ARTWORK'    },
                    { text = 'Overlay',    value = 'OVERLAY'    },
                    { text = 'Highlight',  value = 'HIGHLIGHT'  },
                }
                local layerLabel = Label('Layer', fontDropdown, COLUMN_2, -12)
                local layerDropdown = Controls.Dropdown(child, nil, layerItems, draft.drawLayer, function(value)
                    draft.drawLayer = value; UpdateModalPreview()
                end, nil, THIRD)
                layerDropdown:SetPoint('TOPLEFT', layerLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

                local subLabel = Label('Sublevel', fontDropdown, COLUMN_3, -12)
                local subSlider = Controls.CompactSlider(child, nil, -7, 7, draft.drawSubLevel, function(value)
                    draft.drawSubLevel = math.floor(value + 0.5); UpdateModalPreview()
                end, 1, THIRD)
                subSlider:SetPoint('TOPLEFT', subLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

                local positionSection = Section('Position', sizeSlider)
                local xLabel = Label('X Offset', positionSection, 0, -8)
                local xSlider = Controls.CompactSlider(child, nil, -200, 200, draft.x, function(value)
                    draft.x = math.floor(value + 0.5); UpdateModalPreview()
                end, 1, HALF)
                xSlider:SetPoint('TOPLEFT', xLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

                local yLabel = Label('Y Offset', positionSection, HALF + COLUMN_GAP, -8)
                local ySlider = Controls.CompactSlider(child, nil, -200, 200, draft.y, function(value)
                    draft.y = math.floor(value + 0.5); UpdateModalPreview()
                end, 1, HALF)
                ySlider:SetPoint('TOPLEFT', yLabel, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

                local dialog = content.dialog
                local function FitDialogToContent()
                    if not dialog:IsShown() then return end
                    local bottomEdge = ySlider:GetBottom()
                    local topEdge = child:GetTop()
                    if not bottomEdge or not topEdge then return end
                    local contentHeight = topEdge - bottomEdge
                    local chrome = dialog:GetHeight() - content.scroll:GetHeight()
                    local wanted = math.ceil(contentHeight + chrome + Pixel.Scale(20))
                    local parentFrame = dialog:GetParent()
                    local ceiling = parentFrame and (parentFrame:GetHeight() - Pixel.Scale(24)) or wanted
                    dialog:SetHeight(math.min(wanted, ceiling))
                    content:Refresh()
                end
                BUILib.Defer(FitDialogToContent)
            end

            local tagPanel = Layout.SettingsCard(customTagsTab, {title = 'Custom Tags'})
            local tagChild = tagPanel.child
            local tagGridFrame

            local addTagButton = Controls.Button(tagPanel.frame, '+ New', 60, function()
                local unitSettings = settings[selectedUnit]
                if not unitSettings then settings[selectedUnit] = {}; unitSettings = settings[selectedUnit] end
                unitSettings.customTags = unitSettings.customTags or {}
                OpenTagEditor({}, true, function(entry)
                    if not entry.name or entry.name == '' then entry.name = 'Tag ' .. (#unitSettings.customTags + 1) end
                    unitSettings.customTags[#unitSettings.customTags + 1] = entry
                    RefreshFrames(); UpdatePreview(); RebuildCustomTagGrid()
                end)
            end)
            local addButtonFrame = addTagButton.frame
            addButtonFrame:SetHeight(Pixel.Scale(20)); addButtonFrame:ClearAllPoints()
            addButtonFrame:SetPoint('RIGHT', tagPanel.frame, 'TOPRIGHT', Pixel.Scale(-12), Pixel.Scale(-14))

            local gridWidth = tagPanel.contentWidth or 500
            local usable = gridWidth - 16
            local tagGrid = Controls.SelectableGrid(tagChild, {
                width = gridWidth,
                selectable = false,
                rowHeight = 32,
                columns = {
                    { label = 'Name',    width = math.floor(usable * 0.22) },
                    { label = 'Anchor',  width = math.floor(usable * 0.18) },
                    { label = 'Tag',     width = math.floor(usable * 0.22) },
                    { label = 'Preview', width = math.floor(usable * 0.20) },
                    { label = 'Status',  width = math.floor(usable * 0.14), type = 'status' },
                },
                onRowClick = function(rowIndex)
                    local unitSettings = settings[selectedUnit]
                    local entry = unitSettings and unitSettings.customTags and unitSettings.customTags[rowIndex]
                    if entry then
                        OpenTagEditor(entry, false, function(result)
                            if result == nil then
                                table.remove(unitSettings.customTags, rowIndex)
                            end
                            RefreshFrames(); UpdatePreview(); RebuildCustomTagGrid()
                        end)
                    end
                end,
            })
            Layout.Add(tagPanel, tagGrid, 0)
            tagGrid:SetBackdrop(nil)
            tagGrid:ClearAllPoints()
            tagGrid:SetPoint('TOPLEFT', tagPanel.frame, 'TOPLEFT', Pixel.Scale(1), -(tagPanel._headerHeight + 1))
            tagGrid:SetPoint('RIGHT', tagPanel.frame, 'RIGHT', Pixel.Scale(-1), 0)

            RebuildCustomTagGrid = function()
                tagGrid:ClearRows()
                local unitSettings = settings[selectedUnit]
                if not unitSettings then settings[selectedUnit] = {}; unitSettings = settings[selectedUnit] end
                unitSettings.customTags = unitSettings.customTags or {}

                for index, entry in ipairs(unitSettings.customTags) do
                    local name = (entry.name and entry.name ~= '') and entry.name or ('Tag ' .. index)
                    local anchor = anchorNames[entry.point or 'CENTER'] or 'Center'
                    local tag = entry.tag or ''
                    local previewText = ''
                    if tag ~= '' and UnitFrames.ParsePreviewTags then
                        previewText = UnitFrames.ParsePreviewTags(tag)
                    end
                    local status = (entry.enabled ~= false)
                        and { text = 'On', color = 'active' }
                        or  { text = 'Off', color = 'inactive' }

                    tagGrid:AddRow({ name, anchor, tag, previewText, status }, { index = index })
                end
                tagPanel:Refresh()
            end

            RebuildCustomTagGrid()
            UpdatePreview()
        end)

        LazyBuild(page:GetTab(4), function() BuildUnitSettings(page:GetTab(4), "player") end)
        SyncableBuild(page:GetTab(5), "target")
        LazyBuild(page:GetTab(6), function() BuildUnitSettings(page:GetTab(6), "targettarget") end)
        LazyBuild(page:GetTab(7), function() BuildUnitSettings(page:GetTab(7), "focus") end)
        SyncableBuild(page:GetTab(8), "pet")
        LazyBuild(page:GetTab(10), function() BuildFiltersTab(page:GetTab(10), RefreshAurasOnly) end)

        local bossTab = page:GetTab(9)
        LazyBuild(bossTab, function()
            local PageKit = BUILib.PageKit
            local bossGrid = BuildUnitSettings(bossTab, "boss")
            local Section, AddRow = bossGrid.Section, bossGrid.AddRow
            local bossSettings = settings.boss

            Section('Stacking')

            AddRow({
                spanFull = true,
                title = 'Stacking',
                description = 'How the five boss frames stack.',
                controlWidth = 170,
                control = function(row)
                    return Controls.Dropdown(row, nil, {{value="DOWN", text="Down (1 at top)"},{value="UP", text="Up (1 at bottom)"}}, bossSettings.growthDirection, function(value) settings.boss.growthDirection = value; RefreshFrames() end, nil, 160)
                end,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.PositionIcon(row, { title = 'STACKING', tooltip = 'Spacing between frames', options = {
                        { kind = 'slider', label = 'Spacing', min = 0, max = 100,
                          get = function() return bossSettings.spacing end,
                          set = function(value) settings.boss.spacing = value; RefreshFrames() end },
                    } }) }
                end,
            })

            local bossAnchorPoints = BUI.C.ANCHOR_POINT_OPTIONS
            local bossGrowthItems = { { value = "LEFT", text = "Left" }, { value = "RIGHT", text = "Right" } }
            local bossVerticalGrowthItems = { { value = "UP", text = "Up" }, { value = "DOWN", text = "Down" } }
            local bossStackPositionItems = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
            local bossSortMethodItems = BUI.AuraEngine.SortMethodItems()

            Section('Auras')

            AddRow({
                spanFull = true,
                title = 'Boss Debuffs',
                description = 'Debuff icons attached to each boss frame.',
                checked = bossSettings.showDebuffs == true,
                callback = function(value) settings.boss.showDebuffs = value; RefreshFrames() end,
                accessoryWidth = 240,
                accessories = function(row)
                    local mover = PageKit.PositionIcon(row, { title = 'DEBUFF POSITION', options = {
                        { kind = 'dropdown', label = 'Anchor Point', items = bossAnchorPoints, controlWidth = 120,
                          get = function() return bossSettings.debuffAnchorPoint end,
                          set = function(value)
                              settings.boss.debuffAnchorPoint = value
                              if string.find(value, "RIGHT") then settings.boss.debuffGrowthX = "LEFT" elseif string.find(value, "LEFT") then settings.boss.debuffGrowthX = "RIGHT" end
                              if string.find(value, "TOP") then settings.boss.debuffGrowthY = "UP" elseif string.find(value, "BOTTOM") then settings.boss.debuffGrowthY = "DOWN" end
                              RefreshFrames()
                          end },
                        { kind = 'dropdown', label = 'Growth Direction', items = bossGrowthItems, controlWidth = 120,
                          get = function() return bossSettings.debuffGrowthX end,
                          set = function(value) settings.boss.debuffGrowthX = value; RefreshFrames() end },
                        { kind = 'dropdown', label = 'Vertical Growth', items = bossVerticalGrowthItems, controlWidth = 120,
                          get = function() return bossSettings.debuffGrowthY end,
                          set = function(value) settings.boss.debuffGrowthY = value; RefreshFrames() end },
                        { kind = 'slider', label = 'X Offset', min = -500, max = 500,
                          get = function() return bossSettings.debuffOffsetX end,
                          set = function(value) settings.boss.debuffOffsetX = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Y Offset', min = -500, max = 500,
                          get = function() return bossSettings.debuffOffsetY end,
                          set = function(value) settings.boss.debuffOffsetY = value; RefreshAurasOnly() end },
                    } })
                    local size = PageKit.SizeIcon(row, { title = 'DEBUFF SIZE', options = {
                        { kind = 'slider', label = 'Icon Size', min = 12, max = 80,
                          get = function() return bossSettings.debuffIconSize or bossSettings.auraIconSize end,
                          set = function(value) settings.boss.debuffIconSize = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Spacing', min = 0, max = 10,
                          get = function() return bossSettings.debuffSpacing or bossSettings.auraSpacing end,
                          set = function(value) settings.boss.debuffSpacing = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Max Icons', min = 1, max = 16,
                          get = function() return bossSettings.maxDebuffs end,
                          set = function(value) settings.boss.maxDebuffs = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Per Row', min = 1, max = 16,
                          get = function() return bossSettings.debuffsPerRow end,
                          set = function(value) settings.boss.debuffsPerRow = value; RefreshAurasOnly() end },
                    } })
                    local cog = PageKit.SettingsIcon(row, { title = 'BOSS DEBUFFS', tooltip = 'Swipe, type color & text', options = {
                        { label = 'Reverse Swipe',
                          get = function() return bossSettings.auraReverseSwipe == true end,
                          set = function(value) settings.boss.auraReverseSwipe = value; RefreshFrames() end },
                        { label = 'Color by Type',
                          get = function() return bossSettings.showDebuffType ~= false end,
                          set = function(value) settings.boss.showDebuffType = value; RefreshFrames() end },
                        { kind = 'dropdown', label = 'Sort By', items = bossSortMethodItems, controlWidth = 120,
                          get = function() return bossSettings.debuffSortMethod end,
                          set = function(value) settings.boss.debuffSortMethod = value; RefreshAurasOnly() end },
                        { label = 'Show Stack Count',
                          get = function() return ResolveShow(bossSettings.debuffShowStack, bossSettings.auraShowStack) end,
                          set = function(value) settings.boss.debuffShowStack = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Stack Size', min = 6, max = 32,
                          get = function() return bossSettings.debuffStackSize or bossSettings.auraStackSize end,
                          set = function(value) settings.boss.debuffStackSize = value; RefreshAurasOnly() end },
                        { kind = 'dropdown', label = 'Stack Position', items = bossStackPositionItems, controlWidth = 120,
                          get = function() return bossSettings.debuffStackPos end,
                          set = function(value) settings.boss.debuffStackPos = value; RefreshAurasOnly() end },
                        { label = 'Show CD Text',
                          get = function() return ResolveShow(bossSettings.debuffShowCd, bossSettings.auraShowCd) end,
                          set = function(value) settings.boss.debuffShowCd = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'CD Size', min = 6, max = 32,
                          get = function() return bossSettings.debuffCdSize or bossSettings.auraCdSize end,
                          set = function(value) settings.boss.debuffCdSize = value; RefreshAurasOnly() end },
                    } })
                    local rules = BUI.AuraRuleEditor(row, {
                        getRules = function()
                            settings.boss = settings.boss
                            return BUI.UnitFrames.GetAuraRules(settings.boss, true)
                        end,
                        polarity = 'HARMFUL', unitFramesOnly = true,
                        onChanged = RefreshFrames,
                    })
                    return { mover, size, cog, rules }
                end,
            })

            AddRow({
                spanFull = true,
                title = 'Boss Buffs',
                description = 'Buff icons attached to each boss frame.',
                checked = bossSettings.showBuffs == true,
                callback = function(value) settings.boss.showBuffs = value; RefreshFrames() end,
                accessoryWidth = 240,
                accessories = function(row)
                    local mover = PageKit.PositionIcon(row, { title = 'BUFF POSITION', options = {
                        { kind = 'dropdown', label = 'Anchor Point', items = bossAnchorPoints, controlWidth = 120,
                          get = function() return bossSettings.buffAnchorPoint or "BOTTOMLEFT" end,
                          set = function(value)
                              settings.boss.buffAnchorPoint = value
                              if string.find(value, "RIGHT") then settings.boss.buffGrowthX = "LEFT" elseif string.find(value, "LEFT") then settings.boss.buffGrowthX = "RIGHT" end
                              if string.find(value, "TOP") then settings.boss.buffGrowthY = "UP" elseif string.find(value, "BOTTOM") then settings.boss.buffGrowthY = "DOWN" end
                              RefreshFrames()
                          end },
                        { kind = 'dropdown', label = 'Growth Direction', items = bossGrowthItems, controlWidth = 120,
                          get = function() return bossSettings.buffGrowthX or "RIGHT" end,
                          set = function(value) settings.boss.buffGrowthX = value; RefreshFrames() end },
                        { kind = 'dropdown', label = 'Vertical Growth', items = bossVerticalGrowthItems, controlWidth = 120,
                          get = function() return bossSettings.buffGrowthY or "DOWN" end,
                          set = function(value) settings.boss.buffGrowthY = value; RefreshFrames() end },
                        { kind = 'slider', label = 'X Offset', min = -500, max = 500,
                          get = function() return bossSettings.buffOffsetX or 0 end,
                          set = function(value) settings.boss.buffOffsetX = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Y Offset', min = -500, max = 500,
                          get = function() return bossSettings.buffOffsetY or -4 end,
                          set = function(value) settings.boss.buffOffsetY = value; RefreshAurasOnly() end },
                    } })
                    local size = PageKit.SizeIcon(row, { title = 'BUFF SIZE', options = {
                        { kind = 'slider', label = 'Icon Size', min = 12, max = 80,
                          get = function() return bossSettings.buffIconSize or bossSettings.auraIconSize end,
                          set = function(value) settings.boss.buffIconSize = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Spacing', min = 0, max = 10,
                          get = function() return bossSettings.buffSpacing or bossSettings.auraSpacing end,
                          set = function(value) settings.boss.buffSpacing = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Max Icons', min = 1, max = 16,
                          get = function() return bossSettings.maxBuffs end,
                          set = function(value) settings.boss.maxBuffs = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Per Row', min = 1, max = 16,
                          get = function() return bossSettings.buffsPerRow or 8 end,
                          set = function(value) settings.boss.buffsPerRow = value; RefreshAurasOnly() end },
                    } })
                    local cog = PageKit.SettingsIcon(row, { title = 'BOSS BUFFS', tooltip = 'Stack & cooldown text', options = {
                        { kind = 'dropdown', label = 'Sort By', items = bossSortMethodItems, controlWidth = 120,
                          get = function() return bossSettings.buffSortMethod or 'default' end,
                          set = function(value) settings.boss.buffSortMethod = value; RefreshAurasOnly() end },
                        { label = 'Show Stack Count',
                          get = function() return ResolveShow(bossSettings.buffShowStack, bossSettings.auraShowStack) end,
                          set = function(value) settings.boss.buffShowStack = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'Stack Size', min = 6, max = 32,
                          get = function() return bossSettings.buffStackSize or bossSettings.auraStackSize end,
                          set = function(value) settings.boss.buffStackSize = value; RefreshAurasOnly() end },
                        { kind = 'dropdown', label = 'Stack Position', items = bossStackPositionItems, controlWidth = 120,
                          get = function() return bossSettings.buffStackPos or "BOTTOMRIGHT" end,
                          set = function(value) settings.boss.buffStackPos = value; RefreshAurasOnly() end },
                        { label = 'Show CD Text',
                          get = function() return ResolveShow(bossSettings.buffShowCd, bossSettings.auraShowCd) end,
                          set = function(value) settings.boss.buffShowCd = value; RefreshAurasOnly() end },
                        { kind = 'slider', label = 'CD Size', min = 6, max = 32,
                          get = function() return bossSettings.buffCdSize or bossSettings.auraCdSize end,
                          set = function(value) settings.boss.buffCdSize = value; RefreshAurasOnly() end },
                    } })
                    local rules = BUI.AuraRuleEditor(row, {
                        getRules = function()
                            settings.boss = settings.boss
                            return BUI.UnitFrames.GetAuraRules(settings.boss, false)
                        end,
                        polarity = 'HELPFUL', unitFramesOnly = true,
                        onChanged = RefreshFrames,
                    })
                    return { mover, size, cog, rules }
                end,
            })

            local CastBar = BUI.CastBar
            local castBarSettings = CastBar and CastBar.GetSettings and CastBar.GetSettings('boss')
            if castBarSettings then
                local function RefreshBossCastBar()
                    RefreshFrames()
                    if UnitFrames and UnitFrames.IsPreviewShown and UnitFrames.IsPreviewShown('boss') then UnitFrames.ShowBossCastbarPreview() end
                end

                Section('Cast Bar')

                AddRow({
                    title = 'Cast Bar',
                    description = 'Cast bar on each boss frame.',
                    checked = castBarSettings.enabled,
                    callback = function(value) castBarSettings.enabled = value; RefreshBossCastBar() end,
                    accessoryWidth = 36,
                    accessories = function(row)
                        return { PageKit.SizeIcon(row, { title = 'CAST BAR', options = {
                            { kind = 'slider', label = 'Height', min = 4, max = 50,
                              get = function() return castBarSettings.height end,
                              set = function(value) castBarSettings.height = value; RefreshBossCastBar() end },
                            { kind = 'slider', label = 'Border Size', min = 0, max = 5,
                              get = function() return castBarSettings.borderSize end,
                              set = function(value) castBarSettings.borderSize = value; RefreshBossCastBar() end },
                            { kind = 'dropdown', label = 'Bar Strata', items = BUI.C.STRATA_OPTIONS, controlWidth = 120,
                              get = function() return castBarSettings.frameStrata end,
                              set = function(value) castBarSettings.frameStrata = value; RefreshBossCastBar() end },
                        } }) }
                    end,
                })

                AddRow({
                    title = 'Icon',
                    description = 'Spell icon beside the bar.',
                    checked = castBarSettings.showIcon,
                    callback = function(value) castBarSettings.showIcon = value; RefreshBossCastBar() end,
                })

                AddRow({
                    title = 'Texture',
                    description = 'Bar fill texture.',
                    controlWidth = 170,
                    control = function(row)
                        return Controls.Dropdown(row, nil, BUI.BuildTextureDropdownItems("GLOBAL"), castBarSettings.texture, function(value) castBarSettings.texture = value; RefreshBossCastBar() end, nil, 160)
                    end,
                })

                AddRow({
                    title = 'Text',
                    description = 'Timer, spell name and size.',
                    plain = true,
                    accessoryWidth = 36,
                    accessories = function(row)
                        return { PageKit.SettingsIcon(row, { title = 'CAST BAR TEXT', tooltip = 'Text display options', options = {
                            { label = 'Show Timer',
                              get = function() return castBarSettings.showTimer end,
                              set = function(value) castBarSettings.showTimer = value; RefreshBossCastBar() end },
                            { label = 'Show Total Time',
                              get = function() return castBarSettings.showTotalTime ~= false end,
                              set = function(value) castBarSettings.showTotalTime = value; RefreshBossCastBar() end },
                            { label = 'Countdown',
                              get = function() return castBarSettings.countdown ~= false end,
                              set = function(value) castBarSettings.countdown = value; RefreshBossCastBar() end },
                            { label = 'Show Spell Name',
                              get = function() return castBarSettings.showSpellName end,
                              set = function(value) castBarSettings.showSpellName = value; RefreshBossCastBar() end },
                            { kind = 'slider', label = 'Name Max Length', min = 0, max = 30,
                              get = function() return castBarSettings.spellNameMaxLength or 0 end,
                              set = function(value) castBarSettings.spellNameMaxLength = value > 0 and value or nil; RefreshBossCastBar() end },
                            { kind = 'slider', label = 'Text Size', min = 8, max = 24,
                              get = function() return castBarSettings.textSize end,
                              set = function(value) castBarSettings.textSize = value; RefreshBossCastBar() end },
                        } }) }
                    end,
                })

                AddRow({
                    title = 'Colors',
                    description = 'Bar and border.',
                    plain = true,
                    accessoryWidth = 64,
                    accessories = function(row)
                        local barSwatch = Controls.ColorSwatch(row, { r=castBarSettings.barColor[1], g=castBarSettings.barColor[2], b=castBarSettings.barColor[3], a=castBarSettings.barColor[4], tooltip='Bar', callback=function(red, green, blue, alpha) castBarSettings.barColor = {red,green,blue,alpha}; RefreshBossCastBar() end })
                        local borderSwatch = Controls.ColorSwatch(row, { r=castBarSettings.borderColor[1], g=castBarSettings.borderColor[2], b=castBarSettings.borderColor[3], a=castBarSettings.borderColor[4], tooltip='Border', callback=function(red, green, blue, alpha) castBarSettings.borderColor = {red,green,blue,alpha}; RefreshBossCastBar() end })
                        return { barSwatch, borderSwatch }
                    end,
                })

                castBarSettings.bossColors = castBarSettings.bossColors
                AddRow({
                    spanFull = true,
                    title = 'Per-Boss Colors',
                    description = 'A distinct bar color for each boss.',
                    checked = castBarSettings.useIndividualColors,
                    callback = function(value) castBarSettings.useIndividualColors = value; RefreshBossCastBar() end,
                    accessoryWidth = 160,
                    accessories = function(row)
                        local out = {}
                        for bossIndex = 5, 1, -1 do
                            local bossColor = castBarSettings.bossColors[bossIndex]
                            if not bossColor then
                                bossColor = { 0.8, 0.2, 0.2, 1.0 }
                                castBarSettings.bossColors[bossIndex] = bossColor
                            end
                            if bossColor[4] == nil then bossColor[4] = 1 end
                            out[#out + 1] = Controls.ColorSwatch(row, { r=bossColor[1], g=bossColor[2], b=bossColor[3], a=bossColor[4], tooltip='Boss ' .. bossIndex, callback=function(red, green, blue, alpha) castBarSettings.bossColors[bossIndex] = {red,green,blue,alpha}; RefreshBossCastBar() end })
                        end
                        return out
                    end,
                })

                if castBarSettings.interruptColor then
                    Section('Interrupts')

                    AddRow({
                        spanFull = true,
                        title = 'Cast Colors',
                        description = 'Bar color by interrupt state.',
                        plain = true,
                        accessoryWidth = 230,
                        accessories = function(row)
                            local interruptColor = castBarSettings.interruptColor
                            local interruptSwatch = Controls.ColorSwatch(row, { r=interruptColor[1], g=interruptColor[2], b=interruptColor[3], a=interruptColor[4], tooltip='Non-interruptible', callback=function(red, green, blue, alpha) castBarSettings.interruptColor = {red,green,blue,alpha}; RefreshBossCastBar() end })
                            local interruptOnCooldownColor = castBarSettings.interruptOnCDColor
                            local cooldownSwatch = Controls.ColorSwatch(row, { r=interruptOnCooldownColor[1], g=interruptOnCooldownColor[2], b=interruptOnCooldownColor[3], a=interruptOnCooldownColor[4], tooltip='Interrupt on cooldown', callback=function(red, green, blue, alpha) castBarSettings.interruptOnCDColor = {red,green,blue,alpha}; RefreshBossCastBar() end })
                            local readyColor = castBarSettings.interruptReadyColor
                            local readySwatch = Controls.ColorSwatch(row, { r=readyColor[1], g=readyColor[2], b=readyColor[3], a=readyColor[4], tooltip='Can interrupt', callback=function(red, green, blue, alpha) castBarSettings.interruptReadyColor = {red,green,blue,alpha}; RefreshBossCastBar() end })
                            local windowColor = castBarSettings.interruptWindowColor
                            local windowSwatch = Controls.ColorSwatch(row, { r=windowColor[1], g=windowColor[2], b=windowColor[3], a=windowColor[4], tooltip='Interrupt soon', callback=function(red, green, blue, alpha) castBarSettings.interruptWindowColor = {red,green,blue,alpha}; RefreshBossCastBar() end })
                            local preview = Controls.GhostButton(row, 'Preview', 90, function() CastBar.PreviewInterrupt('boss') end)
                            return { preview, windowSwatch, readySwatch, cooldownSwatch, interruptSwatch }
                        end,
                    })

                    AddRow({
                        title = 'Ready Line',
                        description = 'Line marking when your kick is back up.',
                        checked = castBarSettings.interruptTick ~= false,
                        callback = function(value) castBarSettings.interruptTick = value; RefreshBossCastBar() end,
                        accessoryWidth = 64,
                        accessories = function(row)
                            local cog = PageKit.SettingsIcon(row, { title = 'READY LINE', tooltip = 'Line width & window', options = {
                                { kind = 'slider', label = 'Line Width', min = 1, max = 6,
                                  get = function() return castBarSettings.interruptTickWidth end,
                                  set = function(value) castBarSettings.interruptTickWidth = value; RefreshBossCastBar() end },
                                { label = 'Show Interrupt Window',
                                  get = function() return castBarSettings.interruptWindow ~= false end,
                                  set = function(value) castBarSettings.interruptWindow = value; RefreshBossCastBar() end },
                            } })
                            local tickColor = castBarSettings.interruptTickColor
                            local swatch = Controls.ColorSwatch(row, { r=tickColor[1], g=tickColor[2], b=tickColor[3], a=tickColor[4], tooltip='Ready line color', callback=function(red, green, blue, alpha) castBarSettings.interruptTickColor = {red,green,blue,alpha}; RefreshBossCastBar() end })
                            return { cog, swatch }
                        end,
                    })
                end
            end

            bossGrid.Flush()
            bossGrid:SyncDim((settings.boss and settings.boss.enabled) ~= false)
        end)

        page:AutoRefresh()
    end,
    OnHide = function()
        BUI.UnitFrames.LockAllPreviews()
        BUI.CastBar.StopInterruptPreview('boss')
        BUI.UnitFrames.UnpinDispelPreview()
    end,
})
