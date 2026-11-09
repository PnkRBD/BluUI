# 5.19.1

Two small follow-ups to 5.19.0.

**Power text**

The primary power type is worked out once per form, spec or display-power change instead of on every power tick.

**Under the hood**

The perf report lists every guarded skin hook under its own call site, so a busy hook in a skinned window can be named instead of counted.

Updating by hand: delete the old BluUI and BluUI_Options folders, then extract the new ones. Your settings are kept. Restart the game rather than /reload.

# 5.19.0

Chat lines that wrap under the name, a cooldown manager that reacts in the frame an event lands, and a profiler that names what called what.

**Chat**

Long messages continue under the name instead of under the time. Turn it off under Messages, Align wrapped lines, if you prefer the old flow. Timestamps are drawn plain.

**Cooldown manager**

Custom icons and custom bars update in the frame their event arrives. The old code held cooldown, usable, aura and bag changes back by up to a tenth of a second and rescanned bags on a delay. The same clean-up went through the rest of the addon: secondary stats, the dispel callout, the objective tracker, the merchant and trainer windows, the currency, reputation and portal panels, and the dashboard all refresh on the next frame instead of on a timer.

Ctrl-click to detach single icons is gone. Positions saved for detached icons are cleared the first time this version loads.

**Character sheet**

The vault icon is cropped to a centred square and zoomed to fill its slot. Stat sections can be dragged into the order you want.

**Premade Groups**

The servers summary sits clear of its label and reads shorter. Category buttons the game never created no longer throw an error.

**Under the hood**

/bui perf lists the most called BluUI functions with who called them and how often, counts BluUI's own secret-value checks exactly, names glow frames and Blizzard template code running on BluUI frames, and reports its own overhead. Every secret-value check in the addon goes through one function so that count is BluUI's alone.

Updating by hand: delete the old BluUI and BluUI_Options folders, then extract the new ones. Your settings are kept. Restart the game rather than /reload.

# 5.18.0

Portals docked beside the group finder, stat tooltips kept off the character sheet, and windows that move the moment you drag them.

**Portals in Premade Groups**

Press Portals in the Premade Groups window to dock your portals beside it, as a rail of icons or as the list. The rail names each dungeon by its initials, shows your best key on the icon, and ends in a cog that switches between the rail and the list.

**Character sheet**

Stat tooltips sit outside the sheet, to the right of the panel or of the settings panel when that is open, so they no longer cover your character. Hovering a stat shows how much of it each piece of gear gives, the same way pinning one does.

**Windows and menus**

Every BluUI window starts moving after the first few pixels of a drag instead of waiting on the game to notice one. Clicking outside a Premade Groups menu closes it and the click still lands where you aimed it. Dropdown menus stay solid and on top.

**Under the hood**

Work that waits for combat to end is spread across frames so leaving combat does not hitch. Player aura changes are read once through a shared helper, group frames and proc alerts take their events from the shared bus instead of frames of their own, and the pixel snapping hooks are brought up to date. The perf report names the file and line behind every dispatcher.

Updating by hand: delete the old BluUI and BluUI_Options folders, then extract the new ones. Your settings are kept. Restart the game rather than /reload.

# 5.17.0

Range fading for target, focus and boss frames, text placement for every aura icon, and three small fixes.

**Range fade**

Target, focus and boss frames can fade while the unit is out of your range. Turn it on from the frame's board under Range fade, with separate opacity for in and out of range. Enemies fade past your longest ranged ability, up to 40 yards. Players you can neither attack nor heal fade past 28 yards out of combat, which is all the game reports for them.

**Aura text**

Buffs and debuffs on unit frames, party frames and raid frames now have a position and pixel offsets for the stack count and the cooldown text, the same as the buff frames. They live under the text tool on each aura row.

**Fixes**

The keystone reminder card waits for combat to end before it resizes or moves. The durability tooltip no longer says nothing is equipped. Venomforged gear shows its track whatever wording the tooltip uses.

Updating by hand: delete the old BluUI and BluUI_Options folders, then extract the new ones. Your settings are kept. Restart the game rather than /reload.
