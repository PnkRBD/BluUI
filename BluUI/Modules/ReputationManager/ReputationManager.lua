local _, BUI = ...
local PoolGet, PoolHideFrom = BUI.Tools.PoolGet, BUI.Tools.PoolHideFrom
local Pixel = BUI.Pixel
local Painter = BUI.Painter
local Skin = BUI.Skinning

local BUILib = BluUI.BUILibClient
local Widget   = BUILib.Widget
local Controls = BUILib.Controls
local FONT     = BUILib.Font

local PANEL_W  = 380
local ROW_H    = 32
local ROW_GAP  = 4
local HEADER_H = 22
local BAR_H    = 2

local MAX_STANDING = 8

local RENOWN_COLOR     = { 0.4, 0.7, 1 }
local PARAGON_COLOR    = { 1, 0.82, 0 }
local FRIENDSHIP_COLOR = { 0.2, 0.85, 0.55 }
local WARBAND_COLOR    = { 0.55, 0.85, 1 }
local STANDING_COLORS  = {}
for reaction = 1, MAX_STANDING do
    local color = FACTION_BAR_COLORS[reaction]
    STANDING_COLORS[reaction] = { color.r, color.g, color.b }
end

local context = Skin.Define('reputationManager', {
    name = 'Reputation Manager',
    description = 'Faction list beside the Character frame.',
    icon = 'Interface\\Icons\\Achievement_Reputation_01',
    newLook = true,
})

BUI.ReputationManager = {}

local panel, slide
local journeyPanel
local rowPool, headerPool = {}, {}
local searchText = ''
local RefreshContent

local function StandingLabel(reaction)
    return GetText('FACTION_STANDING_LABEL' .. reaction, UnitSex('player'))
end

local function MajorFactionData(factionID)
    if not C_Reputation.IsMajorFaction(factionID) then return nil end
    return C_MajorFactions.GetMajorFactionData(factionID)
end

local function ParagonProgress(factionID)
    if not C_Reputation.IsFactionParagon(factionID) then return nil end
    local currentValue, threshold, rewardQuestID, hasReward = C_Reputation.GetFactionParagonInfo(factionID)
    if not currentValue or not threshold or threshold <= 0 then return nil end
    local label = 'Paragon ' .. math.floor(currentValue / threshold)
    if hasReward then label = label .. ' |TInterface\\RaidFrame\\ReadyCheck-Ready:10|t |cffffd200(reward!)|r' end
    return currentValue % threshold, threshold, label, hasReward, rewardQuestID
end

local function FriendshipProgress(friendshipInfo)
    local current = friendshipInfo.standing - friendshipInfo.reactionThreshold
    local max = friendshipInfo.nextThreshold and (friendshipInfo.nextThreshold - friendshipInfo.reactionThreshold) or 0
    return current, max
end

local function PaintPanel(frame)
    Painter.Custom(frame, Skin.PaintPanelBackdrop)
end

local JOURNEY_W      = 260
local JOURNEY_PAD    = 12
local JOURNEY_LINE_H = 16
local JOURNEY_HEADER = 44
local STATE_PAST    = 1
local STATE_CURRENT = 2
local STATE_FUTURE  = 3
local FUTURE_ALPHA  = 0.6

local function HideJourneyPanel()
    if journeyPanel then journeyPanel:Hide() end
end

local function BuildJourneyPanel()
    if journeyPanel then return end
    journeyPanel = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
    journeyPanel:SetWidth(Pixel.Scale(JOURNEY_W))
    PaintPanel(journeyPanel)
    journeyPanel:SetFrameStrata('TOOLTIP')
    journeyPanel:SetClampedToScreen(true)
    journeyPanel:Hide()

    journeyPanel.title = journeyPanel:CreateFontString(nil, 'OVERLAY')
    Skin.TipFont(journeyPanel.title, 'title')
    journeyPanel.title:SetPoint('TOPLEFT', Pixel.Scale(JOURNEY_PAD), Pixel.Scale(-JOURNEY_PAD))
    journeyPanel.title:SetPoint('TOPRIGHT', Pixel.Scale(-JOURNEY_PAD - 16), Pixel.Scale(-JOURNEY_PAD))
    journeyPanel.title:SetJustifyH('LEFT')

    journeyPanel.subtitle = journeyPanel:CreateFontString(nil, 'OVERLAY')
    Skin.TipFont(journeyPanel.subtitle, 'label')
    journeyPanel.subtitle:SetPoint('TOPLEFT', journeyPanel.title, 'BOTTOMLEFT', 0, Pixel.Scale(-2))
    journeyPanel.subtitle:SetPoint('TOPRIGHT', journeyPanel.title, 'BOTTOMRIGHT', 0, Pixel.Scale(-2))
    journeyPanel.subtitle:SetJustifyH('LEFT')

    local closeButton = Controls.Icon(journeyPanel, { preset = 'clear', size = Pixel.Scale(16), onClick = HideJourneyPanel })
    closeButton:SetPoint('TOPRIGHT', Pixel.Scale(-6), Pixel.Scale(-6))

    journeyPanel.lines = {}

    journeyPanel:HookScript('OnHide', BUI.Profiler.Wrap('ReputationManager.ReputationManager journey hidden', function()
        BUI.Events:Unregister('GLOBAL_MOUSE_DOWN', 'RepManager.Journey')
    end))
