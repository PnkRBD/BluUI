local _, BUI = ...

local GroupFrames = BUI.GroupFrames
local Engine = BUI.AuraEngine
local Pixel = BUI.Pixel

local HotSlots = {}
GroupFrames.HotSlots = HotSlots

HotSlots.SPECS = { 105, 1468, 270, 65, 256, 257, 264 }

local FILTER = 'HELPFUL|PLAYER'
local SLOT_PREFIX = 'bluHot'
local NO_SPELLS = { includeSpellIDs = {} }
local WHITE8X8 = 'Interface\\Buttons\\WHITE8X8'
local BORDER = { 0, 0, 0, 1 }
local GROWTH = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

local spellSets = setmetatable({}, { __mode = 'k' })
local activeEntries, activeSet, activeSignature
local specUnresolved = false
local pending = {}

local function CopyEntry(entry)
	local copy = { id = entry.id, color = { entry.color[1], entry.color[2], entry.color[3] } }
	if entry.also then copy.also = { unpack(entry.also) } end
	return copy
end

function HotSlots.SpellsFor(specID)
	local stored = GroupFrames.GetDB().hotSpells
	if stored[specID] then return stored[specID] end
	local defaults = GroupFrames.AuraRegistry.healerHots[specID]
	if not defaults then return nil end
	local list = {}
	for index, entry in ipairs(defaults) do list[index] = CopyEntry(entry) end
	stored[specID] = list
	return list
end

function HotSlots.ResetSpells(specID)
	GroupFrames.GetDB().hotSpells[specID] = nil
	HotSlots.Invalidate()
end

local function SpellSet(entry)
	local set = spellSets[entry]
	if set then return set end
	set = { [entry.id] = true }
	if entry.also then
		for _, spellID in ipairs(entry.also) do set[spellID] = true end
	end
	spellSets[entry] = set
	return set
end

function HotSlots.Invalidate()
	activeEntries, activeSet, activeSignature = nil, nil, nil
	specUnresolved = false
end

local NONE = {}

local function Active()
	if activeSignature then return activeEntries, activeSet, activeSignature end
	local specID = PlayerUtil.GetCurrentSpecID()
	if not specID then
		specUnresolved = true
		return NONE, NONE, ''
	end
	local list = HotSlots.SpellsFor(specID)
	activeEntries, activeSet = {}, {}
	if list then
		for _, entry in ipairs(list) do
			if C_Spell.DoesSpellExist(entry.id) then
				activeEntries[#activeEntries + 1] = entry
				for spellID in pairs(SpellSet(entry)) do activeSet[spellID] = true end
			end
		end
	end
	activeSignature = Engine.SortedKeys(activeSet)
	return activeEntries, activeSet, activeSignature
end

function HotSlots.ExcludedSpells(settings)
	if not settings.hotSlots.enabled then return nil, '' end
	local entries, set, signature = Active()
	if #entries == 0 then return nil, '' end
	return set, signature
end

local StyleSlot

local function SlotInitializer(holder, index)
	return function(button)
		local border = button:CreateTexture(nil, 'BACKGROUND', nil, 0)
		border:SetAllPoints()
		border:SetTexture(WHITE8X8)
		border:SetVertexColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])

		local fill = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
		fill:SetTexture(WHITE8X8)

		local icon = button:CreateTexture(nil, 'ARTWORK')
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

		local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
		cooldown:SetAllPoints()
		cooldown:SetDrawEdge(false)
		cooldown:SetReverse(true)
		cooldown:SetHideCountdownNumbers(true)

		local countHost = CreateFrame('Frame', nil, button)
		countHost:SetAllPoints()
		countHost:SetFrameLevel(cooldown:GetFrameLevel() + 1)
		countHost:EnableMouse(false)
		local count = countHost:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
		count:SetPoint('BOTTOMRIGHT', 1, -1)

		button:SetIcon(icon)
		button:SetDurationCooldown(cooldown)
		button:SetApplicationCount(count, {})
		button:SetMouseClickEnabled(false)
		button:SetMouseMotionEnabled(false)

		holder.parts[index] = { fill = fill, icon = icon, count = count }
		StyleSlot(holder.parts[index], holder.entries[index], holder.size)
	end
