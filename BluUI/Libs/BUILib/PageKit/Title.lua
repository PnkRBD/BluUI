local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local Widget = BUILib.Widget
local PageKit = BUILib.PageKit

function PageKit.PageTitle(pageFrame, text, width, options)
	local contentWidth = width or Layout.PAGE_CONTENT_W
	local holder = CreateFrame("Frame", nil, pageFrame)
	holder:SetPoint("TOP", pageFrame, "TOP", 0, -PageKit.PAD)

	local row = CreateFrame("Frame", nil, holder)
	row:SetSize(contentWidth, 30)
	row:SetPoint("TOP", holder, "TOP", 0, 0)
	holder.row = row

	local titleText = row:CreateFontString(nil, "OVERLAY")
	titleText:SetFont(BUILib.Font, 22, "")
	titleText:SetTextColor(1, 1, 1, 1)
	titleText:SetText(text)
	holder.text = titleText

	if options and options.back then
		local backButton = Controls.Icon(row, {
			texture = BUILib.GetLibMedia("dropdown"),
			size = 26,
			iconScale = 0.7,
			idleColor = {0.85, 0.85, 0.88, 1},
			hoverColor = {1, 1, 1, 1},
			tooltip = options.back.tooltip or options.back.text or "Back",
			onClick = options.back.onClick,
		})
		local backFrame = Widget.Unwrap(backButton)
		backFrame:SetPoint("LEFT", row, "LEFT", -4, 0)
		backFrame.icon:SetRotation(-math.pi / 2)
		holder.backButton = backButton
		titleText:SetPoint("LEFT", backFrame, "RIGHT", 6, 0)
	else
		titleText:SetPoint("LEFT", 0, 0)
	end

	local firstSlot, rightAnchor
	local function PlaceRight(frame)
		frame:ClearAllPoints()
		frame:SetParent(row)
		if rightAnchor then
			frame:SetPoint("RIGHT", rightAnchor, "LEFT", -14, 0)
		else
			firstSlot = frame
		end
		rightAnchor = frame
	end
	if options and options.anchor then
		local eye = Controls.IconToggle(row, options.anchor.value, options.anchor.onToggle, {
			texture = BUILib.GetLibMedia("eye"),
			tooltip = options.anchor.tooltip or "Show or hide the move anchor",
		})
		PlaceRight(Widget.Unwrap(eye))
		holder.anchorToggle = eye
	end
	if options and options.enable then
		local gate = options.enable.gate
		local function Allowed() return not gate or gate() end

		local hint
		local toggle = Controls.IconToggle(row, options.enable.value, function(value)
			if hint then hint:SetShown(not value) end
			if options.enable.onToggle then options.enable.onToggle(value) end
		end, {
			texture = BUILib.GetLibMedia("enable"),
			tooltip = options.enable.tooltip or "Enable or disable this module",
			disabledTooltip = options.enable.disabledTooltip
				or "Turned off in Settings > Modules. Re-enable it there to use these settings.",
		})
		PlaceRight(Widget.Unwrap(toggle))
		holder.enableToggle = toggle

		local toggleFrame = Widget.Unwrap(toggle)
		hint = PageKit.HintArrow(toggleFrame, { label = "Enable" })
		hint:SetShown(not options.enable.value and Allowed())
		holder.enableHint = hint

		local origSetValue = toggleFrame.SetValue
		toggleFrame.SetValue = function(self, value)
			origSetValue(self, value)
			hint:SetShown(not value and Allowed())
		end

		if gate then
			local function ApplyGate()
				local allowed = Allowed()
				toggleFrame:SetEnabled(allowed)
				hint:SetShown(allowed and not toggleFrame:GetValue())
			end
			ApplyGate()
			holder:HookScript("OnShow", ApplyGate)
			holder.ApplyEnableGate = ApplyGate
		end
	end
	if options and options.preview then
		local eye = Controls.IconToggle(row, false, options.preview.onToggle, {
			texture = BUILib.GetLibMedia("eye"),
			tooltip = options.preview.tooltip or "Preview",
		})
		PlaceRight(Widget.Unwrap(eye))
		holder.previewToggle = eye
	end
	if options and options.button then
		local button = Controls.Button(row, options.button.text, options.button.width or 110, options.button.onClick)
		PlaceRight(Widget.Unwrap(button))
		holder.button = button
	end

	local height = 30
	if options and options.desc then
		local descriptionText = holder:CreateFontString(nil, "OVERLAY")
		descriptionText:SetFont(BUILib.Font, 12, "")
		descriptionText:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -1)
		descriptionText:SetWidth(contentWidth)
		descriptionText:SetJustifyH("LEFT")
		descriptionText:SetTextColor(0.6, 0.6, 0.64, 1)
		descriptionText:SetText(options.desc)
		holder.desc = descriptionText
		height = height + 17
	end

	local divider = holder:CreateTexture(nil, "OVERLAY")
	divider:SetColorTexture(1, 1, 1, 0.1)
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(height + 6))
	divider:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -(height + 6))
	height = height + 7

	if firstSlot then firstSlot:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 9) end

	holder:SetSize(contentWidth, height)
	return height + PageKit.GAP, holder
end
