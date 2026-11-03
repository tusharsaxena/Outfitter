# Ka0s WoW Addon Standard: compliance checklist for the Outfitter conversion

- **Standard:** v2.97.0 (2026-11-01), `WowAddonStandards/standards/STANDARDS.md` plus every section file under `standards/standards/`.
- **LibKa0s target:** v1.85.0, the tag DpsRace bundles (DpsRace `CLAUDE.md`, provenance line).
- **Reference addon:** DpsRace (`/mnt/d/Profile/Users/Tushar/Documents/GIT/DpsRace`).
- **Baseline:** Outfitter@9630757 on `feat/2026-11-03-ka0s-conversion`.
- **Owner decisions already taken:** Title `Ka0s Outfitter Reborn`, folder stays `Outfitter`, version 1.1.0, fresh AceDB store with no migration, window stays docked to the character sheet but takes the LibKa0s skin, full rewrite allowed, functionality must survive.

## How to read this

- Each row is a rule: `[LEVEL] ref`, then what it means for Outfitter.
- Numbered sections are cited `filename-§N`. The eleven unnumbered files are cited by bare name: anti-patterns (`anti-patterns #N`), audit-review-history, compat, lint, naming-cheatsheet, open-evolutions, packaging, preview-mode, public-api, standalone-windows, versioning-git. Never write `compat-§N`, `public-api-§N`, `standalone-windows-§N`, `preview-mode-§N` or `anti-patterns-§N`; those are out of range, and an out-of-range citation is a MUST fix.
- `:NN` after a ref is a line in that section file at v2.97.0. It is for the implementer, not for authored docs, which cite the section only.
- Severity (STANDARDS.md:32-35): a MUST violation is a bug. A SHOULD deviation needs a code comment saying why. A declined rule goes in `docs/ARCHITECTURE.md` `## Documented deviations`.
- Rows tagged *(library-owned)* need correct wiring only. The host must not re-implement them or fight them.
- The last section, **Hard calls for Outfitter**, collects every rule that needs a design decision or a deviation row, with a recommendation for each.

## Outfitter baseline facts

- **Line counts (authored).** `Outfitter.lua` 8806, `OutfitterScripting.lua` 2187, `OutfitterBar.lua` 1681, `tests/client_events.lua` 1545 are over the cap. `OutfitterInventory.lua` 1382, `OutfitterEquipment.lua` 1315, `OutfitterOptimize.lua` 1266, `OutfitterOutfits.lua` 1071 sit in the 1000-1500 band. `Deprecated.lua` is 941. `Outfitter.xml` is 1669 and `OutfitterBar.xml` 171. About 23.5k lines of Lua in total.
- **Layout.** Everything sits flat at the root. Libraries live in `Libraries/`. `Media/` (about 8 MB of source art and screenshots) and `Textures/` (15 `.blp`) are capitalized. There is no `.gitattributes`, and line endings are mixed (21 CRLF files, 7 LF).
- **TOC.** No X-Standard or X-License. `Title: Outfitter Reborn`. `Author: mundocani, aDd1kTeD2Ka0s`. `IconTexture: Interface\Icons\INV_Chest_Cloth_21`. It also has `AddonCompartmentFunc: Outfitter_OnAddonCompartmentClick`, `X-ReloadTag: 2`, empty `OptionalDeps:` and `RequiredDeps:` lines, and Curse id 1698220. `Compat.lua` and UTF8 load before LibStub. There are no `#` section headers.
- **SavedVariables.** `SavedVariablesPerCharacter: gOutfitter_Settings` and `SavedVariables: gOutfitter_GlobalSettings` (`.Banned`).
- **Globals.** The `Outfitter` table, `OutfitterAPI`, about 25 `Outfitter_*` API globals, about 30 `Outfitter_c*` XML-text globals (`Outfitter.lua:381-412`), `_G["OutfitterItem"..n]` row lookups, and `gOutfitter_OutfitToDelete`.
- **Slash.** `SLASH_OUTFITTER1="/outfitter"` and `SLASH_UNEQUIP1="/unequip"` (`Outfitter.lua:5296-5302`). `ExecuteCommand` uses a named-field table (`:1985-2045`) with these verbs: wear, unwear, toggle, reset (AskReset and `reset bar`), deposit, depositunique, depositothers, withdraw, withdrawothers, update, updatetitle, summary, rating, iteminfo, itemstats, missing, zone, sound, help, enable/disable (auto-changes), errors, daxdax. It parses macro conditionals with `SecureCmdOptionParse`, which `|h` bypasses.
- **Bindings.** `Bindings.xml` has 14 Lua-bodied bindings: `OUTFITTER_OUTFIT1..10`, the automation toggles, update and open UI. They use `category="Outfitter!"` and `header="OUTFITTER_TITLE"`.
- **User Lua.** `loadstring` runs at `OutfitterScriptDialog.lua:109` and `OutfitterScripting.lua:1879,2067`. Presets resolve live from `Outfitter.PresetScripts`.
- **Events.** About 38 `RegisterEvent` sites go through MC2EventLib, plus about 30 scheduler/C_Timer sites. `UNIT_AURA`, `UNIT_INVENTORY_CHANGED`, `UNIT_HEALTH`, `UNIT_MANA` (retired) and nine `UNIT_SPELLCAST_*` are unfiltered. `CHARACTER_POINTS_CHANGED` is retired too. `PLAYER_REGEN_*` is at `:5383-5384`.
- **Hooks.** `hooksecurefunc` at `Outfitter.lua:5285` (C_PetJournal), `5482-5484` (GameTooltip) and `7801` (GameTooltip_ShowCompareItem). `OutfitterFrame:HookScript("OnUpdate")` at `:1343`, plus OnUpdates in the tooltip (`:8056`) and About (`:68,225`).
- **Secure.** `SecureActionButtonTemplate` in list rows (`Outfitter.xml:388`). Attributes are set at `Outfitter.lua:8427-8492`, gated on `InCombatLockdown`.
- **Layering.** `MatchWindowStrata` and `MatchSlotEnablesStrata` (`Outfitter.lua:1418-1456`). Literal `"DIALOG"` at `Outfitter.lua:5891,6271`, `OutfitterBar.lua:1377`, `OutfitterUITools.lua:14`. Absolute or sibling levels in `OutfitterUITools.lua:15,317,554-588`, `Outfitter.lua:8481`, `OutfitterBar.lua:1063` and the XML.
- **Localized matching.** LibBabble-SubZone and LibBabble-Inventory (`OutfitterPrefix.lua:16-23`). Profession presets match on LBI names (`OutfitterScripting.lua:500,506,1650`). `IN_ZONES` matches on zone text (`:663-680`). The buff preset calls `GetAuraDataBySpellName` (`:1311`). MC2TooltipLib parses English stat text. `UpdateZone` gates on `GetZoneText` (`Outfitter.lua:4941-4947`).
- **Libraries.** Eight MC2* libs, three LibBabble libs, LibTipHooker, LibDropdown, UTF8, `LibWithFreeDragDBIcon` (a renamed LibDBIcon), the soft `LibButtonFacade`, CallbackHandler, LDB and LibStub.
- **Integrations.** Pawn and WeightsWatcher (`OutfitterItemStats.lua:442,514`), and TankPoints (`Deprecated.lua:741`).
- **Displays.** The outfit bar is movable and lockable (`OutfitterBar.lua:242-266,1410,1600,1627`) and has a typed backdrop (`:922`). The bar settings dialog has literal colors (`:1369-1389`). There is an icon chooser over `GetMacroIcons`, QuickSlots, a minimap button (`OutfitterMinimapButton.lua`), an LDB launcher whose icon and text follow the worn outfit (`OutfitterLDB.lua`), and an About credits frame.
- **Harness.** Home-grown: `tests/framework.lua`, `loader.lua`, `wow_mock.lua`, `run.lua` and `run-all.sh`, plus a local `test_eol.lua`. The suites are test_commands, test_compat, test_deprecated, test_harness, test_load, test_locale, test_outfits, test_scripts, test_secrets, test_syntax, test_toc, test_xml and test_zones.
- **Docs.** `README.md` (sections: What it does, Usage, What no longer works, Version history, Credits, Licence), `CHANGES.txt`, `UsersManual.md`, a full-brief `CLAUDE.md`, the frozen `docs/reviews/2026-09-16/`, and `docs/superpowers/`.

---

## STANDARDS.md (index)

- [ ] **[MUST] STANDARDS.md:5.** The addon is built to the standard and references it.
  - This reverses every line of the current "NOT a Ka0s addon" CLAUDE.md: the roster exclusion, "never vendor LibKa0s", "don't reshape", the Hungarian naming and "no Ka0s testkit".
- [ ] **[MUST] launcher-§2 :65 (cross-repo).** Add Outfitter to `WowAddonStandards/standards/ADDONS.md`. Use a same-named branch there (versioning-git).

---

## anti-patterns.md (cite as `anti-patterns #N`)

- [ ] **#1** No global namespace table. `_G.Outfitter`, `OutfitterAPI`, `gOutfitter_*`, the `Outfitter_*` and `Outfitter_c*` globals and `Outfitter_OnAddonCompartmentClick` all go. Any external surface uses the public-api shape.
- [ ] **#2** No strict AceLocale. Use the metatable fallback.
- [ ] **#3** No hand-rolled options framework. The in-window Options tab and the MC2UIElementsLib controls are replaced by LibKa0s-Options.
- [ ] **#4** AceConfig only for Profiles.
- [ ] **#5** No direct `SLASH_*` registration. Applies to `:5297` and `:5301`.
- [ ] **#6** No if-chain dispatcher. Use `NS.COMMANDS`.
- [ ] **#7** No `.pkgmeta externals:`. None today.
- [ ] **#8** No forked Ace libs. `RegisterWidgetType` is for new names only.
- [ ] **#9** No `WOW_PROJECT_ID` branching. None found.
- [ ] **#10** Deprecated-API calls route through Compat.
- [ ] **#11** Replaced Blizzard frames are reparented to a hidden parent, never `:Hide()`d. Check that no paperdoll or equipment-manager element is hidden.
- [ ] **#12** Don't replace `AddMessage`.
- [ ] **#13** No hard `## Dependencies`. Remove the empty `RequiredDeps:` line.
- [ ] **#14** MIT. Already MIT; keep John Stephen's 2006-2018 copyright in LICENSE.
- [ ] **#15** Retail only, one Interface line. Compliant.
- [ ] **#16** No authored `.lua` over 1500 lines, `tests/` included. Covers the four files over the cap, plus the 1000-1500 band proactively.
- [ ] **#17** One sender per bus message.
- [ ] **#18** No debug output to chat while a main window exists. MC2DebugLib and chat debug prints go.
- [ ] **#19** No cross-module direct table access. Modules talk through the bus.
- [ ] **#20** User-supplied Lua execution is banned at the standard level. **Hard call H1.**
- [ ] **#21** No unrequested branches. The owner directed `feat/2026-11-03-ka0s-conversion`.
- [ ] **#22** The settings category is registered eagerly. Only the body is lazy.
- [ ] **#23** Never commit red or lint-dirty.
- [ ] **#24** Every logic change has a test. Characterize first; the existing outfits, zones and scripts suites are the seeds.
- [ ] **#25** No loose files in `media/`. Use typed subfolders.
- [ ] **#26** The root CLAUDE.md is a stub.
- [ ] **#27** No TODO.md in a released addon.
- [ ] **#28** Canonical README order and TOC field order.
- [ ] **#29** No hard suite dependencies and no reading other addons' data. Pawn and WeightsWatcher must be presence-guarded.
- [ ] **#30** The options scrollbar is always shown. *(library-owned)*
- [ ] **#31** Paired buttons use `BUTTON_PAIR_REL`. *(library-owned)*
- [ ] **#32** Each bus receiver owns a distinct target.
- [ ] **#33** The bus mock keys by target and fans out. Use the kit's mock.
- [ ] **#34** The standards reference appears in CLAUDE.md (and in the TOC and README, documentation-§6).
- [ ] **#35** No secret values into concat, format or print, and no `..` probe. Map `OutfitterAPI` helpers onto LibKa0s-Compat and the stringifier. Keep the `BeginEquipmentUpdate`/`EquipmentUpdateCount` invariant as a test.
- [ ] **#36** AceConsole `:Print` must not clobber the printer.
- [ ] **#37** Never match game data on localized strings. Covers LibBabble, the profession, zone and buff presets, and tooltip stat parsing (see localization-§4).
- [ ] **#38** No aggregate `embeds.xml`. List each lib directly.
- [ ] **#39** No full-panel rebuild per mutation. *(library-owned)* The host must not rebuild every page when an outfit changes.
- [ ] **#40** Retired.
- [ ] **#41** The console has a scrollbar and a line counter. *(library-owned)*
- [ ] **#42** No header buttons built at registration. *(library-owned)*
- [ ] **#43** No ungated instrumentation in hot paths.
- [ ] **#44** No shared measurement frame. *(library-owned)*
- [ ] **#45** LibKa0s is byte-identical to its tag outside `media/icons/`.
- [ ] **#46** No British spelling: "Licence", "Localisations", "optimised", "behaviour", "favour". A key change moves every locale file in the same commit.
- [ ] **#47** No hand-rolled console, options toolkit, dispatcher, test harness, SearchBox, TestStrip or `BonusIDsFromLink`. The current `tests/` framework is replaced by `tests/_kit/`. Any simulator is built on Sim.
- [ ] **#48** No partial vendoring of LibKa0s.
- [ ] **#49** No `docs/agent-context.md`.
- [ ] **#50** DEPENDENCIES.md is present and accurate.
- [ ] **#51** The complexity record is read and the watch list dispositioned.
- [ ] **#52** No metric-gaming refactors (`part2`, `doTheRest`). Name helpers for what they do.
- [ ] **#53** A watch-list entry accepted for three runs is fixed or tracked.
- [ ] **#54** No `or`-defaulting of falsy choices. Use `== nil`.
- [ ] **#55** Don't promote repeated-but-not-shared shapes into the library.
- [ ] **#56** The stub's member set matches its call sites (surface parity).
- [ ] **#57** `.gitattributes` has the CRLF pin, LF for `*.sh`/`*.py`, and binaries marked.
- [ ] **#58** No library inventory in the README. Delete the "libraries bundled under `Libraries/`" sentence.
- [ ] **#59** The provenance line lives in CLAUDE.md, not the README.
- [ ] **#60** No `docs/pending/LEDGER.md`. None exists.
- [ ] **#61** Every perf capture bundle has an `ANALYSIS.md`.
- [ ] **#62** No status or severity in issue titles.
- [ ] **#63** No private copies of catalog media or one-off marks. Covers the Textures chrome.
- [ ] **#64** Forwarders pass every argument.
- [ ] **#65** One `MakeCloseButton` wrapper in the Core setup file, taking the folder name.
- [ ] **#66** Annotate load-bearing TOC lines.
- [ ] **#67** No placeholder Curse id. 1698220 is real.
- [ ] **#68** The General page's first tab is `Master controls`.
- [ ] **#69** Every schema row has a `group`.
- [ ] **#70** No state-dependent layout measurement.
- [ ] **#71** No hand-rolled headings.
- [ ] **#72** No box around chrome-band controls.
- [ ] **#73** No hand-written font, border or bar groups.
- [ ] **#74** No `disabledIf` on a color row while class color is on.
- [ ] **#75** No up/down arrow reorder. Applies to outfit order, bar order and trigger priority if they are user-set.
- [ ] **#76** No addon-local widget-type re-registration.
- [ ] **#77** README edits get a de-AI pass.
- [ ] **#78** A structural registry has one writer. The outfit collection's writer must be named.
- [ ] **#79** No logo in the README.
- [ ] **#80** A positionable display needs a session-only Test mode. The outfit bar qualifies.
- [ ] **#81** One LDB object. OnClick is the library's. One visibility row at `hide`. No broker toggle and no host menus. **Hard call H6.**
- [ ] **#82** IconTexture is the addon's own 128 TGA.
- [ ] **#83** No reset un-hides the minimap button.
- [ ] **#84** The broker label is `Ka0s Outfitter Reborn`, plain text.
- [ ] **#85** Disable is total.
- [ ] **#86** Out-of-game runs are bounded, with no host paths and no stray probes.
- [ ] **#87** The harness retains no per-case instances.
- [ ] **#88** Never close Blizzard's Settings in combat.
- [ ] **#89** The launcher tooltip comes from the library.
- [ ] **#90** There is a `diagnostics` verb and `debug diagnostics`, with no aliases, ungated, no Clear, working while disabled, capped.
- [ ] **#91** No per-pass logging in steady-state repeating paths.
- [ ] **#92** Complexity is measured through the kit runner, never raw lizard.
- [ ] **#93** Nothing left on pooled AceGUI frames without `OnRelease`.
- [ ] **#94** Locale topic files don't reassign `NS.L`. No duplicate keys. Translations carry their own gate.
- [ ] **#95** The icon subset matches the CLAUDE.md declaration.
- [ ] **#96** Bindings: CLICK, category `BINDING_HEADER_OUTFITTER`, no `header` attribute, no Lua, no default key.
- [ ] **#97** Test-mode data carries a visible, localized marker.
- [ ] **#98** The Keybindings tab uses `O.KeybindingsTab` and is last on the General page.
- [ ] **#99** Layering comes from a layers table: no bare strata, no absolute or sibling level, no level captured once against a moving base. Re-express `MatchWindowStrata` and `MatchSlotEnablesStrata`.
- [ ] **#100** No overlay under what it overlays. The slot checkboxes must sit above the paperdoll item buttons.
- [ ] **#101** Edit chrome is reachable and above content. The bar drag handle ignores parent alpha.
- [ ] **#102** No HUD in the dialog tiers.
- [ ] **#103** Window ordering: dialogs open above their opener.
- [ ] **#104** Popups clamp, die with their opener, and use no full-screen catcher.
- [ ] **#105** No mouse-enabled alpha-0 frame. A StaticPopup is restored after a lift.
- [ ] **#106** Don't rewrite composed row words. Use `notes`.
- [ ] **#107** After `RegisterOwner`, no literal colors or fonts, and no Blizzard shared frame restyled.
- [ ] **#108** No full redraw on every size change.
- [ ] **#109** Media pickers go through `Ka0sMedia_*`.
- [ ] **#110** Every surface follows the skin, and HUD colors have FromSkin companions.

