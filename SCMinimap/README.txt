SCMINIMAP 1.6.14.0
Target: Warcraft Forever, interface 16001

INSTALL
1. Exit the game.
2. Extract SCMinimap.zip into the Forever client's Interface\AddOns folder.
3. The final path must be Interface\AddOns\SCMinimap\SCMinimap.toc.
4. Enable SCMinimap in the AddOns list.

FEATURES
- Square minimap with a matching one-pixel gray border.
- Uses the Classic-safe square minimap mask, reports a square minimap shape, and
  reapplies terrain setup when indoor/cave zoom levels change.
- Continuously suppresses Blizzard's circular border/backdrop and fixed north marker.
- Blizzard's lens and location bar rest immediately above the minimap's top edge,
  with the unread-mail indicator inside the map's upper-right corner.
- Player coordinates along the top inside the map on a lighter translucent,
  borderless background, with a live eight-way heading (N, NE, E, SE, S, SW, W,
  NW) immediately to their right; the duplicate in-map zone name is removed.
- Mouse-wheel zoom while preserving normal minimap clicks.
- Enlarges all native minimap icons to 1.20x. Terrain remains fully opaque
  because the Forever client renders indoor and cave terrain black below 100%.
- Collects third-party minimap buttons into one numbered drop-down grid.
- Keeps the numbered addon-icon launcher on the minimap's top-left corner while
  its tray expands upward; the launcher is invisible until directly hovered.
- Fits the complete lens/location/time header exactly between the minimap's left
  and right borders.
- Compensates for the rounded header texture's three-pixel right inset so its
  visible border—not only its frame—ends flush with the minimap.
- Compensates for the lens texture's one-pixel overhang and hooks day/night
  controls so Blizzard cannot re-show sun or moon artwork after it is hidden.
- Recursively suppresses calendar, sun, moon, game-time, and day/night textures and
  atlases, including anonymous minimap-cluster frames used by Forever.
- Structurally suppresses every small frame occupying the minimap's outside
  upper-right day/night slot when the client provides no usable frame identity.
- Safely skips forbidden Blizzard frames and secret values during structural
  sun/moon scans, preventing the scan from flooding the Lua error counter.
- Runs the global structural frame discovery once during initialization, then
  reuses cached matches instead of rescanning the entire UI every two seconds.
- Keeps collected launchers on DIALOG strata so GameTooltip renders above them.
- Excludes all tooltip frames from structural day/night detection.
- Opens the addon tray upward when space permits, otherwise downward, and clamps
  it to the screen so the popout always remains visible.
- Keeps the clock just above the map's top-right border and places the calendar
  button inside the map's top-right corner.
- Extends Blizzard's actual rounded, translucent location bar and places the clock
  inside that same control, preserving its exact border and background styling.
- Uses a brighter yellow clock font to distinguish time from the location name.
- Removes the clock's sun/day-night artwork and enforces 24-hour military time.
- Joins the clock directly to the location bar at matching height and suppresses
  the client-specific calendar alias that re-shows the sun/day-night control.
- Preserves the terrain-rendering minimap backdrop while removing only border and
  compass artwork.
- Removes the separate sun/moon day-night indicator.
- Hides the redundant Blizzard addon-compartment square and native coordinate
  duplicate while SCMinimap supplies those controls.
- Hold Shift and left-drag anywhere on the minimap to move it; releasing the
  left button saves its position. Normal clicks do not unlock or move it.
- Keeps the full-map drag helper hidden and mouse-disabled; direct Minimap hooks
  preserve Shift-drag while restoring native POI hover and click-to-ping.
- Position and settings are saved account-wide.
- Defensive handling for restricted or unavailable coordinate values.
- No tooltip and no external libraries.

