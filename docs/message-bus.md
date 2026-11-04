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
- **Nothing before the LoadPass.** No message is dispatched before `OnEnable` and the first LoadPass;
  `LEGACY_DETECTED` is held until the LoadPass finishes.
- **Stand-down.** `NS.BusStandDown()` stops delivery while the addon is stood down;
  `NS.BusStandUp()` resumes it.

## Catalog

Senders marked P4 arrive with the port; until then the key is declared and nothing sends it.

| Key | Sender | Payload | Receivers |
|---|---|---|---|
| `SETTINGS_CHANGED` | `settings/Schema.lua` (the announce) | `(path, value)`, settings paths only | Trigger binder (`auto.enabled`), Bar (`bar.*`), Window |
| `PROFILE_CHANGED` | `core/Database.lua` | `(key)` | Everything that re-applies a profile; the Trigger binder calls `SetActive` from the new profile's `auto.enabled` itself, so `NS.ApplyProfile` must not |
| `OUTFIT_ADDED` | `modules/Outfits.lua` (P4) | `(id)` | Window, Bar, Trigger binder (`Bind(id)`), API v1 |
| `OUTFIT_DELETED` | `modules/Outfits.lua` (P4) | `(id, name)` | Window, Bar, Trigger binder (unbind), API v1 |
| `OUTFIT_EDITED` | `modules/Outfits.lua` (P4), also for the instance-row writes the `NS.OutfitSchema` announce makes | `(id, what)` | Window, Bar, Tooltips, Trigger binder (coalesced rebind on `what == "trigger"`), API v1 |
| `OUTFIT_RENAMED` | `modules/Outfits.lua` (P4) | `(id, oldName, newName)` | Window, Bar, API v1 |
| `OUTFIT_WORN` | `modules/OutfitStack.lua` (P4) | `(id, layer, byTrigger)` | Trigger binder (the `OUTFIT_WORN` pseudo-event), Window, Bar, API v1 |
| `OUTFIT_REMOVED` | `modules/OutfitStack.lua` (P4) | `(id, byTrigger)` | Trigger binder, Window, Bar, API v1 |
| `SELECTION_CHANGED` | `modules/OutfitStack.lua` (P4) | `(id or nil)` | Window, slot checkboxes |
| `STACK_CHANGED` | `modules/Equip.lua` (P4, on the close of a bracket in which the stack moved: `E.Request` or `E.Touch` marked it; outside a bracket `E.Touch` sends at once) | none | Window (dirty, status cache kept), Bar, the launcher tooltip line |
| `INVENTORY_CHANGED` | `modules/Inventory.lua` (P4) | `(equippedChanged, bagsChanged)` | Stack watch, Window, the tooltip cache |
| `SWAP_COMPLETE` | `modules/OutfitStack_Watch.lua` (P4) | none | Equipment Manager mirror (pending save) |
| `EM_SYNCED` | `modules/EquipmentManager.lua` (P4) | none | Window |
| `STATS_CHANGED` | `modules/ItemStats.lua` (P4) | none | The Rebuild dialog's stat menus |
| `OPTIMIZE_STARTED` | `modules/Optimize.lua` (P4) | `(job)` | Progress dialog |
| `OPTIMIZE_PROGRESS` | `modules/Optimize.lua` (P4) | `(job, noChangeCount, maxNoChange, bestText)` | Progress dialog |
| `OPTIMIZE_DONE` | `modules/Optimize.lua` (P4) | `(job, ok, reason)` | Progress dialog |
| `PLAYER_STATE_CHANGED` | `modules/PlayerState.lua` (P4) | `(key, value)`, key one of `combat`, `dead`, `casting`, `spec` | Bar (combat opacity), test mode. Spec triggers use `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, not this |
| `STATE_CHANGED` | `modules/States.lua` (P4; `NS.States.Set`, shared by `States.lua` and `States_Zone.lua`) | `(stateId, isActive)` | Trigger binder |
| `AURAS_SCANNED` | `modules/States.lua` (P4) | none | Trigger binder (HAS_BUFF) |
| `TOOLTIP_SHOWN` | `modules/States.lua` (P4) | none | Trigger binder |
| `TOOLTIP_HIDDEN` | `modules/States.lua` (P4) | none | Trigger binder |
| `TRIGGERS_REBOUND` | `modules/Triggers_Binder.lua` (P4) | `(count)` | Window (row badges), Diagnostics |
| `PREVIEW_CHANGED` | `modules/Preview.lua` (P4) | `(active)` | Bar |
| `LEGACY_DETECTED` | `core/OutfitterReborn.lua` (from `NS.OnLoadPassDone`, once, when the legacy addon is loaded) | none | Diagnostics |

The four outfit-record messages are per kind on purpose: a receiver needs to know whether an outfit
was added, deleted, edited or renamed, and `NS.Outfits` stays their only sender.

The public API v1 (`modules/Api.lua`) relays the six `OUTFIT_*` messages to its subscribers as
`fn(event, id, ...)`: `event` is the catalog key, never the wire name, and `...` is the rest of
the bus payload above. While the addon is stood down, `WearOutfit` and
`RemoveOutfit` return false; the reads still answer.
