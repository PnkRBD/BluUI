local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('WorldMap')

local hooksecurefunc = BUI.Prof.MakeHooker('worldmap')
local ipairs = ipairs

local Skin = BUI.Skinning
local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Layout = BUILib.Layout

local SKIN_ID = 'worldmap'
local BORDER_ART = { 'Bg', 'TopTileStreaks', 'InsetBorderTop', 'Underlay' }
local DETAILS_ART = { 'Bg', 'SealMaterialBG' }
local REWARDS_ART = { 'Bottom', 'Top', 'Background' }
local DETAIL_BUTTON_KEYS = { 'AbandonButton', 'ShareButton', 'TrackButton' }
local SIDE_TAB_KEYS = { 'QuestsTab', 'EventsTab', 'MapLegendTab' }
local SIDE_TAB_TOP_OFFSET = -2
local ROW_HOVER_ALPHA = 0.1
local SELECTED_ROW_ALPHA = 0.18
local DIVIDER_ALPHA = 0.1
local CHECKBOX_INSET = 1
local ACTIVE_RING_PADDING = 3
local PARENT_WALK_DEPTH = 6
local SEARCH_WIDTH, SEARCH_HEIGHT = 160, 22
local SEARCH_INSET = 8
local SEARCH_TEXT_INSET = 6

local installed = false
local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, Dropdown = context.Shell, context.Button, context.Close, context.Dropdown
local EditBox, ScrollBar, Body, Title = context.EditBox, context.ScrollBar, context.Body, context.Title
local AccentTexture = Skin.AccentTexture

local function RefreshExtras()
	if BUI.WorldMapLabels then BUI.WorldMapLabels.Refresh() end
	if BUI.WorldMapInstancePins then BUI.WorldMapInstancePins.Refresh() end
end

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function FadeStateTextures(button)
	Fade(button:GetNormalTexture())
	Fade(button:GetPushedTexture())
	Fade(button:GetDisabledTexture())
	Fade(button:GetHighlightTexture())
end

local function FitTexture(texture, host)
	local anchor = host.Background or host
	texture:ClearAllPoints()
	texture:SetPoint('TOPLEFT', anchor, 'TOPLEFT', 0, 0)
	texture:SetPoint('BOTTOMRIGHT', anchor, 'BOTTOMRIGHT', 0, 0)
end

local function AccentTint(texture, alpha)
	if not texture then return end
	KeepTexture(texture)
	texture:SetBlendMode('BLEND')
	AccentTexture(texture, alpha)
end

local function AccentFill(texture, host, alpha)
	if not texture then return end
	KeepTexture(texture)
	texture:SetBlendMode('BLEND')
	FitTexture(texture, host)
	AccentTexture(texture, alpha)
end

local function DividerLine(frame)
	if frame._buiDivider then return end
	local line = frame:CreateTexture(nil, 'ARTWORK')
	line.__buiSkin = true
	line:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
	line:SetHeight(1)
	line:SetPoint('LEFT', frame, 'LEFT', 8, 0)
	line:SetPoint('RIGHT', frame, 'RIGHT', -8, 0)
	frame._buiDivider = line
end

local function SkinWindow(map)
	FadeRegions(map)
	Shell(map)
	Shell(map.ScrollContainer)
	local toggle = map.SidePanelToggle
	if toggle then
		FadeRegions(toggle.OpenButton)
		FadeRegions(toggle.CloseButton)
		Skin.TipPageButton(toggle.OpenButton, 'next')
		Skin.TipPageButton(toggle.CloseButton, 'previous')
	end
end

local function SkinBorder(border)
	Fade(border.NineSlice)
	FadeKeys(border, BORDER_ART)
	Fade(border.PortraitContainer.portrait)
	Title(border.TitleContainer.TitleText)
	Close(border.CloseButton)
	local maxMin = border.MaximizeMinimizeFrame
	Skin.TipPageButton(maxMin.MaximizeButton, 'expand')
	Skin.TipPageButton(maxMin.MinimizeButton, 'condense')
