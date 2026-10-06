local _, BUI = ...

local Hook = BUI.Profiler.Hooker('Skin.Chat')
local Wrap = BUI.Profiler.Wrap
local After = BUI.Profiler.After

local _G = _G
local tconcat = table.concat
local upper = string.upper
local find = string.find

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local theme = BUILib.Theme
local Skin3 = BUILib.Skin
local Skin = BUI.Skinning
local sharedMedia = LibStub('LibSharedMedia-3.0')
local GLOBAL_OPTION = BUI.C.GLOBAL_OPTION

local SIZER_IDLE_ALPHA = 0.55
local HISTORY_CAP = 64
local EDGES = { 'top', 'bottom', 'left', 'right' }

local FLAG_OPTIONS = {
	{ value = '', text = 'None' },
	{ value = 'OUTLINE', text = 'Outline' },
	{ value = 'THICKOUTLINE', text = 'Thick Outline' },
	{ value = 'OUTLINE, MONOCHROME', text = 'Monochrome' },
}
local EDITBOX_OPTIONS = {
	{ value = 'BOTTOM', text = 'Below Chat' },
	{ value = 'TOP', text = 'Above Chat' },
	{ value = 'INSIDE_BOTTOM', text = 'Inside Bottom' },
	{ value = 'INSIDE_TOP', text = 'Inside Top' },
}
local TAB_STYLE_OPTIONS = {
	{ value = 'UNDERLINE', text = 'Underline' },
	{ value = 'FILL', text = 'Filled' },
	{ value = 'TEXT', text = 'Text Only' },
}
local TIMESTAMP_OPTIONS = {
	{ value = '%H:%M', text = '14:30' },
	{ value = '[%H:%M]', text = '[14:30]' },
	{ value = '%H:%M:%S', text = '14:30:55' },
	{ value = '%I:%M', text = '02:30' },
	{ value = '%I:%M %p', text = '02:30 PM' },
}
local CHANNEL_ABBR = {
	['LookingForGroup'] = 'LFG', ['LocalDefense'] = 'Defense',
	['General'] = 'Gen', ['Trade'] = 'Trade', ['Services'] = 'Svc',
}

local HOVER_LINK_TYPES = {
	item = true, spell = true, enchant = true, talent = true,
	quest = true, achievement = true, currency = true, keystone = true,
	mount = true,
}

local BAR_WIDTH = 16
local SCROLL_GUTTER = 20
local TAB_TEXT_PAD = 4
local TAB_LINE_HEIGHT = 2
local TAB_LINE_INSET = 6
local TAB_GLOW_HEIGHT = 12
local TAB_GLOW_ALPHA = 0.22
local TAB_FILL_SELECTED_ALPHA = 0.14
local TAB_FILL_IDLE_ALPHA = 0.28
local TAB_HOVER_ALPHA = 0.05
local TAB_PULSE_HALF_PERIOD = math.pi / 5
local BUTTON_IDLE = { 0.65, 0.65, 0.7 }
local auxPainters = {}
local chatPanel, panelSquare, sizer, fader, copyWindow, mover
local UpdateMover, UpdateSizer, ApplyMsgFontSize
local skinnedTabs = {}
local skinnedFrames = {}
local fadeState = { alpha = 1, lastActive = 0 }
local StartFader, StopFader
local installed = false
local TARGET_TELL_COMMANDS = { ['/t '] = true }
local TAB_STRATA = 'MEDIUM'
local TAB_LEVEL_LIFT = 10

local function LiftTab(tab, level)
	tab:SetFrameStrata(TAB_STRATA)
	tab:SetFrameLevel(level)
end

local function Enabled() return Skin.IsSkinEnabled('chat') end

local function GetConfig()
	return BUI.GetDB().skinning.chatSettings
end

local function Reader(key)
	return function() return GetConfig()[key] end
end

local function ColorReader(key)
	return function()
		local color = GetConfig()[key]
		return color[1], color[2], color[3]
	end
end

local function BGColor()
	local config = GetConfig()
	local color = config.bgColor
	return color[1], color[2], color[3], config.bgAlpha
end

local function EditBoxBGColor()
	local red, green, blue = BGColor()
	return red, green, blue, 1
end

local function BorderColor()
	local config = GetConfig()
	if not config.showBorder then return 0, 0, 0, 0 end
	local color = config.borderColor
	return color[1], color[2], color[3], 1
end

local function SelectedColor()
	local config = GetConfig()
	if config.selectedUseAccent then return theme.GetAccent() end
	local color = config.selectedColor
	return color[1], color[2], color[3]
end

local InactiveColor = ColorReader('inactiveColor')
local FlashColor = ColorReader('flashColor')

local function ResolveFont()
	local name = GetConfig().font
	if name == GLOBAL_OPTION then return BUI.GetGlobalFont() end
	return sharedMedia:Fetch('font', name, true) or BUI.GetGlobalFont()
end

local MsgFontSize = Reader('fontSize')
local EditFontSize = Reader('editFontSize')
local TabFontSize = Reader('tabFontSize')
local SelectedAlpha = Reader('selectedAlpha')
local DockedAlpha = Reader('dockedAlpha')
local BorderThickness = Reader('borderThickness')
local InsetX = Reader('insetX')
local InsetTop = Reader('insetTop')
local InsetBottom = Reader('insetBottom')
local EditBoxHeight = Reader('editboxHeight')
local ScrollLines = Reader('scrollLines')
local MsgFadeTime = Reader('msgFadeTime')
local FadeDelay = Reader('fadeDelay')

local BGTexture = Reader('bgTexture')
local TabStyle = Reader('tabStyle')
local MsgFlags = Reader('fontFlags')
local TabFlags = Reader('tabFontFlags')

local FontShadow = Reader('fontShadow')
local TabUppercase = Reader('tabUppercase')
local TabFlash = Reader('tabFlash')
local HideLogTab = Reader('hideLogTab')
local EditHistory = Reader('editHistory')
local DragToMove = Reader('dragToMove')
local MsgFade = Reader('msgFade')
local FadeEnabled = Reader('mouseoverFade')
local SizerEnabled = Reader('showSizer')
local HideButtons = Reader('hideButtons')
local HideVoiceButtons = Reader('hideVoiceButtons')
local ShowCopyButton = Reader('showCopyButton')
local Locked = Reader('locked')

local function EditBoxPos()
	local position = GetConfig().editboxPosition
	if position == 'BELOW' then return 'BOTTOM' elseif position == 'ABOVE' then return 'TOP' end
	return position
end

local function ApplyShadow(fontObject)
	if FontShadow() then
		fontObject:SetShadowColor(0, 0, 0, 1); fontObject:SetShadowOffset(1, -1)
	else
		fontObject:SetShadowColor(0, 0, 0, 0); fontObject:SetShadowOffset(0, 0)
	end
end

local function ApplyChatFont(chatFrame, size)
	chatFrame:SetFont(ResolveFont(), size or MsgFontSize(), MsgFlags())
end

local function HideTexture(texture)
	if not texture then return end
	texture:SetTexture(nil)
	texture:SetAtlas(nil)
	texture:SetAlpha(0)
end

local function StayHidden(frame, flag, shouldHide)
	if frame[flag] then return end
	frame[flag] = true
	local function Reassert(shownFrame) if shouldHide(shownFrame) then shownFrame:Hide() end end
	Hook(frame, 'Show', Reassert)
	Hook(frame, 'SetShown', function(shownFrame, shown) if shown then Reassert(shownFrame) end end)
end

local function Always() return true end
local function WantsHidden(frame) return frame._buiWantHidden end

local function ManageHidden(frame, shouldHide)
	StayHidden(frame, '_buiManageHook', WantsHidden)
	frame._buiWantHidden = shouldHide
	if shouldHide then frame:Hide() else frame:Show() end
end

local HIDDEN_PARENT = CreateFrame('Frame')
HIDDEN_PARENT:Hide()
local function Kill(frame)
	if not frame or frame._buiKilled then return end
	frame:UnregisterAllEvents()
	frame:Hide()
	StayHidden(frame, '_buiKilled', Always)
	frame:SetParent(HIDDEN_PARENT)
end

local function NormalizeGeometry(chat)
	local left, bottom = chat:GetLeft(), chat:GetBottom()
	if not left or not bottom or issecretvalue(left) or issecretvalue(bottom) then return end
	local pixel = BUI.Pixel.PixelSizeFor(chat, 1)
	local width, height = chat:GetSize()
	local restoring = chat._buiRestoringGeo
	chat._buiRestoringGeo = true
	chat:SetSize(BUILib.Widget.SnapX(width, pixel), BUILib.Widget.SnapX(height, pixel))
	chat:ClearAllPoints()
	chat:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', BUILib.Widget.SnapX(left, pixel), BUILib.Widget.SnapY(bottom, pixel))
	chat._buiRestoringGeo = restoring
end

local function RecordGeometry(chat, geometry)
	geometry.w, geometry.h = chat:GetSize()
	local point, _, relativePoint, x, y = chat:GetPoint(1)
	geometry.point, geometry.relPoint, geometry.x, geometry.y = point, relativePoint, x, y
end

local function SaveGeometry(chat)
	if chat:GetNumPoints() > 1 then return end
	NormalizeGeometry(chat)
	local db = BUI.GetDB()
	db.chatGeometry = db.chatGeometry or {}
	RecordGeometry(chat, db.chatGeometry)
	FCF_SavePositionAndDimensions(chat)
	chat:SetClampRectInsets(0, 0, 0, 0)
	BUI.Datatext.Apply()
end

local function GeometryMatches()
	local chat = ChatFrame1
	local geometry = BUI.GetDB().chatGeometry
	if not geometry or not geometry.w then return true end
	if chat:GetNumPoints() ~= 1 then return false end
	local point, relativeTo, relativePoint, x, y = chat:GetPoint(1)
	if point ~= geometry.point or relativePoint ~= (geometry.relPoint or geometry.point) or relativeTo ~= UIParent then return false end
	local width, height = chat:GetSize()
	return math.abs(width - geometry.w) < 0.5 and math.abs(height - geometry.h) < 0.5
		and math.abs(x - (geometry.x or 0)) < 0.5 and math.abs(y - (geometry.y or 0)) < 0.5
end

local function RestoreGeometry()
	local chat = ChatFrame1
	chat._buiRestoringGeo = true
	chat:SetClampRectInsets(0, 0, 0, 0)
	local geometry = BUI.GetDB().chatGeometry
	if not geometry or not geometry.w then chat._buiRestoringGeo = false return end
	chat:SetUserPlaced(true)
	chat:SetSize(geometry.w, geometry.h)
	if geometry.point then
		chat:ClearAllPoints()
		chat:SetPoint(geometry.point, UIParent, geometry.relPoint or geometry.point, geometry.x or 0, geometry.y or 0)
		NormalizeGeometry(chat)
		RecordGeometry(chat, geometry)
	end
	chat._buiRestoringGeo = false
end

local function NormalizeDock()
	local dock, chat = GeneralDockManager, ChatFrame1
	local height = InsetTop()
	dock:ClearAllPoints()
	dock:SetPoint('BOTTOMLEFT', chat, 'TOPLEFT', 0, 0)
	dock:SetPoint('BOTTOMRIGHT', chat, 'TOPRIGHT', 0, 0)
	dock:SetHeight(height)
	local level = chat:GetFrameLevel() + TAB_LEVEL_LIFT
	dock:SetFrameStrata(TAB_STRATA)
	dock:SetFrameLevel(level)
	local scrollFrame = dock.scrollFrame
	scrollFrame:SetHeight(height)
	scrollFrame:SetFrameStrata(TAB_STRATA)
	scrollFrame:SetFrameLevel(level + 1)
	local scrollChild = scrollFrame.child
	scrollChild:SetHeight(height)
	scrollChild:SetFrameStrata(TAB_STRATA)
	scrollChild:SetFrameLevel(level + 2)
	for tabIndex = 1, #skinnedTabs do LiftTab(skinnedTabs[tabIndex], level + 3) end
