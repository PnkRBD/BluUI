local _, BUI = ...

local ipairs = ipairs
local pairs = pairs

local Skin = BUI.Skinning
local SELECTED, MUTED_TEXT, BODY_TEXT = Skin.SELECTED_COLOR, Skin.MUTED_COLOR, Skin.BODY_COLOR

local MAIN_ART = { 'Bg', 'TopTileStreaks', 'inset', 'InsetBorderBottomLeft', 'InsetBorderBottomRight', 'InsetBorderBottom', 'InsetBorderLeft', 'InsetBorderRight' }
local TAB_KEYS = { 'JourneysTab', 'MonthlyActivitiesTab', 'suggestTab', 'dungeonsTab', 'raidsTab', 'LootJournalTab', 'TutorialsTab' }
local SIDE_TAB_KEYS = { 'overviewTab', 'lootTab', 'bossTab', 'modelTab' }
local SIDE_TAB_OPTIONS = { iconKeys = { 'selected', 'unselected' }, iconWidth = 26, iconHeight = 23, width = 34, height = 34 }
local SIDE_TAB_TOP_OFFSET = -6
local DISABLED_ICON_ALPHA = 0.35
local INSTANCE_SELECT_ART = { 'bg', 'evergreenBg' }
local LOOT_ITEM_ART = { 'bossTexture', 'bosslessTexture' }
local LOOT_ITEM_TEXT_KEYS = { 'armorType', 'slot', 'boss' }
local LOOT_INSET = 1
local SEARCH_RESULT_LABEL_KEYS = { 'path', 'resultType' }
local SUGGESTION_KEYS = { 'Suggestion1', 'Suggestion2', 'Suggestion3' }
local CARD_INSET = 4
local CARD_TITLE_SCALE = 1.15
local CATEGORY_SCALE = 1.3
local TILE_TITLE_SCALE = 1.2
local SEARCH_TITLE_SCALE = 1.15
local LORE_TITLE_SCALE = 1.6
local ENCOUNTER_TITLE_SCALE = 1.2
local BOSS_TEXT_SCALE = 1.2
local BOSS_SELECTED_ALPHA = 0.12
local BULLET_SIZE = 4
local ROW_HOVER_ALPHA = 0.07
local LOOT_FILTER_GAP = 4
local LORE_COLOR = CreateColor(BODY_TEXT[1], BODY_TEXT[2], BODY_TEXT[3])
local THRESHOLD_ART = { 'BarBackground', 'BarBackgroundGlow', 'BarBorder', 'BarBorderGlow', 'BarFillGlow' }
local THRESHOLD_BARS = { 'ThresholdBar', 'BonusThresholdBar' }

local sideTabs
local bossSelections = {}

local context = Skin.Define('journeys', {
	name = 'Journeys',
	description = 'The Adventure Guide: renown cards, dungeon and raid tiles, boss lists, encounter overviews, abilities, loot tables, search and the suggested content pages.',
	icon = 'Interface/EncounterJournal/UI-EJ-PortraitIcon',
})
local Hook, Guard, Enabled = context.Hook, context.Guard, context.Enabled
local Fade, FadeRegions, FadeKeys, FadeStates, Keep = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeStates, context.Keep
local Shell, Button, Close, Dropdown, EditBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox
local ScrollBar, Body, Title, Line, SideTab = context.ScrollBar, context.Body, context.Title, context.Line, context.SideTab
local FlatTexture, SelectedTexture = Skin.FlatTexture, Skin.SelectedTexture

local function SetColor(fontString, color)
	fontString:SetTextColor(color[1], color[2], color[3], color[4])
end

local function PictureText(fontString, kind, scale)
	Skin.TipFont(fontString, kind, scale)
	fontString:SetShadowColor(0, 0, 0, 1)
	fontString:SetShadowOffset(1, -1)
end

