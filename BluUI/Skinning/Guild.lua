local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Guild')

local hooksecurefunc = BUI.Prof.MakeHooker('guild')
local ipairs, pairs = ipairs, pairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'guild'
local HOVER_ALPHA = 0.06
local SELECTED_ALPHA = 0.18
local ROW_TEXTURE_INSET = 1
local SIDE_TAB_TOP_OFFSET = -36
local SIDE_TAB_OPTIONS = { width = 32, height = 32, crop = true }
local CHAT_EDIT_INSET = 6
local CHECK_INSET_DIVISOR = 4
local NAME_SCALE = 1.5
local BIG_TITLE_SCALE = 2
local BODY_COLOR = { 0.87, 0.87, 0.9, 1 }
local HTML_ELEMENTS = { P = 12, H1 = 16, H2 = 14, H3 = 13 }
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'Inset' }
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

local installed = false
local communitiesInstalled = false
local bankInstalled = false
local controlInstalled = false
local communitiesSkinned = false
local bankSkinned = false
local controlSkinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, TextBox, Face, Title = context.ScrollBar, context.TextBox, context.Face, context.Title
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function GuardEnabled(callback)
	return function(...)
		if Enabled() then callback(...) end
	end
end

local function FitTexture(texture, host, inset)
	if not texture or not host then return end
	inset = inset or 0
	texture:ClearAllPoints()
	texture:SetPoint('TOPLEFT', host, 'TOPLEFT', inset, -inset)
	texture:SetPoint('BOTTOMRIGHT', host, 'BOTTOMRIGHT', -inset, inset)
end

local function FlatHighlight(button, alpha)
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if not highlight then return end
	KeepTexture(highlight)
	highlight:SetBlendMode('BLEND')
	FlatTexture(highlight, 1, 1, 1, alpha or HOVER_ALPHA)
end

local function RowHover(button)
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if not highlight then return end
	KeepTexture(highlight)
	highlight:SetBlendMode('BLEND')
	Skin.RowHighlight(button)
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

local function SkinHtml(html)
	if not html or not html.SetFont or not html.SetTextColor then return end
	for element, size in pairs(HTML_ELEMENTS) do
		html:SetFont(element, BUILib.Font, size, '')
		html:SetTextColor(element, BODY_COLOR[1], BODY_COLOR[2], BODY_COLOR[3])
	end
end

local function ScrollChild(scrollFrame, key)
	if not scrollFrame then return nil end
	local child = scrollFrame:GetScrollChild()
	if child and key and child[key] then return child[key] end
	return child
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

local skinnedSideTabs = {}
local sideTabs

local function SideTabs(frame)
	if not sideTabs then
		sideTabs = {}
		for index, key in ipairs(SIDE_TAB_KEYS) do sideTabs[index] = frame[key] end
	end
	return sideTabs
end

local function RefreshTabSelected(tab)
	if tab and tab._buiSideTab then Skin.SetSideTabSelected(tab, tab:GetChecked() == true) end
end

local function RefreshSideTabs()
	local frame = _G.CommunitiesFrame
	if not frame or not Enabled() then return end
	for _, tab in ipairs(SideTabs(frame)) do
		Skin.SideTab(context, tab, SIDE_TAB_OPTIONS)
		RefreshTabSelected(tab)
	end
	Skin.LayoutSideTabs(frame, sideTabs, SIDE_TAB_TOP_OFFSET)
end

local function RefreshFinderTabs(finder)
	if not finder or not Enabled() then return end
	for _, key in ipairs(FINDER_TAB_KEYS) do
		local tab = finder[key]
		Skin.SideTab(context, tab, SIDE_TAB_OPTIONS)
		RefreshTabSelected(tab)
	end
end

