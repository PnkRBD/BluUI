local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Retained = BUILib.R
local Pool = Retained.Pool
local Spec = Retained.Spec

local Reconcile = {}
Retained.Reconcile = Reconcile

local function mountOf(frame)
	local mount = frame._bui3mount
	if not mount then mount = { childrenByKey = {} }; frame._bui3mount = mount end
	return mount
end

local function defaultLayout(parentFrame, ordered, specs)
	local parentNode = parentFrame._bui3node
	if parentNode and parentNode.class.Layout then
		parentNode.class.Layout(parentNode, ordered, specs)
		return
	end
	local y = 0
	for index = 1, #ordered do
		local frame = ordered[index].frame
		local props = specs[index].props
		y = y + (props and props.topMargin or 0)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT",  parentFrame, "TOPLEFT",  0, -y)
		frame:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, -y)
		y = y + (frame:GetHeight() or 0) + (props and props.gap or 0)
	end
	parentFrame._bui3contentHeight = y

	if parentFrame.SetHeight then parentFrame:SetHeight(math.max(1, y)) end
end

function Reconcile.Children(parentFrame, childSpecs)
	local mount = mountOf(parentFrame)
	local old   = mount.childrenByKey
	local nextByKey = {}
	local ordered   = {}

	for specIndex = 1, #childSpecs do
		local spec = childSpecs[specIndex]
		Spec.Validate(spec, specIndex)
		local key = Spec.KeyOf(spec, specIndex)
		local claimed = nextByKey[key]
		local node

		if claimed then
			node = claimed.node
			node:Bind(spec)
			claimed.spec = spec
		else
			local existing = old[key]
			if existing then
				node = existing.node
				node:Bind(spec)
				existing.spec = spec
				nextByKey[key] = existing
				old[key] = nil
			else
				node = Pool.Acquire(spec.type, parentFrame, spec)
				nextByKey[key] = { node = node, spec = spec }
			end
		end

		ordered[specIndex] = node
		if spec.children then Reconcile.Children(node.frame, spec.children) end
	end

	for _, leftover in pairs(old) do
		Pool.Release(leftover.node)
	end

	mount.childrenByKey = nextByKey
	mount.order = ordered
	mount.orderedSpecs = childSpecs
	defaultLayout(parentFrame, ordered, childSpecs)
	return ordered
end

function Reconcile.Relayout(parentFrame)
	while parentFrame do
		local mount = parentFrame._bui3mount
		if mount and mount.order and mount.orderedSpecs then
			defaultLayout(parentFrame, mount.order, mount.orderedSpecs)
		end
		parentFrame = parentFrame:GetParent()
	end
end

