local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE

local function ShowDragDropPicker(parent, itemID, spellID, onSelect, onCancel, iconID, forceShow)
	local Modals = BUILib.Modals
	if not Modals then return end

	local options = {}
	if spellID then
		local name = C_Spell.GetSpellName(spellID)
		local icon = C_Spell.GetSpellTexture(spellID)
		if name then options[#options + 1] = {type = "spell", id = spellID, name = name, icon = icon or 134400, label = "Spell ID"} end
	end
	if itemID then
		local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
		if not itemName then
			local _, _, _, _, instantIcon = GetItemInfoInstant(itemID)
			itemIcon = instantIcon; C_Item.RequestLoadItemDataByID(itemID)
		end
		options[#options + 1] = {type = "item", id = itemID, name = itemName or ("Item " .. itemID), icon = itemIcon or 134400, label = "Item ID"}
	end
	if iconID then
		options[#options + 1] = {type = "icon", id = iconID, name = "Texture " .. iconID, icon = iconID, label = "Icon/Texture ID"}
	end

	if #options == 1 and not forceShow then
		if onSelect then onSelect(options[1].type, options[1].id) end; return
	end
	if #options == 0 then if onCancel then onCancel() end; return end

	local cardWidth, cardHeight = 220, 180
	local gap, padding = 20, 35
	local width = (#options * cardWidth) + ((#options - 1) * gap) + (padding * 2)

	local bounded = parent ~= nil
	local overlay, dialog, Close = Modals.CreateBase(width, 290, bounded, parent)
	if not bounded then
		overlay:SetFrameStrata("FULLSCREEN_DIALOG"); overlay:SetFrameLevel(500); dialog:SetFrameLevel(510)
	end

	Modals.CreateTitle(dialog, "Choose Type to Add")
	local cardsContainer = CreateFrame("Frame", nil, dialog)
	cardsContainer:SetSize(width - (padding * 2), cardHeight); cardsContainer:SetPoint("CENTER", 0, 5)

	for optionIndex, option in ipairs(options) do
		local card = Controls.Card(cardsContainer, option.icon, option.name, option.label .. ": " .. option.id, cardWidth, cardHeight, true, function()
			Close(); if onSelect then onSelect(option.type, option.id) end
		end)
		card:SetPoint("TOPLEFT", (optionIndex - 1) * (cardWidth + gap), 0)
	end

	local cancelButton = Modals.CreateButton(dialog, "Cancel", Modals.BTN_CANCEL, 100)
	cancelButton:SetPoint("BOTTOM", 0, 15)
	cancelButton:SetScript("OnClick", function() Close(); if onCancel then onCancel() end end)

	overlay:SetScript("OnKeyDown", function(_, key)
		if key == "ESCAPE" then Close(); if onCancel then onCancel() end end
	end)
	overlay:Show()
	return overlay, Close
end

Controls.ShowDragDropPicker = ShowDragDropPicker

local function CreateAutocomplete(editBox, searchFunc, onSelect, anchor)
	local dropdown = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	dropdown.isBluUIWindow = true
	dropdown:SetFrameStrata(BUILib.GetPopupStrata()); dropdown:SetFrameLevel(BUILib.GetPopupLevel())
	dropdown:SetBackdrop(Widget.BACKDROP); dropdown:SetBackdropColor(0.12, 0.12, 0.12, 0.98)
	dropdown:SetBackdropBorderColor(0.4, 0.4, 0.4, 1); dropdown:Hide()
	dropdown:SetScript("OnShow", function() BUILib._popupCount = (BUILib._popupCount or 0) + 1 end)
	dropdown:SetScript("OnHide", function() BUILib._popupCount = math.max(0, (BUILib._popupCount or 0) - 1) end)

	local rows = {}
	for rowIndex = 1, 10 do
		local row = CreateFrame("Button", nil, dropdown)
		row:SetHeight(28); row:SetPoint("TOPLEFT", 2, -2 - (rowIndex - 1) * 28); row:SetPoint("TOPRIGHT", -2, -2 - (rowIndex - 1) * 28)
		local background = Widget.Create(row, 1, 1, 1, 0); background:SetAllPoints(); row._bg = background
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(22, 22); icon:SetPoint("LEFT", 6, 0); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); row._icon = icon
		local name = row:CreateFontString(nil, "OVERLAY")
		name:SetFont(BUILib.Font, 12, ""); name:SetPoint("LEFT", icon, "RIGHT", 8, 0); name:SetTextColor(1, 1, 1); row._name = name
		local idText = row:CreateFontString(nil, "OVERLAY")
		idText:SetFont(BUILib.Font, 11, ""); idText:SetPoint("RIGHT", -8, 0); idText:SetTextColor(0.5, 0.5, 0.5); row._id = idText
		row:SetScript("OnEnter", function() Widget.SetColor(background, 1, 1, 1, 0.1) end)
		row:SetScript("OnLeave", function() Widget.SetColor(background, 1, 1, 1, 0) end)
		row:SetScript("OnClick", function()
			if row._data and onSelect then dropdown:Hide(); editBox:SetText(""); editBox:ClearFocus(); onSelect(row._data) end
		end)
		row:Hide(); rows[rowIndex] = row
	end

	local function Update(results)
		local count = math.min(#results, 10)
		for rowIndex = 1, 10 do
			local row = rows[rowIndex]
			if rowIndex <= count then
				local item = results[rowIndex]
				row._icon:SetTexture(item.icon or 134400); row._name:SetText(item.name or "Unknown")
				row._id:SetText(item.id or ""); row._data = item; row:Show()
			else row:Hide() end
		end
		if count > 0 then
			local anchorTo = anchor or editBox:GetParent()
			dropdown:SetFrameStrata(anchorTo:GetFrameStrata())
			dropdown:SetFrameLevel((anchorTo:GetFrameLevel() or 0) + 20)
			dropdown:SetHeight(count * 28 + 4); dropdown:ClearAllPoints()
			dropdown:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -2)
			dropdown:SetPoint("TOPRIGHT", anchorTo, "BOTTOMRIGHT", 0, -2); dropdown:Show()
		else dropdown:Hide() end
	end

	editBox:HookScript("OnTextChanged", function(self, userInput)
		if not userInput then return end
		local text = self:GetText()
		if #text >= 2 then Update(searchFunc(text)) else dropdown:Hide() end
	end)
	editBox:HookScript("OnEscapePressed", function() dropdown:Hide() end)
	editBox:HookScript("OnEditFocusLost", function()
		C_Timer.After(0.15, function() if not dropdown:IsMouseOver() then dropdown:Hide() end end)
	end)
	return dropdown
end

function Controls.AttachAutocomplete(editBox, searchFunc, onSelect, anchor)
	return CreateAutocomplete(editBox, searchFunc, onSelect, anchor)
end

local function CreateInputRow(parent, inputWidth, inputHeight, placeholder, onAdd, HandleDrop, searchFunc, onSearchSelect)
	local inputBoxWidget = Widget.New(parent, "Frame", nil, {bg = Theme.bg.input, border = Theme.border.input, size = {inputWidth, inputHeight}})
	local inputBox = inputBoxWidget.frame
	inputBox:SetPoint("TOPLEFT", 0, 0)
	inputBox:EnableMouse(true)
	inputBox:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" and HandleDrop then HandleDrop() end end)
	if HandleDrop then inputBox:SetScript("OnReceiveDrag", HandleDrop) end

	local SetInputHovered = inputBoxWidget:SetupHoverBorder(nil, Theme.border.input)

	local editBox = CreateFrame("EditBox", nil, inputBox)
	editBox:SetPoint("LEFT", 10, 0); editBox:SetPoint("RIGHT", -10, 0); editBox:SetHeight(20)
	editBox:SetAutoFocus(false); editBox:SetFont(BUILib.Font, FONT_SIZE, ""); editBox:SetTextColor(unpack(Theme.text.primary))
	editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	editBox:SetScript("OnEnter", function() SetInputHovered(true) end)
	editBox:SetScript("OnLeave", function() if not editBox:HasFocus() then SetInputHovered(false) end end)
	editBox:SetScript("OnEditFocusGained", function() SetInputHovered(true) end)
	editBox:SetScript("OnEditFocusLost", function() SetInputHovered(false) end)

	if HandleDrop then
		editBox:SetScript("OnReceiveDrag", HandleDrop)
		editBox:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" and not HandleDrop() then self:SetFocus() end
		end)
	end

	local placeholderText = editBox:CreateFontString(nil, "OVERLAY")
	placeholderText:SetFont(BUILib.Font, FONT_SIZE, ""); placeholderText:SetPoint("LEFT")
	placeholderText:SetText(placeholder or ""); placeholderText:SetTextColor(unpack(Theme.text.muted))
	editBox:SetScript("OnTextChanged", function(self) placeholderText:SetShown(self:GetText() == "") end)

	local addButton = Controls.Button(parent, "Add", 50, function()
		local text = editBox:GetText()
		if text ~= "" and onAdd then onAdd(text); editBox:SetText(""); editBox:ClearFocus(); placeholderText:Show() end
	end)
	addButton:SetHeight(inputHeight); addButton:SetPoint("LEFT", inputBox, "RIGHT", 4, 0)

	editBox:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		if text ~= "" and onAdd then onAdd(text); self:SetText(""); self:ClearFocus(); placeholderText:Show() end
	end)

	if searchFunc then CreateAutocomplete(editBox, searchFunc, onSearchSelect or onAdd) end
	return inputBox, editBox
end

function Controls.ItemInput(parent, options)
	options = options or {}
	local width = options.width or 400
	local containerHeight = options.height or 30
	local container = CreateFrame("Frame", nil, Widget.Unwrap(parent))
	container:SetSize(width, containerHeight)
	container.layoutHeight = containerHeight

	local onAdd = options.onAdd
	local function HandleDrop()
		local infoType, id = GetCursorInfo()
		if infoType == "item" and id then
			ClearCursor()
			if options.noDragPicker then
				if onAdd then onAdd("item:" .. id) end
			else
				local _, itemSpellID = GetItemSpell(id)
				if itemSpellID then
					ShowDragDropPicker(options.modalParent or container, id, itemSpellID,
						function(selectedType, selectedID) if onAdd then onAdd((selectedType == "item" and "item:" or "spell:") .. selectedID) end end, nil)
				elseif onAdd then
					onAdd("item:" .. id)
				end
			end
			return true
		elseif infoType == "spell" then
			local spellID = select(4, GetCursorInfo())
			ClearCursor()
			if onAdd and spellID then onAdd("spell:" .. spellID) end
			return true
		end
		return false
	end

	local _, editBox = CreateInputRow(container, width - 54, containerHeight, options.hint or "Drag an item here, or search...", onAdd, HandleDrop, options.searchFunc, options.onSearchSelect)
	container.editBox = editBox
	return container
end

function Controls.ItemList(parent, placeholder, width, height, onAdd, onRemove, searchFunc, onSearchSelect, orderable, onReorder, noInput, config)
	config = config or {}; width = width or 400; height = height or 200
	local showCheckbox = config.showCheckbox
	local onCheckboxChange = config.onCheckboxChange
	local onIconClick = config.onIconClick
	local onRowRightClick = config.onRowRightClick
	local onBindRow = config.onBindRow
	local hideID = config.hideID

	local GAP, ROW_HEIGHT = 4, 30
	local INPUT_HEIGHT = 26
	local STRIDE = ROW_HEIGHT + 1
	local totalHeight = noInput and (height + 12) or (INPUT_HEIGHT + GAP + height + 12)

	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(width, totalHeight); container.layoutHeight = totalHeight
	local listOffset = 0

	local function GetModalParent()
		local ancestor = parent
		while ancestor do
			if ancestor.GetFrameStrata and ancestor:GetFrameStrata() == "HIGH" then return ancestor end
			if ancestor._buiWindow or ancestor.Close then return ancestor end
			ancestor = ancestor:GetParent()
		end
		return parent
	end

	local function HandleDrop()
		local infoType, id = GetCursorInfo()
		if infoType == "item" and id then
			ClearCursor()
			if config.noDragPicker then
				if onAdd then onAdd("item:" .. id) end
			else
				local _, itemSpellID = GetItemSpell(id)
				if itemSpellID then
					ShowDragDropPicker(GetModalParent(), id, itemSpellID,
						function(selectedType, selectedID) if onAdd then onAdd((selectedType == "item" and "item:" or "spell:") .. selectedID) end end, nil)
				else
					if onAdd then onAdd("item:" .. id) end
				end
			end
			return true
		elseif infoType == "spell" then
			local spellID = select(4, GetCursorInfo())
			ClearCursor()
			if onAdd and spellID then onAdd("spell:" .. spellID) end
			return true
		end
		return false
	end

	if not noInput then
		local inputBox, editBox = CreateInputRow(container, width - 54, INPUT_HEIGHT, placeholder or "Drag item here, or search...", onAdd, HandleDrop, searchFunc, onSearchSelect)
		container.editBox = editBox
		listOffset = INPUT_HEIGHT + GAP
	end

	local listFrame = Widget.New(container, "Frame", nil, {bg = Theme.bg.dark, border = Theme.border.default, size = {width, height}}).frame
	listFrame:SetPoint("TOPLEFT", 0, -listOffset)
	listFrame:EnableMouse(true)
	listFrame:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then HandleDrop() end end)
	listFrame:SetScript("OnReceiveDrag", HandleDrop)

	local scroll = Controls.ScrollFrame(listFrame, width, height, height)
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll.child:EnableMouse(true)
	scroll.child:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then HandleDrop() end end)
	scroll.child:SetScript("OnReceiveDrag", HandleDrop)

	local data = {}
	local rowWidth = width - 14
	local dragIndex = nil
	local lastYByItem = setmetatable({}, { __mode = "k" })
	local SLIDE_DURATION = 0.15

	local ghostIconOffset = 6
	if showCheckbox then ghostIconOffset = ghostIconOffset + 26 end

	local ghost
	if orderable then
		ghost = Widget.New(UIParent, "Frame", nil, {bg = Theme.bg.hover, border = Theme.border.hover, size = {rowWidth, ROW_HEIGHT}}).frame
		ghost:SetFrameStrata(BUILib.GetPopupStrata()); ghost:SetFrameLevel(BUILib.GetPopupLevel())
		ghost:SetAlpha(0.95); ghost:Hide()
		local ghostIcon = ghost:CreateTexture(nil, "ARTWORK")
		ghostIcon:SetSize(28, 28); ghostIcon:SetPoint("LEFT", ghostIconOffset, 0); ghostIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ghost._icon = ghostIcon
		local ghostName = ghost:CreateFontString(nil, "OVERLAY")
		ghostName:SetFont(BUILib.Font, FONT_SIZE, ""); ghostName:SetPoint("LEFT", ghostIcon, "RIGHT", 10, 0)
		ghostName:SetTextColor(unpack(Theme.text.primary)); ghost._name = ghostName
	end

	local pool = {}
	local poolSize = math.ceil(height / STRIDE) + 4

	local function CreatePoolFrame()
		local row = Widget.New(scroll.child, "Frame", nil, {bg = Theme.bg.light, border = Theme.border.default, size = {rowWidth, ROW_HEIGHT}}).frame
		local iconOffset = 6
		local checkboxOffset = 0

		if showCheckbox then
			checkboxOffset = 26
			local checkFrame = Widget.New(row, "Button", nil, {bg = Theme.bg.input, border = Theme.border.input, size = {18, 18}}).frame
			checkFrame:SetPoint("LEFT", 6, 0)
			local checkMark = Widget.Create(checkFrame, Theme.GetAccent())
			checkMark:SetSize(12, 12); checkMark:SetPoint("CENTER")
			row._checkMark = checkMark; row._enabled = true
			row._checkbox = checkFrame

			checkFrame:SetScript("OnClick", function()
				if row._locked then return end
				row._enabled = not row._enabled; checkMark:SetShown(row._enabled)
				if row.data then row.data.enabled = row._enabled end
				if row._enabled then
					row.name:SetTextColor(unpack(row._customColor or Theme.text.primary))
					row.icon:SetDesaturated(false); row.icon:SetAlpha(1)
				else
					row.name:SetTextColor(unpack(Theme.text.disabled))
					row.icon:SetDesaturated(true); row.icon:SetAlpha(0.5)
				end
				if onCheckboxChange and row.data then onCheckboxChange(row.data.id, row._enabled, row) end
			end)
			checkFrame:SetScript("OnEnter", function()
				if row._locked then return end
				local accentRed, accentGreen, accentBlue = Theme.GetAccent(); checkFrame:SetBackdropBorderColor(accentRed, accentGreen, accentBlue, 1)
			end)
			checkFrame:SetScript("OnLeave", function()
				if row._locked then return end; checkFrame:SetBackdropBorderColor(unpack(Theme.border.input))
			end)

			function row:SetLocked(locked)
				self._locked = locked
				checkFrame:SetAlpha(locked and 0.3 or 1); checkFrame:EnableMouse(not locked)
			end
		end

		if orderable then
			iconOffset = checkboxOffset + 6
			row:EnableMouse(true); row:RegisterForDrag("LeftButton")
		else
			iconOffset = checkboxOffset + 6
		end

		local iconBg = Widget.New(row, "Frame", nil, {bg = Theme.bg.dark, border = Theme.border.default, size = {26, 26}}).frame
		iconBg:SetPoint("LEFT", iconOffset, 0)
		local iconTexture = iconBg:CreateTexture(nil, "ARTWORK")
		iconTexture:SetSize(24, 24); iconTexture:SetPoint("CENTER"); iconTexture:SetTexture(134400)
		iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.icon = iconTexture; row.iconBg = iconBg

		if onIconClick then
			iconBg:EnableMouse(true)
			iconBg:SetScript("OnMouseDown", function(_, mouseButton) if mouseButton == "LeftButton" and row.data then onIconClick(row.data.id, row) end end)
			iconBg:SetScript("OnEnter", function() iconBg:SetBackdropBorderColor(unpack(Theme.border.hover)) end)
			iconBg:SetScript("OnLeave", function() iconBg:SetBackdropBorderColor(unpack(Theme.border.default)) end)
		end

		local nameText = row:CreateFontString(nil, "OVERLAY")
		nameText:SetFont(BUILib.Font, FONT_SIZE, ""); nameText:SetPoint("LEFT", iconBg, "RIGHT", 8, 0)
		nameText:SetPoint("RIGHT", row, "RIGHT", hideID and -32 or -90, 0); nameText:SetJustifyH("LEFT")
		nameText:SetTextColor(unpack(Theme.text.primary))
		row.name = nameText

		local idText = row:CreateFontString(nil, "OVERLAY")
		idText:SetFont(BUILib.Font, 10, ""); idText:SetPoint("RIGHT", -28, 0)
		idText:SetTextColor(unpack(Theme.text.muted))
		row.id = idText

		row:EnableMouse(true)

		if onRowRightClick then
			row:SetScript("OnMouseUp", function(self, button)
				if button == "RightButton" and self.data then
					onRowRightClick(self.data.id, self)
				end
			end)
		end

		row:SetScript("OnEnter", function()
			row:SetBackdropColor(unpack(Theme.bg.hover)); row:SetBackdropBorderColor(unpack(Theme.border.hover))
			if row.data then
				GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
				local entryID = row.data.id
				if entryID and type(entryID) == "number" then GameTooltip:SetSpellByID(entryID) else GameTooltip:SetText(row.data.name or "") end
				if entryID and not hideID then GameTooltip:AddLine("ID: " .. tostring(entryID), 0.5, 0.5, 0.5) end
				GameTooltip:Show()
			end
		end)
		row:SetScript("OnLeave", function()
			if dragIndex ~= row._dataIndex then
				row:SetBackdropColor(unpack(Theme.bg.light)); row:SetBackdropBorderColor(unpack(Theme.border.default))
			end
			GameTooltip:Hide()
		end)

		if orderable then
			row:SetScript("OnDragStart", function()
				dragIndex = row._dataIndex
				ghost._icon:SetTexture(row.icon:GetTexture()); ghost._name:SetText(row.name:GetText()); ghost:Show()
				listFrame:SetScript("OnUpdate", function()
					local cursorX, cursorY = GetCursorPosition()
					local scale = UIParent:GetEffectiveScale()
					cursorX, cursorY = cursorX / scale, cursorY / scale
					ghost:ClearAllPoints(); ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX, cursorY)

					local scrollTop = scroll.child:GetTop()
					if scrollTop and dragIndex then
						local relativeY = scrollTop - cursorY
						local targetIndex = math.floor(relativeY / STRIDE) + 1
						targetIndex = math.max(1, math.min(#data, targetIndex))
						if targetIndex ~= dragIndex then
							local movedEntry = table.remove(data, dragIndex)
							table.insert(data, targetIndex, movedEntry)
							dragIndex = targetIndex
							container:_renderVisible()
						end
					end
				end)
			end)
			row:SetScript("OnDragStop", function()
				dragIndex = nil; ghost:Hide(); listFrame:SetScript("OnUpdate", nil)
				container:_renderVisible()
				if onReorder then onReorder(data) end
			end)
		end

		local closeButton = Controls.Icon(row, { preset = "close", size = 24, onClick = function() if row.data then container:RemoveItem(row.data) end end })
		closeButton:SetPoint("RIGHT", -4, 0); row.xBtn = closeButton

		row:Hide()
		return row
	end

	for poolIndex = 1, poolSize do pool[poolIndex] = CreatePoolFrame() end

	local function BindFrame(frame, entry, dataIndex)
		frame._dataIndex = dataIndex
		frame.data = entry

		frame.icon:SetTexture(entry.icon or 134400)
		frame.name:SetText(entry.name or "")
		if hideID then frame.id:Hide() else frame.id:SetText("ID: " .. (entry.id or "")); frame.id:Show() end

		if entry.removable == false then frame.xBtn:Hide() else frame.xBtn:Show() end

		local customColor = entry.removable == true and {1, 0.6, 0.2} or nil
		frame._customColor = customColor

		if showCheckbox then
			local enabled = entry.enabled ~= false
			frame._enabled = enabled
			frame._checkMark:SetShown(enabled)
			if enabled then
				frame.name:SetTextColor(unpack(customColor or Theme.text.primary))
				frame.icon:SetDesaturated(false); frame.icon:SetAlpha(1)
			else
				frame.name:SetTextColor(unpack(Theme.text.disabled))
				frame.icon:SetDesaturated(true); frame.icon:SetAlpha(0.5)
			end
			frame:SetLocked(entry._locked or false)
		else
			frame.name:SetTextColor(unpack(customColor or Theme.text.primary))
			frame.icon:SetDesaturated(false); frame.icon:SetAlpha(1)
		end

		frame:SetBackdropColor(unpack((orderable and dragIndex == dataIndex) and Theme.bg.hover or Theme.bg.light))
		frame:SetBackdropBorderColor(unpack(Theme.border.default))

		if onBindRow then onBindRow(frame, entry, dataIndex) end

		frame:SetAlpha((orderable and dragIndex == dataIndex) and 0.2 or 1)

		frame:Show()
	end

	local function PlaceRow(frame, entry, dataIndex)
		local targetY = -(dataIndex - 1) * STRIDE
		local previousY = lastYByItem[entry]
		lastYByItem[entry] = targetY
		frame:SetScript("OnUpdate", nil)
		frame:ClearAllPoints()

		local isDragged = dragIndex and data[dragIndex] == entry
		if previousY and previousY ~= targetY and not isDragged then
			local slideOffset = previousY - targetY
			local startTime = GetTime()
			frame:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, targetY + slideOffset)
			frame:SetScript("OnUpdate", function(self)
				local elapsedFraction = (GetTime() - startTime) / SLIDE_DURATION
				if elapsedFraction >= 1 then
					self:SetScript("OnUpdate", nil)
					self:ClearAllPoints()
					self:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, targetY)
				else
					local eased = 1 - (1 - elapsedFraction) * (1 - elapsedFraction)
					self:ClearAllPoints()
					self:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, targetY + slideOffset * (1 - eased))
				end
			end)
		else
			frame:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, targetY)
		end
	end

	function container:_renderVisible()
		local scrollOffset = scroll.scrollFrame:GetVerticalScroll()

		local viewHeight = height - 8

		local maxScroll = math.max(0, #data * STRIDE - viewHeight)
		if scrollOffset > maxScroll then scrollOffset = maxScroll end

		local firstVisible = math.max(1, math.floor(scrollOffset / STRIDE) + 1)
		local lastVisible = math.min(#data, math.ceil((scrollOffset + viewHeight) / STRIDE))

		local poolIndex = 0
		for dataIndex = firstVisible, lastVisible do
			poolIndex = poolIndex + 1
			if poolIndex <= poolSize then
				BindFrame(pool[poolIndex], data[dataIndex], dataIndex)
				PlaceRow(pool[poolIndex], data[dataIndex], dataIndex)
			end
		end
		for hiddenIndex = poolIndex + 1, poolSize do pool[hiddenIndex]:Hide() end
	end

	local function UpdateLayout()
		local virtualHeight = #data * STRIDE
		scroll:SetChildHeight(math.max(height, virtualHeight))
		container:_renderVisible()
	end

	local layoutPending = false
	local function RequestLayout()
		if layoutPending then return end
		layoutPending = true
		C_Timer.After(0, function()
			layoutPending = false
			UpdateLayout()
		end)
	end

	hooksecurefunc(scroll.scrollFrame, "SetVerticalScroll", function()
		container:_renderVisible()
	end)

	function container:AddItem(icon, name, id, removable, enabled)
		if enabled == nil then enabled = true end
		local rowData = {icon = icon, name = name, id = id, removable = removable, enabled = enabled}
		table.insert(data, rowData)

		local proxy = {data = rowData}
		function proxy:SetLocked(locked) rowData._locked = locked end
		RequestLayout()
		return proxy
	end

	function container:RemoveItem(rowData)
		for index, existingRow in ipairs(data) do
			if existingRow == rowData then
				table.remove(data, index)
				if onRemove then onRemove(rowData) end
				break
			end
		end
		UpdateLayout()
	end

	function container:ClearItems()
		wipe(data)
		RequestLayout()
	end

	function container:GetItems() return data end

	function container:SetListHeight(newHeight)
		height = newHeight
		listFrame:SetHeight(newHeight)
		scroll.frame:SetSize(width, newHeight)
		local newTotalHeight = noInput and (newHeight + 12) or (INPUT_HEIGHT + GAP + newHeight + 12)
		container:SetHeight(newTotalHeight)
		container.layoutHeight = newTotalHeight

		local newPoolSize = math.ceil(newHeight / STRIDE) + 4
		for poolIndex = poolSize + 1, newPoolSize do pool[poolIndex] = CreatePoolFrame() end
		if newPoolSize > poolSize then poolSize = newPoolSize end
		UpdateLayout()
	end

	return Widget.Wrap(container)
end

function Controls.SpellColorList(parent, placeholder, width, height, onAdd, onRemove, onColorChange, searchFunc, onSearchSelect)
	width = width or 400; height = height or 200
	local GAP, ROW_HEIGHT = 6, 36
	local INPUT_HEIGHT = 28
	local totalHeight = INPUT_HEIGHT + GAP + height + 12

	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(width, totalHeight); container.layoutHeight = totalHeight

	local function HandleDrop()
		local infoType, id = GetCursorInfo()
		if infoType == "spell" and id then ClearCursor(); if onAdd then onAdd(tostring(id)) end; return true end
		return false
	end

	local inputBox, editBox = CreateInputRow(container, width - 54, INPUT_HEIGHT, placeholder or "Drag spell here, or search...", onAdd, HandleDrop, searchFunc, onSearchSelect)
	container.editBox = editBox

	local listFrame = Widget.New(container, "Frame", nil, {bg = Theme.bg.dark, border = Theme.border.default, size = {width, height}}).frame
	listFrame:SetPoint("TOPLEFT", 0, -(INPUT_HEIGHT + GAP))
	listFrame:EnableMouse(true)
	listFrame:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then HandleDrop() end end)
	listFrame:SetScript("OnReceiveDrag", HandleDrop)

	local scroll = Controls.ScrollFrame(listFrame, width, height, height)
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll.child:EnableMouse(true)
	scroll.child:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then HandleDrop() end end)
	scroll.child:SetScript("OnReceiveDrag", HandleDrop)

	local rows, data = {}, {}
	local rowWidth = width - 14

	local function UpdateLayout()
		local cursorY = 0
		for _, row in ipairs(rows) do
			if row:IsShown() then row:ClearAllPoints(); row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -cursorY); cursorY = cursorY + ROW_HEIGHT + 2 end
		end
		scroll:SetChildHeight(math.max(height, cursorY))
	end

	local function CreateRow(icon, name, id, color)
		local row = Widget.New(scroll.child, "Frame", nil, {bg = Theme.bg.light, border = Theme.border.default, size = {rowWidth, ROW_HEIGHT}}).frame
		color = color or {1, 0.7, 0, 1}

		local iconBg = Widget.New(row, "Frame", nil, {bg = Theme.bg.dark, border = Theme.border.default, size = {26, 26}}).frame
		iconBg:SetPoint("LEFT", 6, 0)
		local iconTexture = iconBg:CreateTexture(nil, "ARTWORK")
		iconTexture:SetSize(22, 22); iconTexture:SetPoint("CENTER"); iconTexture:SetTexture(icon or 134400)
		iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92); row.icon = iconTexture

		local nameText = row:CreateFontString(nil, "OVERLAY")
		nameText:SetFont(BUILib.Font, FONT_SIZE, ""); nameText:SetPoint("LEFT", iconBg, "RIGHT", 10, 0)
		nameText:SetPoint("RIGHT", row, "RIGHT", -142, 0); nameText:SetJustifyH("LEFT")
		nameText:SetText(name or "Unknown Spell"); nameText:SetTextColor(unpack(Theme.text.primary)); row.name = nameText

		local swatch = CreateFrame("Button", nil, row)
		swatch:SetSize(24, 24); swatch:SetPoint("RIGHT", -110, 0)
		local swatchBorder = Widget.Create(swatch, 0, 0, 0, 1); swatchBorder:SetAllPoints()
		local swatchTexture = Widget.Create(swatch, color[1], color[2], color[3], 1)
		swatchTexture:SetDrawLayer("ARTWORK"); swatchTexture:SetPoint("TOPLEFT", 1, -1); swatchTexture:SetPoint("BOTTOMRIGHT", -1, 1)
		row.swatch = swatchTexture; row.color = color

		swatch:SetScript("OnClick", function()
			Controls.OpenColorPicker({
				r = color[1], g = color[2], b = color[3], a = 1,
				anchorTo = swatch,
				callback = function(red, green, blue)
					Widget.SetColor(swatchTexture, red, green, blue, 1)
					color[1], color[2], color[3] = red, green, blue
					if onColorChange and row.data then onColorChange(row.data.id, {red, green, blue, 1}) end
				end,
			})
		end)

		local idText = row:CreateFontString(nil, "OVERLAY")
		idText:SetFont(BUILib.Font, 10, ""); idText:SetPoint("RIGHT", -36, 0)
		idText:SetText("ID: " .. (id or "")); idText:SetTextColor(unpack(Theme.text.muted)); row.id = idText

		local closeButton = Controls.Icon(row, { preset = "close", size = 20, onClick = function() container:RemoveItem(row.data) end })
		closeButton:SetPoint("RIGHT", -8, 0)
		return row
	end

	function container:AddItem(icon, name, id, color)
		local rowData = {icon = icon, name = name, id = id, color = color or {1, 0.7, 0, 1}}
		table.insert(data, rowData)
		local row = CreateRow(icon, name, id, rowData.color)
		row.data = rowData; table.insert(rows, row); UpdateLayout()
		return row
	end

	function container:RemoveItem(rowData)
		for index, existingRow in ipairs(data) do if existingRow == rowData then table.remove(data, index); break end end
		for index, row in ipairs(rows) do
			if row.data == rowData then row:Hide(); table.remove(rows, index); if onRemove then onRemove(rowData) end; break end
		end
		UpdateLayout()
	end

	function container:ClearItems()
		for _, row in ipairs(rows) do row:Hide() end
		wipe(rows)
		wipe(data)
		UpdateLayout()
	end

	function container:GetItems() return data end

	return Widget.Wrap(container)
end
