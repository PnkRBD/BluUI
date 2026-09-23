local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('Achievements')

local hooksecurefunc = BUI.Prof.MakeHooker('achievements')
local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme
local Pixel = BUI.Pixel

local SKIN_ID = 'achievements'
local ROW_HIDDEN_ART = { 'TitleBar', 'Glow', 'BottomLeftTsunami', 'BottomRightTsunami', 'TopLeftTsunami', 'TopRightTsunami', 'BottomTsunami1', 'TopTsunami1' }
local SEARCH_PREVIEW_COUNT = 5
local TAB_COUNT = 3
local SUMMARY_CATEGORY_COUNT = 12
local HOVER_ALPHA = 0.08
local SELECTED_ALPHA = 0.18
local HEADER_ROW_ALPHA = 0.12
local STRIPE_ALPHA = 0.03
local POINTS_TOP_OFFSET = -5
local BAR_TEXT_INSET = 6
local VALUE_GUTTER = 72
local METER_INSET = 1
local METER_TEXT_SIZE = 11
local CARD_DESCRIPTION_GAP = 4
local CARD_DESCRIPTION_TOP = -30
local CARD_SEAM = 1
local CARD_EDGE_INSET = 16
local CARD_TOP_OFFSET = 2
local BACK_OFFSET_X = -1
local BACK_OFFSET_Y = -10
local FILTERS_OFFSET_X = 3
local FILTERS_OFFSET_Y = -6
local PREVIEW_ANCHOR_X = 7
local PREVIEW_ANCHOR_Y = 5
local EXPAND_ARROW_SIZE = 10
local EXPANDED_ROTATION = 0
local COLLAPSED_ROTATION = math.pi / 2
local MINI_POINTS_OFFSET = 2
local CHECK_CROP = { 0, 1, 0.1, 0.9 }
local VALUE_SHELL_INSET = { right = VALUE_GUTTER }
local SEARCH_BOX_INSET = { left = -5, top = 4, bottom = 4 }
local FILTER_INSET = { top = -2, bottom = -2 }
local SUMMARY_PANEL_INSET = { right = -1 }
local ACHIEVEMENTS_PANEL_INSET = { right = -26 }
local STATS_PANEL_INSET = { right = -24 }
local COMPARISON_HEADER_INSET = { left = 21, right = 40, top = 13 }
local BODY_TEXT = { 0.87, 0.87, 0.9, 1 }
local MUTED_TEXT = { 0.62, 0.62, 0.66, 1 }
local ACCOUNT_TEXT = { 0.4, 0.72, 1, 1 }
local ACCOUNT_MUTED_TEXT = { 0.25, 0.42, 0.58, 1 }
local COMPLETED_TEXT = { 0.5, 0.9, 0.5, 1 }

local installed = false
local skinned = false
local autoHiddenBars = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions = context.Fade, context.FadeRegions
local Shell, Button, Close, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.EditBox, context.CheckBox
local ScrollBar, Body, Title = context.ScrollBar, context.Body, context.Title
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function HideKeys(frame, keys)
	for _, key in ipairs(keys) do
		local art = frame[key]
		if art then art:Hide() end
	end
end

local function SetColor(fontString, color)
	if not fontString then return end
	fontString:SetVertexColor(1, 1, 1, 1)
	fontString:SetTextColor(color[1], color[2], color[3], color[4])
end

local function AccentColor(fontString)
	local red, green, blue = Theme.GetAccent()
	fontString:SetVertexColor(1, 1, 1, 1)
	fontString:SetTextColor(red, green, blue, 1)
end

local function LabelColor(frame, completed)
	if frame.accountWide then return completed and ACCOUNT_TEXT or ACCOUNT_MUTED_TEXT end
	return completed and BODY_TEXT or MUTED_TEXT
end

local function FadeBorderChildren(panel)
	for _, child in ipairs({ panel:GetChildren() }) do Fade(child.NineSlice) end
end

