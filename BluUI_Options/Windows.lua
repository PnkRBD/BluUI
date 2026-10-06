local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout = BUILib.Layout

local WINDOW_WIDTH, WINDOW_HEIGHT = 1100, 780
local PAGE_WIDTH = 960

BUI.OptionsWindow = {}
local OptionsWindow = BUI.OptionsWindow
local windows = {}

function OptionsWindow.New(id, config)
	local width, height = config.width or WINDOW_WIDTH, config.height or WINDOW_HEIGHT
	local shell = Layout.Shell({
		chrome = 'topnav',
		title = config.title,
		icon = BUI.C.ICON_PATH,
		brand = config.brand,
		version = BUI.Version,
		width = width, height = height,
		minWidth = width, minHeight = height,
		pageWidth = config.pageWidth or PAGE_WIDTH,
		strata = 'FULLSCREEN_DIALOG', frameLevel = 200,
		globalName = config.globalName,
		resizable = false,
		clampedToScreen = false,
		resolveFont = BUI.FetchFont,
		onWindowCreated = function(window)
			window.frame:SetScale(BUI.db.global.windowScale / 100)
			if config.onClosed then
				window.frame:HookScript('OnHide', BUI.Profiler.Wrap(config.title .. ' window closed', config.onClosed))
			end
		end,
	})
	shell.memory.theme = BUI.GetDB().windowTheme
	shell:AddPage(id, { title = config.title, icon = config.icon, hidden = true, build = config.build })
	windows[id] = { shell = shell, onOpen = config.onOpen }
	return shell
end

function OptionsWindow.Open(id)
	local entry = windows[id]
	if not entry.shell:IsShown() and entry.onOpen then entry.onOpen(entry.shell) end
	entry.shell:Open(id)
end
