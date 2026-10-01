local _, BUI = ...

local CastBar = BUI.CastBar
local Pixel = BUI.Pixel
local UnpackColor = BUI.UnpackColor

local CreateFrame = CreateFrame

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

local function BossPostCastInterrupted(castbar)
	castbar._interrupted = true
	CastBar.HideInterruptOverlays(castbar)
	castbar:SetStatusBarColor(1, 0, 0, 1)
end

function CastBar.CreateBossCastbar(frame)
	local font = BUI.UnitFrames.GetFont()

	local container = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
	container:SetFrameLevel(frame:GetFrameLevel() + 5)
	CastBar.TrackContainer(container)

	local iconFrame = CreateFrame('Frame', nil, container, 'BackdropTemplate')
	iconFrame:SetFrameLevel(container:GetFrameLevel() + 1)

	local icon = iconFrame:CreateTexture(nil, 'ARTWORK')
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local castbar = CreateFrame('StatusBar', nil, container)
	castbar:SetFrameLevel(container:GetFrameLevel() + 2)
	castbar._bossIndex = tonumber(frame.unit and frame.unit:match('%d+')) or 1

	local overlay = CreateFrame('Frame', nil, castbar)
	overlay:SetAllPoints(castbar)
	overlay:SetFrameLevel(castbar:GetFrameLevel() + 10)

	local text = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(text, 12, font)
	text:SetJustifyH('LEFT')
	text:SetJustifyV('MIDDLE')

	local time = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(time, 12, font)
	time:SetJustifyH('RIGHT')
	time:SetJustifyV('MIDDLE')

	castbar.Icon = icon
	castbar.Text = text
	castbar.Time = time
	castbar.timeToHold = 0.5
	castbar._container = container
	castbar._iconFrame = iconFrame

	castbar:HookScript('OnShow', BUI.Profiler.Wrap('CastBar.Boss castbar show', function() container:Show() end))
	castbar:HookScript('OnHide', BUI.Profiler.Wrap('CastBar.Boss castbar hide', function() container:Hide() end))
	castbar.PostCastStart = BossPostCastStart
	castbar.PostCastStop = CastBar.HideInterruptOverlays
	castbar.PostCastInterrupted = BossPostCastInterrupted
	castbar.PostCastInterruptible = BossPostCastInterruptible

	frame._castbarContainer = container
	frame.Castbar = castbar
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
			frame:HookScript('OnSizeChanged', BUI.Profiler.Wrap('CastBar.Boss size wait', function(self)
				if self:GetWidth() > 0 then CastBar.ApplyBossCastbar(self) end
			end))
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

	local backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha = UnpackColor(settings.bgColor, 0.1, 0.1, 0.1, 0.8)
	local borderRed, borderGreen, borderBlue, borderAlpha = UnpackColor(settings.borderColor)
	Pixel.SetTemplate(container, backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha, borderRed, borderGreen, borderBlue, borderAlpha, settings.borderSize)

	if not castbar:IsShown() then container:Hide() end

	castbar:ClearAllPoints()
	castbar:SetPoint('TOPLEFT', container, 'TOPLEFT', edge, -edge)
	castbar:SetPoint('BOTTOMRIGHT', container, 'BOTTOMRIGHT', -edge, edge)
	castbar:SetStatusBarTexture(CastBar.GetTexturePath(settings.texture))

	local barColor = ResolveBossColor(castbar, settings)
	castbar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)

	local iconFrame = castbar._iconFrame
	iconFrame:SetSize(height, height)
	iconFrame:ClearAllPoints()
	iconFrame:SetPoint('RIGHT', container, 'LEFT', -gap, 0)
	if settings.showIcon and settings.borderSize > 0 then
		Pixel.ApplyBorder(iconFrame, settings.borderSize, borderRed, borderGreen, borderBlue, borderAlpha)
		Pixel.ShowBorder(iconFrame)
	else
		Pixel.HideBorder(iconFrame)
	end
	iconFrame:SetShown(settings.showIcon)
	castbar.Icon:SetSize(height - edge * 2, height - edge * 2)
	castbar.Icon:ClearAllPoints()
	castbar.Icon:SetPoint('CENTER', iconFrame)
	castbar.Icon:SetShown(settings.showIcon)

	CastBar.StyleText(castbar, castbar.Text, castbar.Time, settings, CastBar.GetFont(settings.font))
	CastBar.SetupTimeText(castbar, settings)
end
