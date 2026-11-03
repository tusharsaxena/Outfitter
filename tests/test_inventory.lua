-- tests/test_inventory.lua — P4.5's scan half (design §5.4, §5.5): the bag range with the bank closed
-- and open, the bank-bag set, what the cache admits (BoE out, the min-level check off), the 0.01 s
-- debounce and the PLAYER_ENTERING_WORLD sync, the INVENTORY_CHANGED payload, the window's item
-- sections, Missing / Unused / OutfitsUsing, the one GET_ITEM_INFO_RECEIVED registration (B5), the
-- per-pass claims (B9) and the warband bank, pinned as not scanned (O19).
--
-- NS.Outfits lands in P4.6 (a parallel task), NS.Equip in P4.8 and NS.EM in P4.10: every call into
-- them runs against a recorded fake (design §12, the fake rule); their own suites pin the real side.

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DB = T.fixtures.items.db

local function gearInstance(scenario, overrides)
    return unitLoad({ mutate = function(M)
        if scenario then M.__gear:load(scenario, overrides) end
    end })
end

-- Equip's load gate, as P4.8 will answer it: `loading` = between PLAYER_LEAVING_WORLD and PEW.
local function fakeEquip(NS, loading)
    local state = { loading = loading == true }
    local f = T.fake(NS, "Equip", { SuspendedForLoad = function() return state.loading end })
    return f, state
end

