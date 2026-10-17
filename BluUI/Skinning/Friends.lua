local _, BUI = ...

local ipairs = ipairs

local BUILib = BluUI.BUILibClient
local Skin = BUI.Skinning

local BOTTOM_TAB_COUNT = 4
local WHO_COLUMN_COUNT = 4
local ROW_BASE_ALPHA = 0.04
local QUICK_JOIN_HIGHLIGHT_ALPHA = 0.14
local QUICK_JOIN_SELECTED_ALPHA = 0.3
local INVITE_BUTTON_SIZE = 24
local INVITE_ICON_INSET = 2
local GAME_ICON_SIZE = 24
local TAB_LIST_GAP = 4
local LIST_EDGE_X = 10
local LIST_BOTTOM_GAP = 8
local LIST_RIGHT_OFFSET = -28
local LIST_LEFT_OFFSET = 8
local LIST_TOP_OFFSET = 87
local DEFAULT_INVITE_ICON = 'Interface/FriendsFrame/PlusManz-PlusManz'
local INVITE_ICONS = {
	['friendslist-invitebutton-horde-normal'] = 'Interface/FriendsFrame/PlusManz-Horde',
	['friendslist-invitebutton-alliance-normal'] = 'Interface/FriendsFrame/PlusManz-Alliance',
}
local INVITE_ICON_DISABLED = { 0.45, 0.45, 0.5, 1 }
local STRETCH_BUTTON_ART = { 'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight', 'TopMiddle', 'MiddleLeft', 'MiddleRight', 'BottomMiddle', 'MiddleMiddle' }
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'Inset' }
local SUMMON_ART = { 'SlotBackground', 'SlotArt', 'NormalTexture', 'Border', 'Flash' }
local SPLASH_ART = {
	'Background', 'PictureFrame', 'Watermark',
	'Bracket_TopLeft', 'Bracket_TopRight', 'Bracket_BottomLeft', 'Bracket_BottomRight',
	'PictureFrame_Bracket_TopLeft', 'PictureFrame_Bracket_TopRight', 'PictureFrame_Bracket_BottomLeft', 'PictureFrame_Bracket_BottomRight',
}
local ROLE_BUTTON_KEYS = { 'RoleButtonTank', 'RoleButtonHealer', 'RoleButtonDPS' }

local artStale = false
local friendsWindow

local context = Skin.Define('friends', {
	name = 'Contacts',
	description = 'The Contacts window and its Who, Raid, Quick Join and Recruit A Friend tabs: flat shell, boxed tabs, clean rows and dialogs.',
	icon = 'Interface/FriendsFrame/Battlenet-Portrait',
})
local Hook = context.Hook
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Face, FaceOnce, Title = context.ScrollBar, context.Tab, context.Face, context.FaceOnce, context.Title
local FlatTexture, SelectedTexture, RowHighlight, CropIcon = Skin.FlatTexture, Skin.SelectedTexture, Skin.RowHighlight, Skin.CropIcon

local function UpdateInvitePass(button)
	local travel = button.travelPassButton
	local icon = travel._buiIcon
	local atlas = travel.NormalTexture:GetAtlas()
	icon:SetTexture(INVITE_ICONS[atlas] or DEFAULT_INVITE_ICON)
	if travel:IsEnabled() then
		icon:SetVertexColor(1, 1, 1, 1)
	else
		icon:SetVertexColor(INVITE_ICON_DISABLED[1], INVITE_ICON_DISABLED[2], INVITE_ICON_DISABLED[3], INVITE_ICON_DISABLED[4])
	end
end

