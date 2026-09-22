local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls, Layout = BUILib.Controls, BUILib.Layout

local Visibility = BUI.Visibility

local STATES = {
	outOfCombat = { label = 'Out of Combat',   icon = 136116 },
	combat      = { label = 'In Combat',       icon = 132349 },
	mounted     = { label = 'Mounted',         icon = 132261 },
	flying      = { label = 'Flying',          icon = 135943 },
	vehicle     = { label = 'In Vehicle',      icon = 135995 },
	inInstance  = { label = 'In Instance',     icon = 136011 },
	dead        = { label = 'Dead',            icon = 135849 },
	override    = { label = 'Override/Puzzle', icon = 236566 },
	petBattle   = { label = 'Pet Battle',      icon = 631719 },
}

local MODULE_LABELS = {
	UnitFrames     = 'Unit Frames',
	CastBars       = 'Cast Bars',
	CDM            = 'Cooldown Manager',
	CustomBars     = 'Custom Bars',
	BuffTracking   = 'Buff Tracking',
	PowerBar       = 'Power Bar',
	SecondaryPower = 'Secondary Power',
}

local function ValidatePriority(db)
	local priority = db.general.visibilityPriority
	local present = {}
	for index = 1, #priority do present[priority[index]] = true end
	for _, conditionKey in ipairs(Visibility.DEFAULT_PRIORITY) do
		if not present[conditionKey] then priority[#priority + 1] = conditionKey end
	end
	local keptCount = 0
	for index = 1, #priority do
		if Visibility.CONDITIONS[priority[index]] then
			keptCount = keptCount + 1
			priority[keptCount] = priority[index]
		end
	end
	for index = keptCount + 1, #priority do priority[index] = nil end
	return priority
end

BUI.VisibilityPage = {}

function BUI.VisibilityPage.BuildTab(tab)
	local PageKit = BUILib.PageKit
	local db = BUI.GetDB()
	local opacity = db.general.visibilityOpacity

	local function UpdateAllModules()
		BUI.Visibility.Update(true)
	end

	local disabledSet = db.general.visibilityModulesDisabled

	local registered = BUI.Visibility.GetRegisteredKeys()
	table.sort(registered, function(leftKey, rightKey)
		return (MODULE_LABELS[leftKey] or leftKey) < (MODULE_LABELS[rightKey] or rightKey)
	end)

	local moduleItems = {}
	local moduleSelected = {}
	for moduleIndex = 1, #registered do
		local moduleKey = registered[moduleIndex]
		moduleItems[moduleIndex] = {value = moduleKey, text = MODULE_LABELS[moduleKey] or moduleKey}
		moduleSelected[moduleKey] = not disabledSet[moduleKey]
	end

	Layout.Section(tab, 'Affected Modules')
	local moduleGrid = PageKit.RowGrid(tab)

	moduleGrid:Add({
		spanFull = true,
		title = 'Modules That Obey State Opacity',
		description = 'Unchecked modules ignore visibility and stay at 100%.',
		plain = true,
		accessoryWidth = 270,
		accessories = function(row)
			return { Controls.MultiDropdown(row, nil, moduleItems, moduleSelected, function(selected)
				for moduleIndex = 1, #registered do
					local moduleKey = registered[moduleIndex]
					if selected[moduleKey] then
						disabledSet[moduleKey] = nil
					else
						disabledSet[moduleKey] = true
					end
				end
				BUI.Visibility.Update(true)
			end, nil, 260) }
		end,
	})
	moduleGrid:Flush()

	local priority = ValidatePriority(db)

	Layout.Section(tab, 'State Opacity', 'Opacity per character state. Higher-priority states (earlier cards) win when several apply.')

	local COLUMN_COUNT, CARD_GAP, CARD_HEIGHT = 3, 12, 78
	local innerWidth = tab.width
	local CARD_WIDTH = math.floor((innerWidth - (COLUMN_COUNT - 1) * CARD_GAP) / COLUMN_COUNT)

	local cardGrid = Controls.DraggableCardGrid(tab.child, {
		columns = COLUMN_COUNT, cardWidth = CARD_WIDTH, cardHeight = CARD_HEIGHT, gap = CARD_GAP,
		onReorder = function(order)
			local keptCount = 0
			for index = 1, #order do
				if order[index] ~= 'outOfCombat' then
					keptCount = keptCount + 1
					priority[keptCount] = order[index]
				end
			end
			for index = keptCount + 1, #priority do priority[index] = nil end
			UpdateAllModules()
		end,
		onValueChange = function(key, value)
			opacity[key] = value
			UpdateAllModules()
		end,
	})

	local function AddStateCard(key)
		local state = STATES[key]
		cardGrid:AddCard(state.icon, state.label, key, opacity[key], 0, 100, 1, true)
	end

	for index = 1, #priority do AddStateCard(priority[index]) end
	AddStateCard('outOfCombat')

	local gridFrame = cardGrid.frame
	local cardGridHeight = gridFrame:GetHeight()
	Layout.PositionInTab(tab, gridFrame, cardGridHeight, 10)

	local reorderButton
	local buttonDefs = {
		{text = 'Reorder States', width = 140, callback = function()
			local entering = not cardGrid:IsDragMode()
			cardGrid:SetDragMode(entering)
			reorderButton:SetText(entering and 'Done Reordering' or 'Reorder States')
		end},
		{text = 'Reset All to 100', width = 140, callback = function()
			for key in pairs(STATES) do
				opacity[key] = 100
			end
			cardGrid:ResetAllValues(100)
			UpdateAllModules()
		end},
		{text = 'Reset Priority', width = 140, callback = function()
			for index, conditionKey in ipairs(Visibility.DEFAULT_PRIORITY) do
				priority[index] = conditionKey
			end
			for index = #Visibility.DEFAULT_PRIORITY + 1, #priority do priority[index] = nil end
			cardGrid:ClearCards()
			for index = 1, #priority do AddStateCard(priority[index]) end
			AddStateCard('outOfCombat')
			UpdateAllModules()
		end},
	}
	local _, buttons = Layout.ButtonRow(tab, buttonDefs, 12)
	reorderButton = buttons[1]
end
