local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Retained = BUILib.R
local Theme = BUILib.Theme

local WidgetMethods = {}

local EMPTY = {}

local function nodeIndex(self, key)
	local method = WidgetMethods[key]
	if method ~= nil then return method end
	local class = rawget(self, "class")
	if class then
		local classMethod = class[key]
		if classMethod ~= nil then return classMethod end
	end
	local frame = rawget(self, "frame")
	if not frame then return nil end
	local value = frame[key]
	if value == nil then return nil end
	if type(value) == "function" then
		local wrapper = function(_, ...) return value(frame, ...) end
		rawset(self, key, wrapper)
		return wrapper
	end
	return value
end

local NodeMT = { __index = nodeIndex }
Retained.NodeMT = NodeMT

function Retained.NewNode(class, parentFrame)
	local node = setmetatable({}, NodeMT)
	node.class    = class
	node._gen     = 0
	local frame = CreateFrame(class.frameType or "Frame", nil, Retained.holdingFrame, class.template)
	node.frame = frame
	frame._bui3node = node
	Retained._framesCreated = Retained._framesCreated + 1
	if class.Build then class.Build(node) end
	return node
end

function WidgetMethods:Acquire(parentFrame, spec)
	local frame = self.frame
	self.__client = BUILib.ClientOf(parentFrame) or BUILib.GetActiveClient()
	frame.__bui3client = self.__client
	frame:SetParent(parentFrame)
	frame:Show()
	self:Bind(spec)
end

function WidgetMethods:Bind(spec)
	self.spec  = spec
	self.props = spec.props or EMPTY
	self.key   = spec.key
	self.get   = spec.get
	self.set   = spec.set
	if self.class.Bind then self.class.Bind(self) end
end

function WidgetMethods:Teardown()
	local mount = self.frame._bui3mount
	if mount then
		for _, child in pairs(mount.childrenByKey) do Retained.Pool.Release(child.node) end
		self.frame._bui3mount = nil
	end
	if self.class.Reset then self.class.Reset(self) end
	local frame = self.frame
	frame:Hide()
	frame:ClearAllPoints()
	frame:SetParent(Retained.holdingFrame)
	frame.__bui3client = nil
	self.spec, self.props, self.key, self.get, self.set, self.__client = nil, nil, nil, nil, nil, nil
	self._gen = self._gen + 1
end

function WidgetMethods:SetEnabled(enabled)
	self._enabled = enabled
	if self._onEnable then self._onEnable(enabled) end
end
function WidgetMethods:IsEnabled() return self._enabled end

function WidgetMethods:Font() return BUILib.GetFont() end
function WidgetMethods:Theme() return Theme end

function WidgetMethods:DeferGuarded(callback)
	local generation = self._gen
	if BUILib.Defer then
		BUILib.Defer(function() if self._gen == generation then callback() end end)
	else
		callback()
	end
end
