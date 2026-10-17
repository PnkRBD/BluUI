local _, BUI = ...

BUI.CastBar = {}
local CastBar = BUI.CastBar
local Pixel = BUI.Pixel
local sharedMedia = LibStub('LibSharedMedia-3.0')

local BAR_TYPES = { 'player', 'target', 'focus' }

function CastBar.GetTexturePath(key)
	if key == BUI.C.GLOBAL_OPTION then return BUI.GetGlobalTexture() end
	return sharedMedia:Fetch('statusbar', key)
end

CastBar.GetFont = BUI.GetFontByName

function CastBar.GetSettings(barType)
	return BUI.GetDB().castBars[barType]
end

BUI.Anchor.RegisterCallback('CastBar', function()
	for _, barType in ipairs(BAR_TYPES) do
		local frame = BUI.UnitFrames[barType]
		if frame and BUI.Anchor.ShouldRefreshOnAnchorChange(CastBar.GetSettings(barType)) then
			CastBar.RepositionCastbar(frame, barType)
		end
	end
end)

function CastBar.RefreshAll()
	for _, barType in ipairs(BAR_TYPES) do
		local frame = BUI.UnitFrames[barType]
		if frame then CastBar.ApplyCastbar(frame, barType) end
	end
end

Pixel.OnScaleChange('CastBars', CastBar.RefreshAll)
