-- tests/fixtures/items.lua — the hand-authored item database tests/mock_gear.lua answers from
-- (design §9.2): links, bonus ids, modifiers, unique-equip categories, one- and two-handers, BoE,
-- warbound, upgrade tracks, Azerite powers, specialty-bag families and one secret entry.
--
-- Each entry is keyed by a short NAME, which is what tests/fixtures/inventories.lua places and what a
-- suite asks for (`Fixtures.items.ring_unique_a`). The link is BUILT from the entry's fields by
-- `Items.link(def)` when this file loads, so the link and the fields can never disagree, and the
-- shape is the 12.x client's:
--
--   |cnIQ<q>:|Hitem:<id>:<enchant>:<gem1>:<gem2>:<gem3>:<gem4>:<suffix>:<uid>:<linkLevel>:<specID>:
--     <upgradeTypeID>:<difficultyID>:<numBonus>[:<bonus>...]:<numMods>[:<type>:<value>...]:::::|h[<name>]|h|r
--
-- A zero field is written EMPTY, as the client writes it ("item:19019::::::::80:..."), and the five
-- trailing relic/crafter fields are always present and empty, so a parser that stops at the modifier
-- list is exercised on the tail it will meet in the client.
--
-- Fields (all optional except id, name, invType):
--   id, name, quality, level (effective item level), baseLevel, minLevel, invType, classID,
--   subclassID, bindType (Enum.ItemBind: 0 none, 1 on acquire, 2 on equip, 9 warbound until
--   equipped), icon, enchant, gems = { g1, g2, g3, g4 }, suffix, uid, upType, diff,
--   bonus = { ids... }, mods = { { type, value }... }, azerite = { powerIDs... } (link order, NOT
--   sorted, so a consumer that compares them must sort), stats = { [ITEM_MOD_*] = n },
--   spell = { name, id } (a "Use:" effect), unique = { name, count, id } (a limit category;
--   `count` is how many may be worn) or unique = true (the item itself is unique-equipped),
--   family (bag-family bits the item carries), slots + bagFamily (a container), durability,
--   unusable (C_PlayerInfo.CanUseItem answers false), secret (its links arrive as Kit.secret),
--   extraLines = { { text, r, g, b } } (more tooltip lines, e.g. a red requirement).

local Items = {}

local ENCHANT_STAM = 7334
local GEM_HASTE = 213743

-- Enum.ItemClass / weapon and armor subclasses, the client's numbers.
local ARMOR, WEAPON, CONTAINER, TRADEGOODS, MISC = 4, 2, 1, 7, 15

