local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

local ShowMenu = Widget.ShowMenuAnimated
local HideMenu = Widget.HideMenuAnimated

local PADDING_X   = 6
local PADDING_Y   = 6
local ROW_HEIGHT  = 28
local TITLE_HEIGHT = 24
local TITLE_GAP   = 1
local SEPARATOR_HEIGHT = 11
local SEPARATOR_INSET = 8
local ICON_SIZE   = 14
local ICON_COLUMN = 22
local TEXT_INSET  = 10
local CHECK_SIZE  = 12
local CHECK_GAP   = 8
local FONT_SIZE   = 12
local TITLE_FONT_SIZE = 11
local SUBTLE_FONT_SIZE = 11
local DEFAULT_WIDTH = 230
local MAX_WIDTH   = 360
local MAX_ROWS    = 12
local MENU_RADIUS = 8
local ROW_RADIUS  = 6
local SELECTED_ALPHA = 0.12
local CONTROL_SELECTED = { 1, 1, 1, 0.06 }
local CONTROL_LINE = { 1, 1, 1, 0.1 }
local TRACK_WIDTH = 4
local TRACK_INSET = 4
local SHADOWS     = { { inset = -2, radius = 10, alpha = 0.3 }, { inset = -6, radius = 14, alpha = 0.12 } }
local WHITE       = "Interface\\Buttons\\WHITE8x8"
local SOLID       = { 1, 1, 1, 1 }
local CLEAR       = { 0, 0, 0, 0 }
local STATIC_CHECK = { texture = "Interface\\RaidFrame\\ReadyCheck-Ready", color = { 1, 1, 1, 1 } }

local unpack = unpack

local activeMenu

local function Palette(window)
	if not window then
		return {
			fill = Theme.bg.dark, edge = Theme.border.light, line = Theme.border.light, hover = Theme.bg.hover, selected = { 1, 1, 1, SELECTED_ALPHA },
			text = Theme.text.primary, muted = Theme.text.muted, disabled = Theme.text.disabled,
			thumb = Theme.scrollbar.thumb, check = STATIC_CHECK, font = BUILib.Font,
		}
	end
	local text = { window:Color('controlText') }
	return {
		square = true, fill = { window:Color('control') }, line = CONTROL_LINE, hover = BUILib.Layout.SOLID_HOVER, selected = CONTROL_SELECTED,
		text = text, muted = { window:Color('muted') }, disabled = { window:Color('faint') },
		thumb = { window:Color('faint') }, check = { texture = BUILib.GetLibMedia('check'), color = text }, font = window:FontPath('control'),
	}
end

local function CloseActive()
	if activeMenu and activeMenu:IsShown() then HideMenu(activeMenu) end
	activeMenu = nil
end

function Controls.ContextMenuIsMouseOver()
	return activeMenu ~= nil and activeMenu:IsShown() and activeMenu:IsMouseOver()
end

local function CleanTitle(title)
	title = Widget.StripColorCodes(title or '')
	local previous
	repeat
		previous = title
		title = title:gsub('%s*%[[^%]]*%]%s*$', '')
		title = title:gsub('%s*%([^%)]*%)%s*$', '')
	until title == previous
	return title
end

