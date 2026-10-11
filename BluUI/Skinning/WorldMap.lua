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
local CALLINGS_ART = { 'Background', 'Divider', 'SelectedTexture', 'SelectedHighlight', 'HighlightTexture' }
local STORY_ART = { 'Background', 'Divider', 'HighlightTexture' }
local DETAIL_BUTTON_KEYS = { 'AbandonButton', 'ShareButton', 'TrackButton' }
local SIDE_TAB_KEYS = { 'QuestsTab', 'EventsTab', 'MapLegendTab' }
local SIDE_TAB_OPTIONS = { dim = true }
local SIDE_TAB_TOP_OFFSET = -2
local ROW_HOVER_ALPHA = 0.07
local CHECK_GLYPH_SIZE = 10
local CHECK_ATLAS = 'questlog-icon-checkmark-yellow'
local ACTIVE_RING_PADDING = 3
local PARENT_WALK_DEPTH = 6
local SEARCH_WIDTH, SEARCH_HEIGHT = 160, 22
local SEARCH_INSET = 8
local SEARCH_TEXT_INSET = 6
local SEARCH_ROOM = SEARCH_WIDTH + SEARCH_INSET * 2
local TITLE_COORDS_GAP = 16
local COLUMN_LEFT, COLUMN_RIGHT = 2, 304
local TEXT_X = COLUMN_LEFT + 15
local CONTROL_X = COLUMN_RIGHT - 12
local QUEST = { top = 2, bottom = 4, control = 15 }
local HEADER = { top = 0, bottom = 0 }
local CAMPAIGN = { top = 2, bottom = 7, height = 53, title = 16, progress = 32, next = 42, pad = 8 }
local MINIMAL = { top = -2, bottom = 2, title = 9, control = 10, next = 19, pad = 5 }
local STORY = { top = 12, bottom = 14, title = 20 }

local context = Skin.Define('worldmap', {
	name = 'World Map',
	description = 'The map and quest log frame in the dark shell, plus continent-map extras: zone name labels and dungeon/raid entrance pins.',
	newLook = true,
})
local Hook = context.Hook
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Card, Dropdown = context.Shell, context.Button, context.Card, context.Dropdown
local EditBox, ScrollBar, Body = context.EditBox, context.ScrollBar, context.Body
local CollapseButton = context.CollapseButton
local SelectedTexture = Skin.SelectedTexture

local generation = 0
local sideTabs = {}
local clearedArt = {}
local restyledChecks = {}
local anchors = {}
local sizes = {}
local rareScannerSearch
local navCorner
local searchRoom

local function RefreshExtras()
	BUI.WorldMapLabels.Refresh()
	BUI.WorldMapInstancePins.Refresh()
end

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function ClearArt(texture)
	if not texture or clearedArt[texture] ~= nil then return end
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

local function Place(region, point, relativeTo, relativePoint, x, y)
	if not anchors[region] then anchors[region] = { region:GetPoint(1) } end
	region:ClearAllPoints()
	region:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function Resize(region, width, height)
	if not sizes[region] then sizes[region] = { region:GetSize() } end
	region:SetSize(width, height)
end

local function RestoreLayout()
	for region, point in pairs(anchors) do
		region:ClearAllPoints()
		region:SetPoint(unpack(point))
	end
	wipe(anchors)
	for region, size in pairs(sizes) do region:SetSize(size[1], size[2]) end
	wipe(sizes)
end

local function Span(frame)
	local left = frame.leftPadding or 0
	return left, left + frame:GetWidth()
end

local function ColumnCard(frame, shape)
	local left, right = Span(frame)
	Card(frame, { left = COLUMN_LEFT - left, right = right - COLUMN_RIGHT, top = shape.top, bottom = shape.bottom })
end

local function ColumnControl(control, frame, relativePoint, y)
	local _, right = Span(frame)
	Place(control, 'CENTER', frame, relativePoint, CONTROL_X - right, y)
end

local function ColumnTitle(text, frame, point, y)
	Place(text, point, frame, 'TOPLEFT', TEXT_X - Span(frame), y)
end

