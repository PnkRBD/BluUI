local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960
local SKINNING_TAB = 3

local function Info()
	return BUI.Skinning.GetSkinRegistry().chat
end

local function Window()
	return BUI.PageEngine.window
end

local function Sections(ui, _, parent, width)
	return Info().buildBoards(ui, parent, width)
end

local function BackToSkins()
	BUI.PageEngine.NavigateToID('settings')
	local settings = BUI.PageEngine.pages.settings
	local adapter = settings and settings.frame and settings.frame._page
	if adapter and adapter.SetTab then adapter:SetTab(SKINNING_TAB) end
end

BUI.PageEngine.RegisterPage('chat', {
	title = 'Chat',
	buttonText = 'Chat',
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
			disabled = function() return not Skin.IsSkinEnabled('chat') end,
			back = { label = 'skins', onClick = BackToSkins },
			tools = {
				{ text = 'Reset', onClick = function()
					info.reset()
					BUILib.Defer(BUI.PageEngine.RefreshCurrentPage)
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
