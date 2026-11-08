# Outfitter Reborn on WoW Forever, step 1: design

Owner request, 2026-11-08: port Outfitter to WoW Forever next ("thats also very useful for me"), doing the deep
dive, spec and plan now and the build after the owner's usage resets. The evidence is the inventory beside this
file, `2026-11-08-forever-port-inventory.md`: every feature, trigger and Blizzard dependency checked against
Blizzard's Forever UI source (Gethe/wow-ui-source `forever` 1.60.1 (70862) against `live` 12.1.5 (70783)) and
Ketho/BlizzardInterfaceResources (`forever` 1.60.1 (70532), `live` 12.1.5 (70448)). Section numbers below refer to
that file.

## Headline (inventory §0)

- **Forever lacks no API Outfitter calls.** The kit's missing-globals scan with the forever set is clean in the
  addon's own code. All 41 `C_*` members it calls exist on Forever (the whole `C_EquipmentSet` set among them), and
  so do all 52 events it registers.
- **The work is in data and in Forever's redrawn character sheet.** That means a ranged slot, the sheet's
  renumbered sidebar tabs, the flyout drawer, and Retail-only triggers, zones, difficulties and stats.
- Two points in the step-5 classification are corrected:
  - `EquipmentManager_UnpackLocation` was already retired; `EquipmentManager_GetLocationData` replaced it, the same
    on both clients.
  - Forever's character sheet has its own Equipment Manager pane.

## Decisions for the owner (inventory §2)

Each carries the inventory's recommendation. **None is ruled yet:** the owner confirms or changes each before the
build starts, and the build follows the ruling recorded here.

| # | Decision | Recommendation |
|---|---|---|
| D1 | Ammo slot (0) | Not in step 1 |
| D2 | Ranged slot (18) | Yes, Forever only (a slot table per client) |
| D3 | PvP zones | The generic battleground row plus AV, WSG and AB on Forever; arenas and post-vanilla battlegrounds absent |
| D4 | Flyout drawer | Absent on Forever (Forever's flyouts open inward, with their own arrows) |
| D5 | Pet Battle and cooking-pet triggers | Absent on Forever |
| D6 | Content quest triggers | Absent on Forever |
| D7 | Instance difficulty | Open world, normal dungeon and 40-player raid on Forever; a 20-player raid row in step 2 |
| D8 | Character-sheet button | After the last shown sidebar tab, in Forever's atlas look, hidden while the pane is collapsed |
| D9 | Stats | Haste, Versatility and Mastery absent on Forever; vanilla stats (spell damage, healing, attack power, MP5) in step 2 |
| D10 | Spell ranks (forms, stealth) | Match by base spell if Forever supports it, else per-rank ID lists in step 2 |

## Design, step 1

Step 1 follows the ConsumableMaster port: Forever-compatible, Retail-only features absent, no Forever seed data yet.

1. **The port shape.**
   - The TOC's `## Interface: 120105, 16001`.
   - LibKa0s v1.94.0 re-vendored: the default skin per client (skinning-§2) and `Compat.UnitCharacterName` /
     `CharacterKey` / `RealmKey`.
   - Docs, both kit profiles in the gate, a WoW Forever smoke section.
   - The roster row flipped in WowAddonStandards.
2. **Data per client, picked once** by `Compat.ClientKey()` (clients-§5): the slot table (D1, D2), trigger rows and
   params (D5, D6), zone rows (D3), difficulty groups (D7) and stat set (D9). The engine loops over
   `ID.SLOT_NAMES` (about 30 call sites), so a per-client slot table needs no engine change.
3. **Features absent on Forever** (clients-§4): declared with `clients = { "retail" }` and gated at registration,
   never hidden. They are D3 to D6's triggers and rows and D9's stats.
4. **Behavior guards.**
   - `PS.CanDualWield2H`'s Titan's Grip rule (`PlayerState.lua:88-90`) applies only on Retail.
   - The `TARGET` trigger compares names through `Compat.UnitCharacterName` (client-quirks-§5; `Triggers_Params.lua:321`
     builds `First-Surname` today).
   - The bare `GetInventorySlotInfo` and `DoEmote` become `C_PaperDollInfo.GetInventorySlotInfo` and
     `C_ChatInfo.PerformEmote` first, on both clients.
   - The one strata read gets the secret guard.
5. **The character-sheet adapter (D8).** On Forever the sheet button anchors after the last shown sidebar tab,
   wears Forever's 42x42 atlas tab look, and hides while the right pane is collapsed (`Camelot/PaperDollFrame.lua`,
   `Camelot/CharacterFrame.lua`). Retail's placement is unchanged.
6. **The flyout drawer (D4)** is absent on Forever. Retail's is unchanged.

## Step 2 (later, its own spec)

- Spell-rank IDs or a base-spell matcher (D10).
- Forever's stat list and its optimizer weights (D9).
- Forever battleground map IDs, and a 20-player raid row (D7).
- Gathering and lockpicking tooltip wording, and the Cooking profession ID.
- A Forever battleground icon if file 1376041 is missing.
- Forever spec outfits, keyed by Forever's spec IDs.

## Before the build: in-game probes

Inventory §4 lists 27 probes (P1 to P26 and P14b), each a `/dump` or `/run` line under 255 characters. They cover
specs, forms, buffs, the ranged and ammo slots, containers and bank tabs, equipment sets, the sidebar tabs and
pane collapse, strata, item stat keys, tooltips, skills, professions, instances and difficulties, tracking,
companions, titles, icons, flyout directions and the deprecation CVar. Running them settles D1, D7, D8 and D10,
and the step-2 data.
