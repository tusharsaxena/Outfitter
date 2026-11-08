# OutfitterReborn on WoW Forever: a feature-by-feature compatibility inventory

Read-only research, 2026-11-08. Repo: `../OutfitterReborn` at master `5a5f6a8` (clean), TOC `## Interface: 120105`,
LibKa0s v1.93.0 vendored, AceDB-3.0 minor 40.

Sources and short names used below:

- **F-UI** = Blizzard UI source, Forever 1.60.1 build 70862 (`scratchpad/uisrc/forever/Interface/AddOns/...`).
  **L-UI** = live 12.1.5 build 70783 (`scratchpad/uisrc/live/...`).
- **F-BIR / L-BIR** = Ketho BlizzardInterfaceResources `Resources/` per client (`GlobalAPI.lua`, `Events.lua`,
  `LuaEnum.lua`, `CVars.lua`, `AtlasInfo.lua`, `GlobalStrings/enUS.lua`).
- On Forever the game type is `camelot`, a member of the `mainline` family. A TOC line
  `[AllowLoadGameType mainline] [ExcludeLoadGameType camelot]` therefore means "Retail only", and `[Game]\X` resolves
  to `Camelot\X` (for example `Blizzard_UIPanels_Game.toc:44-57`).

## 0. Headline findings

1. **No missing API.** The kit scanner (`tests/_kit/client_globals.lua`, both sets, `tools/` skipped) finds no call
   in the addon's own code that Forever lacks. The only hits are AceGUI's `GetSpellInfo` else-branch, which the kit
   allow-lists already. I also cross-checked every `C_*` member the addon reaches, including those it calls by name
   through `member(C_X, "Y")` in `core/Compat.lua`: all 41 are present in F-BIR `GlobalAPI.lua`, `C_EquipmentSet.*`
   included. So is every event the addon names (52 events): there are **0** missing from F-BIR `Events.lua`.
   The classification's "`EquipmentManager_UnpackLocation` gone" is stale: the addon already retired it
   (`core/Compat.lua:716-728` uses `EquipmentManager_GetLocationData`, which is byte-identical in F-UI and L-UI
   `Blizzard_FrameXML/Shared/EquipmentManager.lua`). "`C_EquipmentSet` unverified" is answered: all 23 members
   exist (F-BIR `GlobalAPI.lua:1623-1645`), and Forever's sheet has its own Equipment Manager pane
   (F-UI `Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:470-560`).
2. **The real gap is data, and the biggest piece is the slot table.** `defaults/Items.lua:15-21` has 18 slots and
   no `RangedSlot` (18) or `AmmoSlot` (0). `defaults/Items.lua:65-68` maps `INVTYPE_RANGED/RANGEDRIGHT/THROWN/RELIC`
   to `MainHandSlot` ("since Legion"). Forever's sheet has `CharacterRangedSlot` and `CharacterAmmoSlot`
   (F-UI `Camelot/PaperDollFrame.xml:868-873`). `INVSLOT_RANGED = 18` sits in `INVSLOTS_EQUIPABLE_IN_COMBAT`
   (F-UI `Blizzard_FrameXMLBase/Constants.lua:153-161`). Without the slot, bows, guns, crossbows, wands, thrown
   weapons and relics (librams, idols, totems) are never part of an outfit. The planner would also try to put them
   in the main hand. Every engine loop iterates `ID.SLOT_NAMES` (about 30 call sites), so the fix is a per-client
   slot table, not engine surgery.
3. **The character sheet is redrawn, and the sidebar tab IDs are permuted.** On Forever, Tab1 = Stats, **Tab2 =
   Equipment Manager**, **Tab3 = Titles** and Tab4 = Pet, shown only with a pet (F-UI
   `Camelot/PaperDollFrame.lua:94-105`, `:3400-3431`). On Retail, Tab3 = Equipment Manager
   (L-UI `Mainline/PaperDollFrame.lua:128-136`). The tabs are 42x42 atlas CheckButtons at the TOP of a right pane
   the player can collapse (F-UI `Camelot/PaperDollFrame.xml:372-432`, `Camelot/CharacterFrame.lua:263-300`).
   The sheet button anchors to Tab3 and wears Retail's tab art, so on Forever it lands after Titles, overlaps the
   pet tab, wears the wrong look, and floats when the pane is collapsed.
