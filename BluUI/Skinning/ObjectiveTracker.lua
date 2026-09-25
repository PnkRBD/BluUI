local _, BUI = ...

local pairs = pairs
local ipairs = ipairs
local select = select
local hooksecurefunc = hooksecurefunc

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Theme = BUILib.Theme
local Skin3 = BUILib.Skin
local Controls = BUILib.Controls
local PageKit = BUILib.PageKit
local LibWidget = BUILib.Widget
local FONT = BUILib.Font or STANDARD_TEXT_FONT
local Skin = BUI.Skinning
local Pixel = BUI.Pixel
local sharedMedia = LibStub and LibStub('LibSharedMedia-3.0', true)

local LIBRARY_FONT_OPTION    = 'LIBRARY'
local DEFAULT_FONT_SIZE      = 11
local DEFAULT_CARD_OPACITY   = 98
local ROLE_SIZE_DELTA        = { line = 0, title = 1, header = 2, timer = 8 }
local TRACKER_STASH_SCALE    = 0.01
local DEFAULT_TRACKER_COLORS = {
	title     = { 1, 0.82, 0.25 },
	hover     = { 1, 1, 1 },
	objective = { 0.85, 0.85, 0.9 },
	completed = { 0.45, 0.85, 0.45 },
	ready     = { 0.35, 1, 0.45 },
	timeLeft  = { 1, 0.45, 0.45 },
	dim       = { 0.45, 0.45, 0.5 },
}
local TIP_TEXT_MAX_LENGTH    = 46
local CARD_TEXTURE_TINT      = { 0.18, 0.19, 0.21 }
local READY_COUNT_HEX        = 'ffd140'
local FLASH_SECONDS          = 0.7

local GLYPH_SIZE        = 10
local BAR_LABEL_SIZE    = 11
local HEADER_TEXT_INSET = 11
local MINIMIZE_SIZE     = 15
local BAR_ICON_SIZE     = 20
local CARD_PAD_LEFT     = 22
local CARD_PAD_RIGHT    = 10
local CARD_PAD_Y        = 6

local POI_BUTTON_SCALE  = 0.8
local POI_ANCHOR_OFFSET_X = -10
local FLAT_TEXTURE      = 'Interface\\Buttons\\WHITE8X8'

local TRACKER_NAMES = {
	'ScenarioObjectiveTracker',
	'UIWidgetObjectiveTracker',
	'CampaignQuestObjectiveTracker',
	'QuestObjectiveTracker',
	'AdventureObjectiveTracker',
	'AchievementObjectiveTracker',
	'MonthlyActivitiesObjectiveTracker',
	'ProfessionsRecipeTracker',
	'BonusObjectiveTracker',
	'WorldQuestObjectiveTracker',
	'InitiativeTasksObjectiveTracker',
}

local addedElements = {}
local restoreHeaders = {}
local skinnedBars = {}
local hiddenTextures = {}
local restoreFonts = {}
local hiddenPoiButtons = {}
local trackerCard
local headerCounts
local headerFilter
local readyQuestIDs = {}
local previousReadyByQuest = {}
local watchedCount = 0
local readyCount = 0
local pendingMenuQuestID
local wrapAdjustedText = { titles = {}, objectives = {} }
local questClassificationLabels
local Scenario = {}
local QuestFilter = {}
local QuestItem = { POSITION_KEY = 'trackerquestitem', SIZE = 40 }
local QuestInfo = { WOWHEAD_URL = 'https://www.wowhead.com/%s=%d', previousObjectives = {} }

local function IsEnabled()
	return Skin.IsSkinEnabled('objectivetracker')
end

local function GetSettings()
	local skinningDB = BUI.GetDB().skinning
	if not skinningDB.objectivetrackerSettings then skinningDB.objectivetrackerSettings = {} end
	return skinningDB.objectivetrackerSettings
end

local function GetSkinFont()
	local fontName = GetSettings().font
	if fontName == BUI.C.GLOBAL_OPTION then
		return BUI.GetGlobalFont() or FONT
	end
	if fontName and fontName ~= LIBRARY_FONT_OPTION and sharedMedia then
		local fetched = sharedMedia:Fetch('font', fontName, true)
		if fetched then return fetched end
	end
	return FONT
end

local function GetSkinFontFlags()
	return GetSettings().fontOutline and 'OUTLINE' or ''
end

local function GetRoleSize(role)
	return (GetSettings().fontSize or DEFAULT_FONT_SIZE) + (ROLE_SIZE_DELTA[role] or 0)
end

local function ApplySkinFont(fontString, role)
	if not fontString then return end
	local entry = restoreFonts[fontString]
	if entry then
		entry.role = role
	else
		local font, oldSize, flags = fontString:GetFont()
		restoreFonts[fontString] = { font = font, size = oldSize, flags = flags, role = role }
	end
	Pixel.ApplyFont(fontString, GetRoleSize(role), GetSkinFont(), GetSkinFontFlags())
end

local linkedPanels = {}

local FLAT_TEXTURE_OPTION = 'FLAT'

local function ApplyPanelStyle(panel)
	local settings = GetSettings()
	local opacity = (settings.cardOpacity or DEFAULT_CARD_OPACITY) / 100
	local borderColor = settings.cardBorderColor or Theme.border.light
	local borderAlpha = settings.cardBorder == false and 0 or (borderColor[4] or 1)
	local textureName = settings.cardTexture or FLAT_TEXTURE_OPTION
	local texturePath
	if textureName ~= FLAT_TEXTURE_OPTION and sharedMedia then
		texturePath = sharedMedia:Fetch('statusbar', textureName, true)
	end
	local overlay = panel.__buiCardTexture
	if texturePath then
		if not overlay then
			overlay = panel:CreateTexture(nil, 'BACKGROUND', nil, 1)
			local inset = Pixel.PixelSize(1)
			overlay:SetPoint('TOPLEFT', panel, 'TOPLEFT', inset, -inset)
			overlay:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -inset, inset)
			panel.__buiCardTexture = overlay
		end
		overlay:SetTexture(texturePath)
		local textureTint = settings.cardTextureColor or CARD_TEXTURE_TINT
		overlay:SetVertexColor(textureTint[1], textureTint[2], textureTint[3], opacity)
		overlay:Show()
		panel:SetBackdropColor(Theme.bg.dark[1], Theme.bg.dark[2], Theme.bg.dark[3], 0)
	else
		if overlay then overlay:Hide() end
		panel:SetBackdropColor(Theme.bg.dark[1], Theme.bg.dark[2], Theme.bg.dark[3], opacity)
	end
	panel:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
end

local function ApplyCardStyle()
	if trackerCard then ApplyPanelStyle(trackerCard) end
	for panel in pairs(linkedPanels) do ApplyPanelStyle(panel) end
end

Skin.trackerRules = {}

function Skin.TrackerSeparatorColor()
	local color = GetSettings().separatorColor or Theme.border.light
	return color[1], color[2], color[3], color[4] or 1
end

local normalizedTrackerColors = {}

local function NormalizeTrackerColor(color)
	if type(color) ~= 'table' then return nil end
	if type(color[1]) == 'number' and type(color[2]) == 'number' and type(color[3]) == 'number' then return color end
	if type(color.r) == 'number' and type(color.g) == 'number' and type(color.b) == 'number' then return { color.r, color.g, color.b } end
	return nil
end

function Skin.ClearTrackerColorCache()
	wipe(normalizedTrackerColors)
end

function Skin.TrackerColor(key)
	local cached = normalizedTrackerColors[key]
	if cached then return cached end
	local colors = GetSettings().colors
	local color = NormalizeTrackerColor(colors and colors[key]) or DEFAULT_TRACKER_COLORS[key] or DEFAULT_TRACKER_COLORS.objective
	if type(color[1]) ~= 'number' then color = DEFAULT_TRACKER_COLORS[key] or DEFAULT_TRACKER_COLORS.objective end
	color = { color[1], color[2], color[3] }
	normalizedTrackerColors[key] = color
	return color
end

function Skin.TrackerColorRGB(key)
	local color = Skin.TrackerColor(key)
	return color[1], color[2], color[3], 1
end

function Skin.ApplyTrackerSeparators()
	local red, green, blue, alpha = Skin.TrackerSeparatorColor()
	for rule in pairs(Skin.trackerRules) do
		rule:SetColorTexture(red, green, blue, alpha)
	end
end

function Skin.RegisterTrackerPanel(frame)
	linkedPanels[frame] = true
	ApplyCardStyle()
end

function Skin.GetTrackerPanelOutsets()
	return Pixel.PixelSize(CARD_PAD_LEFT), Pixel.PixelSize(CARD_PAD_RIGHT), Pixel.PixelSize(CARD_PAD_Y)
end

local function IsFiniteNumber(value)
	if type(value) ~= 'number' then return false end
	if issecretvalue and issecretvalue(value) then return false end
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function GetLaidOutTrackerHeight(trackerFrame)
	local total, shownModules = 0, 0
	for _, module in ipairs(trackerFrame.modules) do
		local contentsHeight = module:GetContentsHeight()
		if contentsHeight > 0 then
			if shownModules > 0 then total = total + trackerFrame.moduleSpacing end
			total = total + contentsHeight + module.bottomSpacing
			shownModules = shownModules + 1
		end
	end
	if shownModules == 0 then return 0 end
	return trackerFrame.topModulePadding + total + trackerFrame.bottomModulePadding
end

