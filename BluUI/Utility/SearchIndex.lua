local _, BUI = ...

BUI.SearchIndex = {}
local SearchIndex = BUI.SearchIndex

local entries = {
	{ label = "Look and behavior", page = "unitframes", tab = 1, panel = "Appearance", keywords = "unit frame texture font statusbar tooltip click to target decimal abbreviations number format sync copy player target pet enable test mode" },
	{ label = "Status tag", page = "unitframes", tab = 2, panel = "Tags", keywords = "dead ghost offline afk dnd status color shared party raid size position" },
	{ label = "Health bar", page = "unitframes", tab = 1, panel = "Appearance", keywords = "health color background border class color transparent" },
	{ label = "Damage absorb", page = "unitframes", tab = 1, panel = "Appearance", keywords = "absorb shield heal absorb texture direction preview" },
	{ label = "Power bar", page = "unitframes", tab = 1, panel = "Appearance", keywords = "power color resource type class reaction" },
	{ label = "Dispel highlight", page = "unitframes", tab = 1, panel = "Appearance", keywords = "dispel debuff highlight bar tint fade dark black type icons cleanse callouts recolor blend colors" },
	{ label = "Default tags", page = "unitframes", tab = 2, panel = "Tags", keywords = "default tags name health power status format reset color size position offset" },
	{ label = "Raid icon", page = "unitframes", tab = 1, panel = "Appearance", keywords = "raid marker leader icon indicators position size" },
	{ label = "Custom tags", page = "unitframes", tab = 2, panel = "Tags", keywords = "custom tag text element font layer anchor" },
	{ label = "Tag reference", page = "unitframes", tab = 2, panel = "Tags", keywords = "tag list reference copy" },
	{ label = "Frame", page = "unitframes", tab = 3, panel = "Player frame", keywords = "player frame position anchor size width height preview enable" },
	{ label = "Power prediction", page = "unitframes", tab = 3, panel = "Player frame", keywords = "power prediction combat border aggro border" },
	{ label = "Name", page = "unitframes", tab = 3, panel = "Player frame", keywords = "name text color position size friendly hostile" },
	{ label = "Health", page = "unitframes", tab = 3, panel = "Text", keywords = "health text power text name status tag position size custom name" },
	{ label = "Debuffs", page = "unitframes", tab = 3, panel = "Player frame", keywords = "debuffs buffs auras icons rules size growth anchor stacks cooldown" },
	{ label = "Frame", page = "unitframes", tab = 4, panel = "Target frame", keywords = "target frame position size auras" },
	{ label = "Frame", page = "unitframes", tab = 5, panel = "Target of target", keywords = "target of target frame position size" },
	{ label = "Frame", page = "unitframes", tab = 6, panel = "Focus frame", keywords = "focus frame position size auras" },
	{ label = "Pet colors", page = "unitframes", tab = 7, panel = "Pet frame", keywords = "pet frame colors health power border custom name" },
	{ label = "Stacking", page = "unitframes", tab = 8, panel = "Boss frames", keywords = "boss frames stacking spacing direction" },
	{ label = "Cast bar", page = "unitframes", tab = 8, panel = "Boss frames", keywords = "boss cast bar texture height icon text colors per boss interrupt ready line" },
	{ label = "Pinned buffs", page = "unitframes", tab = 9, panel = "Filters", keywords = "pinned whitelist buffs debuffs only show" },
	{ label = "Buff blacklist", page = "unitframes", tab = 9, panel = "Filters", keywords = "blacklist filter buff debuff hide spell recently seen built-in share" },
	{ label = "Smooth Bars", page = "settings", tab = 1, panel = "Bar Textures", keywords = "animation smooth unit frames group frames" },

	{ label = "Blizzard settings", page = "cdm", tab = 1, panel = "Cooldown Manager", keywords = "advanced cdm blizzard edit mode settings panel overlay fix always visible show timer hide when inactive" },
	{ label = "Sync settings", page = "cdm", tab = 1, panel = "Behavior", keywords = "sync essential utility share appearance" },
	{ label = "Tooltips", page = "cdm", tab = 1, panel = "Behavior", keywords = "spell tooltip hover icons" },
	{ label = "Buff time on cooldowns", page = "cdm", tab = 1, panel = "Behavior", keywords = "buff duration remaining time cooldown desaturate" },
	{ label = "Move icons individually", page = "cdm", tab = 1, panel = "Behavior", keywords = "detach drag resize snapping reset positions" },
	{ label = "Font", page = "cdm", tab = 1, panel = "Behavior", keywords = "timer stack text font" },
	{ label = "Custom glows", page = "cdm", tab = 1, panel = "Glow and highlights", keywords = "glow proc alert color type speed lines thickness preview pixel autocast button" },
	{ label = "Assisted highlight", page = "cdm", tab = 1, panel = "Glow and highlights", keywords = "assist assisted combat highlight color next spell marker on off" },
	{ label = "Keypress highlight", page = "cdm", tab = 1, panel = "Glow and highlights", keywords = "key press flash tint border style" },
	{ label = "Viewer", page = "cdm", tab = 2, panel = "Essential", keywords = "essential viewer position anchor skin enable preview" },
	{ label = "Rows", page = "cdm", tab = 2, panel = "Essential", keywords = "essential row growth count vertical center last row icons per row" },
	{ label = "Icons", page = "cdm", tab = 2, panel = "Essential", keywords = "essential icon width height size spacing zoom aspect ratio" },
	{ label = "Border", page = "cdm", tab = 2, panel = "Essential", keywords = "essential border color thickness" },
	{ label = "Swipe", page = "cdm", tab = 2, panel = "Essential", keywords = "essential swipe color reverse cooldown sweep bright edge flash ready" },
	{ label = "Cooldown text", page = "cdm", tab = 2, panel = "Text", keywords = "essential cooldown text size position decimals threshold warning color" },
	{ label = "Stack text", page = "cdm", tab = 2, panel = "Text", keywords = "essential stack charges text size position" },
	{ label = "Keybind text", page = "cdm", tab = 2, panel = "Text", keywords = "essential keybind hotkey font size anchor offset color show" },
	{ label = "Viewer", page = "cdm", tab = 3, panel = "Utility", keywords = "utility viewer position anchor skin enable preview" },
	{ label = "Rows", page = "cdm", tab = 3, panel = "Utility", keywords = "utility row growth count vertical center last row icons per row" },
	{ label = "Icons", page = "cdm", tab = 3, panel = "Utility", keywords = "utility icon width height size spacing zoom aspect ratio" },
	{ label = "Border", page = "cdm", tab = 3, panel = "Utility", keywords = "utility border color thickness" },
	{ label = "Swipe", page = "cdm", tab = 3, panel = "Utility", keywords = "utility swipe color reverse cooldown sweep bright edge flash ready" },
	{ label = "Cooldown text", page = "cdm", tab = 3, panel = "Text", keywords = "utility cooldown text size position decimals threshold warning color" },
	{ label = "Stack text", page = "cdm", tab = 3, panel = "Text", keywords = "utility stack charges text size position" },
	{ label = "Keybind text", page = "cdm", tab = 3, panel = "Text", keywords = "utility keybind hotkey font size anchor offset color show" },
	{ label = "Viewer", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons viewer position anchor skin enable preview" },
	{ label = "Rows", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons row growth count vertical center last row icons per row" },
	{ label = "Icons", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons icon width height size spacing zoom aspect ratio" },
	{ label = "Border", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons border color thickness" },
	{ label = "Swipe", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons swipe color reverse cooldown sweep bright edge flash ready" },
	{ label = "Cooldown text", page = "cdm", tab = 4, panel = "Text", keywords = "buff icons cooldown text size position decimals threshold warning color" },
	{ label = "Stack text", page = "cdm", tab = 4, panel = "Text", keywords = "buff icons stack charges text size position" },
	{ label = "Bars", page = "cdm", tab = 5, panel = "Buff bars", keywords = "buff bars position anchor grow direction preview skin enable match width" },
	{ label = "Size", page = "cdm", tab = 5, panel = "Buff bars", keywords = "buff bar width height spacing" },
	{ label = "Icon", page = "cdm", tab = 5, panel = "Buff bars", keywords = "buff bar icon size show" },
	{ label = "Colors", page = "cdm", tab = 5, panel = "Buff bars", keywords = "buff bar color background border" },
	{ label = "Class color bar", page = "cdm", tab = 5, panel = "Buff bars", keywords = "class color bar fill" },
	{ label = "Name", page = "cdm", tab = 5, panel = "Text", keywords = "buff bar name size show" },
	{ label = "Duration", page = "cdm", tab = 5, panel = "Text", keywords = "buff bar duration time size show" },
	{ label = "Stacks", page = "cdm", tab = 5, panel = "Text", keywords = "buff bar stacks applications attach position size offset show" },
	{ label = "New snapshot", page = "cdm", tab = 6, panel = "Layouts", keywords = "save snapshot layout name profile" },
	{ label = "Saved snapshots", page = "cdm", tab = 6, panel = "Layouts", keywords = "apply delete snapshot restore backup profile" },
	{ label = "Export", page = "cdm", tab = 6, panel = "Share", keywords = "export layout string copy share" },
	{ label = "Import", page = "cdm", tab = 6, panel = "Share", keywords = "import layout string paste replace share" },
	{ label = "Viewer", page = "cdm", tab = 7, panel = "Icon management", keywords = "icon management viewer list autosort order hide spells items" },
	{ label = "Bar", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom tracking bar name position anchor x y unlock lock drag eye enable on off" },
	{ label = "Racials", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar racial auto add stoneform blood fury escape artist azerite surge will to survive" },
	{ label = "Hide when not in bags", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar bags empty potion flask hide" },
	{ label = "Tooltips", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar tooltip hover icon" },
	{ label = "Hide the global cooldown", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar gcd swipe global cooldown" },
	{ label = "Trinkets", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar trinket equipped usable auto skip blacklist" },
	{ label = "Icons", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar icon size spacing zoom border color opacity" },
	{ label = "Layout", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar grow direction left right row growth up down max per row strata frame level" },
	{ label = "Font", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar font tracking text" },
	{ label = "Cooldown text", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar cooldown timer text size position offset" },
	{ label = "Stack text", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar stacks charges count text size position offset" },
	{ label = "Add a spell or item", page = "cdm", tab = 8, panel = "Custom bars", keywords = "custom bar track spell item potion flask search add remove reorder drag hide" },
	{ label = "Import", page = "cdm", tab = 9, panel = "Custom bars", keywords = "custom bars import copy character alt duplicate" },


	{ label = "Enable", page = "castbars", tab = 1, keywords = "cast bar player" },
	{ label = "Show Anchor", page = "castbars", tab = 1, keywords = "anchor mover unlock position" },
	{ label = "Anchor Frame", page = "castbars", tab = 1, panel = "Anchor" },
	{ label = "Match Anchor Width", page = "castbars", tab = 1, panel = "Anchor" },
	{ label = "X Position", page = "castbars", tab = 1, panel = "Position" },
	{ label = "Y Position", page = "castbars", tab = 1, panel = "Position" },
	{ label = "Texture", page = "castbars", tab = 1, panel = "Size & Appearance" },
	{ label = "Width", page = "castbars", tab = 1, panel = "Size & Appearance" },
	{ label = "Height", page = "castbars", tab = 1, panel = "Size & Appearance" },
	{ label = "Text Size", page = "castbars", tab = 1, panel = "Size & Appearance" },
	{ label = "Border Size", page = "castbars", tab = 1, panel = "Size & Appearance" },
	{ label = "Bar Color", page = "castbars", tab = 1, panel = "Colors" },
	{ label = "Border Color", page = "castbars", tab = 1, panel = "Colors" },
	{ label = "Background Color", page = "castbars", tab = 1, panel = "Colors" },
	{ label = "Use Class Color", page = "castbars", tab = 1, panel = "Colors" },
	{ label = "Show Icon", page = "castbars", tab = 1, panel = "Display Options" },
	{ label = "Show Timer", page = "castbars", tab = 1, panel = "Display Options" },
	{ label = "Show Total Time", page = "castbars", tab = 1, panel = "Display Options" },
	{ label = "Countdown", page = "castbars", tab = 1, panel = "Display Options" },
	{ label = "Show Spell Name", page = "castbars", tab = 1, panel = "Display Options" },
	{ label = "Name Max Length", page = "castbars", tab = 1, panel = "Display Options" },
	{ label = "Show Latency", page = "castbars", tab = 1, panel = "Display Options", keywords = "lag latency" },
	{ label = "Latency Color", page = "castbars", tab = 1, panel = "Display Options" },
	{ label = "Line Width", page = "castbars", tab = 1, panel = "Empowered Stages", cond = "empower", keywords = "empowered pip" },
	{ label = "Glow", page = "castbars", tab = 1, panel = "Empowered Stages", cond = "empower" },
	{ label = "Pip Color", page = "castbars", tab = 1, panel = "Empowered Stages", cond = "empower" },
	{ label = "Enable", page = "castbars", tab = 1, panel = "Empowered Stages", cond = "empower", keywords = "empowered stage colors background" },
	{ label = "Enable", page = "castbars", tab = 1, panel = "Custom Spell Colors" },
	{ label = "Enable", page = "castbars", tab = 2, keywords = "cast bar target" },
	{ label = "Width", page = "castbars", tab = 2, panel = "Size & Appearance" },
	{ label = "Height", page = "castbars", tab = 2, panel = "Size & Appearance" },
	{ label = "Non-Interruptible", page = "castbars", tab = 2, panel = "Colors", keywords = "interrupt" },
	{ label = "Interrupt On CD", page = "castbars", tab = 2, panel = "Colors" },
	{ label = "Enable", page = "castbars", tab = 3, keywords = "cast bar focus" },
	{ label = "Width", page = "castbars", tab = 3, panel = "Size & Appearance" },
	{ label = "Height", page = "castbars", tab = 3, panel = "Size & Appearance" },
	{ label = "Non-Interruptible", page = "castbars", tab = 3, panel = "Colors" },

	{ label = "Primary bar", page = "power", tab = 1, panel = "Primary power", keywords = "mana rage energy focus power bar source enable anchor unlock position match width" },
	{ label = "Bar instead of a number", page = "power", tab = 1, panel = "Primary power", keywords = "bar mode text mode number" },
	{ label = "Class color", page = "power", tab = 1, panel = "Primary power", keywords = "class color power" },
	{ label = "Bar", page = "power", tab = 1, panel = "Primary power", keywords = "bar color background width height" },
	{ label = "Prediction", page = "power", tab = 1, panel = "Primary power", keywords = "prediction incoming power cast" },
	{ label = "Tick marks", page = "power", tab = 1, panel = "Primary power", keywords = "tick mark threshold color width" },
	{ label = "Bar text", page = "power", tab = 1, panel = "Primary power", keywords = "text font size color percent sign offset layer strata" },
	{ label = "Low power colors", page = "power", tab = 1, panel = "Primary power", keywords = "low power color threshold warning" },
	{ label = "Druid forms", page = "power", tab = 1, panel = "Primary power", keywords = "bear cat moonkin travel form power druid" },
	{ label = "Secondary bar", page = "power", tab = 2, cond = "secondaryPower", panel = "Secondary power", keywords = "combo points runes holy power soul shards chi essence stagger secondary source enable anchor unlock position" },
	{ label = "Segments instead of a number", page = "power", tab = 2, cond = "secondaryPower", panel = "Secondary power", keywords = "segments bar mode number" },
	{ label = "Segments", page = "power", tab = 2, cond = "secondaryPower", panel = "Secondary power", keywords = "active color charged background width height spacing" },
	{ label = "Runes", page = "power", tab = 2, cond = "secondaryPower", panel = "Secondary power", keywords = "rune ready recharging cooldown death knight" },
	{ label = "Count", page = "power", tab = 2, cond = "secondaryPower", panel = "Secondary power", keywords = "count text font size color offset show max" },
	{ label = "Stack", page = "power", tab = 3, panel = "Stacking", keywords = "stacking container gap width match member order cast bar" },
	{ label = "Save power settings", page = "power", panel = "Scope", keywords = "scope profile class spec save copy setup" },
	{ label = "Power and resource colors", page = "power", panel = "Scope", keywords = "power colors appearance resource" },

	{ label = "Enable", page = "auras", sidebar = "petWarnings", panel = "Pet Warnings", keywords = "pet warning" },
	{ label = "Show Anchor", page = "auras", sidebar = "petWarnings", panel = "Pet Warnings" },
	{ label = "X Position", page = "auras", sidebar = "petWarnings", panel = "Position" },
	{ label = "Y Position", page = "auras", sidebar = "petWarnings", panel = "Position" },
	{ label = "Font", page = "auras", sidebar = "petWarnings", panel = "Appearance" },
	{ label = "Font Size", page = "auras", sidebar = "petWarnings", panel = "Appearance" },
	{ label = "Warning Color", page = "auras", sidebar = "petWarnings", panel = "Appearance" },
	{ label = "Pet Not Attacking", page = "auras", sidebar = "petWarnings", panel = "Warning Types" },
	{ label = "Pet Dead / Missing", page = "auras", sidebar = "petWarnings", panel = "Warning Types" },
	{ label = "Grimoire of Sacrifice", page = "auras", sidebar = "petWarnings", panel = "Warning Types" },
	{ label = "Pet Low Health", page = "auras", sidebar = "petWarnings", panel = "Warning Types" },
	{ label = "Enable", page = "auras", sidebar = "combatTimer", panel = "Combat Timer", keywords = "combat timer" },
	{ label = "Show Anchor", page = "auras", sidebar = "combatTimer", panel = "Combat Timer" },
	{ label = "Font Size", page = "auras", sidebar = "combatTimer", panel = "Appearance" },
	{ label = "Text Color", page = "auras", sidebar = "combatTimer", panel = "Appearance" },
	{ label = "Enable", page = "auras", sidebar = "messages", panel = "Combat Messages", keywords = "combat message text" },
	{ label = "Font Size", page = "auras", sidebar = "messages", panel = "Appearance" },
	{ label = "Fade Time", page = "auras", sidebar = "messages", panel = "Appearance" },
	{ label = "Color", page = "auras", sidebar = "messages", panel = "Appearance" },
	{ label = "Enable", page = "auras", sidebar = "crosshair", panel = "Crosshair", keywords = "crosshair reticle" },
	{ label = "Style", page = "auras", sidebar = "crosshair", panel = "Visibility" },
	{ label = "Hide Out of Combat", page = "auras", sidebar = "crosshair", panel = "Visibility" },
	{ label = "Hide in Town", page = "auras", sidebar = "crosshair", panel = "Visibility" },
	{ label = "Size", page = "auras", sidebar = "crosshair", panel = "Appearance" },
	{ label = "Thickness", page = "auras", sidebar = "crosshair", panel = "Appearance" },
	{ label = "Center Gap", page = "auras", sidebar = "crosshair", panel = "Appearance" },
	{ label = "Opacity", page = "auras", sidebar = "crosshair", panel = "Appearance" },
	{ label = "Color", page = "auras", sidebar = "crosshair", panel = "Appearance" },
	{ label = "Range Indicator", page = "auras", sidebar = "crosshair", panel = "Crosshair", keywords = "melee range ranged out of range color" },
	{ label = "Enable", page = "auras", sidebar = "lowHpWarning", panel = "Low HP Warning", keywords = "low health warning hp" },
	{ label = "Show Anchor", page = "auras", sidebar = "lowHpWarning", panel = "Low HP Warning" },
	{ label = "Threshold %", page = "auras", sidebar = "lowHpWarning", panel = "Low HP Warning" },
	{ label = "Font Size", page = "auras", sidebar = "lowHpWarning", panel = "Appearance" },
	{ label = "Text Color", page = "auras", sidebar = "lowHpWarning", panel = "Appearance" },

	{ label = "Enable", page = "minimap", keywords = "minimap map" },
	{ label = "Show Anchor", page = "minimap", keywords = "anchor mover unlock position" },
	{ label = "Size in pixels", page = "minimap", panel = "Appearance", keywords = "scale size pixels position mover" },
	{ label = "Border Width", page = "minimap", panel = "Appearance", keywords = "border width position mover" },
	{ label = "Indicators", page = "minimap", panel = "Appearance", keywords = "difficulty mail crafting orders garrison mission indicators shape cog" },
	{ label = "24-Hour Format", page = "minimap", panel = "Appearance" },
	{ label = "Server Time", page = "minimap", panel = "Appearance" },
	{ label = "Position", page = "minimap", panel = "Appearance", keywords = "position from right from top rotate show anchor move" },
	{ label = "Enable", page = "minimap", panel = "Datatext", keywords = "datatext minimap bar" },
	{ label = "Modules", page = "minimap", panel = "Datatext", keywords = "datatext modules order ping fps latency" },
	{ label = "Text", page = "minimap", panel = "Datatext", keywords = "datatext font size color anchor position background border" },

	{ label = "Enable", page = "datatext", keywords = "datatext info bar module on off" },
	{ label = "Unlock", page = "datatext", keywords = "anchor mover unlock lock drag position eye" },
	{ label = "Bars", page = "datatext", panel = "Bars and panels", keywords = "bar select new add delete second multiple bars shown sample" },
	{ label = "Panels", page = "datatext", panel = "Bars and panels", keywords = "panel blank background square empty new add delete resize shown" },
	{ label = "Title", page = "datatext", panel = "Bars and panels", keywords = "panel title text label anchor offset size color header" },
	{ label = "Mouseover and tooltips", page = "datatext", panel = "Bars and panels", keywords = "only on mouseover hide bar fade hover show tooltip combat latency friends guild roster member mplus score rank rio disable behavior" },
	{ label = "Font", page = "datatext", panel = "Bars and panels" },
	{ label = "Font size", page = "datatext", panel = "Bars and panels", keywords = "font size" },
	{ label = "Spacing", page = "datatext", panel = "Bars and panels", keywords = "spacing gap" },
	{ label = "Orientation", page = "datatext", panel = "Bars and panels", keywords = "orientation vertical horizontal text align stack hide labels" },
	{ label = "Value color", page = "datatext", panel = "Bars and panels" },
	{ label = "Position", page = "datatext", panel = "Bars and panels", keywords = "anchor x y offset strata frame level align below minimap mirror chat" },
	{ label = "Background", page = "datatext", panel = "Bars and panels", keywords = "background opacity color border width height" },
	{ label = "Ping source", page = "datatext", panel = "Datatexts", keywords = "ping source home world" },
	{ label = "Datatexts", page = "datatext", panel = "Datatexts", keywords = "fps framerate ping latency durability gold ilvl item level coords location loot spec specialization talent loadout friends guild modules order time clock" },

	{ label = "Enable", page = "chat", keywords = "chat skin enable" },
	{ label = "Panel", page = "chat", panel = "Panel", keywords = "chat font background border edit box position size padding lock move resize" },
	{ label = "Tabs", page = "chat", panel = "Tabs", keywords = "chat tabs style font uppercase combat log color opacity flash" },
	{ label = "Messages", page = "chat", panel = "Messages", keywords = "chat timestamps links channel abbreviate fade history copy voice buttons hide scroll" },
	{ label = "Enable", page = "objectivetracker", keywords = "objective tracker quest skin enable" },
	{ label = "Text", page = "objectivetracker", panel = "Text", keywords = "objective tracker quest font size outline single line wrap colors title hover objective completed ready time left" },
	{ label = "Panel", page = "objectivetracker", panel = "Panel", keywords = "objective tracker quest background texture tint opacity border separator lines" },
	{ label = "Quests", page = "objectivetracker", panel = "Quests", keywords = "objective tracker quest header icons dashes tooltips completion messages sound hide item button key" },

	{ label = "Enable", page = "cursor", keywords = "cursor ring circle enable" },
	{ label = "Cursor size", page = "cursor", panel = "General", keywords = "cursor ring size diameter" },
	{ label = "Only in combat", page = "cursor", panel = "Visibility", keywords = "cursor combat hide show" },
	{ label = "Rings", page = "cursor", panel = "Rings", keywords = "cursor ring main inner outer behavior color size offset layer click gcd cast" },

	{ label = "Cooldown Announcer", page = "auras", tab = 1, panel = "General", keywords = "cd announcer cooldown countdown ready alert tts speak" },
	{ label = "Announcements", page = "cdAnnouncer", tab = 1, panel = "Announcer", keywords = "cooldown announcer font growth position color anchor" },
	{ label = "Hide unusable spells", page = "cdAnnouncer", tab = 1, panel = "Announcer", keywords = "unusable unknown spells skip" },
	{ label = "Add a cooldown", page = "cdAnnouncer", tab = 1, panel = "Cooldowns", keywords = "track spell item cooldown add remove reorder countdown ready speak tts sound" },
	{ label = "Cooldown Flash", page = "auras", tab = 1, panel = "General", keywords = "cooldown flash icon ready off cooldown buff sweep spec weakaura" },
	{ label = "Secondary Stats", page = "auras", tab = 1, panel = "General", keywords = "secondary stats crit haste mastery versatility vers rating percent readout weakaura" },
	{ label = "Stats", page = "secondaryStats", tab = 1, panel = "Stats", keywords = "primary agility strength intellect stamina crit haste mastery versatility leech avoidance speed color order show hide" },
	{ label = "Readout", page = "secondaryStats", tab = 1, panel = "Text", keywords = "stats font size align rating percent combat only position" },
	{ label = "New group", page = "auras", tab = 1, panel = "General", keywords = "group folder organize drag weakaura" },
	{ label = "Add a spell", page = "cooldownFlash", tab = 1, panel = "Spells", keywords = "cooldown flash spell add remove reorder per spec size color glow text sound tts opacity position" },
	{ label = "Pack Leader", page = "auras", tab = 3, panel = "Class", keywords = "pack leader beast cycle wyvern bear boar hunter" },
	{ label = "Kill Command overlay", page = "auras", tab = 3, panel = "Class", keywords = "kill command overlay timer beast name" },
	{ label = "Tip of the Spear", page = "auras", tab = 3, panel = "Class", keywords = "tip spear stacks bars survival width height spacing border filled empty color" },
	{ label = "Smart Misdirection", page = "auras", tab = 3, panel = "Class", keywords = "misdirect smart tank focus pet macro" },
	{ label = "Misdirect alert", page = "auras", tab = 3, panel = "Class", keywords = "misdirection target text alert" },
	{ label = "Hunter's Mark", page = "auras", tab = 3, panel = "Class", keywords = "hunters mark missing target callout hunter" },
	{ label = "Precise Shots", page = "auras", tab = 3, panel = "Class", keywords = "precise shots lock and load bulletstorm marksmanship text alert" },
	{ label = "Vivacious Vivification", page = "auras", tab = 3, panel = "Class", keywords = "mistweaver vivify instant reminder" },
	{ label = "Lifebloom refresh", page = "auras", tab = 3, panel = "Class", keywords = "restoration druid lifebloom refresh" },
	{ label = "Clearcasting", page = "auras", tab = 3, panel = "Class", keywords = "druid feral restoration clearcasting omen of clarity free proc" },
	{ label = "Arcane Salvo", page = "auras", tab = 3, panel = "Class", keywords = "arcane mage salvo stacks barrage missiles" },

	{ label = "Enable", page = "auras", tab = 2, panel = "GCD History", keywords = "gcd history streamer" },
	{ label = "Preview", page = "auras", tab = 2, panel = "GCD History", keywords = "gcd anchor unlock drag" },
	{ label = "Icons", page = "auras", tab = 2, panel = "Display", keywords = "gcd icon size max spacing zoom border" },
	{ label = "Grow Direction", page = "auras", tab = 2, panel = "Display", keywords = "gcd left right" },
	{ label = "Border Color", page = "auras", tab = 2, panel = "Display", keywords = "gcd" },
	{ label = "Position", page = "auras", tab = 2, panel = "Display", keywords = "gcd anchor frame offset" },
	{ label = "Active Cast", page = "auras", tab = 2, panel = "Behavior", keywords = "gcd cast scale channel" },
	{ label = "Auto-Expire", page = "auras", tab = 2, panel = "Behavior", keywords = "gcd fade lifetime" },
	{ label = "Hide Auto Attacks", page = "auras", tab = 2, panel = "Behavior", keywords = "gcd" },
	{ label = "Debug to Chat", page = "auras", tab = 2, panel = "Behavior", keywords = "gcd" },
	{ label = "Blacklist", page = "auras", tab = 2, panel = "Blacklist", keywords = "gcd spell ignore" },

	{ label = "Use Class Color", page = "settings", tab = 1, panel = "Accent", keywords = "theme color accent class" },
	{ label = "Accent Color", page = "settings", tab = 1, panel = "Accent", keywords = "theme color accent" },
	{ label = "Global Bar Texture", page = "settings", tab = 1, panel = "Bar Textures", keywords = "texture statusbar" },
	{ label = "Gradient Tint", page = "settings", tab = 1, panel = "Bar Textures", keywords = "gradient color texture" },
	{ label = "Global Font", page = "settings", tab = 1, panel = "Fonts", keywords = "font typeface" },
	{ label = "Slug Rendering", page = "settings", tab = 1, panel = "Fonts", keywords = "font slug outline thick" },
	{ label = "Dispel Type Colors", page = "settings", tab = 1, panel = "Dispel Types", keywords = "dispel magic curse poison disease bleed color shared palette" },
	{ label = "Window size", page = "settings", tab = 7, panel = "Window", keywords = "window scale size smaller bigger shrink options" },
	{ label = "Hotkey text", page = "actionbars", sidebar = "general", panel = "Button text", keywords = "action bar keybind text size anchor color" },
	{ label = "Count text", page = "actionbars", sidebar = "general", panel = "Button text", keywords = "action bar stack charges count text" },
	{ label = "Macro text", page = "actionbars", sidebar = "general", panel = "Button text", keywords = "action bar macro name text" },
	{ label = "Cooldown text", page = "actionbars", sidebar = "general", panel = "Button text", keywords = "action bar cooldown countdown decimals warning seconds color" },
	{ label = "Item rank", page = "actionbars", sidebar = "general", panel = "Button text", keywords = "crafting quality badge potion flask rank" },
	{ label = "Border", page = "actionbars", sidebar = "general", panel = "Buttons", keywords = "action bar button border outline color thickness" },
	{ label = "Empty buttons", page = "actionbars", sidebar = "general", panel = "Buttons", keywords = "action bar empty slot background opacity" },
	{ label = "Key presses", page = "actionbars", sidebar = "general", panel = "Buttons", keywords = "action bar key press flash" },
	{ label = "Proc glow", page = "actionbars", sidebar = "general", panel = "Buttons", keywords = "action bar proc glow style speed" },
	{ label = "Cast animation", page = "actionbars", sidebar = "general", panel = "Buttons", keywords = "cast animation sweep burst assisted combat" },
	{ label = "Keybind mode", page = "actionbars", sidebar = "general", panel = "Keybinds and moving", keywords = "keybind mode bind hover key" },
	{ label = "Lock buttons", page = "actionbars", sidebar = "general", panel = "Keybinds and moving", keywords = "action bar lock pick up key shift" },
	{ label = "Unlock bars", page = "actionbars", sidebar = "general", panel = "Keybinds and moving", keywords = "action bar move drag snap" },
	{ label = "Bar 1", page = "actionbars", sidebar = "bar1", panel = "Bar 1", keywords = "action bar position anchor center fill strata enable" },
	{ label = "Buttons", page = "actionbars", sidebar = "bar1", panel = "Bar 1", keywords = "action bar buttons count per row size height spacing scale" },
	{ label = "Mouseover fade", page = "actionbars", sidebar = "bar1", panel = "Bar 1", keywords = "action bar fade mouseover opacity" },
	{ label = "Page switching", page = "actionbars", sidebar = "bar1", panel = "Bar 1", keywords = "action bar paging modifier ctrl alt shift vehicle stance page" },
	{ label = "Pet bar", page = "actionbars", sidebar = "pet", panel = "Pet bar", keywords = "pet bar action buttons autocast hunter warlock" },
	{ label = "Stance bar", page = "actionbars", sidebar = "stance", panel = "Stance bar", keywords = "stance form shapeshift bar druid warrior" },
	{ label = "Vehicle exit", page = "actionbars", sidebar = "vehicle", panel = "Vehicle exit", keywords = "vehicle exit leave taxi possess button click through" },
	{ label = "Micro menu", page = "actionbars", sidebar = "micro", panel = "Micro menu", keywords = "micro menu buttons character spellbook bar click through" },
	{ label = "Bag bar", page = "actionbars", sidebar = "bags", panel = "Bag bar", keywords = "bag bar backpack buttons single bag scale" },
	{ label = "Extra action", page = "actionbars", sidebar = "extra", panel = "Extra action", keywords = "extra action zone ability button blizzard art click through" },
	{ label = "Volume", page = "settings", tab = 2, panel = "Voice and sound", keywords = "tts voice speech volume loudness audio" },
	{ label = "Alert sound channel", page = "settings", tab = 2, panel = "Voice and sound", keywords = "sound channel master sfx audio alerts" },
	{ label = "Faster Looting", page = "qol", tab = 3, panel = "Looting", keywords = "loot speed auto fast" },
	{ label = "Auto-Sell Junk", page = "qol", tab = 3, panel = "Looting", keywords = "vendor sell grey trash" },
	{ label = "Auto-Repair", page = "qol", tab = 3, panel = "Merchant", keywords = "repair gold" },
	{ label = "Use Guild Funds", page = "qol", tab = 3, panel = "Merchant" },
	{ label = "Show Repair Cost", page = "qol", tab = 3, panel = "Merchant" },
	{ label = "Auto-Accept & Gossip", page = "qol", tab = 3, panel = "Questing", keywords = "quest auto accept gossip" },
	{ label = "Auto-Complete", page = "qol", tab = 3, panel = "Questing", keywords = "quest auto complete turn in" },
	{ label = "Skip Movies", page = "qol", tab = 3, panel = "Questing", keywords = "cinematic movie skip" },
	{ label = "Cast on Key Down", page = "qol", tab = 1, panel = "Casting", keywords = "key down press" },
	{ label = "Auto Keystone", page = "qol", tab = 1, panel = "Casting", keywords = "mythic keystone auto insert" },
	{ label = "Auto Combat Log", page = "qol", tab = 1, panel = "Combat Logging", keywords = "combat log logging warcraft logs record auto" },
	{ label = "Logging Indicator", page = "qol", tab = 1, panel = "Combat Logging", keywords = "combat log indicator recording dot" },
	{ label = "Advanced Logging", page = "qol", tab = 1, panel = "Combat Logging", keywords = "advanced combat logging warcraft logs cvar" },
	{ label = "Spell Queue (ms)", page = "qol", tab = 1, panel = "Casting", keywords = "spell queue window spellqueue" },
	{ label = "Auto-Accept Party", page = "qol", tab = 3, panel = "Social" },
	{ label = "Include Guild", page = "qol", tab = 3, panel = "Social" },
	{ label = "Auto-Confirm Role", page = "qol", tab = 3, panel = "Social" },
	{ label = "Easy Item Destroy", page = "qol", tab = 2, panel = "Interface", keywords = "delete destroy confirm" },
	{ label = "Hide Talking Head", page = "qol", tab = 2, panel = "Interface" },
	{ label = "Hide Rested Zzz", page = "qol", tab = 2, panel = "Interface" },
	{ label = "Hide Zone Text", page = "qol", tab = 2, panel = "Interface" },
	{ label = "Hide Error Msgs", page = "qol", tab = 2, panel = "Interface", keywords = "error red text" },
	{ label = "FPS preset", page = "qol", tab = 4, panel = "Graphics", keywords = "fps cvar performance graphics vsync apply" },
	{ label = "Restore", page = "qol", tab = 4, panel = "Graphics", keywords = "fps cvar restore original" },
	{ label = "Reset BluUI", page = "qol", tab = 5, panel = "Danger zone", keywords = "reset wipe default settings" },
	{ label = "Celebrations", page = "qol", tab = 6, panel = "Celebrations", keywords = "confetti mythic plus m+ key timed boss kill raid dungeon celebrate" },
	{ label = "Unit Frames", page = "settings", tab = 5, panel = "Modules", keywords = "enable disable module" },
	{ label = "Cooldown Manager", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Cast Bars", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Power Bars", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Minimap", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Auras", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Buff Tracking", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Datatext", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Cursor", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Streamer Tools", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Gem Manager", page = "settings", tab = 5, panel = "Modules" },

	{ label = "Switch profile with spec", page = "exportimport", tab = 1, panel = "Spec profiles", keywords = "export import profile share spec" },

	{ label = "Hide the Blizzard frames", page = "unitframes", tab = 10, panel = "Group frames", keywords = "blizzard default frames hide group party raid enable" },
	{ label = "Click casting", page = "unitframes", tab = 10, panel = "Group frames", keywords = "click cast mouse clique" },
	{ label = "Fade out of range", page = "unitframes", tab = 10, panel = "Group frames", keywords = "range fade alpha distance offline" },
	{ label = "Party frames", page = "unitframes", tab = 11, panel = "Party", keywords = "party frames position anchor preview enable" },
	{ label = "Sorting", page = "unitframes", tab = 11, panel = "Party", keywords = "sort role class order party slot" },
	{ label = "Visibility", page = "unitframes", tab = 11, panel = "Party", keywords = "self solo raid group show" },
	{ label = "Frames", page = "unitframes", tab = 11, panel = "Party", keywords = "width height spacing texture vertical" },
	{ label = "Power bar", page = "unitframes", tab = 11, panel = "Party", keywords = "power bar show hide height healer mana" },
	{ label = "Health and colors", page = "unitframes", tab = 11, panel = "Appearance", keywords = "class color health border background transparent dead opacity" },
	{ label = "Damage absorb", page = "unitframes", tab = 11, panel = "Appearance", keywords = "absorb shield heal texture direction" },
	{ label = "Target border", page = "unitframes", tab = 11, panel = "Appearance", keywords = "target mouseover border highlight" },
	{ label = "Font", page = "unitframes", tab = 11, panel = "Text", keywords = "font name text" },
	{ label = "Name", page = "unitframes", tab = 11, panel = "Text", keywords = "name length truncate letters max" },
	{ label = "Health text", page = "unitframes", tab = 11, panel = "Text", keywords = "health percent text format absorb" },
	{ label = "Power text", page = "unitframes", tab = 11, panel = "Text", keywords = "power mana text" },
	{ label = "Status text", page = "unitframes", tab = 11, panel = "Text", keywords = "dead ghost offline afk dnd status" },
	{ label = "Mythic+ key", page = "unitframes", tab = 11, panel = "Text", keywords = "keystone mythic plus key party" },
	{ label = "Role icon", page = "unitframes", tab = 11, panel = "Indicators", keywords = "role leader raid marker resurrect ready check combat icon" },
	{ label = "Unit tooltips", page = "unitframes", tab = 11, panel = "Tooltips", keywords = "tooltip aura buff debuff" },
	{ label = "Raid frames", page = "unitframes", tab = 12, panel = "Raid", keywords = "raid frames position preview enable" },
	{ label = "Role icons", page = "unitframes", tab = 12, panel = "Raid", keywords = "raid role icon tank healer" },
	{ label = "Large raid layout", page = "unitframes", tab = 12, panel = "Raid", keywords = "large raid size threshold groups per row spacing" },
	{ label = "Power bar", page = "unitframes", tab = 12, panel = "Raid", keywords = "raid power bar show hide height healer mana" },
	{ label = "Buffs", page = "unitframes", tab = 13, panel = "Party auras", keywords = "party aura buff debuff defensive crowd control icons rules" },
	{ label = "Dispel highlight", page = "unitframes", tab = 13, panel = "Party auras", keywords = "dispel debuff highlight tint badge magic curse poison disease" },
	{ label = "Dispel type colors", page = "unitframes", tab = 13, panel = "Party auras", keywords = "dispel color magic curse poison disease bleed shared palette" },
	{ label = "Buffs", page = "unitframes", tab = 14, panel = "Raid auras", keywords = "raid aura buff debuff defensive crowd control icons rules" },
	{ label = "Dispel highlight", page = "unitframes", tab = 14, panel = "Raid auras", keywords = "raid dispel highlight tint badge" },
	{ label = "Debuff blacklist", page = "unitframes", tab = 15, panel = "Filters", keywords = "blacklist filter debuff buff hide spell recently seen built-in share" },
}

local pageTitles = {}
local tabNames = {}

local HAS_SECONDARY_POWER = {
	DEATHKNIGHT = true, ROGUE = true, WARLOCK = true, PALADIN = true, EVOKER = true,
	DRUID = true, MONK = true, MAGE = true, PRIEST = true, SHAMAN = true,
}
local condChecks = {
	secondaryPower = function()
		local _, className = UnitClass('player')
		return HAS_SECONDARY_POWER[className] == true
	end,
	empower = function()
		return BUI.Tools.PlayerCanEmpower()
	end,
	module = function(moduleName)
		local db = BUI.GetDB()
		if not db then return true end
		return db.modules[moduleName] ~= false
	end,
}
local function CheckCond(condition)
	if not condition then return true end
	local check = condChecks[condition]
	if check then return check() end
	local moduleName = condition:match('^module:(.+)')
	if moduleName then return condChecks.module(moduleName) end
	return true
end

local function EnsureTitles()
	if next(pageTitles) then return end
	local engine = BUI.PageEngine
	if not engine or not engine.pages then return end
	for pageId, pageConfig in pairs(engine.pages) do
		pageTitles[pageId] = pageConfig.buttonText or pageConfig.title or pageId
	end
end

function SearchIndex.RegisterTabNames(pageId, names)
	tabNames[pageId] = names
end

function SearchIndex.Search(query)
	if not query or query == '' then return {} end
	EnsureTitles()
	query = query:lower()
	local results = {}
	for _, entry in ipairs(entries) do
		if CheckCond(entry.cond) then
			local haystack = (entry.label .. ' ' .. (entry.panel or '') .. ' ' .. (pageTitles[entry.page] or entry.page) .. ' ' .. (entry.keywords or '')):lower()
			if haystack:find(query, 1, true) then
				local tabs = tabNames[entry.page]
				local tabName = tabs and tabs[entry.tab] or nil
				if entry.sidebar then tabName = entry.panel end
				results[#results + 1] = {
					label = entry.label,
					page = entry.page,
					pageTitle = pageTitles[entry.page] or entry.page,
					tab = entry.tab,
					sidebar = entry.sidebar,
					tabName = tabName,
					panel = entry.panel,
				}
				if #results >= 30 then break end
			end
		end
	end
	return results
end

SearchIndex.RegisterTabNames('auras', { 'General', 'GCD History', 'Class' })
SearchIndex.RegisterTabNames('power', { 'Primary', 'Secondary', 'Stacking' })
SearchIndex.RegisterTabNames('cdm', { 'General', 'Essential', 'Utility', 'Buff icons', 'Buff bars', 'Layouts', 'Icon management' })
SearchIndex.RegisterTabNames('castbars', { 'Player', 'Target', 'Focus' })
SearchIndex.RegisterTabNames('unitframes', { 'Appearance', 'Tags', 'Player', 'Target', 'Target of target', 'Focus', 'Pet', 'Boss', 'Filters', 'Groups', 'Party', 'Raid', 'Party auras', 'Raid auras', 'Group filters' })
SearchIndex.RegisterTabNames('settings', { 'Appearance', 'Sound', 'Skinning', 'Visibility', 'Modules', 'Help', 'Theme' })
SearchIndex.RegisterTabNames('qol', { 'Combat', 'Interface', 'Automation', 'Graphics', 'Danger zone' })
