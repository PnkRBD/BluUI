local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local PageKit = BUILib.PageKit

function PageKit.Grid(panel, items, columnCount)
	Layout.SettingsGrid(panel, { cols = columnCount or 1, items = items })
	panel:Refresh()
end

function PageKit.CardGrid(tab, options)
	options = options or {}
	local grid = Layout.SettingsCardGrid(tab, {
		columns = options.columns or 2, gap = options.gap or 12, topMargin = options.topMargin or 12,
	})
	local dimmable = options.dimmable or {}
	grid._dimmable = dimmable
	local origAddCard = grid.AddCard
	grid.AddCard = function(self, cardDef)
		cardDef = cardDef or {}
		local skipDim = cardDef._skipDim
		cardDef._skipDim = nil
		if not cardDef.spanFull and not cardDef.column then
			local minColumn, minHeight = 1, self._columnFrames[1]:GetHeight() or 0
			for columnIndex = 2, self._columns do
				local columnHeight = self._columnFrames[columnIndex]:GetHeight() or 0
				if columnHeight < minHeight then minColumn, minHeight = columnIndex, columnHeight end
			end
			cardDef.column = minColumn
		end
		local card = origAddCard(self, cardDef)
		if not skipDim then dimmable[#dimmable + 1] = card end
		return card
	end
	function grid:SyncDim(enabled)
		local dimmed = not enabled
		for index = 1, #dimmable do dimmable[index]:SetDimmed(dimmed) end
	end
	return grid
end

