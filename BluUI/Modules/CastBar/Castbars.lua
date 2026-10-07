local _, BUI = ...

local CastBar = BUI.CastBar
local Pixel = BUI.Pixel

local CreateFrame = CreateFrame
local UnitChannelInfo = UnitChannelInfo

local UnpackColor = BUI.UnpackColor

local TEXT_INSET = 4
local STAGE_BACKGROUND_ALPHA = 0.45
local PIP_GLOW_ALPHA = 0.15
local DISPLAY_NAMES = { player = 'Player', target = 'Target', focus = 'Focus' }

function CastBar.StyleText(anchor, text, time, settings, font)
	local textColor = settings.textColor
	local offsetY = -Pixel.Scale(settings.textOffsetY)
	Pixel.ApplyFont(time, settings.textSize, font)
	time:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
	time:SetWordWrap(false)
	time:ClearAllPoints()
	time:SetPoint('RIGHT', anchor, 'RIGHT', Pixel.Scale(settings.textOffsetX - TEXT_INSET), offsetY)
	Pixel.ApplyFont(text, settings.textSize, font)
	text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
	text:SetWordWrap(false)
	text:ClearAllPoints()
	text:SetPoint('LEFT', anchor, 'LEFT', Pixel.Scale(TEXT_INSET + settings.textOffsetX), offsetY)
	text:SetPoint('RIGHT', time, 'LEFT', -Pixel.Scale(TEXT_INSET), 0)
end

function CastBar.HideQuietly(castbar)
	castbar.holdTime = nil
	castbar._suppressAutoPreview = true
	castbar:Hide()
	castbar._container:Hide()
	castbar._suppressAutoPreview = nil
end

local function BaseColor(settings, barType)
	if settings.useClassColor then
		local red, green, blue = BUI.Tools.GetUnitClassColor(barType)
		if red then return { red, green, blue, 1 } end
	end
	return settings.barColor
end

local function ResolveColor(castbar, settings)
	local spellID = castbar.spellID
	if settings.useSpellColors and not BUI.Tools.IsSecretValue(spellID) and settings.spellColors[spellID] then
		return settings.spellColors[spellID]
	end
	return BaseColor(settings, castbar._barType)
end

local function HideStageBackground(castbar)
	if not castbar._stageBgs then return end
	for _, stageTexture in ipairs(castbar._stageBgs) do stageTexture:Hide() end
end

local function SetupStageBackgrounds(castbar, stageColors, numStages, boundaries, fullDuration)
	castbar._stageBgs = castbar._stageBgs or {}
	HideStageBackground(castbar)

	local barWidth = castbar:GetWidth()
	if barWidth <= 0 then return end
	local texturePath = castbar:GetStatusBarTexture():GetTexture()

	for stage = 1, numStages do
		local startFraction = (stage == 1 and 0 or boundaries[stage - 1]) / fullDuration
		local endFraction = boundaries[stage] / fullDuration

		local stageTexture = castbar._stageBgs[stage]
		if not stageTexture then
			stageTexture = castbar:CreateTexture(nil, 'BACKGROUND', nil, 1)
			castbar._stageBgs[stage] = stageTexture
		end
		stageTexture:SetTexture(texturePath)

		local stageColor = stageColors[stage]
		if stageColor then
			stageTexture:SetVertexColor(stageColor[1], stageColor[2], stageColor[3], (stageColor[4] or 1) * STAGE_BACKGROUND_ALPHA)
		end

		stageTexture:ClearAllPoints()
		stageTexture:SetPoint('TOPLEFT', castbar, 'TOPLEFT', startFraction * barWidth, 0)
		stageTexture:SetSize((endFraction - startFraction) * barWidth, castbar:GetHeight())
		stageTexture:Show()
	end
end

