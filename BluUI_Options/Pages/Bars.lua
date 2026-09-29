local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Controls, Layout, Theme = BUILib.Controls, BUILib.Layout, BUILib.Theme
local CastBar = BUI.CastBar
local Pixel = BUI.Pixel

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 110
local PREVIEW_ROOM = 120
local MENU_WIDTH = 160
local ICON_SIZE = 24
local NAME_WIDTH = 300
local INPUT_WIDTH = 260
local ERASE_SIZE = 32
local ERASE_INSET = 18
local TOOL_GAP = 12
local RESULTS_WIDTH = 280
local TEXT_OFFSET_RANGE = 100

local UNITS = { 'player', 'target', 'focus' }
local UNIT_INDEX = { player = 1, target = 2, focus = 3 }
local RAIL_GROUPS = {
	{ title = 'Bars', items = {
		{ id = 'player', label = 'Player' },
		{ id = 'target', label = 'Target' },
		{ id = 'focus', label = 'Focus' },
	} },
}
local TITLES = { player = 'Player cast bar', target = 'Target cast bar', focus = 'Focus cast bar' }
local STAGE_LAYERS = {
	{ value = 'background', text = 'Background' },
	{ value = 'foreground', text = 'Bar fill' },
}

local selectedUnit = 'player'
local preview
local fonts, textures

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local relock = { SetValue = Repaint }

local function Settings(unit)
	return CastBar.GetSettings(unit or selectedUnit)
end

local function RefreshPreview()
	if preview then preview:Update() end
end

local function Apply()
	local unitFrames = BUI.UnitFrames
	for _, unit in ipairs(UNITS) do
		local frame = unitFrames[unit]
		if frame then CastBar.ApplyCastbar(frame, unit) end
	end
	RefreshPreview()
end

