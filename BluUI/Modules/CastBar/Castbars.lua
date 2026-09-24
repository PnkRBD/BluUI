local _, BUI = ...

local CastBar = BUI.CastBar
local Pixel = BUI.Pixel

local CreateFrame = CreateFrame
local UnitChannelInfo = UnitChannelInfo

local UnpackColor = BUI.UnpackColor

local function ResolveColor(castbar, settings)
	local barColor = settings.barColor
	if settings.useClassColor then
		local classColor = CastBar.GetUnitClassColor(castbar._barType)
		if classColor then barColor = classColor end
	end
	if settings.useSpellColors and not BUI.Tools.IsSecretValue(castbar.spellID) then
		local spellColor = CastBar.GetSpellColor(settings, castbar.spellID, castbar.spellName)
		if spellColor then barColor = spellColor end
	end
	return barColor
end

local function HideStageBackground(castbar)
	if not castbar._stageBgs then return end
	for _, stageTexture in ipairs(castbar._stageBgs) do stageTexture:Hide() end
end

local function SetupStageBackgrounds(castbar, stageColors, numStages, msBoundaries, fullDurationMs)
	castbar._stageBgs = castbar._stageBgs or {}
	HideStageBackground(castbar)
	if not msBoundaries or fullDurationMs <= 0 then return end

	local barWidth = castbar:GetWidth()
	if barWidth <= 0 then return end

	local texture = castbar:GetStatusBarTexture()
	local texturePath = texture and texture.GetTexture and texture:GetTexture()

	for stageIndex = 1, numStages do
		local startMs = (stageIndex == 1) and 0 or msBoundaries[stageIndex - 1]
		local endMs = msBoundaries[stageIndex] or fullDurationMs
		local startFraction = startMs / fullDurationMs
		local endFraction = endMs / fullDurationMs
		if endFraction > 1 then endFraction = 1 end

		local stageTexture = castbar._stageBgs[stageIndex]
		if not stageTexture then
			stageTexture = castbar:CreateTexture(nil, 'BACKGROUND', nil, 1)
			castbar._stageBgs[stageIndex] = stageTexture
		end

		if texturePath then
			stageTexture:SetTexture(texturePath)
		else
			stageTexture:SetColorTexture(1, 1, 1, 1)
		end

		local stageColor = stageColors[stageIndex]
		if stageColor then
			stageTexture:SetVertexColor(stageColor[1], stageColor[2], stageColor[3], (stageColor[4] or 1) * 0.45)
		end

		stageTexture:ClearAllPoints()
		stageTexture:SetPoint('TOPLEFT', castbar, 'TOPLEFT', startFraction * barWidth, 0)
		stageTexture:SetSize((endFraction - startFraction) * barWidth, castbar:GetHeight())
		stageTexture:Show()
	end
end

local function PostCastStart(castbar, unit)
	local settings = CastBar.GetSettings(castbar._barType)
	castbar._empoweredSettings = settings
	if not settings.enabled then return end
	castbar._interrupted = nil
	castbar._lastStage = nil
	castbar._ttsAnnounced = nil
	castbar._ttsSoonAnnounced = nil
	castbar._intTTSWant = nil
	castbar._intTTSSoonWant = nil

	local barColor = ResolveColor(castbar, settings)
	if castbar._barType ~= 'player' and settings.interruptColor then
		castbar._intBarColor = barColor
		castbar._intInterruptColor = settings.interruptColor
		castbar._intOnCDColor = settings.interruptOnCDColor
		castbar._intReadyColor = settings.interruptReadyColor
		castbar._intTTSWant = settings.interruptTTS
		castbar._intTTSText = settings.interruptTTSText
		castbar._intTTSSoonWant = settings.interruptTTSSoon
		castbar._intTTSSoonText = settings.interruptTTSSoonText
		castbar._intTTSSoonWindow = settings.interruptTTSSoonWindow
		CastBar.StartTrackingInterrupts(castbar)
		CastBar.ApplyInterruptColor(castbar, barColor, settings.interruptColor, settings.interruptOnCDColor, settings.interruptReadyColor)
		CastBar.SetupInterruptTick(castbar, settings)
		CastBar.CheckInterruptTTS(castbar)
	else
		castbar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
	end

	CastBar.TruncateSpellName(castbar, settings)
	CastBar.ApplyCastTarget(castbar, settings, unit)
	CastBar.UpdateChannelTicks(castbar, settings)
	castbar.Text:SetShown(settings.showSpellName)
	castbar.Time:SetShown(settings.showTimer)
	castbar._container:Show()
