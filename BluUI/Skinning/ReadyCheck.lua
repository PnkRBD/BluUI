local _, BUI = ...

local Wrap = BUI.Profiler.Wrap

local max, min, floor = math.max, math.min, math.floor
local GetTime = GetTime

local BUILib = BluUI.BUILibClient
local Skin = BUI.Skinning

local SCALE_KEY = 'readycheckScale'
local MIN_WIDTH = 240
local MAX_WIDTH = 360
local BUTTON_HEIGHT = 22
local BUTTON_GAP = 8
local ROW_GAP = 10
local FALLBACK_TEXT_HEIGHT = 14

local context = Skin.Define('readycheck', {
	name = 'Ready Check',
	description = 'Ready check prompt drawn like the BluUI tooltip, with a countdown of the time left.',
	icon = 'Interface/RaidFrame/ReadyCheck-Ready',
})
local Fade, FadeRegions, Shell, Button, Own = context.Fade, context.FadeRegions, context.Shell, context.Button, context.Own

local countdownText, countdownTicker, countdownExpiry
local initiatorName
local recoloringPrompt = false

local function ColorInitiator()
	if not initiatorName then return end
	local text = _G.ReadyCheckFrameText
	local current = text:GetText()
	if not current or issecretvalue(current) or current:find('|c', 1, true) then return end
	local red, green, blue = BUI.Tools.GetUnitClassColor(initiatorName)
	if not red then return end
	local pattern = initiatorName:gsub('%W', '%%%0')
	local colored = '|cff' .. BUI.Hex(red, green, blue) .. initiatorName .. '|r'
	local replaced, count = current:gsub(pattern, colored, 1)
	if count == 0 then return end
	recoloringPrompt = true
	text:SetText(replaced)
	recoloringPrompt = false
end

local function CurrentScale()
	return BUI.GetDB().skinning[SCALE_KEY]
end

local function Scaled(value, scale)
	return floor(value * scale + 0.5)
end

local function Even(value)
	return value + value % 2
end

local function StopCountdown()
	if countdownTicker then
		countdownTicker:Cancel()
		countdownTicker = nil
	end
	countdownExpiry = nil
	if countdownText then countdownText:SetText('') end
end

local CountdownTick = Wrap('Skin.ReadyCheck countdown tick', function()
	local remaining = countdownExpiry - GetTime()
	if remaining <= 0 then
		StopCountdown()
		return
	end
	BUILib.Skin.SetCountdownText(countdownText, floor(remaining + 0.5), BUILib.Skin.COUNTDOWN_GREEN_COLOR)
end)

local function StartCountdown(timeLeft)
	StopCountdown()
	if timeLeft <= 0 then return end
	countdownExpiry = GetTime() + timeLeft
	CountdownTick()
	countdownTicker = C_Timer.NewTicker(1, CountdownTick)
end

