# Outfitter — post-implementation summary

**Date:** 2026-09-16 · **Baseline SHA:** `8ff8a26` · **Version at review:** 12.1.0.3

> **Status: template.** This document is written on the assumption that
> `04_EXECUTION_PLAN.md` has been executed and every test in `03_SMOKE_TESTS.md`
> has passed. Fill the bracketed placeholders from the actual run before using it
> as a PR description. **Do not hand-write a pass count** — take it from
> `./tests/run-all.sh`.

---

## Headline

This cycle did two things. It fixed four real defects in Outfitter's own code —
three of them one-token mistakes that Lua's truthiness rules made invisible, one a
leftover name-based gate in front of the map-ID zone detection that the rebuild was
supposed to have retired. And, more importantly, it repaired the test harness that
was supposed to have caught them.

The harness was green before this cycle and green after. The difference is that
three of its checks are now capable of going red. Two of them — the preset-event
whitelist and the initialisation assertion — were shown by injection to accept
arbitrary breakage while still printing `116 passed, 0 failed`. A harness that
cannot fail is worse than no harness, because it is read as evidence.

Nothing about the addon's structure, naming, file layout or public API changed.
Outfitter still looks like Outfitter.

---

## Counts

```
Critical fixed: 0   (none were raised)
High fixed:     [N] of 4
Medium fixed:   [N] of 12
Low fixed:      [N] of 7
```

**Deferred, with reasons:**

| Finding | Deferred because |
|---|---|
| F-006 (mock `Frame.__index` permissiveness) | Load-bearing for the no-XML-engine design; tightening it is its own project. Partially addressed — C-09 hardened the secret sentinel, which was the sharpest edge of it. |
| F-013 (three `bit.band` sites uncovered) | C-12 made them testable; writing the cases is separate work. In-client coverage is R-11 and R-12 until then. |
| F-022 (mock `hooksecurefunc` is a no-op) | Installing real hooks would start executing four never-exercised hook bodies during the load. |
| F-015 (widen `test_deprecated.lua:46`) | C-16 renamed it to what it checks, which closes the misleading part. Widening it is a different job. |

**Unverified items resolved in-client:** `SetBackdrop` at `OutfitterBar.lua:922`
(T-10) and the `GetQuestLink` signature at `Outfitter.lua:7654` (T-11). Record the
outcome of each here — if either failed, it is a **new finding**, not a regression
from this cycle.

---

## Changes by theme

### Theme A · Make the green mean something

**What changed.** The test harness can now fail in three places it previously could
not. An error anywhere in `Outfitter:Initialize` is reported by name instead of
being discarded. The WoW mock rejects event names the client would reject. The
preset-event check uses an explicit allow-list instead of a regex that matched
every realistic event name. The mock's stand-in for a secret value now raises on
indexing, `tostring`, `#` and concatenation, closing most of the gap between it and
the client's behaviour, and four more APIs can be made secret.

**Why it mattered.** `CLAUDE.md` tells the next maintainer that 0 failures means
their change introduced nothing. Three checks made that statement false in the
areas the harness was built to watch — including the preset-event check, which is
the only thing standing between the repo and a repeat of the "four presets sat dead
for years" failure. The failure it was missing was not even a quiet one:
`OutfitterScripting.lua:2095` routes an unrecognised event to the client's own
registration, which has thrown on unknown events since patch 8.0 — a fact recorded
in the addon's own comment at `Outfitter.lua:466`.

**Findings covered:** F-001, F-002, F-005, F-006 (partial), F-007, F-008, F-013.
**Changes implemented:** C-01, C-02, C-03, C-09, C-10, C-11, C-12.

**Files touched:**
- `tests/test_load.lua`
- `tests/test_scripts.lua`
- `tests/test_secrets.lua`
- `tests/wow_mock.lua`

### Theme B · Finish the map-ID zone rebuild

**What changed.** `Outfitter:UpdateZone` now decides whether to refresh the active
zone outfits by comparing the instance type and instance map ID alongside the zone
name, instead of the zone name alone. Six unread locals left over from the previous
implementation were removed. Two test cases cover `UpdateZone` itself, which
previously had none.

**Why it mattered.** The zone detection was rebuilt around map IDs precisely because
localized zone names had rotted, and the rebuilt function carries a comment saying
so. But the gate deciding whether to call it was still a zone-name comparison, and
Wintergrasp and Ashran each name both an outdoor zone and a battleground instance.
Entering or leaving one of those left the name unchanged, so the refresh was
skipped and the zone outfit neither equipped nor came off. The existing test
*"detection never reads a zone name"* covered the pure function and not the path
the client calls, which is how it stayed green.