end

local function SkinNavButton(button)
	if not button then return end
	FadeRegions(button)
	FadeStateTextures(button)
	Shell(button)
	Body(button.text)
end

local function OnNavButtonAdded(navBar)
	if not Enabled() or navBar ~= _G.WorldMapFrame.NavBar then return end
	local buttons = navBar.navList
	SkinNavButton(buttons[#buttons])
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
	local overlays = map.overlayFrames
	if not overlays then return end
	for _, frame in ipairs(overlays) do
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
	search:SetPoint('TOPLEFT', map:GetCanvasContainer(), 'TOPLEFT', SEARCH_INSET, -SEARCH_INSET)
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
	if Enabled() then Skin.SetSideTabSelected(tab, checked == true) end
end

local sideTabs

local function SideTabs(questLog)
	if not sideTabs then
		sideTabs = {}
		for index, key in ipairs(SIDE_TAB_KEYS) do sideTabs[index] = questLog[key] end
	end
	return sideTabs
end

local function RefreshSideTabs(questLog)
	for _, tab in ipairs(SideTabs(questLog)) do
		local fresh = not tab._buiSideTab
		Skin.SideTab(context, tab)
		if fresh then hooksecurefunc(tab, 'SetChecked', OnTabChecked) end
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

local function SkinHeaderRow(header)
	if not header._buiHeaderRow then
		header._buiHeaderRow = true
		Skin.TipFace(header.ButtonText, 'title')
	end
	Button(header)
end

local function SkinCampaignHeader(header)
	if not header._buiCampaign then
		header._buiCampaign = true
		Skin.TipFace(header.Text, 'title')
		Skin.TipFace(header.Progress, 'body')
		Skin.TipFace(header.NextObjective.Text, 'body')
		AccentFill(header.HighlightTexture, header, ROW_HOVER_ALPHA)
		AccentFill(header.SelectedHighlight, header, SELECTED_ROW_ALPHA)
	end
	Fade(header.Background)
	Fade(header.TopFiligree)
	AccentTexture(header.HighlightTexture, ROW_HOVER_ALPHA)
	Shell(header)
end

local function SkinCampaignMinimalHeader(header)
	if not header._buiCampaignMinimal then
		header._buiCampaignMinimal = true
		Skin.TipFace(header.Text, 'title')
		Skin.TipFace(header.NextObjective.Text, 'body')
		KeepTexture(header.Background)
		AccentFill(header.Highlight, header, ROW_HOVER_ALPHA)
	end
	Fade(header.Background)
	Button(header)
end

local function SkinCallingsHeader(header)
	if not header._buiCallings then
		header._buiCallings = true
		Skin.TipFace(header.ButtonText, 'title')
		KeepTexture(header.Background)
		KeepTexture(header.Divider)
		KeepTexture(header.SelectedTexture)
		AccentFill(header.HighlightTexture, header, ROW_HOVER_ALPHA)
		AccentFill(header.SelectedHighlight, header, SELECTED_ROW_ALPHA)
	end
	Fade(header.Background)
	Fade(header.Divider)
	Fade(header.SelectedTexture)
	Button(header)
end

local function SweepQuestLog()
	local scroll = _G.QuestScrollFrame
	for button in scroll.titleFramePool:EnumerateActive() do SkinQuestTitle(button) end
	for line in scroll.objectiveFramePool:EnumerateActive() do SkinObjective(line) end
	for header in scroll.headerFramePool:EnumerateActive() do SkinHeaderRow(header) end
	for header in scroll.campaignHeaderFramePool:EnumerateActive() do SkinCampaignHeader(header) end
	for header in scroll.campaignHeaderMinimalFramePool:EnumerateActive() do SkinCampaignMinimalHeader(header) end
	for header in scroll.covenantCallingsHeaderFramePool:EnumerateActive() do SkinCallingsHeader(header) end
end

local function SkinStoryHeader(header)
	Fade(header.Background)
	Fade(header.Divider)
	Skin.TipFace(header.Text, 'title')
	Skin.TipFace(header.Progress, 'body')
	AccentFill(header.HighlightTexture, header, ROW_HOVER_ALPHA)
	Shell(header)
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
	Fade(overview.TopShadow)
	Fade(overview.BottomShadow)
	local header = overview.Header
	Fade(header.Background)
	Fade(header.TopFiligree)
	Skin.TipFace(header.Text, 'title')
	Skin.TipFace(header.Progress, 'body')
	local scroll = overview.ScrollFrame
	ScrollBar(scroll.ScrollBar)
	local child = scroll.ScrollChild
	Fade(child and child.BG)
end

local function SkinEventRow(frame)
	if frame.Name then
		if not frame._buiEventRow then
			frame._buiEventRow = true
			Skin.TipFace(frame.Name, 'body')
			Skin.TipFace(frame.Location, 'body')
			AccentFill(frame.Highlight, frame, ROW_HOVER_ALPHA)
		end
		Fade(frame.Background)
		Fade(frame.Background2)
		Shell(frame)
	elseif frame.Label then
		if not frame._buiEventLabel then
			frame._buiEventLabel = true
			Skin.TipFace(frame.Label, frame.Background and 'title' or 'body')
		end
		Fade(frame.Background)
	end
end

local function OnEventRow(frame)
	if Enabled() then SkinEventRow(frame) end
end

local function SkinEvents(events)
	FadeRegions(events)
	Skin.FadeTree(events.BorderFrame)
	Fade(events.ScrollBox.Background)
	Body(events.ScrollBox.EmptyText)
	ScrollBar(events.ScrollBar)
	Skin.TipFace(events.TitleText, 'title')
	Skin.SweepScrollBox(events.ScrollBox, OnEventRow)
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
	RefreshSideTabs(questLog)
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
	if not skinned or not Enabled() or not Skin.RefreshQuestInfoText then return end
	if IsInsideQuestLog(parentFrame) then Skin.RefreshQuestInfoText() end
end

local function Apply()
	local map = _G.WorldMapFrame
	if map:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinWindow(map)
		SkinBorder(map.BorderFrame)
		SkinNavBar(map.NavBar)
		SkinOverlayFrames(map)
		SkinQuestLog(_G.QuestMapFrame)
	end
	SkinRareScannerSearch(map)
	SweepQuestLog()
	RefreshSideTabs(_G.QuestMapFrame)
end

local function OnQuestLogUpdated()
	if skinned and Enabled() then SweepQuestLog() end
end

local function OnTabsValidated()
	if skinned and Enabled() then RefreshSideTabs(_G.QuestMapFrame) end
end

local function Install()
	if installed then return end
	local map = _G.WorldMapFrame
	if not map then return end
	installed = true
	HookScript(map, 'OnShow', Apply)
	hooksecurefunc('NavBar_AddButton', OnNavButtonAdded)
	hooksecurefunc('QuestLogQuests_Update', OnQuestLogUpdated)
	hooksecurefunc('QuestInfo_Display', OnQuestInfoDisplayed)
	hooksecurefunc(_G.QuestMapFrame, 'ValidateTabs', OnTabsValidated)
	if map:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.WorldMap') end
end

local function Deactivate()
	context.Restore()
	ReleaseRareScannerSearch()
	if sideTabs then
		for _, tab in ipairs(sideTabs) do Skin.ResetSideTab(tab) end
	end
	skinned = false
end

Skin.OnToggle(SKIN_ID, function(enabled)
	RefreshExtras()
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.WorldMap', TryInstall)
		elseif _G.WorldMapFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'World Map',
	description = 'The map and quest log frame in the dark shell, plus continent-map extras: zone name labels and dungeon/raid entrance pins.',
	buildSettings = function(content)
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
	end,
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.WorldMapInstall', TryInstall)
