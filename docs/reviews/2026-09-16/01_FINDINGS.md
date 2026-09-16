# Outfitter — code review findings

**Date:** 2026-09-16 · **SHA:** `8ff8a26` · **Version:** 12.1.0.3 (`## Interface: 120007, 120100`)

**Verdict: minor issues.** Nothing blocks shipping. The addon loads clean, lints
clean, and the whole battery is green. But the green is worth less than it looks:
two of the suite's most load-bearing checks are proven here to be unfalsifiable,
and three always-true conditions in `Outfitter.lua` sit in code no test reaches.

## Scope note — the Ka0s standard is deliberately not applied

Per `CLAUDE.md`, Outfitter is a third-party fork and is **not governed by the Ka0s
WoW Addon Standard**. The standards cross-check was therefore **not performed and
not applicable** — this is a deliberate exclusion, not a fetch failure. No finding
below is a deviation from that standard, and no proposed change moves the addon
toward it. Upstream naming (`pFoo`/`vFoo`/`cFoo`), tabs, the flat root, the global
`Outfitter` table, the `Outfitter_*` / `OutfitterItemList_*` export surface and the
per-file line endings are all treated as fixed constraints.

Likewise: there is no `libs/LibKa0s/`, no `tests/_kit/`, no `tests/perf.lua`, no
`Makefile`, no `docs/test-cases.md`, no `docs/performance.md`, no
`docs/perf-analysis/` and no `docs/automated-tests/`. Those are **absent by
design**, not missing artifacts, and their absence is not a finding.

---

## Measurement run

Every suite below was run fresh from the repo root on 2026-09-16 against `8ff8a26`.
Scratch output lives outside the repo; nothing committed was modified or regenerated.

| Suite | Command | Result |
|---|---|---|
| Lint | `luacheck .` | **PASS** — 0 warnings / 0 errors in 42 files |
| Headless suite | `lua5.1 tests/run.lua` | **PASS** — 116 passed, 0 failed, 19 suites |
| Case inventory | `lua5.1 tests/run.lua --list` → scratch | **PASS** — 116 cases in 19 suites; no committed inventory to drift against |
| Full battery | `./tests/run-all.sh` | **PASS** — `luac -p` all files, luacheck clean, 116/0, `ALL SUITES PASSED` |
| Complexity | `lizard -l lua -x "./Libraries/*" -x "./tests/*" .` → scratch | **RAN (non-gating)** — 1007 functions, avg CCN 3.5, **28 warnings**; exit 1 is lizard's warnings-present exit, not a failure |
| Offline perf runner | — | **N/A** — no `tests/perf.lua` in this repo, by design |
| `make test` | — | **N/A** — no `Makefile` in this repo, by design |
| Vendor sync | — | **N/A** — nothing Ka0s-owned is vendored; `Libraries/` is upstream's own checked-in copy with no sibling source repo on disk. Nothing to diff. |
| Cross-addon pass | — | **N/A** — Outfitter is not part of the nine-addon collection and shares no vendored payload, no `LibKa0s` minor and no slash root with it. Its only token is `/outfitter`, which no Ka0s addon registers. |

**Artifact drift:** none to report. The repo commits no generated evidence files,
so there is no committed number that today's run can contradict.

**Lizard, in detail.** 28 functions exceed a default threshold. The largest is
`Outfitter:Initialize` (`Outfitter.lua:5140-5391` — 127 NLOC, CCN 17, 252 lines).
The highest CCN outside the vendored tree is `Outfitter._InventoryCache:ItemsAreSame`
(`OutfitterInventory.lua:1234-1308`, CCN 31), followed by `Outfitter:CheckDatabase`
(`Outfitter.lua:6619-6730`, CCN 27) and `Outfitter._ExtendedCompareTooltip`
(`Outfitter.lua:7738-7862`, CCN 26). These are cited below where they bear on a
finding; the raw report is otherwise an observation, not a demand.

**Mutation experiments.** Three findings below (F-001, F-002, F-005) were
established by temporarily mutating a file, re-running the suite and restoring the
file. Every mutation was reverted; `git diff --stat` was empty after each. The
exact mutations and observed outputs are quoted in the findings.

---

## Census scopes used

Two scopes appear below; each count states which one it used.

