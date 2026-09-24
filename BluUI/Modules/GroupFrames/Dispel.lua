local _, BUI = ...

local GroupFrames = BUI.GroupFrames
local Pixel  = BUI.Pixel
local Engine = BUI.AuraEngine

local CreateFrame   = CreateFrame
local UnitExists    = UnitExists
local UnitIsVisible = UnitIsVisible
local UnitIsFriend  = UnitIsFriend

local GetUnitAuras           = C_UnitAuras.GetUnitAuras
local GetAuraDispelTypeColor = C_UnitAuras.GetAuraDispelTypeColor

local WHITE8X8 = [[Interface\Buttons\WHITE8X8]]

local DISPEL_RGB = {
	Magic   = { r = 0.20, g = 0.60, b = 1.00 },
	Curse   = { r = 0.60, g = 0.00, b = 1.00 },
	Disease = { r = 0.60, g = 0.40, b = 0.00 },
	Poison  = { r = 0.00, g = 0.60, b = 0.00 },
	Bleed   = { r = 1.00, g = 0.20, b = 0.20 },
	Enrage  = { r = 1.00, g = 0.40, b = 0.00 },
}

local DISPEL_BADGE_ATLAS = {
	Magic   = "RaidFrame-Icon-DebuffMagic",
	Curse   = "RaidFrame-Icon-DebuffCurse",
	Disease = "RaidFrame-Icon-DebuffDisease",
	Poison  = "RaidFrame-Icon-DebuffPoison",
	Bleed   = "RaidFrame-Icon-DebuffBleed",
}

local DISPEL_BADGE_NAMES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }

local TRANSPARENT_COLOR = CreateColor(0, 0, 0, 0)

GroupFrames.DispelViaEngine = Engine.Available and true or false

local HIGHLIGHT_KEY = "BluAura_dispelHL"
GroupFrames.DISPEL_HL_KEY = HIGHLIGHT_KEY

local ANY_DISPEL_TYPES = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true }

function GroupFrames.DispelHighlightWanted(settings)
	local borderSettings = settings.dispelBorder
	return (borderSettings.enabled or borderSettings.tintBar or borderSettings.showBadge ~= false) and true or false
end

local frameKits = setmetatable({}, { __mode = "k" })
local highlightRestyleQueue = {}

local function EdgeSize()
	return Pixel.Scale(Pixel.ClampBorder(1))
end

local function AnchorEdges(kit, frame)
	local edgeThickness = EdgeSize()
	local top, bottom, left, right = kit.edges[1], kit.edges[2], kit.edges[3], kit.edges[4]
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", frame, "TOPLEFT")
	top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -edgeThickness)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, edgeThickness)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -edgeThickness)
	left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", edgeThickness, edgeThickness)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -edgeThickness)
	right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -edgeThickness, edgeThickness)
end

local function AnchorFill(kit, frame)
	local healthTexture = frame.Health and frame.Health:GetStatusBarTexture()
	local fill = kit.fill
	fill:ClearAllPoints()
	if healthTexture then
		fill:SetPoint("TOPLEFT", healthTexture, "TOPLEFT")
		fill:SetPoint("BOTTOMRIGHT", healthTexture, "BOTTOMRIGHT")
	else
		fill:SetAllPoints(frame.Health)
	end
end

local function BuildHighlightKit(host, frame)
	local kit = { edges = {} }
	for edgeIndex = 1, 4 do
		local edge = host:CreateTexture(nil, "OVERLAY", nil, 5)
		edge:SetTexture(WHITE8X8)
		kit.edges[edgeIndex] = edge
	end
	AnchorEdges(kit, frame)

	local fill = host:CreateTexture(nil, "OVERLAY", nil, 1)
	fill:SetTexture(WHITE8X8)
	kit.fill = fill
	AnchorFill(kit, frame)

	local badge = host:CreateTexture(nil, "OVERLAY", nil, 7)
	badge:SetTexture(WHITE8X8)
	kit.badge = badge

	return kit
end

local tintOptions, badgeOptions

