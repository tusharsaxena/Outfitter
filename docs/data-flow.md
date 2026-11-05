# Data flow

How Ka0s Outfitter Reborn actually works, as a pipeline (documentation-§3, Tier 1): load and enable,
the write seam, the stand-down latch, and the core mechanic, a trigger or a click in and an equipped
item out. It is the engineer counterpart of the README's "How outfit changes work"; the two describe one
pipeline and must not contradict each other.

The design behind it is `superpowers/specs/2026-11-03-design.md`, §5 and §6.

## Load and enable

1. **File load**, in TOC order ([module-map.md](module-map.md)). Each seam leases its LibKa0s major or
   takes its degrade stub. `core/SkinSetup.lua` registers the skin owner at file scope;
   `core/OutfitterReborn.lua` calls `NewAddon(NS, "OutfitterReborn", "AceEvent-3.0", "AceTimer-3.0",
   "AceConsole-3.0")` and reclaims `NS.Print` from AceConsole's embed.
2. **`OnInitialize`** (`ADDON_LOADED`): `InitDB` (AceDB on the shared "Default" profile, the three
   profile callbacks), `RunMigrations`, `ApplySkinChoice`, `SyncEnabledHold` (so a disabled login
   registers nothing), `NS.Launcher:Register()`, `CreateOptionsPanel()` (eager categories, lazy
   bodies) and `NS.Slash:Register()` (`/or`, `/outfitterreborn`).
3. **`OnEnable`** (`PLAYER_LOGIN`, `core/OutfitterReborn.lua`): the legacy guard first (a loaded
   original Outfitter sets `NS.State.legacyLoaded` and, standing up, prints one warning; warn only, no
   hold). Stood down, it stops there. Standing up, it calls the latch's own stand-up, `NS.StandUp()`
   (`core/LifecycleSetup.lua`): the bus replay (a no-op while never stood down),
   `NS.RegisterGameEvents()` (the host owns no game event; every one is a module's), then every
   module in `NS.LIFECYCLE_MODULES` resumed bottom to top (a name with no module table, or one
   without `Resume`, is skipped), so PlayerState, Inventory and the stack are up before the binder
   wears through them. The binder's resume installs its receivers only: it binds nothing until the first LoadPass has run (`/or auto on` before it records the setting and lets the
   LoadPass bind). Last, the first-run skin picker's 2 s AceTimer. Nothing is dispatched on the bus
   before this and the first LoadPass.
4. **First `PLAYER_ENTERING_WORLD`**: a 1 s AceTimer runs `NS.Outfits.LoadPass()`, which seeds
   the built-in outfits once per character (guarded by `char.seeded`), repairs stale ids, mirrors the
   Equipment Manager, and ends by binding every trigger. The first pass marks
   `NS.Outfits.FirstPassDone()`, which the public API and the trigger binder read. The old Outfitter
   being loaded changes nothing here (warn only, no hold).

## The settings write seam

Every settings write, from the panel, `/or set`, a key binding or a reset, goes through
`NS.SetByPath(path, value)` (`settings/Schema.lua`): validate → store under the row's root →
the row's `onChange` → one `SETTINGS_CHANGED (path, value)` on the bus. A `instanceId` argument
forwards the same call to `NS.OutfitSchema`, whose announce calls `NS.Outfits.Changed(id, what)` and
so sends `OUTFIT_EDITED` instead ([schema.md](schema.md)).

A profile switch, copy or reset runs `NS.OnProfileChanged` (`core/Database.lua`): hide the skin
picker, apply the profile's skin, re-run the migrations over a reset profile, re-take the enabled hold,
maybe show the skin picker, then `PROFILE_CHANGED`, on which the bar re-anchors, the trigger
binder re-reads `auto.enabled` and the window redraws its trigger marks ([profiles.md](profiles.md)).
`db.char` is never touched.

## The stand-down latch

`core/LifecycleSetup.lua` holds one latch with two holds: `disabled` (persisted through `enabled`)
and `perf` (session, while a capture runs). Any hold stands the addon down: unregister every event and
message, cancel every timer, stand the bus down, and call each module's `Suspend()` in the design's
`MODULES` order (top to bottom; stand-up runs `Resume()` bottom to top and rebuilds from the current
settings). Hooks that cannot be unhooked check `NS.IsStoodDown()` first in their body. What survives
a stand-down: both chat commands, the dispatcher, the settings categories, AceDB with its callbacks and
the launcher (slash-commands-§7). Every refusal goes through `NS.StoodDownRefusal()`.

## The core mechanic

