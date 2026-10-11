local _, BUI = ...

local ipairs = ipairs
local pairs = pairs
local unpack = unpack

local Skin = BUI.Skinning
local SELECTED = Skin.SELECTED_COLOR
local Painter = BUI.Painter
local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Wrap = BUI.Profiler.Wrap

local BORDER_ART = { 'Bg', 'TopTileStreaks', 'InsetBorderTop', 'Underlay' }
local DETAILS_ART = { 'Bg', 'SealMaterialBG' }
local REWARDS_ART = { 'Bottom', 'Top', 'Background' }
local CAMPAIGN_ART = { 'Background', 'TopFiligree', 'HighlightTexture', 'SelectedHighlight' }
local DETAIL_BUTTON_KEYS = { 'AbandonButton', 'ShareButton', 'TrackButton' }
local SIDE_TAB_KEYS = { 'QuestsTab', 'EventsTab', 'MapLegendTab' }
local SIDE_TAB_OPTIONS = { dim = true }
local SIDE_TAB_TOP_OFFSET = -2
local ROW_HOVER_ALPHA = 0.07
local DIVIDER_INSET = 8
local ROW_INSETS = { top = 2, bottom = 4 }
local CHECK_GLYPH_SIZE = 10
local CHECK_ATLAS = 'questlog-icon-checkmark-yellow'
local ACTIVE_RING_PADDING = 3
local PARENT_WALK_DEPTH = 6
local SEARCH_WIDTH, SEARCH_HEIGHT = 160, 22
local SEARCH_INSET = 8
local SEARCH_TEXT_INSET = 6
local LIST_ROW_WIDTH = 289
local CAMPAIGN_PLATE_TOP, CAMPAIGN_PLATE_HEIGHT = 6, 46
local CAMPAIGN_TITLE_DROP = 16
local COLLAPSE_INSET = 8
local TITLE_COORDS_GAP = 16

local context = Skin.Define('worldmap', {
	name = 'World Map',
	description = 'The map and quest log frame in the dark shell, plus continent-map extras: zone name labels and dungeon/raid entrance pins.',
	newLook = true,
})
local Hook, Enabled = context.Hook, context.Enabled
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Card, Dropdown = context.Shell, context.Button, context.Card, context.Dropdown
local EditBox, ScrollBar, Body = context.EditBox, context.ScrollBar, context.Body
local CollapseButton = context.CollapseButton
local SelectedTexture = Skin.SelectedTexture

local generation = 0
local sideTabs = {}
local clearedArt = {}
local restyledChecks = {}
local plates = {}
local movedButtons = {}
local rareScannerSearch

local function RefreshExtras()
	BUI.WorldMapLabels.Refresh()
	BUI.WorldMapInstancePins.Refresh()
end

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function ClearArt(texture)
	if clearedArt[texture] ~= nil then return end
	clearedArt[texture] = texture:GetAtlas() or false
	texture:SetTexture(nil)
end

local function RestoreArt()
	for texture, atlas in pairs(clearedArt) do
		if atlas then texture:SetAtlas(atlas, true) end
	end
	wipe(clearedArt)
	for check in pairs(restyledChecks) do
		check:SetAtlas(CHECK_ATLAS, true)
		check:SetVertexColor(1, 1, 1, 1)
		check:ClearAllPoints()
		check:SetPoint('CENTER', 1, 1)
	end
	wipe(restyledChecks)
end

local function DividerLine(frame)
	if frame._buiDivider then return end
	local line = context.Own(Painter.Fill(frame:CreateTexture(nil, 'ARTWORK'), 'skinLine'))
	BUILib.Skin.PixelLine(line, frame, false, DIVIDER_INSET, DIVIDER_INSET)
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

local function PlaceTomTomCoords()
	local coords = _G.TomTomWorldFrame
	if not coords then return end
	coords.Player:ClearAllPoints()
	coords.Player:SetPoint('LEFT', WorldMapFrame.BorderFrame.TitleContainer.TitleText, 'RIGHT', TITLE_COORDS_GAP, 0)
end

local function SkinNavButton(button)
	FadeRegions(button)
	Shell(button)
	Body(button.text)
	Skin.TipNavArrow(button.MenuArrowButton)
