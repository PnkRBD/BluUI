local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

local ShowMenu = Widget.ShowMenuAnimated
local HideMenu = Widget.HideMenuAnimated

local PADDING_X   = 4
local PADDING_Y   = 4
local ROW_HEIGHT  = 26
local TITLE_HEIGHT = 24
local TITLE_GAP   = 1
local SEPARATOR_HEIGHT = 9
local ICON_COLUMN_WIDTH = 20
local TEXT_INSET  = 10
local FONT_SIZE   = 12
local TITLE_FONT_SIZE = 12
local SUBTLE_FONT_SIZE = 11
local DEFAULT_WIDTH = 230
local MAX_WIDTH   = 360
local MAX_ROWS    = 12
local SHADOW_PADDING = 2
local TRACK_WIDTH = 6
local TRACK_INSET = 3
local WHITE       = "Interface\\Buttons\\WHITE8x8"
local STATIC_CHECK = { texture = "Interface\\RaidFrame\\ReadyCheck-Ready", color = { 1, 1, 1, 1 } }

local unpack = unpack

local activeMenu

local function Blend(base, over)
	local alpha = over[4] or 1
	return { base[1] + (over[1] - base[1]) * alpha, base[2] + (over[2] - base[2]) * alpha, base[3] + (over[3] - base[3]) * alpha, 1 }
end

local function Palette(window)
	if not window then
		return {
			fill = Theme.bg.dark, edge = Theme.border.light, hover = Theme.bg.hover,
			text = Theme.text.primary, muted = Theme.text.muted, disabled = Theme.text.disabled,
			thumb = Theme.scrollbar.thumb, check = STATIC_CHECK, font = BUILib.Font,
		}
	end
	local fill = { window:Color('input') }
	return {
		fill = fill, edge = { window:Color('rule') }, hover = Blend(fill, { window:Color('hover') }),
		text = { window:Color('text') }, muted = { window:Color('muted') }, disabled = { window:Color('faint') },
		thumb = { window:Color('faint') }, check = { texture = BUILib.GetLibMedia('check'), color = { window:Color('accent') } }, font = window:FontPath('control'),
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

local function BuildShadow(menu)
	for layerIndex, layerAlpha in ipairs({0.10, 0.06}) do
		local shadow = menu:CreateTexture(nil, "BACKGROUND", nil, -8 + layerIndex)
		shadow:SetTexture(WHITE)
		shadow:SetVertexColor(0, 0, 0, layerAlpha)
		local inset = SHADOW_PADDING - layerIndex + 1
		shadow:SetPoint("TOPLEFT", menu, "TOPLEFT", -inset, inset)
		shadow:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", inset, -inset)
	end
end

local function MakeRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_HEIGHT)

	local highlight = row:CreateTexture(nil, "BACKGROUND")
	highlight:SetPoint("TOPLEFT", 1, -1); highlight:SetPoint("BOTTOMRIGHT", -1, 1)
	highlight:SetTexture(WHITE)
	highlight:Hide()
	row.hl = highlight

	local check = row:CreateTexture(nil, "OVERLAY")
	check:SetSize(14, 14)
	check:SetPoint("LEFT", 4 + (ICON_COLUMN_WIDTH - 14) / 2, 0)
	check:Hide()
	row.check = check

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(14, 14)
	icon:SetPoint("LEFT", 4 + (ICON_COLUMN_WIDTH - 14) / 2, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); icon:Hide()
	row.icon = icon

	local text = row:CreateFontString(nil, "OVERLAY")
	text:SetJustifyH("LEFT"); text:SetJustifyV("MIDDLE")
	text:SetWordWrap(false)
	text:SetPoint("LEFT", 4 + ICON_COLUMN_WIDTH + TEXT_INSET, 0)
	text:SetPoint("RIGHT", -TEXT_INSET, 0)
	row.text = text

	local subText = row:CreateFontString(nil, "OVERLAY")
	subText:SetJustifyH("RIGHT"); subText:SetJustifyV("MIDDLE")
	subText:SetPoint("RIGHT", -TEXT_INSET, 0)
	subText:Hide()
	row.sub = subText

	return row
end

local function BindRow(row, item, onSelect, palette)
	row.hl:Hide()
	row.hl:SetVertexColor(unpack(palette.hover))
	row.text:SetFont(item.fontPath or palette.font, FONT_SIZE, "")
	row.sub:SetFont(palette.font, SUBTLE_FONT_SIZE, "")

	if item.icon then
		row.icon:SetTexture(item.icon); row.icon:Show()
		row.check:Hide()
	else
		row.icon:Hide()
		if item.checked then
			row.check:SetTexture(palette.check.texture)
			row.check:SetVertexColor(unpack(item.disabled and palette.disabled or palette.check.color))
			row.check:SetDesaturated(item.disabled and true or false)
			row.check:Show()
		else
			row.check:Hide()
		end
	end

	row.text:SetText(item.text or "")

	if item.sub and item.sub ~= "" then
		row.sub:SetText(item.sub); row.sub:Show()
	else
		row.sub:Hide()
	end

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

	row:SetScript("OnEnter", function() row.hl:Show() end)
	row:SetScript("OnLeave", function() row.hl:Hide() end)
	row:SetScript("OnClick", function()
		local keepOpen = false
		if item.callback then keepOpen = item.callback(item) == true end
		if onSelect then onSelect(item) end
		if not keepOpen then
			CloseActive()
			return
		end
		if not item.icon then row.check:SetShown(item.checked and true or false) end
		if item.sub and item.sub ~= "" then
			row.sub:SetText(item.sub)
			row.sub:Show()
		else
			row.sub:Hide()
		end
	end)
