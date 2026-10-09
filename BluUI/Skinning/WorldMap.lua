local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning
local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Layout = BUILib.Layout

local BORDER_ART = { 'Bg', 'TopTileStreaks', 'InsetBorderTop', 'Underlay' }
local DETAILS_ART = { 'Bg', 'SealMaterialBG' }
local REWARDS_ART = { 'Bottom', 'Top', 'Background' }
local CAMPAIGN_ART = { 'Background', 'TopFiligree', 'HighlightTexture', 'SelectedHighlight' }
local DETAIL_BUTTON_KEYS = { 'AbandonButton', 'ShareButton', 'TrackButton' }
local SIDE_TAB_KEYS = { 'QuestsTab', 'EventsTab', 'MapLegendTab' }
local SIDE_TAB_OPTIONS = { dim = true }
local SIDE_TAB_TOP_OFFSET = -2
local ROW_HOVER_ALPHA = 0.1
local DIVIDER_ALPHA = 0.1
local CHECKBOX_INSET = 1
local ACTIVE_RING_PADDING = 3
local PARENT_WALK_DEPTH = 6
local SEARCH_WIDTH, SEARCH_HEIGHT = 160, 22
local SEARCH_INSET = 8
local SEARCH_TEXT_INSET = 6

local context = Skin.Define('worldmap', {
	name = 'World Map',
	description = 'The map and quest log frame in the dark shell, plus continent-map extras: zone name labels and dungeon/raid entrance pins.',
})
local Hook = context.Hook
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Card, Dropdown = context.Shell, context.Button, context.Card, context.Dropdown
local EditBox, ScrollBar, Body = context.EditBox, context.ScrollBar, context.Body
local CollapseButton = context.CollapseButton
local AccentTexture = Skin.AccentTexture

local function RefreshExtras()
	if BUI.WorldMapLabels then BUI.WorldMapLabels.Refresh() end
	if BUI.WorldMapInstancePins then BUI.WorldMapInstancePins.Refresh() end
end

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function AccentTint(texture, alpha)
	KeepTexture(texture)
	texture:SetBlendMode('BLEND')
	AccentTexture(texture, alpha)
end

local function DividerLine(frame)
	if frame._buiDivider then return end
	local line = context.Own(frame:CreateTexture(nil, 'ARTWORK'))
	line:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
	line:SetHeight(1)
	line:SetPoint('LEFT', frame, 'LEFT', 8, 0)
	line:SetPoint('RIGHT', frame, 'RIGHT', -8, 0)
	BUILib.Skin.PixelLine(line, frame, false, 8, 8)
	frame._buiDivider = line
end

local function SkinWindow(map)
	FadeRegions(map)
	Shell(map)
	Shell(map.ScrollContainer)
	local toggle = map.SidePanelToggle
	FadeRegions(toggle.OpenButton)
	FadeRegions(toggle.CloseButton)
	Skin.TipPageButton(toggle.OpenButton, 'next')
	Skin.TipPageButton(toggle.CloseButton, 'previous')
end

local function SkinBorder(border)
	Fade(border.NineSlice)
	FadeKeys(border, BORDER_ART)
	Fade(border.PortraitContainer.portrait)
	Skin.LeftTitle(border)
	context.Close(border.CloseButton)
	local maxMin = border.MaximizeMinimizeFrame
	Skin.TipPageButton(maxMin.MaximizeButton, 'expand')
	Skin.TipPageButton(maxMin.MinimizeButton, 'condense')
end

local function SkinNavButton(button)
	FadeRegions(button)
	Fade(button:GetNormalTexture())
	Fade(button:GetPushedTexture())
	Fade(button:GetDisabledTexture())
	Fade(button:GetHighlightTexture())
	Shell(button)
	Body(button.text)
	Skin.TipNavArrow(button.MenuArrowButton)
end

