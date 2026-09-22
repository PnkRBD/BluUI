local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Retained = BUILib.R
local Widget = BUILib.Widget

function Retained.Define(name, class)
	class.__kind = name
	Retained.types[name] = class
	return class
end