local function MakeRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row.round = Widget.DrawCardShape(row, ROW_RADIUS, SOLID, CLEAR, "BACKGROUND", 0, 0)
	row.round:Hide()
	row.flat = row:CreateTexture(nil, "BACKGROUND")
	row.flat:SetTexture(WHITE)
	row.flat:SetAllPoints()
	row.flat:Hide()

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON_SIZE, ICON_SIZE)
	row.icon:SetPoint("LEFT", TEXT_INSET, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.icon:Hide()

	row.check = row:CreateTexture(nil, "OVERLAY")
	row.check:SetSize(CHECK_SIZE, CHECK_SIZE)
	row.check:SetPoint("RIGHT", -TEXT_INSET, 0)
	row.check:Hide()

	row.sub = row:CreateFontString(nil, "OVERLAY")
	row.sub:SetJustifyH("RIGHT")
	row.sub:SetPoint("RIGHT", -(TEXT_INSET + CHECK_SIZE + CHECK_GAP), 0)
	row.sub:Hide()

	row.text = row:CreateFontString(nil, "OVERLAY")
	row.text:SetJustifyH("LEFT")
	row.text:SetWordWrap(false)
	row.text:SetPoint("RIGHT", -(TEXT_INSET + CHECK_SIZE + CHECK_GAP), 0)
	return row
end

local function PaintRow(row, palette, hovered)
	if hovered then
		row.hl:SetVertexColor(unpack(palette.hover))
		row.hl:Show()
	elseif row.selected then
		row.hl:SetVertexColor(unpack(palette.selected))
		row.hl:Show()
	else
		row.hl:Hide()
	end
end

local function ShowCheck(row, item, palette)
	row.selected = item.checked == true
	row.check:SetShown(row.selected)
	if row.selected then
		row.check:SetTexture(palette.check.texture)
		row.check:SetVertexColor(unpack(item.disabled and palette.disabled or palette.check.color))
		row.check:SetDesaturated(item.disabled and true or false)
	end
end

local function ShowSub(row, item)
	local hasSub = item.sub ~= nil and item.sub ~= ""
	row.sub:SetShown(hasSub)
	if hasSub then row.sub:SetText(item.sub) end
end

local function BindRow(row, item, onSelect, palette, textX)
	row.round:Hide()
	row.flat:Hide()
	row.hl = palette.square and row.flat or row.round
	row.text:SetFont(item.fontPath or palette.font, FONT_SIZE, "")
	row.sub:SetFont(palette.font, SUBTLE_FONT_SIZE, "")
	row.text:SetPoint("LEFT", textX, 0)
	row.text:SetText(item.text or "")
	row.icon:SetShown(item.icon ~= nil)
	if item.icon then row.icon:SetTexture(item.icon) end
	ShowCheck(row, item, palette)
	ShowSub(row, item)
	PaintRow(row, palette, false)

	if item.disabled then
		row.text:SetTextColor(unpack(palette.disabled))
		row.sub:SetTextColor(unpack(palette.disabled))
		row:EnableMouse(false)
		row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil); row:SetScript("OnClick", nil)
		return
	end

	row:EnableMouse(true)
	row.text:SetTextColor(unpack(palette.text))
	row.sub:SetTextColor(unpack(palette.muted))
	row:SetScript("OnEnter", function() PaintRow(row, palette, true) end)
	row:SetScript("OnLeave", function() PaintRow(row, palette, false) end)
	row:SetScript("OnClick", function()
		local keepOpen = false
		if item.callback then keepOpen = item.callback(item) == true end
		if onSelect then onSelect(item) end
		if not keepOpen then
			CloseActive()
			return
		end
		ShowCheck(row, item, palette)
		ShowSub(row, item)
		PaintRow(row, palette, row:IsMouseOver())
	end)
end

local function MakeTitle(parent)
	local wrap = CreateFrame("Frame", nil, parent)
	wrap:SetHeight(TITLE_HEIGHT)
	wrap.text = wrap:CreateFontString(nil, "OVERLAY")
	wrap.text:SetJustifyH("LEFT")
	wrap.text:SetWordWrap(false)
	wrap.text:SetPoint("RIGHT", -TEXT_INSET, 0)
	return wrap
end

local function MakeSeparator(parent)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE)
	line:SetHeight(1)
	return line
end

local sharedMenu, menuFill, menuEdge, menuSquare, scrollFrame, scrollChild, scrollTrack, scrollThumb, scrollLogic
local rowPool = {}
local titlePool = {}
local separatorPool = {}
local checkFrame

