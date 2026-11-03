-- tests/test_equip_plan.lua — P4.7 (design §5.11): the pure change-list builder NS.Changes and the
-- bag moves NS.Moves. The plan is checked three ways:
--   * Build over hand-made infos (Inv.NewCache): durability order, the working copy and its claims,
--     empty markers, phantoms, TGFix and the miss path.
--   * Unique.Order replays tests/fixtures/legacy/plans.lua's `unique` captures, and its pass bound.
--   * Opt.Apply over hand-made change lists, the optimize the legacy addon meant to run (B1 fixed):
--     TGFix first, the off hand after/before the main hand, one off-hand clear for a two-hander (B2),
--     and the ring, trinket and MH<->OH swaps (INV §3.3; hand-authored, the legacy one never ran).
-- Build also runs over Inv.Cache() for a few mock_gear scenarios, and NS.Moves moves items for real
-- in tests/mock_gear.lua. NS.Changes and NS.Moves call no module that has not landed, so no fakes.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local LEGACY = T.legacy.plans
local SLOT_IDS = T.gear.SLOT_IDS
local OH, MH = "SecondaryHandSlot", "MainHandSlot"

local function NS() return T.NS end

-- ── hand-made infos and records ───────────────────────────────────────────────────────────────

local INVTYPE = { HeadSlot = "INVTYPE_HEAD", Finger0Slot = "INVTYPE_FINGER", Finger1Slot = "INVTYPE_FINGER",
                  Trinket0Slot = "INVTYPE_TRINKET", Trinket1Slot = "INVTYPE_TRINKET", MainHandSlot = "INVTYPE_WEAPON",
                  SecondaryHandSlot = "INVTYPE_SHIELD", BackSlot = "INVTYPE_CLOAK", ChestSlot = "INVTYPE_CHEST",
                  FeetSlot = "INVTYPE_FEET", NeckSlot = "INVTYPE_NECK", WristSlot = "INVTYPE_WRIST" }

-- An info as the cache holds one; `uniqueKeys = false` keeps UniqueKeys off the client.
local function info(id, loc, extra)
    local t = { id = id, suffix = 0, name = "Item" .. id, loc = loc, uniqueKeys = false }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end
local function worn(slot, id, extra)
    local e = { invType = INVTYPE[slot] }
    for k, v in pairs(extra or {}) do e[k] = v end
    return info(id, { slotID = SLOT_IDS[slot], slotName = slot }, e)
end
local function bagged(bag, slot, id, extra) return info(id, { bag = bag, slot = slot }, extra) end
local function rec(id) return { id = id, suffix = 0, name = "Item" .. id } end

local function build(compiled, infos, ctx)
    return NS().Changes.Build(compiled, NS().Inventory.NewCache(infos), ctx or {})
end

-- One change as a short string: slot, then "!tg", "<bag/slot", "<SlotName" or "-" (empty it).
local function show(c)
    local tail
    if c.tgFix then tail = "!tg"
    elseif c.to and c.to.slotName then tail = "<" .. c.to.slotName
    elseif c.to then tail = "<" .. c.to.bag .. "/" .. c.to.slot
    else tail = "-" end
    return c.slot .. tail
end
local function plan(changes)
    local out = {}
    for i, c in ipairs(changes) do out[i] = show(c) end
    return table.concat(out, " ")
end

-- ── published ─────────────────────────────────────────────────────────────────────────────────

test("equip plan: NS.Changes and NS.Moves are published", function()
    local C, M = NS().Changes, NS().Moves
    for _, name in ipairs({ "Build", "ForMoves" }) do assertEqual(type(C[name]), "function", "Changes." .. name) end
    assertEqual(type(C.Unique.Order), "function", "Changes.Unique.Order")
    assertEqual(type(C.Opt.Apply), "function", "Changes.Opt.Apply")
    for _, name in ipairs({ "Pickup", "ToEmpty", "EmptyBagSlots", "EmptyBankSlots", "UnequipByName" }) do
        assertEqual(type(M[name]), "function", "Moves." .. name)
    end
end)

-- ── Build ─────────────────────────────────────────────────────────────────────────────────────

