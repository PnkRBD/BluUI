local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Widget = BUILib.Widget
local Theme = BUILib.Theme

local CHIP_X = 14
local CHIP_HEIGHT = 30
local CHIP_TEXT_X = 14
local HEADER_X = 24
local PILL_RADIUS = 8
local SLIDE_SECONDS = 0.30
local FADE_IN = 0.18
local WEAK_KEYS = { __mode = 'k' }
local unpack = unpack

Widget.NAV_CHIP_X = CHIP_X
Widget.NAV_CHIP_HEIGHT = CHIP_HEIGHT
Widget.NAV_HEADER_HEIGHT = 18

local function Colors(rail)
	return rail._navColors or Theme.window.dark.nav
end

local function Track(rail, key, item)
	rail[key] = rail[key] or setmetatable({}, WEAK_KEYS)
	rail[key][item] = true
end

function Widget.NavSetColors(rail, colors)
	rail._navColors = colors
	for chip in pairs(rail._navChips or {}) do chip:Repaint() end
	for header in pairs(rail._navHeaders or {}) do header:SetTextColor(unpack(colors.header)) end
	if rail._navPillFill then Widget.SetRectColor(rail._navPillFill, unpack(colors.pill)) end
end

local function EnsurePill(rail)
	if rail._navPill then return rail._navPill end
	local pill = CreateFrame('Frame', nil, rail)
	pill:SetFrameLevel(rail:GetFrameLevel())
	pill:SetSize(rail:GetWidth() - CHIP_X * 2, CHIP_HEIGHT)
	local red, green, blue = Theme.GetAccent()
	local ring = Widget.DrawRoundedRect(pill, PILL_RADIUS, { red, green, blue, 0.35 }, 'ARTWORK', 0, 0)
	rail._navPillFill = Widget.DrawRoundedRect(pill, PILL_RADIUS - 1, Colors(rail).pill, 'ARTWORK', 1, 1)
	local tint = Widget.DrawRoundedRect(pill, PILL_RADIUS - 1, { red, green, blue, 0.10 }, 'ARTWORK', 2, 1)
	pill:Hide()
	rail._navPill = pill
	Theme.RegisterAccentElement(pill, function(_, newRed, newGreen, newBlue)
		Widget.SetRectColor(ring, newRed, newGreen, newBlue, 0.35)
		Widget.SetRectColor(tint, newRed, newGreen, newBlue, 0.10)
	end)

	local pillX = CHIP_X + pill:GetWidth() / 2
	local ticker = CreateFrame('Frame', nil, rail)
	ticker:Hide()
	rail._navPillTicker = ticker
	ticker:SetScript('OnUpdate', function(self)
		local pillState = rail._navPillState
		if not pillState then self:Hide(); return end
		local progress = (GetTime() - pillState.start) / pillState.dur
		if progress >= 1 then
			pill:ClearAllPoints()
			pill:SetPoint('CENTER', rail, 'TOPLEFT', pillX, -pillState.toY)
			pill:SetAlpha(1)
			rail._navPillPosY = pillState.toY
			rail._navPillState = nil
			self:Hide()
			return
		end
		if pillState.kind == 'slide' then
			local eased = 1 - (1 - progress) ^ 3
			local y = pillState.fromY + (pillState.toY - pillState.fromY) * eased
			pill:ClearAllPoints()
			pill:SetPoint('CENTER', rail, 'TOPLEFT', pillX, -y)
		else
			pill:ClearAllPoints()
			pill:SetPoint('CENTER', rail, 'TOPLEFT', pillX, -pillState.toY)
			pill:SetAlpha(progress)
		end
	end)
	return pill
end

