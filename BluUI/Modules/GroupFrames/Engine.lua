local _, BUI = ...
local SetScript = BUI.Prof.Scripts('GroupFrames.Engine')

local GroupFrames = BUI.GroupFrames

function GroupFrames.ConfigSnippet(width, height)
	return ([[
		self:SetWidth(%s)
		self:SetHeight(%s)
	]]):format(BUI.Pixel.Scale(width), BUI.Pixel.Scale(height))
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
	local childIndex = 1
	while true do
		local child = header:GetAttribute("child" .. childIndex)
		if not child then return end
		callback(child)
		childIndex = childIndex + 1
	end
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
	local wasShown = header:IsShown()
	header:SetAttribute("startingIndex", 1 - wantedCount)
	header:Show()
	header:SetAttribute("startingIndex", 1)
	if not wasShown then header:Hide() end
	if header:GetAttribute("child" .. wantedCount) then
		header._bluPrebuilt = wantedCount
	end
end

function GroupFrames.ApplyChildAll(child, settings, geometry)
	GroupFrames.ApplyGeometry(child, geometry)
	GroupFrames.ApplyFrameColors(child, settings, child.unit)
	GroupFrames.ApplyBarTextures(child, settings)
	GroupFrames.ApplyAbsorbToChild(child, settings)
	GroupFrames.ApplyTextToChild(child, settings)
	GroupFrames.ApplyIndicatorsToChild(child, settings)
	GroupFrames.ApplyMissingRaidBuffToChild(child, settings)
	GroupFrames.ApplyKeystoneToChild(child, settings)
	GroupFrames.ApplyPrivateAuras(child)
	GroupFrames.ApplySelectionToChild(child, settings)
	if child.unit then
		if child.Health and child:IsElementEnabled("Health") then child.Health:ForceUpdate() end
		if child.Power and child:IsElementEnabled("Power") then child.Power:ForceUpdate() end
	end
	GroupFrames.RepaintPreviewChild(child)
end

function GroupFrames.RecolorChild(child, settings)
	GroupFrames.ApplyFrameColors(child, settings, child.unit)
	GroupFrames.ApplyAbsorbToChild(child, settings)
	if child.unit and child.Health and child.Health.PostUpdateColor then
		child.Health.PostUpdateColor(child.Health, child.unit)
	end
	GroupFrames.ApplyTextColors(child, settings)
	if child.HpText then GroupFrames.ReTagHp(child, settings) end
	if child.unit then child:UpdateTags() end
	GroupFrames.RefreshDispelBorder(child, settings)
	GroupFrames.RepaintPreviewChild(child)
end

function GroupFrames.RefreshAll(section)
	if section ~= "raid"  then GroupFrames.RefreshParty() end
	if section ~= "party" then GroupFrames.RefreshRaid()  end
	GroupFrames.RefreshAuras(section)
end

local rosterForce = false

local function RosterSweep()
	local force = rosterForce
	rosterForce = false
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
		local unit = child.unit
		local guid = unit and UnitGUID(unit) or false
		if guid and IsSecret(guid) then guid = nil end
		local role = unit and UnitGroupRolesAssigned(unit) or ""
		if IsSecret(role) then role = "" end
		local changed = force or guid == nil
			or child._bluRosterGUID ~= guid or child._bluRosterRole ~= role
		child._bluRosterGUID, child._bluRosterRole = guid, role

		GroupFrames.FinishChildAuraSetup(child)
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
			GroupFrames.ApplyPrivateAuras(child)
		elseif not child._bluRosterGeom and not inCombat then
			GroupFrames.ApplyGeometry(child, settings)
			child._bluRosterGeom = true
		end
		GroupFrames.ReflowAuraVisibility(child)
		GroupFrames.MarkAurasDirty(child)
		GroupFrames.RepaintPreviewChild(child)
	end)
end

local DispatchRosterSweep = BUI.Dispatcher.New(RosterSweep, 'GroupFrames.RosterSweep')

local function QueueRosterSweep(force)
	if force then rosterForce = true end
	DispatchRosterSweep()
end

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

local function CountHeaderEvent(_, event)
	if BUI.Prof.active then BUI.Prof.Count("gfheader#" .. tostring(event)) end
end

local function CountHeaderAttribute(_, name)
	if BUI.Prof.active then BUI.Prof.Count("gfheaderattr#" .. tostring(name)) end
end

function GroupFrames.WatchHeader(header)
	if not header or header._buiWatched then return header end
	header._buiWatched = true
	header:HookScript("OnEvent", CountHeaderEvent)
	header:HookScript("OnAttributeChanged", CountHeaderAttribute)
	return header
end

function GroupFrames.Setup()
	local oUF = BUI.oUF
	if not oUF._buiHeaderWatch then
		oUF._buiHeaderWatch = true
		local spawnHeader = oUF.SpawnHeader
		oUF.SpawnHeader = function(self, ...)
			return GroupFrames.WatchHeader(spawnHeader(self, ...))
		end
	end
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
		SetScript(rosterWatcher, "OnEvent", BUI.Prof.Wrap("groupframes#Roster", function(_, event)
			if event == "PLAYER_REGEN_ENABLED" then
				BUI.Events:AfterCombatSettled(function() QueueRosterSweep(false) end, "GF.RosterSweep")
				return
			end
			QueueRosterSweep(event == "PLAYER_ENTERING_WORLD")
		end))
		BUI.Tools.OnAuraQueriesUnblocked(function()
			GroupFrames.PrecreateParty()
			GroupFrames.PrecreateRaid()
			GroupFrames.SyncPreviewChildren()
		end)
	end
end

function GroupFrames.SetFramesEnabled(enabled)
	if enabled and not GroupFrames.headers.party and not GroupFrames.headers.raid then
		GroupFrames.Setup()
		return
	end
	GroupFrames.SetPartyEnabled(enabled)
	GroupFrames.SetRaidEnabled(enabled)
end