```
game event ─► NS.States / NS.PlayerState / zone producer ─► STATE_CHANGED (bus)
                                                         │
outfit's trigger target (NS.TriggerBinder) ◄─────────────┘
   gate (auto.enabled, trigger.disabled, combat) ─► condition(ctx, event, …) ─► verdict
                                                                              │
NS.Equip.Batch(function()  NS.Stack.Wear / Remove (layer, byTrigger)  end) ◄──┘
   └─ on close ─► E.Update(): gates (dead, casting, delay, throttle, combat)
                  ─► St.Compile() ─► Changes.Build(compiled, Inv.Cache()) ─► E.Execute(changes)
                  ─► STACK_CHANGED (only when the stack moved) ─► window, Outfits broker
```

- **Triggers are data.** A descriptor in `defaults/Triggers.lua` names its events, its typed
  parameters, its icon and its condition (a family factory in `modules/Triggers_Families.lua`, or a
  bespoke function in one of the three `Triggers_Cond*.lua` files). An outfit stores only
  `trigger.id`, its flags and `triggerParams[id]`, so **behavior always comes from the shipped
  descriptor**: changing a trigger's code changes it for every existing outfit, with no saved-variable
  migration. (The fork's "preset scripts resolve live" rule, kept by construction.)
- **Binding.** Each bound outfit owns one AceEvent and AceTimer target (H14). Game events go through
  `NS.SafeRegisterEvent`; pseudo-events (a state changing, a tooltip shown, an outfit worn) arrive as
  bus messages. A `UNIT_*` event of a `unit = "player"` descriptor (Spellcast, the vehicle quests)
  rides the binder's one player unit-filter frame instead (`RegisterUnitEvent(event, "player")`,
  events-frames-taint-§1), which fans it out to the bound contexts, so no other unit's event enters
  Lua; the stand-down empties it. Rebinding after an edit is coalesced: one 0 s timer rebinds every edited outfit.
- **The verdict** is `(action, delay, layer, interrupt)`: wear, remove or nothing, optionally after a
  delay, into a layer, interrupting a cast. The binder applies it inside `NS.Equip.Batch`.
- **The stack** (`NS.Stack`) is an array of `{ id, layer }` entries, bottom to top, persisted in
  `char.stack`. Wearing a Complete outfit replaces the Complete entry; an Accessory stacks; a layer
  (`zone`, `shapeshift`) keeps its entries together, so leaving a zone removes exactly what it added.
