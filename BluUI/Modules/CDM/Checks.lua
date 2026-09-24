local _, BUI = ...
local CDM    = BUI.CDM
local Modals = BUI.BUILibClient.Modals

local SafeNum = BUI.Tools.SafeNum
local COOLDOWN_VIEWER_CVAR = 'cooldownViewerEnabled'
local LAYOUT_SETTLE_SECONDS = 5

local function CollectSpellIDs(viewer)
	local spellIDSet = {}
	for frame in viewer.itemFramePool:EnumerateActive() do
		local cooldownInfo = frame.cooldownInfo
		if cooldownInfo then
			local spellID = SafeNum(cooldownInfo.spellID)
			local overrideID = SafeNum(cooldownInfo.overrideSpellID)
			if spellID    then spellIDSet[spellID]    = true end
			if overrideID then spellIDSet[overrideID] = true end
			local linked = cooldownInfo.linkedSpellIDs
			if linked and not issecretvalue(linked) then
				for _, linkedID in ipairs(linked) do
					local id = SafeNum(linkedID)
					if id then spellIDSet[id] = true end
				end
			end
		end
	end
	return spellIDSet
end

local function IsSpellCoveredBySet(cooldownInfo, spellIDSet)
	local spellID = SafeNum(cooldownInfo.spellID)
	local overrideID = SafeNum(cooldownInfo.overrideSpellID)
	if spellID and spellIDSet[spellID] then return true end
	if overrideID and spellIDSet[overrideID] then return true end
	local linked = cooldownInfo.linkedSpellIDs
	if linked and not issecretvalue(linked) then
		for _, linkedID in ipairs(linked) do
			local id = SafeNum(linkedID)
			if id and spellIDSet[id] then return true end
		end
	end
	return false
end

function CDM.CheckDisabled(done)
	local db = BUI.GetDB()

	local anyCDMViewerEnabled = false
	for _, key in ipairs(CDM.VIEWER_KEYS) do
		local viewerSettings = db.cdm[key]
		if viewerSettings and viewerSettings.enabled then anyCDMViewerEnabled = true; break end
	end
	if not anyCDMViewerEnabled or C_CVar.GetCVarBool(COOLDOWN_VIEWER_CVAR) then done() return end

	C_Timer.After(LAYOUT_SETTLE_SECONDS, function()
		if C_CVar.GetCVarBool(COOLDOWN_VIEWER_CVAR) then done() return end
		Modals.Confirm({
			title       = 'Cooldown Manager Disabled',
			message     = "Blizzard's Cooldown Manager is turned off.\nBluUI's CDM requires it. Enable and reload?",
			confirmText = 'Enable & Reload',
			cancelText  = 'Close',
			onConfirm   = function()
				SetCVar(COOLDOWN_VIEWER_CVAR, '1')
				BUI.Reload()
			end,
			onCancel = done,
		})
	end)
end

function CDM.CheckUtilityPrompt(done)
	local db = BUI.GetDB()

	local anyCDMEnabled = false
	for _, key in ipairs(CDM.VIEWER_KEYS) do
		local viewerSettings = db.cdm[key]
		if viewerSettings and viewerSettings.enabled then anyCDMEnabled = true; break end
	end
	if not anyCDMEnabled then done() return end

	local utilitySettings = db.cdm.utility
	if utilitySettings.enabled then done() return end

	local finished = false
	local function Finish()
		if finished then return end
		finished = true
		BUI.Events:Unregister('COOLDOWN_VIEWER_DATA_LOADED', 'CDM.UtilityCheck')
		done()
	end

	local function Evaluate()
		if finished then return end
		local utilityViewer   = UtilityCooldownViewer
		local essentialViewer = EssentialCooldownViewer
		if not utilityViewer or not utilityViewer.itemFramePool
		or not essentialViewer or not essentialViewer.itemFramePool then return end
		finished = true
		BUI.Events:Unregister('COOLDOWN_VIEWER_DATA_LOADED', 'CDM.UtilityCheck')

		local essentialSpellIDs = CollectSpellIDs(essentialViewer)

		local hasUniqueUtilitySpell = false
		for frame in utilityViewer.itemFramePool:EnumerateActive() do
			local cooldownInfo = frame.cooldownInfo
			if cooldownInfo and cooldownInfo.spellID and not IsSpellCoveredBySet(cooldownInfo, essentialSpellIDs) then
				hasUniqueUtilitySpell = true
				break
			end
		end

		if not hasUniqueUtilitySpell then done() return end

		Modals.CardPicker({
			title   = 'Utility Cooldowns Detected',
			message = "Your Cooldown Manager (/cdm) has spells in its Utility section, but BluUI's Utility Viewer is turned off (/bui > CDM > Utility Viewer). Those spells are not shown anywhere until you pick one of these.",
			cards = {
				{
					recommended = true,
					icon        = 134063,
					title       = 'Open Cooldown Manager',
					desc        = 'Move the spells from the Utility section into Essential, where the Essential Viewer shows them.',
					onClick     = function()
						C_Timer.After(0, function()
							if CooldownViewerSettings then CooldownViewerSettings:SetShown(true) end
						end)
					end,
				},
				{
					icon    = 136243,
					title   = 'Enable Utility Viewer',
					desc    = "Turn on BluUI's Utility Viewer (/bui > CDM > Utility Viewer) and reload the UI.",
					onClick = function()
						utilitySettings.enabled = true
						BUI.Reload()
					end,
				},
			},
			onHide = done,
		})
	end

	if UtilityCooldownViewer and UtilityCooldownViewer.itemFramePool then
		Evaluate()
	end
	if not finished then
		BUI.Events:Register('COOLDOWN_VIEWER_DATA_LOADED', 'CDM.UtilityCheck', Evaluate)
		C_Timer.After(20, Finish)
	end
end
