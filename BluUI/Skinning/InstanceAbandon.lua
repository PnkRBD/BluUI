local _, BUI = ...

local Wrap = BUI.Profiler.Wrap

local ipairs = ipairs
local floor = math.floor

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local PREVIEW_DIALOG = 'BUI_INSTANCE_ABANDON_PREVIEW'
local PREVIEW_DURATION = 60
local PREVIEW_TIME_LEFT = 42
local PREVIEW_VOTES = 2
local PREVIEW_VOTES_NEEDED = 4
local VOTED_ATLAS = 'ui-lfg-roleicon-generic'
local WAITING_ATLAS = 'UI-LFG-RoleIcon-Generic-Disabled'
local BAR_HEIGHT = 2
local BAR_GAP = 4
local FILL_INSET = 4
local TRACK_SUBLEVEL = -7
local BLIZZARD_BAR_INSET = 4
local BLIZZARD_BAR_HEIGHT = 18
local BLIZZARD_FILL_HEIGHT = 11
local BLIZZARD_FILL_ATLAS = 'ui-frame-lfg-progressbar-fill-green'

local context = Skin.Define('instanceabandon', {
	name = 'Abandon Instance Vote',
	description = 'The vote to abandon a dungeon, with a countdown by the title and a white timer line under it.',
	icon = 'Interface/Icons/INV_Misc_Key_03',
	newLook = true,
})
local Fade, Shell, Button = context.Fade, context.Shell, context.Button
local Title, Body, Face = context.Title, context.Body, context.Face

local countdown, countdownTicker

local function Dialog()
	return _G.InstanceAbandonPopup
end

local function StopCountdown()
	if countdownTicker then
		countdownTicker:Cancel()
		countdownTicker = nil
	end
	countdown:SetText('')
end

local TickCountdown = Wrap('Skin.InstanceAbandon countdown tick', function()
	local remaining = Dialog().timeleft
	if remaining <= 0 then
		StopCountdown()
		return
	end
	BUILib.Skin.SetCountdownText(countdown, floor(remaining + 0.5))
end)

local function StartCountdown()
	StopCountdown()
	if Dialog().timeleft <= 0 then return end
	TickCountdown()
	countdownTicker = C_Timer.NewTicker(1, TickCountdown)
end

local function FitTitle(frame)
	frame.Text:SetWidth(frame:GetWidth() - Skin.TIP_PADDING_X * 2)
	frame:Layout()
end

local function OnRefresh(votes)
	Body(votes.VoteText)
	local dialog = Dialog()
	if dialog:IsShown() then dialog:Layout() end
end

local function OnProgressBarTime(dialog)
	if dialog == Dialog() then StartCountdown() end
end

local function SkinPopup(frame)
	Fade(frame.BG)
	Fade(frame.ProgressBarBorder)
	Shell(frame)
	Button(frame.ButtonContainer.Button1)
	Button(frame.ButtonContainer.Button2)
	Title(frame.Text)
	frame.Text:SetJustifyH('LEFT')
	local votes = _G.InstanceAbandonFrame
	Body(votes.VoteText)
	Body(votes.ResponseText)
	BUI.Painter.Text(votes.ResponseText, 'skinTitle')
	local border, fill = frame.ProgressBarBorder, frame.ProgressBarFill
	border:ClearAllPoints()
	border:SetPoint('TOPLEFT', frame.Text, 'BOTTOMLEFT', -FILL_INSET, -BAR_GAP)
	border:SetPoint('TOPRIGHT', frame.Text, 'BOTTOMRIGHT', FILL_INSET, -BAR_GAP)
	border:SetHeight(BAR_HEIGHT)
	fill:SetHeight(BAR_HEIGHT)
	Skin.SelectedTexture(fill, 1)
	FitTitle(frame)
end

local function InstallPopup(frame)
	countdown = context.Own(frame:CreateFontString(nil, 'OVERLAY'))
	countdown.ignoreInLayout = true
	countdown:SetPoint('TOPRIGHT', frame.Text, 'TOPRIGHT')
	Face(countdown)
	local track = context.Own(frame:CreateTexture(nil, 'BACKGROUND', nil, TRACK_SUBLEVEL))
	track.ignoreInLayout = true
	track:SetPoint('LEFT', frame.ProgressBarBorder, 'LEFT', FILL_INSET, 0)
	track:SetPoint('RIGHT', frame.ProgressBarBorder, 'RIGHT', -FILL_INSET, 0)
	track:SetHeight(BAR_HEIGHT)
	BUI.Painter.Fill(track, 'skinLine')
	frame:HookScript('OnHide', Wrap('Skin.InstanceAbandon countdown stop', StopCountdown))
	context.Hook(frame, 'Resize', FitTitle)
	context.Hook(_G.InstanceAbandonFrame, 'Refresh', OnRefresh)
	context.Hook('StaticPopup_SetProgressBarTime', OnProgressBarTime)
end

context.Window('InstanceAbandonPopup', { skin = SkinPopup, show = StartCountdown, install = InstallPopup })

context.OnDisable(function()
	if not countdown then return end
	StopCountdown()
	local dialog = Dialog()
	dialog.Text:SetJustifyH('CENTER')
	local border, fill = dialog.ProgressBarBorder, dialog.ProgressBarFill
	border:ClearAllPoints()
	border:SetPoint('BOTTOMLEFT', dialog, 'BOTTOMLEFT', BLIZZARD_BAR_INSET, BLIZZARD_BAR_INSET)
	border:SetPoint('BOTTOMRIGHT', dialog, 'BOTTOMRIGHT', -BLIZZARD_BAR_INSET, BLIZZARD_BAR_INSET)
	border:SetHeight(BLIZZARD_BAR_HEIGHT)
	fill:SetHeight(BLIZZARD_FILL_HEIGHT)
	fill:SetAtlas(BLIZZARD_FILL_ATLAS)
end)

StaticPopupDialogs[PREVIEW_DIALOG] = {
	text = VOTE_TO_ABANDON_PROMPT,
	button1 = YES,
	button2 = NO,
	whileDead = 1,
	hideOnEscape = 1,
	progressBar = 1,
	GetReservedDialogFrame = Dialog,
}

context.info.test = function()
	local votes = _G.InstanceAbandonFrame
	votes:Show()
	local dialog = StaticPopup_Show(PREVIEW_DIALOG, nil, nil, nil, votes)
	if not dialog then return end
	votes.VoteText:SetFormattedText(VOTE_TO_ABANDON_VOTES_NEEDED, PREVIEW_VOTES_NEEDED)
	for index, texture in ipairs(votes.StatusFrame.textures) do
		texture:SetAtlas(index <= PREVIEW_VOTES and VOTED_ATLAS or WAITING_ATLAS)
	end
	dialog:Layout()
	StaticPopup_SetProgressBarTime(dialog, PREVIEW_DURATION, PREVIEW_TIME_LEFT)
	return dialog
end

context.info.stopTest = function()
	StaticPopup_Hide(PREVIEW_DIALOG)
end
