local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local function Info()
	return BUI.Skinning.GetSkinRegistry().chat
end

local function Sections(ui, _, parent, width)
	return Info().buildBoards(ui, parent, width)
end

BUI.OptionsWindow.New('chat', {
	title = 'Chat',
	icon = 'chat',
	globalName = 'BluUIChatFrame',
	build = function(tab, shell)
		local Skin = BUI.Skinning
		local info = Info()
		Layout.TablePage(tab, shell, {
			icon = 'chat',
			title = 'Chat',
			placeholder = 'Search chat settings...',
			disabled = function() return not Skin.IsSkinEnabled('chat') end,
			tools = {
				{ text = 'Reset', onClick = function()
					info.reset()
					BUILib.Defer(function() shell:RebuildPage('chat') end)
				end },
				{ icon = 'enable', tooltip = 'Turn the chat skin on or off', get = function() return Skin.IsSkinEnabled('chat') end, set = function(value)
					Skin.SetSkinEnabled('chat', value)
					if not value then BUI.SkinningPage.ConfirmReload(info) end
				end },
			},
			tabs = { { label = 'Chat', build = Sections } },
		})
	end,
})
