local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('GroupFinder')

local hooksecurefunc = BUI.Prof.MakeHooker('groupfinder')
local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme

local SKIN_ID = 'groupfinder'
local PVP_ADDON = 'Blizzard_PVPUI'
local CHALLENGES_ADDON = 'Blizzard_ChallengesUI'
local BOTTOM_TAB_COUNT = 3
local GROUP_BUTTON_COUNT = 4
local PVP_CATEGORY_COUNT = 5
local MENU_ICON_SIZE = 40
local MENU_ICON_INSET = 10
local MENU_NAME_SIZE = 13
local ACTIVITY_TITLE_SIZE = 14
local LIST_CHECK_INSET = 2
local HIGHLIGHT_ALPHA = 0.06
local SELECTED_ALPHA = 0.15
local MENU_REST_FILL = { 0.03, 0.03, 0.036, 0.97 }
local MENU_SELECTED_FILL = { 0.075, 0.078, 0.088, 0.97 }
local MENU_TEXT = { 0.87, 0.87, 0.9, 1 }
local ROLE_KEYS = { 'RoleButtonTank', 'RoleButtonHealer', 'RoleButtonDPS', 'RoleButtonLeader' }
local PVP_ROLE_KEYS = { 'TankIcon', 'HealerIcon', 'DPSIcon' }
local LIST_OPTION_KEYS = { 'ItemLevel', 'MythicPlusRating', 'PVPRating', 'PvpItemLevel', 'VoiceChat', 'PrivateGroup', 'CrossFactionGroup' }
local LIST_DROPDOWN_KEYS = { 'GroupDropdown', 'ActivityDropdown', 'PlayStyleDropdown' }
local HONOR_BONUS_KEYS = { 'RandomBGButton', 'RandomEpicBGButton', 'Arena1Button', 'BrawlButton', 'BrawlButton2' }
local CONQUEST_KEYS = { 'RatedSoloShuffle', 'RatedBGBlitz', 'Arena2v2', 'Arena3v3', 'RatedBG' }
local REWARD_TITLE_KEYS = { 'title', 'rewardsLabel' }
local REWARD_TEXT_KEYS = { 'description', 'rewardsDescription', 'xpLabel' }
local SEARCH_ENTRY_TEXT_KEYS = { 'Name', 'ActivityName', 'Playstyle', 'ExpirationTime', 'PendingLabel' }
local ENTRY_APPLIED_COLOR = { 0.25, 0.8, 0.35, 0.14 }
local ENTRY_FILTERED_COLOR = { 0.85, 0.25, 0.25, 0.14 }
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

local installed = false
local skinned = false
local pvpSkinned = false
local pvpHooked = false
local challengesSkinned = false
local challengesHooked = false
local pvpSelectedIndex

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Face, Title, Body, TextBox = context.ScrollBar, context.Face, context.Title, context.Body, context.TextBox
local AccentTexture, RowHighlight, CropIcon, FlatTexture = Skin.AccentTexture, Skin.RowHighlight, Skin.CropIcon, Skin.FlatTexture

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

local function KeepIcon(button)
	if button and button.Icon then button.Icon.__buiSkin = true end
end

local function IconButton(button)
	if not button then return end
	KeepIcon(button)
	Button(button)
end

local function SkinRoundIcon(holder)
	if not holder then return end
	Fade(holder.Border)
	Fade(holder.Ring)
	if holder.CircleMask then holder.CircleMask:Hide() end
	CropIcon(holder.Icon)
	Skin.TipIconFrame(holder, holder.Icon)
end

local function MenuButtonName(button)
	return button.name or button.Name
end

local function SetMenuButtonSelected(button, selected)
	local shell = button._buiShell
	if shell then
		local fill = selected and MENU_SELECTED_FILL or MENU_REST_FILL
		shell.fill:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
	end
	local name = MenuButtonName(button)
	if not name then return end
	if selected then
		local red, green, blue = Theme.GetAccent()
		name:SetTextColor(red, green, blue, 1)
	else
		name:SetTextColor(MENU_TEXT[1], MENU_TEXT[2], MENU_TEXT[3], MENU_TEXT[4])
	end
end

