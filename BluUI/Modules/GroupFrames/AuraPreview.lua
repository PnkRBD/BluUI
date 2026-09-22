local _, BUI = ...
local hooksecurefunc = BUI.Prof.MakeHooker('gfaurapreview')

local GroupFrames = BUI.GroupFrames
local Pixel = BUI.Pixel

local FALLBACK_ICON = 'Interface\\Icons\\INV_Misc_QuestionMark'
local ICON_CROP = 0.08
local MISSING_BUFF_SPELL = 1126

local SAMPLE_SPELLS = {
	buffs        = { 21562, 1459, 6673 },
	debuffs      = { 589, 980, 703 },
	bigDef       = { 642 },
	crowdControl = { 5782, 118 },
	privateAuras = { 8122, 33786, 605, 1776 },
}
local SAMPLE_STACKS = {
	buffs   = { 3, nil, 2 },
	debuffs = { nil, 4, nil },
}
local SAMPLE_DISPEL = {
	debuffs      = { 'Magic', 'Curse', 'Poison' },
	crowdControl = { 'Magic', 'Magic' },
}
local CONTAINER_KINDS = { buffs = true, debuffs = true, bigDef = true, crowdControl = true }

local active = {}

local function Key(sectionKey, kind) return sectionKey .. ':' .. kind end

local function SpellIcon(spellID)
	local texture = spellID and C_Spell.GetSpellTexture(spellID)
	return texture or FALLBACK_ICON
end

local function Growth(anchorPoint, growDirection)
	local horizontal = anchorPoint:find('RIGHT') and 'LEFT' or 'RIGHT'
	local vertical = anchorPoint:find('BOTTOM') and 'UP' or 'DOWN'
	if growDirection == 'LEFT' or growDirection == 'RIGHT' then horizontal = growDirection
	elseif growDirection == 'UP' or growDirection == 'DOWN' then vertical = growDirection end
	return horizontal, vertical
end

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

local function Holder(child, kind, parent, level)
	child._buiAuraSamples = child._buiAuraSamples or {}
	local holder = child._buiAuraSamples[kind]
	if not holder then
		holder = CreateFrame('Frame', nil, parent)
		holder.icons = {}
		holder:EnableMouse(false)
		child._buiAuraSamples[kind] = holder
	end
	holder:SetParent(parent)
	holder:SetFrameStrata(parent:GetFrameStrata())
	holder:SetFrameLevel(child:GetFrameLevel() + level)
	return holder
end

local function LayoutHolder(holder, kind, parent, layout)
	local size = Pixel.Scale(layout.size)
	local gap = Pixel.Scale(layout.spacing or 0)
	local rowGap = Pixel.Scale(layout.rowSpacing or layout.spacing or 0)
	local perRow = math.max(1, layout.perRow or 1)
	local spells = SAMPLE_SPELLS[kind]
	local count = math.max(1, math.min(layout.max or #spells, #spells))
	local growX, growY = Growth(layout.anchorPoint, layout.growDirection)
	local corner = (growY == 'UP' and 'BOTTOM' or 'TOP') .. (growX == 'RIGHT' and 'LEFT' or 'RIGHT')
	local directionX = growX == 'RIGHT' and 1 or -1
	local directionY = growY == 'UP' and 1 or -1
	local columns = math.min(count, perRow)
	local rows = math.ceil(count / perRow)
	local stacks = SAMPLE_STACKS[kind]
	local dispel = SAMPLE_DISPEL[kind]

	holder:SetSize(columns * size + (columns - 1) * gap, rows * size + (rows - 1) * rowGap)
	holder:ClearAllPoints()
	holder:SetPoint(layout.anchorPoint, parent, layout.relativePoint or layout.anchorPoint, Pixel.Scale(layout.offsetX or 0), Pixel.Scale(layout.offsetY or 0))

	for index = 1, count do
		local icon = SampleIcon(holder, index)
		local column = (index - 1) % perRow
		local row = math.floor((index - 1) / perRow)
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint(corner, holder, corner, column * (size + gap) * directionX, row * (size + rowGap) * directionY)
		icon.texture:SetTexture(SpellIcon(spells[index]))
		local dispelType = dispel and dispel[index]
		if dispelType then
			local red, green, blue = BUI.AuraEngine.DispelColorRGB(dispelType)
			Pixel.SetBorderColor(icon, red, green, blue, 1)
		else
			Pixel.SetBorderColor(icon, 0, 0, 0, 1)
		end
		local stack = stacks and stacks[index]
		if stack then
			Pixel.ApplyFont(icon.count, layout.stackSize or 10, STANDARD_TEXT_FONT, 'OUTLINE')
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

local function ApplyContainerSample(child, kind, settings)
	local config = settings[kind]
	if not config then return end
	local holder = Holder(child, kind, child, GroupFrames.Layers.auras + 1)
	LayoutHolder(holder, kind, child, config)
end

local function ApplyPrivateSample(child, settings)
	local config = settings.privateAuras
	if not config then return end
	local host = child.Health or child
	local holder = Holder(child, 'privateAuras', host, GroupFrames.Layers.privateAura + 1)
	local vertical = config.growDirection == 'UP' or config.growDirection == 'DOWN'
	local count = math.max(1, config.num)
	LayoutHolder(holder, 'privateAuras', host, {
		size = config.size, spacing = config.spacing, rowSpacing = config.spacing,
		perRow = vertical and 1 or count, max = count,
		anchorPoint = config.anchorPoint, relativePoint = config.relativePoint,
		growDirection = config.growDirection, offsetX = config.offsetX, offsetY = config.offsetY,
	})
end

local function ApplyMissingSample(child, settings)
	local icon = child.MissingRaidBuff
	if not icon then return end
	icon._buiPreview = true
	GroupFrames.ApplyMissingRaidBuffToChild(child, settings)
	icon.texture:SetTexture(SpellIcon(MISSING_BUFF_SPELL))
	icon:Show()
end

local function ClearSample(child, kind, settings)
	if kind == 'missingRaidBuff' then
		local icon = child.MissingRaidBuff
		if icon and icon._buiPreview then
			icon._buiPreview = nil
			icon:Hide()
			GroupFrames.ApplyMissingRaidBuffToChild(child, settings)
		end
		return
	end
	local holder = child._buiAuraSamples and child._buiAuraSamples[kind]
	if holder then holder:Hide() end
end

local function ApplySample(child, kind, settings)
	if CONTAINER_KINDS[kind] then
		ApplyContainerSample(child, kind, settings)
	elseif kind == 'privateAuras' then
		ApplyPrivateSample(child, settings)
	elseif kind == 'missingRaidBuff' then
		ApplyMissingSample(child, settings)
	end
end

local function ApplyKind(sectionKey, kind, enabled)
	local settings = GroupFrames.GetDB()[sectionKey]
	if not settings then return end
	EachSectionChild(sectionKey, function(child)
		if enabled then ApplySample(child, kind, settings) else ClearSample(child, kind, settings) end
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
	BUI.Prof.After('GroupFrames.AuraPreview', 0, GroupFrames.ReapplyAuraPreviews)
end

hooksecurefunc(GroupFrames, 'RefreshAuras', ReapplyLater)
hooksecurefunc(GroupFrames, 'RefreshMissingRaidBuff', ReapplyLater)
