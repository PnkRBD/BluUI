local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local PageKit = BUILib.PageKit

function PageKit.DbRGB(parent, db, prefix, applyFn, label)
	return Controls.ColorSwatch(parent, { r = db[prefix .. "R"] or 1, g = db[prefix .. "G"] or 1, b = db[prefix .. "B"] or 1, a = 1, callback = function(red, green, blue)
		db[prefix .. "R"], db[prefix .. "G"], db[prefix .. "B"] = red, green, blue; applyFn()
	end, tooltip = label })
end

function PageKit.DbRGBA(parent, db, prefix, applyFn, label)
	return Controls.ColorSwatch(parent, { r = db[prefix .. "R"] or 1, g = db[prefix .. "G"] or 1, b = db[prefix .. "B"] or 1, a = db[prefix .. "A"] or 1, callback = function(red, green, blue, alpha)
		db[prefix .. "R"], db[prefix .. "G"], db[prefix .. "B"], db[prefix .. "A"] = red, green, blue, alpha; applyFn()
	end, tooltip = label })
end

