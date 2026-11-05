# Smoke tests

The in-game checks no headless run can reach: real rendering, layering, taint, and client behavior
the design could not measure ahead of time (audit-review-history). The owner runs them end to end
before a release. Each row has a pass criterion, and every row can run on the 1.1.0 build; section 10 maps what the headless gate leaves unverified to the
rows that verify it. Section 11 is the sheet, window and broker round of 2026-11-04, the owner's CP4
pass.

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
| W6 | The sheet button | Shows on the stock sheet, sits after the Equipment Manager tab, matches the tab icons' size and overlaps nothing; S1 to S3 check each sheet (O29) |
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
| Docked layout, anchoring and strata against real CharacterFrame children | The layer mock records levels; it cannot see Blizzard's or another addon's frames redrawn over the sheet (O29, O31) | W1, W2, W5, W6, W7, SK6, ST1-ST9, EU1-EU7, CH1-CH7, WC1-WC3 |
| EllesmereUI's and ChonkyCharacterSheet's live frames | The harness stands in for the frames their sources build; their timing and their own hooks are theirs | EU1-EU7, CH1-CH7 |
| The outward drawer against Blizzard's flyout | The flyout is a recorded stand-in; the real arrow, flyout and hosts that share it are the client's | ST6-ST9, EU6, EU7, CH7 |
| Broker displays | LibDataBroker's object is real; how a display draws its text, icon tint, menu and tooltip is the display's | BR1-BR6 |
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

## 11. Sheet, window and broker (2026-11-04)

The sheet and window feedback round (design
[2026-11-04](superpowers/specs/2026-11-04-sheet-and-window-feedback-design.md), G1 to G10), the owner's
CP4 pass. Sections 11.1 to 11.3 are one pass per sheet; play each in its own session so that only
that sheet's addon is enabled. Sections 11.4 and 11.5 run once, on any sheet.

Before each sheet pass:

- `/reload` with only that sheet's addon enabled: none for 11.1; **EllesmereUI** and
  **EllesmereUIBlizzardSkin** for 11.2; **ChonkyCharacterSheet** for 11.3.
- Have at least one outfit, so a row can be selected, and an item in the bags for a head or a
  shoulder slot, so a left-column flyout has something to list.
- `/fstack` names the frame under the cursor. A button reads `OutfitterRebornSheetButton`, the
  window `OutfitterRebornWindow`.

### 11.1 The stock sheet

| # | Do | See |
|---|---|---|
| ST1 | Press `C` to open the sheet on the Character tab | Three square tab icons at the top right of the character pane (stats, titles, Equipment Manager), then a gold coat hanger just to the right of the Equipment Manager one, the same size, with no border; on the stock sheet the button was missing before this round. It is not next to the close X |
| ST2 | Hover the coat hanger, click it, click it again | The tooltip reads *Toggle the Outfitter window*; the first click opens the outfit window, the second closes it |
| ST3 | Open the window, then pick the Reputation tab, the Currency tab, then Character again | The coat hanger and the window leave with the Character pane and both come back with it |
| ST4 | Window open: compare the window's top and left edges with the sheet's; if a mover addon is loaded, drag the sheet | The window's top is level with the sheet's top edge, no 30 px drop, and its left edge touches the sheet's right edge; a dragged sheet takes the window with it |
| ST5 | Select an outfit in the window and look at the slot boxes | Small boxes (14 px, about half the old size): the left column's on each slot's top-right corner, the right column's on the top-left, both weapons' on the top-right. Each item's icon stays readable |
| ST6 | Window open: hover the Head slot and click its arrow; then the Hands slot's; then the Main Hand's | Head: the arrow sits on the slot's left side, pointing left, and the flyout opens to the left of the slot, over the empty space, not over the right column. Hands: arrow on the right, flyout to the right, as Blizzard has it. Main Hand: arrow below, flyout downward, as Blizzard has it. No `ADDON_ACTION_BLOCKED` |
| ST7 | Close the window with the sheet still open, then open the Head slot's flyout | Blizzard's drawer: the arrow on the slot's right, the flyout opening right |
| ST8 | Open the window, close the sheet with `C`, reopen the sheet (the window stays shut), open the Head slot's flyout | Blizzard's drawer again; nothing is left mirrored |
| ST9 | Open the Item Upgrade frame (an upgrade NPC) and open its item flyout, with and without the outfit window open | Its flyout opens where Blizzard puts it in both cases |

### 11.2 EllesmereUI

Its Character Sheet skin must be on (EllesmereUI options: *Blizzard skin*, the themed character sheet).
With it off, the sheet is the stock one and section 11.1 applies.

| # | Do | See |
|---|---|---|
| EU1 | In a fresh session, press `C` for the first time | The text tabs Character, Titles, Equipment at the top; the coat hanger (20 px) sits just after **Equipment**, not over the close X. It is there on this first open, not only on the second |
| EU2 | Close and reopen the sheet; then `/reload` and open it again | The button keeps its place after Equipment each time |
| EU3 | Open the window; pick Reputation, then Currency, then Character | The coat hanger and the window leave with the Character tab and come back with it; on Reputation and Currency no coat hanger floats over the tab strip |
| EU4 | Window open: compare its top and left edges with EllesmereUI's sheet frame; move the sheet | Top flush with the sheet's top, left edge on the sheet's right edge, and it follows the sheet |
| EU5 | Select an outfit | The small boxes sit on the same corners as on the stock sheet (left column top-right, right column top-left, weapons top-right), over EllesmereUI's square slot art, not under it |
| EU6 | Window open: open the Head, Hands and Main Hand flyouts | Head opens left with the arrow on its left, in EllesmereUI's flat flyout skin; Hands opens right, Main Hand down. The skin and our position both hold: the flyout is flat **and** on the left |
| EU7 | Close the window, open the Head flyout; then turn on EllesmereUI's *Hide Slot Flyout Arrows*, open the window and hover a left-column slot | Window closed: Blizzard's place (arrow right, opening right). Arrows hidden: no arrow is shown in either place, and a modified hover still opens the flyout on the left while the window is open |

