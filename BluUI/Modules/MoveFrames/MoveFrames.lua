local _, BUI = ...

local Events = BUI.Events

local MoveFrames = {}
BUI.MoveFrames = MoveFrames

local InCombatLockdown = InCombatLockdown
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local issecretvalue = issecretvalue

local CONFLICTING_ADDONS = { 'BlizzMove', 'MoveAnything' }

local ALWAYS_LOADED = {
	'AddFriendFrame',
	'AddonList',
	'BattleNetInviteFrame',
	'BankFrame',
	'BNToastFrame',
	{ 'BonusRollFrame', 'BonusRollFrame.PromptFrame', 'BonusRollFrame.PromptFrame.InfoFrame', 'BonusRollFrame.RollingFrame', 'BonusRollFrame.BlackBackgroundHoist' },
	'ChatConfigFrame',
	'GossipFrame',
	'GuildRegistrarFrame',
	'HelpFrame',
	'ItemTextFrame',
	'LFDRoleCheckPopup',
	'LFGInvitePopup',
	'LFGListApplicationDialog',
	'LFGListInviteDialog',
	'LFGDungeonReadyDialog',
	'LFGDungeonReadyStatus',
	'LootFrame',
	'LossOfControlFrame',
	'MerchantFrame',
	'ModelPreviewFrame',
	'PetitionFrame',
	'PVEFrame',
	'PVPReadyDialog',
	'QuestFrame',
	'QuestLogPopupDetailFrame',
	'QuickJoinRoleSelectionFrame',
	'QuickKeybindFrame',
	'RaidInfoFrame',
	'ReadyCheckFrame',
	'RecruitAFriendRecruitmentFrame',
	'RecruitAFriendRewardsFrame',
	'ReportFrame',
	'RolePollPopup',
	'SettingsPanel',
	'SideDressUpFrame',
	'SplashFrame',
	'TabardFrame',
	'TaxiFrame',
	'TradeFrame',
	{ 'DressUpFrame', 'DressUpFrame.OutfitDetailsPanel', 'DressUpFrame.SetSelectionPanel' },
	{ 'FriendsFrame', 'FriendsFrame.IgnoreListWindow' },
	'FriendsFriendsFrame',
	{ 'MailFrame', 'SendMailFrame', 'OpenMailFrame', 'OpenMailFrame.OpenMailSender' },
	{ 'WorldMapFrame', 'QuestMapFrame' },
}

