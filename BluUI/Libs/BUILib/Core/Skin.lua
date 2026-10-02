local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end

local Widget = BUILib.Widget
local Theme = BUILib.Theme

local select = select
local max = math.max
local floor = math.floor

BUILib.Skin = BUILib.Skin or {}
local Skin = BUILib.Skin

function Skin.StripTextures(frame)
	if not frame or not frame.GetRegions then return end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region and region.IsObjectType and region:IsObjectType('Texture') then
			region:SetTexture(nil)
			region:SetAtlas(nil)
		end
	end
	if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
	if frame.Border then frame.Border:SetAlpha(0) end
	if frame.Bg then frame.Bg:SetAlpha(0) end
	if frame.Bg2 then frame.Bg2:SetAlpha(0) end
end

local HIDDEN_PARENT = CreateFrame('Frame')
HIDDEN_PARENT:Hide()
local CLEAR_TEXTURE = BUILib.GetLibMedia('blank')
local STATE_SETTERS = { 'SetNormalTexture', 'SetPushedTexture', 'SetHighlightTexture', 'SetDisabledTexture' }

function Skin.StripButton(button)
	if not button then return end
	if CLEAR_TEXTURE then
		for setterIndex = 1, #STATE_SETTERS do
			local setter = button[STATE_SETTERS[setterIndex]]
			if setter then setter(button, CLEAR_TEXTURE) end
		end
	end
	if button.GetRegions then
		for regionIndex = 1, select('#', button:GetRegions()) do
			local region = select(regionIndex, button:GetRegions())
			if region and not region.__buiSkin and region.IsObjectType and region:IsObjectType('Texture') then
				region:SetTexture(nil)
				region:SetAtlas(nil)
				region:Hide()
				region:SetAlpha(0)
			end
		end
	end
	local nineSlice = button.NineSlice
	if nineSlice and not nineSlice.__buiParked then
		nineSlice.__buiParked = true
		nineSlice:Hide()
		if nineSlice.SetParent then nineSlice:SetParent(HIDDEN_PARENT) end
	end
end

function Skin.Backdrop(frame, options)
	options = options or {}
	if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
	frame:SetBackdrop(Widget.BACKDROP)
	local backgroundColor = options.bg or Theme.bg.dark
	local border = options.border or Theme.border.light
	frame:SetBackdropColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4] or 1)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
	return frame
end

function Skin.ChildBackdrop(frame, options)
	local backdrop = frame._buiBackdrop
	if not backdrop then
		options = options or {}
		local inset = options.inset or 1
		local parent = frame:GetParent() or UIParent
		backdrop = Widget.New(parent, 'Frame', nil, { bg = options.bg or Theme.bg.dark, border = options.border or Theme.border.light }).frame
		backdrop:SetScript('OnSizeChanged', nil)
		backdrop:SetPoint('TOPLEFT', frame, 'TOPLEFT', inset, -inset)
		backdrop:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -inset, inset)
		frame._buiBackdrop = backdrop
		frame:HookScript('OnHide', function() backdrop:Hide() end)
	end
	local strata, level = frame:GetFrameStrata(), frame:GetFrameLevel()
	if issecretvalue and (issecretvalue(strata) or issecretvalue(level)) then
		C_Timer.After(0, function()
			local resolvedStrata, resolvedLevel = frame:GetFrameStrata(), frame:GetFrameLevel()
			if issecretvalue(resolvedStrata) or issecretvalue(resolvedLevel) then return end
			backdrop:SetFrameStrata(resolvedStrata)
			backdrop:SetFrameLevel(max(0, resolvedLevel - 1))
		end)
	else
		backdrop:SetFrameStrata(strata)
		backdrop:SetFrameLevel(max(0, level - 1))
	end
	backdrop:Show()
	return backdrop
end

function Skin.Button(button, options)
	if not button or button._buiSkinned then return end
	button._buiSkinned = true
	options = options or {}
	local border = options.border or Theme.border.default
	Skin.StripTextures(button)
	Skin.Backdrop(button, { bg = options.bg or Theme.bg.light, border = border })
	button:HookScript('OnEnter', function(self) self:SetBackdropBorderColor(Theme.GetAccent()) end)
	button:HookScript('OnLeave', function(self) self:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end)
