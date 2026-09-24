local _, BUI = ...

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel
local SNAP_THRESHOLD = 10
local OVERLAY_LEVEL = 30
local FILL_ALPHA = 0.26
local FILL_ALPHA_ACTIVE = 0.42
local GUIDE_ALPHA = 0.8
local HINT_TEXT = 'drag to move  ·  right-click to lock'
local CENTERED_HINT = 'centered  ·  drag up or down'
local HINT_GAP = 2
local LABEL_SIZE = 18
local HINT_SIZE = 11
local HINT_COLOR = { 0.85, 0.85, 0.85 }
local MOVER_COLOR = { 0.3, 0.62, 1 }
local SAVE_PRECISION = 1000

local state = { unlocked = false, dragging = nil, bars = {}, editMode = false }
local listeners = {}
local guides

local function UIScale(frame)
	return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function UIRect(frame)
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (left and right and top and bottom) then return nil end
	local scale = UIScale(frame)
	return left * scale, right * scale, top * scale, bottom * scale
end

local function CursorUI()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	return x / scale, y / scale
end

local function EnsureGuides()
	if guides then return guides end
	guides = CreateFrame('Frame', nil, UIParent)
	guides:SetFrameStrata('TOOLTIP')
	guides:SetAllPoints(UIParent)
	local vertical = guides:CreateTexture(nil, 'OVERLAY')
	vertical:SetTexture(BUI.C.FALLBACK_TEXTURE)
	vertical:SetWidth(Pixel.PixelSize(1))
	local horizontal = guides:CreateTexture(nil, 'OVERLAY')
	horizontal:SetTexture(BUI.C.FALLBACK_TEXTURE)
	horizontal:SetHeight(Pixel.PixelSize(1))
	guides.vertical, guides.horizontal = vertical, horizontal
	guides:Hide()
	return guides
end

local function ShowGuides(snapX, snapY)
	local frame = EnsureGuides()
	local red, green, blue = MOVER_COLOR[1], MOVER_COLOR[2], MOVER_COLOR[3]
	if snapX then
		frame.vertical:ClearAllPoints()
		frame.vertical:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', snapX, 0)
		frame.vertical:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', snapX, 0)
		frame.vertical:SetVertexColor(red, green, blue, GUIDE_ALPHA)
		frame.vertical:Show()
	else
		frame.vertical:Hide()
	end
	if snapY then
		frame.horizontal:ClearAllPoints()
		frame.horizontal:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', 0, snapY)
		frame.horizontal:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', 0, snapY)
		frame.horizontal:SetVertexColor(red, green, blue, GUIDE_ALPHA)
		frame.horizontal:Show()
	else
		frame.horizontal:Hide()
	end
	frame:SetShown(snapX ~= nil or snapY ~= nil)
end

local snap = { threshold = 0, bestDeltaX = nil, bestDeltaY = nil, guideX = nil, guideY = nil }

local function ConsiderX(target, edge)
	local delta = target - edge
	if math.abs(delta) <= snap.threshold and (not snap.bestDeltaX or math.abs(delta) < math.abs(snap.bestDeltaX)) then
		snap.bestDeltaX, snap.guideX = delta, target
	end
end

local function ConsiderY(target, edge)
	local delta = target - edge
	if math.abs(delta) <= snap.threshold and (not snap.bestDeltaY or math.abs(delta) < math.abs(snap.bestDeltaY)) then
		snap.bestDeltaY, snap.guideY = delta, target
	end
end

