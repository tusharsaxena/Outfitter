# Analysis — 20261105-125130

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** green
- **Commit:** 46d0193 (feat/2026-11-05-smoke-round-3), clean
- **Previous run:** 20261105-124114

## Headline

All four suites pass on a clean tree at `46d0193`, the head of the smoke round 3 branch. The previous
bundle measured `0ae116f` two commits back and was amber on perf alone. The commits between them
record that bundle and re-pin the equipPlan and triggerFanout ceilings in `tests/perf.lua`, and no
addon code changed. Every figure is the same as that run's. Only the perf verdict moved, because
the ceilings it is judged against moved. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261105-124114 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 200 files | [`lint.txt`](lint.txt) | did not move |
| tests | pass | 1519 passed, 1 skipped, 0 failed, 1520 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | did not move |
| perf | pass | 13 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | fail → pass; every bytes/iter figure unchanged, two ceilings re-pinned |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | did not move |

| Metric | Value |
|---|---|
| Total NLOC | 46198 |
| Functions | 5737 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 63.2 |
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
([`tests.txt`](tests.txt), line 1494). It is a skip with its reason recorded, not a pass.

**perf.** It passes ([`perf.txt`](perf.txt)). equipPlan allocates 235856.1 bytes/iter in both halves,
and triggerFanout 107671.7 (off) and 107674.6 (on). Those are the figures that failed in
`20261105-124114`. They pass now because `46d0193` re-pinned equipPlan's ceiling at 240000 and
triggerFanout's at 109500. That bundle's analysis gives the reason: the rise is the vendored
recorder's 896 bytes per registration for E11's four new bus registrations, and none of it is the
addon's. The margins are now 4143.9 for equipPlan and 1828.3 / 1825.4 for triggerFanout. The ms/iter
figures are for orientation only and are not compared across runs.

## What moved

- **lint:** still 0/0 over 200 files.
- **tests:** still 1520 total, 1519 passed, 1 skipped, 0 failed.
- **perf:** fail → pass with no figure moving: equipPlan (235856.1), zoneFlips (118022.7 / 117934.4),
  triggerFanout (107671.7 / 107674.6), tooltips (138494.1), gaGeneration (468126.8), dockIdle
  (192.3) and tooltipsAbsent (138494.1) are byte-for-byte the previous run's. The verdict moved
  because two ceilings moved.
- **complexity:** NLOC 46198, functions 5737, avg NLOC 7.1, avg CCN 2.3, avg tokens 63.2, max CCN 15,
  0 warnings and both file bands empty, all unchanged.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

None.