end

local aligners = setmetatable({}, { __mode = 'k' })
local alignQueued = false

function Skin.PixelRect(region)
	local left, right, top, bottom = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
	if not left or not right or not top or not bottom then return nil end
	if issecretvalue and (issecretvalue(left) or issecretvalue(right) or issecretvalue(top) or issecretvalue(bottom)) then return nil end
	return left, right, top, bottom, PixelUtil.GetPixelToUIUnitFactor() / region:GetEffectiveScale()
end

local function Align(entry, force)
	local left, right, top, bottom, pixel = Skin.PixelRect(entry.region)
	if not left then return end
	local last = entry.last
	if not force and last[1] == left and last[2] == right and last[3] == top and last[4] == bottom and last[5] == pixel then return end
	last[1], last[2], last[3], last[4], last[5] = left, right, top, bottom, pixel
	entry.apply(left, right, top, bottom, pixel)
end

local function AlignHost(host)
	local entries = aligners[host]
	if not entries then return end
	for entryIndex = 1, #entries do Align(entries[entryIndex]) end
end

local function AlignAll()
	alignQueued = false
	for host in pairs(aligners) do
		if host:IsVisible() then AlignHost(host) end
	end
end

function Skin.QueuePixelAlign()
	if alignQueued then return end
	alignQueued = true
	C_Timer.After(0, AlignAll)
end

local function OnHostSizeChanged(host)
	AlignHost(host)
	Skin.QueuePixelAlign()
end

