local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('SystemPanels')

local hooksecurefunc = BUI.Prof.MakeHooker('systempanels')
local pairs = pairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme

local SKIN_ID = 'systempanels'
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'Inset' }
local LIST_TITLE_SCALE = 1.4
local SECTION_TITLE_SCALE = 1.2
local ROW_SELECTED_ALPHA = 0.2
local ROW_HOVER_ALPHA = 0.06
local ICON_HOVER_ALPHA = 0.15
local ICON_SELECTED_ALPHA = 0.35
local BINDING_SELECTED_ALPHA = 0.3
local SLIDER_TRACK_HEIGHT = 2
local CHECK_INSET = 4
local LARGE_CHECK_INSET = 6
local ARROW_EXPANDED = 0
local ARROW_COLLAPSED = math.pi / 2
local CATEGORY_ACTIVE_ATLAS = 'Options_List_Active'
local CATEGORY_HOVER_ATLAS = 'Options_List_Hover'
local SETTINGS_TAB_KEYS = { 'GameTab', 'AddOnsTab' }
local SETTINGS_BUTTON_KEYS = { 'ApplyButton', 'CloseButton' }
local SLIDER_TEXT_KEYS = { 'LeftText', 'RightText', 'TopText', 'MinText', 'MaxText' }
local BINDING_BUTTON_KEYS = { 'Button1', 'Button2', 'CustomButton' }
local ROW_BUTTON_KEYS = { 'Button1', 'Button2', 'PushToTalkKeybindButton', 'ToggleTest' }
local EDIT_MODE_CHECK_KEYS = { 'ShowGridCheckButton', 'EnableSnapCheckButton', 'EnableAdvancedOptionsCheckButton' }
local EDIT_MODE_TITLE_KEYS = { 'FramesTitle', 'CombatTitle', 'MiscTitle' }
local EDIT_MODE_LABEL_KEYS = { 'EditBoxLabel', 'NameEditBoxLabel' }
local UNSAVED_BUTTON_KEYS = { 'SaveAndProceedButton', 'ProceedButton', 'CancelButton' }
local MACRO_BUTTON_NAMES = { 'MacroEditButton', 'MacroSaveButton', 'MacroCancelButton', 'MacroDeleteButton', 'MacroNewButton', 'MacroExitButton' }
local MACRO_TAB_COUNT = 2
local ICON_EDIT_ART = { 'IconSelectorPopupNameLeft', 'IconSelectorPopupNameMiddle', 'IconSelectorPopupNameRight' }
local ADDON_BUTTON_KEYS = { 'EnableAllButton', 'DisableAllButton', 'OkayButton', 'CancelButton' }
local PERFORMANCE_TEXT_KEYS = { 'Current', 'Average', 'Peak' }
local QUICK_KEYBIND_TEXT_KEYS = { 'InstructionText', 'CancelDescriptionText', 'OutputText' }
local QUICK_KEYBIND_BUTTON_KEYS = { 'DefaultsButton', 'CancelButton', 'OkayButton' }
local STATE_TEXTURE_GETTERS = { 'GetNormalTexture', 'GetPushedTexture', 'GetHighlightTexture', 'GetDisabledTexture' }

local installed = false
local macroInstalled = false
local quickKeybindInstalled = false
local skinnedWindows = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local TextBox, ScrollBar, Tab, Face, Title, Body = context.TextBox, context.ScrollBar, context.Tab, context.Face, context.Title, context.Body
local FlatTexture, AccentTexture, RowHighlight, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.RowHighlight, Skin.CropIcon

local function Once(key)
	if skinnedWindows[key] then return false end
	skinnedWindows[key] = true
	return true
end

local function FadeAgain(texture)
	if not texture then return end
	Fade(texture)
	texture:SetAlpha(0)
end

