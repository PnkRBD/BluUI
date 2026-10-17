local BUI = BluUI
local BUILib = BUI.BUILibClient

local MENU_WIDTH = 150

local Kit = {}
BUI.OptionsKit = Kit

function Kit.Window()
	return BUI.PageEngine.window
end

function Kit.Repaint()
	BUI.PageEngine.window:Repaint()
end

function Kit.RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

function Kit.RebuildPane(page)
	BUILib.Defer(function() page:RebuildCurrent() end)
end

local function On(value) return value == true end
local function Off(value) return value ~= false end

local function Read(read, value)
	if read then return read(value) end
	return value
end

function Kit.Setting(db, label, key, read, extra)
	local option = { label = label }
	option.get = function() return Read(read, db[key]) end
	option.set = function(value)
		db[key] = value
		if option.onChange then option.onChange() end
	end
	local factory = BUI.FactoryOf(db)
	if factory then option.default = function() return Read(read, factory[key]) end end
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

function Kit.Option(db, label, key, extra)
	return Kit.Setting(db, label, key, nil, extra)
end

function Kit.Toggle(db, label, key, extra)
	return Kit.Setting(db, label, key, On, extra)
end

function Kit.OnUnlessOff(db, label, key, extra)
	return Kit.Setting(db, label, key, Off, extra)
end

function Kit.Menu(db, key, entries, width)
	return Kit.Option(db, nil, key, { entries = entries, width = width or MENU_WIDTH })
end

function Kit.Color(db, label, key, extra)
	local swatch = { kind = 'swatch', label = label, tooltip = label, opacity = true }
	swatch.get = function()
		local color = db[key]
		return color[1], color[2], color[3], color[4] or 1
	end
	swatch.set = function(red, green, blue, alpha)
		db[key] = { red, green, blue, alpha }
		if swatch.onChange then swatch.onChange() end
	end
	local factory = BUI.FactoryOf(db)
	if factory then
		swatch.default = function()
			local color = factory[key]
			if color then return color[1], color[2], color[3], color[4] or 1 end
		end
	end
	for name, value in pairs(extra or {}) do swatch[name] = value end
	return swatch
end

function Kit.TableColor(db, label, key, opacity)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = opacity,
		get = function()
			local color = db[key]
			return color.r, color.g, color.b, opacity and color.a or 1
		end,
		set = function(red, green, blue, alpha)
			db[key] = opacity and { r = red, g = green, b = blue, a = alpha } or { r = red, g = green, b = blue }
		end,
	}
end

function Kit.Eye(tooltip, get, set)
	return { icon = 'eye', tooltip = tooltip, get = get, set = function(value)
		set(value)
		Kit.Repaint()
	end }
end
