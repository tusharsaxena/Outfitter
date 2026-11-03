# Ka0s Outfitter Reborn — Architecture

The engineer brief and the hub of the doc set (documentation-§3). This is the scaffold's minimal
hub: each section names what exists today and grows as the port lands. The design the addon is
built to is
[`superpowers/specs/2026-11-03-design.md`](superpowers/specs/2026-11-03-design.md) (the design), and
the build order is
[`superpowers/plans/2026-11-03-ka0s-conversion.md`](superpowers/plans/2026-11-03-ka0s-conversion.md)
(the plan).

## Overview

Ka0s Outfitter Reborn is an equipment manager for Retail (Midnight, 12.x): named outfits, switched
by hand or automatically by native triggers, docked to the character sheet. It is a rewrite of the
community fork of Outfitter by John Stephen (mundocani), MIT licensed, as an Ace3 addon in the
standard's modular layout, on the vendored `LibKa0s` v1.85.0.

The rewrite lands in steps (the design's §11 and §12). Today the scaffold carries the namespace,
media, constants, session state, environment, core printer, the AceAddon object and the AceDB
store with its migration runner; the seams, the settings and the engine follow.

## Module Map

The TOC (`OutfitterReborn.toc`) is the load order and the authority on it.

| File | Job |
|---|---|
| `locales/enUS.lua` | `NS.L`, the canonical locale with the key-is-the-string fallback |
| `core/Namespace.lua` | `NS.PREFIX`, `NS.name`, `NS.BRAND`, `NS.SLASH`/`NS.SLASH_LONG`, the version fallback |
| `core/MediaSetup.lua` | `NS.Icon`, `NS.MediaFont` and the LibSharedMedia registration (LibKa0s-Media) |
| `core/Constants.lua` | `FONT_MONO`, `LOGO`/`LOGO_128`, `LAYERS`, `OUTFIT_MESSAGE_COLOR` |
| `core/State.lua` | `NS.State`: session-only flags (`debug`, `testMode`, `legacyLoaded`) |
| `core/EnvSetup.lua` | `NS.Meta`, `NS.Version` (LibKa0s-Env) |
| `core/CoreSetup.lua` | `NS.Print`, `NS.SafeToString`, the `SafeRegister*` family, the window chrome (LibKa0s-Core) |
| `core/SkinSetup.lua` | `NS.Skin`, the owner registration and its `of.*` tokens, the skin choice and picker seams (LibKa0s-Skin) |
| `core/Bus.lua` | `NS.MSG`, `NS.NewBusTarget`, `NS.SendBus`, `NS.BusStandDown`/`BusStandUp` (LibKa0s-Bus) |
| `core/OutfitterReborn.lua` | `NewAddon`, the `NS.Print` reclaim, `OnInitialize` (DB, migrations, the profile's skin) |
| `core/Database.lua` | AceDB, the profile callbacks, the migration runner, both `resolveRoot` functions |
| `defaults/Profile.lua` | `NS.defaults`, the only place a default is hardcoded |

## Settings Schema

The store is `OutfitterRebornDB`, one AceDB object on the shared "Default" profile (H30), shaped by
`defaults/Profile.lua`. Settings live in `profile`; outfits live in `char`, which no profile
callback touches (H7). `global.schemaVersion` is the migration stamp, advanced by
`NS:RunMigrations` (`core/Database.lua`) after each step returns; a step may walk every stored
profile (`scope = "profile"`) or every stored character (`scope = "char"`). There are no schema rows
yet.

Named non-setting state (architecture-§5): `profile.windows.bar` is written only by
`NS.Bar.SavePosition`; `profile.windows.dialogs[key]` only by `NS.Dialogs.SavePosition`;
`global.minimap.minimapPos` only by LibDBIcon; `char.outfits`, `char.order`, `char.nextID`,
`char.bindings` and `char.seeded` only by `NS.Outfits` (and the instance-row writes through the
outfit schema's `resolveRoot`); `char.stack` and `char.recent` only by `NS.Stack`; `char.emPreserved`
only by `NS.EM`; `outfits[id].triggerState[TID]` only by `NS.TriggerBinder`. Each owner arrives with
the port.

## Message Bus

`core/Bus.lua` declares the full catalog (`NS.MSG`, 25 keys, wire names
`Ka0s_OutfitterReborn_<Pascal>`), each with its one sending file on a `Sender:` line. Nothing
sends yet; each sender arrives with its module.

## Slash Commands

No commands yet. `/of` (primary) and `/outfitter` (alias) arrive with `settings/Slash.lua`.

## Event Subscriptions

None yet. The scaffold registers no game event.

## Taint Notes

Nothing in the scaffold touches a secure frame or a protected call.

## Known Limitations

- The scaffold loads and stores settings only: no outfit can be worn yet.

## Documentation map

Frozen and generated stores are named once each and not enumerated: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`,
`docs/revendor/<date>-v<tag>/`, `docs/superpowers/` and `docs/investigations/` (documentation-§3).
Of those, `docs/reviews/`, `docs/revendor/<date>-v<tag>/` and `docs/superpowers/` exist today;
`docs/superpowers/` holds the design, the plan and the research behind them. The rest of the doc set
arrives with the documentation commit.

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `users-manual.md` | The player's manual, carried over from the fork |

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| localization-§5 | tests/_kit/test_prose declined until the doc set is rewritten in US English | The scaffold keeps the fork's README, user manual and research documents, which are written in British English; the documentation commit rewrites them and wires the suite in the same change | 2026-11-03 | C16 lands |

### Files over the 1500-line cap

Nothing is over the cap today.
