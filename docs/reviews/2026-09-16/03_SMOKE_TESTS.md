# Outfitter — manual smoke tests

**Date:** 2026-09-16 · Derived from `02_PROPOSED_CHANGES.md`

Everything that runs in a shell already ran in Step 0 and is recorded in
`01_FINDINGS.md`'s measurement block. **This document is only for what needs a
logged-in client.** Do not restate the headless suites here.

---

## Pre-flight

1. **Headless gate, once, before installing anything.** From the repo root:

   ```sh
   ./tests/run-all.sh
   ```

   Must print `ALL SUITES PASSED` with 0 luacheck warnings and 0 test failures.
   `CLAUDE.md`'s rule applies: any non-zero number is something these changes
   introduced. Do not proceed to the client until this is green.

2. **Install.** Copy the repo to `World of Warcraft/_retail_/Interface/AddOns/Outfitter`,
   or symlink it. The TOC declares `## Interface: 120007, 120100` — this is a
   **retail-only** addon; nothing below applies to Classic.

3. **Make failures visible.**

   ```
   /console scriptErrors 1
   /reload
   ```

   Optionally `/etrace` for the zone tests (T-04), filtered to `ZONE_CHANGED`,
   `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED_INDOORS` and `PLAYER_ENTERING_WORLD`.

4. **Enable Outfitter's own debug output** before T-06 and T-08 — several of the
   new diagnostics go through `DebugMessage`, which is quiet by default. Use
   `/outfitter errors on` and check `Outfitter.Debug.EquipmentChanges` is set if
   the build exposes it; otherwise those two tests observe behaviour only.

5. **Two profiles.** Several tests need a *fresh* saved-variable state and several
   need an *existing* one. Before starting, take a copy of
   `WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/Outfitter.lua` so you
   can restore it. T-09 deliberately deletes it.

6. **Characters needed.** One max-level character with at least three Complete
   outfits saved and a populated recent-complete history. A mana user (any healer
   or caster) for T-07. Access to Wintergrasp or Ashran for T-04 — see that test
   for the alternatives if neither is reachable.

---

## T-01 · C-04 — `UpdateZone` gates on the instance, not the zone name

**Change covered:** C-04 — the zone gate stops comparing localized zone names.

**Setup:** A character with a zone outfit configured for `Battleground`. Stand in
the **outdoor** Wintergrasp zone in Northrend (or outdoor Ashran in Draenor). Note
which outfit you are wearing.

**Steps:**

1. `/outfitter zone` — record the reported instance name, type and map ID.
   Expect type `none` and *"No zone outfits apply here"*.
2. Queue for and enter **Battle for Wintergrasp** (map ID 2118). Wait for the
   loading screen to finish and for combat lockdown to clear.
3. `/outfitter zone` again.
4. Leave the battleground back to the outdoor zone.
5. `/outfitter zone` a third time.

**Expected:**

- Step 3 reports instance type `pvp`, map ID `2118`, and *"Zone outfits active:
  Battleground, Wintergrasp"*. Your Battleground outfit is on.
- Step 5 reports type `none` and *"No zone outfits apply here"*. The Battleground
  outfit has come off.
- No red `Interface action failed` text and no Lua error popup at any step.

**Pass / fail:** PASS if the zone outfit both equips on entry and unequips on exit.
FAIL if either transition is missed — that is the pre-C-04 behaviour surviving.

**If neither Wintergrasp nor Ashran is reachable:** substitute any two instances
whose `/outfitter zone` map IDs differ while `GetZoneText()` agrees. Record which
pair you used; if you cannot find one, mark this test **not run** rather than
passed — C-04's benefit is unconfirmed without it.

---

## T-02 · C-04 — ordinary zone changes still work

**Change covered:** C-04 — regression check on the wider gate.

**Setup:** Any character, out in the world.

**Steps:**

1. Walk across a zone boundary (e.g. Elwynn Forest → Westfall).
2. Enter and leave a building (fires `ZONE_CHANGED_INDOORS`).
3. Take a flight path across three or more zones.
4. `/outfitter zone` after each.

**Expected:** No Lua errors, no equipment churn, no repeated chat spam. Outfitter
should not swap anything on an ordinary outdoor zone change.

**Pass / fail:** PASS if no errors and no unexpected outfit change. FAIL on any
error, or if an outfit equips/unequips where none should.

---

## T-03 · C-06 — the recent-complete fallback walks back

