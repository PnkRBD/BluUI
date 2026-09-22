local _, BUI = ...

local format = string.format
local floor  = math.floor

local TimeFormat = {}
BUI.TimeFormat = TimeFormat

local NS_MMSS = 1000000
local NS_HOUR = 2000000
local NS_DAY  = 3000000

function TimeFormat.Bucket(seconds, decimalThreshold)
	if seconds < 0 then return 0 end
	if decimalThreshold and decimalThreshold > 0 and seconds < decimalThreshold then
		return -1 - floor(seconds * 10)
	end
	local total = floor(seconds)
	if total < 60    then return total end
	if total < 3600  then return NS_MMSS + total end
	if total < 86400 then return NS_HOUR + floor(total / 3600) end
	return NS_DAY + floor(total / 86400)
end

function TimeFormat.Format(seconds, decimalThreshold)
	if seconds < 0 then seconds = 0 end
	if decimalThreshold and decimalThreshold > 0 and seconds < decimalThreshold then
		return format("%.1f", floor(seconds * 10) * 0.1)
	end
	local total = floor(seconds)
	if total < 60    then return tostring(total) end
	if total < 3600  then return format("%d:%02d", floor(total / 60), total % 60) end
	if total < 86400 then return format("%dh", floor(total / 3600)) end
	return format("%dd", floor(total / 86400))
end

local DOWN = Enum.NumericRuleFormatRounding.Down
local formatters = {}

local function Segment(threshold, fmt, step, components)
	return { threshold = threshold, format = fmt, rounding = DOWN, step = step, components = components }
end

local function Build(decimalThreshold, warnThreshold, warnHex)
	local segments = {}
	if decimalThreshold > 0 then
		segments[#segments + 1] = Segment(0, "%.1f", 0.1)
		segments[#segments + 1] = Segment(decimalThreshold, "%d", 1)
	else
		segments[#segments + 1] = Segment(0, "%d", 1)
	end
	segments[#segments + 1] = Segment(60,    "%d:%02d", 1, { { div = 60 }, { mod = 60 } })
	segments[#segments + 1] = Segment(3600,  "%dh",     1, { { div = 3600 } })
	segments[#segments + 1] = Segment(86400, "%dd",     1, { { div = 86400 } })

	if warnThreshold > 0 and warnHex then
		local split = {}
		for index = 1, #segments do
			local segment = segments[index]
			local nextThreshold = segments[index + 1] and segments[index + 1].threshold or math.huge
			if segment.threshold < warnThreshold then
				split[#split + 1] = Segment(segment.threshold, "|c" .. warnHex .. segment.format .. "|r", segment.step, segment.components)
				if warnThreshold < nextThreshold then
					split[#split + 1] = Segment(warnThreshold, segment.format, segment.step, segment.components)
				end
			else
				split[#split + 1] = segment
			end
		end
		segments = split
	end

	local formatter = C_StringUtil.CreateNumericRuleFormatter()
	formatter:SetBreakpoints(segments)
	return formatter
end

function TimeFormat.ColorHex(color)
	if not color then return nil end
	return format("ff%02x%02x%02x", floor((color[1] or 1) * 255 + 0.5), floor((color[2] or 1) * 255 + 0.5), floor((color[3] or 1) * 255 + 0.5))
end

function TimeFormat.GetFormatter(decimalThreshold, warnThreshold, warnColor)
	decimalThreshold = decimalThreshold or 0
	warnThreshold = warnThreshold or 0
	local warnHex = warnThreshold > 0 and TimeFormat.ColorHex(warnColor) or nil
	if not warnHex then warnThreshold = 0 end
	local key = decimalThreshold .. ":" .. warnThreshold .. ":" .. (warnHex or "")
	local formatter = formatters[key]
	if not formatter then
		formatter = Build(decimalThreshold, warnThreshold, warnHex)
		formatters[key] = formatter
	end
	return formatter
end