end

local function PostCastInterruptible(castbar, unit)
	local settings = CastBar.GetSettings(castbar._barType)
	if not settings.enabled or castbar._barType == 'player' then return end
	CastBar.ApplyInterruptColor(castbar, ResolveColor(castbar, settings), settings.interruptColor, settings.interruptOnCDColor, settings.interruptReadyColor)
	CastBar.SetupInterruptTick(castbar, settings)
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

local DisplayNames = { player = 'Player', target = 'Target', focus = 'Focus' }

local function ShowPreview(castbar, barType)
	local settings = CastBar.GetSettings(barType)

	local container = castbar._container
	local display = DisplayNames[barType] or barType

	castbar.holdTime = 1e9
	castbar:SetMinMaxValues(0, 1)
	castbar:SetValue(1)
	local previewColor = settings.barColor
	if settings.useClassColor then
		local classColor = CastBar.GetUnitClassColor(barType)
		if classColor then previewColor = classColor end
	end
	castbar:SetStatusBarColor(UnpackColor(previewColor, 0.2, 0.2, 0.8, 1))

	if container._isAnchored then
		castbar.Text:SetText(display .. ' - Anchored | Right-Click to Lock')
	else
		castbar.Text:SetText(display .. ' - Drag to Reposition | Right-Click to Lock')
	end
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

	local function ApplyPipStyle(pip, settings)
		local pipWidth = settings.pipWidth
		local pipColor = settings.pipColor
		local showGlow = settings.pipGlow ~= false

		pip:SetWidth(pipWidth)
		if pip._line then pip._line:SetColorTexture(pipColor[1], pipColor[2], pipColor[3], pipColor[4]) end
		if pip._glow then
			if showGlow then
				pip._glow:SetColorTexture(pipColor[1], pipColor[2], pipColor[3], 0.15)
				pip._glow:ClearAllPoints()
				pip._glow:SetPoint('TOPLEFT', -(pipWidth + 1), 0)
				pip._glow:SetPoint('BOTTOMRIGHT', (pipWidth + 1), 0)
				pip._glow:Show()
			else
				pip._glow:Hide()
			end
		elseif showGlow then
			local glow = pip:CreateTexture(nil, 'OVERLAY', nil, -1)
			glow:SetColorTexture(pipColor[1], pipColor[2], pipColor[3], 0.15)
			glow:SetPoint('TOPLEFT', -(pipWidth + 1), 0)
			glow:SetPoint('BOTTOMRIGHT', (pipWidth + 1), 0)
			pip._glow = glow
		end
	end

	function castbar:CreatePip(stage)
		local settings = CastBar.GetSettings(self._barType)
		local pipWidth = settings.pipWidth
		local pipColor = settings.pipColor

		local pip = CreateFrame('Frame', nil, self)
		pip:SetFrameLevel(self:GetFrameLevel() + 5)
		pip:SetWidth(pipWidth)

		local line = pip:CreateTexture(nil, 'OVERLAY')
		line:SetColorTexture(pipColor[1], pipColor[2], pipColor[3], pipColor[4])
		line:SetAllPoints()
		pip._line = line

		if settings.pipGlow ~= false then
			local glow = pip:CreateTexture(nil, 'OVERLAY', nil, -1)
			glow:SetColorTexture(pipColor[1], pipColor[2], pipColor[3], 0.15)
			glow:SetPoint('TOPLEFT', -(pipWidth + 1), 0)
			glow:SetPoint('BOTTOMRIGHT', (pipWidth + 1), 0)
			pip._glow = glow
		end

		return pip
	end

	function castbar:RefreshPips()
		local settings = CastBar.GetSettings(self._barType)
		for _, pip in next, self.Pips do
			ApplyPipStyle(pip, settings)
		end
	end

	castbar.PostCastStart = PostCastStart
	castbar.PostCastStop = function(bar) CastBar.HideInterruptOverlays(bar) end
	castbar.PostCastFail = PostCastFail
	castbar.PostCastInterrupted = PostCastInterrupted
	castbar.PostCastInterruptible = PostCastInterruptible

	castbar.UpdatePips = function(self, stages)
		if not stages then return end

		for _, pip in next, self.Pips do pip:Hide() end

		local _, _, _, _, _, _, _, _, _, numStages = UnitChannelInfo('player')
		if not numStages or numStages < 2 then return end
		local pipCount = numStages - 1

		local totalDuration = 0
		local msBoundaries = {}
		for stageIndex = 1, numStages do
			totalDuration = totalDuration + (GetUnitEmpowerStageDuration('player', stageIndex - 1) or 0)
			msBoundaries[stageIndex] = totalDuration
		end
		if totalDuration == 0 then return end

		local fullDuration = ((castbar.endTime or 0) - (castbar.startTime or 0)) * 1000
		if fullDuration <= 0 then fullDuration = totalDuration end
		local barWidth = self:GetWidth()

		for pipIndex = 1, pipCount do
			local pixelOffset = (msBoundaries[pipIndex] / fullDuration) * barWidth
			local pip = self.Pips[pipIndex]
			if not pip then
				pip = self:CreatePip(pipIndex)
				self.Pips[pipIndex] = pip
			end
			pip:ClearAllPoints()
			pip:SetPoint('TOP', self, 'TOPLEFT', pixelOffset, 0)
			pip:SetPoint('BOTTOM', self, 'BOTTOMLEFT', pixelOffset, 0)
			pip:Show()
		end

		for pipIndex = pipCount + 1, 10 do
			if self.Pips[pipIndex] then self.Pips[pipIndex]:Hide() end
		end

		local pipFractions = {}
		for stageIndex = 1, numStages do
			pipFractions[stageIndex] = msBoundaries[stageIndex] / fullDuration
		end
		self._pipFractions = pipFractions
		self._numStages = numStages
		self._lastStage = nil

		local settings = CastBar.GetSettings(self._barType)
		if settings.stageColorsEnabled and settings.stageColorBackground ~= false then
			local stageColors = settings.stageColors
			if stageColors and next(stageColors) then
				SetupStageBackgrounds(self, stageColors, numStages, msBoundaries, fullDuration)
			end
		end
	end

	castbar:HookScript('OnHide', function(self)
		self._pipFractions = nil
		self._lastStage = nil
		self._empoweredSettings = nil
		HideStageBackground(self)
		CastBar.HideChannelTicks(self)
		if self._suppressAutoPreview then return end
		self._container:Hide()
	end)

	local function SaveDragPosition(x, y)
		local settings = CastBar.GetSettings(barType)
		local saveX = x

		if settings.showIcon then saveX = x - (Pixel.ScaleEven(settings.height) + Pixel.PixelSize(1)) / 2 end
		CastBar.SaveSettings(barType, 'posX', saveX)
		CastBar.SaveSettings(barType, 'posY', y)
		CastBar.FirePositionCallback(barType, saveX, y)
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
			local settings = CastBar.GetSettings(barType)
			settings.locked = true
			BUI.Dragging.SetLocked(container, true)
			if CastBar._lockToggles and CastBar._lockToggles[barType] then
				local toggle = CastBar._lockToggles[barType]
				if toggle and toggle.SetValue then toggle:SetValue(false) end
			end
			castbar._suppressAutoPreview = true
			castbar:Hide()
			container:Hide()
			castbar._suppressAutoPreview = nil
		end,
	})

	frame._castbarContainer = container
	frame.Castbar = castbar
