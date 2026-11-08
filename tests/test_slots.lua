-- tests/test_slots.lua — defaults/Items.lua (NS.ItemData, design §5.1, INV §14) against the legacy
-- tables captured at 7ea3dc3 (tests/fixtures/legacy/slots.lua): the 18 slots in durability-first
-- order and their reverse index, the inventory-type map, the alternate slots, the item aliases for
-- both factions, the ignored and phantom item ids, and the slot labels.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function data() return T.NS.ItemData end

-- The suite's client profile. WoW Forever's slot table is Retail's (the legacy one) with the ranged
-- slot after the two hands, and its ranged inventory types go there (rulings D2; probe P5).
local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"
local RANGED_TYPES = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true }

-- The legacy slot list, with the ranged slot inserted after SecondaryHandSlot on WoW Forever.
local function wantSlotNames()
    local out = {}
    for _, name in ipairs(T.legacy.slots.slotNames) do
        out[#out + 1] = name
        if FOREVER and name == "SecondaryHandSlot" then out[#out + 1] = "RangedSlot" end
    end
    return out
end

-- The keys of a table as a sorted, comma-joined string, so two sets compare in one assertion.
local function keyList(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    return table.concat(keys, ",")
end

-- `t` as "k=v" pairs, sorted, for a flat table of plain values.
local function pairList(t)
    local out = {}
    for k, v in pairs(t) do out[#out + 1] = tostring(k) .. "=" .. tostring(v) end
    table.sort(out)
    return table.concat(out, ",")
end

test("slots: NS.ItemData is published by defaults/Items.lua", function()
    assertEqual(type(data()), "table", "NS.ItemData")
    assertEqual(type(data().SLOT_NAMES), "table", "SLOT_NAMES")
end)

test("slots: SLOT_NAMES is the legacy durability-first order, all 18 (19 with Forever's ranged slot)", function()
    local want = wantSlotNames()
    local got = data().SLOT_NAMES
    assertEqual(#got, FOREVER and 19 or 18, "slot count")
    assertEqual(#got, #want, "legacy slot count")
    for i, name in ipairs(want) do assertEqual(got[i], name, "slot " .. i) end
end)

test("slots: SLOT_ORDER is SLOT_NAMES' reverse index, and the legacy one", function()
    local names, order = data().SLOT_NAMES, data().SLOT_ORDER
    for i, name in ipairs(names) do assertEqual(order[name], i, name) end
    -- red under: an extra entry in SLOT_ORDER (e.g. `AmmoSlot = 19`) -- the index would still agree
    -- with every SLOT_NAMES entry above, and only the key-set comparison sees the stray.
    local wantOrder = {}
    for i, name in ipairs(wantSlotNames()) do wantOrder[name] = i end
    if not FOREVER then assertEqual(pairList(wantOrder), pairList(T.legacy.slots.slotOrder), "the legacy order") end
    assertEqual(keyList(order), keyList(wantOrder), "SLOT_ORDER's keys")
    assertEqual(pairList(order), pairList(wantOrder), "SLOT_ORDER against legacy")
end)

test("slots: every slot has exactly one label source, a GlobalString key or an L string", function()
    local keys, labels = data().SLOT_LABEL_KEYS, data().SLOT_LABELS
    for _, slot in ipairs(data().SLOT_NAMES) do
        local k, l = keys[slot], labels[slot]
        assertTrue((k ~= nil) ~= (l ~= nil), slot .. " needs exactly one of SLOT_LABEL_KEYS / SLOT_LABELS")
        -- The GlobalString is the slot's own constant: HeadSlot -> HEADSLOT (legacy cSlotDisplayNames).
        if k then assertEqual(k, slot:upper(), slot .. "'s GlobalString key") end
        if l then assertEqual(type(l), "string", slot .. "'s label") end
    end
    -- The four labels no GlobalString carries are the legacy English re-cased to sentence case
    -- (design §4.6 "Re-homed", options-ui-§21): "First Finger" becomes "First finger".
    local legacy = T.legacy.slots.displayNames
    local want = { Finger0Slot = "First finger", Finger1Slot = "Second finger",
                   Trinket0Slot = "First trinket", Trinket1Slot = "Second trinket" }
    for slot, label in pairs(want) do
        assertEqual(labels[slot], label, slot)
        assertEqual(label:lower(), legacy[slot]:lower(), slot .. " is the legacy text, re-cased")
    end
    -- red under: a SLOT_LABELS entry for a slot that is not one of the 18 (the per-slot loop above
    -- never visits it).
    assertEqual(keyList(labels), "Finger0Slot,Finger1Slot,Trinket0Slot,Trinket1Slot", "SLOT_LABELS' keys")
end)

test("slots: INVTYPE_TO_SLOT is the legacy inventory-type map, as { slot, meta }", function()
    local want = T.legacy.slots.invTypeToSlot
    local got = data().INVTYPE_TO_SLOT
    -- red under: drop INVTYPE_RELIC (or add a stray INVTYPE_AMMO) from the table.
    assertEqual(keyList(got), keyList(want), "the inventory types")
    for invType, w in pairs(want) do
        local slot = (FOREVER and RANGED_TYPES[invType]) and "RangedSlot" or w.SlotName
        assertEqual(got[invType].slot, slot, invType .. ".slot")
        assertEqual(got[invType].meta, w.MetaSlotName, invType .. ".meta")
    end
end)

test("slots: the slot table is picked per client: Forever adds the ranged slot, Retail's is unchanged", function()
    local names = table.concat(data().SLOT_NAMES, ",")
    local retail = "HeadSlot,ShoulderSlot,ChestSlot,WristSlot,HandsSlot,WaistSlot,LegsSlot,FeetSlot,"
        .. "MainHandSlot,SecondaryHandSlot,"
        .. "BackSlot,NeckSlot,ShirtSlot,TabardSlot,Finger0Slot,Finger1Slot,Trinket0Slot,Trinket1Slot"
    -- red under: RangedSlot in Retail's list (Retail's client raises on the name), or missing on Forever.
    assertEqual(names, FOREVER and retail:gsub("SecondaryHandSlot,", "SecondaryHandSlot,RangedSlot,") or retail)
    assertEqual(data().SLOT_LABEL_KEYS.RangedSlot, FOREVER and "RANGEDSLOT" or nil, "the ranged slot's GlobalString")
    for invType in pairs(RANGED_TYPES) do
        assertEqual(data().INVTYPE_TO_SLOT[invType].slot, FOREVER and "RangedSlot" or "MainHandSlot", invType)
        assertEqual(data().INVTYPE_TO_SLOT[invType].meta, nil, invType .. " has no meta slot")
    end
    assertEqual(data().SLOT_ORDER.AmmoSlot, nil, "no ammo slot yet (D1 waits for the stack-aware equip path)")
end)

test("slots: every INVTYPE_TO_SLOT target is one of the 18 slots", function()
    local order = data().SLOT_ORDER
    for invType, e in pairs(data().INVTYPE_TO_SLOT) do
        assertTrue(order[e.slot] ~= nil, invType .. " -> " .. tostring(e.slot))
    end
end)

test("slots: the alternate-slot tables are the legacy ones", function()
    assertEqual(pairList(data().HALF_ALT_SLOT), pairList(T.legacy.slots.halfAltSlot), "HALF_ALT_SLOT")
    assertEqual(pairList(data().FULL_ALT_SLOT), pairList(T.legacy.slots.fullAltSlot), "FULL_ALT_SLOT")
    -- FULL is HALF made symmetric.
    for a, b in pairs(data().FULL_ALT_SLOT) do assertEqual(data().FULL_ALT_SLOT[b], a, a .. " <-> " .. b) end
end)

test("slots: SLOT_SWAP pairs the two rings, the two trinkets and the two hands", function()
    assertEqual(pairList(data().SLOT_SWAP),
        "Finger0Slot=Finger1Slot,MainHandSlot=SecondaryHandSlot,Trinket0Slot=Trinket1Slot", "SLOT_SWAP")
end)

test("slots: UNEQUIP_EXEMPT is the shirt and the tabard", function()
    assertEqual(pairList(data().UNEQUIP_EXEMPT), "ShirtSlot=true,TabardSlot=true", "UNEQUIP_EXEMPT")
end)

test("slots: ALIASES load as the legacy (Alliance) table", function()
    local fresh = T.load({ init = false }).NS.ItemData
    assertEqual(pairList(fresh.ALIASES), pairList(T.legacy.slots.aliases), "ALIASES at load")
end)

test("slots: ApplyFactionAliases swaps the Argent Lance to the Horde lance, and back (quirk 23)", function()
    local ID = T.load({ init = false }).NS.ItemData
    ID.ApplyFactionAliases("Horde")
    -- red under: an ApplyFactionAliases that never writes ALIASES[46106] (the load value is 46069).
    assertEqual(pairList(ID.ALIASES), pairList(T.legacy.slots.aliasesHorde), "ALIASES for Horde")
    -- A character switch to an Alliance character in the same session restores the load value: the
    -- legacy one-way write would have kept the Horde lance.
    ID.ApplyFactionAliases("Alliance")
    assertEqual(pairList(ID.ALIASES), pairList(T.legacy.slots.aliases), "ALIASES back for Alliance")
    -- Neutral (a fresh pandaren) and nil read as the load value too.
    ID.ApplyFactionAliases("Horde")
    ID.ApplyFactionAliases(nil)
    assertEqual(ID.ALIASES[46106], 46069, "nil faction")
    ID.ApplyFactionAliases("Neutral")
    assertEqual(ID.ALIASES[46106], 46069, "Neutral faction")
end)

test("slots: IGNORED_UNUSED holds the legacy ids", function()
    local got = data().IGNORED_UNUSED
    assertEqual(keyList(got), keyList(T.legacy.slots.ignoredUnused), "IGNORED_UNUSED ids")
    for id, v in pairs(got) do assertEqual(v, true, "IGNORED_UNUSED[" .. id .. "]") end
end)

test("slots: PHANTOM_IDS holds the 18 legacy artifact off-hands", function()
    local want = {}
    for _, id in ipairs(T.legacy.slots.phantomIDs) do want[id] = true end
    local got = data().PHANTOM_IDS
    assertEqual(#T.legacy.slots.phantomIDs, 18, "the legacy count")
    -- red under: a PHANTOM_IDS missing 137246 (Spine of Thal'kiel) or carrying a 19th id.
    assertEqual(keyList(got), keyList(want), "PHANTOM_IDS")
    for id, v in pairs(got) do assertEqual(v, true, "PHANTOM_IDS[" .. id .. "]") end
end)

test("slots: CORRECTIONS are the three legacy item-class overrides", function()
    local c = data().CORRECTIONS
    assertEqual(keyList(c), "27503,27515,6533", "the corrected items")
    assertEqual(pairList(c[6533]), "subType=Other,type=Consumable", "6533 Aquadynamic Fish Attractor")
    assertEqual(pairList(c[27503]), "subType=Scroll", "27503 Scroll of Protection V")
    assertEqual(pairList(c[27515]), "invType=,subType=Meat,type=Trade Goods", "27515 Huge Spotted Feltail")
end)

test("slots: the dropped tables stay dropped (design §5.1, INV §18)", function()
    -- NS.ItemData is a closed set: a retired table (cUniqueGemItemIDs, cCombatEquipmentSlots,
    -- cArgentDawnTrinkets, cStatIDItems) carried over under any name adds a key here.
    -- red under: an `ID.UNIQUE_GEM_IDS = {}` (or any other new table) in defaults/Items.lua.
    assertEqual(keyList(data()), "ALIASES,ApplyFactionAliases,CORRECTIONS,FULL_ALT_SLOT,HALF_ALT_SLOT,"
        .. "IGNORED_UNUSED,INVTYPE_TO_SLOT,PHANTOM_IDS,SLOT_LABELS,SLOT_LABEL_KEYS,SLOT_NAMES,SLOT_ORDER,"
        .. "SLOT_SWAP,UNEQUIP_EXEMPT", "NS.ItemData's members")
    -- And no addon file names a retired legacy table, by its legacy name.
    local RETIRED = { "cUniqueGemItemIDs", "cCombatEquipmentSlots", "cArgentDawnTrinkets", "cStatIDItems" }
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") and not rel:match("^libs/") then
            local f = assert(io.open(T.root .. "/" .. rel, "rb"))
            local src = f:read("*a")
            f:close()
            for _, name in ipairs(RETIRED) do
                -- red under: a `local cStatIDItems = { ... }` in any addon file the TOC loads.
                assertFalse(src:find(name, 1, true) ~= nil, rel .. " names the retired " .. name)
            end
        end
    end
end)
