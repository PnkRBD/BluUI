local _, BUI = ...

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel
local BUILib = BUI.BUILibClient
local Controls = BUILib.Controls
local Theme = BUILib.Theme

local EVENT_KEY = 'ActionBars.KeybindMode'
local BANNER_WIDTH = 520
local BANNER_HEIGHT = 58
local BANNER_TOP = -120
local IGNORED_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true,
}
local MOUSE_KEYS = { MiddleButton = 'BUTTON3', Button4 = 'BUTTON4', Button5 = 'BUTTON5' }
local HINT_TEXT = 'Hover a button and press a key or mouse button.  Escape clears the hovered button.  Escape with nothing hovered exits.'

local state = { active = false, hovered = nil, hooked = {} }
local capture, banner, highlight, bannerText, hoverText

local function ButtonCommand(button)
	return button.config and button.config.keyBoundTarget
end

local function BoundKeysText(command)
	local first, second = GetBindingKey(command)
	if not first then return 'not bound' end
	local text = BUI.Keybinds.Format(first) or first
	if second then text = text .. ', ' .. (BUI.Keybinds.Format(second) or second) end
	return text
end

local function ButtonLabel(button)
	local spellID = ActionBars.Plain(button.GetSpellId and button:GetSpellId())
	if spellID then
		local info = C_Spell.GetSpellInfo(spellID)
		if info and info.name then return info.name end
	end
	local command = ButtonCommand(button)
	return command and command:gsub('BUTTON', ' ') or 'button'
end

local function RefreshHoverText()
	if not hoverText then return end
	local button = state.hovered
	if not button then
		hoverText:SetText('Nothing hovered')
		return
	end
	local command = ButtonCommand(button)
	hoverText:SetText(ButtonLabel(button) .. '  ·  ' .. (command and BoundKeysText(command) or 'no binding slot'))
end

local function SetHovered(button)
	if not state.active then return end
	state.hovered = button
	if button then
		highlight:ClearAllPoints()
		highlight:SetAllPoints(button)
		highlight:Show()
	else
		highlight:Hide()
	end
	RefreshHoverText()
end

local function SaveBindingSet()
	SaveBindings(GetCurrentBindingSet())
end

local function Bind(button, chord)
	local command = ButtonCommand(button)
	if not command then return end
	if InCombatLockdown() then
		BUI.Print('Keybinds cannot change during combat.')
		return
	end
	if not SetBinding(chord, command) then
		BUI.Print('Could not bind ' .. chord .. '.')
		return
	end
	SaveBindingSet()
	BUI.Print((BUI.Keybinds.Format(chord) or chord) .. ' bound to ' .. ButtonLabel(button) .. '.')
	RefreshHoverText()
end

local function ClearBindings(button)
	local command = ButtonCommand(button)
	if not command or InCombatLockdown() then return end
	local first, second = GetBindingKey(command)
	if not first then return end
	SetBinding(first)
	if second then SetBinding(second) end
	SaveBindingSet()
	BUI.Print('Cleared keybinds on ' .. ButtonLabel(button) .. '.')
	RefreshHoverText()
end

local function OnKeyDown(_, key)
	if not state.active then return end
	if key == 'ESCAPE' then
		if state.hovered then
			ClearBindings(state.hovered)
		else
			ActionBars.SetKeybindMode(false)
		end
		return
	end
	if IGNORED_KEYS[key] or not state.hovered then return end
	Bind(state.hovered, CreateKeyChordString(key))
end

local function OnButtonMouseDown(button, mouseButton)
	if not state.active or state.hovered ~= button then return end
	local key = MOUSE_KEYS[mouseButton]
	if key then Bind(button, CreateKeyChordString(key)) end
end

local function OnButtonWheel(button, delta)
	if not state.active or state.hovered ~= button then return end
	Bind(button, CreateKeyChordString(delta > 0 and 'MOUSEWHEELUP' or 'MOUSEWHEELDOWN'))
end

