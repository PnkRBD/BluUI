local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout, Modals, Widget = BUILib.Layout, BUILib.Modals, BUILib.Widget
local MinimapModule = BUI.Minimap
local Datatext = BUI.Datatext
local ButtonBar = BUI.MinimapButtonBar
local Pixel = BUI.Pixel

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local format = string.format
local FONT = BUI.C.FONT_PATH

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 240
local PREVIEW_MAP = 200
local PREVIEW_TICK = 2
local ICON_SIZE = 18
local MENU_WIDTH = 160
local SWITCH_WIDTH = 40
local ARROW = 22
local ARROW_GAP = 4
local ORDER_ROOM = SWITCH_WIDTH + 12 + ARROW * 2 + ARROW_GAP
local LABEL_TOGGLE = 22

local RAIL_GROUPS = {
	{ title = 'Map', items = {
		{ id = 'map', label = 'Map', icon = 'minimap' },
		{ id = 'indicators', label = 'Indicators', icon = 'eye' },
		{ id = 'text', label = 'Clock and zone', icon = 'clock' },
	} },
	{ title = 'Around the map', items = {
		{ id = 'datatext', label = 'Datatext bar', icon = 'text' },
		{ id = 'buttons', label = 'Drawer and buttons', icon = 'modules5' },
	} },
}
local PANE_IDS = { 'map', 'indicators', 'text', 'datatext', 'buttons' }
local PANE_INDEX = {}
for index, id in ipairs(PANE_IDS) do PANE_INDEX[id] = index end

local SIDES = {
	{ value = 'LEFT', text = 'Left' },
	{ value = 'RIGHT', text = 'Right' },
	{ value = 'TOP', text = 'Top' },
	{ value = 'BOTTOM', text = 'Bottom' },
}
local ALIGNS = {
	{ value = 'START', text = 'Start' },
	{ value = 'CENTER', text = 'Center' },
	{ value = 'END', text = 'End' },
}
local ANCHORS = {
	{ value = 'BOTTOM', text = 'Bottom' },
	{ value = 'TOP', text = 'Top' },
	{ value = 'LEFT', text = 'Left' },
	{ value = 'RIGHT', text = 'Right' },
	{ value = 'INSIDE_BOTTOM', text = 'Inside bottom' },
	{ value = 'INSIDE_TOP', text = 'Inside top' },
}

local INDICATORS = {
	{ key = 'queue', name = 'Queue eye', sub = 'Dungeon, raid and PvP queue status', icon = 'Interface\\LFGFrame\\LFG-Eye', color = { 0.35, 0.72, 1.00 } },
	{ key = 'difficulty', name = 'Difficulty', sub = 'The instance difficulty', hide = 'minimapHideDifficulty', icon = 'Interface\\Icons\\INV_Misc_Bone_Skull_02', color = { 1.00, 0.55, 0.15 } },
	{ key = 'mail', name = 'Mail', sub = 'New mail waiting', hide = 'minimapHideMail', icon = 'Interface\\Icons\\INV_Letter_15', color = { 1.00, 0.88, 0.25 } },
	{ key = 'crafting', name = 'Crafting orders', sub = 'Personal crafting orders', hide = 'minimapHideCrafting', icon = 'Interface\\Icons\\Trade_BlackSmithing', color = { 0.45, 0.82, 0.30 } },
	{ key = 'missions', name = 'Folio', sub = 'The expansion landing page', hide = 'minimapHideGarrison', icon = 'Interface\\Icons\\INV_Misc_Book_09', color = { 0.65, 0.40, 0.95 } },
}

local MINIMAP_YARDS = { 466.67, 400, 333.33, 266.67, 200, 133.33 }
local ADT_TILE = 533.3333333333333

local preview
local fonts

local function Window()
	return BUI.PageEngine.window
end

local function Interface()
	return BUI.GetDB().interface
end

local function Bar()
	return Datatext.GetMinimapDB()
end

local function Buttons()
	return Interface().buttonBar
end

local function Repaint()
	Window():Repaint()
end

local function RefreshPreview()
	if preview then preview:UpdatePreview() end
end

local function Switch(board, label, get, set, tip)
	board:AddSwitch(label, get, function(value)
		set(value)
		RefreshPreview()
	end, tip)
end

local function Swap(list, value, delta)
	for index, candidate in ipairs(list) do
		if candidate == value then
			local other = list[index + delta]
			if not other then return false end
			list[index], list[index + delta] = other, value
			return true
		end
	end
	return false
end

local function OrderArrows(ui, row, onMove)
	local down = ui.ArrowButton(row, false, function() onMove(1) end)
	down:SetPoint('RIGHT', -(ui.ROW_INSET + SWITCH_WIDTH + 12), 0)
	ui.ArrowButton(row, true, function() onMove(-1) end):SetPoint('RIGHT', down, 'LEFT', -ARROW_GAP, 0)
end

local function ConfirmModule(value)
	Modals.Confirm({
		parent = Window().frame,
		title = 'Reload required',
		message = value and 'Turning the minimap module on needs a UI reload.' or 'Turning the minimap module off needs a UI reload to put everything back.',
		confirmText = 'Reload now', cancelText = 'Cancel', laterText = 'Later',
		onConfirm = function()
			Interface().minimapEnabled = value
			ReloadUI()
		end,
		onLater = function()
			Interface().minimapEnabled = value
			Repaint()
		end,
		onCancel = Repaint,
	})
end

