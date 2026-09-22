local _, BUI = ...

local ActionBars = BUI.ActionBars

local MODIFIER_ORDER = { 'ctrl', 'alt', 'shift' }
local MAIN_PAGE_COUNT = 6
local BONUS_BAR_COUNT = 4
local SKYRIDING_PAGE = 11
local FALLBACK_POSSESS_PAGE = 12

local PAGE_SNIPPET = [[
	local page = newstate
	if page == 'possess' then
		if HasVehicleActionBar() then
			page = GetVehicleBarIndex()
		elseif HasOverrideActionBar() then
			page = GetOverrideBarIndex()
		elseif HasTempShapeshiftActionBar() then
			page = GetTempShapeshiftBarIndex()
		elseif HasBonusActionBar() then
			page = GetBonusBarIndex()
		else
			page = %d
		end
	end
	self:SetAttribute('state', page)
	control:ChildUpdate('state', page)
]]

function ActionBars.SetPagingStates(button, buttonIndex)
	for page = 1, ActionBars.PAGE_COUNT do
		button:SetState(page, 'action', (page - 1) * ActionBars.BUTTONS_PER_PAGE + buttonIndex)
	end
end

function ActionBars.PagingDriver(barSettings, barIndex)
	local parts = { '[overridebar][possessbar][shapeshift][vehicleui] possess' }
	for _, modifier in ipairs(MODIFIER_ORDER) do
		local page = barSettings.modifierPages[modifier]
		if page > 0 then parts[#parts + 1] = ('[mod:%s] %d'):format(modifier, page) end
	end
	if barIndex == 1 then
		for page = 2, MAIN_PAGE_COUNT do
			parts[#parts + 1] = ('[bar:%d] %d'):format(page, page)
		end
		parts[#parts + 1] = ('[bonusbar:5] %d'):format(SKYRIDING_PAGE)
		for bonus = 1, BONUS_BAR_COUNT do
			parts[#parts + 1] = ('[bonusbar:%d] %d'):format(bonus, MAIN_PAGE_COUNT + bonus)
		end
	end
	parts[#parts + 1] = tostring(ActionBars.PAGE_FOR_BAR[barIndex])
	return table.concat(parts, '; ')
end

local function RefreshBarPaging(barIndex)
	local bar = ActionBars.bars[barIndex]
	if not bar then return end
	local barSettings = ActionBars.GetBarSettings(barIndex)
	local header = bar.header
	local ownPage = ActionBars.PAGE_FOR_BAR[barIndex]
	if not header._buiPagingSnippet then
		header:SetAttribute('_onstate-page', PAGE_SNIPPET:format(barIndex == 1 and FALLBACK_POSSESS_PAGE or ownPage))
		header._buiPagingSnippet = true
	end
	if barSettings.enabled and barSettings.pagingEnabled then
		RegisterStateDriver(header, 'page', ActionBars.PagingDriver(barSettings, barIndex))
	else
		UnregisterStateDriver(header, 'page')
		header:SetAttribute('state', ownPage)
		header:Execute(([[ control:ChildUpdate('state', %d) ]]):format(ownPage))
	end
end

function ActionBars.RefreshPaging()
	for barIndex = 1, #ActionBars.COMMAND_FOR_BAR do RefreshBarPaging(barIndex) end
end
