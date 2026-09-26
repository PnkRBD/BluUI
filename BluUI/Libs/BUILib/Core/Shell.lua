local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout

local DEFAULT_PAGE_WIDTH = 800

local Shell = {}
Shell.__index = Shell

local function RestoreGeometry(shell)
	local geometry = shell:Store().geometry
	if not geometry then return end
	local frame = shell.window.frame
	frame:ClearAllPoints()
	frame:SetPoint(geometry.point, UIParent, geometry.relativePoint, geometry.x, geometry.y)
	frame:SetSize(geometry.width, geometry.height)
end

local function SelectNav(shell, pageID)
	local highlight = shell.pages[pageID].parent or pageID
	for index, id in ipairs(shell.order) do
		local button = shell.navButtons[index]
		if button then button:SetSelected(id == highlight) end
	end
end

local function BuildPage(shell, page)
	local container = CreateFrame('Frame', nil, shell.window.content)
	container:SetAllPoints()
	local layoutPage = Layout.Page(container, nil, shell.config.pageWidth or DEFAULT_PAGE_WIDTH)
	page.build(layoutPage:GetTab(1), shell)
	layoutPage:AutoRefresh()
	page.container = container
end

local function DiscardPage(page)
	page.container:Hide()
	page.container:SetParent(nil)
	page.container = nil
end

local function CreateWindow(shell)
	local build = shell:Chrome() == 'topnav' and Layout.TopNavWindow or Layout.Window
	shell.window = build(setmetatable({
		escapable = true,
		theme = shell:Theme(),
		onGeometryChanged = function() shell:SaveGeometry() end,
	}, { __index = shell.config }))
	RestoreGeometry(shell)
	shell:BuildNav()
	if shell.config.onWindowCreated then shell.config.onWindowCreated(shell.window) end
end

function Shell:Store()
	local name = self.config.savedVariable
	if not name then return self.memory end
	_G[name] = _G[name] or {}
	return _G[name]
end

function Shell:SaveGeometry()
	local frame = self.window.frame
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	self:Store().geometry = { point = point, relativePoint = relativePoint, x = x, y = y, width = frame:GetWidth(), height = frame:GetHeight() }
end

function Shell:Theme()
	local store = self:Store()
	store.theme = store.theme or {}
	return store.theme
end

function Shell:Chrome()
	return self:Store().chrome or self.config.chrome
end

function Shell:SetChrome(chrome)
	self:Store().chrome = chrome
	if not self.window then return end
	local current = self.current
	for _, page in pairs(self.pages) do
		if page.container then DiscardPage(page) end
	end
	self.window:Hide()
	self.window.frame:SetParent(nil)
	self.window = nil
	self.current = nil
	self:Open(current)
end

function Shell:ApplyTheme()
	if self.window then self.window:ApplyTheme(self:Theme()) end
end

function Shell:BuildNav()
	local sections, sectionByName = {}, {}
	for _, pageID in ipairs(self.order) do
		local sectionName = self.pages[pageID].section
		if sectionName then
			local section = sectionByName[sectionName]
			if not section then
				section = { header = sectionName, ids = {} }
				sectionByName[sectionName] = section
				sections[#sections + 1] = section
			end
			section.ids[#section.ids + 1] = pageID
		end
	end
	self.navButtons = self.window:SetNavStyle(nil, {
		pages = self.pages,
		pageOrder = self.order,
		sections = sections,
		showPage = function(index) self:ShowPage(self.order[index]) end,
	})
	if self.current then SelectNav(self, self.current) end
end

function Shell:AddPage(pageID, page)
	self.pages[pageID] = page
	self.order[#self.order + 1] = pageID
	if self.window then self:BuildNav() end
	return page
end

function Shell:ShowPage(pageID)
	local page = self.pages[pageID]
	if not page or not self.window then return end
	local previous = self.current and self.pages[self.current]
	if previous ~= page then
		if previous and previous.container then previous.container:Hide() end
		if page.container and page.rebuildOnShow then DiscardPage(page) end
	end
	if page.container then
		page.container:Show()
	else
		BuildPage(self, page)
	end
	self.current = pageID
	SelectNav(self, pageID)
end

function Shell:RebuildPage(pageID)
	local page = self.pages[pageID]
	if not page.container then return end
	DiscardPage(page)
	if self.current == pageID then self:ShowPage(pageID) end
end

function Shell:Open(pageID)
	if not self.window then CreateWindow(self) end
	BUILib.SetPopupParent(self.window.frame)
	self.window:Show()
	self:ShowPage(pageID or self.current or self.order[1])
end

function Shell:Close()
	if self.window then self.window:Hide() end
end

function Shell:IsShown()
	return self.window ~= nil and self.window.frame:IsShown()
end

function Shell:FindPage(query)
	query = query:lower():match('^%s*(.-)%s*$')
	if query == '' then return nil end
	for _, pageID in ipairs(self.order) do
		if pageID:lower() == query or (self.pages[pageID].title or pageID):lower():find(query, 1, true) then return pageID end
	end
end

function Shell:Toggle(query)
	local pageID = query and self:FindPage(query)
	if pageID then
		self:Open(pageID)
	elseif self:IsShown() then
		self:Close()
	else
		self:Open()
	end
end

function Layout.Shell(config)
	local shell = setmetatable({ config = config, memory = {}, pages = {}, order = {}, navButtons = {} }, Shell)
	if config.slash then
		local key = ('BUILIBSHELL' .. (config.globalName or config.title)):upper():gsub('%W', '')
		for index, command in ipairs(config.slash) do _G['SLASH_' .. key .. index] = command end
		SlashCmdList[key] = function(message) shell:Toggle(message) end
	end
	return shell
end
