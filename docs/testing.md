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
  `CLAUDE.md` (test kit revision 50). Never edit it; `test_vendor_sync` fails on any drift.
- **`tests/run.lua`** loads the vendored library in `LibKa0s.xml` order (asserting the sixteen leased
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
  recorded stand-in a suite installs for a module that has not landed yet. `tests/run.lua` wraps
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
- Every negative assertion was proven able to fail by mutating the code under test (testing-§12).

## The suites

Every suite is declared in `SUITES` in `tests/run.lua`; a file that is not listed loads nothing, and
the kit's inventory fails a `tests/test_*.lua` with no entry. The P4 suites (the engine, the triggers,
the UI) join as their files land.

| Suite | What it covers |
|---|---|
| `test_skeleton` | Registration under the folder name, the tagged printer, the DB defaults, the declared icons, the file headers, the bus wire names, the login resume walk, the legacy guard |
| `test_toc` | The TOC header: field order, Title, version, IconTexture, SavedVariables, the CurseForge project, no retired fields |
| `test_loadorder` | The runner's load list is the TOC's; every path exists; the folder order; the `LOAD-BEARING` lines; no legacy file back |
| `test_database` | The store: the migration stamp, a raising step, the profile and char walks, no `gOutfitter_*` reader, both `resolveRoot` functions |
| `test_packaging` | What reaches players: the package folder, every maintainer file ignored, nothing ignored loaded, every media path resolves, the icon declaration is exactly what is drawn |
| `test_vendor_sync` | `libs/LibKa0s/` and `tests/_kit/` are exactly the tag root `CLAUDE.md` names, icons pruned to its declaration |
| `test_secrets` | The secret-value seam: the conversions, the bounded walk, the guards on both arms, the Compat accessors, the seam scan, and the engine on the whole login (secret links as empty slots, a secret level, the tooltip/compare/quick-slot/iteminfo guards, the balanced Equip count) |
| `test_bus` | The full catalog, its wire names, exactly one sender per key over every call site |
| `test_skinsetup` | The skin seam: the owner registration, the `of.*` tokens, the choice and the picker |
| `test_surface_parity` | Every degrade stub carries the surface of what it stands in for; every leased major has its row; the degraded login resumes the whole graph and stands it down and up |
| `test_perf_harness` | The ten buckets in order with the one nest, each reached on the whole addon (`equipExecute` only inside `E.Update`), the five offline scenarios doing what they are named for, the `perf` verb, the latch's `perf` hold |
| `test_schema` | The settings rows, the write seam, its forward to the outfit instance, the reset's reach |
| `test_settings` | Page registration and order, the General tabs, Master controls, the reset wording, the landing page |
| `test_slash` | The reserved verbs, bare `/of`, help, the schema CLI, both chat commands, the macro-conditional wrapper |
| `test_launcher` | The one LDB object, its static icon and label, the right-click menu, the tooltip line, the Minimap row |
| `test_keybinds` | `Bindings.xml`, `NS.BINDINGS`, the hidden non-secure buttons and their press |
| `test_disabled` | The disabled state is total: the kit's ten conformance steps on the real addon, and the Outfitter cases (an active trigger, the Equip bracket, the hook bodies, the Dock driver, the LoadPass timer, the rebuild) |
| `test_locale` | The locale gates: the TOC-derived enUS set, cross-file duplicates, the overlays' gates, legacy coverage read from the overlays' end notes, format-directive safety (a translation's directives, in order, are a prefix of its English's). The overlays are generated by `lua tools/rekey-locales.lua` (`--check` writes nothing and exits 1 if an overlay differs from its output) |
| `test_glyphs` | The display-glyph guard over the addon's own Lua. The zhCN, zhTW, koKR and ruRU overlays are skipped (no western safe set holds them); their faces are left to the H8 client check |
| `test_credits` | The landing credits, the README Credits block, the LICENSE copyright lines |
| `test_skin` | Only our frames are skinned; the window, bar, dialogs and menus follow a skin switch |
| kit `test_skin_values`, `test_skin_switch` | The typed-color gate and the skin switch over `tests/skin_surfaces.lua` |
| kit `test_eol` | Every tracked file's line endings match `.gitattributes` |
| kit `test_layout_cap` | Every file over the 1500-line cap is in the census in `ARCHITECTURE.md` |
| kit `test_diagnostics_contract` | `/of diagnostics` meets debug-logging-§14 |
| kit `test_lizard_sighted` | The complexity suite's sighted shadow |
| kit `test_prose` | No tracked authored file carries a British spelling (localization-§5); waivers are per file and per word in `tests/prose_waivers.lua` |

## Inventory and badge

`docs/test-cases.md` is generated by `lua tests/run.lua --list > docs/test-cases.md` and never
hand-edited; its Total is the authoritative pass count. The README's Tests badge must equal it, and
both move in the same change as the suite (testing-§5).

## In game

What no headless run can reach (rendering, layering, taint, the real client APIs) is the in-game
suite: [smoke-tests.md](smoke-tests.md).