local function SkinMenuButton(button)
	if not button then return end
	if not button._buiMenuButton then
		button._buiMenuButton = true
		if button.CircleMask then button.CircleMask:Hide() end
		local icon = button.icon or button.Icon
		if icon then
			icon:ClearAllPoints()
			icon:SetPoint('LEFT', button, 'LEFT', MENU_ICON_INSET, 0)
			icon:SetSize(MENU_ICON_SIZE, MENU_ICON_SIZE)
			CropIcon(icon)
			Skin.TipIconFrame(button, icon)
		end
		InsetTexture(button:GetHighlightTexture(), 1, 1, 1, HIGHLIGHT_ALPHA)
		FaceSize(MenuButtonName(button), MENU_NAME_SIZE)
	end
	Fade(button.bg or button.Background)
	Fade(button.ring or button.Ring)
	Shell(button)
	SetMenuButtonSelected(button, false)
end

local function RefreshMenuButtons(holder, prefix, count, selectedIndex)
	if not holder then return end
	for buttonIndex = 1, count do
		local button = holder[prefix .. buttonIndex]
		if button and button._buiMenuButton then SetMenuButtonSelected(button, buttonIndex == selectedIndex) end
	end
end

local function RefreshGroupButtons()
	local frame = _G.GroupFinderFrame
	if frame then RefreshMenuButtons(frame, 'groupButton', GROUP_BUTTON_COUNT, frame.selectionIndex) end
end

local function RefreshPvpButtons()
	RefreshMenuButtons(_G.PVPQueueFrame, 'CategoryButton', PVP_CATEGORY_COUNT, pvpSelectedIndex)
end

local function SkinRoleButton(button)
	Skin.TipRoleButton(context, button)
end

local function SkinRoleButtons(holder, keys, prefix)
	if not holder then return end
	for _, key in ipairs(keys) do
		SkinRoleButton(prefix and _G[prefix .. key] or holder[key])
	end
end

local function SkinRewardItem(item)
	if not item or item._buiReward then return end
	item._buiReward = true
	local name = item.GetName and item:GetName()
	local icon = item.Icon or (name and _G[name .. 'IconTexture'])
	Fade(item.NameFrame or (name and _G[name .. 'NameFrame']))
	Fade(item.IconOverlay)
	CropIcon(icon)
	Skin.TipIconFrame(item, icon)
	Face(item.Name or (name and _G[name .. 'Name']))
	Face(item.Count or (name and _G[name .. 'Count']))
end

local function SkinRewardPanel(child)
	if not child then return end
	for _, key in ipairs(REWARD_TITLE_KEYS) do Title(child[key]) end
	for _, key in ipairs(REWARD_TEXT_KEYS) do Body(child[key]) end
	Face(child.xpAmount)
	SkinRewardItem(child.MoneyReward)
end

local function OnRewardItem(parentFrame, _, index)
	if not Enabled() then return end
	local name = parentFrame and parentFrame.GetName and parentFrame:GetName()
	if name then SkinRewardItem(_G[name .. 'Item' .. index]) end
end

local function SkinDungeonRow(button, partial)
	if not button._buiDungeonRow then
		button._buiDungeonRow = true
		CheckBox(button.enableButton, LIST_CHECK_INSET)
	end
	if button.enableButton then Skin.TipCheckGlyph(button.enableButton, partial) end
	Face(button.instanceName)
	Face(button.level)
end

local function OnDungeonRow(button, dungeonID, _, checkedList)
	if not Enabled() or not button then return end
	SkinDungeonRow(button, checkedList and dungeonID and checkedList[dungeonID] == 1)
end

local function SweepDungeonRow(button)
	SkinDungeonRow(button, false)
end

local function SweepDungeonRows(list)
	local box = list and list.ScrollBox
	Skin.ForEachScrollFrame(box, SweepDungeonRow)
end

local function SkinBackfill(cover)
	if not cover then return end
	local name = cover:GetName()
	if not name then return end
	Button(_G[name .. 'BackfillButton'])
	Button(_G[name .. 'NoBackfillButton'])
	Skin.TipFaceTree(cover, 1)
end

local function TopOffset(frame)
	if not frame then return end
	for index = 1, frame:GetNumPoints() do
		local point, _, _, _, offsetY = frame:GetPoint(index)
		if TOP_POINTS[point] then return offsetY end
	end