---

## architecture.md

### architecture-§1 Namespace bootstrap
- [ ] **[MUST] :7** Every authored `.lua` opens with `local addonName, NS = ...`. No file does today.
- [ ] **[MUST NOT] :15** No `_G[addonName]` table. The folder is `Outfitter`, so the global `Outfitter` must go. The public surface is `NS.API.v1` (public-api).
  - Scripts get a `setfenv` sandbox (H1).
  - The `Outfitter_c*`, `gOutfitter_*` and compartment globals go.
- [ ] **[MAY] :17-23** Local aliases (`local L = NS.L`).

### architecture-§2 AceAddon
- [ ] **[MUST] :36** `AceAddon:NewAddon(NS, addonName, ...)` and `NS.addon = addon`, in `core/Outfitter.lua` (shape of DpsRace `core/DpsRace.lua`).
- [ ] **[MUST] :37-44** The printer survives the AceConsole embed. Reclaim `NS.Print` after NewAddon, or use `NS.Util.print` everywhere.
- [ ] **[MUST] :45** The mock's `NewAddon` stamps the colliding `:Print`. *(kit)*
- [ ] **[SHOULD NOT] :46** `NewModule` below about 10 modules. Outfitter will have 10-15; plain `NS.Foo` tables with per-receiver bus targets, as in DpsRace.

### architecture-§3 Module pattern
- [ ] **[MUST] :59** `NS.X = NS.X or {}`, idempotent.
- [ ] **[SHOULD NOT] :60** No cross-module calls at file load. Presets may read `NS.L`, but not `NS.Inventory`.

### architecture-§4 Closed message bus
- [ ] **[MUST] :64-69** Modules talk through named messages. It binds here: many modules.
  - Candidates: OutfitWorn, OutfitsChanged, InventoryChanged, ZoneChanged, ScriptEvent, ProfileChanged.
  - MC2EventLib custom events map onto the bus.
- [ ] **[MUST] :110** Message names are prefixed `Ka0s_Outfitter_`.
- [ ] **[MUST] :111** Each name is declared once in `NS.MSG` in `core/Bus.lua`, and no call site types the literal.
  - [MAY] wrap it in a LibKa0s-Bus Catalog. Recommended, because it catches typos in the script event-name map.
- [ ] **[MUST] :112** ARCHITECTURE documents each message: name, one sender, payload and consumers.
- [ ] **[MUST NOT] :113** No two senders. `OutfitsChanged` comes only from the Outfits registry writer; Equipment, Scripting and EM-sync call the writer.
- [ ] **[MUST] :114-126** Each receiver registers on its own AceEvent target, never `NS.addon`. That includes one target per script context.
- [ ] **[MUST] :127** The bus mock fans out by target. Test two scripts receiving one event.
- [ ] **[MAY] :128** LibKa0s-Bus `StandDown`/`StandUp`. Recommended, given the many per-script targets.

### architecture-§5 Schema as single source, registries, named non-setting state
- [ ] **[MUST] :132** A schema exists (more than 3 settings).
- [ ] **[MUST] :146** The schema drives AceDB defaults (through `defaults/Profile.lua`), panel widgets, `get|set|list|reset` and defaults reset.
- [ ] **[MUST] :147** Every row write goes through `NS.Schema:Set(path, value)`: panel, slash, bar menu toggles. Instance rows go through the helper with an instance argument.
- [ ] **[MUST] :148,153** Each structural registry has one named writer, with storage keys and its load pass, in ARCHITECTURE/schema.md.
  - **Outfit collection** (`db.char`): writer `NS.Outfits` (Create, Delete, Duplicate, Rename, Reorder, SetItem, Capture). It owns membership, the id counter, category order (Complete, Accessory) and the current-outfit pointer.
  - **Per-outfit script settings** (`$SETTING`): a dynamic per-member schema. **Hard call H13.**
  - **Item records** inside an outfit are member contents, written only by the writer.
  - The outfit stack is runtime state and is not persisted.
- [ ] **[MUST] :150** Panel and slash call the writer and never `tinsert` the stored table. Today the code mutates `Outfits[category]` directly in many places; consolidate.
  - The current pointer MAY live in a narrower scope, and readers treat a missing target as "none".
- [ ] **[rule] :151** The load pass (seed special outfits, repair, counter) is reachable only from init and the profile callbacks. No old-SV migration.
- [ ] **[rule] :152** ResetProfile, swap and copy are not registry writes.
- [ ] **[MUST NOT] :154** No other persistent write outside the helper, except named non-setting state.
- [ ] **[MUST] :155-161** Name each piece of non-setting state with key, owner and writers:
  - bar position (drag geometry);
  - LibDBIcon `minimapPos`;
  - script-editor size;
  - the inventory or item cache, if persisted (learned);
  - the last-worn outfit, if persisted;
  - remembered view state.
  - The docked window has no geometry.
- [ ] **[rule] :164-167** A value that a control sets is a preference. A drag writing a field that a row addresses goes through the helper.
- [ ] **[MUST] :168** Boot check that every row path resolves. The minimap row (`minimap.shown` over `hide`) is skipped, and no `shown` default is added.

### architecture-§6 Two-phase init
- [ ] **[SHOULD] :172** With six or more modules, use an initial queue before AceDB and a regular queue after. Mirror DpsRace Lifecycle/Env setup.

### architecture-§7 Prototype registry
- [ ] **[MAY] :176** Candidates: `_ListItem`, `_ScriptContext`, `_Credits` prototypes.

---

## audit-review-history.md (cite bare)

- [ ] **[MUST]** One frozen dated folder per run, never edited:
  - `docs/audits/<date>/` with 01_CURRENT_STATE … 05_EXECUTION_PLAN, and stable deviation ids;
  - `docs/reviews/<date>/` with 01_FINDINGS … 05_FINAL_SUMMARY;
  - `docs/revendor/<date>-v<tag>/` with 01_DELTA and 05_SUMMARY always, and the middle three when there is content.
  - `docs/reviews/2026-09-16/` already exists. A same-day re-run gets a distinct folder.
- [ ] **[MUST]** The revendor folder name carries the tag.
- [ ] **[MUST NOT]** No README.md in the audits, reviews or revendor stores. `docs/automated-tests/README.md` and `docs/perf-analysis/README.md` are MUST.
- [ ] **[SHOULD]** Retain prior bundles. Keep `docs/reviews/2026-09-16/` untouched.
- [ ] **[MUST NOT]** Histories never ship. `docs` stays in the `.pkgmeta` ignore list.
- [ ] **[rule]** Stores appear in the documentation map as directories, never row by row.
- [ ] **[rule]** A review's `03_SMOKE_TESTS.md` holds the in-game checks.
- [ ] **[MUST]** Every commit touching `libs/LibKa0s/` or `tests/_kit/` has a revendor bundle naming the tag from that commit's CLAUDE.md provenance line, or a deviation row. The horizon is the store's first bundle. Span bundles start `Delta: LibKa0s vA -> vB (span: vA … vB)`, have one line per tag in 05_SUMMARY, and are never edited. **Hard call H24.**
- [ ] **[MUST] (deviation register)**
  - Rows resolve to the current standard.
  - Triggers are evaluable against the tree.
  - Evidence ids in Why resolve to a bundle or issue. Cite ids only after the bundle or issue exists.
  - The audit reads the register first.
- [ ] **[MUST] Issue store.** Exactly one status label (`state:done` 00ff00, `state:will-not-do` 0000ff, `state:triaged` ffff00, `state:untriaged` ff0000) and one severity label (`severity:critical` 110000, `high` 110800, `medium` 111100, `low` 001100).
  - No status or severity in titles.
  - Repair labels on sight and announce it.
  - Use `gh issue`/`gh label` only, never GraphQL. Create labels with `gh label create --force`.
  - Check that all eight labels exist on tusharsaxena/Outfitter. Deferred findings become labeled issues.
- [ ] **[MUST NOT]** No `docs/pending/LEDGER.md`.

---

## automated-tests.md (cite as `automated-tests-§N`)

- [ ] **§1 [MUST] :18-46** Every run goes in `docs/automated-tests/<YYYYMMDD-HHMMSS>/` (local time, frozen): manifest.json, ANALYSIS.md, lint.txt, tests.txt, test-cases.md, perf.txt, perf.json and complexity.txt. Plus the store's README.md and RESULTS.md.
  - Files are named for the suite, not the tool. Never prune.
  - `docs/` is pkgmeta-ignored.
- [ ] **§2 [MUST] :53-61** Run via `tests/_kit/run-automated-tests.sh`. Never edit or re-implement it. Retire `tests/run-all.sh`.
- [ ] **§2 [MUST] :62-83** `*.sh text eol=lf`, and the rest of line-endings.
- [ ] **§2 [MUST] :84-100** Set the runner to 100755 in the index with `git update-index --chmod=+x` (WSL DrvFs). The vendor gate asserts it.
- [ ] **§3 [MUST] :105-120** Lint and tests gate. Perf and complexity record only (amber) and never block a commit.
- [ ] **§3 :122-133** A missing tool is a skip with its reason. Perf skip reasons are limited to "no `tests/perf.lua`" or a named performance-§12 exemption. Outfitter ships `tests/perf.lua`.
- [ ] **§3 :135-136** Verdict definitions: red, amber, green.
- [ ] **§3 [MUST] :138-235 Sighted complexity.**
  - Measure only through `--suite complexity`, never raw lizard.
  - `blindFiles>0` or `crashedFiles>0` fails (amber, blocks release).
  - Wire `{name="test_lizard_sighted", dir="tests/_kit/"}`.
  - Hoist keyed function literals out of `for … in pairs({…})` headers.
  - A kit older than rev 35 means re-vendor.
- [ ] **§3 :237-254** CCN>15 is the only complexity warning. `-L 1500` is fixed. Never split functions for length alone or re-tune `-L`.
- [ ] **§3 [MUST NOT] :256-298 Release gate.** No 1.1.0 bump or tag unless the manifest shows all four suites passing, `complexity.warnings==0`, and zero blind and crashed files. A skip is not a pass (narrow perf exception only). Report every failed gate; never do a partial bump. **Hard call H19.**
- [ ] **§4 :302-446 RESULTS.md**
  - One file, overwritten in place, one row per run with the full column set.
  - Skipped counts are separate: not-selected, skipped and 0 are different.
  - Per-row SHA and clean/dirty mark. Checkpoints in the lead-in, a `gates` object in the manifest.
  - Never recreate the file on a column change. Only `Disposition` is authored.
  - The watch list is two tables (functions by CCN, files by band). "Accepted" lasts at most three release runs.
  - The band table agrees with the ARCHITECTURE census.
- [ ] **§5 :453-474 ANALYSIS.md.** MUST at release, SHOULD when not green or when numbers moved. Never backfill. Follow the `AUTOMATED_TESTS.md` prompt.
  - A release run carries `## Preview and simulation data` (preview-mode).
  - Link artifacts and report complexity totals.
- [ ] **§6 [MUST] :478-489** A full four-suite bundle in the release change, before the tag. Never gate commits on the full bundle. Subsets are allowed anytime.
- [ ] **§7 :493-502** No `docs/complexity.md`. `docs/perf-analysis/` holds in-game captures only, and its README says so.

---

## compat.md (cite bare)

- [ ] **[MUST] :5** Every deprecated or version-variant client call lives in the compat family. Consumed LibKa0s-Compat members are routed from `core/Compat.lua`.
  - `Compat.lua` (`OutfitterAPI`) becomes `core/Compat.lua`, publishing `NS.Compat`.
  - `GetAddOnMetadata` reads go through LibKa0s-Env.
  - Decide each item, container and equipment API case by case. Only deprecated or variant calls must be in the family.
- [ ] **[MUST] :7** Family files are `core/Compat.lua` plus `core/Compat<Topic>.lua` only. No folder, no shims in `modules/`.
- [ ] **[MUST] :9** One `NS.Compat` table. Callers don't know which file defines a member.
- [ ] **[MUST] :10** The root exists whenever a split exists, loads first, carries the LibKa0s-Compat resolution and the library-absent stubs, and its header names every split file.
- [ ] **[MAY/SHOULD] :11** Split only when the family exceeds 1000 lines, and do it then, by cohesive topic (no `Compat2`). Keep stat parsing in `modules/`, so compat should stay under 1000.
- [ ] **[MAY] :13** Lint fences confining client globals to family files (DpsRace `files[...]` stanzas).
- [ ] **[MUST] :17** With no qualifying call, ship no file and record N/A. Outfitter will have calls.
- [ ] **[MUST] :19** A shipped simulator reads only through compat. Outfitter declines a simulator (H18); say so.
- [ ] **[MUST] :21** Delete dead fallback rungs, don't shim them: pre-retail globals behind `C_Container`/`C_AddOns`, and the whole Deprecated.lua layer.
- [ ] **[MUST] :41** Route every deprecated API through Compat.
- [ ] **[MUST NOT] :42** No flavor branching. A Retail-patch check goes behind a named flag.
- [ ] **Secret values.** `IsSecret`, `Unsecret` and `UnsecretNumber` map onto the LibKa0s-Compat guard arm (`IsSecret`/`CanAccess`/`IsSafeKey`). The library-absent stub re-implements the one-rung body, with a comment naming the Compat API doc's Degradation section (options-ui-§1 :76). Write shims dot-form so the compat-layer.md shim count works.

---

## debug-logging.md (cite `debug-logging-§N`)

Adoption: the wiring, the Diagnosis checklist, §9, §10 and §14 are MUST. §8's choice of flows is SHOULD (:9).

- [ ] **§1 [MUST] :13** Vendor the whole LibKa0s folder and list `LibKa0s.xml` after Ace3.
- [ ] **§1 [MUST NOT] :14** No hand-rolled console. Delete `DebugMessage`, `DebugTable`, `DebugColorCode` and MC2DebugLib.
- [ ] **§1 [MUST] :15-18** One guarded instance in `core/DebugLogSetup.lua`, after Constants, State and the printer and before any caller.
  - `NS.Debug = NS.DebugLog.Debug`, bound bare.
  - No lib-level singleton.
  - A stub when the lib is absent.
- [ ] **§1 :19** Descriptor: name, title, font, isEnabled, setEnabled, plus the optional fields. Check that `OutfitterDebugWindow` doesn't collide with an existing global.
- [ ] **§1 [MUST] :20** `print` and `safeToString` are call-time forwarders.
- [ ] **§1 [MUST NOT] :26** Never save console, copy-window or perf-panel size. The legacy `StartMovingFrame` must never touch library windows.
- [ ] **§1 :22** An audit asks for no console internals. Any Outfitter surface at DIALOG or above (the icon chooser) has a layers comment saying it can cover the console.
- [ ] **§1 :28-35** `DebugOnce`, `DebugChanged`, `DebugForget` and `DebugAtEnable` are bound bare.
- [ ] **§2 [MUST] :41-45** JetBrains Mono from the payload via `NS.MediaFont`. No second copy. Fallback is a real client font. The path is passed as the descriptor `font`. No `SetFont` on console regions. Every other text surface uses skin faces.
- [ ] **§2 [MAY] :47-49** Catalog marks. Mono glyphs for ▲/▼.
- [ ] **§3 :55-59** Line shape is `HH:MM:SS | [Tag] content`.
  - Suggested tags: Equip, Swap, Outfit, Script, Zone, Bag, Combat, State, Bar, Open, Set, Cmd. `Debug` and `Init` are reserved.
  - Never redefine or copy the formatters. Console colors come from the skin.
- [ ] **§4 [MUST] :67-72** The gated sink at every trace site. Never pre-build messages (`format`, `..`). Varargs go through `safeToString`, and secret values (health, aura fields, links) are passed raw. No ungated `Add` for tracing. Ship the diagnostics dump.
- [ ] **§4 [MUST] :83** Pass `debug = function(t,m) NS.Debug(t,m) end` to the Slash, Options, Launcher and Lifecycle descriptors. [SHOULD] pass `debugAtEnable` to the Launcher.
- [ ] **§4 [MUST NOT] :84** Don't duplicate library lines (stand-down, refusals, combat lock). Additive lines are fine.
- [ ] **§5 [MUST] :91-99** The flag is session-only in `NS.State.debug`.
  - `debug` toggles the window, `debug on|off` maps to SetEnabled, and `debug diagnostics` is tested first.
  - One `SetEnabled` seam.
  - Ack, bracket lines and `[Init]` are library-made. The host supplies `initSummary` ("v1.1.0, schema v1, profile, N outfits, M scripted").
