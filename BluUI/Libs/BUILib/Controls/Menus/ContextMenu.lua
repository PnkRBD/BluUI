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
local SHADOW_PADDING = 2
local HIGHLIGHT_FADE_IN  = 0.08
local HIGHLIGHT_FADE_OUT = 0.08
local WHITE       = "Interface\\Buttons\\WHITE8x8"

local unpack = unpack

local activeMenu

local function CloseActive()
	if activeMenu and activeMenu:IsShown() then HideMenu(activeMenu) end
	activeMenu = nil
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

local function MakeRow(menu)
	local row = CreateFrame("Button", nil, menu)
	row:SetHeight(ROW_HEIGHT)

	local highlight = row:CreateTexture(nil, "BACKGROUND")
	highlight:SetPoint("TOPLEFT", 1, -1); highlight:SetPoint("BOTTOMRIGHT", -1, 1)
	highlight:SetTexture(WHITE)
	highlight:SetVertexColor(unpack(Theme.bg.hover))
	highlight:SetAlpha(0)
	row.hl = highlight

	local fadeIn = row:CreateAnimationGroup()
	local fadeInAnimation = fadeIn:CreateAnimation("Alpha")
	fadeInAnimation:SetDuration(HIGHLIGHT_FADE_IN); fadeInAnimation:SetFromAlpha(0); fadeInAnimation:SetToAlpha(1)
	fadeInAnimation:SetTarget(highlight)
	fadeIn:SetScript("OnFinished", function() highlight:SetAlpha(1) end)
	row.fadeIn = fadeIn

	local fadeOut = row:CreateAnimationGroup()
	local fadeOutAnimation = fadeOut:CreateAnimation("Alpha")
	fadeOutAnimation:SetDuration(HIGHLIGHT_FADE_OUT); fadeOutAnimation:SetFromAlpha(1); fadeOutAnimation:SetToAlpha(0)
	fadeOutAnimation:SetTarget(highlight)
	fadeOut:SetScript("OnFinished", function() highlight:SetAlpha(0) end)
	row.fadeOut = fadeOut

	local check = row:CreateTexture(nil, "OVERLAY")
	check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
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
	text:SetFont(BUILib.Font, FONT_SIZE, "")
	text:SetJustifyH("LEFT"); text:SetJustifyV("MIDDLE")
	text:SetWordWrap(false)
	text:SetPoint("LEFT", 4 + ICON_COLUMN_WIDTH + TEXT_INSET, 0)
	text:SetPoint("RIGHT", -TEXT_INSET, 0)
	row.text = text

	local subText = row:CreateFontString(nil, "OVERLAY")
	subText:SetFont(BUILib.Font, SUBTLE_FONT_SIZE, "")
	subText:SetJustifyH("RIGHT"); subText:SetJustifyV("MIDDLE")
	subText:SetPoint("RIGHT", -TEXT_INSET, 0)
	subText:SetTextColor(unpack(Theme.text.muted))
	subText:Hide()
	row.sub = subText

	return row
end

local function BindRow(row, item, onSelect)
	row.fadeIn:Stop(); row.fadeOut:Stop(); row.hl:SetAlpha(0)

	if item.icon then
		row.icon:SetTexture(item.icon); row.icon:Show()
		row.check:Hide()
	else
		row.icon:Hide()
		if item.checked then
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
		row.text:SetTextColor(unpack(Theme.text.disabled))
		row.sub:SetTextColor(unpack(Theme.text.disabled))
		row:EnableMouse(false)
		row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil); row:SetScript("OnClick", nil)
		return
	end

	row:EnableMouse(true)
	row.text:SetTextColor(unpack(Theme.text.primary))
	row.sub:SetTextColor(unpack(Theme.text.muted))

	row:SetScript("OnEnter", function()
		row.fadeOut:Stop()
		row.fadeIn:Stop(); row.fadeIn:Play()
	end)
	row:SetScript("OnLeave", function()
		row.fadeIn:Stop()
		row.fadeOut:Stop(); row.fadeOut:Play()
	end)
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

