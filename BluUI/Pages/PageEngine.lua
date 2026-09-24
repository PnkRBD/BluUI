local _, BUI = ...
local Pixel = BUI.Pixel
local Layout = BUI.BUILibClient.Layout

local PageEngine = {
	pages        = {},
	pageOrder    = {},
	buttons      = {},
	currentIndex = 1,
}
BUI.PageEngine = PageEngine

local function GetCurrentPageConfig()
	local pageID = PageEngine.pageOrder[PageEngine.currentIndex]
	return pageID and PageEngine.pages[pageID]
end

local function HideCurrentPage()
	local pageConfig = GetCurrentPageConfig()
	if not pageConfig or not pageConfig.frame or not pageConfig.frame:IsShown() then return end
	if pageConfig.OnHide then pageConfig.OnHide(pageConfig.frame) end
	pageConfig.frame:Hide()
end

local function TeardownPageContent(pageConfig)
	if not pageConfig.frame then return end

	if pageConfig.frame:IsShown() and pageConfig.OnHide then pageConfig.OnHide(pageConfig.frame) end
	pageConfig.frame:Hide()
	pageConfig.frame:UnregisterAllEvents()
	pageConfig.frame:SetScript('OnUpdate', nil)
	pageConfig.frame:SetParent(nil)
	pageConfig.frame = nil
	pageConfig.stale = nil
end
PageEngine.TeardownPageContent = TeardownPageContent

local function CreateWindow()
	if PageEngine.window then return end

	local SearchIndex   = BUI.SearchIndex
	local SearchResults = BUI.SearchResults

	local window
	window = Layout.Window({
		width        = 1100, height    = 700, title = 'BluUI',
		icon         = BUI.C.ICON_PATH,
		minWidth     = 1044, minHeight = 640,
		version      = BUI.Version, sidebarWidth = 190,
		strata       = 'FULLSCREEN_DIALOG', frameLevel = 200, escapable = true,
		onSettings   = function() PageEngine.NavigateToID('settings') end,
		onHelp       = function() BUI.Settings.OpenDiagnostics() end,
		globalName   = 'BluUIFrame', footerButtons = BUI.Scale.GetFooterButtons(),
		clampedToScreen = false,
		searchBox    = {
			placeholder = 'Search...',
			width       = 200,
			onSearch    = function(query)
				if not query or query == '' then SearchResults.Hide(); return end
				local results = SearchIndex.Search(query)
				if #results > 0 then
					SearchResults.Show(results, window.searchBox.frame)
				else
					SearchResults.Hide()
				end
			end,
			onSubmit    = function(query)
				local results = SearchIndex.Search(query)
				if results[1] then
					SearchResults.Hide()
					SearchResults.NavigateTo(results[1])
					return true
				end
			end,
		},
	})
	window.frame:Hide()
	PageEngine.window = window
	PageEngine.frame  = window.frame
	PageEngine.searchBox = window.searchBox
	BUI.Scale.SetupButtons(window, PageEngine.frame)

	window.frame:HookScript('OnHide', HideCurrentPage)

	local searchBoxFrame = window.searchBox.frame
	local buttonFrame = window.footerLeftmost.frame or window.footerLeftmost
	searchBoxFrame:SetParent(buttonFrame:GetParent())
	searchBoxFrame:ClearAllPoints()
	searchBoxFrame:SetPoint('TOP', buttonFrame, 'TOP', 0, 0)
	searchBoxFrame:SetPoint('BOTTOM', buttonFrame, 'BOTTOM', 0, 0)
	if window.sidebar then searchBoxFrame:SetPoint('LEFT', window.sidebar, 'RIGHT', Pixel.Scale(12), 0) end
	searchBoxFrame:SetPoint('RIGHT', buttonFrame, 'LEFT', Pixel.Scale(-8), 0)
end

local function BuildPageContent(pageConfig)
	local frame = CreateFrame('Frame', nil, PageEngine.window.content)
	frame:SetAllPoints(PageEngine.window.content)
	frame:Hide()
	if pageConfig.OnBuild then pageConfig.OnBuild(frame) end
	return frame
end

local function UpdateNavSelection()
	local pageConfig = GetCurrentPageConfig()
	local selectedIndex = PageEngine.currentIndex
	if pageConfig and pageConfig.navParent then
		for pageIndex = 1, #PageEngine.pageOrder do
			if PageEngine.pageOrder[pageIndex] == pageConfig.navParent then selectedIndex = pageIndex; break end
		end
	end
	for _, button in ipairs(PageEngine.buttons) do
		button:SetSelected(button.pageIndex == selectedIndex)
	end
