local _, BUI = ...

BUI.SearchIndex = {}
local SearchIndex = BUI.SearchIndex

local entries = {
	{ label = "Look", page = "unitframes", tab = 1, panel = "Appearance", keywords = "unit frame texture font statusbar enable test mode" },
	{ label = "Tooltips", page = "unitframes", tab = 1, panel = "Appearance", keywords = "tooltip click to target decimal abbreviations" },
	{ label = "Sync target and pet to the player", page = "unitframes", tab = 1, panel = "Appearance", keywords = "sync copy player target pet look" },
	{ label = "Health bar", page = "unitframes", tab = 1, panel = "Appearance", keywords = "health color background border class color transparent" },
	{ label = "Damage absorb", page = "unitframes", tab = 1, panel = "Appearance", keywords = "absorb shield heal absorb texture direction preview" },
	{ label = "Power bar", page = "unitframes", tab = 1, panel = "Appearance", keywords = "power color resource type class reaction" },
	{ label = "Dispel highlight", page = "unitframes", tab = 1, panel = "Appearance", keywords = "dispel debuff highlight border bar type icons cleanse callouts recolor blend colors" },
	{ label = "Name tag", page = "unitframes", tab = 1, panel = "Appearance", keywords = "default tags name health power format reset" },
	{ label = "Raid icon", page = "unitframes", tab = 1, panel = "Appearance", keywords = "raid marker leader icon indicators position size" },
	{ label = "Custom tags", page = "unitframes", tab = 3, panel = "Tags", keywords = "custom tag text element font layer anchor" },
	{ label = "Tag reference", page = "unitframes", tab = 2, panel = "Tags", keywords = "tag list reference copy" },
	{ label = "Frame", page = "unitframes", tab = 4, panel = "Player frame", keywords = "player frame position anchor size width height preview enable" },
	{ label = "Power prediction", page = "unitframes", tab = 4, panel = "Player frame", keywords = "power prediction combat border aggro border" },
	{ label = "Name", page = "unitframes", tab = 4, panel = "Player frame", keywords = "name text color position size friendly hostile" },
	{ label = "Health text", page = "unitframes", tab = 4, panel = "Player frame", keywords = "health text power text power bar tag position size" },
	{ label = "Debuffs", page = "unitframes", tab = 4, panel = "Player frame", keywords = "debuffs buffs auras icons rules size growth anchor stacks cooldown" },
	{ label = "Frame", page = "unitframes", tab = 5, panel = "Target frame", keywords = "target frame position size auras" },
	{ label = "Frame", page = "unitframes", tab = 6, panel = "Target of target", keywords = "target of target frame position size" },
	{ label = "Frame", page = "unitframes", tab = 7, panel = "Focus frame", keywords = "focus frame position size auras" },
	{ label = "Pet colors", page = "unitframes", tab = 8, panel = "Pet frame", keywords = "pet frame colors health power border custom name" },
	{ label = "Stacking", page = "unitframes", tab = 9, panel = "Boss frames", keywords = "boss frames stacking spacing direction" },
	{ label = "Cast bar", page = "unitframes", tab = 9, panel = "Boss frames", keywords = "boss cast bar texture height icon text colors per boss interrupt ready line" },
	{ label = "Pinned buffs", page = "unitframes", tab = 10, panel = "Filters", keywords = "pinned whitelist buffs debuffs only show" },
	{ label = "Buff blacklist", page = "unitframes", tab = 10, panel = "Filters", keywords = "blacklist filter buff debuff hide spell recently seen built-in share" },
	{ label = "Smooth Bars", page = "settings", tab = 1, panel = "Bar Textures", keywords = "animation smooth unit frames group frames" },

	{ label = "Shortcuts", page = "cdm", tab = 1, panel = "Cooldown Manager", keywords = "advanced cdm blizzard edit mode settings panel" },
	{ label = "Edit Mode setup", page = "cdm", tab = 1, panel = "Cooldown Manager", keywords = "edit mode visibility fix always visible show timer hide when inactive" },
	{ label = "Sync settings", page = "cdm", tab = 1, panel = "Behavior", keywords = "sync essential utility buff icons share appearance" },
	{ label = "Blizzard panel overlay", page = "cdm", tab = 1, panel = "Behavior", keywords = "blizzard cooldown viewer settings overlay" },
	{ label = "Tooltips", page = "cdm", tab = 1, panel = "Behavior", keywords = "spell tooltip hover icons" },
	{ label = "Buff duration", page = "cdm", tab = 1, panel = "Behavior", keywords = "remaining time buff icons desaturate" },
	{ label = "Cooldown flash", page = "cdm", tab = 1, panel = "Behavior", keywords = "flash animation cooldown complete" },
	{ label = "Cooldown edge", page = "cdm", tab = 1, panel = "Behavior", keywords = "bright edge cooldown sweep" },
	{ label = "Move icons individually", page = "cdm", tab = 1, panel = "Behavior", keywords = "detach drag resize snapping reset positions" },
	{ label = "Font", page = "cdm", tab = 1, panel = "Behavior", keywords = "timer stack text font" },
	{ label = "Custom glows", page = "cdm", tab = 1, panel = "Glow and highlights", keywords = "glow proc alert color type speed lines thickness preview pixel autocast button" },
	{ label = "Assisted highlight", page = "cdm", tab = 1, panel = "Glow and highlights", keywords = "assist assisted combat highlight color" },
	{ label = "Keypress highlight", page = "cdm", tab = 1, panel = "Glow and highlights", keywords = "key press flash tint border style" },
	{ label = "Viewer", page = "cdm", tab = 2, panel = "Essential", keywords = "essential viewer position anchor skin enable preview" },
	{ label = "Rows", page = "cdm", tab = 2, panel = "Essential", keywords = "essential row growth count vertical center last row icons per row" },
	{ label = "Icons", page = "cdm", tab = 2, panel = "Essential", keywords = "essential icon width height size spacing zoom aspect ratio" },
	{ label = "Border", page = "cdm", tab = 2, panel = "Essential", keywords = "essential border color thickness" },
	{ label = "Swipe", page = "cdm", tab = 2, panel = "Essential", keywords = "essential swipe color reverse cooldown sweep" },
	{ label = "Cooldown text", page = "cdm", tab = 2, panel = "Text", keywords = "essential cooldown text size position decimals threshold warning color" },
	{ label = "Stack text", page = "cdm", tab = 2, panel = "Text", keywords = "essential stack charges text size position" },
	{ label = "Keybind text", page = "cdm", tab = 2, panel = "Text", keywords = "essential keybind hotkey font size anchor offset color show" },
	{ label = "Viewer", page = "cdm", tab = 3, panel = "Utility", keywords = "utility viewer position anchor skin enable preview" },
	{ label = "Rows", page = "cdm", tab = 3, panel = "Utility", keywords = "utility row growth count vertical center last row icons per row" },
	{ label = "Icons", page = "cdm", tab = 3, panel = "Utility", keywords = "utility icon width height size spacing zoom aspect ratio" },
	{ label = "Border", page = "cdm", tab = 3, panel = "Utility", keywords = "utility border color thickness" },
	{ label = "Swipe", page = "cdm", tab = 3, panel = "Utility", keywords = "utility swipe color reverse cooldown sweep" },
	{ label = "Cooldown text", page = "cdm", tab = 3, panel = "Text", keywords = "utility cooldown text size position decimals threshold warning color" },
	{ label = "Stack text", page = "cdm", tab = 3, panel = "Text", keywords = "utility stack charges text size position" },
	{ label = "Keybind text", page = "cdm", tab = 3, panel = "Text", keywords = "utility keybind hotkey font size anchor offset color show" },
	{ label = "Viewer", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons viewer position anchor skin enable preview" },
	{ label = "Rows", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons row growth count vertical center last row icons per row" },
	{ label = "Icons", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons icon width height size spacing zoom aspect ratio" },
	{ label = "Border", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons border color thickness" },
	{ label = "Swipe", page = "cdm", tab = 4, panel = "Buff icons", keywords = "buff icons swipe color reverse cooldown sweep" },
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
	{ label = "Scale", page = "minimap", panel = "Appearance", keywords = "scale size position mover" },
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
	{ label = "Hide tooltips in combat", page = "datatext", panel = "Tooltips", keywords = "tooltip hover combat hide latency friends guild mouseover" },
	{ label = "Roster tooltips", page = "datatext", panel = "Tooltips", keywords = "guild friends member tooltip mplus score rank rio hover disable" },
	{ label = "Font", page = "datatext", panel = "Bars and panels" },
	{ label = "Font size", page = "datatext", panel = "Bars and panels", keywords = "font size" },
	{ label = "Spacing", page = "datatext", panel = "Bars and panels", keywords = "spacing gap" },
	{ label = "Orientation", page = "datatext", panel = "Bars and panels", keywords = "orientation vertical horizontal text align stack hide labels" },
	{ label = "Value color", page = "datatext", panel = "Bars and panels" },
	{ label = "Position", page = "datatext", panel = "Bars and panels", keywords = "anchor x y offset strata frame level align below minimap mirror chat" },
	{ label = "Background", page = "datatext", panel = "Bars and panels", keywords = "background opacity color border width height" },
	{ label = "Ping source", page = "datatext", panel = "Datatexts", keywords = "ping source home world" },
	{ label = "Datatexts", page = "datatext", panel = "Datatexts", keywords = "fps framerate ping latency durability gold ilvl item level coords location loot spec friends guild modules order time clock" },

	{ label = "Enable", page = "cursor", keywords = "cursor ring circle enable" },
	{ label = "Cursor Size", page = "cursor", panel = "General", keywords = "cursor ring size" },
	{ label = "Show Only In Combat", page = "cursor", panel = "General" },

	{ label = "Enable", page = "customBars", tab = 1, keywords = "tracking custom bar item on off" },
	{ label = "Unlock", page = "customBars", tab = 1, keywords = "anchor mover unlock lock drag position eye" },
	{ label = "Trinkets", page = "customBars", tab = 1, panel = "Bars", keywords = "trinket equipped usable auto skip blacklist" },
	{ label = "Racials", page = "customBars", tab = 1, panel = "Bars", keywords = "racial auto add stoneform blood fury escape artist azerite surge will to survive" },
	{ label = "Hide when not in bags", page = "customBars", tab = 1, panel = "Bars", keywords = "bags empty potion flask hide" },
	{ label = "Tooltips", page = "customBars", tab = 1, panel = "Bars", keywords = "tooltip hover icon" },
	{ label = "Hide the global cooldown", page = "customBars", tab = 1, panel = "Bars", keywords = "gcd swipe global cooldown" },
	{ label = "Bar", page = "customBars", tab = 1, panel = "Bars", keywords = "name icon size spacing zoom border color opacity position anchor x y" },
	{ label = "Layout", page = "customBars", tab = 1, panel = "Bars", keywords = "grow direction left right row growth up down max per row strata frame level" },
	{ label = "Font", page = "customBars", tab = 1, panel = "Bars", keywords = "font tracking text" },
	{ label = "Cooldown text", page = "customBars", tab = 1, panel = "Bars", keywords = "cooldown timer text size position offset" },
	{ label = "Stack text", page = "customBars", tab = 1, panel = "Bars", keywords = "stacks charges count text size position offset" },
	{ label = "Add a spell or item", page = "customBars", tab = 1, panel = "Tracked spells and items", keywords = "track spell item potion flask search add remove reorder drag hide" },
	{ label = "Import", page = "customBars", panel = "Settings", keywords = "import copy character alt bars duplicate" },

	{ label = "Cooldown Announcer", page = "auras", tab = 1, panel = "Alerts", keywords = "cd announcer cooldown countdown ready alert tts speak" },
	{ label = "Announcements", page = "cdAnnouncer", tab = 1, panel = "Announcer", keywords = "cooldown announcer font growth position color anchor" },
	{ label = "Hide unusable spells", page = "cdAnnouncer", tab = 1, panel = "Announcer", keywords = "unusable unknown spells skip" },
	{ label = "Add a cooldown", page = "cdAnnouncer", tab = 1, panel = "Cooldowns", keywords = "track spell item cooldown add remove reorder countdown ready speak tts sound" },
	{ label = "Buff tracking module", page = "auras", tab = 3, panel = "Class", keywords = "buff tracking module reload" },
	{ label = "Pack Leader", page = "auras", tab = 3, panel = "Class", keywords = "pack leader beast cycle wyvern bear boar hunter" },
	{ label = "Kill Command overlay", page = "auras", tab = 3, panel = "Class", keywords = "kill command overlay timer beast name" },
	{ label = "Bestial Wrath callout", page = "auras", tab = 3, panel = "Class", keywords = "bestial wrath hold send thrash callout tts" },
	{ label = "Tip of the Spear", page = "auras", tab = 3, panel = "Class", keywords = "tip spear stacks bars survival" },
	{ label = "Stack bars", page = "auras", tab = 3, panel = "Class", keywords = "stack bars width height spacing border filled empty color" },
	{ label = "Smart Misdirection", page = "auras", tab = 3, panel = "Class", keywords = "misdirect smart tank focus pet macro" },
	{ label = "Misdirect alert", page = "auras", tab = 3, panel = "Class", keywords = "misdirection target text alert" },
	{ label = "Precise Shots", page = "auras", tab = 3, panel = "Class", keywords = "precise shots lock and load bulletstorm marksmanship text alert" },
	{ label = "Vivacious Vivification", page = "auras", tab = 3, panel = "Class", keywords = "mistweaver vivify instant reminder" },
	{ label = "Lifebloom refresh", page = "auras", tab = 3, panel = "Class", keywords = "restoration druid lifebloom refresh" },
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
	{ label = "Vehicle exit", page = "actionbars", sidebar = "vehicle", panel = "Vehicle exit", keywords = "vehicle exit leave taxi possess button" },
	{ label = "Micro menu", page = "actionbars", sidebar = "micro", panel = "Micro menu", keywords = "micro menu buttons character spellbook bar" },
	{ label = "Bag bar", page = "actionbars", sidebar = "bags", panel = "Bag bar", keywords = "bag bar backpack buttons" },
	{ label = "Extra action", page = "actionbars", sidebar = "extra", panel = "Extra action", keywords = "extra action zone ability button blizzard art" },
	{ label = "Volume", page = "settings", tab = 2, panel = "Voice and sound", keywords = "tts voice speech volume loudness audio" },
	{ label = "Alert sound channel", page = "settings", tab = 2, panel = "Voice and sound", keywords = "sound channel master sfx audio alerts" },
	{ label = "Faster Looting", page = "settings", tab = 2, panel = "Looting", keywords = "loot speed auto fast" },
	{ label = "Auto-Sell Junk", page = "settings", tab = 2, panel = "Looting", keywords = "vendor sell grey trash" },
	{ label = "Auto-Repair", page = "settings", tab = 2, panel = "Merchant", keywords = "repair gold" },
	{ label = "Use Guild Funds", page = "settings", tab = 2, panel = "Merchant" },
	{ label = "Show Repair Cost", page = "settings", tab = 2, panel = "Merchant" },
	{ label = "Auto-Accept & Gossip", page = "settings", tab = 2, panel = "Questing", keywords = "quest auto accept gossip" },
	{ label = "Auto-Complete", page = "settings", tab = 2, panel = "Questing", keywords = "quest auto complete turn in" },
	{ label = "Skip Movies", page = "settings", tab = 2, panel = "Questing", keywords = "cinematic movie skip" },
	{ label = "Cast on Key Down", page = "settings", tab = 2, panel = "Casting", keywords = "key down press" },
	{ label = "Auto Keystone", page = "settings", tab = 2, panel = "Casting", keywords = "mythic keystone auto insert" },
	{ label = "Auto Combat Log", page = "settings", tab = 2, panel = "Combat Logging", keywords = "combat log logging warcraft logs record auto" },
	{ label = "Logging Indicator", page = "settings", tab = 2, panel = "Combat Logging", keywords = "combat log indicator recording dot" },
	{ label = "Advanced Logging", page = "settings", tab = 2, panel = "Combat Logging", keywords = "advanced combat logging warcraft logs cvar" },
	{ label = "Spell Queue (ms)", page = "settings", tab = 2, panel = "Casting", keywords = "spell queue window spellqueue" },
	{ label = "Auto-Accept Party", page = "settings", tab = 2, panel = "Social" },
	{ label = "Include Guild", page = "settings", tab = 2, panel = "Social" },
	{ label = "Auto-Confirm Role", page = "settings", tab = 2, panel = "Social" },
	{ label = "Easy Item Destroy", page = "settings", tab = 2, panel = "Interface", keywords = "delete destroy confirm" },
	{ label = "Hide Talking Head", page = "settings", tab = 2, panel = "Interface" },
	{ label = "Hide Rested Zzz", page = "settings", tab = 2, panel = "Interface" },
	{ label = "Hide Zone Text", page = "settings", tab = 2, panel = "Interface" },
	{ label = "Hide Error Msgs", page = "settings", tab = 2, panel = "Interface", keywords = "error red text" },
	{ label = "FPS preset", page = "settings", tab = 2, panel = "Graphics", keywords = "fps cvar performance graphics vsync apply" },
	{ label = "Restore", page = "settings", tab = 2, panel = "Graphics", keywords = "fps cvar restore original" },
	{ label = "Reset BluUI", page = "settings", tab = 2, panel = "Danger zone", keywords = "reset wipe default settings" },
	{ label = "Unit Frames", page = "settings", tab = 5, panel = "Modules", keywords = "enable disable module" },
	{ label = "Cooldown Manager", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Cast Bars", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Power Bars", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Minimap", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Auras", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Buff Tracking", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Datatext", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Custom Bars", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Cursor", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Streamer Tools", page = "settings", tab = 5, panel = "Modules" },
	{ label = "Gem Manager", page = "settings", tab = 5, panel = "Modules" },

	{ label = "Switch profile with spec", page = "exportimport", tab = 1, panel = "Spec profiles", keywords = "export import profile share spec" },

	{ label = "Hide the Blizzard frames", page = "groupframes", tab = 1, panel = "Group frames", keywords = "blizzard default frames hide group party raid enable" },
	{ label = "Click casting", page = "groupframes", tab = 1, panel = "Group frames", keywords = "click cast mouse clique" },
	{ label = "Fade out of range", page = "groupframes", tab = 1, panel = "Group frames", keywords = "range fade alpha distance offline" },
	{ label = "Party frames", page = "groupframes", tab = 2, panel = "Party", keywords = "party frames position anchor preview enable" },
	{ label = "Sorting", page = "groupframes", tab = 2, panel = "Party", keywords = "sort role class order party slot" },
	{ label = "Visibility", page = "groupframes", tab = 2, panel = "Party", keywords = "self solo raid group show" },
	{ label = "Frames", page = "groupframes", tab = 2, panel = "Party", keywords = "width height spacing power bar texture vertical healer mana" },
	{ label = "Health and colors", page = "groupframes", tab = 2, panel = "Appearance", keywords = "class color health border background transparent dead opacity" },
	{ label = "Damage absorb", page = "groupframes", tab = 2, panel = "Appearance", keywords = "absorb shield heal texture direction" },
	{ label = "Target border", page = "groupframes", tab = 2, panel = "Appearance", keywords = "target mouseover border highlight" },
	{ label = "Font", page = "groupframes", tab = 2, panel = "Text", keywords = "font name text" },
	{ label = "Name", page = "groupframes", tab = 2, panel = "Text", keywords = "name length truncate letters max" },
	{ label = "Health text", page = "groupframes", tab = 2, panel = "Text", keywords = "health percent text format absorb" },
	{ label = "Power text", page = "groupframes", tab = 2, panel = "Text", keywords = "power mana text" },
	{ label = "Status text", page = "groupframes", tab = 2, panel = "Text", keywords = "dead ghost offline afk dnd status color" },
	{ label = "Mythic+ key", page = "groupframes", tab = 2, panel = "Text", keywords = "keystone mythic plus key party" },
	{ label = "Role icon", page = "groupframes", tab = 2, panel = "Indicators", keywords = "role leader raid marker resurrect ready check combat icon" },
	{ label = "Unit tooltips", page = "groupframes", tab = 2, panel = "Tooltips", keywords = "tooltip aura buff debuff" },
	{ label = "Raid frames", page = "groupframes", tab = 3, panel = "Raid", keywords = "raid frames position preview enable" },
	{ label = "Role icons", page = "groupframes", tab = 3, panel = "Raid", keywords = "raid role icon tank healer" },
	{ label = "Large raid layout", page = "groupframes", tab = 3, panel = "Raid", keywords = "large raid size threshold groups per row spacing" },
	{ label = "Buffs", page = "groupframes", tab = 4, panel = "Party auras", keywords = "party aura buff debuff defensive crowd control icons rules" },
	{ label = "Private auras", page = "groupframes", tab = 4, panel = "Party auras", keywords = "private aura raid boss" },
	{ label = "Dispel highlight", page = "groupframes", tab = 4, panel = "Party auras", keywords = "dispel debuff highlight border badge magic curse poison disease" },
	{ label = "Dispel type colors", page = "groupframes", tab = 4, panel = "Party auras", keywords = "dispel color magic curse poison disease bleed shared palette" },
	{ label = "Buffs", page = "groupframes", tab = 5, panel = "Raid auras", keywords = "raid aura buff debuff defensive crowd control icons rules" },
	{ label = "Dispel highlight", page = "groupframes", tab = 5, panel = "Raid auras", keywords = "raid dispel highlight border badge" },
	{ label = "Debuff blacklist", page = "groupframes", tab = 6, panel = "Filters", keywords = "blacklist filter debuff buff hide spell recently seen built-in share" },
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

SearchIndex.RegisterTabNames('auras', { 'Alerts', 'GCD History', 'Class' })
SearchIndex.RegisterTabNames('power', { 'Primary', 'Secondary', 'Stacking' })
SearchIndex.RegisterTabNames('cdm', { 'General', 'Essential', 'Utility', 'Buff icons', 'Buff bars', 'Layouts', 'Icon management' })
SearchIndex.RegisterTabNames('castbars', { 'Player', 'Target', 'Focus' })
SearchIndex.RegisterTabNames('unitframes', { 'Appearance', 'Tags', 'Tags', 'Player', 'Target', 'Target of target', 'Focus', 'Pet', 'Boss', 'Filters' })
SearchIndex.RegisterTabNames('groupframes', { 'General', 'Party', 'Raid', 'Party auras', 'Raid auras', 'Filters' })
SearchIndex.RegisterTabNames('settings', { 'Appearance', 'Settings', 'Skinning', 'Visibility', 'Modules', 'Help', 'Theme' })