local function MakeTitle(menu)
	local wrap = CreateFrame("Frame", nil, menu)
	wrap:SetHeight(TITLE_HEIGHT)

	local text = wrap:CreateFontString(nil, "OVERLAY")
	text:SetFont(BUILib.Font, TITLE_FONT_SIZE, "")
	text:SetJustifyH("LEFT"); text:SetJustifyV("MIDDLE")
	text:SetWordWrap(false)
	text:SetPoint("LEFT", 4 + ICON_COLUMN_WIDTH + TEXT_INSET, 0)
	text:SetPoint("RIGHT", -TEXT_INSET, 0)
	text:SetTextColor(unpack(Theme.text.muted))
	wrap.text = text

	return wrap
end

local function MakeSeparator(menu)
	local line = menu:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE); line:SetHeight(1)
	line:SetVertexColor(unpack(Theme.border.default))
	return line
end

local sharedMenu
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
	menu:SetScript("OnShow", function(self) self:Raise() end)
	sharedMenu = menu
	return menu
end

local function GetRow(index, menu)
	if rowPool[index] then return rowPool[index] end
	rowPool[index] = MakeRow(menu)
	return rowPool[index]
end

local function GetTitle(index, menu)
	if titlePool[index] then return titlePool[index] end
	titlePool[index] = MakeTitle(menu)
	return titlePool[index]
end

local function GetSeparator(index, menu)
	if separatorPool[index] then return separatorPool[index] end
	separatorPool[index] = MakeSeparator(menu)
	return separatorPool[index]
end

local function HidePools()
	for _, row in ipairs(rowPool) do row:Hide() end
	for _, title in ipairs(titlePool) do title:Hide() end
	for _, separator in ipairs(separatorPool) do separator:Hide() end
end

function Controls.ContextMenu(items, options)
	options = options or {}
	local width = math.min(options.width or DEFAULT_WIDTH, MAX_WIDTH)
	local innerWidth = width - PADDING_X * 2

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

	menu:SetSize(width, totalHeight)

	local rowIndex, titleIndex, separatorIndex = 0, 0, 0
	local y = -PADDING_Y
	for itemIndex, item in ipairs(items) do
		if item.separator then
			separatorIndex = separatorIndex + 1
			local line = GetSeparator(separatorIndex, menu)
			local separatorY = y - math.floor(SEPARATOR_HEIGHT / 2)
			line:ClearAllPoints()
			line:SetPoint("LEFT", menu, "TOPLEFT", PADDING_X + 4, separatorY)
			line:SetPoint("RIGHT", menu, "TOPRIGHT", -(PADDING_X + 4), separatorY)
			line:Show()
			y = y - SEPARATOR_HEIGHT
		elseif item.title then
			titleIndex = titleIndex + 1
			local wrap = GetTitle(titleIndex, menu)
			wrap:SetWidth(innerWidth)
			wrap.text:SetText(CleanTitle(item.text or item.title))
			wrap:ClearAllPoints()
			wrap:SetPoint("TOPLEFT", PADDING_X, y)
			wrap:Show()
			y = y - TITLE_HEIGHT
			if items[itemIndex + 1] then y = y - TITLE_GAP end
		else
			rowIndex = rowIndex + 1
			local row = GetRow(rowIndex, menu)
			row:SetWidth(innerWidth)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", PADDING_X, y)
			BindRow(row, item, options.onSelect)
			row:Show()
			y = y - ROW_HEIGHT
		end
	end

	menu:ClearAllPoints()
	if options.anchor and not options.atCursor then
		menu:SetPoint(options.point or "TOPLEFT", options.anchor, options.relPt or "BOTTOMLEFT",
			options.offsetX or 0, options.offsetY or -2)
	else
		local cursorX, cursorY = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)
	end

	if not checkFrame then checkFrame = CreateFrame("Frame") end
	local armed = not (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
	checkFrame:SetScript("OnUpdate", function(self)
		if not menu:IsShown() then
			self:SetScript("OnUpdate", nil)
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

