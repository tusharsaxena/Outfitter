# Outfitter — proposed changes (HLD + LLD)

**Date:** 2026-09-16 · **SHA:** `8ff8a26` · Derived from `01_FINDINGS.md`

## Standards conformance

The Ka0s WoW Addon Standard **does not apply to this repository** (`CLAUDE.md`), so
no conformance check was performed and no standard version was resolved. This is a
deliberate exclusion, not a skipped step.

The constraints that *do* govern every change below are `CLAUDE.md`'s own:

- Upstream naming is preserved — `pFoo` parameters, `vFoo` locals, `cFoo`
  constants. No renaming toward any other convention.
- Tabs, flat root directory, global `Outfitter` table, `OutfitterAPI` compat seam.
- The `Outfitter_*` / `OutfitterItemList_*` export surface does not shrink.
- **Line endings are per-file and must be preserved.** `Outfitter.lua`,
  `OutfitterEquipment.lua` and `Deprecated.lua` are LF; `OutfitterScripting.lua`,
  `OutfitterQuickSlots.lua` and the `OutfitterStrings*` family are CRLF. Every
  change below names the file's ending so an editor cannot re-end it by accident.
  `tests/test_eol.lua` will catch a slip, but it should not have to.
- Retiring something follows `Deprecated.lua`'s shape; reviving something removes
  it from that file entirely.
- The harness stays bespoke. Nothing below adopts an external test kit.

**Nothing in this document targets a path under `Libraries/`.** The eight `MC2*`
libraries and the third-party ones are upstream's, read-only here, and no finding
landed in them.

---

# HLD — themes

## Theme A · Make the green mean something

