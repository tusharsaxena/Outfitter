# Character sheet, outfit window and broker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The run is driven by ultracode workflows (owner ruling); each milestone is one workflow.

**Goal:** Make Outfitter Reborn sit properly on the stock, EllesmereUI and Chonky character sheets, give outfits icons through a LibKa0s icon browser promoted from Quick Comms, and bring back the old outfit-switcher broker plugin.

**Architecture:** Three repos. LibKa0s gains a new major, `LibKa0s-IconBrowser-1.0`, lifted from Quick Comms with descriptor-driven tabs; Quick Comms re-vendors and becomes a thin caller; Outfitter Reborn re-vendors and gains a sheet adapter (one module that knows the three sheets), a reworked row, the icon model, the outward drawer and a second LDB object.

**Tech Stack:** Lua 5.1, WoW retail 12.x API, Ace3, LibKa0s (v1.85.0 → v1.86.0), LibDataBroker-1.1, the repos' headless harness (`lua tests/run.lua`) and bounded luacheck.

**Spec:** `docs/superpowers/specs/2026-11-04-sheet-and-window-feedback-design.md` (OutfitterReborn repo). Read it with this plan.

## Global Constraints

- The Ka0s WoW Addon Standard binds all three repos. A new departure is a deviation row; the only expected one is `launcher-§1` (G9).
- Green gate before every commit, per repo: `lua tests/run.lua` and `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0 warnings / 0 errors).
- Branches: `feat/2026-11-04-sheet-window-feedback` (OutfitterReborn, exists), `feat/2026-11-04-icon-browser` (LibKa0s), `feat/2026-11-04-icon-browser-revendor` (QuickComms).
- Owner rulings: commit freely; LibKa0s tag `v1.86.0` and release allowed; push to origin after each milestone; **never merge without the owner's go-ahead**; after the merge, delete every branch, stash and worktree this run created. No Outfitter Reborn or Quick Comms version bump.
- Files keep CRLF line endings where they have them (`git ls-files --eol`); new files follow the repo's `.gitattributes`.
- New strings go through `L[...]` in `locales/enUS.lua` (addons) or `lib.STRINGS` (library). The brand is never localized.
- No secure frame is anchored, re-parented or shown/hidden in combat (`modules/Dock.lua` header, `docs/taint.md`). Flyout and sheet changes are `hooksecurefunc` post-hooks and plain frames only.
- Re-vendor from the **tag**, never untagged master (`tests/test_vendor_sync.lua`).
- Blizzard UI symbols are verified against `Gethe/wow-ui-source` (`live`), cited `wow-ui-source@<sha>:path:line`; this plan's citations are at `297d7aa`. Shallow-clone it into the session scratchpad to check any other symbol.

## Review Focus

1. **Sheet addon present but its skin off** (EllesmereUI with the "blizzard" style, Chonky during combat/M+ where `AreSecretsDisabled()` skips its setup): the adapter must fall back to stock anchors, not anchor to a frame that is hidden or never built. → Task 3.1 test `sheet: EllesmereUI loaded with the blizzard style resolves to stock`.
2. **Chonky side panel open** (M+ / raid / GearFinder `ccs*_af` frames): the window must dock right of the open panel, not on top of it. → Task 3.2 test `dock: an open Chonky side panel pushes the window right`.
3. **Stored icon shapes from 1.1.0** (a number fileID, nil, the 134400 wildcard) must keep drawing exactly as before; a glyph path on an EM outfit must not be written to the EM set. → Task 3.5 tests.
4. **Combat**: opening the flyout, clicking the EM icon, the broker menu's wear/remove and the sheet button in combat lockdown must refuse cleanly, never error. → Tasks 3.4, 3.6, 3.7.
5. **Stood down** (`/or disable`): the sheet button, broker object text and menu, slot boxes and the outward flyout hook all go quiet and Blizzard's drawer is untouched. → `test_disabled` cases in Tasks 3.4, 3.6, 3.7.

## Status ledger (resume from here)

Update the row and commit the plan at every checkpoint. A resumed run reads this table, `git log` in all three repos, and continues from the first row not `done`.

| CP | Milestone / task | Repo | State |
|---|---|---|---|
| CP0 | Slash rename + design committed | OR | done (11ead73, f4aa2b0) |
| CP1 | M1 LibKa0s IconBrowser released as v1.86.0, pushed | LK | done (tag v1.86.0 = cad1609, branch pushed) |
| CP2 | M2 Quick Comms re-vendored onto the library browser, pushed | QC | done (7398649..b154e6e, review fixes included, pushed) |
| CP3a | M3 Tasks 3.1–3.4 (sheet adapter, dock, chrome, rows) | OR | done (b70853e..4793a91, pushed) |
| CP3b | M3 Tasks 3.5–3.6 (re-vendor, icon model, browser) | OR | done (c6c8d53..0f7a2da, pushed) |
| CP3c | M3 Tasks 3.7–3.9 (slots/drawers, broker, docs), pushed | OR | done (8e21b14..1058dc8; whole-branch review: 13 OR + 6 QC defects confirmed and fixed; pushed) |
| CP3d | Clear the two amber release gates from bundle 20261104-233516 | OR | done (729d23a placeFlyout split, f5420fb equipPlan re-pinned: the rise is the test recorder's registration survey; 5/5 test runs green; bundle 20261105-004501 **green**; pushed; stash dropped) |
| CP4 | Owner's in-game smoke pass; fixes on the branches | all | done 2026-11-05: feedback taken into round 2 (`docs/superpowers/plans/2026-11-05-smoke-round-2.md`, branch `feat/2026-11-05-smoke-round-2`) |
| CP5 | Owner go-ahead → merge all three, push, delete run branches/stashes/worktrees | all | todo |

M1 and Tasks 3.1–3.4 are independent and run in parallel. M2 and Tasks 3.5–3.6 wait for CP1.

### Resume notes (2026-11-05, owner restarted the machine)

State when paused (all three branches pushed, nothing merged, all working trees clean):

- **LibKa0s** `feat/2026-11-04-icon-browser` at `cad1609` = tag `v1.86.0` (pushed).
- **QuickComms** `feat/2026-11-04-icon-browser-revendor` at `b154e6e` (pushed). Green: 1706 passed, luacheck 0/0.
- **OutfitterReborn** `feat/2026-11-04-sheet-window-feedback` at `1058dc8` (pushed; this ledger commit on top). Green: 1383 passed, luacheck 0/0.
- Upstream done and pushed: WowAddonStandards `baebb21` (v2.101.0, events-frames-taint-§9 wow-ui-source), dev-copilot `f55715c` (2.7.0).

**CP3d — what is left.** The last automated-test bundle (`docs/automated-tests/20261104-233516/`) is **amber**; the
bundle before this round (`20261104-134211`) was green. Both regressions came in this round:

1. `placeFlyout` in `modules/QuickSlots.lua` is CCN 18 (cap 15). Split the anchor choice from the host-settings
   read, no behavior change. A partial, **unverified** attempt by the stopped agent is parked in
   `git stash` as `wip-cp3d: partial placeFlyout CCN refactor` (28+/18- in QuickSlots.lua): inspect it
   (`git stash show -p stash@{0}`), apply or drop it, and drop the stash either way (CP5 cleans stashes).
2. `tests/perf.lua` `equipPlan` allocates 229584.1 bytes/iter vs a 229000 ceiling (passed before this
   round). Find the cause on the equip-plan path (`git diff master..HEAD`); remove avoidable waste, or re-pin
   the ceiling per `docs/performance.md`'s rule with the reason recorded. Never bump it bare.
3. One gate run during Task 3.9 saw a test failure that did not recur: run `lua tests/run.lua` five times
   and chase any flake test-first.
4. Green gate, then a fresh bundle via `tests/_kit/run-automated-tests.sh` (AUTOMATED_TESTS.md) — target
   **green** — commit, `git push origin feat/2026-11-04-sheet-window-feedback`. Mark CP3d done.

Then **CP4**: hand the owner `docs/smoke-tests.md` §11 (one concrete pass per sheet: stock, EllesmereUI,
Chonky) and the three branch names. Then **CP5** on the owner's go-ahead only.

Cleanup inventory for CP5 (everything this run created): branches `feat/2026-11-04-icon-browser` (LK),
`feat/2026-11-04-icon-browser-revendor` (QC), `feat/2026-11-04-sheet-window-feedback` (OR), locally and on
origin; the CP3d stash was dropped at CP3d (2026-11-05). No worktrees remain (the scratch ones were removed). The
`v1.86.0` tag stays. The wow-ui-source clone lived in the session scratchpad and is gone after a restart:
re-clone `https://github.com/Gethe/wow-ui-source` (`live`, was `297d7aa`) if a Blizzard symbol needs checking.

