local ADDON_NAME, BUI = ...

BluUI = BUI
BUI.ADDON_NAME = ADDON_NAME

function BUI.Print(message) print(BUI.C.CHAT_PREFIX .. message) end

local EDIT_MODE_WRITE_WINDOW = 10
local editModeWriteWindowOpen = true

function BUI.CanWriteEditModeLayout()
	return editModeWriteWindowOpen
end

function BUI.CloseEditModeWriteWindow()
	BUI.Prof.After('Core.Core', EDIT_MODE_WRITE_WINDOW, function() editModeWriteWindowOpen = false end)
end

local LibEMO = LibStub('LibEditModeOverride-1.0')

function BUI.LeaveFrameManager(frame, point, relativePoint, offsetX, offsetY)
	local systemInfo = frame.systemInfo
	if not (systemInfo and systemInfo.isInDefaultPosition) then return end
	if not editModeWriteWindowOpen or InCombatLockdown() or not LibEMO:IsReady() then return end
	LibEMO:LoadLayouts()
	if not LibEMO:CanEditActiveLayout() or not LibEMO:HasEditModeSettings(frame) then return end
	LibEMO:ReanchorFrame(frame, point, UIParent, relativePoint, offsetX, offsetY)
	LibEMO:SaveOnly()
end

function BUI.GetDB()
	return BUI.db and BUI.db.profile
end

function BUI.GetAceDB()
	return BUI.db
end

function BUI.IsModuleEnabled(key)
	local db = BUI.GetDB()
	local modules = db and db.modules
	return not modules or modules[key] ~= false
end

BUI.ModuleControls = {}
function BUI.RegisterModuleControl(key, handler) BUI.ModuleControls[key] = handler end
function BUI.ApplyModuleRuntime(key)
	local handler = BUI.ModuleControls[key]
	if not handler then return false end
	handler(BUI.IsModuleEnabled(key))
	return true
end

function BUI.SetModuleEnabled(key, enabled)
	local db = BUI.GetDB()
	if not db then return end
	db.modules = db.modules or {}
	db.modules[key] = enabled and true or false
	BUI.ApplyModuleRuntime(key)
end

local BUILib     = LibStub('BUILib')
local AceAddon = LibStub('AceAddon-3.0')
local AceDB    = LibStub('AceDB-3.0')
BUI.BUILibClient = BUILib.NewClient('BluUI', {
	getDB     = BUI.GetDB,
	mediaPath = BUI.C.MEDIA_PATH,
	font      = BUI.C.FONT_PATH,
	default   = true,
})
BUI.Modals = BUI.BUILibClient.Modals
BUILib.Controls.SetColorPickerDB(BUI.GetDB)
BUI.Version = C_AddOns.GetAddOnMetadata(ADDON_NAME, 'Version')

local Addon = AceAddon:NewAddon('BluUI')
LibStub('AceHook-3.0'):Embed(BUI)

local SCALE_FLOOR, SCALE_CEILING = 0.35, 1.15

local function ClampScale(value)
	if value < SCALE_FLOOR then return SCALE_FLOOR end
	if value > SCALE_CEILING then return SCALE_CEILING end
	return value
end

function BUI.DeviceScale()
	local _, physicalHeight = GetPhysicalScreenSize()
	return 768 / physicalHeight
end

function BUI.ClampedUIScale()
	return ClampScale(BUI.DeviceScale())
end

function BUI.AppliedUIScale()
	local db = BUI.GetDB()
	local saved = db and db.uiScale.scale
	local best = BUI.ClampedUIScale()
	if saved and BUI.ApproxEqual(saved, best) then return best end
	if saved then return ClampScale(saved) end
	return best
end

function BUI.ApplyScale()
	local newScale = BUI.AppliedUIScale()
	BUI.Events:AfterCombat(function()
		BUI._applyingScale = true
		UIParent:SetScale(newScale)
		BUI._applyingScale = false
		if BUI.Minimap then BUI.Minimap.ApplyPosition() end
	end, 'ApplyScale.SetScale')
end

function BUI:OnNewProfile(_, db)
	if BUI._suppressProfileCallback then return end
	BUI.ExportImport.ApplyDefaultProfile(rawget(db, 'profile'))
end

function BUI:OnProfileChanged(event)
	if BUI._suppressProfileCallback then return end
	if event == 'OnProfileReset' then BUI.ExportImport.ApplyDefaultProfile(BUI.GetDB()) end

	BUI.MigrateProfile(BUI.GetDB())
	BUI.Skinning.SeedSkinStates()
	BUI.ExportImport.RefreshAllModules()
	BUI.PageEngine.RebuildAllPages()
end