**Rationale.** The battery is 116/116 and the lint is clean, and both are load-bearing
claims in `CLAUDE.md` ("any number other than zero is something this change
introduced"). Three of the suite's checks are demonstrably incapable of going red
(F-001, F-002, F-008), and the mock cannot express two failure classes the addon
explicitly guards against (F-005, F-006). Every one of those was written in good
faith and reads as coverage. The cost of leaving them is that the next regression
in exactly the area the harness was built to watch arrives green.

This theme is deliberately first. Fixing F-003/F-004 without it means the fixes ship
unverified too.

**Alternatives considered.**

- *Delete the inert cases rather than repair them.* Rejected: each names a real
  invariant worth holding, and deleting one trades a misleading green for a silent
  gap. The names are right; the implementations are not.
- *Broaden `Outfitter.BuiltinEvents` so F-001's check can drop its escape hatch.*
  Rejected outright: `BuiltinEvents` has runtime meaning —
  `OutfitterScripting.lua:2095` and `:2106` use it to choose between custom
  dispatch and real client registration. Adding `PLAYER_ENTERING_WORLD` to it
  would stop that event reaching the client. The allow-list must be a
  **test-side** constant.
- *Make the mock strict everywhere (error on unknown widget methods).* Rejected as
  the first move: `Frame.__index`'s permissiveness (F-006) is what lets the whole
  TOC load without an XML engine, which is the harness's central design choice.
  Tightening it is a separate, larger piece of work with a real chance of turning
  a 116/116 run into a week of stubbing. Left as a follow-up, not proposed here.

**Trade-off accepted.** F-006's mock-secret hardening will very likely turn up
existing truthiness tests on API returns that are currently silent. That is the
point, but it means Milestone 1 may grow. It is scheduled before the behaviour
fixes so the discovery happens early.

## Theme B · Finish the map-ID zone rebuild

**Rationale.** `GetCurrentZoneIDs` was rewritten to be map-ID driven and is
well-tested for it, but `UpdateZone` still decides *whether to call it* by comparing
a localized zone name (F-003). The rebuild's stated purpose — "Nothing here matches
on a zone name, which is what rotted the previous version" — is true of the function
the test covers and false of the function the client calls. The five-table
invariant is in good shape; this is the last name-based gate.

**Alternatives considered.**

- *Drop the early return entirely and recompute every time.* Rejected:
  `ScheduleUpdateZone` is wired to `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS` and
  `ZONE_CHANGED_NEW_AREA` (`Outfitter.lua:5275-5277`), and `ZONE_CHANGED` fires
  often enough that an unguarded `SetSpecialOutfitEnabled` sweep across 33 zone
  specials on each one is real work. The 0.01s coalescing in
  `ScheduleUpdateZone` reduces bursts but does not eliminate them. Keep a gate;
  gate on the right thing.
- *Gate on map ID alone.* Rejected: it would stop `UpdateZone` running on an
  ordinary outdoor zone change, and `self.CurrentZone` is read elsewhere.

## Theme C · Repair the three always-true conditions

**Rationale.** `#t` used as a truth test is always true in Lua. Three sites (F-004
×2, F-019). Two of them disable the recent-complete fallback on a documented user
flow; the third overcounts a scroll frame. All three are one-token fixes with the
correct form visible nearby in the same file, and none is reachable by luacheck.

**Alternatives considered.** None needed — the intent is unambiguous in every case
and `Outfitter.lua:3197` shows the author's own correct spelling eight lines above
`:3205`.

## Theme D · Make a stranded `EquipmentUpdateCount` visible

**Rationale.** `CLAUDE.md` documents this as the fork's characteristic failure:
equipment updates silently stop, with no symptom a user can describe and no
recovery short of `/reload`. The two known raisers were fixed; the structure that
makes any future raiser do the same thing was not (F-009).

**Alternatives considered.**

- *Wrap all 17 regions in `pcall`.* Rejected. It converts a stuck-count failure
  into a swallowed-error failure, which is strictly harder to diagnose, and it
  would hide exactly the secret-value errors `test_secrets.lua` exists to surface.
- *A `WithEquipmentUpdate(fn)` combinator replacing all 17 sites.* Rejected for
  now as too large a mechanical diff across a 8,699-line file with no
  characterization test over any of the 17 regions. The clamp and the diagnostic
  get most of the value for a fraction of the risk; the combinator is listed under
  follow-ups.

## Theme E · Packaging and documentation accuracy

**Rationale.** Small, cheap, and each one closes an asymmetry: `.pkgmeta` is
checked in one direction only (F-014), `Deprecated.lua`'s header claims more than
it delivers (F-015), and the README documents fewer commands than the client does
(F-021).

---

# Upstream change-set

**None.** No finding landed under `Libraries/`. The eight `MC2*` libraries are
upstream's own and were not in scope; the third-party libraries (LibStub,
CallbackHandler, LibDataBroker, LibBabble, LibDropdown, LibTipHooker, UTF8) were
read where the addon touches them and nothing was found. Upstream Outfitter is dead
(John Stephen, 2018), so there is nowhere to send a fix in any case — anything found
there would have to become a presence-guarded workaround in Outfitter's own code.

---

# LLD — change-set

## C-01 · Give the preset-event whitelist a real allow-list

**Covers:** F-001 · **File:** `tests/test_scripts.lua` (LF) · **Risk:** low

Replace the regex escape hatch with an explicit set of the raw client events
presets are permitted to declare. Derive it from the `$EVENTS` lines actually
present in `Outfitter.PresetScripts` today, reviewed by hand once, then pinned.

Before (`:109-121`):

```lua
for ev in (fields and fields.Events or ""):gmatch("([%w_]+)") do
	if not Outfitter.BuiltinEvents[ev] and not ev:match("^[A-Z_]+$") then
```

After:

