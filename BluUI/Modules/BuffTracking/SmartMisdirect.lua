local _, BUI = ...

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsInRaid = IsInRaid
local IsInInstance = IsInInstance
local IsMounted = IsMounted
local GetNumGroupMembers = GetNumGroupMembers
local UnitExists = UnitExists
local UnitIsDead = UnitIsDead
local UnitIsFriend = UnitIsFriend
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitIsVisible = UnitIsVisible
local UnitName = UnitName
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local GetPartyAssignment = GetPartyAssignment
local strcmputf8i = strcmputf8i
local format = string.format

local Tools = BUI.Tools

local SmartMisdirect = {}
BUI.BuffTracking.SmartMisdirect = SmartMisdirect

local MISDIRECTION_SPELL = 34477
local BUTTON_NAME = 'BUI_SmartMisdirect'
local MACRO_NAME = 'BluUI Misdirect'
local MACRO_BODY = '#showtooltip Misdirection\n/click ' .. BUTTON_NAME .. ' LeftButton'

local TANK_ROLE_ONLY = 'roleOnly'
local TANK_ROLE_OR_MAIN = 'roleOrMain'
local TANK_MAIN_THEN_ROLE = 'mainThenRole'
local TANK_MAIN_ONLY = 'mainOnly'

SmartMisdirect.TANK_METHOD_ITEMS = {
	{ value = TANK_ROLE_ONLY,      text = 'Assigned Tank Role'   },
	{ value = TANK_ROLE_OR_MAIN,   text = 'Role Or Main Tank'    },
	{ value = TANK_MAIN_THEN_ROLE, text = 'Main Tank, Then Role' },
	{ value = TANK_MAIN_ONLY,      text = 'Main Tank Only'       },
}

local ALERT_KEY = 'misdirectAlert'
local ALERT_FRAME = 'BUI_MisdirectAlert'
local FADE_IN_SECONDS = 0.25
local FADE_OUT_SECONDS = 0.6

local RAID_UNITS, PARTY_UNITS = {}, {}
for memberIndex = 1, MAX_RAID_MEMBERS do RAID_UNITS[memberIndex] = 'raid' .. memberIndex end
for memberIndex = 1, MAX_PARTY_MEMBERS do PARTY_UNITS[memberIndex] = 'party' .. memberIndex end

local playerIsHunter = select(2, UnitClass('player')) == 'HUNTER'

local button
local currentLabel
local wasMounted = false
local alertTracker
local flashShowing = false
local flashToken = 0

local function Settings()
	return BUI.GetDB().smartMisdirect
end

local function AlertSettings()
	return BUI.GetDB().misdirectAlert
end

local function FindGroupUnit(test, argumentA, argumentB)
	local units, lastIndex
	if IsInRaid() then
		units, lastIndex = RAID_UNITS, GetNumGroupMembers()
	else
		units, lastIndex = PARTY_UNITS, GetNumGroupMembers() - 1
	end
	for memberIndex = 1, lastIndex do
		local unit = units[memberIndex]
		if UnitExists(unit) and test(unit, argumentA, argumentB) then return unit end
	end
end

local function SafeName(unit)
	local name, realm = UnitName(unit)
	if Tools.IsSecretValue(name) or type(name) ~= 'string' or name == '' then return nil end
	if Tools.IsSecretValue(realm) or type(realm) ~= 'string' then realm = nil end
	return name, realm
end

local function IsCandidate(unit)
	return UnitIsVisible(unit) and not UnitIsUnit(unit, 'player')
end

local function IsRoleTank(unit)
	if not IsCandidate(unit) then return false end
	local role = UnitGroupRolesAssigned(unit)
	return not Tools.IsSecretValue(role) and role == 'TANK'
end

local function IsMainTank(unit)
	return IsCandidate(unit) and GetPartyAssignment('MAINTANK', unit, true)
end

local function IsEitherTank(unit)
	return IsMainTank(unit) or IsRoleTank(unit)
end

local function TankUnit(method)
	if method == TANK_MAIN_ONLY then return FindGroupUnit(IsMainTank) end
	if method == TANK_MAIN_THEN_ROLE then return FindGroupUnit(IsMainTank) or FindGroupUnit(IsRoleTank) end
	if method == TANK_ROLE_OR_MAIN then return FindGroupUnit(IsEitherTank) end
	return FindGroupUnit(IsRoleTank)
end

local function MatchesPinnedName(unit, wantedName, wantedRealm)
	if not IsCandidate(unit) then return false end
	local name, realm = SafeName(unit)
	if not name or strcmputf8i(name, wantedName) ~= 0 then return false end
	if not wantedRealm then return true end
	return realm ~= nil and strcmputf8i(realm, wantedRealm) == 0