local function HoverFill(host, alpha)
	if not host then return end
	if not host._buiHover then
		local fill = host:CreateTexture(nil, 'BACKGROUND')
		fill.__buiSkin = true
		fill:SetAllPoints(host)
		host._buiHover = fill
	end
	AccentTexture(host._buiHover, alpha)
	FadeRegions(host)
end

local function AccentFill(texture, host, alpha)
	KeepTexture(texture)
	texture:ClearAllPoints()
	texture:SetAllPoints(host)
	AccentTexture(texture, alpha)
end

local function CheckGlyph(texture)
	KeepTexture(texture)
	texture:SetTexture(BUILib.GetLibMedia('check'))
	texture:SetTexCoord(CHECK_CROP[1], CHECK_CROP[2], CHECK_CROP[3], CHECK_CROP[4])
	local red, green, blue = Theme.GetAccent()
	texture:SetVertexColor(red, green, blue, 1)
end

local function FitScrollBar(scrollBar)
	if Enabled() then scrollBar:SetAlpha(scrollBar:HasScrollableExtent() and 1 or 0) end
end

local function AutoHideScrollBar(scrollBar)
	ScrollBar(scrollBar)
	if not scrollBar._buiAutoHide then
		scrollBar._buiAutoHide = true
		autoHiddenBars[#autoHiddenBars + 1] = scrollBar
		hooksecurefunc(scrollBar, 'Update', FitScrollBar)
	end
	FitScrollBar(scrollBar)
end

local function LayoutMeter(bar)
	local meter = bar._buiMeter
	local minValue, maxValue = bar:GetMinMaxValues()
	local span = maxValue - minValue
	local fraction = span > 0 and (bar:GetValue() - minValue) / span or 0
	fraction = math.min(math.max(fraction, 0), 1)
	local width = (bar:GetWidth() - bar._buiGutter - METER_INSET * 2) * fraction
	if width < 1 then
		meter:Hide()
		return
	end
	meter:SetWidth(width)
	meter:Show()
end

local function BuildMeter(bar, gutter)
	local meter = bar:CreateTexture(nil, 'ARTWORK')
	meter.__buiSkin = true
	meter:SetPoint('TOPLEFT', bar, 'TOPLEFT', METER_INSET, -METER_INSET)
	meter:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT', METER_INSET, METER_INSET)
	bar._buiMeter = meter
	bar._buiGutter = gutter
	HookScript(bar, 'OnValueChanged', LayoutMeter)
	HookScript(bar, 'OnMinMaxChanged', LayoutMeter)
	HookScript(bar, 'OnSizeChanged', LayoutMeter)
end

local function MeterText(fontString)
	if not fontString then return end
	Pixel.ApplyFont(fontString, METER_TEXT_SIZE, BUILib.Font, 'OUTLINE')
	fontString:SetTextColor(1, 1, 1, 1)
	fontString:SetJustifyV('MIDDLE')
	fontString:SetHeight(0)
end

local function BarLabel(bar, name)
	return bar.Label or bar.Title or (name and _G[name .. 'Title'])
end

local function BarValue(bar, name)
	return bar.Text or (name and _G[name .. 'Text'])
end

local function AnchorBarText(bar, label, value)
	local gutter = bar._buiGutter
	if label then
		label:ClearAllPoints()
		label:SetPoint('LEFT', bar, 'LEFT', BAR_TEXT_INSET, 0)
		if gutter > 0 then
			label:SetPoint('RIGHT', bar, 'RIGHT', -(gutter + BAR_TEXT_INSET), 0)
			label:SetJustifyH('LEFT')
			label:SetWordWrap(false)
		end
	end
	if value then
		value:ClearAllPoints()
		value:SetPoint('RIGHT', bar, 'RIGHT', gutter > 0 and 0 or -BAR_TEXT_INSET, 0)
		value:SetJustifyH('RIGHT')
	end
end

local function SkinBar(bar, sideText, gutter)
	if not bar._buiMeter then
		BuildMeter(bar, gutter and VALUE_GUTTER or 0)
		local name = bar:GetName()
		local label, value = BarLabel(bar, name), BarValue(bar, name)
		MeterText(label)
		MeterText(value)
		if sideText then AnchorBarText(bar, label, value) end
	end
	Fade(bar:GetStatusBarTexture())
	FadeRegions(bar)
	Shell(bar, gutter and VALUE_SHELL_INSET or nil)
	AccentTexture(bar._buiMeter, 1)
	LayoutMeter(bar)
end

local function SkinSummaryBar(bar)
	SkinBar(bar, true, true)
	HoverFill(_G[bar:GetName() .. 'ButtonHighlight'], HOVER_ALPHA)
end

local function SkinIconFrame(iconFrame)
	if not iconFrame._buiIcon then
		iconFrame._buiIcon = true
		CropIcon(iconFrame.texture)
		Skin.TipIconFrame(iconFrame, iconFrame.texture)
	end
	Fade(iconFrame.frame)
	Fade(iconFrame.bling)
end

local function PaintPoints(points, completed)
	Skin.TipFont(points, 'title')
	if completed then AccentColor(points) else SetColor(points, MUTED_TEXT) end
end

local function SkinShield(shield, completed)
	Fade(shield.Icon)
	PaintPoints(shield.Points, completed)
end

local function ObjectiveTextColor(objectivesFrame, objective)
	if not objective.Check:IsShown() then return MUTED_TEXT end
	if objectivesFrame.completed then return BODY_TEXT end
	return COMPLETED_TEXT
end

local function PaintObjectiveText(objectivesFrame, objective, text)
	SetColor(text, ObjectiveTextColor(objectivesFrame, objective))
	text:SetShadowOffset(0, 0)
end

local function SkinCriteria(objectivesFrame, criteria)
	if not criteria._buiObjective then
		criteria._buiObjective = true
		CheckGlyph(criteria.Check)
		Skin.TipFace(criteria.Name, 'body')
	end
	PaintObjectiveText(objectivesFrame, criteria, criteria.Name)
end

local function SkinMeta(objectivesFrame, meta)
	if not meta._buiObjective then
		meta._buiObjective = true
		CheckGlyph(meta.Check)
		CropIcon(meta.Icon)
		Skin.TipIconFrame(meta, meta.Icon)
		local highlight = meta:GetHighlightTexture()
		highlight:SetBlendMode('BLEND')
		AccentTexture(highlight, HOVER_ALPHA)
		Skin.TipFace(meta.Label, 'body')
	end
	Fade(meta.Border)
	PaintObjectiveText(objectivesFrame, meta, meta.Label)
end

local function SkinMini(mini)
	if not mini._buiObjective then
		mini._buiObjective = true
		CropIcon(mini.Icon)
		Skin.TipIconFrame(mini, mini.Icon)
		local points = mini.Points
		MeterText(points)
		points:SetWidth(0)
		points:ClearAllPoints()
		points:SetPoint('BOTTOMRIGHT', mini.Icon, 'BOTTOMRIGHT', MINI_POINTS_OFFSET, -MINI_POINTS_OFFSET)
	end
	Fade(mini.Border)
	Fade(mini.Shield)
end

local function SkinObjective(objectivesFrame, objective)
	if objective.SetStatusBarTexture then
		SkinBar(objective)
	elseif objective.Shield then
		SkinMini(objective)
	elseif objective.Border then
		SkinMeta(objectivesFrame, objective)
	elseif objective.Name then
		SkinCriteria(objectivesFrame, objective)
	end
end

local function SkinObjectives(objectivesFrame)
	for objective in objectivesFrame.pools:EnumerateActive() do SkinObjective(objectivesFrame, objective) end
end

local function OnCategoryRow(category)
	if not Enabled() then return end
	local button = category.Button
	if not button._buiCategory then
		button._buiCategory = true
		local highlight = button:GetHighlightTexture()
		highlight:SetBlendMode('BLEND')
		highlight:ClearAllPoints()
		highlight:SetAllPoints(button)
		AccentTexture(highlight, HOVER_ALPHA)
	end
	Skin.TipFace(button.Label, 'body')
	button.Label:SetJustifyV('MIDDLE')
	Fade(button.Background)
end

local function OnCategorySelection(category, selected)
	if not Enabled() then return end
	local label = category.Button.Label
	if selected then AccentColor(label) else SetColor(label, BODY_TEXT) end
end

local function BuildExpandArrow(row)
	local arrow = Skin.TipArrow(row, true)
	arrow:ClearAllPoints()
	arrow:SetPoint('CENTER', row.PlusMinus, 'CENTER', 0, 0)
	arrow:SetSize(EXPAND_ARROW_SIZE, EXPAND_ARROW_SIZE)
end

local function OnPlusMinus(row)
	local arrow = row._buiTipArrow
	if not arrow or not Enabled() then return end
	arrow:SetShown(row.PlusMinus:IsShown())
	arrow:SetRotation(row.collapsed and COLLAPSED_ROTATION or EXPANDED_ROTATION)
end

local function PaintRow(row)
	SetColor(row.Label, LabelColor(row, row.completed))
	SetColor(row.Description, BODY_TEXT)
	SetColor(row.HiddenDescription, BODY_TEXT)
	row.Description:SetShadowOffset(0, 0)
	if row.completed then AccentColor(row.Reward) else SetColor(row.Reward, MUTED_TEXT) end
	SkinShield(row.Shield, row.completed)
end

local function OnAchievementRow(row)
	if not Enabled() then return end
	if not row._buiRow then
		row._buiRow = true
		CheckGlyph(row.Check)
		FadeRegions(row)
		HideKeys(row, ROW_HIDDEN_ART)
		Skin.TipFace(row.Label, 'title')
		Skin.TipFace(row.Description, 'body')
		Skin.TipFace(row.HiddenDescription, 'body')
		Skin.TipFace(row.Reward, 'body')
		Skin.TipFont(row.DateCompleted, 'label')
		HoverFill(row.Highlight, HOVER_ALPHA)
		CheckBox(row.Tracked, 0)
		BuildExpandArrow(row)
		Shell(row)
	end
	Fade(row.NineSlice)
	Fade(row.Tabard)
	SkinIconFrame(row.Icon)
	PaintRow(row)
	OnPlusMinus(row)
end

local function OnRowObjectives(row)
	if Enabled() then SkinObjectives(row:GetObjectiveFrame()) end
end

local function AnchorCardDescription(card)
	local description, icon, shield = card.Description, card.Icon, card.Shield
	if not description then return end
	local _, _, _, _, iconTop = icon:GetPoint(1)
	local _, _, _, _, shieldTop = shield:GetPoint(1)
	description:ClearAllPoints()
	description:SetPoint('TOPLEFT', icon, 'TOPRIGHT', CARD_DESCRIPTION_GAP, CARD_DESCRIPTION_TOP - (iconTop or 0))
	description:SetPoint('TOPRIGHT', shield, 'TOPLEFT', -CARD_DESCRIPTION_GAP, CARD_DESCRIPTION_TOP - (shieldTop or 0))
end

local function PaintCard(card)
	local completed = card.saturatedStyle ~= nil
	SetColor(card.Label, LabelColor(card, completed))
	SetColor(card.Description, BODY_TEXT)
	if card.Description then card.Description:SetShadowOffset(0, 0) end
	SetColor(card.Status, completed and BODY_TEXT or MUTED_TEXT)
	SkinShield(card.Shield, completed)
end

local function SkinCard(card)
	if not card._buiCard then
		card._buiCard = true
		FadeRegions(card)
		HideKeys(card, ROW_HIDDEN_ART)
		Skin.TipFace(card.Label, 'title')
		Skin.TipFace(card.Description, 'body')
		AnchorCardDescription(card)
		Skin.TipFont(card.DateCompleted, 'label')
		Skin.TipFont(card.Status, 'label')
		HoverFill(card.Highlight, HOVER_ALPHA)
		Shell(card)
	end
	Fade(card.NineSlice)
	SkinIconFrame(card.Icon)
	PaintCard(card)
end

local function OnSummaryUpdated()
	if not Enabled() then return end
	local cards = _G.AchievementFrameSummaryAchievements.buttons
	if not cards then return end
	local header = _G.AchievementFrameSummaryAchievementsHeader
	local previous
	for _, card in ipairs(cards) do
		SkinCard(card)
		if card:IsShown() then
			card:ClearAllPoints()
			if previous then
				card:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, CARD_SEAM)
				card:SetPoint('TOPRIGHT', previous, 'BOTTOMRIGHT', 0, CARD_SEAM)
			else
				card:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', CARD_EDGE_INSET, CARD_TOP_OFFSET)
				card:SetPoint('TOPRIGHT', header, 'BOTTOMRIGHT', -CARD_EDGE_INSET, CARD_TOP_OFFSET)
			end
			previous = card
		end
	end
