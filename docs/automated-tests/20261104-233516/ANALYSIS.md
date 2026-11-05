# Analysis — 20261104-233516

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** amber
- **Commit:** b71bc61 (feat/2026-11-04-sheet-window-feedback), clean
- **Previous run:** 20261104-225824

## Headline

Lint and tests pass on a clean tree at `b71bc61`: 0/0 over 193 files, and 1383 cases passed with 0
failed and 1 declared skip. This is the closing run for the sheet and window round (plan Task 3.9),
taken after the smoke checklist rewrite, so the newest bundle measures the tree the branch pushes.
The two commits since `20261104-225824` touch only documentation and the record, and every figure
but the timings is the same. It stays amber for the same two reasons, neither of which gates a
commit: the equipPlan scenarios allocate 229584.1 bytes per iteration against a 229000-byte ceiling,
and `placeFlyout` in `modules/QuickSlots.lua` is at CCN 18. Both block the tag.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261104-225824 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 193 files | [`lint.txt`](lint.txt) | none |
| tests | pass | 1383 passed, 1 skipped, 0 failed, 1384 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | none |
| perf | fail | 13 scenarios, 2 allocation ceilings exceeded | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged in every scenario |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | none |

| Metric | Value |
|---|---|
| Total NLOC | 42369 |
| Functions | 5302 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 2.3 |
| Max CCN | 18 |
| Avg tokens / function | 62.1 |
| Warnings (CCN > 15) | 1 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**perf.** `perf.txt` reports `2 assertions FAILED`: `equipPlanCaptureOff` and `equipPlanCaptureOn`
allocate 229584.1 bytes per iteration over the 229000-byte ceiling, the same as the previous run.
Perf gates neither the run nor the commit; it gates the tag.

**complexity.** Passed with a clean sighting (0 blind, 0 crashed). The one warned function is still
`placeFlyout` (CCN 18, `modules/QuickSlots.lua`); its disposition is carried forward unchanged.

## What moved

- **lint:** nothing; 193 files, 0/0.
- **tests:** nothing; 1384 cases, 1 skip. The commits since the previous run are docs only.
- **perf:** allocation figures identical in all 13 scenarios. Timings differ run to run and are for
  orientation only.
- **complexity:** nothing; NLOC 42369, 5302 functions, max CCN 18, 1 warning.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `placeFlyout` | 18 | `modules/QuickSlots.lua` | **Peel next** (carried forward from `20261104-225824`). Split the anchor choice from the host-settings read before the tag |

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Preview and simulation data

Not a release run; not required (`automated-tests-§5`).

## Actions

1. `modules/QuickSlots.lua` `placeFlyout`: bring CCN to 15 or below before the tag. Carried from
   `20261104-225824` action 1; still no tracked ID.
2. `tests/perf.lua` equipPlan ceiling (229000 bytes): remove the extra ~5.4 KB per iteration or
   re-pin the ceiling with its reason, before the tag. Carried from `20261104-225824` action 2; still
   no tracked ID.