local function Option(settings, label, key, extra)
	local option = { label = label, get = function() return settings[key] end, set = function(value) settings[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Color(settings, label, key)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = true,
		get = function()
			local color = settings[key]
			return color[1], color[2], color[3], color[4] or 1
		end,
		set = function(red, green, blue, alpha) settings[key] = { red, green, blue, alpha } end,
	}
end

local function Toggle(settings, label, key)
	return { label = label, get = function() return settings[key] == true end, set = function(value) settings[key] = value end }
end

local function OnUnlessOff(settings, label, key)
	return { label = label, get = function() return settings[key] ~= false end, set = function(value) settings[key] = value end }
end

local function TextTools(settings, unit)
	local options = {
		Option(settings, 'Text size', 'textSize', { min = 8, max = 24, step = 1 }),
		Toggle(settings, 'Show timer', 'showTimer'),
		OnUnlessOff(settings, 'Show total time', 'showTotalTime'),
		OnUnlessOff(settings, 'Countdown', 'countdown'),
		Toggle(settings, 'Show spell name', 'showSpellName'),
		Toggle(settings, 'Show cast target', 'showCastTarget'),
		{ label = 'Name length, 0 for no limit', min = 0, max = 30, step = 1, get = function() return settings.spellNameMaxLength or 0 end, set = function(value) settings.spellNameMaxLength = value > 0 and value or nil end },
		Option(settings, 'Text strata', 'textStrata', { entries = BUI.C.STRATA_OPTIONS }),
	}
	local tools = { Color(settings, 'Text color', 'textColor') }
	if unit == 'player' then
		tools[#tools + 1] = Color(settings, 'Latency color', 'latencyColor')
		options[#options + 1] = Toggle(settings, 'Show latency', 'showLatency')
	end
	tools[#tools + 1] = { entries = fonts, width = MENU_WIDTH, get = function() return settings.font or BUI.C.GLOBAL_OPTION end, set = function(value) settings.font = value end }
	tools[#tools + 1] = { icon = 'text', tooltip = 'Size and what the bar shows', title = 'Text', options = options }
	tools[#tools + 1] = { icon = 'mover', tooltip = 'Text offset', title = 'Text offset', options = {
		Option(settings, 'Horizontal', 'textOffsetX', { min = -TEXT_OFFSET_RANGE, max = TEXT_OFFSET_RANGE, step = 1 }),
		Option(settings, 'Vertical', 'textOffsetY', { min = -TEXT_OFFSET_RANGE, max = TEXT_OFFSET_RANGE, step = 1 }),
	} }
	return tools
end

local function BarBoard(ui, parent, width, unit)
	local settings = Settings(unit)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = TITLES[unit],
		description = 'Size, colors, texture and text. Unlock it with the eye in the header to drag it, right-click it to lock it again.',
	})
	board:AddSwitch('Class color', function() return settings.useClassColor == true end, function(value)
		settings.useClassColor = value
		Apply()
	end, 'Color the bar by your class instead of the bar color')
	board:AddSwitch('Spell icon', function() return settings.showIcon == true end, function(value)
		settings.showIcon = value
		Apply()
	end, 'The spell icon beside the bar')
	board:AddTools('Bar', 'Colors, texture, size and position', {
		Color(settings, 'Bar color', 'barColor'),
		Color(settings, 'Border color', 'borderColor'),
		Color(settings, 'Background color', 'bgColor'),
		{ entries = textures, width = MENU_WIDTH, get = function() return settings.texture end, set = function(value) settings.texture = value end },
		{ tooltip = 'Size, border and layer', title = 'Bar', options = {
			Option(settings, 'Width', 'width', { min = 100, max = 500, step = 1 }),
			Option(settings, 'Height', 'height', { min = 4, max = 50, step = 1 }),
			Option(settings, 'Border size', 'borderSize', { min = 0, max = 5, step = 1 }),
			Option(settings, 'Strata', 'frameStrata', { entries = BUI.C.STRATA_OPTIONS }),
		} },
		BUI.PositionTool(settings),
	}, Apply)
	board:AddTools('Text', 'Font, color and what the bar shows', TextTools(settings, unit), Apply)
	if unit == 'player' then
		board:AddTools('Channel ticks', 'Tick marks on channeled casts', {
			Color(settings, 'Tick color', 'channelTickColor'),
			{ tooltip = 'Tick width', title = 'Channel ticks', options = { Option(settings, 'Tick width', 'channelTickWidth', { min = 1, max = 6, step = 1 }) } },
			Toggle(settings, nil, 'channelTicks'),
		}, Apply)
	end
	return board
end

local function PreviewEye(unit)
	return { icon = 'eye', tooltip = 'Preview the ready line and the voice lines', get = function() return CastBar.IsPreviewingInterrupt(unit) end, set = function(value)
		if value then CastBar.PreviewInterrupt(unit) else CastBar.StopInterruptPreview(unit) end
		Repaint()
	end }
end

local function InterruptsBoard(ui, parent, width, unit)
	local settings = Settings(unit)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Interrupts',
		description = 'Color the bar by whether you can kick the cast, mark when your kick is back, and hear about it.',
	})
	board:AddTools('Cast colors', 'Bar color by interrupt state', {
		Color(settings, 'Interrupt soon', 'interruptWindowColor'),
		Color(settings, 'Can interrupt', 'interruptReadyColor'),
		Color(settings, 'Interrupt on cooldown', 'interruptOnCDColor'),
		Color(settings, 'Not interruptible', 'interruptColor'),
	}, Apply)
	board:AddTools('Ready line', 'Line marking when your kick is back up', {
		Color(settings, 'Line color', 'interruptTickColor'),
		{ tooltip = 'Line width and window', title = 'Ready line', options = {
			Option(settings, 'Line width', 'interruptTickWidth', { min = 1, max = 6, step = 1 }),
			OnUnlessOff(settings, 'Show interrupt window', 'interruptWindow'),
		} },
		PreviewEye(unit),
		OnUnlessOff(settings, nil, 'interruptTick'),
	}, Apply)
	board:AddTools('Interrupt voice', 'Spoken alerts when your kick is ready, or will be before the cast ends', {
		{ tooltip = 'Voice lines and timing', title = 'Interrupt voice', options = {
			Toggle(settings, 'Kick ready', 'interruptTTS'),
			{ label = 'Ready text', kind = 'input', placeholder = 'Kick', get = function() return settings.interruptTTSText end, set = function(text) settings.interruptTTSText = text ~= '' and text or 'Kick' end },
			Toggle(settings, 'Kick soon', 'interruptTTSSoon'),
			{ label = 'Soon text', kind = 'input', placeholder = 'Kick soon', get = function() return settings.interruptTTSSoonText end, set = function(text) settings.interruptTTSSoonText = text ~= '' and text or 'Kick soon' end },
			Option(settings, 'Soon lead in seconds', 'interruptTTSSoonWindow', { min = 1, max = 10, step = 0.5 }),
		} },
		PreviewEye(unit),
	}, Apply)
	return board
end

