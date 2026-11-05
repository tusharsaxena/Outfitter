# Character sheet, outfit window and broker — feedback round 1 (design)

Date: 2026-11-04. Source: the owner's in-client feedback on 1.1.0 (eleven screenshots: stock sheet,
EllesmereUI sheet, ChonkyCharacterSheet, the window's columns, the slot boxes, the drawers, the menu).

## Intent

1.1.0 works, but on the character sheet it reads as bolted on. The way in is invisible on the stock
sheet, the window floats 30 px below the sheet's top, the window's columns don't explain themselves,
outfits have no icons, the slot boxes are too large, and the icon buttons carry bevels that look
dated. The old Outfitter also had a broker plugin people used as an outfit switcher, and this addon
dropped it. This round makes the addon look as if it belongs on the sheet, on all three sheets players
use, and gives the switcher back.

Success: on stock, EllesmereUI and Chonky sheets a player sees the outfit button next to the
Equipment Manager tab, opens a window that sits flush against the sheet, reads each row at a glance
(worn, icon, stored in the Equipment Manager, name, automation, menu), and can switch outfits from a
broker display without opening the sheet.

## Goals

### G1. The sheet button (ingress)

- One button that toggles the outfit window, placed **next to the Equipment Manager tab icon** on
  every supported sheet:
  - **Stock Blizzard**: beside the three sheet-tab icons at the top right of the character pane
    (stats, titles, Equipment Manager), after the Equipment Manager one.
  - **EllesmereUI**: beside its text tabs (Character / Titles / Equipment), after Equipment.
  - **ChonkyCharacterSheet**: beside its row of tab icons above the item-level readout, after the
    last one.
  - Today it sits left of the close X. On the stock sheet it does not show at all (a bug to find
    and fix as part of this). On EllesmereUI and Chonky it shows but in the wrong place.
- Its icon is the **default outfit icon (G5), colorized** (the addon's accent color, as opposed to the
  plain white glyph used for outfit rows). Borderless, matching the tab icons beside it in size.
- *Builder's call:* detection of EllesmereUI's and Chonky's sheets (addon loaded and their frame
  present), and the exact anchor and size on each, taken from the live frames.

### G2. Support all three sheets

Stock Blizzard, EllesmereUI's character sheet and ChonkyCharacterSheet: the button (G1), the window
dock (G3), the slot boxes and drawers (G7, G8) all work on each. Today's code knows only
`PaperDollFrame` and the stock `Character<Slot>` buttons; whether EllesmereUI and Chonky reuse those
buttons or draw their own is to be found out in the client and handled per sheet.

### G3. The window docks flush

The outfit window attaches to the **right** edge of the sheet with its **top edge flush with the
sheet's top edge** (today `Dock.Y_OFFSET = -30`). On EllesmereUI and Chonky "the sheet" is their
visible frame, not `PaperDollFrame`. The existing dock rules stay: parented to UIParent, followed not
anchored, never shown or hidden in combat (`modules/Dock.lua` header).

### G4. Row layout

Each outfit row reads, left to right:

`[worn checkbox] [outfit icon] [Equipment Manager icon] [name] … [automation icon] [gear menu]`

