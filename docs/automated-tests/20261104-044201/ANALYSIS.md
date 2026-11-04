# Analysis — 20261104-044201

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** green
- **Commit:** 9a27eb789860e6e4ed4529da6aafbe2aafb9916a (feat/2026-11-03-ka0s-conversion), clean
- **Previous run:** 20261104-042841

## Headline

All four suites ran and passed on a clean tree at `9a27eb7`, the commit that fixes the P5 gate
verification findings (design §13 step 8): lint 0/0 over 188 files, 1277 cases passed with 0 failed
and 1 declared skip, 10 perf scenarios recorded, and lizard's max CCN is exactly 15 with 0 warnings,
0 blind and 0 crashed files. The change since the previous run is test code only: the mock sheet
and two fixtures set their fake host strata through a named constant instead of a string literal,
and two `test_locale` comments were reworded. No case was added or removed. Nothing here blocks the
gate.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261104-042841 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 188 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1277 passed, 1 skipped, 0 failed, 1278 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged; inventory identical |
| perf | pass | 10 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | timings only (same machine, run-to-run noise) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 39999 → 40002 |

| Metric | Value |
|---|---|
| Total NLOC | 40002 |
| Functions | 5040 |
| Avg NLOC / function | 6.9 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 61.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every value is `manifest.json`'s `suites.complexity`. The three added NLOC are the three new
host-strata constant lines in `tests/mock_world.lua`, `tests/test_dock.lua` and
`tests/test_slot_enables.lua`. The kit is sighted (blind and crashed counts are recorded and 0).

The one skip in `tests.txt` is the kit's diagnostics-contract opt-out case: this addon keeps the
default, so the case declares itself not applicable, with its reason. It is a standing condition,
not a regression.

The design §13 step 5 parity figures (serial and `-j auto` identical case for case; serial 30.8 s
wall / 21.7 s CPU, 16 shards 16.7 s / 36.9 s) were taken at `bd45fa5` and are recorded in
[`../20261104-042841/ANALYSIS.md`](../20261104-042841/ANALYSIS.md); the change since touches no
suite membership or sharding.

## What moved

- **lint:** 0/0 both runs, 188 files both runs.
- **tests:** 1278 cases both runs, same names in the same order (`test-cases.md` is byte-identical
  to the previous bundle's and to `docs/test-cases.md`; the README badge still reads 1277/1277).
- **perf:** every scenario is faster this run (for example `gaGenerationCaptureOff` 8.66735 →
  4.26146 ms/iter). No addon code changed between the two commits, so this is host load, not the
  addon; bytes per iteration are identical to the previous run in all ten scenarios.
- **complexity:** +3 NLOC, function count and max CCN unchanged.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Preview and simulation data

This is not a release run; design §13 step 10 asks for the section on the P5 bundle anyway.

- **Answer:** Refreshed
- **Asked:** 2026-11-04, by hand (design §13 step 10)
- **Files reviewed:** test mode only: `defaults/PreviewOutfits.lua`, `modules/Preview.lua`,
  `tests/test_preview.lua`. No simulator ships (H18, declined, a MAY), so there are no scenarios
  to review.
- **Commits since the previous release touching them:** 3 since `1.0.0-release` (`8f4cc54`,
  `c46e835`, `710fae9`), unchanged since the previous bundle.
- **Note:** the placeholder icons are the shipped default trigger icons, so the release currency
  check covers them.

## Actions

1. `tests/run.lua`: carried from the previous bundle. The serial gate is above testing-§14's
   roughly-10-seconds SHOULD for opting into `Kit.run{ ..., jobs = "auto" }`; parity is proven.
   No deviation or review finding owns it yet.