local function DispelTextureOptions()
	if tintOptions then return tintOptions, badgeOptions end
	local styleEnum = Enum.CustomAuraButtonDispelTypeTextureStyle
	tintOptions = { showWhenHarmful = true }
	badgeOptions = { showWhenHarmful = true }
	if styleEnum then
		tintOptions.style = styleEnum.PreserveAsset
		badgeOptions.style = styleEnum.Icon
	end
	return tintOptions, badgeOptions
end

local function KitSignature(borderSettings, badgeSettings)
	return (borderSettings.enabled and "b" or "") .. (borderSettings.tintBar and "t" or "") .. (borderSettings.showBadge ~= false and "i" or "")
		.. "#" .. EdgeSize() .. "#" .. badgeSettings.size .. badgeSettings.anchor .. badgeSettings.offsetX .. "," .. badgeSettings.offsetY
end

local function RegisterKitTextures(kit, borderSettings, badgeSettings)
	local button = kit.button
	if not button.AddDispelTypeTexture then return end
	local signature = KitSignature(borderSettings, badgeSettings)
	if kit.signature == signature then return end
	if kit.signature and button.ClearDispelTypeTextures then button:ClearDispelTypeTextures() end
	kit.signature = signature
	local wantBorder, wantTint, wantBadge = borderSettings.enabled, borderSettings.tintBar, borderSettings.showBadge ~= false
	for edgeIndex = 1, 4 do
		if not wantBorder then kit.edges[edgeIndex]:Hide() end
	end
	if not wantTint then kit.fill:Hide() end
	if not wantBadge then kit.badge:Hide() end
	local tint, badge = DispelTextureOptions()
	if wantBorder then
		for edgeIndex = 1, 4 do button:AddDispelTypeTexture(kit.edges[edgeIndex], tint) end
	end
	if wantTint then button:AddDispelTypeTexture(kit.fill, tint) end
	if wantBadge then button:AddDispelTypeTexture(kit.badge, badge) end
end

local function StyleHighlightKit(frame, kit)
	local settings = GroupFrames.SettingsForFrame(frame)
	local borderSettings, badgeSettings = settings.dispelBorder, settings.dispelBadge

	AnchorEdges(kit, frame)
	AnchorFill(kit, frame)
	local badge = kit.badge
	badge:SetSize(Pixel.Scale(badgeSettings.size), Pixel.Scale(badgeSettings.size))
	badge:ClearAllPoints()
	badge:SetPoint(badgeSettings.anchor, frame.Health, badgeSettings.anchor, Pixel.Scale(badgeSettings.offsetX), Pixel.Scale(badgeSettings.offsetY))

	if kit.button then
		RegisterKitTextures(kit, borderSettings, badgeSettings)
		return
	end
	local edgeAlpha = borderSettings.enabled and 1 or 0
	for edgeIndex = 1, 4 do kit.edges[edgeIndex]:SetAlpha(edgeAlpha) end
	kit.fill:SetAlpha(borderSettings.tintBar and 1 or 0)
	badge:SetAlpha(borderSettings.showBadge ~= false and 1 or 0)
end

