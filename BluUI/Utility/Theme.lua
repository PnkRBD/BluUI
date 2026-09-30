local _, BUI = ...
local sharedMedia = LibStub('LibSharedMedia-3.0')

local function GetGeneral()
	local db = BUI.GetDB()
	return db and db.general
end

function BUI.GetAccentColor()
	local general = GetGeneral()
	if general and general.useClassColorTheme then
		local _, class = UnitClass('player')
		local color    = class and RAID_CLASS_COLORS[class]
		if color then return color.r, color.g, color.b, 1 end
	end
	local theme = general and general.themeColor
	if theme and theme[1] and theme[2] and theme[3] then return theme[1], theme[2], theme[3], theme[4] or 1 end
	return unpack(BUI.C.DEFAULT_ACCENT)
end

function BUI.GetGlobalTexture()
	local general     = GetGeneral()
	local textureName = general and general.texture or BUI.C.DEFAULT_TEXTURE
	return sharedMedia:Fetch('statusbar', textureName) or BUI.C.FALLBACK_TEXTURE
end

function BUI.GetGradientTint()
	local general = GetGeneral()
	if general and general.texture == BUI.C.GRADIENT_TEXTURE then
		return general.gradientColor
	end
end

function BUI.GetGlobalFont()
	local general  = GetGeneral()
	local fontName = general and general.font or BUI.C.DEFAULT_FONT
	return sharedMedia:Fetch('font', fontName) or BUI.C.FONT_PATH
end

function BUI.GetAddonFont()
	return BUI.C.BASE_MEDIA_PATH .. [[Fonts\gotham_narrow_ultra.ttf]]
end

function BUI.FetchFont(name)
	return sharedMedia:Fetch('font', name, true)
end

function BUI.WindowFont()
	local fonts = BUI.GetDB().windowTheme.fonts
	local name = fonts and fonts.base
	return name and BUI.FetchFont(name) or BUI.GetAddonFont()
end

function BUI.ApplyWindowFont()
	BUI.BUILibClient.SetFont(BUI.WindowFont())
	BUI.PageEngine.window:Repaint()
	BUI.PageEngine.MarkPagesStale()
end

function BUI.BuildFontDropdownItems(globalOption)
	local items = {}
	if globalOption then
		items[1] = { value = globalOption, text = 'Use Global Font' }
	end
	local fonts = sharedMedia:List('font')
	table.sort(fonts)
	for _, name in ipairs(fonts) do
		items[#items + 1] = { value = name, text = name, fontPath = sharedMedia:Fetch('font', name) }
	end
	return items
end

function BUI.BuildTextureDropdownItems(globalOption)
	local items = {}
	if globalOption then
		items[1] = { value = globalOption, text = 'Use Global Texture' }
	end
	local textures = sharedMedia:List('statusbar')
	table.sort(textures)
	for _, name in ipairs(textures) do
		items[#items + 1] = { value = name, text = name }
	end
	return items
end

function BUI.BuildSoundDropdownItems()
	local items = { { value = 'None', text = 'None' } }
	local sounds = sharedMedia:List('sound')
	table.sort(sounds)
	for _, name in ipairs(sounds) do
		if name ~= 'None' then
			items[#items + 1] = { value = name, text = name }
		end
	end
	return items
end

function BUI.PlaySoundByName(name)
	if not name or name == '' or name == 'None' then return end
	local path = sharedMedia:Fetch('sound', name, true)
	if not path then return end
	local db = BUI.GetDB()
	local channel = db and db.general.soundChannel or 'Master'
	PlaySoundFile(path, channel)
end

function BUI.ResolveSpellInput(text)
	if not text or text == '' then return nil end
	local linkID = tostring(text):match('spell:(%d+)')
	if linkID then return tonumber(linkID) end
	local numericID = tonumber(text)
	if numericID then return numericID end
	local info = C_Spell.GetSpellInfo(text)
	if info and info.spellID then return info.spellID end
	return nil
end

function BUI.SpellListItems(list)
	local items = {}
	if list then
		for spellID, active in pairs(list) do
			if active then
				local name, icon
				local info = C_Spell.GetSpellInfo(spellID)
				if info then name, icon = info.name, info.iconID end
				items[#items + 1] = { icon = icon, name = name or ('Spell ' .. tostring(spellID)), id = spellID, removable = true }
			end
		end
		table.sort(items, function(itemA, itemB) return (itemA.name or '') < (itemB.name or '') end)
	end
	return items
end

local function CreateFontGetter(dbKey)
	return function()
		local general  = GetGeneral()
		local fontName = general and general[dbKey]
		if fontName then
			local path = sharedMedia:Fetch('font', fontName)
			if path then return path end
		end
		return BUI.GetGlobalFont()
	end
end

BUI.GetCDMFont            = CreateFontGetter('cdmFont')
BUI.GetTrackingFont       = CreateFontGetter('trackingFont')
BUI.GetPowerFont          = CreateFontGetter('powerFont')
BUI.GetSecondaryPowerFont = CreateFontGetter('secondaryPowerFont')

function BUI.GetModuleFont(moduleSettings)
	if not moduleSettings then return BUI.GetGlobalFont() end
	local fontName = moduleSettings.font
	if not fontName or fontName == BUI.C.GLOBAL_OPTION then return BUI.GetGlobalFont() end
	return sharedMedia:Fetch('font', fontName) or BUI.GetGlobalFont()
end

function BUI.ApplySlug(flags)
	flags = flags or ''
	local general = GetGeneral()
	if general and general.fontSlug then
		if not flags:find('SLUG') then
			flags = (flags == '') and 'SLUG' or (flags .. '|SLUG')
		end
	elseif flags:find('SLUG') then
		flags = flags:gsub('|?SLUG', '')
	end
	return flags
end

function BUI.GetFontOutline()
	return BUI.ApplySlug('OUTLINE')
end
