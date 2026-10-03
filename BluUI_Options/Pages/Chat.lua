local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960

local function Window()
	return BUI.PageEngine.window
end

local function Info()
	return BUI.Skinning.GetSkinRegistry().chat
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function Sections(ui, _, parent, width)
	return Info().buildBoards(ui, parent, width)
end

BUI.PageEngine.RegisterPage('chat', {
	title = 'Chat',
	buttonText = 'Chat',
	icon = 'chat',
	hidden = true,
	navParent = 'settings',
	OnBuild = function(pageFrame)
		local Skin = BUI.Skinning
		local info = Info()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'chat',
			title = 'Chat',
			placeholder = 'Search chat settings...',
			back = { label = 'skins', onClick = function() BUI.PageEngine.NavigateToID('settings') end },
			tools = {
				{ text = 'Reset', onClick = function()
					info.reset()
					RebuildPage()
				end },
				{ icon = 'enable', tooltip = 'Turn the chat skin on or off', get = function() return Skin.IsSkinEnabled('chat') end, set = function(value)
					Skin.SetSkinEnabled('chat', value)
					if not value then BUI.SkinningPage.ConfirmReload(info) end
				end },
			},
			tabs = { { label = 'Chat', build = Sections } },
		})
		page:AutoRefresh()
	end,
})
