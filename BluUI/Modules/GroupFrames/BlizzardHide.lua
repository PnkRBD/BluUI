local _, BUI = ...

local GroupFrames = BUI.GroupFrames

local InCombatLockdown = InCombatLockdown

local BLOCKED_ROLESET = "alwaysBlocked"
local BAR_KEYS = { "healthBar", "healthbar", "HealthBar", "manabar", "ManaBar", "powerBar", "powerBarAlt", "spellbar", "castBar" }

local blocked = setmetatable({}, { __mode = "k" })

local function Block(frame)
	if not frame or blocked[frame] then return end
	blocked[frame] = true
	frame:UnregisterAllEvents()
	if frame.SetRolesets then frame:SetRolesets(BLOCKED_ROLESET) end
	for barIndex = 1, #BAR_KEYS do
		local bar = frame[BAR_KEYS[barIndex]]
		if bar and bar.UnregisterAllEvents then bar:UnregisterAllEvents() end
	end
end

local MAX_PARTY = MAX_PARTY_MEMBERS
local MAX_RAID  = MAX_RAID_MEMBERS
local COMPACT_PARTY_MEMBERS = MEMBERS_PER_RAID_GROUP

local PARTY_UNITS = {}
for memberIndex = 1, MAX_PARTY do
	PARTY_UNITS["party"    .. memberIndex] = true
	PARTY_UNITS["partypet" .. memberIndex] = true
end

local RAID_UNITS = {}
for raidIndex = 1, MAX_RAID do
	RAID_UNITS["raid"    .. raidIndex] = true
	RAID_UNITS["raidpet" .. raidIndex] = true
end

local partyActive = false
local raidActive  = false

local function stripCompactUnitEvents(frame)
	local unit = frame and frame.unit
	if not unit or frame:IsForbidden() then return end
	if (partyActive and PARTY_UNITS[unit])
		or (raidActive and RAID_UNITS[unit])
		or (partyActive and raidActive and (unit == "player" or unit == "pet")) then
		frame:UnregisterAllEvents()
	end
end

local setupFrames = setmetatable({}, { __mode = "k" })

local function markCompactSetup(frame, setup)
	if setup ~= DefaultCompactUnitFrameSetup or not frame or frame:IsForbidden() then return end
	local name = frame:GetDebugName()
	if not name or issecretvalue(name) then return end
	if (partyActive and name:find("^CompactPartyFrameMember%d+$"))
		or (raidActive and name:find("^CompactRaidGroup%d+Member%d+$")) then
		setupFrames[frame] = true
	end
end

local function silenceCompactUnit(frame, unit)
	if unit == nil or not setupFrames[frame] then return end
	frame:SetScript("OnEvent", nil)
	frame:SetScript("OnUpdate", nil)
end

local compactHookInstalled = false
local function installCompactHook()
	if compactHookInstalled or not _G.CompactUnitFrame_UpdateUnitEvents then return end
	compactHookInstalled = true
	hooksecurefunc("CompactUnitFrame_UpdateUnitEvents", stripCompactUnitEvents)
	hooksecurefunc("CompactUnitFrame_SetUpFrame", markCompactSetup)
	hooksecurefunc("CompactUnitFrame_SetUnit", silenceCompactUnit)
end

local partyHidden = false
function GroupFrames.HideBlizzardParty()
	if partyHidden or not PartyFrame or InCombatLockdown() then return end
	partyHidden = true
	partyActive = true
	installCompactHook()

	Block(PartyFrame)
	if PartyFrame.PartyMemberFramePool then
		for member in PartyFrame.PartyMemberFramePool:EnumerateActive() do Block(member) end
	end
	for memberIndex = 1, COMPACT_PARTY_MEMBERS do
		Block(_G["CompactPartyFrameMember" .. memberIndex])
	end
	Block(CompactPartyFrame)
end

local raidHidden = false
function GroupFrames.HideBlizzardRaid()
	if raidHidden or not CompactRaidFrameContainer or InCombatLockdown() then return end
	raidHidden = true
	raidActive = true
	installCompactHook()
	Block(CompactRaidFrameContainer)
end

local raidManagerHidden = false
function GroupFrames.HideBlizzardRaidManager()
	if raidManagerHidden or not CompactRaidFrameManager then return end
	if InCombatLockdown() then GroupFrames.AfterCombat(GroupFrames.HideBlizzardRaidManager, "GF.HideRaidManager"); return end
	raidManagerHidden = true
	Block(CompactRaidFrameManager)
end