```sh
# A — tracked, authored Lua (the addon's own code)
git ls-files '*.lua' | grep -v '^Libraries/'
# 25,744 lines across 27 files. Largest: Outfitter.lua 8699, OutfitterScripting.lua 2187,
# OutfitterBar.lua 1681, OutfitterInventory.lua 1382, OutfitterEquipment.lua 1285.

# B — the TOC-derived load list (what the client actually loads)
tr -d '\r' < Outfitter.toc | grep -iE '\.lua$' | grep -v '^#' | sed 's|\\|/|g'
# 42 files. Excludes everything under tests/.
```

Scope A includes `tests/`; scope B does not. `Libraries/` is excluded from A because
it is upstream's vendored third-party code, read-only here for the same reason any
vendored tree is: a local patch is lost at the next re-vendor.

---

# High

### F-001 · The preset-event whitelist cannot fail, and the bug it misses raises in the client · `[tests]`

`tests/test_scripts.lua:114`

```lua
if not Outfitter.BuiltinEvents[ev] and not ev:match("^[A-Z_]+$") then
```

Every event name in `Outfitter.BuiltinEvents` and every raw Blizzard event is
uppercase-and-underscores, so the second clause swallows the first. The case named
*"every event a preset declares is one the addon dispatches"* accepts any
plausibly-named event whatsoever.

**Proven by mutation.** Appending `BOGUS_EVENT_XYZ` to the live STEALTH preset's
`$EVENTS` line (`OutfitterScripting.lua:160`) and re-running:

```
116 passed, 0 failed
```

**Impact is worse than a dead preset.** `Outfitter._ScriptContext:RegisterEvent`
(`OutfitterScripting.lua:2087-2100`) routes anything *not* in `BuiltinEvents` to
`Outfitter.EventLib:RegisterEvent(pEventID, ...)` — the real client registration.
`Outfitter.lua:466` states the consequence in the addon's own words:

> `-- Beginning in patch 8.0, WoW throws errors when registering for events which don't exist.`

So a typo'd event name in a preset is not silently inert; it throws in the game,
on the path that check exists to protect. This is the single check standing between
the repo and a repeat of the "four presets sat dead for years" failure that the
zone rebuild was undertaken to fix, and it is inert.

**Reachability:** Any player who enables an affected preset outfit — today none are
affected, so nobody is currently harmed. The finding is that the guard against the
next one does not work, and the failure it would let through is an in-client error
rather than a quiet no-op. Filed High on defect kind (a broken safety net over a
throwing path), not on present harm.

**Fix direction:** replace the regex escape hatch with an explicit allow-list of the
raw client events presets are permitted to listen for, checked as a set alongside
`BuiltinEvents`. Do not widen `BuiltinEvents` itself — it has a runtime meaning
(custom vs. client dispatch) that the test must not disturb.

---

### F-002 · A failure in `Outfitter:Initialize()` is invisible to the whole battery · `[tests]`

`tests/run.lua:66-69`

```lua
Ctx.initOK, Ctx.initError = pcall(function()
	Ctx.Outfitter:InitializeInstant()
	Ctx.Outfitter:Initialize()
end)
```

`Ctx.initOK` and `Ctx.initError` are set and **never read by any suite**:

```sh
$ grep -rn "initOK\|initError" tests/
tests/run.lua:66:Ctx.initOK, Ctx.initError = pcall(function()
```

**Proven by mutation.** Injecting `error("INJECTED late init failure")` immediately
after `Ctx.Outfitter:Initialize()`:

```
116 passed, 0 failed
```

An early failure is caught only *indirectly* — injecting the error before
`InitializeInstant()` produced `108 passed, 8 failed`, but every one of the eight
is a downstream symptom (`bad argument #1 to 'pairs' (table expected, got nil)`,
`SLASH_OUTFITTER1: expected "/outfitter", got nil`) and the actual error text is
discarded, so the diagnosis starts from eight unrelated failures rather than one
line naming the cause.

This matters disproportionately because `Outfitter:Initialize` is the largest
function in the addon — `Outfitter.lua:5140-5391`, 252 lines, CCN 17, lizard's
top warning — and it ends with `self:SchedulePlayerEnteringWorld()` at `:5390`.
Everything after whatever a suite happens to probe can raise unnoticed.

**Reachability:** Every maintainer, every run. The harness's stated contract in
`CLAUDE.md` — *"a file that stops loading is a test failure rather than a surprise
in someone's client"* — holds for file load (`tests/loader.lua:316` errors hard)
but not for initialisation, which is exactly where a client-visible startup failure
would live.

**Fix direction:** assert `Ctx.initOK` in `test_load.lua`, failing with
`Ctx.initError`, as the first case in the suite.

---

