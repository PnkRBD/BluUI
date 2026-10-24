local _, BUI = ...

local GroupFrames     = BUI.GroupFrames
local Anchor = GroupFrames.Anchor

local UIParent           = UIParent
local InCombatLockdown   = InCombatLockdown
local Scale              = BUI.Pixel.Scale
local SetHeaderAttribute = GroupFrames.SetHeaderAttribute

local function ResolveAnchorTarget(partySettings)
	return BUI.ResolveAnchorFrame(partySettings.anchorFrame, partySettings.anchorPoint)
end

local function AnchorWidth(partySettings, target)
	if not partySettings.matchAnchorWidth or not target then return nil end
	local width = target._row1W or target:GetWidth()
	if width <= 0 then return nil end
	return width
end

local LEFT_PIN_VARIANT = { TOP = "TOPLEFT", BOTTOM = "BOTTOMLEFT", INSIDE_TOP = "INSIDE_TOPLEFT", INSIDE_BOTTOM = "INSIDE_BOTTOMLEFT" }
local RIGHT_PIN_VARIANT = { TOP = "TOPRIGHT", BOTTOM = "BOTTOMRIGHT", INSIDE_TOP = "INSIDE_TOPRIGHT", INSIDE_BOTTOM = "INSIDE_BOTTOMRIGHT" }

local GROWTH = {
	DOWN  = { point = "TOP",    x = 0,  y = -1 },
	UP    = { point = "BOTTOM", x = 0,  y = 1 },
	RIGHT = { point = "LEFT",   x = 1,  y = 0 },
	LEFT  = { point = "RIGHT",  x = -1, y = 0 },
}

function GroupFrames.PartyGrowth(partySettings)
	if GROWTH[partySettings.growDirection] then return partySettings.growDirection end
	return partySettings.vertical == false and "RIGHT" or "DOWN"
end

local function Growth(partySettings)
	return GROWTH[GroupFrames.PartyGrowth(partySettings)]
end

local function LayoutAttributes(partySettings)
	local growth, gap = Growth(partySettings), Scale(partySettings.spacing)
	return growth.point, growth.x * gap, growth.y * gap
end

local function PlaceFree(header, partySettings, growth)
	local point, x, y = partySettings.point, Scale(partySettings.x), Scale(partySettings.y)
	if growth.y > 0 then
		point = point:gsub("TOP", "BOTTOM")
		y = y - Scale(partySettings.height)
	elseif growth.x < 0 then
		point = point:gsub("LEFT", "RIGHT")
		x = x + Scale(partySettings.width)
	end
	header:ClearAllPoints()
	header:SetPoint(point, UIParent, partySettings.relPoint, x, y)
end

local function PositionHeader(header, partySettings)
	local growth = Growth(partySettings)
	local target = ResolveAnchorTarget(partySettings)
	if not target then
		PlaceFree(header, partySettings, growth)
		return nil
	end
	local pins = growth.x < 0 and RIGHT_PIN_VARIANT or LEFT_PIN_VARIANT
	Anchor.ApplyPosition(header, target, partySettings.anchorFrame,
		pins[partySettings.anchorPoint] or partySettings.anchorPoint,
		partySettings.anchorOffsetX, partySettings.anchorOffsetY)
	return target
end

local lastSyncedWidth
local function SyncAnchorWidth()
	if InCombatLockdown() then return end
	local header = GroupFrames.headers.party
	if not header then return end
	local partySettings = GroupFrames.GetDB().party
	if not partySettings.matchAnchorWidth then return end
	local target = ResolveAnchorTarget(partySettings)
	local width = AnchorWidth(partySettings, target)
	if not width or width == lastSyncedWidth then return end
	lastSyncedWidth = width

	header:SetAttribute("oUF-initialConfigFunction", GroupFrames.ConfigSnippet(width, partySettings.height))
	GroupFrames.EachPartyChild(function(child) child:SetSize(Scale(width), Scale(partySettings.height)) end)
end

local watchedTarget
local function WatchAnchorTarget(target)
	if target == watchedTarget then return end
	watchedTarget = target
	if target and not target._bluFramesPartyHook then
		target._bluFramesPartyHook = true
		target:HookScript("OnSizeChanged", function(self)
			if watchedTarget == self then SyncAnchorWidth() end
		end)
	end
end

local function SortOrderFor(partySettings)
	if partySettings.sortBy == "ASSIGNEDROLE" then return partySettings.roleOrder end
	if partySettings.sortBy == "CLASS"        then return partySettings.classOrder end
	return "1,2,3,4,5,6,7,8"
end

local function ShowInRaid(partySettings) return partySettings.raidGroup ~= "off" end

local function VisibilityFor(partySettings)
	if not partySettings.enabled then return "hide" end
	if GroupFrames.IsPartyPreviewShown() then return "show" end
	local condition = "[group:party,nogroup:raid] show;"
	if ShowInRaid(partySettings) then condition = condition .. "[group:raid] show;" end
	if partySettings.showSolo and partySettings.showPlayer then condition = "[@player,exists,nogroup:party] show;" .. condition end
	return condition .. "hide"
end