local function SkinInvitePass(travel)
	travel:SetSize(INVITE_BUTTON_SIZE, INVITE_BUTTON_SIZE)
	travel:ClearAllPoints()
	travel:SetPoint('TOPRIGHT', travel:GetParent(), 'TOPRIGHT', -4, -5)
	local highlight = travel.HighlightTexture
	highlight:SetColorTexture(1, 1, 1, 0.25)
	highlight:SetAllPoints(travel)
	local icon = travel:CreateTexture(nil, 'ARTWORK')
	icon.__buiSkin = true
	icon:SetPoint('TOPLEFT', travel, 'TOPLEFT', INVITE_ICON_INSET, -INVITE_ICON_INSET)
	icon:SetPoint('BOTTOMRIGHT', travel, 'BOTTOMRIGHT', -INVITE_ICON_INSET, INVITE_ICON_INSET)
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	travel._buiIcon = icon
end

local function SkinSummon(summon)
	summon:SetSize(INVITE_BUTTON_SIZE, INVITE_BUTTON_SIZE)
	local icon = summon.icon
	CropIcon(icon)
	icon:ClearAllPoints()
	icon:SetPoint('TOPLEFT', summon, 'TOPLEFT', INVITE_ICON_INSET, -INVITE_ICON_INSET)
	icon:SetPoint('BOTTOMRIGHT', summon, 'BOTTOMRIGHT', -INVITE_ICON_INSET, INVITE_ICON_INSET)
	local highlight = summon:GetHighlightTexture()
	highlight:SetColorTexture(1, 1, 1, 0.25)
	highlight:SetAllPoints(summon)
end

local function RefreshFriendRowArt(button)
	local travel = button.travelPassButton
	Fade(travel.NormalTexture)
	Fade(travel.PushedTexture)
	Fade(travel.DisabledTexture)
	Shell(travel)
	local summon = button.summonButton
	FadeKeys(summon, SUMMON_ART)
	Shell(summon)
end

local function SkinFriendRow(button)
	if not button._buiFriendRow then
		button._buiFriendRow = true
		RowHighlight(button)
		Face(button.name)
		Face(button.info)
		local travel = button.travelPassButton
		SkinInvitePass(travel)
		SkinSummon(button.summonButton)
		local gameIcon = button.gameIcon
		gameIcon:SetSize(GAME_ICON_SIZE, GAME_ICON_SIZE)
		gameIcon:ClearAllPoints()
		gameIcon:SetPoint('RIGHT', travel, 'LEFT', -6, 0)
		RefreshFriendRowArt(button)
	end
	UpdateInvitePass(button)
end

local function RefreshInviteHeaderArt(button)
	Fade(button.BG)
	FadeKeys(button, STRETCH_BUTTON_ART)
	Shell(button, 2)
end

local function SkinInviteHeader(button)
	if button._buiInviteHeader then return end
	button._buiInviteHeader = true
	RowHighlight(button)
	Face(button:GetFontString())
	RefreshInviteHeaderArt(button)
end

local function SkinInviteRow(button)
	if not button._buiInviteRow then
		button._buiInviteRow = true
		Face(button.Name)
		local icon = button.DeclineButton.Icon
		if icon then icon.__buiSkin = true end
	end
	Button(button.DeclineButton)
	Button(button.AcceptButton)
end

local function SkinListRow(button)
	if button.gameIcon then
		SkinFriendRow(button)
		if artStale then RefreshFriendRowArt(button) end
	elseif button.DownArrow then
		SkinInviteHeader(button)
		if artStale then RefreshInviteHeaderArt(button) end
	elseif button.AcceptButton then
		SkinInviteRow(button)
	end
end

local function SkinWhoRow(button)
	if button._buiWhoRow then return end
	button._buiWhoRow = true
	RowHighlight(button)
	for _, fontString in ipairs(button.FontStrings) do Face(fontString) end
end

local function SkinIgnoreRow(button)
	if button._buiIgnoreRow then return end
	button._buiIgnoreRow = true
	RowHighlight(button)
	Face(button.name)
end

