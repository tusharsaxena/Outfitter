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

While idle, out of combat with the window closed, the addon should run nothing but its event
handlers on the edges it listens to; the window's follow tick exists only while the window is shown.

## Taking a capture

All in game, through the reserved `perf` verb (`/of perf help` lists the words):

- `/of perf start [label]`: begin a run; records who and where you are.
- `/of perf measure a`: arm experiment A, the addon active. It records only while combat lasts.
- Fight, then leave combat.
- `/of perf measure b`: arm experiment B, the same with the addon suspended through the latch's
  `perf` hold.
- Fight the same way for about as long, then leave combat.
- `/of perf finish`, `/reload`, then `/of perf report`: prints the summary and the one JSON line.

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

Each carries a byte ceiling a little above its measured figure and a pinned note count, and each
pair must agree: capture off allocates nothing over capture on, and on no more than 64 bytes per
step over off. Capture off alone may carry a one-off of up to 8 KB per measured window, granted only
while it spreads to under 16 bytes per bracket call, so it can never hide a per-call allocation
(`Scenes.pairFailures` in `tests/perf_scenes.lua`; `tests/perf.lua`'s header has the figures). A ceiling is raised only by re-measuring and saying why. The runs are kept in
[`automated-tests/`](automated-tests/README.md), not in `perf-analysis/`.

## Complexity

Measured by the runner's sighted `complexity` suite at release (automated-tests-§3). The release is
gated on zero functions above CCN 15; the trend line is `automated-tests/RESULTS.md`. The design's
CCN risk register (§5.17) names the functions most likely to need one of the four sanctioned shapes.
