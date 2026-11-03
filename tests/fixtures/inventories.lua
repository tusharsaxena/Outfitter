-- tests/fixtures/inventories.lua — named gear scenarios tests/mock_gear.lua loads with
-- `M.__gear:load("<name>")` (design §9.2): who the player is, what is worn, what each bag holds,
-- what the bank holds and whether it is open, and which Equipment Manager sets exist.
--
-- Shape of one scenario (every field optional):
--   class, spec, level, faction        the player (applied through tests/mock_world.lua's state)
--   titansGrip = true                  a two-hander may sit in the off hand (Fury, INV §3.3 TGFix)
--   equipped = { [slotName] = itemKey }
--   bags = { [bagID] = { bag = itemKey, items = { [slot] = itemKey | { key, count, bound,
--            cooldown = { start, duration, enable }, durability = { cur, max } } } } }
--            Bag 0 is the backpack (16 slots, no bag item); bags 1-4 take their size and family
--            from the bag item; bag 5 is the reagent bag.
--   bank = { [tabID] = { size, items = { ... } } }   character bank tabs 6-11 (Enum.BagIndex)
--   bankOpen = true
--   sets = { { name, icon, items = { [slotName] = itemKey | false } , ignored = { slotName... } } }
--          an EM set: each item is the FIRST instance of that key the scenario placed, so the set
--          follows the item wherever it moves, as the client's sets follow an item's GUID.
--   pending = { itemKey... }           C_Item.GetItemInfo answers nil for these until resolved
--
-- A suite that needs a variation copies a scenario (`M.__gear:load(name, overrides)` merges the
-- top-level fields) rather than adding a near-duplicate here.

local function fill(key, n)
    local t = {}
    for i = 1, n do t[i] = key end
    return t
end

local FULL_GEAR = {
    HeadSlot = "head_plate", NeckSlot = "neck_chain", ShoulderSlot = "shoulder_plate",
    BackSlot = "back_cloak", ChestSlot = "chest_plate", ShirtSlot = "shirt_plain",
    TabardSlot = "tabard_guild", WristSlot = "wrist_plate", HandsSlot = "hands_plate",
    WaistSlot = "waist_plate", LegsSlot = "legs_plate", FeetSlot = "feet_plate",
    Finger0Slot = "ring_plain_a", Finger1Slot = "ring_plain_b",
    Trinket0Slot = "trinket_use", Trinket1Slot = "trinket_passive",
    MainHandSlot = "sword_1h", SecondaryHandSlot = "shield",
}

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local S = {}

-- Nothing worn, nothing carried: the empty-inventory baseline (legacy/states.lua's note).
S.naked = { class = "WARRIOR", spec = 1, level = 80, faction = "Alliance", equipped = {}, bags = {} }

-- A complete warrior set worn, a few spares in the backpack, four bags.
S.geared = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Alliance",
    equipped = copy(FULL_GEAR),
    bags = {
        [0] = { items = { [1] = "greatsword", [2] = "ring_unique_a", [3] = "boe_legs",
                          [4] = "hearthstone", [5] = "chest_hero" } },
        [1] = { bag = "bag_backpack16", items = { [1] = "warbound_cloak" } },
        [2] = { bag = "bag_backpack16", items = {} },
        [3] = { bag = "bag_small4", items = {} },
        [4] = { bag = "bag_small4", items = {} },
    },
}

-- Every general-purpose slot occupied: nothing can be unequipped into the bags.
S.full_bags = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Alliance",
    equipped = copy(FULL_GEAR),
    bags = {
        [0] = { items = fill("herb_silverleaf", 16) },
        [1] = { bag = "bag_small4", items = { "greatsword", "hearthstone", "boe_legs", "staff" } },
    },
}

-- Fury: two two-handers, the second in the off hand (Titan's Grip).
S.tg_warrior = {
    class = "WARRIOR", spec = 2, level = 80, faction = "Horde", titansGrip = true,
    equipped = { MainHandSlot = "greatsword", SecondaryHandSlot = "greataxe", HeadSlot = "head_plate" },
    bags = { [0] = { items = { [1] = "sword_1h", [2] = "sword_1h_b", [3] = "staff" } } },
}

-- Two rings that share one limit category, one worn and one carried, plus a self-unique ring.
S.unique_rings = {
    class = "PALADIN", spec = 1, level = 80, faction = "Alliance",
    equipped = { Finger0Slot = "ring_unique_a", Finger1Slot = "ring_plain_a" },
    bags = { [0] = { items = { [1] = "ring_unique_b", [2] = "ring_self_unique",
                               [3] = "ring_self_unique", [4] = "ring_plain_b" } } },
}

-- The bank is open and holds part of an outfit.
S.bank_open = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Alliance", bankOpen = true,
    equipped = { HeadSlot = "head_plate", ChestSlot = "chest_plate" },
    bags = { [0] = { items = { [1] = "ring_plain_a" } } },
    bank = {
        [6] = { size = 98, items = { [1] = "legs_plate", [2] = "feet_plate", [3] = "trinket_use" } },
        [7] = { size = 98, items = {} },
    },
}