local DB = {
    -- ── armor, one per slot ───────────────────────────────────────────────────────────────────
    head_plate      = { id = 212001, name = "Helm of the Test Bench", quality = 4, level = 639,
                        invType = "INVTYPE_HEAD", classID = ARMOR, subclassID = 4, bindType = 1,
                        bonus = { 10353, 1520 }, durability = { 100, 100 },
                        stats = { ITEM_MOD_STAMINA_SHORT = 900, ITEM_MOD_STRENGTH_SHORT = 520,
                                  ITEM_MOD_CRIT_RATING_SHORT = 210 } },
    neck_chain      = { id = 212002, name = "Chain of Fixtures", quality = 4, level = 636,
                        invType = "INVTYPE_NECK", classID = ARMOR, subclassID = 0, bindType = 1,
                        gems = { GEM_HASTE, 0, 0, 0 },
                        stats = { ITEM_MOD_STAMINA_SHORT = 400, ITEM_MOD_HASTE_RATING_SHORT = 600 } },
    shoulder_plate  = { id = 212003, name = "Pauldrons of Mocking", quality = 4, level = 639,
                        invType = "INVTYPE_SHOULDER", classID = ARMOR, subclassID = 4, bindType = 1,
                        durability = { 100, 100 }, stats = { ITEM_MOD_STAMINA_SHORT = 700 } },
    back_cloak      = { id = 212004, name = "Drape of Stubs", quality = 3, level = 610,
                        invType = "INVTYPE_CLOAK", classID = ARMOR, subclassID = 1, bindType = 1,
                        stats = { ITEM_MOD_STAMINA_SHORT = 300 } },
    chest_plate     = { id = 212005, name = "Breastplate of Assertions", quality = 4, level = 639,
                        invType = "INVTYPE_CHEST", classID = ARMOR, subclassID = 4, bindType = 1,
                        enchant = ENCHANT_STAM, durability = { 165, 165 },
                        stats = { ITEM_MOD_STAMINA_SHORT = 1200, ITEM_MOD_STRENGTH_SHORT = 700 } },
    shirt_plain     = { id = 45, name = "Squire's Shirt", quality = 1, level = 1,
                        invType = "INVTYPE_BODY", classID = ARMOR, subclassID = 0, bindType = 0 },
    tabard_guild    = { id = 5976, name = "Guild Tabard", quality = 1, level = 1,
                        invType = "INVTYPE_TABARD", classID = ARMOR, subclassID = 0, bindType = 1 },
    wrist_plate     = { id = 212395, name = "Vambraces of the Track", quality = 3, level = 619,
                        invType = "INVTYPE_WRIST", classID = ARMOR, subclassID = 4, bindType = 1,
                        upType = 0, bonus = { 10353, 1520, 10255 }, mods = { { 28, 2734 } },
                        durability = { 55, 55 }, stats = { ITEM_MOD_STAMINA_SHORT = 350 } },
    hands_plate     = { id = 212007, name = "Gauntlets of Grip", quality = 4, level = 639,
                        invType = "INVTYPE_HAND", classID = ARMOR, subclassID = 4, bindType = 1,
                        durability = { 55, 55 }, stats = { ITEM_MOD_STAMINA_SHORT = 650 } },
    waist_plate     = { id = 212008, name = "Girdle of Teardown", quality = 4, level = 639,
                        invType = "INVTYPE_WAIST", classID = ARMOR, subclassID = 4, bindType = 1,
                        durability = { 55, 55 }, stats = { ITEM_MOD_STAMINA_SHORT = 650 } },
    legs_plate      = { id = 212009, name = "Legplates of Setup", quality = 4, level = 639,
                        invType = "INVTYPE_LEGS", classID = ARMOR, subclassID = 4, bindType = 1,
                        durability = { 120, 120 }, stats = { ITEM_MOD_STAMINA_SHORT = 1150 } },
    feet_plate      = { id = 212010, name = "Sabatons of Steps", quality = 4, level = 639,
                        invType = "INVTYPE_FEET", classID = ARMOR, subclassID = 4, bindType = 1,
                        durability = { 75, 75 }, stats = { ITEM_MOD_STAMINA_SHORT = 650 } },

    -- ── one item on two upgrade tracks: same id, different bonus ids, upgrade type and
    -- modifiers, so only a partial match joins them ─────────────────────────────────────────────
    chest_champion  = { id = 212020, name = "Hauberk of Tracks", quality = 4, level = 626,
                        invType = "INVTYPE_CHEST", classID = ARMOR, subclassID = 3, bindType = 1,
                        upType = 4, diff = 14, bonus = { 10297, 1514 }, mods = { { 9, 80 }, { 28, 2462 } },
                        durability = { 140, 140 }, stats = { ITEM_MOD_STAMINA_SHORT = 1000 } },
    chest_hero      = { id = 212020, name = "Hauberk of Tracks", quality = 4, level = 639,
                        invType = "INVTYPE_CHEST", classID = ARMOR, subclassID = 3, bindType = 1,
                        upType = 4, diff = 15, bonus = { 10298, 1527 }, mods = { { 9, 80 }, { 28, 2463 } },
                        durability = { 140, 140 }, stats = { ITEM_MOD_STAMINA_SHORT = 1150 } },

    -- ── an Azerite chest, its powers in link order ──────────────────────────────────────────
    chest_azerite   = { id = 165000, name = "Azerite Robes of Order", quality = 4, level = 445,
                        invType = "INVTYPE_ROBE", classID = ARMOR, subclassID = 1, bindType = 1,
                        azerite = { 560, 13, 30 }, durability = { 100, 100 } },

    -- ── rings: plain, a shared limit category, and a unique-equipped item itself ─────────────
    ring_plain_a    = { id = 212030, name = "Band of Alpha", quality = 4, level = 636,
                        invType = "INVTYPE_FINGER", classID = ARMOR, subclassID = 0, bindType = 1,
                        stats = { ITEM_MOD_STAMINA_SHORT = 300, ITEM_MOD_MASTERY_RATING_SHORT = 500 } },
    ring_plain_b    = { id = 212031, name = "Band of Beta", quality = 4, level = 636,
                        invType = "INVTYPE_FINGER", classID = ARMOR, subclassID = 0, bindType = 1,
                        enchant = 7340,
                        stats = { ITEM_MOD_STAMINA_SHORT = 300, ITEM_MOD_VERSATILITY = 500 } },
    ring_unique_a   = { id = 212032, name = "Signet of the First Seal", quality = 4, level = 636,
                        invType = "INVTYPE_FINGER", classID = ARMOR, subclassID = 0, bindType = 1,
                        unique = { name = "Seal of the Bench", count = 1, id = 701 },
                        stats = { ITEM_MOD_STAMINA_SHORT = 320 } },
    ring_unique_b   = { id = 212033, name = "Signet of the Second Seal", quality = 4, level = 636,
                        invType = "INVTYPE_FINGER", classID = ARMOR, subclassID = 0, bindType = 1,
                        unique = { name = "Seal of the Bench", count = 1, id = 701 },
                        stats = { ITEM_MOD_STAMINA_SHORT = 330 } },
    ring_self_unique = { id = 212034, name = "Loop of One", quality = 4, level = 636,
                        invType = "INVTYPE_FINGER", classID = ARMOR, subclassID = 0, bindType = 1,
                        unique = true, stats = { ITEM_MOD_STAMINA_SHORT = 310 } },

    -- ── trinkets: one on-use with a cooldown, one passive ───────────────────────────────────
    trinket_use     = { id = 212040, name = "Clockwork Stopwatch", quality = 4, level = 639,
                        invType = "INVTYPE_TRINKET", classID = ARMOR, subclassID = 0, bindType = 1,
                        spell = { name = "Tick", id = 451000 },
                        stats = { ITEM_MOD_STRENGTH_SHORT = 400 } },
    trinket_passive = { id = 212041, name = "Paperweight of Patience", quality = 4, level = 639,
                        invType = "INVTYPE_TRINKET", classID = ARMOR, subclassID = 0, bindType = 1,
                        stats = { ITEM_MOD_CRIT_RATING_SHORT = 700 } },

    -- ── weapons ─────────────────────────────────────────────────────────────────────────────
    sword_1h        = { id = 212050, name = "Shortsword of Stubs", quality = 4, level = 639,
                        invType = "INVTYPE_WEAPON", classID = WEAPON, subclassID = 7, bindType = 1,
                        durability = { 110, 110 }, stats = { ITEM_MOD_STRENGTH_SHORT = 600 } },
    sword_1h_b      = { id = 212051, name = "Shortsword of Spies", quality = 4, level = 626,
                        invType = "INVTYPE_WEAPON", classID = WEAPON, subclassID = 7, bindType = 1,
                        durability = { 110, 110 }, stats = { ITEM_MOD_STRENGTH_SHORT = 560 } },
    mace_mainhand   = { id = 212052, name = "Mace of the Main Hand", quality = 4, level = 639,
                        invType = "INVTYPE_WEAPONMAINHAND", classID = WEAPON, subclassID = 4,
                        bindType = 1, durability = { 110, 110 },
                        stats = { ITEM_MOD_INTELLECT_SHORT = 900 } },
    dagger_offhand  = { id = 212053, name = "Parrying Dagger", quality = 4, level = 639,
                        invType = "INVTYPE_WEAPONOFFHAND", classID = WEAPON, subclassID = 15,
                        bindType = 1, durability = { 110, 110 },
                        stats = { ITEM_MOD_AGILITY_SHORT = 500 } },
    shield          = { id = 212054, name = "Bulwark of Baselines", quality = 4, level = 639,
                        invType = "INVTYPE_SHIELD", classID = ARMOR, subclassID = 6, bindType = 1,
                        durability = { 120, 120 }, stats = { ITEM_MOD_STAMINA_SHORT = 800 } },
    tome_holdable   = { id = 212055, name = "Tome of Test Cases", quality = 4, level = 639,
                        invType = "INVTYPE_HOLDABLE", classID = ARMOR, subclassID = 0, bindType = 1,
                        stats = { ITEM_MOD_INTELLECT_SHORT = 400 } },
    greatsword      = { id = 212056, name = "Greatsword of Grips", quality = 4, level = 639,
                        invType = "INVTYPE_2HWEAPON", classID = WEAPON, subclassID = 8, bindType = 1,
                        durability = { 120, 120 }, stats = { ITEM_MOD_STRENGTH_SHORT = 1500 } },
    greataxe        = { id = 212057, name = "Greataxe of Titans", quality = 4, level = 636,
                        invType = "INVTYPE_2HWEAPON", classID = WEAPON, subclassID = 1, bindType = 1,
                        durability = { 120, 120 }, stats = { ITEM_MOD_STRENGTH_SHORT = 1450 } },
    staff           = { id = 212058, name = "Staff of Seams", quality = 3, level = 610,
                        invType = "INVTYPE_2HWEAPON", classID = WEAPON, subclassID = 10, bindType = 1,
                        durability = { 120, 120 }, stats = { ITEM_MOD_INTELLECT_SHORT = 1100 } },
    bow_ranged      = { id = 212059, name = "Longbow of Latency", quality = 4, level = 639,
                        invType = "INVTYPE_RANGEDRIGHT", classID = WEAPON, subclassID = 2,
                        bindType = 1, durability = { 120, 120 },
                        stats = { ITEM_MOD_AGILITY_SHORT = 1500 } },

    -- ── binding variants ────────────────────────────────────────────────────────────────────
    boe_legs        = { id = 212060, name = "Leggings of the Auction", quality = 3, level = 600,
                        invType = "INVTYPE_LEGS", classID = ARMOR, subclassID = 4, bindType = 2,
                        durability = { 120, 120 }, stats = { ITEM_MOD_STAMINA_SHORT = 900 } },
    warbound_cloak  = { id = 212061, name = "Cloak of the Warband", quality = 4, level = 619,
                        invType = "INVTYPE_CLOAK", classID = ARMOR, subclassID = 1, bindType = 9,
                        stats = { ITEM_MOD_STAMINA_SHORT = 350 } },
    unusable_helm   = { id = 212062, name = "Crown of the Next Expansion", quality = 4, level = 700,
                        minLevel = 90, invType = "INVTYPE_HEAD", classID = ARMOR, subclassID = 4,
                        bindType = 1, unusable = true, durability = { 100, 100 },
                        extraLines = { { "Requires Level 90", 1, 0.125, 0.125 } } },

    -- ── a secret: every link the client hands out for it is a Kit.secret wrapper ─────────────
    secret_helm     = { id = 212070, name = "Veiled Helm", quality = 4, level = 639,
                        invType = "INVTYPE_HEAD", classID = ARMOR, subclassID = 4, bindType = 1,
                        secret = true, durability = { 100, 100 } },

    -- ── the Argent Tournament lances the alias table joins (INV §14, quirk 23) ───────────────
    argent_lance    = { id = 46106, name = "Argent Lance", quality = 3, level = 200,
                        invType = "INVTYPE_2HWEAPON", classID = WEAPON, subclassID = 6, bindType = 1 },
    alliance_lance  = { id = 46069, name = "Alliance Lance", quality = 3, level = 200,
                        invType = "INVTYPE_2HWEAPON", classID = WEAPON, subclassID = 6, bindType = 1 },
    horde_lance     = { id = 46070, name = "Horde Lance", quality = 3, level = 200,
                        invType = "INVTYPE_2HWEAPON", classID = WEAPON, subclassID = 6, bindType = 1 },

    -- ── things that are not gear ────────────────────────────────────────────────────────────
    mining_pick     = { id = 2901, name = "Mining Pick", quality = 1, level = 4,
                        invType = "INVTYPE_WEAPONMAINHAND", classID = WEAPON, subclassID = 0,
                        bindType = 0 },
    herb_silverleaf = { id = 765, name = "Silverleaf", quality = 1, level = 5, invType = "",
                        classID = TRADEGOODS, subclassID = 9, bindType = 0, family = 0x0020 },
    hearthstone     = { id = 6948, name = "Hearthstone", quality = 1, level = 1, invType = "",
                        classID = MISC, subclassID = 0, bindType = 1,
                        spell = { name = "Hearthstone", id = 8690 } },

    -- ── containers ──────────────────────────────────────────────────────────────────────────
    bag_backpack16  = { id = 4500, name = "Traveler's Backpack", quality = 1, level = 1,
                        invType = "INVTYPE_BAG", classID = CONTAINER, subclassID = 0, bindType = 0,
                        slots = 16, bagFamily = 0 },
    bag_small4      = { id = 4496, name = "Small Brown Pouch", quality = 1, level = 1,
                        invType = "INVTYPE_BAG", classID = CONTAINER, subclassID = 0, bindType = 0,
                        slots = 4, bagFamily = 0 },
    bag_herb        = { id = 22251, name = "Cenarion Herb Bag", quality = 2, level = 1,
                        invType = "INVTYPE_BAG", classID = CONTAINER, subclassID = 2, bindType = 0,
                        slots = 24, bagFamily = 0x0020 },
    bag_reagent     = { id = 194019, name = "Shimmering Reagent Satchel", quality = 1, level = 1,
                        invType = "INVTYPE_BAG", classID = CONTAINER, subclassID = 11, bindType = 0,
                        slots = 32, bagFamily = 0 },
}

