local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout, Modals, Widget = BUILib.Controls, BUILib.Layout, BUILib.Modals, BUILib.Widget
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
local NAME_WIDTH = 260
local SLIDER_WIDTH = 220
local DROPDOWN_WIDTH = 200
local SWATCH_SIZE = 28
local SWATCH_ROOM = 60
local SWITCH_WIDTH = 40
local SHOWN_COLUMN = 344
local ARROW = 22
local ARROW_GAP = 4
local ORDER_ROOM = SWITCH_WIDTH + 12 + ARROW * 2 + ARROW_GAP

local RAIL_GROUPS = {
	{ title = 'Map', items = {
		{ id = 'map', label = 'Map', icon = 'minimap' },
		{ id = 'indicators', label = 'Indicators', icon = 'eye' },
		{ id = 'text', label = 'Clock and zone', icon = 'edit' },
	} },
	{ title = 'Around the map', items = {
		{ id = 'datatext', label = 'Datatext bar', icon = 'report2' },
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
	{ key = 'queue', name = 'Queue eye', sub = 'Dungeon, raid and PvP queue status' },
	{ key = 'difficulty', name = 'Difficulty', sub = 'The instance difficulty', hide = 'minimapHideDifficulty' },
	{ key = 'mail', name = 'Mail', sub = 'New mail waiting', hide = 'minimapHideMail' },
	{ key = 'crafting', name = 'Crafting orders', sub = 'Personal crafting orders', hide = 'minimapHideCrafting' },
	{ key = 'missions', name = 'Folio', sub = 'The expansion landing page', hide = 'minimapHideGarrison' },
}

local ICON_DEFS = {
	{ key = 'queue', name = 'Queue', icon = 'Interface\\LFGFrame\\LFG-Eye', color = { 0.35, 0.72, 1.00 } },
	{ key = 'difficulty', name = 'Difficulty', icon = 'Interface\\Icons\\INV_Misc_Bone_Skull_02', color = { 1.00, 0.55, 0.15 } },
	{ key = 'mail', name = 'Mail', icon = 'Interface\\Icons\\INV_Letter_15', color = { 1.00, 0.88, 0.25 } },
	{ key = 'crafting', name = 'Crafting', icon = 'Interface\\Icons\\Trade_BlackSmithing', color = { 0.45, 0.82, 0.30 } },
	{ key = 'missions', name = 'Folio', icon = 'Interface\\Icons\\INV_Misc_Book_09', color = { 0.65, 0.40, 0.95 } },
}

local MINIMAP_YARDS = { 466.67, 400, 333.33, 266.67, 200, 133.33 }
local ADT_TILE = 533.3333333333333

local PREVIEW_DOCK = {
	TOPLEFT = { point = 'TOPLEFT', x = 5, y = -5, dirX = 1 },
	TOPRIGHT = { point = 'TOPRIGHT', x = -5, y = -5, dirX = -1 },
	BOTTOMLEFT = { point = 'BOTTOMLEFT', x = 5, y = 5, dirX = 1 },
	BOTTOMRIGHT = { point = 'BOTTOMRIGHT', x = -5, y = 5, dirX = -1 },
}

local preview

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

local function Named(entries, value)
	for _, entry in ipairs(entries) do
		if entry.value == value then return entry.text end
	end
	return value
end

local function Switch(board, label, get, set, tip)
	board:AddSwitch(label, get, function(value)
		set(value)
		RefreshPreview()
	end, tip)
end

local function Slider(ui, row, minimum, maximum, step, get, set)
	ui.Slider(row, SLIDER_WIDTH, { min = minimum, max = maximum, step = step, get = get, set = function(value)
		set(value)
		RefreshPreview()
	end }):SetPoint('RIGHT', -ui.ROW_INSET, 0)
end

local function Menu(ui, row, entries, get, set)
	local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local current = get()
		local items = {}
		for _, entry in ipairs(entries) do
			items[#items + 1] = { text = entry.text, checked = entry.value == current, callback = function()
				set(entry.value)
				RefreshPreview()
				Repaint()
			end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function() dropdown.label:SetText(Named(entries, get())) end)
end

local function FontMenu(ui, row, get, set)
	Menu(ui, row, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), get, set)
end

local function ColorRow(ui, board, name, sub, hasOpacity, get, set)
	local row = board:AddRow(name, sub, SWATCH_ROOM)
	local swatch = ui.Swatch(row, SWATCH_SIZE, function(self)
		local red, green, blue, alpha = get()
		Controls.OpenColorPicker({
			r = red, g = green, b = blue, a = alpha, hasOpacity = hasOpacity, anchorTo = self,
			callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
				if cancelled then set(red, green, blue, alpha) else set(newRed, newGreen, newBlue, newAlpha) end
				RefreshPreview()
				Repaint()
			end,
		})
	end)
	swatch:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function()
		local red, green, blue, alpha = get()
		swatch.fill:SetVertexColor(red, green, blue, hasOpacity and alpha or 1)
	end)
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

	local interfaceDB = Interface()
	local minimapWidth = Minimap:GetWidth()
	local scale = PREVIEW_MAP / minimapWidth
	local uiScale = scale * UIParent:GetEffectiveScale() / Minimap:GetEffectiveScale()

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

		local zoom = Minimap:GetZoom()
		local yards = MINIMAP_YARDS[zoom + 1] or MINIMAP_YARDS[1]
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

		local zoom = Minimap:GetZoom()
		local yards = MINIMAP_YARDS[zoom + 1] or MINIMAP_YARDS[1]
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

	local function ReadPosition(key)
		local saved = MinimapModule.GetIndicatorPosition(key)
		if saved then return saved[1], saved[2], saved[3] end
		return MinimapModule.GetIndicatorDefault(key)
	end

	local icons = {}

	local function PlaceIcon(proxy, key)
		local point, x, y = ReadPosition(key)
		local iconScale = MinimapModule.GetIconScale(key)
		proxy:ClearAllPoints()
		proxy:SetPoint(point, mapFrame, point, x * iconScale * scale, y * iconScale * scale)
		local size = floor(ICON_SIZE * (iconScale / 0.8))
		proxy:SetSize(size, size)
	end

	local function RefreshIcons()
		local anchor = PREVIEW_DOCK[MinimapModule.GetDock()]
		if anchor then
			local size = max(8, floor(MinimapModule.GetIconSize() * scale))
			local step = size + 3
			local iconIndex = 0
			for _, def in ipairs(ICON_DEFS) do
				local proxy = icons[def.key]
				if def.key ~= 'difficulty' then
					proxy:EnableMouse(false)
					proxy:ClearAllPoints()
					proxy:SetSize(size, size)
					proxy:SetPoint(anchor.point, mapFrame, anchor.point, anchor.x + anchor.dirX * iconIndex * step, anchor.y)
					iconIndex = iconIndex + 1
				else
					proxy:EnableMouse(true)
					PlaceIcon(proxy, def.key)
				end
			end
		else
			for _, def in ipairs(ICON_DEFS) do
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

	for _, def in ipairs(ICON_DEFS) do
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
				if not eyeFrame or not eyeFrame.GetRegions then return false end
				for _, region in ipairs({ eyeFrame:GetRegions() }) do
					if region.GetObjectType and region:GetObjectType() == 'Texture' then
						local atlas = region.GetAtlas and region:GetAtlas()
						if atlas then
							iconTexture:SetAtlas(atlas)
							iconTexture:SetTexCoord(0, 1, 0, 1)
							return true
						end
						local texture = region.GetTexture and region:GetTexture()
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
			local point, offsetX, offsetY = ReadPosition(def.key)
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

	local fontProbe = {}
	local function PreviewFont(key)
		fontProbe.font = interfaceDB[key]
		return BUI.GetModuleFont(fontProbe)
	end

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
		Pixel.ApplyFont(clockLabel, 9, PreviewFont('minimapClockFont'), '')
		Pixel.ApplyFont(zoneLabel, 8, PreviewFont('minimapZoneFont'), '')
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

	local DRAWER_TAB_W, DRAWER_TAB_H, DRAWER_TAB_INSET = 10, 44, 3
	local drawerTab = CreateFrame('Frame', nil, stage, 'BackdropTemplate')
	drawerTab:SetFrameLevel(mapFrame:GetFrameLevel() + 12)
	Pixel.SetTemplate(drawerTab, 0.85, 0.85, 0.85, 1, 0.1, 0.1, 0.1, 1)
	drawerTab:Hide()

	local function RefreshDrawer()
		if not interfaceDB.drawerEnabled then
			drawerTab:Hide()
			return
		end
		local side = interfaceDB.drawerSide
		local tabWidth, tabHeight = DRAWER_TAB_W * uiScale, DRAWER_TAB_H * uiScale
		if side == 'TOP' or side == 'BOTTOM' then tabWidth, tabHeight = tabHeight, tabWidth end
		drawerTab:SetSize(max(2, tabWidth), max(2, tabHeight))
		local offsetX = interfaceDB.drawerX * uiScale
		local offsetY = interfaceDB.drawerY * uiScale
		local inset = DRAWER_TAB_INSET * uiScale
		drawerTab:ClearAllPoints()
		if side == 'LEFT' then
			drawerTab:SetPoint('CENTER', mapFrame, 'LEFT', inset + offsetX, offsetY)
		elseif side == 'RIGHT' then
			drawerTab:SetPoint('CENTER', mapFrame, 'RIGHT', -inset + offsetX, offsetY)
		elseif side == 'TOP' then
			drawerTab:SetPoint('CENTER', mapFrame, 'TOP', offsetX, -inset + offsetY)
		else
			drawerTab:SetPoint('CENTER', mapFrame, 'BOTTOM', offsetX, inset + offsetY)
		end
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

		local anchor = ButtonBar.ANCHORS[config.side] or ButtonBar.ANCHORS.BOTTOM
		local size = max(4, floor(config.size * uiScale + 0.5))
		local spacing = floor(config.spacing * uiScale + 0.5)
		local perLine = config.perLine > 0 and config.perLine or count
		local lineCount = min(count, perLine)
		local crossCount = math.ceil(count / perLine)
		local lineExtent = lineCount * size + (lineCount - 1) * spacing
		local crossExtent = crossCount * size + (crossCount - 1) * spacing
		if anchor.horizontal then
			barHolder:SetSize(max(1, lineExtent), max(1, crossExtent))
		else
			barHolder:SetSize(max(1, crossExtent), max(1, lineExtent))
		end
		local points = anchor[config.align] or anchor.CENTER
		barHolder:ClearAllPoints()
		local mapGap = config.gap * uiScale
		local gapX = (config.side == 'LEFT' and -mapGap) or (config.side == 'RIGHT' and mapGap) or 0
		local gapY = (config.side == 'TOP' and mapGap) or (config.side == 'BOTTOM' and -mapGap) or 0
		barHolder:SetPoint(points[1], mapFrame, points[2], config.offsetX * uiScale + gapX, config.offsetY * uiScale + gapY)

		local corner = (anchor.dirY == 1 and 'BOTTOM' or 'TOP') .. (anchor.dirX == -1 and 'RIGHT' or 'LEFT')
		local step = size + spacing
		local background = config.background
		for index = 1, count do
			local proxy = BarProxy(index)
			local lineIndex = (index - 1) % perLine
			local crossIndex = floor((index - 1) / perLine)
			local x, y
			if anchor.horizontal then x, y = lineIndex * step, crossIndex * step else x, y = crossIndex * step, lineIndex * step end
			proxy:SetSize(size, size)
			proxy:SetBackdropColor(background[1], background[2], background[3], background[4])
			proxy:ClearAllPoints()
			proxy:SetPoint(corner, barHolder, corner, x * anchor.dirX, y * anchor.dirY)
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
		minimapWidth = Minimap:GetWidth()
		scale = PREVIEW_MAP / minimapWidth
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
	Slider(ui, board:AddRow('Scale', 'Percent of the default size', SLIDER_WIDTH), 50, 200, 1,
		function() return Interface().minimapScale end,
		MinimapModule.SetScale)
	Slider(ui, board:AddRow('Border width', 'Pixels around the map', SLIDER_WIDTH), 0, 10, 1,
		function() return Interface().minimapBorderWidth end,
		MinimapModule.SetBorderWidth)
	Slider(ui, board:AddRow('From the right edge', 'Distance from the right of the screen', SLIDER_WIDTH), 0, floor(GetScreenWidth()), 1,
		function() return -(MinimapModule.GetPosition()) end,
		function(value) MinimapModule.SetPositionX(-value) end)
	Slider(ui, board:AddRow('From the top edge', 'Distance from the top of the screen', SLIDER_WIDTH), 0, floor(GetScreenHeight()), 1,
		function() local _, y = MinimapModule.GetPosition() return -y end,
		function(value) MinimapModule.SetPositionY(-value) end)
	return board