local function StylePip(pip, settings)
	local width, color = settings.pipWidth, settings.pipColor
	pip:SetWidth(width)
	pip._line:SetColorTexture(color[1], color[2], color[3], color[4])
	if settings.pipGlow then
		pip._glow = pip._glow or pip:CreateTexture(nil, 'OVERLAY', nil, -1)
		pip._glow:SetColorTexture(color[1], color[2], color[3], PIP_GLOW_ALPHA)
		pip._glow:ClearAllPoints()
		pip._glow:SetPoint('TOPLEFT', -(width + 1), 0)
		pip._glow:SetPoint('BOTTOMRIGHT', width + 1, 0)
		pip._glow:Show()
	elseif pip._glow then
		pip._glow:Hide()
	end
end

local function CreatePip(castbar)
	local pip = CreateFrame('Frame', nil, castbar)
	pip:SetFrameLevel(castbar:GetFrameLevel() + 5)
	pip._line = pip:CreateTexture(nil, 'OVERLAY')
	pip._line:SetAllPoints()
	StylePip(pip, CastBar.GetSettings(castbar._barType))
	return pip
end

local function RefreshPips(castbar)
	local settings = CastBar.GetSettings(castbar._barType)
	for _, pip in ipairs(castbar.Pips) do StylePip(pip, settings) end
end

local function UpdatePips(castbar)
	for _, pip in ipairs(castbar.Pips) do pip:Hide() end
	castbar._pipFractions = nil
	if castbar._barType ~= 'player' then return end

	local _, _, _, startMS, endMS, _, _, _, _, numStages = UnitChannelInfo('player')
	if not numStages or numStages < 2 then return end

	local boundaries = {}
	local stageTotal = 0
	for stage = 1, numStages do
		stageTotal = stageTotal + GetUnitEmpowerStageDuration('player', stage - 1)
		boundaries[stage] = stageTotal
	end
	local fullDuration = endMS + GetUnitEmpowerHoldAtMaxTime('player') - startMS
	castbar._empowerStart = startMS / 1000
	castbar._empowerEnd = (startMS + fullDuration) / 1000
	local barWidth = castbar:GetWidth()

	for index = 1, numStages - 1 do
		local pip = castbar.Pips[index]
		if not pip then
			pip = CreatePip(castbar)
			castbar.Pips[index] = pip
		end
		local x = boundaries[index] / fullDuration * barWidth
		pip:ClearAllPoints()
		pip:SetPoint('TOP', castbar, 'TOPLEFT', x, 0)
		pip:SetPoint('BOTTOM', castbar, 'BOTTOMLEFT', x, 0)
		pip:Show()
	end

	local fractions = {}
	for stage = 1, numStages do fractions[stage] = boundaries[stage] / fullDuration end
	castbar._pipFractions = fractions
	castbar._numStages = numStages
	castbar._lastStage = nil

	local settings = CastBar.GetSettings(castbar._barType)
	if settings.stageColorsEnabled and settings.stageColorBackground and next(settings.stageColors) then
		SetupStageBackgrounds(castbar, settings.stageColors, numStages, boundaries, fullDuration)
	end
end

local function CancelStageColors(castbar)
	if not castbar._stageTimer then return end
	castbar._stageTimer:Cancel()
	castbar._stageTimer = nil
end

local function EmpoweredStageAt(castbar, now)
	local startTime = castbar._empowerStart
	local span = castbar._empowerEnd - startTime
	local stage = 1
	for index, fraction in ipairs(castbar._pipFractions) do
		if now >= startTime + fraction * span then stage = index + 1 end
	end
	if stage > castbar._numStages then stage = castbar._numStages end
	return stage
end

