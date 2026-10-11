local _, BUI = ...

local pairs = pairs
local ipairs = ipairs
local select = select
local Wrap = BUI.Profiler.Wrap
local After = BUI.Profiler.After

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local LibSkin = BUILib.Skin
local LibWidget = BUILib.Widget
local FONT = BUILib.Font or STANDARD_TEXT_FONT
local Skin = BUI.Skinning
local Pixel = BUI.Pixel
local Painter = BUI.Painter
local sharedMedia = LibStub('LibSharedMedia-3.0', true)

local LIBRARY_FONT_OPTION = 'LIBRARY'
local FLAT_TEXTURE_OPTION = 'FLAT'
local ROLE_SIZE_DELTA     = { caption = -1, line = 0, title = 1, header = 2, timer = 8 }
local TRACKER_STASH_SCALE = 0.01
local TIP_TEXT_MAX_LENGTH = 46
local CARD_TEXTURE_TINT   = { 0.18, 0.19, 0.21 }
local READY_COUNT_HEX     = 'ffd140'
local FLASH_SECONDS       = 0.7

local GLYPH_SIZE          = 10
local BAR_LABEL_SIZE      = 11
local HEADER_TEXT_INSET   = 11
local RULE_GAP            = 8
local MINIMIZE_SIZE       = 15
local KEY_TOOL_WIDTH      = 120
local MODIFIER_KEYS       = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }
local BAR_ICON_SIZE       = 20
local CARD_PAD_LEFT       = 22
local CARD_PAD_RIGHT      = 10
local CARD_PAD_Y          = 6
local POI_BUTTON_SCALE    = 0.8
local POI_ANCHOR_OFFSET_X = -10
local FLAT_TEXTURE        = 'Interface\\Buttons\\WHITE8X8'

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

local QUEST_CACHE_EVENTS = {
	'QUEST_LOG_UPDATE', 'QUEST_WATCH_LIST_CHANGED', 'QUEST_ACCEPTED', 'QUEST_REMOVED', 'QUEST_TURNED_IN', 'PLAYER_ENTERING_WORLD',
}

local addedElements = {}
local restoreHeaders = {}
local moduleHeaders = {}
local headerRoles = {}
local chevrons = {}
local rules = {}
local skinnedBars = {}
local hiddenTextures = {}
local restoreFonts = {}
local hiddenPoiButtons = {}
local dashFontStrings = {}
local linkedPanels = {}
local wrapAdjustedText = { titles = {}, objectives = {} }
local readyQuestIDs = {}
local readyByQuest, nextReadyByQuest = {}, {}
local trackerCard, headerCounts, headerFilter
local trackerSkinned = false
local trackerStashScale, trackerFadedOut
local watchedCount, readyCount = 0, 0
local fontGeneration = 1
local pendingMenuQuestID
local questClassificationLabels
local styleOverrides
local Scenario = {}
local QuestFilter = {}
local QuestItem = { POSITION_KEY = 'trackerquestitem', SIZE = 40 }
local QuestInfo = { WOWHEAD_URL = 'https://www.wowhead.com/%s=%d', previousObjectives = {} }
local NO_OBJECTIVES = {}

local context = Skin.Define('objectivetracker', {
	name = 'Objective Tracker',
	description = 'A dark panel behind the tracker, quest counts and track presets on the header, flat bars and square quest items.',
	icon = 'Interface\\Icons\\INV_Misc_Book_07',
	page = 'objectivetracker',
	newLook = true,
})
local Enabled, Hook, Guard = context.Enabled, context.Hook, context.Guard

local function GetSettings()
	return BUI.GetDB().skinning.objectivetrackerSettings
end

local function GetSkinFont()
	local fontName = GetSettings().font
	if fontName == BUI.C.GLOBAL_OPTION then return BUI.GetGlobalFont() or FONT end
	if fontName ~= LIBRARY_FONT_OPTION and sharedMedia then
		return sharedMedia:Fetch('font', fontName, true) or FONT
	end
	return FONT
end

local function ApplySkinFont(fontString, role)
	if not fontString then return end
	local entry = restoreFonts[fontString]
	if not entry then
		local font, size, flags = fontString:GetFont()
		entry = { font = font, size = size, flags = flags }
		restoreFonts[fontString] = entry
	elseif entry.role == role and entry.generation == fontGeneration then
		return
	end
	entry.role, entry.generation = role, fontGeneration
	local settings = GetSettings()
	Pixel.ApplyFont(fontString, settings.fontSize + ROLE_SIZE_DELTA[role], GetSkinFont(), settings.fontOutline and 'OUTLINE' or '')
end

local function SetRawText(fontString, value)
	getmetatable(fontString).__index.SetText(fontString, value)
end

local function RoleColor(role)
	local red, green, blue = Painter.Color(role)
	return { red, green, blue }
end

local function PanelColor(key, role)
	local color = GetSettings()[key]
	if color then return color[1], color[2], color[3], color[4] or 1 end
	return Painter.Color(role)
end

local function ApplyPanelStyle(panel)
	local settings = GetSettings()
	local opacity = settings.cardOpacity / 100
	local borderRed, borderGreen, borderBlue, borderAlpha = PanelColor('cardBorderColor', 'skinBorder')
	if settings.cardBorder == false then borderAlpha = 0 end
	local texturePath = settings.cardTexture ~= FLAT_TEXTURE_OPTION and sharedMedia and sharedMedia:Fetch('statusbar', settings.cardTexture, true)
	local overlay = panel.__buiCardTexture
	if texturePath then
		if not overlay then
			overlay = panel:CreateTexture(nil, 'BACKGROUND', nil, 1)
			local inset = Pixel.PixelSize(1)
			overlay:SetPoint('TOPLEFT', panel, 'TOPLEFT', inset, -inset)
			overlay:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -inset, inset)
			panel.__buiCardTexture = overlay
		end
		local tint = settings.cardTextureColor or CARD_TEXTURE_TINT
		overlay:SetTexture(texturePath)
		overlay:SetVertexColor(tint[1], tint[2], tint[3], opacity)
		overlay:Show()
		opacity = 0
	elseif overlay then
		overlay:Hide()
	end
	local red, green, blue = Painter.Color('skinBackground')
	panel:SetBackdropColor(red, green, blue, opacity)
	panel:SetBackdropBorderColor(borderRed, borderGreen, borderBlue, borderAlpha)
end

local function ApplyCardStyle()
	if trackerCard then ApplyPanelStyle(trackerCard) end
	for panel in pairs(linkedPanels) do ApplyPanelStyle(panel) end
end

local function PaintRule(rule)
	rule:SetColorTexture(PanelColor('separatorColor', 'skinLine'))
end

local function PaintRules()
	for rule in pairs(rules) do PaintRule(rule) end
end

local function PaintGlyph(glyph, bright)
	glyph:SetVertexColor(Painter.Color(bright and 'skinText' or 'skinLabel'))
end

function Skin.RegisterTrackerPanel(frame)
	linkedPanels[frame] = true
	ApplyPanelStyle(frame)
end

function Skin.GetTrackerPanelOutsets()
	return Pixel.PixelSize(CARD_PAD_LEFT), Pixel.PixelSize(CARD_PAD_RIGHT), Pixel.PixelSize(CARD_PAD_Y)
end