**Change covered:** C-06 — `#t` → `#t > 0` / `== 0` at `Outfitter.lua:3453`, `:3468`.

**Setup:** Fresh SavedVariables is *not* wanted here. You need three Complete
outfits — call them **A**, **B**, **C** — and a recent-complete history containing
all three. Build it by wearing A, then B, then C in sequence.

**Steps:**

1. Confirm the history: wear A, wear B, wear C.
2. **Delete outfit B** from the outfit list.
3. While wearing **C**, remove it — `/outfitter unwear C`.

**Expected:** Outfitter falls back to a Complete outfit. With B deleted, the
walk-back skips it and lands on **A**. Before C-06 it would try B, fail, and stop —
leaving you wearing nothing.

**Pass / fail:** PASS if you end up wearing **A**. FAIL if you end up wearing
nothing, or if a Lua error appears.

**Also check:** repeat with an *empty* recent-complete history (a fresh character,
or `/outfitter reset`). Removing a Complete outfit must not raise.

---

## T-04 · C-06 — the item list no longer scrolls past its end

**Change covered:** C-06 — `Outfitter.lua:3205`.

**Setup:** A character with **no** bind-on-equip items in bags or bank. If you have
some, mail them away for the duration, or use a bank alt.

**Steps:**

1. Open the Outfitter main window.
2. Select an outfit and scroll the item list to the very bottom.

**Expected:** The last visible row is a real item or category header. There is no
blank row, and no phantom "BoEs" header, below the last entry.

**Pass / fail:** PASS if the list bottoms out on content. FAIL if one empty row
scrolls into view past the last item.

**Then confirm the positive case:** acquire or mail in one BoE item, reopen the
window, and confirm the BoEs category header *does* appear and expands correctly.
A fix that overcorrects — hiding the header when there *are* BoEs — is worse than
the bug.

---

## T-05 · C-13 — saved-variable migration, both directions

**Change covered:** C-13 — `Outfits` in the defaults, guards settled,
`vOutfit.Items` loops guarded.

This is the highest-risk change in the set. Run **both** halves.

**Setup A — existing profile.** Restore your pre-flight backup of
`SavedVariables/Outfitter.lua`. Do **not** delete it.

**Steps A:**

1. Log in.
2. `/reload`.
3. Open the Outfitter main window.
4. Check each saved outfit still lists its items.
5. Wear one, then remove it.

**Expected A:** Every outfit that existed before still exists, with the same items,
the same category and the same name. No Lua error at login or on `/reload`. Outfit
bar, minimap button and quick slots all still present.

**Setup B — fresh install.** Log out, delete
`WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/Outfitter.lua`, log in.

**Steps B:**

1. Observe the login with no saved variables at all.
2. Open the Outfitter main window.
3. Create a new outfit, put one item in it, wear it.
4. `/reload` and confirm it survived.

**Expected B:** No Lua error at any point. The window opens to an empty but
functional outfit list. The new outfit persists across the reload.

**Pass / fail:** PASS only if **both** A and B are clean. A failure in B with A
passing means `Outfits = {}` in the defaults is shadowing something; a failure in A
with B passing means the guard removal was premature. Either way, revert C-13 and
re-open the finding.

---

## T-06 · C-08 — a stranded `EquipmentUpdateCount` is now visible and recovers

**Change covered:** C-08 — clamp at zero, diagnostic, reset on entering the world.

**Setup:** Any character. Debug output enabled per pre-flight step 4.

**Steps:**

1. Provoke an unmatched `End` directly, from a macro or the chat frame:

   ```
   /run Outfitter:EndEquipmentUpdate("smoke test")
   ```

2. Watch for the debug line.
3. `/run print(Outfitter.EquipmentUpdateCount)`
4. Now wear an outfit and remove it — confirm equipment changes still work.
5. Take a portal or hearth (fires `PLAYER_ENTERING_WORLD`), then
   `/run print(Outfitter.EquipmentUpdateCount)` again.

**Expected:**

- Step 2 prints *"EndEquipmentUpdate without a matching Begin (smoke test)"*.
- Step 3 prints `0` — **not** `-1`. Before C-08 it would print `-1`, and step 4
  would silently do nothing.
- Step 4 works normally.
- Step 5 prints `0` and produces no extra warning (nothing was stranded).

**Pass / fail:** PASS if the count never goes negative and equipment changes keep
working after the unmatched `End`. FAIL on `-1`, or if the outfit in step 4 does
not equip.

**Second half — the stranded case:**