local function PaintEmpoweredStage(castbar)
	castbar._stageTimer = nil
	if not castbar._pipFractions or castbar._interrupted then return end
	local now = GetTime()
	local stage = EmpoweredStageAt(castbar, now)
	if stage ~= castbar._lastStage then
		castbar._lastStage = stage
		local stageColor = castbar._empoweredSettings.stageColors[stage]
		if stageColor then castbar:SetStatusBarColor(stageColor[1], stageColor[2], stageColor[3], stageColor[4] or 1) end
	end
	if stage < castbar._numStages then
		local startTime = castbar._empowerStart
		local nextStageAt = startTime + castbar._pipFractions[stage] * (castbar._empowerEnd - startTime)
		castbar._stageTimer = BUI.Profiler.NewTimer('CastBar.Castbars empower stage', nextStageAt - now, function() PaintEmpoweredStage(castbar) end)
	end
end

local function StartStageColors(castbar, settings)
	CancelStageColors(castbar)
	if not (castbar._pipFractions and settings.stageColorsEnabled) then return end
	if settings.stageColorBackground ~= false or not next(settings.stageColors) then return end
	PaintEmpoweredStage(castbar)
end

local function PostCastStart(castbar, unit)
	local settings = CastBar.GetSettings(castbar._barType)
	castbar._empoweredSettings = settings
	if not settings.enabled then return end
	castbar._interrupted = nil
	castbar._lastStage = nil

	local barColor = ResolveColor(castbar, settings)
	if castbar._barType == 'player' then
		castbar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
		StartStageColors(castbar, settings)
	else
		CastBar.TrackInterrupts(castbar, settings, barColor, unit)
	end

	CastBar.TruncateSpellName(castbar, settings)
	CastBar.ApplyCastTarget(castbar, settings, unit)
	CastBar.UpdateChannelTicks(castbar, settings)
	castbar.Text:SetShown(settings.showSpellName)
	castbar.Time:SetShown(settings.showTimer)
	castbar._container:Show()
end

local function PostCastInterruptible(castbar)
	local settings = CastBar.GetSettings(castbar._barType)
	if not settings.enabled or castbar._barType == 'player' then return end
	CastBar.RefreshInterruptible(castbar, ResolveColor(castbar, settings), settings)
end

local function PostCastFail(castbar)
	CastBar.HideInterruptOverlays(castbar)
	castbar:SetStatusBarColor(0.8, 0.2, 0.2, 1)
end

local function PostCastInterrupted(castbar)
	castbar._interrupted = true
	CastBar.HideInterruptOverlays(castbar)
	castbar:SetStatusBarColor(1, 0, 0, 1)
	castbar._container:Show()
end

local function ShowPreview(castbar, barType)
	local settings = CastBar.GetSettings(barType)
	local container = castbar._container

	castbar.holdTime = 1e9
	castbar:SetMinMaxValues(0, 1)
	castbar:SetValue(1)
	local color = BaseColor(settings, barType)
	castbar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)

	local hint = container._isAnchored and ' - Anchored | Right-Click to Lock' or ' - Drag to Reposition | Right-Click to Lock'
	castbar.Text:SetText(DISPLAY_NAMES[barType] .. hint)
	castbar.Text:Show()
	castbar.Time:SetText('')
	castbar.Time:Hide()

	castbar.Icon:SetTexture(136243)
	castbar.Icon:SetShown(settings.showIcon)
	castbar._iconFrame:SetShown(settings.showIcon)

	castbar:Show()
	container:Show()
end