### F-003 · `UpdateZone` gates on the localized zone name the map-ID rebuild disowned · `[design]`

`Outfitter.lua:4855-4884`

```lua
function Outfitter:UpdateZone()
	local vCurrentZone = GetZoneText()
	local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID = GetInstanceInfo()

	-- Just return if the zone isn't changing
	if vCurrentZone == self.CurrentZone then
		return
	end
```

Every decision below this point is map-ID driven, and the comment on
`GetCurrentZoneIDs` (`Outfitter.lua:4891`) says so explicitly — *"Nothing here
matches on a zone name, which is what rotted the previous version."* But the gate
that decides whether any of it runs at all is still a localized string comparison,
and `self.CurrentZoneIDs` is only refreshed on the far side of it (`:4865`).

Where two instances share a zone name but differ in instance type or map ID, the
refresh is skipped and the zone outfit neither equips nor unequips. The candidates
in the shipped table are `[1191] Ashran` and `[2118] Battle for Wintergrasp`, both
of which share a name with an outdoor zone that is not a battleground.

Note also that the eight locals destructured from `GetInstanceInfo()` on the next
line are **entirely unread** in this function — leftovers from the pre-rebuild
version that survived because `.luacheckrc` ignores 211/231 by policy.

**Reachability:** Any player entering or leaving a battleground whose instance
shares a zone name with its surrounding world zone — Wintergrasp and Ashran are the
shipped candidates. Not confirmed in-client; the code-level defect (a name-based
gate in front of an ID-based decision) is certain regardless of which map
demonstrates it. `03_SMOKE_TESTS.md` carries the confirmation step.

**Fix direction:** gate on the pair the rest of the function actually uses — the
instance map ID and the instance type — rather than on `GetZoneText()`, and drop
the unread destructure.

---

### F-004 · `Outfitter:RemoveOutfit`'s fallback-outfit walk-back is dead code · `[bug]`

`Outfitter.lua:3452-3471`

```lua
	if pOutfit.CategoryID == "Complete"
	and #self.Settings.RecentCompleteOutfits then          -- :3453  always true
		local vOutfit
		while not vOutfit do
			local vOutfitName = self.Settings.RecentCompleteOutfits[#self.Settings.RecentCompleteOutfits]
			vOutfit = self:FindOutfitByName(vOutfitName)
			if vOutfit and vOutfit.CategoryID == "Complete" then
				self:WearOutfit(vOutfit)
				break
			end
			table.remove(self.Settings.RecentCompleteOutfits)
			if #self.Settings.RecentCompleteOutfits then   -- :3468  always true
				break
			end
		end
	end
```

Both conditions use `#t` as a truth test. `#t` is always a number and every number
including `0` is truthy in Lua, so **both are unconditionally true**. Two consequences:

1. `:3468` makes the `while not vOutfit` loop break after exactly one iteration.
   The loop's entire purpose — walk back through the recent-complete list until it
   finds one that still exists and is still Complete — never happens. Only the
   single most-recent entry is ever tried.
2. `:3453` lets the body run against an empty list, where
   `RecentCompleteOutfits[0]` is `nil`. No crash — `FindOutfitByName`
   (`Outfitter.lua:3712-3716`) rejects nil up front — but the guard is doing nothing.

The intended form is `> 0` in both places, and `:3468` additionally has the wrong
sense: it should break when the list *is* empty, i.e. `if #... == 0 then break end`.

**Reachability:** Any player on a default profile who removes a Complete outfit —
via the outfit list, a hotkey, or `/outfitter unwear` — where the most recent
complete outfit has since been renamed, deleted or recategorized. Outfitter then
silently wears nothing instead of falling back, on a documented core flow.

**Cited coverage gap:** `tests/test_outfits.lua` has 14 cases, all on the `Outfit`
object and the slot tables. `RemoveOutfit`, `WearOutfit` and the recent-complete
fallback have no case at all.

**Fix direction:** `#... > 0` at `:3453`; `#... == 0` at `:3468`.

---

# Medium

### F-005 · The mock accepts any event name; the client has rejected unknown ones since 8.0 · `[tests]`

`tests/wow_mock.lua:81`

```lua
function Frame:RegisterEvent(e) self.__events = self.__events or {}; self.__events[e] = true end
```

The addon's own comment at `Outfitter.lua:466` records that the client throws when
an addon registers an event that does not exist. The mock accepts any string, so
the harness is structurally incapable of catching F-001's failure class even if
F-001's regex were tightened. The two findings need fixing together or neither
holds.

