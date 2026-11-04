# Proposed changes — Ka0s Outfitter Reborn 1.1.0 (P8 review)

Standard: **Ka0s WoW Addon Standard v2.99.0 (2026-11-04)**, read from the sibling checkout
`../WowAddonStandards` at `f9c2117`. That checkout was clean and equal to `origin/master`, and no
network fetch was needed. Every change below was checked against that version, and none of them
introduces a new deviation.

Finding IDs refer to `01_FINDINGS.md`. Change IDs are `C-01` through `C-10`.

## HLD — themes

### T1. Announce what changed, not what might have (C-01, C-06)

`NS.Equip.Batch` serves two jobs. It brackets real stack mutations, and it groups producer `Set`s so
that one update runs for many edges. Its close announces `STACK_CHANGED` for both. The fix is to
make the announcement conditional on what actually happened inside the bracket, and to make the
window's reaction to `STACK_CHANGED` proportionate. A stack change re-draws the worn marks. It cannot
change an outfit's missing or banked status, which is inventory-driven.

- *Alternatives rejected.* (a) Stop the States poll from using `Batch`. That breaks the "one update
  for many edges" property the bracket exists for (design §5.10). (b) Throttle `Window.Render`. That
  hides the waste instead of removing it. (c) Diff the stack before and after in `flush`. That works,
  but it costs a copy per close. A flag set by the writers costs one boolean.
- *Trade-off.* Anything that silently relied on the spurious message stops receiving it. Today the
  only receiver is the window (`modules/Window.lua:29`). Two suites count the message
  (`tests/test_diagnostics.lua:214`, `tests/test_disabled.lua:203`) and must be re-read when this
  lands.

### T2. Bind triggers only once the world is loaded and the store repaired (C-02)

The LoadPass is documented as the point after which the addon acts (`docs/ARCHITECTURE.md:79`,
`docs/data-flow.md:27`), and the legacy `Initialized` guard kept scripts inert until it ran. The
binder should honor that. Its listeners can be installed at stand-up, but the bindings should wait
for the first LoadPass, which binds them anyway.

- *Alternative rejected.* Move the whole LoadPass to `OnEnable`. That gives up the 1 s
  post-`PLAYER_ENTERING_WORLD` delay (C32) the seed and the EM mirror depend on.

### T3. Let the client filter player-only unit events (C-03)

Use the `events-frames-taint-§1` unit-filter carve-out. Give the binder **one** frame, held on the
module, whose only job is `RegisterUnitEvent(event, "player")` for the `UNIT_*` events that bound
descriptors with `unit = "player"` name, plus the single `OnEvent` that hands them to the bound
contexts.