local function HighlightInitializer(frame)
	return function(button)
		local kit = BuildHighlightKit(button, frame)
		kit.button = button
		local kits = frameKits[frame]
		if not kits then kits = {}; frameKits[frame] = kits end
		kits[#kits + 1] = kit
		StyleHighlightKit(frame, kit)
		if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
		if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
	end
end

function GroupFrames.RestyleDispelHighlight(frame)
	local kits = frameKits[frame]
	if not kits then return end
	if BUI.Tools.ShouldAurasBeSecret() then
		highlightRestyleQueue[frame] = true
		return
	end
	highlightRestyleQueue[frame] = nil
	for kitIndex = 1, #kits do
		StyleHighlightKit(frame, kits[kitIndex])
	end
end

local function DrainHighlightRestyles()
	for frame in pairs(highlightRestyleQueue) do
		highlightRestyleQueue[frame] = nil
		GroupFrames.RestyleDispelHighlight(frame)
	end
end

local function EnsureHighlightGroup(container, frame)
	if not container.AddAuraGroup then return end
	local settings = GroupFrames.SettingsForFrame(frame)
	local source = settings.dispelBorder.source == "all" and "all" or "mine"

	local exclude
	for spellID in pairs(BUI.AuraBlacklist.GroupSet("HARMFUL")) do
		exclude = exclude or {}
		exclude[spellID] = true
	end

	local fingerprint = source .. "#" .. (exclude and Engine.SortedKeys(exclude) or "")
	local groups = container._hlGroups
	local info = groups[fingerprint]

	for key, other in pairs(groups) do
		if key ~= fingerprint and other.active then
			other.active = false
			if container.SetAuraGroupMaxFrameCount then
				container:SetAuraGroupMaxFrameCount(other.key, 0)
			end
		end
	end

	if info then
		if not info.active then
			info.active = true
			if container.SetAuraGroupMaxFrameCount then
				container:SetAuraGroupMaxFrameCount(info.key, 1)
			end
		end
		return
	end

	local filter = "HARMFUL|RAID_PLAYER_DISPELLABLE"
	local candidates = exclude and { excludeSpellIDs = exclude } or nil
	if source == "all" then
		filter = "HARMFUL"
		candidates = candidates or {}
		candidates.includeDispelTypes = ANY_DISPEL_TYPES
	end

	container._hlSeq = (container._hlSeq or 0) + 1
	local key = "hl" .. container._hlSeq
	container:AddAuraGroup(key, filter, {
		maxFrameCount = 1,
		initializeFrame = HighlightInitializer(frame),
		candidateFilters = candidates,
	})
	groups[fingerprint] = { key = key, active = true }
end

function GroupFrames.EnsureDispelHighlight(frame)
	if not GroupFrames.DispelViaEngine or not frame.Health then return nil end
	local container = frame[HIGHLIGHT_KEY]
	if not container then
		container = Engine.NewContainer(frame.Health, true, 3)
		container:SetPoint("TOPLEFT", frame, "TOPLEFT")
		container._hlGroups = {}
		frame[HIGHLIGHT_KEY] = container
	end
	return container
end

function GroupFrames.ConfigureDispelHighlight(frame)
	local container = GroupFrames.EnsureDispelHighlight(frame)
	if not container then return end
	local settings = GroupFrames.SettingsForFrame(frame)
	if not GroupFrames.DispelHighlightWanted(settings) or (frame._preview and not frame._dispelPreview) then
		container:Hide()
		Engine.BindUnit(container, nil)
		return
	end
	EnsureHighlightGroup(container, frame)
	GroupFrames.RestyleDispelHighlight(frame)
	if not frame._dispelPreview then
		container:SetShown(frame._bluAurasVisible ~= false)
	end
	Engine.BindUnit(container, frame.unit)
end

if GroupFrames.DispelViaEngine then
	BUI.Events:Register("PLAYER_REGEN_ENABLED", "GFDispel.RestyleDrain", DrainHighlightRestyles)
	BUI.Events:Register("PLAYER_ENTERING_WORLD", "GFDispel.RestyleDrain", DrainHighlightRestyles)
end

local dispelCurve, dispelCurveStamp
local function GetDispelCurve()
	if not dispelCurve or dispelCurveStamp ~= Engine.DispelPaletteStamp() then
		dispelCurve, dispelCurveStamp = GroupFrames.BuildDispelCurve(TRANSPARENT_COLOR)
	end
	return dispelCurve
end

local SOLID = CreateColor(1, 1, 1, 1)
local CLEAR = CreateColor(1, 1, 1, 0)

local function MakeTypeCurve(match)
	local curve = C_CurveUtil.CreateColorCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	for _, dispelIndex in ipairs({ 0, 1, 2, 3, 4, 9, 11 }) do
		curve:AddPoint(dispelIndex, match[dispelIndex] and SOLID or CLEAR)
	end
	return curve
end

local ICON_CURVES
local function GetIconCurves()
	if ICON_CURVES then return ICON_CURVES end
	ICON_CURVES = {
		Magic   = MakeTypeCurve({ [1] = true }),
		Curse   = MakeTypeCurve({ [2] = true }),
		Disease = MakeTypeCurve({ [3] = true }),
		Poison  = MakeTypeCurve({ [4] = true }),
		Bleed   = MakeTypeCurve({ [9] = true, [11] = true }),
	}
	return ICON_CURVES
end

local function colorFromCurve(unit, auraInstanceID)
	if not auraInstanceID then return nil end
	return GetAuraDispelTypeColor(unit, auraInstanceID, GetDispelCurve())
end

local function FindDispelColor(unit, source)
	if not UnitIsFriend("player", unit) then return nil, nil end

	local mine = GetUnitAuras(unit, "HARMFUL|RAID_PLAYER_DISPELLABLE", 40, 0, 0)
	if mine then
		for auraIndex = 1, #mine do
			local aura = mine[auraIndex]
			if not GroupFrames.IsBlacklistedDebuff(aura.spellId) and aura.auraInstanceID then
				local color = colorFromCurve(unit, aura.auraInstanceID)
				if color then return color, aura.auraInstanceID end
			end
		end
	end

	if source ~= "all" then return nil, nil end

	local any = GetUnitAuras(unit, "HARMFUL", 40, 0, 0)
	if any then
		for auraIndex = 1, #any do
			local aura = any[auraIndex]
			if not GroupFrames.IsBlacklistedDebuff(aura.spellId) and aura.auraInstanceID and aura.dispelName ~= nil then
				local color = colorFromCurve(unit, aura.auraInstanceID)
				if color then return color, aura.auraInstanceID end
			end
		end
	end
	return nil, nil
end

function GroupFrames.ApplyDispelBadgeStyle(badge, frame)
	local badgeSettings = GroupFrames.SettingsForFrame(frame).dispelBadge
	badge:SetSize(Pixel.Scale(badgeSettings.size), Pixel.Scale(badgeSettings.size))
	badge:ClearAllPoints()
	badge:SetPoint(badgeSettings.anchor, frame.Health, badgeSettings.anchor, Pixel.Scale(badgeSettings.offsetX), Pixel.Scale(badgeSettings.offsetY))
end

function GroupFrames.RestyleAllDispelBadges()
	GroupFrames.EachChild(function(child)
		if GroupFrames.DispelViaEngine then
			GroupFrames.RestyleDispelHighlight(child)
			local previewKit = child._dispelPreviewKit
			if previewKit and previewKit.host:IsShown() then StyleHighlightKit(child, previewKit.kit) end
		end
		if child.DispelBadge then GroupFrames.ApplyDispelBadgeStyle(child.DispelBadge, child) end
	end)
end

local function EnsureDispelTextures(frame)
	local healthBar = frame.Health
	if not healthBar then return end

	if not frame.DispelBadge then
		local badge = CreateFrame("Frame", nil, healthBar)
		badge:SetFrameLevel(healthBar:GetFrameLevel() + 3)
		badge:EnableMouse(false)
		badge:Hide()
		badge.icons = {}
		for _, name in ipairs(DISPEL_BADGE_NAMES) do
			local texture = badge:CreateTexture(nil, "OVERLAY", nil, 7)
			texture:SetAllPoints(badge)
			texture:SetAtlas(DISPEL_BADGE_ATLAS[name])
			texture:Hide()
			badge.icons[name] = texture
		end
		frame.DispelBadge = badge
	end
	GroupFrames.ApplyDispelBadgeStyle(frame.DispelBadge, frame)
end

local function HideDispelTextures(frame)
	if frame.DispelBadge then frame.DispelBadge:Hide() end
end

local function RepaintHealth(frame, unit)
	if frame.Health and frame.Health.PostUpdateColor then
		frame.Health.PostUpdateColor(frame.Health, unit)
	end
end

local function RestoreFrameBorder(frame)
	local borderColor = GroupFrames.SettingsForFrame(frame).borderColor
	frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end

function GroupFrames.ApplyDispelBadgeIcons(badge, unit, auraInstanceID)
	if not badge or not badge.icons or not auraInstanceID then return end
	local curves = GetIconCurves()
	for _, name in ipairs(DISPEL_BADGE_NAMES) do
		local texture = badge.icons[name]
		local color   = GetAuraDispelTypeColor(unit, auraInstanceID, curves[name])
		if texture and color then
			texture:SetVertexColor(color:GetRGBA())
			texture:Show()
		elseif texture then
			texture:Hide()
		end
	end
end

function GroupFrames.ApplyDispelBadgePreview(badge, typeName)
	if not badge or not badge.icons then return end
	local key = (typeName == "Enrage") and "Bleed" or typeName
	for _, name in ipairs(DISPEL_BADGE_NAMES) do
		local texture = badge.icons[name]
		if texture and name == key then
			texture:SetVertexColor(1, 1, 1, 1)
			texture:Show()
		elseif texture then
			texture:Hide()
		end
	end
end

function GroupFrames.UpdateDispelBorder(frame, unit)
	if GroupFrames.DispelViaEngine then return end
	if frame._dispelPreview then return end
	if frame._preview then
		HideDispelTextures(frame)
		if frame._dispelColor then
			frame._dispelColor = nil
			RestoreFrameBorder(frame)
		end
		return
	end
	local borderSettings = GroupFrames.SettingsForFrame(frame).dispelBorder

	if not unit or not UnitExists(unit) or not UnitIsVisible(unit) then
		HideDispelTextures(frame)
		if frame._dispelColor then
			frame._dispelColor = nil
			RestoreFrameBorder(frame)
			RepaintHealth(frame, unit)
		end
		return
	end

	local wantBorder = borderSettings.enabled
	local wantBadge  = borderSettings.showBadge ~= false
	local wantTint   = borderSettings.tintBar

	if not wantBorder and not wantBadge and not wantTint then
		if frame._dispelColor then
			HideDispelTextures(frame)
			frame._dispelColor = nil
			RestoreFrameBorder(frame)
			RepaintHealth(frame, unit)
		end
		return
	end

	if BUI.Tools.ShouldAurasBeSecret() or BUI.Tools.AuraQueriesBlocked() then return end

	local colorObj, auraInstanceID = FindDispelColor(unit, borderSettings.source)
	if colorObj then
		frame._dispelColor = colorObj
		if wantBorder then
			frame:SetBackdropBorderColor(colorObj:GetRGBA())
		else
			RestoreFrameBorder(frame)
		end
		EnsureDispelTextures(frame)
		if wantBadge and auraInstanceID then
			GroupFrames.ApplyDispelBadgeIcons(frame.DispelBadge, unit, auraInstanceID)
			frame.DispelBadge:Show()
		else
			frame.DispelBadge:Hide()
		end
		RepaintHealth(frame, unit)
	elseif frame._dispelColor then
		HideDispelTextures(frame)
		frame._dispelColor = nil
		RestoreFrameBorder(frame)
		RepaintHealth(frame, unit)
	end
end

local function EnsurePreviewKit(frame)
	local previewKit = frame._dispelPreviewKit
	if previewKit then return previewKit end
	local host = CreateFrame("Frame", nil, frame.Health)
	host:SetFrameLevel(frame.Health:GetFrameLevel() + 3)
	host:EnableMouse(false)
	host:Hide()
	previewKit = { host = host, kit = BuildHighlightKit(host, frame) }
	frame._dispelPreviewKit = previewKit
	return previewKit
end

local function PaintPreviewKit(frame, previewKit, typeName)
	StyleHighlightKit(frame, previewKit.kit)
	local dispelRGB = DISPEL_RGB[typeName]
	local kit = previewKit.kit
	for edgeIndex = 1, 4 do kit.edges[edgeIndex]:SetVertexColor(dispelRGB.r, dispelRGB.g, dispelRGB.b) end
	kit.fill:SetVertexColor(dispelRGB.r, dispelRGB.g, dispelRGB.b)
	local atlas = DISPEL_BADGE_ATLAS[(typeName == "Enrage") and "Bleed" or typeName]
	if atlas then
		kit.badge:SetAtlas(atlas)
		kit.badge:SetVertexColor(1, 1, 1, 1)
	end
end

local function ApplyDispelPreview(frame, dispelName)
	if not frame then return false, "no frame" end

	if GroupFrames.DispelViaEngine then
		if not dispelName or dispelName == "off" then
			frame._dispelPreview = nil
			if frame._dispelPreviewKit then frame._dispelPreviewKit.host:Hide() end
			if frame._auraWatcher then GroupFrames.ConfigureDispelHighlight(frame) end
			return true
		end
		local dispelRGB = DISPEL_RGB[dispelName]
		if not dispelRGB then return false, "unknown type: " .. tostring(dispelName) end
		frame._dispelPreview = true
		if frame[HIGHLIGHT_KEY] then frame[HIGHLIGHT_KEY]:Hide() end
		local previewKit = EnsurePreviewKit(frame)
		PaintPreviewKit(frame, previewKit, dispelName)
		previewKit.host:Show()
		return true
	end

	if not dispelName or dispelName == "off" then
		frame._dispelPreview = nil
		HideDispelTextures(frame)
		frame._dispelColor = nil
		RestoreFrameBorder(frame)
		RepaintHealth(frame, frame.unit)
		return true
	end

	local dispelRGB = DISPEL_RGB[dispelName]
	if not dispelRGB then return false, "unknown type: " .. tostring(dispelName) end
	local color = CreateColor(dispelRGB.r, dispelRGB.g, dispelRGB.b, 1)

	local borderSettings = GroupFrames.SettingsForFrame(frame).dispelBorder
	local wantBorder = borderSettings.enabled
	local wantBadge  = borderSettings.showBadge ~= false

	frame._dispelPreview = true
	frame._dispelColor = color
	if wantBorder then
		frame:SetBackdropBorderColor(color:GetRGBA())
	else
		RestoreFrameBorder(frame)
	end
	EnsureDispelTextures(frame)
	if wantBadge then
		GroupFrames.ApplyDispelBadgePreview(frame.DispelBadge, dispelName)
		frame.DispelBadge:Show()
	else
		frame.DispelBadge:Hide()
	end
	RepaintHealth(frame, frame.unit)
	return true
end

function GroupFrames.PreviewDispelOnAllParty(startIndex)
	startIndex = startIndex or 1
	local types = { "Magic", "Curse", "Disease", "Poison", "Bleed", "Enrage" }
	local memberIndex = 0
	GroupFrames.EachChild(function(child)
		if not child.unit then return end
		local typeName = types[((startIndex - 1 + memberIndex) % #types) + 1]
		ApplyDispelPreview(child, typeName)
		memberIndex = memberIndex + 1
	end)
	return true
end

function GroupFrames.ClearAllDispelPreviews()
	GroupFrames.EachChild(function(child)
		if child.unit then ApplyDispelPreview(child, "off") end
	end)
end

local DISPEL_INTERVAL = 1.5
local cycleIndex = 0
local cycleTicker

local function StopCycle()
	if cycleTicker then cycleTicker:Cancel(); cycleTicker = nil end
	GroupFrames.ClearAllDispelPreviews()
end

local function StepCycle()
	cycleIndex = cycleIndex + 1
	GroupFrames.PreviewDispelOnAllParty(cycleIndex)
	GroupFrames.Print("Party dispel preview: shift " .. cycleIndex)
end

function GroupFrames.StartDispelPartyPreview()
	StopCycle()
	cycleIndex = 0
	StepCycle()
	cycleTicker = C_Timer.NewTicker(DISPEL_INTERVAL, StepCycle)
	GroupFrames.Print("Party dispel preview started. Click again to stop.")
end

function GroupFrames.StopDispelPreview() StopCycle() end
function GroupFrames.IsDispelPreviewActive() return cycleTicker ~= nil end
