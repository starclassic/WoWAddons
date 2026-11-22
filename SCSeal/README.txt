SCSeal 2.0.0 - WoW Forever

One icon combines the seal timer with the Unsealed Wrath reminder.

- Normally the icon shows your current seal.
- The thin border INSIDE the outer glow drains clockwise as the active seal
  runs out. This uses Blizzard's native seal duration, including in combat.
- The bottom-right number shows your active seal's Echo stacks: 1, 2, or 3.
  No number is shown when there are no Echo stacks.
- At 3 stacks the icon shows the OTHER seal, with the strong gold halo and
  "Switch" underneath. The timer still belongs to the seal currently on you.
- After you cast the other seal, the halo and Switch cue disappear, the seal
  timer follows the new buff, and the count follows the new seal's Echoes.
- Swap reminders pair Command and Righteousness. Other seals still have their
  native icon and countdown, without the Command/Righteousness swap cue.

Hold Ctrl + left-drag outside combat to move. Holding Ctrl reveals a preview
so you can find and move the icon even when no seal is active.

/scseal test             Toggle a 3-stack swap preview with a sample countdown
/scseal test command     Preview the Command suggestion
/scseal size 64          Icon size, 32-128 pixels
/scseal on               Enable the display
/scseal off              Disable the display
/scseal reset            Reset position and size
/scseal debug            Print native API and last recognized seal status
/uwbox is also accepted as an alias. No lock/unlock commands are needed.

INSTALL
Put the SCSeal folder inside your Forever Interface\AddOns folder.
Disable/remove the separate UnsealedWrathBox addon to avoid a duplicate icon.
Restart WoW after installing the new texture files.

Existing SCSeal position settings are retained; the former bar becomes a
64-pixel icon by default. Width/height bar settings are no longer used.

LIMITS AND VALIDATION
The game draws the duration, stack number, next-seal icon and glow using
native aura bindings. Lua does not inspect or estimate secret combat values.
The active Echo group is selected from your own learned seal casts. If you
reload in combat, initialization waits until combat ends. If a client update
changes the native APIs or Echo IDs, an addon update may be needed.

Lua 5.1 syntax and mocked client checks cover native duration binding, both
stack counts and swap directions, old Echo suppression after switching,
damage-proc rejection, Ctrl-drag, saved positioning, and combat restrictions.
Not yet validated in a live WoW client. Try /scseal test, then build three
Echo stacks with each seal and check that the number, icon and glow agree.

The countdown and glow textures are original procedural assets. See
LICENSE.txt and NOTICE.txt for third-party API implementation attribution.
