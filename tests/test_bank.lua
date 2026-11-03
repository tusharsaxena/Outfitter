-- tests/test_bank.lua — P4.10 (design §5.13, INV §3.7): modules/Bank.lua's deposit, deposit-unique,
-- deposit-others, withdraw and withdraw-others, the selection cleared first, the two full-bags lines,
-- the missing-items report, and the refusals while the bank is closed and in combat.
--
-- Outfits, the Stack, Inventory, Equip, Changes and Moves are the real modules, and the items move
-- for real in tests/mock_gear.lua. The Dock lands later (P4.19): the Stack's window read runs
-- against a recorded fake (design §12, the fake rule).

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BANK_FIRST, BANK_LAST = 6, 11

-- A fresh instance at t = 100 on `scenario` (bank_open by default, its bank frame opened for the
-- Inventory), PlayerState, Inventory and Equip resumed and the first scan settled.
local function scene(scenario, overrides, closed)
    local inst = T.load({ mutate = function(M) M.__gear:load(scenario or "bank_open", overrides) end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Inventory.Resume()
    NS.Equip.Resume()
    if not closed then M.__gear:openBank() end
    M.__fireTimers()
    NS.Inventory.Sync()
    T.fake(NS, "Dock", { IsShown = function() return false end })
    return NS, M, NS.Bank
end

-- The ItemRecord of a fixture item, read from wherever it is now.
local function snap(NS, key, M)
    local inst, loc = M.__gear:find(key)
    assert(inst, "no " .. key)
    local info
    if loc.equip then
        for _, s in ipairs(NS.ItemData.SLOT_NAMES) do
            if NS.Compat.InventorySlotID(s) == loc.equip then info = NS.ItemInfo.FromSlot(s) end
        end
    else
        info = NS.ItemInfo.FromBag(loc.bag, loc.slot)
    end
    return NS.ItemInfo.Snapshot(info)
end

-- Where a fixture item is now: "worn", "bags" or "bank".
local function place(M, key)
    local _, loc = M.__gear:find(key)
    if not loc then return nil end
    if loc.equip then return "worn" end
    if loc.bag >= BANK_FIRST and loc.bag <= BANK_LAST then return "bank" end
    return "bags"
end

local function hear(NS, key)
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG[key], function(_, ...) heard[#heard + 1] = { ... } end)
    return heard
end

-- Whether one printed line holds every needle (the line carries the item's link, not its name).
local function printed(M, ...)
    local needles = { ... }
    for _, line in ipairs(M.__printed()) do
        local all = true
        for _, n in ipairs(needles) do all = all and line:find(n, 1, true) ~= nil end
        if all then return true end
    end
    return false
end

local function moves(M)
    local n = 0
    for _, c in ipairs(M.__equipCalls) do
        if c[1] == "PickupContainerItem" or c[1] == "PickupInventoryItem" then n = n + 1 end
    end
    return n
end

-- ── the surface ───────────────────────────────────────────────────────────────────────────────

test("bank: NS.Bank is published with the §5.13 surface", function()
    local Bank = T.NS.Bank
    assertEqual(type(Bank), "table")
    for _, k in ipairs({ "IsOpen", "Deposit", "DepositOthers", "Withdraw", "WithdrawOthers", "MissingReport" }) do
        assertEqual(type(Bank[k]), "function", k)
    end
end)

test("bank: IsOpen follows the Inventory's bank frame", function()
    local NS, M, Bank = scene()
    assertTrue(Bank.IsOpen())
    M.__gear:closeBank()
    assertFalse(Bank.IsOpen())
    assertTrue(NS ~= nil)
end)

-- ── withdraw ──────────────────────────────────────────────────────────────────────────────────

test("bank: Withdraw brings the outfit's banked items to the bags and leaves the rest", function()
    local NS, M, Bank = scene()
    local O = NS.Outfits
    local id = O.Create("Lower", { LegsSlot = snap(NS, "legs_plate", M), FeetSlot = snap(NS, "feet_plate", M),
                                   HeadSlot = snap(NS, "head_plate", M) })
    local edited = hear(NS, "OUTFIT_EDITED")
    assertTrue(Bank.Withdraw(id))
    assertEqual(place(M, "legs_plate"), "bags")
    assertEqual(place(M, "feet_plate"), "bags")
    -- red under: a withdraw with no bank filter (the worn helm is moved into the bags).
    assertEqual(place(M, "head_plate"), "worn")
    assertEqual(place(M, "trinket_use"), "bank", "an item no outfit names stays")
    assertEqual(edited[#edited][1], id)
    assertEqual(edited[#edited][2], "bank")
end)

test("bank: WithdrawOthers brings every other outfit's banked items and not this one's (INV §3.7 Fix)", function()
    local NS, M, Bank = scene()
    local O = NS.Outfits
    local kept = O.Create("Kept", { LegsSlot = snap(NS, "legs_plate", M) })
    O.Create("Other", { FeetSlot = snap(NS, "feet_plate", M), Trinket0Slot = snap(NS, "trinket_use", M) })
    assertTrue(Bank.WithdrawOthers(kept))
    -- red under: the legacy call (an undefined function: nothing moves).
    assertEqual(place(M, "feet_plate"), "bags")
    assertEqual(place(M, "trinket_use"), "bags")
    assertEqual(place(M, "legs_plate"), "bank")
end)

test("bank: a withdraw into full bags says so with the withdraw line", function()
    local fill = {}
    for i = 1, 16 do fill[i] = "herb_silverleaf" end
    local NS, M, Bank = scene("bank_open", { bags = { [0] = { items = fill } } })
    local id = NS.Outfits.Create("Lower", { LegsSlot = snap(NS, "legs_plate", M) })
    Bank.Withdraw(id)
    assertEqual(place(M, "legs_plate"), "bank")
    -- red under: the default bags-full key (the "Can't remove" line).
    assertTrue(printed(M, "Can't withdraw ", "Legplates of Setup", " because all bags are full"))
end)

-- ── deposit ───────────────────────────────────────────────────────────────────────────────────

test("bank: Deposit puts the outfit's carried and worn items in the bank, clearing the selection first", function()
    local NS, M, Bank = scene()
    local O = NS.Outfits
    local id = O.Create("Top", { HeadSlot = snap(NS, "head_plate", M), Finger0Slot = snap(NS, "ring_plain_a", M),
                                 LegsSlot = snap(NS, "legs_plate", M) })
    NS.Stack.Select(id)
    local selection = hear(NS, "SELECTION_CHANGED")
    assertTrue(Bank.Deposit(id))
    -- red under: a deposit that keeps the selection (the window would record the put-away items).
    assertEqual(#selection, 1)
    assertNil(NS.Stack.Selected())
    assertEqual(place(M, "head_plate"), "bank")
    assertEqual(place(M, "ring_plain_a"), "bank")
    assertEqual(place(M, "legs_plate"), "bank", "already banked, untouched")
    assertEqual(place(M, "chest_plate"), "worn")
end)

test("bank: Deposit unique keeps what another unbanked outfit uses; a partly banked one does not count", function()
    local NS, M, Bank = scene()
    local O = NS.Outfits
    local ring, head = snap(NS, "ring_plain_a", M), snap(NS, "head_plate", M)
    local id = O.Create("Mine", { HeadSlot = head, Finger0Slot = ring })
    O.Create("Ringer", { Finger1Slot = ring })                            -- unbanked; the ring on the other finger
    O.Create("Half", { HeadSlot = head, LegsSlot = snap(NS, "legs_plate", M) })   -- partly banked
    assertTrue(Bank.Deposit(id, true))
    -- red under: a unique deposit that subtracts nothing (the ring goes too).
    assertEqual(place(M, "ring_plain_a"), "bags")
    -- red under: subtracting a partly banked outfit too (the helm stays).
    assertEqual(place(M, "head_plate"), "bank")
end)

test("bank: DepositOthers banks every other outfit's items but this one's", function()
    local NS, M, Bank = scene()
    local O = NS.Outfits
    local head = snap(NS, "head_plate", M)
    local kept = O.Create("Kept", { HeadSlot = head })
    O.Create("Ringer", { Finger0Slot = snap(NS, "ring_plain_a", M) })
    O.Create("Plate", { HeadSlot = head, ChestSlot = snap(NS, "chest_plate", M) })
    NS.Stack.Select(kept)
    assertTrue(Bank.DepositOthers(kept))
    assertNil(NS.Stack.Selected())
    assertEqual(place(M, "ring_plain_a"), "bank")
    assertEqual(place(M, "chest_plate"), "bank")
    -- red under: no claim on the kept outfit's items first (Plate's helm is deposited).
    assertEqual(place(M, "head_plate"), "worn")
end)

test("bank: a deposit into a full bank says so with the deposit line", function()
    local NS, M, Bank = scene("bank_open", { bank = { [6] = { size = 1, items = { [1] = "legs_plate" } } } })
    local id = NS.Outfits.Create("Top", { HeadSlot = snap(NS, "head_plate", M) })
    Bank.Deposit(id)
    assertEqual(place(M, "head_plate"), "worn")
    assertTrue(printed(M, "Can't deposit ", "Helm of the Test Bench", " because all bank bags are full"))
end)

-- ── refusals ──────────────────────────────────────────────────────────────────────────────────

test("bank: every operation is refused while the bank is closed", function()
    local NS, M, Bank = scene("bank_closed", nil, true)
    local id = NS.Outfits.Create("Top", { HeadSlot = snap(NS, "head_plate", M) })
    local before = moves(M)
    for _, op in ipairs({ "Deposit", "DepositOthers", "Withdraw", "WithdrawOthers" }) do
        local ok, why = Bank[op](id)
        assertFalse(ok, op)
        assertEqual(why, NS.L["The bank must be open"], op)
    end
    -- red under: a refusal that only prints (the moves still run).
    assertEqual(moves(M), before)
    assertEqual(place(M, "head_plate"), "worn")
end)

test("bank: every operation is refused in combat", function()
    local NS, M, Bank = scene()
    local id = NS.Outfits.Create("Top", { HeadSlot = snap(NS, "head_plate", M) })
    M.__world:setCombat(true)
    local before = moves(M)
    for _, op in ipairs({ "Deposit", "DepositOthers", "Withdraw", "WithdrawOthers" }) do
        local ok, why = Bank[op](id)
        assertFalse(ok, op)
        assertEqual(why, NS.L["Bank items can't be moved in combat."], op)
    end
    -- red under: no combat refusal.
    assertEqual(moves(M), before)
end)

test("bank: an unknown outfit is refused", function()
    local _, _, Bank = scene()
    assertFalse(Bank.Deposit("o99"))
    assertFalse(Bank.Withdraw("preview:1"))
end)

-- ── the missing-items report ──────────────────────────────────────────────────────────────────

test("bank: MissingReport lists every outfit's missing items after the intro, or says none are missing", function()
    local NS, M, Bank = scene()
    local L = NS.L
    local O = NS.Outfits
    O.Create("Fine", { HeadSlot = snap(NS, "head_plate", M), LegsSlot = snap(NS, "legs_plate", M) })
    local lines = Bank.MissingReport()
    assertEqual(#lines, 1)
    -- red under: a banked item reported as missing.
    assertEqual(lines[1], L["No items are missing"])
    O.Create("Ghost", { HeadSlot = { id = 424242, name = "Ghostly Hood" }, ChestSlot = { id = 0 } })
    lines = Bank.MissingReport()
    assertEqual(#lines, 2)
    assertEqual(lines[1], L["Missing items (an item used by several outfits is listed once per outfit)."])
    assertEqual(lines[2], "Ghostly Hood")
end)

test("bank: MissingReport needs the bank open", function()
    local NS, _, Bank = scene("bank_closed", nil, true)
    local lines, why = Bank.MissingReport()
    -- red under: a report while closed (every banked item would read as missing).
    assertNil(lines)
    assertEqual(why, NS.L["You must have your bank open to generate a missing items report"])
end)