local function DividerLine(frame)
	if frame._buiDivider then return end
	local left, right = Span(frame)
	local line = context.Own(Painter.Fill(frame:CreateTexture(nil, 'ARTWORK'), 'skinLine'))
	BUILib.Skin.PixelLine(line, frame, false, COLUMN_LEFT - left, right - COLUMN_RIGHT)
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
	if button._buiGeneration == generation then return end
	button._buiGeneration = generation
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

local SyncSearchRoom = Wrap('Skin.WorldMap search room', function()
	if not navCorner then return end
	local room = rareScannerSearch.EditBox:IsShown() and SEARCH_ROOM or 0
	if room == searchRoom then return end
	searchRoom = room
	local navBar = WorldMapFrame.NavBar
	navBar:SetPoint('BOTTOMRIGHT', navCorner[1], navCorner[2], navCorner[3] - room, navCorner[4])
	NavBar_CheckLength(navBar)
end)

local function FindRareScannerSearch(map)
	local mixin = _G.RSSearchMixin
	if rareScannerSearch or not mixin then return rareScannerSearch end
	for _, child in ipairs({ map:GetChildren() }) do
		if child.OnLoad == mixin.OnLoad then
			rareScannerSearch = child
			child.EditBox:HookScript('OnShow', SyncSearchRoom)
			child.EditBox:HookScript('OnHide', SyncSearchRoom)
			return child
		end
	end
end

local function NavBarCorner(navBar)
	for index = 1, navBar:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = navBar:GetPoint(index)
		if point == 'BOTTOMRIGHT' then return { relativeTo, relativePoint, x, y } end
	end
end

local function SkinRareScannerSearch(map)
	local search = FindRareScannerSearch(map)
	if not search or navCorner then return end
	local editBox = search.EditBox
	navCorner = NavBarCorner(map.NavBar)
	FadeRegions(editBox)
	EditBox(editBox)
	editBox:SetTextInsets(SEARCH_TEXT_INSET, SEARCH_TEXT_INSET, 0, 0)
	Resize(editBox, SEARCH_WIDTH, SEARCH_HEIGHT)
	Resize(search, SEARCH_WIDTH, SEARCH_HEIGHT)
	Place(search, 'LEFT', map.NavBar, 'RIGHT', SEARCH_INSET, 0)
	SyncSearchRoom()
end

local function ReleaseRareScannerSearch()
	if not navCorner then return end
	local navBar = WorldMapFrame.NavBar
	navBar:SetPoint('BOTTOMRIGHT', unpack(navCorner))
	navCorner, searchRoom = nil, nil
	rareScannerSearch.EditBox:SetTextInsets(0, 0, 0, 0)
	NavBar_CheckLength(navBar)
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

