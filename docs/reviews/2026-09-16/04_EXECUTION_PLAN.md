# Outfitter — execution plan

**Date:** 2026-09-16 · Implements `02_PROPOSED_CHANGES.md`

## Ordering principle

Milestone 1 comes first because every later milestone's verification depends on it.
Landing the behaviour fixes (M2, M3) against a harness that cannot detect an
`Initialize` failure or an unknown event registration means shipping them
unverified — which is the same position this review found the repo in.

Two standing rules for every task:

- **Check the target file's line ending before editing.** `Outfitter.lua`,
  `OutfitterEquipment.lua`, `Deprecated.lua` and everything under `tests/` are LF;
  `OutfitterScripting.lua`, `OutfitterQuickSlots.lua` and `OutfitterStrings*.lua`
  are CRLF. `tests/test_eol.lua` will catch a slip, but a whole-file re-ending
  buries the real change in the diff, which is the point.
- **`./tests/run-all.sh` must be green before every commit.** 0 warnings,
  0 failures. Any other number came from that commit.

---

# Milestone 1 · Make the harness able to fail

**Done when:** the suite is green, the pass count has risen, and each of the three
mutations below has been shown to turn it red and then reverted.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **M1-T1** | test-engineer | C-03 | `tests/test_load.lua` |
| **M1-T2** | test-engineer | C-02 | `tests/wow_mock.lua` |
| **M1-T3** | test-engineer | C-01 | `tests/test_scripts.lua` |
| **M1-T4** | test-engineer | C-09 | `tests/wow_mock.lua` |
| **M1-T5** | test-engineer | C-10 | `tests/test_secrets.lua` |
| **M1-T6** | test-engineer | C-11 | `tests/wow_mock.lua` |
| **M1-T7** | test-engineer | C-12 | `tests/wow_mock.lua` |

**Serialisation:** M1-T2, M1-T4, M1-T6 and M1-T7 all touch `tests/wow_mock.lua` →
**must serialise**, in that order. M1-T3 depends on M1-T2 landing (the allow-list
is only authoritative once the mock enforces it). M1-T5 depends on M1-T4.

**Parallelisable:** M1-T1 touches only `tests/test_load.lua` and can run alongside
anything.

**Falsification gate — required before this milestone is called done.** Apply each
mutation, confirm the suite goes red with a message naming the cause, revert, and
confirm `git diff --stat` is empty:

1. `error("x")` appended inside `run.lua`'s init `pcall`, after `Initialize()`.
   Must fail M1-T1's case with the injected text in the message. *(Today: 116
   passed, 0 failed.)*
2. `BOGUS_EVENT_XYZ` appended to the `$EVENTS` line at `OutfitterScripting.lua:160`
   — remember this file is **CRLF**. Must fail M1-T3's case. *(Today: 116 passed,
   0 failed.)*
3. Removing the `OutfitterAPI:UnsecretNumber(...)` wrapper at `Outfitter.lua:1835`.
   Must fail M1-T5's case.

**Expected turbulence.** M1-T2 and M1-T4 are the two tasks most likely to turn the
run red on first application, by surfacing real registrations and real truthiness
tests that were previously silent. Triage each as a finding before adding it to
`KNOWN_EVENTS` or working around it. Do **not** loosen the new checks to get back
to green — that reproduces exactly the defect this milestone exists to remove.

> **CHECKPOINT A — human review.** Before M2 starts. Confirm: (a) the pass count
> moved and by how much; (b) all three falsification mutations reddened the suite;
> (c) anything M1-T2 or M1-T4 surfaced has been written up rather than suppressed.

---

# Milestone 2 · Behaviour fixes

**Done when:** the suite is green, T-01 through T-04 in `03_SMOKE_TESTS.md` pass in
a client, and the new cases from M2-T2 and M2-T4 are shown to redden under a revert
of their paired source change.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **M2-T1** | lua-bugfixer | C-06 (3 lines) | `Outfitter.lua` (LF) |
| **M2-T2** | test-engineer | C-07 | `tests/test_outfits.lua` |
| **M2-T3** | lua-bugfixer | C-04 | `Outfitter.lua` (LF) |
| **M2-T4** | test-engineer | C-05 | `tests/test_zones.lua` |
| **M2-T5** | lua-bugfixer | F-010, F-011 (`PlayerIsFull` power fallback; `PreviousManaLevel`) | `Outfitter.lua` (LF) |
| **M2-T6** | test-engineer | F-010 mirror case | `tests/test_secrets.lua` |

