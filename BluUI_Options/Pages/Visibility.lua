local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Visibility = BUI.Visibility

local SLIDER_WIDTH = 220
local ARROW = 22
local ARROW_GAP = 4
local CONTROL_ROOM = SLIDER_WIDTH + 12 + ARROW * 2 + ARROW_GAP

local STATES = {
	outOfCombat = { label = 'Out of combat', sub = 'The fallback when nothing else applies' },
	combat = { label = 'In combat', sub = 'While you are fighting' },
	mounted = { label = 'Mounted', sub = 'On a mount or in travel form' },
	flying = { label = 'Flying', sub = 'In the air' },
	vehicle = { label = 'In a vehicle', sub = 'Riding a vehicle' },
	inInstance = { label = 'In an instance', sub = 'Dungeons, raids, arenas and battlegrounds' },
	dead = { label = 'Dead', sub = 'Dead or a ghost' },
	override = { label = 'Override or puzzle', sub = 'An override bar or a puzzle is up' },
	petBattle = { label = 'Pet battle', sub = 'During a pet battle' },
}

local MODULE_LABELS = {
	UnitFrames = 'Unit Frames',
	CastBars = 'Cast Bars',
	CDM = 'Cooldown Manager',
	CustomBars = 'Custom Bars',
	BuffTracking = 'Buff Tracking',
	PowerBar = 'Power Bar',
	SecondaryPower = 'Secondary Power',
}

local function Window()
	return BUI.PageEngine.window
end

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

local function ModulesBoard(ui, parent, width)
	local disabled = BUI.GetDB().general.visibilityModulesDisabled
	local keys = Visibility.GetRegisteredKeys()
	table.sort(keys, function(left, right) return (MODULE_LABELS[left] or left) < (MODULE_LABELS[right] or right) end)
	local board = ui.Board(parent, width, { title = 'Modules', description = 'The modules that follow the state opacity below. Anything off here stays at full opacity.' })
	for _, key in ipairs(keys) do
		board:AddSwitch(MODULE_LABELS[key] or key, function() return not disabled[key] end, function(follows)
			disabled[key] = not follows or nil
			Visibility.Update(true)
		end)
	end
	return board
end

local function StateBoard(ui, parent, width, page)
	local db = BUI.GetDB()
	local opacity = db.general.visibilityOpacity
	local priority = ValidatePriority(db)
	local rows = {}
	local board
	board = ui.Board(parent, width, {
		stacked = true,
		title = 'State opacity',
		description = 'How see-through the modules go in each state. Higher rows win when several states apply, and out of combat is the fallback.',
		buttons = {
			{ text = 'Reset order', icon = 'reset', onClick = function()
				for index, conditionKey in ipairs(Visibility.DEFAULT_PRIORITY) do priority[index] = conditionKey end
				for index = #Visibility.DEFAULT_PRIORITY + 1, #priority do priority[index] = nil end
				Visibility.Update(true)
				page:Rebuild('visibility')
			end },
			{ style = 'primary', text = 'All to 100', onClick = function()
				for key in pairs(STATES) do opacity[key] = 100 end
				Visibility.Update(true)
				Window():Repaint()
			end },
		},
	})
	local function Move(key, delta)
		local index
		for position, conditionKey in ipairs(priority) do
			if conditionKey == key then index = position end
		end
		if not priority[index + delta] then return end
		priority[index], priority[index + delta] = priority[index + delta], priority[index]
		board:Move(rows[key], delta)
		Visibility.Update(true)
		page:Resize()
	end
	local function StateRow(key, movable)
		local state = STATES[key]
		local row = board:AddRow(state.label, state.sub, CONTROL_ROOM)
		rows[key] = row
		ui.Slider(row, SLIDER_WIDTH, { min = 0, max = 100, step = 1, get = function() return opacity[key] end, set = function(value)
			opacity[key] = value
			Visibility.Update(true)
		end }):SetPoint('RIGHT', -ui.ROW_INSET, 0)
		if movable then
			local down = ui.ArrowButton(row, false, function() Move(key, 1) end)
			down:SetPoint('RIGHT', -(ui.ROW_INSET + SLIDER_WIDTH + 12), 0)
			ui.ArrowButton(row, true, function() Move(key, -1) end):SetPoint('RIGHT', down, 'LEFT', -ARROW_GAP, 0)
		end
	end
	for _, key in ipairs(priority) do StateRow(key, true) end
	StateRow('outOfCombat', false)
	return board
end

BUI.VisibilityPage = {}

function BUI.VisibilityPage.Sections(ui, _, parent, width, page)
	return { ModulesBoard(ui, parent, width), StateBoard(ui, parent, width, page) }
end
