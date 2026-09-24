local _, BUI = ...
local PoolGet, PoolHideFrom = BUI.Tools.PoolGet, BUI.Tools.PoolHideFrom
local Pixel = BUI.Pixel

local BUILib = BluUI.BUILibClient
local Widget   = BUILib.Widget
local Colors   = BUILib.Colors
local Controls = BUILib.Controls
local FONT     = BUILib.Font

local PANEL_W  = 380
local PANEL_H  = 460
local ROW_H    = 32
local HEADER_H = 22

local MAX_STANDING = 8

local RENOWN_COLOR     = { 0.4, 0.7, 1 }
local PARAGON_COLOR    = { 1, 0.82, 0 }
local FRIENDSHIP_COLOR = { 0.2, 0.85, 0.55 }

BUI.ReputationManager = {}

local panel, slide
local journeyPanel
local rowPool, headerPool = {}, {}
local searchText = ''
local RefreshContent

local function StandingLabel(reaction)
    return GetText('FACTION_STANDING_LABEL' .. reaction, UnitSex('player'))
end

local function StandingColor(reaction)
    local color = FACTION_BAR_COLORS[reaction]
    return color.r, color.g, color.b
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

local JOURNEY_W      = 260
local JOURNEY_PAD    = 12
local JOURNEY_LINE_H = 16
local JOURNEY_HEADER = 44
local STATE_PAST    = 1
local STATE_CURRENT = 2
local STATE_FUTURE  = 3

local function HideJourneyPanel()
    if journeyPanel then journeyPanel:Hide() end
end

