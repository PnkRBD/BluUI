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