function CastBar.CreateCastbar(frame, barType)
	local container = CreateFrame('Frame', 'BUI_Castbar_' .. barType, frame, 'BackdropTemplate')
	container:SetFrameStrata('LOW')
	container:SetFrameLevel(10)
	container:Hide()
	CastBar.TrackContainer(container)

	local iconFrame = CreateFrame('Frame', nil, container, 'BackdropTemplate')
	local icon = iconFrame:CreateTexture(nil, 'ARTWORK')
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local castbar = CreateFrame('StatusBar', nil, container)
	castbar:SetFrameLevel(container:GetFrameLevel() + 1)
	castbar:EnableMouse(false)

	local overlay = CreateFrame('Frame', nil, container)
	overlay:SetAllPoints(castbar)
	overlay:SetFrameLevel(container:GetFrameLevel() + 20)
	overlay:EnableMouse(false)

	local text = overlay:CreateFontString(nil, 'OVERLAY')
	text:SetJustifyH('LEFT')
	text:SetJustifyV('MIDDLE')

	local timer = overlay:CreateFontString(nil, 'OVERLAY')
	timer:SetJustifyH('RIGHT')
	timer:SetJustifyV('MIDDLE')

	local safeZone = castbar:CreateTexture(nil, 'OVERLAY')
	safeZone:SetBlendMode('ADD')
	safeZone:Hide()

	castbar.Icon = icon
	castbar.Text = text
	castbar.Time = timer
	castbar.SafeZone = safeZone
	castbar._container = container
	castbar._overlay = overlay
	castbar._iconFrame = iconFrame
	castbar._barType = barType
	castbar.timeToHold = 0.5
	castbar.Pips = {}

	castbar.PostCastStart = PostCastStart
	castbar.PostCastStop = CastBar.HideInterruptOverlays
	castbar.PostCastFail = PostCastFail
	castbar.PostCastInterrupted = PostCastInterrupted
	castbar.PostCastInterruptible = PostCastInterruptible
	castbar.UpdatePips = UpdatePips

	castbar:HookScript('OnHide', BUI.Profiler.Wrap('CastBar.Castbars castbar hide', function(self)
		CancelStageColors(self)
		self._pipFractions = nil
		self._lastStage = nil
		self._empoweredSettings = nil
		HideStageBackground(self)
		CastBar.HideChannelTicks(self)
		if self._suppressAutoPreview then return end
		container:Hide()
	end))

	local function SaveDragPosition(x, y)
		local settings = CastBar.GetSettings(barType)
		settings.posX = settings.showIcon and x - (Pixel.ScaleEven(settings.height) + Pixel.PixelSize(1)) / 2 or x
		settings.posY = y
	end

	BUI.Dragging.MakeDraggable(container, {
		isLocked = function()
			return CastBar.GetSettings(barType).locked
		end,
		onDragging = SaveDragPosition,
		onPositionChanged = function(x, y)
			SaveDragPosition(x, y)
			container:ClearAllPoints()
			container:SetPoint('CENTER', UIParent, 'CENTER', x, y)
		end,
		onRightClick = function()
			CastBar.GetSettings(barType).locked = true
			BUI.Dragging.SetLocked(container, true)
			local toggle = CastBar._lockToggles and CastBar._lockToggles[barType]
			if toggle then toggle:SetValue(false) end
			CastBar.HideQuietly(castbar)
		end,
	})

	frame._castbarContainer = container
	frame.Castbar = castbar
end

local function LayoutContainer(container, settings)
	local height = Pixel.ScaleEven(settings.height)
	local gap = Pixel.PixelSize(1)
	local iconTotal = height + gap
	local width = Pixel.Scale(settings.width)
	container:SetSize(settings.showIcon and width - iconTotal or width, height)
	container._castbarIconWidth = settings.showIcon and iconTotal or 0

	local anchorSettings = {
		anchorFrame = settings.anchorFrame,
		anchorPoint = settings.anchorPoint,
		anchorOffsetX = settings.anchorOffsetX,
		anchorOffsetY = settings.anchorOffsetY,
		posX = settings.posX,
		posY = settings.posY,
		centerHorizontally = settings.centerHorizontally,
	}
	if settings.showIcon then
		if settings.anchorFrame == '' then
			anchorSettings.posX = settings.posX + (settings.height + 1) / 2
		elseif settings.anchorPoint:match('LEFT') then
			anchorSettings.anchorOffsetX = settings.anchorOffsetX + iconTotal
		elseif not settings.anchorPoint:match('RIGHT') then
			anchorSettings.anchorOffsetX = settings.anchorOffsetX + iconTotal / 2
		end
	end

	BUI.Anchor.ApplyPosition(container, anchorSettings)

	if container._isAnchored and settings.matchAnchorWidth then
		local anchorWidth = BUI.Anchor.GetAnchorWidth(container, settings)
		if anchorWidth then
			container:SetWidth(settings.showIcon and anchorWidth - iconTotal or anchorWidth)
		end
	end
