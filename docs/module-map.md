# Module map

Every authored file in the addon, its one job, and the load order (documentation-§3, Tier 1). The
TOC, `OutfitterReborn.toc`, is the load order and the authority on it; this page says why it is that
order. Every file the TOC loads has a row below, and so does every authored file that does not ship
([Not shipped](#not-shipped)).

## Load order

`libs → locales → core → defaults → modules → settings` (layout-§1). Each folder may read the
folders before it at file scope and anything at call time. A file that reads another at **file
scope** has a `# LOAD-BEARING` comment above its TOC line, and `tests/test_loadorder.lua` pins every
one of them:

| TOC line | Why it is where it is |
|---|---|
| `locales\enUS.lua` | Creates `NS.L`, which `core\LauncherSetup.lua`, `defaults\*.lua` and every `settings\` file read at file scope |
| `locales\enUS_Triggers.lua`, `locales\enUS_Window.lua` | Read `NS.L` (created by `enUS.lua`) at file scope |
| `core\Namespace.lua` | `NS.PREFIX`, `NS.name`, `NS.BRAND` and the version fallback every file below reads |
| `core\MediaSetup.lua` | `NS.MediaFont`, which `core\Constants.lua` resolves `FONT_MONO` from at file scope |
| `core\EnvSetup.lua` | `NS.Version()`, called by `core\PerfSetup.lua` at file scope |
| `core\CoreSetup.lua` | `NS.Util.print` (reclaimed by `core\OutfitterReborn.lua` at file scope) and `NS.LIBKA0S_MISSING` (read by every stub below) |
| `core\SkinSetup.lua` | `RegisterOwner` at file scope, before EllesmereUI dispatches; `NS.SKIN_OPTIONS` is read by `settings\General.lua` at file scope |
| `core\Compat.lua` | `NS.Compat`, whose secret detectors `core\Secrets.lua` binds at file scope. Compat reaches `NS.Secrets` at call time only, so it may precede Secrets |
| `core\Secrets.lua` | `NS.Secrets`, captured at file scope by the modules that read possibly secret values |
| `core\LifecycleSetup.lua` | `NS.lifecycle`, which LibKa0s-Perf `:New` raises without |
| `core\PerfSetup.lua` | `NS.Perf`, captured at file scope by the modules |
| `core\DebugLogSetup.lua` | Needs `FONT_MONO`, `NS.State` and the printer, and precedes any `NS.Debug` call |
| `core\LauncherSetup.lua` | Reads `NS.Constants.LOGO_128` and `NS.L` at file scope; creates the binding buttons and the `BINDING_*` globals |
| `core\OutfitterReborn.lua` | `NewAddon(NS, addonName, …)` and the `NS.Print` reclaim at file scope, so it follows `core\CoreSetup.lua` |
| `settings\Schema.lua` | `NS.RegisterSchemaRows`, which `settings\General.lua` calls at file scope |
| `settings\OptionsSetup.lua` | `NS.Helpers` and `NS.RegisterTabbedPage`, captured at file scope by every page below |
| `settings\General.lua` … `settings\Profiles.lua` | General registers first and Profiles last; page order is registration order |

The libraries load first, each in its own folder under `libs/`, and are vendored read-only
(library-stack-§7). `Bindings.xml` is read by the client by name and is not in the TOC.

## Root

| File | Job |
|---|---|
| `OutfitterReborn.toc` | Metadata and the load order, with the `LOAD-BEARING` notes (toc-file-§1, §5) |
| `Bindings.xml` | The key bindings, as `CLICK` bindings on permanent hidden buttons (launcher-§6); not in the TOC |
| `README.md` | The player-facing page (documentation-§1) |
| `CLAUDE.md` | The agent stub: the standard, the doc pointers, the gate, the LibKa0s provenance and icons lines (documentation-§2) |
| `DEPENDENCIES.md` | The runtime and development toolchain (documentation-§7) |
| `LICENSE` | MIT, with John Stephen's original copyright kept |
| `.gitattributes`, `.gitignore`, `.luacheckrc`, `.pkgmeta` | Line endings (CRLF, `*.sh` LF), ignores, lint policy, packaging |

## core/

| File | Job |
|---|---|
| `core/Namespace.lua` | `NS.PREFIX` (`[OR]`), `NS.name`, `NS.BRAND`, `NS.SLASH`/`NS.SLASH_LONG`, the version fallback |
| `core/MediaSetup.lua` | `NS.Icon`, `NS.MediaFont` and the LibSharedMedia registration (LibKa0s-Media) |
| `core/Constants.lua` | `FONT_MONO`, `LOGO`/`LOGO_128`, `LAYERS`, `OUTFIT_MESSAGE_COLOR` |
| `core/State.lua` | `NS.State`: session-only flags (`debug`, `testMode`, `legacyLoaded`) |
| `core/EnvSetup.lua` | `NS.Meta`, `NS.Version` (LibKa0s-Env) |
| `core/CoreSetup.lua` | `NS.Print`, `NS.SafeToString`, the `SafeRegister*` family, the window chrome (LibKa0s-Core) |
| `core/SkinSetup.lua` | `NS.Skin`, the owner registration and its `of.*` tokens, the skin choice and picker seams (LibKa0s-Skin) |
| `core/Compat.lua` | `NS.Compat`: every version-variant client call and every LibKa0s-Compat member the addon consumes ([compat-layer.md](compat-layer.md)) |
| `core/Secrets.lua` | `NS.Secrets`, the only file that inspects a possibly secret value, and the `NS.IsSecret`/`NS.Unsecret`/`NS.SafeNumber` aliases |
| `core/Bus.lua` | `NS.MSG`, `NS.NewBusTarget`, `NS.SendBus`, `NS.BusStandDown`/`BusStandUp` (LibKa0s-Bus; [message-bus.md](message-bus.md)) |
| `core/PoolSetup.lua` | `NS.Pool`, the array and keyed widget pools (LibKa0s-Pool) |
| `core/ItemSetup.lua` | `NS.Item`: `ItemIDFromLink`, `BonusIDsFromLink` on plain links only (LibKa0s-Item) |
| `core/WidgetsSetup.lua` | `NS.MakeDropdown`, `NS.OpenMenu`, `NS.CloseMenu`, `NS.IconText`, `NS.MakeTestStrip`, `NS.TEST_STRIP_HEIGHT`, `NS.MakeDragHandle` (LibKa0s-Widgets) |
| `core/SecureQueue.lua` | `NS.SecureQueue`: a protected write runs now or waits out combat lockdown, latest per key |
| `core/LifecycleSetup.lua` | `NS.lifecycle`, the one stand-down latch with its `disabled` and `perf` holds, `NS.ApplyEnabled`, `NS.IsStoodDown`, `NS.StoodDownRefusal` (LibKa0s-Lifecycle) |
| `core/PerfSetup.lua` | `NS.Perf`, the performance harness over `OutfitterRebornPerfDB` with its ten fixed buckets (LibKa0s-Perf; [performance.md](performance.md)) |
| `core/DebugLogSetup.lua` | `NS.DebugLog`, the console with its init summary and diagnostics hook, `NS.Debug` and the `DebugOnce`/`DebugChanged`/`DebugAtEnable` gates ([debug.md](debug.md)) |
| `core/LauncherSetup.lua` | `NS.Launcher` (one LDB object, minimap button and broker row), the binding buttons, `NS.BINDINGS` and the `BINDING_*` globals (LibKa0s-Launcher) |
| `core/OutfitterReborn.lua` | `NewAddon`, the `NS.Print` reclaim, `OnInitialize` (DB, migrations, the profile's skin, the enabled hold, launcher, options, slash) |
| `core/Database.lua` | AceDB, the profile callbacks, the migration runner, both `resolveRoot` functions ([schema.md](schema.md)) |

## defaults/

| File | Job |
|---|---|
| `defaults/Profile.lua` | `NS.defaults`, the AceDB defaults tree: the only place a default is hardcoded |
| `defaults/Items.lua` | `NS.ItemData`: slots, inventory types, alternates, aliases, ignored items, phantoms |
| `defaults/Zones.lua` | `NS.Zones.rows` and `BRAWL_MAP_IDS`: the single zone source, one row per battleground and arena |
| `defaults/TriggerData.lua` | The aura, form, NPC, difficulty, map, skill-line and pet ID tables the triggers and their state producers read; pure data, every key an ID |
| `defaults/Triggers.lua` | `NS.TriggerCatalog`: one data row per non-zone trigger, and `CATEGORY_ORDER` |
| `defaults/PreviewOutfits.lua` | The test-mode placeholder outfits, read by `modules/Preview.lua` and never by the store |

## modules/

In TOC order: the engine, then the triggers and their state producers, then the UI, the API and
the diagnostics sections.

**Engine**

| File | Job |
|---|---|
| `modules/PlayerState.lua` | `NS.PlayerState`: the combat, dead, cast and spec flags |
| `modules/ItemInfo.lua` | `NS.ItemInfo`: link parse, item identity and comparison |
| `modules/Inventory.lua` | `NS.Inventory`: the bag and equipment scan, its cache and the bank-open rules |
| `modules/Inventory_Lists.lua` | The missing, unused, BoE, warbound, in-use and cooldown lists and their sections (extends `NS.Inventory`) |
| `modules/IconBrowserSetup.lua` | `NS.Glyph`: the glyph helpers (`IsGlyph`, `ValidColor`, `Tint`) from LibKa0s-IconBrowser, with a library-absent stub; `NS.IconBrowser` (`Open(id)`, `Close`, `IsOpen`, `Browser`): Change icon...'s library browser, tabs Recommended and Equipped and bags ahead of Game icons and Glyphs, no Markers |
| `modules/Outfits.lua` | `NS.Outfits`: the outfit store and its one writer API; `NS.OutfitIcon`, the one outfit icon resolver, and `NS.Outfits.SetIcon` |
| `modules/Outfits_Seed.lua` | The LoadPass: store repair, the built-in outfits' seed and the 1 s timer that runs the first one (extends `NS.Outfits`) |
| `modules/Outfits_Schema.lua` | `NS.OutfitSchema`: the per-outfit instance rows, `outfit.*` and `trigger.<TID>.*` |
| `modules/OutfitStack.lua` | `NS.Stack`: wear, remove, toggle, layers, recents, selection and title |
| `modules/OutfitStack_Watch.lua` | The inventory watch: the temporary outfit, window-open recording and `SWAP_COMPLETE` (extends `NS.Stack`) |
| `modules/Equip.lua` | `NS.Equip`: the bracket that cannot strand, its gates, execution and the muted SFX |
| `modules/Equip_Changes.lua` | `NS.Changes`: the pure change-list builder, unique-equip order and the optimize rules |
| `modules/Equip_Moves.lua` | `NS.Moves`: pickup, a move to an empty bag slot, the empty-slot lists and `/or unequip` |
| `modules/EquipmentManager.lua` | `NS.EM`: the Blizzard Equipment Manager mirror |
| `modules/Bank.lua` | `NS.Bank`: deposit, withdraw and the missing-items report |
| `modules/ItemStats.lua` | `NS.Stats`: the stats the optimizer scores items by |
| `modules/ItemStats_Sources.lua` | `NS.StatSources`: Pawn and WeightsWatcher as optional stat sources |
| `modules/Optimize.lua` | `NS.Optimize`: the smart-outfit driver, the simple search, Trial and Rebuild |
| `modules/Optimize_Genetic.lua` | `NS.OptimizeGA`: the genetic search behind a complex smart outfit |
| `modules/Companion.lua` | `NS.Companion`: the battle-pet reconciler |

**Triggers**

| File | Job |
|---|---|
| `modules/Triggers_Params.lua` | `NS.TriggerParams`: typed trigger parameters, validate, normalize, display and capture |
| `modules/Triggers_Families.lua` | `NS.TriggerFamilies`: the condition factories, guards and `TooltipHasLine` |
| `modules/Triggers_CondGeneral.lua` | The bespoke GENERAL (and PvP-flag) trigger conditions |
| `modules/Triggers_CondTrade.lua` | The bespoke TRADE trigger conditions |
| `modules/Triggers_CondQuest.lua` | The bespoke QUEST and ENTERTAIN trigger conditions |
| `modules/Triggers_Effects.lua` | The triggers' save-and-restore side effects: auto-loot, tracking, click-to-move, bar page, pets |
| `modules/Triggers.lua` | `NS.Triggers`: the trigger registry, the `PSEUDO` table and the schema rows |
| `modules/Triggers_Binder.lua` | `NS.TriggerBinder`: bind, unbind, dispatch and apply |
| `modules/States.lua` | `NS.States`: auras, forms, the 0.5 s mounted and swimming poll, Dining, Spirit and the tooltip hooks |
| `modules/States_Zone.lua` | The zone producer, its derived tables and `/or zone`'s zone half |

**UI, API and diagnostics**

| File | Job |
|---|---|
| `modules/Commands.lua` | `NS.Commands`: the slash outfit verbs' handlers (the verb table is `settings/Slash.lua`'s) |
| `modules/Popups.lua` | `NS.Popups`: this addon's `StaticPopupDialogs` |
| `modules/Tooltips.lua` | `NS.Tooltips`: the "Used by outfits" line on item tooltips |
| `modules/Tooltips_Compare.lua` | `NS.Compare`: up to five comparison tooltips with the items your outfits use in the hovered slot |
| `modules/OutfitTooltip.lua` | `NS.OutfitTooltip`: an outfit's tooltip, for the window's rows and the bar's buttons |
| `modules/Sheet.lua` | `NS.Sheet`: which character sheet is up (stock, EllesmereUI, ChonkyCharacterSheet) and where on it the sheet button and the window go; reads only, anchors nothing |
| `modules/Dock.lua` | `NS.Dock`: the sheet holder and button, the window's show model, its follow and its layer sync |
| `modules/Window.lua` | `NS.Window`: the outfit window's chrome, list body, scroll bar, footer and render |
| `modules/Window_ListModel.lua` | `NS.WindowListModel`: what the outfit list shows, in order |
| `modules/Window_Rows.lua` | `NS.WindowRows`: the list's 14 rows and the secure child each one owns |
| `modules/SlotEnables.lua` | `NS.SlotEnables`: the 18 slot checkboxes over the character sheet while an outfit is selected |
| `modules/OutfitMenu.lua` | `NS.OutfitMenu`: the outfit context menu |
| `modules/UIDialogs.lua` | `NS.Dialogs`: the dialogs' shared chrome and controls |
| `modules/Dialog_Outfit.lua` | `NS.OutfitDialog`: the new-outfit and rename dialog |
| `modules/Dialog_Trigger.lua` | `NS.TriggerDialog`: the trigger chooser and its settings |
| `modules/Dialog_TriggerFields.lua` | `NS.TriggerFields`: the trigger parameter editors, nine field types |
| `modules/Dialog_Rebuild.lua` | `NS.RebuildDialog`: the multi-stat rebuild dialog |
| `modules/Dialog_Progress.lua` | `NS.ProgressDialog`: the optimizer's progress window |
| `modules/Bar.lua` | `NS.Bar`: the outfit bar |
| `modules/Bar_Buttons.lua` | The outfit bar's pooled buttons |
| `modules/Broker.lua` | `NS.Broker`: the `OutfitterRebornOutfits` LibDataBroker data source, the old addon's outfit switcher (a second object beside the launcher; [ARCHITECTURE.md](ARCHITECTURE.md#documented-deviations)) |
| `modules/QuickSlots.lua` | `NS.QuickSlots`: the equipment flyout hooks, and the left column's drawer turned outward while the window shows |
| `modules/QuickSlots_Sort.lua` | The flyout's upgrade-track sort (extends `NS.QuickSlots`) |
| `modules/Preview.lua` | `NS.Preview`: test mode |
| `modules/Api.lua` | The public API, `NS.API.v1`, published as `OutfitterReborn.API.v1` ([ARCHITECTURE.md](ARCHITECTURE.md#public-api)) |
| `modules/Diagnostics.lua` | This addon's sections of `/or diagnostics` (debug-logging-§14) |

## settings/

| File | Job |
|---|---|
| `settings/Schema.lua` | The settings rows, the one write seam, the page filter and the forward to `NS.OutfitSchema` (LibKa0s-Schema) |
| `settings/Slash.lua` | `NS.COMMANDS`, the LibKa0s-Slash descriptor and the macro-conditional wrapper ([slash-dispatch.md](slash-dispatch.md)) |
| `settings/OptionsSetup.lua` | The LibKa0s-Options descriptor (`NS.Helpers`), the tabbed-page helper and the global reset popup |
| `settings/General.lua` | The General page (Master controls, Behavior, Tooltips, Skin, Keybindings) and the landing page spec, `NS.LANDING` |
| `settings/OutfitBar.lua` | The Outfit Bar page, `bar`, registered between General and Profiles |
| `settings/Profiles.lua` | The Profiles sub-page, registered last, under a line saying outfits are per character |

## locales/

| File | Job |
|---|---|
| `locales/enUS.lua` | `NS.L`, the canonical locale with the key-is-the-string fallback |
| `locales/enUS_Triggers.lua` | enUS topic file: the native triggers' strings, filling `NS.L` |
| `locales/enUS_Window.lua` | enUS topic file: the window, menus, dialogs, bar, tooltips and test mode, filling `NS.L` |
| `locales/deDE.lua`, `frFR.lua`, `zhCN.lua`, `zhTW.lua`, `koKR.lua`, `ruRU.lua` | The six overlays, each gated on its own `GetLocale()` first and generated by `tools/rekey-locales.lua` from the fork's translations |

## Not shipped

`.pkgmeta` keeps these out of the zip a player downloads; nothing in the TOC loads them.

| Path | Job |
|---|---|
| `tests/run.lua` | The runner: the load list, the lifecycle kick and the suite list, on the vendored kit |
| `tests/wow_mock.lua` | The WoW API mock, extending the kit's base mock, and `T.fake` (design §12, the fake rule: a stand-in restored when the case ends) |
| `tests/mock_gear.lua` | The domain mock's gear half: worn items, bags, the bank, the cursor and item info, moving items for real |
| `tests/mock_gear_sets.lua` | `C_EquipmentSet` over the gear half: sets that follow their items and wear for real |
| `tests/mock_world.lua` | The domain mock's world half: instance, restriction, auras, class and spec, protected frames, hooks, the character sheet and tooltips |
| `tests/fixtures/items.lua` | The item fixtures the gear half answers from, in the 12.x link shape |
| `tests/fixtures/inventories.lua` | The named gear scenarios `M.__gear:load` places |
| `tests/unit_load.lua` | A unit instance: the whole load and login with the resume walk emptied, for a suite that drives one module's `Resume` itself |
| `tests/spy.lua` | A recorder over a REAL module's members: the call is recorded, then made (it replaced the fakes once their modules landed, P4.27) |
| `tests/dock_scene.lua` | The shared scene of the four window suites (`test_dock`, `test_list_model`, `test_rows_secure`, `test_slot_enables`) |
| `tests/dialog_scene.lua` | The shared scene of the three dialog suites (`test_outfit_menu`, `test_dialogs`, `test_trigger_dialog`) |
| `tests/test_*.lua` | The local suites ([testing.md](testing.md)) |
| `tests/skin_surfaces.lua` | The skin-switch suite's painted surfaces (skinning-§1) |
| `tests/prose_waivers.lua` | What the US-English gate must not correct here, per file and per word |
| `tests/perf.lua` | The offline perf scenarios, outside the gate |
| `tests/perf_scenes.lua` | The drivers of the ten bracketed paths, shared by `tests/perf.lua` and `test_perf_harness` |
| `tests/fixtures/legacy/` | Legacy behavior captured from the fork at `7ea3dc3` by `tools/legacy_capture.lua`; generated, never hand-edited |
| `tests/_kit/` | The LibKa0s test kit, vendored byte-identical; never edited |
| `tools/legacy_capture.lua` | Writes `tests/fixtures/legacy/` from a worktree of the fork |
| `tools/gen-zones.lua` | Diffs a wago.tools Map.db2 export against `defaults/Zones.lua` (added, removed, wrong kind); edits nothing |
| `tools/rekey-locales.lua` | Writes the six locale overlays from the legacy translations (`--check` compares without writing) |
| `media/logos/*.png`, `media/logos/*.jpg`, `media/screenshots/` | Source art and screenshots |
| `docs/` | This doc set |