**Serialisation — this is the milestone's critical path.** M2-T1, M2-T3 and M2-T5
**all touch `Outfitter.lua`** and must serialise. They touch disjoint regions
(`:3205`/`:3453`/`:3468`, `:4855-4866` + `:292`, `:1734`/`:1753`/`:1838-1855`), so
the order is free, but they cannot be applied concurrently.

M2-T2 must be written **before** M2-T1 lands — it is a characterization test, and
its whole value is pinning the pre-fix behaviour so the fix's effect is visible.
Write it, run it green against the unfixed code, then apply M2-T1 and update the
expectation in the same commit.

**Parallelisable:** M2-T4 and M2-T6 touch only test files and can be written
alongside the source tasks; they must land after their paired source change.

> **CHECKPOINT B — human review, and the first client session.** Run T-01, T-02,
> T-03, T-04 and T-07 from `03_SMOKE_TESTS.md`. C-06's `:3468` inversion is the one
> change in this cycle that makes code run which has **never run in this
> codebase** — the walk-back loop's behaviour past its first iteration is untested
> by construction. Do not proceed to M3 until T-03 has passed in a client.

---

# Milestone 3 · Saved variables and the equipment-update guard

**Done when:** the suite is green and T-05A, T-05B and T-06 pass in a client.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **M3-T1** | lua-bugfixer | C-08 (clamp + diagnostic) | `OutfitterEquipment.lua` (LF) |
| **M3-T2** | lua-bugfixer | C-08 (reset on entering world; count in `ShowZoneInfo`) | `Outfitter.lua` (LF) |
| **M3-T3** | lua-bugfixer | C-13 | `Outfitter.lua` (LF) |
| **M3-T4** | test-engineer | C-14 | `tests/test_outfits.lua` |

**Serialisation:** M3-T2 and M3-T3 both touch `Outfitter.lua` → **must serialise**.
M3-T1 touches only `OutfitterEquipment.lua` and is **parallelisable** with both.
M3-T4 lands after M3-T3.

**This is the riskiest milestone.** C-13 changes the shape of freshly-initialised
saved variables. A mistake here does not show as an error — it shows as a player's
outfits being empty after an update, which is unrecoverable for them and
indistinguishable from a reset. T-05 exists specifically for this and both halves
are mandatory.

> **CHECKPOINT C — human review, mandatory client session.** T-05A (existing
> profile) and T-05B (fresh install) must **both** pass before this milestone is
> called done. A pass on one and a failure on the other means C-13 is wrong in a
> specific way — see `03_SMOKE_TESTS.md` T-05 for which — and the change should be
> reverted rather than patched forward.

---

# Milestone 4 · Packaging, documentation and nits

**Done when:** the suite is green and T-09 passes against a built package.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **M4-T1** | packaging | C-15 (`.pkgmeta`) | `.pkgmeta` |
| **M4-T2** | test-engineer | C-15 (converse check) | `tests/test_harness.lua` |
| **M4-T3** | packaging | C-17 | `Textures/IconButtonHighlight.blp`, `Textures/Outfitter-Button-original.blp` (deleted) |
| **M4-T4** | docs | C-18 (README rows) | `README.md` |
| **M4-T5** | test-engineer | C-18 (README as third surface) | `tests/test_commands.lua` |
| **M4-T6** | docs | C-16 | `Deprecated.lua` (LF), `tests/test_deprecated.lua` |
| **M4-T7** | tooling | C-19 (`mktemp`; `git ls-files`; drop `xmlFrameCount`; `strsplit`) | `tests/run-all.sh`, `tests/run.lua`, `tests/wow_mock.lua` |
| **M4-T8** | lua-bugfixer | C-19 (`DeprecatedFeature` label) | `Outfitter.lua` (LF), `Deprecated.lua` (LF) |

**Serialisation:** M4-T6 and M4-T8 both touch `Deprecated.lua` → **must
serialise**. Everything else in this milestone touches a disjoint file set and is
**fully parallelisable**.

**Ordering note:** M4-T2's converse check must land *after* M4-T1 and M4-T3, or it
fails on the files those tasks remove.

> **CHECKPOINT D — final review.** Build a package and run T-09 from a clean AddOns
> folder. T-10 and T-11 (the two unverified items) are cheap to fold into the same
> session.

---

# Milestone 5 · Follow-ups (not scheduled)

Carried from `02_PROPOSED_CHANGES.md`'s *Deliberately not proposed* section. Each is
real work with real payoff and each is larger than anything above. Listed here so
they are findable, not so they are done now.

