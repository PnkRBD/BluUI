local _, BUI = ...

local _G = _G
local tconcat = table.concat
local upper = string.upper
local find = string.find

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local theme = BUILib.Theme
local Skin3 = BUILib.Skin
local Skin = BUI.Skinning
local Controls = BUILib.Controls
local PageKit = BUILib.PageKit
local sharedMedia = LibStub and LibStub('LibSharedMedia-3.0', true)
local GLOBAL_OPTION = (BUI.C and BUI.C.GLOBAL_OPTION) or 'GLOBAL'

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

local DEFAULTS = {
	bgColor = { 0.06, 0.06, 0.06 }, bgAlpha = 0.82, bgTexture = 'SOLID',
	showBorder = true, borderColor = { 0, 0, 0 }, borderThickness = 1,
	insetX = 5, insetTop = 30, insetBottom = 5,
	font = GLOBAL_OPTION, fontSize = 14, fontFlags = '', editFontSize = 13, fontShadow = false,
	tabFontSize = 12, tabFontFlags = '', tabUppercase = false, tabStyle = 'UNDERLINE',
	selectedUseAccent = true, selectedColor = { 1, 1, 1 }, inactiveColor = { 0.82, 0.82, 0.85 },
	selectedAlpha = 1, dockedAlpha = 0.6, tabFlash = true, flashColor = { 1, 0.6, 0.1 }, hideLogTab = false,
	timestamps = false, timestampFormat = '%H:%M', timestampColor = { 0.6, 0.6, 0.6 },
	hideChannelNumbers = false, abbreviateChannels = false, scrollLines = 3,
	urlCopy = true, urlColor = { 0, 0.66, 1 }, hoverTooltips = true,
	editboxPosition = 'BOTTOM', editboxHeight = 22, editHistory = true, dragToMove = true, msgFade = false, msgFadeTime = 120,
	mouseoverFade = false, fadeDelay = 2, showSizer = true, sizerGrow = 'UP',
	hideButtons = true, hideVoiceButtons = true, showCopyButton = true,
	locked = false,
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
local chatPanel, panelSquare, sizer, fader, copyWindow, mover
local UpdateMover, UpdateSizer, ApplyMsgFontSize
local skinnedTabs = {}
local skinnedFrames = {}
local fadeState = { alpha = 1, lastActive = 0 }
local StartFader, StopFader
local TARGET_TELL_COMMANDS = { ['/t '] = true }
local TAB_STRATA = 'MEDIUM'
local TAB_LEVEL_LIFT = 10

local function LiftTab(tab, level)
	if not tab then return end
	tab:SetFrameStrata(TAB_STRATA)
	tab:SetFrameLevel(level)
end

local function Enabled() return Skin.IsSkinEnabled('chat') end

local function GetConfig()
	local db = BUI.GetDB()
	local skinning = db and db.skinning
	if not skinning then return nil end
	if not skinning.chatSettings then skinning.chatSettings = {} end
	return skinning.chatSettings
end

local function BGColor()
	local config = GetConfig()
	local color = (config and config.bgColor) or DEFAULTS.bgColor
	return color[1], color[2], color[3], (config and config.bgAlpha) or DEFAULTS.bgAlpha
end

local function BorderColor()
	local config = GetConfig()
	if config and config.showBorder == false then return 0, 0, 0, 0 end
	local color = (config and config.borderColor) or DEFAULTS.borderColor
	return color[1], color[2], color[3], 1
end

local function EditBoxBGColor()
	local config = GetConfig()
	local color = (config and config.bgColor) or DEFAULTS.bgColor
	return color[1], color[2], color[3], 1
end

local function SelectedColor()
	local config = GetConfig()
	if not config or config.selectedUseAccent ~= false then return theme.GetAccent() end
	local color = config.selectedColor or { 1, 1, 1 }
	return color[1], color[2], color[3]
end

local function ColorReader(key)
	return function()
		local config = GetConfig()
		local color = (config and config[key]) or DEFAULTS[key]
		return color[1], color[2], color[3]
	end
end
local InactiveColor = ColorReader('inactiveColor')
local FlashColor = ColorReader('flashColor')

local function ResolveFont()
	local config = GetConfig()
	local name = config and config.font
	if not name or name == GLOBAL_OPTION then
		return (BUI.GetGlobalFont and BUI.GetGlobalFont()) or BUILib.Font
	end
	return (sharedMedia and sharedMedia:Fetch('font', name)) or (BUI.GetGlobalFont and BUI.GetGlobalFont()) or BUILib.Font
end

local function NumReader(key)
	return function() local config = GetConfig(); return (config and config[key]) or DEFAULTS[key] end
end
local function StrReader(key)
	return function() local config = GetConfig(); return (config and config[key]) or DEFAULTS[key] end
end
local function BoolReader(key, defaultTrue)
	if defaultTrue then
		return function() local config = GetConfig(); return not config or config[key] ~= false end
	end
	return function() local config = GetConfig(); return config and config[key] end
end

local MsgFontSize = NumReader('fontSize')
local EditFontSize = NumReader('editFontSize')
local TabFontSize = NumReader('tabFontSize')
local SelectedAlpha = NumReader('selectedAlpha')
local DockedAlpha = NumReader('dockedAlpha')
local BorderThickness = NumReader('borderThickness')
local InsetX = NumReader('insetX')
local InsetTop = NumReader('insetTop')
local InsetBottom = NumReader('insetBottom')
local EditBoxHeight = NumReader('editboxHeight')
local ScrollLines = NumReader('scrollLines')
local MsgFadeTime = NumReader('msgFadeTime')
local FadeDelay = NumReader('fadeDelay')

local BGTexture = StrReader('bgTexture')

local FontShadow = BoolReader('fontShadow')
local TabUppercase = BoolReader('tabUppercase')
local TabFlash = BoolReader('tabFlash', true)
local HideLogTab = BoolReader('hideLogTab')
local EditHistory = BoolReader('editHistory', true)
local DragToMove = BoolReader('dragToMove', true)
local MsgFade = BoolReader('msgFade')
local FadeEnabled = BoolReader('mouseoverFade')
local SizerEnabled = BoolReader('showSizer', true)
local HideButtons = BoolReader('hideButtons', true)
local HideVoiceButtons = BoolReader('hideVoiceButtons', true)
local ShowCopyButton = BoolReader('showCopyButton', true)
local Locked = BoolReader('locked')

local function MsgFlags() local config = GetConfig(); return (config and config.fontFlags) or '' end
local function TabFlags() local config = GetConfig(); return (config and config.tabFontFlags) or '' end
local function EditBoxPos()
	local config = GetConfig()
	local position = (config and config.editboxPosition) or DEFAULTS.editboxPosition
	if position == 'BELOW' then return 'BOTTOM' elseif position == 'ABOVE' then return 'TOP' end
	return position
end

local function SetFontSafe(fontString, font, size, flags)
	if fontString and font then fontString:SetFont(font, size, flags or '') end
end

local function ApplyShadow(fontObject)
	if not fontObject or not fontObject.SetShadowColor then return end
	if FontShadow() then
		fontObject:SetShadowColor(0, 0, 0, 1); fontObject:SetShadowOffset(1, -1)
	else
		fontObject:SetShadowColor(0, 0, 0, 0); fontObject:SetShadowOffset(0, 0)
	end
end

local function HideTexture(texture)
	if not texture then return end
	if texture.SetTexture then texture:SetTexture(nil) end
	if texture.SetAtlas then texture:SetAtlas(nil) end
	if texture.SetAlpha then texture:SetAlpha(0) end
end

local function ManageHidden(frame, shouldHide)
	if not frame then return end
	if not frame._buiManageHook then
		frame._buiManageHook = true
		hooksecurefunc(frame, 'Show', function(shownFrame) if shownFrame._buiWantHidden then shownFrame:Hide() end end)
		hooksecurefunc(frame, 'SetShown', function(shownFrame, shown) if shown and shownFrame._buiWantHidden then shownFrame:Hide() end end)
	end
	frame._buiWantHidden = shouldHide
	if shouldHide then frame:Hide() else frame:Show() end
end

local HIDDEN_PARENT = CreateFrame('Frame')
HIDDEN_PARENT:Hide()
local function KillShow(frame) frame:Hide() end
local function Kill(frame)
	if not frame or frame._buiKilled then return end
	frame._buiKilled = true
	if frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
	frame:Hide()
	hooksecurefunc(frame, 'Show', KillShow)
	if frame.SetParent then frame:SetParent(HIDDEN_PARENT) end
end

local function SaveGeometry(chat)
	if chat:GetNumPoints() > 1 then return end
	local db = BUI.GetDB()
	db.chatGeometry = db.chatGeometry or {}
	local geometry = db.chatGeometry
	geometry.w, geometry.h = chat:GetSize()
	local point, _, relativePoint, x, y = chat:GetPoint(1)
	geometry.point, geometry.relPoint, geometry.x, geometry.y = point, relativePoint, x, y
	if _G.FCF_SavePositionAndDimensions then _G.FCF_SavePositionAndDimensions(chat) end
	if chat.SetClampRectInsets then chat:SetClampRectInsets(0, 0, 0, 0) end
	if BUI.Datatext and BUI.Datatext.Apply then BUI.Datatext.Apply() end
end

local function GeometryMatches()
	local chat = _G.ChatFrame1
	if not chat then return true end
	local geometry = BUI.GetDB().chatGeometry
	if not geometry or not geometry.w then return true end
	if chat:GetNumPoints() ~= 1 then return false end
	local point, relativeTo, relativePoint, x, y = chat:GetPoint(1)
	if point ~= geometry.point or relativePoint ~= (geometry.relPoint or geometry.point) or relativeTo ~= UIParent then return false end
	local width, height = chat:GetSize()
	return math.abs(width - geometry.w) < 0.5 and math.abs(height - geometry.h) < 0.5
		and math.abs((x or 0) - (geometry.x or 0)) < 0.5 and math.abs((y or 0) - (geometry.y or 0)) < 0.5
end

local function RestoreGeometry()
	local chat = _G.ChatFrame1
	if not chat then return end
	chat._buiRestoringGeo = true
	if chat.SetClampRectInsets then chat:SetClampRectInsets(0, 0, 0, 0) end
	local geometry = BUI.GetDB().chatGeometry
	if not geometry or not geometry.w then chat._buiRestoringGeo = false return end
	chat:SetUserPlaced(true)
	if chat.SetClampRectInsets then chat:SetClampRectInsets(0, 0, 0, 0) end
	chat:SetSize(geometry.w, geometry.h)
	if geometry.point then
		chat:ClearAllPoints()
		chat:SetPoint(geometry.point, UIParent, geometry.relPoint or geometry.point, geometry.x or 0, geometry.y or 0)
	end
	chat._buiRestoringGeo = false
end

local function NormalizeDock()
	local dock = _G.GeneralDockManager
	if not dock then return end
	local chat = _G.ChatFrame1
	local height = InsetTop()
	if chat then
		dock:ClearAllPoints()
		dock:SetPoint('BOTTOMLEFT', chat, 'TOPLEFT', 0, 0)
		dock:SetPoint('BOTTOMRIGHT', chat, 'TOPRIGHT', 0, 0)
	end
	dock:SetHeight(height)
	local level = ((chat and chat:GetFrameLevel()) or 5) + TAB_LEVEL_LIFT
	dock:SetFrameStrata(TAB_STRATA)
	dock:SetFrameLevel(level)
	local scrollFrame, scrollChild = _G.GeneralDockManagerScrollFrame, _G.GeneralDockManagerScrollFrameChild
	if scrollFrame then
		scrollFrame:SetHeight(height)
		scrollFrame:SetFrameStrata(TAB_STRATA)
		scrollFrame:SetFrameLevel(level + 1)
	end
	if scrollChild then
		scrollChild:SetHeight(height)
		scrollChild:SetFrameStrata(TAB_STRATA)
		scrollChild:SetFrameLevel(level + 2)
	end
	for tabIndex = 1, #skinnedTabs do LiftTab(skinnedTabs[tabIndex], level + 3) end
end

_G.StaticPopupDialogs['BUI_CHAT_URL'] = {
	text = 'Press Ctrl+C to copy the link:',
	button1 = _G.CLOSE or 'Close',
	hasEditBox = true,
	editBoxWidth = 350,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
	OnShow = function(self, data)
		local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
		if editBox then editBox:SetText(data or ''); editBox:SetFocus(); editBox:HighlightText() end
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
}

local function ShowURLPopup(url)
	_G.StaticPopup_Show('BUI_CHAT_URL', nil, nil, url)
end

local urlRefHooked
local function HookURLRef()
	if urlRefHooked then return end
	urlRefHooked = true
	hooksecurefunc('SetItemRef', function(link)
		local kind, value = link:match('^(%a+):(.+)$')
		if kind == 'url' and value then ShowURLPopup(value) end
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
	local color = (config and config.urlColor) or DEFAULTS.urlColor
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
	if config and config.hideChannelNumbers then
		text = gsub(text, '(%[)%d+%.%s*', '%1')
	end
	if config and config.abbreviateChannels then
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
	hooksecurefunc(frame, 'AddMessage', function(self, text)
		if Enabled() and self ~= _G.ChatFrame2 and type(text) == 'string' and not issecretvalue(text) and text ~= '' then
			local buffer = self.historyBuffer
			local entry = buffer and buffer.GetEntryAtIndex and buffer:GetEntryAtIndex(1)
			if entry and entry.message == text then
				local config = GetConfig()
				local newText = ProcessChannels(text, config)
				if not config or config.urlCopy ~= false then newText = LinkifyURLs(newText, config) end
				if config and config.timestamps then
					local stampFormat = config.timestampFormat or DEFAULTS.timestampFormat
					if ValidStampFormat(stampFormat) then
						local stampColor = config.timestampColor or DEFAULTS.timestampColor
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

local function GetCopyWindow()
	if copyWindow then return copyWindow end
	local window = CreateFrame('Frame', 'BUI_ChatCopy', UIParent)
	window:SetSize(580, 420)
	window:SetPoint('CENTER')
	window:SetFrameStrata('DIALOG')
	window:EnableMouse(true)
	window:SetMovable(true)
	window:RegisterForDrag('LeftButton')
	window:SetScript('OnDragStart', window.StartMoving)
	window:SetScript('OnDragStop', window.StopMovingOrSizing)
	window:Hide()
	if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, 'BUI_ChatCopy') end
	Skin3.Backdrop(window, { bg = { 0.05, 0.05, 0.05, 0.96 }, border = { 0, 0, 0, 1 } })

	local title = window:CreateFontString(nil, 'OVERLAY')
	SetFontSafe(title, BUILib.Font, 14, '')
	title:SetPoint('TOPLEFT', 14, -12)
	title:SetText('Copy Chat')
	title:SetTextColor(1, 1, 1)

	local close = CreateFrame('Button', nil, window)
	close:SetSize(22, 22)
	close:SetPoint('TOPRIGHT', -6, -6)
	local closeGlyph = close:CreateFontString(nil, 'OVERLAY')
	SetFontSafe(closeGlyph, BUILib.Font, 18, '')
	closeGlyph:SetPoint('CENTER')
	closeGlyph:SetText('×')
	closeGlyph:SetTextColor(0.7, 0.7, 0.7)
	close:SetScript('OnEnter', function() closeGlyph:SetTextColor(theme.GetAccent()) end)
	close:SetScript('OnLeave', function() closeGlyph:SetTextColor(0.7, 0.7, 0.7) end)
	close:SetScript('OnClick', function() window:Hide() end)

	local scroll = CreateFrame('ScrollFrame', 'BUI_ChatCopyScroll', window)
	scroll:SetPoint('TOPLEFT', 14, -38)
	scroll:SetPoint('BOTTOMRIGHT', -18, 14)
	scroll:EnableMouseWheel(true)

	local editBox = CreateFrame('EditBox', nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetMaxLetters(0)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(_G.ChatFontNormal)
	editBox:SetWidth(540)
	editBox:SetScript('OnEscapePressed', function() window:Hide() end)
	if _G.ScrollingEdit_OnTextChanged then
		editBox:SetScript('OnTextChanged', function(self) _G.ScrollingEdit_OnTextChanged(self, self:GetParent()) end)
	end
	if _G.ScrollingEdit_OnCursorChanged then
		editBox:SetScript('OnCursorChanged', _G.ScrollingEdit_OnCursorChanged)
	end
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
	editBox:HookScript('OnMouseDown', function(self)
		local now = GetTime()
		if now - clicks[#clicks] < 0.5 then
			local triple = clicks[#clicks] - clicks[#clicks - 1] < 0.5
			local cursorPosition = self:GetCursorPosition()
			local text = self:GetText() or ''
			local startPos, endPos
			if triple then
				startPos, endPos = Expand(text, cursorPosition, '\n')
			else
				startPos, endPos = Expand(text, cursorPosition, '%s')
				if not LooksLikeURL(text:sub(startPos + 1, endPos)) then
					startPos, endPos = Expand(text, cursorPosition, '[%s%p]')
				end
			end
			C_Timer.After(0, function() self:HighlightText(startPos, endPos) end)
		end
		clicks[#clicks + 1] = now
		if #clicks > 3 then tremove(clicks, 1) end
	end)

	local bar = CreateFrame('Frame', nil, window)
	bar:SetWidth(4)
	bar:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 6, 0)
	bar:SetPoint('BOTTOMLEFT', scroll, 'BOTTOMRIGHT', 6, 0)
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
	thumbTexture:SetColorTexture(theme.GetAccent())
	thumbTexture:SetAlpha(0.55)

	local function UpdateCopyBar()
		local range = scroll:GetVerticalScrollRange() or 0
		local trackHeight = bar:GetHeight() or 0
		if range <= 1 or trackHeight <= 1 then thumb:Hide(); return end
		thumb:Show()
		local viewHeight = scroll:GetHeight() or 1
		local thumbHeight = max(20, min(trackHeight, trackHeight * (viewHeight / (viewHeight + range))))
		thumb:SetHeight(thumbHeight)
		if not thumb._drag then
			local fraction = min(1, max(0, (scroll:GetVerticalScroll() or 0) / range))
			thumb:ClearAllPoints()
			thumb:SetPoint('LEFT'); thumb:SetPoint('RIGHT')
			thumb:SetPoint('TOP', bar, 'TOP', 0, -fraction * (trackHeight - thumbHeight))
		end
	end
	window._updateBar = UpdateCopyBar

	scroll:SetScript('OnScrollRangeChanged', UpdateCopyBar)
	scroll:SetScript('OnVerticalScroll', UpdateCopyBar)
	scroll:SetScript('OnMouseWheel', function(self, delta)
		local range = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(min(max(0, (self:GetVerticalScroll() or 0) - delta * 40), range))
	end)

	thumb:SetScript('OnEnter', function() thumbTexture:SetAlpha(0.9) end)
	thumb:SetScript('OnLeave', function() if not thumb._drag then thumbTexture:SetAlpha(0.55) end end)
	thumb:SetScript('OnDragStart', function(self) self._drag = true; thumbTexture:SetAlpha(0.9) end)
	thumb:SetScript('OnDragStop', function(self) self._drag = false; thumbTexture:SetAlpha(0.55); UpdateCopyBar() end)
	thumb:SetScript('OnUpdate', function(self)
		if not self._drag then return end
		local trackHeight = bar:GetHeight() or 0
		local thumbHeight = self:GetHeight() or 20
		local usable = trackHeight - thumbHeight
		if usable <= 0 then return end
		local scale = bar:GetEffectiveScale()
		local _, cursorY = GetCursorPosition()
		local relativeY = (bar:GetTop() or 0) - cursorY / scale - thumbHeight / 2
		local fraction = min(1, max(0, relativeY / usable))
		scroll:SetVerticalScroll(fraction * (scroll:GetVerticalScrollRange() or 0))
		self:ClearAllPoints()
		self:SetPoint('LEFT'); self:SetPoint('RIGHT')
		self:SetPoint('TOP', bar, 'TOP', 0, -fraction * usable)
	end)

	copyWindow = window
	return window
end

local function CopyChat(frame)
	frame = frame or _G.ChatFrame1
	if not frame or not frame.GetNumMessages then return end
	local lines = {}
	for messageIndex = 1, frame:GetNumMessages() do
		local info = frame:GetMessageInfo(messageIndex)
		local message = type(info) == 'table' and info.message or info
		if type(message) == 'string' and not issecretvalue(message) and message ~= '' then
			message = StripEscapes(message)
			if type(info) == 'table' and type(info.r) == 'number' and type(info.g) == 'number' and type(info.b) == 'number' then
				message = '|cff' .. BUI.Hex(info.r, info.g, info.b) .. message .. '|r'
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
	if window._updateBar then C_Timer.After(0, window._updateBar) end
end

local function GetHistory()
	local db = BUI.GetDB()
	if not db.chatHistory then db.chatHistory = {} end
	return db.chatHistory
end

local function PushHistory(text)
	if not text or text == '' then return end
	local command = text:match('^(/%S+)')
	if command and IsSecureCmd(command) then return end
	local history = GetHistory()
	if history[#history] == text then return end
	history[#history + 1] = text
	while #history > HISTORY_CAP do tremove(history, 1) end
end

local function SetupEditHistory(editBox)
	if not editBox or editBox._buiHist then return end
	editBox._buiHist = true
	if editBox.SetAltArrowKeyMode then editBox:SetAltArrowKeyMode(false) end

	if editBox.AddHistoryLine then
		hooksecurefunc(editBox, 'AddHistoryLine', function(self, text)
			if not (Enabled() and EditHistory()) then return end
			if type(text) ~= 'string' or text == '' then return end
			if issecretvalue(text) then return end
			PushHistory(text)
			self._histIdx = nil
		end)
	end

	editBox:HookScript('OnKeyDown', function(self, key)
		if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
		if not (Enabled() and EditHistory()) then return end
		local history = GetHistory()
		local historyCount = #history
		if historyCount == 0 then return end
		if key == 'UP' then
			if self._histIdx == nil then
				self._histTop = self:GetText() or ''
				self._histIdx = historyCount
			elseif self._histIdx > 1 then
				self._histIdx = self._histIdx - 1
			else
				return
			end
			self:SetText(history[self._histIdx] or '')
		elseif key == 'DOWN' then
			if self._histIdx == nil then return end
			if self._histIdx < historyCount then
				self._histIdx = self._histIdx + 1
				self:SetText(history[self._histIdx] or '')
			else
				self._histIdx = nil
				self:SetText(self._histTop or '')
			end
		end
	end)

	editBox:HookScript('OnEditFocusLost', function(self) self._histIdx = nil end)
end

local historyHooked
local function HookHistoryCapture()
	if historyHooked or not _G.ChatEdit_SendText then return end
	historyHooked = true
	hooksecurefunc('ChatEdit_SendText', function(editBox, addHistory)
		if not (addHistory and Enabled() and EditHistory()) then return end
		if editBox and editBox.GetText then
			local text = editBox:GetText()
			if strtrim then text = strtrim(text) end
			PushHistory(text)
		end
	end)
end

local function IsTabSelected(tab)
	local dock = _G.GeneralDockManager
	return dock and dock.selected == tab._buiChat
end

local function SetTabTextColor(text, red, green, blue)
	text:SetTextColor(red, green, blue)
end

local function TabStyle()
	local config = GetConfig()
	return (config and config.tabStyle) or DEFAULTS.tabStyle
end

local function ApplyTabColor(tab, selected)
	local text = tab and tab._buiText
	if not text then return end
	local style = TabStyle()
	local red, green, blue = SelectedColor()
	if selected then
		if style == 'TEXT' then SetTabTextColor(text, red, green, blue) else SetTabTextColor(text, 1, 1, 1) end
	else
		SetTabTextColor(text, InactiveColor())
	end
	local showLine = selected and style ~= 'TEXT'
	if tab._buiLine then
		tab._buiLine:SetColorTexture(red, green, blue, 1)
		tab._buiLine:SetShown(showLine)
	end
	if tab._buiGlow then
		tab._buiGlow:SetGradient('VERTICAL', CreateColor(red, green, blue, TAB_GLOW_ALPHA), CreateColor(red, green, blue, 0))
		tab._buiGlow:SetShown(showLine)
	end
	if tab._buiFill then
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
end

local function DesiredTabAlpha(tab)
	if tab._buiCollapsed then return 0 end
	local chat = tab._buiChat
	if not chat then return fadeState.alpha end
	local selected = _G.GeneralDockManager and _G.GeneralDockManager.selected
	local base = (not chat.isDocked or chat == selected or tab._buiPulse) and SelectedAlpha() or DockedAlpha()
	return base * fadeState.alpha
end

local function ApplyTabAlpha(tab)
	tab:SetAlpha(DesiredTabAlpha(tab), true)
end

function Skin.CollapseChatTab(tab, collapsed)
	if not tab then return end
	collapsed = collapsed and true or false
	if tab._buiCollapsed == collapsed then return end
	tab._buiCollapsed = collapsed
	tab:EnableMouse(not collapsed)
	if collapsed then tab:SetWidth(1) end
	ApplyTabAlpha(tab)
	local dock = _G.GeneralDockManager
	if dock and _G.FCFDock_UpdateTabs then _G.FCFDock_UpdateTabs(dock, true) end
end

local function TabAlphaHook(tab, _, skip)
	if skip or not Enabled() then return end
	if not tab._buiChat then return end
	ApplyTabAlpha(tab)
end

local function BlankTabTexture(texture)
	if not texture or texture._buiOwned or not texture.SetTexture then return end
	texture:SetTexture(nil)
	if texture.SetAtlas then texture:SetAtlas(nil) end
	texture:SetAlpha(0)
end

local function StripTabRegions(tab)
	if not tab.GetRegions then return end
	for regionIndex = 1, select('#', tab:GetRegions()) do
		local region = select(regionIndex, tab:GetRegions())
		if region ~= tab._buiText and region.IsObjectType and region:IsObjectType('Texture') then
			BlankTabTexture(region)
		end
	end
	if tab.GetHighlightTexture then BlankTabTexture(tab:GetHighlightTexture()) end
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
	if not tab or not tab._buiText then return end
	local text = tab._buiText
	StripTabRegions(tab)
	EnsureTabArt(tab)
	tab:SetHeight(InsetTop())
	SetFontSafe(text, ResolveFont(), TabFontSize(), TabFlags())
	if text.SetWordWrap then text:SetWordWrap(false) end
	if text.SetJustifyH then text:SetJustifyH('CENTER') end
	local chat = tab._buiChat
	if TabUppercase() and not (chat and chat.isTemporary) then
		local tabText = text:GetText()
		if tabText and not issecretvalue(tabText) then
			local uppercased = upper(tabText)
			if uppercased ~= tabText then text:SetText(uppercased) end
		end
	end
	text:ClearAllPoints()
	text:SetPoint('CENTER', tab, 'CENTER', 0, 0)
	if tab.conversationIcon then tab.conversationIcon:Hide() end
	ApplyShadow(text)
	ApplyTabColor(tab, IsTabSelected(tab))
	ApplyTabAlpha(tab)
end

local function TabOf(chatFrame)
	if not chatFrame then return nil end
	return chatFrame.tab or (chatFrame.GetName and _G[chatFrame:GetName() .. 'Tab'])
end

local function AlignDockTabs(dock)
	if not Enabled() then return end
	if not dock or dock ~= _G.GeneralDockManager then return end
	if not dock:IsVisible() then return end
	if not dock.isDirty and dock:GetScript('OnUpdate') and dock.scrollFrame and dock.scrollFrame:GetRight() and _G.FCFDock_SetDirty then
		_G.FCFDock_SetDirty(dock)
	end
	local frames = dock.DOCKED_CHAT_FRAMES
	if not frames then return end
	for _, chatFrame in ipairs(frames) do
		local tab = TabOf(chatFrame)
		if tab and tab._buiChat then
			local point, relativeTo, relativePoint, x, y = tab:GetPoint(1)
			if point == 'LEFT' and y and y ~= 0 then
				tab:SetPoint(point, relativeTo, relativePoint, x or 0, 0)
			end
			if tab._buiCollapsed then
				tab:SetWidth(1)
			elseif tab._buiText then
				tab._buiText:SetWidth(max(1, tab:GetWidth() - TAB_TEXT_PAD * 2))
			end
		end
	end
end

local function RefreshTabs()
	for tabIndex = 1, #skinnedTabs do StyleTab(skinnedTabs[tabIndex]) end
	local dock = _G.GeneralDockManager
	if dock and _G.FCFDock_UpdateTabs then _G.FCFDock_UpdateTabs(dock, true) end
end

local function SkinTab(tab, chat)
	if not tab or tab._buiChatSkin then return end
	tab._buiChatSkin = true
	tab._buiChat = chat
	tab._buiText = tab.Text or (tab.GetName and _G[tab:GetName() .. 'Text'])
	skinnedTabs[#skinnedTabs + 1] = tab
	tab:HookScript('OnEnter', function()
		if Enabled() then StartFader() end
	end)
	StyleTab(tab)
	hooksecurefunc(tab, 'SetAlpha', TabAlphaHook)
	ApplyTabAlpha(tab)
	local dock = _G.GeneralDockManager
	LiftTab(tab, ((dock and dock:GetFrameLevel()) or 5) + 3)
end

local function PositionEditBox(chat)
	local editBox = chat and (chat.editBox or _G[chat:GetName() .. 'EditBox'])
	if not editBox then return end
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

local function SkinEditBox(editBox, chat)
	if not editBox then return end
	editBox._buiChat = chat
	SetupEditHistory(editBox)
	if editBox._buiChatSkin then PositionEditBox(chat); return end
	editBox._buiChatSkin = true

	local editBoxName = editBox:GetName()
	HideTexture(editBoxName and _G[editBoxName .. 'Left'])
	HideTexture(editBoxName and _G[editBoxName .. 'Mid'])
	HideTexture(editBoxName and _G[editBoxName .. 'Right'])
	HideTexture(editBox.focusLeft)
	HideTexture(editBox.focusRight)
	HideTexture(editBox.focusMid)

	Skin3.Backdrop(editBox, { bg = { EditBoxBGColor() }, border = { BorderColor() } })
	editBox:SetTextInsets(8, 8, 2, 2)
	SetFontSafe(editBox, ResolveFont(), EditFontSize(), '')
	editBox:SetTextColor(1, 1, 1)
	PositionEditBox(chat)

	editBox:HookScript('OnShow', function(self) PositionEditBox(self._buiChat) end)
	editBox:HookScript('OnEditFocusGained', function(self) self:SetBackdropBorderColor(theme.GetAccent()) end)
	editBox:HookScript('OnEditFocusLost', function(self) self:SetBackdropBorderColor(BorderColor()) end)
end

local function AnchorPanel()
	if not chatPanel then return end
	local chat = _G.ChatFrame1
	if not chat then return end
	chatPanel:ClearAllPoints()
	chatPanel:SetPoint('BOTTOMLEFT', chat, 'BOTTOMLEFT', -InsetX(), -InsetBottom())
	chatPanel:SetPoint('TOPRIGHT', chat, 'TOPRIGHT', InsetX() + SCROLL_GUTTER, InsetTop())
end

local function ApplyTopStrip()
	if not chatPanel or not chatPanel._strip then return end
	local thickness = BorderThickness()
	local strip = chatPanel._strip
	strip:ClearAllPoints()
	strip:SetPoint('TOPLEFT', chatPanel, 'TOPLEFT', thickness, -thickness)
	strip:SetPoint('TOPRIGHT', chatPanel, 'TOPRIGHT', -thickness, -thickness)
	strip:SetHeight(InsetTop())
end

local function ApplyRightStrip()
	if not chatPanel or not chatPanel._vstrip then return end
	local thickness = BorderThickness()
	local verticalStrip = chatPanel._vstrip
	verticalStrip:ClearAllPoints()
	verticalStrip:SetWidth(BAR_WIDTH)
	verticalStrip:SetPoint('TOPRIGHT', chatPanel, 'TOPRIGHT', -thickness, -(InsetTop() + thickness))
	verticalStrip:SetPoint('BOTTOMRIGHT', chatPanel, 'BOTTOMRIGHT', -thickness, thickness)
	local gutter = chatPanel._gutter
	if gutter then
		gutter:ClearAllPoints()
		gutter:SetWidth(SCROLL_GUTTER)
		gutter:SetPoint('TOPRIGHT', chatPanel, 'TOPRIGHT', -thickness, -(InsetTop() + thickness))
		gutter:SetPoint('BOTTOMRIGHT', chatPanel, 'BOTTOMRIGHT', -thickness, thickness)
	end
end

local function ApplyPanelFill()
	if not panelSquare then return end
	local red, green, blue, alpha = BGColor()
	local textureName = BGTexture()
	local path = (textureName and textureName ~= 'SOLID' and sharedMedia) and sharedMedia:Fetch('statusbar', textureName) or nil
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
	local chat = _G.ChatFrame1
	if not chat then return end
	local gutter = chatPanel and chatPanel._gutter
	local hovered = gutter and gutter:IsMouseOver()
	local alpha = (hovered and 1 or 0.25) * (FadeEnabled() and fadeState.alpha or 1)
	if chat._buiCog then chat._buiCog:SetAlpha(alpha) end
	if chat._buiLock then chat._buiLock:SetAlpha(alpha) end
	if chat._buiCopy and ShowCopyButton() then chat._buiCopy:SetAlpha(alpha) end
end

local function MakeCornerButton(chat, mediaKey, fallbackTexture)
	local button = CreateFrame('Button', nil, UIParent)
	button:SetFrameStrata('MEDIUM')
	button:SetSize(14, 14)
	button:SetFrameLevel(chat:GetFrameLevel() + 8)
	button:SetAlpha(0.25)
	local texture = button:CreateTexture(nil, 'ARTWORK')
	texture:SetAllPoints()
	texture:SetTexture(BUILib.GetLibMedia(mediaKey) or fallbackTexture)
	texture:SetVertexColor(0.65, 0.65, 0.7, 1)
	button._tex = texture
	button:SetScript('OnEnter', function()
		texture:SetVertexColor(theme.GetAccent())
		fadeState.lastActive = GetTime()
		StartFader()
		UpdateCornerButtons()
	end)
	button:SetScript('OnLeave', function()
		texture:SetVertexColor(0.65, 0.65, 0.7, 1)
		UpdateCornerButtons()
	end)
	return button
end

local function UpdateCopyButton()
	local chat = _G.ChatFrame1
	if not chat or not chat._buiCopy then return end
	if ShowCopyButton() then chat._buiCopy:Show() else chat._buiCopy:Hide() end
end

local function SkinPanel()
	local chat = _G.ChatFrame1
	if not chat or chatPanel then return end

	local panel = CreateFrame('Frame', 'BUI_ChatPanel', UIParent)
	panel:SetFrameStrata('BACKGROUND')
	panel:SetFrameLevel(max(0, chat:GetFrameLevel() - 1))
	chatPanel = panel
	AnchorPanel()
	C_Timer.After(0, function()
		if BUI.Datatext and BUI.Datatext.Apply then BUI.Datatext.Apply() end
	end)
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
	gutter:SetFrameLevel((panel:GetFrameLevel() or 0) + 1)
	gutter:EnableMouse(true)
	if gutter.SetPropagateMouseClicks then gutter:SetPropagateMouseClicks(true) end
	panel._gutter = gutter
	gutter:SetScript('OnEnter', function()
		if not Enabled() then return end
		fadeState.lastActive = GetTime()
		StartFader()
		UpdateCornerButtons()
	end)
	gutter:SetScript('OnLeave', function()
		if not Enabled() then return end
		UpdateCornerButtons()
	end)
	ApplyRightStrip()

	local cog = MakeCornerButton(chat, 'cog', 'Interface\\Buttons\\UI-OptionsButton')
	cog:SetPoint('TOP', verticalStrip, 'TOP', 0, -3)
	cog:SetScript('OnClick', function()
		if BUI.PageEngine.EnsureLoaded() and BUI.SkinningPage and BUI.SkinningPage.OpenSkinSettings then
			BUI.SkinningPage.OpenSkinSettings('chat')
		end
	end)
	chat._buiCog = cog

	local copy = MakeCornerButton(chat, 'copy', 'Interface\\BUTTONS\\UI-GuildButton-PublicNote-Up')
	copy:SetPoint('TOP', cog, 'BOTTOM', 0, -5)
	copy:SetScript('OnClick', function()
		local win = GetCopyWindow()
		if win:IsShown() then
			win:Hide()
		else
			CopyChat((_G.GeneralDockManager and _G.GeneralDockManager.selected) or _G.ChatFrame1)
		end
	end)
	chat._buiCopy = copy

	local lock = MakeCornerButton(chat, 'lock', 'Interface\\Buttons\\LockButton-Locked-Up')
	lock:SetPoint('TOP', copy, 'BOTTOM', 0, -5)
	local function PaintLock(hovered)
		if not lock._tex then return end
		local red, green, blue = theme.GetAccent()
		if hovered then
			lock._tex:SetVertexColor(red, green, blue, 1)
		elseif lock._lockedTint then
			lock._tex:SetVertexColor(red * 0.75, green * 0.75, blue * 0.75, 1)
		else
			lock._tex:SetVertexColor(0.65, 0.65, 0.7, 1)
		end
	end
	local function UpdateLockIcon()
		lock._lockedTint = Locked() and true or false
		PaintLock(lock:IsMouseOver())
	end
	lock:SetScript('OnEnter', function()
		PaintLock(true)
		fadeState.lastActive = GetTime()
		StartFader()
		UpdateCornerButtons()
	end)
	lock:SetScript('OnLeave', function()
		PaintLock(false)
		UpdateCornerButtons()
	end)
	lock:SetScript('OnClick', function()
		local config = GetConfig()
		if not config then return end
		config.locked = not Locked()
		UpdateLockIcon()
		UpdateMover()
		UpdateSizer()
	end)
	UpdateLockIcon()
	chat._buiLock = lock
end

local function PositionMover()
	if not mover then return end
	local chat = _G.ChatFrame1
	if not chat then return end
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
	local chat = _G.ChatFrame1
	if not chat or mover or not chatPanel then return end
	mover = CreateFrame('Frame', 'BUI_ChatMover', chatPanel)
	mover:SetFrameStrata('BACKGROUND')
	mover:SetFrameLevel((chatPanel:GetFrameLevel() or 0) + 2)
	mover:RegisterForDrag('LeftButton')
	local highlight = mover:CreateTexture(nil, 'ARTWORK')
	highlight:SetAllPoints()
	highlight:SetColorTexture(theme.GetAccent())
	highlight:SetAlpha(0)
	mover._hl = highlight
	mover:SetScript('OnEnter', function(self) self._hl:SetAlpha(0.18) end)
	mover:SetScript('OnLeave', function(self) self._hl:SetAlpha(0) end)
	mover:SetScript('OnDragStart', function()
		if InCombatLockdown and InCombatLockdown() then return end
		if chat.SetClampRectInsets then chat:SetClampRectInsets(0, 0, 0, 0) end
		chat:SetMovable(true)
		chat:StartMoving()
	end)
	mover:SetScript('OnDragStop', function()
		chat:StopMovingOrSizing()
		SaveGeometry(chat)
	end)
	UpdateMover()
end

local function PositionSizer()
	if not sizer or not chatPanel then return end
	local thickness = BorderThickness()
	sizer:ClearAllPoints()
	sizer:SetPoint('TOPRIGHT', chatPanel, 'TOPRIGHT', -thickness - 1, -thickness - 1)
	sizer._handle = 'TOPRIGHT'
	if sizer._grip then sizer._grip:SetTexCoord(0, 1, 1, 0) end
end

function UpdateSizer()
	if not sizer then return end
	PositionSizer()
	if SizerEnabled() and not Locked() then sizer:Show() else sizer:Hide() end
end

local function CreateSizer()
	local chat = _G.ChatFrame1
	if not chat or sizer then return end
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

	sizer:SetScript('OnEnter', function(self) self:SetAlpha(1); GripColor(true) end)
	sizer:SetScript('OnLeave', function(self) self:SetAlpha(SIZER_IDLE_ALPHA); GripColor(false) end)
	sizer:SetScript('OnMouseDown', function(self)
		if InCombatLockdown and InCombatLockdown() then return end
		if chat.SetClampRectInsets then chat:SetClampRectInsets(0, 0, 0, 0) end
		chat:SetResizable(true)
		chat:StartSizing(self._handle or 'BOTTOMRIGHT')
	end)
	sizer:SetScript('OnMouseUp', function()
		chat:StopMovingOrSizing()
		SaveGeometry(chat)
	end)
	UpdateSizer()
end

function Skin.ChatMaxScrollOffset(chat)
	local buffer = chat.historyBuffer
	local count = (chat.GetNumMessages and chat:GetNumMessages()) or 0
	if not (buffer and buffer.GetEntryAtIndex) or count <= 1 then return 0 end
	local frameHeight = chat:GetHeight() or 0
	if frameHeight <= 0 then return count - 1 end
	local measure = chat._buiMeasure
	if not measure then
		measure = chat:CreateFontString(nil, 'BACKGROUND')
		measure:Hide()
		measure:SetNonSpaceWrap(true)
		chat._buiMeasure = measure
	end
	local font, size, flags = chat:GetFont()
	if font then measure:SetFont(font, size, flags or '') end
	measure:SetWidth(chat:GetWidth() or 0)
	local lineHeight = max(1, measure:GetLineHeight() or 1)
	local spacing = measure:GetSpacing() or 0
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
	frame:SetScript('OnMouseWheel', function(self, delta)
		if not Enabled() then
			if delta > 0 then self:ScrollUp() else self:ScrollDown() end
			return
		end
		if IsControlKeyDown() then
			local config = GetConfig()
			if config then
				local currentSize = config.fontSize or DEFAULTS.fontSize
				local newSize = min(22, max(8, currentSize + (delta > 0 and 1 or -1)))
				if newSize ~= currentSize then
					config.fontSize = newSize
					ApplyMsgFontSize()
				end
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
			local maxOffset = Skin.ChatMaxScrollOffset(self)
			if (self:GetScrollOffset() or 0) > maxOffset then self:SetScrollOffset(maxOffset) end
		end
		if FadeEnabled() then fadeState.lastActive = GetTime(); StartFader() end
	end)
	frame:EnableMouseWheel(true)
	frame:EnableMouse(true)
	frame:HookScript('OnEnter', function()
		if Enabled() then StartFader() end
	end)
	local editBox = frame.editBox or _G[frame:GetName() .. 'EditBox']
	if editBox and not editBox._buiFadeHook then
		editBox._buiFadeHook = true
		editBox:HookScript('OnEditFocusGained', function()
			if not Enabled() then return end
			if FadeEnabled() then fadeState.lastActive = GetTime() end
			StartFader()
		end)
		editBox:HookScript('OnTextChanged', function(self, userInput)
			if not userInput or not Enabled() then return end
			local text = self:GetText()
			if not TARGET_TELL_COMMANDS[text:lower()] then return end
			if not UnitExists('target') or not UnitIsPlayer('target') then return end
			local name = GetUnitName('target', true)
			if not name or name == '' then return end
			self:SetText('/w ' .. name .. ' ')
		end)
	end
	if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(true) end
	if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(true) end
	if frame.SetHyperlinksEnabled then frame:SetHyperlinksEnabled(true) end
	if _G.ChatFrame_OnHyperlinkShow and frame:GetScript('OnHyperlinkClick') ~= _G.ChatFrame_OnHyperlinkShow then
		frame:SetScript('OnHyperlinkClick', _G.ChatFrame_OnHyperlinkShow)
	end
	if not frame._buiLinkHover then
		frame._buiLinkHover = true
		frame:HookScript('OnHyperlinkEnter', function(self, link)
			if not Enabled() then return end
			local config = GetConfig()
			if config and config.hoverTooltips == false then return end
			if issecretvalue(link) or type(link) ~= 'string' then return end
			local linkType = link:match('^([^:]+)')
			if not HOVER_LINK_TYPES[linkType] then return end
			GameTooltip:SetOwner(self, 'ANCHOR_CURSOR')
			local shown = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
			if shown then GameTooltip:Show() else GameTooltip:Hide() end
		end)
		frame:HookScript('OnHyperlinkLeave', function()
			GameTooltip:Hide()
		end)
	end
end

local function Clamp01(value)
	if value < 0 then return 0 elseif value > 1 then return 1 end
	return value
end

local function ScrollMetrics(chat)
	local messageCount = chat:GetNumMessages() or 0
	local _, fontSize = chat:GetFont()
	local spacing = (chat.GetSpacing and chat:GetSpacing()) or 0
	local lineHeight = max(1, (fontSize or 14) + spacing)
	local visible = max(1, floor((chat:GetHeight() or lineHeight) / lineHeight))
	return messageCount, visible, Skin.ChatMaxScrollOffset(chat)
end

local function UpdateChatScrollBar(chat)
	local scrollBar = chat._buiSB
	if not scrollBar then return end
	local thumb = scrollBar._thumb
	local offset = chat:GetScrollOffset() or 0
	local messageCount = chat:GetNumMessages() or 0
	local trackHeight = scrollBar:GetHeight() or 0
	if not thumb._drag and offset == scrollBar._lo and messageCount == scrollBar._ln and trackHeight == scrollBar._lh then return end
	scrollBar._lo, scrollBar._ln, scrollBar._lh = offset, messageCount, trackHeight
	local _, visible, maxOffset = ScrollMetrics(chat)
	if maxOffset <= 0 or trackHeight <= 1 then
		thumb:Hide()
		return
	end
	thumb:Show()
	local thumbHeight = max(16, min(trackHeight, trackHeight * (visible / messageCount)))
	thumb:SetHeight(thumbHeight)
	if not thumb._drag then
		local positionFraction = Clamp01(1 - (offset / maxOffset))
		thumb:ClearAllPoints()
		thumb:SetPoint('LEFT')
		thumb:SetPoint('RIGHT')
		thumb:SetPoint('TOP', scrollBar, 'TOP', 0, -positionFraction * (trackHeight - thumbHeight))
	end
end

local function PositionScrollBar(chat)
	local scrollBar = chat._buiSB
	if not scrollBar then return end
	local thickness = BorderThickness()
	local offsetX = InsetX() + SCROLL_GUTTER - thickness - BAR_WIDTH - 4
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint('TOP', chat, 'TOPRIGHT', offsetX, -(thickness + 2))
	scrollBar:SetPoint('BOTTOM', chat, 'BOTTOMRIGHT', offsetX, -InsetBottom() + thickness + 2)
end

local function CreateChatScrollBar(chat)
	if chat._buiSB then return end
	local scrollBar = CreateFrame('Frame', nil, chat)
	scrollBar:SetWidth(4)
	scrollBar:SetFrameLevel(chat:GetFrameLevel() + 6)

	local track = scrollBar:CreateTexture(nil, 'ARTWORK')
	track:SetAllPoints()
	track:SetColorTexture(1, 1, 1, 0.05)

	local thumb = CreateFrame('Frame', nil, scrollBar)
	thumb:SetPoint('LEFT'); thumb:SetPoint('RIGHT'); thumb:SetPoint('TOP')
	thumb:SetHeight(20)
	thumb:EnableMouse(true)
	thumb:RegisterForDrag('LeftButton')
	local thumbTexture = thumb:CreateTexture(nil, 'OVERLAY')
	thumbTexture:SetAllPoints()
	local function ThumbColor(accent)
		if accent then
			thumbTexture:SetColorTexture(theme.GetAccent())
			thumbTexture:SetAlpha(0.9)
		else
			thumbTexture:SetColorTexture(0.65, 0.65, 0.7, 1)
			thumbTexture:SetAlpha(0.55)
		end
	end
	ThumbColor(false)
	scrollBar._thumb, scrollBar._track, scrollBar._tt = thumb, track, thumbTexture
	chat._buiSB = scrollBar
	PositionScrollBar(chat)

	thumb:SetScript('OnEnter', function() ThumbColor(true) end)
	thumb:SetScript('OnLeave', function() if not thumb._drag then ThumbColor(false) end end)
	thumb:SetScript('OnDragStart', function(self) self._drag = true; ThumbColor(true) end)
	thumb:SetScript('OnDragStop', function(self) self._drag = false; ThumbColor(false) end)
	thumb:SetScript('OnUpdate', function(self)
		if not self._drag then return end
		local trackHeight = scrollBar:GetHeight() or 0
		local thumbHeight = self:GetHeight() or 16
		local usable = trackHeight - thumbHeight
		if usable <= 0 then return end
		local scale = scrollBar:GetEffectiveScale()
		local _, cursorY = GetCursorPosition()
		local relativeY = (scrollBar:GetTop() or 0) - cursorY / scale - thumbHeight / 2
		local positionFraction = min(1, max(0, relativeY / usable))
		local _, _, maxOffset = ScrollMetrics(chat)
		chat:SetScrollOffset(floor((1 - positionFraction) * maxOffset + 0.5))
		self:ClearAllPoints()
		self:SetPoint('TOP', scrollBar, 'TOP', 0, -positionFraction * usable)
		self:SetPoint('LEFT'); self:SetPoint('RIGHT')
	end)

	local function Update() UpdateChatScrollBar(chat) end
	scrollBar._update = Update
	for _, methodName in ipairs({ 'SetScrollOffset', 'ScrollUp', 'ScrollDown', 'ScrollToTop', 'ScrollToBottom', 'PageUp', 'PageDown' }) do
		if chat[methodName] then hooksecurefunc(chat, methodName, Update) end
	end
	chat:HookScript('OnSizeChanged', Update)
	Update()
end

local function IsChatHovered()
	if chatPanel and chatPanel:IsMouseOver() then return true end
	if mover and mover:IsShown() and mover:IsMouseOver() then return true end
	for frameIndex = 1, #skinnedFrames do
		local chatFrame = skinnedFrames[frameIndex]
		if chatFrame:IsShown() and chatFrame:IsMouseOver() then return true end
		local editBox = chatFrame.editBox or _G[chatFrame:GetName() .. 'EditBox']
		if editBox and editBox:IsShown() and (editBox:HasFocus() or editBox:IsMouseOver()) then return true end
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
		fader._handler = function(_, elapsed)
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
		end
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
	if not chat then return end
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
			hooksecurefunc(chat.Background, 'Show', KillShow)
		end
		if chat.SetClampRectInsets then chat:SetClampRectInsets(0, 0, 0, 0) end
		local config = GetConfig()
		local _, size = chat:GetFont()
		SetFontSafe(chat, ResolveFont(), (config and config.fontSize) or size or DEFAULTS.fontSize, MsgFlags())
	end

	HideTexture(_G[name .. 'ThumbTexture'])
	HideTexture(_G[name .. 'EditBoxLeft'])
	HideTexture(_G[name .. 'EditBoxMid'])
	HideTexture(_G[name .. 'EditBoxRight'])
	Kill(chat.ScrollBar)
	Kill(_G[name .. 'ScrollBar'])
	Kill(chat.ScrollToBottomButton)
	Kill(_G[name .. 'ScrollToBottomButton'])
	ManageHidden(_G[name .. 'ButtonFrame'], true)

	SkinTab(_G[name .. 'Tab'], chat)
	SkinEditBox(chat.editBox or _G[name .. 'EditBox'], chat)
end

local function SkinAllChatFrames()
	for _, frameName in ipairs(_G.CHAT_FRAMES or {}) do
		local chat = _G[frameName]
		if chat then SkinChatFrame(chat) end
	end
end

function ApplyMsgFontSize()
	local font, size, flags = ResolveFont(), MsgFontSize(), MsgFlags()
	for frameIndex = 1, #skinnedFrames do SetFontSafe(skinnedFrames[frameIndex], font, size, flags) end
end

local function PlaceAuxButton(button, previous, gap)
	if not button then return previous end
	button._buiOrigParent = button._buiOrigParent or button:GetParent()
	button:SetParent(chatPanel)
	button:SetFrameLevel(chatPanel:GetFrameLevel() + 10)
	button:ClearAllPoints()
	button:SetPoint('TOP', previous, 'BOTTOM', 0, -(gap or 3))
	button:SetSize(16, 16)
	if button.UpdateVisibleState then button:UpdateVisibleState() end
	return button
end

local function RestoreAuxButton(button)
	if button and button._buiOrigParent then
		button:SetParent(button._buiOrigParent)
		button._buiOrigParent = nil
	end
end

local function RepositionAuxButtons()
	if not chatPanel then return end
	local chat = _G.ChatFrame1
	if not chat then return end
	local anchor = chat._buiLock or chat._buiCopy or chat._buiCog
	if not anchor then return end

	local previous = anchor
	if not HideVoiceButtons() then
		previous = PlaceAuxButton(_G.ChatFrameChannelButton, previous, 8)
		previous = PlaceAuxButton(_G.ChatFrameToggleVoiceDeafenButton, previous)
		previous = PlaceAuxButton(_G.ChatFrameToggleVoiceMuteButton, previous)
	end
	if not HideButtons() then
		previous = PlaceAuxButton(_G.ChatFrameMenuButton, previous, 8)
		previous = PlaceAuxButton(_G.QuickJoinToastButton, previous)
	end
end

local function ApplyTimestampCVar()
	local config = GetConfig()
	if not config then return end
	if Enabled() and config.timestamps then
		local currentValue = _G.GetCVar('showTimestamps')
		if currentValue and currentValue ~= 'none' then config.blizzTimestamps = currentValue end
		_G.SetCVar('showTimestamps', 'none')
	elseif config.blizzTimestamps then
		_G.SetCVar('showTimestamps', config.blizzTimestamps)
		config.blizzTimestamps = nil
	end
end

local function ApplySettings()
	if not Enabled() then return end

	AnchorPanel()
	ApplyPanelFill()
	ApplyBorder()
	ApplyTopStrip()
	ApplyRightStrip()
	NormalizeDock()
	ApplyTimestampCVar()

	local font, flags = ResolveFont(), MsgFlags()
	local config = GetConfig()
	local configSize = config and config.fontSize
	for frameIndex = 1, #skinnedFrames do
		local chatFrame = skinnedFrames[frameIndex]
		local _, curSize = chatFrame:GetFont()
		SetFontSafe(chatFrame, font, configSize or curSize or DEFAULTS.fontSize, flags)
		ApplyShadow(chatFrame)
		if chatFrame.SetClampRectInsets then chatFrame:SetClampRectInsets(0, 0, 0, 0) end
		if chatFrame.SetFading then chatFrame:SetFading(MsgFade() and true or false) end
		if chatFrame.SetTimeVisible then chatFrame:SetTimeVisible(MsgFadeTime()) end
		PositionEditBox(chatFrame)
		PositionScrollBar(chatFrame)
		if chatFrame._buiSB and chatFrame._buiSB._update then chatFrame._buiSB._update() end
		local editBox = chatFrame.editBox or _G[chatFrame:GetName() .. 'EditBox']
		if editBox then
			SetFontSafe(editBox, font, EditFontSize(), '')
			editBox:SetTextColor(1, 1, 1)
			ApplyShadow(editBox)
			if editBox.SetBackdropColor then
				editBox:SetBackdropColor(EditBoxBGColor())
				editBox:SetBackdropBorderColor(BorderColor())
			end
		end
	end

	ManageHidden(_G.ChatFrameMenuButton, HideButtons())
	ManageHidden(_G.QuickJoinToastButton, HideButtons())
	ManageHidden(_G.ChatFrameChannelButton, HideVoiceButtons())
	ManageHidden(_G.ChatFrameToggleVoiceDeafenButton, HideVoiceButtons())
	ManageHidden(_G.ChatFrameToggleVoiceMuteButton, HideVoiceButtons())
	Skin.CollapseChatTab(_G.ChatFrame2Tab, HideLogTab())
	RefreshTabs()

	RepositionAuxButtons()

	UpdateCopyButton()
	UpdateMover()
	UpdateSizer()

	if FadeEnabled() then StartFader() else StopFader() end
end

local function FrameShowsWhispers(chatFrame)
	if not chatFrame then return false end
	if chatFrame.isTemporary then
		local chatType = chatFrame.chatType
		return chatType == 'WHISPER' or chatType == 'BN_WHISPER' or chatType == 'BN_CONVERSATION'
	end
	return (_G.ChatFrame_ContainsMessageGroup and _G.ChatFrame_ContainsMessageGroup(chatFrame, 'WHISPER')) or false
end

local function StopTabPulse(tab)
	if not tab or not tab._buiPulse then return end
	tab._buiPulse:SetScript('OnUpdate', nil)
	tab._buiPulse = nil
	if tab._buiText then ApplyTabColor(tab, IsTabSelected(tab)) end
	ApplyTabAlpha(tab)
end

local function StartTabPulse(tab)
	if not tab or not tab._buiText then return end
	if tab._buiPulse then return end
	local pulseFrame = tab._buiPulseFrame
	if not pulseFrame then pulseFrame = CreateFrame('Frame'); tab._buiPulseFrame = pulseFrame end
	pulseFrame._t = 0
	tab._buiPulse = pulseFrame
	local text = tab._buiText
	local inactiveRed, inactiveGreen, inactiveBlue = InactiveColor()
	local flashRed, flashGreen, flashBlue = FlashColor()
	ApplyTabAlpha(tab)
	pulseFrame:SetScript('OnUpdate', function(self, elapsed)
		if not (Enabled() and TabFlash()) or not tab._buiText or IsTabSelected(tab) then
			StopTabPulse(tab)
			return
		end
		self._t = self._t + elapsed
		local phase = (math.cos(self._t * 5) + 1) * 0.5
		SetTabTextColor(text, inactiveRed + (flashRed - inactiveRed) * phase, inactiveGreen + (flashGreen - inactiveGreen) * phase, inactiveBlue + (flashBlue - inactiveBlue) * phase)
	end)
end

local function FlashWhisperTabs()
	if not (Enabled() and TabFlash()) then return end
	local selected = _G.GeneralDockManager and _G.GeneralDockManager.selected
	for tabIndex = 1, #skinnedTabs do
		local tab = skinnedTabs[tabIndex]
		if tab._buiChat and tab._buiChat ~= selected and FrameShowsWhispers(tab._buiChat) then
			StartTabPulse(tab)
		end
	end
end

local function Refresh()
	if not Enabled() then return end
	SkinPanel()
	CreateMover()
	CreateSizer()
	NormalizeDock()
	HookURLRef()
	HookHistoryCapture()
	SkinAllChatFrames()
	ApplySettings()
	RestoreGeometry()
	C_Timer.After(0.5, RestoreGeometry)
end

local installed = false
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

	if _G.FCF_OpenTemporaryWindow then
		hooksecurefunc('FCF_OpenTemporaryWindow', function()
			C_Timer.After(0, function()
				if not Enabled() then return end
				SkinAllChatFrames()
				RefreshTabs()
			end)
		end)
	end

	if _G.FCFTab_UpdateColors then
		hooksecurefunc('FCFTab_UpdateColors', function(tab, selected)
			if not Enabled() or not tab or not tab._buiChat then return end
			if selected == nil then selected = IsTabSelected(tab) end
			if selected then StopTabPulse(tab) end
			ApplyTabColor(tab, selected)
			ApplyTabAlpha(tab)
		end)
	end

	if _G.FCFDock_UpdateTabs then
		hooksecurefunc('FCFDock_UpdateTabs', AlignDockTabs)
	end

	if _G.FCF_StartAlertFlash then
		hooksecurefunc('FCF_StartAlertFlash', function(chatFrame)
			if not (Enabled() and TabFlash()) then return end
			local tab = chatFrame and (chatFrame.tab or _G[chatFrame:GetName() .. 'Tab'])
			if tab and tab._buiChat then StartTabPulse(tab) end
		end)
	end

	if _G.FCF_StopAlertFlash then
		hooksecurefunc('FCF_StopAlertFlash', function(chatFrame)
			local tab = chatFrame and (chatFrame.tab or _G[chatFrame:GetName() .. 'Tab'])
			if tab then StopTabPulse(tab) end
		end)
	end

	if _G.FCF_SetChatWindowFontSize then
		hooksecurefunc('FCF_SetChatWindowFontSize', function(_, chat, size)
			if not Enabled() then return end
			chat = chat or (_G.FCF_GetCurrentChatFrame and _G.FCF_GetCurrentChatFrame())
			if chat then
				local config = GetConfig()
				if config and config.fontSize and size then config.fontSize = size end
				local _, curSize = chat:GetFont()
				SetFontSafe(chat, ResolveFont(), size or curSize or MsgFontSize(), MsgFlags())
			end
		end)
	end

	if _G.FCF_RestorePositionAndDimensions then
		hooksecurefunc('FCF_RestorePositionAndDimensions', function(chat)
			if not Enabled() then return end
			if chat == _G.ChatFrame1 then RestoreGeometry(); NormalizeDock() end
		end)
	end

	local geometryReassertPending = false
	local function ReassertGeometry()
		if geometryReassertPending or not Enabled() then return end
		geometryReassertPending = true
		C_Timer.After(0, function()
			geometryReassertPending = false
			if not Enabled() or GeometryMatches() then return end
			RestoreGeometry()
			NormalizeDock()
			AnchorPanel()
			local chat = _G.ChatFrame1
			if chat then
				PositionEditBox(chat)
				PositionScrollBar(chat)
			end
			UpdateMover()
			UpdateSizer()
		end)
	end
	BUI.Events:Register('EDIT_MODE_LAYOUTS_UPDATED', 'Skinning.Chat', ReassertGeometry)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skinning.Chat', ReassertGeometry)

	local chat1 = _G.ChatFrame1
	if chat1 and not chat1._buiGeoHook then
		chat1._buiGeoHook = true
		local function OnExternalMove()
			if chat1._buiRestoringGeo then return end
			ReassertGeometry()
		end
		hooksecurefunc(chat1, 'SetPoint', OnExternalMove)
		hooksecurefunc(chat1, 'SetSize', OnExternalMove)
		hooksecurefunc(chat1, 'SetWidth', OnExternalMove)
		hooksecurefunc(chat1, 'SetHeight', OnExternalMove)
	end

	BUI.Events:Register('CHAT_MSG_WHISPER', 'Skinning.Chat', FlashWhisperTabs)
	BUI.Events:Register('CHAT_MSG_BN_WHISPER', 'Skinning.Chat', FlashWhisperTabs)
end

BUI.Events:OnLogin('Skinning.Chat', Install)

local function Deactivate()
	if chatPanel then chatPanel:Hide() end
	if mover then mover:Hide() end
	if sizer then sizer:Hide() end
	StopFader()
	fadeState.alpha = 1
	local chat = _G.ChatFrame1
	if chat then
		if chat._buiCog then chat._buiCog:Hide() end
		if chat._buiCopy then chat._buiCopy:Hide() end
		if chat._buiLock then chat._buiLock:Hide() end
	end
	for frameIndex = 1, #skinnedFrames do
		local chatFrame = skinnedFrames[frameIndex]
		chatFrame:SetAlpha(1)
		if chatFrame._buiSB then chatFrame._buiSB:Hide() end
		ManageHidden(_G[chatFrame:GetName() .. 'ButtonFrame'], false)
	end
	for tabIndex = 1, #skinnedTabs do
		local tab = skinnedTabs[tabIndex]
		StopTabPulse(tab)
		tab:SetAlpha(1, true)
		if tab._buiLine then tab._buiLine:Hide() end
		if tab._buiGlow then tab._buiGlow:Hide() end
		if tab._buiFill then tab._buiFill:Hide() end
		if tab._buiText then SetTabTextColor(tab._buiText, 1, 0.82, 0) end
	end
	RestoreAuxButton(_G.ChatFrameMenuButton)
	RestoreAuxButton(_G.QuickJoinToastButton)
	RestoreAuxButton(_G.ChatFrameChannelButton)
	RestoreAuxButton(_G.ChatFrameToggleVoiceDeafenButton)
	RestoreAuxButton(_G.ChatFrameToggleVoiceMuteButton)
	ManageHidden(_G.ChatFrameMenuButton, false)
	ManageHidden(_G.QuickJoinToastButton, false)
	ManageHidden(_G.ChatFrameChannelButton, false)
	ManageHidden(_G.ChatFrameToggleVoiceDeafenButton, false)
	ManageHidden(_G.ChatFrameToggleVoiceMuteButton, false)
	Skin.CollapseChatTab(_G.ChatFrame2Tab, false)
	ApplyTimestampCVar()
	BUI.Print('Chat skin disabled. Type /reload to fully restore the default chat frame.')
end

local function Reactivate()
	if chatPanel then chatPanel:Show() end
	local chat = _G.ChatFrame1
	if chat then
		if chat._buiCog then chat._buiCog:Show() end
		if chat._buiLock then chat._buiLock:Show() end
	end
	for frameIndex = 1, #skinnedFrames do
		local scrollBar = skinnedFrames[frameIndex]._buiSB
		if scrollBar then scrollBar:Show() end
	end
	Refresh()
end

Skin.OnToggle('chat', function(enabled)
	if enabled then
		if installed then Reactivate() else Install() end
	elseif installed then
		Deactivate()
	end
end)

local function BuildTextureItems()
	local items = { { value = 'SOLID', text = 'Solid Color' } }
	if sharedMedia then
		local list = sharedMedia:List('statusbar')
		for _, name in ipairs(list) do items[#items + 1] = { value = name, text = name } end
	end
	return items
end

local function ResetToDefaults()
	local config = GetConfig()
	if not config then return end
	for key, value in pairs(DEFAULTS) do
		if type(value) == 'table' then
			local copiedTable = {}
			for valueIndex = 1, #value do copiedTable[valueIndex] = value[valueIndex] end
			config[key] = copiedTable
		else
			config[key] = value
		end
	end
	ApplySettings()
	ApplyMsgFontSize()
end

local chatHiddenActive = false
local chatHideHooked = {}
local chatPreviouslyShown = {}
local chatHideHooksInstalled = false

local CHAT_HIDE_EXTRAS = {
	'GeneralDockManager', 'QuickJoinToastButton', 'ChatFrameMenuButton',
	'ChatFrameChannelButton', 'TextToSpeechButtonFrame', 'CombatLogQuickButtonFrame_Custom',
}

local function CollectChatHideTargets()
	local targets = {}
	for _, frameName in ipairs(_G.CHAT_FRAMES or {}) do
		local frame = _G[frameName]
		if frame then
			targets[#targets + 1] = frame
			local tab = _G[frameName .. 'Tab']
			if tab then targets[#targets + 1] = tab end
			if frame.buttonFrame then targets[#targets + 1] = frame.buttonFrame end
		end
	end
	for _, extraName in ipairs(CHAT_HIDE_EXTRAS) do
		local extra = _G[extraName]
		if extra then targets[#targets + 1] = extra end
	end
	return targets
end

local function ReassertChatHidden(frame)
	if chatHiddenActive and Enabled() and frame:IsShown() then frame:Hide() end
end

local function ApplyChatHidden()
	local config = GetConfig()
	local hidden = config.chatHidden == true and Enabled()
	chatHiddenActive = hidden
	local targets = CollectChatHideTargets()
	if hidden then
		if not chatHideHooksInstalled then
			chatHideHooksInstalled = true
			hooksecurefunc('ChatEdit_ActivateChat', function(editBox)
				if chatHiddenActive and editBox and _G.ChatEdit_DeactivateChat then _G.ChatEdit_DeactivateChat(editBox) end
			end)
			hooksecurefunc('FCF_OpenTemporaryWindow', function()
				if chatHiddenActive then ApplyChatHidden() end
			end)
		end
		for _, frame in ipairs(targets) do
			if not chatHideHooked[frame] then
				chatHideHooked[frame] = true
				hooksecurefunc(frame, 'Show', ReassertChatHidden)
				hooksecurefunc(frame, 'SetShown', ReassertChatHidden)
			end
			if frame:IsShown() then chatPreviouslyShown[frame] = true end
			frame:Hide()
		end
	else
		for _, frame in ipairs(targets) do
			if chatPreviouslyShown[frame] then frame:Show() end
		end
		wipe(chatPreviouslyShown)
		if _G.FCF_DockUpdate then _G.FCF_DockUpdate() end
	end
end

Skin.OnToggle('chat', function(enabled)
	if not enabled and chatHiddenActive then ApplyChatHidden() end
end)
Skin.ApplyChatHidden = ApplyChatHidden

BUI.Events:OnLogin('Skinning.ChatHidden', function()
	if GetConfig().chatHidden == true then ApplyChatHidden() end
end)

Skin.RegisterSkin('chat', {
	name = 'Chat',
	description = 'Dark panel behind the chat dock, with timestamps, copy chat, abbreviations, and fading.',
	icon = 'Interface\\Icons\\UI_Chat',
	settingsWidth = 846,
	settingsHeight = 600,
	buildSettings = function(content)
		local config = GetConfig()
		local pageKit = PageKit

		local GAP = pageKit.GAP
		local fullWidth = content.width
		local TALL, SHORT, TALLER = pageKit.CardHeight(5), pageKit.CardHeight(4), pageKit.CardHeight(6)

		local root = CreateFrame('Frame', nil, content.child)
		root:SetPoint('TOPLEFT', 0, -8)
		root:SetSize(content.width, TALL + GAP + SHORT + GAP + SHORT + GAP + TALLER)

		local function MakeCard(title, x, y, width, height)
			local cardWidget = Controls.SettingsCard(root, { title = title, width = width })
			local card = cardWidget.frame
			card:SetSize(width, height)
			card:SetPoint('TOPLEFT', x, -y)
			card:SetFrameLevel((root:GetFrameLevel() or 0) + 5)
			return card
		end

		local chatCard = MakeCard('CHAT', 0, 0, fullWidth, TALL)
		local tabsCard = MakeCard('TABS', 0, TALL + GAP, fullWidth, SHORT)
		local messagesCard  = MakeCard('MESSAGES', 0, TALL + GAP + SHORT + GAP, fullWidth, SHORT)
		local behaviorCard  = MakeCard('BEHAVIOR', 0, TALL + GAP + SHORT + GAP + SHORT + GAP, fullWidth, TALLER)

		local fontCog = pageKit.SettingsIcon(chatCard, {
			title = 'FONT', tooltip = 'Font sizes, outline & shadow', options = {
				{ kind = 'slider', label = 'Message Size', min = 8, max = 22,
				  get = function() return config.fontSize or 14 end,
				  set = function(value) config.fontSize = value end, apply = ApplyMsgFontSize },
				{ kind = 'slider', label = 'Edit Box Size', min = 8, max = 22,
				  get = function() return config.editFontSize or 13 end,
				  set = function(value) config.editFontSize = value end, apply = ApplySettings },
				{ kind = 'dropdown', label = 'Outline', items = FLAG_OPTIONS,
				  get = function() return config.fontFlags or '' end,
				  set = function(value) config.fontFlags = value end,
				  apply = function() ApplySettings(); ApplyMsgFontSize() end },
				{ label = 'Font Shadow',
				  get = function() return config.fontShadow == true end,
				  set = function(value) config.fontShadow = value end, apply = ApplySettings },
			},
		})
		local fontDropdown = Controls.Dropdown(chatCard, nil, BUI.BuildFontDropdownItems(GLOBAL_OPTION), config.font or GLOBAL_OPTION, function(value)
			config.font = value; ApplySettings(); ApplyMsgFontSize()
		end, nil, 140)
		pageKit.Row(chatCard, 38, 'Font', fontCog)
		pageKit.AttachLeft(fontDropdown, fontCog)

		local backgroundCog = pageKit.SettingsIcon(chatCard, {
			title = 'BACKGROUND', tooltip = 'Background opacity', options = {
				{ kind = 'slider', label = 'Opacity', min = 0, max = 100,
				  get = function() return floor((config.bgAlpha or DEFAULTS.bgAlpha) * 100 + 0.5) end,
				  set = function(value) config.bgAlpha = value / 100 end, apply = ApplySettings },
			},
		})
		local backgroundDropdown = Controls.Dropdown(chatCard, nil, BuildTextureItems(), config.bgTexture or 'SOLID', function(value)
			config.bgTexture = value; ApplySettings()
		end, nil, 140)
		local backgroundColor = config.bgColor or DEFAULTS.bgColor
		local backgroundSwatch = Controls.ColorSwatch(chatCard, { r = backgroundColor[1], g = backgroundColor[2], b = backgroundColor[3], hasOpacity = false, callback = function(red, green, blue)
			config.bgColor = { red, green, blue }; ApplySettings()
		end, tooltip = 'Background Color' })
		pageKit.Row(chatCard, 78, 'Background', backgroundCog)
		pageKit.AttachLeft(backgroundDropdown, backgroundCog)
		pageKit.AttachLeft(backgroundSwatch, backgroundDropdown)

		local borderCog = pageKit.SettingsIcon(chatCard, {
			title = 'BORDER', tooltip = 'Border thickness', options = {
				{ kind = 'slider', label = 'Thickness', min = 1, max = 4,
				  get = function() return config.borderThickness or 1 end,
				  set = function(value) config.borderThickness = value end, apply = ApplySettings },
			},
		})
		local borderColor = config.borderColor or DEFAULTS.borderColor
		local borderSwatch = Controls.ColorSwatch(chatCard, { r = borderColor[1], g = borderColor[2], b = borderColor[3], hasOpacity = false, callback = function(red, green, blue)
			config.borderColor = { red, green, blue }; ApplySettings()
		end, tooltip = 'Border Color' })
		local borderToggle = Controls.SwitchToggle(chatCard, nil, config.showBorder ~= false, function(value)
			config.showBorder = value; ApplySettings()
		end)
		pageKit.Row(chatCard, 118, 'Border', borderCog)
		pageKit.AttachLeft(borderSwatch, borderCog)
		pageKit.AttachLeft(borderToggle, borderSwatch)

		local function ChatGeo()
			local chatFrame = _G.ChatFrame1
			local width, height = chatFrame:GetSize()
			return chatFrame, floor((width or 400) + 0.5), floor((height or 200) + 0.5), floor((chatFrame:GetLeft() or 0) + 0.5), floor((chatFrame:GetBottom() or 0) + 0.5)
		end
		local function SetGeo(part, value)
			if InCombatLockdown() then return end
			local chatFrame, width, height, x, y = ChatGeo()
			if part == 'w' then width = value elseif part == 'h' then height = value elseif part == 'x' then x = value else y = value end
			chatFrame:SetSize(width, height)
			chatFrame:ClearAllPoints()
			chatFrame:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', x, y)
			SaveGeometry(chatFrame)
			if chatFrame.SetClampRectInsets then chatFrame:SetClampRectInsets(0, 0, 0, 0) end
			AnchorPanel(); PositionScrollBar(chatFrame); PositionEditBox(chatFrame)
			UpdateMover(); UpdateSizer()
		end
		local screenWidth, screenHeight = floor(GetScreenWidth()), floor(GetScreenHeight())
		local posIcon = pageKit.PositionIcon(chatCard, {
			title = 'POSITION', tooltip = 'Position on screen', options = {
				{ kind = 'slider', label = 'X (from left)', min = 0, max = screenWidth,
				  get = function() local _, _, _, x = ChatGeo(); return x end,
				  set = function(value) SetGeo('x', value) end },
				{ kind = 'slider', label = 'Y (from bottom)', min = 0, max = screenHeight,
				  get = function() local _, _, _, _, y = ChatGeo(); return y end,
				  set = function(value) SetGeo('y', value) end },
			},
		})
		local sizeIcon = pageKit.SizeIcon(chatCard, {
			title = 'SIZE', tooltip = 'Size & padding', options = {
				{ kind = 'slider', label = 'Width', min = 200, max = max(screenWidth, 400),
				  get = function() local _, width = ChatGeo(); return width end,
				  set = function(value) SetGeo('w', value) end },
				{ kind = 'slider', label = 'Height', min = 80, max = max(screenHeight, 200),
				  get = function() local _, _, height = ChatGeo(); return height end,
				  set = function(value) SetGeo('h', value) end },
				{ kind = 'slider', label = 'Side Padding', min = 0, max = 20,
				  get = function() return config.insetX or 5 end,
				  set = function(value) config.insetX = value end, apply = ApplySettings },
				{ kind = 'slider', label = 'Top Bar Height', min = 12, max = 40,
				  get = function() return config.insetTop or DEFAULTS.insetTop end,
				  set = function(value) config.insetTop = value end, apply = ApplySettings },
				{ kind = 'slider', label = 'Bottom Padding', min = 0, max = 20,
				  get = function() return config.insetBottom or 5 end,
				  set = function(value) config.insetBottom = value end, apply = ApplySettings },
			},
		})
		local moveCog = pageKit.SettingsIcon(chatCard, {
			title = 'MOVING', tooltip = 'Moving & resizing', options = {
				{ label = 'Lock Frame',
				  get = function() return config.locked == true end,
				  set = function(value) config.locked = value end,
				  apply = function() UpdateMover(); UpdateSizer() end },
				{ label = 'Drag Top Bar to Move',
				  get = function() return config.dragToMove ~= false end,
				  set = function(value) config.dragToMove = value end, apply = UpdateMover },
				{ label = 'Show Resize Grip',
				  get = function() return config.showSizer ~= false end,
				  set = function(value) config.showSizer = value end, apply = UpdateSizer },
			},
		})
		pageKit.Row(chatCard, 158, 'Position & Size', posIcon)
		pageKit.AttachLeft(sizeIcon, posIcon)
		pageKit.AttachLeft(moveCog, sizeIcon)

		local editBoxCog = pageKit.SettingsIcon(chatCard, {
			title = 'EDIT BOX', tooltip = 'Edit box height', options = {
				{ kind = 'slider', label = 'Height', min = 16, max = 40,
				  get = function() return config.editboxHeight or 22 end,
				  set = function(value) config.editboxHeight = value end, apply = ApplySettings },
			},
		})
		local editBoxDropdown = Controls.Dropdown(chatCard, nil, EDITBOX_OPTIONS, EditBoxPos(), function(value)
			config.editboxPosition = value; ApplySettings()
		end, nil, 140)
		pageKit.Row(chatCard, 198, 'Edit Box', editBoxCog)
		pageKit.AttachLeft(editBoxDropdown, editBoxCog)

		local tabTextCog = pageKit.SettingsIcon(tabsCard, {
			title = 'TAB TEXT', tooltip = 'Tab font & names', options = {
				{ kind = 'slider', label = 'Font Size', min = 8, max = 18,
				  get = function() return config.tabFontSize or 12 end,
				  set = function(value) config.tabFontSize = value end, apply = ApplySettings },
				{ kind = 'dropdown', label = 'Outline', items = FLAG_OPTIONS,
				  get = function() return config.tabFontFlags or '' end,
				  set = function(value) config.tabFontFlags = value end, apply = ApplySettings },
				{ label = 'Uppercase Names',
				  get = function() return config.tabUppercase == true end,
				  set = function(value) config.tabUppercase = value end, apply = ApplySettings },
				{ label = 'Hide Combat Log Tab',
				  get = function() return config.hideLogTab == true end,
				  set = function(value) config.hideLogTab = value end, apply = ApplySettings },
			},
		})
		local styleDropdown = Controls.Dropdown(tabsCard, nil, TAB_STYLE_OPTIONS, config.tabStyle or DEFAULTS.tabStyle, function(value)
			config.tabStyle = value; ApplySettings()
		end, nil, 110)
		pageKit.Row(tabsCard, 38, 'Tab Text', tabTextCog)
		pageKit.AttachLeft(styleDropdown, tabTextCog)

		local accentToggle
		local selectedColor = config.selectedColor or { 1, 1, 1 }
		local activeSwatch = Controls.ColorSwatch(tabsCard, { r = selectedColor[1], g = selectedColor[2], b = selectedColor[3], hasOpacity = false, callback = function(red, green, blue)
			config.selectedColor = { red, green, blue }
			config.selectedUseAccent = false
			if accentToggle and accentToggle.SetValue then accentToggle:SetValue(false) end
			ApplySettings()
		end, tooltip = 'Active Tab Accent (turns off theme accent)' })
		local inactiveColor = config.inactiveColor or DEFAULTS.inactiveColor
		local inactiveSwatch = Controls.ColorSwatch(tabsCard, { r = inactiveColor[1], g = inactiveColor[2], b = inactiveColor[3], hasOpacity = false, callback = function(red, green, blue)
			config.inactiveColor = { red, green, blue }; ApplySettings()
		end, tooltip = 'Inactive Tab Color' })
		accentToggle = Controls.SwitchToggle(tabsCard, nil, config.selectedUseAccent ~= false, function(value)
			config.selectedUseAccent = value; ApplySettings()
		end, nil, nil, 'Use the theme accent for the active tab')
		pageKit.Row(tabsCard, 78, 'Tab Colors', inactiveSwatch)
		pageKit.AttachLeft(activeSwatch, inactiveSwatch)
		pageKit.AttachLeft(accentToggle, activeSwatch)

		local tabOpacityCog = pageKit.SettingsIcon(tabsCard, {
			title = 'TAB OPACITY', tooltip = 'Tab opacity', options = {
				{ kind = 'slider', label = 'Selected Tab', min = 10, max = 100,
				  get = function() return floor((config.selectedAlpha or 1) * 100 + 0.5) end,
				  set = function(value) config.selectedAlpha = value / 100 end, apply = ApplySettings },
				{ kind = 'slider', label = 'Background Tabs', min = 0, max = 100,
				  get = function() return floor((config.dockedAlpha or 0.6) * 100 + 0.5) end,
				  set = function(value) config.dockedAlpha = value / 100 end, apply = ApplySettings },
			},
		})
		pageKit.Row(tabsCard, 118, 'Opacity', tabOpacityCog)

		local flashColor = config.flashColor or DEFAULTS.flashColor
		local flashSwatch = Controls.ColorSwatch(tabsCard, { r = flashColor[1], g = flashColor[2], b = flashColor[3], hasOpacity = false, callback = function(red, green, blue)
			config.flashColor = { red, green, blue }; ApplySettings()
		end, tooltip = 'Flash Color' })
		local flashToggle = Controls.SwitchToggle(tabsCard, nil, config.tabFlash ~= false, function(value)
			config.tabFlash = value; ApplySettings()
		end)
		pageKit.Row(tabsCard, 158, 'Flash on Message', flashSwatch)
		pageKit.AttachLeft(flashToggle, flashSwatch)

		local stampCog = pageKit.SettingsIcon(messagesCard, {
			title = 'TIMESTAMPS', tooltip = 'Timestamp format', options = {
				{ kind = 'dropdown', label = 'Format', items = TIMESTAMP_OPTIONS,
				  get = function() return config.timestampFormat or '%H:%M' end,
				  set = function(value) config.timestampFormat = value end },
			},
		})
		local timestampColor = config.timestampColor or DEFAULTS.timestampColor
		local stampSwatch = Controls.ColorSwatch(messagesCard, { r = timestampColor[1], g = timestampColor[2], b = timestampColor[3], hasOpacity = false, callback = function(red, green, blue)
			config.timestampColor = { red, green, blue }
		end, tooltip = 'Timestamp Color' })
		local stampToggle = Controls.SwitchToggle(messagesCard, nil, config.timestamps == true, function(value)
			config.timestamps = value; ApplySettings()
		end)
		pageKit.Row(messagesCard, 38, 'Timestamps', stampCog)
		pageKit.AttachLeft(stampSwatch, stampCog)
		pageKit.AttachLeft(stampToggle, stampSwatch)

		local linksCog = pageKit.SettingsIcon(messagesCard, {
			title = 'LINKS', tooltip = 'Link behavior', options = {
				{ label = 'Tooltip on Hover',
				  get = function() return config.hoverTooltips ~= false end,
				  set = function(value) config.hoverTooltips = value end },
			},
		})
		local urlColor = config.urlColor or DEFAULTS.urlColor
		local urlSwatch = Controls.ColorSwatch(messagesCard, { r = urlColor[1], g = urlColor[2], b = urlColor[3], hasOpacity = false, callback = function(red, green, blue)
			config.urlColor = { red, green, blue }
		end, tooltip = 'Link Color' })
		local urlToggle = Controls.SwitchToggle(messagesCard, nil, config.urlCopy ~= false, function(value)
			config.urlCopy = value
		end)
		pageKit.Row(messagesCard, 78, 'Clickable Links', linksCog)
		pageKit.AttachLeft(urlSwatch, linksCog)
		pageKit.AttachLeft(urlToggle, urlSwatch)

		local channelCog = pageKit.SettingsIcon(messagesCard, {
			title = 'CHANNELS', tooltip = 'Channel display', options = {
				{ label = 'Hide Channel Numbers',
				  get = function() return config.hideChannelNumbers == true end,
				  set = function(value) config.hideChannelNumbers = value end },
				{ label = 'Abbreviate Names',
				  get = function() return config.abbreviateChannels == true end,
				  set = function(value) config.abbreviateChannels = value end },
			},
		})
		pageKit.Row(messagesCard, 118, 'Channels', channelCog)

		local scrollCog = pageKit.SettingsIcon(messagesCard, {
			title = 'SCROLLING', tooltip = 'Scroll speed', options = {
				{ kind = 'slider', label = 'Lines per Scroll', min = 1, max = 10,
				  get = function() return config.scrollLines or 3 end,
				  set = function(value) config.scrollLines = value end },
			},
		})
		pageKit.Row(messagesCard, 158, 'Scrolling', scrollCog)

		local messageFadeCog = pageKit.SettingsIcon(behaviorCard, {
			title = 'MESSAGE FADE', tooltip = 'Fade timing', options = {
				{ kind = 'slider', label = 'Visible Time (sec)', min = 10, max = 300, step = 5,
				  get = function() return config.msgFadeTime or 120 end,
				  set = function(value) config.msgFadeTime = value end, apply = ApplySettings },
			},
		})
		local messageFadeToggle = Controls.SwitchToggle(behaviorCard, nil, config.msgFade == true, function(value)
			config.msgFade = value; ApplySettings()
		end)
		pageKit.Row(behaviorCard, 38, 'Fade Old Messages', messageFadeCog)
		pageKit.AttachLeft(messageFadeToggle, messageFadeCog)

		local hoverFadeCog = pageKit.SettingsIcon(behaviorCard, {
			title = 'HOVER FADE', tooltip = 'Fade delay', options = {
				{ kind = 'slider', label = 'Delay (sec)', min = 0, max = 10,
				  get = function() return config.fadeDelay or 2 end,
				  set = function(value) config.fadeDelay = value end },
			},
		})
		local hoverFadeToggle = Controls.SwitchToggle(behaviorCard, nil, config.mouseoverFade == true, function(value)
			config.mouseoverFade = value
			if value then StartFader() else StopFader() end
		end)
		pageKit.Row(behaviorCard, 78, 'Fade When Not Hovered', hoverFadeCog)
		pageKit.AttachLeft(hoverFadeToggle, hoverFadeCog)

		local clearButton = Controls.Button(behaviorCard, 'Clear', 84, function()
			wipe(GetHistory())
		end, 'Clear saved input history')
		local historyToggle = Controls.SwitchToggle(behaviorCard, nil, config.editHistory ~= false, function(value)
			config.editHistory = value
		end)
		pageKit.Row(behaviorCard, 118, 'Input History', clearButton)
		pageKit.AttachLeft(historyToggle, clearButton)

		local buttonsCog = pageKit.SettingsIcon(behaviorCard, {
			title = 'BUTTONS', tooltip = 'Chat buttons', options = {
				{ label = 'Hide Menu & Social',
				  get = function() return config.hideButtons ~= false end,
				  set = function(value) config.hideButtons = value end, apply = ApplySettings },
				{ label = 'Hide Voice Buttons',
				  get = function() return config.hideVoiceButtons ~= false end,
				  set = function(value) config.hideVoiceButtons = value end, apply = ApplySettings },
				{ label = 'Show Copy-Chat Button',
				  get = function() return config.showCopyButton ~= false end,
				  set = function(value) config.showCopyButton = value end, apply = UpdateCopyButton },
			},
		})
		pageKit.Row(behaviorCard, 158, 'Buttons', buttonsCog)

		local resetButton = Controls.Button(behaviorCard, 'Reset', 84, function()
			ResetToDefaults()
			content.Rebuild()
		end, 'Restore all chat settings to defaults')
		pageKit.Row(behaviorCard, 198, 'Restore Defaults', resetButton)

		local hideChatToggle = Controls.SwitchToggle(behaviorCard, nil, config.chatHidden == true, function(value)
			config.chatHidden = value
			ApplyChatHidden()
			ApplySettings()
		end)
		pageKit.Row(behaviorCard, 238, 'Hide Chat Completely', hideChatToggle)

		content:Refresh()
	end,
})