local function SkinSideTab(tab, onClick)
	if not tab or tab._buiGuildTab then return end
	tab._buiGuildTab = true
	Skin.SideTab(context, tab, SIDE_TAB_OPTIONS)
	skinnedSideTabs[#skinnedSideTabs + 1] = tab
	HookScript(tab, 'OnClick', onClick)
	RefreshTabSelected(tab)
end

local function RestyleListEntry(entry)
	if not Enabled() then return end
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
		if entry.CircleMask then entry.CircleMask:Hide() end
		FlatHighlight(entry)
		FitTexture(entry:GetHighlightTexture(), entry, ROW_TEXTURE_INSET)
		FitTexture(entry.Selection, entry, ROW_TEXTURE_INSET)
		FrameIcon(entry, entry.Icon)
		Face(entry.Name)
		for _, method in ipairs(LIST_ENTRY_METHODS) do
			if entry[method] then hooksecurefunc(entry, method, RestyleListEntry) end
		end
	end
	RestyleListEntry(entry)
end

local function SkinCommunitiesList(list)
	if not list then return end
	FadeKeys(list, LIST_ART)
	FadeRegions(list.FilligreeOverlay)
	FadeArt(list.InsetFrame)
	Shell(list)
	ScrollBar(list.ScrollBar)
	Skin.SweepScrollBox(list.ScrollBox, GuardEnabled(SkinListEntry))
end

local function SkinColumnHeader(header)
	if header._buiColumnHeader then return end
	header._buiColumnHeader = true
	FadeKeys(header, THREE_SLICE_ART)
	FlatHighlight(header)
	Face(header.GetFontString and header:GetFontString())
end

local function SkinColumnHeaders(columnDisplay)
	if not Enabled() then return end
	for _, child in ipairs({ columnDisplay:GetChildren() }) do
		if child.IsObjectType and child:IsObjectType('Button') then SkinColumnHeader(child) end
	end
end

local function SkinColumnDisplay(columnDisplay)
	if not columnDisplay or columnDisplay._buiColumns then return end
	columnDisplay._buiColumns = true
	FadeRegions(columnDisplay)
	if columnDisplay.LayoutColumns then hooksecurefunc(columnDisplay, 'LayoutColumns', SkinColumnHeaders) end
	SkinColumnHeaders(columnDisplay)
end

local function SkinMemberRow(row)
	if row._buiMemberRow then return end
	row._buiMemberRow = true
	Fade(row:GetNormalTexture())
	RowHover(row)
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
	if not Enabled() then return end
	local watermarkFrame = memberList.WatermarkFrame
	if watermarkFrame then watermarkFrame:SetShown(false) end
end

local function SkinMemberList(memberList)
	if not memberList then return end
	FadeArt(memberList.InsetFrame)
	Shell(memberList)
	local watermarkFrame = memberList.WatermarkFrame
	if watermarkFrame then
		Fade(watermarkFrame.Watermark)
		watermarkFrame:SetShown(false)
		if memberList.UpdateWatermark and not memberList._buiWatermarkHooked then
			memberList._buiWatermarkHooked = true
			hooksecurefunc(memberList, 'UpdateWatermark', HideWatermark)
		end
	end
	Label(memberList.MemberCount)
	CheckBox(memberList.ShowOfflineButton)
	SkinColumnDisplay(memberList.ColumnDisplay)
	ScrollBar(memberList.ScrollBar)
	Skin.SweepScrollBox(memberList.ScrollBox, GuardEnabled(SkinMemberRow))
end

local function SkinNoteBox(box)
	if not box then return end
	Fade(box.NineSlice)
	Shell(box)
end

local function SkinMemberDetail(detail)
	if not detail then return end
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
	Face(detail.NoteBackground and detail.NoteBackground.PersonalNoteText)
	Face(detail.OfficerNoteBackground and detail.OfficerNoteBackground.OfficerNoteText)
end

local function SkinChat(frame)
	local chat = frame.Chat
	if chat then
		FadeArt(chat.InsetFrame)
		Shell(chat.InsetFrame)
		ScrollBar(chat.ScrollBar)
	end
	Button(_G.JumpToUnreadButton)
	local editBox = frame.ChatEditBox
	if editBox then
		FadeKeys(editBox, CHAT_EDIT_ART)
		EditBox(editBox, CHAT_EDIT_INSET)
	end
end

local function SkinAddToChat(button)
	if not button then return end
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
	RowHover(row)
	FrameIcon(row, row.Icon)
	Face(row.Name)
	Face(row.SubText)
end

local function SkinFactionBar(factionFrame)
	if not factionFrame then return end
	Label(factionFrame.Label)
	local bar = factionFrame.Bar
	if not bar then return end
	FadeKeys(bar, FACTION_BAR_ART)
	local trough = bar.BG
	if trough then
		local fill = Skin.PANEL_FILL
		FlatTexture(trough, fill[1], fill[2], fill[3], fill[4])
		Skin.TipIconFrame(bar, trough)
	end
	AccentTexture(bar.Progress, 1)
	Face(bar.Label)
end

local function SkinBenefits(benefits)
	if not benefits then return end
	FadeRegions(benefits)
	local perks = benefits.Perks
	if perks then
		FadeRegions(perks)
		Title(perks.TitleText)
		ScrollBar(perks.ScrollBar)
		Skin.SweepScrollBox(perks.ScrollBox, GuardEnabled(SkinPerkRow))
	end
	local rewards = benefits.Rewards
	if rewards then
		Fade(rewards.Bg)
		Title(rewards.TitleText)
		ScrollBar(rewards.ScrollBar)
		Skin.SweepScrollBox(rewards.ScrollBox, GuardEnabled(SkinRewardRow))
	end
	local tutorial = benefits.GuildRewardsTutorialButton
	if tutorial then
		Fade(tutorial)
		tutorial:EnableMouse(false)
	end
	local points = benefits.GuildAchievementPointDisplay
	if points then Face(points.SumText) end
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
	if not info then return end
	FadeRegions(info)
	Skin.TipFaceTree(info, 1)
	Title(info.TitleText)
	Label(info.Header1Label)
	Label(info.Header2Label)
	SkinChallenges(info)
	local motdScroll = info.MOTDScrollFrame
	if motdScroll then
		ScrollBar(motdScroll.ScrollBar)
		SkinHtml(ScrollChild(motdScroll, 'MOTD'))
	end
	local detailsScroll = info.DetailsFrame
	if detailsScroll then
		ScrollBar(detailsScroll.ScrollBar)
		Face(ScrollChild(detailsScroll, 'Details'))
	end
	Face(info.EditMOTDButton and info.EditMOTDButton:GetFontString())
	Face(info.EditDetailsButton and info.EditDetailsButton:GetFontString())
end

local function SkinNewsRow(row)
	if not row._buiNewsRow then
		row._buiNewsRow = true
		RowHover(row)
		Face(row.text)
		Face(row.dash)
	end
	Fade(row.header)
end

local function SkinBossModel(model)
	if not model then return end
	FadeRegions(model)
	Shell(model)
	Face(model.BossName)
	local textFrame = model.TextFrame
	if textFrame then
		FadeRegions(textFrame)
		Shell(textFrame)
		Face(textFrame.BossLocationText)
	end
end

local function SkinGuildNews(news)
	if not news then return end
	FadeRegions(news)
	Skin.TipFaceTree(news, 1)
	Title(news.TitleText)
	Face(news.NoNews)
	Face(news.SetFiltersButton and news.SetFiltersButton:GetFontString())
	local impeach = news.GMImpeachButton
	if impeach then
		RowHover(impeach)
		Face(impeach.Text)
	end
	ScrollBar(news.ScrollBar)
	Skin.SweepScrollBox(news.ScrollBox, GuardEnabled(SkinNewsRow))
	SkinBossModel(news.BossModel)
end

local function SkinGuildDetails(details)
	if not details then return end
	FadeRegions(details)
	SkinGuildInfo(details.Info)
	SkinGuildNews(details.News)
end

local function SkinNewsFilters(filters)
	if not filters then return end
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
	if not container then return end
	Fade(container.NineSlice)
	Shell(container)
	local scroll = container.ScrollFrame
	if scroll then ScrollBar(scroll.ScrollBar) end
end

local function SkinGuildLog(log)
	if not log then return end
	FadeArt(log)
	Shell(log)
	Title(_G.CommunitiesGuildLogFrameTitle)
	SkinDialogButtons(log)
	SkinTextContainer(log.Container)
	local scroll = log.Container and log.Container.ScrollFrame
	if scroll then SkinHtml(scroll.Child and scroll.Child.HTMLFrame or ScrollChild(scroll, 'HTMLFrame')) end
end

local function SkinTextEdit(edit)
	if not edit then return end
	FadeArt(edit)
	Shell(edit)
	Title(edit.Title)
	SkinDialogButtons(edit)
	SkinTextContainer(edit.Container)
	local scroll = edit.Container and edit.Container.ScrollFrame
	if scroll then Face(scroll.EditBox or ScrollChild(scroll, 'EditBox')) end
end

local function SkinStreamDialog(dialog)
	if not dialog then return end
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
	if not Enabled() then return end
	local child = dialog.ScrollFrame and dialog.ScrollFrame.Child
	if not child then return end
	for _, entry in ipairs({ child:GetChildren() }) do
		if entry.StreamName and not entry._buiStreamEntry then
			entry._buiStreamEntry = true
			Face(entry.StreamName)
			FlatHighlight(entry)
			SizedCheckBox(entry.ShowNotificationsButton)
			SizedCheckBox(entry.HideNotificationsButton)
		end
	end
end

local function SkinNotificationDialog(dialog)
	if not dialog then return end
	Fade(dialog.BG)
	FadeKeys(dialog, SELECTOR_KEYS)
	Shell(dialog)
	Title(dialog.TitleLabel)
	Dropdown(dialog.CommunitiesListDropdown)
	local selector = dialog.Selector
	if selector then
		Button(selector.OkayButton)
		Button(selector.CancelButton)
	end
	local scroll = dialog.ScrollFrame
	if scroll then
		ScrollBar(scroll.ScrollBar)
		local child = scroll.Child
		if child then
			Face(child.SettingsLabel)
			CheckBox(child.QuickJoinButton)
			Button(child.NoneButton)
			Button(child.AllButton)
		end
	end
	if dialog.Refresh and not dialog._buiRefreshHooked then
		dialog._buiRefreshHooked = true
		hooksecurefunc(dialog, 'Refresh', SkinNotificationEntries)
	end
	SkinNotificationEntries(dialog)
end

local function SkinMessageInput(messageFrame, inputKey)
	if not messageFrame then return end
	FadeRegions(messageFrame)
	Label(messageFrame.Label)
	TextBox(messageFrame[inputKey])
end

local function SkinRecruitmentDialog(dialog)
	if not dialog then return end
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
	if not dialog then return end
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
	FlatHighlight(button)
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
	if not dialog then return end
	FadeRegions(dialog)
	FadeKeys(dialog, SELECTOR_KEYS)
	Shell(dialog)
	Skin.TipFaceTree(dialog, 1)
	local selector = dialog.Selector
	if selector then
		Button(selector.OkayButton)
		Button(selector.CancelButton)
	end
	ScrollBar(dialog.ScrollBar)
	Skin.SweepScrollBox(dialog.ScrollBox, GuardEnabled(SkinAvatarRow))
end

local function SkinTicketRow(row)
	if row._buiTicketRow then return end
	row._buiTicketRow = true
	Fade(row.Stripe)
	RowHover(row)
	FaceKeys(row, TICKET_ROW_TEXT)
	Button(row.CopyLinkButton)
	IconButton(row.RevokeButton)
end

local function SkinTicketManager(dialog)
	if not dialog then return end
	KeepTexture(dialog.Icon)
	KeepTexture(dialog.CircleMask)
	FadeRegions(dialog)
	if dialog.CircleMask then dialog.CircleMask:Hide() end
	FrameIcon(dialog, dialog.Icon)
	Shell(dialog)
	Skin.TipFaceTree(dialog, 1)
	Title(dialog.DialogLabel)
	ButtonKeys(dialog, TICKET_BUTTON_KEYS)
	for _, key in ipairs(TICKET_DROPDOWN_KEYS) do Dropdown(dialog[key]) end
	IconButton(dialog.MaximizeButton)
	local manager = dialog.InviteManager
	if not manager then return end
	FadeRegions(manager.ArtOverlay)
	SkinColumnDisplay(manager.ColumnDisplay)
	if manager.ScrollBox then Fade(manager.ScrollBox.Background) end
	ScrollBar(manager.ScrollBar)
	Skin.SweepScrollBox(manager.ScrollBox, GuardEnabled(SkinTicketRow))
end

local function SkinApplicantRow(row)
	if row._buiApplicantRow then return end
	row._buiApplicantRow = true
	Fade(row:GetNormalTexture())
	RowHover(row)
	FaceKeys(row, APPLICANT_ROW_TEXT)
	IconButton(row.CancelInvitationButton)
	local invite = row.InviteButton
	if invite then
		Button(invite)
		Face(invite.Text)
	end
end

local function SkinApplicantList(list)
	if not list then return end
	FadeArt(list.InsetFrame)
	Shell(list)
	SkinColumnDisplay(list.ColumnDisplay)
	ScrollBar(list.ScrollBar)
	Skin.SweepScrollBox(list.ScrollBox, GuardEnabled(SkinApplicantRow))
end

local function SkinRequestSpecs(request)
	if not Enabled() then return end
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
	if request.Initialize then hooksecurefunc(request, 'Initialize', SkinRequestSpecs) end
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
	if not invitation then return end
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
	if not Enabled() then return end
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
	if not cards then return end
	if cards.Cards then
		for _, card in ipairs(cards.Cards) do SkinGuildCard(card) end
	end
	Skin.TipPageButton(cards.PreviousPage, 'previous')
	Skin.TipPageButton(cards.NextPage, 'next')
	if cards.RefreshLayout and not cards._buiLayoutHooked then
		cards._buiLayoutHooked = true
		hooksecurefunc(cards, 'RefreshLayout', RefreshCardPager)
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
	FlatHighlight(card)
	FrameIcon(card, card.CommunityLogo)
	Shell(card)
	Skin.TipFaceTree(card, 1)
	Title(card.Name)
	local join = card.RequestJoin
	if join then Face(join.InvitedString) end
end

local function SkinCommunityCards(cards)
	if not cards then return end
	ScrollBar(cards.ScrollBar)
	Skin.SweepScrollBox(cards.ScrollBox, GuardEnabled(SkinCommunityCard))
end

local function SkinFinderOptions(options)
	if not options then return end
	if options.PendingTextFrame then Title(options.PendingTextFrame.Text) end
	for _, key in ipairs(FINDER_DROPDOWN_KEYS) do LabeledDropdown(options[key]) end
	for _, key in ipairs(FINDER_ROLE_KEYS) do
		local role = options[key]
		if role then SizedCheckBox(role.Checkbox) end
	end
	EditBox(options.SearchBox)
	Button(options.Search)
end

local function SkinFinder(finder)
	if not finder then return end
	SkinFinderOptions(finder.OptionsList)
	for _, key in ipairs(FINDER_CARD_KEYS) do SkinGuildCards(finder[key]) end
	for _, key in ipairs(FINDER_LIST_KEYS) do SkinCommunityCards(finder[key]) end
	SkinRequestToJoin(finder.RequestToJoinFrame)
	local inset = finder.InsetFrame
	if inset then
		FadeArt(inset)
		Skin.TipFace(inset.GuildDescription, 'title')
		Skin.TipFace(inset.ErrorDescription, 'title')
	end
	local disabled = finder.DisabledFrame
	if disabled then
		FadeArt(disabled)
		Skin.TipFace(disabled.Title, 'title', BIG_TITLE_SCALE)
		Skin.TipFace(disabled.Description, 'title')
	end
	local function OnFinderTab() RefreshFinderTabs(finder) end
	for _, key in ipairs(FINDER_TAB_KEYS) do
		local tab = finder[key]
		SkinSideTab(tab, OnFinderTab)
		if tab and tab.SetTab then hooksecurefunc(tab, 'SetTab', OnFinderTab) end
	end
end

local function SkinNameChange(frame)
	if not frame then return end
	FadeRegions(frame)
	Shell(frame)
	Skin.TipFaceTree(frame, 1)
	Title(frame.RenameText)
	Close(frame.CloseButton)
	Button(frame.Button)
	EditBox(frame.EditBox)
end

local function SkinPostingExpiration(expiration)
	if not expiration then return end
	Skin.TipFaceTree(expiration, 1)
	local info = expiration.InfoButton
	if info then
		Fade(info)
		info:EnableMouse(false)
	end
end

local function SkinMaximize(maximize)
	if not maximize then return end
	Skin.TipPageButton(maximize.MaximizeButton, 'expand')
	Skin.TipPageButton(maximize.MinimizeButton, 'condense')
end

local function SkinMainFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	if frame.PortraitOverlay then KeepTexture(frame.PortraitOverlay.CircleMask) end
	FadeRegions(frame.PortraitOverlay)
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	SkinMaximize(frame.MaximizeMinimizeFrame)
	for _, key in ipairs(SIDE_TAB_KEYS) do SkinSideTab(frame[key], RefreshSideTabs) end
	if frame.UpdateCommunitiesTabs and not frame._buiTabsHooked then
		frame._buiTabsHooked = true
		hooksecurefunc(frame, 'UpdateCommunitiesTabs', RefreshSideTabs)
	end
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

local function ApplyCommunities()
	local frame = _G.CommunitiesFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not communitiesSkinned then
		communitiesSkinned = true
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
	RefreshSideTabs()
	RefreshFinderTabs(frame.GuildFinderFrame)
	RefreshFinderTabs(frame.CommunityFinderFrame)
end

local function SkinBankSlot(button)
	if button._buiBankSlot then return end
	button._buiBankSlot = true
	Fade(button:GetNormalTexture())
	Fade(button.IconBorder)
	Fade(button.IconOverlay)
	local icon = button.icon
	if not icon then return end
	local fill = button:CreateTexture(nil, 'BACKGROUND')
	fill.__buiSkin = true
	fill:SetAllPoints(icon)
	local panel = Skin.PANEL_FILL
	FlatTexture(fill, panel[1], panel[2], panel[3], panel[4])
	FrameIcon(button, icon)
end

local function RefreshBankSlots(frame)
	if not Enabled() or frame.mode ~= 'bank' then return end
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
	FlatHighlight(button)
	CropIcon(button.IconTexture)
	Shell(button, BANK_TAB_INSET)
	Face(button.Count)
end

local function RefreshBankTabs(frame)
	if not Enabled() then return end
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
	FlatHighlight(button)
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
	if not popup then return end
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
		Skin.SweepScrollBox(selector.ScrollBox, GuardEnabled(SkinIconCell))
	end
end

local function SkinBankInfo(info)
	if not info then return end
	Button(info.SaveButton)
	local scroll = info.ScrollFrame
	if not scroll then return end
	ScrollBar(scroll.ScrollBar)
	Face(scroll.EditBox or ScrollChild(scroll, 'EditBox'))
end

local function SkinGuildBankFrame(frame)
	Fade(frame.NineSlice)
	FadeRegions(frame)
	FadeRegions(frame.Emblem)
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText or frame.TitleText)
	Close(frame.CloseButton)
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