function Skin.PixelAlign(host, region, apply)
	local entries = aligners[host]
	if not entries then
		entries = {}
		aligners[host] = entries
		host:HookScript('OnShow', AlignHost)
		host:HookScript('OnSizeChanged', OnHostSizeChanged)
		hooksecurefunc(host, 'SetPoint', Skin.QueuePixelAlign)
	end
	local entry = { region = region, apply = apply, last = {} }
	entries[#entries + 1] = entry
	Align(entry, true)
	Skin.QueuePixelAlign()
	return entry
end

function Skin.Realign(entry)
	if entry then Align(entry, true) end
end

local scaleWatcher = CreateFrame('Frame')
scaleWatcher:RegisterEvent('UI_SCALE_CHANGED')
scaleWatcher:RegisterEvent('DISPLAY_SIZE_CHANGED')
scaleWatcher:SetScript('OnEvent', Skin.QueuePixelAlign)

local function AlignBox(owner, fill, top, bottom, left, right, insets, thickness)
	return function(frameLeft, frameRight, frameTop, frameBottom, pixel)
		local size = max(1, floor((thickness or 1) / pixel + 0.5)) * pixel
		local offsetLeft = Widget.SnapX(frameLeft + insets.left, pixel) - frameLeft
		local offsetRight = frameRight - Widget.SnapX(frameRight - insets.right, pixel)
		local offsetTop = frameTop - Widget.SnapY(frameTop - insets.top + (insets.raise or 0), pixel)
		local offsetBottom = Widget.SnapY(frameBottom + insets.bottom, pixel) - frameBottom
		if fill then
			fill:SetPoint('TOPLEFT', owner, 'TOPLEFT', offsetLeft, -offsetTop)
			fill:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', -offsetRight, offsetBottom)
		end
		top:SetPoint('TOPLEFT', owner, 'TOPLEFT', offsetLeft, -offsetTop); top:SetPoint('TOPRIGHT', owner, 'TOPRIGHT', -offsetRight, -offsetTop)
		bottom:SetPoint('BOTTOMLEFT', owner, 'BOTTOMLEFT', offsetLeft, offsetBottom); bottom:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', -offsetRight, offsetBottom)
		left:SetPoint('TOPLEFT', owner, 'TOPLEFT', offsetLeft, -offsetTop); left:SetPoint('BOTTOMLEFT', owner, 'BOTTOMLEFT', offsetLeft, offsetBottom)
		right:SetPoint('TOPRIGHT', owner, 'TOPRIGHT', -offsetRight, -offsetTop); right:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', -offsetRight, offsetBottom)
		top:SetHeight(size)
		bottom:SetHeight(size)
		left:SetWidth(size)
		right:SetWidth(size)
	end
end

local function SizeEdges(top, bottom, left, right)
	PixelUtil.SetHeight(top, 1, 1)
	PixelUtil.SetHeight(bottom, 1, 1)
	PixelUtil.SetWidth(left, 1, 1)
	PixelUtil.SetWidth(right, 1, 1)
end

local SQUARE_INSETS = { left = 0, right = 0, top = 0, bottom = 0 }

function Skin.AlignEdges(host, fill, edges, insets, thickness)
	return Skin.PixelAlign(host, host, AlignBox(host, fill, edges[1], edges[2], edges[3], edges[4], insets or SQUARE_INSETS, thickness))
end

function Skin.PixelLine(line, reference, vertical, startInset, endInset)
	startInset, endInset = startInset or 0, endInset or 0
	return Skin.PixelAlign(line:GetParent(), reference, function(left, right, top, bottom, pixel)
		line:ClearAllPoints()
		if vertical then
			local edge = Widget.SnapX((left + right) / 2 - pixel / 2, pixel) - left
			line:SetPoint('TOPLEFT', reference, 'TOPLEFT', edge, Widget.SnapY(top - startInset, pixel) - top)
			line:SetPoint('BOTTOMLEFT', reference, 'BOTTOMLEFT', edge, Widget.SnapY(bottom + endInset, pixel) - bottom)
			line:SetWidth(pixel)
		else
			local edge = Widget.SnapY((top + bottom) / 2 + pixel / 2, pixel) - top
			line:SetPoint('TOPLEFT', reference, 'TOPLEFT', Widget.SnapX(left + startInset, pixel) - left, edge)
			line:SetPoint('TOPRIGHT', reference, 'TOPRIGHT', Widget.SnapX(right - endInset, pixel) - right, edge)
			line:SetHeight(pixel)
		end
	end)
end

function Skin.SquarePanel(frame, options)
	if frame._buiSquare then return frame._buiSquare end
	options = options or {}
	local backgroundColor = options.bg or Theme.bg.dark
	local border = options.border or Theme.border.light
	local fill = frame:CreateTexture(nil, 'BACKGROUND')
	fill:SetAllPoints(frame)
	fill:SetColorTexture(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4] or 1)
	local function CreateEdge()
		local edgeTexture = frame:CreateTexture(nil, 'BORDER')
		edgeTexture:SetColorTexture(border[1], border[2], border[3], border[4] or 1)
		return edgeTexture
	end
	local top, bottom, left, right = CreateEdge(), CreateEdge(), CreateEdge(), CreateEdge()
	top:SetPoint('TOPLEFT'); top:SetPoint('TOPRIGHT')
	bottom:SetPoint('BOTTOMLEFT'); bottom:SetPoint('BOTTOMRIGHT')
	left:SetPoint('TOPLEFT'); left:SetPoint('BOTTOMLEFT')
	right:SetPoint('TOPRIGHT'); right:SetPoint('BOTTOMRIGHT')
	SizeEdges(top, bottom, left, right)
	frame._buiSquare = { fill = fill, top = top, bottom = bottom, left = left, right = right }
	Skin.PixelAlign(frame, frame, AlignBox(frame, fill, top, bottom, left, right, SQUARE_INSETS))
	return frame._buiSquare
end


local SHELL_SUBLEVEL = -8

function Skin.SetEdgeColor(edges, color)
	for edgeIndex = 1, 4 do
		edges[edgeIndex]:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	end
end

local function ResolveInsets(inset)
	if type(inset) == 'table' then
		local base = inset.all or 0
		return inset.left or base, inset.right or base, inset.top or base, inset.bottom or base
	end
	inset = inset or 0
	return inset, inset, inset, inset
end

