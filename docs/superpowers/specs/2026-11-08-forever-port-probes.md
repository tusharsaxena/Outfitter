# Outfitter on WoW Forever: the owner's probe results (2026-11-08)

The owner ran the inventory's §4 probes on Forever (1.60.1, build 70862), as Traxex Silentshot, a level-18 Night
Elf Hunter with a pet out and a gun equipped. Output below is verbatim from chat, trimmed only of the echoed
command lines.

## What it settles

| Probe | Finding | Feeds |
|---|---|---|
| P1, P2 | **One specialization per class on Forever.** `GetNumSpecializations()` = 1. The active spec is 1485, "Hunter", DAMAGER, primary stat 4. Specs 2 and 3 answer empty | The seeded per-spec outfits become one per class on Forever; spec triggers have one spec to match |
| P23 | `[spec:1]` works in a macro conditional | Spec conditions work as on Retail |
| P5, P6 | `RangedSlot` = **18**, `AmmoSlot` = **0**. `IsRangedSlotShown()`, `AmmoNeeded()` and `UnitUsesAmmo("player")` are all true. A gun is `INVTYPE_RANGEDRIGHT` (class 2, subclass 3) | D1, D2: both slots are real; the ranged slot takes RANGED/RANGEDRIGHT/THROWN/RELIC |
| P11 | An Equipment Manager set records slot 18 (`1048594`), so Blizzard's sets include the ranged slot. Ammo (slot 0) is not in the saved set | D1/D2 and the Equipment Manager sync: ranged rides the set's location keys; ammo needs Outfitter's own handling |
| P10 | `CanUseEquipmentSets()` true; one set, ID 0 | The Equipment Manager sync works |
| P7 | `NUM_BAG_SLOTS` 4, `NUM_REAGENTBAG_SLOTS` 1, `NUM_TOTAL_EQUIPPED_BAG_SLOTS` 5, `NUM_CHARACTER_BANK_SLOTS` 9, `ITEM_INVENTORY_BANK_BAG_OFFSET` 5 | Inventory and bank walks |
| P8, P9 | **Forever's bank uses the modern tab model:** container 6 is "Tab 1" (48 slots, `bankType` 0), with up to 9 tabs. Container -1 has 32 slots and the backpack 20. `ShouldUsePlayerBagsInBank()` is true | The bank module reads tabs as on Retail; Retail's Warband tabs stay absent |
| P14 | Item stat keys are Retail's style: `ITEM_MOD_STAMINA_SHORT`, `ITEM_MOD_AGILITY_SHORT`, `RESISTANCE0_NAME` (armor) | D9: the vanilla bonus keys (spell damage, hit, defense, MP5) are still unseen; that needs an item carrying them |
| P15 | Herbalism 182, Mining 186, Skinning 393, Lockpicking 633 all have names | The gathering triggers |
| P16 | Cooking is `professionID` 185, `profession` 5 | The Cooking trigger |
| P14b | A skinnable corpse's tooltip carries a gray (0.5, 0.5, 0.5) `Skinnable` line | The gathering trigger's tooltip test |
| P19 | **No Find Fish tracking.** The types are Track Beasts, Track Humanoids and Track Undead, plus town-service types | The Find Fish param stays absent |
| P20 | **Companions exist:** `C_PetJournal` answers 4 pets, with Mini Diablo summoned | The Companion feature works on Forever (D5 drops only the Pet Battle trigger and the Retail cooking pets) |
| P22 | 111 titles; none current | The Titles feature works |
| P26 | `loadDeprecationFallbacks` = 1; bare `GetInventorySlotInfo` and `DoEmote` exist | Works today; the guards still move to the `C_*` calls first |
| P4 | Aspect of the Hawk 13165, **Shadowmeld 20580** (Retail's is 58984) | D10: aura IDs differ per client, so per-client ID lists are needed at least for Shadowmeld |
| P12, P13 | Sidebar tabs are 42 px. Tab4 (Pet) shows with a pet out. Right pane expanded; frame width 631. `CharacterFrame` is MEDIUM, level 1; slot buttons are level 101 | The sheet adapter and the strata guard |
| P25 | Flyouts open by slot: Head RIGHT, Hands LEFT, Main Hand UP, Ranged UP; `EquipmentFlyoutFrame.NavigationFrame` exists | D4: the adapted drawer follows each slot's direction |
| P27 | The outer strip's `CharacterFrameModeTab6` is 55 px wide, anchored TOPLEFT and shown; `CharacterFrame.ModeTabs` is 384 tall | D8: the button stacks below tab 6 at the strip's spacing |

## Still open (the owner, later)

- **P21, the spec and talent events:** couldn't change talents at the time.
- **P17, P18, the instances:** WSG, AB and AV map IDs, a dungeon, Molten Core, and Zul'Gurub or AQ20 for the
  20-player difficulty ID that D7 needs.
- **P3, the shapeshift forms:** no druid at 40+ and no rogue yet. This, and whether ranks map to a base spell, settle
  D10.
- **P12 with the pane collapsed:** only the expanded run was taken.
- **P24, the icon test:** whether any of the five icons drew green or black was not reported.
- **P14 for the vanilla bonus keys:** an item with spell damage, healing, hit, defense or MP5 is needed (D9).

## Raw output

Not kept verbatim. Every returned value that bears on the port is transcribed into the table above, from the
owner's pasted chat log of 2026-11-08, 15:59 to 16:07.
