local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

function Controls.TickEditor(parent, options)
	options = options or {}
	local track = CreateFrame("Button", nil, Widget.Unwrap(parent))
	track:SetSize(220, 24)
	track:RegisterForClicks("LeftButtonUp")

	local backgroundTexture = track:CreateTexture(nil, "BACKGROUND")
	backgroundTexture:SetAllPoints()
	backgroundTexture:SetColorTexture(0.13, 0.13, 0.145, 1)

	local hint = track:CreateFontString(nil, "OVERLAY")
	hint:SetFont(BUILib.GetFont(), 9, "")
	hint:SetTextColor(0.45, 0.45, 0.48, 1)
	hint:SetPoint("CENTER")
	hint:SetText("Click to add a tick")

	local ghost = track:CreateTexture(nil, "ARTWORK")
	ghost:SetColorTexture(1, 1, 1, 1)
	ghost:SetWidth(2)
	ghost:Hide()

	local label = track:CreateFontString(nil, "OVERLAY")
	label:SetFont(BUILib.GetFont(), 10, "OUTLINE")
	label:Hide()

	local markers = {}
	local dragIndex
	local hovering = false

	local function LineColor()
		if options.color then return options.color() end
		return 1, 1, 1, 0.6
	end

	local function CursorPercent()
		local scale = track:GetEffectiveScale()
		local x = GetCursorPosition() / scale - (track:GetLeft() or 0)
		local width = track:GetWidth()
		if not width or width <= 0 then return 50 end
		return math.max(1, math.min(99, math.floor(x / width * 100 + 0.5)))
	end

	local function PlaceLine(region, percent)
		local x = (track:GetWidth() or 0) * percent / 100
		region:ClearAllPoints()
		region:SetPoint("TOP", track, "TOPLEFT", x, 0)
		region:SetPoint("BOTTOM", track, "BOTTOMLEFT", x, 0)
	end

	local function ShowLabel(percent, red, green, blue)
		label:SetText(percent .. "%")
		label:SetTextColor(red or 1, green or 1, blue or 1, 1)
		label:ClearAllPoints()
		local x = (track:GetWidth() or 0) * percent / 100

		if percent > 85 then
			label:SetPoint("RIGHT", track, "LEFT", x - 6, 0)
		else
			label:SetPoint("LEFT", track, "LEFT", x + 6, 0)
		end
		label:Show()
	end

	local function StartDriver()
		track:SetScript("OnUpdate", track.Driver)
	end

	local function StopDriver()
		if not dragIndex and not hovering then
			track:SetScript("OnUpdate", nil)
			ghost:Hide()
			label:Hide()
		end
	end

	local function Layout()
		local list = options.get()
		local lineWidth = math.max(2, (options.width and options.width()) or 1)
		local red, green, blue, alpha = LineColor()
		for tickIndex = 1, #list do
			local marker = markers[tickIndex]
			if not marker then
				marker = CreateFrame("Button", nil, track)
				marker:SetWidth(12)
				marker:RegisterForClicks("RightButtonUp")
				marker:RegisterForDrag("LeftButton")
				marker.line = marker:CreateTexture(nil, "ARTWORK")
				marker.line:SetColorTexture(1, 1, 1, 1)
				marker.line:SetPoint("TOP")
				marker.line:SetPoint("BOTTOM")
				marker:SetScript("OnClick", function(self, buttonName)
					if buttonName == "RightButton" and not dragIndex then
						table.remove(options.get(), self.index)
						track.Commit()
					end
				end)
				marker:SetScript("OnDragStart", function(self)
					dragIndex = self.index
					StartDriver()
				end)
				marker:SetScript("OnDragStop", function()
					dragIndex = nil
					track.Commit()
					StopDriver()
				end)
				marker:SetScript("OnEnter", function(self)
					hovering = true
					StartDriver()
					local accentRed, accentGreen, accentBlue = Theme.GetAccent()
					self.line:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
					if Widget.ShowTip then Widget.ShowTip(self, "Drag to move, right-click to remove") end
				end)
				marker:SetScript("OnLeave", function(self)
					hovering = track:IsMouseOver()
					StopDriver()
					local lineRed, lineGreen, lineBlue, lineAlpha = LineColor()
					self.line:SetVertexColor(lineRed, lineGreen, lineBlue, lineAlpha or 0.6)
					if Widget.HideTip then Widget.HideTip() end
				end)
				markers[tickIndex] = marker
			end
			marker.index = tickIndex
			marker.line:SetWidth(lineWidth)
			marker.line:SetVertexColor(red, green, blue, alpha or 0.6)
			PlaceLine(marker, list[tickIndex] or 0)
			marker:Show()
		end
		for markerIndex = #list + 1, #markers do markers[markerIndex]:Hide() end
		hint:SetShown(#list == 0)
	end

	function track.Commit()
		local list = options.get()
		table.sort(list)
		for tickIndex = #list, 2, -1 do
			if list[tickIndex] == list[tickIndex - 1] then table.remove(list, tickIndex) end
		end
		if options.onChange then options.onChange() end
		Layout()
	end

	function track.Driver()
		if dragIndex then
			local list = options.get()
			local percent = CursorPercent()
			if list[dragIndex] ~= percent then
				list[dragIndex] = percent
				Layout()
				if options.onChange then options.onChange() end
			end
			local accentRed, accentGreen, accentBlue = Theme.GetAccent()
			ShowLabel(percent, accentRed, accentGreen, accentBlue)
			ghost:Hide()
		elseif track:IsMouseOver() then
			local hoveredMarker
			for markerIndex = 1, #markers do
				if markers[markerIndex]:IsShown() and markers[markerIndex]:IsMouseOver() then hoveredMarker = markers[markerIndex]; break end
			end
			if hoveredMarker then
				ghost:Hide()
				ShowLabel(options.get()[hoveredMarker.index] or 0, 1, 1, 1)
			else
				local percent = CursorPercent()
				local accentRed, accentGreen, accentBlue = Theme.GetAccent()
				PlaceLine(ghost, percent)
				ghost:SetVertexColor(accentRed, accentGreen, accentBlue, 0.6)
				ghost:Show()
				ShowLabel(percent, accentRed, accentGreen, accentBlue)
			end
		else
			ghost:Hide()
			label:Hide()
		end
	end

	track:SetScript("OnEnter", function()
		hovering = true
		StartDriver()
	end)
	track:SetScript("OnLeave", function()
		hovering = false
		StopDriver()
	end)
	track:SetScript("OnClick", function()
		local list = options.get()
		local percent = CursorPercent()
		for _, value in ipairs(list) do if value == percent then return end end
		list[#list + 1] = percent
		track.Commit()
	end)
	track:SetScript("OnSizeChanged", Layout)

	track.Refresh = Layout
	Layout()
	return Widget.Wrap(track)
end
