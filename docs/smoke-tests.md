# Smoke tests

The in-game checks no headless run can reach: real rendering, layering, taint, and client behavior
the design could not measure ahead of time (audit-review-history). The owner runs them end to end
before a release. Each row has a pass criterion, and every row can run on the 1.1.0 build; section 10 maps what the headless gate leaves unverified to the
rows that verify it. Section 11 is the sheet, window and broker round of 2026-11-04, the owner's CP4
pass; section 12 is smoke round 2 of 2026-11-05 (the sheet button, slots, flyouts, menus, the
outfit bar and test mode), the owner's CP5 pass; section 13 is smoke round 3 of 2026-11-05 (the flyout,
the sheet button's icon, the bar's options, test mode's placement and menu, the Outfit Window page),
the owner's R7 pass.

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
| S5 | Keybindings | The Toggle outfit window binding is listed first under the addon's own header, then Toggle outfit bar |
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
| B1 | Show the outfit bar; drag it by its header; lock; vertical | Position saved; opacity in combat applies |
| B2 | Test mode | The bar and the window fill with sample outfits under a Test mode strip each; nothing is worn |
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
| SK1 | Open the window with an outfit selected, the outfit bar, the icon browser, and each dialog in turn (outfit, trigger with a field of each type, rebuild, the optimize progress); switch the skin from the Skin tab | Every one repaints at once with no `/reload`: the window and its scroll bar, a category, outfit and item row, the slot checkboxes in all three states and their accent edge, the footer buttons, the dialogs and their error line, the icon browser, the bar with its header band, labels, a button, its edge and its worn mark, and the test strips. The sheet button does **not** change: it wears the sheet's own tab (deviation `DEV-SKIN-SHEET-BUTTON`) |
| SK2 | Hover an item that an outfit holds, with comparisons on | The compare tooltips wear the skin; the stock comparison tooltips beside them keep Blizzard's look |
| SK3 | The character sheet under each skin | The sheet itself keeps Blizzard's look; only this addon's frames change |
| SK4 | Item icons in the list, the icon browser and the bar | Cropped with no art border showing; a 1 px edge in the window, in the icon browser and on the bar (the window outline: the bar always draws a window background) |
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
| Docked layout, anchoring and strata against real CharacterFrame children | The layer mock records levels; it cannot see Blizzard's or another addon's frames redrawn over the sheet (O29, O31) | W1, W2, W5, W6, W7, SK6, ST1-ST9, EU1-EU7, CH1-CH7, WC1-WC3, RS1-RS5, RE1-RE5, RC1-RC5 |
| EllesmereUI's and ChonkyCharacterSheet's live frames | The harness stands in for the frames their sources build; their timing and their own hooks are theirs | EU1-EU7, CH1-CH7, RE1-RE5, RC1-RC5 |
| The outward drawer against Blizzard's flyout | The flyout is a recorded stand-in; the real arrow, flyout and hosts that share it are the client's | ST6-ST9, EU6, EU7, CH7, RS4, RS5, RE5, RC5 |
| How the host-matched sheet button and the bar's window look are drawn | The harness records textures, coords and colors, never the pixels; whether a tab reads like its neighbors is the eye's | RS1, RS2, RE1, RE2, RC1, RC2, RB2-RB8 |
| Cascading menus on a real screen | Screen edges, the client's menu and the strata of what a row opens are the client's | RM1-RM4 |
| Test mode's alone window | The stock sheet's spot and the UI scale are the client's | RT1-RT5 |
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