local function BuildJourneyPanel()
    if journeyPanel then return end
    journeyPanel = Widget.New(UIParent, 'Frame', nil, {
        bg = Colors.bg.dark,
        border = Colors.border.light,
        size = { JOURNEY_W, 200 },
    }).frame
    journeyPanel:SetFrameStrata('TOOLTIP')
    journeyPanel:SetClampedToScreen(true)
    journeyPanel:Hide()

    journeyPanel.title = journeyPanel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(journeyPanel.title, 13, FONT, 'OUTLINE')
    journeyPanel.title:SetPoint('TOPLEFT', Pixel.Scale(JOURNEY_PAD), Pixel.Scale(-JOURNEY_PAD))
    journeyPanel.title:SetPoint('TOPRIGHT', Pixel.Scale(-JOURNEY_PAD - 16), Pixel.Scale(-JOURNEY_PAD))
    journeyPanel.title:SetJustifyH('LEFT')

    journeyPanel.subtitle = journeyPanel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(journeyPanel.subtitle, 10, FONT, '')
    journeyPanel.subtitle:SetPoint('TOPLEFT', journeyPanel.title, 'BOTTOMLEFT', 0, Pixel.Scale(-2))
    journeyPanel.subtitle:SetPoint('TOPRIGHT', journeyPanel.title, 'BOTTOMRIGHT', 0, Pixel.Scale(-2))
    journeyPanel.subtitle:SetJustifyH('LEFT')
    journeyPanel.subtitle:SetTextColor(0.6, 0.6, 0.6)

    local closeButton = Controls.Icon(journeyPanel, { preset = 'clear', size = Pixel.Scale(16),
        idleColor = { 0.7, 0.7, 0.7 }, onClick = HideJourneyPanel })
    closeButton:SetPoint('TOPRIGHT', Pixel.Scale(-6), Pixel.Scale(-6))

    journeyPanel.lines = {}

    journeyPanel:HookScript('OnHide', function()
        BUI.Events:Unregister('GLOBAL_MOUSE_DOWN', 'RepManager.Journey')
    end)
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
    line.value:SetTextColor(0.65, 0.65, 0.65)

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

    if state == STATE_PAST then
        line.marker:SetSize(Pixel.Scale(6), Pixel.Scale(6))
        line.marker:SetColorTexture(0.4, 0.7, 0.4, 1)
        line.label:SetTextColor(0.55, 0.55, 0.55)
    elseif state == STATE_CURRENT then
        line.marker:SetSize(Pixel.Scale(8), Pixel.Scale(8))
        line.marker:SetColorTexture(1, 0.82, 0, 1)
        line.label:SetTextColor(labelColor[1], labelColor[2], labelColor[3])
    else
        line.marker:SetSize(Pixel.Scale(4), Pixel.Scale(4))
        line.marker:SetColorTexture(0.3, 0.3, 0.3, 1)
        line.label:SetTextColor(0.4, 0.4, 0.4)
    end

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
    local lines = 0
    for standingID = 1, MAX_STANDING do
        lines = lines + 1
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
        SetJourneyLine(lines, state, StandingLabel(standingID), { StandingColor(standingID) }, value)
    end

    local paragonCurrent, paragonMax, paragonLabel = ParagonProgress(factionID)
    if paragonCurrent then
        lines = lines + 1
        SetJourneyLine(lines, STATE_CURRENT, paragonLabel, PARAGON_COLOR, ProgressText(paragonCurrent, paragonMax))
    end
    return lines
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
    local subParts = {}
    if factionData.isAccountWide then subParts[#subParts + 1] = '|cff8cd9ffWarband|r' end
    subParts[#subParts + 1] = row._standingLabel
    journeyPanel.subtitle:SetText(table.concat(subParts, '  '))

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
    for lineIndex = lineCount + 1, #journeyPanel.lines do journeyPanel.lines[lineIndex]:Hide() end

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
    Controls.ContextMenu(items, { atCursor = true, width = 220 })
end

local function AddParagonTooltipLines(factionID)
    local paragonCurrent, paragonMax, _, hasReward, rewardQuestID = ParagonProgress(factionID)
    if not paragonCurrent then return end
    local factionData = C_Reputation.GetFactionDataByID(factionID)
    local text = PARAGON_REPUTATION_TOOLTIP_TEXT
    GameTooltip:AddLine(' ')
    GameTooltip:AddLine('Paragon  ' .. ProgressText(paragonCurrent, paragonMax), PARAGON_COLOR[1], PARAGON_COLOR[2], PARAGON_COLOR[3])
    GameTooltip:AddLine(text:format(factionData and factionData.name or ''), 0.7, 0.7, 0.7, true)
    if rewardQuestID then
        if not HaveQuestRewardData(rewardQuestID) then
            C_QuestLog.RequestLoadQuestByID(rewardQuestID)
        end
        local rewardName, rewardTexture, rewardCount, rewardQuality = GetQuestLogRewardInfo(1, rewardQuestID)
        if rewardName then
            local qualityColor = ITEM_QUALITY_COLORS[rewardQuality or 1]
            local countPrefix = (rewardCount or 1) > 1 and (rewardCount .. 'x ') or ''
            GameTooltip:AddLine(('|T%s:14|t %s%s'):format(rewardTexture or 134400, countPrefix, rewardName),
                qualityColor and qualityColor.r or 1, qualityColor and qualityColor.g or 1, qualityColor and qualityColor.b or 1)
        end
    end
    if hasReward then GameTooltip:AddLine('Reward ready to collect', 0.2, 1, 0.2) end
end

local function CreateRow(parent)
    local row = CreateFrame('Button', nil, parent, 'BackdropTemplate')
    row:SetHeight(Pixel.Scale(ROW_H))
    row:RegisterForClicks('RightButtonUp')
    row:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8x8',
        edgeFile = 'Interface\\Buttons\\WHITE8x8',
        edgeSize = 1,
    })
    row:SetBackdropColor(0.07, 0.07, 0.08, 0.6)
    row:SetBackdropBorderColor(0.13, 0.13, 0.15, 1)

    local watched = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(watched, 11, FONT, 'OUTLINE')
    watched:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', Pixel.Scale(-4), Pixel.Scale(4))
    watched:SetTextColor(1, 0.82, 0, 1)
    watched:SetText('★')
    row.watchedText = watched

    local warband = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(warband, 9, FONT, 'OUTLINE')
    warband:SetPoint('TOPLEFT', Pixel.Scale(6), Pixel.Scale(-4))
    warband:SetTextColor(0.55, 0.85, 1, 1)
    warband:SetText('W')
    row.warbandText = warband

    local progress = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(progress, 10, FONT, '')
    progress:SetPoint('TOPRIGHT', Pixel.Scale(-6), Pixel.Scale(-4))
    progress:SetJustifyH('RIGHT')
    progress:SetTextColor(0.7, 0.7, 0.7, 1)
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

    local barBg = row:CreateTexture(nil, 'BACKGROUND')
    barBg:SetPoint('BOTTOMLEFT', Pixel.Scale(4), Pixel.Scale(1))
    barBg:SetPoint('BOTTOMRIGHT', Pixel.Scale(-4), Pixel.Scale(1))
    barBg:SetHeight(Pixel.PixelSize(2))
    barBg:SetColorTexture(0.15, 0.15, 0.15, 1)
    row.barBg = barBg

    local bar = row:CreateTexture(nil, 'ARTWORK')
    bar:SetPoint('BOTTOMLEFT', barBg, 'BOTTOMLEFT', 0, 0)
    bar:SetPoint('TOPLEFT', barBg, 'TOPLEFT', 0, 0)
    row.bar = bar

    row:SetScript('OnEnter', function(self)
        self:SetBackdropBorderColor(Colors.GetAccent())
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetText(self._name, 1, 1, 1)
        GameTooltip:AddLine(self._standingLabel, 0.7, 0.7, 0.7, true)
        if self._accountWide then
            GameTooltip:AddLine('Warband Reputation', 0.55, 0.85, 1, true)
        end
        if self._description ~= '' then
            GameTooltip:AddLine(' ')
            GameTooltip:AddLine(self._description, 0.7, 0.7, 0.7, true)
        end
        AddParagonTooltipLines(self._factionID)
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine('|cff888888Right-click for options|r', 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    row:SetScript('OnLeave', function(self)
        self:SetBackdropBorderColor(0.13, 0.13, 0.15, 1)
        GameTooltip:Hide()
    end)
    row:SetScript('OnClick', function(self) ShowRowMenu(self) end)
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
        if paragonCurrent then
            return { current = paragonCurrent, max = paragonMax, label = label .. '  ' .. paragonLabel, color = PARAGON_COLOR }
        end
        if atMax then label = label .. ' (Max)' end
        return {
            current = atMax and majorFactionData.renownLevelThreshold or majorFactionData.renownReputationEarned,
            max     = majorFactionData.renownLevelThreshold,
            label   = label,
            color   = RENOWN_COLOR,
        }
    end

    local paragonCurrent, paragonMax, paragonLabel = ParagonProgress(factionID)
    if paragonCurrent then
        return { current = paragonCurrent, max = paragonMax, label = paragonLabel, color = PARAGON_COLOR }
    end

    local friendshipInfo = C_GossipInfo.GetFriendshipReputation(factionID)
    if friendshipInfo and friendshipInfo.friendshipFactionID > 0 then
        local label = friendshipInfo.reaction
        local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionID)
        if ranks.maxLevel > 0 then
            label = label .. ' (' .. ranks.currentLevel .. '/' .. ranks.maxLevel .. ')'
        end
        local current, max = FriendshipProgress(friendshipInfo)
        if max <= 0 then
            current, max = 1, 1
            label = label .. ' (Max)'
        end
        return { current = current, max = max, label = label, color = FRIENDSHIP_COLOR }
    end

    local current = factionData.currentStanding - factionData.currentReactionThreshold
    local max = factionData.nextReactionThreshold - factionData.currentReactionThreshold
    if factionData.reaction == MAX_STANDING and max == 0 then current, max = 1, 1 end
    return {
        current = current,
        max     = max,
        label   = StandingLabel(factionData.reaction),
        color   = { StandingColor(factionData.reaction) },
    }
end

local function BuildPanel()
    if panel then return end

    panel = Widget.New(UIParent, 'Frame', nil, {
        bg = Colors.bg.dark,
        border = Colors.border.light,
        size = { PANEL_W, PANEL_H },
    }).frame
    panel:SetFrameStrata('HIGH')
    panel:SetFrameLevel(50)
    panel:SetClampedToScreen(false)
    panel:Hide()

    BUI.Skinning.CreateTitleBar(panel, 'Reputation', 36, function() slide.Close(true) end)
    panel.searchBox = BUI.Skinning.CreateSearchBox(panel, PANEL_W - 24, function(text)
        searchText = text
        RefreshContent()
    end)
    panel.searchBox:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-44))

    local scrollArea = CreateFrame('Frame', nil, panel)
    scrollArea:SetPoint('TOPLEFT', Pixel.Scale(8), Pixel.Scale(-78))
    scrollArea:SetPoint('BOTTOMRIGHT', Pixel.Scale(-8), Pixel.Scale(12))
    panel.scroll, panel.child = BUI.Skinning.CreateScrollArea(scrollArea, ROW_H, 4)

    panel.emptyText = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.emptyText, 11, FONT, '')
    panel.emptyText:SetPoint('CENTER', scrollArea)
    panel.emptyText:SetTextColor(0.4, 0.4, 0.4)
    panel.emptyText:Hide()