end

local function LayoutContainer(container, settings)
	local height = Pixel.ScaleEven(settings.height)
	local gap = Pixel.PixelSize(1)
	local width = Pixel.Scale(settings.width)
	local barWidth = width
	if settings.showIcon then
		barWidth = width - height - gap
	end
	container:SetSize(barWidth, height)

	local anchorSettings = {
		anchorFrame = settings.anchorFrame,
		anchorPoint = settings.anchorPoint,
		anchorOffsetX = settings.anchorOffsetX,
		anchorOffsetY = settings.anchorOffsetY,
		posX = settings.posX,
		posY = settings.posY,
		centerHorizontally = settings.centerHorizontally,
	}
	local iconTotal = height + gap
	container._castbarIconWidth = settings.showIcon and iconTotal or 0
	if settings.showIcon and settings.anchorFrame and settings.anchorFrame ~= '' then
		local anchorPoint = settings.anchorPoint
		if anchorPoint:match('LEFT') then
			anchorSettings.anchorOffsetX = anchorSettings.anchorOffsetX + iconTotal
		elseif not anchorPoint:match('RIGHT') then
			anchorSettings.anchorOffsetX = anchorSettings.anchorOffsetX + (iconTotal / 2)
		end
	end
	if settings.showIcon and (not settings.anchorFrame or settings.anchorFrame == '') then
		anchorSettings.posX = anchorSettings.posX + (settings.height + 1) / 2
	end

	BUI.Anchor.ApplyPosition(container, anchorSettings)

	if container._isAnchored and settings.matchAnchorWidth then
		local anchorWidth = BUI.Anchor.GetAnchorWidth(container, settings)
		if anchorWidth then
			if settings.showIcon then anchorWidth = anchorWidth - iconTotal end
			container:SetWidth(anchorWidth)
		end
	end
