local _, BUI = ...

local Wrap = BUI.Profiler.Wrap

local pairs, ipairs = pairs, ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme

local LIST_TITLE_SCALE = 1.4
local SECTION_TITLE_SCALE = 1.2
local ROW_SELECTED_ALPHA = 0.2
local ROW_HOVER_ALPHA = 0.06
local BINDING_SELECTED_ALPHA = 0.3
local CHECK_INSET = 4
local LARGE_CHECK_INSET = 6
local SEGMENT_PAD = 2
local LAYOUT_NAME_INSET = { left = -5, right = -5, top = 6, bottom = 6 }
local IMPORT_NAME_INSET = { right = -10, top = 6, bottom = 6 }
local NAME_TEXT_PAD = 6
local NAME_LOCKED_HINT = 'Paste a valid layout string first'
local LABEL_GAP = 4
local ARROW_EXPANDED = 0
local ARROW_COLLAPSED = math.pi / 2
local GRAY_MATCH = 0.02
local CATEGORY_ACTIVE_ATLAS = 'Options_List_Active'
local CATEGORY_HOVER_ATLAS = 'Options_List_Hover'
local SETTINGS_TAB_KEYS = { 'GameTab', 'AddOnsTab' }
local QUALITY_TAB_KEYS = { 'BaseTab', 'RaidTab' }
local QUALITY_GROUP_KEYS = { 'BaseQualityControls', 'RaidQualityControls' }
local SETTINGS_BUTTON_KEYS = { 'ApplyButton', 'CloseButton' }
local SLIDER_TEXT_KEYS = { 'LeftText', 'RightText', 'TopText', 'MinText', 'MaxText' }
local BINDING_BUTTON_KEYS = { 'Button1', 'Button2', 'CustomButton' }
local ROW_BUTTON_KEYS = { 'Button1', 'Button2', 'PushToTalkKeybindButton', 'ToggleTest' }
local EDIT_MODE_CHECK_KEYS = { 'ShowGridCheckButton', 'EnableSnapCheckButton', 'EnableAdvancedOptionsCheckButton' }
local EDIT_MODE_TITLE_KEYS = { 'FramesTitle', 'CombatTitle', 'MiscTitle' }
local EDIT_MODE_LABEL_KEYS = { 'EditBoxLabel', 'NameEditBoxLabel' }
local LAYOUT_DIALOGS = { 'EditModeLayoutDialog', 'EditModeImportLayoutDialog', 'EditModeImportLayoutLinkDialog', 'CooldownViewerLayoutDialog', 'CooldownViewerImportLayoutDialog' }
local UNSAVED_BUTTON_KEYS = { 'SaveAndProceedButton', 'ProceedButton', 'CancelButton' }
local MACRO_BUTTON_NAMES = { 'MacroEditButton', 'MacroSaveButton', 'MacroCancelButton', 'MacroDeleteButton', 'MacroNewButton', 'MacroExitButton' }
local MACRO_TAB_COUNT = 2
local ADDON_BUTTON_KEYS = { 'EnableAllButton', 'DisableAllButton', 'OkayButton', 'CancelButton' }
local PERFORMANCE_TEXT_KEYS = { 'Current', 'Average', 'Peak' }
local QUICK_KEYBIND_TEXT_KEYS = { 'InstructionText', 'CancelDescriptionText', 'OutputText' }
local QUICK_KEYBIND_BUTTON_KEYS = { 'DefaultsButton', 'CancelButton', 'OkayButton' }
local STATE_TEXTURE_GETTERS = { 'GetNormalTexture', 'GetPushedTexture', 'GetHighlightTexture', 'GetDisabledTexture' }

local context = Skin.Define('systempanels', {
	name = 'Settings & Editors',
	description = 'The game settings window, Edit Mode manager and dialogs, quick keybinding, macro editor and addon list: segmented tabs, left titles, house controls, flat sliders and clean list rows.',
	icon = 'Interface/Icons/INV_Misc_Gear_01',
	newLook = true,
})
local Hook = context.Hook
local Fade, FadeRegions, FadeArt = context.Fade, context.FadeRegions, context.FadeArt
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local TextBox, ScrollBar, Face, Title, Body = context.TextBox, context.ScrollBar, context.Face, context.Title, context.Body
local FlatTexture, AccentTexture, RowHighlight = Skin.FlatTexture, Skin.AccentTexture, Skin.RowHighlight