local SyncRowHighlight = Wrap('Skin.WorldMap quest row highlight', function(texture)
	local row = texture:GetParent()
	local lit = texture:IsShown()
	if row._buiLit == lit then return end
	row._buiLit = lit
	Skin.TipShellEdges(row, lit and Skin.HoverColor())
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
	ColumnCard(button, QUEST)
	SkinTrackBox(button.Checkbox)
	ColumnControl(button.Checkbox, button, 'TOPRIGHT', -QUEST.control)
	if not button._buiHighlightHooked then
		button._buiHighlightHooked = true
		Hook(highlight, 'Show', SyncRowHighlight)
		Hook(highlight, 'Hide', SyncRowHighlight)
		Hook(highlight, 'SetShown', SyncRowHighlight)
	end
	button._buiLit = nil
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
	ColumnControl(header.CollapseButton, header, 'RIGHT', 0)
	ColumnCard(header, HEADER)
end

local function SkinCallingsHeader(header)
	FadeKeys(header, CALLINGS_ART)
	SkinListHeader(header)
end

local function AttachNextObjective(header, shape)
	local nextObjective = header.NextObjective
	local text = nextObjective.Text
	Skin.TipFace(text, 'body')
	Place(nextObjective, 'TOPLEFT', header, 'TOPLEFT', TEXT_X - Span(header) - select(4, text:GetPoint(1)), -shape.next)
	if nextObjective._buiPad then return end
	local pad = context.Own(nextObjective:CreateTexture())
	pad:SetSize(1, shape.pad + shape.bottom)
	pad:SetPoint('TOPLEFT', text, 'BOTTOMLEFT')
	nextObjective._buiPad = pad
end

local function SkinCampaignHeader(header)
	FadeKeys(header, CAMPAIGN_ART)
	Skin.TipFace(header.Text, 'title')
	Skin.TipFace(header.Progress, 'body')
	CollapseButton(header.CollapseButton)
	Resize(header.Background, header.Background:GetWidth(), CAMPAIGN.height)
	ColumnTitle(header.Text, header, 'LEFT', -CAMPAIGN.title)
	ColumnTitle(header.Progress, header, 'LEFT', -CAMPAIGN.progress)
	ColumnControl(header.CollapseButton, header, 'TOPRIGHT', -CAMPAIGN.title)
	AttachNextObjective(header, CAMPAIGN)
	ColumnCard(header, CAMPAIGN)
end

local function SkinCampaignMinimalHeader(header)
	Fade(header.Background)
	Fade(header.Highlight)
	Skin.TipFace(header.Text, 'title')
	CollapseButton(header.CollapseButton)
	ColumnTitle(header.Text, header, 'LEFT', -MINIMAL.title)
	ColumnControl(header.CollapseButton, header, 'TOPRIGHT', -MINIMAL.control)
	AttachNextObjective(header, MINIMAL)
	ColumnCard(header, MINIMAL)
end

local function SkinOnce(frame, skin)
	if frame._buiGeneration == generation then return end
	skin(frame)
	frame._buiGeneration = generation
end

local function SweepPool(pool, skin)
	for frame in pool:EnumerateActive() do SkinOnce(frame, skin) end
end

local function CampaignSetHook(skin)
	return function(header)
		if header:GetParent() == QuestScrollFrame.Contents then SkinOnce(header, skin) end
	end
end

local function SweepQuestLog()
	if not QuestMapFrame:IsVisible() then return end
	local scroll = QuestScrollFrame
	SweepPool(scroll.titleFramePool, SkinQuestTitle)
	SweepPool(scroll.objectiveFramePool, SkinObjective)
	SweepPool(scroll.headerFramePool, SkinListHeader)
	SweepPool(scroll.covenantCallingsHeaderFramePool, SkinCallingsHeader)
	SweepPool(scroll.campaignHeaderFramePool, SkinCampaignHeader)
	SweepPool(scroll.campaignHeaderMinimalFramePool, SkinCampaignMinimalHeader)
end

Hook(CampaignHeaderMixin, 'SetCampaign', CampaignSetHook(SkinCampaignHeader))
Hook(CampaignHeaderMinimalMixin, 'SetCampaign', CampaignSetHook(SkinCampaignMinimalHeader))

local function SkinStoryHeader(header)
	FadeKeys(header, STORY_ART)
	Skin.TipFace(header.Text, 'title')
	Skin.TipFace(header.Progress, 'body')
	ColumnTitle(header.Text, header, 'TOPLEFT', -STORY.title)
	ColumnCard(header, STORY)
end

local function SkinQuestScroll(scroll)
	local search = scroll.SearchBox
	local _, _, _, _, searchY = search:GetPoint(1)
	Fade(scroll.Background)
	Fade(scroll.Edge)
	Skin.FadeTree(scroll.BorderFrame)
	EditBox(search)
	Place(search, 'BOTTOMLEFT', scroll, 'TOPLEFT', COLUMN_LEFT, searchY)
	Resize(search, COLUMN_RIGHT - COLUMN_LEFT, search:GetHeight())
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
	if frame._buiGeneration == generation then return end
	frame._buiGeneration = generation
	if frame.Name then
		Skin.TipFace(frame.Name, 'body')
		Skin.TipFace(frame.Location, 'body')
		Fade(frame.Background)
		ClearArt(frame.Background)
		ClearArt(frame.Background2)
		Fade(frame.Highlight)
		Card(frame)
	elseif frame.Label then
		Skin.TipFace(frame.Label, frame.Background and 'title' or 'body')
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
	RestoreLayout()
	for _, tab in ipairs(sideTabs) do Skin.ResetSideTab(tab) end
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