local function BuildPreview(band)
	local card = CreateFrame('Frame', nil, band)
	card:SetAllPoints()
	local stage = CreateFrame('Frame', nil, card)
	stage:SetSize(PREVIEW_MAP + 8, PREVIEW_MAP + 8)
	stage:SetPoint('CENTER')
	stage:SetFrameLevel(card:GetFrameLevel() + 5)

	local interfaceDB, scale, uiScale

	local function PreviewPixels(value)
		return floor(value * uiScale + 0.5)
	end

	local function YardsAtZoom()
		return MINIMAP_YARDS[Minimap:GetZoom() + 1]
	end

	local borderFrame = CreateFrame('Frame', nil, stage)
	borderFrame:SetPoint('CENTER')
	local borderBackground = borderFrame:CreateTexture(nil, 'BACKGROUND', nil, -1)
	borderBackground:SetAllPoints()
	borderBackground:SetColorTexture(0.12, 0.12, 0.13, 1)

	local mapFrame = CreateFrame('Frame', nil, stage)
	mapFrame:SetSize(PREVIEW_MAP, PREVIEW_MAP)
	mapFrame:SetPoint('CENTER')
	mapFrame:SetFrameLevel(stage:GetFrameLevel() + 2)
	mapFrame:SetClipsChildren(true)
	local mapBackground = mapFrame:CreateTexture(nil, 'BACKGROUND')
	mapBackground:SetAllPoints()

	local content = CreateFrame('Frame', nil, mapFrame)
	content:SetAllPoints()
	local overlay = CreateFrame('Frame', nil, mapFrame)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(content:GetFrameLevel() + 1)

	local vignette = overlay:CreateTexture(nil, 'ARTWORK', nil, 2)
	vignette:SetAllPoints(mapFrame)
	vignette:SetTexture('Interface\\FullScreenTextures\\LowHealth')
	vignette:SetBlendMode('BLEND')
	vignette:SetVertexColor(0, 0, 0, 0.45)

	local hint = card:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(hint, 9, FONT, '')
	hint:SetPoint('BOTTOM', card, 'BOTTOM', 0, 6)
	hint:SetTextColor(0.42, 0.42, 0.47, 0.9)
	hint:SetText('Drag icons and text to reposition  ·  Scroll icons to resize')

	local tilePool = {}
	local tileCache, tileCacheDir

	local function DecodeTiles(dir)
		if tileCacheDir == dir then return tileCache end
		tileCacheDir, tileCache = dir, nil
		local stream = dir and BUI.MinimapTiles[dir]
		if not stream then return nil end
		local tiles = {}
		local tileIndex, fileDataID = 0, 0
		for indexToken, fileToken in stream:gmatch('([^;.]+)%.([^;]+)') do
			tileIndex = tileIndex + (indexToken:sub(1, 1) == '!' and -tonumber(indexToken:sub(2), 36) or tonumber(indexToken, 36))
			fileDataID = fileDataID + (fileToken:sub(1, 1) == '!' and -tonumber(fileToken:sub(2), 36) or tonumber(fileToken, 36))
			tiles[tileIndex] = fileDataID
		end
		tileCache = tiles
		return tiles
	end

	local function Tile(index)
		local tile = tilePool[index]
		if not tile then
			tile = content:CreateTexture(nil, 'BACKGROUND')
			tilePool[index] = tile
		end
		return tile
	end

	local function ApplyMapArt()
		local mapID = C_Map.GetBestMapForUnit('player')
		local layer = mapID and (C_Map.GetMapArtLayers(mapID) or {})[1]
		local textures = layer and C_Map.GetMapArtLayerTextures(mapID, 1)
		if not (textures and #textures > 0 and layer.tileWidth and layer.tileWidth > 0) then return end

		local position = C_Map.GetPlayerMapPosition(mapID, 'player')
		local playerX = position and position.x or 0.5
		local playerY = position and position.y or 0.5

		local yards = YardsAtZoom()
		local worldWidth, worldHeight = C_Map.GetMapWorldSize(mapID)
		local fracX = (worldWidth and worldWidth > 0) and min(1, yards / worldWidth) or 0.25
		local fracY = (worldHeight and worldHeight > 0) and min(1, yards / worldHeight) or 0.25

		local windowWidth = fracX * layer.layerWidth
		local windowHeight = fracY * layer.layerHeight
		local centerX = max(windowWidth / 2, min(layer.layerWidth - windowWidth / 2, playerX * layer.layerWidth))
		local centerY = max(windowHeight / 2, min(layer.layerHeight - windowHeight / 2, playerY * layer.layerHeight))
		local left, top = centerX - windowWidth / 2, centerY - windowHeight / 2

		local scaleX = PREVIEW_MAP / windowWidth
		local scaleY = PREVIEW_MAP / windowHeight
		local cols = math.ceil(layer.layerWidth / layer.tileWidth)
		local tileCount = 0
		for textureIndex = 1, #textures do
			local tileX = ((textureIndex - 1) % cols) * layer.tileWidth
			local tileY = floor((textureIndex - 1) / cols) * layer.tileHeight
			if tileX < left + windowWidth and tileX + layer.tileWidth > left
				and tileY < top + windowHeight and tileY + layer.tileHeight > top then
				tileCount = tileCount + 1
				local tile = Tile(tileCount)
				tile:SetTexture(textures[textureIndex])
				tile:SetVertexColor(0.75, 0.75, 0.75, 1)
				tile:SetSize(layer.tileWidth * scaleX, layer.tileHeight * scaleY)
				tile:ClearAllPoints()
				tile:SetPoint('TOPLEFT', mapFrame, 'TOPLEFT', (tileX - left) * scaleX, -(tileY - top) * scaleY)
				tile:Show()
			end
		end
	end

	local function ApplyMapSnapshot()
		for tileIndex = 1, #tilePool do tilePool[tileIndex]:Hide() end
		mapBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

		if _G.HybridMinimap and _G.HybridMinimap:IsShown() then
			ApplyMapArt()
			return
		end

		local posX, posY, _, instanceID = UnitPosition('player')
		if not posX then return end
		local tiles = DecodeTiles(BUI.MinimapTileDirs[instanceID])
		if not tiles then return end

		local yards = YardsAtZoom()
		local half = yards / 2
		local tilePixelSize = ADT_TILE * (PREVIEW_MAP / yards)

		local columnFraction = 32 - (posY + half) / ADT_TILE
		local rowFraction = 32 - (posX + half) / ADT_TILE
		local span = yards / ADT_TILE

		local tileCount = 0
		for col = floor(columnFraction), floor(columnFraction + span) do
			for row = floor(rowFraction), floor(rowFraction + span) do
				local fileDataID = col >= 0 and col <= 63 and row >= 0 and row <= 63 and tiles[col * 64 + row]
				if fileDataID then
					tileCount = tileCount + 1
					local tile = Tile(tileCount)
					tile:SetTexture(fileDataID)
					tile:SetVertexColor(1, 1, 1, 1)
					tile:SetSize(tilePixelSize, tilePixelSize)
					tile:ClearAllPoints()
					tile:SetPoint('TOPLEFT', mapFrame, 'TOPLEFT', (col - columnFraction) * tilePixelSize, -(row - rowFraction) * tilePixelSize)
					tile:Show()
				end
			end
		end
	end

	local function ApplyBorder()
		local borderWidth = max(0, interfaceDB.minimapBorderWidth) * scale
		borderFrame:SetSize(PREVIEW_MAP + borderWidth * 2, PREVIEW_MAP + borderWidth * 2)
	end

	local icons = {}

	local function PlaceIcon(proxy, key)
		local point, x, y = MinimapModule.GetIndicatorPlacement(key)
		local iconScale = MinimapModule.GetIconScale(key)
		proxy:ClearAllPoints()
		proxy:SetPoint(point, mapFrame, point, x * iconScale * scale, y * iconScale * scale)
		local size = floor(ICON_SIZE * (iconScale / 0.8))
		proxy:SetSize(size, size)
	end

	local function RefreshIcons()
		local anchor = MinimapModule.DOCK_ANCHORS[MinimapModule.GetDock()]
		if anchor then
			local size = max(8, floor(MinimapModule.GetIconSize() * scale))
			local step = size + 3
			local iconIndex = 0
			for _, def in ipairs(INDICATORS) do
				local proxy = icons[def.key]
				if def.key ~= 'difficulty' then
					proxy:EnableMouse(false)
					proxy:ClearAllPoints()
					proxy:SetSize(size, size)
					proxy:SetPoint(anchor.point, mapFrame, anchor.point, anchor.x * scale + anchor.dirX * iconIndex * step, anchor.y * scale)
					iconIndex = iconIndex + 1
				else
					proxy:EnableMouse(true)
					PlaceIcon(proxy, def.key)
				end
			end
		else
			for _, def in ipairs(INDICATORS) do
				icons[def.key]:EnableMouse(true)
				PlaceIcon(icons[def.key], def.key)
			end
		end
	end

	local function OnDragStop(proxy, key)
		local centerX, centerY = proxy:GetCenter()
		local mapCenterX, mapCenterY = mapFrame:GetCenter()
		if not centerX or not mapCenterX then PlaceIcon(proxy, key) return end

		local relX, relY = centerX - mapCenterX, centerY - mapCenterY
		local half = PREVIEW_MAP / 2
		relX = max(-half, min(half, relX))
		relY = max(-half, min(half, relY))

		proxy:ClearAllPoints()
		proxy:SetPoint('CENTER', mapFrame, 'CENTER', relX, relY)

		local iconScale = MinimapModule.GetIconScale(key)
		MinimapModule.SaveIndicatorPosition(key, 'CENTER', relX / (scale * iconScale), relY / (scale * iconScale))
		MinimapModule.RepositionIndicators()
		Repaint()
	end

	for _, def in ipairs(INDICATORS) do
		local proxy = CreateFrame('Button', nil, mapFrame, 'BackdropTemplate')
		proxy:SetSize(ICON_SIZE, ICON_SIZE)
		proxy:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8X8', edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
		proxy:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
		proxy:SetBackdropBorderColor(def.color[1], def.color[2], def.color[3], 0.9)
		proxy:SetFrameLevel(mapFrame:GetFrameLevel() + 10)

		local iconTexture = proxy:CreateTexture(nil, 'ARTWORK')
		iconTexture:SetPoint('TOPLEFT', 2, -2)
		iconTexture:SetPoint('BOTTOMRIGHT', -2, 2)
		iconTexture:SetTexture(def.icon)
		iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		if def.key == 'missions' then
			local landingButton = _G.ExpansionLandingPageMinimapButton
			local source = landingButton and (landingButton.LandingPageIcon or landingButton.Icon or (landingButton.GetNormalTexture and landingButton:GetNormalTexture()))
			local atlas = source and source.GetAtlas and source:GetAtlas()
			if atlas then
				iconTexture:SetAtlas(atlas)
				iconTexture:SetTexCoord(0, 1, 0, 1)
			end
		elseif def.key == 'queue' then
			local function CopyEye(eyeFrame)
				if not eyeFrame then return false end
				for _, region in ipairs({ eyeFrame:GetRegions() }) do
					if region:IsObjectType('Texture') then
						local atlas = region:GetAtlas()
						if atlas then
							iconTexture:SetAtlas(atlas)
							iconTexture:SetTexCoord(0, 1, 0, 1)
							return true
						end
						local texture = region:GetTexture()
						if texture then
							iconTexture:SetTexture(texture)
							iconTexture:SetTexCoord(region:GetTexCoord())
							return true
						end
					end
				end
				return false
			end
			local queueButton = _G.QueueStatusButton
			if not (CopyEye(queueButton and queueButton.Eye) or CopyEye(queueButton)) then
				iconTexture:SetTexCoord(0, 1, 0, 1)
			end
		end

		local highlight = proxy:CreateTexture(nil, 'OVERLAY')
		highlight:SetTexture('Interface\\Buttons\\WHITE8x8')
		highlight:SetPoint('TOPLEFT', 1, -1)
		highlight:SetPoint('TOPRIGHT', -1, -1)
		highlight:SetHeight(1)
		highlight:SetVertexColor(1, 1, 1, 0.2)

		proxy:EnableMouse(true)
		proxy:RegisterForDrag('LeftButton')
		proxy:SetScript('OnDragStart', function(self)
			self:SetScript('OnUpdate', function(draggedIcon)
				local cursorX, cursorY = GetCursorPosition()
				local mapScale = mapFrame:GetEffectiveScale()
				cursorX, cursorY = cursorX / mapScale, cursorY / mapScale
				local left, bottom = mapFrame:GetLeft(), mapFrame:GetBottom()
				local right, top = mapFrame:GetRight(), mapFrame:GetTop()
				if not left then return end
				cursorX = max(left, min(right, cursorX))
				cursorY = max(bottom, min(top, cursorY))
				local snap = 8 * scale
				local best, bestDistance
				for _, other in pairs(icons) do
					if other ~= draggedIcon and other:IsShown() and other:IsMouseEnabled() then
						local otherX, otherY = other:GetCenter()
						if otherX then
							local distance = abs(cursorX - otherX) + abs(cursorY - otherY)
							if not bestDistance or distance < bestDistance then best, bestDistance = other, distance end
						end
					end
				end
				if best then
					local bestX, bestY = best:GetCenter()
					local gap = draggedIcon:GetWidth() / 2 + best:GetWidth() / 2
					if abs(abs(cursorX - bestX) - gap) <= snap and abs(cursorY - bestY) <= gap then
						cursorX, cursorY = bestX + (cursorX >= bestX and gap or -gap), bestY
					elseif abs(abs(cursorY - bestY) - gap) <= snap and abs(cursorX - bestX) <= gap then
						cursorX, cursorY = bestX, bestY + (cursorY >= bestY and gap or -gap)
					end
				end
				draggedIcon:ClearAllPoints()
				draggedIcon:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cursorX, cursorY)
			end)
		end)
		proxy:SetScript('OnDragStop', function(self)
			self:SetScript('OnUpdate', nil)
			OnDragStop(self, def.key)
		end)

		proxy:EnableMouseWheel(true)
		proxy:SetScript('OnMouseWheel', function(self, delta)
			local oldScale = MinimapModule.GetIconScale(def.key)
			local newScale = max(0.4, min(1.6, oldScale + delta * 0.1))
			MinimapModule.SetIconScale(def.key, newScale)
			local point, offsetX, offsetY = MinimapModule.GetIndicatorPlacement(def.key)
			MinimapModule.SaveIndicatorPosition(def.key, point, offsetX * oldScale / newScale, offsetY * oldScale / newScale)
			PlaceIcon(self, def.key)
			MinimapModule.RepositionIndicators()
			Widget.ShowTip(self, format('%s  |  Scale: %.0f%%', def.name, newScale * 100))
			Repaint()
		end)
		proxy:SetScript('OnEnter', function(self)
			self:SetBackdropBorderColor(1, 1, 1, 1)
			Widget.ShowTip(self, format('%s  |  Scale: %.0f%%  |  Drag to move', def.name, MinimapModule.GetIconScale(def.key) * 100))
		end)
		proxy:SetScript('OnLeave', function(self)
			self:SetBackdropBorderColor(0, 0, 0, 1)
			Widget.HideTip()
		end)

		icons[def.key] = proxy
	end

	local clockLabel = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(clockLabel, 9, FONT, '')
	local zoneLabel = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(zoneLabel, 8, FONT, '')

	local textDraggers = {}
	local PlaceText

	local function MakeTextDragger(name, fontString, keyX, keyY, onStop)
		local button = CreateFrame('Button', nil, overlay)
		button:SetFrameLevel(overlay:GetFrameLevel() + 5)
		button:SetPoint('CENTER', fontString, 'CENTER')
		button:RegisterForDrag('LeftButton')

		local glow = button:CreateTexture(nil, 'BACKGROUND')
		glow:SetTexture('Interface\\Buttons\\WHITE8x8')
		glow:SetAllPoints()
		glow:SetVertexColor(1, 1, 1, 0)

		button:SetScript('OnDragStart', function(self)
			local cursorX, cursorY = GetCursorPosition()
			local effectiveScale = self:GetEffectiveScale()
			self._startX, self._startY = cursorX / effectiveScale, cursorY / effectiveScale
			self._baseX = interfaceDB[keyX]
			self._baseY = interfaceDB[keyY]
			self:SetScript('OnUpdate', function(dragButton)
				local newX, newY = GetCursorPosition()
				newX, newY = newX / effectiveScale, newY / effectiveScale
				interfaceDB[keyX] = max(-300, min(300, floor(dragButton._baseX + (newX - dragButton._startX) / scale + 0.5)))
				interfaceDB[keyY] = max(-300, min(300, floor(dragButton._baseY + (newY - dragButton._startY) / scale + 0.5)))
				PlaceText()
			end)
		end)
		button:SetScript('OnDragStop', function(self)
			self:SetScript('OnUpdate', nil)
			onStop()
			Repaint()
		end)
		button:SetScript('OnEnter', function(self)
			glow:SetVertexColor(1, 1, 1, 0.12)
			Widget.ShowTip(self, name .. '  |  Drag to move')
		end)
		button:SetScript('OnLeave', function()
			glow:SetVertexColor(1, 1, 1, 0)
			Widget.HideTip()
		end)
		textDraggers[#textDraggers + 1] = { button = button, fontString = fontString }
		return button
	end

	local clockDrag = MakeTextDragger('Clock', clockLabel, 'minimapClockX', 'minimapClockY', MinimapModule.RefreshClock)
	local zoneDrag = MakeTextDragger('Zone name', zoneLabel, 'minimapZoneX', 'minimapZoneY', MinimapModule.RefreshZoneText)

	local function SyncTextDraggers()
		for _, entry in ipairs(textDraggers) do
			entry.button:SetSize(max(36, entry.fontString:GetStringWidth() + 10), 14)
		end
		clockDrag:SetShown(clockLabel:IsShown())
		zoneDrag:SetShown(zoneLabel:IsShown())
	end

	PlaceText = function()
		clockLabel:SetText(date('%H:%M'))
		zoneLabel:SetText(GetMinimapZoneText() or 'Zone Name')
		Pixel.ApplyFont(clockLabel, 9, BUI.GetFontByName(interfaceDB.minimapClockFont), '')
		Pixel.ApplyFont(zoneLabel, 8, BUI.GetFontByName(interfaceDB.minimapZoneFont), '')
		clockLabel:ClearAllPoints()
		zoneLabel:ClearAllPoints()
		clockLabel:SetShown(interfaceDB.minimapClock ~= false)
		zoneLabel:SetShown(interfaceDB.minimapZone ~= false)
		clockLabel:SetPoint('TOPRIGHT', mapFrame, 'TOPRIGHT', -4 + interfaceDB.minimapClockX * scale, -4 + interfaceDB.minimapClockY * scale)
		clockLabel:SetJustifyH('RIGHT')
		zoneLabel:SetPoint('TOPLEFT', mapFrame, 'TOPLEFT', 4 + interfaceDB.minimapZoneX * scale, -4 + interfaceDB.minimapZoneY * scale)
		zoneLabel:SetJustifyH('LEFT')
		local clockColor = interfaceDB.minimapClockColor
		clockLabel:SetTextColor(clockColor.r, clockColor.g, clockColor.b, 0.9)
		if interfaceDB.minimapZoneColorCustom then
			local zoneColor = interfaceDB.minimapZoneColor
			zoneLabel:SetTextColor(zoneColor.r, zoneColor.g, zoneColor.b, 0.9)
		else
			zoneLabel:SetTextColor(1, 0.82, 0, 0.6)
		end
		SyncTextDraggers()
	end

	local drawerTab = CreateFrame('Frame', nil, stage, 'BackdropTemplate')
	drawerTab:SetFrameLevel(mapFrame:GetFrameLevel() + 12)
	Pixel.SetTemplate(drawerTab, 0.85, 0.85, 0.85, 1, 0.1, 0.1, 0.1, 1)
	drawerTab:Hide()

	local function RefreshDrawer()
		if not interfaceDB.drawerEnabled then
			drawerTab:Hide()
			return
		end
		local width, height, point, x, y = BUI.Drawer.TabLayout(interfaceDB.drawerSide, interfaceDB.drawerX, interfaceDB.drawerY, PreviewPixels)
		drawerTab:SetSize(max(2, width), max(2, height))
		drawerTab:ClearAllPoints()
		drawerTab:SetPoint('CENTER', mapFrame, point, x, y)
		drawerTab:Show()
	end

	local barHolder = CreateFrame('Frame', nil, stage)
	barHolder:SetFrameLevel(mapFrame:GetFrameLevel() + 12)
	barHolder:Hide()
	local barProxies = {}

	local function BarProxy(index)
		local proxy = barProxies[index]
		if proxy then return proxy end
		proxy = CreateFrame('Frame', nil, barHolder, 'BackdropTemplate')
		proxy:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8X8', edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
		proxy:SetBackdropBorderColor(0, 0, 0, 1)
		proxy.icon = proxy:CreateTexture(nil, 'ARTWORK')
		proxy.icon:SetPoint('TOPLEFT', 1, -1)
		proxy.icon:SetPoint('BOTTOMRIGHT', -1, 1)
		proxy.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		barProxies[index] = proxy
		return proxy
	end

	local function RefreshButtonBar()
		local config = interfaceDB.buttonBar
		if not config.enabled then
			barHolder:Hide()
			return
		end
		local entries = {}
		for _, entry in ipairs(ButtonBar.PickerEntries()) do
			if entry.included then entries[#entries + 1] = entry end
		end
		local count = #entries
		if count == 0 then
			barHolder:Hide()
			return
		end

		local layout = ButtonBar.Arrange(config, count, PreviewPixels)
		barHolder:SetSize(layout.width, layout.height)
		barHolder:ClearAllPoints()
		barHolder:SetPoint(layout.point, mapFrame, layout.relativePoint, layout.x, layout.y)

		local background = config.background
		for index = 1, count do
			local proxy = BarProxy(index)
			local slot = layout.slots[index]
			proxy:SetSize(layout.size, layout.size)
			proxy:SetBackdropColor(background[1], background[2], background[3], background[4])
			proxy:ClearAllPoints()
			proxy:SetPoint(layout.corner, barHolder, layout.corner, slot[1], slot[2])
			local icon = entries[index].icon
			if icon then
				proxy.icon:SetTexture(icon)
				proxy.icon:Show()
			else
				proxy.icon:Hide()
			end
			proxy:Show()
		end
		for index = count + 1, #barProxies do barProxies[index]:Hide() end
		barHolder:Show()
	end

	function card:UpdatePreview()
		interfaceDB = Interface()
		scale = PREVIEW_MAP / Minimap:GetWidth()
		uiScale = scale * UIParent:GetEffectiveScale() / Minimap:GetEffectiveScale()
		ApplyMapSnapshot()
		ApplyBorder()
		RefreshIcons()
		PlaceText()
		RefreshDrawer()
		RefreshButtonBar()
	end

	local sinceTick = 0
	card:SetScript('OnUpdate', function(self, elapsed)
		sinceTick = sinceTick + elapsed
		if sinceTick >= PREVIEW_TICK then
			sinceTick = 0
			self:UpdatePreview()
		end
	end)
	card:HookScript('OnShow', function(self) self:UpdatePreview() end)
	card:UpdatePreview()
	return card
end

local function MapBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Map',
		description = 'The square minimap: where it sits, how big it is and the frame around it. The eye in the header unlocks the real map to drag it, right-click it there to lock it again.',
	})
	Switch(board, 'Rotate with you', function() return Interface().rotateMinimap == true end, function(value)
		Interface().rotateMinimap = value
		MinimapModule.ToggleRotation(value)
	end)
	Switch(board, 'Hide the BluUI button', BUI.IsMinimapButtonHidden, BUI.SetMinimapButtonHidden)
	board:AddTools('Size and frame', 'How big the map is and the border around it', {
		{ tooltip = 'Scale and border', title = 'Map', options = {
			{ label = 'Scale', min = 50, max = 200, step = 1, get = function() return Interface().minimapScale end, set = MinimapModule.SetScale },
			{ label = 'Border width', min = 0, max = 10, step = 1, get = function() return Interface().minimapBorderWidth end, set = MinimapModule.SetBorderWidth },
		} },
	}, RefreshPreview)
	board:AddTools('Position', 'Distance from the right and top edges of the screen', {
		{ icon = 'mover', tooltip = 'Position', title = 'Position', options = {
			{ label = 'From the right edge', min = 0, max = floor(GetScreenWidth()), step = 1, get = function() return -(MinimapModule.GetPosition()) end, set = function(value) MinimapModule.SetPositionX(-value) end },
			{ label = 'From the top edge', min = 0, max = floor(GetScreenHeight()), step = 1, get = function() local _, y = MinimapModule.GetPosition() return -y end, set = function(value) MinimapModule.SetPositionY(-value) end },
		} },
	}, RefreshPreview)
	return board
