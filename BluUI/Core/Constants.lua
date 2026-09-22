local _, BUI = ...
BUI.C = {}

BUI.C.BASE_MEDIA_PATH = [[Interface\AddOns\BluUI\Media\]]
BUI.C.MEDIA_PATH      = [[Interface\AddOns\BluUI\Media\Textures\]]
BUI.C.FONT_PATH     = [[Interface\AddOns\BluUI\Media\Fonts\gotham_narrow_ultra.ttf]]
BUI.C.BLIZZARD_FONT = [[Fonts\FRIZQT__.TTF]]
BUI.C.ICON_PATH = [[Interface\AddOns\BluUI\Media\Icon\logo_small]]
BUI.C.FALLBACK_TEXTURE    = [[Interface\Buttons\WHITE8X8]]
BUI.C.BAR_TEXTURE         = [[Interface\AddOns\BluUI\Media\Textures\melli.tga]]
BUI.C.CURSOR_RING_TEXTURE = [[Interface\AddOns\BluUI\Media\Textures\cursor_ring.tga]]
BUI.C.RAID_ICON_TEXTURE   = [[Interface\TargetingFrame\UI-RaidTargetingIcons]]
BUI.C.PANEL_BACKDROP = { 0.045, 0.045, 0.055, 0.97, 0.09, 0.09, 0.11, 1 }
BUI.C.COLOR_PINK         = 'FD008B'
BUI.C.CHAT_PREFIX        = '|cff6D00FDBluUI:|r '
BUI.C.DEFAULT_ACCENT = { 0.667, 0.831, 0.451, 1 }
BUI.C.DEFAULT_FONT       = 'Gotham Narrow Ultra'
BUI.C.DEFAULT_TEXTURE    = 'Solid'
BUI.C.GRADIENT_TEXTURE   = 'BUI Gradient'
BUI.C.GLOBAL_OPTION      = 'GLOBAL'

