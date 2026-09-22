local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('SplashFrame')

local hooksecurefunc = BUI.Prof.MakeHooker('splash')
local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'splash'
local KIT_TEXTURE_KEYS = { 'LeftTexture', 'RightTexture', 'BottomTexture' }
local FEATURE_KEYS = { 'TopLeftFeature', 'BottomLeftFeature' }
local RECT_MASK_TEXTURE = BUI.C.MEDIA_PATH .. 'solid'
local CIRCLE_MASK_TEXTURE = BUILib.GetLibMedia('circle_mask')
local MASK_WRAP = 'CLAMPTOBLACKADDITIVE'
local CIRCLE_SIZE = 360
local CIRCLE_OFFSET_X = -4
local CIRCLE_OFFSET_Y = 8
local CIRCLE_EDGE = 1
local PICTURE_SUBLEVEL = -2
local RING_SUBLEVEL = -3
local PICTURE_EDGE = 1
local HEADER_SCALE = 1.6
local LABEL_SCALE = 1.2
local FEATURE_TITLE_SCALE = 1.25
local FEATURE_BODY_SCALE = 1
local RIGHT_TITLE_SCALE = 2.8
local RIGHT_BODY_SCALE = 1.1
local QUEST_BUTTON_SCALE = 1.3
local SHADOW_OFFSET = 1

local installed = false
local built = false
local pictures = {}
local decor = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local FadeRegions = context.FadeRegions
local Shell, Button, Close = context.Shell, context.Button, context.Close

local function PictureText(fontString, kind, scale)
	Skin.TipFont(fontString, kind, scale)
	fontString:SetShadowColor(0, 0, 0, 1)
	fontString:SetShadowOffset(SHADOW_OFFSET, -SHADOW_OFFSET)
end

local function NewMask(frame, texturePath)
	local mask = frame:CreateMaskTexture()
	mask:SetTexture(texturePath, MASK_WRAP, MASK_WRAP)
	return mask
end

local function AddPictures(frame, mask)
	for _, key in ipairs(KIT_TEXTURE_KEYS) do
		local source = frame[key]
		if source then
			local picture = frame:CreateTexture(nil, 'ARTWORK', nil, PICTURE_SUBLEVEL)
			picture.__buiSkin = true
			picture:AddMaskTexture(mask)
			picture.source = source
			pictures[#pictures + 1] = picture
		end
	end
end

local function SyncPictures()
	for _, picture in ipairs(pictures) do
		local source = picture.source
		local shown = source:IsShown() and source:GetTexture() ~= nil
		picture:SetShown(shown)
		if shown then
			picture:SetTexture(source:GetTexture())
			picture:SetTexCoord(source:GetTexCoord())
			picture:ClearAllPoints()
			picture:SetAllPoints(source)
		end
	end
end

local function SetDecorShown(shown)
	for _, region in ipairs(decor) do region:SetShown(shown) end
	if shown then return end
	for _, picture in ipairs(pictures) do picture:Hide() end
end

local function FrameFeature(frame, feature)
	local mask = NewMask(frame, RECT_MASK_TEXTURE)
	mask:SetAllPoints(feature)
	AddPictures(frame, mask)
	Skin.TipIconFrame(frame, feature, PICTURE_EDGE)
	local edges = feature._buiIconFrame
	for edgeIndex = 1, 4 do decor[#decor + 1] = edges[edgeIndex] end
end

local function FrameCircle(frame, host)
	local mask = NewMask(frame, CIRCLE_MASK_TEXTURE)
	mask:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
	mask:SetPoint('CENTER', host, 'CENTER', CIRCLE_OFFSET_X, CIRCLE_OFFSET_Y)
	AddPictures(frame, mask)

	local ringSize = CIRCLE_SIZE + CIRCLE_EDGE * 2
	local ringMask = NewMask(frame, CIRCLE_MASK_TEXTURE)
	ringMask:SetSize(ringSize, ringSize)
	ringMask:SetPoint('CENTER', host, 'CENTER', CIRCLE_OFFSET_X, CIRCLE_OFFSET_Y)
	local ring = frame:CreateTexture(nil, 'ARTWORK', nil, RING_SUBLEVEL)
	ring.__buiSkin = true
	ring:SetTexture(RECT_MASK_TEXTURE)
	local backdrop = BUI.C.PANEL_BACKDROP
	ring:SetVertexColor(backdrop[5], backdrop[6], backdrop[7], backdrop[8])
	ring:SetSize(ringSize, ringSize)
	ring:SetPoint('CENTER', host, 'CENTER', CIRCLE_OFFSET_X, CIRCLE_OFFSET_Y)
	ring:AddMaskTexture(ringMask)
	decor[#decor + 1] = ring
end

local function RefreshQuestButtonText(button)
	PictureText(button.Text, 'title', QUEST_BUTTON_SCALE)
end

local function RefreshText(frame)
	Skin.TipFont(frame.Header, 'title', HEADER_SCALE)
	Skin.TipFont(frame.Label, 'body', LABEL_SCALE)
	for _, key in ipairs(FEATURE_KEYS) do
		local feature = frame[key]
		PictureText(feature.Title, 'title', FEATURE_TITLE_SCALE)
		PictureText(feature.Description, 'body', FEATURE_BODY_SCALE)
	end
	local right = frame.RightFeature
	PictureText(right.Title, 'title', RIGHT_TITLE_SCALE)
	PictureText(right.Description, 'body', RIGHT_BODY_SCALE)
	RefreshQuestButtonText(right.StartQuestButton)
end

local function Build(frame)
	for _, key in ipairs(FEATURE_KEYS) do FrameFeature(frame, frame[key]) end
	local right = frame.RightFeature
	FrameCircle(frame, right)
	local questButton = right.StartQuestButton
	HookScript(questButton, 'OnEnter', RefreshQuestButtonText)
	HookScript(questButton, 'OnLeave', RefreshQuestButtonText)
end

local function SkinFrame(frame)
	FadeRegions(frame)
	Shell(frame)
	Close(frame.TopCloseButton)
	Button(frame.BottomCloseButton)
	Button(frame.RightFeature.StartQuestButton)
end

local function Apply()
	local frame = _G.SplashFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not built then
		built = true
		Build(frame)
	end
	SkinFrame(frame)
	RefreshText(frame)
	SetDecorShown(true)
	SyncPictures()
end

local function Install()
	if installed then return end
	local frame = _G.SplashFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	hooksecurefunc(frame, 'SetupFrame', Apply)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Splash') end
end

local function Deactivate()
	context.Restore()
	SetDecorShown(false)
	BUI.Print("What's New skin disabled. /reload for a full visual reset.")
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Splash', TryInstall)
		elseif _G.SplashFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

BUI.Events:Once('PLAYER_LOGIN', 'Skin.SplashInstall', function()
	if not Enabled() then return end
	Install()
	if not installed then BUI.Events:Register('ADDON_LOADED', 'Skin.Splash', TryInstall) end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = "What's New",
	description = "The seasonal What's New splash: parchment and banner art replaced by the dark shell, the feature pictures kept as framed cards and a round portrait, house fonts and buttons.",
	icon = 'Interface/Icons/INV_Misc_Note_06',
	test = function()
		local frame = _G.SplashFrame
		if not frame then return end
		if not frame:IsShown() then
			C_SplashScreen.RequestLatestSplashScreen(false)
			return
		end
		return frame
	end,
	stopTest = function()
		local frame = _G.SplashFrame
		if frame and frame:IsShown() then HideUIPanel(frame) end
	end,
})
