local _, BUI = ...

local select, pcall = select, pcall

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Tools = BUI.Tools

local SKIN_ID = 'loothistory'
local FRAME_NAME = 'GroupLootHistoryFrame'
local ROW_ART_KEYS = { 'NameFrame', 'BorderFrame', 'HighlightNameFrame', 'PushedNameFrame', 'IconQuestTexture' }
local ICON_ART_KEYS = { 'IconBorder', 'Border', 'IconQuestTexture' }
local ROW_TEXT_KEYS = { 'Text', 'PlayerName', 'Name', 'RollResult' }
local ROLL_ICON_SIZE = 14
local ROLL_STATE = Enum.EncounterLootDropRollState
local ROLL_ICONS = {
	[ROLL_STATE.NeedMainSpec] = CreateAtlasMarkup('lootroll-icon-need', ROLL_ICON_SIZE, ROLL_ICON_SIZE),
	[ROLL_STATE.NeedOffSpec]  = CreateAtlasMarkup('lootroll-icon-need', ROLL_ICON_SIZE, ROLL_ICON_SIZE),
	[ROLL_STATE.Transmog]     = CreateAtlasMarkup('lootroll-icon-transmog', ROLL_ICON_SIZE, ROLL_ICON_SIZE),
	[ROLL_STATE.Greed]        = CreateAtlasMarkup('lootroll-icon-greed', ROLL_ICON_SIZE, ROLL_ICON_SIZE),
	[ROLL_STATE.Pass]         = CreateAtlasMarkup('lootroll-icon-pass', ROLL_ICON_SIZE, ROLL_ICON_SIZE),
}
local WINNER_MARK = ' ' .. CreateAtlasMarkup('lootroll-icon-checkmark', ROLL_ICON_SIZE, ROLL_ICON_SIZE)

local installed = false
local skinned = false
local fadedArt = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local function Frame()
	return _G[FRAME_NAME]
end

local function FadeTextures(frame, keep)
	if not frame or not frame.GetRegions then return end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region and region ~= keep and region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then
			fadedArt[region] = true
			region:SetAlpha(0)
		end
	end
end

local function FadeKeys(frame, keys)
	for keyIndex = 1, #keys do
		local child = frame[keys[keyIndex]]
		if child and child.IsObjectType then
			if child:IsObjectType('Texture') then
				fadedArt[child] = true
				child:SetAlpha(0)
			else
				FadeTextures(child)
			end
		end
	end
end

local function AddRollLine(roll)
	local name = RAID_CLASS_COLORS[roll.playerClass]:WrapTextInColorCode(roll.playerName)
	if roll.state == ROLL_STATE.NeedOffSpec then name = LOOT_HISTORY_OFF_SPEC_FMT:format(name) end
	if roll.isWinner then name = name .. WINNER_MARK end
	GameTooltip:AddDoubleLine(ROLL_ICONS[roll.state] .. ' ' .. name, roll.roll and tostring(roll.roll) or '', 1, 1, 1, 1, 1, 1)
end

local function ShowAllRolls(row)
	local drop = row.dropInfo
	if not drop or not Enabled() then return end
	GameTooltip:SetOwner(row, 'ANCHOR_RIGHT', -7, -6)
	local red, green, blue = row.ItemName:GetVertexColor()
	GameTooltip:AddLine(row.ItemName:GetText(), red, green, blue)
	local winner, waiting = drop.winner
	for _, roll in ipairs(drop.rollInfos) do
		if roll.state == ROLL_STATE.NoRoll then
			waiting = waiting or {}
			waiting[#waiting + 1] = RAID_CLASS_COLORS[roll.playerClass]:WrapTextInColorCode(roll.playerName)
		elseif not (winner and not roll.isWinner and roll.roll and roll.roll > winner.roll) then
			AddRollLine(roll)
		end
	end
	if drop.allPassed then
		GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode(LOOT_HISTORY_ALL_PASSED))
	elseif waiting and not winner then
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
		GameTooltip_AddNormalLine(GameTooltip, LOOT_HISTORY_WAITING_ON .. table.concat(waiting, LOOT_HISTORY_PLAYER_DELIMITER), true)
	end
	GameTooltip:Show()
end

local function SkinRow(row)
	if not row or row:IsForbidden() or not Enabled() then return end
	if row._buiLootRow then return end
	row._buiLootRow = true
	if row.SetTooltip then hooksecurefunc(row, 'SetTooltip', ShowAllRolls) end
	if row.BackgroundArtFrame then FadeTextures(row.BackgroundArtFrame) end
	FadeKeys(row, ROW_ART_KEYS)
	local item = row.Item
	if item then
		FadeKeys(item, ICON_ART_KEYS)
		local normal = item.GetNormalTexture and item:GetNormalTexture()
		if normal then normal:SetAlpha(0) end
		local icon = item.icon or item.Icon
		if icon and icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	end
	for keyIndex = 1, #ROW_TEXT_KEYS do
		local fontString = row[ROW_TEXT_KEYS[keyIndex]]
		if fontString and fontString.SetFont then Skin.TipFace(fontString, 'body') end
	end