end

local function GetJourneyLine(index)
    local line = journeyPanel.lines[index]
    if line then return line end
    line = CreateFrame('Frame', nil, journeyPanel)
    line:SetHeight(Pixel.Scale(JOURNEY_LINE_H))

    line.marker = line:CreateTexture(nil, 'ARTWORK')
    line.marker:SetPoint('LEFT', Pixel.Scale(8), 0)

    line.label = line:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(line.label, 11, FONT, '')
    line.label:SetPoint('LEFT', line.marker, 'RIGHT', Pixel.Scale(8), 0)
    line.label:SetJustifyH('LEFT')

    line.value = line:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(line.value, 10, FONT, '')
    line.value:SetPoint('RIGHT', Pixel.Scale(-8), 0)
    line.value:SetJustifyH('RIGHT')
    Painter.Text(line.value, 'skinLabel')

    line.label:SetPoint('RIGHT', line.value, 'LEFT', Pixel.Scale(-6), 0)

    journeyPanel.lines[index] = line
    return line
end

local function SetJourneyLine(index, state, label, labelColor, value)
    local line = GetJourneyLine(index)
    local y = -Pixel.Scale(JOURNEY_HEADER + (index - 1) * JOURNEY_LINE_H)
    line:ClearAllPoints()
    line:SetPoint('TOPLEFT', Pixel.Scale(JOURNEY_PAD), y)
    line:SetPoint('TOPRIGHT', Pixel.Scale(-JOURNEY_PAD), y)

    local labelRed, labelGreen, labelBlue, labelAlpha = Painter.Color('skinLabel')
    if state == STATE_PAST then
        line.marker:SetSize(Pixel.Scale(6), Pixel.Scale(6))
        line.marker:SetColorTexture(Painter.Color('positive'))
    elseif state == STATE_CURRENT then
        line.marker:SetSize(Pixel.Scale(8), Pixel.Scale(8))
        line.marker:SetColorTexture(PARAGON_COLOR[1], PARAGON_COLOR[2], PARAGON_COLOR[3], 1)
        labelRed, labelGreen, labelBlue, labelAlpha = labelColor[1], labelColor[2], labelColor[3], 1
    else
        line.marker:SetSize(Pixel.Scale(4), Pixel.Scale(4))
        line.marker:SetColorTexture(Painter.Color('skinBorder'))
        labelAlpha = FUTURE_ALPHA
    end
    line.label:SetTextColor(labelRed, labelGreen, labelBlue, labelAlpha)
    line.label:SetText(label)
    line.value:SetText(value or '')
    line:Show()
end

local function StateFor(rank, current)
    if rank < current then return STATE_PAST end
    if rank == current then return STATE_CURRENT end
    return STATE_FUTURE
end

local function ProgressText(current, max)
    return BreakUpLargeNumbers(current) .. ' / ' .. BreakUpLargeNumbers(max)
end

