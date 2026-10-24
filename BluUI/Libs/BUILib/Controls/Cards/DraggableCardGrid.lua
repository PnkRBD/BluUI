local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local unpack, type, ipairs, select = unpack, type, ipairs, select
local floor, max, min = math.floor, math.max, math.min

local NORMAL_RING = { 0.20, 0.22, 0.26, 0.55 }
local TRACK_COLOR = { 1, 1, 1, 0.06 }

function Controls.DraggableCardGrid(parent, config)
	config = config or {}
	local columns = config.columns or 3
	local cardWidth = config.cardWidth or 180
	local cardHeight = config.cardHeight or 130
	local gap = config.gap or 10
	local onReorder = config.onReorder
	local onValueChange = config.onValueChange

	local container = CreateFrame("Frame", nil, parent)
	local totalWidth = columns * cardWidth + (columns - 1) * gap
	container:SetWidth(totalWidth)

	local cards = {}
	local freeCards = {}
	local dragMode = false
	local dragIndex = nil
	local TRACK_WIDTH = cardWidth - 28

	local ghostFrame = CreateFrame("Frame", nil, UIParent)
	ghostFrame:SetSize(cardWidth, cardHeight)
	ghostFrame:SetFrameStrata(BUILib.GetPopupStrata()); ghostFrame:SetFrameLevel(BUILib.GetPopupLevel())
	do
		local accentRed, accentGreen, accentBlue = Theme.GetAccent()
		Widget.DrawRoundedRect(ghostFrame, 8, { accentRed, accentGreen, accentBlue, 0.9 }, "BACKGROUND", 0, 0)
		Widget.DrawRoundedRect(ghostFrame, 7, Theme.bg.card, "BACKGROUND", 1, 1)
	end
	ghostFrame:SetAlpha(0.92); ghostFrame:Hide()
	local ghostIcon = ghostFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	ghostIcon:SetSize(16, 16); ghostIcon:SetPoint("TOPLEFT", 14, -13); ghostIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local ghostLabel = ghostFrame:CreateFontString(nil, "OVERLAY")
	ghostLabel:SetFont(BUILib.GetFont(), 10, ""); ghostLabel:SetPoint("LEFT", ghostIcon, "RIGHT", 7, 0)
	ghostLabel:SetTextColor(unpack(Theme.text.secondary))

	local function GetCardPosition(index)
		local columnIndex = (index - 1) % columns
		local rowIndex = floor((index - 1) / columns)
		return columnIndex * (cardWidth + gap), -(rowIndex * (cardHeight + gap))
	end

	local function UpdateLayout()
		for index, card in ipairs(cards) do
			local offsetX, offsetY = GetCardPosition(index)
			card.frame:ClearAllPoints()
			card.frame:SetPoint("TOPLEFT", container, "TOPLEFT", offsetX, offsetY)
			card._index = index
		end
		local rowCount = math.ceil(#cards / columns)
		local totalHeight = rowCount > 0 and (rowCount * cardHeight + (rowCount - 1) * gap) or 10
		container:SetHeight(totalHeight)
		container.layoutHeight = totalHeight
	end

	local function FindDropTarget(cursorX, cursorY)
		for index, card in ipairs(cards) do
			local cardFrame = card.frame
			local left, bottom, width, height = cardFrame:GetLeft(), cardFrame:GetBottom(), cardFrame:GetWidth(), cardFrame:GetHeight()
			if left and bottom and cursorX >= left and cursorX <= left + width and cursorY >= bottom and cursorY <= bottom + height then
				return index
			end
		end
		return nil
	end

	local function SetDragMode(enabled)
		dragMode = enabled
		for _, card in ipairs(cards) do
			card._dragHandle:SetShown(enabled)
			card._sliderOverlay:SetShown(enabled)
			card._setRing(enabled and "drag" or "normal")
		end
	end

	local function ConfigureCard(entry, icon, label, id, value, minValue, maxValue, step)
		entry.minVal = minValue or 0
		entry.maxVal = maxValue or 100
		entry.step = step or 5
		entry.id = id
		entry.currentValue = max(entry.minVal, min(entry.maxVal, value or entry.maxVal))

		if type(icon) == "number" then entry._iconTex:SetTexture(icon) else entry._iconTex:SetTexture(icon or 134400) end
		entry._label:SetText((label or ""):upper())
		entry.ApplyVisual(entry.currentValue)
	end

	local function CreateCard()
		local card = CreateFrame("Frame", nil, container)
		card:SetSize(cardWidth, cardHeight)

		local outerRing = Widget.DrawRoundedRect(card, 8, NORMAL_RING, "BACKGROUND", 0, 0)
		Widget.DrawRoundedRect(card, 7, Theme.bg.card, "BACKGROUND", 1, 1)

		local entry = { frame = card, _outerRing = outerRing }

		local iconTexture = card:CreateTexture(nil, "ARTWORK", nil, 2)
		iconTexture:SetSize(16, 16); iconTexture:SetPoint("TOPLEFT", 14, -13)
		iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		entry._iconTex = iconTexture

		local labelText = card:CreateFontString(nil, "OVERLAY")
		labelText:SetFont(BUILib.GetFont(), 10, "")
		labelText:SetPoint("LEFT", iconTexture, "RIGHT", 7, 0)
		labelText:SetPoint("RIGHT", card, "RIGHT", -12, 0)
		labelText:SetJustifyH("LEFT")
		labelText:SetWordWrap(false)
		entry._label = labelText

		local valueFontString = card:CreateFontString(nil, "OVERLAY")
		valueFontString:SetFont(BUILib.GetFont(), 18, "")
		valueFontString:SetPoint("TOPLEFT", 14, -34)
		valueFontString:SetJustifyH("LEFT")
		valueFontString:SetTextColor(0.95, 0.95, 0.95, 1)
		entry._value = valueFontString

		local percentFontString = card:CreateFontString(nil, "OVERLAY")
		percentFontString:SetFont(BUILib.GetFont(), 11, "")
		percentFontString:SetTextColor(unpack(Theme.text.muted))
		percentFontString:SetText("%")
		percentFontString:SetPoint("BOTTOMLEFT", valueFontString, "BOTTOMRIGHT", 3, 2)
		entry._pct = percentFontString

		local track = card:CreateTexture(nil, "ARTWORK")
		track:SetTexture(Widget.WHITE)
		track:SetVertexColor(unpack(TRACK_COLOR))
		track:SetHeight(3)
		track:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 13)
		track:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 13)

		local fill = card:CreateTexture(nil, "OVERLAY")
		fill:SetTexture(Widget.WHITE)
		fill:SetPoint("TOPLEFT", track, "TOPLEFT")
		fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
		entry._fill = fill

		local function Recolor()
			local red, green, blue = Theme.GetAccent()
			labelText:SetTextColor(red * 0.85 + 0.1, green * 0.85 + 0.1, blue * 0.85 + 0.1, 1)
			fill:SetVertexColor(red, green, blue, 1)
		end
		Recolor()
		if Theme.RegisterAccentElement then Theme.RegisterAccentElement(card, Recolor) end

		local function SetRing(state)
			local red, green, blue = Theme.GetAccent()
			if state == "draghover" then
				Widget.SetRectColor(outerRing, red, green, blue, 1)
			elseif state == "drag" then
				Widget.SetRectColor(outerRing, red, green, blue, 0.7)
			elseif state == "hover" then
				Widget.SetRectColor(outerRing, red, green, blue, 0.5)
			else
				Widget.SetRectColor(outerRing, NORMAL_RING[1], NORMAL_RING[2], NORMAL_RING[3], NORMAL_RING[4])
			end
		end
		entry._setRing = SetRing

		local function ApplyVisual(value)
			local ratio = (entry.maxVal == entry.minVal) and 0 or (value - entry.minVal) / (entry.maxVal - entry.minVal)
			if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
			fill:SetWidth(max(0.001, TRACK_WIDTH * ratio))
			fill:SetShown(ratio > 0.001)
			valueFontString:SetText(floor(value + 0.5))
		end
		entry.ApplyVisual = ApplyVisual

		local function SetValue(newValue, fireCallback)
			newValue = max(entry.minVal, min(entry.maxVal, newValue))
			newValue = floor(newValue / entry.step + 0.5) * entry.step
			newValue = max(entry.minVal, min(entry.maxVal, newValue))
			local changed = newValue ~= entry.currentValue
			entry.currentValue = newValue
			ApplyVisual(newValue)
			if fireCallback and changed and onValueChange then onValueChange(entry.id, newValue) end
		end

		local hitArea = CreateFrame("Frame", nil, card)
		hitArea:SetAllPoints(card)
		hitArea:EnableMouse(true)
		hitArea:SetFrameLevel(card:GetFrameLevel() + 4)
		entry._hit = hitArea

		local dragging = false
		local function ValueAtCursor()
			local cardLeft, cardRight = card:GetLeft(), card:GetRight()
			if not cardLeft or not cardRight or cardRight == cardLeft then return entry.currentValue end
			local padRatio = 14 / (cardRight - cardLeft)
			local scale = UIParent:GetEffectiveScale()
			local cursorX = select(1, GetCursorPosition()) / scale
			local ratio = ((cursorX - cardLeft) / (cardRight - cardLeft) - padRatio) / (1 - 2 * padRatio)
			if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
			return entry.minVal + ratio * (entry.maxVal - entry.minVal)
		end

		hitArea:SetScript("OnMouseDown", function(_, mouseButton)
			if mouseButton ~= "LeftButton" or dragMode then return end
			dragging = true
			SetValue(ValueAtCursor(), true)
			hitArea:SetScript("OnUpdate", function() SetValue(ValueAtCursor(), true) end)
		end)
		local function EndDrag()
			if not dragging then return end
			dragging = false
			hitArea:SetScript("OnUpdate", nil)
		end
		hitArea:SetScript("OnMouseUp", EndDrag)
		hitArea:SetScript("OnHide", EndDrag)
		hitArea:SetScript("OnEnter", function() if not dragMode then SetRing("hover") end end)
		hitArea:SetScript("OnLeave", function() if not dragMode then SetRing("normal") end end)

		entry._slider = {
			SetValue = function(_, newValue) SetValue(newValue, false) end,
		}

		local dragHandle = CreateFrame("Frame", nil, card)
		dragHandle:SetSize(18, 18); dragHandle:SetPoint("TOPRIGHT", -8, -8)
		dragHandle:SetFrameLevel(card:GetFrameLevel() + 6)
		for lineIndex = 1, 3 do
			local line = dragHandle:CreateTexture(nil, "OVERLAY")
			line:SetTexture(Widget.WHITE); line:SetVertexColor(0.7, 0.7, 0.7, 1)
			line:SetSize(11, 2); line:SetPoint("TOP", 0, -(lineIndex - 1) * 5 - 1)
		end
		dragHandle:Hide()
		entry._dragHandle = dragHandle

		local sliderOverlay = CreateFrame("Frame", nil, card)
		sliderOverlay:SetAllPoints()
		sliderOverlay:EnableMouse(true); sliderOverlay:SetFrameLevel(card:GetFrameLevel() + 20)
		sliderOverlay:RegisterForDrag("LeftButton")
		sliderOverlay:SetScript("OnDragStart", function()
			local handler = card:GetScript("OnDragStart")
			if handler then handler(card) end
		end)
		sliderOverlay:SetScript("OnDragStop", function()
			local handler = card:GetScript("OnDragStop")
			if handler then handler(card) end
		end)
		sliderOverlay:SetScript("OnEnter", function()
			local handler = card:GetScript("OnEnter")
			if handler then handler(card) end
		end)
		sliderOverlay:SetScript("OnLeave", function()
			local handler = card:GetScript("OnLeave")
			if handler then handler(card) end
		end)
		sliderOverlay:Hide()
		entry._sliderOverlay = sliderOverlay

		card:EnableMouse(true); card:RegisterForDrag("LeftButton")
		card:SetScript("OnDragStart", function()
			if not dragMode then return end
			dragIndex = entry._index
			ghostIcon:SetTexture(iconTexture:GetTexture())
			ghostLabel:SetText(labelText:GetText())
			ghostFrame:Show()
			card:SetAlpha(0.3)

			container:SetScript("OnUpdate", function()
				local cursorX, cursorY = GetCursorPosition()
				local scale = UIParent:GetEffectiveScale()
				cursorX, cursorY = cursorX / scale, cursorY / scale
				ghostFrame:ClearAllPoints()
				ghostFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX, cursorY)

				local targetIndex = FindDropTarget(cursorX, cursorY)
				if targetIndex and targetIndex ~= dragIndex then
					local movedCard = table.remove(cards, dragIndex)
					table.insert(cards, targetIndex, movedCard)
					dragIndex = targetIndex
					UpdateLayout()
				end
			end)
		end)
		card:SetScript("OnDragStop", function()
			if not dragIndex then return end
			card:SetAlpha(1)
			ghostFrame:Hide()
			container:SetScript("OnUpdate", nil)
			dragIndex = nil
			UpdateLayout()
			if onReorder then
				local order = {}
				for index, orderedCard in ipairs(cards) do order[index] = orderedCard.id end
				onReorder(order)
			end
		end)

		card:SetScript("OnEnter", function() if dragMode then SetRing("draghover") end end)
		card:SetScript("OnLeave", function() if dragMode then SetRing("drag") end end)

		return entry
	end

	function container:AddCard(icon, label, id, value, minValue, maxValue, step, draggable)
		local card = table.remove(freeCards)
		if card then
			card.frame:Show()
		else
			card = CreateCard()
		end
		ConfigureCard(card, icon, label, id, value, minValue, maxValue, step)
		card._dragHandle:SetShown(dragMode)
		card._sliderOverlay:SetShown(dragMode)
		card._setRing(dragMode and "drag" or "normal")
		cards[#cards + 1] = card
		UpdateLayout()
		return card
	end

	function container:ClearCards()
		for _, card in ipairs(cards) do
			card.frame:Hide()
			freeCards[#freeCards + 1] = card
		end
		cards = {}
		UpdateLayout()
	end

	function container:SetDragMode(enabled) SetDragMode(enabled) end
	function container:IsDragMode() return dragMode end

	function container:ResetAllValues(value)
		for _, card in ipairs(cards) do
			if card._slider then card._slider:SetValue(value) end
		end
	end

	return Widget.Wrap(container)
end
