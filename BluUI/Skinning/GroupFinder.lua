local _, BUI = ...

local ipairs = ipairs

local BUILib = BluUI.BUILibClient
local Skin = BUI.Skinning
local SELECTED = Skin.SELECTED_COLOR

local BOTTOM_TAB_COUNT = 3
local GROUP_BUTTON_COUNT = 4
local PVP_CATEGORY_COUNT = 5
local MENU_ICON_SIZE = 40
local MENU_ICON_INSET = 10
local MENU_NAME_SIZE = 13
local ACTIVITY_TITLE_SIZE = 14
local LIST_CHECK_INSET = 2
local HIGHLIGHT_ALPHA = 0.06
local SELECTED_ALPHA = 0.12
local ROLE_KEYS = { 'RoleButtonTank', 'RoleButtonHealer', 'RoleButtonDPS', 'RoleButtonLeader' }
local ROLE_BAND = { width = 321, height = 64, x = -10, y = -28, alpha = 0.08 }
local PVP_ROLE_KEYS = { 'TankIcon', 'HealerIcon', 'DPSIcon' }
local LIST_OPTION_KEYS = { 'ItemLevel', 'MythicPlusRating', 'PVPRating', 'PvpItemLevel', 'VoiceChat', 'PrivateGroup', 'CrossFactionGroup' }
local LIST_DROPDOWN_KEYS = { 'GroupDropdown', 'ActivityDropdown', 'PlayStyleDropdown' }
local HONOR_BONUS_KEYS = { 'RandomBGButton', 'RandomEpicBGButton', 'Arena1Button', 'BrawlButton', 'BrawlButton2' }
local CONQUEST_KEYS = { 'RatedSoloShuffle', 'RatedBGBlitz', 'Arena2v2', 'Arena3v3', 'RatedBG' }
local REWARD_TITLE_KEYS = { 'title', 'rewardsLabel' }
local REWARD_TEXT_KEYS = { 'description', 'rewardsDescription', 'xpLabel' }
local SEARCH_ENTRY_TEXT_KEYS = { 'Name', 'ActivityName', 'Playstyle', 'ExpirationTime', 'PendingLabel' }
local ENTRY_APPLIED_COLOR = { 0.25, 0.8, 0.35, 0.14 }
local ENTRY_UNAVAILABLE_ALPHA = 0.45
local ENTRY_STATUS_SIZE = 14
local ENTRY_STATUS_LEVEL = 10
local ENTRY_PLATE_ALPHA = 0.8
local ENTRY_DELISTED = 'DELISTED'
local ENTRY_FILTERED = 'NO LONGER MATCHES'
local COLUMN_HEADER_KEYS = { 'NameColumnHeader', 'RoleColumnHeader', 'ItemLevelColumnHeader', 'RatingColumnHeader' }
local BONUS_ART_KEYS = { 'ShadowOverlay', 'WorldBattlesTexture' }
local CONQUEST_BAR_ART = { 'Border', 'Background' }
local KEYSTONE_ART = { 'InstructionBackground', 'Divider' }
local KEYSTONE_SHELL_ATLAS = 'ChallengeMode-KeystoneFrame'
local KEYSTONE_HEADING_SIZE = 20
local KEYSTONE_TEXT_SIZE = 14
local BOTTOM_ROW_PAD = 8
local SEARCH_ROW_HEIGHT = 22
local SEARCH_ROW_GAP = 6
local SEARCH_ROW_TOP = -58
local SEARCH_ROW_RIGHT = -8
local SEARCH_BOX_LEFT = 12
local BOTTOM_POINTS = { BOTTOM = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
local TOP_POINTS = { TOP = true, TOPLEFT = true, TOPRIGHT = true }

local pvpSelectedIndex

local context = Skin.Define('groupfinder', {
	name = 'Group Finder',
	description = 'Dungeons & Raids, PvP and Mythic+ window with its side menu, queue panels and Premade Groups.',
	icon = 'Interface/LFGFrame/UI-LFG-PORTRAIT',
	newLook = true,
})
local Hook = context.Hook
local Fade, FadeRegions, FadeKeys, FadeArt, Keep = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt, context.Keep
local Shell, Button, Close, Card, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Card, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Face, Title, Body, TextBox = context.ScrollBar, context.Face, context.Title, context.Body, context.TextBox
local SelectedTexture, RowHighlight, CropIcon, FlatTexture = Skin.SelectedTexture, Skin.RowHighlight, Skin.CropIcon, Skin.FlatTexture

local function FaceSize(fontString, size)
	if not fontString then return end
	fontString:SetFont(BUILib.Font, size, '')
	fontString:SetShadowColor(0, 0, 0, 0)
end

local function InsetTexture(texture, red, green, blue, alpha)
	if not texture then return end
	texture:SetColorTexture(red, green, blue, alpha)
	texture:ClearAllPoints()
	texture:SetPoint('TOPLEFT', 1, -1)
	texture:SetPoint('BOTTOMRIGHT', -1, 1)
end

local function IconButton(button)
	if not button then return end
	Keep(button.Icon)
	Button(button)
end

local function SkinRoundIcon(holder)
	if not holder then return end
	Fade(holder.Border)
	Fade(holder.Ring)
	if holder.CircleMask then holder.CircleMask:Hide() end
	Skin.SquareIcon(holder, holder.Icon)
end

local function MenuButtonName(button)
	return button.name or button.Name
end

local function SetMenuButtonSelected(button, selected)
	Skin.SetActiveEdge(button, selected)
	BUI.Painter.Text(MenuButtonName(button), selected and 'skinTitle' or 'skinText')
end

local function SkinMenuButton(button)
	if not button._buiMenuButton then
		button._buiMenuButton = true
		button.CircleMask:Hide()
		local icon = button.icon or button.Icon
		icon:ClearAllPoints()
		icon:SetPoint('LEFT', button, 'LEFT', MENU_ICON_INSET, 0)
		icon:SetSize(MENU_ICON_SIZE, MENU_ICON_SIZE)
		Skin.SquareIcon(button, icon)
		InsetTexture(button:GetHighlightTexture(), 1, 1, 1, HIGHLIGHT_ALPHA)
		FaceSize(MenuButtonName(button), MENU_NAME_SIZE)
	end
	Fade(button.bg or button.Background)
	Fade(button.ring or button.Ring)
	Card(button)
	SetMenuButtonSelected(button, false)
end

local function RefreshMenuButtons(holder, prefix, count, selectedIndex)
	for buttonIndex = 1, count do
		local button = holder[prefix .. buttonIndex]
		if button._buiMenuButton then SetMenuButtonSelected(button, buttonIndex == selectedIndex) end
	end
end

local function RefreshGroupButtons()
	local frame = _G.GroupFinderFrame
	RefreshMenuButtons(frame, 'groupButton', GROUP_BUTTON_COUNT, frame.selectionIndex)
end

local function RefreshPvpButtons()
	RefreshMenuButtons(_G.PVPQueueFrame, 'CategoryButton', PVP_CATEGORY_COUNT, pvpSelectedIndex)
end

local function SkinRoleButtons(holder, keys, prefix)
	for _, key in ipairs(keys) do
		Skin.TipRoleButton(context, prefix and _G[prefix .. key] or holder[key])
	end
end

local function SkinRewardItem(item)
	if item._buiReward then return end
	item._buiReward = true
	Fade(item.NameFrame)
	Fade(item.IconOverlay)
	Skin.SquareIcon(item, item.Icon)
	Face(item.Name)
	Face(item.Count)
end

local function SkinRewardPanel(child)
	for _, key in ipairs(REWARD_TITLE_KEYS) do Title(child[key]) end
	for _, key in ipairs(REWARD_TEXT_KEYS) do Body(child[key]) end
	Face(child.xpAmount)
	SkinRewardItem(child.MoneyReward)
end

local function OnRewardItem(parentFrame, _, index)
	SkinRewardItem(_G[parentFrame:GetName() .. 'Item' .. index])
end

local function SkinDungeonRow(button, partial)
	if not button._buiDungeonRow then
		button._buiDungeonRow = true
		CheckBox(button.enableButton, LIST_CHECK_INSET)
	end
	Skin.TipCheckGlyph(button.enableButton, partial)
	Face(button.instanceName)
	Face(button.level)
end

local function OnDungeonRow(button, dungeonID, _, checkedList)
	SkinDungeonRow(button, checkedList and checkedList[dungeonID] == 1)
end

local function SweepDungeonRow(button)
	SkinDungeonRow(button, false)
end

local function SweepDungeonRows(list)
	Skin.ForEachScrollFrame(list.ScrollBox, SweepDungeonRow)
end

local function SkinBackfill(cover)
	local name = cover:GetName()
	Button(_G[name .. 'BackfillButton'])
	Button(_G[name .. 'NoBackfillButton'])
	Skin.TipFaceTree(cover, 1)
end

local function TopOffset(frame)
	for index = 1, frame:GetNumPoints() do
		local point, _, _, _, offsetY = frame:GetPoint(index)
		if TOP_POINTS[point] then return offsetY end
	end
end

local function BottomOffset(frame)
	for index = 1, frame:GetNumPoints() do
		local point, _, _, _, offsetY = frame:GetPoint(index)
		if BOTTOM_POINTS[point] then return offsetY end
	end
end

local function RaiseBottom(frame, lift, skipRelative)
	if frame._buiRaised then return end
	local points, hasTop, hasBottom = {}, false, false
	for index = 1, frame:GetNumPoints() do
		local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(index)
		if TOP_POINTS[point] then hasTop = true end
		if BOTTOM_POINTS[point] then
			if skipRelative and relativeTo == skipRelative then return end
			hasBottom, offsetY = true, offsetY + lift
		end
		points[index] = { point, relativeTo or frame:GetParent(), relativePoint, offsetX, offsetY }
	end
	if not hasBottom then return end
	frame._buiRaised = true
	local height = frame:GetHeight()
	frame:ClearAllPoints()
	for index = 1, #points do
		local anchor = points[index]
		frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
	end
	if not hasTop then frame:SetHeight(height - lift) end
end

local function PadBottomRow(inset, buttons, content)
	if inset._buiBottomRow then return end
	local insetBottom = BottomOffset(inset)
	if not insetBottom then return end
	local tallest = 0
	for index = 1, #buttons do
		local button = buttons[index]
		if button:GetNumPoints() > 0 then
			local point, relativeTo, relativePoint, offsetX = button:GetPoint(1)
			button:SetPoint(point, relativeTo or button:GetParent(), relativePoint or point, offsetX or 0, BOTTOM_ROW_PAD)
			local height = button:GetHeight()
			if height > tallest then tallest = height end
		end
	end
	if tallest <= 0 then return end
	inset._buiBottomRow = true
	local lift = BOTTOM_ROW_PAD + tallest + BOTTOM_ROW_PAD - insetBottom
	if lift <= 0 then return end
	RaiseBottom(inset, lift)
	for index = 1, (content and #content or 0) do RaiseBottom(content[index], lift, inset) end
end

local function PaintRoleBand(texture)
	texture:SetColorTexture(1, 1, 1, 1)
	texture:SetGradient('VERTICAL', CreateColor(SELECTED[1], SELECTED[2], SELECTED[3], 0), CreateColor(SELECTED[1], SELECTED[2], SELECTED[3], ROLE_BAND.alpha))
end

local function RoleBand(texture, frame)
	Keep(texture)
	texture:ClearAllPoints()
	texture:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', ROLE_BAND.x, ROLE_BAND.y)
	texture:SetSize(ROLE_BAND.width, ROLE_BAND.height)
	BUI.Painter.Custom(texture, PaintRoleBand)
end

local function SkinDungeonFinder()
	local parent = _G.LFDParentFrame
	RoleBand(_G.LFDParentFrameRoleBackground, parent)
	FadeRegions(parent)
	FadeArt(parent.Inset)
	Shell(parent.Inset)
	local queue = _G.LFDQueueFrame
	FadeRegions(queue)
	SkinRoleButtons(queue, ROLE_KEYS, 'LFDQueueFrame')
	Dropdown(queue.TypeDropdown)
	Face(_G.LFDQueueFrameTypeDropdownName)
	local random = _G.LFDQueueFrameRandomScrollFrame
	ScrollBar(random.ScrollBar)
	SkinRewardPanel(_G.LFDQueueFrameRandomScrollFrameChildFrame)
	ScrollBar(queue.Specific.ScrollBar)
	local follower = queue.Follower
	ScrollBar(follower.ScrollBar)
	Title(_G.LFDQueueFrameFollowerTitle)
	Body(_G.LFDQueueFrameFollowerDescription)
	Button(_G.LFDQueueFrameFindGroupButton)
	PadBottomRow(parent.Inset, { _G.LFDQueueFrameFindGroupButton }, { random, queue.Specific, follower })
	SkinBackfill(queue.PartyBackfill)
	Fade(_G.LFDQueueFrameNoLFDWhileLFRBlackFilter)
	Face(_G.LFDQueueFrameNoLFDWhileLFRDescription)
	Button(_G.LFDQueueFrameNoLFDWhileLFRLeaveQueueButton)
end

local function SkinRaidFinder()
	local frame = _G.RaidFinderFrame
	RoleBand(_G.RaidFinderFrameRoleBackground, frame)
	FadeRegions(frame)
	FadeArt(frame.Inset)
	FadeArt(_G.RaidFinderFrameBottomInset)
	Shell(_G.RaidFinderFrameBottomInset)
	local cover = frame.NoRaidsCover
	FadeRegions(cover)
	Title(cover.Label)
	local queue = _G.RaidFinderQueueFrame
	FadeRegions(queue)
	SkinRoleButtons(queue, ROLE_KEYS, 'RaidFinderQueueFrame')
	Dropdown(queue.SelectionDropdown)
	Face(_G.RaidFinderQueueFrameSelectionDropdownName)
	local scroll = _G.RaidFinderQueueFrameScrollFrame
	ScrollBar(scroll.ScrollBar)
	SkinRewardPanel(_G.RaidFinderQueueFrameScrollFrameChildFrame)
	SkinBackfill(queue.PartyBackfill)
	local ineligible = _G.RaidFinderQueueFrameIneligibleFrame
	Fade(_G.RaidFinderQueueFrameIneligibleFrameBlackFilter)
	Face(ineligible.description)
	Button(ineligible.leaveQueueButton)
	Button(_G.RaidFinderFrameFindRaidButton)
	PadBottomRow(_G.RaidFinderFrameBottomInset, { _G.RaidFinderFrameFindRaidButton }, { scroll })
end

local function SkinCategoryButton(button)
	if button._buiCategory then return end
	button._buiCategory = true
	Fade(button.Cover)
	Fade(button.SelectedTexture)
	local icon = button.Icon
	icon:ClearAllPoints()
	icon:SetPoint('TOPLEFT', button, 'TOPLEFT', 1, -1)
	icon:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -1, 1)
	InsetTexture(button.HighlightTexture, 1, 1, 1, HIGHLIGHT_ALPHA)
	Face(button.Label)
end

local function OnCategoryButton(selection, buttonIndex, categoryID, filters)
	local button = selection.CategoryButtons[buttonIndex]
	SkinCategoryButton(button)
	Shell(button)
	Skin.TipShellEdges(button, selection.selectedCategory == categoryID and selection.selectedFilters == filters)
end

local function SkinSearchEntry(button)
	if button._buiSearchEntry then return end
	button._buiSearchEntry = true
	Fade(button.ResultBG)
	SelectedTexture(button.Highlight, HIGHLIGHT_ALPHA)
	for _, key in ipairs(SEARCH_ENTRY_TEXT_KEYS) do Face(button[key]) end
	IconButton(button.CancelButton)
	local cover = CreateFrame('Frame', nil, button)
	cover:SetAllPoints()
	cover:SetFrameLevel(button:GetFrameLevel() + ENTRY_STATUS_LEVEL)
	cover:SetIgnoreParentAlpha(true)
	cover:Hide()
	local plate = BUI.Painter.Fill(cover:CreateTexture(nil, 'BACKGROUND'), 'skinBackground')
	plate:SetAllPoints()
	plate:SetAlpha(ENTRY_PLATE_ALPHA)
	cover.label = cover:CreateFontString(nil, 'OVERLAY')
	cover.label:SetPoint('CENTER')
	FaceSize(cover.label, ENTRY_STATUS_SIZE)
	BUI.Painter.Text(cover.label, 'skinTitle')
	button._buiStatus = cover
end

local function FilterReason(resultID, info)
	local filter = C_LFGList.GetAdvancedFilter()
	local counts = C_LFGList.GetSearchResultMemberCounts(resultID)
	local _, class = UnitClass('player')
	if filter.needsTank and counts.TANK ~= 0 then return 'TANK TAKEN' end
	if filter.needsHealer and counts.HEALER ~= 0 then return 'HEALER TAKEN' end
	if filter.needsDamage and counts.DAMAGER >= 3 then return 'DPS FULL' end
	if filter.needsMyClass and counts[class] > 0 then return 'HAS YOUR CLASS' end
	if filter.hasTank and counts.TANK == 0 then return 'NO TANK' end
	if filter.hasHealer and counts.HEALER == 0 then return 'NO HEALER' end
	if filter.minimumRating > (info.leaderOverallDungeonScore or 0) then return 'LEADER RATING TOO LOW' end
	return ENTRY_FILTERED
end

local function EntryStatus(button)
	if button.isApplication then return end
	local pending = button.PendingLabel
	if pending:IsShown() then return pending:GetText():upper() end
	local resultID = button.resultID
	if not resultID or not C_LFGList.HasSearchResultInfo(resultID) then return end
	local info = C_LFGList.GetSearchResultInfo(resultID)
	if info.isDelisted then return ENTRY_DELISTED end
	if button.isNowFilteredOut then return FilterReason(resultID, info) end
end

local function PaintSearchEntryState(button)
	local status = EntryStatus(button)
	button:SetAlpha(status and ENTRY_UNAVAILABLE_ALPHA or 1)
	button.PendingLabel:SetAlpha(status and 0 or 1)
	button._buiStatus.label:SetText(status)
	button._buiStatus:SetShown(status ~= nil)
	local background = button.BackgroundTexture
	background:SetBlendMode('BLEND')
	if status then
		FlatTexture(background, 0, 0, 0, 0)
	elseif button.isApplication then
		FlatTexture(background, ENTRY_APPLIED_COLOR[1], ENTRY_APPLIED_COLOR[2], ENTRY_APPLIED_COLOR[3], ENTRY_APPLIED_COLOR[4])
	elseif button.isSelected then
		SelectedTexture(background, SELECTED_ALPHA)
	end
end

local function OnSearchEntry(button)
	SkinSearchEntry(button)
	PaintSearchEntryState(button)
end

local function OnApplicant(button)
	if button._buiApplicant then return end
	button._buiApplicant = true
	IconButton(button.DeclineButton)
	Button(button.InviteButton)
	IconButton(button.InviteButtonSmall)
end

local function OnAutoComplete(panel)
	for _, child in ipairs({ panel.AutoCompleteFrame:GetChildren() }) do
		if child:IsObjectType('Button') then Button(child) end
	end
end

local function AlignSearchRow(panel)
	if panel._buiSearchRow then return end
	panel._buiSearchRow = true
	local box, refresh, filter = panel.SearchBox, panel.RefreshButton, panel.FilterButton
	local rowHeight = SEARCH_ROW_HEIGHT
	local insetTop = TopOffset(panel.ResultsInset)
	if insetTop then
		local room = SEARCH_ROW_TOP - insetTop - SEARCH_ROW_GAP
		if room > 8 and room < rowHeight then rowHeight = room end
	end
	filter:SetHeight(rowHeight)
	filter:ClearAllPoints()
	filter:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', SEARCH_ROW_RIGHT, SEARCH_ROW_TOP)
	refresh:ClearAllPoints()
	refresh:SetSize(rowHeight, rowHeight)
	refresh:SetPoint('RIGHT', filter, 'LEFT', -SEARCH_ROW_GAP, 0)
	box:ClearAllPoints()
	box:SetPoint('TOPLEFT', panel, 'TOPLEFT', SEARCH_BOX_LEFT, SEARCH_ROW_TOP)
	box:SetPoint('BOTTOMRIGHT', refresh, 'BOTTOMLEFT', -SEARCH_ROW_GAP, 0)
end

local function SkinSearchPanel(panel)
	Dropdown(panel.FilterButton)
	EditBox(panel.SearchBox)
	IconButton(panel.RefreshButton)
	AlignSearchRow(panel)
	PadBottomRow(panel.ResultsInset, { panel.BackButton, panel.SignUpButton, panel.BackToGroupButton })
	FadeArt(panel.ResultsInset)
	Shell(panel.ResultsInset)
	ScrollBar(panel.ScrollBar)
	Button(panel.BackButton)
	Button(panel.SignUpButton)
	Button(panel.BackToGroupButton)
	Button(panel.ScrollBox.StartGroupButton)
	local autoComplete = panel.AutoCompleteFrame
	FadeArt(autoComplete)
	Shell(autoComplete)
end

local function SkinApplicationViewer(viewer)
	Fade(viewer.InfoBackground)
	Face(viewer.EntryName)
	Face(viewer.PrivateGroup)
	CheckBox(viewer.AutoAcceptButton)
	FadeArt(viewer.Inset)
	Shell(viewer.Inset)
	for _, key in ipairs(COLUMN_HEADER_KEYS) do
		local header = viewer[key]
		FadeRegions(header)
		Face(header.Label)
	end
	IconButton(viewer.RefreshButton)
	Button(viewer.RemoveEntryButton)
	Button(viewer.EditButton)
	Button(viewer.BrowseGroupsButton)
	ScrollBar(viewer.ScrollBar)
end

local function SkinEntryCreation(creation)
	FadeArt(creation.Inset)
	EditBox(creation.Name)
	TextBox(creation.Description)
	for _, key in ipairs(LIST_DROPDOWN_KEYS) do Dropdown(creation[key]) end
	for _, key in ipairs(LIST_OPTION_KEYS) do
		local option = creation[key]
		CheckBox(option.CheckButton)
		EditBox(option.EditBox)
	end
	Button(creation.ListGroupButton)
	Button(creation.CancelButton)
	local dialog = creation.ActivityFinder.Dialog
	FadeArt(dialog)
	FadeArt(dialog.BorderFrame)
	Shell(dialog)
	EditBox(dialog.EntryBox)
	ScrollBar(dialog.ScrollBar)
	Button(dialog.SelectButton)
	Button(dialog.CancelButton)
end

local function SkinPremadeGroups()
	local list = _G.LFGListFrame
	local category = list.CategorySelection
	FadeArt(category.Inset)
	Button(category.FindGroupButton)
	Button(category.StartGroupButton)
	PadBottomRow(category.Inset, { category.FindGroupButton, category.StartGroupButton })
	local nothing = list.NothingAvailable
	FadeArt(nothing.Inset)
	Skin.TipFaceTree(nothing, 1)
	SkinSearchPanel(list.SearchPanel)
	SkinApplicationViewer(list.ApplicationViewer)
	SkinEntryCreation(list.EntryCreation)
end

local function SkinActivityButton(button)
	if not button or button._buiActivity then return end
	button._buiActivity = true
	local selected = button.SelectedTexture
	SelectedTexture(selected, SELECTED_ALPHA)
	selected:ClearAllPoints()
	selected:SetPoint('TOPLEFT', 1, -1)
	selected:SetPoint('BOTTOMRIGHT', -1, 1)
	InsetTexture(button.HighlightTexture, 1, 1, 1, HIGHLIGHT_ALPHA)
	FaceSize(button.Title, ACTIVITY_TITLE_SIZE)
	FaceSize(button.TeamSizeText, ACTIVITY_TITLE_SIZE)
	Face(button.LevelRequirement)
	Face(button.TeamTypeText)
	Face(button.CurrentRating)
	local reward = button.Reward
	SkinRoundIcon(reward)
	if reward.EnlistmentBonus then FadeRegions(reward.EnlistmentBonus) end
	Shell(button)
end

local function SkinActivityButtons(holder, keys)
	for _, key in ipairs(keys) do
		SkinActivityButton(type(key) == 'table' and key or holder[key])
	end
end

local function SkinSpecificRow(button)
	if button._buiSpecificRow then return end
	button._buiSpecificRow = true
	Fade(button.Bg)
	Fade(button.Border)
	SelectedTexture(button.SelectedTexture, SELECTED_ALPHA)
	RowHighlight(button)
	CropIcon(button.Icon)
	Face(button.SizeText)
	Face(button.InfoText)
	Face(button.NameText)
end

local function SkinSpecificRows(scrollBox)
	Skin.ForEachScrollFrame(scrollBox, SkinSpecificRow)
end

local function OnHonorListUpdated()
	SkinSpecificRows(_G.HonorFrame.SpecificScrollBox)
end

local function RefreshConquestBar(bar)
	for keyIndex = 1, #CONQUEST_BAR_ART do bar[CONQUEST_BAR_ART[keyIndex]]:SetAlpha(0) end
	bar:SetStatusBarTexture(BUI.GetGlobalTexture())
	bar:SetStatusBarColor(SELECTED[1], SELECTED[2], SELECTED[3], 1)
end

local function SkinConquestBar(bar)
	FadeKeys(bar, CONQUEST_BAR_ART)
	Shell(bar)
	Face(bar.Label)
	RefreshConquestBar(bar)
	local reward = bar.Reward
	SkinRoundIcon(reward)
	reward:ClearAllPoints()
	reward:SetPoint('LEFT', bar, 'RIGHT')
	if bar._buiConquestHooked then return end
	bar._buiConquestHooked = true
	Hook(bar, 'Update', RefreshConquestBar)
end

local function SkinQueuePanel(panel)
	FadeRegions(panel)
	FadeArt(panel.Inset)
	SkinRoleButtons(panel.RoleList, PVP_ROLE_KEYS)
	Dropdown(panel.TypeDropdown)
	Button(panel.QueueButton)
	Button(panel.JoinButton)
	ScrollBar(panel.SpecificScrollBar)
	SkinSpecificRows(panel.SpecificScrollBox)
	local bonus = panel.BonusFrame
	if bonus then
		FadeKeys(bonus, BONUS_ART_KEYS)
		SkinActivityButtons(bonus, HONOR_BONUS_KEYS)
	end
	local trainingList = panel.BonusTrainingGroundList
	if trainingList then
		FadeKeys(trainingList, BONUS_ART_KEYS)
		SkinActivityButtons(trainingList, trainingList.BonusTrainingGroundButtons)
	end
	local specificTraining = panel.SpecificTrainingGroundList
	if specificTraining then
		ScrollBar(specificTraining.ScrollBar)
		SkinSpecificRows(specificTraining.ScrollBox)
	end
	SkinActivityButtons(panel, CONQUEST_KEYS)
	SkinConquestBar(panel.ConquestBar)
end

local function OnPvpSelection(index)
	pvpSelectedIndex = index
	RefreshPvpButtons()
end

local function SkinPvp()
	local queue = _G.PVPQueueFrame
	FadeRegions(_G.PVPUIFrame)
	for buttonIndex = 1, PVP_CATEGORY_COUNT do SkinMenuButton(queue['CategoryButton' .. buttonIndex]) end
	RefreshPvpButtons()
	local honorInset = queue.HonorInset
	FadeArt(honorInset)
	Shell(honorInset)
	SkinRoundIcon(honorInset.RatedPanel.SeasonRewardFrame)
	Button(honorInset.PlunderstormPanel.PlunderstoreButton)
	SkinQueuePanel(_G.HonorFrame)
	SkinQueuePanel(_G.ConquestFrame)
	SkinQueuePanel(_G.TrainingGroundsFrame)
	local plunderstorm = _G.PlunderstormFrame
	FadeArt(plunderstorm.Inset)
	Button(plunderstorm.StartQueue)
	local season = queue.NewSeasonPopup
	FadeRegions(season)
	Shell(season)
	Button(season.Leave)
	SkinRoundIcon(season.SeasonRewardFrame)
end

local function InstallPvp()
	Hook('HonorFrameSpecificList_Update', OnHonorListUpdated)
	Hook('PVPQueueFrame_SelectButton', OnPvpSelection)
	Hook(_G.PVPSpecificTrainingGroundButtonMixin, 'Initialize', SkinSpecificRow)
end

local function SkinDungeonIcon(child)
	if child._buiDungeonIcon then return end
	child._buiDungeonIcon = true
	local icon = child.Icon
	for _, region in ipairs({ child:GetRegions() }) do
		if region ~= icon and region:IsObjectType('Texture') then Fade(region) end
	end
	Skin.SquareIcon(child, icon)
end

local function OnChallengesUpdated(frame)
	if not frame.DungeonIcons then return end
	for _, child in ipairs(frame.DungeonIcons) do SkinDungeonIcon(child) end
end

local function KeystoneBackdropTexture(frame)
	if frame._buiKeystoneBackdrop then return frame._buiKeystoneBackdrop end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType('Texture') and region:GetAtlas() == KEYSTONE_SHELL_ATLAS then
			frame._buiKeystoneBackdrop = region
			return region
		end
	end
end

local function RefadeKeystoneArt(frame)
	local backdrop = KeystoneBackdropTexture(frame)
	if backdrop then backdrop:SetAlpha(0) end
	for keyIndex = 1, #KEYSTONE_ART do frame[KEYSTONE_ART[keyIndex]]:SetAlpha(0) end
end

local function SkinKeystoneFrame(frame)
	RefadeKeystoneArt(frame)
	Shell(frame)
	Close(frame.CloseButton)
	Button(frame.StartButton)
	FaceSize(frame.PowerLevel, KEYSTONE_HEADING_SIZE)
	FaceSize(frame.DungeonName, KEYSTONE_HEADING_SIZE)
	FaceSize(frame.TimeLimit, KEYSTONE_TEXT_SIZE)
end

local function SkinChallenges(frame)
	FadeRegions(frame)
	FadeArt(_G.ChallengesFrameInset)
	OnChallengesUpdated(frame)
	local notice = frame.SeasonChangeNoticeFrame
	FadeRegions(notice)
	Shell(notice)
	Button(notice.Leave)
	local keystone = _G.ChallengesKeystoneFrame
	if keystone:IsShown() then SkinKeystoneFrame(keystone) end
end

local function InstallChallenges(frame)
	Hook(frame, 'Update', OnChallengesUpdated)
	local keystone = _G.ChallengesKeystoneFrame
	keystone:HookScript('OnShow', BUI.Profiler.Wrap('Skin.GroupFinder keystone reskin', context.Guard(SkinKeystoneFrame)))
	Hook(keystone, 'Reset', RefadeKeystoneArt)
end

local function SkinMainFrame(frame)
	context.Chrome(frame)
	FadeRegions(frame.shadows)
	Shell(frame.Inset)
	local tabs = {}
	for tabIndex = 1, BOTTOM_TAB_COUNT do tabs[tabIndex] = frame['tab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
end

local function SkinGroupButtons()
	local frame = _G.GroupFinderFrame
	for buttonIndex = 1, GROUP_BUTTON_COUNT do SkinMenuButton(frame['groupButton' .. buttonIndex]) end
	RefreshGroupButtons()
end

local function SkinPVE(frame)
	SkinMainFrame(frame)
	SkinGroupButtons()
	SkinDungeonFinder()
	SkinRaidFinder()
	SkinPremadeGroups()
end

local function RefreshPVE(frame)
	RefreshGroupButtons()
	Skin.RefreshTabStrip(frame)
	local queue = _G.LFDQueueFrame
	SweepDungeonRows(queue.Specific)
	SweepDungeonRows(queue.Follower)
end

local function InstallPVE()
	Hook('LFGRewardsFrame_SetItemButton', OnRewardItem)
	Hook('LFGDungeonListButton_SetDungeon', OnDungeonRow)
	Hook('GroupFinderFrame_SelectGroupButton', RefreshGroupButtons)
	Hook('LFGListCategorySelection_AddButton', OnCategoryButton)
	Hook('LFGListSearchEntry_Update', OnSearchEntry)
	Hook('LFGListApplicationViewer_UpdateApplicant', OnApplicant)
	Hook('LFGListSearchPanel_UpdateAutoComplete', OnAutoComplete)
end

context.Window('PVEFrame', { skin = SkinPVE, show = RefreshPVE, install = InstallPVE })
context.Window('PVPUIFrame', { skin = SkinPvp, install = InstallPvp })
context.Window('ChallengesFrame', { skin = SkinChallenges, install = InstallChallenges })