| Item | From | Why deferred |
|---|---|---|
| Make `Frame.__index` strict | F-006 | Permissiveness is load-bearing for the no-XML-engine design; tightening it is a week, not an hour |
| Install real hooks in the mock's `hooksecurefunc` | F-022 | Would start executing four never-exercised hook bodies inside the load |
| `WithEquipmentUpdate(fn)` combinator across 17 sites | F-009 | Large mechanical diff with no characterization test over any region |
| Cases over the three `bit.band` sites | F-013 | C-12 makes them possible; writing them is separate |
| Widen `test_deprecated.lua:46` to catch indented writes and reads | F-015 | C-16 renames it honestly; widening is a different job |

---

# Upstream change-set

**None.** No finding landed under `Libraries/`, and upstream Outfitter has been dead
since 2018, so there is no cross-repo handoff and no re-vendor commit in this plan.

---

# Critical-path / concurrency map

The whole plan's serialisation reduces to three shared files:

```
Outfitter.lua        M2-T1 → M2-T3 → M2-T5 → M3-T2 → M3-T3 → M4-T8
                     (six tasks, disjoint regions, order within a
                      milestone is free, across milestones is not)

tests/wow_mock.lua   M1-T2 → M1-T4 → M1-T6 → M1-T7 → M4-T7
                     (M1-T2 first: everything else assumes enforcement)

Deprecated.lua       M4-T6 → M4-T8
```

Everything else is parallelisable. Within M1 the test-file tasks (M1-T1, M1-T3,
M1-T5) can proceed alongside the mock chain subject to the stated dependencies.
Within M4, six of eight tasks are independent.

**Longest chain:** `M1-T2 → M1-T3 → CHECKPOINT A → M2-T3 → CHECKPOINT B → M3-T3 →
CHECKPOINT C → M4-T2 → CHECKPOINT D`. Four client sessions are unavoidable;
Checkpoints B, C and D can be collapsed into two if T-01…T-06 are run together.

---

# Commit strategy

One commit per task, so a revert is surgical. Suggested messages, in the repo's
existing style (imperative, no prefix convention in use):

```
Assert that Outfitter:Initialize succeeded

The runner pcalls InitializeInstant and Initialize and stashes the result in
Ctx.initOK, which no suite ever read.  An error at the tail of Initialize --
the largest function in the addon at 252 lines -- left the suite reporting
116 passed, 0 failed.  Verified by injection.

Findings: F-002.  Change: C-03.
```

```
Reject unknown events in the WoW mock

The client throws on an event that does not exist (Outfitter.lua:466) and the
mock accepted any string, so a typo'd event name in a preset reached a client
green.  Adds M.KNOWN_EVENTS and errors outside it.

Findings: F-005.  Change: C-02.
```

```
Give the preset event check a real allow-list

test_scripts.lua matched `not ev:match("^[A-Z_]+$")` as an escape hatch, which
every plausibly-named event satisfies -- so the case could not fail.  Appending
BOGUS_EVENT_XYZ to a live preset's $EVENTS left the suite at 116/0.  Replaced
with an explicit list of the client events a preset may declare.

Findings: F-001.  Change: C-01.
```

```
Fix three always-true length tests

`#t` is always a number and every number is truthy, so `if #t then` never
guards anything.  Outfitter.lua:3453 and :3468 between them made the
recent-complete fallback try exactly one outfit and stop; :3205 overcounted the
item list by one row.  The correct form is eight lines above :3205.

Findings: F-004, F-019.  Change: C-06.
```

```
Gate UpdateZone on the instance rather than the zone name

GetCurrentZoneIDs was rebuilt to be map-ID driven, but UpdateZone still decided
whether to call it by comparing GetZoneText() -- the localized name the rebuild
disowned.  Wintergrasp and Ashran each name both an outdoor zone and a
battleground, so the refresh was skipped across exactly the transition that
matters.  Also drops six unread locals.

Findings: F-003.  Change: C-04.
```

```
Clamp EquipmentUpdateCount and report a stranded one

An unmatched End drove the count negative and the == 0 test then never fired
again, silently stopping equipment updates for the rest of the session with no
symptom a user could describe.  Clamps at zero, reports the unmatched call, and
resets on entering the world.

Findings: F-009.  Change: C-08.
```

Milestone 4's eight tasks may reasonably be squashed into two commits — one for
packaging (`M4-T1`, `M4-T2`, `M4-T3`) and one for documentation and nits — since
none of them changes behaviour.
