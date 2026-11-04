# Review findings — Ka0s Outfitter Reborn 1.1.0 (P8)

**Verdict: minor issues.** Nothing here is Critical or High. The engine, the stand-down latch, the
secure queue and the docked window hold up when read against the legacy code. The suite is large and
mostly falsifiable. Five Medium findings: one measured steady-state perf waste, one broken
load-order invariant (also measured), one unit-event firehose, one locale defect carried over from
the fork, and one zero-overhead check that cannot fail.

**Resolved scope:** the whole addon at `9592fce` (branch `feat/2026-11-03-ka0s-conversion`, clean
tree). The scope directive was empty, and in a WoW repo the default is the full addon. That covers
the authored Lua under `core/`, `defaults/`, `modules/`, `settings/`, `locales/`, `tests/` and
`tools/`, plus the TOC, `Bindings.xml` and `.luacheckrc`. `libs/` and `tests/_kit/` are vendored. They
were checked only for vendor sync and the cross-addon pass. The standards audit's OR-01 (stale docs,
plan step P11) and OR-02 (README, plan step P10) are known to be open. They are noted below, not
filed again.

Standards cross-check: done against the Ka0s WoW Addon Standard **v2.99.0 (2026-11-04)**, read from
the sibling checkout `../WowAddonStandards` at `f9c2117`. That checkout's `status --porcelain` was
empty and its HEAD equals `ls-remote origin refs/heads/master`.

## Measurement run

Every run went through `~/.claude/dev-copilot/bin/ka0s-bounded`, from the repo root. Output was
written to a scratch path outside the repo, and nothing was written into the repo. Tool versions:
Lua 5.1.5, Luacheck 1.2.0, lizard 1.24.0, kit revision 50 (`tests/_kit/framework.lua:20`).