function GroupFrames.ApplyPartyVisibility()
	local header = GroupFrames.headers.party
	if not header then return end
	GroupFrames.SetHeaderVisibility(header, VisibilityFor(GroupFrames.GetDB().party))
end

function GroupFrames.PrecreateParty()
	local header = GroupFrames.headers.party
	if not header or not GroupFrames.CanBuildChildren() then return end
	if not GroupFrames.GetDB().party.enabled then return end
	GroupFrames.PrecreateHeaderChildren(header, 5)
end

function GroupFrames.ApplyPartyRaidMode()
	local header = GroupFrames.headers.party
	if not header then return end
	local partySettings = GroupFrames.GetDB().party
	local showRaid = IsInRaid() and ShowInRaid(partySettings)
	local groupFilter = showRaid and partySettings.raidGroup or nil
	if header:GetAttribute("showRaid") == showRaid and header:GetAttribute("groupFilter") == groupFilter then return end
	if InCombatLockdown() then GroupFrames.AfterCombat(GroupFrames.ApplyPartyRaidMode, "GF.PartyRaidMode"); return end
	SetHeaderAttribute(header, "showRaid",    showRaid)
	SetHeaderAttribute(header, "groupFilter", groupFilter)
end

function GroupFrames.SpawnParty()
	if GroupFrames.headers.party then return end
	local partySettings = GroupFrames.GetDB().party

	local point, xOffset, yOffset = LayoutAttributes(partySettings)
	local header = GroupFrames.SpawnHeader(
		GroupFrames.FRAME_PREFIX .. "Party",
		"showParty",   true,
		"showPlayer",  partySettings.showPlayer == true,
		"showSolo",    (partySettings.showSolo and partySettings.showPlayer) == true,
		"yOffset",     yOffset,
		"xOffset",     xOffset,
		"point",       point,
		"groupBy",     partySettings.sortBy,
		"groupingOrder", SortOrderFor(partySettings),
		"sortMethod",  "INDEX",
		"maxColumns",  1,
		"unitsPerColumn", 5,
		"oUF-initialConfigFunction", GroupFrames.ConfigSnippet(partySettings.width, partySettings.height)
	)
	GroupFrames.SetHeaderVisibility(header, VisibilityFor(partySettings))
	GroupFrames.headers.party = header
	GroupFrames.RefreshPartyAnchor()
	GroupFrames.ApplyPartyRaidMode()
	GroupFrames.PrecreateParty()
end

function GroupFrames.RefreshPartyAnchor()
	local header = GroupFrames.headers.party
	if not header or InCombatLockdown() then return end
	WatchAnchorTarget(PositionHeader(header, GroupFrames.GetDB().party))
	SyncAnchorWidth()
end

function GroupFrames.SetPartyEnabled(enabled)
	local header = GroupFrames.headers.party
	if not header then return end
	GroupFrames.SetHeaderVisibility(header, enabled and VisibilityFor(GroupFrames.GetDB().party) or "hide")
end

function GroupFrames.RefreshParty()
	local header = GroupFrames.headers.party
	if not header then return end
	if InCombatLockdown() then GroupFrames.AfterCombat(GroupFrames.RefreshParty, "GF.RefreshParty"); return end
	local partySettings = GroupFrames.GetDB().party

	local target = PositionHeader(header, partySettings)
	WatchAnchorTarget(target)
	local effectiveWidth = AnchorWidth(partySettings, target) or partySettings.width

	local point, xOffset, yOffset = LayoutAttributes(partySettings)
	SetHeaderAttribute(header, "oUF-initialConfigFunction", GroupFrames.ConfigSnippet(effectiveWidth, partySettings.height))
	SetHeaderAttribute(header, "point",      point)
	SetHeaderAttribute(header, "xOffset",    xOffset)
	SetHeaderAttribute(header, "yOffset",    yOffset)
	SetHeaderAttribute(header, "showPlayer", partySettings.showPlayer == true)
	SetHeaderAttribute(header, "showSolo",   (partySettings.showSolo and partySettings.showPlayer) == true)
	GroupFrames.ApplyPartyRaidMode()
	SetHeaderAttribute(header, "groupBy",    partySettings.sortBy)
	SetHeaderAttribute(header, "groupingOrder", SortOrderFor(partySettings))
	GroupFrames.SetHeaderVisibility(header, VisibilityFor(partySettings))

	GroupFrames.EachPartyChild(function(child) child:ClearAllPoints() end)
	if header:IsVisible() then header:Hide(); header:Show() end

	local geometry = {
		width           = effectiveWidth,
		height          = partySettings.height,
		powerHeight     = partySettings.powerHeight,
		showPower       = partySettings.showPower,
		showPwrText     = partySettings.showPwrText,
		showName        = partySettings.showName,
		showHpText      = partySettings.showHpText,
		healerOnlyPower = partySettings.healerOnlyPower,
	}
	GroupFrames.PrecreateParty()
	GroupFrames.EachPartyChild(function(child) GroupFrames.ApplyChildAll(child, partySettings, geometry) end)
	GroupFrames.SyncPreviewChildren()
	GroupFrames.Keystone.Sync()
end