local function FadeButtonStates(button)
	for getterIndex = 1, #STATE_TEXTURE_GETTERS do
		local getter = button[STATE_TEXTURE_GETTERS[getterIndex]]
		local texture = getter and getter(button)
		if texture then FadeAgain(texture) end
	end
end

local function FaceRegions(frame, kind)
	if not frame then return end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region.IsObjectType and region:IsObjectType('FontString') then Skin.TipFace(region, kind or 'body') end
	end
end

local function ReplaceDivider(texture, parent)
	if not texture then return end
	FadeAgain(texture)
	if texture._buiLine then return end
	local line = (parent or texture:GetParent()):CreateTexture(nil, 'ARTWORK')
	line.__buiSkin = true
	line:SetHeight(1)
	line:SetPoint('LEFT', texture, 'LEFT', 0, 0)
	line:SetPoint('RIGHT', texture, 'RIGHT', 0, 0)
	local edge = Skin.PANEL_EDGE
	FlatTexture(line, edge[1], edge[2], edge[3], edge[4])
	texture._buiLine = line
end

local function ReplaceDividerRegions(frame)
	if not frame then return end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then ReplaceDivider(region, frame) end
	end
end

local function SetArrowRotation(button, expanded)
	local arrow = button and button._buiTipArrow
	if arrow then arrow:SetRotation(expanded and ARROW_EXPANDED or ARROW_COLLAPSED) end
end

local function StyleStepper(button, direction)
	if not button then return end
	Skin.TipPageButton(button, direction)
	FadeButtonStates(button)
	FadeAgain(button.Texture)
	Skin.RefreshPageButton(button)
end

local function StyleSliderTrack(slider)
	if not slider or slider._buiTrack then return end
	local thumb = slider.Thumb or (slider.GetThumbTexture and slider:GetThumbTexture())
	for regionIndex = 1, select('#', slider:GetRegions()) do
		local region = select(regionIndex, slider:GetRegions())
		if region ~= thumb and region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then Fade(region) end
	end
	local track = slider:CreateTexture(nil, 'BACKGROUND')
	track.__buiSkin = true
	track:SetHeight(SLIDER_TRACK_HEIGHT)
	track:SetPoint('LEFT', slider, 'LEFT', 0, 0)
	track:SetPoint('RIGHT', slider, 'RIGHT', 0, 0)
	local edge = Skin.PANEL_EDGE
	FlatTexture(track, edge[1], edge[2], edge[3], edge[4])
	if thumb then
		local fill = slider:CreateTexture(nil, 'BACKGROUND', nil, 1)
		fill.__buiSkin = true
		fill:SetHeight(SLIDER_TRACK_HEIGHT)
		fill:SetPoint('LEFT', track, 'LEFT', 0, 0)
		fill:SetPoint('RIGHT', thumb, 'CENTER', 0, 0)
		AccentTexture(fill, 1)
	end
	slider._buiTrack = track
end

local function StyleStepSlider(stepper)
	if not stepper then return end
	StyleSliderTrack(stepper.Slider)
	StyleStepper(stepper.Back, 'previous')
	StyleStepper(stepper.Forward, 'next')
	for keyIndex = 1, #SLIDER_TEXT_KEYS do Face(stepper[SLIDER_TEXT_KEYS[keyIndex]]) end
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
	if not holder then return end
	CheckBox(holder.Button, inset)
	Face(holder.Label)
end

local function StyleIconButton(button)
	if not button or button:IsForbidden() then return end
	local icon = button.Icon
	if not icon then return end
	local highlight = button.Highlight or (button.GetHighlightTexture and button:GetHighlightTexture())
	if not button._buiIconButton then
		button._buiIconButton = true
		for regionIndex = 1, select('#', button:GetRegions()) do
			local region = select(regionIndex, button:GetRegions())
			if region ~= icon and region ~= highlight and region ~= button.SelectedTexture and region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then
				Fade(region)
			end
		end
		CropIcon(icon)
		Skin.TipIconFrame(button, icon)
		if highlight then
			highlight:SetBlendMode('BLEND')
			FlatTexture(highlight, 1, 1, 1, ICON_HOVER_ALPHA)
		end
	end
	local selected = button.SelectedTexture
	if selected then
		selected:SetBlendMode('BLEND')
		AccentTexture(selected, ICON_SELECTED_ALPHA)
	end
