# Analysis — 20261105-004501

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** green
- **Commit:** f5420fb (feat/2026-11-04-sheet-window-feedback), clean
- **Previous run:** 20261104-233516

## Headline

All four suites pass on a clean tree at `f5420fb`, so the two amber items from `20261104-233516` are
cleared. Complexity has no function above CCN 15: `placeFlyout` dropped from 18 to the 15-or-under
range after the split in `729d23a`. Perf passes all 13 scenarios. The equipPlan figure did not move
(229584.1 bytes/iter). Its ceiling was re-pinned to 234000 in `f5420fb`, with the reason recorded:
the rise comes from the test recorder's registration survey, not from the addon. Nothing is left to
act on for the release gate.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261104-233516 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 193 files | [`lint.txt`](lint.txt) | none |
| tests | pass | 1383 passed, 1 skipped, 0 failed, 1384 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | none |
| perf | pass | 13 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | fail → pass; bytes/iter unchanged in every scenario, the equipPlan ceiling re-pinned |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 18 → 15, warnings 1 → 0 |

| Metric | Value |
|---|---|
| Total NLOC | 42375 |
| Functions | 5304 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 62.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

All values are from [`manifest.json`](manifest.json) `suites.complexity`. The run is sighted: 0 blind
and 0 crashed files.

**perf.** The bytes per iteration are the same as the previous run in every scenario
([`perf.txt`](perf.txt)): equipPlan is 229584.1 with capture off and on. What changed is the ceiling.
`tests/perf.lua` now pins equipPlan at 234000, about 2% over the figure, as the other scenarios are
pinned. The reason is in the perf header and in `docs/performance.md`. A line-level allocation
profile of one step, run with and without the Outfits broker's six bus registrations, puts all 5376
bytes on `M.__fire` in the vendored `tests/_kit/mock_record.lua`. For every game event it fires, that
function rebuilds `M.__registrations()`, one row per live registration. So each registration costs
896 bytes a step, whether or not its message is ever sent. The addon's own allocation on the equip
path did not move. triggerFanout (106103.7) rose by the same mechanism and stays under its 107000
ceiling.

## What moved

- **lint:** unchanged, 0/0 over 193 files.
- **tests:** unchanged, 1383 passed, 1 skipped, 1384 total. The two commits since `b71bc61` add no
  cases: one is a behavior-preserving split and the other is a re-pin. Five consecutive
  `lua tests/run.lua` runs before this one were all green, so the one-off failure seen during Task
  3.9 did not recur.
- **perf:** fail → pass. Every bytes/iter figure is unchanged, and only the equipPlan ceiling moved
  (229000 → 234000).
- **complexity:** NLOC 42369 → 42375 and functions 5302 → 5304 (`placeFlyout` became three functions).
  Max CCN went from 18 to 15 and warnings from 1 to 0. Avg CCN (2.3), avg NLOC (7.0) and avg tokens
  (62.1) are unchanged.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Preview and simulation data

Not a release run, so this section is not required (`automated-tests-§5`).

## Actions

None. Both actions carried from `20261104-233516` are closed. `placeFlyout` was split in `729d23a`,
and the equipPlan ceiling was re-pinned with its reason in `f5420fb`.