end

local function StatFill(row)
	local fill = row._buiFill
	if fill then return fill end
	fill = row:CreateTexture(nil, 'BACKGROUND')
	fill.__buiSkin = true
	fill:SetAllPoints(row)
	row._buiFill = fill
	return fill
end

local function SkinStatRow(row)
	row._buiRow = true
	FadeRegions(row)
	Skin.TipFont(row.Title, 'title')
	Skin.TipFace(row.Value, 'body')
	SetColor(row.Value, BODY_TEXT)
	if row.SetNormalFontObject then
		Skin.TipButtonFonts(row)
		local hover = row:CreateTexture(nil, 'HIGHLIGHT')
		hover.__buiSkin = true
		hover:SetAllPoints(row)
		AccentTexture(hover, HOVER_ALPHA)
	else
		Skin.TipFace(row.Text, 'body')
	end
end

local function OnStatRow(row, elementData)
	if not Enabled() then return end
	if not row._buiRow then SkinStatRow(row) end
	row.Background:SetAlpha(0)
	if row.FriendValue then
		Skin.TipFace(row.FriendValue, 'body')
		SetColor(row.FriendValue, BODY_TEXT)
	end
	local fill = StatFill(row)
	if elementData.header then
		AccentTexture(fill, HEADER_ROW_ALPHA)
	else
		FlatTexture(fill, 1, 1, 1, elementData.colorIndex == 1 and STRIPE_ALPHA or 0)
	end
