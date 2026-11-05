# Testing

How to verify Ka0s Outfitter Reborn (testing-§6). What to install first is in the root
[`DEPENDENCIES.md`](../DEPENDENCIES.md); this page assumes it is done. Every command runs from the
**repo root**.

## Commands

| Command | What it does |
|---|---|
| `lua tests/run.lua` | The headless suite. Exits non-zero on any failure |
| `lua tests/run.lua -j auto` | The same, split across one worker per CPU (testing-§14) |
| `lua tests/run.lua --list > docs/test-cases.md` | Regenerates the case inventory without running anything |
| `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` | Lint, configured by `.luacheckrc`; must report 0 warnings and 0 errors. `luacheck` loads no kit, so it runs through the bounded runner (testing-§15) |
| `luac -p path/to/file.lua` | Syntax-check one file |
| `bash tests/_kit/run-automated-tests.sh` | All four out-of-game suites, written to a dated bundle ([automated-tests/README.md](automated-tests/README.md)); run it through the bounded runner |

Every Lua run is bounded by the vendored kit as it loads (memory, time, process depth; testing-§15).

## The commit gate

Before **every** commit: `lua tests/run.lua` green **and** `~/.claude/dev-copilot/bin/ka0s-bounded
luacheck .` at 0/0 (testing-§4). The runner's `--suite lint --suite tests --no-bundle` is the same
pair and writes nothing. Work is test-first: a failing case that pins the behavior, then the code.

## The four out-of-game suites

A suite gates a **commit** and a **release** (the tag) differently, so both are named:

| Suite | Command | Gates the commit? | Gates the release (tag)? |
|---|---|---|---|
| `lint` | `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` | yes | yes |
| `tests` | `lua tests/run.lua` | yes | yes |
| `perf` | `lua tests/perf.lua` | no, recorded only | yes, at `pass` (a `skip` is not evaluated) |
| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` | no, recorded only | yes, at `pass` with zero functions above CCN 15 |

The release is gated on all four at `pass` plus zero functions above CCN 15, `blindFiles` at 0 and a
run on which `lizard` did not raise (automated-tests-§3). Never run raw `lizard`: it is blind in
places in Lua, and the kit's sighted shadow is what the complexity suite measures.

## How the harness is built

- **`tests/_kit/`** is the shared harness, vendored byte-identical from the LibKa0s tag named in root
  `CLAUDE.md` (test kit revision 51). Never edit it; `test_vendor_sync` fails on any drift.
- **`tests/run.lua`** loads the vendored library in `LibKa0s.xml` order (asserting the seventeen leased
  majors' files are present) and the addon in **TOC order** (`Loader.tocFiles`), so the harness cannot
  drift from what the client loads (testing-§9). It runs `OnInitialize` and `OnEnable` like the
  client, and `loadInstance` builds isolated instances (a library-absent load passes `libFiles = {}`).
  It exposes `_G.OUTFITTERREBORN_TEST` to the local suites.
- **`tests/wow_mock.lua`** extends the kit's base mock with what this addon calls, and installs the
  two domain halves on every build: `tests/mock_gear.lua` (worn items, bags, the bank, the cursor and
  item info, moving items for real and recording each call in `M.__equipCalls`; `C_EquipmentSet` is
  in `tests/mock_gear_sets.lua`) and `tests/mock_world.lua` (instances and maps, add-on restrictions
  and auras, forms, units, pets, quests, CVars, titles, protected frames, the character sheet's
  frames, the tooltips). Both answer from `tests/fixtures/items.lua` and the named scenarios in
  `tests/fixtures/inventories.lua` (`M.__gear:load("full_bags")`). It also carries `fake`, the
  recorded stand-in a suite installs in place of a real module it isolates the case from. `tests/run.lua` wraps
  every `T.test` case so the fakes it installed are restored when it ends, pass or fail.
- **The whole login and the unit instance.** `T.load()` logs in as the client does, so since P4.27
  every instance holds the whole graph live (`OnEnable` resumes every module). A suite that pins one
  module and drives its `Resume` itself loads through `tests/unit_load.lua` instead: the same load and
  login with the resume walk emptied and the skin picker's login timer canceled. `test_disabled`,
  `test_surface_parity`, `test_skeleton` and the secrets engine cases run on the whole login.
- **`tests/spy.lua`** records calls on a REAL module's members and calls straight through: it replaced
  the fakes of the dialogs, the icon chooser, the outfit menu, the outfit dialog and the popups once
  those modules landed (P4.27).
- **`tests/fixtures/legacy/`** is the fork's behavior, captured at `7ea3dc3` by
  `tools/legacy_capture.lua` and never hand-edited (its README says how to regenerate it). The new
  suites assert against it: a *keep* pin asserts the legacy value, a *fix* pin the corrected one with
  a `-- legacy:` note.
- **A suite holds every frame it makes.** The kit tracks frames and their event registrations in
  weak-keyed tables, so a frame only those tables reach is collected at the next GC cycle and stops
  hearing its events; a client frame never is. When the cycle lands depends on the heap the earlier
  suites left, so a dropped frame fails at random and only in the full run. `listener()` in
  `test_mock_gear` keeps its frame on the list it returns, and its swap case forces a collection
  between registering and delivering to pin that.
- Every negative assertion was proven able to fail by mutating the code under test (testing-§12).

## The suites

Every suite is declared in `SUITES` in `tests/run.lua`; a file that is not listed loads nothing, and
the kit's inventory fails a `tests/test_*.lua` with no entry. Every suite is live: none is held
`pending`. The P5 gate found no function above CCN 15, so the `test_refactor_pins` entry it
reserved for green-before pins was dropped (design §13 step 1). The tables group and order
the suites as design §9.3 catalogs them (the kit's own suites close the structural group, as
there); the run order is `SUITES`' own, not this one. `test_packaging` fails when a declared suite
has no row here, or a row leaves its §9.3 group or order.

**Standard-required and structural**

| Suite | What it covers |
|---|---|
| `test_skeleton` | Registration under the folder name, the tagged printer, the DB defaults, the declared icons, the file headers, the bus wire names, the login resume walk, the legacy guard |
| `test_toc` | The TOC header: field order, Title, version, IconTexture, SavedVariables, the CurseForge project, no retired fields |
| `test_loadorder` | The runner's load list is the TOC's; every path exists; the folder order; the `LOAD-BEARING` lines; no legacy file back |
| `test_vendor_sync` | `libs/LibKa0s/` and `tests/_kit/` are exactly the tag root `CLAUDE.md` names, icons pruned to its declaration |
| `test_surface_parity` | Every degrade stub carries the surface of what it stands in for; every leased major has its row; the degraded login resumes the whole graph and stands it down and up |
| `test_disabled` | The disabled state is total: the kit's ten conformance steps on the real addon, and the Outfitter cases (an active trigger, the Equip bracket, the hook bodies, the Dock driver, the LoadPass timer, the rebuild) |
| `test_secrets` | The secret-value seam: the conversions, the bounded walk, the guards on both arms, the Compat accessors, the seam scan, and the engine on the whole login (secret links as empty slots, a secret level, the tooltip/compare/quick-slot/iteminfo guards, the balanced Equip count) |
| `test_secrets_states` | The states half of the secret-value seam: `PlayerIsFull`, the aura scan, the mana history |
| `test_no_loadstring` | No code runs from text anywhere: no `loadstring`, `load(`, `setfenv`, `RunScript`, no script field on a trigger, no `CUSTOM` id |
| `test_removed_apis` | No live file names an API, event or library the game or this rewrite removed (INV §18) |
| `test_file_budget` | Every authored Lua file, `tests/` and `tools/` included, stays under 1000 lines |
| `test_packaging` | What reaches players: the package folder, every maintainer file ignored, nothing ignored loaded, every media path resolves, the icon declaration is exactly what is drawn. Also the doc set's account of the rest: no `pending` suite, a row here per declared suite in its design §9.3 group and order, the retired-harness map, a `module-map.md` `## Not shipped` row per helper, and the README badge equal to `docs/test-cases.md` |
| `test_credits` | The landing credits, the README Credits block, the LICENSE copyright lines |
| `test_bus` | The full catalog, its wire names, exactly one sender per key over every call site |
| `test_mock_gear` | The domain mock's fidelity: plans move items for real, bag-full, the secret wrap, the Equipment Manager flake |
| kit `test_eol` | Every tracked file's line endings match `.gitattributes` |
| kit `test_prose` | No tracked authored file carries a British spelling (localization-§5); waivers are per file and per word in `tests/prose_waivers.lua` |
| kit `test_layout_cap` | Every file over the 1500-line cap is in the census in `ARCHITECTURE.md` |
| kit `test_diagnostics_contract` | `/or diagnostics` meets debug-logging-§14 |
| kit `test_lizard_sighted` | The complexity suite's sighted shadow |
| kit `test_skin_values`, `test_skin_switch` | The typed-color gate and the skin switch over `tests/skin_surfaces.lua` |

**Data, settings and slash**

| Suite | What it covers |
|---|---|
| `test_database` | The store: the migration stamp, a raising step, the profile and char walks, no `gOutfitter_*` reader, both `resolveRoot` functions |
| `test_schema` | The settings rows, the write seam, its forward to the outfit instance, the reset's reach |
| `test_settings` | Page registration and order, the General tabs, Master controls, the reset wording, the landing page |
| `test_reset` | Reset all keeps the character's outfits and the profile list; Delete all outfits re-seeds after the accept; switch and copy keep outfits |
| `test_slash` | The reserved verbs, bare `/or`, help, the schema CLI, both chat commands, the macro-conditional wrapper |
| `test_keybinds` | `Bindings.xml`, `NS.BINDINGS`, the hidden non-secure buttons and their press |
| `test_launcher` | The one LDB object, its static icon and label, the right-click menu, the tooltip line, the Minimap row |
| `test_locale` | The locale gates: the TOC-derived enUS set, cross-file duplicates, the overlays' gates, legacy coverage read from the overlays' end notes, format-directive safety (a translation's directives, in order, are a prefix of its English's). The overlays are generated by `lua tools/rekey-locales.lua` (`--check` writes nothing and exits 1 if an overlay differs from its output) |
| `test_diagnostics` | The `/or zone` and `/or diagnostics` sections: the instance line, the zone outfits, the STUCK line, rejected events, faulted bindings, a loaded legacy addon |

**Engine**

| Suite | What it covers |
|---|---|
| `test_slots` | The slot tables, aliases and phantom ids against the legacy capture; the Horde lance swap |
| `test_itemlink` | The link parse on full, short, signed, secret and nil links; the canonical bonus and modifier lists; the safe info lines |
| `test_item_match` | Exact and partial matching against the legacy capture, claimed duplicates, aliases, the upgrade track, Azerite as a set, the cooldown-item rules |
| `test_inventory` | The bag range with the bank closed and open, the debounce, the change payload, the sections, one item-info registration, per-pass claims |
| `test_outfits` | The record shape, categories, the LoadPass seeding, repair, rename, delete's order, the binding uniqueness, the slot tri-state |
| `test_equip_plan` | The change list: durability order, two-hand and Titan's Grip, unique ranks against the legacy plans, the off-hand ordering, the swaps, an empty plan |
| `test_equip_bracket` | The one Equip bracket: balanced on success and on a raise, its exact argument passing, no allocation and no held reference in the common case, the defers, the throttle, the muted SFX, the bags-full line, the `Diagnostic()` lines |
| `test_stack` | Wear and remove, accessories and Complete outfits, temp outfits, window recording, the compile, toggle and fallback, titles on a hand wear only, the persisted round trip |
| `test_em_sync` | The Equipment Manager mirror: every set, deletions, the zero-set flake, the 31-byte names, store and restore with every setting, the pending save; the one toggle (`SetStored`: worn first and saved once the swap lands, refused in combat, at the cap and on a taken name before anything is worn, the waiting save's 10 s cancel) |
| `test_bank` | Deposit, unique, others, withdraw and withdraw-others; bank-full; the missing report; refused closed and in combat |
| `test_item_stats` | Stats from the item's stat tokens and level, scored under a German client; the level rule; the Pawn and WeightsWatcher sources |
| `test_optimize` | The simple picks against the legacy capture, the seeded genetic search, cancel and stand-down, the progress lines, delivered once |
| `test_companion` | The battle-pet summon and dismiss by name, GUID and species; the blockers; the auto-summon watch and its cap |
| `test_api` | The `API.v1` members, the case-insensitive find, an isolated raising subscriber, and the global allow-list (no `Outfitter_*` or `gOutfitter_*`) |

**Triggers**

| Suite | What it covers |
|---|---|
| `test_zones` | The single zone source: unique map ids, generic and specific battlegrounds and arenas, the wear order, the first-sighting seed, the shape of the legacy tables |
| `test_states` | The state producers: the restriction, the aura scan and form poll, the dropped `UNIT_AURA` window, the forms, mounted, Dining and Spirit, `Set` |
| `test_triggers` | The catalog: well-formed descriptors, ids, categories, classes, events (no pseudo-event registered), typed parameters, icons, live resolution, `Finalize` |
| `test_trigger_binder` | The binder: fan-out, a faulting condition, the timers, the delays, Complete re-worn, smart unequip, `auto.enabled`, the coalesced rebind |
| `test_triggers_general` | The general triggers: dungeon and difficulty, buffs, target, the trinket and feet queues, zones, talents, Spirit, PvP flag |
| `test_triggers_trade` | The trade triggers: gathering, lockpicking, riding, swimming, fishing, dining, falling, resting, spellcast, cooking |
| `test_triggers_quest` | The quest triggers: the vehicle quests, the survey, the turn-in, pet battle, dance, companion |
| `test_triggers_class` | The class and spec triggers: caster, druid forms, stealth, Ghost Wolf, Feign Death, the per-class spec rows |
| `test_triggers_pvp` | Every zone row has a trigger on its own state, enumerated from the table |
| `test_triggers_parity` | The catalog against every legacy preset: each mapped or dropped with a reason, events, parameters, filing and sort, the counts |

**UI**

| Suite | What it covers |
|---|---|
| `test_sheet` | The sheet adapter: stock, EllesmereUI and Chonky told apart (addon loaded and its frame there: EllesmereUI's tab built, so its hidden state off the Character tab still reads eui; Chonky's backdrop shown), the fallback to stock when a sheet addon's skin is off, the button anchor per sheet, the dock edge past an open Chonky side panel |
| `test_dock` | The window dock: strata and level from the host, the secure queue under lockdown, combat hide and restore, the follow driver, Escape; the sheet button in each host's tab look (sidebar tab on stock and Chonky, selected while the window shows; EllesmereUI's text tab), the header gear at the close X's size and tint |
| `test_list_model` | The list model: section order, both sorts, nil names last, collapse; the sample outfits with no item section in test mode |
| `test_rows_secure` | The secure row children: built once, never moved after the build, disarmed in lockdown; the EM mark's one-click toggle and its state-and-hint tooltip |
| `test_slot_enables` | The slot checkboxes: one per slot on the character sheet, the tri-state, All and None, the restack to the host strata (the slot buttons' included) and its level cap, the accent edge |
| `test_outfit_menu` | The outfit context menu: the rows per kind, the bank rows, the binding labels, the title submenu, the trigger switch; the whole tree as cascading levels, keep-open radios and toggles against act-and-close rows, MenuUtil's Refresh; the bar's menu closing on every path that hides the bar, and only the bar's; test mode's browse-only menu for a sample (every data row disabled with its tooltip, the submenus cascading, no click reaching a seam), only in test mode; *Save in equipment manager*'s On/Off radios on the EM mark's path, and every row of the open menu following the outfit across its store |
| `test_dialogs` | The new-outfit and rename dialogs, the popups' data, the icon browser (Change icon...), the row's Equipment Manager mark (one click stores, the full-EM popup, one more unstores) |
| `test_trigger_dialog` | The trigger dialog: the draft, validation, Done writes through `SetMany` only, X and Escape discard, the nine field types |
| `test_bar` | The outfit bar: defaults, buttons, stacking, the icon ladder, alpha and fades, pet battles, the menu, disabled-trigger outfits; the layout arithmetic (per line, padding, spacing, size, grow direction and its saved corner), the window look and header band with lock and close, the labels, the icon border and the worn highlight |
| `test_bar_look` | The outfit bar's look, split from `test_bar` for the file budget: the label's face through `S.Resolve` (Ignore fonts included) and its color, the border color's skin companion on the player's plate and icon edge, the button's frame-level rungs and worn-mark overlay, and test mode without the library (no strip room, the title says test mode) |
| `test_outfit_icons` | The outfit icon model: one resolver for row, bar and broker (a 1.1.0 fileID as before, a tinted glyph, a seeded spec outfit's spec icon, the trigger, item and default 132724 fall-through), `NS.Outfits.SetIcon`, the wildcard as nil, an Equipment Manager outfit's per-character glyph override and its clearing |
| `test_broker` | The Outfits data source: its name and type, not on the minimap, text and icon following the worn outfit, the menu's categories and visible outfits with their checks and status colors, wear/remove/set-current clicks, right-click, the tooltip, a combat wear as the window's |
| `test_preview` | Test mode: the placeholder outfits, nothing worn and nothing saved, refused and ended in combat, the ends; the window's samples, alone in the screen center or docked, its strip, X and Escape dismissing it for the session, every row action refused but the gear's browse-only menu, New outfit off and the selection cleared |
| `test_preview_place` | Where test mode puts its surfaces (smoke round 3 E3): the alone window centered, dragged for the session only (the drop held through Refresh, the follow and a sheet open and close, never saved, the client's user-placed flag cleared), never moved docked or in lockdown, the move stopped when combat comes; the bar just left of the window, a drag of it saved as usual, Reset position honored in the session, the saved place back when test mode ends |
| `test_window_settings` | The Outfit Window settings page (smoke round 3 E11): its rows, tabs, tooltips and defaults, and the reach of each: the sheet button hidden and shown in place, the slot check boxes, the outward drawer, the dock's gap (never on the alone test window), the item sections and the outfit row's two marks, each following a write and a profile switch |
| `test_flyout_tint` | The equipment flyout's border tint (smoke round 3 E1, deviation DEV-SKIN-FLYOUT-TINT): while the window is on screen a sheet slot's flyout rim (every background piece and the paging strip, never the slot's glow) is desaturated in the skin's `win.border`; each texture's own color and desaturation are given back exactly when the window closes, another host opens the flyout and at the stand-down; once let go the rim is not written again; a new page's pieces are tinted and restored too; a skin change re-tints; nothing is written in combat lockdown |
| `test_quickslots` | The flyout quick slots: the sort against the legacy capture, the upgrade fallback, the specials, the guards and the latch; the drawer: every arrow shown while the window shows, the `HideAll` post-hook, the flyout level with its slot in both columns and Blizzard's point back |
| `test_tooltips` | The "Used by outfits" line on bag, inventory and hyperlink tooltips (never another unit's), its colors and cache; the compare tooltips; the outfit tooltip |
| `test_skinsetup` | The skin seam: the owner registration, the `of.*` tokens, the choice and the picker |
| `test_skin` | Only our frames are skinned; the window, bar, dialogs and menus follow a skin switch |
| `test_perf_harness` | The ten buckets in order with the one nest, each reached on the whole addon (`equipExecute` only inside `E.Update`), the six offline scenarios doing what they are named for (the idle docked window's announcing nothing and leaving no update pending among them), the `perf` verb, the latch's `perf` hold |
| `test_glyphs` | The display-glyph guard over the addon's own Lua. The zhCN, zhTW, koKR and ruRU overlays are skipped (no western safe set holds them); their faces are left to the H8 client check |

## Inventory and badge

`docs/test-cases.md` is generated by `lua tests/run.lua --list > docs/test-cases.md` and never
hand-edited; its Total is the authoritative pass count. The README's Tests badge must equal it, and
both move in the same change as the suite (testing-§5). `test_packaging` holds the badge to the
inventory's Total and fails when a live suite has no Totals row, so a stale inventory or badge is
red rather than remembered.

## Retired harness

The fork's own harness (the 14 suites under `tests/` at `7ea3dc3`, 144 cases) was deleted when the
kit replaced it (P3 C5, design §9.4), together with `tests/framework.lua`, `loader.lua`,
`run-all.sh`, `wow_mock.lua` and `client_events.lua` (re-homed into `tests/mock_world.lua` and
`tests/mock_gear.lua`). Its behavior was captured first into `tests/fixtures/legacy/` (testing-§13).
Each old case is kept by a new home or dropped for a reason:

| Old suite (cases) | New home | Dropped, and why |
|---|---|---|
| harness (8) | kit `assertSuiteInventory`; `test_packaging`; `test_toc` | none |
| syntax (3) | kit loader; luacheck `std = lua51`; `test_skeleton`'s Lua 5.2 scan | the BOM list (MC2DebugLib deleted, H15) |
| eol (3) | kit `test_eol` (CRLF) | the per-file LF/CRLF pins (the H27 policy change) |
| toc (6) | `test_loadorder`, `test_toc` | "Deprecated loads after Outfitter" became "no Deprecated.lua" |
| xml (6) | `test_keybinds`, `test_slot_enables` (2) | the XML handler and template cases: no XML ships but `Bindings.xml` |
| load (17) | `test_skeleton`, `test_api` (the leak check, inverted), `test_toc`, `test_launcher`, `test_locale`, `test_credits` | "the broker identity is still Outfitter" (superseded by design §1.6 #6) and "the display name is Outfitter Reborn" (the Title is now "Ka0s Outfitter Reborn") |
| compat (5) | `test_secrets` | none |
| zones (16) | `test_zones`, all kept | none |
| scripts (15) | `test_triggers`, `test_triggers_parity`, `test_trigger_binder`, `test_no_loadstring` | "compiles in the wrapper" became no-loadstring; "a hand-written script is unchanged" (H1); "the retired presets are inert" became "the retired presets are absent" |
| locale (6) | `test_locale` | none |
| deprecated (11) | `test_removed_apis` (1 kept by intent) | 10 cases on the deleted layer (H16, INV §18) |
| secrets (20) | `test_secrets`, `test_secrets_states`, `test_equip_bracket` | none |
| outfits (17) | `test_outfits`, `test_slots`, `test_stack` | none |
| commands (11) | `test_slash`, `test_diagnostics` | the manual's image references are gone with the manual, retired into the README in P10; `test_slash`'s parity case now checks `/or help` and that the README's Usage points at it |

## In game

What no headless run can reach (rendering, layering, taint, the real client APIs) is the in-game
suite: [smoke-tests.md](smoke-tests.md).
