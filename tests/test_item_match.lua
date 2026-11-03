-- tests/test_item_match.lua — P4.5's matching half (design §5.4, §5.5): the inventory cache's Find,
-- FindOrAlt, FindAll, Same and SlotHas over item records, against the legacy captures in
-- tests/fixtures/legacy/matching.lua; the per-pass claims (B9); and the cooldown reads the trinket
-- queue uses: NextCooldownItem's 30 s rules and its boolean `enabled` (B19), SlotItemActive and
-- HasUseEffect.
--
-- The cache under test is built two ways: Inv.NewCache(infos) over hand-made records, which is how
-- the legacy cases are replayed, and Inv.Cache() over a mock_gear scenario, which is the client path.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DB = T.fixtures.items.db
local LEGACY = T.legacy.matching

local function gearInstance(scenario, overrides, mutate)
    return T.load({ mutate = function(M)
        if scenario then M.__gear:load(scenario, overrides) end
        if mutate then mutate(M) end
    end })
end

-- ── the legacy records, in the new spelling ───────────────────────────────────────────────────

-- The capture's item(code, sub, extra) (tools/legacy_capture.lua) as an ItemRecord: Code -> id,
-- SubCode -> suffix, and each compared field under its one canonical name (design §3.3). Azerite
-- powers become the sorted ":"-joined string ItemInfo builds.
local RENAME = { EnchantCode = "enchant", UpgradeTypeID = "upType", BonusIDs = "bonus",
                 InstanceDifficultyID = "diff" }

local function rec(code, sub, extra)
    local t = { id = code, suffix = sub, name = "Item" .. code .. "/" .. tostring(sub) }
    for k, v in pairs(extra or {}) do
        if k == "AzeriteCodes" then
            local sorted = {}
            for i, p in ipairs(v) do sorted[i] = p end
            table.sort(sorted)
            t.azerite = table.concat(sorted, ":")
        elseif RENAME[k] then
            t[RENAME[k]] = v
        end
    end
    return t
end

-- Cache entries: each record placed in the backpack, slot = its position, so it has a location.
local function placed(list)
    for i, r in ipairs(list) do r.loc = { bag = 0, slot = i } end
    return list
end

local function indexOf(list, x)
    for i, v in ipairs(list) do if v == x then return i end end
    return nil
end

-- The legacy find cases, by capture name: the cache, the query, and the options that replay it.
local FIND = {
    ["exact on every field"] = function()
        return { rec(10, 1, { EnchantCode = 5 }), rec(10, 1, { EnchantCode = 6 }) }, rec(10, 1, { EnchantCode = 6 })
    end,
    ["a unique partial match is accepted"] = function()
        return { rec(11, 1, { EnchantCode = 5 }) }, rec(11, 1, { EnchantCode = 9 })
    end,
    ["two partials are ambiguous"] = function()
        return { rec(12, 1, { EnchantCode = 5 }), rec(12, 1, { EnchantCode = 6 }) }, rec(12, 1, { EnchantCode = 9 })
    end,
    ["subcode must match"] = function() return { rec(13, 2) }, rec(13, 1) end,
    ["wildcard ignores subcode"] = function() return { rec(14, 2) }, rec(14, nil), { wildcard = true } end,
    ["an exact claimed item is reported as ignored"] = function()
        return { rec(15, 1) }, rec(15, 1), nil, { 1 }
    end,
    ["UpgradeTypeID takes part in exact"] = function()
        return { rec(16, 1, { UpgradeTypeID = 1 }), rec(16, 1, { UpgradeTypeID = 2 }) }, rec(16, 1, { UpgradeTypeID = 2 })
    end,
    ["BonusIDs take part in exact"] = function()
        return { rec(17, 1, { BonusIDs = "1:2" }), rec(17, 1, { BonusIDs = "3" }) }, rec(17, 1, { BonusIDs = "3" })
    end,
    ["Azerite codes compare as a list"] = function()
        return { rec(18, 1, { AzeriteCodes = { 1, 2 } }), rec(18, 1, { AzeriteCodes = { 2, 1 } }) },
               rec(18, 1, { AzeriteCodes = { 2, 1 } })
    end,
    ["unknown code"] = function() return { rec(19, 1) }, rec(20, 1) end,
}

