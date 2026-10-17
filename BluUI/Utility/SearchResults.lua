local _, BUI = ...
local Pixel = BUI.Pixel
local After = BUI.Profiler.After

local BUILib = BluUI.BUILibClient
local Theme = BUILib.Theme
local Widget = BUILib.Widget

BUI.SearchResults = {}
local SearchResults = BUI.SearchResults

local TIFFANY = { 0.04, 0.73, 0.71 }
local MAX_VISIBLE = 10
local ROW_HEIGHT = 28

local dropdown, rows, activeCount = nil, {}, 0
local scrollAnim, pulseAnim, highlight

local function CreateDropdown(parent)
	if dropdown then return end
	dropdown = Widget.New(parent, 'Frame', nil, {
		bg = Theme.bg.panel, border = Theme.border.dark, size = { 300, 100 },
	}).frame
	dropdown:SetFrameStrata('FULLSCREEN_DIALOG')
	dropdown:SetFrameLevel(500)
	dropdown:EnableKeyboard(false)
	dropdown:EnableMouse(true)
	dropdown:Hide()

	local scroll = BUILib.Controls.ScrollFrame(dropdown, nil, nil, 100)
	scroll:SetPoint('TOPLEFT', Pixel.Scale(4), Pixel.Scale(-4))
	scroll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-4), Pixel.Scale(4))
	dropdown._child = scroll.child
end

local function OnRowClick(self)
	SearchResults.Hide()
	SearchResults.NavigateTo(self._result)
	local searchBox = BUI.PageEngine.searchBox
	searchBox:SetValue('')
	searchBox.frame.editbox:ClearFocus()
end

local function GetRow(index)
	if rows[index] then return rows[index] end
	local row = CreateFrame('Button', nil, dropdown._child)
	row:SetSize(Pixel.Scale(280), Pixel.Scale(ROW_HEIGHT))
	row:SetPoint('TOPLEFT', 0, Pixel.Scale(-(index - 1) * ROW_HEIGHT))

	local highlightTexture = row:CreateTexture(nil, 'HIGHLIGHT')
	highlightTexture:SetAllPoints()
	highlightTexture:SetColorTexture(1, 1, 1, 0.06)

	row._crumb = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row._crumb, 10, BUILib.Font, '')
	row._crumb:SetPoint('TOPLEFT', Pixel.Scale(8), Pixel.Scale(-3))
	row._crumb:SetTextColor(0.5, 0.5, 0.5)

	row._label = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row._label, 12, BUILib.Font, '')
	row._label:SetPoint('TOPLEFT', Pixel.Scale(8), Pixel.Scale(-14))
	row._label:SetTextColor(1, 1, 1)

	row:SetScript('OnClick', BUI.Profiler.Script('SearchResults row OnClick', OnRowClick))

	rows[index] = row
	return row
end

