local _, BUI = ...
local Pixel   = BUI.Pixel
local Painter = BUI.Painter
local Skin    = BUI.Skinning

local BUILib = BluUI.BUILibClient
local Colors = BUILib.Colors
local FONT   = BUILib.Font

local PANEL_W    = 300
local ROW_H      = 34
local ROW_GAP    = 4
local ICON_SIZE  = 26
local LEVEL_W    = 40
local TIME_W     = 104
local LIST_TOP   = 96
local DROPDOWN_W = 170
local FILL_ALPHA = 0.45
local COUNTDOWN_SIZE = 11
local PARTY_SETTING = 'portalManagerPartyKeys'
local PARTY_LABEL = 'Party Keys'
local NO_KEY_TEXT = 'No key'
local KEYSTONE_ICON = 'Interface\\Icons\\INV_Relics_Hourglass'

local CHEST_COLORS = {
    [0] = { 0.6, 0.6, 0.6 },
    [1] = { 1, 0.6, 0.25 },
    [2] = { 1, 0.82, 0 },
    [3] = { 1, 0.45, 0 },
}

BUI.PortalManager = {}

local function PartyEnabled()
    return BUI.GetDB().skinning[PARTY_SETTING] ~= false
end

function BUI.PortalManager.ShowsPartyKeys()
    return PartyEnabled()
end

local context = Skin.Define('portalManager', {
    name = 'Portal Manager',
    description = 'Dungeon and raid portals beside the Character frame and the Premade Groups list.',
    icon = 'Interface\\Icons\\Spell_Arcane_PortalDalaran',
    newLook = true,
    settings = {
        {
            label = "Show the party's keys",
            get = PartyEnabled,
            set = function(value)
                BUI.GetDB().skinning[PARTY_SETTING] = value
                BUI.PortalManager.RefreshLists()
                local reminder = BUI.Auras and BUI.Auras.KeystoneReminder
                if reminder then reminder.Refresh() end
            end,
        },
    },
})

local panel, slide
local host, hostOptions
local rows = {}
local lists, activeList
local mapIDByName, timeLimitByMap = {}, {}
local castingRow, castingSpellID, castStart, castEnd
local RefreshContent

local function ResolveSpellID(entry)
    if entry.spellIDs then
        local fallback
        for _, spellID in ipairs(entry.spellIDs) do
            if C_SpellBook.IsSpellKnown(spellID) then return spellID end
            if not fallback and C_Spell.DoesSpellExist(spellID) then fallback = spellID end
        end
        return fallback or entry.spellIDs[1]
    end
    if entry.spellIDAlliance or entry.spellIDHorde then
        if UnitFactionGroup('player') == 'Alliance' then return entry.spellIDAlliance end
        return entry.spellIDHorde
    end
    return entry.spellID
end

local function FindEntry(name)
    for _, season in ipairs(BUI.PortalData.seasons) do
        for _, entry in ipairs(season.dungeons) do
            if entry.name == name then return entry end
        end
    end
    for _, entries in pairs(BUI.PortalData.expansions) do
        for _, entry in ipairs(entries) do
            if entry.name == name then return entry end
        end
    end
end

function BUI.PortalManager.TeleportSpell(name)
    local entry = FindEntry(name)
    return entry and ResolveSpellID(entry)
end

local function AnyEntryExists(entries)
    for _, entry in ipairs(entries) do
        if C_Spell.DoesSpellExist(ResolveSpellID(entry)) then return true end
    end
    return false
end

