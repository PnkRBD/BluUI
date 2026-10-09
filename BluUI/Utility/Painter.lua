local _, BUI = ...

local Painter = {}
BUI.Painter = Painter

local roles, kinds = {}, {}
local listeners = {}

local function Color(role)
	return BUI.ThemeColor(role)
end
Painter.Color = Color

local APPLY = {
	fill = function(region, role) region:SetColorTexture(Color(role)) end,
	tint = function(region, role) region:SetVertexColor(Color(role)) end,
	text = function(region, role) region:SetTextColor(Color(role)) end,
	custom = function(region, apply) apply(region) end,
}

local function Register(region, kind, role)
	roles[region], kinds[region] = role, kind
	APPLY[kind](region, role)
	return region
end

function Painter.Fill(texture, role) return Register(texture, 'fill', role) end
function Painter.Tint(region, role) return Register(region, 'tint', role) end
function Painter.Text(region, role) return Register(region, 'text', role) end
function Painter.Custom(region, apply) return Register(region, 'custom', apply) end

function Painter.OnRepaint(name, callback)
	listeners[name] = callback
end

function Painter.Repaint()
	for _, callback in pairs(listeners) do callback() end
	for region, role in pairs(roles) do APPLY[kinds[region]](region, role) end
end
