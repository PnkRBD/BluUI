local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('Friends')

local hooksecurefunc = BUI.Prof.MakeHooker('friends')
local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme

local SKIN_ID = 'friends'
local BOTTOM_TAB_COUNT = 4
local WHO_COLUMN_COUNT = 4
local ROW_BASE_ALPHA = 0.04
local QUICK_JOIN_HIGHLIGHT_ALPHA = 0.5
local QUICK_JOIN_SELECTED_ALPHA = 0.6
local INVITE_BUTTON_SIZE = 24
local INVITE_ICON_INSET = 2
local GAME_ICON_SIZE = 24
local TAB_LIST_GAP = 4
local LIST_EDGE_X = 10
local LIST_BOTTOM_GAP = 8
local LIST_RIGHT_OFFSET = -28
local LIST_LEFT_OFFSET = 8
local LIST_TOP_OFFSET = 87
local CLOSE_GLYPH_SIZE = 12
local DEFAULT_INVITE_ICON = 'Interface/FriendsFrame/PlusManz-PlusManz'
local INVITE_ICONS = {
	['friendslist-invitebutton-horde-normal'] = 'Interface/FriendsFrame/PlusManz-Horde',
	['friendslist-invitebutton-alliance-normal'] = 'Interface/FriendsFrame/PlusManz-Alliance',
}
local INVITE_ICON_DISABLED = { 0.45, 0.45, 0.5, 1 }
local CLOSE_IDLE = { 0.75, 0.75, 0.8, 1 }
local CLOSE_DISABLED = { 0.4, 0.4, 0.45, 1 }
local STATE_TEXTURE_GETTERS = { 'GetNormalTexture', 'GetPushedTexture', 'GetDisabledTexture', 'GetHighlightTexture' }
local STRETCH_BUTTON_ART = { 'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight', 'TopMiddle', 'MiddleLeft', 'MiddleRight', 'BottomMiddle', 'MiddleMiddle' }
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'Inset' }
local SUMMON_ART = { 'SlotBackground', 'SlotArt', 'NormalTexture', 'Border', 'Flash' }
local SPLASH_ART = {
	'Background', 'PictureFrame', 'Watermark',
	'Bracket_TopLeft', 'Bracket_TopRight', 'Bracket_BottomLeft', 'Bracket_BottomRight',
	'PictureFrame_Bracket_TopLeft', 'PictureFrame_Bracket_TopRight', 'PictureFrame_Bracket_BottomLeft', 'PictureFrame_Bracket_BottomRight',
}
local ROLE_BUTTON_KEYS = { 'RoleButtonTank', 'RoleButtonHealer', 'RoleButtonDPS' }

local installed = false
local skinned = false
local artStale = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Face, FaceOnce, Title = context.ScrollBar, context.Tab, context.Face, context.FaceOnce, context.Title
local FlatTexture, AccentTexture, RowHighlight, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.RowHighlight, Skin.CropIcon

local function UpdateInvitePass(button)
	local travel = button.travelPassButton
	local icon = travel and travel._buiIcon
	if not icon then return end
	local atlas = travel.NormalTexture and travel.NormalTexture:GetAtlas()
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
	if highlight then
		highlight:SetColorTexture(1, 1, 1, 0.25)
		highlight:SetAllPoints(travel)
	end
	local icon = travel:CreateTexture(nil, 'ARTWORK')
	icon.__buiSkin = true
	icon:SetPoint('TOPLEFT', travel, 'TOPLEFT', INVITE_ICON_INSET, -INVITE_ICON_INSET)
	icon:SetPoint('BOTTOMRIGHT', travel, 'BOTTOMRIGHT', -INVITE_ICON_INSET, INVITE_ICON_INSET)
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	travel._buiIcon = icon
end

local function SkinSummon(summon)
	summon:SetSize(INVITE_BUTTON_SIZE, INVITE_BUTTON_SIZE)
	local icon = summon.icon or summon.Icon
	if icon then
		CropIcon(icon)
		icon:ClearAllPoints()
		icon:SetPoint('TOPLEFT', summon, 'TOPLEFT', INVITE_ICON_INSET, -INVITE_ICON_INSET)
		icon:SetPoint('BOTTOMRIGHT', summon, 'BOTTOMRIGHT', -INVITE_ICON_INSET, INVITE_ICON_INSET)
	end
	local highlight = summon.GetHighlightTexture and summon:GetHighlightTexture()
	if highlight then
		highlight:SetColorTexture(1, 1, 1, 0.25)
		highlight:SetAllPoints(summon)
	end
end