local function SnapCenter(bar, centerX, centerY, halfWidth, halfHeight, lockX)
	local settings = ActionBars.GetSettings()
	if not settings.snapBars or IsShiftKeyDown() then return centerX, centerY, nil, nil end
	local threshold = Pixel.Scale(SNAP_THRESHOLD)
	local gapPixels = settings.snapGap
	local gap = gapPixels > 0 and Pixel.PixelSize(gapPixels) or 0
	local left, right = centerX - halfWidth, centerX + halfWidth
	local top, bottom = centerY + halfHeight, centerY - halfHeight
	snap.threshold, snap.bestDeltaX, snap.bestDeltaY, snap.guideX, snap.guideY = threshold, nil, nil, nil, nil

	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	if not lockX then
		ConsiderX(0, left)
		ConsiderX(screenWidth, right)
		ConsiderX(screenWidth / 2, centerX)
	end
	ConsiderY(0, bottom)
	ConsiderY(screenHeight, top)
	ConsiderY(screenHeight / 2, centerY)

	for _, other in pairs(ActionBars.bars) do
		local otherSettings = ActionBars.GetBarSettings(other.key)
		if other ~= bar and otherSettings.enabled and not other.empty and other.header:IsShown() then
			local otherLeft, otherRight, otherTop, otherBottom = UIRect(other.header)
			if otherLeft then
				local verticalOverlap = bottom - threshold <= otherTop and top + threshold >= otherBottom
				local horizontalOverlap = left - threshold <= otherRight and right + threshold >= otherLeft
				if not lockX then
					if verticalOverlap then
						ConsiderX(otherRight + gap, left)
						ConsiderX(otherLeft - gap, right)
					end
					ConsiderX(otherLeft, left)
					ConsiderX(otherRight, right)
					ConsiderX((otherLeft + otherRight) / 2, centerX)
				end
				if horizontalOverlap then
					ConsiderY(otherTop + gap, bottom)
					ConsiderY(otherBottom - gap, top)
				end
				ConsiderY(otherTop, top)
				ConsiderY(otherBottom, bottom)
				ConsiderY((otherTop + otherBottom) / 2, centerY)
			end
		end
	end

	return centerX + (snap.bestDeltaX or 0), centerY + (snap.bestDeltaY or 0), snap.guideX, snap.guideY
end

local function AlignToPixelGrid(centerX, centerY, halfWidth, halfHeight)
	local unit = Pixel.PixelSize(1)
	local left = BUI.Round((centerX - halfWidth) / unit) * unit
	local top = BUI.Round((centerY + halfHeight) / unit) * unit
	return left + halfWidth, top - halfHeight
end

local function SavePosition(header, settings)
	local centerX, centerY = header:GetCenter()
	local uiCenterX, uiCenterY = UIParent:GetCenter()
	if not (centerX and uiCenterX) then return end
	local scale = UIScale(header)
	local offsetX = (centerX * scale - uiCenterX) / scale
	local offsetY = (centerY * scale - uiCenterY) / scale
	settings.posX = settings.centerHorizontally and 0 or BUI.Round(offsetX * SAVE_PRECISION) / SAVE_PRECISION
	settings.posY = BUI.Round(offsetY * SAVE_PRECISION) / SAVE_PRECISION
end

local function PlaceHeader(header, centerX, centerY)
	local uiCenterX, uiCenterY = UIParent:GetCenter()
	local scale = UIScale(header)
	header:ClearAllPoints()
	header:SetPoint('CENTER', UIParent, 'CENTER', (centerX - uiCenterX) / scale, (centerY - uiCenterY) / scale)
end

local EndDrag

local function DragUpdate(overlay)
	local bar = state.dragging
	if not bar then
		overlay:SetScript('OnUpdate', nil)
		return
	end
	if InCombatLockdown() then
		EndDrag(bar, overlay)
		return
	end
	local cursorX, cursorY = CursorUI()
	local centerX = overlay.startCenterX + (cursorX - overlay.startCursorX)
	local centerY = overlay.startCenterY + (cursorY - overlay.startCursorY)
	centerX, centerY = AlignToPixelGrid(centerX, centerY, overlay.halfWidth, overlay.halfHeight)
	if overlay.lockX then centerX = UIParent:GetWidth() / 2 end
	local snapX, snapY
	centerX, centerY, snapX, snapY = SnapCenter(bar, centerX, centerY, overlay.halfWidth, overlay.halfHeight, overlay.lockX)
	PlaceHeader(bar.header, centerX, centerY)
	ShowGuides(snapX, snapY)
	local uiCenterX, uiCenterY = UIParent:GetCenter()
	overlay.hint:SetText(('%d, %d%s'):format(centerX - uiCenterX, centerY - uiCenterY, (snapX or snapY) and '   snapped' or ''))
