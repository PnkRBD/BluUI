local _, BUI = ...

local GroupFrames = {}
BUI.GroupFrames = GroupFrames

GroupFrames.STYLE_NAME   = "BluUI-Group"
GroupFrames.FRAME_PREFIX = "BUI_Group"

GroupFrames.headers = {}

GroupFrames.Layers = {
	auras       = 10,
	aggro       = 18,
	selection   = 20,
	indicators  = 25,
}

function GroupFrames.GetDB()
	return BUI.GetDB().groupFrames
end

local Util = {}
GroupFrames.Util = Util

local IsSecret  = issecretvalue
local CanAccess = canaccessvalue
Util.IsSecret   = IsSecret
Util.CanAccess  = CanAccess

function Util.FrameClass(frame, unit)
	local previewClass = frame and frame._previewClass
	if previewClass then return previewClass end
	if not unit then return nil end
	local _, class = UnitClass(unit)
	return class
end

function Util.ClassColor(unit, frame)
	local class = Util.FrameClass(frame, unit)
	local classColor = class and RAID_CLASS_COLORS[class]
	if classColor then return classColor.r, classColor.g, classColor.b end
end

function Util.PlayerSpecRole()
	local spec = C_SpecializationInfo.GetSpecialization()
	if not spec then return nil end
	local _, _, _, _, role = C_SpecializationInfo.GetSpecializationInfo(spec)
	return role
end

function Util.FrameRole(frame)
	if not frame then return nil end
	if frame._previewRole then return frame._previewRole end
	local unit = frame.unit
	if not unit then return nil end
	local role = UnitGroupRolesAssigned(unit)
	if IsSecret(role) then return nil end
	if role ~= "NONE" then return role end
	if UnitIsUnit(unit, "player") then return Util.PlayerSpecRole() end
end

function Util.ResolveGrowth(anchorPoint, growDirection)
	local horizontal = anchorPoint:find("RIGHT")  and "LEFT" or "RIGHT"
	local vertical   = anchorPoint:find("BOTTOM") and "UP"   or "DOWN"
	if growDirection == "LEFT"  or growDirection == "RIGHT" then horizontal = growDirection
	elseif growDirection == "UP" or growDirection == "DOWN" then vertical = growDirection
	end
	return horizontal, vertical
end

function Util.JustifyFor(anchor)
	if anchor:find("RIGHT") then return "RIGHT" end
	if anchor:find("LEFT")  then return "LEFT"  end
	return "CENTER"
end

function GroupFrames.AfterCombat(callback, key)
	BUI.Events:AfterCombat(callback, key)
end

do
	local queued = false
	local queuedSection, queuedAurasOnly

	function GroupFrames.Refresh(section, aurasOnly)
		if queued then
			if queuedSection ~= section then queuedSection = nil end
			if not aurasOnly then queuedAurasOnly = false end
			return
		end
		queued = true
		queuedSection, queuedAurasOnly = section, aurasOnly == true
		C_Timer.After(0, function()
			local pendingSection, pendingAurasOnly = queuedSection, queuedAurasOnly
			queued, queuedSection, queuedAurasOnly = false, nil, nil
			GroupFrames.InvalidateLargeRaidSettings()
			local work = pendingAurasOnly and GroupFrames.RefreshAuras or GroupFrames.RefreshAll
			local key = (pendingAurasOnly and "GF.RefreshAuras:" or "GF.RefreshAll:") .. (pendingSection or "all")
			GroupFrames.AfterCombat(function() work(pendingSection) end, key)
		end)
	end
end

function GroupFrames.SetEnabled(enabled)
	GroupFrames.AfterCombat(function() GroupFrames.SetFramesEnabled(enabled) end, "GF.SetEnabled")
end