4. **The flyout "drawer" is Retail geometry.** Forever's flyouts open by `flyoutDirection` KeyValues: the left
   column opens RIGHT, the right column opens LEFT and the weapons open UP, all inward. Their arrows are rotated
   atlases (F-UI `Camelot/PaperDollFrame.xml:138,151,164`, `Blizzard_FrameXML/Camelot/EquipmentFlyout.lua:687-760`).
   `EquipmentFlyoutPopoutButton_SetReversed` is gone (the kit's forever `removed` list). The drawer's
   `SetTexCoord` arrow mirroring and its slot-relative re-anchoring (`modules/QuickSlots.lua:176-262`) would garble
   the arrows and push right-column flyouts under the docked window.
5. **Three Retail rules leak into behavior.** (a) `PS.CanDualWield2H()` = Warrior and spec index 2
   (`modules/PlayerState.lua:88-90`) is Titan's Grip. Vanilla has none, but Forever's Warrior spec 2 is presumably
   Fury, so the planner would allow two-handers in the off hand (guess: the spec order). (b) Druid, rogue and night
   elf state IDs are rank-1 or Retail spell IDs, but Forever has spell ranks (`C_SpellBook.IsSpellBookItemLowRank`,
   F-BIR added). (c) The `TARGET` trigger stores `First-Surname` as if the surname were a realm
   (`modules/Triggers_Params.lua:321`).

## 1. Feature inventory

Verdict key: **OK** works as is · **GUARD** needs a guard or adapter (what) · **ABSENT** Retail-only, absent on
Forever (clients-§4: not built, not hidden) · **CHECK** unknown, needs an in-game check (probe number in §4) ·
**SEED** carries Retail-specific seed data that needs a Forever list (step 2).

### 1.1 Character-sheet tab and Dock (`modules/Dock.lua`, `modules/Sheet.lua`)

Uses `PaperDollFrame` (OnShow/OnHide hooks, `Dock.lua:581-582`), `CharacterFrame` (button parent,
`Dock.lua:554`), `CharacterFrameCloseButton` (level base, `Dock.lua:469-470`; fallback anchor, `Sheet.lua:113`),
`PaperDollSidebarTab3` (`Sheet.lua:41`, `:107-112`, `:123-131`), `ToggleCharacter("PaperDollFrame")`
(`Dock.lua:426`, `:449`), `UISpecialFrames` (`Dock.lua:402`), `GameTooltip`, the texture
`Interface\PaperDollInfoFrame\PaperDollSidebarTabs` with Retail coords (`Dock.lua:273-311`), and
`IsAddOnLoaded("EllesmereUIBlizzardSkin"/"ChonkyCharacterSheet")`.

Each of these exists on Forever: `CharacterFrame` (F-UI `Camelot/CharacterFrame.xml:403`, now
`PortraitFrameBaseTemplate`, with `$parentCloseButton` at `:405`), `PaperDollFrame` (`Camelot/PaperDollFrame.xml:403`),
`PaperDollSidebarTab1-4` (`:405-432`) and `ToggleCharacter` (`Camelot/CharacterFrame.lua:1`).

Where behavior differs:

- Tab3 is Titles, not the Equipment Manager (see §0.3). The button lands after Titles. That is still the end of
  the row without a pet, but it overlaps **Tab4 (Pet)** for any player with a pet UI
  (`PaperDollFrame_UpdateSidebarTabLayout`, `Camelot/PaperDollFrame.lua:3400-3431`).
- Forever's tabs are 42x42 with a CENTER-anchored icon and atlases `UI-Character-Info-StatTab` and `-Selected`.
  F-BIR `AtlasInfo.lua` has both, L-BIR has neither. `Sheet.lua` reads the size live, so that is fine, and
  `TabIconOffset` falls back to the template's offsets because the icon is not BOTTOM-anchored. The hand-built
  Retail art (50x43 TabBg, coords) will not match: this is cosmetic.
- **The right pane can be collapsed** (CVar `characterFrameCollapsed`, F-BIR `CVars.lua` only;
  `CharacterFrameMixin:SetRightPaneCollapsed`, `Camelot/CharacterFrame.lua:279-300`). Collapsing hides
  `PaperDollSidebarTabs` (`Camelot/PaperDollFrame.lua:1524`), but the button is parented to `CharacterFrame`, so it
  stays shown at the hidden tab's position, outside the 398 px collapsed frame.
- The sheet width is 631 px expanded and 398 px collapsed (`Camelot/CharacterFrameConstants.lua:4-8`). The dock
  follows `CharacterFrame:GetRight()` every 0.05 s, so the window re-docks on collapse. OK.
- `CHARACTERFRAME_SUBFRAMES` adds `PVPRankFrame` and `SkillsFrame` (`Camelot/CharacterFrameConstants.lua:1`). They
  hide `PaperDollFrame` the way Reputation does, so the OnHide path covers them. OK.
- EllesmereUI and Chonky are Retail addons. On Forever the kind is always `stock`. OK.

Verdict: **GUARD**. Anchor to the last **shown** sidebar tab (or to the Equipment Manager tab's row end), not to
Tab3. Hide the button while `CharacterFrame:IsRightPaneCollapsed()` and re-place it on the pane's show and hide
(hook `PaperDollSidebarTabs` OnShow and OnHide, or `CharacterFrame.SetRightPaneCollapsed`). Give it a Forever look
from the two atlases, a check-button style. Then **CHECK** (P12, P13).

### 1.2 Slot checkboxes (`modules/SlotEnables.lua`)

Uses the 18 `Character<Slot>` buttons (`:145-158`), `GetFrameStrata` and levels walked under `CharacterFrame`
(`:105`, `:144`, `:177`, `:185-213`), `EquipmentFlyoutFrame` (`:166`, `:347-350`), and the `COLUMN` map (`:56-63`).

- All 18 slot button names exist on Forever (F-UI `Camelot/PaperDollFrame.xml:779-868`), plus Ranged (`:868`) and
  Ammo (`:873`).
- Forever puts `PaperDollLevelInfo` at frameStrata HIGH, level 520 (`:575`), and the side panes at HIGH
  (`Camelot/CharacterFrame.xml:317`). The host strata is the max of `CharacterFrame` and the slot buttons, so a HIGH
  child does not lift it. The level search counts only host-strata frames, so this is probably fine, but it is
  unverified.

Verdict: **GUARD** (the slot table, §1.6: add `RangedSlot = "BOTTOM"`, and `AmmoSlot` if adopted) and **CHECK**
(P13: boxes above the slots, under the flyout rule, and not poking through other windows).

### 1.3 Outfit window (`modules/Window*.lua`, `Dialog_*.lua`, `UIDialogs.lua`, `OutfitMenu.lua`)

Uses `CreateFrame` with `SecureActionButtonTemplate` and `BackdropTemplate` (both in F-BIR `Templates.lua`),
`GameTooltip:SetBagItem` and `:SetInventoryItem` (`Window_Rows.lua:197-200`), `UISpecialFrames`
(`UIDialogs.lua:176`), and LibKa0s widgets. The secure row buttons only set `target-bag` and `target-slot`
(`Window_Rows.lua:95-97`). The window is parented to UIParent and docked (§1.1).

Verdict: **OK**. The slot lists in `Dialog_Outfit.lua:120` and `Dialog_TriggerFields.lua:181` follow `SLOT_NAMES`,
so they pick up Ranged with §1.6.

### 1.4 Outfit bar (`modules/Bar*.lua`), broker (`modules/Broker.lua`), minimap launcher (`core/LauncherSetup.lua`), keybindings (`Bindings.xml`, `core/LauncherSetup.lua:95-113`)

Uses LibDataBroker, LibDBIcon (through the LibKa0s launcher), `C_Spell.GetSpellTexture` (`Bar_Buttons.lua:82`,
guarded), `CLICK` bindings to named buttons, and `BINDING_HEADER_*` / `BINDING_NAME_*` globals.

On Forever, the launcher, minimap button and settings panel pattern passed smoke in other LibKa0s addons
(AbsorbTracker FOREVER-5/-10, PanelMaster FOREVER-10, ConsumableMaster FOREVER-13/-16, in each repo's
`docs/smoke-tests.md`). The Forever minimap and addon compartment are Camelot files that load
(`Blizzard_Minimap.toc`).

Verdict: **OK**. The trigger default icons need a check (§1.20, P24).

### 1.5 Equipment Manager sync (`modules/EquipmentManager.lua`, `core/Compat.lua:651-766`)

Uses `C_EquipmentSet.GetEquipmentSetIDs / GetEquipmentSetInfo / GetItemLocations / GetIgnoredSlots /
CreateEquipmentSet / SaveEquipmentSet / ModifyEquipmentSet / DeleteEquipmentSet / ClearIgnoredSlotsForSave /
IgnoreSlotForSave / UnignoreSlotForSave / GetEquipmentSetID / GetNumEquipmentSets`, `EquipmentManager_GetLocationData`,
`MAX_EQUIPMENT_SETS_PER_PLAYER` and the event `EQUIPMENT_SETS_CHANGED`.

- All present (F-BIR `GlobalAPI.lua:1623-1645`). `MAX_EQUIPMENT_SETS_PER_PLAYER = 10` on both clients
  (F-UI `Blizzard_FrameXMLBase/Constants.lua:182`).
- Forever's sheet has the pane, with Equip, Save and New Set (F-UI `Camelot/PaperDollFrame.xml:470-560`), and the
  pane calls `C_EquipmentSet.*` the way Retail's does (`Camelot/PaperDollFrame.lua:3156-3252`).
- `slotTable` walks slots 1..19 (`Compat.lua:657-668`), so it already covers 18 (Ranged), but `slotMap` is built
  from `SLOT_NAMES` (`EquipmentManager.lua:93-99`), so a set's ranged item is dropped today. Slot 0 (Ammo) is never
  walked.

Verdict: **GUARD** through §1.6 (slot table; ammo only if adopted). **CHECK** P10/P11: that the client allows sets
on Forever (`CanUseEquipmentSets`), and whether `GetItemLocations` keys slot 0.

### 1.6 Equip engine and moves (`modules/Equip.lua`, `Equip_Changes.lua`, `Equip_Moves.lua`, `defaults/Items.lua`)

Uses `PickupInventoryItem`, `EquipCursorItem`, `C_Container.PickupContainerItem / UseContainerItem`, `ClearCursor`,
`CursorHasItem`, `GetCursorInfo`, `GetInventorySlotInfo` (`Compat.lua:342-347`), the CVar `Sound_EnableSFX`
(`Equip.lua:38`, `:288-298`, present in F-BIR `CVars.lua`), `CanDualWield` and `InCombatLockdown`.

- APIs: all present. `GetInventorySlotInfo` is a deprecation shim on **both** clients
  (`Deprecated_PaperDoll/Deprecated_PaperDoll.lua:4-8`), loaded only under CVar `loadDeprecationFallbacks`, which
  defaults to `"1"` on both (F-BIR `CVars.lua:1016`). Hardening for both clients: read
  `C_PaperDollInfo.GetInventorySlotInfo` first (both BIRs list it).
- **Data, Retail-only:** `SLOT_NAMES` (`Items.lua:15-21`, no Ranged or Ammo), `INVTYPE_TO_SLOT` ranged rows
  (`:65-68`), `SLOT_LABEL_KEYS` (`:31-36`; `RANGEDSLOT` and `AMMOSLOT` exist in F-BIR GlobalStrings), and
  `SLOT_SWAP` (`:88-92`).
- **Behavior:** `PS.CanDualWield2H` (`PlayerState.lua:88-90`) is Titan's Grip, read as "Warrior spec 2". It must
  be `false` on Forever (Retail-only talent).
- Combat: Forever lets MH, OH and Ranged swap in combat (Constants `:157-161`). The engine waits out combat for
  automated swaps anyway (`Equip.lua:215-239`). OK.
- Specialty bags: the family test (`Compat.BitAnd`) covers quivers, ammo pouches and soul bags. OK.

Verdict: **GUARD**: a per-client slot table (Forever adds `RangedSlot` and the ranged invtypes →
`RangedSlot`; Ammo per decision D1), Titan's Grip off on Forever. **CHECK** P5/P6.

### 1.7 Bag and inventory scanning (`modules/Inventory.lua`, `Inventory_Lists.lua`)

Uses `C_Container.GetContainerItemLink / GetContainerNumSlots / GetContainerNumFreeSlots / GetContainerItemCooldown /
ContainerIDToInventoryID`, `NUM_TOTAL_EQUIPPED_BAG_SLOTS` (`Compat.lua:869-871`), and the events `BAG_UPDATE`,
`BAG_UPDATE_DELAYED`, `UNIT_INVENTORY_CHANGED`, `GET_ITEM_INFO_RECEIVED` and `PLAYER_ENTERING_WORLD`.

- The bag range is 0..`NUM_TOTAL_EQUIPPED_BAG_SLOTS` (`Inventory.lua:52-67`). On Forever that is
  `NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS` (F-UI `Constants.lua:168-170`). The values are not static, so they need a
  probe (P7).
- `Enum.BagIndex.Keyring = -1` exists on both (`KEYRING_CONTAINER`, F-UI `Constants.lua:166`). Keys are not gear,
  so it is not scanned. OK.

Verdict: **OK**, **CHECK** P7.

### 1.8 Bank: deposit, withdraw, missing (`modules/Bank.lua`, `Compat.lua:799-837`)

Uses `Enum.BagIndex.CharacterBankTab_N` (else `Bank` and `BankBag_N`), `Enum.PlayerInteractionType.Banker` and
`CharacterBanker`, and the events `BANKFRAME_OPENED/CLOSED`, `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` and
`PLAYERBANKSLOTS_CHANGED`.

- Forever's `BagIndex` has `CharacterBankTab_1..9` = 6..14 (Retail has 1..6) and AccountBankTab_1..9 (F-BIR
  `LuaEnum.lua` BagIndex). `appendSeries` stops at the first missing name and is capped at 16, so it reads all nine.
  `PlayerInteractionType.Banker = 8` and `CharacterBanker = 67` are identical on both clients.
- Forever's bank is tab-based with "player bags in bank" (`C_Bank.ShouldUsePlayerBagsInBank`, F-BIR added). A bank
  bag maps to `CharacterBankTab_1 + bagSlotID - 1` (F-UI `Camelot/BankFrame.lua:26-32`, `:310-318`). What is not
  known is whether the base 24-slot bank is tab 1, and whether unbought tabs answer 0 slots.
- No warband bank: the addon never scans account tabs. OK.

Verdict: **OK by construction**, **CHECK** P8/P9 (a deposit and withdraw round trip at a Forever banker).

### 1.9 Item info, stats and sources (`modules/ItemInfo.lua`, `ItemStats.lua`, `ItemStats_Sources.lua`, `Compat.lua:318-524`)

Uses `C_Item.GetItemInfo / GetItemInfoInstant / GetDetailedItemLevelInfo / GetItemStats / GetItemIconByID /
GetItemSpell / GetItemFamily / GetItemUpgradeInfo / GetItemUniquenessByID / IsBound / IsBoundToAccountUntilEquip /
DoesItemExist`, `C_PlayerInfo.CanUseItem`, `C_ItemUpgrade.CanUpgradeItem`, `C_AzeriteEmpoweredItem.*` and
`C_TooltipInfo.GetBagItem / GetInventoryItem / GetHyperlink`. All are present on Forever. The unconfirmed ones are
`pcall`'d and read as nil.

- Stats: the built-in category is STA, STR, INT, AGI, SPI, HAS, VER, MAS, CRI (`ItemStats.lua:39-49`). Vanilla
  items carry Hit, Crit, Spell Damage, Spell Healing, Attack Power, Defense, MP5, resistances and armor. The
  Forever GlobalStrings show the vanilla vocabulary: `ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "Spell Damage"`,
  `ITEM_MOD_SPELL_HEALING_DONE_SHORT = "Spell Healing"`, `ITEM_MOD_MANA_REGENERATION_SHORT = "Mana Regeneration
  per 5 sec"`, eight `ITEM_MOD_ATTACK_POWER_VS_*` and `ITEM_MOD_SPELL_DAMAGE_VS_*` keys, and "Piercing" for
  penetration (diff of F-BIR and L-BIR `GlobalStrings/enUS.lua`: 215 against 192 `ITEM_MOD_*` keys). HAS, VER and
  MAS will always score 0 on Forever. Nothing breaks, but the optimizer is blind to the stats that matter there.
- Sources: Pawn and WeightsWatcher are optional and fail soft (`Compat.lua:898-938`). OK.
- Seed data: `ALIASES` (Benediction/Anathema, Thunderstrike/Shadowstrike) and `IGNORED_UNUSED` (Mining Pick,
  Arclight Spanner, Twilight Cultist set) are vanilla items and **fit Forever**. The Argent lances and
  `PHANTOM_IDS` (Legion artifacts) are Retail-only but harmless. `CORRECTIONS` 27503 and 27515 are TBC items,
  also harmless.

Verdict: item info **OK**. Stats: **ABSENT** for HAS, VER and MAS on Forever. **SEED** (step 2): a Forever stat
list (hit, spell crit, spell damage, healing, AP, defense, MP5, resistances, armor) keyed on the keys P14 reports.

### 1.10 Optimizer (`modules/Optimize.lua`, `Optimize_Genetic.lua`, `Dialog_Rebuild.lua`)

Pure Lua over `NS.Stats` and `SLOT_NAMES`, with `TwoHandSlot`/`Weapon0Slot` meta slots (`ItemInfo.lua:333-346`).

Verdict: **OK**. It inherits §1.6 (Ranged slot, Titan's Grip) and §1.9 (stat list).

### 1.11 Tooltips: "used by" lines and compare (`modules/Tooltips.lua`, `Tooltips_Compare.lua`, `OutfitTooltip.lua`)

Uses `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item)` (`Tooltips.lua:192-196`; F-UI
`Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua`), `GameTooltip`, `ShoppingTooltip1/2`,
`ShoppingTooltipTemplate`, `hooksecurefunc("GameTooltip_ShowCompareItem")` (`Compat.lua:639-642`) and
`GetPrimaryTooltipInfo`. `GameTooltip_ShowCompareItem` is identical in F-UI and L-UI
(`Blizzard_GameTooltip/Mainline/GameTooltip.lua:483`; the files differ by one whitespace line).

Verdict: **OK**.

### 1.12 Quick slots: flyout filter, sort, click-to-open, drawer, tint (`modules/QuickSlots.lua`, `QuickSlots_Sort.lua`)

Uses `PaperDollItemsFrame.flyoutSettings.getItemsFunc / postGetItemsFunc` (post-hooks, `:454-457`),
`EquipmentFlyout_UpdateItems`, `EquipmentFlyoutPopoutButton_SetReversed`, `EquipmentFlyoutPopoutButton_HideAll`
(`:451-453`), `EquipmentFlyoutPopoutButton_OnClick`, `EquipmentFlyout_Hide` (`:142-156`), `EquipmentFlyoutFrame`
(`.button`, `.buttonFrame`, `.buttonFrame.bgN/numBGs`, `.NavigationFrame.BottomBackground`),
`ITEM_INVENTORY_LOCATION_*`, `EQUIPMENTFLYOUT_BORDERWIDTH` and `EFITEM_HEIGHT`.

Forever loads `Blizzard_FrameXML/Camelot/EquipmentFlyout.lua` (`Blizzard_FrameXML.toc:71-72`).

- The filter and sort hooks work. `flyoutSettings` keeps the same keys and signatures (F-UI
  `Camelot/PaperDollFrame.lua:354-364`, `:2573-2590`), and the location bits are identical (Constants `:130-132`).
  The click-to-open path works: `OnClick`, `Hide`, `.button` and `flyoutLocked` are all present. The upgrade-track
  sort reads nil and falls through to item level.
- `SetReversed` is removed on Forever. It is guarded (`hookGlobal` type test, `:430-434`), so the mirror repaint
  silently never runs. Forever's replacements are `_RefreshVisualState` and `_OnStateChanged` (F-UI
  `Camelot/EquipmentFlyout.lua:730-768`).
- **The drawer is wrong on Forever.** Arrow placement differs (Forever: `LEFT/RIGHT/UP/DOWN` with a ±5 px offset by
  `flyoutDirection`, `Camelot/PaperDollFrame.lua:1976-1989`). `paintArrow` writes `SetTexCoord` onto rotated atlas
  textures, and `alignFlyout` moves right-column flyouts to the slot's right, under the docked window, where
  Blizzard opens them left. Forever's flyouts already open inward, so the problem the drawer solves on Retail
  (left-column flyouts colliding with the sheet) does not exist there.
- The tint (vertex color plus desaturate on the rim textures) probably works, since Forever still builds
  `buttonFrame.bgN` and `NavigationFrame` (`Camelot/EquipmentFlyout.lua:205-217`, `:351`). That is a guess.

Verdict: filter, sort and click **OK**. Drawer **GUARD**: on Forever keep at most "show every arrow while the
window is up", with no `placeArrow`, `paintArrow` or `alignFlyout` (decision D4). Tint **CHECK** (P25). Ranged and
Ammo slot buttons join `slotOf` through §1.6.

### 1.13 Outfit stack, categories, slash outfit verbs (`modules/OutfitStack*.lua`, `Commands.lua`, `settings/Slash.lua`)

Pure Lua. The `[spec:N]` macro conditionals go through `SecureCmdOptionParse` (present).

Verdict: **OK**, **CHECK** P23 (`[spec:N]` resolves on Forever).

### 1.14 Seeded outfits (`modules/Outfits_Seed.lua`, `modules/Triggers.lua:156-233`)

Seeds Normal, Naked, one outfit per spec named `"<class>: <spec>"` from `Compat.NumSpecializations()` and
`Compat.GetSpecializationInfo(i)` (`Triggers.lua:157-170`), and class outfits (`Outfits_Seed.lua:29-43`).

- Specs are **index-based**, so Forever's different spec IDs do not matter. `GetNumSpecializations` is a C API on
  both clients (F-BIR). `Compat.GetSpecialization` goes through LibKa0s (C_SpecializationInfo first), which handles
  the fact that bare `GetSpecialization` is nil on Forever.
- Class outfits: Druid Tree of Life is Retail-only. Druid Moonkin is vanilla (talent). Rogue Stealth, Shaman Ghost
  Wolf, and the Druid caster, bear, cat, travel and prowl outfits are vanilla.

Verdict: spec seeds **OK** with **CHECK** P1/P2 (count, names, icons). Class seeds: `DRUID_TREE` **ABSENT**. The
rest is **OK** once §1.16's form IDs are right.

### 1.15 Zone and state detection (`modules/States.lua`, `States_Zone.lua`, `PlayerState.lua`)

Uses `GetInstanceInfo` (type, mapID), `GetZoneText`, `GetRealZoneText`, `C_UnitAuras.GetAuraDataByIndex`,
`GetNumShapeshiftForms/GetShapeshiftFormInfo`, `IsMounted`, `UnitOnTaxi`, `IsSwimming`, `IsFalling`, `IsResting`,
`UnitHealth/Max`, `UnitPower/Max/Type`, `UnitCastingInfo/ChannelInfo`, `UnitIsDeadOrGhost`,
`C_RestrictedActions.IsAddOnRestrictionActive` and the zone events. All present.

- **SEED, Retail-only:** `defaults/Zones.lua:24-62` holds 15 battlegrounds, 16 arenas and brawls
  (`Z.BRAWL_MAP_IDS`, `:66`). Vanilla has only AV, WSG and AB, and no arenas. The Classic map IDs are already in
  the rows: AV 30, AB 529, WSG 489. Whether Forever's instances answer those IDs needs P17.
- `DINING` reads aura icons 134062 and 132805 (`TriggerData.lua:15-18`). These are probably the same art in
  vanilla (guess), **CHECK** P4.
- Form and aura IDs: see §1.16.

Verdict: the engine is **OK**. The zone rows: the generic BG and AV/WSG/AB stay, every other row and `PVP_ARENA`
are **ABSENT** on Forever (D3). **SEED**: verify the three Forever map IDs (P17).

### 1.16 Triggers, one row each (`defaults/Triggers.lua`, `defaults/TriggerData.lua`, `modules/Triggers_*.lua`)

The trigger engine (`Triggers.lua`, `Triggers_Binder.lua`, `Triggers_Params.lua`, `Triggers_Families.lua`) is pure
Lua over the events above. **OK.**

| Trigger (`defaults/Triggers.lua` line) | Blizzard dependency | Forever verdict |
|---|---|---|
| IN_DUNGEON (70) | `IsInInstance` types party, raid, pvp, arena (`Triggers_CondGeneral.lua:60-75`) | OK. Param `enableArena` ABSENT (vanilla has no arenas) |
| INSTANCE_DIFFICULTY (80) | `GetInstanceInfo` 3rd return vs `DIFFICULTY_GROUPS` (`TriggerData.lua:97-114`) | GUARD and SEED: keep openWorld (0), dungeonNormal (1) and raid40 (9). ABSENT: heroic, mythic, mythicPlus, LFR, raid normal/heroic/mythic, delve. 20-player raids (ZG, AQ20; Classic uses 148) are unknown, CHECK P18 |
| HAS_BUFF (98) | `C_UnitAuras` (user spell list) | OK |
| TARGET (106) | `UnitGUID`, `UnitName("target")` 2-value (`Triggers_Params.lua:320-330`) | GUARD: the second return is the surname on Forever (W1 probe), so entries read `Ryz-Rockheart`. That is self-consistent, but the "match the name on any realm" rule (`Triggers_CondGeneral.lua:120-125`) then matches every `Ryz`. Use LibKa0s v1.94.0 `UnitCharacterName` (re-vendor) |
| TRINKET_QUEUE (114), FEET_QUEUE (122) | `GetInventoryItemCooldown`, container cooldowns | OK (Goblin Rocket Boots are vanilla) |
| IN_ZONES (127) | `C_Map.GetBestMapForUnit/GetMapInfo`, `GetMinimapZoneText` (captured by the player) | OK. Forever's uiMapIDs may differ from Retail's, but the IDs are captured in game, so no seed data |
| TALENT_TREE (135) | `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_TALENT_UPDATE` (present) | CHECK P21: whether either event fires on a Forever respec or talent change |
| SPIRIT_REGEN (140) | `UnitPower(MANA)` | OK (the five-second rule is vanilla) |
| GATHER_HERBALISM/MINING/SKINNING (147-165) | node tooltip line = `C_TradeSkillUI.GetTradeSkillDisplayName(182/186)` or `UNIT_SKINNABLE_LEATHER` ("Skinnable" on both), colored orange or red | CHECK P14b/P15: vanilla node tooltips may say "Requires Herbalism 150" instead of a bare skill line, and the display names may differ |
| LOCKPICKING (166) | `LOCKED_WITH_SPELL` ("Requires %s", identical) and the skill line 633 name, `SpellIsTargeting` | CHECK P15 (633's name on Forever). Otherwise OK |
| RIDING (170) | `IsMounted`, `UnitOnTaxi`, `IsFalling` | OK |
| SWIMMING (180) | `IsSwimming`, `C_Map` for Vashj'ir (`TriggerData.lua:117-121`) | OK. Param `disableVashjir` ABSENT (Cataclysm zone) |
| FISHING (189) | effects: Find Fish tracking `C_Minimap.GetTrackingInfo/SetTracking` (spell 43308), CVar `autoLootDefault`, CVar `autoInteract`, `C_ActionBar.SetActionBarPage` (all present) | Param `trackFish` and the FishTracking effect ABSENT: vanilla has no Find Fish tracking (CHECK P19 to confirm). The rest OK |
| DINING (202) | aura icons (§1.15) | CHECK P4 |
| FALLING (207), RESTING (211) | `IsFalling`, `IsResting` | OK |
| SPELLCAST (215) | `UNIT_SPELLCAST_START` spellID | OK. On a ranked client a list holds rank IDs, so the player must add each rank (doc note) |
| COOKING (223) | `TRADE_SKILL_SHOW/CLOSE`, `C_TradeSkillUI.GetBaseProfessionInfo().professionID == 185`, cooking pets Lil' Ragnaros (297) and Pierre (1204) | CHECK P16 (the professionID on Forever's Camelot professions UI). Params `summonRagnaros`, `summonPierre` and `randomPet` ABSENT (Retail store and MoP pets) |
| PVP_FLAGGED (235) | `UnitIsPVP` | OK |
| Zone rows (generated, `Triggers.lua:134-154`, `defaults/Zones.lua`) | `GetRealZoneText(mapID)` names them | See §1.15. Generic BG, AV, WSG and AB on Forever, and nothing else |
| QUEST_ARGENT_TOURNAMENT (241), QUEST_VIGILANCE_ON_WINGS (246), QUEST_FLAME_LEVIATHAN (251), QUEST_MULTIPHASE_SURVEY (256) | vehicle NPC IDs (`TriggerData.lua:50-90`), quest 34000-range (`Triggers_CondQuest.lua:32-42`) | ABSENT (WotLK, Cata and WoD content) |
| QUEST_TURNIN (260) | `QUEST_PROGRESS`, `QUEST_FINISHED` | OK |
| PET_BATTLE (265) | `PET_BATTLE_OPENING_DONE/CLOSE` | ABSENT (recommended). Note: `Blizzard_PetBattleUI` *allows* camelot (`Blizzard_PetBattleUI.toc`), but vanilla has no pet battles. Owner call D5 |
| DANCE (271) | `DoEmote` (deprecation shim to `C_ChatInfo.PerformEmote`, `Blizzard_DeprecatedChatInfo/Deprecated_ChatInfo.lua:12`, both clients) | OK. Hardening: call `C_ChatInfo.PerformEmote` first |
| COMPANION (275) | `C_PetJournal.GetSummonedPetGUID/SummonPetByGUID/GetNumPets/GetPetInfoByIndex` (present; Forever loads the *Classic* pet collection, `Blizzard_Collections.toc` `Classic\Blizzard_PetCollection.lua [... camelot]`) | CHECK P20 |
| DRUID_CASTER (282), DRUID_BEAR/CAT/TRAVEL/MOONKIN (druidForm) | `GetShapeshiftFormInfo` 4th return vs `FORM_SPELL_STATE` (`TriggerData.lua:32-39`) | SEED and CHECK P3: Forever has ranks, so Dire Bear (vanilla 9634, a guess from memory) will not map to FORM_BEAR. Cat 768, Travel 783 and Moonkin 24858 are probably the same (guess). Aquatic Form has no state (as on Retail) |
| DRUID_TREE | spell 33891 | ABSENT |
| DRUID_PROWL (298) | aura 5215 (`TriggerData.lua:22-27`) | SEED and CHECK P4: vanilla Prowl ranks (6783, 9913, a guess) |
| ROGUE_STEALTH (303) | form 1784, effect AutoLoot | SEED and CHECK P3: vanilla Stealth ranks (1785, 1786, 1787, a guess) |
| SHAMAN_GHOST_WOLF (309) | aura 2645 | OK (vanilla ID, guess), CHECK P4 |
| HUNTER_FEIGN_DEATH (314) | aura 5384 | OK (vanilla ID, guess), CHECK P4 |
| Shadowmeld (state STEALTH via aura 58984) | Retail ID | SEED: vanilla Shadowmeld is 20580 (guess) |
| SPEC_1..N (generated) | spec index | OK, CHECK P1/P2 |

A better rank fix than a list (to check): match a form or aura by its base spell (`C_Spell.GetBaseSpell` or
`FindBaseSpellByID`, if Forever maps ranks to rank 1). That would make the rank lists unnecessary. P3 and P4 give
the data either way.

### 1.17 Companion (`modules/Companion.lua`, `Compat.lua:584-635`)

Uses `C_PetJournal.*` and `hooksecurefunc(C_PetJournal, "SummonPetByGUID")`, all present.

Verdict: **CHECK** P20 (does the Forever journal list owned companions with species IDs, and can it summon).

### 1.18 Titles (`Compat.lua:768-797`, the outfit's `titleID`, `/or updatetitle`)

Uses `GetNumTitles`, `IsTitleKnown`, `GetTitleName` and `SetCurrentTitle`, all present. Forever has a Titles pane
(`Camelot/PaperDollFrame.xml:436-468`) and PvP-rank titles.

Verdict: **OK**, **CHECK** P22 (titles list, set).

### 1.19 Popups, dialogs, icon browser, diagnostics, debug, perf, settings, skins

- `StaticPopupDialogs` and `StaticPopup_Show` (`Popups.lua:42-136`, `settings/OptionsSetup.lua:72-89`): **OK**.
- `Settings.RegisterCanvasLayoutSubcategory` (guarded): **OK**. Panels passed on Forever in other addons.
- Icon browser: LibKa0s-IconBrowser-1.0, `LibKa0s icons: all`. **CHECK** P24: ConsumableMaster found that a
  Midnight-era fileID (7704166) is missing on the Forever client (CM `9ac7e33`). The browser's fileID list may hold
  Retail-only art.
- Diagnostics, debug console, perf: LibKa0s. **OK**.
- **Skins: GUARD.** Adopt the per-client default skin (`Skin:DefaultSkin()`, LibKa0s v1.94.0 Skin minor 18,
  skinning-§2 MUST), so `NS.DEFAULT_SKIN` in `core/SkinSetup.lua` follows the wave-1 pattern
  (`W1_DEFAULT_SKIN_AND_FOREVER_NAMES.md` §1). That needs the LibKa0s re-vendor.

### 1.20 Trigger and seed icons (`defaults/Triggers.lua` `icon =`, `C.ZONE_ICONS`, `core/Constants.lua:73`)

FileIDs: 132132, 135826, 135934, 136246, 134708, 134366, 136058, 132261, 136148, 136245, 134062, 133971,
135157, 132276, 132115, 132144, 136096, 136041, 132089, 132320, 136095, 132293, **1376041** (zone/BG icon), and the
defaults 132724 and 134400. The 13xxxx IDs are classic-era art (guess: present). 1376041 is Legion-era.

Verdict: **CHECK** P24. If 1376041 is missing, give Forever a per-client BG icon, as CM-F8 did for its empty icon.

### 1.21 Profiles and character identity

AceDB 40 is vendored (`libs/AceDB-3.0/AceDB-3.0.lua:44`, `:263`), so `db.char` keys by name and surname on Forever
already. **OK.** Outfitter stores no `Name-Realm` key of its own (grep: no `GetRealmName`/`UnitFullName` use).

## 2. Decisions for the owner

- **D1. The Ammo slot.** Forever has `CharacterAmmoSlot` (slot 0), shown when `C_PaperDollInfo.AmmoNeeded()`
  (`Camelot/PaperDollFrame.lua:1951-1956`). Should an outfit hold ammo? *Recommendation:* **no in step 1.** Ammo is
  a stack, not gear. Equipping it is a cursor drop that the stack-count and move logic were never built for, and
  slot 0 breaks the 1..19 walks. Ranged is the slot that matters (D2). Revisit if hunters ask.
- **D2. The Ranged slot.** *Recommendation:* **yes, in step 1**, Forever only. Add `RangedSlot` to a per-client
  `SLOT_NAMES` (weapons priority, after SecondaryHand), `INVTYPE_RANGED/RANGEDRIGHT/THROWN/RELIC → RangedSlot` on
  Forever, a `RANGEDSLOT` label, `COLUMN.RangedSlot = "BOTTOM"`, and no swap pair. Without it the addon is wrong
  for every hunter, warrior, rogue and wand user on Forever.
- **D3. PvP zone outfits.** *Recommendation:* on Forever, keep the generic Battleground row plus AV, WSG and AB
  (after P17 confirms the map IDs). Make `PVP_ARENA`, every arena row, the post-vanilla battlegrounds and the
  brawls absent. Keep `IN_DUNGEON.enableArena` absent too.
- **D4. The quick-slot drawer.** *Recommendation:* absent on Forever: no arrow moves, no mirroring, no flyout
  re-anchoring. Forever's flyouts already open inward, away from the docked window. Keep the filter, the sort and
  click-to-open. Optional: keep "show every slot's arrow while the window is up", which is harmless and per button.
- **D5. Pet Battle and Cooking pets.** *Recommendation:* both absent on Forever. Vanilla has no pet battles, and
  Lil' Ragnaros and Pierre are Retail pets. COOKING keeps its equip-on-window-open core.
- **D6. Quest triggers.** *Recommendation:* the four content quests (Argent Tournament, Vigilance on Wings, Flame
  Leviathan, Multiphase Survey) are absent on Forever. Quest Turn-in stays.
- **D7. Instance difficulty.** *Recommendation:* on Forever offer Open world, Normal dungeons and 40-player raids.
  Add a 20-player raid row in step 2 once P18 gives the ID. Everything else is absent.
- **D8. The sheet button on the redrawn sheet.** *Recommendation:* place it as the last tab of Forever's centered
  tab row, after Titles or Pet, whichever is last, in Forever's atlas look. Hide it while the right pane is
  collapsed. Alternatively, put it on the left pane's top strip. That needs a mock-up, and I would not do it in
  step 1.
- **D9. The stat list.** *Recommendation:* step 1 drops HAS, VER and MAS on Forever (absent, not zero rows). Step 2
  adds the vanilla stats once P14 shows the keys `GetItemStats` returns.
- **D10. Rank handling.** *Recommendation:* for forms and auras, match by base spell if P3/P4 show Forever maps
  ranks to a base. Otherwise keep per-client ID lists (step 2 seed).

## 3. Proposed scope

### Step 1: Forever-compatible, no Forever seed data, Retail-only features absent

In the spirit of the ConsumableMaster port (`../ConsumableMaster/docs/superpowers/specs/2026-11-08-forever-port-design.md`):

1. **The port shape**, as in waves 1 and 2: `## Interface: 120105, 16001`, LibKa0s v1.94.0 re-vendored (for
   `Skin:DefaultSkin()` and `UnitCharacterName`), `NS.DEFAULT_SKIN` per client, README and DEPENDENCIES, the
   per-client feature table in `docs/ARCHITECTURE.md`, both kit profiles (`KA0S_KIT_CLIENT=forever`) in the gate,
   and a WoW Forever smoke section. The roster row flips in WowAddonStandards in the same change. The
   missing-globals scanner then enforces Forever. It is clean today apart from the built-in AceGUI row.
2. **Per-client data, chosen once at load** with `Compat.ForClient` / `ClientKey` (both present in v1.93.0,
   `libs/LibKa0s/Compat.lua:141`, `:155`):
   - `defaults/Items.lua`: `SLOT_NAMES` + `RangedSlot` and the ranged invtype rows on Forever (D2; D1: no ammo).
   - Trigger rows declare `clients = { "retail" }`, and Finalize skips them on Forever: the four quest triggers,
     PET_BATTLE, DRUID_TREE. Params declare clients too: `enableArena`, `disableVashjir`, `trackFish` plus the
     FishTracking effect, the three cooking-pet params, and the difficulty toggles in D7.
   - `defaults/Zones.lua`: rows declare clients. Forever keeps `PVP_BATTLEGROUND`, `BG_AV`, `BG_WSG` and `BG_AB`
     (D3), the brawls Retail-only.
   - `ItemStats.lua`: HAS, VER and MAS Retail-only (D9).
   - `FIND_FISH`, `COOKING_PETS`, `VASHJIR_MAP_IDS` and the vehicle NPC tables are reached only through their
     absent rows.
3. **Guards and adapters, with no seed data:**
   - `PS.CanDualWield2H()` → false on Forever (Titan's Grip).
   - The sheet button (D8): last shown tab, Forever look, hide while collapsed.
   - The quick-slot drawer off on Forever (D4).
   - `TARGET` player entries through `UnitCharacterName` (name and surname, no realm on Forever).
   - Both-client hardening: `C_PaperDollInfo.GetInventorySlotInfo` before the shim, `C_ChatInfo.PerformEmote`
     before `DoEmote`.
4. **Left as today on Forever:** Retail form and aura IDs (Bear, Cat, Travel, Moonkin, Prowl, Stealth, Shadowmeld,
   Ghost Wolf, FD). The low ranks work, and higher ranks wait for step 2's data. Document this as a known limitation
   for step 1.
5. **Tests:** every gate on both profiles. Forever's `SLOT_NAMES` is 19 and Retail's 18. An absent trigger has no
   catalog row, no picker entry and no param. The zone rows per client. `CanDualWield2H` per client. The sheet
   anchor under a 4-tab and a collapsed mock. Retail is pinned unchanged.

### Step 2: seed data (separate spec)

- Form and aura rank IDs, or a base-spell matcher (D10): Dire Bear, Prowl and Stealth ranks, vanilla Shadowmeld,
  and confirmed Ghost Wolf, FD and dining icons (P3/P4).
- The Forever stat list for the optimizer (hit, spell hit and crit, spell damage and healing, AP and ranged AP,
  defense, block, MP5, resistances, armor), keyed to P14's `GetItemStats` keys.
- Forever BG map IDs (P17), a 20-player raid difficulty ID (P18), and a Forever BG icon if 1376041 is missing (P24).
- The gathering and lockpicking tooltip wording on Forever (P14b/P15), and the cooking professionID (P16).
- Possibly class outfits for Forever: a hunter Aspect of the Pack or Cheetah ranged set, or a Paladin
  libram set (owner idea list, not required).
- Possibly the Ammo slot (D1) if wanted.

## 4. In-game probes for the owner (Forever)

Type each line in chat. Every line is under 255 characters. "(where)" says what to be doing first.

- **P1. Specs: count, the active one, and the first.**
  `/dump GetNumSpecializations(), C_SpecializationInfo.GetSpecialization(), C_SpecializationInfo.GetSpecializationInfo(1)`
- **P2. The other specs' names and icons.**
  `/dump C_SpecializationInfo.GetSpecializationInfo(2), C_SpecializationInfo.GetSpecializationInfo(3)`
- **P3. Shapeshift forms and their spell IDs** (on a druid at 40 or above, and on a rogue).
  `/run for i=1,GetNumShapeshiftForms() do print(i, GetShapeshiftFormInfo(i)) end`
- **P4. The player's buffs with spell IDs and icons** (eating or drinking, prowling, Shadowmeld, Ghost Wolf, Feign
  Death).
  `/run for i=1,40 do local a=C_UnitAuras.GetAuraDataByIndex("player",i,"HELPFUL") if not a then break end print(i,a.name,a.spellId,a.icon) end`
- **P5. The ranged and ammo slots.**
  `/dump GetInventorySlotInfo("RangedSlot"), GetInventorySlotInfo("AmmoSlot"), C_PaperDollInfo.IsRangedSlotShown(), C_PaperDollInfo.AmmoNeeded(), UnitUsesAmmo("player")`
- **P6. The equipped ranged item's inventory type** (with a bow, gun, wand or relic equipped).
  `/dump C_Item.GetItemInfoInstant(GetInventoryItemLink("player",18) or 0)`
- **P7. The bag constants.**
  `/dump NUM_BAG_SLOTS, NUM_REAGENTBAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS, NUM_CHARACTER_BANK_SLOTS, ITEM_INVENTORY_BANK_BAG_OFFSET`
- **P8. Container sizes** (at a banker, with the bank open).
  `/run for i=-3,14 do print(i, C_Container.GetContainerNumSlots(i), C_Container.GetContainerNumFreeSlots(i)) end`
- **P9. The bank tabs** (bank open).
  `/dump C_Bank.FetchPurchasedBankTabData(0), C_Bank.FetchMaxNumBankTabs(0), C_Bank.ShouldUsePlayerBagsInBank()`
- **P10. Equipment sets allowed.**
  `/dump C_EquipmentSet.CanUseEquipmentSets(), C_EquipmentSet.GetNumEquipmentSets(), C_EquipmentSet.GetEquipmentSetIDs()`
- **P11. A set's location keys** (after saving a set in Blizzard's pane with a ranged weapon on).
  `/dump C_EquipmentSet.GetItemLocations(C_EquipmentSet.GetEquipmentSetIDs()[1])`
