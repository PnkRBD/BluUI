local _, BUI = ...

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local HideUIPanel = HideUIPanel
local max = math.max

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local theme = BUILib.Theme
local Skin3 = BUILib.Skin
local Skin = BUI.Skinning

local MENU_BG = { 0.03, 0.03, 0.04, 0.80 }
local PANEL_BORDER = { 0.10, 0.10, 0.12, 1 }
local CARD_BORDER = { 0.12, 0.13, 0.16, 0.50 }
local ROW_GAP = 2
local GROUP_GAP = 14
local GROUP_TOL = 5
local BUTTON_HEIGHT = 28
local PANEL_PAD = 24
local SKIN_INSET = 0
local SKIN_INSET_X = 18

local function OnBUIClick()

	if not InCombatLockdown() and _G.GameMenuFrame then HideUIPanel(_G.GameMenuFrame) end
	if BUI.PageEngine and BUI.PageEngine.Toggle then BUI.PageEngine.Toggle() end
end

local function SetState(button, hovered)
	if hovered or button._accentAlways then
		local red, green, blue = theme.GetAccent()
		for edgeIndex = 1, 4 do button._edges[edgeIndex]:SetColorTexture(red, green, blue, 1) end
	else
		for edgeIndex = 1, 4 do button._edges[edgeIndex]:SetColorTexture(CARD_BORDER[1], CARD_BORDER[2], CARD_BORDER[3], CARD_BORDER[4]) end
	end
	if button._accentAlways then
		button._fill:SetColorTexture(0.12, 0.08, 0.18, 0.88)
	elseif hovered then
		button._fill:SetColorTexture(0.10, 0.10, 0.13, 0.9)
	else
		button._fill:SetColorTexture(0.04, 0.04, 0.05, 0.88)
	end
end

local function BUIOnEnter(self)
	if self._buiOrigEnter then self._buiOrigEnter(self) end
	SetState(self, true)
end

local function BUIOnLeave(self)
	if self._buiOrigLeave then self._buiOrigLeave(self) end
	SetState(self, false)
end

local function EnsureHover(button)
	if button:GetScript('OnEnter') ~= BUIOnEnter then
		button._buiOrigEnter = button:GetScript('OnEnter')
		button:SetScript('OnEnter', BUIOnEnter)
	end
	if button:GetScript('OnLeave') ~= BUIOnLeave then
		button._buiOrigLeave = button:GetScript('OnLeave')
		button:SetScript('OnLeave', BUIOnLeave)
	end
	if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
end

local skinnedButtons = setmetatable({}, { __mode = 'k' })

local function SkinButton(button, accentAlways)
	if not button then return end
	Skin3.StripButton(button)
	if not button._buiSkinned then
		button._buiSkinned = true
		local fill = button:CreateTexture(nil, 'BACKGROUND')
		fill.__buiSkin = true
		fill:SetPoint('TOPLEFT', button, 'TOPLEFT', SKIN_INSET_X, -SKIN_INSET)
		fill:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -SKIN_INSET_X, SKIN_INSET)
		button._fill = fill
		local edges = {}
		for edgeIndex = 1, 4 do edges[edgeIndex] = button:CreateTexture(nil, 'BORDER'); edges[edgeIndex].__buiSkin = true end
		edges[1]:SetPoint('TOPLEFT', fill, 'TOPLEFT'); edges[1]:SetPoint('TOPRIGHT', fill, 'TOPRIGHT'); edges[1]:SetHeight(1)
		edges[2]:SetPoint('BOTTOMLEFT', fill, 'BOTTOMLEFT'); edges[2]:SetPoint('BOTTOMRIGHT', fill, 'BOTTOMRIGHT'); edges[2]:SetHeight(1)
		edges[3]:SetPoint('TOPLEFT', fill, 'TOPLEFT'); edges[3]:SetPoint('BOTTOMLEFT', fill, 'BOTTOMLEFT'); edges[3]:SetWidth(1)
		edges[4]:SetPoint('TOPRIGHT', fill, 'TOPRIGHT'); edges[4]:SetPoint('BOTTOMRIGHT', fill, 'BOTTOMRIGHT'); edges[4]:SetWidth(1)
		button._edges = edges
	end
	EnsureHover(button)
	skinnedButtons[button] = true
	button._accentAlways = accentAlways or false
	button._fill:Show()
	for edgeIndex = 1, 4 do button._edges[edgeIndex]:Show() end
	local fontString = button.GetFontString and button:GetFontString()
	if fontString then
		fontString:SetTextColor(1, 1, 1, 1)
		if BUILib.Font then fontString:SetFont(BUILib.Font, 12, 'OUTLINE') end
	end
	SetState(button, false)
end

local function EnsureBUIButton(frame)
	if frame.BUIButton then return frame.BUIButton end
	local button = CreateFrame('Button', 'BUI_GameMenuButton', frame)
	button:RegisterForClicks('AnyUp')
	local fontString = button:CreateFontString(nil, 'OVERLAY')
	fontString:SetFont(BUILib.Font, 12, 'OUTLINE')
	fontString:SetPoint('CENTER')
	fontString:SetText('BluUI')
	button:SetFontString(fontString)
	button:SetScript('OnClick', OnBUIClick)
	frame.BUIButton = button
	return button