local function IsFiniteNumber(value)
	if type(value) ~= 'number' or issecretvalue(value) then return false end
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
	if not trackerCard then return end
	local trackerFrame = ObjectiveTrackerFrame
	local padLeft = Pixel.PixelSize(CARD_PAD_LEFT)
	local padRight = Pixel.PixelSize(CARD_PAD_RIGHT)
	local padY = Pixel.PixelSize(CARD_PAD_Y)
	trackerCard:ClearAllPoints()
	trackerCard:SetPoint('TOPLEFT', trackerFrame, 'TOPLEFT', -padLeft, padY)
	trackerCard:SetPoint('TOPRIGHT', trackerFrame, 'TOPRIGHT', padRight, padY)
	if trackerFrame:IsCollapsed() then
		trackerCard:SetPoint('BOTTOM', trackerFrame.Header, 'BOTTOM', 0, -padY)
	else
		trackerCard:SetHeight(GetLaidOutTrackerHeight(trackerFrame) + padY * 2)
	end
end

local function SyncTrackerCardShown()
	if not trackerCard then return end
	local trackerFrame = ObjectiveTrackerFrame
	local shown = Enabled() and not trackerStashScale and not trackerFadedOut and trackerFrame:IsVisible() and trackerFrame.NineSlice:IsShown()
	trackerCard:SetShown(shown and true or false)
end

local function TrackerClamp()
	if not trackerCard or not Enabled() or trackerStashScale then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(TrackerClamp, 'Skinning.TrackerClamp')
		return
	end
	local trackerFrame = ObjectiveTrackerFrame
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

local function StashTracker(stashed)
	if stashed == (trackerStashScale ~= nil) then return end
	local trackerFrame = ObjectiveTrackerFrame
	if stashed then
		trackerStashScale = trackerFrame:GetScale()
		trackerFrame:SetScaleBase(TRACKER_STASH_SCALE)
		trackerFrame:SetAlpha(0)
	else
		trackerFrame:SetScaleBase(trackerStashScale)
		trackerFrame:SetAlpha(1)
		trackerStashScale = nil
	end
	SyncTrackerCardShown()
	TrackerClamp()
end

local function ApplyTrackerHidden()
	if InCombatLockdown() then
		BUI.Events:AfterCombat(ApplyTrackerHidden, 'Skinning.TrackerHidden')
		return
	end
	StashTracker(Enabled() and GetSettings().trackerHidden == true)
end

local function OnTrackerAlpha(_, alpha)
	local fadedOut = not issecretvalue(alpha) and alpha == 0 and not trackerStashScale
	if fadedOut == (trackerFadedOut or false) then return end
	trackerFadedOut = fadedOut or nil
	SyncTrackerCardShown()
end

local function CreateTrackerCard(trackerFrame)
	trackerCard = CreateFrame('Frame', 'BUI_TrackerPanel', UIParent, 'BackdropTemplate')
	trackerCard:SetFrameStrata('LOW')
	trackerCard:SetFrameLevel(0)
	Pixel.SetTemplate(trackerCard, 0, 0, 0, 0, 0, 0, 0, 0, 1)
	trackerCard:Hide()
	trackerCard:HookScript('OnSizeChanged', Wrap('Skin.ObjectiveTracker tracker clamp', TrackerClamp))

	local nineSlice = trackerFrame.NineSlice
	local syncShown = Wrap('Skin.ObjectiveTracker card sync', SyncTrackerCardShown)
	Hook(trackerFrame, 'SetCollapsed', UpdateCardAnchors)
	Hook(trackerFrame, 'SetAlpha', OnTrackerAlpha)
	Hook(nineSlice, 'SetPoint', UpdateCardAnchors)
	Hook(nineSlice, 'SetAlpha', function(self, alpha)
		if alpha ~= 0 then self:SetAlpha(0) end
	end)
	nineSlice:HookScript('OnShow', syncShown)
	nineSlice:HookScript('OnHide', syncShown)
	trackerFrame:HookScript('OnShow', syncShown)
	trackerFrame:HookScript('OnHide', syncShown)
end

local function TrackerColorRGB(key)
	local color = GetSettings().colors[key]
	return color[1], color[2], color[3], 1
end

local function GetStyleOverrides()
	if styleOverrides then return styleOverrides end
	local colors = GetSettings().colors
	local map = {
		Header            = colors.title,
		HeaderHighlight   = colors.hover,
		Normal            = colors.objective,
		NormalHighlight   = colors.hover,
		Complete          = colors.completed,
		CompleteHighlight = colors.completed,
		TimeLeft          = colors.timeLeft,
		TimeLeftHighlight = colors.hover,
	}
	styleOverrides = {}
	for key, replacement in pairs(map) do
		local style = OBJECTIVE_TRACKER_COLOR[key]
		if style then styleOverrides[style] = replacement end
	end
	return styleOverrides
end

local function PaintFromStyle(fontString, style)
	local replacement = style and GetStyleOverrides()[style]
	if replacement then fontString:SetTextColor(replacement[1], replacement[2], replacement[3], 1) end
end

local function IsReadyBlock(block)
	local questID = block.poiQuestID
	return questID and readyQuestIDs[questID] == true
end

local function OnSetStringText(block, fontString, _, _, colorStyle, useHighlight)
	if GetSettings().customColors == false then return end
	if fontString == block.HeaderText and IsReadyBlock(block) then
		fontString:SetTextColor(TrackerColorRGB(useHighlight and 'hover' or 'ready'))
		return
	end
	local effective = colorStyle or OBJECTIVE_TRACKER_COLOR.Normal
	if useHighlight and effective.reverse then effective = effective.reverse end
	PaintFromStyle(fontString, effective)
end

local function OnUpdateHighlight(block)
	if GetSettings().customColors == false then return end
	local headerText = block.HeaderText
	if headerText then
		local key = IsReadyBlock(block) and 'ready' or 'title'
		headerText:SetTextColor(TrackerColorRGB(block.isHighlighted and 'hover' or key))
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
		if tracker then
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

local function ApplyTrackerColors()
	styleOverrides = nil
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
	local red, green, blue = Painter.Color('skinLabel')
	GameTooltip:AddLine('Ctrl+drag to move', red, green, blue)
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

	local edgeRed, edgeGreen, edgeBlue = Painter.Color('skinBorder')
	Pixel.ApplyBorder(button, 1, edgeRed, edgeGreen, edgeBlue, 1)
	button:SetScript('OnEnter', BUI.Profiler.Script('Skin.ObjectiveTracker button OnEnter', QuestItem.OnEnter))
	button:SetScript('OnLeave', GameTooltip_Hide)
	button:SetScript('OnDragStart', BUI.Profiler.Script('Skin.ObjectiveTracker button OnDragStart', QuestItem.OnDragStart))
	button:SetScript('OnDragStop', BUI.Profiler.Script('Skin.ObjectiveTracker button OnDragStop', QuestItem.OnDragStop))
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
	local wantBinding = Enabled() and key and key ~= 'NONE'
	local wantButton = Enabled() and settings.showQuestItemButton == true
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

local function PressedKey(key)
	return (IsAltKeyDown() and 'ALT-' or '') .. (IsControlKeyDown() and 'CTRL-' or '') .. (IsShiftKeyDown() and 'SHIFT-' or '') .. key
end

function QuestItem.KeyTool(ui)
	return { kind = 'custom', build = function(row)
		local settings = GetSettings()
		local holder = CreateFrame('Frame', nil, row)
		local listening = false
		local button
		local function Label()
			if listening then return 'Press a key' end
			local key = settings.questItemKey
			if not key or key == 'NONE' then return 'Set key' end
			return BUI.Keybinds.Format(key)
		end
		local function Listen(on)
			listening = on
			holder:EnableKeyboard(on)
			button:SetText(Label())
		end
		button = ui.Button(holder, Label(), 'secondary', function()
			if InCombatLockdown() then return end
			Listen(not listening)
		end)
		button:SetPoint('RIGHT')
		button:HookScript('OnEnter', function(self) LibWidget.ShowTip(self, 'Click, then press a key. Escape clears it.') end)
		button:HookScript('OnLeave', LibWidget.HideTip)
		holder:SetSize(KEY_TOOL_WIDTH, button:GetHeight())
		holder:SetScript('OnKeyDown', function(_, key)
			if MODIFIER_KEYS[key] then return end
			settings.questItemKey = key == 'ESCAPE' and 'NONE' or PressedKey(key)
			Listen(false)
			QuestItem.Update()
		end)
		holder:SetScript('OnHide', function()
			if listening then Listen(false) end
		end)
		return holder
	end }