function Widget.NavSelect(chip)
	local rail = chip:GetParent()
	if not rail then return end
	local pill = EnsurePill(rail)
	local pillX = CHIP_X + pill:GetWidth() / 2

	local _, _, _, _, yOff = chip:GetPoint(1)
	if not yOff then return end
	local centerY = -yOff + chip:GetHeight() / 2

	if rail._navPillPosY == nil then
		pill:SetAlpha(0)
		pill:ClearAllPoints()
		pill:SetPoint('CENTER', rail, 'TOPLEFT', pillX, -centerY)
		pill:Show()
		rail._navPillState = { kind = 'fade', start = GetTime(), dur = FADE_IN, toY = centerY }
		rail._navPillPosY = centerY
		rail._navPillTicker:Show()
		return
	end

	local currentY = rail._navPillPosY
	local pillState = rail._navPillState
	if pillState and pillState.kind == 'slide' then
		local progress = math.min(1, (GetTime() - pillState.start) / pillState.dur)
		local eased = 1 - (1 - progress) ^ 3
		currentY = pillState.fromY + (pillState.toY - pillState.fromY) * eased
	end

	if math.abs(currentY - centerY) < 0.5 then
		pill:SetAlpha(1)
		pill:Show()
		return
	end

	pill:SetAlpha(1)
	rail._navPillState = {
		kind  = 'slide',
		start = GetTime(),
		dur   = SLIDE_SECONDS,
		fromY = currentY,
		toY   = centerY,
	}
	rail._navPillPosY = centerY
	pill:Show()
	rail._navPillTicker:Show()
end

function Widget.NavResetPill(rail)
	if not rail then return end
	if rail._navPill then rail._navPill:Hide() end
	if rail._navPillTicker then rail._navPillTicker:Hide() end
	rail._navPillPosY = nil
	rail._navPillState = nil
end

function Widget.NavHeader(rail, text, y, x)
	local header = rail:CreateFontString(nil, 'OVERLAY')
	header:SetFont(BUILib.Font, 9, 'OUTLINE')
	header:SetPoint('TOPLEFT', x or HEADER_X, y)
	header:SetText((text or ''):upper())
	header:SetTextColor(unpack(Colors(rail).header))
	Track(rail, '_navHeaders', header)
	return header
end

function Widget.NavChip(rail, label, callback, options)
	options = options or {}
	local chip = CreateFrame('Button', nil, rail)
	chip:SetHeight(CHIP_HEIGHT)
	chip:SetWidth(rail:GetWidth() - CHIP_X * 2)
	chip:RegisterForClicks('LeftButtonUp')
	if callback then chip:SetScript('OnClick', callback) end

	local text = chip:CreateFontString(nil, 'OVERLAY', nil, 3)
	text:SetFont(BUILib.Font, options.fontSize or 12, '')
	text:SetText(label)
	text:SetPoint('LEFT', CHIP_TEXT_X + (options.indent or 0), 0)
	chip.text = text

	local hoverTextures = Widget.DrawRoundedRect(chip, PILL_RADIUS, Colors(rail).hoverFill, 'BACKGROUND', 0, 0)
	local function SetHoverShown(shown)
		for _, texture in ipairs(hoverTextures) do texture:SetShown(shown) end
	end
	SetHoverShown(false)

	function chip:Repaint()
		local colors = Colors(rail)
		Widget.SetRectColor(hoverTextures, unpack(colors.hoverFill))
		text:SetTextColor(unpack(colors[self.disabled and 'disabled' or self.selected and 'selected' or 'rest']))
	end

	chip:HookScript('OnEnter', function(self)
		if self.selected or self.disabled then return end
		text:SetTextColor(unpack(Colors(rail).hover))
		SetHoverShown(true)
	end)
	chip:HookScript('OnLeave', function(self)
		if self.selected or self.disabled then return end
		self:Repaint()
		SetHoverShown(false)
	end)

	function chip:SetSelected(isSelected)
		if self.disabled then return end
		self.selected = isSelected
		self:Repaint()
		if isSelected then
			SetHoverShown(false)
			Widget.NavSelect(self)
		end
	end

	function chip:SetLabel(newLabel)
		text:SetText(newLabel)
	end

	function chip:SetIndent(indent)
		text:ClearAllPoints()
		text:SetPoint('LEFT', CHIP_TEXT_X + (indent or 0), 0)
	end

	Track(rail, '_navChips', chip)
	chip:Repaint()
	return chip
end

function Widget.NavChipDisable(chip)
	chip.disabled = true
	chip.selected = false
	chip:SetScript('OnClick', nil)
	chip:EnableMouse(false)
	chip:Repaint()
end

function Widget.NavChipEnable(chip, callback)
	chip.disabled = nil
	chip:EnableMouse(true)
	chip:SetScript('OnClick', callback)
	chip:Repaint()
end

function Widget.NavChipMute(chip)
	chip.disabled = true
	chip.selected = false
	chip:SetScript('OnClick', nil)
	chip:Repaint()
end
