local _, BUI = ...

local GroupFrames     = BUI.GroupFrames
local Anchor = GroupFrames.Anchor

local UIParent           = UIParent
local InCombatLockdown   = InCombatLockdown
local Scale              = BUI.Pixel.Scale
local SetHeaderAttribute = GroupFrames.SetHeaderAttribute

local function ResolveAnchorTarget(partySettings)
	if partySettings.anchorFrame == "" then return nil end
	return Anchor.ResolveFrame(partySettings.anchorFrame)
end

local function AnchorWidth(partySettings, target)
	if not partySettings.matchAnchorWidth or not target then return nil end
	local width = target._row1W or target:GetWidth()
	if not width or width <= 0 then return nil end
	return width
end

local LEFT_PIN_VARIANT = { TOP = "TOPLEFT", BOTTOM = "BOTTOMLEFT", INSIDE_TOP = "INSIDE_TOPLEFT", INSIDE_BOTTOM = "INSIDE_BOTTOMLEFT" }

local function PositionHeader(header, partySettings)
	local target = ResolveAnchorTarget(partySettings)
	if not target then
		header:ClearAllPoints()
		header:SetPoint(partySettings.point, UIParent, partySettings.relPoint, Scale(partySettings.x), Scale(partySettings.y))
		return nil
	end
	return Anchor.ApplyPosition(header, {
		anchorFrame   = partySettings.anchorFrame,
		anchorPoint   = LEFT_PIN_VARIANT[partySettings.anchorPoint] or partySettings.anchorPoint,
		anchorOffsetX = partySettings.anchorOffsetX,
		anchorOffsetY = partySettings.anchorOffsetY,
		posX          = partySettings.x,
		posY          = partySettings.y,
	})
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
		target:HookScript("OnSizeChanged", BUI.Profiler.Wrap("GroupFrames.Party anchor resize", function(self)
			if watchedTarget == self then SyncAnchorWidth() end
		end))
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
	local hidesBlizzard = (partySettings.enabled and GroupFrames.GetDB().hideBlizzardFrames ~= false) == true

	local gap = Scale(partySettings.spacing)
	local header = GroupFrames.SpawnHeader(
		GroupFrames.FRAME_PREFIX .. "Party",
		"showParty",   hidesBlizzard,
		"showPlayer",  partySettings.showPlayer == true,
		"showSolo",    (partySettings.showSolo and partySettings.showPlayer) == true,
		"yOffset",     partySettings.vertical and -gap or 0,
		"xOffset",     partySettings.vertical and 0 or gap,
		"point",       partySettings.vertical and "TOP" or "LEFT",
		"groupBy",     partySettings.sortBy,
		"groupingOrder", SortOrderFor(partySettings),
		"sortMethod",  "INDEX",
		"maxColumns",  1,
		"unitsPerColumn", 5,
		"oUF-initialConfigFunction", GroupFrames.ConfigSnippet(partySettings.width, partySettings.height)
	)
	if not hidesBlizzard then header:SetAttribute("showParty", true) end
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

	local gap = Scale(partySettings.spacing)
	SetHeaderAttribute(header, "oUF-initialConfigFunction", GroupFrames.ConfigSnippet(effectiveWidth, partySettings.height))
	SetHeaderAttribute(header, "point",      partySettings.vertical and "TOP" or "LEFT")
	SetHeaderAttribute(header, "xOffset",    partySettings.vertical and 0 or gap)
	SetHeaderAttribute(header, "yOffset",    partySettings.vertical and -gap or 0)
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