end

local function OverrideUnit(settings)
	local wantedName = settings.overrideName
	if wantedName == '' then return nil end
	local wantedRealm = settings.overrideRealm
	if wantedRealm == '' then wantedRealm = nil end
	return FindGroupUnit(MatchesPinnedName, wantedName, wantedRealm)
end

local function ResolveTarget()
	local settings = Settings()
	if not settings.enabled then return nil end
	local override = OverrideUnit(settings)
	if override then return override end
	if settings.useFocus and UnitExists('focus') and UnitIsFriend('player', 'focus') and not UnitIsUnit('focus', 'player') then
		return 'focus'
	end
	if settings.preferTank then
		local tank = TankUnit(settings.tankMethod)
		if tank then return tank end
	end
	if settings.fallbackPet and UnitExists('pet') and not UnitIsDead('pet') then return 'pet' end
end

local function TargetLabel(unit)
	if not unit then return nil end
	if unit == 'pet' then return SafeName('pet') or 'Pet' end
	return SafeName(unit)
end

local function TargetColor(unit)
	if unit == 'pet' then return 1, 1, 1 end
	local red, green, blue = Tools.GetUnitClassColor(unit)
	if not red then return 1, 1, 1 end
	return red, green, blue
end

local function AlertStacks()
	if not currentLabel then return 0 end
	if flashShowing or AlertSettings().alertMode ~= 'flash' then return 1 end
	return 0
end

local function AlertText(settings)
	if not currentLabel then return nil end
	local prefix = settings.customText
	if prefix ~= '' then return prefix .. ' ' .. currentLabel end
	return currentLabel
end

function SmartMisdirect.Create()
	if not playerIsHunter then return nil end
	local Display = BUI.BuffTracking.Display
	alertTracker = Display.CreateTracker({
		settingsKey   = ALERT_KEY,
		frameName     = ALERT_FRAME,
		getStacks     = AlertStacks,
		getCustomText = AlertText,
		isActive      = Display.AlwaysActive,
		maxStacks     = 1,
		textOnly      = true,
	})
	return alertTracker
end

local function RefreshAlert(shouldFlash)
	if not alertTracker then return end
	local settings = AlertSettings()
	if not shouldFlash or not currentLabel or not settings.enabled or settings.alertMode ~= 'flash' then
		alertTracker.Update()
		return
	end

	flashToken = flashToken + 1
	local token = flashToken
	flashShowing = true
	alertTracker.Update()

	local frame = alertTracker.frame
	UIFrameFadeRemoveFrame(frame)
	frame:SetAlpha(0)
	UIFrameFadeIn(frame, FADE_IN_SECONDS, 0, 1)

	local holdSeconds = settings.flashSeconds
	C_Timer.After(holdSeconds, function()
		if flashToken ~= token then return end
		UIFrameFadeOut(frame, FADE_OUT_SECONDS, frame:GetAlpha(), 0)
	end)
	C_Timer.After(holdSeconds + FADE_OUT_SECONDS, function()
		if flashToken ~= token then return end
		UIFrameFadeRemoveFrame(frame)
		flashShowing = false
		alertTracker.Update()
		frame:SetAlpha(1)
	end)
end

local function Announce(unit)
	local mounted = IsMounted()
	local suppressed = mounted or wasMounted
	wasMounted = mounted

	local name = TargetLabel(unit)
	if name == currentLabel then return end
	currentLabel = name
	if alertTracker then alertTracker.MarkDirty() end

	local _, instanceType = IsInInstance()
	if instanceType == 'pvp' or instanceType == 'arena' then suppressed = true end
	RefreshAlert(not suppressed and AlertSettings().flashOnTargetChange)
	if suppressed or not Settings().enabled then return end
	if not name then
		BUI.Print('Misdirect: no valid target.')
		return
	end
	BUI.Print(format('Misdirect: |cff%s%s|r', BUI.Hex(TargetColor(unit)), name))
end

local function ApplyTarget()
	if not button then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(ApplyTarget, 'SmartMisdirect.Apply')
		return
	end

	local unit = ResolveTarget()
	if unit then
		button:SetAttribute('type', 'spell')
		button:SetAttribute('typerelease', 'spell')
		button:SetAttribute('unit', unit)
	else
		button:SetAttribute('type', nil)
		button:SetAttribute('typerelease', nil)
		button:SetAttribute('unit', nil)
	end
	Announce(unit)
end