end

local function IndicatorTools(def)
	local options = {
		{ label = 'Size', min = 40, max = 160, step = 5, get = function() return floor(MinimapModule.GetIconScale(def.key) * 100 + 0.5) end, set = function(value) MinimapModule.SetIconScale(def.key, value / 100) end },
	}
	if def.key == 'difficulty' then
		options[#options + 1] = { label = 'Show as letters', get = function() return Interface().minimapTextDifficulty == true end, set = function(value)
			Interface().minimapTextDifficulty = value
			MinimapModule.ToggleTextDifficulty(value)
			MinimapModule.ApplyVisibility()
		end }
	end
	local tools = { { icon = 'resize', tooltip = def.key == 'difficulty' and 'Size and style' or 'Size', title = def.name, options = options } }
	if def.hide then
		tools[2] = { get = function() return not Interface()[def.hide] end, set = function(value)
			Interface()[def.hide] = not value
			MinimapModule.ApplyVisibility()
			if def.key == 'difficulty' then MinimapModule.ToggleTextDifficulty(value and Interface().minimapTextDifficulty == true) end
		end }
	end
	return tools
end

local function IndicatorsBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Indicators',
		description = 'The small buttons that live on the map. Drag them around the preview above, or unlock the real map.',
	})
	for _, def in ipairs(INDICATORS) do
		board:AddTools(def.name, def.sub, IndicatorTools(def), RefreshPreview)
	end
	return board
