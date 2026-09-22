local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Controls, Layout = BUILib.Controls, BUILib.Layout
local PageKit = BUILib.PageKit

local fonts, sounds

local function GetConfig() return BUI.GetDB().bloodlust end
local function Refresh() BUI.Bloodlust.Refresh() end
local function bind(key) return function(value) GetConfig()[key] = value; Refresh() end end

local function Option(kind, label, key, extra)
	local option = { kind = kind, label = label, get = function() return GetConfig()[key] end, set = function(value) GetConfig()[key] = value end, apply = Refresh }
	if extra then for name, value in pairs(extra) do option[name] = value end end
	return option
end

local function PlaySound(value)
	if value ~= 'None' then BUI.PlaySoundByName(value) end
end

local function SoundOption(label, key)
	return { kind = 'dropdown', label = label, items = sounds, get = function() return GetConfig()[key] end, set = function(value)
		GetConfig()[key] = value
		PlaySound(value)
	end }
end

local function SoundDropdown(row, key)
	return Controls.Dropdown(row, nil, sounds, GetConfig()[key], function(value)
		GetConfig()[key] = value
		PlaySound(value)
		Refresh()
	end, nil, 160)
end

local function Swatch(row, key)
	local color = GetConfig()[key]
	return Controls.ColorSwatch(row, { r = color[1], g = color[2], b = color[3], a = color[4], tooltip = 'Text color',
		callback = function(red, green, blue, alpha) GetConfig()[key] = { red, green, blue, alpha }; Refresh() end })
end

local function Cog(row, title, tooltip, options)
	return PageKit.SettingsIcon(row, { title = title, tooltip = tooltip, width = 280, options = options })
end

local function StopPreview()
	if BUI.Bloodlust.IsPreviewing() then BUI.Bloodlust.StopPreview() end
end