Since section 12 (2026-11-05), the sheet button wears the host sheet's own tab and its icon is the
chest-armor icon (132724), the arrows show on every slot only while the window is open (otherwise
Blizzard's rule holds: only with the Equipment Manager pane), and a flyout's first item lines up with
its slot. The rows below are worded for the current build; where a look differs, section 12 is the
check.

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
| ST1 | Press `C` to open the sheet on the Character tab | Three square tab icons at the top right of the character pane (stats, titles, Equipment Manager), then the outfit tab just to the right of the Equipment Manager one, the same size (its look: RS1); on the stock sheet the button was missing before this round. It is not next to the close X |
| ST2 | Hover the outfit tab, click it, click it again | The tooltip reads *Toggle the Outfitter window*; the first click opens the outfit window, the second closes it |
| ST3 | Open the window, then pick the Reputation tab, the Currency tab, then Character again | The outfit tab and the window leave with the Character pane and both come back with it |
| ST4 | Window open: compare the window's top and left edges with the sheet's; if a mover addon is loaded, drag the sheet | The window's top is level with the sheet's top edge, no 30 px drop, and its left edge touches the sheet's right edge; a dragged sheet takes the window with it |
| ST5 | Select an outfit in the window and look at the slot boxes | Small boxes (14 px, about half the old size): the left column's on each slot's top-right corner, the right column's on the top-left, the main hand's on the top-right and the off-hand's on the top-left. Each item's icon stays readable |
| ST6 | Window open: hover the Head slot and click its arrow; then the Hands slot's; then the Main Hand's | Head: the arrow sits on the slot's left side, pointing left, and the flyout opens to the left of the slot, over the empty space, not over the right column. Hands: arrow on the right, flyout to the right, as Blizzard has it. Main Hand: arrow below, flyout downward, as Blizzard has it. No `ADDON_ACTION_BLOCKED` |
| ST7 | Close the window with the sheet still open, then open the Head slot's flyout | Blizzard's drawer: the arrow on the slot's right, the flyout opening right |
| ST8 | Open the window, close the sheet with `C`, reopen the sheet (the window stays shut), open the Head slot's flyout | Blizzard's drawer again; nothing is left mirrored |
| ST9 | Open the Item Upgrade frame (an upgrade NPC) and open its item flyout, with and without the outfit window open | Its flyout opens where Blizzard puts it in both cases |

### 11.2 EllesmereUI

Its Character Sheet skin must be on (EllesmereUI options: *Blizzard skin*, the themed character sheet).
With it off, the sheet is the stock one and section 11.1 applies.

| # | Do | See |
|---|---|---|
| EU1 | In a fresh session, press `C` for the first time | The text tabs Character, Titles, Equipment at the top; the *Outfits* text tab sits directly above **Equipment** (RE1), not over the close X. It is there on this first open, not only on the second |
| EU2 | Close and reopen the sheet; then `/reload` and open it again | The button keeps its place above Equipment each time |
| EU3 | Open the window; pick Reputation, then Currency, then Character | The *Outfits* tab and the window leave with the Character tab and come back with it; on Reputation and Currency no *Outfits* tab floats over the tab strip |
| EU4 | Window open: compare its top and left edges with EllesmereUI's sheet frame; move the sheet | Top flush with the sheet's top, left edge on the sheet's right edge, and it follows the sheet |
| EU5 | Select an outfit | The small boxes sit on the same corners as on the stock sheet (left column top-right, right column top-left, main hand top-right, off-hand top-left), over EllesmereUI's square slot art, not under it |
| EU6 | Window open: open the Head, Hands and Main Hand flyouts | Head opens left with the arrow on its left, in EllesmereUI's flat flyout skin; Hands opens right, Main Hand down. The skin and our position both hold: the flyout is flat **and** on the left |
| EU7 | Close the window, open the Head flyout; then turn on EllesmereUI's *Hide Slot Flyout Arrows*, open the window and hover a left-column slot | Window closed: Blizzard's place (arrow right, opening right). Arrows hidden: no arrow is shown in either place, and a modified hover still opens the flyout on the left while the window is open |

### 11.3 ChonkyCharacterSheet

| # | Do | See |
|---|---|---|
| CH1 | Out of combat, press `C` | Chonky's wide sheet with its row of tab icons above the item-level readout; the outfit tab sits right after the last tab icon, the same size, in the same tab art (RC1) |
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
| WC2 | Look at an outfit row, then click its Equipment Manager icon twice | Left to right: worn box, outfit icon, Equipment Manager icon, name, then the lightning and the gear at the right edge, all flat. The EM icon is full color for an outfit in the Equipment Manager and dimmed otherwise; each click toggles it, selected or not (R3M2), and the sheet's Equipment Manager list gains and loses the set |
| WC3 | Find an outfit with no icon and no trigger (make a new empty one) | Its icon is the game's chest-armor icon (132724), untinted and cropped like an item's. An outfit with an item's icon shows it edged and cropped like an item. The outfit bar and the broker object (11.5) show the same icons |
| WC4 | On a native outfit, gear menu, *Change icon…*: visit Recommended, Equipped and bags, Game icons, Glyphs; type in the search; pick a glyph with a color and Choose; then reopen and Cancel | There is no Markers tab. Search filters the open tab. The chosen glyph shows in its color on the row, on the bar and on the broker object; Cancel changes nothing |
| WC5 | On an Equipment Manager outfit: Change icon… pick a glyph; then a game icon; then *Outfitter chooses* | Glyph: the row, bar and broker show it, while the sheet's Equipment Manager list keeps the set's own icon. Game icon: it becomes the set's icon there too. Outfitter chooses: back to the trigger's icon, else an item's |

### 11.5 The Outfits broker

Needs a broker display (Titan Panel, ChocolateBar, Bazooka or similar).

| # | Do | See |
|---|---|---|
| BR1 | Add *Ka0s Outfitter Reborn: Outfits* to the display; wear an outfit, then take it off | The text is the worn outfit's name with its icon; with none worn, the brand with the chest-armor icon, untinted. The minimap still has one Outfitter Reborn button |
| BR2 | Left-click it | A menu: the brand as the title, *Open outfit window*, *Automatic changes* with a tick when on, then each category with its visible outfits, each with its icon and a tick when worn. An outfit with missing items reads red, a banked one blue. Hidden outfits are not listed |
| BR3 | In the menu: click an Accessory, click it again, then click a Complete outfit other than the worn one | The Accessory goes on and gets its tick; it comes off; the new Complete outfit goes on and the old one's tick goes. The menu stays open throughout |
| BR4 | Shift-click an outfit; then click *Open outfit window*, once with the window shut and once with it open | Shift-click closes the menu and the set-current prompt asks. Open outfit window opens the sheet and the window when shut, and leaves them open when they already are; it never closes either |
| BR5 | Right-click the object; hover it | Right-click toggles the window. The tooltip shows the brand, the current outfit and both click hints |
| BR6 | `/or disable`, look at the object and open its menu; `/or enable` | Disabled: the text is the brand; the outfit rows and Open outfit window are grayed and a click prints the one refusal line; Automatic changes still toggles. Enabled: everything is back |

## 12. Smoke round 2 (2026-11-05)

The smoke round 2 pass (design
[2026-11-05](superpowers/specs/2026-11-05-smoke-round-2-design.md), G1 to G7, D1 to D10), the owner's
CP5 pass. Sections 12.1 to 12.3 are one pass per sheet, set up as section 11's are (one sheet addon
enabled per session, at least one outfit, a head or shoulder item and a hands or ring item in the
bags). Sections 12.4 to 12.7 run once, on any sheet. `/fstack` names what is under the cursor:
`OutfitterRebornSheetButton`, `OutfitterRebornWindow`, `OutfitterRebornBar`.

