local _, BUI = ...
local LibDBIcon     = LibStub('LibDBIcon-1.0')
local LibDataBroker = LibStub('LibDataBroker-1.1')
local dataObject = LibDataBroker:NewDataObject(BUI.ADDON_NAME, {
	type = 'launcher',
	text = BUI.ADDON_NAME,
	icon = BUI.C.ICON_PATH,
	OnClick = function(_, button)
		if button == 'LeftButton' then BUI.PageEngine.Toggle() end
	end,
	OnTooltipShow = function(tooltip)
		tooltip:AddLine(BUI.ADDON_NAME, 1, 1, 1)
		tooltip:AddLine('Left-click to open settings', 0.7, 0.7, 0.7)
	end,
})

function BUI.InitializeMinimapButton()
	LibDBIcon:Register(BUI.ADDON_NAME, dataObject, BUI.GetDB().general.minimapButton)
end

function BUI.IsMinimapButtonHidden()
	local db = BUI.GetDB().general.minimapButton
	return db.hide and true or false
end

function BUI.SetMinimapButtonHidden(hide)
	local db = BUI.GetDB().general.minimapButton
	db.hide = hide and true or false
	if db.hide then
		LibDBIcon:Hide(BUI.ADDON_NAME)
	else
		LibDBIcon:Show(BUI.ADDON_NAME)
	end
end