local function RefreshFriendRowArt(button)
	local travel = button.travelPassButton
	if travel then
		Fade(travel.NormalTexture)
		Fade(travel.PushedTexture)
		Fade(travel.DisabledTexture)
		Shell(travel)
	end
	local summon = button.summonButton
	if summon then
		FadeKeys(summon, SUMMON_ART)
		Shell(summon)
	end
end

local function SkinFriendRow(button)
	if not button._buiFriendRow then
		button._buiFriendRow = true
		RowHighlight(button)
		Face(button.name)
		Face(button.info)
		local travel = button.travelPassButton
		if travel then SkinInvitePass(travel) end
		if button.summonButton then SkinSummon(button.summonButton) end
		local gameIcon = button.gameIcon
		if gameIcon and travel then
			gameIcon:SetSize(GAME_ICON_SIZE, GAME_ICON_SIZE)
			gameIcon:ClearAllPoints()
			gameIcon:SetPoint('RIGHT', travel, 'LEFT', -6, 0)
		end
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
	Face(button.GetFontString and button:GetFontString())
	RefreshInviteHeaderArt(button)
end

local function SkinInviteRow(button)
	if not button._buiInviteRow then
		button._buiInviteRow = true
		Face(button.Name)
		local decline = button.DeclineButton
		if decline and decline.Icon then decline.Icon.__buiSkin = true end
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
	local fontStrings = button.FontStrings
	if not fontStrings then return end
	for stringIndex = 1, #fontStrings do Face(fontStrings[stringIndex]) end
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
		AccentTexture(button.Highlight, QUICK_JOIN_HIGHLIGHT_ALPHA)
		AccentTexture(button.Selected, QUICK_JOIN_SELECTED_ALPHA)
	end
	Fade(button.Background)
	local members, queues = button.Members, button.Queues
	if members then
		for memberIndex = 1, #members do FaceOnce(members[memberIndex]) end
	end
	if queues then
		for queueIndex = 1, #queues do FaceOnce(queues[queueIndex]) end
	end
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
	local box = info and info.ScrollBox
	Skin.ForEachScrollFrame(box, FaceRaidInfoRow)
end

local function SafeClose(close)
	if not close or close._buiSafeClose then return end
	close._buiSafeClose = true
	local glyph = BUILib.GetLibMedia('x')
	close:SetNormalTexture(glyph)
	close:SetPushedTexture(glyph)
	close:SetDisabledTexture(glyph)
	close:SetHighlightTexture(glyph)
	for getterIndex = 1, #STATE_TEXTURE_GETTERS do
		local texture = close[STATE_TEXTURE_GETTERS[getterIndex]](close)
		if texture then
			texture:ClearAllPoints()
			texture:SetPoint('CENTER', close, 'CENTER', 0, 0)
			texture:SetSize(CLOSE_GLYPH_SIZE, CLOSE_GLYPH_SIZE)
			texture:SetBlendMode('BLEND')
		end
	end
	local red, green, blue = Theme.GetAccent()
	close:GetNormalTexture():SetVertexColor(CLOSE_IDLE[1], CLOSE_IDLE[2], CLOSE_IDLE[3], CLOSE_IDLE[4])
	close:GetPushedTexture():SetVertexColor(1, 1, 1, 1)
	close:GetDisabledTexture():SetVertexColor(CLOSE_DISABLED[1], CLOSE_DISABLED[2], CLOSE_DISABLED[3], CLOSE_DISABLED[4])
	close:GetHighlightTexture():SetVertexColor(red, green, blue, 1)
end

