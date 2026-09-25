local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls, Layout = BUILib.Controls, BUILib.Layout
local MinimapModule = BUI.Minimap
local Pixel = BUI.Pixel

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local FONT = BUI.C.FONT_PATH
local PREVIEW_MAP = 200
local ICON_SIZE = 18

local SIDE_OPTIONS = {
    { value = 'LEFT',   text = 'Left'   },
    { value = 'RIGHT',  text = 'Right'  },
    { value = 'TOP',    text = 'Top'    },
    { value = 'BOTTOM', text = 'Bottom' },
}

local ALIGN_OPTIONS = {
    { value = 'START',  text = 'Start'  },
    { value = 'CENTER', text = 'Center' },
    { value = 'END',    text = 'End'    },
}

local ICON_DEFS = {
    { key = 'queue',      label = 'Q', icon = 'Interface\\LFGFrame\\LFG-Eye',             color = { 0.35, 0.72, 1.00 } },
    { key = 'difficulty', label = 'D', icon = 'Interface\\Icons\\INV_Misc_Bone_Skull_02', color = { 1.00, 0.55, 0.15 } },
    { key = 'mail',       label = 'M', icon = 'Interface\\Icons\\INV_Letter_15',          color = { 1.00, 0.88, 0.25 } },
    { key = 'crafting',   label = 'C', icon = 'Interface\\Icons\\Trade_BlackSmithing',    color = { 0.45, 0.82, 0.30 } },
    { key = 'missions',   label = 'F', name = 'Folio', icon = 'Interface\\Icons\\INV_Misc_Book_09', color = { 0.65, 0.40, 0.95 } },
}

local function GetInterfaceConfig() return BUI.GetDB().interface end

local PageKit = BUILib.PageKit

local function ShowTip(frame, text)
    BUILib.Widget.ShowTip(frame, text)
end
local function HideTip()
    BUILib.Widget.HideTip()
end

