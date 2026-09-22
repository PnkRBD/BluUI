local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Util.Visibility')
local Visibility = {}
BUI.Visibility = Visibility
local InCombatLockdown      = InCombatLockdown
local UnitAffectingCombat   = UnitAffectingCombat
local UnitIsDeadOrGhost     = UnitIsDeadOrGhost
local UnitInVehicle         = UnitInVehicle
local HasOverrideActionBar  = HasOverrideActionBar
local IsFlying              = IsFlying
local IsMounted             = IsMounted
local IsInInstance          = IsInInstance
local C_PetBattles          = C_PetBattles

local CONDITIONS = {
	petBattle = function()
		return C_PetBattles.IsInBattle()
	end,
	dead = function()
		return UnitIsDeadOrGhost('player')
	end,
	combat = function()
		return InCombatLockdown() or UnitAffectingCombat('player')
	end,
	vehicle = function()
		return UnitInVehicle('player')
	end,
	override = function()
		return HasOverrideActionBar()
	end,
	flying = function()
		if not IsFlying() then return false end

		local form = GetShapeshiftFormID()
		if form == 27 or form == 3 then return false end
		return true
	end,
	mounted = function()
		if IsMounted() then return true end
		local form = GetShapeshiftFormID()
		return form == 27 or form == 3
	end,
	inInstance = function()
		local inInstance, instanceType = IsInInstance()
		return inInstance and (instanceType == 'party' or instanceType == 'raid'
			or instanceType == 'arena' or instanceType == 'pvp')
	end,
}
Visibility.CONDITIONS = CONDITIONS

local FALLBACKS = {
	petBattle = 0, dead = 50, combat = 100, vehicle = 100,
	override = 0, flying = 30, mounted = 100, inInstance = 100,
}

local DEFAULT_PRIORITY = {'petBattle', 'dead', 'combat', 'vehicle', 'override', 'flying', 'mounted', 'inInstance'}
Visibility.DEFAULT_PRIORITY = DEFAULT_PRIORITY

local function GetPriority()
	local db = BUI.GetDB()
	return db and db.general.visibilityPriority or DEFAULT_PRIORITY
end

local cachedKey   = nil
local cacheDirty  = true

local function RefreshCache()
	if not cacheDirty then return end
	cacheDirty = false
	cachedKey  = nil
	local order = GetPriority()
	for orderIndex = 1, #order do
		local key = order[orderIndex]
		local check = CONDITIONS[key]
		if check and check() then
			cachedKey = key
			return
		end
	end
end

local function IsModuleDisabled(moduleKey)
	if not moduleKey then return false end
	local db = BUI.GetDB()
	local disabledModules = db and db.general.visibilityModulesDisabled
	return disabledModules and disabledModules[moduleKey] == true
end

local currentKey = nil


function Visibility.GetContextualOpacity(moduleKey)
	local key = moduleKey or currentKey
	if IsModuleDisabled(key) then return 100 end
	local opacity = BUI.GetDB().general.visibilityOpacity
	RefreshCache()
	if cachedKey then
		return opacity[cachedKey]
	end
	return opacity.outOfCombat
end

local modules = {}
local keys    = {}
local count   = 0
local lastAppliedKey = false
local lastModuleOpacity = {}
local pureOpacity = {}

function Visibility.Register(key, updateCallback, pure)
	if modules[key] then return end
	modules[key] = updateCallback
	pureOpacity[key] = pure or nil
	count        = count + 1
	keys[count]  = key
	if lastAppliedKey ~= false then
		currentKey = key
		lastModuleOpacity[key] = Visibility.GetContextualOpacity(key)
		updateCallback(true)
		currentKey = nil
	end
end

function Visibility.Unregister(key)
	if not modules[key] then return end
	modules[key] = nil
	lastModuleOpacity[key] = nil
	pureOpacity[key] = nil
	local newCount = 0
	for keyIndex = 1, count do
		if modules[keys[keyIndex]] then
			newCount       = newCount + 1
			keys[newCount] = keys[keyIndex]
		end
	end
	count = newCount
