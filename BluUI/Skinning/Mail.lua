local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Mail')

local hooksecurefunc = BUI.Prof.MakeHooker('mail')
local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'mail'
local INBOX_ROW_COUNT = 7
local ATTACHMENT_COUNT = 16
local BOTTOM_TAB_COUNT = 2
local BODY_FONT_SIZE = 12
local ROW_FILL_ALPHA = 0.03
local ROW_TITLE_COLOR = { 0.9, 0.9, 0.93, 1 }
local ROW_BODY_COLOR = { 0.87, 0.87, 0.9, 1 }
local ROW_READ_COLOR = { 0.55, 0.55, 0.6, 1 }
local MUTED_TEXT_THRESHOLD = 0.6
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'Inset' }
local HTML_ELEMENTS = { P = 12, H1 = 16, H2 = 14, H3 = 13 }
local MONEY_BOX_KEYS = { 'Gold', 'Silver', 'Copper' }
local RADIO_GAP = 4
local INVOICE_TEXT_NAMES = {
	'OpenMailInvoiceItemLabel', 'OpenMailInvoicePurchaser', 'OpenMailInvoiceSalePrice', 'OpenMailInvoiceDeposit',
	'OpenMailInvoiceHouseCut', 'OpenMailInvoiceAmountReceived', 'OpenMailInvoiceNotYetSent', 'OpenMailInvoiceMoneyDelay',
}
local CONSORTIUM_TEXT_KEYS = { 'OpeningText', 'CrafterText', 'CommissionReceived', 'CrafterNote', 'ConsortiumNote', 'CommissionPaidText' }
local OPEN_MAIL_BUTTONS = { 'OpenMailReportSpamButton', 'OpenMailReplyButton', 'OpenMailDeleteButton', 'OpenMailCancelButton' }

local installed = false
local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.EditBox, context.CheckBox
local ScrollBar, Body, Title = context.ScrollBar, context.Body, context.Title
local FlatTexture, CropIcon = Skin.FlatTexture, Skin.CropIcon

local function SetColor(fontString, color)
	if fontString then fontString:SetTextColor(color[1], color[2], color[3], color[4]) end
end

local function IsMutedText(fontString)
	local red = fontString:GetTextColor()
	return red < MUTED_TEXT_THRESHOLD
end

local function FadeLayer(frame, layer)
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region:IsObjectType('Texture') and region:GetDrawLayer() == layer then Fade(region) end
	end
end

local function BodyRegions(frame)
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region:IsObjectType('FontString') then Body(region) end
	end
end

local function SkinPageButton(button, direction)
	if not button or button._buiMailPage then return end
	button._buiMailPage = true
	Skin.TipPageButton(button, direction)
	BodyRegions(button)
end

local function InboxRowParts(rowIndex)
	local name = 'MailItem' .. rowIndex
	return _G[name], _G[name .. 'Sender'], _G[name .. 'Subject'], _G[name .. 'ExpireTime'], name .. 'Button'
end

local function SkinInboxRow(rowIndex)
	local row, sender, subject, expire, buttonName = InboxRowParts(rowIndex)
	if not row or row._buiMailRow then return end
	row._buiMailRow = true
	FadeRegions(row)
	local fill = row:CreateTexture(nil, 'BACKGROUND')
	fill.__buiSkin = true
	fill:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
	fill:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 2)
	FlatTexture(fill, 1, 1, 1, ROW_FILL_ALPHA)
	local button = row.Button
	Fade(_G[buttonName .. 'Slot'])
	Fade(button.IconOverlay)
	Fade(button.IconOverlay2)
	Fade(_G[buttonName .. 'CODBackground'])
	CropIcon(button.Icon)
	Skin.TipIconFrame(button, button.Icon)
	Body(_G[buttonName .. 'Count'])
	Body(_G[buttonName .. 'COD'])
	Skin.TipFace(sender, 'title')
	Skin.TipFace(subject, 'body')
	Skin.TipFace(expire:GetFontString(), 'body')
end

local function RefreshInboxRow(rowIndex)
	local row, sender, subject = InboxRowParts(rowIndex)
	if not row or not row._buiMailRow or not row.Button:IsShown() then return end
	local mailIndex = (_G.InboxFrame.pageNum - 1) * INBOX_ROW_COUNT + rowIndex
	local wasRead = select(9, GetInboxHeaderInfo(mailIndex))
	SetColor(sender, wasRead and ROW_READ_COLOR or ROW_TITLE_COLOR)
	SetColor(subject, wasRead and ROW_READ_COLOR or ROW_BODY_COLOR)
end

local function RefreshInbox()
	for rowIndex = 1, INBOX_ROW_COUNT do RefreshInboxRow(rowIndex) end
	Skin.RefreshPageButton(_G.InboxPrevPageButton)
	Skin.RefreshPageButton(_G.InboxNextPageButton)
end

local function SkinAttachment(button)
	if not button or button._buiAttachment then return end
	button._buiAttachment = true
	Fade(button:GetNormalTexture())
	Fade(button.IconOverlay)
	CropIcon(button.icon)
	Skin.TipIconFrame(button, button.icon)
	Body(button.Count)
end

local function SkinSendAttachment(button)
	if not button then return end
	if not button._buiAttachment then
		button._buiAttachment = true
		FadeLayer(button, 'BACKGROUND')
		Fade(button.IconOverlay)
		Fade(button.IconOverlay2)
		Body(button.Count)
		Skin.TipIconFrame(button, button)
	end
	CropIcon(button.icon or button:GetNormalTexture())
end

local function SkinPanelFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
end

