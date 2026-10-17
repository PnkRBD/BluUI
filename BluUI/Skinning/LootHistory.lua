local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning
local Tools = BUI.Tools
local SELECTED_COLOR = Skin.SELECTED_COLOR

local FONT_DEPTH = 2
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

local context = Skin.Define('loothistory', {
	name = 'Loot History',
	description = 'The Loot Rolls window drawn like the BluUI tooltip: flat shell, white timer, clean rows, and every roll listed when you hover an item.',
	icon = 'Interface/Icons/INV_Misc_Bag_10',
})
local Fade, FadeRegions, Shell, Close, Dropdown = context.Fade, context.FadeRegions, context.Shell, context.Close, context.Dropdown
local ScrollBar, Title, Own = context.ScrollBar, context.Title, context.Own

local function AddRollLine(roll)
	local name = RAID_CLASS_COLORS[roll.playerClass]:WrapTextInColorCode(roll.playerName)
	if roll.state == ROLL_STATE.NeedOffSpec then name = LOOT_HISTORY_OFF_SPEC_FMT:format(name) end
	if roll.isWinner then name = name .. WINNER_MARK end
	GameTooltip:AddDoubleLine(ROLL_ICONS[roll.state] .. ' ' .. name, roll.roll and tostring(roll.roll) or '', 1, 1, 1, 1, 1, 1)
end

local function ShowAllRolls(row)
	local drop = row.dropInfo
	if not drop then return end
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
	if not context.Enabled() or row:IsForbidden() or row._buiLootRow then return end
	row._buiLootRow = true
	local item = row.Item
	if item then
		context.Hook(row, 'SetTooltip', ShowAllRolls)
		FadeRegions(row.BackgroundArtFrame)
		Fade(item.IconBorder)
		Fade(item:GetNormalTexture())
		Skin.CropIcon(item.icon)
	end
	Skin.TipFaceTree(row, FONT_DEPTH)
end

local function RefreshTimer(frame)
	local fill = frame.Timer.Fill
	fill:SetTexture(BUI.GetGlobalTexture())
	fill:SetVertexColor(SELECTED_COLOR[1], SELECTED_COLOR[2], SELECTED_COLOR[3], 1)
end

local function SkinFrame(frame)
	Fade(frame.NineSlice)
	FadeRegions(frame.Bg)
	FadeRegions(frame)
	Shell(frame)
	Close(frame.ClosePanelButton)
	Title(frame.TitleContainer.TitleText)
	Dropdown(frame.EncounterDropdown)
	local timer = frame.Timer
	Fade(timer.Background)
	Fade(timer.Border)
	local track = Own(timer:CreateTexture(nil, 'BACKGROUND'))
	track:SetAllPoints(timer)
	Tools.SetColorTex(track, 0, 0, 0, 0.5)
	ScrollBar(frame.ScrollBar)
	Skin.SweepScrollBox(frame.ScrollBox, SkinRow)
	RefreshTimer(frame)
end

context.Window('GroupLootHistoryFrame', { skin = SkinFrame, show = RefreshTimer })