end

local function ApplyUpdate(instant)
	cacheDirty = true
	RefreshCache()
	if not instant and cachedKey == lastAppliedKey then return end
	lastAppliedKey = cachedKey
	for keyIndex = 1, count do
		local moduleKey = keys[keyIndex]
		local callback = modules[moduleKey]
		if callback then
			local opacity = Visibility.GetContextualOpacity(moduleKey)
			if instant or not pureOpacity[moduleKey] or lastModuleOpacity[moduleKey] ~= opacity then
				currentKey = moduleKey
				if xpcall(callback, geterrorhandler(), instant) then
					lastModuleOpacity[moduleKey] = opacity
				end
			end
		end
	end
	currentKey = nil
end

local pendingInstant = false
local Dispatch = BUI.Dispatcher.New(function()
	local instant = pendingInstant
	pendingInstant = false
	ApplyUpdate(instant)
end, 'Visibility')

function Visibility.Update(instant)
	if instant then pendingInstant = true end
	Dispatch()
end

function Visibility.GetRegisteredKeys()
	local list = {}
	for keyIndex = 1, count do list[keyIndex] = keys[keyIndex] end
	return list
end

local forceInstant = false

local EVENTS = {
	'PLAYER_REGEN_ENABLED', 'PLAYER_REGEN_DISABLED', 'PLAYER_ENTERING_WORLD',
	'PLAYER_MOUNT_DISPLAY_CHANGED', 'UPDATE_SHAPESHIFT_FORM', 'PLAYER_IS_GLIDING_CHANGED',
	'PET_BATTLE_OPENING_START', 'PET_BATTLE_CLOSE',
	'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST',
	'ZONE_CHANGED_NEW_AREA', 'UPDATE_OVERRIDE_ACTIONBAR',
	'PLAYER_CONTROL_GAINED', 'PLAYER_CONTROL_LOST',
}

local flyStateFrame

local function FlyingMatters()
	if count == 0 then return false end
	local db = BUI.GetDB()
	local opacity = db and db.general.visibilityOpacity
	local fly = opacity and opacity.flying or FALLBACKS.flying
	local mount = opacity and opacity.mounted or FALLBACKS.mounted
	return fly ~= mount
end

local function EnsureFlyStateDriver()
	if flyStateFrame then return end
	if not FlyingMatters() then return end
	if InCombatLockdown() then return end
	flyStateFrame = CreateFrame('Frame', 'BUI_FlyStateDriver')
	SetScript(flyStateFrame, 'OnAttributeChanged', function(_, attributeName)
		if attributeName == 'state-buiflying' then Visibility.Update() end
	end)
	RegisterStateDriver(flyStateFrame, 'buiflying', '[flying] fly; [mounted] mounted; ground')
end

local function OnVisibilityEvent(event)
	if event == 'PLAYER_ENTERING_WORLD' then
		forceInstant = true
		BUI.Prof.After('Util.Visibility', 1, function() forceInstant = false end)
	end

	Visibility.Update(forceInstant or event == 'PLAYER_ENTERING_WORLD')

	if event == 'PLAYER_MOUNT_DISPLAY_CHANGED' or event == 'PLAYER_CONTROL_GAINED' or event == 'PLAYER_ENTERING_WORLD' then
		EnsureFlyStateDriver()
	end
end

for _, event in ipairs(EVENTS) do
	BUI.Events:Register(event, 'Visibility', OnVisibilityEvent)
end

BUI.Events:RegisterUnit('UNIT_ENTERED_VEHICLE', 'player', 'Visibility', OnVisibilityEvent)
BUI.Events:RegisterUnit('UNIT_EXITED_VEHICLE', 'player', 'Visibility', OnVisibilityEvent)
