SCSEAL 1.1.4
Target: Warcraft Forever, interface 16001

INSTALL
1. Exit the game.
2. Extract SCSeal.zip into your Forever client's Interface\AddOns folder.
3. The final path must be Interface\AddOns\SCSeal\SCSeal.toc.
4. Start the game, enable SCSeal in AddOns, and log in on a Paladin.
5. Cast a seal outside combat once. Hold Shift and left-drag the display to position it.

DISPLAY
Shows the active seal's real spell icon beside a horizontal duration bar. The icon
and bar have the same height and matching thin gray borders. The seal name is
left-aligned inside the bar and the remaining time is right-aligned. The bar drains
from right to left as time expires. It is green from 100% through 50% remaining,
yellow below 50% through 20%, and red below 20%. No sounds or flashing.
No active seal: hidden outside combat. The display is always position-locked during
normal use; hold Shift and left-drag it whenever you want to reposition it.
Unknown seal state during restricted combat: a question mark with "Seal unknown".
The preview uses Seal of Righteousness; gameplay uses whichever seal is active.
The addon remains dormant on other classes. It has no Plater or WeakAuras dependency.

COMMANDS
/scseal             Show command help
/scseal size 36     Set the icon and bar height (24-80 pixels; default 36)
/scseal width 320   Set the bar width (140-600 pixels; default 320)
/scseal test        Show a 30-second preview when no seal is active
/scseal reset       Restore 36px height, 320px width, and default position

TIMING AND FOREVER COMPATIBILITY
Outside combat, expiration and duration are read from the actual player buff.
Recasting restarts the timer; swapping seals changes the icon and countdown.
Judgement does not clear the seal timer: the reviewed Forever example reports
that Judgement does not consume seals in this client.

Forever examples report restricted player aura access during combat. This addon
does not request combat aura data. It counts down from the last readable buff,
and updates from your own readable UNIT_SPELLCAST_SUCCEEDED seal events.
Triggered effects that share a seal name, including Seal of Command's damage proc,
are ignored unless the event's spell ID is a learned player spell.
An asterisk (*) marks an estimated timer. These estimates cannot detect a combat
dispel, manual buff cancellation, or an aura refresh not caused by a readable cast.
The display resynchronizes once buffs are readable again. If you reload while
already in combat, the addon may show "Seal unknown" until you cast or leave combat.

Durations are learned by spell ID and seal name and saved per character. If a seal
has not been observed outside combat, its first combat cast uses an estimated 30s
duration. Cast each seal outside combat to learn its actual duration. A readable
buff with no expiration displays "--". These are duration timers, not a swing or
seal-twisting predictor. Runtime state is not saved across sessions.

Names for familiar seal IDs are resolved through the client's spell information.
Additional English "Seal of ..." buffs/casts (including Forever seals) are detected
by name. New seals on non-English clients may need additional localized mappings.

VALIDATION
42 automated checks passed in a mocked WoW API environment using Fengari (Lua 5.3).
Checks cover tracking, swaps, refreshes, learned durations, restricted aura reads,
secret values, expiry, permanent buffs, death clearing, bar layout and thresholds,
embedded text, Shift-drag positioning, preview behavior, UI events and slash commands.
No in-game test has been performed. Forever client updates may change APIs or TOC.

RESEARCH REFERENCES
Wago was requested as an example source. Its main site and addon page require
JavaScript and did not expose readable source through the research tools.
Wago addon example: https://addons.wago.io/addons/swedgetimer
Wago home: https://wago.io/
Forever-specific API behavior was checked against this public source and probe log:
https://github.com/Nyte-fyre/NyteLytePaladinToolkit/blob/main/Services/AuraService.lua
https://github.com/Nyte-fyre/NyteLytePaladinToolkit/blob/main/docs/PROBE_LOG.md
https://github.com/Nyte-fyre/NyteLytePaladinToolkit/blob/main/NyteLytePaladinToolkit.toc
Reviewed November 8, 2026. The probe notes describe a beta build and are reference
evidence, not verification on the user's current game build.
This addon is an original implementation; no external code libraries are bundled.
