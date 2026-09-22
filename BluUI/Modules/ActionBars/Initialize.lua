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

function ActionBars.Initialize()
	ActionBars.Refresh()
	BUI.Pixel.OnScaleChange('ActionBars', ActionBars.Refresh)
end