- **P12. The sheet tabs** (character sheet open).
  `/dump PaperDollSidebarTab3:GetSize(), PaperDollSidebarTab4:IsShown(), CharacterFrame:IsRightPaneCollapsed(), CharacterFrame:GetWidth()`
- **P13. Sheet strata and levels** (sheet open).
  `/dump CharacterFrame:GetFrameStrata(), CharacterFrame:GetFrameLevel(), CharacterHeadSlot:GetFrameStrata(), CharacterHeadSlot:GetFrameLevel()`
- **P14. Item stat keys** (wearing chest gear with a vanilla bonus such as spell damage or hit; slot 5 = chest).
  `/dump C_Item.GetItemStats(GetInventoryItemLink("player",5))`
- **P14b. Node tooltip lines and colors.** Run it, then hover an herb or ore node, or a skinnable corpse, within 5 s.
  `/run C_Timer.After(5,function() for i=1,GameTooltip:NumLines() do local f=_G["GameTooltipTextLeft"..i] print(i,f:GetText(),f:GetTextColor()) end end)`
- **P15. The skill-line display names.**
  `/dump C_TradeSkillUI.GetTradeSkillDisplayName(182), C_TradeSkillUI.GetTradeSkillDisplayName(186), C_TradeSkillUI.GetTradeSkillDisplayName(393), C_TradeSkillUI.GetTradeSkillDisplayName(633)`
