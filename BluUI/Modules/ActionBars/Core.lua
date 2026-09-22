local _, BUI = ...

local ActionBars = {}
BUI.ActionBars = ActionBars

ActionBars.BAR_COUNT = 8
ActionBars.BUTTONS_PER_PAGE = 12
ActionBars.PAGE_COUNT = 18
ActionBars.PET_BUTTON_COUNT = 10
ActionBars.STANCE_BUTTON_COUNT = 10

ActionBars.PAGE_FOR_BAR = { 1, 6, 5, 3, 4, 13, 14, 15 }

ActionBars.COMMAND_FOR_BAR = {
	'ACTIONBUTTON',
	'MULTIACTIONBAR1BUTTON',
	'MULTIACTIONBAR2BUTTON',
	'MULTIACTIONBAR3BUTTON',
	'MULTIACTIONBAR4BUTTON',
	'MULTIACTIONBAR5BUTTON',
	'MULTIACTIONBAR6BUTTON',
	'MULTIACTIONBAR7BUTTON',
}

ActionBars.SETTINGS_KEY = {
	pet = 'petBar',
	stance = 'stanceBar',
	vehicle = 'vehicleBar',
	micro = 'microBar',
	bags = 'bagBar',
	extra = 'extraBar',
}

ActionBars.LABELS = {
	pet = 'Pet Bar',
	stance = 'Stance Bar',
	vehicle = 'Vehicle Exit',
	micro = 'Micro Menu',
	bags = 'Bag Bar',
	extra = 'Extra Action',
}

ActionBars.bars = {}
ActionBars.hooksecurefunc = BUI.Prof.MakeHooker('actionbars')

function ActionBars.GetSettings()
	local db = BUI.GetDB()
	return db and db.actionBars
end

function ActionBars.GetBarSettings(key)
	local settings = ActionBars.GetSettings()
	if not settings then return nil end
	if type(key) == 'number' then
		return settings.bars[key]
	end
	local settingsKey = ActionBars.SETTINGS_KEY[key]
	return settingsKey and settings[settingsKey]
end

function ActionBars.BarLabel(key)
	if type(key) == 'number' then return 'Bar ' .. key end
	return ActionBars.LABELS[key] or tostring(key)
end

function ActionBars.RegisterBar(bar)
	ActionBars.bars[bar.key] = bar
	return bar
end

function ActionBars.CreateHeader(name, secure)
	local header = CreateFrame('Frame', name, UIParent, secure and 'SecureHandlerStateTemplate' or nil)
	header:SetSize(1, 1)
	header:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	return header
end

function ActionBars.JustifyForAnchor(anchor)
	if anchor:find('LEFT', 1, true) then return 'LEFT' end
	if anchor:find('RIGHT', 1, true) then return 'RIGHT' end
	return 'CENTER'
end

function ActionBars.ForEachButton(callback)
	for _, bar in pairs(ActionBars.bars) do
		for _, button in ipairs(bar.buttons) do
			callback(button, bar)
		end
	end
end

function ActionBars.Plain(value)
	if issecretvalue(value) then return nil end
	return value
end

function ActionBars.RunSecure(key, task)
	BUI.Events:AfterCombat(task, 'ActionBars.' .. key)
end