```
/run Outfitter:BeginEquipmentUpdate()
```

then hearth. On arrival, `/run print(Outfitter.EquipmentUpdateCount)` must print
`0` and the debug output must carry *"EquipmentUpdateCount was 1 entering the
world; resetting"*.

---

## T-07 · C-06 supporting / F-010, F-011 context — dining and spirit outfits

**Change covered:** none directly; this is the regression surface the secret-value
work sits on, and it cannot be exercised headless.

**Setup:** A mana-using character with a Dining outfit and a Spirit outfit
configured and enabled.

**Steps:**

1. Sit down and eat/drink to full. Confirm the Dining outfit equips and comes off
   at full.
2. Spend mana to below 85%, confirm the Spirit outfit behaves as configured.
3. Enter a dungeon or raid where health and power read as secret values (any
   current-season instanced content), and repeat 1 and 2.

**Expected:** No Lua error, and specifically no *"attempt to compare"* or
*"attempt to perform arithmetic"* error. In step 3, the safe direction is that the
Dining outfit stays off rather than flapping.

**Pass / fail:** PASS if no error in any of the three. FAIL on any error — that is
the exact class that strands `EquipmentUpdateCount` and would then be visible via
T-06's step 3.

---

## T-08 · C-01 / C-02 — preset event registration (the class the tests now cover)

**Change covered:** C-01, C-02 — indirectly. The client half of the event-name check.

**Setup:** A character with several preset-script outfits enabled — at minimum one
PvP zone preset, one form/stealth preset appropriate to the class, and one
`TIMER`-driven preset.

**Steps:**

1. `/reload` with those outfits enabled.
2. Watch the chat frame and the error frame during login.
3. Open the script editor on one preset and confirm its `$EVENTS` line is intact.
4. Trigger each preset's condition at least once.

**Expected:** No *"Attempted to register unknown event"* error, and no
*"Couldn't activate script"* message. Each preset fires when its condition is met.

**Pass / fail:** PASS if the login is clean and every preset fires once. FAIL on
any event-registration error — which would mean C-01's allow-list is missing a
real event, not that the addon is broken.

---

## T-09 · C-15 / C-17 — packaged contents

**Change covered:** C-15 (`.pkgmeta` tightened), C-17 (two textures removed).

**Setup:** Build a package the way the CurseForge packager would, or inspect the
generated zip from a test build.

**Steps:**

1. Confirm the zip contains **no** `Media/`, **no** `tests/`, **no** `.luacheckrc`,
   **no** `CLAUDE.md`, **no** `Documentation/Images/`, **no**
   `Documentation/RevisionHistory.txt`, **no** `CHANGES.txt`.
2. Confirm it **does** contain `Outfitter.toc`, all 42 TOC-listed Lua files, both
   XML files, `Bindings.xml`, `Textures/`, `Libraries/`, `LICENSE`, `README.md` and
   `Documentation/UsersManual.html`.
3. Install **only** the packaged zip into a clean AddOns folder — not the repo.
4. Log in and open every Outfitter window: main, options, about, outfit bar, quick
   slots, the script editor, the icon chooser.

**Expected:** Every window renders with its artwork. No green/black missing-texture
squares anywhere — this is what confirms C-17 removed two genuinely unreferenced
BLPs rather than two that something reaches for by string.

**Pass / fail:** PASS if every window renders correctly from the packaged build.
FAIL on any missing texture.

---

## T-10 · `SetBackdrop` at `OutfitterBar.lua:922` — unresolved from source

**Change covered:** none. This resolves an item `01_FINDINGS.md` marked unverified.

**Steps:**

1. Open the outfit bar's icon chooser (`OutfitterChooseIconDialog`).
2. Look for a *"SetBackdrop is not a function"* error or a dialog with no border.

**Expected:** The dialog draws with a border and a tiled background.

**Pass / fail:** PASS if it renders. FAIL means the frame at `:922` needs
`BackdropTemplate` added the way `:1369` already does — a new finding, not a
regression from this cycle.

---

## T-11 · `GetQuestLink` signature — unresolved from source

**Change covered:** none. Resolves the second unverified item.

**Setup:** A character with several quests in the log, including at least one
whose quest ID you know.

**Steps:**

1. Create or enable an outfit using a preset that checks quest state, or call
   `/run print(Outfitter:PlayerIsOnQuestID(<a questID you are on>))` directly.

**Expected:** `true` for a quest you are on, `false` for one you are not.

