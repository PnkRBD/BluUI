local _, BUI = ...

local Skin = BUI.Skinning
local BUILib = BluUI.BUILibClient or LibStub('BUILib')

local ANCHOR_WIDTH = 300
local CAPTION_BUTTON_WIDTH = 58
local UNLOCKED_STRATA = 'TOOLTIP'
local LOCKED_STRATA = 'HIGH'
local ANCHOR_HEIGHT = 20
local CAPTION_LEVEL = 8
local SAMPLE_ICON = 'Interface/Icons/INV_Misc_Bag_10'
local SAMPLE_LINE_HEIGHT = 2

local entries = {}
local order = {}

local ToastAnchors = {}
Skin.ToastAnchors = ToastAnchors

local function SharedConfig(key)
	local skinning = BUI.GetDB().skinning
	local store = skinning.toastAnchors
	if not store then
		store = {}
		skinning.toastAnchors = store
	end
	local config = store[key]
	if not config then
		config = {}
		store[key] = config
	end
	return config
end

local function Config(entry)
	if entry.config then return entry.config() end
	return SharedConfig(entry.key)
end

local function EntryPoint(entry)
	local point = entry.point
	if type(point) == 'function' then return point() end
	return point
end

local function ScreenOffset(frame, point)
	local x, y = frame:GetCenter()
	if not x or issecretvalue(x) or issecretvalue(y) then return nil end
	if point == 'BOTTOM' then
		local bottom = frame:GetBottom()
		if issecretvalue(bottom) then return nil end
		y = bottom + ANCHOR_HEIGHT / 2
	elseif point == 'TOP' then
		local top = frame:GetTop()
		if issecretvalue(top) then return nil end
		y = top - ANCHOR_HEIGHT / 2
	end
	local parentX, parentY = UIParent:GetCenter()
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * ratio - parentX, y * ratio - parentY
end

local function SnapshotPoints(entry, frame)
	local points = {}
	for index = 1, frame:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
		points[index] = { point, relativeTo or UIParent, relativePoint, x, y }
	end
	entry.points = points
end

local function RestorePoints(entry)
	local frame, points = entry.target, entry.points
	frame:ClearAllPoints()
	if #points == 0 then
		frame:SetAllPoints(UIParent)
		return
	end
	for index = 1, #points do
		local saved = points[index]
		frame:SetPoint(saved[1], saved[2], saved[3], saved[4], saved[5])
	end
end

local function PlaceAnchor(entry)
	local anchor, config = entry.anchor, Config(entry)
	anchor:ClearAllPoints()
	if config.positioned then
		anchor:SetPoint('CENTER', UIParent, 'CENTER', config.posX, config.posY)
		return
	end
	if entry.followFrame then
		local x, y = ScreenOffset(entry.target, EntryPoint(entry))
		if x then
			anchor:SetPoint('CENTER', UIParent, 'CENTER', x, y)
			return
		end
	end
	anchor:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, entry.defaultY)
end

local function Apply(entry)
	if not Config(entry).positioned then return end
	local frame, anchor = entry.target, entry.anchor
	if InCombatLockdown() and frame:IsProtected() then return end
	if entry.apply then
		entry.apply(frame, anchor)
		return
	end
	local point = EntryPoint(entry)
	frame:ClearAllPoints()
	frame:SetPoint(point, anchor, point, 0, 0)
end

local function OnDragStart(anchor)
	anchor:StartMoving()
end

local function OnDragStop(anchor)
	anchor:StopMovingOrSizing()
	local entry = anchor._buiEntry
	local config = Config(entry)
	config.posX, config.posY = ScreenOffset(anchor, 'CENTER')
	config.positioned = true
	PlaceAnchor(entry)
	Apply(entry)
end

local function ResetEntry(entry)
	Config(entry).positioned = false
	RestorePoints(entry)
	PlaceAnchor(entry)
end

local function CenterEntry(entry)
	local config = Config(entry)
	if not config.positioned then
		local _, y = ScreenOffset(entry.anchor, 'CENTER')
		config.posY = y
	end
	config.posX = 0
	config.positioned = true
	PlaceAnchor(entry)
	Apply(entry)
