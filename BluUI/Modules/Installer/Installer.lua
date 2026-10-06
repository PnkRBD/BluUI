local _, BUI = ...

local Installer = {}
BUI.Installer = Installer

local GLASS_UF = {
	transparentHealth = true, healthBarAlpha = 0.35,
	classColorHealth = true, classColorPower = true,
	bgColor = { 0.05, 0.05, 0.06, 0.55 },
}
local SOLID_UF = {
	transparentHealth = false, healthBarAlpha = 1,
	classColorHealth = true, classColorPower = true,
	bgColor = { 0.1, 0.1, 0.1, 0.8 },
}
local DARK_GLASS_UF = {
	transparentHealth = true, healthBarAlpha = 0.85,
	classColorHealth = false, classColorPower = false,
	healthColor = { 0, 0, 0, 1 },
	bgColor = { 1, 1, 1, 1 },
}
local DARK_SOLID_UF = {
	transparentHealth = false, healthBarAlpha = 1,
	classColorHealth = false, classColorPower = false,
	healthColor = { 0, 0, 0, 1 },
	bgColor = { 1, 1, 1, 1 },
}
local GROUP_UNITS = { 'party', 'raid' }

Installer.FRAME_STYLES = {
	{ key = 'classglass', name = 'Class Glass', dark = false, glass = true, uf = GLASS_UF, tip = 'Class-colored glass bars' },
	{ key = 'classsolid', name = 'Class Solid', dark = false, glass = false, uf = SOLID_UF, tip = 'Class-colored solid bars' },
	{ key = 'darkglass', name = 'Dark Glass', dark = true, glass = true, uf = DARK_GLASS_UF, tip = 'Black glass bars on white, no class coloring' },
	{ key = 'darksolid', name = 'Dark Solid', dark = true, glass = false, uf = DARK_SOLID_UF, tip = 'Black solid bars on white, no class coloring' },
}

local function Copy(value)
	if type(value) == 'table' then return { value[1], value[2], value[3], value[4] } end
	return value
end

function Installer.AppliedStyle()
	local key = BUI.db.global.installerFrameStyle
	for _, style in ipairs(Installer.FRAME_STYLES) do
		if style.key == key then return style end
	end
end

function Installer.MatchesGroupFrames()
	return BUI.db.global.installerMatchGroups
end

function Installer.SetMatchGroupFrames(enabled)
	BUI.db.global.installerMatchGroups = enabled
end

function Installer.SyncGroupFrames()
	if not BUI.db.global.installerMatchGroups then return end
	local unitFrames = BUI.GetDB().unitFrames
	local groupFrames = BUI.GroupFrames.GetDB()
	for _, unit in ipairs(GROUP_UNITS) do
		local settings = groupFrames[unit]
		settings.transparentHealth = unitFrames.transparentHealth
		settings.healthOpacity = BUI.Round(unitFrames.healthBarAlpha * 100)
		settings.useClassColor = unitFrames.classColorHealth
		settings.healthColor = Copy(unitFrames.healthColor)
		settings.bgColor = Copy(unitFrames.bgColor)
		settings.absorb.color = Copy(unitFrames.shieldColor)
		settings.healAbsorb.color = Copy(unitFrames.healAbsorbColor)
	end
	BUI.GroupFrames.Refresh()
end

function Installer.ApplyFrameStyle(style)
	local unitFrameSettings = BUI.GetDB().unitFrames
	for key, value in pairs(style.uf) do unitFrameSettings[key] = Copy(value) end
	BUI.db.global.installerFrameStyle = style.key
	Installer.SyncGroupFrames()
	BUI.ExportImport.RefreshAllModules()
end

function Installer.Open()
	BUI.Events:AfterCombat(function()
		if BUI.PageEngine.EnsureLoaded() then BUI.OptionsWindow.Open('setup') end
	end, 'Installer.Open')
end