```lua
-- Raw client events a preset may declare.  Anything not in BuiltinEvents goes to
-- EventLib:RegisterEvent, which the client rejects if the event does not exist
-- (see the comment at Outfitter.lua:466), so this list is the only thing between a
-- typo and an in-game error.  Adding to it means confirming the event is real.
local CLIENT_EVENTS = {
	PLAYER_ENTERING_WORLD = true, PLAYER_FLAGS_CHANGED = true,
	QUEST_LOG_UPDATE = true, ZONE_CHANGED = true, ZONE_CHANGED_NEW_AREA = true,
	ZONE_CHANGED_INDOORS = true, UNIT_SPELLCAST_START = true,
	TRADE_SKILL_SHOW = true, TRADE_SKILL_CLOSE = true,
	PET_BATTLE_OPENING_DONE = true, PET_BATTLE_CLOSE = true,
	ACTIVE_TALENT_GROUP_CHANGED = true,
	-- ...completed from the full $EVENTS sweep during implementation
}
...
	if not Outfitter.BuiltinEvents[ev] and not CLIENT_EVENTS[ev] then
```

Add a `-- red under:` comment recording the mutation that reddens it —
appending `BOGUS_EVENT_XYZ` to any preset's `$EVENTS` line — so the next reader
does not have to re-derive falsifiability.

**Depends on C-02**, which is what makes the list authoritative rather than
another hand-maintained copy that can drift.

## C-02 · Make the mock reject unknown events

**Covers:** F-005 · **File:** `tests/wow_mock.lua` (LF) · **Risk:** medium

Before (`:81`):

```lua
function Frame:RegisterEvent(e) self.__events = self.__events or {}; self.__events[e] = true end
```

After:

```lua
-- The client throws on an event that does not exist (Outfitter.lua:466), so the
-- mock has to as well -- otherwise a typo'd event name in a preset or a handler
-- passes headless and errors in someone's game.
function Frame:RegisterEvent(e)
	if not M.KNOWN_EVENTS[e] then
		error("RegisterEvent: no such event " .. tostring(e), 2)
	end
	self.__events = self.__events or {}; self.__events[e] = true
end
```

`M.KNOWN_EVENTS` is a new mock-level table holding every real client event the
addon or its presets register. Expect this to surface registrations not currently
in the list — that discovery is the change's main value.

**Risk note:** this can turn a green run red on first application. That is a
finding, not a regression; triage each before adding it to `KNOWN_EVENTS`.

## C-03 · Assert that initialisation succeeded

**Covers:** F-002 · **Files:** `tests/test_load.lua` (LF) · **Risk:** none

Add as the **first** case in the `load` suite, so an init failure is reported once,
by name, ahead of the eight downstream symptoms it causes:

```lua
Kit.test("the addon initialized without raising", function()
	-- run.lua pcalls InitializeInstant + Initialize.  Without this case the error
	-- is discarded and a failure in the tail of Initialize -- the largest function
	-- in the addon -- is completely invisible: 116 passed, 0 failed.
	Kit.isTrue(Ctx.initOK, "Outfitter:Initialize raised: " .. tostring(Ctx.initError))
end)
```

Pass count moves 116 → 117.

## C-04 · Gate `UpdateZone` on the instance, not the zone name

**Covers:** F-003 · **File:** `Outfitter.lua` (**LF**) · **Risk:** medium

Before (`:4855-4866`):

```lua
function Outfitter:UpdateZone()
	local vCurrentZone = GetZoneText()
	local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID = GetInstanceInfo()

	-- Just return if the zone isn't changing
	if vCurrentZone == self.CurrentZone then
		return
	end

	self.CurrentZone = vCurrentZone
	self.CurrentZoneIDs = self:GetCurrentZoneIDs(self.CurrentZoneIDs)
```

After:

```lua
function Outfitter:UpdateZone()
	local vCurrentZone = GetZoneText()
	local _, vInstanceType, _, _, _, _, _, vInstanceMapID = GetInstanceInfo()

	-- Gate on what the decision below actually reads.  The zone name alone is not
	-- enough: Wintergrasp and Ashran each name both an outdoor zone and a
	-- battleground instance, so entering or leaving one leaves the name unchanged
	-- while the zone outfits that apply change completely

	if vCurrentZone == self.CurrentZone
	and vInstanceType == self.CurrentInstanceType
	and vInstanceMapID == self.CurrentInstanceMapID then
		return
	end

	self.CurrentZone = vCurrentZone
	self.CurrentInstanceType = vInstanceType
	self.CurrentInstanceMapID = vInstanceMapID
	self.CurrentZoneIDs = self:GetCurrentZoneIDs(self.CurrentZoneIDs)
```