end

local function BottomOffset(frame)
	if not frame then return end
	for index = 1, frame:GetNumPoints() do
		local point, _, _, _, offsetY = frame:GetPoint(index)
		if BOTTOM_POINTS[point] then return offsetY end
	end
end

local function RaiseBottom(frame, lift, skipRelative)
	if not frame or frame._buiRaised then return end
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
	if not inset or inset._buiBottomRow then return end
	local insetBottom = BottomOffset(inset)
	if not insetBottom then return end
	local tallest = 0
	for index = 1, #buttons do
		local button = buttons[index]
		if button and button:GetNumPoints() > 0 then
			local point, relativeTo, relativePoint, offsetX = button:GetPoint(1)
			button:SetPoint(point, relativeTo or button:GetParent(), relativePoint or point, offsetX or 0, BOTTOM_ROW_PAD)
			local height = button:GetHeight() or 0
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

local function SkinDungeonFinder()
	local parent = _G.LFDParentFrame
	if not parent then return end
	FadeRegions(parent)
	FadeArt(parent.Inset)
	Shell(parent.Inset)
	local queue = _G.LFDQueueFrame
	if not queue then return end
	FadeRegions(queue)
	SkinRoleButtons(queue, ROLE_KEYS, 'LFDQueueFrame')
	Dropdown(queue.TypeDropdown)
	Face(_G.LFDQueueFrameTypeDropdownName)
	local random = _G.LFDQueueFrameRandomScrollFrame
	if random then
		ScrollBar(random.ScrollBar)
		SkinRewardPanel(_G.LFDQueueFrameRandomScrollFrameChildFrame)
	end
	if queue.Specific then ScrollBar(queue.Specific.ScrollBar) end
	local follower = queue.Follower
	if follower then
		ScrollBar(follower.ScrollBar)
		Title(_G.LFDQueueFrameFollowerTitle)
		Body(_G.LFDQueueFrameFollowerDescription)
	end
	Button(_G.LFDQueueFrameFindGroupButton)
	PadBottomRow(parent.Inset, { _G.LFDQueueFrameFindGroupButton },
		{ _G.LFDQueueFrameRandomScrollFrame, queue.Specific, queue.Follower })
	SkinBackfill(queue.PartyBackfill)
	Fade(_G.LFDQueueFrameNoLFDWhileLFRBlackFilter)
	Face(_G.LFDQueueFrameNoLFDWhileLFRDescription)
	Button(_G.LFDQueueFrameNoLFDWhileLFRLeaveQueueButton)
end

local function SkinRaidFinder()
	local frame = _G.RaidFinderFrame
	if not frame then return end
	FadeRegions(frame)
	FadeArt(frame.Inset)
	FadeArt(_G.RaidFinderFrameBottomInset)
	Shell(_G.RaidFinderFrameBottomInset)
	local cover = frame.NoRaidsCover
	if cover then
		FadeRegions(cover)
		Title(cover.Label)
	end
	local queue = _G.RaidFinderQueueFrame
	if not queue then return end
	FadeRegions(queue)
	SkinRoleButtons(queue, ROLE_KEYS, 'RaidFinderQueueFrame')
	Dropdown(queue.SelectionDropdown)
	Face(_G.RaidFinderQueueFrameSelectionDropdownName)
	local scroll = _G.RaidFinderQueueFrameScrollFrame
	if scroll then
		ScrollBar(scroll.ScrollBar)
		SkinRewardPanel(_G.RaidFinderQueueFrameScrollFrameChildFrame)
	end
	SkinBackfill(queue.PartyBackfill)
	local ineligible = _G.RaidFinderQueueFrameIneligibleFrame
	if ineligible then
		Fade(_G.RaidFinderQueueFrameIneligibleFrameBlackFilter)
		Face(ineligible.description)
		Button(ineligible.leaveQueueButton)
	end
	Button(_G.RaidFinderFrameFindRaidButton)
	PadBottomRow(_G.RaidFinderFrameBottomInset, { _G.RaidFinderFrameFindRaidButton },
		{ _G.RaidFinderQueueFrameScrollFrame })
end

