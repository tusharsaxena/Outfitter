-- tests/test_em_sync.lua — P4.10 (design §5.13, B17, INV §3.5): modules/EquipmentManager.lua, the
-- Equipment Manager mirror: every Blizzard set mirrored as an outfit and removed with it, the
-- case-insensitive name match, zero-sets preservation (Q8) and the restore, the own-save ignore
-- (INV §16 #14), the 31-byte name, 134400 as "no icon", StoreOnServer's and StoreLocally's copy list,
-- the record whole on OUTFIT_ADDED, and the rebuild path's pending save on SWAP_COMPLETE.
--
-- The trigger binder lands beside this task (P4.15) and the Dock later (P4.19): O.Delete's Unbind
-- and the Stack's window read run against recorded fakes (design §12, the fake rule). Outfits, the
-- Stack, Inventory and Equip are the real modules, and the sets are tests/mock_gear_sets.lua's.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local SLOTS = {
    "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "MainHandSlot", "SecondaryHandSlot", "BackSlot", "NeckSlot", "ShirtSlot", "TabardSlot", "Finger0Slot",
    "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
}

-- The settings a store carries between the two kinds (B17), as one record would hold them.
local SETTINGS = {
    trigger = { id = "IN_DUNGEON", combatDisabled = true },
    triggerParams = { IN_DUNGEON = { delay = 2 } },
    triggerState = { IN_DUNGEON = { was = 1 } },
    stat = { { stat = "STA", min = 1 }, complex = true },
    unequipOthers = true, titleID = 5, bar = { hide = true }, ignoreComparisons = true,
}