### 12.1 The stock sheet

| # | Do | See |
|---|---|---|
| RS1 | Press `C`; look at the tab row at the top right of the character pane, then hover each tab | After the Equipment Manager tab, a fourth tab drawn exactly like the three beside it: the same 33x35 size, the same dark tab background and the strip under it, its bottom on the same line, and the chest-armor icon inside. Hovering it lights it as hovering a Blizzard tab does. It overlaps nothing |
| RS2 | Click the outfit tab; click it again | Window open: the tab looks selected, as a selected Blizzard tab does (the lighter background, no strip, no hover light). Window closed: it is back to unselected. Blizzard's own tabs keep their own selection throughout |
| RS3 | Open the window and select an outfit | A box on every one of the 18 slots, visible at a glance: 14 px, with an edge in the skin's accent, over each item's icon and not under it |
| RS4 | Window open: look at every slot; close the window; open the window, click the Equipment Manager tab, then the stats tab | Window open: a flyout arrow on every slot, the weapons' included (left column on the slot's left, pointing left; right column on its right; weapons below). Window closed: no arrows. Leaving the Equipment Manager tab with the window open: the arrows stay |
| RS5 | Window open: open the Head flyout, then the Hands flyout, then the Main Hand flyout; close the window and open the Head flyout again (click it while holding an item, or with the slot empty) | Head: opens to the left, its first item level with the slot (same top), 8 px of arrow between them. Hands: opens to the right, first item level with the slot, about 11 px away. Main Hand: opens downward where Blizzard puts it. Window closed: Blizzard's place. No `ADDON_ACTION_BLOCKED` |

