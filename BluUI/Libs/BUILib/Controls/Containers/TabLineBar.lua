local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

function Controls.TabLineBar(parent, tabs, selected, callback, width)
	width = width or 400
	local ROW_HEIGHT = 32
	local SHRINK = 12
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	local buttons = {}
	local state = {selected = selected or 1}

	local function LineTarget(index, button)
		if index ~= state.selected then return 0 end
		if button._hover then return button._w end
		return math.max(1, button._w - SHRINK)
	end

	local animating = false
	local function StartLineAnim()
		if animating then return end
		animating = true
		container:SetScript("OnUpdate", function(_, deltaTime)
			local lerpFactor = 1 - math.exp(-16 * deltaTime)
			local settled = true
			for index, button in ipairs(buttons) do
				local target = LineTarget(index, button)
				local newWidth = button._lw + (target - button._lw) * lerpFactor
				if math.abs(target - newWidth) < 0.5 then newWidth = target else settled = false end
				button._lw = newWidth
				if newWidth < 0.5 then
					button.indicator:Hide()
				else
					button.indicator:SetWidth(newWidth)
					button.indicator:Show()
				end
			end
			if settled then
				animating = false
				container:SetScript("OnUpdate", nil)
			end
		end)
	end

	local function UpdateAll()
		for index, button in ipairs(buttons) do
			if index == state.selected then
				button.text:SetTextColor(unpack(Theme.text.primary))
			elseif button._hover then
				button.text:SetTextColor(unpack(Theme.text.secondary))
			else
				button.text:SetTextColor(unpack(Theme.text.muted))
			end
		end
		StartLineAnim()
	end

	local x, row = 0, 0
	for tabIndex, tabInfo in ipairs(tabs) do
		local tabText = type(tabInfo) == "table" and tabInfo.text or tabInfo
		local button = CreateFrame("Button", nil, container)
		button:SetHeight(ROW_HEIGHT)
		button.text = button:CreateFontString(nil, "OVERLAY")
		button.text:SetFont(BUILib.Font, 13, "")
		button.text:SetPoint("CENTER", 0, 2)
		button.text:SetText(tabText)
		button.text:SetTextColor(unpack(Theme.text.muted))
		local textWidth = button.text:GetStringWidth() + 24

		if x + textWidth > width and x > 0 then
			x = 0
			row = row + 1
		end
		button:SetWidth(textWidth)
		button:SetPoint("TOPLEFT", x, -row * ROW_HEIGHT)
		x = x + textWidth
		button._w, button._lw = textWidth, 0
		button.indicator = Widget.CreateAccent(button)
		button.indicator:SetHeight(2)
		button.indicator:SetPoint("BOTTOM")
		button.indicator:SetWidth(1)
		button.indicator:Hide()
		button:SetScript("OnClick", function()
			state.selected = tabIndex
			UpdateAll()
			if callback then callback(tabIndex, tabInfo) end
		end)
		button:SetScript("OnEnter", function()
			button._hover = true
			UpdateAll()
		end)
		button:SetScript("OnLeave", function()
			button._hover = nil
			UpdateAll()
		end)
		buttons[tabIndex] = button
	end

	local totalRows = row + 1
	local totalHeight = totalRows * ROW_HEIGHT
	container:SetSize(width, totalHeight)

	local baseLine = Widget.Create(container, unpack(Theme.border.default))
	baseLine:SetHeight(1)
	baseLine:SetPoint("BOTTOMLEFT")
	baseLine:SetPoint("BOTTOMRIGHT")

	UpdateAll()

	function container:GetSelected() return state.selected end
	function container:SetSelected(index) state.selected = index; UpdateAll() end
	function container:SetCallback(newCallback) callback = newCallback end

	Theme.RegisterAccentElement(container, function(_, red, green, blue)
		for _, button in ipairs(buttons) do Widget.SetColor(button.indicator, red, green, blue, 1) end
	end)

	container._buttons = buttons
	return Widget.Wrap(container)
end