local SAME = {
    ["nil and nil"] = function() return {}, nil, nil end,
    ["empty slot and empty slot"] = function() return {}, rec(0, 0), rec(0, 0) end,
    ["one copy ignores the enchant"] = function()
        return { rec(30, 1) }, rec(30, 1, { EnchantCode = 1 }), rec(30, 1, { EnchantCode = 2 })
    end,
    ["two copies compare the enchant"] = function()
        return { rec(31, 1), rec(31, 1) }, rec(31, 1, { EnchantCode = 1 }), rec(31, 1, { EnchantCode = 2 })
    end,
    ["two copies compare the difficulty"] = function()
        return { rec(32, 1), rec(32, 1) }, rec(32, 1, { InstanceDifficultyID = 1 }), rec(32, 1, { InstanceDifficultyID = 2 })
    end,
    ["different subcode"] = function() return { rec(33, 1) }, rec(33, 1), rec(33, 2) end,
    ["an alias is the same item"] = function() return { rec(18608, 0) }, rec(18608, 0), rec(18609, 0) end,
}

local function Inv() return T.NS.Inventory end

-- ── published ─────────────────────────────────────────────────────────────────────────────────

test("item match: NS.Inventory is published with the cache and list surface", function()
    local I = Inv()
    assertEqual(type(I), "table", "NS.Inventory")
    for _, name in ipairs({ "Cache", "NewCache", "Sync", "ScheduleSync", "Flush", "BagIDs", "IsBankBag",
                            "BankOpen", "Missing", "Unused", "BoE", "Warbound", "ItemSections", "OutfitsUsing",
                            "NextCooldownItem", "SlotItemActive", "HasUseEffect", "Suspend", "Resume" }) do
        assertEqual(type(I[name]), "function", "Inv." .. name)
    end
end)

-- ── Find, against the legacy captures ─────────────────────────────────────────────────────────

test("item match: every legacy FindItem case finds the same item (fixtures/legacy/matching.lua)", function()
    local seen = 0
    for _, case in ipairs(LEGACY.find) do
        local build = assert(FIND[case.name], "no replay for legacy case " .. case.name)
        local items, query, opts, claimedIdx = build()
        placed(items)
        local cache = Inv().NewCache(items)
        local pass = cache:BeginPass()
        for _, i in ipairs(claimedIdx or {}) do pass.claimed[items[i]] = true end
        local found, dup = cache:Find(query, pass, opts)
        assertEqual(indexOf(items, found), case.found, case.name .. ": found")
        assertEqual(indexOf(items, dup), case.ignored, case.name .. ": the claimed duplicate")
        seen = seen + 1
    end
    assertEqual(seen, 10, "the ten legacy find cases")
end)

test("item match: exact compares every EXACT_FIELDS member, diff included (unified with Same)", function()
    -- red under: dropping `diff` (or any member) from ItemInfo's EXACT_FIELDS: the two copies then
    -- tie as exact and the first one is taken. (A different suffix is no match at all: the legacy
    -- "subcode must match" case above.)
    for _, k in ipairs({ "enchant", "gems", "uid", "upType", "diff", "bonus", "mods", "azerite" }) do
        local a, b, want = rec(40, 0), rec(40, 0), rec(40, 0)
        local v = (k == "gems") and "1:0:0:0" or ((k == "bonus" or k == "mods" or k == "azerite") and "7" or 7)
        b[k], want[k] = v, v
        local cache = Inv().NewCache(placed({ a, b }))
        assertEqual(cache:Find(want), b, k .. " takes part in exact")
    end
end)