Execution guidelines from the owner (still binding): ask only when necessary; commit incrementally on the
branches; push after milestones; never merge without the go-ahead; ultracode workflows for substantive work.

---

## M1 — LibKa0s: `LibKa0s-IconBrowser-1.0` (repo `../LibKa0s`)

Source to lift: `QuickComms/settings/IconBrowser.lua` (824), `IconBrowser_Sources.lua` (250), `ModalWindow.lua` (the parts the browser uses), the glyph helpers in `QuickComms/modules/Library.lua:272-316` (`IsGlyph`, `ValidIconColor`, `IconTint`, `IconColorFrom`), `modules/IconStyle.lua:135-179` (`WindowIcon`, `WindowEdge`, `NativeEdge`), `core/Compat.lua:392-428` (`MacroIcons`), and the ~60 strings at `QuickComms/locales/enUS.lua:1152-1213`.

### Task 1.1: Sources with descriptor tabs

**Files:**
- Create: `LibKa0s/IconBrowserSources.lua` (pure; Media + Compat only)
- Modify: `LibKa0s/LibKa0s.xml` (after the Options group: the browser uses `TabStrip`, `CreatePanel`, `AttachTooltip`), `tests/majors.lua` (new row)
- Test: `tests/test_icon_browser_sources.lua` (add to `tests/run.lua` SUITES)