end

local function SweepIconSelector(selector, callback)
	local box = selector and selector.ScrollBox
	Skin.ForEachScrollFrame(box, callback)
end

local function SkinIconSelector(selector)
	if not selector then return end
	FadeArt(selector)
	Shell(selector)
	ScrollBar(selector.ScrollBar)
	Skin.SweepScrollBox(selector.ScrollBox, StyleIconButton)
	if selector.UpdateAllSelectedTextures and not selector._buiSelectionHook then
		selector._buiSelectionHook = true
		hooksecurefunc(selector, 'UpdateAllSelectedTextures', function(host)
			if Enabled() then SweepIconSelector(host, StyleIconButton) end
		end)
	end
end

local function RefreshCategoryState(button)
	local texture = button.Texture
	if not texture or not texture:IsShown() then return end
	local atlas = texture:GetAtlas()
	if atlas == CATEGORY_ACTIVE_ATLAS then
		AccentTexture(texture, ROW_SELECTED_ALPHA)
		local red, green, blue = Theme.GetAccent()
		if button.Label then button.Label:SetTextColor(red, green, blue, 1) end
	elseif atlas == CATEGORY_HOVER_ATLAS then
		FlatTexture(texture, 1, 1, 1, ROW_HOVER_ALPHA)
	end
end

local function OnCategoryState(button)
	if not Enabled() then return end
	Skin.TipFont(button.Label, 'body')
	RefreshCategoryState(button)
end

local function CategoryExpanded(button)
	local elementData = button.GetElementData and button:GetElementData()
	local category = elementData and elementData.data and elementData.data.category
	return category and category.IsExpanded and category:IsExpanded()
end

local function StyleCategoryRow(button)
	if not Enabled() or button:IsForbidden() then return end
	if button.Toggle then
		if not button._buiCategoryRow then
			button._buiCategoryRow = true
			Skin.TipPageButton(button.Toggle, 'down')
			hooksecurefunc(button, 'UpdateStateInternal', OnCategoryState)
		end
		FadeButtonStates(button.Toggle)
		SetArrowRotation(button.Toggle, CategoryExpanded(button))
		OnCategoryState(button)
	elseif button.Background then
		FadeAgain(button.Background)
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
	for keyIndex = 1, #BINDING_BUTTON_KEYS do StyleBindingButton(row[BINDING_BUTTON_KEYS[keyIndex]]) end
end

local function StyleControl(control)
	if not control or control:IsForbidden() then return end
	if control.Button1 or control.Button2 then
		StyleBindingRow(control)
		return
	end
	Face(control.text)
	Face(control.Text)
	Face(control.Label)
	if control.Checkbox then CheckBox(control.Checkbox, CHECK_INSET) end
	StyleStepSlider(control.SliderWithSteppers)
	StyleDropdownControl(control.Control)
end

local function OnSectionToggle(button)
	local row = button:GetParent()
	local elementData = row and row.GetElementData and row:GetElementData()
	local data = elementData and elementData.data
	SetArrowRotation(button, data and data.expanded)
end

local function StyleRowButton(row)
	local button = row.Button
	if not button then return end
	if button.Left and button.Right then
		if not button._buiSection then
			button._buiSection = true
			FadeRegions(button)
			Shell(button)
			Skin.TipArrow(button, false, ARROW_EXPANDED)
			Skin.TipFont(button.Text, 'title')
			HookScript(button, 'OnClick', OnSectionToggle)
		end
		FadeAgain(button.Left)
		FadeAgain(button.Right)
		OnSectionToggle(button)
	else
		Button(button)
	end
end

local GRAY_MATCH = 0.02