### 12.2 EllesmereUI

Its Character Sheet skin must be on, as in section 11.2.

| # | Do | See |
|---|---|---|
| RE1 | In a fresh session, press `C`; look at the text tabs, then hover the *Outfits* label | An *Outfits* text tab stacked directly above **Equipment** and centered on it: the same face and size (10) as Character, Titles and Equipment, no background, no border, white at about 60 % at rest and full white on hover, as its neighbors are. It is there on the first open |
| RE2 | Click *Outfits*; click it again; with the window open change EllesmereUI's accent color | Window open: the label in EllesmereUI's accent (green by default), as the selected text tab is drawn; closed: back to dim white. After an accent change the label takes the new accent on its next paint (hover it or reopen the window) |
| RE3 | Change EllesmereUI's font, then close and reopen the sheet | The *Outfits* label takes the new face once the sheet reopens (it copies the face when it is placed, a known limitation) |
| RE4 | Open the window and select an outfit | The boxes show on every slot, over EllesmereUI's square slot art, with the accent edge |
| RE5 | Window open: look at every slot, then open the Head, Hands and Main Hand flyouts; then turn on EllesmereUI's *Hide Slot Flyout Arrows* and look again | Arrows on every slot while the window is open; Head opens left and Hands right, each first item level with its slot, in EllesmereUI's flat flyout skin; Main Hand down, untouched. With *Hide Slot Flyout Arrows* on: no arrow anywhere, and a modified hover still opens a flyout where described |

### 12.3 ChonkyCharacterSheet

| # | Do | See |
|---|---|---|
| RC1 | Out of combat, press `C`; look at Chonky's tab row | The outfit tab right after the last tab icon, in the same tab art and size. The row sits about 18 px right-heavy (accepted: Chonky centers its row for its own tabs, and this addon never moves them) |
| RC2 | Look closely at the strip under the tabs: Blizzard's tabs, Chonky's purple transmog tab at the left, and the outfit tab | The outfit tab carries Blizzard's Hider strip under it; Chonky's own extra tab has none. **Owner to judge** which reads better; record the call (keep the strip, or drop it on Chonky) |
| RC3 | Click the outfit tab; click it again | Selected while the window is open, unselected after, as on stock |
| RC4 | Open the window and select an outfit; open and close Chonky's stats, Mythic+, raid and GearFinder panels | The boxes are visible on every slot (before this round Chonky's slots, in a higher strata, covered them) and stay visible with a panel open; `/fstack` over a slot names the box above the slot button |
| RC5 | Window open: look at every slot; open the Head, Hands and Main Hand flyouts; close the window | As RS4 and RS5: arrows on every slot while the window is open, the left column opening left and the right column right, each first item level with its slot, Main Hand untouched; window closed: no arrows, Blizzard's place. No `ADDON_ACTION_BLOCKED` |

### 12.4 Icons and the window header (any sheet)

| # | Do | See |
|---|---|---|
| RI1 | Make a new empty outfit; show the bar; with nothing worn, look at the Outfits broker object | The outfit's icon is the game's chest-armor icon (132724), untinted and cropped like an item icon, on its row and its bar button. The broker shows the brand with the same icon, untinted. No gold coat hanger anywhere |
| RI2 | On a character with the seeded spec outfits (a new character, or after `/or deleteall`): look at each spec outfit; on one, *Change icon...*, pick a game icon, then reopen and pick *Outfitter chooses* | Each spec outfit shows its specialization's icon. The picked icon replaces it; *Outfitter chooses* brings the spec icon back. An Equipment Manager outfit keeps its set's icon |
| RG1 | Look at the window's header; hover the gear, then the X | The gear and the X are drawn at the same size and the same tint at rest, and both brighten the same way on hover. The gear still opens the settings |

### 12.5 Cascading menus (any sheet)