function SearchResults.Show(results, anchor)
	CreateDropdown(BUI.PageEngine.frame)

	activeCount = math.min(#results, MAX_VISIBLE * 3)
	local visible = math.min(activeCount, MAX_VISIBLE)

	for rowIndex = 1, activeCount do
		local row = GetRow(rowIndex)
		local result = results[rowIndex]
		local crumb = result.pageTitle
		if result.tabName then crumb = crumb .. ' > ' .. result.tabName end
		if result.panel then crumb = crumb .. ' > ' .. result.panel end
		row._crumb:SetText(crumb)
		row._label:SetText(result.label)
		row._result = result
		row:Show()
	end
	for rowIndex = activeCount + 1, #rows do rows[rowIndex]:Hide() end

	dropdown._child:SetHeight(Pixel.Scale(activeCount * ROW_HEIGHT))
	dropdown:SetHeight(Pixel.Scale(visible * ROW_HEIGHT + 16))
	dropdown:ClearAllPoints()
	dropdown:SetPoint('BOTTOMLEFT', anchor, 'TOPLEFT', 0, Pixel.Scale(2))
	dropdown:SetPoint('BOTTOMRIGHT', anchor, 'TOPRIGHT', 0, Pixel.Scale(2))
	dropdown:Show()
end

function SearchResults.Hide()
	if dropdown then dropdown:Hide() end
end

local function FindLabel(frame, text, depth)
	depth = depth or 0
	if depth > 8 then return nil end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType('FontString') and region:GetText() == text then return region end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		local found = FindLabel(child, text, depth + 1)
		if found then return found end
	end
end

local function ClearHighlight()
	if pulseAnim then pulseAnim:SetScript('OnUpdate', nil) end
	if highlight then
		highlight.bar:Hide()
		highlight.bar:SetParent(nil)
		highlight.target:SetTextColor(highlight.origR, highlight.origG, highlight.origB)
		highlight = nil
	end
end

local function ScrollIntoView(scroll, searchChild, target)
	local scrollFrame = scroll.scrollFrame
	local targetTop, targetBottom = target:GetTop(), target:GetBottom()
	local viewTop, viewBottom = scrollFrame:GetTop(), scrollFrame:GetBottom()
	if not (targetTop and targetBottom and viewTop and viewBottom) then return end
	local visible = targetTop <= viewTop and targetBottom >= viewBottom
	local nearTop = targetTop <= viewTop and targetTop >= (viewTop - (viewTop - viewBottom) * 0.4)
	if visible and nearTop then return end

	local childTop = searchChild:GetTop() or 0
	local viewHeight = scrollFrame:GetHeight()
	local goal = math.max(0, math.min(
		childTop - targetTop - (viewHeight * 0.3),
		math.max(0, searchChild:GetHeight() - viewHeight)
	))
	local start = scrollFrame:GetVerticalScroll()
	local elapsedTime = 0
	if not scrollAnim then scrollAnim = CreateFrame('Frame') end
	scrollAnim:SetScript('OnUpdate', BUI.Profiler.Wrap('Utility.SearchResults scroll anim', function(self, deltaTime)
		elapsedTime = elapsedTime + deltaTime
		local progress = math.min(elapsedTime / 0.3, 1)
		progress = 1 - (1 - progress) * (1 - progress)
		scrollFrame:SetVerticalScroll(start + (goal - start) * progress)
		scroll:UpdateScroll()
		if elapsedTime >= 0.3 then
			scrollFrame:SetVerticalScroll(goal)
			scroll:UpdateScroll()
			self:SetScript('OnUpdate', nil)
		end
	end))
end

local function HighlightSetting(pageFrame, result)
	local page = pageFrame._page
	if not page then return end
	local tab = page.tabContents[result.tab or 1]
	if not tab or not tab.child then return end
	local target = FindLabel(tab.child, result.label)
	if not target then return end

	ScrollIntoView(tab.scroll, tab.child, target)
	ClearHighlight()

	local container = target:GetParent()
	local bar = CreateFrame('Frame', nil, container)
	bar:SetPoint('LEFT', container, 'LEFT', Pixel.Scale(-4), 0)
	bar:SetPoint('RIGHT', container, 'RIGHT', Pixel.Scale(4), 0)
	bar:SetPoint('TOP', target, 'TOP', 0, Pixel.Scale(8))
	bar:SetPoint('BOTTOM', target, 'BOTTOM', 0, Pixel.Scale(-8))
	bar:SetFrameLevel(container:GetFrameLevel() + 100)
	local texture = bar:CreateTexture(nil, 'OVERLAY')
	texture:SetAllPoints()
	texture:SetColorTexture(unpack(TIFFANY))
	bar:SetAlpha(0.6)

	local originalRed, originalGreen, originalBlue = target:GetTextColor()
	target:SetTextColor(unpack(TIFFANY))

	local elapsed = 0
	if not pulseAnim then pulseAnim = CreateFrame('Frame') end
	pulseAnim:SetScript('OnUpdate', BUI.Profiler.Wrap('Utility.SearchResults pulse anim', function(self, deltaTime)
		elapsed = elapsed + deltaTime
		if elapsed < 4 then
			bar:SetAlpha(0.4 + 0.2 * math.sin(elapsed * 8))
		elseif elapsed < 5 then
			bar:SetAlpha(0.6 * (1 - (elapsed - 4)))
		else
			ClearHighlight()
			self:SetScript('OnUpdate', nil)
		end
	end))

	highlight = { bar = bar, target = target, origR = originalRed, origG = originalGreen, origB = originalBlue }
end

function SearchResults.NavigateTo(result)
	local pageEngine = BUI.PageEngine
	local pageIndex
	for orderIndex, pageID in ipairs(pageEngine.pageOrder) do
		if pageID == result.page then pageIndex = orderIndex; break end
	end
	if not pageIndex then return end

	pageEngine.ShowPage(pageIndex)

	After('Utility.SearchResults navigate', 0, function()
		local pageFrame = pageEngine.pages[result.page].frame
		if not pageFrame then return end

		if result.sidebar and pageFrame._selectModule then
			pageFrame._selectModule(result.sidebar)
		else
			local page = pageFrame._page
			if page and result.tab then
				page:SetTab(result.tab)
				local tab = page.tabContents[result.tab]
				if tab and tab.scroll then
					tab.scroll.scrollFrame:SetVerticalScroll(0)
					tab.scroll:UpdateScroll()
				end
			end
		end
		After('Utility.SearchResults highlight setting', 0.15, function()
			HighlightSetting(pageFrame, result)
		end)
	end)
end