local function UpdateCardAnchors()
	local trackerFrame = _G.ObjectiveTrackerFrame
	if not trackerCard or not trackerFrame then return end
	local padLeft = Pixel.PixelSize(CARD_PAD_LEFT)
	local padRight = Pixel.PixelSize(CARD_PAD_RIGHT)
	local padY = Pixel.PixelSize(CARD_PAD_Y)
	trackerCard:ClearAllPoints()
	trackerCard:SetPoint('TOPLEFT', trackerFrame, 'TOPLEFT', -padLeft, padY)
	trackerCard:SetPoint('TOPRIGHT', trackerFrame, 'TOPRIGHT', padRight, padY)
	local collapsed = trackerFrame.IsCollapsed and trackerFrame:IsCollapsed()
	if collapsed and trackerFrame.Header then
		trackerCard:SetPoint('BOTTOM', trackerFrame.Header, 'BOTTOM', 0, -padY)
	else
		trackerCard:SetHeight(GetLaidOutTrackerHeight(trackerFrame) + padY * 2)
	end
end

local function SyncTrackerCardShown()
	if not trackerCard then return end
	local trackerFrame = _G.ObjectiveTrackerFrame
	local nineSlice = trackerFrame and trackerFrame.NineSlice
	local shown = IsEnabled() and not Skin.trackerStashScale and not Skin.trackerFadedOut
	if nineSlice then
		trackerCard:SetShown(shown and nineSlice:IsShown())
	else
		trackerCard:SetShown(shown)
	end
end

local function EnsureTrackerCard()
	local trackerFrame = _G.ObjectiveTrackerFrame
	if not trackerFrame then return end
	local nineSlice = trackerFrame.NineSlice
	if not trackerCard then
		trackerCard = CreateFrame('Frame', 'BUI_TrackerPanel', UIParent, 'BackdropTemplate')
		trackerCard:SetFrameStrata('LOW')
		trackerCard:SetFrameLevel(0)
		Skin3.Backdrop(trackerCard, { bg = Theme.bg.dark, border = Theme.border.light })
		trackerCard:HookScript('OnSizeChanged', Skin.TrackerClamp)

		if trackerFrame.SetCollapsed then hooksecurefunc(trackerFrame, 'SetCollapsed', UpdateCardAnchors) end
		if nineSlice then
			nineSlice:SetAlpha(0)
			hooksecurefunc(nineSlice, 'SetAlpha', function(self, alpha)
				if IsEnabled() and alpha ~= 0 then self:SetAlpha(0) end
			end)
			nineSlice:HookScript('OnShow', SyncTrackerCardShown)
			nineSlice:HookScript('OnHide', SyncTrackerCardShown)
			hooksecurefunc(nineSlice, 'SetPoint', UpdateCardAnchors)
		end
		trackerFrame:HookScript('OnHide', SyncTrackerCardShown)
		trackerFrame:HookScript('OnShow', SyncTrackerCardShown)
		hooksecurefunc(trackerFrame, 'SetAlpha', function(_, alpha)
			local fadedOut = not issecretvalue(alpha) and alpha == 0 and not Skin.trackerStashScale
			if fadedOut == (Skin.trackerFadedOut or false) then return end
			Skin.trackerFadedOut = fadedOut or nil
			SyncTrackerCardShown()
		end)
	end
	UpdateCardAnchors()
	ApplyCardStyle()
	SyncTrackerCardShown()
end

local styleOverrides

local function GetStyleOverrides()
	if styleOverrides then return styleOverrides end
	local palette = _G.OBJECTIVE_TRACKER_COLOR
	if not palette then return nil end
	styleOverrides = {}
	local map = {
		Header             = Skin.TrackerColor('title'),
		HeaderHighlight    = Skin.TrackerColor('hover'),
		Normal             = Skin.TrackerColor('objective'),
		NormalHighlight    = Skin.TrackerColor('hover'),
		Complete           = Skin.TrackerColor('completed'),
		CompleteHighlight  = Skin.TrackerColor('completed'),
		TimeLeft           = Skin.TrackerColor('timeLeft'),
		TimeLeftHighlight  = Skin.TrackerColor('hover'),
	}
	for key, replacement in pairs(map) do
		local style = palette[key]
		if style then styleOverrides[style] = replacement end
	end
	return styleOverrides
end

local function PaintFromStyle(fontString, style)
	local overrides = GetStyleOverrides()
	local replacement = overrides and style and overrides[style]
	if replacement then
		fontString:SetTextColor(replacement[1], replacement[2], replacement[3], 1)
	end
end

local function IsReadyBlock(block)
	local questID = block.poiQuestID
	return questID and readyQuestIDs[questID] == true
end

local function OnSetStringText(block, fontString, _, _, colorStyle, useHighlight)
	if not IsEnabled() or not fontString or GetSettings().customColors == false then return end
	if fontString == block.HeaderText and IsReadyBlock(block) then
		fontString:SetTextColor(Skin.TrackerColorRGB(useHighlight and 'hover' or 'ready'))
		return
	end
	local palette = _G.OBJECTIVE_TRACKER_COLOR
	local effective = colorStyle or (palette and palette.Normal)
	if useHighlight and effective and effective.reverse then effective = effective.reverse end
	PaintFromStyle(fontString, effective)
end

local function OnUpdateHighlight(block)
	if not IsEnabled() or GetSettings().customColors == false then return end
	local headerText = block.HeaderText
	if headerText then
		local key = IsReadyBlock(block) and 'ready' or 'title'
		headerText:SetTextColor(Skin.TrackerColorRGB(block.isHighlighted and 'hover' or key))
	end
	if block.usedLines then
		for _, line in pairs(block.usedLines) do
			if line.Text then PaintFromStyle(line.Text, line.Text.colorStyle) end
		end
	end
end

local function ForEachTrackedBlock(callback)
	for _, trackerName in ipairs(TRACKER_NAMES) do
		local tracker = _G[trackerName]
		if tracker and tracker.usedBlocks then
			for _, blocks in pairs(tracker.usedBlocks) do
				for _, block in pairs(blocks) do callback(block) end
			end
		end
	end
end

local function RepaintSkinColors()
	ForEachTrackedBlock(OnUpdateHighlight)
end

local function RepaintBlizzardColors()
	ForEachTrackedBlock(function(block)
		local headerText = block.HeaderText
		local headerStyle = headerText and headerText.colorStyle
		if headerStyle then headerText:SetTextColor(headerStyle.r, headerStyle.g, headerStyle.b) end
		if block.usedLines then
			for _, line in pairs(block.usedLines) do
				local style = line.Text and line.Text.colorStyle
				if style then line.Text:SetTextColor(style.r, style.g, style.b) end
			end
		end
	end)
end

function Skin.ApplyTrackerColors()
	styleOverrides = nil
	Skin.ClearTrackerColorCache()
	if GetSettings().customColors == false then
		RepaintBlizzardColors()
	else
		RepaintSkinColors()
	end
end

function QuestItem.UpdateCooldown()
	local button = QuestItem.button
	if not button or not button.questLogIndex or not button:IsShown() then return end
	local start, duration, enable = GetQuestLogSpecialItemCooldown(button.questLogIndex)
	if start then CooldownFrame_Set(button.cooldown, start, duration, enable) end
end

function QuestItem.OnEnter(self)
	if not self.questLogIndex then return end
	GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	GameTooltip:SetQuestLogSpecialItem(self.questLogIndex)
	GameTooltip:AddLine('Ctrl+drag to move', Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3])
	GameTooltip:Show()
end

function QuestItem.OnDragStart(self)
	if IsControlKeyDown() and not InCombatLockdown() then self:StartMoving() end
end

function QuestItem.OnDragStop(self)
	self:StopMovingOrSizing()
	Skin.SavePosition(self, QuestItem.POSITION_KEY)
end

function QuestItem.Ensure()
	if QuestItem.button then return end
	local button = CreateFrame('Button', 'BUI_TrackerQuestItemButton', UIParent, 'SecureActionButtonTemplate')
	button:SetAttribute('type', 'item')
	button:RegisterForClicks('AnyUp', 'AnyDown')
	button:RegisterForDrag('LeftButton')
	button:SetMovable(true)
	button:SetClampedToScreen(true)

	local icon = button:CreateTexture(nil, 'ARTWORK')
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
	cooldown:SetAllPoints(button)
	button.cooldown = cooldown

	local hotkey = button:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(hotkey, BAR_LABEL_SIZE, FONT, 'OUTLINE')
	hotkey:SetPoint('TOPRIGHT', button, 'TOPRIGHT', -Pixel.Scale(2), -Pixel.Scale(3))
	button.hotkey = hotkey

	local count = button:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(count, BAR_LABEL_SIZE, FONT, 'OUTLINE')
	count:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -Pixel.Scale(2), Pixel.Scale(3))
	button.count = count

	local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
	highlight:SetAllPoints(button)
	highlight:SetColorTexture(1, 1, 1, 0.22)

	Pixel.ApplyBorder(button, 1, Theme.border.light[1], Theme.border.light[2], Theme.border.light[3], 1)
	button:SetScript('OnEnter', QuestItem.OnEnter)
	button:SetScript('OnLeave', GameTooltip_Hide)
	button:SetScript('OnDragStart', QuestItem.OnDragStart)
	button:SetScript('OnDragStop', QuestItem.OnDragStop)
	QuestItem.button = button
end

function QuestItem.Place(visible)
	local button = QuestItem.button
	if button.placedVisible == visible then return end
	button.placedVisible = visible
	button:ClearAllPoints()
	if not visible then
		button:SetSize(1, 1)
		button:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', -50, -50)
		button:SetAlpha(0)
		button:EnableMouse(false)
		return
	end
	button:SetSize(Pixel.Scale(QuestItem.SIZE), Pixel.Scale(QuestItem.SIZE))
	if not Skin.RestorePosition(button, QuestItem.POSITION_KEY) then
		button:SetPoint('CENTER', UIParent, 'CENTER', 0, -200)
	end
	button:SetAlpha(1)
	button:EnableMouse(true)
end

