# 5.3.0

Big one. Most of the work went into the unit frames and the action bars, with a pile of fixes for the 12.x API changes on top.

**Setup**

The installer is called Setup BluUI now. On the theme step there's a switch to make your party and raid frames use the same style as your unit frames, so you don't have to set it twice.

**Unit frames**

The group frames page has moved into the unit frames page. Name, health, status and power text share their defaults across every frame, so you set them once and only override the frames you want different.

Every row in the Frames, Dispels and Indicators tables has a reset. It only shows up when you've changed something in that row, and one click puts it back. The dispel type colours now live on the Type icons row instead of a row of their own, and hovering any row shows what it does in full.

Absorb stripes draw in the colour you picked rather than Blizzard's blue.

**Party and raid frames**

Power bars have their own row. The private aura icons are gone. If you want to move the private raid warning text, it has a mover and a scale now.

**Action bars**

Movers for the bag bar, stance bar, status tracking bar, extra action button and vehicle exit. Labels fit small bars and sit above the buttons so you can actually read them. The experience bar stays visible while movers are unlocked so you can place it.

Changing a bar only refreshes that bar, so dragging sliders doesn't churn memory any more. Fading is smooth again and no longer breaks the micro menu icons. Scaling a bar keeps it where it is.

**Bag bar**

It's skinned again. Single bag mode works, the backpack has its icon back, icons sit inside their border, and the options fit on one row. If another addon owns the bag buttons, BluUI leaves them alone.

**Profiles**

A fresh install starts from a proper default profile instead of bare settings. Export and import are on one card, and bringing settings over from other addons has its own entry in the rail.

**Chat**

Up and down arrow history works again. Links and names are clickable again. Chat settings open in their own window.

**Dashboard**

A keystone reminder card when you join a Mythic+ group.

**Look**

Panels, the search box and buttons are as dark as the cards out of the box. Text boxes have an outline, table headers are bolder, and a page greys out while its module is switched off, with the switch up in the header.

**Fixes**

Errors from the item functions Blizzard removed in 12.x. The unit frame preview no longer errors on the group tabs. The character sheet notice only shows once.

Updating by hand: delete the old BluUI and BluUI_Options folders, then extract the new ones. Your settings are kept. Restart the game rather than /reload.