-- ── the link builder ─────────────────────────────────────────────────────────────────────────

local function field(n)
    if n == nil or n == 0 then return "" end
    return tostring(n)
end

--- The item string (no color, no brackets): "item:<id>:...". Exposed for suites that need the
--- short form a hyperlink carries.
function Items.itemString(def)
    local gems = def.gems or {}
    local parts = { "item", tostring(def.id), field(def.enchant), field(gems[1]), field(gems[2]),
                    field(gems[3]), field(gems[4]), field(def.suffix), field(def.uid),
                    tostring(def.linkLevel or 80), field(def.specID), field(def.upType),
                    field(def.diff) }
    local bonus = def.bonus or {}
    parts[#parts + 1] = field(#bonus)
    for _, b in ipairs(bonus) do parts[#parts + 1] = tostring(b) end
    local mods = def.mods or {}
    parts[#parts + 1] = field(#mods)
    for _, m in ipairs(mods) do
        parts[#parts + 1] = tostring(m[1])
        parts[#parts + 1] = tostring(m[2])
    end
    -- The five relic / crafter / extra-enchant fields the client always writes, here empty.
    for _ = 1, 5 do parts[#parts + 1] = "" end
    return table.concat(parts, ":")
end

--- The full hyperlink in the 12.x shape (|cnIQ<quality>: color, |H...|h[name]|h|r).
function Items.link(def)
    return ("|cnIQ%d:|H%s|h[%s]|h|r"):format(def.quality or 1, Items.itemString(def), def.name)
end

local names = {}
for key, def in pairs(DB) do
    def.key = key
    def.quality = def.quality or 1
    def.minLevel = def.minLevel or 1
    def.baseLevel = def.baseLevel or def.level
    def.bindType = def.bindType or 0
    def.icon = def.icon or (100000 + def.id % 100000)
    def.link = Items.link(def)
    names[#names + 1] = key
end
table.sort(names)

Items.db = DB
Items.names = names   -- every key, sorted: a suite that walks the database gets a stable order

return Items
