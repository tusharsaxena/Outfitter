# Settings panel

How Ka0s Outfitter Reborn is configured (documentation-§3, Tier 1; options-ui). The panel is
LibKa0s-Options, built from the rows in `NS.Schema`; categories are registered eagerly at
`OnInitialize` and page bodies are built on first open (options-ui-§1, §5). It is reached from the
game's **Settings → AddOns → Ka0s Outfitter Reborn**, from `/or config`, and from a left-click on
the minimap button.

The options stay in the addon: four subcategories, below options-ui-§4's five-subpanel threshold, so
there is no LoadOnDemand split (H21; the comment is in `settings/OptionsSetup.lua`).

## Pages

| Page | Covers |
|---|---|
| General | Master controls, automatic outfit changes and equip behavior, tooltips, the skin, and key bindings |
| Outfit Bar | Whether the bar shows and how it marks the worn outfit, opacity in combat; its layout (Grouped or Collapsed), icons and their border, category labels, and its window frame (background and border) |
| Outfit Window | The character sheet's button, slot check boxes and flyout arrows, the window's gap from the sheet; which item sections the list shows and which marks an outfit row draws |
| Profiles | AceDB profiles: settings only; outfits belong to each character |

## Landing page

The parent category (`OutfitterRebornMainPanel`), built from `NS.LANDING` (`settings/General.lua`):
the logo, the TOC's Notes, a **Slash Commands** section generated from `NS.COMMANDS`
(`NS.Slash:LandingRows()`), and a **Credits** line naming John Stephen (mundocani), the maintainer and
the earlier maintainers, testers and translators. It replaces the fork's About panel.

## General

`settings/General.lua`, page `general`. Tabs in declaration order:

### Master controls

Composed by `H.MasterControls` from one declaration, the canonical rows in canonical order
(options-ui-§15), with nothing omitted because the outfit bar is a real movable frame.