end

local function SampleShell(parent, width, height)
	local frame = CreateFrame('Frame', nil, parent)
	frame:SetSize(width, height)
	Skin.TipShell(frame)
	return frame
end

local function SampleIcon(frame, size, x)
	local icon = frame:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(size, size)
	icon:SetPoint('LEFT', frame, 'LEFT', x, 0)
	icon:SetTexture(SAMPLE_ICON)
	Skin.CropIcon(icon)
	Skin.TipIconFrame(frame, icon)
	return icon
end

local function SampleText(frame, kind, text, point, relativeTo, relativePoint, x, y)
	local fontString = frame:CreateFontString(nil, 'OVERLAY')
	Skin.TipFont(fontString, kind)
	fontString:SetPoint(point, relativeTo, relativePoint, x, y)
	fontString:SetText(text)
	return fontString
end

local function SampleButton(frame, text, width, point, relativeTo, relativePoint, x, y)
	local button = CreateFrame('Button', nil, frame)
	button:SetSize(width, 22)
	button:SetPoint(point, relativeTo, relativePoint, x, y)
	Skin.TipButton(button)
	button:SetText(text)
	button:EnableMouse(false)
	return button
end

local function SampleTimer(frame, fraction)
	local line = frame:CreateTexture(nil, 'OVERLAY')
	local red, green, blue = BUILib.Theme.GetAccent()
	line:SetColorTexture(red, green, blue, 1)
	line:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 1, 1)
	line:SetSize(math.floor(frame:GetWidth() * fraction), SAMPLE_LINE_HEIGHT)
	return line
end

local SAMPLES = {}

