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
local SLIDER_WIDTH = 220
local DROPDOWN_WIDTH = 200

local CHANNELS = {
	{ value = 'Master', text = 'Master' },
	{ value = 'SFX', text = 'Sound Effects' },
	{ value = 'Music', text = 'Music' },
	{ value = 'Ambience', text = 'Ambience' },
	{ value = 'Dialog', text = 'Dialog' },
}

local function Menu(ui, row, entries, get, set)
	ui.Menu(row, DROPDOWN_WIDTH, { entries = entries, get = get, set = set }):SetPoint('RIGHT', -ui.ROW_INSET, 0)
end

local function SoundBoard(ui, parent, width)
	local general = BUI.GetDB().general
	local board = ui.Board(parent, width, { title = 'Voice and sound', description = 'The voice BluUI speaks with, how loud it is, and the channel its alert sounds play on.' })
	Menu(ui, board:AddRow('Voice', 'Used for every spoken alert', DROPDOWN_WIDTH), BUI.TTS.BuildVoiceDropdownItems(), function() return general.ttsVoice end, function(voiceID)
		general.ttsVoice = voiceID
		BUI.TTS.Speak('Voice selected', { voiceID = voiceID })
	end)
	ui.Slider(board:AddRow('Volume', 'For spoken alerts', SLIDER_WIDTH), SLIDER_WIDTH, { min = 0, max = 100, step = 5, get = function() return general.ttsVolume end, set = function(value) general.ttsVolume = value end }):SetPoint('RIGHT', -ui.ROW_INSET, 0)
	Menu(ui, board:AddRow('Alert sound channel', 'Where BluUI alert sounds play', DROPDOWN_WIDTH), CHANNELS, function() return general.soundChannel end, function(channel) general.soundChannel = channel end)
	return board
end

local PANES = {
	theme = BUI.ThemePage,
	modules = BUI.ModulesPage,
	help = BUI.HelpPage,
	appearance = BUI.AppearancePage,
	skinning = BUI.SkinningPage,
	visibility = BUI.VisibilityPage,
}

BUI.PageEngine.RegisterPage("settings", {
	title = "Settings",
	icon = 'cog',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local rail = Layout.RailPage(page:GetTab(1), { window = BUI.PageEngine.window }, {
			icon = 'cog',
			title = 'Settings',
			placeholder = 'Search settings...',
			tabs = TAB_IDS,
			rail = { groups = RAIL_GROUPS },
			build = function(kit, shell, parent, width, item, railPage)
				if item.id == 'sound' then return { SoundBoard(kit, parent, width) } end
				return PANES[item.id].Sections(kit, shell, parent, width, railPage)
			end,
		})
		pageFrame._page = rail.adapter
		page:AutoRefresh()
	end,
})
