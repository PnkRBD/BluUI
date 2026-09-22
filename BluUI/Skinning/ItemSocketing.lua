local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('ItemSocketing')

local ipairs = ipairs
local select = select

local hooksecurefunc = BUI.Prof.MakeHooker('itemsocketing')
local Skin = BUI.Skinning

local SKIN_ID = 'itemsocketing'
local TOOLTIP_ART = { 'NineSlice', 'Bg' }
local APPLY_INSET = 4

local installed = false
local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, ScrollBar, Title = context.Shell, context.Button, context.Close, context.ScrollBar, context.Title

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function TitleRegions(frame)
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region and region.IsObjectType and region:IsObjectType('FontString') then Title(region) end
	end
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
end

local function SkinSocket(socket)
	if not socket or socket._buiSocket then return end
	socket._buiSocket = true

	KeepTexture(socket.Icon)
	FadeRegions(socket)
	FadeRegions(socket.BracketFrame)

	if socket.Icon then
		Skin.CropIcon(socket.Icon)
		Skin.TipIconFrame(socket, socket.Icon, 1)
	end
end

local function SkinDescription(description)
	if not description or description._buiSocketText then return end
	description._buiSocketText = true
	description:DisableDrawLayer('BORDER')
	description:DisableDrawLayer('BACKGROUND')
	FadeRegions(description)
	FadeKeys(description, TOOLTIP_ART)
end

local function Apply()
	local frame = _G.ItemSocketingFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end

	if not skinned then
		skinned = true
		FadeRegions(frame)
		Fade(frame.NineSlice)
		if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
		Skin.FadeTree(frame.Inset)
		Shell(frame)
		Close(frame.CloseButton)
		TitleRegions(frame)

		local scroll = _G.ItemSocketingScrollFrame
		if scroll then
			Shell(scroll)
			ScrollBar(scroll.ScrollBar)
		end

		local container = frame.SocketingContainer
		if container then
			FadeRegions(container)
			local apply = container.ApplySocketsButton
			if apply then
				Button(apply)
				apply:ClearAllPoints()
				apply:SetPoint('BOTTOM', frame, 'BOTTOM', 0, APPLY_INSET)
			end
		end

		if _G.ItemSocketingFrame_Update then
			hooksecurefunc('ItemSocketingFrame_Update', Apply)
		end
	end

	SkinDescription(_G.ItemSocketingDescription)

	local container = frame.SocketingContainer
	if container and container.SocketFrames then
		for _, socket in ipairs(container.SocketFrames) do SkinSocket(socket) end
	end
end

local function Install()
	if installed then return end
	local frame = _G.ItemSocketingFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.ItemSocketing') end
end

local function Deactivate()
	context.Restore()
	skinned = false
	BUI.Print('Item Socketing skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.ItemSocketing', TryInstall)
		elseif _G.ItemSocketingFrame and _G.ItemSocketingFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

BUI.Events:Once('PLAYER_LOGIN', 'Skin.ItemSocketingInstall', function()
	if not Enabled() then return end
	Install()
	if not installed then BUI.Events:Register('ADDON_LOADED', 'Skin.ItemSocketing', TryInstall) end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Item Socketing',
	description = 'The gem socketing window: the parchment and gold filigree stripped back to the dark shell, framed socket icons and a house-styled Apply button.',
	icon = 'Interface/Icons/INV_Misc_Gem_Variety_01',
})
