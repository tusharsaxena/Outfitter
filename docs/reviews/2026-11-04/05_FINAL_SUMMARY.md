# Final summary — P8 review-and-fix cycle (written as if every check in 03_SMOKE_TESTS.md passed)

## Headline

The P8 review of the converted addon found no Critical or High defects. This cycle fixes the five
Medium findings and five Low ones.

- **Window redraws.** The outfit window no longer redraws itself twice a second while nothing is
  happening. Before the fix, every equipment bracket announced a stack change, including the idle
  mount/swim poll.
- **Trigger timing.** Triggers no longer act during the login, before the addon has repaired its
  saved outfits and the world has loaded.
- **Event filtering.** Player-only trigger events are now filtered by the client instead of in Lua.
- **Locales.** The French and Korean patterns that tell Trinket Queue a trinket's effect is still
  running were rewritten from strings captured on those clients.
- **Perf evidence.** The perf evidence now has an instrumentation-absent arm, so "free when capture is
  off" is measured instead of assumed.
- **Hygiene.** One stand-up path, bounded binder targets, the load-time `Perf` upvalue, and a dead
  argument removed.

## Counts

`Critical fixed: 0, High fixed: 0, Medium fixed: 5, Low fixed: 5`. No finding was deferred.

## Changes by theme

### T1. Announce what changed, not what might have

- **What changed:** an equipment bracket now announces `STACK_CHANGED` only when something inside it
  requested an update or touched the stack. The window treats a stack change as a redraw of the worn
  marks and keeps its outfit-status cache.
- **Why it mattered:** the 0.5 s poll and every out-of-combat aura scan forced a full window rebuild.
  The review measured about 177 KB of allocation per rebuild with five outfits, at 2 Hz, while the
  window was open and idle.
- **Findings / changes:** F-001, F-006, through C-01 and C-06.
- **Files touched:** `modules/Equip.lua`, `modules/OutfitStack.lua`, `modules/Window.lua`,
  `tests/test_stack.lua` (or `tests/test_dock.lua`), `tests/perf.lua`, `tests/perf_scenes.lua`,
  `docs/performance.md`, `docs/test-cases.md`, `README.md`.

### T2. Bind triggers only once the world is loaded

- **What changed:** the trigger binder installs its listeners at stand-up but binds nothing until the
  session's first LoadPass.
- **Why it mattered:** on every login after the first, a trigger whose condition held at login could
  wear an outfit before the store was repaired and before `PLAYER_ENTERING_WORLD`. This broke the
  documented "nothing before the first LoadPass" rule and the fork's `Initialized` guard. It also
  bound every outfit twice.
- **Findings / changes:** F-002, through C-02.
- **Files touched:** `modules/Triggers_Binder.lua`, `tests/test_trigger_binder.lua`,
  `docs/test-cases.md`, `README.md`.

### T3. Let the client filter player-only unit events

- **What changed:** Spellcast and the three vehicle-quest triggers receive their `UNIT_*` events
  through one binder-held unit-filter frame registered for `"player"`. Before this, every unit's
  event was taken on AceEvent and dropped in Lua.
- **Why it mattered:** in raids and battlegrounds, other units' cast starts entered Lua once per
  bound outfit.
- **Findings / changes:** F-003, through C-03.
- **Files touched:** `modules/Triggers_Binder.lua`, `modules/PlayerState.lua` (comment),
  `tests/test_trigger_binder.lua`, `docs/test-cases.md`, `README.md`.

### T4. Fix the inherited locale patterns

- **What changed:** the frFR and koKR use-duration patterns were written from tooltip lines captured
  on those clients. The frFR pattern accepts the NBSP before the colon. A duration read before the
  tooltip data loads is no longer cached.
- **Why it mattered:** both overlays carried the English word "seconds", inherited from the fork. As a
  result, Trinket Queue could swap out a trinket whose effect was still running.
- **Findings / changes:** F-004, through C-04.
- **Files touched:** `locales/frFR.lua`, `locales/koKR.lua`, `modules/Inventory_Lists.lua`,
  `tests/test_locale.lua` (or a new fixture), `docs/test-cases.md`, `README.md`.

### T5. Make the zero-overhead evidence falsifiable

- **What changed:** `tests/perf.lua` gained `tooltipsAbsent`, the bracketed tooltip path with its
  bracket removed. Capture off is now pinned against it, alongside the existing off/on pair.
