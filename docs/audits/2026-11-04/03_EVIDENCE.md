# 03 — Evidence

Every `file:line` below was re-read at HEAD `3a56da5` before it was written, and the quoted text is
what is there. Every count names its command and its scope. Commands ran from the repo root. The
default Lua scope is `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, which gives **188
files**: `tests/` and `tools/` are in, while vendored `libs/` and `tests/_kit/` are out. The runtime
scope is the TOC-derived load list, which gives **95 files**.

## Mechanical checks

### E-LINT — `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .`

```
Total: 0 warnings / 0 errors in 188 files
luacheck exit 0
```

Scope: `.luacheckrc:8` reads `exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/" }`.
`tests/` is linted. `.luacheckrc:36` opens `files["tests/"] = {`, and the harness global is
declared there only. There is no top-level `ignore`.

### E-SUITE — `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`

```
1277 passed, 0 failed, 1 skipped, 1278 total
suite exit 0
```

`docs/test-cases.md` Total = 1277. `README.md:7` reads `Tests-1277%2F1277_passing`, which agrees.

### E-CPLX — `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`

```
complexity  pass  — 0 warnings (fun rate 0.00), 40002 NLOC / 5040 funcs, avg NLOC 6.9, avg CCN 2.3 (max 15), avg tokens 61.2 (recorded, non-gating)
verdict: green
record:  newest bundle 20261104-044201 measured 9a27eb7, 2 commit(s) behind HEAD — its figures describe a tree this one is no longer
```

The `RESULTS.md` row for `20261104-044201` reads `9a27eb7 | clean | 1.1.0 | 0/0 | 188 | 1277/1/1278 | pass | 40002 | 5040 | 6.9 | 2.3 | 15 | 0 | green`.
**Drift: none.** The figures are identical, and no file entered the 1000–1500 band.

