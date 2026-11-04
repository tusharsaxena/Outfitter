# Analysis — 20261104-225824

- **Addon:** OutfitterReborn 1.1.0
- **Verdict:** amber
- **Commit:** 73d6770 (feat/2026-11-04-sheet-window-feedback), clean
- **Previous run:** 20261104-134211

## Headline

Lint and tests pass on a clean tree at `73d6770`: 0/0 over 193 files, and 1383 cases passed with 0
failed and 1 declared skip. The run is amber for two reasons, and neither gates a commit. The perf
suite failed two allocation ceilings: `equipPlanCaptureOff` and `equipPlanCaptureOn` allocate
229584.1 bytes per iteration against a 229000-byte ceiling. Complexity has 1 function above CCN 15,
`placeFlyout` in `modules/QuickSlots.lua` at 18. Both arrived with this branch's sheet and window
feedback work, before the review fixes this run follows. A perf run at `10cbeaa`, before those fixes,
gives the same 229584.1 bytes. Both block the tag, so both are owed before a release.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261104-134211 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 193 files | [`lint.txt`](lint.txt) | 188 → 193 files |
| tests | pass | 1383 passed, 1 skipped, 0 failed, 1384 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1292 → 1384 cases |
| perf | fail | 13 scenarios, 2 allocation ceilings exceeded | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | equipPlan 224208.1 → 229584.1 bytes/iter |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 18, warnings 0 → 1 |

| Metric | Value |
|---|---|
| Total NLOC | 42369 |
| Functions | 5302 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 2.3 |
| Max CCN | 18 |
| Avg tokens / function | 62.1 |
| Warnings (CCN > 15) | 1 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**perf.** `perf.txt` reports `2 assertions FAILED`. Both equipPlan scenarios allocate 229584.1
bytes per iteration against the 229000-byte ceiling in `tests/perf.lua`. The previous run measured
224208.1. This is a regression on the branch, not caused by this run's review fixes: `tests/perf.lua`
at `10cbeaa` reports the same 229584.1 bytes. Perf gates neither the run nor the commit, but it gates
the tag.

**complexity.** The suite passed, and the sighting is clean (0 blind files, 0 crashed files). One
function is warned: `placeFlyout` (CCN 18, `modules/QuickSlots.lua`). It is guard-dense: nil checks on
the flyout, its button and the host's settings, `or` defaults on each anchor offset, and a three-way
anchor choice (vertical, outward, Blizzard's). The 0 → 1 move is the outward-drawer work (Task 3.7,
`8e21b14` and `d2e22df`). The averages did not move: avg CCN 2.3 and avg NLOC 6.9 → 7.0, while the
total grew with the code (NLOC 40505 → 42369, functions 5091 → 5302).

## What moved

- **lint:** still 0/0, over 193 files instead of 188, five more files tracked on the branch.
- **tests:** 1292 → 1384 cases, from the branch's new suites (sheet, broker, glyphs, outfit icons) and
  the eight cases the review fixes added. The skip count is unchanged at 1.
- **perf:** still 13 scenarios. equipPlan rose from 224208.1 to 229584.1 bytes per iteration
  (Off and On alike) and is now over its ceiling. Timings are for orientation only and are not
  compared across runs.
- **complexity:** NLOC 40505 → 42369, functions 5091 → 5302, avg CCN 2.3 unchanged, max CCN 15 → 18,
  warnings 0 → 1.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `placeFlyout` | 18 | `modules/QuickSlots.lua` | **Peel next.** New with the outward drawer. It is guard and default density, not tangled flow. Split the anchor choice from the host-settings read before the tag (the release gate needs 0 functions above CCN 15) |

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

1. `modules/QuickSlots.lua` `placeFlyout`: peel the host-settings read and the outward/restore anchor
   choice into helpers to bring CCN to 15 or below. This is new and has no tracked ID yet.
2. `tests/perf.lua` equipPlan ceiling (229000 bytes): find which branch commit after `ff19950` added
   about 5.4 KB per iteration to the equip-plan path. Then either remove the allocation or re-pin the
   ceiling with the reason stated. This is new and has no tracked ID yet.
