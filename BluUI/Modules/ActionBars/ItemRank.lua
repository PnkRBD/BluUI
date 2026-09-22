local _, BUI = ...

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel

local function ItemQualityInfo(button)
	if button._state_type ~= 'action' or not button._state_action then return nil end
	local actionType, itemID = GetActionInfo(button._state_action)
	if actionType ~= 'item' then return nil end
	return BUI.Lookup.CraftedQualityInfo(itemID)
end

function ActionBars.StyleItemRank(button)
	local badge = button._buiItemRank
	if not badge then return end
	local settings = ActionBars.GetSettings()
	local height = Pixel.Scale(settings.itemRankSize)
	local atlasInfo = C_Texture.GetAtlasInfo(badge:GetAtlas())
	local width = atlasInfo and height * atlasInfo.width / atlasInfo.height or height
	badge:SetSize(width, height)
	badge:ClearAllPoints()
	badge:SetPoint(settings.itemRankAnchor, button, settings.itemRankAnchor, settings.itemRankOffsetX, settings.itemRankOffsetY)
end

function ActionBars.SyncItemRank(button)
	local info = ActionBars.GetSettings().showItemRank and ItemQualityInfo(button) or nil
	local atlas = info and info.iconInventory or nil
	if button._buiItemRankAtlas == atlas then return end
	button._buiItemRankAtlas = atlas
	local badge = button._buiItemRank
	if not atlas then
		if badge then badge:Hide() end
		return
	end
	if not badge then
		badge = (button.TextOverlayContainer or button):CreateTexture(nil, 'OVERLAY', nil, 6)
		button._buiItemRank = badge
	end
	badge:SetAtlas(atlas)
	ActionBars.StyleItemRank(button)
	badge:Show()
end

function ActionBars.RefreshItemRank()
	ActionBars.ForEachButton(function(button)
		button._buiItemRankAtlas = nil
		ActionBars.SyncItemRank(button)
	end)
end