end

function QuestInfo.AddWowheadButton(rootDescription, kind, id)
	if not id then return end
	rootDescription:CreateButton('Copy Wowhead Link', function()
		BUI.Modals.Input({
			title = 'Wowhead Link',
			message = 'Press Ctrl+C to copy.',
			defaultText = QuestInfo.WOWHEAD_URL:format(kind, id),
			confirmText = 'Done',
		})
	end)
end

function QuestInfo.FindWaypoint(questID)
	local mapID, waypointX, waypointY = C_QuestLog.GetNextWaypoint(questID)
	if mapID then return mapID, waypointX, waypointY end
	local uiMapID = GetQuestUiMapID(questID)
	if not uiMapID or uiMapID == 0 then uiMapID = C_Map.GetBestMapForUnit('player') end
	if not uiMapID or uiMapID == 0 then return end
	waypointX, waypointY = C_QuestLog.GetNextWaypointForMap(questID, uiMapID)
	if waypointX then return uiMapID, waypointX, waypointY end
	for _, questPOI in ipairs(C_QuestLog.GetQuestsOnMap(uiMapID) or {}) do
		if questPOI.questID == questID and questPOI.x and questPOI.y then return uiMapID, questPOI.x, questPOI.y end
	end
	local taskX, taskY = C_TaskQuest.GetQuestLocation(questID, uiMapID)
	if taskX and taskY then return uiMapID, taskX, taskY end
end

function QuestInfo.AddTomTomButton(rootDescription)
	local TomTom = _G.TomTom
	local questID = pendingMenuQuestID
	if not TomTom or not TomTom.AddWaypoint or not questID then return end
	rootDescription:CreateButton('TomTom Waypoint', function()
		local mapID, waypointX, waypointY = QuestInfo.FindWaypoint(questID)
		if not mapID then
			BUI.Print('No map location available for that quest.')
			return
		end
		local title = C_QuestLog.GetTitleForQuestID(questID) or ('Quest ' .. questID)
		TomTom:AddWaypoint(mapID, waypointX, waypointY, { title = title, persistent = false, minimap = true, world = true })
	end)
end

local function InstallMenuHook()
	Menu.ModifyMenu('MENU_QUEST_OBJECTIVE_TRACKER', Guard(function(_, rootDescription)
		QuestInfo.AddTomTomButton(rootDescription)
		QuestInfo.AddWowheadButton(rootDescription, 'quest', pendingMenuQuestID)
	end))
	Menu.ModifyMenu('MENU_BONUS_OBJECTIVE_TRACKER', Guard(function(_, rootDescription, block)
		QuestInfo.AddWowheadButton(rootDescription, 'quest', block and block.id)
	end))
	Menu.ModifyMenu('MENU_ACHIEVEMENT_TRACKER', Guard(function(_, rootDescription, block)
		QuestInfo.AddWowheadButton(rootDescription, 'achievement', block and block.id)
	end))
end

local function SingleLineTitlesEnabled()
	return GetSettings().singleLineTitles ~= false
end

local function ApplyWrap(fontStrings, wrap)
	for fontString in pairs(fontStrings) do
		fontString.__buiWordWrap = wrap
		fontString:SetWordWrap(wrap)
	end
end

local function ApplyTitleWrap()
	ApplyWrap(wrapAdjustedText.titles, not (Enabled() and SingleLineTitlesEnabled()))
	ApplyWrap(wrapAdjustedText.objectives, not (Enabled() and GetSettings().singleLineObjectives ~= false))
end

local function TruncateTipText(text)
	if #text > TIP_TEXT_MAX_LENGTH then return text:sub(1, TIP_TEXT_MAX_LENGTH) .. '...' end
	return text
end