local function HookButton(button)
	if state.hooked[button] then return end
	state.hooked[button] = true
	button:HookScript('OnEnter', function(self) SetHovered(self) end)
	button:HookScript('OnLeave', function(self)
		if state.hovered == self then SetHovered(nil) end
	end)
	button:HookScript('OnMouseDown', OnButtonMouseDown)
end

local function SetWheelCapture(enabled)
	ActionBars.ForEachButton(function(button)
		if not ButtonCommand(button) then return end
		if enabled then
			button:EnableMouseWheel(true)
			button:SetScript('OnMouseWheel', OnButtonWheel)
		else
			button:SetScript('OnMouseWheel', nil)
			button:EnableMouseWheel(false)
		end
	end)
end

local function EnsureFrames()
	if capture then return end
	capture = CreateFrame('Frame', 'BUI_KeybindCapture', UIParent)
	capture:SetSize(1, 1)
	capture:SetPoint('CENTER')
	capture:SetScript('OnKeyDown', OnKeyDown)
	capture:Hide()

	highlight = CreateFrame('Frame', nil, UIParent)
	highlight:SetFrameStrata('TOOLTIP')
	highlight:Hide()

	banner = CreateFrame('Frame', 'BUI_KeybindBanner', UIParent)
	banner:SetSize(BANNER_WIDTH, BANNER_HEIGHT)
	banner:SetPoint('TOP', UIParent, 'TOP', 0, BANNER_TOP)
	banner:SetFrameStrata('DIALOG')
	Pixel.SetTemplate(banner, 0.05, 0.05, 0.06, 0.95, 0.15, 0.15, 0.18, 1, 1)
	banner:Hide()

	bannerText = banner:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(bannerText, 11, BUI.C.FONT_PATH, 'OUTLINE')
	bannerText:SetPoint('TOPLEFT', 12, -9)
	bannerText:SetPoint('TOPRIGHT', -90, -9)
	bannerText:SetJustifyH('LEFT')
	bannerText:SetWordWrap(true)
	bannerText:SetText(HINT_TEXT)
	bannerText:SetTextColor(0.85, 0.85, 0.88, 1)

	hoverText = banner:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(hoverText, 12, BUI.C.FONT_PATH, 'OUTLINE')
	hoverText:SetPoint('BOTTOMLEFT', 12, 9)
	hoverText:SetPoint('BOTTOMRIGHT', -90, 9)
	hoverText:SetJustifyH('LEFT')
	hoverText:SetTextColor(1, 1, 1, 1)

	local done = Controls.Button(banner, 'Done', 70, function() ActionBars.SetKeybindMode(false) end)
	local doneFrame = done.frame or done
	doneFrame:SetPoint('RIGHT', banner, 'RIGHT', -10, 0)
end

local function PaintHighlight()
	local red, green, blue = Theme.GetAccent()
	Pixel.ApplyBorder(highlight, 2, red, green, blue, 1)
end

function ActionBars.KeybindModeActive()
	return state.active
end

function ActionBars.SetKeybindMode(active)
	active = active and true or false
	if state.active == active then return end
	if active and (InCombatLockdown() or not BUI.IsModuleEnabled('actionBars')) then
		BUI.Print('Keybind mode needs the Action Bars module enabled and no combat.')
		return
	end
	EnsureFrames()
	state.active = active
	state.hovered = nil
	ActionBars.SetClickThroughSuspended(active)
	if active then
		ActionBars.ForEachButton(function(button)
			if ButtonCommand(button) then HookButton(button) end
		end)
		SetWheelCapture(true)
		PaintHighlight()
		capture:EnableKeyboard(true)
		capture:SetPropagateKeyboardInput(false)
		capture:Show()
		banner:Show()
		RefreshHoverText()
	else
		SetWheelCapture(false)
		capture:SetPropagateKeyboardInput(true)
		capture:EnableKeyboard(false)
		capture:Hide()
		banner:Hide()
		highlight:Hide()
	end
	ActionBars.RefreshFade()
end

function ActionBars.ToggleKeybindMode()
	ActionBars.SetKeybindMode(not state.active)
end

BUI.Events:Register('PLAYER_REGEN_DISABLED', EVENT_KEY, function()
	if state.active then ActionBars.SetKeybindMode(false) end
end)
