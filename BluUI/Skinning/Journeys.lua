local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('Journeys')

local hooksecurefunc = BUI.Prof.MakeHooker('journeys')
local ipairs = ipairs
local pairs = pairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'journeys'
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
local BOSS_SELECTED_ALPHA = 0.18
local BULLET_SIZE = 4
local ROW_HOVER_ALPHA = 0.07
local BODY_TEXT = { 0.87, 0.87, 0.9, 1 }
local THRESHOLD_ART = { 'BarBackground', 'BarBackgroundGlow', 'BarBorder', 'BarBorderGlow', 'BarFillGlow' }
local THRESHOLD_BARS = { 'ThresholdBar', 'BonusThresholdBar' }

local installed = false
local skinned = false
local sideTabs

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, Dropdown, EditBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox
local ScrollBar, Body, Title = context.ScrollBar, context.Body, context.Title
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function SetColor(fontString, color)
	if fontString then fontString:SetTextColor(color[1], color[2], color[3], color[4]) end
end

local function AccentColor(fontString)
	if not fontString then return end
	local red, green, blue = BUILib.Theme.GetAccent()
	fontString:SetTextColor(red, green, blue, 1)
end

local function PictureText(fontString, kind, scale)
	if not fontString then return end
	Skin.TipFont(fontString, kind, scale)
	fontString:SetShadowColor(0, 0, 0, 1)
	fontString:SetShadowOffset(1, -1)
end

local function FadeStateTextures(button)
	Fade(button:GetNormalTexture())
	Fade(button:GetPushedTexture())
	Fade(button:GetDisabledTexture())
	Fade(button:GetHighlightTexture())
end

local function GuardEnabled(callback)
	return function(frame)
		if Enabled() then callback(frame) end
	end
end

local function SkinPanelFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
end

local function SkinNavButton(button)
	if not button or button._buiNavButton then return end
	button._buiNavButton = true
	FadeRegions(button)
	FadeStateTextures(button)
	Shell(button)
	Body(button.text or (button.GetFontString and button:GetFontString()))
	Skin.TipNavArrow(button.MenuArrowButton)
end