- [ ] **§6 :105** Copy and Clear are the library's. Pass `onClear` for host gates.
- [ ] **§7 [MUST] :110-116** The stub doesn't error and carries every member called: Debug, Add, SetEnabled, IsEnabled, Show, Hide, Toggle, IsShown, Clear, ConsoleCheckbox, RunDiagnostics, buffer and the gates.
  - It flips the flag and acks. [SHOULD] say once that the window is unavailable.
  - No formatter copies. Uses the console path (Outfitter has a main window).
  - Verified by a real lib-missing load.
- [ ] **§8 [MUST] :126** Lifecycle lines: `[Init]`, any migration (none at 1.1.0) and any prune.
- [ ] **§8 [SHOULD] :130-137** Core flow: equip requested, swap computed and finished, script trigger to decision, zone to special ID, and the no-op decisions (already worn, item missing, slot disabled, refused in combat, two-hander conflict).
  - Registry mutations get one functional line each (never `[Set]`): create, delete, rename, rebuild, optimize.
  - View opens: one line per list or bar rebuild.
- [ ] **§8 [MUST] :143-169 Diagnosis.**
  - State edges: combat, restriction parking, zone, spec, mount, enable.
  - Deferred work held and flushed: combat swap queue, `EquipmentUpdateCount` hold and flush, deferred bag rescans, item-info waits.
  - Refusals naming the guard.
  - Dependencies once at enable: LDB, LibDBIcon, EllesmereUI, Pawn, WeightsWatcher.
  - Caught errors once per distinct error: script compile and runtime errors keyed per outfit with `DebugOnce`.
- [ ] **§8 :171** One gated, tagged line per event.
- [ ] **§9 [MUST] :179-216** One summary line per pass (`[Bag] scanned N, M changed`), built behind the gate.
  - Nothing logged on unchanged repeats: UNIT_AURA, UNIT_HEALTH, BAG_UPDATE bursts, OnUpdate and timers. `(xN)` folding doesn't count.
  - [SHOULD] DebugChanged/DebugOnce over hand-made memos.
- [ ] **§10 [MUST] :220-263** `[Set] path = value` once, at the seam, with no reactor echo. Bulk reset is one `[Set] reset <scope>: N rows`. Profile events get one line.
- [ ] **§10 [SHOULD NOT] :265-272** Don't log named non-setting state per change: bar position, geometry, learned data. Outfit edits are registry flow lines.
- [ ] **§11 :276-280** *(library-owned)* No `GetNumLinesDisplayed`/`GetCurrentScroll` on a ScrollingMessageFrame.
- [ ] **§12 [MUST] :290-296** Shared windows are decorated only with `ApplySkin` and the `NS.MakeCloseButton` wrapper. [SHOULD] delete close-only decorate hooks. Module logs go to the sink and chat to `NS.Print`. User-initiated runs print ungated. The host supplies the "show my log" hook.
- [ ] **§13 [MUST] :303-310** Descriptor `addonName = "Outfitter"`. No tooltips on console controls. DebugLog minor ≥10.
- [ ] **§14 [MUST] :335-470 Diagnostics dump.**
  - Exactly `/<slash> diagnostics` and `/<slash> debug diagnostics`, with no aliases.
  - Works while disabled. Read-only: no holds, events, timers or stand-up.
  - Uses `RunDiagnostics()` ungated. It turns logging on by default; `diagnosticsEnablesLogging=false` must be documented. Never wrap it in `SetEnabled`.
  - Appends, never clears. Secret-safe: `%s` only, per-section pcall, "unreadable in combat".
  - Markers `[Diag] ==== Ka0s Outfitter Reborn diagnostics begin ====` and `… end: N line(s) ====`, with `brandName` set.
  - Order: identity, non-default settings, domain sections, rejected events and errors, truncated, end. Plain English, hyperlinks stripped, capped at `DIAG_MAX_LINES`.
  - Domain sections: current and expected outfit and layers, `EquipmentUpdateCount` and in-flight swap, scripted outfits with enabled state and last error, zone and special-ID detection, queued combat swaps, missing items (capped), bar shown/locked, test mode, holds.
  - Built on the library helper. The stub prints the library-absent line and returns 0.
  - Tests: kit `test_diagnostics_contract.lua` plus domain cases with falsification comments.
  - Documented in `docs/debug.md`.

---

## documentation.md (cite `documentation-§N`)

- [ ] **Preamble [MUST] :5-19** The root has README.md, a stub CLAUDE.md, DEPENDENCIES.md and LICENSE, never a fourth doc. No root CHANGELOG in any form, and `docs/CHANGELOG.md` doesn't satisfy the ban (:172-176).
  - **Delete `CHANGES.txt`** (its history folds into the README Version History).
  - Move `UsersManual.md` into README Usage/FAQ or a Tier 3 `docs/users-manual.md`; it then stops shipping.
  - `Bindings.xml` and the TOC are client files, not docs.
- [ ] **§1 [MUST] README.md**
  - Player-facing only. Plain US English, no jargon (secret value, EquipmentUpdateCount, AceDB).
  - No angle-bracket placeholders anywhere, backticks included. No `%20` in badges. Bullets, never numbered lists. Don't strip deliberate `<br>`/`<code>`.
  - **Exact order:**
    - H1 `# Ka0s Outfitter Reborn`.
    - Five badges, verbatim: `![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5-purple)` (matches Interface 120105), `![CurseForge Version](https://img.shields.io/curseforge/v/1698220)`, `![License](https://img.shields.io/badge/License-MIT-orange)`, `![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)` (never linked), `![Tests](https://img.shields.io/badge/Tests-X%2FY_passing-green)` (from `docs/test-cases.md`).
    - Description.
    - `## Screenshots`: **MUST**, because the addon is published (H22).
    - `## Usage`: up to about five prose paragraphs, in the order a player meets the addon. No slash or settings tables. Ends with Settings > AddOns plus the help verb in short and long form.
    - `## How outfits and automatic switching work`: must not contradict data-flow.md.
    - `## FAQ` (SHOULD): include "where did my old outfits go".
    - `## Troubleshooting` (SHOULD), with the Reporting-a-bug row.
    - `## Reporting a bug`: exact body with the real slash, no destination.
    - `## Issues and feature requests`, pointing at github.com/tusharsaxena/Outfitter/issues.
    - `## Version History` (capital H): Version | Date | Highlights, newest first, highlights as `- ` items joined by `<br>`, player-facing.
    - `## Credits`, last: John Stephen (mundocani), Nulian, NokeHarrier, kionik, UppyDan, translators. Open Iconic (Waybury, MIT) for close, copy and clear. Game-icons (CC BY 3.0, authors, "modified") if any `gi:` ships. Phosphor if shipped.
  - No font credits, no library list, no provenance sentence.
  - Drop `## Licence`; a one-sentence license mention in Credits is fine. Drop "What no longer works" (move it to scope.md and FAQ).
  - No logo image. No `## Testing`. Optional sections keep their relative order.
  - Keep in sync: the `[wow]` badge moves with any Interface bump, the `[tests]` badge with any count change.
  - **A de-AI pass before every README commit.**
- [ ] **§2 [MUST] CLAUDE.md stub.**
  - Order: H1 `# CLAUDE.md — Ka0s Outfitter Reborn`, the adherence line with the standard URL, `## Standards compliance (read first)` (copy DpsRace CLAUDE.md:6-27 in substance), read-the-docs pointers (ARCHITECTURE, testing, topic docs; never agent-context), the green-gate line (`lua tests/run.lua` + `luacheck .`), `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).`, and directly under it `LibKa0s icons: <names>.`.
  - Both lines move in the same commit as the vendored bytes.
  - The current gotchas move to docs: secrets to midnight-quirks.md, zone tables to common-tasks.md or zone-detection.md, stacking to ARCHITECTURE `## Frame layering`, secure rows to taint.md, live presets to schema.md or a scripts doc. The line-endings gotcha is retired.
