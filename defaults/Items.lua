local _, NS = ...
-- defaults/Items.lua — NS.ItemData: slots, inventory types, alternates, aliases, ignored items, phantoms
-- and corrections (design §5.1, INV §14). Pure data with one builder, ApplyFactionAliases.
--
-- Every table is the legacy one at 7ea3dc3 (Outfitter.lua, cited per table) with the retired keys left
-- out; tests/test_slots.lua compares each against tests/fixtures/legacy/slots.lua.

local L = NS.L

NS.ItemData = NS.ItemData or {}                      -- architecture-§3 idempotent
local ID = NS.ItemData

-- The 18 equipment slots in priority order (Outfitter.lua:850-878). The order is load-bearing: the
-- change engine equips in it, so the slots that carry durability go first.
ID.SLOT_NAMES = {
    -- First priority goes to armor
    "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    -- Second priority goes to weapons
    "MainHandSlot", "SecondaryHandSlot",
    -- Last priority goes to items with no durability
    "BackSlot", "NeckSlot", "ShirtSlot", "TabardSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
}

-- slot name -> its index in SLOT_NAMES
ID.SLOT_ORDER = {}
for i, name in ipairs(ID.SLOT_NAMES) do ID.SLOT_ORDER[name] = i end

-- The slot's display label (Outfitter.lua:886-906). Fourteen slots have a GlobalString of their own,
-- named here and read at call time; the two rings and the two trinkets need their position in the
-- label, which no GlobalString carries, so theirs are L strings.
ID.SLOT_LABEL_KEYS = {
    HeadSlot = "HEADSLOT", NeckSlot = "NECKSLOT", ShoulderSlot = "SHOULDERSLOT", BackSlot = "BACKSLOT",
    ChestSlot = "CHESTSLOT", ShirtSlot = "SHIRTSLOT", TabardSlot = "TABARDSLOT", WristSlot = "WRISTSLOT",
    HandsSlot = "HANDSSLOT", WaistSlot = "WAISTSLOT", LegsSlot = "LEGSSLOT", FeetSlot = "FEETSLOT",
    MainHandSlot = "MAINHANDSLOT", SecondaryHandSlot = "SECONDARYHANDSLOT",
}
ID.SLOT_LABELS = {
    Finger0Slot  = L["First finger"],
    Finger1Slot  = L["Second finger"],
    Trinket0Slot = L["First trinket"],
    Trinket1Slot = L["Second trinket"],
}

-- An item's inventory type -> the slot it goes in, and the meta slot the optimizer pairs it on
-- (Outfitter.lua:908-935). Ranged, thrown and relic all live in the main hand since Legion.
ID.INVTYPE_TO_SLOT = {
    INVTYPE_2HWEAPON       = { slot = "MainHandSlot", meta = "TwoHandSlot" },
    INVTYPE_BODY           = { slot = "ShirtSlot" },
    INVTYPE_CHEST          = { slot = "ChestSlot" },
    INVTYPE_CLOAK          = { slot = "BackSlot" },
    INVTYPE_FEET           = { slot = "FeetSlot" },
    INVTYPE_FINGER         = { slot = "Finger0Slot" },
    INVTYPE_HAND           = { slot = "HandsSlot" },
    INVTYPE_HEAD           = { slot = "HeadSlot" },
    INVTYPE_HOLDABLE       = { slot = "SecondaryHandSlot" },
    INVTYPE_LEGS           = { slot = "LegsSlot" },
    INVTYPE_NECK           = { slot = "NeckSlot" },
    INVTYPE_ROBE           = { slot = "ChestSlot" },
    INVTYPE_SHIELD         = { slot = "SecondaryHandSlot" },
    INVTYPE_SHOULDER       = { slot = "ShoulderSlot" },
    INVTYPE_TABARD         = { slot = "TabardSlot" },
    INVTYPE_TRINKET        = { slot = "Trinket0Slot" },
    INVTYPE_WAIST          = { slot = "WaistSlot" },
    INVTYPE_WEAPON         = { slot = "MainHandSlot", meta = "Weapon0Slot" },
    INVTYPE_WEAPONMAINHAND = { slot = "MainHandSlot" },
    INVTYPE_WEAPONOFFHAND  = { slot = "SecondaryHandSlot" },
    INVTYPE_WRIST          = { slot = "WristSlot" },
    INVTYPE_RANGED         = { slot = "MainHandSlot" },
    INVTYPE_RANGEDRIGHT    = { slot = "MainHandSlot" },
    INVTYPE_THROWN         = { slot = "MainHandSlot" },
    INVTYPE_RELIC          = { slot = "MainHandSlot" },
}

-- The second slot an item of a paired type may also go in (Outfitter.lua:937-952). HALF names the
-- forward step only; FULL is the same pairs in both directions.
ID.HALF_ALT_SLOT = {
    Trinket0Slot = "Trinket1Slot",
    Finger0Slot  = "Finger1Slot",
    Weapon0Slot  = "Weapon1Slot",
}
ID.FULL_ALT_SLOT = {
    Trinket0Slot = "Trinket1Slot", Trinket1Slot = "Trinket0Slot",
    Finger0Slot  = "Finger1Slot",  Finger1Slot  = "Finger0Slot",
    Weapon0Slot  = "Weapon1Slot",  Weapon1Slot  = "Weapon0Slot",
}

