# Data flow

How Ka0s Outfitter Reborn actually works, as a pipeline (documentation-§3, Tier 1): load and enable,
the write seam, the stand-down latch, and the core mechanic, a trigger or a click in and an equipped
item out. It is the engineer counterpart of the README's "How it works"; the two describe one
pipeline and must not contradict each other.

Sections marked **P4** describe the design (`superpowers/specs/2026-11-03-design.md`, §5 and §6) that
the port lands; the rest is in the tree today.

## Load and enable

1. **File load**, in TOC order ([module-map.md](module-map.md)). Each seam leases its LibKa0s major or
   takes its degrade stub. `core/SkinSetup.lua` registers the skin owner at file scope;
   `core/OutfitterReborn.lua` calls `NewAddon(NS, "OutfitterReborn", "AceEvent-3.0", "AceTimer-3.0",
   "AceConsole-3.0")` and reclaims `NS.Print` from AceConsole's embed.
2. **`OnInitialize`** (`ADDON_LOADED`): `InitDB` (AceDB on the shared "Default" profile, the three
   profile callbacks), `RunMigrations`, `ApplySkinChoice`, `SyncEnabledHold` (so a disabled login
   registers nothing), `NS.Launcher:Register()`, `CreateOptionsPanel()` (eager categories, lazy
   bodies) and `NS.Slash:Register()` (`/of`, `/outfitter`).
3. **`OnEnable`** (`PLAYER_LOGIN`): the latch's stand-up registers the game events of every module
   (P4). Nothing is dispatched on the bus before this and the first LoadPass.
4. **First `PLAYER_ENTERING_WORLD`** (P4): a 1 s AceTimer runs `NS.Outfits.LoadPass()`, which seeds
   the built-in outfits once per character (guarded by `char.seeded`), repairs stale ids, mirrors the
   Equipment Manager, and ends by binding every trigger. Its finish sends `LEGACY_DETECTED` when the
   old Outfitter is loaded (warn only, no hold).

## The settings write seam

Every settings write, from the panel, `/of set`, a key binding or a reset, goes through
`NS.SetByPath(path, value)` (`settings/Schema.lua`): validate → store under the row's root →
the row's `onChange` → one `SETTINGS_CHANGED (path, value)` on the bus. A `instanceId` argument
forwards the same call to `NS.OutfitSchema`, whose announce calls `NS.Outfits.Changed(id, what)` and
so sends `OUTFIT_EDITED` instead ([schema.md](schema.md)).

A profile switch, copy or reset runs `NS.OnProfileChanged` (`core/Database.lua`): hide the skin
picker, apply the profile's skin, re-run the migrations over a reset profile, re-take the enabled hold,
`NS.ApplyProfile()` (bar, automatic changes), maybe show the skin picker, then `PROFILE_CHANGED`.
`db.char` is never touched.

## The stand-down latch

`core/LifecycleSetup.lua` holds one latch with two holds: `disabled` (persisted through `enabled`)
and `perf` (session, while a capture runs). Any hold stands the addon down: unregister every event and
message, cancel every timer, stand the bus down, and call each module's `Suspend()` in the design's
`MODULES` order (top to bottom; stand-up runs `Resume()` bottom to top and rebuilds from the current
settings). Hooks that cannot be unhooked check `NS.IsStoodDown()` first in their body. What survives
a stand-down: both chat commands, the dispatcher, the settings categories, AceDB with its callbacks and
the launcher (slash-commands-§7). Every refusal goes through `NS.StoodDownRefusal()`.

## The core mechanic (P4)

```
game event ─► NS.States / NS.PlayerState / zone producer ─► STATE_CHANGED (bus)
                                                         │
outfit's trigger target (NS.TriggerBinder) ◄─────────────┘
   gate (auto.enabled, trigger.disabled, combat) ─► condition(ctx, event, …) ─► verdict
                                                                              │
NS.Equip.Batch(function()  NS.Stack.Wear / Remove (layer, byTrigger)  end) ◄──┘
   └─ on close ─► E.Update(): gates (dead, casting, delay, throttle, combat)
                  ─► St.Compile() ─► Changes.Build(compiled, Inv.Cache()) ─► E.Execute(changes)
                  ─► STACK_CHANGED ─► window, bar, launcher tooltip
```

