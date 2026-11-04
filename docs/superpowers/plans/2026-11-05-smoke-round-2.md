# Smoke round 2 — Implementation Plan

> **For agentic workers:** the run is driven by ultracode workflows (owner ruling). Each task is one
> implementer agent then one adversarial reviewer agent; the reviewer fixes what it confirms. Steps use
> checkbox syntax for tracking.

**Goal:** the owner's CP4 feedback on the 2026-11-04 round: default icon 132724 and spec icons, the
sheet button in each host's tab look, slot selectors / flyout arrow / flyout alignment, cascading
menus, the gear size, the outfit bar as a Ka0s HUD window, and test mode showing the window.

**Spec:** `docs/superpowers/specs/2026-11-05-smoke-round-2-design.md` (G1-G7, D1-D10) and its recon
evidence `docs/superpowers/specs/2026-11-05-recon/<area>.md`. Read both before any task.

**Tech:** Lua 5.1, retail 12.x, Ace3, LibKa0s v1.86.0 -> v1.87.0, the headless harness.

## Global Constraints

- The 2026-11-04 plan's Global Constraints all apply (standard, green gate per repo, CRLF, `L[...]`,
  combat rules, wow-ui-source citations, re-vendor from the tag, never hand-edit `tests/_kit/`).
- Green gate before every commit, per repo: `lua tests/run.lua` and
  `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0). Heavy runs only through
  `~/.claude/dev-copilot/bin/ka0s-bounded`.
- Branches (stacked on the unmerged 2026-11-04 branches): OutfitterReborn
  `feat/2026-11-05-smoke-round-2` (from `feat/2026-11-04-sheet-window-feedback`); LibKa0s
  `feat/2026-11-05-cascading-menus` (from `feat/2026-11-04-icon-browser`).
- Owner rulings: commit freely; LibKa0s tag `v1.87.0` and release allowed; push after each milestone;
  **never merge without the owner's go-ahead**; after the merge delete every branch, stash and worktree
  this run (and the 2026-11-04 run) created. No Outfitter Reborn version bump.
- Deviations: exactly two, both owner-ratified 2026-11-05: a new `skinning-§1`/`§9` row (D4) and a
  test-mode clause on the `standalone-windows` row (D10). Any other departure: stop and flag.

## Status ledger (resume from here)

Update the row and commit the plan at every checkpoint. A resumed run reads this table, `git log` in
both repos, and continues from the first row not `done`.

| CP | Milestone / task | Repo | State |
|---|---|---|---|
| CP0 | Design, recon evidence and this plan committed | OR | done |
| CP1 | LibKa0s v1.87.0: cascading menus (Task 1), released and pushed | LK | todo |
| CP2a | Tasks 2.1-2.3: default icon + spec rung, host-look sheet button, gear size | OR | done (3a062f8..66914ec; 132724 + SPEC_n rung, host tab/EUI label citing DEV-SKIN-SHEET-BUTTON, gear via S.CloseButton) |
| CP2b | Task 2.4: slot selectors, flyout arrow, flyout alignment | OR | done (25f50ed..79db327; host-strata boxes + accent edge, arrows shown with the window, flyout level with its slot) |
| CP2c | Task 2.5: outfit bar as a Ka0s HUD window | OR | done (68ea99f..e11c4ea; Bar_Layout/Bar_Chrome split, header band with lock+close, labels, icon border + worn highlight, FromSkin on every color, /or bar + binding) |
| CP2d | Task 2.6: test mode shows the window | OR | todo |
| CP3 | Task 3.1: re-vendor v1.87.0, cascading outfit menus (needs CP1) | OR | todo |
| CP4 | Task 4.1: docs, deviation rows, smoke §12, whole-branch review, bundle, push | OR | todo |
| CP5 | Owner's in-game pass of smoke §12 | all | todo |
| CP6 | Owner go-ahead -> merge both rounds in order, push, delete run branches/stashes/worktrees | all | todo |

CP1 runs in parallel with CP2a-CP2d (different repo). CP2a-CP2d run in order on one tree.

---

## Task 1 — LibKa0s: cascading menus (repo `../LibKa0s`) — CP1

**Files:** `Widgets.lua` (ContextMenu, EnsureMenu, Populate, __OutsideClick, CloseMenu), its tests,
`docs/api/Widgets*.md` (version doc), the CONSUMERS table, the library's changelog/version files.

- [ ] Branch `feat/2026-11-05-cascading-menus` from `feat/2026-11-04-icon-browser`.
- [ ] Tests first: a row with `submenu = rows` opens a child frame anchored to the row's right edge
  (left at the screen edge, clamped); the parent stays shown; opening a sibling submenu closes deeper
  levels; an outside click on none of the shown depths closes all; a click inside any depth does not;
  CloseMenu closes all; depth-1 OnHide closes all; a keepOpen click in a child repaints the child and
  every ancestor; optional `radio`/`selected` draw a tick; every existing single-level test unchanged.
- [ ] Implement as a Widgets minor bump (per-depth pooled frames, `menus[depth]`).
- [ ] Docs, CONSUMERS row, the library's release steps for `v1.87.0` (its own CLAUDE.md / docs say
  how: changelog, TOC/version, tag). Green gate. Commit, tag `v1.87.0`, push branch and tag.
- [ ] Ledger CP1 -> done (commit in OutfitterReborn's plan).

## Task 2.1 — Default icon 132724 and the spec rung — CP2a

**Files:** `core/Constants.lua`, `modules/Outfits.lua` (`NS.OutfitIcon`), `modules/Outfits_Seed.lua`,
`modules/Broker.lua`, `core/SkinSetup.lua`, tests (`test_skinsetup`, icon/broker/outfits tests).

- [x] Tests: no-icon multi-item outfit -> 132724 (white); a `builtin = "SPEC_2"` outfit with no icon ->
  that spec's icon even with its trigger removed; "Outfitter chooses" on it -> spec icon; an EM mirror
  adopted by name keeps its EM icon; broker idle icon is 132724 untinted.
- [x] Implement G1. Retire `SHEET_BUTTON_TINT` and `of.sheet.button` with their test pins.

## Task 2.2 — The sheet button wears the host's tab — CP2a

**Files:** `modules/Dock.lua` (buildSheet/placeButton/recheckSheet), `modules/Sheet.lua`
(ButtonAnchor/Kind), `locales/enUS.lua`, tests (`test_dock`, `test_sheet`, skin switch/values pins).

- [x] Tests: stock and Chonky build the tab textures with the template's coords and 33x35; selected
  state while the window shows; EUI builds a 64x25 text label above `EUI_CharSheet_Equipment` with the
  idle/hover/active colors and falls back when `ELLESMERE_GREEN` is absent; kind change re-places and
  re-looks; stood down hides it; combat-safe (insecure).
- [x] Implement G2. Skin-values rows cite the D4 deviation (row text written in Task 4.1; reserve
  its id now and use it consistently). Reserved id: `DEV-SKIN-SHEET-BUTTON` (the kit's cause-id
  pattern takes upper case, digits and hyphens only).

## Task 2.3 — Gear icon size — CP2a

- [x] `modules/Window.lua`: gear texture centred at the close's art size (fallback 12), the X's tint
  and hover. Test in `test_dock`. Commit, ledger CP2a -> done, push.

## Task 2.4 — Slots, arrow, alignment — CP2b

**Files:** `core/Constants.lua` (LAYERS strata order, cap), `modules/SlotEnables.lua`,
`modules/QuickSlots.lua`, `tests/test_slot_enables.lua`, `tests/test_quickslots.lua`.

- [x] Tests (recon `slots.md` lists them): HIGH slots under a MEDIUM CharacterFrame lift the container
  to HIGH above HIGH frames only; a MEDIUM 9000 sibling no longer inflates the level; restack on a
  strata-only change; arrows shown on every slot while the window shows, hidden otherwise unless the
  EM pane is shown, re-shown after HideAll while wanted, none stood down, nothing written in combat;
  right-column flyout's first item level with its slot; left-column outward likewise; a moved frame
  gets Blizzard's point back; vertical and other hosts untouched.
- [x] Implement G3, keep every function at CCN <= 15. Commit, ledger CP2b -> done, push.

## Task 2.5 — The outfit bar as a Ka0s HUD window — CP2c

**Files:** `modules/Bar.lua` (split, e.g. `Bar_Layout.lua`, `Bar_Header.lua`), `modules/Bar_Buttons.lua`,
`settings/OutfitBar.lua`, `settings/Schema.lua`, `defaults/Profile.lua`, `settings/Slash.lua`,
`Bindings.xml` + its labels module, `locales/enUS.lua`, tests (`test_bar`, `test_settings`,
`skin_surfaces`, slash/binding tests), perf `barRender` if it moves (re-pin only with a reason).

- [x] Study DpsRace's race HUD (`../DpsRace/modules/Style.lua` and its HUD module) and recon `bar.md`.
- [x] Tests first for: header band and title, drag by header, lock/close controls writing the same
  paths, layout (per line wrap, padding, spacing, size, grow direction keeping the saved corner),
  labels on/off and per section, FontGroup/BorderGroup/ColorPair rows with FromSkin companions,
  `/or bar show|hide|toggle`, the binding, test strip under the band, degraded load (no Band).
- [x] Implement G6. Every new color has its FromSkin bool (skinning-§6). Commit, ledger CP2c -> done,
  push.

## Task 2.6 — Test mode shows the window — CP2d

**Files:** `modules/Preview.lua`, `modules/Dock.lua`, `modules/Window.lua`, `modules/Window_ListModel.lua`,
`modules/Window_Rows.lua`, `modules/SlotEnables.lua` (clear selection), `locales/enUS.lua`, tests.

- [ ] Tests (recon `test.md`): `/or test` with the sheet closed shows the window alone at the stock
  position via the single TOPLEFT point; sheet open docks it; samples listed, no item sections; every
  row handler refuses `preview:` ids quietly; New outfit disabled; selection cleared; X/Escape hides
  for the session without ending test mode; combat ends test mode and hides the alone window before
  lockdown; strip on window and under the bar's band; degraded strip fallback title.
- [ ] Implement G7. Commit, ledger CP2d -> done, push.

## Task 3.1 — Re-vendor v1.87.0 and cascading outfit menus — CP3 (after CP1)

- [ ] Re-vendor LibKa0s from tag `v1.87.0` the standard way (`/dev-copilot:wow-revendor-libka0s`
  semantics: copy `libs/LibKa0s/` and `tests/_kit/` whole, roll CLAUDE.md's provenance line, keep the
  icons line, revendor bundle `docs/revendor/<date>-v1.87.0/`).
- [ ] `core/WidgetsSetup.lua` `NS.OpenMenu` builds the whole tree and uses `submenu`; classify rows
  keep-open (radio ticks) vs act-and-close per design G4; MenuUtil fallback returns Refresh only for
  keep-open. Tests in `test_outfit_menu`. Commit, ledger CP3 -> done, push.

## Task 4.1 — Docs, deviations, smoke §12, review, bundle — CP4

- [ ] `docs/ARCHITECTURE.md` deviations: the new `skinning-§1`/`§9` row (D4) and the
  `standalone-windows` test-mode clause (D10); the 2026-11-03 design's H17 marked reversed. Module map,
  data flow, schema, settings panel, slash dispatch (`bar` verb, verb count), taint (popout Show/Hide,
  HideAll hook), frame layering (host strata), known limitations, `docs/test-cases.md`, README
  features.
- [ ] `docs/smoke-tests.md` §12 *Smoke round 2 (2026-11-05)*: per sheet (stock, EllesmereUI, Chonky):
  button look and selected state, selectors visible, arrows, flyout alignment both columns; menus;
  gear; bar options; test mode alone/docked.
- [ ] Whole-branch adversarial review (both repos), fix confirmed defects, green gate.
- [ ] `/dev-copilot:wow-automated-tests` bundle, target green; commit; push both branches. Ledger CP4.

## CP5 — Owner's in-game pass

Hand the owner `docs/smoke-tests.md` §12 and the branch names. Fixes go on the same branches.

## CP6 — Merge and clean up (only on the owner's go-ahead)

1. LibKa0s: merge `feat/2026-11-04-icon-browser` then `feat/2026-11-05-cascading-menus` into master;
   tags `v1.86.0` and `v1.87.0` stay reachable; push.
2. QuickComms: merge `feat/2026-11-04-icon-browser-revendor`; push.
3. OutfitterReborn: merge `feat/2026-11-04-sheet-window-feedback` then `feat/2026-11-05-smoke-round-2`;
   push.
4. Delete the five feature branches locally and on origin; drop any run stashes; remove any worktrees.
5. Both plans' ledgers -> done; commit and push.