-- The slot pairs a move may swap in one step, rather than through a bag (OutfitterEquipment.lua:701).
ID.SLOT_SWAP = {
    Finger0Slot  = "Finger1Slot",
    Trinket0Slot = "Trinket1Slot",
    MainHandSlot = "SecondaryHandSlot",
}

-- Slots an "unequip the outfit" leaves alone: taking them off looks like a bug, not an outfit change
-- (OutfitterOutfits.lua:198-210).
ID.UNEQUIP_EXEMPT = { ShirtSlot = true, TabardSlot = true }

-- Items that stand in for each other when an outfit's item is missing (Outfitter.lua:960-970).
local ARGENT_LANCE, ALLIANCE_LANCE, HORDE_LANCE = 46106, 46069, 46070
ID.ALIASES = {
    [18608] = 18609,                  -- Benediction -> Anathema
    [18609] = 18608,                  -- Anathema -> Benediction
    [17223] = 17074,                  -- Thunderstrike -> Shadowstrike
    [17074] = 17223,                  -- Shadowstrike -> Thunderstrike
    [ALLIANCE_LANCE] = ARGENT_LANCE,  -- Alliance Lance -> Argent Lance
    [HORDE_LANCE]    = ARGENT_LANCE,  -- Horde Lance -> Argent Lance
    [ARGENT_LANCE]   = ALLIANCE_LANCE, -- Argent Lance -> the player's faction lance (ApplyFactionAliases)
}

--- Points the Argent Lance at the player's own faction lance (quirk 23, INV §16). Called by
--- Outfits.LoadPass. `faction` is UnitFactionGroup's FIRST return, the English token, read through
--- NS.Compat.PlayerFaction() (H10). Anything but "Horde" (Alliance, Neutral, nil) restores the load
--- value, so a second character in the same session gets its own lance rather than the first one's.
function ID.ApplyFactionAliases(faction)
    ID.ALIASES[ARGENT_LANCE] = (faction == "Horde") and HORDE_LANCE or ALLIANCE_LANCE
end

-- Items never listed as unused: profession tools and quest items people keep on purpose
-- (Outfitter.lua:972-986).
ID.IGNORED_UNUSED = {
    [2901]   = true, -- Mining Pick
    [5956]   = true, -- Blacksmith hammer
    [6219]   = true, -- Arclight Spanner
    [7005]   = true, -- Skinning Knife
    [7297]   = true, -- Morbent's Bane
    [10696]  = true, -- Enchanted Azsharite Felbane Sword
    [10697]  = true, -- Enchanted Azsharite Felbane Dagger
    [10698]  = true, -- Enchanted Azsharite Felbane Staff
    [20406]  = true, -- Twilight Cultist Mantle
    [20407]  = true, -- Twilight Cultist Robe
    [20408]  = true, -- Twilight Cultist Cowl
    [136350] = true, -- Brumdysla, Hammer of Vrorsk
}

-- Phantom items appear in a slot but are the by-product of an item equipped in another one: the
-- Legion artifact off-hands, which occupy both weapon slots (Outfitter.lua:625-646).
ID.PHANTOM_IDS = {
    [133948] = true, -- Monk, Fists of the Heavens
    [128293] = true, -- DK, Blades of the Fallen Prince
    [127830] = true, -- DH, Twinblades of the Deceiver
    [128831] = true, -- DH, Aldrachi Warblades
    [128859] = true, -- Druid, Fangs of Ashamane
    [128822] = true, -- Druid, Claws of Ursoc
    [133959] = true, -- Mage, Heart of the Phoenix
    [128867] = true, -- Paladin, Oathseeker
    [133958] = true, -- Priest, Secrets of the Void
    [128869] = true, -- Rogue, The Kingslayers
    [134552] = true, -- Rogue, Fortune
    [128479] = true, -- Rogue, Akaari's Will
    [128936] = true, -- Shaman, The Highkeeper's Ward
    [128873] = true, -- Shaman, Fury of the Stonemother
    [128934] = true, -- Shaman, Shield of the Sea Queen
    [137246] = true, -- Warlock, Spine of Thal'kiel
    [134553] = true, -- Warrior, Helya's Wrath
    [128288] = true, -- Warrior, Scaleshard
}

-- Item-class overrides for items the client misfiles (Outfitter.lua:3903-3908). The values are the
-- client's English class tokens, merged over the item record's fields by name; ItemInfo applies them.
ID.CORRECTIONS = {
    [6533]  = { type = "Consumable", subType = "Other" },                 -- Aquadynamic Fish Attractor
    [27503] = { subType = "Scroll" },                                     -- Scroll of Protection V
    [27515] = { type = "Trade Goods", subType = "Meat", invType = "" },   -- Huge Spotted Feltail
}
