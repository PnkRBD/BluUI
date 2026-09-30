local _, BUI = ...

local AddonButtons = {}
BUI.AddonButtons = AddonButtons

local Pixel = BUI.Pixel
local WoWMinimap = _G.Minimap
local LDBIcon = LibStub('LibDBIcon-1.0')

local LDB_PREFIX = 'LibDBIcon10_'
local UNORDERED_BASE = 100000
local BORDER_TEXTURE_FILEID = 136430
local BACKGROUND_TEXTURE_FILEID = 136467

local ignoreNames = {
	GameTimeFrame                     = true,
	MinimapBackdrop                   = true,
	TimeManagerClockButton            = true,
	QueueStatusButton                 = true,
	ExpansionLandingPageMinimapButton = true,
	AddonCompartmentFrame             = true,
}

local ignorePatterns = {
	'^GatherMatePin%d+$',
	'^HandyNotes.*Pin$',
}

local buttons = {}
local captured = {}
local displays = {}
local mode = 'NONE'

local noop = function() end

local parking = CreateFrame('Frame')
parking:Hide()

local function Config()
	return BUI.GetDB().interface.buttonBar
end

local function ShouldIgnore(frame)
	local name = frame:GetName()
	if not name then return false end
	if ignoreNames[name] then return true end
	for patternIndex = 1, #ignorePatterns do
		if name:match(ignorePatterns[patternIndex]) then return true end
	end
	return false
end

local function ClassifyTexture(region)
	local path = region:GetTexture()
	if path == BORDER_TEXTURE_FILEID
		or (type(path) == 'string' and path:lower():find('minimap%-trackingborder')) then
		return 'border'
	end
	if path == BACKGROUND_TEXTURE_FILEID
		or (type(path) == 'string' and path:lower():find('ui%-minimap%-background')) then
		return 'background'
	end
	return 'content'
end

local function FindIconTexture(button)
	local icon = button.Icon or button.icon
	if icon and icon.IsObjectType and icon:IsObjectType('Texture') then return icon end

	if button.GetNormalTexture then
		local normal = button:GetNormalTexture()
		if normal and (normal:GetTexture() or normal:GetAtlas()) and ClassifyTexture(normal) == 'content' then
			return normal
		end
	end

	local best, bestArea
	for _, region in pairs({ button:GetRegions() }) do
		if region:IsObjectType('Texture') and ClassifyTexture(region) == 'content' then
			local layer = region:GetDrawLayer()
			if layer == 'BACKGROUND' or layer == 'ARTWORK' then
				local texturePath = region:GetTexture()
				if region:GetDebugName():lower():find('icon', 1, true) or (type(texturePath) == 'string' and texturePath:lower():find('icon', 1, true)) then
					return region
				end
				local width, height = region:GetSize()
				local area = width * height
				if not bestArea or area > bestArea then best, bestArea = region, area end
			end
		end
	end
	return best
end

local function HasClickHandler(frame)
	if frame:HasScript('OnClick')     and frame:GetScript('OnClick')     then return true end
	if frame:HasScript('OnMouseUp')   and frame:GetScript('OnMouseUp')   then return true end
	if frame:HasScript('OnMouseDown') and frame:GetScript('OnMouseDown') then return true end
	return false
end

local function LooksLikeButton(frame)
	if frame:IsForbidden() or not frame:IsShown() then return false end
	local width, height = frame:GetSize()
	if width < 16 or height < 16 then return false end
	if width > 60 or height > 60 then return false end
	if math.abs(width - height) > 10 then return false end
	if HasClickHandler(frame) then return true end
	for _, child in pairs({ frame:GetChildren() }) do
		if HasClickHandler(child) then return true end
	end
	return false
end

local function FreezeButton(button)
	button._buiOriginalFuncs = {
		SetPoint       = button.SetPoint,
		ClearAllPoints = button.ClearAllPoints,
		SetParent      = button.SetParent,
		SetScale       = button.SetScale,
		SetSize        = button.SetSize,
		SetWidth       = button.SetWidth,
		SetHeight      = button.SetHeight,
	}
	button:SetFixedFrameStrata(false)
	button:SetFixedFrameLevel(false)
	button.SetPoint, button.ClearAllPoints = noop, noop
	button.SetParent, button.SetScale = noop, noop
	button.SetSize, button.SetWidth, button.SetHeight = noop, noop, noop
end

local function UnfreezeButton(button)
	for name, originalFunc in pairs(button._buiOriginalFuncs) do
		button[name] = originalFunc
	end
	button._buiOriginalFuncs = nil
end

local function Park(button)
	button._buiOriginalFuncs.SetParent(button, parking)
	button:Hide()
end

local function Relayout()
	local display = displays[mode]
	if not display then return end
	for index = 1, #buttons do Park(buttons[index]) end
	display.Layout(AddonButtons.Shown())
end

local QueueRelayout = BUI.Dispatcher.New(Relayout, 'Minimap.AddonButtons')

