local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout, Modals, Toast = BUILib.Controls, BUILib.Layout, BUILib.Modals, BUILib.Toast
local GetLibMedia = LibStub('BUILib').GetLibMedia

local PAGE_WIDTH = 960
local DEFAULT_NAME = 'Default'
local MENU_WIDTH = 260
local NAME_WIDTH = 260
local SWITCH_NAME_WIDTH = 380
local PROFILE_COLUMN = 344
local DROPDOWN_WIDTH = 200
local AVATAR_SIZE = 28
local BUTTON_ROOM = 150
local BOX_HEIGHT = 150
local BOX_INSET = 10
local SECTION_PAD = 24
local HEADER_GAP = 8
local CARDS_GAP = 20
local CARD_GAP = 16
local CARD_RADIUS = 8
local CARD_PAD = 16
local CARD_TEXT_GAP = 6
local CARD_BOX_GAP = 12
local READOUT_GAP = 10
local FOOTER_GAP = 14
local FOOTER_Y = 16
local BUTTON_GAP = 10
local CONTROL_HEIGHT = 30
local SCROLL_STEP = 40
local DIM_ALPHA = 0.4

local RAIL_GROUPS = {
    { title = 'Manage', items = {
        { id = 'profiles', label = 'Profiles', icon = 'profile' },
        { id = 'transfer', label = 'Export and import', icon = 'copy' },
    } },
    { title = 'Automation', items = {
        { id = 'specs', label = 'Spec profiles', icon = 'shuffle' },
    } },
}
local PANE_IDS = { 'profiles', 'transfer', 'specs' }
local PANE_INDEX = {}
for index, id in ipairs(PANE_IDS) do PANE_INDEX[id] = index end

local function Window()
    return BUI.PageEngine.window
end

local function AceDB()
    return BUI.GetAceDB()
end

local function Trim(text)
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function ToastOptions()
    return { style = 'bar', position = 'bottom', parent = Window().frame }
end

local function Notify(title, message)
    Toast.Success(title, message, ToastOptions())
end

local function Warn(title, message)
    Toast.Error(title, message, ToastOptions())
end

local function ReclaimScratch()
    collectgarbage('collect')
end

local function Plural(count, noun)
    return count .. ' ' .. noun .. (count == 1 and '' or 's')
end

local function ProfileUsage(profileName)
    local myKey = BUI.db.keys.char
    local count, isMine = 0, false
    for charKey, value in pairs(BUI.db.sv.profileKeys) do
        if value == profileName then
            count = count + 1
            if charKey == myKey then isMine = true end
        end
    end
    return count, isMine
end

local function UsageText(count, isMine)
    if isMine then
        if count == 1 then return 'This character only' end
        return 'This character and ' .. Plural(count - 1, 'other')
    end
    if count == 0 then return 'Not used by any character' end
    return 'Used by ' .. Plural(count, 'character')
end

local function SpecsUsing(profileName)
    local SpecProfiles = BUI.SpecProfiles
    if not SpecProfiles.IsEnabled() then return nil end
    local names
    for _, spec in ipairs(SpecProfiles.GetPlayerSpecs()) do
        if SpecProfiles.GetProfileForSpec(spec.id) == profileName then
            names = names and (names .. ', ' .. spec.name) or spec.name
        end
    end
    return names
end

local function DescribeProfile(profileName)
    local text = UsageText(ProfileUsage(profileName))
    local specs = SpecsUsing(profileName)
    if specs then text = text .. ', paired with ' .. specs end
    return text
end

local function ForEachSpecMap(callback)
    for _, data in pairs(BUI.db.sv.char) do
        local store = type(data) == 'table' and data.specProfiles
        if type(store) == 'table' and type(store.map) == 'table' then callback(store.map) end
    end
end

local function RepointReferences(oldName, newName, charKeys)
    local keys = BUI.db.sv.profileKeys
    for _, charKey in ipairs(charKeys) do keys[charKey] = newName end
    if BUI.db.global.defaultProfile == oldName then
        BUI.db.global.defaultProfile = newName
    end
    ForEachSpecMap(function(map)
        for specID, value in pairs(map) do
            if value == oldName then map[specID] = newName end
        end
    end)
