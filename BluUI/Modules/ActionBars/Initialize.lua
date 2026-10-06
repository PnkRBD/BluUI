local _, BUI = ...

local ActionBars = BUI.ActionBars

local function RefreshSecure()
	ActionBars.RefreshAllBars()
	ActionBars.RefreshPaging()
	ActionBars.RefreshPetBar()
	ActionBars.RefreshStanceBar()
	ActionBars.RefreshVehicleBar()
	ActionBars.RouteKeybinds()
	ActionBars.HideBlizzardBars()
end

function ActionBars.Refresh()
	if not BUI.IsModuleEnabled('actionBars') then return end
	ActionBars.RunSecure('Refresh', RefreshSecure)
	ActionBars.RefreshMicroBar()
	ActionBars.RefreshBagBar()
	ActionBars.RefreshExtraBar()
	ActionBars.RefreshKeyPress()
	ActionBars.RefreshProcGlow()
	ActionBars.RefreshMovers()
	ActionBars.RefreshFade()
	ActionBars.RefreshCooldownText()
	ActionBars.RefreshItemRank()
end

function ActionBars.OnProfileChanged()
	ActionBars.Refresh()
end

local SECURE_BARS = { pet = 'RefreshPetBar', stance = 'RefreshStanceBar', vehicle = 'RefreshVehicleBar' }
local PLAIN_BARS = { micro = 'RefreshMicroBar', bags = 'RefreshBagBar', extra = 'RefreshExtraBar' }

function ActionBars.RefreshOnly(key)
	if not BUI.IsModuleEnabled('actionBars') then return end
	if type(key) == 'number' then
		ActionBars.RunSecure('Refresh.' .. key, function()
			ActionBars.RefreshBar(key)
			ActionBars.RefreshBarPaging(key)
			ActionBars.RouteKeybinds()
		end)
	elseif SECURE_BARS[key] then
		ActionBars.RunSecure('Refresh.' .. key, ActionBars[SECURE_BARS[key]])
	else
		ActionBars[PLAIN_BARS[key]]()
	end
	ActionBars.RefreshMovers()
	ActionBars.RefreshBarFade(key)
	ActionBars.RefreshBarCooldownText(key)
end

function ActionBars.Initialize()
	ActionBars.Refresh()
	BUI.Pixel.OnScaleChange('ActionBars', ActionBars.Refresh)
end