function SAMPLES.toast(parent)
	local frame = SampleShell(parent, 280, 64)
	local icon = SampleIcon(frame, 44, 10)
	local title = SampleText(frame, 'title', 'You received', 'TOPLEFT', icon, 'TOPRIGHT', 12, -4)
	SampleText(frame, 'body', 'Sample Item', 'TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
	return frame
end

function SAMPLES.roll(parent)
	local frame = SampleShell(parent, 300, 56)
	local icon = SampleIcon(frame, 40, 8)
	SampleText(frame, 'title', 'Sample Item', 'TOPLEFT', icon, 'TOPRIGHT', 10, -2)
	local pass = SampleButton(frame, 'Pass', 52, 'BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -8, 8)
	local greed = SampleButton(frame, 'Greed', 56, 'RIGHT', pass, 'LEFT', -4, 0)
	SampleButton(frame, 'Need', 52, 'RIGHT', greed, 'LEFT', -4, 0)
	SampleTimer(frame, 0.65)
	return frame
end

function SAMPLES.bonus(parent)
	local frame = SampleShell(parent, 300, 72)
	local icon = SampleIcon(frame, 44, 10)
	local roll = SampleButton(frame, 'Roll', 60, 'RIGHT', frame, 'RIGHT', -10, 0)
	local title = SampleText(frame, 'title', 'Bonus Roll', 'TOPLEFT', icon, 'TOPRIGHT', 12, -6)
	local body = SampleText(frame, 'body', 'Spend a seal to roll again', 'TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
	body:SetPoint('RIGHT', roll, 'LEFT', -8, 0)
	body:SetJustifyH('LEFT')
	body:SetWordWrap(false)
	SampleTimer(frame, 0.5)
	return frame
end

local function SampleDragStart(sample)
	sample._buiAnchor:StartMoving()
end

local function SampleDragStop(sample)
	OnDragStop(sample._buiAnchor)
end

local function PointSample(entry)
	local point = EntryPoint(entry)
	local sample = entry.sampleFrame
	sample:ClearAllPoints()
	sample:SetPoint(point, entry.anchor, entry.sampleRelativePoint or point, 0, 0)
end

local function EnsureSample(entry)
	if entry.sampleFrame then return entry.sampleFrame end
	local anchor = entry.anchor
	local sample = SAMPLES[entry.sample](anchor)
	sample._buiAnchor = anchor
	sample:SetFrameLevel(anchor:GetFrameLevel() + 1)
	sample:EnableMouse(true)
	sample:RegisterForDrag('LeftButton')
	sample:SetScript('OnDragStart', SampleDragStart)
	sample:SetScript('OnDragStop', SampleDragStop)
	sample:Hide()
	entry.sampleFrame = sample
	PointSample(entry)
	local caption = entry.caption
	caption:ClearAllPoints()
	caption:SetSize(ANCHOR_WIDTH, ANCHOR_HEIGHT)
	caption:SetPoint('TOP', sample, 'BOTTOM', 0, -2)
	return sample
end

local function CreateAnchor(entry)
	local anchor = CreateFrame('Frame', 'BluUIToastAnchor_' .. entry.key, UIParent)
	anchor._buiEntry = entry
	anchor:SetSize(ANCHOR_WIDTH, ANCHOR_HEIGHT)
	anchor:SetFrameStrata(LOCKED_STRATA)
	anchor:SetMovable(true)
	anchor:SetClampedToScreen(true)
	anchor:EnableMouse(false)
	anchor:RegisterForDrag('LeftButton')
	anchor:SetScript('OnDragStart', OnDragStart)
	anchor:SetScript('OnDragStop', OnDragStop)

	local caption = CreateFrame('Frame', nil, anchor)
	caption:SetAllPoints(anchor)
	caption:SetFrameLevel(anchor:GetFrameLevel() + CAPTION_LEVEL)
	entry.caption = caption

	local fill = caption:CreateTexture(nil, 'BACKGROUND')
	fill:SetAllPoints(caption)
	fill:SetColorTexture(0, 0, 0, 0.7)

	local label = caption:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	label:SetPoint('LEFT', caption, 'LEFT', 8, 0)
	label:SetText(entry.label)

	local function CaptionButton(text, anchorTo, onClick)
		local button = CreateFrame('Button', nil, caption)
		button:SetSize(CAPTION_BUTTON_WIDTH, ANCHOR_HEIGHT)
		if anchorTo then
			button:SetPoint('RIGHT', anchorTo, 'LEFT', -2, 0)
		else
			button:SetPoint('RIGHT', caption, 'RIGHT', -2, 0)
		end
		local buttonText = button:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
		buttonText:SetPoint('CENTER')
		buttonText:SetText(text)
		button:SetScript('OnClick', onClick)
		button:SetScript('OnEnter', function() buttonText:SetTextColor(1, 0.82, 0) end)
		button:SetScript('OnLeave', function() buttonText:SetTextColor(1, 1, 1) end)
		return button
	end
	local reset = CaptionButton('RESET', nil, function() ResetEntry(entry) end)
	CaptionButton('CENTER', reset, function() CenterEntry(entry) end)

	anchor:Hide()
	entry.anchor = anchor
	PlaceAnchor(entry)
end

local function SetEntryUnlocked(entry, value)
	entry.unlocked = value
	local anchor = entry.anchor
	if value then PlaceAnchor(entry) end
	anchor:SetFrameStrata(value and UNLOCKED_STRATA or LOCKED_STRATA)
	anchor:EnableMouse(value)
	anchor:SetShown(value)
	EnsureSample(entry):SetShown(value)
end

local function Install(entry)
	local frame = entry.frame()
	if not frame then return end
	entry.target = frame
	SnapshotPoints(entry, frame)
	CreateAnchor(entry)
	local function Reapply() Apply(entry) end
	frame:HookScript('OnShow', Reapply)
	entry.hooks(Reapply)
	Apply(entry)
end

function ToastAnchors.Register(entry)
	entries[entry.key] = entry
	order[#order + 1] = entry
end

function ToastAnchors.SetUnlocked(key, value)
	local entry = entries[key]
	if entry.anchor then SetEntryUnlocked(entry, value) end
end

function ToastAnchors.IsUnlocked(key)
	return entries[key].unlocked == true
end

function ToastAnchors.Refresh(key)
	local entry = entries[key]
	if not entry.anchor then return end
	if entry.sampleFrame then PointSample(entry) end
	PlaceAnchor(entry)
	Apply(entry)
end

BUI.Events:Once('PLAYER_LOGIN', 'Skin.ToastAnchors', function()
	for index = 1, #order do Install(order[index]) end
end)