local function SkinQuickJoinRow(button)
	if not button._buiQuickJoinRow then
		button._buiQuickJoinRow = true
		SelectedTexture(button.Highlight, QUICK_JOIN_HIGHLIGHT_ALPHA)
		SelectedTexture(button.Selected, QUICK_JOIN_SELECTED_ALPHA)
	end
	Fade(button.Background)
	for _, member in ipairs(button.Members) do FaceOnce(member) end
	for _, queue in ipairs(button.Queues) do FaceOnce(queue) end
end

local function SkinRecentAllyRow(button)
	if button._buiRecentAllyRow then return end
	button._buiRecentAllyRow = true
	RowHighlight(button)
	FlatTexture(button.NormalTexture, 1, 1, 1, ROW_BASE_ALPHA)
	Skin.TipFaceTree(button.CharacterData, 1)
end

local function SkinFriendsFriendsRow(button)
	if button._buiFriendsFriendsRow then return end
	button._buiFriendsFriendsRow = true
	RowHighlight(button)
	Face(button.Name)
end

local function FaceRaidInfoRow(row)
	if row._buiRaidRow then return end
	row._buiRaidRow = true
	Skin.TipFaceTree(row, 1)
end

local function SkinRaidInfoRows(info)
	Skin.ForEachScrollFrame(info.ScrollBox, FaceRaidInfoRow)
end

local function FitHeaderTab(tab)
	if tab._buiWidthFitted then return false end
	tab._buiWidthFitted = true
	tab.Text:SetWidth(0)
	tab:UpdateTabWidth()
	return true
end

local function RefreshHeaderTabs()
	local tabSystem = _G.FriendsTabHeader.TabSystem
	local resized = false
	for _, tab in ipairs(tabSystem.tabs) do
		Tab(tab)
		Skin.TipTabSelected(tab, tab.isSelected == true)
		if FitHeaderTab(tab) then resized = true end
	end
	if resized then tabSystem:MarkDirty() end
end

local function SkinMainFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	Fade(frame.PortraitContainer.portrait)
	Fade(_G.FriendsFrameIcon)
	Shell(frame)
	Title(frame.TitleContainer.TitleText)
	Title(_G.FriendsFrameTitleText)
	Close(frame.CloseButton)
	local tabs = {}
	for tabIndex = 1, BOTTOM_TAB_COUNT do tabs[tabIndex] = _G['FriendsFrameTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
end

local function SkinBattlenet(battlenet)
	FadeRegions(battlenet)
	Shell(battlenet)
	Face(battlenet.Tag)
	Face(battlenet.UnavailableLabel)
	local rowHeight = Skin.DropdownHeight()
	if not battlenet._buiRowHeight then
		battlenet._buiRowHeight = true
		battlenet:SetHeight(rowHeight)
	end
	local menu = battlenet.ContactsMenuButton
	if not menu._buiTipArrow then
		BUILib.Skin.StripButton(menu)
		menu:SetSize(rowHeight, rowHeight)
	end
	Shell(menu)
	Skin.TipArrow(menu, true)
	local unavailable = battlenet.UnavailableInfoFrame
	FadeKeys(unavailable, Skin.PANEL_ART)
	Shell(unavailable)
	Title(unavailable.Label)
	Face(unavailable.Text)
	local broadcast = battlenet.BroadcastFrame
	FadeArt(broadcast.Border)
	Shell(broadcast)
	Skin.TipFaceTree(broadcast, 1)
	EditBox(broadcast.EditBox)
	Face(broadcast.EditBox.PromptText)
	Button(broadcast.UpdateButton)
	Button(broadcast.CancelButton)
end

local function PadListTop(frames)
	local set = {}
	for frameIndex = 1, #frames do set[frames[frameIndex]] = true end
	for frame in pairs(set) do Skin.PadVertical(frame, TAB_LIST_GAP, 0, set) end
end

local function LayoutFriendsList(list)
	if list._buiLayout then return end
	list._buiLayout = true
	local frame, box = _G.FriendsFrame, list.ScrollBox
	local addFriend, sendMessage = _G.FriendsFrameAddFriendButton, _G.FriendsFrameSendMessageButton
	local boxRight, frameRight = box:GetRight(), frame:GetRight()
	local rightOffset = (boxRight and frameRight) and (boxRight - frameRight) or LIST_RIGHT_OFFSET
	local buttonHeight = addFriend:GetHeight()
	local addWidth, sendWidth = addFriend:GetWidth(), sendMessage:GetWidth()
	addFriend:ClearAllPoints()
	addFriend:SetSize(addWidth, buttonHeight)
	addFriend:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', LIST_EDGE_X, LIST_BOTTOM_GAP)
	sendMessage:ClearAllPoints()
	sendMessage:SetSize(sendWidth, buttonHeight)
	sendMessage:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -LIST_EDGE_X, LIST_BOTTOM_GAP)
	local topPoint
	for pointIndex = 1, box:GetNumPoints() do
		local point, relativeTo, relativePoint, offsetX, offsetY = box:GetPoint(pointIndex)
		if point:sub(1, 3) == 'TOP' then topPoint = { point, relativeTo, relativePoint, offsetX, offsetY } end
	end
	box:ClearAllPoints()
	if topPoint then
		box:SetPoint(topPoint[1], topPoint[2], topPoint[3], topPoint[4], topPoint[5] - TAB_LIST_GAP)
	else
		box:SetPoint('TOPLEFT', frame, 'TOPLEFT', LIST_LEFT_OFFSET, -LIST_TOP_OFFSET - TAB_LIST_GAP)
	end
	box:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', rightOffset, LIST_BOTTOM_GAP * 2 + buttonHeight)
