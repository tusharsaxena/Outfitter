# Forever port, smoke feedback 1: design

**Source:** the owner's first in-game pass of the Forever port branch (2026-11-09), feedback items 1 to 3
with screenshots 1 to 16. The screenshots are kept outside the repo:
`/home/tushar/.claude/projects/-mnt-d-Profile-Users-Tushar-Documents-GIT-OutfitterReborn/forever-smoke1-screens/<n>.png`.

**Branch:** OutfitterReborn `feat/2026-11-08-forever-port` (unmerged; this is that branch's smoke feedback).
No LibKa0s or standard change is planned.

**References.** F-UI is the Forever 1.60.1 build 70862 UI source, `Gethe/wow-ui-source@9dc84f0` (branch
`forever`), the same build the port was written against. CCS-F is ChonkyCharacterSheet 2.5.04 as installed
in the owner's `_forever_` client. Line numbers are those files'.

## What the screenshots show, and why

| # | Seen | Cause |
|---|------|-------|
| 1, 2 | Chonky, Skin Character Tabs on: the sheet button is a big Blizzard side tab under a row of small Chonky tabs | Chonky reskins the mode tabs to 48 x 48 in its own art and lays them in a horizontal row under the sheet (CCS-F `core/styles.lua:1046-1064`, `Modules/Forever.lua:1225-1238`), and scales the strip to 0.8 (`Modules/Forever.lua:1222`). The button is CharacterFrame's child at scale 1, anchored below the last tab as if the strip were vertical. |
| 4, 5 | Chonky, Skin Character Tabs off: vertical Blizzard tabs, the button bigger | Same 0.8 strip scale, the button at 1. |
| 6 | Chonky, tabs off: the window sits under the tabs | The window docks at the sheet's right edge, and the strip hangs off that edge (CCS-F `Modules/Forever.lua:1242`). |
| 8 | Chonky: the window's top is above the sheet's visible top line | The window is flush with `CharacterFrameBgbg`'s top, but its backdrop draws the visible line 3 px inside (its `insets`, CCS-F `Modules/Forever.lua:1277-1281`). Measured in 6.png: window top row 5, Chonky's line row 8. |
| 9-11 | Chonky: a gap between each slot and its flyout arrow | F-UI puts the arrow 5 px off the slot (`Camelot/PaperDollFrame.lua:1976-1989`); the slot's `BorderFrame` art covers that gap, and Chonky hides it (CCS-F `Modules/Forever.lua:1340`). |
| 13 | Stock: the button is gone on every tab but Character | The button hides with PaperDollFrame. Forever's mode-tab strip stays on every tab. |
| 14-16 | Stock and EllesmereUI: the tabs cover the window's left edge | Same as 6: the strip hangs off the sheet's right edge. |
| 7 | No hover feedback in the window | Rows paint no hover state; the checkbox's `menu.hover` wash is faint; the gear paints none. |

## Decisions

Builder's calls under the owner's standing guidelines, each reversible in review.

- **S1 Chonky's tab strip (1, 2, 4, 5).** The button takes the strip's scale (the last mode tab's
  effective scale over CharacterFrame's), so it is exactly a tab's size. Strip direction is read live
  from the first two shown tabs. Vertical: below the last tab, at the strip's spacing (today's rule).
  Horizontal: right of the last tab, at the strip's spacing. When the neighbor wears Chonky's skin
  (`CCS_BG` shown), the button wears a copy of it, a new `chonkytab` look: the template's art hidden as
  Chonky hides it, the neighbor's `CCS_BG` file and coords, the outfit icon at 42/48 of the tab, masked
  with Chonky's mask, and Chonky's yellow highlight while the window shows. Colors are copied live from
  the neighbors: the selected mode tab's for selected and hover, an unselected one's for idle. Chonky's
  table is private, so nothing else can be read. This widens the accepted deviation
  `DEV-SKIN-SHEET-BUTTON` (the host's look) to Chonky's skinned strip.
- **S2 Chonky's top edge (8).** On a Chonky sheet the window's top drops by the backdrop's top inset,
  read live from `CharacterFrameBgbg.backdropInfo.insets.top` (3 when unreadable), so its top meets
  Chonky's visible line. Retail and Forever alike: the backdrop is the same on both.
- **S3 The arrow gap (9-11).** Where the drawer places a Forever arrow (S7), the 5 px offset applies
  only while the slot's `BorderFrame` is shown. Hidden, the arrow sits flush against the slot.
- **S4 The button on every tab (13).** On Forever the button follows CharacterFrame, not the paper doll:
  it is placed on CharacterFrame's show and on every mode switch, and hides with CharacterFrame. A click
  from another tab opens the Character tab and the window (Dock.Open already does this). The window
  still needs the paper doll. Retail is unchanged: its sidebar tabs belong to the doll.
- **S5 The window under a side strip (6, 14-16).** When a vertical side-tab strip (the shown mode tabs
  and the sheet button) starts at the window's docking edge, the window keeps its dock point and
  widens by the strip's width plus a 4 px margin. Its title, divider, strip, list and footer move right
  by the same amount, so the tabs lie over an empty band of the window's own background. The window
  is extended, not moved. The inset is measured live on every placing and compared by the follow, so a
  Chonky side panel opening (which moves the dock past the strip) drops it. It applies on Forever's
  stock sheet, on EllesmereUI's skin and on Chonky with its tabs unskinned. Width changes happen only
  where the dock places the window: out of lockdown.
- **S6 Hover (7), both clients.** An outfit, item or category row shows the skin's `list.hover` wash
  while the pointer is anywhere over it, including over its controls. The worn checkbox and the
  Equipment Manager mark add their own wash in the skin's accent (`icon.arrow`, at 0.35 alpha). The
  row gear is painted as the title gear is (`NS.Skin.CloseButton`: rest, hot under the pointer).
  Colors are read when they are painted, and the row wash is repainted on a skin change through the
  ListRow record.
- **S7 Outward flyouts, always (owner: "core behavior change"), both clients.** The drawer no longer
  waits for the outfit window. While the paper doll shows and `window.drawer` is on (the default),
  every slot's arrow is shown and every flyout opens away from the doll: the left column left, the
  right column right, the bottom row down. That covers the plain Character tab, the Equipment Manager
  pane and the outfit window.
  - Retail keeps today's mechanics: it moves the left column's arrows, mirrors them, and re-anchors the
    flyout. Its right column and weapons were already outward.
  - Forever gets the same behaviour through hooks. It never writes Blizzard's `flyoutDirection`. Each
    arrow is re-anchored by F-UI's own rule for the outward direction (`PaperDollFrame.lua:1976-1989`,
    S3's offset), and a post-hook on `EquipmentFlyoutPopoutButton_RefreshVisualState` re-sizes and
    re-rotates it as F-UI would for that direction (`Camelot/EquipmentFlyout.lua:707-755`). A post-hook
    on `EquipmentFlyout_UpdateItems` re-anchors `buttonFrame` by F-UI's own formula for that direction
    (`:420-433`). The flyout's background hangs inside buttonFrame whatever the direction, so it
    follows.
  - Everything is put back exactly when the doll hides, the setting turns off, or the addon stands
    down. Nothing is written in combat lockdown, and the next regen re-syncs.
  - The flyout tint (`DEV-SKIN-FLYOUT-TINT`) still follows the outfit window only.
  - This supersedes the 2026-11-04 owner ruling "only while the outfit window shows" (sheet and window
    feedback design G8).
  - The `window.drawer` row's label and tooltip say the new rule.

## Not in scope

The ammo slot (tusharsaxena/Outfitter#1, deferred by the owner). Retail's sheet button placement. The
window's height.
