local _, BUI = ...

local Confetti = {}
BUI.Confetti = Confetti

local REFERENCE_HEIGHT = 780
local BASE_COUNT = 480
local MAX_SCALE = 1.3
local RAIN_DRIFT = 140
local RAIN_PUSH = 220
local RAIN_STAGGER = 1.2
local RAIN_ABOVE = 60
local GRAVITY = 1100
local DRAG = 3
local SPEED_MIN, SPEED_MAX = 2200, 3400
local ANGLE_MIN, ANGLE_MAX = math.rad(45), math.rad(85)
local ACCENT_SHARE = 0.2
local LIFE_MIN, LIFE_MAX = 3.4, 4.6
local FADE = 1
local STAGGER = 0.35
local CANNON_X = 0.06
local WIDTH_MIN, WIDTH_RANGE = 7, 5
local HEIGHT_MIN, HEIGHT_RANGE = 12, 8
local SWAY = 14
local FLIP_MIN = 0.15
local LEVEL = 500
local COLORS = {
	{ 1, 0.84, 0.25 }, { 0.3, 0.84, 0.52 }, { 0.94, 0.42, 0.42 },
	{ 0.35, 0.62, 1 }, { 1, 1, 1 }, { 0.95, 0.5, 0.85 },
}

local abs, cos, sin, exp, max, min = math.abs, math.cos, math.sin, math.exp, math.max, math.min
local screenHost

local function Step(self, elapsed)
	self.clock = self.clock + elapsed
	self.parity = 1 - self.parity
	local parity = self.parity
	local clock = self.clock
	local drag = exp(-DRAG * elapsed)
	local fall = self.gravity * elapsed
	local live = 0
	local pieces = self.pieces
	for index = 1, self.active do
		local piece = pieces[index]
		if not piece.done then
			local age = clock - piece.delay
			local texture = piece.texture
			if age >= piece.life then
				piece.done = true
				texture:Hide()
			elseif age >= 0 then
				live = live + 1
				piece.vx = piece.vx * drag
				piece.vy = (piece.vy - fall) * drag
				piece.x = piece.x + piece.vx * elapsed
				piece.y = piece.y + piece.vy * elapsed
				piece.spin = piece.spin + piece.spinRate * elapsed
				if index % 2 == parity then
					texture:SetWidth(piece.width * max(FLIP_MIN, abs(cos(piece.phase + age * piece.flipRate))))
					texture:SetRotation(piece.spin)
				end
				texture:SetPoint('CENTER', self, 'BOTTOMLEFT', piece.x + sin(piece.phase + age * 3) * SWAY * min(1, age), piece.y)
				local remaining = piece.life - age
				if remaining < FADE then texture:SetAlpha(remaining / FADE) end
				if not piece.shown then
					piece.shown = true
					texture:Show()
				end
			else
				live = live + 1
			end
		end
	end
	if live == 0 then self:Hide() end
end

local function Layer(host)
	if host.confettiLayer then return host.confettiLayer end
	local layer = CreateFrame('Frame', nil, host)
	layer:SetAllPoints()
	layer:SetFrameLevel(min(host:GetFrameLevel() + LEVEL, 10000))
	layer:SetClipsChildren(true)
	layer:EnableMouse(false)
	layer.pieces = {}
	layer:SetScript('OnUpdate', Step)
	layer:Hide()
	host.confettiLayer = layer
	return layer
end

local function Piece(layer, index)
	local piece = layer.pieces[index]
	if piece then return piece end
	local texture = layer:CreateTexture(nil, 'OVERLAY')
	texture:SetTexture(BUI.BUILibClient.Widget.WHITE)
	texture:Hide()
	piece = { texture = texture }
	layer.pieces[index] = piece
	return piece
end

function Confetti.Burst(host)
	local layer = Layer(host)
	local width, height = layer:GetWidth(), layer:GetHeight()
	if not width or width <= 0 or not height or height <= 0 then return end
	local scale = max(1, min(MAX_SCALE, height / REFERENCE_HEIGHT))
	local count = math.floor(BASE_COUNT * scale)
	local red, green, blue = BUI.BUILibClient.Theme.GetAccent()
	for index = count + 1, #layer.pieces do layer.pieces[index].texture:Hide() end
	for index = 1, count do
		local piece = Piece(layer, index)
		local source = index % 3
		piece.delay = math.random() * STAGGER
		if source == 0 then
			piece.x = math.random() * width
			piece.y = height + math.random() * RAIN_ABOVE * scale
			piece.vx = (math.random() - 0.5) * 2 * RAIN_DRIFT * scale
			piece.vy = -math.random() * RAIN_PUSH * scale
			piece.delay = math.random() * RAIN_STAGGER
		else
			local left = source == 1
			local angle = ANGLE_MIN + math.random() * (ANGLE_MAX - ANGLE_MIN)
			local speed = (SPEED_MIN + math.random() * (SPEED_MAX - SPEED_MIN)) * scale
			piece.x = left and width * CANNON_X or width * (1 - CANNON_X)
			piece.y = 0
			piece.vx = cos(angle) * speed * (left and 1 or -1)
			piece.vy = sin(angle) * speed
		end
		piece.life = LIFE_MIN + math.random() * (LIFE_MAX - LIFE_MIN)
		piece.width = WIDTH_MIN + math.random() * WIDTH_RANGE
		piece.spin = math.random() * math.pi * 2
		piece.spinRate = (math.random() - 0.5) * 12
		piece.phase = math.random() * math.pi * 2
		piece.flipRate = 4 + math.random() * 6
		piece.done, piece.shown = false, false
		local texture = piece.texture
		texture:Hide()
		texture:ClearAllPoints()
		texture:SetHeight(HEIGHT_MIN + math.random() * HEIGHT_RANGE)
		texture:SetAlpha(1)
		local color = math.random() < ACCENT_SHARE and { red, green, blue } or COLORS[math.random(#COLORS)]
		texture:SetVertexColor(color[1], color[2], color[3])
	end
	layer.active = count
	layer.gravity = GRAVITY * scale
	layer.clock = 0
	layer.parity = 0
	layer:Show()
end

function Confetti.BurstOnScreen()
	if not screenHost then
		screenHost = CreateFrame('Frame', 'BUI_Confetti', UIParent)
		screenHost:SetAllPoints(UIParent)
		screenHost:SetFrameStrata('FULLSCREEN_DIALOG')
		screenHost:EnableMouse(false)
	end
	Confetti.Burst(screenHost)
end