end

local function OnComparisonRow(row)
	if not Enabled() then return end
	SkinCard(row.Player)
	SkinCard(row.Friend)
end

local function OnSearchResultRow(row)
	if not Enabled() or row._buiRow then return end
	row._buiRow = true
	KeepTexture(row.Icon)
	local highlight = row:GetHighlightTexture()
	KeepTexture(highlight)
	highlight:SetBlendMode('BLEND')
	Skin.RowHighlight(row, HOVER_ALPHA)
	FadeRegions(row)
	CropIcon(row.Icon)
	Skin.TipIconFrame(row, row.Icon)
	Skin.TipFont(row.Name, 'title')
	Skin.TipFont(row.Path, 'label')
	Skin.TipFont(row.ResultType, 'label')
end

local function SkinSearchPreviewButton(button)
	if not button._buiPreview then
		button._buiPreview = true
		KeepTexture(button.Icon)
		CropIcon(button.Icon)
		AccentFill(button.SelectedTexture, button, SELECTED_ALPHA)
		Skin.TipFont(button.Name, 'body')
		Skin.TipFont(button.Text, 'body')
	end
	FadeRegions(button)
end

local function PreviewBox(container)
	local box = container._buiBox
	if box then return box end
	box = CreateFrame('Frame', nil, container)
	box:SetFrameLevel(container:GetFrameLevel())
	box:SetPoint('TOPRIGHT', container, 'TOPRIGHT', 0, 0)
	box:SetPoint('BOTTOMLEFT', container.BorderAnchor, 'BOTTOMLEFT', PREVIEW_ANCHOR_X, PREVIEW_ANCHOR_Y)
	container._buiBox = box
	return box