local function CaptureButton(button)
	if captured[button] or ShouldIgnore(button) then return end
	captured[button] = true

	local points = {}
	for pointIndex = 1, button:GetNumPoints() do
		points[pointIndex] = { button:GetPoint(pointIndex) }
	end
	button._buiOriginalState = {
		parent = button:GetParent(),
		points = points,
		strata = button:GetFrameStrata(),
		level  = button:GetFrameLevel(),
		scale  = button:GetScale(),
		alpha  = button:GetAlpha(),
		width  = button:GetWidth(),
		height = button:GetHeight(),
	}

	FreezeButton(button)

	local iconTexture = FindIconTexture(button)
	for _, region in pairs({ button:GetRegions() }) do
		if region:IsObjectType('Texture') and region ~= iconTexture and ClassifyTexture(region) ~= 'content' then
			region:Hide()
		end
	end
	if iconTexture then
		button._buiIcon = iconTexture
		button._buiIconCoord = { iconTexture:GetTexCoord() }
		button._buiIconW, button._buiIconH = iconTexture:GetSize()
		button._buiIconPoints = {}
		for pointIndex = 1, iconTexture:GetNumPoints() do button._buiIconPoints[pointIndex] = { iconTexture:GetPoint(pointIndex) } end
	end
	button._buiBorder = button._buiBorder or CreateFrame('Frame', nil, button, 'BackdropTemplate')

	Park(button)
	buttons[#buttons + 1] = button
	QueueRelayout()
end

local function ReleaseButton(button)
	UnfreezeButton(button)

	local original = button._buiOriginalState
	button:SetParent(original.parent)
	button:ClearAllPoints()
	for _, point in ipairs(original.points) do
		button:SetPoint(unpack(point))
	end
	button:SetFrameStrata(original.strata)
	button:SetFrameLevel(original.level)
	button:SetScale(original.scale)
	button:SetAlpha(original.alpha)
	button:SetSize(original.width, original.height)

	for _, region in pairs({ button:GetRegions() }) do
		if region:IsObjectType('Texture') then region:Show() end
	end
	local iconTexture = button._buiIcon
	if iconTexture then
		iconTexture:SetTexCoord(unpack(button._buiIconCoord))
		iconTexture:SetSize(button._buiIconW, button._buiIconH)
		iconTexture:ClearAllPoints()
		for _, point in ipairs(button._buiIconPoints) do iconTexture:SetPoint(unpack(point)) end
		button._buiIcon, button._buiIconCoord, button._buiIconW, button._buiIconH, button._buiIconPoints = nil, nil, nil, nil, nil
	end
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight then
		highlight:ClearAllPoints()
		highlight:SetAllPoints(button)
	end
	button._buiBorder:Hide()
	button:Show()
	button._buiOriginalState = nil
end

local function ScanChildren(parent)
	for _, child in pairs({ parent:GetChildren() }) do
		if not captured[child] and LooksLikeButton(child) then
			CaptureButton(child)
		end
	end
end

local function OnIconCreated(_, button)
	CaptureButton(button)
end

local function StartCapture()
	LDBIcon.RegisterCallback(AddonButtons, 'LibDBIcon_IconCreated', OnIconCreated)
	for _, name in ipairs(LDBIcon:GetButtonList()) do
		CaptureButton(LDBIcon:GetMinimapButton(name))
	end
	ScanChildren(WoWMinimap)
	ScanChildren(_G.MinimapBackdrop)
end

local function StopCapture()
	LDBIcon.UnregisterCallback(AddonButtons, 'LibDBIcon_IconCreated')
	for index = #buttons, 1, -1 do ReleaseButton(buttons[index]) end
	wipe(buttons)
	wipe(captured)
end

local function OrderKey(order, name, captureIndex)
	for index = 1, #order do
		if order[index] == name then return index end
	end
	return UNORDERED_BASE + captureIndex
end

local function Sorted(withExcluded)
	local config = Config()
	local list, keys = {}, {}
	for index = 1, #buttons do
		local button = buttons[index]
		local name = button:GetName()
		if withExcluded or not (name and config.excluded[name]) then
			list[#list + 1] = button
			keys[button] = name and OrderKey(config.order, name, index) or UNORDERED_BASE + index
		end
	end
	table.sort(list, function(left, right) return keys[left] < keys[right] end)
	return list
end

function AddonButtons.Shown()
	return Sorted(false)
end

function AddonButtons.Entries()
	local excluded = Config().excluded
	local entries = {}
	for _, button in ipairs(Sorted(true)) do
		local name = button:GetName()
		if name then
			entries[#entries + 1] = {
				id = name,
				label = (name:gsub('^' .. LDB_PREFIX, '')),
				icon = button._buiIcon and button._buiIcon:GetTexture(),
				included = not excluded[name],
			}
		end
	end
	return entries
end

function AddonButtons.SetIncluded(name, included)
	Config().excluded[name] = (not included) and true or nil
	Relayout()
end

function AddonButtons.SetOrder(names)
	local order = Config().order
	wipe(order)
	for index = 1, #names do order[index] = names[index] end
	Relayout()
end

function AddonButtons.Register(key, display)
	displays[key] = display
end

function AddonButtons.Refresh()
	local display = displays[mode]
	if not display then return end
	display.Show()
	Relayout()
end

function AddonButtons.SetMode(newMode)
	local previous = displays[mode]
	if previous and newMode ~= mode then previous.Hide() end
	local wasCapturing = previous ~= nil
	mode = newMode
	if not displays[mode] then
		if wasCapturing then StopCapture() end
		return
	end
	if not wasCapturing then StartCapture() end
	AddonButtons.Refresh()
end

Pixel.OnScaleChange('AddonButtons', AddonButtons.Refresh)