-- The outfit store, as P4.6 will answer it: `recs` is a list of outfit records.
local function fakeOutfits(NS, recs)
    local byID, ids = {}, {}
    for _, r in ipairs(recs) do
        byID[r.id] = r
        ids[#ids + 1] = r.id
    end
    return T.fake(NS, "Outfits", {
        Categories = function() return { "Complete", "Accessory" } end,
        Ids = function(category) if category == "Complete" then return ids end return {} end,
        Get = function(id) return byID[id] end,
        Items = function(r) return r.items end,
    })
end

local function snap(NS, key)
    return NS.ItemInfo.Snapshot(NS.ItemInfo.FromLink(DB[key].link))
end

-- Up and running: Equip not loading, the module resumed, the first sync done.
local function running(inst)
    fakeEquip(inst.NS, false)
    inst.NS.Inventory.Resume()
    inst.mocks.__fireTimers()
end

local function contains(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

local function ids(list)
    local out = {}
    for i, info in ipairs(list) do out[i] = info.id end
    return out
end

-- ── the bag range and the bank ────────────────────────────────────────────────────────────────

test("inventory: the bags are 0 through the reagent bag with the bank closed", function()
    local inst = gearInstance("geared")
    running(inst)
    local bags = inst.NS.Inventory.BagIDs()
    assertEqual(table.concat(bags, ","), "0,1,2,3,4,5")
    assertFalse(inst.NS.Inventory.BankOpen())
end)

test("inventory: with the bank open the character tabs join, and they make the bank-bag set", function()
    local inst = gearInstance("bank_closed")
    running(inst)
    local I = inst.NS.Inventory
    inst.mocks.__gear:openBank()
    assertTrue(I.BankOpen(), "BANKFRAME_OPENED / the banker interaction opened it")
    assertEqual(table.concat(I.BagIDs(), ","), "0,1,2,3,4,5,6,7,8,9,10,11")
    for bag = 6, 11 do assertTrue(I.IsBankBag(bag), "tab " .. bag .. " is a bank bag") end
    -- red under: the legacy `i > NUM_TOTAL_EQUIPPED_BAG_SLOTS or i < 0` heuristic (12 and up, the
    -- warband tabs, would read as bank bags of this character).
    for _, bag in ipairs({ 0, 1, 4, 5, 12 }) do assertFalse(I.IsBankBag(bag), bag .. " is not") end
    inst.mocks.__gear:closeBank()
    assertFalse(I.BankOpen())
    assertEqual(#I.BagIDs(), 6, "closed again: the bank tabs leave the range")
end)

test("inventory: a stand-down with the bank open fails closed, so a bank closed while down leaves the scan", function()
    local inst = gearInstance("bank_closed")
    running(inst)
    local I = inst.NS.Inventory
    inst.mocks.__gear:openBank()
    assertTrue(I.BankOpen())
    I.Suspend()
    inst.mocks.__gear:closeBank()   -- BANKFRAME_CLOSED goes unheard: nothing is registered
    I.Resume()
    -- red under: Suspend leaving bankOpen alone (the closed bank's tabs stay in the scan).
    assertFalse(I.BankOpen(), "the stand-down closed the bank flag")
    assertEqual(#I.BagIDs(), 6, "the bank tabs left the range")
    inst.mocks.__gear:openBank()
    assertTrue(I.BankOpen(), "the next open reopens it")
end)

test("inventory: a banked item reads missing while the bank is closed, banked once it opens", function()
    local inst = gearInstance("bank_closed")
    running(inst)
    local NS, I = inst.NS, inst.NS.Inventory
    local outfit = { id = "o1", kind = "native",
                     items = { HeadSlot = snap(NS, "head_plate"), LegsSlot = snap(NS, "legs_plate") } }
    local missing, banked = I.Missing(outfit)
    assertEqual(#missing, 1, "the legs are in the closed bank")
    assertEqual(missing[1].id, DB.legs_plate.id)
    assertEqual(#banked, 0)
    inst.mocks.__gear:openBank()
    inst.mocks.__fireTimers()
    missing, banked = I.Missing(outfit)
    assertEqual(#missing, 0, "the bank is open: nothing missing")
    assertEqual(#banked, 1, "the legs are banked")
    assertEqual(banked[1].id, DB.legs_plate.id)
end)

test("inventory: Missing skips phantoms and empty markers, and hands EM outfits to NS.EM", function()
    local inst = gearInstance("naked")
    local NS = inst.NS
    local outfit = { id = "o1", kind = "native",
                     items = { HeadSlot = NS.ItemInfo.EMPTY, SecondaryHandSlot = { id = 133948 } } }
    local missing, banked = NS.Inventory.Missing(outfit)
    -- red under: testing every non-nil item (an empty marker or a phantom off-hand would read missing).
    assertEqual(#missing, 0)
    assertEqual(#banked, 0)
    local em = T.fake(NS, "EM", { Missing = function() return { "m" }, { "b" } end })
    local m, b = NS.Inventory.Missing({ id = "o2", kind = "em", setID = 3 })
    assertEqual(em.__count("Missing"), 1, "the EM kind asks NS.EM")
    assertEqual(m[1], "m")
    assertEqual(b[1], "b")
end)

test("inventory: the warband bank is not scanned (O19)", function()
    local inst = gearInstance("bank_open", {
        bank = { [6] = { size = 98, items = { [1] = "legs_plate" } },
                 [12] = { size = 98, items = { [1] = "feet_plate" } } },
    })
    running(inst)
    local NS, I = inst.NS, inst.NS.Inventory
    inst.mocks.__gear:openBank()
    inst.mocks.__fireTimers()
    assertFalse(contains(I.BagIDs(), 12), "the first warband tab is outside the range")
    local missing = I.Missing({ id = "o1", kind = "native", items = { FeetSlot = snap(NS, "feet_plate") } })
    assertEqual(#missing, 1, "a warbound-tab item reads missing, the documented gap")
end)

-- ── what the cache admits ─────────────────────────────────────────────────────────────────────

test("inventory: the cache holds equipped gear and bag gear, without BoEs or non-gear", function()
    local inst = gearInstance("geared")
    local cache = inst.NS.Inventory.Cache()
    assertTrue(cache.byID[DB.head_plate.id] ~= nil, "worn")
    assertTrue(cache.byID[DB.greatsword.id] ~= nil, "carried gear")
    assertTrue(cache.byID[DB.warbound_cloak.id] ~= nil, "a warbound item is gear like any other")
    -- red under: dropping the `II.Bind(info) ~= "boe"` test from the bag scan.
    assertNil(cache.byID[DB.boe_legs.id], "an unbound BoE is not an outfit candidate")
    assertNil(cache.byID[DB.hearthstone.id], "a Hearthstone goes in no slot")
end)

test("inventory: the minimum-level check stays off (Q3)", function()
    -- A level 80 player, an item that wants 90 (and that the client calls unusable).
    local inst = gearInstance("geared", { bags = { [0] = { items = { [1] = "unusable_helm" } } } })
    local cache = inst.NS.Inventory.Cache()
    -- red under: admitting bag items only when `minLevel <= UnitLevel("player")`.
    assertTrue(cache.byID[DB.unusable_helm.id] ~= nil, "the min-level check is disabled, as in the legacy scan")
end)

-- ── the scan: debounce, events, payload ───────────────────────────────────────────────────────

local function liveDelays(M)
    local out = {}
    for _, t in ipairs(M.__timers()) do out[#out + 1] = t.delay end
    return out
end

test("inventory: bag events debounce into one 0.01 s sync", function()
    local inst = gearInstance("geared")
    running(inst)
    local M = inst.mocks
    local before = #M.__timers()
    M.__fire("BAG_UPDATE", 0)
    M.__fire("BAG_UPDATE_DELAYED")
    M.__fire("PLAYERBANKSLOTS_CHANGED", 1)
    M.__fire("UNIT_INVENTORY_CHANGED", "player")
    -- red under: ScheduleSync scheduling without canceling the pending one (four timers).
    assertEqual(#M.__timers(), before + 1, "one pending sync")
    assertTrue(contains(liveDelays(M), 0.01), "rescheduled at 0.01 s")
end)

test("inventory: another unit's inventory never reaches the scan", function()
    local inst = gearInstance("geared")
    running(inst)
    local M = inst.mocks
    local before = #M.__timers()
    M.__fire("UNIT_INVENTORY_CHANGED", "target")
    -- red under: registering UNIT_INVENTORY_CHANGED for every unit with no unit test in the handler.
    assertEqual(#M.__timers(), before, "the target's inventory scheduled a sync")
end)

test("inventory: events are dropped during a load, and PLAYER_ENTERING_WORLD always syncs", function()
    local inst = gearInstance("geared")
    local _, load = fakeEquip(inst.NS, false)
    inst.NS.Inventory.Resume()
    local M = inst.mocks
    M.__fireTimers()
    load.loading = true
    local before = #M.__timers()
    M.__fire("BAG_UPDATE", 0)
    -- red under: dropping the SuspendedForLoad read from the scan events' handler.
    assertEqual(#M.__timers(), before, "a bag update during a load scheduled a sync")
    M.__fire("PLAYER_ENTERING_WORLD", false, true)
    assertEqual(#M.__timers(), before + 1, "PEW schedules the sync whatever the load gate says")
end)

test("inventory: INVENTORY_CHANGED carries (equippedChanged, bagsChanged), only on a change", function()
    local inst = gearInstance("geared")
    local NS, M = inst.NS, inst.mocks
    fakeEquip(NS, false)
    local heard = {}
    local target = NS.NewBusTarget()
    target:RegisterMessage(NS.MSG.INVENTORY_CHANGED, function(_, eq, bags) heard[#heard + 1] = { eq, bags } end)
    local any, eq, bags = NS.Inventory.Sync()
    assertTrue(any and eq and bags, "the first sync sees everything")
    assertEqual(#heard, 1)
    assertFalse((NS.Inventory.Sync()), "nothing moved")
    -- red under: sending INVENTORY_CHANGED on every Sync.
    assertEqual(#heard, 1, "no change, no message")
    -- A move inside the backpack: bags only.
    M.C_Container.PickupContainerItem(0, 1)
    M.C_Container.PickupContainerItem(0, 10)
    NS.Inventory.Sync()
    assertEqual(#heard, 2)
    assertFalse(heard[2][1], "nothing worn changed")
    assertTrue(heard[2][2], "a bag changed")
    -- The helm leaves the head: equipped only.
    M.__gear.worn[1] = nil
    NS.Inventory.Sync()
    assertEqual(#heard, 3)
    assertTrue(heard[3][1])
    assertFalse(heard[3][2])
end)

test("inventory: a changed bag is flushed from the cache, and the next Cache() sees it", function()
    local inst = gearInstance("geared")
    local NS, M = inst.NS, inst.mocks
    NS.Inventory.Sync()
    local cache = NS.Inventory.Cache()
    local gs = cache.byID[DB.greatsword.id][1]
    assertEqual(gs.loc.slot, 1)
    M.C_Container.PickupContainerItem(0, 1)
    M.C_Container.PickupContainerItem(0, 10)
    NS.Inventory.Sync()
    -- red under: Sync not flushing the changed bag (the cache keeps the stale slot 1).
    assertEqual(NS.Inventory.Cache().byID[DB.greatsword.id][1].loc.slot, 10)
end)

test("inventory: a secret link is an empty slot to the scan (Q12)", function()
    local inst = gearInstance("secret_slots")
    local NS = inst.NS
    NS.Inventory.Sync()
    -- A fresh secret wrapper on every read: were it compared raw, every sync would see a change.
    -- red under: Compat.InventoryItemLink / ContainerItemLink in core/Compat.lua handing the raw link
    -- through (no Secrets.PlainString): the scan would then snapshot a new wrapper every time.
    assertFalse((NS.Inventory.Sync()), "the secret helm reads as a stable empty slot")
end)

-- ── B5: one registration ──────────────────────────────────────────────────────────────────────

local function countRegs(M, event)
    local n = 0
    for _, r in ipairs(M.__registrations()) do if r.event == event then n = n + 1 end end
    return n
end

test("inventory: one GET_ITEM_INFO_RECEIVED registration across 100 updates (B5)", function()
    local inst = gearInstance("geared")
    running(inst)
    local NS, M = inst.NS, inst.mocks
    for i = 1, 100 do
        M.__gear.worn[1] = (i % 2 == 0) and M.__gear.worn[1] or nil
        NS.Inventory.Sync()
        NS.Inventory.Flush()
        NS.Inventory.Cache()
    end
    -- red under: registering GET_ITEM_INFO_RECEIVED per cache (the legacy _InventoryCache:Construct).
    assertEqual(countRegs(M, "GET_ITEM_INFO_RECEIVED"), 1)
end)

test("inventory: GET_ITEM_INFO_RECEIVED flushes the cache so a late item's info is read", function()
    local inst = gearInstance("uncached")
    running(inst)
    local NS = inst.NS
    local legs = NS.Inventory.Cache().byID[DB.legs_plate.id][1]
    assertNil(legs.level, "the client has no info for the legs yet")
    inst.mocks.__gear:resolve("legs_plate")
    -- red under: no GET_ITEM_INFO_RECEIVED handler (the cache keeps the info-less entry).
    assertEqual(NS.Inventory.Cache().byID[DB.legs_plate.id][1].level, DB.legs_plate.level)
end)

-- ── the lists ─────────────────────────────────────────────────────────────────────────────────

test("inventory: sections are Odds 'n Ends, then Warbound, then the BoEs", function()
    local inst = gearInstance("geared")
    local NS = inst.NS
    fakeOutfits(NS, { { id = "o1", kind = "native", items = { HeadSlot = snap(NS, "head_plate") } } })
    local sections = NS.Inventory.ItemSections()
    local keys = {}
    for i, s in ipairs(sections) do keys[i] = s.key end
    assertEqual(table.concat(keys, ","), "unused,warbound,boe")
    local unused, warbound, boe = sections[1].items, sections[2].items, sections[3].items
    -- red under: Unused not claiming the outfits' items first (the helm would be listed).
    assertFalse(contains(ids(unused), DB.head_plate.id), "the outfit's helm is in use")
    assertTrue(contains(ids(unused), DB.chest_plate.id), "the worn chest is in no outfit")
    -- red under: Unused not excluding warbound items.
    assertFalse(contains(ids(unused), DB.warbound_cloak.id), "warbound is its own section")
    assertEqual(table.concat(ids(warbound), ","), tostring(DB.warbound_cloak.id))
    assertEqual(table.concat(ids(boe), ","), tostring(DB.boe_legs.id))
    for _, s in ipairs(sections) do assertTrue(type(s.labelKey) == "string" and s.labelKey ~= "", s.key) end
end)

test("inventory: Odds 'n Ends sorts by level, then name, then id, worn before carried", function()
    local inst = gearInstance("geared")
    local NS = inst.NS
    fakeOutfits(NS, {})
    local unused = NS.Inventory.Unused()
    table.sort(unused, NS.Inventory.CompareItems)
    for i = 2, #unused do
        local a, b = unused[i - 1], unused[i]
        assertTrue((a.level or 0) >= (b.level or 0), "level descends at " .. i)
        if a.level == b.level and a.name == b.name and a.id == b.id then
            assertTrue(a.loc.slotName ~= nil or b.loc.slotName == nil, "worn before carried at " .. i)
        end
    end
    local sorted = NS.Inventory.ItemSections()[1].items
    assertEqual(sorted[1].level, 639)
    assertEqual(sorted[#sorted].level, 1, "the shirt and tabard last")
end)

test("inventory: IGNORED_UNUSED items are never Odds 'n Ends", function()
    local inst = gearInstance("lances")
    local NS = inst.NS
    fakeOutfits(NS, {})
    -- red under: Unused not reading NS.ItemData.IGNORED_UNUSED (the Mining Pick would be listed).
    assertFalse(contains(ids(NS.Inventory.Unused()), DB.mining_pick.id))
    assertTrue(contains(ids(NS.Inventory.Unused()), DB.horde_lance.id))
end)

test("inventory: Unused's claims are per pass, so a deleted outfit frees its items (B9)", function()
    local inst = gearInstance("geared")
    local NS = inst.NS
    local recs = { { id = "o1", kind = "native", items = { HeadSlot = snap(NS, "head_plate") } } }
    fakeOutfits(NS, recs)
    assertFalse(contains(ids(NS.Inventory.Unused()), DB.head_plate.id))
    T.fake(NS, "Outfits", {
        Categories = function() return { "Complete", "Accessory" } end,
        Ids = function() return {} end,
        Get = function() return nil end,
        Items = function(r) return r.items end,
    })
    -- red under: Unused marking the item itself (the legacy UsedInOutfit, never reset).
    assertTrue(contains(ids(NS.Inventory.Unused()), DB.head_plate.id), "no outfit uses the helm now")
end)

test("inventory: two outfits on one ring claim it once; a second copy stays unused", function()
    local inst = gearInstance("unique_rings", {
        bags = { [0] = { items = { [1] = "ring_plain_a" } } },
    })
    local NS = inst.NS
    local ring = snap(NS, "ring_plain_a")
    fakeOutfits(NS, {
        { id = "o1", kind = "native", items = { Finger1Slot = ring } },
        { id = "o2", kind = "native", items = { Finger0Slot = ring } },
    })
    local unused = NS.Inventory.Unused()
    local n = 0
    for _, info in ipairs(unused) do if info.id == DB.ring_plain_a.id then n = n + 1 end end
    -- Two outfits, two copies: each claims one, none is left.
    assertEqual(n, 0)
    fakeOutfits(NS, { { id = "o1", kind = "native", items = { Finger1Slot = ring } } })
    n = 0
    for _, info in ipairs(NS.Inventory.Unused()) do if info.id == DB.ring_plain_a.id then n = n + 1 end end
    assertEqual(n, 1, "one outfit claims one copy; the other is unused")
end)

test("inventory: BoE and Warbound walk the bags only", function()
    local inst = gearInstance("geared", { equipped = { BackSlot = "warbound_cloak" } })
    local I = inst.NS.Inventory
    -- The worn cloak is bound now in the client, and the bag copy is still warbound.
    assertEqual(#I.Warbound(), 1)
    assertEqual(I.Warbound()[1].loc.bag, 1)
    assertEqual(#I.BoE(), 1)
end)

test("inventory: OutfitsUsing pairs the rings, the trinkets and the weapons", function()
    local inst = gearInstance("geared")
    local NS = inst.NS
    local ring = snap(NS, "ring_plain_a")
    fakeOutfits(NS, {
        { id = "o1", kind = "native", items = { Finger0Slot = ring } },
        { id = "o2", kind = "native", items = { Finger1Slot = ring } },
        { id = "o3", kind = "native", items = { HeadSlot = snap(NS, "head_plate") } },
    })
    local worn = NS.ItemInfo.FromSlot("Finger0Slot")
    local using = NS.Inventory.OutfitsUsing(worn)
    -- red under: comparing only the item's own slot (o2 keeps the ring in the other finger).
    assertEqual(table.concat(using, ","), "o1,o2")
    assertEqual(table.concat(NS.Inventory.OutfitsUsing(NS.ItemInfo.FromSlot("HeadSlot")), ","), "o3")
    assertEqual(#NS.Inventory.OutfitsUsing(NS.ItemInfo.FromSlot("ChestSlot")), 0)
    assertEqual(#NS.Inventory.OutfitsUsing(nil), 0)
end)

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

test("inventory: Suspend drops every registration and the pending sync; Resume rebuilds them", function()
    local inst = gearInstance("geared")
    fakeEquip(inst.NS, false)
    local M, I = inst.mocks, inst.NS.Inventory
    local base = #M.__registrations()
    I.Resume()
    local up = #M.__registrations()
    assertTrue(up > base, "Resume registered the scan")
    M.__fire("BAG_UPDATE", 0)
    local armed = #M.__timers()
    I.Suspend()
    assertEqual(#M.__registrations(), base, "Suspend left a registration")
    -- red under: Suspend not canceling the debounce handle.
    assertEqual(#M.__timers(), armed - 1, "the pending sync was canceled")
    I.ScheduleSync()
    assertEqual(#M.__timers(), armed - 1, "nothing schedules while suspended")
    I.Resume()
    assertEqual(#M.__registrations(), up, "the same set again")
end)
