local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Core')
local hooksecurefunc = BUI.Prof.MakeHooker('Core')

BUI.Skinning = {}
local Skin = BUI.Skinning

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Colors = BUILib.Colors
local BACKDROP = BUILib.Widget.BACKDROP

local toggleCallbacks = {}
local skinRegistry = {}
local skinOrder = {}

function Skin.OnToggle(name, callback)
	if not toggleCallbacks[name] then toggleCallbacks[name] = {} end
	toggleCallbacks[name][#toggleCallbacks[name] + 1] = callback
end

local function SkinSortName(id)
	local info = skinRegistry[id]
	return ((info and info.name) or id):lower()
end

function Skin.RegisterSkin(id, info)
	skinRegistry[id] = info
	skinOrder[#skinOrder + 1] = id
	table.sort(skinOrder, function(a, b) return SkinSortName(a) < SkinSortName(b) end)
end

function Skin.GetSkinRegistry()
	return skinRegistry, skinOrder
end

local function GetSkinDB()
	local db = BUI.GetDB()
	if not db.skinning then db.skinning = {} end
	return db.skinning
end

function Skin.IsEnabled()
	return true
end

function Skin.IsSkinEnabled(id)
	return GetSkinDB()[id] ~= false
end

local function ClearNew(skinDB, id)
	local unseen = skinDB.unseen
	if not unseen then return end
	if id then unseen[id] = nil else wipe(unseen) end
end

function Skin.IsSkinNew(id)
	local unseen = GetSkinDB().unseen
	return unseen ~= nil and unseen[id] == true
end

local BASELINE_SKINS = {}
for _, id in ipairs({
	'achievements', 'alerts', 'auctionhouse', 'bonusroll', 'calendar', 'chatpanels', 'collections', 'deathrecap', 'mirrortimers',
	'cooldownmanager', 'delves', 'dressup', 'friends', 'greatvault', 'groupfinder', 'grouploot', 'guild', 'inspect',
	'instanceabandon', 'itemsocketing', 'itemupgrade', 'journeys', 'loothistory', 'lootwindow', 'mail', 'playerauras',
	'professions', 'questdialogs', 'queuepopups', 'readycheck', 'spellbook', 'splash', 'staticpopup', 'systempanels',
	'trade', 'transmog', 'travel', 'worldmap', 'characterFrame', 'chat', 'experiencebar', 'gameMenu', 'menus',
	'merchant', 'objectivetracker', 'trainer', 'petstable', 'playerchoice', 'pvpmatch', 'renown', 'keybinds',
	'currencytransfer', 'housing', 'tradingpost', 'catalogshop', 'landingpage', 'barbershop', 'iteminteraction',
	'clock', 'tabard', 'petition', 'help', 'talkinghead', 'guildregistrar', 'bnetToast', 'petBattle',
	'currencyManager', 'gemcounter', 'portalManager', 'reputationManager', 'questoverlay',
}) do BASELINE_SKINS[id] = true end

function Skin.SeedSkinStates()
	local skinDB = GetSkinDB()
	local firstRun = skinDB.seen == nil
	local hadKeys = next(skinDB) ~= nil
	local seen = skinDB.seen
	if not seen then
		seen = {}
		skinDB.seen = seen
	end
	local unseen = skinDB.unseen
	if not unseen then
		unseen = {}
		skinDB.unseen = unseen
	end
	for id in pairs(unseen) do
		if BASELINE_SKINS[id] then
			unseen[id] = nil
			skinDB[id] = true
		end
	end
	for _, id in ipairs(skinOrder) do
		if not seen[id] then
			seen[id] = true
			if skinDB[id] == nil then
				local info = skinRegistry[id]
				local legacy = info and info.legacy
				if legacy and skinDB[legacy] == false then
					skinDB[id] = false
				elseif firstRun and (not hadKeys or BASELINE_SKINS[id]) then
					skinDB[id] = true
				else
					skinDB[id] = false
					unseen[id] = true
				end
			end
		end
	end
	skinDB.miscpanels = nil
	skinDB.shop = nil
	skinDB.micromenu = nil
	skinDB.combatalerts = nil
	skinDB.lossofcontrol = nil
end

function Skin.SetSkinEnabled(id, enabled)
	enabled = enabled and true or false
	GetSkinDB()[id] = enabled
	ClearNew(GetSkinDB(), id)
	local list = toggleCallbacks[id]
	if list then
		for _, callback in ipairs(list) do callback(enabled) end
	end
end

function Skin.SetAllSkinsEnabled(enabled)
	for _, id in ipairs(skinOrder) do
		Skin.SetSkinEnabled(id, enabled)
	end
	ClearNew(GetSkinDB())
end

function Skin.WriteSkinsEnabled(enabledByID)
	local skinDB = GetSkinDB()
	for _, id in ipairs(skinOrder) do skinDB[id] = enabledByID[id] and true or false end
	ClearNew(skinDB)
end

function Skin.RefreshAll()
	for _, id in ipairs(skinOrder) do
		local list = toggleCallbacks[id]
		if list then
			local effective = Skin.IsSkinEnabled(id)
			for _, callback in ipairs(list) do callback(effective) end
		end
	end
end

function Skin.Toggle()
	Skin.RefreshAll()
end

local SUPPRESS_MOUSE_DEPTH = 3

function Skin.SuppressBlizzardFrame(frame)
	if not frame then return end
	if frame._buiSuppressActive then
		frame:SetAlpha(0)
		frame:EnableMouse(false)
		return
	end
	frame._buiSuppressActive = true

	frame._buiSavedAlpha = frame:GetAlpha()
	frame._buiSavedMouse = frame:IsMouseEnabled()
	frame._buiSavedChildMouse = {}

	local function DisableMouseTree(parent, depth)
		for _, child in pairs({ parent:GetChildren() }) do
			if child.IsMouseEnabled then
				frame._buiSavedChildMouse[child] = child:IsMouseEnabled()
			end
			if child.EnableMouse then child:EnableMouse(false) end
			if depth > 1 then DisableMouseTree(child, depth - 1) end
		end
	end
	DisableMouseTree(frame, SUPPRESS_MOUSE_DEPTH)

	frame:SetAlpha(0)
	frame:EnableMouse(false)
end

function Skin.RestoreBlizzardFrame(frame)
	if not frame or not frame._buiSuppressActive then return end
	frame._buiSuppressActive = false

	frame:SetAlpha(frame._buiSavedAlpha or 1)
	frame:EnableMouse(frame._buiSavedMouse ~= false)
	if frame._buiSavedChildMouse then
		for child, wasEnabled in pairs(frame._buiSavedChildMouse) do
			if child.EnableMouse then child:EnableMouse(wasEnabled) end
		end
	end
	frame._buiSavedAlpha = nil
	frame._buiSavedMouse = nil
	frame._buiSavedChildMouse = nil
	if BUI.MoveFrames and BUI.MoveFrames.OnFrameRestored then BUI.MoveFrames.OnFrameRestored(frame) end
end

function Skin.ApplyBackdrop(frame, bgColor, borderColor)
	if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
	frame:SetBackdrop(BACKDROP)
	frame:SetBackdropColor(unpack(bgColor or Colors.bg.dark))
	frame:SetBackdropBorderColor(unpack(borderColor or Colors.border.default))
end

function Skin.SavePosition(frame, dbKey)
	local db = BUI.GetDB()
	if not db.framePositions then db.framePositions = {} end
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	if type(point) == 'string' and type(x) == 'number' and type(y) == 'number'
		and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then
		db.framePositions[dbKey] = { point = point, relPoint = relativePoint or point, x = x, y = y }
		return
	end
	local left, top = frame:GetLeft(), frame:GetTop()
	if type(left) ~= 'number' or type(top) ~= 'number' then return end
	if issecretvalue and (issecretvalue(left) or issecretvalue(top)) then return end
	db.framePositions[dbKey] = { point = 'TOPLEFT', relPoint = 'BOTTOMLEFT', x = left, y = top }
end

local VALID_ANCHOR_POINTS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true,
	LEFT = true, CENTER = true, RIGHT = true,
	BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

function Skin.RestorePosition(frame, dbKey)
	local db = BUI.GetDB()
	if not db.framePositions then return false end
	local position = db.framePositions[dbKey]
	if not position then return false end
	if not VALID_ANCHOR_POINTS[position.point] or type(position.x) ~= 'number' or type(position.y) ~= 'number' then
		db.framePositions[dbKey] = nil
		return false
	end
	local relativePoint = VALID_ANCHOR_POINTS[position.relPoint] and position.relPoint or position.point
	frame:ClearAllPoints()
	frame:SetPoint(position.point, UIParent, relativePoint, position.x, position.y)
	return true
end

function Skin.PositionMode()
	local config = BUI.MoveFrames and BUI.MoveFrames.GetConfig()
	return config and config.positionMode or 'remember'
end

local function ResolvePanel(panel)
	if type(panel) == 'string' then return _G[panel] end
	return panel
end

local function SetPanelLayoutAttribute(panel, name, value)
	if UIPanelWindows and UIPanelWindows[panel:GetName() or ''] and SetUIPanelAttribute then
		SetUIPanelAttribute(panel, name, value)
	elseif panel:GetAttribute('UIPanelLayout-defined') then
		panel:SetAttributeNoHandler('UIPanelLayout-' .. name, value)
	end
end

local function ApplyPanelSlot(panel, width, height)
	panel = ResolvePanel(panel)
	if not panel or not panel.GetAttribute or (InCombatLockdown() and panel:IsProtected()) then return end
	SetPanelLayoutAttribute(panel, 'width', width)
	SetPanelLayoutAttribute(panel, 'height', height)
	if panel:IsShown() and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions, panel) end
end

function Skin.ReservePanelSlot(panel, width, height)
	ApplyPanelSlot(panel, width, height)
end

function Skin.ReleasePanelSlot(panel)
	ApplyPanelSlot(panel, nil, nil)
end

local function LastPanelSlot(panel)
	if not (panel.GetLeft and panel.GetTop) then return end
	local left, top = panel:GetLeft(), panel:GetTop()
	if type(left) ~= 'number' or type(top) ~= 'number' then return end
	if issecretvalue and (issecretvalue(left) or issecretvalue(top)) then return end
	local ratio = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return left * ratio, top * ratio - UIParent:GetHeight()
end

function Skin.HomePosition(frame, dbKey, point, x, y, follow)
	if InCombatLockdown() and frame:IsProtected() then return end
	if Skin.PositionMode() == 'remember' and dbKey and Skin.RestorePosition(frame, dbKey) then return end
	local panel = ResolvePanel(follow)
	frame:ClearAllPoints()
	if panel and panel:IsShown() then
		frame:SetPoint('TOPLEFT', panel, 'TOPLEFT', 0, 0)
		return
	end
	local left, top
	if panel then left, top = LastPanelSlot(panel) end
	if left then
		frame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', left, top)
	else
		point = point or 'CENTER'
		frame:SetPoint(point, UIParent, point, x or 0, y or 0)
	end
end

function Skin.MakeDraggable(frame, dbKey, point, x, y, follow)
	if frame._buiDraggable then return end
	frame._buiDraggable = true
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag('LeftButton')
	SetScript(frame, 'OnDragStart', function(self)
		self._buiDragged = true
		self:StartMoving()
	end)
	SetScript(frame, 'OnDragStop', function(self)
		self:StopMovingOrSizing()
		if dbKey and Skin.PositionMode() == 'remember' then Skin.SavePosition(self, dbKey) end
	end)
	local function Home() Skin.HomePosition(frame, dbKey, point, x, y, follow) end
	local function WantsHome() return Skin.PositionMode() ~= 'session' or not frame._buiDragged end

	local hookedPanel
	local function WatchPanel()
		local panel = follow and ResolvePanel(follow)
		if not panel or panel == hookedPanel or not panel.HookScript then return panel end
		hookedPanel = panel
		HookScript(panel, 'OnShow', function()
			if frame:IsShown() and WantsHome() then Home() end
		end)
		return panel
	end

	HookScript(frame, 'OnShow', function(self)
		if follow then Skin.ReservePanelSlot(follow, self:GetWidth(), self:GetHeight()) end
		local panel = WatchPanel()
		if WantsHome() then Home() end
		if follow and not (panel and panel:IsShown()) then
			BUI.Prof.After('Core', 0, function()
				local latePanel = WatchPanel()
				if latePanel and latePanel:IsShown() and self:IsShown() and WantsHome() then Home() end
			end)
		end
	end)
	HookScript(frame, 'OnHide', function(self)
		if Skin.PositionMode() == 'reset' then
			Home()
			self._buiDragged = false
		end
	end)
	Home()
end

local DEFAULT_QUALITY = { 0.9, 0.9, 0.9 }
function Skin.QualityColor(itemID)
	if not itemID then return DEFAULT_QUALITY[1], DEFAULT_QUALITY[2], DEFAULT_QUALITY[3] end
	local quality = C_Item.GetItemQualityByID(itemID)
	if quality and quality > 1 then
		local color = ITEM_QUALITY_COLORS[quality]
		if color then return color.r, color.g, color.b end
	end
	return DEFAULT_QUALITY[1], DEFAULT_QUALITY[2], DEFAULT_QUALITY[3]
end

local TIP_PADDING_X, TIP_PADDING_Y, TIP_TITLE_BLOCK = 10, 8, 24
local TIP_BODY_SIZE, TIP_TITLE_SIZE = 11, 12
local TIP_TITLE_COLOR = { 0.9, 0.9, 0.93, 1 }
local TIP_BODY_COLOR = { 0.87, 0.87, 0.9, 1 }
local TIP_LABEL_COLOR = { 0.55, 0.55, 0.6, 1 }
local TIP_LINE_COLOR = { 1, 1, 1, 0.1 }
local PANEL_FILL = { BUI.C.PANEL_BACKDROP[1], BUI.C.PANEL_BACKDROP[2], BUI.C.PANEL_BACKDROP[3], BUI.C.PANEL_BACKDROP[4] }
local PANEL_EDGE = { BUI.C.PANEL_BACKDROP[5], BUI.C.PANEL_BACKDROP[6], BUI.C.PANEL_BACKDROP[7], BUI.C.PANEL_BACKDROP[8] }

Skin.TIP_PADDING_X = TIP_PADDING_X
Skin.TIP_PADDING_Y = TIP_PADDING_Y
Skin.TIP_TITLE_BLOCK = TIP_TITLE_BLOCK

local PANEL_STYLE = { fill = PANEL_FILL, edge = PANEL_EDGE }

function Skin.TipShell(frame, inset)
	return BUILib.Skin.Shell(frame, PANEL_STYLE, inset)
end

function Skin.HideTipShell(frame)
	BUILib.Skin.HideShell(frame)
end

local DROPDOWN_HEIGHT_FALLBACK = 26
local dropdownHeight

function Skin.DropdownHeight()
	if dropdownHeight then return dropdownHeight end
	local ok, probe = pcall(CreateFrame, 'DropdownButton', nil, UIParent, 'WowStyle1DropdownTemplate')
	local height = ok and probe and probe.GetHeight and probe:GetHeight()
	if probe and probe.Hide then probe:Hide() end
	dropdownHeight = (height and height > 0) and math.floor(height + 0.5) or DROPDOWN_HEIGHT_FALLBACK
	return dropdownHeight
end

local function AnchorIsVertical(point, prefix)
	return type(point) == 'string' and point:sub(1, #prefix) == prefix
end

local function CollectPoints(frame)
	local points = {}
	for pointIndex = 1, frame:GetNumPoints() do
		local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(pointIndex)
		if point then points[#points + 1] = { point, relativeTo, relativePoint, offsetX or 0, offsetY or 0 } end
	end
	return points
end

local function HasVerticalAnchors(frame, topPrefix, bottomPrefix)
	local top, bottom = false, false
	for pointIndex = 1, frame:GetNumPoints() do
		local point = frame:GetPoint(pointIndex)
		if AnchorIsVertical(point, topPrefix) then top = true end
		if AnchorIsVertical(point, bottomPrefix) then bottom = true end
	end
	return top and bottom
end

function Skin.NormalizeDropdownHeight(dropdown)
	if not dropdown or dropdown._buiDropdownHeight or not (dropdown.SetupMenu and dropdown.SetHeight) then return end
	if not dropdown.GetNumPoints or HasVerticalAnchors(dropdown, 'TOP', 'BOTTOM') then return end
	dropdown._buiDropdownHeight = true
	dropdown:SetHeight(Skin.DropdownHeight())
end

local CONTROL_GAP = 6
Skin.CONTROL_GAP = CONTROL_GAP

function Skin.PadVertical(frame, top, bottom, skip)
	if not frame or frame._buiPadded or not frame.GetNumPoints then return end
	frame._buiPadded = true
	local points = CollectPoints(frame)
	for pointIndex = 1, #points do
		local entry = points[pointIndex]
		if not (skip and skip[entry[2]]) then
			local amount = 0
			if AnchorIsVertical(entry[1], 'TOP') then amount = -(type(top) == 'function' and top(entry[2]) or top or 0) end
			if AnchorIsVertical(entry[1], 'BOTTOM') then amount = type(bottom) == 'function' and bottom(entry[2]) or bottom or 0 end
			if amount ~= 0 then frame:SetPoint(entry[1], entry[2], entry[3], entry[4], entry[5] + amount) end
		end
	end
end

function Skin.TipTitleLine(frame, scale)
	scale = scale or 1
	local line = frame._buiTipLine
	if not line then
		line = frame:CreateTexture(nil, 'BORDER')
		line:SetColorTexture(TIP_LINE_COLOR[1], TIP_LINE_COLOR[2], TIP_LINE_COLOR[3], TIP_LINE_COLOR[4])
		line:SetHeight(1)
		frame._buiTipLine = line
	end
	local offsetY = -(TIP_PADDING_Y + TIP_TITLE_BLOCK - 6) * scale
	line:ClearAllPoints()
	line:SetPoint('TOPLEFT', frame, 'TOPLEFT', TIP_PADDING_X * scale, offsetY)
	line:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -TIP_PADDING_X * scale, offsetY)
	line:Show()
	return line
end

local HTML_TEXT_TYPES = { 'P', 'H1', 'H2', 'H3' }

function Skin.TipFont(fontString, kind, scale)
	if not fontString then return end
	local color = TIP_BODY_COLOR
	local size = TIP_BODY_SIZE
	if kind == 'title' then
		color, size = TIP_TITLE_COLOR, TIP_TITLE_SIZE
	elseif kind == 'label' then
		color = TIP_LABEL_COLOR
	end
	size = math.floor(size * (scale or 1) + 0.5)
	if fontString.GetObjectType and fontString:GetObjectType() == 'SimpleHTML' then
		local titleSize = math.floor(TIP_TITLE_SIZE * (scale or 1) + 0.5)
		for _, textType in ipairs(HTML_TEXT_TYPES) do
			local isHeader = textType ~= 'P'
			local typeColor = isHeader and TIP_TITLE_COLOR or color
			fontString:SetFont(textType, BUILib.Font, isHeader and titleSize or size, '')
			fontString:SetTextColor(textType, typeColor[1], typeColor[2], typeColor[3], typeColor[4])
			fontString:SetShadowColor(textType, 0, 0, 0, 0)
			fontString:SetShadowOffset(textType, 0, 0)
		end
		return
	end
	fontString:SetFont(BUILib.Font, size, '')
	fontString:SetTextColor(color[1], color[2], color[3], color[4])
	fontString:SetShadowColor(0, 0, 0, 0)
	fontString:SetShadowOffset(0, 0)
end

local buttonFonts = {}

local function ButtonFontObjects(scale)
	local size = math.floor(TIP_BODY_SIZE * (scale or 1) + 0.5)
	local fonts = buttonFonts[size]
	if not fonts then
		local normal = CreateFont('BUI_TipButtonFont' .. size)
		normal:SetFont(BUILib.Font, size, '')
		normal:SetTextColor(TIP_BODY_COLOR[1], TIP_BODY_COLOR[2], TIP_BODY_COLOR[3], TIP_BODY_COLOR[4])
		normal:SetShadowColor(0, 0, 0, 0)
		normal:SetShadowOffset(0, 0)
		local disabled = CreateFont('BUI_TipButtonFontDisabled' .. size)
		disabled:SetFont(BUILib.Font, size, '')
		disabled:SetTextColor(TIP_LABEL_COLOR[1], TIP_LABEL_COLOR[2], TIP_LABEL_COLOR[3], TIP_LABEL_COLOR[4])
		disabled:SetShadowColor(0, 0, 0, 0)
		disabled:SetShadowOffset(0, 0)
		fonts = { normal = normal, disabled = disabled }
		buttonFonts[size] = fonts
	end
	return fonts
end

local function TipButtonEnter(button)
	local red, green, blue = BUILib.Theme.GetAccent()
	BUILib.Skin.SetEdgeColor(button._buiShell.edges, { red, green, blue, 1 })
end

local function TipButtonLeave(button)
	BUILib.Skin.SetEdgeColor(button._buiShell.edges, PANEL_EDGE)
end

function Skin.TipButton(button, scale)
	if not button then return end
	if not button._buiTipButton then
		button._buiTipButton = true
		BUILib.Skin.StripButton(button)
		HookScript(button, 'OnEnter', TipButtonEnter)
		HookScript(button, 'OnLeave', TipButtonLeave)
	end
	Skin.TipShell(button)
	local fonts = ButtonFontObjects(scale)
	if button.SetNormalFontObject then button:SetNormalFontObject(fonts.normal) end
	if button.SetHighlightFontObject then button:SetHighlightFontObject(fonts.normal) end
	if button.SetDisabledFontObject then button:SetDisabledFontObject(fonts.disabled) end
end

function Skin.TipCardSlider(card, config)
	local Layout = BUILib.Layout
	local Controls = BUILib.Controls
	local sliderHeight = Layout.HEIGHTS.slider
	local holder = CreateFrame('Frame', nil, card.child)
	holder:SetSize(card.width, sliderHeight)
	local anchorControl, anchorY = card:GetAnchor(14)
	if anchorControl then holder:SetPoint('TOPLEFT', anchorControl, 'BOTTOMLEFT', 0, anchorY) end
	card:SetLast(holder, 0)
	card:AddY(14 + sliderHeight)
	local slider = Controls.Slider(holder, config.label, config.min, config.max, config.value, config.callback,
		config.decimals or 0, nil, config.tooltip, config.step or 1, card.width)
	slider:SetPoint('TOPLEFT', holder, 'TOPLEFT', 0, 0)
	return slider
end

function Skin.TipScaleCard(content, key, onChange)
	local db = BUI.GetDB().skinning
	local card = BUILib.Layout.SettingsCard(content, { title = 'Size' })
	Skin.TipCardSlider(card, {
		label = 'Scale', min = 1, max = 2.5, value = db[key], step = 0.1, decimals = 0,
		tooltip = 'Overall size. 1 is tooltip size.',
		callback = function(value)
			db[key] = value
			if onChange then onChange() end
		end,
	})
	card:Refresh()
	return card
end

local SHOWCASE_NAME = 'BUI_SkinShowcase'
local SHOWCASE_GAP = 4
local SHOWCASE_DRIFT_INTERVAL = 0.05
local SHOWCASE_MARGIN = 40
local SHOWCASE_TOP_RESERVE = 120
local SHOWCASE_DIM = { 0, 0, 0, 0.75 }
local SHOWCASE_STRATA = 'TOOLTIP'
local SHOWCASE_QUEUE_KEY = 'Skin.ShowcaseQueue'
local SHOWCASE_STEP_INTERVAL = 0.05
local showcaseQueue = {}
local showcase
local showcaseEntries = {}
local showcaseActive = false
local showcaseOnClosed
local ShowcaseOnUpdate
local OnEntrySetPoint
local OnEntryStartMoving
local placingEntry = false

local function EnsureShowcase()
	if showcase then return showcase end
	showcase = CreateFrame('Frame', SHOWCASE_NAME, UIParent)
	showcase:SetAllPoints(UIParent)
	showcase:SetFrameStrata('FULLSCREEN_DIALOG')
	showcase:EnableMouse(true)
	showcase:Hide()
	local dim = showcase:CreateTexture(nil, 'BACKGROUND')
	dim:SetAllPoints(showcase)
	dim:SetColorTexture(SHOWCASE_DIM[1], SHOWCASE_DIM[2], SHOWCASE_DIM[3], SHOWCASE_DIM[4])
	local title = showcase:CreateFontString(nil, 'OVERLAY')
	Skin.TipFont(title, 'title', 3.2)
	title:SetPoint('TOP', showcase, 'TOP', 0, -SHOWCASE_MARGIN * 0.5)
	title:SetText('BluUI Skins')
	local hint = showcase:CreateFontString(nil, 'OVERLAY')
	Skin.TipFont(hint, 'body', 1.8)
	hint:SetPoint('TOP', title, 'BOTTOM', 0, -8)
	hint:SetText('Press Escape to close the showcase')
	SetScript(showcase, 'OnHide', function() if showcaseActive then Skin.StopTest() end end)
	SetScript(showcase, 'OnUpdate', ShowcaseOnUpdate)
	return showcase
end

local function RememberPlacement(entry)
	local frame = entry.frame
	local points = {}
	for pointIndex = 1, frame:GetNumPoints() do
		points[pointIndex] = { frame:GetPoint(pointIndex) }
	end
	entry.points = points
	entry.strata = frame:GetFrameStrata()
end

local function OnShowcaseFrameHidden(frame)
	if not showcaseActive then return end
	for _, entry in ipairs(showcaseEntries) do
		if entry.frame == frame then
			Skin.StopTest()
			return
		end
	end
end

local function WatchShowcaseFrame(frame)
	if frame.__buiShowcaseWatched then return end
	frame.__buiShowcaseWatched = true
	HookScript(frame, 'OnHide', OnShowcaseFrameHidden)
	hooksecurefunc(frame, 'SetPoint', OnEntrySetPoint)
	hooksecurefunc(frame, 'StartMoving', OnEntryStartMoving)
end

local function RestorePlacement(entry)
	local frame = entry.frame
	if entry.strata then frame:SetFrameStrata(entry.strata) end
	local points = entry.points
	if not points then return end
	frame:ClearAllPoints()
	for pointIndex = 1, #points do
		local point = points[pointIndex]
		frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
	end
end

local function FrameExtent(frame)
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return frame:GetWidth() * scale, frame:GetHeight() * scale, scale
end

local function PlaceEntry(entry, left, top)
	local frame = entry.frame
	local _, _, scale = FrameExtent(frame)
	entry.left, entry.top = left, top
	placingEntry = true
	frame:ClearAllPoints()
	frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left / scale, top / scale)
	placingEntry = false
	if frame:GetFrameStrata() ~= SHOWCASE_STRATA then frame:SetFrameStrata(SHOWCASE_STRATA) end
end

function OnEntrySetPoint(frame)
	if placingEntry or not showcaseActive then return end
	for _, entry in ipairs(showcaseEntries) do
		if entry.frame == frame then
			if entry.left and not entry.released then PlaceEntry(entry, entry.left, entry.top) end
			return
		end
	end
end

function OnEntryStartMoving(frame)
	if not showcaseActive then return end
	for _, entry in ipairs(showcaseEntries) do
		if entry.frame == frame then
			entry.released = true
			return
		end
	end
end

local function LayoutShowcase()
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local maxRowWidth = screenWidth - 2 * SHOWCASE_MARGIN
	local ordered = {}
	for index, entry in ipairs(showcaseEntries) do
		if not entry.released then
			entry.width, entry.height = FrameExtent(entry.frame)
			entry.order = index
			ordered[#ordered + 1] = entry
		end
	end
	table.sort(ordered, function(a, b)
		if a.height ~= b.height then return a.height > b.height end
		return a.order < b.order
	end)
	local rows, row, rowWidth, rowHeight = {}, nil, 0, 0
	local function CloseRow()
		if row then rows[#rows + 1] = { entries = row, width = rowWidth - SHOWCASE_GAP, height = rowHeight } end
	end
	for _, entry in ipairs(ordered) do
		if row and rowWidth + entry.width > maxRowWidth then
			CloseRow()
			row = nil
		end
		if not row then row, rowWidth, rowHeight = {}, 0, 0 end
		row[#row + 1] = entry
		rowWidth = rowWidth + entry.width + SHOWCASE_GAP
		if entry.height > rowHeight then rowHeight = entry.height end
	end
	CloseRow()
	local totalHeight = -SHOWCASE_GAP
	for _, rowInfo in ipairs(rows) do totalHeight = totalHeight + rowInfo.height + SHOWCASE_GAP end
	local bandTop = screenHeight - SHOWCASE_TOP_RESERVE
	local bandHeight = bandTop - SHOWCASE_MARGIN
	local cursorY = bandTop - math.max(0, (bandHeight - totalHeight) / 2)
	for _, rowInfo in ipairs(rows) do
		local cursorX = (screenWidth - rowInfo.width) / 2
		for _, entry in ipairs(rowInfo.entries) do
			PlaceEntry(entry, cursorX, cursorY)
			cursorX = cursorX + entry.width + SHOWCASE_GAP
		end
		cursorY = cursorY - rowInfo.height - SHOWCASE_GAP
	end
end

local function ShowcaseDrifted()
	for _, entry in ipairs(showcaseEntries) do
		if not entry.released then
			local width, height = FrameExtent(entry.frame)
			if math.abs(width - (entry.width or 0)) > 0.5 or math.abs(height - (entry.height or 0)) > 0.5 then return true end
		end
	end
	return false
end

local sinceDriftCheck = 0
function ShowcaseOnUpdate(_, elapsed)
	sinceDriftCheck = sinceDriftCheck + elapsed
	if sinceDriftCheck < SHOWCASE_DRIFT_INTERVAL then return end
	sinceDriftCheck = 0
	if showcaseActive and ShowcaseDrifted() then LayoutShowcase() end
end

function Skin.StopTest()
	if not showcaseActive then return end
	showcaseActive = false
	BUI.Scheduler.UnregisterUpdate(SHOWCASE_QUEUE_KEY)
	wipe(showcaseQueue)
	local stopped = {}
	for _, entry in ipairs(showcaseEntries) do
		RestorePlacement(entry)
		local info = skinRegistry[entry.id]
		if info.stopTest and not stopped[entry.id] then
			stopped[entry.id] = true
			info.stopTest()
		end
	end
	wipe(showcaseEntries)
	showcase:Hide()
	tDeleteItem(UISpecialFrames, SHOWCASE_NAME)
	local onClosed = showcaseOnClosed
	showcaseOnClosed = nil
	if onClosed then onClosed() end
end

local function CollectPreviewFrames(id, info, ok, ...)
	if not ok then
		BUI.Print(('Skin preview failed for %s.'):format(info.name or id))
		return
	end
	for resultIndex = 1, select('#', ...) do
		local frame = select(resultIndex, ...)
		if type(frame) == 'table' and frame.GetNumPoints then
			local entry = { id = id, frame = frame, name = info.name }
			RememberPlacement(entry)
			WatchShowcaseFrame(frame)
			frame:SetFrameStrata(SHOWCASE_STRATA)
			showcaseEntries[#showcaseEntries + 1] = entry
		end
	end
end

local function StepShowcase()
	if not showcaseActive then return end
	local id = table.remove(showcaseQueue, 1)
	if id then
		local info = skinRegistry[id]
		CollectPreviewFrames(id, info, pcall(info.test))
		LayoutShowcase()
	end
	if #showcaseQueue > 0 then return end

	BUI.Scheduler.UnregisterUpdate(SHOWCASE_QUEUE_KEY)
	local frameCount = #showcaseEntries
	if frameCount == 0 then
		BUI.Print('No enabled skin has a preview.')
		Skin.StopTest()
		return
	end
	BUI.Print(('Showcasing %d skin window%s. Press Escape to close.'):format(frameCount, frameCount == 1 and '' or 's'))
end

function Skin.Test(onClosed, ids)
	Skin.StopTest()
	if not ids then return end
	if InCombatLockdown() then
		BUI.Print('Skin showcase is unavailable in combat.')
		return
	end

	wipe(showcaseQueue)
	for _, id in ipairs(ids) do
		local info = skinRegistry[id]
		if info and info.test and Skin.IsSkinEnabled(id) then
			showcaseQueue[#showcaseQueue + 1] = id
		end
	end
	if #showcaseQueue == 0 then
		BUI.Print('No enabled skin has a preview.')
		return
	end

	showcaseActive = true
	showcaseOnClosed = onClosed
	EnsureShowcase():Show()
	if not tContains(UISpecialFrames, SHOWCASE_NAME) then tinsert(UISpecialFrames, SHOWCASE_NAME) end
	BUI.Scheduler.RegisterUpdate(SHOWCASE_QUEUE_KEY, StepShowcase, SHOWCASE_STEP_INTERVAL, true)
	return true
end

function Skin.TipFace(fontString, kind, scale)
	if not fontString then return end
	local size = kind == 'title' and TIP_TITLE_SIZE or TIP_BODY_SIZE
	size = math.floor(size * (scale or 1) + 0.5)
	if fontString.GetObjectType and fontString:GetObjectType() == 'SimpleHTML' then
		for _, textType in ipairs(HTML_TEXT_TYPES) do
			fontString:SetFont(textType, BUILib.Font, size, '')
			fontString:SetShadowColor(textType, 0, 0, 0, 0)
			fontString:SetShadowOffset(textType, 0, 0)
		end
		return
	end
	fontString:SetFont(BUILib.Font, size, '')
	fontString:SetShadowColor(0, 0, 0, 0)
	fontString:SetShadowOffset(0, 0)
end

function Skin.FadeTree(frame, keep, depth)
	if not frame or frame:IsForbidden() then return end
	depth = depth or 0
	if frame.GetRegions then
		for regionIndex = 1, select('#', frame:GetRegions()) do
			local region = select(regionIndex, frame:GetRegions())
			if region and region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin and not (keep and keep[region]) then
				region:SetAlpha(0)
			end
		end
	end
	if depth < 4 and frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do
			Skin.FadeTree(child, keep, depth + 1)
		end
	end
end


local SCROLL_THUMB_REST, SCROLL_THUMB_HOVER, SCROLL_THUMB_DRAG = 0.35, 0.6, 0.85
local SCROLL_ARROW_SIZE = 10

local function ThumbFill(thumb, alpha)
	local red, green, blue = BUILib.Theme.GetAccent()
	thumb._buiThumbFill:SetColorTexture(red, green, blue, alpha)
end

local function ThumbEnter(thumb)
	if not thumb._buiDragging then ThumbFill(thumb, SCROLL_THUMB_HOVER) end
end

local function ThumbLeave(thumb)
	if not thumb._buiDragging then ThumbFill(thumb, SCROLL_THUMB_REST) end
end

local function ThumbDown(thumb)
	thumb._buiDragging = true
	ThumbFill(thumb, SCROLL_THUMB_DRAG)
end

local function ThumbUp(thumb)
	thumb._buiDragging = false
	ThumbFill(thumb, thumb:IsMouseOver() and SCROLL_THUMB_HOVER or SCROLL_THUMB_REST)
end

local function ArrowEnter(button)
	local red, green, blue = BUILib.Theme.GetAccent()
	button._buiTipArrow:SetVertexColor(red, green, blue, 1)
end

local function ArrowLeave(button)
	local color = BUILib.Theme.text.secondary
	button._buiTipArrow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

local function ScrollStepper(button, rotation)
	if not button or button._buiTipArrow then return end
	local arrow = Skin.TipArrow(button, true, rotation)
	arrow:SetSize(SCROLL_ARROW_SIZE, SCROLL_ARROW_SIZE)
	HookScript(button, 'OnEnter', ArrowEnter)
	HookScript(button, 'OnLeave', ArrowLeave)
end

local function FadeStepperArt(button)
	if button and button.Texture then button.Texture:SetAlpha(0) end
end

function Skin.TipScrollBar(scrollBar, keepThumb)
	if not scrollBar or scrollBar._buiTipScroll then return end
	scrollBar._buiTipScroll = true
	local track = scrollBar.Track
	if keepThumb then
		FadeStepperArt(scrollBar.Back)
		FadeStepperArt(scrollBar.Forward)
		if track then
			if track.Begin then track.Begin:SetAlpha(0) end
			if track.Middle then track.Middle:SetAlpha(0) end
			if track.End then track.End:SetAlpha(0) end
		end
		return
	end
	Skin.FadeTree(scrollBar)
	ScrollStepper(scrollBar.Back, math.pi)
	ScrollStepper(scrollBar.Forward, 0)
	local thumb = track and track.Thumb
	if not thumb then return end
	local fill = thumb:CreateTexture(nil, 'OVERLAY')
	fill.__buiSkin = true
	fill:SetPoint('TOPLEFT', thumb, 'TOPLEFT', 1, 0)
	fill:SetPoint('BOTTOMRIGHT', thumb, 'BOTTOMRIGHT', -1, 0)
	thumb._buiThumbFill = fill
	ThumbFill(thumb, SCROLL_THUMB_REST)
	HookScript(thumb, 'OnEnter', ThumbEnter)
	HookScript(thumb, 'OnLeave', ThumbLeave)
	HookScript(thumb, 'OnMouseDown', ThumbDown)
	HookScript(thumb, 'OnMouseUp', ThumbUp)
end

local EDIT_BOX_ART = {
	'Left', 'Middle', 'Right', 'LeftTexture', 'MiddleTexture', 'RightTexture', 'Backdrop',
	'TopLeftBorder', 'TopRightBorder', 'TopBorder', 'BottomLeftBorder', 'BottomRightBorder', 'BottomBorder',
	'LeftBorder', 'RightBorder', 'MiddleBorder',
}

function Skin.TipEditBox(editBox, scale, inset)
	if not editBox then return end
	if not editBox._buiTipEdit then
		editBox._buiTipEdit = true
		local name = editBox.GetName and editBox:GetName()
		for keyIndex = 1, #EDIT_BOX_ART do
			local key = EDIT_BOX_ART[keyIndex]
			local texture = editBox[key] or (name and _G[name .. key])
			if texture and texture.SetAlpha then texture:SetAlpha(0) end
		end
	end
	Skin.TipShell(editBox, inset)
	Skin.TipFace(editBox, 'body', scale)
end

local TAB_STYLE = BUILib.Skin.TabStyle({ fill = PANEL_FILL, edge = PANEL_EDGE, disabledText = TIP_LABEL_COLOR, fontSize = TIP_TITLE_SIZE })

Skin.TIP_TAB_INSET = BUILib.Skin.TAB_INSET

function Skin.TipTabSelected(tab, selected)
	BUILib.Skin.SetTabSelected(tab, selected)
end

function Skin.TipTab(tab, fused)
	BUILib.Skin.Tab(tab, TAB_STYLE, fused)
end

function Skin.TipArrow(frame, centered, rotation)
	local arrow = frame._buiTipArrow
	if not arrow then
		arrow = frame:CreateTexture(nil, 'OVERLAY')
		arrow.__buiSkin = true
		arrow:SetTexture(BUILib.GetLibMedia('dropdown'))
		arrow:SetSize(11, 11)
		if centered then
			arrow:SetPoint('CENTER', frame, 'CENTER', 0, 0)
		else
			arrow:SetPoint('RIGHT', frame, 'RIGHT', -6, 0)
		end
		if rotation then arrow:SetRotation(rotation) end
		local color = BUILib.Theme.text.secondary
		arrow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
		frame._buiTipArrow = arrow
	end
	arrow:Show()
	return arrow
end

function Skin.TipDropdown(dropdown, scale, keepHeight)
	if not dropdown then return end
	if not dropdown._buiTipDropdown then
		dropdown._buiTipDropdown = true
		for regionIndex = 1, select('#', dropdown:GetRegions()) do
			local region = select(regionIndex, dropdown:GetRegions())
			if region and region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then
				region:SetAlpha(0)
			end
		end
	end
	Skin.TipShell(dropdown)
	Skin.TipArrow(dropdown)
	if not keepHeight then Skin.NormalizeDropdownHeight(dropdown) end
	if dropdown.Text then Skin.TipFace(dropdown.Text, 'body', scale) end
end

local CLOSE_IDLE = { 0.75, 0.75, 0.8, 1 }

local function CloseEnter(button)
	local red, green, blue = BUILib.Theme.GetAccent()
	button._buiCloseGlyph:SetVertexColor(red, green, blue, 1)
end

local function CloseLeave(button)
	button._buiCloseGlyph:SetVertexColor(CLOSE_IDLE[1], CLOSE_IDLE[2], CLOSE_IDLE[3], CLOSE_IDLE[4])
end

function Skin.TipClose(button)
	if not button or button._buiCloseGlyph then return end
	BUILib.Skin.StripButton(button)
	local glyph = button:CreateTexture(nil, 'OVERLAY')
	glyph.__buiSkin = true
	glyph:SetTexture(BUILib.GetLibMedia('x'))
	glyph:SetSize(12, 12)
	glyph:SetPoint('CENTER', button, 'CENTER', 0, 0)
	glyph:SetVertexColor(CLOSE_IDLE[1], CLOSE_IDLE[2], CLOSE_IDLE[3], CLOSE_IDLE[4])
	button._buiCloseGlyph = glyph
	HookScript(button, 'OnEnter', CloseEnter)
	HookScript(button, 'OnLeave', CloseLeave)
end

local STATE_TEXTURE_GETTERS = { 'GetNormalTexture', 'GetPushedTexture', 'GetHighlightTexture', 'GetDisabledTexture' }

local function FadeStateTextures(button)
	for getterIndex = 1, #STATE_TEXTURE_GETTERS do
		local getter = button[STATE_TEXTURE_GETTERS[getterIndex]]
		local texture = getter and getter(button)
		if texture then texture:SetAlpha(0) end
	end
end

local CHECK_INSET = 4
local CHECK_GLYPH_GAP = 3

local function PlaceCheckGlyph(check, texture, color, glyphInset)
	if not texture then return end
	texture:SetTexCoord(0, 1, 0, 1)
	texture:ClearAllPoints()
	texture:SetPoint('TOPLEFT', check, 'TOPLEFT', glyphInset, -glyphInset)
	texture:SetPoint('BOTTOMRIGHT', check, 'BOTTOMRIGHT', -glyphInset, glyphInset)
	texture:SetBlendMode('BLEND')
	texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

function Skin.TipCheckGlyph(check, muted)
	local inset = check._buiCheckInset
	if not inset then return end
	local glyph = BUILib.GetLibMedia('check')
	check:SetCheckedTexture(glyph)
	check:SetDisabledCheckedTexture(glyph)
	local color = TIP_LABEL_COLOR
	if not muted then
		local red, green, blue = BUILib.Theme.GetAccent()
		color = { red, green, blue, 1 }
	end
	PlaceCheckGlyph(check, check:GetCheckedTexture(), color, inset + CHECK_GLYPH_GAP)
	PlaceCheckGlyph(check, check:GetDisabledCheckedTexture(), TIP_LABEL_COLOR, inset + CHECK_GLYPH_GAP)
end

function Skin.TipCheckBox(check, inset)
	if not check then return end
	inset = inset or CHECK_INSET
	Skin.TipShell(check, inset)
	if check._buiTipCheck then return end
	check._buiTipCheck = true
	check._buiCheckInset = inset
	FadeStateTextures(check)
	Skin.TipCheckGlyph(check, false)
	Skin.TipFace(check.Text or (check.GetFontString and check:GetFontString()), 'body')
	HookScript(check, 'OnEnter', TipButtonEnter)
	HookScript(check, 'OnLeave', TipButtonLeave)
end

local BACKDROP_BUTTON_ART = { 'Left', 'Middle', 'Right', 'LeftDisabled', 'MiddleDisabled', 'RightDisabled' }

local function BackdropButtonEnter(button)
	local red, green, blue = BUILib.Theme.GetAccent()
	button:SetBackdropBorderColor(red, green, blue, 1)
end

local function BackdropButtonLeave(button)
	button:SetBackdropBorderColor(PANEL_EDGE[1], PANEL_EDGE[2], PANEL_EDGE[3], PANEL_EDGE[4])
end

function Skin.TipBackdropButton(button, scale)
	if not button then return end
	if not button._buiTipBackdrop then
		button._buiTipBackdrop = true
		FadeStateTextures(button)
		local name = button.GetName and button:GetName()
		for artIndex = 1, #BACKDROP_BUTTON_ART do
			local key = BACKDROP_BUTTON_ART[artIndex]
			local texture = button[key] or (name and _G[name .. key])
			if texture and texture.SetAlpha then texture:SetAlpha(0) end
		end
		Skin.ApplyBackdrop(button, PANEL_FILL, PANEL_EDGE)
		HookScript(button, 'OnEnter', BackdropButtonEnter)
		HookScript(button, 'OnLeave', BackdropButtonLeave)
	end
	local fonts = ButtonFontObjects(scale)
	if button.SetNormalFontObject then button:SetNormalFontObject(fonts.normal) end
	if button.SetHighlightFontObject then button:SetHighlightFontObject(fonts.normal) end
	if button.SetDisabledFontObject then button:SetDisabledFontObject(fonts.disabled) end
end

function Skin.TipFaceTree(frame, depth, kind)
	if not frame or frame:IsForbidden() then return end
	depth = depth or 2
	if frame.GetRegions then
		for regionIndex = 1, select('#', frame:GetRegions()) do
			local region = select(regionIndex, frame:GetRegions())
			if region and region.IsObjectType and region:IsObjectType('FontString') then
				Skin.TipFace(region, kind or 'body')
			end
		end
	end
	if depth > 1 and frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do
			Skin.TipFaceTree(child, depth - 1, kind)
		end
	end
end

Skin.PANEL_FILL = PANEL_FILL
Skin.PANEL_EDGE = PANEL_EDGE

local HELP_BUTTON_DEPTH = 4

local function IsHelpArt(texture)
	local art = texture.GetAtlas and texture:GetAtlas() or texture.GetTexture and texture:GetTexture()
	return type(art) == 'string' and art:lower():find('help', 1, true) ~= nil
end

local function IsHelpPlateButton(child)
	if not child.Ring or not child.IsObjectType or not child:IsObjectType('Button') then return false end
	return child.I ~= nil or IsHelpArt(child.Ring)
end

function Skin.HideHelpButtons(frame, depth)
	if not frame or not frame.GetChildren or frame:IsForbidden() then return end
	depth = depth or HELP_BUTTON_DEPTH
	for _, child in ipairs({ frame:GetChildren() }) do
		if IsHelpPlateButton(child) then
			if not child._buiHelpHidden then
				child._buiHelpHidden = true
				child:SetAlpha(0)
				child:EnableMouse(false)
			end
		elseif depth > 1 then
			Skin.HideHelpButtons(child, depth - 1)
		end
	end
end

local PANEL_ART = { 'NineSlice', 'Bg', 'Border', 'Inset', 'TopTileStreaks', 'ScrollFrameBorder' }
Skin.PANEL_ART = PANEL_ART
local ROW_HIGHLIGHT_ALPHA = 0.22
local ICON_CROP = 0.08

function Skin.FlatTexture(texture, red, green, blue, alpha)
	if not texture then return end
	texture:SetColorTexture(red, green, blue, alpha)
end

function Skin.AccentTexture(texture, alpha)
	if not texture then return end
	local red, green, blue = BUILib.Theme.GetAccent()
	texture:SetColorTexture(red, green, blue, alpha)
end

function Skin.RowHighlight(button, alpha)
	Skin.AccentTexture(button.GetHighlightTexture and button:GetHighlightTexture(), alpha or ROW_HIGHLIGHT_ALPHA)
end

function Skin.CropIcon(icon)
	if icon then icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP) end
end

local function LayoutIconEdges(edges, icon, thickness)
	edges[1]:ClearAllPoints()
	edges[1]:SetPoint('BOTTOMLEFT', icon, 'TOPLEFT', -thickness, 0); edges[1]:SetPoint('BOTTOMRIGHT', icon, 'TOPRIGHT', thickness, 0); edges[1]:SetHeight(thickness)
	edges[2]:ClearAllPoints()
	edges[2]:SetPoint('TOPLEFT', icon, 'BOTTOMLEFT', -thickness, 0); edges[2]:SetPoint('TOPRIGHT', icon, 'BOTTOMRIGHT', thickness, 0); edges[2]:SetHeight(thickness)
	edges[3]:ClearAllPoints()
	edges[3]:SetPoint('TOPRIGHT', icon, 'TOPLEFT', 0, thickness); edges[3]:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMLEFT', 0, -thickness); edges[3]:SetWidth(thickness)
	edges[4]:ClearAllPoints()
	edges[4]:SetPoint('TOPLEFT', icon, 'TOPRIGHT', 0, thickness); edges[4]:SetPoint('BOTTOMLEFT', icon, 'BOTTOMRIGHT', 0, -thickness); edges[4]:SetWidth(thickness)
end

function Skin.TipIconFrame(parent, icon, thickness)
	if not icon or icon._buiIconFrame then return end
	local edges = {}
	for edgeIndex = 1, 4 do
		edges[edgeIndex] = parent:CreateTexture(nil, 'OVERLAY')
		edges[edgeIndex].__buiSkin = true
	end
	LayoutIconEdges(edges, icon, thickness or 1)
	BUILib.Skin.SetEdgeColor(edges, PANEL_EDGE)
	icon._buiIconFrame = edges
end

function Skin.SetIconEdgeThickness(icon, thickness)
	local edges = icon and icon._buiIconFrame
	if not edges then return end
	if thickness <= 0 then
		for edgeIndex = 1, 4 do edges[edgeIndex]:Hide() end
		return
	end
	for edgeIndex = 1, 4 do edges[edgeIndex]:Show() end
	LayoutIconEdges(edges, icon, thickness)
end

local iconEdgeColor = { 0, 0, 0, 1 }

function Skin.SetIconEdgeColor(icon, red, green, blue)
	local edges = icon and icon._buiIconFrame
	if not edges then return end
	if red then
		local secret = issecretvalue and (issecretvalue(red) or issecretvalue(green) or issecretvalue(blue))
		if not secret and icon._buiEdgeR == red and icon._buiEdgeG == green and icon._buiEdgeB == blue then return end
		if secret then
			icon._buiEdgeR, icon._buiEdgeG, icon._buiEdgeB = nil, nil, nil
		else
			icon._buiEdgeR, icon._buiEdgeG, icon._buiEdgeB = red, green, blue
		end
		iconEdgeColor[1], iconEdgeColor[2], iconEdgeColor[3] = red, green, blue
		BUILib.Skin.SetEdgeColor(edges, iconEdgeColor)
	else
		if icon._buiEdgeR == false then return end
		icon._buiEdgeR, icon._buiEdgeG, icon._buiEdgeB = false, nil, nil
		BUILib.Skin.SetEdgeColor(edges, PANEL_EDGE)
	end
end

function Skin.SetIconEdgeQuality(icon, border)
	if border and border:IsShown() then
		Skin.SetIconEdgeColor(icon, border:GetVertexColor())
	else
		Skin.SetIconEdgeColor(icon)
	end
end

function Skin.SetIconEdgeRarity(icon, quality)
	local color = quality and quality > 1 and ITEM_QUALITY_COLORS[quality]
	if color then
		Skin.SetIconEdgeColor(icon, color.r, color.g, color.b)
	else
		Skin.SetIconEdgeColor(icon)
	end
end

function Skin.SetIconEdgeItemQuality(icon, item)
	Skin.SetIconEdgeRarity(icon, item and C_Item.GetItemQualityByID(item))
end

function Skin.TipShellEdges(frame, accent)
	if accent then
		local red, green, blue = BUILib.Theme.GetAccent()
		BUILib.Skin.SetShellEdges(frame, { red, green, blue, 1 })
	else
		BUILib.Skin.SetShellEdges(frame, PANEL_EDGE)
	end
end

local SIDE_TAB_WIDTH, SIDE_TAB_HEIGHT = 30, 40
local SIDE_TAB_GAP = 4
local SIDE_TAB_EDGE_GAP = 2
local SIDE_TAB_SELECTED_ALPHA = 0.3
local SIDE_TAB_HOVER_ALPHA = 0.15
local NO_OPTIONS = {}
local SIDE_TAB_ICON_KEYS = { 'Icon' }
local sideTabHooker = BUI.Prof.MakeHooker('skin')

local function CenterSideTabIcon(icon)
	if icon._buiCentering then return end
	local point, _, relativePoint, offsetX, offsetY = icon:GetPoint(1)
	if point == 'CENTER' and relativePoint == 'CENTER' and offsetX == 0 and offsetY == 0 then return end
	icon._buiCentering = true
	icon:ClearAllPoints()
	icon:SetPoint('CENTER')
	icon._buiCentering = nil
end

local function FitToTab(texture, tab)
	texture.__buiSkin = true
	texture:ClearAllPoints()
	texture:SetAllPoints(tab)
end

function Skin.SideTab(context, tab, options)
	if not tab then return end
	options = options or NO_OPTIONS
	if not tab._buiSideTab then
		tab._buiSideTab = true
		for _, key in ipairs(options.iconKeys or SIDE_TAB_ICON_KEYS) do
			local icon = tab[key]
			if icon then
				icon.__buiSkin = true
				if options.crop then Skin.CropIcon(icon) end
				if options.iconWidth then icon:SetSize(options.iconWidth, options.iconHeight or options.iconWidth) end
				CenterSideTabIcon(icon)
				sideTabHooker(icon, 'SetPoint', CenterSideTabIcon)
			end
		end
		if tab.IconOverlay then tab.IconOverlay.__buiSkin = true end
		if tab.TabGlow then FitToTab(tab.TabGlow, tab) end
		local selected = tab:CreateTexture(nil, 'ARTWORK', nil, -1)
		FitToTab(selected, tab)
		selected:Hide()
		tab._buiSideSelected = selected
		local hover = tab:CreateTexture(nil, 'HIGHLIGHT')
		FitToTab(hover, tab)
		hover:SetColorTexture(1, 1, 1, SIDE_TAB_HOVER_ALPHA)
		tab._buiSideHover = hover
	end
	tab:SetSize(options.width or SIDE_TAB_WIDTH, options.height or SIDE_TAB_HEIGHT)
	context.FadeRegions(tab)
	context.Shell(tab)
	Skin.AccentTexture(tab._buiSideSelected, SIDE_TAB_SELECTED_ALPHA)
	if tab.TabGlow then Skin.AccentTexture(tab.TabGlow, SIDE_TAB_SELECTED_ALPHA) end
	tab._buiSideHover:Show()
end

function Skin.SetSideTabSelected(tab, selected)
	local overlay = tab and tab._buiSideSelected
	if overlay then overlay:SetShown(selected == true) end
end

function Skin.ResetSideTab(tab)
	if not tab or not tab._buiSideTab then return end
	tab._buiSideSelected:Hide()
	tab._buiSideHover:Hide()
end

function Skin.LayoutSideTabs(host, tabs, topOffset)
	local previous
	for _, tab in ipairs(tabs) do
		if tab and tab._buiSideTab and tab:IsShown() then
			tab:ClearAllPoints()
			if previous then
				tab:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, -SIDE_TAB_GAP)
			else
				tab:SetPoint('TOPLEFT', host, 'TOPRIGHT', SIDE_TAB_EDGE_GAP, topOffset)
			end
			previous = tab
		end
	end
end

function Skin.NewContext(enabled)
	local fadedArt, shelled = {}, {}
	local context = { enabled = enabled }

	local function Fade(object)
		if not object or fadedArt[object] or not object.SetAlpha then return end
		fadedArt[object] = true
		object:SetAlpha(0)
	end

	local function FadeRegions(frame)
		if not frame or not frame.GetRegions then return end
		for regionIndex = 1, select('#', frame:GetRegions()) do
			local region = select(regionIndex, frame:GetRegions())
			if region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then Fade(region) end
		end
	end

	local function FadeKeys(frame, keys)
		if not frame then return end
		for keyIndex = 1, #keys do
			local child = frame[keys[keyIndex]]
			if child and child.IsObjectType then
				if child:IsObjectType('Texture') then
					Fade(child)
				else
					FadeRegions(child)
					Fade(child.NineSlice)
				end
			end
		end
	end

	local function FadeArt(frame)
		if not frame then return end
		FadeRegions(frame)
		FadeKeys(frame, PANEL_ART)
	end

	local function Shell(frame, inset)
		if not frame then return end
		shelled[frame] = true
		Skin.TipShell(frame, inset)
		Skin.HideHelpButtons(frame)
	end

	local function Button(button)
		if not button then return end
		shelled[button] = true
		Skin.TipButton(button)
	end

	local function Close(button)
		if button then Skin.TipClose(button) end
	end

	local function Dropdown(dropdown)
		if not dropdown then return end
		shelled[dropdown] = true
		Skin.TipDropdown(dropdown)
	end

	local function EditBox(editBox, inset)
		if not editBox then return end
		shelled[editBox] = true
		Skin.TipEditBox(editBox, nil, inset)
	end

	local function CheckBox(check, inset)
		if not check then return end
		shelled[check] = true
		Skin.TipCheckBox(check, inset)
	end

	local function TextBox(frame)
		if not frame then return end
		if frame.SetFont then
			EditBox(frame)
			return
		end
		FadeRegions(frame)
		Shell(frame)
		if frame.EditBox and frame.EditBox.SetFont then EditBox(frame.EditBox) end
	end

	local function ScrollBar(scrollBar, keepThumb)
		if scrollBar then Skin.TipScrollBar(scrollBar, keepThumb) end
	end

	local function Tab(tab, fused)
		if not tab then return end
		shelled[tab] = true
		Skin.TipTab(tab, fused)
	end

	local function Face(fontString)
		if fontString then Skin.TipFace(fontString, 'body') end
	end

	local function FaceOnce(fontString)
		if not fontString or fontString._buiFaced then return end
		fontString._buiFaced = true
		Skin.TipFace(fontString, 'body')
	end

	local function Title(fontString)
		if fontString then Skin.TipFont(fontString, 'title') end
	end

	local function Body(fontString)
		if fontString then Skin.TipFont(fontString, 'body') end
	end

	local function Restore()
		for object in pairs(fadedArt) do object:SetAlpha(1) end
		wipe(fadedArt)
		for frame in pairs(shelled) do Skin.HideTipShell(frame) end
	end

	context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt = Fade, FadeRegions, FadeKeys, FadeArt
	context.Shell, context.Button, context.Close, context.Dropdown = Shell, Button, Close, Dropdown
	context.EditBox, context.CheckBox, context.TextBox, context.ScrollBar, context.Tab = EditBox, CheckBox, TextBox, ScrollBar, Tab
	context.Face, context.FaceOnce, context.Title, context.Body, context.Restore = Face, FaceOnce, Title, Body, Restore
	return context
end

local tabStrips = {}
local tabHooksInstalled = false
local stripHooker = BUI.Prof.MakeHooker('skin')

function Skin.RefreshTabStrip(frame)
	local strip = tabStrips[frame]
	if not strip or not strip.context.enabled() then return end
	BUILib.Skin.RefreshTabStrip(frame, strip.tabs)
end

local function OnTabsChanged(frame)
	if tabStrips[frame] then Skin.RefreshTabStrip(frame) end
end

local function OnTabResized(tab)
	local parent = tab and tab.GetParent and tab:GetParent()
	if parent and tabStrips[parent] then Skin.RefreshTabStrip(parent) end
end

local function InstallTabHooks()
	if tabHooksInstalled then return end
	tabHooksInstalled = true
	stripHooker('PanelTemplates_UpdateTabs', OnTabsChanged)
	stripHooker('PanelTemplates_ShowTab', OnTabsChanged)
	stripHooker('PanelTemplates_HideTab', OnTabsChanged)
	stripHooker('PanelTemplates_TabResize', OnTabResized)
end

function Skin.RegisterTabStrip(frame, tabs, context)
	InstallTabHooks()
	tabStrips[frame] = { frame = frame, tabs = tabs, context = context }
	for tabIndex = 1, #tabs do context.Tab(tabs[tabIndex], true) end
	Skin.RefreshTabStrip(frame)
end

local tabSystems = {}

function Skin.RefreshTabSystem(tabSystem)
	local strip = tabSystems[tabSystem]
	if not strip or not strip.context.enabled() then return end
	local tabs = tabSystem.tabs
	for tabIndex = 1, #tabs do
		local tab = tabs[tabIndex]
		strip.context.Tab(tab, strip.panel ~= nil)
		Skin.TipTabSelected(tab, tab.isSelected == true)
	end
	if strip.panel then
		BUILib.Skin.LayoutTabStrip(strip.panel, tabs)
	else
		BUILib.Skin.LayoutTabStrip(tabSystem, tabs, 'TOPLEFT', 0, 0)
	end
end

function Skin.RegisterTabSystem(tabSystem, context, panel)
	if not tabSystem or tabSystems[tabSystem] then return end
	tabSystems[tabSystem] = { context = context, panel = panel }
	stripHooker(tabSystem, 'SetTab', Skin.RefreshTabSystem)
	stripHooker(tabSystem, 'Layout', Skin.RefreshTabSystem)
	Skin.RefreshTabSystem(tabSystem)
end

local ROLE_CHECK_SIZE = 18

function Skin.TipRoleButton(context, button)
	if not button or button._buiRole then return end
	button._buiRole = true
	local check = button.checkButton or button.CheckButton
	if check then
		check:SetScale(1)
		check:SetSize(ROLE_CHECK_SIZE, ROLE_CHECK_SIZE)
		context.CheckBox(check, 0)
	end
	context.Fade(button.shortageBorder)
end

local PAGE_ARROW_SIZE = 12
local PAGE_ARROW_IDLE = { 0.75, 0.75, 0.8, 1 }
local PAGE_ARROW_DISABLED_ALPHA = 0.35
local PAGE_ROTATION = { previous = -math.pi / 2, next = math.pi / 2, up = math.pi, down = 0, expand = math.pi * 0.75, condense = -math.pi * 0.25 }

local function PageArrowEnter(button)
	if not button:IsEnabled() then return end
	local red, green, blue = BUILib.Theme.GetAccent()
	button._buiTipArrow:SetVertexColor(red, green, blue, 1)
end

local function PageArrowLeave(button)
	button._buiTipArrow:SetVertexColor(PAGE_ARROW_IDLE[1], PAGE_ARROW_IDLE[2], PAGE_ARROW_IDLE[3], PAGE_ARROW_IDLE[4])
end

function Skin.RefreshPageButton(button)
	local arrow = button and button._buiTipArrow
	if arrow then arrow:SetAlpha(button:IsEnabled() and 1 or PAGE_ARROW_DISABLED_ALPHA) end
end

function Skin.TipPageButton(button, direction)
	if not button or button._buiPageArrow then return end
	button._buiPageArrow = true
	FadeStateTextures(button)
	local arrow = Skin.TipArrow(button, true, PAGE_ROTATION[direction] or 0)
	arrow:SetSize(PAGE_ARROW_SIZE, PAGE_ARROW_SIZE)
	PageArrowLeave(button)
	HookScript(button, 'OnEnter', PageArrowEnter)
	HookScript(button, 'OnLeave', PageArrowLeave)
	Skin.RefreshPageButton(button)
end

function Skin.SetPageButtonSkinned(button, skinned)
	if not button or not button._buiPageArrow then return end
	local alpha = 1
	if skinned then alpha = 0 end
	for getterIndex = 1, #STATE_TEXTURE_GETTERS do
		local getter = button[STATE_TEXTURE_GETTERS[getterIndex]]
		local texture = getter and getter(button)
		if texture then texture:SetAlpha(alpha) end
	end
	if button._buiTipArrow then button._buiTipArrow:SetShown(skinned) end
end

local sweepHooker = BUI.Prof.MakeHooker('skin')

function Skin.ForEachScrollFrame(box, callback)
	if not box or not box.ForEachFrame then return end
	if box.GetView and not box:GetView() then return end
	box:ForEachFrame(callback)
end

function Skin.SweepScrollBox(scrollBox, callback)
	if not scrollBox or scrollBox._buiSweep then return end
	scrollBox._buiSweep = true
	local function Sweep(box) Skin.ForEachScrollFrame(box, callback) end
	sweepHooker(scrollBox, 'Update', Sweep)
	Sweep(scrollBox)
end
