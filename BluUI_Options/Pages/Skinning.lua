local BUI = BluUI

local max, min = math.max, math.min

local BUILib = BluUI.BUILibClient
local Controls = BUILib.Controls
local Layout = BUILib.Layout
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

	local panel = Widget.New(overlay, 'Frame', nil, {bg = Colors.bg.dark, border = Colors.border.default, size = {PANEL_WIDTH, PANEL_HEIGHT}}).frame
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
	BUI.Tools.SetColorTex(headerRule, unpack(Colors.border.default))

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
	BUI.Tools.SetColorTex(footerRule, unpack(Colors.border.default))

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

	function content:Refresh()
		if self._isRefreshing then return end
		self._isRefreshing = true
		local totals = CountFields(self.child, { sections = 0, fields = 0 })
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

	local previousStyle = BUILib.SetCardStyle('datasheet')
	info.buildSettings(content, tabIndex)
	BUILib.SetCardStyle(previousStyle)
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
	if info and info.buildSettings then
		OpenSkinSettings(id, info, UIParent)
	end
end

function BUI.SkinningPage.BuildTab(tab)
	local PageKit = BUILib.PageKit

	local cards = {}
	local unlockToggles = {}

	local function SyncUnlockToggles()
		local registryNow = BUI.Skinning.GetSkinRegistry()
		for id, toggle in pairs(unlockToggles) do toggle:SetValue(registryNow[id].unlock.get()) end
	end

	local function SyncAllCards()
		for id, rowFrame in pairs(cards) do
			rowFrame:SetValue(BUI.Skinning.IsSkinEnabled(id))
		end
	end

	do
		local MoveFrames = BUI.MoveFrames
		local moveConfig = MoveFrames.GetConfig()
		Layout.Section(tab, 'Movable Blizzard Frames', 'Click and hold on a Blizzard window to drag it.')
		local moveGrid = PageKit.RowGrid(tab)

		if MoveFrames.blockedBy then
			moveGrid:Add({
				spanFull = true,
				title = 'Handled by ' .. MoveFrames.blockedBy,
				description = MoveFrames.blockedBy .. ' is loaded, so BluUI leaves Blizzard frame moving to it.',
				plain = true,
				accessories = function() return {} end,
			})
		else
			moveGrid:Add({
				title = 'Enable',
				description = 'Drag Blizzard windows by clicking and holding on them.',
				checked = moveConfig.enabled,
				callback = function(enabled) MoveFrames.SetEnabled(enabled) end,
			})
			moveGrid:Add({
				title = 'Position',
				description = 'What happens to a window after you move it.',
				controlWidth = 180,
				control = function(row)
					return Controls.Dropdown(row, nil, {
						{ value = 'remember', text = 'Remember' },
						{ value = 'session',  text = 'Keep until reload' },
						{ value = 'reset',    text = 'Reset when closed' },
					}, moveConfig.positionMode, function(value)
						moveConfig.positionMode = value
					end, nil, 170)
				end,
			})
			moveGrid:Add({
				spanFull = true,
				title = 'Saved Positions',
				description = 'Put every window back where Blizzard puts it.',
				plain = true,
				accessoryWidth = 160,
				accessories = function(row)
					return { Controls.Button(row, 'Reset Positions', 150, function()
						MoveFrames.ResetPositions()
						BUI.Print('Blizzard frame positions reset.')
					end) }
				end,
			})
		end
		moveGrid:Flush()
	end

	Layout.Section(tab, 'Controls')
	local controlGrid = PageKit.RowGrid(tab)

	controlGrid:Add({
		spanFull = true,
		title = 'All Skins',
		description = 'Enable or disable every skin at once.',
		plain = true,
		accessoryWidth = 290,
		accessories = function(row)
			local enableButton = Controls.Button(row, 'Enable All', 120, function()
				BUI.Skinning.SetAllSkinsEnabled(true)
				SyncAllCards()
			end)
			local disableButton = Controls.Button(row, 'Disable All', 120, function()
				BUI.Skinning.SetAllSkinsEnabled(false)
				SyncAllCards()
			end)
			return { disableButton, enableButton }
		end,
	})
	controlGrid:Flush()

	local registry, order = BUI.Skinning.GetSkinRegistry()

	Layout.Section(tab, 'Skins', 'Hover a name for what it covers. Skins added in an update start off and are marked NEW.')
	local columns = 3
	local gap = 10
	local grid = PageKit.CheckGrid(tab, { columns = columns, gap = gap, rowHeight = 26 })

	for _, id in ipairs(order) do
		local info = registry[id]
		local label = BUI.Skinning.IsSkinNew(id) and (info.name .. '  (NEW)') or info.name
		local cell = grid:Add(label, BUI.Skinning.IsSkinEnabled(id), function(enabled)
			BUI.Skinning.SetSkinEnabled(id, enabled)
			if not enabled and (id == 'chat' or id == 'objectivetracker') then
				BUI.Modals.Confirm({
					title = 'Reload Recommended',
					message = info.name .. ' skin is now off, but some of its hooks only release on an interface reload.\n\nReload now for a 100% default ' .. info.name .. '?',
					confirmText = 'Reload Now', cancelText = 'Later',
					onConfirm = function() BUI.Reload() end,
				})
			end
		end, info.description)
		cards[id] = cell
		local cellFrame = cell.frame
		local lastFrame = cellFrame
		if info.unlock then
			local eye = Controls.IconToggle(cellFrame, info.unlock.get(), function(value)
				info.unlock.set(value)
			end, { texture = BUILib.GetLibMedia('eye'), size = 16, tooltip = info.unlock.tooltip or 'Unlock position' })
			unlockToggles[id] = eye
			local eyeFrame = eye.frame
			eyeFrame:SetPoint('LEFT', lastFrame, 'RIGHT', 4, 0)
			lastFrame = eyeFrame
		end
		if info.buildSettings then
			local cog = Controls.Icon(cellFrame, {
				texture = BUILib.GetLibMedia('cog'),
				size = 16,
				tooltip = 'Settings',
				onClick = function() OpenSkinSettings(id, info) end,
			})
			local cogFrame = cog.frame
			cogFrame:SetPoint('LEFT', lastFrame, 'RIGHT', 2, 0)
		end
	end

	local windowFrame = BUI.PageEngine.frame
	if not windowFrame._buiSkinUnlockHooked then
		windowFrame._buiSkinUnlockHooked = true
		windowFrame:HookScript('OnHide', function()
			for id, info in pairs(registry) do
				if info.unlock and info.unlock.get() then info.unlock.set(false) end
			end
			SyncUnlockToggles()
		end)
		windowFrame:HookScript('OnShow', SyncUnlockToggles)
	end
end
