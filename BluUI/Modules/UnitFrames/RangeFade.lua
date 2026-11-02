local _, BUI = ...

local UnitFrames = BUI.UnitFrames
local Scheduler = BUI.Scheduler
local rangeCheck = LibStub('LibRangeCheck-3.0')

local TICK_KEY = 'UnitFrames.RangeFade'
local TICK_SECONDS = 0.25
local CHECK_YARDS = 40
local FRAME_KEYS = { 'target', 'focus', 'boss1', 'boss2', 'boss3', 'boss4', 'boss5' }
local FRAME_TYPES = { 'target', 'focus', 'boss', 'boss', 'boss', 'boss', 'boss' }
local UNIT_TYPES = { target = true, focus = true, boss = true }

local typeByUnit = {}
for index = 1, #FRAME_KEYS do typeByUnit[FRAME_KEYS[index]] = FRAME_TYPES[index] end

local checker
local checkerStale = true

local function Checker()
	if checkerStale then
		checker = rangeCheck:GetSmartMaxChecker(CHECK_YARDS, true)
		checkerStale = false
	end
	return checker
end

local function AnyFadeEnabled()
	for unitType in pairs(UNIT_TYPES) do
		if UnitFrames.GetUnitSettings(unitType).rangeFade then return true end
	end
	return false
end

local function ApplyRange(frame, settings, check)
	local opacity = frame._ufOpacity or 1
	local inside = settings.rangeInsideAlpha * opacity
	local inRange = check and check(frame.unit)
	if inRange == nil then
		frame:SetAlpha(inside)
	else
		frame:SetAlphaFromBoolean(inRange, inside, settings.rangeOutsideAlpha * opacity)
	end
end

function UnitFrames.ApplyFrameOpacity(frame, opacity)
	frame._ufOpacity = opacity
	local unitType = not frame._isPreview and typeByUnit[frame.unit]
	local settings = unitType and UnitFrames.GetUnitSettings(unitType)
	if settings and settings.rangeFade then
		ApplyRange(frame, settings, Checker())
	else
		frame:SetAlpha(opacity)
	end
end

local function Tick()
	local check = Checker()
	local shown = false
	for index = 1, #FRAME_KEYS do
		local frame = UnitFrames[FRAME_KEYS[index]]
		if frame and frame:IsShown() then
			local settings = UnitFrames.GetUnitSettings(FRAME_TYPES[index])
			if settings.rangeFade then
				shown = true
				ApplyRange(frame, settings, check)
			end
		end
	end
	if not shown then Scheduler.SetUpdateEnabled(TICK_KEY, false) end
end

local function Wake()
	if AnyFadeEnabled() then Scheduler.SetUpdateEnabled(TICK_KEY, true) end
end

function UnitFrames.RefreshRangeFade()
	for index = 1, #FRAME_KEYS do
		local frame = UnitFrames[FRAME_KEYS[index]]
		if frame then UnitFrames.ApplyFrameOpacity(frame, frame._ufOpacity or 1) end
	end
	Wake()
end

Scheduler.RegisterUpdate(TICK_KEY, Tick, TICK_SECONDS, false)
rangeCheck.RegisterCallback(UnitFrames, rangeCheck.CHECKERS_CHANGED, function() checkerStale = true end)
BUI.Events:Register('PLAYER_TARGET_CHANGED', 'UF.RangeFade', Wake)
BUI.Events:Register('PLAYER_FOCUS_CHANGED', 'UF.RangeFade', Wake)
BUI.Events:Register('INSTANCE_ENCOUNTER_ENGAGE_UNIT', 'UF.RangeFade', Wake)
BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.RangeFade', Wake)