end

local function TextBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'The clock and the zone name on the map. Drag them in the preview above, or nudge them from their cogs.',
	})
	board:AddTools('Clock', 'The time in the corner of the map', {
		{ kind = 'swatch', tooltip = 'Text color',
			get = function() local color = Interface().minimapClockColor return color.r, color.g, color.b, 1 end,
			set = function(red, green, blue) Interface().minimapClockColor = { r = red, g = green, b = blue } MinimapModule.RefreshClock() end },
		{ entries = fonts, width = MENU_WIDTH,
			get = function() return Interface().minimapClockFont end,
			set = function(value) Interface().minimapClockFont = value MinimapModule.RefreshClock() end },
		{ icon = 'text', tooltip = 'Size', title = 'Clock', options = {
			{ label = 'Size', min = 8, max = 24, step = 1, get = function() return Interface().minimapClockSize end, set = function(value) Interface().minimapClockSize = value MinimapModule.RefreshClock() end },
		} },
		{ tooltip = 'Format and offsets', title = 'Clock', options = {
			{ label = '24-hour', get = function() return Interface().minimapClock24h == true end, set = function(value) Interface().minimapClock24h = value MinimapModule.SetClockFormat(value) end },
			{ label = 'Server time', get = function() return Interface().minimapClockServer == true end, set = function(value) Interface().minimapClockServer = value MinimapModule.SetClockSource(value) end },
			{ label = 'Horizontal offset', min = -300, max = 300, step = 1, get = function() return Interface().minimapClockX end, set = function(value) Interface().minimapClockX = value MinimapModule.RefreshClock() end },
			{ label = 'Vertical offset', min = -300, max = 300, step = 1, get = function() return Interface().minimapClockY end, set = function(value) Interface().minimapClockY = value MinimapModule.RefreshClock() end },
		} },
		{ get = function() return Interface().minimapClock == true end, set = function(value) Interface().minimapClock = value MinimapModule.ToggleClock(value) end },
	}, RefreshPreview)
	board:AddTools('Zone name', 'The zone you are in, at the top of the map', {
		{ kind = 'swatch', tooltip = 'Custom color',
			get = function() local color = Interface().minimapZoneColor return color.r, color.g, color.b, 1 end,
			set = function(red, green, blue)
				Interface().minimapZoneColorCustom = true
				Interface().minimapZoneColor = { r = red, g = green, b = blue }
				MinimapModule.RefreshZoneText()
			end },
		{ entries = fonts, width = MENU_WIDTH,
			get = function() return Interface().minimapZoneFont end,
			set = function(value) Interface().minimapZoneFont = value MinimapModule.RefreshZoneText() end },
		{ icon = 'text', tooltip = 'Size', title = 'Zone name', options = {
			{ label = 'Size', min = 8, max = 24, step = 1, get = function() return Interface().minimapZoneSize end, set = function(value) Interface().minimapZoneSize = value MinimapModule.RefreshZoneText() end },
		} },
		{ tooltip = 'Color and offsets', title = 'Zone name', options = {
			{ label = 'Custom color, off colors by zone type', get = function() return Interface().minimapZoneColorCustom == true end, set = function(value) Interface().minimapZoneColorCustom = value MinimapModule.RefreshZoneText() end },
			{ label = 'Horizontal offset', min = -300, max = 300, step = 1, get = function() return Interface().minimapZoneX end, set = function(value) Interface().minimapZoneX = value MinimapModule.RefreshZoneText() end },
			{ label = 'Vertical offset', min = -300, max = 300, step = 1, get = function() return Interface().minimapZoneY end, set = function(value) Interface().minimapZoneY = value MinimapModule.RefreshZoneText() end },
		} },
		{ get = function() return Interface().minimapZone == true end, set = function(value) Interface().minimapZone = value MinimapModule.ToggleZoneText(value) end },
	}, RefreshPreview)
	return board
