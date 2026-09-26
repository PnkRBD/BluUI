local _, BUI = ...

local ipairs, unpack = ipairs, unpack
local floor, max = math.floor, math.max

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'guildinvite'
local WIDTH = 320
local TABARD = 62
local TEXT_GAP = 12
local LINE_GAP = 4
local POINTS_GAP = 6
local BLOCK_GAP = 10
local ROW_GAP = 12
local BUTTON_HEIGHT = 22
local BUTTON_GAP = 8
local SHIELD = 18
local INVITE_SECONDS = 60
local PREVIEW_OFFSET_Y = -140
local WARNING_COLOR = { 0.94, 0.62, 0.42, 1 }
local KEEP_TEXTURES = { 'GuildInviteFrameTabardBackground', 'GuildInviteFrameTabardBorder', 'GuildInviteFrameTabardEmblem' }
local PREVIEW_GUILD = 'Sample Guild'
local PREVIEW_OLD_GUILD = 'Your Old Guild'
local PREVIEW_POINTS = '120'

local title, countdown, countdownTicker

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local FadeArt, Shell, Button = context.FadeArt, context.Shell, context.Button

local function Frame()
	return _G.GuildInviteFrame
end

local function Height(fontString)
	return floor(fontString:GetStringHeight() + 0.5)
end

local function StopCountdown()
	if countdownTicker then
		countdownTicker:Cancel()
		countdownTicker = nil
	end
	if countdown then countdown:SetText('') end
end

local function TickCountdown()
	local remaining = INVITE_SECONDS - Frame().elapsed
	if remaining <= 0 then
		StopCountdown()
		return
	end
	BUILib.Skin.SetCountdownText(countdown, floor(remaining + 0.5))
end

local function StartCountdown()
	StopCountdown()
	TickCountdown()
	countdownTicker = C_Timer.NewTicker(1, TickCountdown)
end

local function Layout(frame)
	local paddingX, paddingY = Skin.TIP_PADDING_X, Skin.TIP_PADDING_Y
	local top = paddingY + Skin.TIP_TITLE_BLOCK
	local textX = paddingX + TABARD + TEXT_GAP
	local textWidth = WIDTH - textX - paddingX

	local tabard = _G.GuildInviteFrameTabardBackground
	tabard:ClearAllPoints()
	tabard:SetPoint('TOPLEFT', frame, 'TOPLEFT', paddingX, -top)

	local inviter, invite, guild = _G.GuildInviteFrameInviterName, _G.GuildInviteFrameInviteText, _G.GuildInviteFrameGuildName
	for _, text in ipairs({ inviter, invite, guild }) do
		text:ClearAllPoints()
		text:SetSize(textWidth, 0)
		text:SetJustifyH('LEFT')
		text:SetWordWrap(false)
	end
	inviter:SetPoint('TOPLEFT', frame, 'TOPLEFT', textX, -top)
	invite:SetPoint('TOPLEFT', inviter, 'BOTTOMLEFT', 0, -LINE_GAP)
	guild:SetPoint('TOPLEFT', invite, 'BOTTOMLEFT', 0, -LINE_GAP)
	guild:SetTextColor(BUILib.Theme.GetAccent())

	local points = frame.Points
	points:ClearAllPoints()
	points:SetPoint('TOPLEFT', guild, 'BOTTOMLEFT', 0, -POINTS_GAP)
	points:SetSize(textWidth, SHIELD)
	points.Title:ClearAllPoints()
	points.Title:SetPoint('LEFT', points, 'LEFT', 0, 0)
	points.Text:ClearAllPoints()
	points.Text:SetHeight(0)
	points.Text:SetPoint('LEFT', points.Title, 'RIGHT', 6, 0)
	points.Icon:ClearAllPoints()
	points.Icon:SetSize(SHIELD, SHIELD)
	points.Icon:SetPoint('LEFT', points.Text, 'RIGHT', 4, 0)

	local blockHeight = max(TABARD, Height(inviter) + LINE_GAP + Height(invite) + LINE_GAP + Height(guild) + POINTS_GAP + SHIELD)

	local warning = _G.GuildInviteFrameWarningText
	warning:ClearAllPoints()
	warning:SetPoint('TOPLEFT', frame, 'TOPLEFT', paddingX, -(top + blockHeight + BLOCK_GAP))
	warning:SetSize(WIDTH - paddingX * 2, 0)
	warning:SetJustifyH('LEFT')
	warning:SetWordWrap(true)
	local warningText = warning:GetText()
	local warningHeight = (warningText and warningText ~= '') and (BLOCK_GAP + Height(warning)) or 0

	local join, decline = _G.GuildInviteFrameJoinButton, _G.GuildInviteFrameDeclineButton
	local buttonWidth = floor((WIDTH - paddingX * 2 - BUTTON_GAP) / 2)
	join:SetSize(buttonWidth, BUTTON_HEIGHT)
	join:ClearAllPoints()
	join:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', paddingX, paddingY)
	decline:SetSize(buttonWidth, BUTTON_HEIGHT)
	decline:ClearAllPoints()
	decline:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -paddingX, paddingY)

	frame:SetSize(WIDTH, top + blockHeight + warningHeight + ROW_GAP + BUTTON_HEIGHT + paddingY)