**Interfaces:**
- Produces: `local IB = LibStub("LibKa0s-IconBrowser-1.0")`; `IB.BUILTIN_TABS = { "markers", "game", "glyphs" }`; a tab descriptor `{ key=string, label=string, tooltip=string?, list=function(filter) -> icons(table), loaded(bool), name=function(icon)->string?, owns=function(icon)->bool, swatch=bool }`; `IB.Sources.TabFor(icon, tabs) -> key|nil` (host tabs checked first, in order); `IB.Sources.List(tab, filter)`; `IB.Sources.Label(tab, icon)`; glyph helpers `IB.IsGlyph(path)`, `IB.ValidColor(hex)`, `IB.ColorFrom(r,g,b) -> "rrggbb"|false` (false for white), `IB.Tint(hex) -> r,g,b`; `IB.MacroIcons()`.

- [ ] **Step 1:** Write failing tests: `sources: a host tab owns its fileIDs before game does` (a host tab `{key="rec", owns=function(i) return i==135349 end}` → `TabFor(135349, tabs) == "rec"`, and `TabFor(135350, tabs) == "game"`); `sources: hidden built-in tabs are not offered` (tabs built from `{ hide = { markers = true } }` → `TabFor("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", tabs) == nil`); `sources: ColorFrom gives false for white and lowercase hex otherwise` (`ColorFrom(1,1,1) == false`, `ColorFrom(1,0.5,0) == "ff8000"`); and the moved Quick Comms source cases (search memo, labels, `Texture id %d`).
- [ ] **Step 2:** `lua tests/run.lua` → the new suite FAILs (module not found).
- [ ] **Step 3:** Implement `IconBrowserSources.lua`: Quick Comms' `IconBrowser_Sources.lua` with `B.TABS`/`Src.TabFor`/`Src.List`/`Label`/search moved onto per-tab descriptors. The three built-ins become descriptors; `GLYPH_LABELS` stays as the glyph tab's default label map. Minor 1, `lib.MODULES.IconBrowserSources = 1`.
- [ ] **Step 4:** `lua tests/run.lua` → PASS; luacheck 0/0.
- [ ] **Step 5:** Commit `IconBrowser: sources as tab descriptors, host tabs and hidden built-ins`.

### Task 1.2: The browser window as a library member