end

function CastBar.RepositionCastbar(frame, barType)
	local castbar = frame and frame.Castbar
	if not castbar or not castbar._container then return end
	local settings = CastBar.GetSettings(barType)
	if not settings.enabled then return end

	LayoutContainer(castbar._container, settings)
end

function CastBar.ApplyCastbar(frame, barType)
	local castbar = frame.Castbar
	if not castbar or not castbar._container then return end

	local settings = CastBar.GetSettings(barType)

	local container = castbar._container
	container:SetFrameStrata(settings.frameStrata)
	if castbar._overlay then castbar._overlay:SetFrameStrata(settings.textStrata) end
	local texture = CastBar.GetTexturePath(settings.texture)
	local font = CastBar.GetFont(settings.font)
	local height = Pixel.ScaleEven(settings.height)
	local edge = Pixel.Scale(settings.borderSize)
	local gap = Pixel.PixelSize(1)

	LayoutContainer(container, settings)

	local backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha = UnpackColor(settings.bgColor, 0.1, 0.1, 0.1, 0.8)
	local borderRed, borderGreen, borderBlue, borderAlpha = UnpackColor(settings.borderColor, 0, 0, 0, 1)
	Pixel.SetTemplate(container, backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha, borderRed, borderGreen, borderBlue, borderAlpha, settings.borderSize)

	castbar:ClearAllPoints()
	castbar:SetPoint('TOPLEFT', container, 'TOPLEFT', edge, -edge)
	castbar:SetPoint('BOTTOMRIGHT', container, 'BOTTOMRIGHT', -edge, edge)
	castbar:SetStatusBarTexture(texture)

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

	castbar.Icon:SetSize(height - (edge * 2), height - (edge * 2))
	castbar.Icon:ClearAllPoints()
	castbar.Icon:SetPoint('CENTER', iconFrame)
	castbar.Icon:SetShown(settings.showIcon)

	local textOffsetX = settings.textOffsetX
	local textOffsetY = settings.textOffsetY

	local textColor = settings.textColor

	Pixel.ApplyFont(castbar.Text, settings.textSize, font)
	castbar.Text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
	castbar.Text:ClearAllPoints()
	castbar.Text:SetPoint('LEFT', castbar, 'LEFT', Pixel.Scale(4 + textOffsetX), -Pixel.Scale(textOffsetY))

	Pixel.ApplyFont(castbar.Time, settings.textSize, font)
	castbar.Time:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
	castbar.Time:ClearAllPoints()
	castbar.Time:SetPoint('RIGHT', castbar, 'RIGHT', Pixel.Scale(-4 + textOffsetX), -Pixel.Scale(textOffsetY))

	CastBar.SetupTimeText(castbar, settings)

	BUI.Dragging.SetLocked(container, settings.locked)

	if not settings.enabled then
		if frame.DisableElement then frame:DisableElement('Castbar') end
		castbar._suppressAutoPreview = true
		castbar:Hide()
		container:Hide()
		castbar._suppressAutoPreview = nil
		return
	end

	if frame.EnableElement then frame:EnableElement('Castbar', frame.unit) end

	if BUI.UnitFrames.IsShowAllActive() and frame._testCastActive then
		castbar.holdTime = 1e9
		castbar:SetMinMaxValues(0, 100)
		castbar:SetValue(frame._testCastValue or 0)
		castbar:Show()
		castbar.Text:SetText('Test Cast')
		castbar.Text:Show()
		castbar.Time:Show()
		container:Show()
		return
	end

	if not settings.locked and not castbar.casting and not castbar.channeling and not castbar.empowering then
		ShowPreview(castbar, barType)
		return
	end

	castbar:RefreshPips()

	if not castbar.casting and not castbar.channeling and not castbar.empowering then
		castbar._suppressAutoPreview = true
		castbar:Hide()
		container:Hide()
		castbar._suppressAutoPreview = nil
	end
end