The manifest gives `release: null`, `suites.complexity.blindFiles: 0` and `crashedFiles: 0`. The kit
is `Kit.VERSION = 50` (`tests/_kit/framework.lua:20`), at or above 35 and 41.
`{ name = "test_lizard_sighted", dir = "tests/_kit/" }` is wired (`tests/run.lua:207`). The watch
list has no rows, so there is no Accepted entry to age (anti-pattern #53 is clean).

### E-VEND — vendored LibKa0s and test kit, at the tag `CLAUDE.md` names

```
CLAUDE.md:43: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).
git -C ../LibKa0s tag -l 'v1.85*'      -> v1.85.0
git -C ../LibKa0s describe --tags      -> v1.85.0-1-g293040c   (HEAD is NOT what was diffed)
git -C ../LibKa0s archive v1.85.0 LibKa0s testkit | tar -x -C <scratch>
diff -r <scratch>/LibKa0s libs/LibKa0s   -> exit 1; 1642 lines, every one "Only in <scratch>/LibKa0s/media/icons…"
diff -r <scratch>/testkit tests/_kit     -> exit 0 (empty)
```

`grep -v '^Only in /tmp' diff_lib.txt` prints nothing, so there is no `differ` line and no
`Only in libs/…` line. Anti-patterns #45 and #48 are clean. TOC line `OutfitterReborn.toc:27` is
`libs\LibKa0s\LibKa0s.xml`, listed once.

### E-ICON — icon subset against the declaration

`CLAUDE.md:44` reads `LibKa0s icons: add, cancel, chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, ellipses, help, info, move, ph:lightning, reset, settings, volume-high.`

`find libs/LibKa0s/media/icons -type f` lists those 17 `.tga` files (with `phosphor/lightning.tga`),
plus `LICENSE-open-iconic.txt` and `phosphor/LICENSE-phosphor.txt`. Nothing else is present.

Names the addon draws, from the grep `Icon("…")` outside `libs/` and `tests/`:

| Name | Where |
|---|---|
| `chevron-down`, `confirm` | `core/WidgetsSetup.lua:34-35` |
| `chevron-right` | `:118` |
| `info` | `:190` |
| `help` | `:207`, `modules/SlotEnables.lua:160` |
| `confirm` | `modules/Bar_Buttons.lua:195` |
| `cancel` | `modules/Dialog_Rebuild.lua:67`, `modules/Dialog_TriggerFields.lua:122` |
| `settings` | `modules/Window.lua:132` |
| `add` | `modules/Window.lua:167` |
| `ph:lightning` | `modules/Window_Rows.lua:303` |
| `ellipses` | `modules/Window_Rows.lua:323` |

Every one is declared. The library-drawn `close`, `copy` and `clear` (the console, wired with
`addonName`, `core/DebugLogSetup.lua:81`) and `info` are declared too.

README credits for the shipped sets are present: Open Iconic and Phosphor, `README.md:135-139`. No
`gi:` icon ships.

### E-EOL — line endings

```
test -f .gitattributes                                   -> present
grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes -> (nothing)   } the file is checked out CRLF,
grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes      -> (nothing)   } so '$' never matches before \r
grep -c ' binary$' .gitattributes                        -> 0           }
tr -dc '\r' < .gitattributes | wc -c -> 84 ; tr -dc '\n' < .gitattributes | wc -c -> 84
tr -d '\r' < .gitattributes | grep -n '^\* text=auto eol=\(crlf\|lf\)$'  -> 26:* text=auto eol=crlf
tr -d '\r' < .gitattributes | grep -nE '^\*\.(sh|py) text eol=lf$'      -> 36:*.sh text eol=lf / 37:*.py text eol=lf
tr -d '\r' < .gitattributes | grep -c ' binary$'                        -> 20
tr -d '\r' < .gitattributes | diff - <canonical client-bound body, line-endings-§5, 84 lines>  -> IDENTICAL
(e) git ls-files -z | xargs -0 -n1 sh -c '<AUDIT.md check (e), verbatim>' _ | wc -l  -> 0
```

Scope: the whole tracked set (499 files, `git ls-files | wc -l`), with no exclusions. Result: **0
tracked files disagree with the declared pin.** The kit gate `test_eol` is wired
(`tests/run.lua:204`) and green, which agrees. *Note for the playbook:* checks (b) to (d) as printed
in AUDIT.md cannot match a CRLF-pinned repo's own `.gitattributes`, because a client-bound repo
always checks that file out CRLF. That is an upstream fix to the playbook, not a finding here.

### E-PKG — package ignore list (AUDIT step 4, three loops, verbatim)

```
(a) NOT IGNORED — .claude
(b) UNACCOUNTED — .claude
    UNACCOUNTED — .git          (the one entry the packager never sees; owes no row)
(c) (nothing)
```

`ls -la .claude` shows only `worktrees/`. `git ls-files .claude` is empty. → OR-08.

### E-GEN — generators

`git ls-files '*.py' '*.sh' | grep -vE '^(libs/|tests/_kit/)'` returns nothing.
`git ls-files tools` gives `tools/gen-zones.lua`, `tools/legacy_capture.lua` and
`tools/rekey-locales.lua`. All three are under `tools/`, none is in the TOC, and `.pkgmeta:12`
reads `  - tools            # generators that run on a desktop Lua, never in the client`.
Compliant.

### E-CAP — the 1500-line census

```
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | sort -rn | head
  52574 total
    993 core/Compat.lua
    988 tests/test_secrets.lua
    953 tests/fixtures/legacy/presets.lua
    903 tests/mock_gear.lua
    854 tools/legacy_capture.lua
```

There are no declared generated-data exemptions. Nothing is over 1500 or in 1000–1500.
`docs/ARCHITECTURE.md:237` reads `Nothing is over the cap today.`, which is true.
`tests/run.lua:205` reads `{ name = "test_layout_cap", dir = "tests/_kit/" },`.

### E-REVENDOR — re-vendor bundles (AUDIT step 4 script, verbatim, `--since="2026-11-03 00:00"`)

```
vendored: v1.85.0
recorded: v1.85.0
unrecorded: (none)
```

There are eight commits touching `libs/LibKa0s` or `tests/_kit` since the horizon:

| Commit | Subject |
|---|---|
| `b0e9c82` | Vendor LibKa0s v1.85.0 and test kit rev 50 |
| `e98b509`, `19e2496`, `1c489c1`, `0efc3a6`, `56145e2`, `b0c63e1` | Re-syncs to the v1.85.0 re-cut |
| `71987ae` | — |

All of them are the one tag. `docs/revendor/2026-11-03-v1.85.0/` holds the two stable members,
`01_DELTA.md` and `05_SUMMARY.md`. Compliant.

### E-BUS — message names

```
grep -rnE '(Send|Register)Message\("Ka0s_' --include='*.lua' . | grep -v -e '/libs/' -e '/tests/_kit/'   -> (nothing)
grep -rnoE '"Ka0s_[A-Za-z]+_[A-Za-z0-9_]+"' … -> 25 names, all in ./core/Bus.lua, all Ka0s_OutfitterReborn_<Pascal>
```

### E-CMD — `NS.COMMANDS` rows and Compat shims

```
awk '/^NS.COMMANDS = \{/,/^\}/' settings/Slash.lua | grep -cE '^\s*\{ "[a-z]+"'   -> 35
cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'       -> 77   (documentation-§3's own grep)
```

These are set against `docs/ARCHITECTURE.md:183`, which reads
`| [\`slash-dispatch.md\`](slash-dispatch.md) | Present | 14 commands in \`NS.COMMANDS\` today (eight or more) |`,
and `:185`, which reads `` `core/Compat.lua` publishes 73 hand-written shims (the trigger is three or more) ``.
→ OR-01a.

### E-ISSUES — issue store

`gh issue list --state all --limit 200 --json number,title,state,labels,url` returns `0` issues
(remote `https://github.com/tusharsaxena/Outfitter.git`). No GraphQL was used. → OR-09.

### E-GREPS — the playbook's remaining finders, no hits unless shown

| Finder | Result |
|---|---|
| `MakeCloseButton(` outside `libs/`, `tests/` | `core/CoreSetup.lua:107` (`return lib.MakeCloseButton(parent, onClick, addonName)`, the wrapper), plus wrapper calls `modules/UIDialogs.lua:150` and `modules/Window.lua:125`. Compliant |
| `SettingsPanel\|HideUIPanel\|ToggleGameMenu\|OpenToCategory` | none |
| `Create("Keybinding")\|SetBinding(\|SaveBindings\|KeybindListener` | only `NS.Outfits.SetBinding` (the addon's own outfit-key map, `modules/Outfits.lua:568`), not the client API |
| `SetFrameStrata("` / `SetFrameLevel(<digit>` / sibling-relative level | none |
| `SetToplevel\|SetMovable` | `modules/Bar.lua:161,163`, `modules/UIDialogs.lua:165,167`, `modules/IconChooser.lua:276`. Every movable frame is toplevel |
| `stockDefault`, `EllesmereUIDB`, `LSM30_`, `libs/AceGUI-3.0-SharedMediaWidgets` | none / none / none / absent |
| `__releaseChrome\|__PatchLSM30Border` | none |
| `ScrollUp-Up\|ScrollDown-Up` in `settings/` | none |
| `OnTooltipShow` in addon code | none (the descriptor's `onTooltipShow` adds one host line) |
| `"(diag\|dump\|dx)"` | Only `"Diag"` debug-tag strings in `modules/Diagnostics.lua`; no alias in `COMMANDS` |
| `docs/pending`, `docs/perf-runs`, `docs/complexity.md`, `file-index.md`, `conventions.md` | all absent |
| non-ASCII in painted strings | `…` (`settings/General.lua:151`), `—` (`settings/OptionsSetup.lua:73`), `\226\128\148` (—, `settings/Slash.lua:129`), `\226\128\186` (›, `settings/Slash.lua:208`). All are in the localization-§7 safe set |

## Findings

### OR-03 — the skin-notice retry timer outlives the stand-down

- `core/SkinSetup.lua:348` reads `local NOTICE_RETRY = 5   -- seconds between asks while the player is in combat`.
- `core/SkinSetup.lua:371` reads `    if why == "combat" and not noticeWaiting and type(_G.C_Timer) == "table" and _G.C_Timer.After then`.
- `core/SkinSetup.lua:373` reads `        _G.C_Timer.After(NOTICE_RETRY, function()`. There is no handle, so
  nothing can cancel it.
- `core/SkinSetup.lua:358` reads `    set = function(v) local g = noticeGlobal(); if g then g.skinNotice = v end end,`.
  This is the write the stood-down re-entry can still make through the library's "claimed" branch
  (`libs/LibKa0s/OptionsSkinPicker.lua:1435` reads `    if lib.__noticeClaimed and lib.__noticeClaimed >= v then`,
  then `store.set(v)`).
- The library's own contract for the notice path: `libs/LibKa0s/OptionsSkinPicker.lua:1423` reads
  `--- so every vendored copy of an addon shares it. No timer: a stand-down must leave nothing armed,`.
- The path starts from login: `core/OutfitterReborn.lua:74` reads
  `    addon:ScheduleTimer(function() NS.MaybeShowSkinPicker() end, 2)`. That AceTimer is canceled by
  `CancelAllTimers`; the inner `C_Timer.After` is not.
- `standDown` (`core/LifecycleSetup.lua:33-52`) cancels the addon's AceTimers, walks the modules and
  calls `NS.HideSkinPicker()`. It touches no `noticeWaiting` timer.
- `tests/test_disabled.lua:219-231` (step 4) asserts no timer is armed after disable. Its scene
  raises the notice out of combat, so this timer is never armed there.
- OR-03a: `modules/OutfitMenu.lua:72` reads `    C_Timer.After(TITLE_DELAY, function()`, gated at fire
  by `if not NS.IsStoodDown() then` (`:73`).

### OR-01 — doc set describes the scaffold

Command (scope: live `docs/*.md` from `git ls-files`, excluding the frozen and generated stores
`docs/{audits,reviews,revendor,superpowers}/`, `docs/automated-tests/2*/` and
`docs/perf-analysis/2*/`):

```
git ls-files 'docs/*.md' | grep -vE '^docs/(audits|reviews|revendor|superpowers|automated-tests/2|perf-analysis/2)' \
 | xargs grep -nE 'arrive with the port|until then|today only|Today the tree|lands in P4|until the engine|Until P4|\(P4\)|marked \*\*P4\*\*|\(P4[,:)]' | wc -l   -> 63
files: ARCHITECTURE.md common-tasks.md data-flow.md debug.md known-limitations.md message-bus.md
       perf-analysis/README.md profiles.md schema.md smoke-tests.md taint.md   (11)
```

A broader `\bP4\b` sweep gives 82 lines, but it also counts legitimate provenance ("landed in
P4.27"), so it is **not** the figure used.

Quoted lines:

| Citation | Text |
|---|---|
| `docs/ARCHITECTURE.md:32` | `**Where the build stands.** P3 (the scaffold) is complete: the namespace, media, constants, session` |
| `docs/ARCHITECTURE.md:49` | ``triggers and the UI (today only `modules/Diagnostics.lua`); `settings/` holds the schema, the slash`` |
| `docs/ARCHITECTURE.md:116` | ``the tree registers one game event: `PLAYER_REGEN_ENABLED`, on `core/SecureQueue.lua`'s own target,``. The load-list census finds over 20 `SafeRegister*` sites (for example `modules/Inventory.lua:486`, `modules/States.lua:481`) |
| `docs/ARCHITECTURE.md:147-148` | `- The scaffold loads, stores settings and answers its slash and settings surfaces; no outfit can be` / `worn until the engine lands in P4.` |
| `docs/data-flow.md:8` | ``Sections marked **P4** describe the design (`superpowers/specs/2026-11-03-design.md`, §5 and §6) that`` |
| `docs/message-bus.md:24` | `Senders marked P4 arrive with the port; until then the key is declared and nothing sends it.` |
| `docs/schema.md:126` | `function that writes it (architecture-§5). Owners marked P4 arrive with the port, and until then` |
| `docs/known-limitations.md:10` | `slash surface and the first key binding; the engine, the triggers and the UI are P4. Until P4.19 the` |

The dependents:

- **OR-01a**: E-CMD.
- **OR-01b**: `docs/settings-panel.md:44` reads
  ``| Minimap button | `global.minimap.shown` | `NS.Launcher:IsShown()`/`SetShown()`; exempt from reset |``.
  There is no binding named on it. `Bindings.xml` line 11 is the Show window binding,
  `CLICK OutfitterRebornToggleWindow:LeftButton`.
- **OR-01c**, the stale code comments:

  | Citation | Text |
  |---|---|
  | `core/LauncherSetup.lua:154` | `    -- Test mode lands in P4.22; until then it answers off and does nothing. Show window toggles the` |
  | `core/LauncherSetup.lua:160` | `    -- The one host line: the outfit on top of the stack. The stack lands in P4.9; until then the` |
  | `settings/General.lua:54-55` | ``    -- The bar's place is the `bar.position` row (settings/OutfitBar.lua, P4.23); with no row yet the`` / `    -- reset answers false and moves nothing.` |
  | `core/LifecycleSetup.lua:23-24` | `-- the engine resets; States.Resume runs before TriggerBinder.BindAll on the way up (design §5.12).` / `-- Declared whole in P4.0: a name whose module has not landed is skipped (the P4.0 stubs publish no NS` |

### OR-02 — README

| Citation | Text |
|---|---|
| `README.md:1` | `# Outfitter Reborn`. documentation-§1 item 1 requires `# Ka0s <Name>`, and the TOC title is `Ka0s Outfitter Reborn` |
| `README.md:35` | `into a battleground. Edit those or write your own in the built-in script editor.` |
| `README.md:82` | `covers all of it, including writing your own scripts.` |
| `README.md:101` | `## Version history`. Item 11 names `## Version History` |
| `README.md:105` | `\| 1.0.0 \| 2026-09-16 \| - First release as Outfitter Reborn, …`. There is no 1.1.0 row |
| `README.md:63` | ``- `/of config` opens the settings panel, `/of skin` the skin picker``. This is the first of 16 command bullets (`:63-78`), a second copy of `NS.COMMANDS` that item 5 forbids |

- `grep -nE '^## ' README.md` gives `25:## What it does`, `51:## Usage`, `84:## What no longer works`,
  `101:## Version history` and `107:## Credits`. There is no `## How … works`, no
  `## Reporting a bug` (OR-02a) and no `## Issues and feature requests`.
- `grep -n -i 'bind\|key' README.md` returns nothing (OR-02b).
- OR-02c: `docs/users-manual.md:260` reads `Scripts are Lua. Outfitter runs yours whenever one of the events it declares`.
  `grep -niE 'script' docs/users-manual.md | wc -l` gives 15.
- The removed editor: `git ls-files '*.lua' | grep -vE '^(libs/|tests/)' | xargs grep -ln 'loadstring'`
  returns only `tools/legacy_capture.lua` and `tools/rekey-locales.lua` (desktop generators, never
  loaded), so the addon ships no script runtime.

### OR-04 — bar position written around the seam

| Citation | Text |
|---|---|
| `settings/OutfitBar.lua:73` | `    { path = "bar.position", page = PAGE, group = DISPLAY, type = "string", skipRender = true,` |
| `settings/OutfitBar.lua:78` | `      set = function(v) NS.db.profile.windows.bar = decode(v) end },` |
| `modules/Bar.lua:140` | `        onDragStop        = function() Bar.SavePosition() end,` |
| `modules/Bar.lua:425` | `    NS.db.profile.windows.bar = p` |
| `modules/Bar.lua:433` | `    NS.db.profile.windows.bar = { point = d.point, x = d.x, y = d.y }` |
| `settings/General.lua:56` | `    onResetPosition      = function() NS.ApplyDefault(NS.FindSchemaRow("bar.position")) end,`. The production reset goes through the seam |
| `tests/test_bar.lua:254` | `    Bar.ResetPosition()` |
| `docs/schema.md:131` | ``\| `profile.windows.bar` \| `NS.Bar` (P4) \| `NS.Bar.SavePosition` on drag stop; the `bar.position` row's default and reset copy the default \|`` |

- `grep -rn 'ResetPosition' core modules settings` finds the definition `modules/Bar.lua:431`, a
  comment at `:17` and the composer key in `settings/General.lua`. There is no production call.
- Stored-tree grep (scope: the default Lua set minus `tests/` and `tools/`):
  `xargs grep -nE '(db\.(profile|global|char)|…)(\.[A-Za-z_]+|\[[^]]+\])+ *= *[^=]'` returns exactly
  these three lines.
- The aliased writers (`modules/OutfitStack_Watch.lua:89` reads `    local s = NS.db.char.stack`, and
  `modules/UIDialogs.lua:96` reads `    local w = NS.db.profile.windows`) are named in
  `docs/schema.md:132,135`. They are class (e) and compliant.

### OR-05 — public API

- `modules/Api.lua:166` reads `OutfitterReborn = { API = { v1 = API } }`.
- `grep -nE 'NS\.API' modules/Api.lua` returns nothing.
- `grep -niE 'API' docs/ARCHITECTURE.md` has hits only inside register row D1 (`:213`) and two other
  rows. There is no contract section.
- public-api's text: `**MUST** version-namespace it: \`NS.API = NS.API or {}; NS.API.v1 = {...}\`. Public consumers reference \`MyAddon.API.v1.SomeFunction\`.`
  and `**MUST** publish via \`_G[addonName] = NS.API\``.

### OR-06 — step 7 misses one diagnostics form

- `tests/test_disabled.lua:312` reads `        NS.Slash:OnSlash(verb)`. This sits inside `for _, row in ipairs(NS.COMMANDS) do` (`:308`), so it dispatches the bare verb only.
- `grep -n 'debug diagnostics' tests/test_disabled.lua` returns nothing.

The other nine steps are each covered:

| Step | Covered at |
|---|---|
| 1 | `:136-146` |
| 2+3 | `:148-159`, combat `:161-193`, bus `:195-217` |
| 4 | `:219-231` |
| 5 | `:233-248` |
| 6 | `:250-280`, combat-entry `PLAYER_REGEN_DISABLED` by name at `:257`, reach at `:272-273` |
| 7 | `:355-400`, the perf-hold line included |
| 8 | `:424-478`, left, right and all 14 binding buttons, disabled and under the perf hold |
| 9 | `:489-510`, with `auto.enabled` changed while down |
| 10 | `:512-536`, both arms |

Each of steps 3, 6 and 10 carries a `-- red under:` comment (`:149`, `:251`, `:513`).

### OR-07 — the protected window is not in D2

- `modules/Window_Rows.lua:335` reads `    local s = CreateFrame("Button", row.__rowName .. "Secure", row, "SecureActionButtonTemplate")`.
- `docs/ARCHITECTURE.md:214`'s Rule cell is
  ``| `standalone-windows` (movable, saved position, Lock/Reset, toplevel; the `UISpecialFrames` MUST is honored) |``.
- standalone-windows line 7: `- **MUST** be a plain **non-secure** \`CreateFrame("Frame")\` (movable/resizable) — **not** a Blizzard Settings canvas, **not** a secure/protected frame.`

### OR-08 — `.claude`

See E-PKG. `.pkgmeta:5-19` holds the ignore list, and it has no `.claude` line.

### OR-09 — register prose and the two conditional rows

- `docs/ARCHITECTURE.md:223` reads ``design's §10, tracked as open issues rather than parked here): **D7** (`localization-§7`, CJK and``.
  E-ISSUES shows 0 issues.
- D7: `libs/LibKa0s/Skin.lua:737` reads `local LOCALE_GROUP = { ruRU = "ruRU", koKR = "koKR", zhCN = "zhCN", zhTW = "zhTW" }`.
  Its `faceRefused` (`:742-750`) answers true for a face whose `langmask` excludes the client's
  locale group. `docs/smoke-tests.md:113` keeps the client check (X1).
- D11: `modules/QuickSlots.lua:62` reads `        if onPlayer(location) then itemTable[location] = nil end`,
  and `modules/QuickSlots.lua:120` reads `    hooksecurefunc(settings, name, fn)`.
  skinning-§7's scope is what a skin paints. events-frames-taint-§3 opens "If your addon replaces a
  Blizzard frame". Neither reaches a post-hook that filters the flyout's item list.

## Compliance citations for the shared subsystems

| Subsystem | Lookup and descriptor | Stub |
|---|---|---|
| Lifecycle | `core/LifecycleSetup.lua:18` `local Lifecycle = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)`. One latch, `MODULES` at `:25-27` | Degraded arm pinned by `test_disabled` step 10 (degraded) |
| DebugLog | `core/DebugLogSetup.lua:11` lookup; `:80-81` `name` and `addonName` | `:47-55` answers `RunDiagnostics`, `DebugOnce`, `DebugChanged`, `DebugForget`, `DebugAtEnable` |
| Options | `settings/OptionsSetup.lua:19` lookup; `:55` `buildMain` → `BuildLandingPage` | Load-completing, the documented exception: `:152` `StrataTooltip`, `:159-160` `AppearanceTab`/`AppearanceRows`, `:168` `SkinVerb` |
| Core | `core/CoreSetup.lua:83-85` `NS.SafeRegister* = lib.SafeRegister*` | One-rung `pcall` bodies at `:54-76` |
| Launcher | `core/LauncherSetup.lua:9` lookup; `:139-169` descriptor | `:111-137` stub. Parity at `tests/test_surface_parity.lua:113` |
| Slash | `settings/Slash.lua:119` lookup; `HOST_LIVE_VERBS` at `:115` | Stub gate at `:168-169` |
| Surface parity | `tests/test_surface_parity.lua:81-176` covers Bus, busRecord, SchemaRuntime, the Slash dispatcher, lifecycle, Launcher, Compat and Secrets | — |