local function CurrentSeason()
    local seasons = BUI.PortalData.seasons
    for _, candidate in ipairs(seasons) do
        if not candidate.gateSpellID or C_Spell.DoesSpellExist(candidate.gateSpellID) then return candidate end
    end
    return seasons[#seasons]
end

local function BuildLists()
    local data = BUI.PortalData
    local built = {}
    if PartyEnabled() then built[1] = { label = PARTY_LABEL, party = true, entries = {} } end
    built[#built + 1] = { label = 'Current Season', entries = CurrentSeason().dungeons }
    for _, season in ipairs(data.seasons) do
        built[#built + 1] = { label = season.name, entries = season.dungeons }
    end
    for _, name in ipairs(data.expansionOrder) do
        local entries = data.expansions[name]
        if entries and AnyEntryExists(entries) then
            built[#built + 1] = { label = name, entries = entries }
        end
    end
    return built
end

local function RebuildMapLookup()
    wipe(mapIDByName)
    wipe(timeLimitByMap)
    for _, mapID in ipairs(C_ChallengeMode.GetMapTable()) do
        local name, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
        if name then
            mapIDByName[name] = mapID
            timeLimitByMap[mapID] = timeLimit
        end
    end
end

local function ScoreColor(score, isPreviousSeason)
    if RaiderIO and RaiderIO.GetScoreColor then
        local red, green, blue = RaiderIO.GetScoreColor(score, isPreviousSeason)
        if red then return CreateColor(red, green, blue) end
    end
    return C_ChallengeMode.GetDungeonScoreRarityColor(score)
end

local function BestRun(mapID)
    local affixScores = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapID)
    if not affixScores then return nil end
    local best
    for _, info in ipairs(affixScores) do
        if not best or info.score > best.score then best = info end
    end
    if not best then return nil end
    local timeLimit = timeLimitByMap[mapID]
    local chests = 0
    if not best.overTime and timeLimit > 0 then
        local ratio = best.durationSec / timeLimit
        chests = ratio <= 0.6 and 3 or ratio <= 0.8 and 2 or 1
    elseif not best.overTime then
        chests = 1
    end
    return {
        level = best.level,
        score = best.score,
        durationSec = best.durationSec,
        delta = timeLimit > 0 and (best.durationSec - timeLimit) or nil,
        chests = chests,
    }
end

local function DeltaText(delta)
    if not delta then return '' end
    local sign = delta < 0 and '-' or '+'
    local magnitude = math.abs(delta)
    local color = delta < 0 and '|cff4dcc4d' or '|cffcc4d4d'
    return ('%s(%s%d:%02d)|r'):format(color, sign, math.floor(magnitude / 60), magnitude % 60)
end

local castDriver = CreateFrame('Frame')
castDriver:Hide()

local function DetachCastFill()
    if castingRow then
        castingRow.castFill:Hide()
        castingRow.castEdge:Hide()
        castingRow = nil
    end
end

local function StopCastFill()
    DetachCastFill()
    castingSpellID = nil
    castDriver:Hide()
end

local function AttachCastFill(row)
    castingRow = row
    local red, green, blue = Colors.GetAccent()
    row.castFill:SetVertexColor(red, green, blue, FILL_ALPHA)
    row.castFill:SetWidth(1)
    row.castFill:Show()
    row.castEdge:Show()
end

local function RowForSpell(spellID)
    for _, row in ipairs(rows) do
        if row:IsShown() and row._spellID == spellID then return row end
    end
    return nil
end

castDriver:SetScript('OnUpdate', function()
    if not castingRow then return end
    local progress = math.min(1, (GetTime() - castStart) / (castEnd - castStart))
    castingRow.castFill:SetWidth(math.max(1, (castingRow:GetWidth() - Pixel.Scale(2)) * progress))
end)

local function StartCastFill(spellID)
    local row = RowForSpell(spellID)
    if not row then return end
    local _, _, _, startMs, endMs = UnitCastingInfo('player')
    if not startMs or endMs <= startMs then return end
    StopCastFill()
    castingSpellID, castStart, castEnd = spellID, startMs / 1000, endMs / 1000
    AttachCastFill(row)
    castDriver:Show()
end

local RowEnter = function(self)
    if not self._spellID then return end
    GameTooltip:SetOwner(self, 'ANCHOR_NONE')
    GameTooltip:SetPoint('TOPRIGHT', self, 'TOPLEFT', -6, 0)
    GameTooltip:SetSpellByID(self._spellID)
    GameTooltip:Show()
end

local function CreateRow(parent, index)
    local row = CreateFrame('Button', nil, parent, 'SecureActionButtonTemplate')
    row:SetHeight(Pixel.Scale(ROW_H))
    row:SetPoint('TOPLEFT', 0, Pixel.Scale(-(index - 1) * (ROW_H + ROW_GAP)))
    row:SetPoint('RIGHT', parent, 'RIGHT')
    row:RegisterForClicks('LeftButtonUp')
    row:SetAttribute('type', 'spell')
    row:SetAttribute('useOnKeyDown', false)
    row:SetScript('OnEnter', RowEnter)
    row:SetScript('OnLeave', GameTooltip_Hide)
    Skin.CardRow(row)

    local castFill = row:CreateTexture(nil, 'BACKGROUND', nil, 1)
    castFill:SetPoint('TOPLEFT', Pixel.Scale(1), Pixel.Scale(-1))
    castFill:SetPoint('BOTTOMLEFT', Pixel.Scale(1), Pixel.Scale(1))
    castFill:SetTexture(BUI.GetGlobalTexture())
    castFill:Hide()
    row.castFill = castFill

    local castEdge = row:CreateTexture(nil, 'BACKGROUND', nil, 2)
    castEdge:SetPoint('TOPLEFT', castFill, 'TOPRIGHT', -Pixel.PixelSize(1), 0)
    castEdge:SetPoint('BOTTOMLEFT', castFill, 'BOTTOMRIGHT', -Pixel.PixelSize(1), 0)
    castEdge:SetWidth(Pixel.PixelSize(1))
    castEdge:SetColorTexture(1, 1, 1, 0.9)
    castEdge:Hide()
    row.castEdge = castEdge

    local icon = row:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(Pixel.Scale(ICON_SIZE), Pixel.Scale(ICON_SIZE))
    icon:SetPoint('LEFT', Pixel.Scale(4), 0)
    Skin.CropIcon(icon)
    Skin.TipIconFrame(row, icon)
    row.icon = icon

    local cooldown = CreateFrame('Cooldown', nil, row, 'CooldownFrameTemplate')
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(false)
    row.cooldown = cooldown

    local time = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(time, 11, FONT, '')
    time:SetPoint('BOTTOMRIGHT', Pixel.Scale(-8), Pixel.Scale(4))
    time:SetWidth(Pixel.Scale(TIME_W))
    time:SetJustifyH('RIGHT')
    Painter.Text(time, 'skinLabel')
    row.timeText = time

    local level = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(level, 11, FONT, '')
    level:SetPoint('BOTTOMLEFT', icon, 'BOTTOMRIGHT', Pixel.Scale(8), 0)
    level:SetWidth(Pixel.Scale(LEVEL_W))
    level:SetJustifyH('LEFT')
    row.levelText = level

    local name = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(name, 11, FONT, '')
    name:SetJustifyH('LEFT')
    name:SetWordWrap(false)
    row.nameText = name
    return row
end

local function EnsureRows(count)
    if #rows >= count then return end
    if InCombatLockdown() then
        BUI.Events:AfterCombat(function() RefreshContent() end, 'PortalManager.Rows')
        return
    end
    for index = #rows + 1, count do rows[index] = CreateRow(panel.child, index) end
end

local function BuildDropdown()
    if panel.dropdown then panel.dropdown:Hide() end
    lists = BuildLists()
    activeList = lists[1]
    panel.dropdown = Skin.CreateDropdown(panel, lists, function(item)
        if InCombatLockdown() then
            panel.dropdown.label:SetText(activeList.label)
            return
        end
        activeList = item
        RefreshContent()
        panel.scroll:SetVerticalScroll(0)
    end, DROPDOWN_W)
    panel.dropdown:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-44))
end

local function BuildPanel()
    if panel then return end
    panel = Skin.CreatePanelWindow('Portals', function() slide.Close(true) end)
    BuildDropdown()

    panel.combatText = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.combatText, 11, FONT, '')
    panel.combatText:SetPoint('RIGHT', panel, 'TOPRIGHT', Pixel.Scale(-14), Pixel.Scale(-56))
    Painter.Text(panel.combatText, 'danger')
    panel.combatText:SetText('In combat')
    panel.combatText:Hide()

    panel.summaryText = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.summaryText, 10, FONT, '')
    panel.summaryText:SetPoint('TOPLEFT', Pixel.Scale(14), Pixel.Scale(-74))
    panel.summaryText:SetPoint('RIGHT', Pixel.Scale(-14), 0)
    panel.summaryText:SetJustifyH('LEFT')
    Painter.Text(panel.summaryText, 'skinLabel')

    local _
    _, panel.scroll, panel.child = Skin.CreateListArea(panel, LIST_TOP, ROW_H)
    panel:HookScript('OnHide', StopCastFill)
