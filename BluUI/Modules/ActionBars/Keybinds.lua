local _, BUI = ...

local ActionBars = BUI.ActionBars

local EVENT_KEY = 'ActionBars.Keybinds'

local owner

local function Owner()
	if not owner then
		owner = CreateFrame('Frame', 'BUI_ActionBarBindings', UIParent)
	end
	return owner
end

function ActionBars.RouteKeybinds()
	local frame = Owner()
	ClearOverrideBindings(frame)
	if not BUI.IsModuleEnabled('actionBars') then return end
	for _, bar in pairs(ActionBars.bars) do
		local barSettings = ActionBars.GetBarSettings(bar.key)
		if bar.command and barSettings and barSettings.enabled then
			for index, button in ipairs(bar.buttons) do
				local buttonName = button:GetName()
				local firstKey, secondKey = GetBindingKey(bar.command .. index)
				if firstKey then SetOverrideBindingClick(frame, false, firstKey, buttonName, bar.clickButton) end
				if secondKey then SetOverrideBindingClick(frame, false, secondKey, buttonName, bar.clickButton) end
			end
		end
	end
end

BUI.Events:Register('UPDATE_BINDINGS', EVENT_KEY, function()
	ActionBars.RunSecure('Keybinds', ActionBars.RouteKeybinds)
end)
