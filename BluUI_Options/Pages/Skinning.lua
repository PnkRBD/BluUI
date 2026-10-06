local BUI = BluUI

local max, min = math.max, math.min

local BUILib = BluUI.BUILibClient
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local Colors = BUILib.Colors
local BLANK = BUI.C.FALLBACK_TEXTURE
local FONT = BUILib.Font
local Pixel = BUI.Pixel

local activeSettingsPanel = nil
local selectedSettingsTab = {}

local function OpenSkinSettings(id, info, parentOverride, savedScroll)
	if activeSettingsPanel then
		activeSettingsPanel:Hide()
		activeSettingsPanel = nil
	end

	local PANEL_WIDTH = info.settingsWidth or 520
	local PANEL_HEIGHT = info.settingsHeight or 620
	local PADDING = 16
	local TITLE_HEIGHT = 48
	local FOOTER_HEIGHT = 44
	local NARROW_FONT = 'Interface\\AddOns\\BluUI\\Media\\Fonts\\PTSansNarrow.ttf'
	local tabs = info.settingsTabs
	local tabIndex = tabs and (selectedSettingsTab[id] or 1) or nil
	local headerHeight = TITLE_HEIGHT

	local appFrame = parentOverride or BUI.PageEngine.frame
	local overlay = CreateFrame('Frame', nil, appFrame, 'BackdropTemplate')
	overlay:SetAllPoints(appFrame)
	overlay:SetFrameStrata(parentOverride and 'FULLSCREEN_DIALOG' or appFrame:GetFrameStrata())
	overlay:SetFrameLevel(appFrame:GetFrameLevel() + 50)
	overlay:SetBackdrop({ bgFile = BLANK })
	overlay:SetBackdropColor(0, 0, 0, 0.55)
	overlay:EnableMouse(true)
	overlay:EnableKeyboard(true)

	local panel = Widget.New(overlay, 'Frame', nil, {bg = { BUI.ThemeColor('page') }, border = { BUI.ThemeColor('edge') }, size = {PANEL_WIDTH, PANEL_HEIGHT}}).frame
	panel:SetPoint('CENTER', overlay, 'CENTER', 0, 0)
	panel:SetFrameLevel(overlay:GetFrameLevel() + 5)
	panel:SetClampedToScreen(true)

	activeSettingsPanel = overlay
	if info.onCloseSettings then
		overlay:HookScript('OnHide', function() info.onCloseSettings() end)
	end

	local activeClient = BUILib.GetActiveClient()
	local prevStrata, prevLevel, prevParent = activeClient.popupStrata, activeClient.popupLevel, activeClient.popupParent
	BUILib.SetPopupParent(panel)
	overlay:HookScript('OnHide', function()
		activeClient.popupStrata, activeClient.popupLevel, activeClient.popupParent = prevStrata, prevLevel, prevParent
	end)

	local function Close()
		overlay:Hide()
		overlay:SetParent(nil)
		activeSettingsPanel = nil
	end

	overlay:SetScript('OnMouseDown', function(_, mouseButton)
		if mouseButton == 'LeftButton' then Close() end
	end)
	overlay:SetScript('OnKeyDown', function(_, key)
		if key == 'ESCAPE' then
			overlay:SetPropagateKeyboardInput(false)
			Close()
		else
			overlay:SetPropagateKeyboardInput(true)
		end
	end)

	panel:EnableMouse(true)

	local title = panel:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(title, 14, FONT, '')
	title:SetPoint('TOPLEFT', Pixel.Scale(PADDING), Pixel.Scale(-PADDING))
	title:SetText(info.name)
	title:SetTextColor(1, 1, 1, 1)

	local meta = panel:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(meta, 10, NARROW_FONT, '')
	meta:SetPoint('TOPRIGHT', Pixel.Scale(-40), Pixel.Scale(-19))
	meta:SetText('SKIN SETTINGS')
	meta:SetTextColor(unpack(Colors.text.muted))

	local headerRule = panel:CreateTexture(nil, 'ARTWORK')
	headerRule:SetHeight(Pixel.PixelSize(1))
	headerRule:SetPoint('TOPLEFT', 0, Pixel.Scale(-(TITLE_HEIGHT - 2)))
	headerRule:SetPoint('TOPRIGHT', 0, Pixel.Scale(-(TITLE_HEIGHT - 2)))
	BUI.Tools.SetColorTex(headerRule, BUI.ThemeColor('cardEdge'))

	if tabs then
		local tabBar = Controls.TabLineBar(panel, tabs, tabIndex, function(index)
			selectedSettingsTab[id] = index
			Close()
			OpenSkinSettings(id, info, parentOverride)
		end, PANEL_WIDTH - PADDING * 2)
		local barFrame = Widget.Unwrap(tabBar)
		barFrame:SetPoint('TOPLEFT', Pixel.Scale(PADDING), Pixel.Scale(-TITLE_HEIGHT))
		headerHeight = TITLE_HEIGHT + barFrame:GetHeight() + 4
	end

	local closeButton = Controls.Icon(panel, { preset = 'close', size = 20, onClick = Close })
	closeButton:SetPoint('TOPRIGHT', Pixel.Scale(-10), Pixel.Scale(-12))
	closeButton:SetFrameLevel(panel:GetFrameLevel() + 5)

	local scrollArea = CreateFrame('Frame', nil, panel)
	scrollArea:SetPoint('TOPLEFT', 0, Pixel.Scale(-headerHeight - 1))
	scrollArea:SetPoint('BOTTOMRIGHT', 0, Pixel.Scale(FOOTER_HEIGHT))

	local footerRule = panel:CreateTexture(nil, 'ARTWORK')
	footerRule:SetHeight(Pixel.PixelSize(1))
	footerRule:SetPoint('BOTTOMLEFT', 0, Pixel.Scale(FOOTER_HEIGHT))
	footerRule:SetPoint('BOTTOMRIGHT', 0, Pixel.Scale(FOOTER_HEIGHT))
	BUI.Tools.SetColorTex(footerRule, BUI.ThemeColor('cardEdge'))

	local summary = panel:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(summary, 10, NARROW_FONT, '')
	summary:SetPoint('BOTTOMLEFT', Pixel.Scale(PADDING), Pixel.Scale(17))
	summary:SetTextColor(unpack(Colors.text.muted))

	local done = BUILib.Modals.CreateButton(panel, 'Done', nil, 90)
	done:SetPoint('BOTTOMRIGHT', Pixel.Scale(-PADDING), Pixel.Scale(8))
	done:SetScript('OnClick', Close)

	local contentWidth = PANEL_WIDTH - 14
	local scrollContainer = Widget.Unwrap(Controls.ScrollFrame(scrollArea, nil, nil, nil, Pixel.Scale(contentWidth)))
	scrollContainer:ClearAllPoints()
	scrollContainer:SetPoint('TOPLEFT', -4, 4)
	scrollContainer:SetPoint('BOTTOMRIGHT', 0, Pixel.Scale(8) - 4)
	local scrollFrame = scrollContainer.scrollFrame
	local scrollChild = scrollContainer.scrollChild

	local contentWrapper = CreateFrame('Frame', nil, scrollChild)
	contentWrapper:SetPoint('TOPLEFT', 0, 0)
	contentWrapper:SetWidth(Pixel.Scale(contentWidth))
	contentWrapper:SetHeight(Pixel.Scale(100))

	local topAnchor = CreateFrame('Frame', nil, contentWrapper)
	topAnchor:SetPoint('TOPLEFT', 0, 0)
	topAnchor:SetPoint('TOPRIGHT', 0, 0)
	topAnchor:SetHeight(Pixel.PixelSize(1))

	local content = {
		frame = scrollArea,
		child = contentWrapper,
		scroll = scrollFrame,
		scrollChild = scrollChild,
		y = 0,
		width = contentWidth,
		contentWidth = contentWidth,
		lastControl = topAnchor,
		lastMargin = 0,
	}

	function content:AddY(amount)
		self.y = self.y - amount
		return self.y
	end

	function content:GetY()
		return self.y
	end

	function content:SetLast(control, margin)
		self.lastControl = control
		self.lastMargin = margin or 0
	end

	function content:GetAnchor(topMargin)
		topMargin = topMargin or 10
		if self.lastControl then
			if self.lastControl == topAnchor then
				return self.lastControl, 0
			end
			return self.lastControl, -(topMargin + self.lastMargin)
		end
		return nil, 0
	end

	function content:GetContentHeight()
		local contentHeight = math.abs(self.y)
		if contentHeight < 20 then contentHeight = 40 end
		return contentHeight
	end

	local function CountFields(frame, totals)
		for _, child in ipairs({ frame:GetChildren() }) do
			if child.__datasheet then
				totals.sections = totals.sections + 1
				totals.fields = totals.fields + (child.__fieldCount or 0)
			else
				CountFields(child, totals)
			end
		end
		return totals
	end

	local function CountBoardRows(boards)
		local totals = { sections = #boards, fields = 0 }
		for _, board in ipairs(boards) do totals.fields = totals.fields + #board.rows end
		return totals
	end

	function content:Refresh()
		if self._isRefreshing then return end
		self._isRefreshing = true
		local totals = self.boards and CountBoardRows(self.boards) or CountFields(self.child, { sections = 0, fields = 0 })
		summary:SetText(('%d %s · %d %s'):format(totals.sections, totals.sections == 1 and 'section' or 'sections', totals.fields, totals.fields == 1 and 'field' or 'fields'))
		local contentHeight = self:GetContentHeight()
		local top = self.child:GetTop()
		if top then
			for _, child in ipairs({self.child:GetChildren()}) do
				if child:IsShown() then
					local childBottom = child:GetBottom()
					if childBottom then
						local distance = top - childBottom
						if distance > contentHeight then contentHeight = distance end
					end
				end
			end
		end
		contentHeight = contentHeight + PADDING
		self.child:SetHeight(contentHeight)
		self.scrollChild:SetHeight(contentHeight)
		self._isRefreshing = false
	end

	content.Close = Close
	content.Rebuild = function()
		local keepScroll = scrollFrame:GetVerticalScroll()
		Close()
		OpenSkinSettings(id, info, parentOverride, keepScroll)
	end
	content.overlay = overlay
	content.dialog = panel

	if info.buildBoards then
		local host = CreateFrame('Frame', nil, contentWrapper)
		host:SetPoint('TOPLEFT', Pixel.Scale(PADDING), 0)
		local hostWidth = Pixel.Scale(contentWidth - PADDING * 2)
		host:SetWidth(hostWidth)
		content.boards = info.buildBoards(BUILib.Layout.TableKit(BUI.PageEngine.window), host, hostWidth, content)
		local y = 0
		for _, board in ipairs(content.boards) do y = board:Layout(y, '') end
		host:SetHeight(y)
		content.y = -y
	else
		local previousStyle = BUILib.SetCardStyle('datasheet')
		info.buildSettings(content, tabIndex)
		BUILib.SetCardStyle(previousStyle)
	end
	overlay:Show()
	C_Timer.After(0, function()
		if not overlay:IsShown() then return end
		content:Refresh()
		if savedScroll and savedScroll > 0 then
			local maxScroll = max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
			scrollFrame:SetVerticalScroll(min(savedScroll, maxScroll))
			scrollContainer:UpdateScroll()
		end
	end)
end

BUI.SkinningPage = {}

function BUI.SkinningPage.OpenSkinSettings(id)
	local info = BUI.Skinning.GetSkinRegistry()[id]
	if info.window then
		BUI.OptionsWindow.Open(info.window)
	elseif info.page then
		BUI.PageEngine.Show()
		BUI.PageEngine.NavigateToID(info.page)
	elseif info.buildBoards then
		BUI.PageEngine.Show()
		if BUI.PageEngine.window then OpenSkinSettings(id, info) end
	elseif info.buildSettings then
		OpenSkinSettings(id, info, UIParent)
	end
end

local ICON_SIZE = 22
local ICON_ROOM = 24
local DROPDOWN_WIDTH = 170
local BUTTON_ROOM = 150
local RELOAD_SKINS = { chat = true, objectivetracker = true }
local POSITION_MODES = {
	{ value = 'remember', text = 'Remember' },
	{ value = 'session', text = 'Keep until reload' },
	{ value = 'reset', text = 'Reset when closed' },
}

local function Window()
	return BUI.PageEngine.window
end

local function CellIcon(ui, cell, glyph, tip, onClick, active)
	local window = Window()
	local button = CreateFrame('Button', nil, cell)
	button:SetSize(ICON_SIZE, ICON_SIZE)
	local icon = ui.Glyph(button, glyph, 13, 'muted')
	icon:SetPoint('CENTER')
	local function Paint() window:Paint(icon, active and active() and 'accent' or 'muted') end
	window:Bind(button, Paint)
	button:SetScript('OnEnter', function(self)
		window:Paint(icon, 'text')
		Widget.ShowTip(self, tip)
	end)
	button:SetScript('OnLeave', function()
		Paint()
		Widget.HideTip()
	end)
	button:SetScript('OnClick', function()
		onClick()
		Paint()
	end)
	return button
end

local function FramesBoard(ui, parent, width)
	local MoveFrames = BUI.MoveFrames
	local board = ui.Board(parent, width, { title = 'Blizzard frames', description = 'Click and hold on a Blizzard window to drag it, and choose what happens to it once you let go.' })
	if MoveFrames.blockedBy then
		board:AddRow('Handled by ' .. MoveFrames.blockedBy, MoveFrames.blockedBy .. ' is loaded, so BluUI leaves frame moving to it')
		return board
	end
	local config = MoveFrames.GetConfig()
	board:AddSwitch('Movable frames', function() return config.enabled end, function(enabled) MoveFrames.SetEnabled(enabled) end, 'Drag Blizzard windows by clicking and holding on them.')
	local mode = board:AddRow('After a move', 'What happens to a window once you let go, toasts and popups always keep their spot', DROPDOWN_WIDTH)
	local dropdown = ui.Dropdown(mode, DROPDOWN_WIDTH, function()
		local items = {}
		for _, entry in ipairs(POSITION_MODES) do
			items[#items + 1] = { text = entry.text, checked = config.positionMode == entry.value, callback = function()
				config.positionMode = entry.value
				Window():Repaint()
			end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(mode, function()
		for _, entry in ipairs(POSITION_MODES) do
			if entry.value == config.positionMode then dropdown.label:SetText(entry.text) end
		end
	end)
	local saved = board:AddRow('Saved positions', 'Put every window back where Blizzard puts it', BUTTON_ROOM)
	ui.Button(saved, 'Reset positions', 'control', function()
		MoveFrames.ResetPositions()
		BUI.Print('Blizzard frame positions reset.')
	end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
	return board
end

local function ConfirmReload(info)
	BUILib.Modals.Confirm({
		parent = Window().frame,
		title = 'Reload recommended',
		message = info.name .. ' skin is now off, but some of its hooks only release on an interface reload.\n\nReload now for a 100% default ' .. info.name .. '?',
		confirmText = 'Reload now', cancelText = 'Later',
		onConfirm = ReloadUI,
	})
end
BUI.SkinningPage.ConfirmReload = ConfirmReload

local function AllSkins(order, enabled)
	for _, id in ipairs(order) do
		if (BUI.Skinning.IsSkinEnabled(id) and true or false) ~= enabled then return false end
	end
	return true
end

local function SkinsBoard(ui, parent, width)
	local Skin = BUI.Skinning
	local registry, order = Skin.GetSkinRegistry()
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Skins',
		description = 'Hover a name for what it covers. Skins added in an update start off and are marked new.',
		buttons = {
			{ text = 'All off', icon = 'check', active = function() return AllSkins(order, false) end, onClick = function()
				Skin.SetAllSkinsEnabled(false)
				Window():Repaint()
			end },
			{ text = 'All on', icon = 'check', active = function() return AllSkins(order, true) end, onClick = function()
				Skin.SetAllSkinsEnabled(true)
				Window():Repaint()
			end },
		},
	})
	for _, id in ipairs(order) do
		local info = registry[id]
		local tag
		local icons = (info.unlock and 1 or 0) + ((info.window or info.page or info.buildSettings or info.buildBoards) and 1 or 0)
		local _, cell = board:AddSwitch(info.name, function() return Skin.IsSkinEnabled(id) end, function(enabled)
			Skin.SetSkinEnabled(id, enabled)
			Window():Repaint()
			if tag then tag:Hide() end
			if not enabled and RELOAD_SKINS[id] then ConfirmReload(info) end
		end, info.description, icons * ICON_ROOM)
		if Skin.IsSkinNew(id) then
			tag = ui.Text(cell, 'NEW', 9, 'accent')
			tag:SetPoint('LEFT', cell.label, 'LEFT', math.ceil(cell.label:GetStringWidth()) + 6, 0)
		end
		local anchor
		if info.window then
			anchor = CellIcon(ui, cell, 'cog', 'Settings', function() BUI.OptionsWindow.Open(info.window) end)
			anchor:SetPoint('RIGHT', -4, 0)
		elseif info.page then
			anchor = CellIcon(ui, cell, 'cog', 'Settings', function() BUI.PageEngine.NavigateToID(info.page) end)
			anchor:SetPoint('RIGHT', -4, 0)
		elseif info.buildSettings or info.buildBoards then
			anchor = CellIcon(ui, cell, 'cog', 'Settings', function() OpenSkinSettings(id, info) end)
			anchor:SetPoint('RIGHT', -4, 0)
		end
		if info.unlock then
			local eye = CellIcon(ui, cell, 'eye', info.unlock.tooltip or 'Unlock position', function() info.unlock.set(not info.unlock.get()) end, info.unlock.get)
			if anchor then eye:SetPoint('RIGHT', anchor, 'LEFT', 0, 0) else eye:SetPoint('RIGHT', -4, 0) end
		end
	end

	local windowFrame = Window().frame
	if not windowFrame._buiSkinUnlockHooked then
		windowFrame._buiSkinUnlockHooked = true
		windowFrame:HookScript('OnHide', function()
			for _, info in pairs(registry) do
				if info.unlock and info.unlock.get() then info.unlock.set(false) end
			end
			Window():Repaint()
		end)
	end
	return board
end

function BUI.SkinningPage.Sections(ui, _, parent, width)
	return { FramesBoard(ui, parent, width), SkinsBoard(ui, parent, width) }
end