function QuestItem.FindClosest()
	local bestLink, bestLogIndex
	local bestDistance = math.huge
	for watchIndex = 1, C_QuestLog.GetNumQuestWatches() do
		local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(watchIndex)
		local logIndex = questID and C_QuestLog.GetLogIndexForQuestID(questID)
		if logIndex then
			local link, _, _, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
			if link and (showWhenComplete or not C_QuestLog.IsComplete(questID)) then
				local distanceSq = C_QuestLog.GetDistanceSqToQuest(questID)
				if type(distanceSq) ~= 'number' then distanceSq = math.huge - 1 end
				if distanceSq < bestDistance then
					bestDistance = distanceSq
					bestLink = link
					bestLogIndex = logIndex
				end
			end
		end
	end
	return bestLink, bestLogIndex
end

function QuestItem.Update()
	local settings = GetSettings()
	local key = settings.questItemKey
	local wantBinding = IsEnabled() and key and key ~= 'NONE'
	local wantButton = IsEnabled() and settings.showQuestItemButton == true
	if not QuestItem.button and not wantBinding and not wantButton then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(QuestItem.Update, 'Skinning.TrackerItemKey')
		return
	end
	QuestItem.Ensure()
	local button = QuestItem.button
	ClearOverrideBindings(button)
	local link, logIndex
	if wantBinding or wantButton then link, logIndex = QuestItem.FindClosest() end
	button:SetAttribute('item', link)
	button.questLogIndex = logIndex
	QuestItem.Place(wantButton)
	button:SetShown(not wantButton or link ~= nil)
	if link and wantBinding then
		SetOverrideBindingClick(button, true, key, 'BUI_TrackerQuestItemButton')
	end
	if not link then return end
	local _, texture, charges = GetQuestLogSpecialItemInfo(logIndex)
	button.icon:SetTexture(texture)
	button.count:SetText(charges and charges > 1 and charges or '')
	button.hotkey:SetText(wantBinding and BUI.Keybinds.Format(key) or '')
	QuestItem.UpdateCooldown()
end

function QuestInfo.AddWowheadButton(rootDescription, kind, id)
	if not IsEnabled() or not id then return end
	rootDescription:CreateButton('Copy Wowhead Link', function()
		BUI.Modals.Input({
			title = 'Wowhead Link',
			message = 'Press Ctrl+C to copy.',
			defaultText = QuestInfo.WOWHEAD_URL:format(kind, id),
			confirmText = 'Done',
		})
	end)
end

function QuestInfo.AddTomTomButton(rootDescription)
	if not IsEnabled() then return end
	local TomTom = _G.TomTom
	if not TomTom or not TomTom.AddWaypoint then return end
	local questID = pendingMenuQuestID
	if not questID then return end
	rootDescription:CreateButton('TomTom Waypoint', function()
		local mapID, waypointX, waypointY
		if C_QuestLog.GetNextWaypoint then
			mapID, waypointX, waypointY = C_QuestLog.GetNextWaypoint(questID)
		end
		if not mapID then
			local uiMapID = GetQuestUiMapID and GetQuestUiMapID(questID)
			if (not uiMapID or uiMapID == 0) and C_Map and C_Map.GetBestMapForUnit then
				uiMapID = C_Map.GetBestMapForUnit('player')
			end
			if uiMapID and uiMapID ~= 0 then
				if C_QuestLog.GetNextWaypointForMap then
					waypointX, waypointY = C_QuestLog.GetNextWaypointForMap(questID, uiMapID)
					if waypointX then mapID = uiMapID end
				end
				if not mapID and C_QuestLog.GetQuestsOnMap then
					local questsOnMap = C_QuestLog.GetQuestsOnMap(uiMapID)
					if questsOnMap then
						for _, questPOI in ipairs(questsOnMap) do
							if questPOI.questID == questID and questPOI.x and questPOI.y then
								mapID, waypointX, waypointY = uiMapID, questPOI.x, questPOI.y
								break
							end
						end
					end
				end
				if not mapID and C_TaskQuest and C_TaskQuest.GetQuestLocation then
					local taskX, taskY = C_TaskQuest.GetQuestLocation(questID, uiMapID)
					if taskX and taskY then
						mapID, waypointX, waypointY = uiMapID, taskX, taskY
					end
				end
			end
		end
		if not mapID or not waypointX or not waypointY then
			BUI.Print('No map location available for that quest.')
			return
		end
		local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or ('Quest ' .. questID)
		TomTom:AddWaypoint(mapID, waypointX, waypointY, { title = title, persistent = false, minimap = true, world = true })
	end)
end

local menuHookInstalled = false

local function InstallMenuHook()
	if menuHookInstalled then return end
	if not Menu or not Menu.ModifyMenu then return end
	menuHookInstalled = true
	Menu.ModifyMenu('MENU_QUEST_OBJECTIVE_TRACKER', function(_, rootDescription)
		QuestInfo.AddTomTomButton(rootDescription)
		QuestInfo.AddWowheadButton(rootDescription, 'quest', pendingMenuQuestID)
	end)
	Menu.ModifyMenu('MENU_BONUS_OBJECTIVE_TRACKER', function(_, rootDescription, block)
		QuestInfo.AddWowheadButton(rootDescription, 'quest', block and block.id)
	end)
	Menu.ModifyMenu('MENU_ACHIEVEMENT_TRACKER', function(_, rootDescription, block)
		QuestInfo.AddWowheadButton(rootDescription, 'achievement', block and block.id)
	end)
end

local function SingleLineTitlesEnabled()
	return GetSettings().singleLineTitles ~= false
end

local function ApplyTitleWrap()
	local titleWrap = not (IsEnabled() and SingleLineTitlesEnabled())
	for fontString in pairs(wrapAdjustedText.titles) do
		fontString.__buiWordWrap = titleWrap
		fontString:SetWordWrap(titleWrap)
	end
	local objectiveWrap = not (IsEnabled() and GetSettings().singleLineObjectives ~= false)
	for fontString in pairs(wrapAdjustedText.objectives) do
		fontString.__buiWordWrap = objectiveWrap
		fontString:SetWordWrap(objectiveWrap)
	end
end

local function TruncateTipText(text)
	if #text > TIP_TEXT_MAX_LENGTH then
		return text:sub(1, TIP_TEXT_MAX_LENGTH) .. '...'
	end
	return text
end

local function GetQuestClassificationLabel(questID)
	if not C_QuestInfoSystem or not C_QuestInfoSystem.GetQuestClassification then return nil end
	local classificationEnum = Enum.QuestClassification
	if not classificationEnum then return nil end
	if not questClassificationLabels then
		local labelByMemberName = {
			Normal = { 'Standard', 'e8e8f0' },
			Questline = { 'Questline', '4fd0c0' },
			Campaign = { 'Campaign', 'ffd140' },
			Calling = { 'Calling', 'ffd140' },
			Important = { 'Important', 'ff6060' },
			Legendary = { 'Legendary', 'ff9b33' },
			Meta = { 'Meta', 'c07fff' },
			Recurring = { 'Recurring', '5fb0ff' },
			WorldQuest = { 'World Quest', '5fb0ff' },
			BonusObjective = { 'Bonus Objective', '5fb0ff' },
			Threat = { 'Threat', 'ff6060' },
		}
		questClassificationLabels = {}
		for memberName, entry in pairs(labelByMemberName) do
			local value = classificationEnum[memberName]
			if value then questClassificationLabels[value] = entry end
		end
	end
	local classification = C_QuestInfoSystem.GetQuestClassification(questID)
	local entry = classification and questClassificationLabels[classification]
	if not entry then return nil end
	return entry[1], entry[2]
end

function QuestInfo.RewardRow(texture, name, amount, quality)
	local red, green, blue = C_Item.GetItemQualityColor(quality or 1)
	return {
		left = ('|T%s:14:14:0:0:64:64:5:59:5:59|t %s'):format(texture, name),
		right = amount and amount > 1 and BreakUpLargeNumbers(amount) or nil,
		leftColor = { red, green, blue },
	}
end