end

local function OnShow()
	if not Enabled() then return end
	Layout(Frame())
	StartCountdown()
end

local function OnEvent(_, event)
	if event == 'GUILD_INVITE_REQUEST' and Enabled() then Layout(Frame()) end
end

local function Apply()
	if not Enabled() then return end
	local frame = Frame()
	if not frame._buiGuildInvite then
		frame._buiGuildInvite = true
		for _, name in ipairs(KEEP_TEXTURES) do _G[name].__buiSkin = true end
		FadeArt(frame)
		title = frame:CreateFontString(nil, 'OVERLAY')
		title:SetPoint('TOPLEFT', frame, 'TOPLEFT', Skin.TIP_PADDING_X, -Skin.TIP_PADDING_Y)
		title:SetText('Guild invitation')
		countdown = frame:CreateFontString(nil, 'OVERLAY')
		countdown:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -Skin.TIP_PADDING_X, -Skin.TIP_PADDING_Y)
		countdown:SetJustifyH('RIGHT')
		frame:HookScript('OnShow', OnShow)
		frame:HookScript('OnHide', StopCountdown)
		frame:HookScript('OnEvent', OnEvent)
	end
	title:Show()
	countdown:Show()
	Shell(frame)
	Skin.TipTitleLine(frame)
	Skin.TipFont(title, 'title')
	Skin.TipFont(countdown, 'body')
	Skin.TipFont(_G.GuildInviteFrameInviterName, 'body')
	Skin.TipFont(_G.GuildInviteFrameInviteText, 'label')
	Skin.TipFont(_G.GuildInviteFrameGuildName, 'title')
	Skin.TipFont(frame.Points.Title, 'label')
	Skin.TipFont(frame.Points.Text, 'body')
	Skin.TipFont(_G.GuildInviteFrameWarningText, 'body')
	_G.GuildInviteFrameWarningText:SetTextColor(unpack(WARNING_COLOR))
	Button(_G.GuildInviteFrameJoinButton)
	Button(_G.GuildInviteFrameDeclineButton)
	Layout(frame)
	if frame:IsShown() then StartCountdown() end
end

local function Deactivate()
	StopCountdown()
	context.Restore()
	local frame = Frame()
	if frame._buiTipLine then frame._buiTipLine:Hide() end
	if title then
		title:Hide()
		countdown:Hide()
	end
	BUI.Print('Guild invite skin disabled. /reload for a full visual reset.')
end

local function StartPreview()
	local frame = Frame()
	local player = UnitName('player')
	_G.GuildInviteFrameInviterName:SetText(player)
	_G.GuildInviteFrameGuildName:SetText(PREVIEW_GUILD)
	frame.Points.Text:SetText(PREVIEW_POINTS)
	_G.GuildInviteFrameWarningText:SetFormattedText(GUILD_REPUTATION_WARNING, PREVIEW_OLD_GUILD)
	SetLargeGuildTabardTextures('player', _G.GuildInviteFrameTabardEmblem, _G.GuildInviteFrameTabardBackground, _G.GuildInviteFrameTabardBorder)
	frame.inviter = player
	frame.accepted = true
	frame.elapsed = 0
	frame:ClearAllPoints()
	frame:SetPoint('TOP', UIParent, 'TOP', 0, PREVIEW_OFFSET_Y)
	frame:Show()
	return frame
end

local function StopPreview()
	Frame():Hide()
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Apply()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Guild Invite',
	description = 'The guild invitation prompt in the dark shell: tabard, guild name in your accent colour, achievement points and the reputation warning laid out cleanly, flat buttons, and a countdown until the invite expires.',
	icon = 'Interface/Icons/INV_Shirt_GuildTabard_01',
	test = StartPreview,
	stopTest = StopPreview,
})