- **P16. The cooking window's profession** (Cooking window open).
  `/dump C_TradeSkillUI.GetBaseProfessionInfo()`
- **P17. Instance info** (inside WSG, AB and AV; also inside any dungeon).
  `/dump GetInstanceInfo()`
- **P18. Raid difficulty** (inside ZG or AQ20, and inside MC).
  `/dump GetInstanceInfo()`. The 3rd and 4th returns are the difficulty ID and name.
- **P19. Tracking types** (to confirm there is no Find Fish).
  `/run for i=1,C_Minimap.GetNumTrackingTypes() do local t=C_Minimap.GetTrackingInfo(i) print(i,t.name,t.spellID,t.texture) end`
- **P20. Companions.**
  `/dump C_PetJournal.GetNumPets(), C_PetJournal.GetSummonedPetGUID(), C_PetJournal.GetPetInfoByIndex(1)`
- **P21. Spec and talent events.** Run it, then change a talent or respec, and see which names print.
  `/run local f=CreateFrame("Frame") for _,e in ipairs({"ACTIVE_PLAYER_SPECIALIZATION_CHANGED","PLAYER_TALENT_UPDATE","ACTIVE_TALENT_GROUP_CHANGED"}) do f:RegisterEvent(e) end f:SetScript("OnEvent",function(_,e) print(e) end)`
