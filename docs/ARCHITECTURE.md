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
bindings or from `/of`, and lets **native triggers** wear and remove them automatically: fishing,
gathering, a battleground or arena by map, a druid form, a spec, a mount, and about sixty more. It is
a rewrite of the community fork of Outfitter by John Stephen (mundocani), MIT licensed, as an Ace3
addon in the standard's modular layout, on the vendored `LibKa0s` v1.85.0.

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

**Where the build stands.** P3 (the scaffold) is complete: the namespace, media, constants, session
state, environment, core printer, every seam (Compat, Secrets, Bus, Skin, Pool, Item, Widgets,
SecureQueue, Lifecycle, Perf, DebugLog, Launcher), the AceAddon object, the AceDB store with its
migration runner, the settings skeleton (General with Master controls, Skin and Keybindings; Profiles),
the slash dispatcher with the reserved verbs, the first key binding, the locale scaffold and this doc
set. The engine, the triggers and the UI are P4 (the design's §12); each topic doc says which parts
exist today and which arrive with the port.

## Module Map

The TOC (`OutfitterReborn.toc`) is the load order and the authority on it: `libs → locales → core →
defaults → modules → settings`. The full table, every file with its one job and the reason for each
`LOAD-BEARING` line, is [`module-map.md`](module-map.md).

In outline: `core/` holds the seams, each a lease on one `LibKa0s` major with a degrade stub
(`core/Compat.lua` and `core/Secrets.lua` are the addon's own); `defaults/` holds pure data
(`defaults/Profile.lua`, the only place a default is hardcoded); `modules/` holds the engine, the
triggers and the UI (today only `modules/Diagnostics.lua`); `settings/` holds the schema, the slash
dispatcher and the pages, last.

## Settings Schema

The store is `OutfitterRebornDB`, one AceDB object on the shared "Default" profile (H30), shaped by
`defaults/Profile.lua`. Settings live in `profile`; outfits live in `char`; `global` holds the
migration stamp, LibDBIcon's table and the skin notice. `global.schemaVersion` is the migration stamp,
advanced by `NS:RunMigrations` (`core/Database.lua`) after each step returns; a step may walk every
stored profile (`scope = "profile"`) or every stored character (`scope = "char"`).

There are two Schema instances (design §3.5). `NS.Schema` (`settings/Schema.lua`) holds every settings
row and is the only one Options, the slash CLI and Reset all read; `NS.OutfitSchema`
(`modules/Outfits_Schema.lua`, P4.6) holds the per-outfit instance rows (`outfit.*`,
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

`core/Bus.lua` declares the whole catalog: `NS.MSG`, 25 keys, wire names
`Ka0s_OutfitterReborn_<Pascal>`, each with its one sending file on a `Sender:` line that
`tests/test_bus.lua` holds every `NS.SendBus` call site to. Handlers are isolated by LibKa0s-Bus (or
by the degraded arm's `xpcall`), and nothing is dispatched before `OnEnable` and the first LoadPass.
Every key has exactly one sending file in the tree (the last, `LEGACY_DETECTED` from
`core/OutfitterReborn.lua`'s `NS.OnLoadPassDone`, landed in P4.27, and `test_bus` holds the rule).
Every message with its sender, payload and receivers: [`message-bus.md`](message-bus.md).

## Slash Commands

`/of` is the command and `/outfitter` its alias; both reach one dispatcher (`settings/Slash.lua`, on
LibKa0s-Slash), behind a host routing wrapper that runs macro conditionals through
`SecureCmdOptionParse` (H25). `NS.COMMANDS` today:

| Verb | What it does |
|---|---|
| `help` | Show this help |
| `config` | Open the settings panel |
| `skin` | Choose a skin: open the skin picker |
| `enable` | Turn the addon on |
| `disable` | Turn the addon off without unloading it |
| `list` | List every setting |
| `get` | Read one setting: `/of get path` |
| `set` | Write one setting: `/of set path value` |
| `reset` | Reset one setting: `/of reset path` |
| `resetall` | Reset every setting (asks first) |
| `debug` | Debug console; `on`/`off` set logging, `diagnostics` writes the report |
| `diagnostics` | Write the diagnostics report to the debug console |
| `perf` | Performance capture; try `/of perf help` |
| `version` | Print the addon version |

The outfit verbs (`show`, `hide`, `wear`, `unwear`, `toggle`, `update`, the bank verbs, `auto`,
`zone`, `iteminfo`, `test`, `lock`, `unlock`, `deleteall` and the rest) follow `version`, with their
handlers in `modules/Commands.lua`. The live-while-disabled rules, the macro-conditional routing and
the full verb set are in [`slash-dispatch.md`](slash-dispatch.md).

## Event Subscriptions

Game events are registered on module-local AceEvent targets through `NS.SafeRegisterEvent`, so a
name the client rejects lands in `NS.rejectedEvents` and `/of diagnostics` instead of raising. Today
the tree registers one game event: `PLAYER_REGEN_ENABLED`, on `core/SecureQueue.lua`'s own target,
held only while a protected write waits out lockdown, and on a target of `core/SkinSetup.lua`'s own
while the first-run skin picker's start is held over combat. Each engine module brings its own
events in P4 (`PLAYER_EQUIPMENT_CHANGED`, `BAG_UPDATE_DELAYED`, `UNIT_AURA`, the zone events,
`PLAYER_REGEN_DISABLED`/`ENABLED` and the rest); the pipeline from event to equipped item is
[`data-flow.md`](data-flow.md).

## Frame layering

Every strata and level comes from `NS.Constants.LAYERS` (`core/Constants.lua`, frame-layering-§5);
there is no strata literal anywhere. The two docked surfaces take their layer from the character
sheet: the outfit window copies the sheet holder's strata and sits `LAYERS.LEVEL.DOCK_OVER_HOST`
above it, and the slot checkboxes take `CharacterFrame`'s strata, one level above the highest frame
under it, so they beat the item buttons and any addon drawing over them. Both re-sync from the
window's follow tick, because raising the sheet changes its level. Neither ever gets a fixed strata,
which would poke it through a window that covers the sheet (the fork's lesson, kept). The bar is
`HUD`, the dialogs `MODAL`, the icon chooser `POPUP` and the compare tooltips `CURSOR`. The full stack
is in the design's §7.1 and the limitations it leaves are in [`known-limitations.md`](known-limitations.md).

## Taint Notes

Every secure-environment write goes through `NS.SecureQueue.Run(key, fn)`: it runs at once out of
combat lockdown, otherwise it waits (latest per key) and replays on `PLAYER_REGEN_ENABLED`
(events-frames-taint-§2). Nothing is written into a Blizzard frame or table (skinning-§7): hooks are
`hooksecurefunc` or `HookScript`, and every hook body checks the stand-down latch first. The outfit
list's secure item buttons make the window protected, so it hides for the length of combat and is
moved rather than its rows re-anchored. The full notes, with each secure surface and the client checks
still owed: [`taint.md`](taint.md).

## Known Limitations

- The scaffold loads, stores settings and answers its slash and settings surfaces; no outfit can be
  worn until the engine lands in P4.
- The window is hidden for the length of combat (a behavior change from the fork, O4).
- Old saved variables are not migrated: 1.1.0 starts from a fresh store (R4), and old key
  assignments are lost (H11).
- Both the old Outfitter and this addon may change gear if both are loaded; the addon warns once and
  does not hold its triggers (O2).

The full list, with the client checks still owed: [`known-limitations.md`](known-limitations.md).

## Documentation map

Frozen and generated stores are named once each and not enumerated: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`,
`docs/revendor/<date>-v<tag>/`, `docs/superpowers/` and `docs/investigations/` (documentation-§3).
Of those, `docs/reviews/`, `docs/automated-tests/<run>/`, `docs/revendor/<date>-v<tag>/` and
`docs/superpowers/` exist today; `docs/superpowers/` holds the design, the plan and the research
behind them, and `docs/reviews/2026-09-16/` is the fork's last review, kept frozen.

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
| [`slash-dispatch.md`](slash-dispatch.md) | Present | 14 commands in `NS.COMMANDS` today (eight or more) |
| [`midnight-quirks.md`](midnight-quirks.md) | Present | `core/Compat.lua` carries client-version workarounds of its own (the table-detector ladder, the spec ladder's stub) and the secret-value rules |
| [`compat-layer.md`](compat-layer.md) | Present | `core/Compat.lua` publishes 73 hand-written shims (the trigger is three or more) |
| [`message-bus.md`](message-bus.md) | Present | 25 messages in `NS.MSG` (the trigger is more than ten) |
| [`profiles.md`](profiles.md) | Present | A Profiles page ships in the options UI (`settings/Profiles.lua`) |
| [`known-limitations.md`](known-limitations.md) | Present | Known Limitations spilled: the full list passes ~60 lines; the hub keeps a summary |
| [`taint.md`](taint.md) | Present | Taint Notes spilled: the secure surfaces the port lands pass ~60 lines; the hub keeps a summary |
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

| Doc | Covers |
|---|---|
| [`users-manual.md`](users-manual.md) | The player's manual, carried over from the fork; folded into the README in P10 |

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `versioning-git` (the semver line) | The release is 1.1.0, although the public API (the `Outfitter_*` globals are gone, H3) and the saved-data format (a fresh `OutfitterRebornDB`) both break, which would call for a MAJOR | D1. Owner ruling 2026-11-03 (the plan's Version decision): 1.1.0 continues the fork's numbering on CurseForge project 1698220. The consumers that lose globals are named in the Version History (design §5.16) | 2026-11-03 | The next MAJOR release |
| `standalone-windows` (movable, saved position, Lock/Reset, toplevel; the `UISpecialFrames` MUST is honored) | The main window is docked to the character sheet: not movable, no saved position, no Lock or Reset, strata and level copied from `OutfitterRebornSheetHolder`, not toplevel. It is hidden for the length of combat and returns at `PLAYER_REGEN_ENABLED`. Its dialogs stay open through that combat suspend. Escape closes it through `UISpecialFrames` | D2. Owner ruling R5 (H4). The outfit list's secure item buttons make every in-combat Show, Hide or SetPoint on the window a blocked action (fork `Outfitter.lua:1326-1331, 8448-8494`). Closing dialogs in combat would lose input (O30) | 2026-11-03 | Blizzard ships a docking API, or the list stops needing secure buttons |
| `standalone-windows` (explicit window verbs `show` / `hide` / `toggle`, a SHOULD) | `/of show` and `/of hide` open and close the window, but there is no window `toggle` verb: `/of toggle <outfit>` stays the outfit verb. The key binding and the sheet button toggle the window | C35. `toggle` has been the outfit verb in players' macros since before this fork, and taking it for the window would break them. The reason is also at the comment above `NS.COMMANDS` (`settings/Slash.lua`) and in [`slash-dispatch.md`](slash-dispatch.md) | 2026-11-03 | `toggle` retires as an outfit verb, or the standard names a different window-toggle verb |
| `localization-§4` | The IN_ZONES subzone list matches `GetMinimapZoneText()` strings captured on the player's own client | D3. No API exposes the current areaID; zones match on uiMapID (H9) | 2026-11-03 | Blizzard exposes the current areaID |
| `localization-§4` | LOCKPICKING matches the lockbox tooltip line against `LOCKED_WITH_SPELL` + `GetTradeSkillDisplayName(633)`, and falls back to `L["Requires Lockpicking"]` when that does not reproduce the line | D4. No GlobalString for the line is confirmed (O22); without the fallback the trigger is dead on any client where the composed form differs | 2026-11-03 | The client check confirms the composed GlobalString form on every shipped locale, after which the `L` fallback and this row go |
| `documentation-§1` | The README has no screenshots of the 1.1.0 UI | D6. They need a client capture of the reskinned docked window and settings pages after the smoke test; stale shots would mislead (H22) | 2026-11-03 | The first client capture of 1.1.0 |
| `localization-§4` | `Inv.SlotItemActive` (the TRINKET_QUEUE skip-while-active rule) parses the item's use-duration tooltip line with the `cUseDurationTooltipLineFormat*` patterns kept in `L` | D8. No GlobalString or ID route gives an active use effect's remaining duration yet (O15) | 2026-11-03 | `C_Item.GetItemSpell` plus spell-duration data (or an aura read) covers it, after which the `L` keys and this row go |
| `localization-§4` | The gathering triggers (GATHER_HERBALISM, GATHER_MINING) match the node tooltip's line against `C_TradeSkillUI.GetTradeSkillDisplayName(skillLine)`, the client's own localized name for an ID, not a GlobalString constant | D10. Tooltip data exposes no skill line for a node; the name is never hardcoded or put in `L`, so the match is correct on every locale | 2026-11-03 | `TooltipDataProcessor` exposes the node's skill line |

Two more rows are conditional and are written only if their check goes the way they describe (the
design's §10, tracked as open issues rather than parked here): **D7** (`localization-§7`, CJK and
Cyrillic text in Skin faces, if LibKa0s-Skin has no locale font fallback) and **D11** (`skinning-§7`,
the quick slots' flyout hooks, if an audit reads them as writes into Blizzard tables).

Not deviations, recorded for audit clarity: `UnitFactionGroup`'s first return is read with a comment,
and the standard's defect is raised upstream (H10); the per-outfit trigger parameters are instance
rows on LibKa0s-Schema v3, so no row is needed (H13); triggers translate onto AceEvent rather than a
dispatcher (H14); no simulator ships, a MAY (H18); the options ship in the addon with three
subcategories, below options-ui-§4's five-subpanel trigger, so this is compliance and is the comment in
`settings/OptionsSetup.lua` (H21); the macro-conditional wrapper is host routing, not a dispatcher fork
(H25).

### Files over the 1500-line cap

Nothing is over the cap today.