- **Triggers are data.** A descriptor in `defaults/Triggers.lua` names its events, its typed
  parameters, its icon and its condition (a family factory in `modules/Triggers_Families.lua`, or a
  bespoke function in one of the three `Triggers_Cond*.lua` files). An outfit stores only
  `trigger.id`, its flags and `triggerParams[id]`, so **behavior always comes from the shipped
  descriptor**: changing a trigger's code changes it for every existing outfit, with no saved-variable
  migration. (The fork's "preset scripts resolve live" rule, kept by construction.)
- **Binding.** Each bound outfit owns one AceEvent and AceTimer target (H14). Game events go through
  `NS.SafeRegisterEvent`; pseudo-events (a state changing, a tooltip shown, an outfit worn) arrive as
  bus messages. Rebinding after an edit is coalesced: one 0 s timer rebinds every edited outfit.
- **The verdict** is `(action, delay, layer, interrupt)`: wear, remove or nothing, optionally after a
  delay, into a layer, interrupting a cast. The binder applies it inside `NS.Equip.Batch`.
- **The stack** (`NS.Stack`) is an array of `{ id, layer }` entries, bottom to top, persisted in
  `char.stack`. Wearing a Complete outfit replaces the Complete entry; an Accessory stacks; a layer
  (`zone`, `shapeshift`) keeps its entries together, so leaving a zone removes exactly what it added.
- **The bracket cannot strand.** `NS.Equip.Batch(fn, ...)` runs `fn` under `xpcall`, always restores
  its depth counter, flushes at depth 0, and surfaces an error once per tag after the counter is
  restored. Stand-down zeroes it and the first `PLAYER_ENTERING_WORLD` zeroes a stranded one. This is
  the fix for the fork's stuck `EquipmentUpdateCount`.
- **Executing.** `E.Update` waits out death, casting, combat lockdown and a 1.5 s throttle, compiles
  the stack into one wanted item per slot, diffs it against the inventory cache into an ordered change
  list, and executes it with the equip sounds muted (`equip.muteSounds`) and the cursor always cleared.
- **Matching uses IDs, never names.** Maps by uiMapID or instance mapID, spells and auras by spellID,
  items by itemID, NPCs by creatureID, professions by skillLine. The documented exceptions are rows
  D3, D4, D8 and D10 in `ARCHITECTURE.md`.

## Zones (P4)

The fork kept five tables in step by hand (instance map IDs, the special-ID order, the event table,
the built-in events and the preset scripts), and missing one left a battleground outfit silently dead.
They collapse into one: `defaults/Zones.lua`'s rows (`id`, `kind`, `mapIDs`), in wear order, from
which `modules/States_Zone.lua` derives the map lookup, the order and the trigger rows at load. The
producer debounces the zone events, reads the instance type for the generic Battleground and Arena
states and `BY_MAP_ID` for the specific ones, and emits them in order inside one batch, so a specific
outfit is worn over the generic one. Map IDs come from `Map.db2` (wago.tools, `InstanceType` 3 and 4)
through `tools/gen-zones.lua`, never from memory.

## Event subscriptions

Today: `PLAYER_REGEN_ENABLED`, on `core/SecureQueue.lua`'s own target while a protected write
waits, and on `core/SkinSetup.lua`'s while the first-run skin picker's start waits out combat. Both are
dropped when their wait ends.

From the port, each on its module's own target, unregistered by its `Suspend()`:

| Module | Events |
|---|---|
| `PlayerState` | `PLAYER_REGEN_DISABLED`/`ENABLED`, `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`, the player's `UNIT_SPELLCAST_*`, `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` |
| `Inventory` | `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, `BANKFRAME_OPENED`/`CLOSED` |
| `Equip` | `PLAYER_ENTERING_WORLD`, `PLAYER_LEAVING_WORLD` |
| `EquipmentManager` | `EQUIPMENT_SETS_CHANGED`, `EQUIPMENT_SWAP_FINISHED` |
| `States` | the player's `UNIT_AURA`, `UPDATE_SHAPESHIFT_FORM(S)`, mount, swim and fall polling on a ticker |
| `States_Zone` | `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `PLAYER_ENTERING_WORLD` |
| `Dock` | `PLAYER_REGEN_DISABLED`/`ENABLED` (the window hides for combat) |
| each bound trigger | the events its descriptor names |
