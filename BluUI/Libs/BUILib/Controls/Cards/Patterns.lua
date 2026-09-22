local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

local function AttachCardHover(card, outerTextures, innerTextures, outerRestore, innerRestore)
	local function setAccent(alpha)
		local red, green, blue = Theme.GetAccent()
		Widget.SetRectRing(outerTextures, red, green, blue, alpha)
	end
	local function restoreIdle()
		Widget.SetRectRing(outerTextures, outerRestore[1], outerRestore[2], outerRestore[3], outerRestore[4] or 1)
	end
	local function maskInner()
		if innerTextures and innerRestore then
			Widget.SetRectColor(innerTextures, innerRestore[1], innerRestore[2], innerRestore[3], 1)
		end
	end
	local function pressInner()

		if innerTextures and innerRestore then
			local red = math.min(1, innerRestore[1] * 1.8 + 0.04)
			local green = math.min(1, innerRestore[2] * 1.8 + 0.04)
			local blue = math.min(1, innerRestore[3] * 1.8 + 0.04)
			Widget.SetRectColor(innerTextures, red, green, blue, 1)
		end
	end
	local function restoreInner()
		if innerTextures and innerRestore then
			Widget.SetRectColor(innerTextures, innerRestore[1], innerRestore[2], innerRestore[3], innerRestore[4] or 1)
		end
	end

	local bandRed, bandGreen, bandBlue
	do
		local function over(topColor, red, green, blue)
			local topAlpha = topColor[4] or 1
			return topColor[1] * topAlpha + red * (1 - topAlpha), topColor[2] * topAlpha + green * (1 - topAlpha), topColor[3] * topAlpha + blue * (1 - topAlpha)
		end
		local baseRed, baseGreen, baseBlue = over(outerRestore, 0.03, 0.035, 0.04)
		bandRed, bandGreen, bandBlue = over(innerRestore, baseRed, baseGreen, baseBlue)
	end
	local function selectedInner()
		if innerTextures and innerRestore then
			Widget.SetRectColor(innerTextures, innerRestore[1], innerRestore[2], innerRestore[3], innerRestore[4] or 1)
			Widget.SetRectRing(innerTextures, bandRed, bandGreen, bandBlue, 1)
		end
	end
	card._selectedInner = selectedInner

	card:SetScript("OnEnter", function(self)
		if not self._selected then setAccent(0.9) end
		maskInner()
	end)
	card:SetScript("OnLeave", function(self)
		if self._selected then
			selectedInner()
		else
			restoreIdle()
			restoreInner()
		end
	end)
	card:SetScript("OnMouseDown", function(self)
		setAccent(1)
		pressInner()
	end)
	card:SetScript("OnMouseUp", function(self)
		local hovering = self:IsMouseOver()
		if self._selected then
			setAccent(1)
			if hovering then maskInner() else selectedInner() end
			return
		end
		if hovering then
			setAccent(0.9)
			maskInner()
		else
			restoreIdle()
			restoreInner()
		end
	end)
end

