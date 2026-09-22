local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local Widget = BUILib.Widget
local PageKit = BUILib.PageKit
local floor = math.floor

function PageKit.TabStrip(root, tabDefs, groups, defaultKey, width, onSelect)
	width = width or Layout.PAGE_CONTENT_W
	local tabWidth = floor((width - PageKit.TAB_GAP * (#tabDefs - 1)) / #tabDefs)
	local selected = defaultKey or tabDefs[1].key
	local tabFrames = {}

	local function ApplyTab()
		for key, frames in pairs(groups) do
			local show = (key == selected)
			for _, frame in ipairs(frames) do
				if show then frame:Show() else frame:Hide() end
			end
		end
	end

	for tabIndex, tabDef in ipairs(tabDefs) do
		local card = Controls.HeroCard(root, {
			horizontal  = true,
			title       = tabDef.title,
			image       = tabDef.image,
			imageRaw    = tabDef.imageRaw,
			imageAtlas  = tabDef.imageAtlas,
			footerLabel = tabDef.footerLabel or "Settings",
			width       = tabWidth,
			height      = PageKit.TAB_H,
			onClick     = function(_, frame)
				selected = tabDef.key
				for _, other in ipairs(tabFrames) do
					other:SetSelected(other == frame)
				end
				ApplyTab()
				if onSelect then onSelect(selected) end
			end,
		})
		local tabFrame = Widget.Unwrap(card)
		tabFrame:SetPoint("TOPLEFT", root, "TOPLEFT", (tabIndex - 1) * (tabWidth + PageKit.TAB_GAP), 0)
		tabFrame:SetSelected(tabDef.key == selected)
		tabFrames[tabIndex] = tabFrame
	end

	return ApplyTab
end