**Findings covered:** F-003. **Changes implemented:** C-04, C-05.

**Files touched:**
- `Outfitter.lua`
- `tests/test_zones.lua`

### Theme C · Three always-true conditions

**What changed.** Three uses of `#someTable` as a truth test became explicit
comparisons.

**Why it mattered.** `#t` is always a number and every number in Lua is truthy,
including zero. Two of the three sit in `Outfitter:RemoveOutfit` and between them
made the recent-complete-outfit fallback try exactly one candidate and give up: the
`while` loop that was supposed to walk back through the history until it found a
surviving Complete outfit broke on its first iteration, every time. A player
removing a Complete outfit whose most recent predecessor had since been renamed or
deleted ended up wearing nothing. The third overcounted the main window's item list
by one row whenever the BoE category was empty — with the correct spelling sitting
eight lines above it in the same function.

None of the three is visible to `luacheck`, and none was covered by a test.

**Findings covered:** F-004, F-019. **Changes implemented:** C-06, C-07.

**Files touched:**
- `Outfitter.lua`
- `tests/test_outfits.lua`

### Theme D · Make a stranded `EquipmentUpdateCount` visible

**What changed.** `EndEquipmentUpdate` clamps at zero and reports an unmatched call
through the debug channel instead of going negative. `PlayerEnteringWorld` resets a
stranded count and says so. The count is reported by the existing `/outfitter zone`
diagnostic.

**Why it mattered.** This is the fork's characteristic silent failure, documented in
`CLAUDE.md`: a handler that raises between `BeginEquipmentUpdate` and
`EndEquipmentUpdate` leaves the count above zero, equipment updates stop firing for
the rest of the session, and the user has no symptom they can describe and no cue
that `/reload` is the fix. The two known raisers had been fixed at source; the
structure that turns any future raiser into the same invisible failure had not been
touched at any of its seventeen bracketed regions.

Deliberately **not** done: wrapping those regions in `pcall`. That would trade a
stuck count for a swallowed error, which is strictly harder to diagnose.

**Findings covered:** F-009. **Changes implemented:** C-08.

**Files touched:**
- `OutfitterEquipment.lua`
- `Outfitter.lua`

### Theme E · Saved-variable invariants

**What changed.** `Settings.Outfits` is created in `InitializeSettings` where the
rest of the defaults live, and the redundant guards in `CheckDatabase` were removed
so the function asserts one invariant instead of two contradictory ones twelve
lines apart. The two unguarded `pairs(vOutfit.Items)` loops were guarded to match
the third. A duplicated repair block and an orphaned local were deleted. The first
test in the repo that exercises a saved-variable shape at all was added.

**Why it mattered.** `Outfitter:CheckDatabase` is the migration path, carries CCN 27,
and had no test. It guarded `Settings.Outfits` in three places and not in the
fourth, while the thing that actually guarantees the field sits 200 lines away in
`Initialize`. That is how the next editor picks the wrong invariant.

**Findings covered:** F-012, F-018, and part of F-017.
**Changes implemented:** C-13, C-14.

**Files touched:**
- `Outfitter.lua`
- `tests/test_outfits.lua`

### Theme F · Packaging and documentation accuracy

**What changed.** `.pkgmeta` now excludes `Documentation/Images`,
`Documentation/RevisionHistory.txt` and `CHANGES.txt` — about 350 KB of maintainer
material that shipped to every player, none of it loadable by a client. Two
unreferenced textures were deleted. A packaging test now checks the converse
direction: nothing shipped is unreferenced. The README's command table gained the
four commands the in-game help documents and it did not, and `test_commands.lua`
now treats the README as a third surface. `Deprecated.lua`'s header no longer claims
more isolation than it has, and two test cases were renamed to describe what they
check.

**Why it mattered.** The packaging check ran in one direction only, so anything new
that should have been excluded shipped unnoticed. `Deprecated.lua`'s header claimed
"nothing here touches the live Outfitter tables", but preserved bodies open with
`local self = Outfitter` and call live methods — which is correct and necessary for
them to be revivable, and makes the written claim wrong in a way that matters when
someone relies on it.

**Findings covered:** F-014, F-015, F-017, F-020, F-021, F-022, F-023.
**Changes implemented:** C-15, C-16, C-17, C-18, C-19.

