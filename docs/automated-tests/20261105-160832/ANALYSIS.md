# Analysis — 20261105-160832

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** green
- **Commit:** 162b787 (feat/2026-11-05-smoke-round-3), clean
- **Previous run:** 20261105-125130

## Headline

All four suites pass on a clean tree at `162b787`, the head of the smoke round 3 branch after Task 7
(the owner's rulings on E1, E7 and E12). Since `20261105-125130` the suite grew by 19 cases and one
linted file, and the code by 548 NLOC over 72 functions with the averages unchanged. Every perf
bytes/iter figure is the previous run's to the decimal, so the new work adds no allocation on the
measured paths and no ceiling needed touching. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261105-125130 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 201 files | [`lint.txt`](lint.txt) | 200 → 201 files, still 0/0 |
| tests | pass | 1538 passed, 1 skipped, 0 failed, 1539 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1520 → 1539 total (+19), still 0 failed |
| perf | pass | 13 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | every bytes/iter figure unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | totals grew; averages flat but tokens 63.2 → 63.3 |

| Metric | Value |
|---|---|
| Total NLOC | 46746 |
| Functions | 5809 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 63.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

All values are from [`manifest.json`](manifest.json) `suites.complexity`. The run is sighted, with 0
blind and 0 crashed files.

**tests.** It passes. The one skip is the standing diagnostics-contract case for an addon that opts
out of logging, which does not apply because this addon keeps the default
([`tests.txt`](tests.txt), line 1513). It is a skip with its reason recorded, not a pass.

**perf.** It passes ([`perf.txt`](perf.txt)). equipPlan allocates 235856.1 bytes/iter in both halves
and triggerFanout 107671.7 (off) and 107674.6 (on), the same figures `20261105-125130` passed against
the ceilings `46d0193` pinned, so the margins are unchanged. The ms/iter figures are for orientation
only and are not compared across runs.

## What moved

- **lint:** 200 → 201 files, still 0 warnings / 0 errors.
- **tests:** 1520 → 1539 total (+19); 1519 → 1538 passed; still 1 skipped, 0 failed. The
  inventory ([`test-cases.md`](test-cases.md)) is the authority on the added cases.
- **perf:** no bytes/iter figure moved: equipPlan (235856.1), zoneFlips (118022.7 / 117934.4),
  triggerFanout (107671.7 / 107674.6), tooltips (138494.1), gaGeneration (468126.8), dockIdle
  (192.3) and tooltipsAbsent (138494.1) are byte-for-byte the previous run's. Still pass.
- **complexity:** NLOC 46198 → 46746 (+548), functions 5737 → 5809 (+72), avg tokens 63.2 → 63.3;
  avg NLOC 7.1, avg CCN 2.3 and max CCN 15 unchanged; 0 warnings and both file bands still empty.
  The totals rose with the code; the averages did not, so it did not get denser.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

None.