local function BuildPreview(parent, opts)
    local onLayoutChanged = opts.onLayoutChanged
    local card, stage = BUILib.PageKit.PreviewStage(parent, { stageW = PREVIEW_MAP + 8, stageH = PREVIEW_MAP + 8, tick = 2 })

    local interfaceDB = GetInterfaceConfig()
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
    mapFrame:SetPoint('CENTER', stage, 'CENTER', 0, 0)
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
    hint:SetPoint('BOTTOM', card, 'BOTTOM', 0, 4)
    hint:SetTextColor(0.42, 0.42, 0.47, 0.9)
    hint:SetText('Drag icons & text to reposition  ·  Scroll icons to resize')

    local tilePool = {}

    local MINIMAP_YARDS = { 466.67, 400, 333.33, 266.67, 200, 133.33 }
    local ADT_TILE = 533.3333333333333

    local tileCache, tileCacheDir

    local function DecodeTiles(dir)
        if tileCacheDir == dir then return tileCache end
        tileCacheDir, tileCache = dir, nil
        local stream = dir and BUI.MinimapTiles[dir]
        if not stream then return nil end
        local tiles = {}
        local tileIndex, fileDataID = 0, 0
        for indexToken, fileToken in stream:gmatch('([^;.]+)%.([^;]+)') do
            tileIndex  = tileIndex  + (indexToken:sub(1, 1) == '!' and -tonumber(indexToken:sub(2), 36) or tonumber(indexToken, 36))
            fileDataID = fileDataID + (fileToken:sub(1, 1) == '!' and -tonumber(fileToken:sub(2), 36) or tonumber(fileToken, 36))
            tiles[tileIndex] = fileDataID
        end
        tileCache = tiles
        return tiles
    end

    local function ApplyMapArt()
        local mapID = C_Map.GetBestMapForUnit('player')
        local layer = mapID and (C_Map.GetMapArtLayers(mapID) or {})[1]
        local textures = layer and C_Map.GetMapArtLayerTextures(mapID, 1)
        if not (textures and #textures > 0 and layer.tileWidth and layer.tileWidth > 0) then return end

        local pos = C_Map.GetPlayerMapPosition(mapID, 'player')
        local playerX = pos and pos.x or 0.5
        local playerY = pos and pos.y or 0.5

        local zoom = Minimap:GetZoom()
        local yards = MINIMAP_YARDS[zoom + 1] or MINIMAP_YARDS[1]
        local worldWidth, worldHeight
        worldWidth, worldHeight = C_Map.GetMapWorldSize(mapID)
        local fracX = (worldWidth and worldWidth > 0) and min(1, yards / worldWidth) or 0.25
        local fracY = (worldHeight and worldHeight > 0) and min(1, yards / worldHeight) or 0.25

        local windowWidth = fracX * layer.layerWidth
        local windowHeight = fracY * layer.layerHeight
        local centerX = max(windowWidth / 2, min(layer.layerWidth  - windowWidth / 2, playerX * layer.layerWidth))
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
                local tile = tilePool[tileCount]
                if not tile then
                    tile = content:CreateTexture(nil, 'BACKGROUND')
                    tilePool[tileCount] = tile
                end
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
                local fileDataID = col >= 0 and col <= 63 and row >= 0 and row <= 63
                    and tiles[col * 64 + row]
                if fileDataID then
                    tileCount = tileCount + 1
                    local tile = tilePool[tileCount]
                    if not tile then
                        tile = content:CreateTexture(nil, 'BACKGROUND')
                        tilePool[tileCount] = tile
                    end
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

    local function WritePosition(key, point, x, y)
        MinimapModule.SaveIndicatorPosition(key, point, x, y)
    end

    local function GetIconScale(key) return MinimapModule.GetIconScale(key) end

    local icons = {}

    local function PlaceIcon(proxy, key)
        local point, x, y = ReadPosition(key)
        local iconScale = GetIconScale(key)
        proxy:ClearAllPoints()
        proxy:SetPoint(point, mapFrame, point, x * iconScale * scale, y * iconScale * scale)
        local size = floor(ICON_SIZE * (iconScale / 0.8))
        proxy:SetSize(size, size)
    end

    local PREVIEW_DOCK = {
        TOPLEFT     = { point = 'TOPLEFT',     x =  5, y = -5, dirX =  1 },
        TOPRIGHT    = { point = 'TOPRIGHT',    x = -5, y = -5, dirX = -1 },
        BOTTOMLEFT  = { point = 'BOTTOMLEFT',  x =  5, y =  5, dirX =  1 },
        BOTTOMRIGHT = { point = 'BOTTOMRIGHT', x = -5, y =  5, dirX = -1 },
    }

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
        if not centerX or not mapCenterX then PlaceIcon(proxy, key); return end

        local relX, relY = centerX - mapCenterX, centerY - mapCenterY
        local half = PREVIEW_MAP / 2
        relX = max(-half, min(half, relX))
        relY = max(-half, min(half, relY))

        proxy:ClearAllPoints()
        proxy:SetPoint('CENTER', mapFrame, 'CENTER', relX, relY)

        local iconScale = GetIconScale(key)
        WritePosition(key, 'CENTER', relX / (scale * iconScale), relY / (scale * iconScale))
        MinimapModule.RepositionIndicators()
        onLayoutChanged()
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
            local src = landingButton and (landingButton.LandingPageIcon or landingButton.Icon or (landingButton.GetNormalTexture and landingButton:GetNormalTexture()))
            local atlas = src and src.GetAtlas and src:GetAtlas()
            if atlas then iconTexture:SetAtlas(atlas); iconTexture:SetTexCoord(0, 1, 0, 1) end
        elseif def.key == 'queue' then
            local function copyEye(eyeFrame)
                if not eyeFrame or not eyeFrame.GetRegions then return false end
                for _, region in ipairs({ eyeFrame:GetRegions() }) do
                    if region.GetObjectType and region:GetObjectType() == 'Texture' then
                        local atlas = region.GetAtlas and region:GetAtlas()
                        if atlas then iconTexture:SetAtlas(atlas); iconTexture:SetTexCoord(0, 1, 0, 1); return true end
                        local texture = region.GetTexture and region:GetTexture()
                        if texture then iconTexture:SetTexture(texture); iconTexture:SetTexCoord(region:GetTexCoord()); return true end
                    end
                end
                return false
            end
            local queueButton = _G.QueueStatusButton
            if not (copyEye(queueButton and queueButton.Eye) or copyEye(queueButton)) then
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
                local SNAP = 8 * scale
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
                    if abs(abs(cursorX - bestX) - gap) <= SNAP and abs(cursorY - bestY) <= gap then
                        cursorX, cursorY = bestX + (cursorX >= bestX and gap or -gap), bestY
                    elseif abs(abs(cursorY - bestY) - gap) <= SNAP and abs(cursorX - bestX) <= gap then
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

        local tipName = def.name or (def.key:sub(1, 1):upper() .. def.key:sub(2))
        proxy:EnableMouseWheel(true)
        proxy:SetScript('OnMouseWheel', function(self, delta)
            local oldScale = GetIconScale(def.key)
            local newScale = max(0.4, min(1.6, oldScale + delta * 0.1))
            MinimapModule.SetIconScale(def.key, newScale)
            local point, offsetX, offsetY = ReadPosition(def.key)
            WritePosition(def.key, point, offsetX * oldScale / newScale, offsetY * oldScale / newScale)
            PlaceIcon(self, def.key)
            MinimapModule.RepositionIndicators()
            ShowTip(self, format('%s  |  Scale: %.0f%%', tipName, newScale * 100))
        end)
        proxy:SetScript('OnEnter', function(self)
            self:SetBackdropBorderColor(1, 1, 1, 1)
            ShowTip(self, format('%s  |  Scale: %.0f%%  |  Drag to move', tipName, GetIconScale(def.key) * 100))
        end)
        proxy:SetScript('OnLeave', function(self)
            self:SetBackdropBorderColor(0, 0, 0, 1)
            HideTip()
        end)

        icons[def.key] = proxy
    end

    local clockLabel = overlay:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(clockLabel, 9, FONT, '')
    clockLabel:SetTextColor(1, 1, 1, 0.6)

    local zoneLabel = overlay:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(zoneLabel, 8, FONT, '')
    zoneLabel:SetTextColor(1, 0.82, 0, 0.6)

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
            onLayoutChanged()
        end)
        button:SetScript('OnEnter', function(self)
            glow:SetVertexColor(1, 1, 1, 0.12)
            ShowTip(self, name .. '  |  Drag to move')
        end)
        button:SetScript('OnLeave', function()
            glow:SetVertexColor(1, 1, 1, 0)
            HideTip()
        end)
        textDraggers[#textDraggers + 1] = { btn = button, fs = fontString }
        return button
    end

    local clockDrag = MakeTextDragger('Clock', clockLabel, 'minimapClockX', 'minimapClockY', function() MinimapModule.RefreshClock() end)
    local zoneDrag  = MakeTextDragger('Zone Text', zoneLabel, 'minimapZoneX', 'minimapZoneY', function() MinimapModule.RefreshZoneText() end)

    local function SyncTextDraggers()
        for _, entry in ipairs(textDraggers) do
            entry.btn:SetSize(max(36, entry.fs:GetStringWidth() + 10), 14)
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
        local clockX = interfaceDB.minimapClockX * scale
        local clockY = interfaceDB.minimapClockY * scale
        local zoneX = interfaceDB.minimapZoneX * scale
        local zoneY = interfaceDB.minimapZoneY * scale
        clockLabel:SetPoint('TOPRIGHT', mapFrame, 'TOPRIGHT', -4 + clockX, -4 + clockY)
        clockLabel:SetJustifyH('RIGHT')
        zoneLabel:SetPoint('TOPLEFT', mapFrame, 'TOPLEFT', 4 + zoneX, -4 + zoneY)
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
        if not interfaceDB.drawerEnabled then drawerTab:Hide(); return end
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
        local module = BUI.MinimapButtonBar
        local config = interfaceDB.buttonBar
        if not config.enabled then barHolder:Hide(); return end
        local entries = {}
        for _, entry in ipairs(module.PickerEntries()) do
            if entry.included then entries[#entries + 1] = entry end
        end
        local count = #entries
        if count == 0 then barHolder:Hide(); return end

        local anchor = module.ANCHORS[config.side] or module.ANCHORS.BOTTOM
        local size = max(4, floor(config.size * uiScale + 0.5))
        local spacing = floor(config.spacing * uiScale + 0.5)
        local perLine = config.perLine > 0 and config.perLine or count
        local lineCount = min(count, perLine)
        local crossCount = math.ceil(count / perLine)
        local lineExtent = lineCount * size + (lineCount - 1) * spacing
        local crossExtent = crossCount * size + (crossCount - 1) * spacing
        if anchor.horizontal then barHolder:SetSize(max(1, lineExtent), max(1, crossExtent))
        else barHolder:SetSize(max(1, crossExtent), max(1, lineExtent)) end
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
            if icon then proxy.icon:SetTexture(icon); proxy.icon:Show() else proxy.icon:Hide() end
            proxy:Show()
        end
        for index = count + 1, #barProxies do barProxies[index]:Hide() end
        barHolder:Show()
    end

    function card:UpdatePreview()
        interfaceDB = GetInterfaceConfig()
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

    ApplyMapSnapshot()
    ApplyBorder()
    RefreshIcons()
    PlaceText()
    RefreshDrawer()
    RefreshButtonBar()
    return card
end

BUI.PageEngine.RegisterPage('minimap', {
    title = 'Minimap',
    buttonText = 'Minimap',
    minContentWidth  = 924,
    minContentHeight = 600,
    OnBuild = function(pageFrame)
        local PREVIEW_HEIGHT = 240

        local SyncDim, titleBar, RunRefreshers

        local preview
        local function RefreshPreview() if preview then preview:UpdatePreview() end end

        local refreshers = {}
        local function AddRefresh(refreshFunction) refreshers[#refreshers + 1] = refreshFunction end
        RunRefreshers = function()
            for _, refresh in ipairs(refreshers) do refresh() end
            RefreshPreview()
        end

        local minimapGrids = {}
        SyncDim = function()
            local enabled = GetInterfaceConfig().minimapEnabled ~= false
            for gridIndex = 1, #minimapGrids do minimapGrids[gridIndex]:SyncDim(enabled) end
        end

        local function OnEnableToggle(value)
            titleBar.enableToggle:SetValue(not value)
            BUILib.Modals.Confirm({
                parent = BUI.PageEngine.window.frame,
                title = 'Reload Required',
                message = value and 'Enabling the minimap module requires a UI reload.'
                    or 'Disabling the minimap module requires a UI reload to fully revert changes.',
                confirmText = 'Reload Now', cancelText = 'Cancel', laterText = 'Later',
                onConfirm = function()
                    GetInterfaceConfig().minimapEnabled = value
                    ReloadUI()
                end,
                onLater = function()
                    GetInterfaceConfig().minimapEnabled = value
                    titleBar.enableToggle:SetValue(value)
                    SyncDim()
                end,
            })
        end

        AddRefresh(function() titleBar.enableToggle:SetValue(GetInterfaceConfig().minimapEnabled ~= false) end)
        AddRefresh(function() titleBar.anchorToggle:SetValue(MinimapModule.IsUnlocked()) end)

        local function BuildMinimapTab(tab)
            local grid
            local function Section(title)
                if grid then grid:Flush() end
                Layout.Section(tab, title)
                grid = PageKit.RowGrid(tab)
                minimapGrids[#minimapGrids + 1] = grid
            end
            local function AddRow(config) return grid:Add(config) end

            Section('Map')

            AddRow({
                spanFull = true,
                title = 'Map',
                description = 'Screen position, scale, and border.',
                plain = true,
                accessoryWidth = 64,
                accessories = function(row)
                    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
                    local mapMover = PageKit.PositionIcon(row, {
                        title = 'POSITION', tooltip = 'Map position on screen', onChange = RefreshPreview,
                        options = {
                            { kind = 'slider', label = 'From Right', min = 0, max = floor(screenWidth),
                              get = function() local x = MinimapModule.GetPosition(); return -x end,
                              set = function(value) MinimapModule.SetPositionX(-value) end },
                            { kind = 'slider', label = 'From Top', min = 0, max = floor(screenHeight),
                              get = function() local _, y = MinimapModule.GetPosition(); return -y end,
                              set = function(value) MinimapModule.SetPositionY(-value) end },
                        },
                    })
                    local mapCog = PageKit.SettingsIcon(row, {
                        title = 'MAP', tooltip = 'Scale, border & rotation', onChange = RefreshPreview,
                        options = {
                            { kind = 'slider', label = 'Scale', min = 50, max = 200,
                              get = function() return GetInterfaceConfig().minimapScale end,
                              set = function(value) MinimapModule.SetScale(value) end },
                            { kind = 'slider', label = 'Border Width', min = 0, max = 10,
                              get = function() return GetInterfaceConfig().minimapBorderWidth end,
                              set = function(value) MinimapModule.SetBorderWidth(value) end },
                            { label = 'Rotate Minimap',
                              get = function() return GetInterfaceConfig().rotateMinimap end,
                              set = function(value) GetInterfaceConfig().rotateMinimap = value; MinimapModule.ToggleRotation(value) end },
                        },
                    })
                    return { mapMover, mapCog }
                end,
            })

            AddRow({
                title = 'Indicator Icons',
                description = 'Which indicator icons appear on the map.',
                plain = true,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, {
                        title = 'ICONS', tooltip = 'Which indicators to show', onChange = RefreshPreview,
                        options = {
                            { label = 'Difficulty',
                              get = function() return not GetInterfaceConfig().minimapHideDifficulty end,
                              set = function(value)
                                  GetInterfaceConfig().minimapHideDifficulty = not value
                                  MinimapModule.ApplyVisibility()
                                  if not value then MinimapModule.ToggleTextDifficulty(false)
                                  elseif GetInterfaceConfig().minimapTextDifficulty then MinimapModule.ToggleTextDifficulty(true) end
                              end },
                            { label = 'Difficulty as Text',
                              get = function() return GetInterfaceConfig().minimapTextDifficulty end,
                              set = function(value) GetInterfaceConfig().minimapTextDifficulty = value; MinimapModule.ToggleTextDifficulty(value); MinimapModule.ApplyVisibility() end },
                            { label = 'Mail',
                              get = function() return not GetInterfaceConfig().minimapHideMail end,
                              set = function(value) GetInterfaceConfig().minimapHideMail = not value; MinimapModule.ApplyVisibility() end },
                            { label = 'Crafting Orders',
                              get = function() return not GetInterfaceConfig().minimapHideCrafting end,
                              set = function(value) GetInterfaceConfig().minimapHideCrafting = not value; MinimapModule.ApplyVisibility() end },
                            { label = 'Folio',
                              get = function() return not GetInterfaceConfig().minimapHideGarrison end,
                              set = function(value) GetInterfaceConfig().minimapHideGarrison = not value; MinimapModule.ApplyVisibility() end },
                        },
                    }) }
                end,
            })

            Section('Clock & Zone Text')

            local clockFontDropdown, clockSwatch
            local clockRow = AddRow({
                spanFull = true,
                title = 'Clock',
                description = 'Time display on the map.',
                checked = GetInterfaceConfig().minimapClock and true or false,
                callback = function(value)
                    GetInterfaceConfig().minimapClock = value; MinimapModule.ToggleClock(value); RefreshPreview()
                end,
                accessoryWidth = 244,
                accessories = function(row)
                    local clockMover = PageKit.OffsetMover(row, {
                        min = -300, max = 300, title = 'CLOCK OFFSET', tooltip = 'Clock position offset',
                        getX = function() return GetInterfaceConfig().minimapClockX end,
                        setX = function(value) GetInterfaceConfig().minimapClockX = value; MinimapModule.RefreshClock(); RefreshPreview() end,
                        getY = function() return GetInterfaceConfig().minimapClockY end,
                        setY = function(value) GetInterfaceConfig().minimapClockY = value; MinimapModule.RefreshClock(); RefreshPreview() end,
                    })
                    local clockCog = PageKit.SettingsIcon(row, {
                        title = 'CLOCK', tooltip = 'Clock format & size', onChange = RefreshPreview,
                        options = {
                            { label = '24-Hour Format',
                              get = function() return GetInterfaceConfig().minimapClock24h end,
                              set = function(value) GetInterfaceConfig().minimapClock24h = value; MinimapModule.SetClockFormat(value) end },
                            { label = 'Server Time',
                              get = function() return GetInterfaceConfig().minimapClockServer end,
                              set = function(value) GetInterfaceConfig().minimapClockServer = value; MinimapModule.SetClockSource(value) end },
                            { kind = 'slider', label = 'Size', min = 8, max = 24,
                              get = function() return GetInterfaceConfig().minimapClockSize end,
                              set = function(value) GetInterfaceConfig().minimapClockSize = value; MinimapModule.RefreshClock() end },
                        },
                    })
                    clockFontDropdown = Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems('GLOBAL'), GetInterfaceConfig().minimapClockFont or 'GLOBAL', function(value)
                        GetInterfaceConfig().minimapClockFont = value; MinimapModule.RefreshClock(); RefreshPreview()
                    end, nil, 140)
                    local clockColor = GetInterfaceConfig().minimapClockColor
                    clockSwatch = Controls.ColorSwatch(row, { r = clockColor.r, g = clockColor.g, b = clockColor.b, hasOpacity = false, callback = function(red, green, blue)
                        GetInterfaceConfig().minimapClockColor = { r = red, g = green, b = blue }
                        MinimapModule.RefreshClock(); RefreshPreview()
                    end, tooltip = 'Clock Color' })
                    return { clockMover, clockCog, clockFontDropdown, clockSwatch }
                end,
            })
            AddRefresh(function()
                clockRow:SetValue(GetInterfaceConfig().minimapClock and true or false)
                clockFontDropdown:SetValue(GetInterfaceConfig().minimapClockFont or 'GLOBAL')
                local color = GetInterfaceConfig().minimapClockColor
                clockSwatch:SetColor(color.r, color.g, color.b, 1)
            end)

            local zoneFontDropdown, zoneSwatch
            local zoneRow = AddRow({
                spanFull = true,
                title = 'Zone Text',
                description = 'Zone name on the map.',
                checked = GetInterfaceConfig().minimapZone and true or false,
                callback = function(value)
                    GetInterfaceConfig().minimapZone = value; MinimapModule.ToggleZoneText(value); RefreshPreview()
                end,
                accessoryWidth = 244,
                accessories = function(row)
                    local zoneMover = PageKit.OffsetMover(row, {
                        min = -300, max = 300, title = 'ZONE TEXT OFFSET', tooltip = 'Zone text position offset',
                        getX = function() return GetInterfaceConfig().minimapZoneX end,
                        setX = function(value) GetInterfaceConfig().minimapZoneX = value; MinimapModule.RefreshZoneText(); RefreshPreview() end,
                        getY = function() return GetInterfaceConfig().minimapZoneY end,
                        setY = function(value) GetInterfaceConfig().minimapZoneY = value; MinimapModule.RefreshZoneText(); RefreshPreview() end,
                    })
                    local zoneCog = PageKit.SettingsIcon(row, {
                        title = 'ZONE TEXT', tooltip = 'Zone text size & color', onChange = RefreshPreview,
                        options = {
                            { kind = 'slider', label = 'Size', min = 8, max = 24,
                              get = function() return GetInterfaceConfig().minimapZoneSize end,
                              set = function(value) GetInterfaceConfig().minimapZoneSize = value; MinimapModule.RefreshZoneText() end },
                            { label = 'Custom Zone Color',
                              get = function() return GetInterfaceConfig().minimapZoneColorCustom end,
                              set = function(value) GetInterfaceConfig().minimapZoneColorCustom = value; MinimapModule.RefreshZoneText() end },
                        },
                    })
                    zoneFontDropdown = Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems('GLOBAL'), GetInterfaceConfig().minimapZoneFont or 'GLOBAL', function(value)
                        GetInterfaceConfig().minimapZoneFont = value; MinimapModule.RefreshZoneText(); RefreshPreview()
                    end, nil, 140)
                    local zoneColor = GetInterfaceConfig().minimapZoneColor
                    zoneSwatch = Controls.ColorSwatch(row, { r = zoneColor.r, g = zoneColor.g, b = zoneColor.b, hasOpacity = false, callback = function(red, green, blue)
                        GetInterfaceConfig().minimapZoneColorCustom = true
                        GetInterfaceConfig().minimapZoneColor = { r = red, g = green, b = blue }
                        MinimapModule.RefreshZoneText(); RefreshPreview()
                    end, tooltip = 'Zone Text Color (enables custom color)' })
                    return { zoneMover, zoneCog, zoneFontDropdown, zoneSwatch }
                end,
            })
            AddRefresh(function()
                zoneRow:SetValue(GetInterfaceConfig().minimapZone and true or false)
                zoneFontDropdown:SetValue(GetInterfaceConfig().minimapZoneFont or 'GLOBAL')
                local color = GetInterfaceConfig().minimapZoneColor
                zoneSwatch:SetColor(color.r, color.g, color.b, 1)
            end)

            grid:Flush()
        end

        local function BuildDatatextTab(tab)
            local Datatext = BUI.Datatext
            local function GetDatatextConfig() return Datatext.GetMinimapDB() end
            local function ApplyDatatext() Datatext.Apply() end

            local DT_ANCHORS = {
                { value = 'BOTTOM',        text = 'Bottom'        },
                { value = 'TOP',           text = 'Top'           },
                { value = 'LEFT',          text = 'Left'          },
                { value = 'RIGHT',         text = 'Right'         },
                { value = 'INSIDE_BOTTOM', text = 'Inside Bottom' },
                { value = 'INSIDE_TOP',    text = 'Inside Top'    },
            }

            local grid
            local function Section(title)
                if grid then grid:Flush() end
                Layout.Section(tab, title)
                grid = PageKit.RowGrid(tab)
            end
            local function AddRow(config) return grid:Add(config) end

            Section('Datatext Bar')

            local dtModuleOptions = Datatext.BuildModuleOptions(GetDatatextConfig, ApplyDatatext)

            local dtRow = AddRow({
                spanFull = true,
                title = 'Datatext Bar',
                description = 'Data readouts attached to the minimap, with modules and their order.',
                checked = GetDatatextConfig().enabled ~= false,
                callback = function(value) GetDatatextConfig().enabled = value; ApplyDatatext(); RefreshPreview() end,
                accessoryWidth = 64,
                accessories = function(row)
                    local modulesCog = Controls.Icon(row, {
                        title = 'DISPLAY MODULES', tooltip = 'Modules', texture = BUILib.GetLibMedia('modules5'),
                        options = dtModuleOptions, width = 260, columns = 2,
                    })
                    local orderButton = Controls.Icon(row, {
                        texture = BUILib.GetLibMedia('shuffle'), tooltip = 'Reorder modules',
                        onClick = function(button)
                            Datatext.OpenOrderPopover(button, GetDatatextConfig(), function() ApplyDatatext(); RefreshPreview() end)
                        end,
                    })
                    return { modulesCog, orderButton }
                end,
            })
            AddRefresh(function() dtRow:SetValue(GetDatatextConfig().enabled ~= false) end)

            AddRow({
                title = 'Bar',
                description = 'Anchor, size, and style.',
                plain = true,
                accessoryWidth = 92,
                accessories = function(row)
                    local barMover = PageKit.PositionIcon(row, {
                        title = 'BAR POSITION', tooltip = 'Bar anchor & gap', onChange = RefreshPreview,
                        options = {
                            { kind = 'dropdown', label = 'Anchor', items = DT_ANCHORS,
                              get = function() return GetDatatextConfig().anchor end,
                              set = function(value) GetDatatextConfig().anchor = value; ApplyDatatext() end },
                            { kind = 'slider', label = 'Gap', min = 0, max = 40,
                              get = function() return GetDatatextConfig().gap end,
                              set = function(value) GetDatatextConfig().gap = value; ApplyDatatext() end },
                        },
                    })
                    local barSize = PageKit.SizeIcon(row, {
                        title = 'BAR SIZE', tooltip = 'Bar height & spread', onChange = RefreshPreview,
                        options = {
                            { kind = 'slider', label = 'Height', min = 10, max = 40,
                              get = function() return GetDatatextConfig().height end,
                              set = function(value) GetDatatextConfig().height = value; ApplyDatatext() end },
                            { kind = 'slider', label = 'Spacing (px)', min = 0, max = 40,
                              get = function() return GetDatatextConfig().spacing end,
                              set = function(value)
                                  local config = GetDatatextConfig()
                                  config.spacing, config.spacingPx = value, true
                                  ApplyDatatext()
                              end },
                            { kind = 'slider', label = 'Spread', min = 0, max = 100,
                              get = function() return tonumber(GetDatatextConfig().spread) or 0 end,
                              set = function(value) GetDatatextConfig().spread = value; ApplyDatatext() end },
                        },
                    })
                    local barStyleCog = PageKit.SettingsIcon(row, {
                        title = 'BAR STYLE', tooltip = 'Background & border', onChange = RefreshPreview,
                        options = {
                            { kind = 'slider', label = 'Opacity', min = 0, max = 100,
                              get = function() return floor(GetDatatextConfig().bgAlpha * 100) end,
                              set = function(value) GetDatatextConfig().bgAlpha = value / 100; ApplyDatatext() end,
                              swatch = function()
                                  local backgroundColor = GetDatatextConfig().bgColor
                                  return { r = backgroundColor.r, g = backgroundColor.g, b = backgroundColor.b, callback = function(red, green, blue)
                                      GetDatatextConfig().bgColor = { r = red, g = green, b = blue }; ApplyDatatext()
                                  end, tooltip = 'Background Color' }
                              end },
                            { label = 'Border',
                              get = function() return GetDatatextConfig().border end,
                              set = function(value) GetDatatextConfig().border = value; ApplyDatatext() end,
                              swatch = function()
                                  local borderColor = GetDatatextConfig().borderColor
                                  return { r = borderColor.r, g = borderColor.g, b = borderColor.b, a = borderColor.a, callback = function(red, green, blue, alpha)
                                      GetDatatextConfig().borderColor = { r = red, g = green, b = blue, a = alpha }; ApplyDatatext()
                                  end, tooltip = 'Border Color' }
                              end },
                        },
                    })
                    return { barMover, barSize, barStyleCog }
                end,
            })

            local fontDropdown
            AddRow({
                spanFull = true,
                title = 'Text',
                description = 'Font, size, labels, and value color.',
                plain = true,
                accessoryWidth = 216,
                accessories = function(row)
                    local fontCog = PageKit.SettingsIcon(row, {
                        title = 'TEXT', tooltip = 'Font size & labels', onChange = RefreshPreview,
                        options = {
                            { kind = 'slider', label = 'Font Size', min = 8, max = 24,
                              get = function() return GetDatatextConfig().fontSize end,
                              set = function(value) GetDatatextConfig().fontSize = value; ApplyDatatext() end },
                            { label = 'Hide Labels',
                              get = function() return GetDatatextConfig().hideLabels end,
                              set = function(value) GetDatatextConfig().hideLabels = value; ApplyDatatext() end },
                        },
                    })
                    fontDropdown = Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems('GLOBAL'), GetDatatextConfig().font, function(value)
                        GetDatatextConfig().font = value; ApplyDatatext(); RefreshPreview()
                    end, nil, 140)
                    local color = GetDatatextConfig().colorValue
                    local valueSwatch = Controls.ColorSwatch(row, { r = color.r, g = color.g, b = color.b, a = color.a, callback = function(red, green, blue, alpha)
                        GetDatatextConfig().colorValue = { r = red, g = green, b = blue, a = alpha }; ApplyDatatext()
                    end, tooltip = 'Value Color' })
                    return { fontCog, fontDropdown, valueSwatch }
                end,
            })
            AddRefresh(function() fontDropdown:SetValue(GetDatatextConfig().font) end)

            grid:Flush()
        end

        local function BuildGeneralTab(tab)
            local grid
            local function Section(title)
                if grid then grid:Flush() end
                Layout.Section(tab, title)
                grid = PageKit.RowGrid(tab)
            end
            local function AddRow(config) return grid:Add(config) end

            Section('Drawer & Button')

            local drawerRow
            AddRow({
                title = 'Addon Drawer',
                description = 'Collect addon buttons into a slide-out drawer.',
                checked = GetInterfaceConfig().drawerEnabled and true or false,
                callback = function(value) MinimapModule.ToggleDrawer(value); RefreshPreview() end,
                accessoryWidth = 36,
                accessories = function(row)
                    drawerRow = row
                    return { PageKit.PositionIcon(row, {
                        title = 'DRAWER', tooltip = 'Drawer side & position', onChange = RefreshPreview,
                        options = {
                            { kind = 'dropdown', label = 'Side', items = SIDE_OPTIONS,
                              get = function() return GetInterfaceConfig().drawerSide end,
                              set = function(value) GetInterfaceConfig().drawerSide = value; MinimapModule.SetDrawerSide(value) end },
                            { kind = 'slider', label = 'X Offset', min = -300, max = 300,
                              get = function() return GetInterfaceConfig().drawerX end,
                              set = function(value) GetInterfaceConfig().drawerX = value; MinimapModule.RepositionDrawer() end },
                            { kind = 'slider', label = 'Y Offset', min = -300, max = 300,
                              get = function() return GetInterfaceConfig().drawerY end,
                              set = function(value) GetInterfaceConfig().drawerY = value; MinimapModule.RepositionDrawer() end },
                        },
                    }) }
                end,
            })
            local barRow
            local function ButtonBarConfig() return GetInterfaceConfig().buttonBar end
            local function RefreshButtonBar() MinimapModule.RefreshButtonBar(); RefreshPreview() end
            local function OpenButtonPicker(anchorButton)
                Controls.Popover({
                    anchor = anchorButton, width = 300, height = 240, title = 'BUTTONS, DRAG TO REORDER',
                    build = function(panel)
                        local list
                        list = Controls.ItemList(panel, nil, panel.width, 210, nil, nil, nil, nil, true,
                            function(data)
                                local names = {}
                                for dataIndex = 1, #data do names[dataIndex] = data[dataIndex].id end
                                BUI.MinimapButtonBar.SetOrder(names)
                                RefreshPreview()
                            end,
                            true,
                            { showCheckbox = true, hideID = true, onCheckboxChange = function(id, checked) BUI.MinimapButtonBar.SetIncluded(id, checked); RefreshPreview() end })
                        list:SetPoint('TOPLEFT', 0, 0)
                        local entries = BUI.MinimapButtonBar.PickerEntries()
                        for _, entry in ipairs(entries) do
                            list:AddItem(entry.icon, entry.label, entry.id, false, entry.included)
                        end
                        if #entries == 0 then
                            local empty = panel:CreateFontString(nil, 'OVERLAY')
                            Pixel.ApplyFont(empty, 11, FONT, '')
                            empty:SetPoint('CENTER', panel, 'CENTER', 0, 0)
                            empty:SetTextColor(0.6, 0.6, 0.65, 1)
                            empty:SetText(ButtonBarConfig().enabled and 'No addon minimap buttons found yet.' or 'Turn the Button Bar on to list buttons.')
                        end
                    end,
                })
            end
            AddRow({
                title = 'Button Bar',
                description = 'Addon buttons in a row beside the minimap.',
                checked = ButtonBarConfig().enabled and true or false,
                callback = function(value) ButtonBarConfig().enabled = value; RefreshButtonBar() end,
                accessoryWidth = 64,
                accessories = function(row)
                    barRow = row
                    local pickButton = Controls.Icon(row, {
                        texture = BUILib.GetLibMedia('modules5'), tooltip = 'Pick which buttons sit on the bar and drag them into order',
                        onClick = function(button) OpenButtonPicker(button) end,
                    })
                    local cog = PageKit.SettingsIcon(row, {
                        title = 'BUTTON BAR', tooltip = 'Side, size & spacing',
                        options = {
                            { kind = 'dropdown', label = 'Side', items = SIDE_OPTIONS,
                              get = function() return ButtonBarConfig().side end,
                              set = function(value) ButtonBarConfig().side = value end, apply = RefreshButtonBar },
                            { kind = 'dropdown', label = 'Align', items = ALIGN_OPTIONS,
                              get = function() return ButtonBarConfig().align end,
                              set = function(value) ButtonBarConfig().align = value end, apply = RefreshButtonBar },
                            { kind = 'slider', label = 'Icon Size', min = 12, max = 40,
                              get = function() return ButtonBarConfig().size end,
                              set = function(value) ButtonBarConfig().size = value end, apply = RefreshButtonBar },
                            { kind = 'slider', label = 'Spacing', min = -1, max = 10,
                              get = function() return ButtonBarConfig().spacing end,
                              set = function(value) ButtonBarConfig().spacing = value end, apply = RefreshButtonBar },
                            { kind = 'slider', label = 'Gap From Map', min = 0, max = 10,
                              get = function() return ButtonBarConfig().gap end,
                              set = function(value) ButtonBarConfig().gap = value end, apply = RefreshButtonBar },
                            { kind = 'slider', label = 'Per Line (0 = all)', min = 0, max = 20,
                              get = function() return ButtonBarConfig().perLine end,
                              set = function(value) ButtonBarConfig().perLine = value end, apply = RefreshButtonBar },
                            { kind = 'slider', label = 'X Offset', min = -300, max = 300,
                              get = function() return ButtonBarConfig().offsetX end,
                              set = function(value) ButtonBarConfig().offsetX = value end, apply = RefreshButtonBar },
                            { kind = 'slider', label = 'Y Offset', min = -300, max = 300,
                              get = function() return ButtonBarConfig().offsetY end,
                              set = function(value) ButtonBarConfig().offsetY = value end, apply = RefreshButtonBar },
                            { kind = 'swatch', label = 'Background', hasOpacity = true, tooltip = 'Tile color & opacity behind every icon',
                              get = function() return ButtonBarConfig().background end,
                              set = function(value) ButtonBarConfig().background = value end, apply = RefreshButtonBar },
                        },
                    })
                    return { cog, pickButton }
                end,
            })
            AddRefresh(function() barRow:SetValue(ButtonBarConfig().enabled and true or false) end)
            local minimapButtonRow = AddRow({
                title = 'Hide BluUI Button',
                description = 'Remove the BluUI button from the map.',
                checked = BUI.IsMinimapButtonHidden() and true or false,
                callback = function(value) BUI.SetMinimapButtonHidden(value) end,
            })
            AddRefresh(function() drawerRow:SetValue(GetInterfaceConfig().drawerEnabled and true or false) end)
            AddRefresh(function() if minimapButtonRow then minimapButtonRow:SetValue(BUI.IsMinimapButtonHidden() and true or false) end end)

            grid:Flush()
        end

        local TABS = {
            { key = 'minimap',  title = 'MINIMAP',  image = 'Interface\\Icons\\INV_Misc_Map02',   build = BuildMinimapTab },
            { key = 'datatext', title = 'DATATEXT', image = 'Interface\\Icons\\INV_Misc_Note_02', build = BuildDatatextTab },
            { key = 'general',  title = 'GENERAL',  image = 'Interface\\Icons\\INV_Misc_Gear_01', build = BuildGeneralTab },
        }

        local root, pinned
        root, pinned, titleBar = PageKit.Scaffold(pageFrame, {
            title = 'Minimap', titleDesc = 'Square minimap with indicators, clock, and an addon-button drawer.',
            previewH = PREVIEW_HEIGHT, watermark = BUI.Tools.GetLogo(),
            titleEnable = { value = GetInterfaceConfig().minimapEnabled ~= false, gate = function() return BUI.IsModuleEnabled('minimap') end, onToggle = OnEnableToggle },
            titleAnchor = { value = MinimapModule.IsUnlocked(), onToggle = function(value) MinimapModule.ToggleUnlock(value); RunRefreshers() end,
                tooltip = 'Unlock the minimap to drag it anywhere on screen' },
            hostTabs = {
                defs = TABS, defaultKey = 'minimap',
                build = function(def, tab) def.build(tab) end,
            },
        })

        preview = BuildPreview(pinned, { onLayoutChanged = RunRefreshers })

        MinimapModule.SetLockReleaseCallback(function()
            titleBar.anchorToggle:SetValue(false)
            RunRefreshers()
        end)

        SyncDim()

        pageFrame:SetScript('OnShow', function()
            RunRefreshers()
            SyncDim()
        end)
    end,
})
