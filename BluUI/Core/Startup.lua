local _, BUI = ...
local Modals = BUI.Modals

do
	local queue = {}
	local active = false

	local function RunNext()
		local check = table.remove(queue, 1)
		active = check ~= nil
		if not check then return end
		local finished = false
		check(function()
			if finished then return end
			finished = true
			RunNext()
		end)
	end

	function BUI.QueueStartupCheck(check)
		queue[#queue + 1] = check
		if not active then RunNext() end
	end
end

function BUI.CheckPlatynatorPrompt(done)
	if not C_AddOns.IsAddOnLoaded('Platynator') then done(); return end

	local global = BUI.db.global
	local bundledDate = BUI.PlatynatorProfileDate
	if global.platynatorImportedDate  == bundledDate then done(); return end
	if global.platynatorDismissedDate == bundledDate then done(); return end

	local overlay, dialog, close = Modals.CreateBase(440, 170, false)
	overlay:HookScript('OnHide', done)

	Modals.CreateTitle(dialog, 'Platynator Detected')
	Modals.CreateMessage(dialog,
		'Recommended: Import the BluUI Platynator profile.\n'
		.. 'Last updated: ' .. bundledDate
	)

	Modals.LayoutButtons(dialog, {
		{
			text  = 'Import Profile',
			color = Modals.BTN_CONFIRM,
			width = 120,
			onClick = function(dismiss)
				BUI.ImportPlatynatorProfile()
				dismiss()
			end,
		},
		{
			text  = "Don't Show Again",
			color = Modals.BTN_WARNING,
			width = 130,
			onClick = function(dismiss)
				global.platynatorDismissedDate = bundledDate
				dismiss()
			end,
		},
		{
			text  = 'Cancel',
			color = Modals.BTN_CANCEL,
			width = 80,
		},
	}, close)

	overlay:Show()
end
