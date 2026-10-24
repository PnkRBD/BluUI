# 5.15.0

This one's a big catch-up: a talent reminder, a settings panel for your character sheet, party frames that grow any way you like, and a lot of fixes.

**Talent Reminder**

When a ready check goes out, a reminder shows your spec and loadout, so you don't pull with the wrong talents.

**Character sheet**

The character sheet has its own settings panel now, with a reset button that puts everything back to default. There's a Great Vault button on the sheet too.

Changing the sheet's scale keeps it where you put it, and the borders redraw properly. When you switch gear sets, the highlight moves to the one you're wearing. The inspect window lost the dark box behind the model.

**Party and raid frames**

Party frames can grow up, down, left or right, and the Grow menu sits right on the Layout row. Health bars can fill in any direction. Shields bigger than your current health show properly when they sit on the left.

**Moving things around**

Every position and offset slider moves one pixel at a time now, even if your UI scale isn't pixel perfect. No more jumping two pixels on some steps. Anchor offsets can go past 200, and Center horizontally lines things up on the anchor when you anchor to its top, bottom or center.

The Class tab alerts on the Weaker Auras page have their own position button. And if your scale ever gets out of hand, type /bui scale reset to put it back to pixel perfect for your screen.

**Hunter**

The Hunter's Mark callout has an Icon only option and an icon size slider. The Kill Command overlay only shows the beast that's ready.

**Cooldown manager and custom bars**

Healthstones and other items with charges count down the moment you use one, on custom bars and in the cooldown manager. Custom bar tooltips keep working after the bar snaps to its anchor.

If you turn our cooldown manager off and use Blizzard's instead, BluUI keeps its icons out of Blizzard's bars. Talent buffs aren't locked as disabled in the buff list anymore.

**Action bars**

Buttons don't stay lit after you let go of the key, and the press highlight on cooldown icons clears sooner. The micro menu can sit tighter, right down to touching tiles, and the latency bar sits inside the last button.

**Quality of life**

There's a second FPS preset with lighter effects, and the Graphics Quality tabs work again.

Faster movie skip and the hide talking head, rested and zone text options don't cause Blizzard errors anymore. Opening things from BluUI doesn't break the world map either, whether it's a datatext click, reputation from the XP bar, the calendar from the minimap menu or Edit Mode.

**Everything else**

Action bars, the cooldown manager and party frames skip work when nothing has changed, so combat runs a bit lighter. The /bui profile, cdm, uf and trace commands are gone.

And a handful of small fixes, like the delve altar menu showing again, cast bars centering with their icon, the talent loadout buttons not reopening the talent window, and the game menu waiting behind BluUI instead of closing.

Updating by hand: delete the old BluUI and BluUI_Options folders, then extract the new ones. Your settings are kept. Restart the game rather than /reload.
