# Midnight quirks

Client-version behavior this addon works around (documentation-§3, Tier 2). The shims themselves are
in [compat-layer.md](compat-layer.md); this page says what about the client makes them necessary.

## Secret values (12.0)

Midnight returns **secret values** from many reads while a restriction is active: `UnitHealth`,
`UnitPower`, `UnitStat`, `UnitLevel`, item links in some contexts, aura fields, tooltip text, a
spellcast's spellID, the mouseover or target GUID and name. A secret cannot be compared, formatted,
concatenated, used in arithmetic or used as a table key; any of those raises.

The fork learned what that costs: a raise inside an event handler aborted it after it had called
`BeginEquipmentUpdate`, leaving the update counter above zero, which silently stopped every later
equipment update for the session. The rewrite closes it twice:

- **No module receives a raw value that might be secret.** Every such read happens in `core/Compat.lua`
  and passes through `core/Secrets.lua` (`NS.Secrets.PlainString`, `PlainNumber`, `PlainTruth`,
  `PlainEquals`, `UnsecretNumber`, `SafeIterate`) before it leaves, and the risky reads happen before
  any engine state moves. `tests/test_secrets.lua`'s seam scan fails a securable API named anywhere
  else.
- **The equipment bracket cannot strand** (`NS.Equip.Batch`, P4): an `xpcall` that always restores
  its depth, so even a raise inside a batch leaves updates running.

A secret value never matches and never counts as full: a trigger reading one sees "unknown", not a
match. A secret item link is treated as an empty slot. While the restriction is active every aura
state reads false, which gives an aura outfit a "not" edge at combat start (O28, ported as is).

## Restriction detection

`C_RestrictedActions.IsAddOnRestrictionActive` is read with the restriction type's name, never a raw
number, because the combat member of `Enum.AddOnRestrictionType` can be missing on some builds. Aura
getters raise while restricted, so the aura scan checks the restriction first and checks `IsSecret`
before nil.

## API ladders

- **Specs.** `C_SpecializationInfo` first, then the deprecated `GetSpecialization*` globals.
- **Secret tables.** `canaccesstable`, then `issecrettable`, then "readable".
- **Add-on queries.** `C_AddOns.IsAddOnLoaded` first.

## Zones

Zone names changed with every expansion and differ per locale, and the fork's battleground outfits
matched names through an API that is gone. Zones now match on uiMapID or instance mapID only, from one
table (`defaults/Zones.lua`, P4) regenerated from `Map.db2`, never from memory. Two quirks survive:

- Blizzard re-issues some battlegrounds under a second map ID (Alterac Valley's `30` and `2197`), so a
  row may list several.
- Brawl maps (`1170`, `1280`, `1691`, `2799`) give the generic Battleground state only.

Subzones have no ID route at all (no API exposes the current areaID), so IN_ZONES matches
`GetMinimapZoneText()` strings captured on the player's own client: deviation row D3.

## Tooltips

`TooltipDataProcessor` replaces tooltip hooking by scanning, and its line text can be secret. The
lockpicking and gathering triggers match tooltip lines against the client's own strings
(`LOCKED_WITH_SPELL`, `GetTradeSkillDisplayName`), recorded as rows D4 and D10; the trinket queue's
use-duration line has no GlobalString route yet (D8).