- **The bracket cannot strand.** `NS.Equip.Batch(fn, ...)` runs `fn` under `xpcall`, always restores
  its depth counter, flushes at depth 0, and surfaces an error once per tag after the counter is
  restored. Stand-down zeroes it and the first `PLAYER_ENTERING_WORLD` zeroes a stranded one. This is
  the fix for the fork's stuck `EquipmentUpdateCount`. With up to three arguments the bracket
  allocates nothing (file-scope slots and trampolines), since the 0.5 s States poll opens one twice a
  second for the whole session ([`performance.md`](performance.md#measured-costs)).
- **Executing.** `E.Update` waits out death, casting, combat lockdown and a 1.5 s throttle, compiles
  the stack into one wanted item per slot, diffs it against the inventory cache into an ordered change
  list, and executes it with the equip sounds muted (`equip.muteSounds`) and the cursor always cleared.
- **The Outfits broker** (`modules/Broker.lua`) is one more reader of the stack: it redraws its text
  and icon from `NS.Stack.Top()` and `NS.OutfitIcon` on the stack and outfit messages, and its menu
  wears and removes through the same `NS.Stack.Wear` / `Remove` calls the window's rows make, so a
  wear asked for in combat is queued exactly as theirs is.
- **The sheet and the window.** `NS.Sheet` reads which character sheet is up (stock, EllesmereUI,
  ChonkyCharacterSheet) and where its button and right edge are; `NS.Dock` asks it on every sheet
  show and from its 0.05 s follow, places the sheet button in that sheet's tab look (Blizzard's
  sidebar tab on stock and Chonky, EllesmereUI's text tab; re-placed on the next frame when the
  sheet kind changes) and paints it selected while the window shows. The window's show and hide, and
  the sheet's hide, call `NS.QuickSlots.DrawerSync`, which, only while the window is visible, shows
  every slot's popout arrow, turns the left column's drawer outward, and lines a horizontal flyout up
  with its slot ([`taint.md`](taint.md)). The slot checkboxes restack from the same follow when the
  host's strata or level moves.
- **Test mode.** `NS.Preview` flips the session-only `NS.State.testMode` and sends `PREVIEW_CHANGED`.
  The bar draws `Preview.Source` (the samples of `defaults/PreviewOutfits.lua`) under its test strip;
  the dock clears the selection and calls `Dock.Refresh`, which shows the window with the samples
  under its own strip, beside the sheet when it is open or alone at `NS.Sheet.AloneCorner` when it is
  not, never in lockdown. X or Escape sets `testDismissed` for that test session. Every row action
  refuses a `preview:` id, so nothing reaches `NS.Outfits` or `NS.Stack`. Combat
  (`PLAYER_STATE_CHANGED "combat"`, before lockdown), its own switch, Reset all and the stand-down
  end it, and `PREVIEW_CHANGED false` puts both surfaces back on live data.
- **The outfit bar.** `NS.Bar` renders on a coalesced 0 s flag (outfit messages, a `bar.*` or Master
  `SETTINGS_CHANGED`, `PREVIEW_CHANGED`, `PROFILE_CHANGED`, a skin change): `NS.Bar.Layout` computes
  the geometry from the Layout and Icons rows, `Bar.PaintChrome` dresses the header band, plate,
  labels and test strip, and the pooled buttons are set from `NS.OutfitIcon`. `/or bar`, the *Toggle
  outfit bar* key and the header's close all write `bar.shown`, except in test mode, where they only
  dismiss the bar for that test session (`Bar.SetTestShown`, cleared on every `PREVIEW_CHANGED` and
  the stand-down) and `bar.shown` is never written; every path that hides the bar closes
  the outfit menu it opened (`NS.CloseMenuFrom`), and only that one.
- **Matching uses IDs, never names.** Maps by uiMapID or instance mapID, spells and auras by spellID,
  items by itemID, NPCs by creatureID, professions by skillLine. The documented exceptions are rows
  D3, D4, D8 and D10 in `ARCHITECTURE.md`.

## Zones

The fork kept five tables in step by hand (instance map IDs, the special-ID order, the event table,
the built-in events and the preset scripts), and missing one left a battleground outfit silently dead.
They collapse into one: `defaults/Zones.lua`'s rows (`id`, `kind`, `mapIDs`), in wear order, from
which `modules/States_Zone.lua` derives the map lookup, the order and the trigger rows at load. The
producer debounces the zone events, reads the instance type for the generic Battleground and Arena
states and `BY_MAP_ID` for the specific ones, and emits them in order inside one batch, so a specific
outfit is worn over the generic one. Map IDs come from `Map.db2` (wago.tools, `InstanceType` 3 and 4)
through `tools/gen-zones.lua`, never from memory.

## Event subscriptions

Every game event is registered through `NS.SafeRegisterEvent` (or `NS.SafeRegisterUnitEvent` for a
player-only unit event), on the owning module's own target, in its `Resume()`, and dropped by its
`Suspend()`. A name the client rejects lands in `NS.rejectedEvents` and `/or diagnostics`.

| Module | Events |
|---|---|
| `PlayerState` | `PLAYER_REGEN_DISABLED`/`ENABLED`, `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`, `PLAYER_TALENT_UPDATE`, `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_ENTERING_WORLD`; the player's `UNIT_SPELLCAST_*` on a unit-filtered frame |
| `Inventory` | `BAG_UPDATE`, `BAG_UPDATE_DELAYED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYER_ENTERING_WORLD`, `GET_ITEM_INFO_RECEIVED`, `BANKFRAME_OPENED`/`CLOSED`, `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE`; the player's `UNIT_INVENTORY_CHANGED` |
| `Equip` | `PLAYER_ENTERING_WORLD`, `PLAYER_LEAVING_WORLD` |
| `Outfits_Seed` | `PLAYER_ENTERING_WORLD` (arms the first LoadPass) |
| `EquipmentManager` | `EQUIPMENT_SETS_CHANGED` |
| `ItemStats_Sources` | `ADDON_LOADED` (Pawn or WeightsWatcher arriving late) |
| `States` | `PLAYER_REGEN_ENABLED`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`, `PLAYER_ENTERING_WORLD`; the player's `UNIT_AURA`; while Dining is watched, the player's `UNIT_HEALTH` and `UNIT_POWER_UPDATE`; while Spirit is watched, the player's `UNIT_SPELLCAST_SENT` and `UNIT_POWER_UPDATE`; a 0.5 s mounted and swimming poll on an AceTimer |
| `States_Zone` | `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `PLAYER_ENTERING_WORLD` |
| `Dock` | `PLAYER_REGEN_DISABLED`/`ENABLED` (the window hides for combat) |
| `Bar` | `PET_BATTLE_OPENING_START`, `PET_BATTLE_OVER` |
| `Triggers_Binder` | Each bound trigger's descriptor events, on the outfit's own target; a `unit = "player"` descriptor's `UNIT_*` events on the binder's one unit-filtered frame |
| `core/SecureQueue.lua` | `PLAYER_REGEN_ENABLED`, only while a protected write waits out lockdown |
| `core/SkinSetup.lua` | `PLAYER_REGEN_ENABLED`, only while the first-run skin picker's start waits out combat |

The icon browser (Change icon..., the library's, modules/IconBrowserSetup.lua) registers nothing: it is
a modal whose catcher swallows outside clicks, and it closes from the window's `OnHide` and the
stand-down.
