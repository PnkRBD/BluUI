local MEDIA = 'BluUI/Libs/BUILib/Media/'
local TARGET = 'BluUI/Libs/BUILib/Core/Glyphs.lua'
local THRESHOLD = 32
local SKIP = {
	'^round%d+$', '^ring%d+$', '^outline%d+$', '^knob', '^pill', '^capsule$', '^checker$', '^circle_mask$',
	'^smoothdisc$', '^glow$', '^wheel$', '^ellipse$', '^dots$', '^dotgrid$', '^blank$', '^sorttri$',
	'^dropdown$', '^arrow$', '^check$', '^grabber$', '^stripes$',
}

local function Skipped(name)
	for _, pattern in ipairs(SKIP) do
		if name:match(pattern) then return true end
	end
	return false
end

local function Read(path)
	local file = assert(io.open(path, 'rb'))
	local data = file:read('a')
	file:close()
	return data
end

local function Bounds(name)
	local data = Read(MEDIA .. name .. '.tga')
	local idLength, _, imageType = data:byte(1, 3)
	local width, height, depth, descriptor = string.unpack('<I2I2BB', data, 13)
	assert(imageType == 2 and depth == 32, name .. ' is not an uncompressed 32-bit TGA')
	assert(width == height, name .. ' is not square')
	local topDown = (descriptor & 0x20) ~= 0
	local left, right, top, bottom = width, -1, height, -1
	local offset = 19 + idLength
	for row = 0, height - 1 do
		local y = topDown and row or (height - 1 - row)
		for x = 0, width - 1 do
			if data:byte(offset + 3) > THRESHOLD then
				if x < left then left = x end
				if x > right then right = x end
				if y < top then top = y end
				if y > bottom then bottom = y end
			end
			offset = offset + 4
		end
	end
	assert(right >= left, name .. ' is empty')
	return left, right, top, bottom, width
end

local names = {}
local listing = io.popen(package.config:sub(1, 1) == '\\' and ('dir /b "' .. MEDIA:gsub('/', '\\') .. '*.tga"') or ('ls "' .. MEDIA .. '"'))
for line in listing:lines() do
	local name = line:match('^(.-)%.tga$')
	if name and not Skipped(name) then names[#names + 1] = name end
end
listing:close()
table.sort(names)

local lines = {}
for _, name in ipairs(names) do
	lines[#lines + 1] = ('\t%s = { %d, %d, %d, %d, %d },'):format(name, Bounds(name))
end

local source = Read(TARGET)
local head, tail = source:match('^(.-local BOUNDS = {\n).-\n(}\nlocal fits.*)$')
assert(head, 'BOUNDS block not found in ' .. TARGET)
local file = assert(io.open(TARGET, 'wb'))
file:write(head, table.concat(lines, '\n'), '\n', tail)
file:close()
print(('%d glyphs written to %s'):format(#names, TARGET))