function Controls.HeroCard(parent, config)
	config = config or {}
	local width = config.width or 220
	local height = config.height or 240
	local compact = config.compact
	local horizontal = config.horizontal
	local parentFrame = Widget.Unwrap(parent)

	local card = CreateFrame("Button", nil, parentFrame)
	card:SetSize(width, height)

	local outer = Widget.DrawRoundedRect(card, 14, config.outerBorder or { 0.20, 0.22, 0.26, 0.50 }, "BACKGROUND", 0, 0)
	local inner = Widget.DrawRoundedRect(card, 13, config.bg or Theme.bg.card, "BACKGROUND", 1, 1)

	local heroWidth, heroHeight
	if horizontal then
		heroHeight = height - 2
		heroWidth = config.heroWidth or heroHeight
	else
		heroWidth = width - 2
		heroHeight = config.heroHeight or math.floor(height * 0.55)
	end
	local hero = CreateFrame("Frame", nil, card)
	if horizontal then
		hero:SetPoint("TOPLEFT", 1, -1)
		hero:SetPoint("BOTTOMLEFT", 1, 1)
		hero:SetWidth(heroWidth)
	else
		hero:SetPoint("TOPLEFT", 1, -1)
		hero:SetPoint("TOPRIGHT", -1, -1)
		hero:SetHeight(heroHeight)
	end
	if config.heroBg then
		local heroBackground = hero:CreateTexture(nil, "BACKGROUND")
		heroBackground:SetAllPoints()
		heroBackground:SetColorTexture(config.heroBg[1], config.heroBg[2], config.heroBg[3], config.heroBg[4] or 1)
	end
	if config.image or config.imageAtlas then
		local imageTexture = hero:CreateTexture(nil, "ARTWORK")
		local imageSize = config.imageSize
		if not imageSize then
			if horizontal then
				imageSize = math.min(heroWidth - 16, heroHeight - 16)
			else
				imageSize = math.min(heroHeight - 20, width - 40)
			end
		end
		imageTexture:SetSize(imageSize, imageSize)
		imageTexture:SetPoint("CENTER", 0, 0)
		if config.imageAtlas then
			imageTexture:SetAtlas(config.imageAtlas)
		else
			imageTexture:SetTexture(config.image)
			if not config.imageRaw then imageTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
		end
		if config.imageColor then
			imageTexture:SetVertexColor(config.imageColor[1], config.imageColor[2], config.imageColor[3], config.imageColor[4] or 1)
		end
	end

	local divider = card:CreateTexture(nil, "OVERLAY")
	divider:SetColorTexture(1, 1, 1, 0.05)
	if horizontal then
		divider:SetWidth(1)
		divider:SetPoint("TOPLEFT", hero, "TOPRIGHT", 0, -8)
		divider:SetPoint("BOTTOMLEFT", hero, "BOTTOMRIGHT", 0, 8)
	else
		divider:SetHeight(1)
		divider:SetPoint("TOPLEFT", 8, -heroHeight - 1)
		divider:SetPoint("TOPRIGHT", -8, -heroHeight - 1)
	end

	local infoLeftX, infoY
	local iconSize = 22
	if horizontal then
		infoLeftX = heroWidth + 14
		infoY = -14
	else
		infoLeftX = 14
		infoY = -heroHeight - 12
	end

	local showInfoIcon = config.icon and not horizontal
	if showInfoIcon then
		local iconTexture = card:CreateTexture(nil, "OVERLAY")
		iconTexture:SetSize(iconSize, iconSize)
		iconTexture:SetPoint("TOPLEFT", infoLeftX, infoY)
		iconTexture:SetTexture(config.icon)
		iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	local title = card:CreateFontString(nil, "OVERLAY")
	local defaultTitleSize = horizontal and 22 or 13
	title:SetFont(BUILib.Font, config.titleSize or defaultTitleSize, "OUTLINE")
	title:SetText(string.upper(config.title or ""))
	if horizontal then

		title:SetPoint("LEFT", card, "LEFT", heroWidth + 14, 10)
	else
		title:SetPoint("TOPLEFT", showInfoIcon and (infoLeftX + iconSize + 8) or infoLeftX, infoY - 4)
	end
	title:SetTextColor(unpack(Theme.text.primary))

	local statusFrame, statusLabel, statusOuter
	if config.statusText then
		local statusBadge = CreateFrame("Frame", nil, card)
		local statusHeight = 18
		statusBadge:SetHeight(statusHeight)
		statusBadge:SetPoint("TOPRIGHT", -10, infoY - 2)
		local statusColor = config.statusColor or { 0.95, 0.75, 0.25, 1 }
		statusOuter = Widget.DrawCapsule(statusBadge, { statusColor[1], statusColor[2], statusColor[3], 0.9 }, "BACKGROUND", 0, 0)
		Widget.DrawCapsule(statusBadge, config.statusBg or { 0.04, 0.045, 0.05, 1 }, "BACKGROUND", 1, 1)
		statusLabel = statusBadge:CreateFontString(nil, "OVERLAY")
		statusLabel:SetFont(BUILib.Font, 9, "")
		statusLabel:SetText(config.statusText)
		statusLabel:SetPoint("CENTER", 0, 0)
		statusLabel:SetTextColor(statusColor[1], statusColor[2], statusColor[3], 1)
		statusBadge:SetWidth((statusLabel:GetStringWidth() or 30) + 18)
		statusFrame = statusBadge
	end

	function card:SetStatus(text, color)
		if not statusFrame then return end
		local statusColor = color or { 0.95, 0.75, 0.25, 1 }
		statusLabel:SetText(text or "")
		statusLabel:SetTextColor(statusColor[1], statusColor[2], statusColor[3], 1)
		Widget.SetRectColor(statusOuter, statusColor[1], statusColor[2], statusColor[3], 0.9)
		statusFrame:SetWidth((statusLabel:GetStringWidth() or 30) + 18)
	end

	if config.subtitle and not compact then
		local subtitleText = card:CreateFontString(nil, "OVERLAY")
		subtitleText:SetFont(BUILib.Font, config.subtitleSize or 9, "")
		subtitleText:SetText(config.subtitle)
		local subLeftX = showInfoIcon and (infoLeftX + iconSize + 8) or infoLeftX
		subtitleText:SetPoint("TOPLEFT", subLeftX, infoY - 22)
		subtitleText:SetPoint("RIGHT", card, "RIGHT", -10, 0)
		subtitleText:SetJustifyH("LEFT")
		subtitleText:SetTextColor(unpack(Theme.text.muted))
	end

	local inlineFooter = compact or horizontal
	local footerLeftX = horizontal and (heroWidth + 14) or 14
	if config.footerLabel or config.footerValue then
		if inlineFooter then
			local footerLabel = card:CreateFontString(nil, "OVERLAY")
			footerLabel:SetFont(BUILib.Font, 9, "")
			footerLabel:SetText(config.footerLabel or "")
			if horizontal then

				footerLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
			else

				footerLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
			end
			footerLabel:SetTextColor(unpack(Theme.text.muted))
			card._footerLabel = footerLabel

			local footerValue = card:CreateFontString(nil, "OVERLAY")
			footerValue:SetFont(BUILib.Font, 11, "OUTLINE")
			footerValue:SetText(config.footerValue or "")
			footerValue:SetPoint("LEFT", footerLabel, "RIGHT", 6, 0)
			footerValue:SetTextColor(unpack(Theme.text.primary))
			card._footerValue = footerValue

			if config.footerIcon then
				local footerIconTexture = card:CreateTexture(nil, "OVERLAY")
				footerIconTexture:SetSize(11, 11)
				footerIconTexture:SetPoint("LEFT", footerValue, "RIGHT", 6, 1)
				footerIconTexture:SetTexture(config.footerIcon)
				footerIconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
		else
			local footerLabel = card:CreateFontString(nil, "OVERLAY")
			footerLabel:SetFont(BUILib.Font, 9, "")
			footerLabel:SetText(config.footerLabel or "")
			footerLabel:SetPoint("BOTTOMLEFT", footerLeftX, 28)
			footerLabel:SetTextColor(unpack(Theme.text.muted))
			card._footerLabel = footerLabel

			local footerValue = card:CreateFontString(nil, "OVERLAY")
			footerValue:SetFont(BUILib.Font, 13, "OUTLINE")
			footerValue:SetText(config.footerValue or "")
			footerValue:SetPoint("BOTTOMLEFT", footerLeftX, 10)
			footerValue:SetTextColor(unpack(Theme.text.primary))
			card._footerValue = footerValue

			if config.footerIcon then
				local footerIconTexture = card:CreateTexture(nil, "OVERLAY")
				footerIconTexture:SetSize(12, 12)
				footerIconTexture:SetPoint("LEFT", footerValue, "RIGHT", 6, 1)
				footerIconTexture:SetTexture(config.footerIcon)
				footerIconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
		end
	end

	if config.actionLabel and not compact and not horizontal then
		local actionButton = Controls.Button(card, config.actionLabel, config.actionWidth or 84,
			function()
				if config.onAction then config.onAction(config) elseif config.onClick then config.onClick(config) end
			end,
			{ radius = 6, accent = config.actionAccent ~= false })
		Widget.Unwrap(actionButton):SetPoint("BOTTOMRIGHT", -10, 10)
		Widget.Unwrap(actionButton):SetHeight(config.actionHeight or 26)
	end

	AttachCardHover(card, outer, inner, config.outerBorder or { 0.20, 0.22, 0.26, 0.50 }, config.bg or Theme.bg.card)

	function card:SetSelected(isSelected)
		card._selected = isSelected and true or false
		card:SetScript("OnUpdate", nil)
		if outer then
			if isSelected then
				local red, green, blue = Theme.GetAccent()
				Widget.SetRectRing(outer, red, green, blue, 1)
				if card._selectedInner then card._selectedInner() end
			else
				local borderColor = config.outerBorder or { 0.20, 0.22, 0.26, 0.50 }
				Widget.SetRectRing(outer, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
				local backgroundColor = config.bg or Theme.bg.card
				if inner then Widget.SetRectColor(inner, backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4] or 1) end
			end
		end
	end

	if config.onClick then
		card:SetScript("OnClick", function() config.onClick(config, card) end)
	end

	return Widget.Wrap(card)
end
