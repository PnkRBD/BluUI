local _, BUI = ...
local Navigation = {}
BUI.Nav = Navigation

local SECTIONS = {
	{header = 'General',  ids = {'dashboard', 'cursor', 'minimap', 'datatext', 'markers', 'auras'}},
	{header = 'Combat',   ids = {'actionbars', 'power', 'cdm', 'castbars', 'unitframes'}},
	{header = 'Quality of life', ids = {'qol'}},
	{header = 'System',   ids = {'settings', 'exportimport'}},
}

function Navigation.Apply()
	local engine = BUI.PageEngine
	engine.buttons = engine.window:SetNavStyle(nil, {
		pageOrder = engine.pageOrder,
		pages     = engine.pages,
		showPage  = engine.ShowPage,
		sections  = SECTIONS,
	})
end

function Navigation.Shortcuts()
	local engine, chosen = BUI.PageEngine, BUI.db.global.dockPages
	local current, items = engine.GetCurrentPage(), {}
	for _, section in ipairs(SECTIONS) do
		for _, id in ipairs(section.ids) do
			local page = engine.pages[id]
			if page then
				items[#items + 1] = {
					icon = page.icon, label = BUI.BUILibClient.Widget.StripColorCodes(page.buttonText or page.title), current = id == current,
					get = function() return chosen[id] end,
					set = function(value) chosen[id] = value end,
					open = function()
						engine.Show()
						if engine.frame:IsShown() then engine.NavigateToID(id) end
					end,
				}
			end
		end
	end
	return items
end
