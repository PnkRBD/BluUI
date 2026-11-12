local _, BUI = ...

local GroupFrames = BUI.GroupFrames
local Dragging    = BUI.Dragging
local Snap        = BUI.Pixel.Snap

local UIParent         = UIParent
local InCombatLockdown = InCombatLockdown
local huge             = math.huge

local movers     = {}
local unlocked   = { party = false, raid = false }
local ownPreview = { party = false, raid = false }

local boundLeft, boundBottom, boundRight, boundTop, boundRatio

local function GrowBounds(child)
	if not child:IsVisible() then return end
	local left, bottom, width, height = child:GetRect()
	if not left then return end
	local ratio = child:GetEffectiveScale() / boundRatio
	left, bottom = left * ratio, bottom * ratio
	local right, top = left + width * ratio, bottom + height * ratio
	if left < boundLeft then boundLeft = left end
	if bottom < boundBottom then boundBottom = bottom end
	if right > boundRight then boundRight = right end
	if top > boundTop then boundTop = top end
end

local function MeasureHeaders(key)
	boundLeft, boundBottom, boundRight, boundTop = huge, huge, -huge, -huge
	boundRatio = UIParent:GetEffectiveScale()
	if key == "party" then
		GroupFrames.ForEachHeaderChild(GroupFrames.headers.party, GrowBounds)
	else
		local headers = GroupFrames.PreviewRaidHeaders()
		for index = 1, #headers do GroupFrames.ForEachHeaderChild(headers[index], GrowBounds) end
	end
	return boundLeft < huge
end

local function Section(key)
	return GroupFrames.GetDB()[key]
end

local function OffsetKeys(key)
	if key == "party" and BUI.ResolveAnchorFrame(Section(key).anchorFrame, Section(key).anchorPoint) then
		return "anchorOffsetX", "anchorOffsetY"
	end
	return "x", "y"
end

local function PlaceHeaders(key)
	if key == "party" then GroupFrames.RefreshPartyAnchor() else GroupFrames.PlaceRaidHeaders() end
end

local function Refit(key)
	local mover = movers[key]
	if not mover then return end
	if not unlocked[key] or mover.dragActive or not MeasureHeaders(key) then
		if not mover.dragActive then mover:Hide() end
		return
	end
	mover:ClearAllPoints()
	mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", boundLeft, boundBottom)
	mover:SetSize(boundRight - boundLeft, boundTop - boundBottom)
	mover:Show()
	local settings = Section(key)
	local keyX, keyY = OffsetKeys(key)
	mover.keyX, mover.keyY = keyX, keyY
	mover.originX, mover.originY = settings[keyX], settings[keyY]
	mover.baseX, mover.baseY = Dragging.GetCenterOffset(mover)
end

local function Follow(mover, x, y)
	local settings = Section(mover.key)
	settings[mover.keyX] = Snap(mover.originX + x - mover.baseX)
	settings[mover.keyY] = Snap(mover.originY + y - mover.baseY)
	if InCombatLockdown() then
		GroupFrames.Refresh(mover.key)
		return
	end
	PlaceHeaders(mover.key)
end

local function CreateMover(key)
	local mover = CreateFrame("Frame", nil, UIParent)
	mover.key = key
	mover._buiPerfName = "BUI_GroupMover " .. key
	mover:SetFrameStrata("MEDIUM")
	mover:SetFrameLevel(200)
	mover:Hide()
	Dragging.MakeDraggable(mover, {
		clamp = true,
		showHint = true,
		showUnlockedBg = true,
		isLocked = InCombatLockdown,
		onDragging = function(x, y) Follow(mover, x, y) end,
		onPositionChanged = function(x, y)
			Follow(mover, x, y)
			Refit(key)
		end,
		onRightClick = function() GroupFrames.SetMoverUnlocked(key, false) end,
	})
	movers[key] = mover
	return mover
end

local function IsPreviewShown(key)
	if key == "party" then return GroupFrames.IsPartyPreviewShown() end
	return GroupFrames.IsRaidPreviewShown()
end

local function SetPreview(key, shown)
	if key == "party" then GroupFrames.SetPartyPreview(shown) else GroupFrames.SetRaidPreview(shown) end
end

function GroupFrames.IsMoverUnlocked(key)
	return unlocked[key]
end

function GroupFrames.SetMoverUnlocked(key, value)
	value = value == true
	if value == unlocked[key] then return end
	if value and (InCombatLockdown() or not GroupFrames.headers[key]) then return end
	unlocked[key] = value
	if value then
		if not movers[key] then CreateMover(key) end
		ownPreview[key] = not IsPreviewShown(key)
		if ownPreview[key] then SetPreview(key, true) end
		Refit(key)
		C_Timer.After(0, function() Refit(key) end)
	else
		Refit(key)
		if ownPreview[key] then SetPreview(key, false) end
		ownPreview[key] = false
	end
	BUI.NotifyModuleChange("unitFramePreview")
end

function GroupFrames.RefitMover(key)
	Refit(key)
end

function GroupFrames.LockMovers()
	GroupFrames.SetMoverUnlocked("party", false)
	GroupFrames.SetMoverUnlocked("raid", false)
end
