local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('Achievements')

local hooksecurefunc = BUI.Prof.MakeHooker('achievements')
local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme
local Pixel = BUI.Pixel

local SKIN_ID = 'achievements'
local ACHIEVEMENT_ADDON = 'Blizzard_AchievementUI'
local ROW_HIDDEN_ART = { 'TitleBar', 'Glow', 'BottomLeftTsunami', 'BottomRightTsunami', 'TopLeftTsunami', 'TopRightTsunami', 'BottomTsunami1', 'TopTsunami1' }
local ROW_KEPT_ART = { 'Check', 'PlusMinus' }
local SEARCH_PREVIEW_COUNT = 5
local TAB_COUNT = 3
local SUMMARY_CATEGORY_COUNT = 12
local HOVER_ALPHA = 0.08
local SELECTED_ALPHA = 0.18
local POINTS_TOP_OFFSET = -5
local BAR_TEXT_INSET = 6
local METER_INSET = 1
local METER_TEXT_SIZE = 11
local COMPARISON_HEADER_INSET = 8
local CARD_DESCRIPTION_GAP = 4
local CARD_SEAM = 1
local CARD_DESCRIPTION_TOP = -30
local BODY_TEXT = { 0.87, 0.87, 0.9, 1 }
local MUTED_TEXT = { 0.62, 0.62, 0.66, 1 }
local ACCOUNT_TEXT = { 0.4, 0.72, 1, 1 }
local ACCOUNT_MUTED_TEXT = { 0.25, 0.42, 0.58, 1 }
local COMPLETED_TEXT = { 0.5, 0.9, 0.5, 1 }

local installed = false
local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions = context.Fade, context.FadeRegions
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Body, Title = context.ScrollBar, context.Body, context.Title
local AccentTexture, CropIcon = Skin.AccentTexture, Skin.CropIcon

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function KeepKeys(frame, keys)
	for _, key in ipairs(keys) do KeepTexture(frame[key]) end
end

local function HideKeys(frame, keys)
	for _, key in ipairs(keys) do
		local art = frame[key]
		if art then art:Hide() end
	end
end

local function SetColor(fontString, color)
	if fontString then fontString:SetTextColor(color[1], color[2], color[3], color[4]) end
end

local function AccentColor(fontString)
	if not fontString then return end
	local red, green, blue = Theme.GetAccent()
	fontString:SetTextColor(red, green, blue, 1)
end

local function FadeBackdropChildren(panel)
	for _, child in ipairs({ panel:GetChildren() }) do
		if child.backdropInfo then Fade(child) end
	end
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
	if not texture then return end
	KeepTexture(texture)
	texture:ClearAllPoints()
	texture:SetAllPoints(host)
	AccentTexture(texture, alpha)
end

local function LayoutMeter(bar)
	local meter = bar._buiMeter
	local minValue, maxValue = bar:GetMinMaxValues()
	local span = maxValue - minValue
	local fraction = span > 0 and (bar:GetValue() - minValue) / span or 0
	fraction = math.min(math.max(fraction, 0), 1)
	local width = (bar:GetWidth() - METER_INSET * 2) * fraction
	if width < 1 then
		meter:Hide()
		return
	end
	meter:SetWidth(width)
	meter:Show()
end

local function BuildMeter(bar)
	Fade(bar:GetStatusBarTexture())
	local meter = bar:CreateTexture(nil, 'ARTWORK')
	meter.__buiSkin = true
	meter:SetPoint('TOPLEFT', bar, 'TOPLEFT', METER_INSET, -METER_INSET)
	meter:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT', METER_INSET, METER_INSET)
	bar._buiMeter = meter
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

local function AnchorBarText(bar, label, text)
	if label then
		label:ClearAllPoints()
		label:SetPoint('LEFT', bar, 'LEFT', BAR_TEXT_INSET, 0)
	end
	if text then
		text:ClearAllPoints()
		text:SetPoint('RIGHT', bar, 'RIGHT', -BAR_TEXT_INSET, 0)
	end