local function SkinBodyHtml(html)
	for element, size in pairs(HTML_ELEMENTS) do
		html:SetFont(element, BUILib.Font, size, '')
		html:SetTextColor(element, ROW_BODY_COLOR[1], ROW_BODY_COLOR[2], ROW_BODY_COLOR[3])
	end
end

local function SkinOpenMail(frame)
	if not frame then return end
	FadeRegions(frame)
	SkinPanelFrame(frame)
	Skin.TipFont(_G.OpenMailSenderLabel, 'label')
	Skin.TipFont(_G.OpenMailSubjectLabel, 'label')
	Body(_G.OpenMailSubject)
	Title(_G.OpenMailSender.Name)
	Body(_G.OpenMailAttachmentText)
	for _, name in ipairs(OPEN_MAIL_BUTTONS) do Button(_G[name]) end
	Fade(_G.OpenStationeryBackgroundLeft)
	Fade(_G.OpenStationeryBackgroundRight)
	local scroll = _G.OpenMailScrollFrame
	Shell(scroll)
	ScrollBar(scroll.ScrollBar)
	SkinBodyHtml(_G.OpenMailBodyText)
	for _, name in ipairs(INVOICE_TEXT_NAMES) do Body(_G[name]) end
	local consortium = _G.ConsortiumMailFrame
	for _, key in ipairs(CONSORTIUM_TEXT_KEYS) do Body(consortium[key]) end
	SkinAttachment(_G.OpenMailLetterButton)
	SkinAttachment(_G.OpenMailMoneyButton)
	for attachmentIndex = 1, ATTACHMENT_COUNT do SkinAttachment(_G['OpenMailAttachmentButton' .. attachmentIndex]) end
end

local function RefreshOpenMail()
	local attachmentText = _G.OpenMailAttachmentText
	SetColor(attachmentText, IsMutedText(attachmentText) and ROW_READ_COLOR or ROW_BODY_COLOR)
end

local function SkinSendMail(frame)
	FadeRegions(frame)
	Fade(_G.SendStationeryBackgroundLeft)
	Fade(_G.SendStationeryBackgroundRight)
	EditBox(_G.SendMailNameEditBox)
	EditBox(_G.SendMailSubjectEditBox)
	local scroll = _G.SendMailScrollFrame
	Shell(scroll)
	ScrollBar(scroll.ScrollBar)
	local body = _G.SendMailBodyEditBox
	body:SetFont(BUILib.Font, BODY_FONT_SIZE, '')
	SetColor(body, ROW_BODY_COLOR)
	Skin.TipFont(_G.SendMailMoneyText, 'label')
	local sendMoney, cod = _G.SendMailSendMoneyButton, _G.SendMailCODButton
	CheckBox(sendMoney, 0)
	CheckBox(cod, 0)
	cod:ClearAllPoints()
	cod:SetPoint('TOPLEFT', sendMoney, 'BOTTOMLEFT', 0, -RADIO_GAP)
	for _, key in ipairs(MONEY_BOX_KEYS) do EditBox(_G['SendMailMoney' .. key]) end
	local inset = _G.SendMailMoneyInset
	FadeRegions(inset)
	Fade(inset.NineSlice)
	FadeRegions(_G.SendMailMoneyBg)
	Button(_G.SendMailMailButton)
	Button(_G.SendMailCancelButton)
	for attachmentIndex = 1, ATTACHMENT_COUNT do SkinSendAttachment(_G['SendMailAttachment' .. attachmentIndex]) end
end

local function RefreshSendMail()
	local codText = _G.SendMailCODButtonText
	SetColor(codText, IsMutedText(codText) and ROW_READ_COLOR or ROW_BODY_COLOR)
	for attachmentIndex = 1, ATTACHMENT_COUNT do SkinSendAttachment(_G['SendMailAttachment' .. attachmentIndex]) end
end

local function SkinMailFrame(frame)
	SkinPanelFrame(frame)
	Fade(_G.InboxFrameBg)
	Body(_G.InboxCurrentPage)
	Body(_G.InboxTooMuchMailText)
	SkinPageButton(_G.InboxPrevPageButton, 'previous')
	SkinPageButton(_G.InboxNextPageButton, 'next')
	Button(_G.OpenAllMail)
	for rowIndex = 1, INBOX_ROW_COUNT do SkinInboxRow(rowIndex) end
	local tabs = {}
	for tabIndex = 1, BOTTOM_TAB_COUNT do tabs[tabIndex] = _G['MailFrameTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
	SkinSendMail(_G.SendMailFrame)
end

local function Apply()
	local frame = _G.MailFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMailFrame(frame)
		SkinOpenMail(_G.OpenMailFrame)
	end
	Skin.RefreshTabStrip(frame)
	RefreshInbox()
	RefreshOpenMail()
	RefreshSendMail()
end

local function OnInboxUpdated()
	if Enabled() and skinned then RefreshInbox() end
end

local function OnOpenMailUpdated()
	if Enabled() and skinned then RefreshOpenMail() end
end

local function OnSendMailUpdated()
	if Enabled() and skinned then RefreshSendMail() end
end

local function Install()
	if installed then return end
	local frame = _G.MailFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	HookScript(_G.OpenMailFrame, 'OnShow', Apply)
	hooksecurefunc('InboxFrame_Update', OnInboxUpdated)
	hooksecurefunc('OpenMail_Update', OnOpenMailUpdated)
	hooksecurefunc('SendMailFrame_Update', OnSendMailUpdated)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Mail') end
end

local function Deactivate()
	context.Restore()
	skinned = false
	BUI.Print('Mail skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Mail', TryInstall)
		elseif _G.MailFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Mail',
	description = 'The mailbox: inbox rows, the open-mail letter with its invoice and attachments, and the send-mail form.',
	icon = 'Interface/MailFrame/Mail-Icon',
})