local lockHints = {}

local function Refade(texture)
	Fade(texture)
	texture:SetAlpha(0)
end

local function FadeButtonStates(button)
	for _, getter in ipairs(STATE_TEXTURE_GETTERS) do
		local texture = button[getter](button)
		if texture then Refade(texture) end
	end
end

local function FaceRegions(frame)
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region:IsObjectType('FontString') then Skin.TipFace(region, 'body') end
	end
end

local function ReplaceDivider(texture, parent)
	Refade(texture)
	if texture._buiLine then return end
	local line = parent:CreateTexture(nil, 'ARTWORK')
	line.__buiSkin = true
	line:SetHeight(1)
	BUI.Painter.Fill(line, 'skinBorder')
	BUILib.Skin.PixelLine(line, texture)
	texture._buiLine = line
end

local function ReplaceDividerRegions(frame)
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region:IsObjectType('Texture') and not region.__buiSkin then ReplaceDivider(region, frame) end
	end
end

local function SetArrowRotation(button, expanded)
	local arrow = button._buiTipArrow
	if arrow then arrow:SetRotation(expanded and ARROW_EXPANDED or ARROW_COLLAPSED) end
end

local function StyleStepper(button, direction)
	Skin.TipStepper(button, direction)
	FadeRegions(button)
end

local function StyleSliderTrack(slider)
	if slider._buiTrack then return end
	local thumb = slider.Thumb or slider:GetThumbTexture()
	for regionIndex = 1, select('#', slider:GetRegions()) do
		local region = select(regionIndex, slider:GetRegions())
		if region ~= thumb and region:IsObjectType('Texture') and not region.__buiSkin then Fade(region) end
	end
	Skin.TipSliderTrack(slider)
end

local function StyleStepSlider(stepper)
	if not stepper then return end
	StyleSliderTrack(stepper.Slider)
	StyleStepper(stepper.Back, 'previous')
	StyleStepper(stepper.Forward, 'next')
	for _, key in ipairs(SLIDER_TEXT_KEYS) do Face(stepper[key]) end
end

local function StyleDropdownControl(control)
	if not control then return end
	if control.SetupMenu then
		Dropdown(control)
		return
	end
	Dropdown(control.Dropdown)
	StyleStepper(control.DecrementButton, 'previous')
	StyleStepper(control.IncrementButton, 'next')
	Face(control.Label)
end

local function StyleLabeledCheck(holder, inset)
	CheckBox(holder.Button, inset)
	Face(holder.Label)
end

local function PaintMinimalTab(tab)
	local selected = tab:IsSelected()
	Skin.SetSegmentSelected(tab, selected)
	Skin.SegmentText(tab.Text, selected or tab.over)
	tab.Text:ClearAllPoints()
	tab.Text:SetPoint('CENTER')
end

