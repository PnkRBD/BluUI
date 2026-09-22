local _, BUI = ...
local Navigation = {}
BUI.Nav = Navigation

local PAGE_ABBREVIATIONS = {
	dashboard = 'DSH', cursor = 'CUR', minimap = 'MAP', datatext = 'DAT',
	markers = 'MRK',
	auras = 'AUR', actionbars = 'ABR', power = 'PWR', cdm = 'CDM', castbars = 'CST',
	unitframes = 'UFR', groupframes = 'GRP', customBars = 'ITM',
	buffTracking = 'BUF', cdAnnouncer = 'CDA', settings = 'SET',
	exportimport = 'PRF',
}

local SECTIONS = {
	{header = 'General',  ids = {'dashboard', 'cursor', 'minimap', 'datatext', 'markers', 'auras'}},
	{header = 'Combat',   ids = {'actionbars', 'power', 'cdm', 'castbars', 'unitframes', 'groupframes'}},
	{header = 'Tracking', ids = {'customBars', 'cdAnnouncer', 'buffTracking'}},
	{header = 'System',   ids = {'settings', 'exportimport'}},
}

function Navigation.Apply(styleName)
	local engine = BUI.PageEngine
	if not engine.window then return end

	local activeIndex = engine.currentIndex
	local pageConfig = engine.pages[engine.pageOrder[activeIndex]]
	local tabController = pageConfig and pageConfig.frame and pageConfig.frame._page
	local activeTab = tabController and tabController.currentTab

	for _, config in pairs(engine.pages) do
		engine.TeardownPageContent(config)
	end

	engine.buttons = engine.window:SetNavStyle(styleName, {
		pageOrder      = engine.pageOrder,
		pages          = engine.pages,
		showPage       = engine.ShowPage,
		abbreviations  = PAGE_ABBREVIATIONS,
		sections       = SECTIONS,
		highlightStyle = BUI.db.global.navHighlight,
	})

	engine.ShowPage(activeIndex)
	tabController = activeTab and pageConfig.frame and pageConfig.frame._page
	if tabController and tabController.SetTab then
		tabController:SetTab(activeTab)
	end
end

function Navigation.GetCurrentStyle()
	return BUI.db.global.navStyle
end