- **P22. Titles.**
  `/dump GetNumTitles(), GetCurrentTitle(), GetTitleName(GetCurrentTitle())`
- **P23. The `[spec:N]` conditional.**
  `/dump SecureCmdOptionParse("[spec:1] one; [spec:2] two; three")`
- **P24. Do these icons draw?** Five squares for 8 s: BG icon, default outfit, question mark, Tree of Life, Instance
  Difficulty. A green or black fill means missing.
  `/run local f=CreateFrame("Frame",nil,UIParent) f:SetAllPoints() for i,d in ipairs({1376041,132724,134400,136041,132132}) do local t=f:CreateTexture() t:SetSize(40,40) t:SetPoint("CENTER",i*44,0) t:SetTexture(d) end C_Timer.After(8,function()f:Hide()end)`
- **P25. The flyout geometry** (sheet open).
  `/dump CharacterHeadSlot.flyoutDirection, CharacterHandsSlot.flyoutDirection, CharacterMainHandSlot.flyoutDirection, CharacterRangedSlot.flyoutDirection, EquipmentFlyoutFrame.NavigationFrame ~= nil`
- **P26. The deprecation fallbacks** (the GetInventorySlotInfo and DoEmote shims).
  `/dump GetCVar("loadDeprecationFallbacks"), GetInventorySlotInfo ~= nil, DoEmote ~= nil`