test("item match: a claim belongs to its pass, never to the item (B9)", function()
    local items = placed({ rec(50, 0, { EnchantCode = 1 }), rec(50, 0, { EnchantCode = 1 }) })
    local cache = Inv().NewCache(items)
    local p1 = cache:BeginPass()
    assertEqual(cache:Find(rec(50, 0, { EnchantCode = 1 }), p1), items[1], "the first copy")
    assertEqual(cache:Find(rec(50, 0, { EnchantCode = 1 }), p1), items[2], "the first is claimed: the second")
    local none, dup = cache:Find(rec(50, 0, { EnchantCode = 1 }), p1)
    assertNil(none, "both claimed")
    assertTrue(dup ~= nil, "a claimed duplicate is reported")
    -- red under: storing the claim on the item (info.claimed = true / IgnoreItem): a new pass then
    -- still sees both copies claimed and finds nothing (the legacy UsedInOutfit, never reset).
    local p2 = cache:BeginPass()
    assertEqual(cache:Find(rec(50, 0, { EnchantCode = 1 }), p2), items[1], "a new pass starts unclaimed")
    for _, info in ipairs(items) do
        for k in pairs(info) do
            assertTrue(k ~= "claimed" and k ~= "IgnoreItem" and k ~= "UsedInOutfit", "a claim was written on the item: " .. k)
        end
    end
    -- No pass, no claim: the same copy answers every time.
    assertEqual(cache:Find(rec(50, 0, { EnchantCode = 1 })), items[1])
    assertEqual(cache:Find(rec(50, 0, { EnchantCode = 1 })), items[1])
    -- A peek inside a pass finds without claiming.
    local p3 = cache:BeginPass()
    assertEqual(cache:Find(rec(50, 0, { EnchantCode = 1 }), p3, { peek = true }), items[1])
    assertEqual(cache:Find(rec(50, 0, { EnchantCode = 1 }), p3), items[1], "the peek claimed nothing")
end)

-- ── FindOrAlt, FindAll ────────────────────────────────────────────────────────────────────────

test("item match: FindOrAlt follows the alias table as the legacy FindItemOrAlt did", function()
    T.NS.ItemData.ApplyFactionAliases("Alliance")
    local cases = {
        { NewCache = { rec(46106, 0) }, query = rec(46069, 0) },
        { NewCache = { rec(46070, 0) }, query = rec(46106, 0) },
    }
    for i, case in ipairs(LEGACY.alt) do
        local c = cases[i]
        local cache = Inv().NewCache(placed(c.NewCache))
        assertEqual(cache:FindOrAlt(c.query) ~= nil, case.found, case.name)
    end
    -- The Horde swap (ApplyFactionAliases) points the Argent Lance at the Horde lance.
    T.NS.ItemData.ApplyFactionAliases("Horde")
    local cache = Inv().NewCache(placed({ rec(46070, 0) }))
    assertTrue(cache:FindOrAlt(rec(46106, 0)) ~= nil, "a Horde character's Argent Lance finds the Horde lance")
    T.NS.ItemData.ApplyFactionAliases("Alliance")
end)

test("item match: FindOrAlt claims the alternate inside a pass", function()
    T.NS.ItemData.ApplyFactionAliases("Alliance")
    local items = placed({ rec(46106, 0) })
    local cache = Inv().NewCache(items)
    local pass = cache:BeginPass()
    assertEqual(cache:FindOrAlt(rec(46069, 0), pass), items[1])
    -- red under: FindOrAlt's alternate lookup not passing the pass on (it would be found again).
    assertNil(cache:FindOrAlt(rec(46069, 0), pass), "the alternate was claimed")
end)