local function AdoptOldDB(legacyDatabase)
	local copy = BUI.Tools.DeepCopy(legacyDatabase)
	BUI.FixLegacyValues(copy)
	return copy
end

function BUI.ImportAzorProfiles()
	if not BluUI_DB then return end
	if type(AzortharionUI_DB) == 'table' then
		BluUI_DB.__forceAdoptOnLoad = true
	else
		C_AddOns.EnableAddOn('AzortharionUI')
		BluUI_DB.__forceAdoptOnLoad = 'disableAfter'
	end
	ReloadUI()
end

local function PromptAzorImport()
	BUI.Modals.Confirm({
		title = 'AzortharionUI Detected',
		message = 'Import your AzortharionUI profiles into BluUI?',
		confirmText = 'Import & Reload', cancelText = 'Not Now', fullscreen = true,
		onConfirm = BUI.ImportAzorProfiles,
		onCancel = function()
			if BluUI_DB then BluUI_DB.__azorImportDeclined = true end
			BUI.Print('Skipped. Import later from the Profiles page.')
		end,
	})
end

function Addon:OnInitialize()
	BUI.Prof.CheckStartupCapture()
	local initializeStart = debugprofilestop()
	local forcedAdopt = BluUI_DB and BluUI_DB.__forceAdoptOnLoad
	if BluUI_DB then BluUI_DB.__forceAdoptOnLoad = nil end

	if forcedAdopt and type(AzortharionUI_DB) == 'table' then
		BluUI_DB = AdoptOldDB(AzortharionUI_DB)
		BluUI_DB.__adoptedLegacySettings = true
		BluUI_DB.__adoptedLegacySettings_v2 = true
		if forcedAdopt == 'disableAfter' then
			C_AddOns.DisableAddOn('AzortharionUI')
			BUI.Prof.After('Core.Core', 1, function()
				BUI.Print('Profiles copied, reloading.')
				BUI.Prof.After('Core.Core', 1.5, ReloadUI)
			end)
		else
			BUI.Prof.After('Core.Core', 1, function()
				BUI.Print('Copied your AzortharionUI profiles.')
			end)
		end
	elseif forcedAdopt then
		BUI.Prof.After('Core.Core', 1, function()
			BUI.Print('AzortharionUI did not load. Enable it and retry.')
		end)
	elseif type(AzortharionUI_DB) == 'table'
		and not (BluUI_DB and (BluUI_DB.__adoptedLegacySettings_v2 or BluUI_DB.__azorImportDeclined)) then
		BUI.Events:Once('PLAYER_ENTERING_WORLD', 'AzorImportPrompt', function()
			BUI.Prof.After('Core.Core', 2, PromptAzorImport)
		end)
	end

	local savedVariables = BluUI_DB or {}
	local charKey = UnitName('player') .. ' - ' .. GetRealmName()
	local isNewChar = not (savedVariables.profileKeys and savedVariables.profileKeys[charKey])
	local knownProfiles = {}
	for name in pairs(savedVariables.profiles or {}) do knownProfiles[name] = true end

	BUI.db = AceDB:New('BluUI_DB', BUI.Defaults, true)

	BUI.Events:Register('ADDON_LOADED', 'Core.DBGuard', function()
		if BluUI_DB ~= BUI.db.sv then
			BluUI_DB = BUI.db.sv
		end
	end)

	BUI.BUILibClient.SetFont(BUI.GetAddonFont())
	BUI.BUILibClient.SetCardStyle('datasheet')

	if isNewChar and BUI.db.global.defaultProfile then
		local target = BUI.db.global.defaultProfile
		if target ~= BUI.db:GetCurrentProfile() then
			BUI.db:SetProfile(target)
		end
	end
	if not knownProfiles[BUI.db:GetCurrentProfile()] then
		BUI.ExportImport.ApplyDefaultProfile(BUI.db.profile)
	end
	BUI.db.RegisterCallback(BUI, 'OnNewProfile', 'OnNewProfile')

	for _, event in ipairs({ 'OnProfileChanged', 'OnProfileCopied', 'OnProfileReset' }) do
		BUI.db.RegisterCallback(BUI, event, 'OnProfileChanged')
	end

	BUI.RunMigrations()
	BUI.Skinning.SeedSkinStates()

	BUI.Print('Using profile: |cff' .. BUI.C.COLOR_PINK .. BUI.db:GetCurrentProfile() .. '|r')
	if BUI.InitializeMinimapButton then BUI.InitializeMinimapButton() end
	if BUI.Prof.active then BUI.Prof.Add('startup#OnInitialize', debugprofilestop() - initializeStart) end
end

