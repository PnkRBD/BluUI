local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Controls, Modals = BUILib.Controls, BUILib.Modals

local WIDTH, HEIGHT = 1000, 680
local PAD = 24
local LIST_TOP = 112
local LIST_BOTTOM = 70
local LINE_HEIGHT = 15
local FONT_SIZE = 11
local TABS = {
	{ text = 'Timeline', key = 'timeline' },
	{ text = 'Ran more than once', key = 'repeats' },
	{ text = 'Never ran', key = 'never' },
}

local function Plain(line)
	return (line:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''))
end

function BUI.ShowLaunchTrace(report)
	local overlay, dialog, Close = Modals.CreateBase(WIDTH, HEIGHT, false)
	Modals.CreateTitle(dialog, 'Launch trace')
	Modals.CreateMessage(dialog, report.summary .. '  Recorded ' .. report.saved .. '.')

	local listWidth = WIDTH - PAD * 2
	local listHeight = HEIGHT - LIST_TOP - LIST_BOTTOM
	local scroll = Controls.ScrollFrame(dialog, listWidth, listHeight)
	scroll:SetPoint('TOPLEFT', PAD, -LIST_TOP)

	local pool = {}
	local current = TABS[1].key
	local function ShowLines(key)
		current = key
		local lines = report[key]
		for index, line in ipairs(lines) do
			local text = pool[index]
			if not text then
				text = scroll.child:CreateFontString(nil, 'OVERLAY')
				text:SetFont(BUILib.Font, FONT_SIZE, '')
				text:SetPoint('TOPLEFT', 8, -(index - 1) * LINE_HEIGHT - 6)
				text:SetJustifyH('LEFT')
				text:SetWordWrap(false)
				text:SetTextColor(0.85, 0.85, 0.88)
				pool[index] = text
			end
			text:SetText(line)
			text:Show()
		end
		for index = #lines + 1, #pool do pool[index]:Hide() end
		scroll:SetChildHeight(#lines * LINE_HEIGHT + 12)
		scroll:ScrollToTop()
	end

	local tabs = Controls.TabLineBar(dialog, TABS, 1, function(_, tab) ShowLines(tab.key) end, listWidth)
	tabs:SetPoint('BOTTOMLEFT', scroll, 'TOPLEFT', 0, 4)
	ShowLines(current)

	overlay:SetScript('OnKeyDown', function(self, key)
		self:SetPropagateKeyboardInput(key ~= 'ESCAPE')
		if key == 'ESCAPE' then Close() end
	end)
	Modals.LayoutButtons(dialog, {
		{ text = 'Close', color = Modals.BTN_CONFIRM },
		{ text = 'Copy this tab', color = Modals.BTN_NEUTRAL, onClick = function()
			local plain = {}
			for index, line in ipairs(report[current]) do plain[index] = Plain(line) end
			local copy = Modals.Copy({ title = 'Launch trace', message = 'The whole tab is selected. Press Ctrl+C to copy it.', text = table.concat(plain, ' || '), fullscreen = true })
			copy:SetFrameLevel(overlay:GetFrameLevel() + 50)
		end },
		{ text = 'Trace again', color = Modals.BTN_NEUTRAL, onClick = function() BUI.LaunchTrace.Start() end },
	}, Close)
	overlay:Show()
end
