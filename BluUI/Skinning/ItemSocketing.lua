local _, BUI = ...

local ipairs = ipairs
local select = select

local Skin = BUI.Skinning

local TOOLTIP_ART = { 'NineSlice', 'Bg' }
local APPLY_INSET = 4

local context = Skin.Define('itemsocketing', {
	name = 'Item Socketing',
	description = 'The gem socketing window: the parchment and gold filigree stripped back to the dark shell, framed socket icons and a house-styled Apply button.',
	icon = 'Interface/Icons/INV_Misc_Gem_Variety_01',
})
local FadeRegions, FadeKeys = context.FadeRegions, context.FadeKeys
local Shell, Button, ScrollBar, Title = context.Shell, context.Button, context.ScrollBar, context.Title

local function TitleRegions(frame)
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region.IsObjectType and region:IsObjectType('FontString') then Title(region) end
	end
end

local function SkinSocket(socket)
	if socket._buiSocket then return end
	socket._buiSocket = true
	socket.Icon.__buiSkin = true
	FadeRegions(socket)
	FadeRegions(socket.BracketFrame)
	Skin.CropIcon(socket.Icon)
	Skin.TipIconFrame(socket, socket.Icon, 1)
end

local function SkinDescription(description)
	if description._buiSocketText then return end
	description._buiSocketText = true
	description:DisableDrawLayer('BORDER')
	description:DisableDrawLayer('BACKGROUND')
	FadeRegions(description)
	FadeKeys(description, TOOLTIP_ART)
end

local function RefreshSockets(frame)
	SkinDescription(_G.ItemSocketingDescription)
	for _, socket in ipairs(frame.SocketingContainer.SocketFrames) do SkinSocket(socket) end
end

local function SkinFrame(frame)
	context.Chrome(frame)
	Skin.FadeTree(frame.Inset)
	TitleRegions(frame)
	local scroll = _G.ItemSocketingScrollFrame
	Shell(scroll)
	ScrollBar(scroll.ScrollBar)
	local container = frame.SocketingContainer
	FadeRegions(container)
	local apply = container.ApplySocketsButton
	Button(apply)
	apply:ClearAllPoints()
	apply:SetPoint('BOTTOM', frame, 'BOTTOM', 0, APPLY_INSET)
end

context.Window('ItemSocketingFrame', {
	skin = SkinFrame,
	show = RefreshSockets,
	install = function() context.Hook('ItemSocketingFrame_Update', function() RefreshSockets(_G.ItemSocketingFrame) end) end,
})