local function EnsureMenu()
	if sharedMenu then return sharedMenu end
	local menu = CreateFrame("Frame", nil, UIParent)
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:Hide()
	for index, shadow in ipairs(SHADOWS) do
		Widget.DrawCardShape(menu, shadow.radius, { 0, 0, 0, shadow.alpha }, CLEAR, "BACKGROUND", -8 + index, shadow.inset)
	end
	menuFill, menuEdge = Widget.DrawCardShape(menu, MENU_RADIUS, SOLID, SOLID, "BACKGROUND", 0, 0)
	menuSquare = menu:CreateTexture(nil, "BACKGROUND")
	menuSquare:SetTexture(WHITE)
	menuSquare:SetAllPoints()

	scrollFrame = CreateFrame("ScrollFrame", nil, menu)
	scrollFrame:SetPoint("TOPLEFT")
	scrollFrame:SetPoint("BOTTOMRIGHT")
	scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollFrame:SetScrollChild(scrollChild)

	scrollTrack = CreateFrame("Frame", nil, menu)
	scrollTrack:SetWidth(TRACK_WIDTH)
	scrollTrack:SetPoint("TOPRIGHT", -TRACK_INSET, -PADDING_Y)
	scrollTrack:SetPoint("BOTTOMRIGHT", -TRACK_INSET, PADDING_Y)
	scrollTrack.fill = scrollTrack:CreateTexture(nil, "BACKGROUND")
	scrollTrack.fill:SetTexture(WHITE)
	scrollTrack.fill:SetAllPoints()
	scrollTrack:Hide()
	scrollThumb = CreateFrame("Frame", nil, scrollTrack)
	scrollThumb:SetWidth(TRACK_WIDTH)
	scrollThumb:SetPoint("TOP")
	scrollThumb.fill = scrollThumb:CreateTexture(nil, "ARTWORK")
	scrollThumb.fill:SetTexture(WHITE)
	scrollThumb.fill:SetAllPoints()
	scrollThumb:Hide()
	scrollLogic = Widget.ScrollLogic(scrollFrame, scrollChild, scrollTrack, scrollThumb, { step = ROW_HEIGHT * 2, draggable = true })
	menu:EnableMouseWheel(true)
	menu:SetScript("OnMouseWheel", function(_, delta) scrollLogic.DoScroll(delta) end)

	menu:SetScript("OnShow", function(self) self:Raise() end)
	sharedMenu = menu
	return menu
end

local function GetRow(index)
	if rowPool[index] then return rowPool[index] end
	rowPool[index] = MakeRow(scrollChild)
	return rowPool[index]
end

local function GetTitle(index)
	if titlePool[index] then return titlePool[index] end
	titlePool[index] = MakeTitle(scrollChild)
	return titlePool[index]
end

local function GetSeparator(index)
	if separatorPool[index] then return separatorPool[index] end
	separatorPool[index] = MakeSeparator(scrollChild)
	return separatorPool[index]
end

local function HidePools()
	for _, row in ipairs(rowPool) do row:Hide() end
	for _, title in ipairs(titlePool) do title:Hide() end
	for _, separator in ipairs(separatorPool) do separator:Hide() end
end