function Addon:OnEnable()
	local Measure = BUI.Prof.Measure
	Measure('startup#SpecProfiles', BUI.SpecProfiles.ApplyOnLogin)

	BUI.BUILibClient.defaultWidth = BUI.C.PAGE_CONTENT_W
	BUI.BUILibClient.modalColor = { BUI.C.PANEL_BACKDROP[1], BUI.C.PANEL_BACKDROP[2], BUI.C.PANEL_BACKDROP[3], BUI.C.PANEL_BACKDROP[4] }
	BUI.BUILibClient.modalBorderColor = { BUI.C.PANEL_BACKDROP[5], BUI.C.PANEL_BACKDROP[6], BUI.C.PANEL_BACKDROP[7], BUI.C.PANEL_BACKDROP[8] }
	BUI.BUILibClient.bodyFont = BUI.GetGlobalFont()

	if BUI.ActionBars and BUI.IsModuleEnabled('actionBars') then Measure('startup#ActionBars', BUI.ActionBars.Initialize) end
	if BUI.UnitFrames and BUI.IsModuleEnabled('unitFrames') then Measure('startup#UnitFrames', BUI.UnitFrames.Initialize, BUI.UnitFrames) end
	if BUI.GroupFrames and BUI.IsModuleEnabled('groupFrames') then Measure('startup#GroupFrames', BUI.GroupFrames.Initialize) end
	if BUI.CDM and BUI.IsModuleEnabled('cdm') then Measure('startup#CDM', BUI.CDM.Initialize) end
	if BUI.CastBar and BUI.CastBar.RefreshAll and BUI.IsModuleEnabled('castBars') then BUI.Prof.After('Core.CastBars', 0.1, BUI.CastBar.RefreshAll) end
	if BUI.Power and BUI.Power.Secondary and BUI.IsModuleEnabled('power') then Measure('startup#Power', BUI.Power.Secondary.Initialize) end

	if BUI.db.global.layoutStyle then
		BUI.BUILibClient.Layout.SetStyle(BUI.db.global.layoutStyle)
	end

	local function ReassertBUILib()
		BUILib.SetDefaultClient(BUI.BUILibClient)
		BUI.BUILibClient.Colors.RefreshAccent()
	end
	ReassertBUILib()
	BUI.Events:Register('ADDON_LOADED', 'Core.BUILibReassert', function()
		if BUILib.GetActiveClient() ~= BUI.BUILibClient then ReassertBUILib() end
	end)

	local lastSpecID
	local function CurrentSpecID()
		local spec = GetSpecialization()
		return spec and GetSpecializationInfo(spec)
	end
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Core.SpecPageRebuildSeed', function()
		if lastSpecID == nil then lastSpecID = CurrentSpecID() end
		if lastSpecID then BUI.Events:Unregister('PLAYER_ENTERING_WORLD', 'Core.SpecPageRebuildSeed') end
	end)
	BUI.Events:OnTalentBurst('Core.SpecPageRebuild', function()
		local specID = CurrentSpecID()
		if not specID or specID == lastSpecID then return end
		lastSpecID = specID
		BUI.PageEngine.RebuildAllPages()
	end)

	BUI.ReassertBUILib = ReassertBUILib
	local pink = BUI.C.COLOR_PINK
	BUI.Print('Loaded! Type |cff' .. pink .. '/bui|r, |cff' .. pink .. '/blu|r, or |cff' .. pink .. '/bluui|r to open menu!')

	BUI.Events:Once('PLAYER_ENTERING_WORLD', 'Core', function()
		ReassertBUILib()
		local scaleBefore = UIParent:GetScale()
		Measure('startup#ApplyScale', BUI.ApplyScale)
		BUI.CloseEditModeWriteWindow()
		if not BUI.ApproxEqual(scaleBefore, UIParent:GetScale()) then
			Measure('startup#RefreshAllModules', BUI.ExportImport.RefreshAllModules)
		else
			if BUI.UnitFrames and BUI.IsModuleEnabled('unitFrames') then
				Measure('startup#RefreshUnitFrames', function()
					BUI.UnitFrames.InvalidateFilterCache()
					BUI.UnitFrames:Refresh()
				end)
			end
			Measure('startup#RefreshSkins', BUI.Skinning.RefreshAll)
		end
		if BUI.CDM then BUI.QueueStartupCheck(BUI.CDM.CheckDisabled) end
		BUI.QueueStartupCheck(BUI.CheckPlatynatorPrompt)
		if BUI.CDM then BUI.QueueStartupCheck(BUI.CDM.CheckUtilityPrompt) end
	end)
end
Addon.OnEnable = BUI.Prof.Wrap('startup#OnEnable', Addon.OnEnable)