end

local function OnNavButtonAdded(navBar)
	if navBar ~= WorldMapFrame.NavBar then return end
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

local function SkinSideTabs(questLog)
	for index, key in ipairs(SIDE_TAB_KEYS) do
		local tab = questLog[key]
		if not sideTabs[index] then
			sideTabs[index] = tab
			Hook(tab, 'SetChecked', OnTabChecked)
		end
		Skin.SideTab(context, tab, SIDE_TAB_OPTIONS)
	end
end

local function RefreshSideTabs()
	local questLog = QuestMapFrame
	for _, tab in ipairs(sideTabs) do Skin.SetSideTabSelected(tab, IsTabSelected(questLog, tab)) end
	Skin.LayoutSideTabs(questLog, sideTabs, SIDE_TAB_TOP_OFFSET)
end

local PlateEnter = Wrap('Skin.WorldMap header plate enter', function(header)
	Skin.TipShellEdges(header._buiPlate, Skin.HoverColor())
end)

local PlateLeave = Wrap('Skin.WorldMap header plate leave', function(header)
	Skin.TipShellEdges(header._buiPlate, false)
end)

local PlateShown = Wrap('Skin.WorldMap header plate shown', function(header)
	header._buiPlate:SetShown(Enabled() and header:IsShown())
end)

local function HeaderPlate(header)
	local plate = header._buiPlate
	if not plate then
		plate = CreateFrame('Frame', nil, header:GetParent())
		plate.ignoreInLayout = true
		header._buiPlate = plate
		plates[header] = plate
		header:HookScript('OnShow', PlateShown)
		header:HookScript('OnHide', PlateShown)
		header:HookScript('OnEnter', PlateEnter)
		header:HookScript('OnLeave', PlateLeave)
	end
	plate:SetFrameStrata(header:GetFrameStrata())
	plate:SetFrameLevel(math.max(0, header:GetFrameLevel() - 1))
	plate:ClearAllPoints()
	Card(plate)
	PlateShown(header)
	return plate
end

local function MoveCollapseButton(button, plate)
	if not movedButtons[button] then movedButtons[button] = { button:GetPoint(1) } end
	button:ClearAllPoints()
	button:SetPoint('RIGHT', plate, 'TOPRIGHT', -COLLAPSE_INSET, -CAMPAIGN_TITLE_DROP)
end

local SyncRowHighlight = Wrap('Skin.WorldMap quest row highlight', function(texture)
	Skin.TipShellEdges(texture:GetParent(), texture:IsShown() and Skin.HoverColor())
end)

local function SkinTrackBox(checkbox)
	local check = checkbox.CheckMark
	for regionIndex = 1, select('#', checkbox:GetRegions()) do
		local region = select(regionIndex, checkbox:GetRegions())
		if region ~= check and region:IsObjectType('Texture') then ClearArt(region) end
	end
	restyledChecks[check] = true
	check:SetTexture(BUILib.GetLibMedia('check'))
	check:SetSize(CHECK_GLYPH_SIZE, CHECK_GLYPH_SIZE)
	check:ClearAllPoints()
	check:SetPoint('CENTER')
	check:SetVertexColor(SELECTED[1], SELECTED[2], SELECTED[3], 1)
	Shell(checkbox)
end

local function SkinQuestTitle(button)
	local highlight = button.HighlightTexture
	Skin.TipFace(button.Text, 'body')
	Fade(highlight)
	Card(button, ROW_INSETS)
	SkinTrackBox(button.Checkbox)
	if not button._buiHighlightHooked then
		button._buiHighlightHooked = true
		Hook(highlight, 'Show', SyncRowHighlight)
		Hook(highlight, 'Hide', SyncRowHighlight)
		Hook(highlight, 'SetShown', SyncRowHighlight)
	end
	SyncRowHighlight(highlight)
end

local function SkinObjective(line)
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
	local plate = HeaderPlate(header)
	plate:SetPoint('TOPLEFT', header.Background, 'TOPLEFT', 0, -CAMPAIGN_PLATE_TOP)
	plate:SetSize(LIST_ROW_WIDTH, CAMPAIGN_PLATE_HEIGHT)
	MoveCollapseButton(header.CollapseButton, plate)