function Skin.Shell(frame, style, inset)
	local shell = frame._buiShell
	if shell then
		shell.fill:Show()
		for edgeIndex = 1, 4 do shell.edges[edgeIndex]:Show() end
		Skin.Realign(shell.aligner)
		return shell
	end
	local left, right, top, bottom = ResolveInsets(inset)
	local fillColor = style.fill
	local fill = frame:CreateTexture(nil, 'BACKGROUND', nil, SHELL_SUBLEVEL)
	fill.__buiSkin = true
	fill.ignoreInLayout = true
	fill:SetPoint('TOPLEFT', frame, 'TOPLEFT', left, -top)
	fill:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -right, bottom)
	fill:SetColorTexture(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
	local edges = {}
	for edgeIndex = 1, 4 do
		edges[edgeIndex] = frame:CreateTexture(nil, 'BORDER')
		edges[edgeIndex].__buiSkin = true
		edges[edgeIndex].ignoreInLayout = true
	end
	edges[1]:SetPoint('TOPLEFT', frame, 'TOPLEFT', left, -top); edges[1]:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -right, -top)
	edges[2]:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', left, bottom); edges[2]:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -right, bottom)
	edges[3]:SetPoint('TOPLEFT', frame, 'TOPLEFT', left, -top); edges[3]:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', left, bottom)
	edges[4]:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -right, -top); edges[4]:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -right, bottom)
	SizeEdges(edges[1], edges[2], edges[3], edges[4])
	Skin.SetEdgeColor(edges, style.edge)
	local insets = { left = left, right = right, top = top, bottom = bottom }
	shell = { fill = fill, edges = edges, inset = inset, insets = insets }
	frame._buiShell = shell
	shell.aligner = Skin.PixelAlign(frame, frame, AlignBox(frame, fill, edges[1], edges[2], edges[3], edges[4], insets))
	return shell
end

function Skin.HideShell(frame)
	local shell = frame._buiShell
	if not shell then return end
	shell.fill:Hide()
	for edgeIndex = 1, 4 do shell.edges[edgeIndex]:Hide() end
end

function Skin.SetShellEdges(frame, color)
	local shell = frame and frame._buiShell
	if shell then Skin.SetEdgeColor(shell.edges, color) end
end

function Skin.SetShellFill(frame, color)
	local shell = frame and frame._buiShell
	if shell then shell.fill:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
end

local TAB_INSET = 3
local TAB_FUSE = 1
local TAB_TEXT_PADDING = 14
local TAB_STRIP_OVERLAP = -5
local TAB_DEFAULTS = {
	restFill = { 0.03, 0.03, 0.036, 0.97 },
	hoverFill = { 0.06, 0.062, 0.07, 0.97 },
	selectedFill = { 0.075, 0.078, 0.088, 0.97 },
	restText = { 0.78, 0.78, 0.82, 1 },
	hoverText = { 0.9, 0.9, 0.93, 1 },
	disabledText = { 0.55, 0.55, 0.6, 1 },
	fontSize = 12,
}
local tabStyleCount = 0

Skin.TAB_INSET = TAB_INSET
Skin.TAB_STRIP_OVERLAP = TAB_STRIP_OVERLAP

local function TabFont(name, size, color)
	local font = CreateFont(name)
	font:SetFont(BUILib.Font, size, '')
	font:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	font:SetShadowColor(0, 0, 0, 0)
	font:SetShadowOffset(0, 0)
	return font
end

function Skin.TabStyle(overrides)
	tabStyleCount = tabStyleCount + 1
	local style = { fill = Theme.bg.dark, edge = Theme.border.light }
	for key, value in pairs(TAB_DEFAULTS) do style[key] = value end
	if overrides then
		for key, value in pairs(overrides) do style[key] = value end
	end
	local prefix = 'BUILib_Tab' .. tabStyleCount
	style.fonts = {
		rest = TabFont(prefix .. 'Rest', style.fontSize, style.restText),
		hover = TabFont(prefix .. 'Hover', style.fontSize, style.hoverText),
		selected = TabFont(prefix .. 'Selected', style.fontSize, style.hoverText),
		disabled = TabFont(prefix .. 'Disabled', style.fontSize, style.disabledText),
	}
	return style
end

local function TabFuse(tab, fused)
	local shell = tab._buiShell
	if not shell then return end
	shell.insets.raise = fused and TAB_FUSE or 0
	Skin.Realign(shell.aligner)
	shell.edges[1]:SetShown(not fused)
end

local function TabEnter(tab)
	local state = tab._buiTab
	if state and not state.selected then Skin.SetShellFill(tab, state.style.hoverFill) end