| # | Do | See |
|---|---|---|
| RM1 | Right-click an outfit; hover *Automation*, then a category; then hover *Key binding* | Each submenu opens beside its row, and every parent stays drawn. Hovering *Key binding* closes the Automation levels and opens its own |
| RM2 | Drag the outfit bar to the right edge of the screen; right-click a bar button and open *Automation*, then a category | Near the right edge a submenu opens to the left of its parent instead, and every level stays fully on screen |
| RM3 | In the menu: pick *Outfit 3* under *Key binding*; pick a title under *Title*; pick a trigger with no settings (no "..."); toggle *Show in outfit bar* and *Turn trigger off* | The menu stays open after each: the tick moves to the new choice, the key's old holder is renamed, and the parent row's label follows (*Automation:* the new trigger) |
| RM4 | In the menu, in turn: *Rename...*, *Delete*, *Update to current items*, *Rebuild for...*, *Trigger settings...*, *Change icon...*, a trigger with settings ("..."), and with the bank open a *Bank* move; then open a menu and click outside every level | Each closes every level, and the dialog, popup or window it opens is on top, never under a menu. A click outside closes them all; a click inside any level does not. Right-clicking a bar button, then `/or bar hide`, closes that menu; a menu the window opened stays when the bar hides |

### 12.6 The outfit bar (any sheet)

| # | Do | See |
|---|---|---|
| RB1 | With test mode off, `/or bar show`, `/or bar hide`, `/or bar toggle` twice, `/or bar`, `/or bar foo`; bind *Toggle outfit bar* and press it; click the bar header's X | Show and hide do; toggle and the bare verb flip it; `foo` prints *bar takes show, hide or toggle*. The key flips it. The X hides it and *Show outfit bar* unticks on the Outfit Bar page |
| RB2 | Look at the bar; drag it by its header; click the header's lock, try to drag; right-click the header | A Ka0s window: the skin's background, edge and title band, *Outfits* on the left of the band, a lock and an X on the right, each category's row labeled (*Complete outfits*, *Accessories*). The header drags it. Locked, it does not move and *Lock frame* on General → Master controls is ticked. The right-click opens the Outfit Bar page. There is no separate handle above the bar |
| RB3 | Outfit Bar → Display: each *Worn outfit highlight* value while wearing an outfit; *Opacity in combat* at 50 % and fight; *Reset position* here and on Master controls | Mark and border: the corner check and an accent edge; Corner mark and Border: one each; None: neither. In combat the bar draws at half its opacity. Both Reset buttons put the bar back at its start |
| RB4 | Layout: *Vertical layout*; *Per row or column* 2; *Padding* 0 then 20; *Spacing* 0 then 20; each *Grow* direction; with both on *Automatic*, drag the bar to each screen corner and add an outfit | Vertical stands each category in a column; 2 wraps every two icons; padding and spacing move as named; an explicit direction grows that way and a drag never makes the bar jump or flip; on Automatic the bar grows away from the nearest screen edges |
| RB5 | Icons: *Icon size* 16, then 64; the Border block with *Use the skin's border* and *Use the skin's color* off: show off and on, a style, a thickness, a color, *Use class color* | Every icon resizes and the bar fits them. With the skin's border and color on the edge is the skin's window icon outline; off, each Border row changes it as named |
| RB6 | Labels: *Show category labels* off and on; the Font block: face, size, outline, shadow, color and *Use class color*, each with its *Use the skin's ...* companion off; then the vertical layout | Each part changes as named only with its companion off; off, the labels go and the rows close up. Vertical: each label sits over its column, truncated to its width |
| RB7 | (Superseded by R3B2: *Show background* is gone.) Frame: *Show background* off and on; *Use the skin's background* off, then a *Background color*, *Use class color*, and the Border block | Background off: no chrome, the buttons alone. Skin's background off: the bar draws in the picked color with the picked border; on, it is a Ka0s window again |
| RB8 | Switch the skin with the bar showing | The band, the background, the edges, the labels and the worn highlight all repaint at once |

### 12.7 Test mode (any sheet)

