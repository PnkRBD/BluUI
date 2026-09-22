local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Widget = BUILib.Widget
local PageKit = BUILib.PageKit

function Widget.AttachLockOverlay(frame, options)
	if frame._lockedOverlay then return frame._lockedOverlay, frame._lockedText end
	options = options or {}
	local overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	if frame._gridCellOffset then
		local rowPad = frame._gridRowPad or 0
		overlay:SetPoint("TOPLEFT", -frame._gridCellOffset, rowPad)
		overlay:SetPoint("BOTTOMRIGHT", 4, -rowPad)
	elseif options.nonGridPad then
		overlay:SetPoint("TOPLEFT", -options.nonGridPad, 0)
		overlay:SetPoint("BOTTOMRIGHT", options.nonGridPad, 0)
	else
		local leftPadding = 4
		local width = frame:GetWidth() or 0
		if width > 0 and width < 80 then leftPadding = 96 - width end
		overlay:SetPoint("TOPLEFT", -leftPadding, 0)
		overlay:SetPoint("BOTTOMRIGHT", 4, 0)
	end
	overlay:SetBackdrop({ bgFile = Widget.WHITE })
	overlay:SetBackdropColor(0, 0, 0, 0.85)
	overlay:EnableMouse(true)
	overlay:SetFrameLevel(options.frameLevel or (frame:GetFrameLevel() + 50))
	local text = overlay:CreateFontString(nil, "OVERLAY")
	text:SetFont(BUILib.Font, 12, "")
	text:SetPoint("CENTER")
	text:SetText("LOCKED")
	text:SetTextColor(1, 1, 1, 1)
	overlay:Hide()
	frame._lockedOverlay = overlay
	frame._lockedText = text
	return overlay, text
end

local function SetLockTip(overlay, tooltipText)
	if not overlay then return end
	if not overlay._lockTipHooked then
		overlay._lockTipHooked = true
		overlay:SetScript("OnEnter", function(hoveredOverlay)
			if hoveredOverlay._lockTip and Widget.ShowTip then Widget.ShowTip(hoveredOverlay, hoveredOverlay._lockTip) end
		end)
		overlay:SetScript("OnLeave", function()
			if Widget.HideTip then Widget.HideTip() end
		end)
	end
	overlay._lockTip = tooltipText
end

function PageKit.SyncAnchorLocks(posX, posY, centerCheckbox, anchored, centered)
	local ANCHOR_TIP = "Clear the Anchor Frame to unlock"
	local CENTER_TIP = "Disable Center Horizontally to unlock"

	local function lock(slider, isLocked, text, tooltipText)
		if not slider then return end
		if isLocked then
			slider:SetLockedText(text)
			slider:SetLocked(true)
			local sliderFrame = Widget.Unwrap(slider)
			SetLockTip(sliderFrame and sliderFrame._lockedOverlay, tooltipText)
		else
			slider:SetLocked(false)
		end
	end
	lock(posX, anchored or centered, anchored and "ANCHORED" or "CENTERED", anchored and ANCHOR_TIP or CENTER_TIP)
	lock(posY, anchored, "ANCHORED", ANCHOR_TIP)
	if centerCheckbox then
		local checkboxFrame = Widget.Unwrap(centerCheckbox)
		if checkboxFrame then
			Widget.AttachLockOverlay(checkboxFrame)
			checkboxFrame._lockedText:SetText("ANCHORED")
			checkboxFrame._lockedOverlay:SetShown(anchored and true or false)
			SetLockTip(checkboxFrame._lockedOverlay, ANCHOR_TIP)

			if checkboxFrame.SetEnabled then checkboxFrame:SetEnabled(not anchored) end
		end
	end
end
