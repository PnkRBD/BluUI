local _, BUI = ...

local select, max, min, floor = select, math.max, math.min, math.floor
local GetTime = GetTime

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'readycheck'
local SCALE_KEY = 'readycheckScale'
local MIN_WIDTH = 240
local MAX_WIDTH = 360
local BUTTON_HEIGHT = 22
local BUTTON_GAP = 8
local ROW_GAP = 10

local installed = false
local fadedArt = {}
local countdownText, countdownTicker, countdownExpiry
local initiatorName
local recoloringPrompt = false

local function ColorInitiator()
	local text = _G.ReadyCheckFrameText
	if not text or not initiatorName then return end
	local current = text:GetText()
	if not current or BUI.Tools.IsSecretValue(current) or current:find('|c', 1, true) then return end
	local red, green, blue = BUI.Tools.GetUnitClassColor(initiatorName)
	if not red then return end
	local pattern = initiatorName:gsub('%W', '%%%0')
	local colored = ('|cff%02x%02x%02x%s|r'):format(floor(red * 255 + 0.5), floor(green * 255 + 0.5), floor(blue * 255 + 0.5), initiatorName)
	local replaced, count = current:gsub(pattern, colored, 1)
	if count == 0 then return end
	recoloringPrompt = true
	text:SetText(replaced)
	recoloringPrompt = false
end

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local function CurrentScale()
	return BUI.GetDB().skinning[SCALE_KEY]
end

local function Scaled(value, scale)
	return floor(value * scale + 0.5)
end

local function Buttons()
	return _G.ReadyCheckFrameYesButton, _G.ReadyCheckFrameNoButton
end

local function FadeTextures(frame)
	if not frame or not frame.GetRegions then return end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region and region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then
			fadedArt[region] = true
			region:SetAlpha(0)
		end
	end
end

local function StopCountdown()
	if countdownTicker then
		countdownTicker:Cancel()
		countdownTicker = nil
	end
	countdownExpiry = nil
	if countdownText then countdownText:SetText('') end
end

local function CountdownTick()
	if not countdownText or not countdownExpiry then
		StopCountdown()
		return
	end
	local remaining = countdownExpiry - GetTime()
	if remaining <= 0 then
		StopCountdown()
		return
	end
	BUILib.Skin.SetCountdownText(countdownText, floor(remaining + 0.5), BUILib.Skin.COUNTDOWN_GREEN_COLOR)
end

local function StartCountdown(timeLeft)
	StopCountdown()
	if type(timeLeft) ~= 'number' or timeLeft <= 0 then return end
	countdownExpiry = GetTime() + timeLeft
	CountdownTick()
	countdownTicker = C_Timer.NewTicker(1, CountdownTick)
end

local function EnsureCountdown(listener)
	if countdownText then return countdownText end
	countdownText = listener:CreateFontString(nil, 'OVERLAY')
	countdownText:SetJustifyH('RIGHT')
	listener:HookScript('OnHide', StopCountdown)
	return countdownText
end

local function LayoutPrompt()
	local outer = _G.ReadyCheckFrame
	local listener = _G.ReadyCheckListenerFrame
	local text = _G.ReadyCheckFrameText
	if not outer or not listener or not text then return end

	local scale = CurrentScale()
	local paddingX = Scaled(Skin.TIP_PADDING_X, scale)
	local paddingY = Scaled(Skin.TIP_PADDING_Y, scale)
	local titleBlock = Scaled(Skin.TIP_TITLE_BLOCK, scale)
	local buttonHeight = Scaled(BUTTON_HEIGHT, scale)
	local buttonGap = Scaled(BUTTON_GAP, scale)
	local rowGap = Scaled(ROW_GAP, scale)

	text:SetWidth(0)
	local needed = text:GetStringWidth()
	if not needed or issecretvalue(needed) then return end
	local width = max(Scaled(MIN_WIDTH, scale), min(floor(needed + 0.5) + paddingX * 2, Scaled(MAX_WIDTH, scale)))

	local titleContainer = listener.TitleContainer
	local title = titleContainer and titleContainer.TitleText
	if title then
		title:ClearAllPoints()
		title:SetPoint('TOPLEFT', listener, 'TOPLEFT', paddingX, -paddingY)
		title:SetJustifyH('LEFT')
	end

	if countdownText then
		countdownText:ClearAllPoints()
		countdownText:SetPoint('TOPRIGHT', listener, 'TOPRIGHT', -paddingX, -paddingY)
	end

	text:SetWidth(width - paddingX * 2)
	text:SetJustifyH('CENTER')
	text:SetWordWrap(true)
	text:SetNonSpaceWrap(true)
	text:ClearAllPoints()
	text:SetPoint('TOPLEFT', listener, 'TOPLEFT', paddingX, -(paddingY + titleBlock))
	local textHeight = text:GetStringHeight()
	if not textHeight or issecretvalue(textHeight) then textHeight = Scaled(14, scale) end

	local yes, no = Buttons()
	if yes and no then
		local buttonWidth = floor((width - paddingX * 2 - buttonGap) / 2)
		yes:SetSize(buttonWidth, buttonHeight)
		no:SetSize(buttonWidth, buttonHeight)
		yes:ClearAllPoints()
		yes:SetPoint('BOTTOMLEFT', listener, 'BOTTOMLEFT', paddingX, paddingY)
		no:ClearAllPoints()
		no:SetPoint('BOTTOMRIGHT', listener, 'BOTTOMRIGHT', -paddingX, paddingY)
	end

	local height = paddingY + titleBlock + floor(textHeight + 0.5) + rowGap + buttonHeight + paddingY
	outer:SetSize(width, height)