end

local function IndicatorsSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Indicators',
		description = 'The small buttons that live on the map. Drag them around the preview above, or unlock the real map, and size them here.',
		columns = { { 'Indicator', ui.ROW_INSET }, { 'Shown', SHOWN_COLUMN }, { 'Size', width - ui.ROW_INSET - SLIDER_WIDTH } },
	})
	for _, def in ipairs(INDICATORS) do
		local row = section:AddRow(def.name .. ' ' .. def.sub)
		ui.RowTitle(row, def.name, def.sub, ui.ROW_INSET, NAME_WIDTH)
		if def.hide then
			ui.Switch(row, function() return not Interface()[def.hide] end, function(value)
				Interface()[def.hide] = not value
				MinimapModule.ApplyVisibility()
				if def.key == 'difficulty' then MinimapModule.ToggleTextDifficulty(value and Interface().minimapTextDifficulty == true) end
				RefreshPreview()
			end):SetPoint('LEFT', SHOWN_COLUMN, 0)
		else
			ui.Cell(row, 'Always', SHOWN_COLUMN)
		end
		Slider(ui, row, 40, 160, 5,
			function() return floor(MinimapModule.GetIconScale(def.key) * 100 + 0.5) end,
			function(value) MinimapModule.SetIconScale(def.key, value / 100) end)
	end
	local textRow = section:AddRow('difficulty as text')
	ui.RowTitle(textRow, 'Difficulty as text', 'Letters instead of the skull icon', ui.ROW_INSET, NAME_WIDTH)
	ui.Switch(textRow, function() return Interface().minimapTextDifficulty == true end, function(value)
		Interface().minimapTextDifficulty = value
		MinimapModule.ToggleTextDifficulty(value)
		MinimapModule.ApplyVisibility()
		RefreshPreview()
	end):SetPoint('LEFT', SHOWN_COLUMN, 0)
	return section