| Suite | Result | Command / detail |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 188 files | `ka0s-bounded luacheck .` |
| Headless suite | **pass**: 1281 passed, 0 failed, 1 skipped, 1282 total | `ka0s-bounded lua tests/run.lua`. The skip is the kit's diagnostics-contract opt-out case, which does not apply here: this addon keeps `enablesLogging` |
| `--list` inventory | **pass**: identical to the committed `docs/test-cases.md` (`diff` empty, Total 1281) | `ka0s-bounded lua tests/run.lua --list` to scratch |
| Offline perf | **ran**: 10 scenarios, 0 assertion failures | `ka0s-bounded lua tests/perf.lua`. Example: `equipPlanCaptureOff 500 iters 224032.1 bytes/iter`, `gaGenerationCaptureOn 200 iters 3.00 notes/iter 468126.8 bytes/iter`. Timings are for orientation only |
| Complexity (sighted) | **pass**: 0 warnings, max CCN 15, 40102 NLOC / 5046 functions, avg CCN 2.3; no blind or crashed files reported | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` (kit rev 50, so sighted) |
| `make test` | **not applicable**: there is no root `Makefile` | — |
| Vendor sync, LibKa0s | **pass**: `libs/LibKa0s` equals the `v1.85.0` tag's `LibKa0s/` except for the `media/icons/*.tga` files this addon does not ship (the icon prune named in `CLAUDE.md`). No file differs in content | `git -C ../LibKa0s archive v1.85.0 LibKa0s testkit`, then `diff -rq` |
| Vendor sync, kit | **pass**: `tests/_kit` is identical to `v1.85.0:testkit` | same `diff -rq` |
| Cross-addon class 1 (slash) | **clean** | Roster from `WowAddonStandards/standards/ADDONS.md`: 16 addons. Outfitter Reborn is **not yet on the roster**, so it was appended by hand. Scope is each addon's TOC load list. 32 roster roots plus Outfitter's `of` and `outfitter` (registered from `NS.SLASH`/`NS.SLASH_LONG`, `settings/Slash.lua:311-312`). No duplicates, and 0 raw `SLASH_*` assignments in loaded source |
| Cross-addon class 2 (minors) | **clean**: one line across all 17 (16 plus Outfitter), equal to the per-major minors at `v1.85.0`: `Bus:2 Charts:1 Compat:1 Core:15 DebugLog:22 Env:2 Glow:2 Item:3 Launcher:7 Lifecycle:3 Media:12 Options:37 Perf:15 Pool:3 Schema:3 Sim:2 Skin:16 Slash:21 Toast:3 Widgets:22` | the class-2 loop |
| Cross-addon class 3 (bytes) | **clean**: against reference AbsorbTracker, `diff -rq` lists 6 lines, every one under `media/icons/`, the per-addon icon prune. Outfitter ships 150 files under `libs/LibKa0s` | the class-3 loop |
| Cross-addon class 4 (`## Interface:`) | **clean**: `120105` for all 16, and Outfitter's TOC carries `120105` | the class-4 loop |

**Committed artifacts that disagree with today's run:**

- `docs/automated-tests/RESULTS.md` and its newest bundle `20261104-044201` (manifest `git.sha`
  `9a27eb7`, 6 commits behind HEAD) record tests `1277/1/1278` and complexity `40002 NLOC / 5040
  funcs`. The fresh run measures `1281/1/1282` and `40102 / 5046`. The record is stale, not wrong. It
  is regenerated at release. The watch list is unchanged: 0 warnings on both sides.
- `docs/test-cases.md` and the README `Tests 1281/1281` badge both match the fresh run.
- `docs/performance.md` quotes no per-scenario figures, so there is nothing for the fresh perf run to
  contradict.

**Scratch experiments run for this review.** These are not suites. They are bounded runs of
throw-away scripts that load the real addon through the kit loader, the same way `tests/perf.lua`
does. They live under the session scratchpad, not in the repo.

- `exp/stack_changed.lua` (F-001): 20 idle `States` poll rounds produced `STACK_CHANGED=20`,
  `Equip.Request=0`, `STATE_CHANGED=0`. One window list-model build with a fresh status cache
  allocates **177232 bytes** (12 entries, 5 outfits, `full_bags` scenario).
- `exp/prelp.lua` (F-002): on a second login with saved outfits, an outfit bound to RESTING was worn
  before any `PLAYER_ENTERING_WORLD`. The run printed `firstPassDone=false binderActive=true
  OUTFIT_WORN=1`.

---

## Medium

### F-001 — Every equipment bracket announces `STACK_CHANGED`, so the idle 0.5 s poll redraws the outfit window twice a second `[perf]`

- **Where:** `modules/Equip.lua:104-107`. `flush` sends unconditionally:
  `NS.SendBus(NS.MSG.STACK_CHANGED)` at `:106`. The States poll opens a bracket every tick:
  `modules/States.lua:357` `NS.Equip.Batch(applyPoll)`, armed by `:487`
  `target:ScheduleRepeatingTimer(poll, POLL_PERIOD)`, with `POLL_PERIOD = 0.5` at `:40`. The window
  marks itself dirty **and wipes its status cache** on that message: `modules/Window.lua:29` (`DIRTY_ON`
  includes `"STACK_CHANGED"`) and `:215`
  `bus:RegisterMessage(NS.MSG[key], function() Win.MarkDirty(true) end)`. The follow tick then redraws
  (`modules/Dock.lua:127` `NS.Window.RenderIfDirty()`).
- **Problem:** the bracket's close cannot tell "the stack changed" from "a producer grouped some
  `Set`s that changed nothing". The poll, every out-of-combat `UNIT_AURA` scan
  (`modules/States.lua:285`), every form poll and every zone read all announce a stack change. Each
  announcement rebuilds the whole list: every outfit's missing/banked status
  (`modules/Window_ListModel.lua:104`) and the three item sections (`:108`).
- **Impact:** measured headless, 20 idle poll rounds sent 20 `STACK_CHANGED` with 0 equipment
  requests and 0 state edges. One dirty list build allocates about 177 KB with 5 outfits. That is
  roughly 350 KB/s of garbage, plus the matching CPU, for as long as the window is open and nothing is
  happening. The in-client magnitude is **unverified** (mock allocator, 5 outfits). The legacy
  `EndEquipmentUpdate` called `self:Update(false)`, a non-forced refresh that kept the outfit list.
  The port turned it into a forced one.
- **Reachability:** any player with the outfit window open on the character sheet, on every 0.5 s
  poll tick and every out-of-combat aura change. The window is hidden in combat, so combat is not
  affected.
- **Coverage:** no suite case asserts that an idle bracket stays quiet, and no offline scenario
  drives this path (F-006).

### F-002 — Triggers bind and act at `PLAYER_LOGIN`, before the session's first LoadPass `[design]` `[correctness]`

- **Where:** `core/OutfitterReborn.lua:70` `for i = #modules, 1, -1 do NS[modules[i]].Resume() end`
  runs `TriggerBinder.Resume` → `B.BindAll()` (`modules/Triggers_Binder.lua:395-398`). `BindAll`'s only
  gates are the latch and `auto.enabled` (`:350`, `:352`). It has no first-pass gate. `B.Bind` then
  arms the BIND evaluation (`:283`), and `States.Resume` schedules an aura scan and a zone read whose
  edges dispatch straight into the bindings. The LoadPass, which repairs ids, seeds, runs
  `Stack.Init` and **then** binds, runs only 1 s after the first `PLAYER_ENTERING_WORLD`
  (`modules/Outfits_Seed.lua:193-203`).
- **Problem:** the documented invariant is "nothing is dispatched before `OnEnable` and the first
  LoadPass" (`docs/ARCHITECTURE.md:79`). `docs/data-flow.md:27` says the same thing ("…is dispatched on
  the bus before this and the first LoadPass"). The legacy addon activated scripts only after
  `Initialized` (`Outfitter.lua:5356`, then `ActivateAllScripts`). Here, on every login after the
  first, a trigger evaluates and wears outfits against an unrepaired stack, before `Stack.Init` has
  set the expected outfit and absorbed hand-changed gear, and before the world (zone, instance) has
  loaded. The LoadPass then unbinds and rebinds every outfit and repeats every BIND evaluation.
- **Impact:** measured headless (`exp/prelp.lua`). A RESTING-bound outfit was worn
  (`OUTFIT_WORN=1`) with `firstPassDone=false`. That is a swap decided on pre-world state, which the
  LoadPass's repair and `Stack.Init` were written to precede, plus double binding work on every
  login. Whether a wrong swap results in the client depends on what the login state reads. That part
  is **unverified**.
- **Reachability:** any player who has at least one outfit whose trigger condition holds at login
  (Resting in an inn, PvP Flagged, a druid form, Mounted, a zone outfit), on every login after the
  first. `auto.enabled` is on by default.
- **Coverage:** `tests/test_api.lua:246` pins only the public-API subscriber gate. No case asserts
  that the binder stays idle until `O.FirstPassDone()`.

### F-003 — Player-only trigger events are registered unfiltered and filtered in Lua `[perf]` `[design]`

- **Where:** `defaults/Triggers.lua:215-218` (`SPELLCAST`, `unit = "player"`,
  `events = { "UNIT_SPELLCAST_START" }`). Also `:51-52`, the three vehicle quests'
  `UNIT_ENTERED_VEHICLE` and `UNIT_EXITED_VEHICLE`, and `:235-238` (`PVP_FLAGGED`,
  `PLAYER_FLAGS_CHANGED`). Each binding registers them on its AceEvent target
  (`modules/Triggers_Binder.lua:198` `NS.SafeRegisterEvent(t, e, …)`) and discards other units in Lua
  (`:199` `if unitPasses(ctx.desc.unit, (...)) then`).
- **Problem:** AceEvent has no `RegisterUnitEvent`, so every unit's cast start enters Lua: raid
  members, nameplates, the target. It enters once per bound outfit. This also contradicts
  `modules/PlayerState.lua:4-5`: "THE ONE OWNER of the player flags (design C18). The triggers … never
  register these events themselves". PlayerState already holds `UNIT_SPELLCAST_START` for `"player"`
  on its unit-filter frame.
- **Impact:** in a raid or battleground, `UNIT_SPELLCAST_START` fires many times a second. Each
  firing costs a dispatch and a `PlainEquals` per Spellcast-bound outfit, all to drop the event. Not
  measured in a client, so the cost is **unverified**. `PLAYER_FLAGS_CHANGED` is low-frequency and
  matters little.
- **Reachability:** any player with an outfit bound to Spellcast, PvP Flagged, or one of the Argent
  Tournament, Vigilance on Wings or Flame Leviathan triggers, while in group content.

### F-004 — The frFR and koKR use-duration patterns cannot match a real tooltip, so Trinket Queue's skip-while-active rule is dead there `[locale]`

- **Where:** `modules/Inventory_Lists.lua:247`
  `local DURATION_PATTERNS = { L["^Use:.*for (%d+) sec"], L["^Use:.*Lasts (%d+) sec"] }`, read by
  `Inv.SlotItemActive` (`:269-275`). The overlays: `locales/frFR.lua:53`
  `"^Utiliser:.*pendant (%d+) seconds"` and `locales/koKR.lua:58` `"^사용 효과: (%d+) seconds"`. koKR
  has no second pattern.
- **Problem:** both overlays contain the English word "seconds", which no French or Korean tooltip
  prints. The frFR patterns also expect `Utiliser:` with no space, while French typography puts a
  non-breaking space (U+00A0) before the colon, which `%s` does not match either. These strings are
  inherited verbatim from the fork (`OutfitterStrings_fr.lua:330-331` at 7ea3dc3). They are not new,
  but the D8 deviation row now rests on them.
- **Impact:** `useDuration` answers 0 and caches it per item id for the session. The `TRINKET_QUEUE`
  trigger then treats an on-use trinket whose effect is still running as idle, and can swap it out in
  the middle of the effect. The exact client strings are **unverified** here (no client), and frFR's
  `Dure (%d+) sec` pattern may still match some items.
- **Reachability:** frFR and koKR players with an outfit on the Trinket Queue trigger.

### F-005 — The "zero-overhead" check compares capture off with capture on, so it cannot catch a dormant bracket that allocates `[tests]` `[perf]`

- **Where:** `tests/perf_scenes.lua:262-279` (`Scenes.pairFailures`). The two real checks are `:271`
  `if off.bytesPerIter > on.bytesPerIter + …` and `:275`
  `if on.bytesPerIter > off.bytesPerIter + Scenes.PAIR_SLACK`. `docs/performance.md:77` describes this
  pair as the zero-overhead evidence.
- **Problem:** `performance-§9` requires the zero-overhead scenario to pin that capture **off**
  allocates no more than the same path with the instrumentation **absent**. Off against on cannot
  show that. A bracket that allocates or concatenates before its gate pays the same bytes in both arms,
  and "off ≤ on" stays green.
- **Impact:** "free when off" (`performance-§2`) is an unverified claim. The brackets in the tree
  read correctly (`Perf.on and debugprofilestop()` everywhere), so this is about the evidence, not
  about shipped behavior.
- **Reachability:** only the offline perf evidence. Shipped code is unaffected, so this is capped at
  Medium.

## Low

### F-006 — No scenario or case covers the docked window's steady state `[tests]`

- **Where:** `tests/perf.lua:49`
  `local ITERS = { equipPlan = 500, zoneFlips = 50, triggerFanout = 100, tooltips = 50, gaGeneration = 200 }`.
  `dockFollow` lives only in the harness suite's `Scenes.OTHERS` (`tests/perf_scenes.lua:244`), with
  no allocation pin.
- **Problem:** the path that runs most while a player is looking at the addon (follow tick → dirty →
  `Win.Render`) has no byte figure and no "idle stays quiet" assertion. That is why F-001 went
  unnoticed.
- **Reachability:** only the test and perf inventory.

### F-007 — Six bracket sites look up `NS.Perf` per call instead of using the load-time upvalue `[perf]`

- **Where:** `modules/Dock.lua:123`, `modules/Bar.lua:259`, `modules/Inventory.lua:375`,
  `modules/States.lua:279`, `modules/States_Zone.lua:105` and `modules/Tooltips.lua:178`, each
  `local Perf = NS.Perf` inside the function. Compare `modules/Equip.lua:32` and
  `modules/Triggers_Binder.lua:32`, which take it at file scope.
- **Problem:** `performance-§2` says to "take the load-time upvalue (`local Perf = NS.Perf`) in both
  shapes". `core/PerfSetup.lua` precedes every module in the TOC, so nothing stops the file-scope form.
- **Reachability:** every bracketed call with capture off pays one extra table lookup. The cost is
  negligible, and `dockFollow` is the hottest of the six.

### F-008 — `OnEnable` hand-copies the stand-up walk, without its nil guard `[design]`

- **Where:** `core/OutfitterReborn.lua:70` (`NS[modules[i]].Resume()`, unguarded) against
  `core/LifecycleSetup.lua:59-62` (`if m and m.Resume then m.Resume() end`), whose comment at `:23`
  promises that "a name whose module has not landed is skipped".
- **Problem:** two copies of the login and re-enable path, one of them unguarded. A future rename or
  removal of a `NS.LIFECYCLE_MODULES` entry turns the login into a load error while the re-enable path
  stays green.
- **Reachability:** nobody today. All 20 names publish `Resume` (`Outfits` through
  `modules/Outfits_Seed.lua:255`). It is a hazard for the next edit.

### F-009 — The binder never releases a deleted outfit's bus target `[design]`

- **Where:** `modules/Triggers_Binder.lua:213-220` (`targets[id] = t`, kept "and reused") and `:324`
  `local function onDeleted(_, id) B.Unbind(id) end`.
- **Problem:** ids are never reused after a delete, so each deleted outfit leaves one AceEvent and
  AceTimer target in `targets` and in the bus record's replay list for the rest of the session.
- **Reachability:** a player who creates and deletes many outfits in one session. Bounded by the
  session, with no user-visible effect.

### F-010 — `O.Status` passes the window's status cache to `Inv.Missing`, which takes one argument `[naming]`

- **Where:** `modules/Outfits.lua:501` `NS.Inventory.Missing(rec, cache)` against
  `modules/Inventory_Lists.lua:54` `function Inv.Missing(rec)`. The `cache` here is the window's
  id → status map (`modules/Window_ListModel.lua:71`), not an inventory cache.
- **Problem:** the extra argument is silently dropped, and its name collides with the inventory
  `cache` used everywhere else in the same call chain. A reader expects it to be the inventory cache.
- **Reachability:** a code-reading hazard only, with no runtime effect.

---

## Noted, not filed again

- **OR-01 (plan step P11).** The doc set still describes the P3 scaffold:
  `docs/ARCHITECTURE.md` "Where the build stands", the Module Map outline "today only
  `modules/Diagnostics.lua`", Event Subscriptions "today the tree registers one game event", and the
  `(P4)` markers throughout `docs/data-flow.md` and `docs/taint.md`.
- **OR-02 (plan step P10).** README.
- The legacy guard warns only and holds nothing (O2), and both addons own `/outfitter` when both are
  loaded. This is documented in `docs/known-limitations.md` and the owner ruled on it.
- **Roster:** Outfitter Reborn is not yet a row in `WowAddonStandards/standards/ADDONS.md`. Until it
  is, every other repo's cross-addon pass skips it. That belongs to the standards repo, not this
  addon.

No `[upstream]` findings were raised. No `[cross-addon]` collisions were found.