local LOAD_ON_DEMAND = {
	Blizzard_AchievementUI = { { 'AchievementFrame', 'AchievementFrame.Header', 'AchievementFrame.SearchResults' } },
	Blizzard_AlliedRacesUI = { 'AlliedRacesFrame' },
	Blizzard_AnimaDiversionUI = { 'AnimaDiversionFrame' },
	Blizzard_ArchaeologyUI = { 'ArchaeologyFrame' },
	Blizzard_ArtifactUI = { 'ArtifactFrame' },
	Blizzard_AuctionHouseUI = { 'AuctionHouseFrame', 'AuctionHouseMultisellProgressFrame' },
	Blizzard_AzeriteEssenceUI = { 'AzeriteEssenceUI' },
	Blizzard_AzeriteRespecUI = { 'AzeriteRespecFrame' },
	Blizzard_AzeriteUI = { 'AzeriteEmpoweredItemUI' },
	Blizzard_BarbershopUI = { 'BarberShopFrame' },
	Blizzard_BindingUI = { 'KeyBindingFrame' },
	Blizzard_BlackMarketUI = { 'BlackMarketFrame' },
	Blizzard_Calendar = {
		{ 'CalendarFrame', 'CalendarCreateEventFrame', 'CalendarViewEventFrame', 'CalendarViewHolidayFrame', 'CalendarViewRaidFrame' },
	},
	Blizzard_CatalogShop = { 'CatalogShopFrame' },
	Blizzard_ChallengesUI = { 'ChallengesKeystoneFrame' },
	Blizzard_Channels = { 'ChannelFrame', 'CreateChannelPopup' },
	Blizzard_ChromieTimeUI = { 'ChromieTimeFrame' },
	Blizzard_ClickBindingUI = { 'ClickBindingFrame' },
	Blizzard_Collections = { 'CollectionsJournal' },
	Blizzard_Communities = {
		{ 'CommunitiesFrame', 'CommunitiesFrame.GuildMemberDetailFrame', 'CommunitiesFrame.NotificationSettingsDialog' },
		'CommunitiesSettingsDialog',
		'CommunitiesGuildLogFrame',
		'CommunitiesGuildNewsFiltersFrame',
		'CommunitiesGuildTextEditFrame',
		'CommunitiesAvatarPickerDialog',
		'CommunitiesTicketManagerDialog',
	},
	Blizzard_Contribution = { 'ContributionCollectionFrame' },
	Blizzard_CooldownViewer = { 'CooldownViewerSettings' },
	Blizzard_CovenantPreviewUI = { 'CovenantPreviewFrame' },
	Blizzard_CovenantRenown = { 'CovenantRenownFrame' },
	Blizzard_CovenantSanctum = { 'CovenantSanctumFrame' },
	Blizzard_DeathRecap = { 'DeathRecapFrame' },
	Blizzard_DelvesCompanionConfiguration = { 'DelvesCompanionConfigurationFrame', 'DelvesCompanionAbilityListFrame' },
	Blizzard_DelvesDifficultyPicker = { 'DelvesDifficultyPickerFrame' },
	Blizzard_EncounterJournal = { 'EncounterJournal' },
	Blizzard_ExpansionLandingPage = { 'ExpansionLandingPage' },
	Blizzard_FlightMap = { 'FlightMapFrame' },
	Blizzard_GarrisonUI = {
		'GarrisonLandingPage',
		'GarrisonMissionFrame',
		'OrderHallMissionFrame',
		'BFAMissionFrame',
		'CovenantMissionFrame',
		'GarrisonBuildingFrame',
		'GarrisonShipyardFrame',
		'GarrisonCapacitiveDisplayFrame',
		'GarrisonRecruiterFrame',
		'GarrisonRecruitSelectFrame',
		'GarrisonMonumentFrame',
	},
	Blizzard_GenericTraitUI = { 'GenericTraitFrame' },
	Blizzard_GuildBankUI = { 'GuildBankFrame', 'GuildBankPopupFrame' },
	Blizzard_GuildControlUI = { 'GuildControlUI' },
	Blizzard_HouseList = { 'HouseListFrame' },
	Blizzard_HousingBlueprint = {
		'HousingBlueprintContentListFrame',
		'HousingBlueprintExportFrame',
		'HousingBlueprintImportFrame',
		'HousingBlueprintRenameFrame',
	},
	Blizzard_HousingBulletinBoard = { 'HousingBulletinBoardFrame', 'HousingInviteResidentFrame' },
	Blizzard_HousingCornerstone = {
		'HousingCornerstoneFrame',
		'HousingCornerstoneHouseInfoFrame',
		'HousingCornerstonePurchaseFrame',
		'HousingCornerstoneVisitorFrame',
	},
	Blizzard_HousingCreateNeighborhood = { 'HousingCreateNeighborhoodCharterFrame' },
	Blizzard_HousingDashboard = { 'HousingDashboardFrame' },
	Blizzard_HousingHouseFinder = { 'HouseFinderFrame' },
	Blizzard_HousingHouseSettings = { 'HousingHouseSettingsFrame' },
	Blizzard_HousingModelPreview = { 'HousingModelPreviewFrame' },
	Blizzard_InspectUI = { 'InspectFrame' },
	Blizzard_IslandsQueueUI = { 'IslandsQueueFrame' },
	Blizzard_ItemInteractionUI = { 'ItemInteractionFrame' },
	Blizzard_ItemSocketingUI = { 'ItemSocketingFrame' },
	Blizzard_ItemUpgradeUI = { 'ItemUpgradeFrame' },
	Blizzard_LootHistory = { 'GroupLootHistoryFrame' },
	Blizzard_MacroUI = { 'MacroFrame', 'MacroPopupFrame' },
	Blizzard_MajorFactions = { 'MajorFactionRenownFrame' },
	Blizzard_ObliterumUI = { 'ObliterumForgeFrame' },
	Blizzard_OrderHallUI = { 'OrderHallTalentFrame' },
	Blizzard_PerksProgram = { 'PerksProgramFrame' },
	Blizzard_PlayerChoice = { 'PlayerChoiceFrame' },
	Blizzard_PlayerSpells = {
		'PlayerSpellsFrame',
		'HeroTalentsSelectionDialog',
		'ClassTalentLoadoutImportDialog',
		'ClassTalentLoadoutCreateDialog',
		'ClassTalentLoadoutEditDialog',
	},
	Blizzard_Professions = { 'ProfessionsFrame', 'InspectRecipeFrame' },
	Blizzard_ProfessionsBook = { 'ProfessionsBookFrame' },
	Blizzard_ProfessionsCustomerOrders = { 'ProfessionsCustomerOrdersFrame' },
	Blizzard_PVPMatch = { 'PVPMatchResults' },
	Blizzard_PVPUI = { 'PVPMatchScoreboard' },
	Blizzard_RemixArtifactUI = { 'RemixArtifactFrame' },
	Blizzard_RuneforgeUI = { 'RuneforgeFrame' },
	Blizzard_ScrappingMachineUI = { 'ScrappingMachineFrame' },
	Blizzard_Soulbinds = { 'SoulbindViewer' },
	Blizzard_StableUI = { 'StableFrame' },
	Blizzard_TalkingHeadUI = { 'TalkingHeadFrame' },
	Blizzard_TimeManager = { 'TimeManagerFrame', 'StopwatchFrame' },
	Blizzard_TorghastLevelPicker = { 'TorghastLevelPickerFrame' },
	Blizzard_TrainerUI = { 'ClassTrainerFrame' },
	Blizzard_Transmog = { 'TransmogFrame' },
	Blizzard_UIPanels_Game = { { 'CharacterFrame', 'PaperDollFrame', 'ReputationFrame', 'TokenFrame' } },
	Blizzard_VoidStorageUI = { 'VoidStorageFrame' },
	Blizzard_WeeklyRewards = { 'WeeklyRewardsFrame', 'WeeklyRewardExpirationWarningDialog' },
}