end

local function SkinCampaignMinimalHeader(header)
	Fade(header.Background)
	Fade(header.Highlight)
	Skin.TipFace(header.Text, 'title')
	Skin.TipFace(header.NextObjective.Text, 'body')
	CollapseButton(header.CollapseButton)
	HeaderPlate(header):SetAllPoints(header.Background)
end

local function SkinCallingsHeader(header)
	Fade(header.Background)
	Fade(header.Divider)
	Fade(header.SelectedTexture)
	SkinListHeader(header)
end

local function SweepPool(pool, skin)
	for frame in pool:EnumerateActive() do
		if frame._buiGeneration ~= generation then
			skin(frame)
			frame._buiGeneration = generation
		end
	end
end

local function SweepQuestLog()
	if not QuestMapFrame:IsVisible() then return end
	local scroll = QuestScrollFrame
	SweepPool(scroll.titleFramePool, SkinQuestTitle)
	SweepPool(scroll.objectiveFramePool, SkinObjective)
	SweepPool(scroll.headerFramePool, SkinListHeader)
	SweepPool(scroll.campaignHeaderFramePool, SkinCampaignHeader)
	SweepPool(scroll.campaignHeaderMinimalFramePool, SkinCampaignMinimalHeader)
	SweepPool(scroll.covenantCallingsHeaderFramePool, SkinCallingsHeader)
	BUILib.Skin.QueuePixelAlign()
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
	SelectedTexture(highlight, ROW_HOVER_ALPHA)
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
	SkinSideTabs(questLog)
end

local function IsInsideQuestLog(frame)
	for _ = 1, PARENT_WALK_DEPTH do
		if not frame then return false end
		if frame == QuestMapFrame then return true end
		frame = frame:GetParent()
	end
	return false
end

local function OnQuestInfoDisplayed(_, parentFrame)
	if IsInsideQuestLog(parentFrame) then Skin.RefreshQuestInfoText() end
end

local function RefreshMap(map)
	SkinRareScannerSearch(map)
	PlaceTomTomCoords()
	SweepQuestLog()
	RefreshSideTabs()
end

local function SkinMap(map)
	generation = generation + 1
	SkinWindow(map)
	SkinBorder(map.BorderFrame)
	SkinNavBar(map.NavBar)
	SkinOverlayFrames(map)
	SkinQuestLog(QuestMapFrame)
end

local function InstallMap()
	Hook('NavBar_AddButton', OnNavButtonAdded)
	Hook('QuestLogQuests_Update', SweepQuestLog)
	Hook('QuestInfo_Display', OnQuestInfoDisplayed)
	Hook(QuestMapFrame, 'ValidateTabs', RefreshSideTabs)
	if _G.TomTom and TomTom.ShowHideWorldCoords then Hook(TomTom, 'ShowHideWorldCoords', PlaceTomTomCoords) end
end

context.Window('WorldMapFrame', { skin = SkinMap, show = RefreshMap, install = InstallMap })

context.OnDisable(function()
	ReleaseRareScannerSearch()
	RestoreArt()
	for _, tab in ipairs(sideTabs) do Skin.ResetSideTab(tab) end
	for _, plate in pairs(plates) do plate:Hide() end
	for button, point in pairs(movedButtons) do
		button:ClearAllPoints()
		button:SetPoint(unpack(point))
	end
	wipe(movedButtons)
	if _G.TomTom and TomTom.ShowHideWorldCoords and _G.TomTomWorldFrame then TomTom:ShowHideWorldCoords() end
end)

Skin.OnToggle('worldmap', RefreshExtras)

local function ExtraOption(label, key)
	return {
		label = label,
		get = function() return BUI.GetDB().interface[key] == true end,
		set = function(value)
			BUI.GetDB().interface[key] = value
			RefreshExtras()
		end,
	}
end

context.info.settings = {
	ExtraOption('Zone names on continent maps', 'worldMapZoneNames'),
	ExtraOption('Dungeon and raid pins', 'worldMapDungeonPins'),
}