end

local function SkinFriendsList(list)
	Face(list.FriendsDisabledText)
	ScrollBar(list.ScrollBar)
	Button(_G.FriendsFrameAddFriendButton)
	Button(_G.FriendsFrameSendMessageButton)
	LayoutFriendsList(list)
end

local function SkinIgnoreWindow(window)
	FadeArt(window)
	Shell(window)
	Title(window.TitleContainer.TitleText)
	Close(window.CloseButton)
	Button(window.UnignorePlayerButton)
	ScrollBar(window.ScrollBar)
end

local function SkinWho(who)
	FadeRegions(who)
	FadeArt(_G.WhoFrameListInset)
	Face(_G.WhoFrameTotals)
	EditBox(_G.WhoFrameEditBox)
	for columnIndex = 1, WHO_COLUMN_COUNT do
		local header = _G['WhoFrameColumnHeader' .. columnIndex]
		FadeRegions(header)
		Face(header:GetFontString())
	end
	Dropdown(_G.WhoFrameDropdown)
	Button(_G.WhoFrameWhoButton)
	Button(_G.WhoFrameAddFriendButton)
	Button(_G.WhoFrameGroupInviteButton)
	ScrollBar(who.ScrollBar)
end

local function SkinRecentAllies(recent)
	local list = recent.List
	ScrollBar(list.ScrollBar)
	PadListTop({ list.ScrollBox, list.ScrollBar })
end

local function SkinQuickJoin(quickJoin)
	Button(quickJoin.JoinQueueButton)
	ScrollBar(quickJoin.ScrollBar)
end

local function SkinRoleSelection(frame)
	FadeArt(frame)
	Shell(frame)
	Button(frame.AcceptButton)
	Button(frame.CancelButton)
	Close(frame.CloseButton)
	for keyIndex = 1, #ROLE_BUTTON_KEYS do CheckBox(frame[ROLE_BUTTON_KEYS[keyIndex]].CheckButton) end
	Skin.TipFaceTree(frame, 1)
end

