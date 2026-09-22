local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Datatext.Order')

local Datatext = BUI.Datatext
local BUILib = LibStub('BUILib')
local Controls = BUILib.Controls

function Datatext.OpenOrderPopover(anchorButton, config, onApply)
    local Theme = BUILib.Theme
    local Widget = BUILib.Widget
    local floor = math.floor
    local order = Datatext.ResolveOrder(config)
    local slotCount = #order
    local POPOVER_WIDTH = 210
    local rowHeight, gap = 26, 4
    local step = rowHeight + gap
    local panelWidth = POPOVER_WIDTH - 12 * 2
    local rowsHeight = slotCount * step - gap
    local resetHeight = 26
    Controls.Popover({
        anchor = anchorButton, width = POPOVER_WIDTH, title = 'MODULE ORDER',
        height = rowsHeight + gap + 8 + resetHeight,
        build = function(panel)
            local items = {}
            local dragSlot
            local closeGuard = false

            local ghostWidget = Widget.New(panel, 'Frame', nil, {
                bg = Theme.bg.hover, border = Theme.border.hover, size = { panelWidth, rowHeight },
            })
            local ghost = ghostWidget.frame
            ghost:SetFrameLevel(panel:GetFrameLevel() + 50)
            ghost:SetAlpha(0.9); ghost:Hide()
            local ghostLabel = ghost:CreateFontString(nil, 'OVERLAY')
            ghostLabel:SetFont(BUILib.GetFont(), 12, '')
            ghostLabel:SetPoint('LEFT', 28, 0)
            ghostLabel:SetTextColor(Theme.text.primary[1], Theme.text.primary[2], Theme.text.primary[3], 1)

            local function Relayout()
                for slot, item in ipairs(items) do
                    item.frame:ClearAllPoints()
                    item.frame:SetPoint('TOPLEFT', 0, -((slot - 1) * step))
                    item.frame:SetPoint('TOPRIGHT', 0, -((slot - 1) * step))
                end
            end

            local function SaveOrder()
                local newOrder = {}
                for slot, item in ipairs(items) do newOrder[slot] = item.id end
                config.order = newOrder
                if onApply then onApply() end
            end

            local function TargetSlot()
                local top = panel:GetTop()
                if not top then return dragSlot end
                local scale = UIParent:GetEffectiveScale()
                local cursorY = select(2, GetCursorPosition()) / scale
                local slot = floor((top - cursorY) / step) + 1
                if slot < 1 then slot = 1 elseif slot > slotCount then slot = slotCount end
                return slot
            end

            local function SetGrip(grip, red, green, blue)
                for _, line in ipairs(grip) do line:SetColorTexture(red, green, blue, 1) end
            end

            for slot = 1, slotCount do
                local id = order[slot]
                local entry = Datatext.Get(id)
                local rowWidget = Widget.New(panel, 'Frame', nil, {
                    bg = Theme.bg.card, border = Theme.border.dark, size = { panelWidth, rowHeight },
                })
                local row = rowWidget.frame
                row:EnableMouse(true)
                row:RegisterForDrag('LeftButton')

                local grip = {}
                for lineIndex = 1, 3 do
                    local line = row:CreateTexture(nil, 'ARTWORK')
                    line:SetColorTexture(0.55, 0.55, 0.58, 1)
                    line:SetSize(11, 2)
                    line:SetPoint('LEFT', 10, (2 - lineIndex) * 4)
                    grip[lineIndex] = line
                end

                local label = row:CreateFontString(nil, 'OVERLAY')
                label:SetFont(BUILib.GetFont(), 12, '')
                label:SetPoint('LEFT', 28, 0)
                label:SetTextColor(Theme.text.primary[1], Theme.text.primary[2], Theme.text.primary[3], 1)
                label:SetText(entry and entry.name or id)

                local item = { frame = row, label = label, grip = grip, id = id }
                items[slot] = item

                SetScript(row, 'OnEnter', function()
                    if dragSlot then return end
                    local accentRed, accentGreen, accentBlue = Theme.GetAccent()
                    row:SetBackdropBorderColor(accentRed, accentGreen, accentBlue, 1)
                    SetGrip(grip, accentRed, accentGreen, accentBlue)
                end)
                SetScript(row, 'OnLeave', function()
                    if dragSlot then return end
                    row:SetBackdropBorderColor(Theme.border.dark[1], Theme.border.dark[2], Theme.border.dark[3], 1)
                    SetGrip(grip, 0.55, 0.55, 0.58)
                end)

                SetScript(row, 'OnDragStart', function()
                    for slotIndex, candidate in ipairs(items) do if candidate == item then dragSlot = slotIndex break end end
                    if not closeGuard then
                        BUILib._popupCount = (BUILib._popupCount or 0) + 1
                        closeGuard = true
                    end
                    ghostLabel:SetText(label:GetText())
                    ghost:Show(); ghost:Raise()
                    row:SetAlpha(0.35)
                    SetScript(row, 'OnUpdate', function()
                        local scale = UIParent:GetEffectiveScale()
                        local cursorX, cursorY = GetCursorPosition()
                        cursorX, cursorY = cursorX / scale, cursorY / scale
                        ghost:ClearAllPoints()
                        ghost:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cursorX, cursorY)
                        local target = TargetSlot()
                        if target and target ~= dragSlot then
                            local moved = table.remove(items, dragSlot)
                            table.insert(items, target, moved)
                            dragSlot = target
                            Relayout()
                        end
                    end)
                end)

                local function EndDrag()
                    if not dragSlot then return end
                    SetScript(row, 'OnUpdate', nil)
                    row:SetAlpha(1)
                    ghost:Hide()
                    dragSlot = nil
                    if closeGuard then
                        BUILib._popupCount = math.max(0, (BUILib._popupCount or 1) - 1)
                        closeGuard = false
                    end
                    Relayout()
                    SaveOrder()
                end
                SetScript(row, 'OnDragStop', EndDrag)
                SetScript(row, 'OnHide', EndDrag)
            end

            Relayout()

            local resetButton = Controls.GhostButton(panel, 'Reset Order', panelWidth, function()
                config.order = nil
                if onApply then onApply() end
                Controls.ClosePopover()
                Datatext.OpenOrderPopover(anchorButton, config, onApply)
            end)
            local resetFrame = Widget.Unwrap(resetButton)
            resetFrame:ClearAllPoints()
            resetFrame:SetPoint('TOPLEFT', 0, -(rowsHeight + gap + 8))
            resetFrame:SetPoint('TOPRIGHT', 0, -(rowsHeight + gap + 8))
            resetFrame:SetHeight(resetHeight)
        end,
    })
end
