# Analysis — 20261104-042841

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** green
- **Commit:** bd45fa5e87886c2b86d37143f02643c1fbbd6845 (feat/2026-11-03-ka0s-conversion), clean
- **Previous run:** 20261103-143906

## Headline

All four suites ran and passed on a clean tree at `bd45fa5`, the design §13 P5 gate commit: lint
0/0 over 188 files, 1277 cases passed with 0 failed and 1 declared skip, 10 perf scenarios recorded,
and lizard's max CCN is exactly 15 with 0 warnings, 0 blind and 0 crashed files. Everything moved
since the previous run, because that run measured the P3 scaffold (73 files, 275 cases) on a dirty
tree with perf and complexity not selected; this is the first complete reading of the ported addon.
Nothing here blocks the gate; one speed action is listed.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261103-143906 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 188 files | [`lint.txt`](lint.txt) | files 73 → 188; still 0/0 |
| tests | pass | 1277 passed, 1 skipped, 0 failed, 1278 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 271/4/275 → 1277/1/1278 |
| perf | pass | 10 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | not run → first reading |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | not run → first reading |

| Metric | Value |
|---|---|
| Total NLOC | 39999 |
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

Every value is `manifest.json`'s `suites.complexity`; the footer in `complexity.txt` agrees
(39999 NLOC, 5040 functions, `No thresholds exceeded`). The functions at the ceiling are
`serialize` in `tools/legacy_capture.lua` and `NS.OnProfileChanged` in `core/Database.lua`, both at
CCN 15 and so not warned on. The kit is sighted (blind and crashed counts are recorded and 0).

The one skip in `tests.txt` is the kit's diagnostics-contract opt-out case ("an addon that opts out
lands the report and leaves logging off"): this addon keeps the default, so the case declares
itself not applicable, with its reason. It is a standing condition, not a regression, and it is
counted in neither passed nor failed. Every other suite is a clean pass.

Outside the runner, on this same commit, the design §13 step 5 parity check (testing-§14) ran
`lua tests/run.lua` and `lua tests/run.lua -j auto` through the bounded runner: both reported
1277 passed, 0 failed, 1 skipped, 1278 total, and their case lines were identical in order (16
shards). Serial took 30.8 s wall for 21.7 s CPU (70 %); parallel took 16.7 s wall for 36.9 s CPU
(221 %). These figures are from `time`, not a bundle artifact, and are restated in the P5 plan
ledger row.

## What moved

- **lint:** 0/0 both runs; the file count rose 73 → 188 as the port (P4) landed its modules,
  settings, locales and suites. Scope is unchanged: `.luacheckrc` still excludes `libs/`,
  `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/` and `_dev/`.
- **tests:** 275 → 1278 cases; skips fell 4 → 1. Three of the previous run's skips were scaffold-era
  cases waiting on P4 tasks (P4.27, P4.28, P4.31), all live now; the fourth is the same
  diagnostics-contract opt-out skip this run carries. The `test_refactor_pins` pending entry was
  dropped at P5 (design §13 step 1) because no function is above CCN 15, so no suite is pending.
- **perf:** first reading. Capture-on costs stay small beside capture-off in every scenario, the
  largest gap being `equipPlanCaptureOn` at 2.36215 ms/iter against 1.51403; bytes per iteration
  are equal on and off in all but `zoneFlips` (149134.4 on, 149217.0 off). Timings are for
  comparison within this run only.
- **complexity:** first reading; see the table above.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|

None. The largest authored Lua files are `core/Compat.lua` (993 lines) and
`tests/test_secrets.lua` (988), both under the 1000-line project budget that `test_file_budget`
holds; neither grew at P5.

## Preview and simulation data

This is not a release run; design §13 step 10 asks for the section on the P5 bundle anyway.

- **Answer:** Refreshed
- **Asked:** 2026-11-04, by hand (design §13 step 10)
- **Files reviewed:** test mode only: `defaults/PreviewOutfits.lua` (the placeholder outfits and
  their icons), `modules/Preview.lua`, `tests/test_preview.lua`. No simulator ships (H18, declined,
  a MAY), so there are no scenarios to review.
- **Commits since the previous release touching them:** 3 since `1.0.0-release` (`8f4cc54`,
  `c46e835`, `710fae9`): the files are new in this conversion.
- **Note:** the placeholder icons were refreshed with the port: they are the shipped default
  trigger icons, so the release currency check covers them.

## Actions

1. `tests/run.lua`: the serial gate is 30.8 s, above testing-§14's roughly-10-seconds SHOULD for
   opting into `Kit.run{ ..., jobs = "auto" }`, and parity is proven above. Opting in, or first
   measuring where the serial time goes as §14 requires before any fix, is new here: no deviation or
   review finding owns it yet.
