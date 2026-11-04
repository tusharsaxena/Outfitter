# Analysis — 20261104-134211

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** green
- **Commit:** ff19950b2aeb3a972e4fe77e75e6a3ebb53da8f8 (feat/2026-11-03-ka0s-conversion), clean
- **Previous run:** 20261104-044201

## Headline

All four suites ran and passed on a clean tree at `ff19950`, 36 commits after the previous bundle's
`9a27eb7`: lint 0/0 over 188 files, 1291 cases passed with 0 failed and 1 declared skip, 13 perf
scenarios recorded, and lizard's max CCN is 15 with 0 warnings, 0 blind and 0 crashed files. What
moved is the P8 review fixes and the post-push follow-ups: 14 more cases, three new perf scenarios,
and lower allocation in the zoneFlips and triggerFanout scenes after the Equip bracket stopped
allocating. The battery was green on its first run, so no re-run was needed. Nothing here blocks
the gate.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261104-044201 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 188 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1291 passed, 1 skipped, 0 failed, 1292 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1278 → 1292 cases |
| perf | pass | 13 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 10 → 13 scenarios; zoneFlips and triggerFanout bytes down |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 40002 → 40505, functions 5040 → 5091 |

| Metric | Value |
|---|---|
| Total NLOC | 40505 |
| Functions | 5091 |
| Avg NLOC / function | 6.9 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 61.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every value is from `manifest.json`'s `suites.complexity`. The kit is sighted: blind and crashed
counts are recorded, and both are 0. The max-CCN function is `serialize` in
`tools/legacy_capture.lua` (CCN 15, as in the previous run). The previous run's other CCN 15 function,
`NS.OnProfileChanged` in `core/Database.lua`, now scores 14 (`complexity.txt`). That follows `251fe99`,
which dropped its dead `NS.ApplyProfile` call.

The one skip in `tests.txt` is the kit's diagnostics-contract opt-out case. This addon keeps the
default, so the case declares itself not applicable and gives its reason. It is a standing
condition, not a regression.

**Known flake, not hit this run.** "bar: a profile switch redraws the bar from the new profile and
rebinds the triggers" (`tests/test_bar.lua:577`) fails about 1 run in 8 to 20 because of the vendored
kit's `Callbacks:unregisterAll` ([LibKa0s#75](https://github.com/tusharsaxena/LibKa0s/issues/75);
recorded in `docs/known-limitations.md` at `ff19950`). It passed here (`tests.txt`). The game is
unaffected, and the case clears at the re-vendor that carries the fix.

## What moved

- **lint:** 0/0 in both runs, over 188 files in both.
- **tests:** 1278 → 1292 cases (+14), 1277 → 1291 passed, the same 1 skip, 0 failed in both.
  `test-cases.md` is byte-identical to `docs/test-cases.md`, and the README badge reads 1291/1291.
  Per suite file: `test_api` 19 → 20, `test_bar` 26 → 28, `test_disabled` 21 → 22, `test_dock`
  19 → 20, `test_equip_bracket` 29 → 32, `test_outfit_menu` 10 → 11, `test_perf_harness` 18 → 19,
  `test_rows_secure` 14 → 15, `test_trigger_binder` 16 → 19. That is 19 new cases and 5 renamed
  ones, renamed because the behavior changed: `STATS_CHANGED` and `LEGACY_DETECTED` were dropped
  (`bb0fa60`), `OnLoadPassDone` became `FirstPassDone`, and the slash-help case now checks that the
  README's Usage points at `/of help`, since the user manual was retired.
- **perf:** three scenarios are new to the record: `tooltipsAbsent` (`c94608b`) and
  `dockIdleCaptureOff`/`On` (`c8fb215`), at 192.3 bytes/iter in both arms (`perf.txt`). No earlier
  bundle measured dockIdle. The scene's earlier figure of about 1256 bytes/iter comes from the
  `aa0a620` commit message, not from a bundle: the scene had settled on a frozen clock and was
  measuring the update its own setup asked for. After `aa0a620` the step moves past the throttle
  and the idle Equip bracket allocates nothing, and the scene's ceiling dropped from 1290 to 200.
  Bytes/iter against the previous bundle:
  - `zoneFlipsCaptureOff` 149217.0 → 118019.8, `zoneFlipsCaptureOn` 149134.4 → 117934.4
  - `triggerFanoutCaptureOff`/`On` 119534.4 → 104718.4
  - `equipPlanCaptureOff`/`On` 224032.1 → 224208.1 (+176)
  - `tooltips` and `gaGeneration` unchanged

  The zoneFlips and triggerFanout drops come from the allocation-free Equip bracket, because every
  zone flip and binding dispatch runs through `E.Batch`. `d766d71` lowered their ceilings in
  `tests/perf.lua` to 120500 and 107000, about 2% over the new figures, and both scenes pass under
  them here. The timings are orientation only (same machine). For example, `gaGenerationCaptureOff`
  went 4.26146 → 4.51521 ms/iter with identical bytes, which is host load, not the addon.
- **complexity:** +503 NLOC and +51 functions, from the new cases and the P8 fixes. Avg NLOC (6.9),
  avg CCN (2.3) and max CCN (15) did not move, and there are still 0 warnings. The addon grew but
  did not get denser.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

1. `tests/_kit/mock_ace.lua`: the `unregisterAll` flake waits on the LibKa0s re-vendor that fixes
   [LibKa0s#75](https://github.com/tusharsaxena/LibKa0s/issues/75). Until then, re-run when the bar
   profile-switch case goes red. This is tracked upstream, not here.
2. `tests/run.lua`: carried from the previous bundle. The serial gate (30068 ms for the tests suite in
   `manifest.json`) is above testing-§14's roughly-10-seconds SHOULD for opting into
   `Kit.run{ ..., jobs = "auto" }`. No deviation or review finding owns it yet.