end

local function DropReferences(profileName)
    if BUI.db.global.defaultProfile == profileName then
        BUI.db.global.defaultProfile = nil
    end
    ForEachSpecMap(function(map)
        for specID, value in pairs(map) do
            if value == profileName then map[specID] = nil end
        end
    end)
end

local function SortedProfiles()
    local names = {}
    for _, name in pairs(AceDB():GetProfiles()) do names[#names + 1] = name end
    table.sort(names, function(first, second) return first:lower() < second:lower() end)
    return names
end

local function Exists(name)
    for _, existing in pairs(AceDB():GetProfiles()) do
        if existing == name then return true end
    end
    return false
end

local function RebuildPage()
    BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function RebuildAllPages()
    BUILib.Defer(function() BUI.PageEngine.RebuildAllPages() end)
end

local function SwitchTo(name)
    AceDB():SetProfile(name)
    Notify('Now using "' .. name .. '"', DescribeProfile(name))
end

local function RequestSwitch(name)
    if name == AceDB():GetCurrentProfile() then return end
    if BUI.SpecProfiles.IsEnabled() then
        Modals.Confirm({
            title = 'Spec Profiles Are On',
            message = 'This character picks its profile from your specialization.\n\nSwitching to "' .. name ..
                '" works now, but the next spec change will override it.',
            confirmText = 'Switch Anyway', cancelText = 'Cancel',
            onConfirm = function() SwitchTo(name) end,
        })
        return
    end
    SwitchTo(name)
end

local function CreateProfile(name, copyFrom, switchToIt)
    local aceDB = AceDB()
    local previous = aceDB:GetCurrentProfile()
    BUI._suppressProfileCallback = true
    aceDB:SetProfile(name)
    if copyFrom and copyFrom ~= name then aceDB:CopyProfile(copyFrom, true) else BUI.ExportImport.ApplyDefaultProfile(BUI.GetDB()) end
    BUI.MigrateProfile(BUI.GetDB())
    if not switchToIt and previous ~= name then aceDB:SetProfile(previous) end
    BUI._suppressProfileCallback = nil
    BUI.ExportImport.RefreshAllModules()
    RebuildAllPages()
end

local function RenameProfile(oldName, newName)
    local aceDB = AceDB()
    local affected = {}
    for charKey, value in pairs(aceDB.sv.profileKeys) do
        if value == oldName then affected[#affected + 1] = charKey end
    end
    local previous = aceDB:GetCurrentProfile()
    BUI._suppressProfileCallback = true
    aceDB:SetProfile(newName)
    aceDB:CopyProfile(oldName, true)
    if previous ~= oldName then aceDB:SetProfile(previous) end
    aceDB:DeleteProfile(oldName, true)
    RepointReferences(oldName, newName, affected)
    BUI._suppressProfileCallback = nil
    Notify('Renamed to "' .. newName .. '"', 'Was "' .. oldName .. '"')
    BUI.ExportImport.RefreshAllModules()
    RebuildAllPages()
end

local function DeleteProfile(name)
    AceDB():DeleteProfile(name, true)
    DropReferences(name)
    Notify('Deleted "' .. name .. '"', 'Characters that used it fall back to Default')
    RebuildPage()
end

local function UseEverywhere(name)
    local aceDB = AceDB()
    for charKey in pairs(aceDB.sv.profileKeys) do aceDB.sv.profileKeys[charKey] = name end
    aceDB.global.defaultProfile = name
    Notify('"' .. name .. '" set on every character', 'New characters will start on it too')
    RebuildPage()
end

local function PromptName(config)
    Modals.Input({
        title = config.title,
        message = config.message,
        defaultText = config.defaultText,
        confirmText = config.confirmText,
        cancelText = 'Cancel',
        onConfirm = function(text)
            local name = Trim(text)
            if name == '' or name == config.unchanged then return end
            if Exists(name) then
                Warn('Name already taken', 'A profile called "' .. name .. '" already exists.')
                return
            end
            config.onName(name)
        end,
    })
end

local function OpenMenu(items, anchorFrame)
    Controls.ContextMenu(items, {
        width = MENU_WIDTH, anchor = anchorFrame, window = Window(),
        point = 'TOPRIGHT', relPt = 'BOTTOMRIGHT', offsetY = -4,
    })
end

local function OpenPicker(anchorFrame, config)
    local items = { { text = config.title, title = true } }
    for _, name in ipairs(SortedProfiles()) do
        if config.include(name) then
            items[#items + 1] = { text = name, callback = function() config.onPick(name) end }
        end
    end
    if #items == 1 then
        items[#items + 1] = { text = config.emptyText, disabled = true }
    end
    OpenMenu(items, anchorFrame)
end

local function OpenNewMenu(anchorFrame)
    local current = AceDB():GetCurrentProfile()
    OpenMenu({
        { text = 'Create A Profile', title = true },
        { text = 'Empty profile', callback = function()
            PromptName({
                title = 'New Profile',
                message = 'Starts from BluUI defaults.',
                defaultText = '', confirmText = 'Create',
                onName = function(name)
                    CreateProfile(name, nil, true)
                    Notify('Now using "' .. name .. '"', 'Started from BluUI defaults')
                end,
            })
        end },
        { text = 'Copy of "' .. current .. '"', callback = function()
            PromptName({
                title = 'New Profile',
                message = 'Starts as a copy of "' .. current .. '".',
                defaultText = current .. ' Copy', confirmText = 'Create',
                onName = function(name)
                    CreateProfile(name, current, true)
                    Notify('Now using "' .. name .. '"', 'Copied from "' .. current .. '"')
                end,
            })
        end },
    }, anchorFrame)
end

local function OpenProfileMenu(name, anchorFrame)
    local isActive = name == AceDB():GetCurrentProfile()
    local isDefault = name == DEFAULT_NAME
    local items = { { text = name, title = true } }
    local function Add(item) items[#items + 1] = item end

    if not isActive then
        Add({ text = 'Use on this character', callback = function() RequestSwitch(name) end })
    end

    Add({ text = 'Duplicate...', callback = function()
        PromptName({
            title = 'Duplicate Profile',
            message = 'Name the copy of "' .. name .. '".',
            defaultText = name .. ' Copy', confirmText = 'Create',
            onName = function(newName)
                CreateProfile(newName, name, false)
                Notify('Created "' .. newName .. '"', 'Copy of "' .. name .. '"')
            end,
        })
    end })

    Add({ text = 'Rename...', disabled = isDefault, sub = isDefault and 'locked' or nil, callback = function()
        PromptName({
            title = 'Rename Profile',
            message = 'New name for "' .. name .. '".',
            defaultText = name, confirmText = 'Rename', unchanged = name,
            onName = function(newName) RenameProfile(name, newName) end,
        })
    end })

    if isActive then
        Add({ text = 'Reset to defaults', callback = function()
            Modals.Confirm({
                title = 'Reset Profile',
                message = 'Put every setting in "' .. name .. '" back to BluUI defaults?\n\nThis cannot be undone.',
                confirmText = 'Reset', cancelText = 'Cancel',
                onConfirm = function()
                    AceDB():ResetProfile()
                    Notify('Reset "' .. name .. '"', 'Back to BluUI defaults')
                end,
            })
        end })

        Add({ text = 'Copy another profile in...', callback = function()
            BUILib.Defer(function()
                OpenPicker(anchorFrame, {
                    title = 'COPY INTO ' .. name:upper(),
                    emptyText = 'No other profiles',
                    include = function(other) return other ~= name end,
                    onPick = function(other)
                        Modals.Confirm({
                            title = 'Copy Settings',
                            message = 'Replace everything in "' .. name .. '" with the settings from "' .. other ..
                                '"?\n\n"' .. other .. '" itself is left alone.',
                            confirmText = 'Copy', cancelText = 'Cancel',
                            onConfirm = function()
                                AceDB():CopyProfile(other, true)
                                Notify('Copied "' .. other .. '"', 'Into "' .. name .. '"')
                            end,
                        })
                    end,
                })
            end)
        end })
    end

    Add({ text = 'Use on every character', callback = function()
        Modals.Confirm({
            title = 'Use Everywhere',
            message = 'Put all of your characters on "' .. name ..
                '", including ones you create later?\n\nTo undo this, set each character back by hand.',
            confirmText = 'Apply', cancelText = 'Cancel',
            onConfirm = function() UseEverywhere(name) end,
        })
    end })

    Add({ separator = true })

    local blocked = isActive and 'in use' or (isDefault and 'locked' or nil)
    Add({ text = '|cffff6060Delete...|r', disabled = blocked ~= nil, sub = blocked, callback = function()
        Modals.Confirm({
            title = 'Delete Profile',
            message = 'Delete "' .. name .. '" and every setting stored in it?\n\nThis cannot be undone.',
            confirmText = 'Delete', cancelText = 'Cancel',
            onConfirm = function() DeleteProfile(name) end,
        })
    end })

    OpenMenu(items, anchorFrame)
end

local function ProfileCards()
    local current = AceDB():GetCurrentProfile()
    local cards = {}
    for _, name in ipairs(SortedProfiles()) do
        local specs = SpecsUsing(name)
        cards[#cards + 1] = {
            name = name,
            sub = UsageText(ProfileUsage(name)),
            note = specs and ('Paired with ' .. specs) or (name == DEFAULT_NAME and 'Built in, cannot be removed' or nil),
            active = name == current,
            activeText = 'Active',
            useText = 'Use',
            menuTip = 'More',
            onUse = name ~= current and function() RequestSwitch(name) end or nil,
            onMenu = function(anchor) OpenProfileMenu(name, anchor) end,
        }
    end
    return cards
end

local function SpecSection(ui, shell, parent, width)
    local SpecProfiles = BUI.SpecProfiles
    local specs = SpecProfiles.GetPlayerSpecs()
    if #specs == 0 then return nil end

    local section = ui.Section(parent, width, {
        stacked = true,
        title = 'Spec profiles',
        description = 'Let the specialization choose the profile. Changing spec loads the profile paired with it.',
        columns = { { 'Specialization', ui.AVATAR_X }, { 'Profile', PROFILE_COLUMN } },
    })

    local row = section:AddRow('switch profile with spec')
    ui.RowTitle(row, 'Switch profile with spec', 'Off keeps whichever profile you picked by hand', ui.ROW_INSET, SWITCH_NAME_WIDTH)
    ui.Switch(row, SpecProfiles.IsEnabled, function(value)
        SpecProfiles.SetEnabled(value)
        shell.window:Repaint()
    end):SetPoint('RIGHT', -ui.ROW_INSET, 0)

    for _, spec in ipairs(specs) do
        local specRow = section:AddRow(spec.name)
        local icon = specRow:CreateTexture(nil, 'ARTWORK')
        icon:SetSize(AVATAR_SIZE, AVATAR_SIZE)
        icon:SetPoint('LEFT', ui.AVATAR_X, 0)
        icon:SetTexture(spec.icon)
        icon:SetMask(GetLibMedia('circle_mask'))
        ui.RowTitle(specRow, spec.name, 'Loaded whenever you play ' .. spec.name, ui.NAME_X, NAME_WIDTH)
        local dropdown = ui.Dropdown(specRow, DROPDOWN_WIDTH, function()
            local paired = SpecProfiles.GetProfileForSpec(spec.id) or AceDB():GetCurrentProfile()
            local items = {}
            for _, name in ipairs(SortedProfiles()) do
                items[#items + 1] = { text = name, checked = name == paired, callback = function()
                    SpecProfiles.SetSpecProfile(spec.id, name)
                    shell.window:Repaint()
                end }
            end
            return items
        end)
        dropdown:SetPoint('LEFT', PROFILE_COLUMN, 0)
        ui.Bind(specRow, function()
            specRow:SetAlpha(SpecProfiles.IsEnabled() and 1 or DIM_ALPHA)
            dropdown.label:SetText(SpecProfiles.GetProfileForSpec(spec.id) or AceDB():GetCurrentProfile())
        end)
    end
    return section
end

local function ScrollBox(ui, shell, parent, hintText)
    local window = shell.window
    local box = CreateFrame('Frame', nil, parent)
    box:SetHeight(BOX_HEIGHT)
    box:EnableMouse(true)
    ui.Box(box, 'textbox', 'inputEdge')

    local scroll = CreateFrame('ScrollFrame', nil, box)
    scroll:SetPoint('TOPLEFT', BOX_INSET, -BOX_INSET)
    scroll:SetPoint('BOTTOMRIGHT', -BOX_INSET, BOX_INSET)

    local edit = CreateFrame('EditBox', nil, scroll)
    edit:SetMultiLine(true)
    edit:SetMaxLetters(0)
    edit:SetAutoFocus(false)
    edit:SetFont(window.font, 11, '')
    window:Paint(edit, 'text')
    window:SetFontRole(edit, 'control')
    edit:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    edit:SetScript('OnTextChanged', function(self) ScrollingEdit_OnTextChanged(self, scroll) end)
    edit:SetScript('OnCursorChanged', ScrollingEdit_OnCursorChanged)
    scroll:SetScrollChild(edit)
    scroll:SetScript('OnSizeChanged', function(_, scrollWidth) edit:SetWidth(scrollWidth) end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel', function(self, delta)
        local range = math.max(0, edit:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * SCROLL_STEP)))
    end)
    box:SetScript('OnMouseDown', function() edit:SetFocus() end)

    local hint = ui.Text(box, hintText, 11, 'faint')
    hint:SetPoint('TOPLEFT', BOX_INSET + 2, -BOX_INSET)
    edit:HookScript('OnTextChanged', function(self) hint:SetShown(self:GetText() == '') end)
    box.edit = edit
    return box
end

local function TransferCard(ui, shell, parent, width, spec)
    local window = shell.window
    local Widget = BUILib.Widget
    local card = CreateFrame('Frame', nil, parent)
    card:SetWidth(width)
    local fill, edge = Widget.DrawCardShape(card, CARD_RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
    window:Paint(fill, 'card')
    window:Paint(edge, 'cardEdge')

    local title = ui.Text(card, spec.title, 14, 'text')
    title:SetPoint('TOPLEFT', CARD_PAD, -CARD_PAD)
    local description = ui.Text(card, spec.description, 11, 'muted', width - CARD_PAD * 2)
    description:SetSpacing(3)
    description:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -CARD_TEXT_GAP)
    local boxTop = CARD_PAD + ui.Height(title) + CARD_TEXT_GAP + ui.Height(description) + CARD_BOX_GAP

    local box = ScrollBox(ui, shell, card, spec.hint)
    box:SetPoint('TOPLEFT', CARD_PAD, -boxTop)
    box:SetPoint('TOPRIGHT', -CARD_PAD, -boxTop)

    local readoutTop = boxTop + BOX_HEIGHT + READOUT_GAP
    local readout = ui.Text(card, spec.readout, 11, 'faint')
    readout:SetWordWrap(false)
    readout:SetPoint('TOPLEFT', CARD_PAD, -readoutTop)
    readout:SetPoint('TOPRIGHT', -CARD_PAD, -readoutTop)

    local previous
    for index = #spec.buttons, 1, -1 do
        local buttonSpec = spec.buttons[index]
        local button = ui.Button(card, buttonSpec.text, buttonSpec.style, buttonSpec.onClick, buttonSpec.icon)
        if previous then
            button:SetPoint('RIGHT', previous, 'LEFT', -BUTTON_GAP, 0)
        else
            button:SetPoint('BOTTOMRIGHT', -CARD_PAD, FOOTER_Y)
        end
        previous = button
    end

    card:SetHeight(readoutTop + ui.Height(readout) + FOOTER_GAP + CONTROL_HEIGHT + FOOTER_Y)
    return {
        frame = card,
        edit = box.edit,
        SetReadout = function(text, role)
            readout:SetText(text)
            window:Paint(readout, role)
        end,
    }
end

local function SummarizeImport(text)
    if Trim(text) == '' then return 'Nothing pasted yet', 'faint' end
    local data = BUI.ExportImport.DecodeImportString(text)
    if not data then return 'Not a BluUI profile string', 'faint' end
    local sections = 0
    for key in pairs(data) do
        if type(key) == 'string' and not key:match('^_') then sections = sections + 1 end
    end
    return ('Profile "%s" from v%s, %s'):format(tostring(data._profileName or '?'), tostring(data._version or '?'), Plural(sections, 'section')), 'text'
end

local function TransferSection(ui, shell, parent, width)
    local block = CreateFrame('Frame', nil, parent)
    block:SetWidth(width)
    local title = ui.Text(block, 'Export and import', 13, 'text')
    title:SetPoint('TOPLEFT', 0, -(SECTION_PAD + 2))
    local description = ui.Text(block, 'Profiles travel as text. Export the active profile to hand it to someone, or paste a string to bring one in and pick the sections you want before anything changes.', 12, 'muted', width)
    description:SetSpacing(4)
    description:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -HEADER_GAP)
    local top = SECTION_PAD + 2 + ui.Height(title) + HEADER_GAP + ui.Height(description) + CARDS_GAP
    local cardWidth = math.floor((width - CARD_GAP) / 2)

    local exportCard, importCard
    local showingListing = false

    local function DoImport(importString, forceOverwrite)
        local outcome, result, data = BUI.ExportImport.ImportSettings(importString, forceOverwrite)
        if outcome == 'conflict' then
            Modals.Confirm({
                title = 'Profile Exists',
                message = 'You already have a profile called "' .. result .. '".\n\nOverwrite it with the pasted one?',
                confirmText = 'Overwrite', cancelText = 'Cancel',
                onConfirm = function() DoImport(importString, true) end,
            })
        elseif outcome == 'chooser' then
            BUI.ExportImport.StartImport(data, result)
        else
            Warn('Import failed', result or 'That string could not be read.')
        end
    end

    exportCard = TransferCard(ui, shell, block, cardWidth, {
        title = 'Export',
        description = 'Writes the active profile as text. Copy it with Ctrl+C and send it anywhere.',
        hint = 'Press Export to fill this box.',
        readout = 'Nothing exported yet',
        buttons = { { text = 'Export', style = 'primary', icon = 'copy', onClick = function()
            local exportString, profileName = BUI.ExportImport.ExportSettings()
            if not exportString then
                Warn('Export failed', profileName or 'Profile data not found.')
                return
            end
            local edit = exportCard.edit
            edit:SetText(exportString)
            edit:SetCursorPosition(0)
            edit:SetFocus()
            edit:HighlightText()
            exportCard.SetReadout(('%s, %.1f KB'):format(profileName, #exportString / 1024), 'text')
            ReclaimScratch()
            Notify('Exported "' .. profileName .. '"', 'Press Ctrl+C to copy it')
        end } },
    })
    exportCard.frame:SetPoint('TOPLEFT', 0, -top)

    importCard = TransferCard(ui, shell, block, cardWidth, {
        title = 'Import',
        description = 'Paste a profile string. Nothing changes until you pick which sections to take.',
        hint = 'Paste a profile string here.',
        readout = 'Nothing pasted yet',
        buttons = {
            { text = 'Clear', onClick = function() importCard.edit:SetText('') end },
            { text = 'Inspect', onClick = function()
                local text, errorMessage = BUI.ImportInspector.Inspect(importCard.edit:GetText())
                if not text then
                    Warn('Could not read that string', errorMessage or 'It is not a BluUI profile string.')
                    return
                end
                showingListing = true
                importCard.edit:SetText(text)
                importCard.edit:SetCursorPosition(0)
                importCard.SetReadout('Readable listing, paste the string again to import it', 'faint')
                ReclaimScratch()
            end },
            { text = 'Import', style = 'primary', onClick = function()
                local importString = importCard.edit:GetText()
                if Trim(importString) == '' then
                    Warn('Nothing to import', 'Paste a profile string into the box first.')
                    return
                end
                DoImport(importString, false)
                ReclaimScratch()
            end },
        },
    })
    importCard.frame:SetPoint('TOPLEFT', cardWidth + CARD_GAP, -top)
    importCard.edit:HookScript('OnTextChanged', function(self)
        if showingListing then
            showingListing = false
            return
        end
        importCard.SetReadout(SummarizeImport(self:GetText()))
    end)

    local rule = ui.DottedRule(block)
    rule:SetPoint('BOTTOMLEFT')
    rule:SetPoint('BOTTOMRIGHT')
    block:SetHeight(top + math.max(exportCard.frame:GetHeight(), importCard.frame:GetHeight()) + SECTION_PAD + 1)
    return block
end

local function OtherAddonsSection(ui, parent, width)
    local azorInstalled = C_AddOns.DoesAddOnExist('AzortharionUI')
    local azorPending = type(AzortharionUI_DB) == 'table'
        or (BluUI_DB.__azorImportDeclined and not (BluUI_DB.__adoptedLegacySettings or BluUI_DB.__adoptedLegacySettings_v2))
    local platynator = Platynator and Platynator.API and Platynator.API.ImportString
    if not azorInstalled and not azorPending and not platynator then return nil end

    local board = ui.Board(parent, width, {
        stacked = true,
        title = 'Other addons',
        description = 'Bring an older setup across, or hand the BluUI nameplate profile to Platynator.',
    })
    local function Action(name, sub, text, onClick)
        local row = board:AddRow(name, sub, BUTTON_ROOM)
        ui.Button(row, text, 'control', onClick):SetPoint('RIGHT', -ui.ROW_INSET, 0)
    end
    if azorInstalled then
        Action('AzortharionUI profiles', 'Replaces every BluUI profile with a fresh copy of your AzortharionUI ones, then reloads', 'Copy and reload', function()
            Modals.Confirm({
                title = 'Copy AzortharionUI Profiles',
                message = 'Replace ALL BluUI profiles with your current AzortharionUI profiles?\n\nThe UI will reload.',
                confirmText = 'Copy & Reload', cancelText = 'Cancel',
                onConfirm = BUI.ImportAzorProfiles,
            })
        end)
    elseif azorPending then
        board:AddRow('AzortharionUI profiles', 'AzortharionUI is uninstalled. Reinstall it to import.')
    end
    if platynator then
        Action('Platynator nameplates', 'Adds the BluUI profile to Platynator. Updated ' .. BUI.PlatynatorProfileDate .. '.', 'Import', BUI.ImportPlatynatorProfile)
    end
    return board
end

local function Panes(ui, shell, parent, width, item)
    local sections = {}
    if item.id == 'profiles' then
        sections[1] = ui.Deck(parent, width, {
            title = 'Profiles',
            description = 'A profile is one complete set of BluUI settings. Every character uses one at a time.',
            cards = ProfileCards(),
            blank = { label = 'New profile', sub = 'Empty, or a copy of the active one', onClick = OpenNewMenu },
        })
    elseif item.id == 'transfer' then
        sections[#sections + 1] = TransferSection(ui, shell, parent, width)
        sections[#sections + 1] = OtherAddonsSection(ui, parent, width)
    else
        sections[#sections + 1] = SpecSection(ui, shell, parent, width)
    end
    return sections
end

BUI.PageEngine.RegisterPage('exportimport', {
    title = 'Profiles',
    buttonText = 'Profiles',
    icon = 'profile',
    OnBuild = function(pageFrame)
        local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
        local adapter = { tabContents = {}, currentTab = 1 }
        for index in ipairs(PANE_IDS) do adapter.tabContents[index] = {} end
        local rail
        rail = Layout.RailPage(page:GetTab(1), { window = Window() }, {
            icon = 'profile',
            title = 'Profiles',
            placeholder = 'Search profiles...',
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
        page:AutoRefresh()
    end,
})