end

local function SortedEntries(entries)
    local sorted = {}
    for index, entry in ipairs(entries) do
        local mapID = mapIDByName[entry.name]
        sorted[index] = { entry = entry, mapID = mapID, run = mapID and BestRun(mapID), order = index }
    end
    table.sort(sorted, function(a, b)
        if (a.run ~= nil) ~= (b.run ~= nil) then return a.run ~= nil end
        if a.run and b.run then
            if a.run.level ~= b.run.level then return a.run.level > b.run.level end
            if a.run.score ~= b.run.score then return a.run.score > b.run.score end
        end
        return a.order < b.order
    end)
    return sorted
end

local function SummaryText(sorted)
    local runs, timed, bestLevel, mapCount = 0, 0, 0, 0
    for _, item in ipairs(sorted) do
        if item.mapID then mapCount = mapCount + 1 end
        if item.run then
            runs = runs + 1
            if item.run.chests > 0 then timed = timed + 1 end
            if item.run.level > bestLevel then bestLevel = item.run.level end
        end
    end
    if mapCount == 0 then return '' end

    local separator = '  ||  '
    local score = C_ChallengeMode.GetOverallDungeonScore()
    local parts = { 'Score ' .. ScoreColor(score):WrapTextInColorCode(('%d'):format(score)) }

    local profile = RaiderIO and RaiderIO.GetProfile and RaiderIO.GetProfile('player')
    local keystoneProfile = profile and profile.mythicKeystoneProfile
    local previous = keystoneProfile and keystoneProfile.previousScore
    if previous and previous > 0 then
        parts[#parts + 1] = 'Prev ' .. ScoreColor(previous, true):WrapTextInColorCode(('%d'):format(previous))
    end
    if runs > 0 then
        parts[#parts + 1] = ('Best |cffffffff+%d|r'):format(bestLevel)
        parts[#parts + 1] = ('Timed |cffffffff%d/%d|r'):format(timed, mapCount)
    end
    return table.concat(parts, separator)
end

local function StyleCountdown(cooldown)
    if cooldown._buiCountdownStyled then return end
    local text = BUI.Tools.CooldownFontString(cooldown)
    if not text then return end
    cooldown._buiCountdownStyled = true
    Pixel.ApplyFont(text, COUNTDOWN_SIZE, FONT, 'OUTLINE')
end

local function ApplyCooldown(button)
    local duration = button:IsShown() and button._known and C_Spell.GetSpellCooldownDuration(button._spellID, true)
    if duration then
        button.cooldown:SetCooldownFromDurationObject(duration)
        StyleCountdown(button.cooldown)
    else
        button.cooldown:Clear()
    end
end

local function RefreshCooldowns()
    if not panel:IsShown() then return end
    for _, row in ipairs(rows) do ApplyCooldown(row) end
end

local function PartyItems()
    local PartyKeys = BUI.PartyKeys
    local items = {}
    for _, unit in ipairs(PartyKeys.UNITS) do
        if UnitExists(unit) then
            local key = PartyKeys.ForUnit(unit)
            local level = key and key.level or 0
            local dungeon = level > 0 and C_ChallengeMode.GetMapUIInfo(key.mapID) or nil
            local classFile = select(2, UnitClass(unit))
            items[#items + 1] = {
                entry = dungeon and (FindEntry(dungeon) or { name = dungeon }) or { name = NO_KEY_TEXT },
                mapID = dungeon and key.mapID or nil,
                level = dungeon and level or nil,
                player = UnitName(unit),
                class = not issecretvalue(classFile) and classFile or nil,
                order = #items + 1,
            }
        end
    end
    table.sort(items, function(a, b)
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        return a.order < b.order
    end)
    return items
end

local function PartySummary(items)
    local reported = 0
    for _, item in ipairs(items) do
        if item.level then reported = reported + 1 end
    end
    return ('Keys reported |cffffffff%d/%d|r'):format(reported, #items)
end

local function FillRow(row, item, inCombat)
    local spellID = ResolveSpellID(item.entry)
    local known = spellID ~= nil and C_SpellBook.IsSpellInSpellBook(spellID)
    row._spellID, row._known = spellID, known
    if not inCombat then
        row:SetAttribute('spell', known and spellID or nil)
        row:Show()
    end

    row.icon:SetTexture(spellID and C_Spell.GetSpellTexture(spellID) or KEYSTONE_ICON)
    row.icon:SetDesaturated(not known)
    row.nameText:SetText(item.entry.name)
    Painter.Text(row.nameText, known and 'skinText' or 'skinLabel')

    row.nameText:ClearAllPoints()
    row.nameText:SetPoint('RIGHT', row, 'RIGHT', Pixel.Scale(-8), 0)
    if item.mapID or item.player then
        row.nameText:SetPoint('TOPLEFT', row.icon, 'TOPRIGHT', Pixel.Scale(8), Pixel.Scale(-1))
    else
        row.nameText:SetPoint('LEFT', row.icon, 'RIGHT', Pixel.Scale(8), 0)
    end

    if item.player then
        row.levelText:SetText(item.level and ('+' .. item.level) or '')
        Painter.Text(row.levelText, 'skinText')
        row.timeText:SetText(item.player)
        local color = item.class and RAID_CLASS_COLORS[item.class]
        if color then
            row.timeText:SetTextColor(color.r, color.g, color.b, 1)
        else
            Painter.Text(row.timeText, 'skinLabel')
        end
        return
    end
    Painter.Text(row.timeText, 'skinLabel')

    local run = item.run
    if run then
        local color = CHEST_COLORS[run.chests]
        row.levelText:SetText(string.rep('+', math.max(1, run.chests)) .. run.level)
        row.levelText:SetTextColor(color[1], color[2], color[3], 1)
        row.timeText:SetText(SecondsToClock(run.durationSec) .. ' ' .. DeltaText(run.delta))
    else
        row.levelText:SetText('')
        row.timeText:SetText(item.mapID and 'no run' or '')
    end
end

RefreshContent = function()
    if not panel or not panel:IsShown() then return end
    local inCombat = InCombatLockdown()
    panel.combatText:SetShown(inCombat)

    local party = activeList.party
    local sorted = party and PartyItems() or SortedEntries(activeList.entries)
    panel.summaryText:SetText(party and PartySummary(sorted) or SummaryText(sorted))
    if party then BUI.PartyKeys.Request() end
    EnsureRows(#sorted)
    local shown = math.min(#rows, #sorted)
    for index = 1, shown do FillRow(rows[index], sorted[index], inCombat) end
    if not inCombat then
        for index = shown + 1, #rows do rows[index]:Hide() end
    end
    RefreshCooldowns()

    if castingSpellID then
        local row = RowForSpell(castingSpellID)
        if row ~= castingRow then
            DetachCastFill()
            if row then AttachCastFill(row) end
        end
    end
    panel.child:SetHeight(Pixel.Scale(math.max(1, shown * (ROW_H + ROW_GAP))))
end

local ThrottledRefresh = BUI.Dispatcher.NewDelayed(function() RefreshContent() end, 0.3)
local QueueCooldowns = BUI.Dispatcher.New(RefreshCooldowns)

local function OnMapsUpdated()
    RebuildMapLookup()
    ThrottledRefresh()
end

local function OnCastStart(_, _, _, spellID)
    StartCastFill(spellID)
end

local function OnCastEnd()
    if castingSpellID then StopCastFill() end
end

local EVENTS = {
    SPELL_UPDATE_COOLDOWN = QueueCooldowns,
    SPELLS_CHANGED = ThrottledRefresh,
    CHALLENGE_MODE_MAPS_UPDATE = OnMapsUpdated,
    PLAYER_REGEN_ENABLED = ThrottledRefresh,
    PLAYER_REGEN_DISABLED = ThrottledRefresh,
    GROUP_ROSTER_UPDATE = ThrottledRefresh,
}
local CAST_EVENTS = {
    UNIT_SPELLCAST_START = OnCastStart,
    UNIT_SPELLCAST_STOP = OnCastEnd,
    UNIT_SPELLCAST_SUCCEEDED = OnCastEnd,
    UNIT_SPELLCAST_INTERRUPTED = OnCastEnd,
    UNIT_SPELLCAST_FAILED = OnCastEnd,
}

local function ListenWhileOpen(open)
    for event, handler in pairs(EVENTS) do
        if open then BUI.Events:Register(event, 'PortalManager', handler) else BUI.Events:Unregister(event, 'PortalManager') end
    end
    for event, handler in pairs(CAST_EVENTS) do
        if open then BUI.Events:RegisterUnit(event, 'player', 'PortalManager', handler) else BUI.Events:Unregister(event, 'PortalManager') end
    end
end

local STRIP = { icon = 36, levelSize = 12, nameSize = 9 }
local SHORT_SKIP = { of = true, the = true, ['and'] = true }
local strip
local stripButtons = {}
local RefreshStrip

local function StripPitch()
    return Pixel.Scale(STRIP.icon) - Pixel.PixelSize(1)
end

local function ShortName(entry)
    if entry.short then return entry.short end
    local letters = ''
    for word in entry.name:gmatch('%a+') do
        if not SHORT_SKIP[word:lower()] then letters = letters .. word:sub(1, 1):upper() end
    end
    return letters
end

local function CogConfig(settings)
    return {
        icon = 'cog', size = 20, iconScale = 0.7, idleColor = { Painter.Color('skinLabel') },
        tooltip = 'Portal options', title = 'Portals', width = 220, options = settings,
    }
end

local function FillSettings(target, source)
    wipe(target)
    for index, option in ipairs(source) do target[index] = option end
end

local function StripEntries()
    local entries = {}
    for index, entry in ipairs(CurrentSeason().dungeons) do entries[index] = entry end
    table.sort(entries, function(a, b) return a.name < b.name end)
    return entries
end

local function StripEnter(button)
    GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
    GameTooltip:SetText(button._name, 1, 1, 1)
    local run = button._run
    if run then
        local color = CHEST_COLORS[run.chests]
        GameTooltip:AddLine(('+%d  %s %s'):format(run.level, SecondsToClock(run.durationSec), DeltaText(run.delta)), color[1], color[2], color[3])
    elseif button._mapID then
        GameTooltip:AddLine('No run this season', 0.6, 0.6, 0.6)
    end
    if not button._known then GameTooltip:AddLine('Teleport not learned', 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

local function CreateStripButton(index)
    local button = CreateFrame('Button', nil, strip, 'SecureActionButtonTemplate')
    button:SetSize(Pixel.Scale(STRIP.icon), Pixel.Scale(STRIP.icon))
    button:SetPoint('TOP', 0, -(index - 1) * StripPitch())
    button:RegisterForClicks('LeftButtonUp')
    button:SetAttribute('type', 'spell')
    button:SetAttribute('useOnKeyDown', false)
    button:SetScript('OnEnter', StripEnter)
    button:SetScript('OnLeave', GameTooltip_Hide)

    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:SetPoint('TOPLEFT', Pixel.PixelSize(1), -Pixel.PixelSize(1))
    icon:SetPoint('BOTTOMRIGHT', -Pixel.PixelSize(1), Pixel.PixelSize(1))
    Skin.SquareIcon(button, icon, 1)
    button.icon = icon

    local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(false)
    button.cooldown = cooldown

    local plate = CreateFrame('Frame', nil, button)
    plate:SetAllPoints(icon)
    plate:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    local level = plate:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(level, STRIP.levelSize, FONT, 'OUTLINE')
    level:SetPoint('BOTTOMRIGHT', Pixel.Scale(-2), Pixel.Scale(1))
    button.levelText = level

    local name = plate:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(name, STRIP.nameSize, FONT, 'OUTLINE')
    name:SetPoint('TOPLEFT', Pixel.Scale(2), Pixel.Scale(-1))
    Painter.Text(name, 'skinTitle')
    button.nameText = name
    return button
end

local function FillStripButton(button, entry, inCombat)
    local spellID = ResolveSpellID(entry)
    local known = spellID ~= nil and C_SpellBook.IsSpellInSpellBook(spellID)
    local mapID = mapIDByName[entry.name]
    local run = mapID and BestRun(mapID)
    button._spellID, button._known, button._name, button._mapID, button._run = spellID, known, entry.name, mapID, run
    if not inCombat then
        button:SetAttribute('spell', known and spellID or nil)
        button:Show()
    end
    button.icon:SetTexture(spellID and C_Spell.GetSpellTexture(spellID) or KEYSTONE_ICON)
    button.icon:SetDesaturated(not known)
    button.nameText:SetText(ShortName(entry))
    if run and strip.options.levels() then
        local color = CHEST_COLORS[run.chests]
        button.levelText:SetText('+' .. run.level)
        button.levelText:SetTextColor(color[1], color[2], color[3], 1)
    else
        button.levelText:SetText('')
    end
    ApplyCooldown(button)
end

RefreshStrip = function()
    if not strip or not strip:IsShown() then return end
    local inCombat = InCombatLockdown()
    local entries = StripEntries()
    if #stripButtons < #entries then
        if inCombat then
            BUI.Events:AfterCombat(RefreshStrip, 'PortalManager.Strip')
            return
        end
        for index = #stripButtons + 1, #entries do stripButtons[index] = CreateStripButton(index) end
    end
    for index, entry in ipairs(entries) do FillStripButton(stripButtons[index], entry, inCombat) end
    if not inCombat then
        for index = #entries + 1, #stripButtons do stripButtons[index]:Hide() end
    end
    strip.cog:ClearAllPoints()
    strip.cog:SetPoint('TOP', 0, -(#entries * StripPitch()))
    strip:SetSize(Pixel.Scale(STRIP.icon), (#entries + 1) * StripPitch() + Pixel.PixelSize(1))
end

local function RefreshStripCooldowns()
    if not strip or not strip:IsShown() then return end
    for _, button in ipairs(stripButtons) do ApplyCooldown(button) end
end

local QueueStrip = BUI.Dispatcher.New(RefreshStrip)
local QueueStripCooldowns = BUI.Dispatcher.New(RefreshStripCooldowns)

local STRIP_EVENTS = {
    SPELL_UPDATE_COOLDOWN = QueueStripCooldowns,
    SPELLS_CHANGED = QueueStrip,
    PLAYER_REGEN_ENABLED = QueueStrip,
    CHALLENGE_MODE_MAPS_UPDATE = function()
        RebuildMapLookup()
        QueueStrip()
    end,
}

local function SyncPanelCog()
    if not panel then return end
    if not hostOptions then
        if panel.cog then panel.cog:Hide() end
        return
    end
    if not panel.cog then
        panel.settings = {}
        panel.cog = BUILib.Controls.Icon(panel, CogConfig(panel.settings)).frame
        panel.cog:SetPoint('RIGHT', panel.titleBar.closeBtn.frame, 'LEFT', Pixel.Scale(-4), 0)
        panel.cog:SetFrameLevel(panel:GetFrameLevel() + 10)
    end
    FillSettings(panel.settings, hostOptions.settings)
    panel.cog:Show()
end

local function Undock()
    host, hostOptions = nil, nil
    SyncPanelCog()
end

slide = BUI.SlidePanel.New({
    skin = 'portalManager',
    width = PANEL_W,
    hiddenX = -PANEL_W,
    anchor = function() return host end,
    panel = function() return panel end,
    build = BuildPanel,
    onOpen = function()
        ListenWhileOpen(true)
        BUI.PartyKeys.Listen('PortalManager', ThrottledRefresh)
        C_MythicPlus.RequestMapInfo()
        RebuildMapLookup()
        RefreshContent()
        panel.scroll:SetVerticalScroll(0)
        SyncPanelCog()
    end,
    onClose = function()
        ListenWhileOpen(false)
        BUI.PartyKeys.Listen('PortalManager', nil)
        StopCastFill()
        if hostOptions then hostOptions.onClosed() end
    end,
})

function BUI.PortalManager.RefreshLists()
    if not panel then return end
    BuildDropdown()
    RefreshContent()
    if panel:IsShown() then panel.scroll:SetVerticalScroll(0) end
end

function BUI.PortalManager.Toggle()
    local docked = host ~= nil
    Undock()
    if docked and slide.IsOpen() then
        slide.Refit()
        return
    end
    slide.Toggle()
end

function BUI.PortalManager.IsOpen()
    return slide.IsOpen()
end

function BUI.PortalManager.OpenBeside(frame, options)
    host, hostOptions = frame, options
    if slide.IsOpen() then slide.Refit() else slide.Open() end
    SyncPanelCog()
end

function BUI.PortalManager.CloseBeside(frame)
    if host ~= frame then return end
    Undock()
    if slide.IsOpen() then slide.Close(true) end
end

function BUI.PortalManager.RefreshStrip()
    RefreshStrip()
end

function BUI.PortalManager.ShowStrip(parent, options)
    if not BUI.Skinning.IsSkinEnabled('portalManager') then return end
    if not strip then
        strip = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
        Skin.PaintBackdrop(strip, Skin.PALETTE.panel)
        strip.cog = CreateFrame('Frame', nil, strip, 'BackdropTemplate')
        strip.cog:SetSize(Pixel.Scale(STRIP.icon), Pixel.Scale(STRIP.icon))
        Skin.PaintBackdrop(strip.cog, Skin.PALETTE.panel)
        strip.settings = {}
        BUILib.Controls.Icon(strip.cog, CogConfig(strip.settings)).frame:SetPoint('CENTER')
    end
    strip.options = options
    FillSettings(strip.settings, options.settings)
    strip:SetParent(parent)
    strip:ClearAllPoints()
    strip:SetPoint('TOPLEFT', parent, 'TOPRIGHT', -Pixel.PixelSize(1), 0)
    strip:Show()
    for event, handler in pairs(STRIP_EVENTS) do BUI.Events:Register(event, 'PortalManager.Strip', handler) end
    C_MythicPlus.RequestMapInfo()
    RebuildMapLookup()
    RefreshStrip()
end

function BUI.PortalManager.HideStrip()
    if not strip then return end
    for event in pairs(STRIP_EVENTS) do BUI.Events:Unregister(event, 'PortalManager.Strip') end
    strip:Hide()
end

CharacterFrame:HookScript('OnHide', function()
    if not host then slide.Close(true) end
end)
context.OnDisable(function()
    Undock()
    slide.Close(true)
    BUI.PortalManager.HideStrip()
end)
