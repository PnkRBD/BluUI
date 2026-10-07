# 5.5.0

A lighter BluUI in combat, confetti when you earn it, and a long list of fixes.

**Celebrations**

Time a key and confetti falls across your screen. Same when your raid kills a boss. Dungeon boss kills can have it too if you turn them on. It all lives on a new Mythic+ tab on the Quality of life page, with a Try it button so you can see it without waiting for a kill.

**Performance**

BluUI does a lot less work on a boss pull. The chat skin had a hook running every single frame. Unit frame and raid frame text was listening to every unit's events and sorting out whose was whose in Lua. Custom cooldown icons redrew every icon on every cooldown change, and swapping a gear set rebuilt them once per slot. All of that is gone, and the pet alert stopped re-checking itself on every pet bar update.

The profile report is more honest too. Frame counts are since your last reload, it says how much time it couldn't explain, and it lists any glows on screen.

**Setup**

The scale step offers 1080p, 1440p and 4K presets, and you can type an exact value. The theme step picks up matching party and raid frames, health opacity and absorb colors. The action bars step spots bar addons that are installed but off, and shows exactly what will be turned on and off before you commit. Setup waits until you press Finish before it creates or switches profiles, and it cleans up any profile a half-finished setup left behind.

**Unit frames**

Target-of-target frames kept going stale after login. They update properly now. Turning off click to target actually turns it off. The leader and assistant icons respect their size setting. Previews hand the live unit back when they close. The combat timer and resting tags work, and the combat, item level, difficulty and role tags update when they should.

**Party and raid frames**

Offline members show an empty bar instead of a full one. Role icons stay off when you turn them off. The ready check icon comes back after a preview. If you keep Blizzard's party frames, BluUI leaves them alone now. Turning off Mana on healers only no longer breaks frame creation. The power bar background takes its tint, and changing party settings in combat waits for combat to end instead of erroring.

**Cast bars**

Countdown and Show total time do what they say. The unlock preview shows up when it should. The boss cast bar clears when a cast fails, and no cast bar carries stale state into the next cast.

**Skins**

The barber shop is no longer dimmed under a dark overlay, and its appearance options take the skin. Dropdown menus everywhere have their background back. Chat settings open inside the settings window. Menus and popups use the window background, cards are darker with softer edges, and the XP bar skin is off by default.

**Settings window**

Sliders accept an exact typed value. The window snaps to the pixel grid while you drag it. Each unit frame's settings fit in two tables, the party, raid and unit frame tabs have icons, and colors line up on the right. My healing buffs show on the player and raid frames by default.

Updating by hand: delete the old BluUI and BluUI_Options folders, then extract the new ones. Your settings are kept. Restart the game rather than /reload.