local function RowTextEnabled(row)
	if row._buiTextEnabled ~= nil then return row._buiTextEnabled end
	local red, green, blue = row.Text:GetTextColor()
	local gray = GRAY_FONT_COLOR
	return not (math.abs(red - gray.r) < GRAY_MATCH and math.abs(green - gray.g) < GRAY_MATCH and math.abs(blue - gray.b) < GRAY_MATCH)
end

local function OnRowDisplayEnabled(row, enabled)
	row._buiTextEnabled = enabled ~= false
	if not Enabled() or not row.Text then return end
	Skin.TipFont(row.Text, enabled == false and 'label' or 'body')
end

local function StyleRowText(row)
	local text = row.Text
	if not text then return end
	if not row._buiTextHook then
		row._buiTextHook = true
		if row.DisplayEnabled then hooksecurefunc(row, 'DisplayEnabled', OnRowDisplayEnabled) end
	end
	OnRowDisplayEnabled(row, RowTextEnabled(row))
end

local function StyleSettingsRow(row)
	if not Enabled() or row:IsForbidden() then return end
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
	for keyIndex = 1, #ROW_BUTTON_KEYS do Button(row[ROW_BUTTON_KEYS[keyIndex]]) end
	if row.NineSlice then
		Fade(row.NineSlice)
		Shell(row)
	end
	local controls = row.Controls
	if controls then
		for controlIndex = 1, #controls do StyleControl(controls[controlIndex]) end
	end
end

local function RefreshSettingsTabs()
	local frame = _G.SettingsPanel
	if not frame or not Enabled() then return end
	for keyIndex = 1, #SETTINGS_TAB_KEYS do
		local tab = frame[SETTINGS_TAB_KEYS[keyIndex]]
		if tab and tab._buiTab then
			local selected = tab.selected == true
			Skin.TipTabSelected(tab, selected)
			local text = tab.Text
			if text then
				Skin.TipFont(text, 'title')
				if selected then
					local red, green, blue = Theme.GetAccent()
					text:SetTextColor(red, green, blue, 1)
				end
			end
		end
	end
end

local function SkinSettingsTab(tab)
	if not tab then return end
	Tab(tab, false)
	if not tab._buiTabHook then
		tab._buiTabHook = true
		hooksecurefunc(tab, 'SetSelectedState', RefreshSettingsTabs)
	end
end

local function SkinListHeader(header)
	if not header then return end
	ReplaceDividerRegions(header)
	Skin.TipFont(header.Title, 'title', LIST_TITLE_SCALE)
	Button(header.DefaultsButton)
end

local function SkinSettingsPanel(frame)
	FadeRegions(frame)
	if frame.Bg then FadeRegions(frame.Bg) end
	local nineSlice = frame.NineSlice
	if nineSlice then
		FadeRegions(nineSlice)
		Title(nineSlice.Text)
	end
	Shell(frame)
	Close(frame.ClosePanelButton)
	Body(frame.OutputText)
	EditBox(frame.SearchBox)
	for keyIndex = 1, #SETTINGS_BUTTON_KEYS do Button(frame[SETTINGS_BUTTON_KEYS[keyIndex]]) end
	for keyIndex = 1, #SETTINGS_TAB_KEYS do SkinSettingsTab(frame[SETTINGS_TAB_KEYS[keyIndex]]) end
	local categoryList = frame.CategoryList
	if categoryList then
		Shell(categoryList)
		ScrollBar(categoryList.ScrollBar)
		Skin.SweepScrollBox(categoryList.ScrollBox, StyleCategoryRow)
	end
	local container = frame.Container
	local settingsList = container and container.SettingsList
	if settingsList then
		Shell(container)
		SkinListHeader(settingsList.Header)
		ScrollBar(settingsList.ScrollBar)
		Skin.SweepScrollBox(settingsList.ScrollBox, StyleSettingsRow)
	end
end

