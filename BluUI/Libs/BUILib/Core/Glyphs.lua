local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Widget = BUILib.Widget

local FILL = 30 / 32
local EDGE = "CLAMPTOBLACKADDITIVE"
local BOUNDS = {
	apps = { 2, 29, 2, 29, 32 },
	bag = { 4, 27, 2, 29, 32 },
	chat = { 2, 29, 3, 28, 32 },
	circledown = { 2, 29, 2, 29, 32 },
	circleleft = { 2, 29, 2, 29, 32 },
	circleright = { 2, 29, 2, 29, 32 },
	circleup = { 2, 29, 2, 29, 32 },
	clear = { 1, 14, 3, 12, 16 },
	clock = { 1, 30, 1, 30, 32 },
	cog = { 0, 31, 0, 31, 32 },
	cogcube = { 0, 31, 0, 31, 32 },
	copy = { 1, 30, 1, 30, 32 },
	crosshair = { 1, 30, 1, 30, 32 },
	cursor = { 9, 25, 3, 29, 32 },
	dashboard = { 3, 28, 3, 28, 32 },
	delete = { 3, 27, 0, 31, 32 },
	disc = { 1, 30, 1, 30, 32 },
	drag = { 0, 31, 0, 31, 32 },
	dungeon = { 3, 28, 1, 30, 32 },
	enable = { 4, 27, 1, 30, 32 },
	erase = { 4, 59, 14, 49, 64 },
	exit = { 3, 28, 2, 29, 32 },
	eye = { 2, 29, 5, 24, 32 },
	hide = { 0, 31, 2, 29, 32 },
	key1 = { 1, 30, 1, 30, 32 },
	key2 = { 1, 30, 1, 30, 32 },
	key3 = { 1, 30, 1, 30, 32 },
	key4 = { 1, 30, 1, 30, 32 },
	key5 = { 1, 30, 1, 30, 32 },
	key6 = { 1, 30, 1, 30, 32 },
	key7 = { 1, 30, 1, 30, 32 },
	key8 = { 1, 30, 1, 30, 32 },
	layout = { 1, 30, 4, 27, 32 },
	location = { 4, 27, 0, 30, 32 },
	lock = { 17, 111, 8, 120, 128 },
	markers = { 3, 28, 4, 27, 32 },
	minimap = { 4, 27, 2, 28, 32 },
	minus = { 2, 9, 5, 6, 12 },
	modules5 = { 3, 28, 1, 30, 32 },
	more = { 2, 29, 13, 18, 32 },
	mover = { 0, 31, 0, 31, 32 },
	order = { 5, 25, 0, 31, 32 },
	palette = { 3, 29, 2, 28, 32 },
	panel = { 2, 29, 4, 27, 32 },
	party = { 0, 31, 5, 27, 32 },
	paw = { 4, 27, 4, 26, 32 },
	play = { 6, 28, 3, 28, 32 },
	plus = { 2, 9, 2, 9, 12 },
	power = { 4, 27, 0, 27, 32 },
	profile = { 2, 28, 2, 28, 32 },
	question = { 19, 44, 11, 52, 64 },
	raid = { 2, 29, 5, 26, 32 },
	redo = { 2, 30, 4, 28, 32 },
	reload = { 5, 26, 4, 26, 32 },
	reset = { 1, 14, 1, 14, 16 },
	resize = { 3, 28, 3, 28, 32 },
	save = { 1, 14, 1, 14, 16 },
	shuffle = { 1, 30, 4, 27, 32 },
	skull = { 3, 28, 2, 29, 32 },
	sound = { 3, 25, 2, 29, 32 },
	sparkle = { 1, 29, 1, 30, 32 },
	stance = { 1, 30, 1, 29, 32 },
	targettarget = { 2, 29, 2, 29, 32 },
	text = { 5, 26, 2, 28, 32 },
	textbar = { 1, 30, 6, 25, 32 },
	theme = { 1, 14, 1, 14, 16 },
	viewfinder = { 2, 29, 2, 29, 32 },
	x = { 3, 28, 3, 28, 32 },
}
local fits = {}

local function Fit(name)
	local fit = fits[name]
	if fit ~= nil then return fit end
	local bounds = BOUNDS[name]
	fit = false
	if bounds then
		local left, right, top, bottom, size = bounds[1], bounds[2], bounds[3], bounds[4], bounds[5]
		local centerX, centerY = (left + right + 1) / 2, (top + bottom + 1) / 2
		local half = math.max(right - left + 1, bottom - top + 1) / FILL / 2
		fit = { (centerX - half) / size, (centerX + half) / size, (centerY - half) / size, (centerY + half) / size }
	end
	fits[name] = fit
	return fit
end

function Widget.SetGlyph(region, path)
	local name = type(path) == "string" and path:match("BUILib.Media.([%w_]+)$")
	local fit = name and Fit(name)
	if fit then
		region:SetTexture(path, EDGE, EDGE)
		region:SetTexCoord(fit[1], fit[2], fit[3], fit[4])
		region._buiGlyphFit = true
		return region
	end
	region:SetTexture(path)
	if region._buiGlyphFit then
		region._buiGlyphFit = nil
		region:SetTexCoord(0, 1, 0, 1)
	end
	return region
end
