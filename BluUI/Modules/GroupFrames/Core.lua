local _, BUI = ...

local GroupFrames = {}
BUI.GroupFrames = GroupFrames

GroupFrames.STYLE_NAME   = "BluUI-Group"
GroupFrames.FRAME_PREFIX = "BUI_Group"

GroupFrames.headers = {}

GroupFrames.Layers = {
	auras       = 10,
	selection   = 20,
	indicators  = 25,
	privateAura = 30,
}

function GroupFrames.Print(message)
	print(BUI.C.CHAT_PREFIX .. message)
end

function GroupFrames.GetDB()
	local profile = BUI.GetDB()
	return profile and profile.groupFrames or BUI.Defaults.profile.groupFrames
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

function Util.FrameRole(frame)
	if not frame then return nil end
	if frame._previewRole then return frame._previewRole end
	local unit = frame.unit
	if not unit then return nil end
	local role = UnitGroupRolesAssigned(unit)
	if IsSecret(role) then return nil end
	if role and role ~= "NONE" then return role end
	if UnitIsUnit(unit, "player") and GetSpecialization and GetSpecializationRole then
		local spec = GetSpecialization()
		if spec then return GetSpecializationRole(spec) end
	end
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

local Anchor = {}
GroupFrames.Anchor = Anchor

local CDM_FRAMES = {
	BUI_EssentialCooldownViewer = true,
	BUI_UtilityCooldownViewer   = true,
	BUI_BuffCooldownViewer      = true,
}

local OPPOSITES = {
	TOP = "BOTTOM", BOTTOM = "TOP",
	LEFT = "RIGHT", RIGHT = "LEFT",
	TOPLEFT = "BOTTOMLEFT", TOPRIGHT = "BOTTOMRIGHT",
	BOTTOMLEFT = "TOPLEFT", BOTTOMRIGHT = "TOPRIGHT",
	CENTER = "CENTER",
}

function Anchor.ResolveFrame(name)
	if not name or name == "" then return nil end
	return _G[name]
end

local function CDMOffset(frameName, point)
	if not CDM_FRAMES[frameName] then return 0 end
	local anchorFrame = _G[frameName]
	if not anchorFrame then return 0 end
	if point == "TOP" or point == "TOPLEFT" or point == "TOPRIGHT" then
		return -(anchorFrame._topEdgeOffset or 0)
	end
	if point == "BOTTOM" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT" then
		return anchorFrame._bottomEdgeOffset or 0
	end
	return 0
end

local function CDMPointInUIParent(frame, point)
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not left or not right or not top or not bottom then return nil, nil end
	local centerX, centerY = (left + right) / 2, (top + bottom) / 2
	if point == "TOPLEFT"     then return left,    top     end
	if point == "TOP"         then return centerX, top     end
	if point == "TOPRIGHT"    then return right,   top     end
	if point == "LEFT"        then return left,    centerY end
	if point == "RIGHT"       then return right,   centerY end
	if point == "BOTTOMLEFT"  then return left,    bottom  end
	if point == "BOTTOM"      then return centerX, bottom  end
	if point == "BOTTOMRIGHT" then return right,   bottom  end
	return centerX, centerY
end

local function GapOffsets(point, offsetX, offsetY)
	if point:find("BOTTOM") then return offsetX, offsetY - 1 end
	if point:find("TOP")    then return offsetX, offsetY + 1 end
	if point == "LEFT"      then return offsetX - 1, offsetY end
	if point == "RIGHT"     then return offsetX + 1, offsetY end
	return offsetX, offsetY
end

function Anchor.ApplyPosition(frame, settings)
	if not frame then return end
	local Scale = BUI.Pixel.Scale

	frame:ClearAllPoints()
	local target = Anchor.ResolveFrame(settings.anchorFrame)
	if target == frame then target = nil end

	if not target then
		frame:SetPoint("CENTER", UIParent, "CENTER", Scale(settings.posX or 0), Scale(settings.posY or 0))
		return
	end

	local point, framePoint, isInside = BUI.Anchor.ResolveAnchorPoint(settings.anchorPoint)
	local offsetX, offsetY = settings.anchorOffsetX or 0, settings.anchorOffsetY or 0
	local direction = isInside and -1 or 1

	offsetY = offsetY + CDMOffset(settings.anchorFrame, point) * direction

	if framePoint == "TOP" or framePoint == "TOPLEFT" or framePoint == "TOPRIGHT" then
		offsetY = offsetY + (frame._topEdgeOffset or 0) * direction
	elseif framePoint == "BOTTOM" or framePoint == "BOTTOMLEFT" or framePoint == "BOTTOMRIGHT" then
		offsetY = offsetY - (frame._bottomEdgeOffset or 0) * direction
	end

	offsetX, offsetY = GapOffsets(isInside and (OPPOSITES[point] or point) or point, offsetX, offsetY)

	if CDM_FRAMES[settings.anchorFrame] then
		local anchorX, anchorY = CDMPointInUIParent(target, point)
		if anchorX and anchorY then
			if target._row1CenterOffsetX
				and (point == "TOP" or point == "BOTTOM" or point == "CENTER") then
				anchorX = anchorX + target._row1CenterOffsetX
			end
			frame:SetPoint(framePoint, UIParent, "BOTTOMLEFT", Scale(anchorX + offsetX), Scale(anchorY + offsetY))
			return target
		end
	end

	frame:SetPoint(framePoint, target, point, Scale(offsetX), Scale(offsetY))
	return target
end

function GroupFrames.AfterCombat(callback, key)
	BUI.Events:AfterCombat(callback, key)
end

do
	local queued = false
	local queuedSection

	function GroupFrames.Refresh(section)
		if queued then
			if queuedSection ~= section then queuedSection = nil end
			return
		end
		queued = true
		queuedSection = section
		C_Timer.After(0, function()
			local pendingSection = queuedSection
			queued, queuedSection = false, nil
			GroupFrames.InvalidateLargeRaidSettings()
			GroupFrames.AfterCombat(function() GroupFrames.RefreshAll(pendingSection) end, "GF.RefreshAll:" .. (pendingSection or "all"))
		end)
	end
end

function GroupFrames.SetEnabled(enabled)
	GroupFrames.AfterCombat(function() GroupFrames.SetFramesEnabled(enabled) end, "GF.SetEnabled")
end
