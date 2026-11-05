# Analysis — 20261105-124114

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** amber
- **Commit:** 0ae116f (feat/2026-11-05-smoke-round-3), clean
- **Previous run:** 20261105-070533

## Headline

Amber, because perf fails: equipPlan and triggerFanout went over their byte ceilings in
`tests/perf.lua`. Lint, tests and complexity pass on a clean tree at `0ae116f`, the head of the smoke
round 3 branch, 28 commits after the previous bundle's `9aeba89`. The suite grew by 49 cases to 1520,
complexity holds at max CCN 15 with no warnings. The perf rise is exactly 4 × 896 bytes a step, the
recorder's per-registration cost that `f5420fb` profiled. Action 1 covers it.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261105-070533 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 200 files | [`lint.txt`](lint.txt) | files 197 → 200 |
| tests | pass | 1519 passed, 1 skipped, 0 failed, 1520 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1471 → 1520 cases (+49), skips unchanged at 1 |
| perf | fail | 13 scenarios, 4 assertions failed | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | equipPlan +3584 and triggerFanout +896 bytes/iter, both now over their ceilings; the other scenarios did not move |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | grew in size; avg NLOC 7.0 → 7.1, avg tokens 62.9 → 63.2; max CCN 15 unchanged |

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

**tests.** It passes. The one skip is the same case as before: the diagnostics-contract case for an
addon that opts out of logging, which does not apply because this addon keeps the default
([`tests.txt`](tests.txt), line 1494). It is a standing skip with its reason recorded, not a pass.

**perf.** It fails, with four assertions ([`perf.txt`](perf.txt)). equipPlan allocates 235856.1
bytes/iter in both halves, 1856.1 over its 234000 ceiling. triggerFanout allocates 107671.7 (off) and
107674.6 (on), 671.7 and 674.6 over its 107000 ceiling. Both pairs still agree, and the notes/iter
counts are the pinned ones (0/3 and 0/40). equipPlan rose 3584 bytes/iter from 232272.1, which is
4 × 896, the per-registration cost of the test recorder's registration survey that `f5420fb`
profiled. triggerFanout rose 896 in each half. The previous analysis flagged triggerFanout's 224.3-byte
margin as too thin for one more rise of this size, and this is that rise. The cause was established
outside this bundle, by a scratch experiment on `0ae116f`. Round 3's E11 commit `702e299` added four
bus registrations: `modules/Dock.lua` (SETTINGS_CHANGED, PROFILE_CHANGED) and `modules/SlotEnables.lua`
(SETTINGS_CHANGED, PROFILE_CHANGED). With only those four lines commented out, the live registration
count after load went 99 → 95, the previous run's count. The equipPlan and triggerFanout figures went
back to 232272.1 and 106775.7 / 106778.6, the previous run's figures to the byte. So the addon's own
allocation did not move. The rise is the vendored recorder's `M.__fire`, which builds
`M.__registrations()` for every game event it fires. This is a regression against the ceilings and
not against the addon. The re-pin it needs is Action 1. The ms/iter figures are for orientation only
and are not compared across runs.

## What moved

- **lint:** still 0/0. The file count went 197 → 200 with the files the round added.
- **tests:** 1471 → 1520 total and 1470 → 1519 passed. The skip count stays at 1 and nothing fails.
- **perf:** pass → fail. equipPlan +3584 and triggerFanout +896 bytes/iter, as above. zoneFlips
  (118022.7 / 117934.4), tooltips (138494.1), gaGeneration (468126.8), dockIdle (192.3) and
  tooltipsAbsent (138494.1) did not move.
- **complexity:** NLOC 44960 → 46198 (+1238) and functions 5598 → 5737 (+139). Avg CCN stays at
  2.3. Avg NLOC went 7.0 → 7.1 and avg tokens 62.9 → 63.2, a slight densening. Max CCN stays at 15,
  warnings at 0, and both file bands stay empty.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

1. `tests/perf.lua` and `docs/performance.md`: re-pin equipPlan and triggerFanout over their new
   figures, giving the reason above, as `f5420fb` did. The four registrations are the window settings
   page's subscribers (E11), and the client's own dispatch has no per-registration cost. Then re-run
   the battery. This is the previous analysis's Action 1, now due. No deviation ID or review finding
   tracks it.