test("equip plan: changes run in SLOT_NAMES order, durability slots first (Q4)", function()
    -- red under: Unique.Order seeding rank2 with the list position while Build walks `compiled` with
    -- pairs (each alone still orders by slot: the walk is pinned by the contested-item case below).
    local slots = { "Trinket1Slot", "BackSlot", "HeadSlot", "Finger0Slot", "FeetSlot", "MainHandSlot", "NeckSlot",
                    "WristSlot", "ChestSlot" }
    local compiled, infos = {}, {}
    for i, slot in ipairs(slots) do
        compiled[slot] = rec(100 + i)
        infos[#infos + 1] = bagged(0, i, 100 + i, { invType = INVTYPE[slot] })
    end
    local changes = build(compiled, infos)
    local want = {}
    for _, slot in ipairs(NS().ItemData.SLOT_NAMES) do
        if compiled[slot] then want[#want + 1] = slot end
    end
    assertEqual(#changes, #want, "one change per wanted slot")
    for i, slot in ipairs(want) do assertEqual(changes[i].slot, slot, "position " .. i) end
    assertEqual(changes[1].slotID, SLOT_IDS.HeadSlot, "the slot id rides on the change")
    assertEqual(changes[1].itemName, "Item103", "the item name rides on the change")
end)

test("equip plan: the slots are walked in SLOT_NAMES order, so the earlier slot wins a contested item", function()
    local missed = {}
    local changes = build({ Finger1Slot = rec(300), Finger0Slot = rec(300) },
                          { bagged(0, 1, 300, { invType = "INVTYPE_FINGER" }) },
                          { showError = function(_, _, slot) missed[#missed + 1] = slot end })
    assertEqual(plan(changes), "Finger0Slot<0/1")
    assertEqual(table.concat(missed, ","), "Finger1Slot")
    -- The walk itself, seen through the misses it reports in turn.
    missed = {}
    local compiled = {}
    for i, slot in ipairs(NS().ItemData.SLOT_NAMES) do compiled[slot] = rec(900 + i) end
    build(compiled, {}, { showError = function(_, _, slot) missed[#missed + 1] = slot end })
    -- red under: walking `compiled` with pairs.
    assertEqual(table.concat(missed, ","), table.concat(NS().ItemData.SLOT_NAMES, ","))
end)

test("equip plan: a satisfied slot is dropped from a working copy and its item is claimed", function()
    local ring = worn("Finger0Slot", 300)
    local compiled = { Finger0Slot = rec(300), Finger1Slot = rec(300) }
    local errors = {}
    local changes = build(compiled, { ring }, { showError = function(item, dup, slot)
        errors[#errors + 1] = { item = item, dup = dup, slot = slot }
    end })
    assertEqual(#changes, 0, "the worn ring is not moved, and its one copy is not handed to Finger1")
    -- red under: not claiming the satisfied slot's item (Finger1 would take the worn ring).
    assertEqual(#errors, 1, "Finger1's miss is reported")
    assertEqual(errors[1].slot, "Finger1Slot")
    assertTrue(errors[1].dup == ring, "the claimed copy is reported as already used")
    -- red under: removing the satisfied slot from `compiled` itself.
    assertTrue(compiled.Finger0Slot ~= nil, "the caller's compiled outfit is untouched")
end)

test("equip plan: an empty marker empties an occupied slot and leaves an empty one alone", function()
    local changes = build({ HeadSlot = { id = 0 }, NeckSlot = { id = 0 } }, { worn("HeadSlot", 1) })
    assertEqual(plan(changes), "HeadSlot-", "only the occupied slot gets an empty change")
    assertEqual(changes[1].itemName, "Item1", "the empty change names what it takes off")
end)

test("equip plan: phantom off-hands are skipped, with no error", function()
    local seen = 0
    local ctx = { showError = function() seen = seen + 1 end }
    local changes = build({ SecondaryHandSlot = rec(133948) }, {}, ctx)
    assertEqual(#changes, 0, "no change for a phantom")
    -- red under: dropping the phantom check (the miss would reach showError).
    assertEqual(seen, 0, "a phantom is not a missing item")
    changes = build({ SecondaryHandSlot = rec(4242) }, {}, { phantom = { [4242] = true }, showError = ctx.showError })
    assertEqual(#changes + seen, 0, "ctx.phantom replaces the default list")
end)

test("equip plan: a missing item reports through showError and plans nothing for the slot", function()
    local got
    local changes = build({ HeadSlot = rec(77) }, {}, { showError = function(item, dup, slot)
        got = { item = item, dup = dup, slot = slot }
    end })
    assertEqual(#changes, 0)
    assertEqual(got.item.id, 77)
    assertNil(got.dup, "nothing claimed")
    assertEqual(got.slot, "HeadSlot")
    assertEqual(#build({ HeadSlot = rec(77) }, {}), 0, "no showError in ctx is fine")
end)

test("equip plan: a matching plan is empty, a table and not nil (B3's no-execute input)", function()
    local changes = build({ HeadSlot = rec(1) }, { worn("HeadSlot", 1) })
    assertEqual(type(changes), "table")
    assertEqual(#changes, 0)
end)

test("equip plan: TGFix unequips a two-hander held in the off hand without Titan's Grip, first", function()
    local infos = { worn(OH, 50, { invType = "INVTYPE_2HWEAPON" }), worn("HeadSlot", 1), bagged(0, 1, 2) }
    local compiled = { [OH] = rec(50), HeadSlot = rec(2) }
    local changes = build(compiled, infos, { canDW2H = false })
    assertEqual(plan(changes), "SecondaryHandSlot!tg HeadSlot<0/1", "TGFix goes first")
    assertEqual(changes[1].itemName, "Item50")
    -- red under: queuing TGFix whatever canDW2H says.
    assertEqual(plan(build(compiled, infos, { canDW2H = true })), "HeadSlot<0/1", "a gripped two-hander stays")
    -- Under the glitch the off hand reads empty: an empty marker there plans no second clear.
    compiled[OH] = { id = 0 }
    assertEqual(plan(build(compiled, infos, { canDW2H = false })), "SecondaryHandSlot!tg HeadSlot<0/1")
end)

test("equip plan: TGFix over the client's gear, with CanDualWield2H = a WARRIOR in spec 2", function()
    for _, case in ipairs({ { spec = 2, tg = false }, { spec = 1, tg = true } }) do
        local inst = T.load({ mutate = function(M) M.__gear:load("tg_warrior", { spec = case.spec }) end })
        local N = inst.NS
        N.PlayerState.Refresh()
        assertEqual(N.PlayerState.CanDualWield2H(), case.spec == 2, "spec " .. case.spec)
        local cache = N.Inventory.Cache()
        local compiled = {}
        for _, slot in ipairs({ "HeadSlot", MH, OH }) do compiled[slot] = N.ItemInfo.Snapshot(cache.worn[slot]) end
        local changes = N.Changes.Build(compiled, cache, { canDW2H = N.PlayerState.CanDualWield2H() })
        assertEqual(#changes > 0 and changes[1].tgFix == true, case.tg, "spec " .. case.spec .. " TGFix")
    end
end)

test("equip plan: unique-equip deltas are -1 per key going out and +1 per key coming in", function()
    local infos = { worn("Finger0Slot", 10, { uniqueKeys = { c1 = true } }),
                    bagged(0, 1, 11, { uniqueKeys = { c1 = true, c2 = true }, invType = "INVTYPE_FINGER" }) }
    local changes = build({ Finger0Slot = rec(11) }, infos)
    assertEqual(#changes, 1)
    assertEqual(changes[1].unique.c1 or 0, 0, "c1 out and in")
    assertEqual(changes[1].unique.c2, 1, "c2 in")
    assertEqual(changes[1].rank, 3, "an increase only ranks 3")
end)

test("equip plan: a two-hander the player cannot grip carries meta TwoHandSlot, a gripped one Weapon0Slot", function()
    local infos = { bagged(0, 1, 60, { invType = "INVTYPE_2HWEAPON", meta = "TwoHandSlot" }) }
    local changes = build({ [MH] = rec(60) }, infos, { canDW2H = false })
    assertEqual(changes[#changes].meta, "TwoHandSlot")
    changes = build({ [MH] = rec(60) }, { bagged(0, 1, 60, { invType = "INVTYPE_2HWEAPON", meta = "TwoHandSlot" }) },
                    { canDW2H = true })
    assertEqual(changes[1].meta, "Weapon0Slot")
end)

-- ── Unique.Order ──────────────────────────────────────────────────────────────────────────────

test("equip plan: unique-equip ranks equal the legacy captures (fixtures/legacy/plans.lua)", function()
    assertTrue(#LEGACY.unique >= 4, "the capture has cases")
    for _, case in ipairs(LEGACY.unique) do
        local changes = {}
        for i, pair in ipairs(case.input) do
            local unique = {}
            for k, v in pairs(pair[2]) do unique[k] = v end
            changes[i] = { slot = pair[1], unique = unique }
        end
        NS().Changes.Unique.Order(changes)
        assertEqual(#changes, #case.output, case.name)
        for i, want in ipairs(case.output) do
            assertEqual(changes[i].slot, want.slot, case.name .. " slot " .. i)
            assertEqual(changes[i].rank, want.rank, case.name .. " rank " .. i)
        end
    end
end)

test("equip plan: Unique.Order runs at most 20 passes", function()
    -- A chain where each pass promotes exactly one more link: link k takes key k-1, which the links
    -- already at rank 1 have freed, and frees key k for the next. L0 starts at rank 1.
    local chain = { { slot = "L0", unique = { k0 = -1 } } }
    for k = 1, 30 do chain[#chain + 1] = { slot = "L" .. k, unique = { ["k" .. (k - 1)] = 1, ["k" .. k] = -1 } } end
    NS().Changes.Unique.Order(chain)
    local promoted = 0
    for _, c in ipairs(chain) do if c.rank == 1 then promoted = promoted + 1 end end
    -- red under: an unbounded `while` in place of the 20-pass loop (all 31 at rank 1).
    assertEqual(promoted, 1 + 20, "L0 and one link per pass")
    assertEqual(chain[#chain].rank, 2, "the links past the bound stay mixed")
    assertEqual(chain[1].slot, "L0", "rank 1 first")
    assertNil(chain[1].seq, "no sort scratch is left on a change")
end)

-- ── Opt.Apply (hand-authored from INV §3.3: the legacy optimize never ran, B1) ────────────────

local function ch(slot, to, extra)
    local c = { slot = slot, slotID = SLOT_IDS[slot], to = to, unique = {} }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local BAG1, BAG2 = { bag = 0, slot = 1 }, { bag = 0, slot = 2 }
local function at(slot) return { slotID = SLOT_IDS[slot], slotName = slot } end
local function apply(list)
    NS().Changes.Opt.Apply(list)
    return plan(list)
end

test("equip plan: optimize runs (B1) and puts TGFix first", function()
    assertEqual(apply({ ch("HeadSlot", BAG1), ch(OH, nil, { tgFix = true }) }), "SecondaryHandSlot!tg HeadSlot<0/1")
end)

test("equip plan: an equipping off hand goes after the main hand, an emptying one before it", function()
    -- red under: findSlot answering nil (the legacy `not change and change.SlotName`, B1).
    assertEqual(apply({ ch(OH, BAG2), ch(MH, BAG1) }), "MainHandSlot<0/1 SecondaryHandSlot<0/2")
    assertEqual(apply({ ch(MH, BAG1), ch(OH, nil) }), "SecondaryHandSlot- MainHandSlot<0/1", "the Argent Lance fix")
    assertEqual(apply({ ch(MH, BAG1), ch(OH, BAG2) }), "MainHandSlot<0/1 SecondaryHandSlot<0/2", "already right")
end)

test("equip plan: a two-hander drops the off-hand change for ONE empty-OH change, marked done (B2)", function()
    local list = { ch(MH, BAG1, { meta = "TwoHandSlot" }), ch(OH, BAG2), ch("Trinket0Slot", { bag = 0, slot = 3 }) }
    -- red under: the legacy loop (B2): the two-hander left un-done and resumed at its own index, so it
    -- is visited again and inserts another clear, the earlier one kept.
    assertEqual(apply(list), "SecondaryHandSlot- MainHandSlot<0/1 Trinket0Slot<0/3")
    assertTrue(list[1].done, "the inserted clear is done")
    assertEqual(apply({ ch(MH, BAG1, { meta = "TwoHandSlot" }) }), "SecondaryHandSlot- MainHandSlot<0/1",
                "a clear is inserted with no off-hand change at all")
    assertEqual(apply({ ch(OH, nil, { tgFix = true }), ch(MH, BAG1, { meta = "TwoHandSlot" }) }),
                "SecondaryHandSlot!tg MainHandSlot<0/1", "TGFix already clears the off hand")
end)

test("equip plan: ring swaps are re-ordered so each move finds its slot free", function()
    local F0, F1 = "Finger0Slot", "Finger1Slot"
    assertEqual(apply({ ch(F0, at(F1)), ch(F1, at(F0)) }), "Finger0Slot<Finger1Slot Finger1Slot<Finger0Slot",
                "a straight swap is the client's to do")
    assertEqual(apply({ ch(F0, BAG1), ch(F1, at(F0)) }), "Finger1Slot- Finger1Slot<Finger0Slot Finger0Slot<0/1",
                "one to two: clear two, move one there, then fill one")
    assertEqual(apply({ ch(F1, at(F0)), ch(F0, BAG1) }), "Finger1Slot- Finger1Slot<Finger0Slot Finger0Slot<0/1",
                "the same whichever comes first")
    assertEqual(apply({ ch(F0, nil), ch(F1, at(F0)) }), "Finger1Slot- Finger1Slot<Finger0Slot",
                "one emptied for two: clear two instead")
    assertEqual(apply({ ch(F0, at(F1)), ch(F1, BAG1) }), "Finger0Slot- Finger0Slot<Finger1Slot Finger1Slot<0/1",
                "two to one: clear one, move two there, then fill two")
    assertEqual(apply({ ch(F0, at(F1)), ch(F1, nil) }), "Finger0Slot- Finger0Slot<Finger1Slot",
                "two emptied for one: clear one instead")
    local list = { ch(F0, BAG1), ch(F1, at(F0)) }
    apply(list)
    for i, c in ipairs(list) do assertTrue(c.done, "change " .. i .. " is done") end
end)

test("equip plan: trinket and main/off-hand swaps take the same re-order", function()
    assertEqual(apply({ ch("Trinket0Slot", BAG1), ch("Trinket1Slot", at("Trinket0Slot")) }),
                "Trinket1Slot- Trinket1Slot<Trinket0Slot Trinket0Slot<0/1")
    assertEqual(apply({ ch(MH, at(OH)), ch(OH, BAG1) }),
                "MainHandSlot- MainHandSlot<SecondaryHandSlot SecondaryHandSlot<0/1")
end)

test("equip plan: optimize is bounded", function()
    local list = {}
    for i = 1, 80 do list[i] = ch(i % 2 == 0 and OH or MH, i % 3 == 0 and BAG1 or nil) end
    NS().Changes.Opt.Apply(list)
    assertTrue(#list >= 80, "it returned")
end)

-- ── Build over the client's gear ──────────────────────────────────────────────────────────────

local function gear(scenario, overrides)
    local inst = T.load({ mutate = function(M) M.__gear:load(scenario, overrides) end })
    inst.NS.PlayerState.Refresh()
    return inst.NS, inst.mocks
end

-- What the cache holds in `slot` and for a bag key, as a record.
local function snapAt(N, cache, slot) return N.ItemInfo.Snapshot(cache.worn[slot]) end
local function snapKey(N, cache, key)
    local id = T.fixtures.items.db[key].id
    return N.ItemInfo.Snapshot(cache.byID[id][1])
end

test("equip plan: a rogue's two-hander plans one off-hand clear, then the main hand (B2)", function()
    local N = gear("dual_wield")
    local cache = N.Inventory.Cache()
    local compiled = { [MH] = snapKey(N, cache, "greatsword"), [OH] = { id = 0 } }
    local changes = N.Changes.Build(compiled, cache, { canDW2H = false })
    assertEqual(plan(changes), "SecondaryHandSlot- MainHandSlot<0/1")
end)

test("equip plan: swapping two worn rings plans the client's straight swap", function()
    local N = gear("geared")
    local cache = N.Inventory.Cache()
    local compiled = { Finger0Slot = snapAt(N, cache, "Finger1Slot"), Finger1Slot = snapAt(N, cache, "Finger0Slot") }
    assertEqual(plan(N.Changes.Build(compiled, cache, {})), "Finger0Slot<Finger1Slot Finger1Slot<Finger0Slot")
end)

-- ── ForMoves ──────────────────────────────────────────────────────────────────────────────────

test("equip plan: ForMoves lists each found item's location in slot order, filtered and claimed", function()
    local C = NS().Changes
    local infos = { bagged(6, 1, 1), bagged(0, 1, 2), worn("NeckSlot", 3) }
    local cache = NS().Inventory.NewCache(infos)
    local items = { NeckSlot = rec(3), HeadSlot = rec(1), FeetSlot = rec(2), BackSlot = { id = 0 },
                    WristSlot = rec(99), Finger0Slot = rec(1) }
    local changes = C.ForMoves(items, cache)
    assertEqual(#changes, 3, "found items once each; the empty marker and the missing item are skipped")
    assertTrue(changes[1].from == infos[1].loc and changes[2].from == infos[2].loc and changes[3].from == infos[3].loc,
               "Head, Feet, Neck: SLOT_NAMES order")
    assertEqual(changes[1].itemName, "Item1")
    assertNil(changes[1].slot, "a move has no target slot")
    local banked = C.ForMoves(items, cache, function(i) return i.loc.bag == 6 end)
    assertEqual(#banked, 1, "the filter decides")
    -- A shared pass carries claims across calls (the deposit-others path).
    local _, pass = C.ForMoves({ HeadSlot = rec(1) }, cache)
    assertEqual(#C.ForMoves({ HeadSlot = rec(1) }, cache, nil, pass), 0, "claimed by the first call")
end)

-- ── NS.Moves over mock_gear ───────────────────────────────────────────────────────────────────

local function printed(M) return table.concat(M.__printed(), "\n") end

test("equip plan: EmptyBagSlots walks the carried bags from the last down, the reagent bag left out", function()
    local N = gear("geared")
    local slots = N.Moves.EmptyBagSlots()
    assertEqual(#slots, 11 + 15 + 16 + 4 + 4, "every free carried slot")
    assertEqual(slots[1].bag, 4, "the last carried bag first")
    assertEqual(slots[#slots].bag, 0, "the backpack last")
    for _, s in ipairs(slots) do
        assertTrue(s.bag ~= 5, "no reagent bag slot")
        assertEqual(s.bagType, 0, "general bags")
    end
    local seen = {}
    for _, s in ipairs(slots) do if s.bag == 0 then seen[s.slot] = true end end
    -- red under: listing a slot without checking it is empty.
    assertFalse(seen[1] or seen[5] or false, "occupied backpack slots are not listed")
end)

test("equip plan: EmptyBankSlots lists the open bank's tabs only", function()
    local N = gear("bank_open")
    local slots = N.Moves.EmptyBankSlots()
    assertEqual(#slots, 95 + 98, "tab 6 and tab 7's free slots")
    for _, s in ipairs(slots) do assertTrue(s.bag == 6 or s.bag == 7, "bank tab " .. s.bag) end
    N = gear("bank_closed")
    assertEqual(#N.Moves.EmptyBankSlots(), 0, "nothing while the bank is closed")
end)

test("equip plan: ToEmpty moves a worn item into a bag and spends the slot", function()
    local N, M = gear("geared")
    local slots = N.Moves.EmptyBagSlots()
    local before = #slots
    local first = slots[1]
    assertTrue(N.Moves.ToEmpty({ slotID = SLOT_IDS.HeadSlot, slotName = "HeadSlot" }, slots), "moved")
    assertNil(M.__gear:equipped("HeadSlot"), "the head is off")
    assertTrue(M.__gear:bagItem(first.bag, first.slot) ~= nil, "into the first general slot")
    assertEqual(#slots, before - 1, "the slot is spent")
    assertTrue(N.Moves.ToEmpty({ slotID = SLOT_IDS.HeadSlot, slotName = "HeadSlot" }, slots), "an empty slot is done")
    assertEqual(#slots, before - 1, "and spends nothing")
end)

test("equip plan: ToEmpty with the bags full prints the error key's line and moves nothing", function()
    local N, M = gear("full_bags")
    local loc = { slotID = SLOT_IDS.HeadSlot, slotName = "HeadSlot" }
    assertFalse(N.Moves.ToEmpty(loc, N.Moves.EmptyBagSlots()), "refused")
    assertTrue(M.__gear:equipped("HeadSlot") ~= nil, "still worn")
    assertTrue(printed(M):find("because all bags are full", 1, true) ~= nil, "the bags-full line")
    assertTrue(printed(M):find("Can't remove", 1, true) ~= nil, "the default key is the unequip one")
    N.Moves.ToEmpty(loc, {}, "withdrawFull")
    assertTrue(printed(M):find("Can't withdraw", 1, true) ~= nil, "withdrawFull")
    N.Moves.ToEmpty(loc, nil, "bankFull")
    assertTrue(printed(M):find("all bank bags are full", 1, true) ~= nil, "bankFull, and no slot list at all")
end)

test("equip plan: ToEmpty tries a specialty bag first, and never drops gear into one", function()
    local N, M = gear("specialty_bags", { bags = {
        [0] = { items = { [1] = "herb_silverleaf" } },
        [1] = { bag = "bag_herb", items = {} },
        [2] = { bag = "bag_backpack16", items = {} },
    } })
    local slots = N.Moves.EmptyBagSlots()
    assertEqual(slots[1].bag, 2, "the general bag is walked first")
    -- red under: taking the first slot of any kind (the herb would land in bag 2).
    assertTrue(N.Moves.ToEmpty({ bag = 0, slot = 1 }, slots), "moved")
    local inst = M.__gear:bagItem(1, 1)
    assertTrue(inst ~= nil and inst.def.id == T.fixtures.items.db.herb_silverleaf.id, "the herb went to the herb bag")
    -- Gear with only the herb bag free: refused.
    N, M = gear("specialty_bags")
    assertFalse(N.Moves.ToEmpty({ slotID = SLOT_IDS.HeadSlot, slotName = "HeadSlot" }, N.Moves.EmptyBagSlots()),
                "no general slot")
    assertTrue(M.__gear:equipped("HeadSlot") ~= nil, "the helm stays on")
end)

test("equip plan: Pickup routes a bag location and an equipment slot", function()
    local N, M = gear("geared")
    local calls = M.__equipCalls
    local n = #calls
    N.Moves.Pickup({ bag = 0, slot = 1 })
    assertEqual(calls[n + 1][1], "PickupContainerItem")
    N.Compat.ClearCursor()
    N.Moves.Pickup({ slotID = 1, slotName = "HeadSlot" })
    assertEqual(calls[#calls][1], "PickupInventoryItem")
    N.Compat.ClearCursor()
end)

test("equip plan: UnequipByName takes a slot number or a case-insensitive name", function()
    local N, M = gear("geared")
    assertTrue(N.Moves.UnequipByName(tostring(SLOT_IDS.HeadSlot)), "by slot number")
    assertNil(M.__gear:equipped("HeadSlot"))
    local name = T.fixtures.items.db.sword_1h.name
    assertTrue(N.Moves.UnequipByName(name:upper()), "by name, any case")
    assertNil(M.__gear:equipped(MH))
end)

test("equip plan: UnequipByName returns after a name it cannot find (INV §19)", function()
    local N, M = gear("geared")
    local n = #M.__equipCalls
    local ok, msg = N.Moves.UnequipByName("Nothing Like It")
    assertFalse(ok)
    assertEqual(msg, "Couldn't find an item named Nothing Like It")
    assertTrue(printed(M):find(msg, 1, true) ~= nil, "the line is printed")
    -- red under: falling through to the pickup, as the legacy function did.
    assertEqual(#M.__equipCalls, n, "no cursor call")
    ok = N.Moves.UnequipByName(tostring(SLOT_IDS.HeadSlot))
    assertTrue(ok)
    ok, msg = N.Moves.UnequipByName(tostring(SLOT_IDS.HeadSlot))
    assertFalse(ok, "an empty slot number has nothing to unequip")
    assertEqual(msg, "Couldn't find an item named " .. SLOT_IDS.HeadSlot)
end)