local function SkinCategoryButton(button)
	if button._buiCategory then return end
	button._buiCategory = true
	Fade(button.Cover)
	Fade(button.SelectedTexture)
	local icon = button.Icon
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint('TOPLEFT', button, 'TOPLEFT', 1, -1)
		icon:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -1, 1)
	end
	InsetTexture(button.HighlightTexture or button:GetHighlightTexture(), 1, 1, 1, HIGHLIGHT_ALPHA)
	Face(button.Label)
end

local function OnCategoryButton(selection, buttonIndex, categoryID, filters)
	if not Enabled() then return end
	local button = selection.CategoryButtons and selection.CategoryButtons[buttonIndex]
	if not button then return end
	SkinCategoryButton(button)
	Shell(button)
	Skin.TipShellEdges(button, selection.selectedCategory == categoryID and selection.selectedFilters == filters)
end

local function SkinSearchEntry(button)
	if button._buiSearchEntry then return end
	button._buiSearchEntry = true
	Fade(button.ResultBG)
	AccentTexture(button.Highlight, SELECTED_ALPHA)
	for _, key in ipairs(SEARCH_ENTRY_TEXT_KEYS) do Face(button[key]) end
	IconButton(button.CancelButton)
end

local function PaintSearchEntryState(button)
	local background = button.BackgroundTexture
	if not background then return end
	background:SetBlendMode('BLEND')
	if button.isNowFilteredOut then
		FlatTexture(background, ENTRY_FILTERED_COLOR[1], ENTRY_FILTERED_COLOR[2], ENTRY_FILTERED_COLOR[3], ENTRY_FILTERED_COLOR[4])
	elseif button.isApplication then
		FlatTexture(background, ENTRY_APPLIED_COLOR[1], ENTRY_APPLIED_COLOR[2], ENTRY_APPLIED_COLOR[3], ENTRY_APPLIED_COLOR[4])
	elseif button.isSelected then
		AccentTexture(background, SELECTED_ALPHA)
	end
end

local function OnSearchEntry(button)
	if not Enabled() or not button then return end
	SkinSearchEntry(button)
	PaintSearchEntryState(button)
end

local function OnApplicant(button)
	if not Enabled() or not button or button._buiApplicant then return end
	button._buiApplicant = true
	IconButton(button.DeclineButton)
	Button(button.InviteButton)
	Button(button.InviteButtonSmall)
end

local function OnAutoComplete(panel)
	if not Enabled() then return end
	local autoComplete = panel and panel.AutoCompleteFrame
	if not autoComplete then return end
	for _, child in ipairs({ autoComplete:GetChildren() }) do
		if child.IsObjectType and child:IsObjectType('Button') then Button(child) end
	end
end

local function AlignSearchRow(panel)
	local box, refresh, filter = panel.SearchBox, panel.RefreshButton, panel.FilterButton
	if not box or not refresh or not filter or panel._buiSearchRow then return end
	panel._buiSearchRow = true
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
	if not panel then return end
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
	if panel.ScrollBox then Button(panel.ScrollBox.StartGroupButton) end
	local autoComplete = panel.AutoCompleteFrame
	if autoComplete then
		FadeArt(autoComplete)
		Shell(autoComplete)
	end
end

local function SkinApplicationViewer(viewer)
	if not viewer then return end
	Fade(viewer.InfoBackground)
	Face(viewer.EntryName)
	Face(viewer.PrivateGroup)
	CheckBox(viewer.AutoAcceptButton)
	FadeArt(viewer.Inset)
	Shell(viewer.Inset)
	for _, key in ipairs(COLUMN_HEADER_KEYS) do
		local header = viewer[key]
		if header then
			FadeRegions(header)
			Face(header.Label)
		end
	end
	IconButton(viewer.RefreshButton)
	Button(viewer.RemoveEntryButton)
	Button(viewer.EditButton)
	Button(viewer.BrowseGroupsButton)
	ScrollBar(viewer.ScrollBar)
end

