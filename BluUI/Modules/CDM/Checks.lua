local _, BUI = ...
local CDM    = BUI.CDM
local Modals = BUI.BUILibClient.Modals

local SafeNum = BUI.Tools.SafeNum
local COOLDOWN_VIEWER_CVAR = 'cooldownViewerEnabled'
local LAYOUT_SETTLE_SECONDS = 5
local DATA_CHANGED_CALLBACK = 'CooldownViewerSettings.OnDataChanged'

local viewerDataLoaded = false
local pendingUtilityDone
local dataChangedOwner = {}

BUI.Events:Once('COOLDOWN_VIEWER_DATA_LOADED', 'CDM.Checks', function()
	viewerDataLoaded = true
end)

local function AnyViewerEnabled(db)
	for _, key in ipairs(CDM.VIEWER_KEYS) do
		if db.cdm[key].enabled then return true end
	end
	return false
end

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
	if not AnyViewerEnabled(BUI.GetDB()) or C_CVar.GetCVarBool(COOLDOWN_VIEWER_CVAR) then done() return end

	BUI.Profiler.After('CDM.Checks disabled prompt', LAYOUT_SETTLE_SECONDS, function()
		if C_CVar.GetCVarBool(COOLDOWN_VIEWER_CVAR) then done() return end
		Modals.Confirm({
			title       = 'Cooldown Manager Disabled',
			message     = "Blizzard's Cooldown Manager is turned off.\nBluUI's CDM requires it. Enable and reload?",
			confirmText = 'Enable & Reload',
			cancelText  = 'Close',
			onConfirm   = function()
				SetCVar(COOLDOWN_VIEWER_CVAR, '1')
				ReloadUI()
			end,
			onCancel = done,
		})
	end)
end

local function ViewersReady()
	return viewerDataLoaded and CooldownViewerSettings:GetDataProvider() ~= nil
end

local function PromptForUtility(done)
	local essentialSpellIDs = CollectSpellIDs(EssentialCooldownViewer)

	local hasUniqueUtilitySpell = false
	for frame in UtilityCooldownViewer.itemFramePool:EnumerateActive() do
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
					BUI.Profiler.After('CDM.Checks open settings', 0, function()
						CooldownViewerSettings:SetShown(true)
					end)
				end,
			},
			{
				icon    = 136243,
				title   = 'Enable Utility Viewer',
				desc    = "Turn on BluUI's Utility Viewer (/bui > CDM > Utility Viewer) and reload the UI.",
				onClick = function()
					BUI.GetDB().cdm.utility.enabled = true
					ReloadUI()
				end,
			},
		},
		onHide = done,
	})
end

local function OnViewerDataChanged()
	BUI.Profiler.After('CDM.Checks viewer data', 0, function()
		local done = pendingUtilityDone
		if not done or not ViewersReady() then return end
		pendingUtilityDone = nil
		EventRegistry:UnregisterCallback(DATA_CHANGED_CALLBACK, dataChangedOwner)
		PromptForUtility(done)
	end)
end

function CDM.CheckUtilityPrompt(done)
	local db = BUI.GetDB()
	if not AnyViewerEnabled(db) then done() return end
	if db.cdm.utility.enabled then done() return end
	if ViewersReady() then PromptForUtility(done) return end
	pendingUtilityDone = done
	EventRegistry:RegisterCallback(DATA_CHANGED_CALLBACK, OnViewerDataChanged, dataChangedOwner)
end