end

local function SkinSearchPreview(container)
	FadeRegions(container)
	Shell(PreviewBox(container))
	for previewIndex = 1, SEARCH_PREVIEW_COUNT do SkinSearchPreviewButton(container['SearchPreview' .. previewIndex]) end
	SkinSearchPreviewButton(container.ShowAllSearchResults)
end

local function RefreshBackButton()
	if not Enabled() then return end
	local back = _G.AchievementFrame.HeaderDetails.Back
	back:SetAlpha(back:IsEnabled() and 1 or 0)
end

local function OnRefreshView()
	if Enabled() then _G.AchievementFrame.Header.Points:SetVertexColor(1, 1, 1, 1) end
end

local function RefreshTabs()
	Skin.RefreshTabStrip(_G.AchievementFrame)
end

local function SkinHeader(frame)
	local header = frame.Header
	FadeRegions(header)
	header.Title:Hide()
	local points = header.Points
	points:ClearAllPoints()
	points:SetPoint('TOP', frame, 'TOP', 0, POINTS_TOP_OFFSET)
	Title(points)
end

local function SkinHeaderDetails(details)
	FadeRegions(details)
	local back = details.Back
	Button(back)
	back:SetPoint('TOPLEFT', details, 'TOPLEFT', BACK_OFFSET_X, BACK_OFFSET_Y)
	local filters = details.Filters
	filters:SetPoint('TOPRIGHT', details, 'TOPRIGHT', FILTERS_OFFSET_X, FILTERS_OFFSET_Y)
	local dropdown = filters.FilterDropdown
	Shell(dropdown, FILTER_INSET)
	Skin.TipDropdown(dropdown, nil, true)
	local searchBox = filters.SearchBox
	EditBox(searchBox, SEARCH_BOX_INSET)
	Skin.TipFont(searchBox.Instructions, 'label')
	SkinSearchPreview(searchBox.SearchPreviewContainer)
	SkinBar(searchBox.SearchProgressBar)