local function EmpowerBoard(ui, parent, width)
	local settings = Settings('player')
	local base = settings.barColor
	for stage = 1, 4 do
		settings.stageColors[stage] = settings.stageColors[stage] or { base[1], base[2], base[3], base[4] }
	end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Empowered casts',
		description = 'Stage lines and per-stage tints for empowered spells.',
	})
	board:AddTools('Stage pips', 'Lines splitting the empower stages', {
		Color(settings, 'Pip color', 'pipColor'),
		{ tooltip = 'Width and glow', title = 'Stage pips', options = {
			Option(settings, 'Line width', 'pipWidth', { min = 1, max = 6, step = 1 }),
			OnUnlessOff(settings, 'Glow', 'pipGlow'),
		} },
	}, Apply)
	local stages = {}
	for stage = 1, 4 do
		stages[stage] = {
			kind = 'swatch', tooltip = 'Stage ' .. stage, opacity = true,
			get = function()
				local color = settings.stageColors[stage]
				return color[1], color[2], color[3], color[4] or 1
			end,
			set = function(red, green, blue, alpha) settings.stageColors[stage] = { red, green, blue, alpha } end,
		}
	end
	stages[#stages + 1] = { entries = STAGE_LAYERS, width = MENU_WIDTH,
		get = function() return settings.stageColorBackground ~= false and 'background' or 'foreground' end,
		set = function(value) settings.stageColorBackground = value == 'background' end }
	stages[#stages + 1] = Toggle(settings, nil, 'stageColorsEnabled')
	board:AddTools('Stage colors', 'Tint the bar per empower stage', stages, Apply)
	return board
end

local function SpellColorsSection(ui, parent, width, page)
	local settings = Settings('player')
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Custom spell colors',
		description = 'Give particular spells their own bar color. Type a name, paste an ID or a link, then press Enter.',
		columns = { { 'Spell', ui.AVATAR_X } },
	})
	local function Add(spellID)
		local red, green, blue = Theme.GetAccent()
		settings.spellColors[spellID] = settings.spellColors[spellID] or { red, green, blue, 1 }
		Apply()
		page:RebuildCurrent()
	end
	local function Search(anchor, text)
		local spellID = BUI.Lookup.ParseSpellInput(text)
		if spellID then return Add(spellID) end
		local hits = BUI.Lookup.SearchSpells(text)
		if #hits == 1 then return Add(hits[1].id) end
		local items = {}
		for _, hit in ipairs(hits) do
			items[#items + 1] = { text = hit.name, icon = hit.icon, callback = function() Add(hit.id) end }
		end
		if #items == 0 then items[1] = { text = 'Nothing found', disabled = true } end
		Controls.ContextMenu(items, { anchor = anchor, width = RESULTS_WIDTH, window = Window() })
	end
	local toggleRow = section:AddRow('use custom spell colors')
	ui.RowTitle(toggleRow, 'Use custom colors', 'Off keeps every cast on the bar color', ui.AVATAR_X, NAME_WIDTH)
	ui.Switch(toggleRow, function() return settings.useSpellColors == true end, function(value)
		settings.useSpellColors = value
		Apply()
	end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
	local addRow = section:AddRow('add a spell')
	ui.RowTitle(addRow, 'Add a spell', 'Name, ID or spell link', ui.AVATAR_X, NAME_WIDTH)
	local box
	box = ui.Input(addRow, INPUT_WIDTH, { placeholder = 'Search...', get = function() return '' end, set = function(text) Search(box, text) end })
	box:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	local spells = {}
	for spellID in pairs(settings.spellColors) do
		local icon, name = BUI.Lookup.GetSpellInfo(spellID)
		spells[#spells + 1] = { id = spellID, icon = icon, name = name or ('Spell ' .. spellID) }
	end
	table.sort(spells, function(left, right) return left.name < right.name end)
	for _, spell in ipairs(spells) do
		local row = section:AddRow(spell.name)
		local icon = row:CreateTexture(nil, 'ARTWORK')
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon:SetPoint('LEFT', ui.AVATAR_X, 0)
		icon:SetTexture(spell.icon)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ui.RowTitle(row, spell.name, 'Spell ' .. spell.id, ui.NAME_X, NAME_WIDTH)
		ui.IconButton(row, 'erase', 'Remove ' .. spell.name, function()
			settings.spellColors[spell.id] = nil
			Apply()
			page:RebuildCurrent()
		end, 'danger', ERASE_SIZE):SetPoint('RIGHT', -ERASE_INSET, 0)
		ui.Tool(row, {
			kind = 'swatch', tooltip = 'Bar color for ' .. spell.name, opacity = true,
			get = function()
				local color = settings.spellColors[spell.id]
				return color[1], color[2], color[3], color[4] or 1
			end,
			set = function(red, green, blue, alpha) settings.spellColors[spell.id] = { red, green, blue, alpha } end,
		}, Apply):SetPoint('RIGHT', -(ERASE_INSET + ERASE_SIZE + TOOL_GAP), 0)
	end
	return section
end

local function Panes(ui, _, parent, width, item, page)
	local unit = item.id
	local sections = { BarBoard(ui, parent, width, unit) }
	if unit == 'player' then
		if BUI.Tools.PlayerCanEmpower() then sections[#sections + 1] = EmpowerBoard(ui, parent, width) end
		sections[#sections + 1] = SpellColorsSection(ui, parent, width, page)
	else
		sections[#sections + 1] = InterruptsBoard(ui, parent, width, unit)
	end
	return sections
end

local function BuildPreview(band)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetAllPoints()
	stage:SetClipsChildren(true)

	local bar = CreateFrame('StatusBar', nil, stage)
	bar:SetPoint('CENTER')
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0.65)
	local background = bar:CreateTexture(nil, 'BACKGROUND')
	background:SetAllPoints()

	local iconHost = CreateFrame('Frame', nil, stage)
	local icon = iconHost:CreateTexture(nil, 'ARTWORK')
	icon:SetAllPoints()
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetTexture(136048)

	local name = bar:CreateFontString(nil, 'OVERLAY')
	local time = bar:CreateFontString(nil, 'OVERLAY')

	function band:Update()
		local settings = Settings()
		local texture = CastBar.GetTexturePath(settings.texture)
		bar:SetStatusBarTexture(texture)
		background:SetTexture(texture)
		local barWidth = math.min(settings.width, PAGE_WIDTH - PREVIEW_ROOM)
		bar:SetSize(barWidth, settings.height)
		if settings.useClassColor then
			local _, class = UnitClass('player')
			local classColor = class and RAID_CLASS_COLORS[class]
			if classColor then bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1) else bar:SetStatusBarColor(unpack(settings.barColor)) end
		else
			bar:SetStatusBarColor(unpack(settings.barColor))
		end
		local backgroundColor = settings.bgColor
		background:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4] or 1)
		local borderColor = settings.borderColor
		Pixel.ApplyBorder(bar, settings.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
		iconHost:SetShown(settings.showIcon == true)
		iconHost:SetSize(settings.height, settings.height)
		iconHost:ClearAllPoints()
		iconHost:SetPoint('RIGHT', bar, 'LEFT', -2, 0)
		CastBar.StyleText(bar, name, time, settings, CastBar.GetFont(settings.font))
		name:SetText('Bloodlust')
		time:SetText('1.4')
		name:SetShown(settings.showSpellName ~= false)
		time:SetShown(settings.showTimer ~= false)
	end
	band:HookScript('OnShow', function(self) self:Update() end)
	band:Update()
	return band
end

BUI.PageEngine.RegisterPage('castbars', {
	title = 'Cast Bars',
	buttonText = 'Cast Bars',
	icon = 'play',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		textures = BUI.BuildTextureDropdownItems(BUI.C.GLOBAL_OPTION)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local tab = page:GetTab(1)
		local adapter = { tabContents = { tab, tab, tab }, currentTab = UNIT_INDEX[selectedUnit] }
		local rail
		rail = Layout.RailPage(tab, { window = Window() }, {
			icon = 'play',
			title = 'Cast Bars',
			placeholder = 'Search cast bar settings...',
			tools = {
				{ icon = 'enable', tooltip = 'Turn this cast bar on or off', get = function() return Settings().enabled == true end, set = function(value)
					Settings().enabled = value
					Apply()
				end },
				{ icon = 'eye', tooltip = 'Unlock this cast bar to drag it, right-click it to lock', get = function() return not Settings().locked end, set = function(value)
					Settings().locked = not value
					Apply()
				end },
			},
			preview = { height = PREVIEW_HEIGHT, build = function(band) preview = BuildPreview(band) end },
			rail = { groups = RAIL_GROUPS, selected = selectedUnit },
			build = Panes,
		})
		local Select = rail.Select
		function rail:Select(id)
			selectedUnit = id
			adapter.currentTab = UNIT_INDEX[id]
			Select(self, id)
			Repaint()
			RefreshPreview()
		end
		function adapter:SetTab(index)
			rail:Select(UNITS[index])
		end
		pageFrame._page = adapter
		CastBar._lockToggles = { player = relock, target = relock, focus = relock }
		page:AutoRefresh()
	end,
	OnHide = function()
		for _, unit in ipairs(UNITS) do CastBar.StopInterruptPreview(unit) end
	end,
})
