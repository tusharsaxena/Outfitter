# Smoke round 2: icon, sheet button, slots, menus, outfit bar, test mode (design)

Date: 2026-11-05. Source: the owner's CP4 in-game pass of the 2026-11-04 round, on stock, EllesmereUI
and ChonkyCharacterSheet (screenshots 1-12 of the session; described below). Recon evidence, with
file:line citations, is in [`2026-11-05-recon/`](2026-11-05-recon/) (one file per area). Read it with
this document: it holds the exact frame names, textures, texcoords and root causes.

## Intent

The last round made the addon sit on all three sheets; the in-game pass shows where it still looks
bolted on or broken. The default icon reads as a placeholder, the way in does not look like the tabs
beside it, the slot selectors and the flyout arrow cannot be seen, the flyout sits off its slot,
nested menus lose their parent, and the outfit bar is a bare strip with almost no options. Test mode
shows nothing of the main window. This round fixes each, and makes the bar a proper Ka0s HUD window.

## Owner decisions (2026-11-05)

- **D1. Default icon** is texture fileID **132724** (a chest-armour icon), untinted: new outfits,
  outfits with no own icon, the broker's idle icon and the sheet button. The gold coat-hanger tint
  retires.
- **D2. Seeded spec outfits** show their specialization's icon until the player picks another.
- **D3. Sheet button** matches the neighbouring tab buttons on each sheet, background and border
  included: Blizzard's sidebar tab on stock, Chonky's tab on Chonky (both are the same Blizzard art),
  and on EllesmereUI a **text tab** in EUI's tab style placed above "Equipment".
- **D4. Standards, skin:** the sheet button wearing the host's look instead of the Ka0s skin is an
  accepted deviation: a `skinning-§1`/`§9` row in `docs/ARCHITECTURE.md` -> Documented deviations.
