# Settings panel

How Ka0s Outfitter Reborn is configured (documentation-§3, Tier 1; options-ui). The panel is
LibKa0s-Options, built from the rows in `NS.Schema`; categories are registered eagerly at
`OnInitialize` and page bodies are built on first open (options-ui-§1, §5). It is reached from the
game's **Settings → AddOns → Ka0s Outfitter Reborn**, from `/or config`, and from a left-click on
the minimap button.

The options stay in the addon: three subcategories, below options-ui-§4's five-subpanel threshold, so
there is no LoadOnDemand split (H21; the comment is in `settings/OptionsSetup.lua`).

## Pages

| Page | Covers |
|---|---|
| General | Master controls, automatic outfit changes and equip behavior, tooltips, the skin, and key bindings |
| Outfit Bar | Whether the bar shows and how it marks the worn outfit, opacity in combat; its layout, icons and their border, category labels, and its window frame (background and border) |
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
edge.

### Labels

`bar.labels.show` (`true`, *Show category labels*), then the library's Font block (`H.FontGroup`,
prefix `bar.labels.`): face, size, flags (From skin first), shadow, color and *Use class color*, with
*Use the skin's font*, then this addon's *Use the skin's color* and *Use the skin's shadow*. The
block's rows dim while the labels are off, the swatch excepted. One label per category, drawn as
HUD text through `S.HudFont`, its face resolved through `S.Resolve`: with *Ignore fonts* on, the
labels draw the stored face whatever *Use the skin's font* says (skinning-§6).

### Frame

`bar.showBackground` (`true`, *Show background*), then the Background block (`H.ColorPair`,
`bar.bgColor` with `bar.useClassColorBg`) with this addon's *Use the skin's background*
(`bar.bgFromSkin`), and the Border block (`H.BorderGroup`, prefix `bar.frame.`, on the skin's bar
family) with *Use the skin's color*. While *Use the skin's background* is on, the bar is drawn
exactly as a Ka0s window and the colors wait; off, they draw on a plate of the bar's own.

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

## Profiles

`settings/Profiles.lua`, page `profiles`, registered last: AceDBOptions' own table through
AceConfigDialog, under one line saying that profiles hold settings only and that outfits belong to
each character. See [profiles.md](profiles.md).

## Not settings

Per-outfit editing (the trigger, its parameters, the icon, the bar toggle) lives in the outfit window
and its dialogs, through `NS.OutfitSchema`'s instance rows (H12, [schema.md](schema.md)); no settings
page shows an outfit.