**Pass / fail:** PASS if both answers are correct. FAIL — specifically, `false` for
a quest you *are* on — means `GetQuestLink(vQuestIndex)` at `Outfitter.lua:7654` is
being passed a log index where retail now wants a quest ID, and a new finding
should be opened against `Outfitter:PlayerIsOnQuestID`.

---

## Regression suite

Not tied to any one change; these cover what the changes could plausibly break.

| # | Check | Expected |
|---|---|---|
| R-01 | `/reload` from a standing start | No error, window state preserved |
| R-02 | Cold login, existing profile | No error; every outfit intact (see T-05A) |
| R-03 | Cold login, no SavedVariables | No error; empty but functional (see T-05B) |
| R-04 | `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | No error at any stage; check with `/etrace` |
| R-05 | Enter combat with all Outfitter windows open, leave combat | No `Interface action failed because of an AddOn`; windows survive |
| R-06 | Character sheet slot checkboxes | `OutfitterSlotEnables` is visible above the paper doll — `CLAUDE.md` notes this strata is raised in `SelectOutfit`, not `OnLoad` |
| R-07 | Outfit bar drag, then `/reload` | Position persists |
| R-08 | `/outfitter reset bar` | Bar returns to default position |
| R-09 | Every option on the Options panel toggled once | Each takes effect; no error |
| R-10 | Minimap button: drag, hide, show | All three work |
| R-11 | Quick slots flyout on a character-sheet slot | Opens, filters on-player items out (exercises `bit.band` at `OutfitterQuickSlots.lua:20`) |
| R-12 | Equip a specialty bag (herb/enchanting), then wear an outfit that swaps into it | Correct bag routing (exercises `bit.band` at `OutfitterEquipment.lua:494`, `:717`) |
| R-13 | Every `/outfitter` verb typed once | Each responds; none raises. Verbs: `wear unwear toggle reset update updatetitle deposit depositunique depositothers withdraw withdrawothers summary rating iteminfo itemstats missing zone sound disable enable errors help` |
| R-14 | `/outfitter help` vs `README.md` | The four commands C-18 added to the README appear in both |
| R-15 | Addon compartment entry | `Outfitter_OnAddonCompartmentClick` opens the window |
| R-16 | Key bindings (`Bindings.xml`) | Each bound action works |

**R-12 note:** this and R-11 are the only in-client exercise the three `bit.band`
sites get. C-12 makes them testable headless but adds no cases; until it does,
these two rows are the whole coverage.

---

## Localization sanity

Run only if any change touched user-facing strings. C-18 touches `README.md` only,
not a locale file, so this section is **not required this cycle**. If a later pass
touches `OutfitterStrings*.lua`: switch the client to deDE, re-run T-03, T-04 and
R-13, and confirm no string renders as `nil` or as its key.

**Note the mixed line endings.** Every `OutfitterStrings*.lua` is CRLF. Check
before editing.

---

## Performance spot-checks

No perf-tagged findings were raised and there is no perf harness in this repo, so
there is no capture protocol to run. If a later pass needs a number:

```
/run collectgarbage("collect"); local a = collectgarbage("count")
   <perform the flow>
/run print(collectgarbage("count") - a)
```

before and after the flow in question. For anything touching `OnUpdate`, use the
Blizzard profiler — `/console scriptProfile 1` → `/reload` →
`/run UpdateAddOnCPUUsage()` — and read it as an order of magnitude only: the
profiler attributes shared frame time in ways that make the absolute number
unreliable as "Outfitter's cost".

---

## Sign-off

| ID | Change | Tested? | Pass/Fail | Notes |
|---|---|---|---|---|
| T-01 | C-04 zone gate, Wintergrasp/Ashran | | | |
| T-02 | C-04 ordinary zone changes | | | |
| T-03 | C-06 recent-complete walk-back | | | |
| T-04 | C-06 item list scroll extent | | | |
| T-05A | C-13 migration, existing profile | | | |
| T-05B | C-13 migration, fresh install | | | |
| T-06 | C-08 EquipmentUpdateCount clamp | | | |
| T-07 | Dining / Spirit under secret values | | | |
| T-08 | C-01/C-02 preset event registration | | | |
| T-09 | C-15/C-17 packaged contents | | | |
| T-10 | `SetBackdrop` at OutfitterBar.lua:922 | | | |
| T-11 | `GetQuestLink` signature | | | |
| R-01…R-16 | Regression suite | | | |
