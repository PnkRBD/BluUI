local _, BUI = ...

local GroupFrames = BUI.GroupFrames
local Pixel  = BUI.Pixel
local Engine = BUI.AuraEngine

local CreateFrame = CreateFrame

local WHITE8X8 = [[Interface\Buttons\WHITE8X8]]

local PREVIEW_TOKEN = {
	Magic   = "Magic",
	Curse   = "Curse",
	Disease = "Disease",
	Poison  = "Poison",
	Bleed   = "Bleed",
	Enrage  = "Bleed",
}

local DISPEL_BADGE_ATLAS = {
	Magic   = "RaidFrame-Icon-DebuffMagic",
	Curse   = "RaidFrame-Icon-DebuffCurse",
	Disease = "RaidFrame-Icon-DebuffDisease",
	Poison  = "RaidFrame-Icon-DebuffPoison",
	Bleed   = "RaidFrame-Icon-DebuffBleed",
}

local PREVIEW_CYCLE = { "Magic", "Curse", "Disease", "Poison", "Bleed", "Enrage" }

local TRANSPARENT_COLOR = CreateColor(0, 0, 0, 0)

local HIGHLIGHT_KEY = "BluAura_dispelHL"
GroupFrames.DISPEL_HL_KEY = HIGHLIGHT_KEY

local ANY_DISPEL_TYPES = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true }

function GroupFrames.DispelLook(settings)
	local border = settings.dispelBorder
	if border.matchPlayer then
		local player = BUI.UnitFrames.GetUnitSettings("player")
		return player.debuffHighlightBar, player.debuffHighlightStyle
	end
	return border.tintBar, border.tintStyle
end

function GroupFrames.DispelHighlightWanted(settings)
	return GroupFrames.DispelLook(settings) or settings.dispelBorder.showBadge
end

local frameKits = setmetatable({}, { __mode = "k" })
local highlightRestyleQueue = {}

local function AnchorFill(kit, frame, alpha)
	local settings = GroupFrames.SettingsForFrame(frame)
	local _, style = GroupFrames.DispelLook(settings)
	local absorb = BUI.UnitFrames.OverlappingAbsorb(frame, settings.absorb.enabled, settings.absorb.direction, settings.healAbsorb.enabled, settings.healAbsorb.direction)
	BUI.UnitFrames.AnchorDispelFill(kit, frame, style, absorb, alpha, BUI.UnitFrames.FillDirection(settings.fillDirection))
end

local function BuildHighlightKit(host)
	local kit = {}
	kit.fill = host:CreateTexture(nil, "OVERLAY", nil, 1)
	kit.fade = host:CreateTexture(nil, "OVERLAY", nil, 1)

	local badge = host:CreateTexture(nil, "OVERLAY", nil, 7)
	badge:SetTexture(WHITE8X8)
	kit.badge = badge

	return kit
end

local dispelCurve, dispelCurveStamp
local function GetDispelCurve()
	if not dispelCurve or dispelCurveStamp ~= Engine.DispelPaletteStamp() then
		dispelCurve, dispelCurveStamp = Engine.BuildDispelCurve(TRANSPARENT_COLOR)
	end
	return dispelCurve, dispelCurveStamp
end

local tintOptions  = { showWhenHarmful = true, style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset }
local badgeOptions = { showWhenHarmful = true, style = Enum.CustomAuraButtonDispelTypeTextureStyle.Icon }

local function KitSignature(wantTint, wantBadge, badgeSettings, paletteStamp)
	return (wantTint and "t" or "") .. (wantBadge and "i" or "")
		.. "#" .. badgeSettings.size .. badgeSettings.anchor .. badgeSettings.offsetX .. "," .. badgeSettings.offsetY
		.. "#" .. paletteStamp
end

local function RegisterKitTextures(kit, wantTint, wantBadge, badgeSettings)
	local button = kit.button
	local curve, paletteStamp = GetDispelCurve()
	local signature = KitSignature(wantTint, wantBadge, badgeSettings, paletteStamp)
	if kit.signature == signature then return end
	if kit.signature then button:ClearDispelTypeTextures() end
	kit.signature = signature
	if not wantTint then
		kit.fill:Hide()
		kit.fade:Hide()
	end
	if not wantBadge then kit.badge:Hide() end
	tintOptions.customDispelColorCurve = curve
	if wantTint then
		button:AddDispelTypeTexture(kit.fill, tintOptions)
		button:AddDispelTypeTexture(kit.fade, tintOptions)
	end
	if wantBadge then button:AddDispelTypeTexture(kit.badge, badgeOptions) end
end

local function StyleHighlightKit(frame, kit)
	local settings = GroupFrames.SettingsForFrame(frame)
	local badgeSettings = settings.dispelBadge
	local wantTint = GroupFrames.DispelLook(settings)
	local wantBadge = settings.dispelBorder.showBadge

	local opacity = BUI.UnitFrames.GetSettings().dispelOpacity / 100
	AnchorFill(kit, frame, (kit.button or wantTint) and opacity or 0)
	local badge = kit.badge
	badge:SetSize(Pixel.Scale(badgeSettings.size), Pixel.Scale(badgeSettings.size))
	badge:ClearAllPoints()
	badge:SetPoint(badgeSettings.anchor, frame.Health, badgeSettings.anchor, Pixel.Scale(badgeSettings.offsetX), Pixel.Scale(badgeSettings.offsetY))

	if kit.button then
		RegisterKitTextures(kit, wantTint, wantBadge, badgeSettings)
		return
	end
	badge:SetAlpha(wantBadge and 1 or 0)
end

