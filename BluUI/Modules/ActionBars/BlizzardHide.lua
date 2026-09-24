local _, BUI = ...

local ActionBars = BUI.ActionBars
local ipairs = ipairs

local BLIZZARD_BAR_FOR_INDEX = {
	'MainActionBar', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft',
	'MultiBar5', 'MultiBar6', 'MultiBar7',
}
local MAIN_BAR_COMPANIONS = { 'PossessActionBar', 'OverrideActionBar' }
local BUTTON_PREFIXES = {
	MainActionBar = 'ActionButton',
	MultiBarBottomLeft = 'MultiBarBottomLeftButton',
	MultiBarBottomRight = 'MultiBarBottomRightButton',
	MultiBarRight = 'MultiBarRightButton',
	MultiBarLeft = 'MultiBarLeftButton',
	MultiBar5 = 'MultiBar5Button',
	MultiBar6 = 'MultiBar6Button',
	MultiBar7 = 'MultiBar7Button',
}
local CONTROLLER_BAR_EVENTS = {
	'PLAYER_ENTERING_WORLD', 'UPDATE_BONUS_ACTIONBAR', 'UPDATE_VEHICLE_ACTIONBAR', 'UPDATE_OVERRIDE_ACTIONBAR',
	'ACTIONBAR_PAGE_CHANGED', 'PET_BATTLE_CLOSE', 'PET_BATTLE_OPENING_START', 'UNIT_DISPLAYPOWER',
}
local CONTROLLER_STANCE_EVENTS = { 'UPDATE_SHAPESHIFT_FORM', 'UPDATE_SHAPESHIFT_FORMS', 'UPDATE_SHAPESHIFT_USABLE' }
local CONTROLLER_POSSESS_EVENT = 'UPDATE_POSSESS_BAR'

local hider
local suppressed = setmetatable({}, { __mode = 'k' })

local function Hider()
	if not hider then
		hider = CreateFrame('Frame', 'BUI_ActionBarHider', UIParent)
		hider:Hide()
	end
	return hider
end

local function FrameKey(frame)
	return frame:GetName() or tostring(frame)
end

local function HideFrame(frame)
	if frame.HideBase then frame:HideBase() else frame:Hide() end
end

local function Rehide(frame)
	if InCombatLockdown() then
		ActionBars.RunSecure('Rehide.' .. FrameKey(frame), function() HideFrame(frame) end)
	else
		HideFrame(frame)
	end
end

local function SnapParent(frame, parent)
	if not hider or parent == hider then return end
	if InCombatLockdown() then
		ActionBars.RunSecure('Reparent.' .. FrameKey(frame), function() frame:SetParent(hider) end)
	else
		frame:SetParent(hider)
	end
end

local function Suppress(frame)
	if not frame or suppressed[frame] then return end
	if InCombatLockdown() then
		ActionBars.RunSecure('Suppress.' .. FrameKey(frame), function() Suppress(frame) end)
		return
	end
	suppressed[frame] = true
	frame:UnregisterAllEvents()
	frame:SetParent(Hider())
	frame:HookScript('OnShow', Rehide)
	hooksecurefunc(frame, 'SetParent', SnapParent)
	HideFrame(frame)
end

local function SuppressButtons(barName)
	local prefix = BUTTON_PREFIXES[barName]
	if not prefix then return end
	for index = 1, ActionBars.BUTTONS_PER_PAGE do
		local button = _G[prefix .. index]
		if button then
			button:UnregisterAllEvents()
			button:SetAttribute('statehidden', true)
		end
	end
end

local function DropControllerEvents(events)
	local controller = _G.ActionBarController
	if not controller then return end
	for _, event in ipairs(events) do controller:UnregisterEvent(event) end
end

local function AllBarsSuppressed()
	for _, name in ipairs(BLIZZARD_BAR_FOR_INDEX) do
		local frame = _G[name]
		if frame and not suppressed[frame] then return false end
	end
	return true
end

local function DetachController()
	if InCombatLockdown() then
		ActionBars.RunSecure('DetachController', DetachController)
		return
	end
	if AllBarsSuppressed() then DropControllerEvents(CONTROLLER_BAR_EVENTS) end
	if suppressed[_G.StanceBar] then
		DropControllerEvents(CONTROLLER_STANCE_EVENTS)
		if suppressed[_G.PossessActionBar] then DropControllerEvents({ CONTROLLER_POSSESS_EVENT }) end
	end
end

function ActionBars.HideBlizzardBars()
	if InCombatLockdown() then
		ActionBars.RunSecure('HideBars', ActionBars.HideBlizzardBars)
		return
	end
	for barIndex, name in ipairs(BLIZZARD_BAR_FOR_INDEX) do
		local barSettings = ActionBars.GetBarSettings(barIndex)
		if barSettings and barSettings.enabled then
			local frame = _G[name]
			if frame then
				Suppress(frame)
				SuppressButtons(name)
			end
			if barIndex == 1 then
				for _, companion in ipairs(MAIN_BAR_COMPANIONS) do
					Suppress(_G[companion])
				end
			end
		end
	end
	DetachController()
end

function ActionBars.HideBlizzardPetBar()
	Suppress(PetActionBar)
end

function ActionBars.HideBlizzardStanceBar()
	Suppress(StanceBar)
	DetachController()
end

function ActionBars.HideBlizzardVehicleButton()
	Suppress(MainMenuBarVehicleLeaveButton)
end
