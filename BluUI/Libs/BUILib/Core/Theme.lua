local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end

local Theme = BUILib.Theme or {}
BUILib.Theme = Theme
BUILib.Colors = Theme

Theme.font = BUILib.Font
Theme.fontSize = BUILib.FONT_SIZE
Theme.controlHeight = BUILib.CONTROL_HEIGHT

Theme.bg = {
	dark   = {0.025, 0.03, 0.035, 0.98},
	medium = {0.035, 0.04, 0.045, 0.98},
	light  = {0.05, 0.055, 0.06, 0.98},
	panel  = {0.025, 0.03, 0.035, 0.98},
	card   = {0.045, 0.050, 0.058, 0.85},
	input  = {0.074, 0.08, 0.086, 1},
	hover  = {0.08, 0.085, 0.09, 1},
}

Theme.sidebar = {
	bg       = {0.025, 0.03, 0.035, 0.98},
	hover    = {0.05, 0.055, 0.06, 0.98},
	selected = {0.06, 0.065, 0.07, 0.98},
}

Theme.border = {
	dark    = {0.055, 0.06, 0.065, 1},
	default = {0.111, 0.12, 0.129, 1},
	light   = {0.166, 0.18, 0.194, 1},
	hover   = {0.231, 0.25, 0.269, 1},
	input   = {0.138, 0.15, 0.162, 1},
}

Theme.text = {
	primary   = {1, 1, 1, 1},
	secondary = {0.7, 0.7, 0.7, 1},
	muted     = {0.5, 0.5, 0.5, 1},
	disabled  = {0.35, 0.35, 0.35, 1},
	label     = {0.9, 0.9, 0.9, 1},
}

Theme.button = {
	normal  = {0.02, 0.022, 0.026, 1},
	hover   = {0.08, 0.085, 0.09, 0.98},
	pressed = {0.014, 0.016, 0.019, 1},
}

Theme.scrollbar = {
	track      = {0.06, 0.065, 0.07, 0},
	thumb      = {0.415, 0.45, 0.485, 1},
	thumbHover = {0.508, 0.55, 0.592, 1},
	border     = {0.415, 0.45, 0.485, 0},
}

Theme.control = {
	ring       = {0.277, 0.3, 0.323, 1},
	disabled   = {0.092, 0.1, 0.108, 1},
	track      = {0.138, 0.15, 0.162, 1},
	trackOff   = {0.185, 0.2, 0.215, 1},
}

local defaultAccent = {0.45, 0.85, 0.65, 1}

function Theme.GetDBGetter()
	local client = BUILib.GetActiveClient()
	return (client and client.getDB)
end

function Theme.GetAccent()
	local dbGetter = Theme.GetDBGetter()
	if dbGetter then
		local db = dbGetter()
		if db and db.general then
			if db.general.useClassColorTheme == true then
				local _, class = UnitClass("player")
				if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
					local color = RAID_CLASS_COLORS[class]
					return color.r, color.g, color.b, 1
				end
			end
			local themeColor = db.general.themeColor
			if themeColor then
				if themeColor[1] and themeColor[2] and themeColor[3] then return themeColor[1], themeColor[2], themeColor[3], themeColor[4] or 1
				elseif themeColor.r and themeColor.g and themeColor.b then return themeColor.r, themeColor.g, themeColor.b, themeColor.a or 1 end
			end
		end
	end
	return defaultAccent[1], defaultAccent[2], defaultAccent[3], defaultAccent[4]
end

Theme.__accentRegistry = Theme.__accentRegistry or setmetatable({}, {__mode = "k"})
local accentRegistry = Theme.__accentRegistry

function Theme.RegisterAccentElement(element, updateFunc)
	if element then accentRegistry[element] = { fn = updateFunc, client = BUILib.GetActiveClient() } end
end

function Theme.RefreshAccent()
	for element, entry in pairs(accentRegistry) do
		if element and entry and element.GetParent and element:GetParent() then
			local previousClient = BUILib.SetActiveClient(entry.client)
			local red, green, blue, alpha = Theme.GetAccent()
			entry.fn(element, red, green, blue, alpha)
			BUILib.SetActiveClient(previousClient)
		else
			accentRegistry[element] = nil
		end
	end
end
