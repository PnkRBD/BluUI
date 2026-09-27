local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget

local PAD = 20
local RADIUS = 10
local SAMPLES = 40
local SAMPLE_GAP = 2
local SPARK_TOP, SPARK_HEIGHT = 86, 60
local SIGNAL = { 6, 10, 14, 18 }
local SIGNAL_ROW = 46
local SHEET_ROW = 20
local FEED_ROW = 26
local CHECK_ROW = 22
local TIMELINE_ROW = 36
local TILE_HEIGHT = 52
local TILE_GAP = 8
local MINI_HEIGHT = 174
local MINI_GAP = 12
local KEY_ROW = 42
local PORTRAIT = 30
local PORTRAIT_STEP = 22
local FIELD_HEIGHT = 30
local ACTION_ROOM = 90
local SWATCH = 20
local SWATCH_GAP = 6
local HEADER = 56
local CHIP_HEIGHT = 26
local CHIP_GAP = 8

local function Clamp(fraction)
	return math.max(0, math.min(1, fraction or 0))
end

Layout.CardKitExtensions[#Layout.CardKitExtensions + 1] = function(cards, kit, window)
	local function Capped(label, width)
		label:SetWidth(width)
		label:SetWordWrap(false)
		return label
	end

	function cards.Panel(parent, x, y, width, height, role, radius)
		local panel = CreateFrame('Frame', nil, parent)
		panel:SetPoint('TOPLEFT', x, -y)
		panel:SetSize(width, height)
		for _, piece in ipairs(Widget.DrawRoundedRect(panel, radius or 8, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)) do window:Paint(piece, role or 'input') end
		return panel
	end

	function cards.Field(parent, x, y, width, height)
		local box = CreateFrame('EditBox', nil, parent)
		box:SetPoint('TOPLEFT', x, -y)
		box:SetSize(width, height or FIELD_HEIGHT)
		local fill = box:CreateTexture(nil, 'BACKGROUND')
		fill:SetTexture(Widget.WHITE)
		fill:SetAllPoints()
		window:Paint(fill, 'input')
		box:SetAutoFocus(false)
		box:SetFont(window.font, 12, '')
		window:Paint(box, 'text')
		window:SetFontRole(box, 'control')
		box:SetTextInsets(10, 10, 0, 0)
		box:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
		box:SetScript('OnEditFocusGained', function(self) self:HighlightText() end)
		return box
	end

	function cards.Placeholder(box, text)
		local hint = kit.Text(box, text, 12, 'faint')
		hint:SetPoint('LEFT', 10, 0)
		box:HookScript('OnTextChanged', function(self) hint:SetShown(self:GetText() == '') end)
		return hint
	end

	function cards.Header(card, width, title, caption)
		cards.Label(card, title, PAD, 18, 15, 'text')
		local right = kit.Text(card, caption:upper(), 9, 'faint')
		right:SetPoint('TOPRIGHT', -PAD, -23)
		local rule = kit.Fill(card, 'rule', 'ARTWORK')
		rule:SetPoint('TOPLEFT', 1, -HEADER)
		rule:SetPoint('TOPRIGHT', -1, -HEADER)
		rule:SetHeight(1)
		return HEADER
	end

	function cards.Footer(card, height, note, buttons)
		local footer = CreateFrame('Frame', nil, card)
		footer:SetPoint('BOTTOMLEFT', 1, 1)
		footer:SetPoint('BOTTOMRIGHT', -1, 1)
		footer:SetHeight(height)
		for _, piece in ipairs(Widget.DrawRoundedRect(footer, RADIUS - 1, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)) do window:Paint(piece, 'input') end
		local square = kit.Fill(footer, 'input', 'BACKGROUND', 1)
		square:SetPoint('TOPLEFT')
		square:SetPoint('TOPRIGHT')
		square:SetHeight(math.floor(height / 2))
		local rule = kit.Fill(footer, 'rule', 'ARTWORK')
		rule:SetPoint('TOPLEFT')
		rule:SetPoint('TOPRIGHT')
		rule:SetHeight(1)
		local caption = kit.Text(footer, note:upper(), 9, 'faint')
		caption:SetPoint('LEFT', PAD, 0)
		local anchor
		for index = #buttons, 1, -1 do
			local spec = buttons[index]
			local button = kit.Button(footer, spec.text, spec.style, spec.onClick, spec.icon)
			if anchor then
				button:SetPoint('RIGHT', anchor, 'LEFT', -8, 0)
			else
				button:SetPoint('RIGHT', -16, 0)
			end
			anchor = button
		end
		return footer
	end

	function cards.Sparkline(parent, x, y, width, spec)
		local height = 170
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.range = kit.Text(card, '', 11, 'muted')
		card.range:SetPoint('TOPRIGHT', -PAD, -20)
		card.value = cards.Readout(card, PAD, 38, 34)
		local chartWidth = width - PAD * 2
		local count = spec.samples or SAMPLES
		local barWidth = (chartWidth - SAMPLE_GAP * (count - 1)) / count
		cards.Rule(card, PAD, SPARK_TOP + SPARK_HEIGHT, chartWidth)
		local bars = {}
		for index = 1, count do
			local bar = kit.Fill(card, 'accent', 'ARTWORK')
			bar:SetPoint('BOTTOMLEFT', card, 'TOPLEFT', PAD + (index - 1) * (barWidth + SAMPLE_GAP), -(SPARK_TOP + SPARK_HEIGHT))
			bar:SetSize(barWidth, 1)
			bar:SetAlpha(index == count and 1 or 0.4)
			bars[index] = bar
		end
		function card:Set(samples, text, range)
			local high = 1
			for _, sample in ipairs(samples) do high = math.max(high, sample) end
			for index, bar in ipairs(bars) do
				local sample = samples[#samples - count + index]
				bar:SetHeight(sample and math.max(1, SPARK_HEIGHT * sample / high) or 1)
			end
			self.value:SetText(text or '')
			self.range:SetText(range or '')
		end
		if spec.read then
			local samples = {}
			cards.Every(card, spec.every or 1, function()
				local sample, text, range = spec.read()
				samples[#samples + 1] = sample
				if #samples > count then table.remove(samples, 1) end
				card:Set(samples, text, range)
			end)
		else
			card:Set(spec.list or {}, spec.text, spec.range)
		end
		return card
	end

	function cards.Compare(parent, x, y, width, spec)
		local height = 170
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		local count = #spec.columns
		local columnWidth = math.floor((width - PAD * 2 - 25 * (count - 1)) / count)
		card.columns = {}
		for index, entry in ipairs(spec.columns) do
			local left = PAD + (index - 1) * (columnWidth + 25)
			if index > 1 then
				local divider = kit.Fill(card, 'rule', 'ARTWORK')
				divider:SetPoint('TOPLEFT', left - 13, -50)
				divider:SetSize(1, height - 50 - PAD)
			end
			local column = CreateFrame('Button', nil, card)
			column:SetPoint('TOPLEFT', left, -48)
			column:SetSize(columnWidth, height - 48 - PAD + 4)
			column:SetScript('OnClick', function() if entry.onClick then entry.onClick() end end)
			cards.Badge(column, entry.icon or 'glow', 36, 0, 2, true)
			Capped(cards.Label(column, entry.title, 48, 4, 13, 'text'), columnWidth - 48)
			Capped(cards.Label(column, entry.sub or '', 48, 24, 11, 'muted'), columnWidth - 48)
			local status = kit.Status(column, spec.activeText or 'In use')
			status:SetPoint('TOPLEFT', 48, -42)
			cards.Description(column, entry.note or '', 0, 66, columnWidth)
			card.columns[index] = { status = status, active = entry.active }
		end
		window:Bind(card, function()
			for _, column in ipairs(card.columns) do column.status:SetShown(column.active ~= nil and column.active() == true) end
		end)
		return card
	end

	function cards.Signal(parent, x, y, width, spec)
		local count = #spec.rows
		local height = 46 + count * SIGNAL_ROW + PAD - 12
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.rows = {}
		for index, row in ipairs(spec.rows) do
			local rowY = 46 + (index - 1) * SIGNAL_ROW
			cards.Label(card, row.label, PAD, rowY, 11, 'muted')
			local value = cards.Label(card, '', PAD, rowY + 14, 18, 'text')
			local bars = {}
			for barIndex, barHeight in ipairs(SIGNAL) do
				local bar = kit.Fill(card, 'control', 'ARTWORK')
				bar:SetPoint('BOTTOMRIGHT', card, 'TOPRIGHT', -(PAD + (4 - barIndex) * 7), -(rowY + 32))
				bar:SetSize(4, barHeight)
				bars[barIndex] = bar
			end
			card.rows[index] = { value = value, bars = bars }
		end
		function card:Set(readings)
			for index, row in ipairs(self.rows) do
				local reading = readings[index] or {}
				row.value:SetText(reading.text or '')
				for barIndex, bar in ipairs(row.bars) do window:Paint(bar, barIndex <= (reading.strength or 0) and 'accent' or 'control') end
			end
		end
		if not cards.Drive(card, spec, function(readings) card:Set(readings) end) then card:Set(spec.readings or {}) end
		return card
	end

	function cards.Details(parent, x, y, width, spec)
		local count = #spec.rows
		local height = 44 + count * SHEET_ROW + PAD
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.values = {}
		for index, row in ipairs(spec.rows) do
			local rowY = 44 + (index - 1) * SHEET_ROW
			if index > 1 then cards.Rule(card, PAD, rowY - 5, width - PAD * 2) end
			cards.Label(card, row.label, PAD, rowY, 11, 'muted')
			local value = kit.Text(card, '', 11, 'text')
			value:SetPoint('TOPRIGHT', -PAD, -rowY)
			card.values[index] = value
		end
		function card:Set(values)
			for index, value in ipairs(self.values) do value:SetText(values[index] or '') end
		end
		if not cards.Drive(card, spec, function(values) card:Set(values) end) then card:Set(spec.values or {}) end
		return card
	end

	function cards.Feed(parent, x, y, width, spec)
		local count = spec.rows or 5
		local height = 48 + count * FEED_ROW + PAD - 6
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		local line = kit.Fill(card, 'rule', 'ARTWORK')
		line:SetPoint('TOPLEFT', PAD + 3, -56)
		line:SetWidth(1)
		card.rows = {}
		for index = 1, count do
			local rowY = 48 + (index - 1) * FEED_ROW
			local dot = kit.Disc(card, 7, index == 1 and 'accent' or 'muted', 'ARTWORK', 1)
			dot:SetPoint('TOPLEFT', PAD, -(rowY + 4))
			local label = Capped(cards.Label(card, '', PAD + 18, rowY, 12, 'text'), width - PAD * 2 - 18 - 70)
			local when = kit.Text(card, '', 11, 'muted')
			when:SetPoint('TOPRIGHT', -PAD, -(rowY + 1))
			card.rows[index] = { dot = dot, label = label, when = when }
		end
		card.empty = cards.Description(card, spec.empty or 'Nothing yet.', PAD, 52, width - PAD * 2)
		function card:Set(entries)
			self.empty:SetShown(#entries == 0)
			line:SetShown(#entries > 1)
			line:SetHeight(math.max(1, (math.min(#entries, count) - 1) * FEED_ROW))
			for index, row in ipairs(self.rows) do
				local entry = entries[index]
				row.dot:SetShown(entry ~= nil)
				row.label:SetShown(entry ~= nil)
				row.when:SetShown(entry ~= nil)
				if entry then
					row.label:SetText(entry.text)
					row.when:SetText(entry.when or '')
				end
			end
		end
		if not cards.Drive(card, spec, function(entries) card:Set(entries) end) then card:Set(spec.entries or {}) end
		return card
	end

	function cards.Checklist(parent, x, y, width, spec)
		local count = #spec.items
		local height = 46 + count * CHECK_ROW + 34 + PAD
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.progress = kit.Text(card, '', 11, 'muted')
		card.progress:SetPoint('TOPRIGHT', -PAD, -20)
		card.rows = {}
		for index, item in ipairs(spec.items) do
			local rowY = 46 + (index - 1) * CHECK_ROW
			local ring = kit.Disc(card, 16, 'rule')
			ring:SetPoint('TOPLEFT', PAD, -rowY)
			local hole = kit.Disc(card, 12, 'panel', 'ARTWORK', 1)
			hole:SetPoint('CENTER', ring)
			local tick = kit.Glyph(card, 'check', 10, 'onAccent', 'OVERLAY')
			tick:SetPoint('CENTER', ring)
			local label = Capped(cards.Label(card, item, PAD + 26, rowY + 2, 12, 'text'), width - PAD * 2 - 26)
			card.rows[index] = { ring = ring, hole = hole, tick = tick, label = label }
		end
		card.bar = cards.Bar(card, PAD, height - PAD - 6, width - PAD * 2, 6)
		function card:Set(states)
			local done = 0
			for index, row in ipairs(self.rows) do
				local complete = states[index] == true
				if complete then done = done + 1 end
				window:Paint(row.ring, complete and 'accent' or 'rule')
				row.hole:SetShown(not complete)
				row.tick:SetShown(complete)
				window:Paint(row.label, complete and 'muted' or 'text')
			end
			self.progress:SetText(('%d of %d done'):format(done, count))
			self.bar:SetFraction(done / count)
		end
		if not cards.Drive(card, spec, function(states) card:Set(states) end) then card:Set(spec.states or {}) end
		return card
	end

	function cards.Gauge(parent, x, y, width, spec)
		local height = 150
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.value = cards.Readout(card, PAD, 42, 34)
		card.note = Capped(cards.Label(card, '', PAD, 86, 11, 'muted'), width - PAD * 2)
		card.fill = cards.Bar(card, PAD, height - PAD - 8, width - PAD * 2, 8)
		function card:Set(fraction, text, note)
			self.value:SetText(text or '')
			self.note:SetText(note or '')
			self.fill:SetFraction(fraction)
			window:Paint(self.fill, spec.low and fraction < spec.low and 'danger' or 'accent')
		end
		if not cards.Drive(card, spec, function(fraction, text, note) card:Set(fraction, text, note) end) then card:Set(spec.fraction or 0, spec.text, spec.note) end
		return card
	end

	function cards.Segments(parent, x, y, width, spec)
		local height = 150
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.value = cards.Readout(card, PAD, 42, 34)
		card.note = Capped(cards.Label(card, '', PAD, 86, 11, 'muted'), width - PAD * 2)
		local barY, barWidth, gap = height - PAD - 8, width - PAD * 2, 3
		local count = spec.count or 6
		local segments = {}
		for index = 1, count do
			local track = kit.Fill(card, 'control', 'ARTWORK')
			track:SetHeight(8)
			track:Hide()
			local used = kit.Fill(card, 'accent', 'ARTWORK', 1)
			used:SetHeight(8)
			used:SetPoint('TOPLEFT', track)
			used:Hide()
			segments[index] = { track = track, used = used }
		end
		function card:Set(list, text, note)
			self.value:SetText(text or '')
			self.note:SetText(note or '')
			local total = 0
			for _, entry in ipairs(list) do total = total + entry.size end
			local shown = math.min(#list, count)
			local usable = barWidth - gap * math.max(0, shown - 1)
			local left = PAD
			for index, segment in ipairs(segments) do
				local entry = list[index]
				segment.track:SetShown(entry ~= nil)
				segment.used:SetShown(entry ~= nil)
				if entry then
					local segmentWidth = math.max(2, math.floor(usable * entry.size / math.max(total, 1)))
					segment.track:ClearAllPoints()
					segment.track:SetPoint('TOPLEFT', left, -barY)
					segment.track:SetWidth(segmentWidth)
					segment.used:SetWidth(math.max(1, segmentWidth * Clamp(entry.used / math.max(entry.size, 1))))
					left = left + segmentWidth + gap
				end
			end
		end
		if not cards.Drive(card, spec, function(list, text, note) card:Set(list, text, note) end) then card:Set(spec.list or {}, spec.text, spec.note) end
		return card
	end

	function cards.Hero(parent, x, y, width, spec)
		local height = 150
		local card = cards.Card(parent, x, y, width, height)
		local ring = kit.Disc(card, 52, nil)
		ring:SetPoint('TOPLEFT', PAD - 2, -(PAD - 2))
		window:Bind(ring, function(region)
			if spec.ringColor then region:SetVertexColor(spec.ringColor[1], spec.ringColor[2], spec.ringColor[3], 1) else region:SetVertexColor(window:Color('rule')) end
		end)
		local icon = card:CreateTexture(nil, 'ARTWORK', nil, 1)
		icon:SetSize(48, 48)
		icon:SetPoint('CENTER', ring)
		icon:SetMask(BUILib.GetLibMedia('circle_mask'))
		card.icon = icon
		card.name = Capped(cards.Label(card, '', PAD + 66, PAD + 4, 15, 'text'), width - PAD * 2 - 66)
		card.sub = Capped(cards.Label(card, '', PAD + 66, PAD + 26, 12, 'muted'), width - PAD * 2 - 66)
		card.body = cards.Description(card, '', PAD, 88, width - PAD * 2)
		card.body:SetMaxLines(3)
		function card:Set(name, sub, description, texture, unit)
			self.name:SetText(name or '')
			self.sub:SetText(sub or '')
			self.body:SetText(description or '')
			if unit then SetPortraitTexture(self.icon, unit) elseif texture then self.icon:SetTexture(texture) end
		end
		if not cards.Drive(card, spec, function(name, sub, description, texture, unit) card:Set(name, sub, description, texture, unit) end) then
			card:Set(spec.name, spec.sub, spec.description, spec.icon, spec.unit)
		end
		return card
	end

	function cards.People(parent, x, y, width, spec)
		local height = 150
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.count = kit.Text(card, '', 11, 'muted')
		card.count:SetPoint('TOPRIGHT', -PAD, -20)
		local max = spec.max or 5
		local holders = {}
		for index = 1, max do
			local holder = CreateFrame('Frame', nil, card)
			holder:SetSize(PORTRAIT + 4, PORTRAIT + 4)
			holder:SetPoint('TOPLEFT', PAD - 2 + (index - 1) * PORTRAIT_STEP, -48)
			holder:SetFrameLevel(card:GetFrameLevel() + max - index + 1)
			kit.Disc(holder, PORTRAIT + 4, 'panel'):SetPoint('CENTER')
			local portrait = holder:CreateTexture(nil, 'ARTWORK', nil, 1)
			portrait:SetSize(PORTRAIT, PORTRAIT)
			portrait:SetPoint('CENTER')
			portrait:SetMask(BUILib.GetLibMedia('circle_mask'))
			holder.portrait = portrait
			holders[index] = holder
		end
		card.more = kit.Text(card, '', 12, 'muted')
		card.names = cards.Description(card, '', PAD, 94, width - PAD * 2)
		card.names:SetMaxLines(2)
		function card:Set(list, count, names)
			local shown = math.min(#list, max)
			for index, holder in ipairs(holders) do
				holder:SetShown(index <= shown)
				if index <= shown then
					local entry = list[index]
					if entry.unit then SetPortraitTexture(holder.portrait, entry.unit) else holder.portrait:SetTexture(entry.icon) end
				end
			end
			self.more:SetShown(#list > max)
			self.more:SetText('+' .. (#list - max))
			self.more:ClearAllPoints()
			if shown > 0 then self.more:SetPoint('LEFT', holders[shown], 'RIGHT', 8, 0) end
			self.count:SetText(count or '')
			self.names:SetText(names or '')
		end
		if not cards.Drive(card, spec, function(list, count, names) card:Set(list, count, names) end) then card:Set(spec.list or {}, spec.count, spec.names) end
		return card
	end

	function cards.Timeline(parent, x, y, width, spec)
		local count = spec.rows or 5
		local height = 46 + count * TIMELINE_ROW + PAD - 6
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		local innerWidth = width - PAD * 2
		local line = kit.Fill(card, 'rule', 'ARTWORK')
		line:SetPoint('TOPLEFT', PAD + 3, -(46 + 12))
		line:SetSize(1, (count - 1) * TIMELINE_ROW)
		card.rows = {}
		for index = 1, count do
			local rowY = 46 + (index - 1) * TIMELINE_ROW
			local dot = cards.Dot(card, 7, index, 'ARTWORK', 1)
			dot:SetPoint('TOPLEFT', PAD, -(rowY + 9))
			local time = cards.Painted(card, 11, 'body', function(region)
				local color = cards.SeriesColor(index)
				if type(color) == 'string' then region:SetTextColor(window:Color(color)) else region:SetTextColor(color[1], color[2], color[3], 1) end
			end)
			time:SetPoint('TOPLEFT', PAD + 18, -(rowY + 6))
			local label = Capped(cards.Label(card, '', PAD + 78, rowY + 6, 12, 'text'), innerWidth - 78 - 90)
			local right = kit.Text(card, '', 11, 'muted')
			right:SetPoint('TOPRIGHT', -PAD, -(rowY + 6))
			card.rows[index] = { dot = dot, time = time, label = label, right = right }
		end
		function card:Set(entries)
			local shown = 0
			for index, row in ipairs(self.rows) do
				local entry = entries[index]
				row.dot:SetShown(entry ~= nil)
				row.time:SetShown(entry ~= nil)
				row.label:SetShown(entry ~= nil)
				row.right:SetShown(entry ~= nil)
				if entry then
					row.time:SetText(entry.time or '')
					row.label:SetText(entry.label or '')
					row.right:SetText(entry.right or '')
					shown = index
				end
			end
			line:SetShown(shown > 1)
			line:SetHeight(math.max(1, (shown - 1) * TIMELINE_ROW))
		end
		if not cards.Drive(card, spec, function(entries) card:Set(entries) end) then card:Set(spec.entries or {}) end
		return card
	end

	function cards.Tiles(parent, x, y, width, spec)
		local count = spec.count or 3
		local height = 46 + TILE_HEIGHT + 16 + PAD
		local card = cards.Card(parent, x, y, width, height)
		cards.Caption(card, spec.caption, PAD, PAD)
		card.total = kit.Text(card, '', 12, 'text')
		card.total:SetPoint('TOPRIGHT', -PAD, -(PAD - 1))
		local innerWidth = width - PAD * 2
		local tileWidth = math.floor((innerWidth - TILE_GAP * (count - 1)) / count)
		local barY = 46 + TILE_HEIGHT + 8
		local tiles = {}
		for index = 1, count do
			local tile = cards.Panel(card, PAD + (index - 1) * (tileWidth + TILE_GAP), 46, tileWidth, TILE_HEIGHT, 'input', 6)
			local top = cards.Fill(tile, index, 'ARTWORK')
			top:SetPoint('TOPLEFT', 6, 0)
			top:SetPoint('TOPRIGHT', -6, 0)
			top:SetHeight(2)
			local name = Capped(cards.Label(tile, '', 10, 10, 11, 'text'), tileWidth - 20)
			local sub = Capped(cards.Label(tile, '', 10, 28, 10, 'muted'), tileWidth - 20)
			local segment = cards.Fill(card, index, 'ARTWORK')
			segment:SetHeight(4)
			tiles[index] = { frame = tile, name = name, sub = sub, segment = segment }
		end
		card.empty = cards.Description(card, spec.empty or 'Nothing to show yet.', PAD, 60, innerWidth)
		function card:Set(entries, total)
			local sum, shown = 0, 0
			for index = 1, count do
				local entry = entries[index]
				if entry then
					sum = sum + entry.fraction
					shown = shown + 1
				end
			end
			local usable = innerWidth - 4 * math.max(0, shown - 1)
			local left = PAD
			for index, tile in ipairs(tiles) do
				local entry = entries[index]
				tile.frame:SetShown(entry ~= nil)
				tile.segment:SetShown(entry ~= nil)
				if entry then
					tile.name:SetText(entry.name)
					tile.sub:SetText(entry.sub or '')
					local segmentWidth = math.max(2, math.floor(usable * (sum > 0 and entry.fraction / sum or 1 / shown)))
					tile.segment:ClearAllPoints()
					tile.segment:SetPoint('TOPLEFT', card, 'TOPLEFT', left, -barY)
					tile.segment:SetWidth(segmentWidth)
					left = left + segmentWidth + 4
				end
			end
			self.total:SetText(total or '')
			self.empty:SetShown(#entries == 0)
		end
		if not cards.Drive(card, spec, function(entries, total) card:Set(entries, total) end) then card:Set(spec.entries or {}, spec.total) end
		return card
	end

	function cards.MiniBars(parent, x, y, width, spec)
		local count, barCount = spec.count or 4, spec.bars or 4
		local height = 46 + MINI_HEIGHT + PAD
		local card = cards.Card(parent, x, y, width, height)
		cards.Caption(card, spec.caption, PAD, PAD)
		local innerWidth = width - PAD * 2
		local miniWidth = math.floor((innerWidth - MINI_GAP * (count - 1)) / count)
		local minis = {}
		for index = 1, count do
			local mini = cards.Panel(card, PAD + (index - 1) * (miniWidth + MINI_GAP), 46, miniWidth, MINI_HEIGHT, 'input', 8)
			mini.title = Capped(cards.Label(mini, '', 14, 14, 12, 'text'), miniWidth - 28)
			mini.bars = {}
			for barIndex = 1, barCount do
				local barY = 38 + (barIndex - 1) * 32
				local fill = cards.Bar(mini, 14, barY, miniWidth - 28, 4, index)
				mini.bars[barIndex] = { fill = fill, label = Capped(cards.Label(mini, '', 14, barY + 9, 10, 'muted'), miniWidth - 28) }
			end
			minis[index] = mini
		end
		function card:Set(list)
			for index, mini in ipairs(minis) do
				local entry = list[index]
				mini:SetShown(entry ~= nil)
				if entry then
					mini.title:SetText(entry.title or '')
					for barIndex, bar in ipairs(mini.bars) do
						local item = entry.bars[barIndex] or {}
						bar.label:SetText(item.label or '')
						bar.fill:SetFraction(item.fraction)
					end
				end
			end
		end
		if not cards.Drive(card, spec, function(list) card:Set(list) end) then card:Set(spec.list or {}) end
		return card
	end

	function cards.KeyValues(parent, x, y, width, spec)
		local count = #spec.rows
		local height = 46 + count * KEY_ROW + PAD - 12
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		local valueX, statusX = math.floor(width * 0.36), math.floor(width * 0.56)
		card.cells = {}
		for index, row in ipairs(spec.rows) do
			local rowY = 46 + (index - 1) * KEY_ROW
			if index > 1 then cards.Rule(card, PAD, rowY - 6, width - PAD * 2) end
			Capped(cards.Label(card, row.label .. ':', PAD, rowY + 6, 12, 'muted'), valueX - PAD - 6)
			local value = Capped(cards.Label(card, '', valueX, rowY + 6, 12, 'text'), statusX - valueX - 6)
			local dot = kit.Disc(card, 7, 'accent', 'ARTWORK', 1)
			dot:SetPoint('TOPLEFT', statusX, -(rowY + 9))
			local status = Capped(cards.Label(card, '', statusX + 14, rowY + 6, 12, 'text'), width - statusX - 14 - PAD)
			card.cells[index] = { value = value, dot = dot, status = status }
		end
		function card:Set(readings)
			for index, cell in ipairs(self.cells) do
				local reading = readings[index] or {}
				cell.value:SetText(reading.value or '')
				cell.status:SetText(reading.status or '')
				window:Paint(cell.dot, reading.healthy == false and 'danger' or 'accent')
			end
		end
		if not cards.Drive(card, spec, function(readings) card:Set(readings) end) then card:Set(spec.readings or {}) end
		return card
	end

	function cards.Share(parent, x, y, width, spec)
		local height = 176
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		cards.Description(card, spec.description or '', PAD, 38, width - PAD * 2)
		local boxWidth = width - PAD * 2 - ACTION_ROOM
		local export = cards.Field(card, PAD, 70, boxWidth)
		export:SetScript('OnTextChanged', function(self, userInput)
			if userInput then
				self:SetText(spec.value())
				self:HighlightText()
			end
		end)
		export:SetText(spec.value())
		local select = kit.Button(card, 'Select', 'secondary', function()
			export:SetFocus()
			export:HighlightText()
		end)
		select:SetPoint('LEFT', export, 'RIGHT', 10, 0)
		local import = cards.Field(card, PAD, 110, boxWidth)
		cards.Placeholder(import, spec.placeholder or 'Paste here')
		card.status = Capped(cards.Label(card, spec.hint or '', PAD, 150, 11, 'muted'), width - PAD * 2)
		local load = kit.Button(card, spec.action or 'Load', 'primary', function()
			local ok, message = spec.onLoad(import:GetText())
			card.status:SetText(message or '')
			if ok then import:SetText('') end
		end)
		load:SetPoint('LEFT', import, 'RIGHT', 10, 0)
		function card:Refresh()
			if not export:HasFocus() then export:SetText(spec.value()) end
		end
		return card
	end

	function cards.Editor(parent, x, y, width, spec)
		local height = 190
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.count = kit.Text(card, '', 11, 'muted')
		card.count:SetPoint('TOPRIGHT', -PAD, -20)
		local limit = spec.limit or 200
		local note = cards.Field(card, PAD, 46, width - PAD * 2, height - 46 - PAD - 18)
		note:SetScript('OnEditFocusGained', nil)
		note:SetMultiLine(true)
		note:SetMaxLetters(limit)
		note:SetTextInsets(10, 10, 8, 8)
		note:SetText(spec.text or '')
		local hint = kit.Text(note, spec.placeholder or 'Write something', 12, 'faint')
		hint:SetPoint('TOPLEFT', 10, -9)
		card.saved = Capped(cards.Label(card, '', PAD, height - PAD - 10, 11, 'muted'), width - PAD * 2)
		local function Update()
			local text = note:GetText()
			hint:SetShown(text == '')
			card.count:SetText(#text .. ' / ' .. limit)
		end
		note:HookScript('OnTextChanged', function(self, userInput)
			Update()
			if userInput and spec.onChange then card.saved:SetText(spec.onChange(self:GetText()) or '') end
		end)
		Update()
		card.edit = note
		return card
	end

	function cards.Filter(parent, x, y, width, spec)
		local height = spec.height or 118
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.selected = spec.selected or 1
		local chips = {}
		local chipX = PAD
		for index, label in ipairs(spec.chips) do
			local chip = CreateFrame('Button', nil, card)
			chip:SetHeight(CHIP_HEIGHT)
			chip.fill, chip.edge = Widget.DrawCardShape(chip, 8, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
			chip.label = kit.Text(chip, label, 11, 'muted', nil, 'control')
			chip.label:SetPoint('CENTER')
			chip:SetWidth(Widget.EvenSize(chip.label:GetStringWidth() + 22))
			chip:SetPoint('TOPLEFT', chipX, -46)
			chipX = chipX + chip:GetWidth() + CHIP_GAP
			chip:SetScript('OnClick', function() card:Select(index) end)
			chips[index] = chip
		end
		local function Refresh()
			for index, chip in ipairs(chips) do
				local active = index == card.selected
				window:Paint(chip.fill, active and 'accent' or 'control')
				window:Paint(chip.edge, active and 'accent' or 'rule')
				window:Paint(chip.label, active and 'onAccent' or 'muted')
			end
		end
		function card:Select(index)
			self.selected = index
			Refresh()
			if spec.onSelect then spec.onSelect(index) end
		end
		card.note = cards.Description(card, spec.note or '', PAD, 84, width - PAD * 2)
		Refresh()
		return card
	end

	function cards.Palette(parent, x, y, width, spec)
		local height = spec.height or 118
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.note = kit.Text(card, '', 11, 'muted')
		card.note:SetPoint('TOPRIGHT', -PAD, -20)
		local perRow = math.max(1, math.floor((width - PAD * 2 + SWATCH_GAP) / (SWATCH + SWATCH_GAP)))
		local swatches = {}
		for index, color in ipairs(spec.colors) do
			local swatch = CreateFrame('Button', nil, card)
			swatch:SetSize(SWATCH, SWATCH)
			local column, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
			swatch:SetPoint('TOPLEFT', PAD + column * (SWATCH + SWATCH_GAP), -(46 + row * (SWATCH + SWATCH_GAP)))
			local ring = kit.Fill(swatch, 'text', 'BACKGROUND')
			ring:SetAllPoints()
			local fill = swatch:CreateTexture(nil, 'ARTWORK')
			fill:SetTexture(Widget.WHITE)
			fill:SetPoint('TOPLEFT', 2, -2)
			fill:SetPoint('BOTTOMRIGHT', -2, 2)
			fill:SetVertexColor(color[1], color[2], color[3], 1)
			swatch.ring = ring
			swatch:SetScript('OnClick', function()
				if spec.onPick then spec.onPick(index, color) end
				card:Refresh()
			end)
			swatches[index] = swatch
		end
		function card:Refresh()
			local picked = spec.selected and spec.selected() or nil
			for index, swatch in ipairs(swatches) do swatch.ring:SetShown(index == picked) end
			self.note:SetText(picked and spec.colors[picked].name or '')
		end
		card:Refresh()
		return card
	end
end