local NEVER_REMEMBER = {
	BonusRollFrame = true,
	PlayerChoiceFrame = true,
}

local OFFSCREEN_MARGIN = 4

local dragTarget = {}
local framePath  = {}
local hookedRoot = {}
local savedMouse = {}
local moving     = {}
local dragged    = {}
local blizzardPoints = {}
local heldPoints = {}
local applying   = false
local suspended  = {}

local POSITION_MODES = { remember = true, session = true, reset = true }

local function GetConfig()
	local config = BUI.GetDB().moveFrames
	if config.autoReset ~= nil or config.rememberPositions ~= nil then
		if config.autoReset then
			config.positionMode = 'reset'
		elseif config.rememberPositions == false then
			config.positionMode = 'session'
		end
		config.autoReset, config.rememberPositions = nil, nil
	end
	if not POSITION_MODES[config.positionMode] then config.positionMode = 'remember' end
	return config
end

function MoveFrames.GetConfig()
	return GetConfig()
end

function MoveFrames.IsActive()
	if MoveFrames.blockedBy then return false end
	return GetConfig().enabled ~= false
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

local function ResolvePath(path)
	if type(path) ~= 'string' then return nil end
	local current = _G
	for segment in path:gmatch('[^.]+') do
		if type(current) ~= 'table' then return nil end
		current = current[segment]
	end
	if type(current) ~= 'table' or not current.GetObjectType then return nil end
	return current
end

local function CanTouch(frame)
	return not (InCombatLockdown() and frame:IsProtected())
end

local function IsSuppressed(handle)
	local target = dragTarget[handle]
	return handle._buiSuppressActive or (target ~= nil and target._buiSuppressActive) or false
end

local function IsLocked(target)
	return target.IsMaximized ~= nil and target:IsMaximized()
end

local function IsOffScreen(frame)
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (left and right and top and bottom) then return false end
	if IsSecret(left) or IsSecret(right) or IsSecret(top) or IsSecret(bottom) then return false end
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	left, right, top, bottom = left * ratio, right * ratio, top * ratio, bottom * ratio
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	return right < OFFSCREEN_MARGIN
		or left > screenWidth - OFFSCREEN_MARGIN
		or top < OFFSCREEN_MARGIN
		or bottom > screenHeight - OFFSCREEN_MARGIN
end

local function SnapshotBlizzardPoints(target)
	local count = target:GetNumPoints()
	if count == 0 then return end
	local snapshot = {}
	for index = 1, count do
		local point, relativeTo, relativePoint, x, y = target:GetPoint(index)
		if not point or IsSecret(x) or IsSecret(y) then return end
		snapshot[index] = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
	end
	blizzardPoints[target] = snapshot
