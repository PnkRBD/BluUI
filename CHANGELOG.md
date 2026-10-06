# 5.3.0

- **Setup**: the installer is now titled Setup BluUI, and the theme step can make the party and raid frames match the unit frame style you pick.
- **Unit frames**: the group frames page lives inside the unit frames page. Text defaults, status tags and colors are shared across frames. Every row on the Frames, Dispels and Indicators grids has a reset that lights up when the row differs from the default, the dispel type colors sit on the Type icons row, and hovering a row shows its full description. Absorb stripes draw in the absorb color.
- **Party and raid frames**: a power bar row of their own. The separate private aura icons are gone; the private raid warning text has a mover and a scale instead.
- **Action bars**: movers for the bag bar, stance bar, status tracking bar, extra action button and vehicle exit. Mover labels fit small bars and stay above the buttons, and the experience bar shows while movers are unlocked. Editing a bar refreshes only that bar, fading is smooth and no longer breaks the micro menu icons, and a bar keeps its place when its scale changes.
- **Bag bar**: skinned again, single bag works, the backpack icon shows, icons draw under their border and the options sit on one row. The bar is left alone when another addon owns the bag buttons.
- **Profiles**: new installs start from the maintained default profile. Export and import share one card, and other addons have their own rail item.
- **Chat**: up and down arrow history works again, links and names are clickable, and the chat settings open in their own window.
- **Dashboard**: a keystone reminder card when you join a Mythic+ group.
- **Look**: panels, the search field and buttons are as dark as the cards by default, text boxes have an outline, table headers are bolder, and a module page greys out while its switch is off, with the switch in the page header.
- **Fixes**: errors from item functions the game removed, the unit frame preview on the group tabs, and the character sheet notice showing more than once.

Updating by hand: delete the old `BluUI` and `BluUI_Options` folders first, then extract the new ones. Your settings are kept. Restart the game instead of using /reload.
