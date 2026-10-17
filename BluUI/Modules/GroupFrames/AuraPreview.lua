local _, BUI = ...

local Hook = BUI.Profiler.Hooker('GroupFrames.AuraPreview')

local GroupFrames = BUI.GroupFrames
local Util = GroupFrames.Util
local Pixel = BUI.Pixel

local FALLBACK_ICON = 'Interface\\Icons\\INV_Misc_QuestionMark'
local ICON_CROP = 0.08

local SAMPLE_SPELLS = {
	buffs        = { 21562, 1459, 6673 },
	debuffs      = { 589, 980, 703 },
	bigDef       = { 642 },
	crowdControl = { 5782, 118 },
}
local SAMPLE_STACKS = {
	buffs   = { 3, nil, 2 },
	debuffs = { nil, 4, nil },
}
local SAMPLE_DISPEL = {
	debuffs      = { 'Magic', 'Curse', 'Poison' },
	crowdControl = { 'Magic', 'Magic' },
}

local active = {}

local function Key(sectionKey, kind) return sectionKey .. ':' .. kind end

local function EachSectionChild(sectionKey, callback)
	if sectionKey == 'party' then GroupFrames.EachPartyChild(callback) else GroupFrames.EachRaidChild(callback) end
end

local function SampleIcon(holder, index)
	local icon = holder.icons[index]
	if icon then return icon end
	icon = CreateFrame('Frame', nil, holder)
	Pixel.SetTemplate(icon, 0, 0, 0, 1, 0, 0, 0, 1, 1)
	local edge = Pixel.PixelSize(1)
	icon.texture = icon:CreateTexture(nil, 'ARTWORK')
	icon.texture:SetPoint('TOPLEFT', edge, -edge)
	icon.texture:SetPoint('BOTTOMRIGHT', -edge, edge)
	icon.texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	icon.count = icon:CreateFontString(nil, 'OVERLAY')
	icon.count:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', -1, 1)
	holder.icons[index] = icon
	return icon
end

local function Holder(child, kind)
	child._buiAuraSamples = child._buiAuraSamples or {}
	local holder = child._buiAuraSamples[kind]
	if not holder then
		holder = CreateFrame('Frame', nil, child)
		holder.icons = {}
		holder:EnableMouse(false)
		holder:SetFrameLevel(child:GetFrameLevel() + GroupFrames.Layers.auras + 1)
		child._buiAuraSamples[kind] = holder
	end
	return holder
end

local function LayoutHolder(holder, kind, child, layout)
	local size = Pixel.Scale(layout.size)
	local gap = Pixel.Scale(layout.spacing)
	local rowGap = Pixel.Scale(layout.rowSpacing)
	local perRow = math.max(1, layout.perRow)
	local spells = SAMPLE_SPELLS[kind]
	local count = math.max(1, layout.max)
	local growX, growY = Util.ResolveGrowth(layout.anchorPoint, layout.growDirection)
	local corner = (growY == 'UP' and 'BOTTOM' or 'TOP') .. (growX == 'RIGHT' and 'LEFT' or 'RIGHT')
	local directionX = growX == 'RIGHT' and 1 or -1
	local directionY = growY == 'UP' and 1 or -1
	local columns = math.min(count, perRow)
	local rows = math.ceil(count / perRow)
	local stacks = SAMPLE_STACKS[kind]
	local dispel = SAMPLE_DISPEL[kind]

	holder:SetSize(columns * size + (columns - 1) * gap, rows * size + (rows - 1) * rowGap)
	holder:ClearAllPoints()
	holder:SetPoint(layout.anchorPoint, child, layout.relativePoint, Pixel.Scale(layout.offsetX), Pixel.Scale(layout.offsetY))

	for index = 1, count do
		local icon = SampleIcon(holder, index)
		local column = (index - 1) % perRow
		local row = math.floor((index - 1) / perRow)
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint(corner, holder, corner, column * (size + gap) * directionX, row * (size + rowGap) * directionY)
		local sample = (index - 1) % #spells + 1
		icon.texture:SetTexture(C_Spell.GetSpellTexture(spells[sample]) or FALLBACK_ICON)
		local dispelType = dispel and dispel[sample]
		if dispelType then
			local red, green, blue = BUI.AuraEngine.DispelColorRGB(dispelType)
			Pixel.SetBorderColor(icon, red, green, blue, 1)
		else
			Pixel.SetBorderColor(icon, 0, 0, 0, 1)
		end
		local stack = stacks and stacks[sample]
		if stack then
			Pixel.ApplyFont(icon.count, layout.stackSize, STANDARD_TEXT_FONT, 'OUTLINE')
			icon.count:SetText(stack)
			icon.count:Show()
		else
			icon.count:Hide()
		end
		icon:Show()
	end
	for index = count + 1, #holder.icons do holder.icons[index]:Hide() end
	holder:Show()
end

local function ApplySample(child, kind, settings)
	LayoutHolder(Holder(child, kind), kind, child, settings[kind])
end

local function ClearSample(child, kind)
	local holder = child._buiAuraSamples and child._buiAuraSamples[kind]
	if holder then holder:Hide() end
end

local function ApplyKind(sectionKey, kind, enabled)
	local settings = GroupFrames.GetDB()[sectionKey]
	EachSectionChild(sectionKey, function(child)
		if enabled then ApplySample(child, kind, settings) else ClearSample(child, kind) end
	end)
end

local function ForceFramesShown(sectionKey)
	if sectionKey == 'party' then
		if not GroupFrames.IsPartyPreviewShown() and not IsInGroup() then GroupFrames.SetPartyPreview(true) end
	elseif not GroupFrames.IsRaidPreviewShown() and not IsInRaid() then
		GroupFrames.SetRaidPreview(true)
	end
end

function GroupFrames.PreviewAuraKind(sectionKey, kind, enabled)
	local key = Key(sectionKey, kind)
	if enabled then
		active[key] = { section = sectionKey, kind = kind }
		ForceFramesShown(sectionKey)
	else
		active[key] = nil
	end
	ApplyKind(sectionKey, kind, enabled and true or false)
end

function GroupFrames.IsAuraPreviewing(sectionKey, kind)
	return active[Key(sectionKey, kind)] ~= nil
end

function GroupFrames.ReapplyAuraPreviews()
	for _, entry in pairs(active) do ApplyKind(entry.section, entry.kind, true) end
end

function GroupFrames.ClearAuraPreviews()
	local entries = {}
	for key, entry in pairs(active) do entries[#entries + 1] = entry; active[key] = nil end
	for index = 1, #entries do ApplyKind(entries[index].section, entries[index].kind, false) end
end

local function ReapplyLater()
	if next(active) == nil then return end
	BUI.Profiler.After('GroupFrames.AuraPreview reapply', 0, GroupFrames.ReapplyAuraPreviews)
end

Hook(GroupFrames, 'RefreshAuras', ReapplyLater)