end

local function RestoreBlizzardPoints(target)
	local snapshot = blizzardPoints[target]
	if not snapshot then
		dragged[target] = nil
		return
	end
	if not CanTouch(target) then
		Events:AfterCombat(function() RestoreBlizzardPoints(target) end, 'MoveFrames:Restore:' .. (framePath[target] or tostring(target)))
		return
	end

	applying = true
	target:ClearAllPoints()
	for _, anchor in ipairs(snapshot) do
		target:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y)
	end
	applying = false
	dragged[target] = nil
end

local function SavePosition(target)
	local config = GetConfig()
	local path = framePath[target]
	if config.positionMode ~= 'remember' or not path or NEVER_REMEMBER[path] then return end

	if IsOffScreen(target) then
		config.positions[path] = nil
		return
	end

	local point, relativeTo, relativePoint, x, y = target:GetPoint(1)
	if not point or IsSecret(x) or IsSecret(y) then return end

	local relativeName = relativeTo and relativeTo.GetName and relativeTo:GetName()
	if not relativeName then
		local parent = target:GetParent()
		relativeName = parent and parent.GetName and parent:GetName() or 'UIParent'
	end

	config.positions[path] = {
		point = point,
		relativeTo = relativeName,
		relativePoint = relativePoint,
		x = x,
		y = y,
	}
end

local function ApplySavedPosition(target)
	local config = GetConfig()
	if not MoveFrames.IsActive() or config.positionMode ~= 'remember' then return end
	local path = framePath[target]
	local saved = path and config.positions[path]
	if not saved or moving[target] or IsLocked(target) or not CanTouch(target) then return end

	local relativeTo = ResolvePath(saved.relativeTo) or UIParent
	applying = true
	target:ClearAllPoints()
	target:SetPoint(saved.point, relativeTo, saved.relativePoint, saved.x, saved.y)
	applying = false

	if IsOffScreen(target) then
		config.positions[path] = nil
	end

	return true
end

local function HoldDraggedPosition(target)
	local held = heldPoints[target]
	if not held or moving[target] or IsLocked(target) or not CanTouch(target) then return end
	applying = true
	target:ClearAllPoints()
	target:SetPoint(held.point, held.relativeTo, held.relativePoint, held.x, held.y)
	applying = false
end

local function CaptureDraggedPosition(target)
	local point, relativeTo, relativePoint, x, y = target:GetPoint(1)
	if not point or IsSecret(x) or IsSecret(y) then return end
	heldPoints[target] = {
		point = point,
		relativeTo = relativeTo or target:GetParent() or UIParent,
		relativePoint = relativePoint or point,
		x = x,
		y = y,
	}
end

local function OnTargetSetPoint(target)
	if applying or suspended[target] then return end
	if not moving[target] then SnapshotBlizzardPoints(target) end
	if not ApplySavedPosition(target) then HoldDraggedPosition(target) end
end

local function StopDrag(target)
	if not moving[target] then return end
	target:StopMovingOrSizing()
	moving[target] = nil
end

local function AutoResetIfDragged(target)
	local config = GetConfig()
	if config.positionMode ~= 'reset' or not dragged[target] then return end

	heldPoints[target] = nil
	RestoreBlizzardPoints(target)
end

local function OnTargetHide(target)
	StopDrag(target)
	AutoResetIfDragged(target)
end

local function OnTargetShow(target)
	AutoResetIfDragged(target)
	HoldDraggedPosition(target)
end

local function OnHandleMouseDown(handle, button)
	if button ~= 'LeftButton' or not MoveFrames.IsActive() then return end
	local target = dragTarget[handle]
	if not target or moving[target] or IsLocked(target) then return end
	if not CanTouch(handle) or not CanTouch(target) then return end

	if not target:IsMovable() then target:SetMovable(true) end
	local wasUserPlaced = target:IsUserPlaced()
	target:StartMoving()
	target:SetUserPlaced(wasUserPlaced)
	moving[target] = true
end

local function OnHandleMouseUp(handle, button)
	if button ~= 'LeftButton' then return end
	local target = dragTarget[handle]
	if not target or not moving[target] then return end
	StopDrag(target)
	dragged[target] = true
	if CanTouch(target) then
		CaptureDraggedPosition(target)
		SavePosition(target)
	end
