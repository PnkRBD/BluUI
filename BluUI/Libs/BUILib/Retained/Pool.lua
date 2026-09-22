local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Retained = BUILib.R

local Pool = {}
Retained.Pool = Pool

Pool._free   = {}
Pool._active = setmetatable({}, { __mode = "k" })

function Pool.Acquire(kind, parentFrame, spec)
	local widgetClass = Retained.types[kind]
	if not widgetClass then
		error("BUILib.R.Pool: no widget type registered for '" .. tostring(kind) .. "'", 2)
	end
	local freeList = Pool._free[kind]
	local node
	if freeList and #freeList > 0 then
		node = freeList[#freeList]
		freeList[#freeList] = nil
	else
		node = Retained.NewNode(widgetClass, parentFrame)
	end
	Pool._active[node] = true
	node:Acquire(parentFrame, spec)
	return node
end

function Pool.Release(node)
	if not node or not Pool._active[node] then return end
	Pool._active[node] = nil
	node:Teardown()
	local kind = node.class.__kind
	local freeList = Pool._free[kind]
	if not freeList then freeList = {}; Pool._free[kind] = freeList end
	freeList[#freeList + 1] = node
end

Pool.ReleaseTree = Pool.Release

