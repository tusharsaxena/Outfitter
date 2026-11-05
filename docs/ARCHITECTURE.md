# Ka0s Outfitter Reborn — Architecture

The engineer brief and the hub of the doc set (documentation-§3). Each section below summarizes and
links its topic doc; the registers at the end (`## Documentation map`, `## Documented deviations`)
are read here. The design the addon is built to is
[`superpowers/specs/2026-11-03-design.md`](superpowers/specs/2026-11-03-design.md) (the design), and
the build order is
[`superpowers/plans/2026-11-03-ka0s-conversion.md`](superpowers/plans/2026-11-03-ka0s-conversion.md)
(the plan).

## Overview

Ka0s Outfitter Reborn is an equipment manager for Retail (Midnight, 12.x). A player builds named
outfits, wears them by hand from a window docked to the character sheet, from an outfit bar, from key
bindings or from `/or`, and lets **native triggers** wear and remove them automatically: fishing,
gathering, a battleground or arena by map, a druid form, a spec, a mount, and about seventy more
(77 in all). It is a rewrite of the community fork of Outfitter by John Stephen (mundocani), MIT
licensed, as an Ace3 addon in the standard's modular layout, on the vendored `LibKa0s` v1.87.0.

Three ideas carry the design:

- **One store, one writer per key.** `OutfitterRebornDB` holds settings per profile and outfits per
  character (`db.char`), and no profile callback touches `db.char` (H7, H30). Every settings write goes
  through one seam, `NS.SetByPath`; every outfit-record write goes through `NS.Outfits`.