local DispatchApply = BUI.Dispatcher.New(ApplyTarget, 'SmartMisdirect.Apply')
local DispatchApplySoon = BUI.Dispatcher.NewDelayed(ApplyTarget, 2)
local DispatchApplyLate = BUI.Dispatcher.NewDelayed(ApplyTarget, 5)

local function DispatchApplyStaggered()
	DispatchApply()
	DispatchApplySoon()
	DispatchApplyLate()
end

SmartMisdirect.Refresh = DispatchApply

local function SetPinnedName(name, realm)
	local settings = Settings()
	settings.overrideName = name
	settings.overrideRealm = realm
	DispatchApply()
end

local function ClearPinnedName()
	SetPinnedName('', '')
end

function SmartMisdirect.CreateMacro()
	if InCombatLockdown() then
		BUI.Print('Leave combat before creating the macro.')
		return
	end
	local icon = C_Spell.GetSpellTexture(MISDIRECTION_SPELL)
	local index = GetMacroIndexByName(MACRO_NAME)
	if index > 0 then
		EditMacro(index, MACRO_NAME, icon, MACRO_BODY)
	else
		if GetNumMacros() >= MAX_ACCOUNT_MACROS then
			BUI.Print('No free account macro slots. Delete one and try again.')
			return
		end
		index = CreateMacro(MACRO_NAME, icon, MACRO_BODY, false)
	end
	if not index or index <= 0 then
		BUI.Print('Could not create the Misdirection macro.')
		return
	end
	BUI.Print('Macro "' .. MACRO_NAME .. '" is on your cursor, drop it on an action bar.')
	PickupMacro(index)
end

local function AddMenuEntry(_, rootDescription, contextData)
	local settings = Settings()
	if not settings.enabled then return end
	local unit = contextData and contextData.unit
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, 'player') then return end
	local groupUnit = FindGroupUnit(UnitIsUnit, unit)
	if not groupUnit then return end
	local name, realm = SafeName(groupUnit)
	if not name then return end

	rootDescription:CreateDivider()
	rootDescription:CreateTitle('Misdirection')
	local pinnedUnit = OverrideUnit(settings)
	if pinnedUnit and UnitIsUnit(pinnedUnit, groupUnit) then
		rootDescription:CreateButton('Remove ' .. name .. ' as override', ClearPinnedName)
		return
	end
	rootDescription:CreateButton('Set ' .. name .. ' as override', function()
		SetPinnedName(name, realm or '')
	end)
	if settings.overrideName ~= '' then
		rootDescription:CreateButton('Remove override (' .. settings.overrideName .. ')', ClearPinnedName)
	end
end

local function OnSpellCast(_, _, _, spellID)
	if spellID ~= MISDIRECTION_SPELL then return end
	if Settings().enabled and AlertSettings().flashOnCast then RefreshAlert(true) end
end

function SmartMisdirect.Setup()
	button = CreateFrame('Button', BUTTON_NAME, UIParent, 'SecureActionButtonTemplate')
	button:SetAttribute('spell', MISDIRECTION_SPELL)
	button:SetAttribute('pressAndHoldAction', '1')
	button:RegisterForClicks('LeftButtonDown', 'LeftButtonUp')
	button:SetSize(1, 1)
	button:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -500, 500)
	button:SetAlpha(0)
	button:EnableMouse(false)
	button:Show()

	Menu.ModifyMenu('MENU_UNIT_PARTY', AddMenuEntry)
	Menu.ModifyMenu('MENU_UNIT_RAID_PLAYER', AddMenuEntry)
	Menu.ModifyMenu('MENU_UNIT_FOCUS', AddMenuEntry)
	Menu.ModifyMenu('MENU_UNIT_TARGET', AddMenuEntry)

	BUI.Events:Register('GROUP_ROSTER_UPDATE', 'SmartMisdirect', DispatchApply)
	BUI.Events:Register('PLAYER_ROLES_ASSIGNED', 'SmartMisdirect', DispatchApply)
	BUI.Events:Register('PLAYER_FOCUS_CHANGED', 'SmartMisdirect', DispatchApply)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'SmartMisdirect', DispatchApplyStaggered)
	BUI.Events:RegisterUnit('UNIT_PET', 'player', 'SmartMisdirect', DispatchApply)
	BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED', 'player', 'SmartMisdirect', OnSpellCast)

	DispatchApplyStaggered()
end

BINDING_HEADER_BLUUI = 'BluUI'
_G['BINDING_NAME_CLICK ' .. BUTTON_NAME .. ':LeftButton'] = 'Smart Misdirection'

if playerIsHunter then
	BUI.Events:OnLogin('SmartMisdirect', SmartMisdirect.Setup, 'buffTracking')
end