-- The same bank, closed: what the client will not answer for.
S.bank_closed = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Alliance",
    equipped = { HeadSlot = "head_plate", ChestSlot = "chest_plate" },
    bags = { [0] = { items = { [1] = "ring_plain_a" } } },
    bank = { [6] = { size = 98, items = { [1] = "legs_plate", [2] = "feet_plate" } } },
}

-- A herb bag with room and a general bag with none: gear must not land among the herbs.
S.specialty_bags = {
    class = "DRUID", spec = 1, level = 80, faction = "Horde",
    equipped = { HeadSlot = "head_plate", LegsSlot = "legs_plate" },
    bags = {
        [0] = { items = fill("hearthstone", 16) },
        [1] = { bag = "bag_herb", items = { [1] = "herb_silverleaf" } },
        [5] = { bag = "bag_reagent", items = {} },
    },
}

-- A worn and a carried item whose links the client hands out as secrets (INV §12, Q12).
S.secret_slots = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Alliance",
    equipped = { HeadSlot = "secret_helm", ChestSlot = "chest_plate" },
    bags = { [0] = { items = { [1] = "secret_helm", [2] = "ring_plain_a" } } },
}

-- One item on two upgrade tracks: the champion copy worn, the hero copy carried.
S.upgrade_tracks = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Alliance",
    equipped = { ChestSlot = "chest_champion" },
    bags = { [0] = { items = { [1] = "chest_hero", [2] = "chest_azerite" } } },
}

-- A rogue's two one-handers, and a two-hander to displace them with.
S.dual_wield = {
    class = "ROGUE", spec = 2, level = 80, faction = "Horde",
    equipped = { MainHandSlot = "sword_1h", SecondaryHandSlot = "sword_1h_b" },
    bags = { [0] = { items = { [1] = "greatsword", [2] = "dagger_offhand", [3] = "mace_mainhand" } } },
}

-- An on-use trinket worn and one in the bags, both cooling down (Inv.NextCooldownItem, B19).
S.cooldowns = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Alliance",
    equipped = { Trinket0Slot = "trinket_use" },
    bags = { [0] = { items = { [1] = { key = "trinket_use", cooldown = { 100, 120, 1 } },
                               [2] = { key = "hearthstone", cooldown = { 0, 0, 1 } } } } },
}

-- Two Equipment Manager sets, one of them partly in the bags.
S.em_sets = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Alliance",
    equipped = { HeadSlot = "head_plate", ChestSlot = "chest_plate", MainHandSlot = "sword_1h",
                 SecondaryHandSlot = "shield" },
    bags = { [0] = { items = { [1] = "greatsword", [2] = "chest_hero" } } },
    sets = {
        { name = "Tank", icon = 132341, items = { HeadSlot = "head_plate", ChestSlot = "chest_plate",
                                                    MainHandSlot = "sword_1h", SecondaryHandSlot = "shield" } },
        { name = "Big Sword", icon = 135349, items = { MainHandSlot = "greatsword", SecondaryHandSlot = false,
                                                         ChestSlot = "chest_hero" },
          ignored = { "HeadSlot" } },
    },
}

-- An item whose info the client has not cached yet (GET_ITEM_INFO_RECEIVED, B5).
S.uncached = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Alliance",
    equipped = { HeadSlot = "head_plate" },
    bags = { [0] = { items = { [1] = "legs_plate" } } },
    pending = { "legs_plate" },
}

-- Argent Tournament lances (the faction alias swap, quirk 23).
S.lances = {
    class = "WARRIOR", spec = 1, level = 80, faction = "Horde",
    equipped = { MainHandSlot = "argent_lance" },
    bags = { [0] = { items = { [1] = "horde_lance", [2] = "alliance_lance", [3] = "mining_pick" } } },
}

return S
