# Known limitations

What Ka0s Outfitter Reborn does not do yet, does differently from the fork, or has not confirmed in a
client (documentation-§3, Tier 2: spilled from `ARCHITECTURE.md`). The O-numbers are the design's
open issues (§14); a row here leaves when its check passes or its owner rules.

## Translations

- **The six overlays carry only what the fork translated.** deDE, frFR, zhCN, zhTW, koKR and ruRU are
  generated from the fork's string tables by `tools/rekey-locales.lua`; a string the port rewrote or
  added has no line there and shows in English on those clients.

## Behavior changes from the fork

- **The window hides for the length of combat** (O4, C40) and comes back when combat ends if the
  character sheet is open. Its list rows hold secure buttons, so any in-combat Show, Hide or move on the
  window is a blocked action. Dialogs stay open through the suspend (O30). Recorded as deviation D2.
- **The window is docked, not movable** (D2). It follows the character sheet and has no saved
  position. If following ever fails, it parents to the sheet instead, which works but pins the sheet.
- **No migration** (R4). 1.1.0 starts from a fresh store: outfits, options and scripts from the old
  addon are not read. Blizzard equipment sets come back as outfits.
- **Key assignments are lost** (H11): the bindings have new names so they cannot collide with a
  legacy install.
- **No `Outfitter_*` globals** (H3, O42). FishingBuddy, ArkInventory, OutfitterFu, third-party stat
  plugins and `/script` macros that called them stop working; the public surface is
  `OutfitterReborn.API.v1`.
- **No Custom scripts** (R3). An outfit with a hand-written script has no equivalent; the shipped
  triggers cover every preset.
- **Automatic changes are per profile** (O35): on the shared Default profile, `/or auto off` affects
  every character on it.
- **Smart unequip forgets across `/reload`** (O9): a trigger that equipped an outfit before a reload
  will not remove it after one, because "did equip" is runtime state.
- **Rename no longer emits worn and removed events** (O16); no trigger relies on them.

## Living beside the old addon

- If the old Outfitter is also loaded, both change gear: the addon warns once at login and does not
  hold its triggers (O2, owner ruling). Disable the old one.
- The old addon keeps `/outfitter`; this one answers only to `/or` and `/outfitterreborn`, so the two
  never compete for a command.
- `/or` itself has not been checked against other common addons (O3).

## Not covered

- **Warband bank.** Not scanned, so warbound items there read as missing (O19).
- **Item stats.** `GetItemStats` combined primary keys on adaptive gear are aliased by hand, and
  Spirit scores 0 on current items (O20).
- **Icon search** covers named icon sets only (O33).
- **Trinket Queue's skip-while-active rule is inactive on frFR and koKR** (F-004). Their `Use:`
  duration patterns are inherited from the fork and cannot match a real tooltip, so an active trinket
  reads as not active there. The fix waits on the client's real tooltip lines, captured by
  smoke S-04 of the 2026-11-04 review ([`reviews/2026-11-04/03_SMOKE_TESTS.md`](reviews/2026-11-04/03_SMOKE_TESTS.md));
  the patterns are not written from memory.
- **Pet trigger picker.** The trigger dialog's pet field offers None, the stored pet and the summoned
  pet, not the owned-pet list: that needs a journal walk Compat does not publish yet
  (`Compat.OwnedPets()`, due when `core/Compat.lua` splits; it is at its line budget).

## Client checks still owed

Each is a row in [smoke-tests.md](smoke-tests.md) with its pass criterion.

| # | Assumption | Fallback if it fails |
|---|---|---|
| O5 | Find Fish tracking is spellID 43308 in `C_Minimap.GetTrackingInfo` | Texture 133888 |
| O7 | `Category-enUS: Inventory` is accepted | `Misc` |
| O8 | `ToggleCharacter` from an insecure CLICK binding works in combat | The "opens when combat ends" line |
| O10 | Spec triggers on `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` | A rejection shows in `/or diagnostics` |
| O11 | No `ADDON_ACTION_BLOCKED` from the window or its rows out of combat | — |
| O17 | The item, uniqueness, account-bound, usability, stats, Azerite and bank-container APIs on 12.x | A tooltip or ladder fallback per API |
| O18 | `EQUIPMENT_SETS_CHANGED` timing inside a save | Widen the ignore window, or match the set id |
| O22 | The lockpicking line's composed GlobalString | `L["Requires Lockpicking"]` (row D4) |
| O23 | `ChangeActionBarPage` in combat (Fishing) | Skipped in lockdown, retried on regen |
| O27 | Druid and rogue form spell IDs | A forms dump under `/or debug` |
| O29 | The sheet button beside the close button does not overlap | Move it |
| O31 | The window title fits 260 px | Shorten it |
| O34 | The Equipment Sets tooltip line | Suppression through `AddLinePreCall` |
| O38 | The title submenu with 200+ titles | — |
| O41 | `GetPrimaryTooltipInfo()` field names for the player-only "Used by outfits" gate | No line on an inventory tooltip (fails safe) |
| O44 | Equipment Manager saves in combat | Refused with a line |
| H8 | LibKa0s-Skin falls back to the client's locale font for zhCN, zhTW, koKR and ruRU | Conditional deviation row D7 |

## Test harness

- **One headless case flakes, about 1 run in 8 to 20** ([LibKa0s#75](https://github.com/tusharsaxena/LibKa0s/issues/75)):
  "bar: a profile switch redraws the bar from the new profile and rebinds the triggers"
  (`tests/test_bar.lua:577`). The cause is in the vendored kit: `Callbacks:unregisterAll`
  (`tests/_kit/mock_ace.lua:116-117`) writes `list[target] = nil` into lists that do not hold the
  target. In Lua 5.1 that can rehash a list mid-dispatch, so `Callbacks:fire`'s `next()` walk ends
  early and skips the bar's `PROFILE_CHANGED` listener; the trigger binder's `onProfile` calls
  `UnregisterAllMessages` inside that same dispatch. The real CallbackHandler guards this
  (`libs/CallbackHandler-1.0/CallbackHandler-1.0.lua:183-184`), so the game is unaffected. Re-run on a
  red bar profile-switch case; it clears at the re-vendor that carries the fix.

## Frame layering

The window and the slot checkboxes take their layer from the character sheet rather than a fixed
strata, so they never poke through a window that covers the sheet. The cost: another addon that
redraws the sheet at a higher level after the follow tick can sit over the checkboxes until the next
tick re-syncs them.
