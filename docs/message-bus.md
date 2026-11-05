# Message bus

The addon's internal messages (documentation-§3, Tier 2: more than ten messages). The bus is
LibKa0s-Bus, leased in `core/Bus.lua`; with the library absent a degraded arm sends AceEvent messages
and isolates each handler with `xpcall`.

## Rules

- **Declared once.** Every message is a key of `NS.MSG` in `core/Bus.lua`, with its wire name
  `Ka0s_OutfitterReborn_<Pascal of the key>` (matching `^Ka0s_OutfitterReborn_%u%a+$`).
- **One sender each.** The `Sender:` comment above each key names the one file that sends it, and
  `tests/test_bus.lua` holds every `NS.SendBus` call site in the tree to it (architecture-§4).
- **Sent through the seam.** `NS.SendBus(NS.MSG.KEY, …)`; received on a `NS.NewBusTarget()` target
  owned by the receiving module.
- **Isolated.** A handler that raises does not stop the others, and a handler's return value is never
  treated as an error.
- **Nothing before the LoadPass.** No message is dispatched before `OnEnable` and the first LoadPass.
- **Every key has a receiver.** A message that nothing registers for and the public API does not
  relay is dropped, not kept: `STATS_CHANGED` and `LEGACY_DETECTED` went that way. The Rebuild
  dialog reads `NS.Stats.Categories()` when it opens, and `/or diagnostics` reads
  `NS.State.legacyLoaded`.
- **Stand-down.** `NS.BusStandDown()` stops delivery while the addon is stood down;
  `NS.BusStandUp()` resumes it.

## Catalog

Each key's sender is its `Sender:` line in `core/Bus.lua`, which `tests/test_bus.lua` holds every call
site to. A receiver is a module that registers for the key on its own bus target; a surface that only
reads state when it is drawn (the launcher tooltip, `/or diagnostics`) is not one.

| Key | Sender | Payload | Receivers |
|---|---|---|---|
| `SETTINGS_CHANGED` | `settings/Schema.lua` (the announce) | `(path, value)`, settings paths only | Trigger binder (`auto.enabled`), Bar (`bar.*`), Window |
| `PROFILE_CHANGED` | `core/Database.lua` | `(key)` | Bar (rebuild and re-anchor from the new profile's `windows.bar`), Trigger binder (`SetActive` from the new profile's `auto.enabled`), Window (redraw: the trigger marks dim on `auto.enabled`) |
| `OUTFIT_ADDED` | `modules/Outfits.lua` | `(id)` | Window, Bar, Tooltips (cache wipe), Trigger binder (`Bind(id)`), API v1 |
| `OUTFIT_DELETED` | `modules/Outfits.lua` | `(id, name)` | Window, Bar, Tooltips (cache wipe), Trigger binder (unbind), API v1 |
| `OUTFIT_EDITED` | `modules/Outfits.lua`, also for the instance-row writes the `NS.OutfitSchema` announce makes | `(id, what)` | Window, Bar, Tooltips (cache wipe), slot checkboxes, Trigger binder (coalesced rebind on `what == "trigger"`), API v1 |
| `OUTFIT_RENAMED` | `modules/Outfits.lua` | `(id, oldName, newName)` | Window, Bar, Tooltips (cache wipe), API v1 |
| `OUTFIT_WORN` | `modules/OutfitStack.lua` | `(id, layer, byTrigger)` | Trigger binder (the `OUTFIT_WORN` pseudo-event), Window, Bar, API v1 |
| `OUTFIT_REMOVED` | `modules/OutfitStack.lua` | `(id, byTrigger)` | Trigger binder, Window, Bar, API v1 |
| `SELECTION_CHANGED` | `modules/OutfitStack.lua` | `(id or nil)` | Window, slot checkboxes |
| `STACK_CHANGED` | `modules/Equip.lua` (on the close of a bracket in which the stack moved: `E.Request` or `E.Touch` marked it; outside a bracket `E.Touch` sends at once) | none | Window (dirty, status cache kept) |
| `INVENTORY_CHANGED` | `modules/Inventory.lua` | `(equippedChanged, bagsChanged)` | Stack watch, Window, slot checkboxes, Tooltips (cache wipe) |
| `SWAP_COMPLETE` | `modules/OutfitStack_Watch.lua` | none | Equipment Manager mirror (pending save) |
| `EM_SYNCED` | `modules/EquipmentManager.lua` | none | Window |
| `OPTIMIZE_STARTED` | `modules/Optimize.lua` | `(job)` | Progress dialog |
| `OPTIMIZE_PROGRESS` | `modules/Optimize.lua` | `(job, noChangeCount, maxNoChange, bestText)` | Progress dialog |
| `OPTIMIZE_DONE` | `modules/Optimize.lua` | `(job, ok, reason)` | Progress dialog |
| `PLAYER_STATE_CHANGED` | `modules/PlayerState.lua` | `(key, value)`, key one of `combat`, `dead`, `casting`, `spec` | Bar (combat opacity), test mode. Spec triggers use `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, not this |
| `STATE_CHANGED` | `modules/States.lua` (`NS.States.Set`, shared by `States.lua` and `States_Zone.lua`) | `(stateId, isActive)` | Trigger binder |
| `AURAS_SCANNED` | `modules/States.lua` | none | Trigger binder (HAS_BUFF) |
| `TOOLTIP_SHOWN` | `modules/States.lua` | none | Trigger binder |
| `TOOLTIP_HIDDEN` | `modules/States.lua` | none | Trigger binder |
| `TRIGGERS_REBOUND` | `modules/Triggers_Binder.lua` | `(count)` | Window (row badges) |
| `PREVIEW_CHANGED` | `modules/Preview.lua` | `(active)` | Bar |

The four outfit-record messages are per kind on purpose: a receiver needs to know whether an outfit
was added, deleted, edited or renamed, and `NS.Outfits` stays their only sender.

The public API v1 (`modules/Api.lua`) relays the six `OUTFIT_*` messages to its subscribers as
`fn(event, id, ...)`: `event` is the catalog key, never the wire name, and `...` is the rest of
the bus payload above. While the addon is stood down, `WearOutfit` and
`RemoveOutfit` return false; the reads still answer.