end

local function BeginDrag(bar, overlay)
	if InCombatLockdown() or state.dragging then return end
	local header = bar.header
	local centerX, centerY = header:GetCenter()
	if not centerX then return end
	local settings = ActionBars.GetBarSettings(bar.key)
	local scale = UIScale(header)
	local cursorX, cursorY = CursorUI()
	state.dragging = bar
	overlay.startCursorX, overlay.startCursorY = cursorX, cursorY
	overlay.startCenterX, overlay.startCenterY = centerX * scale, centerY * scale
	overlay.halfWidth, overlay.halfHeight = header:GetWidth() * scale / 2, header:GetHeight() * scale / 2
	overlay.lockX = settings.centerHorizontally
	overlay:Paint(true)
	overlay.hint:Show()
	overlay:SetScript('OnUpdate', DragUpdate)
end

EndDrag = function(bar, overlay)
	overlay:SetScript('OnUpdate', nil)
	if state.dragging ~= bar then return end
	state.dragging = nil
	ShowGuides(nil, nil)
	overlay:Paint(overlay:IsMouseOver())
	overlay:RefreshHint()
	overlay.hint:SetShown(overlay:IsMouseOver())
	if InCombatLockdown() then return end
	local settings = ActionBars.GetBarSettings(bar.key)
	settings.anchorFrame = ''
	SavePosition(bar.header, settings)
	ActionBars.PositionBar(bar)
	for _, listener in pairs(listeners) do listener('position', bar.key) end
end

local function CreateOverlay(bar)
	local header = bar.header
	local overlay = CreateFrame('Frame', nil, header)
	overlay:SetAllPoints(header)
	overlay:SetFrameLevel(header:GetFrameLevel() + OVERLAY_LEVEL)
	overlay:EnableMouse(true)
	overlay:RegisterForDrag('LeftButton')
	overlay:Hide()

	local fill = overlay:CreateTexture(nil, 'BACKGROUND')
	fill:SetAllPoints()
	fill:SetTexture(BUI.C.FALLBACK_TEXTURE)
	local label = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(label, LABEL_SIZE, BUI.C.FONT_PATH, 'OUTLINE')
	label:SetIgnoreParentScale(true)
	label:SetPoint('CENTER', 0, 0)
	label:SetText(bar.label)
	label:SetTextColor(1, 1, 1, 1)
	local hint = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(hint, HINT_SIZE, BUI.C.FONT_PATH, 'OUTLINE')
	hint:SetIgnoreParentScale(true)
	hint:SetPoint('TOP', label, 'BOTTOM', 0, -HINT_GAP)
	hint:SetTextColor(HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3], 1)
	hint:Hide()
	overlay.fill, overlay.label, overlay.hint = fill, label, hint

	function overlay:Paint(active)
		local red, green, blue = MOVER_COLOR[1], MOVER_COLOR[2], MOVER_COLOR[3]
		fill:SetVertexColor(red, green, blue, active and FILL_ALPHA_ACTIVE or FILL_ALPHA)
		Pixel.ApplyBorder(self, 1, red, green, blue, 1)
	end
	function overlay:RefreshHint()
		hint:SetText(ActionBars.GetBarSettings(bar.key).centerHorizontally and CENTERED_HINT or HINT_TEXT)
	end

	overlay:SetScript('OnEnter', function(self)
		self:Paint(true)
		self.hint:Show()
	end)
	overlay:SetScript('OnLeave', function(self)
		if state.dragging == bar then return end
		self:Paint(false)
		self.hint:Hide()
	end)
	overlay:SetScript('OnMouseUp', function(_, button)
		if button ~= 'RightButton' or state.dragging then return end
		if state.bars[bar.key] and not state.unlocked then
			ActionBars.SetBarUnlocked(bar.key, false)
		else
			ActionBars.SetMoversUnlocked(false)
		end
	end)
	overlay:SetScript('OnDragStart', function(self) BeginDrag(bar, self) end)
	overlay:SetScript('OnDragStop', function(self) EndDrag(bar, self) end)
	overlay:Paint(false)
	overlay:RefreshHint()
	bar.mover = overlay
	return overlay
