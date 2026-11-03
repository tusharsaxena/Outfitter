# Outfitter: functional inventory for the rewrite

Date: 2026-11-03. Branch `feat/2026-11-03-ka0s-conversion`, base `7ea3dc3`.

This is the functional spec a full rewrite of Outfitter has to reproduce. It merges five read-only passes over the source: core 1-4400, core 4400-8806, the engine files, scripting and the bar, and the UI shell and tooling. Every citation is `file:line` at the base commit, and `Outfitter.lua` is the default file when none is named. Where the readers disagreed, the source was re-read and the source wins. Those reconciliations are listed in §0.

How to read it:
- **Keep** means the behaviour must survive the rewrite.
- **Fix** means it is a known bug that must not be copied.
- **Decide** means it is an upstream policy or dead path that needs a deliberate call.
- §18 lists the features that are retired and must **not** be carried over.

Nothing in this document was verified in a client. The headless suite stood at 144 passed and 0 failed at the base commit.

---

## 0. Reader conflicts resolved against source

| Topic | Conflict | Source says |
|---|---|---|
| Initialization events | One reader listed six, another seven | Seven: `PLAYER_ENTERING_WORLD`, `BAG_UPDATE`, `UNIT_INVENTORY_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `PLAYER_ALIVE` (455-464) |
| Credits table | One reader said it holds three groups | It is the full table at 17-261: DF compat, Ace Library, seven localizer groups, contributing developers, testers, donors by realm, and Thorium Brotherhood |
| HSV "red" threshold | Two different cut-offs were reported | Both are right, for different functions. `TooltipContainsLine` uses `h < 50 or h > 150` (7348). `_ItemInfo` FailedRequirements uses `h < 50 or h > 310` (OutfitterInventory.lua:427) |
| `ShowOutfitBar` default | false or true | `false` on a fresh install (OutfitterBar.lua:112). `true` when `CheckDatabase` repairs a missing `Settings.OutfitBar` (6828) |
| `/unequip` registration | Possibly broken | Confirmed broken. The handler is registered as the bare `self.UnequipItemByName` (5299-5300), so the message string arrives as `self` |
| Compartment function | Missing? | Confirmed missing. `Outfitter_OnAddonCompartmentClick` appears only in the TOC (L11), in `.luacheckrc:37` and in the old smoke-test doc. Nothing defines it |
| `OutfitterMinimapButton` | | Indexed at 5254 and 5277 but never created. Those error paths would raise |
| ArgentDawn events | | `cSpecialIDEvents.ArgentDawn` (1019) maps to `ARGENT_DAWN`/`NOT_ARGENT_DAWN`. Neither is in `BuiltinEvents`, and nothing ever produces them |

---

## 1. Identity, credits, packaging

### Identity and TOC
- The TOC (Outfitter.toc) declares:
  - Title `Outfitter Reborn`, Version `1.0.0`, Interface `120105`.
  - Author `mundocani, aDd1kTeD2Ka0s`.
  - IconTexture `Interface\Icons\INV_Chest_Cloth_21`.
  - `X-Curse-Project-ID: 1698220`. **Keep.**
- `X-ReloadTag: 2` is checked by `Initialize` (5253). **Decide**: drop it or replace it with a version check.
- Display name is "Outfitter Reborn". The tab title is "Outfitter", because the long name overflows the tab (OutfitterStrings.lua:29-30).
- The **LDB and LibDBIcon object key `"Outfitter"` is an identity, not a label** (`cBrokerName`, OutfitterStrings.lua:3-11). Broker displays and minimap settings are stored against it. **Keep it forever.** tests/test_load.lua:129-145 pins it.
- The header copyright reads "Copyright 2006-2018 John Stephen" (Outfitter.lua:1-4) and must survive.

### Credits
`Outfitter.CreditPlayersByRealm` (17-261) feeds the About panel.
- Role codes: 0 Friend, 1 Tester/dev, 2 Localizer, 3 Donor.
- Groups:
  - Dragonflight compat: Nulian, Coremeeko2.
  - "Ace Library": LibBabble, LibBabble-Zone, LibBabble-SubZone, LibBabble-Inventory, LibDataBroker, LibTipHooker, LibDropdown.
  - Localizers:
    - German: Ani, Zokrym, Dessa.
    - Chinese: AndyAska, xingdvd.
    - French: Jullye, Quetzaco, Ekhurr, Negwe.
    - Spanish: Marutak, Marosth.
    - Russian: Delika.
    - Korean: "Unknown".
  - 21 contributing developers and 15 testers.
  - Donors, grouped by realm.
  - Thorium Brotherhood, with the guild "Bloodforged" formatted by `cGuildCreditFormat`.

The README currently credits John Stephen / mundocani (2006-2018, MIT), aDd1kTeD2Ka0s, Nulian (Dragonflight), NokeHarrier, kionik and UppyDan (9.x), plus the library and localisation authors. **These credits must survive the README restyle.** tests/test_load.lua:171 asserts that the About panel credits both authors.

### Packaging
- `.pkgmeta` packages the addon as `Outfitter`.
- It ignores: `Media`, `tests`, `docs`, `.luacheckrc`, `.gitignore`, `.github`, `CLAUDE.md`, and two unreferenced textures (`IconButtonHighlight.blp`, `Outfitter-Button-original.blp`).
- `UsersManual.md` ships deliberately.

---

## 2. Saved variables and settings

The user has decided on a **fresh AceDB store with no migration**. The tables below are the *spec* for what that store must hold and what each key defaults to. The current names are `gOutfitter_Settings` (per character) and `gOutfitter_GlobalSettings` (account).

### 2.1 Per-character root (`InitializeSettings`, 5527-5547)

| Key | Default | Meaning |
|---|---|---|
| `Version` | 22 | Schema version. Irrelevant once migration is dropped |
| `Options` | `{MinimapButton = {}}` | See §2.2 |
| `Outfits[categoryID]` | `{}` per category in `cCategoryOrder` = `{"Complete","Accessory"}` | Arrays of outfit records (§2.4) |
| `LastOutfitStack` | `{}`. First run sets `{{Name=cNormalOutfit}}` | The persisted outfit stack. Named entries are stored as `{Name}`; temporary outfits are stored whole |
| `LayerIndex` | `{}` | Maps a layerID to a stack index (script layering) |
| `RecentCompleteOutfits` | `{}` | Names, most recent last. Init prunes missing names and duplicates (5334-5345) |
| `OutfitBar` | see §2.3 | |
| `ShapeshiftIndexInfo[index]` | lazily created | Cache from form index to shapeshift info (4787-4847) |
| `PreservedEMOutfits[name]` | transient | Set while the Equipment Manager reports zero sets (5586-5602) |
| `EnableEquipSounds` | nil | nil means **SFX is muted during swaps**. Set by `/outfitter sound` |
| `DisableEquipErrors` | nil | nil means equip errors are shown. Set by `/outfitter errors` |
| `LBFSettings` | nil | `{SkinID, Gloss, Backdrop, Colors}`, the dead LibButtonFacade skin (OutfitterBar.lua:1672-1681) |

### 2.2 `Options` (every key starts nil)

| Key | UI | nil means |
|---|---|---|
| `DisableAutoSwitch` | Options checkbox `OutfitterAutoSwitch`, labelled "Disable all outfit scripts". Checked means disabled | scripts run |
| `MinimapButton` (LibDBIcon table: `hide`, `minimapPos` as an angle or a `{x,y}` free-drag table, `lock`, `showInCompartment`) | `OutfitterShowMinimapButton` | shown |
| `HideMinimapButton` | legacy | seeds `MinimapButton.hide` once (5233-5235). Drop it |
| `DisableHotkeyMessages` | `OutfitterShowHotkeyMessages` | binding messages are shown |
| `DisableToolTipInfo` | `OutfitterTooltipInfo` ("Show 'Used by:' in tooltips") | tooltip line shown |
| `DisableItemComparisons` | `OutfitterItemComparisons` | extended compare is shown. Creates `ExtendedCompareTooltip` lazily |
| `ShowStackContents` | none (debug) | no stack dumps |

### 2.3 `OutfitBar` (OutfitterBar.lua:62-72, 107-115)

| Key | Default | Meaning |
|---|---|---|
| `ShowOutfitBar` | `false` (fresh) | Bar visible |
| `Position` | `{RelativePoint="TOPLEFT", x=200, y=-200}` | Screen pixels, divided by effective scale when applied |
| `Scale` | nil, read as 1 | Size slider, 0.5-1.5 |
| `Alpha` | nil, read as 1 | Idle alpha |
| `CombatAlpha` | nil, falls back to Alpha then 1 | Alpha in combat |
| `Vertical` | nil | One column per category |
| `LockPosition` | nil | No dragging; handles stay hidden |
| `HideBackground` | nil | Hides the background tiles |

### 2.4 Account (`InitializeGlobalSettings`, 5549)
- `{Version = 1, SavedScripts = {}}`. `SavedScripts` is never used elsewhere.
- `Banned` is a sticky boolean (§16). **Decide**: drop it with the ban list.

### 2.5 Outfit record

| Field | Meaning |
|---|---|
| `Name` | nil means a **temporary outfit**; the stack logic relies on this |
| `CategoryID` | `"Complete"` or `"Accessory"`, computed by `CalculateOutfitCategory`. Complete means every slot except Shirt and Tabard is present |
| `Items[slotName]` | nil means the slot is not used. `Code == 0` means the slot must be empty |
| `BindingIndex` | 1-10, unique across all outfits (3704-3716) |
| `ShowTitleID` | Player title to apply while worn |
| `UnequipOthers` | Non-Complete only. Wearing it clears the Accessory layer |
| `IgnoreComparisons` | Excluded from extended compare |
| `Disabled` | Script disabled. Also hidden from bar and minimap lists. Cleared when the outfit is worn by checkbox, left click or key binding |
| `CombatDisabled` | Script suppressed while `InCombat` or `MaybeInCombat` |
| `Script` / `ScriptID` | Mutually exclusive: custom text or preset ID |
| `SavedScript` | Stashes a custom script when the preset is set to NONE. EDIT_SCRIPT restores it |
| `ScriptSettings` | Script input values. Scripts also write runtime state here (§9.9) |
| `StatID` / `StatConfig` | Smart-outfit rebuild config |
| `StoredInEM`, `equipmentSetID`, `Unused`, `ItemLocations`, `TemporaryItems` | Equipment Manager mirror (§6) |
| `OutfitBar.Hide`, `OutfitBar.Texture` | Bar visibility and icon |
| `didEquip`, `didUnequip` | Runtime. True only when a *script* caused the change |
| `wasPvP` | Written by the PVP_FLAGGED preset |

**Item record** (`AddItem`, OutfitterOutfits.lua:107-137):
- Identity and codes: `Code`, `SubCode`, `Name`, `EnchantCode`, `JewelCode1..4`, `UniqueID`, `UpgradeTypeID`, `InstanceDifficultyID`, `BonusIDs`, `UpgradeID`.
- Descriptive: `InvType`, `SubType`, `Link`, `Quality`, `Level`, `BagType`.
- `AzeriteCodes`, a set of powerIDs.

`NewEmptyItemInfo` (4282-4300) has zeros everywhere, with `BonusIDs = "::"`.

**Fix**: `BonusIDs` currently has four spellings (`"n:b1:b2"`, `"::"`, `"0"`, `"nil"`). Pick one canonical form.

### 2.6 Script setting types (`SettingTypeInfo`, 305-312)

| Type | Default | Editor |
|---|---|---|
| `string` | `""` | EditBox |
| `number` | `0` | EditBox |
| `stringtable` | `{}` | ScrollableEditBox (one entry per line) |
| `zonelist` | `{}` | ZoneListEditBox (with an "insert current zone" button) |
| `boolean` | `false` | Checkbox |

---

## 3. Feature inventory by area

### 3.1 Outfits and categories
- There are two user categories, **Complete** and **Accessory**, chosen automatically from the slot count.
- `OutfitSettingsChanged` (5069) re-categorises an outfit and moves it between lists, then dispatches `EDIT_OUTFIT`.
- Three generated list sections:
  - **Odds 'n Ends**: unused, equippable, non-BoE, non-Warbound items. `CompiledUnusedItemsList` (OutfitterInventory.lua:1140-1180) excludes `cIgnoredUnusedItems`.
  - **Warbound**: warbound-until-equipped items (`GetWarboundItems`).
  - **BoEs**: unbound BoE items (`GetBoEItems`).
- Category descriptions are at 841-848.
- First run (`InitializeOutfits`, 5695):
  - Creates the **Normal** outfit from current gear and makes it the stack.
  - Creates the **Naked** outfit (every slot empty).
  - Runs `SynchronizeEM`.
  - Creates the per-class special outfits (`cClassSpecialOutfits`, 1058-1107):
    - DRUID: Caster, Bear, Cat, Travel, Moonkin, Tree, Prowl.
    - ROGUE: Stealth.
    - SHAMAN: Ghost Wolf.
  - Creates one outfit per specialization, named `"<Localized Class>: <Spec>"`, with `ScriptID SPECIALIZATION_n` and the spec icon (5776).
- Create (`NameOutfitDialog`) offers three sources: empty, current gear (the default), or "Create using" stats. The new outfit is **worn immediately**.
- Rename dispatches `WILL_RENAME_OUTFIT` → `UNWEAR_OUTFIT` → SetName → `WEAR_OUTFIT` → `DID_RENAME_OUTFIT` (6105-6117).
- Delete asks for confirmation, then unwears, deactivates the script, removes the outfit and dispatches `DELETE_OUTFIT`.
- **Set to current** / `update`: snapshot equipped gear into the outfit, wear it, then print "Updated the outfit '%s' to currently equipped items" (2219).
- **Rebuild**: `RebuildOutfit` (2153-2217). For a Complete outfit, slots the new result leaves empty keep their old items. **Fix**: the result is currently applied twice, once in the callback and once on the synchronous return.

### 3.2 The outfit stack (layering)
OutfitterEquipment.lua:986-1315.
- **Wear** (`WearOutfit`, 3411-3459):
  - A Complete outfit clears the stack.
  - `UnequipOthers` clears the Accessory category.
  - The outfit is pushed at its `LayerIndex[layerID]` slot or on top.
  - A Complete outfit moves to the end of RecentCompleteOutfits.
  - If the window is open, the outfit is selected when topmost; otherwise the selection is cleared. Comment: "UI can't function correctly if the selected outfit and top outfit don't stay the same."
- **Remove** (3468-3547):
  - A Complete outfit moves to the front of the recents.
  - Removing a Complete outfit **walks the recents from newest and wears the first one that still exists**, pruning stale names.
  - The HACK comment (3469-3477) records that skipping the Complete unequip broke stealth and riding outfits. **Keep the behaviour.**
- **Temporary outfit**: a manual swap outside Outfitter becomes a nameless top layer (`GetNewItemsOutfit`, `UpdateTemporaryOutfit`, 4431-4536). Adjacent temporaries collapse upward.
- **Window-open edit recording** (`InventoryChanged`, 1938-1983): when the window is open and an outfit is selected, items the player equips by hand are recorded into that outfit through `AddNewItems`. A tri-state "unknown" slot is not overwritten. The text "Adding %s to %s outfit" is printed.
- `GetCompiledOutfit` (4035-4070) layers the current inventory, then each stack outfit, then `AdjustOffhandSlot`, which empties the off-hand under a 2H unless Titan's Grip applies.
- `OUTFITTER_SWAP_COMPLETE` fires when the current inventory equals the expected outfit.
- **Title**: the highest stacked outfit with `ShowTitleID` calls `SetCurrentTitle`, **only inside a hardware event** (`HasHWEvent`) (`UpdateOutfitDisplay`, Equipment:1262-1275).
- `GetCurrentOutfitInfo` returns `""` for an empty stack and `"Custom"` when a temporary outfit is on top.
- *Toggle* semantics: `ToggleOutfit`/`ToggleOutfitNow` (3549-3567) remove a worn outfit, a Complete one too, and the Complete fallback then wears the previous one (the `toggle` verb, 1990). The bar (`OutfitterBar.lua:783-788`) and the key binding (3745-3751) re-wear a Complete outfit at their own call sites. Anything else toggles. (Corrected at the P4 group F review: this line read "a Complete outfit is always re-worn", which only the bar and the binding do.)
- `*Now` variants force an immediate update via `EndEquipmentUpdate(nil, true)`.
- **Fix B6**: `CollapseTemporaryOutfits` and `RestoreSavedStack` desync `LastOutfitStack` and `LayerIndex`.

### 3.3 Equipment change engine (OutfitterEquipment.lua)

**Update bracket (Keep, hard-won; comment at :802-851):**
- Begin and End are counted.
- End refuses to go negative.
- At zero, End runs `UpdateEquippedItems` immediately when `now` is set, or schedules it otherwise.
- A raise between Begin and End strands the count and **silently stops all swaps**.
- The existing mitigation is `ResetEquipmentUpdateCount()` at the very start of `PlayerEnteringWorld`, **before** that function's own Begin (1529-1535).
- Upstream deliberately chose not to pcall, "trading a visible stuck state for an invisible one".
- The rewrite should use a bracket that cannot strand, such as try/finally, and still surface failures. Keep the stuck diagnostic in `/outfitter zone`.

**`UpdateEquippedItems` (:853-947), in order:**
1. Return unless `EquippedNeedsUpdate`.
2. Defer while dead, and while casting or channeling unless `InterruptCasting` is set.
3. Throttle to `cMinEquipmentUpdateInterval = 1.5` s.
4. Compile the target outfit.
5. **Defer while `InCombat or MaybeInCombat`**. Automated combat swaps have been disallowed since 3.3, and `cCombatEquipmentSlots` is empty.
6. Build the change list and execute it.
7. Copy the result into `ExpectedOutfit`.

**Building and executing changes:**
- Change order follows `cSlotNames` priority, **durability items first** (Q4: it cuts repair costs on wipes): Head, Shoulder, Chest, Wrist, Hands, Waist, Legs, Feet, MainHand, SecondaryHand, Back, Neck, Shirt, Tabard, Finger0/1, Trinket0/1 (850-878).
- Slots that already hold the target item are skipped and the item is claimed.
- **Titan's Grip / dual-spec fix**: an off-hand holding a 2H without TG gets a `TGFix` unequip. `CanDualWield2H = WARRIOR and spec 2` (`TalentsChanged`).
- **Unique-equip ordering (Q7, :165-250, 558-644)**: rank 1 means no net unique increase, rank 2 mixed, rank 3 increase only. Up to 20 re-rank passes. This avoids "already equipped unique" errors.
- Legion artifact **phantom off-hand IDs** (`PhantomItemIDs`, 625-646) are skipped everywhere.
- **Execute** (:466-535):
  - Unless `EnableEquipSounds`, saves `Sound_EnableSFX`, sets it to 0 and restores it afterwards. **Fix B8**: a raise leaves SFX off for good.
  - Specialty-bag aware empty-then-equip.
  - CT_Mod `CT_oldPickupContainerItem` compatibility. **Decide**: drop it.
- Unequip to bags: specialty bag first, then a general bag. Otherwise "Can't remove %s because all bags are full".
- Equip errors are silenced by `DisableEquipErrors`:
  - "Can't put %s in the %s slot because it's already being used in another slot"
  - "Can't find item %s for slot %s"
- `optimize()` (:351-464) is intended to:
  - put TGFix first
  - equip the OH after the MH, and empty the OH before the MH (the Argent Lance fix)
  - drop the OH change for a 2H equip
  - fix ring, trinket and MH↔OH swaps
  
  **Fix B1**: `findChangeForSlot` always returns nil (`if not change and change.SlotName`), so none of this runs. It would also crash on the `FixSlotSwapChange` vs `fixSlotSwapChange` case mismatch.

**Other engine fixes:**
- **B2**: the 2H branch re-inserts the empty-OH change on every iteration.
- **B3**: `execute` runs (and toggles SFX) even when there are no changes.
- **B4**: `construct` returns an undefined global.
- **B5**: every `_InventoryCache` registers `GET_ITEM_INFO_RECEIVED` and never unregisters. A throwaway "expected" cache is built on every update, so the handlers leak.

### 3.4 Inventory scanning and item matching (OutfitterInventory.lua)

**Scanning:**
- `ScheduleSynch` debounces with a 0.01 s reschedule. It runs on `BAG_UPDATE`, player `UNIT_INVENTORY_CHANGED` and `PLAYERBANKSLOTS_CHANGED`, and always on entering the world.
- `Synchronize` compares link strings per bag slot and equipped slot. **A secret link is treated as an empty slot** (Q12). It dispatches `OUTFITTER_INVENTORY_CHANGED` and `OUTFITTER_BAGS_CHANGED`.
- Bag range:
  - Bank closed: `0 … NUM_TOTAL_EQUIPPED_BAG_SLOTS`, which includes the reagent bag.
  - Bank open: also `-1` and the purchased character bank tabs (`C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Character)`).
  - `IsBankBagIndex(i) = i > NUM_TOTAL_EQUIPPED_BAG_SLOTS or i < 0`.
  - The warband bank is never scanned. **Decide**: add it or document the gap.
- **With the bank closed, banked items read as missing.**
- The cache admits equipped items, and bag items that are equippable and **not BoE**. The min-level check is disabled (Q3: "new drops pre WoD are showing as minLevel 100 despite only requiring 90", 5851).

**Matching (`FindItem`, :951-1039):**
- Same Code, optional SubCode wildcard.
- An exact match needs SubCode, Enchant, Jewels, UniqueID, UpgradeTypeID, BonusIDs, UpgradeID and an Azerite set match.
- Otherwise a unique partial match is accepted.
- Claimed items carry `IgnoreItem`.

**Aliases (`cItemAliases`, 960-970):**
- Benediction↔Anathema, Thunderstrike↔Shadowstrike.
- The Alliance and Horde lances map to the Argent Lance. The Argent Lance maps to the Alliance lance, replaced by the Horde lance at runtime (`cItemAliases[46106]=46070`).

**`ItemsAreSame` (:1234-1308):** when only one copy is owned, codes are disregarded. It compares `InstanceDifficultyID`, which `FindItem` does not. **Fix**: unify the two.

**Link parsing (`GetItemInfoFromLink`, :315-372):**
- LinkLevel `[9]` and SpecializationID `[10]` are deliberately not captured (Q9).
- **Fix B11/B12**:
  - Only two bonus IDs are kept, and `UpgradeID` is read from the wrong position.
  - A short link raises.
  - Negative fields lose their sign.

**Tooltip-derived lazy properties (`ParseTooltip`, :374-401):**
- `BoE`, `Warbound`.
- `UniqueType`/`UniqueCount`, from `cUniqueEquippedSearchPattern`.
- `FailedRequirements`: "Requires:" in red. **Fix B14**: modern lines don't match, so this is always "meets".

**`FindNextCooldownItem(codes, ignoreSwapCooldown)` (:5-60)** is script API:
- An item with no "Use:" line counts as 30 s.
- Bag items get a minimum of 30 s unless `ignoreSwapCooldown` (Q10).
- **Fix B19**: the container cooldown `enable` flag may be a boolean.

**Fix B9**: `UsedInOutfit` is never reset.

### 3.5 Equipment Manager mirror (OutfitterOutfits.lua:433-1071; Outfitter.lua:5557-5680)
- **Every Blizzard equipment set appears as an Outfitter outfit.** Deleting a set in the Blizzard UI removes it here.
- `SynchronizeEM` runs on `EQUIPMENT_SETS_CHANGED` and on entering the world:
  - It marks EM outfits Unused.
  - It finds each set by name, case-insensitively.
  - A missing outfit is restored from `PreservedEMOutfits` or created as a stub.
  - Leftovers are deleted.
- **Keep**: zero reported sets means "the EM is flaking out". Outfits are preserved rather than deleted (Q8).
- **Store on server** (row checkbox `OutfitServerButton`):
  - On an unselected outfit, the first check wears and selects it. A second check stores it.
  - Refused with popup `OUTFITTER_SERVER_FULL` at `MAX_EQUIPMENT_SETS_PER_PLAYER`.
  - **The name is truncated to 31 characters.**
  - The icon comes from `OutfitBar:GetOutfitTexture`.
  - Slots come from the slot-checkbox UI state (`MarkEnabledSlots`).
  - `Script`, `ScriptID` and `StatID` are copied. **Fix B17**: `ScriptSettings` and `UnequipOthers` are dropped.
- **Store locally** clones the set into a native outfit, keeping the script, settings, stat and UnequipOthers.
- EM saves stop and restart EM monitoring so the addon doesn't re-process its own event.
- Icon 134400 (question mark) means "no icon".
- An EM outfit's `SetItems` (the rebuild path) wears temporary items and saves on `OUTFITTER_SWAP_COMPLETE` ("Saved outfit to Equipment Manager", unlocalized).
- `AddItem` and `SetItem` raise "Not implemented".
- **Fix B10**: the `IsComplete` TemporaryItems branch is wrong.

### 3.6 Stats and smart outfits (OutfitterItemStats.lua, OutfitterOptimize.lua)
- Stat category "Stat": STA, STR, INT, AGI, SPI, HAS, VER, MAS, CRI, `TOTAL_STATS`, `ITEM_LEVEL` (:204-224).
- Too-high-level items are excluded via `UnsecretNumber(UnitLevel)`. A secret level lets the item through.
- **Pawn** integration ("Pawn" category, a stat per visible scale, installed on Pawn's `ADDON_LOADED`). **Keep.**
- **WeightsWatcher** integration exists. **Decide**: the addon is abandoned, so drop it.
- `GenerateSmartOutfit(name, statConfig, cache, allowEmpty, completion)`:
  - *Simple* (one stat, no min/max): a linear greedy search. Items are bumped to their alternate slot (Trinket0→1, Finger0→1, Weapon0→1). The best MH/OH combination is chosen; for ITEM_LEVEL, only combinations with a non-empty MH. 2H is compared against 1H+OH.
  - *Complex*: a **genetic search** in a coroutine.
    - Population 300, top 25 parents, mutation 0.2, at most 1000 generations.
    - Stops after 100 generations with no change.
    - Yields every 0.02 s, or 0.1 s in "High speed".
    - A ties-favour-more-empty-slots element is appended (Q6).
    - Progress window: "Genetically optimizing %s for %s", with Cancel, a progress bar, the High speed checkbox and "Best score: %s".
    - Chat summary: "Checked %s outfits in %s seconds…" and "Best outfit score: %s".
- **Multi-stat config widget**:
  - Lines of `Stat %d` dropdown + op (Max / `<=` / `>=`) + value.
  - Add and remove buttons.
  - `GetConfig()` returns `{{StatID, MinValue, MaxValue}, Complex=bool}`. The default is `{{StatID="STA"}}`.
- **Fix**:
  - B13: VER, CRI and ITEM_LEVEL names are hard-coded English, so they never score on non-English clients. Use `C_Item.GetItemStats` and `C_Item.GetDetailedItemLevelInfo`.
  - B15: one-handers are never tried in the OH, and live cache objects get saved.
  - B16: assorted dead code and nil-printing errors.
  - B7: the result is both returned and passed to the callback.

### 3.7 Bank operations (bank must be open)
These are reachable from the outfit menu and slash commands (6912-7130).
- **Deposit**: the outfit's items go to empty bank slots (`GetEmptyBankSlotList`).
- **Deposit unique**: skips items used by other outfits that are not themselves banked.
- **Deposit others**: every other outfit's items are deposited, except this outfit's.
- **Withdraw**: banked items go to empty bag slots.
- **Withdraw others**: **Fix**. It currently calls the undefined `ExecuteEquipmentChangeList2`. Implement it properly, and report `cWithdrawBagsFullError` when the bags are full.
- Deposit clears the selection first, so put-away items are not recorded into the outfit.
- **Fix**: `vExpectedInventoryCache` is an undefined global, passed as nil.
- `/outfitter missing` requires the bank. It prints `cMissingItemReportIntro` and the links, or `cNoMissingItems`.

### 3.8 Tooltips
- **"Equipment Sets: …" line** (7152-7287). Hooks `GameTooltip` `SetBagItem`, `SetInventoryItem` (player only) and `SetHyperlink`. Gated on `not DisableToolTipInfo`.
  - Colour-coded outfit names: grey when disabled, red when items are missing, `|cff4033ff` when banked, white otherwise.
  - It **replaces Blizzard's own `EQUIPMENT_SETS` line** when one is present, found via `ConvertFormatStringToSearchPattern` with a pcall'd find. Otherwise it appends a line.
  - The result is cached per link.
  - **Fix**: links are not secret-guarded on this path.
- **Extended compare** (`_ExtendedCompareTooltip`, 7797-8187). Hooks `GameTooltip_ShowCompareItem`. On 10.0.2+ it requires `TooltipUtil.ShouldDoItemComparison` and the COMPAREITEMS modifier.
  - It **returns on a secret link** (hidden dungeon loot).
  - Armor only.
  - Secret tooltip geometry falls back to left-to-right.
  - Shows up to **5** `OutfitterCompareTooltip<N>` frames (ShoppingTooltipTemplate) with items from outfits not marked IgnoreComparisons, quality ≥ 2, sorted by level, skipping items already shown.
  - Line 1 reads "outfit name | Outfitter" in grey.
  - Calls the `LibTipHooker.HandlerList.item` handlers so other addons can decorate it.
- **Outfit tooltip** (`ShowOutfitTooltip`, 2836):
  - Name, script description, "Missing:" in red, "Banked:" in blue.
  - Falls back to a newbie tip (UberTooltips CVar).
  - **Fix**: the banked line renders red.

### 3.9 Automation (scripts)
Covered in full in §9.

### 3.10 Companion (battle pet) control (8238-8360, script API)
- `SummonCompanionByName/ByGUID(…, delay)` and `DismissCompanionByName/ByGUID`, driven by a desired-state reconciler, `SynchronizeCompanionState`.
- `CanSummonOrDismissCompanion` refuses while flying, in combat, dead, feigning, casting or channeling, or **within 3 s of `C_PetJournal.SummonPetByGUID`** (which is hooked).
- **Keep the comment at 8345-8353**: watch for the game auto-summoning a pet after a mount auto-dismiss, then dismiss it.
- Retries every 1 s with **no cap**. **Fix**: add a cap.
- Name matching is on the species name, case-insensitive. **Fix**: a nil name raises.

### 3.11 Flyout quick slots (OutfitterQuickSlots.lua)
- Created on `OUTFITTER_INIT`. There is no option to turn it off.
- Hooks PreClick and PostClick on each `Character<Slot>` button.
  - Clicking with an item on the cursor, or on an empty slot, **forces the Blizzard flyout open**.
  - Clicking while it is open closes it.
- Filter: items already equipped on the player are removed. Bag and bank items are kept.
- Sort (**Keep the algorithm and comments**, :85-314):
  - TrackCeiling (`C_Item.GetItemUpgradeInfo().maxItemLevel`) descending, then TrackStringID, then item level, then name (uncached last), then original index.
  - A track counts only if the item can still be upgraded. `C_ItemUpgrade.CanUpgradeItem` is pcall'd, with a headroom fallback.
  - Untracked items are banded into the highest track whose minimum level in *this* flyout is at or below theirs.
  - Special entries stay in place, and "place in bags" moves to the end.
- Bag links are unsecreted. A secret link or void storage returns nil.

### 3.12 Outfit bar
Covered in §7.6.

---

## 4. Slash commands

`/outfitter` → `ExecuteCommand` (1985-2079). Registered at 5296.
- If the text contains `|h` (an item link), it is used raw.
- Otherwise it goes through **`SecureCmdOptionParse`**, so macro conditionals work. A nil result is a silent no-op.
- Pattern `(%w+) ?(.*)`, command lower-cased.
- An empty command shows help. An unknown command shows help plus "Unknown command %s".
- **Outfit commands** take `[outfit name]`:
  - With no argument they use the current Complete outfit, or error "No Complete outfit is equipped".
  - A name not found errors "Couldn't find outfit named X".
  - Execution is wrapped in `HasHWEvent = true … false`.

| Command | Arg | Behaviour |
|---|---|---|
| `wear` / `unwear` / `toggle` | outfit | `WearOutfitNow` / `RemoveOutfitNow` / `ToggleOutfitNow` |
| `deposit` / `depositunique` / `depositothers` | outfit | §3.7 |
| `withdraw` / `withdrawothers` | outfit | §3.7 (withdrawothers is broken) |
| `update` | outfit | `SetOutfitToCurrent` |
| `reset` | `[bar]` | `bar` resets the bar position and prints "Outfit bar position reset", with no prompt. Otherwise the `OUTFITTER_CONFIRM_RESET` popup, then `Reset()`: hide, clear the selection and stack, then re-run InitializeSettings, InitializeOutfits and SynchronizeEM. **Fix**: `strlower(nil)` |
| `updatetitle` | | `OutfitStack:UpdateOutfitDisplay()` |
| `missing` | | §3.7 |
| `zone` | | `ShowZoneInfo` (5008-5042). Prints `Instance: <name> (type <t>, map ID <id>)`, a "no entry in cInstanceMapIDZoneIDs" note, `Zone outfits active: …` or `No zone outfits apply here`, and **`Equipment updates are STUCK (count N) -- reload to clear`**. **Keep** this diagnostic |
| `sound on\|off` | | Sets `EnableEquipSounds`. **Fix**: the messages read inverted |
| `errors on\|off` (hidden alias `daxdax`) | | Sets `DisableEquipErrors` |
| `disable` / `enable` | | `SetAutoSwitch` plus `cAutoChangesDisabled` / `cAutoChangesEnabled` |
| `iteminfo <link>` | | `ShowLinkInfo`: prints the link fields. **Fix**: no secret guard |
| `help` | | `ShowCommandHelp` (2091-2117). The rewrite needs equivalent help text that covers every command |
| `summary` | | **Dead** (empty stub). Drop it or implement it |
| `rating` | | **Dead/stale**: legacy combat-rating indices. Drop it |
| `itemstats <link>` | | **Dead**: `GetItemLinkStats` returns nil. Drop it or re-implement it on `C_Item.GetItemStats` |

`/unequip <name|slotID>` is registered only if no other addon owns `SlashCmdList.UNEQUIP` (5298-5301).
- A numeric argument is a slot ID. Otherwise the name is matched case-insensitively against equipped items.
- The item moves to an empty bag slot, or the command errors "…all bags are full".
- **Fix**: it is registered as a bare function, so `self` is the message. It also does not return after "Couldn't find an item named X".

tests/test_commands.lua requires that every dispatched command appears in the help and in UsersManual.md, and that nothing documented is fake.

---

## 5. Key bindings (Bindings.xml)

All bindings use `category="Outfitter!"` and the header `BINDING_HEADER_OUTFITTER_TITLE`.

| Binding | Action | Label |
|---|---|---|
| `OUTFITTER_OUTFIT1..10` | `WearBoundOutfit(n)` | "Outfit 1".."Outfit 10" |
| `OUTFITTER_OUTFIT` | `OpenUI()` | "Open Outfitter" |
| `OUTFITTER_ENABLEAUTOMATION` | `EnableAutoChanges()` | "Enable automatic changes" |
| `OUTFITTER_DISABLEAUTOMATION` | `DisableAutoChanges()` | "Disable automatic changes" |
| `OUTFITTER_UPDATEOUTFIT` | `SetOutfitToCurrent(GetCurrentCompleteOutfit())` | "Update to equipped items". **Fix**: nil when no Complete outfit is worn |

`WearBoundOutfit` (3723-3772):
- **Anti-panic**: a repeat press of the same index within `cMinBindingTime = 0.75` s is ignored, and the timer refreshes on every press.
- It clears `Disabled` and sets `HasHWEvent`.
- A Complete outfit is worn with `WearOutfitNow`. Anything else toggles.
- Unless `DisableHotkeyMessages` is set, it prints "Outfitter: %s equipped/unequipped" to `UIErrorsFrame` in `OUTFIT_MESSAGE_COLOR` (0.2, 0.75, 0.3).
- The index is assigned from the outfit menu (None, Outfit 1-10). `SetOutfitBindingIndex` keeps indices unique.

---

## 6. Events

### 6.1 WoW events (EventLib registrations in `Initialize`, 5366-5496, unless noted)

| Event | Handler | Behaviour |
|---|---|---|
| 7 init events (§0) | `InitializationCheck` | `InitializeInstant` once, then reschedule `Initialize` 1 s later ("allow time for WoW to load inventory, bags, talent trees"). Unregistered in `Initialize` |
| PLAYER_ENTERING_WORLD | `SchedulePlayerEnteringWorld` (0.05 s debounce) | Clear casting flags; **ResetEquipmentUpdateCount before Begin**; flush the inventory cache; RegenEnabled; UpdateAuraStates; ScheduleUpdateZone; resume load-screen events; ScheduleSynch; SynchronizeEM; End |
| PLAYER_LEAVING_WORLD | `PlayerLeavingWorld` | Sets `Suspended` and unregisters BAG_UPDATE, UNIT_INVENTORY_CHANGED, UNIT_AURA and PLAYERBANKSLOTS_CHANGED for the loading screen |
| BAG_UPDATE, PLAYERBANKSLOTS_CHANGED | `ScheduleSynch` | |
| UNIT_INVENTORY_CHANGED (blind) | player only, `ScheduleSynch` | |
| BANKFRAME_OPENED/CLOSED | `BankFrameIsOpen` + synch | Gates the bank actions and the bank bag range |
| PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE | type 26 sets `VoidStorageIsOpen` | Void storage itself is retired. **Decide**: drop |
| PLAYER_REGEN_DISABLED | `RegenDisabled` | `InCombat`, bar `AdjustAlpha`, UpdateOutfitDisplay, suspend the secure row actions |
| PLAYER_REGEN_ENABLED | `RegenEnabled` | Clear InCombat inside a bracket so queued swaps fire; AdjustAlpha; resume secure actions; **re-read the auras** (a buff that survived the fight won't fire UNIT_AURA) |
| PLAYER_DEAD | | `IsDead = true` |
| PLAYER_ALIVE, PLAYER_UNGHOST | `PlayerAlive` | Bracket: `IsDead = false`, then UpdateAuraStates |
| UNIT_AURA | `UnitAuraChanged` | Player only. A 2 s unique task in combat, otherwise immediate |
| ZONE_CHANGED_NEW_AREA / ZONE_CHANGED / ZONE_CHANGED_INDOORS | `ScheduleUpdateZone` (0.01 s) | §8 |
| UNIT_HEALTH (dynamic), UNIT_MANA (blind) | `UnitHealthOrManaChanged` | Dining and Spirit (§8.4). **Fix**: UNIT_MANA no longer exists on retail; use UNIT_POWER_UPDATE |
| UNIT_SPELLCAST_SENT, _START | `UnitSpellcastSent` | `SpellcastSentTime`, IsCasting |
| _INTERRUPTED, _STOP, _FAILED, _FAILED_QUIET, _SUCCEEDED | `UnitSpellcastStop` | Clear IsCasting; `SetUpdateDelay(now, 0.5)` ("in combat message comes after the cast") |
| _CHANNEL_START / _CHANNEL_STOP | | IsChanneling, the same 0.5 s delay |
| PLAYER_TALENT_UPDATE (and the removed CHARACTER_POINTS_CHANGED) | `TalentsChanged` | `CanDualWield2H` |
| EQUIPMENT_SETS_CHANGED | `SynchronizeEM` | Toggled off around the addon's own saves |
| GET_ITEM_INFO_RECEIVED | `_InventoryCache:Flush` | **Fix B5**: leaks |
| ADDON_LOADED | Pawn and WW category install | |
| PET_BATTLE_OPENING_START / PET_BATTLE_OVER | bar hide/show (OutfitterBar.lua:100-101) | |
| ZONE_CHANGED* on the ZoneListButton (Outfitter.xml:1414-1428) | refresh the button text while shown | |
| Script-declared events | `_ScriptContext:RegisterEvent` | §9.5 |

### 6.2 Hooks
- `hooksecurefunc(C_PetJournal,"SummonPetByGUID")`, the pet cooldown.
- GameTooltip:
  - OnShow and OnHide, which fire `GAMETOOLTIP_SHOW` and `GAMETOOLTIP_HIDE`. The same hooks go on `MI2_TooltipFrame` when MobInfo2 is present.
  - `SetBagItem`, `SetInventoryItem`, `SetHyperlink`.
  - `TooltipDataProcessor` / `OnTooltipSetItem`.
  - `GameTooltip_ShowCompareItem`.
- `PaperDollFrame` OnHide hides the window.
- `OutfitterFrame` OnUpdate runs the follow logic.
- QuickSlots Pre/PostClick on the `Character<Slot>` buttons.

### 6.3 Custom EventLib events
- `TIMER`: 0.5 s heartbeat.
- `GAMETOOLTIP_SHOW` / `GAMETOOLTIP_HIDE`.
- `OUTFITTER_INVENTORY_CHANGED`, whose listener is `InventoryChanged`.
- `OUTFITTER_BAGS_CHANGED`, which has no listener.
- `OUTFITTER_SWAP_COMPLETE`.
- `WEAROUTFIT` / `UNWEAROUTFIT`, re-dispatched publicly.
- Every special-state `X` / `NOT_X` pair (§8.3).

**EventLib behaviour that matters (Libraries/MC2EventLib):**
- Handlers are called **without pcall**. An error leaves `Iterators[eventID]` set, so **that event never dispatches again for the session**.
- A re-entrant dispatch of the same event is dropped silently.
- A duplicate registration raises "Attempted to register a handler twice".
- `TRADE_SKILL_SHOW/CLOSE` dispatches set `HasHWEvent`.

**Fix**: the rewrite's bus must isolate handler errors.

### 6.4 Outfit event bus (public)
`RegisterOutfitEvent(event, fn)` / `UnregisterOutfitEvent`, with dispatch at 1590-1679.

Events:
- `OUTFITTER_INIT`
- `ADD_OUTFIT`, `DELETE_OUTFIT`, `EDIT_OUTFIT`
- `WILL_RENAME_OUTFIT(outfit, old, new)`, `DID_RENAME_OUTFIT`
- `WEAR_OUTFIT`, `UNWEAR_OUTFIT`, with `(name, outfit)`

Dispatch:
- Nothing is dispatched before `Initialized`.
- Each handler runs under pcall. **Fix**: a handler that *returns* a value is reported as an error.
- `WEAR`/`UNWEAR` also run that outfit's own `OUTFIT_EQUIPPED`/`OUTFIT_UNEQUIPPED` script handler, re-dispatch through EventLib, call `UpdateOutfitDisplay`, and schedule the (dead) icon update.

---

## 7. UI surfaces

### 7.1 Main window `OutfitterFrame` (Outfitter.xml:604; Outfitter.lua:1309-1520)
The user wants it to **stay docked to the character sheet, restyled with the LibKa0s skin**.
- Open it with:
  - the robe button **`OutfitterButton`** (64×32 at the PaperDollFrame TOPRIGHT (0,-27), `Textures\Outfitter-Button`)
  - the LDB right click
  - the minimap menu "Open Outfitter"
  - key binding `OUTFITTER_OUTFIT`
  - the addon compartment (**Fix**: the function is missing)
- `OpenUI` shows CharacterFrame on PaperDollFrame and then the window. `ToggleUI(true)` also closes the sheet.
- At init, `PaperDollSidebarTabs` is moved to `BOTTOMRIGHT` of `CharacterFrameInsetRight` `TOPRIGHT` (-30, -1) to make room for the button (5348).
- **Detach and follow (Keep, hard-won, 1326-1488):**
  - Each list row owns a secure button. A protected frame restricts both its parents and its anchor targets. A window parented or anchored to PaperDollFrame therefore makes the sheet **unmovable for other addons**.
  - So `OnLoad` reparents the window to UIParent, hides it from the PaperDollFrame OnHide hook, and follows the sheet from OnUpdate.
  - `PositionWindow` issues a single TOPLEFT SetPoint to UIParent BOTTOMLEFT at the sheet's right and top, times the anchor-to-own scale ratio, with y −30. There is no ClearAllPoints. If the sheet was never laid out, the window parks at UIParent and the follow cache is cleared.
  - The follow is throttled to 0.05 s and re-attaches only when the sheet corner moves.
  - Attach and Detach are no-ops in combat. If the pcall'd attach fails, `WindowFollowDisabled` is set and the window reparents to `OutfitterButtonFrame` (usable, but the sheet is pinned).
- **Strata (Keep; CLAUDE.md):**
  - `MatchWindowStrata` copies `OutfitterButtonFrame`'s strata and its level +1 onto the window. It is skipped in combat.
  - `MatchSlotEnablesStrata` gives the slot checkboxes CharacterFrame's strata and one level above the highest frame under CharacterFrame (excluding `OutfitterButtonFrame`). It is allowed in combat because there are no secure frames.
  - **Never use a fixed strata.**
  - The checkboxes are first stacked in `SelectOutfit`, not `OnLoad`, because the XML frame doesn't exist yet when OnLoad runs.
- `OnShow` attaches, matches strata and **always opens the main panel** (3).
- `OnHide` clears the selection, cancels the Name and Rebuild dialogs, and explicitly calls `Hide()` so the window does not reappear the next time the sheet opens.
- Esc: the window is not in UISpecialFrames. It closes via the sheet.
- Tabs: 1 About, 2 Options, 3 Main (`cPanelFrames`).
  - **Fix**: the XML tab names and ids are crossed. `OutfitterFrameTab3` has id 1, and so on.
  - About is built lazily.
  - `ShowPanel` deliberately re-runs even when the panel is unchanged, because it resets field values.

### 7.2 Main list (`Update`, 3153-3300)
- 14 rows, `OutfitterItem0..13`, 224×18, in a FauxScrollFrame with an 18 px step.
- Sections:
  - Complete and Accessory outfits, sorted by name (nil names last, EM tiebreak).
  - Odds 'n Ends, Warbound and BoEs, sorted by item level descending, then name, then code, then location.
- Collapsible categories (session-only `Collapsed`).
- `Update(true)` wipes `OutfitInfoCache`. The function only redraws when the window is visible and the display is dirty.
- **Outfit row** (`SetToOutfit`, 8512):
  - A "worn" checkbox: check to wear (clears Disabled), uncheck to remove.
  - The EM server checkbox.
  - The name, coloured grey with the `cDisabledOutfitName` format when disabled, red when missing items, blue when banked.
  - The gear script icon (`Textures\Gear`), dimmed to 0.4 when auto-switch is off or the outfit is disabled.
  - A menu button.
  - The selection highlight.
- **Item row**: icon plus name in quality colour (heirloom 7 maps to 6).
- **Category row**: plus/minus expand control.
- **Clicks** (8688-8734):
  - If a spell is targeting an item (`SpellCanTargetItem`/`ID`), the click goes to the secure button.
  - Category: toggle collapse.
  - Item, left click: pick it up.
  - Item, right click: use or sell it, except with the merchant **buyback tab** open.
  - Outfit, left click: clear Disabled and wear.
  - Outfit, right click: the menu at the cursor.
- **Hover**:
  - Category: newbie tip with the description.
  - Item: the item tooltip, with the repair cost in repair mode and the sell cursor at a merchant.
  - Outfit: `ShowOutfitTooltip`.
- **Secure row buttons (Keep, 8457-8479):**
  - `<row>SecureAction` is a `SecureActionButtonTemplate`, setAllPoints. **Never reparent it or re-anchor it** ("Cannot anchor protected frames to regions").
  - Item rows set `target-bag`/`target-slot` so Disenchant and other item-targeting spells land on a secure frame.
  - Enable and disable are no-ops in combat. All 14 rows are suspended on entering combat and resumed on leaving it.
  - Unused rows are disabled **before** they are hidden.
- "New Outfit" button: `CreateNewOutfit`.

### 7.3 Slot enable checkboxes (`OutfitterSlotEnables`, Outfitter.xml:1058)
- 18 `OutfitterEnable<Slot>` checkboxes, 24×24, anchored to `Character<Slot>` at TOPLEFT (−4,4). The Finger, Trinket, MainHand and SecondaryHand boxes anchor at TOPRIGHT (4,4).
- The frames are **read directly** by the outfit methods (OutfitterOutfits.lua:50, 538, 558). If the rewrite renames them, update those readers.
- Tri-state, per slot:
  - unchecked: the slot is unused
  - green tick: enabled and equipped
  - `Textures\CheckboxUnknown` with `IsUnknown = true`: enabled, owned, but not currently equipped
- Click:
  - With an item on the cursor, **drop it into the slot** (`PickupInventoryItem`). Drag-and-drop works the same way.
  - Otherwise toggle. Enabling records the currently equipped item, then the outfit is re-categorised.
- "Enable all" / "Enable none" buttons. **Fix**: the frame names are swapped relative to the labels.
- Shown only while an outfit is selected. They hide `CharacterLevelText` while shown.

### 7.4 Options panel (panel 2)
Six checkboxes, listed in §2.2. Each has an `AddNewbieTip` with On and Off descriptions.

The setters are:
- `SetAutoSwitch`, which activates or deactivates all scripts.
- `SetShowMinimapButton`, which calls `LDB:Show/HideIcon`.
- `SetShowHotkeyMessages`, `SetShowTooltipInfo`, `SetShowItemComparisons`.
- `OutfitBar:SetShowOutfitBar`.

**Fix/Decide**: the auto-switch box is inverted (checked means disabled). The rewrite's AceConfig panel should present "Automatic outfit changes" as a positive option.

### 7.5 About panel (OutfitterAbout.lua)
- Title "About Outfitter Reborn", "Originally created by John Stephen", "Updated for WoW Midnight by aDd1kTeD2Ka0s", "Copyright 2006 - 2018 John Stephen", the thanks line, and an animated **credits rain**:
  - A new credit spawns every 1.2 s.
  - It fades in over 0.8 s and falls at −50 acceleration.
  - The list is shuffled.
  - The player's own realm is over-weighted at 2 % per player, capped at 50 %.
  - Frames are pooled.
- **Keep the credits.** The animation is optional.

### 7.6 Outfit bar (OutfitterBar.lua, OutfitterUITools.lua)
- One bar per category with shown outfits (`OutfitterOutfitBar<n>`): DIALOG strata, `ActionButtonTemplate` buttons, a 1×N or N×1 layout, and a background built from `Textures\QuickSlotsBackground` (`Style.ButtonBar`: 37 px buttons, 128 px texture).
- The stack direction follows the anchor quadrant.
- Rebuilt on WEAR, UNWEAR, ADD, DELETE and EDIT, coalesced with a 0.01 s unique task.
- Hidden during pet battles.
- Alpha switches to `CombatAlpha` in combat.
- **Button**:
  - The icon comes from `GetOutfitTexture`:
    1. outfit icon
    2. `cDefaultScriptIcons` by ScriptID, then StatID, then name
    3. a single item's icon
    4. 132662
  - Checked when worn.
  - Left click wears the outfit, or removes it if it is a worn non-Complete outfit (HasHWEvent).
  - **Alt + drop** from the cursor sets the icon. **Fix**: the spell path uses the removed `GetSpellTexture`.
  - Dropping an **item** creates a new outfit named after the item, adds it and wears it.
  - Right click opens the outfit menu via LibDropdown at the cursor. **Keep the comment at 792-835**: pooled frames go stale, so check `.released` and `IsShown`.
  - Hover shows the outfit tooltip and reveals the drag handles.
- **Drag bars**: top or left handles (`Textures\TopDragHandle` / `LeftDragHandle`).
  - Dragging is refused when locked: "The outfit bar can't be moved because you've locked its position".
  - Right click toggles the settings popup.
  - Fades: handles 0.3 s, bar 0.5 s down to Alpha.
  - The position is saved to the nearest screen corner.
- **Settings popup** `OutfitBarSettingsDialog` (180×245), applied live with no OK:
  - Size 0.5-1.5, Alpha 0-1, Combat Alpha 0-1.
  - Vertical, Lock Position, Hide Background.
- **Choose-icon dialog** `OutfitterChooseIconDialog` (400×415), from the menu entry "Change Icon…":
  - A 6×5 grid with a faux scroll.
  - Sets: **Recommend** (wildcard + the outfit's items + defaults), Spellbook (professions only now), Inventory (equipped + bags), All, Items, Abilities (macro icons).
  - Search filter (case-insensitive).
  - Wildcard 134400 means "Outfitter will choose an icon for you" and saves `SetIcon(nil)`.
  - Enter or OK saves and dispatches EDIT_OUTFIT.
- **Fix**:
  - `ResetPosition` aliases the default table, so a reset after a drag can do nothing.
  - `_ButtonBar` allocates one extra button.
  - The `Solo` icon key does not match `SOLO`.
  - `FrameStopDragging` is undefined.
  - LibButtonFacade is dead. **Decide**: Masque support or none.

### 7.7 Outfit context menu (`AddOutfitMenu`, 2348-2582; `OutfitMenuActions`, 6432-6563)
Opened from a row's menu button, a row right click, or a bar right click. It auto-hides 0.1 s (0.2 s on the bar) after a selection.

| Section | Entry | Action |
|---|---|---|
| General (titled with the outfit name) | Rename | `RENAME` |
| | Key Binding: None / Outfit 1-10 | `BINDING_<n>` / `BINDING_NONE` |
| | Title submenu: None + known titles sorted, in chunks of 30 | `TITLE_<id>`, then `UpdateOutfitDisplay` 0.5 s later |
| | Bank: Deposit, Deposit Unique, Withdraw, divider, Deposit Others, Withdraw Others (disabled unless the bank is open) | `DEPOSIT*` / `WITHDRAW*` |
| | Unequip others (non-Complete only) | `UNEQUIP_OTHERS` |
| | Ignore comparisons | `IGNORE_COMPARISONS` |
| | Delete | `DELETE`, with confirmation |
| Rebuild | Set to current items | `SET_CURRENT`, with confirmation |
| | Rebuild for <stat> (only with StatConfig or StatID) | `REBUILD`, with confirmation |
| | Rebuild for… | `REBUILD_FOR`, the dialog |
| Automation | "Script: <name\|Custom\|None>" submenu: No script; Edit script… (custom scripts only); one submenu per category, presets filtered by class, "..." appended when a preset has inputs, the description as tooltip | `PRESET_NONE` / `EDIT_SCRIPT` / `PRESET_<id>` (opens settings when the preset has inputs) |
| | Script settings… / Disable script / Disable outfit in combat (all disabled without a script) | `SCRIPT_SETTINGS` / `DISABLE` / `COMBATDISABLE` |
| Outfit Bar | Show in outfit bar / Change icon… | `OUTFITBAR_SHOW` / `OUTFITBAR_CHOOSEICON` |

Also `REBUILD_STAT_<id>` and `IGNORETITLE`. Unknown action IDs are ignored.

Category names come from `cScriptCategoryName`, or from the localized class name, using the female form when `UnitSex == 3`.

**Fix**: `cChangeIcon` gets a doubled "...", and the title sentinel branch is unreachable.

### 7.8 Minimap / LDB
- LDB launcher `"Outfitter"`:
  - `icon` and `text` follow the current outfit (`GetCurrentOutfitInfo`), falling back to the addon name and icon.
  - **Left click** toggles the outfit menu. **Any other button** runs `ToggleUI(true)`.
  - There is no tooltip. **Decide**: add one; `cMinimapButtonTitle` and `cMinimapButtonDescription` already exist unused.
- Minimap icon: `LibWithFreeDragDBIcon`, a custom LibDBIcon. **Holding a modifier at drag start enables free drag**, saving `{x,y}`.
- Menu (`GetMinimapDropdownItems`, OutfitterMinimapButton.lua):
  - Title.
  - "Open Outfitter".
  - The auto-switch toggle.
  - Then visible outfits per category: icon plus a colour (red for missing, blue for banked), checked when worn.
  - Click: **any modifier** runs `AskSetCurrent`. Otherwise a worn non-Complete outfit is removed, and anything else is worn.
  - Nothing happens before init.

### 7.9 Dialogs and popups
- `NameOutfitDialog` (5880-6257):
  - 315×207, modal, DIALOG strata.
  - Name box; Enter means Done.
  - Automation dropdown. Picking a preset auto-fills the name when the name is empty or still the previous auto-fill.
  - Build radio: empty / current (default) / create using (multi-stat).
  - Errors: `cNameAlreadyUsedError`, and `cNoItemsWithStatError` from a trial generation. Done is disabled while the name is empty.
  - Rename mode shows only the name, and the dialog is 65 px shorter.
- `RebuildOutfitDialog` (6260-6386): multi-stat only. It seeds `StatConfig` from a legacy `StatID`. **Fix**: its `Update` is a broken copy.
- Script editor: §9.8.
- Genetic progress window: §3.6.
- StaticPopups (all `timeout=0`, `whileDead`, `hideOnEscape`):
  - `OUTFITTER_CANT_RELOADUI`
  - `OUTFITTER_SERVER_FULL`
  - `OUTFITTER_CANT_SET_ICON` (dead)
  - `OUTFITTER_CONFIRM_DELETE` (`%s`). **Fix**: the leaked global `gOutfitter_OutfitToDelete`
  - `OUTFITTER_CONFIRM_REBUILD`
  - `OUTFITTER_CONFIRM_SET_CURRENT`
  - `OUTFITTER_CONFIRM_RESET`
- **Fix**: MC2UIElementsLib replaces the global `StaticPopup_EscapePressed`, which is a taint risk.

### 7.10 Chat output
MC2DebugLib:
- `NoteMessage` prints with a `[Outfitter]` prefix (`|cff99ffcc`).
- `ErrorMessage` prints with a red `[ERROR]` prefix.
- Debug output goes only to a chat tab named "Debug".

The rewrite will move this onto LibKa0s output.

---

## 8. Automation engine: special states and zones

### 8.1 Special-state sources
- **Shapeshift** (`UpdateShapeshiftState`, 4787-4847):
  - `cShapeshiftIDInfo` (1297-1307): 5487 Bear (`MaybeInCombat`), 768 Cat, 783 Travel, 24858 Moonkin, 1784 rogue Stealth.
  - `CasterForm` is a druid pseudo-form, active when no other form is.
  - The form index cache lives in `Settings.ShapeshiftIndexInfo`.
  - It re-polls every 0.1 s while `Suspended` (on loading screens the forms vanish briefly).
  - It runs 0.01 s after each aura update ("since 2.3 shapeshift info isn't up-to-date when the AURA event arrives").
- **Auras** (`GetPlayerAuraStates`, 4631-4675). **Keep all of this.**
  - **Avoid the aura APIs entirely while `C_RestrictedActions.IsAddOnRestrictionActive` is true** for Combat, Encounter, ChallengeMode or PvPMatch. The types are resolved *by name* from `Enum.AddOnRestrictionType`, because Combat is 0 and a nil would leave a hole. Since 12.1 the reads raise instead of returning nothing.
  - While restricted, every state reads false. `RegenEnabled` and `UNIT_AURA` restore them.
  - The scan is bounded to 100 auras. **`IsSecret(aura)` is checked before the nil test**, and a secret aura is skipped, not treated as the end of the list.
  - Matching is icon-first, through `cAuraIconSpecialID` (134062 and 132805 map to Dining), then spell, through `cSpellIDToSpecialID` (12051 Evocate, 2645 GhostWolf, 5384 Feigning, 58984 Prowl/Shadowmeld).
- **Mounted**: `IsMounted() and not UnitOnTaxi("player")`.
- **Swimming**: `IsSwimming()`.
- Both are polled in the 0.5 s `UpdateSwimming` tick, which also dispatches `TIMER`.
- `SetSpecialOutfitEnabled(id, on)` (4876-4915):
  - Coerces the value to boolean and returns if it is unchanged.
  - Dispatches `cSpecialIDEvents[id].Equip` or `.Unequip`.
  - Errors "No events found for <id>" when the mapping is missing.
  - **Fix**: enabling Dining registers UNIT_HEALTH, but *any other* state change unregisters it.

### 8.2 Zone detection (map-ID based; Outfitter.lua:1128-1271, 4925-5056)
- `UpdateZone` (0.01 s debounce) exits early only if **instance type, instance map ID and zone text are all unchanged**. Keep the comment at 4929-4938: Ashran and Wintergrasp each name both a zone and a BG.
- `GetCurrentZoneIDs`:
  - `pvp` gives Battleground. `arena` gives Battleground and Arena. That way a brand-new map still triggers the generic outfits.
  - It then adds `cInstanceMapIDZoneIDs[select(8, GetInstanceInfo())]`.
  - **It never matches on a zone name.**
- The first time an ID is seen, its state is seeded from `WearingOutfitWithScriptID`.
- **`cZoneSpecialIDs` (1138-1175) is ordered**: later entries are worn over earlier ones, so a map-specific outfit beats the generic one.
- **`cInstanceMapIDZoneIDs`** (1187-1271) is the Map.db2 row ID → special IDs table. Regenerate it from wago.tools Map.db2 (InstanceType 3 or 4), never from memory.
  - Battlegrounds:
    - AV: 30, 2197
    - AB: 529, 1681, 2107, 2177
    - WSG: 489, 2106
    - EotS: 566, 968
    - SotA 607, IoC 628, TwinPeaks 726, Gilneas 761, Wintergrasp 2118, Silvershard 727, Kotmogu 998
    - Deepwind: 1105, 2245
    - Seething 1803, Deephaul 2656, Ashran 1191
  - Brawls, generic Battleground only: 1170, 1280, 1691, 2799.
  - Arenas, which also set Battleground and Arena:
    - Lordaeron 572, Sewers 617
    - Blade's Edge: 562, 1672
    - Nagrand: 559, 1505
    - Tol'Viron 980, Tiger's Peak 1134, Black Rook 1504, Ashamane 1552, Hook Point 1825, Mugambala 1911, Robodrome 2167, Empyrean 2373, Maldraxxus 2509, Enigma 2547, Nokhudon 2563, Cage of Carnage 2759.
- **Invariant: five tables move together.** Adding a BG or arena touches `cInstanceMapIDZoneIDs`, `cZoneSpecialIDs`, `cSpecialIDEvents` (996-1056), `BuiltinEvents` (466-616) and `PresetScripts`. Four presets sat dead for years because one table was missed. tests/test_zones.lua enforces this. The rewrite should derive the dependent tables from a single source table.
- `InZoneType(type)` is public script API, pinned by tests. `InBattlegroundZone()` is true for pvp or arena.

### 8.3 `BuiltinEvents` (466-616)
These are pseudo-events that **must never reach `RegisterEvent`**; since 8.0 registering a non-existent event throws.
- Single: `TIMER`, `GAMETOOLTIP_SHOW`, `GAMETOOLTIP_HIDE`.
- `X`/`NOT_X` pairs:
  - `BATTLEGROUND`, `BATTLEGROUND_ARENA`
  - `BATTLEGROUND_` + one of AV, AB, WSG, EOTS, SOTA, IOC, TWINPEAKS, GILNEAS, WG, SILVERSHARD, KOTMOGU, DEEPWIND, SEETHING, DEEPHAUL, ASHRAN, LORDAERON, SEWERS, BLADESEDGE, NAGRAND, TOLVIRON, TIGERSPEAK, BLACKROOK, ASHAMANE, HOOKPOINT, MUGAMBALA, ROBODROME, EMPYREAN, MALDRAXXUS, ENIGMA, NOKHUDON, CAGEOFCARNAGE
  - `CASTER_FORM`, `BEAR_FORM`, `CAT_FORM`, `TRAVEL_FORM`, `MOONKIN_FORM`, `TREE_FORM`
  - `STEALTH`, `MOUNTED`, `SPIRIT_REGEN`, `GHOST_WOLF`, `FEIGN_DEATH`, `SWIMMING`, `CITY`, `EVOCATE`, `DINING`
- `OUTFIT_EQUIPPED` and `OUTFIT_UNEQUIPPED` are routed per outfit (§9.5).
- Never produced: `CITY` (retired) and `ARGENT_DAWN`, which is also absent from this table. `EVOCATE` fires but has no preset.

### 8.4 Dining and Spirit (`UnitHealthOrManaChanged`, 1769-1821)
- **Dining**: while dining, `PlayerIsFull()` auto-removes the outfit. `UpdateAuraStates` also suppresses Dining when the player is full.
- `PlayerIsFull` (1887-1930):
  - Health at least 85 %.
  - Mana above 85 %; a power type other than mana counts as full.
  - **Every unreadable or secret value means "not full".** The comments record two past bugs that removed the outfit mid-meal.
- **Spirit (five-second rule)**:
  - A mana drop within 10 s of `UNIT_SPELLCAST_SENT` cancels Spirit.
  - It re-enables after 5 s (`SpiritRegenTimer`).
  - `CheckSpellcastManaDrop` is rescheduled at 0.01 s.
  - **`PreviousManaLevel` is kept through secret windows.** A nil would make the next sample look like a drop.

---

## 9. Scripting

### 9.1 Script text format (`ParseScriptFields`, OutfitterScripting.lua:1859-1914)
- Directives are matched by `--%s*$([%w_]+)([^\r\n]*)`, with the name upper-cased.
- `-- $EVENTS A B C`: space-separated. Several lines concatenate. Required, or the script fails with "does not specify any events".
- `-- $DESC text`: the last one wins.
- `-- $SETTING <lua table body>`: wrapped as `return { … }` and evaluated. Two forms:
  - shorthand `Name="type"`, which gets the label `Name` (plus ":" unless boolean)
  - table form `{type, label, default, zonetype, suffix}`, keys case-insensitive
  - Labels may be expressions, for example `Outfitter:GetTalentTreeName(1)`.
  - **A nil label skips the field** (Tree4 hides for 3-spec classes).
  - A compile error returns `nil, msg`.

### 9.2 Execution wrapper (1835-1854)
- The chunk is `cScriptPrefix .. user .. cScriptSuffix`, loaded with `loadstring(…, "Script for <outfit>")`. It returns `function(self, event, ...)`.
- The prefix:
  - returns early if `outfit.Disabled`, or if `CombatDisabled` and (`InCombat` or `MaybeInCombat`)
  - exposes the locals `outfit`, `equip`, `immediate`, `layer`, `delay`, `interrupt`, `didEquip`, `didUnequip`, `isEquipped`, `time = GetTime()`, `setting = outfit.ScriptSettings`, `run = Outfitter.Run`
  - wraps the user code in `if true then … end`
- The suffix calls `self:PostProcess(equip, immediate, layer, delay, interrupt, time)`.
- There is no sandbox: scripts have full `_G`.
- `self` is the per-outfit `_ScriptContext`, with `RegisterEvent`, `UnregisterEvent`, `UnregisterAllEvents` and `Debug(fmt, …)`. Ad-hoc state stored on it is lost on re-activation.
- The user script API must keep the old `Outfitter:` names (§10.3).

### 9.3 PostProcess (2125-2187)
- `equip == true`: wear with `(layer, callerIsScript=true)` if not worn. Complete outfits are always re-worn, "so that the stack clears".
- `equip == false`: remove if worn.
- `interrupt` sets `InterruptCasting`.
- `delay` applies only when the outfit actually changed. It calls `SetUpdateDelay(start, delay)`, which pushes `LastEquipmentUpdateTime` to `start + delay − 1.5`, so a later event can cancel the change. The druid caster-form `delay=0.1` relies on this.
- `equip == nil` with `layer` set: `TagOutfitLayer`.
- All of this runs inside a Begin/End bracket, with `immediate` forcing it.
- **Fix**: the CPU lockup guard (>0.1 s runs, more than 20 times, at <0.5 s spacing → "Excessive CPU time in script for %s, script deactivated.") never trips, because it reads `self.Outfit.LastScriptTime`.

### 9.4 Lifecycle
- `ActivateScript` (1916-1987):
  - Returns early if auto-switch is off, the outfit is disabled, or it has no script.
  - Parses the fields.
  - Fills `ScriptSettings` defaults when a value is nil or the wrong type. An unknown type errors "unknown $SETTING type".
  - Compiles. A failure prints "Couldn't activate script for %s".
  - Registers the events, then dispatches the script event `INITIALIZE`.
- `DeactivateScript` dispatches `TERMINATE`, then unregisters everything.
- `ActivateAllScripts` runs at init (after `OUTFITTER_INIT`, only with auto-switch on) and on every auto-switch toggle.
- `GetScript(outfit)` (2281-2293) **resolves the preset text live** on every call. It strips `\r`, turns tabs into 4 spaces and returns `(text, id)`. **Keep**: editing a preset changes behaviour for existing users with no migration.
- `SetScript` / `SetScriptID` are mutually exclusive, and `""` becomes nil. **Fix**: they notify `SelectedOutfit` rather than the outfit that changed.
- `SetScriptEnabled(outfit, on)` toggles `Disabled` and activates or deactivates.
- `FindMatchingPresetScriptID(text)` is an exact compare.

### 9.5 Event routing (`_ScriptContext:RegisterEvent`, 2087-2100)
- `OUTFIT_EQUIPPED` / `OUTFIT_UNEQUIPPED` go to `OutfitScriptEvents[id][outfit]`. They fire only for that one outfit, under pcall.
- An ID in `BuiltinEvents` goes to `RegisterCustomEvent`.
- Anything else is registered as a real WoW event. Unknown events raise.
- **Fix**:
  - A TIMER script error inside the `UpdateSwimming` bracket strands the update count *and* kills TIMER.
  - Lockpicking and Riding can register TIMER twice and raise.

### 9.6 Script generators (217-492)
- `GenerateScriptHeader(events, desc)`.
- `GenerateSimpleScript(ev, desc)`: equip on `ev`, unequip on `NOT_ev`.
- `GenerateSmartUnequipScript(ev, desc, delay, specEnables)`:
  - Unequips **only if `didEquip`**, so a manual equip is never auto-removed.
  - Spec enables add `ACTIVE_TALENT_GROUP_CHANGED` and `Tree1..4` (default true).
- `GenerateDruidShapeshiftScript(ev, desc)`:
  - Settings DisableBG, DisablePVP, UnequipComplete (all false) and Tree1-4 (true).
  - Skips when not `HasFullControl()` and not dead.
  - `OUTFIT_EQUIPPED` tags the layer `"shapeshift"`.
  - The unequip is **delayed 2 s in combat** so the druid can self-heal without losing a GCD.
- `GenerateGatheringScript(text, desc)`:
  - Events GAMETOOLTIP_SHOW and GAMETOOLTIP_HIDE, setting `ignoreDifficulty`.
  - Equips when the tooltip line is an exact match at line > 1 and is difficult (orange or red).
  - Unequips on hide with `delay=1`, so the outfit doesn't flicker.
- `GenerateLockpickingScript`: GAMETOOLTIP_SHOW registers TIMER. It requires `SpellIsTargeting()` and the difficult-coloured `cRequiresLockpicking` line, and unequips with `delay=1`.
- `ScriptModules` (RogueStealth, AutoLootOnEquip).
- Unused: `GenerateShapeshiftScript`, `ScriptModules.DruidShapeshift`, `GenerateDisableModule`.

### 9.7 Preset scripts (`Outfitter.PresetScripts`, OutfitterScripting.lua:494-1759)
- Each preset has `{Name, ID, Category | Class, Script}`.
- Category order: GENERAL, TRADE ("Activities"), PVP, QUEST ("Questing"), ENTERTAIN ("Entertainment"), then class. Sorted by category, then name.
- Spec presets `SPECIALIZATION_1..4` are installed at init (`InstallTalentTreeScripts`, 1771-1803).
- The preset **bodies** are the spec. Port them verbatim (§9.9 lists the bug fixes) and keep the IDs stable, because outfits store `ScriptID`.

| ID | Cat/Class | Events | Behaviour, settings (default) | Status |
|---|---|---|---|---|
| HERBALISM | TRADE | tooltip | Gathering on `LBI.Herbalism` | live |
| MINING | TRADE | tooltip | Gathering on `LBI.Mining` | live |
| SKINNING | TRADE | tooltip | Gathering on `UNIT_SKINNABLE_LEATHER` | live |
| LOCKPICKING | TRADE/ROGUE | tooltip+TIMER | Lockpicking | Fix double-register |
| PVP_FLAGGED | PVP | PLAYER_FLAGS_CHANGED, PEW | Edge-triggered `UnitIsPVP`, via `outfit.wasPvP` | live |
| IN_DUNGEON | GENERAL | PEW | Enable5Man (true), EnableRaid, EnableBG, EnableArena (false) | **Fix**: arena reads EnableBG (565) |
| TRINKET_QUEUE | GENERAL | TIMER | stringtable Trinkets / Trinkets2. `FindNextCooldownItem(list, true)`; skips while the current trinket is active (`InventoryItemIsActive`). Refuses EM outfits | live |
| FEET_QUEUE "Rocket Boots" | GENERAL | TIMER | stringtable Boots | live |
| IN_ZONES | GENERAL | ZONE_CHANGED* | zonelist `zoneList` (GetZoneText), zonelist `minimapZoneList` (zonetype MinimapZone). Unequips only if didEquip | live (name-based, localized) |
| TalentTree | GENERAL | ACTIVE_TALENT_GROUP_CHANGED, PLAYER_TALENT_UPDATE | Tree1-4 (false), delay 0.5 | live |
| Riding | TRADE | MOUNTED, NOT_MOUNTED (+TIMER) | DisableBG (true), DisableInstance (true), DisablePVP (false), StayEquippedWhileFalling (false), UnequipDelay number 0 (suffix "seconds before unequipping"). The falling path waits until dismount+1 s and not `IsFalling()` | live; Fix double-register |
| Swimming | TRADE | SWIMMING, NOT_SWIMMING | DisableInstance, DisableBG, DisablePVP (false), DisableVashjir (true; uiMaps 204/201/205). Unequip only if didEquip, delay 2.5 (jumping briefly stops swimming) | live |
| Fishing | TRADE | OUTFIT_EQUIPPED/UNEQUIPPED | EnableFishTracking (true; tracking texture 133888), EnableAutoLoot (false; CVar autoLootDefault), DisableClicktoMove (true; CVar autointeract), ChangeActionBar (false), ActionBarNumber (1). Saves and restores in `setting.*` | live; Fix the undefined `equipped` |
| Dining | TRADE | DINING, NOT_DINING | smart-unequip | live |
| City "Around Town" | ENTERTAIN | CITY | simple | **dead**: CITY is never fired |
| Battleground, Arena, and 31 per-map presets (AV…CageOfCarnage) | PVP | `BATTLEGROUND_*` | smart-unequip with spec enables (908-1097) | live |
| Spirit "Spirit Regen" | GENERAL | SPIRIT_REGEN | smart-unequip, delay 0.5 | live |
| Caster | DRUID | CASTER_FORM, NOT_CASTER_FORM, OUTFIT_EQUIPPED | DisableInstance, BG, PVP (false), Tree1-4 (true). **delay 0.1** cancels the transient caster form between shifts | live |
| Bear, Cat, Travel, Moonkin, Tree | DRUID | `*_FORM` | druid shapeshift generator | live |
| Prowl | DRUID | STEALTH | simple | live |
| Stealth | ROGUE | STEALTH, NOT_STEALTH, OUTFIT_EQUIPPED/UNEQUIPPED | RogueStealth + AutoLoot module | live; Fix nil `pSettings` |
| GhostWolf | SHAMAN | GHOST_WOLF | simple | live |
| Feigning | HUNTER | FEIGN_DEATH | simple | live |
| SOLO | GENERAL | PEW, GROUP_ROSTER_UPDATE | EquipSolo, Normal5, Heroic5, Normal10, Heroic10, Normal25, Heroic25, RaidFinder, Challenge, Normal40 | **Fix**: legacy difficulty IDs; Solo never matches the open world. Remap to 0/1/2/8/14-17/23/208 |
| LOW_HEALTH | GENERAL | stub | settings Health, Mana | **retired** (secret health and power) |
| HAS_BUFF | GENERAL | UNIT_AURA, PEW | string buffName; DisableInstance, BG, PVP. `C_UnitAuras.GetAuraDataBySpellName`, which returns nil while restricted | **Fix**: returns early on PEW |
| HAS_DEBUFF | GENERAL | stub | | **retired** (UnitDebuff) |
| EQUIP_ON_TARGET | GENERAL | PLAYER_TARGET_CHANGED | string targetName | **Fix**: nil target raises; never unequips; not secret-guarded |
| FALLING | TRADE | TIMER | `IsFalling()`, delay 4; unequip if didEquip | live |
| RESTING | TRADE | PLAYER_UPDATE_RESTING, PEW | `IsResting()` | live |
| ARGENT_TOURNY | QUEST | tooltip, UPDATE_MOUSEOVER_UNIT, UNIT_ENTERED/EXITED_VEHICLE | vehicle GUIDs + stabled-mount NPCs (33790-33843, 36557/36558, 33870, 34125); unequip delay 1; entering a vehicle within 3 s cancels | legacy but live |
| VIGILANCE_ON_WINGS | QUEST | same | NPCs 39710/40719/40720/40723 | legacy; empty description |
| FLAME_LEVIATHAN | QUEST | same + REGEN_ENABLED | vehicles 33060/33109/33062; waits for out-of-combat | legacy |
| MULTI_SURVEY | QUEST | QUEST_LOG_UPDATE + zone events | uiMap 107, quest 11880, delay 5 | **Fix**: `PlayerIsOnQuestID` uses a legacy quest API; use `C_QuestLog.IsOnQuest` |
| QUEST_TURNIN | QUEST | QUEST_PROGRESS, QUEST_FINISHED | equip on progress | live |
| SPELLCAST | TRADE | UNIT_SPELLCAST_START | string spell, boolean dontWait (interrupt) | **Fix**: compares the castGUID; use the spellID / `C_Spell.GetSpellName` |
| DANCE | ENTERTAIN | OUTFIT_EQUIPPED | `DoEmote("DANCE")` | live |
| COMPANION | ENTERTAIN | OUTFIT_EQUIPPED | string pet. `SummonCompanionByName(pet, 2)`, else "Couldn't find a pet named %s" | live |
| COOKING | TRADE | TRADE_SKILL_SHOW/CLOSE | professionID 185. Ragnaros, Pierre, RandomCookFirePet (false) summon a pet with a 0.2 s delay, then restore the previous pet | live; dead TRADE_SKILL_UPDATE branch |
| CHAMPFACTION, CHAMP, CHAMPCATACLYSM | QUEST | stub | | **retired** (GetMapNameByID) |
| PETBATTLE | QUEST | PET_BATTLE_OPENING_DONE, PET_BATTLE_CLOSE | equip on opening. Credit: Bruce Quinton | live |
| SPECIALIZATION_1..4 | class | PEW, ACTIVE_TALENT_GROUP_CHANGED | `"<class>: <spec>"`. Acts only on a spec change; delay 0.5 "so artifacts equip properly" | live |

The retired stubs stay registered upstream so existing outfits still resolve. With a fresh store there are no existing outfits, so the rewrite may drop them (§18).

### 9.8 Script editor dialog (OutfitterScriptDialog.lua; Outfitter.xml:1468)
- `OutfitterEditScriptDialog`: 512×490, DIALOG strata, LEFT of OutfitterFrame +100.
  - Title "Script for %s outfit".
  - Preset dropdown ("Preset script:").
  - Tabs **Settings** (generated fields) and **Source** (multi-line edit box, 4000 characters, "Status:" line).
  - Cancel and OK. The close X **saves**. Esc closes via UIMenus.
- `Open(outfit, showSource)` copies the settings and opens the Settings tab, or Source when asked.
- Picking a preset overwrites the source with the preset text.
- Live check: "Typing...", then a 1.5 s debounce, then "OK" or "Error at line %d: %s".
- Fields are pooled per type: ScrollableEditBox 300×80, EditBox 300×18, ZoneListEditBox 180×80 with "<- %s" (current zone or minimap zone), Checkbox 24×24. "There are no settings for this script." when there are none.
- `Done`: an exact preset match calls `SetScriptID`, otherwise `SetScript`; then `ScriptSettings` is replaced.
- **Fix**:
  - The error-line rebase pattern never matches the chunk name.
  - `Done` wipes the runtime `setting.*` state (the Fishing restores).
  - Missing values fall back to the type default, not the `$SETTING default`.
  - `Suffix`/`suffix` and `"Number"` case mismatches.
  - A preset re-match can overwrite text the user typed.

### 9.9 Script-visible state and helpers
- Scripts write into `setting`: `savedAutoLoot`, `didSetAutoLoot`, `savedTracking`, `didSetTracking`, `savedMove`, `didSetMove`, `savedActionBar`, `didChangeActionBar`. They write `outfit.wasPvP` on the outfit.
- Helpers scripts call:
  - `Outfitter:Run(text)`: runs any slash command.
  - `InZoneType`, `InBattlegroundZone`.
  - `TooltipContainsLine(tt, text)` → `found, isDifficult, exact, line`.
  - `FindNextCooldownItem`, `InventoryItemIsActive`.
  - `ItemHasUseFeature`, `GetItemUseDuration`.
  - `Get/SetTrackingEnabled(texture)`.
  - `SummonCompanionByName/ByGUID`, `DismissCompanionByName`, `GetSummonedCompanionID`.
  - `PlayerIsOnQuestID`, `GetTalentTreeName`, `GetPlayerStat`.
  - `SpecialState`, `InCombat`, `IsDead`, `MaybeInCombat`, `InterruptCasting`.
  - `TagOutfitLayer`, `SetScriptEnabled`, `WearOutfit`, `RemoveOutfit`.
  - `GetInventoryCache`, `GetItemInfoFromLink`, `GetBagItemInfo`, `GetInventoryItemInfo`, `ParseItemLink2`.
  - `Begin/EndEquipmentUpdate`, `OutfitStack`.
  - `GetStatByID`, `StatCategories`.
- `Outfitter.LBI` gives localized profession names (Herbalism, Mining, Cooking). **Decide**: replace with `C_Spell` or profession IDs.

---

## 10. Public API (other addons, macros, user scripts)

### 10.1 Globals
These exist for OutfitterFu, FishingBuddy and ArkInventory (405-449). **Keep them unchanged.**
- `Outfitter_OnLoad`, `Outfitter_IsInitialized`, `Outfitter_Update`
- `Outfitter_FindOutfitByStatID` (kept for Fishing Buddy), `Outfitter_FindOutfitByName` (case-insensitive; returns outfit, categoryID, index)
- `Outfitter_GetCategoryOrder`, `Outfitter_GetOutfitsByCategoryID`, `Outfitter_HasVisibleOutfits`, `Outfitter_OutfitIsVisible`
- `Outfitter_GenerateSmartOutfit(name, stat, cache, allowEmpty)`, `Outfitter_AddOutfit`, `Outfitter_DeleteOutfit`
- `Outfitter_WearOutfit(outfit, categoryID, wearBelow)`. Only `outfit` is used.
- `Outfitter_RemoveOutfit`, `Outfitter_WearingOutfit`
- `Outfitter_RegisterOutfitEvent`, `Outfitter_UnregisterOutfitEvent`
- `Outfitter_GetCurrentOutfitInfo`, `Outfitter_SetShowMinimapButton`
- `Outfitter_GetItemInfoFromLink`, `Outfitter_GetOutfitsUsingItem`
- `OutfitterItemList_GetEquippableItems`, `OutfitterItemList_GetMissingItems`, plus the `Outfitter.ItemList_*` duplicates
- `Outfitter:OutfitUsesItem`
- `Outfitter_OnAddonCompartmentClick` (**Fix**: implement it)
- XML string globals (381-412):
  - `Outfitter_cTitle`, `cTitleVersion`, `cCreateUsingTitle`, `cAutomationLabel`
  - `cOutfitterTabTitle`, `cOptionsTabTitle`, `cAboutTabTitle`
  - `cNewOutfit`, `cNameAlreadyUsedError`, `cEnableAll`, `cEnableNone`, `cOptionsTitle`
  - `cEditScriptTitle`, `cEditScriptEllide`, `cPresetScript`, `cSettings`, `cSource`
  - `cIconFilterLabel`, `cIconSetLabel`
  - `cCompleteOutfits`, `cAccessoryOutfits`, `cOddsNEndsOutfits`
- `OutfitterAPI` (Compat.lua) with `IsSecret`, `Unsecret`, `UnsecretNumber` and the container and tracking shims.

### 10.2 `Outfitter:` methods (the table is global; scripts and bindings call these)
- **Outfits**:
  - `WearOutfit(outfit, layerID, callerIsScript)`, `RemoveOutfit`, `WearOutfitNow`, `RemoveOutfitNow`, `ToggleOutfit`, `ToggleOutfitNow`
  - `WearOutfitByName` / `RemoveOutfitByName`, which print an error when the name is not found
  - `WearingOutfit`, `WearingOutfitName`, `WearingOutfitWithScriptID`
  - `FindOutfitByName`, `FindOutfit`, `GetOutfitCategoryID`, `GetOutfitByName`, `GetIndexedOutfit`
  - `GetCurrentCompleteOutfit`, `GetCompiledOutfit`, `GetExpectedOutfit`, `GetInventoryOutfit`
  - `SetOutfitToCurrent`, `SetOutfitBindingIndex`, `WearBoundOutfit`
- **UI**: `OpenUI`, `ToggleUI`, `ToggleOutfitterFrame`, `IsOpen`
- **Automation**: `SetAutoSwitch`, `EnableAutoChanges`, `DisableAutoChanges`, `ActivateScript`, `DeactivateScript`, `ActivateAllScripts`, `DeactivateAllScripts`, `SetScript`, `SetScriptID`, `GetScript`, `SetScriptEnabled`, `GetPresetScriptByID`, the `Generate*Script` family
- **Items, stats and helpers**: listed in §3.4, §3.6 and §9.9
- **Data tables**: `PresetScripts`, `BuiltinEvents`, `StatCategories` (third parties may add categories via `GetNumStats`/`GetIndexedStat`), `OutfitBar` (`GetOutfitTexture`, `SetShowOutfitBar`, `ResetPosition`, `cDefaultScriptIcons`, and so on)

### 10.3 Shim rule
User scripts run arbitrary Lua against `Outfitter`. **The rewrite must keep every name in §10 as at least a thin shim.** tests/test_load.lua:70-118 pins a 13-function subset and asserts that no other `Outfitter*` global leaks.

---

## 11. Timers and scheduled tasks

| Delay | Task | Kind | Source |
|---|---|---|---|
| 1 s | `Initialize` after the last init event | reschedule | 5213 |
| 0.05 s | `PlayerEnteringWorld` | reschedule | 1522 |
| 0.5 s | `UpdateSwimming` (TIMER, mounted, swimming) | repeating, `"Outfitter:UpdateSwimming"` | 5474 |
| 0.01 s | `Synchronize` (inventory) | reschedule | Inventory:587 |
| max(0.05, 1.5−elapsed) | `UpdateEquippedItems` | unique | Equipment:983 |
| 1.5 s | min equipment update interval | constant | 453 |
| 0.5 s | `SetUpdateDelay` after a cast or channel ends | | 1863, 1878 |
| 2.0 s | `UpdateAuraStates` in combat | unique | 4733 |
| 0.01 s / 0.1 s | `UpdateShapeshiftState` after an aura / while suspended | | 4778, 4794 |
| 0.01 s | `UpdateZone` | reschedule | 4926 |
| 5.0 s | `SpiritRegenTimer` | reschedule | 1800 |
| 0.01 s | `CheckSpellcastManaDrop` | reschedule | 1815 |
| 0.1 s | `UpdateCurrentOutfitIcon` (dead) | unique | 1678 |
| 0.1 s | close the outfit menu / LDB menu after a pick | one-shot | 2896, LDB:71 |
| 0.2 s | close the bar menu after a pick | one-shot | Bar:812 |
| 0.5 s | `UpdateOutfitDisplay` after `TITLE_` | one-shot | 6607 |
| 2 s / 1 s | `SynchronizeCompanionState` (request / retry, uncapped) | | 8271-8358 |
| 0.01 s | `UpdateBars2` coalescing | unique | Bar:468 |
| 1.5 s | `CheckScriptErrors` debounce | reschedule | ScriptDialog:443 |
| 0 s | `RunGeneticThread` / `UpdateMovingFrame` | repeating | Optimize:356, UITools:518 |
| 0.02 s / 0.1 s | genetic coroutine yield | | Optimize |
| 0.05 s | window follow throttle | OnUpdate | 1391-1397 |
| 0.75 s | key-binding anti-spam | constant | 3723 |
| 1.2 s / 0.8 s | credits spawn / fade | OnUpdate | About |
| 0.3 s / 0.5 s | bar drag-handle / bar fade | UIFrameFade | Bar:241-252 |

---

## 12. Secret values (12.0): rules to preserve

The rule (Compat.lua:75-117): **check `IsSecret` before any other test, including truthiness.** Since 11.2 a secret cannot be compared, used in arithmetic, concatenated, measured or used as a key.

| Site | Handling to keep |
|---|---|
| Health, mana, power, power type (1785, 1892-1919) | `UnsecretNumber`. nil means unknown, the conservative branch is taken, and the last known mana is kept |
| UnitStat (6905-6907) | `UnsecretNumber(v, 0)` |
| UnitLevel (ItemStats:172, 390) | nil means don't filter |
| Item links (Inventory:169, 575, 629, 651; QuickSlots:72; bag type 4109) | `ParseItemLink2` is the choke point and returns nil for a secret link. A secret link reads as an empty slot |
| Aura records (4653-4665) | Restriction gate first, then `IsSecret` before nil, then `UnsecretNumber` on icon and spellId |
| Compare tooltip (7852, 7880-7882) | A secret link returns; secret geometry falls back to 0 |
| `FindTooltipLine` | pcall'd find |

**Fix** (unguarded today):
- `ShowLinkInfo` concatenation
- `RatingSummary` arithmetic
- `GetSortedTitles` compares
- `/unequip` name compares
- tooltip-hook links into `GetItemInfoFromLink`
- `TooltipContainsLine` text and colour
- `EQUIP_ON_TARGET` `UnitName`
- the vehicle presets' `UnitGUID("mouseover")`
- `FindNextCooldownItem` arithmetic
- `GetCursorTexture` compares
- `GetSpecializationInfo`, quest parsing, `GetIconIndex`
- `ItemHasUseFeature`, which indexes a nil parse

Any of these inside an update bracket strands the count.

## 13. Combat lockdown: rules to preserve
- No automated equipment swaps while `InCombat` or `MaybeInCombat`. They are queued and flushed by REGEN_ENABLED closing a bracket.
- Window reparent, position and strata changes are skipped under `InCombatLockdown()`. The slot-checkbox stacking is allowed.
- Secure row buttons are never toggled in combat. They are suspended and resumed on REGEN.
- Aura reads are avoided entirely while add-on restrictions are active.
- Companion sync waits for combat to end.
- `HasHWEvent` wraps user-initiated actions (slash, binding, bar click, title menu, TRADE_SKILL dispatch) so the title and EM calls that need a hardware event work.
- Bar buttons are non-secure and only request a wear.

---

## 14. Item and slot data tables (port as data)
- `cSlotNames` (850-878), in priority order, with the reverse index `cSlotOrder`. `cSlotIDs` and `cSlotIDToInventorySlot` are built from `GetInventorySlotInfo` at init. The 18 slots are Head, Neck, Shoulder, Back, Chest, Shirt, Tabard, Wrist, Hands, Waist, Legs, Feet, Finger0, Finger1, Trinket0, Trinket1, MainHand, SecondaryHand.
- `cSlotDisplayNames` (886-906).
- `cInvTypeToSlotName` (908-935): 2H maps to MainHand with meta `TwoHandSlot`, and INVTYPE_WEAPON to MainHand with meta `Weapon0Slot`. Ranged, thrown and relic map to MainHand.
- `cHalfAlternateStatSlot` and `cFullAlternateStatSlot` (937-952).
- `cItemAliases` (960-970) and `cIgnoredUnusedItems` (972-986).
- `PhantomItemIDs` (625-646): 18 Legion artifact off-hands.
- `cUniqueGemItemIDs` (648-769): TBC to MoP gem uniqueness groups (`PRISM3`, `FACET2`). Legacy. **Decide**: drop it if gem capture stays retired.
- `gOutfitterItemCorrections` (3903-3908): 6533 becomes a Consumable, 27503 a Scroll, 27515 Trade Goods/Meat.
- Colours: `BANKED_FONT_COLOR` (0.25, 0.2, 1.0) / `|cff4033ff`, and `OUTFIT_MESSAGE_COLOR` (0.2, 0.75, 0.3).
- `cDefaultScriptIcons` (OutfitterBar.lua:9-53): drop the retired keys. Spec icons are added at runtime.

## 15. Localization
- English base: `OutfitterStrings.lua` (354 assignments), with key tables such as `cScriptCategoryName`.
- Overlays, each guarded on its own locale: deDE (172), frFR (207), zhCN (282), zhTW (272), koKR (191), ruRU (277). The esES localizers are credited but there is no esES file.
- Every locale re-sets `cTitle = "Outfitter Reborn"`.
- `cVersion` comes from the TOC metadata.
- The rewrite moves to AceLocale and must carry every translated string across. tests/test_locale.lua's rules apply: no orphans, each file guards its own locale, no retired strings, and every string the addon reads exists in English.

## 16. Quirks to preserve (consolidated)
1. Detach-and-follow window, single SetPoint, pcall fallback (§7.1).
2. Strata matching, never a fixed strata, checkboxes first stacked in `SelectOutfit` (§7.1).
3. Secure row buttons are never re-anchored or reparented; spell-targeting clicks fall through to them (§7.2).
4. Update-count reset at PLAYER_ENTERING_WORLD before Begin, and the stuck diagnostic (§3.3).
5. Aura restriction gate, IsSecret before nil, bounded scan, icon-first match (§8.1).
6. `PlayerIsFull` treats unknown as not full; mana is kept through secret windows (§8.4).
7. Zones are map-ID based and never name-based. The ordered `cZoneSpecialIDs`, the three-field early-out, and the five tables in step (§8.2).
8. Pseudo-events never reach `RegisterEvent` (§8.3).
9. Preset scripts resolve live (§9.4).
10. Smart unequip only when `didEquip`; the druid 2 s combat delay; the caster 0.1 s delay; the gathering 1 s hide delay; swimming 2.5 s; the spec 0.5 s delay (§9).
11. A Complete outfit is always re-worn by scripts; Complete removal walks back the recents (§3.2).
12. Durability-first unequip order; unique-equip ranking; Titan's Grip fix; phantom off-hands (§3.3).
13. SFX muted during swaps by default (restore it reliably).
14. EM: name truncated to 31 characters, 134400 means no icon, zero-sets protection, own-save events ignored (§3.5).
15. BoE items are not equippable by outfits; the min-level check is disabled (§3.4).
16. Bag items have a 30 s minimum cooldown in `FindNextCooldownItem` (§3.4).
17. Key-binding 0.75 s anti-panic (§5).
18. The `SecureCmdOptionParse` macro conditionals in `/outfitter` (§4).
19. The LDB key `"Outfitter"` is permanent (§1).
20. Quick-slot track banding and upgrade-aware sort (§3.11).
21. The bar's LibDropdown stale-reference handling (§7.6).
22. `HasHWEvent` around user actions (§13).
23. The Horde lance alias swap at init.
24. `/unequip` is registered only if the slot is free.
25. The bank-closed "banked reads as missing" semantics, unless the rewrite deliberately scans the bank from a cache.

## 17. Upstream policy features: decide
- `X-ReloadTag` guard and the `OUTFITTER_CANT_RELOADUI` popup. Recommend dropping both.
- `BannedCharacters` (empty) and the sticky `GlobalSettings.Banned`. Recommend dropping.
- The hidden `daxdax` alias. Recommend dropping it, or keeping it silently.
- MobInfo2 tooltip hook, CT_Mod pickup compatibility, WeightsWatcher, LibButtonFacade. Recommend dropping all four. Masque is optional.
- The `PaperDollSidebarTabs` nudge. Keep it if the robe button stays where it is.
- The animated credits rain.

## 18. Retired and dead: do NOT carry over

**Retired** (in `Deprecated.lua`; the game removed the API):
- Void storage deposit and withdraw (`DepositOutfitToVoidStorage`, `WithdrawOutfitFromVoidStorage`; menu actions DEPOSITVOID, DEPOSITUNIQUEVOID, WITHDRAWVOID) and the `VoidStorageIsOpen` tracking.
- `CallCompanionByName`. `SummonCompanionByName` replaces it.
- Banked-item tooltip in the list row (`BankButtonIDToInvSlotID`).
- City and ArgentDawn zone detection, the City "Around Town" preset, and the `CITY` / `ARGENT_DAWN` events.
- Gem capture (`GetContainerItemGems` / `GetInventoryItemGems`).
- Legacy flyout location unpacking.
- The Spellbook part of the Spellbook icon set.
- Presets LOW_HEALTH, HAS_DEBUFF, CHAMPFACTION, CHAMP, CHAMPCATACLYSM.
- Hunter Aspect of the Hawk / Dragonhawk, and all legacy `AuraStates` keys (Monkey, Hawk, Cheetah, Pack, Beast, Wild, Viper, Dragonhawk).
- Locale strings for FuBar, aspects, stances, presences, monk stances and resistances.
- The TankPoints stat category.

**Dead code** (zero callers or cannot work):
- Profession smart outfits (`cSmartOutfits` is commented out), the `ArgentDawn` and `"Fishing"` StatID paths, and the non-base stat categories.
- `cCombatEquipmentSlots`, combat swaps disallowed since 3.3.
- The bag-sort work in progress (`gOutfitter_SortBagItems`, `gOutfitter_Categories`, `GetItemSortRank`, `RunThreads`).
- `OutfitSummary` (`/outfitter summary`), `GetItemLinkStats` (`/outfitter itemstats`), `RatingSummary` (`/outfitter rating`; stale indices).
- `CancelDialogs`, `UpdateCurrentOutfitIcon`, `UnitSpellcastDebug`, `GetBuffTooltipText`, `GetMountIDByName`, `ShowAllLinks`, `Hook`/`HookTable`, `InitializeFrameMethods`, `InitializeFrameWidgets`, `CheckOutfitCategories`, `GetOutfitByScriptID`.
- `_RebuildOutfitDialog:Update`.
- Unused engine helpers: `GetCategoryByID`, `ConstrainScore`, `ItemContainsStats`, `SortItemsByStat`, `CalcMinNumSlotsByStat`, `_OutfitIterator:Outfits/Next/GetOutfit`, `_MultiStat:GetFilterStats/CompareOutfits`, `IsFullyEquipped`, `LocationsEqual`, `InventorySlotIsEmpty`, `GetBagSlotItemName`, `GetBagList`, `FindOutfitByCategory`, `FindItemInfoByCode/BySlot`, the `Swap*` no-ops.
- Unused script generators: `GenerateShapeshiftScript`, `ScriptModules.DruidShapeshift`, `GenerateDisableModule`.
- QuickSlots `Close` / `InventoryChanged` hooks and the XML QuickSlot templates.
- XML: `OutfitterTooltip`, `Outfitter_SliderTemplate`, `Outfitter_ScrollFrameTemplate`, `Outfitter_ListButtonTemplate`.
- `CursorInFrame`, `AnchorDragBar`, `OUTFITTER_CANT_SET_ICON`.
- Unused libraries: **MC2ItemLinkLib**, **UTF8**, LibBabble-SubZone (used only by Deprecated.lua), LibButtonFacade.
- Removed events: `UNIT_MANA`, `CHARACTER_POINTS_CHANGED`.
- `Options.HideMinimapButton`, every `CheckDatabase` migration (fresh store), `gOutfitter_GlobalSettings.SavedScripts`.
- The `pIgnoreAmmo` parameter, the `/outfit` comment, `CHANGES.txt` (a stale upstream tag dump).

The fresh store means existing outfits referencing retired presets cannot exist, so the stubs and the `DeprecatedFeature` layer can go entirely. CLAUDE.md's "revive by taking it out of Deprecated.lua" rule then no longer applies.

## 19. Bug list: fix in the rewrite (do not copy)

**Core:**
- `/unequip` arity and its missing return.
- `DispatchOutfitEvent` treats a handler's return value as an error.
- `SetScript*` notifies the wrong outfit.
- Rebuild applies the result twice.
- `GetInventoryOutfit` compares `UpgradeItemID`, not `UpgradeTypeID`.
- Inverted sound messages; inverted auto-switch checkbox.
- `AskReset` calls `strlower(nil)`.
- Leaked global `gOutfitter_OutfitToDelete`.
- `AzeriteCodesMatch` uses `#` on a set.
- The banked tooltip line is red.
- The Dining UNIT_HEALTH unregistration.
- `WithdrawOtherOutfits` is broken; `vExpectedInventoryCache` is undefined.
- The compartment function and `OutfitterMinimapButton` are undefined.
- The tab id/name cross; the swapped Enable All/None names; the doubled "...".
- `UPDATEOUTFIT` with no Complete outfit.
- The companion retry is uncapped.