| # | Do | See |
|---|---|---|
| RT1 | With the character sheet closed, `/or test` | The outfit window shows **alone**, where it sits beside a stock character sheet, with *Test mode: sample outfits, nothing equipped* under its title. Five samples: one worn (its box ticked), one with a trigger (the lightning), one with a spec icon, one in the Equipment Manager (its mark), one red for missing items with the default icon; no item sections. The bar shows the samples under its band with its own strip. It cannot be dragged |
| RT2 | Click each sample, its worn box, its EM mark, its gear; hover it; try *New outfit...*; open the sheet and look at the slots | Nothing is worn and nothing changes (the worn box keeps its drawn state); the tooltip says *Sample outfit (test mode). Nothing is equipped.*; *New outfit...* is disabled; no sample is selected, so no slot box and no *Slots* button shows |
| RT3 | Press `C`, then `C` again | The sheet opens and the window docks beside it as usual, still with the samples and the strip; closing the sheet puts it back alone |
| RT4 | Click the window's X; open the sheet; click the outfit tab; close everything and press Escape on the alone window in a new test session (`/or test` twice) | The X hides it and test mode stays on (the bar keeps its strip; the minimap menu's *Test mode* is ticked). Opening the sheet does not bring it back; the outfit tab does, docked. Escape hides it the same way |
| RT5 | With test mode on and the window alone, attack a training dummy | Test mode ends with one chat line, the alone window goes before combat locks it, and the bar shows real outfits again. `/or test` in combat refuses with a line |
| RT6 | With *Show outfit bar* ticked, `/or test`; click the bar header's X; `/or bar show`; `/or bar hide`; press *Toggle outfit bar* twice; `/or test` to end it; then untick *Show outfit bar* and repeat with a fresh `/or test` and `/or bar hide` | In test mode each hide puts the bar away for that test session only: test mode stays on, *Show outfit bar* stays ticked, and the slash words print *Outfit bar hidden (shown) for this test session*. Show and the key bring it back. When test mode ends the bar is back as before (ticked: shown; unticked: hidden), and a new test session shows it again |

## 13. Smoke round 3 (2026-11-05)