function Controls.ContextMenu(items, options)
	options = options or {}
	local palette = Palette(options.window)
	local width = math.min(options.width or DEFAULT_WIDTH, MAX_WIDTH)

	local menu = EnsureMenu()
	local alreadyShown = menu:IsShown() and activeMenu == menu
	if alreadyShown then
		local previousOnClose = menu._onClose
		menu._onClose = nil
		if previousOnClose then previousOnClose() end
	else
		CloseActive()
	end
	HidePools()

	local totalHeight, hasIcons = PADDING_Y, false
	for itemIndex, item in ipairs(items) do
		if item.separator then
			totalHeight = totalHeight + SEPARATOR_HEIGHT
		elseif item.title then
			totalHeight = totalHeight + TITLE_HEIGHT
			local nextItem = items[itemIndex + 1]
			if nextItem and not nextItem.separator then totalHeight = totalHeight + TITLE_GAP end
		else
			totalHeight = totalHeight + ROW_HEIGHT
			if item.icon then hasIcons = true end
		end
	end
	totalHeight = totalHeight + PADDING_Y
	local textX = hasIcons and (TEXT_INSET + ICON_COLUMN) or TEXT_INSET

	local visibleHeight = math.min(totalHeight, PADDING_Y * 2 + MAX_ROWS * ROW_HEIGHT)
	local trackSpace = totalHeight > visibleHeight and (TRACK_WIDTH + TRACK_INSET * 2) or 0
	local innerWidth = width - PADDING_X * 2 - trackSpace
	menu:SetSize(width, visibleHeight)
	scrollChild:SetSize(width, totalHeight)
	menuSquare:SetShown(palette.square == true)
	menuFill:SetShown(not palette.square)
	menuEdge:SetShown(not palette.square)
	if palette.square then
		menuSquare:SetVertexColor(unpack(palette.fill))
	else
		menuFill:SetVertexColor(unpack(palette.fill))
		menuEdge:SetVertexColor(unpack(palette.edge))
	end
	scrollTrack.fill:SetVertexColor(palette.line[1], palette.line[2], palette.line[3], (palette.line[4] or 1) * 0.5)
	scrollThumb.fill:SetVertexColor(unpack(palette.thumb))

	local rowIndex, titleIndex, separatorIndex = 0, 0, 0
	local y = -PADDING_Y
	for itemIndex, item in ipairs(items) do
		if item.separator then
			separatorIndex = separatorIndex + 1
			local line = GetSeparator(separatorIndex)
			local separatorY = y - math.floor(SEPARATOR_HEIGHT / 2)
			line:ClearAllPoints()
			line:SetPoint("BOTTOMLEFT", scrollChild, "TOPLEFT", PADDING_X + SEPARATOR_INSET, separatorY)
			line:SetPoint("BOTTOMRIGHT", scrollChild, "TOPRIGHT", -(PADDING_X + SEPARATOR_INSET + trackSpace), separatorY)
			line:SetVertexColor(unpack(palette.line))
			line:Show()
			y = y - SEPARATOR_HEIGHT
		elseif item.title then
			titleIndex = titleIndex + 1
			local wrap = GetTitle(titleIndex)
			wrap:SetWidth(innerWidth)
			wrap.text:SetFont(palette.font, TITLE_FONT_SIZE, "")
			wrap.text:SetTextColor(unpack(palette.muted))
			wrap.text:SetPoint("LEFT", textX, 0)
			wrap.text:SetText(CleanTitle(item.text or item.title))
			wrap:ClearAllPoints()
			wrap:SetPoint("TOPLEFT", PADDING_X, y)
			wrap:Show()
			y = y - TITLE_HEIGHT
			if items[itemIndex + 1] then y = y - TITLE_GAP end
		else
			rowIndex = rowIndex + 1
			local row = GetRow(rowIndex)
			row:SetWidth(innerWidth)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", PADDING_X, y)
			BindRow(row, item, options.onSelect, palette, textX)
			row:Show()
			y = y - ROW_HEIGHT
		end
	end
	scrollLogic.Stop()
	scrollFrame:SetVerticalScroll(0)
	BUILib.Defer(scrollLogic.UpdateThumb)

	local host = options.anchor or (options.window and options.window.frame)
	Widget.MatchScale(menu, host or UIParent)
	Widget.LiftAbove(menu, host)
	menu:ClearAllPoints()
	if options.anchor and not options.atCursor then
		menu:SetPoint(options.point or "TOPLEFT", options.anchor, options.relPt or "BOTTOMLEFT",
			options.offsetX or 0, options.offsetY or -2)
	else
		local cursorX, cursorY = GetCursorPosition()
		local scale = menu:GetEffectiveScale()
		menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)
	end
	Widget.PinToPixels(menu)

	if not checkFrame then checkFrame = CreateFrame("Frame") end
	local armed = not (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
	checkFrame:SetScript("OnUpdate", function(self)
		if not menu:IsShown() then
			self:SetScript("OnUpdate", nil)
			return
		end
		if host and not host:IsVisible() then
			self:SetScript("OnUpdate", nil)
			CloseActive()
			return
		end
		local mouseDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
		if not armed then
			if not mouseDown then armed = true end
			return
		end
		if mouseDown and not menu:IsMouseOver() then
			self:SetScript("OnUpdate", nil)
			CloseActive()
		end
	end)

	menu._onClose = options.onClose
	menu:SetScript("OnHide", function(self)
		checkFrame:SetScript("OnUpdate", nil)
		if activeMenu == self then activeMenu = nil end
		local onClose = self._onClose
		self._onClose = nil
		if onClose then onClose() end
	end)

	activeMenu = menu
	if not alreadyShown then ShowMenu(menu) end

	return menu
end