local function OnNavButtonAdded(navBar)
	local journal = _G.EncounterJournal
	if not Enabled() or not journal or navBar ~= journal.navBar then return end
	local buttons = navBar.navList
	if buttons then SkinNavButton(buttons[#buttons]) end
end

local function SkinNavBar(navBar)
	if not navBar then return end
	FadeRegions(navBar)
	Fade(navBar.overlay)
	SkinNavButton(navBar.homeButton)
	if navBar.navList then
		for _, button in ipairs(navBar.navList) do SkinNavButton(button) end
	end
end

local function SkinSearchResult(row)
	if not Enabled() or row._buiSearchRow then return end
	row._buiSearchRow = true
	FadeStateTextures(row)
	Fade(row.iconFrame)
	CropIcon(row.icon)
	Skin.TipIconFrame(row, row.icon)
	Skin.TipFont(row.name, 'title', SEARCH_TITLE_SCALE)
	for _, key in ipairs(SEARCH_RESULT_LABEL_KEYS) do Skin.TipFont(row[key], 'label') end
end

local function SkinSearch(frame)
	EditBox(frame.searchBox)
	local results = frame.searchResults
	if not results then return end
	FadeRegions(results)
	Fade(results.NineSlice)
	Shell(results)
	ScrollBar(results.ScrollBar)
end

local function SkinInstanceTile(tile)
	if tile._buiTile then return end
	tile._buiTile = true
	FadeStateTextures(tile)
	Skin.TipIconFrame(tile, tile.bgImage)
	PictureText(tile.name, 'title', TILE_TITLE_SCALE)
	Body(tile.range)
end

local function SkinInstanceSelect(select)
	if not select then return end
	FadeKeys(select, INSTANCE_SELECT_ART)
	Skin.TipFont(select.Title, 'title', TILE_TITLE_SCALE)
	Dropdown(select.ExpansionDropdown)
	ScrollBar(select.ScrollBar)
	Skin.SweepScrollBox(select.ScrollBox, GuardEnabled(SkinInstanceTile))
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
		Skin.SideTab(context, tab, SIDE_TAB_OPTIONS)
		Skin.SetSideTabSelected(tab, info.tab == index)
	end
	Skin.LayoutSideTabs(info, tabs, SIDE_TAB_TOP_OFFSET)
end

local function OnTabSet()
	if Enabled() and skinned then RefreshSideTabs(_G.EncounterJournal.encounter.info) end
end

local function OnTabEnabled(tab, enabled)
	if not Enabled() or not tab._buiSideTab then return end
	local alpha = enabled and 1 or DISABLED_ICON_ALPHA
	tab.selected:SetAlpha(alpha)
	tab.unselected:SetAlpha(alpha)
end

local function OnBossSelected(button)
	if Enabled() then button._buiBossSelected:Show() end
end

local function OnBossUnselected(button)
	button._buiBossSelected:Hide()
end

local function OnBossButton(button)
	if not Enabled() then return end
	if not button._buiBoss then
		button._buiBoss = true
		Skin.TipButton(button, BOSS_TEXT_SCALE)
		local selected = button:CreateTexture(nil, 'ARTWORK', nil, -1)
		selected.__buiSkin = true
		selected:SetAllPoints(button)
		selected:Hide()
		button._buiBossSelected = selected
		hooksecurefunc(button, 'LockHighlight', OnBossSelected)
		hooksecurefunc(button, 'UnlockHighlight', OnBossUnselected)
	end
	AccentTexture(button._buiBossSelected, BOSS_SELECTED_ALPHA)
	button._buiBossSelected:SetShown(_G.EncounterJournal.encounterID == button.encounterID)
end

local function OnLootItem(item)
	if not Enabled() then return end
	if not item._buiLoot then
		item._buiLoot = true
		KeepTexture(item.icon)
		FadeKeys(item, LOOT_ITEM_ART)
		Fade(item.IconBorder)
		CropIcon(item.icon)
		Skin.TipIconFrame(item, item.icon)
		Skin.TipFace(item.name, 'title')
		for _, key in ipairs(LOOT_ITEM_TEXT_KEYS) do Skin.TipFont(item[key], 'body') end
		Shell(item, LOOT_INSET)
	end
	Skin.SetIconEdgeQuality(item.icon, item.IconBorder)
end

local function RefreshHeaderState(button)
	if not Enabled() or not button.title then return end
	if button:GetParent().expanded then AccentColor(button.title) else SetColor(button.title, BODY_TEXT) end
	SetColor(button.expandedIcon, BODY_TEXT)
end

local function SkinInfoHeader(header)
	if header._buiHeader then return end
	header._buiHeader = true
	local button = header.button
	KeepTexture(button.abilityIcon)
	Button(button)
	for _, child in ipairs({ button:GetChildren() }) do
		KeepTexture(child.icon)
		FadeRegions(child)
	end
	Skin.TipFace(button.expandedIcon, 'title')
	Skin.TipFace(button.title, 'title')
	Skin.TipFont(header.description, 'body')
	Fade(header.descriptionBG)
	Fade(header.descriptionBGBottom)
	if header.overviewDescription then Skin.TipFont(header.overviewDescription.Text, 'body') end
	RefreshHeaderState(button)
end

local function SweepHeaders()
	if not Enabled() then return end
	local encounter = _G.EncounterJournal.encounter
	for _, header in pairs(encounter.usedHeaders) do SkinInfoHeader(header) end
	for _, header in ipairs(encounter.overviewFrame.overviews) do SkinInfoHeader(header) end
end

local function SkinBullet(bullet)
	if bullet._buiBullet then return end
	bullet._buiBullet = true
	Skin.TipFont(bullet.Text, 'body')
	local dot = bullet.Bullet
	if not dot then return end
	dot:SetSize(BULLET_SIZE, BULLET_SIZE)
	AccentTexture(dot, 1)
end

local function OnBullets(object)
	if not Enabled() then return end
	local bullets = object:GetParent().Bullets
	if not bullets then return end
	for _, bullet in ipairs(bullets) do SkinBullet(bullet) end
end

local function RecolorLore(instance)
	local scrollingFont = instance.LoreScrollingFont
	scrollingFont:SetTextColor(CreateColor(BODY_TEXT[1], BODY_TEXT[2], BODY_TEXT[3]))
	local target = scrollingFont.ScrollBox and scrollingFont.ScrollBox.ScrollTarget
	if not target then return end
	for _, child in ipairs({ target:GetChildren() }) do
		if child.FontString then SetColor(child.FontString, BODY_TEXT) end
	end
end

local function OnInstanceDisplayed()
	if not Enabled() or not skinned then return end
	local encounter = _G.EncounterJournal.encounter
	RefreshSideTabs(encounter.info)
	RecolorLore(encounter.instance)
end

local LOOT_FILTER_GAP = 4

local function OnLootFilterUpdated()
	if not Enabled() or not skinned then return end
	local loot = _G.EncounterJournal.encounter.info.LootContainer
	local filterBar = loot.classClearFilter
	if not filterBar:IsShown() then return end
	loot.ScrollBox:SetPoint('TOPLEFT', filterBar, 'BOTTOMLEFT', 14, -LOOT_FILTER_GAP)
end

local function SkinInstancePage(instance)
	KeepTexture(instance.loreBG)
	FadeRegions(instance)
	PictureText(instance.title, 'title', LORE_TITLE_SCALE)
	local mapButton = instance.mapButton
	KeepTexture(mapButton.texture)
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
end

local function SkinModelPage(model)
	FadeRegions(model)
	PictureText(model.imageTitle, 'title')
end

local function SkinInfo(info)
	KeepTexture(info.difficultyIcon)
	FadeRegions(info)
	Shell(info)
	Skin.TipFont(info.encounterTitle, 'title', ENCOUNTER_TITLE_SCALE)
	Skin.TipFont(info.instanceTitle, 'title', ENCOUNTER_TITLE_SCALE)
	local instanceButton = info.instanceButton
	KeepTexture(instanceButton.icon)
	FadeRegions(instanceButton)
	Dropdown(info.difficulty)
	ScrollBar(info.BossesScrollBar)
	SkinOverviewPage(info.overviewScroll)
	SkinDetailsPage(info.detailsScroll)
	SkinLootPage(info.LootContainer)
	SkinModelPage(info.model)
	RefreshSideTabs(info)
end

local function SkinEncounter(encounter)
	if not encounter then return end
	SkinInstancePage(encounter.instance)
	SkinInfo(encounter.info)
	SweepHeaders()
end

local function CardEnter(card)
	if card._buiCard then Skin.TipShellEdges(card, true) end
end

local function CardLeave(card)
	if card._buiCard then Skin.TipShellEdges(card, false) end
end

local function SkinJourneyCard(card)
	if card._buiCard then return end
	card._buiCard = true
	FadeStateTextures(card)
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
		local line = entry:CreateTexture(nil, 'ARTWORK')
		line.__buiSkin = true
		line:SetPoint('LEFT', entry, 'LEFT', 14, 0)
		line:SetPoint('RIGHT', entry, 'RIGHT', -31, 0)
		line:SetHeight(1)
		local edge = Skin.PANEL_EDGE
		FlatTexture(line, edge[1], edge[2], edge[3], edge[4])
	end
end

local function SkinJourneys(frame)
	if not frame then return end
	ScrollBar(frame.ScrollBar)
	Skin.FadeTree(frame.BorderFrame)
	Skin.SweepScrollBox(frame.JourneysList, GuardEnabled(SkinJourneyEntry))
	if frame.JourneyProgress then Button(frame.JourneyProgress.OverviewBtn) end
	if frame.JourneyOverview then Button(frame.JourneyOverview.OverviewBtn) end
end

local function OnActivityTextColor(textContainer, data)
	if not Enabled() then return end
	if data and data.completed then
		Skin.TipFont(textContainer.NameText, 'label')
		Skin.TipFont(textContainer.ConditionsText, 'label')
	else
		Skin.TipFace(textContainer.NameText, 'title')
		Skin.TipFace(textContainer.ConditionsText, 'label')
	end
end

local function SkinActivityRow(row)
	if not Enabled() or row._buiActivity then return end
	row._buiActivity = true
	Fade(row:GetNormalTexture())
	Fade(row.Ribbon)
	Fade(row.RibbonStacked)
	local highlight = row:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode('BLEND')
		FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
	end
	Shell(row, CARD_INSET)
	Skin.TipFont(row.Points, 'title')
	local textContainer = row.TextContainer
	if textContainer then
		Skin.TipFace(textContainer.NameText, 'title')
		Skin.TipFace(textContainer.ConditionsText, 'label')
		if textContainer.UpdateTextColor then
			hooksecurefunc(textContainer, 'UpdateTextColor', OnActivityTextColor)
		end
	end
end

local function SkinThresholdBar(container)
	if not container or container._buiThreshold then return end
	container._buiThreshold = true
	for _, key in ipairs(THRESHOLD_ART) do Fade(container[key]) end
	if container.BarEnd then Fade(container.BarEnd.line) end
	Shell(container)
	for _, key in ipairs(THRESHOLD_BARS) do
		local bar = container[key]
		if bar then
			bar:SetStatusBarTexture(BUI.GetGlobalTexture())
			local red, green, blue = BUILib.Theme.GetAccent()
			bar:SetStatusBarColor(red, green, blue, 1)
		end
	end
	local textContainer = container.TextContainer
	if textContainer then
		Body(textContainer.Points)
		Body(textContainer.ProgressText)
	end
end

local function SkinMonthly(frame)
	if not frame then return end
	ScrollBar(frame.ScrollBar)
	if frame.FilterList then ScrollBar(frame.FilterList.ScrollBar) end
	if frame.ThemeContainer then FadeRegions(frame.ThemeContainer) end
	local header = frame.HeaderContainer
	if header then
		Skin.TipFont(header.Title, 'title', CATEGORY_SCALE)
		Body(header.Month)
		Body(header.TimeLeft)
	end
	SkinThresholdBar(frame.ThresholdContainer)
	Skin.SweepScrollBox(frame.ScrollBox, GuardEnabled(SkinActivityRow))
end

local function SkinSuggestions(frame)
	if not frame then return end
	for _, key in ipairs(SUGGESTION_KEYS) do
		local suggestion = frame[key]
		if suggestion then
			Button(suggestion.button)
			Skin.TipFaceTree(suggestion.title, 1, 'title')
			Skin.TipFaceTree(suggestion.description, 1, 'body')
		end
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

local function Apply()
	local frame = _G.EncounterJournal
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMainFrame(frame)
	end
	Skin.RefreshTabStrip(frame)
	RefreshSideTabs(frame.encounter.info)
	OnLootFilterUpdated()
end

local function HookMixin(mixin, method, callback)
	if mixin and mixin[method] then hooksecurefunc(mixin, method, callback) end
end

local function HookGlobal(name, callback)
	if _G[name] then hooksecurefunc(name, callback) end
end

local function HookRows()
	HookMixin(_G.EncounterBossButtonMixin, 'Init', OnBossButton)
	HookMixin(_G.EncounterJournalItemMixin, 'Init', OnLootItem)
	HookMixin(_G.EncounterSearchResultLGMixin, 'Init', SkinSearchResult)
	HookMixin(_G.RenownCardButtonMixin, 'OnEnter', CardEnter)
	HookMixin(_G.RenownCardButtonMixin, 'OnLeave', CardLeave)
	HookMixin(_G.JourneyCardButtonMixin, 'OnEnter', CardEnter)
	HookMixin(_G.JourneyCardButtonMixin, 'OnLeave', CardLeave)
	HookGlobal('NavBar_AddButton', OnNavButtonAdded)
	HookGlobal('EncounterJournal_SetTab', OnTabSet)
	HookGlobal('EncounterJournal_SetTabEnabled', OnTabEnabled)
	HookGlobal('EncounterJournal_DisplayInstance', OnInstanceDisplayed)
	HookGlobal('EncounterJournal_UpdateFilterString', OnLootFilterUpdated)
	HookGlobal('EncounterJournal_ToggleHeaders', SweepHeaders)
	HookGlobal('EncounterJournal_SetUpOverview', SweepHeaders)
	HookGlobal('EncounterJournal_SetBullets', OnBullets)
	HookGlobal('EncounterJournal_UpdateButtonState', RefreshHeaderState)
end

local function Install()
	if installed then return end
	local frame = _G.EncounterJournal
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	HookRows()
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Journeys') end
end

local function Deactivate()
	context.Restore()
	if sideTabs then
		for _, tab in ipairs(sideTabs) do Skin.ResetSideTab(tab) end
	end
	skinned = false
	BUI.Print('Journeys skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Journeys', TryInstall)
		elseif _G.EncounterJournal:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Journeys',
	description = 'The Adventure Guide: renown cards, dungeon and raid tiles, boss lists, encounter overviews, abilities, loot tables, search and the suggested content pages.',
	icon = 'Interface/EncounterJournal/UI-EJ-PortraitIcon',
})