local function HeaderTabs()
	local header = _G.FriendsTabHeader
	local tabSystem = header and header.TabSystem
	if not tabSystem then return nil end
	if tabSystem.tabs then return tabSystem.tabs, tabSystem end
	local tabs = {}
	for _, child in ipairs({ tabSystem:GetChildren() }) do
		if child.IsObjectType and child:IsObjectType('Button') then tabs[#tabs + 1] = child end
	end
	return tabs, tabSystem
end

local function FitHeaderTab(tab)
	if tab._buiWidthFitted or not (tab.UpdateTabWidth and tab.Text) then return false end
	tab._buiWidthFitted = true
	tab.Text:SetWidth(0)
	tab:UpdateTabWidth()
	return true
end

local function RefreshHeaderTabs()
	local tabs, tabSystem = HeaderTabs()
	if not tabs then return end
	local resized = false
	for _, tab in ipairs(tabs) do
		Tab(tab)
		Skin.TipTabSelected(tab, tab.isSelected == true)
		if FitHeaderTab(tab) then resized = true end
	end
	if resized and tabSystem.MarkDirty then tabSystem:MarkDirty() end
end

local function SkinMainFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Fade(_G.FriendsFrameIcon)
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Title(_G.FriendsFrameTitleText)
	Close(frame.CloseButton)
	local tabs = {}
	for tabIndex = 1, BOTTOM_TAB_COUNT do tabs[tabIndex] = _G['FriendsFrameTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
end

local function SkinBattlenet(battlenet)
	if not battlenet then return end
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
	if menu then
		if not menu._buiTipArrow then
			BUILib.Skin.StripButton(menu)
			menu:SetSize(rowHeight, rowHeight)
		end
		Shell(menu)
		Skin.TipArrow(menu, true)
	end
	local unavailable = battlenet.UnavailableInfoFrame
	if unavailable then
		FadeKeys(unavailable, Skin.PANEL_ART)
		Shell(unavailable)
		Title(unavailable.Label)
		Face(unavailable.Text)
	end
	local broadcast = battlenet.BroadcastFrame
	if broadcast then
		FadeArt(broadcast.Border)
		Shell(broadcast)
		Skin.TipFaceTree(broadcast, 1)
		EditBox(broadcast.EditBox)
		Face(broadcast.EditBox and broadcast.EditBox.PromptText)
		Button(broadcast.UpdateButton)
		Button(broadcast.CancelButton)
	end
end

local function PadListTop(frames)
	local set = {}
	for frameIndex = 1, #frames do
		if frames[frameIndex] then set[frames[frameIndex]] = true end
	end
	for frame in pairs(set) do Skin.PadVertical(frame, TAB_LIST_GAP, 0, set) end
end

local function LayoutFriendsList(list)
	local frame, box = _G.FriendsFrame, list.ScrollBox
	local addFriend, sendMessage = _G.FriendsFrameAddFriendButton, _G.FriendsFrameSendMessageButton
	if list._buiLayout or not (frame and box and addFriend and sendMessage) then return end
	list._buiLayout = true
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
		if point and point:sub(1, 3) == 'TOP' then topPoint = { point, relativeTo, relativePoint, offsetX or 0, offsetY or 0 } end
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
	if not list then return end
	Face(list.FriendsDisabledText)
	ScrollBar(list.ScrollBar)
	Button(_G.FriendsFrameAddFriendButton)
	Button(_G.FriendsFrameSendMessageButton)
	LayoutFriendsList(list)
end

local function SkinIgnoreWindow(window)
	if not window then return end
	FadeArt(window)
	Shell(window)
	Title(window.TitleContainer and window.TitleContainer.TitleText)
	Close(window.CloseButton)
	Button(window.UnignorePlayerButton)
	ScrollBar(window.ScrollBar)
end

local function SkinWho(who)
	if not who then return end
	FadeRegions(who)
	FadeArt(_G.WhoFrameListInset)
	Face(_G.WhoFrameTotals)
	EditBox(_G.WhoFrameEditBox)
	for columnIndex = 1, WHO_COLUMN_COUNT do
		local header = _G['WhoFrameColumnHeader' .. columnIndex]
		if header then
			FadeRegions(header)
			Face(header.GetFontString and header:GetFontString())
		end
	end
	Dropdown(_G.WhoFrameDropdown)
	Button(_G.WhoFrameWhoButton)
	Button(_G.WhoFrameAddFriendButton)
	Button(_G.WhoFrameGroupInviteButton)
	ScrollBar(who.ScrollBar)
end

local function SkinRecentAllies(recent)
	local list = recent and recent.List
	if not list then return end
	ScrollBar(list.ScrollBar)
	PadListTop({ list.ScrollBox, list.ScrollBar })
end

local function SkinQuickJoin(quickJoin)
	if not quickJoin then return end
	Button(quickJoin.JoinQueueButton)
	ScrollBar(quickJoin.ScrollBar)
end

local function SkinRoleSelection(frame)
	if not frame or not Enabled() then return end
	FadeArt(frame)
	Shell(frame)
	Button(frame.AcceptButton)
	Button(frame.CancelButton)
	Close(frame.CloseButton)
	for keyIndex = 1, #ROLE_BUTTON_KEYS do
		local role = frame[ROLE_BUTTON_KEYS[keyIndex]]
		CheckBox(role and role.CheckButton)
	end
	Skin.TipFaceTree(frame, 1)
end

local function SkinRaidTab()
	local raid = _G.RaidFrame
	if not raid then return end
	Skin.TipBackdropButton(_G.RaidFrameConvertToRaidButton)
	Skin.TipBackdropButton(_G.RaidFrameRaidInfoButton)
	local assist = _G.RaidFrameAllAssistCheckButton
	if assist then Face(assist.Text) end
	Skin.TipFaceTree(raid.RoleCount, 2)
	local notInRaid = raid.RaidFrameNotInRaid
	if notInRaid then ScrollBar(notInRaid.ScrollingDescriptionScrollBar, true) end
	local info = _G.RaidInfoFrame
	if not info then return end
	Fade(_G.RaidInfoDetailHeader)
	Fade(_G.RaidInfoDetailFooter)
	FadeArt(info.Border)
	FadeRegions(info.Header)
	Title(info.Header and info.Header.Text)
	local instanceLabel, idLabel = _G.RaidInfoInstanceLabel, _G.RaidInfoIDLabel
	FadeRegions(instanceLabel)
	Face(instanceLabel and instanceLabel.text)
	FadeRegions(idLabel)
	Face(idLabel and idLabel.text)
	if not info._buiBackdrop then
		info._buiBackdrop = true
		Skin.ApplyBackdrop(info, Skin.PANEL_FILL, Skin.PANEL_EDGE)
	end
	SafeClose(_G.RaidInfoCloseButton)
	ScrollBar(info.ScrollBar, true)
	Skin.TipBackdropButton(_G.RaidInfoExtendButton)
	Skin.TipBackdropButton(_G.RaidInfoCancelButton)
	SkinRaidInfoRows(info)
end

local function SkinRewards(rewards)
	if not Enabled() then return end
	if rewards.rewardTabPool then
		for tab in rewards.rewardTabPool:EnumerateActive() do
			Fade(tab.Tab)
			Shell(tab, 2)
		end
	end
	if rewards.rewardPool then
		for reward in rewards.rewardPool:EnumerateActive() do
			local button = reward.Button
			if button then
				Fade(button.IconOverlay)
				CropIcon(button.Icon)
			end
			Skin.TipFaceTree(reward.Months, 1)
		end
	end
end

local function SkinRecruit()
	local raf = _G.RecruitAFriendFrame
	if not raf then return end
	local list = raf.RecruitList
	if list then
		Button(list.RecruitmentButton)
		FadeRegions(list.Header)
		Skin.TipFaceTree(list.Header, 1)
		FadeArt(list.ScrollFrameInset)
		Shell(list.ScrollFrameInset)
		ScrollBar(list.ScrollBar)
		PadListTop({ list.Header, list.ScrollFrameInset, list.ScrollBox, list.ScrollBar })
	end
	local claiming = raf.RewardClaiming
	if claiming then
		FadeRegions(claiming)
		FadeArt(claiming.Inset)
		Shell(claiming)
		Skin.TipFaceTree(claiming, 1)
		Button(claiming.ClaimOrViewRewardButton)
		local nextReward = claiming.NextRewardButton
		if nextReward then
			CropIcon(nextReward.Icon)
			if nextReward.CircleMask then nextReward.CircleMask:Hide() end
			Fade(nextReward.IconBorder)
			Fade(nextReward.IconOverlay)
		end
	end
	local splash = raf.SplashFrame
	if splash then
		FadeKeys(splash, SPLASH_ART)
		Shell(splash)
		Button(splash.OKButton)
	end
	local recruitment = _G.RecruitAFriendRecruitmentFrame
	if recruitment then
		FadeRegions(recruitment)
		FadeArt(recruitment.Border)
		Shell(recruitment)
		Skin.TipFaceTree(recruitment, 1)
		Close(recruitment.CloseButton)
		Button(recruitment.GenerateOrCopyLinkButton)
		EditBox(recruitment.EditBox)
	end
	local rewards = _G.RecruitAFriendRewardsFrame
	if rewards then
		FadeRegions(rewards)
		FadeArt(rewards.Border)
		Shell(rewards)
		Skin.TipFaceTree(rewards, 2)
		Close(rewards.CloseButton)
		Button(rewards.ClaimLegacyRewardsButton)
		if not rewards._buiRewardsHook and rewards.UpdateRewards then
			rewards._buiRewardsHook = true
			hooksecurefunc(rewards, 'UpdateRewards', SkinRewards)
		end
		SkinRewards(rewards)
	end
end

local function SkinAddFriend(frame)
	if not frame or not Enabled() then return end
	FadeRegions(frame)
	FadeArt(frame.Border)
	Shell(frame)
	Close(frame.CloseButton)
	local info = frame.InfoFrame
	if info then Button(info.OkayButton) end
	local entry = frame.EntryFrame
	if entry then
		EditBox(entry.NameEditBox)
		Button(entry.AcceptButton)
		Button(entry.CancelButton)
	end
	Skin.TipFaceTree(frame, 5)
end

local function SkinBattleNetInvite(frame)
	if not frame or not Enabled() then return end
	FadeRegions(frame)
	FadeArt(frame.Border)
	Shell(frame)
	Button(frame.SendButton)
	Button(frame.CancelButton)
	Skin.TipFaceTree(frame, 2)
end

local function SkinFriendsFriends(frame)
	if not frame or not Enabled() then return end
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
	local box = frame.ScrollBox
	Skin.ForEachScrollFrame(box, SkinFriendsFriendsRow)
end

local function ForEachRow(host, callback)
	local box = host and host.ScrollBox
	Skin.ForEachScrollFrame(box, callback)
end

local function SweepLists()
	local frame = _G.FriendsFrame
	ForEachRow(_G.FriendsListFrame, SkinListRow)
	ForEachRow(_G.WhoFrame, SkinWhoRow)
	ForEachRow(frame and frame.IgnoreListWindow, SkinIgnoreRow)
	ForEachRow(_G.QuickJoinFrame, SkinQuickJoinRow)
	ForEachRow(_G.RecentAlliesFrame and _G.RecentAlliesFrame.List, SkinRecentAllyRow)
end

local function Apply()
	local frame = _G.FriendsFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
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
	RefreshHeaderTabs()
	Skin.RefreshTabStrip(frame)
	SweepLists()
	artStale = false
end

local function OnFriendsUpdated()
	if not Enabled() or not skinned then return end
	RefreshHeaderTabs()
	SweepLists()
end

local function OnRaidInfoUpdated()
	if Enabled() and skinned then SkinRaidInfoRows(_G.RaidInfoFrame) end
end

local function RowHook(callback)
	return function(button)
		if Enabled() then callback(button) end
	end
end

local function HookRows()
	hooksecurefunc('FriendsFrame_UpdateFriendButton', RowHook(SkinFriendRow))
	hooksecurefunc('FriendsFrame_UpdateFriendInviteButton', RowHook(SkinInviteRow))
	hooksecurefunc('FriendsFrame_UpdateFriendInviteHeaderButton', RowHook(SkinInviteHeader))
	if _G.WhoList_InitButton then hooksecurefunc('WhoList_InitButton', RowHook(SkinWhoRow)) end
	if _G.IgnoreList_InitButton then hooksecurefunc('IgnoreList_InitButton', RowHook(SkinIgnoreRow)) end
	if _G.RaidInfoFrame_Update then hooksecurefunc('RaidInfoFrame_Update', OnRaidInfoUpdated) end
	local quickJoinMixin = _G.QuickJoinButtonMixin
	if quickJoinMixin and quickJoinMixin.Init then hooksecurefunc(quickJoinMixin, 'Init', RowHook(SkinQuickJoinRow)) end
	local recentAllyMixin = _G.RecentAlliesEntryMixin
	if recentAllyMixin and recentAllyMixin.Initialize then hooksecurefunc(recentAllyMixin, 'Initialize', RowHook(SkinRecentAllyRow)) end
	local friendsFriendsMixin = _G.FriendsFriendsButtonMixin
	if friendsFriendsMixin and friendsFriendsMixin.Init then hooksecurefunc(friendsFriendsMixin, 'Init', RowHook(SkinFriendsFriendsRow)) end
end

local function HookDialog(frame, callback)
	if frame then HookScript(frame, 'OnShow', callback) end
end

local function HookDialogs()
	HookDialog(_G.AddFriendFrame, SkinAddFriend)
	HookDialog(_G.BattleNetInviteFrame, SkinBattleNetInvite)
	HookDialog(_G.FriendsFriendsFrame, SkinFriendsFriends)
	HookDialog(_G.QuickJoinRoleSelectionFrame, SkinRoleSelection)
end

local function Install()
	if installed then return end
	local frame = _G.FriendsFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	hooksecurefunc('FriendsFrame_Update', OnFriendsUpdated)
	HookRows()
	HookDialogs()
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Friends') end
end

local function Deactivate()
	context.Restore()
	skinned = false
	artStale = true
	BUI.Print('Contacts skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Friends', TryInstall)
		elseif _G.FriendsFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Contacts',
	description = 'The Contacts window and its Who, Raid, Quick Join and Recruit A Friend tabs: flat shell, boxed tabs, clean rows and dialogs.',
	icon = 'Interface/FriendsFrame/Battlenet-Portrait',
	test = function()
		local frame = _G.FriendsFrame
		if frame then frame:Show() end
		return frame
	end,
	stopTest = function()
		if _G.FriendsFrame then HideUIPanel(_G.FriendsFrame) end
	end,
})