end

local function OnPromptText()
	if recoloringPrompt or not Enabled() then return end
	ColorInitiator()
	LayoutPrompt()
end

local function Apply()
	if not Enabled() then return end
	local listener = _G.ReadyCheckListenerFrame
	if not listener then return end

	if not listener._buiReadyCheck then
		listener._buiReadyCheck = true
		FadeTextures(listener)
		FadeTextures(listener.NineSlice)
		FadeTextures(listener.TitleContainer)
		if listener.PortraitContainer then listener.PortraitContainer:Hide() end
		local text = _G.ReadyCheckFrameText
		if text then
			hooksecurefunc(text, 'SetText', OnPromptText)
			hooksecurefunc(text, 'SetFormattedText', OnPromptText)
		end
		EnsureCountdown(listener)
	end

	local scale = CurrentScale()
	Skin.TipShell(listener)
	Skin.TipTitleLine(listener, scale)
	Skin.TipFont(listener.TitleContainer and listener.TitleContainer.TitleText, 'title', scale)
	Skin.TipFont(_G.ReadyCheckFrameText, 'body', scale)
	Skin.TipFont(countdownText, 'body', scale)
	countdownText:SetTextColor(BUILib.Skin.CountdownColor(BUILib.Skin.COUNTDOWN_WARN_SECONDS, BUILib.Skin.COUNTDOWN_GREEN_COLOR))
	local yes, no = Buttons()
	Skin.TipButton(yes, scale)
	Skin.TipButton(no, scale)
	ColorInitiator()
	LayoutPrompt()
end

local function OnReadyCheck(_, initiator, timeLeft)
	if not Enabled() then return end
	initiatorName = initiator
	ColorInitiator()
	StartCountdown(timeLeft)
end

local function Install()
	if installed then return end
	local listener = _G.ReadyCheckListenerFrame
	if not listener then return end
	installed = true
	listener:HookScript('OnShow', Apply)
	BUI.Events:Register('READY_CHECK', 'Skin.ReadyCheck', OnReadyCheck)
	BUI.Events:Register('READY_CHECK_FINISHED', 'Skin.ReadyCheck', StopCountdown)
	if listener:IsShown() then Apply() end
end

local function Deactivate()
	StopCountdown()
	local listener = _G.ReadyCheckListenerFrame
	if not listener or not listener._buiReadyCheck then return end
	for region in pairs(fadedArt) do region:SetAlpha(1) end
	if listener.PortraitContainer then listener.PortraitContainer:Show() end
	Skin.HideTipShell(listener)
	if listener._buiTipLine then listener._buiTipLine:Hide() end
	BUI.Print('Ready Check skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if _G.ReadyCheckListenerFrame and _G.ReadyCheckListenerFrame:IsShown() then Apply() end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Ready Check',
	description = 'Ready check prompt drawn like the BluUI tooltip, with a countdown of the time left.',
	icon = 'Interface/RaidFrame/ReadyCheck-Ready',
	settingsHeight = 240,
	buildSettings = function(content)
		Skin.TipScaleCard(content, SCALE_KEY, function()
			if _G.ReadyCheckListenerFrame and _G.ReadyCheckListenerFrame:IsShown() then Apply() end
		end)
	end,
})
