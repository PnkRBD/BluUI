local _, BUI = ...

local ipairs, pairs = ipairs, pairs

local Skin = BUI.Skinning

local HOVER_ALPHA = 0.06
local SELECTED_ALPHA = 0.18
local SIDE_TAB_TOP_OFFSET = -36
local SIDE_TAB_OPTIONS = { width = 34, height = 34, iconWidth = 26, crop = true, dim = true }
local LIST_SHELL_INSET = { left = 1 }
local LIST_CARD_INSET = { left = 6, right = 6, top = 3, bottom = 3 }
local MEMBER_LIST_SHELL_INSET = { top = -3 }
local SEARCH_BOX_INSET = { left = -5, top = 7, bottom = 7 }
local CHAT_EDIT_INSET = { left = -2, right = -3, top = 2, bottom = 10 }
local CHECK_INSET_DIVISOR = 4
local NAME_SCALE = 1.5
local BIG_TITLE_SCALE = 2
local LIST_ART = { 'Bg', 'TopFiligree', 'BottomFiligree' }
local SIDE_TAB_KEYS = { 'ChatTab', 'RosterTab', 'GuildBenefitsTab', 'GuildInfoTab' }
local FINDER_TAB_KEYS = { 'ClubFinderSearchTab', 'ClubFinderPendingTab' }
local LIST_ENTRY_METHODS = { 'Init', 'SetAddCommunity', 'SetFindCommunity', 'SetGuildFinder' }
local THREE_SLICE_ART = { 'Left', 'Middle', 'Right' }
local CHAT_EDIT_ART = { 'Left', 'Mid', 'Right' }
local MEMBER_ROW_TEXT = { 'Level', 'Zone', 'Rank', 'Note', 'GuildInfo' }
local APPLICANT_ROW_TEXT = { 'Name', 'Level', 'ItemLevel', 'Note', 'AllSpec', 'RequestStatus' }
local TICKET_ROW_TEXT = { 'Creator', 'Link', 'Expires', 'Uses' }
local FACTION_BAR_ART = { 'Left', 'Right', 'Middle', 'Shadow' }
local INVITATION_KEEP = { 'Icon', 'GuildBannerBackground', 'GuildBannerShadow', 'GuildBannerBorder', 'GuildBannerEmblemLogo' }
local INVITATION_TEXT = { 'Type', 'MemberCount', 'Leader', 'Description' }
local INVITATION_BUTTONS = { 'AcceptButton', 'DeclineButton', 'ApplyButton' }
local FINDER_DROPDOWN_KEYS = { 'ClubFilterDropdown', 'ClubSizeDropdown', 'SortByDropdown' }
local FINDER_ROLE_KEYS = { 'TankRoleFrame', 'HealerRoleFrame', 'DpsRoleFrame' }
local FINDER_CARD_KEYS = { 'GuildCards', 'PendingGuildCards' }
local FINDER_LIST_KEYS = { 'CommunityCards', 'PendingCommunityCards' }
local REQUEST_TEXT = { 'ClubName', 'ClubDescription', 'ClubDescription2', 'ErrorDescription', 'RecruitingSpecDescriptions' }
local POSTING_DROPDOWN_KEYS = { 'ClubFocusDropdown', 'LookingForDropdown', 'LanguageDropdown' }
local OPTION_ROW_KEYS = { 'ShouldListClub', 'AutoAcceptApplications', 'MaxLevelOnly', 'MinIlvlOnly' }
local SETTINGS_LABEL_KEYS = { 'NameLabel', 'ShortNameLabel', 'DescriptionLabel', 'MessageOfTheDayLabel' }
local SETTINGS_BUTTON_KEYS = { 'ChangeAvatarButton', 'Delete', 'Accept', 'Cancel' }
local STREAM_LABEL_KEYS = { 'NameLabel', 'DescriptionLabel', 'TypeLabel' }
local STREAM_BUTTON_KEYS = { 'Accept', 'Delete', 'Cancel' }
local TICKET_BUTTON_KEYS = { 'LinkToChat', 'Copy', 'GenerateLinkButton', 'Close' }
local TICKET_DROPDOWN_KEYS = { 'ExpiresDropdown', 'UsesDropdown' }
local NAME_CHANGE_KEYS = { 'GuildNameChangeFrame', 'CommunityNameChangeFrame', 'GuildPostingChangeFrame', 'CommunityPostingChangeFrame' }
local CONTROL_BUTTON_KEYS = { 'CommunitiesSettingsButton', 'GuildControlButton', 'GuildRecruitmentButton' }
local ICON_SELECTOR_EDIT_ART = { 'IconSelectorPopupNameLeft', 'IconSelectorPopupNameMiddle', 'IconSelectorPopupNameRight' }
local RANK_BUTTON_KEYS = { 'deleteButton', 'downButton', 'upButton' }
local DIALOG_BORDER_KEYS = { 'BG' }
local DETAIL_BORDER_KEYS = { 'Border' }
local SELECTOR_KEYS = { 'Selector' }
local BORDER_BOX_KEYS = { 'BorderBox' }
local BANK_TAB_COUNT = 4
local BANK_TAB_INSET = 1