end

local function CreateHeader(parent)
    return BUI.Skinning.CreateListHeader(parent, HEADER_H)
end

RefreshContent = function()
    if not panel or not panel:IsShown() then return end

    C_Reputation.ExpandAllFactionHeaders()
    local headerIndex, rowIndex, y = 0, 0, 0
    local activeHeader, headerPlaced
    local rowWidth = panel.child:GetWidth()
    if rowWidth <= 0 then rowWidth = PANEL_W - 30 end

    for factionIndex = 1, C_Reputation.GetNumFactions() do
        local factionData = C_Reputation.GetFactionDataByIndex(factionIndex)
        if factionData and factionData.isHeader and not factionData.isHeaderWithRep then
            if activeHeader and not headerPlaced then activeHeader:Hide() end
            headerIndex = headerIndex + 1
            activeHeader = PoolGet(headerPool, headerIndex, CreateHeader, panel.child)
            activeHeader.text:SetText(factionData.name)
            headerPlaced = false
        elseif factionData and (searchText == '' or factionData.name:lower():find(searchText, 1, true)) then
            if activeHeader and not headerPlaced then
                activeHeader:ClearAllPoints()
                activeHeader:SetPoint('TOPLEFT', panel.child, 'TOPLEFT', 0, -y)
                activeHeader:SetPoint('TOPRIGHT', panel.child, 'TOPRIGHT', 0, -y)
                activeHeader:Show()
                headerPlaced = true
                y = y + HEADER_H + 2
            end
            rowIndex = rowIndex + 1
            local row = PoolGet(rowPool, rowIndex, CreateRow, panel.child)
            row:ClearAllPoints()
            row:SetPoint('TOPLEFT', panel.child, 'TOPLEFT', 0, -y)
            row:SetPoint('TOPRIGHT', panel.child, 'TOPRIGHT', 0, -y)

            local standing = ResolveStanding(factionData)
            local red, green, blue = standing.color[1], standing.color[2], standing.color[3]

            row.warbandText:SetShown(factionData.isAccountWide)
            row.nameText:ClearAllPoints()
            if factionData.isAccountWide then
                row.nameText:SetPoint('TOPLEFT', row.warbandText, 'TOPRIGHT', Pixel.Scale(4), 0)
            else
                row.nameText:SetPoint('TOPLEFT', Pixel.Scale(6), Pixel.Scale(-4))
            end
            row.nameText:SetPoint('RIGHT', row.progressText, 'LEFT', Pixel.Scale(-6), 0)
            row.watchedText:SetShown(factionData.isWatched)

            row.nameText:SetText(factionData.name)
            row.nameText:SetTextColor(red, green, blue)
            row.standingText:SetText(standing.label)
            row.standingText:SetTextColor(red, green, blue)

            if standing.max > 0 then
                row.progressText:SetText(ProgressText(standing.current, standing.max))
                row.bar:SetWidth(math.max(1, (rowWidth - 8) * math.min(1, standing.current / standing.max)))
                row.bar:SetColorTexture(red, green, blue, 0.9)
                row.bar:Show()
                row.barBg:Show()
            else
                row.progressText:SetText('')
                row.bar:Hide()
                row.barBg:Hide()
            end

            row._factionID = factionData.factionID
            row._factionIndex = factionIndex
            row._name = factionData.name
            row._standingLabel = standing.label
            row._accountWide = factionData.isAccountWide
            row._watched = factionData.isWatched
            row._description = factionData.description
            row:Show()
            y = y + ROW_H + 2
        end
    end
    if activeHeader and not headerPlaced then activeHeader:Hide() end

    PoolHideFrom(headerPool, headerIndex + 1)
    PoolHideFrom(rowPool, rowIndex + 1)
    panel.child:SetHeight(math.max(1, y))
    panel.scroll:SetVerticalScroll(0)

    panel.emptyText:SetShown(rowIndex == 0)
    panel.emptyText:SetText(searchText ~= '' and 'No matching factions.' or 'No factions tracked.')
