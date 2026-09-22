local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('ActionBars.BlizzardBar')

local ActionBars = BUI.ActionBars

local BlizzardBar = {}
BlizzardBar.__index = BlizzardBar

function ActionBars.NewBlizzardBar(spec)
	return setmetatable({
		key = spec.key,
		headerName = spec.headerName,
		Frame = spec.frame,
		Retake = spec.retake,
		Release = spec.release,
		InstallHooks = spec.installHooks,
		applying = false,
		hooked = false,
		hideHooked = false,
	}, BlizzardBar)
end

function BlizzardBar:Settings()
	return ActionBars.GetBarSettings(self.key)
end

function BlizzardBar:Hidden()
	return self:Settings().hidden and BUI.IsModuleEnabled('actionBars')
end

function BlizzardBar:Enabled()
	local barSettings = self:Settings()
	return barSettings.enabled and not barSettings.hidden and BUI.IsModuleEnabled('actionBars')
end

function BlizzardBar:Owned()
	local frame = self.Frame()
	return self.bar ~= nil and frame ~= nil and frame:GetParent() == self.bar.header
end

function BlizzardBar:Active()
	return self.bar ~= nil and not self.applying and self:Enabled()
end

function BlizzardBar:Apply(task)
	self.applying = true
	task()
	self.applying = false
end

function BlizzardBar:SyncHover()
	local frame = self.Frame()
	if not self.bar or not frame then return end
	local frames = { frame:GetChildren() }
	frames[#frames + 1] = frame
	ActionBars.HookFadeFrames(self.bar, frames)
end

function BlizzardBar:EnsureBar()
	if not self.bar then
		self.bar = ActionBars.RegisterBar({
			key = self.key,
			kind = 'blizzard',
			label = ActionBars.BarLabel(self.key),
			header = ActionBars.CreateHeader(self.headerName, false),
			buttons = {},
		})
	end
	return self.bar
end

function BlizzardBar:ReleaseFrame()
	if not self:Owned() then return end
	self.Release(self)
	self.bar.header:Hide()
	if self.bar.mouseEnabled == false then
		for _, child in ipairs({ self.Frame():GetChildren() }) do child:EnableMouse(true) end
	end
	self.bar.mouseEnabled = nil
	self.bar.mouseState = nil
end

function BlizzardBar:Refresh()
	local frame = self.Frame()
	if not frame then return end
	if self:Hidden() then
		self:ReleaseFrame()
		if not self.hideHooked then
			self.hideHooked = true
			HookScript(frame, 'OnShow', function(shown)
				if self:Hidden() then shown:Hide() end
			end)
		end
		frame:Hide()
		return
	end
	if self.hideHooked and not frame:IsShown() then frame:Show() end
	if not self:Enabled() then
		self:ReleaseFrame()
		return
	end
	self:EnsureBar()
	if not self.hooked then
		self.hooked = true
		self.InstallHooks(self)
	end
	self.Retake(self)
	self:SyncHover()
	ActionBars.ApplyBarMouse(self.bar, { frame:GetChildren() })
end