end

local function Inset(texture, edge)
	texture:ClearAllPoints()
	texture:SetPoint('TOPLEFT', edge, -edge)
	texture:SetPoint('BOTTOMRIGHT', -edge, edge)
end

function StyleSlot(parts, entry, size)
	local edge = Pixel.PixelSize(1)
	Inset(parts.fill, edge)
	Inset(parts.icon, edge)
	local isIcon = entry.style == 'icon'
	parts.icon:SetAlpha(isIcon and 1 or 0)
	parts.fill:SetShown(not isIcon)
	if not isIcon then
		local color = entry.color
		parts.fill:SetVertexColor(color[1], color[2], color[3], 1)
	end
	Pixel.ApplyFont(parts.count, math.max(8, size - 1), BUI.GetGlobalFont(), 'OUTLINE')
end

local function EnsureHolder(frame)
	local holder = frame._bluHotSlots
	if holder then return holder end
	local container = Engine.NewContainer(frame, false, GroupFrames.Layers.indicators)
	container:SetAllPoints(frame)
	holder = { container = container, frames = {}, parts = {}, entries = {} }
	frame._bluHotSlots = holder
	return holder
end

local function Deactivate(holder)
	holder.active = false
	holder.container:Hide()
	Engine.BindUnit(holder.container, nil)
end

function HotSlots.Apply(frame, settings)
	local holder = frame._bluHotSlots
	if BUI.Tools.ShouldAurasBeSecret() and holder then
		pending[frame] = true
		return
	end
	local config = settings.hotSlots
	local entries = config.enabled and Active() or nil
	local count = entries and #entries or 0
	if count == 0 then
		if holder then Deactivate(holder) end
		return
	end

	holder = EnsureHolder(frame)
	holder.size = config.size
	local container = holder.container
	for index = 1, count do
		local entry, key = entries[index], SLOT_PREFIX .. index
		holder.entries[index] = entry
		local candidates = { includeSpellIDs = SpellSet(entry) }
		if holder.frames[index] then
			container:SetAuraSlotCandidateFilters(key, candidates)
		else
			holder.frames[index] = container:AddAuraSlot(key, FILTER, { candidateFilters = candidates, initializeFrame = SlotInitializer(holder, index) })
		end
		if holder.parts[index] then StyleSlot(holder.parts[index], entry, config.size) end
	end
	for index = count + 1, #holder.frames do container:SetAuraSlotCandidateFilters(SLOT_PREFIX .. index, NO_SPELLS) end

	local size = Pixel.Scale(config.size)
	local step = Pixel.Scale(config.size + config.spacing)
	local direction = GROWTH[config.growth]
	local offsetX, offsetY = Pixel.Scale(config.offsetX), Pixel.Scale(config.offsetY)
	for index = 1, count do
		local slot = holder.frames[index]
		slot:SetSize(size, size)
		slot:ClearAllPoints()
		slot:SetPoint(config.anchor, frame, config.anchor, offsetX + direction[1] * step * (index - 1), offsetY + direction[2] * step * (index - 1))
	end

	holder.active = true
	container:Show()
	Engine.BindUnit(container, frame.unit)
end

function HotSlots.Bind(frame, unit)
	local holder = frame._bluHotSlots
	if holder and holder.active then Engine.BindUnit(holder.container, unit) end
end

function HotSlots.SetVisible(frame, visible)
	local holder = frame._bluHotSlots
	if holder and holder.active then holder.container:SetShown(visible) end
end

local function ApplyPending()
	for frame in pairs(pending) do
		pending[frame] = nil
		HotSlots.Apply(frame, GroupFrames.SettingsForFrame(frame))
	end
end

BUI.Tools.OnAuraQueriesUnblocked(ApplyPending, 'Group frame HoT slots')

BUI.Events:OnTalentBurst('GroupFrames.HotSlots', function()
	local before, unresolved = activeSignature, specUnresolved
	HotSlots.Invalidate()
	if before == nil and not unresolved then return end
	local _, _, after = Active()
	if after ~= before then GroupFrames.RefreshAuras() end
end)