**Files touched:**
- `.pkgmeta`
- `README.md`
- `Deprecated.lua`
- `Outfitter.lua`
- `Textures/IconButtonHighlight.blp` *(deleted)*
- `Textures/Outfitter-Button-original.blp` *(deleted)*
- `tests/test_harness.lua`
- `tests/test_commands.lua`
- `tests/test_deprecated.lua`
- `tests/run-all.sh`
- `tests/run.lua`
- `tests/wow_mock.lua`

---

## API / behaviour changes

**Externally observable:**

1. **Zone outfits now fire on an instance change with an unchanged zone name.**
   Wintergrasp and Ashran are the shipped cases. Previously the outfit neither
   equipped on entry nor came off on exit.
2. **Removing a Complete outfit now falls back correctly.** The walk-back through
   the recent-complete history runs to completion instead of stopping after one
   candidate. Users who had grown used to "sometimes it wears nothing" will see
   behaviour change.
3. **The main window's item list no longer scrolls one row past its content** when
   there are no bind-on-equip items.
4. **`/outfitter zone` reports `EquipmentUpdateCount`.** New diagnostic line on an
   existing verb.
5. **Four commands added to the README** — `summary`, `rating`, `iteminfo`,
   `itemstats`. No new commands were added to the addon; these already worked and
   already appeared in `/outfitter help`.
6. **The download is roughly 350 KB smaller.** No shipped file that the addon loads
   or references was removed.

**No slash command was added, renamed or removed.** **No locale string key was
added, renamed or removed.** **The `Outfitter_*` / `OutfitterItemList_*` export
surface is unchanged** — `tests/test_load.lua:137` pins it and still passes.

---

## Saved-variable / migration notes

**No schema version bump.** `Settings.Version` remains 22.

One structural change: `Outfitter:InitializeSettings` now includes `Outfits = {}` in
the fresh-install defaults. This is not a migration — it moves a guarantee that
already existed at `Outfitter.lua:5217` to where the rest of the defaults are
declared, so the field is present from the moment the table is built.

**Existing profiles auto-migrate with no user action.** `CheckDatabase` runs
unchanged for Version < 22 profiles; the only difference is that two loops over
`vOutfit.Items` now guard against a missing `Items` table, which previously raised
inside `Initialize` for pre-6.2 profiles and prevented the addon coming up at all.

**No `/outfitter reset` is required, and none should be recommended.** If a user
reports empty outfits after this update, that is a C-13 failure and the change
should be reverted — see `03_SMOKE_TESTS.md` T-05.

---

## Deprecated-API migrations

**None.** No deprecated or removed API was replaced this cycle. The sweep over the
TOC-derived load list came back clean: no `UnitAura`/`UnitBuff`/`UnitDebuff`, no
`InterfaceOptions_AddCategory`, no `IsAddOnLoaded`/`LoadAddOn`, and every
`C_Container` call already routed through `Compat.lua`'s guarded seam.

Two API questions were carried into the client rather than guessed at:

| Question | Where | Resolved by |
|---|---|---|
| Does `OutfitterBar.lua:922`'s frame have `BackdropTemplate`? | `OutfitterBar.lua:922` | T-10 — `[result]` |
| Does `GetQuestLink` still take a quest log index? | `Outfitter.lua:7654` | T-11 — `[result]` |

If either came back FAIL, open it as a new finding against the next cycle. Neither
is a regression from this one.

---

## Performance impact

**Omitted — no perf-tagged findings were raised and this repo ships no perf
harness.** One change, C-04, makes `UpdateZone` run in cases it previously skipped;
the body is idempotent (every zone special gets a `SetSpecialOutfitEnabled` call on
every pass regardless of the gate), and `ScheduleUpdateZone` already coalesces at
0.01s, so the extra runs are no-ops rather than extra equipment changes. This is an
argument from the code, not a measurement, and it is stated as such.

---

## Test movement

```
Before:  116 passed, 0 failed   (19 suites, measured 2026-09-16 at 8ff8a26)
After:   [N] passed, 0 failed   ([N] suites)
```

There is no `docs/test-cases.md` in this repo and no `[tests]` badge in the README,
so nothing generated needs to move alongside the count. `CLAUDE.md`'s rule — 0
warnings and 0 failures, any other number is this change's fault — is the whole
contract.

**Complexity.** `lizard -l lua -x "./Libraries/*" -x "./tests/*" .` reported 28
warnings across 1007 functions at the baseline (avg CCN 3.5). Two changes move
entries on that list and the direction should be confirmed by re-running it:

| Function | Baseline | Expected direction |
|---|---|---|
| `Outfitter:UpdateZone` (`Outfitter.lua:4855`) | not flagged | up slightly — C-04 adds two conditions to the gate |
| `Outfitter:CheckDatabase` (`Outfitter.lua:6619`) | CCN 27 | **down** — C-13 removes three redundant guards |
| `Outfitter:EndEquipmentUpdate` (`OutfitterEquipment.lua:806`) | not flagged | up slightly — C-08 adds a branch |

