local _, BUI = ...

local ipairs = ipairs
local floor = math.floor

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'instanceabandon'
local PREVIEW_DIALOG = 'BUI_INSTANCE_ABANDON_PREVIEW'
local PREVIEW_DURATION = 60
local PREVIEW_TIME_LEFT = 42
local PREVIEW_VOTES = 2
local PREVIEW_VOTES_NEEDED = 4
local BAR_HEIGHT = 6
local FILL_INSET = 4
local TRACK_ALPHA = 0.5
local VOTED_ATLAS = 'ui-lfg-roleicon-generic'
local WAITING_ATLAS = 'UI-LFG-RoleIcon-Generic-Disabled'
local BLIZZARD_BAR_INSET = 4
local BLIZZARD_BAR_HEIGHT = 18
local BLIZZARD_FILL_HEIGHT = 11
local BLIZZARD_FILL_ATLAS = 'ui-frame-lfg-progressbar-fill-green'

local countdown, countdownTicker, track

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, Shell, Button = context.Fade, context.Shell, context.Button

local function Dialog()
	return _G.InstanceAbandonPopup
end

local function Votes()
	return _G.InstanceAbandonFrame
end

local function StopCountdown()
	if countdownTicker then
		countdownTicker:Cancel()
		countdownTicker = nil
	end
	if countdown then countdown:SetText('') end
end

local function TickCountdown()
	local remaining = Dialog().timeleft
	if not remaining or remaining <= 0 then
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

local function StyleText(dialog)
	Skin.TipFont(dialog.Text, 'title')
	Skin.TipFont(countdown, 'body')
	local votes = Votes()
	Skin.TipFont(votes.VoteText, 'body')
	Skin.TipFont(votes.ResponseText, 'body')
	votes.ResponseText:SetTextColor(BUILib.Theme.GetAccent())
end

local function LayoutBar(dialog)
	local border, fill = dialog.ProgressBarBorder, dialog.ProgressBarFill
	local insetX = Skin.TIP_PADDING_X - FILL_INSET
	border:ClearAllPoints()
	border:SetPoint('BOTTOMLEFT', dialog, 'BOTTOMLEFT', insetX, Skin.TIP_PADDING_Y)
	border:SetPoint('BOTTOMRIGHT', dialog, 'BOTTOMRIGHT', -insetX, Skin.TIP_PADDING_Y)
	border:SetHeight(BAR_HEIGHT)
	fill:SetHeight(BAR_HEIGHT)
	fill:SetTexture(BUI.GetGlobalTexture())
	fill:SetVertexColor(BUILib.Theme.GetAccent())
	track:SetShown(border:IsShown())
end

local function OnRefresh(votes)
	if not Enabled() then return end
	local dialog = Dialog()
	StyleText(dialog)
	votes:Layout()
	if dialog:IsShown() then dialog:Layout() end
end

local function OnShow(dialog)
	if not Enabled() then return end
	StyleText(dialog)
	LayoutBar(dialog)
end

local function OnProgressBarTime(dialog)
	if dialog == Dialog() and Enabled() then StartCountdown() end
end

local function Apply()
	if not Enabled() then return end
	local dialog = Dialog()
	if not dialog._buiAbandon then
		dialog._buiAbandon = true
		countdown = dialog:CreateFontString(nil, 'OVERLAY')
		countdown.ignoreInLayout = true
		countdown:SetPoint('TOPRIGHT', dialog, 'TOPRIGHT', -Skin.TIP_PADDING_X, -Skin.TIP_PADDING_Y)
		countdown:SetJustifyH('RIGHT')
		track = dialog:CreateTexture(nil, 'BACKGROUND', nil, -7)
		track.__buiSkin = true
		track.ignoreInLayout = true
		track:SetPoint('LEFT', dialog.ProgressBarBorder, 'LEFT', FILL_INSET, 0)
		track:SetPoint('RIGHT', dialog.ProgressBarBorder, 'RIGHT', -FILL_INSET, 0)
		track:SetHeight(BAR_HEIGHT)
		track:SetColorTexture(0, 0, 0, TRACK_ALPHA)
		dialog:HookScript('OnShow', OnShow)
		dialog:HookScript('OnHide', StopCountdown)
		hooksecurefunc(Votes(), 'Refresh', OnRefresh)
		hooksecurefunc('StaticPopup_SetProgressBarTime', OnProgressBarTime)
	end
	Fade(dialog.BG)
	Fade(dialog.ProgressBarBorder)
	Shell(dialog)
	Button(dialog.ButtonContainer.Button1)
	Button(dialog.ButtonContainer.Button2)
	countdown:Show()
	StyleText(dialog)
	LayoutBar(dialog)
	if dialog:IsShown() then StartCountdown() end
end

local function Deactivate()
	StopCountdown()
	context.Restore()
	local dialog = Dialog()
	if not dialog._buiAbandon then return end
	countdown:Hide()
	track:Hide()
	local border, fill = dialog.ProgressBarBorder, dialog.ProgressBarFill
	border:ClearAllPoints()
	border:SetPoint('BOTTOMLEFT', dialog, 'BOTTOMLEFT', BLIZZARD_BAR_INSET, BLIZZARD_BAR_INSET)
	border:SetPoint('BOTTOMRIGHT', dialog, 'BOTTOMRIGHT', -BLIZZARD_BAR_INSET, BLIZZARD_BAR_INSET)
	border:SetHeight(BLIZZARD_BAR_HEIGHT)
	fill:SetHeight(BLIZZARD_FILL_HEIGHT)
	fill:SetAtlas(BLIZZARD_FILL_ATLAS)
	fill:SetVertexColor(1, 1, 1)
	BUI.Print('Abandon vote skin disabled. /reload for a full visual reset.')
end

StaticPopupDialogs[PREVIEW_DIALOG] = {
	text = VOTE_TO_ABANDON_PROMPT,
	button1 = YES,
	button2 = NO,
	whileDead = 1,
	hideOnEscape = 1,
	progressBar = 1,
	GetReservedDialogFrame = Dialog,
}

local function StartPreview()
	local votes = Votes()
	votes:Show()
	local dialog = StaticPopup_Show(PREVIEW_DIALOG, nil, nil, nil, votes)
	if not dialog then return end
	votes.VoteText:SetFormattedText(VOTE_TO_ABANDON_VOTES_NEEDED, PREVIEW_VOTES_NEEDED)
	for index, texture in ipairs(votes.StatusFrame.textures) do
		texture:SetAtlas(index <= PREVIEW_VOTES and VOTED_ATLAS or WAITING_ATLAS)
	end
	votes:Layout()
	dialog:Layout()
	StaticPopup_SetProgressBarTime(dialog, PREVIEW_DURATION, PREVIEW_TIME_LEFT)
	return dialog
end

local function StopPreview()
	StaticPopup_Hide(PREVIEW_DIALOG)
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Apply()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Abandon Instance Vote',
	description = 'The group vote to abandon a dungeon in the dark shell: the vote icons stay, the timer becomes a slim accent bar with a countdown, and the buttons go flat.',
	icon = 'Interface/Icons/INV_Misc_Key_03',
	test = StartPreview,
	stopTest = StopPreview,
})