**Reachability:** Every headless run. No player impact directly; it is the reason a
player-facing defect can reach a client green.

**Fix direction:** give the mock a known-events set (the union of `BuiltinEvents`'
client-side counterparts and a list of the raw events the addon and its presets
register) and `error()` on anything outside it, matching the client.

---

### F-006 · The mock's secret sentinel is more permissive than a real secret on the exact check `Compat.lua` documents · `[tests]`

`tests/wow_mock.lua:140` and `Compat.lua:85`

```lua
local SECRET = setmetatable({}, {__tostring = function() return "<secret>" end})
```

`Compat.lua:80-86` states the rule the whole seam exists to enforce:

> `-- Anything coming back from the game therefore has to be checked before it's`
> `-- used, and the check has to come before any other test (including a plain`
> `-- truthiness test) since that's an inspection too.`

The sentinel raises correctly on arithmetic, comparison and concatenation, because
those raise on any table. It does **not** raise on a truthiness test (`if
UnitHealth("player") then` succeeds and is taken) and does not raise on `tostring`
(the metamethod answers). Those are precisely the two inspections the comment
singles out. Code that violates the documented rule in those two ways passes the
suite and aborts the handler in a client.

**Reachability:** Every headless run; the player-facing consequence is an aborted
handler, which per `CLAUDE.md` is what strands `EquipmentUpdateCount` (see F-009).

**Fix direction:** make the sentinel a userdata-like proxy whose `__index`,
`__tostring`, `__len`, `__eq` and `__concat` all raise, and keep `issecretvalue`
answering `true` for it — the one operation that must stay safe.

---

### F-007 · Only five APIs can be made secret; item links and aura fields cannot · `[tests]`

`tests/wow_mock.lua:143-146, 185-190`

`maybeSecret` is wired into `UnitHealth`, `UnitHealthMax`, `UnitPower`,
`UnitPowerMax`, `UnitPowerType` and `UnitLevel` only. `UnitStat`
(`wow_mock.lua:191`) returns fixed numbers, and `GetInventoryItemLink`,
`C_Container.GetContainerItemLink` and `C_UnitAuras.GetAuraDataByIndex` cannot be
made secret at all — yet `CLAUDE.md` names item links and aura fields as secret
sources, and `Outfitter:GetPlayerStat` (`Outfitter.lua:6791-6802`) exists solely to
handle a secret `UnitStat`.

The consequence is that `Outfitter:GetPlayerAuraStates` (`Outfitter.lua:4557-4600`)
— the most carefully secret-aware function in the addon, with three separate
comments explaining its ordering — has **no test that ever hands it a secret**.

**Reachability:** Every headless run. The uncovered code is correct today; it is
uncovered against regression.

**Fix direction:** route `UnitStat`, `GetInventoryItemLink`,
`C_Container.GetContainerItemLink` and `C_UnitAuras.GetAuraDataByIndex` through
`maybeSecret`, including a mode that makes an aura *field* secret while the table
itself is not.

---

### F-008 · `test_secrets.lua`'s source-discipline check misses the idiom the codebase actually uses · `[tests]`

`tests/test_secrets.lua:106-137`

The case *"no live file compares a Unit API result directly"* matches only inline
forms — `UnitHealth(...) < x`, `x + UnitPower(...)` and similar. The idiom the
codebase overwhelmingly uses is bind-then-compare:

```lua
local vHealth = OutfitterAPI:UnsecretNumber(UnitHealth("player"))   -- Outfitter.lua:1835
...
if vHealth < (vHealthMax * 0.85) then                                -- Outfitter.lua:1842
```

Drop the `OutfitterAPI:UnsecretNumber(...)` wrapper and the check still passes: the
comparison is against a local, not against a call. The case reads as a standing
guarantee of secret discipline and enforces only its least-likely spelling. It is
green today because the code is correct, not because the check works.

**Reachability:** Every headless run. Filed Medium rather than High because the
shipped code is correct on every site — this is a guard that does not guard.

**Fix direction:** track locals bound from a risky API within a function's scope and
flag comparisons against those locals, or invert the check — require that every
call to a risky API appear as a direct argument to an `OutfitterAPI:` helper.

---

### F-009 · `BeginEquipmentUpdate`/`EndEquipmentUpdate` is a manual, non-exception-safe pair at 17 sites · `[design]`

`OutfitterEquipment.lua:802-822`, with 17 bracketed regions across `Outfitter.lua`
(14), `OutfitterScripting.lua` (3).