local function GetQuestClassificationLabel(questID)
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
			local value = Enum.QuestClassification[memberName]
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
		rewardRows[#rewardRows + 1] = { left = 'Choose one:', leftColor = RoleColor('skinLabel') }
		for choiceIndex = 1, choiceCount do
			local name, texture, amount, quality = GetQuestLogChoiceInfo(choiceIndex, questID)
			if name then rewardRows[#rewardRows + 1] = QuestInfo.RewardRow(texture, name, amount, quality) end
		end
	end
	if #rewardRows == 0 then return end
	rows[#rows + 1] = { space = true }
	rows[#rows + 1] = { left = 'Rewards', leftColor = RoleColor('skinLabel') }
	for _, row in ipairs(rewardRows) do rows[#rows + 1] = row end
end

function QuestInfo.MetaLine(questID)
	local parts = {}
	local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
	local info = logIndex and C_QuestLog.GetInfo(logIndex)
	if info and info.level then parts[#parts + 1] = '|cffe8e8f0' .. info.level .. '|r' end
	local typeLabel, typeHex = GetQuestClassificationLabel(questID)
	if typeLabel then parts[#parts + 1] = '|cff' .. typeHex .. typeLabel .. '|r' end
	if info then
		if info.frequency == Enum.QuestFrequency.Daily then
			parts[#parts + 1] = '|cff5fb0ffDaily|r'
		elseif info.frequency == Enum.QuestFrequency.Weekly then
			parts[#parts + 1] = '|cff5fb0ffWeekly|r'
		end
		if info.suggestedGroup and info.suggestedGroup > 0 then parts[#parts + 1] = ('Group %d'):format(info.suggestedGroup) end
	end
	local uiMapID = GetQuestUiMapID(questID)
	local mapInfo = uiMapID and uiMapID ~= 0 and C_Map.GetMapInfo(uiMapID)
	if mapInfo and mapInfo.name then parts[#parts + 1] = '|cff7fb0ff' .. mapInfo.name .. '|r' end
	if #parts == 0 then return nil end
	return table.concat(parts, ' \194\183 ')
end

local function OnQuestBlockHeaderEnter(_, block, questID, isInGroup)
	if GetSettings().questTooltip == false or isInGroup or not block or not questID then return end
	local title = C_QuestLog.GetTitleForQuestID(questID)
	if not title then return end

	local rows = {}
	local meta = QuestInfo.MetaLine(questID)
	if meta then
		rows[#rows + 1] = { left = meta, right = tostring(questID), rightColor = RoleColor('skinLabel') }
		rows[#rows + 1] = { space = true }
	end
	local colors = GetSettings().colors
	for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
		if objective.text and objective.text ~= '' then
			local objectiveText = TruncateTipText(objective.text)
			if not objective.finished then
				objectiveText = objectiveText:gsub('^(%d+/%d+)', '|cff' .. READY_COUNT_HEX .. '%1|r')
			end
			rows[#rows + 1] = { left = objectiveText, leftColor = objective.finished and colors.completed or colors.objective }
		end
	end
	if readyQuestIDs[questID] then
		rows[#rows + 1] = { left = '|A:UI-QuestIcon-TurnIn-Normal:14:14|a Ready to turn in', leftColor = colors.ready }
	end
	QuestInfo.AddRewardRows(rows, questID)
	if #rows == 0 then return end

	local anchorSide = block:GetCenter() < UIParent:GetWidth() / 2 and 'RIGHT' or 'LEFT'
	LibWidget.ShowTipRows(block, title, rows, { anchor = anchorSide })
end

local function HideQuestTip()
	LibWidget.HideTip()
end

function QuestFilter.HasActive()
	local spec = GetSettings().trackerTrackSpec
	return spec ~= nil and spec ~= 'all'
end

function QuestFilter.Trackable(info)
	return not info.isHeader and not info.isTask and (not info.isBounty or C_QuestLog.IsComplete(info.questID))
end

function QuestFilter.Wanted(spec, info, inZoneHeader)
	if spec == 'all' then return true end
	if spec == 'zone' then return info.isOnMap or inZoneHeader end
	if spec == 'campaign' then return (info.campaignID or 0) ~= 0 end
	if spec == 'daily' then return (info.frequency or 0) >= Enum.QuestFrequency.Daily end
	if spec == 'ready' then return C_QuestLog.IsComplete(info.questID) end
end

function QuestFilter.Retrack(spec)
	GetSettings().trackerTrackSpec = spec
	QuestFilter.UpdateTint()
	local numEntries = C_QuestLog.GetNumQuestLogEntries()
	local maxWatches = Constants.QuestWatchConsts.MAX_QUEST_WATCHES
	local superTracked = C_SuperTrack.GetSuperTrackedQuestID()
	if not IsShiftKeyDown() then
		for entryIndex = 1, numEntries do
			local info = C_QuestLog.GetInfo(entryIndex)
			if info and QuestFilter.Trackable(info) then C_QuestLog.RemoveQuestWatch(info.questID) end
		end
	end
	local zoneName = GetRealZoneText()
	local inZoneHeader = false
	for entryIndex = 1, numEntries do
		local info = C_QuestLog.GetInfo(entryIndex)
		if info and not info.isHidden then
			if info.isHeader then
				inZoneHeader = info.title == zoneName
			elseif QuestFilter.Trackable(info) and QuestFilter.Wanted(spec, info, inZoneHeader) then
				if C_QuestLog.GetNumQuestWatches() >= maxWatches then break end
				C_QuestLog.AddQuestWatch(info.questID)
			end
		end
	end
	C_QuestLog.SortQuestWatches()
	if superTracked > 0 and C_QuestLog.GetQuestWatchType(superTracked) then
		C_SuperTrack.SetSuperTrackedQuestID(superTracked)
	end
end

function QuestFilter.UpdateTint()
	if not headerFilter then return end
	if QuestFilter.HasActive() then
		headerFilter.glyph:SetVertexColor(Painter.Color('skinTitle'))
	else
		PaintGlyph(headerFilter.glyph, false)
	end
end

function QuestFilter.ShowMenu()
	local settings = GetSettings()
	local items = { { title = 'TRACK' } }
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
	Skin.ContextMenu(items, { width = 180, anchor = headerFilter, point = 'TOPRIGHT', relPt = 'BOTTOMRIGHT', offsetY = -4 })
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
	for objectiveIndex, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
		finished[objectiveIndex] = objective.finished
		if objective.finished and previousFinished and previousFinished[objectiveIndex] == false and objective.text and objective.text ~= '' then
			UIErrorsFrame:AddMessage('Objective complete: ' .. objective.text, TrackerColorRGB('completed'))
		end
	end
	return finished
end

function QuestInfo.AnnounceReady(questID)
	local title = C_QuestLog.GetTitleForQuestID(questID)
	if title then UIErrorsFrame:AddMessage(title .. ' complete', TrackerColorRGB('ready')) end
end

local function RefreshQuestCache()
	if not Enabled() then return end
	local announce = GetSettings().completionMessage == true
	local objectivesByQuest = announce and {} or nil
	local chime, readyChanged = false, false
	wipe(readyQuestIDs)
	wipe(nextReadyByQuest)
	watchedCount, readyCount = 0, 0
	for watchIndex = 1, C_QuestLog.GetNumQuestWatches() do
		local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(watchIndex)
		if questID then
			watchedCount = watchedCount + 1
			local ready = C_QuestLog.IsComplete(questID)
			if ready then
				readyCount = readyCount + 1
				readyQuestIDs[questID] = true
				if readyByQuest[questID] == false then
					chime = true
					if announce then QuestInfo.AnnounceReady(questID) end
				end
			elseif announce then
				objectivesByQuest[questID] = QuestInfo.AnnounceObjectives(questID, QuestInfo.previousObjectives[questID])
			end
			if readyByQuest[questID] ~= ready then readyChanged = true end
			nextReadyByQuest[questID] = ready
		end
	end
	readyByQuest, nextReadyByQuest = nextReadyByQuest, readyByQuest
	QuestInfo.previousObjectives = objectivesByQuest or NO_OBJECTIVES
	UpdateHeaderCounts()
	if readyChanged then RepaintSkinColors() end
	QuestItem.Update()
	if chime then BUI.PlaySoundByName(GetSettings().completionSound) end
end

local RefreshQuestCacheSoon = BUI.Dispatcher.NewDelayed(RefreshQuestCache, 0.3, 'Quest cache refresh')

local flashQuestID

local function FlashProgressBlock()
	local questID = flashQuestID
	flashQuestID = nil
	if not questID or not Enabled() then return end
	local targetBlock
	ForEachTrackedBlock(function(block)
		if block.poiQuestID == questID then targetBlock = block end
	end)
	if not targetBlock or not targetBlock.usedLines then return end
	local red, green, blue = Painter.Color('skinTitle')
	for _, line in pairs(targetBlock.usedLines) do
		if line.Text then line.Text:SetTextColor(red, green, blue, 1) end
	end
	After('Skin.ObjectiveTracker flash restore', FLASH_SECONDS, function()
		if Enabled() then OnUpdateHighlight(targetBlock) end
	end)
end

local FlashProgressSoon = BUI.Dispatcher.NewDelayed(FlashProgressBlock, 0.15, 'Quest progress flash')

local function OnQuestProgress(_, questID)
	if not questID then return end
	flashQuestID = questID
	FlashProgressSoon()
end

local function DashesVisible()
	return not Enabled() or GetSettings().showDashes == true
end

local function ApplyDashAlpha()
	local alpha = DashesVisible() and 1 or 0
	for dash in pairs(dashFontStrings) do dash:SetAlpha(alpha) end
end

local function SetPoiButtonVisible(button, visible)
	button:SetAlpha(visible and 1 or 0)
	button:EnableMouse(visible)
end

local function ApplyPoiVisibility()
	local visible = not Enabled() or GetSettings().showQuestIcons == true
	for button in pairs(hiddenPoiButtons) do SetPoiButtonVisible(button, visible) end
end

local function HeaderControls(parent, anchor)
	local filterButton = CreateFrame('Button', nil, parent)
	filterButton:SetSize(Pixel.PixelSize(MINIMIZE_SIZE), Pixel.PixelSize(MINIMIZE_SIZE))
	filterButton:SetPoint('RIGHT', anchor, 'LEFT', -Pixel.Scale(4), 0)
	local filterGlyph = filterButton:CreateTexture(nil, 'OVERLAY')
	LibWidget.SetGlyph(filterGlyph, BUILib.GetLibMedia('eye'))
	filterGlyph:SetPoint('CENTER', 0, 0)
	filterGlyph:SetSize(Pixel.Scale(GLYPH_SIZE + 2), Pixel.Scale(GLYPH_SIZE + 2))
	filterButton.glyph = filterGlyph
	headerFilter = filterButton
	filterButton:SetScript('OnEnter', BUI.Profiler.Script('Skin.ObjectiveTracker filterButton OnEnter', function()
		PaintGlyph(filterGlyph, true)
	end))
	filterButton:SetScript('OnLeave', BUI.Profiler.Script('Skin.ObjectiveTracker filterButton OnLeave', QuestFilter.UpdateTint))
	filterButton:SetScript('OnClick', BUI.Profiler.Script('Skin.ObjectiveTracker filterButton OnClick', QuestFilter.ShowMenu))
	QuestFilter.UpdateTint()

	headerCounts = parent:CreateFontString(nil, 'ARTWORK')
	ApplySkinFont(headerCounts, 'line')
	headerCounts:SetPoint('RIGHT', filterButton, 'LEFT', -Pixel.Scale(8), 0)
	headerCounts:SetJustifyH('RIGHT')
	headerCounts:SetTextColor(Painter.Color('skinLabel'))
	UpdateHeaderCounts()
end

local function DecorateHeader(trackerFrame)
	local header = trackerFrame.Header
	local enabled = Enabled()
	if enabled and not headerFilter then HeaderControls(header, header.MinimizeButton) end
	SetRawText(header.Text, enabled and 'OBJECTIVES' or trackerFrame.headerText)
	if not headerFilter then return end
	headerFilter:SetShown(enabled)
	headerCounts:SetShown(enabled)
end

local function ApplyHeaderRowVisibility()
	local trackerFrame = ObjectiveTrackerFrame
	trackerFrame.Header:SetShown(not Enabled() or GetSettings().showHeaderRow ~= false)
	DecorateHeader(trackerFrame)
end

local function Track(element)
	addedElements[#addedElements + 1] = element
	return element
end

local function ReassertHidden(texture)
	if texture.__buiReasserting or not texture.__buiHidden then return end
	texture.__buiReasserting = true
	texture:SetTexture(nil)
	texture:SetAlpha(0)
	texture.__buiReasserting = nil
end

local function HideBlizzardTexture(texture)
	if not texture or texture.__buiHidden then return end
	texture.__buiHidden = true
	texture.__buiOldAlpha = texture:GetAlpha()
	texture.__buiOldAtlas = texture:GetAtlas()
	if not texture.__buiOldAtlas then texture.__buiOldTexture = texture:GetTexture() end
	hiddenTextures[#hiddenTextures + 1] = texture
	ReassertHidden(texture)
	Hook(texture, 'SetAtlas', ReassertHidden)
	Hook(texture, 'SetTexture', ReassertHidden)
end

local function HideFrameTextures(frame)
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region:IsObjectType('Texture') then HideBlizzardTexture(region) end
	end
end

local function SetCollapsedGlyph(header, collapsed)
	header.MinimizeButton.__buiChevron:SetRotation(collapsed and 0 or math.pi)
end

local function SkinMinimizeButton(header)
	local button = header.MinimizeButton
	HideBlizzardTexture(button:GetNormalTexture())
	HideBlizzardTexture(button:GetPushedTexture())
	HideBlizzardTexture(button:GetDisabledTexture())
	HideBlizzardTexture(button:GetHighlightTexture())
	HideFrameTextures(button)
	button:SetSize(Pixel.PixelSize(MINIMIZE_SIZE), Pixel.PixelSize(MINIMIZE_SIZE))

	local chevron = Track(button:CreateTexture(nil, 'OVERLAY'))
	chevron:SetTexture(BUILib.GetLibMedia('dropdown'))
	chevron:SetPoint('CENTER', 0, 0)
	chevron:SetSize(Pixel.Scale(GLYPH_SIZE), Pixel.Scale(GLYPH_SIZE))
	button.__buiChevron = chevron
	chevrons[chevron] = true
	PaintGlyph(chevron, false)

	button:HookScript('OnEnter', BUI.Profiler.Wrap('Skin.ObjectiveTracker minimize OnEnter', function()
		if Enabled() then PaintGlyph(chevron, true) end
	end))
	button:HookScript('OnLeave', BUI.Profiler.Wrap('Skin.ObjectiveTracker minimize OnLeave', function()
		PaintGlyph(chevron, false)
	end))

	SetCollapsedGlyph(header, header.isCollapsed)
	Hook(header, 'SetCollapsed', SetCollapsedGlyph)
end

local function PlaceHeaderRule(header)
	local text = header.Text
	header.__buiRule:SetPoint('LEFT', text, 'LEFT', text:GetUnboundedStringWidth() + Pixel.Scale(RULE_GAP), 0)
end

local function UpperHeader(header)
	local text = header.Text
	local value = text:GetText()
	if not value or value == header.__buiUpper then return end
	header.__buiOriginal = value
	header.__buiUpper = value:upper()
	SetRawText(text, header.__buiUpper)
	PlaceHeaderRule(header)
end

local function OnSetHeader(module)
	local header = module.Header
	if header and header.__buiSkinned then UpperHeader(header) end
end

local function SkinHeader(header, isContainer)
	if header.__buiSkinned then return end
	header.__buiSkinned = true

	local text = header.Text
	restoreHeaders[header] = { text:GetTextColor() }
	HideFrameTextures(header)
	HideBlizzardTexture(header.Background)

	local inset = -Pixel.Scale(HEADER_TEXT_INSET)
	text:ClearAllPoints()
	text:SetPoint('LEFT', header, 'LEFT', inset, 0)

	local rule = Track(header:CreateTexture(nil, 'ARTWORK'))
	rule:SetHeight(Pixel.PixelSize(1))
	header.__buiRule = rule
	rules[rule] = true
	PaintRule(rule)

	if isContainer then
		rule:SetPoint('BOTTOMLEFT', header, 'BOTTOMLEFT', inset, 0)
		rule:SetPoint('BOTTOMRIGHT')
		headerRoles[text] = 'skinTitle'
		ApplySkinFont(text, 'header')
	else
		rule:SetPoint('RIGHT', header.MinimizeButton, 'LEFT', -Pixel.Scale(RULE_GAP), 0)
		headerRoles[text] = 'skinLabel'
		moduleHeaders[header] = true
		ApplySkinFont(text, 'caption')
		UpperHeader(header)
		PlaceHeaderRule(header)
	end
	text:SetTextColor(Painter.Color(headerRoles[text]))
	SkinMinimizeButton(header)
end

local function CropIcon(icon)
	if icon:GetAtlas() then return end
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function CardBackdrop(frame)
	return LibSkin.ChildBackdrop(frame, { bg = Skin.PALETTE.card, border = Skin.PALETTE.edge })
end

local function PaintBar(bar)
	bar:SetStatusBarColor(Painter.Color('skinLabel'))
end

local function SkinBar(bar)
	if not bar or bar.__buiSkinned then return end
	bar.__buiSkinned = true

	LibSkin.StripTextures(bar)
	bar:SetStatusBarTexture(FLAT_TEXTURE)
	Painter.Custom(bar, PaintBar)
	local backdrop = CardBackdrop(bar)
	skinnedBars[bar] = backdrop
	bar:HookScript('OnShow', Wrap('Skin.ObjectiveTracker bar backdrop', function(self)
		backdrop:SetShown(Enabled() and self:IsShown())
	end))
	backdrop:SetShown(Enabled() and bar:IsShown())

	local label = bar.Label
	if label then
		Pixel.ApplyFont(label, BAR_LABEL_SIZE, FONT, 'OUTLINE')
		label:ClearAllPoints()
		label:SetPoint('CENTER', bar, 'CENTER', 0, 0)
	end

	local icon = bar.Icon
	if icon then
		icon:SetMask('')
		CropIcon(icon)
		icon:SetSize(Pixel.Scale(BAR_ICON_SIZE), Pixel.Scale(BAR_ICON_SIZE))
		icon:ClearAllPoints()
		icon:SetPoint('LEFT', bar, 'RIGHT', Pixel.Scale(6), 0)
	end
end

local function SkinStageBlock()
	local stageBlock = ScenarioObjectiveTracker.StageBlock
	if stageBlock.__buiSkinned then return end
	stageBlock.__buiSkinned = true

	HideBlizzardTexture(stageBlock.NormalBG)
	HideBlizzardTexture(stageBlock.ThemeOverlay)
	HideBlizzardTexture(stageBlock.FinalBG)
	HideBlizzardTexture(stageBlock.GlowTexture)

	skinnedBars[stageBlock] = CardBackdrop(stageBlock)
	stageBlock:HookScript('OnShow', Wrap('Skin.ObjectiveTracker stage backdrop', Scenario.SyncStageBackdrop))
	stageBlock:HookScript('OnHide', Wrap('Skin.ObjectiveTracker stage backdrop', Scenario.SyncStageBackdrop))
	Hook(stageBlock, 'UpdateWidgetRegistration', Scenario.SyncStageBackdrop)
	Hook(stageBlock, 'SetupStageTransition', Scenario.SyncStageBackdrop)
	Scenario.SyncStageBackdrop(stageBlock)

	ApplySkinFont(stageBlock.Stage, 'header')
	ApplySkinFont(stageBlock.Name, 'title')
	ApplySkinFont(stageBlock.CompleteLabel, 'header')
	if stageBlock.Stage then stageBlock.Stage:SetTextColor(TrackerColorRGB('title')) end
	if stageBlock.Name then stageBlock.Name:SetTextColor(TrackerColorRGB('title')) end
end

local function SkinItemButton(button)
	if not button or button.__buiSkinned then return end
	button.__buiSkinned = true

	HideBlizzardTexture(button:GetNormalTexture())
	HideBlizzardTexture(button:GetPushedTexture())

	local highlight = button:GetHighlightTexture()
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

	local edgeRed, edgeGreen, edgeBlue = Painter.Color('skinBorder')
	Pixel.ApplyBorder(button, 1, edgeRed, edgeGreen, edgeBlue, 1)

	local glow = button.Glow
	if glow then
		local outset = Pixel.PixelSize(2)
		glow:SetAtlas(nil)
		Painter.Fill(glow, 'skinTitle')
		glow:ClearAllPoints()
		glow:SetPoint('TOPLEFT', button, 'TOPLEFT', -outset, outset)
		glow:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', outset, -outset)
	end

	local count = button.Count or button.count
	if count then Pixel.ApplyFont(count, BAR_LABEL_SIZE, FONT, 'OUTLINE') end
end

local function ApplyCheckTexture(check)
	if check.__buiApplyingCheck then return end
	check.__buiApplyingCheck = true
	check:SetTexture(BUILib.GetLibMedia('check'))
	check:SetVertexColor(Painter.Color('skinTitle'))
	check.__buiApplyingCheck = nil
end

local function SkinCheck(check)
	if not check or check.__buiSkinned then return end
	check.__buiSkinned = true
	Painter.Custom(check, ApplyCheckTexture)
	Hook(check, 'SetAtlas', ApplyCheckTexture)
	Hook(check, 'SetTexture', ApplyCheckTexture)
end

local function SkinBlockText(fontString, role, wrapSet, wantWrap)
	ApplySkinFont(fontString, role)
	wrapSet[fontString] = true
	if fontString.__buiWordWrap ~= wantWrap then
		fontString.__buiWordWrap = wantWrap
		fontString:SetWordWrap(wantWrap)
	end
end

local function SkinLine(line, wantWrap)
	SkinCheck(line.Check)
	if line.Text then SkinBlockText(line.Text, 'line', wrapAdjustedText.objectives, wantWrap) end
	local dash = line.Dash
	if dash and not dashFontStrings[dash] then
		dashFontStrings[dash] = true
		dash:SetAlpha(DashesVisible() and 1 or 0)
	end
end

local function OnAddPOIButton(block)
	local button = block.poiButton
	if button and block.HeaderText then
		button:ClearAllPoints()
		button:SetPoint('RIGHT', block.HeaderText, 'LEFT', POI_ANCHOR_OFFSET_X, 0)
	end
end

local OnBlockMouseDown = BUI.Profiler.Wrap('Skin.ObjectiveTracker block OnMouseDown', function(block)
	pendingMenuQuestID = block.poiQuestID or block.id
end)

local function HookBlock(block)
	block.__buiHooked = true
	if block.AddPOIButton then Hook(block, 'AddPOIButton', OnAddPOIButton) end
	if block.SetStringText then Hook(block, 'SetStringText', OnSetStringText) end
	if block.UpdateHighlight then Hook(block, 'UpdateHighlight', OnUpdateHighlight) end
	block:HookScript('OnMouseDown', OnBlockMouseDown)
	OnUpdateHighlight(block)
end

local function OnAddBlock(_, block)
	SkinItemButton(block.ItemButton or block.itemButton)
	if block.addedRegions and not InCombatLockdown() then
		local raisedLevel = block:GetFrameLevel() + 5
		for region in pairs(block.addedRegions) do
			if region.SetFrameLevel and region:GetFrameLevel() ~= raisedLevel then region:SetFrameLevel(raisedLevel) end
		end
	end
	HideBlizzardTexture(block.HeaderGlow)
	if block.HeaderText then SkinBlockText(block.HeaderText, 'title', wrapAdjustedText.titles, not SingleLineTitlesEnabled()) end
	if block.usedLines then
		local objectiveWrap = GetSettings().singleLineObjectives == false
		for _, line in pairs(block.usedLines) do SkinLine(line, objectiveWrap) end
	end
	local poiButton = block.poiButton
	if poiButton and not hiddenPoiButtons[poiButton] then
		hiddenPoiButtons[poiButton] = true
		poiButton:SetScale(POI_BUTTON_SCALE)
		SetPoiButtonVisible(poiButton, GetSettings().showQuestIcons == true)
	end
	if not block.__buiHooked then HookBlock(block) end
end

local function OnGetProgressBar(tracker, key)
	local progressBar = tracker.usedProgressBars[key]
	if progressBar then SkinBar(progressBar.Bar) end
end

local function OnGetTimerBar(tracker, key)
	local timerBar = tracker.usedTimerBars[key]
	if timerBar then SkinBar(timerBar.Bar) end
end

Scenario.headers = {}
Scenario.headerMixins = { 'UIWidgetTemplateScenarioHeaderDelvesMixin', 'UIWidgetTemplateScenarioHeaderTimerMixin', 'UIWidgetTemplateScenarioHeaderCurrenciesAndBackgroundMixin' }
Scenario.headerOverhangKeys = { 'SpellContainer', 'CurrencyContainer', 'RewardFrame' }
Scenario.stageTextKeys = { 'Stage', 'Name', 'CompleteLabel' }
Scenario.backdropInset = 1
Scenario.headerBackdropPad = 4
Scenario.stageBackdropPad = 8

function Scenario.FitHeaderBackdrop(widget, backdrop)
	local bottom = widget:GetBottom()
	if not bottom then return false end
	local lowest = bottom
	for _, key in ipairs(Scenario.headerOverhangKeys) do
		local child = widget[key]
		if child and child:IsShown() then
			local childBottom = child:GetBottom()
			if childBottom and childBottom < lowest then lowest = childBottom end
		end
	end
	local inset = Scenario.backdropInset
	local drop = bottom - lowest
	if drop > 0 then drop = drop + Scenario.headerBackdropPad end
	if backdrop._buiHeaderDrop == drop then return true end
	backdrop._buiHeaderDrop = drop
	backdrop:ClearAllPoints()
	backdrop:SetPoint('TOPLEFT', widget, 'TOPLEFT', inset, -inset)
	backdrop:SetPoint('BOTTOMRIGHT', widget, 'BOTTOMRIGHT', -inset, inset - drop)
	return true
end

function Scenario.ApplyHeader(widget)
	Scenario.headers[widget] = true
	local enabled = Enabled()
	local alpha = enabled and 0 or 1
	widget.Frame:SetAlpha(alpha)
	widget.ThemeOverlay:SetAlpha(alpha)
	widget.DecorationBottomLeft:SetAlpha(alpha)
	local backdrop = skinnedBars[widget]
	if enabled then
		if not backdrop then
			backdrop = CardBackdrop(widget)
			skinnedBars[widget] = backdrop
		end
		if not Scenario.FitHeaderBackdrop(widget, backdrop) then
			After('Skin.ObjectiveTracker header fit', 0, function() Scenario.FitHeaderBackdrop(widget, backdrop) end)
		end
		ApplySkinFont(widget.HeaderText, 'title')
		widget.HeaderText:SetTextColor(TrackerColorRGB('title'))
		local timerBar = widget.TimerBar
		if timerBar then
			SkinBar(timerBar)
			timerBar:SetStatusBarTexture(FLAT_TEXTURE)
			PaintBar(timerBar)
			ApplySkinFont(widget.Timer.Text, 'timer')
		end
	end
	if backdrop then backdrop:SetShown(enabled and widget:IsShown()) end
end

function Scenario.ScanHeaders()
	local frames = ScenarioObjectiveTracker.StageBlock.WidgetContainer.widgetFrames
	if type(frames) ~= 'table' then return end
	for _, widget in pairs(frames) do
		if not Scenario.headers[widget] and widget.Frame and widget.HeaderText then
			Hook(widget, 'Setup', Scenario.ApplyHeader)
			Scenario.headers[widget] = true
		end
	end
	for widget in pairs(Scenario.headers) do Scenario.ApplyHeader(widget) end
end

function Scenario.InstallHeaderHooks()
	for _, mixinName in ipairs(Scenario.headerMixins) do
		local mixin = _G[mixinName]
		if mixin then Hook(mixin, 'Setup', Scenario.ApplyHeader) end
	end
end

function Scenario.FitStageBackdrop(stageBlock, backdrop)
	local top = stageBlock:GetTop()
	if not top then return false end
	local lowest
	for _, key in ipairs(Scenario.stageTextKeys) do
		local text = stageBlock[key]
		if text and text:IsShown() and (text:GetText() or '') ~= '' then
			local bottom = text:GetBottom()
			if bottom and (not lowest or bottom < lowest) then lowest = bottom end
		end
	end
	local height = stageBlock:GetHeight()
	if lowest then height = math.min(height, top - lowest + Scenario.stageBackdropPad) end
	height = math.floor(height + 0.5)
	if backdrop._buiStageHeight == height then return true end
	backdrop._buiStageHeight = height
	local inset = Scenario.backdropInset
	backdrop:ClearAllPoints()
	backdrop:SetPoint('TOPLEFT', stageBlock, 'TOPLEFT', inset, -inset)
	backdrop:SetPoint('TOPRIGHT', stageBlock, 'TOPRIGHT', -inset, -inset)
	backdrop:SetHeight(math.max(1, height - inset * 2))
	return true
end

function Scenario.SyncStageBackdrop(stageBlock)
	local backdrop = skinnedBars[stageBlock]
	if not backdrop then return end
	local blockParent = stageBlock:GetParent()
	if backdrop:GetParent() ~= blockParent then
		backdrop:SetParent(blockParent)
		backdrop:SetFrameLevel(math.max(0, stageBlock:GetFrameLevel() - 1))
	end
	local shown = Enabled() and stageBlock:IsShown() and not stageBlock.widgetSetID
	backdrop:SetShown(shown)
	if shown and not Scenario.FitStageBackdrop(stageBlock, backdrop) then
		After('Skin.ObjectiveTracker stage fit', 0, function()
			if backdrop:IsShown() then Scenario.FitStageBackdrop(stageBlock, backdrop) end
		end)
	end
end

local function PaintHeaders()
	for text, role in pairs(headerRoles) do text:SetTextColor(Painter.Color(role)) end
	for chevron in pairs(chevrons) do PaintGlyph(chevron, false) end
	if headerCounts then headerCounts:SetTextColor(Painter.Color('skinLabel')) end
	QuestFilter.UpdateTint()
end

local function ApplyTextSettings()
	fontGeneration = fontGeneration + 1
	for fontString, entry in pairs(restoreFonts) do ApplySkinFont(fontString, entry.role) end
	for header in pairs(moduleHeaders) do PlaceHeaderRule(header) end
	ApplyCardStyle()
end

local function EachTracker(callback)
	for _, trackerName in ipairs(TRACKER_NAMES) do
		local tracker = _G[trackerName]
		if tracker then callback(tracker) end
	end
end

local function HookTracker(tracker)
	Hook(tracker, 'AddBlock', OnAddBlock)
	Hook(tracker, 'GetProgressBar', OnGetProgressBar)
	Hook(tracker, 'GetTimerBar', OnGetTimerBar)
	Hook(tracker, 'OnBlockHeaderLeave', HideQuestTip)
	Hook(tracker, 'SetHeader', OnSetHeader)
end

local function SkinModuleHeader(tracker)
	if not tracker.Header then return end
	SkinHeader(tracker.Header, false)
	UpperHeader(tracker.Header)
end

local function InstallTracker(trackerFrame)
	Scenario.InstallHeaderHooks()
	InstallMenuHook()
	EventRegistry:RegisterCallback('OnQuestBlockHeader.OnEnter', Guard(OnQuestBlockHeaderEnter), context)
	Hook(trackerFrame, 'UpdateClampOffsets', TrackerClamp)
	Hook(trackerFrame, 'Init', DecorateHeader)
	CreateTrackerCard(trackerFrame)
	EachTracker(HookTracker)

	local refresh = Guard(RefreshQuestCacheSoon)
	for _, event in ipairs(QUEST_CACHE_EVENTS) do BUI.Events:Register(event, 'Skinning.TrackerQuestCache', refresh) end
	BUI.Events:Register('QUEST_WATCH_UPDATE', 'Skinning.TrackerProgress', Guard(OnQuestProgress))
	BUI.Events:Register('ZONE_CHANGED_NEW_AREA', 'Skinning.TrackerItemKey', Guard(QuestItem.Update))
	BUI.Events:Register('BAG_UPDATE_COOLDOWN', 'Skinning.TrackerItemCooldown', Guard(QuestItem.UpdateCooldown))
	Painter.OnRepaint('Skin.ObjectiveTracker', Guard(function()
		ApplyCardStyle()
		PaintRules()
		PaintHeaders()
	end))
end

local function SkinTracker(trackerFrame)
	trackerSkinned = true
	Scenario.ScanHeaders()
	SkinStageBlock()
	SkinHeader(trackerFrame.Header, true)
	EachTracker(SkinModuleHeader)
	trackerFrame.NineSlice:SetAlpha(0)
	HideFrameTextures(trackerFrame.NineSlice)

	for _, element in ipairs(addedElements) do element:Show() end
	for bar, backdrop in pairs(skinnedBars) do backdrop:SetShown(bar:IsShown()) end
	for button in pairs(hiddenPoiButtons) do button:SetScale(POI_BUTTON_SCALE) end
	for _, texture in ipairs(hiddenTextures) do ReassertHidden(texture) end
	Scenario.SyncStageBackdrop(ScenarioObjectiveTracker.StageBlock)

	ApplyPoiVisibility()
	ApplyDashAlpha()
	ApplyTitleWrap()
	ApplyTextSettings()
	PaintRules()
	PaintHeaders()
	ApplyTrackerColors()
	UpdateCardAnchors()
	SyncTrackerCardShown()
	ApplyHeaderRowVisibility()
	ApplyTrackerHidden()
	RefreshQuestCacheSoon()
end

local function RestoreTracker()
	if not trackerSkinned then return end
	trackerSkinned = false
	local trackerFrame = ObjectiveTrackerFrame

	for _, element in ipairs(addedElements) do element:Hide() end
	for _, backdrop in pairs(skinnedBars) do backdrop:Hide() end
	trackerCard:Hide()
	trackerCard._buiClamp = nil
	for button in pairs(hiddenPoiButtons) do
		button:SetScale(1)
		button:ClearAllPoints()
	end
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
		entry.generation = nil
	end
	for header, color in pairs(restoreHeaders) do
		header.Text:SetTextColor(color[1], color[2], color[3], color[4])
		if header.__buiOriginal then
			header.Text:SetText(header.__buiOriginal)
			header.__buiUpper = nil
		end
	end

	trackerFrame.NineSlice:SetAlpha(1)
	trackerFrame:UpdateClampOffsets()
	ApplyTitleWrap()
	ApplyHeaderRowVisibility()
	HideQuestTip()
	for widget in pairs(Scenario.headers) do Scenario.ApplyHeader(widget) end
	ApplyPoiVisibility()
	ApplyDashAlpha()
	ApplyTrackerHidden()
	RepaintBlizzardColors()
	QuestItem.Update()
end

context.Window('ObjectiveTrackerFrame', { install = InstallTracker, skin = SkinTracker })
context.OnDisable(RestoreTracker)

local function BuildBoards(ui, parent, width)
	local settings = GetSettings()

	local function OnByDefault(key)
		return function() return settings[key] ~= false end
	end
	local function OffByDefault(key)
		return function() return settings[key] == true end
	end
	local function Store(key, apply)
		return function(value)
			settings[key] = value
			if apply then apply() end
		end
	end
	local function TrackerSwatch(label, key)
		return { kind = 'swatch', label = label, get = function() return TrackerColorRGB(key) end, set = function(red, green, blue)
			settings.colors[key] = { red, green, blue }
		end }
	end
	local function TextureTint()
		local tint = settings.cardTextureColor or CARD_TEXTURE_TINT
		return tint[1], tint[2], tint[3], 1
	end
	local function ApplyLines()
		ApplyCardStyle()
		PaintRules()
	end
	local function ResetItemButton()
		local positions = BUI.GetDB().framePositions
		if positions then positions[QuestItem.POSITION_KEY] = nil end
		if QuestItem.button then QuestItem.button.placedVisible = nil end
		QuestItem.Update()
	end

	local fontItems = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
	table.insert(fontItems, 1, { value = LIBRARY_FONT_OPTION, text = 'Tooltip Font' })
	local textureItems = BUI.BuildTextureDropdownItems()
	table.insert(textureItems, 1, { value = FLAT_TEXTURE_OPTION, text = 'Flat' })

	local text = ui.Board(parent, width, { stacked = true, title = 'Text', description = 'The font on quest titles and objectives, and the colors they use.' })
	text:AddTools('Font', 'Typeface, size, outline and line wrapping', {
		{ entries = fontItems, get = function() return settings.font end, set = Store('font') },
		{ icon = 'text', tooltip = 'Size, outline and wrapping', title = 'Font', options = {
			{ label = 'Size', min = 8, max = 16, step = 1, get = function() return settings.fontSize end, set = Store('fontSize') },
			{ label = 'Outlined text', get = OffByDefault('fontOutline'), set = Store('fontOutline') },
			{ label = 'Single-line titles', separator = true, get = OnByDefault('singleLineTitles'), set = Store('singleLineTitles', ApplyTitleWrap) },
			{ label = 'Single-line objectives', get = OnByDefault('singleLineObjectives'), set = Store('singleLineObjectives', ApplyTitleWrap) },
		} },
	}, Guard(ApplyTextSettings))
	text:AddTools('Colors', "Your own colors for quests and objectives, off keeps Blizzard's", {
		{ icon = 'palette', tooltip = 'Pick the colors', title = 'Colors', options = {
			TrackerSwatch('Quest title', 'title'),
			TrackerSwatch('Title on hover', 'hover'),
			TrackerSwatch('Objective', 'objective'),
			TrackerSwatch('Completed objective', 'completed'),
			TrackerSwatch('Ready to turn in', 'ready'),
			TrackerSwatch('Time left', 'timeLeft'),
		} },
		{ get = OnByDefault('customColors'), set = Store('customColors') },
	}, Guard(ApplyTrackerColors))

	local panel = ui.Board(parent, width, { stacked = true, title = 'Panel', description = 'The dark card behind the tracker and the lines inside it.' })
	panel:AddTools('Background', 'Texture, tint and opacity', {
		{ kind = 'swatch', tooltip = 'Texture tint', get = TextureTint, set = function(red, green, blue)
			settings.cardTextureColor = { red, green, blue }
		end },
		{ entries = textureItems, get = function() return settings.cardTexture end, set = Store('cardTexture') },
		{ tooltip = 'Opacity', title = 'Background', options = {
			{ label = 'Opacity', min = 0, max = 100, step = 1, get = function() return settings.cardOpacity end, set = Store('cardOpacity') },
		} },
	}, ApplyCardStyle)
	panel:AddTools('Lines', 'Border and separator colors, the switch shows the border', {
		{ kind = 'swatch', tooltip = 'Border color', opacity = true, get = function() return PanelColor('cardBorderColor', 'skinBorder') end, set = function(red, green, blue, alpha)
			settings.cardBorderColor = { red, green, blue, alpha }
		end },
		{ kind = 'swatch', tooltip = 'Separator color', opacity = true, get = function() return PanelColor('separatorColor', 'skinLine') end, set = function(red, green, blue, alpha)
			settings.separatorColor = { red, green, blue, alpha }
		end },
		{ get = OnByDefault('cardBorder'), set = Store('cardBorder') },
	}, ApplyLines)

	local quests = ui.Board(parent, width, { stacked = true, title = 'Quests', description = 'What the tracker shows and how it tells you about progress.' })
	quests:AddSwitch('Objectives header', OnByDefault('showHeaderRow'), function(value)
		settings.showHeaderRow = value
		if value == false then
			settings.trackerTrackSpec = nil
			QuestFilter.UpdateTint()
		end
		ApplyHeaderRowVisibility()
	end, 'Quest counts and track presets above the list')
	quests:AddSwitch('Quest type icons', OffByDefault('showQuestIcons'), Store('showQuestIcons', ApplyPoiVisibility))
	quests:AddSwitch('Objective dashes', OffByDefault('showDashes'), Store('showDashes', ApplyDashAlpha), 'A dash in front of each objective')
	quests:AddSwitch('Quest tooltips', OnByDefault('questTooltip'), Store('questTooltip'), 'Quest details when you hover a quest')
	quests:AddSwitch('Completion messages', OffByDefault('completionMessage'), Store('completionMessage'), 'Say on screen when an objective or quest is done')
	quests:AddSwitch('Hide the tracker', OffByDefault('trackerHidden'), Store('trackerHidden', ApplyTrackerHidden), 'Hide the objective tracker completely')
	quests:AddTools('Completion sound', 'Plays when a quest is ready to turn in', {
		{ entries = BUI.BuildSoundDropdownItems(), get = function() return settings.completionSound or 'None' end, set = Store('completionSound') },
		{ icon = 'play', tooltip = 'Hear it', onClick = function() BUI.PlaySoundByName(settings.completionSound) end },
	})
	quests:AddTools('Quest item', "A key for your closest quest's item, the switch adds a button you can drag", {
		QuestItem.KeyTool(ui),
		{ icon = 'reset', tooltip = 'Put the button back where it started', onClick = ResetItemButton },
		{ get = OffByDefault('showQuestItemButton'), set = Store('showQuestItemButton') },
	}, QuestItem.Update)

	return { text, panel, quests }
end

context.info.buildBoards = BuildBoards