end

function ActionBars.MoversUnlocked()
	return state.unlocked
end

function ActionBars.BarUnlocked(key)
	return state.unlocked or state.bars[key] == true
end

function ActionBars.RefreshMovers()
	local allowed = BUI.IsModuleEnabled('actionBars') and not InCombatLockdown()
	local anyShown = false
	for _, bar in pairs(ActionBars.bars) do
		local settings = ActionBars.GetBarSettings(bar.key)
		local overlay = bar.mover or CreateOverlay(bar)
		local wanted = allowed and (state.unlocked or state.bars[bar.key] == true)
		local enabled = settings.enabled
		local visible = wanted and enabled
		if visible and not bar.forcedShown then
			bar.forcedShown = true
			ActionBars.ForceBarShown(bar)
		elseif not visible and bar.forcedShown and not InCombatLockdown() then
			bar.forcedShown = nil
			if bar.visibility then ActionBars.SetBarActive(bar, enabled) end
		end
		if visible then
			overlay:Paint(false)
			overlay:RefreshHint()
			overlay:Show()
			anyShown = true
		else
			overlay:Hide()
		end
	end
	if not anyShown then ShowGuides(nil, nil) end
end

function ActionBars.SetBarUnlocked(key, unlocked)
	unlocked = unlocked and true or false
	if (state.bars[key] == true) == unlocked then return end
	state.bars[key] = unlocked or nil
	if not unlocked and state.dragging and state.dragging.key == key and not state.unlocked then
		EndDrag(state.dragging, state.dragging.mover)
	end
	ActionBars.RefreshMovers()
	for _, listener in pairs(listeners) do listener('barUnlocked', key, unlocked) end
end

function ActionBars.SetMoversUnlocked(unlocked)
	unlocked = unlocked and true or false
	if state.unlocked == unlocked then return end
	state.unlocked = unlocked
	if not unlocked then
		wipe(state.bars)
		if state.dragging then
			local bar = state.dragging
			EndDrag(bar, bar.mover)
		end
	end
	ActionBars.RefreshMovers()
	for _, listener in pairs(listeners) do listener('unlocked', unlocked) end
end

function ActionBars.OnMoversChanged(key, listener)
	listeners[key] = listener
end

BUI.Events:Register('PLAYER_REGEN_DISABLED', 'ActionBars.Movers.Combat', function()
	if state.dragging then EndDrag(state.dragging, state.dragging.mover) end
	ActionBars.RefreshMovers()
end)
BUI.Events:Register('PLAYER_REGEN_ENABLED', 'ActionBars.Movers.Settled', function()
	ActionBars.RefreshMovers()
end)

local editModeHooked = false

local function HookEditMode()
	local manager = EditModeManagerFrame
	if editModeHooked or not manager then return end
	editModeHooked = true
	manager:HookScript('OnShow', function()
		if not BUI.IsModuleEnabled('actionBars') or state.unlocked then return end
		state.editMode = true
		ActionBars.SetMoversUnlocked(true)
	end)
	manager:HookScript('OnHide', function()
		if not state.editMode then return end
		state.editMode = false
		ActionBars.SetMoversUnlocked(false)
	end)
	if manager:IsShown() and BUI.IsModuleEnabled('actionBars') and not state.unlocked then
		state.editMode = true
		ActionBars.SetMoversUnlocked(true)
	end
end

HookEditMode()
if not editModeHooked then
	EventUtil.ContinueOnAddOnLoaded('Blizzard_EditMode', HookEditMode)
end