end

local function SkinBar(bar, sideText)
	if not bar then return end
	if not bar._buiMeter then
		BuildMeter(bar)
		local name = bar:GetName()
		local label = bar.Label or bar.Title or (name and _G[name .. 'Title'])
		local text = bar.Text or (name and _G[name .. 'Text'])
		MeterText(label)
		MeterText(text)
		if sideText then AnchorBarText(bar, label, text) end
	end
	AccentTexture(bar._buiMeter, 1)
	FadeRegions(bar)
	Shell(bar)
	LayoutMeter(bar)
end

local function SkinSummaryBar(bar)
	if not bar then return end
	SkinBar(bar, true)
	HoverFill(_G[bar:GetName() .. 'ButtonHighlight'], HOVER_ALPHA)
end

local function SkinIconFrame(iconFrame)
	if not iconFrame or iconFrame._buiIcon then return end
	iconFrame._buiIcon = true
	CropIcon(iconFrame.texture)
	Skin.TipIconFrame(iconFrame, iconFrame.texture)
	if iconFrame.frame then iconFrame.frame:Hide() end
	Fade(iconFrame.bling)
end

local function ObjectiveTextColor(objectivesFrame, objective)
	if not objective.Check:IsShown() then return MUTED_TEXT end
	if objectivesFrame.completed then return BODY_TEXT end
	return COMPLETED_TEXT
end

local function SkinObjective(objectivesFrame, objective)
	if objective.SetStatusBarTexture then
		SkinBar(objective)
		return
	end
	local text = objective.Name or objective.Label
	if not text or not objective.Check then return end
	if not objective._buiObjective then
		objective._buiObjective = true
		Skin.TipFace(text, 'body')
	end
	SetColor(text, ObjectiveTextColor(objectivesFrame, objective))
	text:SetShadowOffset(0, 0)
end

local function SkinObjectives(objectivesFrame)
	if not objectivesFrame or not objectivesFrame.pools then return end
	for objective in objectivesFrame.pools:EnumerateActive() do SkinObjective(objectivesFrame, objective) end
end

local function OnCategoryRow(category)
	if not Enabled() then return end
	local button = category.Button
	if not button._buiCategory then
		button._buiCategory = true
		local highlight = button:GetHighlightTexture()
		highlight:SetBlendMode('BLEND')
		AccentTexture(highlight, HOVER_ALPHA)
		Skin.TipFace(button.Label, 'body')
	end
	Fade(button.Background)
end

local function OnCategorySelection(category, selected)
	if not Enabled() then return end
	local label = category.Button.Label
	if selected then AccentColor(label) else SetColor(label, BODY_TEXT) end
end

local function RowLabelColor(row)
	if row.accountWide then
		return row.completed and ACCOUNT_TEXT or ACCOUNT_MUTED_TEXT
	end
	return row.completed and BODY_TEXT or MUTED_TEXT
end

local function PaintRowText(row)
	SetColor(row.Label, RowLabelColor(row))
	SetColor(row.Description, BODY_TEXT)
	row.Description:SetShadowOffset(0, 0)
end

local function OnRowObjectives(row)
	if Enabled() then SkinObjectives(row:GetObjectiveFrame()) end
end

local function OnAchievementRow(row)
	if not Enabled() then return end
	if not row._buiRow then
		row._buiRow = true
		KeepKeys(row, ROW_KEPT_ART)
		FadeRegions(row)
		HideKeys(row, ROW_HIDDEN_ART)
		Skin.TipFace(row.Label, 'title')
		Skin.TipFace(row.Description, 'body')
		Skin.TipFace(row.HiddenDescription, 'body')
		Skin.TipFace(row.Reward, 'body')
		Skin.TipFont(row.DateCompleted, 'label')
		CheckBox(row.Tracked, 0)
		HoverFill(row.Highlight, HOVER_ALPHA)
		SkinIconFrame(row.Icon)
		Shell(row)
	end
	PaintRowText(row)
