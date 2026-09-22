local hostAddon = ...
local MAJOR, MINOR = 'BUILib', 23
local BUILib = LibStub:NewLibrary(MAJOR, MINOR)

LibStub(MAJOR).__loadChildren = BUILib ~= nil
if not BUILib then return end

BUILib.FONT_SIZE = 11
BUILib.CONTROL_HEIGHT = 36
BUILib.ROW_HEIGHT = 28
BUILib.BUTTON_ROW_HEIGHT = 24
BUILib.LABEL_OFFSET = 22
BUILib.TOGGLE_HEIGHT = 22

BUILib.__baseFont = BUILib.__baseFont or 'Fonts\\FRIZQT__.TTF'
BUILib.mediaPath = ''
BUILib.libMediaPath = ('Interface\\AddOns\\%s\\Libs\\BUILib\\Media\\'):format(hostAddon)

local function newClientTable(name, config)
	config = config or {}
	return {
		name         = name,
		getDB        = config.getDB,
		mediaPath    = config.mediaPath or '',
		libMediaPath = config.libMediaPath or (('Interface\\AddOns\\%s\\Libs\\BUILib\\Media\\'):format(name or hostAddon)),
		font         = config.font or BUILib.__baseFont,
		popupStrata  = 'FULLSCREEN_DIALOG',
		popupLevel   = 200,
		popupParent  = nil,
	}
end

BUILib.__defaultClient = BUILib.__defaultClient or newClientTable(hostAddon, { libMediaPath = BUILib.libMediaPath })
BUILib.__activeClient  = BUILib.__activeClient or BUILib.__defaultClient

function BUILib.GetActiveClient() return BUILib.__activeClient or BUILib.__defaultClient end
function BUILib.SetActiveClient(client)
	local previousClient = BUILib.__activeClient
	BUILib.__activeClient = client or BUILib.__defaultClient
	return previousClient
end

function BUILib.SetDefaultClient(client)
	if not client then return end
	BUILib.__defaultClient = client
	BUILib.__activeClient  = client
end

function BUILib.ClientOf(frame)
	while frame do
		if frame.__bui3client then return frame.__bui3client end
		frame = frame.GetParent and frame:GetParent()
	end
	return BUILib.GetActiveClient()
end

function BUILib.GetLibMedia(filename) return BUILib.GetActiveClient().libMediaPath .. filename end
function BUILib.GetFont()             return BUILib.GetActiveClient().font or BUILib.__baseFont end

setmetatable(BUILib, { __index = function(_, key)
	if key == "Font" then return BUILib.GetFont() end
end })

function BUILib.SetFont(path)      BUILib.__defaultClient.font = path end

local function makeClientView(realTable, client)
	return setmetatable({}, { __index = function(_, key)
		local member = realTable[key]
		if type(member) ~= 'function' then return member end
		return function(...)
			local previousClient = BUILib.SetActiveClient(client)
			local function restore(...) BUILib.SetActiveClient(previousClient); return ... end
			return restore(member(...))
		end
	end })
end

local CLIENT_VIEWS = {
	Controls = true, Layout = true, PageKit = true, Widget = true,
	Theme = true, Colors = true, Modals = true, Toast = true,
}

function BUILib.NewClient(name, config)
	config = config or {}
	local client = newClientTable(name, config)
	local views = {}

	client.SetFont        = function(path) client.font = path end
	client.Activate       = function() return BUILib.SetActiveClient(client) end
	client.GetLibMedia    = function(filename) return client.libMediaPath .. filename end
	client.GetPopupStrata = function() return client.popupStrata or 'FULLSCREEN_DIALOG' end
	client.GetPopupLevel  = function() return (client.popupLevel or 200) + 100 end
	client.GetPopupParent = function() return client.popupParent end
	client.SetPopupParent = function(frame)
		client.popupStrata = frame:GetFrameStrata()
		client.popupLevel  = frame:GetFrameLevel()
		client.popupParent = frame
	end

	setmetatable(client, { __index = function(_, key)
		if key == 'Font' then return client.font or BUILib.__baseFont end
		if CLIENT_VIEWS[key] then
			local view = views[key]
			if not view then
				local real = BUILib[key]
				if type(real) ~= 'table' then return real end
				view = makeClientView(real, client)
				views[key] = view
			end
			return view
		end
		return BUILib[key]
	end })

	if config.default then
		BUILib.__defaultClient = client
		BUILib.__activeClient  = client
	end
	return client
end

BUILib.Controls = BUILib.Controls or {}
BUILib.Layout = BUILib.Layout or {}
BUILib.Modals = BUILib.Modals or {}
BUILib.Toast = BUILib.Toast or {}

function BUILib.SetCardStyle(style)
	local previous = BUILib.__cardStyle
	BUILib.__cardStyle = style
	return previous
end

function BUILib.GetCardStyle() return BUILib.__cardStyle end
function BUILib.IsDatasheet() return BUILib.__cardStyle == 'datasheet' end

function BUILib.SetPopupParent(frame)
	local client = BUILib.GetActiveClient()
	client.popupStrata = frame:GetFrameStrata()
	client.popupLevel  = frame:GetFrameLevel()
	client.popupParent = frame
end

function BUILib.GetPopupStrata() return BUILib.GetActiveClient().popupStrata or 'FULLSCREEN_DIALOG' end
function BUILib.GetPopupLevel() return (BUILib.GetActiveClient().popupLevel or 200) + 100 end
function BUILib.GetPopupParent() return BUILib.GetActiveClient().popupParent end