local function HighlightInitializer(frame)
	return function(button)
		local kit = BuildHighlightKit(button)
		kit.button = button
		local kits = frameKits[frame]
		if not kits then kits = {}; frameKits[frame] = kits end
		kits[#kits + 1] = kit
		StyleHighlightKit(frame, kit)
		button:SetMouseClickEnabled(false)
		button:SetMouseMotionEnabled(false)
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

BUI.Tools.OnAuraQueriesUnblocked(DrainHighlightRestyles, 'Group frame dispel highlight')

local excludeSource, excludeSet, excludeSignature

local function HighlightExcludes()
	local blacklist = BUI.AuraBlacklist.GroupSet("HARMFUL")
	if excludeSource ~= blacklist then
		excludeSource = blacklist
		excludeSet = next(blacklist) and blacklist or nil
		excludeSignature = excludeSet and Engine.SortedKeys(excludeSet) or ""
	end
	return excludeSet, excludeSignature
end

local function EnsureHighlightGroup(container, frame)
	local source = GroupFrames.SettingsForFrame(frame).dispelBorder.source
	local exclude, signature = HighlightExcludes()
	local fingerprint = source .. "#" .. signature
	local groups = container._hlGroups
	local info = groups[fingerprint]

	for key, other in pairs(groups) do
		if key ~= fingerprint and other.active then
			other.active = false
			container:SetAuraGroupMaxFrameCount(other.key, 0)
		end
	end

	if info then
		if not info.active then
			info.active = true
			container:SetAuraGroupMaxFrameCount(info.key, 1)
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

	container._hlSeq = container._hlSeq + 1
	local key = "hl" .. container._hlSeq
	container:AddAuraGroup(key, filter, {
		maxFrameCount = 1,
		initializeFrame = HighlightInitializer(frame),
		candidateFilters = candidates,
	})
	groups[fingerprint] = { key = key, active = true }
end

local function EnsureHighlightContainer(frame)
	local container = frame[HIGHLIGHT_KEY]
	if not container then
		container = Engine.NewContainer(frame.Health, true, 3)
		container:SetPoint("TOPLEFT", frame, "TOPLEFT")
		container._hlGroups = {}
		container._hlSeq = 0
		frame[HIGHLIGHT_KEY] = container
	end
	return container
end

function GroupFrames.ConfigureDispelHighlight(frame)
	local container = EnsureHighlightContainer(frame)
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

function GroupFrames.RestyleAllDispelBadges()
	GroupFrames.EachChild(function(child)
		GroupFrames.RestyleDispelHighlight(child)
		local previewKit = child._dispelPreviewKit
		if previewKit and previewKit.host:IsShown() then StyleHighlightKit(child, previewKit.kit) end
	end)
end

local function EnsurePreviewKit(frame)
	local previewKit = frame._dispelPreviewKit
	if previewKit then return previewKit end
	local host = CreateFrame("Frame", nil, frame.Health)
	host:SetFrameLevel(frame.Health:GetFrameLevel() + 3)
	host:EnableMouse(false)
	host:Hide()
	previewKit = { host = host, kit = BuildHighlightKit(host) }
	frame._dispelPreviewKit = previewKit
	return previewKit
end

local function PaintPreviewKit(frame, previewKit, typeName)
	StyleHighlightKit(frame, previewKit.kit)
	local token = PREVIEW_TOKEN[typeName]
	local red, green, blue = Engine.DispelColorRGB(token)
	local kit = previewKit.kit
	kit.fill:SetVertexColor(red, green, blue)
	kit.fade:SetVertexColor(red, green, blue)
	kit.badge:SetAtlas(DISPEL_BADGE_ATLAS[token])
	kit.badge:SetVertexColor(1, 1, 1, 1)
end

local function ApplyDispelPreview(frame, dispelName)
	if dispelName == "off" then
		frame._dispelPreview = nil
		if frame._dispelPreviewKit then frame._dispelPreviewKit.host:Hide() end
		GroupFrames.RefreshDispelBorder(frame)
		return
	end
	frame._dispelPreview = true
	if frame[HIGHLIGHT_KEY] then frame[HIGHLIGHT_KEY]:Hide() end
	local previewKit = EnsurePreviewKit(frame)
	PaintPreviewKit(frame, previewKit, dispelName)
	previewKit.host:Show()
end

local function PreviewDispelOnAllParty(startIndex)
	local memberIndex = 0
	GroupFrames.EachChild(function(child)
		if not child.unit then return end
		ApplyDispelPreview(child, PREVIEW_CYCLE[((startIndex - 1 + memberIndex) % #PREVIEW_CYCLE) + 1])
		memberIndex = memberIndex + 1
	end)
end

local function ClearAllDispelPreviews()
	GroupFrames.EachChild(function(child)
		if child.unit then ApplyDispelPreview(child, "off") end
	end)
end

local DISPEL_INTERVAL = 1.5
local cycleIndex = 0
local cycleTicker

local function StopCycle()
	if cycleTicker then cycleTicker:Cancel(); cycleTicker = nil end
	ClearAllDispelPreviews()
end

local function StepCycle()
	cycleIndex = cycleIndex + 1
	PreviewDispelOnAllParty(cycleIndex)
end
local StepCycleTimed = BUI.Profiler.Wrap("GroupFrames.Dispel preview cycle", StepCycle)

function GroupFrames.StartDispelPartyPreview()
	StopCycle()
	cycleIndex = 0
	StepCycle()
	cycleTicker = C_Timer.NewTicker(DISPEL_INTERVAL, StepCycleTimed)
end

function GroupFrames.StopDispelPreview() StopCycle() end
function GroupFrames.IsDispelPreviewActive() return cycleTicker ~= nil end
