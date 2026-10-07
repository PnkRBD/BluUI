local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960
local SKINNING_TAB = 3

local function Window()
	return BUI.PageEngine.window
end

local function BackToSkins()
	BUI.PageEngine.NavigateToID('settings')
	local settings = BUI.PageEngine.pages.settings
	local adapter = settings and settings.frame and settings.frame._page
	if adapter and adapter.SetTab then adapter:SetTab(SKINNING_TAB) end
end

local function RegisterSkinPage(id, title, icon)
	BUI.PageEngine.RegisterPage(id, {
		title = title,
		buttonText = title,
		hidden = true,
		navParent = 'settings',
		OnBuild = function(pageFrame)
			local Skin = BUI.Skinning
			local info = Skin.GetSkinRegistry()[id]
			local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
			local tools = {}
			if info.reset then
				tools[#tools + 1] = { text = 'Reset', onClick = function()
					info.reset()
					BUILib.Defer(BUI.PageEngine.RefreshCurrentPage)
				end }
			end
			tools[#tools + 1] = { icon = 'enable', tooltip = 'Turn the ' .. title:lower() .. ' skin on or off', get = function() return Skin.IsSkinEnabled(id) end, set = function(value)
				Skin.SetSkinEnabled(id, value)
				if not value then BUI.SkinningPage.ConfirmReload(info) end
			end }
			Layout.TablePage(page:GetTab(1), { window = Window() }, {
				icon = icon,
				title = title,
				placeholder = 'Search ' .. title:lower() .. ' settings...',
				disabled = function() return not Skin.IsSkinEnabled(id) end,
				back = { label = 'skins', onClick = BackToSkins },
				tools = tools,
				tabs = { { label = title, build = function(ui, _, parent, width) return info.buildBoards(ui, parent, width) end } },
			})
			page:AutoRefresh()
		end,
	})
end

RegisterSkinPage('chat', 'Chat', 'chat')
RegisterSkinPage('objectivetracker', 'Objective Tracker', 'order')