- **One equipment bracket that cannot strand.** Every change to what is worn runs inside
  `NS.Equip.Batch(fn)`, an `xpcall` bracket that always restores its counter, so an error in a trigger
  or a secret value can no longer stop equipment updates for the session (the fork's worst bug).
- **Triggers are data.** A trigger is a shipped descriptor (events, typed parameters, a condition
  from a family factory). An outfit stores only the trigger's id, its flags and its parameters, so
  behavior always comes from the code that ships. There is no `loadstring` and no script editor (R3).

**What ships in 1.1.0.** The whole port is in the tree: the seams over `LibKa0s`, the AceDB store
with its migration runner, the equipment engine (inventory scan, outfit store, stack, the equip
bracket, the Equipment Manager mirror, the bank verbs, the stat optimizer, the battle-pet companion),
the native trigger catalog with its binder and state producers, the docked outfit window and its
slot checkboxes, the outfit bar, the dialogs and menus, the tooltips and quick slots, test mode, the
public API, four settings pages (General, Outfit Bar, Outfit Window, Profiles), 36 slash verbs, 15 key bindings
and six translation overlays. What it does not do yet, and what a client has still to confirm, is
under Known Limitations.

## Module Map

The TOC (`OutfitterReborn.toc`) is the load order and the authority on it: `libs → locales → core →
defaults → modules → settings`. The full table, every file with its one job and the reason for each
`LOAD-BEARING` line, is [`module-map.md`](module-map.md).

In outline: `core/` holds the seams, each a lease on one `LibKa0s` major with a degrade stub
(`core/Compat.lua` and `core/Secrets.lua` are the addon's own); `defaults/` holds pure data (the
profile defaults, the item and zone tables, the trigger catalog and its ID tables, the test-mode
outfits; `defaults/Profile.lua` is the only place a default is hardcoded); `modules/` holds, in load
order, the engine (`PlayerState` through `Companion`), the triggers and their state producers
(`Triggers_*`, `States`, `States_Zone`), then the UI (`Commands` through `Preview`, with `Sheet`
reading which character sheet is up for the dock, and `Broker` the Outfits data source), the public API
(`Api`) and the diagnostics sections; `settings/` holds the schema, the slash dispatcher and the
pages, last.

## Settings Schema

The store is `OutfitterRebornDB`, one AceDB object on the shared "Default" profile (H30), shaped by
`defaults/Profile.lua`. Settings live in `profile`; outfits live in `char`; `global` holds the
migration stamp, LibDBIcon's table and the skin notice. `global.schemaVersion` is the migration stamp,
advanced by `NS:RunMigrations` (`core/Database.lua`) after each step returns; a step may walk every
stored profile (`scope = "profile"`) or every stored character (`scope = "char"`).

There are two Schema instances (design §3.5). `NS.Schema` (`settings/Schema.lua`) holds every settings
row and is the only one Options, the slash CLI and Reset all read; `NS.OutfitSchema`
(`modules/Outfits_Schema.lua`) holds the per-outfit instance rows (`outfit.*`,
`trigger.<TID>.*`). `NS.SetByPath(path, value, instanceId)` is the one write seam for both: a non-nil
`instanceId` forwards to the outfit instance. Their roots are `NS.ResolveSettingsRoot` and
`NS.ResolveOutfitRoot` in `core/Database.lua`.

The full shape, every default, the migration path, the outfit and item records and the registry
detail are in [`schema.md`](schema.md). The section has spilled there, so `schema.md` is also the
one home of the **named non-setting state** (the window positions, LibDBIcon's minimap position, the
outfit store, the persisted stack and recents, the preserved equipment sets, the triggers' own
state): each piece's storage key, its one owner module and every function that writes it
(architecture-§5).

## Message Bus

`core/Bus.lua` declares the whole catalog: `NS.MSG`, 23 keys, wire names
`Ka0s_OutfitterReborn_<Pascal>`, each with its one sending file on a `Sender:` line that
`tests/test_bus.lua` holds every `NS.SendBus` call site to. Handlers are isolated by LibKa0s-Bus (or
by the degraded arm's `xpcall`), and nothing is dispatched before `OnEnable` and the first LoadPass.
Every key has exactly one sending file in the tree, and `test_bus` holds the rule. Every key also
has a receiver: `STATS_CHANGED` and `LEGACY_DETECTED`, which nothing heard, were dropped.
Every message with its sender, payload and receivers: [`message-bus.md`](message-bus.md).

## Slash Commands

`/or` is the command and `/outfitterreborn` its alias; both reach one dispatcher (`settings/Slash.lua`, on
LibKa0s-Slash), behind a host routing wrapper that runs macro conditionals through
`SecureCmdOptionParse` (H25). `NS.COMMANDS` opens with the reserved verbs:

| Verb | What it does |
|---|---|
| `help` | Show this help |
| `config` | Open the settings panel |
| `skin` | Choose a skin: open the skin picker |
| `enable` | Turn the addon on |
| `disable` | Turn the addon off without unloading it |
| `list` | List every setting |
| `get` | Read one setting: `/or get path` |
| `set` | Write one setting: `/or set path value` |
| `reset` | Reset one setting: `/or reset path` |
| `resetall` | Reset every setting (asks first) |
| `debug` | Debug console; `on`/`off` set logging, `diagnostics` writes the report |
| `diagnostics` | Write the diagnostics report to the debug console |
| `perf` | Performance capture; try `/or perf help` |
| `version` | Print the addon version |

The outfit verbs (`show`, `hide`, `wear`, `unwear`, `toggle`, `update`, the bank verbs, `auto`,
`zone`, `iteminfo`, `test`, `bar`, `lock`, `unlock`, `deleteall` and the rest) follow `version`, with
their handlers in `modules/Commands.lua` (`bar show|hide|toggle` writes `bar.shown` in
`settings/Slash.lua`, or in test mode only dismisses the bar for that test session; the *Toggle outfit bar* key runs it). The live-while-disabled rules, the macro-conditional routing and
the full verb set are in [`slash-dispatch.md`](slash-dispatch.md).

## Public API

`modules/Api.lua` builds the one surface another addon may call, `NS.API.v1`, and publishes it
under the folder's name as `_G[addonName] = { API = NS.API }`, so a consumer reads
`OutfitterReborn.API.v1`, as public-api requires (standard v2.99.1). Only the
API table is global, never `NS`. **v1 is semver-stable**: a member is never removed or changed in
meaning inside v1, and a breaking change arrives as a sibling `v2`.

| Member | Answers |
|---|---|
| `FindOutfitByName(name)` | A copy `{ id, name, category }` of the outfit with that name (case-insensitive), or nil |
| `WearOutfit(name)` | `true` when the outfit was worn; `false` for an unknown name or while the addon is stood down |
| `RemoveOutfit(name)` | `true` when the outfit was taken off; `false` for an unknown name, an outfit not worn, or while stood down |
| `GetCurrentOutfitInfo()` | `name, id` of the top outfit; `""` when nothing is worn, the localized "Custom" for a temporary outfit |
| `GetOutfitsUsingItem(link)` | An array of copies `{ id, name }`; empty for a secret or unparsable link |
| `RegisterOutfitEvent(fn)` | `true` once `fn` is subscribed (a second call with the same `fn` is the same subscription); `false` for a non-function or with no event bus |
| `UnregisterOutfitEvent(fn)` | `true` when `fn` was subscribed |

The contract:

- **No member raises.** Called before the saved data exists (at the caller's own load), each answers
  its empty value.
- **Answers are fresh copies**, so nothing a caller writes into one can reach the store.
- **Stood down, the two wear calls refuse** (disabled means not running); the reads still answer.
  An addon's wear is not a hardware event, so it never changes the player's title.
- **Events.** A subscriber is called as `fn(event, id, ...)` for the six outfit messages
  (`OUTFIT_ADDED`, `OUTFIT_DELETED`, `OUTFIT_RENAMED`, `OUTFIT_WORN`, `OUTFIT_REMOVED`,
  `OUTFIT_EDITED`). `event` is the catalog key, never the wire name, and `...` is the rest of the
  bus payload ([`message-bus.md`](message-bus.md)). Each call is isolated with `xpcall` and a raise
  goes to the client's error handler; a return value is ignored. Nothing is delivered before the
  session's first LoadPass, and nothing while the addon is stood down.

The legacy `Outfitter_*` globals are gone and are not shimmed (H3, deviation row D1 below);
`tests/test_api.lua` pins the members and the global allow-list.

## Event Subscriptions

Game events are registered on module-local AceEvent targets through `NS.SafeRegisterEvent` (and a
player-only unit event through `NS.SafeRegisterUnitEvent` on a unit-filtered frame), so a name the
client rejects lands in `NS.rejectedEvents` and `/or diagnostics` instead of raising. The addon
object registers none: each module registers its own in its `Resume()` and drops them in its
`Suspend()`. In outline:

- **PlayerState**: combat, death, the player's casts and the spec.
- **Inventory**: the bag, bank and item-info events, and the player's `UNIT_INVENTORY_CHANGED`.
- **Equip** and **Outfits_Seed**: the loading-screen edges and the first LoadPass.
- **States** and **States_Zone**: the player's `UNIT_AURA`, the Dining and Spirit watches while a
  trigger needs them, the zone events, and a 0.5 s mounted and swimming poll.
- **Dock**: `PLAYER_REGEN_DISABLED`/`ENABLED`, to hide the window for combat. **Bar**: pet battles.
  **EquipmentManager**: `EQUIPMENT_SETS_CHANGED`. **ItemStats_Sources**: `ADDON_LOADED`, for a stat
  addon that loads late.
- **Triggers_Binder**: each bound trigger's descriptor events, on the outfit's own target.
- **core/SecureQueue.lua** and **core/SkinSetup.lua**: `PLAYER_REGEN_ENABLED`, only while something
  waits out combat.

The full table and the pipeline from event to equipped item are in [`data-flow.md`](data-flow.md).

## Frame layering

Every strata and level comes from `NS.Constants.LAYERS` (`core/Constants.lua`, frame-layering-§5);
there is no strata literal anywhere. The two docked surfaces take their layer from the character
sheet: the outfit window copies the sheet holder's strata and sits `LAYERS.LEVEL.DOCK_OVER_HOST`
above it. The slot checkboxes take the **host strata**, the highest among `CharacterFrame` and its 18
`Character<Slot>` buttons (ranked by `LAYERS.STRATA_ORDER`; ChonkyCharacterSheet lifts the slot
buttons to `HIGH` under a `MEDIUM` sheet, EllesmereUI lifts the sheet itself), and one level above
the highest frame **of that strata** under the sheet, capped at `LAYERS.LEVEL.MAX` (smoke round 2
design G3). So they beat the item buttons and any addon drawing over them, and a high level in a
lower strata no longer inflates theirs. Both re-sync from the window's follow tick, on a level or a
strata change, because raising the sheet changes its level. Neither ever gets a fixed strata, which
would poke it through a window that covers the sheet (the fork's lesson, kept). The bar is `HUD`
(its header band, test strip and labels ride its own levels; the separate drag handle is retired),
the dialogs and the icon browser `MODAL` (the browser in a band over the dialogs), the menus `POPUP`
(each cascading level of a menu in the same strata) and the compare tooltips `CURSOR`. The full stack
is in the design's §7.1 and the limitations it leaves are in [`known-limitations.md`](known-limitations.md).

## Taint Notes

Every secure-environment write goes through `NS.SecureQueue.Run(key, fn)`: it runs at once out of
combat lockdown, otherwise it waits (latest per key) and replays on `PLAYER_REGEN_ENABLED`
(events-frames-taint-§2). Nothing is written into a Blizzard frame or table (skinning-§7): hooks are
`hooksecurefunc` or `HookScript`, and every hook body checks the stand-down latch first. The outfit
list's secure item buttons make the window protected, so it hides for the length of combat and is
moved rather than its rows re-anchored. While the outfit window is shown, every slot's own popout
arrow is shown per button (never `EquipmentFlyoutPopoutButton_ShowAll`/`HideAll`, which write
`flyoutLocked`), re-shown after Blizzard's `HideAll` through a post-hook, and a character-sheet
slot's horizontal flyout is re-anchored level with its slot; all of it out of lockdown only and put
back when the window goes. The full notes, with each secure surface and the client checks still
owed: [`taint.md`](taint.md).

## Known Limitations

- The window is hidden for the length of combat (a behavior change from the fork, O4).
- Old saved variables are not migrated: 1.1.0 starts from a fresh store (R4), and old key
  assignments are lost (H11).
- Both the old Outfitter and this addon may change gear if both are loaded; the addon warns once and
  does not hold its triggers (O2).
- The six translations carry only what the fork translated; a string the port rewrote or added shows
  in English on those clients.
- The sheet button copies each host sheet's tab, so it inherits that sheet's quirks: Chonky's tab row
  sits about 18 px right-heavy with it, and the EllesmereUI label takes EllesmereUI's face when it is
  placed, not when EllesmereUI changes it.

The full list, with the client checks still owed: [`known-limitations.md`](known-limitations.md).

## Documentation map

Frozen and generated stores are named once each and not enumerated: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`,
`docs/revendor/<date>-v<tag>/`, `docs/superpowers/` and `docs/investigations/` (documentation-§3).
Of those, `docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`,
`docs/revendor/<date>-v<tag>/` and `docs/superpowers/` exist today; `docs/superpowers/` holds the
design, the plan and the research behind them, and `docs/reviews/2026-09-16/` is the fork's last
review, kept frozen.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `ARCHITECTURE.md` | This file: the hub |
| [`scope.md`](scope.md) | What the addon does, and what it deliberately leaves out |
| [`module-map.md`](module-map.md) | Every authored file, its job, and the TOC load order with its reasons |
| [`schema.md`](schema.md) | SavedVariables shape, defaults, migrations, the outfit and item records, named non-setting state |
| [`settings-panel.md`](settings-panel.md) | The `Page \| Covers` table and the page → tab → row tree, mapped to schema paths |
| [`data-flow.md`](data-flow.md) | Load and enable, the write seam, the stand-down latch, and the trigger → stack → equip pipeline |
| [`common-tasks.md`](common-tasks.md) | Recipes for the changes most often made here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| [`perf-analysis/README.md`](perf-analysis/README.md) | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| [`slash-dispatch.md`](slash-dispatch.md) | Present | `NS.COMMANDS` holds the reserved verbs and the outfit verbs, well past the trigger of eight or more |
| [`midnight-quirks.md`](midnight-quirks.md) | Present | `core/Compat.lua` carries client-version workarounds of its own (the table-detector ladder, the spec ladder's stub) and the secret-value rules |
| [`compat-layer.md`](compat-layer.md) | Present | `core/Compat.lua` publishes far more than the trigger's three hand-written shims ([`compat-layer.md`](compat-layer.md) has the counting grep) |
| [`message-bus.md`](message-bus.md) | Present | 23 messages in `NS.MSG` (the trigger is more than ten) |
| [`profiles.md`](profiles.md) | Present | A Profiles page ships in the options UI (`settings/Profiles.lua`) |
| [`known-limitations.md`](known-limitations.md) | Present | Known Limitations spilled: the full list passes ~60 lines; the hub keeps a summary |
| [`taint.md`](taint.md) | Present | Taint Notes spilled: the secure surfaces pass ~60 lines; the hub keeps a summary |
| [`debug.md`](debug.md) | Present | The diagnostics report ships (always fired) |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| [`testing.md`](testing.md) | How to run the harness and lint; the green commit gate; the suite checkpoints |
| [`smoke-tests.md`](smoke-tests.md) | The owner's in-game checklist and every client assumption with its pass criterion |
| [`test-cases.md`](test-cases.md) | The generated case inventory (authoritative pass count) |
| [`performance.md`](performance.md) | The addon performance page |
| [`automated-tests/README.md`](automated-tests/README.md) | What the automated-test record is and how to produce it |
| [`automated-tests/RESULTS.md`](automated-tests/RESULTS.md) | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4) |

### Addon-specific (documentation-§3, Tier 3)

None. The fork's `users-manual.md` was retired in P10: its player content is the README (the one
player-facing document, documentation-§1), and its slash-command table was a second copy of
[`slash-dispatch.md`](slash-dispatch.md), which Tier 3 may not duplicate.

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `versioning-git` (the semver line) | The release is 1.1.0, although the public API (the `Outfitter_*` globals are gone, H3) and the saved-data format (a fresh `OutfitterRebornDB`) both break, which would call for a MAJOR | D1. Owner ruling 2026-11-03 (the plan's Version decision): 1.1.0 continues the fork's numbering on CurseForge project 1698220. The consumers that lose globals are named in the Version History (design §5.16) | 2026-11-03 | The next MAJOR release |
| `standalone-windows` (plain non-secure window, movable, saved position, Lock/Reset, toplevel; the `UISpecialFrames` MUST is honored) | The main window is a protected frame: each outfit row carries a `SecureActionButtonTemplate` child (`modules/Window_Rows.lua`). It is docked to the character sheet: not movable, no saved position, no Lock or Reset, strata and level copied from `OutfitterRebornSheetHolder`, not toplevel. It is hidden for the length of combat and returns at `PLAYER_REGEN_ENABLED`. Its dialogs stay open through that combat suspend. Escape closes it through `UISpecialFrames`. **Test mode** (D10): while the session-only test mode is on and the sheet is closed, the window stands alone in the screen center (`NS.Dock.AloneSpot`, through the dock's one `TOPLEFT` point and `Dock.Refresh`, never in lockdown), listing the sample outfits under a test strip; alone, it is draggable for the test session, out of combat only, and its position is not saved (the drop clears the client's user-placed flag; the next session starts centered), and it stores nothing (no position, no outfit). X or Escape hides it for the rest of that test session without ending test mode, which still ends only on its own switch, combat or Reset all (preview-mode); opening the sheet docks it as usual | D2. Owner ruling R5 (H4). The outfit list's secure item buttons make every in-combat Show, Hide or SetPoint on the window a blocked action (fork `Outfitter.lua:1326-1331, 8448-8494`). Closing dialogs in combat would lose input (O30). The test-mode clause is D10 of the [2026-11-05 design](superpowers/specs/2026-11-05-smoke-round-2-design.md) (owner ruling 2026-11-05): the player places and skins the window without opening the sheet, as PGFE's test mode does; it reverses H17 ("the window shows real data"), marked so at H17 in the 2026-11-03 design. Smoke round 3 E3 (owner, 2026-11-05) amends the clause from "still unmovable" to "draggable for the session, position not saved" ([round 3 plan](superpowers/plans/2026-11-05-smoke-round-3.md)) | 2026-11-03; test clause 2026-11-05, E3 amendment 2026-11-05 | Blizzard ships a docking API, or the list stops needing secure buttons; for the test clause, preview-mode gains a rule for docked windows |
| `standalone-windows` (explicit window verbs `show` / `hide` / `toggle`, a SHOULD) | `/or show` and `/or hide` open and close the window, but there is no window `toggle` verb: `/or toggle <outfit>` stays the outfit verb. The key binding and the sheet button toggle the window | C35. `toggle` has been the outfit verb in players' macros since before this fork, and taking it for the window would break them. The reason is also at the comment above `NS.COMMANDS` (`settings/Slash.lua`) and in [`slash-dispatch.md`](slash-dispatch.md) | 2026-11-03 | `toggle` retires as an outfit verb, or the standard names a different window-toggle verb |
| `localization-§4` | The IN_ZONES subzone list matches `GetMinimapZoneText()` strings captured on the player's own client | D3. No API exposes the current areaID; zones match on uiMapID (H9) | 2026-11-03 | Blizzard exposes the current areaID |
| `localization-§4` | LOCKPICKING matches the lockbox tooltip line against `LOCKED_WITH_SPELL` + `GetTradeSkillDisplayName(633)`, and falls back to `L["Requires Lockpicking"]` when that does not reproduce the line | D4. No GlobalString for the line is confirmed (O22); without the fallback the trigger is dead on any client where the composed form differs | 2026-11-03 | The client check confirms the composed GlobalString form on every shipped locale, after which the `L` fallback and this row go |
| `documentation-§1` | The README has no screenshots of the 1.1.0 UI | D6. They need a client capture of the reskinned docked window and settings pages after the smoke test; stale shots would mislead (H22) | 2026-11-03 | The first client capture of 1.1.0 |
| `localization-§4` | `Inv.SlotItemActive` (the TRINKET_QUEUE skip-while-active rule) parses the item's use-duration tooltip line with the `cUseDurationTooltipLineFormat*` patterns kept in `L` | D8. No GlobalString or ID route gives an active use effect's remaining duration yet (O15) | 2026-11-03 | `C_Item.GetItemSpell` plus spell-duration data (or an aura read) covers it, after which the `L` keys and this row go |
| `launcher-§1` | A second LibDataBroker object, `OutfitterRebornOutfits` (type `data source`, `modules/Broker.lua`), carries the old addon's outfit switcher; the launcher object is unchanged, and the second object is never put on the minimap | Owner ruling 2026-11-04: players used the old broker plugin to switch outfits, and the launcher's clicks and logo are fixed by launcher-§2/§4 | 2026-11-04 | The standard allows a feature data source next to the launcher |
| `skinning-§1`/`skinning-§9` (`DEV-SKIN-SHEET-BUTTON`) | The sheet button (`OutfitterRebornSheetButton`, `modules/Dock.lua`) draws the host sheet's tab look, not the Ka0s skin: on the stock sheet and ChonkyCharacterSheet a hand-built copy of Blizzard's `PaperDollSidebarTabTemplate` (TabBg, icon, Hider and Highlight from `Interface\PaperDollInfoFrame\PaperDollSidebarTabs` with the template's texcoords, selected while the window shows); on EllesmereUI a text tab, `L["Outfits"]`, in EllesmereUI's tab style (its face at size 10, white at 0.6 idle, 1.0 on hover, `EllesmereUI.ELLESMERE_GREEN` while the window shows). No `NS.Skin` call paints it, it left `Kit.skinSwitch.surfaces` (`tests/skin_surfaces.lua`), and its three typed values are `Kit.skinValues` rows citing this id (`tests/run.lua`) | Smoke round 2 design D3/D4 (G2), [2026-11-05](superpowers/specs/2026-11-05-smoke-round-2-design.md): the way in sits in the host's own tab row, and a skinned button there read as bolted on; matching the neighboring tabs is the point, so the skin must not reach it | 2026-11-05 owner ruling | The standard gains a host-matched ingress exception, or a host changes its tabs (Blizzard's sidebar tab art, Chonky's tab row, EllesmereUI's tab style) |
| `localization-§4` | The gathering triggers (GATHER_HERBALISM, GATHER_MINING) match the node tooltip's line against `C_TradeSkillUI.GetTradeSkillDisplayName(skillLine)`, the client's own localized name for an ID, not a GlobalString constant | D10. Tooltip data exposes no skill line for a node; the name is never hardcoded or put in `L`, so the match is correct on every locale | 2026-11-03 | `TooltipDataProcessor` exposes the node's skill line |

One more row is conditional (the design's §10): **D7** (`localization-§7`, CJK and Cyrillic text
in Skin faces) is written only if smoke test X1 shows a box glyph. The vendored Skin major already
refuses a face the client's locale cannot draw, so only that client check remains. The client checks
the design's §14 still owes are mapped to their rows in
[`smoke-tests.md`](smoke-tests.md#10-what-the-headless-run-cannot-reach) section 10.

Not deviations, recorded for audit clarity: `UnitFactionGroup`'s first return is read with a comment,
and the standard's defect is raised upstream (H10); the per-outfit trigger parameters are instance
rows on LibKa0s-Schema v3, so no row is needed (H13); triggers translate onto AceEvent rather than a
dispatcher (H14); no simulator ships, a MAY (H18); the options ship in the addon with four
subcategories, below options-ui-§4's five-subpanel trigger, so this is compliance and is the comment in
`settings/OptionsSetup.lua` (H21); the macro-conditional wrapper is host routing, not a dispatcher fork
(H25); the quick slots' flyout post-hooks (`modules/QuickSlots.lua`) are not a skin path, since
`skinning-§7` governs what a skin paints and `events-frames-taint-§3` binds only an addon that
replaces a Blizzard frame (the design's D11, ruled out by the 2026-11-04 audit).

### Files over the 1500-line cap

Nothing is over the cap today.
