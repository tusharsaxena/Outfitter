# 01 — Current state: Ka0s Outfitter Reborn 1.1.0

Standards audit, run 2026-11-04, `/dev-copilot:wow-standards-audit`. Read-only: this bundle changes
no addon code.

## What was measured, and against what

| Item | Value |
|---|---|
| Repository | `/mnt/d/Profile/Users/Tushar/Documents/GIT/Outfitter` (checkout directory still named `Outfitter`; addon folder and TOC `OutfitterReborn`) |
| Branch / HEAD | `feat/2026-11-03-ka0s-conversion` at `3a56da57173bf0da04da25a857442421974a0e9b`, clean tree (`git status --porcelain` empty) |
| Standard | **Ka0s WoW Addon Standard v2.96.0 (2026-11-01)**, `standards/STANDARDS.md` line 1 |
| Standard source | **Network fetch** of `AUDIT.md`, `standards/STANDARDS.md`, the 29 section files its Sections list links and `standards/ADDONS.md`, from `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, saved verbatim with `curl -fsSL`. The sibling checkout `../WowAddonStandards` was **not** used: its HEAD `42ca8d4` differs from `origin/master` `c48b169` (`git ls-remote`), so it fails the "provably current" test |
| Repo kind | **Addon** (a root `OutfitterReborn.toc` exists; the detector reported `profile=wow, kind=addon`). The whole addon rule set and the whole `AUDIT.md` playbook apply |
| Roster | Not yet in `standards/ADDONS.md`; its row is plan step P9. Audited as a roster addon would be. The launcher-menu expectation was taken from the code and the design (Enabled, Locked, Test mode, Show window), since there is no roster column to read |
| Deviation-ID prefix | **`OR`** (Outfitter Reborn). First audit of this repo: there is no `docs/audits/` store before this run |
| Vendored library | `LibKa0s` **v1.85.0**, test kit **revision 50** (`CLAUDE.md:43`, `tests/_kit/framework.lua:20`) |

## Where the conversion stands

The plan ledger (`docs/superpowers/plans/2026-11-03-ka0s-conversion.md`) records P0 to P6 done and
**P7 (this audit) pending**. P4 (the full port: engine, triggers, UI, bar, quick slots, settings,
launcher, test mode) and P5 (the green gate) are done, and the tree confirms it: 54 `modules/*.lua`
files, every one listed in the TOC. P10 (README in Ka0s style) and P11 (`/dev-copilot:sync-docs`) are
still pending. Several findings below fall inside those two steps, and the bundle says so where it
applies.

## Snapshot, section by section

### Layout (`layout`)

- The modular layout is in place: `core/` (20 files), `defaults/` (6), `locales/` (9), `modules/` (54),
  `settings/` (6), `tests/`, `tools/` (3 generators), `media/{logos,screenshots}/`, `libs/`.
- TOC load order `libs → locales → core → defaults → modules → settings` (`OutfitterReborn.toc:15-157`).
- **Cap census.** `docs/ARCHITECTURE.md:235-237` carries `### Files over the 1500-line cap` reading
  "Nothing is over the cap today." Measured: the largest authored file is `core/Compat.lua` at 993
  lines, so nothing is over 1500 and nothing is in the 1000–1500 band (`03_EVIDENCE.md` E-CAP). The
  kit gate `test_layout_cap` is wired by path (`tests/run.lua:205`). The repo also runs a stricter
  1000-line budget of its own (`tests/test_file_budget.lua`). That is a tighter design rule beside
  the kit's gate, not a shadow copy of it.
- **Logos.** `media/logos/outfitterreborn.logo.128.tga`: TGA type 2, 128×128, 32 bpp. The landing
  logo `outfitterreborn.logo.tga`: type 2, 300×300, 32 bpp. The `.png` and `.jpg` sources are
  `.pkgmeta`-ignored.
- **Generators** live under `tools/` (`gen-zones.lua`, `legacy_capture.lua`, `rekey-locales.lua`).
  None is in the TOC, and `tools` is ignored by `.pkgmeta:12`.
- `Bindings.xml` sits at the root, is absent from the TOC and from `.pkgmeta`'s ignore list, and holds
  14 `CLICK` bindings, each with `category="BINDING_HEADER_OUTFITTERREBORN"`, no `header` and no
  `default`.

### TOC (`toc-file`)

All required fields are present (`OutfitterReborn.toc:1-13`). `## Title: Ka0s Outfitter Reborn`.
`## IconTexture` names the addon's own 128 logo (`:6`). `## X-Curse-Project-ID: 1698220` is the
fork's real project, kept by owner decision. `## OptionalDeps` names `EllesmereUI` (skinning-§5).
LibKa0s is listed once, as `libs\LibKa0s\LibKa0s.xml` (`:27`), after Ace3. Load-bearing positions
carry `LOAD-BEARING:` comments naming what resolves (for example `:33`, `:59-60`, `:110-113`,
`:149-154`).

### Library stack (`library-stack`)

The vendored set is Ace3 (AceAddon, AceEvent, AceTimer, AceDB, AceDBOptions, AceConsole, AceGUI,
AceConfig), LibStub, CallbackHandler, the whole LibKa0s ship folder, LibSharedMedia-3.0,
LibDataBroker-1.1 and LibDBIcon-1.0.

- `diff -r` against LibKa0s **at tag v1.85.0** (`git archive v1.85.0`, not the sibling's HEAD
  `v1.85.0-1-g293040c`): **empty outside `media/icons/`**. Its 1642 lines are all
  `Only in <LibKa0s>/…/media/icons` for icons the addon does not declare (E-VEND).
- `diff -r <LibKa0s>/testkit tests/_kit`: **empty** (E-VEND).
- **Icon subset.** `CLAUDE.md:44` declares 17 icons. `libs/LibKa0s/media/icons/` holds exactly those
  17, plus `LICENSE-open-iconic.txt` and `phosphor/LICENSE-phosphor.txt`. Every name the addon passes
  to `NS.Icon` is declared, and so are the library-drawn `close`, `copy`, `clear` and `info` (E-ICON).
  - *Note.* The copy of `CLAUDE.md` loaded into this session's context carried a longer list (it
    added `edit`, `lock`, `unlock`). `git show HEAD:CLAUDE.md` and the working tree both carry the
    17-name list above, and that list is what was measured.
- No removed `__` member is mirrored (`__releaseChrome`, `__PatchLSM30Border`: no hits).
- `Compat` and `Secrets` are the addon's own (`core/Compat.lua`, `core/Secrets.lua`). At v2.96.0 that
  is not anti-pattern #47: `LibKa0s-Compat-1.0` is required of no addon yet (AUDIT step 4).

### Patterns: namespace, AceAddon, message bus (`architecture`)

- **Bus.** `core/Bus.lua` declares 25 `Ka0s_OutfitterReborn_<Pascal>` wire names, all PascalCase.
  There are **no** literal `Ka0s_` names at a `SendMessage`/`RegisterMessage` call site (E-BUS).
- **Write seam.** `NS.SetByPath` is the one settings seam. `NS.Outfits` is the outfit-record writer.
  The stored-tree grep found three direct writes, all to `profile.windows.bar` (OR-04).

### Settings (`options-ui`, `savedvariables`, `skinning`)

- There are three pages: General (Master controls, Behavior, Tooltips, Skin, Keybindings), Outfit
  bar, and Profiles. The landing page uses the library's `BuildLandingPage`
  (`settings/OptionsSetup.lua:55`).
- Master controls are composed by `H.MasterControls` (`settings/General.lua:36`). Reset position
  goes through the seam (`NS.ApplyDefault(NS.FindSchemaRow("bar.position"))`,
  `settings/General.lua:56`).
- The minimap row is `global.minimap.shown` (`settings/Schema.lua:20`), closure-backed onto
  LibDBIcon's `hide`.
- **Skins adopted:** `Skin:RegisterOwner(addonName, …)` (`core/SkinSetup.lua:496`). The profile
  defaults are `ignorePanel = true`, `ignoreFonts = false` and `outline = "hud"`
  (`defaults/Profile.lua:17-18`). `skin` is the `COMMANDS` row right after `config`
  (`settings/Slash.lua:43`). There are no `stockDefault` hits, no `EllesmereUIDB` hits and no
  `LSM30_` hits, and `AceGUI-3.0-SharedMediaWidgets` is not vendored.
- The skin literal grep found 7 hits outside the seam. Each sets a game-data quality color, a skin
  token read (`NS.SkinColor`), or a base font object that `NS.Skin.EditBox` then paints, so none is
  #107.
- Glyphs: the non-ASCII characters in painted strings (`—`, `…`, `›`) are all in localization-§7's
  safe set, and the suite runs `tests/test_glyphs.lua`.

### Slash (`slash-commands`)

- `/of`, with `/outfitter` as an alias, on LibKa0s-Slash. `NS.COMMANDS` has **35 rows**
  (`settings/Slash.lua`, E-CMD): the 14 reserved and shared verbs, then 21 outfit verbs.
- `liveVerbs` is built on the library's list plus `HOST_LIVE_VERBS = { "auto", "zone", "iteminfo" }`
  (`settings/Slash.lua:115`). `diagnostics` is exactly one row (`:53`), with no alias.
- `lock` and `unlock` (a MAY) write the `locked` row through `writeRow`. `enable` and `disable` write
  `enabled` through the seam.
- The window has `show` and `hide` but no `toggle`. That is a ratified register row (accepted, below).

### Disabled state (`slash-commands-§7`, `performance-§6`)

- **One latch.** `core/LifecycleSetup.lua` builds it on `LibKa0s-Lifecycle-1.0`. It has two holds
  (`disabled`, persisted; `perf`, session-only), and `standDown` walks 20 named modules
  (`core/LifecycleSetup.lua:25-27`). It clears the SecureQueue before the modules (`:44`), and the
  one `PLAYER_REGEN_ENABLED` kept for a combat-deferred Dock hide is the sanctioned survivor.
- **Registrations.** Every game event goes through `NS.SafeRegister*`. The one raw registration is
  `IconChooser`'s `GLOBAL_MOUSE_DOWN`: it is armed on `OnShow` and released on `OnHide`
  (`modules/IconChooser.lua:288-290`), and the stand-down closes the chooser (`IC.Suspend`).
- **`tests/test_disabled.lua`** (708 lines) is listed in `tests/run.lua:122` and is green. All ten
  steps are present, on the real addon, with `-- red under:` comments. Step 6 asserts reach per event
  (`__fireUnconditional(...) >= 1`, `:272-273`). Step 10 uses `T.assertLatchHoldOrder` on both arms.
  The one gap is step 7, which does not dispatch the `debug diagnostics` form (OR-06).
- **The one survivor found:** the skin-notice retry timer (`core/SkinSetup.lua:371-376`, OR-03).

### Launcher (`launcher`)

- There is one object: `LibKa0s-Launcher-1.0` `:New` (`core/LauncherSetup.lua:139`) with
  `label = NS.BRAND` (`:142`). It passes `isEnabled`/`setEnabled`, `isLocked`/`toggleLock`,
  `isTestMode`/`toggleTestMode`, `isWindowShown`/`toggleWindow`, plus `debug` and `debugAtEnable`.
- There is no host `OnClick`, no `MenuUtil` call of its own, and no LDB object assigned
  `OnTooltipShow`.
- The 14 binding buttons are plain, hidden and non-secure. Each asks `NS.StoodDownRefusal()` before
  its handler. `BINDING_HEADER_OUTFITTERREBORN` is set from the brand (`:90`), and `Kit.assertBindingsXml`
  pins the file (`tests/test_keybinds.lua:84`).

### Debug (`debug-logging`)

The `LibKa0s-DebugLog-1.0` descriptor passes `name` and `addonName` (`core/DebugLogSetup.lua:80-81`).
Its stub answers `RunDiagnostics`, `DebugOnce`, `DebugChanged`, `DebugForget` and `DebugAtEnable`
(`:47-55`). `modules/Diagnostics.lua` contributes the addon's sections. The host makes no
`SetEnabled` call around a run (`core/DebugLogSetup.lua:113`).

### Frame layering (`frame-layering`)

There is no `SetFrameStrata("…")` literal and no absolute or sibling-relative `SetFrameLevel`. The
movable frames (the bar and the dialogs) call `SetToplevel(true)`. The icon chooser is clamped,
dismissed on `GLOBAL_MOUSE_DOWN` and in `UISpecialFrames`. The docked window copies the sheet's
layer, which is register row D2.

### Tests and lint (`testing`, `lint`)

- `luacheck .`: **0 warnings / 0 errors in 188 files**. `exclude_files` is `libs/`, `tests/_kit/` and
  the frozen doc stores (`.luacheckrc:8`), so `tests/` is linted. The harness global sits only in
  `files["tests/"]` (`:36-37`), and there is no top-level `ignore`.
- `lua tests/run.lua`: **1277 passed, 0 failed, 1 skipped, 1278 total**. The README badge reads
  `1277/1277` and `docs/test-cases.md` counts Total 1277, so they agree.
- The kit gates are wired by path: `test_eol`, `test_layout_cap`, `test_diagnostics_contract`,
  `test_lizard_sighted` and `test_prose` (`tests/run.lua:204-208`). `test_vendor_sync` is green.

### Performance and complexity (`performance`, `automated-tests`)

- `core/PerfSetup.lua` wires LibKa0s-Perf. `OutfitterRebornPerfDB` is declared in the TOC.
  `tests/perf.lua` has 10 scenarios.
- The complexity suite, run verbatim through the bounded runner, reports **0 warnings, max CCN 15,
  40002 NLOC, 5040 functions**. That matches the newest bundle `docs/automated-tests/20261104-044201/`
  exactly (`RESULTS.md` row). The bundle measured `9a27eb7`, **2 commits behind HEAD**, from a clean
  tree, and it is not a release run (`manifest.json` `release: null`).
- `blindFiles` and `crashedFiles` are both 0. The watch list is empty (no warned function, no file in
  the band), so there is no "Accepted" entry to age.
- The bundle's `ANALYSIS.md` carries `## Preview and simulation data`.
- `docs/complexity.md` and `docs/perf-runs/` are absent, as required.

### Packaging (`packaging`)

`.pkgmeta` ignores the dev-only set (`.pkgmeta:5-19`). The one gap is the untracked `.claude/`
directory (OR-08).

### `.gitattributes` (`line-endings`)

- The pin is `* text=auto eol=crlf`, verbatim (`.gitattributes:26`). Both carve-outs are present
  (`:36-37`) and 20 `binary` lines follow.
- After CR-stripping, the body is **byte-identical** to the canonical client-bound body (84 lines),
  with no appendix.
- Working-tree agreement (e): **0** tracked files disagree with the pin.
- The plain `grep … '$'` forms of checks (b) to (d) print nothing on this file, because a
  CRLF-checked-out `.gitattributes` ends every line in `\r`. Re-run over `tr -d '\r'`, they pass
  (E-EOL).

### Root doc set (`documentation-§1/§2/§7`)

- **`README.md`** is still the fork-era README (P10 pending). Its H1 reads `# Outfitter Reborn`, it
  describes the removed script editor, and three MUST sections are missing (OR-02).
  - Clean on the cheap checks: the badge is bare (`README.md:6`), there is no logo image, no
    numbered list, no library inventory, no font text and no provenance line. The Open Iconic and
    Phosphor credits are present (`:135-139`).
- **`CLAUDE.md`** is a conforming stub: H1, adherence line, `## Standards compliance (read first)`,
  the docs pointer list, the green-gate line, and the provenance line with the icons line directly
  under it (`:43-44`).
- **`DEPENDENCIES.md`** names `lua5.1`, `luacheck`, `lizard` (via the runner), Pillow and the install
  check.

### `docs/` (`documentation-§3`)

- Tier 1 is complete: `scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`, `data-flow.md`,
  `common-tasks.md`.
- Every Tier 2 doc is present: `slash-dispatch.md` (35 commands), `midnight-quirks.md`,
  `compat-layer.md` (77 shims), `message-bus.md` (25 messages), `profiles.md`, `debug.md`,
  `perf-analysis/README.md`, `known-limitations.md`, `taint.md`.
- `## Documentation map` has the four tables in order. Every live `.md` under `docs/` is registered
  exactly once, with no dangling row. The fourth table holds exactly the six verification-and-record
  docs, and `users-manual.md` is Addon-specific.
- No non-canonical names, no retired docs, no `docs/pending/`.
- Hub shape: 237 lines, and no section is past about 60 lines.
- **Content drift:** 63 lines in 11 live docs still describe the P3 scaffold (OR-01).

### Recorded-deviation register and issue store

`docs/ARCHITECTURE.md:209-220` holds **8** ratified rows: D1, D2, C35, D3, D4, D6, D8, D10. Each
cites a rule, a reason with its design id, a Decided date (2026-11-03) and a re-check trigger.

- None of the triggers has fired.
- Every cited rule still says what the row claims at v2.96.0.
- They are recorded below as **accepted** and are not counted toward the MUST tally.
- **The issue store is empty:** `gh issue list --state all --limit 200` returns 0 issues, so there is
  no `state:will-not-do` decision lacking a row, and no `[status]` prefix.
- **Closed here:**
  - The D11 question that design §10 put to this audit: it is not a deviation.
  - D7's library half: the vendored library already falls back to the client's locale font
    (`libs/LibKa0s/Skin.lua:737-750`). See OR-09 for both.
- The D2 row omits one departure it should carry, the protected window (OR-07).

| Accepted row | Rule | Re-check trigger state |
|---|---|---|
| D1 | `versioning-git` | Not fired (no MAJOR release) |
| D2 | `standalone-windows` | Not fired. The row is incomplete, see OR-07 |
| C35 | `standalone-windows` (window `toggle` SHOULD) | Not fired |
| D3 | `localization-§4` | Not fired |
| D4 | `localization-§4` | Not fired (client check owed) |
| D6 | `documentation-§1` (screenshots) | Not fired (no 1.1.0 client capture) |
| D8 | `localization-§4` | Not fired |
| D10 | `localization-§4` | Not fired |

### Shared subsystems (descriptor + stub, not hand-rolled)

Core (`core/CoreSetup.lua`, which uses one-rung `pcall` `SafeRegister*` stubs, `:54-76`), DebugLog,
Options (load-completing, answering `AppearanceTab`, `AppearanceRows`, `SkinVerb` and `StrataTooltip`,
`settings/OptionsSetup.lua:152-168`), Slash, Launcher, Lifecycle, Perf, Bus and Schema are all
consumed through descriptors. `tests/test_surface_parity.lua` pins every stub against its live
instance. Nothing is hand-rolled (#47 clean). `NS.MakeCloseButton` is the one wrapper
(`core/CoreSetup.lua:107`), and both call sites use it.
