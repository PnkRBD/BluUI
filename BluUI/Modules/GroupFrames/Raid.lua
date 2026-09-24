local _, BUI = ...

local oUF = BUI.oUF
local GroupFrames = BUI.GroupFrames

local UIParent         = UIParent
local InCombatLockdown = InCombatLockdown
local GetInstanceInfo  = GetInstanceInfo
local floor, ceil      = math.floor, math.ceil
local Scale            = BUI.Pixel.Scale

local RAID_GROUP_SIZE = 5

local maxAllowedGroups = 8

local function MemberAttrs(raidSettings)
	local gap = Scale(raidSettings.spacing)
	if raidSettings.vertical == false then return "LEFT", gap, 0 end
	if raidSettings.growUp then return "BOTTOM", 0, gap end
	return "TOP", 0, -gap
end

local function GroupCell(raidSettings)
	local memberWidth, memberHeight = Scale(raidSettings.width), Scale(raidSettings.height)
	local gap      = Scale(raidSettings.spacing)
	local groupGap = Scale(raidSettings.groupSpacing)
	if raidSettings.vertical == false then
		return memberWidth * RAID_GROUP_SIZE + gap * (RAID_GROUP_SIZE - 1) + groupGap, memberHeight + groupGap
	end
	return memberWidth + groupGap, memberHeight * RAID_GROUP_SIZE + gap * (RAID_GROUP_SIZE - 1) + groupGap
end

local function PlaceGroup(header, groupIndex, raidSettings)
	local columnCount = math.max(1, raidSettings.groupsPerRow)
	local rowIndex    = floor((groupIndex - 1) / columnCount)
	local columnIndex = (groupIndex - 1) % columnCount
	local cellWidth, cellHeight = GroupCell(raidSettings)
	header:ClearAllPoints()
	local rowDirection = raidSettings.growUp and 1 or -1
	header:SetPoint(raidSettings.point, UIParent, raidSettings.relPoint,
		Scale(raidSettings.x) + columnIndex * cellWidth,
		Scale(raidSettings.y) + rowDirection * rowIndex * cellHeight)
end

local function UsesWideLayout(raidSettings)
	return raidSettings.raidWideSorting
end

