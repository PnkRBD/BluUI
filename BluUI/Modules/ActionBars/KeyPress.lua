local _, BUI = ...

local ActionBars = BUI.ActionBars

local wipe, pairs, ipairs, next = wipe, pairs, ipairs, next
local GetBindingKey = GetBindingKey
local GetCurrentKeyBoardFocus = GetCurrentKeyBoardFocus
local GetTime = GetTime
local IsKeyDown = IsKeyDown
local IsMouseButtonDown = IsMouseButtonDown
local IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown = IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown
local InCombatLockdown = InCombatLockdown

local bindingsByKey = {}
local heldKeys = {}
local pressedButtons = {}
local pressedNow = {}
local listener
local running = false
local built = false

local MIN_VISIBLE = 0.05

local MOUSE_KEY = {
	LeftButton = 'BUTTON1', RightButton = 'BUTTON2', MiddleButton = 'BUTTON3',
	Button4 = 'BUTTON4', Button5 = 'BUTTON5',
}

local MOUSE_BUTTON_INDEX = { BUTTON1 = 1, BUTTON2 = 2, BUTTON3 = 3, BUTTON4 = 4, BUTTON5 = 5 }

local function GetModifierMask()
	return (IsShiftKeyDown() and 1 or 0)
		+ (IsControlKeyDown() and 2 or 0)
		+ (IsAltKeyDown() and 4 or 0)
end

local function ParseBinding(rawBinding)
	if not rawBinding or rawBinding == '' then return nil, 0 end
	local modifierMask = 0
	local remaining = rawBinding
	while true do
		if remaining:sub(1, 6) == 'SHIFT-' then
			modifierMask = modifierMask + 1; remaining = remaining:sub(7)
		elseif remaining:sub(1, 5) == 'CTRL-' then
			modifierMask = modifierMask + 2; remaining = remaining:sub(6)
		elseif remaining:sub(1, 4) == 'ALT-' then
			modifierMask = modifierMask + 4; remaining = remaining:sub(5)
		else
			break
		end
	end
	if remaining == '' then return nil, 0 end
	return remaining, modifierMask
end

local function AddBinding(rawBinding, button)
	local keyName, modifierMask = ParseBinding(rawBinding)
	if not keyName then return end
	local entries = bindingsByKey[keyName]
	if not entries then
		entries = {}
		bindingsByKey[keyName] = entries
	end
	entries[#entries + 1] = modifierMask
	entries[#entries + 1] = button
end

local function RebuildBindings()
	for _, entries in pairs(bindingsByKey) do wipe(entries) end
	wipe(bindingsByKey)
	for _, bar in pairs(ActionBars.bars) do
		local command = bar.command
		for buttonIndex, button in ipairs(bar.buttons) do
			if command then
				local firstKey, secondKey = GetBindingKey(command .. buttonIndex)
				if firstKey then AddBinding(firstKey, button) end
				if secondKey then AddBinding(secondKey, button) end
			end
		end
	end
	built = true
end

local function RefreshPressed()
	local currentMask = GetModifierMask()
	wipe(pressedNow)
	for keyName in pairs(heldKeys) do
		local entries = bindingsByKey[keyName]
		if entries then
			for entryIndex = 1, #entries, 2 do
				if entries[entryIndex] == currentMask then
					pressedNow[entries[entryIndex + 1]] = true
				end
			end
		end
	end
	for button in pairs(pressedButtons) do
		if not pressedNow[button] then
			pressedButtons[button] = nil
			button:SetButtonState('NORMAL')
		end
	end
	for button in pairs(pressedNow) do
		if not pressedButtons[button] and button:IsVisible() then
			pressedButtons[button] = true
			button:SetButtonState('PUSHED')
		end
	end
end

local function ReleaseAll()
	wipe(heldKeys)
	for button in pairs(pressedButtons) do
		pressedButtons[button] = nil
		button:SetButtonState('NORMAL')
	end
end

local pollFrame = CreateFrame('Frame')
pollFrame:Hide()

local function VerifyHeld()
	local now = GetTime()
	for keyName, pressedAt in pairs(heldKeys) do
		if now - pressedAt >= MIN_VISIBLE then
			local mouseIndex = MOUSE_BUTTON_INDEX[keyName]
			local isDown = mouseIndex and IsMouseButtonDown(mouseIndex) or (not mouseIndex and IsKeyDown(keyName))
			if not isDown then heldKeys[keyName] = nil end
		end
	end
	RefreshPressed()
	if not next(heldKeys) then pollFrame:Hide() end
end

pollFrame:SetScript('OnUpdate', VerifyHeld)

local function OnInputDown(keyName)
	if not running then return end
	if GetCurrentKeyBoardFocus() then return end
	if not built then RebuildBindings() end
	if not bindingsByKey[keyName] then return end
	heldKeys[keyName] = GetTime()
	RefreshPressed()
	pollFrame:Show()
end

local function OnInputUp(keyName)
	local pressedAt = heldKeys[keyName]
	if not pressedAt then return end
	if GetTime() - pressedAt < MIN_VISIBLE then return end
	heldKeys[keyName] = nil
	RefreshPressed()
end

local function StartListener()
	if not listener then
		if InCombatLockdown() then
			BUI.Events:AfterCombat(function()
				if running then StartListener() end
			end, 'ActionBars.KeyPress.Listener')
			return
		end
		listener = CreateFrame('Frame', nil, UIParent)
		listener:EnableKeyboard(true)
		listener:SetPropagateKeyboardInput(true)
		listener:SetScript('OnKeyDown', function(_, key) OnInputDown(key) end)
		listener:SetScript('OnKeyUp', function(_, key) OnInputUp(key) end)
	end
	listener:Show()
	BUI.Events:Register('GLOBAL_MOUSE_DOWN', 'ActionBars.KeyPress', function(_, mouseButton)
		local keyName = MOUSE_KEY[mouseButton]
		if keyName then OnInputDown(keyName) end
	end)
	BUI.Events:Register('GLOBAL_MOUSE_UP', 'ActionBars.KeyPress', function(_, mouseButton)
		local keyName = MOUSE_KEY[mouseButton]
		if keyName then OnInputUp(keyName) end
	end)
	BUI.Events:Register('MODIFIER_STATE_CHANGED', 'ActionBars.KeyPress', function()
		if next(heldKeys) then RefreshPressed() end
	end)
end

local function StopListener()
	if listener then listener:Hide() end
	BUI.Events:Unregister('GLOBAL_MOUSE_DOWN', 'ActionBars.KeyPress')
	BUI.Events:Unregister('GLOBAL_MOUSE_UP', 'ActionBars.KeyPress')
	BUI.Events:Unregister('MODIFIER_STATE_CHANGED', 'ActionBars.KeyPress')
	pollFrame:Hide()
	ReleaseAll()
end

function ActionBars.RefreshKeyPress()
	local enable = BUI.IsModuleEnabled('actionBars') and ActionBars.GetSettings().showKeyPresses
	if enable and not running then
		running = true
		StartListener()
	elseif not enable and running then
		running = false
		StopListener()
	end
	built = false
end

BUI.Events:Register('UPDATE_BINDINGS', 'ActionBars.KeyPress.Bindings', function()
	built = false
end)

BUI.Events:Register('PLAYER_DEAD', 'ActionBars.KeyPress.Dead', function()
	if running then ReleaseAll(); pollFrame:Hide() end
end)
