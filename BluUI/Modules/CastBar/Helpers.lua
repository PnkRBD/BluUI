local _, BUI = ...

BUI.CastBar = {}
local CastBar = BUI.CastBar
local Pixel = BUI.Pixel
local sharedMedia = LibStub('LibSharedMedia-3.0')
local PositionCallbacks = {}

function CastBar.GetTexturePath(key)
	if not key or key == 'GLOBAL' then return BUI.GetGlobalTexture() end
	return sharedMedia:Fetch('statusbar', key) or BUI.GetGlobalTexture()
end

function CastBar.GetFont(key)
	if not key or key == 'GLOBAL' then return BUI.GetGlobalFont() end
	return sharedMedia:Fetch('font', key) or BUI.GetGlobalFont()
end

function CastBar.GetSettings(barType)
	return BUI.GetDB().castBars[barType]
end

function CastBar.SaveSettings(barType, key, value)
	BUI.GetDB().castBars[barType][key] = value
end

do
	local nameCache = {}
	local lastColors

	function CastBar.GetSpellColor(settings, spellID, spellName)
		if not settings.useSpellColors or not settings.spellColors then return nil end
		local colors = settings.spellColors
		if not next(colors) then return nil end

		if spellID then
			local color = colors[spellID]
			if color then return color end
		end

		if spellName then
			if colors ~= lastColors then
				wipe(nameCache)
				for colorKey, color in pairs(colors) do
					if type(colorKey) == 'string' then
						nameCache[colorKey:lower()] = color
					end
				end
				lastColors = colors
			end
			return nameCache[spellName:lower()]
		end
	end
end

function CastBar.RegisterPositionCallback(barType, callback)
	PositionCallbacks[barType] = callback
end

function CastBar.UnregisterPositionCallback(barType)
	PositionCallbacks[barType] = nil
end

function CastBar.FirePositionCallback(barType, x, y)
	local callback = PositionCallbacks[barType]
	if callback then callback(x, y) end
end

local BAR_TYPES = { 'player', 'target', 'focus' }

local function OnAnchorSizeChanged()
	local unitFrames = BUI.UnitFrames
	local castBars = BUI.GetDB().castBars

	for barTypeIndex = 1, #BAR_TYPES do
		local barType = BAR_TYPES[barTypeIndex]
		local settings = castBars[barType]
		if BUI.Anchor.ShouldRefreshOnAnchorChange(settings) then
			local frame = unitFrames[barType]
			if frame then CastBar.RepositionCastbar(frame, barType) end
		end
	end
end

BUI.Anchor.RegisterCallback('CastBar', OnAnchorSizeChanged)

function CastBar.RefreshAll()
	local unitFrames = BUI.UnitFrames
	for barTypeIndex = 1, #BAR_TYPES do
		local frame = unitFrames[BAR_TYPES[barTypeIndex]]
		if frame then CastBar.ApplyCastbar(frame, BAR_TYPES[barTypeIndex]) end
	end
end

Pixel.OnScaleChange('CastBars', CastBar.RefreshAll)
