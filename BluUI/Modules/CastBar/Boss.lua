local _, BUI = ...

local CastBar = BUI.CastBar
local Pixel = BUI.Pixel
local UnpackColor = BUI.UnpackColor

local function ResolveBossColor(castbar, settings)
	return settings.useIndividualColors and settings.bossColors[castbar._bossIndex] or settings.barColor
end

local function BossPostCastStart(castbar, unit)
	local settings = CastBar.GetSettings('boss')
	if not settings.enabled then return end
	castbar._interrupted = nil
	castbar._container:Show()
	CastBar.TrackInterrupts(castbar, settings, ResolveBossColor(castbar, settings), unit)
	CastBar.TruncateSpellName(castbar, settings)
	CastBar.ApplyCastTarget(castbar, settings, unit)
	castbar.Text:SetShown(settings.showSpellName)
	castbar.Time:SetShown(settings.showTimer)
end

local function BossPostCastInterruptible(castbar)
	local settings = CastBar.GetSettings('boss')
	if not settings.enabled then return end
	CastBar.RefreshInterruptible(castbar, ResolveBossColor(castbar, settings), settings)
end

function CastBar.CreateBossCastbar(frame)
	local castbar, container, overlay = CastBar.BuildFrames(frame, 'boss')
	container:SetFrameLevel(frame:GetFrameLevel() + 5)
	castbar:SetFrameLevel(container:GetFrameLevel() + 2)
	overlay:SetFrameLevel(castbar:GetFrameLevel() + 10)
	castbar._bossIndex = tonumber(frame.unit:match('%d+'))

	castbar:HookScript('OnShow', function() container:Show() end)
	castbar:HookScript('OnHide', function() container:Hide() end)
	castbar.PostCastStart = BossPostCastStart
	castbar.PostCastFail = CastBar.HideInterruptOverlays
	castbar.PostCastInterruptible = BossPostCastInterruptible
end

function CastBar.ApplyBossCastbar(frame, index)
	local castbar = frame.Castbar
	local container = castbar._container
	local settings = CastBar.GetSettings('boss')

	container:SetFrameStrata(settings.frameStrata)
	castbar._bossIndex = index or castbar._bossIndex

	if not settings.enabled then
		frame:DisableElement('Castbar')
		container:Hide()
		castbar:Hide()
		return
	end

	if frame:GetWidth() == 0 then
		if not frame._castbarSizeHooked then
			frame._castbarSizeHooked = true
			frame:HookScript('OnSizeChanged', function(self)
				if self:GetWidth() > 0 then CastBar.ApplyBossCastbar(self) end
			end)
		end
		return
	end

	frame:EnableElement('Castbar', frame.unit)

	local height = Pixel.ScaleEven(settings.height)
	local frameWidth = frame:GetWidth()
	local edge = Pixel.Scale(settings.borderSize)
	local gap = Pixel.PixelSize(1)

	container:ClearAllPoints()
	if settings.showIcon then
		local iconTotal = height + gap
		container:SetSize(frameWidth - iconTotal, height)
		container:SetPoint('TOPLEFT', frame, 'BOTTOMLEFT', iconTotal, -gap)
	else
		container:SetSize(frameWidth, height)
		container:SetPoint('TOP', frame, 'BOTTOM', 0, -gap)
	end

	local backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha = UnpackColor(settings.bgColor)
	local borderRed, borderGreen, borderBlue, borderAlpha = UnpackColor(settings.borderColor)
	Pixel.SetTemplate(container, backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha, borderRed, borderGreen, borderBlue, borderAlpha, settings.borderSize)

	if not castbar:IsShown() then container:Hide() end

	CastBar.FitBar(castbar, settings, height, edge, gap)
	local barColor = ResolveBossColor(castbar, settings)
	castbar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4])

	local iconFrame = castbar._iconFrame
	if settings.showIcon and settings.borderSize > 0 then
		Pixel.ApplyBorder(iconFrame, settings.borderSize, borderRed, borderGreen, borderBlue, borderAlpha)
		Pixel.ShowBorder(iconFrame)
	else
		Pixel.HideBorder(iconFrame)
	end
end