**Engine:** B1-B20 (§3.3-§3.6 and the engine notes), especially:
- `findChangeForSlot` always nil (B1)
- the cache event leak (B5)
- SFX stuck off on a raise (B8)
- the stack desync (B6)
- English-only stat names (B13)
- bonus-ID capture (B12)
- the `ItemsAreSame` vs `FindItem` mismatch

**Scripting:**
- The lockup guard never trips.
- TIMER errors strand the count and kill the event.
- TIMER can register twice.
- SPELLCAST compares the castGUID.
- HAS_BUFF ignores PEW.
- IN_DUNGEON arena reads EnableBG.
- SOLO uses legacy difficulty IDs.
- EQUIP_ON_TARGET nil target.
- MULTI_SURVEY uses a legacy quest API.
- Dialog: line rebase, setting wipe, default fallback, key-case mismatches, preset re-match overwrites text.
- Stealth passes a nil `pSettings`.
- Fishing's undefined `equipped`.

**Bar:**
- The alt-drop spell icon uses removed APIs.
- `ResetPosition` aliasing.
- The `ShowOutfitBar` default differs between fresh install and repair.
- The `Solo` icon key.
- `_ButtonBar` allocates one extra button.
- `FrameStopDragging` is undefined.

**Libraries:** MC2EventLib does not isolate errors and drops re-entrant dispatches. MC2UIElementsLib replaces `StaticPopup_EscapePressed`.

## 20. Test coverage today (for parity)
Suites: harness 8, syntax 3, eol 3, toc 6, xml 6, load 18, compat 5, zones 16, scripts 15, locale 6, deprecated 11, secrets 20, outfits 17, commands 11. Total 144.

The rewrite's suite should at least re-pin:
- the zone five-table invariant
- preset well-formedness, compile and event coverage
- the secret-value paths and the update-count balance
- the slash command, help and manual parity
- the public API globals and the leak check
- the LDB identity
- the credits

Nothing tests the change engine, unique-equip ordering, the optimizer, ItemStatsLib or the EM mirror. All of that is in-client only.