end

local function TabLeave(tab)
	local state = tab._buiTab
	if state and not state.selected then Skin.SetShellFill(tab, state.style.restFill) end
end

function Skin.SetTabSelected(tab, selected)
	local state = tab._buiTab
	if not state then return end
	local style = state.style
	state.selected = selected and true or false
	if state.selected then
		Skin.SetShellFill(tab, state.fused and style.fill or style.selectedFill)
	else
		Skin.SetShellFill(tab, style.restFill)
	end
	if state.fused then TabFuse(tab, state.selected) end
	local fonts = style.fonts
	if state.selected then
		local red, green, blue = Theme.GetAccent()
		fonts.selected:SetTextColor(red, green, blue, 1)
		tab:SetNormalFontObject(fonts.selected)
		tab:SetHighlightFontObject(fonts.selected)
		tab:SetDisabledFontObject(fonts.selected)
	else
		tab:SetNormalFontObject(fonts.rest)
		tab:SetHighlightFontObject(fonts.hover)
		tab:SetDisabledFontObject(fonts.disabled)
	end
	local text = tab.Text or (tab.GetFontString and tab:GetFontString())
	if text then
		text:ClearAllPoints()
		text:SetPoint('CENTER', tab, 'CENTER', 0, 0)
	end
end

function Skin.Tab(tab, style, fused)
	if not tab then return end
	local state = tab._buiTab
	if not state then
		Skin.StripButton(tab)
		state = { selected = false, fused = false }
		tab._buiTab = state
		tab:HookScript('OnEnter', TabEnter)
		tab:HookScript('OnLeave', TabLeave)
	end
	state.style = style
	if fused ~= nil then state.fused = fused and true or false end
	Skin.Shell(tab, style, TAB_INSET)
	Skin.SetTabSelected(tab, state.selected)
end

local function TabID(tab, tabIndex)
	local id = tab.GetID and tab:GetID()
	if not id or id == 0 then return tabIndex end
	return id
end

function Skin.LayoutTabStrip(frame, tabs, relativePoint, offsetX, offsetY)
	local previous
	for tabIndex = 1, #tabs do
		local tab = tabs[tabIndex]
		if tab._buiTab and tab:IsShown() then
			local text = tab.Text
			if text then
				text:SetWidth(0)
				local textWidth = math.ceil(text:GetStringWidth())
				tab:SetWidth(textWidth + 2 * (TAB_TEXT_PADDING + TAB_INSET))
				text:SetWidth(textWidth + 2)
			end
			tab:ClearAllPoints()
			if previous then
				tab:SetPoint('TOPLEFT', previous, 'TOPRIGHT', TAB_STRIP_OVERLAP, 0)
			else
				tab:SetPoint('TOPLEFT', frame, relativePoint or 'BOTTOMLEFT', offsetX or -TAB_INSET, offsetY or TAB_INSET)
			end
			previous = tab
		end
	end
end

function Skin.RefreshTabStrip(frame, tabs)
	local selected = frame.selectedTab
	for tabIndex = 1, #tabs do
		local tab = tabs[tabIndex]
		if tab._buiTab then Skin.SetTabSelected(tab, TabID(tab, tabIndex) == selected) end
	end
	Skin.LayoutTabStrip(frame, tabs)
end

local COUNTDOWN_WARN_SECONDS = 10
local COUNTDOWN_COLOR = { 1, 1, 1, 1 }
local COUNTDOWN_WARN_COLOR = { 1, 0.25, 0.25, 1 }

Skin.COUNTDOWN_WARN_SECONDS = COUNTDOWN_WARN_SECONDS
Skin.COUNTDOWN_GREEN_COLOR = { 0.25, 1, 0.25, 1 }

function Skin.CountdownColor(seconds, normalColor)
	local color = seconds < COUNTDOWN_WARN_SECONDS and COUNTDOWN_WARN_COLOR or normalColor or COUNTDOWN_COLOR
	return color[1], color[2], color[3], color[4]
end

function Skin.SetCountdownText(fontString, seconds, normalColor)
	fontString:SetFormattedText('%ds', seconds)
	fontString:SetTextColor(Skin.CountdownColor(seconds, normalColor))
end