Initialise `Outfitter.CurrentInstanceType = nil` and
`Outfitter.CurrentInstanceMapID = nil` alongside
`Outfitter.CurrentZoneIDs = {}` at `Outfitter.lua:292`, so the two new fields are
declared where the existing one is.

This also removes the six unread locals from F-017.

**Risk note:** `UpdateZone` now runs in cases it previously skipped. The body is
already idempotent — `SetSpecialOutfitEnabled(id, vIsActive)` is called for every
zone special on every pass regardless — so the extra runs are no-ops, not extra
equipment changes. Confirm in-client per `03_SMOKE_TESTS.md`.

## C-05 · Cover `UpdateZone` in the zone suite

**Covers:** F-003, F-004 (coverage) · **File:** `tests/test_zones.lua` (LF) · **Risk:** none

Two cases, both falsifiable by reverting C-04:

```lua
Kit.test("a map change with an unchanged zone name still refreshes the zone outfits", function()
	-- red under: reverting UpdateZone's gate to `vCurrentZone == self.CurrentZone`
	Mock.reset()
	Mock.state.instanceType, Mock.state.instanceMapID = "none", nil
	Outfitter.CurrentZone, Outfitter.CurrentInstanceType, Outfitter.CurrentInstanceMapID = nil, nil, nil
	Outfitter:UpdateZone()
	Kit.isTrue(Outfitter.CurrentZoneIDs.Battleground ~= true, "outdoors")
	-- same zone text, now the battleground instance
	Mock.state.instanceType, Mock.state.instanceMapID = "pvp", 2118
	Outfitter:UpdateZone()
	Kit.isTrue(Outfitter.CurrentZoneIDs.Wintergrasp, "Wintergrasp after entering the instance")
	Mock.reset()
end)

Kit.test("UpdateZone never reads a zone name to decide what applies", function()
	-- The zone-name rot again, one level up: GetCurrentZoneIDs is clean (above),
	-- but UpdateZone is what the client calls.
	...
end)
```

Pass count moves 117 → 119.

## C-06 · Repair the three always-true length tests

**Covers:** F-004, F-019 · **File:** `Outfitter.lua` (**LF**) · **Risk:** low

| Line | Before | After |
|---|---|---|
| `3453` | `and #self.Settings.RecentCompleteOutfits then` | `and #self.Settings.RecentCompleteOutfits > 0 then` |
| `3468` | `if #self.Settings.RecentCompleteOutfits then` | `if #self.Settings.RecentCompleteOutfits == 0 then` |
| `3205` | `if vBoEItems and #vBoEItems then` | `if vBoEItems and #vBoEItems > 0 then` |

Note `:3468` inverts as well as fixing — the loop must break when the list is
*exhausted*, and today it breaks unconditionally after one iteration. This is the
one entry in this document that **changes behaviour rather than restoring it**: the
walk-back has never run in this codebase, so what it does with a list of stale
names is untested by construction. Verify in-client.

## C-07 · Add a characterization test for the recent-complete fallback