`Outfitter:Initialize` (`Outfitter.lua:5140`, 127 NLOC / CCN 17 / 252 lines) remains
lizard's largest warning and was **not** touched. It is on notice, not scheduled.

---

## Known follow-ups

| Item | Rationale for deferring |
|---|---|
| Make the mock's `Frame.__index` strict | Its permissiveness is what lets the whole TOC load without an XML engine — the harness's central design choice. Tightening it means stubbing a large unknown surface. |
| Install real hooks in the mock's `hooksecurefunc` | Would start executing four hook bodies (`Outfitter.lua:5183`, `:5380-5382`, `:7694`) that no test has ever run, inside the load, with unpredictable fallout. |
| A `WithEquipmentUpdate(fn)` combinator across the 17 bracketed regions | Structurally the right answer to F-009, but a large mechanical diff across an 8,699-line file with no characterization test over any region. C-08's clamp and diagnostic get most of the value at a fraction of the risk. |
| Cases over the three `bit.band` sites | C-12 made them testable. Writing them is separate work; R-11 and R-12 are the in-client coverage until then. |
| Widen `test_deprecated.lua:46` to catch indented writes and reads into live tables | C-16 renamed it honestly, which closes the misleading half. Widening it needs a real parse, not a line regex. |
| Split `Outfitter.lua` | Explicitly **not** a follow-up. The flat root and the large file are upstream's and `CLAUDE.md` rules it out. Recorded here so nobody re-proposes it. |

---

## Verification evidence

- **Headless:** `./tests/run-all.sh` — `luac -p` over every file, `luacheck .`,
  and the suite. Green at `[SHA]`.
- **In-client:** `03_SMOKE_TESTS.md` with its sign-off table filled in. T-05A,
  T-05B and T-06 are the mandatory ones; T-01 and T-03 confirm the two behaviour
  changes that are unobservable headless.
- **Falsification:** the three mutations named in `04_EXECUTION_PLAN.md`'s
  Milestone 1 gate were each shown to redden the suite and then reverted, with
  `git diff --stat` empty after each.
- **Commit range:** `[8ff8a26..HEAD]`

---

## Suggested PR description

```
Fix four defects and repair three tests that could not fail

Four real bugs, three of them one-token mistakes that Lua's truthiness rules
made invisible to both the linter and the eye:

  * Outfitter.lua:3453/:3468 -- `if #t then` is always true, so the
    recent-complete fallback in RemoveOutfit tried exactly one candidate and
    stopped.  Removing a Complete outfit whose predecessor had been renamed or
    deleted left you wearing nothing.
  * Outfitter.lua:3205 -- the same mistake, with the correct spelling eight
    lines above it.  The item list scrolled one row past its content whenever
    there were no BoEs.
  * Outfitter.lua:4860 -- UpdateZone still gated on GetZoneText(), the
    localized name the map-ID rebuild was undertaken to stop matching on.
    Wintergrasp and Ashran each name both an outdoor zone and a battleground,
    so the zone outfit neither equipped on entry nor came off on exit.
  * OutfitterEquipment.lua:807 -- EndEquipmentUpdate had no floor, so an
    unmatched End drove the count negative and equipment updates stopped for
    the rest of the session with no symptom anyone could describe.

And the reason none of them was caught.  Three of the harness's checks were
shown by injection to accept arbitrary breakage while still printing
116 passed, 0 failed:

  * test_scripts.lua's preset-event whitelist had a `^[A-Z_]+$` escape hatch
    that every realistic event name satisfies.  The failure it was missing
    throws in the client -- OutfitterScripting.lua:2095 routes an unrecognised
    event to the client's own registration, which has rejected unknown events
    since 8.0.
  * run.lua pcalled Initialize and stashed the result in Ctx.initOK, which no
    suite ever read.  An error at the tail of the addon's largest function was
    completely invisible.
  * test_secrets.lua's source-discipline check matched only inline comparisons,
    never the bind-then-compare idiom the codebase actually uses.

Plus saved-variable invariants settled in CheckDatabase, ~350 KB of maintainer
documentation stopped shipping to players, and the README caught up with
/outfitter help.

No renaming, no restructuring, no new dependency.  Line endings preserved
per file.

Findings: F-001 .. F-023.  Changes: C-01 .. C-19.
Review bundle: docs/reviews/2026-09-16/
```
