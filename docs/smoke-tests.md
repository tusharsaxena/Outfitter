# Smoke tests

The in-game checks no headless run can reach: real rendering, layering, taint, and client behavior
the design could not measure ahead of time (audit-review-history). The owner runs them end to end
before a release. Each row has a pass criterion; a row marked **P4** cannot run until the port lands
the surface it checks.

## Sign-off

| Date | Build | Result |
|---|---|---|
| — | — | Not run yet. The scaffold (P3) has no outfit surface; the first full pass is after the port (P4) and before the 1.1.0 tag |

## How to run it

- Install the build as `Interface\AddOns\OutfitterReborn\`, with the old `Outfitter` folder **disabled**
  unless a row says otherwise.
- Use a character with a few equipment sets, a profession, and access to a battleground queue.
- Turn on `/of debug on` before starting and keep the console open; copy it into the result of any
  failed row.
- Note the client build in the Sign-off row.

## 1. Load and identity

| # | Check | Pass when |
|---|---|---|
| L1 | Log in | No Lua error; nothing is printed except the first-run skin picker on a new profile |
| L2 | The AddOns list | The entry reads **Ka0s Outfitter Reborn** with the 128 px logo; Category is accepted (O7) |
| L3 | `/of version` and `/outfitter version` | Both print `[OR]` and `1.1.0` |
| L4 | `/reload` | No error; settings kept |

## 2. Settings panel

| # | Check | Pass when |
|---|---|---|
| S1 | Settings → AddOns → Ka0s Outfitter Reborn | The landing page shows the logo, the notes, the command list and the credits line |
| S2 | General | Tabs in order: Master controls, (P4: Behavior, Tooltips,) Skin, Keybindings |
| S3 | Master controls | Every row reads and writes; Reset all asks first, and resets the profile only |
| S4 | Skin | Choosing a skin repaints the panel; the choice survives `/reload` |
| S5 | Keybindings | The Show window binding is listed under the addon's own header |
| S6 | Profiles | The note above AceDBOptions says outfits are per character; switching profiles applies the new profile's skin |
| S7 | Outfit Bar (P4) | Every row reacts at once on the bar |

## 3. Launcher, key bindings and slash

| # | Check | Pass when |
|---|---|---|
| K1 | Minimap button left-click | Opens the settings panel |
| K2 | Minimap button right-click | The library menu: Enabled, Locked, Test mode, Show window, Open settings, Open skin selector |
| K3 | Minimap button tooltip | The brand and (P4) "Current outfit: …" |
| K4 | `/of` and `/of help` | The command list, with the alias line |
| K5 | `/of disable`, then a feature verb | The one disabled line; `/of enable` restores |
| K6 | Show window key, out of combat and in combat | Opens the settings panel today; (P4) toggles the window, and from combat prints that it opens when combat ends (O8) |
| K7 | `/of wear [combat] A; B` (P4) | Wears B out of combat and A in combat |

## 4. Debug, diagnostics and performance

| # | Check | Pass when |
|---|---|---|
| D1 | `/of debug on`, `/of debug` | The console opens with one Init line (brand, version, schema, profile, outfit counts) |
| D2 | `/of diagnostics` | The report is appended, with the brand in both markers, the four sections, and no error |
| D3 | `/of diagnostics` while disabled | Still runs |
| D4 | `/of perf start`, `measure a`, a fight, `measure b`, a fight, `finish`, `/reload`, `report` | A report and one JSON line |

## 5. The outfit window and the sheet (P4)

| # | Check | Pass when |
|---|---|---|
| W1 | Open the character sheet, click the sheet button | The window docks to the right of the sheet and follows it when the sheet moves |
| W2 | Raise another window over the sheet | It covers the outfit window and the slot checkboxes too |
| W3 | Enter combat with the window open | It hides at once; no `ADDON_ACTION_BLOCKED`; it returns when combat ends (O4, O11) |
| W4 | Escape | Closes the window |
| W5 | Slot checkboxes | Beat the item buttons and any addon drawing over them; tri-state works |
| W6 | The sheet button | Does not overlap the close button (O29) |
| W7 | The window title | Fits (O31) |

## 6. Wearing and triggers (P4)

| # | Check | Pass when |
|---|---|---|
| T1 | Wear a Complete outfit, then an Accessory, then remove it | The Complete outfit's items come back |
| T2 | `/reload` with an Accessory worn | The stack is restored |
| T3 | Fishing, a gathering node, riding, swimming | Each trigger wears and removes its outfit |
| T4 | Enter a battleground and an arena | The map's outfit is worn over the generic one; `/of zone` shows the map ID and the active ids |
| T5 | Druid forms, rogue stealth, a spec change | Each trigger fires (O10, O27) |
| T6 | A lockbox tooltip | LOCKPICKING fires (O22, row D4) |
| T7 | Find Fish tracking | FISHING's tracking restore works (O5) |
| T8 | An error inside a trigger | Updates keep working afterward; `/of zone` reports no stuck bracket |
| T9 | Blizzard equipment sets | Each shows as an outfit, a save from the addon appears in the Equipment Manager (O18), and a save is refused in combat (O44) |

## 7. Bar, bank, tooltips and quick slots (P4)

| # | Check | Pass when |
|---|---|---|
| B1 | Show the outfit bar; drag; lock; vertical | Position saved; opacity in combat applies |
| B2 | Test mode | The bar fills with sample outfits under a Test mode strip; nothing is worn |
| B3 | Bank open: deposit, withdraw, `missing` | Items move; the missing list is right |
| B4 | An item's tooltip | Lists the outfits that use it; comparisons draw (O34, O41) |
| B5 | Click an empty slot | The flyout opens, sorted |

## 8. Locales and coexistence

| # | Check | Pass when |
|---|---|---|
| X1 | A zhCN, zhTW, koKR and ruRU client | Text renders in the skin's face, or the D7 row is written (H8) |
| X2 | The old Outfitter enabled too | One warning at login; `/of diagnostics` reports it |

## 9. The skin switch (P4)

The same surfaces `tests/skin_surfaces.lua` declares for the headless skin-switch suite (design §9.5),
checked by eye in the client.

| # | Check | Pass when |
|---|---|---|
| SK1 | Open the window with an outfit selected, the outfit bar, the icon chooser, and each dialog in turn (outfit, trigger with a field of each type, rebuild, the optimize progress); switch the skin from the Skin tab | Every one repaints at once with no `/reload`: the sheet button, the window and its scroll bar, a category, outfit and item row, the slot checkboxes in all three states, the footer buttons, the dialogs and their error line, the icon chooser, the bar, a bar button and its worn mark, the drag handle and the test strip |
| SK2 | Hover an item that an outfit holds, with comparisons on | The compare tooltips wear the skin; the stock comparison tooltips beside them keep Blizzard's look |
| SK3 | The character sheet under each skin | The sheet itself keeps Blizzard's look; only this addon's frames change |
| SK4 | Item icons in the list, the icon chooser and the bar | Cropped with no art border showing; a 1 px edge in the window and in the icon chooser, the HUD edge on the bar |
| SK5 | A dialog open over the window, then Escape twice | The dialog closes first, then the window |
| SK6 | Another addon moves the character sheet with the window open | The sheet still moves, and the window follows it |