**Files:**
- Create: `LibKa0s/IconBrowser.lua` (shell; window, toolbar, grid, hint, footer). Split a `IconBrowserWindow.lua` secondary file paired on the shell's minor if it passes the layout-§1 size band.
- Test: `tests/test_icon_browser.lua` (port Quick Comms' 37 cases, re-pointed at the library), `tests/run.lua`

**Interfaces:**
- Consumes: Task 1.1.
- Produces: `IB:New(spec) -> browser`, where `spec = { owner=string (skin owner, the host's folder), title=string (the host's brand), layers={ strata=string, level=number, over=number }, helpers=<the host's LibKa0s Options instance>, tabs={ <descriptor>... } (host tabs, shown first), hide={ markers=bool, game=bool, glyphs=bool }, print=function(line), inCombat=function()->bool, schedule=function(sec, fn)->handle, cancel=function(handle), copyWindow=function(...)?, trackPicker=function(picker)?, releasePicker=function()? }`. The browser: `browser:Open({ icon, color, onChoose=function(icon, color|nil), owner=string, lift={names}?, valid=function()->bool? }) -> bool`; `:Choose() -> true | false, "notOpen"|"combat"|"noSelection"`; `:Cancel(owner?)`; `:IsOpen()`; `:Select(icon)`; `:SetTab(key)`; `:SetSearch(text)`; `:SetColor(hex|nil)`; `:State()`; `:StandDown()` / `:StandUp()` (the host calls these from its lifecycle; the library registers no bus messages). Value shapes handed to `onChoose`: marker path string; game fileID number; glyph Media path string plus `"rrggbb"` or nil for white.

- [ ] **Step 1:** Port the Quick Comms browser suite; add `browser: a host tab is listed first and preselected for its icon`, `browser: a hidden built-in tab has no strip button and SetTab refuses it`, `browser: Choose in combat answers false, "combat" and calls nothing`, `browser: two instances do not share selection or search`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement by lifting `IconBrowser.lua` and the browser's part of `ModalWindow.lua`. Every Quick Comms-only dependency becomes a `spec` field: `NS.BRAND` → `spec.title`; `NS.Constants.LAYERS` → `spec.layers`; `qc.*` tokens → library owner tokens `ib.selStrong`, `ib.note`, `ib.markGray`, `ib.modalDim` with the same values; `QC:ScheduleTimer` → `spec.schedule`; the `SettingsPanel` OnHide hook and `LIBRARY_CHANGED`/`PROFILE_CHANGED` handlers stay in the host (the host calls `Cancel`). Strings → `lib.STRINGS` (same English).
- [ ] **Step 4:** Run → PASS; luacheck 0/0.
- [ ] **Step 5:** Commit `IconBrowser: the window as a library member, host-configured`.

### Task 1.3: Docs, release v1.86.0, push (CP1)

**Files:** `docs/api/IconBrowser/version-1.1-docs.md` (new), `docs/api/README.md`, `docs/api/CONSUMERS.md` (QuickComms, OutfitterReborn as pending), `docs/releasing.md` (step-2 minor constants; the Library-drawn icons table gains any mark the browser draws, e.g. `search`, `close`), `CHANGELOG.md` (`## v1.86.0 — 2026-11-04`), `README.md` version, `docs/test-cases.md`.

- [ ] **Step 1:** Write the API doc and run `lua tools/gen-api-members.lua`; `test_versioning` must pass.
- [ ] **Step 2:** Follow `docs/releasing.md` steps 1–9 as written for `1.86.0` (including `lua tests/run.lua --list > docs/test-cases.md` and `tests/_kit/run-automated-tests.sh --release 1.86.0` on a clean tree).
- [ ] **Step 3:** Commit, merge nothing; tag `v1.86.0` on the branch head; `git push -u origin feat/2026-11-04-icon-browser` and `git push origin v1.86.0`.
  - *Note:* the tag is on the feature branch; the merge to master waits for the owner (CP5). The re-vendors copy from the tag, so they do not need master.
- [ ] **Step 4:** Ledger CP1 → done; commit the plan in OR.

## M2 — Quick Comms onto the library browser (repo `../QuickComms`)

### Task 2.1: Re-vendor v1.86.0 and swap the browser

**Files:**
- Modify: `libs/LibKa0s/`, `tests/_kit/` (copy from tag `v1.86.0`), `CLAUDE.md` provenance line, `settings/IconBrowser.lua` (becomes a thin adapter: builds `IB:New{...}` once with QC's title, layers, helpers, timers; keeps `Settings.IconBrowser.Open/Cancel/IsOpen/...` as pass-throughs so callers do not change), `settings/Editors.lua`, the host bus handlers that call `Cancel`.
- Delete: `settings/IconBrowser_Sources.lua`, the moved helpers' bodies (`Library.IsGlyph` and the rest become one-line calls into `IB` or stay as callers' aliases), TOC lines.
- Test: QC's `tests/test_icon_browser.lua` shrinks to the adapter cases (it opens through `Settings.IconBrowser`, Choose writes a group's icon and color, the popup's lift, stand-down cancels). Everything else now lives in LibKa0s. Update `tests/run.lua` skinValues allow rows (`:166-169`) to the `ib.*` tokens.

- [ ] **Step 1:** Re-vendor per `LibKa0s/docs/releasing.md:276-430` (copy, both `diff -r` checks, provenance line, `lua tools/prune-icons.lua QuickComms` from LK).
- [ ] **Step 2:** Run QC's suite → expect the browser cases to fail against the swapped adapter; port them.
- [ ] **Step 3:** Implement the adapter; no behavior change a player can see.
- [ ] **Step 4:** `lua tests/run.lua` and luacheck → green.
- [ ] **Step 5:** Commit `Re-vendor LibKa0s v1.86.0; the icon browser is the library's`; push branch (CP2).

## M3 — Outfitter Reborn (this repo, branch `feat/2026-11-04-sheet-window-feedback`)

### Task 3.1: The sheet adapter

**Files:**
- Create: `modules/Sheet.lua` (add to TOC before `modules/Dock.lua`)
- Test: `tests/test_sheet.lua` (SUITES), mocks for `EUI_CharSheet_Equipment`, `CharacterFrameBgbg`, `PaperDollSidebarTab3` in `tests/wow_mock.lua`

**Interfaces:**
- Produces: `NS.Sheet.Kind() -> "stock"|"eui"|"chonky"` (re-evaluated on each sheet show); `NS.Sheet.Frame() -> frame` (the visible sheet: `CharacterFrame` for stock and EUI, `CharacterFrameBgbg` for Chonky); `NS.Sheet.ButtonAnchor() -> point, relFrame, relPoint, x, y, size` (stock/Chonky: `"LEFT", PaperDollSidebarTab3, "RIGHT", 4, 0`, size from `PaperDollSidebarTab3:GetSize()` — 33×35 from `PaperDollSidebarTabTemplate`; Tab3 sits at `PaperDollSidebarTabs` BOTTOMRIGHT -30,0, leaving 30 px, so the button overhangs the 168-px container by ~7 px, `wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:475-503`; EUI: `"LEFT", EUI_CharSheet_Equipment, "RIGHT", 2, 0`, 20); `NS.Sheet.DockRight() -> x, top` (the right edge of the sheet or of the rightmost shown Chonky side panel among `ccsf_af`, `ccsm_af`, `ccsrf_af`, `ccsgf_af`; the sheet's top).
- Detection: EUI = `IsAddOnLoaded("EllesmereUIBlizzardSkin")` and `_G.EUI_CharSheet_Equipment` exists and is shown; Chonky = `IsAddOnLoaded("ChonkyCharacterSheet")` and `_G.CharacterFrameBgbg` exists and is shown. Otherwise stock.

- [ ] **Step 1:** Failing tests: `sheet: stock by default`; `sheet: EllesmereUI with its equipment tab shown is eui`; `sheet: EllesmereUI loaded with the blizzard style resolves to stock` (addon loaded, no `EUI_CharSheet_Equipment`); `sheet: Chonky with its backdrop shown is chonky`; `sheet: Chonky skipped its setup (backdrop hidden) resolves to stock`; `sheet: DockRight takes the rightmost shown Chonky side panel`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → PASS; luacheck.
- [ ] **Step 5:** Commit `Sheet: one adapter for the stock, EllesmereUI and Chonky character sheets`.

### Task 3.2: The sheet button and the flush dock

**Files:** Modify `modules/Dock.lua` (`buildSheet`, `positionWindow`, `Y_OFFSET`), `core/Constants.lua` (an accent tint for the button, e.g. `SHEET_BUTTON_TINT`), `CLAUDE.md` icons line (+ `ph:coat-hanger`, + `ph:gear-six`), the vendored icon files via `prune-icons` from the LK tag. Test: `tests/test_dock.lua`, `tests/dock_scene.lua`.

**Interfaces:** Consumes `NS.Sheet.*`. Produces `NS.Constants.DEFAULT_OUTFIT_ICON = NS.Icon("ph:coat-hanger")` (used by 3.5, 3.7).

- [ ] **Step 1:** Failing tests: `dock: the sheet button sits right of the Equipment Manager tab` (stock: its anchor is `PaperDollSidebarTab3` RIGHT +4); `dock: on EllesmereUI the button follows the Equipment label`; `dock: the button is parented to CharacterFrame and above the close button's level`; `dock: the button's icon is the coat hanger, tinted, with no border`; `dock: the window's top is flush with the sheet's top` (`Y_OFFSET == 0`; the window's TOPLEFT y equals `NS.Sheet.Frame():GetTop()` scaled); `dock: an open Chonky side panel pushes the window right`; stood-down: the button is hidden.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement. Re-anchor the button on every sheet show (the kind can change after `/reload` with another addon). Keep the follow driver and the parking fallback as they are; only the source of `right/top` changes to `NS.Sheet.DockRight()`. Borderless: `NS.Skin.Button(btn, { noBg = true, noBorder = true })`, then tint `btn.icon` with the constant.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `Dock: the sheet button beside the Equipment Manager tab; the window flush with the sheet`.

### Task 3.3: Window chrome — close X and borderless icon buttons

**Files:** Modify `modules/Window.lua:118-171`. Test: `tests/test_window.lua` (or the suite that owns the window header; find with `grep -l OutfitterRebornWindowSettings tests/`).

- [ ] **Step 1:** Failing tests: `window: the close button is anchored at the header's top right` (a point exists, `TOPRIGHT`, x ≈ -6); `window: the gear sits left of the close button`; `window: the header gear has no border` (it was skinned with `noBorder`).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Anchor `close` at `TOPRIGHT, f, TOPRIGHT, -6, -5`; keep the gear at -28. Header gear and the New outfit mark use `{ noBg = true, noBorder = true }`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `Window: the close button shows; the header icons lose their borders`.

### Task 3.4: The row — outfit icon, EM icon, borderless lightning, gear menu (CP3a)

**Files:** Modify `modules/Window_Rows.lua:220-331`. Test: `tests/test_window_rows.lua` (or the owning suite).

**Interfaces:** Consumes `NS.OutfitIcon(rec) -> texture, r, g, b` from Task 3.5. Until 3.5 lands, call `NS.Bar.OutfitIcon(rec)` behind the same local, so this task does not wait.

Layout (row 228×18): worn checkbox 16 at LEFT +14; outfit icon 16 at LEFT +32; EM icon 16 at LEFT +50; name LEFT +68 → RIGHT -38; lightning 12 at RIGHT -22 (a `Mark`, no border); gear 14 at RIGHT -4 (`ph:gear-six`, borderless button, opens `NS.OutfitMenu.Open`).

The EM icon is a Button (not a CheckButton) whose texture is `PAPERDOLL_SIDEBARS[3].icon` with `.texCoords`, read at run time (`wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:97-100`: `Interface\PaperDollInfoFrame\PaperDollSidebarTabs`, `{0.015625, 0.53125, 0.46875, 0.60546875}`); alpha 1 when `NS.Outfits.IsEM(id)`, else 0.35; its click runs the existing `onEmClick` logic with the toggled state.

- [ ] **Step 1:** Failing tests: `rows: an outfit row shows worn, icon, EM mark, name in that order` (x offsets as above); `rows: the EM mark is full for an EM outfit and dimmed otherwise`; `rows: clicking the dimmed EM mark stores the outfit on the server, as the checkbox did`; `rows: clicking the EM mark in combat refuses and changes nothing`; `rows: the menu control is a borderless gear that opens the outfit menu`; `rows: the lightning has no border`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement. Item rows (Odds 'n ends) keep `row.icon` as today.
- [ ] **Step 4:** Run → PASS; luacheck.
- [ ] **Step 5:** Commit `Rows: outfit icon, Equipment Manager mark, borderless lightning and gear menu`. Ledger CP3a → done.

### Task 3.5: Re-vendor v1.86.0 and the icon model

**Files:**
- Modify: `libs/LibKa0s/`, `tests/_kit/` (from tag `v1.86.0`), `CLAUDE.md` (provenance `v1.86.0`; `LibKa0s icons: all (icon browser).`), `modules/Outfits_Schema.lua:27-71`, `modules/Bar_Buttons.lua:52-69`, `modules/EquipmentManager.lua`, `core/Database.lua` (char default `emIcons = {}`).
- Create: nothing; the resolver moves to `modules/Outfits.lua` as `NS.OutfitIcon`.
- Test: `tests/test_outfit_icons.lua` (new SUITE), `tests/test_bar.lua:295-311`, `tests/test_em_sync.lua`.

**Interfaces:**
- Produces: `NS.OutfitIcon(rec) -> texture(number|string), r, g, b` (one resolver for row, bar and broker): own icon (with `iconColor` tint for a glyph), then for an EM outfit `db.char.emIcons[setID]` glyph override, then the trigger's icon, NAKED, the single item's icon, else `NS.Constants.DEFAULT_OUTFIT_ICON` (white). `NS.Outfits.SetIcon(id, icon, color|nil)`: native → `outfit.icon` + `outfit.iconColor` rows; EM + fileID → `NS.EM.SetIcon` and clears `emIcons[setID]`; EM + glyph → `emIcons[setID] = { icon=path, color=hex }`, EM set untouched. EM set deletion clears `emIcons[setID]`.
- Schema: `outfit.icon` accepts nil, a positive integer, or a string the library's `IB.IsGlyph` accepts; `outfit.iconColor` new row, `"rrggbb"` or nil. 134400 still maps to nil.

- [ ] **Step 1:** Re-vendor (copy, diffs, provenance, `prune-icons`), run the suite: green before any change.
- [ ] **Step 2:** Failing tests: `icons: a 1.1.0 fileID draws as before`; `icons: no icon falls through trigger, item, then the coat hanger`; `icons: a glyph with a color tints`; `icons: 134400 stores nil`; `icons: a glyph on an EM outfit is kept per character and the set is not modified`; `icons: a fileID on an EM outfit goes to the set and clears the override`; `icons: deleting an EM set clears its override`; update `test_bar` to expect the coat hanger in place of 132662.
- [ ] **Step 3:** Run → FAIL.
- [ ] **Step 4:** Implement; `Bar_Buttons.lua` calls `NS.OutfitIcon` and sets vertex color; Task 3.4's row switches to it.
- [ ] **Step 5:** Run → PASS; commit `Re-vendor LibKa0s v1.86.0; one outfit icon resolver with the coat hanger default and glyphs`.

### Task 3.6: Change icon… opens the library browser (CP3b)

**Files:** Delete `modules/IconChooser.lua` (and its TOC line); create `modules/IconBrowserSetup.lua` (builds `IB:New` once: owner = addon folder, title = `NS.BRAND`, layers from `NS.Constants.LAYERS` POPUP tier, `hide = { markers = true }`, host tabs Recommended and Equipped and bags built from today's IconChooser sets); modify `modules/OutfitMenu.lua:213`, `modules/Dock.lua:149`, `core/LifecycleSetup.lua:27` (StandDown/StandUp), `locales/enUS.lua` (the two tab labels, if not already keys). Tests: port `tests/test_dialogs.lua:298-395`, `tests/test_outfit_menu.lua:265`, `tests/dock_scene.lua:73`, `tests/test_dock.lua:331`, `tests/skin_surfaces.lua:169-171`.

**Interfaces:** Produces `NS.IconBrowser.Open(id) -> bool`, `NS.IconBrowser.Close(reason)`, `NS.IconBrowser.IsOpen()`. `onChoose(icon, color)` → `NS.Outfits.SetIcon(id, icon, color)`.

- [ ] **Step 1:** Failing tests: `browser: Change icon opens on Recommended with the outfit's icon selected`; `browser: no Markers tab`; `browser: choosing a glyph writes icon and color`; `browser: closing the window or the sheet closes the browser`; `browser: stood down, it cannot open`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** PASS + luacheck.
- [ ] **Step 5:** Commit `Change icon… opens the LibKa0s icon browser`. Ledger CP3b → done.

### Task 3.7: Slot boxes and the outward drawer

**Files:** Modify `modules/SlotEnables.lua:27-28,145-160`, `modules/QuickSlots.lua` (install the flyout hooks). Test: `tests/test_slot_enables.lua`, `tests/test_quickslots.lua` (owning suites; find with grep).

Columns: LEFT = Head, Neck, Shoulder, Back, Chest, Shirt, Tabard, Wrist. RIGHT = Hands, Waist, Legs, Feet, Finger0, Finger1, Trinket0, Trinket1 (fixes today's `RIGHT_SIDE`, which misses Hands–Feet). BOTTOM = MainHand, SecondaryHand.

- Boxes 14×14. LEFT column: `TOPRIGHT` of the slot (+2, +2). RIGHT column: `TOPLEFT` (-2, +2). BOTTOM: `TOPRIGHT`.
- Drawer, **only while `NS.Dock.IsShown()`** and not stood down, LEFT column only. Verified at
  `wow-ui-source@297d7aa` (`live`): the right column already has its arrow on the slot's right
  (`Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:1527-1532`, `LEFT` → slot `RIGHT` -8,0) and opens
  right (`Blizzard_FrameXML/EquipmentFlyout.lua:339`), so it needs nothing.
  - **Arrow**: Blizzard anchors `slot.popoutButton` once, in `PaperDollItemSlotButton_OnLoad`
    (`PaperDollFrame.lua:1515-1534`); nothing re-anchors it later. On window show (out of combat),
    re-anchor each LEFT-column arrow `RIGHT` → slot `LEFT` +8,0 and mirror its texcoords; on window hide
    or stand-down, restore Blizzard's exact `LEFT` → slot `RIGHT` -8,0 and its unreversed texcoords
    (`:1529-1532`).
  - **Arrow direction**: `hooksecurefunc("EquipmentFlyoutPopoutButton_SetReversed", fn)`
    (`EquipmentFlyout.lua:633-651`): for a LEFT-column arrow while active, apply the mirrored pair of
    the coords Blizzard just set.
  - **Flyout**: placement happens in `EquipmentFlyout_UpdateItems`, not `_Show`
    (`EquipmentFlyout.lua:238-339`): `flyout.buttonFrame` is anchored `TOPLEFT` → `relativeAnchor`
    (`itemButton.popoutButton or itemButton`) `TOPRIGHT` + (`anchorX`, `anchorY`) from
    `PaperDollItemsFrame.flyoutSettings` (`PaperDollFrame.lua:343-354`: 0, -3). Post-hook
    `EquipmentFlyout_UpdateItems`: when `EquipmentFlyoutFrame.button` is a LEFT-column slot and the
    window is shown, `buttonFrame:ClearAllPoints()` and anchor `TOPRIGHT` → `relativeAnchor` `TOPLEFT`
    (-anchorX, anchorY). The background textures hang off `buttonFrame`, so they follow.
  - Blizzard's `flyoutSettings` table is never written. BOTTOM untouched. Never in combat lockdown.
  - Each hook is guarded by `type(_G[name]) == "function"`; the mock grows the same names.

- [ ] **Step 1:** Failing tests: `slots: boxes are 14 px`; `slots: Hands is in the right column and its box is top-left`; `slots: Head's box is top-right`; `drawer: with the window open a left-column flyout's buttonFrame is anchored TOPRIGHT to the arrow's TOPLEFT`; `drawer: a right-column flyout is left alone`; `drawer: SetReversed on a left-column arrow mirrors its coords`; `drawer: with the window closed the flyout keeps Blizzard's anchors`; `drawer: closing the window restores the left-column arrows`; `drawer: stood down nothing is moved`; `drawer: a missing Blizzard function installs nothing and errors nothing`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5:** Commit `Slots: smaller boxes on the inner corner; the drawer opens outward while the window is open`.

### Task 3.8: The Outfits broker object

**Files:** Create `modules/Broker.lua` (TOC after `core/LauncherSetup.lua`); modify `locales/enUS.lua`. Test: `tests/test_broker.lua` (SUITE), `tests/test_disabled.lua`.

**Interfaces:**
- Consumes: `NS.Stack.Top/CurrentInfo/IsWorn/Wear/Remove`, `NS.Outfits.Categories`, `NS.WindowListModel.SortedIds(category)` and `.Status(id, cache)`, `Window_Rows.STATUS_TOKEN`, `NS.OutfitIcon`, `NS.Popups.ShowSetCurrent(id)`, `NS.OpenMenu(anchor, fill)`, `NS.RunVerb("auto", "on"|"off")`, `NS.Dock.Toggle(true)`.
- Produces: `NS.Broker.Object()`; LDB name `OutfitterRebornOutfits`, `type = "data source"`, `label = NS.BRAND .. ": " .. L["Outfits"]`.

Behavior: `text`/`icon` = the top outfit's name and `NS.OutfitIcon`; none or stood down → `NS.BRAND` and the tinted coat hanger. Updated on the stack's change message and on stand-up/down. Left-click → `NS.OpenMenu`: title (brand), "Open outfit window", "Automatic changes" checkbox, then per category (window order) a title and one checkbox per visible outfit with its icon and status color; click → modifier: `ShowSetCurrent`; worn non-Complete: `Remove(id, {hw=true})`; else `Wear(id, {hw=true})`. Right-click → `NS.Dock.Toggle(true)`. Tooltip: brand, `L["Current outfit: %s"]`, `L["Left-click: choose an outfit"]`, `L["Right-click: outfit window"]`. Stood down: outfit entries are disabled and a click prints `NS.StoodDownRefusal()`. No LibDBIcon registration. Without LibDataBroker: no object, said once to the debug log.

- [ ] **Step 1:** Failing tests: `broker: a data source named OutfitterRebornOutfits exists and is not on the minimap`; `broker: text and icon follow the worn outfit`; `broker: no outfit shows the brand and the coat hanger`; `broker: left-click lists categories then outfits, worn ones checked, missing in the missing color`; `broker: clicking a worn accessory removes it; clicking a Complete wears it`; `broker: a modifier-click asks to set current`; `broker: right-click toggles the window`; `broker: in combat a wear is queued or refused as the window's is`; `disabled: the broker shows the brand and refuses outfit clicks`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5:** Commit `Broker: the Outfits data source, the old plugin's switcher`.

### Task 3.9: Docs, deviation, automated-test bundle, push (CP3c)

**Files:** `docs/ARCHITECTURE.md` (module map, the deviation row below), `docs/module-map.md`, `docs/data-flow.md`, `docs/settings-panel.md` if touched, `docs/known-limitations.md`, `docs/smoke-tests.md` (the CP4 checklist), `docs/test-cases.md` (`lua tests/run.lua --list`), `docs/taint.md` (the flyout hooks), `README.md` (feature text: the sheet button's place, the broker), `DEPENDENCIES.md` (LibKa0s v1.86.0).

Deviation row: `| launcher-§1 | A second LibDataBroker object, OutfitterRebornOutfits (type data source), carries the old addon's outfit switcher; the launcher object is unchanged | Owner ruling 2026-11-04: players used the old broker plugin to switch outfits, and the launcher's clicks and logo are fixed by launcher-§2/§4 | 2026-11-04 | The standard allows a feature data source next to the launcher |`

- [ ] **Step 1:** Write the docs; `docs/smoke-tests.md` gains a section *Sheet, window and broker (2026-11-04)* with checks for each sheet (button place, flush dock, Chonky side panel, slot boxes, drawers open/closed with the window), the close X, row layout, Change icon (each tab, glyph color, EM outfit), the broker (text, menu, clicks, tooltip, disabled).
- [ ] **Step 2:** Run `/dev-copilot:wow-automated-tests` (the full battery and bundle).
- [ ] **Step 3:** Commit `Docs: sheet adapter, icons, broker; the launcher-§1 deviation`; `git push -u origin feat/2026-11-04-sheet-window-feedback`. Ledger CP3c → done.

## CP4 — Owner's in-game pass

Hand the owner `docs/smoke-tests.md` → *Sheet, window and broker (2026-11-04)* with the three branch names. Fixes go on the same branches with the same gate; re-push. Do not merge.

## CP5 — Merge and clean up (only on the owner's go-ahead)

1. LibKa0s: merge `feat/2026-11-04-icon-browser` into master (fast-forward if possible; the `v1.86.0` tag must stay reachable), push.
2. Quick Comms, then Outfitter Reborn: merge, push.
3. Delete the three feature branches locally and on origin; `git stash list` and `git worktree list` in all three repos, drop/remove anything this run created.
4. Ledger CP5 → done; commit and push the plan.