local function SkinPanelFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	Fade(frame.PortraitContainer.portrait)
	Shell(frame)
	Title(frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
end

local function SkinNavButton(button)
	if button._buiNavButton then return end
	button._buiNavButton = true
	FadeRegions(button)
	FadeStates(button)
	Shell(button)
	Body(button.text)
	Skin.TipNavArrow(button.MenuArrowButton)
end

local function OnNavButtonAdded(navBar)
	if navBar ~= _G.EncounterJournal.navBar then return end
	local buttons = navBar.navList
	SkinNavButton(buttons[#buttons])
end

local function SkinNavBar(navBar)
	FadeRegions(navBar)
	Fade(navBar.overlay)
	SkinNavButton(navBar.homeButton)
	for _, button in ipairs(navBar.navList) do SkinNavButton(button) end
end

local function SkinSearchResult(row)
	if row._buiSearchRow then return end
	row._buiSearchRow = true
	FadeStates(row)
	Fade(row.iconFrame)
	Skin.SquareIcon(row, row.icon)
	Skin.TipFont(row.name, 'title', SEARCH_TITLE_SCALE)
	for _, key in ipairs(SEARCH_RESULT_LABEL_KEYS) do Skin.TipFont(row[key], 'label') end
end

local function SkinSearch(frame)
	EditBox(frame.searchBox)
	local results = frame.searchResults
	FadeRegions(results)
	Shell(results)
	ScrollBar(results.ScrollBar)
	Skin.SweepScrollBox(results.ScrollBox, Guard(SkinSearchResult))
end

local function SkinInstanceTile(tile)
	if tile._buiTile then return end
	tile._buiTile = true
	FadeStates(tile)
	Skin.TipIconFrame(tile, tile.bgImage)
	PictureText(tile.name, 'title', TILE_TITLE_SCALE)
	Body(tile.range)
end

local function SkinInstanceSelect(select)
	FadeKeys(select, INSTANCE_SELECT_ART)
	Skin.TipFont(select.Title, 'title', TILE_TITLE_SCALE)
	Dropdown(select.ExpansionDropdown)
	ScrollBar(select.ScrollBar)
	Skin.SweepScrollBox(select.ScrollBox, Guard(SkinInstanceTile))
end

local function SideTabs(info)
	if not sideTabs then
		sideTabs = {}
		for index, key in ipairs(SIDE_TAB_KEYS) do sideTabs[index] = info[key] end
	end
	return sideTabs
end

local function RefreshSideTabs(info)
	local tabs = SideTabs(info)
	for index, tab in ipairs(tabs) do
		SideTab(tab, SIDE_TAB_OPTIONS)
		Skin.SetSideTabSelected(tab, info.tab == index)
	end
	Skin.LayoutSideTabs(info, tabs, SIDE_TAB_TOP_OFFSET)
end

local function OnTabSet()
	RefreshSideTabs(_G.EncounterJournal.encounter.info)
end

local function OnTabEnabled(tab, enabled)
	if not tab._buiSideTab then return end
	local alpha = enabled and 1 or DISABLED_ICON_ALPHA
	tab.selected:SetAlpha(alpha)
	tab.unselected:SetAlpha(alpha)
end

local function OnBossSelected(button)
	button._buiBossSelected:Show()
end

local function OnBossUnselected(button)
	button._buiBossSelected:Hide()
end

local function SkinBossButton(button)
	if not button._buiBoss then
		button._buiBoss = true
		Skin.TipButton(button, BOSS_TEXT_SCALE)
		local selected = Keep(button:CreateTexture(nil, 'ARTWORK', nil, -1))
		selected:SetAllPoints(button)
		selected:Hide()
		button._buiBossSelected = selected
		bossSelections[#bossSelections + 1] = selected
		Hook(button, 'LockHighlight', OnBossSelected)
		Hook(button, 'UnlockHighlight', OnBossUnselected)
	end
	SelectedTexture(button._buiBossSelected, BOSS_SELECTED_ALPHA)
	button._buiBossSelected:SetShown(_G.EncounterJournal.encounterID == button.encounterID)
end

local function RefreshLootRow(item)
	Skin.SetIconEdgeQuality(item.icon, item.IconBorder)
end

local function SkinLootRow(item)
	if not item.IconBorder then return end
	if not item._buiLoot then
		item._buiLoot = true
		Keep(item.icon)
		FadeKeys(item, LOOT_ITEM_ART)
		Fade(item.IconBorder)
		Skin.SquareIcon(item, item.icon)
		Skin.TipFace(item.name, 'title')
		for _, key in ipairs(LOOT_ITEM_TEXT_KEYS) do Skin.TipFont(item[key], 'body') end
		Shell(item, LOOT_INSET)
		Hook(item, 'Init', RefreshLootRow)
	end
	RefreshLootRow(item)
end

local function RefreshHeaderState(button)
	SetColor(button.title, button:GetParent().expanded and SELECTED or MUTED_TEXT)
	SetColor(button.expandedIcon, BODY_TEXT)
end

local function SkinInfoHeader(header)
	local button = header.button
	if not header._buiHeader then
		header._buiHeader = true
		Keep(button.abilityIcon)
		Button(button)
		for _, child in ipairs({ button:GetChildren() }) do
			Keep(child.icon)
			FadeRegions(child)
		end
		Skin.TipFace(button.expandedIcon, 'title')
		Skin.TipFace(button.title, 'title')
		Skin.TipFont(header.description, 'body')
		Fade(header.descriptionBG)
		Fade(header.descriptionBGBottom)
		Skin.TipFont(header.overviewDescription.Text, 'body')
		button:HookScript('OnShow', Guard(RefreshHeaderState))
	end
	RefreshHeaderState(button)
end

local function SweepHeaders()
	local encounter = _G.EncounterJournal.encounter
	for _, header in pairs(encounter.usedHeaders) do SkinInfoHeader(header) end
	for _, header in ipairs(encounter.overviewFrame.overviews) do SkinInfoHeader(header) end
end

local function SkinBullet(bullet)
	if bullet._buiBullet then return end
	bullet._buiBullet = true
	Skin.TipFont(bullet.Text, 'body')
	local dot = bullet.Bullet
	dot:SetSize(BULLET_SIZE, BULLET_SIZE)
	SelectedTexture(dot, 1)
end

local function OnBullets(object)
	local bullets = object:GetParent().Bullets
	if not bullets then return end
	for _, bullet in ipairs(bullets) do SkinBullet(bullet) end
end

local function RecolorLore(instance)
	instance.LoreScrollingFont:SetTextColor(LORE_COLOR)
end

local function OnInstanceDisplayed()
	local encounter = _G.EncounterJournal.encounter
	RefreshSideTabs(encounter.info)
	RecolorLore(encounter.instance)
end

local function OnLootFilterUpdated()
	local loot = _G.EncounterJournal.encounter.info.LootContainer
	local filterBar = loot.classClearFilter
	if not filterBar:IsShown() then return end
	loot.ScrollBox:SetPoint('TOPLEFT', filterBar, 'BOTTOMLEFT', 14, -LOOT_FILTER_GAP)
end

local function SkinInstancePage(instance)
	Keep(instance.loreBG)
	FadeRegions(instance)
	PictureText(instance.title, 'title', LORE_TITLE_SCALE)
	local mapButton = instance.mapButton
	Keep(mapButton.texture)
	FadeRegions(mapButton)
	Body(_G[mapButton:GetName() .. 'Text'])
	ScrollBar(instance.LoreScrollBar)
	RecolorLore(instance)
end

local function SkinOverviewPage(scroll)
	ScrollBar(scroll.ScrollBar)
	local child = scroll.child
	Skin.TipFont(child.loreDescription, 'body')
	Fade(child.header)
	Skin.TipFont(_G[child:GetName() .. 'Title'], 'title')
	Skin.TipFont(child.overviewDescription.Text, 'body')
end

local function SkinDetailsPage(scroll)
	ScrollBar(scroll.ScrollBar)
	Skin.TipFont(scroll.child.description, 'body')
end

local function SkinLootPage(loot)
	ScrollBar(loot.ScrollBar)
	Dropdown(loot.filter)
	Dropdown(loot.slotFilter)
	local clear = loot.classClearFilter
	FadeRegions(clear)
	Shell(clear)
	Skin.TipFace(clear.text, 'body')
	Close((clear:GetChildren()))
	Skin.SweepScrollBox(loot.ScrollBox, Guard(SkinLootRow))
end

local function SkinModelPage(model)
	FadeRegions(model)
	PictureText(model.imageTitle, 'title')
end

local function SkinInfo(info)
	Keep(info.difficultyIcon)
	FadeRegions(info)
	Shell(info)
	Skin.TipFont(info.encounterTitle, 'title', ENCOUNTER_TITLE_SCALE)
	Skin.TipFont(info.instanceTitle, 'title', ENCOUNTER_TITLE_SCALE)
	local instanceButton = info.instanceButton
	Keep(instanceButton.icon)
	FadeRegions(instanceButton)
	Dropdown(info.difficulty)
	ScrollBar(info.BossesScrollBar)
	Skin.SweepScrollBox(info.BossesScrollBox, Guard(SkinBossButton))
	SkinOverviewPage(info.overviewScroll)
	SkinDetailsPage(info.detailsScroll)
	SkinLootPage(info.LootContainer)
	SkinModelPage(info.model)
	RefreshSideTabs(info)
end

local function SkinEncounter(encounter)
	SkinInstancePage(encounter.instance)
	SkinInfo(encounter.info)
	SweepHeaders()
end

local function CardEnter(card)
	if Enabled() then Skin.TipShellEdges(card, Skin.HoverColor()) end
end

local function CardLeave(card)
	if Enabled() then Skin.TipShellEdges(card, false) end
end

local function SkinJourneyCard(card)
	if card._buiCard then return end
	card._buiCard = true
	card:HookScript('OnEnter', CardEnter)
	card:HookScript('OnLeave', CardLeave)
	FadeStates(card)
	Skin.TipShell(card, CARD_INSET)
	Skin.TipFont(card.RenownCardFactionName or card.JourneyCardName, 'title', CARD_TITLE_SCALE)
	Body(card.RenownCardFactionLevel or card.JourneyCardLevel)
end

local function SkinJourneyEntry(entry)
	if entry.RenownCardFactionName or entry.JourneyCardName then
		SkinJourneyCard(entry)
	elseif entry.CategoryName then
		Skin.TipFont(entry.CategoryName, 'title', CATEGORY_SCALE)
	elseif entry.CategoryDivider and not entry._buiDivider then
		entry._buiDivider = true
		Fade(entry.CategoryDivider)
		Line(entry, entry, false, 14, 31)
	end
end

local function SkinJourneys(frame)
	ScrollBar(frame.ScrollBar)
	Skin.FadeTree(frame.BorderFrame)
	Skin.SweepScrollBox(frame.JourneysList, Guard(SkinJourneyEntry))
	Button(frame.JourneyProgress.OverviewBtn)
	Button(frame.JourneyOverview.OverviewBtn)
end

local function OnActivityTextColor(textContainer, data)
	if data and data.completed then
		Skin.TipFont(textContainer.NameText, 'label')
		Skin.TipFont(textContainer.ConditionsText, 'label')
	else
		Skin.TipFace(textContainer.NameText, 'title')
		Skin.TipFace(textContainer.ConditionsText, 'label')
	end
end

local function SkinActivityRow(row)
	if row._buiActivity then return end
	row._buiActivity = true
	Fade(row:GetNormalTexture())
	Fade(row.Ribbon)
	Fade(row.RibbonStacked)
	local highlight = row:GetHighlightTexture()
	highlight:SetBlendMode('BLEND')
	FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
	Shell(row, CARD_INSET)
	Skin.TipFont(row.Points, 'title')
	local textContainer = row.TextContainer
	Skin.TipFace(textContainer.NameText, 'title')
	Skin.TipFace(textContainer.ConditionsText, 'label')
	Hook(textContainer, 'UpdateTextColor', OnActivityTextColor)
end

local function SkinThresholdBar(container)
	if container._buiThreshold then return end
	container._buiThreshold = true
	for _, key in ipairs(THRESHOLD_ART) do Fade(container[key]) end
	Fade(container.BarEnd.line)
	Shell(container)
	for _, key in ipairs(THRESHOLD_BARS) do
		local bar = container[key]
		bar:SetStatusBarTexture(BUI.GetGlobalTexture())
		bar:SetStatusBarColor(SELECTED[1], SELECTED[2], SELECTED[3], 1)
	end
	local textContainer = container.TextContainer
	Body(textContainer.Points)
	Body(textContainer.ProgressText)
end

local function SkinMonthly(frame)
	ScrollBar(frame.ScrollBar)
	ScrollBar(frame.FilterList.ScrollBar)
	FadeRegions(frame.ThemeContainer)
	local header = frame.HeaderContainer
	Skin.TipFont(header.Title, 'title', CATEGORY_SCALE)
	Body(header.Month)
	Body(header.TimeLeft)
	SkinThresholdBar(frame.ThresholdContainer)
	Skin.SweepScrollBox(frame.ScrollBox, Guard(SkinActivityRow))
end

local function SkinSuggestions(frame)
	for _, key in ipairs(SUGGESTION_KEYS) do
		local suggestion = frame[key]
		Button(suggestion.button)
		Skin.TipFaceTree(suggestion.title, 1, 'title')
		Skin.TipFaceTree(suggestion.description, 1, 'body')
	end
end

local function SkinMainFrame(frame)
	SkinPanelFrame(frame)
	Dropdown(frame.LootJournalViewDropdown)
	SkinSearch(frame)
	SkinNavBar(frame.navBar)
	local tabs = {}
	for _, key in ipairs(TAB_KEYS) do tabs[#tabs + 1] = frame[key] end
	Skin.RegisterTabStrip(frame, tabs, context)
	SkinInstanceSelect(frame.instanceSelect)
	SkinEncounter(frame.encounter)
	SkinJourneys(frame.JourneysFrame)
	SkinMonthly(frame.MonthlyActivitiesFrame)
	SkinSuggestions(frame.suggestFrame)
end

local function ShowFrame(frame)
	Skin.RefreshTabStrip(frame)
	RefreshSideTabs(frame.encounter.info)
	OnLootFilterUpdated()
end

local function HookJournal()
	Hook('NavBar_AddButton', OnNavButtonAdded)
	Hook('EncounterJournal_SetTab', OnTabSet)
	Hook('EncounterJournal_SetTabEnabled', OnTabEnabled)
	Hook('EncounterJournal_DisplayInstance', OnInstanceDisplayed)
	Hook('EncounterJournal_UpdateFilterString', OnLootFilterUpdated)
	Hook('EncounterJournal_ToggleHeaders', SweepHeaders)
	Hook('EncounterJournal_SetUpOverview', SweepHeaders)
	Hook('EncounterJournal_SetBullets', OnBullets)
end

context.Window('EncounterJournal', { install = HookJournal, skin = SkinMainFrame, show = ShowFrame })

context.OnDisable(function()
	for _, selected in ipairs(bossSelections) do selected:Hide() end
end)