local context = Skin.Define('guild', {
	name = 'Guild & Communities',
	description = 'The Guild & Communities window with its chat, roster, perks, guild info, finder and dialogs; also skins the Guild Bank and Guild Control windows, which only open at a guild vault.',
	icon = 'Interface/Icons/achievement_guildperk_everybodysfriend',
})
local Hook, Guard, Own = context.Hook, context.Guard, context.Own
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, TextBox, Face, Title, Card = context.ScrollBar, context.TextBox, context.Face, context.Title, context.Card
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function FitToCard(texture, host)
	local inset = LIST_CARD_INSET
	texture:ClearAllPoints()
	texture:SetPoint('TOPLEFT', host, 'TOPLEFT', inset.left + 1, -inset.top - 1)
	texture:SetPoint('BOTTOMRIGHT', host, 'BOTTOMRIGHT', -inset.right - 1, inset.bottom + 1)
end

local function Highlight(button, accent)
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if not highlight then return end
	KeepTexture(highlight)
	highlight:SetBlendMode('BLEND')
	if accent then
		Skin.RowHighlight(button)
	else
		FlatTexture(highlight, 1, 1, 1, HOVER_ALPHA)
	end
end

local function FrameIcon(parent, icon)
	if not icon then return end
	KeepTexture(icon)
	CropIcon(icon)
	Skin.TipIconFrame(parent, icon)
end

local function IconButton(button)
	if not button then return end
	KeepTexture(button.icon or button.Icon)
	Button(button)
end

local function FaceKeys(frame, keys)
	if not frame then return end
	for _, key in ipairs(keys) do Face(frame[key]) end
end

local function Label(fontString)
	if fontString then Skin.TipFont(fontString, 'label') end
end

local function ButtonKeys(frame, keys)
	if not frame then return end
	for _, key in ipairs(keys) do Button(frame[key]) end
end

local function SizedCheckBox(check)
	if not check then return end
	CheckBox(check, math.floor(check:GetHeight() / CHECK_INSET_DIVISOR))
end

local function LabeledDropdown(dropdown)
	if not dropdown then return end
	Dropdown(dropdown)
	Label(dropdown.Label)
end

local function OptionRow(row)
	if not row then return end
	SizedCheckBox(row.Button or row.CheckButton)
	Face(row.Label)
	if row.EditBox then
		EditBox(row.EditBox)
		Face(row.EditBox.Text)
	end
end