end

local function SkinCategories(categories)
	FadeRegions(categories)
	Fade(categories.NineSlice)
	Shell(categories)
	AutoHideScrollBar(categories.ScrollBar)
end

local function SkinAchievementsPanel(panel)
	FadeRegions(panel)
	FadeBorderChildren(panel)
	Shell(panel, ACHIEVEMENTS_PANEL_INSET)
	Body(_G.AchievementFrameAchievementsFeatOfStrengthText)
	Skin.TipFace(_G.AchievementFrameAchievementsObjectives.RepCriteria, 'body')
	AutoHideScrollBar(panel.ScrollBar)
end

local function SkinStats(stats)
	Fade(_G.AchievementFrameStatsBG)
	FadeBorderChildren(stats)
	Shell(stats, STATS_PANEL_INSET)
	AutoHideScrollBar(stats.ScrollBar)
end

local function SkinSummary(summary)
	FadeRegions(summary)
	FadeBorderChildren(summary)
	Shell(summary, SUMMARY_PANEL_INSET)
	Fade(_G.AchievementFrameSummaryAchievementsHeaderHeader)
	Title(_G.AchievementFrameSummaryAchievementsHeaderTitle)
	Body(_G.AchievementFrameSummaryAchievementsEmptyText)
	Fade(_G.AchievementFrameSummaryCategoriesHeaderTexture)
	Title(_G.AchievementFrameSummaryCategoriesHeaderTitle)
	SkinBar(_G.AchievementFrameSummaryCategoriesStatusBar, true, true)
	for categoryIndex = 1, SUMMARY_CATEGORY_COUNT do
		SkinSummaryBar(_G['AchievementFrameSummaryCategoriesCategory' .. categoryIndex])
	end
	OnSummaryUpdated()
end

local function SkinComparisonHeader(header)
	local portrait = _G.AchievementFrameComparisonHeaderPortrait
	KeepTexture(portrait)
	FadeRegions(header)
	Shell(header, COMPARISON_HEADER_INSET)
	Skin.TipIconFrame(header, portrait)
	Body(_G.AchievementFrameComparisonHeaderName)
	Title(header.Points)