local function SkinRaidTab()
	local raid = _G.RaidFrame
	Skin.TipBackdropButton(_G.RaidFrameConvertToRaidButton)
	Skin.TipBackdropButton(_G.RaidFrameRaidInfoButton)
	Face(_G.RaidFrameAllAssistCheckButton.Text)
	Skin.TipFaceTree(raid.RoleCount, 2)
	ScrollBar(raid.RaidFrameNotInRaid.ScrollingDescriptionScrollBar, true)
	local info = _G.RaidInfoFrame
	Fade(_G.RaidInfoDetailHeader)
	Fade(_G.RaidInfoDetailFooter)
	FadeArt(info.Border)
	FadeRegions(info.Header)
	Title(info.Header.Text)
	local instanceLabel, idLabel = _G.RaidInfoInstanceLabel, _G.RaidInfoIDLabel
	FadeRegions(instanceLabel)
	Face(instanceLabel.text)
	FadeRegions(idLabel)
	Face(idLabel.text)
	if not info._buiBackdrop then
		info._buiBackdrop = true
		BUI.Painter.Custom(info, Skin.PaintPanelBackdrop)
	end
	Close(_G.RaidInfoCloseButton)
	ScrollBar(info.ScrollBar, true)
	Skin.TipBackdropButton(_G.RaidInfoExtendButton)
	Skin.TipBackdropButton(_G.RaidInfoCancelButton)
	SkinRaidInfoRows(info)
end

local function SkinRewards(rewards)
	for tab in rewards.rewardTabPool:EnumerateActive() do
		Fade(tab.Tab)
		Shell(tab, 2)
	end
	for reward in rewards.rewardPool:EnumerateActive() do
		local button = reward.Button
		Fade(button.IconOverlay)
		CropIcon(button.Icon)
		Skin.TipFaceTree(reward.Months, 1)
	end
end

local function SkinRecruit()
	local raf = _G.RecruitAFriendFrame
	local list = raf.RecruitList
	Button(list.RecruitmentButton)
	FadeRegions(list.Header)
	Skin.TipFaceTree(list.Header, 1)
	FadeArt(list.ScrollFrameInset)
	Shell(list.ScrollFrameInset)
	ScrollBar(list.ScrollBar)
	PadListTop({ list.Header, list.ScrollFrameInset, list.ScrollBox, list.ScrollBar })
	local claiming = raf.RewardClaiming
	FadeRegions(claiming)
	FadeArt(claiming.Inset)
	Shell(claiming)
	Skin.TipFaceTree(claiming, 1)
	Button(claiming.ClaimOrViewRewardButton)
	local nextReward = claiming.NextRewardButton
	CropIcon(nextReward.Icon)
	nextReward.CircleMask:Hide()
	Fade(nextReward.IconBorder)
	Fade(nextReward.IconOverlay)
	local splash = raf.SplashFrame
	FadeKeys(splash, SPLASH_ART)
	Shell(splash)
	Button(splash.OKButton)
	local recruitment = _G.RecruitAFriendRecruitmentFrame
	FadeRegions(recruitment)
	FadeArt(recruitment.Border)
	Shell(recruitment)
	Skin.TipFaceTree(recruitment, 1)
	Close(recruitment.CloseButton)
	Button(recruitment.GenerateOrCopyLinkButton)
	EditBox(recruitment.EditBox)
	local rewards = _G.RecruitAFriendRewardsFrame
	FadeRegions(rewards)
	FadeArt(rewards.Border)
	Shell(rewards)
	Skin.TipFaceTree(rewards, 2)
	Close(rewards.CloseButton)
	Button(rewards.ClaimLegacyRewardsButton)
	SkinRewards(rewards)
end

local function SkinAddFriend(frame)
	FadeRegions(frame)
	FadeArt(frame.Border)
	Shell(frame)
	Close(frame.CloseButton)
	Button(frame.InfoFrame.OkayButton)
	local entry = frame.EntryFrame
	EditBox(entry.NameEditBox)
	Button(entry.AcceptButton)
	Button(entry.CancelButton)
	Skin.TipFaceTree(frame, 5)
end