COMMANDS
/scminimap                 Show command help
/scminimap size 200        Set outer size (140-320 pixels; default 200)
/scminimap coords on|off   Show or hide player coordinates
/scminimap icons 1.2       Set all native minimap icon scale (1.0-1.5)
/scminimap terrain         Explain why terrain opacity is locked at 1.0
/scminimap buttons on|off  Collect or restore third-party minimap buttons
/scminimap rescan          Look for newly created addon buttons immediately
/scminimap reset           Restore default size, position, and text

The default Blizzard zoom buttons and border artwork are hidden. Mail, tracking,
calendar, instance difficulty, and other Blizzard minimap indicators are preserved.
Only direct, named third-party minimap launchers are collected; Blizzard's nested
tracking and calendar menu controls are intentionally ignored.
Collected launchers are forced to full opacity in the tray, while any original
mouseover-only fade setting is restored when button collection is disabled.
LibDBIcon's fixed frame-level lock is temporarily released while each launcher is
moved above the tray background, then relocked at the corrected level.

VERSION 1.6.9
- Preserves Blizzard's native MinimapContainer parent so the Forever client can
  swap in cave and interior-floor terrain without leaving the minimap black.
- Reapplies only SCMinimap's holder anchors after zone and zoom transitions,
  keeping the custom layout without breaking Blizzard's terrain hierarchy.

VERSION 1.6.10
- Moves Blizzard's complete native MinimapContainer into SCMinimap instead of
  anchoring its child outside the container. This keeps normal world terrain,
  cave-floor terrain, and the renderer's clipping frame together.
- Continues suppressing redundant native artwork and coordinates after moving
  the container, without touching the terrain renderer.

VERSION 1.6.11
- Reverts the experimental native-container changes from 1.6.9 and 1.6.10.
- Restores the proven 1.6.8 minimap layout so outdoor/world terrain renders
  normally. Cave-floor behavior is left to the Forever client.

VERSION 1.6.12
- Fixes black cave and mine terrain by keeping Minimap alpha at 1.0.
- Migrates saved 0.82 terrain-opacity profiles to the safe value and prevents
  the legacy terrain command from reintroducing the client rendering bug.
- Leaves every frame parent, anchor, mask, and control from stable 1.6.11 intact.

VERSION 1.6.13
- Removes both sun and moon variants of Blizzard's day/night indicator, including
  replacement frames created after the initial scan.
- Moves the mail indicator above the tracking lens at the minimap's top-left.

VERSION 1.6.13.1
- Keeps the stable 1.6.13 codebase and replaces only its unusable Blizzard mail
  frame with an SCMinimap-owned unread-mail icon inside the upper-right corner.
- Shows and hides the icon from `HasNewMail()` and `UPDATE_PENDING_MAIL`.

VERSION 1.6.13.2
- Automatically acquires late VuhDo and Details LibDBIcon buttons and returns
  them to the tray whenever their libraries restore a minimap anchor.
- Accepts any public truthy `HasNewMail()` result and uses the guaranteed
  `INV_Letter_15` envelope texture for the custom mail indicator.

VERSION 1.6.13.3
- Shifts the unread-mail icon six pixels left for better spacing from the
  minimap's right border.

VERSION 1.6.13.4
- Replaces the dark inventory-letter artwork with Blizzard's complete minimap
  mail texture, preserving its transparent background and full envelope shape.

VERSION 1.6.13.5
- Copies the actual mail texture or atlas from Forever's live native mail control
  instead of relying on an unavailable hardcoded Blizzard texture path.
- Retains the inventory-letter artwork only as a fallback when the client exposes
  no reusable native mail artwork.

VERSION 1.6.13.6
- Places coordinates on a compact translucent charcoal plate with a thin gray
  border and slightly larger outlined white text for reliable terrain contrast.
- Keeps the coordinate plate mouse-transparent and hides it with coordinates.

VALIDATION
57 automated checks passed in a mocked WoW API environment using Fengari (Lua 5.3).
No in-game test has been performed; Warcraft Forever updates may change UI behavior.