```lua
function Outfitter:BeginEquipmentUpdate()
	self.EquipmentUpdateCount = self.EquipmentUpdateCount + 1
end

function Outfitter:EndEquipmentUpdate(pCallerName, pUpdateNow)
	self.EquipmentUpdateCount = self.EquipmentUpdateCount - 1
	if self.EquipmentUpdateCount == 0 then
```

`CLAUDE.md` names the failure mode precisely: an error between the two leaves the
count above zero, and equipment updates then stop firing for the rest of the
session. The two known secret-value raisers were fixed at source and pinned by
`test_secrets.lua:79-102`; **the structure was not touched**, and every one of the
17 regions does real work in between.

Two structural gaps beyond the exception case:

- `EndEquipmentUpdate` decrements unconditionally with no floor at zero. An
  unmatched `End` drives the count negative, and the `== 0` test then never fires
  again for subsequent balanced pairs.
- Nothing reports a stuck count. The only recovery is `/reload`, and nothing tells
  the user — or a maintainer reading a bug report — that the count is the cause.

**Reachability:** Any player, on any session where a bracketed handler raises for
any reason. No current raiser is known; the class has already bitten once and the
recovery is invisible.

**Fix direction:** clamp at zero with a `DebugMessage` on an unmatched `End`, add
the count to `/outfitter zone`'s diagnostic output (or a sibling verb) so a stuck
count is reportable, and reset it in `PlayerEnteringWorld`. Do **not** wrap the 17
regions in `pcall` — swallowing errors trades a visible stuck state for an
invisible one.

---

### F-010 · `PlayerIsFull` falls back in opposite directions for health and power · `[bug]`

`Outfitter.lua:1830-1858`

The function's own header comment states the intent:

> `-- There's no way to tell how full the player is without`
> `-- them, so fall back on "not full" and leave the dining outfit alone`

Unreadable health takes that path (`:1838-1840`, `return false`). Unreadable power
does the opposite (`:1853-1855`, `return true`), reporting the player as full and
removing the dining outfit. `tests/test_secrets.lua:71` pins the health direction
only; there is no power equivalent.

**Reachability:** Any mana-using character in content where `UnitPower` is secret
and health is not — the dining outfit is removed mid-meal.

**Fix direction:** return `false` from the power branch to match the comment, and
add the mirrored test case.

---

### F-011 · A secret power reading poisons `PreviousManaLevel` · `[bug]`

`Outfitter.lua:1734, 1753`

```lua
local vPlayerMana = OutfitterAPI:UnsecretNumber(UnitPower("player"))
...
self.PreviousManaLevel = vPlayerMana     -- :1753, unconditional
```

When power is secret, `vPlayerMana` is `nil` and `PreviousManaLevel` is wiped. On
the next call with a real reading, `not self.PreviousManaLevel` at `:1736` is true,
so a first real sample is treated as a mana drop — which can cancel the Spirit
outfit (`:1745-1746`) with no drop having occurred.

**Reachability:** Any character with a Spirit-regen outfit in content where
`UnitPower` is intermittently secret.

**Fix direction:** only assign when `vPlayerMana` is non-nil, so the last known
reading survives a secret window.

---

### F-012 · `Outfitter:CheckDatabase` guards `Settings.Outfits` in five places and not the sixth · `[bug]`