The smoke round 3 pass ([plan](superpowers/plans/2026-11-05-smoke-round-3.md), decisions E1 to E12),
the owner's R7 pass. It supersedes two rows of section 12: RB7's *Show background* is gone (E6), and
RT1's placement is now the screen center, draggable (E3). Sections 13.1 to 13.3 are one pass per sheet,
set up as section 12's are; sections 13.4 to 13.7 run once, on any sheet. Run 13.4's border rows, and
the flyout-tint rows (R3S1, R3S5, R3E1, R3C1), under Ka0s Default and under one other skin with a
colored window border. E1, E7 and E12 are built to the owner's rulings of 2026-11-05 (the plan's
*Owner rulings on the held items*); E1 is the accepted deviation `DEV-SKIN-FLYOUT-TINT`
([ARCHITECTURE.md](ARCHITECTURE.md#documented-deviations)).

### 13.1 The stock sheet

| # | Do | See |
|---|---|---|
| R3S1 (E1) | Window open: open the Head flyout; page it if it has a second page; then close the window with the flyout still open (or reopen the flyout with the window closed) | Window open: the flyout's whole rim, its paging strip and a second page's pieces included, is in the skin's window border color, near black under Ka0s Default and that skin's color under the other; the open slot's own glow is untouched. Window closed: the rim is Blizzard's gold again, no dark or gray piece left |
| R3S5 (E1) | Window open with the Head flyout up: switch the skin in General; then open Item Upgrade (or an Item Interaction or Runeforge window) and open its item flyout; back on the sheet with the window and a flyout open, type `/or disable`, then `/or enable` and open the window and a flyout again | The rim takes the new skin's border color at once. The other window's flyout draws Blizzard's gold, not the skin's. After `/or disable` the rim is Blizzard's; enabled again with the window open, the next flyout is tinted again. No `ADDON_ACTION_BLOCKED` |
| R3S6 (E1) | Window open with a flyout up: attack a training dummy | The window steps aside before combat locks it and the flyout's rim is Blizzard's gold through the fight; after it, with the window back, the next flyout is tinted. No `ADDON_ACTION_BLOCKED` |
| R3S2 (E2) | Window open, an outfit selected: open the Head flyout, then the Hands flyout; close each | While a flyout is open, its slot's check box stays on top of the flyout's slot highlight, as it is with the flyout closed. After the close the box is where it was, and the other slots' boxes never moved. No `ADDON_ACTION_BLOCKED` |
| R3S3 (E10) | Press `C`; compare the outfit tab with the Equipment Manager tab beside it; hover it; open the window | The chest-armor icon is the same size as the neighbors' icons, centered where theirs are, with the tab's bevel showing around it; the tab's bottom and spacing match the tabs between themselves; its border, hover light and selected look are those of the Blizzard tabs |
| R3S4 (E11) | Outfit Window → Character sheet: untick *Show the button on the character sheet*, then tick it; untick *Show slot check boxes* with an outfit selected; untick *Show the flyout arrows while the window is open*; set *Gap from the character sheet (px)* to 20, then 0 | The tab goes and comes back in place; `/or show` still opens the window without it. No box on any slot; ticked again, they return for the selection. With the window open no arrow shows and a flyout opens at Blizzard's place. At 20 the window stands 20 px right of the sheet, at 0 flush again |

### 13.2 EllesmereUI

| # | Do | See |
|---|---|---|
| R3E1 (E1) | As R3S1 | Window open: the rim Blizzard draws is in the skin's border color (where EllesmereUI's own flyout look hides Blizzard's rim, nothing of this addon's shows over it); window closed: the flyout looks exactly as EllesmereUI draws it without this addon |
| R3E2 (E2) | As R3S2 | The box stays over the flyout on EllesmereUI's square slot art, with its accent edge |
| R3E3 (E10) | Press `C`; look at the *Outfits* text tab | Unchanged from round 2 (the owner passed it): stacked above *Equipment*, in its face, size and color |
| R3E4 (E11) | As R3S4 | The same, with the *Outfits* text tab as the button and EllesmereUI's arrows (*Hide Slot Flyout Arrows* off) |

### 13.3 ChonkyCharacterSheet

| # | Do | See |
|---|---|---|
| R3C1 (E1) | As R3S1, on Chonky's slots | Window open: the rim in the skin's border color; window closed: Blizzard's gold again, on every slot Chonky shows |
| R3C2 (E2) | As R3S2, with Chonky's stats panel open | The box stays over the flyout and its highlight (Chonky's slots are already `HIGH`), and over the slot once the flyout closes |
| R3C3 (E10) | Press `C`; compare the outfit tab with Chonky's tab icons | The icon is the same size as Chonky's tab icons and on the same line as them, the tab spaced from its neighbor as they are from each other (the row's right-heavy offset of RC1 stays accepted) |
| R3C4 (E11) | As R3S4 | The same on Chonky's tab row and slots |

### 13.4 The outfit bar (any sheet)

| # | Do | See |
|---|---|---|
| R3B1 (E5) | Outfit Bar → Icons, under Ka0s Default and then another skin: *Show border* on, then off; then with *Use the skin's border* and *Use the skin's color* off, on and off again | On: every button carries a visible edge (the skin's window icon outline, gray under Ka0s Default, or the picked one); off: no edge at all on any button, in both skins and both companion states. Never inverted |
| R3B2 (E6) | Open Outfit Bar → Frame | There is no *Show background* row; the tab starts with the Background block. The bar always draws a background |
| R3B3 (E7) | Frame, *Use the skin's border* on: under Ka0s Default hover *Show border*, set it off, then on; switch to Azeroth (a real bar border style) and hover it again, then back to Ka0s Default; then turn the companion off and set *Show border* off, then on; each with *Use the skin's background* on, then off; then switch the skin with it off | Companion on under Ka0s Default (None): *Show border* is live; off, the bar has no edge, on, the edge (the picked one on the plate) shows. Under Azeroth: the row is dimmed and ticked, its tooltip says why, and the skin's edge shows whatever the switch says; back under Ka0s Default the row is live again and the switch governs. Companion off, *Show border* off: no edge in either background state, in every skin, and it stays off across the skin switch; on: the skin's edge (or the picked one on the plate) comes back (skinning-§6) |
| R3B4 (E8) | On a fresh profile (Profiles → New), look at Layout | *Padding (px)* reads 8 and *Spacing (px)* 4, and the bar draws 8 px in from its edges with 4 px between icons |
| R3B5 (E9) | Layout: hover *Grouping*; set it to *Collapsed*; open the Labels tab; set *Vertical layout*; set *Grouping* back to *Grouped* | The tooltip explains Grouped and Collapsed. Collapsed: every shown outfit in one group, no category label, the Labels tab's rows hidden with one note naming *Grouping* in their place; vertical, one column. Grouped: one labeled row per category again |

### 13.5 Test mode (any sheet)

| # | Do | See |
|---|---|---|
| R3T1 (E3) | With the sheet closed, `/or test` | The window opens in the middle of the screen and the bar just to its left (about 8 px apart), not stacked |
| R3T2 (E3) | Drag the window by its header; open the sheet with `C`, close it; `/or test` twice | The window moves and stays where dropped; docked, it follows the sheet; with the sheet closed it is back at the drop. The new session starts centered again (nothing saved) |
| R3T3 (E3) | Drag the bar; `/or test` to end test mode; then a new `/or test`, *Reset position*, end it | The dragged place is saved: the bar stays there after test mode ends. In the new session the bar starts beside the window again; Reset position puts it at its start, and test mode's end leaves it there |
| R3T4 (E3) | With test mode on and the window alone, start a drag and attack a training dummy | Test mode ends before lockdown, the window goes, and no `ADDON_ACTION_BLOCKED` |
| R3T5 (E4) | Click a sample's gear; open *Automation* and a category, then *Key binding*; hover a grayed row; click one | The menu opens for the sample and every submenu cascades. Every row that would change data is grayed, its tooltip *Not available in test mode*, and a click does nothing: no real outfit changes. After test mode ends a real outfit's menu is whole |

### 13.6 The Outfit Window page (any sheet)

| # | Do | See |
|---|---|---|
| R3W1 (E11) | Settings → AddOns → Ka0s Outfitter Reborn: open *Outfit Window*; hover each row | The page sits between Outfit Bar and Profiles, with the tabs Character sheet and List; every row has a tooltip |
| R3W2 (E11) | List: untick *Show Odds 'n ends*, *Show Warbound until equipped* and *Show Unopened*, each with the window open | Each section leaves the list at once; ticked again, it returns |
| R3W3 (E11) | List: untick *Show the Equipment Manager mark*, then *Show the automation mark* | The EM icon goes and the name starts where it was; the lightning goes from outfits with a trigger. Ticked again, both return |
| R3W4 (E11) | Change a few rows, then switch to another profile and back | Each surface (the tab, the boxes, the arrows, the gap, the sections, the marks) follows the profile at once |

### 13.7 The Equipment Manager mark and menu (any sheet)

E12, built to the owner's ruling: one click saves or removes, whether or not the outfit is selected.
The client saves a set from the gear worn at the moment, so a save wears the outfit first and makes
the set once the swap lands.

| # | Do | See |
|---|---|---|
| R3M1 (E12) | Hover the EM icon of an outfit not in the Equipment Manager, then of one that is | Not stored: *Not stored in the Equipment Manager*, then *Click to save in the Equipment Manager*. Stored: *Stored in the Equipment Manager*, then *Click to remove from the Equipment Manager* |
| R3M2 (E12) | With no outfit selected, click the dimmed EM icon of an outfit you are not wearing; then click its full icon | One click: the outfit is worn, and a moment later its icon is full and the sheet's Equipment Manager list has the set with that gear. The second click: the icon dims and the set leaves the list, the outfit kept as an Outfitter outfit |
| R3M6 (E12) | Click an outfit to select it; click its dimmed EM icon; then its full icon | The same as R3M2 on the selected outfit: one click saves it (the set appears, the icon fills, the outfit stays selected with its slot boxes), one click removes it. No click is spent on selecting or wearing first |
| R3M3 (E12) | Open an outfit's gear menu | *Save in equipment manager* sits directly below *Rename...*; its submenu has *On* and *Off*, the outfit's state ticked. Pick the other one: the menu stays open, the change is the same as R3M2's click, and the tick moves once the save lands |
| R3M4 (E12) | Attack a training dummy; in combat, click an EM icon, then pick On or Off in the menu | Refused with *Outfits can't be changed in combat.*; nothing is worn and the Equipment Manager is unchanged. A full Equipment Manager shows its popup before anything is worn |
| R3M5 (E12) | `/or test`: hover sample 4's EM icon and another sample's; open a sample's gear menu, then *Save in equipment manager* | The tooltip gives the sample's drawn state and *Not available in test mode*. The submenu opens, and *On* and *Off* are grayed |
