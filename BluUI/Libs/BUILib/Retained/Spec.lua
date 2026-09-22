local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Retained = BUILib.R

local Spec = {}
Retained.Spec = Spec


local warnedKeylessTypes = {}

function Spec.KeyOf(node, index)
	if node.key ~= nil then return node.type .. "\0" .. tostring(node.key) end
	return node.type .. "\0#" .. index
end

function Spec.Validate(node, index)
	if type(node) ~= "table" then
		error("BUILib.R.Spec: child #" .. index .. " is not a table", 3)
	end
	if not node.type then
		error("BUILib.R.Spec: child #" .. index .. " has no `type`", 3)
	end
	if not Retained.types[node.type] then
		error("BUILib.R.Spec: child #" .. index .. " type '" .. tostring(node.type) .. "' is not registered", 3)
	end
end