`Outfitter.lua:6619-6730`, CCN 27 (lizard, today's run)

Four migration blocks open `if self.Settings.Outfits then` (`:6629`, `:6663`,
`:6683`). The final scan at `:6725` does not:

```lua
	for vCategoryID, vOutfits in pairs(self.Settings.Outfits) do
```

The guards are in fact the redundant half — `Outfitter.lua:5217-5219` runs
`if not self.Settings.Outfits then self:InitializeOutfits() end` before
`CheckDatabase` is called at `:5223`, so `Outfits` is always present. But the
function now asserts two contradictory invariants about the same field twelve lines
apart, which is exactly how the next editor picks the wrong one.

Separately, the `Version < 21` and `Version < 22` blocks iterate
`pairs(vOutfit.Items)` with no guard (`:6664`, `:6685`) where the `Version < 19`
block guards `if vOutfit.Items then` (`:6631`). An outfit with no `Items` table in
a pre-6.2 saved-variable file raises inside `Initialize` — which per F-002 the
harness cannot see, and which in a client means the addon does not come up.

`Outfitter:InitializeSettings` (`Outfitter.lua:5425-5433`) also does not create
`Outfits`, so the whole invariant rests on one line 200 lines away.

**Reachability:** The unguarded `Items` loops need a saved-variable file older than
WoW 6.2 (2015) — rare but not impossible for a fork whose users carry old profiles.
The invariant contradiction is reachable by the next maintainer, every edit.

**Cited coverage gap:** no test loads a saved-variable table at all; `CheckDatabase`
is entirely uncovered.

**Fix direction:** settle the invariant in one direction — either create `Outfits`
in `InitializeSettings` and drop all six guards, or guard all six. Guard the two
`vOutfit.Items` loops to match the third.

---

### F-013 · `bit.band` in the mock returns its first argument · `[tests]`

`tests/wow_mock.lua:341`

```lua
g.bit = { band = function(a) return a end, bor = function(a) return a end, bxor = function(a) return a end }
```

`band(x, mask)` returns `x` — no masking at all. Three live call sites depend on it:

- `OutfitterEquipment.lua:494` — specialty-bag routing, deciding `emptyThenEquip`
- `OutfitterEquipment.lua:717` — `FindEmptySpecialtyBagSlot`
- `OutfitterQuickSlots.lua:20` — the flyout filter that removes on-player items

Any test touching these exercises them against a masking function that does not
mask, so a wrong mask or a swapped argument order is invisible.

**Reachability:** Every headless run. None of the three sites is currently
covered by a case, so the present exposure is latent rather than active.

**Fix direction:** implement real 32-bit `band`/`bor`/`bxor` in the mock.

---

### F-014 · `.pkgmeta` ships 360 KB of maintainer documentation to every player · `[packaging]`

`.pkgmeta:10-25`

`Documentation/` is not in the ignore list and therefore ships. It holds
`RevisionHistory.txt` (93 KB of upstream changelog), `UsersManual.html` (19 KB) and
six JPEGs (~250 KB) that no WoW client can load as textures. `CHANGES.txt` (302
bytes) also ships. None is referenced by the TOC, the XML or any Lua file.

`UsersManual.html` is arguably player-facing and a defensible inclusion; the
JPEGs and the revision history are not — they are `README.md`'s illustrations and
the fork's own history.

The packaging suite (`tests/test_harness.lua:49-56`) asserts only that three named
entries *are* ignored. It never asserts the converse, so anything new that should
be excluded ships unnoticed. That asymmetry is the finding as much as the 360 KB is.

**Reachability:** Every player who downloads the addon. 360 KB is not a burden by
itself; the missing converse check is what compounds.

**Immediate instance of the same gap:** this review bundle creates `docs/`, which
`.pkgmeta` does not ignore either. Committing it as-is ships the review to every
player. `docs/` must go in the ignore list in the same change that commits this
bundle.

**Fix direction:** add `Documentation/Images`, `CHANGES.txt` and `docs/` to the ignore list
(keeping `UsersManual.html` if it is meant for players), and add a case asserting
that no shipped file is unreferenced by the TOC, the XML or any Lua source.

---

### F-015 · The Deprecated.lua header overstates the isolation, and the test that checks it is narrower than its name · `[docs]`

`Deprecated.lua:8-11` claims:

> `-- nothing here is called, nothing here is registered for an event, and nothing`
> `-- here touches the live Outfitter tables -- it all hangs off Outfitter.Deprecated.`

The first two clauses are true and I verified them — the only references to
`Deprecated.*` from live files are comments, and nothing in the file registers an
event. The third is not: preserved bodies open by reaching into the live table,
e.g. `Deprecated.VoidStorage.DepositOutfit` at `Deprecated.lua:74-75`:

```lua
	local self = Outfitter
	local vUnequipOutfit, vInventoryCache = self:GetDepositList(pOutfit, pUniqueItemsOnly)
```

That is correct and necessary — a body preserved verbatim must keep its original
calls to be revivable — but it means the isolation is one-directional (*nothing
calls in*), which is a weaker and more useful claim than the one written down.

Two tests are similarly narrower than their names:

- `tests/test_deprecated.lua:46` — *"the layer writes nothing to the live Outfitter
  table but its own two keys"* — matches only **column-zero** `^Outfitter%.X%s*=`
  and `^function Outfitter[:.]X`. An indented write inside any function body is
  invisible, and reads are not checked at all.
- `tests/test_deprecated.lua:131` — *"the header documents every entry point that
  calls into the layer"* — checks that the **file name** appears somewhere in the
  header, not that the feature does. A new stub in `Outfitter.lua` for an
  undocumented feature passes, because `Outfitter.lua` is already named eight times.

**Reachability:** A maintainer reading the header or trusting either test name.
No runtime effect.

**Fix direction:** reword the header's third clause to *"nothing live calls into
it"*; rename the two cases to what they check, or widen them to match their names.

---

### F-016 · `test_locale.lua`'s used-but-undefined check is filtered down to near-inert · `[tests]`

`tests/test_locale.lua:118-140`

The case *"every string the addon reads is defined in English"* only considers keys
whose name ends in `Outfit`, `Description`, `Title`, `Label`, `Error` or `Message`,
**and** passes anything for which `Outfitter[key] ~= nil` — true for every constant
the addon assigns at runtime. Between the two filters, most `Outfitter.cXxx` string
reads escape the check entirely.

`keysIn` (`:15-19`) also matches `Outfitter%.(c[%w_]+)%s*=`, which matches `==` as
well as `=`, so a comparison like `if Outfitter.cFoo == x` is counted as a
definition.

The rest of the locale suite is strong — the `KNOWN_ORPHANS` staleness check at
`:76` is a genuinely good falsifiable pattern and is credited with catching three
real orphans.

**Reachability:** Every headless run; a missing string shows as a `nil`
concatenation error for players on one locale.

**Fix direction:** drop the suffix filter, drop the `Outfitter[key] ~= nil`
escape, and anchor `keysIn` on `=` not followed by `=`.

---

# Low

### F-017 · Dead code invisible to lint by policy · `[dead-code]`

`.luacheckrc:495-524` ignores 211/212/213/231/311 with a written and entirely
reasonable rationale. The cost is that genuinely dead declarations do not surface.
Found by hand:

- `Outfitter.lua:4947-4949` — `Outfitter:InZoneType` has **zero callers** in any
  `.lua` or `.xml` file. `ShowZoneInfo` and `UpdateZone` both index
  `self.CurrentZoneIDs` directly instead. (It is a method on the global table, so
  a user script could in principle call it — but nothing ships that does.)
- `Outfitter.lua:7019` — `local VOID_DEPOSIT_MAX = 8`, orphaned when the void
  storage body moved to `Deprecated.VoidStorage.DEPOSIT_MAX`.
- `Outfitter.lua:4857` — all eight locals from `GetInstanceInfo()` unread (see F-003).
- `Outfitter.lua:4951-4954` — `InBattlegroundZone` destructures eight and reads one.

**Reachability:** A maintainer reading the file. No runtime effect.

---

### F-018 · Duplicated repair block in `CheckDatabase` · `[dead-code]`

`Outfitter.lua:6702-6704` and `Outfitter.lua:6714-6716` are byte-identical:

```lua
	if not self.Settings.RecentCompleteOutfits then
		self.Settings.RecentCompleteOutfits = {}
	end
```

The second can never fire. Harmless; a copy-paste slip twelve lines apart in the
function lizard already flags at CCN 27.

**Reachability:** A maintainer reading the file. No runtime effect.

---

### F-019 · `if vBoEItems and #vBoEItems then` overcounts the item list by one row · `[bug]`

`Outfitter.lua:3205`

```lua
		-- Add in the Warbound category
		if vWarboundItems and #vWarboundItems > 0 then      -- :3197  correct
			...
		-- Add in the BoEs category
		if vBoEItems and #vBoEItems then                    -- :3205  always true
			vTotalNumItems = vTotalNumItems + 1
```

The correct form sits eight lines above. With an empty BoE list the BoEs header row
is still counted, so `FauxScrollFrame_Update` at `:3212` is handed a
`vTotalNumItems` one larger than the list has content for, and the main window's
item list scrolls one row past its end.

**Reachability:** Any player with the Outfitter main window open and no
bind-on-equip items in the inventory cache — the common case — every session. Filed
Low rather than higher because the symptom is a one-row scroll overshoot, not lost
or wrong data.

**Fix direction:** `> 0`, matching `:3197`.

---

### F-020 · Two shipped textures with zero references · `[dead-code]`

`Textures/IconButtonHighlight.blp` and `Textures/Outfitter-Button-original.blp`
(6.6 KB each) are referenced by no `.lua`, `.xml` or `.toc` file. Measured over
scope A plus the two XML files and the TOC; every other BLP in `Textures/` has at
least one reference.

**Reachability:** Nobody. 13 KB in every download.

---

### F-021 · README documents 17 commands; the in-game help documents 21 · `[ux]`

`README.md:62-78` lists the slash commands as a table. `Outfitter:ShowCommandHelp`
(`Outfitter.lua:2019-2045`) additionally documents `summary`, `rating`, `iteminfo`
and `itemstats`, none of which appear in the README.

`tests/test_commands.lua:36-59` checks dispatch ↔ in-game help in both directions
and is a genuinely good pair of cases — but it never reads `README.md`, so this
third surface drifts unchecked.

**Reachability:** Any user reading the README rather than typing `/outfitter help`.
Four working commands are undiscoverable to them.

**Fix direction:** add the four to the README table and extend
`test_commands.lua` to treat the README as a third surface.

---

### F-022 · Harness nits · `[tests]`

- `tests/run-all.sh:30-31` writes the BOM-stripped copy to a fixed
  `/tmp/outfitter-nobom.lua`. Two concurrent runs, or two users on a shared
  machine, collide. Use `mktemp` and trap the cleanup.
- `tests/run.lua:65` sets `Ctx.xmlFrameCount`; nothing reads it. `test_xml.lua`
  re-derives what it needs. Either assert on it or drop it.
- `tests/wow_mock.lua:296-299` — `hooksecurefunc` is a no-op, so the four live
  hooks (`Outfitter.lua:5183`, `:5380`, `:5381`, `:5382`, `:7694`) are never
  installed in any test and their bodies are wholly unexercised.
- `tests/wow_mock.lua:314-318` — `strsplit` drops empty fields; the client's
  preserves them. The three consumers (`OutfitterScripting.lua:1404`, `:1473`,
  `:1521`) split GUIDs, which do not contain empty fields, so no live path is
  currently wrong — but the divergence is a trap for the next consumer.
- `tests/run.lua:203` shells out via `io.popen("cd '" .. root .. "' && find ...")`.
  A repo path containing a single quote breaks it, and untracked scratch `.lua`
  files in the tree are swept into the discipline checks. `git ls-files` would be
  both safer and reproducible.

**Reachability:** Maintainers only.

---

### F-023 · Inconsistent `DeprecatedFeature` labels · `[naming]`

`Outfitter.lua:7025` passes `"Void storage deposit"` — a feature description.
`Outfitter.lua:7647` passes `"Outfitter:CallCompanionByName"` — a method name. The
debug line at `Deprecated.lua:60` formats them into the same sentence, so the two
read differently for no reason.

**Reachability:** A maintainer with debug output enabled.

---

## Non-findings worth recording

Things I checked that came back clean, so the next reviewer does not re-derive them:

- **Deprecation isolation, call direction.** Verified: every reference to
  `Deprecated.*` outside `Deprecated.lua` is a comment. Nothing live calls in, and
  nothing in the file registers an event. The layer really is deletable in one step.
- **Secret-value discipline at the source sites.** All ten live `Unit*` call sites
  route through `OutfitterAPI`. `Outfitter:GetPlayerStat`
  (`Outfitter.lua:6791-6802`) handles a secret `UnitStat` correctly, and
  `GetPlayerAuraStates` (`:4557-4600`) gets the ordering right — `IsSecret(vAura)`
  before the nil test, and a secret aura continues the scan rather than ending it.
- **Zone table consistency.** All five tables agree; `tests/test_zones.lua:15-78`
  checks four of the five pairings and the sixth case pins the map-table shape.
  The five-table invariant is genuinely well guarded — it is only the live
  `UpdateZone` path that escapes (F-003).
- **Deprecated-API sweep** over scope B: no `UnitAura`/`UnitBuff`/`UnitDebuff`,
  no bare `GetContainerItem*` outside `Compat.lua`'s guarded fallbacks, no
  `InterfaceOptions_AddCategory`, no `IsAddOnLoaded`/`LoadAddOn`. `SetBackdrop` at
  `OutfitterBar.lua:922` and `:1386` — the `:1386` frame is created with
  `"BackdropTemplate"` at `:1369` and `OutfitterBar.xml:4` inherits it; `:922`
  should be confirmed in-client (`03_SMOKE_TESTS.md` carries the step).
- `GetQuestLink(vQuestIndex)` at `Outfitter.lua:7654` takes a **quest log index**.
  Modern retail's `GetQuestLink` takes a questID. I could not resolve this from the
  source alone — it is flagged as **unverified** and carried into the smoke tests
  rather than filed as a finding.
- **Line endings**: `tests/test_eol.lua` pins all 24 root files individually and
  asserts the pin list is exhaustive. This is the best-designed suite in the repo
  and needs nothing.
