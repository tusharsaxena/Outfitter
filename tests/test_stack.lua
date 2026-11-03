-- tests/test_stack.lua — P4.9 (design §5.8, §5.9, §3.4, B6): modules/OutfitStack.lua's wear, remove,
-- toggle, layers, recents, selection and title, and modules/OutfitStack_Watch.lua's temporary outfit,
-- window-open recording and SWAP_COMPLETE.
--
-- NS.Dock lands in P4.19: the window-open reads (Wear's selection rule, the Watch's recording) run
-- against a recorded fake (design §12, the fake rule). Outfits, Inventory, Equip, Changes and Moves are
-- the real modules, and the items move for real in tests/mock_gear.lua.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local SLOTS = {
    "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "MainHandSlot", "SecondaryHandSlot", "BackSlot", "NeckSlot", "ShirtSlot", "TabardSlot", "Finger0Slot",
    "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
}

-- A fresh instance at t = 100: the gear scenario loaded, PlayerState, Inventory and Equip resumed and
-- the first scan settled, the window (the Dock fake) closed unless `ctl.shown` is set.
local function scene(scenario)
    local inst = T.load({ mutate = function(M) M.__gear:load(scenario or "geared") end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Inventory.Resume()
    NS.Equip.Resume()
    M.__fireTimers()
    local ctl = { shown = false }
    T.fake(NS, "Dock", { IsShown = function() return ctl.shown end })
    return NS, M, NS.Stack, ctl
end

local function snap(NS, info) return NS.ItemInfo.Snapshot(info) end

-- Every worn slot as an outfit would store it (the empty marker for an empty slot): a Complete outfit.
local function wornItems(NS)
    local items = {}
    for _, s in ipairs(SLOTS) do
        local info = NS.ItemInfo.FromSlot(s)
        items[s] = info and snap(NS, info) or { id = 0 }
    end
    return items
end

local function naked()
    local items = {}
    for _, s in ipairs(SLOTS) do items[s] = { id = 0 } end
    return items
end

-- Three outfits on the geared scenario: Normal (Complete, the worn gear), Naked (Complete) and two
-- Accessory outfits that touch the head and the chest.
local function outfits(NS)
    local O = NS.Outfits
    return {
        normal = O.Create("Normal", wornItems(NS)),
        naked  = O.Create("Naked", naked()),
        hat    = O.Create("Hat", { HeadSlot = { id = 0 } }),
        hero   = O.Create("Hero", { ChestSlot = snap(NS, NS.ItemInfo.FromBag(0, 5)) }),
    }
end

local function hear(NS, key)
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG[key], function(_, ...) heard[#heard + 1] = { ... } end)
    return heard
end

-- The stack as "id/layer" (a temp entry reads "temp:<slots>"), bottom to top.
local function shape(NS)
    local out = {}
    for _, e in ipairs(NS.db.char.stack) do
        if e.temp then
            local slots = {}
            for s in pairs(e.temp) do slots[#slots + 1] = s end
            table.sort(slots)
            out[#out + 1] = "temp:" .. table.concat(slots, "+")
        else
            out[#out + 1] = e.id .. (e.layer and ("/" .. e.layer) or "")
        end
    end
    return table.concat(out, ",")
end

local function printed(M, needle)
    for _, line in ipairs(M.__printed()) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

-- ── the surface ───────────────────────────────────────────────────────────────────────────────

test("stack: NS.Stack is published with the §5.8 surface and the Watch's reader", function()
    local St = T.NS.Stack
    assertEqual(type(St), "table")
    for _, k in ipairs({ "Wear", "Remove", "Toggle", "WearBound", "IsWorn", "Top", "CurrentComplete",
                         "CurrentInfo", "CurrentLabel", "TagLayer", "Compile", "Layered", "Expected",
                         "SetExpected", "Select", "Selected", "UpdateTitle", "DidEquip", "DidUnequip",
                         "Clear", "Init", "Suspend", "Resume", "OnInventoryChanged" }) do
        assertEqual(type(St[k]), "function", k)
    end
end)

-- ── wear ──────────────────────────────────────────────────────────────────────────────────────

test("stack: a Complete wear clears the stack, moves to the end of the recents and announces", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    local worn, removed, changed = hear(NS, "OUTFIT_WORN"), hear(NS, "OUTFIT_REMOVED"), hear(NS, "STACK_CHANGED")
    assertTrue(St.Wear(o.normal))
    St.Wear(o.hat, { layer = "zone", byTrigger = true })
    assertEqual(shape(NS), o.normal .. "," .. o.hat .. "/zone")
    assertEqual(worn[2][1], o.hat); assertEqual(worn[2][2], "zone"); assertEqual(worn[2][3], true)
    St.Wear(o.naked)
    -- red under: a Complete wear that skips the clear (the hat stays layered over Naked).
    assertEqual(shape(NS), o.naked)
    assertEqual(#removed, 2, "each cleared entry announced OUTFIT_REMOVED")
    assertEqual(table.concat(NS.db.char.recent, ","), o.normal .. "," .. o.naked)
    St.Wear(o.normal)
    assertEqual(table.concat(NS.db.char.recent, ","), o.naked .. "," .. o.normal, "a re-wear moves to the end")
    assertTrue(#changed >= 4, "every wear's Batch closed with STACK_CHANGED")
    assertFalse(St.Wear("o99"), "an unknown id wears nothing")
    assertFalse(St.Wear("preview:1"), "nor does a preview placeholder (C28)")
end)

test("stack: unequipOthers clears the Accessory entries and leaves the Complete one and the temps", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    St.Wear(o.normal); St.Wear(o.hat)
    table.insert(NS.db.char.stack, { temp = { WristSlot = { id = 0 } } })
    NS.Outfits.SetFlag(o.hero, "unequipOthers", true)
    St.Wear(o.hero)
    -- red under: a wear that ignores unequipOthers (the hat stays).
    assertEqual(shape(NS), o.normal .. ",temp:WristSlot," .. o.hero)
end)

test("stack: a layered wear goes under the lowest entry of its layer, else on top; an untagged one on top", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    local O = NS.Outfits
    local cloak = O.Create("Cloak", { BackSlot = { id = 0 } })
    St.Wear(o.normal)
    St.Wear(o.hat, { layer = "zone" })
    St.Wear(o.hero)
    assertEqual(shape(NS), o.normal .. "," .. o.hat .. "/zone," .. o.hero)
    St.Wear(cloak, { layer = "zone" })
    -- red under: an insertIndexFor that always answers the top.
    assertEqual(shape(NS), o.normal .. "," .. cloak .. "/zone," .. o.hat .. "/zone," .. o.hero)
    assertEqual(St.Top(), o.hero)
end)

test("stack: re-wearing a lower entry removes it first, collapses the temps it parted, then pushes it", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    St.Wear(o.normal)
    local c = NS.db.char
    c.stack[#c.stack + 1] = { temp = { WristSlot = { id = 0 }, HandsSlot = { id = 0 } } }
    St.Wear(o.hat)
    c.stack[#c.stack + 1] = { temp = { HandsSlot = { id = 7 } } }
    local removed = hear(NS, "OUTFIT_REMOVED")
    St.Wear(o.hat)
    assertEqual(shape(NS), o.normal .. ",temp:HandsSlot+WristSlot," .. o.hat)
    assertEqual(#removed, 1); assertEqual(removed[1][1], o.hat)
    -- The upper temp wins a slot both hold (OutfitterEquipment.lua:1215-1250).
    assertEqual(c.stack[2].temp.HandsSlot.id, 7)
    local before = #removed
    St.Wear(o.hat)
    -- red under: a pushEntry that removes and re-pushes the topmost entry.
    assertEqual(#removed, before, "wearing the topmost entry again changes nothing")
end)

test("stack: B6, the layer point is derived, so a temp collapse can never leave it stale", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    local cloak = NS.Outfits.Create("Cloak", { BackSlot = { id = 0 } })
    local c = NS.db.char
    St.Wear(o.normal)
    c.stack[#c.stack + 1] = { temp = { WristSlot = { id = 0 } } }
    St.Wear(o.hero)
    c.stack[#c.stack + 1] = { temp = { HandsSlot = { id = 0 } } }
    St.Wear(o.hat, { layer = "zone" })
    St.Wear(o.hero)       -- out from between the temps: they collapse into one
    assertEqual(shape(NS), o.normal .. ",temp:HandsSlot+WristSlot," .. o.hat .. "/zone," .. o.hero)
    St.Wear(cloak, { layer = "zone" })
    -- red under: an insert point one above the layer's lowest entry (where the legacy collapse left it).
    assertEqual(shape(NS), o.normal .. ",temp:HandsSlot+WristSlot," .. cloak .. "/zone," .. o.hat .. "/zone," .. o.hero)
end)

test("stack: O39, once a layer's last entry goes, the next wear of that layer goes on top", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    local cloak = NS.Outfits.Create("Cloak", { BackSlot = { id = 0 } })
    St.Wear(o.normal)
    St.Wear(o.hat, { layer = "zone" })
    St.Wear(o.hero)
    St.Remove(o.hat)
    St.Wear(cloak, { layer = "zone" })
    assertEqual(shape(NS), o.normal .. "," .. o.hero .. "," .. cloak .. "/zone")
    St.TagLayer(o.hero, "zone")
    assertEqual(shape(NS), o.normal .. "," .. o.hero .. "/zone," .. cloak .. "/zone")
end)

-- ── remove and toggle ─────────────────────────────────────────────────────────────────────────

test("stack: Remove of an id not on the stack is a quiet no-op (O.Delete calls it unconditionally)", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    local removed, changed = hear(NS, "OUTFIT_REMOVED"), hear(NS, "STACK_CHANGED")
    -- red under: a Remove that opens its Batch before the lookup (STACK_CHANGED for nothing).
    assertFalse(St.Remove(o.hat))
    assertFalse(St.Remove("o99"))
    assertEqual(#removed, 0); assertEqual(#changed, 0)
end)

test("stack: removing a Complete outfit puts it first in the recents and wears the newest that still exists", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    local c = NS.db.char
    St.Wear(o.naked); St.Wear(o.normal)
    -- Newest last: a stale id and an Accessory id sit above Naked, and both are pruned on the walk.
    c.recent = { o.naked, o.hat, "o99" }
    c.recent[#c.recent + 1] = o.normal
    local removed = hear(NS, "OUTFIT_REMOVED")
    assertTrue(St.Remove(o.normal, { byTrigger = true }))
    assertEqual(removed[1][1], o.normal); assertEqual(removed[1][2], true)
    -- red under: the walk-back from the oldest recent (Normal, moved to the front, would be re-worn).
    assertEqual(shape(NS), o.naked)
    assertEqual(table.concat(c.recent, ","), o.normal .. "," .. o.naked)
    assertTrue(St.DidUnequip(o.normal)); assertFalse(St.DidEquip(o.normal))
end)

test("stack: the fallback walk is bounded, prunes as it goes, and a deleted outfit's entry reads as none", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    local c = NS.db.char
    St.Wear(o.normal)
    c.recent = { "o97", "o98", o.hat, "o96", o.normal }
    St.Remove(o.normal)
    -- Normal went to the front, so the walk prunes everything above it and re-wears it (as today).
    assertEqual(table.concat(c.recent, ","), o.normal)
    assertEqual(shape(NS), o.normal)
    -- O.Delete calls Remove while the record still exists: the walk re-wears it, then the store drops it.
    -- The trigger binder lands in P4.15 (the fake rule).
    local binder = T.fake(NS, "TriggerBinder", { Unbind = true })
    NS.Outfits.Delete(o.normal)
    assertEqual(binder.__count("Unbind"), 1)
    local name, id = St.CurrentInfo()
    assertEqual(name, ""); assertNil(id)
    -- red under: a Compile that reads O.Items of a stale entry (it raises on the nil record).
    assertEqual(St.Compile().FeetSlot.id, NS.ItemInfo.FromSlot("FeetSlot").id)
    assertNil(St.CurrentComplete())
end)

test("stack: Toggle removes a worn Accessory, wears an unworn one, and always re-wears a Complete one", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    St.Wear(o.normal)
    assertTrue(St.Toggle(o.hat)); assertTrue(St.IsWorn(o.hat))
    assertFalse(St.Toggle(o.hat)); assertFalse(St.IsWorn(o.hat))
    St.Wear(o.hat)
    -- red under: a Toggle that removes a worn Complete outfit.
    assertTrue(St.Toggle(o.normal), "a Complete outfit is re-worn")
    assertEqual(shape(NS), o.normal)
end)

test("stack: Clear announces every named entry, and the reads answer from the stack", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    St.Wear(o.normal); St.Wear(o.hat)
    NS.db.char.stack[#NS.db.char.stack + 1] = { temp = { WristSlot = { id = 0 } } }
    assertEqual(St.CurrentComplete(), o.normal)
    assertNil(St.Top(), "a temp on top has no id")
    local removed = hear(NS, "OUTFIT_REMOVED")
    St.Clear()
    assertEqual(#removed, 2)
    assertEqual(shape(NS), "")
    assertNil(St.CurrentComplete())
end)

-- ── the reads: CurrentInfo, Compile ───────────────────────────────────────────────────────────

test("stack: CurrentInfo answers \"\" for an empty stack, the name on top, Custom for a temp on top", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    local name, id = St.CurrentInfo()
    assertEqual(name, ""); assertNil(id)
    assertEqual(St.CurrentLabel(), "None")
    St.Wear(o.normal)
    name, id = St.CurrentInfo()
    assertEqual(name, "Normal"); assertEqual(id, o.normal)
    assertEqual(St.CurrentLabel(), "Normal")
    NS.db.char.stack[#NS.db.char.stack + 1] = { temp = { WristSlot = { id = 0 } } }
    name, id = St.CurrentInfo()
    assertEqual(name, "Custom"); assertNil(id)
end)

test("stack: Compile layers the worn gear, then each entry bottom to top; Layered leaves the worn gear out", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    St.Wear(o.normal); St.Wear(o.hero); St.Wear(o.hat)
    local items = St.Compile()
    assertEqual(items.HeadSlot.id, 0, "the hat empties the head")
    assertEqual(items.ChestSlot.id, NS.ItemInfo.FromBag(0, 5).id, "the hero chest over Normal's")
    assertEqual(items.FeetSlot.id, NS.ItemInfo.FromSlot("FeetSlot").id)
    local without = St.Compile(o.hat)
    assertTrue(without.HeadSlot.id ~= 0, "Compile(excludeId) skips that entry")
    St.Clear(); St.Wear(o.hat)
    local layered = St.Layered()
    assertEqual(layered.HeadSlot.id, 0)
    assertNil(layered.FeetSlot, "no worn base under Layered")
    assertTrue(St.Compile().FeetSlot ~= nil)
end)

test("stack: Compile empties the off-hand under a two-hander, unless Titan's Grip holds it", function()
    local NS, _, St = scene("geared")
    local gs = NS.Outfits.Create("Big", { MainHandSlot = snap(NS, NS.ItemInfo.FromBag(0, 1)) })
    St.Wear(gs)
    -- red under: Compile without AdjustOffhandSlot (the shield stays in the compiled off-hand).
    assertEqual(St.Compile().SecondaryHandSlot.id, 0)
    local NS2, _, St2 = scene("tg_warrior")
    St2.Init()
    assertTrue(St2.Compile().SecondaryHandSlot.id ~= 0, "a Fury warrior keeps the second two-hander")
    assertTrue(NS2 ~= nil)
end)

-- ── the title, clearDisabled, the selection ──────────────────────────────────────────────────

test("stack: a hardware wear or remove sets the highest stacked title; a trigger's never does", function()
    local NS, M, St = scene()
    local o = outfits(NS)
    local O = NS.Outfits
    O.SetFlag(o.normal, "titleID", 1)
    O.SetFlag(o.hat, "titleID", 3)
    St.Wear(o.normal, { hw = true })
    assertEqual(table.concat(M.__world.titleCalls or {}, ","), "1")
    St.Wear(o.hat, { byTrigger = true })
    -- red under: a wearBody that updates the title on every wear.
    assertEqual(table.concat(M.__world.titleCalls or {}, ","), "1", "a trigger wear leaves the title")
    St.Wear(o.hero, { hw = true })
    assertEqual(table.concat(M.__world.titleCalls, ","), "1,3", "the highest stacked title")
    St.Remove(o.hat)
    assertEqual(#M.__world.titleCalls, 2, "a remove with no hardware event leaves it")
    St.Remove(o.hero, { hw = true })
    assertEqual(table.concat(M.__world.titleCalls, ","), "1,3,1")
    St.UpdateTitle(false)
    assertEqual(#M.__world.titleCalls, 3, "UpdateTitle without hw does nothing")
end)

test("stack: clearDisabled re-enables the trigger through NS.SetByPath, so the binder hears OUTFIT_EDITED", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    local rec = NS.Outfits.Get(o.hat)
    rec.trigger = { id = "FISHING", disabled = true }
    local edited = hear(NS, "OUTFIT_EDITED")
    St.Wear(o.hat)
    assertTrue(rec.trigger.disabled, "a plain wear leaves the flag")
    St.Remove(o.hat)
    St.Wear(o.hat, { clearDisabled = true })
    -- red under: a wearBody that skips step 1.
    assertFalse(rec.trigger.disabled == true)
    assertEqual(#edited, 1); assertEqual(edited[1][1], o.hat); assertEqual(edited[1][2], "trigger")
end)

test("stack: with the window open a wear selects the topmost outfit, else clears the selection", function()
    local NS, _, St, ctl = scene()
    local o = outfits(NS)
    local sel = hear(NS, "SELECTION_CHANGED")
    St.Wear(o.normal)
    assertNil(St.Selected(), "the window is closed")
    ctl.shown = true
    St.Wear(o.hat, { layer = "zone" })
    assertEqual(St.Selected(), o.hat)
    St.Wear(o.hero)
    assertEqual(St.Selected(), o.hero)
    local cloak = NS.Outfits.Create("Cloak", { BackSlot = { id = 0 } })
    St.Wear(cloak, { layer = "zone" })   -- under the hat: not topmost
    -- red under: a followSelection that selects whatever was worn.
    assertNil(St.Selected())
    assertEqual(#sel, 3); assertEqual(sel[1][1], o.hat); assertEqual(sel[2][1], o.hero); assertNil(sel[3][1])
    St.Select(o.hero)
    St.Remove(o.hero)
    assertNil(St.Selected(), "removing the selected outfit clears the selection")
    St.Select("o99")
    assertNil(St.Selected(), "an unknown id selects nothing")
end)

-- ── the key bindings ─────────────────────────────────────────────────────────────────────────

test("stack: WearBound wears a Complete outfit now, toggles anything else, and ignores a panic repeat", function()
    local NS, M, St = scene()
    local o = outfits(NS)
    local O = NS.Outfits
    O.SetBinding(o.normal, 1); O.SetBinding(o.hat, 2)
    NS.Outfits.Get(o.hat).trigger = { id = "FISHING", disabled = true }
    local worn, rec = St.WearBound(1)
    assertTrue(worn); assertEqual(rec.id, o.normal)
    assertEqual(NS.Equip.Pending(), false, "a Complete key wear updates now")
    worn = St.WearBound(2)
    assertTrue(worn); assertTrue(St.IsWorn(o.hat))
    assertFalse(NS.Outfits.Get(o.hat).trigger.disabled == true, "the key clears Disabled")
    M.__now = 100.5
    local again, _, ignored = St.WearBound(2)
    -- red under: no anti-panic window (the second press toggles the hat off).
    assertNil(again); assertTrue(ignored); assertTrue(St.IsWorn(o.hat))
    M.__now = 101.0   -- 0.5 s after the ignored press: the window refreshed on it
    assertNil((St.WearBound(2)))
    M.__now = 102
    assertFalse((St.WearBound(2)), "a press after the window toggles off")
    assertNil((St.WearBound(5)), "an unbound key answers nil")
end)

-- ── the watch: temps, recording, SWAP_COMPLETE ───────────────────────────────────────────────

-- Normal on the stack and the Watch live: the state a login's LoadPass and resume leave.
local function watching(scenario)
    local NS, M, St, ctl = scene(scenario)
    local o = outfits(NS)
    NS.db.char.stack = { { id = o.normal } }
    St.Init()
    St.Resume()
    return NS, M, St, ctl, o
end

test("stack: a hand swap becomes a temp on top, a second one merges in, and swapping back prunes it", function()
    local NS, M, St, _, o = watching()
    M.C_Container.UseContainerItem(0, 5)   -- the hero chest on, by hand
    NS.Inventory.Sync()
    assertEqual(shape(NS), o.normal .. ",temp:ChestSlot")
    assertEqual(St.CurrentInfo(), "Custom")
    assertEqual(St.Expected().ChestSlot.id, NS.ItemInfo.FromSlot("ChestSlot").id, "expected follows the swap")
    M.C_Container.UseContainerItem(0, 1)   -- the greatsword
    NS.Inventory.Sync()
    assertEqual(shape(NS), o.normal .. ",temp:ChestSlot+MainHandSlot+SecondaryHandSlot", "one temp, merged")
    local bag = M.__gear:find("chest_plate")
    assertTrue(bag ~= nil)
    M.C_Container.UseContainerItem(0, 5)   -- the plate chest back
    NS.Inventory.Sync()
    -- red under: an updateTemp that never subtracts what the stack below already expects.
    assertEqual(shape(NS), o.normal .. ",temp:MainHandSlot+SecondaryHandSlot")
end)

test("stack: a hand swap with the window open records into the selected outfit and says so", function()
    local NS, M, St, ctl, o = watching()
    local O = NS.Outfits
    local plate = NS.ItemInfo.FromSlot("ChestSlot")
    local rec = O.Get(O.Create("Gear", { ChestSlot = snap(NS, plate), FeetSlot = { id = 4242 } }))
    ctl.shown = true
    St.Select(rec.id)
    M.__resetPrinted()
    M.C_Container.UseContainerItem(0, 5)
    NS.Inventory.Sync()
    assertEqual(rec.items.ChestSlot.id, NS.ItemInfo.FromSlot("ChestSlot").id, "the hand-worn chest recorded")
    assertTrue(printed(M, "Adding Hauberk of Tracks to Gear outfit"))
    assertEqual(shape(NS), o.normal, "no temp while recording")
    -- An unknown slot (used, its item not worn) is not overwritten.
    local feet = NS.ItemInfo.FromSlot("FeetSlot")
    assertTrue(feet ~= nil)
    rec.items.FeetSlot = { id = 4242 }
    M.PickupInventoryItem(8); M.C_Container.PickupContainerItem(2, 1)
    NS.Inventory.Sync()
    -- red under: recording that ignores the tri-state (the ghost boots are replaced by the empty slot).
    assertEqual(rec.items.FeetSlot.id, 4242)
end)

test("stack: SWAP_COMPLETE once the worn gear matches the expected outfit and no update is pending", function()
    local NS, M, St, _, o = watching()
    local done = hear(NS, "SWAP_COMPLETE")
    St.Wear(o.hero, { now = true })
    assertEqual(NS.ItemInfo.FromSlot("ChestSlot").name, "Hauberk of Tracks", "the wear equipped it")
    NS.Inventory.Sync()
    assertEqual(#done, 1)
    assertEqual(shape(NS), o.normal .. "," .. o.hero, "the outfit's own items make no temp")
    St.Wear(o.hat)                         -- scheduled, not yet run
    assertTrue(NS.Equip.Pending())
    St.OnInventoryChanged(true)
    -- red under: a SWAP_COMPLETE that ignores Equip.Pending().
    assertEqual(#done, 1)
    assertTrue(M ~= nil)
end)

-- ── persistence and Init ─────────────────────────────────────────────────────────────────────

test("stack: the persisted stack round-trips; Init drops unknown ids, keeps temps whole, sets expected", function()
    local NS, _, St = scene()
    local o = outfits(NS)
    St.Wear(o.normal)
    St.Wear(o.hat, { layer = "zone" })
    NS.db.char.stack[#NS.db.char.stack + 1] = { temp = { WristSlot = { id = 0 }, HandsSlot = { id = 0 } } }
    local saved = {}
    for _, k in ipairs({ "outfits", "order", "nextID", "stack", "recent" }) do saved[k] = NS.db.char[k] end
    table.insert(saved.stack, 2, { id = "o99" })
    local NS2, _, St2 = scene()
    for k, v in pairs(saved) do NS2.db.char[k] = v end
    St2.Init()
    assertEqual(shape(NS2), o.normal .. "," .. o.hat .. "/zone,temp:HandsSlot+WristSlot")
    assertEqual(St2.CurrentInfo(), "Custom")
    assertEqual(St2.Expected().HeadSlot.id, 0, "expected is the compiled stack")
    assertEqual(St2.CurrentComplete(), o.normal)
end)