## 5. Method and evidence notes

- The scanner ran from a scratch script (`scratchpad/ofscan/scan.lua`) over `CG.collect(".", {"tools/"})` with
  both sets. The only findings were `libs/AceGUI-3.0/.../EditBox.lua:91` and `MultiLineEditBox.lua:112`
  `GetSpellInfo` (live and forever), which `CG.BUILTIN` allows. A wider reference scan (`scratchpad/ofscan/refs.lua`:
  any token naming a name in the forever `removed` list, calls or not, outside `libs/`, `tests/` and `tools/`) found
  only `modules/QuickSlots.lua:452 EquipmentFlyoutPopoutButton_SetReversed`, which is guarded.
- Events: 52 event names the shipping code mentions, all in F-BIR `Events.lua`
  (`scratchpad/ofscan/used_events` against `ev_forever`).
- C members: 41 `C_X.Y` names (`scratchpad/ofscan/cmembers`), all in F-BIR `GlobalAPI.lua`.
- Spell IDs for vanilla ranks (9634, 6783, 9913, 1785-1787, 20580) are **from memory**. Treat them as guesses until
  P3 and P4 answer.
- I did not run the test suite under `KA0S_KIT_CLIENT=forever`. The kit's mock models no Camelot sheet, so a green
  run would not prove §1.1, §1.2 or §1.12.