| Row | Path | Reaction |
|---|---|---|
| Enable Ka0s Outfitter Reborn | `enabled` | `NS.ApplyEnabled`: the stand-down latch's `disabled` hold |
| General visibility | `visibility` (`always`, `inCombat`, `outOfCombat`, `never`) | `NS.OnVisibilityChanged()`; governs the bar, after `bar.shown` |
| Master scale | `scale` | `NS.Bar.ApplyScale()`; the bar only (the note says the window follows the sheet) |
| Master opacity | `alpha` | `NS.Bar.ApplyAlpha()` |
| Lock frame | `locked` | `NS.Bar.SetLocked(v)` |
| Debug console | `state.debugConsole` | `NS.DebugLog:ConsoleCheckbox()` (session; Reset all turns it off) |
| Minimap button | `global.minimap.shown` | `NS.Launcher:IsShown()`/`SetShown()`; exempt from reset. The launcher's Show window entry has a key binding of its own, **Toggle outfit window** (`CLICK OutfitterRebornToggleWindow:LeftButton`, first in `Bindings.xml`), set on the Keybindings tab below or in Options → Keybindings |
| Test mode | `state.testMode` | `NS.Preview.Start`/`Stop` (session; Reset all ends it) |
| Reset position | button | Resets `bar.position` (the Outfit Bar page's Display tab has the same button, writing the same row) |
| Reset all settings | button | `NS.ShowResetAll` |

The Master reactions are resolved at call time. The host stamps `default = false` on the two session
rows, so the reset's session sweep reaches them (design §3.6).

### Behavior

| Subgroup | Path | Default | Label |
|---|---|---|---|
| Outfit changes | `auto.enabled` | `true` | Switch outfits automatically |
| Outfit changes | `equip.muteSounds` | `true` | Mute sound effects while changing outfits |
| Outfit changes | `equip.showErrors` | `true` | Show equip errors |
| Outfit changes | `equip.announceKeys` | `true` | Announce outfit changes from key bindings |
| Character sheet | `quickSlots.enabled` | `true` | Open the item flyout when you click an empty slot or drop an item on it |
| *(last, no heading)* | act | button | Delete all outfits… (`NS.Popups.ShowDeleteAll()`) |

`auto.enabled` has no `onChange`: the trigger binder's `SETTINGS_CHANGED` handler is the one route,
so the panel, `/or auto`, the key bindings and a profile change all reach it the same way.
`quickSlots.enabled` reacts with `NS.QuickSlots.SetEnabled(v)`. The act is drawn by
`NS.GENERAL_AFTER_GROUP["Behavior"]`, after the tab's last row (options-ui-§7).

### Tooltips

| Path | Default | Label |
|---|---|---|
| `tooltip.usedBy` | `true` | Show which outfits use an item |
| `tooltip.compare` | `true` | Compare items with your outfits |

The reactions are `NS.Tooltips.Refresh()` and `NS.Compare.Refresh()`; the hook bodies read both rows
themselves.

### Skin

`H.AppearanceTab({ owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice })`, the
library's tab, which draws every row itself. The eight rows stay schema rows with `skipRender`, so
the defaults resolve, every reset reaches them and `/or set skin.skin` validates:

| Path | Default |
|---|---|
| `skin.source` | `ka0s` |
| `skin.skin` | `ka0s` |
| `skin.ignorePanel` | `true` |
| `skin.ignoreFonts` | `false` |
| `skin.font` | `""` |
| `skin.texture` | `""` |
| `skin.outline` | `hud` |
| `skin.pickerSeen` | `false` |

### Keybindings

`H.KeybindingsTab({ bindings = NS.BINDINGS })`: the addon's key bindings, last (options-ui-§20). The
General Defaults tooltip ends with `H.KEYBINDS_UNCHANGED`: no reset changes a key.

## Outfit Bar

`settings/OutfitBar.lua`, page `bar` (smoke round 2 design G6). The bar is drawn as a Ka0s window:
the skin's title band is its header, with the title *Outfits* on the left and a lock and a close
on the right, and the header drags it. Tabs in declaration order:

### Display

| Path | Default | Label |
|---|---|---|
| `bar.shown` | `false` | Show outfit bar |
| `bar.worn.style` | `both` (`both`, `mark`, `border`, `none`) | Worn outfit highlight |
| `bar.combatAlpha` | `1.0` (0 to 1, step 0.05) | Opacity in combat (%) |
| `bar.position` | `TOPLEFT 200 -200` | Outfit bar position (`skipRender`; encodes `profile.windows.bar`) |
| *(after the tab)* | button | Reset position: `NS.ApplyDefault` on `bar.position`, the Master button's twin |

### Layout

| Path | Default | Label |
|---|---|---|
| `bar.layout.mode` | `grouped` (`grouped`, `collapsed`) | Grouping: Grouped is one block per category under its label; Collapsed is every shown outfit in one block with no labels, and every Labels row dims |
| `bar.vertical` | `false` | Vertical layout |
| `bar.layout.perLine` | `0` (0 to 20) | Per row or column (0 = one line) |
| `bar.layout.growH` | `auto` (`auto`, `right`, `left`) | Grow horizontally |
| `bar.layout.growV` | `auto` (`auto`, `down`, `up`) | Grow vertically |
| `bar.layout.padding` | `8` (0 to 20) | Padding (px) |
| `bar.layout.spacing` | `4` (0 to 20) | Spacing (px) |

### Icons

`bar.icons.size` (`32`, 16 to 64, *Icon size (px)*), then the library's Border block (`H.BorderGroup`,
prefix `bar.icons.`, on the skin's icon family): show, style, size, color and *Use class color*
with *Use the skin's border*, then this addon's *Use the skin's color*
(`bar.icons.borderColorFromSkin`). With both companions on, a button wears the skin's own HUD icon
edge. *Show border* (`bar.icons.borderShow`) is the only edge a button draws, in every skin: on, the
skin's edge or the player's; off, none (smoke round 3 E5: the button no longer takes `S.SquareIcon`,
whose permanent outline edge read as an inverted switch under Ka0s Default and a dead one under the
other skins; its art is cropped by hand instead).

### Labels

`bar.labels.show` (`true`, *Show category labels*), then the library's Font block (`H.FontGroup`,
prefix `bar.labels.`): face, size, flags (From skin first), shadow, color and *Use class color*, with
*Use the skin's font*, then this addon's *Use the skin's color* and *Use the skin's shadow*. The
block's rows dim while the labels are off, the swatch excepted, and every row of the tab (the swatch
again excepted) dims while the Layout tab's *Grouping* is Collapsed, since no label draws then.
One label per category, drawn as
HUD text through `S.HudFont`, its face resolved through `S.Resolve`: with *Ignore fonts* on, the
labels draw the stored face whatever *Use the skin's font* says (skinning-§6).