end

local function SkinComparisonCard(card)
	FadeRegions(card)
	Fade(card.NineSlice)
	Shell(card)
	SkinBar(card.StatusBar, true)
end

local function SkinComparison(comparison)
	FadeRegions(comparison)
	FadeBorderChildren(comparison)
	SkinComparisonHeader(_G.AchievementFrameComparisonHeader)
	SkinComparisonCard(comparison.Summary.Player)
	SkinComparisonCard(comparison.Summary.Friend)
	AutoHideScrollBar(comparison.AchievementContainer.ScrollBar)
	AutoHideScrollBar(comparison.StatContainer.ScrollBar)
end

local function SkinSearchResults(results)
	FadeRegions(results)
	Shell(results)
	Title(results.TitleText)
	Close(results.CloseButton)
	AutoHideScrollBar(results.ScrollBar)
end

local function SkinMainFrame(frame)
	FadeRegions(frame)
	Shell(frame)
	Close(_G.AchievementFrameCloseButton)
	SkinHeader(frame)
	local tabs = {}
	for tabIndex = 1, TAB_COUNT do tabs[tabIndex] = _G['AchievementFrameTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
	SkinCategories(frame.Categories)
	SkinHeaderDetails(frame.HeaderDetails)
	SkinAchievementsPanel(_G.AchievementFrameAchievements)
	SkinStats(_G.AchievementFrameStats)
	SkinSummary(_G.AchievementFrameSummary)
	SkinComparison(_G.AchievementFrameComparison)
	SkinSearchResults(frame.SearchResults)
end

local function Apply()
	local frame = _G.AchievementFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMainFrame(frame)
	end
	Skin.RefreshTabStrip(frame)
	OnSummaryUpdated()
	RefreshBackButton()
	OnRefreshView()
end

local function HookMixin(mixin, method, callback)
	if mixin and mixin[method] then hooksecurefunc(mixin, method, callback) end
end

local function Install()
	if installed then return end
	local frame = _G.AchievementFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	HookMixin(_G.AchievementCategoryTemplateMixin, 'Init', OnCategoryRow)
	HookMixin(_G.AchievementCategoryTemplateMixin, 'UpdateSelectionState', OnCategorySelection)
	HookMixin(_G.AchievementTemplateMixin, 'Init', OnAchievementRow)
	HookMixin(_G.AchievementTemplateMixin, 'DisplayObjectives', OnRowObjectives)
	HookMixin(_G.AchievementTemplateMixin, 'UpdatePlusMinusTexture', OnPlusMinus)
	HookMixin(_G.AchievementStatTemplateMixin, 'Init', OnStatRow)
	HookMixin(_G.AchievementComparisonTemplateMixin, 'Init', OnComparisonRow)
	HookMixin(_G.AchivementComparisonStatMixin, 'Init', OnStatRow)
	HookMixin(_G.AchievementFullSearchResultsButtonMixin, 'Init', OnSearchResultRow)
	hooksecurefunc('AchievementFrameSummary_UpdateAchievements', OnSummaryUpdated)
	hooksecurefunc('AchievementFrame_UpdateTabs', RefreshTabs)
	hooksecurefunc('AchievementFrame_RefreshBackButton', RefreshBackButton)
	hooksecurefunc('AchievementFrame_RefreshView', OnRefreshView)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Achievements') end
end

local function Deactivate()
	context.Restore()
	for _, scrollBar in ipairs(autoHiddenBars) do scrollBar:SetAlpha(1) end
	local frame = _G.AchievementFrame
	if frame then frame.HeaderDetails.Back:SetAlpha(1) end
	skinned = false
	BUI.Print('Achievements skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Achievements', TryInstall)
		elseif _G.AchievementFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Achievements',
	description = 'The achievements window: dark shell, flat category list, card rows for achievements, summary and comparison, accent progress bars, statistics, search and tabs.',
	icon = 'Interface/Icons/Achievement_Level_10',
})
