local _, BUI = ...

local ipairs = ipairs

local BUILib = BluUI.BUILibClient
local Skin = BUI.Skinning
local Painter = BUI.Painter

local INBOX_ROW_COUNT = 7
local ATTACHMENT_COUNT = 16
local BOTTOM_TAB_COUNT = 2
local BODY_FONT_SIZE = 12
local ROW_FILL_ALPHA = 0.03
local MUTED_TEXT_THRESHOLD = 0.6
local HTML_ELEMENTS = { P = 12, H1 = 16, H2 = 14, H3 = 13 }
local MONEY_BOX_KEYS = { 'Gold', 'Silver', 'Copper' }
local RADIO_GAP = 4
local INVOICE_TEXT_NAMES = {
	'OpenMailInvoiceItemLabel', 'OpenMailInvoicePurchaser', 'OpenMailInvoiceSalePrice', 'OpenMailInvoiceDeposit',
	'OpenMailInvoiceHouseCut', 'OpenMailInvoiceAmountReceived', 'OpenMailInvoiceNotYetSent', 'OpenMailInvoiceMoneyDelay',
}
local CONSORTIUM_TEXT_KEYS = { 'OpeningText', 'CrafterText', 'CommissionReceived', 'CrafterNote', 'ConsortiumNote', 'CommissionPaidText' }
local OPEN_MAIL_BUTTONS = { 'OpenMailReportSpamButton', 'OpenMailReplyButton', 'OpenMailDeleteButton', 'OpenMailCancelButton' }

local context = Skin.Define('mail', {
	name = 'Mail',
	description = 'The mailbox: inbox rows, the open-mail letter with its invoice and attachments, and the send-mail form.',
	icon = 'Interface/MailFrame/Mail-Icon',
})
local Hook = context.Hook
local Fade, FadeRegions, FadeArt = context.Fade, context.FadeRegions, context.FadeArt
local Shell, Button, Close, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.EditBox, context.CheckBox
local ScrollBar, Body, Title, Keep, PageButton = context.ScrollBar, context.Body, context.Title, context.Keep, context.PageButton
local FlatTexture, CropIcon = Skin.FlatTexture, Skin.CropIcon

local function SetColor(fontString, role)
	fontString:SetTextColor(Painter.Color(role))
end

local function IsMutedText(fontString)
	local red = fontString:GetTextColor()
	return red < MUTED_TEXT_THRESHOLD
end

local function FadeLayer(frame, layer)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType('Texture') and region:GetDrawLayer() == layer then Fade(region) end
	end
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
	local fill = Keep(row:CreateTexture(nil, 'BACKGROUND'))
	fill:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
	fill:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 2)
	FlatTexture(fill, 1, 1, 1, ROW_FILL_ALPHA)
	local button = row.Button
	Fade(_G[buttonName .. 'Slot'])
	Fade(button.IconOverlay)
	Fade(button.IconOverlay2)
	Fade(_G[buttonName .. 'CODBackground'])
	Skin.SquareIcon(button, button.Icon)
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
	SetColor(sender, wasRead and 'skinLabel' or 'skinTitle')
	SetColor(subject, wasRead and 'skinLabel' or 'skinText')
end

local function RefreshInbox()
	for rowIndex = 1, INBOX_ROW_COUNT do RefreshInboxRow(rowIndex) end
	Skin.RefreshPageButtons(_G.InboxPrevPageButton, _G.InboxNextPageButton)
end

local function SkinAttachment(button)
	if not button or button._buiAttachment then return end
	button._buiAttachment = true
	Fade(button:GetNormalTexture())
	Fade(button.IconOverlay)
	Skin.SquareIcon(button, button.icon)
	Skin.TipCount(button.Count)
end

local function SkinSendAttachment(button)
	if not button then return end
	if not button._buiAttachment then
		button._buiAttachment = true
		FadeLayer(button, 'BACKGROUND')
		Fade(button.IconOverlay)
		Fade(button.IconOverlay2)
		Skin.TipCount(button.Count)
		Skin.TipIconFrame(button, button)
	end
	CropIcon(button:GetNormalTexture())
end

local function SkinPanelFrame(frame)
	FadeArt(frame)
	Fade(frame.PortraitContainer.portrait)
	Shell(frame)
	Title(frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
end

local function SkinBodyHtml(html)
	for element, size in pairs(HTML_ELEMENTS) do
		html:SetFont(element, BUILib.Font, size, '')
		html:SetTextColor(element, Painter.Color('skinText'))
	end
end

local function SkinOpenMail(frame)
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
	SetColor(attachmentText, IsMutedText(attachmentText) and 'skinLabel' or 'skinText')
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
	SetColor(body, 'skinText')
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
	SetColor(codText, IsMutedText(codText) and 'skinLabel' or 'skinText')
	for attachmentIndex = 1, ATTACHMENT_COUNT do SkinSendAttachment(_G['SendMailAttachment' .. attachmentIndex]) end
end

local function SkinMailFrame(frame)
	SkinPanelFrame(frame)
	Fade(_G.InboxFrameBg)
	Body(_G.InboxCurrentPage)
	Body(_G.InboxTooMuchMailText)
	PageButton(_G.InboxPrevPageButton, 'previous')
	PageButton(_G.InboxNextPageButton, 'next')
	Button(_G.OpenAllMail)
	for rowIndex = 1, INBOX_ROW_COUNT do SkinInboxRow(rowIndex) end
	local tabs = {}
	for tabIndex = 1, BOTTOM_TAB_COUNT do tabs[tabIndex] = _G['MailFrameTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
	SkinSendMail(_G.SendMailFrame)
end

local function RefreshMailFrame(frame)
	Skin.RefreshTabStrip(frame)
	RefreshInbox()
	RefreshSendMail()
end

local function InstallMailFrame()
	Hook('InboxFrame_Update', RefreshInbox)
	Hook('OpenMail_Update', RefreshOpenMail)
	Hook('SendMailFrame_Update', RefreshSendMail)
end

context.Window('MailFrame', { skin = SkinMailFrame, show = RefreshMailFrame, install = InstallMailFrame })
context.Window('OpenMailFrame', { skin = SkinOpenMail, show = RefreshOpenMail })
