local _, BUI = ...

local GroupFrames = BUI.GroupFrames

local CreateFrame         = CreateFrame
local UIParent            = UIParent
local RegisterStateDriver = RegisterStateDriver

function GroupFrames.ConfigSnippet(width, height)
	return ([[
		self:SetWidth(%s)
		self:SetHeight(%s)
		UnregisterUnitWatch(self)
		self:SetAttribute("statehidden", nil)
	]]):format(BUI.Pixel.Scale(width), BUI.Pixel.Scale(height))
end

function GroupFrames.SpawnHeader(name, ...)
	local holder = CreateFrame("Frame", name .. "Holder", UIParent, "SecureFrameTemplate")
	holder:SetAllPoints()
	holder:Hide()
	local header = BUI.oUF:SpawnHeader(name, nil, ...)
	local level = header:GetFrameLevel()
	header:SetParent(holder)
	header:SetFrameLevel(level)
	header:Show()
	header._bluHolder = holder
	return header
end

function GroupFrames.SetHeaderVisibility(header, condition)
	local holder = header._bluHolder
	if holder._bluVisibility == condition then return end
	holder._bluVisibility = condition
	RegisterStateDriver(holder, "visibility", condition)
end

function GroupFrames.SetHeaderAttribute(header, name, value)
	if header:GetAttribute(name) == value then return end
	header:SetAttribute(name, value)
end

function GroupFrames.SettingsForUnit(unit)
	local db = GroupFrames.GetDB()
	if unit and unit:sub(1, 4) == "raid" then return db.raid end
	return db.party
end

local largeMerged

function GroupFrames.InvalidateLargeRaidSettings()
	largeMerged = nil
end

function GroupFrames.LargeRaidSettings()
	if not largeMerged then
		local raidSettings = GroupFrames.GetDB().raid
		local largeSettings = raidSettings.large
		largeMerged = setmetatable({
			width        = largeSettings.width,
			height       = largeSettings.height,
			powerHeight  = largeSettings.powerHeight,
			spacing      = largeSettings.spacing,
			groupSpacing = largeSettings.groupSpacing,
			groupsPerRow = largeSettings.groupsPerRow,
		}, { __index = raidSettings })
	end
	return largeMerged
end

local function SectionForFrame(frame)
	local section = frame._bluSection
	if not section then
		local parentName = frame:GetParent():GetName() or ""
		if parentName == GroupFrames.FRAME_PREFIX .. "Party" then
			section = "party"
		elseif parentName:find(GroupFrames.FRAME_PREFIX .. "RaidL", 1, true) == 1 then
			section = "raidLarge"
		else
			section = "raid"
		end
		frame._bluSection = section
	end
	return section
end

function GroupFrames.SettingsForFrame(frame)
	local section = SectionForFrame(frame)
	if section == "raidLarge" then return GroupFrames.LargeRaidSettings() end
	return GroupFrames.GetDB()[section]
end

