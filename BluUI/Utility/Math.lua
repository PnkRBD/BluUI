local _, BUI = ...
local math_floor = math.floor
local math_abs   = math.abs
local format     = string.format

function BUI.Round(value)
	return value >= 0 and math_floor(value + 0.5) or -math_floor(-value + 0.5)
end

function BUI.ApproxEqual(valueA, valueB, epsilon)
	return math_abs(valueA - valueB) < (epsilon or 0.001)
end

function BUI.Hex(red, green, blue)
	return format('%02x%02x%02x',
		math_floor(red * 255 + 0.5),
		math_floor(green * 255 + 0.5),
		math_floor(blue * 255 + 0.5))
end

function BUI.UnpackColor(color, defaultRed, defaultGreen, defaultBlue, defaultAlpha)
	if type(color) == 'table' then
		return color[1] or defaultRed or 1, color[2] or defaultGreen or 1,
		       color[3] or defaultBlue or 1, color[4] or defaultAlpha or 1
	end
	return defaultRed or 1, defaultGreen or 1, defaultBlue or 1, defaultAlpha or 1
end