- **Worn checkbox**: as today.
- **Outfit icon**: new (G5).
- **Equipment Manager icon**: replaces today's second checkbox. The Equipment Manager's own icon
  (the one on the sheet's Equipment Manager tab), full color when the outfit is stored in the
  Equipment Manager, dimmed when it isn't. Clicking it toggles storage, exactly as the checkbox does
  today.
- **Automation icon**: stays the lightning, **without a border**.
- **Gear menu**: replaces today's `…` button. A borderless gear that opens the same outfit menu.

### G5. Outfit icons

- A **default outfit icon** for every outfit that has none: the Phosphor **coat hanger** glyph
  (`ph:coat-hanger`, already in LibKa0s' icon set; add it to this addon's `LibKa0s icons:`
  declaration). *My call.*
- The icon shows on the row (G4), on the outfit bar and in the broker's menu (G9).
- **Change icon…** in the outfit menu opens the **icon browser Quick Comms uses**, promoted into
  LibKa0s (G6). It replaces `modules/IconChooser.lua`.

### G6. Promote Quick Comms' icon browser into LibKa0s (owner ruling)

Two consumers with the same semantics, so it moves into the library (library-stack, *What earns
promotion*; anti-pattern #47 forbids copying it). Three repos, in order:

1. **LibKa0s**: the browser becomes a library member (tabs Markers / Game icons / Glyphs, search,
   glyph color, Choose / Cancel), with host-supplied title, opener callback and any extra source
   tabs. Docs, tests, release.
2. **Quick Comms**: re-vendor; its `settings/IconBrowser.lua` becomes a thin call into the library,
   with no behavior change.
3. **Outfitter Reborn**: re-vendor; Change icon… opens the library browser.

Outfitter-specific needs the library member has to allow:
- A **Recommended** source (the outfit's item icons and its trigger's icon). Today's chooser has it,
  and players pick an outfit's icon from its gear. *My call:* keep it as a host-supplied extra tab.
- **Glyph + color storage.** A glyph pick stores the glyph key and its color. A game-icon pick stores
  the fileID, as today.
- **Equipment Manager outfits** store their icon in the Equipment Manager set, which takes only a
  fileID. *My call:* a game-icon pick for an EM outfit writes the set's icon as today; a glyph pick
  for an EM outfit is stored addon-side and drawn instead of the set's icon, while the set keeps its own.
- *My call:* "no icon / Outfitter chooses" (the 134400 wildcard) keeps today's resolver
  (`Bar.OutfitIcon`, modules/Bar_Buttons.lua): the outfit's own icon, then its trigger's, then its
  first item's. Only the final fallback (132662 today) becomes the coat hanger. Row, bar and broker
  share that one resolver, so the bar's look changes only for outfits that had no icon at all.
- *My call:* tabs Outfitter shows: **Recommended** and **Equipped and bags** (both host-supplied, as
  today), then the library's **Game icons** (which covers today's Item, Ability and All sets) and
  **Glyphs**. The library's **Markers** tab is hidden for outfits, since raid markers aren't outfit
  icons. So the library member must let a host hide built-in tabs and add its own.
- *My call:* storage. `outfit.icon` widens from a number to a number (fileID) or a glyph record
  (`{ glyph = key, color = rgb }`), and stored numbers keep drawing. An Equipment Manager outfit's
  glyph override lives in `db.char`, keyed by the set ID, and is cleared when the set is deleted.

### G7. Slot boxes smaller

The per-slot selector boxes (`modules/SlotEnables.lua`, 24×24 today) are far too large. Make them
roughly half the size. *Builder's call:* exact size, checked in the client.

### G8. Slot box and drawer orientation

- **Left column slots**: the box sits in the slot's **top-right** corner, and the item drawer (the
  equipment flyout's arrow and the flyout itself) sits on the slot's **left** side and **opens left**.
- **Right column slots**: the box sits **top-left**, and the drawer sits on the **right** and opens
  **right**.
- *My call:* the weapon slots along the bottom keep today's drawer (below, opening down) and put the
  box top-right.
- **Owner ruling:** the outward drawer applies **only while the outfit window is showing**. Otherwise
  Blizzard's drawer is left exactly as it is.
- The drawer is Blizzard's `EquipmentFlyout`. It is not protected, so repositioning it out of
  combat is allowed, but it must stay hook-based and touch no secure frame
  (`docs/taint.md`).

### G9. The outfit broker object (owner ruling: second object)

The Ka0s launcher stays **exactly** as the standard requires (one launcher object, left-click
settings, right-click toggle menu, the logo). Next to it, a **second** LibDataBroker object of type
`data source` that replicates the old addon's `OutfitterLDB.lua`
(`git show d396f11:OutfitterLDB.lua`, `OutfitterMinimapButton.lua`):

- **Name**: *My call*: `OutfitterRebornOutfits`, label *Outfitter Reborn: Outfits*. Not `"Outfitter"`,
  which the old addon owns and may still register.
- **Icon and text** follow the current outfit (`NS.Stack`), its icon (G5) and name. With none, the
  brand and the colorized default icon.
- **Left-click** opens the outfit selector menu:
  - a title (the brand);
  - *Open outfit window*;
  - *Automatic changes*, a toggle (`auto on|off`, the same handler as the verb);
  - then every visible outfit, grouped by category in the window's order, each with its icon and a
    check when worn. The name is red when items are missing and blue when banked (the window's
    status colors).
  - Click: a worn non-Complete outfit is removed; anything else is worn. **Modifier-click** asks to
    make it the current outfit (the legacy `AskSetCurrent`).
- **Right-click** toggles the outfit window.
- **Tooltip** (new; the old one had none): the brand, the current outfit, the two click hints.
- Stood down: the object stays (setup), its menu's outfit entries are refused with the one refusal
  line (slash-commands-§7), and the text shows the brand.
- Not registered with LibDBIcon. It appears only in broker displays, so the minimap keeps one button.
- **Standard:** launcher-§1 says exactly one LDB object. *My call:* record a row in
  `docs/ARCHITECTURE.md` → *Documented deviations* (rule `launcher-§1`), not an upstream change.

### G10. Window chrome

- The **close X** comes back beside the header's gear. The code calls `NS.MakeCloseButton`, but in
  the client nothing shows; find out why.
- **Remove the border/bevel** from the header gear and the window's other small icon buttons: the
  row's lightning (G4), the row's gear menu (G4), the New outfit mark, and the scroll buttons.
  Text buttons (New outfit…, Slots: All / None) keep theirs.

## Non-goals

- No change to the Ka0s launcher, the minimap button, its menu or the key bindings.
- No change to how outfits are worn, the stack, triggers or the Equipment Manager mirror.
- No new settings rows for any of this, except what the deviation register needs.
- The outfit bar's look is untouched apart from showing the new icons.

## Anti-goals

- Anything that taints the character sheet, the Equipment Manager or the flyout, or makes the sheet
  unmovable for other addons (the reason the window is docked, not anchored).
- A second copy of the icon browser in this addon.
- Breaking a player's stored outfit icons: existing fileIDs keep drawing.

## Constraints

- The Ka0s WoW Addon Standard. Any new departure is a deviation row (G9 is the one expected).
- Green gate per commit: `lua tests/run.lua` and the bounded `luacheck .` (0/0).
- **Owner ruling (2026-11-04), for this work only:** commits on feature branches in all three repos,
  the LibKa0s tag and release, and the re-vendors may go ahead without stopping. Push to origin after
  each major milestone; **never merge without the owner's go-ahead**. After the merge, delete every
  branch, stash and worktree this run created.
- LibKa0s release and re-vendor follow that repo's own `docs/releasing.md` and the
  `wow-revendor-libka0s` flow.
- The slash rename (`/or`, `/outfitterreborn`), still uncommitted in the working tree, lands first.

## How the work is staged (my call)

EllesmereUI's and ChonkyCharacterSheet's sources are installed locally
(`G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\`, `/mnt/g/...` in WSL), so their
frames, slot buttons and drawers are read from source, not probed. **Owner ruling:** one in-game
check, before the merge. Everything is built against the sources and the headless suite, pushed, and
handed over with a smoke checklist; fixes from that pass land on the same branch. If EllesmereUI or
Chonky draw their own slot buttons and drawers, G2 and G8 grow for that sheet: the builder decides
and records why.

## Left to the builder

- Sheet detection and anchors for EllesmereUI and Chonky (G1–G3, G8). Each needs an in-client look.
- The colorized icon's exact tint, the slot box size, icon sizes in the row.
- The library member's API shape for the icon browser, within LibKa0s' conventions.
- Order of work, provided the LibKa0s release lands before the two re-vendors.
