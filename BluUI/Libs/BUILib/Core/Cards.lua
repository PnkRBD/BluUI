local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget

local PAD = 20
local RADIUS = 10
local GAP = 16
local ROW_GAP = 24
local CAPTION = 22
local BADGE_GLYPH = 0.42
local BAR = 4
local CHIP_HEIGHT = 24
local CHIP_GAP = 8
local KEYCAP_HEIGHT = 22
local KEY_CAPS = 3
local KEY_ROOM = 110
local PROGRESS_ROW = 48
local ROSTER_ROW = 44
local LIST_ROW = 44
local KEY_ROW = 30
local SWITCH_ROW = 58
local CELL_INSET = 16
local TITLE_ROOM = 100
local BAR_ROW = 44
local STEP_ROW = 44
local STEP_DISC = 22
local TICKS = 40
local TICK_HEIGHT = 10
local MARK_HEIGHT = 18
local MARK_LABEL = 14
local CHART_LINES = 3
local SERIES = {
	{ 0.55, 0.85, 0.35, 1 },
	{ 0.95, 0.7, 0.2, 1 },
	{ 0.6, 0.45, 0.95, 1 },
	{ 0.3, 0.62, 0.95, 1 },
	{ 0.92, 0.4, 0.5, 1 },
	{ 0.35, 0.8, 0.8, 1 },
}

local function Clamp(fraction)
	return math.max(0, math.min(1, fraction or 0))
end

local function NiceCeiling(value)
	if value <= 0 then return 10 end
	local magnitude = 10 ^ math.floor(math.log10(value))
	local unit = magnitude / 2
	return math.ceil(value / unit) * unit
end

Layout.CardKitExtensions = {}