local function SkinBattleNetInvite(frame)
	FadeRegions(frame)
	FadeArt(frame.Border)
	Shell(frame)
	Button(frame.SendButton)
	Button(frame.CancelButton)
	Skin.TipFaceTree(frame, 2)
end

local function SkinFriendsFriends(frame)
	FadeRegions(frame)
	FadeArt(frame.Border)
	FadeArt(frame.ScrollFrameBorder)
	Shell(frame)
	Title(frame.Title)
	Dropdown(frame.FriendsDropdown)
	Button(frame.SendRequestButton)
	Button(frame.CloseButton)
	ScrollBar(frame.ScrollBar)
	Skin.TipFaceTree(frame.WaitFrame, 1)
end

local function SweepFriendsFriends(frame)
	Skin.ForEachScrollFrame(frame.ScrollBox, SkinFriendsFriendsRow)
end

local function ForEachRow(host, callback)
	Skin.ForEachScrollFrame(host.ScrollBox, callback)
end

local function SweepLists()
	ForEachRow(_G.FriendsListFrame, SkinListRow)
	ForEachRow(_G.WhoFrame, SkinWhoRow)
	ForEachRow(_G.FriendsFrame.IgnoreListWindow, SkinIgnoreRow)
	ForEachRow(_G.QuickJoinFrame, SkinQuickJoinRow)
	ForEachRow(_G.RecentAlliesFrame.List, SkinRecentAllyRow)
end

local function SkinFriends(frame)
	SkinMainFrame(frame)
	SkinBattlenet(_G.FriendsFrameBattlenetFrame)
	Dropdown(_G.FriendsFrameStatusDropdown)
	SkinFriendsList(_G.FriendsListFrame)
	SkinIgnoreWindow(frame.IgnoreListWindow)
	SkinWho(_G.WhoFrame)
	SkinRecentAllies(_G.RecentAlliesFrame)
	SkinQuickJoin(_G.QuickJoinFrame)
	SkinRaidTab()
	SkinRecruit()
end

local function RefreshFriends(frame)
	RefreshHeaderTabs()
	Skin.RefreshTabStrip(frame)
	SweepLists()
	artStale = false
end

local function OnFriendsUpdated()
	if not friendsWindow.skinned then return end
	RefreshHeaderTabs()
	SweepLists()
end

local function OnRaidInfoUpdated()
	if friendsWindow.skinned then SkinRaidInfoRows(_G.RaidInfoFrame) end
end

local function InstallFriends()
	Hook('FriendsFrame_Update', OnFriendsUpdated)
	Hook('FriendsFrame_UpdateFriendButton', SkinFriendRow)
	Hook('FriendsFrame_UpdateFriendInviteButton', SkinInviteRow)
	Hook('FriendsFrame_UpdateFriendInviteHeaderButton', SkinInviteHeader)
	Hook('WhoList_InitButton', SkinWhoRow)
	Hook('IgnoreList_InitButton', SkinIgnoreRow)
	Hook('RaidInfoFrame_Update', OnRaidInfoUpdated)
	Hook(_G.QuickJoinButtonMixin, 'Init', SkinQuickJoinRow)
	Hook(_G.RecentAlliesEntryMixin, 'Initialize', SkinRecentAllyRow)
	Hook(_G.FriendsFriendsButtonMixin, 'Init', SkinFriendsFriendsRow)
	Hook(_G.RecruitAFriendRewardsFrame, 'UpdateRewards', SkinRewards)
end

friendsWindow = { skin = SkinFriends, show = RefreshFriends, install = InstallFriends }
context.Window('FriendsFrame', friendsWindow)
context.Window('AddFriendFrame', { skin = SkinAddFriend })
context.Window('BattleNetInviteFrame', { skin = SkinBattleNetInvite })
context.Window('FriendsFriendsFrame', { skin = SkinFriendsFriends, show = SweepFriendsFriends })
context.Window('QuickJoinRoleSelectionFrame', { skin = SkinRoleSelection })

context.OnDisable(function() artStale = true end)