- *Alternative considered.* Route the cast start through PlayerState (design C18) as a new bus
  message. This honors C18 literally. But it adds catalog keys and senders (`test_bus`'s `SENDERS`),
  and it puts vehicle state in PlayerState. Keep it as the owner's alternative if C18 is meant to
  cover raw cast events as well as flags.
- *Alternative rejected.* One frame per binding. That is a frame factory, which the carve-out's
  "what the carve-out does not admit" paragraph forbids.

### T4. Fix the inherited locale patterns (C-04)

Correct the frFR and koKR overlays against strings captured on those clients, and stop caching a
duration that was read before the tooltip data existed. Row D8 stays as it is: the route is still a
tooltip read.

### T5. Make the zero-overhead evidence falsifiable (C-05)

Add an instrumentation-**absent** arm, as `performance-§9` requires. AuraMaster's `tests/perf.lua`
§7 (`probeAbsent`) is the collection's precedent.

### T6. Small hygiene (C-07 through C-10)

The load-time `Perf` upvalue, one stand-up walk instead of two, bounded binder targets, and the
misleading `cache` argument.

## Upstream change-set

None. No finding lands in `libs/` or `tests/_kit/`, and no entry below targets either path.

## LLD — per change

### C-01 — Conditional `STACK_CHANGED`, and a status-preserving redraw (F-001)

**`modules/Equip.lua`**

- Add `touched = false` to the session state `st` (`:42-44`).
- `E.Request` (`:140-144`): set `st.touched = true` before the depth check. Every stack writer
  (`wearBody`, `removeBody`, the Watch's temp update) already calls `E.Request`. Add a one-line
  `E.Touch()` for the stack writers that do not request: `St.TagLayer` (`modules/OutfitStack.lua:146`)
  and `St.Clear` when it runs outside a wear.
- `flush` (`:104-107`):

  ```lua
  local function flush(now)
      if now then E.Update() else scheduleUpdate() end
      if st.touched then
          st.touched = false
          NS.SendBus(NS.MSG.STACK_CHANGED)
      end
  end
  ```

- `E.Suspend`: reset `st.touched = false`.

**`modules/Window.lua`**: take `STACK_CHANGED` out of `DIRTY_ON` (`:29-31`) and register it
separately as `Win.MarkDirty(false)`. A stack change re-draws the worn marks but keeps the status
cache. `INVENTORY_CHANGED` and the outfit messages still wipe it.

- *Risk.* A path that changes the stack without calling `E.Request` would stop redrawing the window.
  The new suite case (C-06) and a grep for every `stack()` writer in `modules/OutfitStack*.lua` close
  that gap. The `PLAYER_REGEN_ENABLED` empty bracket (`modules/PlayerState.lua:171`) no longer
  announces. The window's own `onRegenEnabled` → `Dock.Refresh` → `MarkDirty(true)` covers that edge.
- *Moves:* the test count moves through C-06. `RESULTS.md`'s watch list is not expected to move.

### C-02 — The binder waits for the first LoadPass (F-002)

**`modules/Triggers_Binder.lua`**

- `B.Resume` (`:395-398`):

  ```lua
  function B.Resume()
      ensureListeners()
      -- The first LoadPass binds (modules/Outfits_Seed.lua); before it the store is unrepaired and
      -- the world not loaded (docs/data-flow.md, "Load and enable").
      if NS.Outfits.FirstPassDone() then B.BindAll() end
  end
  ```

- `B.SetActive(true)` (`:382-387`): apply the same gate, so `/of auto on` typed before the first
  LoadPass records the wish (the setting) and lets the LoadPass bind.
- `O.LoadPass` (`modules/Outfits_Seed.lua:193-203`) is unchanged. It calls `BindAll` directly, before
  `firstDone` is set, so it is unaffected by the gate.

- *Risk.* Re-enabling after a stand-down that happened before the first PEW still binds, because
  `O.Resume` arms the LoadPass when `stoodDown` is set (`modules/Outfits_Seed.lua:255-260`). Existing
  binder cases that call `B.Resume()` and expect bindings before any LoadPass must first drive
  `NS.Outfits.LoadPass()`. Re-read them, and do not weaken them. Each such case asserted the
  behavior this change removes, so it moves with the change, together with its `-- red under:` line.
- *Moves:* +1 case: "the binder holds no binding and dispatches nothing until the first LoadPass",
  `-- red under:` an unconditional `B.BindAll()` in `B.Resume`. `docs/test-cases.md` and the README
  `[tests]` badge move in the same change.

### C-03 — One player unit-filter frame for the binder (F-003)

**`modules/Triggers_Binder.lua`**

- Add a module-held `B.unitFrame`, created once and reused across stand-downs (the carve-out's
  reuse MUST). Its `OnEvent` fans out to `unitBound[event]`, a set of contexts.
- In `registerOne` (`:188-202`): when `ctx.desc.unit == "player"` and `e:find("^UNIT_")`, add `ctx`
  to `unitBound[e]`, and register `e` on the frame through
  `NS.SafeRegisterUnitEvent(B.unitFrame, e, B.rejected, "player")` when its set was empty. Do not
  call `NS.SafeRegisterEvent` for it.
- In `unbind` (`:247-260`): remove `ctx` from every `unitBound[e]`, and unregister `e` from the frame
  once its set empties.
- `B.Suspend` and `B.UnbindAll`: `B.unitFrame:UnregisterAllEvents()` and clear `unitBound`.
  AceAddon's `UnregisterAllEvents` cannot reach this frame (`events-frames-taint-§1`).
- `PLAYER_FLAGS_CHANGED` keeps the Lua filter. It is not a `UNIT_*` event, and the carve-out is
  written for `UNIT_*` filtering.
- Correct the header comment at `modules/PlayerState.lua:4-5`. PlayerState owns the **flags**, while
  a trigger that needs the raw cast start receives it through the binder's unit filter. If the owner
  prefers the C18 reading, take the PlayerState-message alternative from T3 instead.

- *Standards.* `events-frames-taint-§1` (the unit-filter frame: one job, held on the module,
  unregistered in the disable path, reused). `slash-commands-§7` (the stand-down reaches it).
  `testing-§1` (the kit mock records `RegisterUnitEvent`, so the new registration is visible to
  `test_disabled`).
- *Moves:* +1 case: "a Spellcast binding registers UNIT_SPELLCAST_START for player only, and another
  unit's cast never reaches the condition", `-- red under:` registering it through
  `SafeRegisterEvent`. `test_disabled`'s registration set must still empty. Test count, inventory and
  badge move together.

### C-04 — Correct the frFR and koKR use-duration patterns (F-004)

**`locales/frFR.lua:52-53`** and **`locales/koKR.lua:58`**: replace the values with patterns written
from tooltip lines **captured on those clients** (`03_SMOKE_TESTS.md` S-04 captures them). Do not
write them from memory. The shape to aim for:

- frFR: `"^Utiliser[ \194\160]?:.*pendant (%d+) sec"` and `"^Utiliser[ \194\160]?:.*[Dd]ure (%d+) sec"`.
  The optional NBSP class handles French typography. `sec` also covers the prefix of `secondes`.
- koKR: a pattern on the captured line's own seconds unit (for example `(%d+)초`), plus the second
  pattern if the capture shows one.

**`modules/Inventory_Lists.lua:250-263`** (`useDuration`): cache only when the tooltip produced at
least one line. An empty read (item data not yet loaded) answers 0 for this call without caching,
so the next read retries.

- *Standards.* `localization-§4`: these are `L` entries used for tooltip matching, already recorded
  as deviation D8 in `docs/ARCHITECTURE.md`. The change edits values inside that row's scope and adds
  no new row. Keys are unchanged, so `tools/rekey-locales.lua` and `test_locale` keep passing.
- *Moves:* +1 case: "each shipped locale's duration patterns match its captured sample line", with
  the samples from S-04 as fixtures.

### C-05 — An instrumentation-absent arm for the zero-overhead claim (F-005)

**`tests/perf.lua`** and **`tests/perf_scenes.lua`**: add `tooltipsAbsent`. It is the `tooltips`
step with `Tooltips.OnItem`'s two bracket lines removed, so it is the same gates and the same
`Tooltips.Decorate` call. Two ways to build it, in order of preference:

1. In the runner, load an absent instance whose `modules/Tooltips.lua` is the TOC's own file with
   `local t0 = Perf.on and debugprofilestop()` and `if t0 then Perf.Note("tooltipUsedBy", …) end`
   removed by `gsub` before the kit loader evaluates it. The load list stays TOC-derived
   (`testing-§9`), with one source transformed.
2. A public, unbracketed body. This needs the gates factored out of `OnItem` into a named local that
   both paths call.

Then pin `tooltipsCaptureOff.bytesPerIter <= tooltipsAbsent.bytesPerIter` (plus `PAIR_NOISE`), with
`-- red under: a string built beside the dormant t0 in Tooltips.OnItem`. Keep the existing off/on
pair: it is still the right check for the on-side slack.

- *Standards.* `performance-§9` (zero-overhead scenario, MUST), `performance-§2` (the evidence it
  backs).
- *Moves:* perf scenarios are not test cases (`testing-§7`), so the inventory and badge do not move.
  Update `docs/performance.md`'s "Offline scenarios" table in the same change.

### C-06 — A steady-window scenario and an idle-bracket case (F-006, guards C-01)

- **Suite case** (`tests/test_stack.lua` or `tests/test_dock.lua`): with the addon up and nothing
  changing, N `States` poll ticks send **zero** `STACK_CHANGED`. The case must prove the poll ran:
  assert its timer fired at least N times, so that zero sends after zero ticks cannot pass
  (`testing-§12`). `-- red under: reverting C-01's st.touched gate`.
- **Offline scenario** (`tests/perf.lua`): `dockIdle`, with the window shown on the `full_bags`
  scenario and one step equal to one poll tick plus one follow tick. Pin bytes per iteration (expected
  to be near zero once C-01 lands) and the `dockFollow` note count.
- *Moves:* +1 case, with the inventory and badge in the same change. The scenario is not counted.

### C-07 — File-scope `Perf` upvalue (F-007)

Move `local Perf = NS.Perf` to file scope in `modules/Dock.lua` (from `:123`), `modules/Bar.lua`
(`:259`), `modules/Inventory.lua` (`:375`), `modules/States.lua` (`:279`), `modules/States_Zone.lua`
(`:105`) and `modules/Tooltips.lua` (`:178`), after the existing file-scope locals.
`core/PerfSetup.lua` precedes all of them in the TOC.

- *Standards.* `performance-§2` ("MUST take the load-time upvalue … in both shapes").
- *Risk.* A suite that swaps `NS.Perf` after load would stop seeing the swap. None does
  (`grep -n "NS.Perf *=" tests/*.lua` is empty).

### C-08 — One stand-up walk (F-008)

`core/OutfitterReborn.lua:68-70`: replace `NS.RegisterGameEvents()` and the unguarded loop with
`NS.StandUp()`. That function (`core/LifecycleSetup.lua:56-63`) runs `NS.BusStandUp()`, which is a
no-op while the bus was never stood down, then `RegisterGameEvents`, then the guarded walk. Keep the
skin-picker timer after it.

- *Risk.* None functionally. The login and the re-enable now run literally one function. Confirm
  that `test_disabled`'s "Disabled 9" (re-enable from current state) and `test_loadorder` stay green.

### C-09 — Recycle deleted outfits' binder targets (F-009)

`modules/Triggers_Binder.lua`: on `OUTFIT_DELETED` (`:324`), after `B.Unbind(id)`, move `targets[id]`
to a `freeTargets` list. `targetFor` (`:213-220`) takes from `freeTargets` before calling
`NS.NewBusTarget()`. The bus record keeps every target it ever made (it has no release member), so
recycling is what bounds the count, to the largest number of outfits held at once. An unbound
target holds no registration, so reusing it is safe.

- *Moves:* +1 case: "deleting and re-creating outfits does not grow the bus record",
  `-- red under: targetFor without the free list`.

### C-10 — Drop the dead argument and name the status cache (F-010)

`modules/Outfits.lua:497-501`: rename the parameter to `statusCache` and call
`NS.Inventory.Missing(rec)`. `modules/Window_ListModel.lua:71-104`: the same rename. No behavior
change.

## Standards conformance (per change)

| Change | Rule(s) that shaped it | New deviation? |
|---|---|---|
| C-01 | `architecture-§4` (closed bus, one sender per key: `STACK_CHANGED` keeps its one sender, `modules/Equip.lua`) | No |
| C-02 | `slash-commands-§7` step 9 (stand-up rebuilds from current state: the LoadPass is the rebuild) | No |
| C-03 | `events-frames-taint-§1` unit-filter carve-out (one job, module-held, unregistered on disable, reused). A per-binding frame was rejected under the same section's "does not admit" paragraph | No |
| C-04 | `localization-§4`, inside existing row D8 | No |
| C-05 | `performance-§9` (MUST zero-overhead scenario), `testing-§9` (TOC-derived load list kept) | No |
| C-06 | `testing-§12` (the idle assertion proves the poll ran), `testing-§7` (the scenario is not counted) | No |
| C-07 | `performance-§2` | No |
| C-08 | `slash-commands-§7` (one stand-down/stand-up path) | No |
| C-09 | none | No |
| C-10 | none | No |

**Test-count movement, rolled up:** C-02 +1, C-03 +1, C-04 +1, C-06 +1, C-09 +1, for an expected
**+5 cases**. `docs/test-cases.md` (regenerated with `lua tests/run.lua --list`) and the README
`[tests]` badge move in the same commit as each case, never in a later one.