function Layout.CardKit(window)
	local kit = Layout.TableKit(window)
	local cards = { PAD = PAD, RADIUS = RADIUS, GAP = GAP }

	local function Painted(parent, size, tier, paint)
		local label = parent:CreateFontString(nil, 'OVERLAY')
		label:SetFont(window:FontPath(tier), size, '')
		label:SetJustifyH('LEFT')
		window:Bind(label, function(region)
			region:SetFont(window:FontPath(tier), size, '')
			paint(region)
		end)
		return label
	end

	function cards.SeriesColor(index)
		if index == 1 then return 'accent' end
		return SERIES[(index - 2) % #SERIES + 1]
	end

	function cards.PaintSeries(texture, index)
		if index == 1 then
			window:Paint(texture, 'accent')
		else
			local color = SERIES[(index - 2) % #SERIES + 1]
			texture:SetVertexColor(color[1], color[2], color[3], color[4])
		end
	end
	cards.Painted = Painted

	function cards.Fill(parent, index, layer, subLayer)
		local texture = parent:CreateTexture(nil, layer or 'ARTWORK', nil, subLayer or 0)
		texture:SetTexture(Widget.WHITE)
		cards.PaintSeries(texture, index)
		return texture
	end

	function cards.Dot(parent, size, index, layer, subLayer)
		local dot = parent:CreateTexture(nil, layer or 'ARTWORK', nil, subLayer or 0)
		dot:SetTexture(BUILib.GetLibMedia('smoothdisc'))
		dot:SetSize(size, size)
		cards.PaintSeries(dot, index)
		return dot
	end

	function cards.Drive(card, spec, apply)
		if not spec.read then return false end
		local function Update() apply(spec.read()) end
		if spec.events then cards.Listen(card, spec.events, Update) else cards.Every(card, spec.every or 1, Update) end
		return true
	end

	function cards.Card(parent, x, y, width, height, opts)
		opts = opts or {}
		local card = CreateFrame(opts.onClick and 'Button' or 'Frame', nil, parent)
		card:SetPoint('TOPLEFT', x, -y)
		card:SetSize(width, height)
		card.fill, card.edge = Widget.DrawCardShape(card, RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
		window:Paint(card.fill, 'card')
		local edge = opts.edge or 'cardEdge'
		window:Paint(card.edge, edge)
		if opts.onClick then
			card:SetScript('OnEnter', function() window:Paint(card.edge, 'faint') end)
			card:SetScript('OnLeave', function() window:Paint(card.edge, edge) end)
			card:SetScript('OnClick', function() opts.onClick(card) end)
		end
		card.height = height
		return card
	end

	function cards.Label(parent, text, x, y, size, role)
		local label = kit.Text(parent, text, size, role)
		label:SetPoint('TOPLEFT', x, -y)
		return label
	end

	function cards.Title(card, text, y)
		return cards.Label(card, text, PAD, y or 18, 13, 'text')
	end

	local function TitledRow(card, text, width)
		local title = cards.Title(card, text)
		title:SetWidth(width - PAD * 2 - TITLE_ROOM)
		title:SetWordWrap(false)
		return title
	end

	function cards.Caption(parent, text, x, y)
		return cards.Label(parent, text:upper(), x, y, 9, 'faint')
	end

	function cards.Description(parent, text, x, y, width, role)
		local label = kit.Text(parent, text, 11, role or 'muted', width)
		label:SetPoint('TOPLEFT', x, -y)
		label:SetSpacing(2)
		return label
	end

	function cards.Readout(parent, x, y, size, width)
		local label = kit.Text(parent, '', size, 'accent', nil, 'title')
		label:SetPoint('TOPLEFT', x, -y)
		if width then
			label:SetWidth(width)
			label:SetWordWrap(false)
		end
		return label
	end

	function cards.Badge(parent, icon, size, x, y, tinted)
		local disc = kit.Disc(parent, size, tinted and 'accent' or 'secondary')
		disc:SetPoint('TOPLEFT', x, -y)
		if tinted then disc:SetAlpha(0.18) end
		local glyph = kit.Glyph(parent, icon, math.floor(size * BADGE_GLYPH), tinted and 'accent' or 'secondaryText', 'OVERLAY')
		glyph:SetPoint('CENTER', disc)
		return disc
	end

	function cards.Chevron(parent, size, role)
		local chevron = kit.Glyph(parent, 'dropdown', size, role)
		chevron:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
		return chevron
	end

	function cards.Rule(card, x, y, width)
		local rule = kit.DottedRule(card)
		rule:SetPoint('TOPLEFT', x, -y)
		rule:SetWidth(width)
		return rule
	end

	function cards.Bar(card, x, y, width, height, index)
		local track = kit.Fill(card, 'control', 'ARTWORK')
		track:SetPoint('TOPLEFT', x, -y)
		track:SetSize(width, height)
		local fill = cards.Fill(card, index or 1, 'ARTWORK', 1)
		fill:SetPoint('TOPLEFT', track)
		fill:SetHeight(height)
		fill.track = track
		function fill:SetFraction(fraction) self:SetWidth(math.max(1, width * Clamp(fraction))) end
		fill:SetFraction(0)
		return fill
	end

	function cards.Chip(parent, text, color)
		local chip = CreateFrame('Frame', nil, parent)
		chip:SetHeight(CHIP_HEIGHT)
		local fill, edge = Widget.DrawCardShape(chip, 8, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
		local function Tint(label, red, green, blue)
			fill:SetVertexColor(red, green, blue, 0.14)
			edge:SetVertexColor(red, green, blue, 0.5)
			label:SetTextColor(red, green, blue, 1)
		end
		chip.label = Painted(chip, 11, 'body', function(region)
			if type(color) == 'string' then Tint(region, window:Color(color)) else Tint(region, color[1], color[2], color[3]) end
		end)
		chip.label:SetPoint('CENTER')
		function chip:SetText(newText)
			self.label:SetText(newText)
			self:SetWidth(Widget.EvenSize(self.label:GetStringWidth() + 20))
		end
		chip:SetText(text)
		return chip
	end

	function cards.Keycap(parent, text)
		local cap = CreateFrame('Frame', nil, parent)
		cap:SetHeight(KEYCAP_HEIGHT)
		local fill, edge = Widget.DrawCardShape(cap, 5, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
		window:Paint(fill, 'secondary')
		window:Paint(edge, 'rule')
		cap.label = kit.Text(cap, text, 11, 'text')
		cap.label:SetPoint('CENTER', 0, 1)
		function cap:SetText(newText)
			self.label:SetText(newText)
			self:SetWidth(Widget.EvenSize(math.max(22, self.label:GetStringWidth() + 14)))
		end
		cap:SetText(text)
		return cap
	end

	function cards.Every(frame, seconds, update)
		local ticker
		local function Start()
			update()
			if not ticker then ticker = C_Timer.NewTicker(seconds, update) end
		end
		local function Stop()
			if ticker then ticker:Cancel() end
			ticker = nil
		end
		frame:HookScript('OnShow', Start)
		frame:HookScript('OnHide', Stop)
		if frame:IsVisible() then Start() else update() end
	end

	function cards.Listen(frame, events, update)
		local listener = CreateFrame('Frame', nil, frame)
		listener:SetScript('OnEvent', function() update() end)
		local function Start()
			for _, event in ipairs(events) do listener:RegisterEvent(event) end
			update()
		end
		frame:HookScript('OnShow', Start)
		frame:HookScript('OnHide', function() listener:UnregisterAllEvents() end)
		if frame:IsVisible() then Start() else update() end
	end

	function cards.Grid(parent, width, rows)
		local third = math.floor((width - GAP * 2) / 3)
		local widths = { third = third, twoThirds = width - third - GAP, half = math.floor((width - GAP) / 2), full = width }
		local y = 0
		for _, row in ipairs(rows) do
			local x, tallest, placed = 0, 0, {}
			for _, entry in ipairs(row) do
				local span = widths[entry.span or 'full']
				local top = y
				if entry.caption then
					cards.Caption(parent, entry.caption, x, y)
					top = y + CAPTION
				end
				local built = entry.build(parent, x, top, span)
				local height = type(built) == 'number' and built or built.height
				if type(built) ~= 'number' then placed[#placed + 1] = { frame = built, offset = top - y } end
				tallest = math.max(tallest, top - y + height)
				x = x + span + GAP
			end
			for _, item in ipairs(placed) do
				item.frame:SetHeight(tallest - item.offset)
				item.frame.height = tallest - item.offset
			end
			y = y + tallest + ROW_GAP
		end
		return y - ROW_GAP
	end

	function cards.Stat(parent, x, y, width, spec)
		local height = 128
		local card = cards.Card(parent, x, y, width, height)
		cards.Label(card, spec.caption, PAD, PAD, 12, 'muted')
		if spec.icon then cards.Badge(card, spec.icon, 30, width - PAD - 30, 14) end
		card.value = cards.Readout(card, PAD, 40, 34, width - PAD * 2)
		card.note = cards.Label(card, '', PAD, 82, 11, 'muted')
		card.note:SetWidth(width - PAD * 2)
		card.note:SetWordWrap(false)
		card.line = cards.Label(card, '', PAD, 100, 11, 'text')
		card.line:SetWidth(width - PAD * 2)
		card.line:SetWordWrap(false)
		card.bar = cards.Bar(card, PAD, height - PAD - 6, width - PAD * 2, 6)
		function card:Set(value, note, fraction, line)
			self.value:SetText(value)
			self.note:SetText(note or '')
			self.line:SetText(line or '')
			self.bar:SetShown(fraction ~= nil)
			self.bar.track:SetShown(fraction ~= nil)
			self.bar:SetFraction(fraction)
		end
		if not cards.Drive(card, spec, function(value, note, fraction, line) card:Set(value, note, fraction, line) end) then
			card:Set(spec.value or '', spec.note, spec.fraction, spec.line)
		end
		return card
	end

	function cards.Strip(parent, x, y, width, spec)
		local height = spec.height or 128
		local card = cards.Card(parent, x, y, width, height)
		local cellWidth = math.floor((width - 2) / #spec.cells)
		local inner = cellWidth - CELL_INSET * 2
		card.values = {}
		for index, cell in ipairs(spec.cells) do
			local cellX = 1 + (index - 1) * cellWidth
			if index > 1 then
				local divider = kit.Fill(card, 'rule', 'ARTWORK')
				divider:SetPoint('TOPLEFT', cellX, -1)
				divider:SetPoint('BOTTOMLEFT', cellX, 1)
				divider:SetWidth(1)
			end
			local value = kit.Text(card, '', 20, cell.accent and 'accent' or 'text', nil, 'title')
			value:SetPoint('LEFT', card, 'LEFT', cellX + CELL_INSET, 10)
			value:SetWidth(inner)
			value:SetWordWrap(false)
			local sub = kit.Text(card, cell.sub, 11, 'muted')
			sub:SetPoint('LEFT', card, 'LEFT', cellX + CELL_INSET, -12)
			sub:SetWidth(inner)
			sub:SetWordWrap(false)
			card.values[index] = value
		end
		function card:Set(values)
			for index, value in ipairs(values) do self.values[index]:SetText(value) end
		end
		card:Set(spec.values or {})
		return card
	end

	function cards.Progress(parent, x, y, width, spec)
		local count = spec.rows or 4
		local textX = spec.icons and PAD + 36 or PAD
		local height = 46 + count * PROGRESS_ROW + PAD - 6
		local card = cards.Card(parent, x, y, width, height)
		TitledRow(card, spec.title, width)
		card.summary = kit.Text(card, '', 11, 'muted')
		card.summary:SetPoint('TOPRIGHT', -PAD, -20)
		card.empty = cards.Description(card, spec.empty or 'Nothing to show yet.', PAD, 52, width - PAD * 2)
		card.rows = {}
		for index = 1, count do
			local rowY = 46 + (index - 1) * PROGRESS_ROW
			local row = {}
			if spec.icons then
				row.icon = card:CreateTexture(nil, 'ARTWORK')
				row.icon:SetSize(26, 26)
				row.icon:SetPoint('TOPLEFT', PAD, -(rowY + 2))
				row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			row.name = cards.Label(card, '', textX, rowY, 12, 'text')
			row.name:SetWidth(width - PAD - textX - 60)
			row.name:SetWordWrap(false)
			row.detail = cards.Label(card, '', textX, rowY + 16, 10, 'muted')
			row.value = kit.Text(card, '', 11, 'text')
			row.value:SetPoint('TOPRIGHT', -PAD, -rowY)
			row.fill = cards.Bar(card, textX, rowY + 32, width - PAD - textX, BAR)
			card.rows[index] = row
		end
		function card:Set(list, summary)
			for index, row in ipairs(self.rows) do
				local entry = list[index]
				local shown = entry ~= nil
				if row.icon then row.icon:SetShown(shown) end
				row.name:SetShown(shown)
				row.detail:SetShown(shown)
				row.value:SetShown(shown)
				row.fill:SetShown(shown)
				row.fill.track:SetShown(shown)
				if entry then
					if row.icon then row.icon:SetTexture(entry.icon) end
					row.name:SetText(entry.name)
					row.detail:SetText(entry.detail or '')
					row.value:SetText(entry.value or '')
					row.fill:SetFraction(entry.fraction)
				end
			end
			self.empty:SetShown(#list == 0)
			self.summary:SetText(summary or '')
		end
		card:Set(spec.list or {}, spec.summary)
		return card
	end

	function cards.Breakdown(parent, x, y, width, spec)
		local count = spec.rows or 4
		local height = 46 + count * BAR_ROW + PAD - 10
		local card = cards.Card(parent, x, y, width, height)
		TitledRow(card, spec.title, width)
		card.total = kit.Text(card, '', 11, 'muted')
		card.total:SetPoint('TOPRIGHT', -PAD, -20)
		card.rows = {}
		local inner = width - PAD * 2
		for index = 1, count do
			local rowY = 46 + (index - 1) * BAR_ROW
			local name = cards.Label(card, '', PAD, rowY, 12, 'text')
			name:SetWidth(inner - 90)
			name:SetWordWrap(false)
			local value = kit.Text(card, '', 11, 'muted')
			value:SetPoint('TOPRIGHT', -PAD, -rowY)
			local fill = cards.Bar(card, PAD, rowY + 22, inner, BAR, index)
			card.rows[index] = { name = name, value = value, fill = fill }
		end
		function card:Set(list, total)
			for index, row in ipairs(self.rows) do
				local entry = list[index]
				local shown = entry ~= nil
				row.name:SetShown(shown)
				row.value:SetShown(shown)
				row.fill:SetShown(shown)
				row.fill.track:SetShown(shown)
				if entry then
					row.name:SetText(entry.name)
					row.value:SetText(entry.value or '')
					row.fill:SetFraction(entry.fraction)
				end
			end
			self.total:SetText(total or '')
		end
		card:Set(spec.list or {}, spec.total)
		return card
	end

	function cards.Toggle(parent, x, y, width, spec)
		local height = 128
		local card = cards.Card(parent, x, y, width, height)
		cards.Badge(card, spec.icon, 32, PAD, PAD, true)
		card.switch = kit.Switch(card, spec.get, spec.set)
		card.switch:SetPoint('TOPRIGHT', -PAD, -(PAD + 5))
		cards.Label(card, spec.title, PAD, 66, 13, 'text')
		cards.Description(card, spec.description, PAD, 86, width - PAD * 2)
		return card
	end

	function cards.Switches(parent, x, y, width, spec)
		local height = 46 + #spec.rows * SWITCH_ROW + PAD - 16
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.switches = {}
		for index, row in ipairs(spec.rows) do
			local rowY = 46 + (index - 1) * SWITCH_ROW
			if index > 1 then cards.Rule(card, PAD, rowY - 8, width - PAD * 2) end
			cards.Label(card, row.title, PAD, rowY, 12, 'text')
			cards.Label(card, row.sub, PAD, rowY + 18, 11, 'muted')
			local switch = kit.Switch(card, row.get, row.set)
			switch:SetPoint('TOPRIGHT', -PAD, -(rowY + 5))
			card.switches[index] = switch
		end
		return card
	end

	function cards.Option(parent, x, y, width, spec)
		local height = 92
		local card = cards.Card(parent, x, y, width, height, { onClick = function() spec.select() end })
		local tint = Widget.DrawCardShape(card, RADIUS, { 1, 1, 1, 1 }, { 0, 0, 0, 0 }, 'BACKGROUND', 2, 0)
		window:Paint(tint, 'accent')
		tint:SetAlpha(0.08)
		cards.Badge(card, spec.icon, 36, PAD, PAD, true)
		cards.Label(card, spec.title, PAD + 50, PAD + 1, 13, 'text')
		cards.Description(card, spec.description, PAD + 50, PAD + 21, width - PAD * 2 - 50 - 30)
		local ring = kit.Disc(card, 18, nil)
		ring:SetPoint('TOPRIGHT', -PAD, -PAD)
		kit.Disc(card, 14, 'card', 'ARTWORK', 1):SetPoint('CENTER', ring)
		local dot = kit.Disc(card, 8, 'accent', 'ARTWORK', 2)
		dot:SetPoint('CENTER', ring)
		card:SetScript('OnEnter', nil)
		card:SetScript('OnLeave', nil)
		window:Bind(card, function()
			local selected = spec.selected()
			tint:SetShown(selected)
			dot:SetShown(selected)
			window:Paint(card.edge, selected and 'accent' or 'rule')
			window:Paint(ring, selected and 'accent' or 'rule')
		end)
		return card
	end

	function cards.Action(parent, x, y, width, spec)
		local height = 128
		local card = cards.Card(parent, x, y, width, height, { onClick = spec.onClick })
		cards.Badge(card, spec.icon, 36, PAD, PAD, true)
		cards.Chevron(card, 10, 'muted'):SetPoint('TOPRIGHT', -PAD, -(PAD + 13))
		cards.Label(card, spec.title, PAD, 70, 13, 'text')
		cards.Description(card, spec.description, PAD, 90, width - PAD * 2)
		return card
	end

	function cards.Launch(parent, x, y, width, spec)
		local height = spec.icon and 220 or 150
		local card = cards.Card(parent, x, y, width, height)
		local textY = PAD
		if spec.icon then
			local stage = CreateFrame('Frame', nil, card)
			stage:SetPoint('TOPLEFT', PAD, -PAD)
			stage:SetSize(width - PAD * 2, 84)
			for line = 0, 2 do cards.Rule(stage, 0, line * 41, width - PAD * 2) end
			local icon = stage:CreateTexture(nil, 'ARTWORK', nil, 1)
			icon:SetSize(64, 64)
			icon:SetPoint('LEFT', 8, 0)
			icon:SetMask(BUILib.GetLibMedia('circle_mask'))
			icon:SetTexture(spec.icon)
			textY = 122
		end
		cards.Label(card, spec.title, PAD, textY, 14, 'text')
		cards.Description(card, spec.description, PAD, textY + 22, width - PAD * 2)
		local start = kit.Button(card, spec.action or 'Start', 'primary', spec.onClick)
		start:SetPoint('BOTTOMLEFT', PAD, PAD - 4)
		return card
	end

	function cards.Roster(parent, x, y, width, spec)
		local count = spec.rows or 4
		local height = 46 + count * ROSTER_ROW + PAD - 4
		local card = cards.Card(parent, x, y, width, height)
		TitledRow(card, spec.title, width)
		card.count = kit.Text(card, '', 11, 'muted')
		card.count:SetPoint('TOPRIGHT', -PAD, -20)
		card.empty = cards.Description(card, spec.empty or 'No one here yet.', PAD, 52, width - PAD * 2)
		card.rows = {}
		for index = 1, count do
			local rowY = 46 + (index - 1) * ROSTER_ROW
			local row = CreateFrame('Frame', nil, card)
			row:SetPoint('TOPLEFT', 1, -rowY)
			row:SetSize(width - 2, ROSTER_ROW)
			if index > 1 then cards.Rule(row, PAD, 0, width - 2 - PAD * 2) end
			row.avatar = kit.Initials(row, 30, '', 'title')
			row.avatar:SetPoint('LEFT', PAD - 1, 0)
			row.name = kit.Text(row, '', 12, 'text')
			row.name:SetPoint('TOPLEFT', PAD + 38, -8)
			row.note = kit.Text(row, '', 11, 'muted')
			row.note:SetPoint('TOPLEFT', PAD + 38, -24)
			row.note:SetWidth(width - PAD * 2 - 38 - 90)
			row.note:SetWordWrap(false)
			row.chip = cards.Chip(row, '', cards.SeriesColor(4))
			row.chip:SetPoint('RIGHT', -PAD, 0)
			card.rows[index] = row
		end
		function card:Set(list, count)
			for index, row in ipairs(self.rows) do
				local entry = list[index]
				row:SetShown(entry ~= nil)
				if entry then
					local first, second = entry.name:match('^(%a)%a*%s+(%a)')
					row.avatar.label:SetText(first and (first .. second):upper() or entry.name:sub(1, 2):upper())
					row.name:SetText(entry.name)
					row.note:SetText(entry.note or '')
					row.chip:SetShown(entry.tag ~= nil)
					if entry.tag then row.chip:SetText(entry.tag) end
				end
			end
			self.empty:SetShown(#list == 0)
			self.count:SetText(count or '')
		end
		card:Set(spec.list or {}, spec.count)
		return card
	end

	function cards.List(parent, x, y, width, spec)
		local height = 52 + #spec.rows * LIST_ROW + 6
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		if spec.note then
			local note = kit.Text(card, spec.note, 11, 'muted')
			note:SetPoint('TOPRIGHT', -PAD, -20)
		end
		local rule = kit.Fill(card, 'rule', 'ARTWORK')
		rule:SetPoint('TOPLEFT', 1, -50)
		rule:SetPoint('TOPRIGHT', -1, -50)
		rule:SetHeight(1)
		card.rows = {}
		for index, entry in ipairs(spec.rows) do
			local row = CreateFrame('Button', nil, card)
			row:SetPoint('TOPLEFT', 1, -(51 + (index - 1) * LIST_ROW))
			row:SetSize(width - 2, LIST_ROW)
			kit.Hover(row)
			if index > 1 then cards.Rule(row, PAD, 0, width - 2 - PAD * 2) end
			if entry.icon then
				kit.Glyph(row, entry.icon, 12, 'muted'):SetPoint('LEFT', PAD, 0)
			else
				local ring = kit.Disc(row, 18, 'rule')
				ring:SetPoint('LEFT', PAD - 1, 0)
				row.swatch = kit.Disc(row, 14, nil, 'ARTWORK', 1)
				row.swatch:SetPoint('CENTER', ring)
			end
			local label = kit.Text(row, entry.label, 12, 'text')
			label:SetPoint('LEFT', PAD + 28, 0)
			label:SetWidth(width - PAD * 2 - 28 - 130)
			label:SetWordWrap(false)
			local chevron = cards.Chevron(row, 9, 'muted')
			chevron:SetPoint('RIGHT', -PAD, 0)
			row.value = kit.Text(row, entry.value or '', 12, 'muted')
			row.value:SetPoint('RIGHT', chevron, 'LEFT', -12, 0)
			row:SetScript('OnClick', function(self) if entry.onClick then entry.onClick(self) end end)
			card.rows[index] = row
		end
		return card
	end

	function cards.Chart(parent, x, y, width, spec)
		local height = spec.height or 250
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		local series = #spec.series
		local groups = spec.groups or 12
		local chartX, chartY = PAD + 36, 56
		local chartHeight = height - chartY - PAD - 40
		local chartWidth = width - PAD * 2 - 36
		local axis = {}
		for line = 0, CHART_LINES do
			local rule = cards.Rule(card, chartX, chartY + chartHeight - math.floor(chartHeight * line / CHART_LINES), chartWidth)
			local label = kit.Text(card, '', 10, 'muted')
			label:SetPoint('RIGHT', rule, 'LEFT', -6, 0)
			axis[line + 1] = label
		end
		local bars, labels = {}, {}
		for group = 1, groups do
			bars[group] = {}
			for slot = 1, series do
				local bar = cards.Fill(card, slot, 'ARTWORK', 1)
				bar:SetHeight(1)
				bar:Hide()
				bars[group][slot] = bar
			end
			labels[group] = kit.Text(card, '', 9, 'muted')
		end
		local legendX = PAD
		for slot = 1, series do
			local dot = cards.Dot(card, 7, slot)
			dot:SetPoint('TOPLEFT', legendX, -(height - PAD - 12))
			local text = kit.Text(card, spec.series[slot], 11, 'muted')
			text:SetPoint('LEFT', dot, 'RIGHT', 6, 0)
			legendX = legendX + 13 + math.ceil(text:GetStringWidth()) + 18
		end
		function card:Set(samples)
			local count = math.min(groups, #samples)
			local peak = 1
			for index = 1, count do
				for slot = 1, series do peak = math.max(peak, samples[index][slot] or 0) end
			end
			local top = spec.top or NiceCeiling(peak)
			for line = 0, CHART_LINES do axis[line + 1]:SetText(tostring(math.floor(top * line / CHART_LINES + 0.5))) end
			local groupWidth = chartWidth / math.max(1, count)
			local barWidth = math.max(2, math.floor((groupWidth - 8) / series))
			for group = 1, groups do
				local sample = group <= count and samples[group] or nil
				local left = chartX + math.floor((group - 1) * groupWidth + 4)
				for slot = 1, series do
					local bar = bars[group][slot]
					bar:SetShown(sample ~= nil)
					if sample then
						bar:ClearAllPoints()
						bar:SetPoint('BOTTOMLEFT', card, 'TOPLEFT', left + (slot - 1) * barWidth, -(chartY + chartHeight))
						bar:SetSize(barWidth - 1, math.max(1, chartHeight * Clamp((sample[slot] or 0) / top)))
					end
				end
				local label = labels[group]
				label:SetShown(sample ~= nil)
				label:ClearAllPoints()
				label:SetPoint('TOP', card, 'TOPLEFT', left + math.floor(barWidth * series / 2), -(chartY + chartHeight + 4))
				label:SetText(sample and sample.label or '')
			end
		end
		card:Set(spec.samples or {})
		return card
	end

	function cards.Keycaps(parent, x, y, width, spec)
		local count = #spec.rows
		local height = 46 + count * KEY_ROW + PAD - 8
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.rows = {}
		for index, row in ipairs(spec.rows) do
			local rowY = 46 + (index - 1) * KEY_ROW
			local label = cards.Label(card, row.label, PAD, rowY + 4, 12, 'text')
			label:SetWidth(width - PAD * 2 - KEY_ROOM)
			label:SetWordWrap(false)
			local caps = {}
			for slot = 1, KEY_CAPS do
				local cap = cards.Keycap(card, '')
				if slot == 1 then
					cap:SetPoint('TOPRIGHT', -PAD, -rowY)
				else
					cap:SetPoint('RIGHT', caps[slot - 1], 'LEFT', -4, 0)
				end
				caps[slot] = cap
			end
			card.rows[index] = caps
		end
		function card:Set(rows)
			for index, caps in ipairs(self.rows) do
				local keys = rows[index] and rows[index].keys or {}
				for slot, cap in ipairs(caps) do
					local key = keys[#keys - slot + 1]
					cap:SetShown(key ~= nil)
					if key then cap:SetText(key) end
				end
			end
		end
		card:Set(spec.rows)
		return card
	end

	function cards.Segmented(parent, x, y, width, spec)
		local hasSub = false
		for _, tab in ipairs(spec.tabs) do
			if tab.sub then hasSub = true end
		end
		local groupHeight = hasSub and 52 or 32
		local height = 46 + (spec.caption and 18 or 0) + groupHeight + PAD
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		local groupY = 46
		if spec.caption then
			cards.Caption(card, spec.caption, PAD, groupY)
			groupY = groupY + 18
		end
		local group = CreateFrame('Frame', nil, card)
		group:SetPoint('TOPLEFT', PAD, -groupY)
		group:SetSize(width - PAD * 2, groupHeight)
		for _, piece in ipairs(Widget.DrawRoundedRect(group, 8, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)) do window:Paint(piece, 'input') end
		local tabWidth = math.floor((width - PAD * 2 - 8 - 4 * (#spec.tabs - 1)) / #spec.tabs)
		local buttons = {}
		card.selected = spec.selected or 1
		local function Refresh()
			for index, button in ipairs(buttons) do
				local active = index == card.selected
				button.fill:SetShown(active)
				window:Paint(button.label, active and 'text' or 'muted')
				if button.sub then window:Paint(button.sub, active and 'muted' or 'faint') end
			end
		end
		for index, tab in ipairs(spec.tabs) do
			local button = CreateFrame('Button', nil, group)
			button:SetSize(tabWidth, groupHeight - 8)
			button:SetPoint('TOPLEFT', 4 + (index - 1) * (tabWidth + 4), -4)
			button.fill = Widget.DrawCardShape(button, 6, { 1, 1, 1, 1 }, { 0, 0, 0, 0 }, 'BACKGROUND', 1, 0)
			window:Paint(button.fill, 'control')
			button.label = kit.Text(button, tab.label, 12, 'muted', nil, 'title')
			if tab.sub then
				button.label:SetPoint('TOP', 0, -8)
				button.sub = kit.Text(button, tab.sub, 10, 'faint')
				button.sub:SetPoint('TOP', 0, -25)
			else
				button.label:SetPoint('CENTER')
			end
			button:SetScript('OnClick', function() card:Select(index) end)
			buttons[index] = button
		end
		function card:SetSelected(index)
			self.selected = index
			Refresh()
		end
		function card:Select(index)
			self:SetSelected(index)
			if spec.onSelect then spec.onSelect(index) end
		end
		Refresh()
		return card
	end

	function cards.Callout(parent, x, y, width, spec)
		local height = spec.height or 128
		local card = cards.Card(parent, x, y, width, height, { edge = 'accent' })
		card.edge:SetAlpha(0.45)
		local tint = Widget.DrawCardShape(card, RADIUS, { 1, 1, 1, 1 }, { 0, 0, 0, 0 }, 'BACKGROUND', 2, 0)
		window:Paint(tint, 'accent')
		tint:SetAlpha(0.08)
		kit.Glyph(card, spec.icon or 'question', 14, 'accent'):SetPoint('TOPLEFT', PAD, -(PAD + 1))
		cards.Label(card, spec.title, PAD + 22, PAD, 13, 'text')
		cards.Description(card, spec.body, PAD, PAD + 28, width - PAD * 2, 'text')
		return card
	end

	function cards.Empty(parent, x, y, width, spec)
		local height = 128
		local card = CreateFrame('Frame', nil, parent)
		card:SetPoint('TOPLEFT', x, -y)
		card:SetSize(width, height)
		card.height = height
		local top = cards.Rule(card, 0, 0, width)
		local bottom = cards.Rule(card, 0, height - 1, width)
		for _, side in ipairs({ 'TOPLEFT', 'TOPRIGHT' }) do
			local edge = kit.DottedRule(card)
			edge:SetPoint(side, card, side, side == 'TOPRIGHT' and -1 or 0, 0)
			edge:SetPoint(side == 'TOPLEFT' and 'BOTTOMLEFT' or 'BOTTOMRIGHT', card, side == 'TOPLEFT' and 'BOTTOMLEFT' or 'BOTTOMRIGHT', side == 'TOPRIGHT' and -1 or 0, 0)
			edge:SetWidth(1)
			edge:SetHorizTile(false)
			edge:SetVertTile(true)
		end
		top:SetShown(true)
		bottom:SetShown(true)
		cards.Badge(card, spec.icon or 'plus', 30, math.floor((width - 30) / 2), 16)
		local title = kit.Text(card, spec.title, 13, 'text')
		title:SetPoint('TOP', 0, -54)
		local sub = kit.Text(card, spec.sub or '', 11, 'muted')
		sub:SetPoint('TOP', 0, -73)
		if spec.action then
			local button = kit.Button(card, spec.action, 'primary', spec.onClick)
			button:SetPoint('TOP', 0, -92)
		end
		return card
	end

	function cards.Danger(parent, x, y, width, spec)
		local height = 84
		local card = cards.Card(parent, x, y, width, height, { edge = 'danger' })
		card.edge:SetAlpha(0.5)
		cards.Title(card, spec.title, 22)
		cards.Description(card, spec.description, PAD, 44, width - PAD * 2 - 180)
		local button = kit.Button(card, spec.action, 'danger', spec.onClick)
		button:SetPoint('RIGHT', -PAD, 0)
		return card
	end

	function cards.Profile(parent, x, y, width, spec)
		local height = 128
		local card = cards.Card(parent, x, y, width, height)
		local ring = kit.Disc(card, 60, 'rule')
		ring:SetPoint('TOPLEFT', PAD - 2, -(PAD - 2))
		local portrait = card:CreateTexture(nil, 'ARTWORK', nil, 1)
		portrait:SetSize(56, 56)
		portrait:SetPoint('CENTER', ring)
		if spec.unit then SetPortraitTexture(portrait, spec.unit) else portrait:SetTexture(spec.icon) end
		portrait:SetMask(BUILib.GetLibMedia('circle_mask'))
		local name = cards.Label(card, spec.name, PAD + 72, PAD + 2, 15, 'text')
		name:SetWidth(width - PAD * 2 - 72)
		name:SetWordWrap(false)
		cards.Label(card, spec.sub or '', PAD + 72, PAD + 24, 12, 'muted')
		local chipX = PAD + 72
		for index, tag in ipairs(spec.tags or {}) do
			local chip = cards.Chip(card, tag, cards.SeriesColor(index))
			chip:SetPoint('TOPLEFT', chipX, -(PAD + 50))
			chipX = chipX + chip:GetWidth() + CHIP_GAP
		end
		return card
	end

	function cards.Steps(parent, x, y, width, spec)
		local count = #spec.steps
		local height = 46 + count * STEP_ROW + PAD - 12
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		local lineX = PAD + math.floor(STEP_DISC / 2)
		local line = kit.Fill(card, 'rule', 'ARTWORK')
		line:SetPoint('TOPLEFT', lineX, -(46 + STEP_DISC / 2))
		line:SetSize(1, (count - 1) * STEP_ROW)
		card.rows = {}
		for index, step in ipairs(spec.steps) do
			local rowY = 46 + (index - 1) * STEP_ROW
			local disc = kit.Disc(card, STEP_DISC, 'secondary', 'ARTWORK', 1)
			disc:SetPoint('TOPLEFT', PAD, -rowY)
			local number = kit.Text(card, tostring(index), 10, 'secondaryText')
			number:SetPoint('CENTER', disc)
			local check = kit.Glyph(card, 'check', 10, 'onAccent', 'OVERLAY')
			check:SetPoint('CENTER', disc)
			local textWidth = width - PAD * 2 - STEP_DISC - 14
			local label = cards.Label(card, step.label, PAD + STEP_DISC + 14, rowY + 2, 12, 'text')
			label:SetWidth(textWidth)
			label:SetWordWrap(false)
			local sub = cards.Label(card, step.sub or '', PAD + STEP_DISC + 14, rowY + 18, 10, 'muted')
			sub:SetWidth(textWidth)
			sub:SetWordWrap(false)
			card.rows[index] = { disc = disc, number = number, check = check, label = label, sub = sub }
		end
		function card:Set(states)
			for index, row in ipairs(self.rows) do
				local state = states[index] or 'todo'
				window:Paint(row.disc, state == 'todo' and 'secondary' or 'accent')
				window:Paint(row.number, state == 'current' and 'onAccent' or 'secondaryText')
				row.number:SetShown(state ~= 'done')
				row.check:SetShown(state == 'done')
				window:Paint(row.label, state == 'current' and 'text' or (state == 'done' and 'muted' or 'faint'))
			end
		end
		card:Set(spec.states or {})
		return card
	end

	function cards.Meter(parent, x, y, width, spec)
		local height = 190
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		cards.Description(card, spec.description or '', PAD, 38, width - PAD * 2)
		card.value = cards.Readout(card, PAD, 62, 34)
		local tag = CreateFrame('Frame', nil, card)
		tag:SetHeight(20)
		tag:SetPoint('LEFT', card.value, 'RIGHT', 12, 0)
		local tagFill = Widget.DrawCardShape(tag, 6, { 1, 1, 1, 1 }, { 0, 0, 0, 0 }, 'ARTWORK', 0, 0)
		window:Paint(tagFill, 'accent')
		tagFill:SetAlpha(0.18)
		card.tag = kit.Text(tag, '', 11, 'text')
		card.tag:SetPoint('CENTER')
		local trackWidth = width - PAD * 2
		local trackY = 124
		card.fill = cards.Bar(card, PAD, trackY, trackWidth, 8)
		local top = spec.top or 1
		for _, mark in ipairs(spec.marks or {}) do
			local tick = kit.Fill(card, 'muted', 'ARTWORK', 2)
			tick:SetPoint('TOPLEFT', PAD + math.floor(trackWidth * Clamp(mark.at / top) + 0.5), -(trackY - 3))
			tick:SetSize(1, 14)
			kit.Text(card, mark.label, 10, 'muted'):SetPoint('TOP', tick, 'BOTTOM', 0, -4)
		end
		cards.Description(card, spec.note or '', PAD, 164, trackWidth)
		function card:Set(value, text, grade)
			self.value:SetText(text)
			self.tag:SetText(grade or '')
			tag:SetShown(grade ~= nil)
			tag:SetWidth(Widget.EvenSize(self.tag:GetStringWidth() + 16))
			self.fill:SetFraction(value / top)
		end
		card:Set(spec.value or 0, spec.text or '', spec.grade)
		return card
	end

	function cards.Ruler(parent, x, y, width, spec)
		local height = 150
		local card = cards.Card(parent, x, y, width, height)
		cards.Caption(card, spec.caption, PAD, PAD)
		card.value = cards.Readout(card, PAD, 34, 26)
		local rulerX, rulerWidth = PAD, width - PAD * 2
		local baseline = 78 + MARK_LABEL + MARK_HEIGHT
		local step = (rulerWidth - 1) / (TICKS - 1)
		local ticks = {}
		for index = 1, TICKS do
			local tick = kit.Fill(card, 'faint', 'ARTWORK')
			tick:SetPoint('BOTTOMLEFT', card, 'TOPLEFT', rulerX + math.floor((index - 1) * step + 0.5), -baseline)
			tick:SetSize(1, (index - 1) % 10 == 0 and TICK_HEIGHT or math.floor(TICK_HEIGHT * 0.6))
			ticks[index] = tick
		end
		local marks = {}
		for slot = 1, 2 do
			local line = kit.Fill(card, 'text', 'ARTWORK', 2)
			line:SetSize(2, MARK_HEIGHT)
			local label = kit.Text(card, '', 11, 'text')
			label:SetPoint('BOTTOM', line, 'TOP', 0, 2)
			marks[slot] = { line = line, label = label }
		end
		local left = cards.Label(card, '', rulerX, baseline + 6, 10, 'muted')
		local middle = kit.Text(card, '', 10, 'muted')
		middle:SetPoint('TOP', card, 'TOPLEFT', rulerX + math.floor(rulerWidth / 2), -(baseline + 6))
		local right = kit.Text(card, '', 10, 'muted')
		right:SetPoint('TOPRIGHT', card, 'TOPLEFT', rulerX + rulerWidth, -(baseline + 6))
		function card:Set(fraction, text, markSpecs, labels)
			self.value:SetText(text)
			for index, tick in ipairs(ticks) do
				window:Paint(tick, (index - 1) / (TICKS - 1) <= fraction and 'accent' or 'faint')
			end
			for slot, mark in ipairs(marks) do
				local markSpec = markSpecs and markSpecs[slot]
				mark.line:SetShown(markSpec ~= nil)
				mark.label:SetShown(markSpec ~= nil)
				if markSpec then
					mark.line:ClearAllPoints()
					mark.line:SetPoint('BOTTOM', card, 'TOPLEFT', rulerX + math.floor(rulerWidth * Clamp(markSpec.at) + 0.5), -baseline)
					window:Paint(mark.line, markSpec.role or 'text')
					mark.label:SetText(markSpec.label)
					window:Paint(mark.label, markSpec.role or 'text')
				end
			end
			left:SetText(labels and labels[1] or '')
			middle:SetText(labels and labels[2] or '')
			right:SetText(labels and labels[3] or '')
		end
		card:Set(spec.fraction or 0, spec.text or '', spec.marks, spec.labels)
		return card
	end

	function cards.Task(parent, x, y, width, spec)
		local height = 176
		local card = cards.Card(parent, x, y, width, height)
		cards.Badge(card, spec.icon or 'reload', 26, PAD, PAD - 2, true)
		cards.Label(card, spec.title, PAD + 36, PAD + 2, 13, 'text')
		local metaX = PAD
		card.meta = {}
		for index, item in ipairs(spec.meta or {}) do
			if index > 1 then
				local divider = kit.Fill(card, 'rule', 'ARTWORK')
				divider:SetPoint('TOPLEFT', metaX, -52)
				divider:SetSize(1, 16)
				metaX = metaX + 12
			end
			local key = cards.Label(card, item.label .. ':', metaX, 54, 11, 'muted')
			local value = cards.Label(card, item.value or '', metaX + math.ceil(key:GetStringWidth()) + 5, 54, 11, 'text')
			card.meta[index] = value
			metaX = metaX + math.ceil(key:GetStringWidth()) + 5 + math.ceil(value:GetStringWidth()) + 12
		end
		local callout = CreateFrame('Frame', nil, card)
		callout:SetPoint('TOPLEFT', PAD, -82)
		callout:SetSize(width - PAD * 2, height - 82 - PAD)
		for _, piece in ipairs(Widget.DrawRoundedRect(callout, 6, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)) do window:Paint(piece, 'input') end
		kit.Glyph(callout, 'question', 12, 'accent'):SetPoint('TOPLEFT', 12, -12)
		card.body = cards.Description(callout, spec.body or '', 32, 11, width - PAD * 2 - 44)
		function card:Set(body, values)
			self.body:SetText(body)
			for index, value in ipairs(values or {}) do self.meta[index]:SetText(value) end
		end
		return card
	end

	function cards.Clock(parent, x, y, width, spec)
		local height = 128
		local card = cards.Card(parent, x, y, width, height)
		cards.Label(card, spec.caption, PAD, PAD, 12, 'muted')
		if spec.icon then cards.Badge(card, spec.icon, 30, width - PAD - 30, 14) end
		card.value = cards.Readout(card, PAD, 40, 34, width - PAD * 2)
		card.note = cards.Label(card, '', PAD, 86, 11, 'muted')
		cards.Every(card, spec.every or 1, function()
			local text, note = spec.read()
			card.value:SetText(text)
			card.note:SetText(note or '')
		end)
		return card
	end

	function cards.Color(parent, x, y, width, spec)
		local height = 128
		local card = cards.Card(parent, x, y, width, height, { onClick = spec.onClick })
		local block = CreateFrame('Frame', nil, card)
		block:SetPoint('TOPLEFT', 1, -1)
		block:SetPoint('TOPRIGHT', -1, -1)
		block:SetHeight(70)
		card.swatch = Widget.DrawCardShape(block, RADIUS - 1, { 1, 1, 1, 1 }, { 0, 0, 0, 0 }, 'BORDER', 0, 0)
		card.square = block:CreateTexture(nil, 'BORDER', nil, 2)
		card.square:SetTexture(Widget.WHITE)
		card.square:SetPoint('BOTTOMLEFT')
		card.square:SetPoint('BOTTOMRIGHT')
		card.square:SetHeight(RADIUS)
		local rule = kit.Fill(card, 'rule', 'ARTWORK')
		rule:SetPoint('TOPLEFT', 1, -71)
		rule:SetPoint('TOPRIGHT', -1, -71)
		rule:SetHeight(1)
		cards.Label(card, spec.title, 16, 84, 13, 'text')
		card.state = kit.Text(card, '', 11, 'muted')
		card.state:SetPoint('TOPRIGHT', -16, -86)
		card.hex = cards.Label(card, '', 16, 104, 12, 'muted')
		kit.Glyph(card, 'palette', 12, 'muted'):SetPoint('TOPRIGHT', -16, -104)
		function card:Set(red, green, blue, state)
			self.swatch:SetVertexColor(red, green, blue, 1)
			self.square:SetColorTexture(red, green, blue, 1)
			self.hex:SetText(('#%02X%02X%02X'):format(math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5)))
			self.state:SetText(state or '')
		end
		if spec.color then card:Set(spec.color[1], spec.color[2], spec.color[3], spec.state) end
		return card
	end

	function cards.Chips(parent, x, y, width, spec)
		local height = spec.height or 118
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		card.chips = {}
		function card:Set(list)
			for index, entry in ipairs(list) do
				local chip = self.chips[index]
				if not chip then
					chip = cards.Chip(self, '', cards.SeriesColor(index))
					self.chips[index] = chip
				end
				chip:SetText(entry)
				chip:Show()
			end
			for index = #list + 1, #self.chips do self.chips[index]:Hide() end
			local chipX, chipY = PAD, 46
			for index = 1, #list do
				local chip = self.chips[index]
				if chipX > PAD and chipX + chip:GetWidth() > width - PAD then
					chipX, chipY = PAD, chipY + CHIP_HEIGHT + CHIP_GAP
				end
				chip:ClearAllPoints()
				chip:SetPoint('TOPLEFT', chipX, -chipY)
				chipX = chipX + chip:GetWidth() + CHIP_GAP
			end
		end
		card:Set(spec.list or {})
		return card
	end

	function cards.Note(parent, x, y, width, spec)
		local height = spec.height or 150
		local card = cards.Card(parent, x, y, width, height)
		cards.Title(card, spec.title)
		if spec.icon then cards.Badge(card, spec.icon, 26, width - PAD - 26, 14) end
		card.body = cards.Description(card, spec.body or '', PAD, 46, width - PAD * 2)
		card.body:SetSpacing(4)
		card.footer = cards.Caption(card, spec.footer or '', PAD, height - PAD - 10)
		function card:Set(body, footer)
			self.body:SetText(body)
			self.footer:SetText((footer or ''):upper())
		end
		return card
	end

	for _, extend in ipairs(Layout.CardKitExtensions) do extend(cards, kit, window) end
	return cards
end