-- A fresh instance at t = 100 on the em_sets scenario (or another): PlayerState, Inventory and Equip
-- resumed and the first scan settled, the Dock and the binder faked.
local function scene(scenario)
    local inst = T.load({ mutate = function(M) M.__gear:load(scenario or "em_sets") end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Inventory.Resume()
    NS.Equip.Resume()
    M.__fireTimers()
    T.fake(NS, "Dock", { IsShown = function() return false end })
    local binder = T.fake(NS, "TriggerBinder", { Unbind = true })
    return NS, M, NS.EM, binder
end

local function hear(NS, key)
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG[key], function(_, ...) heard[#heard + 1] = { ... } end)
    return heard
end

-- The em records by name, and how many there are.
local function mirrors(NS)
    local out, n = {}, 0
    for id, rec in pairs(NS.db.char.outfits) do
        if rec.kind == "em" then out[rec.name] = id; n = n + 1 end
    end
    return out, n
end

local function calls(M, name)
    local n = 0
    for _, c in ipairs(M.__equipCalls) do if c[1] == name then n = n + 1 end end
    return n
end

local function lastCall(M, name)
    for i = #M.__equipCalls, 1, -1 do
        if M.__equipCalls[i][1] == name then return M.__equipCalls[i] end
    end
    return nil
end

local function printed(M, needle)
    for _, line in ipairs(M.__printed()) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

local function deepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function withSettings(rec)
    for k, v in pairs(SETTINGS) do rec[k] = v end
end

local function assertSettings(rec, what)
    for k, v in pairs(SETTINGS) do
        assertTrue(deepEqual(rec[k], v), what .. " carries " .. k)
        assertTrue(rec[k] ~= v or type(v) ~= "table", what .. "'s " .. k .. " is a copy")
    end
end

-- ── the surface ───────────────────────────────────────────────────────────────────────────────

test("em: NS.EM is published with the §5.13 surface", function()
    local EM = T.NS.EM
    assertEqual(type(EM), "table")
    for _, k in ipairs({ "Sync", "Items", "Missing", "Save", "SetSlotsFromItems", "StoreOnServer", "StoreLocally",
                         "Rename", "Icon", "SetIcon", "DeleteSet", "SetItems", "SetItem", "ClearSlot",
                         "TruncateName", "Suspend", "Resume" }) do
        assertEqual(type(EM[k]), "function", k)
    end
end)

-- ── the mirror ────────────────────────────────────────────────────────────────────────────────

test("em: every set is mirrored as an em outfit, its items resolved from the set's locations", function()
    local NS, M, EM = scene()
    local synced, added = hear(NS, "EM_SYNCED"), hear(NS, "OUTFIT_ADDED")
    assertTrue(EM.Sync())
    local by, n = mirrors(NS)
    assertEqual(n, 2)
    assertEqual(#added, 2)
    assertEqual(#synced, 1)
    local tank, big = NS.Outfits.Get(by.Tank), NS.Outfits.Get(by["Big Sword"])
    assertEqual(tank.setID, M.C_EquipmentSet.GetEquipmentSetID("Tank"))
    local items = NS.Outfits.Items(tank)
    assertEqual(items.HeadSlot.id, NS.ItemInfo.FromSlot("HeadSlot").id, "a worn item resolves from its slot")
    assertEqual(items.NeckSlot.id, 0, "an empty-slot entry is the empty marker")
    assertEqual(tank.category, "Complete")
    local bigItems = NS.Outfits.Items(big)
    assertEqual(bigItems.MainHandSlot.id, NS.ItemInfo.FromBag(0, 1).id, "a carried item resolves from its bag")
    assertEqual(bigItems.SecondaryHandSlot.id, 0)
    -- red under: an ignored slot read as the empty marker (the set would never leave the helm alone).
    assertNil(bigItems.HeadSlot, "an ignored slot is unused")
    assertEqual(big.category, "Accessory")
    assertEqual(big.items.MainHandSlot.id, bigItems.MainHandSlot.id, "the resolved items are the record's snapshot")
end)

test("em: a second sync adopts the same records and adds nothing", function()
    local NS, _, EM = scene()
    EM.Sync()
    local before = mirrors(NS)
    local added = hear(NS, "OUTFIT_ADDED")
    EM.Sync()
    local after, n = mirrors(NS)
    assertEqual(n, 2)
    assertEqual(#added, 0)
    assertEqual(after.Tank, before.Tank)
end)

test("em: a set deleted in the Blizzard UI removes its outfit here, and the set is not deleted again", function()
    local NS, M, EM, binder = scene()
    EM.Sync()
    local by = mirrors(NS)
    local deleted = hear(NS, "OUTFIT_DELETED")
    M.C_EquipmentSet.DeleteEquipmentSet(M.C_EquipmentSet.GetEquipmentSetID("Tank"))
    EM.Sync()
    local after, n = mirrors(NS)
    assertEqual(n, 1)
    assertNil(after.Tank)
    assertNil(NS.Outfits.Get(by.Tank))
    assertEqual(#deleted, 1)
    assertEqual(deleted[1][1], by.Tank)
    assertEqual(binder.__count("Unbind"), 1, "the trigger is unbound")
    -- red under: a prune that deletes the set through EM.DeleteSet (a reused set id would lose a set).
    assertEqual(calls(M, "DeleteEquipmentSet"), 1, "only the client's own delete")
end)

test("em: a set matches its outfit by name case-insensitively and takes its current set id", function()
    local NS, M, EM = scene()
    local id = NS.Outfits.Create("TANK", {}, { kind = "em", setID = 99 })
    local added = hear(NS, "OUTFIT_ADDED")
    EM.Sync()
    local by, n = mirrors(NS)
    assertEqual(n, 2)
    -- red under: an exact-case match (a "Tank" stub is added beside "TANK", which is pruned).
    assertEqual(by.TANK, id)
    assertEqual(#added, 1, "only Big Sword is new")
    assertEqual(NS.Outfits.Get(id).setID, M.C_EquipmentSet.GetEquipmentSetID("Tank"))
end)

test("em: a native outfit of the same name is not taken for the set's mirror", function()
    local NS, _, EM = scene()
    local native = NS.Outfits.Create("Tank", {})
    EM.Sync()
    local by, n = mirrors(NS)
    assertEqual(n, 2)
    assertTrue(by.Tank ~= native)
    assertEqual(NS.Outfits.Get(native).kind, "native")
end)

-- ── zero sets (Q8) ────────────────────────────────────────────────────────────────────────────

test("em: zero sets preserve every em outfit and delete nothing; the sets' return clears the store", function()
    local NS, M, EM = scene()
    EM.Sync()
    local by = mirrors(NS)
    withSettings(NS.Outfits.Get(by.Tank))
    local deleted = hear(NS, "OUTFIT_DELETED")
    M.__emFlake = true
    EM.Sync()
    -- red under: the legacy prune with zero sets (both outfits deleted while the EM flakes).
    assertEqual(#deleted, 0)
    local _, n = mirrors(NS)
    assertEqual(n, 2)
    local kept = NS.db.char.emPreserved
    assertTrue(kept ~= nil and kept.tank ~= nil and kept["big sword"] ~= nil, "preserved by lower-case name")
    assertEqual(kept.tank.trigger.id, "IN_DUNGEON")
    M.__emFlake = false
    EM.Sync()
    local after = mirrors(NS)
    assertEqual(after.Tank, by.Tank, "the outfit came through unchanged")
    assertNil(NS.db.char.emPreserved)
end)

test("em: an outfit lost while the EM flaked is restored from the store, whole on OUTFIT_ADDED", function()
    local NS, M, EM = scene()
    EM.Sync()
    local by = mirrors(NS)
    withSettings(NS.Outfits.Get(by.Tank))
    M.__emFlake = true
    EM.Sync()
    NS.Outfits.Delete(by.Tank)          -- the client cannot delete the set while it flakes
    M.__emFlake = false
    M.__now = 101                       -- past the delete's own-save window
    local seen = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.OUTFIT_ADDED, function(_, id)
        local rec = NS.Outfits.Get(id)
        seen[#seen + 1] = { name = rec.name, trigger = rec.trigger and rec.trigger.id,
                            params = rec.triggerParams and rec.triggerParams.IN_DUNGEON }
    end)
    EM.Sync()
    local after = mirrors(NS)
    assertTrue(after.Tank ~= nil and after.Tank ~= by.Tank, "a new record")
    -- red under: a restore that writes the settings after Create (the binder would bind no trigger).
    assertEqual(#seen, 1)
    assertEqual(seen[1].trigger, "IN_DUNGEON")
    assertEqual(seen[1].params.delay, 2)
    local rec = NS.Outfits.Get(after.Tank)
    assertSettings(rec, "the restored outfit")
    assertEqual(rec.setID, M.C_EquipmentSet.GetEquipmentSetID("Tank"))
    assertNil(NS.db.char.emPreserved)
end)

-- ── own saves (INV §16 #14, O18) ──────────────────────────────────────────────────────────────

test("em: the addon's own save is not synced back, inside the save or for 0.5 s after it", function()
    local NS, M, EM = scene()
    EM.Sync()
    EM.Resume()
    local by = mirrors(NS)
    local synced = hear(NS, "EM_SYNCED")
    local save = M.C_EquipmentSet.SaveEquipmentSet
    M.C_EquipmentSet.SaveEquipmentSet = function(...)
        save(...)
        M.__fire("EQUIPMENT_SETS_CHANGED")   -- a client that fires inside the call
    end
    M.__now = 200
    assertTrue(EM.Save(NS.Outfits.Get(by.Tank)))
    -- red under: no saving counter (the synchronous event syncs).
    assertEqual(#synced, 0)
    M.__gear:deliver()
    -- red under: no ignore window (the queued event syncs).
    assertEqual(#synced, 0)
    M.__now = 200.6
    M.__fire("EQUIPMENT_SETS_CHANGED")
    assertEqual(#synced, 1, "a later change syncs")
end)

test("em: a save that raises still balances the saving counter", function()
    local NS, M, EM = scene()
    EM.Sync()
    local by = mirrors(NS)
    M.C_EquipmentSet.SaveEquipmentSet = function() error("boom") end
    local ok = pcall(EM.Save, NS.Outfits.Get(by.Tank))
    assertFalse(ok, "the raise reaches the caller")
    assertEqual(EM.__state.saving, 0)
    M.__now = 300
    -- red under: a counter left raised (every later sync is refused).
    assertTrue(EM.Sync())
end)

-- ── names and icons ───────────────────────────────────────────────────────────────────────────

test("em: a name is cut to 31 bytes on a UTF-8 boundary", function()
    local EM = T.NS.EM
    assertEqual(EM.TruncateName("short"), "short")
    assertEqual(EM.TruncateName(("a"):rep(40)), ("a"):rep(31))
    -- red under: a plain byte cut (half of the "é" is left at the end).
    assertEqual(EM.TruncateName(("a"):rep(30) .. "\195\169bc"), ("a"):rep(30))
    assertEqual(EM.TruncateName(("a"):rep(29) .. "\195\169bc"), ("a"):rep(29) .. "\195\169")
    assertEqual(EM.TruncateName(("a"):rep(29) .. "\226\130\172z"), ("a"):rep(29), "a 3-byte character that does not fit")
end)

test("em: icon 134400 reads as no icon, and no icon writes 134400", function()
    local NS, M, EM = scene()
    EM.Sync()
    local by = mirrors(NS)
    local tank = NS.Outfits.Get(by.Tank)
    assertEqual(EM.Icon(tank), 132341)
    EM.SetIcon(tank, nil)
    assertEqual(lastCall(M, "ModifyEquipmentSet")[4], 134400)
    -- red under: the wildcard read back as an icon.
    assertNil(EM.Icon(tank))
    EM.SetIcon(tank, 135349)
    assertEqual(EM.Icon(tank), 135349)
end)

test("em: a rename renames the set, keeps its icon, and refuses a name the EM cannot hold", function()
    local NS, M, EM = scene()
    EM.Sync()
    local by = mirrors(NS)
    assertTrue(NS.Outfits.Rename(by.Tank, "Shield Wall"))
    local call = lastCall(M, "ModifyEquipmentSet")
    assertEqual(call[3], "Shield Wall")
    assertEqual(call[4], 132341)
    local ok, err = NS.Outfits.Rename(by.Tank, ("x"):rep(32))
    -- red under: a rename that lets the set and the record names drift apart.
    assertFalse(ok)
    assertEqual(err, NS.L["That name is too long for the Equipment Manager"])
    assertEqual(NS.Outfits.Get(by.Tank).name, "Shield Wall")
    local _, n = mirrors(NS)
    M.__now = 400
    EM.Sync()
    local after, n2 = mirrors(NS)
    assertEqual(n2, n)
    assertEqual(after["Shield Wall"], by.Tank, "the renamed set still matches its outfit")
end)

-- ── slots ─────────────────────────────────────────────────────────────────────────────────────

test("em: enabling a slot saves it into the set; clearing one ignores it", function()
    local NS, M, EM = scene()
    EM.Sync()
    local by = mirrors(NS)
    local id = by["Big Sword"]
    NS.Outfits.SetSlotEnabled(id, "HeadSlot", true)
    assertEqual(lastCall(M, "SaveEquipmentSet")[2], NS.Outfits.Get(id).setID)
    local items = NS.Outfits.Items(NS.Outfits.Get(id))
    assertEqual(items.HeadSlot.id, NS.ItemInfo.FromSlot("HeadSlot").id)
    assertTrue(items.MainHandSlot ~= nil, "the other slots stay enabled")
    NS.Outfits.ClearSlot(id, "ChestSlot")
    items = NS.Outfits.Items(NS.Outfits.Get(id))
    -- red under: a clear that saves without ignoring the slot.
    assertNil(items.ChestSlot)
    assertTrue(items.HeadSlot ~= nil)
end)

test("em: SetSlotsFromItems ignores exactly the slots the items leave out", function()
    local NS, M, EM = scene()
    EM.SetSlotsFromItems({ HeadSlot = { id = 1 }, ChestSlot = { id = 0 } })
    local ignored = {}
    for _, c in ipairs(M.__equipCalls) do
        if c[1] == "IgnoreSlotForSave" then ignored[c[2]] = true end
    end
    local n = 0
    for _ in pairs(ignored) do n = n + 1 end
    assertEqual(n, #SLOTS - 2)
    assertNil(ignored[NS.Compat.InventorySlotID("HeadSlot")])
    assertNil(ignored[NS.Compat.InventorySlotID("ChestSlot")], "an empty marker is a used slot")
    assertEqual(calls(M, "ClearIgnoredSlotsForSave"), 1)
end)

test("em: Missing reads the set's locations: a gone item is missing, a bank-tab one is banked", function()
    local NS, M, EM = scene("bank_open")
    M.__gear:openBank()
    M.__gear:addSet({ name = "Banked", items = { LegsSlot = "legs_plate", HeadSlot = "head_plate" } })
    EM.Sync()
    local by = mirrors(NS)
    local rec = NS.Outfits.Get(by.Banked)
    local items = EM.Items(rec)
    assertEqual(items.LegsSlot.id, 212009, "a bank-tab item resolves from the tab")
    local missing, banked = EM.Missing(rec)
    -- red under: the location's BAGS bit taken at its word (the bank tab read as a carried bag).
    assertEqual(#banked, 1)
    assertEqual(banked[1].id, 212009)
    assertEqual(#missing, 0)
    local legs = M.__gear:find("legs_plate")
    M.__gear.bags[M.__gear:where(legs).bag].slots[M.__gear:where(legs).slot] = nil   -- the item is gone
    missing = EM.Missing(rec)
    assertEqual(#missing, 1)
    assertEqual(missing[1].id, 212009, "a gone item keeps its last snapshot")
end)

-- ── store on server, store locally (B17) ─────────────────────────────────────────────────────

test("em: StoreOnServer makes the set from the outfit's slots and carries every setting (B17)", function()
    local NS, M, EM = scene()
    EM.Sync()
    local O = NS.Outfits
    local head = NS.ItemInfo.Snapshot(NS.ItemInfo.FromSlot("HeadSlot"))
    local id = O.Create(("Raid Gear "):rep(4), { HeadSlot = head, NeckSlot = { id = 0 } }, { icon = 135349 })
    withSettings(O.Get(id))
    O.SetBinding(id, 3)
    local seen = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.OUTFIT_ADDED, function(_, newId)
        local rec = O.Get(newId)
        seen[#seen + 1] = rec.trigger and rec.trigger.id
    end)
    local ok, popup, newId = EM.StoreOnServer(id)
    assertTrue(ok)
    assertNil(popup)
    local name = EM.TruncateName(("Raid Gear "):rep(4))
    assertEqual(lastCall(M, "CreateEquipmentSet")[2], name)
    assertEqual(lastCall(M, "CreateEquipmentSet")[3], 135349)
    local rec = O.Get(newId)
    assertEqual(rec.kind, "em")
    assertEqual(rec.name, name)
    assertEqual(rec.setID, M.C_EquipmentSet.GetEquipmentSetID(name))
    -- red under: the legacy copy (Script and StatID only; B17 dropped the params and UnequipOthers).
    assertSettings(rec, "the stored outfit")
    assertEqual(seen[1], "IN_DUNGEON", "whole on OUTFIT_ADDED")
    assertEqual(O.BindingOf(newId), 3, "the binding moved")
    assertNil(O.Get(id), "the native outfit is gone")
    local items = O.Items(rec)
    assertEqual(items.HeadSlot.id, head.id)
    assertEqual(items.NeckSlot.id, 0)
    assertNil(items.ChestSlot, "a slot the outfit left out is ignored in the set")
    assertTrue(NS.Stack.IsWorn(newId))
    assertEqual(NS.Stack.Selected(), newId)
end)

test("em: StoreOnServer at the cap answers the EM-full popup and changes nothing", function()
    local NS, M, EM = scene()
    M.MAX_EQUIPMENT_SETS_PER_PLAYER = 2
    local id = NS.Outfits.Create("Spare", { HeadSlot = { id = 0 } })
    local ok, popup = EM.StoreOnServer(id)
    assertFalse(ok)
    assertEqual(popup, "OUTFITTERREBORN_EM_FULL")
    -- red under: the cap read after the create.
    assertEqual(calls(M, "CreateEquipmentSet"), 0)
    assertEqual(NS.Outfits.Get(id).kind, "native")
end)

test("em: StoreLocally clones the set into a native outfit with the same copy list", function()
    local NS, M, EM = scene()
    EM.Sync()
    local O = NS.Outfits
    local by = mirrors(NS)
    withSettings(O.Get(by.Tank))
    O.SetBinding(by.Tank, 4)
    local resolved = O.Items(O.Get(by.Tank))
    local seen = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.OUTFIT_ADDED, function(_, newId)
        seen[#seen + 1] = O.Get(newId).trigger.id
    end)
    local newId = EM.StoreLocally(by.Tank)
    local rec = O.Get(newId)
    assertEqual(rec.kind, "native")
    assertEqual(rec.name, "Tank")
    assertEqual(rec.icon, 132341)
    assertSettings(rec, "the local outfit")
    assertEqual(seen[1], "IN_DUNGEON")
    assertTrue(deepEqual(rec.items, resolved), "the set's resolved items")
    assertEqual(O.BindingOf(newId), 4)
    assertNil(O.Get(by.Tank))
    assertTrue(NS.Stack.IsWorn(newId))
    M.__now = 500
    EM.Sync()
    local after, n = mirrors(NS)
    -- red under: the set kept (the next sync mirrors a second "Tank" beside the local one).
    assertNil(after.Tank)
    assertEqual(n, 1)
end)

-- ── the rebuild path ──────────────────────────────────────────────────────────────────────────

test("em: SetItems wears the items and saves them on SWAP_COMPLETE", function()
    local NS, M, EM = scene()
    EM.Sync()
    local by = mirrors(NS)
    local rec = NS.Outfits.Get(by["Big Sword"])
    local want = { HeadSlot = NS.ItemInfo.Snapshot(NS.ItemInfo.FromSlot("HeadSlot")), ChestSlot = { id = 0 } }
    local saves = calls(M, "SaveEquipmentSet")
    EM.SetItems(rec, want)
    assertTrue(deepEqual(EM.Items(rec), want), "the pending items read as the outfit's")
    assertTrue(NS.Stack.IsWorn(rec.id), "worn")
    assertEqual(EM.__state.timer.delay, 10)
    NS.SendBus(NS.MSG.SWAP_COMPLETE)
    -- red under: no save on SWAP_COMPLETE.
    assertEqual(calls(M, "SaveEquipmentSet"), saves + 1)
    assertTrue(printed(M, "Saved outfit to Equipment Manager"))
    assertNil(EM.__state.pending)
    local items = EM.Items(rec)
    assertTrue(items.HeadSlot ~= nil and items.ChestSlot ~= nil)
    assertNil(items.MainHandSlot, "the slots come from the items")
    NS.SendBus(NS.MSG.SWAP_COMPLETE)
    assertEqual(calls(M, "SaveEquipmentSet"), saves + 1, "one save per rebuild")
end)

test("em: a pending save is dropped after 10 s, by a stand-down, and by a slot edit", function()
    local NS, M, EM = scene()
    EM.Sync()
    local by = mirrors(NS)
    local rec = NS.Outfits.Get(by["Big Sword"])
    local saves = calls(M, "SaveEquipmentSet")
    EM.SetItems(rec, { HeadSlot = { id = 0 } })
    EM.__state.timer.callback()
    -- red under: no 10 s cancel (a much later swap saves the abandoned rebuild).
    assertNil(EM.__state.pending)
    NS.SendBus(NS.MSG.SWAP_COMPLETE)
    assertEqual(calls(M, "SaveEquipmentSet"), saves)
    EM.SetItems(rec, { HeadSlot = { id = 0 } })
    EM.Suspend()
    assertNil(EM.__state.pending)
    assertEqual(EM.__state.saving, 0)
    EM.SetItems(rec, { HeadSlot = { id = 0 } })
    NS.Outfits.ClearSlot(rec.id, "ChestSlot")
    assertNil(EM.__state.pending)
end)

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

test("em: Resume registers EQUIPMENT_SETS_CHANGED; Suspend lets it go", function()
    local NS, M, EM = scene()
    local synced = hear(NS, "EM_SYNCED")
    EM.Resume()
    M.__fire("EQUIPMENT_SETS_CHANGED")
    assertEqual(#synced, 1)
    EM.Suspend()
    M.__fire("EQUIPMENT_SETS_CHANGED")
    -- red under: a Suspend that keeps the registration.
    assertEqual(#synced, 1)
end)