local function SkinDialogButtons(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.IsObjectType and child:IsObjectType('Button') then
			local text = child.GetText and child:GetText()
			if text and text ~= '' then
				Button(child)
			else
				Close(child)
			end
		end
	end
end

local tabGroups = {}

local function RefreshTabGroup(tabs)
	for _, tab in ipairs(tabs) do Skin.SetSideTabSelected(tab, tab:GetChecked()) end
	Skin.LayoutSideTabs(_G.CommunitiesFrame, tabs, SIDE_TAB_TOP_OFFSET)
end

local function SkinTabGroup(host, keys, method)
	local tabs = tabGroups[host]
	if not tabs then
		tabs = {}
		for index, key in ipairs(keys) do tabs[index] = host[key] end
		tabGroups[host] = tabs
		local function Refresh() RefreshTabGroup(tabs) end
		if method then
			Hook(host, method, Refresh)
		else
			for _, tab in ipairs(tabs) do Hook(tab, 'SetTab', Refresh) end
		end
	end
	for _, tab in ipairs(tabs) do Skin.SideTab(context, tab, SIDE_TAB_OPTIONS) end
	RefreshTabGroup(tabs)
end

local function RestyleListEntry(entry)
	local selection = entry.Selection
	if selection then
		selection:SetBlendMode('BLEND')
		AccentTexture(selection, SELECTED_ALPHA)
	end
	local edges = entry.Icon and entry.Icon._buiIconFrame
	if edges then
		local shown = entry.Icon:IsShown()
		for edgeIndex = 1, 4 do edges[edgeIndex]:SetShown(shown) end
	end
end

local function SkinListEntry(entry)
	if not entry._buiListEntry then
		entry._buiListEntry = true
		Fade(entry.Background)
		Fade(entry.IconRing)
		entry.CircleMask:Hide()
		Highlight(entry)
		FitToCard(entry:GetHighlightTexture(), entry)
		FitToCard(entry.Selection, entry)
		FrameIcon(entry, entry.Icon)
		Face(entry.Name)
		for _, method in ipairs(LIST_ENTRY_METHODS) do Hook(entry, method, RestyleListEntry) end
	end
	Card(entry, LIST_CARD_INSET)
	RestyleListEntry(entry)
end

local function SkinCommunitiesList(list)
	FadeKeys(list, LIST_ART)
	FadeRegions(list.FilligreeOverlay)
	FadeArt(list.InsetFrame)
	Shell(list, LIST_SHELL_INSET)
	ScrollBar(list.ScrollBar)
	Skin.SweepScrollBox(list.ScrollBox, Guard(SkinListEntry))
end

local function SkinColumnHeader(header)
	if header._buiColumnHeader then return end
	header._buiColumnHeader = true
	FadeKeys(header, THREE_SLICE_ART)
	Highlight(header)
	Face(header.GetFontString and header:GetFontString())
end

local function SkinColumnHeaders(columnDisplay)
	for _, child in ipairs({ columnDisplay:GetChildren() }) do
		if child.IsObjectType and child:IsObjectType('Button') then SkinColumnHeader(child) end
	end
end

local function SkinColumnDisplay(columnDisplay)
	if columnDisplay._buiColumns then return end
	columnDisplay._buiColumns = true
	FadeRegions(columnDisplay)
	if columnDisplay.LayoutColumns then Hook(columnDisplay, 'LayoutColumns', SkinColumnHeaders) end
	SkinColumnHeaders(columnDisplay)
end

local function SkinMemberRow(row)
	if row._buiMemberRow then return end
	row._buiMemberRow = true
	Fade(row:GetNormalTexture())
	Highlight(row, true)
	FaceKeys(row, MEMBER_ROW_TEXT)
	Face(row.NameFrame and row.NameFrame.Name)
	local header = row.ProfessionHeader
	if header then
		FadeKeys(header, THREE_SLICE_ART)
		Face(header.Name)
		Face(header.AllRecipes and header.AllRecipes:GetFontString())
	end
	IconButton(row.CancelInvitationButton)
end

local function HideWatermark(memberList)
	memberList.WatermarkFrame:Hide()
end

local function SkinMemberList(memberList)
	FadeArt(memberList.InsetFrame)
	Shell(memberList, MEMBER_LIST_SHELL_INSET)
	Fade(memberList.WatermarkFrame.Watermark)
	HideWatermark(memberList)
	if not memberList._buiWatermarkHooked then
		memberList._buiWatermarkHooked = true
		Hook(memberList, 'UpdateWatermark', HideWatermark)
	end
	Label(memberList.MemberCount)
	CheckBox(memberList.ShowOfflineButton)
	SkinColumnDisplay(memberList.ColumnDisplay)
	ScrollBar(memberList.ScrollBar)
	Skin.SweepScrollBox(memberList.ScrollBox, Guard(SkinMemberRow))
end

local function SkinNoteBox(box)
	Fade(box.NineSlice)
	Shell(box)
end

local function SkinMemberDetail(detail)
	FadeKeys(detail, DETAIL_BORDER_KEYS)
	Shell(detail)
	Skin.TipFaceTree(detail, 1)
	Title(detail.Name)
	Close(detail.CloseButton)
	Button(detail.RemoveButton)
	Button(detail.GroupInviteButton)
	Dropdown(detail.RankDropdown)
	SkinNoteBox(detail.NoteBackground)
	SkinNoteBox(detail.OfficerNoteBackground)
	Face(detail.NoteBackground.PersonalNoteText)
	Face(detail.OfficerNoteBackground.OfficerNoteText)
end

local function SkinChat(frame)
	local chat = frame.Chat
	FadeArt(chat.InsetFrame)
	Shell(chat.InsetFrame)
	ScrollBar(chat.ScrollBar)
	Button(_G.JumpToUnreadButton)
	local editBox = frame.ChatEditBox
	FadeKeys(editBox, CHAT_EDIT_ART)
	EditBox(editBox, CHAT_EDIT_INSET)
	editBox:SetTextInsets(6, 6, 0, 8)
end

local function SkinAddToChat(button)
	FadeRegions(button)
	Shell(button)
	Skin.TipArrow(button, true)
	Label(button.Label)
end

local function SkinPerkRow(row)
	if row._buiPerkRow then return end
	row._buiPerkRow = true
	KeepTexture(row.Icon)
	FadeRegions(row)
	FadeRegions(row.NormalBorder)
	FadeRegions(row.DisabledBorder)
	FrameIcon(row, row.Icon)
	Face(row.Name)
end

local function SkinRewardRow(row)
	if row._buiRewardRow then return end
	row._buiRewardRow = true
	Fade(row:GetNormalTexture())
	Highlight(row, true)
	FrameIcon(row, row.Icon)
	Face(row.Name)
	Face(row.SubText)
end

local function SkinFactionBar(factionFrame)
	Label(factionFrame.Label)
	local bar = factionFrame.Bar
	FadeKeys(bar, FACTION_BAR_ART)
	local trough = bar.BG
	if trough then
		BUI.Painter.Fill(trough, 'skinBackground')
		Skin.TipIconFrame(bar, trough)
	end
	AccentTexture(bar.Progress, 1)
	Face(bar.Label)
end

local function SkinBenefits(benefits)
	FadeRegions(benefits)
	local perks = benefits.Perks
	FadeRegions(perks)
	Title(perks.TitleText)
	ScrollBar(perks.ScrollBar)
	Skin.SweepScrollBox(perks.ScrollBox, Guard(SkinPerkRow))
	local rewards = benefits.Rewards
	Fade(rewards.Bg)
	Title(rewards.TitleText)
	ScrollBar(rewards.ScrollBar)
	Skin.SweepScrollBox(rewards.ScrollBox, Guard(SkinRewardRow))
	local tutorial = benefits.GuildRewardsTutorialButton
	Fade(tutorial)
	tutorial:EnableMouse(false)
	Face(benefits.GuildAchievementPointDisplay.SumText)
	SkinFactionBar(benefits.FactionFrame)
end

local function SkinChallenges(info)
	local challenges = info.Challenges
	if not challenges then return end
	for _, challenge in ipairs(challenges) do
		Face(challenge.label)
		Face(challenge.count)
	end
end

local function SkinGuildInfo(info)
	FadeRegions(info)
	Skin.TipFaceTree(info, 1)
	Title(info.TitleText)
	Label(info.Header1Label)
	Label(info.Header2Label)
	SkinChallenges(info)
	ScrollBar(info.MOTDScrollFrame.ScrollBar)
	Skin.TipFont(info.MOTDScrollFrame.MOTD, 'body')
	ScrollBar(info.DetailsFrame.ScrollBar)
	Face(info.DetailsFrame:GetScrollChild().Details)
	Face(info.EditMOTDButton:GetFontString())
	Face(info.EditDetailsButton:GetFontString())
end

local function SkinNewsRow(row)
	if not row._buiNewsRow then
		row._buiNewsRow = true
		Highlight(row, true)
		Face(row.text)
		Face(row.dash)
	end
	Fade(row.header)
end

local function SkinBossModel(model)
	FadeRegions(model)
	Shell(model)
	Face(model.BossName)
	local textFrame = model.TextFrame
	FadeRegions(textFrame)
	Shell(textFrame)
	Face(textFrame.BossLocationText)
end

local function SkinGuildNews(news)
	FadeRegions(news)
	Skin.TipFaceTree(news, 1)
	Title(news.TitleText)
	Face(news.NoNews)
	Face(news.SetFiltersButton:GetFontString())
	Highlight(news.GMImpeachButton, true)
	Face(news.GMImpeachButton.Text)
	ScrollBar(news.ScrollBar)
	Skin.SweepScrollBox(news.ScrollBox, Guard(SkinNewsRow))
	SkinBossModel(news.BossModel)
end

local function SkinGuildDetails(details)
	FadeRegions(details)
	SkinGuildInfo(details.Info)
	SkinGuildNews(details.News)
end

local function SkinNewsFilters(filters)
	FadeArt(filters)
	Shell(filters)
	Title(filters.Title)
	Close(filters.CloseButton)
	local checks = filters.GuildNewsFilterButtons
	if checks then
		for _, check in ipairs(checks) do CheckBox(check) end
	end
end

local function SkinTextContainer(container)
	Fade(container.NineSlice)
	Shell(container)
	ScrollBar(container.ScrollFrame.ScrollBar)
end

local function SkinGuildLog(log)
	FadeArt(log)
	Shell(log)
	Title(_G.CommunitiesGuildLogFrameTitle)
	SkinDialogButtons(log)
	SkinTextContainer(log.Container)
	Skin.TipFont(log.Container.ScrollFrame.Child.HTMLFrame, 'body')
end

local function SkinTextEdit(edit)
	FadeArt(edit)
	Shell(edit)
	Title(edit.Title)
	SkinDialogButtons(edit)
	SkinTextContainer(edit.Container)
	Face(edit.Container.ScrollFrame.EditBox)
end

local function SkinStreamDialog(dialog)
	FadeKeys(dialog, DIALOG_BORDER_KEYS)
	Shell(dialog)
	Title(dialog.TitleLabel)
	for _, key in ipairs(STREAM_LABEL_KEYS) do Label(dialog[key]) end
	EditBox(dialog.NameEdit)
	TextBox(dialog.Description)
	CheckBox(dialog.TypeCheckbox)
	ButtonKeys(dialog, STREAM_BUTTON_KEYS)
end

local function SkinNotificationEntries(dialog)
	for _, entry in ipairs({ dialog.ScrollFrame.Child:GetChildren() }) do
		if entry.StreamName and not entry._buiStreamEntry then
			entry._buiStreamEntry = true
			Face(entry.StreamName)
			Highlight(entry)
			SizedCheckBox(entry.ShowNotificationsButton)
			SizedCheckBox(entry.HideNotificationsButton)
		end
	end
end

local function SkinNotificationDialog(dialog)
	Fade(dialog.BG)
	FadeKeys(dialog, SELECTOR_KEYS)
	Shell(dialog)
	Title(dialog.TitleLabel)
	Dropdown(dialog.CommunitiesListDropdown)
	Button(dialog.Selector.OkayButton)
	Button(dialog.Selector.CancelButton)
	local scroll = dialog.ScrollFrame
	ScrollBar(scroll.ScrollBar)
	Face(scroll.Child.SettingsLabel)
	CheckBox(scroll.Child.QuickJoinButton)
	Button(scroll.Child.NoneButton)
	Button(scroll.Child.AllButton)
	if not dialog._buiRefreshHooked then
		dialog._buiRefreshHooked = true
		Hook(dialog, 'Refresh', SkinNotificationEntries)
	end
	SkinNotificationEntries(dialog)
end

local function SkinMessageInput(messageFrame, inputKey)
	FadeRegions(messageFrame)
	Label(messageFrame.Label)
	TextBox(messageFrame[inputKey])
end

local function SkinRecruitmentDialog(dialog)
	FadeKeys(dialog, DIALOG_BORDER_KEYS)
	Shell(dialog)
	Title(dialog.DialogLabel)
	for _, key in ipairs(OPTION_ROW_KEYS) do OptionRow(dialog[key]) end
	for _, key in ipairs(POSTING_DROPDOWN_KEYS) do LabeledDropdown(dialog[key]) end
	SkinMessageInput(dialog.RecruitmentMessageFrame, 'RecruitmentMessageInput')
	Button(dialog.Accept)
	Button(dialog.Cancel)
end

local function SkinSettingsDialog(dialog)
	FadeKeys(dialog, DIALOG_BORDER_KEYS)
	Fade(dialog.IconPreviewRing)
	if dialog.CircleMask then dialog.CircleMask:Hide() end
	Shell(dialog)
	Title(dialog.DialogLabel)
	for _, key in ipairs(SETTINGS_LABEL_KEYS) do Label(dialog[key]) end
	Face(dialog.ClubFinderPostingBannedError)
	FrameIcon(dialog, dialog.IconPreview)
	EditBox(dialog.NameEdit)
	EditBox(dialog.ShortNameEdit)
	TextBox(dialog.Description)
	TextBox(dialog.MessageOfTheDay)
	OptionRow(dialog.CrossFactionToggle)
	for _, key in ipairs(OPTION_ROW_KEYS) do OptionRow(dialog[key]) end
	for _, key in ipairs(POSTING_DROPDOWN_KEYS) do LabeledDropdown(dialog[key]) end
	ButtonKeys(dialog, SETTINGS_BUTTON_KEYS)
end

local function SkinAvatarButton(button)
	if not button.Icon or button._buiAvatar then return end
	button._buiAvatar = true
	Highlight(button)
	FrameIcon(button, button.Icon)
	local selected = button.Selected
	if selected then
		selected:SetBlendMode('BLEND')
		AccentTexture(selected, SELECTED_ALPHA * 2)
	end
end

local function SkinAvatarRow(row)
	if row.Icon then
		SkinAvatarButton(row)
		return
	end
	for _, child in ipairs({ row:GetChildren() }) do SkinAvatarButton(child) end
end

local function SkinAvatarPicker(dialog)
	FadeRegions(dialog)
	FadeKeys(dialog, SELECTOR_KEYS)
	Shell(dialog)
	Skin.TipFaceTree(dialog, 1)
	Button(dialog.Selector.OkayButton)
	Button(dialog.Selector.CancelButton)
	ScrollBar(dialog.ScrollBar)
	Skin.SweepScrollBox(dialog.ScrollBox, Guard(SkinAvatarRow))
end

local function SkinTicketRow(row)
	if row._buiTicketRow then return end
	row._buiTicketRow = true
	Fade(row.Stripe)
	Highlight(row, true)
	FaceKeys(row, TICKET_ROW_TEXT)
	Button(row.CopyLinkButton)
	IconButton(row.RevokeButton)
end

local function SkinTicketManager(dialog)
	KeepTexture(dialog.Icon)
	KeepTexture(dialog.CircleMask)
	FadeRegions(dialog)
	dialog.CircleMask:Hide()
	FrameIcon(dialog, dialog.Icon)
	Shell(dialog)
	Skin.TipFaceTree(dialog, 1)
	Title(dialog.DialogLabel)
	ButtonKeys(dialog, TICKET_BUTTON_KEYS)
	for _, key in ipairs(TICKET_DROPDOWN_KEYS) do Dropdown(dialog[key]) end
	IconButton(dialog.MaximizeButton)
	local manager = dialog.InviteManager
	FadeRegions(manager.ArtOverlay)
	SkinColumnDisplay(manager.ColumnDisplay)
	Fade(manager.ScrollBox.Background)
	ScrollBar(manager.ScrollBar)
	Skin.SweepScrollBox(manager.ScrollBox, Guard(SkinTicketRow))
end

local function SkinApplicantRow(row)
	if row._buiApplicantRow then return end
	row._buiApplicantRow = true
	Fade(row:GetNormalTexture())
	Highlight(row, true)
	FaceKeys(row, APPLICANT_ROW_TEXT)
	IconButton(row.CancelInvitationButton)
	local invite = row.InviteButton
	if invite then
		Button(invite)
		Face(invite.Text)
	end
end

local function SkinApplicantList(list)
	FadeArt(list.InsetFrame)
	Shell(list)
	SkinColumnDisplay(list.ColumnDisplay)
	ScrollBar(list.ScrollBar)
	Skin.SweepScrollBox(list.ScrollBox, Guard(SkinApplicantRow))
end

local function SkinRequestSpecs(request)
	local pool = request.SpecsPool
	if not pool then return end
	for spec in pool:EnumerateActive() do
		SizedCheckBox(spec.Checkbox)
		Face(spec.SpecName)
	end
end

local function SkinRequestToJoin(request)
	if not request or request._buiRequest then return end
	request._buiRequest = true
	FadeKeys(request, DIALOG_BORDER_KEYS)
	Shell(request)
	Title(request.DialogLabel)
	FaceKeys(request, REQUEST_TEXT)
	SkinMessageInput(request.MessageFrame, 'MessageScroll')
	Button(request.Apply)
	Button(request.Cancel)
	Hook(request, 'Initialize', SkinRequestSpecs)
	SkinRequestSpecs(request)
end

local function SkinWarningDialog(warning)
	if not warning then return end
	FadeKeys(warning, DIALOG_BORDER_KEYS)
	Shell(warning)
	Face(warning.DialogLabel)
	Button(warning.Accept)
	Button(warning.Cancel)
end

local function SkinInvitation(invitation)
	for _, key in ipairs(INVITATION_KEEP) do KeepTexture(invitation[key]) end
	KeepTexture(invitation.CircleMask)
	FadeRegions(invitation)
	if invitation.CircleMask then invitation.CircleMask:Hide() end
	FrameIcon(invitation, invitation.Icon)
	FadeArt(invitation.InsetFrame)
	Shell(invitation)
	Title(invitation.InvitationText)
	if invitation.Name then Skin.TipFace(invitation.Name, 'title', NAME_SCALE) end
	FaceKeys(invitation, INVITATION_TEXT)
	ButtonKeys(invitation, INVITATION_BUTTONS)
	SkinWarningDialog(invitation.WarningDialog)
	SkinRequestToJoin(invitation.RequestToJoinFrame)
end

local function RefreshCardPager(cards)
	Skin.RefreshPageButton(cards.PreviousPage)
	Skin.RefreshPageButton(cards.NextPage)
end

local function SkinGuildCard(card)
	if not card or card._buiGuildCard then return end
	card._buiGuildCard = true
	Fade(card.CardBackground)
	Shell(card)
	Skin.TipFaceTree(card, 1)
	Title(card.Name)
	Button(card.RequestJoin)
end

local function SkinGuildCards(cards)
	if cards.Cards then
		for _, card in ipairs(cards.Cards) do SkinGuildCard(card) end
	end
	Skin.TipPageButton(cards.PreviousPage, 'previous')
	Skin.TipPageButton(cards.NextPage, 'next')
	if cards.RefreshLayout and not cards._buiLayoutHooked then
		cards._buiLayoutHooked = true
		Hook(cards, 'RefreshLayout', RefreshCardPager)
	end
	local spinner = cards.SearchingSpinner
	if spinner then Title(spinner.Label) end
end

local function SkinCommunityCard(card)
	if card._buiCommunityCard then return end
	card._buiCommunityCard = true
	Fade(card.Background)
	Fade(card.LogoBorder)
	if card.CircleMask then card.CircleMask:Hide() end
	Highlight(card)
	FrameIcon(card, card.CommunityLogo)
	Shell(card)
	Skin.TipFaceTree(card, 1)
	Title(card.Name)
	local join = card.RequestJoin
	if join then Face(join.InvitedString) end
end

local function SkinCommunityCards(cards)
	ScrollBar(cards.ScrollBar)
	Skin.SweepScrollBox(cards.ScrollBox, Guard(SkinCommunityCard))
end

local function SkinFinderOptions(options)
	if options.PendingTextFrame then Title(options.PendingTextFrame.Text) end
	for _, key in ipairs(FINDER_DROPDOWN_KEYS) do LabeledDropdown(options[key]) end
	for _, key in ipairs(FINDER_ROLE_KEYS) do
		local role = options[key]
		if role then SizedCheckBox(role.Checkbox) end
	end
	EditBox(options.SearchBox, SEARCH_BOX_INSET)
	Button(options.Search)
end

local function SkinFinder(finder)
	SkinFinderOptions(finder.OptionsList)
	for _, key in ipairs(FINDER_CARD_KEYS) do SkinGuildCards(finder[key]) end
	for _, key in ipairs(FINDER_LIST_KEYS) do SkinCommunityCards(finder[key]) end
	SkinRequestToJoin(finder.RequestToJoinFrame)
	local inset = finder.InsetFrame
	FadeArt(inset)
	Skin.TipFace(inset.GuildDescription, 'title')
	Skin.TipFace(inset.ErrorDescription, 'title')
	local disabled = finder.DisabledFrame
	FadeArt(disabled)
	Skin.TipFace(disabled.Title, 'title', BIG_TITLE_SCALE)
	Skin.TipFace(disabled.Description, 'title')
	SkinTabGroup(finder, FINDER_TAB_KEYS)
end

local function SkinNameChange(frame)
	FadeRegions(frame)
	Shell(frame)
	Skin.TipFaceTree(frame, 1)
	Title(frame.RenameText)
	Close(frame.CloseButton)
	Button(frame.Button)
	EditBox(frame.EditBox)
end

local function SkinPostingExpiration(expiration)
	Skin.TipFaceTree(expiration, 1)
	Fade(expiration.InfoButton)
	expiration.InfoButton:EnableMouse(false)
end

local function SkinMainFrame(frame)
	context.Chrome(frame)
	KeepTexture(frame.PortraitOverlay.CircleMask)
	FadeRegions(frame.PortraitOverlay)
	SkinTabGroup(frame, SIDE_TAB_KEYS, 'UpdateCommunitiesTabs')
	Dropdown(frame.StreamDropdown)
	Dropdown(frame.GuildMemberListDropdown)
	Dropdown(frame.CommunityMemberListDropdown)
	Dropdown(frame.CommunitiesListDropdown)
	SkinAddToChat(frame.AddToChatButton)
	Button(frame.InviteButton)
	Button(frame.GuildLogButton)
	ButtonKeys(frame.CommunitiesControlFrame, CONTROL_BUTTON_KEYS)
	SkinPostingExpiration(frame.PostingExpirationText)
end

local function SkinCommunities(frame)
	SkinMainFrame(frame)
	SkinCommunitiesList(frame.CommunitiesList)
	SkinChat(frame)
	SkinMemberList(frame.MemberList)
	SkinMemberDetail(frame.GuildMemberDetailFrame)
	SkinBenefits(frame.GuildBenefitsFrame)
	SkinGuildDetails(frame.GuildDetailsFrame)
	SkinNewsFilters(_G.CommunitiesGuildNewsFiltersFrame)
	SkinGuildLog(_G.CommunitiesGuildLogFrame)
	SkinTextEdit(_G.CommunitiesGuildTextEditFrame)
	SkinStreamDialog(frame.EditStreamDialog)
	SkinNotificationDialog(frame.NotificationSettingsDialog)
	SkinRecruitmentDialog(frame.RecruitmentDialog)
	SkinSettingsDialog(_G.CommunitiesSettingsDialog)
	SkinAvatarPicker(_G.CommunitiesAvatarPickerDialog)
	SkinTicketManager(_G.CommunitiesTicketManagerDialog)
	SkinApplicantList(frame.ApplicantList)
	SkinInvitation(frame.InvitationFrame)
	SkinInvitation(frame.TicketFrame)
	SkinInvitation(frame.ClubFinderInvitationFrame)
	SkinFinder(frame.GuildFinderFrame)
	SkinFinder(frame.CommunityFinderFrame)
	for _, key in ipairs(NAME_CHANGE_KEYS) do SkinNameChange(frame[key]) end
end

local function RefreshTabGroups()
	for _, tabs in pairs(tabGroups) do RefreshTabGroup(tabs) end
end

local function SkinBankSlot(button)
	if button._buiBankSlot then return end
	button._buiBankSlot = true
	Fade(button:GetNormalTexture())
	Fade(button.IconBorder)
	Fade(button.IconOverlay)
	local icon = button.icon
	if not icon then return end
	local fill = Own(button:CreateTexture(nil, 'BACKGROUND'))
	fill:SetAllPoints(icon)
	BUI.Painter.Fill(fill, 'skinBackground')
	FrameIcon(button, icon)
end

local function RefreshBankSlots(frame)
	if frame.mode ~= 'bank' then return end
	local tab = GetCurrentGuildBankTab()
	for _, column in ipairs(frame.Columns) do
		for _, button in ipairs(column.Buttons) do
			local icon = button.icon
			if icon and icon._buiIconFrame then
				CropIcon(icon)
				local _, _, _, _, quality = GetGuildBankItemInfo(tab, button:GetID())
				Skin.SetIconEdgeRarity(icon, quality)
			end
		end
	end
end

local function SkinBankTab(tab)
	if not tab or tab._buiBankTab then return end
	tab._buiBankTab = true
	FadeRegions(tab)
	local button = tab.Button
	if not button then return end
	Fade(button.NormalTexture)
	Fade(button:GetPushedTexture())
	Fade(button:GetCheckedTexture())
	Highlight(button)
	CropIcon(button.IconTexture)
	Shell(button, BANK_TAB_INSET)
	Skin.TipCount(button.Count)
end

local function RefreshBankTabs(frame)
	for _, tab in ipairs(frame.BankTabs) do
		local button = tab.Button
		if button and tab._buiBankTab then
			CropIcon(button.IconTexture)
			Skin.TipShellEdges(button, button:GetChecked() == true)
		end
	end
end

local function SkinIconCell(button)
	if button._buiIconCell then return end
	button._buiIconCell = true
	KeepTexture(button.Icon)
	KeepTexture(button.SelectedTexture)
	Highlight(button)
	FadeRegions(button)
	FrameIcon(button, button.Icon)
	local selected = button.SelectedTexture
	if selected then
		selected:SetBlendMode('BLEND')
		AccentTexture(selected, SELECTED_ALPHA * 2)
	end
end

local function SkinSelectedIcon(area)
	if not area then return end
	local button = area.SelectedIconButton
	if button then
		KeepTexture(button.Icon)
		FadeRegions(button)
		FrameIcon(button, button.Icon)
	end
	Skin.TipFaceTree(area, 3)
end

local function SkinBankPopup(popup)
	Fade(popup.BG)
	FadeKeys(popup, BORDER_BOX_KEYS)
	Shell(popup)
	local box = popup.BorderBox
	if box then
		Label(box.EditBoxHeaderText)
		Face(box.IconSelectionText)
		local editBox = box.IconSelectorEditBox
		if editBox then
			FadeKeys(editBox, ICON_SELECTOR_EDIT_ART)
			EditBox(editBox)
		end
		Dropdown(box.IconTypeDropdown)
		Dropdown(box.IconFilterDropdown)
		Button(box.OkayButton or popup.OkayButton)
		Button(box.CancelButton or popup.CancelButton)
		SkinSelectedIcon(box.SelectedIconArea)
		local drag = box.IconDragArea
		if drag then Skin.TipFaceTree(drag, 2) end
	end
	local selector = popup.IconSelector
	if selector then
		FadeRegions(selector)
		ScrollBar(selector.ScrollBar)
		Skin.SweepScrollBox(selector.ScrollBox, Guard(SkinIconCell))
	end
end

local function SkinBankInfo(info)
	Button(info.SaveButton)
	ScrollBar(info.ScrollFrame.ScrollBar)
	Face(info.ScrollFrame.EditBox)
end

local function SkinGuildBankFrame(frame)
	context.Chrome(frame)
	FadeRegions(frame.Emblem)
	Face(frame.TabTitle)
	Label(frame.LimitLabel)
	Face(frame.ErrorMessage)
	for _, column in ipairs(frame.Columns) do
		Fade(column.Background)
		for _, button in ipairs(column.Buttons) do SkinBankSlot(button) end
	end
	local moneyBackground = frame.MoneyFrameBG
	if moneyBackground then
		FadeRegions(moneyBackground)
		Label(moneyBackground.LimitLabel)
		Face(moneyBackground.UnlimitedLabel)
	end
	Button(frame.DepositButton)
	Button(frame.WithdrawButton)
	local tabs = {}
	for tabIndex = 1, BANK_TAB_COUNT do tabs[tabIndex] = _G['GuildBankFrameTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
	for _, tab in ipairs(frame.BankTabs) do SkinBankTab(tab) end
	local buyInfo = frame.BuyInfo
	if buyInfo then
		Skin.TipFaceTree(buyInfo, 1)
		Button(buyInfo.PurchaseButton)
	end
	if frame.Log then ScrollBar(frame.Log.ScrollBar) end
	SkinBankInfo(frame.Info)
	EditBox(_G.GuildItemSearchBox)
	SkinBankPopup(_G.GuildBankPopupFrame)
end

local function RefreshGuildBank(frame)
	Skin.RefreshTabStrip(frame)
	RefreshBankTabs(frame)
	RefreshBankSlots(frame)
end

local function SkinRankRows()
	for rankIndex = 1, GuildControlGetNumRanks() do
		local rankFrame = _G['GuildControlUIRankOrderFrameRank' .. rankIndex]
		if rankFrame and not rankFrame._buiRankRow then
			rankFrame._buiRankRow = true
			EditBox(rankFrame.nameBox)
			Label(rankFrame.rankLabel)
			for _, key in ipairs(RANK_BUTTON_KEYS) do IconButton(rankFrame[key]) end
		end
	end
end

local function SkinBankPermissionRow(row)
	if row._buiPermissionRow then return end
	row._buiPermissionRow = true
	local owned = row.owned
	if owned then
		FrameIcon(owned, owned.tabIcon)
		Face(owned.tabName)
		CheckBox(owned.viewCB)
		CheckBox(owned.depositCB)
		local stackBox = owned.editBox
		if stackBox then
			EditBox(stackBox)
			Label(_G[stackBox:GetName() .. 'LabelText'])
		end
	end
	local buy = row.buy
	if buy then
		Skin.TipFaceTree(buy, 1)
		Button(buy.button)
	end
end

local function SkinBankPermissionRows()
	local rowIndex = 1
	local row = _G['GuildControlBankTab' .. rowIndex]
	while row do
		SkinBankPermissionRow(row)
		rowIndex = rowIndex + 1
		row = _G['GuildControlBankTab' .. rowIndex]
	end
end

local function SkinDiscordPanels()
	local linked = _G.DiscordLinkFrame
	if linked and not linked._buiDiscord then
		linked._buiDiscord = true
		Skin.TipFaceTree(linked, 1)
		Title(linked.linkedTitle)
		OptionRow(linked.SeparateStream)
		Button(linked.button)
	end
	local unlinked = _G.DiscordUnlinkFrame
	if unlinked and not unlinked._buiDiscord then
		unlinked._buiDiscord = true
		Face(unlinked.unlinkedTitle)
		Button(unlinked.button)
	end
end

local function SkinRankPermissions(permissions)
	Dropdown(permissions.dropdown)
	Skin.TipFaceTree(permissions.dropdown, 1)
	Face(permissions.OfficerPermissions)
	Label(_G.GuildControlUIRankSettingsFrameBankLabel)
	CheckBox(permissions.OfficerCheckbox)
	for flagIndex = 1, NUM_RANK_FLAGS do CheckBox(_G['GuildControlUIRankSettingsFrameCheckbox' .. flagIndex]) end
	local goldBox = permissions.goldBox
	if goldBox then
		EditBox(goldBox)
		Skin.TipFaceTree(goldBox, 1)
	end
end

local function SkinGuildControlFrame(frame)
	FadeArt(frame)
	Shell(frame)
	Title(_G.GuildControlUITitle)
	Close(_G.GuildControlUICloseButton)
	Dropdown(frame.dropdown)
	FadeRegions(_G.GuildControlUIHbar)
	local order = frame.orderFrame
	if order then
		Button(order.newButton)
		Button(order.dupButton)
	end
	local bank = frame.bankTabFrame
	if bank then
		Dropdown(bank.dropdown)
		Skin.TipFaceTree(bank.dropdown, 1)
		local inset = bank.inset
		if inset then
			FadeArt(inset)
			Shell(inset)
			if inset.scrollFrame then ScrollBar(inset.scrollFrame.ScrollBar) end
		end
	end
	local discord = frame.discordFrame
	if discord then
		Dropdown(discord.serverDropdown)
		Skin.TipFaceTree(discord.serverDropdown, 1)
		Dropdown(discord.channelDropdown)
		Skin.TipFaceTree(discord.channelDropdown, 1)
		Button(discord.channelButton)
		Face(discord.channelListTitle)
		Face(discord.noChannelsError)
	end
	SkinRankPermissions(frame.rankPermFrame)
end

local function RefreshGuildControl()
	SkinRankRows()
	SkinBankPermissionRows()
	SkinDiscordPanels()
end

context.Window('CommunitiesFrame', { skin = SkinCommunities, show = RefreshTabGroups })

context.Window('GuildBankFrame', {
	skin = SkinGuildBankFrame,
	show = RefreshGuildBank,
	install = function(frame)
		Hook(frame, 'Update', RefreshBankSlots)
		Hook(frame, 'UpdateTabs', RefreshBankTabs)
	end,
})

context.Window('GuildControlUI', {
	skin = SkinGuildControlFrame,
	show = RefreshGuildControl,
	install = function()
		Hook('GuildControlUI_RankOrder_Update', SkinRankRows)
		Hook('GuildControlUI_BankTabPermissions_Update', SkinBankPermissionRows)
		Hook('GuildControlUI_Discord_Update', SkinDiscordPanels)
	end,
})

context.OnDisable(function()
	for _, tabs in pairs(tabGroups) do
		for _, tab in ipairs(tabs) do Skin.ResetSideTab(tab) end
	end
end)
