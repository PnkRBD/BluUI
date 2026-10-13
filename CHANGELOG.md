# 5.9.0

Ready for 12.1.5, with HoT slots for healers, a smarter target frame and a bunch of aura fixes.

**HoT slots**

Party and raid frames can now show your HoTs in fixed spots, so Rejuvenation is always in the same place and you can tell at a glance who's missing it. Pick coloured squares or spell icons. Each healer spec gets its own list, and you can find it under HoT slots on the group frames page.

**Target frame**

Your target's buffs and debuffs now show the things you actually care about. On enemies that's boss and role buffs, buffs you can purge, and important buffs. On friendly players you see the buffs other players cast on them. Debuffs show the ones you're tracking, like your DoTs, plus big debuffs from anyone. Both sort by time remaining.

If you set your own target rules, they're left alone.

**Aura rules**

There are four new rules to pick from: Boss & Role Buffs, Buffs From Players, My Tracked Debuffs and Major Debuffs. Each aura now shows once, in the highest rule it matches, so nothing doubles up and nothing goes missing further down the list. The rule list is easier to read too, and "Max icons" is now called "Max per rule", because that's what it does.

**Timer decimals**

Aura timers can show tenths of a second when they're about to run out, like 4.3. Turn on Decimals in the timer options on the unit frames, party and raid frames, or Buffs & Debuffs pages, and pick when it kicks in.

**One blacklist**

The Buffs & Debuffs page used to keep its own blacklist, so something you blacklisted on your unit frames could still show up there. It's one list now, and anything you'd already blacklisted is carried over.

**Mana**

When the secondary power bar shows mana, it shows a percent by default instead of a giant number.

**Fixes**

The currency panel, merchant and trainer windows were throwing errors on the gold text, and they don't anymore. Escape works again after you open BluUI from the game menu. Quest auto accept and turn-in wait until you're out of combat, and so does applying a quest tracking preset. The player aura size sliders don't error in settings. Pinned buffs can't end up on the debuff list, or the other way around.

Updating by hand: delete the old BluUI and BluUI_Options folders, then extract the new ones. Your settings are kept. Restart the game rather than /reload.