local function SkinEntryCreation(creation)
	if not creation then return end
	FadeArt(creation.Inset)
	EditBox(creation.Name)
	TextBox(creation.Description)
	for _, key in ipairs(LIST_DROPDOWN_KEYS) do Dropdown(creation[key]) end
	for _, key in ipairs(LIST_OPTION_KEYS) do
		local option = creation[key]
		if option then
			CheckBox(option.CheckButton)
			EditBox(option.EditBox)
		end
	end
	Button(creation.ListGroupButton)
	Button(creation.CancelButton)
	local dialog = creation.ActivityFinder and creation.ActivityFinder.Dialog
	if dialog then
		FadeArt(dialog)
		FadeArt(dialog.BorderFrame)
		Shell(dialog)
		EditBox(dialog.EntryBox)
		ScrollBar(dialog.ScrollBar)
		Button(dialog.SelectButton)
		Button(dialog.CancelButton)
	end
end

local function SkinPremadeGroups()
	local list = _G.LFGListFrame
	if not list then return end
	local category = list.CategorySelection
	if category then
		FadeArt(category.Inset)
		Button(category.FindGroupButton)
		Button(category.StartGroupButton)
		PadBottomRow(category.Inset, { category.FindGroupButton, category.StartGroupButton })
	end
	local nothing = list.NothingAvailable
	if nothing then
		FadeArt(nothing.Inset)
		Skin.TipFaceTree(nothing, 1)
	end
	SkinSearchPanel(list.SearchPanel)
	SkinApplicationViewer(list.ApplicationViewer)
	SkinEntryCreation(list.EntryCreation)
end

local function SkinActivityButton(button)
	if not button or button._buiActivity then return end
	button._buiActivity = true
	local selected = button.SelectedTexture
	if selected then
		AccentTexture(selected, SELECTED_ALPHA)
		selected:ClearAllPoints()
		selected:SetPoint('TOPLEFT', 1, -1)
		selected:SetPoint('BOTTOMRIGHT', -1, 1)
	end
	InsetTexture(button.HighlightTexture or button:GetHighlightTexture(), 1, 1, 1, HIGHLIGHT_ALPHA)
	FaceSize(button.Title, ACTIVITY_TITLE_SIZE)
	FaceSize(button.TeamSizeText, ACTIVITY_TITLE_SIZE)
	Face(button.LevelRequirement)
	Face(button.TeamTypeText)
	Face(button.CurrentRating)
	local reward = button.Reward
	if reward then
		SkinRoundIcon(reward)
		if reward.EnlistmentBonus then FadeRegions(reward.EnlistmentBonus) end
	end
	Shell(button)
end

local function SkinActivityButtons(holder, keys)
	if not holder or not keys then return end
	for _, key in ipairs(keys) do
		SkinActivityButton(type(key) == 'table' and key or holder[key])
	end
end

local function SkinSpecificRow(button)
	if button._buiSpecificRow then return end
	button._buiSpecificRow = true
	Fade(button.Bg)
	Fade(button.Border)
	AccentTexture(button.SelectedTexture, SELECTED_ALPHA)
	RowHighlight(button)
	CropIcon(button.Icon)
	Face(button.SizeText)
	Face(button.InfoText)
	Face(button.NameText)
end

local function SkinSpecificRows(scrollBox)
	if Enabled() then Skin.ForEachScrollFrame(scrollBox, SkinSpecificRow) end
end

local function OnHonorListUpdated()
	local honor = _G.HonorFrame
	if honor then SkinSpecificRows(honor.SpecificScrollBox) end
end

local function SkinQueuePanel(panel)
	if not panel then return end
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
	local bar = panel.ConquestBar
	if bar then
		FadeKeys(bar, CONQUEST_BAR_ART)
		Shell(bar)
		SkinRoundIcon(bar.Reward)
	end
end

local function OnPvpSelection(index)
	pvpSelectedIndex = index
	if Enabled() and pvpSkinned then RefreshPvpButtons() end
end