local function LayoutPrompt()
	local listener = _G.ReadyCheckListenerFrame
	local text = _G.ReadyCheckFrameText
	local scale = CurrentScale()
	local paddingX = Scaled(Skin.TIP_PADDING_X, scale)
	local paddingY = Scaled(Skin.TIP_PADDING_Y, scale)
	local titleBlock = Scaled(Skin.TIP_TITLE_BLOCK, scale)
	local buttonHeight = Scaled(BUTTON_HEIGHT, scale)
	local buttonGap = Scaled(BUTTON_GAP, scale)
	local rowGap = Scaled(ROW_GAP, scale)

	text:SetWidth(0)
	local needed = text:GetStringWidth()
	if issecretvalue(needed) then return end
	local width = Even(max(Scaled(MIN_WIDTH, scale), min(floor(needed + 0.5) + paddingX * 2, Scaled(MAX_WIDTH, scale))))

	local title = listener.TitleContainer.TitleText
	title:ClearAllPoints()
	title:SetPoint('TOPLEFT', listener, 'TOPLEFT', paddingX, -paddingY)
	title:SetJustifyH('LEFT')

	countdownText:ClearAllPoints()
	countdownText:SetPoint('TOPRIGHT', listener, 'TOPRIGHT', -paddingX, -paddingY)

	text:SetWidth(width - paddingX * 2)
	text:SetJustifyH('CENTER')
	text:SetWordWrap(true)
	text:SetNonSpaceWrap(true)
	text:ClearAllPoints()
	text:SetPoint('TOPLEFT', listener, 'TOPLEFT', paddingX, -(paddingY + titleBlock))
	local textHeight = text:GetStringHeight()
	if issecretvalue(textHeight) then textHeight = Scaled(FALLBACK_TEXT_HEIGHT, scale) end

	local yes, no = _G.ReadyCheckFrameYesButton, _G.ReadyCheckFrameNoButton
	local buttonWidth = floor((width - paddingX * 2 - buttonGap) / 2)
	yes:SetSize(buttonWidth, buttonHeight)
	no:SetSize(buttonWidth, buttonHeight)
	yes:ClearAllPoints()
	yes:SetPoint('BOTTOMLEFT', listener, 'BOTTOMLEFT', paddingX, paddingY)
	no:ClearAllPoints()
	no:SetPoint('BOTTOMRIGHT', listener, 'BOTTOMRIGHT', -paddingX, paddingY)

	local height = Even(paddingY + titleBlock + floor(textHeight + 0.5) + rowGap + buttonHeight + paddingY)
	_G.ReadyCheckFrame:SetSize(width, height)
end

local function OnPromptText()
	if recoloringPrompt then return end
	ColorInitiator()
	LayoutPrompt()
end

local function ScaledButton(button, scale)
	Button(button)
	Skin.TipButtonFonts(button, scale)
end

local function SkinPrompt(listener)
	FadeRegions(listener)
	FadeRegions(listener.NineSlice)
	Fade(listener.PortraitContainer)
end

local function RefreshPrompt(listener)
	local scale = CurrentScale()
	Shell(listener)
	Skin.TipTitleLine(listener, scale)
	Skin.TipFont(listener.TitleContainer.TitleText, 'title', scale)
	Skin.TipFont(_G.ReadyCheckFrameText, 'body', scale)
	Skin.TipFont(countdownText, 'body', scale)
	countdownText:SetTextColor(BUILib.Skin.CountdownColor(BUILib.Skin.COUNTDOWN_WARN_SECONDS, BUILib.Skin.COUNTDOWN_GREEN_COLOR))
	ScaledButton(_G.ReadyCheckFrameYesButton, scale)
	ScaledButton(_G.ReadyCheckFrameNoButton, scale)
	ColorInitiator()
	LayoutPrompt()
end

local function OnReadyCheck(_, initiator, timeLeft)
	initiatorName = initiator
	ColorInitiator()
	StartCountdown(timeLeft)
end

local function InstallPrompt(listener)
	countdownText = Own(listener:CreateFontString(nil, 'OVERLAY'))
	Skin.TipFont(countdownText, 'body', CurrentScale())
	countdownText:SetJustifyH('RIGHT')
	listener:HookScript('OnHide', Wrap('Skin.ReadyCheck countdown stop', StopCountdown))
	local text = _G.ReadyCheckFrameText
	context.Hook(text, 'SetText', OnPromptText)
	context.Hook(text, 'SetFormattedText', OnPromptText)
	BUI.Events:Register('READY_CHECK', 'Skin.ReadyCheck', context.Guard(OnReadyCheck))
	BUI.Events:Register('READY_CHECK_FINISHED', 'Skin.ReadyCheck', StopCountdown)
end

local function RefreshShown()
	local listener = _G.ReadyCheckListenerFrame
	if context.Enabled() and listener:IsShown() then RefreshPrompt(listener) end
end

context.Window('ReadyCheckListenerFrame', { skin = SkinPrompt, show = RefreshPrompt, install = InstallPrompt })

context.OnDisable(function()
	StopCountdown()
	local line = _G.ReadyCheckListenerFrame._buiTipLine
	if line then line:Hide() end
end)

context.info.settings = { Skin.ScaleOption(SCALE_KEY, RefreshShown) }