end

local function ClockBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Clock',
		description = 'The time in the corner of the map. Drag it in the preview above, or nudge it here.',
	})
	Switch(board, 'Clock', function() return Interface().minimapClock == true end, function(value)
		Interface().minimapClock = value
		MinimapModule.ToggleClock(value)
	end)
	Switch(board, '24-hour', function() return Interface().minimapClock24h == true end, function(value)
		Interface().minimapClock24h = value
		MinimapModule.SetClockFormat(value)
	end)
	Switch(board, 'Server time', function() return Interface().minimapClockServer == true end, function(value)
		Interface().minimapClockServer = value
		MinimapModule.SetClockSource(value)
	end)
	Slider(ui, board:AddRow('Size', 'Font size', SLIDER_WIDTH), 8, 24, 1,
		function() return Interface().minimapClockSize end,
		function(value) Interface().minimapClockSize = value MinimapModule.RefreshClock() end)
	Slider(ui, board:AddRow('Horizontal offset', 'From its corner', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().minimapClockX end,
		function(value) Interface().minimapClockX = value MinimapModule.RefreshClock() end)
	Slider(ui, board:AddRow('Vertical offset', 'From its corner', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().minimapClockY end,
		function(value) Interface().minimapClockY = value MinimapModule.RefreshClock() end)
	FontMenu(ui, board:AddRow('Font', 'Global unless you pick one', DROPDOWN_WIDTH),
		function() return Interface().minimapClockFont or BUI.C.GLOBAL_OPTION end,
		function(value) Interface().minimapClockFont = value MinimapModule.RefreshClock() end)
	ColorRow(ui, board, 'Color', 'Text color', false,
		function() local color = Interface().minimapClockColor return color.r, color.g, color.b end,
		function(red, green, blue) Interface().minimapClockColor = { r = red, g = green, b = blue } MinimapModule.RefreshClock() end)
	return board
end

local function ZoneBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Zone name',
		description = 'The zone you are in, at the top of the map. Drag it in the preview above, or nudge it here.',
	})
	Switch(board, 'Zone name', function() return Interface().minimapZone == true end, function(value)
		Interface().minimapZone = value
		MinimapModule.ToggleZoneText(value)
	end)
	Switch(board, 'Custom color', function() return Interface().minimapZoneColorCustom == true end, function(value)
		Interface().minimapZoneColorCustom = value
		MinimapModule.RefreshZoneText()
	end, 'Off colors the name by zone type')
	Slider(ui, board:AddRow('Size', 'Font size', SLIDER_WIDTH), 8, 24, 1,
		function() return Interface().minimapZoneSize end,
		function(value) Interface().minimapZoneSize = value MinimapModule.RefreshZoneText() end)
	Slider(ui, board:AddRow('Horizontal offset', 'From its corner', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().minimapZoneX end,
		function(value) Interface().minimapZoneX = value MinimapModule.RefreshZoneText() end)
	Slider(ui, board:AddRow('Vertical offset', 'From its corner', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().minimapZoneY end,
		function(value) Interface().minimapZoneY = value MinimapModule.RefreshZoneText() end)
	FontMenu(ui, board:AddRow('Font', 'Global unless you pick one', DROPDOWN_WIDTH),
		function() return Interface().minimapZoneFont or BUI.C.GLOBAL_OPTION end,
		function(value) Interface().minimapZoneFont = value MinimapModule.RefreshZoneText() end)
	ColorRow(ui, board, 'Color', 'Used when custom color is on', false,
		function() local color = Interface().minimapZoneColor return color.r, color.g, color.b end,
		function(red, green, blue)
			Interface().minimapZoneColorCustom = true
			Interface().minimapZoneColor = { r = red, g = green, b = blue }
			MinimapModule.RefreshZoneText()
		end)
	return board
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
	Switch(board, 'Hide labels', function() return Bar().hideLabels == true end, function(value)
		Bar().hideLabels = value
		Datatext.Apply()
	end)
	Switch(board, 'Border', function() return Bar().border == true end, function(value)
		Bar().border = value
		Datatext.Apply()
	end)
	Menu(ui, board:AddRow('Anchor', 'Which side of the map it hangs on', DROPDOWN_WIDTH), ANCHORS,
		function() return Bar().anchor end,
		function(value) Bar().anchor = value Datatext.Apply() end)
	Slider(ui, board:AddRow('Gap from the map', nil, SLIDER_WIDTH), 0, 40, 1,
		function() return Bar().gap end,
		function(value) Bar().gap = value Datatext.Apply() end)
	Slider(ui, board:AddRow('Height', nil, SLIDER_WIDTH), 10, 40, 1,
		function() return Bar().height end,
		function(value) Bar().height = value Datatext.Apply() end)
	Slider(ui, board:AddRow('Spacing', 'Pixels between datatexts', SLIDER_WIDTH), 0, 40, 1,
		function() return Bar().spacing end,
		function(value)
			local config = Bar()
			config.spacing, config.spacingPx = value, true
			Datatext.Apply()
		end)
	Slider(ui, board:AddRow('Spread', 'Pushes the datatexts apart to fill the bar', SLIDER_WIDTH), 0, 100, 1,
		function() return tonumber(Bar().spread) or 0 end,
		function(value) Bar().spread = value Datatext.Apply() end)
	Slider(ui, board:AddRow('Background opacity', nil, SLIDER_WIDTH), 0, 100, 1,
		function() return floor(Bar().bgAlpha * 100 + 0.5) end,
		function(value) Bar().bgAlpha = value / 100 Datatext.Apply() end)
	Slider(ui, board:AddRow('Font size', nil, SLIDER_WIDTH), 8, 24, 1,
		function() return Bar().fontSize end,
		function(value) Bar().fontSize = value Datatext.Apply() end)
	FontMenu(ui, board:AddRow('Font', 'Global unless you pick one', DROPDOWN_WIDTH),
		function() return Bar().font end,
		function(value) Bar().font = value Datatext.Apply() end)
	ColorRow(ui, board, 'Background color', nil, false,
		function() local color = Bar().bgColor return color.r, color.g, color.b end,
		function(red, green, blue) Bar().bgColor = { r = red, g = green, b = blue } Datatext.Apply() end)
	ColorRow(ui, board, 'Border color', nil, true,
		function() local color = Bar().borderColor return color.r, color.g, color.b, color.a end,
		function(red, green, blue, alpha) Bar().borderColor = { r = red, g = green, b = blue, a = alpha } Datatext.Apply() end)
	ColorRow(ui, board, 'Value color', 'The numbers next to each label', true,
		function() local color = Bar().colorValue return color.r, color.g, color.b, color.a end,
		function(red, green, blue, alpha) Bar().colorValue = { r = red, g = green, b = blue, a = alpha } Datatext.Apply() end)
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
		local index
		for position, candidate in ipairs(order) do
			if candidate == id then index = position end
		end
		if not order[index + delta] then return end
		order[index], order[index + delta] = order[index + delta], order[index]
		board:Move(rows[id], delta)
		config.order = order
		Datatext.Apply()
		page:Resize()
	end
	for _, id in ipairs(order) do
		local entry = Datatext.Get(id)
		local row = board:AddRow(entry.name, nil, ORDER_ROOM)
		rows[id] = row
		ui.Switch(row, function() return config[entry.show] == true end, function(value)
			config[entry.show] = value
			Datatext.Apply()
		end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
		OrderArrows(ui, row, function(delta) Move(id, delta) end)
	end
	return board
end

local function DrawerBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Addon drawer',
		description = 'Collects addon minimap buttons behind a tab on the edge of the map.',
	})
	Switch(board, 'Drawer', function() return Interface().drawerEnabled == true end, MinimapModule.ToggleDrawer)
	Menu(ui, board:AddRow('Side', 'Which edge the tab sits on', DROPDOWN_WIDTH), SIDES,
		function() return Interface().drawerSide end,
		function(value)
			Interface().drawerSide = value
			MinimapModule.SetDrawerSide(value)
		end)
	Slider(ui, board:AddRow('Horizontal offset', 'Nudge along the edge', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().drawerX end,
		function(value) Interface().drawerX = value MinimapModule.RepositionDrawer() end)
	Slider(ui, board:AddRow('Vertical offset', 'Nudge along the edge', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().drawerY end,
		function(value) Interface().drawerY = value MinimapModule.RepositionDrawer() end)
	return board
end

local function ButtonBarBoard(ui, parent, width)
	local function Refresh()
		MinimapModule.RefreshButtonBar()
	end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Button bar',
		description = 'Addon buttons in a tidy row beside the map instead of scattered around it.',
	})
	Switch(board, 'Button bar', function() return Buttons().enabled == true end, function(value)
		Buttons().enabled = value
		Refresh()
	end)
	Menu(ui, board:AddRow('Side', 'Which edge of the map', DROPDOWN_WIDTH), SIDES,
		function() return Buttons().side end,
		function(value) Buttons().side = value Refresh() end)
	Menu(ui, board:AddRow('Align', 'Along that edge', DROPDOWN_WIDTH), ALIGNS,
		function() return Buttons().align end,
		function(value) Buttons().align = value Refresh() end)
	Slider(ui, board:AddRow('Icon size', nil, SLIDER_WIDTH), 12, 40, 1,
		function() return Buttons().size end,
		function(value) Buttons().size = value Refresh() end)
	Slider(ui, board:AddRow('Spacing', 'Between icons', SLIDER_WIDTH), -1, 10, 1,
		function() return Buttons().spacing end,
		function(value) Buttons().spacing = value Refresh() end)
	Slider(ui, board:AddRow('Gap from the map', nil, SLIDER_WIDTH), 0, 10, 1,
		function() return Buttons().gap end,
		function(value) Buttons().gap = value Refresh() end)
	Slider(ui, board:AddRow('Per line', '0 keeps them on one line', SLIDER_WIDTH), 0, 20, 1,
		function() return Buttons().perLine end,
		function(value) Buttons().perLine = value Refresh() end)
	Slider(ui, board:AddRow('Horizontal offset', nil, SLIDER_WIDTH), -300, 300, 1,
		function() return Buttons().offsetX end,
		function(value) Buttons().offsetX = value Refresh() end)
	Slider(ui, board:AddRow('Vertical offset', nil, SLIDER_WIDTH), -300, 300, 1,
		function() return Buttons().offsetY end,
		function(value) Buttons().offsetY = value Refresh() end)
	ColorRow(ui, board, 'Tile background', 'Behind every icon', true,
		function() local color = Buttons().background return color[1], color[2], color[3], color[4] end,
		function(red, green, blue, alpha)
			Buttons().background = { red, green, blue, alpha }
			Refresh()
		end)
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
		local index
		for position, candidate in ipairs(entries) do
			if candidate == entry then index = position end
		end
		if not entries[index + delta] then return end
		entries[index], entries[index + delta] = entries[index + delta], entries[index]
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
	if item.id == 'indicators' then return { IndicatorsSection(ui, parent, width) } end
	if item.id == 'text' then return { ClockBoard(ui, parent, width), ZoneBoard(ui, parent, width) } end
	if item.id == 'datatext' then return { DatatextBoard(ui, parent, width), ReadoutsBoard(ui, parent, width, page) } end
	return { DrawerBoard(ui, parent, width), ButtonBarBoard(ui, parent, width), ButtonsBoard(ui, parent, width, page) }
end

BUI.PageEngine.RegisterPage('minimap', {
	title = 'Minimap',
	buttonText = 'Minimap',
	icon = 'minimap',
	OnBuild = function(pageFrame)
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