end

local ThrottledRefresh = BUI.Dispatcher.NewDelayed(function() RefreshContent() end, 0.3)

slide = BUI.SlidePanel.New({
    skin = 'reputationManager',
    width = function() return Pixel.Scale(PANEL_W) end,
    hiddenX = -PANEL_W,
    panel = function() return panel end,
    build = BuildPanel,
    onOpen = function() RefreshContent() end,
    onClose = HideJourneyPanel,
})

function BUI.ReputationManager.Toggle()
    slide.Toggle()
end

function BUI.ReputationManager.IsOpen()
    return slide.IsOpen()
end

local function OnRepEvent()
    if slide.IsOpen() then ThrottledRefresh() end
end

BUI.Events:OnLogin('ReputationManager', function()
    CharacterFrame:HookScript('OnHide', function() slide.Close(true) end)

    BUI.Events:Register('UPDATE_FACTION',                    'ReputationManager', OnRepEvent)
    BUI.Events:Register('MAJOR_FACTION_UNLOCKED',            'ReputationManager', OnRepEvent)
    BUI.Events:Register('MAJOR_FACTION_RENOWN_LEVEL_CHANGED', 'ReputationManager', OnRepEvent)

    BUI.Skinning.OnToggle('reputationManager', function(enabled)
        if not enabled then slide.Close(true) end
    end)
    BUI.Skinning.RegisterSkin('reputationManager', {
        name = 'Reputation Manager',
        description = 'Faction list beside the Character frame.',
        icon = 'Interface\\Icons\\Achievement_Reputation_01',
    })
end)