function QuestInfo.AddRewardRows(rows, questID)
	local rewardRows = {}
	local _, baseXP = GetQuestLogRewardXP(questID)
	if baseXP and baseXP > 0 then
		rewardRows[#rewardRows + 1] = { left = BreakUpLargeNumbers(baseXP) .. ' XP' }
	end
	local money = GetQuestLogRewardMoney(questID)
	if money and money > 0 then
		rewardRows[#rewardRows + 1] = { left = GetMoneyString(money, true) }
	end
	for rewardIndex = 1, GetNumQuestLogRewards(questID) do
		local name, texture, amount, quality = GetQuestLogRewardInfo(rewardIndex, questID)
		if name then rewardRows[#rewardRows + 1] = QuestInfo.RewardRow(texture, name, amount, quality) end
	end
	for _, currency in ipairs(C_QuestLog.GetQuestRewardCurrencies(questID)) do
		local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currency.currencyID)
		rewardRows[#rewardRows + 1] = QuestInfo.RewardRow(currency.texture, currency.name, currency.totalRewardAmount, currencyInfo and currencyInfo.quality)
	end
	local choiceCount = GetNumQuestLogChoices(questID)
	if choiceCount > 0 then
		rewardRows[#rewardRows + 1] = { left = 'Choose one:', leftColor = Skin.TrackerColor('dim') }
		for choiceIndex = 1, choiceCount do
			local name, texture, amount, quality = GetQuestLogChoiceInfo(choiceIndex, questID)
			if name then rewardRows[#rewardRows + 1] = QuestInfo.RewardRow(texture, name, amount, quality) end
		end
	end
	if #rewardRows == 0 then return end
	rows[#rows + 1] = { space = true }
	rows[#rows + 1] = { left = 'Rewards', leftColor = Skin.TrackerColor('dim') }
	for _, row in ipairs(rewardRows) do rows[#rows + 1] = row end
end

local function OnQuestBlockHeaderEnter(_, block, questID, isInGroup)
	if not IsEnabled() or GetSettings().questTooltip == false then return end
	if isInGroup or not block or not questID then return end
	local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
	if not title then return end

	local rows = {}
	local logIndex = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
	local info = logIndex and C_QuestLog.GetInfo and C_QuestLog.GetInfo(logIndex)
	local metaParts = {}
	if info and info.level then
		metaParts[#metaParts + 1] = '|cffe8e8f0' .. info.level .. '|r'
	end
	local typeLabel, typeHex = GetQuestClassificationLabel(questID)
	if typeLabel then
		metaParts[#metaParts + 1] = '|cff' .. typeHex .. typeLabel .. '|r'
	end
	if info and Enum.QuestFrequency then
		if info.frequency == Enum.QuestFrequency.Daily then
			metaParts[#metaParts + 1] = '|cff5fb0ffDaily|r'
		elseif info.frequency == Enum.QuestFrequency.Weekly then
			metaParts[#metaParts + 1] = '|cff5fb0ffWeekly|r'
		end
	end
	if info and info.suggestedGroup and info.suggestedGroup > 0 then
		metaParts[#metaParts + 1] = ('Group %d'):format(info.suggestedGroup)
	end
	local uiMapID = GetQuestUiMapID and GetQuestUiMapID(questID)
	if uiMapID and uiMapID ~= 0 and C_Map and C_Map.GetMapInfo then
		local mapInfo = C_Map.GetMapInfo(uiMapID)
		if mapInfo and mapInfo.name then
			metaParts[#metaParts + 1] = '|cff7fb0ff' .. mapInfo.name .. '|r'
		end
	end
	if #metaParts > 0 then
		rows[#rows + 1] = {
			left = table.concat(metaParts, ' \194\183 '),
			right = tostring(questID),
			rightColor = Skin.TrackerColor('dim'),
		}
		rows[#rows + 1] = { space = true }
	end

	local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
	if objectives then
		for _, objective in ipairs(objectives) do
			if objective.text and objective.text ~= '' then
				local objectiveText = TruncateTipText(objective.text)
				if not objective.finished then
					objectiveText = objectiveText:gsub('^(%d+/%d+)', '|cff' .. READY_COUNT_HEX .. '%1|r')
				end
				rows[#rows + 1] = {
					left = objectiveText,
					leftColor = Skin.TrackerColor(objective.finished and 'completed' or 'objective'),
				}
			end
		end
	end
	if readyQuestIDs[questID] then
		rows[#rows + 1] = { left = '|A:UI-QuestIcon-TurnIn-Normal:14:14|a Ready to turn in', leftColor = Skin.TrackerColor('ready') }
	end
	QuestInfo.AddRewardRows(rows, questID)
	if #rows == 0 then return end

	local blockCenterX = block.GetCenter and block:GetCenter()
	local anchorSide = (blockCenterX and blockCenterX < UIParent:GetWidth() / 2) and 'RIGHT' or 'LEFT'
	LibWidget.ShowTipRows(block, title, rows, { anchor = anchorSide })
end

local function HideQuestTip()
	LibWidget.HideTip()
end

local questTipHookInstalled = false

local function InstallQuestTipHook()
	if questTipHookInstalled then return end
	if not EventRegistry or not EventRegistry.RegisterCallback then return end
	questTipHookInstalled = true
	EventRegistry:RegisterCallback('OnQuestBlockHeader.OnEnter', OnQuestBlockHeaderEnter, wrapAdjustedText)
end

function QuestFilter.HasActive()
	local spec = GetSettings().trackerTrackSpec
	return spec ~= nil and spec ~= 'all'
end

function QuestFilter.Trackable(info)
	return not info.isHeader and not info.isTask and (not info.isBounty or C_QuestLog.IsComplete(info.questID))
end

function QuestFilter.MaxWatches()
	return Constants and Constants.QuestWatchConsts and Constants.QuestWatchConsts.MAX_QUEST_WATCHES or 25
end

function QuestFilter.Retrack(spec)
	if not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then return end
	GetSettings().trackerTrackSpec = spec
	QuestFilter.UpdateTint()
	local numEntries = C_QuestLog.GetNumQuestLogEntries()
	local maxWatches = QuestFilter.MaxWatches()
	local superTracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID() or 0
	if not IsShiftKeyDown() then
		for entryIndex = 1, numEntries do
			local info = C_QuestLog.GetInfo(entryIndex)
			if info and QuestFilter.Trackable(info) then
				C_QuestLog.RemoveQuestWatch(info.questID)
			end
		end
	end
	local zoneName = GetRealZoneText() or ''
	local inZoneHeader = false
	for entryIndex = 1, numEntries do
		local info = C_QuestLog.GetInfo(entryIndex)
		if info and not info.isHidden then
			if info.isHeader then
				inZoneHeader = info.title == zoneName
			elseif QuestFilter.Trackable(info) then
				local wanted
				if spec == 'all' then
					wanted = true
				elseif spec == 'zone' then
					wanted = info.isOnMap or inZoneHeader
				elseif spec == 'campaign' then
					wanted = (info.campaignID or 0) ~= 0
				elseif spec == 'daily' then
					wanted = info.frequency and Enum.QuestFrequency and info.frequency >= Enum.QuestFrequency.Daily
				elseif spec == 'ready' then
					wanted = C_QuestLog.IsComplete(info.questID)
				end
				if wanted then
					if C_QuestLog.GetNumQuestWatches() >= maxWatches then break end
					C_QuestLog.AddQuestWatch(info.questID)
				end
			end
		end
	end
	C_QuestLog.SortQuestWatches()
	if superTracked > 0 and C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(superTracked) then
		C_SuperTrack.SetSuperTrackedQuestID(superTracked)
	end
end

function QuestFilter.UpdateTint()
	if not headerFilter then return end
	if QuestFilter.HasActive() then
		local accentRed, accentGreen, accentBlue = Theme.GetAccent()
		headerFilter.glyph:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
	else
		headerFilter.glyph:SetVertexColor(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3], 1)
	end
end

function QuestFilter.ShowMenu()
	local settings = GetSettings()
	local items = {}
	items[#items + 1] = { title = 'TRACK' }
	for _, preset in ipairs({
		{ spec = 'zone', label = 'Current Zone' },
		{ spec = 'campaign', label = 'Campaign' },
		{ spec = 'daily', label = 'Daily & Weekly' },
		{ spec = 'ready', label = 'Completed' },
		{ spec = 'all', label = 'All Quests' },
	}) do
		local spec = preset.spec
		items[#items + 1] = {
			text = preset.label,
			checked = settings.trackerTrackSpec == spec,
			callback = function(item)
				QuestFilter.Retrack(spec)
				item.checked = true
				QuestFilter.ShowMenu()
				return true
			end,
		}
	end
	Controls.ContextMenu(items, { width = 180, anchor = headerFilter, point = 'TOPRIGHT', relPt = 'BOTTOMRIGHT', offsetY = -4 })
end

local function UpdateHeaderCounts()
	if not headerCounts then return end
	if watchedCount == 0 then
		headerCounts:SetText('')
		return
	end
	local text = watchedCount .. ' tracked'
	if readyCount > 0 then
		text = ('%s |cff%s\194\183 %d ready|r'):format(text, READY_COUNT_HEX, readyCount)
	end
	headerCounts:SetText(text)
end

function QuestInfo.AnnounceObjectives(questID, previousFinished)
	local finished = {}
	local objectives = C_QuestLog.GetQuestObjectives(questID)
	if not objectives then return finished end
	for objectiveIndex, objective in ipairs(objectives) do
		finished[objectiveIndex] = objective.finished
		if objective.finished and previousFinished and previousFinished[objectiveIndex] == false and objective.text and objective.text ~= '' then
			UIErrorsFrame:AddMessage('Objective complete: ' .. objective.text, Skin.TrackerColorRGB('completed'))
		end
	end
	return finished
end

function QuestInfo.AnnounceReady(questID)
	local title = C_QuestLog.GetTitleForQuestID(questID)
	if title then UIErrorsFrame:AddMessage(title .. ' complete', Skin.TrackerColorRGB('ready')) end
end

local function RefreshQuestCache()
	if not IsEnabled() then return end
	if not C_QuestLog.GetNumQuestWatches or not C_QuestLog.GetQuestIDForQuestWatchIndex then return end
	local announce = GetSettings().completionMessage == true
	local newObjectivesByQuest = {}
	local newReadyByQuest = {}
	local chime = false
	local readyChanged = false
	readyQuestIDs = {}
	watchedCount = 0
	readyCount = 0
	for watchIndex = 1, C_QuestLog.GetNumQuestWatches() do
		local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(watchIndex)
		if questID then
			watchedCount = watchedCount + 1
			local ready = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) or false
			if ready then
				readyCount = readyCount + 1
				readyQuestIDs[questID] = true
				if previousReadyByQuest[questID] == false then
					chime = true
					if announce then QuestInfo.AnnounceReady(questID) end
				end
			elseif announce then
				newObjectivesByQuest[questID] = QuestInfo.AnnounceObjectives(questID, QuestInfo.previousObjectives[questID])
			end
			if previousReadyByQuest[questID] ~= ready then readyChanged = true end
			newReadyByQuest[questID] = ready
		end
	end
	previousReadyByQuest = newReadyByQuest
	QuestInfo.previousObjectives = newObjectivesByQuest
	UpdateHeaderCounts()
	if readyChanged then RepaintSkinColors() end
	QuestItem.Update()
	if chime then BUI.PlaySoundByName(GetSettings().completionSound) end
end

local queueQuestCacheRefresh = BUI.Dispatcher.NewDelayed(RefreshQuestCache, 0.3)

local flashQuestID

local function GetFlashColor()
	local accentRed, accentGreen, accentBlue = Theme.GetAccent()
	return (accentRed + 1) / 2, (accentGreen + 1) / 2, (accentBlue + 1) / 2
end

local function FlashProgressBlock()
	local questID = flashQuestID
	flashQuestID = nil
	if not questID or not IsEnabled() then return end
	local targetBlock
	ForEachTrackedBlock(function(block)
		if block.poiQuestID == questID then targetBlock = block end
	end)
	if not targetBlock or not targetBlock.usedLines then return end
	local flashRed, flashGreen, flashBlue = GetFlashColor()
	for _, line in pairs(targetBlock.usedLines) do
		if line.Text then line.Text:SetTextColor(flashRed, flashGreen, flashBlue, 1) end
	end
	C_Timer.After(FLASH_SECONDS, function()
		if IsEnabled() then OnUpdateHighlight(targetBlock) end
	end)
end

local queueProgressFlash = BUI.Dispatcher.NewDelayed(FlashProgressBlock, 0.15)

local function OnQuestProgress(_, questID)
	if not IsEnabled() or not questID then return end
	flashQuestID = questID
	queueProgressFlash()
end

local dashFontStrings = {}

local function DashesVisible()
	return not IsEnabled() or GetSettings().showDashes == true
end

local function ApplyDashAlpha()
	local visible = DashesVisible()
	for dash in pairs(dashFontStrings) do
		dash:SetAlpha(visible and 1 or 0)
	end
end

local function SetPoiButtonVisible(button, visible)
	button:SetAlpha(visible and 1 or 0)
	if button.EnableMouse then button:EnableMouse(visible) end
end

local function ApplyPoiVisibility()
	local visible = not IsEnabled() or GetSettings().showQuestIcons == true
	for button in pairs(hiddenPoiButtons) do
		SetPoiButtonVisible(button, visible)
	end
end

function Skin.StashTracker(stashed)
	local trackerFrame = _G.ObjectiveTrackerFrame
	if stashed == (Skin.trackerStashScale ~= nil) then return end
	if stashed then
		Skin.trackerStashScale = trackerFrame:GetScale()
		trackerFrame:SetScaleBase(TRACKER_STASH_SCALE)
		trackerFrame:SetAlpha(0)
	else
		trackerFrame:SetScaleBase(Skin.trackerStashScale)
		trackerFrame:SetAlpha(1)
		Skin.trackerStashScale = nil
	end
	SyncTrackerCardShown()
	Skin.TrackerClamp()
end

function Skin.TrackerClamp()
	if not trackerCard or not IsEnabled() or Skin.trackerStashScale then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(Skin.TrackerClamp, 'Skinning.TrackerClamp')
		return
	end
	local trackerFrame = _G.ObjectiveTrackerFrame
	local left, right, top, bottom = trackerCard:GetLeft(), trackerCard:GetRight(), trackerCard:GetTop(), trackerCard:GetBottom()
	local frameLeft, frameRight, frameTop, frameBottom = trackerFrame:GetLeft(), trackerFrame:GetRight(), trackerFrame:GetTop(), trackerFrame:GetBottom()
	if not IsFiniteNumber(left) or not IsFiniteNumber(bottom) or not IsFiniteNumber(frameLeft) or not IsFiniteNumber(frameBottom) then return end
	for panel in pairs(linkedPanels) do
		local panelTop, panelBottom = panel:GetTop(), panel:GetBottom()
		if panel:IsShown() and IsFiniteNumber(panelTop) and IsFiniteNumber(panelBottom) then
			top = math.max(top, panelTop)
			bottom = math.min(bottom, panelBottom)
		end
	end
	local ratio = trackerCard:GetEffectiveScale() / trackerFrame:GetEffectiveScale()
	local insetLeft, insetRight = left * ratio - frameLeft, right * ratio - frameRight
	local insetTop, insetBottom = top * ratio - frameTop, bottom * ratio - frameBottom
	local applied = trackerCard._buiClamp
	if applied and applied[1] == insetLeft and applied[2] == insetRight and applied[3] == insetTop and applied[4] == insetBottom then return end
	trackerCard._buiClamp = { insetLeft, insetRight, insetTop, insetBottom }
	trackerFrame:SetClampRectInsets(insetLeft, insetRight, insetTop, insetBottom)
end

function Skin.TrackerHeaderControls(parent, anchor)
	local filterButton = CreateFrame('Button', nil, parent)
	filterButton:SetSize(Pixel.PixelSize(MINIMIZE_SIZE), Pixel.PixelSize(MINIMIZE_SIZE))
	filterButton:SetPoint('RIGHT', anchor, 'LEFT', -Pixel.Scale(4), 0)
	local filterGlyph = filterButton:CreateTexture(nil, 'OVERLAY')
	filterGlyph:SetTexture(BUILib.GetLibMedia('eye'))
	filterGlyph:SetPoint('CENTER', 0, 0)
	filterGlyph:SetSize(Pixel.Scale(GLYPH_SIZE + 2), Pixel.Scale(GLYPH_SIZE + 2))
	headerFilter = filterButton
	headerFilter.glyph = filterGlyph
	filterButton:SetScript('OnEnter', function()
		filterGlyph:SetVertexColor(1, 1, 1, 1)
	end)
	filterButton:SetScript('OnLeave', function()
		QuestFilter.UpdateTint()
	end)
	filterButton:SetScript('OnClick', QuestFilter.ShowMenu)
	QuestFilter.UpdateTint()

	headerCounts = parent:CreateFontString(nil, 'ARTWORK')
	ApplySkinFont(headerCounts, 'line')
	headerCounts:SetPoint('RIGHT', filterButton, 'LEFT', -Pixel.Scale(8), 0)
	headerCounts:SetJustifyH('RIGHT')
	headerCounts:SetTextColor(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3], 1)
	UpdateHeaderCounts()
end

function Skin.TrackerDecorateHeader(trackerFrame)
	local header = trackerFrame.Header
	if not header.__buiDecorated then
		header.__buiDecorated = true
		Skin.TrackerHeaderControls(header, header.MinimizeButton)
		hooksecurefunc(trackerFrame, 'Init', Skin.TrackerDecorateHeader)
	end
	local enabled = IsEnabled()
	local text = header.Text
	getmetatable(text).__index.SetText(text, enabled and 'OBJECTIVES' or trackerFrame.headerText)
	headerFilter:SetShown(enabled)
	headerCounts:SetShown(enabled)
end

local function ApplyHeaderRowVisibility()
	local trackerFrame = _G.ObjectiveTrackerFrame
	local header = trackerFrame and trackerFrame.Header
	if not header then return end
	header:SetShown(not IsEnabled() or GetSettings().showHeaderRow ~= false)
	Skin.TrackerDecorateHeader(trackerFrame)
end

local function ApplyTextSettings()
	local font = GetSkinFont()
	local flags = GetSkinFontFlags()
	for fontString, entry in pairs(restoreFonts) do
		Pixel.ApplyFont(fontString, GetRoleSize(entry.role), font, flags)
	end
	ApplyCardStyle()
end

local function Track(element)
	if element then addedElements[#addedElements + 1] = element end
	return element
end

local function SetCollapsedGlyph(header, collapsed)
	local button = header and header.MinimizeButton
	local chevron = button and button.__buiChevron
	if chevron then chevron:SetRotation(collapsed and 0 or math.pi) end
end

local function ReassertHidden(texture)
	if texture.__buiReasserting then return end
	if texture.__buiHidden and IsEnabled() then
		texture.__buiReasserting = true
		texture:SetTexture(nil)
		texture:SetAlpha(0)
		texture.__buiReasserting = nil
	end
end

local function HideBlizzardTexture(texture)
	if not texture or texture.__buiHidden then return end
	texture.__buiHidden = true
	texture.__buiOldAlpha = texture:GetAlpha()
	texture.__buiOldAtlas = texture.GetAtlas and texture:GetAtlas() or nil
	if not texture.__buiOldAtlas then texture.__buiOldTexture = texture:GetTexture() end
	hiddenTextures[#hiddenTextures + 1] = texture

	texture:SetTexture(nil)
	texture:SetAlpha(0)
	hooksecurefunc(texture, 'SetAtlas', ReassertHidden)
	hooksecurefunc(texture, 'SetTexture', ReassertHidden)
	hooksecurefunc(texture, 'SetShown', ReassertHidden)
	hooksecurefunc(texture, 'Show', ReassertHidden)
	hooksecurefunc(texture, 'SetAlpha', ReassertHidden)
end

local function HideFrameTextures(frame)
	if not frame or not frame.GetRegions then return end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region and region.IsObjectType and region:IsObjectType('Texture') then
			HideBlizzardTexture(region)
		end
	end
end

local function ClearButtonTextures(button, getters)
	for _, getter in ipairs(getters) do
		HideBlizzardTexture(button[getter] and button[getter](button))
	end
end

local function SkinMinimizeButton(header)
	local button = header.MinimizeButton
	if not button or button.__buiSkinned then return end
	button.__buiSkinned = true

	ClearButtonTextures(button, { 'GetNormalTexture', 'GetPushedTexture', 'GetDisabledTexture', 'GetHighlightTexture' })
	HideFrameTextures(button)
	button:SetSize(Pixel.PixelSize(MINIMIZE_SIZE), Pixel.PixelSize(MINIMIZE_SIZE))

	local chevron = Track(button:CreateTexture(nil, 'OVERLAY'))
	chevron:SetTexture(BUILib.GetLibMedia('dropdown'))
	chevron:SetPoint('CENTER', 0, 0)
	chevron:SetSize(Pixel.Scale(GLYPH_SIZE), Pixel.Scale(GLYPH_SIZE))
	button.__buiChevron = chevron

	local function PaintGlyph(red, green, blue)
		chevron:SetVertexColor(red, green, blue, 1)
	end
	PaintGlyph(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3])

	button:HookScript('OnEnter', function()
		if IsEnabled() then PaintGlyph(1, 1, 1) end
	end)
	button:HookScript('OnLeave', function()
		PaintGlyph(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3])
	end)

	SetCollapsedGlyph(header, header.isCollapsed)
	if header.SetCollapsed then hooksecurefunc(header, 'SetCollapsed', SetCollapsedGlyph) end
end

local function SkinHeader(header)
	if not header or header.__buiSkinned then return end
	header.__buiSkinned = true

	local entry = {}
	restoreHeaders[header] = entry

	HideFrameTextures(header)
	HideBlizzardTexture(header.Background)

	local headerTextInset = -Pixel.Scale(HEADER_TEXT_INSET)

	local rule = Track(header:CreateTexture(nil, 'ARTWORK'))
	rule:SetPoint('BOTTOMLEFT', header, 'BOTTOMLEFT', headerTextInset, 0)
	rule:SetPoint('BOTTOMRIGHT', header, 'BOTTOMRIGHT', 0, 0)
	rule:SetHeight(Pixel.PixelSize(1))
	Skin.trackerRules[rule] = true
	rule:SetColorTexture(Skin.TrackerSeparatorColor())

	local text = header.Text
	if text then
		entry.red, entry.green, entry.blue, entry.alpha = text:GetTextColor()

		ApplySkinFont(text, 'header')
		text:ClearAllPoints()
		text:SetPoint('LEFT', header, 'LEFT', headerTextInset, 0)
		text:SetTextColor(Theme.text.label[1], Theme.text.label[2], Theme.text.label[3], 1)
	end

	SkinMinimizeButton(header)
end

local function CropIcon(icon)
	if icon.GetAtlas and icon:GetAtlas() then return end
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function SkinBar(bar)
	if not bar or bar.__buiSkinned then return end
	bar.__buiSkinned = true

	Skin3.StripTextures(bar)
	bar:SetStatusBarTexture(FLAT_TEXTURE)
	bar:SetStatusBarColor(Theme.GetAccent())
	Theme.RegisterAccentElement(bar, function(element, red, green, blue)
		element:SetStatusBarColor(red, green, blue, 1)
	end)
	local backdrop = Skin3.ChildBackdrop(bar, { bg = Theme.bg.dark, border = Theme.border.default })
	skinnedBars[bar] = backdrop
	bar:HookScript('OnShow', function(self)
		backdrop:SetShown(IsEnabled() and self:IsShown())
	end)
	backdrop:SetShown(IsEnabled() and bar:IsShown())

	local label = bar.Label
	if label then
		Pixel.ApplyFont(label, BAR_LABEL_SIZE, FONT, 'OUTLINE')
		label:ClearAllPoints()
		label:SetPoint('CENTER', bar, 'CENTER', 0, 0)
	end

	local icon = bar.Icon
	if icon then
		if icon.SetMask then icon:SetMask('') end
		CropIcon(icon)
		icon:SetSize(Pixel.Scale(BAR_ICON_SIZE), Pixel.Scale(BAR_ICON_SIZE))
		icon:ClearAllPoints()
		icon:SetPoint('LEFT', bar, 'RIGHT', Pixel.Scale(6), 0)
	end
end

local function SkinStageBlock()
	local scenarioTracker = _G.ScenarioObjectiveTracker
	local stageBlock = scenarioTracker and scenarioTracker.StageBlock
	if not stageBlock or stageBlock.__buiSkinned then return end
	stageBlock.__buiSkinned = true

	HideBlizzardTexture(stageBlock.NormalBG)
	HideBlizzardTexture(stageBlock.ThemeOverlay)
	HideBlizzardTexture(stageBlock.FinalBG)
	HideBlizzardTexture(stageBlock.GlowTexture)

	skinnedBars[stageBlock] = Skin3.ChildBackdrop(stageBlock, { bg = Theme.bg.light, border = Theme.border.light })
	stageBlock:HookScript('OnShow', Scenario.SyncStageBackdrop)
	hooksecurefunc(stageBlock, 'UpdateWidgetRegistration', Scenario.SyncStageBackdrop)
	Scenario.SyncStageBackdrop(stageBlock)

	ApplySkinFont(stageBlock.Stage, 'header')
	ApplySkinFont(stageBlock.Name, 'title')
	ApplySkinFont(stageBlock.CompleteLabel, 'header')
	if stageBlock.Stage then
		stageBlock.Stage:SetTextColor(Skin.TrackerColorRGB('title'))
	end
	if stageBlock.Name then
		stageBlock.Name:SetTextColor(Skin.TrackerColorRGB('title'))
	end
end

local function SkinItemButton(button)
	if not button or button.__buiSkinned then return end
	button.__buiSkinned = true

	ClearButtonTextures(button, { 'GetNormalTexture', 'GetPushedTexture' })

	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight then
		highlight:SetAtlas(nil)
		highlight:SetColorTexture(1, 1, 1, 0.22)
	end

	local icon = button.icon or button.Icon or button.IconTexture
	if icon then
		CropIcon(icon)
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
	end

	Pixel.ApplyBorder(button, 1, Theme.border.light[1], Theme.border.light[2], Theme.border.light[3], 1)

	local glow = button.Glow
	if glow then
		local outset = Pixel.PixelSize(2)
		glow:SetAtlas(nil)
		glow:SetColorTexture(Theme.GetAccent())
		glow:ClearAllPoints()
		glow:SetPoint('TOPLEFT', button, 'TOPLEFT', -outset, outset)
		glow:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', outset, -outset)
		Theme.RegisterAccentElement(glow, function(element, red, green, blue)
			element:SetColorTexture(red, green, blue, 1)
		end)
	end

	local count = button.Count or button.count
	if count then Pixel.ApplyFont(count, BAR_LABEL_SIZE, FONT, 'OUTLINE') end
end

local function ApplyCheckTexture(check)
	if check.__buiApplyingCheck then return end
	check.__buiApplyingCheck = true
	check:SetTexture(BUILib.GetLibMedia('check'))
	check:SetVertexColor(Theme.GetAccent())
	check.__buiApplyingCheck = nil
end

local function SkinCheck(check)
	if not check or check.__buiSkinned then return end
	check.__buiSkinned = true
	ApplyCheckTexture(check)
	hooksecurefunc(check, 'SetAtlas', ApplyCheckTexture)
	hooksecurefunc(check, 'SetTexture', ApplyCheckTexture)
	Theme.RegisterAccentElement(check, function(element, red, green, blue)
		element:SetVertexColor(red, green, blue, 1)
	end)
end

local function SkinLine(line)
	SkinCheck(line.Check)
	ApplySkinFont(line.Text, 'line')
	local lineText = line.Text
	if lineText then
		wrapAdjustedText.objectives[lineText] = true
		local wantWrap = GetSettings().singleLineObjectives == false
		if lineText.__buiWordWrap ~= wantWrap then
			lineText.__buiWordWrap = wantWrap
			lineText:SetWordWrap(wantWrap)
		end
	end
	local dash = line.Dash
	if dash and not dashFontStrings[dash] then
		dashFontStrings[dash] = true
		dash:SetAlpha(DashesVisible() and 1 or 0)
	end
end

local function OnAddBlock(_, block)
	if not IsEnabled() or not block then return end
	SkinItemButton(block.ItemButton or block.itemButton)
	if block.addedRegions and not InCombatLockdown() then
		local raisedLevel = (block.GetFrameLevel and block:GetFrameLevel() or 0) + 5
		for region in pairs(block.addedRegions) do
			if region.SetFrameLevel and region:GetFrameLevel() ~= raisedLevel then region:SetFrameLevel(raisedLevel) end
		end
	end
	HideBlizzardTexture(block.HeaderGlow)
	ApplySkinFont(block.HeaderText, 'title')
	local blockHeaderText = block.HeaderText
	if blockHeaderText then
		wrapAdjustedText.titles[blockHeaderText] = true
		local wantWrap = not SingleLineTitlesEnabled()
		if blockHeaderText.__buiWordWrap ~= wantWrap then
			blockHeaderText.__buiWordWrap = wantWrap
			blockHeaderText:SetWordWrap(wantWrap)
		end
	end
	local currentLine = block.currentLine
	if currentLine then SkinLine(currentLine) end
	if block.usedLines then
		for _, line in pairs(block.usedLines) do
			SkinLine(line)
		end
	end
	local poiButton = block.poiButton
	if poiButton and not hiddenPoiButtons[poiButton] then
		hiddenPoiButtons[poiButton] = true
		poiButton:SetScale(POI_BUTTON_SCALE)
		SetPoiButtonVisible(poiButton, GetSettings().showQuestIcons == true)
	end
	if not block.__buiPoiAnchorHook and block.AddPOIButton then
		block.__buiPoiAnchorHook = true
		hooksecurefunc(block, 'AddPOIButton', function(self)
			if not IsEnabled() then return end
			local button = self.poiButton
			if button and self.HeaderText then
				button:ClearAllPoints()
				button:SetPoint('RIGHT', self.HeaderText, 'LEFT', POI_ANCHOR_OFFSET_X, 0)
			end
		end)
	end
	if not block.__buiMenuHook then
		block.__buiMenuHook = true
		block:HookScript('OnMouseDown', function(self)
			pendingMenuQuestID = self.poiQuestID or self.id
		end)
	end
	if not block.__buiColorHook then
		block.__buiColorHook = true
		if block.SetStringText then hooksecurefunc(block, 'SetStringText', OnSetStringText) end
		if block.UpdateHighlight then hooksecurefunc(block, 'UpdateHighlight', OnUpdateHighlight) end
	end
	OnUpdateHighlight(block)
end

local function OnGetProgressBar(tracker, key)
	if not IsEnabled() then return end
	local progressBar = tracker.usedProgressBars and tracker.usedProgressBars[key]
	if progressBar then SkinBar(progressBar.Bar) end
end

local function OnGetTimerBar(tracker, key)
	if not IsEnabled() then return end
	local timerBar = tracker.usedTimerBars and tracker.usedTimerBars[key]
	if timerBar then SkinBar(timerBar.Bar) end
end

local hookedTrackers = {}

local function ApplyTrackerHidden()
	if InCombatLockdown() then
		BUI.Events:AfterCombat(ApplyTrackerHidden, 'Skinning.TrackerHidden')
		return
	end
	Skin.StashTracker(IsEnabled() and GetSettings().trackerHidden == true)
end

Scenario.headers = {}
Scenario.headerMixins = { 'UIWidgetTemplateScenarioHeaderDelvesMixin', 'UIWidgetTemplateScenarioHeaderTimerMixin', 'UIWidgetTemplateScenarioHeaderCurrenciesAndBackgroundMixin' }
Scenario.headerOverhangKeys = { 'SpellContainer', 'CurrencyContainer', 'RewardFrame' }
Scenario.headerBackdropInset = 1
Scenario.headerBackdropPad = 4

Scenario.FitHeaderBackdrop = function(widget, backdrop)
	local bottom = widget:GetBottom()
	if not bottom then return false end
	local keys, lowest = Scenario.headerOverhangKeys, bottom
	for keyIndex = 1, #keys do
		local child = widget[keys[keyIndex]]
		if child and child:IsShown() then
			local childBottom = child:GetBottom()
			if childBottom and childBottom < lowest then lowest = childBottom end
		end
	end
	local inset = Scenario.headerBackdropInset
	local drop = bottom - lowest
	if drop > 0 then drop = drop + Scenario.headerBackdropPad end
	if backdrop._buiHeaderDrop == drop then return true end
	backdrop._buiHeaderDrop = drop
	backdrop:ClearAllPoints()
	backdrop:SetPoint('TOPLEFT', widget, 'TOPLEFT', inset, -inset)
	backdrop:SetPoint('BOTTOMRIGHT', widget, 'BOTTOMRIGHT', -inset, inset - drop)
	return true
end

Scenario.ApplyHeader = function(widget)
	Scenario.headers[widget] = true
	local enabled = IsEnabled()
	local alpha = enabled and 0 or 1
	widget.Frame:SetAlpha(alpha)
	widget.ThemeOverlay:SetAlpha(alpha)
	widget.DecorationBottomLeft:SetAlpha(alpha)
	local backdrop = skinnedBars[widget]
	if enabled then
		if not backdrop then
			backdrop = Skin3.ChildBackdrop(widget, { bg = Theme.bg.light, border = Theme.border.light })
			skinnedBars[widget] = backdrop
		end
		if not Scenario.FitHeaderBackdrop(widget, backdrop) then
			C_Timer.After(0, function() Scenario.FitHeaderBackdrop(widget, backdrop) end)
		end
		ApplySkinFont(widget.HeaderText, 'title')
		widget.HeaderText:SetTextColor(Skin.TrackerColorRGB('title'))
		local timerBar = widget.TimerBar
		if timerBar then
			SkinBar(timerBar)
			timerBar:SetStatusBarTexture(FLAT_TEXTURE)
			timerBar:SetStatusBarColor(Theme.GetAccent())
			ApplySkinFont(widget.Timer.Text, 'timer')
		end
	end
	if backdrop then backdrop:SetShown(enabled and widget:IsShown()) end
end

Scenario.TrackHeader = function(widget)
	if Scenario.headers[widget] or not widget.Frame or not widget.HeaderText then return end
	hooksecurefunc(widget, 'Setup', Scenario.ApplyHeader)
	Scenario.ApplyHeader(widget)
end

Scenario.ScanHeaders = function()
	local scenarioTracker = _G.ScenarioObjectiveTracker
	local container = scenarioTracker and scenarioTracker.StageBlock and scenarioTracker.StageBlock.WidgetContainer
	local frames = container and container.widgetFrames
	if type(frames) ~= 'table' then return end
	for _, widget in pairs(frames) do Scenario.TrackHeader(widget) end
end

Scenario.InstallHeaderHooks = function()
	if Scenario.headerHooked then return end
	Scenario.headerHooked = true
	for _, mixinName in ipairs(Scenario.headerMixins) do
		local mixin = _G[mixinName]
		if mixin then hooksecurefunc(mixin, 'Setup', Scenario.ApplyHeader) end
	end
end

Scenario.SyncStageBackdrop = function(stageBlock)
	local backdrop = skinnedBars[stageBlock]
	if not backdrop then return end
	local blockParent = stageBlock:GetParent()
	if backdrop:GetParent() ~= blockParent then
		backdrop:SetParent(blockParent)
		backdrop:SetFrameLevel(math.max(0, stageBlock:GetFrameLevel() - 1))
	end
	backdrop:SetShown(IsEnabled() and stageBlock:IsShown() and not stageBlock.widgetSetID)
end

function Scenario.Install()
	Scenario.ScanHeaders()
	Scenario.InstallHeaderHooks()
end

function Scenario.Remove()
	for widget in pairs(Scenario.headers) do Scenario.ApplyHeader(widget) end
end

local function Install()
	if not IsEnabled() then return end
	Scenario.Install()
	InstallMenuHook()
	InstallQuestTipHook()

	local trackerFrame = _G.ObjectiveTrackerFrame
	if trackerFrame then
		if trackerFrame.Header then SkinHeader(trackerFrame.Header) end
		if trackerFrame.NineSlice then HideFrameTextures(trackerFrame.NineSlice) end
		if not hookedTrackers[trackerFrame] then
			hookedTrackers[trackerFrame] = true
			hooksecurefunc(trackerFrame, 'UpdateClampOffsets', Skin.TrackerClamp)
		end
	end

	for _, trackerName in ipairs(TRACKER_NAMES) do
		local tracker = _G[trackerName]
		if tracker then
			if tracker.Header then SkinHeader(tracker.Header) end
			if not hookedTrackers[tracker] then
				hookedTrackers[tracker] = true
				if tracker.AddBlock then hooksecurefunc(tracker, 'AddBlock', OnAddBlock) end
				if tracker.GetProgressBar then hooksecurefunc(tracker, 'GetProgressBar', OnGetProgressBar) end
				if tracker.GetTimerBar then hooksecurefunc(tracker, 'GetTimerBar', OnGetTimerBar) end
				if tracker.OnBlockHeaderLeave then hooksecurefunc(tracker, 'OnBlockHeaderLeave', HideQuestTip) end
			end
		end
	end

	SkinStageBlock()
	EnsureTrackerCard()
	ApplyHeaderRowVisibility()
	ApplyTrackerHidden()

	BUI.Events:Register('QUEST_LOG_UPDATE', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_WATCH_LIST_CHANGED', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_ACCEPTED', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_REMOVED', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_TURNED_IN', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_WATCH_UPDATE', 'Skinning.TrackerProgress', OnQuestProgress)
	BUI.Events:Register('ZONE_CHANGED_NEW_AREA', 'Skinning.TrackerItemKey', QuestItem.Update)
	BUI.Events:Register('BAG_UPDATE_COOLDOWN', 'Skinning.TrackerItemCooldown', QuestItem.UpdateCooldown)
	queueQuestCacheRefresh()
end

BUI.Events:OnLogin('Skinning.ObjectiveTracker', Install)

Skin.OnToggle('objectivetracker', function(enabled)
	Skin.ClearTrackerColorCache()
	if enabled then
		Install()
		for _, element in ipairs(addedElements) do element:Show() end
		for bar, backdrop in pairs(skinnedBars) do backdrop:SetShown(bar:IsShown()) end
		Scenario.SyncStageBackdrop(_G.ScenarioObjectiveTracker.StageBlock)
		for button in pairs(hiddenPoiButtons) do button:SetScale(POI_BUTTON_SCALE) end
		ApplyPoiVisibility()
		ApplyDashAlpha()
		ApplyTitleWrap()
		Skin.ApplyTrackerSeparators()
		ApplyTextSettings()
		Skin.ApplyTrackerColors()
		queueQuestCacheRefresh()
		QuestItem.Update()
		for _, texture in ipairs(hiddenTextures) do ReassertHidden(texture) end
		return
	end

	for _, element in ipairs(addedElements) do element:Hide() end
	for _, backdrop in pairs(skinnedBars) do backdrop:Hide() end
	if trackerCard then trackerCard:Hide() end
	for button in pairs(hiddenPoiButtons) do
		button:SetScale(1)
		button:ClearAllPoints()
	end
	ApplyTitleWrap()
	ApplyHeaderRowVisibility()
	HideQuestTip()
	Scenario.Remove()
	if trackerCard then trackerCard._buiClamp = nil end
	_G.ObjectiveTrackerFrame:UpdateClampOffsets()
	QuestItem.Update()
	ApplyPoiVisibility()
	ApplyDashAlpha()
	ApplyTrackerHidden()
	RepaintBlizzardColors()
	for _, texture in ipairs(hiddenTextures) do
		if texture.__buiOldAtlas then
			texture:SetAtlas(texture.__buiOldAtlas)
		elseif texture.__buiOldTexture then
			texture:SetTexture(texture.__buiOldTexture)
		end
		texture:SetAlpha(texture.__buiOldAlpha or 1)
	end
	for fontString, entry in pairs(restoreFonts) do
		if entry.font then fontString:SetFont(entry.font, entry.size, entry.flags) end
	end
	for header, entry in pairs(restoreHeaders) do
		local text = header.Text
		if text and entry.red then
			text:SetTextColor(entry.red, entry.green, entry.blue, entry.alpha)
		end
	end
end)

Skin.RegisterSkin('objectivetracker', {
	name = 'Objective Tracker',
	description = 'Tooltip-style dark cards behind each tracker section, clean library fonts on quest text, accent-marked headers, flat progress bars, and square quest item icons. The OBJECTIVES header carries quest counts and track presets. Move and size the tracker in Edit Mode.',
	icon = 'Interface\\Icons\\INV_Misc_Book_07',
	settingsWidth = 430,
	settingsHeight = 1400,
	buildSettings = function(content)
		local settings = GetSettings()
		local pageKit = PageKit
		local GAP = pageKit.GAP
		local width = content.width

		local textHeight = pageKit.CardHeight(3)
		local colorsHeight = pageKit.CardHeight(7)
		local panelHeight = pageKit.CardHeight(10)
		local behaviorHeight = pageKit.CardHeight(2)
		local positionHeight = pageKit.CardHeight(1)
		local behaviorTop = textHeight + GAP + colorsHeight + GAP + panelHeight + GAP
		local positionTop = behaviorTop + behaviorHeight + GAP

		local root = CreateFrame('Frame', nil, content.child)
		root:SetPoint('TOPLEFT', 0, -8)
		root:SetSize(width, positionTop + positionHeight)

		local function MakeCard(title, y, height)
			local cardWidget = Controls.SettingsCard(root, { title = title, width = width })
			local card = cardWidget.frame
			card:SetSize(width, height)
			card:SetPoint('TOPLEFT', 0, -y)
			card:SetFrameLevel((root:GetFrameLevel() or 0) + 5)
			return card
		end

		local textCard = MakeCard('TEXT', 0, textHeight)
		local colorsCard = MakeCard('COLORS', textHeight + GAP, colorsHeight)
		local panelCard = MakeCard('PANEL', textHeight + GAP + colorsHeight + GAP, panelHeight)
		local behaviorCard = MakeCard('BEHAVIOR', behaviorTop, behaviorHeight)
		local positionCard = MakeCard('POSITION', positionTop, positionHeight)

		local fontCog = pageKit.SettingsIcon(textCard, {
			title = 'TEXT', tooltip = 'Size & outline', options = {
				{ kind = 'slider', label = 'Font Size', min = 8, max = 16,
				  get = function() return settings.fontSize or DEFAULT_FONT_SIZE end,
				  set = function(value) settings.fontSize = value end, apply = ApplyTextSettings },
				{ label = 'Outlined Text',
				  get = function() return settings.fontOutline == true end,
				  set = function(value) settings.fontOutline = value end, apply = ApplyTextSettings },
			},
		})
		local fontItems = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		table.insert(fontItems, 1, { value = LIBRARY_FONT_OPTION, text = 'Tooltip Font' })
		local fontDropdown = Controls.Dropdown(textCard, nil, fontItems, settings.font or LIBRARY_FONT_OPTION, function(value)
			settings.font = value
			ApplyTextSettings()
		end, nil, 150)
		pageKit.Row(textCard, 38, 'Font', fontCog)
		pageKit.AttachLeft(fontDropdown, fontCog)

		local singleLineToggle = Controls.SwitchToggle(textCard, nil, settings.singleLineTitles ~= false, function(value)
			settings.singleLineTitles = value
			ApplyTitleWrap()
		end)
		pageKit.Row(textCard, 78, 'Single-line Titles', singleLineToggle)

		local singleLineObjectivesToggle = Controls.SwitchToggle(textCard, nil, settings.singleLineObjectives ~= false, function(value)
			settings.singleLineObjectives = value
			ApplyTitleWrap()
		end)
		pageKit.Row(textCard, 118, 'Single-line Objectives', singleLineObjectivesToggle)

		local customColorsToggle = Controls.SwitchToggle(colorsCard, nil, settings.customColors ~= false, function(value)
			settings.customColors = value
			Skin.ApplyTrackerColors()
		end)
		pageKit.Row(colorsCard, 38, 'Custom Colors', customColorsToggle)

		local function ColorRow(y, label, key)
			local color = Skin.TrackerColor(key)
			local swatch = Controls.ColorSwatch(colorsCard, { r = color[1], g = color[2], b = color[3], a = 1, hasOpacity = false, callback = function(red, green, blue)
				settings.colors = settings.colors or {}
				settings.colors[key] = { red, green, blue }
				Skin.ApplyTrackerColors()
			end })
			pageKit.Row(colorsCard, y, label, swatch)
		end
		ColorRow(78, 'Quest Title', 'title')
		ColorRow(118, 'Title Hover', 'hover')
		ColorRow(158, 'Objective', 'objective')
		ColorRow(198, 'Completed Objective', 'completed')
		ColorRow(238, 'Ready to Turn In', 'ready')
		ColorRow(278, 'Time Left', 'timeLeft')

		local backgroundCog = pageKit.SettingsIcon(panelCard, {
			title = 'PANEL', tooltip = 'Background', options = {
				{ kind = 'slider', label = 'Opacity', min = 0, max = 100,
				  get = function() return settings.cardOpacity or DEFAULT_CARD_OPACITY end,
				  set = function(value) settings.cardOpacity = value end, apply = ApplyCardStyle },
				{ label = 'Border',
				  get = function() return settings.cardBorder ~= false end,
				  set = function(value) settings.cardBorder = value end, apply = ApplyCardStyle,
				  swatch = function()
					  local borderColor = settings.cardBorderColor or Theme.border.light
					  return { r = borderColor[1], g = borderColor[2], b = borderColor[3], a = borderColor[4] or 1,
						  callback = function(red, green, blue, alpha)
							  settings.cardBorderColor = { red, green, blue, alpha }
							  ApplyCardStyle()
						  end }
				  end },
			},
		})
		pageKit.Row(panelCard, 38, 'Background', backgroundCog)

		local textureItems = BUI.BuildTextureDropdownItems()
		table.insert(textureItems, 1, { value = FLAT_TEXTURE_OPTION, text = 'Flat' })
		local textureDropdown = Controls.Dropdown(panelCard, nil, textureItems, settings.cardTexture or FLAT_TEXTURE_OPTION, function(value)
			settings.cardTexture = value
			ApplyCardStyle()
		end, nil, 150)
		pageKit.Row(panelCard, 78, 'Texture', textureDropdown)
		local textureTint = settings.cardTextureColor or CARD_TEXTURE_TINT
		local textureSwatch = Controls.ColorSwatch(panelCard, { r = textureTint[1], g = textureTint[2], b = textureTint[3], a = 1, hasOpacity = false, callback = function(red, green, blue)
			settings.cardTextureColor = { red, green, blue }
			ApplyCardStyle()
		end })
		pageKit.AttachLeft(textureSwatch, textureDropdown)

		local separatorRed, separatorGreen, separatorBlue, separatorAlpha = Skin.TrackerSeparatorColor()
		local separatorSwatch = Controls.ColorSwatch(panelCard, { r = separatorRed, g = separatorGreen, b = separatorBlue, a = separatorAlpha, callback = function(red, green, blue, alpha)
			settings.separatorColor = { red, green, blue, alpha }
			Skin.ApplyTrackerSeparators()
		end })
		pageKit.Row(panelCard, 358, 'Separator Color', separatorSwatch)

		local hideTrackerToggle = Controls.SwitchToggle(panelCard, nil, settings.trackerHidden == true, function(value)
			settings.trackerHidden = value
			ApplyTrackerHidden()
		end)
		pageKit.Row(panelCard, 398, 'Hide Tracker Completely', hideTrackerToggle)

		local questIconsToggle = Controls.SwitchToggle(panelCard, nil, settings.showQuestIcons == true, function(value)
			settings.showQuestIcons = value
			ApplyPoiVisibility()
		end)
		pageKit.Row(panelCard, 118, 'Quest Type Icons', questIconsToggle)

		local dashesToggle = Controls.SwitchToggle(panelCard, nil, settings.showDashes == true, function(value)
			settings.showDashes = value
			ApplyDashAlpha()
		end)
		pageKit.Row(panelCard, 158, 'Objective Dashes', dashesToggle)

		local chimeDropdown = Controls.Dropdown(panelCard, nil, BUI.BuildSoundDropdownItems(), settings.completionSound or 'None', function(value)
			settings.completionSound = value
			BUI.PlaySoundByName(value)
		end, nil, 150)
		pageKit.Row(panelCard, 198, 'Completion Sound', chimeDropdown)

		local itemKeybind = Controls.Keybind(panelCard, nil, settings.questItemKey or 'NONE', function(value)
			settings.questItemKey = value
			QuestItem.Update()
		end, 190)
		pageKit.Row(panelCard, 238, 'Quest Item Key', itemKeybind)

		local tooltipToggle = Controls.SwitchToggle(panelCard, nil, settings.questTooltip ~= false, function(value)
			settings.questTooltip = value
		end)
		pageKit.Row(panelCard, 278, 'Quest Tooltip', tooltipToggle)

		local headerRowToggle = Controls.SwitchToggle(panelCard, nil, settings.showHeaderRow ~= false, function(value)
			settings.showHeaderRow = value
			if value == false then
				settings.trackerTrackSpec = nil
				QuestFilter.UpdateTint()
			end
			ApplyHeaderRowVisibility()
		end)
		pageKit.Row(panelCard, 318, 'Objectives Header', headerRowToggle)

		local resetItemButton = Controls.Button(positionCard, 'Reset', 84, function()
			local positions = BUI.GetDB().framePositions
			if positions then positions[QuestItem.POSITION_KEY] = nil end
			if QuestItem.button then QuestItem.button.placedVisible = nil end
			QuestItem.Update()
		end)
		pageKit.Row(positionCard, 38, 'Reset Item Button', resetItemButton)

		local itemButtonToggle = Controls.SwitchToggle(behaviorCard, nil, settings.showQuestItemButton == true, function(value)
			settings.showQuestItemButton = value
			QuestItem.Update()
		end)
		pageKit.Row(behaviorCard, 38, 'Quest Item Button', itemButtonToggle)

		local completionMessageToggle = Controls.SwitchToggle(behaviorCard, nil, settings.completionMessage == true, function(value)
			settings.completionMessage = value
		end)
		pageKit.Row(behaviorCard, 78, 'Completion Messages', completionMessageToggle)

		content:Refresh()
	end,
})
