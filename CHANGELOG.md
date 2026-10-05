# 5.2.0

## New

- **Quality of life page**: everything that lived under Settings > Settings moved here, on a left rail: Combat, Interface, Automation, Graphics and Danger zone. Settings now only holds BluUI's own options, with voice and sound on their own Sound pane.
- **FPS preset** is a checklist. Switch on exactly the settings you want changed, see the current, preset and Blizzard default value for each, and apply the preset or put them back to Blizzard defaults.
- **Danger zone** cards show live counts: loadouts on this spec, macro slots used, quests that can be abandoned.
- **Cooldown Manager**: a **Hide icons past the last row** switch in each viewer's Rows popover. With Row 1 at 7 and Row 2 at 0 you get exactly seven icons, in Icon Management order.
- **Cursor** settings sit on the standard boards beside the live preview.
- **Great Vault** on the dashboard: raid, dungeon and world rows open one at a time, raid progress shows as boss dots, tooltips follow the window theme, and the vault skin keeps Blizzard's slot art under a black border.
- **Dispel highlight**: one adjustable fade shared by unit and group frames. The border and strip styles are gone.
- Footer buttons and search fields are a touch darker.
- The Bestial Wrath callout has been removed.

## Fixes

- Cooldown containers are pinned to their first row. Adding or hiding a row no longer shifts the icons, their keybind text or the frames anchored beside them, and the container edges snap to pixels like unit frames.
- Switching profiles rebuilds the settings pages before modules refresh, so the Fill colour and aura rows no longer error.
- The Chat Channels window lines its Add and Settings buttons up with the lists, and the roster title no longer sits on the list edge.
- The Danger zone opens before the macro window has ever been opened.

Updating by hand: delete the old `BluUI` and `BluUI_Options` folders first, then extract the new ones. Your settings are kept. This update removes and adds files, so restart the game instead of using /reload.