local function SegmentMinimalTabs(owner, keys)
	local first, last = owner[keys[1]], owner[keys[#keys]]
	for _, key in ipairs(keys) do
		local tab = owner[key]
		Skin.SegmentButton(tab)
		if not tab._buiSegmentHook then
			tab._buiSegmentHook = true
			Hook(tab, 'OnSelected', PaintMinimalTab)
			local repaint = Wrap('Skin.SystemPanels tab hover', context.Guard(PaintMinimalTab))
			tab:HookScript('OnEnter', repaint)
			tab:HookScript('OnLeave', repaint)
		end
		PaintMinimalTab(tab)
	end
	local strip = first._buiStrip
	if not strip then
		strip = CreateFrame('Frame', nil, first:GetParent())
		strip:SetPoint('TOPLEFT', first, 'TOPLEFT', -SEGMENT_PAD, SEGMENT_PAD)
		strip:SetPoint('BOTTOMRIGHT', last, 'BOTTOMRIGHT', SEGMENT_PAD, -SEGMENT_PAD)
		strip:SetFrameLevel(math.max(0, first:GetFrameLevel() - 1))
		first._buiStrip = strip
	end
	Shell(strip)
end

local function RefreshCategoryState(button)
	local texture = button.Texture
	if not texture:IsShown() then return end
	local atlas = texture:GetAtlas()
	if atlas == CATEGORY_ACTIVE_ATLAS then
		AccentTexture(texture, ROW_SELECTED_ALPHA)
		button.Label:SetTextColor(Theme.GetAccent())
	elseif atlas == CATEGORY_HOVER_ATLAS then
		FlatTexture(texture, 1, 1, 1, ROW_HOVER_ALPHA)
	end
end

local function OnCategoryState(button)
	Skin.TipFont(button.Label, 'body')
	RefreshCategoryState(button)
end

local function CategoryExpanded(button)
	local category = button:GetElementData().data.category
	return category and category:IsExpanded()
end

local function StyleCategoryRow(button)
	if button:IsForbidden() then return end
	if button.Toggle then
		if not button._buiCategoryRow then
			button._buiCategoryRow = true
			Skin.TipPageButton(button.Toggle, 'down')
			Hook(button, 'UpdateStateInternal', OnCategoryState)
		end
		FadeButtonStates(button.Toggle)
		SetArrowRotation(button.Toggle, CategoryExpanded(button))
		OnCategoryState(button)
	elseif button.Background then
		Refade(button.Background)
		Skin.TipFont(button.Label, 'label')
	end
end

local function StyleBindingButton(button)
	if not button then return end
	local selectedHighlight = button.SelectedHighlight or button.selectedHighlight
	if selectedHighlight and not button._buiTipButton then
		selectedHighlight.__buiSkin = true
		selectedHighlight:SetBlendMode('BLEND')
		AccentTexture(selectedHighlight, BINDING_SELECTED_ALPHA)
	end
	Button(button)
end

local function StyleBindingRow(row)
	Face(row.Label)
	if row.Highlight then AccentTexture(row.Highlight, ROW_HOVER_ALPHA) end
	for _, key in ipairs(BINDING_BUTTON_KEYS) do StyleBindingButton(row[key]) end
end

local function StyleControl(control)
	if control:IsForbidden() then return end
	if control.Button1 or control.Button2 then
		StyleBindingRow(control)
		return
	end
	Face(control.text)
	Body(control.Text)
	Face(control.Label)
	if control.Checkbox then CheckBox(control.Checkbox, CHECK_INSET) end
	StyleStepSlider(control.SliderWithSteppers)
	StyleDropdownControl(control.Control)
end

local function StyleControls(holder)
	local controls = holder.Controls
	if not controls then return end
	for _, control in ipairs(controls) do StyleControl(control) end
end

local function OnSectionToggle(button)
	local data = button:GetParent():GetElementData().data
	SetArrowRotation(button, data and data.expanded)
end

local function StyleRowButton(row)
	local button = row.Button
	if not button then return end
	if not (button.Left and button.Right) then
		Button(button)
		return
	end
	if not button._buiSection then
		button._buiSection = true
		FadeRegions(button)
		Shell(button)
		Skin.TipArrow(button, false, ARROW_EXPANDED)
		Skin.TipFont(button.Text, 'title')
		button:HookScript('OnClick', Wrap('Skin.SystemPanels section toggle', context.Guard(OnSectionToggle)))
	end
	Refade(button.Left)
	Refade(button.Right)
	OnSectionToggle(button)
end

local function RowTextEnabled(row)
	if row._buiTextEnabled ~= nil then return row._buiTextEnabled end
	local red, green, blue = row.Text:GetTextColor()
	local gray = GRAY_FONT_COLOR
	return not (math.abs(red - gray.r) < GRAY_MATCH and math.abs(green - gray.g) < GRAY_MATCH and math.abs(blue - gray.b) < GRAY_MATCH)
end

local function OnRowDisplayEnabled(row, enabled)
	row._buiTextEnabled = enabled ~= false
	Skin.TipFont(row.Text, enabled == false and 'label' or 'body')
end

local function StyleRowText(row)
	if not row.Text then return end
	if not row._buiTextHook then
		row._buiTextHook = true
		if row.DisplayEnabled then Hook(row, 'DisplayEnabled', OnRowDisplayEnabled) end
	end
	OnRowDisplayEnabled(row, RowTextEnabled(row))
end

local function StyleSettingsRow(row)
	if row:IsForbidden() then return end
	StyleRowText(row)
	if row.Title then Skin.TipFont(row.Title, 'title', SECTION_TITLE_SCALE) end
	if row.MouseoverOverlay then
		row.MouseoverOverlay:SetBlendMode('BLEND')
		FlatTexture(row.MouseoverOverlay, 1, 1, 1, ROW_HOVER_ALPHA)
	end
	if row.Checkbox then CheckBox(row.Checkbox, CHECK_INSET) end
	StyleStepSlider(row.SliderWithSteppers)
	StyleDropdownControl(row.Control)
	StyleDropdownControl(row.Dropdown)
	StyleRowButton(row)
	for _, key in ipairs(ROW_BUTTON_KEYS) do Button(row[key]) end
	if row.NineSlice then
		Fade(row.NineSlice)
		Shell(row)
	end
	StyleControls(row)
	if row.BaseQualityControls then
		SegmentMinimalTabs(row, QUALITY_TAB_KEYS)
		for _, key in ipairs(QUALITY_GROUP_KEYS) do StyleControls(row[key]) end
	end
end

local function SkinSettingsPanel(frame)
	FadeRegions(frame)
	FadeRegions(frame.Bg)
	FadeRegions(frame.NineSlice)
	Title(frame.NineSlice.Text)
	Shell(frame)
	Close(frame.ClosePanelButton)
	Body(frame.OutputText)
	EditBox(frame.SearchBox)
	for _, key in ipairs(SETTINGS_BUTTON_KEYS) do Button(frame[key]) end
	local categoryList = frame.CategoryList
	Shell(categoryList)
	ScrollBar(categoryList.ScrollBar)
	Skin.SweepScrollBox(categoryList.ScrollBox, StyleCategoryRow)
	local container = frame.Container
	local settingsList = container.SettingsList
	Shell(container)
	ReplaceDividerRegions(settingsList.Header)
	Skin.TipFont(settingsList.Header.Title, 'title', LIST_TITLE_SCALE)
	Button(settingsList.Header.DefaultsButton)
	ScrollBar(settingsList.ScrollBar)
	Skin.SweepScrollBox(settingsList.ScrollBox, StyleSettingsRow)
end

local function RefreshSettings(frame)
	SegmentMinimalTabs(frame, SETTINGS_TAB_KEYS)
	Skin.ForEachScrollFrame(frame.CategoryList.ScrollBox, StyleCategoryRow)
	Skin.ForEachScrollFrame(frame.Container.SettingsList.ScrollBox, StyleSettingsRow)
end

local function StyleAccountChecks(account)
	for _, check in pairs(account.settingsCheckButtons) do StyleLabeledCheck(check, LARGE_CHECK_INSET) end
end

local function SkinEditModeManager(frame)
	FadeArt(frame.Border)
	Shell(frame)
	Title(frame.Title)
	Skin.TipFont(frame.LayoutLabel, 'label')
	Close(frame.CloseButton)
	Dropdown(frame.LayoutDropdown)
	for _, key in ipairs(EDIT_MODE_CHECK_KEYS) do StyleLabeledCheck(frame[key], LARGE_CHECK_INSET) end
	StyleStepSlider(frame.GridSpacingSlider.Slider)
	Button(frame.SaveChangesButton)
	Button(frame.RevertAllChangesButton)

	local account = frame.AccountSettings
	local container = account.SettingsContainer
	FadeRegions(container.BorderArt)
	Shell(container)
	ScrollBar(container.ScrollBar)
	local advanced = container.ScrollChild.AdvancedOptionsContainer
	for _, key in ipairs(EDIT_MODE_TITLE_KEYS) do Title(advanced[key].Title) end
	ReplaceDivider(account.Expander.Divider, account.Expander)
	Face(account.Expander.Label)
end

local function RefreshEditMode(frame)
	StyleAccountChecks(frame.AccountSettings)
end

local function StyleSystemSetting(frame)
	if frame:IsForbidden() then return end
	if frame.Dropdown then
		Dropdown(frame.Dropdown)
		Face(frame.Label)
	elseif frame.Slider then
		StyleStepSlider(frame.Slider)
		Face(frame.Label)
	elseif frame.Button and frame.Label then
		StyleLabeledCheck(frame, LARGE_CHECK_INSET)
	elseif frame:IsObjectType('Button') then
		Button(frame)
	end
end

local function SweepSystemDialog(dialog)
	for frame in dialog.pools:EnumerateActive() do StyleSystemSetting(frame) end
end

local function SkinSystemDialog(dialog)
	FadeArt(dialog.Border)
	Shell(dialog)
	Title(dialog.Title)
	Close(dialog.CloseButton)
	Button(dialog.Buttons.RevertChangesButton)
	ReplaceDivider(dialog.Buttons.Divider, dialog.Buttons)
end

local function SyncNameBoxState(nameBox)
	nameBox._buiLockHint:SetShown(not nameBox:IsEnabled())
end

local function AlignLabel(label, box, inset)
	if not (label and box) then return end
	label:ClearAllPoints()
	label:SetPoint('BOTTOMLEFT', box, 'TOPLEFT', inset and inset.left or 0, LABEL_GAP - (inset and inset.top or 0))
end

local function AddLockHint(nameBox, importBox, textPad)
	if nameBox._buiLockHint then return end
	local instructions = importBox.EditBox.Instructions
	local hint = nameBox:CreateFontString(nil, 'OVERLAY')
	hint:SetFontObject(instructions:GetFontObject())
	hint:SetTextColor(instructions:GetTextColor())
	hint:SetPoint('LEFT', nameBox, 'LEFT', textPad, 0)
	hint:SetText(NAME_LOCKED_HINT)
	nameBox._buiLockHint = hint
	lockHints[hint] = true
	Hook(nameBox, 'SetEnabled', SyncNameBoxState)
end

local function SkinLayoutDialog(dialog)
	FadeArt(dialog.Border)
	Shell(dialog)
	Title(dialog.Title)
	for _, key in ipairs(EDIT_MODE_LABEL_KEYS) do Skin.TipFont(dialog[key], 'label') end
	local importBox = dialog.ImportBox
	if importBox then
		TextBox(importBox)
		ScrollBar(importBox.ScrollBar)
	end
	local nameBox = dialog.LayoutNameEditBox
	local nameInset = importBox and IMPORT_NAME_INSET or LAYOUT_NAME_INSET
	if nameBox then
		EditBox(nameBox, nameInset)
		local textPad = NAME_TEXT_PAD + (nameInset.left or 0)
		nameBox:SetTextInsets(textPad, NAME_TEXT_PAD, 0, 0)
		if importBox then AddLockHint(nameBox, importBox, textPad) end
	end
	AlignLabel(dialog.EditBoxLabel, importBox)
	AlignLabel(dialog.NameEditBoxLabel, nameBox, nameInset)
	if dialog.CharacterSpecificLayoutCheckButton then StyleLabeledCheck(dialog.CharacterSpecificLayoutCheckButton, LARGE_CHECK_INSET) end
	Button(dialog.AcceptButton)
	Button(dialog.CancelButton)
end

local function RefreshLayoutDialog(dialog)
	local nameBox = dialog.LayoutNameEditBox
	if nameBox and nameBox._buiLockHint then SyncNameBoxState(nameBox) end
end

local function SkinUnsavedDialog(dialog)
	FadeArt(dialog.Border)
	Shell(dialog)
	Body(dialog.Title)
	for _, key in ipairs(UNSAVED_BUTTON_KEYS) do Button(dialog[key]) end
end

local function SkinMacroFrame(frame)
	FaceRegions(frame)
	context.Chrome(frame)
	Skin.TipFont(_G.MacroFrameSelectedMacroName, 'title')
	Skin.TipFont(_G.MacroFrameEnterMacroText, 'label')
	Skin.TipFont(_G.MacroFrameCharLimitText, 'label')
	local tabs = {}
	for tabIndex = 1, MACRO_TAB_COUNT do tabs[tabIndex] = _G['MacroFrameTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
	Skin.TipIconSelector(context, frame.MacroSelector)
	for _, name in ipairs(MACRO_BUTTON_NAMES) do Button(_G[name]) end
	local textBackground = _G.MacroFrameTextBackground
	FadeArt(textBackground)
	Shell(textBackground)
	Face(_G.MacroFrameText)
	ScrollBar(_G.MacroFrameScrollFrame.ScrollBar)
end

local function RefreshMacro(frame)
	Skin.RefreshTabStrip(frame)
	Skin.SweepIconSelector(frame.MacroSelector)
	Skin.TipIconButton(frame.SelectedMacroButton)
end

local function StyleAddonEntry(entry)
	if entry:IsForbidden() then return end
	if not entry._buiAddonRow then
		entry._buiAddonRow = true
		entry:GetHighlightTexture():SetBlendMode('BLEND')
		RowHighlight(entry)
		Face(entry.Title)
		Face(entry.Status)
		Face(entry.Reload)
		CheckBox(entry.Enabled, CHECK_INSET)
		Button(entry.LoadAddonButton)
	end
	Skin.TipCheckGlyph(entry.Enabled, entry.Enabled.state == Enum.AddOnEnableState.Some)
end

local function StyleAddonRow(row)
	if row:IsForbidden() then return end
	local collapse = row.CollapseExpand
	if not collapse then
		if row.Enabled then StyleAddonEntry(row) end
		return
	end
	if not row._buiAddonCategory then
		row._buiAddonCategory = true
		row:GetHighlightTexture():SetBlendMode('BLEND')
		RowHighlight(row)
		Skin.TipFont(row.Title, 'title')
		Skin.TipPageButton(collapse, 'down')
	end
	FadeButtonStates(collapse)
	local treeNode = collapse.treeNode
	SetArrowRotation(collapse, not (treeNode and treeNode:IsCollapsed()))
end

local function SkinAddonList(frame)
	context.Chrome(frame)
	Dropdown(frame.Dropdown)
	CheckBox(frame.ForceLoad, CHECK_INSET)
	FaceRegions(frame.ForceLoad)
	EditBox(frame.SearchBox)
	local performance = frame.Performance
	Skin.TipFont(performance.Header, 'title')
	for _, key in ipairs(PERFORMANCE_TEXT_KEYS) do Face(performance[key]) end
	ReplaceDivider(performance.Divider, performance)
	ScrollBar(frame.ScrollBar)
	for _, key in ipairs(ADDON_BUTTON_KEYS) do Button(frame[key]) end
	Skin.SweepScrollBox(frame.ScrollBox, StyleAddonRow)
end

local function RefreshAddonList(frame)
	Skin.ForEachScrollFrame(frame.ScrollBox, StyleAddonRow)
end

local function SkinAddonDialog()
	FadeArt(_G.AddonDialogBackground)
	Shell(_G.AddonDialogBackground)
	Body(_G.AddonDialogText)
	Button(_G.AddonDialogButton1)
	Button(_G.AddonDialogButton2)
end

local function SkinQuickKeybind(frame)
	FadeArt(frame.BG)
	Shell(frame)
	FadeRegions(frame.Header)
	Title(frame.Header.Text)
	for _, key in ipairs(QUICK_KEYBIND_TEXT_KEYS) do Body(frame[key]) end
	CheckBox(frame.UseCharacterBindingsButton, LARGE_CHECK_INSET)
	for _, key in ipairs(QUICK_KEYBIND_BUTTON_KEYS) do Button(frame[key]) end
end

context.Window('SettingsPanel', { skin = SkinSettingsPanel, show = RefreshSettings })
context.Window('EditModeManagerFrame', { skin = SkinEditModeManager, show = RefreshEditMode })
context.Window('EditModeSystemSettingsDialog', {
	skin = SkinSystemDialog,
	show = SweepSystemDialog,
	install = function(dialog)
		Hook(dialog, 'UpdateSettings', SweepSystemDialog)
		Hook(dialog, 'UpdateExtraButtons', SweepSystemDialog)
	end,
})
for _, dialogName in ipairs(LAYOUT_DIALOGS) do context.Window(dialogName, { skin = SkinLayoutDialog, show = RefreshLayoutDialog }) end
context.Window('EditModeUnsavedChangesDialog', { skin = SkinUnsavedDialog })
context.Window('AddonList', {
	skin = SkinAddonList,
	show = RefreshAddonList,
	install = function() Hook('AddonList_InitAddon', StyleAddonEntry) end,
})
context.Window('AddonDialog', { skin = SkinAddonDialog })
context.Window('MacroFrame', { skin = SkinMacroFrame, show = RefreshMacro })
context.Window('MacroPopupFrame', {
	skin = function(popup) Skin.TipIconPopup(context, popup) end,
	show = function(popup) Skin.SweepIconSelector(popup.IconSelector) end,
})
context.Window('QuickKeybindFrame', { skin = SkinQuickKeybind })

context.OnDisable(function()
	for hint in pairs(lockHints) do hint:Hide() end
end)
