local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local APPLY_INSET = 4

local context = Skin.Define('itemsocketing', {
	name = 'Item Socketing',
	description = 'The gem socketing window: the parchment and gold filigree stripped back to the dark shell, framed socket icons and a library-styled Apply button.',
	icon = 'Interface/Icons/INV_Misc_Gem_Variety_01',
})
local Fade, FadeRegions, Keep = context.Fade, context.FadeRegions, context.Keep
local Shell, Button, ScrollBar, Title = context.Shell, context.Button, context.ScrollBar, context.Title

local function TitleRegions(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType('FontString') then Title(region) end
	end
end

local function SkinSocket(socket)
	if socket._buiSocket then return end
	socket._buiSocket = true
	Keep(socket.Icon)
	FadeRegions(socket)
	FadeRegions(socket.BracketFrame)
	Skin.SquareIcon(socket, socket.Icon, 1)
end

local function SkinDescription(description)
	if description._buiSocketText then return end
	description._buiSocketText = true
	description:DisableDrawLayer('BORDER')
	description:DisableDrawLayer('BACKGROUND')
	FadeRegions(description)
	Fade(description.NineSlice)
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
