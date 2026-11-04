# Smoke tests

The in-game checks no headless run can reach: real rendering, layering, taint, and client behavior
the design could not measure ahead of time (audit-review-history). The owner runs them end to end
before a release. Each row has a pass criterion, and every row can run on the 1.1.0 build; section 10 maps what the headless gate leaves unverified to the
rows that verify it.

## Sign-off

| Date | Build | Result |
|---|---|---|
| — | — | Not run yet. The headless gate is green at P5 (`docs/automated-tests/`, newest bundle); the first full pass is before the 1.1.0 tag |

## How to run it

- Install the build as `Interface\AddOns\OutfitterReborn\`, with the old `Outfitter` folder **disabled**
  unless a row says otherwise.
- Use a character with a few equipment sets, a profession, and access to a battleground queue.
- Turn on `/or debug on` before starting and keep the console open; copy it into the result of any
  failed row.
- Note the client build in the Sign-off row.

## 1. Load and identity

| # | Check | Pass when |
|---|---|---|
| L1 | Log in | No Lua error; nothing is printed except the first-run skin picker on a new profile |
| L2 | The AddOns list | The entry reads **Ka0s Outfitter Reborn** with the 128 px logo; Category is accepted (O7) |
| L3 | `/or version` and `/outfitterreborn version` | Both print `[OR]` and `1.1.0` |
| L4 | `/reload` | No error; settings kept |

## 2. Settings panel

| # | Check | Pass when |
|---|---|---|
| S1 | Settings → AddOns → Ka0s Outfitter Reborn | The landing page shows the logo, the notes, the command list and the credits line |
| S2 | General | Tabs in order: Master controls, Behavior, Tooltips, Skin, Keybindings |
| S3 | Master controls | Every row reads and writes; Reset all asks first, and resets the profile only |
| S4 | Skin | Choosing a skin repaints the panel; the choice survives `/reload` |
| S5 | Keybindings | The Show window binding is listed under the addon's own header |
| S6 | Profiles | The note above AceDBOptions says outfits are per character; switching profiles applies the new profile's skin |
| S7 | Outfit Bar | Every row reacts at once on the bar |

## 3. Launcher, key bindings and slash

| # | Check | Pass when |
|---|---|---|
| K1 | Minimap button left-click | Opens the settings panel |
| K2 | Minimap button right-click | The library menu: Enabled, Locked, Test mode, Show window, Open settings, Open skin selector |
| K3 | Minimap button tooltip | The brand and "Current outfit: …" |
| K4 | `/or` and `/or help` | The command list, with the alias line |
| K5 | `/or disable`, then a feature verb | The one disabled line; `/or enable` restores |
| K6 | Show window key, out of combat and in combat | Toggles the window, and from combat prints that it opens when combat ends (O8) |
| K7 | `/or wear [combat] A; B` | Wears B out of combat and A in combat |

## 4. Debug, diagnostics and performance

| # | Check | Pass when |
|---|---|---|
| D1 | `/or debug on`, `/or debug` | The console opens with one Init line (brand, version, schema, profile, outfit counts) |
| D2 | `/or diagnostics` | The report is appended, with the brand in both markers, the addon's seven sections (identity, settings, state, zone, equip, bindings, rejected), and no error |
| D3 | `/or diagnostics` while disabled | Still runs |
| D4 | `/or perf start`, `measure a`, a fight, `measure b`, a fight, `finish`, `/reload`, `report` | A report and one JSON line |

## 5. The outfit window and the sheet

| # | Check | Pass when |
|---|---|---|
| W1 | Open the character sheet, click the sheet button | The window docks to the right of the sheet and follows it when the sheet moves |
| W2 | Raise another window over the sheet | It covers the outfit window and the slot checkboxes too |
| W3 | Enter combat with the window open | It hides at once; no `ADDON_ACTION_BLOCKED`; it returns when combat ends (O4, O11) |
| W4 | Escape | Closes the window |
| W5 | Slot checkboxes | Beat the item buttons and any addon drawing over them; tri-state works |
| W6 | The sheet button | Does not overlap the close button (O29) |
| W7 | The window title | Fits (O31) |
| W8 | In combat with the window gone: change an outfit from the bar, press a wear key, rebind a key on the Keybindings tab | The wear follows the client's combat rules; the window's secure rows are not rebuilt until combat ends; a binding change in combat is refused or waits, never half-applied; no `ADDON_ACTION_BLOCKED` appears (O11) |
| W9 | The icon browser's search (Change icon...); the Title submenu on a character with 200+ titles | Search on Recommended and Equipped and bags finds icons by item or trigger name, on Game icons by texture id; the submenu opens in 30-row chunks with "More" and stays usable (O38) |

## 6. Wearing and triggers

| # | Check | Pass when |
|---|---|---|
| T1 | Wear a Complete outfit, then an Accessory, then remove it | The Complete outfit's items come back |
| T2 | `/reload` with an Accessory worn | The stack is restored |
| T3 | Fishing, a gathering node, riding, swimming | Each trigger wears and removes its outfit |
| T4 | Enter a battleground and an arena | The map's outfit is worn over the generic one; `/or zone` shows the map ID and the active ids |
| T5 | Druid forms, rogue stealth, a spec change | Each trigger fires (O10, O27) |
| T6 | A lockbox tooltip | LOCKPICKING fires (O22, row D4) |
| T7 | Find Fish tracking | FISHING's tracking restore works (O5) |
| T8 | An error inside a trigger | Updates keep working afterward; `/or zone` reports no stuck bracket |
| T9 | Blizzard equipment sets | Each shows as an outfit, a save from the addon appears in the Equipment Manager (O18), and a save is refused in combat (O44) |
| T10 | Wear an outfit that holds two unique-equipped items of one family (two of the same unique ring or trinket, or past an equipped-limit category's count) | The outfit is worn in full with no "unique-equipped" error; if the client still refuses one item, the rest is worn, the error does not repeat on every update, and `/or zone` shows no stuck bracket (O17 uniqueness shape) |
| T11 | Fishing with a pole outfit, entering combat with Fishing worn | The action bar page change is skipped in combat and applied when combat ends (O23) |
| T12 | A boss encounter (a raid or dungeon boss) with triggers on and `/or debug on` | No Lua error while health, power, auras or item links read as secret values; a trigger that needs one holds its outfit instead of flapping; `/or diagnostics` after the fight shows no stuck bracket |
| T13 | A potion or trinket with a use duration | The duration the addon reads matches the tooltip; record the item and the client build when it does not (O15) |

## 7. Bar, bank, tooltips and quick slots

| # | Check | Pass when |
|---|---|---|
| B1 | Show the outfit bar; drag; lock; vertical | Position saved; opacity in combat applies |
| B2 | Test mode | The bar fills with sample outfits under a Test mode strip; nothing is worn |
| B3 | Bank open: deposit, withdraw, `missing` | Items move; the missing list is right |
| B4 | An item's tooltip | Lists the outfits that use it; comparisons draw (O34, O41) |
| B5 | Click an empty slot | The flyout opens, sorted |
| B6 | With Pawn, then WeightsWatcher, loaded: open Rebuild (optimize) and pick each addon's stat category | Pawn lists one stat per visible scale and WeightsWatcher one per active weight; values match the addon's own tooltip; hiding a Pawn scale removes it the next time the list opens; nothing errors without either addon |

## 8. Locales and coexistence

| # | Check | Pass when |
|---|---|---|
| X1 | A zhCN, zhTW, koKR and ruRU client | Text renders in the skin's face, or the D7 row is written (H8) |
| X2 | The old Outfitter enabled too | One warning at login; `/or diagnostics` reports it |
| X3 | Common addons that register slash commands (e.g. a bag addon, a raid tool) | `/or` reaches this addon; record any collision (O3) |
| X4 | `/or diagnostics` after login | The O17 client APIs (uniqueness, warbound, usability, item stats, Azerite, bank container) answer, or their tooltip or ladder fallback is the one in use |

## 9. The skin switch

The same surfaces `tests/skin_surfaces.lua` declares for the headless skin-switch suite (design §9.5),
checked by eye in the client.

| # | Check | Pass when |
|---|---|---|
| SK1 | Open the window with an outfit selected, the outfit bar, the icon browser, and each dialog in turn (outfit, trigger with a field of each type, rebuild, the optimize progress); switch the skin from the Skin tab | Every one repaints at once with no `/reload`: the sheet button, the window and its scroll bar, a category, outfit and item row, the slot checkboxes in all three states, the footer buttons, the dialogs and their error line, the icon browser, the bar, a bar button and its worn mark, the drag handle and the test strip |
| SK2 | Hover an item that an outfit holds, with comparisons on | The compare tooltips wear the skin; the stock comparison tooltips beside them keep Blizzard's look |
| SK3 | The character sheet under each skin | The sheet itself keeps Blizzard's look; only this addon's frames change |
| SK4 | Item icons in the list, the icon browser and the bar | Cropped with no art border showing; a 1 px edge in the window and in the icon browser, the HUD edge on the bar |
| SK5 | A dialog open over the window, then Escape twice | The dialog closes first, then the window |
| SK6 | Another addon moves the character sheet with the window open | The sheet still moves, and the window follows it |

## 10. What the headless run cannot reach

The headless gate (design §13 step 11) mocks the client, so it proves the logic and leaves these to
this list. Each is checked by the rows named beside it; an O-number is a design §14 open issue marked
"client check", also listed in [known-limitations.md](known-limitations.md).

| Unverified headless | Why the harness cannot reach it | Rows |
|---|---|---|
| Real equips | The mock moves items by the plan; the client's swap timing, item locks and bag-full refusals are its own | T1, T2, T3, T10 |
| The unique-equip error path | The mock ranks unique keys from captured fixtures; the client's error and `GetItemUniquenessByID`'s 12.x shape are not mocked (O17) | T10, X4 |
| Docked layout, anchoring and strata against real CharacterFrame children | The layer mock records levels; it cannot see Blizzard's or another addon's frames redrawn over the sheet (O29, O31) | W1, W2, W5, W6, W7, SK6 |
| The combat hide and restore of the window | Lockdown is a flag in the mock; implicit protection of the rows is assumed worst-case (O4, O11) | W3 |
| Refusals of secure rows and bindings in combat | The client's `ADDON_ACTION_BLOCKED` and binding protection are not emulated (O8, O11, O44) | K6, W8, T9 |
| Escape ordering | `UISpecialFrames` order is the client's | W4, SK5 |
| CJK and Cyrillic in skin faces | Glyph coverage is the font file's; the harness checks paths, not rendering (H8) | X1 |
| Pawn and WeightsWatcher live | Their globals are stubbed; the live scale and weight tables are theirs | B6 |
| Secret-value windows in an encounter | The harness seals values on demand; which reads the client seals, and when, is its own | T12 |
| O5 Find Fish tracking | `C_Minimap.GetTrackingInfo` IDs | T7 |
| O7 Category accepted | The AddOns list | L2 |
| O10 Spec event name on 12.x | Event delivery | T5 |
| O15 Item use-duration text | Tooltip text | T13 |
| O17 Client API shapes | The 12.x APIs | T10, X4 |
| O18 `EQUIPMENT_SETS_CHANGED` timing | Event timing inside a save | T9 |
| O22 Lockpicking line text | GlobalStrings | T6 |
| O23 `ChangeActionBarPage` in combat | Protection | T11 |
| O27 Druid and rogue form spell IDs | Spell IDs | T5 |
| O33 Icon search sources | `GetMacroIcons` on 120105 | W9 |
| O34 The Equipment Sets tooltip line | Tooltip data lines | B4 |
| O38 Title submenu with 200+ titles | Usability | W9 |
| O41 `GetPrimaryTooltipInfo()` field names | Tooltip info | B4 |
| O3 `/or` collision | Other addons | X3 |