**Covers:** F-004 · **File:** `tests/test_outfits.lua` (CRLF? — check;
`test_eol.lua` does not pin `tests/`, so match the file's existing ending) · **Risk:** none

Before C-06 lands, pin current behaviour; after, pin the corrected behaviour. At
minimum: removing a Complete outfit with a recent list whose head names a deleted
outfit must fall through to the second entry.

Pass count moves 119 → 120.

## C-08 · Clamp and report `EquipmentUpdateCount`

**Covers:** F-009 · **File:** `OutfitterEquipment.lua` (**LF**) · **Risk:** low

Before (`:806-808`):

```lua
function Outfitter:EndEquipmentUpdate(pCallerName, pUpdateNow)
	self.EquipmentUpdateCount = self.EquipmentUpdateCount - 1

	if self.EquipmentUpdateCount == 0 then
```

After:

```lua
function Outfitter:EndEquipmentUpdate(pCallerName, pUpdateNow)
	-- An unmatched End drives the count negative, and the == 0 test below then
	-- never fires again for later balanced pairs -- equipment updates stop for the
	-- rest of the session with no symptom anyone can describe
	if self.EquipmentUpdateCount <= 0 then
		self:DebugMessage("EndEquipmentUpdate without a matching Begin (%s)", tostring(pCallerName))
		self.EquipmentUpdateCount = 0
	else
		self.EquipmentUpdateCount = self.EquipmentUpdateCount - 1
	end

	if self.EquipmentUpdateCount == 0 then
```

Plus, in `Outfitter:PlayerEnteringWorld` (`Outfitter.lua:1480`, LF) — before the
existing `self:BeginEquipmentUpdate()` at `:1484`:

```lua
	-- A handler that raised between Begin and End left the count stranded; entering
	-- the world is the natural place to recover, since nothing is mid-update here
	if self.EquipmentUpdateCount ~= 0 then
		self:DebugMessage("EquipmentUpdateCount was %d entering the world; resetting", self.EquipmentUpdateCount)
		self.EquipmentUpdateCount = 0
	end
```

And extend `Outfitter:ShowZoneInfo` — or better, add one line to it — reporting the
count, so `/outfitter zone` becomes a usable "is it stuck?" check. Keeping it on an
existing verb avoids adding a command that would need a README row, a help line and
a `test_commands.lua` update.

## C-09 · Harden the mock's secret sentinel

**Covers:** F-006 · **File:** `tests/wow_mock.lua` (LF) · **Risk:** medium

Before (`:140`):

```lua
local SECRET = setmetatable({}, {__tostring = function() return "<secret>" end})
```

After:

```lua
-- Compat.lua:85 states the rule this has to enforce: "the check has to come before
-- any other test (including a plain truthiness test) since that's an inspection
-- too".  A bare table raises on arithmetic and comparison but happily answers a
-- truthiness test and tostring, so it was silent on exactly the two inspections
-- the seam exists to catch.
local function refuse() error("inspected a secret value", 2) end
local SECRET = setmetatable({}, {
	__index = refuse, __newindex = refuse, __len = refuse,
	__concat = refuse, __tostring = refuse, __call = refuse,
	__add = refuse, __sub = refuse, __mul = refuse, __div = refuse,
	__lt = refuse, __le = refuse, __eq = refuse,
})
```

`issecretvalue` must keep answering for it — `OutfitterAPI:IsSecret` already
`pcall`s the call (`Compat.lua:91-99`), so that path is safe.

**Caveat, stated plainly:** Lua 5.1 cannot make a truthiness test on a table raise —
`if t then` has no metamethod. So this change closes `tostring`, `#`, `..` and
indexing, but **not** the bare truthiness test. That residual gap should be noted
in the mock's comment rather than papered over; catching it needs the static check
in C-10.

## C-10 · Widen the secret source-discipline check

**Covers:** F-008 · **File:** `tests/test_secrets.lua` (LF) · **Risk:** low

Extend the check at `:106` to the idiom the codebase actually uses: find
`local vX = <riskyAPI>(...)` bindings that are **not** wrapped in an `OutfitterAPI:`
call, and flag any later use of `vX` in a comparison, in arithmetic, in a
concatenation, or as a bare condition, within the same function. Simplest robust
form: require every call to a risky API to appear as a direct argument to
`OutfitterAPI:Unsecret` or `OutfitterAPI:UnsecretNumber`, with an explicit
exemption list for the sites that legitimately do not (currently: none outside
`Compat.lua` and `Deprecated.lua`).

Add a `-- red under:` comment naming the mutation — removing the
`OutfitterAPI:UnsecretNumber(...)` wrapper at `Outfitter.lua:1835`.

## C-11 · Route more APIs through `maybeSecret`

**Covers:** F-007 · **File:** `tests/wow_mock.lua` (LF) · **Risk:** low

Add `UnitStat`, `GetInventoryItemLink`, `C_Container.GetContainerItemLink` and
`C_UnitAuras.GetAuraDataByIndex` to the `maybeSecret` set. For the aura case, also
support a `M.state.secretAuraField` mode that returns a real table with a secret
`icon` or `spellId`, since that is the shape `GetPlayerAuraStates`
(`Outfitter.lua:4586-4590`) is written to survive. Add one case per new source.

## C-12 · Implement real bitwise ops in the mock

**Covers:** F-013 · **File:** `tests/wow_mock.lua` (LF) · **Risk:** none

Replace `:341` with a correct 32-bit `band`/`bor`/`bxor`. Lua 5.1 has no bitwise
operators, so implement arithmetically — a dozen lines. The three consumers
(`OutfitterEquipment.lua:494`, `:717`, `OutfitterQuickSlots.lua:20`) then become
testable; adding cases over them is a follow-up, not part of this change.

## C-13 · Settle the `Settings.Outfits` invariant in `CheckDatabase`

**Covers:** F-012 · **Files:** `Outfitter.lua` (**LF**) · **Risk:** low

Two parts:

1. Add `Outfits = {}` to the defaults in `Outfitter:InitializeSettings`
   (`Outfitter.lua:5426-5432`), so the field is guaranteed at its source rather than
   200 lines away at `:5217`. Then drop the now-plainly-redundant
   `if self.Settings.Outfits then` guards at `:6629`, `:6663`, `:6683`, leaving the
   function asserting one invariant instead of two.
2. Guard the two unguarded `pairs(vOutfit.Items)` loops at `:6664` and `:6685` to
   match the guarded one at `:6631`.

Also delete the duplicated repair block at `:6714-6716` (F-018) and the orphan
`local VOID_DEPOSIT_MAX = 8` at `:7019` (F-017).

**Risk note:** part 1 must be verified against an existing saved-variable file —
adding `Outfits = {}` to defaults is only safe because `:5217` already guarantees
the same thing; confirm it does not shadow a loaded table. `03_SMOKE_TESTS.md`
carries a fresh-install and an upgrade-from-existing-profile step.

## C-14 · Add a `CheckDatabase` migration test

**Covers:** F-012 (coverage) · **File:** `tests/test_outfits.lua` · **Risk:** none

Construct a synthetic `gOutfitter_Settings` at Version 19 with one outfit that has
no `Items` table, run `CheckDatabase`, assert it completes and the version lands at
22. This is the first test in the repo to exercise a saved-variable shape at all.

Pass count moves 120 → 121 (approximately; final count set at implementation).

## C-15 · Tighten `.pkgmeta` and add the converse packaging check

**Covers:** F-014 · **Files:** `.pkgmeta`, `tests/test_harness.lua` · **Risk:** none

Add to `.pkgmeta`'s ignore list, each with a comment in the file's existing style:

```yaml
    # Screenshots for the project listing and the README, not in-game textures --
    # the client cannot load a JPEG.
    - Documentation/Images

    # Upstream's 93 KB changelog.  README.md carries what a player needs.
    - Documentation/RevisionHistory.txt
    - CHANGES.txt
```

`Documentation/UsersManual.html` is left shipping — it is player-facing.

Then add the converse case to the `packaging` suite:

```lua
Kit.test("nothing shipped is unreferenced by the TOC, the XML or any Lua file", function()
	-- .pkgmeta is checked in one direction today: that three named entries are
	-- ignored.  Anything new that should be excluded ships unnoticed.
	...
end)
```

Pass count moves +1.

## C-16 · Correct the Deprecated.lua header and two test names

**Covers:** F-015 · **Files:** `Deprecated.lua` (**LF**), `tests/test_deprecated.lua` · **Risk:** none

Header (`Deprecated.lua:8-11`), third clause:

> Before: `nothing here touches the live Outfitter tables`
> After: `nothing live calls into it -- the preserved bodies still reach out to
> Outfitter, which is what makes them revivable, but nothing reaches in`

Rename `tests/test_deprecated.lua:46` to *"no top-level statement in the layer
writes to the live Outfitter table"* — what it checks — and `:131` to *"every file
with a deprecation stub is named in the header"*, likewise. Widening either to
match its current name is a larger change and is listed as a follow-up.

## C-17 · Drop the two orphan textures

**Covers:** F-020 · **Files:** `Textures/IconButtonHighlight.blp`,
`Textures/Outfitter-Button-original.blp` · **Risk:** none

Both have zero references. C-15's converse packaging check will keep the next pair
from accumulating.

## C-18 · Sync the README command table

**Covers:** F-021 · **Files:** `README.md`, `tests/test_commands.lua` · **Risk:** none

Add `summary`, `rating`, `iteminfo` and `itemstats` rows to `README.md:62-78`,
wording taken from `ShowCommandHelp` (`Outfitter.lua:2039-2042`). Extend
`test_commands.lua` to treat the README table as a third surface alongside dispatch
and in-game help, so all three agree.

Pass count moves +1.

## C-19 · Harness nits

**Covers:** F-022, F-023 · **Files:** `tests/run-all.sh`, `tests/run.lua`,
`tests/wow_mock.lua`, `Outfitter.lua` (**LF**) · **Risk:** none

- `tests/run-all.sh:30-31` — `mktemp` with a cleanup trap, replacing the fixed
  `/tmp/outfitter-nobom.lua`.
- `tests/run.lua:65` — drop `Ctx.xmlFrameCount`, or assert on it in `test_xml.lua`.
- `tests/run.lua:203` — derive `Ctx.luaFiles` from `git ls-files` rather than
  `find`, so untracked scratch files stop entering the discipline checks.
- `tests/wow_mock.lua:314-318` — make `strsplit` preserve empty fields, matching
  the client.
- `Outfitter.lua:7025` — change `"Void storage deposit"` to
  `"Outfitter:DepositOutfitToVoidStorage"`, matching `:7647`'s form, and update the
  matching header line in `Deprecated.lua`.

---

# Deliberately **not** proposed

Recorded so a future pass does not re-litigate them:

- **Splitting `Outfitter.lua` (8,699 lines).** The flat root and the single large
  file are upstream's and `CLAUDE.md` says so. lizard's 28 warnings are an
  observation in `01_FINDINGS.md`, not a restructuring demand.
- **Renaming anything toward another convention.** `pFoo`/`vFoo`/`cFoo` stay.
- **Adopting an external test kit.** The harness is deliberately bespoke.
- **Re-ending any file.** Every change above names the target file's ending.
- **Normalising `hooksecurefunc` in the mock to actually install hooks (F-022).**
  Correct in principle, but it would start running four previously-unexercised hook
  bodies (`Outfitter.lua:5183`, `:5380-5382`, `:7694`) inside the load, with
  unpredictable fallout. Follow-up, with its own milestone.
- **Making `Frame.__index` strict (F-006).** Discussed under Theme A. Large, and
  the permissiveness is load-bearing for the no-XML-engine design.
- **A `WithEquipmentUpdate(fn)` combinator (F-009).** Discussed under Theme D.
- **Anything about `GetQuestLink(vQuestIndex)` at `Outfitter.lua:7654`.** Flagged
  unverified in `01_FINDINGS.md` and carried into the smoke tests. No change until
  a client confirms which signature is live.

# Test-count movement

`docs/test-cases.md` does not exist in this repo (by design), so there is no
inventory file to move. The README carries no `[tests]` badge. The number that
matters is the one `tests/run.lua` prints and `CLAUDE.md`'s "0 failures" rule.

Current: **116 passed, 0 failed.** The changes above add roughly **seven** cases
(C-03 +1, C-05 +2, C-07 +1, C-11 +~2, C-14 +1, C-15 +1, C-18 +1, minus overlap) and
remove none. Final count to be recorded in `05_FINAL_SUMMARY.md` from the actual
run, not estimated.