local function PopulateStandardJourney(factionID, factionData)
    local reaction = factionData.reaction
    for standingID = 1, MAX_STANDING do
        local state = StateFor(standingID, reaction)
        local value
        if state == STATE_CURRENT then
            local max = factionData.nextReactionThreshold - factionData.currentReactionThreshold
            if max > 0 then
                value = ProgressText(factionData.currentStanding - factionData.currentReactionThreshold, max)
            elseif standingID == MAX_STANDING then
                value = 'Max'
            end
        end
        SetJourneyLine(standingID, state, StandingLabel(standingID), STANDING_COLORS[standingID], value)
    end

    local paragonCurrent, paragonMax, paragonLabel = ParagonProgress(factionID)
    if not paragonCurrent then return MAX_STANDING end
    SetJourneyLine(MAX_STANDING + 1, STATE_CURRENT, paragonLabel, PARAGON_COLOR, ProgressText(paragonCurrent, paragonMax))
    return MAX_STANDING + 1
end

local function PopulateRenownJourney(factionID, majorFactionData)
    local current = majorFactionData.renownLevel
    local maxLevel = math.max(#C_MajorFactions.GetRenownLevels(factionID), current)
    local atMax = C_MajorFactions.HasMaximumRenown(factionID)
    local paragonCurrent, paragonMax, paragonLabel
    if atMax then paragonCurrent, paragonMax, paragonLabel = ParagonProgress(factionID) end

    for level = 1, maxLevel do
        local state = StateFor(level, current)
        local value
        if state == STATE_CURRENT then
            if paragonCurrent then
                state = STATE_PAST
            else
                value = atMax and 'Max' or ProgressText(majorFactionData.renownReputationEarned, majorFactionData.renownLevelThreshold)
            end
        end
        SetJourneyLine(level, state, RENOWN_LEVEL_LABEL:format(level), RENOWN_COLOR, value)
    end
    if paragonCurrent then
        maxLevel = maxLevel + 1
        SetJourneyLine(maxLevel, STATE_CURRENT, paragonLabel, PARAGON_COLOR, ProgressText(paragonCurrent, paragonMax))
    end
    return maxLevel
end

local function PopulateFriendshipJourney(factionID, friendshipInfo)
    local current, max = FriendshipProgress(friendshipInfo)
    local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionID)
    if ranks.maxLevel <= 0 then
        SetJourneyLine(1, STATE_CURRENT, friendshipInfo.reaction, FRIENDSHIP_COLOR, max > 0 and ProgressText(current, max) or 'Max')
        return 1
    end

    for level = 1, ranks.maxLevel do
        local state = StateFor(level, ranks.currentLevel)
        local label = 'Rank ' .. level
        local value
        if state == STATE_CURRENT then
            label = friendshipInfo.reaction
            value = max > 0 and ProgressText(current, max) or 'Max'
        end
        SetJourneyLine(level, state, label, FRIENDSHIP_COLOR, value)
    end
    return ranks.maxLevel
end

local function ShowJourneyPanel(row)
    BuildJourneyPanel()

    local factionID = row._factionID
    local factionData = C_Reputation.GetFactionDataByID(factionID)
    if not factionData then return end

    journeyPanel.title:SetText(factionData.name)
    local subtitle = row._standingLabel
    if factionData.isAccountWide then subtitle = '|cff8cd9ffWarband|r  ' .. subtitle end
    journeyPanel.subtitle:SetText(subtitle)

    local lineCount
    local majorFactionData = MajorFactionData(factionID)
    local friendshipInfo = C_GossipInfo.GetFriendshipReputation(factionID)
    if majorFactionData then
        lineCount = PopulateRenownJourney(factionID, majorFactionData)
    elseif friendshipInfo and friendshipInfo.friendshipFactionID > 0 then
        lineCount = PopulateFriendshipJourney(factionID, friendshipInfo)
    else
        lineCount = PopulateStandardJourney(factionID, factionData)
    end
    PoolHideFrom(journeyPanel.lines, lineCount + 1)

    journeyPanel:SetHeight(Pixel.Scale(JOURNEY_HEADER + lineCount * JOURNEY_LINE_H + JOURNEY_PAD))

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    journeyPanel:ClearAllPoints()
    journeyPanel:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', cursorX / scale + 8, cursorY / scale)
    journeyPanel:Show()

    BUI.Events:Register('GLOBAL_MOUSE_DOWN', 'RepManager.Journey', function()
        if not journeyPanel:IsMouseOver() then journeyPanel:Hide() end
    end)
end

local function OpenRenown(factionID)
    if not EncounterJournal then EncounterJournal_LoadUI() end
    if not EncounterJournal:IsShown() then ShowUIPanel(EncounterJournal) end
    EJ_ContentTab_Select(EncounterJournal.JourneysTab:GetID())
    EncounterJournalJourneysFrame:ResetView(nil, factionID)