end

function PageEngine.RegisterPage(id, pageConfig)
	if PageEngine.pages[id] then return end
	PageEngine.pages[id] = pageConfig or {}
	PageEngine.pageOrder[#PageEngine.pageOrder + 1] = id
end

function PageEngine.ShowPage(index)
	if not PageEngine.window then return end
	local pageID = PageEngine.pageOrder[index]
	if not pageID then return end
	local pageConfig = PageEngine.pages[pageID]
	if pageConfig.disabled then return end
	if index == PageEngine.currentIndex and pageConfig.frame and pageConfig.frame:IsShown() then return end
	HideCurrentPage()
	if pageConfig.frame and pageConfig.stale then TeardownPageContent(pageConfig) end
	if not pageConfig.frame then pageConfig.frame = BuildPageContent(pageConfig) end
	pageConfig.frame:Show()
	PageEngine.window:SetContentMinSize(pageConfig.minContentWidth or 895, pageConfig.minContentHeight or 0)
	if pageConfig.OnShow then pageConfig.OnShow(pageConfig.frame) end
	PageEngine.currentIndex = index
	UpdateNavSelection()
end

local OPTIONS_ADDON = 'BluUI_Options'

function PageEngine.EnsureLoaded()
	if PageEngine.optionsLoaded then return true end
	if not C_AddOns.IsAddOnLoaded(OPTIONS_ADDON) then
		local loaded, reason = C_AddOns.LoadAddOn(OPTIONS_ADDON)
		if not loaded then
			BUI.Print(('Could not load the BluUI_Options folder (%s). Reinstall BluUI so both the BluUI and BluUI_Options folders are present.'):format(tostring(reason)))
			return false
		end
	end
	PageEngine.optionsLoaded = true
	return true
end

function PageEngine.Show()
	if InCombatLockdown() then
		if not PageEngine._combatWaiting then
			PageEngine._combatWaiting = true
			BUI.Print('Settings will open when combat ends.')
			BUI.Events:AfterCombat(function()
				PageEngine._combatWaiting = false
				PageEngine.Show()
			end, 'PageEngine.Show')
		end
		return
	end

	if BUI.ReassertBUILib then BUI.ReassertBUILib() end
	if not PageEngine.EnsureLoaded() then return end
	if not PageEngine.window then
		CreateWindow()
		BUI.Nav.Apply(BUI.Nav.GetCurrentStyle())
	end
	PageEngine.window:Show()
	PageEngine.ShowPage(PageEngine.currentIndex)
end

function PageEngine.Hide()
	if not PageEngine.window then return end

	PageEngine.window:Hide()
end

function PageEngine.Toggle()
	if PageEngine.frame and PageEngine.frame:IsShown() then
		PageEngine.Hide()
	else
		PageEngine.Show()
	end
end

function PageEngine.GetCurrentPage()
	return PageEngine.pageOrder[PageEngine.currentIndex]
end

function PageEngine.NavigateToID(id)
	for pageIndex = 1, #PageEngine.pageOrder do
		if PageEngine.pageOrder[pageIndex] == id then
			PageEngine.ShowPage(pageIndex)
			return true
		end
	end
end

local function CurrentPageTab()
	local pageConfig = GetCurrentPageConfig()
	local page = pageConfig and pageConfig.frame and pageConfig.frame._page
	return page and page.currentTab
end

local function RestorePageTab(tabIndex)
	if not tabIndex or tabIndex <= 1 then return end
	local pageConfig = GetCurrentPageConfig()
	local page = pageConfig and pageConfig.frame and pageConfig.frame._page
	if page and page.tabContents and page.tabContents[tabIndex] then
		page:SetTab(tabIndex)
	end
end

function PageEngine.RebuildAllPages()
	for _, pageConfig in pairs(PageEngine.pages) do
		if pageConfig.frame then pageConfig.stale = true end
	end
	if PageEngine.frame and PageEngine.frame:IsShown() then
		PageEngine.RefreshCurrentPage()
	end
end

function PageEngine.RefreshCurrentPage()
	if not PageEngine.frame or not PageEngine.frame:IsShown() then return end
	local pageConfig = GetCurrentPageConfig()
	if not pageConfig then return end
	local keepTab = CurrentPageTab()
	TeardownPageContent(pageConfig)
	PageEngine.ShowPage(PageEngine.currentIndex)
	RestorePageTab(keepTab)
end