test("item match: FindAll answers every copy with the suffix, plus the alias's", function()
    T.NS.ItemData.ApplyFactionAliases("Alliance")
    local items = placed({ rec(60, 1), rec(60, 1, { EnchantCode = 3 }), rec(60, 2), rec(18609, 0), rec(18608, 0) })
    local cache = Inv().NewCache(items)
    local all = cache:FindAll(rec(60, 1))
    assertEqual(#all, 2, "two copies with suffix 1")
    assertEqual(#cache:FindAll(rec(60, nil), true), 3, "the wildcard takes every suffix")
    local alias = cache:FindAll(rec(18608, 0))
    assertEqual(#alias, 2, "Benediction finds itself and Anathema")
end)

-- ── Same, against the legacy captures ─────────────────────────────────────────────────────────

test("item match: every legacy ItemsAreSame case answers the same (fixtures/legacy/matching.lua)", function()
    local seen = 0
    for _, case in ipairs(LEGACY.same) do
        local build = assert(SAME[case.name], "no replay for legacy case " .. case.name)
        local items, a, b = build()
        local cache = Inv().NewCache(placed(items))
        assertEqual(cache:Same(a, b), case.same, case.name)
        seen = seen + 1
    end
    assertEqual(seen, 7, "the seven legacy same cases")
end)

test("item match: Same compares mods and azerite between two copies, as Find does", function()
    -- The unification (INV §3.4 Fix): Same and Find use one EXACT_FIELDS list.
    local cache = Inv().NewCache(placed({ rec(70, 0), rec(70, 0) }))
    local a, b = rec(70, 0), rec(70, 0)
    a.mods, b.mods = "9=70", "9=71"
    -- red under: Same comparing a hand-written field list that leaves out `mods`.
    assertFalse(cache:Same(a, b), "two copies with different modifiers are not the same")
    b.mods = "9=70"
    assertTrue(cache:Same(a, b))
end)

-- ── SlotHas, on the client path ───────────────────────────────────────────────────────────────

test("item match: SlotHas answers whether a worn slot holds the item, empty markers included", function()
    local inst = gearInstance("geared")
    local NS = inst.NS
    local cache = NS.Inventory.Cache()
    local II = NS.ItemInfo
    local helm = II.Snapshot(II.FromLink(DB.head_plate.link))
    assertTrue(cache:SlotHas("HeadSlot", helm), "the helm is worn")
    assertFalse(cache:SlotHas("ChestSlot", helm), "not in the chest")
    assertFalse(cache:SlotHas("HeadSlot", nil), "a nil item is never contained")
    assertFalse(cache:SlotHas("HeadSlot", II.EMPTY), "the head is not empty")
    local naked = gearInstance("naked")
    assertTrue(naked.NS.Inventory.Cache():SlotHas("HeadSlot", naked.NS.ItemInfo.EMPTY), "an empty head")
end)

test("item match: with two copies SlotHas wants the exact one in the slot", function()
    -- upgrade_tracks: the champion chest worn, the hero copy (same id, other bonus) carried.
    local inst = gearInstance("upgrade_tracks")
    local NS = inst.NS
    local II = NS.ItemInfo
    local cache = NS.Inventory.Cache()
    local hero = II.Snapshot(II.FromLink(DB.chest_hero.link))
    local champ = II.Snapshot(II.FromLink(DB.chest_champion.link))
    assertTrue(cache:SlotHas("ChestSlot", champ), "the worn champion copy")
    -- red under: SlotHas answering true for any copy of the id in the slot (no exact check).
    assertFalse(cache:SlotHas("ChestSlot", hero), "the hero copy is in the bags, not the slot")
    assertEqual(#cache:FindAll(hero), 2, "both copies are owned")
end)

test("item match: the client path admits a secret slot as empty (Q12)", function()
    local inst = gearInstance("secret_slots")
    local cache = inst.NS.Inventory.Cache()
    assertNil(cache.byID[DB.secret_helm.id], "a secret link is never matched or stored")
    assertTrue(cache.byID[DB.chest_plate.id] ~= nil, "the readable chest is cached")
end)

-- ── NextCooldownItem (B19, Q10) ───────────────────────────────────────────────────────────────

local TRINKET = 212040   -- trinket_use, "Use: Tick"

test("item match: NextCooldownItem prefers the worn copy that is ready", function()
    local inst = gearInstance("cooldowns")
    inst.mocks.__now = 150
    local info, secs = inst.NS.Inventory.NextCooldownItem({ TRINKET })
    assertTrue(info ~= nil, "found")
    assertEqual(info.loc.slotName, "Trinket0Slot", "the worn copy")
    assertEqual(secs, 0, "ready: it has a use effect and no cooldown")
end)

test("item match: a boolean `enabled` cooldown counts (B19)", function()
    -- The bag copy's cooldown is { 100, 120, true }: at 150 it has 70 s left.
    local inst = gearInstance("cooldowns", { equipped = {} })
    inst.mocks.__now = 150
    local info, secs = inst.NS.Inventory.NextCooldownItem({ TRINKET }, true)
    assertEqual(info.loc.bag, 0)
    -- red under: testing `enabled == 1` (the legacy check): a boolean true then reads as "no
    -- cooldown", the use effect answers 0.
    assertEqual(secs, 70, "the running cooldown")
end)

test("item match: a bag item has a 30 s floor unless ignoreSwapCooldown (Q10)", function()
    local inst = gearInstance("cooldowns", { equipped = {} })
    inst.mocks.__now = 200                       -- 20 s left on the bag copy
    local _, floored = inst.NS.Inventory.NextCooldownItem({ TRINKET })
    -- red under: dropping the bag floor (or applying it only under ignoreSwapCooldown).
    assertEqual(floored, 30, "a bag item needs the swap: at least 30 s")
    local _, raw = inst.NS.Inventory.NextCooldownItem({ TRINKET }, true)
    assertEqual(raw, 20, "ignoreSwapCooldown takes the real time")
end)

test("item match: no use effect counts as 30 s; unknown ids find nothing", function()
    local inst = gearInstance("geared")
    -- trinket_passive is worn and has no "Use:" line.
    local info, secs = inst.NS.Inventory.NextCooldownItem({ DB.trinket_passive.id })
    assertTrue(info ~= nil)
    assertEqual(secs, 30, "no Use: line, lowest priority")
    local none, noSecs = inst.NS.Inventory.NextCooldownItem({ 999999 })
    assertNil(none)
    assertNil(noSecs)
    -- The best of several ids: the ready on-use trinket beats the passive one.
    local best, bestSecs = inst.NS.Inventory.NextCooldownItem({ DB.trinket_passive.id, TRINKET })
    assertEqual(best.id, TRINKET)
    assertEqual(bestSecs, 0)
end)

test("item match: a secret cooldown start is treated as 30 s", function()
    local inst = gearInstance("cooldowns", {
        equipped = {},
        bags = { [0] = { items = { [1] = { key = "trinket_use", cooldown = { T.secret(100), 120, true } } } } },
    })
    inst.mocks.__now = 150
    local _, secs = inst.NS.Inventory.NextCooldownItem({ TRINKET }, true)
    -- red under: reading a nil (secret) start as "not on cooldown" (the use effect would answer 0).
    assertEqual(secs, 30)
end)

-- ── SlotItemActive and HasUseEffect ───────────────────────────────────────────────────────────

-- The worn trinket's tooltip gains "Use: ... for 20 sec" and its cooldown starts at 100.
local function activeTrinket(M)
    M.__gear:load("cooldowns", { equipped = { Trinket0Slot = { key = "trinket_use", cooldown = { 100, 120, 1 } } } })
    local base = M.C_TooltipInfo.GetInventoryItem
    M.C_TooltipInfo.GetInventoryItem = function(unit, id)
        local data = base(unit, id)
        if data and id == 13 then
            data.lines[#data.lines + 1] = { leftText = "Use: Speeds time for 20 sec.", leftColor = { r = 0, g = 1, b = 0 } }
        end
        return data
    end
end

test("item match: SlotItemActive is true while the use effect lasts", function()
    local inst = T.load({ mutate = activeTrinket })
    local Inv2 = inst.NS.Inventory
    inst.mocks.__now = 110
    assertTrue(Inv2.SlotItemActive("Trinket0Slot"), "10 s into a 20 s effect")
    inst.mocks.__now = 125
    -- red under: comparing against the cooldown's duration (120) rather than the use duration (20).
    assertFalse(Inv2.SlotItemActive("Trinket0Slot"), "the effect ended at 120")
    assertFalse(Inv2.SlotItemActive("Trinket1Slot"), "nothing worn there")
end)

test("item match: SlotItemActive is false off cooldown and without a duration line", function()
    local inst = gearInstance("cooldowns")
    inst.mocks.__now = 110
    assertFalse(inst.NS.Inventory.SlotItemActive("Trinket0Slot"), "no cooldown running")
    local cd = gearInstance("cooldowns", { equipped = { Trinket0Slot = { key = "trinket_use", cooldown = { 100, 120, 1 } } } })
    cd.mocks.__now = 101
    assertFalse(cd.NS.Inventory.SlotItemActive("Trinket0Slot"), "a cooldown, but no use duration on the tooltip")
end)

test("item match: HasUseEffect reads the item's spell", function()
    local I = Inv()
    assertTrue(I.HasUseEffect(DB.trinket_use.link))
    assertFalse(I.HasUseEffect(DB.trinket_passive.link))
    assertFalse(I.HasUseEffect(nil))
    assertFalse(I.HasUseEffect(T.secret(DB.trinket_use.link)), "a secret link is no item")
end)
