# Module map

Every authored file in the addon, its one job, and the load order (documentation-§3, Tier 1). The
TOC, `OutfitterReborn.toc`, is the load order and the authority on it; this page says why it is that
order. Files the design plans but the port has not written yet are listed under
[Arriving with the port](#arriving-with-the-port), so this page never claims a file that is not on
disk.

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
| `core/WidgetsSetup.lua` | `NS.MakeDropdown`, `NS.OpenMenu`, `NS.CloseMenu`, `NS.MakeTestStrip`, `NS.TEST_STRIP_HEIGHT`, `NS.MakeDragHandle`, `NS.ShowCopy` (LibKa0s-Widgets) |
| `core/SecureQueue.lua` | `NS.SecureQueue`: a protected write runs now or waits out combat lockdown, latest per key |
| `core/LifecycleSetup.lua` | `NS.lifecycle`, the one stand-down latch with its `disabled` and `perf` holds, `NS.ApplyEnabled`, `NS.IsStoodDown`, `NS.StoodDownRefusal` (LibKa0s-Lifecycle) |
| `core/PerfSetup.lua` | `NS.Perf`, the performance harness over `OutfitterRebornPerfDB` with its ten fixed buckets (LibKa0s-Perf; [performance.md](performance.md)) |
| `core/DebugLogSetup.lua` | `NS.DebugLog`, the console with its init summary and diagnostics hook, `NS.Debug` and the `DebugOnce`/`DebugChanged`/`DebugAtEnable` gates ([debug.md](debug.md)) |
| `core/LauncherSetup.lua` | `NS.Launcher` (one LDB object, minimap button and broker row), the binding buttons, `NS.BINDINGS` and the `BINDING_*` globals (LibKa0s-Launcher) |
| `core/OutfitterReborn.lua` | `NewAddon`, the `NS.Print` reclaim, `OnInitialize` (DB, migrations, the profile's skin, the enabled hold, launcher, options, slash) |
| `core/Database.lua` | AceDB, the profile callbacks, the migration runner, both `resolveRoot` functions ([schema.md](schema.md)) |

## defaults/, modules/, settings/, locales/

| File | Job |
|---|---|
| `defaults/Profile.lua` | `NS.defaults`, the only place a default is hardcoded |
| `modules/Diagnostics.lua` | This addon's sections of `/of diagnostics` (debug-logging-§14) |
| `settings/Schema.lua` | The settings rows, the one write seam, the page filter and the forward to `NS.OutfitSchema` (LibKa0s-Schema) |
| `settings/Slash.lua` | `NS.COMMANDS`, the LibKa0s-Slash descriptor and the macro-conditional wrapper ([slash-dispatch.md](slash-dispatch.md)) |
| `settings/OptionsSetup.lua` | The LibKa0s-Options descriptor (`NS.Helpers`), the tabbed-page helper and the global reset popup |
| `settings/General.lua` | The General page (Master controls, Skin, Keybindings) and the landing page spec, `NS.LANDING` |
| `settings/Profiles.lua` | The Profiles sub-page, registered last, under a line saying outfits are per character |
| `locales/enUS.lua` | `NS.L`, the canonical locale with the key-is-the-string fallback |
| `locales/enUS_Triggers.lua` | enUS topic file: the native triggers' strings, filling `NS.L` |
| `locales/enUS_Window.lua` | enUS topic file: the window, menus, dialogs, bar, tooltips and test mode, filling `NS.L` |
| `locales/deDE.lua`, `frFR.lua`, `zhCN.lua`, `zhTW.lua`, `koKR.lua`, `ruRU.lua` | The six overlays, each gated on its own `GetLocale()` first; the gate line only until the re-key (P4.28) |

## Arriving with the port

The design's §1.1 tree is the plan; the P4 sub-ledger (design §12) names the task that writes each
file. In outline:

| Folder | Files |
|---|---|
| `defaults/` | `Items.lua` (`NS.ItemData`), `Zones.lua` (the single zone source), `TriggerData.lua`, `Triggers.lua` (`NS.TriggerCatalog`), `PreviewOutfits.lua` |
| `modules/` engine | `PlayerState`, `ItemInfo`, `Inventory`, `Inventory_Lists`, `Outfits`, `Outfits_Seed`, `Outfits_Schema`, `OutfitStack`, `OutfitStack_Watch`, `Equip`, `Equip_Changes`, `Equip_Moves`, `EquipmentManager`, `Bank`, `ItemStats`, `ItemStats_Sources`, `Optimize`, `Optimize_Genetic`, `Companion` |
| `modules/` triggers | `Triggers_Params`, `Triggers_Families`, `Triggers_CondGeneral`, `Triggers_CondTrade`, `Triggers_CondQuest`, `Triggers_Effects`, `Triggers`, `Triggers_Binder`, `States`, `States_Zone` |
| `modules/` UI | `Commands`, `Popups`, `Tooltips`, `Tooltips_Compare`, `OutfitTooltip`, `Dock`, `Window`, `Window_ListModel`, `Window_Rows`, `SlotEnables`, `OutfitMenu`, `UIDialogs`, `Dialog_Outfit`, `Dialog_Trigger`, `Dialog_TriggerFields`, `Dialog_Rebuild`, `Dialog_Progress`, `IconChooser`, `Bar`, `Bar_Buttons`, `QuickSlots`, `QuickSlots_Sort`, `Preview`, `Api` |
| `settings/` | `OutfitBar.lua` (page `bar`) |
| `tools/` | `gen-zones.lua`, `rekey-locales.lua` |

## Not shipped

`.pkgmeta` keeps these out of the zip a player downloads; nothing in the TOC loads them.

| Path | Job |
|---|---|
| `tests/run.lua` | The runner: the load list, the lifecycle kick and the suite list, on the vendored kit |
| `tests/wow_mock.lua` | The WoW API mock, extending the kit's base mock , and `T.fake` (design §12, the fake rule: a stand-in restored when the case ends) |
| `tests/mock_gear.lua` | The domain mock's gear half: worn items, bags, the bank, the cursor and item info, moving items for real |
| `tests/mock_gear_sets.lua` | `C_EquipmentSet` over the gear half: sets that follow their items and wear for real |
| `tests/mock_world.lua` | The domain mock's world half: instance, restriction, auras, class and spec, protected frames, hooks, the character sheet and tooltips |
| `tests/fixtures/items.lua` | The item fixtures the gear half answers from, in the 12.x link shape |
| `tests/fixtures/inventories.lua` | The named gear scenarios `M.__gear:load` places |
| `tests/test_*.lua` | The local suites ([testing.md](testing.md)) |
| `tests/skin_surfaces.lua` | The skin-switch suite's painted surfaces (skinning-§1) |
| `tests/prose_waivers.lua` | What the US-English gate must not correct here, per file and per word |
| `tests/perf.lua` | The offline perf scenarios, outside the gate |
| `tests/fixtures/legacy/` | Legacy behavior captured from the fork at `7ea3dc3` by `tools/legacy_capture.lua`; generated, never hand-edited |
| `tests/_kit/` | The LibKa0s test kit, vendored byte-identical; never edited |
| `tools/legacy_capture.lua` | Writes `tests/fixtures/legacy/` from a worktree of the fork |
| `media/logos/*.png`, `*.jpg`, `media/screenshots/` | Source art and screenshots |
| `docs/` | This doc set |
