local _, BUI = ...

local UnitFrames = BUI.UnitFrames
local Scheduler = BUI.Scheduler
local rangeCheck = LibStub('LibRangeCheck-3.0')

local TICK_KEY = 'UnitFrames.RangeFade'
local TICK_SECONDS = 0.25
local CHECK_YARDS = 40
local FRAME_KEYS = { 'target', 'focus', 'boss1', 'boss2', 'boss3', 'boss4', 'boss5' }
local FRAME_TYPES = { 'target', 'focus', 'boss', 'boss', 'boss', 'boss', 'boss' }
local UNIT_TYPES = { 'target', 'focus', 'boss' }

local harm, friend
local checkersStale = true

local function Checkers()
	if not checkersStale then return end
	harm = rangeCheck:GetHarmMaxChecker(CHECK_YARDS, true)
	friend = rangeCheck:GetFriendMaxChecker(CHECK_YARDS, true)
	checkersStale = false
end

local function InRange(unit)
	if UnitIsDeadOrGhost(unit) then return true end
	if UnitCanAttack('player', unit) then return not harm or harm(unit) end
	if UnitIsPlayer(unit) and UnitCanAssist('player', unit) then return not friend or friend(unit) end
	return true
end

local function AnyFadeEnabled()
	for index = 1, #UNIT_TYPES do
		if UnitFrames.GetUnitSettings(UNIT_TYPES[index]).rangeFade then return true end
	end
	return false
end

local function Paint(frame)
	frame:SetAlpha((frame._ufOpacity or 1) * (frame._ufRangeAlpha or 1))
end

function UnitFrames.ApplyFrameOpacity(frame, opacity)
	frame._ufOpacity = opacity
	Paint(frame)
end

local function Tick()
	Checkers()
	local active = false
	for index = 1, #FRAME_KEYS do
		local frame = UnitFrames[FRAME_KEYS[index]]
		if frame and frame:IsShown() then
			local unit = frame.unit
			local settings = UnitFrames.GetUnitSettings(FRAME_TYPES[index])
			if unit and settings.rangeFade then
				active = true
				local factor = InRange(unit) and settings.rangeInsideAlpha or settings.rangeOutsideAlpha
				if frame._ufRangeAlpha ~= factor then
					frame._ufRangeAlpha = factor
					Paint(frame)
				end
			elseif frame._ufRangeAlpha then
				frame._ufRangeAlpha = nil
				Paint(frame)
			end
		end
	end
	if not active then Scheduler.SetUpdateEnabled(TICK_KEY, false) end
end

local function Wake()
	if AnyFadeEnabled() then Scheduler.SetUpdateEnabled(TICK_KEY, true) end
end

function UnitFrames.RefreshRangeFade()
	for index = 1, #FRAME_KEYS do
		local frame = UnitFrames[FRAME_KEYS[index]]
		if frame then
			frame._ufRangeAlpha = nil
			Paint(frame)
		end
	end
	Wake()
end

Scheduler.RegisterUpdate(TICK_KEY, Tick, TICK_SECONDS, false)
rangeCheck.RegisterCallback(UnitFrames, rangeCheck.CHECKERS_CHANGED, function() checkersStale = true end)
BUI.Events:Register('PLAYER_TARGET_CHANGED', 'UF.RangeFade', Wake)
BUI.Events:Register('PLAYER_FOCUS_CHANGED', 'UF.RangeFade', Wake)
BUI.Events:Register('INSTANCE_ENCOUNTER_ENGAGE_UNIT', 'UF.RangeFade', Wake)
BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.RangeFade', Wake)