end

local function ApplyDatatext()
	Datatext.Apply()
	RefreshPreview()
end

local function DatatextBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Datatext bar',
		description = 'A strip of datatexts attached to the map.',
	})
	Switch(board, 'Datatext bar', function() return Bar().enabled ~= false end, function(value)
		Bar().enabled = value
		Datatext.Apply()
	end)
	board:AddTools('Bar', 'Where it hangs on the map and how it is drawn', {
		{ kind = 'swatch', tooltip = 'Background color',
			get = function() local color = Bar().bgColor return color.r, color.g, color.b, 1 end,
			set = function(red, green, blue) Bar().bgColor = { r = red, g = green, b = blue } end },
		{ entries = ANCHORS, width = MENU_WIDTH, get = function() return Bar().anchor end, set = function(value) Bar().anchor = value end },
		{ tooltip = 'Gap, height, spacing and background', title = 'Bar', options = {
			{ label = 'Gap from the map', min = 0, max = 40, step = 1, get = function() return Bar().gap end, set = function(value) Bar().gap = value end },
			{ label = 'Height', min = 10, max = 40, step = 1, get = function() return Bar().height end, set = function(value) Bar().height = value end },
			{ label = 'Spacing', min = 0, max = 40, step = 1, get = function() return Bar().spacing end, set = function(value)
				local config = Bar()
				config.spacing, config.spacingPx = value, true
			end },
			{ label = 'Spread', min = 0, max = 100, step = 1, get = function() return tonumber(Bar().spread) or 0 end, set = function(value) Bar().spread = value end },
			{ label = 'Background opacity', min = 0, max = 100, step = 1, get = function() return floor(Bar().bgAlpha * 100 + 0.5) end, set = function(value) Bar().bgAlpha = value / 100 end },
			{ label = 'Border', get = function() return Bar().border == true end, set = function(value) Bar().border = value end },
			{ kind = 'swatch', label = 'Border color', opacity = true,
				get = function() local color = Bar().borderColor return color.r, color.g, color.b, color.a end,
				set = function(red, green, blue, alpha) Bar().borderColor = { r = red, g = green, b = blue, a = alpha } end },
		} },
	}, ApplyDatatext)
	board:AddTools('Text', 'Font, size and the value color', {
		{ kind = 'swatch', tooltip = 'Value color', opacity = true,
			get = function() local color = Bar().colorValue return color.r, color.g, color.b, color.a end,
			set = function(red, green, blue, alpha) Bar().colorValue = { r = red, g = green, b = blue, a = alpha } end },
		{ entries = fonts, width = MENU_WIDTH, get = function() return Bar().font end, set = function(value) Bar().font = value end },
		{ icon = 'text', tooltip = 'Size', title = 'Text', options = {
			{ label = 'Font size', min = 8, max = 24, step = 1, get = function() return Bar().fontSize end, set = function(value) Bar().fontSize = value end },
		} },
	}, ApplyDatatext)
	return board
