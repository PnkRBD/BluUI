local BUI = BluUI
local BUILib = BUI.BUILibClient
local Widget = BUILib.Widget

local ROW_HEIGHT = 28
local MAX_ROWS = 8
local ICON_SIZE = 18
local ICON_X = 10
local TEXT_X = 36
local PAD = 6
local RADIUS = 8
local LIST_GAP = 4
local MIN_WIDTH = 260
local DEBOUNCE = 0.2
local MIN_LETTERS = 2
local ICON_CROP = 0.08

local function Window()
	return BUI.PageEngine.window
end

local function BuildList(ui, window, box)
	local list = CreateFrame('Frame', nil, window.frame)
	list:SetFrameStrata(BUILib.GetPopupStrata())
	list:SetFrameLevel(BUILib.GetPopupLevel())
	list:SetPoint('TOPRIGHT', box, 'BOTTOMRIGHT', 0, -LIST_GAP)
	list:SetWidth(math.max(box:GetWidth(), MIN_WIDTH))
	list:EnableMouse(true)
	list:Hide()
	local fill, edge = Widget.DrawCardShape(list, RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
	window:Paint(fill, 'card')
	window:Paint(edge, 'cardEdge')
	list.rows = {}
	for index = 1, MAX_ROWS do
		local row = CreateFrame('Button', nil, list)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint('TOPLEFT', PAD, -(PAD + (index - 1) * ROW_HEIGHT))
		row:SetPoint('RIGHT', -PAD, 0)
		ui.Hover(row, true)
		row.icon = row:CreateTexture(nil, 'ARTWORK')
		row.icon:SetSize(ICON_SIZE, ICON_SIZE)
		row.icon:SetPoint('LEFT', ICON_X, 0)
		row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
		row.label = ui.Text(row, '', 12, 'text')
		row.label:SetPoint('LEFT', TEXT_X, 0)
		row.label:SetPoint('RIGHT', -ICON_X, 0)
		row.label:SetWordWrap(false)
		list.rows[index] = row
	end
	return list
end

function BUI.SpellSearch(ui, parent, width, options)
	local window = Window()
	local hits, pending, enterPressed = {}, 0, false
	local box, list

	local function Results(text)
		local found = BUI.Lookup.SearchSpellsAndItems(text)
		if not options.spellsOnly then return found end
		local spells = {}
		for _, hit in ipairs(found) do
			if not hit.isItem then spells[#spells + 1] = hit end
		end
		return spells
	end

	local function Pick(hit)
		hits = {}
		list:Hide()
		box.edit:SetText('')
		box.edit:ClearFocus()
		options.onPick(hit)
	end

	local function ShowResults()
		local shown = math.min(#hits, MAX_ROWS)
		for index, row in ipairs(list.rows) do
			local hit = hits[index]
			row:SetShown(hit ~= nil)
			if hit then
				row.icon:SetTexture(hit.icon)
				row.label:SetText(hit.name)
				row:SetScript('OnClick', function() Pick(hit) end)
			end
		end
		list:SetHeight(PAD * 2 + shown * ROW_HEIGHT)
		list:SetShown(shown > 0)
	end

	local function Suggest(text)
		pending = pending + 1
		local token = pending
		BUI.Profiler.After('SpellSearch suggest', DEBOUNCE, function()
			if token ~= pending or not box.edit:HasFocus() then return end
			hits = Results(text)
			ShowResults()
		end)
	end

	box = ui.Input(parent, width, { placeholder = options.placeholder or 'Search...', get = function() return '' end, set = function(text)
		if not enterPressed or text == '' then return end
		local found = #hits > 0 and hits or Results(text)
		if found[1] then Pick(found[1]) end
	end })
	list = BuildList(ui, window, box)

	box.edit:HookScript('OnKeyDown', function(_, key) enterPressed = key == 'ENTER' or key == 'NUMPADENTER' end)
	box.edit:HookScript('OnTextChanged', function(self, userInput)
		if not userInput then return end
		local text = self:GetText()
		if #text >= MIN_LETTERS then
			Suggest(text)
		else
			hits = {}
			list:Hide()
		end
	end)
	box.edit:HookScript('OnEditFocusLost', function()
		enterPressed = false
		if not list:IsMouseOver() then list:Hide() end
	end)
	box.edit:HookScript('OnEscapePressed', function() list:Hide() end)
	box:HookScript('OnHide', function() list:Hide() end)
	return box
end
