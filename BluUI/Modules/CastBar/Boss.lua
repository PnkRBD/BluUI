local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('CastBar.Boss')

local CastBar = BUI.CastBar
local Pixel = BUI.Pixel
local UnpackColor = BUI.UnpackColor

local CreateFrame = CreateFrame


local function ResolveBossColor(castbar, settings)
	local barColor = settings.barColor
	if settings.useIndividualColors and settings.bossColors then
		barColor = settings.bossColors[castbar._bossIndex] or barColor
	end
	return barColor
end

local function BossPostCastStart(castbar, unit)
	local settings = CastBar.GetSettings('boss')
	if not settings.enabled then return end
	castbar._interrupted = nil

	local owner = castbar.__owner
	if owner and owner._castbarContainer then
		owner._castbarContainer:Show()
	end

	local barColor = ResolveBossColor(castbar, settings)
	castbar._intBarColor = barColor
	castbar._intInterruptColor = settings.interruptColor or barColor
	castbar._intOnCDColor = settings.interruptOnCDColor or (settings.interruptColor or barColor)
	castbar._intReadyColor = settings.interruptReadyColor
	castbar._ttsAnnounced = nil
	castbar._ttsSoonAnnounced = nil
	castbar._intTTSWant = settings.interruptTTS
	castbar._intTTSText = settings.interruptTTSText
	castbar._intTTSSoonWant = settings.interruptTTSSoon
	castbar._intTTSSoonText = settings.interruptTTSSoonText
	castbar._intTTSSoonWindow = settings.interruptTTSSoonWindow
	CastBar.StartTrackingInterrupts(castbar)
	CastBar.ApplyInterruptColor(castbar, barColor, settings.interruptColor, settings.interruptOnCDColor, settings.interruptReadyColor)
	CastBar.SetupInterruptTick(castbar, settings)
	CastBar.CheckInterruptTTS(castbar)
	CastBar.TruncateSpellName(castbar, settings)
	CastBar.ApplyCastTarget(castbar, settings, unit)
	castbar.Text:SetShown(settings.showSpellName)
	castbar.Time:SetShown(settings.showTimer)
end

local function BossPostCastInterruptible(castbar, unit)
	local settings = CastBar.GetSettings('boss')
	if not settings.enabled then return end
	local barColor = ResolveBossColor(castbar, settings)
	CastBar.ApplyInterruptColor(castbar, barColor, settings.interruptColor or barColor, settings.interruptOnCDColor, settings.interruptReadyColor)
	CastBar.SetupInterruptTick(castbar, settings)
end

function CastBar.CreateBossCastbar(frame)
	local UF = BUI.UnitFrames
	local font = UF.GetFont() or BUI.GetGlobalFont()

	local container = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
	container:SetFrameLevel(frame:GetFrameLevel() + 5)
	frame._castbarContainer = container
	CastBar.TrackContainer(container)

	local iconFrame = CreateFrame('Frame', nil, container, 'BackdropTemplate')
	iconFrame:SetFrameLevel(container:GetFrameLevel() + 1)
	frame._castbarIconFrame = iconFrame

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

	HookScript(castbar, 'OnShow', function() container:Show() end)
	HookScript(castbar, 'OnHide', function() container:Hide() end)
	castbar.PostCastStart = BossPostCastStart
	castbar.PostCastStop = function(bar) CastBar.HideInterruptOverlays(bar) end
	castbar.PostCastInterrupted = function(bar) bar._interrupted = true; CastBar.HideInterruptOverlays(bar); bar:SetStatusBarColor(1, 0, 0, 1) end
	castbar.PostCastInterruptible = BossPostCastInterruptible

	frame.Castbar = castbar
end

function CastBar.ApplyBossCastbar(frame, index)
	local castbar = frame.Castbar
	local container = frame._castbarContainer
	if not castbar or not container then return end

	local settings = CastBar.GetSettings('boss')

	container:SetFrameStrata(settings.frameStrata)
	castbar._bossIndex = index or castbar._bossIndex or 1

	if not settings.enabled then
		if frame.DisableElement then frame:DisableElement('Castbar') end
		container:Hide()
		castbar:Hide()
		return
	end

	if frame:GetWidth() == 0 then
		if not frame._castbarSizeHooked then
			frame._castbarSizeHooked = true
			HookScript(frame, 'OnSizeChanged', function(self)
				if self:GetWidth() > 0 and self.Castbar then
					CastBar.ApplyBossCastbar(self)
				end
			end)
		end
		return
	end

	if frame.EnableElement then frame:EnableElement('Castbar', frame.unit) end

	local texture = CastBar.GetTexturePath(settings.texture)
	local font = CastBar.GetFont(settings.font)
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
	local borderRed, borderGreen, borderBlue, borderAlpha = UnpackColor(settings.borderColor, 0, 0, 0, 1)
	Pixel.SetTemplate(container, backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha, borderRed, borderGreen, borderBlue, borderAlpha, settings.borderSize)

	if not castbar:IsShown() then
		container:Hide()
	end

	castbar:ClearAllPoints()
	castbar:SetPoint('TOPLEFT', container, 'TOPLEFT', edge, -edge)
	castbar:SetPoint('BOTTOMRIGHT', container, 'BOTTOMRIGHT', -edge, edge)
	castbar:SetStatusBarTexture(texture)

	local barColor = ResolveBossColor(castbar, settings)
	castbar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)

	local iconFrame = frame._castbarIconFrame
	if iconFrame then
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
	end

	Pixel.ApplyFont(castbar.Text, settings.textSize, font)
	castbar.Text:ClearAllPoints()
	castbar.Text:SetPoint('LEFT', castbar, 'LEFT', Pixel.Scale(4), 0)

	Pixel.ApplyFont(castbar.Time, settings.textSize, font)
	castbar.Time:ClearAllPoints()
	castbar.Time:SetPoint('RIGHT', castbar, 'RIGHT', Pixel.Scale(-4), 0)

	CastBar.SetupTimeText(castbar, settings)
end
