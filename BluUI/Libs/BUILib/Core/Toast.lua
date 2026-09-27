local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Toast = BUILib.Toast
local Widget = BUILib.Widget

local DEFAULT_DURATION = 5
local FADE_IN = 0.2
local FADE_OUT = 0.3
local STACK_GAP = 8
local EDGE_OFFSET = 16
local WIDTH = 320
local RADIUS = 8
local PADDING_X, PADDING_Y = 14, 11
local DOT_SIZE = 8
local DOT_GAP = 10
local TITLE_SIZE = 12
local SUB_SIZE = 11
local LINE_HEIGHT = 2
local LINE_INSET = 6
local SURFACE = { 0.06, 0.07, 0.08, 0.96 }
local EDGE = { 0.2, 0.22, 0.26, 0.85 }
local TITLE = { 0.95, 0.95, 0.97, 1 }
local SUBTEXT = { 0.6, 0.6, 0.65, 1 }
local TRACK = { 1, 1, 1, 0.06 }
local VARIANTS = {
	success = { 0.30, 0.85, 0.45 },
	error = { 0.95, 0.30, 0.30 },
	warning = { 0.95, 0.65, 0.20 },
	info = { 0.30, 0.65, 0.95 },
}

local stack = {}

local function Reanchor()
	for index, token in ipairs(stack) do
		local frame = token.frame
		frame:ClearAllPoints()
		if index == 1 then
			frame:SetPoint('BOTTOMRIGHT', token.parent, 'BOTTOMRIGHT', -EDGE_OFFSET, EDGE_OFFSET)
		else
			frame:SetPoint('BOTTOMRIGHT', stack[index - 1].frame, 'TOPRIGHT', 0, STACK_GAP)
		end
	end
end

local function Remove(token)
	if token.removed then return end
	token.removed = true
	token.frame:SetScript('OnUpdate', nil)
	token.frame:Hide()
	token.frame:SetParent(nil)
	for index, entry in ipairs(stack) do
		if entry == token then
			table.remove(stack, index)
			break
		end
	end
	Reanchor()
end

local function Fade(token, seconds, from, to, onDone)
	local started = GetTime()
	token.frame:SetScript('OnUpdate', function(self)
		local progress = math.min(1, (GetTime() - started) / seconds)
		local eased = progress * (2 - progress)
		self:SetAlpha(from + (to - from) * eased)
		if progress >= 1 then
			self:SetScript('OnUpdate', nil)
			onDone(token)
		end
	end)
end

local function Sit(token)
	local started = GetTime()
	local width = WIDTH - PADDING_X * 2
	token.frame:SetScript('OnUpdate', function(self)
		local progress = (GetTime() - started) / token.duration
		if progress >= 1 then
			self:SetScript('OnUpdate', nil)
			token:Dismiss()
			return
		end
		token.line:SetWidth(math.max(1, width * (1 - progress)))
	end)
end

local function Dismiss(token)
	if token.leaving or token.removed then return end
	token.leaving = true
	Fade(token, FADE_OUT, token.frame:GetAlpha(), 0, Remove)
end

local function Build(token, text, subtext, color, onClick)
	local frame = CreateFrame('Button', nil, token.parent)
	local height = PADDING_Y + TITLE_SIZE + (subtext and (SUB_SIZE + 4) or 0) + 8 + LINE_HEIGHT + LINE_INSET
	frame:SetSize(WIDTH, height)
	frame:SetFrameStrata(token.parent:GetFrameStrata())
	frame:SetFrameLevel((token.parent:GetFrameLevel() or 0) + 100)
	Widget.DrawCardShape(frame, RADIUS, SURFACE, EDGE, 'BACKGROUND', 0, 0)

	local dot = frame:CreateTexture(nil, 'ARTWORK')
	dot:SetTexture(BUILib.GetLibMedia('smoothdisc'))
	dot:SetSize(DOT_SIZE, DOT_SIZE)
	dot:SetPoint('TOPLEFT', PADDING_X, -(PADDING_Y + 3))
	dot:SetVertexColor(color[1], color[2], color[3], 1)

	local title = frame:CreateFontString(nil, 'OVERLAY')
	title:SetFont(BUILib.Font, TITLE_SIZE, '')
	title:SetPoint('TOPLEFT', PADDING_X + DOT_SIZE + DOT_GAP, -PADDING_Y)
	title:SetPoint('TOPRIGHT', -PADDING_X, -PADDING_Y)
	title:SetJustifyH('LEFT')
	title:SetWordWrap(false)
	title:SetText(text)
	title:SetTextColor(unpack(TITLE))

	if subtext then
		local sub = frame:CreateFontString(nil, 'OVERLAY')
		sub:SetFont(BUILib.Font, SUB_SIZE, '')
		sub:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
		sub:SetPoint('TOPRIGHT', title, 'BOTTOMRIGHT', 0, -4)
		sub:SetJustifyH('LEFT')
		sub:SetWordWrap(false)
		sub:SetText(subtext)
		sub:SetTextColor(unpack(SUBTEXT))
	end

	local track = frame:CreateTexture(nil, 'ARTWORK')
	track:SetTexture(Widget.WHITE)
	track:SetVertexColor(unpack(TRACK))
	track:SetPoint('BOTTOMLEFT', PADDING_X, LINE_INSET)
	track:SetPoint('BOTTOMRIGHT', -PADDING_X, LINE_INSET)
	track:SetHeight(LINE_HEIGHT)
	local line = frame:CreateTexture(nil, 'ARTWORK', nil, 1)
	line:SetTexture(Widget.WHITE)
	line:SetVertexColor(color[1], color[2], color[3], 0.9)
	line:SetPoint('BOTTOMLEFT', PADDING_X, LINE_INSET)
	line:SetSize(WIDTH - PADDING_X * 2, LINE_HEIGHT)

	frame:SetScript('OnClick', function()
		if onClick then onClick() end
		token:Dismiss()
	end)
	token.frame, token.line = frame, line
end

function Toast.Show(options)
	options = options or {}
	local color = VARIANTS[options.variant] or VARIANTS.info
	local token = {
		parent = options.parent or BUILib.GetActiveClient().popupParent or UIParent,
		duration = options.duration or DEFAULT_DURATION,
		Dismiss = Dismiss,
	}
	Build(token, options.text or '', options.subtext, color, options.onClick)
	stack[#stack + 1] = token
	Reanchor()
	token.frame:SetAlpha(0)
	Fade(token, FADE_IN, 0, 1, Sit)
	return token
end

local function WithVariant(variant, text, subtext, options)
	local merged = {}
	if options then
		for key, value in pairs(options) do merged[key] = value end
	end
	merged.text, merged.subtext, merged.variant = text, subtext, variant
	return Toast.Show(merged)
end

function Toast.Success(text, subtext, options) return WithVariant('success', text, subtext, options) end
function Toast.Error(text, subtext, options) return WithVariant('error', text, subtext, options) end
function Toast.Warning(text, subtext, options) return WithVariant('warning', text, subtext, options) end
function Toast.Info(text, subtext, options) return WithVariant('info', text, subtext, options) end