BUI.PageEngine.RegisterPage('bloodlust', {
	title = 'Bloodlust',
	buttonText = 'Bloodlust',
	hidden = true,
	navParent = 'auras',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems('GLOBAL')
		sounds = BUI.BuildSoundDropdownItems()
		BUI.Tools.AddPageWatermark(pageFrame)
		local width = Layout.PAGE_CONTENT_W

		local grids = {}
		local function SyncDim()
			local enabled = GetConfig().enabled
			for index = 1, #grids do grids[index]:SyncDim(enabled) end
		end

		local titleHeight, titleHolder = PageKit.PageTitle(pageFrame, 'Bloodlust', width, {
			desc = 'Tracks Bloodlust, Heroism and similar haste buffs. Use [spell] for the buff name and [time] for the countdown.',
			back = { tooltip = 'Back to Alerts', onClick = function() BUI.PageEngine.NavigateToID('auras') end },
			preview = { tooltip = 'Preview the alerts', onToggle = function(previewing)
				if previewing then BUI.Bloodlust.StartPreview() else BUI.Bloodlust.StopPreview() end
			end },
			enable = { value = GetConfig().enabled, onToggle = function(enabled) GetConfig().enabled = enabled; Refresh(); SyncDim() end },
		})
		BUI.Bloodlust.onPreviewStop = function() titleHolder.previewToggle:SetValue(false) end

		local host = CreateFrame('Frame', nil, pageFrame)
		host:SetPoint('TOPLEFT', pageFrame, 'TOPLEFT', 0, -(PageKit.PAD + titleHeight))
		host:SetPoint('BOTTOMRIGHT', pageFrame, 'BOTTOMRIGHT', 0, 0)
		local page = Layout.Page(host, nil, width)
		local tab = page:GetTab(1)
		tab.topPadding = 0

		local grid
		local function Section(title)
			Layout.Section(tab, title)
			grid = PageKit.RowGrid(tab)
			grids[#grids + 1] = grid
		end

		local function Row(config)
			config.spanFull = true
			return grid:Add(config)
		end

		Section('Display')
		Row({
			title = 'Text',
			description = 'Font, size, icon and position.',
			controlWidth = 170,
			control = function(row) return Controls.Dropdown(row, nil, fonts, GetConfig().font, bind('font'), nil, 160) end,
			accessoryWidth = 60,
			accessories = function(row)
				return {
					Cog(row, 'TEXT', 'Size & icon', {
						Option('slider', 'Font Size', 'fontSize', { min = 8, max = 48 }),
						Option('checkbox', 'Show Icon', 'showIcon'),
						Option('slider', 'Icon Size', 'iconSize', { min = 12, max = 64 }),
					}),
					BUI.AlertMover(row, GetConfig(), Refresh),
				}
			end,
		})

		Section('Alerts')
		Row({
			title = 'Used',
			description = 'Announcement when someone pops Bloodlust, and the sound to play.',
			controlWidth = 170,
			control = function(row) return SoundDropdown(row, 'soundOnUsed') end,
			accessoryWidth = 66,
			accessories = function(row)
				return {
					Cog(row, 'USED', 'Text, timing & speech', {
						Option('textbox', 'Text', 'usedFormat'),
						Option('slider', 'Hold Seconds', 'usedHoldDuration', { min = 0.5, max = 10, step = 0.5 }),
						Option('checkbox', 'Flash', 'flashOnUsed'),
						Option('slider', 'Flash Seconds', 'flashDuration', { min = 0.2, max = 5, step = 0.1 }),
						Option('checkbox', 'Speak', 'ttsOnUsed'),
						Option('textbox', 'Speak Text', 'ttsUsedText'),
					}),
					Swatch(row, 'usedColor'),
				}
			end,
		})
		Row({
			title = 'Available',
			description = 'Alert when Bloodlust comes off cooldown, and the sound to play.',
			controlWidth = 170,
			control = function(row) return SoundDropdown(row, 'soundOnReady') end,
			accessoryWidth = 66,
			accessories = function(row)
				return {
					Cog(row, 'AVAILABLE', 'Text, timing & speech', {
						Option('textbox', 'Text', 'readyFormat'),
						Option('slider', 'Hold Seconds', 'readyHoldDuration', { min = 0.5, max = 10, step = 0.5 }),
						Option('checkbox', 'Keep On Screen', 'showWhenReady'),
						Option('checkbox', 'Flash', 'flashOnReady'),
						Option('slider', 'Flash Seconds', 'flashReadyDuration', { min = 0.2, max = 5, step = 0.1 }),
						Option('checkbox', 'Speak', 'ttsOnReady'),
						Option('textbox', 'Speak Text', 'ttsReadyText'),
					}),
					Swatch(row, 'readyColor'),
				}
			end,
		})

		Section('Countdowns')
		Row({
			title = 'Active',
			description = 'Live timer while the buff runs.',
			checked = GetConfig().showWhenActive,
			callback = bind('showWhenActive'),
			accessoryWidth = 66,
			accessories = function(row)
				return {
					Cog(row, 'ACTIVE', 'Text', {
						Option('textbox', 'Text', 'activeFormat'),
					}),
					Swatch(row, 'activeColor'),
				}
			end,
		})
		Row({
			title = 'On Cooldown',
			description = 'Live timer until Bloodlust is ready, with an optional warning before.',
			checked = GetConfig().showWhenCD,
			callback = bind('showWhenCD'),
			accessoryWidth = 66,
			accessories = function(row)
				return {
					Cog(row, 'ON COOLDOWN', 'Text & warning', {
						Option('textbox', 'Text', 'cdFormat'),
						Option('slider', 'Warn Seconds Before', 'warnBeforeReady', { min = 0, max = 60 }),
						SoundOption('Warn Sound', 'soundOnWarn'),
						Option('checkbox', 'Speak Warning', 'ttsOnWarn'),
						Option('textbox', 'Warning Text', 'ttsWarnText'),
					}),
					Swatch(row, 'cdColor'),
				}
			end,
		})

		SyncDim()
		page:AutoRefresh()
	end,
	OnHide = StopPreview,
})