### Frame

The Background block (`H.ColorPair`,
`bar.bgColor` with `bar.useClassColorBg`) with this addon's *Use the skin's background*
(`bar.bgFromSkin`), and the Border block (`H.BorderGroup`, prefix `bar.frame.`, on the skin's bar
family) with *Use the skin's color*. While *Use the skin's background* is on, the bar is drawn
exactly as a Ka0s window and the colors wait; off, they draw on a plate of the bar's own. *Show
border* (`bar.frame.borderShow`) reaches both: off, the plate draws no edge and the skin's window
edge is dropped (`S.Shell`'s `noBorder`, replayed on every skin switch).

**No second switches** (options-ui-§15): scale, opacity, the lock, Reset position and General
visibility are the Master controls' and govern this one frame. The header's lock writes `locked`
and its close writes `bar.shown = false`, the same rows (in test mode the close only dismisses the
bar for that test session and writes nothing); hiding the bar in combat is General
visibility, which the combat opacity row's tooltip points to. Every color has its FromSkin
companion, default on (skinning-§6).

No row has an `onChange`: the bar re-renders on `SETTINGS_CHANGED` for any `bar.*` path.
`bar.position` reads and writes `POINT X Y` through its own get/set, refuses anything but a screen
corner and two numbers, and decodes every write into a new table, so a reset copies the default. Its
default is the defaults tree's `windows.bar`, encoded, and the load-time shape check skips it, since
its own get/set are its storage.

## Outfit Window

`settings/OutfitWindow.lua`, page `window` (smoke round 3 E11): everything configurable about the
docked outfit window and the sheet surfaces it brings. The Master controls govern the bar only, so
the window takes no scale, opacity or lock here; General > Behavior's flyout row (`quickSlots.enabled`,
the flyout's lists and clicks) is a different state from the drawer row and stays on General. Tabs in
declaration order:

### Character sheet

| Path | Default | Label |
|---|---|---|
| `window.sheetButton` | `true` | Show the button on the character sheet: off, the button stays hidden (still anchored); the window opens from the minimap button, a key binding or `/or show` |
| `window.slotBoxes` | `true` | Show slot check boxes: off, no box shows for any selection |
| `window.drawer` | `true` | Show the flyout arrows while the window is open: off, the arrows and flyouts stay Blizzard's |
| `window.dockGap` | `0` (0 to 40) | Gap from the character sheet (px): sheet units right of the dock's edge; never the alone test window |

### List

| Path | Default | Label |
|---|---|---|
| `window.sections.unused` | `true` | Show Odds 'n ends (*Item sections*) |
| `window.sections.warbound` | `true` | Show Warbound until equipped |
| `window.sections.boe` | `true` | Show Unopened |
| `window.marks.em` | `true` | Show the Equipment Manager mark (*Outfit rows*): off, the name takes its place |
| `window.marks.trigger` | `true` | Show the automation mark |

No row has an `onChange`, and the page draws no color, font or border block, so no FromSkin companion
or composed group is owed. Each surface follows a `window.*` write (`SETTINGS_CHANGED`) and a profile
switch (`PROFILE_CHANGED`) itself: modules/Dock.lua (the button, the drawer; the gap through the
follow's corner compare), modules/SlotEnables.lua (the boxes) and modules/Window.lua (the sections and
marks, redrawn on the follow tick).

## Profiles

`settings/Profiles.lua`, page `profiles`, registered last: AceDBOptions' own table through
AceConfigDialog, under one line saying that profiles hold settings only and that outfits belong to
each character. See [profiles.md](profiles.md).

## Not settings

Per-outfit editing (the trigger, its parameters, the icon, the bar toggle) lives in the outfit window
and its dialogs, through `NS.OutfitSchema`'s instance rows (H12, [schema.md](schema.md)); no settings
page shows an outfit.