end

local function MakeTitle(parent)
	local wrap = CreateFrame("Frame", nil, parent)
	wrap:SetHeight(TITLE_HEIGHT)

	local text = wrap:CreateFontString(nil, "OVERLAY")
	text:SetJustifyH("LEFT"); text:SetJustifyV("MIDDLE")
	text:SetWordWrap(false)
	text:SetPoint("LEFT", 4 + ICON_COLUMN_WIDTH + TEXT_INSET, 0)
	text:SetPoint("RIGHT", -TEXT_INSET, 0)
	wrap.text = text

	return wrap
end

local function MakeSeparator(parent)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE); line:SetHeight(1)
	return line
end

local sharedMenu, scrollFrame, scrollChild, scrollTrack, scrollThumb, scrollLogic
local rowPool = {}
local titlePool = {}
local separatorPool = {}
local checkFrame

local function EnsureMenu()
	if sharedMenu then return sharedMenu end
	local menuWidget = Widget.New({frame = UIParent}, "Frame", nil, {bg = Theme.bg.dark, border = Theme.border.light})
	local menu = menuWidget.frame
	menu:SetFrameStrata(BUILib.GetPopupStrata())
	menu:SetFrameLevel(BUILib.GetPopupLevel() + 50)
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:Hide()
	BuildShadow(menu)

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

	local totalHeight = PADDING_Y
	for itemIndex, item in ipairs(items) do
		if item.separator then
			totalHeight = totalHeight + SEPARATOR_HEIGHT
		elseif item.title then
			totalHeight = totalHeight + TITLE_HEIGHT
			local nextItem = items[itemIndex + 1]
			if nextItem and not nextItem.separator then totalHeight = totalHeight + TITLE_GAP end
		else
			totalHeight = totalHeight + ROW_HEIGHT
		end
	end
	totalHeight = totalHeight + PADDING_Y

	local visibleHeight = math.min(totalHeight, PADDING_Y * 2 + MAX_ROWS * ROW_HEIGHT)
	local trackSpace = totalHeight > visibleHeight and (TRACK_WIDTH + TRACK_INSET * 2) or 0
	local innerWidth = width - PADDING_X * 2 - trackSpace
	menu:SetSize(width, visibleHeight)
	scrollChild:SetSize(width, totalHeight)
	menu:SetBackdropColor(unpack(palette.fill))
	menu:SetBackdropBorderColor(unpack(palette.edge))
	scrollTrack.fill:SetVertexColor(palette.edge[1], palette.edge[2], palette.edge[3], 0.5)
	scrollThumb.fill:SetVertexColor(unpack(palette.thumb))

	local rowIndex, titleIndex, separatorIndex = 0, 0, 0
	local y = -PADDING_Y
	for itemIndex, item in ipairs(items) do
		if item.separator then
			separatorIndex = separatorIndex + 1
			local line = GetSeparator(separatorIndex)
			local separatorY = y - math.floor(SEPARATOR_HEIGHT / 2)
			line:ClearAllPoints()
			line:SetPoint("BOTTOMLEFT", scrollChild, "TOPLEFT", PADDING_X + 4, separatorY)
			line:SetPoint("BOTTOMRIGHT", scrollChild, "TOPRIGHT", -(PADDING_X + 4 + trackSpace), separatorY)
			line:SetVertexColor(unpack(palette.edge))
			line:Show()
			y = y - SEPARATOR_HEIGHT
		elseif item.title then
			titleIndex = titleIndex + 1
			local wrap = GetTitle(titleIndex)
			wrap:SetWidth(innerWidth)
			wrap.text:SetFont(palette.font, TITLE_FONT_SIZE, "")
			wrap.text:SetTextColor(unpack(palette.muted))
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
			BindRow(row, item, options.onSelect, palette)
			row:Show()
			y = y - ROW_HEIGHT
		end
	end
	scrollLogic.Stop()
	scrollFrame:SetVerticalScroll(0)
	BUILib.Defer(scrollLogic.UpdateThumb)

	Widget.MatchScale(menu, options.anchor or (options.window and options.window.frame) or UIParent)
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
	local host = options.anchor or (options.window and options.window.frame)
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