end

local function ReadoutsBoard(ui, parent, width, page)
	local config = Bar()
	local order = Datatext.ResolveOrder(config)
	local rows = {}
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Datatexts',
		description = 'What the bar shows, top to bottom here is left to right on the bar.',
		buttons = {
			{ text = 'Default order', icon = 'reset', onClick = function()
				config.order = nil
				Datatext.Apply()
				page:Rebuild('datatext')
			end },
		},
	})
	local function Move(id, delta)
		if not Swap(order, id, delta) then return end
		board:Move(rows[id], delta)
		config.order = order
		Datatext.Apply()
		page:Resize()
	end
	for _, id in ipairs(order) do
		local entry = Datatext.Get(id)
		local row = board:AddRow(entry.name, nil, ORDER_ROOM + LABEL_TOGGLE + 12)
		rows[id] = row
		ui.Switch(row, function() return config[entry.show] == true end, function(value)
			config[entry.show] = value
			Datatext.Apply()
		end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
		OrderArrows(ui, row, function(delta) Move(id, delta) end)
		ui.Tool(row, BUI.DatatextLabelToggle(entry, config, ApplyDatatext)):SetPoint('RIGHT', -(ui.ROW_INSET + ORDER_ROOM + 12), 0)
	end
	return board
end

local function AddonButtonsBoard(ui, parent, width)
	local function RefreshButtonBar()
		ButtonBar.Refresh()
		RefreshPreview()
	end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Addon buttons',
		description = 'Tidy the buttons other addons put on the minimap: behind a drawer tab on its edge, or in a row beside it.',
	})
	board:AddTools('Drawer', 'Collects the buttons behind a tab on the edge of the map', {
		{ tooltip = 'Side and offsets', title = 'Drawer', options = {
			{ label = 'Side', entries = SIDES, get = function() return Interface().drawerSide end, set = function(value) Interface().drawerSide = value MinimapModule.SetDrawerSide(value) end },
			{ label = 'Horizontal offset', min = -300, max = 300, step = 1, get = function() return Interface().drawerX end, set = function(value) Interface().drawerX = value MinimapModule.RepositionDrawer() end },
			{ label = 'Vertical offset', min = -300, max = 300, step = 1, get = function() return Interface().drawerY end, set = function(value) Interface().drawerY = value MinimapModule.RepositionDrawer() end },
		} },
		{ get = function() return Interface().drawerEnabled == true end, set = MinimapModule.ToggleDrawer },
	}, RefreshPreview)
	board:AddTools('Button bar', 'A tidy row of buttons beside the map', {
		{ kind = 'swatch', tooltip = 'Tile background', opacity = true,
			get = function() local color = Buttons().background return color[1], color[2], color[3], color[4] end,
			set = function(red, green, blue, alpha) Buttons().background = { red, green, blue, alpha } end },
		{ tooltip = 'Side, size and spacing', title = 'Button bar', options = {
			{ label = 'Side', entries = SIDES, get = function() return Buttons().side end, set = function(value) Buttons().side = value end },
			{ label = 'Align', entries = ALIGNS, get = function() return Buttons().align end, set = function(value) Buttons().align = value end },
			{ label = 'Icon size', min = 12, max = 40, step = 1, get = function() return Buttons().size end, set = function(value) Buttons().size = value end },
			{ label = 'Spacing', min = -1, max = 10, step = 1, get = function() return Buttons().spacing end, set = function(value) Buttons().spacing = value end },
			{ label = 'Gap from the map', min = 0, max = 10, step = 1, get = function() return Buttons().gap end, set = function(value) Buttons().gap = value end },
			{ label = 'Per line, 0 keeps one line', min = 0, max = 20, step = 1, get = function() return Buttons().perLine end, set = function(value) Buttons().perLine = value end },
			{ label = 'Horizontal offset', min = -300, max = 300, step = 1, get = function() return Buttons().offsetX end, set = function(value) Buttons().offsetX = value end },
			{ label = 'Vertical offset', min = -300, max = 300, step = 1, get = function() return Buttons().offsetY end, set = function(value) Buttons().offsetY = value end },
		} },
		{ get = function() return Buttons().enabled == true end, set = function(value) Buttons().enabled = value end },
	}, RefreshButtonBar)
	return board