- **D5. Slot selectors, flyout arrow, flyout alignment** are fixed on all three sheets.
- **D6. Nested menus** keep their parent open.
- **D7. Gear icon** is the same size as the close X.
- **D8. Outfit bar**: a header; icons per row/column; padding to the edge; spacing; icon options
  (size, border, …); the look of a Ka0s window (as DpsRace's race HUD); `/or bar show|hide|toggle`;
  per-section labels (Complete outfits, Accessories, …) with font size, outline, shadow and color, and
  an off switch; plus background/border color and opacity, lock and reset, grow direction, and a worn
  highlight.
- **D9. Test mode** (`/or test`) also shows the outfit window as if docked to the sheet (the window
  only, not the sheet, as PGFE's test mode does), filled with sample outfits, and a test strip on both
  the bar and the window.
- **D10. Standards, test window:** the `standalone-windows` deviation row gains a test-mode clause and
  design decision H17 ("the window shows real data") is reversed. Closing the alone test window only
  hides it; test mode still ends only by `/or test`, combat or Reset all (preview-mode).

## Goals

### G1. The default icon (D1, D2)

- `NS.OutfitIcon` keeps its ladder (own icon, then the trigger's icon, the Birthday Suit and
  single-item rungs) and changes only the **last rung** from the coat-hanger glyph to fileID 132724.
  The default is computed, never stored: no saved-data change and no migration.
- A new rung after the own icon: a seeded spec outfit (`rec.builtin == "SPEC_n"`) resolves to that
  spec's icon at draw time (the cached `NS.Triggers.Get(rec.builtin).icon`), so it no longer depends on
  the trigger staying in place, and "Outfitter chooses" (134400 -> nil) on it returns to the spec icon.
  Equipment Manager mirrors carry no `builtin` and their icon is never written; the seed must not
  write `rec.icon` on an EM mirror it adopts by name.
- Retire `NS.Constants.SHEET_BUTTON_TINT`, the `of.sheet.button` skin token and the broker's tinted
  `idleIcon`; both draw 132724 cropped like the window's art. `ph:coat-hanger` stays in the shipped
  icon set (LibKa0s icons: all) but nothing draws it by default.

### G2. The sheet button wears the host's tab (D3, D4)

- **Stock and Chonky:** one hand-built tab with Blizzard's art, `Interface\PaperDollInfoFrame\
  PaperDollSidebarTabs`: 33x35, TabBg (BACKGROUND 50x43, BOTTOMLEFT -9,-2), Icon, Hider and Highlight
  textures with the template's texcoords (recon `ingress.md`; `PaperDollFrame.xml:393-430`). Chonky's
  own extra tab (`MyTransmogButton`) is the precedent. It cannot inherit `PaperDollSidebarTabTemplate`
  (its OnLoad indexes `PAPERDOLL_SIDEBARS[id]`). Anchored after `PaperDollSidebarTab3` as today. The
  icon is 132724 inside the tab. Chonky re-centres its row for one extra tab; ours makes the row about
  18 px right-heavy, accepted (we never move another addon's tabs).
- **Selected state** while the outfit window is open: the selected TabBg texcoords with Hider and
  Highlight hidden; unselected otherwise.
- **EllesmereUI:** a text label `L["Outfits"]` in EUI's tab style (font from `EUI_CharSheet_Equipment`'s
  own FontString at placement, size 10, no flags; idle white 0.6, hover 1.0, active
  `EllesmereUI.ELLESMERE_GREEN`, read at paint time with a fallback), 64x25, no background or border,
  stacked directly above `EUI_CharSheet_Equipment` and centred on it. Re-placed on the next frame when
  the sheet kind changes (EUI builds its labels after our OnShow hook).
- The button leaves `Kit.skinSwitch.surfaces`; `Kit.skinValues` rows for its literal texture path and
  EUI alphas cite the D4 deviation id.

### G3. Slot selectors, flyout arrow, flyout alignment (D5)

- **Selectors (root cause: strata).** Chonky puts every `Character<Slot>` button in HIGH strata while
  our boxes copy CharacterFrame's MEDIUM. The selector container takes the highest strata among
  CharacterFrame and the 18 slot buttons (a strata-order table in `NS.Constants.LAYERS`,
  frame-layering-§5), and its level is the highest level among frames **of that strata** under the
  sheet, plus the existing offset, capped below the client ceiling. Restack also when the host strata
  changes (Chonky sets it lazily and defers in combat or M+). On stock and EUI, recon found no stacking
  bug; the boxes show only while an outfit row is selected and are visually weak, so they gain a
  stronger edge (the skin's accent border) at the same 14 px size. *Builder's call: exact edge token.*
- **Arrow (root cause: Blizzard's rule).** Blizzard shows the popout arrows only while the Equipment
  Manager pane is shown. We show Blizzard's own `button.popoutButton` (its own texture and coords, so
  the default look) on every slot, weapons included, **while the outfit window is shown**, per-button
  Show/Hide (never `EquipmentFlyoutPopoutButton_ShowAll/HideAll`, which write `flyoutLocked`), and
  re-show after Blizzard's `HideAll` post-hook while still wanted. Never in lockdown; restored at
  stand-down; never touch alpha (EUI's "hide flyout arrows" setting keeps working).
- **Alignment (root cause: stock geometry with no arrow drawn).** For PaperDoll-hosted horizontal
  slots, anchor the flyout's item frame to the slot itself so its first item lines up with the slot
  (same top and centre), leaving the arrow's visible 8 px between them: right column `TOPLEFT -> slot
  TOPRIGHT (8, y)`, left column (outward drawer) `TOPRIGHT -> slot TOPLEFT (-8, y)`, `y = BORDERWIDTH -
  (slotH - EFITEM_HEIGHT)/2`. This supersedes the 2026-11-04 G8 note "the right column needs nothing".
  Vertical (weapon) flyouts and the other hosts (Item Upgrade, Item Interaction, Runeforge) keep
  Blizzard's own anchor; a moved frame gets Blizzard's point back when we stop wanting it.

### G4. Nested menus keep their parent (D6)

- **Root cause:** LibKa0s's `W.ContextMenu` is one shared frame with no sub-menus; this addon fakes a
  submenu by refilling that frame, so the parent vanishes.
- **LibKa0s v1.87.0** (Widgets minor bump): true cascading menus. A row option `submenu = rows`;
  per-depth pooled frames anchored to the opening row's right edge (flipping left at the screen edge,
  clamped); opening a sibling closes deeper levels; the outside-click test covers every shown depth;
  CloseMenu and depth-1 OnHide close all; a keepOpen click repaints its own and every ancestor level.
  Single-level behaviour for every existing consumer is unchanged. API doc, CONSUMERS row, release,
  then re-vendor here.
- **Here:** `NS.OpenMenu` builds the whole tree once and hands it to the library. Rows are classed:
  keep-open with a tick on the current choice (Key binding, Title, a trigger without parameters, the
  existing toggles) or act-and-close (anything that opens a dialog, popup or window: Rename, Delete,
  Update to current items, Rebuild, Trigger settings, Change icon, a trigger with parameters; Bank
  moves close). The MenuUtil fallback returns `MenuResponse.Refresh` only for keep-open rows.

### G5. Gear icon size (D7)

The gear's texture is centred at the close X's art size (read from the close's own icon, falling back
to 12) inside the unchanged 18x18 button, and takes the X's rest and hover tint.

### G6. The outfit bar as a Ka0s HUD window (D8)

- **Frame:** LibKa0s `S.Shell` chrome with the skin's title band as the header (as DpsRace's race
  HUD), title `L["Outfits"]`, header controls lock and close (close writes `bar.shown = false`).
  The separate drag handle retires; the header drags. The test strip sits under the band.
- **Layout rows:** icons per line (0 = no wrap), padding to the edge (0-20, default 4), spacing
  (0-20, default 5, keeping today's 37 px pitch at size 32), icon size (16-64, default 32), grow
  direction (the saved corner follows the grow direction so a drag never flips it), vertical.
- **Icon rows:** border via `H.BorderGroup` (style, size, color with FromSkin), worn highlight (the
  corner mark plus an accent border; no glow, no new library).
- **Labels:** one per category section (above the row horizontally; above the column, truncated,
  vertically), on/off, font via `H.FontGroup` (face, size, outline, shadow, color, each FromSkin per
  skinning-§6), drawn through `S.HudFont`.
- **Frame color:** background and border via `H.ColorPair`/`H.BorderGroup` with FromSkin companions;
  with them on the bar is drawn exactly as a Ka0s window; off, the player's colors on a host plate
  sibling layer (never repaint the Shell).
- **No second switches** (options-ui-§15): lock, reset position, scale and "hide in combat" already
  exist on the Master and General rows and govern only the bar. The bar page offers a Reset position
  button and the header lock that write **the same** paths, and points to General visibility for
  combat; no new `bar.hideInCombat`.
- **Slash and binding:** `/or bar show|hide|toggle` (no word: toggle), and a "Toggle outfit bar" key
  binding.
- Split `modules/Bar.lua` so no file nears the cap and `Render` stays at CCN 15 or below.

### G7. Test mode shows the window (D9, D10)

- One rule: while test mode is on, the outfit window lists **sample outfits** under a `W.TestStrip`
  (`L["Test mode: sample outfits, nothing equipped"]`), docked or alone. The bar's strip moves under
  its header band.
- **Alone:** with the sheet closed, `/or test` shows the window by itself where a stock sheet would put
  it (TOPLEFT at UIParent x = 16 + 540, y = -116), the same single `TOPLEFT -> UIParent BOTTOMLEFT`
  point the dock uses, through `Dock.Refresh` only (never in lockdown). Opening the sheet docks it as
  usual. X or Escape hides it for the rest of the session's test mode (`testDismissed`) without ending
  the mode.
- **Samples:** a handful demonstrating each row state (worn, triggered, stored in the Equipment
  Manager, missing items, a spec icon, the default 132724), from `NS.Preview`. No item sections (they
  would arm secure buttons with real bag locations). Every outfit-row handler (wear, worn box, EM mark,
  gear menu, tooltip, Change icon) refuses `preview:` ids quietly; New outfit is disabled; entering
  test mode clears the slot selection so the sheet boxes and Slots All/None never act on a real outfit.
- The `standalone-windows` row and H17 are updated (D10).

## Non-goals

- No change to ChonkyCharacterSheet or EllesmereUI; we read their frames only.
- No glow highlight (would need LibCustomGlow), no compact header height (would need a LibKa0s band
  height option).
- No Quick Comms re-vendor: it gains nothing from cascading menus this round.

## Constraints

Everything in the 2026-11-04 plan's Global Constraints carries over: the Ka0s standard, the green gate
per repo, CRLF where present, strings through `L[...]`, no secure frame anchored, shown or hidden in
combat, Blizzard symbols verified at `Gethe/wow-ui-source` (`live`) and cited, re-vendor from the
**tag**. Never edit `tests/_kit/` by hand.

## Left to the builder

Exact pixel nudges inside the tab art, the selector edge token, sample outfit names, the header
control icons, the label truncation width, and the file split of the bar. Anything visual that cannot
be verified headless goes into `docs/smoke-tests.md` §12 for the owner's pass.