local function ApplyGuildBank()
	local frame = _G.GuildBankFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not bankSkinned then
		bankSkinned = true
		SkinGuildBankFrame(frame)
	end
	Skin.RefreshTabStrip(frame)
	RefreshBankTabs(frame)
	RefreshBankSlots(frame)
end

local function SkinRankRows()
	if not Enabled() then return end
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
	if not Enabled() then return end
	local rowIndex = 1
	local row = _G['GuildControlBankTab' .. rowIndex]
	while row do
		SkinBankPermissionRow(row)
		rowIndex = rowIndex + 1
		row = _G['GuildControlBankTab' .. rowIndex]
	end
end

local function SkinDiscordPanels()
	if not Enabled() then return end
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
	if not permissions then return end
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

local function ApplyGuildControl()
	local frame = _G.GuildControlUI
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not controlSkinned then
		controlSkinned = true
		SkinGuildControlFrame(frame)
	end
	SkinRankRows()
	SkinBankPermissionRows()
	SkinDiscordPanels()
end

local function InstallCommunities()
	if communitiesInstalled then return end
	local frame = _G.CommunitiesFrame
	if not frame then return end
	communitiesInstalled = true
	HookScript(frame, 'OnShow', ApplyCommunities)
	if frame:IsShown() then ApplyCommunities() end