end

local function ShowRowMenu(row)
    local factionID, factionIndex = row._factionID, row._factionIndex
    local items = {
        { title = true, text = row._name },
        { text = 'Show Reputation Journey', callback = function() ShowJourneyPanel(row) end },
    }
    if C_Reputation.IsMajorFaction(factionID) then
        items[#items + 1] = { text = 'View Renown', callback = function() OpenRenown(factionID) end }
    end
    items[#items + 1] = { separator = true }
    if row._watched then
        items[#items + 1] = {
            text = 'Stop Watching',
            callback = function() C_Reputation.SetWatchedFactionByIndex(0); RefreshContent() end,
        }
    else
        items[#items + 1] = {
            text = 'Set as Watched (XP Bar)',
            callback = function() C_Reputation.SetWatchedFactionByIndex(factionIndex); RefreshContent() end,
        }
    end
    Skin.ContextMenu(items, { atCursor = true, width = 220 })
end

local function AddParagonTooltipLines(factionID, name)
    local paragonCurrent, paragonMax, _, hasReward, rewardQuestID = ParagonProgress(factionID)
    if not paragonCurrent then return end
    GameTooltip:AddLine(' ')
    GameTooltip:AddLine('Paragon  ' .. ProgressText(paragonCurrent, paragonMax), PARAGON_COLOR[1], PARAGON_COLOR[2], PARAGON_COLOR[3])
    GameTooltip:AddLine(PARAGON_REPUTATION_TOOLTIP_TEXT:format(name), 0.7, 0.7, 0.7, true)
    if rewardQuestID then
        if not HaveQuestRewardData(rewardQuestID) then C_QuestLog.RequestLoadQuestByID(rewardQuestID) end
        local rewardName, rewardTexture, rewardCount, rewardQuality = GetQuestLogRewardInfo(1, rewardQuestID)
        if rewardName then
            local quality = ITEM_QUALITY_COLORS[rewardQuality] or ITEM_QUALITY_COLORS[1]
            local countPrefix = rewardCount > 1 and (rewardCount .. 'x ') or ''
            GameTooltip:AddLine(('|T%s:14|t %s%s'):format(rewardTexture, countPrefix, rewardName), quality.r, quality.g, quality.b)
        end
    end
    if hasReward then GameTooltip:AddLine('Reward ready to collect', 0.2, 1, 0.2) end
end

local RowEnter = BUI.Profiler.Script('ReputationManager.ReputationManager row OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    GameTooltip:SetText(self._name, 1, 1, 1)
    GameTooltip:AddLine(self._standingLabel, 0.7, 0.7, 0.7, true)
    if self._accountWide then
        GameTooltip:AddLine('Warband Reputation', WARBAND_COLOR[1], WARBAND_COLOR[2], WARBAND_COLOR[3], true)
    end
    if self._description ~= '' then
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine(self._description, 0.7, 0.7, 0.7, true)
    end
    AddParagonTooltipLines(self._factionID, self._name)
    GameTooltip:AddLine(' ')
    GameTooltip:AddLine('|cff888888Right-click for options|r', 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

local RowClick = BUI.Profiler.Script('ReputationManager.ReputationManager row OnClick', ShowRowMenu)

local function CreateRow(parent)
    local row = CreateFrame('Button', nil, parent)
    row:SetHeight(Pixel.Scale(ROW_H))
    row:RegisterForClicks('RightButtonUp')
    row:SetScript('OnEnter', RowEnter)
    row:SetScript('OnLeave', GameTooltip_Hide)
    row:SetScript('OnClick', RowClick)
    Skin.CardRow(row)

    local watched = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(watched, 11, FONT, 'OUTLINE')
    watched:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', Pixel.Scale(-6), Pixel.Scale(5))
    watched:SetTextColor(PARAGON_COLOR[1], PARAGON_COLOR[2], PARAGON_COLOR[3], 1)
    watched:SetText('★')
    row.watchedText = watched

    local warband = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(warband, 9, FONT, 'OUTLINE')
    warband:SetPoint('TOPLEFT', Pixel.Scale(8), Pixel.Scale(-5))
    warband:SetTextColor(WARBAND_COLOR[1], WARBAND_COLOR[2], WARBAND_COLOR[3], 1)
    warband:SetText('W')
    row.warbandText = warband

    local progress = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(progress, 10, FONT, '')
    progress:SetPoint('TOPRIGHT', Pixel.Scale(-8), Pixel.Scale(-5))
    progress:SetJustifyH('RIGHT')
    Painter.Text(progress, 'skinLabel')
    row.progressText = progress

    local name = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(name, 11, FONT, '')
    name:SetJustifyH('LEFT')
    name:SetWordWrap(false)
    row.nameText = name

    local standing = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(standing, 9, FONT, '')
    standing:SetPoint('TOPLEFT', name, 'BOTTOMLEFT', 0, Pixel.Scale(-1))
    standing:SetJustifyH('LEFT')
    row.standingText = standing

    local bar = CreateFrame('StatusBar', nil, row)
    bar:SetPoint('BOTTOMLEFT', Pixel.Scale(6), Pixel.Scale(3))
    bar:SetPoint('BOTTOMRIGHT', Pixel.Scale(-6), Pixel.Scale(3))
    bar:SetHeight(Pixel.PixelSize(BAR_H))
    bar:SetStatusBarTexture(Widget.WHITE)
    local barBg = bar:CreateTexture(nil, 'BACKGROUND')
    barBg:SetAllPoints()
    Painter.Fill(barBg, 'skinBorder')
    row.bar = bar
    return row
end

local function ResolveStanding(factionData)
    local factionID = factionData.factionID

    local majorFactionData = MajorFactionData(factionID)
    if majorFactionData then
        local atMax = C_MajorFactions.HasMaximumRenown(factionID)
        local label = RENOWN_LEVEL_LABEL:format(majorFactionData.renownLevel)
        local paragonCurrent, paragonMax, paragonLabel
        if atMax then paragonCurrent, paragonMax, paragonLabel = ParagonProgress(factionID) end
        if paragonCurrent then return paragonCurrent, paragonMax, label .. '  ' .. paragonLabel, PARAGON_COLOR end
        local threshold = majorFactionData.renownLevelThreshold
        if atMax then return threshold, threshold, label .. ' (Max)', RENOWN_COLOR end
        return majorFactionData.renownReputationEarned, threshold, label, RENOWN_COLOR
    end

    local paragonCurrent, paragonMax, paragonLabel = ParagonProgress(factionID)
    if paragonCurrent then return paragonCurrent, paragonMax, paragonLabel, PARAGON_COLOR end

    local friendshipInfo = C_GossipInfo.GetFriendshipReputation(factionID)
    if friendshipInfo and friendshipInfo.friendshipFactionID > 0 then
        local label = friendshipInfo.reaction
        local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionID)
        if ranks.maxLevel > 0 then label = label .. ' (' .. ranks.currentLevel .. '/' .. ranks.maxLevel .. ')' end
        local current, max = FriendshipProgress(friendshipInfo)
        if max <= 0 then return 1, 1, label .. ' (Max)', FRIENDSHIP_COLOR end
        return current, max, label, FRIENDSHIP_COLOR
    end

    local reaction = factionData.reaction
    local current = factionData.currentStanding - factionData.currentReactionThreshold
    local max = factionData.nextReactionThreshold - factionData.currentReactionThreshold
    if reaction == MAX_STANDING and max == 0 then current, max = 1, 1 end
    return current, max, StandingLabel(reaction), STANDING_COLORS[reaction]
end

local function BuildPanel()
    if panel then return end

    panel = Skin.CreatePanelWindow('Reputation', function() slide.Close(true) end)
    panel.searchBox = Skin.CreateSearchBox(panel, PANEL_W - 24, function(text)
        searchText = text
        RefreshContent()
        panel.scroll:SetVerticalScroll(0)
    end)
    panel.searchBox:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-44))

    local area
    area, panel.scroll, panel.child = Skin.CreateListArea(panel, 78, ROW_H)
    panel.emptyText = Skin.CreateEmptyText(panel, area)
end

local function CreateHeader(parent)
    return Skin.CreateListHeader(parent, HEADER_H)
end

local function PlaceRow(frame, y)
    frame:ClearAllPoints()
    frame:SetPoint('TOPLEFT', panel.child, 'TOPLEFT', 0, -y)
    frame:SetPoint('TOPRIGHT', panel.child, 'TOPRIGHT', 0, -y)
    frame:Show()
end

local function FillRow(row, factionData, factionIndex)
    local current, max, label, color = ResolveStanding(factionData)
    local red, green, blue = color[1], color[2], color[3]

    row.warbandText:SetShown(factionData.isAccountWide)
    row.nameText:ClearAllPoints()
    if factionData.isAccountWide then
        row.nameText:SetPoint('TOPLEFT', row.warbandText, 'TOPRIGHT', Pixel.Scale(4), 0)
    else
        row.nameText:SetPoint('TOPLEFT', Pixel.Scale(8), Pixel.Scale(-5))
    end
    row.nameText:SetPoint('RIGHT', row.progressText, 'LEFT', Pixel.Scale(-6), 0)
    row.watchedText:SetShown(factionData.isWatched)

    row.nameText:SetText(factionData.name)
    row.nameText:SetTextColor(red, green, blue)
    row.standingText:SetText(label)
    row.standingText:SetTextColor(red, green, blue)

    local hasBar = max > 0
    row.progressText:SetText(hasBar and ProgressText(current, max) or '')
    row.bar:SetShown(hasBar)
    if hasBar then
        row.bar:SetMinMaxValues(0, max)
        row.bar:SetValue(math.min(current, max))
        row.bar:SetStatusBarColor(red, green, blue, 0.9)
    end

    row._factionID = factionData.factionID
    row._factionIndex = factionIndex
    row._name = factionData.name
    row._standingLabel = label
    row._accountWide = factionData.isAccountWide
    row._watched = factionData.isWatched
    row._description = factionData.description
end

RefreshContent = function()
    if not panel or not panel:IsShown() then return end

    local headerIndex, rowIndex, y = 0, 0, 0
    local pendingHeader
    for factionIndex = 1, C_Reputation.GetNumFactions() do
        local factionData = C_Reputation.GetFactionDataByIndex(factionIndex)
        if factionData.isHeader and not factionData.isHeaderWithRep then
            pendingHeader = factionData.name
        elseif searchText == '' or factionData.name:lower():find(searchText, 1, true) then
            if pendingHeader then
                headerIndex = headerIndex + 1
                local header = PoolGet(headerPool, headerIndex, CreateHeader, panel.child)
                header.text:SetText(pendingHeader)
                PlaceRow(header, y)
                y = y + HEADER_H + ROW_GAP
                pendingHeader = nil
            end
            rowIndex = rowIndex + 1
            local row = PoolGet(rowPool, rowIndex, CreateRow, panel.child)
            FillRow(row, factionData, factionIndex)
            PlaceRow(row, y)
            y = y + ROW_H + ROW_GAP
        end
    end

    PoolHideFrom(headerPool, headerIndex + 1)
    PoolHideFrom(rowPool, rowIndex + 1)
    panel.child:SetHeight(math.max(1, y))

    panel.emptyText:SetShown(rowIndex == 0)
    panel.emptyText:SetText(searchText ~= '' and 'No matching factions.' or 'No factions tracked.')
end

local ThrottledRefresh = BUI.Dispatcher.NewDelayed(function() RefreshContent() end, 0.3, 'Reputation refresh')

local function OnRepEvent()
    ThrottledRefresh()
end

local EVENTS = { 'UPDATE_FACTION', 'MAJOR_FACTION_UNLOCKED', 'MAJOR_FACTION_RENOWN_LEVEL_CHANGED' }

slide = BUI.SlidePanel.New({
    skin = 'reputationManager',
    width = function() return Pixel.Scale(PANEL_W) end,
    hiddenX = -PANEL_W,
    panel = function() return panel end,
    build = BuildPanel,
    onOpen = function()
        for _, event in ipairs(EVENTS) do BUI.Events:Register(event, 'ReputationManager', OnRepEvent) end
        C_Reputation.ExpandAllFactionHeaders()
        RefreshContent()
        panel.scroll:SetVerticalScroll(0)
    end,
    onClose = function()
        for _, event in ipairs(EVENTS) do BUI.Events:Unregister(event, 'ReputationManager') end
        HideJourneyPanel()
    end,
})

function BUI.ReputationManager.Toggle()
    slide.Toggle()
end

function BUI.ReputationManager.IsOpen()
    return slide.IsOpen()
end

CharacterFrame:HookScript('OnHide', BUI.Profiler.Wrap('ReputationManager.ReputationManager character hide', function() slide.Close(true) end))
context.OnDisable(function() slide.Close(true) end)
