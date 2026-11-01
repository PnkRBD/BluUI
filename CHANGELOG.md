# 5.16.0

Party keys in the portal manager, no more jumping on spec change, and a good tidy of the cooldown manager.

**Party keys**

The Portal Manager and the keystone reminder show your party's keys: who has which dungeon, the level on the right of each row, and whether you can teleport there. Rows use the group frame role icons and light up when you hover them. This is on by default. Turn it off under Skins > Portal Manager if you'd rather not see it.

**Spec changes**

Chat, the bag bar, the extra action bar and the buff bars stay put when you switch spec. The cooldown manager reads your per-spec icon settings for the new spec straight away, so hidden icons and custom order from the old spec don't flash through first.

**Cooldown manager and custom bars**

Custom bar icons can show only in the specs you pick, and the picks are kept per class. Venomstone counts show in venom green. Unusable items dim like they do on the action bars, icon tooltips show the real bag item, and custom bar cooldown text rounds the same way as the action bars. Press highlight finds items on the last action bar too, dragging a buff icon out of the viewer doesn't snap back, and keybind text stays off on a viewer you've turned off.

**Party and raid frames**

A healer's power bar stays on mana, even on a druid shifting forms. Raid frames build in one go instead of five at a time, auras appear as soon as a frame gets a unit, and anything held back for combat runs all at once when it ends. Frames that spawn during combat lay out fully, aura containers stay put while you're mind controlled, and the combat res counter stays up between raid bosses. Loading screens no longer sweep the frames twice.

**Character sheet**

Reset all lives in the settings panel and asks before it wipes anything. The sheet closes through Blizzard's own close button and doesn't flash at its old spot. The debuff type icon row above the character is gone.

**Premade groups**

There's a Fits my group filter, and applicants show to the whole group, not just the leader.

**Action bars**

Flyout buttons follow their bar's size and spacing, with Blizzard's flyout art hidden behind the skinned buttons.

**Everything else**

Chat timestamps show plain, with no digit padding. There's an option to dismount when you use a skyriding ability on the ground. Skins all apply at once on login. And /bui perf measures a pull and reports BluUI's frame time, heaviest handlers and stalls, if you ever want to see what's costing you.

Updating by hand: delete the old BluUI and BluUI_Options folders, then extract the new ones. Your settings are kept. Restart the game rather than /reload.