end

StaticPopupDialogs['BUI_CHAT_URL'] = {
	text = 'Press Ctrl+C to copy the link:',
	button1 = CLOSE,
	hasEditBox = true,
	editBoxWidth = 350,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
	OnShow = function(self, data)
		local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
		if editBox then editBox:SetText(data); editBox:SetFocus(); editBox:HighlightText() end
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
}

local function RegisterURLHandler()
	if LinkUtil.IsLinkHandlerRegistered('url') then return end
	LinkUtil.RegisterLinkHandler('url', function(link)
		StaticPopup_Show('BUI_CHAT_URL', nil, nil, link:sub(5))
	end)
end

local function LinkifyPlain(text, wrap)
	local out
	out = gsub(text, '(%a[%w%.+-]+://[%w_%./~%%%?&=#:;,@!*$%-+()]+)', wrap)
	if out ~= text then return out end
	out = gsub(text, '(www%.[%w_%./~%%%?&=#:;,@!*$%-+()]+)', wrap)
	if out ~= text then return out end
	out = gsub(text, '([%w%-_]+%.[%w%-_]+%.?[%w%-_]+/[%w_%./~%%%?&=#:;,@!*$%-+()]*)', wrap)
	if out ~= text then return out end
	return text
end

local function LinkifyURLs(text, config)
	if not (find(text, '://', 1, true) or find(text, 'www.', 1, true) or find(text, '/', 1, true)) then return text end
	local color = config.urlColor
	local wrap = '|cff' .. BUI.Hex(color[1], color[2], color[3]) .. '|Hurl:%1|h[%1]|h|r'
	if not find(text, '|', 1, true) then return LinkifyPlain(text, wrap) end

	local parts, position, textLength = {}, 1, #text
	while position <= textLength do
		local pipe = find(text, '|', position, true)
		if not pipe then
			parts[#parts + 1] = LinkifyPlain(text:sub(position), wrap)
			break
		end
		if pipe > position then parts[#parts + 1] = LinkifyPlain(text:sub(position, pipe - 1), wrap) end
		local marker = text:sub(pipe + 1, pipe + 1)
		local segmentEnd
		if marker == 'H' then
			segmentEnd = select(2, find(text, '^|H.-|h.-|h', pipe))
		elseif marker == 'c' then
			if text:sub(pipe + 2, pipe + 2) == 'n' then
				segmentEnd = find(text, ':', pipe, true)
			else
				segmentEnd = pipe + 9
			end
		elseif marker == 'T' then
			segmentEnd = select(2, find(text, '|t', pipe + 2, true))
		elseif marker == 'A' then
			segmentEnd = select(2, find(text, '|a', pipe + 2, true))
		elseif marker == 'K' then
			segmentEnd = select(2, find(text, '|k', pipe + 2, true))
		else
			segmentEnd = pipe + 1
		end
		if not segmentEnd or segmentEnd > textLength then segmentEnd = textLength end
		parts[#parts + 1] = text:sub(pipe, segmentEnd)
		position = segmentEnd + 1
	end
	return tconcat(parts)
end

local function ProcessChannels(text, config)
	if config.hideChannelNumbers then
		text = gsub(text, '(%[)%d+%.%s*', '%1')
	end
	if config.abbreviateChannels then
		text = gsub(text, '%[(%d*%.?%s*)([%a]+)%s*%-%s*[^%]]-%]', '[%1%2]')
		for fullName, abbreviation in pairs(CHANNEL_ABBR) do
			text = gsub(text, '(%[%d*%.?%s*)' .. fullName .. '%]', '%1' .. abbreviation .. ']')
		end
	end
	return text
end

local lastCheckedFormat, lastFormatValid
local function ValidStampFormat(formatString)
	if formatString ~= lastCheckedFormat then
		lastCheckedFormat = formatString
		lastFormatValid = true
		for spec in formatString:gmatch('%%(.?)') do
			if not spec:find('^[aAbBcCdDeHIjMmnpRrSTtUuVWwXxYyZz%%]') then
				lastFormatValid = false
				break
			end
		end
	end
	return lastFormatValid
end

local function HookAddMessage(frame)
	if frame._buiAddMessage then return end
	frame._buiAddMessage = true
	Hook(frame, 'AddMessage', function(self, text)
		if Enabled() and self ~= ChatFrame2 and type(text) == 'string' and not issecretvalue(text) and text ~= '' then
			local entry = self.historyBuffer:GetEntryAtIndex(1)
			if entry and entry.message == text then
				local config = GetConfig()
				local newText = ProcessChannels(text, config)
				if config.urlCopy then newText = LinkifyURLs(newText, config) end
				if config.timestamps then
					local stampFormat = config.timestampFormat
					if ValidStampFormat(stampFormat) then
						local stampColor = config.timestampColor
						newText = '|cff' .. BUI.Hex(stampColor[1], stampColor[2], stampColor[3]) .. date(stampFormat) .. '|r ' .. newText
					end
				end
				if newText ~= text then
					entry.message = newText
					if self.MarkDisplayDirty then self:MarkDisplayDirty() end
				end
			end
		end
		if self._buiSB and self._buiSB._update then self._buiSB._update() end
	end)
end

local function StripEscapes(text)
	text = gsub(text, '|c%x%x%x%x%x%x%x%x|Hurl:(.-)|h.-|h|r', '%1')
	text = gsub(text, '|Hurl:(.-)|h.-|h', '%1')
	text = gsub(text, '|H.-|h(.-)|h', '%1')
	text = gsub(text, '|T.-|t', '')
	text = gsub(text, '|A.-|a', '')
	text = gsub(text, '|K.-|k', '')
	return text
end

local function Clamp01(value)
	if value < 0 then return 0 elseif value > 1 then return 1 end
	return value
end

local function CreateScrollBar(parent, label, model)
	local bar = CreateFrame('Frame', nil, parent)
	bar:SetWidth(4)
	local track = bar:CreateTexture(nil, 'ARTWORK')
	track:SetAllPoints()
	track:SetColorTexture(1, 1, 1, 0.05)

	local thumb = CreateFrame('Frame', nil, bar)
	thumb:SetPoint('LEFT'); thumb:SetPoint('RIGHT'); thumb:SetPoint('TOP')
	thumb:SetHeight(20)
	thumb:EnableMouse(true)
	thumb:RegisterForDrag('LeftButton')
	local thumbTexture = thumb:CreateTexture(nil, 'OVERLAY')
	thumbTexture:SetAllPoints()
	local function ThumbColor(accent)
		if accent or model.accentIdle then
			thumbTexture:SetColorTexture(theme.GetAccent())
		else
			thumbTexture:SetColorTexture(0.65, 0.65, 0.7, 1)
		end
		thumbTexture:SetAlpha(accent and 0.9 or 0.55)
	end
	ThumbColor(false)

	local function PlaceThumb(fraction, usable)
		thumb:ClearAllPoints()
		thumb:SetPoint('LEFT'); thumb:SetPoint('RIGHT')
		thumb:SetPoint('TOP', bar, 'TOP', 0, -fraction * usable)
	end

	local function Update()
		local trackHeight = bar:GetHeight()
		local unchanged = model.Unchanged and model.Unchanged(trackHeight)
		if unchanged and not thumb._drag then return end
		if trackHeight <= 1 then thumb:Hide() return end
		local ratio, fraction = model.Read()
		if not ratio then thumb:Hide() return end
		thumb:Show()
		local thumbHeight = max(model.minThumb, min(trackHeight, trackHeight * ratio))
		thumb:SetHeight(thumbHeight)
		if not thumb._drag then PlaceThumb(fraction, trackHeight - thumbHeight) end
	end
	bar._update = Update

	thumb:SetScript('OnEnter', BUI.Profiler.Script(label .. ' thumb OnEnter', function() ThumbColor(true) end))
	thumb:SetScript('OnLeave', BUI.Profiler.Script(label .. ' thumb OnLeave', function() if not thumb._drag then ThumbColor(false) end end))
	local Drag = Wrap(label, function(self)
		local trackHeight, thumbHeight = bar:GetHeight(), self:GetHeight()
		local usable = trackHeight - thumbHeight
		if usable <= 0 then return end
		local _, cursorY = GetCursorPosition()
		local fraction = Clamp01((bar:GetTop() - cursorY / bar:GetEffectiveScale() - thumbHeight / 2) / usable)
		model.Seek(fraction)
		PlaceThumb(fraction, usable)
	end)
	thumb:SetScript('OnDragStart', BUI.Profiler.Script(label .. ' thumb OnDragStart', function(self)
		self._drag = true
		ThumbColor(true)
		self:SetScript('OnUpdate', Drag)
	end))
	thumb:SetScript('OnDragStop', BUI.Profiler.Script(label .. ' thumb OnDragStop', function(self)
		self._drag = false
		self:SetScript('OnUpdate', nil)
		ThumbColor(false)
		Update()
	end))
	return bar
end

local function GetCopyWindow()
	if copyWindow then return copyWindow end
	local window = CreateFrame('Frame', 'BUI_ChatCopy', UIParent)
	window:SetSize(580, 420)
	window:SetPoint('CENTER')
	window:SetFrameStrata('DIALOG')
	window:EnableMouse(true)
	window:SetMovable(true)
	window:RegisterForDrag('LeftButton')
	window:SetScript('OnDragStart', BUI.Profiler.Script('Skin.Chat window OnDragStart', window.StartMoving))
	window:SetScript('OnDragStop', BUI.Profiler.Script('Skin.Chat window OnDragStop', window.StopMovingOrSizing))
	window:Hide()
	table.insert(UISpecialFrames, 'BUI_ChatCopy')
	Skin3.Backdrop(window, { bg = { 0.05, 0.05, 0.05, 0.96 }, border = { 0, 0, 0, 1 } })

	local title = window:CreateFontString(nil, 'OVERLAY')
	title:SetFont(BUILib.Font, 14, '')
	title:SetPoint('TOPLEFT', 14, -12)
	title:SetText('Copy Chat')
	title:SetTextColor(1, 1, 1)

	local close = CreateFrame('Button', nil, window)
	close:SetSize(22, 22)
	close:SetPoint('TOPRIGHT', -6, -6)
	local closeGlyph = close:CreateFontString(nil, 'OVERLAY')
	closeGlyph:SetFont(BUILib.Font, 18, '')
	closeGlyph:SetPoint('CENTER')
	closeGlyph:SetText('×')
	closeGlyph:SetTextColor(0.7, 0.7, 0.7)
	close:SetScript('OnEnter', BUI.Profiler.Script('Skin.Chat close OnEnter', function() closeGlyph:SetTextColor(theme.GetAccent()) end))
	close:SetScript('OnLeave', BUI.Profiler.Script('Skin.Chat close OnLeave', function() closeGlyph:SetTextColor(0.7, 0.7, 0.7) end))
	close:SetScript('OnClick', BUI.Profiler.Script('Skin.Chat close OnClick', function() window:Hide() end))

	local scroll = CreateFrame('ScrollFrame', 'BUI_ChatCopyScroll', window)
	scroll:SetPoint('TOPLEFT', 14, -38)
	scroll:SetPoint('BOTTOMRIGHT', -18, 14)
	scroll:EnableMouseWheel(true)

	local editBox = CreateFrame('EditBox', nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetMaxLetters(0)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetWidth(540)
	editBox:SetScript('OnEscapePressed', BUI.Profiler.Script('Skin.Chat editBox OnEscapePressed', function() window:Hide() end))
	editBox:SetScript('OnTextChanged', BUI.Profiler.Script('Skin.Chat editBox OnTextChanged', function(self) ScrollingEdit_OnTextChanged(self, self:GetParent()) end))
	editBox:SetScript('OnCursorChanged', ScrollingEdit_OnCursorChanged)
	scroll:SetScrollChild(editBox)
	window.editBox = editBox

	local function Expand(text, cursorPosition, pattern)
		if text:sub(cursorPosition + 1, cursorPosition + 1):match(pattern) then
			if cursorPosition > 0 then cursorPosition = cursorPosition - 1 else cursorPosition = cursorPosition + 1 end
		end
		local startPos, endPos = cursorPosition, cursorPosition
		while startPos > 0 and not text:sub(startPos, startPos):match(pattern) do startPos = startPos - 1 end
		while startPos >= endPos and endPos < #text do endPos = endPos + 1 end
		while endPos < #text and not text:sub(endPos, endPos):match(pattern) do endPos = endPos + 1 end
		if text:sub(endPos, endPos):match(pattern) then endPos = endPos - 1 end
		return startPos, endPos
	end

	local function LooksLikeURL(token)
		return find(token, '://', 1, true) or find(token, 'www%.') or (find(token, '/', 1, true) and find(token, '%a%.%a'))
	end

	local clicks = { 0, 0, 0 }
	editBox:HookScript('OnMouseDown', BUI.Profiler.Wrap('Skin.Chat editBox OnMouseDown', function(self)
		local now = GetTime()
		if now - clicks[#clicks] < 0.5 then
			local triple = clicks[#clicks] - clicks[#clicks - 1] < 0.5
			local cursorPosition = self:GetCursorPosition()
			local text = self:GetText()
			local startPos, endPos
			if triple then
				startPos, endPos = Expand(text, cursorPosition, '\n')
			else
				startPos, endPos = Expand(text, cursorPosition, '%s')
				if not LooksLikeURL(text:sub(startPos + 1, endPos)) then
					startPos, endPos = Expand(text, cursorPosition, '[%s%p]')
				end
			end
			After('Skin.Chat copy highlight', 0, function() self:HighlightText(startPos, endPos) end)
		end
		clicks[#clicks + 1] = now
		if #clicks > 3 then tremove(clicks, 1) end
	end))

	local bar = CreateScrollBar(window, 'Skin.Chat copy scrollbar', {
		minThumb = 20,
		accentIdle = true,
		Read = function()
			local range = scroll:GetVerticalScrollRange()
			if range <= 1 then return end
			local viewHeight = scroll:GetHeight()
			return viewHeight / (viewHeight + range), Clamp01(scroll:GetVerticalScroll() / range)
		end,
		Seek = function(fraction)
			scroll:SetVerticalScroll(fraction * scroll:GetVerticalScrollRange())
		end,
	})
	bar:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 6, 0)
	bar:SetPoint('BOTTOMLEFT', scroll, 'BOTTOMRIGHT', 6, 0)
	window._bar = bar

	scroll:SetScript('OnScrollRangeChanged', Wrap('Skin.Chat copy bar', bar._update))
	scroll:SetScript('OnVerticalScroll', Wrap('Skin.Chat copy bar', bar._update))
	scroll:SetScript('OnMouseWheel', BUI.Profiler.Script('Skin.Chat scroll OnMouseWheel', function(self, delta)
		local range = self:GetVerticalScrollRange()
		self:SetVerticalScroll(min(max(0, self:GetVerticalScroll() - delta * 40), range))
	end))

	copyWindow = window
	return window
end

local function CopyChat(frame)
	local lines = {}
	for messageIndex = 1, frame:GetNumMessages() do
		local message, red, green, blue = frame:GetMessageInfo(messageIndex)
		if type(message) == 'string' and not issecretvalue(message) and message ~= '' then
			message = StripEscapes(message)
			if type(red) == 'number' and type(green) == 'number' and type(blue) == 'number' then
				message = '|cff' .. BUI.Hex(red, green, blue) .. message .. '|r'
			end
			lines[#lines + 1] = message
		end
	end
	local window = GetCopyWindow()
	window.editBox:SetText(tconcat(lines, '\n'))
	window:Show()
	window.editBox:SetCursorPosition(0)
	window.editBox:HighlightText()
	window.editBox:SetFocus()
	After('Skin.Chat copy bar', 0, window._bar._update)
end

local function GetHistory()
	local db = BUI.GetDB()
	if not db.chatHistory then db.chatHistory = {} end
	return db.chatHistory
end

local function PushHistory(text)
	if type(text) ~= 'string' or issecretvalue(text) then return end
	text = strtrim(text)
	if text == '' then return end
	local command = text:match('^(/%S+)')
	if command and IsSecureCmd(command) then return end
	local history = GetHistory()
	if history[#history] == text then return end
	history[#history + 1] = text
	while #history > HISTORY_CAP do tremove(history, 1) end
end

local function SetupEditHistory(editBox)
	if editBox._buiHist then return end
	editBox._buiHist = true
	editBox:SetAltArrowKeyMode(false)

	editBox:HookScript('OnKeyDown', BUI.Profiler.Wrap('Skin.Chat editBox OnKeyDown', function(self, key)
		if C_ChatInfo.InChatMessagingLockdown() then return end
		if not (Enabled() and EditHistory()) then return end
		local history = GetHistory()
		local historyCount = #history
		if historyCount == 0 then return end
		if key == 'UP' then
			if self._histIdx == nil then
				self._histTop = self:GetText()
				self._histIdx = historyCount
			elseif self._histIdx > 1 then
				self._histIdx = self._histIdx - 1
			else
				return
			end
			self:SetText(history[self._histIdx])
		elseif key == 'DOWN' then
			if self._histIdx == nil then return end
			if self._histIdx < historyCount then
				self._histIdx = self._histIdx + 1
				self:SetText(history[self._histIdx])
			else
				self._histIdx = nil
				self:SetText(self._histTop)
			end
		end
	end))

	editBox:HookScript('OnEditFocusLost', BUI.Profiler.Wrap('Skin.Chat editBox OnEditFocusLost', function(self) self._histIdx = nil end))

	Hook(editBox, 'AddHistoryLine', function(self, line)
		if not (Enabled() and EditHistory()) then return end
		self._histIdx = nil
		PushHistory(line)
	end)
end

local function IsTabSelected(tab)
	return GeneralDockManager.selected == tab._buiChat
end

local function ApplyTabColor(tab, selected)
	local text = tab._buiText
	local style = TabStyle()
	local red, green, blue = SelectedColor()
	if selected then
		if style == 'TEXT' then text:SetTextColor(red, green, blue) else text:SetTextColor(1, 1, 1) end
	else
		text:SetTextColor(InactiveColor())
	end
	local showLine = selected and style ~= 'TEXT'
	tab._buiLine:SetColorTexture(red, green, blue, 1)
	tab._buiLine:SetShown(showLine)
	tab._buiGlow:SetGradient('VERTICAL', CreateColor(red, green, blue, TAB_GLOW_ALPHA), CreateColor(red, green, blue, 0))
	tab._buiGlow:SetShown(showLine)
	if style == 'FILL' then
		if selected then
			tab._buiFill:SetColorTexture(red, green, blue, TAB_FILL_SELECTED_ALPHA)
		else
			tab._buiFill:SetColorTexture(0, 0, 0, TAB_FILL_IDLE_ALPHA)
		end
		tab._buiFill:Show()
	else
		tab._buiFill:Hide()
	end
end

local function DesiredTabAlpha(tab)
	if tab._buiCollapsed then return 0 end
	local chat = tab._buiChat
	local base = (not chat.isDocked or chat == GeneralDockManager.selected or tab._buiPulse) and SelectedAlpha() or DockedAlpha()
	return base * fadeState.alpha
end

local function ApplyTabAlpha(tab)
	local alpha = DesiredTabAlpha(tab)
	if tab:GetAlpha() ~= alpha then tab:SetAlpha(alpha, true) end
end

local function CollapseChatTab(tab, collapsed)
	if not tab then return end
	collapsed = collapsed and true or false
	if tab._buiCollapsed == collapsed then return end
	tab._buiCollapsed = collapsed
	tab:EnableMouse(not collapsed)
	if collapsed then tab:SetWidth(1) end
	ApplyTabAlpha(tab)
	FCFDock_UpdateTabs(GeneralDockManager, true)
end

local function TabAlphaHook(tab, _, skip)
	if skip or not Enabled() then return end
	if not tab._buiChat then return end
	ApplyTabAlpha(tab)
end

local function BlankTabTexture(texture)
	if not texture or texture._buiOwned then return end
	texture:SetTexture(nil)
	texture:SetAtlas(nil)
	texture:SetAlpha(0)
end

local function StripTabRegions(tab)
	for regionIndex = 1, select('#', tab:GetRegions()) do
		local region = select(regionIndex, tab:GetRegions())
		if region ~= tab._buiText and region:IsObjectType('Texture') then
			BlankTabTexture(region)
		end
	end
	BlankTabTexture(tab:GetHighlightTexture())
end

local function EnsureTabArt(tab)
	if tab._buiLine then return end
	local fill = tab:CreateTexture(nil, 'BACKGROUND')
	fill._buiOwned = true
	fill:SetAllPoints(tab)
	fill:Hide()
	tab._buiFill = fill

	local glow = tab:CreateTexture(nil, 'ARTWORK')
	glow._buiOwned = true
	glow:SetColorTexture(1, 1, 1, 1)
	glow:SetHeight(TAB_GLOW_HEIGHT)
	glow:SetPoint('BOTTOMLEFT', tab, 'BOTTOMLEFT', TAB_LINE_INSET, TAB_LINE_HEIGHT)
	glow:SetPoint('BOTTOMRIGHT', tab, 'BOTTOMRIGHT', -TAB_LINE_INSET, TAB_LINE_HEIGHT)
	glow:Hide()
	tab._buiGlow = glow

	local line = tab:CreateTexture(nil, 'ARTWORK', nil, 1)
	line._buiOwned = true
	line:SetHeight(TAB_LINE_HEIGHT)
	line:SetPoint('BOTTOMLEFT', tab, 'BOTTOMLEFT', TAB_LINE_INSET, 0)
	line:SetPoint('BOTTOMRIGHT', tab, 'BOTTOMRIGHT', -TAB_LINE_INSET, 0)
	line:Hide()
	tab._buiLine = line

	local hover = tab:CreateTexture(nil, 'HIGHLIGHT')
	hover._buiOwned = true
	hover:SetAllPoints(tab)
	hover:SetColorTexture(1, 1, 1, TAB_HOVER_ALPHA)
	tab._buiHover = hover
end

local function StyleTab(tab)
	local text = tab._buiText
	StripTabRegions(tab)
	EnsureTabArt(tab)
	tab:SetHeight(InsetTop())
	text:SetFont(ResolveFont(), TabFontSize(), TabFlags())
	text:SetWordWrap(false)
	text:SetJustifyH('CENTER')
	local chat = tab._buiChat
	local tabText = text:GetText()
	if tabText and not issecretvalue(tabText) then
		if text._buiName == nil or upper(text._buiName) ~= tabText then text._buiName = tabText end
		local wanted = (TabUppercase() and not chat.isTemporary) and upper(text._buiName) or text._buiName
		if wanted ~= tabText then text:SetText(wanted) end
	end
	text:ClearAllPoints()
	text:SetPoint('CENTER', tab, 'CENTER', 0, 0)
	if tab.conversationIcon then tab.conversationIcon:Hide() end
	ApplyShadow(text)
	ApplyTabColor(tab, IsTabSelected(tab))
	ApplyTabAlpha(tab)
end

local function TabOf(chatFrame)
	return chatFrame.tab or _G[chatFrame:GetName() .. 'Tab']
end

local function EditBoxOf(chatFrame)
	return chatFrame.editBox or _G[chatFrame:GetName() .. 'EditBox']
end

local function AlignDockTabs(dock)
	if not Enabled() then return end
	if dock ~= GeneralDockManager then return end
	if not dock:IsVisible() then return end
	for _, chatFrame in ipairs(dock.DOCKED_CHAT_FRAMES) do
		local tab = TabOf(chatFrame)
		if tab._buiChat then
			local point, relativeTo, relativePoint, x, y = tab:GetPoint(1)
			if point == 'LEFT' and y and y ~= 0 then
				tab:SetPoint(point, relativeTo, relativePoint, x, 0)
			end
			if tab._buiCollapsed then
				if tab:GetWidth() ~= 1 then tab:SetWidth(1) end
			else
				local width = max(1, tab:GetWidth() - TAB_TEXT_PAD * 2)
				if tab._buiTextWidth ~= width then
					tab._buiTextWidth = width
					tab._buiText:SetWidth(width)
				end
			end
		end
	end
end

local function RefreshTabs()
	for tabIndex = 1, #skinnedTabs do StyleTab(skinnedTabs[tabIndex]) end
	FCFDock_UpdateTabs(GeneralDockManager, true)
end

local function SkinTab(tab, chat)
	if tab._buiChatSkin then return end
	tab._buiChatSkin = true
	tab._buiChat = chat
	tab._buiText = tab.Text or _G[tab:GetName() .. 'Text']
	skinnedTabs[#skinnedTabs + 1] = tab
	tab:HookScript('OnEnter', BUI.Profiler.Wrap('Skin.Chat tab OnEnter', function()
		if Enabled() then StartFader() end
	end))
	StyleTab(tab)
	Hook(tab, 'SetAlpha', TabAlphaHook)
	ApplyTabAlpha(tab)
	LiftTab(tab, GeneralDockManager:GetFrameLevel() + 3)
end

local function PositionEditBox(chat)
	local editBox = EditBoxOf(chat)
	local position = EditBoxPos()
	editBox:ClearAllPoints()
	if position == 'TOP' then
		editBox:SetPoint('BOTTOMLEFT', chat, 'TOPLEFT', -InsetX(), InsetTop())
		editBox:SetPoint('BOTTOMRIGHT', chat, 'TOPRIGHT', InsetX(), InsetTop())
	elseif position == 'INSIDE_TOP' then
		editBox:SetPoint('TOPLEFT', chat, 'TOPLEFT', -InsetX(), 0)
		editBox:SetPoint('TOPRIGHT', chat, 'TOPRIGHT', InsetX(), 0)
	elseif position == 'INSIDE_BOTTOM' then
		editBox:SetPoint('BOTTOMLEFT', chat, 'BOTTOMLEFT', -InsetX(), 0)
		editBox:SetPoint('BOTTOMRIGHT', chat, 'BOTTOMRIGHT', InsetX(), 0)
	else
		editBox:SetPoint('TOPLEFT', chat, 'BOTTOMLEFT', -InsetX(), -InsetBottom())
		editBox:SetPoint('TOPRIGHT', chat, 'BOTTOMRIGHT', InsetX(), -InsetBottom())
	end
	editBox:SetHeight(EditBoxHeight())
	editBox:SetClampedToScreen(true)
end

local function StyleEditBox(editBox)
	editBox:SetFont(ResolveFont(), EditFontSize(), '')
	editBox:SetTextColor(1, 1, 1)
	ApplyShadow(editBox)
	editBox:SetBackdropColor(EditBoxBGColor())
	editBox:SetBackdropBorderColor(BorderColor())
end

local function SkinEditBox(editBox, chat)
	editBox._buiChat = chat
	SetupEditHistory(editBox)
	if editBox._buiChatSkin then PositionEditBox(chat); return end
	editBox._buiChatSkin = true

	local editBoxName = editBox:GetName()
	HideTexture(_G[editBoxName .. 'Left'])
	HideTexture(_G[editBoxName .. 'Mid'])
	HideTexture(_G[editBoxName .. 'Right'])
	HideTexture(editBox.focusLeft)
	HideTexture(editBox.focusRight)
	HideTexture(editBox.focusMid)

	Skin3.Backdrop(editBox)
	editBox:SetTextInsets(8, 8, 2, 2)
	StyleEditBox(editBox)
	PositionEditBox(chat)

	editBox:HookScript('OnShow', Wrap('Skin.Chat editbox position', function(self) PositionEditBox(self._buiChat) end))
	editBox:HookScript('OnEditFocusGained', BUI.Profiler.Wrap('Skin.Chat editBox OnEditFocusGained', function(self) self:SetBackdropBorderColor(theme.GetAccent()) end))
	editBox:HookScript('OnEditFocusLost', BUI.Profiler.Wrap('Skin.Chat editBox OnEditFocusLost 2', function(self) self:SetBackdropBorderColor(BorderColor()) end))
end

local function AnchorPanel()
	if not chatPanel then return end
	local chat = ChatFrame1
	chatPanel:ClearAllPoints()
	chatPanel:SetPoint('BOTTOMLEFT', chat, 'BOTTOMLEFT', -InsetX(), -InsetBottom())
	chatPanel:SetPoint('TOPRIGHT', chat, 'TOPRIGHT', InsetX() + SCROLL_GUTTER, InsetTop())
end

local function ApplyTopStrip()
	if not chatPanel then return end
	local thickness = BorderThickness()
	local strip = chatPanel._strip
	strip:ClearAllPoints()
	strip:SetPoint('TOPLEFT', chatPanel, 'TOPLEFT', thickness, -thickness)
	strip:SetPoint('TOPRIGHT', chatPanel, 'TOPRIGHT', -thickness, -thickness)
	strip:SetHeight(InsetTop())
end

local function ApplyRightStrip()
	if not chatPanel then return end
	local thickness = BorderThickness()
	local verticalStrip = chatPanel._vstrip
	verticalStrip:ClearAllPoints()
	verticalStrip:SetWidth(BAR_WIDTH)
	verticalStrip:SetPoint('TOPRIGHT', chatPanel, 'TOPRIGHT', -thickness, -(InsetTop() + thickness))
	verticalStrip:SetPoint('BOTTOMRIGHT', chatPanel, 'BOTTOMRIGHT', -thickness, thickness)
	local gutter = chatPanel._gutter
	gutter:ClearAllPoints()
	gutter:SetWidth(SCROLL_GUTTER)
	gutter:SetPoint('TOPRIGHT', chatPanel, 'TOPRIGHT', -thickness, -(InsetTop() + thickness))
	gutter:SetPoint('BOTTOMRIGHT', chatPanel, 'BOTTOMRIGHT', -thickness, thickness)
end

local function ApplyPanelFill()
	if not panelSquare then return end
	local red, green, blue, alpha = BGColor()
	local textureName = BGTexture()
	local path = textureName ~= 'SOLID' and sharedMedia:Fetch('statusbar', textureName) or nil
	if path then
		panelSquare.fill:SetTexture(path)
		panelSquare.fill:SetVertexColor(red, green, blue, alpha)
	else
		panelSquare.fill:SetVertexColor(1, 1, 1, 1)
		panelSquare.fill:SetColorTexture(red, green, blue, alpha)
	end
end

local function ApplyBorder()
	if not panelSquare then return end
	local thickness = BorderThickness()
	panelSquare.top:SetHeight(thickness); panelSquare.bottom:SetHeight(thickness)
	panelSquare.left:SetWidth(thickness); panelSquare.right:SetWidth(thickness)
	for _, edgeKey in ipairs(EDGES) do panelSquare[edgeKey]:SetColorTexture(BorderColor()) end
end

local function UpdateCornerButtons()
	local chat = ChatFrame1
	local gutter = chatPanel and chatPanel._gutter
	local hovered = gutter and gutter:IsMouseOver()
	local alpha = (hovered and 1 or 0.25) * (FadeEnabled() and fadeState.alpha or 1)
	if chat._buiCog then chat._buiCog:SetAlpha(alpha) end
	if chat._buiLock then chat._buiLock:SetAlpha(alpha) end
	if chat._buiCopy and ShowCopyButton() then chat._buiCopy:SetAlpha(alpha) end
	for button, paint in pairs(auxPainters) do
		if button:IsMouseOver() then
			local red, green, blue = theme.GetAccent()
			paint(red, green, blue, alpha)
		else
			paint(BUTTON_IDLE[1], BUTTON_IDLE[2], BUTTON_IDLE[3], alpha)
		end
	end
end

local function TouchFader()
	fadeState.lastActive = GetTime()
	StartFader()
	UpdateCornerButtons()
end

local function MakeCornerButton(chat, mediaKey)
	local button = CreateFrame('Button', nil, UIParent)
	button:SetFrameStrata('MEDIUM')
	button:SetSize(14, 14)
	button:SetFrameLevel(chat:GetFrameLevel() + 8)
	button:SetAlpha(0.25)
	local texture = button:CreateTexture(nil, 'ARTWORK')
	texture:SetAllPoints()
	texture:SetTexture(BUILib.GetLibMedia(mediaKey))
	texture:SetVertexColor(BUTTON_IDLE[1], BUTTON_IDLE[2], BUTTON_IDLE[3], 1)
	button._tex = texture
	button:SetScript('OnEnter', BUI.Profiler.Script('Skin.Chat button OnEnter', function()
		texture:SetVertexColor(theme.GetAccent())
		TouchFader()
	end))
	button:SetScript('OnLeave', BUI.Profiler.Script('Skin.Chat button OnLeave', function()
		texture:SetVertexColor(BUTTON_IDLE[1], BUTTON_IDLE[2], BUTTON_IDLE[3], 1)
		UpdateCornerButtons()
	end))
	return button
end

local function UpdateCopyButton()
	local copy = ChatFrame1._buiCopy
	if not copy then return end
	if ShowCopyButton() then copy:Show() else copy:Hide() end
end

local function SkinPanel()
	if chatPanel then return end
	local chat = ChatFrame1

	local panel = CreateFrame('Frame', 'BUI_ChatPanel', UIParent)
	panel:SetFrameStrata('BACKGROUND')
	panel:SetFrameLevel(max(0, chat:GetFrameLevel() - 1))
	chatPanel = panel
	AnchorPanel()
	After('Skin.Chat datatext apply', 0, BUI.Datatext.Apply)
	panelSquare = Skin3.SquarePanel(panel, { bg = { BGColor() }, border = { BorderColor() } })

	local strip = panel:CreateTexture(nil, 'BORDER')
	strip:SetColorTexture(0, 0, 0, 0.22)
	panel._strip = strip
	ApplyTopStrip()

	local verticalStrip = panel:CreateTexture(nil, 'BORDER')
	verticalStrip:SetColorTexture(0, 0, 0, 0.08)
	panel._vstrip = verticalStrip

	local gutter = CreateFrame('Frame', nil, panel)
	gutter:SetFrameStrata('BACKGROUND')
	gutter:SetFrameLevel(panel:GetFrameLevel() + 1)
	gutter:EnableMouse(true)
	gutter:SetPropagateMouseClicks(true)
	panel._gutter = gutter
	gutter:SetScript('OnEnter', BUI.Profiler.Script('Skin.Chat gutter OnEnter', function()
		if not Enabled() then return end
		TouchFader()
	end))
	gutter:SetScript('OnLeave', BUI.Profiler.Script('Skin.Chat gutter OnLeave', function()
		if not Enabled() then return end
		UpdateCornerButtons()
	end))
	ApplyRightStrip()

	local cog = MakeCornerButton(chat, 'cog')
	cog:SetPoint('TOP', verticalStrip, 'TOP', 0, -3)
	cog:SetScript('OnClick', BUI.Profiler.Script('Skin.Chat cog OnClick', function()
		if not BUI.PageEngine.EnsureLoaded() then return end
		BUI.PageEngine.Show()
		BUI.PageEngine.NavigateToID('chat')
	end))
	chat._buiCog = cog

	local copy = MakeCornerButton(chat, 'copy')
	copy:SetPoint('TOP', cog, 'BOTTOM', 0, -5)
	copy:SetScript('OnClick', BUI.Profiler.Script('Skin.Chat copy OnClick', function()
		local win = GetCopyWindow()
		if win:IsShown() then
			win:Hide()
		else
			CopyChat(GeneralDockManager.selected or ChatFrame1)
		end
	end))
	chat._buiCopy = copy

	local lock = MakeCornerButton(chat, 'lock')
	lock:SetPoint('TOP', copy, 'BOTTOM', 0, -5)
	local function PaintLock(hovered)
		local red, green, blue = theme.GetAccent()
		if hovered then
			lock._tex:SetVertexColor(red, green, blue, 1)
		elseif lock._lockedTint then
			lock._tex:SetVertexColor(red * 0.75, green * 0.75, blue * 0.75, 1)
		else
			lock._tex:SetVertexColor(BUTTON_IDLE[1], BUTTON_IDLE[2], BUTTON_IDLE[3], 1)
		end
	end
	local function UpdateLockIcon()
		lock._lockedTint = Locked() and true or false
		PaintLock(lock:IsMouseOver())
	end
	lock.Refresh = UpdateLockIcon
	lock:SetScript('OnEnter', BUI.Profiler.Script('Skin.Chat lock OnEnter', function()
		PaintLock(true)
		TouchFader()
	end))
	lock:SetScript('OnLeave', BUI.Profiler.Script('Skin.Chat lock OnLeave', function()
		PaintLock(false)
		UpdateCornerButtons()
	end))
	lock:SetScript('OnClick', BUI.Profiler.Script('Skin.Chat lock OnClick', function()
		GetConfig().locked = not Locked()
		UpdateLockIcon()
		UpdateMover()
		UpdateSizer()
	end))
	UpdateLockIcon()
	chat._buiLock = lock
end

local function PositionMover()
	if not mover then return end
	local chat = ChatFrame1
	mover:ClearAllPoints()
	mover:SetPoint('TOPLEFT', chat, 'TOPLEFT', -InsetX(), InsetTop())
	mover:SetPoint('BOTTOMRIGHT', chat, 'TOPRIGHT', InsetX(), 0)
end

function UpdateMover()
	if not mover then return end
	PositionMover()
	if DragToMove() and not Locked() then mover:EnableMouse(true); mover:Show() else mover:EnableMouse(false); mover:Hide() end
end

local function CreateMover()
	if mover then return end
	local chat = ChatFrame1
	mover = CreateFrame('Frame', 'BUI_ChatMover', chatPanel)
	mover:SetFrameStrata('BACKGROUND')
	mover:SetFrameLevel(chatPanel:GetFrameLevel() + 2)
	mover:RegisterForDrag('LeftButton')
	local highlight = mover:CreateTexture(nil, 'ARTWORK')
	highlight:SetAllPoints()
	highlight:SetColorTexture(theme.GetAccent())
	highlight:SetAlpha(0)
	mover._hl = highlight
	mover:SetScript('OnEnter', BUI.Profiler.Script('Skin.Chat mover OnEnter', function(self) self._hl:SetAlpha(0.18) end))
	mover:SetScript('OnLeave', BUI.Profiler.Script('Skin.Chat mover OnLeave', function(self) self._hl:SetAlpha(0) end))
	mover:SetScript('OnDragStart', BUI.Profiler.Script('Skin.Chat mover OnDragStart', function()
		if InCombatLockdown() then return end
		chat:SetClampRectInsets(0, 0, 0, 0)
		chat:SetMovable(true)
		chat:StartMoving()
	end))
	mover:SetScript('OnDragStop', BUI.Profiler.Script('Skin.Chat mover OnDragStop', function()
		chat:StopMovingOrSizing()
		SaveGeometry(chat)
	end))
	UpdateMover()
end

local function PositionSizer()
	if not sizer then return end
	local thickness = BorderThickness()
	sizer:ClearAllPoints()
	sizer:SetPoint('TOPRIGHT', chatPanel, 'TOPRIGHT', -thickness - 1, -thickness - 1)
	sizer._handle = 'TOPRIGHT'
	sizer._grip:SetTexCoord(0, 1, 1, 0)
end

function UpdateSizer()
	if not sizer then return end
	PositionSizer()
	if SizerEnabled() and not Locked() then sizer:Show() else sizer:Hide() end
end

local function CreateSizer()
	if sizer then return end
	local chat = ChatFrame1
	sizer = CreateFrame('Frame', 'BUI_ChatSizer', UIParent)
	sizer:SetFrameStrata('MEDIUM')
	sizer:SetSize(16, 16)
	sizer:SetFrameLevel(chat:GetFrameLevel() + 8)
	sizer:EnableMouse(true)
	sizer:SetAlpha(SIZER_IDLE_ALPHA)

	local grip = sizer:CreateTexture(nil, 'OVERLAY')
	grip:SetTexture(BUILib.GetLibMedia('grabber'))
	grip:SetAllPoints()
	sizer._grip = grip

	local function GripColor(accent)
		if accent then
			grip:SetVertexColor(theme.GetAccent())
		else
			grip:SetVertexColor(0.65, 0.65, 0.7, 1)
		end
	end
	GripColor(false)

	sizer:SetScript('OnEnter', BUI.Profiler.Script('Skin.Chat sizer OnEnter', function(self) self:SetAlpha(1); GripColor(true) end))
	sizer:SetScript('OnLeave', BUI.Profiler.Script('Skin.Chat sizer OnLeave', function(self) self:SetAlpha(SIZER_IDLE_ALPHA); GripColor(false) end))
	sizer:SetScript('OnMouseDown', BUI.Profiler.Script('Skin.Chat sizer OnMouseDown', function(self)
		if InCombatLockdown() then return end
		chat:SetClampRectInsets(0, 0, 0, 0)
		chat:SetResizable(true)
		chat:StartSizing(self._handle)
	end))
	sizer:SetScript('OnMouseUp', BUI.Profiler.Script('Skin.Chat sizer OnMouseUp', function()
		chat:StopMovingOrSizing()
		SaveGeometry(chat)
	end))
	UpdateSizer()
end

local function ChatMaxScrollOffset(chat)
	local count = chat:GetNumMessages()
	if count <= 1 then return 0 end
	local frameHeight = chat:GetHeight()
	if frameHeight <= 0 then return count - 1 end
	local measure = chat._buiMeasure
	if not measure then
		measure = chat:CreateFontString(nil, 'BACKGROUND')
		measure:Hide()
		measure:SetNonSpaceWrap(true)
		chat._buiMeasure = measure
	end
	measure:SetFont(chat:GetFont())
	measure:SetWidth(chat:GetWidth())
	local lineHeight = max(1, measure:GetLineHeight())
	local spacing = measure:GetSpacing()
	local buffer = chat.historyBuffer
	local filled = 0
	for messageIndex = count, 1, -1 do
		local entry = buffer:GetEntryAtIndex(messageIndex)
		local height = lineHeight
		if entry and entry.message ~= nil then
			measure:SetText(entry.message)
			local measured = measure:GetStringHeight()
			if measured and not issecretvalue(measured) and measured > 0 then height = measured end
		end
		if filled + height > frameHeight then return messageIndex end
		filled = filled + height + spacing
	end
	return 0
end

local function SetupScroll(frame)
	if frame._buiScroll then return end
	frame._buiScroll = true
	frame:SetScript('OnMouseWheel', BUI.Profiler.Script('Skin.Chat frame OnMouseWheel', function(self, delta)
		if not Enabled() then
			if delta > 0 then self:ScrollUp() else self:ScrollDown() end
			return
		end
		if IsControlKeyDown() then
			local config = GetConfig()
			local currentSize = config.fontSize
			local newSize = min(22, max(8, currentSize + (delta > 0 and 1 or -1)))
			if newSize ~= currentSize then
				config.fontSize = newSize
				ApplyMsgFontSize()
			end
			return
		end
		if IsShiftKeyDown() then
			if delta > 0 then self:ScrollToTop() else self:ScrollToBottom() end
		else
			local lines = ScrollLines()
			if delta > 0 then
				for _ = 1, lines do self:ScrollUp() end
			else
				for _ = 1, lines do self:ScrollDown() end
			end
		end
		if delta > 0 then
			local maxOffset = ChatMaxScrollOffset(self)
			if self:GetScrollOffset() > maxOffset then self:SetScrollOffset(maxOffset) end
		end
		if FadeEnabled() then fadeState.lastActive = GetTime(); StartFader() end
	end))
	frame:EnableMouseWheel(true)
	frame:EnableMouse(true)
	frame:HookScript('OnEnter', BUI.Profiler.Wrap('Skin.Chat frame OnEnter', function()
		if Enabled() then StartFader() end
	end))
	local editBox = EditBoxOf(frame)
	if not editBox._buiFadeHook then
		editBox._buiFadeHook = true
		editBox:HookScript('OnEditFocusGained', BUI.Profiler.Wrap('Skin.Chat editBox OnEditFocusGained 2', function()
			if not Enabled() then return end
			if FadeEnabled() then fadeState.lastActive = GetTime() end
			StartFader()
		end))
		editBox:HookScript('OnTextChanged', BUI.Profiler.Wrap('Skin.Chat editBox OnTextChanged 2', function(self, userInput)
			if not userInput or not Enabled() then return end
			local text = self:GetText()
			if issecretvalue(text) or not TARGET_TELL_COMMANDS[text:lower()] then return end
			if not UnitExists('target') or not UnitIsPlayer('target') then return end
			local name = GetUnitName('target', true)
			if not name or name == '' then return end
			self:SetText('/w ' .. name .. ' ')
		end))
	end
	frame:SetMouseClickEnabled(true)
	frame:SetMouseMotionEnabled(true)
	frame:SetHyperlinksEnabled(true)
	if not frame._buiLinkHover then
		frame._buiLinkHover = true
		frame:HookScript('OnHyperlinkEnter', BUI.Profiler.Wrap('Skin.Chat frame OnHyperlinkEnter', function(self, link)
			if not Enabled() then return end
			if not GetConfig().hoverTooltips then return end
			if issecretvalue(link) or type(link) ~= 'string' then return end
			local linkType = link:match('^([^:]+)')
			if not HOVER_LINK_TYPES[linkType] then return end
			GameTooltip:SetOwner(self, 'ANCHOR_CURSOR')
			local shown = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
			if shown then GameTooltip:Show() else GameTooltip:Hide() end
		end))
		frame:HookScript('OnHyperlinkLeave', BUI.Profiler.Wrap('Skin.Chat frame OnHyperlinkLeave', function()
			GameTooltip:Hide()
		end))
	end
end

local function ScrollMetrics(chat)
	local messageCount = chat:GetNumMessages()
	local _, fontSize = chat:GetFont()
	local lineHeight = max(1, fontSize + chat:GetSpacing())
	local visible = max(1, floor(chat:GetHeight() / lineHeight))
	return messageCount, visible, ChatMaxScrollOffset(chat)
end

local function PositionScrollBar(chat)
	local scrollBar = chat._buiSB
	local thickness = BorderThickness()
	local offsetX = InsetX() + SCROLL_GUTTER - thickness - BAR_WIDTH - 4
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint('TOP', chat, 'TOPRIGHT', offsetX, -(thickness + 2))
	scrollBar:SetPoint('BOTTOM', chat, 'BOTTOMRIGHT', offsetX, -InsetBottom() + thickness + 2)
end

local function CreateChatScrollBar(chat)
	if chat._buiSB then return end
	local lastOffset, lastCount, lastHeight
	local scrollBar = CreateScrollBar(chat, 'Skin.Chat scrollbar', {
		minThumb = 16,
		Unchanged = function(trackHeight)
			local offset, messageCount = chat:GetScrollOffset(), chat:GetNumMessages()
			if offset == lastOffset and messageCount == lastCount and trackHeight == lastHeight then return true end
			lastOffset, lastCount, lastHeight = offset, messageCount, trackHeight
			return false
		end,
		Read = function()
			local messageCount, visible, maxOffset = ScrollMetrics(chat)
			if maxOffset <= 0 then return end
			return visible / messageCount, Clamp01(1 - chat:GetScrollOffset() / maxOffset)
		end,
		Seek = function(fraction)
			local _, _, maxOffset = ScrollMetrics(chat)
			chat:SetScrollOffset(floor((1 - fraction) * maxOffset + 0.5))
		end,
	})
	scrollBar:SetFrameLevel(chat:GetFrameLevel() + 6)
	chat._buiSB = scrollBar
	PositionScrollBar(chat)

	local Update = scrollBar._update
	for _, methodName in ipairs({ 'SetScrollOffset', 'ScrollUp', 'ScrollDown', 'ScrollToTop', 'ScrollToBottom', 'PageUp', 'PageDown' }) do
		Hook(chat, methodName, Update)
	end
	chat:HookScript('OnSizeChanged', Wrap('Skin.Chat scrollbar resize', Update))
	Update()
end

local function IsChatHovered()
	if chatPanel and chatPanel:IsMouseOver() then return true end
	if mover and mover:IsShown() and mover:IsMouseOver() then return true end
	for frameIndex = 1, #skinnedFrames do
		local chatFrame = skinnedFrames[frameIndex]
		if chatFrame:IsShown() and chatFrame:IsMouseOver() then return true end
		local editBox = EditBoxOf(chatFrame)
		if editBox:IsShown() and (editBox:HasFocus() or editBox:IsMouseOver()) then return true end
	end
	for tabIndex = 1, #skinnedTabs do
		local tab = skinnedTabs[tabIndex]
		if tab:IsShown() and tab:IsMouseOver() then return true end
	end
	return false
end

local function ApplyFadeAlpha(alpha)
	if chatPanel then chatPanel:SetAlpha(alpha) end
	for frameIndex = 1, #skinnedFrames do skinnedFrames[frameIndex]:SetAlpha(alpha) end
	for tabIndex = 1, #skinnedTabs do ApplyTabAlpha(skinnedTabs[tabIndex]) end
end

function StopFader()
	if fader then fader:SetScript('OnUpdate', nil) end
	fadeState.target = nil
	fadeState.lastHovered = nil
	if fadeState.alpha ~= 1 then
		fadeState.alpha = 1
		ApplyFadeAlpha(1)
		UpdateCornerButtons()
	end
end

function StartFader()
	if not fader then
		fader = CreateFrame('Frame')
		local accumulated = 0
		fader._handler = Wrap('Skin.Chat fader', function(_, elapsed)
			accumulated = accumulated + elapsed
			local animating = fadeState.target ~= nil and fadeState.alpha ~= fadeState.target
			if accumulated < 0.1 and not animating then return end
			accumulated = 0
			if not Enabled() then StopFader() return end
			local gutter = chatPanel and chatPanel._gutter
			local hovered = (gutter and gutter:IsMouseOver()) and true or false
			if hovered ~= fadeState.lastHovered then
				fadeState.lastHovered = hovered
				UpdateCornerButtons()
			end
			if not FadeEnabled() then
				fadeState.target = nil
				if fadeState.alpha ~= 1 then
					fadeState.alpha = 1
					ApplyFadeAlpha(1)
					UpdateCornerButtons()
				end
				if not hovered then StopFader() end
				return
			end
			local now = GetTime()
			if IsChatHovered() then fadeState.lastActive = now end
			local target = (now - fadeState.lastActive) < FadeDelay() and 1 or 0
			fadeState.target = target
			local alpha = fadeState.alpha
			if alpha < target then alpha = min(target, alpha + elapsed * 4)
			elseif alpha > target then alpha = max(target, alpha - elapsed * 1.5) end
			if alpha ~= fadeState.alpha then
				fadeState.alpha = alpha
				ApplyFadeAlpha(alpha)
				UpdateCornerButtons()
			end
			if target == 0 and alpha == 0 then
				fader:SetScript('OnUpdate', nil)
			end
		end)
	end
	if not fader:GetScript('OnUpdate') then
		fader:SetScript('OnUpdate', fader._handler)
	end
end

local function TrackFrame(chat)
	for frameIndex = 1, #skinnedFrames do
		if skinnedFrames[frameIndex] == chat then return end
	end
	skinnedFrames[#skinnedFrames + 1] = chat
end

local function SkinChatFrame(chat)
	local name = chat:GetName()
	TrackFrame(chat)
	HookAddMessage(chat)
	SetupScroll(chat)
	CreateChatScrollBar(chat)

	if not chat._buiStripped then
		chat._buiStripped = true
		Skin3.StripTextures(chat)
		if chat.Background then
			chat.Background:Hide()
			StayHidden(chat.Background, '_buiKilled', Always)
		end
		chat:SetClampRectInsets(0, 0, 0, 0)
		ApplyChatFont(chat)
	end

	HideTexture(_G[name .. 'ThumbTexture'])
	Kill(chat.ScrollBar)
	Kill(chat.ScrollToBottomButton)
	ManageHidden(chat.buttonFrame, true)

	SkinTab(TabOf(chat), chat)
	SkinEditBox(EditBoxOf(chat), chat)
end

local function SkinAllChatFrames()
	for _, frameName in ipairs(CHAT_FRAMES) do SkinChatFrame(_G[frameName]) end
end

function ApplyMsgFontSize()
	for frameIndex = 1, #skinnedFrames do ApplyChatFont(skinnedFrames[frameIndex]) end
end

local PlaceAuxButton, RestoreAuxButton, RepositionAuxButtons
local RepositionAuxLater = BUI.Dispatcher.New(function() RepositionAuxButtons() end, 'Skin.Chat aux buttons')

do
	local AUX_BUTTON_SIZE = 14
	local MENU_GLYPH = 'more'
	local FRIENDS_GLYPH = 'profile'
	local VOICE_BUTTON_NAMES = { ChatFrameChannelButton = true, ChatFrameToggleVoiceDeafenButton = true, ChatFrameToggleVoiceMuteButton = true }
	local FRIENDS_ART = { FriendsButton = 'quickjoin-button-friendslist-up', QueueButton = 'quickjoin-button-quickjoin-up', FlashingLayer = 'quickjoin-button-quickjoin-up' }
	local FRIENDS_COUNTS = { 'FriendCount', 'QueueCount' }

	local function SetArtAlpha(alpha, ...)
		for index = 1, select('#', ...) do
			local texture = select(index, ...)
			if texture then texture:SetAlpha(alpha) end
		end
	end

	local function ButtonArt(button)
		return button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture()
	end

	local function FillButton(texture)
		texture:ClearAllPoints()
		texture:SetAllPoints()
	end

	local function Glyph(button)
		local glyph = button._buiGlyph
		if not glyph then
			glyph = button:CreateTexture(nil, 'OVERLAY')
			button._buiGlyph = glyph
		end
		FillButton(glyph)
		glyph:Show()
		return glyph
	end

	local function KeepFriendsArtBlank(texture)
		if auxPainters[QuickJoinToastButton] then texture:SetTexture(nil) end
	end

	local function SkinMenuButton(button)
		SetArtAlpha(0, ButtonArt(button))
		local glyph = Glyph(button)
		glyph:SetTexture(BUILib.GetLibMedia(MENU_GLYPH))
		return function(red, green, blue, alpha)
			glyph:SetVertexColor(red, green, blue, 1)
			button:SetAlpha(alpha)
		end
	end

	local function SkinVoiceButton(button)
		SetArtAlpha(0, ButtonArt(button))
		button.Icon:SetDesaturated(true)
		FillButton(button.Icon)
		if not button._buiVoiceHook then
			button._buiVoiceHook = true
			local function HideHighlight(self)
				if auxPainters[self] then SetArtAlpha(0, self:GetHighlightTexture()) end
			end
			Hook(button, 'SetHighlight', HideHighlight)
			Hook(button, 'UpdateHighlight', HideHighlight)
		end
		return function(red, green, blue, alpha)
			button.Icon:SetVertexColor(red, green, blue, 1)
			button:SetAlpha(alpha)
		end
	end

	local function SkinFriendsButton(button)
		for key in pairs(FRIENDS_ART) do
			local texture = button[key]
			texture:SetTexture(nil)
			if not texture._buiBlankHook then
				texture._buiBlankHook = true
				Hook(texture, 'SetAtlas', KeepFriendsArtBlank)
			end
		end
		for _, key in ipairs(FRIENDS_COUNTS) do button[key]:Hide() end
		local glyph = Glyph(button)
		glyph:SetTexture(BUILib.GetLibMedia(FRIENDS_GLYPH))
		return function(red, green, blue, alpha)
			glyph:SetVertexColor(red, green, blue, alpha)
		end
	end

	local function SkinAuxButton(button)
		local name = button:GetName()
		if name == 'ChatFrameMenuButton' then return SkinMenuButton(button) end
		if name == 'QuickJoinToastButton' then return SkinFriendsButton(button) end
		if VOICE_BUTTON_NAMES[name] then return SkinVoiceButton(button) end
	end

	local function HookAuxHover(button)
		if button._buiAuxHover then return end
		button._buiAuxHover = true
		button:HookScript('OnEnter', Wrap('Skin.Chat aux OnEnter', function(self)
			if not auxPainters[self] then return end
			TouchFader()
		end))
		button:HookScript('OnLeave', Wrap('Skin.Chat aux OnLeave', function(self)
			if auxPainters[self] then UpdateCornerButtons() end
		end))
	end

	local function UnskinAuxButton(button)
		if not auxPainters[button] then return end
		auxPainters[button] = nil
		button:SetAlpha(1)
		SetArtAlpha(1, ButtonArt(button))
		if button._buiGlyph then button._buiGlyph:Hide() end
		if VOICE_BUTTON_NAMES[button:GetName()] then
			button.Icon:SetDesaturated(false)
			button.Icon:SetVertexColor(1, 1, 1, 1)
			button.Icon:ClearAllPoints()
			button.Icon:SetPoint('CENTER')
			button.Icon:SetSize(button.fixedIconWidth, button.fixedIconHeight)
		elseif button == QuickJoinToastButton then
			for key, atlas in pairs(FRIENDS_ART) do button[key]:SetAtlas(atlas) end
			for _, key in ipairs(FRIENDS_COUNTS) do button[key]:Show() end
		end
	end

	function PlaceAuxButton(button, previous, gap)
		button._buiOrigParent = button._buiOrigParent or button:GetParent()
		button:SetParent(chatPanel)
		button:SetFrameLevel(chatPanel:GetFrameLevel() + 10)
		button:ClearAllPoints()
		button:SetPoint('TOP', previous, 'BOTTOM', 0, -(gap or 5))
		button:SetSize(AUX_BUTTON_SIZE, AUX_BUTTON_SIZE)
		if button.UpdateVisibleState then button:UpdateVisibleState() end
		if not auxPainters[button] then
			auxPainters[button] = SkinAuxButton(button)
			HookAuxHover(button)
		end
		if not button._buiAuxRelayout then
			button._buiAuxRelayout = true
			button:HookScript('OnShow', RepositionAuxLater)
			button:HookScript('OnHide', RepositionAuxLater)
		end
		return button:IsShown() and button or previous
	end

	function RestoreAuxButton(button)
		UnskinAuxButton(button)
		if button._buiOrigParent then
			button:SetParent(button._buiOrigParent)
			button._buiOrigParent = nil
		end
	end
end

function RepositionAuxButtons()
	if not Enabled() or not chatPanel then return end
	local previous = ChatFrame1._buiLock
	if not HideVoiceButtons() then
		previous = PlaceAuxButton(ChatFrameChannelButton, previous, 8)
		previous = PlaceAuxButton(ChatFrameToggleVoiceDeafenButton, previous)
		previous = PlaceAuxButton(ChatFrameToggleVoiceMuteButton, previous)
	end
	if not HideButtons() then
		previous = PlaceAuxButton(ChatFrameMenuButton, previous, 8)
		previous = PlaceAuxButton(QuickJoinToastButton, previous)
	end
	UpdateCornerButtons()
end

local function ApplyTimestampCVar()
	local config = GetConfig()
	if Enabled() and config.timestamps then
		local currentValue = GetCVar('showTimestamps')
		if currentValue and currentValue ~= 'none' then config.blizzTimestamps = currentValue end
		SetCVar('showTimestamps', 'none')
	elseif config.blizzTimestamps then
		SetCVar('showTimestamps', config.blizzTimestamps)
		config.blizzTimestamps = nil
	end
end

local function PulseText(tab)
	local overlay = tab._buiPulseText
	if overlay then return overlay end
	overlay = tab:CreateFontString(nil, 'OVERLAY')
	overlay:SetAllPoints(tab._buiText)
	overlay:Hide()
	local fade = overlay:CreateAnimationGroup()
	fade:SetLooping('BOUNCE')
	local alpha = fade:CreateAnimation('Alpha')
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(0)
	alpha:SetDuration(TAB_PULSE_HALF_PERIOD)
	alpha:SetSmoothing('IN_OUT')
	overlay.fade = fade
	tab._buiPulseText = overlay
	return overlay
end

local function StopTabPulse(tab)
	if not tab._buiPulse then return end
	tab._buiPulse.fade:Stop()
	tab._buiPulse:Hide()
	tab._buiPulse = nil
	ApplyTabColor(tab, IsTabSelected(tab))
	ApplyTabAlpha(tab)
end

local function StartTabPulse(tab)
	if tab._buiPulse or IsTabSelected(tab) then return end
	local text = tab._buiText
	local overlay = PulseText(tab)
	overlay:SetFont(text:GetFont())
	overlay:SetShadowOffset(text:GetShadowOffset())
	overlay:SetShadowColor(text:GetShadowColor())
	overlay:SetJustifyH(text:GetJustifyH())
	overlay:SetWordWrap(false)
	overlay:SetText(text:GetText())
	overlay:SetTextColor(FlashColor())
	tab._buiPulse = overlay
	ApplyTabColor(tab, false)
	ApplyTabAlpha(tab)
	overlay:Show()
	overlay.fade:Play()
end

local function RefreshTabPulses()
	for tabIndex = 1, #skinnedTabs do
		local tab = skinnedTabs[tabIndex]
		if tab._buiPulse then
			StopTabPulse(tab)
			if TabFlash() then StartTabPulse(tab) end
		end
	end
end

local function ApplySettings()
	if not installed or not Enabled() then return end

	AnchorPanel()
	ApplyPanelFill()
	ApplyBorder()
	ApplyTopStrip()
	ApplyRightStrip()
	NormalizeDock()
	ApplyTimestampCVar()

	for frameIndex = 1, #skinnedFrames do
		local chatFrame = skinnedFrames[frameIndex]
		ApplyChatFont(chatFrame)
		ApplyShadow(chatFrame)
		chatFrame:SetClampRectInsets(0, 0, 0, 0)
		chatFrame:SetFading(MsgFade())
		chatFrame:SetTimeVisible(MsgFadeTime())
		PositionEditBox(chatFrame)
		PositionScrollBar(chatFrame)
		chatFrame._buiSB._update()
		StyleEditBox(EditBoxOf(chatFrame))
	end

	ManageHidden(ChatFrameMenuButton, HideButtons())
	ManageHidden(QuickJoinToastButton, HideButtons())
	ManageHidden(ChatFrameChannelButton, HideVoiceButtons())
	ManageHidden(ChatFrameToggleVoiceDeafenButton, HideVoiceButtons())
	ManageHidden(ChatFrameToggleVoiceMuteButton, HideVoiceButtons())
	CollapseChatTab(ChatFrame2Tab, HideLogTab())
	RefreshTabs()
	RefreshTabPulses()

	RepositionAuxButtons()

	UpdateCopyButton()
	UpdateMover()
	UpdateSizer()
	ChatFrame1._buiLock.Refresh()

	if FadeEnabled() then StartFader() else StopFader() end
end

local function Refresh()
	if not Enabled() then return end
	SkinPanel()
	CreateMover()
	CreateSizer()
	RegisterURLHandler()
	SkinAllChatFrames()
	ApplySettings()
	RestoreGeometry()
	After('Skin.Chat restore layout', 0.5, RestoreGeometry)
end

local chatHiddenActive = false
local chatPreviouslyShown = {}
local chatHideHooksInstalled = false

local CHAT_HIDE_EXTRAS = {
	'GeneralDockManager', 'QuickJoinToastButton', 'ChatFrameMenuButton',
	'ChatFrameChannelButton', 'TextToSpeechButtonFrame', 'CombatLogQuickButtonFrame_Custom',
}

local function CollectChatHideTargets()
	local targets = {}
	for _, frameName in ipairs(CHAT_FRAMES) do
		local frame = _G[frameName]
		targets[#targets + 1] = frame
		targets[#targets + 1] = TabOf(frame)
		targets[#targets + 1] = frame.buttonFrame
	end
	for _, extraName in ipairs(CHAT_HIDE_EXTRAS) do
		local extra = _G[extraName]
		if extra then targets[#targets + 1] = extra end
	end
	return targets
end

local function ChatHiddenWanted(frame)
	return chatHiddenActive and Enabled() and frame:IsShown()
end

local function ApplyChatHidden()
	local hidden = GetConfig().chatHidden and Enabled()
	chatHiddenActive = hidden
	local targets = CollectChatHideTargets()
	if hidden then
		if not chatHideHooksInstalled then
			chatHideHooksInstalled = true
			Hook('ChatEdit_ActivateChat', function(editBox)
				if chatHiddenActive then ChatEdit_DeactivateChat(editBox) end
			end)
		end
		for _, frame in ipairs(targets) do
			StayHidden(frame, '_buiChatHideHook', ChatHiddenWanted)
			if frame:IsShown() then chatPreviouslyShown[frame] = true end
			frame:Hide()
		end
	else
		for _, frame in ipairs(targets) do
			if chatPreviouslyShown[frame] then frame:Show() end
		end
		wipe(chatPreviouslyShown)
		FCF_DockUpdate()
	end
end

local conflictWarned = false
local function Install()
	if not Enabled() or installed then return end
	for _, name in ipairs({ 'Chattynator', 'Prat-3.0', 'Glass', 'ls_Glass' }) do
		if C_AddOns.IsAddOnLoaded(name) then
			if not conflictWarned then
				conflictWarned = true
				BUI.Print('Chat skin off, ' .. name .. ' owns chat. Disable it and /reload.')
			end
			return
		end
	end
	installed = true
	Refresh()

	Hook('FCFTab_UpdateColors', function(tab, selected)
		if not Enabled() or not tab._buiChat then return end
		if selected == nil then selected = IsTabSelected(tab) end
		if selected then StopTabPulse(tab) end
		ApplyTabColor(tab, selected)
		ApplyTabAlpha(tab)
	end)

	Hook('FCFDock_UpdateTabs', AlignDockTabs)

	Hook('FCF_StartAlertFlash', function(chatFrame)
		if not (Enabled() and TabFlash()) then return end
		local tab = TabOf(chatFrame)
		if tab._buiChat then StartTabPulse(tab) end
	end)

	Hook('FCF_StopAlertFlash', function(chatFrame)
		StopTabPulse(TabOf(chatFrame))
	end)

	Hook('FCF_SetChatWindowFontSize', function(_, chat, size)
		if not Enabled() then return end
		chat = chat or FCF_GetCurrentChatFrame()
		if not chat then return end
		if size then GetConfig().fontSize = size end
		local _, curSize = chat:GetFont()
		ApplyChatFont(chat, size or curSize)
	end)

	Hook('FCF_RestorePositionAndDimensions', function(chat)
		if not Enabled() then return end
		if chat == ChatFrame1 then RestoreGeometry(); NormalizeDock() end
	end)

	Hook(ChatAlertFrame, 'UpdateAnchors', RepositionAuxLater)

	local geometryReassertPending = false
	local function ReassertGeometry()
		if geometryReassertPending or not Enabled() then return end
		geometryReassertPending = true
		After('Skin.Chat reassert geometry', 0, function()
			geometryReassertPending = false
			if not Enabled() or GeometryMatches() then return end
			RestoreGeometry()
			NormalizeDock()
			AnchorPanel()
			local chat = ChatFrame1
			PositionEditBox(chat)
			PositionScrollBar(chat)
			UpdateMover()
			UpdateSizer()
		end)
	end
	BUI.Events:Register('EDIT_MODE_LAYOUTS_UPDATED', 'Skinning.Chat', ReassertGeometry)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skinning.Chat', ReassertGeometry)

	local chat1 = ChatFrame1
	local function OnExternalMove()
		if chat1._buiRestoringGeo then return end
		ReassertGeometry()
	end
	Hook(chat1, 'SetPoint', OnExternalMove)
	Hook(chat1, 'SetSize', OnExternalMove)
	Hook(chat1, 'SetWidth', OnExternalMove)
	Hook(chat1, 'SetHeight', OnExternalMove)
end

Hook('FCF_OpenTemporaryWindow', function()
	if chatHiddenActive then ApplyChatHidden() end
	if not installed then return end
	After('Skin.Chat temp window', 0, function()
		if not Enabled() then return end
		SkinAllChatFrames()
		RefreshTabs()
	end)
end)

BUI.Events:OnLogin('Skinning.Chat', Install)

local function Deactivate()
	chatPanel:Hide()
	mover:Hide()
	sizer:Hide()
	StopFader()
	fadeState.alpha = 1
	local chat = ChatFrame1
	chat._buiCog:Hide()
	chat._buiCopy:Hide()
	chat._buiLock:Hide()
	for frameIndex = 1, #skinnedFrames do
		local chatFrame = skinnedFrames[frameIndex]
		chatFrame:SetAlpha(1)
		chatFrame._buiSB:Hide()
		ManageHidden(chatFrame.buttonFrame, false)
	end
	for tabIndex = 1, #skinnedTabs do
		local tab = skinnedTabs[tabIndex]
		StopTabPulse(tab)
		tab:SetAlpha(1, true)
		tab._buiLine:Hide()
		tab._buiGlow:Hide()
		tab._buiFill:Hide()
		tab._buiText:SetTextColor(1, 0.82, 0)
	end
	RestoreAuxButton(ChatFrameMenuButton)
	RestoreAuxButton(QuickJoinToastButton)
	RestoreAuxButton(ChatFrameChannelButton)
	RestoreAuxButton(ChatFrameToggleVoiceDeafenButton)
	RestoreAuxButton(ChatFrameToggleVoiceMuteButton)
	ManageHidden(ChatFrameMenuButton, false)
	ManageHidden(QuickJoinToastButton, false)
	ManageHidden(ChatFrameChannelButton, false)
	ManageHidden(ChatFrameToggleVoiceDeafenButton, false)
	ManageHidden(ChatFrameToggleVoiceMuteButton, false)
	CollapseChatTab(ChatFrame2Tab, false)
	ApplyTimestampCVar()
end

local function Reactivate()
	chatPanel:Show()
	local chat = ChatFrame1
	chat._buiCog:Show()
	chat._buiLock:Show()
	for frameIndex = 1, #skinnedFrames do skinnedFrames[frameIndex]._buiSB:Show() end
	Refresh()
end

Skin.OnToggle('chat', function(enabled)
	if enabled then
		if installed then Reactivate() else Install() end
	elseif installed then
		Deactivate()
	end
	if not enabled and chatHiddenActive then ApplyChatHidden() end
end)

BUI.Events:OnLogin('Skinning.ChatHidden', function()
	if GetConfig().chatHidden then ApplyChatHidden() end
end)

local function BuildTextureItems()
	local items = { { value = 'SOLID', text = 'Solid Color' } }
	for _, name in ipairs(sharedMedia:List('statusbar')) do items[#items + 1] = { value = name, text = name } end
	return items
end

local function ResetToDefaults()
	local config = GetConfig()
	for key, value in pairs(BUI.Defaults.profile.skinning.chatSettings) do
		if type(value) == 'table' then
			local copiedTable = {}
			for valueIndex = 1, #value do copiedTable[valueIndex] = value[valueIndex] end
			config[key] = copiedTable
		else
			config[key] = value
		end
	end
	ApplySettings()
end

Skin.RegisterSkin('chat', {
	name = 'Chat',
	description = 'Dark panel behind the chat dock, with timestamps, copy chat, abbreviations, and fading.',
	icon = 'Interface\\Icons\\UI_Chat',
	page = 'chat',
	reset = ResetToDefaults,
	buildBoards = function(ui, parent, width)
		local config = GetConfig()

		local function Store(key)
			return function(value) config[key] = value end
		end
		local function Slider(label, key, read, low, high, step)
			return { label = label, min = low, max = high, step = step or 1, get = read, set = Store(key) }
		end
		local function Percent(label, key, read, low)
			return { label = label, min = low, max = 100, step = 1, get = function() return floor(read() * 100 + 0.5) end, set = function(value) config[key] = value / 100 end }
		end
		local function Check(label, key, read)
			return { label = label, get = read, set = Store(key) }
		end
		local function Choice(label, key, entries, read)
			return { label = label, entries = entries, get = read, set = Store(key) }
		end
		local function Color(tooltip, key, read)
			return { kind = 'swatch', tooltip = tooltip, get = function()
				local red, green, blue = read()
				return red, green, blue, 1
			end, set = function(red, green, blue) config[key] = { red, green, blue } end }
		end
		local function Cog(tooltip, title, options, icon)
			return { icon = icon, tooltip = tooltip, title = title, options = options }
		end
		local function Switch(read, key)
			return { get = read, set = Store(key) }
		end

		local function ChatGeo()
			local chatFrame = ChatFrame1
			local frameWidth, frameHeight = chatFrame:GetSize()
			return chatFrame, floor(frameWidth + 0.5), floor(frameHeight + 0.5), floor(chatFrame:GetLeft() + 0.5), floor(chatFrame:GetBottom() + 0.5)
		end
		local function SetGeo(part, value)
			if InCombatLockdown() then return end
			local chatFrame, frameWidth, frameHeight, x, y = ChatGeo()
			if part == 'w' then frameWidth = value elseif part == 'h' then frameHeight = value elseif part == 'x' then x = value else y = value end
			chatFrame:SetSize(frameWidth, frameHeight)
			chatFrame:ClearAllPoints()
			chatFrame:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', x, y)
			SaveGeometry(chatFrame)
		end
		local GEO_INDEX = { w = 2, h = 3, x = 4, y = 5 }
		local function Geo(part, label, low, high)
			return { label = label, min = low, max = high, step = 1, get = function() return (select(GEO_INDEX[part], ChatGeo())) end, set = function(value) SetGeo(part, value) end }
		end
		local screenWidth, screenHeight = floor(GetScreenWidth()), floor(GetScreenHeight())

		local function Applied(key)
			return function(value)
				config[key] = value
				ApplySettings()
			end
		end

		local panel = ui.Board(parent, width, { stacked = true, title = 'Panel', description = 'The panel behind the chat dock: font, background, border, edit box and where it sits.' })
		panel:AddTools('Font', 'Typeface, message and edit box size, outline and shadow', {
			Choice(nil, 'font', BUI.BuildFontDropdownItems(GLOBAL_OPTION), function() return config.font end),
			Cog('Sizes, outline and shadow', 'Font', {
				Slider('Message size', 'fontSize', MsgFontSize, 8, 22),
				Slider('Edit box size', 'editFontSize', EditFontSize, 8, 22),
				Choice('Outline', 'fontFlags', FLAG_OPTIONS, MsgFlags),
				Check('Shadow', 'fontShadow', FontShadow),
			}),
		}, ApplySettings)
		panel:AddTools('Background', 'Color, opacity and texture behind the messages', {
			{ kind = 'swatch', tooltip = 'Background color and opacity', opacity = true, get = BGColor, set = function(red, green, blue, alpha)
				config.bgColor = { red, green, blue }
				config.bgAlpha = alpha
			end },
			Choice(nil, 'bgTexture', BuildTextureItems(), BGTexture),
		}, ApplySettings)
		panel:AddTools('Border', 'The edge around the panel', {
			Color('Border color', 'borderColor', ColorReader('borderColor')),
			Cog('Thickness', 'Border', { Slider('Thickness', 'borderThickness', BorderThickness, 1, 4) }),
			Switch(function() return config.showBorder end, 'showBorder'),
		}, ApplySettings)
		panel:AddTools('Edit box', 'Where you type, and how tall it is', {
			Choice(nil, 'editboxPosition', EDITBOX_OPTIONS, EditBoxPos),
			Cog('Height', 'Edit box', { Slider('Height', 'editboxHeight', EditBoxHeight, 16, 40) }),
		}, ApplySettings)
		panel:AddTools('Layout', 'Where the panel sits, its size and padding, and how it moves', {
			Cog('Position on screen', 'Position', {
				Geo('x', 'From the left', 0, screenWidth),
				Geo('y', 'From the bottom', 0, screenHeight),
			}, 'location'),
			Cog('Size and padding', 'Size', {
				Geo('w', 'Width', 200, max(screenWidth, 400)),
				Geo('h', 'Height', 80, max(screenHeight, 200)),
				Slider('Side padding', 'insetX', InsetX, 0, 20),
				Slider('Top bar height', 'insetTop', InsetTop, 12, 40),
				Slider('Bottom padding', 'insetBottom', InsetBottom, 0, 20),
			}, 'resize'),
			Cog('Moving and resizing', 'Moving', {
				Check('Lock the frame', 'locked', Locked),
				Check('Drag the top bar to move', 'dragToMove', DragToMove),
				Check('Show the resize grip', 'showSizer', SizerEnabled),
			}),
		}, ApplySettings)

		local tabs = ui.Board(parent, width, { stacked = true, title = 'Tabs', description = 'The chat tabs along the top of the panel.' })
		tabs:AddTools('Style', 'Tab look, font and names', {
			Choice(nil, 'tabStyle', TAB_STYLE_OPTIONS, TabStyle),
			Cog('Font and names', 'Tabs', {
				Slider('Font size', 'tabFontSize', TabFontSize, 8, 18),
				Choice('Outline', 'tabFontFlags', FLAG_OPTIONS, TabFlags),
				Check('Uppercase names', 'tabUppercase', TabUppercase),
				Check('Hide the combat log tab', 'hideLogTab', HideLogTab),
			}),
		}, ApplySettings)
		tabs:AddTools('Colors', 'Background tabs, the active tab and how see-through they are', {
			Color('Background tabs', 'inactiveColor', InactiveColor),
			{ kind = 'swatch', tooltip = 'Active tab, turns off the theme accent', get = function()
				local red, green, blue = SelectedColor()
				return red, green, blue, 1
			end, set = function(red, green, blue)
				config.selectedColor = { red, green, blue }
				config.selectedUseAccent = false
			end },
			Cog('Opacity', 'Tab opacity', {
				Percent('Active tab', 'selectedAlpha', SelectedAlpha, 10),
				Percent('Background tabs', 'dockedAlpha', DockedAlpha, 0),
			}),
			Switch(function() return config.selectedUseAccent end, 'selectedUseAccent'),
		}, ApplySettings)
		tabs:AddTools('Flash on message', 'Pulse a background tab when a message arrives', {
			Color('Flash color', 'flashColor', FlashColor),
			Switch(TabFlash, 'tabFlash'),
		}, ApplySettings)

		local messages = ui.Board(parent, width, { stacked = true, title = 'Messages', description = 'What each line shows, fading, history and the side buttons.' })
		messages:AddSwitch('Timestamps', Reader('timestamps'), Applied('timestamps'), 'The time in front of each line')
		messages:AddSwitch('Clickable links', Reader('urlCopy'), Store('urlCopy'), 'Turn web addresses into links you can copy')
		messages:AddSwitch('Link tooltips', Reader('hoverTooltips'), Store('hoverTooltips'), 'Tooltips when hovering links')
		messages:AddSwitch('Hide channel numbers', Reader('hideChannelNumbers'), Store('hideChannelNumbers'))
		messages:AddSwitch('Abbreviate channel names', Reader('abbreviateChannels'), Store('abbreviateChannels'))
		messages:AddSwitch('Fade old messages', MsgFade, Applied('msgFade'), 'Messages fade out after a while')
		messages:AddSwitch('Fade when not hovered', FadeEnabled, function(value)
			config.mouseoverFade = value
			if value then StartFader() else StopFader() end
		end, 'The chat fades until the cursor is over it')
		messages:AddSwitch('Input history', EditHistory, Store('editHistory'), 'Up and down arrows step through what you typed')
		messages:AddSwitch('Copy chat button', ShowCopyButton, Applied('showCopyButton'))
		messages:AddSwitch('Hide menu and social buttons', HideButtons, Applied('hideButtons'))
		messages:AddSwitch('Hide voice buttons', HideVoiceButtons, Applied('hideVoiceButtons'))
		messages:AddSwitch('Hide chat completely', function() return config.chatHidden end, function(value)
			config.chatHidden = value
			ApplyChatHidden()
		end, 'Hide every chat window and tab')
		messages:AddTools('Details', 'Timestamp and link colors, timestamp format, scroll speed and fade timing', {
			Color('Timestamp color', 'timestampColor', ColorReader('timestampColor')),
			Color('Link color', 'urlColor', ColorReader('urlColor')),
			Cog('Format, scrolling and fade timing', 'Details', {
				Choice('Timestamp format', 'timestampFormat', TIMESTAMP_OPTIONS, Reader('timestampFormat')),
				Slider('Lines per scroll', 'scrollLines', ScrollLines, 1, 10, 1),
				{ label = 'Messages visible for (sec)', min = 10, max = 300, step = 5, separator = true, get = MsgFadeTime, set = Store('msgFadeTime') },
				Slider('Hover fade delay (sec)', 'fadeDelay', FadeDelay, 0, 10),
			}),
			{ text = 'Clear history', onClick = function() wipe(GetHistory()) end },
		}, ApplySettings)

		return { panel, tabs, messages }
	end,
})
