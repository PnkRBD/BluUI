local _, BUI = ...

local GroupFrames = BUI.GroupFrames

local CreateFrame     = CreateFrame
local UnitExists      = UnitExists
local UnitIsConnected = UnitIsConnected
local ResolveGrowth   = GroupFrames.Util.ResolveGrowth
local Scale         = BUI.Pixel.Scale

local AddAnchor    = C_UnitAuras.AddPrivateAuraAnchor
local RemoveAnchor = C_UnitAuras.RemovePrivateAuraAnchor

local function Config(frame)
	return GroupFrames.SettingsForFrame(frame).privateAuras
end

local function Wanted(frame, settings)
	local unit = frame.unit
	return settings.enabled ~= false and unit and UnitExists(unit) and UnitIsConnected(unit)
end

local function ResolveLayer(frame)
	return frame:GetFrameStrata(), frame:GetFrameLevel() + GroupFrames.Layers.privateAura
end

local function PokeSlotLevel(slot, container)
	local level = container:GetFrameLevel()
	slot:SetFrameLevel(level)
	slot:SetFrameLevel(level + 1)
end

local function ClearAnchors(container)
	for handleIndex = #container.handles, 1, -1 do
		RemoveAnchor(container.handles[handleIndex])
		container.handles[handleIndex] = nil
	end
end

local function RegisterAnchors(frame, container, settings)
	local size      = Scale(settings.size)
	local showTimer = settings.showTimer ~= false

	for slotIndex = 1, settings.num do
		local slot = container.slots[slotIndex]
		if not slot then break end
		container.handles[#container.handles + 1] = AddAnchor({
			unitToken            = frame.unit,
			auraIndex            = slotIndex,
			parent               = slot,
			isContainer          = false,
			showCountdownFrame   = showTimer,
			showCountdownNumbers = showTimer,
			iconInfo = {
				iconWidth   = size,
				iconHeight  = size,
				borderScale = -10000,
				iconAnchor = {
					point         = "CENTER",
					relativeTo    = slot,
					relativePoint = "CENTER",
					offsetX       = 0,
					offsetY       = 0,
				},
			},
		})
		PokeSlotLevel(slot, container)
	end
end

local function ReleaseAnchors(container)
	ClearAnchors(container)
	container._regUnit = nil
end

local function SyncAnchors(frame, container, settings)
	local size      = Scale(settings.size)
	local count     = settings.num
	local showTimer = settings.showTimer ~= false

	if container._regUnit == frame.unit and container._regSize == size
		and container._regCount == count and container._regTimer == showTimer then
		return
	end

	ClearAnchors(container)
	RegisterAnchors(frame, container, settings)
	container._regUnit, container._regSize = frame.unit, size
	container._regCount, container._regTimer = count, showTimer
end

local function RefreshAnchors(frame)
	local container = frame.BluPrivateAuras
	if not container then return end

	local settings = Config(frame)
	if not Wanted(frame, settings) then
		ReleaseAnchors(container)
		container:Hide()
		return
	end

	SyncAnchors(frame, container, settings)
	container:Show()
end

local function EnsureContainer(frame)
	local container = frame.BluPrivateAuras
	if container then return container end
	local host = frame.Health or frame
	container = CreateFrame("Frame", nil, host)
	local strata, level = ResolveLayer(frame)
	container:SetFrameStrata(strata)
	container:SetFrameLevel(level)
	container.slots = {}
	container.handles = {}
	frame.BluPrivateAuras = container

	if not frame._bluPaUnitHook then
		frame._bluPaUnitHook = true
		frame:HookScript("OnAttributeChanged", function(self, name)
			if name == "unit" then RefreshAnchors(self) end
		end)
	end
	return container
end

function GroupFrames.ApplyPrivateAuras(frame)
	local settings = Config(frame)
	local container = frame.BluPrivateAuras

	if not Wanted(frame, settings) then
		if container then
			ReleaseAnchors(container)
			container:Hide()
		end
		return
	end

	container = EnsureContainer(frame)

	local size          = Scale(settings.size)
	local auraCount     = settings.num
	local gap           = Scale(settings.spacing)
	local point         = settings.anchorPoint
	local relativePoint = settings.relativePoint
	local growDirection = settings.growDirection
	local host          = frame.Health or frame
	local growthX, growthY = ResolveGrowth(point, growDirection)
	local directionX    = (growthX == "LEFT") and -1 or 1
	local directionY    = (growthY == "DOWN") and -1 or 1
	local vertical      = (growDirection == "UP" or growDirection == "DOWN")
	local span          = auraCount * size + (auraCount - 1) * gap

	local strata, level = ResolveLayer(frame)
	container:ClearAllPoints()
	container:SetPoint(point, host, relativePoint, Scale(settings.offsetX), Scale(settings.offsetY))
	container:SetSize(vertical and size or span, vertical and span or size)
	container:SetFrameStrata(strata)
	container:SetFrameLevel(level)
	container:Show()

	local leading = vertical and (directionY == -1 and "TOP" or "BOTTOM") or (directionX == -1 and "RIGHT" or "LEFT")

	for slotIndex = 1, auraCount do
		local slot = container.slots[slotIndex]
		if not slot then
			slot = CreateFrame("Frame", nil, container)
			container.slots[slotIndex] = slot
		end
		slot:SetSize(size, size)
		slot:SetFrameStrata(container:GetFrameStrata())
		slot:SetFrameLevel(container:GetFrameLevel() + 1)
		slot:ClearAllPoints()
		local step = (slotIndex - 1) * (size + gap)
		slot:SetPoint(leading, container, leading, vertical and 0 or step * directionX, vertical and step * directionY or 0)
		slot:Show()
	end
	for slotIndex = auraCount + 1, #container.slots do container.slots[slotIndex]:Hide() end

	SyncAnchors(frame, container, settings)
end

function GroupFrames.NudgePrivateAuras(frame)
	local container = frame.BluPrivateAuras
	if not container then return end
	ReleaseAnchors(container)
	GroupFrames.ApplyPrivateAuras(frame)
end