end

local function DetectGroupSizes(buttons)
	local buttonCount = #buttons
	if buttonCount <= 1 then return { buttonCount } end
	local gaps, minGap = {}, nil
	for buttonIndex = 1, buttonCount - 1 do
		local gap = (buttons[buttonIndex]:GetBottom() or 0) - (buttons[buttonIndex + 1]:GetTop() or 0)
		gaps[buttonIndex] = gap
		if not minGap or gap < minGap then minGap = gap end
	end
	local sizes, currentSize = {}, 0
	for buttonIndex = 1, buttonCount do
		currentSize = currentSize + 1
		if buttonIndex < buttonCount and gaps[buttonIndex] > minGap + GROUP_TOL then
			sizes[#sizes + 1] = currentSize
			currentSize = 0
		end
	end
	sizes[#sizes + 1] = currentSize
	return sizes
end

local function LayoutStack(frame, buttons, sizes)
	local buiButton = frame.BUIButton
	local referenceButton = buttons[1]
	if not buiButton or not referenceButton then return end
	local width = referenceButton:GetWidth()
	sizes = sizes or { #buttons }

	local order, breakAfter = { buiButton }, { true }
	local buttonIndex = 1
	for groupIndex = 1, #sizes do
		for positionInGroup = 1, sizes[groupIndex] do
			order[#order + 1] = buttons[buttonIndex]
			breakAfter[#order] = (positionInGroup == sizes[groupIndex]) and (groupIndex < #sizes)
			buttonIndex = buttonIndex + 1
		end
	end

	local orderCount = #order
	local totalHeight = orderCount * BUTTON_HEIGHT
	for orderIndex = 1, orderCount - 1 do
		totalHeight = totalHeight + (breakAfter[orderIndex] and GROUP_GAP or ROW_GAP)
	end

	local previousButton
	for orderIndex = 1, orderCount do
		local button = order[orderIndex]
		button:SetSize(width, BUTTON_HEIGHT)
		button:ClearAllPoints()
		if orderIndex == 1 then
			button:SetPoint('TOP', frame, 'CENTER', 0, totalHeight / 2)
		else
			button:SetPoint('TOP', previousButton, 'BOTTOM', 0, breakAfter[orderIndex - 1] and -GROUP_GAP or -ROW_GAP)
		end
		button:Show()
		previousButton = button
	end

	local square = frame._buiSquare
	if square then
		square.fill:ClearAllPoints()
		square.fill:SetPoint('LEFT', order[1], 'LEFT', -(PANEL_PAD - SKIN_INSET_X), 0)
		square.fill:SetPoint('RIGHT', order[1], 'RIGHT', PANEL_PAD - SKIN_INSET_X, 0)
		square.fill:SetPoint('TOP', order[1], 'TOP', 0, PANEL_PAD)
		square.fill:SetPoint('BOTTOM', order[orderCount], 'BOTTOM', 0, -PANEL_PAD)
		square.top:ClearAllPoints(); square.top:SetPoint('TOPLEFT', square.fill); square.top:SetPoint('TOPRIGHT', square.fill)
		square.bottom:ClearAllPoints(); square.bottom:SetPoint('BOTTOMLEFT', square.fill); square.bottom:SetPoint('BOTTOMRIGHT', square.fill)
		square.left:ClearAllPoints(); square.left:SetPoint('TOPLEFT', square.fill); square.left:SetPoint('BOTTOMLEFT', square.fill)
		square.right:ClearAllPoints(); square.right:SetPoint('TOPRIGHT', square.fill); square.right:SetPoint('BOTTOMRIGHT', square.fill)
	end
end

local function HideNewTags(frame)
	local function scan(scannedFrame, depth)
		if depth > 3 then return end
		if scannedFrame.GetRegions then
			for _, region in ipairs({ scannedFrame:GetRegions() }) do
				local tag = (region.GetAtlas and region:GetAtlas() == 'collections-newglow')
					or (region.GetText and region:GetText() == 'NEW')
				local tagParent = tag and region:GetParent()
				if tagParent and tagParent ~= frame and not tagParent._buiNewHidden then
					tagParent._buiNewHidden = true
					tagParent:Hide()
					hooksecurefunc(tagParent, 'Show', function(shownFrame) if Skin.IsSkinEnabled('gameMenu') then shownFrame:Hide() end end)
				end
			end
		end
		if scannedFrame.GetChildren then
			for _, childFrame in ipairs({ scannedFrame:GetChildren() }) do scan(childFrame, depth + 1) end
		end
	end
	scan(frame, 0)
end

local function SortByTop(buttonA, buttonB) return (buttonA:GetTop() or 0) > (buttonB:GetTop() or 0) end

local function Refresh(frame)
	if not Skin.IsSkinEnabled('gameMenu') or not frame.buttonPool then return end
	if frame.Header then frame.Header:SetAlpha(0) end
	if frame.dividerPool and frame.dividerPool.EnumerateActive then
		for divider in frame.dividerPool:EnumerateActive() do divider:SetAlpha(0) end
	end
	local buttons = {}
	for button in frame.buttonPool:EnumerateActive() do
		SkinButton(button, false)
		buttons[#buttons + 1] = button
	end
	table.sort(buttons, SortByTop)
	EnsureBUIButton(frame)
	SkinButton(frame.BUIButton, true)
	LayoutStack(frame, buttons, DetectGroupSizes(buttons))
	HideNewTags(frame)
end

local function HideBlizzArt(frame)
	if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
	if frame.Border then frame.Border:SetAlpha(0) end
	if frame.Bg then frame.Bg:SetAlpha(0) end
	if frame.Bg2 then frame.Bg2:SetAlpha(0) end
end

local function EnsureDim(frame)
	if frame._buiDim then return end
	local dim = CreateFrame('Frame', nil, UIParent)
	dim:SetAllPoints(UIParent)
	dim:Hide()

	dim:EnableMouse(true)
	dim:EnableMouseWheel(true)
	dim:SetScript('OnMouseWheel', function() end)
	local texture = dim:CreateTexture(nil, 'BACKGROUND')
	texture:SetAllPoints(dim)
	texture:SetColorTexture(0, 0, 0, 0.6)
	frame._buiDim = dim
end

local function Install()
	local frame = _G.GameMenuFrame
	if not frame then
		if EventUtil and EventUtil.ContinueOnAddOnLoaded then
			EventUtil.ContinueOnAddOnLoaded('Blizzard_GameMenu', Install)
		end
		return
	end
	if not Skin.IsSkinEnabled('gameMenu') or frame._buiGMInit then return end
	frame._buiGMInit = true

	Skin3.StripTextures(frame)
	Skin3.SquarePanel(frame, { bg = MENU_BG, border = PANEL_BORDER })
	HideBlizzArt(frame)
	EnsureDim(frame)

	if frame.Layout then hooksecurefunc(frame, 'Layout', Refresh) end
	if frame.InitButtons then hooksecurefunc(frame, 'InitButtons', Refresh) end

	frame:HookScript('OnShow', function(self)
		if not Skin.IsSkinEnabled('gameMenu') then return end
		HideBlizzArt(self)
		Refresh(self)
		local dim = self._buiDim
		if dim then
			dim:SetFrameStrata(self:GetFrameStrata())
			dim:SetFrameLevel(max(0, self:GetFrameLevel() - 1))
			dim:Show()
		end
	end)
	frame:HookScript('OnHide', function(self)
		if self._buiDim then self._buiDim:Hide() end
	end)

	Refresh(frame)
end

BUI.Events:OnLogin('Skinning.GameMenu', Install)

local function RestoreButton(button)
	if button._fill then button._fill:Hide() end
	if button._edges then for edgeIndex = 1, 4 do button._edges[edgeIndex]:Hide() end end
	if button:GetScript('OnEnter') == BUIOnEnter then button:SetScript('OnEnter', button._buiOrigEnter) end
	if button:GetScript('OnLeave') == BUIOnLeave then button:SetScript('OnLeave', button._buiOrigLeave) end
end

local function Deactivate()
	local frame = _G.GameMenuFrame
	if not frame or not frame._buiGMInit then return end
	local square = frame._buiSquare
	if square then
		square.fill:Hide()
		square.top:Hide(); square.bottom:Hide(); square.left:Hide(); square.right:Hide()
	end
	if frame.NineSlice then frame.NineSlice:SetAlpha(1) end
	if frame.Border then frame.Border:SetAlpha(1) end
	if frame.Bg then frame.Bg:SetAlpha(1) end
	if frame.Bg2 then frame.Bg2:SetAlpha(1) end
	if frame.Header then frame.Header:SetAlpha(1) end
	if frame.dividerPool and frame.dividerPool.EnumerateActive then
		for divider in frame.dividerPool:EnumerateActive() do divider:SetAlpha(1) end
	end
	for button in pairs(skinnedButtons) do RestoreButton(button) end
	if frame.BUIButton then frame.BUIButton:Hide() end
	if frame._buiDim then frame._buiDim:Hide() end
	BUI.Print('Game Menu skin disabled. Reopen the menu to restore the Blizzard layout; /reload for a full visual reset.')
end

local function Activate()
	Install()
	local frame = _G.GameMenuFrame
	if not frame or not frame._buiGMInit then return end
	local square = frame._buiSquare
	if square then
		square.fill:Show()
		square.top:Show(); square.bottom:Show(); square.left:Show(); square.right:Show()
	end
	if frame:IsShown() then
		HideBlizzArt(frame)
		Refresh(frame)
	end
end

Skin.OnToggle('gameMenu', function(enabled)
	if enabled then Activate() else Deactivate() end
end)

Skin.RegisterSkin('gameMenu', {
	name = 'Game Menu',
	description = 'Dark theme for the Escape menu, with a BluUI shortcut.',
	icon = 'Interface\\Icons\\INV_Misc_Gear_01',
})