- [ ] **§3 [MUST] docs/**
  - The trio: ARCHITECTURE.md, testing.md, smoke-tests.md.
  - ARCHITECTURE has ten sections: Overview, Module Map, Settings Schema (registries and non-setting state, named), Message Bus, Slash Commands, Event Subscriptions, Taint Notes, Known Limitations, `## Documentation map`, `## Documented deviations`. Extras such as Frame layering and Skins are OK.
  - `### Files over the 1500-line cap` sits under `## Documented deviations`, even if empty ("Nothing is over the cap today").
  - The deviations table is present even when empty ("None."), with columns `| Rule | What differs | Why | Decided | Re-check trigger |`. Rule is a `filename-§N` or bare name. Why SHOULD cite an issue or bundle. It is the single home and not a graveyard: retire stale rows.
  - testing.md: commands, gate, toolchain, pointers. A gate table names both checkpoints per suite and never has an unqualified "no — recorded only".
  - smoke-tests.md: every render-only check (docked window, checkbox stacking, skin switch, secure buttons, combat-queued equip, Escape ordering).
  - Verification and record docs: test-cases.md (generated), performance.md, perf-analysis/README.md, automated-tests/README.md and RESULTS.md. No complexity.md.
  - **Tier 1 (exact names):** scope.md (what it does not do: void storage, TankPoints, removed presets, Classic, no migration, the script decision), module-map.md, schema.md (new SV names, char vs profile), settings-panel.md (Page | Covers, then page > tab > row), data-flow.md (event > selection > equip queue > what the player sees), common-tasks.md (add a setting, slash verb, locale string, battleground trigger via the five tables and Map.db2, preset or trigger).
  - **Tier 2, when triggered:** slash-dispatch.md (present), midnight-quirks.md (present), compat-layer.md (at 3 or more addon shims), message-bus.md (over 10 messages, else an N/A row), profiles.md (present: settings follow profiles, outfits don't), known-limitations.md and taint.md (when the ARCHITECTURE section passes about 60 lines; taint likely does), debug.md (always), perf-analysis/README.md.
    - An untriggered doc gets an N/A row in the map, not a deviation row.
  - **Tier 3 (free-form):** scripts and triggers, zone detection, docking spec, upstream lineage, users manual. Each gets one map line and no duplication.
  - **Spill rule:** a section over about 60 lines spills to its canonical doc, leaving a summary and exactly one link. Overview, map and deviations never spill. A Tier 3 doc is never a spill target. The hub SHOULD stay under about 400 lines.
  - **Documentation map:** `### Required`, `### Conditional` (Doc | Status | Trigger), `### Verification and record` (exactly six rows), `### Addon-specific`. Every docs `.md` appears exactly once. Frozen stores are named once as directories: audits, reviews, automated-tests/<run>, perf-analysis/<run>, revendor, superpowers, investigations.
  - `file-index.md` and `conventions.md` must not exist.
  - No agent-context.md.
- [ ] **§4 [MUST NOT]** No TODO.md (released addon).
- [ ] **§5 [MUST]** Docs match the code. Run sync-docs before release.
- [ ] **§6 [MUST]** The standards reference in all three places: TOC X-Standard, unlinked README badge, CLAUDE.md section with stop-and-flag wording.
  - [SHOULD] `filename-§N` notation everywhere, with no dotted `§N.M`.
  - Malformed or out-of-range citations are a MUST fix; range-check with `grep -c '^### [0-9]'`.
  - Never edit frozen bundles.
  - An audit rolls the notation sweep into one finding.
  - [SHOULD] Cross-repo: present tense cites path plus symbol; historical claims pin `Outfitter@7ea3dc3:path:line`.
- [ ] **§7 [MUST] DEPENDENCIES.md.**
  - Runtime: WoW Retail only, all libs vendored.
  - Development: Lua 5.1 (hard: `setfenv`), luacheck, lizard via pipx, git.
  - Release/assets: Python and Pillow for the 128 TGA, marked as not needed to build or test.
  - Verbatim WSL2/Ubuntu install commands with the PEP 668 pipx workaround, and a version check per tool.
  - [SHOULD] end with the verified-with commands (`bash tests/_kit/run-automated-tests.sh`).
- [ ] **§8** N/A: this section is for doc and tooling repos.
- [ ] **§9 [SHOULD]** Every authored file opens, right after the vararg line, with `-- core/X.lua — purpose`. Apply to 100% of files.

---

## events-frames-taint.md (cite `events-frames-taint-§N`)

- [ ] **§1 [MUST] :7** All game events go through AceEvent. Retire MC2EventLib. The script engine maps to per-script AceEvent targets, game events through SafeRegisterEvent, pseudo-events (TIMER, GAMETOOLTIP_SHOW, special-zone ids, OUTFIT_*) to `NS.MSG`, and TIMER to AceTimer. **Hard call H14** (name map vs "dispatcher").
- [ ] **§1 [SHOULD]/[MUST NOT] :8** CLEU on one frame. None today; keep it so.
- [ ] **§1 [MAY] :9** AceEvent messages for the bus.
- [ ] **§1 [MAY] :17-24** Unit-filter frames, one event per frame, for player `UNIT_AURA` and `UNIT_INVENTORY_CHANGED`. Spellcasts use AceEvent with an early-out on unit.
  - [MUST] hold them on NS or the module, unregister them by hand on stand-down, and reuse them, never rebuild.
  - No factory and no second job (the OnUpdate tickers stay separate).
- [ ] **§1 :30-36** No boundary-watcher carve-out, because AceEvent is embedded.
- [ ] **§1 [MUST] :42-45** Register through LibKa0s-Core `SafeRegisterEvent(s)/SafeRegisterUnitEvent`, script-requested names included.
  - Drop `UNIT_MANA` and `CHARACTER_POINTS_CHANGED` in favor of `UNIT_POWER_UPDATE` and the talent events.
  - One `NS.rejectedEvents`, surfaced in `[Init]` and the debug verb.
  - The Core stub carries three one-rung pcall helpers.
- [ ] **§1 [SHOULD] :46-47** Front-gate with `C_EventUtils.IsEventValid` *(library)*. Write probe trade-offs into midnight-quirks.md.
- [ ] **§1 test :49** `M.__badEvents` proves one bad name doesn't deafen the block. Include `UNIT_MANA`.
- [ ] **§2 [MUST] :53-54** Secure writes are gated on `InCombatLockdown()` with a replay on `PLAYER_REGEN_ENABLED`: one `NS.SecureQueue` for list-row and bar secure attributes and for strata, level and toplevel writes on `OutfitterFrame`, which holds secure children. Today `:1427` silently drops the write. The slot enables hold no secure children; keep that comment.
- [ ] **§2 [MUST]/[MUST NOT] :62** Never gate secure writes on `UnitAffectingCombat`. Audit the equip paths.
- [ ] **§2 [SHOULD] :63-64** `UnitAffectingCombat` for display logic. Combat transitions come from REGEN events, not polling.
- [ ] **§3 [MUST] :70-74** `hooksecurefunc` on Toggle*, never assign `_G.ToggleX`. [SHOULD] a recursion guard if any are added.
  - Hide Blizzard frames by reparenting. No MoneyFrame.
  - [SHOULD] `core/TaintLess.xml` first if XML stays in the TOC.
- [ ] **§4 [MUST] :80-81** A single macro-API firewall if macros are ever created (none today). No protected API from combat-fired handlers. Equip deferral stays in Equipment.
- [ ] **§5 :87-89** N/A: no chat formatting or AddMessage hooks.
- [ ] **§6 [MUST] :93-96** Lua `CreateFrame` over XML for non-templated frames, which favors converting `Outfitter.xml` and `OutfitterBar.xml`. [MAY] XML for declarative groups.
  - Pool any UI with 10 or more dynamic frames: list rows, bar buttons, QuickSlots, optimize and script rows, icon grid. Secure pools acquire outside combat.
  - Set strata in the `CreateFrame` block, from LAYERS.
- [ ] **§7 [MUST] :113** `RefreshUpvalues()` after every setter feeding hot paths (aura, inventory, bag handlers, window follow, bar mouse).
- [ ] **§8 [MUST NOT] :125** No unguarded secret values in concat, format, print, comparison or arithmetic.
  - Dining thresholds and aura fields.
  - The script environment gets guarded accessors (`UnsecretNumber` equivalent in `core/Secrets.lua`).
  - `BeginEquipmentUpdate` stays paired on error.
- [ ] **§8 [MUST] :126-156** A `table.concat` probe. Stringifier and printer come from LibKa0s-Core in `core/CoreSetup.lua`.
  - `IsSecret` and `Unsecret` retire as stringifiers.
  - One `NS.Print` and one debug sink. No global `print` (`OutfitterOptimize.lua:666`), no hand prefix, no pre-format.
  - Reclaim `NS.Print` after NewAddon.
- [ ] **§8 :158-209** Pre-formatting is a MUST NOT where health, aura or cooldown values reach it; SHOULD NOT elsewhere. No global `print()` anywhere: the script sandbox exposes the tagged printer as `print`.

---

## frame-layering.md (cite `frame-layering-§N`; binds from 1.1.0)

Tier map:
- T0: unit frames, secure queue, binding buttons, hidden parent.
- Host-matched: `OutfitterFrame`, `OutfitterSlotEnables`.
- T1 HUD: the outfit bar (MEDIUM).
- T2: bar chrome.
- T3: the bar's popup.
- T6 MODAL (DIALOG): script editor, name and rebuild dialogs, About if kept, console.
- T8 POPUP (FULLSCREEN_DIALOG): menus, icon picker.
- T9: tooltips.

- [ ] **§1 [MUST NOT] :11** No frame-level race. The measured max-level+1 over CharacterFrame is relative by construction (:61); document it as host-matched.
- [ ] **§1 [MUST] :29-30** Only T8 and T9 at FULLSCREEN_DIALOG or above. An opened frame sits at least one strata above its opener.
- [ ] **§1 [MUST] :34** A strata knob offers only BACKGROUND through HIGH and uses `O.StrataTooltip`. Recommend no knob.
- [ ] **§1 [MUST] :42 Host-matched.** Read the host's strata, never a literal. Raise by a named offset (`LAYERS.LEVEL.HOST_OVER`). The highest-descendant walk skips `IsForbidden()` and pcalls secret level reads.
- [ ] **§1 :43** Player-layered: N/A.
- [ ] **§1 [MUST] :45-47** Exceptions carry a call-site comment and a deviation row. A window sharing strata with its modal band is not toplevel.
- [ ] **§2 [MUST] :51-57 Bar chrome.** Top of the band, mouse chrome floored at `max(display, MEDIUM)`, `SetFixedFrameStrata` with a re-lift.
  - [SHOULD NOT] drag affordances inheriting alpha: use `SetIgnoreParentAlpha` or DragHandle `ignoreParentAlpha`.
  - Order: backplate < outline < marker < handle. The test strip displaces or covers.
- [ ] **§3 [MUST NOT] :61** No absolute or sibling-relative `SetFrameLevel`. Delete `OutfitterUITools.lua:15`, the recursive `SetFrameLevel`/`SetFrameStrata` helpers (`:554-588`), and the `+1/+2/+5/+6/+20` offsets in Lua and XML. Use `base + LAYERS.LEVEL.X`.
- [ ] **§3 [MUST] :63-73** Root < FILL < BORDER < EFFECT < OVERLAY. Overlays over clickable or secure buttons get `EnableMouse(false)`. Glow uses LibKa0s-Glow with an explicit `frameLevel`.
- [ ] **§3 :75** Bands. HUD: backplate L, content L+1..19, label +20, outline +30, marker +40, handle +50. Window: chrome W+1, content W+2..8, grip +10, popovers +30.
- [ ] **§3 [MUST] :77-80** Distinct levels for overlapping drawing siblings (row item button vs secure child; checkboxes vs paperdoll).
  - Re-assert levels after `SetParent` and in every re-level, including `MatchWindowStrata` and pooled-row acquire.
  - Peers stack whole (stride ≥50, or toplevel).
  - Name library bands in the LAYERS comment and keep content ≤ +8.
- [ ] **§4 [MUST] :84** A movable window is toplevel. The docked `OutfitterFrame` is not movable and must **not** be toplevel (H4). A movable script editor is toplevel and clamped.
- [ ] **§4 [MUST] :85** Modals and tool windows are DIALOG, toplevel and clamped, and re-raise shown `StaticPopup1-4` on show.
- [ ] **§4 [MUST] :86** Popups are FULLSCREEN_DIALOG and clamped. They close on every opener-close path (opener OnHide, i.e. CharacterFrame hiding; the disable ladder; Escape). Dismissed via `GLOBAL_MOUSE_DOWN`. No full-screen catcher: check `OutfitterUITools.lua:14`.
- [ ] **§4 [MUST] :87** A HUD popup sits one strata above the bar, set once, clamped.
- [ ] **§4 [MUST] :88** Never switch strata to fix an order. Host copying is not an order fix; keep that comment. A lifted StaticPopup is restored on hide.
- [ ] **§4 [MUST] :89** Nothing invisible stays mouse-live: faded bar, alpha-0 secure parents. Disarm at REGEN_DISABLED or add a row.
- [ ] **§4 [MUST] :90** Protected strata, level and toplevel writes go through the secure queue.
- [ ] **§5 [MUST] :94-101** One `NS.Constants.LAYERS` in `core/Constants.lua`.
  - STRATA: HUD, HUD_POPUP, MODAL, POPUP, CURSOR.
  - LEVEL: named offsets.
  - The header states the whole stack, including the library tiers and CharacterFrame as host.
  - `grep -rn 'SetFrameStrata("' core modules settings` returns nothing.
  - ARCHITECTURE points to the table in one line.
- [ ] **§5 :103** The frameless clause is N/A.
- [ ] **§6 [MUST NOT] :125** Never re-strata CharacterFrame, PaperDollFrame, GameTooltip or the LibDBIcon button. Only the StaticPopup lift-and-restore is allowed.

---

## launcher.md (cite `launcher-§N`)

- [ ] **§1 [MUST] :9-36** Exactly one LDB object, `type="launcher"`, registered with LibDBIcon, built via LibKa0s-Launcher in `core/LauncherSetup.lua`.
  - Delete `OutfitterMinimapButton.lua`, `LibWithFreeDragDBIcon` and the custom compartment function (H6, H20).
  - Both registrations use the name `"Outfitter"`.
  - OnClick is the library's.
  - `icon` is the logo, the same path as IconTexture, and static: no outfit icon swap.
  - `label = "Ka0s Outfitter Reborn"` from `NS.BRAND`.
  - Never registered conditionally, no broker setting.
  - The library draws the tooltip (also while disabled), fed `version`, `isLocked` (bar lock) and `isTestMode`.
  - Host lines only via `onTooltipShow`: "Current outfit: X". Don't set LDB `OnTooltipShow`. Strings go through the locale.
- [ ] **§2 [MUST] :38-68** Left-click opens settings. Right-click opens the library menu, rows in fixed order: Enabled, Locked (bar), Test mode, Show window, Open settings, Open skin selector (Sim mode optional).
  - Every toggle uses the shared handler. While disabled, everything but Enabled and Open settings is grayed.
  - No host menu or click routing. Don't pass retired `onClick`/`leftClickLabel`.
  - Record the entries in ADDONS.md.
  - The minimap outfit quick-switch menu leaves the launcher (H6).
- [ ] **§3 [MUST] :70-86** `minimap.hide` lives in `db.global`, and `db.global.minimap` is passed to Register. No `show` key.
  - A profile switch doesn't move it, and it survives Reset all and page Defaults (`skipRestoreAll`).
  - It is a Master-controls row via `minimapPath` at `global.minimap.shown` with inverting closures through the seam, calling Show/Hide. Only `hide` is in defaults. The boot check skips it.
  - Seeding follows architecture-§5.
- [ ] **§4 [MUST] :88-94** IconTexture and LDB `icon` are the same 128 TGA. No Blizzard path or file id. The landing logo is separate.
- [ ] **§5 :96-119** Adoption steps:
  - vendor LDB and LibDBIcon;
  - generate the 128 logo;
  - build via Launcher;
  - add the row via `minimapPath`;
  - update ADDONS.md;
  - document it in settings-panel.md and ARCHITECTURE;
  - the README describes the clicks.
  - Ship the logo with the launcher.
- [ ] **§6 [MUST] :121-159** Show window binding.
  - `CLICK OutfitterToggleWindow:LeftButton`, listed first in `Bindings.xml`.
  - Every binding has `category="BINDING_HEADER_OUTFITTER"`. No `header` attribute, no `default`, no Lua.
  - The button is plain, named, hidden and non-secure, uses `RegisterForClicks("AnyDown")`, and its OnClick calls the `toggleWindow` handler.
  - The other bindings become CLICK on named hidden buttons: `OutfitterWearOutfit1..10`, automation enable and disable, update outfit. `OUTFITTER_OUTFIT` (open UI) becomes the Show window binding. Button names are permanent once shipped (H11).
  - `BINDING_HEADER_OUTFITTER` = brand, set at file scope.
  - `BINDING_NAME_*` via `L` and `rawset`: "Toggle outfitter window", "Wear outfit 1" and so on, verb phrases, no brand.
  - One `NS.BINDINGS` table in XML order.
  - A press while stood down refuses through the one helper (also the wear presses). Combat follows the handler; verify `ToggleCharacter` from an insecure click in combat.
  - Document it in README Usage (both places to set it) and settings-panel.md.
  - Test with `Kit.assertBindingsXml`, test_disabled step 8 and the Keybindings tab.
  - Commences 1.1.0 (anti-patterns #96).

---

## layout.md (cite `layout-§N`)

- [ ] **§1 [MUST] :59** Source lives under `core/ defaults/ settings/ locales/ modules/`, never loose at the root.
- [ ] **§1 :9-57 Target skeleton.**
  - One TOC. Root `Bindings.xml`.
  - `core/`: Namespace, Constants, State, Util, Compat, Secrets, the `<Module>Setup.lua` seams, `Outfitter.lua` (AceAddon), Database, Bus.
  - `defaults/`: Profile.lua, Global.lua if needed, and data files (PresetScripts, the zone tables, BuiltinEvents, stat tables).
  - `settings/`: Schema, OptionsSetup, Slash, Profiles and the pages.
  - `locales/`: enUS plus deDE, frFR, zhCN, zhTW, koKR, ruRU.
  - `modules/`: one file per feature.
  - `media/`, `libs/`, `tests/`, `tools/`, `docs/`.
  - Root files: README, CLAUDE, DEPENDENCIES, LICENSE, `.luacheckrc`, `.pkgmeta`, `.gitattributes`.
- [ ] **§1 [MUST] :60-61** Folder load order libs > locales > core > defaults > modules > settings, matching the TOC headers. Core is dependency-ordered, with load-bearing comments.
- [ ] **§1 [MUST] :62-65** 1500-line cap on every authored `.lua`, tests included. 1000-1500 is on notice. Target: everything under 1000. Frame XML converts to Lua and becomes capped.
- [ ] **§1 [MAY] :63** Peel into 2-3 siblings. Locales peel per localization-§6.
- [ ] **§1 :67-70** Carve-outs: `libs/` and `tests/_kit/`, and generated non-shipping data only when all three conditions hold. The zone tables ship, so they are capped.
- [ ] **§1 [MUST] :72-76** An over-cap file is peeled, has an open issue, or has a ratified row. The census `### Files over the 1500-line cap` sits under `## Documented deviations` and agrees with the RESULTS watch list (the band only there).
- [ ] **§1 [MUST] :78-88** Wire kit `test_layout_cap.lua` (rev ≥25) as `(basename, kit dir)`, with the exempt set via opts. It fails rather than skips.
- [ ] **§1 [MUST] :94-96** An authored generator lives in `tools/`, not the TOC, and is pkgmeta-ignored (e.g. a Map.db2 zone generator). [SHOULD] for non-Lua: fail loudly, review the diff, name the interpreter in DEPENDENCIES.
- [ ] **§1 [MUST] :102** `Bindings.xml`: exactly that name, at the root, not in the TOC, not ignored, no Lua beyond what the client needs. `BINDING_*` strings are set from a module.
- [ ] **§2 [MUST] :106-111** The root folder is PascalCase matching Title minus "Ka0s " (conflict, H2). Subfolders lowercase: `libs/`, `media/logos`, `media/screenshots`, `media/textures`. Files are `PascalCase.lua` without the `Outfitter` prefix. Locales use the locale code.
- [ ] **§3 [MUST] :113-123** Typed media subfolders only. fonts, sounds and textures only for assets the library lacks. No copies of library assets. The runtime `.tga`/`.blp` sits beside its `.png`/`.jpg` source.
- [ ] **§4 [MUST] :125-146**
  - `media/logos/outfitter.logo.128.tga`: 128×128, TGA type 2, uncompressed, 32 bpp, made with the Pillow recipe from `outfitter.logo.png`.
  - `media/logos/outfitter.logo.tga`: the 300 landing logo. It exists; check that it isn't RLE.
  - Commit the `.png`. Filenames use the lowercased folder name. No Blizzard icon, file id or other addon's art.

---

## library-stack.md (cite `library-stack-§N`)

- [ ] **§1 [MUST] :5-24** Core set: LibStub, CallbackHandler, AceAddon, AceDB, plus LDB-1.1 and LibDBIcon-1.0 always. AceEvent, AceTimer, AceConsole and AceGUI when reached (§3 test; Options reaches AceGUI). Copy DpsRace's set.
- [ ] **§2 :26-40** Optional libs:
  - LibSharedMedia-3.0: yes (skin, RegisterLSM).
  - AceDBOptions and AceConfig/AceConfigDialog: yes, for the Profiles page only.
  - LibDualSpec: no.
  - LibSerialize/LibDeflate: no (no export).
  - LibCustomGlow: only if something glows.
  - **[MUST NOT]** AceGUI-3.0-SharedMediaWidgets.
- [ ] **§3 [MUST] :42-55** Vendored under `libs/` and committed, no externals, one folder per lib, libs loaded first (today Compat and UTF8 precede LibStub).
  - [SHOULD] copy DpsRace's lib set.
  - **[MUST] vendor exactly what is reached**, checked three ways (direct LibStub, Ace mixin strings, lib-to-lib) with two greps. Delete the MC2* (8, which duplicate DebugLog, AceTimer, AceEvent and Options), LibBabble (3), LibTipHooker, LibDropdown, UTF8 (unless reached), LibButtonFacade and LibWithFreeDragDBIcon (H15).
  - [MAY] a private micro-lib.
- [ ] **§4 [SHOULD] :57-59** Call LibStub once at load and stash on NS. Fix `OutfitterBar.lua:836` and `OutfitterLDB.lua:4,22`.
- [ ] **§5 [MUST NOT] :61-64** No Ace forks. Extend AceGUI only with new `Ka0s_X` names. Drop the DBIcon fork.
- [ ] **§6 [MUST NOT]/[MUST] :66-74** No hard dependency on any addon. Fully functional alone. Never read a suite's data. Only `SkinEUI.lua` reads `EllesmereUIDB`. No embedded suite code.
  - [MAY] an integration only when presence-guarded, in OptionalDeps, and with a no-loss fallback. Pawn and WeightsWatcher: add them to OptionalDeps and re-check on `ADDON_LOADED`. TankPoints dies with Deprecated.lua. LibButtonFacade is dropped (H16).
- [ ] **§7 :76-401 LibKa0s.**
  - Vendor from the LibKa0s repo's inner ship folder at v1.85.0, not from DpsRace.
  - No hand-rolled module equivalents (#47).
  - Compat, Bus, Schema, Glow and Sim are optional, but no parallel copy once adopted. A simulator first shipped on ≥v1.75 is built on Sim. No hand copies of SearchBox, TestStrip or `Item.BonusIDsFromLink`; use LibKa0s-Item where it applies (MC2ItemLinkLib).
  - **[MUST]** the payload is the whole folder minus `media/icons/`, and the TOC lists only `libs\LibKa0s\LibKa0s.xml`, after Ace3.
  - One `core/<Module>Setup.lua` per adopted module (`LibStub(major, true)` plus a stub): Core, Env, Media, Skin, Widgets, Pool, Lifecycle, Perf, DebugLog, Launcher, Bus if adopted, and Options and Slash under `settings/`.
  - Not in Dependencies. `media/` ships. The testkit goes to `tests/_kit/`, never `libs/`.
  - **[MUST NOT]** edit `libs/`.
  - Byte-identical sync (`diff -r` empty except undeclared icons). [SHOULD] a stand-alone re-vendor commit.
  - The CLAUDE.md Bundles line moves with the bytes. The `LibKa0s icons:` line sits under it, and `media/icons/` holds exactly the declared set. `all` only for a player-facing catalog chooser (H23). Declare the library-drawn `close, copy, clear`, `info` if needed, plus host marks (`settings`, `lock`/`unlock`, TestStrip).
  - Attribution files travel with their set. `Media.Icon` receives only declared names.
  - Library-repo rules (minors, promotion bars) don't bind. [SHOULD] record a rejected promotion.
- [ ] **§8 [MUST] :403-539 Shared media.**
  - Every Media call passes `"Outfitter"`, the folder.
  - One `core/MediaSetup.lua` (`NS.Icon`, `NS.MediaFont`, a single `RegisterLSM`), loaded right after Namespace, registering at file load.
  - Use catalog marks. No private duplicates (Gear, MinimapButton, Icon, ScrollbarTrench, DialogBox-Background, drag handles, ButtonBar and QuickSlots backgrounds). New marks go upstream, in white.
  - Treat `nil` as an answer. No concatenated paths (`OutfitterLDB.lua:12,53`).
  - [SHOULD] sweep frames for catalog surfaces. [SHOULD NOT] replace a wide button's label with a mark; a tooltip doesn't fix an unclear mark.
- [ ] **§9 [MUST NOT] :541-591** No re-registration of existing AceGUI types from host code. New `Ka0s_X` types are fine. [MAY] per-instance tweaks.

---

## line-endings.md (cite `line-endings-§N`)

- [ ] **§1 [MUST] :49-61** A committed root `.gitattributes` (absent today = the defect). Exceptions-only doesn't count. It must not ship: add it to the `.pkgmeta` ignore list.
- [ ] **§2 [MUST] :65-96** `* text=auto eol=crlf`. No contradicting per-path pins.
- [ ] **§3 [MUST] :100-126** `*.sh text eol=lf` and `*.py text eol=lf`.
- [ ] **§4 [MUST] :130-146** Binaries marked from the canonical union list, never trimmed (`.blp`, `.png`, `.tga`, `.jpg`, `.ttf`). Extension-less binaries only in the appendix; none here, since the LICENSE files are text.
- [ ] **§5 [MUST] :150-385** Byte-identical canonical body (84 lines). Copy DpsRace's. Optional appendix after `# --- line-endings-§5 appendix ---`. Verify with `diff <(head -n $n .gitattributes) canonical`.
- [ ] **§6 [MUST] :391-433** `git add .gitattributes && git add --renormalize .`, then re-checkout stragglers until CR count equals LF count and renormalize stages nothing.
  - Never `git rm --cached -r . && git reset --hard` with uncommitted work.
  - [SHOULD] the commit is the renormalization only. Do it **first**. The 7 LF files flip, and the "preserve mixed endings" gotcha is retired.
  - WSL tool writes land LF: re-checkout after writes.
- [ ] **§7 [MUST] :437-571** Wire `tests/_kit/test_eol.lua` (rev 26+) green. Delete the local `tests/test_eol.lua`. Fail when it cannot look. Clear a red by per-file re-checkout. Strays are one rolled-up finding.

---

## lint.md (cite bare)

- [ ] **[MUST] :5-38** Root `.luacheckrc` from the template: `std="lua51"`, `max_line_length=false`, `codes=true`, `exclude_files={"libs/","tests/_kit/","docs/audits/","docs/reviews/","docs/revendor/","_dev/"}`.
- [ ] **[MUST] :40** `luacheck .` is at 0 before every commit, `tests/` included.
- [ ] **[rule] :41** Only `tests/_kit/` is excluded under tests. Outfitter-authored suites stay linted.
- [ ] **[MUST] :42** `OUTFITTER_TEST` is declared only in `files["tests/"]`.
- [ ] **[MUST NOT] :43** No blanket `ignore`. Follow DpsRace, with no top-level ignore and narrow commented per-file stanzas. Re-justify or drop the current convention codes.
- [ ] **[MUST NOT] :44** No write global without a comment. The target list is `OutfitterDB`, `OutfitterPerfDB`, `StaticPopupDialogs`, `BINDING_*` and `Outfitter` (the API publish). The `Outfitter_*` API and XML globals and `gOutfitter_OutfitToDelete` go.
- [ ] **[rule] :45** `libs/` is not linted.
- [ ] **[MUST] :46** `debugprofilestop` goes in read_globals and `OutfitterPerfDB` in globals, because perf is wired.
- [ ] Preset bodies kept as strings aren't linted. Add a test compiling every preset. Moot if presets become native (H1).

---

## localization.md (cite `localization-§N`)

- [ ] **§1 [MUST] :31-33** `NS.L` with a key-returning metatable in `locales/enUS.lua`. [MAY] non-strict AceLocale; never strict. Every non-enUS file starts with `if GetLocale() ~= "xx" then return end` (today they use `if == … end` blocks).
- [ ] **§1 [SHOULD] :34-35** Derived aliases in `locales/PostLoad.lua`. Every user-facing string goes through `NS.L` as whole sentences with placeholders.
- [ ] **§2 [MUST] :39-40** The key is the English string. Re-key all 339 `Outfitter.cFoo`. No opaque ids.
- [ ] **§3 [MUST] :44-45** Ship enUS. Don't substitute `_G` strings for the module; `INVTYPE_*` and slot names in addition are fine.
- [ ] **§3 :51-56** Terminal state: Routed, or English-only with a deviation row (H8).
- [ ] **§3 [MUST NOT] :69** No dead enUS keys (union with topic files). Drop retired-feature strings.
- [ ] **§4 [MUST] :80-99** Match game data on IDs.
  - Professions on the `GetProfessionInfo` skillLine id (Herbalism 182, Mining 186, Skinning 393, Fishing 356, Cooking 185; verify on wago SkillLine).
  - Zones on `uiMapID`/`instanceID`. Subzones: H9.
  - `UpdateZone` gates on IDs only.
  - Buffs as a spellID list matched on `aura.spellId`. Calling `GetAuraDataBySpellName` with a localized name is the :99 MUST NOT.
  - Item stats via `C_Item.GetItemStats` `ITEM_MOD_*` tokens or `C_TooltipInfo`, or GlobalString constants if text must match (:94).
  - Item class and subclass via `GetItemInfoInstant` and `Enum.ItemArmorSubclass`.
  - Spellcast logic on spellID.
  - `UnitClass` display only.
  - `UnitFactionGroup`'s first return is already the token: keep it (H10).
  - Equip error text compared against `ERR_*` GlobalStrings.
  - Outfit names are player data and exempt.
  - Expose ID helpers to scripts (`InZone(mapID)`, `HasAura(spellID)`).
- [ ] **§4 [SHOULD] :97** IDs flow to names for display only.
- [ ] **§5 [MUST] :122-153** US spelling everywhere ("optimised", "behaviour", "favour", "Licence", "Localisations"). A key's spelling fix moves every locale and call site in the same change.
  - Exceptions (:159-169): translations, Blizzard symbols, quoted upstream text, the name "Outfitter".
- [ ] **§5 [MUST] :180-303** The gate uses the canonical BRITISH (92) and ALLOWED (33) lists whole, with no private entries.
  - Exclusions are named per file or dir: libs, `tests/_kit`, frozen bundles, released changelog entries.
  - Waivers in `tests/prose_waivers.lua`, per file and word, with a reason.
- [ ] **§5 [SHOULD] :305-312** Wire kit `test_prose` as one suite entry (no hand-written copy); otherwise a deviation row.
- [ ] **§6 :343-398** Only if enUS passes 1500 lines (445 today):
  - enUS alone creates `NS.L`;
  - topic files are `enUS_<Consumer>.lua`;
  - one file per key;
  - TOC order enUS, topics, other locales, PostLoad, with LOAD-BEARING comments;
  - mirrored and gated translations;
  - the gates read the union and fail on duplicates.
- [ ] **§7 [MUST] :435-439** Strings painted in skinned faces are ASCII plus the safe set. Check the credit names. CJK translations in Latin skin faces are an issue (H8). Exempt: game data, chat, test data. Player outfit names are ambiguous; treat them as user data. Call the kit glyph guard (LibKa0s ≥1.82) on window, bar, panel and tooltip strings, including "Used by outfits: …". Commences 1.1.0.

---

## naming-cheatsheet.md (cite bare)

- [ ] :7 The addon folder is PascalCase: `Outfitter`. Folder vs Title is H2.
- [ ] :8 Lowercase subfolders. `Libraries/` > `libs/`, `Media/` > `media/`, `Textures/` > `media/textures/`.
- [ ] :9 Typed media subfolders.
- [ ] :10 `PascalCase.lua`, no `Outfitter` prefix (`modules/OutfitBar.lua`, `Inventory.lua`, `QuickSlots.lua`, `Scripting.lua`).
- [ ] :11-12 Suites `test_<module>.lua`. Conformance suites `test_disabled`, `test_surface_parity`, `test_vendor_sync`.
- [ ] :13 `local addonName, NS = ...`. Every `Outfitter:Foo` becomes an `NS.<Module>` call.
- [ ] :14 Public API `_G[addonName].API.v1`.
- [ ] :15-16 `OutfitterDB` and `OutfitterPerfDB`.
- [ ] :17-18 `NS.Perf` from `core/PerfSetup.lua`. lowerCamel buckets named for the path.
- [ ] :19 One LibKa0s major per module.
- [ ] :20 Slash verb of 2-3 lowercase letters (H5).
- [ ] :21 Bus messages `Ka0s_Outfitter_<PastParticiple>` (OutfitWorn, OutfitsChanged, InventoryChanged) as `NS.MSG` constants.
- [ ] :22 Settings keys are snake_case and dotted, in positive sense: `automation.auto_switch`, `tooltip.show_outfits`, `tooltip.item_comparisons`, `chat.hotkey_messages`, `bar.scale`, `bar.vertical`, `bar.hide_background`.
- [ ] :23 Locale key is the English source string.
- [ ] :24 Labels are sentence case, '(px)', 'opacity' never 'alpha', ' > ' in locations.
- [ ] :25 US English.
- [ ] :26 Module tables `NS.<PascalCase>`.
- [ ] :27 Chat printer `NS.Util.print` / reclaimed `NS.Print`.
- [ ] :28-29 A root CLAUDE.md stub with a Standards-compliance section, and no in-repo agent brief.
- [ ] :30-32 The `docs/` trio.
- [ ] Style: drop Hungarian `pFoo`/`vFoo`/`cFoo` and tabs for DpsRace's lowerCamel and 4 spaces. Not mandated, but the owner allowed the rewrite.

---

## options-ui.md (cite `options-ui-§N`)

Settings move from the in-window Options tab to a LibKa0s-Options canvas. The docked outfit window is **not** the settings panel.

- [ ] **Preamble [MUST] :7** Vendor Options, make one instance from a descriptor, stash it on NS, degrade when absent. The contract from §5 on binds. [SHOULD] an addon-specific page split; a hand-rolled shell is #47.
- [ ] **§1 [MUST] :13-25**
  - Vendor the whole folder after Ace3.
  - `settings/OptionsSetup.lua` loads after Schema and Slash and before every page.
  - `NS.Helpers = lib:New(descriptor)` is the instance, decorated in place.
  - OnCommit, OnDefault and OnRefresh are library-stamped; the host must not set them.
  - A load-completing stub publishes the members pages touch at load (found by measurement). Tests pin the member set and row count. No maker copies.
- [ ] **§1 [SHOULD] :51** Reset-all stays real in the stub.
- [ ] **§1 [MUST] :43-45** `addonName` in the descriptor. `get`/`set` through the single seam that slash `set` uses. `colorDecode`/`colorEncode` if colors aren't `{r,g,b,a}` (SHOULD write them anyway).
- [ ] **§1 [MUST] :57-64**
  - Hollow composers answer `{}` when the library is absent.
  - Verbs that write composed rows (enable/disable, lock/unlock, test mode) use route (a) writeThrough or route (b) a refusal line. They never raise and never ack a write that didn't land. [SHOULD] enable/disable take route (a); (b) is a deviation row.
  - Profile defaults come from the AceDB table, never the schema.
  - Test pins full, absent and delta counts.
- [ ] **§1 [MAY] :68-76** A runtime-completing Schema stub citing the degradation doc, with no per-write logging. Compat guard arm shape.
- [ ] **§2 [MUST] :82-94 Combat.**
  - The `InCombatLockdown` gate lives inside the library's open, with no second ungated path. Route the window and bar links through it.
  - Refuse with the gray line verbatim: "cannot open settings during combat — Blizzard's category-switch is protected".
  - No defer-and-replay of the open; the equip queue is a separate secure write, and the code comments say so.
  - No `SettingsPanel` access in combat (#88).
  - The page lock, tab guard and close are library-owned.
  - Numeric `:GetID()`. The `SetExpanded` walk runs under pcall *(library)*.
  - No host-rolled open, except a combat-gated jump to the addon's own subcategory.
- [ ] **§2 [SHOULD] :88** Setters that rebuild frames are combat-gated: bar toggle, vertical, button rebuild, minimap.
- [ ] **§3 :98-100** [MAY] a Profiles page through AceDBOptions and AceConfigDialog. **Adopt.** [SHOULD] that is the only AceConfig use. [MUST] `skipRestoreAll` vetoes Profiles rows, named once and shared with the stub reset.
- [ ] **§4 [SHOULD] :104** A LoadOnDemand `Outfitter_Options` addon at 5 or more subpanels (H21).
- [ ] **§5 [MUST] :108-151**
  - The parent canvas is the landing page, and the first subcategory is "General".
  - Use `RegisterCanvasLayoutCategory`/`Subcategory`, never `InterfaceOptions_AddCategory`.
  - `CreateOptionsPanel` once, eagerly at PLAYER_LOGIN; the library parks it in combat.
  - `RegisterOptionsPage` at file load. Content is raw AceGUI. Bodies are lazy on first OnShow behind `rendered`.
  - The landing page comes from `BuildLandingPage`: logo, Notes tagline, "Slash Commands" from `NS.Slash:LandingRows()`. The host may add widgets after it (an upstream-credit line). `OutfitterAbout.lua` is replaced.
  - Logo `media/logos/outfitter.logo.tga` at 300. Omit `logoSize`. [SHOULD] power-of-two source. The png sits beside it.
  - No hand header. The Defaults button is an AceGUI Button created lazily: `defaultsButton=true`, `defaultsTooltip`, `ctx.panel.defaultsOnClick`, `EnsureDefaultsButton` at the top of every OnShow (DpsRace `RegisterTabbedPage`).
  - [SHOULD] a button region dump via the console.
- [ ] **§6 [MUST] :155-162** Two-column schema grid from the flow engine. Use `solo` and `skipRender`, never omit a row. `BUTTON_PAIR_REL` 0.492. LSM values come from a deferred closure.
- [ ] **§7 :166-180** [MUST] Heading only on untabbed pages (landing). [MUST] multi-subject tabs carry `subgroup` headings that don't restate the tab or fake a second tab level. [MAY] one unheaded leading master switch. [SHOULD] merge one-row subsections. No heading over an act; purge acts ("Delete all outfits…") go last. [MUST] one heading widget (#71).
- [ ] **§8 [MUST NOT] :184-252** Don't copy LAYOUT or landing constants; read them off the instance. Faces follow the skin.
- [ ] **§9 [MUST] :268-269** Category registration is never gated on a user action. Secure buttons and hooks stay deferred. Load-reachable builds go through `C_Timer.After(0)`.
- [ ] **§10 :275-277** *(library-owned)* Scrollbar, clip-safe edges, `OnSizeChanged`.
- [ ] **§11 [MUST] :283-289** Scalars refresh in place. Hand widgets add pcall'd refreshers that are dropped on release. Structural rebuilds only for the on-screen page; others are marked dirty. No O(N) rebuild (an outfit add must not rebuild every page). Re-render guard cleared on error. Page Defaults refreshes its own page. The global reset runs `afterRestoreAll` before refreshing.
- [ ] **§12 [MUST] :293-329 Reset all settings.**
  - The General Defaults button, `/of resetall` and AceDBOptions Reset Profile are one act: `db:ResetProfile()` on the active profile only. It restores everything the profile holds and never walks the schema.
  - OnProfileReset re-runs migrations, re-seeds and publishes `Ka0s_Outfitter_ProfileChanged`.
  - `skipRestoreAll` vetoes Profiles and profile-resident rows; the walk sweeps only session rows (test mode, console).
  - StaticPopup text, verbatim and localized: "Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected." Yes/No, `timeout=0`, `whileDead`, `hideOnEscape`.
  - [SHOULD] the tooltip names the Profiles equivalence. [MUST] the General Defaults tooltip is `O.ResetAllTooltip(O.KEYBINDS_UNCHANGED)`. [SHOULD] the resetall landing row describes the same act.
  - Outfits live in `db.char` and are not settings (H7).
  - No geometry hook in `afterRestoreAll`. A Reset position row is mandatory.
  - Test: the shipped set survives, the profile list is unchanged, session rows are swept, the message is published, and **`db.char` outfits survive**.
  - Fix the AceDB-fake callback form in the host mock extender, not the kit.
- [ ] **§13 :333-357 Tabs.**
  - [MUST] every page has a tab strip, except Profiles and landing. One tab per `group`. Host tabs via `opts.tabs` (Keybindings, Skin).
  - [SHOULD] two or more lines per tab.
  - Tab labels sentence case with "and"; page names Title Case. The first tab under a rail is "General". Every row has a `group`.
  - [MUST] wrap, never truncate. [SHOULD] at most 8 labels (6 with a rail). Watch the General page: Master controls, Behavior, Tooltips, Skin, Keybindings.
  - Wrap is selection-independent *(library)*. Multi-subject tabs carry subsections.
  - [MAY] a secondary strip in the scroll, not persisted, with no third level.
  - [MAY] a rail for per-instance pages; keep per-outfit editing in the window (H12).
  - No host tab guard. Active tab not persisted. Page Defaults doesn't narrow to the tab, and its tooltip says what it resets. Don't duplicate the library's wrap test.
- [ ] **§14 :363-393** Banner and chrome bind only when a settings page edits one instance of many. With a single outfit bar and per-outfit editing in the window, **N/A**. State that in settings-panel.md.
- [ ] **§15 [MUST] :397-430 Master controls.**
  - The General page's first tab is exactly `Master controls`, with the canonical order composed via `MasterControls`:
    - [Enable Outfitter] [General visibility]
    - [Master scale] [Master opacity]
    - [Lock frame] [Debug console]
    - [Minimap button] [Test mode]
    - [Reset position] [Reset all settings]
  - Not frameless: the frame rows govern the **outfit bar** (scale, opacity, lock, position), stated via `notes` and `resetPositionTooltip`. The docked window isn't positionable.
  - Enable is the addon-wide switch and total stand-down. Distinct from auto-switch, which becomes an `extra` or a Behavior row "Switch outfits automatically".
  - General visibility (Always / Only in combat / Only out of combat / Never) covers the bar (`ShowOutfitBar` and CombatAlpha mapped). Combat opacity becomes a "Faded opacity" row under a Visibility subsection on the bar tab.
  - The debug console row is session-only. The minimap row sits in column 1 at `minimap.shown` over `hide`.
  - Test mode: session-only, default false, shows without unlocking, ends at REGEN_DISABLED, refused in combat, composed via `testModePath`.
  - Resets close the tab. "Reset all settings" has no ellipsis.
  - The host writes no label words except via `notes`, `resetPositionTooltip` and `lockIsPreview` (#106).
  - [MAY] at most two `extra` addon-wide switches, after Test mode, before the resets, with `startsLine` as needed.
  - Anything else as the first tab is #68.
- [ ] **§16 :436-478** Font, border and bar groups are N/A unless added; skin-driven. If the bar gets a background, it is a swatch plus companion only, `<key>FromSkin` default true, composed (#73).
  - [SHOULD] a bar tab "Size and position" with Size, Position and Layer subsections, and a Layout tab.
  - [MUST] canonical labels; the show toggle leads its block.
  - A strata row uses `O.StrataTooltip`.
- [ ] **§17 :482-492** Every color picker gets a "Use class color" companion (default off, player source, falls through to the swatch, never disabled). N/A unless a color row exists.
- [ ] **§18 :496-502** Where order is the setting, use `ReorderList` (outfit or bar order if exposed). No host row chrome, no whole-row drag, uniform heights, categories form drag boundaries, cancel the controller at render start.
- [ ] **§19 :509-511** No regions, scripts or reparents on pooled AceGUI frames without one undoing `OnRelease`. Use namespaced keys `__OutfitterX`. Never override a maker's OnRelease. Build the window on plain pooled frames or Widgets, not AceGUI.
- [ ] **§20 [MUST] :514-534 Keybindings tab.**
  - The last tab of General (order: Master controls, own tabs, Skin, Keybindings).
  - `O.KeybindingsTab({ bindings = NS.BINDINGS })`. No AceGUI Keybinding widget.
  - Labels are the `GetBindingName` globals. Don't replace the intro; [MAY] add one `spec.intro` line.
  - Never keep keys in SV.
  - [SHOULD] General Defaults tooltip ends with `KEYBINDS_UNCHANGED`. The stub answers `KeybindingsTab`, `KeybindRows` and `KEYBINDS_UNCHANGED`.
  - Tests: the strip ends in Keybindings, rows equal `NS.BINDINGS`, labels match the globals, `Kit.keybindThroughTab`, `Kit.assertBindingsXml`.
- [ ] **§21 [MUST] :540-553 Labels.**
  - Sentence case, "and" not "&", units in '(px)'/'(seconds)'/'(%)', X/Y offset and 'Maximum', 'opacity' not 'alpha'.
  - ASCII ' > ' in locations.
  - Instance acts: "New outfit", "Duplicate outfit", "Delete outfit…", "Reset outfit". Delete is last. Apply the same words in window menus.
  - Confirm buttons end in '…'. "Test <thing>". "Copy settings from". No '+'.
  - [SHOULD] rows that Master multiplies say "Multiplied by Master scale on General > Master controls." "Needs <label>." on dependent rows. "Account-wide: shared by every profile." on account-wide rows (the banned list).
- [ ] **§22 :558-561** Selector groups hide via `shownWhen`; hidden isn't disabled. Likely N/A, since script settings live in the window dialog.
- [ ] **§23 :567-582** LSM pickers use `Ka0sMedia_*`. Never vendor SharedMediaWidgets. N/A unless added.

---

## packaging.md (cite bare)

- [ ] **[MUST] :5** `.pkgmeta` at the root, `package-as: Outfitter`, no `externals:`.
- [ ] **[MUST] :40** Every lib vendored under `libs/`.
- [ ] **[MUST] :41** Ignore `docs`, `tests`, `tools`/`_dev` if present, lockfiles, `.luacheckrc`, `.pkgmeta`, `.gitignore`, `.gitattributes`, and `.claude`/`.superpowers` if present at the root. Add the missing `.pkgmeta` and `.gitattributes` lines.
- [ ] **[MUST] :42** Every root dotfile and dot-dir is either ignored or commented "deliberately packaged". **Remove the ignore line for the absent `.github`**; a line for an absent dir asserts something false. Only include entries that exist (`_dev`, `*.bak`).
- [ ] :29-30 Ignore `media/logos/*.png`, `*.jpg` and `media/screenshots`; shipped `.tga`/`.blp` ship. Stop ignoring all of `Media`. Delete the unused `IconButtonHighlight.blp` and `Outfitter-Button-original.blp`. Ignore `CLAUDE.md` and `DEPENDENCIES.md`, as DpsRace does. **Never ignore `Bindings.xml`.**
- [ ] **[MUST NOT] :43** No `enable-toc-creation`.
- [ ] **[MAY] :44** `move-folders` is monorepo-only: N/A.

---

## performance.md (cite `performance-§N`)

The §12 no-combat-path exemption is **not available** (UNIT_AURA, UNIT_HEALTH, REGEN, BAG_UPDATE, OnUpdate, scripts in combat). Full wiring is required.

- [ ] **§1 [MUST] :13-16** Perf comes in the whole folder. One guarded instance in `core/PerfSetup.lua`, before any `local Perf = NS.Perf`. The stub has every member (`on`, Note, Open, Close, slash and ladder members). No shared frames, and don't extend the lib.
- [ ] **§2 [MUST] :64-76** Exactly two shapes: A (`local t0 = Perf.on and debugprofilestop()` … `Perf.Note`) and B (`Open`/`Close`, for 2+ exits). Never B on per-event hot paths: restructure the aura and health handlers to a single exit.
  - `local Perf = NS.Perf` upvalue. B closes on every exit, error paths included. A around the script pcall.
  - The gate is a plain field and the sink dot-callable. No allocation while off (#43). The zero-overhead scenario is the evidence. `debugprofilestop` in read_globals.
- [ ] **§3 [MUST] :91-114** Declare buckets in report order, nesting via `within`. Proposed: `auraEvent`, `unitEvent`, `scriptDispatch` > `scriptRun`, `bagScan`, `equipPass` > `swapCompute`, `barRefresh`, `listRender`, `windowFollow`.
  - Never sum parent and child. [SHOULD] real hot paths only.
  - The suite pins every bucket as reached.
  - Containment through `Perf.Note(key, ms, parentKey)`, with the real parent passed. Correct a wrong `within`, don't delete it.
- [ ] **§4 [MUST] :121-129** `perf` is a COMMANDS row with the cyan tag, never lib-registered. The lib returns lines and the host prints. Bare `perf` prints the phase and opens the panel; [SHOULD] a clickable step panel. [MAY] a decorate hook. Width is session-only. The close mark goes through the wrapper; [SHOULD] delete a close-only hook.
- [ ] **§5 [MUST] :133-136** `## SavedVariables: OutfitterDB, OutfitterPerfDB`, the name in the descriptor, outside AceDB, a bounded ring (10), and a commented luacheck global.
- [ ] **§6 [MUST] :140-148** Suspend is the `perf` hold on the Lifecycle latch shared with disable. Releasing one hold doesn't stand up past another.
  - Inert without a reload: unregister every event (including script contexts) and cancel work. **No auto-swap while suspended.**
  - Replace the unremovable `OutfitterFrame:HookScript("OnUpdate")` with an owned driver frame.
  - Visibility is enforced in the show ladder (bar, window, checkboxes, minimap, button frame), including the CharacterFrame OnShow path.
  - Resume rebuilds from current state (script registrations re-derived, `EquipmentUpdateCount` reset).
  - The flag is never persisted. Resume before saving or reporting. A refused verb prints `Not available during a performance capture.`
- [ ] **§7 :157-161** *(library-driven)* Combat-gated polled windows, no cross-set comparisons, [SHOULD] same target, buckets are the cost, [SHOULD] context.
- [ ] **§8 [MUST] :179-187** Library schema stamped with addon and version. Bundles `docs/perf-analysis/<stamp>/` with report.md, dump.json and ANALYSIS.md.
  - `docs/perf-analysis/README.md`: naming, schema, lib pointer, `/<slash> perf` capture steps, the note that offline runs live in automated-tests, and an index ("None yet").
  - Never report a null frame delta. [SHOULD] investigations. No `docs/perf-runs/`.
- [ ] **§9 [MUST] :197-202** `tests/perf.lua`, outside the gate. No wall-clock asserts; counts and bytes with a full collect. Zero-overhead scenario on `auraEvent` > `scriptDispatch` with capture off. [SHOULD] per-addon scenarios (equip coalescing, bag scan, script event storm) with orientation-only timings.
- [ ] **§10 [MUST] :206-287** Complexity goes to the bundle and RESULTS (not complexity.md), via the runner.
  - A generated header and a `## Watch list` (CCN>15 functions and band files with dispositions, "None." if empty).
  - Don't game the and/or tax. "Accepted" lasts at most three releases. [SHOULD] a short list.
  - Never gate commits on it. Regenerate at every release. Record newly crossed items. [SHOULD] mid-cycle runs. Stale stays visible.
  - Watch lizard blind spots.
- [ ] **§11 [MUST] :296-330** Only four refactor shapes: table dispatch, named helper, data table and loop, split builder.
  - No gaming wrappers, no per-call allocations, no behavior change inside a refactor, never drop a why-comment (secret notes, `disableSecureActions`, five-table zone note).
  - Characterize first. The contract is chat strings, events, SV shape and slash output. The deliberate SV and slash changes are recorded as owner decisions, in separate commits from mechanical splits.
- [ ] **§12 :344-395** Exemption not claimable. No register row.

---

## preview-mode.md (cite bare)

- [ ] **[MUST] :5** Preview renders representative placeholder data: 4-6 sample outfit buttons on the bar ("Tank", "Fishing", "PvP") with real icons.
- [ ] **[SHOULD] :9** Auto-preview while unlocked, and/or a verb.
- [ ] **[MUST] :10** A standalone Test mode, independent of lock, session-only, ending at combat start, refused in combat, as the Master-controls checkbox. The `lockIsPreview` exception doesn't fit (the unlocked bar shows real outfits). Placeholder clicks never reach the equip path and never write SVs.
- [ ] **[MUST] :11-16** A localized on-display text marker, readable without hover, wherever placeholders show. A HUD may go unmarked (:26) but mark the bar anyway (H17). If the window list shows placeholders, it must be marked (TestStrip or title badge).
- [ ] **[SHOULD NOT] :18** Two markers for one mode.
- [ ] **:20-24** Tooltip, checkbox or plausible data are not markers. Placeholder names that say "Test" count. A missing or hover-only marker is #97.
- [ ] **[MUST] :27** The launcher menu's Test mode entry uses the same handler, grayed while disabled.
- [ ] **[SHOULD] :28** Placeholders feed the real bar builder.
- [ ] **[MUST] :29** Off returns to live data. Test mode ends only by its switch, combat or Reset all, never by re-locking.
- [ ] **:30** "Utility addon N/A" does not apply.
- [ ] **[MAY] :34-58 Simulator.** Decline (H18). If shipped: Sim-1.0, every read and action through Compat, the refusal list, no real action or SV writes, guarded equip APIs, exact restore, the step panel as marker, slash-only, and an `Unwrapped()`-empty test.
- [ ] **[MUST] :64-77** At every bump, starting with 1.1.0, re-look at Coverage, Currency (icons valid for 120105) and Fidelity. Record exactly one answer in the release ANALYSIS.md `## Preview and simulation data` with the files reviewed. For 1.1.0: "Refreshed" with commits.

---

## public-api.md (cite bare)

Outfitter has a real public surface: about 25 `Outfitter_*` globals, `Outfitter:Method` used from macros, and the script environment.

- [ ] **[MUST] :7** Version-namespace it: `NS.API = NS.API or {}; NS.API.v1 = {...}`.
- [ ] **[MUST] :8** Publish with `_G[addonName] = NS.API`, so `_G.Outfitter` is the API table only. Legacy globals and macros break (H3).
- [ ] **[MUST] :9** Document the v1 contract as semver-stable in ARCHITECTURE: names, args, returns, outfit-event callback shape, script env.
- [ ] **[SHOULD NOT] :10** Don't break v1 later; add v2 beside it.

---

## savedvariables.md (cite `savedvariables-§N`)

- [ ] **§1 [MUST] :17** One namespace via `AceDB:New("OutfitterDB", NS.defaults, true)`.
  - `profile`: options, bar look, skin pair, enable.
  - `char`: Outfits, categories, LastOutfitStack, LayerIndex, bound-outfit indices, per-outfit script settings, bar position (non-setting).
  - `global`: schemaVersion, minimap, Banned.
- [ ] **§1 [MUST] :18,57-66** `global.schemaVersion = 0` in defaults, never moved. `NS.SCHEMA_VERSION` = the highest step's `to`. Ship `core/Database.lua` with one no-op step `{to=1}`.
  - The runner owns the stamp, which advances only after a clean step.
  - Profile steps reach every stored profile. Char-scoped steps mirror the walk over `sv.char`, with a comment (the standard names only profiles).
- [ ] **§1 [MUST NOT] :68** Never tell user-set from default by key presence.
- [ ] **§1 [MUST] :75-80** The runner runs right after `AceDB:New`, before any read. Compare to the default. Steps are idempotent on a fresh profile. A red-first test covers stamp survival of the logout strip, a raising step holding the stamp, and reaching a non-active profile.
- [ ] **§1 :84** The load pass seeds the outfit registry (categories, special outfits). Name it beside its writer.
- [ ] **§1 [SHOULD] :85** A soft fallback shim when AceDB is missing.
- [ ] **§2 [MUST] :89-90** All defaults in `defaults/Profile.lua`, the only hardcoded place. Schema `default=` references it. Move the scattered defaults (Options init, bar defaults, `cDefaultScriptIcons`, preset setting defaults).
- [ ] **§3 [SHOULD] :94** Per-zone settings trees: N/A (zone outfits are a feature).
- [ ] **§4 [MUST] :100-105** `OutfitterPerfDB` outside AceDB, a bounded ring, stamp owned by Perf. No other top-level globals (`gOutfitter_OutfitToDelete` goes).
- [ ] **§5 [MUST] :121-127** Default with `== nil` wherever falsy is a choice: inverted Disable flags, per-outfit false flags. Comment deliberate empties (empty outfit, empty banned list). No `or`-defaulting during refactors.

---

## skinning.md (cite `skinning-§N`)

Adopted (owner asked for skins), on v1.85.0, so §9 and kit rev 50 bind. The Options stub answers `AppearanceTab`, `AppearanceRows` and `SkinVerb` either way (:54).

- [ ] **§1 [MUST] :11-30**
  - `Skin:RegisterOwner("Outfitter")` at file load in `core/SkinSetup.lua`, with a stub, `get`/`set` through the seam, and `label = "Ka0s Outfitter Reborn"`.
  - Every element paints through `S = Skin:For(owner)` primitives: Shell, Panel, Button, Text, Checkbox, ScrollBar, Tab, CloseButton, EditBox.
  - Surfaces: window, rows, tabs, slot checkboxes, button frame, bar and its settings dialog, icon chooser, script dialog, rebuild/optimize dialogs, menus (LibDropdown replaced by Widgets).
  - Declare `test_skin_values` and `test_skin_switch` with `Kit.skinValues`/`Kit.skinSwitch` facts set before `Kit.run`. A declaration without facts is a skip, not adoption. Delete any legacy `test_skin_literals`.
  - Owner tokens `of.*` (default = today's value, `follow` = nearest role) for every addon color. Never snapped to a library token or given a `text.`/`sem.` name.
  - Other tokens via `opts.tokens` by name. Never repaint after the primitive call.
  - No `opts.stockDefault`. Under Ka0s Default the docked window looks Ka0s, not stock; note it in smoke-tests.
  - Every library factory gets the owner. Settings widgets pass `panel`.
  - Overlays sit on holder children. Singletons repaint on open.
- [ ] **§2 [MUST] :34-40** Source (`ka0s`/`eui`) and skin key in the profile, defaulting to `ka0s`, through the seam. Profile switch, copy and reset call `Skin:SetChoice`. Live repaint and the reload offer are the library's.
- [ ] **§3 [MUST] :44-54** A `Skin` tab (key Appearance) on General, just before Keybindings, using `O.AppearanceTab`/`AppearanceRows`. No hand picker.
  - Defaults: `skin.ignorePanel` on, `ignoreFonts` off, outline `hud`.
  - Overrides reset in `__chooseSkin`, not in the host.
  - First-run `O.SkinPicker` once per profile, with a seen flag.
  - The `skin` verb sits right after `config`.
  - Reset all resets the choice.
- [ ] **§4 :74-80** Never register or patch a skin.
  - Meaning colors come from semantic tokens: item quality via `q.*` or `GetItemQualityColor`.
  - Fonts and art by LSM key.
  - Geometry and the addon's fixed text widths are skin-invariant. HUD text via `S.HudFontSize`.
- [ ] **§5 [MUST] :88-91** `EllesmereUI` in OptionalDeps. Use `GetEUIStatus`, never read EUIDB. Fail closed *(library)*.
- [ ] **§6 [MUST] :95-105** The outfit bar is a HUD.
  - Style values resolve via `S.Resolve` with `FROM_SKIN`.
  - Every HUD color has a `<key>FromSkin` row defaulting true. Draw via `S.HudTextColor`, `BarFillColor`, `Color`, `GlowColor`, `HudFont`, `BarBorder`. Class and meaning colors take precedence and get no companion. Font flags default "From skin". Ignore-fonts keeps the HUD face.
  - Wire `Skin.FollowOnce(profile, keys)` from Database init and OnProfileChanged even on a fresh store, and test it with the library absent.
  - Record the HUD classification in ARCHITECTURE.
- [ ] **§7 [MUST] :110-122** Never restyle a Blizzard shared frame: CharacterFrame, PaperDoll slots, GameTooltip (lines added to it may take skin colors), StaticPopup, ColorPicker, SettingsPanel.
  - No taint: no Hide, SetParent, SetScript or SetBackdrop on Blizzard frames, and nothing written into their tables. Parent the checkboxes to an Outfitter holder and anchor them.
  - No AceGUI pool leak (`PaintAce`/`OnRelease`).
  - Don't diverge on edge, close mark, TestStrip, header or console colors.
- [ ] **§9 [MUST] :132-142** Every color, texture, border, face, shadow and gloss comes from a primitive or token. A typed literal needs a kit category or a `Kit.skinValues.rows` entry `{file, substring, why, cause}`; stale rows fail. XML attributes count too.
  - Allowed: meaning colors, game art (item and spell icons, logo, minimap ring), Leave classes, chat (script output).
  - The panel stays stock by default but supports skins. Never write the ignore flags beyond the library defaults.
  - `Kit.skinSwitch.surfaces` declares every surface, run with Scope cleared and companions on, then off.

---

## slash-commands.md (cite `slash-commands-§N`)

- [ ] **§1 [MUST] :11-34**
  - No hand dispatcher: delete `ExecuteCommand`. Vendor the whole folder.
  - Exactly one dispatcher in `settings/Slash.lua`: `LibStub("LibKa0s-Slash-1.0", true):New(descriptor)` after `NS.COMMANDS`, with a forward-declared `cli`.
  - Register through AceConsole `RegisterChatCommand`. No `SLASH_*`.
  - Degrade when absent. The stub has OnSlash, PrintHelp, LandingRows, SetRowAnnotator and the Cli* members. A refused composed write prints `L["%s is unavailable: the LibKa0s library did not load."]`. No rendering, parser or `key = value` copies; degraded rows print `cmd  desc`.
  - [MAY] exactly one verbatim `DISABLED_LINE_FORMAT`, pinned with `Kit.assertLibraryConstant`. Minimal stub routing is OK.
- [ ] **§2 [MUST] :38-49**
  - 2-3 letter primary verb, [SHOULD] with the full name as an alias via `slashAliases`. No collisions (H5).
  - Reserved verbs keep their meaning: help, get, set, list, reset, resetall, config, version, debug, enable, disable, perf, diagnostics, skin, lock/unlock.
    - `enable`/`disable` become the addon-wide switch on the Master path. Auto-changes move to a sub-tree (`/of auto enable|disable`) and a schema row.
    - `reset` is path-shaped (`reset bar.position`). Wiping all outfits becomes a separate confirmed verb.
    - `sound`, `errors` and `daxdax` become schema rows.
  - `perf` is host-registered (wired). `diagnostics` always, no alias. `skin` directly after `config`, no argument, combat refusal, disabled refusal, not in `liveVerbs`, no alias, never hand-built.
  - enable/disable write the stored path through the seam. No `NS.enabled`. [SHOULD] confirm in the `set` shape. No top-level reuse.
  - The dispatcher survives disable.
  - [SHOULD] feature verbs refuse while disabled (wear, unwear, toggle, deposit*, withdraw*, update, missing, summary, rating, unequip). Decide live vs feature for zone, iteminfo and itemstats and list live ones in `liveVerbs`. Never refuse help, config, version, enable, disable, debug, diagnostics, perf, get, set, list, reset or resetall. Copy DpsRace's `feature()` wrapper.
  - [MAY] legacy aliases (`options` > `config`).
- [ ] **§3 [MUST] :55-120**
  - Host-owned `NS.COMMANDS` of positional triples `{name, desc, handler}` (the named-field shape is forbidden).
  - `rest` keeps case and spacing (outfit names).
  - `runDebug` tests diagnostics first.
  - The descriptor carries slash, aliases, commands, print, version, get, set, findRow, applyDefault, allRows, groupKey. set and applyDefault go through the seam. allRows in panel order (settings only, not outfits).
  - Bare slash opens settings. `help` prints the index. Opening the window uses `show`.
  - `version` prints `<tag> v<version>`.
  - Only the verb is lower-cased. Unknown verbs print `unknown command '<verb>'` plus help. No if-chains.
  - Macro conditionals (H25).
- [ ] **§4 [MUST] :126-137**
  - Every line carries the cyan tag `|cff00ffff[XY]|r` from `NS.PREFIX` (initials, H5).
  - Secret-safe printer from the Core factory, passed as `print`, guarded against the AceConsole mixin. NoteMessage and ErrorMessage route through it.
  - Help and landing use the library formatter. Header: `<tag> v<ver> — slash commands (/outfitter is an alias for /of)`. Generated from COMMANDS.
  - No chat line ends in ':' (sweep the summary, missing and zone outputs).
- [ ] **§5 :149-183** Library list, get, set and reset shapes with mandatory colors. One line per action, with the echo after clamping. Type-aware formatting; empty shows as `(none)`. Don't wrap the formatters. `Setting not found: <path>` and `Usage:` lines. [SHOULD] a host annotator (never on reset).
- [ ] **§6 [MUST NOT] :187-194** No re-implemented parsing (drop the hand on/off parsers). [MAY] a descriptor `parse` for exotic types.
- [ ] **§7 [MUST] :208-334 Total disabled state.**
  - Every owned frame is hidden via the show ladder, including the CharacterFrame OnShow re-show.
  - Every event, message and bucket is unregistered (script contexts included; unit frames kept, not destroyed).
  - Settings refresh is recorded only.
  - `hooksecurefunc` bodies gate themselves (pet journal, tooltip, compare). Raw hooks are un-hooked.
  - Every timer, ticker and OnUpdate is canceled.
  - No SV writes from events.
  - In combat, hold the stand-down and finish it at REGEN_ENABLED (the one kept registration, released when it fires).
  - Survives: chat command, dispatcher, COMMANDS, settings category and body, AceDB with seam and profile callbacks (which re-evaluate enabled), launcher registration. The slash surface is otherwise unchanged.
  - Launcher while disabled: left opens settings; menu grayed except Enabled; no SV writes except Enabled; binding presses refuse through the helper.
  - Refusal line exactly: `<NS.PREFIX> Ka0s Outfitter Reborn is disabled — enable it with |cFFFFFF00/of enable|r`. The brand equals the LDB label.
  - Under the perf hold alone, `<PREFIX> Not available during a performance capture.` When both holds are taken, the disabled line wins. One helper for every refusal site.
  - Two holds on the LibKa0s-Lifecycle latch, the same seam as perf. Always release and re-evaluate, never a bare StandUp. perf is session-only, disabled persisted. Stand-up rebuilds from current state.
  - `tests/test_disabled.lua` in SUITES with the ten steps and `-- red under:` comments on steps 3, 6 and 10. Seed an active preset script so `R_on` includes script events. Step 6 catches equipment-changed SV writes. Kit-rev trap: call method-named handlers directly.
  - LibKa0s ≥1.42 (v1.85 OK).
- [ ] **§8 [MAY] :340-355** lock/unlock for the bar lock, writing the Lock frame path through the seam. Feature verbs, [SHOULD] confirm. Top-level only while exactly one lockable frame exists. Declining needs no row. Never invent a lock.

---

## standalone-windows.md (cite bare)

Scope: the docked `OutfitterFrame`, the name and rebuild dialogs, the script editor, the icon chooser and the About window if kept. The bar and QuickSlots are displays.

- [ ] **[MUST] :7** Plain non-secure frame, movable/resizable, not a Settings canvas, not secure. Secure list-row children are content, under events-frames-taint-§2; document the combat behavior. The docked window isn't movable or resizable (H4).
- [ ] **[MUST] :8** `UISpecialFrames` for the window and every dialog. Verify the Escape ordering against CharacterFrame in the client.
- [ ] **[MUST] :9** `SetToplevel(true)` in the window tier, and popups close with the window. The docked window is host-matched and not toplevel (H4). Dialogs are DIALOG and close when the window or sheet closes.
- [ ] **[MUST] :10** Persist position and size (dialogs, bar, QuickSlots via named non-setting writers). [SHOULD] clamp and `SetClampedToScreen`. The docked window is covered by the H4 row.
- [ ] **[SHOULD] :11** A scale setting. The docked window inherits the sheet's scale; comment it.
- [ ] **[SHOULD] :12** Tabs built lazily. Options and About leave the window; the list stays.
- [ ] **[MUST] :13** The look comes from the Skin facade, owner `"Outfitter"`. No shipped chrome art or lookalike. Never skin CharacterFrame. The checkboxes are Outfitter controls and get skinned. Library marks and the logo are sanctioned; private copies are flagged.
- [ ] **[MUST NOT] :15-29 Edge.**
  - Ka0s Default: bg WHITE8x8 0.06/0.06/0.08/0.92, 1px black outer, 1px inner 0.24/0.24/0.27/0.85, gold title 1/0.82/0, divider 0.24/0.24/0.27/0.85, two lines.
  - [SHOULD] `ApplySkin` draws it, with `frame.title` and `frame.divider` set first. A host helper must produce the exact values. [MAY] an `applySkin` hook.
- [ ] **[MUST] :30-39** Close via `NS.MakeCloseButton` (18×18 catalog close) in `core/CoreSetup.lua`. Replace `UIPanelCloseButton` and the dialog closes. The grep returns only the wrapper and callers. A decline needs all four conditions (not recommended).
- [ ] **[MUST] :40** A title-bar strip uses catalog marks at one size and pitch. [SHOULD] keep a fallback ladder.
- [ ] **[SHOULD] :41** Wide buttons keep their label and gain a mark beside it ("New outfit…", "Update", "Edit script").
- [ ] **[SHOULD/MAY] :42-48** `Widgets.TestStrip` for test mode in the window, if placeholders show there. Amber for test, cyan for sim. No mode word in the header while a strip shows.
- [ ] **:49-50** A library window keeps the library close. Edge values change only in the standard.
- [ ] **[MUST] :51** Pooled rows for the outfit list and icon grid (Pool or ScrollBox). Secure rows acquire outside combat.
- [ ] **[SHOULD] :52** show, hide and toggle verbs. Bare slash opens settings. The launcher's Show window shares the handler.
- [ ] **:54-69 Resizing.** N/A if nothing is resizable; say so in ARCHITECTURE. If the script editor is made resizable:
  - cheap layout only while sizing;
  - one pass per frame;
  - full redraw and one size write at the end, with one debug line;
  - numbers from size and constants, never measured children;
  - [SHOULD] one shared helper (DpsRace `modules/Sizing.lua`);
  - a falsifiable drag-spy test plus a smoke check.

---

## testing.md (cite `testing-§N`)

- [ ] **§1 [MUST] :11-39**
  - No hand-rolled registry, assertions, loader or base mock. Replace `framework.lua`, `loader.lua`, `run-all.sh` and `test_eol.lua`, and port the suites.
  - Vendor the whole testkit to `tests/_kit/` (never `libs/`) and never edit it.
  - Rule-subject suite names.
  - `tests/run.lua` keeps only addon content: kit dofiles, libs then TOC files, lifecycle kick (ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD), `Kit.expose` (`OUTFITTER_TEST`), `Kit.run`.
  - `wow_mock.lua` is a thin extender of `mock_base` (C_Container, inventory and equip APIs, `C_EquipmentSet`, `SecureCmdOptionParse`, instance and map info, CharacterFrame and slots, bank, `C_PetJournal`). `client_events.lua` shrinks or splits.
  - Five fidelity rules: no silent stubs where code branches, real values, record what tests observe, fire what tests drive, model awkward behavior.
  - Registration is not execution. `--list` is a pure filter.
  - Gates enumerate from the tree (the zone-table check derives from the tables).
- [ ] **§2-3 :43-60** `lua tests/run.lua` exits non-zero on failure. `luacheck .` at 0. `luac -p`. Lua 5.1. [SHOULD NOT] LuaFileSystem.
- [ ] **§4 [MUST] :64-67** Test-first. Green and lint-clean before every commit (`--suite lint --suite tests --no-bundle`), never the full bundle. A suite with every behavior change. Pure logic headless: matching, equip planning, optimizer, stats, presets, zone ids, schema, formatting.
- [ ] **§5 [MUST] :72-89** Generated `docs/test-cases.md`. A static README badge regenerated in the same change. Skips shown with reasons, never counted.
- [ ] **§6 [MUST] :101-115** `docs/testing.md` with a gate table naming both checkpoints per suite.
- [ ] **§7 :126-134** `tests/perf.lua` outside the gate. No wall-clock. Not counted. Its load list obeys §9.
- [ ] **§8 [MUST] :142-200** Don't duplicate library tests.
  - One integration suite per adopted module: descriptor, buckets reached, suspend and resume, degraded path via a partial load, never a hand stub.
  - `tests/test_surface_parity.lua`: one case per module, members from a named grep in a comment, both arms, present-but-nil is a divergence, [SHOULD] all divergences in one message.
- [ ] **§9 [MUST] :212-312**
  - `Loader.tocFiles("Outfitter.toc")`, which skips only `libs\`, so the rename is required.
  - Vendored files listed explicitly in XML order.
  - Pin the derivation (equal, exists, no libs leak); pin `perf.lua` by source.
  - Pin the suite list both ways with distinct messages.
  - Kit suites as `{name, dir="tests/_kit/"}`. A same-basename local suite is a collision. Unreferenced kit suites fail unless declined. Wire test_eol, test_prose, test_lizard_sighted, test_layout_cap, test_skin_switch, test_skin_values, test_diagnostics_contract and whatever else the kit ships.
  - `loadSuites` raises on absent files. Use `pending` for work in progress.
- [ ] **§10** N/A (no LibStub minors are published). State it in ARCHITECTURE.
- [ ] **§11 [MUST] :415-500** `tests/test_vendor_sync.lua` delegating to the kit, ref read from the CLAUDE.md provenance line, blob vs worktree stripping only CR (reasoning in the header), icon subset from the `LibKa0s icons:` grammar, pruned with `tools/prune-icons.lua`, README credits in step. An absent sibling is a visible skip. The 100755 assert.
- [ ] **§12 [MUST] :506-511** Verify negatives by mutation (restore from a `cp` backup). Check what was raised. Don't build the object under test in the test. [SHOULD] `-- red under:` comments.
- [ ] **§13 [MUST] :537-553** Characterize before refactoring, on the old code: equip plans, slot masks, categories and stacking, preset triggers and the five zone tables, optimizer picks, bank plans, command outputs, macro conditionals, the `|h` bypass. Pin returns, chat lines and side-effect order.
  - Don't weaken tests; replace a test of a removed API with a behavior-equivalent one in the same change, and say so.
  - [SHOULD] keep characterizations. Extract pure logic from popups and layout.
  - Record the no-migration decision so §13 doesn't read as a gap.
- [ ] **§14 [MUST] :567-635** Measure before optimizing (wall, CPU, dominant count; [SHOULD] in RESULTS). No re-parse, no per-item spawns; [SHOULD] slice batched replies. Exhaust both before `--jobs`. [SHOULD] `auto` above about 10 s, with serial and parallel verified to agree. Order dependence is a bug. Parallel rules. The WSL 9p cost applies.
- [ ] **§15 [MUST] :650-725** Kit-bounded runs; never `KA0S_KIT_GUARD=off`. Per-case budgets (raising one needs a row). No work at load. No host paths (`/mnt/d`). No scratch under `tests/`. Releasable instances (no weak caches). `--jobs auto` memory-capped.

---

## toc-file.md (cite `toc-file-§N`)

- [ ] **§1 [MUST] :7-48** Exact metadata order, no blank lines: Interface, Title, Notes, Author, Version, IconTexture, SavedVariables, OptionalDeps, DefaultState, Category-enUS, X-License, X-Standard, X-Curse-Project-ID (X-Wago-ID and X-WoWI-ID only if listed; check WoWI). Rewrite from DpsRace `DpsRace.toc:1-13`.
  - `## Title: Ka0s Outfitter Reborn`.
  - `## Author: add1kted2ka0s` (mundocani's credit moves to the README and LICENSE).
  - `## Version: 1.1.0` (H3).
  - `## IconTexture: Interface\AddOns\Outfitter\media\logos\outfitter.logo.128.tga`.
  - `## OptionalDeps: Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0, EllesmereUI, Pawn, WeightsWatcher`.
  - `## DefaultState: enabled`.
  - Category-enUS checked against the client (e.g. "Inventory").
  - `## X-License: MIT`.
  - `## X-Standard: https://github.com/tusharsaxena/WowAddonStandards`.
  - `## X-Curse-Project-ID: 1698220`, unchanged.
  - [SHOULD NOT] hard Dependencies; drop the empty `RequiredDeps`.
  - `AddonCompartmentFunc` and `X-ReloadTag` have no slot (H20).
- [ ] **§2 [MUST] :52-55** `## SavedVariables: OutfitterDB, OutfitterPerfDB`. Never three globals. The `gOutfitter_*` lines are dropped (fresh store). [SHOULD NOT] PerCharacter: use AceDB `char`. `schemaVersion = 0` plus the `core/Database.lua` runner.
- [ ] **§3 [MUST] :61-65** One TOC, one Interface (120105). No flavor lists, per-flavor TOCs or `enable-toc-creation`. No `WOW_PROJECT_ID`. The README `[wow]` badge matches, bumped in the same commit.
- [ ] **§4 [MUST] :69-71** Dependency order. Never list `Bindings.xml`. Every lib listed directly (`.lua` or the lib's own `.xml`). No addon-authored aggregate. One `libs\LibKa0s\LibKa0s.xml` after Ace3. Frame XML, if any survives, goes in its module's section, but prefer Lua.
- [ ] **§5 [MUST] :75-172** One blank line after the metadata. `#` headers in order Libraries, Locales, Core, Defaults, Modules, Settings (Settings last). Exactly one trailing newline.
  - A reason comment above any unusual order.
  - Every load-bearing line carries a comment, kind (a) "resolves at load" or (b) "ordered table / handler first". Outfitter risks: several handlers on equipment, bag, aura and zone events; scripts vs the inventory cache on BAG_UPDATE; schema rows appended across settings files. Expect about 40 notes, as in DpsRace.
  - [SHOULD] conventional groups say so once per file (graded per file).
  - Read the comment before moving a line.

---

## versioning-git.md (cite bare)

- [ ] **[MUST] :5** semver, with MAJOR for incompatible API **or SV** changes. The fresh store and the API break make this 2.0.0 by rule; the owner chose 1.1.0 (H3).
- [ ] **[MUST] :6** The bump touches the TOC, code fallback constants, the README badge and the bulleted Version History, via `dev-copilot:bump-version`.
- [ ] **[MUST] :7** At the bump, re-look at test-mode data and record it in the release ANALYSIS.md.
- [ ] **[MUST] :8** Interface and `[wow]` bumps go through `dev-copilot:wow-bump-interface`.
- [ ] **[MUST] :9** Raise `NS.SCHEMA_VERSION` with every migration step; the default stays 0.
- [ ] **[MUST NOT] :10** Don't conflate lib minors. Re-vendor commits stand alone ([SHOULD]) and carry the CLAUDE.md provenance and icons lines and a revendor bundle.
- [ ] **[MUST] :14** Owner-directed branch named `feat/<date>-<topic>` (compliant). Merge with `--no-ff`, then delete branches, worktrees and stashes. The WowAddonStandards ADDONS.md edit uses the same branch name there.
- [ ] **[MUST NOT] :15** Push only when asked (milestone pushes are authorized). Never merge, tag or release without the owner's go-ahead.
- [ ] **[MUST] :16** Commit only on green. Plan commit-sized units that keep the tree green: eol renormalize, then scaffold, vendor, core, then each module with its tests.

---

## Hard calls for Outfitter

Each entry gives the rule or rules, the conflict, and a recommendation. **Ask the owner** marks the ones that are worth one upfront question, because they can't be undone quietly. The rest can be decided and recorded.

- **H1. User-authored Lua scripts.** anti-patterns #20, events-frames-taint-§1/§8, localization-§4, public-api, preview-mode. **Ask the owner.**
  - #20 bans user-supplied Lua at the standard level. Auto-switching runs on `loadstring` of presets and free-form scripts.
  - **Recommendation:**
    - Re-implement every preset as a native trigger descriptor (event list, condition function, typed `$SETTING` parameters as schema-driven fields). Presets keep working, with no `loadstring`.
    - Drop the free-form "Custom" script editor. The fresh store already discards existing custom scripts.
    - Record it in scope.md, the FAQ and the Version History.
  - Fallback if the owner insists on keeping custom scripts: a sandboxed `setfenv` env (API table, tagged `print`, secret-guarded accessors), plus a deviation row `| anti-patterns | Custom outfit scripts still compiled via loadstring in a sandbox | core feature since 2006; owner ruling | 2026-11-03 | owner retires custom scripts or the standard permits sandboxed conditions |`. Expect an audit argument.
- **H2. Title vs folder.** layout-§2. "Ka0s Outfitter Reborn" implies `OutfitterReborn`; the folder stays `Outfitter` (CurseForge `package-as`, installed path, LDB and LibDBIcon keys).
  - **Recommendation:** a deviation row citing layout-§2, with re-check trigger "a decision to rename the package". The alternative (Title "Ka0s Outfitter", with "Reborn" in Notes) is the owner's to choose.
  - The brand string "Ka0s Outfitter Reborn" is then used for the LDB label, the refusal line, the binding header and the diagnostics markers.
- **H3. semver and the public-API break.** versioning-git :5, public-api :8, anti-patterns #1. **Ask the owner.**
  - The fresh store drops every outfit, and `_G.Outfitter` becomes the `API` table, which breaks the `Outfitter_*` globals, `/run Outfitter:…` macros and third-party callers. By rule that is 2.0.0.
  - **Recommendation:** ask once whether to ship 2.0.0. If the owner keeps 1.1.0, add a deviation row citing versioning-git (owner ruling, trigger "next MAJOR").
  - Make a clean API break: publish `NS.API.v1` (WearOutfit, RemoveOutfit, FindOutfitByName, GetCurrentOutfitInfo, outfit-event callback) and document it in ARCHITECTURE.
  - No legacy-global shim. If one is wanted, `modules/LegacyApi.lua` as a deviation row with trigger "remove at 2.0.0".
- **H4. The docked main window.** standalone-windows :7,:9,:10, frame-layering-§1/§4, skinning-§7.
  - It isn't movable or resizable, has no saved geometry, and must not be toplevel, because that would lift it over its host.
  - **Recommendation:**
    - One deviation row citing standalone-windows (frame-layering-§4 noted in Why): "OutfitterFrame is a host-matched surface docked to CharacterFrame; no player geometry, not toplevel; strata copied from the host, level host+`LAYERS.LEVEL.HOST_OVER`", with trigger "an undocked/movable mode is added".
    - Keep the re-sync on every raise, with the level writes queued in combat.
    - Skin only Outfitter's own frames, and list them in smoke-tests.md.
    - Escape through `UISpecialFrames` still applies.
- **H5. Slash verb, alias and chat tag.** slash-commands-§2/§4, naming-cheatsheet :20.
  - **Recommendation:** primary `/of`, with `/outfitter` as the registered alias so existing macros keep working. Check `/of` for collisions first; fall back to `/ofr`.
  - Tag `[OR]` (Outfitter Reborn), matching DpsRace's brand-initials `[DR]`.
  - Verbs:
    - `enable`/`disable` become the addon switch.
    - Auto-switching moves to `/of auto enable|disable` and a schema row.
    - `reset bar` becomes `reset bar.position`.
    - Old `reset` (wipe outfits) becomes `/of deleteall` with a confirmation popup, labeled "Delete all outfits…".
    - `sound`, `errors` and `daxdax` become schema rows.
    - `/unequip` becomes `/of unequip`. Optionally keep a bare `/unequip` through AceConsole and routed via OnSlash, with a deviation row. Recommend dropping it.
- **H6. Launcher semantics vs the outfit quick-switch menu.** launcher-§1/§2, anti-patterns #81/#89, preview-mode :27.
  - Left-click must open settings, the right-click menu is the library's, and the broker icon and text are static. Today the minimap left-click opens an outfit menu, and the icon and text follow the worn outfit.
  - **Recommendation:**
    - Comply fully.
    - Rehome quick switching to the outfit bar, the window, `/of wear name`, and the wear-outfit bindings.
    - Show "Current outfit: X" as an `onTooltipShow` host line.
    - Delete `OutfitterMinimapButton.lua` and `LibWithFreeDragDBIcon`.
    - Call out the change in the Version History.
  - No deviation.
- **H7. Outfits in `db.char` vs Reset all settings.** options-ui-§12 (:298,:323), architecture-§5, savedvariables-§1.
  - **Recommendation:** outfits are per-character inventory data, not profile content, because a shared profile can't hold another character's items. Reset all settings leaves them intact.
  - "Delete all outfits…" is a separate confirmed act, last on its tab with no heading.
  - Document the reasoning in ARCHITECTURE (Settings Schema), schema.md and profiles.md, and pin it with a reset test that proves `db.char` survives.
  - Add a deviation row only if an audit reads :298 otherwise.
- **H8. Translations.** localization-§3/§7.
  - Routed needs all 339 keys re-keyed, and translated CJK strings in a Latin skin face may draw boxes. English-only needs a deviation row and throws away community work.
  - **Recommendation:** Routed. Re-key de, fr, cn, tw, kr and ru mechanically, gated by early returns. Untranslated new strings fall back to English.
  - Check whether the skin facade falls back to the client locale font for zhCN, zhTW, koKR and ruRU. If not, add a localization-§7 deviation row for CJK and Cyrillic painted in skin faces, with trigger "the skin library ships locale font fallback". Confirm in the client.
- **H9. Subzone matching.** localization-§4. Minimap subzones have no ID API.
  - **Recommendation:** match zones on uiMapID or instanceID. Keep subzone matching on `GetMinimapZoneText()`, captured on the player's own client, under a localization-§4 deviation row with trigger "Blizzard exposes the current areaID".
  - Professions move to skillLine ids, buffs to spellID lists, stats to `GetItemStats` tokens. Drop LibBabble. Each change gets a characterization test.
- **H10. Standard defect, `UnitFactionGroup`.** localization-§4 table (:89). The table says the token is the second return; for `UnitFactionGroup` the first return is the English token.
  - **Recommendation:** keep the first return, comment that it's the token, and raise it upstream as an open-evolutions note. No deviation row, because the code is correct.
- **H11. Bindings reshape.** layout-§1, launcher-§6, options-ui-§20, anti-patterns #96/#98.
  - **Recommendation:** all 14 bindings become CLICK on permanent hidden buttons, with `OutfitterToggleWindow` first. Category `BINDING_HEADER_OUTFITTER`, no header attribute, no defaults.
  - Players lose their old key assignments; consistent with the fresh start, and said in the release notes.
  - "Toggle window" opens the character sheet with Outfitter shown. Verify the combat behavior in the client.
- **H12. Per-outfit editing location.** options-ui-§13/§14.
  - **Recommendation:** keep per-outfit settings (trigger, its parameters, bar visibility, icon, binding slot, unequip others) in the docked window and its dialogs. The settings panel then needs no instance picker, and §14 is N/A.
- **H13. Per-outfit trigger parameters as a dynamic schema.** architecture-§5.
  - **Recommendation:** trigger descriptors declare typed parameters, and the dialog writes them through `NS.Schema:Set` with an instance path (`outfits.<id>.trigger.<key>`), validated against the descriptor. Add a deviation row only if instance rows can't be expressed.
- **H14. Event-name translation for triggers.** events-frames-taint-§1, architecture-§4.
  - **Recommendation:** each trigger or context gets its own AceEvent target. Game events go through SafeRegisterEvent, with rejected names surfaced. Pseudo-events (TIMER, zone special ids, OUTFIT_*) map to `NS.MSG` constants through one Catalog-backed table, and TIMER runs on AceTimer.
  - Document it as translation onto AceEvent, not a dispatcher. Deviation row only if an audit rules otherwise.
- **H15. Library pruning and item stats.** library-stack-§3/§5/§7, anti-patterns #37/#47.
  - **Recommendation:** delete the MC2* libs, LibBabble, LibTipHooker, LibDropdown, UTF8 (unless reached), LibButtonFacade and the DBIcon fork.
  - Absorb stat logic into `modules/ItemStats.lua` on `C_Item.GetItemStats` and GlobalStrings. Item links go through LibKa0s-Item. Tooltip lines go through `TooltipDataProcessor`. Menus use LibKa0s-Widgets or `MenuUtil`.
  - Check the Optimize feature against the survival list.
- **H16. Optional integrations.** library-stack-§6.
  - **Recommendation:** keep Pawn and WeightsWatcher stat sources: listed in OptionalDeps, guarded with `IsAddOnLoaded` plus an `ADDON_LOADED` re-check, with a built-in fallback.
  - TankPoints and the rest of Deprecated.lua are deleted (scope.md, FAQ). This reverses the CLAUDE.md Deprecated-layer convention, and `tests/test_deprecated.lua` goes.
- **H17. Test mode scope and marker.** preview-mode :10-29, options-ui-§15, anti-patterns #80/#97.
  - **Recommendation:** test mode fills the outfit bar with placeholder outfits (real icons, names such as "Test Outfit 1") and draws a small localized "Test mode" label on the bar. That is always compliant and settles the HUD-vs-window question.
  - The window keeps real data and so owes no marker.
  - Placeholders never reach the equip path or write SVs. Test mode ends at combat start and is refused in combat.
  - Record "Refreshed" in the 1.1.0 ANALYSIS.md.
- **H18. Simulator.** preview-mode (MAY), library-stack-§7, compat :19.
  - **Recommendation:** decline. The engine's output is equipping the real player, and a simulator would need every bag and equip read behind Compat. Record the decline in ARCHITECTURE and scope.md. No row needed (it's a MAY).
- **H19. 1500-line cap and zero CCN>15 at the tag.** layout-§1, automated-tests-§3, performance-§10/§11.
  - **Recommendation:** split everything well under 1000 lines. Presets and zone tables go to `defaults/` data files. `tests/client_events.lua` is split.
  - Decompose the high-CCN engines with the four sanctioned shapes and no gaming helpers.
  - Write the census as "Nothing is over the cap today". There is no deviation path for the release gate; budget for it.
- **H20. TOC extras.** toc-file-§1, launcher-§1.
  - **Recommendation:** drop `X-ReloadTag` (only the moot reload check reads it) and `AddonCompartmentFunc`. If LibDBIcon or the Launcher registers the compartment entry from the same object, use that. Otherwise no compartment entry, which avoids a third click route and a global.
- **H21. LoadOnDemand options.** options-ui-§4 (SHOULD), with about five pages (General, Automation, Outfit Bar, Tooltips and Display, Profiles).
  - **Recommendation:** don't split. Put a SHOULD-deviation comment in `settings/OptionsSetup.lua` explaining that the options code is small and DpsRace precedent, plus a register row for audit clarity.
- **H22. README screenshots.** documentation-§1 (MUST once published).
  - **Recommendation:** capture the reskinned docked window and the settings pages in the client after the smoke test. Until then, a temporary documented-deviation row with trigger "first client capture of 1.1.0" rather than stale shots. Use absolute image URLs.
- **H23. LibKa0s icons declaration.** library-stack-§7, documentation-§2.
  - **Recommendation:** list names, not `all`. The icon chooser picks game macro icons, not catalog icons. Start from `close, copy, clear, settings, lock, unlock` (plus `info` if an IdList uses the default help mark), and finalize by grepping `NS.Icon(` calls. Credit Open Iconic, and Phosphor or Game-icons if their marks ship.
- **H24. Initial LibKa0s vendoring as a re-vendor commit.** audit-review-history, versioning-git :10.
  - **Recommendation:** treat it as one. Write `docs/revendor/2026-11-03-v1.85.0/` (01_DELTA, 05_SUMMARY) in the same shape as `/dev-copilot:wow-revendor-libka0s`, in a stand-alone commit that also carries the CLAUDE.md provenance and icons lines. That starts the store's horizon.
- **H25. Macro conditionals.** slash-commands-§3.
  - **Recommendation:** the `RegisterChatCommand` wrapper runs `SecureCmdOptionParse` only when the message starts with `[` or contains `;`. It skips this when the message holds `|h`, and a nil result is a silent no-op. Then it calls `Sl:OnSlash`.
  - Document it in slash-dispatch.md as host routing, not a dispatcher fork. Test the bypass and the nil case.
- **H26. Total disable vs Outfitter's hooks and dynamic events.** slash-commands-§7, performance-§6, anti-patterns #85.
  - **Recommendation:**
    - One Lifecycle latch.
    - Replace the `OutfitterFrame` OnUpdate hook with an owned driver frame.
    - Gate the bodies of the tooltip and pet-journal `hooksecurefunc` hooks.
    - Check the latch in the CharacterFrame OnShow show ladder.
    - Enumerate trigger registrations through per-target `UnregisterAllEvents` (optionally LibKa0s-Bus StandDown).
    - Reset `EquipmentUpdateCount` and in-flight swap state on stand-down and resume.
    - `test_disabled` seeds an active trigger.
- **H27. Line endings first.** line-endings-§6.
  - **Recommendation:** the first commit of the conversion is `.gitattributes` (DpsRace's body, verbatim) plus the renormalization alone, before any rewrite, so later diffs stay reviewable. Retire the mixed-endings gotcha.
- **H28. Root docs and source art.** documentation preamble, layout-§3, packaging.
  - **Recommendation:**
    - Delete `CHANGES.txt` (Version History covers it).
    - Fold `UsersManual.md` into README Usage and FAQ plus a Tier 3 `docs/users-manual.md`.
    - Move the logos into `media/logos/` and the screenshots into the ignored `media/screenshots/`.
    - Delete unused and catalog-duplicated textures, and keep only Outfitter-specific art under `media/textures/`.
- **H29. Cross-repo roster entry.** STANDARDS.md:5, launcher-§2 :65.
  - **Recommendation:** add Outfitter to `WowAddonStandards/standards/ADDONS.md` on a same-named branch `feat/2026-11-03-ka0s-conversion`. Merge only with the owner's go-ahead, alongside the Outfitter merge.
- **H30. AceDB profile default.** savedvariables-§1, skinning-§2.
  - **Recommendation:** `AceDB:New("OutfitterDB", defaults, true)` (a shared "Default" profile), with the Profiles page so players can split per character. Outfits are in `char`, so they are per-character regardless. Say so in profiles.md.