end

local function AnchorCardDescription(card)
	local description, icon, shield = card.Description, card.Icon, card.Shield
	if not description or not icon or not shield then return end
	local _, _, _, _, iconTop = icon:GetPoint(1)
	local _, _, _, _, shieldTop = shield:GetPoint(1)
	description:ClearAllPoints()
	description:SetPoint('TOPLEFT', icon, 'TOPRIGHT', CARD_DESCRIPTION_GAP, CARD_DESCRIPTION_TOP - (iconTop or 0))
	description:SetPoint('TOPRIGHT', shield, 'TOPLEFT', -CARD_DESCRIPTION_GAP, CARD_DESCRIPTION_TOP - (shieldTop or 0))
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
		SkinIconFrame(card.Icon)
		Shell(card)
	end
	SetColor(card.Label, card.accountWide and ACCOUNT_TEXT or BODY_TEXT)
	if card.Description then
		SetColor(card.Description, BODY_TEXT)
		card.Description:SetShadowOffset(0, 0)
	end
end

local function OnSummaryUpdated()
	if not Enabled() then return end
	local cards = _G.AchievementFrameSummaryAchievements.buttons
	if not cards then return end
	local previous
	for _, card in ipairs(cards) do
		SkinCard(card)
		if card:IsShown() then
			if previous then
				card:ClearAllPoints()
				card:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, CARD_SEAM)
				card:SetPoint('TOPRIGHT', previous, 'BOTTOMRIGHT', 0, CARD_SEAM)
			end
			previous = card
		end
	end
end

local function OnStatRow(row)
	if not Enabled() or row._buiRow then return end
	row._buiRow = true
	FadeRegions(row)
	Skin.TipFace(row.Title, 'title')
	Skin.TipFace(row.Text, 'body')
	Skin.TipFace(row.Value, 'body')
	Skin.TipFace(row.FriendValue, 'body')
	Skin.RowHighlight(row, HOVER_ALPHA)
	Shell(row)
end

local function OnComparisonRow(row)
	if not Enabled() then return end
	SkinCard(row.Player)
	SkinCard(row.Friend)
end

local function SkinSearchResultRow(row)
	if not Enabled() or row._buiRow then return end
	row._buiRow = true
	KeepTexture(row.Icon)
	FadeRegions(row)
	Skin.TipFace(row.Name, 'title')
	Skin.TipFace(row.Path, 'body')
	Skin.TipFace(row.ResultType, 'body')
	CropIcon(row.Icon)
	Skin.TipIconFrame(row, row.Icon)
	Skin.RowHighlight(row, HOVER_ALPHA)
end

local function SkinSearchPreviewButton(button)
	if not button then return end
	if not button._buiPreview then
		button._buiPreview = true
		CropIcon(button.Icon)
		AccentFill(button.SelectedTexture, button, SELECTED_ALPHA)
		Skin.TipFace(button.Name, 'body')
		Skin.TipFace(button.Text, 'body')
	end
	Fade(button.IconFrame)
end

local function SkinSearchPreview(container)
	if not container then return end
	FadeRegions(container)
	Shell(container)
	for previewIndex = 1, SEARCH_PREVIEW_COUNT do SkinSearchPreviewButton(container['SearchPreview' .. previewIndex]) end
	SkinSearchPreviewButton(container.ShowAllSearchResults)
end

local function SkinHeader(frame)
	local header = frame.Header
	KeepTexture(header.Shield)
	FadeRegions(header)
	header.Title:Hide()
	local points = header.Points
	points:ClearAllPoints()
	points:SetPoint('TOP', frame, 'TOP', 0, POINTS_TOP_OFFSET)
	Title(points)
end