local function SweepSettingsLists()
	local frame = _G.SettingsPanel
	if not frame or not Enabled() then return end
	local categoryBox = frame.CategoryList and frame.CategoryList.ScrollBox
	Skin.ForEachScrollFrame(categoryBox, StyleCategoryRow)
	local settingsList = frame.Container and frame.Container.SettingsList
	local settingsBox = settingsList and settingsList.ScrollBox
	Skin.ForEachScrollFrame(settingsBox, StyleSettingsRow)
end

local function ApplySettings()
	local frame = _G.SettingsPanel
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if Once('settings') then SkinSettingsPanel(frame) end
	RefreshSettingsTabs()
	SweepSettingsLists()
end

local function SkinAccountSettings(account)
	if not account then return end
	local container = account.SettingsContainer
	if container then
		if container.BorderArt then FadeRegions(container.BorderArt) end
		Shell(container)
		ScrollBar(container.ScrollBar)
		local checks = account.settingsCheckButtons
		if checks then
			for _, check in pairs(checks) do StyleLabeledCheck(check, LARGE_CHECK_INSET) end
		end
		local scrollChild = container.ScrollChild
		local advanced = scrollChild and scrollChild.AdvancedOptionsContainer
		if advanced then
			for keyIndex = 1, #EDIT_MODE_TITLE_KEYS do
				local holder = advanced[EDIT_MODE_TITLE_KEYS[keyIndex]]
				if holder then Title(holder.Title) end
			end
		end
	end
	local expander = account.Expander
	if expander then
		ReplaceDivider(expander.Divider, expander)
		Face(expander.Label)
	end
end

local function SkinEditModeManager(frame)
	FadeArt(frame.Border)
	Shell(frame)
	Title(frame.Title)
	Skin.TipFont(frame.LayoutLabel, 'label')
	Close(frame.CloseButton)
	Dropdown(frame.LayoutDropdown)
	for keyIndex = 1, #EDIT_MODE_CHECK_KEYS do StyleLabeledCheck(frame[EDIT_MODE_CHECK_KEYS[keyIndex]], LARGE_CHECK_INSET) end
	if frame.GridSpacingSlider then StyleStepSlider(frame.GridSpacingSlider.Slider) end
	Button(frame.SaveChangesButton)
	Button(frame.RevertAllChangesButton)
	SkinAccountSettings(frame.AccountSettings)
end

local function StyleSystemSetting(frame)
	if not frame or frame:IsForbidden() then return end
	if frame.Dropdown then
		Dropdown(frame.Dropdown)
		Face(frame.Label)
	elseif frame.Slider then
		StyleStepSlider(frame.Slider)
		Face(frame.Label)
	elseif frame.Button and frame.Label then
		StyleLabeledCheck(frame, LARGE_CHECK_INSET)
	elseif frame.IsObjectType and frame:IsObjectType('Button') then
		Button(frame)
	end
end

local function SweepSystemDialog(dialog)
	if not Enabled() or not dialog.pools then return end
	for frame in dialog.pools:EnumerateActive() do StyleSystemSetting(frame) end
end

local function SkinSystemDialog(dialog)
	if not dialog or not Enabled() then return end
	if Once('systemDialog') then
		FadeArt(dialog.Border)
		Shell(dialog)
		Title(dialog.Title)
		Close(dialog.CloseButton)
		local buttons = dialog.Buttons
		if buttons then
			Button(buttons.RevertChangesButton)
			ReplaceDivider(buttons.Divider, buttons)
		end
	end
	SweepSystemDialog(dialog)
end

