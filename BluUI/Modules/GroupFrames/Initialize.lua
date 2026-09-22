local _, BUI = ...

local GroupFrames = BUI.GroupFrames

function GroupFrames.MigrateBlacklists()
	local db = GroupFrames.GetDB()
	local auraBlacklist = BUI.AuraBlacklist
	local overrides = db.blacklistOverrides

	local legacyList = db.userDebuffBlacklist
	if legacyList then
		local curated = auraBlacklist.Curated('HARMFUL')
		for spellID, isBlacklisted in pairs(legacyList) do
			if isBlacklisted == true and not curated[spellID] then overrides.debuff[spellID] = 'hide'
			elseif isBlacklisted == false and curated[spellID] then overrides.debuff[spellID] = 'show' end
		end
		db.userDebuffBlacklist = nil
	end

	legacyList = db.userBuffBlacklist
	if legacyList then
		for spellID, isBlacklisted in pairs(legacyList) do
			if isBlacklisted == true then overrides.buff[spellID] = 'hide' end
		end
		db.userBuffBlacklist = nil
	end

	db._blacklistSeedVersion = nil
	auraBlacklist.Invalidate()
end

function GroupFrames.NarrowPlayerBuffRules()
	local db = GroupFrames.GetDB()
	if db.playerBuffRulesNarrowed then return end
	db.playerBuffRulesNarrowed = true
	for _, section in ipairs({ db.party, db.raid }) do
		local rules = section and section.buffs and section.buffs.rules
		if type(rules) == "table" then
			local seen = {}
			for ruleIndex = #rules, 1, -1 do
				local ruleID = rules[ruleIndex] == "mineHelpful" and "mineRaidCombat" or rules[ruleIndex]
				if seen[ruleID] then
					table.remove(rules, ruleIndex)
				else
					seen[ruleID] = true
					rules[ruleIndex] = ruleID
				end
			end
		end
	end
end

local function CopyInto(destination, source)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(destination[key]) ~= "table" then destination[key] = {} end
			CopyInto(destination[key], value)
		elseif type(value) ~= "function" then
			destination[key] = value
		end
	end
end

local IMPORT_KEYS = {
	"enabled", "clickMode",
	"userDebuffBlacklist", "userBuffBlacklist",
	"range", "party", "raid",
}

function GroupFrames.ImportStandaloneProfile()
	local profile = BUI.GetDB()
	if not profile or not profile.general then return end
	if profile.general._groupFramesImported_v1 then return end

	local standaloneDB = _G.BluFramesDB
	if not standaloneDB or not standaloneDB.profiles then return end
	profile.general._groupFramesImported_v1 = true

	local characterKey = UnitName("player") .. " - " .. GetRealmName()
	local profileName = standaloneDB.profileKeys and standaloneDB.profileKeys[characterKey]
	local sourceProfile = profileName and standaloneDB.profiles[profileName] or standaloneDB.profiles["Default"]
	if not sourceProfile then
		for _, candidateProfile in pairs(standaloneDB.profiles) do sourceProfile = candidateProfile; break end
	end
	if not sourceProfile then return end

	local groupFramesSettings = profile.groupFrames
	for _, key in ipairs(IMPORT_KEYS) do
		local value = sourceProfile[key]
		if type(value) == "table" then
			if type(groupFramesSettings[key]) ~= "table" then groupFramesSettings[key] = {} end
			CopyInto(groupFramesSettings[key], value)
		elseif value ~= nil then
			groupFramesSettings[key] = value
		end
	end
	if standaloneDB.global and standaloneDB.global.hideBlizzardFrames ~= nil then
		groupFramesSettings.hideBlizzardFrames = standaloneDB.global.hideBlizzardFrames
	end
	GroupFrames.Print("Imported your standalone Blu Frames settings into Group Frames.")
end

local initialized = false

function GroupFrames.IsActive() return initialized end

function GroupFrames.Initialize()
	GroupFrames.ImportStandaloneProfile()
	GroupFrames.MigrateBlacklists()
	GroupFrames.NarrowPlayerBuffRules()

	if C_AddOns.IsAddOnLoaded("BluFrames") then
		GroupFrames.Print("BluFrames detected, Group Frames stays idle. Disable BluFrames and /reload.")
		return
	end

	if not GroupFrames.GetDB().enabled then return end
	GroupFrames.Activate()
end

function GroupFrames.Activate()
	if initialized then return end
	initialized = true
	GroupFrames.Setup()
	BUI.Pixel.OnScaleChange("GroupFrames", function() GroupFrames.Refresh() end)
end

function GroupFrames.SetEnabledLive(enabled)
	if enabled and not initialized then
		GroupFrames.AfterCombat(GroupFrames.Activate, "GF.Activate")
		return
	end
	GroupFrames.SetEnabled(enabled)
end

function GroupFrames.OnProfileChanged()
	GroupFrames.ImportStandaloneProfile()
	GroupFrames.MigrateBlacklists()
	GroupFrames.NarrowPlayerBuffRules()
	if initialized then GroupFrames.Refresh() end
end