function GroupFrames.ForEachHeaderChild(header, callback)
	if not header then return end
	local children = header._bluChildren
	if not children then
		children = {}
		header._bluChildren = children
	end
	local newChild = header:GetAttribute("child" .. (#children + 1))
	while newChild do
		children[#children + 1] = newChild
		newChild = header:GetAttribute("child" .. (#children + 1))
	end
	for childIndex = 1, #children do callback(children[childIndex]) end
end

function GroupFrames.EachPartyChild(callback) GroupFrames.ForEachHeaderChild(GroupFrames.headers.party, callback) end

function GroupFrames.EachRaidChild(callback)
	local raid = GroupFrames.headers.raid
	if raid then
		for headerIndex = 1, #raid do GroupFrames.ForEachHeaderChild(raid[headerIndex], callback) end
	end
	if GroupFrames.headers.raidWide then GroupFrames.ForEachHeaderChild(GroupFrames.headers.raidWide, callback) end
	local large = GroupFrames.headers.raidLarge
	if large then
		for headerIndex = 1, #large do GroupFrames.ForEachHeaderChild(large[headerIndex], callback) end
	end
	if GroupFrames.headers.raidLargeWide then GroupFrames.ForEachHeaderChild(GroupFrames.headers.raidLargeWide, callback) end
end

function GroupFrames.EachChild(callback)
	GroupFrames.EachPartyChild(callback)
	GroupFrames.EachRaidChild(callback)
end

function GroupFrames.CanBuildChildren()
	return not InCombatLockdown()
end

function GroupFrames.PrecreateHeaderChildren(header, wantedCount)
	if not header or (header._bluPrebuilt or 0) >= wantedCount then return end
	local holder = header._bluHolder
	local wasShown = holder:IsShown()
	header:SetAttribute("startingIndex", 1 - wantedCount)
	holder:Show()
	header:SetAttribute("startingIndex", 1)
	if not wasShown then holder:Hide() end
	if header:GetAttribute("child" .. wantedCount) then
		header._bluPrebuilt = wantedCount
	end
end

function GroupFrames.ApplyChildAll(child, settings, geometry)
	GroupFrames.ApplyGeometry(child, geometry)
	GroupFrames.ApplyFrameColors(child, settings, child.unit)
	GroupFrames.ApplyBarTextures(child, settings)
	GroupFrames.ApplyAbsorbToChild(child, settings)
	GroupFrames.RestyleDispelHighlight(child)
	GroupFrames.ApplyTextToChild(child, settings)
	GroupFrames.ApplyIndicatorsToChild(child, settings)
	GroupFrames.ApplyKeystoneToChild(child, settings)
	GroupFrames.RefreshSelection(child)
	if child.unit then
		if child.Health and child:IsElementEnabled("Health") then child.Health:ForceUpdate() end
		if child.Power and child:IsElementEnabled("Power") then child.Power:ForceUpdate() end
	end
	GroupFrames.RepaintPreviewChild(child)
end

function GroupFrames.RecolorChild(child, settings)
	GroupFrames.ApplyFrameColors(child, settings, child.unit)
	GroupFrames.ApplyAbsorbToChild(child, settings)
	GroupFrames.RestyleDispelHighlight(child)
	if child.unit and child.Health and child.Health.PostUpdateColor then
		child.Health.PostUpdateColor(child.Health, child.unit)
	end
	GroupFrames.ApplyTextColors(child, settings)
	if child.HpText then GroupFrames.ReTagHp(child, settings) end
	if child.unit then child:UpdateTags() end
	GroupFrames.RefreshDispelBorder(child, settings)
	GroupFrames.RefreshSelection(child)
	GroupFrames.RepaintPreviewChild(child)
end

function GroupFrames.RefreshAll(section)
	if section ~= "raid"  then GroupFrames.RefreshParty() end
	if section ~= "party" then GroupFrames.RefreshRaid()  end
	GroupFrames.RefreshAuras(section)
end

local function RosterSweep()
	if GroupFrames.GetDB().hideBlizzardFrames ~= false then
		GroupFrames.HideBlizzardParty()
		GroupFrames.HideBlizzardRaid()
		GroupFrames.HideBlizzardRaidManager()
	end
	GroupFrames.ApplyPartyRaidMode()
	GroupFrames.UpdateInstanceClamp()
	GroupFrames.PrecreateParty()
	GroupFrames.PrecreateRaid()
	if not InCombatLockdown() then GroupFrames.SyncPreviewChildren() end
	local inCombat = InCombatLockdown()
	local IsSecret = GroupFrames.Util.IsSecret
	GroupFrames.EachChild(function(child)
		if not child._preview and not child:GetAttribute("unit") then
			child._bluRosterUnit, child._bluRosterGUID = nil, nil
			return
		end
		local unit = child.unit
		local guid = unit and UnitGUID(unit) or false
		if guid and IsSecret(guid) then guid = child._bluRosterGUID end
		local role = unit and UnitGroupRolesAssigned(unit) or ""
		if IsSecret(role) then role = "" end
		local changed = child._bluRosterUnit ~= unit or child._bluRosterGUID ~= guid or child._bluRosterRole ~= role
		child._bluRosterUnit, child._bluRosterGUID, child._bluRosterRole = unit, guid, role

		GroupFrames.QueueChildAuraSetup(child)
		local settings = GroupFrames.SettingsForFrame(child)
		if changed then
			if inCombat then
				child._bluRosterGeom = false
			else
				GroupFrames.ApplyGeometry(child, settings)
				child._bluRosterGeom = true
			end
			if unit and child.Power and child.Power.ForceUpdate
				and child:IsElementEnabled("Power") then
				child.Power:ForceUpdate()
			end
			GroupFrames.ApplyTextColors(child, settings)
			GroupFrames.MarkAurasDirty(child)
		elseif not child._bluRosterGeom and not inCombat then
			GroupFrames.ApplyGeometry(child, settings)
			child._bluRosterGeom = true
		end
		GroupFrames.ReflowAuraVisibility(child)
		GroupFrames.RepaintPreviewChild(child)
	end)
end

local DispatchRosterSweep = BUI.Dispatcher.New(RosterSweep, 'GroupFrames.RosterSweep')

function GroupFrames.RefreshColors()
	local db = GroupFrames.GetDB()
	GroupFrames.EachPartyChild(function(child) GroupFrames.RecolorChild(child, db.party) end)
	GroupFrames.EachRaidChild(function(child) GroupFrames.RecolorChild(child, db.raid) end)
end

function GroupFrames.CloseAllPreviews()
	GroupFrames.StopDispelPreview()
	GroupFrames.ClearIndicatorPreviews()
	GroupFrames.ClearAuraPreviews()
	GroupFrames.SetPartyPreview(false)
	GroupFrames.SetRaidPreview(false)
end

local rosterWatcher

function GroupFrames.Setup()
	local oUF = BUI.oUF
	oUF:RegisterStyle(GroupFrames.STYLE_NAME, GroupFrames.Style)
	oUF:Factory(function()
		oUF:SetActiveStyle(GroupFrames.STYLE_NAME)
		GroupFrames.SpawnParty()
		GroupFrames.SpawnRaid()
	end)
	GroupFrames.HookSelection()

	if not rosterWatcher then
		rosterWatcher = CreateFrame("Frame")
		rosterWatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
		rosterWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
		rosterWatcher:RegisterEvent("PLAYER_ROLES_ASSIGNED")
		rosterWatcher:RegisterEvent("PARTY_MEMBER_ENABLE")
		rosterWatcher:RegisterEvent("PARTY_MEMBER_DISABLE")
		rosterWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		rosterWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		rosterWatcher:SetScript("OnEvent", BUI.Profiler.Wrap("GroupFrames.Engine roster event", function(_, event)
			if event == "PLAYER_REGEN_ENABLED" then
				BUI.Events:AfterCombatSettled(DispatchRosterSweep, "GF.RosterSweep")
				return
			end
			DispatchRosterSweep()
		end))
		BUI.Tools.OnAuraQueriesUnblocked(function()
			GroupFrames.PrecreateParty()
			GroupFrames.PrecreateRaid()
			GroupFrames.SyncPreviewChildren()
		end, 'Group frame precreate')
	end
	GroupFrames.SyncReachabilitySweep()
end

function GroupFrames.SetFramesEnabled(enabled)
	if enabled and not GroupFrames.headers.party and not GroupFrames.headers.raid then
		GroupFrames.Setup()
		return
	end
	GroupFrames.SetPartyEnabled(enabled)
	GroupFrames.SetRaidEnabled(enabled)
	GroupFrames.SyncReachabilitySweep()
end