local function SkinLayoutDialog(dialog)
	if not dialog or not Enabled() then return end
	FadeArt(dialog.Border)
	Shell(dialog)
	Title(dialog.Title)
	for keyIndex = 1, #EDIT_MODE_LABEL_KEYS do Skin.TipFont(dialog[EDIT_MODE_LABEL_KEYS[keyIndex]], 'label') end
	local importBox = dialog.ImportBox
	if importBox then
		TextBox(importBox)
		ScrollBar(importBox.ScrollBar)
	end
	EditBox(dialog.LayoutNameEditBox)
	StyleLabeledCheck(dialog.CharacterSpecificLayoutCheckButton, LARGE_CHECK_INSET)
	Button(dialog.AcceptButton)
	Button(dialog.CancelButton)
end

local function SkinUnsavedDialog(dialog)
	if not dialog or not Enabled() then return end
	FadeArt(dialog.Border)
	Shell(dialog)
	Body(dialog.Title)
	for keyIndex = 1, #UNSAVED_BUTTON_KEYS do Button(dialog[UNSAVED_BUTTON_KEYS[keyIndex]]) end
end

local function ApplyEditMode()
	local frame = _G.EditModeManagerFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if Once('editMode') then SkinEditModeManager(frame) end
	local account = frame.AccountSettings
	local checks = account and account.settingsCheckButtons
	if checks then
		for _, check in pairs(checks) do StyleLabeledCheck(check, LARGE_CHECK_INSET) end
	end
end