end

local function ButtonsBoard(ui, parent, width, page)
	local entries = ButtonBar.PickerEntries()
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Buttons',
		description = 'Which addon buttons sit on the bar, top to bottom here is first to last on the bar.',
	})
	if #entries == 0 then
		board:AddRow('No addon buttons yet', Buttons().enabled and 'They appear here as addons add buttons to the minimap' or 'Turn the button bar on to collect them')
		return board
	end
	local rows = {}
	local function Move(entry, delta)
		if not Swap(entries, entry, delta) then return end
		board:Move(rows[entry.id], delta)
		local names = {}
		for position, candidate in ipairs(entries) do names[position] = candidate.id end
		ButtonBar.SetOrder(names)
		RefreshPreview()
		page:Resize()
	end
	for _, entry in ipairs(entries) do
		local row = board:AddRow(entry.label, nil, ORDER_ROOM)
		rows[entry.id] = row
		ui.Switch(row, function() return entry.included == true end, function(value)
			entry.included = value
			ButtonBar.SetIncluded(entry.id, value)
			RefreshPreview()
		end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
		OrderArrows(ui, row, function(delta) Move(entry, delta) end)
	end
	return board
end

local function Panes(ui, _, parent, width, item, page)
	if item.id == 'map' then return { MapBoard(ui, parent, width) } end
	if item.id == 'indicators' then return { IndicatorsBoard(ui, parent, width) } end
	if item.id == 'text' then return { TextBoard(ui, parent, width) } end
	if item.id == 'datatext' then return { DatatextBoard(ui, parent, width), ReadoutsBoard(ui, parent, width, page) } end
	return { AddonButtonsBoard(ui, parent, width), ButtonsBoard(ui, parent, width, page) }
end

BUI.PageEngine.RegisterPage('minimap', {
	title = 'Minimap',
	buttonText = 'Minimap',
	icon = 'minimap',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local adapter = { tabContents = {}, currentTab = 1 }
		for index in ipairs(PANE_IDS) do adapter.tabContents[index] = {} end
		local rail
		rail = Layout.RailPage(page:GetTab(1), { window = Window() }, {
			icon = 'minimap',
			title = 'Minimap',
			placeholder = 'Search minimap settings...',
			tools = {
				{ icon = 'enable', tooltip = 'Turn the minimap module on or off, needs a reload', get = function() return Interface().minimapEnabled ~= false end, set = ConfirmModule },
				{ icon = 'eye', tooltip = 'Unlock the map to drag it and its indicators, right-click it to lock', get = MinimapModule.IsUnlocked, set = MinimapModule.ToggleUnlock },
			},
			preview = { height = PREVIEW_HEIGHT, build = function(band) preview = BuildPreview(band) end },
			rail = { groups = RAIL_GROUPS },
			build = Panes,
		})
		local Select = rail.Select
		function rail:Select(id)
			Select(self, id)
			adapter.currentTab = PANE_INDEX[id]
		end
		function adapter:SetTab(index)
			rail:Select(PANE_IDS[index])
		end
		pageFrame._page = adapter
		MinimapModule.SetLockReleaseCallback(Repaint)
		page:AutoRefresh()
	end,
})