end

local function AnchorMoved(container, settings)
	return BUI.UnitFrames.AnchorGeometryChanged(container, BUI.ResolveAnchorFrame(settings.anchorFrame, settings.anchorPoint))
end

function CastBar.RepositionCastbar(frame, barType)
	local settings = CastBar.GetSettings(barType)
	local container = frame.Castbar._container
	if settings.enabled and AnchorMoved(container, settings) then LayoutContainer(container, settings) end
end

function CastBar.ApplyCastbar(frame, barType)
	local castbar = frame.Castbar
	local container = castbar._container
	local settings = CastBar.GetSettings(barType)

	container:SetFrameStrata(settings.frameStrata)
	local overlay = castbar._overlay
	overlay:SetFixedFrameStrata(false)
	overlay:SetFrameStrata(settings.textStrata)
	overlay:SetFixedFrameStrata(true)
	local height = Pixel.ScaleEven(settings.height)
	local edge = Pixel.Scale(settings.borderSize)
	local gap = Pixel.PixelSize(1)

	AnchorMoved(container, settings)
	LayoutContainer(container, settings)

	local backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha = UnpackColor(settings.bgColor, 0.1, 0.1, 0.1, 0.8)
	local borderRed, borderGreen, borderBlue, borderAlpha = UnpackColor(settings.borderColor)
	Pixel.SetTemplate(container, backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha, borderRed, borderGreen, borderBlue, borderAlpha, settings.borderSize)

	castbar:ClearAllPoints()
	castbar:SetPoint('TOPLEFT', container, 'TOPLEFT', edge, -edge)
	castbar:SetPoint('BOTTOMRIGHT', container, 'BOTTOMRIGHT', -edge, edge)
	castbar:SetStatusBarTexture(CastBar.GetTexturePath(settings.texture))

	if barType == 'player' and settings.showLatency then
		local latencyColor = settings.latencyColor
		castbar.SafeZone:SetColorTexture(latencyColor[1], latencyColor[2], latencyColor[3], latencyColor[4])
		castbar.SafeZone:Show()
	else
		castbar.SafeZone:Hide()
	end

	local iconFrame = castbar._iconFrame
	iconFrame:SetSize(height, height)
	iconFrame:ClearAllPoints()
	iconFrame:SetPoint('RIGHT', container, 'LEFT', -gap, 0)
	if settings.showIcon and settings.borderSize > 0 then
		Pixel.SetTemplate(iconFrame, backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha, borderRed, borderGreen, borderBlue, borderAlpha, settings.borderSize)
	else
		iconFrame:SetBackdrop(nil)
	end
	iconFrame:SetShown(settings.showIcon)

	castbar.Icon:SetSize(height - edge * 2, height - edge * 2)
	castbar.Icon:ClearAllPoints()
	castbar.Icon:SetPoint('CENTER', iconFrame)
	castbar.Icon:SetShown(settings.showIcon)

	CastBar.StyleText(castbar, castbar.Text, castbar.Time, settings, CastBar.GetFont(settings.font))
	CastBar.SetupTimeText(castbar, settings)
	BUI.Dragging.SetLocked(container, settings.locked)

	if not settings.enabled then
		frame:DisableElement('Castbar')
		CastBar.HideQuietly(castbar)
		return
	end

	frame:EnableElement('Castbar', frame.unit)

	if BUI.UnitFrames.PaintSampleCast(frame) then return end

	local casting = castbar.casting or castbar.channeling or castbar.empowering
	if not settings.locked and not casting then
		ShowPreview(castbar, barType)
		return
	end

	RefreshPips(castbar)
	if not casting then CastBar.HideQuietly(castbar) end
end