local function SkinMacroFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	FaceRegions(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	Skin.TipFont(_G.MacroFrameSelectedMacroName, 'title')
	Skin.TipFont(_G.MacroFrameEnterMacroText, 'label')
	Skin.TipFont(_G.MacroFrameCharLimitText, 'label')
	local tabs = {}
	for tabIndex = 1, MACRO_TAB_COUNT do tabs[tabIndex] = _G['MacroFrameTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
	SkinIconSelector(frame.MacroSelector)
	StyleIconButton(frame.SelectedMacroButton)
	for nameIndex = 1, #MACRO_BUTTON_NAMES do Button(_G[MACRO_BUTTON_NAMES[nameIndex]]) end
	local textBackground = _G.MacroFrameTextBackground
	if textBackground then
		Fade(textBackground.NineSlice)
		FadeRegions(textBackground)
		Shell(textBackground)
	end
	Face(_G.MacroFrameText)
	local scrollFrame = _G.MacroFrameScrollFrame
	if scrollFrame then ScrollBar(scrollFrame.ScrollBar) end
end

local function SkinSelectedIcon(button)
	if not button then return end
	local icon = button.Icon
	for regionIndex = 1, select('#', button:GetRegions()) do
		local region = select(regionIndex, button:GetRegions())
		if region ~= icon and region ~= button.Highlight and region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then Fade(region) end
	end
	CropIcon(icon)
	Skin.TipIconFrame(button, icon)
	if button.Highlight then
		button.Highlight:SetBlendMode('BLEND')
		FlatTexture(button.Highlight, 1, 1, 1, ICON_HOVER_ALPHA)
	end
end

local function SkinIconPopup(popup)
	if not popup or popup:IsForbidden() or not Enabled() then return end
	if not Once('iconPopup') then
		SweepIconSelector(popup.IconSelector, StyleIconButton)
		return
	end
	Fade(popup.BG)
	local border = popup.BorderBox
	if border then
		FadeArt(border)
		Skin.TipFont(border.EditBoxHeaderText, 'label')
		Skin.TipFont(border.IconSelectionText, 'label')
		local editBox = border.IconSelectorEditBox
		if editBox then
			for keyIndex = 1, #ICON_EDIT_ART do Fade(editBox[ICON_EDIT_ART[keyIndex]]) end
			EditBox(editBox)
		end
		Dropdown(border.IconTypeDropdown)
		local area = border.SelectedIconArea
		if area then
			SkinSelectedIcon(area.SelectedIconButton)
			local text = area.SelectedIconText
			if text then
				Skin.TipFont(text.SelectedIconHeader, 'label')
				Face(text.SelectedIconDescription)
			end
		end
		Button(border.OkayButton)
		Button(border.CancelButton)
	end
	Shell(popup)
	SkinIconSelector(popup.IconSelector)
end

local function ApplyMacro()
	local frame = _G.MacroFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if Once('macro') then SkinMacroFrame(frame) end
	Skin.RefreshTabStrip(frame)
	SweepIconSelector(frame.MacroSelector, StyleIconButton)
	StyleIconButton(frame.SelectedMacroButton)
end

local function StyleAddonEntry(entry)
	if not entry or entry:IsForbidden() then return end
	if not entry._buiAddonRow then
		entry._buiAddonRow = true
		local highlight = entry:GetHighlightTexture()
		if highlight then highlight:SetBlendMode('BLEND') end
		RowHighlight(entry)
		Face(entry.Title)
		Face(entry.Status)
		Face(entry.Reload)
		CheckBox(entry.Enabled, CHECK_INSET)
		Button(entry.LoadAddonButton)
	end
	local check = entry.Enabled
	if check then Skin.TipCheckGlyph(check, check.state == Enum.AddOnEnableState.Some) end
end

local function OnAddonEntry(entry)
	if Enabled() then StyleAddonEntry(entry) end
end

local function StyleAddonRow(row)
	if not Enabled() or row:IsForbidden() then return end
	local collapse = row.CollapseExpand
	if collapse then
		if not row._buiAddonCategory then
			row._buiAddonCategory = true
			local highlight = row:GetHighlightTexture()
			if highlight then highlight:SetBlendMode('BLEND') end
			RowHighlight(row)
			Skin.TipFont(row.Title, 'title')
			Skin.TipPageButton(collapse, 'down')
		end
		FadeButtonStates(collapse)
		local treeNode = collapse.treeNode
		SetArrowRotation(collapse, not (treeNode and treeNode:IsCollapsed()))
	elseif row.Enabled then
		StyleAddonEntry(row)
	end
end

local function SkinAddonPerformance(performance)
	if not performance then return end
	Skin.TipFont(performance.Header, 'title')
	for keyIndex = 1, #PERFORMANCE_TEXT_KEYS do Face(performance[PERFORMANCE_TEXT_KEYS[keyIndex]]) end
	ReplaceDivider(performance.Divider, performance)
end

local function SkinAddonList(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	Dropdown(frame.Dropdown)
	local forceLoad = frame.ForceLoad
	if forceLoad then
		CheckBox(forceLoad, CHECK_INSET)
		FaceRegions(forceLoad)
	end
	EditBox(frame.SearchBox)
	SkinAddonPerformance(frame.Performance)
	ScrollBar(frame.ScrollBar)
	for keyIndex = 1, #ADDON_BUTTON_KEYS do Button(frame[ADDON_BUTTON_KEYS[keyIndex]]) end
	Skin.SweepScrollBox(frame.ScrollBox, StyleAddonRow)
end

local function SkinAddonDialog(dialog)
	if not dialog or not Enabled() or not Once('addonDialog') then return end
	local background = _G.AddonDialogBackground
	if background then
		FadeArt(background)
		Shell(background)
	end
	Body(_G.AddonDialogText)
	Button(_G.AddonDialogButton1)
	Button(_G.AddonDialogButton2)
end

local function ApplyAddonList()
	local frame = _G.AddonList
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if Once('addonList') then SkinAddonList(frame) end
	local box = frame.ScrollBox
	Skin.ForEachScrollFrame(box, StyleAddonRow)
end

local function SkinQuickKeybind(frame)
	FadeArt(frame.BG)
	Shell(frame)
	local header = frame.Header
	if header then
		FadeRegions(header)
		Title(header.Text)
	end
	for keyIndex = 1, #QUICK_KEYBIND_TEXT_KEYS do Body(frame[QUICK_KEYBIND_TEXT_KEYS[keyIndex]]) end
	CheckBox(frame.UseCharacterBindingsButton, LARGE_CHECK_INSET)
	for keyIndex = 1, #QUICK_KEYBIND_BUTTON_KEYS do Button(frame[QUICK_KEYBIND_BUTTON_KEYS[keyIndex]]) end
end

local function ApplyQuickKeybind()
	local frame = _G.QuickKeybindFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if Once('quickKeybind') then SkinQuickKeybind(frame) end
end

local function HookDialog(frame, callback)
	if frame then HookScript(frame, 'OnShow', callback) end
end

local function InstallMacro()
	if macroInstalled then return end
	local frame = _G.MacroFrame
	if not frame then return end
	macroInstalled = true
	HookScript(frame, 'OnShow', ApplyMacro)
	HookDialog(_G.MacroPopupFrame, SkinIconPopup)
	if frame:IsShown() then ApplyMacro() end
end

local function InstallQuickKeybind()
	if quickKeybindInstalled then return end
	local frame = _G.QuickKeybindFrame
	if not frame then return end
	quickKeybindInstalled = true
	HookScript(frame, 'OnShow', ApplyQuickKeybind)
	if frame:IsShown() then ApplyQuickKeybind() end
end

local function Install()
	if installed then return end
	local settings = _G.SettingsPanel
	if not settings then return end
	installed = true
	HookScript(settings, 'OnShow', ApplySettings)
	if settings:IsShown() then ApplySettings() end
	local editMode = _G.EditModeManagerFrame
	if editMode then
		HookScript(editMode, 'OnShow', ApplyEditMode)
		local systemDialog = _G.EditModeSystemSettingsDialog
		if systemDialog then
			HookScript(systemDialog, 'OnShow', SkinSystemDialog)
			hooksecurefunc(systemDialog, 'UpdateSettings', SweepSystemDialog)
			hooksecurefunc(systemDialog, 'UpdateExtraButtons', SweepSystemDialog)
		end
		HookDialog(_G.EditModeLayoutDialog, SkinLayoutDialog)
		HookDialog(_G.EditModeImportLayoutDialog, SkinLayoutDialog)
		HookDialog(_G.EditModeImportLayoutLinkDialog, SkinLayoutDialog)
		HookDialog(_G.EditModeUnsavedChangesDialog, SkinUnsavedDialog)
		if editMode:IsShown() then ApplyEditMode() end
	end
	local addonList = _G.AddonList
	if addonList then
		HookScript(addonList, 'OnShow', ApplyAddonList)
		if _G.AddonList_InitAddon then hooksecurefunc('AddonList_InitAddon', OnAddonEntry) end
		HookDialog(_G.AddonDialog, SkinAddonDialog)
		if addonList:IsShown() then ApplyAddonList() end
	end
end

local function TryInstall()
	Install()
	InstallMacro()
	InstallQuickKeybind()
	if installed and macroInstalled and quickKeybindInstalled then BUI.Events:Unregister('ADDON_LOADED', 'Skin.SystemPanels') end
end

local function ReapplyShown()
	if _G.SettingsPanel and _G.SettingsPanel:IsShown() then ApplySettings() end
	if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then ApplyEditMode() end
	if _G.AddonList and _G.AddonList:IsShown() then ApplyAddonList() end
	if _G.MacroFrame and _G.MacroFrame:IsShown() then ApplyMacro() end
	if _G.QuickKeybindFrame and _G.QuickKeybindFrame:IsShown() then ApplyQuickKeybind() end
end

local function Deactivate()
	context.Restore()
	wipe(skinnedWindows)
	BUI.Print('Settings & Editors skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		TryInstall()
		if not (installed and macroInstalled and quickKeybindInstalled) then
			BUI.Events:Register('ADDON_LOADED', 'Skin.SystemPanels', TryInstall)
		end
		ReapplyShown()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Settings & Editors',
	description = 'The game settings window, Edit Mode manager and dialogs, quick keybinding, macro editor and addon list: dark shells, house controls, flat sliders and clean list rows.',
	icon = 'Interface/Icons/INV_Misc_Gear_01',
})