### 11.3 ChonkyCharacterSheet

| # | Do | See |
|---|---|---|
| CH1 | Out of combat, press `C` | Chonky's wide sheet with its row of tab icons above the item-level readout; the coat hanger sits right after the last tab icon, the same size, borderless |
| CH2 | Enter combat (a training dummy), leave it, then open the sheet for the first time in a fresh session; repeat with a Mythic+ key running if one is at hand | While Chonky has not built its backdrop yet the button sits after the stock Equipment Manager tab; once Chonky's sheet shows, it is after Chonky's last tab icon. It never sits on the close X |
| CH3 | Pick Reputation, Currency, then Character, with the window open | The button and the window leave with the Character tab and come back with it |
| CH4 | Window open, Chonky's side panels all closed | The window's top is flush with Chonky's sheet top (its dark backdrop, not Blizzard's smaller frame) and its left edge touches the backdrop's right edge |
| CH5 | Open each Chonky side panel in turn: stats, Mythic+, raid, GearFinder; close each | With a panel open the window moves right so its left edge touches that panel's right edge; with two open, the rightmost one's; closing the panel brings the window back to the sheet's edge within a moment |
| CH6 | Change Chonky's Mythic+ panel scale, open that panel | The window still sits on the panel's right edge, not inside or past it |
| CH7 | Select an outfit; open the Head, Hands and Main Hand flyouts with the window open, then with it closed | The small boxes on the same corners as the stock sheet; window open: Head's drawer opens left, Hands right, Main Hand down; window closed: all Blizzard's. No `ADDON_ACTION_BLOCKED` |

### 11.4 Window chrome, rows and icons (any sheet)

| # | Do | See |
|---|---|---|
| WC1 | Look at the window's header; click the X | An X sits beside the gear and closes the window. The gear, the scroll buttons and the New outfit mark are flat, with no bevel; New outfit… and Slots: All / None keep their button frames |
| WC2 | Look at an outfit row, then click its Equipment Manager icon twice | Left to right: worn box, outfit icon, Equipment Manager icon, name, then the lightning and the gear at the right edge, all flat. The EM icon is full color for an outfit in the Equipment Manager and dimmed otherwise; each click toggles it, and the sheet's Equipment Manager list gains and loses the set |
| WC3 | Find an outfit with no icon and no trigger (make a new empty one) | Its icon is the white coat hanger, whole, with no edge and no crop. An outfit with an item's icon shows it edged and cropped like an item. The outfit bar and the broker object (11.5) show the same icons |
| WC4 | On a native outfit, gear menu, *Change icon…*: visit Recommended, Equipped and bags, Game icons, Glyphs; type in the search; pick a glyph with a color and Choose; then reopen and Cancel | There is no Markers tab. Search filters the open tab. The chosen glyph shows in its color on the row, on the bar and on the broker object; Cancel changes nothing |
| WC5 | On an Equipment Manager outfit: Change icon… pick a glyph; then a game icon; then *Outfitter chooses* | Glyph: the row, bar and broker show it, while the sheet's Equipment Manager list keeps the set's own icon. Game icon: it becomes the set's icon there too. Outfitter chooses: back to the trigger's icon, else an item's |

### 11.5 The Outfits broker

Needs a broker display (Titan Panel, ChocolateBar, Bazooka or similar).

| # | Do | See |
|---|---|---|
| BR1 | Add *Ka0s Outfitter Reborn: Outfits* to the display; wear an outfit, then take it off | The text is the worn outfit's name with its icon; with none worn, the brand with the gold coat hanger. The minimap still has one Outfitter Reborn button |
| BR2 | Left-click it | A menu: the brand as the title, *Open outfit window*, *Automatic changes* with a tick when on, then each category with its visible outfits, each with its icon and a tick when worn. An outfit with missing items reads red, a banked one blue. Hidden outfits are not listed |
| BR3 | In the menu: click an Accessory, click it again, then click a Complete outfit other than the worn one | The Accessory goes on and gets its tick; it comes off; the new Complete outfit goes on and the old one's tick goes. The menu stays open throughout |
| BR4 | Shift-click an outfit; then click *Open outfit window*, once with the window shut and once with it open | Shift-click closes the menu and the set-current prompt asks. Open outfit window opens the sheet and the window when shut, and leaves them open when they already are; it never closes either |
| BR5 | Right-click the object; hover it | Right-click toggles the window. The tooltip shows the brand, the current outfit and both click hints |
| BR6 | `/or disable`, look at the object and open its menu; `/or enable` | Disabled: the text is the brand; the outfit rows and Open outfit window are grayed and a click prints the one refusal line; Automatic changes still toggles. Enabled: everything is back |