local function AllHeaders()
	local collected = {}
	local raid = GroupFrames.headers.raid
	if raid then
		for index = 1, #raid do collected[#collected + 1] = raid[index] end
	end
	local large = GroupFrames.headers.raidLarge
	if large then
		for index = 1, #large do collected[#collected + 1] = large[index] end
	end
	if GroupFrames.headers.raidWide then collected[#collected + 1] = GroupFrames.headers.raidWide end
	if GroupFrames.headers.raidLargeWide then collected[#collected + 1] = GroupFrames.headers.raidLargeWide end
	return collected
end

local function ShownGroupFilter()
	local parts = {}
	for groupIndex = 1, maxAllowedGroups do parts[#parts + 1] = groupIndex end
	return table.concat(parts, ",")
end

function GroupFrames.ApplyRaidRoleFilter()
	if not GroupFrames.headers.raid then return end
	GroupFrames.AfterCombat(function()
		local function ApplyGroupFilter(header, groups)
			header:SetAttribute("roleFilter",      nil)
			header:SetAttribute("strictFiltering", nil)
			header:SetAttribute("groupFilter",     groups)
		end
		for groupIndex, header in ipairs(GroupFrames.headers.raid) do ApplyGroupFilter(header, tostring(groupIndex)) end
		if GroupFrames.headers.raidLarge then
			for groupIndex, header in ipairs(GroupFrames.headers.raidLarge) do ApplyGroupFilter(header, tostring(groupIndex)) end
		end
		local shownGroups = ShownGroupFilter()
		if GroupFrames.headers.raidWide then ApplyGroupFilter(GroupFrames.headers.raidWide, shownGroups) end
		if GroupFrames.headers.raidLargeWide then ApplyGroupFilter(GroupFrames.headers.raidLargeWide, shownGroups) end
		GroupFrames.ApplyRaidVisibility()
	end, "GF.RoleFilter")
end

local function LargeRaidConfig()
	local largeConfig = GroupFrames.GetDB().raid.large
	return largeConfig.enabled and largeConfig or nil
end

local function BankCondition(bank)
	local largeConfig = LargeRaidConfig()
	if bank == "large" then
		if not largeConfig then return nil end
		return ("custom [group:raid,@raid%d,exists] show; hide"):format(largeConfig.threshold)
	end
	if largeConfig then
		return ("custom [@raid%d,exists] hide; [group:raid] show; hide"):format(largeConfig.threshold)
	end
	return "raid"
end

local function GroupVisibility(bank, groupIndex)
	local raidSettings = GroupFrames.GetDB().raid
	if not raidSettings.enabled then return "custom hide" end
	if UsesWideLayout(raidSettings) then return "custom hide" end
	if groupIndex > maxAllowedGroups then return "custom hide" end
	if GroupFrames.IsRaidPreviewShown() then
		return bank == "base" and "custom show" or "custom hide"
	end
	return BankCondition(bank) or "custom hide"
end

local function WideVisibility(bank)
	local raidSettings = GroupFrames.GetDB().raid
	if not raidSettings.enabled or not UsesWideLayout(raidSettings) then return "custom hide" end
	if GroupFrames.IsRaidPreviewShown() then
		return bank == "base" and "custom show" or "custom hide"
	end
	return BankCondition(bank) or "custom hide"
end

function GroupFrames.ApplyRaidVisibility()
	if not GroupFrames.headers.raid then return end
	for groupIndex, header in ipairs(GroupFrames.headers.raid) do
		header:SetVisibility(GroupVisibility("base", groupIndex))
	end
	if GroupFrames.headers.raidLarge then
		for groupIndex, header in ipairs(GroupFrames.headers.raidLarge) do
			header:SetVisibility(GroupVisibility("large", groupIndex))
		end
	end
	if GroupFrames.headers.raidWide then GroupFrames.headers.raidWide:SetVisibility(WideVisibility("base")) end
	if GroupFrames.headers.raidLargeWide then GroupFrames.headers.raidLargeWide:SetVisibility(WideVisibility("large")) end
end

local PRECREATE_STAGGER = 0.05
local precreateTicker

local function PendingPrecreate()
	local pending = {}
	local raidSettings = GroupFrames.GetDB().raid
	if UsesWideLayout(raidSettings) then
		pending[#pending + 1] = { GroupFrames.headers.raidWide, 40 }
		if LargeRaidConfig() then
			pending[#pending + 1] = { GroupFrames.headers.raidLargeWide, 40 }
		end
		return pending
	end
	for groupIndex, header in ipairs(GroupFrames.headers.raid) do
		if GroupVisibility("base", groupIndex) ~= "custom hide" then
			pending[#pending + 1] = { header, RAID_GROUP_SIZE }
		end
	end
	if LargeRaidConfig() and GroupFrames.headers.raidLarge then
		for groupIndex, header in ipairs(GroupFrames.headers.raidLarge) do
			if GroupVisibility("large", groupIndex) ~= "custom hide" then
				pending[#pending + 1] = { header, RAID_GROUP_SIZE }
			end
		end
	end
	return pending
end

local function StopPrecreateStagger()
	if precreateTicker then precreateTicker:Cancel(); precreateTicker = nil end
end

local function PrecreateStep()
	if not GroupFrames.CanBuildChildren() then return end
	local pending = PendingPrecreate()
	for index = 1, #pending do
		local header, wanted = pending[index][1], pending[index][2]
		if header and (header._bluPrebuilt or 0) < wanted then
			GroupFrames.PrecreateHeaderChildren(header, wanted)
			return
		end
	end
	StopPrecreateStagger()
end

function GroupFrames.PrecreateRaid()
	if not GroupFrames.headers.raid or not GroupFrames.CanBuildChildren() then return end
	local raidSettings = GroupFrames.GetDB().raid
	if not raidSettings.enabled then return end
	if IsInRaid() or GroupFrames.IsRaidPreviewShown() then
		StopPrecreateStagger()
		local pending = PendingPrecreate()
		for index = 1, #pending do
			GroupFrames.PrecreateHeaderChildren(pending[index][1], pending[index][2])
		end
		return
	end
	if precreateTicker then return end
	precreateTicker = C_Timer.NewTicker(PRECREATE_STAGGER, PrecreateStep)
end

function GroupFrames.UpdateInstanceClamp()
	local raidSettings = GroupFrames.GetDB().raid
	local maxGroups = 8
	if raidSettings.clampGroups ~= false then
		local _, instanceType, difficultyID = GetInstanceInfo()
		if difficultyID == 16 then
			maxGroups = 4
		elseif instanceType == "raid" then
			maxGroups = 6
		end
	end
	if maxGroups == maxAllowedGroups then return end
	maxAllowedGroups = maxGroups
	if GroupFrames.headers.raid then
		GroupFrames.AfterCombat(function()
			GroupFrames.ApplyRaidVisibility()
			GroupFrames.ApplyRaidRoleFilter()
		end, "GF.RaidVisibility")
	end
end

local function SpawnGroupBank(bank, raidSettings)
	local suffix = bank == "large" and "RaidL" or "Raid"
	local memberPoint, memberX, memberY = MemberAttrs(raidSettings)
	local groups = {}
	for groupIndex = 1, 8 do
		local header = oUF:SpawnHeader(
			GroupFrames.FRAME_PREFIX .. suffix .. groupIndex,
			nil,
			"showRaid",      true,
			"showPlayer",    true,
			"showSolo",      false,
			"groupFilter",   tostring(groupIndex),
			"groupingOrder", "1,2,3,4,5,6,7,8",
			"groupBy",       "GROUP",
			"maxColumns",    1,
			"unitsPerColumn", RAID_GROUP_SIZE,
			"point",         memberPoint,
			"xOffset",       memberX,
			"yOffset",       memberY,
			"oUF-initialConfigFunction", GroupFrames.ConfigSnippet(raidSettings.width, raidSettings.height)
		)
		header:SetVisibility(GroupVisibility(bank, groupIndex))
		PlaceGroup(header, groupIndex, raidSettings)
		groups[groupIndex] = header
	end
	return groups
end

local function WideSortAttrs(raidSettings)
	local mode = raidSettings.wideSortBy
	if mode == "CLASS" then return "CLASS", raidSettings.classOrder, "INDEX" end
	if mode == "NAME"  then return nil, "1,2,3,4,5,6,7,8", "NAME" end
	if mode == "INDEX" then return nil, "1,2,3,4,5,6,7,8", "INDEX" end
	return "ASSIGNEDROLE", raidSettings.roleOrder, "INDEX"
end

local function WideColumnAnchor(raidSettings)
	if raidSettings.vertical == false then return raidSettings.growUp and "BOTTOM" or "TOP" end
	return "LEFT"
end

local function ConfigureWide(header, bank, raidSettings)
	local base = GroupFrames.GetDB().raid
	local memberPoint, memberX, memberY = MemberAttrs(raidSettings)
	local unitsPerColumn = math.max(1, math.min(40, base.wideUnitsPerColumn))
	local groupBy, order, sortMethod = WideSortAttrs(base)
	header:SetAttribute("oUF-initialConfigFunction", GroupFrames.ConfigSnippet(raidSettings.width, raidSettings.height))
	header:SetAttribute("point",             memberPoint)
	header:SetAttribute("xOffset",           memberX)
	header:SetAttribute("yOffset",           memberY)
	header:SetAttribute("unitsPerColumn",    unitsPerColumn)
	header:SetAttribute("maxColumns",        ceil(40 / unitsPerColumn))
	header:SetAttribute("columnSpacing",     Scale(raidSettings.groupSpacing))
	header:SetAttribute("columnAnchorPoint", WideColumnAnchor(raidSettings))
	header:SetAttribute("groupBy",           groupBy)
	header:SetAttribute("groupingOrder",     order)
	header:SetAttribute("sortMethod",        sortMethod)
	header:ClearAllPoints()
	header:SetPoint(raidSettings.point, UIParent, raidSettings.relPoint, Scale(raidSettings.x), Scale(raidSettings.y))
	header:SetVisibility(WideVisibility(bank))
end

local function SpawnWide(bank, raidSettings)
	local name = GroupFrames.FRAME_PREFIX .. (bank == "large" and "RaidLWide" or "RaidWide")
	local header = oUF:SpawnHeader(
		name,
		nil,
		"showRaid",    true,
		"showPlayer",  true,
		"showSolo",    false,
		"groupFilter", "1,2,3,4,5,6,7,8",
		"oUF-initialConfigFunction", GroupFrames.ConfigSnippet(raidSettings.width, raidSettings.height)
	)
	ConfigureWide(header, bank, raidSettings)
	return header
end

local function EnsureLargeBank()
	if GroupFrames.headers.raidLarge then return end
	if not LargeRaidConfig() then return end
	if InCombatLockdown() then return end
	local largeRaidSettings = GroupFrames.LargeRaidSettings()
	GroupFrames.headers.raidLarge     = SpawnGroupBank("large", largeRaidSettings)
	GroupFrames.headers.raidLargeWide = SpawnWide("large", largeRaidSettings)
end

function GroupFrames.SpawnRaid()
	if GroupFrames.headers.raid then return end
	GroupFrames.InvalidateLargeRaidSettings()
	local raidSettings = GroupFrames.GetDB().raid

	GroupFrames.headers.raid     = SpawnGroupBank("base", raidSettings)
	GroupFrames.headers.raidWide = SpawnWide("base", raidSettings)
	EnsureLargeBank()

	GroupFrames.UpdateInstanceClamp()
	GroupFrames.ApplyRaidRoleFilter()
	GroupFrames.PrecreateRaid()
end

function GroupFrames.PreviewRaidHeaders()
	local raidSettings = GroupFrames.GetDB().raid
	if UsesWideLayout(raidSettings) then
		return GroupFrames.headers.raidWide and { GroupFrames.headers.raidWide } or nil
	end
	return GroupFrames.headers.raid
end

function GroupFrames.AllRaidHeaders()
	return AllHeaders()
end

function GroupFrames.SetRaidEnabled(enabled)
	if not GroupFrames.headers.raid then return end
	if enabled then
		GroupFrames.ApplyRaidVisibility()
		return
	end
	for _, header in ipairs(AllHeaders()) do
		header:SetVisibility("custom hide")
	end
end

local function ReflowHeader(header, raidSettings)
	GroupFrames.ForEachHeaderChild(header, function(child) child:ClearAllPoints() end)
	if header:IsVisible() then header:Hide(); header:Show() end
	GroupFrames.ForEachHeaderChild(header, function(child) GroupFrames.ApplyChildAll(child, raidSettings, raidSettings) end)
end

local function RefreshBank(bank, groups, wideHeader, raidSettings)
	local memberPoint, memberX, memberY = MemberAttrs(raidSettings)
	for groupIndex, header in ipairs(groups) do
		header:SetAttribute("oUF-initialConfigFunction", GroupFrames.ConfigSnippet(raidSettings.width, raidSettings.height))
		header:SetAttribute("point",   memberPoint)
		header:SetAttribute("xOffset", memberX)
		header:SetAttribute("yOffset", memberY)
		PlaceGroup(header, groupIndex, raidSettings)
		header:SetVisibility(GroupVisibility(bank, groupIndex))
		ReflowHeader(header, raidSettings)
	end
	if wideHeader then
		ConfigureWide(wideHeader, bank, raidSettings)
		ReflowHeader(wideHeader, raidSettings)
	end
end

function GroupFrames.RefreshRaid()
	if not GroupFrames.headers.raid then return end
	if InCombatLockdown() then GroupFrames.AfterCombat(GroupFrames.RefreshRaid, "GF.RefreshRaid"); return end
	GroupFrames.InvalidateLargeRaidSettings()
	EnsureLargeBank()
	GroupFrames.UpdateInstanceClamp()
	local raidSettings = GroupFrames.GetDB().raid
	RefreshBank("base", GroupFrames.headers.raid, GroupFrames.headers.raidWide, raidSettings)
	if GroupFrames.headers.raidLarge then
		RefreshBank("large", GroupFrames.headers.raidLarge, GroupFrames.headers.raidLargeWide, GroupFrames.LargeRaidSettings())
	end
	GroupFrames.ApplyRaidRoleFilter()
	GroupFrames.PrecreateRaid()
	GroupFrames.SyncPreviewChildren()
end