end

local function SkinRows(frame)
	local box = frame.ScrollBox
	if not box or not box.ForEachFrame then return end
	pcall(box.ForEachFrame, box, SkinRow)
	if not box._buiRowHook and box.Update then
		box._buiRowHook = true
		hooksecurefunc(box, 'Update', function(scrollBox)
			pcall(scrollBox.ForEachFrame, scrollBox, SkinRow)
		end)
	end
end

local function SkinClose(frame)
	local close = frame.ClosePanelButton or frame.CloseButton or (frame.TitleContainer and frame.TitleContainer.CloseButton)
	if not close or close._buiClose then return end
	close._buiClose = true
	BUILib.Skin.StripButton(close)
	local glyph = close:CreateTexture(nil, 'OVERLAY')
	glyph.__buiSkin = true
	glyph:SetTexture(BUILib.GetLibMedia('x'))
	glyph:SetSize(12, 12)
	glyph:SetPoint('CENTER', close, 'CENTER', 0, 0)
	glyph:SetVertexColor(0.75, 0.75, 0.8, 1)
	close:HookScript('OnEnter', function() glyph:SetVertexColor(1, 1, 1, 1) end)
	close:HookScript('OnLeave', function() glyph:SetVertexColor(0.75, 0.75, 0.8, 1) end)
end

local function SkinDropdown(dropdown)
	Skin.TipDropdown(dropdown)
end

local function SkinTimer(timer)
	if not timer then return end
	local fill = timer.Fill
	if not timer._buiSkinned then
		timer._buiSkinned = true
		FadeTextures(timer, fill)
		local background = timer:CreateTexture(nil, 'BACKGROUND')
		background.__buiSkin = true
		background:SetAllPoints(timer)
		Tools.SetColorTex(background, 0, 0, 0, 0.5)
	end
	if fill then
		fill:SetTexture(BUI.GetGlobalTexture())
		local red, green, blue = BUILib.Theme.GetAccent()
		fill:SetVertexColor(red, green, blue, 1)
	end
end

local function SkinScrollBar(scrollBar)
	if not scrollBar or scrollBar._buiSkinned then return end
	scrollBar._buiSkinned = true
	Skin.FadeTree(scrollBar)
	local thumb = scrollBar.Track and scrollBar.Track.Thumb
	if thumb then
		local fill = thumb:CreateTexture(nil, 'OVERLAY')
		fill.__buiSkin = true
		fill:SetPoint('TOPLEFT', thumb, 'TOPLEFT', 2, 0)
		fill:SetPoint('BOTTOMRIGHT', thumb, 'BOTTOMRIGHT', -2, 0)
		local edge = BUI.C.PANEL_BACKDROP
		Tools.SetColorTex(fill, edge[5], edge[6], edge[7], 1)
	end
end

local function Apply()
	local frame = Frame()
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
		FadeKeys(frame, { 'Bg', 'Background', 'Border' })
		FadeTextures(frame)
		if frame.TitleContainer then FadeTextures(frame.TitleContainer) end
		SkinClose(frame)
	end
	Skin.TipShell(frame)
	local title = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText
	Skin.TipFont(title, 'title')
	SkinDropdown(frame.EncounterDropdown)
	SkinTimer(frame.Timer)
	SkinScrollBar(frame.ScrollBar)
	SkinRows(frame)
end

local function Install()
	if installed then return end
	local frame = Frame()
	if not frame then return end
	installed = true
	frame:HookScript('OnShow', Apply)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.LootHistory') end
end

local function Deactivate()
	for region in pairs(fadedArt) do region:SetAlpha(1) end
	local frame = Frame()
	if frame and skinned then
		if frame.NineSlice then frame.NineSlice:SetAlpha(1) end
		Skin.HideTipShell(frame)
	end
	BUI.Print('Loot history skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then BUI.Events:Register('ADDON_LOADED', 'Skin.LootHistory', TryInstall) end
		local frame = Frame()
		if frame and frame:IsShown() then Apply() end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Loot History',
	description = 'The Loot Rolls window drawn like the BluUI tooltip: flat shell, accent timer, clean rows, and every roll listed when you hover an item.',
	icon = 'Interface/Icons/INV_Misc_Bag_10',
})
