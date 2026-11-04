# In-client smoke tests — P8 review changes

These are the checks only the game client can make, run after the changes in
`02_PROPOSED_CHANGES.md` land. The headless suites already ran in this review's Step 0b
(`01_FINDINGS.md`, *Measurement run*) and are not repeated here.

## Pre-flight

1. Headless gate on the changed tree: `lua tests/run.lua` (green, with the new case count in
   `docs/test-cases.md` and the README badge) and `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
   (0/0).
2. Retail client, `## Interface: 120105` (Midnight 12.1.5). Install the addon folder as
   `Interface/AddOns/OutfitterReborn`. Do **not** load the legacy `Outfitter` alongside it, except in
   R-6.
3. `/console scriptErrors 1`, and BugSack (or the default error frame) visible. Run `/etrace` only
   where a step says so.
4. Characters needed: any class for most steps. A **druid** for S-02b. An **frFR** and a **koKR**
   client (or a locale switch through the launcher's `-locale`) for S-04.
5. Before each section, `/of debug on` so that the console records the `Trigger`, `Equip` and `Perf`
   lines.

## S-01 — C-01: an idle window no longer redraws (F-001)

- **Change covered:** C-01, conditional `STACK_CHANGED` plus a status-preserving redraw.
- **Setup:** a character with at least 10 outfits, in a city, out of combat, not moving.
- **Steps:**
  1. Open the character sheet and the outfit window (the sheet button, or `/of show`).
  2. `/of perf start`, then leave the client idle for 60 s with the window open, then `/of perf stop`.
     Follow the two-arm protocol from `/of perf help`: clean arm first, suspended arm second, no
     `/reload` between the arms.
  3. Read the `dockFollow` bucket's call count and total ms from the report.
  4. Mount and dismount once, and equip one ring by hand.
- **Expected:** at step 3, `dockFollow`'s total is the follow tick alone. There is no per-0.5 s render
  spike, and its total sits well below the pre-change capture, if one was taken. At step 4 the worn
  checkbox and the ring row update within one follow tick.
- **Pass/Fail:** pass when the idle arm's `dockFollow` shows no 2 Hz render cost **and** step 4's
  changes still draw. Record the capture as a frozen `docs/perf-analysis/<YYYYMMDD-HHMMSS>/` bundle
  through `/dev-copilot:wow-perf-analysis`.

## S-02 — C-02: no trigger acts before the world is loaded (F-002)

- **Change covered:** C-02, the binder waits for the first LoadPass.
- **Setup:** an outfit with the **Resting** trigger (`/of` window → the outfit's menu → trigger
  Resting). Log out inside an inn.
- **Steps:**
  1. Log back in on the same character, still in the inn.
  2. Watch chat and the debug console from the loading screen until 3 s after the world appears.
- **Expected:** the first `Trigger RESTING on <id>: equip` console line comes **after** the world has
  loaded (at least 1 s after `PLAYER_ENTERING_WORLD`), never during the loading screen. The outfit
  ends up worn. There is no "Can't find item" line and no Lua error.
- **Pass/Fail:** pass when the outfit is worn after login, with no trigger line stamped before the
  LoadPass and no error.
- **S-02b (druid):** log out in Cat Form with a Cat Form outfit. Log in. Expected: the Cat outfit is
  worn once, after the world loads, and nothing flips off and back on.

## S-03 — C-03: a player-only cast filter (F-003)

- **Change covered:** C-03, the binder's player unit-filter frame.
- **Setup:** an outfit with the **Spellcast** trigger listing one spell you can cast (for example a
  profession spell or Hearthstone's spell id), and `/of debug on`.
- **Steps:**
  1. Stand beside a training dummy area or a busy city crowd, where other players are casting.
  2. Cast a different spell, then the listed one.
  3. `/etrace`, and filter for `UNIT_SPELLCAST_START` for 10 s.
- **Expected:** the outfit is worn on your listed spell only. The debug console shows no `Trigger
  SPELLCAST` line caused by another player's cast. `/etrace` shows the event arriving, which is
  normal, because the filter happens before Lua and is invisible there.
- **Pass/Fail:** pass when the wear and unwear behave as before and no dispatch follows other units'
  casts.
- **S-03b (vehicle):** if a character can reach the Argent Tournament grounds, mount a tournament
  steed. Expected: the outfit is worn on mount and removed on dismount.

## S-04 — C-04: locale duration patterns (F-004). Capture first, then verify

- **Change covered:** C-04, the frFR and koKR use-duration patterns.
- **Setup:** an frFR client, then a koKR client, each with an on-use trinket whose tooltip shows a
  duration (for example "for 20 sec").
- **Steps:**
  1. **Capture (before C-04 is written).** Hover the trinket and run
     `/run for _,l in ipairs(C_TooltipInfo.GetInventoryItem("player",13).lines) do print(("%q"):format(l.leftText or "")) end`.
     Copy the `Use:` line verbatim, NBSP and all, into the C-04 fixture.
  2. **Verify (after C-04).** Put the trinket in a Trinket Queue outfit, use it, and while its effect
     runs, trigger a queue swap (wait for the queue's tick).
- **Expected:** the active trinket is **not** swapped out until its effect ends.
- **Pass/Fail:** pass on both locales. If a locale's line does not match the new pattern, the fixture
  is wrong. Re-capture it; never hand-type it.

## S-05 — C-05, C-06, C-07: the perf wiring is still sound

- **Change covered:** C-05 and C-06 (headless only: covered by the pre-flight run of
  `ka0s-bounded lua tests/perf.lua`, nothing to do in the client) and C-07.
- **Steps:** one full `/of perf` two-arm capture, at least 60 s per arm, with the window open and one
  zone change.
- **Expected:** every declared bucket that the session reached reports figures. No bucket appears
  outside the report's order. The suspended arm stands the addon down and resume brings it back
  (window, bar, bindings).
- **Pass/Fail:** pass when the report is well-formed and the stand-up restores everything.

## S-06 — C-08, C-09, C-10: login, delete and re-create

- **Steps:**
  1. `/reload`. The addon comes up with no Lua error, the window opens, and the bar shows.
  2. Create five throw-away outfits, give each a trigger, delete all five, and repeat three times.
  3. `/of disable`, then `/of enable`.
- **Expected:** no error at any step. After step 3 every trigger still works (wear one by its
  condition).
- **Pass/Fail:** pass when all three steps are clean.

## Regression suite

- **R-1** `/reload` cleanly. ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD with no errors.
- **R-2** First-time defaults: on a new character, the built-in outfits are seeded (Normal, Birthday
  Suit, one per spec, and the class outfits).
- **R-3** Combat edge with the window open: it hides at combat start and returns at combat end with
  its dialogs still open. No `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` (O11).
- **R-4** The Show window key binding works from combat. The window opens when combat ends, with
  one chat line (O8).
- **R-5** Profile switch on the Profiles page. Outfits are unchanged (`db.char`). Settings follow the
  profile.
- **R-6** Legacy coexistence: load the original Outfitter too. Exactly one warning line appears.
  `/of` reaches this addon.
- **R-7** Settings panel: open General, Outfit Bar and Profiles, and toggle every option once. No
  error.
- **R-8** Cross-addon: with the other roster addons loaded, type each roster addon's root and confirm
  it reaches its own addon. Type `/of` and `/outfitter` and confirm they reach this one. Open
  Settings → AddOns and confirm each addon appears exactly once, and each multi-page addon's pages
  appear once each.

## Taint-specific tests

Run R-3 and R-4 above, plus:

- **T-1** Disenchant (or any item-targeting spell) cast on an item row of the outfit window, out of
  combat. The spell lands on the item through the row's secure child, with no blocked-action text.
- **T-2** Escape with the window open out of combat closes it through `UISpecialFrames`. Enter
  combat, then press Escape. Nothing is blocked, because the window is already hidden.

## Localization sanity

S-04 covers the changed strings. Also open the outfit window and the trigger dialog on frFR. Labels
render with no box glyphs and no `%s` placeholders showing.

## Performance spot-checks

S-01 is the capture (the bucket figures, not the frame-time delta, per `performance-§8`). Commit it
as a frozen bundle under `docs/perf-analysis/`.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 (S-01) | | | |
| C-02 (S-02, S-02b) | | | |
| C-03 (S-03, S-03b) | | | |
| C-04 (S-04 frFR) | | | |
| C-04 (S-04 koKR) | | | |
| C-05 / C-06 (headless pre-flight) | | | |
| C-07 (S-05) | | | |
| C-08 / C-09 / C-10 (S-06) | | | |
| Regression R-1 to R-8 | | | |
| Taint T-1, T-2 | | | |
