local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Retained = BUILib.R
local Widget = BUILib.Widget

local function frameOf(control)
	local frame = Widget.Unwrap(control)
	return frame
end

function Retained.Legacy(name)
	local typeName = "@" .. name
	if Retained.types[typeName] then return typeName end
	Retained.Define(typeName, {
		frameType = "Frame",

		Bind = function(self)
			local props = self.props

			local stale = props.rebuildKey ~= nil and props.rebuildKey ~= self._builtKey
			if not self._ctrl or stale then
				if self._ctrl and self._ctrlFrame then
					self._ctrlFrame:Hide()
					self._ctrlFrame:SetParent(Retained.holdingFrame)
				end
				Retained._legacyCreated = (Retained._legacyCreated or 0) + 1
				if props.make then
					self._ctrl = props.make(self.frame)
				else
					self._ctrl = BUILib.Controls[name](self.frame, unpack(props.args or {}))
				end
				self._ctrlFrame = frameOf(self._ctrl)
				if self._ctrlFrame and not self._ctrlFrame:GetPoint() then
					self._ctrlFrame:SetPoint("TOPLEFT")
				end
				self._builtKey = props.rebuildKey
			end
			local frame = self._ctrlFrame
			if frame and frame.GetHeight then
				self.frame:SetSize(math.max(1, frame:GetWidth() or 1), math.max(1, frame:GetHeight() or 1))
			end
			if props.update then props.update(self._ctrl) end

			local control = self._ctrl
			if control and (control.Refresh or (type(control) == "table" and control.content and control.content.Refresh)) then
				self:DeferGuarded(function()
					local node = self
					local controlFrame = node._ctrlFrame
					if not controlFrame or not controlFrame.GetHeight then return end
					local before = controlFrame:GetHeight() or 0
					local target = control.Refresh and control or control.content
					if target and target.Refresh then target:Refresh() end
					local after = controlFrame:GetHeight() or before
					if math.abs(after - before) >= 0.5 then
						node.frame:SetSize(math.max(1, controlFrame:GetWidth() or 1), math.max(1, after))
						BUILib.R.Reconcile.Relayout(node.frame:GetParent())
					end
				end)
			end
		end,

		Reset = function(self)
			if self._ctrlFrame then
				self._ctrlFrame:Hide()
				self._ctrlFrame:SetParent(Retained.holdingFrame)
			end
			self._ctrl = nil
			self._ctrlFrame = nil
			self._builtKey = nil
		end,
	})
	return typeName
end