local function SkinPvp()
	if pvpSkinned or not Enabled() then return end
	local queue = _G.PVPQueueFrame
	if not queue then return end
	pvpSkinned = true
	FadeRegions(_G.PVPUIFrame)
	for buttonIndex = 1, PVP_CATEGORY_COUNT do SkinMenuButton(queue['CategoryButton' .. buttonIndex]) end
	RefreshPvpButtons()
	local honorInset = queue.HonorInset
	if honorInset then
		FadeArt(honorInset)
		Shell(honorInset)
		local rated = honorInset.RatedPanel
		if rated then SkinRoundIcon(rated.SeasonRewardFrame) end
		local plunder = honorInset.PlunderstormPanel
		if plunder then Button(plunder.PlunderstoreButton) end
	end
	SkinQueuePanel(_G.HonorFrame)
	SkinQueuePanel(_G.ConquestFrame)
	SkinQueuePanel(_G.TrainingGroundsFrame)
	local plunderstorm = _G.PlunderstormFrame
	if plunderstorm then
		FadeArt(plunderstorm.Inset)
		Button(plunderstorm.StartQueue)
	end
	local season = queue.NewSeasonPopup
	if season then
		FadeRegions(season)
		Shell(season)
		Button(season.Leave)
		SkinRoundIcon(season.SeasonRewardFrame)
	end
	if pvpHooked then return end
	pvpHooked = true
	if _G.HonorFrameSpecificList_Update then hooksecurefunc('HonorFrameSpecificList_Update', OnHonorListUpdated) end
	if _G.PVPQueueFrame_SelectButton then hooksecurefunc('PVPQueueFrame_SelectButton', OnPvpSelection) end
	local trainingMixin = _G.PVPSpecificTrainingGroundButtonMixin
	if trainingMixin and trainingMixin.Initialize then
		hooksecurefunc(trainingMixin, 'Initialize', function(button) if Enabled() then SkinSpecificRow(button) end end)
	end
end

local function SkinDungeonIcon(child)
	if child._buiDungeonIcon then return end
	child._buiDungeonIcon = true
	local icon = child.Icon
	for regionIndex = 1, select('#', child:GetRegions()) do
		local region = select(regionIndex, child:GetRegions())
		if region ~= icon and region.IsObjectType and region:IsObjectType('Texture') then Fade(region) end
	end
	CropIcon(icon)
	Skin.TipIconFrame(child, icon)
end

local function OnChallengesUpdated(frame)
	if not Enabled() or not frame.DungeonIcons then return end
	for _, child in ipairs(frame.DungeonIcons) do SkinDungeonIcon(child) end
end

local function KeystoneBackdropTexture(frame)
	if frame._buiKeystoneBackdrop then return frame._buiKeystoneBackdrop end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region.GetAtlas and region:GetAtlas() == KEYSTONE_SHELL_ATLAS then
			frame._buiKeystoneBackdrop = region
			return region
		end
	end
end

local function RefadeKeystoneArt(frame)
	if not Enabled() then return end
	local backdrop = KeystoneBackdropTexture(frame)
	if backdrop then backdrop:SetAlpha(0) end
	for keyIndex = 1, #KEYSTONE_ART do
		local region = frame[KEYSTONE_ART[keyIndex]]
		if region then region:SetAlpha(0) end
	end
end

local function SkinKeystoneFrame(frame)
	if not Enabled() then return end
	RefadeKeystoneArt(frame)
	Shell(frame)
	Close(frame.CloseButton)
	Button(frame.StartButton)
	FaceSize(frame.PowerLevel, KEYSTONE_HEADING_SIZE)
	FaceSize(frame.DungeonName, KEYSTONE_HEADING_SIZE)
	FaceSize(frame.TimeLimit, KEYSTONE_TEXT_SIZE)
end

local function SkinChallenges()
	if challengesSkinned or not Enabled() then return end
	local frame = _G.ChallengesFrame
	if not frame then return end
	challengesSkinned = true
	FadeRegions(frame)
	FadeArt(_G.ChallengesFrameInset)
	OnChallengesUpdated(frame)
	local notice = frame.SeasonChangeNoticeFrame
	if notice then
		FadeRegions(notice)
		Shell(notice)
		Button(notice.Leave)
	end
	local keystone = _G.ChallengesKeystoneFrame
	if keystone and keystone:IsShown() then SkinKeystoneFrame(keystone) end
	if challengesHooked then return end
	challengesHooked = true
	if frame.Update then hooksecurefunc(frame, 'Update', OnChallengesUpdated) end
	if keystone then
		HookScript(keystone, 'OnShow', SkinKeystoneFrame)
		if keystone.Reset then hooksecurefunc(keystone, 'Reset', RefadeKeystoneArt) end
	end
end

