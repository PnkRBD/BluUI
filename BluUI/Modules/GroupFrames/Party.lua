local _, BUI = ...

local oUF    = BUI.oUF
local GroupFrames     = BUI.GroupFrames
local Anchor = GroupFrames.Anchor

local UIParent         = UIParent
local InCombatLockdown = InCombatLockdown
local Scale            = BUI.Pixel.Scale

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
	if not partySettings.enabled then return "custom hide" end
	if GroupFrames.IsPartyPreviewShown() then return "custom show" end
	local list = "party"
	if ShowInRaid(partySettings) then list = list .. ",raid" end
	if partySettings.showSolo and partySettings.showPlayer then list = "solo," .. list end
	return list
end

function GroupFrames.ApplyPartyVisibility()
	local header = GroupFrames.headers.party
	if not header then return end
	header:SetVisibility(VisibilityFor(GroupFrames.GetDB().party))
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
	if InCombatLockdown() then GroupFrames.AfterCombat(GroupFrames.ApplyPartyRaidMode, "GF.PartyRaidMode"); return end
	local partySettings = GroupFrames.GetDB().party
	if IsInRaid() and ShowInRaid(partySettings) then
		header:SetAttribute("showRaid",    true)
		header:SetAttribute("groupFilter", partySettings.raidGroup)
	else
		header:SetAttribute("showRaid",    false)
		header:SetAttribute("groupFilter", nil)
	end
end

function GroupFrames.SpawnParty()
	if GroupFrames.headers.party then return end
	local partySettings = GroupFrames.GetDB().party

	local gap = Scale(partySettings.spacing)
	local header = oUF:SpawnHeader(
		GroupFrames.FRAME_PREFIX .. "Party",
		nil,
		"showParty",   true,
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
	header:SetVisibility(VisibilityFor(partySettings))
	PositionHeader(header, partySettings)
	GroupFrames.headers.party = header
	GroupFrames.ApplyPartyRaidMode()
	GroupFrames.PrecreateParty()
end

function GroupFrames.SetPartyEnabled(enabled)
	local header = GroupFrames.headers.party
	if not header then return end
	header:SetVisibility(enabled and VisibilityFor(GroupFrames.GetDB().party) or "custom hide")
end

function GroupFrames.RefreshParty()
	local header = GroupFrames.headers.party
	if not header then return end
	local partySettings = GroupFrames.GetDB().party

	local target = PositionHeader(header, partySettings)
	WatchAnchorTarget(target)
	local effectiveWidth = AnchorWidth(partySettings, target) or partySettings.width

	local gap = Scale(partySettings.spacing)
	header:SetAttribute("oUF-initialConfigFunction", GroupFrames.ConfigSnippet(effectiveWidth, partySettings.height))
	header:SetAttribute("point",      partySettings.vertical and "TOP" or "LEFT")
	header:SetAttribute("xOffset",    partySettings.vertical and 0 or gap)
	header:SetAttribute("yOffset",    partySettings.vertical and -gap or 0)
	header:SetAttribute("showPlayer", partySettings.showPlayer == true)
	header:SetAttribute("showSolo",   (partySettings.showSolo and partySettings.showPlayer) == true)
	GroupFrames.ApplyPartyRaidMode()
	header:SetAttribute("groupBy",    partySettings.sortBy)
	header:SetAttribute("groupingOrder", SortOrderFor(partySettings))
	header:SetVisibility(VisibilityFor(partySettings))

	if not InCombatLockdown() then
		GroupFrames.EachPartyChild(function(child) child:ClearAllPoints() end)
		if header:IsVisible() then header:Hide(); header:Show() end
	end

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
end