- **Why it mattered:** the off/on pair could not catch a dormant bracket that allocates, because both
  arms pay that allocation (`performance-§9`).
- **Findings / changes:** F-005, through C-05.
- **Files touched:** `tests/perf.lua`, `tests/perf_scenes.lua`, `docs/performance.md`.

### T6. Hygiene

- **What changed:**
  - Six modules take `local Perf = NS.Perf` at file scope.
  - The login runs `NS.StandUp()` instead of a hand-copied walk.
  - Deleted outfits' binder targets are recycled.
  - `O.Status` no longer passes an argument `Inv.Missing` ignores.
- **Findings / changes:** F-007 through F-010, through C-07 to C-10.
- **Files touched:** `modules/Dock.lua`, `modules/Bar.lua`, `modules/Inventory.lua`,
  `modules/States.lua`, `modules/States_Zone.lua`, `modules/Tooltips.lua`, `core/OutfitterReborn.lua`,
  `modules/Triggers_Binder.lua`, `modules/Outfits.lua`, `modules/Window_ListModel.lua`,
  `tests/test_trigger_binder.lua`, `docs/test-cases.md`, `README.md`.

## API / behavior changes

- `STACK_CHANGED` (internal bus) no longer fires on a bracket that changed nothing. The public
  `OutfitterReborn.API.v1` events are unchanged.
- Triggers start acting about 1 s after the first loading screen of a session, instead of at
  `PLAYER_LOGIN`.
- No slash verb, setting, key binding, saved-variable key or locale key was added, renamed or
  removed. Only the frFR and koKR values of two existing keys changed.

## Saved-variable / migration notes

None. `NS.SCHEMA_VERSION` stays at 1, and no stored shape changed.

## Deprecated-API migrations

None.

## Performance impact

Fill in from the records. Do not estimate.

- Offline: `dockIdle` bytes per iteration, before and after, from the `tests/perf.lua` run at the
  fix commit. Today's tree (`9592fce`) has no such scenario. The review's scratch measurement of
  about 177 KB per dirty list build is orientation, not the record.
- In-client: the `dockFollow` bucket from the S-01 capture, committed under
  `docs/perf-analysis/<YYYYMMDD-HHMMSS>/`.

## Test and complexity movement

- Pass count: **1281 → 1286** (+5: C-02, C-03, C-04, C-06, C-09). The skip count stays at 1.
  `docs/test-cases.md` and the README badge moved in each case's own commit.
- Perf scenarios: +2 (`tooltipsAbsent`, `dockIdle`). These are not counted as test cases.
- Complexity: no watch-list entry is expected to move. The next release's regeneration of
  `docs/automated-tests/RESULTS.md` confirms that.

## Known follow-ups

- **OR-01** (stale doc set, plan step P11) and **OR-02** (README, plan step P10) remain with their
  own plan steps.
- Add Outfitter Reborn to `WowAddonStandards/standards/ADDONS.md`'s roster, so that the other repos'
  cross-addon passes include it. That change lands in the standards repo.
- `PLAYER_FLAGS_CHANGED` (PvP Flagged) keeps its Lua unit filter. It is not a `UNIT_*` event and is
  low-frequency.
- If the owner reads design C18 as covering raw cast events, move Spellcast to a PlayerState bus
  message (the alternative in T3).

## Verification evidence

- `docs/reviews/2026-11-04/03_SMOKE_TESTS.md`, with the sign-off table filled in.
- Commit range: `<first P8 fix commit>..<last>` on `feat/2026-11-03-ka0s-conversion`.

## Suggested commit message / PR description

```
P8: Review fixes — quiet idle window, bind after LoadPass, unit-filtered triggers

- Announce STACK_CHANGED only when a bracket touched the stack; the window
  keeps its status cache on a stack change (F-001, F-006)
- Hold trigger bindings until the session's first LoadPass (F-002)
- Filter Spellcast and vehicle-quest UNIT_* events to the player in the
  client through one binder unit-filter frame (F-003)
- Correct the frFR/koKR use-duration patterns from captured tooltips (F-004)
- Pin capture-off against an instrumentation-absent arm (F-005)
- File-scope Perf upvalue, one stand-up path, recycled binder targets,
  dead Inv.Missing argument (F-007..F-010)

Tests: 1281 -> 1286 passing (1 skip unchanged); docs/test-cases.md and the
README badge moved with each case.
Review bundle: docs/reviews/2026-11-04/
```
