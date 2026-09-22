local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local PageKit = BUILib.PageKit

function PageKit.PreviewBand(pageFrame, width, height, top, noDivider)
	local pinned = CreateFrame("Frame", nil, pageFrame)
	pinned:SetSize(width or Layout.PAGE_CONTENT_W, height or Layout.PAGE_PREVIEW_H)
	pinned:SetPoint("TOP", pageFrame, "TOP", 0, -(top or PageKit.PAD))
	pinned:SetFrameLevel((pageFrame:GetFrameLevel() or 0) + 30)
	pinned:EnableMouse(true)
	pinned:RegisterForDrag("LeftButton")

	pinned:SetScript("OnDragStart", function(self)
		local window = BUILib.ClientOf(self).popupParent
		if window and window.StartMoving then window:StartMoving() end
	end)
	pinned:SetScript("OnDragStop", function(self)
		local window = BUILib.ClientOf(self).popupParent
		if window and window.StopMovingOrSizing then window:StopMovingOrSizing() end
	end)

	if not noDivider then
		local divider = pinned:CreateTexture(nil, "OVERLAY")
		divider:SetColorTexture(1, 1, 1, 0.1)
		divider:SetHeight(1)
		divider:SetPoint("BOTTOMLEFT")
		divider:SetPoint("BOTTOMRIGHT")
	end

	return pinned
end

function PageKit.PreviewStage(parent, options)
	options = options or {}
	local card = CreateFrame("Frame", nil, parent)
	card:SetPoint("TOPLEFT")
	card:SetPoint("BOTTOMRIGHT")
	card:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
	local stage = CreateFrame("Frame", nil, card)
	if options.inset then
		stage:SetPoint("TOPLEFT", options.inset, -options.inset)
		stage:SetPoint("BOTTOMRIGHT", -options.inset, options.inset)
	else
		stage:SetSize(options.stageW or 2, options.stageH or 2)
		stage:SetPoint("CENTER")
	end
	stage:SetFrameLevel(card:GetFrameLevel() + 5)
	card.stage = stage
	if options.tick then
		local elapsed = 0
		card:SetScript("OnUpdate", function(self, deltaTime)
			elapsed = elapsed + deltaTime
			if elapsed >= options.tick then
				elapsed = 0
				if self.UpdatePreview then self:UpdatePreview() end
			end
		end)
	end
	return card, stage
end

function PageKit.TabBand(pageFrame, width, top)
	local band = CreateFrame("Frame", nil, pageFrame)
	band:SetSize(width or Layout.PAGE_CONTENT_W, PageKit.TAB_H + PageKit.GAP)
	band:SetPoint("TOP", pageFrame, "TOP", 0, -(top or 0))
	band:SetFrameLevel((pageFrame:GetFrameLevel() or 0) + 30)
	local divider = band:CreateTexture(nil, "OVERLAY")
	divider:SetColorTexture(1, 1, 1, 0.1)
	divider:SetHeight(1)
	divider:SetPoint("BOTTOMLEFT")
	divider:SetPoint("BOTTOMRIGHT")
	band.bottom = (top or 0) + PageKit.TAB_H + PageKit.GAP
	return band
end
