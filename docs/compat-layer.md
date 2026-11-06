# Compat layer

The addon's own compat family (documentation-§3, Tier 2; compat). It is one file, `core/Compat.lua`,
publishing `NS.Compat`. The trigger counts its hand-written shims:

```
cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'
```

which answers **74** (three or more fires the trigger). The members LibKa0s-Compat-1.0
supplies are documented by the library and are not repeated here beyond naming which ones this addon
routes.

## The rules

- **No other file names a version-variant or optional client API.** A module calls `NS.Compat`; the
  client global is read here, bare and at call time, so a client (or the harness's mock) that adds an
  API later is seen, and a suite can take a rung away after load and watch the ladder move.
- **Every member answers plain-or-nil.** A read that may come back secret goes through `NS.Secrets`
  before it leaves this file, so no module ever holds a raw value that might be secret.
- **`NS.Secrets` is reached at call time only.** `core/Secrets.lua` binds this file's guards at file
  scope, so Compat loads first, and a file-scope capture of `NS.Secrets` here would read nil
  (`test_loadorder` pins it).
- **One file.** The family stays one file until `cat core/Compat*.lua | wc -l` would pass 1000
  (compat; design C39). With the engine's accessors it is 956 lines as measured on 2026-11-06, close to that budget. A split by size alone,
  or an underscore name such as `Compat_Items`, is outside the family pattern.

## Routed from LibKa0s-Compat-1.0

Each with a library-absent stub of the addon's own.

| Member | Answers | Stub when the library is missing |
|---|---|---|
| `Compat.IsSecret(v)` | Whether a value is secret | `issecretvalue`, read bare; `false` only on a client with no secrets system |
| `Compat.CanAccess(v)` | Whether a value may be read | `canaccessvalue`, else `not IsSecret(v)` |
| `Compat.IsSafeKey(v)` | Whether a value may index a table | The same two client detectors |
| `Compat.GetSpecialization()` | The active spec index | `C_SpecializationInfo` first, then the deprecated global |
| `Compat.GetSpecializationInfo(index)` | The spec's fields | The same ladder |

The secret guards' stub is a deliberate duplication: "the library is missing" is not "the client has
no secrets system", and a stub answering `IsSecret → false` on a 12.x client would send a secret into
a comparison mid-swap, on exactly the degraded path the stub exists to survive.

## Hand-written shims

| Shim | Answers |
|---|---|
| `Compat.CanAccessTable(t)` | `canaccesstable`, then `issecrettable`, then "readable" |
| `Compat.NumSpecializations()` | The class's spec count, 0 when unknown |
| `Compat.PlayerClass()` | The class token (`"WARRIOR"`), or nil |
| `Compat.PlayerFaction()` | `UnitFactionGroup`'s **first** return (`"Horde"`, the English token), or nil (H10) |
| `Compat.UnitLevel(unit)` | A plain level, or nil (nil means "do not filter") |
| `Compat.IsDeadOrGhost(unit)` | `true`/`false`, or nil when unreadable |
| `Compat.InCombatLockdown()` | `true`/`false` |
| `Compat.GetCVar(name)` | A plain string, or nil |
| `Compat.SetCVar(name, value)` | `true` when the client took the write |
| `Compat.GetTime()` | The client clock, 0 without one |
| `Compat.IsAddOnLoaded(name)` | `true`/`false` (`C_AddOns` first) |

## The engine's accessors

The engine's whole view of the client (design §5.13). Reads answer plain-or-nil; writes answer `true`
when the client call was made and `false` when the API is absent. A **location** is the addon's own
plain table, `{ bag = bagID, slot = index }` or `{ slotID = inventorySlotID }`; only this file builds the
client's `ItemLocation` from one. The client APIs still to be confirmed in game (O17) are `pcall`'d,
and a raise reads as `nil` ("unknown"), which sends the caller to its tooltip fallback.

| Group | Members | No-answer value |
|---|---|---|
| Links and slots | `ContainerItemLink(bag, slot)`, `InventoryItemLink(slotID)`, `InventoryItemID(slotID)`, `InventorySlotID(slotName)` | `nil` (a secret link reads as an empty slot) |
| Item info | `ItemInfo(item)` → name, quality, level, minLevel, bindType; `ItemInfoInstant(item)` → id, invType, icon, classID, subclassID; `DetailedItemLevel`, `ItemStats` (a secret key or value dropped), `ItemIcon`, `ItemSpell` → name, spellID; `ItemFamily`; `ItemUpgradeInfo` (the four numeric track fields) | `nil`; a sealed argument is refused before the client is asked |
| Cooldowns | `ContainerItemCooldown(bag, slot)`, `InventoryItemCooldown(slotID)` → start, duration, enabled (1/0 normalized) | each part `nil` |
| By location | `IsBound(loc)`, `IsWarboundUntilEquip(loc)`, `CanUpgradeItem(loc)` (checks `DoesItemExist` first), `AzeritePowers(loc)` (sorted selected ids); `ItemUniqueness(id)` → `{ unique, categoryID, count }`; `CanUseItem(id)` | `nil` |
| Tooltip data | `TooltipLines(loc or link)` → `{ {text, r, g, b} }`, a secret line skipped; `TooltipInventoryUnit(tooltip)` (O41: `"?"` when an inventory tooltip's unit is unreadable) | `{}` / `nil` |
| Pets and hooks | `SummonedPetGUID()`, `PetGUIDBySpecies(id)` (owned pets only; a secret GUID is never a handle), `SummonPet(guid)`, `HookPetSummon(fn)`, `HookCompare(fn)` | `nil` / `false` |
| Equipment Manager | `EMSetIDs()` (bounded at 512, a secret id skipped), `EMSetInfo(id)`, `EMLocations(id)`, `EMIgnoredSlots(id)`, `EMLocation(location)` (alias `FlyoutLocationData`), `EMSetID(name)`, `EMNumSets()`, `EMMaxSets()`; writes `EMCreateSet`, `EMSaveSet`, `EMModifySet`, `EMDeleteSet`, `EMClearIgnored`, `EMIgnoreSlot(slotID, ignore)` | `{}` (the zero-sets path, Q8), `nil`, `0`, `10`, `false` |
| Titles | `KnownTitles()` → `{ {id, name} }`, sorted case-insensitively, a secret name skipped; `SetCurrentTitle(id)` | `{}` / `false` |
| Bank | `BankBagIDs()` (the character bank tabs, else the bank and its bags; never the warband tabs, O19), `IsBankerInteraction(type)` | `{}` / `false` |
| Containers and cursor | `ContainerNumSlots`, `ContainerNumFreeSlots` → free, family; `ContainerIDToInventoryID`; `PickupContainerItem`, `PickupInventoryItem`, `PickupItemLocation(loc)`, `UseContainerItem`, `ShowContainerSellCursor`, `EquipCursorItem`, `ClearCursor` | `0` / `nil` / `false` |
| Other | `PawnVisibleScales()`, `PawnItemValue(link, scale)`, `CanDualWield()`, `BitAnd(a, b)` (plain arithmetic, no `bit` library) | `{}` / `nil` / `false` / `0` |

`test_secrets` pins each group: plain answers through, secret answers out as their no-answer value,
and every member's answer with its API absent.
