# Analysis — 20261105-070533

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** green
- **Commit:** 9aeba89 (feat/2026-11-05-smoke-round-2), clean
- **Previous run:** 20261105-004501

## Headline

All four suites pass on a clean tree at `9aeba89`, the head of the smoke round 2 branch. The
previous bundle measured `f5420fb`, 31 commits back, so every delta below covers the whole round.
The suite grew by 87 cases to 1471, complexity stays at max CCN 15 with no warnings, and perf passes
all 13 scenarios. One thing to act on before the next round: `triggerFanout`'s bytes/iter now sit
224.3 under the 107000 ceiling in `tests/perf.lua`.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261105-004501 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 197 files | [`lint.txt`](lint.txt) | files 193 → 197 |
| tests | pass | 1470 passed, 1 skipped, 0 failed, 1471 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1384 → 1471 cases (+87), skips unchanged at 1 |
| perf | pass | 13 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | equipPlan and triggerFanout bytes/iter rose; the other scenarios did not move |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | grew in size; averages flat except tokens 62.1 → 62.9; max CCN 15 unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 44960 |
| Functions | 5598 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 62.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

All values are from [`manifest.json`](manifest.json) `suites.complexity`. The run is sighted, with 0
blind and 0 crashed files.

**tests.** It passes. The one skip is the same case as before: the diagnostics-contract case for an
addon that opts out of logging, which does not apply because this addon keeps the default
([`tests.txt`](tests.txt), line 1445). It is a standing skip with its reason recorded, not a pass.

**perf.** It passes, but two scenarios allocate more than they did
([`perf.txt`](perf.txt)). equipPlan went from 229584.1 to 232272.1 bytes/iter with capture off and
on, a rise of 2688. That is 3 × 896, the per-registration cost of the test recorder's registration
survey that `20261105-004501` profiled. triggerFanout went from 106103.7 to 106775.7 (off) and from
106106.6 to 106778.6 (on), a rise of 672 in each. This run did not profile either rise, so their
cause is not established here. Both stay under their ceilings in `tests/perf.lua`. equipPlan is
1727.9 under 234000. triggerFanout is 224.3 under 107000 (off) and 221.4 under it (on), and that
margin is thin enough that one more rise of this size turns perf red. The ms/iter figures are for
orientation only and are not compared across runs.

## What moved

- **lint:** still 0/0. The file count went 193 → 197 with the files the round added.
- **tests:** 1384 → 1471 total and 1383 → 1470 passed. The skip count stays at 1 and nothing fails.
  The flat run of 1384 cases that `RESULTS.md` noted across the last three runs is over.
- **perf:** pass → pass. equipPlan rose 2688 bytes/iter and triggerFanout 672, as above. zoneFlips
  (118022.7 / 117934.4), tooltips (138494.1), gaGeneration (468126.8), dockIdle (192.3) and
  tooltipsAbsent (138494.1) did not move.
- **complexity:** NLOC 42375 → 44960 (+2585) and functions 5304 → 5598 (+294). Avg NLOC (7.0) and
  avg CCN (2.3) did not move, so the growth adds size without adding density. Avg tokens went
  62.1 → 62.9. Max CCN stays at 15, warnings at 0, and both file bands stay empty.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

1. `tests/perf.lua`: triggerFanout runs 224.3 bytes/iter under its 107000 ceiling, after a rise of
   672 this round whose cause has not been profiled. Profile the rise. If it is the recorder's
   registration survey again, re-pin the ceiling with that reason, as `f5420fb` did for equipPlan.
   If it is not, treat it as the addon's own allocation. No deviation ID or review finding tracks
   this yet; it is new here.