BUI.C.PAGE_CONTENT_W     = 804
BUI.C.ANCHOR_POINT_OPTIONS = {
	{ value = 'TOPLEFT',     text = 'Top Left'     },
	{ value = 'TOP',         text = 'Top Center'   },
	{ value = 'TOPRIGHT',    text = 'Top Right'    },
	{ value = 'LEFT',        text = 'Center Left'  },
	{ value = 'CENTER',      text = 'Center'       },
	{ value = 'RIGHT',       text = 'Center Right' },
	{ value = 'BOTTOMLEFT',  text = 'Bottom Left'  },
	{ value = 'BOTTOM',      text = 'Bottom Center'},
	{ value = 'BOTTOMRIGHT', text = 'Bottom Right' },
}
BUI.C.ANCHOR_POINT_OPTIONS_SHORT = {
	{ value = 'TOPLEFT',     text = 'Top Left'     },
	{ value = 'TOP',         text = 'Top'          },
	{ value = 'TOPRIGHT',    text = 'Top Right'    },
	{ value = 'LEFT',        text = 'Left'         },
	{ value = 'CENTER',      text = 'Center'       },
	{ value = 'RIGHT',       text = 'Right'        },
	{ value = 'BOTTOMLEFT',  text = 'Bottom Left'  },
	{ value = 'BOTTOM',      text = 'Bottom'       },
	{ value = 'BOTTOMRIGHT', text = 'Bottom Right' },
}
BUI.C.TEXT_PLACEMENT_OPTIONS = {
	{ value = 'TOPLEFT',             text = 'Inside Top Left'      },
	{ value = 'TOP',                 text = 'Inside Top'           },
	{ value = 'TOPRIGHT',            text = 'Inside Top Right'     },
	{ value = 'LEFT',                text = 'Inside Left'          },
	{ value = 'CENTER',              text = 'Center'               },
	{ value = 'RIGHT',               text = 'Inside Right'         },
	{ value = 'BOTTOMLEFT',          text = 'Inside Bottom Left'   },
	{ value = 'BOTTOM',              text = 'Inside Bottom'        },
	{ value = 'BOTTOMRIGHT',         text = 'Inside Bottom Right'  },
	{ value = 'OUTSIDE_TOPLEFT',     text = 'Outside Top Left'     },
	{ value = 'OUTSIDE_TOP',         text = 'Outside Top'          },
	{ value = 'OUTSIDE_TOPRIGHT',    text = 'Outside Top Right'    },
	{ value = 'OUTSIDE_LEFT',        text = 'Outside Left'         },
	{ value = 'OUTSIDE_RIGHT',       text = 'Outside Right'        },
	{ value = 'OUTSIDE_BOTTOMLEFT',  text = 'Outside Bottom Left'  },
	{ value = 'OUTSIDE_BOTTOM',      text = 'Outside Bottom'       },
	{ value = 'OUTSIDE_BOTTOMRIGHT', text = 'Outside Bottom Right' },
}
BUI.C.ANCHOR_PLACEMENT_OPTIONS = {
	{ value = 'INSIDE_TOPLEFT',     text = 'Inside Top Left'      },
	{ value = 'INSIDE_TOP',         text = 'Inside Top'           },
	{ value = 'INSIDE_TOPRIGHT',    text = 'Inside Top Right'     },
	{ value = 'INSIDE_LEFT',        text = 'Inside Left'          },
	{ value = 'CENTER',             text = 'Center'               },
	{ value = 'INSIDE_RIGHT',       text = 'Inside Right'         },
	{ value = 'INSIDE_BOTTOMLEFT',  text = 'Inside Bottom Left'   },
	{ value = 'INSIDE_BOTTOM',      text = 'Inside Bottom'        },
	{ value = 'INSIDE_BOTTOMRIGHT', text = 'Inside Bottom Right'  },
	{ value = 'TOPLEFT',            text = 'Outside Top Left'     },
	{ value = 'TOP',                text = 'Outside Top'          },
	{ value = 'TOPRIGHT',           text = 'Outside Top Right'    },
	{ value = 'LEFT',               text = 'Outside Left'         },
	{ value = 'RIGHT',              text = 'Outside Right'        },
	{ value = 'BOTTOMLEFT',         text = 'Outside Bottom Left'  },
	{ value = 'BOTTOM',             text = 'Outside Bottom'       },
	{ value = 'BOTTOMRIGHT',        text = 'Outside Bottom Right' },
}
BUI.C.STRATA_OPTIONS = {
	{ value = 'BACKGROUND', text = 'Background' },
	{ value = 'LOW',        text = 'Low' },
	{ value = 'MEDIUM',     text = 'Medium' },
	{ value = 'HIGH',       text = 'High' },
	{ value = 'DIALOG',     text = 'Dialog' },
	{ value = 'TOOLTIP',    text = 'Tooltip' },
}
BUI.C.ROW_GROWTH_OPTIONS = {
	{ value = 'Up',   text = 'Up'   },
	{ value = 'Down', text = 'Down' },
}

BUI.C.MODULE_MAP = {
	Minimap = "minimap",
	Auras = "auras", Crosshair = "auras", CombatTimer = "auras", CombatMessage = "auras", GatewayAlert = "auras",
	BuffTrackingHunter = "buffTracking", BuffTrackingDisplay = "buffTracking", BuffTrackingMonk = "buffTracking", BuffTrackingKCO = "buffTracking", SmartMisdirect = "buffTracking",
	Datatext = "datatext",
	CustomBars = "customBars",
	Cursor = "cursor",
	Markers = "markers",
	GCDHistory = "streamerTools",
	GemCounter = "gemCounter",
	SecondaryPower = "power", PowerBar = "power",
}

local sharedMedia = LibStub('LibSharedMedia-3.0')
local fontPath    = BUI.C.BASE_MEDIA_PATH .. [[Fonts\]]
local texturePath = BUI.C.MEDIA_PATH

for _, entry in ipairs({
	{ 'PTSansNarrow',               'PT Sans Narrow'         },
	{ 'Accidental Presidency',      'Accidental Presidency'  },
	{ 'Expressway',                 'Expressway'             },
	{ 'gotham_narrow_ultra',        'Gotham Narrow Ultra'    },
	{ 'gotham_narrow_ultra_french', 'Gotham Narrow Ultra FR' },
}) do sharedMedia:Register('font', entry[2], fontPath .. entry[1] .. '.ttf') end

for _, entry in ipairs({
	{ 'melli',        'Melli'        },
	{ 'solid',        'Solid'        },
	{ 'bui_gradient', 'BUI Gradient' },
}) do sharedMedia:Register('statusbar', entry[2], texturePath .. entry[1] .. '.tga') end
