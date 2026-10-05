local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local RAIL_GROUPS = {
	{ title = 'BluUI', items = {
		{ id = 'theme', label = 'Theme', icon = 'theme' },
		{ id = 'sound', label = 'Sound', icon = 'sound' },
		{ id = 'modules', label = 'Modules', icon = 'modules5' },
		{ id = 'help', label = 'Help', icon = 'question' },
	} },
	{ title = 'Game', items = {
		{ id = 'appearance', label = 'Appearance', icon = 'glow' },
		{ id = 'skinning', label = 'Skinning', icon = 'palette' },
		{ id = 'visibility', label = 'Visibility', icon = 'eye' },
	} },
}
local PAGE_WIDTH = 960
local TAB_IDS = { 'appearance', 'sound', 'skinning', 'visibility', 'modules', 'help', 'theme' }
local TAB_INDEX = {}
for index, id in ipairs(TAB_IDS) do TAB_INDEX[id] = index end
local SLIDER_WIDTH = 220
local DROPDOWN_WIDTH = 200

local CHANNELS = {
	{ value = 'Master', text = 'Master' },
	{ value = 'SFX', text = 'Sound Effects' },
	{ value = 'Music', text = 'Music' },
	{ value = 'Ambience', text = 'Ambience' },
	{ value = 'Dialog', text = 'Dialog' },
}

local function Window()
	return BUI.PageEngine.window
end

local function Named(entries, value)
	for _, entry in ipairs(entries) do
		if entry.value == value then return entry.text end
	end
end

local function Slider(ui, row, min, max, step, get, set)
	ui.Slider(row, SLIDER_WIDTH, { min = min, max = max, step = step, get = get, set = set }):SetPoint('RIGHT', -ui.ROW_INSET, 0)
end

local function Menu(ui, row, entries, get, set)
	local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local items = {}
		for _, entry in ipairs(entries) do
			items[#items + 1] = { text = entry.text, checked = entry.value == get(), callback = function()
				set(entry.value)
				Window():Repaint()
			end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function() dropdown.label:SetText(Named(entries, get())) end)
end

local function SoundBoard(ui, parent, width)
	local general = BUI.GetDB().general
	local board = ui.Board(parent, width, { title = 'Voice and sound', description = 'The voice BluUI speaks with, how loud it is, and the channel its alert sounds play on.' })
	Menu(ui, board:AddRow('Voice', 'Used for every spoken alert', DROPDOWN_WIDTH), BUI.TTS.BuildVoiceDropdownItems(), function() return general.ttsVoice end, function(voiceID)
		general.ttsVoice = voiceID
		BUI.TTS.Speak('Voice selected', { voiceID = voiceID })
	end)
	Slider(ui, board:AddRow('Volume', 'For spoken alerts', SLIDER_WIDTH), 0, 100, 5, function() return general.ttsVolume end, function(value) general.ttsVolume = value end)
	Menu(ui, board:AddRow('Alert sound channel', 'Where BluUI alert sounds play', DROPDOWN_WIDTH), CHANNELS, function() return general.soundChannel end, function(channel) general.soundChannel = channel end)
	return board
end

BUI.PageEngine.RegisterPage("settings", {
	title = "Settings",
	icon = 'cog',
	OnBuild = function(pageFrame)
		local panes = {
			theme = BUI.ThemePage,
			modules = BUI.ModulesPage,
			help = BUI.HelpPage,
			appearance = BUI.AppearancePage,
			skinning = BUI.SkinningPage,
			visibility = BUI.VisibilityPage,
		}
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local adapter = { tabContents = {}, currentTab = 1 }
		for index in ipairs(TAB_IDS) do adapter.tabContents[index] = {} end
		local rail
		rail = Layout.RailPage(page:GetTab(1), { window = BUI.PageEngine.window }, {
			icon = 'cog',
			title = 'Settings',
			placeholder = 'Search settings...',
			rail = { groups = RAIL_GROUPS },
			build = function(kit, shell, parent, width, item, railPage)
				if item.id == 'sound' then return { SoundBoard(kit, parent, width) } end
				return panes[item.id].Sections(kit, shell, parent, width, railPage)
			end,
		})
		local Select = rail.Select
		function rail:Select(id)
			Select(self, id)
			adapter.currentTab = TAB_INDEX[id]
		end
		function adapter:SetTab(index)
			rail:Select(TAB_IDS[index])
		end
		pageFrame._page = adapter
		page:AutoRefresh()
	end,
})