local function SkinHeaderDetails(details)
	FadeRegions(details)
	Button(details.Back)
	local filters = details.Filters
	Dropdown(filters.FilterDropdown)
	local searchBox = filters.SearchBox
	EditBox(searchBox)
	SkinSearchPreview(searchBox.SearchPreviewContainer)
	SkinBar(searchBox.SearchProgressBar)
end

local function SkinCategories(categories)
	FadeRegions(categories)
	Shell(categories)
	ScrollBar(categories.ScrollBar)
end

local function SkinAchievementsPanel(panel)
	FadeRegions(panel)
	FadeBackdropChildren(panel)
	Body(_G.AchievementFrameAchievementsFeatOfStrengthText)
	local objectives = _G.AchievementFrameAchievementsObjectives
	if objectives then Skin.TipFace(objectives.RepCriteria, 'body') end
	ScrollBar(panel.ScrollBar)
end

local function SkinStats(stats)
	Fade(_G.AchievementFrameStatsBG)
	FadeBackdropChildren(stats)
	ScrollBar(stats.ScrollBar)
end

local function SkinSummary(summary)
	FadeRegions(summary)
	FadeBackdropChildren(summary)
	Fade(_G.AchievementFrameSummaryAchievementsHeaderHeader)
	Title(_G.AchievementFrameSummaryAchievementsHeaderTitle)
	Body(_G.AchievementFrameSummaryAchievementsEmptyText)
	Fade(_G.AchievementFrameSummaryCategoriesHeaderTexture)
	Title(_G.AchievementFrameSummaryCategoriesHeaderTitle)
	SkinBar(_G.AchievementFrameSummaryCategoriesStatusBar, true)
	for categoryIndex = 1, SUMMARY_CATEGORY_COUNT do
		SkinSummaryBar(_G['AchievementFrameSummaryCategoriesCategory' .. categoryIndex])
	end
	OnSummaryUpdated()
end

local function SkinComparisonCard(card)
	FadeRegions(card)
	Shell(card)
	SkinBar(card.StatusBar, true)
end

local function SkinComparison(comparison)
	FadeRegions(comparison)
	FadeBackdropChildren(comparison)
	local header = _G.AchievementFrameComparisonHeader
	KeepTexture(_G.AchievementFrameComparisonHeaderPortrait)
	FadeRegions(header)
	Shell(header, COMPARISON_HEADER_INSET)
	Body(_G.AchievementFrameComparisonHeaderName)
	Title(header.Points)
	SkinComparisonCard(comparison.Summary.Player)
	SkinComparisonCard(comparison.Summary.Friend)
	ScrollBar(comparison.AchievementContainer.ScrollBar)
	ScrollBar(comparison.StatContainer.ScrollBar)
end

local function SkinSearchResults(results)
	FadeRegions(results)
	Shell(results)
	Title(results.TitleText)
	Close(results.CloseButton)
	ScrollBar(results.ScrollBar)
	Skin.SweepScrollBox(results.ScrollBox, SkinSearchResultRow)
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
	HookMixin(_G.AchievementStatTemplateMixin, 'Init', OnStatRow)
	HookMixin(_G.AchievementComparisonTemplateMixin, 'Init', OnComparisonRow)
	HookMixin(_G.AchivementComparisonStatMixin, 'Init', OnStatRow)
	hooksecurefunc('AchievementFrameSummary_UpdateAchievements', OnSummaryUpdated)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Achievements') end
end

local function Deactivate()
	context.Restore()
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
	test = function()
		if not _G.AchievementFrame then
			C_AddOns.LoadAddOn(ACHIEVEMENT_ADDON)
			TryInstall()
		end
		local frame = _G.AchievementFrame
		if not frame then return end
		if not frame:IsShown() then ToggleAchievementFrame() end
		return frame
	end,
	stopTest = function()
		if _G.AchievementFrame then HideUIPanel(_G.AchievementFrame) end
	end,
})
