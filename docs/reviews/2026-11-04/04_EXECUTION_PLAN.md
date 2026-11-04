# Execution plan — P8 review changes

Ten changes (C-01 to C-10) for ten findings (F-001 to F-010), in four milestones. There is no
upstream milestone: no finding lands in `libs/` or `tests/_kit/`. Every commit passes the green gate
(`lua tests/run.lua` and `ka0s-bounded luacheck .`, 0/0). Where a case is added, `docs/test-cases.md`
(from `lua tests/run.lua --list`) and the README `[tests]` badge move in that same commit. Nothing is
staged, committed or pushed without the owner's instruction (`CLAUDE.md`).

## M1 — Engine invariants (F-001, F-002, F-006)

**Done when:** an idle bracket sends no `STACK_CHANGED`, the binder holds no binding before the first
LoadPass, both are pinned by falsifiable cases, and the suite is green at **+2 cases**.

| Task | Owner role | Implements | Files |
|---|---|---|---|
| M1-T1 | lua-refactorer | C-01 (F-001) | `modules/Equip.lua`, `modules/OutfitStack.lua` (`E.Touch` call sites), `modules/Window.lua` |
| M1-T2 | test-author | C-06 suite case (F-006), guarding C-01 | `tests/test_stack.lua` (or `tests/test_dock.lua`), `docs/test-cases.md`, `README.md` badge |
| M1-T3 | lua-refactorer | C-02 (F-002) | `modules/Triggers_Binder.lua` |
| M1-T4 | test-author | C-02's case, and re-reading the binder cases that assumed bind-at-Resume | `tests/test_trigger_binder.lua`, `docs/test-cases.md`, `README.md` badge |

**Checkpoint CP-1:** the owner reads the diff of every pre-existing case M1-T4 touched. Such a case
may only move in the direction C-02 changes, and never be weakened. Then run S-01 and S-02 in the
client before M2.

## M2 — Unit filter and locale (F-003, F-004)

**Done when:** Spellcast and the vehicle triggers register through the binder's player unit-filter
frame, `test_disabled` still empties the registration set, and the frFR and koKR patterns match
their captured lines. Suite green at **+4 cases** cumulative.

| Task | Owner role | Implements | Files |
|---|---|---|---|
| M2-T1 | wow-event-wiring | C-03 (F-003) | `modules/Triggers_Binder.lua`, `modules/PlayerState.lua` (comment only) |
| M2-T2 | test-author | C-03's case | `tests/test_trigger_binder.lua`, `docs/test-cases.md`, `README.md` badge |
| M2-T3 | human (client) | S-04 step 1: capture the frFR and koKR `Use:` lines | none (writes the fixture text into the task) |
| M2-T4 | locale-fixer | C-04 (F-004), after M2-T3 | `locales/frFR.lua`, `locales/koKR.lua`, `modules/Inventory_Lists.lua`, `tests/test_locale.lua` (or a new fixture), `docs/test-cases.md`, `README.md` badge |

**Checkpoint CP-2:** S-03 and S-04 step 2 in the client.

## M3 — Evidence (F-005, F-006 scenario, F-007)

**Done when:** `tests/perf.lua` carries the `tooltipsAbsent` arm and the `dockIdle` scenario, both
pinned, and all six bracket sites use the file-scope upvalue. The perf runner reports 0 failures.

| Task | Owner role | Implements | Files |
|---|---|---|---|
| M3-T1 | perf-harness | C-05 (F-005) | `tests/perf.lua`, `tests/perf_scenes.lua`, `docs/performance.md` |
| M3-T2 | perf-harness | C-06 scenario (F-006) | `tests/perf.lua`, `tests/perf_scenes.lua`, `docs/performance.md` |
| M3-T3 | lua-refactorer | C-07 (F-007) | `modules/Dock.lua`, `modules/Bar.lua`, `modules/Inventory.lua`, `modules/States.lua`, `modules/States_Zone.lua`, `modules/Tooltips.lua` |

**Checkpoint CP-3:** S-05, one full two-arm capture, committed as a frozen `docs/perf-analysis/`
bundle.

## M4 — Hygiene (F-008, F-009, F-010)

**Done when:** login calls `NS.StandUp()`, deleted outfits' targets are recycled with a case pinning
it, and the `cache` argument is gone. Suite green at **+5 cases** cumulative.

| Task | Owner role | Implements | Files |
|---|---|---|---|
| M4-T1 | lua-refactorer | C-08 (F-008) | `core/OutfitterReborn.lua` |
| M4-T2 | lua-refactorer | C-09 (F-009), plus its case | `modules/Triggers_Binder.lua`, `tests/test_trigger_binder.lua`, `docs/test-cases.md`, `README.md` badge |
| M4-T3 | lua-refactorer | C-10 (F-010) | `modules/Outfits.lua`, `modules/Window_ListModel.lua` |

**Checkpoint CP-4:** S-06 and the regression suite R-1 to R-8.

## Critical path and concurrency map

- `modules/Triggers_Binder.lua` is touched by **M1-T3, M2-T1 and M4-T2**. These must run in that
  order.
- `tests/test_trigger_binder.lua` is touched by **M1-T4, M2-T2 and M4-T2**. Serialize them with the
  binder tasks.
- `docs/test-cases.md` and `README.md` (badge) are touched by every case-adding task (M1-T2, M1-T4,
  M2-T2, M2-T4, M4-T2). Serialize them: each regenerates the inventory from its own tree, so two in
  flight produce a conflicting count.
- `tests/perf.lua`, `tests/perf_scenes.lua` and `docs/performance.md` are shared by **M3-T1 and
  M3-T2**. Serialize them.
- `modules/Window.lua` (M1-T1) and `modules/Dock.lua` (M3-T3) are disjoint files.
- **Parallelizable:** M1-T1 with M1-T3, apart from their test commits. M3-T3 with M3-T1. M4-T1 with
  M4-T3. M2-T3 (the client capture) can run at any time before M2-T4.

## Commit strategy

One commit per task. A test-author task may fold into its implementing task when one person does
both. A case always lands in the same commit as the code it pins. The subjects follow this branch's
convention (`P<step>: …`). Every commit message ends with the attribution lines from the session's
reminder.

| Task | Subject |
|---|---|
| M1-T1 + M1-T2 | `P8: Announce STACK_CHANGED only when the stack moved (F-001, F-006)` |
| M1-T3 + M1-T4 | `P8: Hold trigger bindings until the first LoadPass (F-002)` |
| M2-T1 + M2-T2 | `P8: Filter player-only trigger events in the client (F-003)` |
| M2-T4 | `P8: Correct the frFR and koKR use-duration patterns (F-004)` |
| M3-T1 | `P8: Add the instrumentation-absent perf arm (F-005)` |
| M3-T2 | `P8: Add the idle docked-window perf scenario (F-006)` |
| M3-T3 | `P8: Take the Perf upvalue at file scope (F-007)` |
| M4-T1 | `P8: Run the login stand-up through NS.StandUp (F-008)` |
| M4-T2 | `P8: Recycle deleted outfits' binder targets (F-009)` |
| M4-T3 | `P8: Drop Inv.Missing's dead argument (F-010)` |