local function OnNavButtonAdded(navBar)
	if navBar ~= _G.WorldMapFrame.NavBar then return end
	SkinNavButton(navBar.navList[#navBar.navList])
end

local function SkinNavBar(navBar)
	FadeRegions(navBar)
	Fade(navBar.overlay)
	SkinNavButton(navBar.homeButton)
	local overflow = navBar.overflowButton
	FadeRegions(overflow)
	Skin.TipPageButton(overflow, 'previous')
	Shell(overflow)
	for _, button in ipairs(navBar.navList) do SkinNavButton(button) end
end

local function SkinRoundButton(button)
	KeepTexture(button.Icon)
	KeepTexture(button.IconOverlay)
	KeepTexture(button.ActiveTexture)
	KeepTexture(button.FilterCounterBanner)
	Button(button)
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint('CENTER')
	local ring = button.ActiveTexture
	if ring then
		ring:ClearAllPoints()
		ring:SetPoint('TOPLEFT', button.Icon, 'TOPLEFT', -ACTIVE_RING_PADDING, ACTIVE_RING_PADDING)
		ring:SetPoint('BOTTOMRIGHT', button.Icon, 'BOTTOMRIGHT', ACTIVE_RING_PADDING, -ACTIVE_RING_PADDING)
	end
	if button.FilterCounter then Body(button.FilterCounter.Count) end
end

local function SkinOverlayFrames(map)
	for _, frame in ipairs(map.overlayFrames) do
		if frame.CursorCoords then
			Body(frame.CursorCoords.Label)
			Body(frame.PlayerCoords.Label)
		elseif frame.FilterCounter or frame.ActiveTexture then
			SkinRoundButton(frame)
		elseif frame.SetupMenu and frame.Text then
			Dropdown(frame)
		end
	end
end

local rareScannerSearch

local function FindRareScannerSearch(map)
	local mixin = _G.RSSearchMixin
	if rareScannerSearch or not mixin then return rareScannerSearch end
	for _, child in ipairs({ map:GetChildren() }) do
		if child.OnLoad == mixin.OnLoad then
			rareScannerSearch = child
			return child
		end
	end
end

local function SkinRareScannerSearch(map)
	local search = FindRareScannerSearch(map)
	if not search or search._buiHome then return end
	local editBox = search.EditBox
	search._buiHome = { point = { search:GetPoint(1) }, width = editBox:GetWidth(), height = editBox:GetHeight() }
	FadeRegions(editBox)
	EditBox(editBox)
	editBox:SetTextInsets(SEARCH_TEXT_INSET, SEARCH_TEXT_INSET, 0, 0)
	editBox:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
	search:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
	search:ClearAllPoints()
	search:SetPoint('RIGHT', map.NavBar, 'RIGHT', -SEARCH_INSET, 0)
end

local function ReleaseRareScannerSearch()
	local home = rareScannerSearch and rareScannerSearch._buiHome
	if not home then return end
	rareScannerSearch._buiHome = nil
	local editBox = rareScannerSearch.EditBox
	editBox:SetTextInsets(0, 0, 0, 0)
	editBox:SetSize(home.width, home.height)
	rareScannerSearch:SetSize(home.width, home.height)
	rareScannerSearch:ClearAllPoints()
	rareScannerSearch:SetPoint(unpack(home.point))
end

local function IsTabSelected(questLog, tab)
	return questLog.displayMode ~= nil and questLog.displayMode == tab.displayMode
end

local function OnTabChecked(tab, checked)
	Skin.SetSideTabSelected(tab, checked == true)
end

local sideTabs = {}

local function RefreshSideTabs(questLog)
	for index, key in ipairs(SIDE_TAB_KEYS) do
		local tab = questLog[key]
		if not sideTabs[index] then
			sideTabs[index] = tab
			Hook(tab, 'SetChecked', OnTabChecked)
		end
		Skin.SideTab(context, tab, SIDE_TAB_OPTIONS)
		Skin.SetSideTabSelected(tab, IsTabSelected(questLog, tab))
	end
	Skin.LayoutSideTabs(questLog, sideTabs, SIDE_TAB_TOP_OFFSET)
end

local function SkinQuestTitle(button)
	local checkbox = button.Checkbox
	if not button._buiQuestRow then
		button._buiQuestRow = true
		Skin.TipFace(button.Text, 'body')
		AccentTint(button.HighlightTexture, ROW_HOVER_ALPHA)
		KeepTexture(checkbox.CheckMark)
	end
	FadeRegions(checkbox)
	Shell(checkbox, CHECKBOX_INSET)
end

local function SkinObjective(line)
	if line._buiObjective then return end
	line._buiObjective = true
	Skin.TipFace(line.Dash, 'body')
	Skin.TipFace(line.Text, 'body')
end

local function SkinListHeader(header)
	Fade(header:GetNormalTexture())
	Fade(header:GetHighlightTexture())
	Skin.TipFace(header.ButtonText, 'title')
	CollapseButton(header.CollapseButton)
	Card(header)
end

local function SkinCampaignHeader(header)
	FadeKeys(header, CAMPAIGN_ART)
	Skin.TipFace(header.Text, 'title')
	Skin.TipFace(header.Progress, 'body')
	Skin.TipFace(header.NextObjective.Text, 'body')
	CollapseButton(header.CollapseButton)
	Card(header)
end

local function SkinCampaignMinimalHeader(header)
	Fade(header.Background)
	Fade(header.Highlight)
	Skin.TipFace(header.Text, 'title')
	Skin.TipFace(header.NextObjective.Text, 'body')
	CollapseButton(header.CollapseButton)
	Card(header)
end

local function SkinCallingsHeader(header)
	Fade(header.Background)
	Fade(header.Divider)
	Fade(header.SelectedTexture)
	SkinListHeader(header)
end

local function SweepQuestLog()
	local scroll = _G.QuestScrollFrame
	for button in scroll.titleFramePool:EnumerateActive() do SkinQuestTitle(button) end
	for line in scroll.objectiveFramePool:EnumerateActive() do SkinObjective(line) end
	for header in scroll.headerFramePool:EnumerateActive() do SkinListHeader(header) end
	for header in scroll.campaignHeaderFramePool:EnumerateActive() do SkinCampaignHeader(header) end
	for header in scroll.campaignHeaderMinimalFramePool:EnumerateActive() do SkinCampaignMinimalHeader(header) end
	for header in scroll.covenantCallingsHeaderFramePool:EnumerateActive() do SkinCallingsHeader(header) end
end

local function SkinStoryHeader(header)
	Fade(header.Background)
	Fade(header.Divider)
	Fade(header.HighlightTexture)
	Skin.TipFace(header.Text, 'title')
	Skin.TipFace(header.Progress, 'body')
	Card(header)
end

local function SkinQuestScroll(scroll)
	Fade(scroll.Background)
	Fade(scroll.Edge)
	Skin.FadeTree(scroll.BorderFrame)
	EditBox(scroll.SearchBox)
	ScrollBar(scroll.ScrollBar)
	Body(scroll.EmptyText)
	Body(scroll.NoSearchResultsText)
	local contents = scroll.Contents
	Fade(contents.Separator.Divider)
	DividerLine(contents.Separator)
	SkinStoryHeader(contents.StoryHeader)
end

local function SkinDetails(details)
	FadeKeys(details, DETAILS_ART)
	Skin.FadeTree(details.BorderFrame)
	FadeRegions(details.BackFrame)
	Button(details.BackFrame.BackButton)
	for _, key in ipairs(DETAIL_BUTTON_KEYS) do Button(details[key]) end
	ScrollBar(details.ScrollFrame.ScrollBar)
	local rewards = details.RewardsFrameContainer.RewardsFrame
	FadeKeys(rewards, REWARDS_ART)
	Skin.TipFace(rewards.Label, 'title')
end

local function SkinCampaignOverview(overview)
	Skin.FadeTree(overview.BorderFrame)
	Fade(overview.BG)
	local header = overview.Header
	Fade(header.Background)
	Fade(header.TopFiligree)
	Skin.TipFace(header.Text, 'title')
	Skin.TipFace(header.Progress, 'body')
	local scroll = overview.ScrollFrame
	ScrollBar(scroll.ScrollBar)
	Fade(scroll.TopShadow)
	Fade(scroll.BottomShadow)
end

local function SkinEventRow(frame)
	if frame.Name then
		if not frame._buiEventRow then
			frame._buiEventRow = true
			Skin.TipFace(frame.Name, 'body')
			Skin.TipFace(frame.Location, 'body')
		end
		Fade(frame.Background)
		Fade(frame.Background2)
		Fade(frame.Highlight)
		Card(frame)
	elseif frame.Label then
		if not frame._buiEventLabel then
			frame._buiEventLabel = true
			Skin.TipFace(frame.Label, frame.Background and 'title' or 'body')
		end
		Fade(frame.Background)
	end
end

local function SkinEvents(events)
	FadeRegions(events)
	Skin.FadeTree(events.BorderFrame)
	Fade(events.ScrollBox.Background)
	Body(events.ScrollBox.EmptyText)
	ScrollBar(events.ScrollBar)
	Skin.TipFace(events.TitleText, 'title')
	Skin.SweepScrollBox(events.ScrollBox, context.Guard(SkinEventRow))
end

local function SkinLegendButton(button)
	local highlight = button:GetHighlightTexture()
	highlight:SetBlendMode('BLEND')
	AccentTexture(highlight, ROW_HOVER_ALPHA)
	Skin.TipFace(button:GetFontString(), 'body')
end

local function SkinLegend(legend)
	Skin.FadeTree(legend.BorderFrame)
	Fade(legend.ScrollFrame.Background)
	ScrollBar(legend.ScrollFrame.ScrollBar)
	Skin.TipFace(legend.TitleText, 'title')
	for _, category in ipairs({ legend.ScrollFrame.ScrollChild:GetChildren() }) do
		if category.TitleText then
			Skin.TipFace(category.TitleText, 'title')
			for _, button in ipairs({ category:GetChildren() }) do
				if button.Icon and button.GetFontString then SkinLegendButton(button) end
			end
		end
	end
end

local function SkinSessionManagement(session)
	Fade(session.BG)
	Body(session.CommandText)
	Body(session.HelpText)
end

local function SkinQuestLog(questLog)
	Fade(questLog.VerticalSeparator)
	local quests = questLog.QuestsFrame
	SkinQuestScroll(quests.ScrollFrame)
	SkinDetails(quests.DetailsFrame)
	SkinCampaignOverview(quests.CampaignOverview)
	SkinEvents(questLog.EventsFrame)
	SkinLegend(questLog.MapLegend)
	SkinSessionManagement(questLog.QuestSessionManagement)
end

local function IsInsideQuestLog(frame)
	local questLog = _G.QuestMapFrame
	for _ = 1, PARENT_WALK_DEPTH do
		if not frame then return false end
		if frame == questLog then return true end
		frame = frame:GetParent()
	end
	return false
end

local function OnQuestInfoDisplayed(_, parentFrame)
	if Skin.RefreshQuestInfoText and IsInsideQuestLog(parentFrame) then Skin.RefreshQuestInfoText() end
end

local function SkinMap(map)
	SkinWindow(map)
	SkinBorder(map.BorderFrame)
	SkinNavBar(map.NavBar)
	SkinOverlayFrames(map)
	SkinQuestLog(_G.QuestMapFrame)
end

local function RefreshMap(map)
	SkinRareScannerSearch(map)
	SweepQuestLog()
	RefreshSideTabs(_G.QuestMapFrame)
end

local function InstallMap()
	Hook('NavBar_AddButton', OnNavButtonAdded)
	Hook('QuestLogQuests_Update', SweepQuestLog)
	Hook('QuestInfo_Display', OnQuestInfoDisplayed)
	Hook(_G.QuestMapFrame, 'ValidateTabs', function() RefreshSideTabs(_G.QuestMapFrame) end)
end

context.Window('WorldMapFrame', { skin = SkinMap, show = RefreshMap, install = InstallMap })

context.OnDisable(function()
	ReleaseRareScannerSearch()
	for _, tab in ipairs(sideTabs) do Skin.ResetSideTab(tab) end
end)

Skin.OnToggle('worldmap', RefreshExtras)

context.info.buildSettings = function(content)
	local db = BUI.GetDB()
	local panel = Layout.SettingsCard(content, { title = 'Continent Maps' })
	Layout.Toggle(panel, 'Zone Names', db.interface.worldMapZoneNames == true, function(value)
		db.interface.worldMapZoneNames = value
		RefreshExtras()
	end)
	Layout.Toggle(panel, 'Dungeon & Raid Pins', db.interface.worldMapDungeonPins == true, function(value)
		db.interface.worldMapDungeonPins = value
		RefreshExtras()
	end)
end
