# Analysis — 20261106-010454

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** green
- **Commit:** 7f512f0 (feat/2026-11-05-kit-flake-dead-code), clean
- **Previous run:** 20261105-160832

## Headline

All four suites pass on a clean tree at `7f512f0`. That commit re-vendors LibKa0s v1.89.0 (kit
revision 51) on top of the dead-code sweep. Since `20261105-160832` the code shrank by 100 NLOC and
24 functions, and the suite lost 2 cases with the functions they covered. Every perf bytes/iter
figure matches the previous run to the decimal. Kit revision 51 fixes the `test_bar`
profile-switch flake. This run and ten bounded `lua tests/run.lua` runs before it were all green,
with 0 failed. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261105-160832 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 201 files | [`lint.txt`](lint.txt) | 201 files, still 0/0 |
| tests | pass | 1536 passed, 1 skipped, 0 failed, 1537 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1539 → 1537 total (−2), still 0 failed |
| perf | pass | 13 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | every bytes/iter figure unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | totals fell; averages flat |

| Metric | Value |
|---|---|
| Total NLOC | 46646 |
| Functions | 5785 |
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

All values come from `suites.complexity` in [`manifest.json`](manifest.json). The run is sighted,
with 0 blind and 0 crashed files.

**tests.** The suite passes. The one skip is the standing diagnostics-contract case for an addon
that opts out of logging. It does not apply here because this addon keeps the default
([`tests.txt`](tests.txt), line 1511). The skip is recorded with its reason and is not counted as
a pass. The bar profile-switch case ("bar: a profile switch redraws the bar from the new profile
and rebinds the triggers") passes. Before the re-vendor it failed about one run in eight to twenty.

**perf.** The suite passes ([`perf.txt`](perf.txt)). equipPlan allocates 235856.1 bytes/iter in
both halves, and triggerFanout allocates 107671.7 (off) and 107674.6 (on). These match
`20261105-160832`, so the margins are unchanged. The kit change touches only the mock
CallbackHandler's unregister paths and moves no figure. The ms/iter figures are for orientation
only and are not compared across runs.

## What moved

- **lint:** still 201 files, 0 warnings / 0 errors. `libs/` and `tests/_kit/` are outside the
  checked set, so the re-vendored files are not in this figure.
- **tests:** 1539 → 1537 total (−2), 1538 → 1536 passed, still 1 skipped and 0 failed. The dead-code
  sweep removed cases with the functions they covered and rewrote others in place. The inventory
  ([`test-cases.md`](test-cases.md)) is the authority on case names.
- **perf:** no bytes/iter figure moved: equipPlan (235856.1), zoneFlips (118022.7 / 117934.4),
  triggerFanout (107671.7 / 107674.6), tooltips (138494.1), gaGeneration (468126.8), dockIdle
  (192.3) and tooltipsAbsent (138494.1).
- **complexity:** NLOC 46746 → 46646 (−100) and functions 5809 → 5785 (−24), from the deleted
  functions and the PreClick hook. Avg NLOC 7.1, avg CCN 2.3, avg tokens 63.3 and max CCN 15 are
  unchanged. There are 0 warnings and both file bands are still empty.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

None in this repo. The library side is open: LibKa0s `master` and tag `v1.89.0` are not on origin
yet. Until they are pushed, `tests/test_vendor_sync.lua` can verify this payload only against a
checkout that holds the local tag.
