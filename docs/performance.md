# Performance

How much Ka0s Outfitter Reborn costs, and how to measure it. The harness is `LibKa0s-Perf-1.0`,
built in `core/PerfSetup.lua` over `OutfitterRebornPerfDB`; the shared capture protocol and record
contract live with the library and are not restated here (performance-§7, §8).

## What is bracketed

The bucket list is fixed: ten static keys, declared in report order in the `core/PerfSetup.lua`
descriptor, each bracketed at exactly one call site with the gated idiom (performance-§2): one boolean
test when capture is off. A trigger id, an outfit name or a slot never becomes a bucket name; it goes
to `NS.Debug`.

Each call site sits in its module, and `tests/test_perf_harness.lua` drives every path on the whole
addon and asserts a non-zero count per bucket, and that `equipExecute` is only ever noted while
`E.Update` runs. The drivers are `tests/perf_scenes.lua`'s, the same ones the offline runner measures.

| Bucket | `within` | Path | Why it is hot |
|---|---|---|---|
| `auraScan` | — | `modules/States.lua`, the player `UNIT_AURA` scan | The hottest path: auras change constantly in combat |
| `zoneUpdate` | — | `modules/States_Zone.lua`, the debounced zone producer | Every zone and subzone change |
| `bagSync` | — | `modules/Inventory.lua`, `Inv.Sync` | Every bag update, debounced |
| `equipUpdate` | — | `modules/Equip.lua`, `E.Update` | Every stack change and every retry while waiting out a gate |
| `equipExecute` | `equipUpdate` | `modules/Equip.lua`, `E.Execute` when called from `E.Update` | The item moves themselves (the bank's direct call is not bracketed) |
| `triggerDispatch` | — | `modules/Triggers_Binder.lua`, `Binder.Dispatch` | Every event every bound trigger listens to |
| `optimizeStep` | — | `modules/Optimize*.lua`, one coroutine resume of the genetic search | A long search spread over frames |
| `dockFollow` | — | `modules/Dock.lua`, one throttled follow tick | 20 Hz while the window is shown |
| `barRender` | — | `modules/Bar.lua`, `Bar.Render` | Every stack and outfit change while the bar shows |
| `tooltipUsedBy` | — | `modules/Tooltips.lua`, `Tooltips.OnItem` past its gates | Every item tooltip |

`equipExecute` only ever runs inside `equipUpdate`, so a report never adds the two.

While idle, out of combat with the window closed, the addon runs its event handlers on the edges it
listens to and one 0.5 s States poll (`POLL_PERIOD` in `modules/States.lua`: mounted and swimming);
the window's follow tick exists only while the window is shown. The poll's cost is under
[Measured costs](#measured-costs).

## Taking a capture

All in game, through the reserved `perf` verb (`/or perf help` lists the words):

- `/or perf start [label]`: begin a run; records who and where you are.
- `/or perf measure a`: arm experiment A, the addon active. It records only while combat lasts.
- Fight, then leave combat.
- `/or perf measure b`: arm experiment B, the same with the addon suspended through the latch's
  `perf` hold.
- Fight the same way for about as long, then leave combat.
- `/or perf finish`, `/reload`, then `/or perf report`: prints the summary and the one JSON line.

Run both arms back to back, in the same place, with the same outfits and triggers. While suspended the
addon is inert: every registration is dropped, and its feature verbs refuse.

A capture worth keeping becomes a bundle under [`perf-analysis/`](perf-analysis/README.md), written
by `/dev-copilot:wow-perf-analysis` from the report and the JSON line.

## Reading a report

- The **buckets** are the addon's own cost, measured directly. Read them first.
- The frame-time delta between the arms is a difference of two noisy aggregates. Below about
  0.5 ms per frame on a 60 to 80 s arm it is **unresolved**, not zero (performance-§8).
- A suspended arm that reads slower than the active one means the environment moved between arms.

## Offline scenarios

`tests/perf.lua` is the offline scenario runner (performance-§9). It measures bytes allocated and
bracket notes per iteration, never wall-clock time, and sits outside the commit gate. Each scenario
runs on a whole addon of its own (every module real, items moving in the gear mock) and is measured
with capture off and on:

| Scenario | One step | Notes per step, capture on |
|---|---|---|
| `equipPlan` | A full-bag Warrior's weapon outfit worn or taken off at once: one `E.Update` with one change, the moved items' events, `Inv.Sync` | 3: `equipUpdate`, `equipExecute`, `bagSync` |
| `zoneFlips` | 50 battleground zone flips (Warsong Gulch and the open world in turn) through the zone producer, a battleground outfit bound | 100: 50 `zoneUpdate`, 50 `triggerDispatch` |
| `triggerFanout` | One `PLAYER_UPDATE_RESTING` edge through 40 outfits on the Resting trigger | 40 `triggerDispatch` |
| `tooltips` | The "Used by outfits" line on 100 bag items | 100 `tooltipUsedBy` |
| `gaGeneration` | One genetic generation: 275 children over whole resumes of the ticker, the search restarted every 20 steps | 3 `optimizeStep` |
| `dockIdle` | The docked window shown on full bags with nothing changing: one States poll tick (0.5 s) and one follow tick. The idle bracket announces nothing, so the list is not rebuilt (about 190 bytes a step, against 180 KB if it redrew) | 1 `dockFollow` |
| `tooltipsAbsent` | The `tooltips` step with `Tooltips.OnItem`'s bracket removed from the source, measured with capture off only (the instrumentation-absent arm, below) | 0: there is no bracket |

Each carries a byte ceiling a little above its measured figure and a pinned note count, and each
pair must agree: capture off allocates nothing over capture on, and on no more than 64 bytes per
step over off. Capture off alone may carry a one-off of up to 8 KB per measured window, granted only
while it spreads to under 16 bytes per bracket call, so it can never hide a per-call allocation
(`Scenes.pairFailures` in `tests/perf_scenes.lua`; `tests/perf.lua`'s header has the figures).

The pair alone cannot show that capture off is free: a dormant bracket that allocates pays the same
bytes in both halves. So one more arm, `tooltipsAbsent`, measures the `tooltips` step on an instance
with no instrumentation at all: its `modules/Tooltips.lua` is the TOC's own file with
`Tooltips.OnItem`'s two bracket lines blanked before it loads (`Scenes.ABSENT`; the load list stays
TOC-derived). `tooltipsCaptureOff` must allocate no more than it (within 1 byte per step, the float's
noise), and the arm must note nothing with capture on, which proves the strip took the bracket.

A ceiling is raised only by re-measuring and saying why. The runs are kept in
[`automated-tests/`](automated-tests/README.md), not in `perf-analysis/`.

**Re-pinned 2026-11-05: `equipPlan` 229000 → 234000.** The scenario rose from 224208 to 229584
bytes a step when the Outfits broker (`modules/Broker.lua`) registered its six bus messages. None of
those bytes are the addon's. A line-level allocation profile of the step, with and without the six
registrations, puts the whole 5376 bytes on one line of the vendored recorder. For every game event
it fires, `M.__fire` (`tests/_kit/mock_record.lua`) builds `M.__registrations()`, one row per live
registration, so each registration costs 896 bytes a step whether or not its message is ever sent.
The client's own dispatch has no such cost. `triggerFanout` rose from 104748 to 106104 for the same
reason and stays under its 107000 ceiling.

## Measured costs

**The idle docked window: about 192 bytes a step.** Measured 2026-11-04 by `tests/perf.lua`'s
`dockIdle` scenario (Lua 5.1, the same figure with capture off and on, ceiling 200). One step is one
States poll tick (the 0.5 s mounted and swimming repeater) and one follow tick. The poll runs twice
a second whenever the addon is up, window or not; the follow tick runs only while the window is
shown. Of the 192 bytes:

| Share | Where it goes |
|---|---|
| 0 | The poll's `NS.Equip.Batch` bracket. With up to three arguments, `run()` in `modules/Equip.lua` passes them through file-scope slots to a file-scope trampoline, and the flush goes through a file-scope function too. Only a call with four or more arguments still builds a table and a closure. `test_equip_bracket` pins the bracket at zero bytes |
| About 96 | The follow tick (`dockFollow`) |
| About 96 | `Scenes.quiet`, the recorder's own housekeeping, not the addon's |

The idle bracket announces nothing (the C-01 gate), so nothing redraws; with that gate reverted the
same step costs about 180 KB. The 200 ceiling catches that, and it also catches the bracket going
back to allocating: the old vararg table and its two `xpcall` closures cost 344 bytes a step.

The same change cut the busy paths that run through the bracket on every call. A zone flip and
each binding's dispatch go through `E.Batch`, so `zoneFlips` fell from 149134 to 118023 bytes a step
and `triggerFanout` from 119534 to 104748; their ceilings moved down with them (120500 and 107000),
and the old bracket now fails both.

The figure before this was 1256 bytes. It also counted about 720 bytes the idle client never pays:
the scene settled on a frozen clock, so the update its setup asked for stayed throttled, and every
poll's flush canceled and re-armed that update's timer. The scene now moves the clock past the 1.5 s
throttle before it settles, and it asserts that no update is pending (`test_perf_harness`). The
re-arm still happens in game while an update is genuinely waiting (inside the throttle, or behind
the dead or casting gate): each Batch close cancels the timer and arms a new one.

## Complexity

Measured by the runner's sighted `complexity` suite at release (automated-tests-§3). The release is
gated on zero functions above CCN 15; the trend line is `automated-tests/RESULTS.md`. The design's
CCN risk register (§5.17) names the functions most likely to need one of the four sanctioned shapes.