local function SkinMainFrame(frame)
	FadeRegions(frame)
	Fade(frame.NineSlice)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	FadeRegions(frame.shadows)
	FadeArt(frame.Inset)
	Shell(frame.Inset)
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	local tabs = {}
	for tabIndex = 1, BOTTOM_TAB_COUNT do tabs[tabIndex] = frame['tab' .. tabIndex] or _G['PVEFrameTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
end

local function SkinGroupButtons()
	local frame = _G.GroupFinderFrame
	if not frame then return end
	for buttonIndex = 1, GROUP_BUTTON_COUNT do SkinMenuButton(frame['groupButton' .. buttonIndex]) end
	RefreshGroupButtons()
end

local function Apply()
	local frame = _G.PVEFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMainFrame(frame)
		SkinGroupButtons()
		SkinDungeonFinder()
		SkinRaidFinder()
		SkinPremadeGroups()
	end
	RefreshGroupButtons()
	Skin.RefreshTabStrip(frame)
	local queue = _G.LFDQueueFrame
	if queue then
		SweepDungeonRows(queue.Specific)
		SweepDungeonRows(queue.Follower)
	end
	SkinPvp()
	SkinChallenges()
end

local function OnGroupSelection()
	if Enabled() and skinned then RefreshGroupButtons() end
end

local function OnAddonLoaded(first, second)
	local addonName = second or first
	if addonName == PVP_ADDON then
		SkinPvp()
	elseif addonName == CHALLENGES_ADDON then
		SkinChallenges()
	end
	if pvpSkinned and challengesSkinned then BUI.Events:Unregister('ADDON_LOADED', 'Skin.GroupFinder') end
end

local function HookRows()
	hooksecurefunc('LFGRewardsFrame_SetItemButton', OnRewardItem)
	hooksecurefunc('LFGDungeonListButton_SetDungeon', OnDungeonRow)
	hooksecurefunc('GroupFinderFrame_SelectGroupButton', OnGroupSelection)
	if _G.LFGListCategorySelection_AddButton then hooksecurefunc('LFGListCategorySelection_AddButton', OnCategoryButton) end
	if _G.LFGListSearchEntry_Update then hooksecurefunc('LFGListSearchEntry_Update', OnSearchEntry) end
	if _G.LFGListApplicationViewer_UpdateApplicant then hooksecurefunc('LFGListApplicationViewer_UpdateApplicant', OnApplicant) end
	if _G.LFGListSearchPanel_UpdateAutoComplete then hooksecurefunc('LFGListSearchPanel_UpdateAutoComplete', OnAutoComplete) end
end

local function Install()
	if installed then return end
	local frame = _G.PVEFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	HookRows()
	BUI.Events:Register('ADDON_LOADED', 'Skin.GroupFinder', OnAddonLoaded)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.GroupFinderInstall') end
end

local function Deactivate()
	context.Restore()
	skinned = false
	pvpSkinned = false
	challengesSkinned = false
	BUI.Print('Group Finder skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if installed and not (pvpSkinned and challengesSkinned) then
			BUI.Events:Register('ADDON_LOADED', 'Skin.GroupFinder', OnAddonLoaded)
			SkinPvp()
			SkinChallenges()
		end
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.GroupFinderInstall', TryInstall)
		elseif _G.PVEFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Group Finder',
	description = 'Dungeons & Raids, PvP and Mythic+ window with its side menu, queue panels and Premade Groups.',
	icon = 'Interface/LFGFrame/UI-LFG-PORTRAIT',
	test = function()
		local frame = _G.PVEFrame
		if not frame then return end
		if _G.PVEFrame_ShowLeftInset then PVEFrame_ShowLeftInset() end
		if _G.PVPUIFrame then _G.PVPUIFrame:Hide() end
		if _G.ChallengesFrame then _G.ChallengesFrame:Hide() end
		PanelTemplates_SetTab(frame, 1)
		local groupFinder = _G.GroupFinderFrame
		if groupFinder then
			groupFinder:Show()
			if _G.GroupFinderFrame_ShowGroupFrame then GroupFinderFrame_ShowGroupFrame(_G.LFDParentFrame) end
		end
		frame:Show()
		return frame
	end,
	stopTest = function()
		if _G.PVEFrame then HideUIPanel(_G.PVEFrame) end
	end,
})