end

local function InstallGuildBank()
	if bankInstalled then return end
	local frame = _G.GuildBankFrame
	if not frame then return end
	bankInstalled = true
	HookScript(frame, 'OnShow', ApplyGuildBank)
	if frame.Update then hooksecurefunc(frame, 'Update', RefreshBankSlots) end
	if frame.UpdateTabs then hooksecurefunc(frame, 'UpdateTabs', RefreshBankTabs) end
	if frame:IsShown() then ApplyGuildBank() end
end

local function InstallGuildControl()
	if controlInstalled then return end
	local frame = _G.GuildControlUI
	if not frame then return end
	controlInstalled = true
	HookScript(frame, 'OnShow', ApplyGuildControl)
	hooksecurefunc('GuildControlUI_RankOrder_Update', SkinRankRows)
	hooksecurefunc('GuildControlUI_BankTabPermissions_Update', SkinBankPermissionRows)
	hooksecurefunc('GuildControlUI_Discord_Update', SkinDiscordPanels)
	if frame:IsShown() then ApplyGuildControl() end
end

local function Install()
	InstallCommunities()
	InstallGuildBank()
	InstallGuildControl()
	installed = communitiesInstalled and bankInstalled and controlInstalled
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Guild') end
end

local function Deactivate()
	context.Restore()
	for _, tab in ipairs(skinnedSideTabs) do Skin.ResetSideTab(tab) end
	communitiesSkinned = false
	bankSkinned = false
	controlSkinned = false
	BUI.Print('Guild & Communities skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then BUI.Events:Register('ADDON_LOADED', 'Skin.Guild', TryInstall) end
		ApplyCommunities()
		ApplyGuildBank()
		ApplyGuildControl()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Guild & Communities',
	description = 'The Guild & Communities window with its chat, roster, perks, guild info, finder and dialogs; also skins the Guild Bank and Guild Control windows, which only open at a guild vault.',
	icon = 'Interface/Icons/achievement_guildperk_everybodysfriend',
})