end

local function InstallHandleHooks(handle)
	if handle:HasScript('OnMouseDown') then handle:HookScript('OnMouseDown', OnHandleMouseDown) end
	if handle:HasScript('OnMouseUp') then handle:HookScript('OnMouseUp', OnHandleMouseUp) end
end

local function HookFrame(path, rootPath)
	local handle = ResolvePath(path)
	if not handle or dragTarget[handle] then return end

	if not CanTouch(handle) then
		Events:AfterCombat(function() HookFrame(path, rootPath) end, 'MoveFrames:' .. path)
		return
	end

	local target = rootPath and ResolvePath(rootPath) or handle
	if not target then return end

	dragTarget[handle] = target
	framePath[handle] = path
	if not framePath[target] then framePath[target] = rootPath or path end

	savedMouse[handle] = handle:IsMouseEnabled()
	if not IsSuppressed(handle) then handle:EnableMouse(true) end
	InstallHandleHooks(handle)

	local rehooking = false
	hooksecurefunc(handle, 'SetScript', function(self, scriptName)
		if rehooking or self ~= handle then return end
		if scriptName ~= 'OnMouseDown' and scriptName ~= 'OnMouseUp' then return end
		rehooking = true
		if scriptName == 'OnMouseDown' then
			handle:HookScript('OnMouseDown', OnHandleMouseDown)
		else
			handle:HookScript('OnMouseUp', OnHandleMouseUp)
		end
		rehooking = false
	end)

	if not hookedRoot[target] then
		hookedRoot[target] = true
		target:SetMovable(true)
		target:SetClampedToScreen(true)
		SnapshotBlizzardPoints(target)
		hooksecurefunc(target, 'SetPoint', OnTargetSetPoint)
		target:HookScript('OnHide', OnTargetHide)
		target:HookScript('OnShow', OnTargetShow)
		ApplySavedPosition(target)
	end
end

local function HookList(list)
	for _, entry in ipairs(list) do
		if type(entry) == 'string' then
			HookFrame(entry)
		else
			local root = entry[1]
			HookFrame(root)
			for index = 2, #entry do
				HookFrame(entry[index], root)
			end
		end
	end
end

local function OnAddonLoaded(_, addonName)
	local list = LOAD_ON_DEMAND[addonName]
	if list then HookList(list) end
end

local function DetectConflicts()
	for _, addonName in ipairs(CONFLICTING_ADDONS) do
		if IsAddOnLoaded(addonName) then
			MoveFrames.blockedBy = addonName
			return true
		end
	end
	return false
end

function MoveFrames.Initialize()
	if MoveFrames.initialized or DetectConflicts() then return end
	MoveFrames.initialized = true

	HookList(ALWAYS_LOADED)
	for addonName, list in pairs(LOAD_ON_DEMAND) do
		if IsAddOnLoaded(addonName) then HookList(list) end
	end
	Events:Register('ADDON_LOADED', 'MoveFrames', OnAddonLoaded)
end

function MoveFrames.Refresh()
	local active = MoveFrames.IsActive()
	if active and not MoveFrames.initialized then MoveFrames.Initialize() end
	for handle, wasEnabled in pairs(savedMouse) do
		if CanTouch(handle) and not IsSuppressed(handle) then handle:EnableMouse(active or wasEnabled) end
	end
end

function MoveFrames.SetSuspended(frame, isSuspended)
	suspended[frame] = isSuspended or nil
end

function MoveFrames.OnFrameRestored(frame)
	if not MoveFrames.IsActive() then return end
	for handle, target in pairs(dragTarget) do
		if (handle == frame or target == frame) and CanTouch(handle) then handle:EnableMouse(true) end
	end
end

function MoveFrames.SetEnabled(enabled)
	local config = GetConfig()
	config.enabled = enabled and true or false
	MoveFrames.Refresh()
end

function MoveFrames.ResetPositions()
	local config = GetConfig()
	wipe(config.positions)
	wipe(BUI.GetDB().framePositions)

	if InCombatLockdown() then return end
	for target in pairs(hookedRoot) do
		if target:IsShown() then
			UpdateUIPanelPositions()
			return
		end
	end
end

Events:OnLogin('MoveFrames', function()
	DetectConflicts()
	if MoveFrames.IsActive() then MoveFrames.Initialize() end
end)
