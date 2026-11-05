-- tests/test_outfits.lua — P4.6's outfit store (design §5.6) and LoadPass (§5.7): the record shape
-- (§3.3), Categorize and the shared IsComplete (B10), seeding against tests/fixtures/legacy/states.lua,
-- the idempotent second pass and the repair, Rename, Delete, SetToCurrent, the bindings, the slot
-- tri-state, the preview-id refusal (C28) and the 1 s LoadPass timer's lifecycle.
--
-- The Stack, the trigger binder, the Equipment Manager mirror and the inventory land later (P4.9,
-- P4.15, P4.10) or beside this task (P4.5): every call into them runs against a recorded fake
-- (design §12, the fake rule), and their own suites pin the real behavior.

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local SLOTS = {
    "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "MainHandSlot", "SecondaryHandSlot", "BackSlot", "NeckSlot", "ShirtSlot", "TabardSlot", "Finger0Slot",
    "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
}

--- A fresh instance: a gear scenario, and a class (and spec) set before the files load.
local function scene(opts)
    opts = opts or {}
    local inst = unitLoad({ mutate = function(M)
        M.__gear:load(opts.scenario or "naked")
        if opts.class then M.__world:setClass(opts.class, opts.spec or 1) end
        if opts.faction then M.__units.player.faction = opts.faction end
    end })
    return inst, inst.NS, inst.mocks
end

--- The modules LoadPass, Delete and DeleteAll call, as recorded fakes logging into one sequence.
local function engineFakes(NS, seq, extra)
    seq = seq or {}
    local function log(name) return function(...) seq[#seq + 1] = name; if extra and extra[name] then return extra[name](...) end end end
    return {
        em = T.fake(NS, "EM", { Sync = log("EM.Sync"), DeleteSet = log("EM.DeleteSet"),
                                Items = function(rec) return rec.items end,
                                Rename = function() return true end }),
        stack = T.fake(NS, "Stack", { Init = log("Stack.Init"), Remove = log("Stack.Remove"),
                                      Select = log("Stack.Select"), Clear = log("Stack.Clear"),
                                      Wear = log("Stack.Wear"), Selected = function() return nil end }),
        binder = T.fake(NS, "TriggerBinder", { BindAll = log("Binder.BindAll"), Unbind = log("Binder.Unbind"),
                                               UnbindAll = log("Binder.UnbindAll") }),
    }, seq
end

--- Every message of `key` heard on the bus, each as its payload array.
local function hear(NS, key)
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG[key], function(_, ...) heard[#heard + 1] = { ... } end)
    return heard
end

--- An items table holding every slot but the named ones.
local function itemsExcept(skip)
    local items = {}
    for _, s in ipairs(SLOTS) do
        if not skip[s] then items[s] = { id = 1000 + #s, invType = "INVTYPE_HEAD" } end
    end
    return items
end

local function names(NS, category)
    local out = {}
    for _, id in ipairs(NS.Outfits.Ids(category)) do out[#out + 1] = NS.Outfits.Get(id).name end
    return out
end

-- ── the record ────────────────────────────────────────────────────────────────────────────────

test("outfits: NS.Outfits and NS.OutfitSchema are published", function()
    assertEqual(type(T.NS.Outfits), "table")
    assertEqual(type(T.NS.Outfits.LoadPass), "function", "Outfits_Seed.lua extends NS.Outfits")
    assertEqual(type(T.NS.OutfitSchema), "table", "built at OnInitialize")
end)

test("outfits: Create allocates o<N>, stores the record's shape, appends to the order, announces once", function()
    local _, NS = scene()
    local O = NS.Outfits
    local added = hear(NS, "OUTFIT_ADDED")
    local head = { id = 5, invType = "INVTYPE_HEAD" }
    local id = O.Create("Fishing", { HeadSlot = head }, { icon = 136245, trigger = "FISHING" })
    assertEqual(id, "o1")
    assertEqual(NS.db.char.nextID, 2, "the counter moved on")
    local rec = O.Get(id)
    assertEqual(rec.id, "o1"); assertEqual(rec.name, "Fishing"); assertEqual(rec.kind, "native")
    assertEqual(rec.category, "Accessory")
    assertEqual(rec.icon, 136245)
    assertEqual(rec.trigger.id, "FISHING")
    assertEqual(rec.items.HeadSlot.id, 5)
    assertTrue(rec.items.HeadSlot ~= head, "the items are copied in, never aliased")
    assertEqual(table.concat(O.Ids("Accessory"), ","), "o1")
    assertEqual(#O.Ids("Complete"), 0)
    assertEqual(#added, 1); assertEqual(added[1][1], "o1")
    -- Ids are never reused: a deleted id's number is not handed out again.
    engineFakes(NS)
    O.Delete(id)
    assertEqual(O.Create("Next", {}), "o2")
end)

test("outfits: Get answers nil for any id that is not o<N>, so a preview placeholder never resolves (C28)", function()
    local _, NS = scene()
    local O = NS.Outfits
    local id = O.Create("Real", {})
    NS.db.char.outfits["preview:1"] = { id = "preview:1", name = "Planted" }
    -- red under: Get without the ^o%d+$ check (the planted record answers).
    assertNil(O.Get("preview:1"))
    assertNil(O.Get(nil)); assertNil(O.Get(7)); assertNil(O.Get("o")); assertNil(O.Get("xo1"))
    assertEqual(O.Get(id).name, "Real")
    assertNil(O.Get("o99"), "an unknown id is none")
end)

test("outfits: Categories, Each and FindByName (case-insensitive, exact)", function()
    local _, NS = scene()
    local O = NS.Outfits
    assertEqual(table.concat(O.Categories(), ","), "Complete,Accessory")
    local a = O.Create("Fishing", {})
    local b = O.Create("Normal", itemsExcept({}))
    assertEqual(O.FindByName("fIsHiNg"), a)
    assertEqual(O.FindByName("Normal"), b)
    assertNil(O.FindByName("Fish"), "a prefix is no match")
    assertNil(O.FindByName(nil))
    local seen = {}
    for id, rec in O.Each("Complete") do seen[#seen + 1] = id .. "=" .. rec.name end
    assertEqual(table.concat(seen, ","), b .. "=Normal")
end)

-- ── Categorize and the shared IsComplete (B10) ───────────────────────────────────────────────

test("outfits: Complete means every slot but shirt and tabard; an empty marker counts as present", function()
    local _, NS = scene()
    local O = NS.Outfits
    assertEqual(O.Categorize({ kind = "native", items = itemsExcept({}) }), "Complete")
    assertEqual(O.Categorize({ kind = "native", items = itemsExcept({ ShirtSlot = true, TabardSlot = true }) }),
        "Complete", "shirt and tabard are UNEQUIP_EXEMPT")
    assertEqual(O.Categorize({ kind = "native", items = itemsExcept({ HeadSlot = true }) }), "Accessory")
    local naked = {}
    for _, s in ipairs(SLOTS) do naked[s] = { id = 0 } end
    assertEqual(O.Categorize({ kind = "native", items = naked }), "Complete", "the Naked outfit is Complete")
    assertEqual(O.Categorize({ kind = "native", items = {} }), "Accessory")
end)

test("outfits: an off-hand may be absent under a two-handed main hand, and only then (B10)", function()
    local _, NS = scene()
    local O = NS.Outfits
    local items = itemsExcept({ SecondaryHandSlot = true })
    items.MainHandSlot = { id = 212056, invType = "INVTYPE_2HWEAPON" }
    -- legacy: Accessory (the native IsComplete had no two-hander rule, OutfitterOutfits.lua:198); fixed:
    -- red under: IsComplete without the SecondaryHandSlot / INVTYPE_2HWEAPON exception.
    assertEqual(O.Categorize({ kind = "native", items = items }), "Complete")
    items.MainHandSlot = { id = 1, invType = "INVTYPE_WEAPON" }
    assertEqual(O.Categorize({ kind = "native", items = items }), "Accessory")
    assertTrue(O.IsComplete(function(s) return s ~= "SecondaryHandSlot" end, "INVTYPE_2HWEAPON"))
    assertFalse(O.IsComplete(function(s) return s ~= "SecondaryHandSlot" end, nil))
end)

test("outfits: an Equipment Manager outfit categorizes through the same IsComplete (B10)", function()
    local _, NS = scene()
    local O = NS.Outfits
    local resolved = itemsExcept({ ShirtSlot = true })
    local em = T.fake(NS, "EM", { Items = function() return resolved end })
    -- legacy: Accessory (the EM TemporaryItems branch returned false for a missing shirt,
    -- OutfitterOutfits.lua:872-886); fixed:
    -- red under: Categorize reading rec.items for an em record (it holds none here).
    assertEqual(O.Categorize({ kind = "em", setID = 3, items = {} }), "Complete")
    assertEqual(em.__count("Items"), 1)
end)

test("outfits: Changed re-categorizes, moves the id between the orders, and sends OUTFIT_EDITED", function()
    local _, NS = scene()
    local O = NS.Outfits
    local id = O.Create("Growing", itemsExcept({ HeadSlot = true }))
    assertEqual(O.Get(id).category, "Accessory")
    local edited = hear(NS, "OUTFIT_EDITED")
    NS.db.char.outfits[id].items.HeadSlot = { id = 9 }
    O.Changed(id, "items")
    assertEqual(O.Get(id).category, "Complete")
    assertEqual(table.concat(O.Ids("Complete"), ","), id)
    assertEqual(#O.Ids("Accessory"), 0, "it left the Accessory order")
    assertEqual(#edited, 1); assertEqual(edited[1][1], id); assertEqual(edited[1][2], "items")
end)

-- ── LoadPass: seeding (INV §3.1, legacy/states.lua) ───────────────────────────────────────────

-- The legacy preset ids each seeded outfit carried, and the trigger it carries now (design §6.8.3).
local TRIGGER_OF = {
    Caster = "DRUID_CASTER", Bear = "DRUID_BEAR", Cat = "DRUID_CAT", Travel = "DRUID_TRAVEL",
    Moonkin = "DRUID_MOONKIN", Tree = "DRUID_TREE", Prowl = "DRUID_PROWL", Stealth = "ROGUE_STEALTH",
    GhostWolf = "SHAMAN_GHOST_WOLF",
}

-- One case per class the capture seeded, in a stable order (the case list is generated, testing-§5).
local CLASSES = {}
for class in pairs(T.legacy.states.seeded) do CLASSES[#CLASSES + 1] = class end
table.sort(CLASSES)

for _, class in ipairs(CLASSES) do
    local want = T.legacy.states.seeded[class]
    test("outfits: the first LoadPass seeds a " .. class .. " as the legacy addon did", function()
        local inst, NS = scene({ class = class })
        local fakes, seq = engineFakes(NS)
        local specs = inst.mocks.__world.specs
        NS.Outfits.LoadPass()
        assertEqual(table.concat(names(NS, "Complete"), "|"), "Normal|Birthday Suit")
        local wantAcc, wantTrig, wantIcon = {}, {}, {}
        for i, o in ipairs(want.outfits.Accessory) do
            local n = o.scriptID:match("^SPECIALIZATION_(%d+)$")
            -- The capture's stand-in spec names (SpecN) are the mock's real ones here.
            wantAcc[i] = n and (o.name:gsub("Spec%d+$", specs[tonumber(n)][2])) or o.name
            wantTrig[i] = n and ("SPEC_" .. n) or TRIGGER_OF[o.scriptID]
            wantIcon[i] = o.icon
        end
        assertEqual(table.concat(names(NS, "Accessory"), "|"), table.concat(wantAcc, "|"))
        for i, id in ipairs(NS.Outfits.Ids("Accessory")) do
            local rec = NS.Outfits.Get(id)
            assertEqual(rec.trigger and rec.trigger.id, wantTrig[i], rec.name .. "'s trigger")
            assertEqual(rec.icon, wantIcon[i], rec.name .. "'s icon")
            assertTrue(type(rec.builtin) == "string", rec.name .. " carries its seed key")
        end
        -- The stack is the Normal outfit (legacy `stack = { "Normal" }`).
        local stack = NS.db.char.stack
        assertEqual(#stack, #want.stack)
        assertEqual(NS.Outfits.Get(stack[1].id).name, want.stack[1])
        assertTrue(NS.db.char.seeded, "seeded is stamped")
        -- EM.Sync first; the Stack restores and the triggers bind after the seed.
        assertEqual(table.concat(seq, ","), "EM.Sync,Stack.Init,Binder.BindAll")
        assertEqual(fakes.em.__count("Sync"), 1)
    end)
end

test("outfits: Normal is the worn gear, Naked empties every slot, and their seed keys are set", function()
    local _, NS, M = scene({ scenario = "geared" })
    engineFakes(NS)
    NS.Outfits.LoadPass()
    local O = NS.Outfits
    local normal, naked = O.Get(O.FindByName("Normal")), O.Get(O.FindByName("Birthday Suit"))
    assertEqual(normal.builtin, "NORMAL"); assertEqual(naked.builtin, "NAKED")
    for _, s in ipairs(SLOTS) do
        assertEqual(naked.items[s].id, 0, "Naked " .. s)
        local worn = M.__gear:equipped(s)
        assertEqual(normal.items[s].id, worn and worn.def.id or 0, "Normal " .. s)
    end
    assertEqual(normal.items.HeadSlot.invType, "INVTYPE_HEAD", "the snapshot is a full ItemRecord")
    assertNil(normal.items.HeadSlot.loc, "no live cache object is stored (B15)")
end)

test("outfits: a second LoadPass seeds nothing and calls no EM.Sync; the first marks FirstPassDone", function()
    local _, NS = scene({ class = "DRUID" })
    local fakes = engineFakes(NS)
    assertFalse(NS.Outfits.FirstPassDone(), "FirstPassDone before any LoadPass")
    NS.Outfits.LoadPass()
    -- red under: a LoadPass that never sets firstDone in modules/Outfits_Seed.lua.
    assertTrue(NS.Outfits.FirstPassDone(), "the first LoadPass did not mark itself done")
    local count = NS.db.char.nextID
    NS.Outfits.LoadPass()
    -- red under: LoadPass seeding without the `seeded` check (every built-in outfit twice).
    assertEqual(NS.db.char.nextID, count, "the second pass created an outfit")
    assertEqual(fakes.em.__count("Sync"), 1)
    assertEqual(fakes.stack.__count("Init"), 2, "the Stack restores on every pass")
    assertEqual(fakes.binder.__count("BindAll"), 2)
end)

test("outfits: seeding adopts an outfit that already has the built-in's name instead of duplicating it", function()
    local _, NS = scene({ class = "ROGUE" })
    engineFakes(NS)
    local mine = NS.Outfits.Create("Rogue: Stealth", {})
    NS.Outfits.LoadPass()
    assertEqual(NS.Outfits.FindByName("Rogue: Stealth"), mine)
    local n = 0
    for _, id in ipairs(NS.Outfits.Ids("Accessory")) do
        if NS.Outfits.Get(id).name == "Rogue: Stealth" then n = n + 1 end
    end
    assertEqual(n, 1)
    assertEqual(NS.Outfits.Get(mine).trigger.id, "ROGUE_STEALTH", "the trigger is assigned when it had none")
    -- red under: seedOne's adoption leaving the seed key unset (design §3.3).
    assertEqual(NS.Outfits.Get(mine).builtin, "CLASS_ROGUE_STEALTH", "the adopted outfit carries its seed key")
end)

test("outfits: an adopted spec outfit takes the spec icon, as the legacy SetIcon did (Outfitter.lua:5788-5790)", function()
    local inst, NS = scene({ class = "ROGUE" })
    engineFakes(NS)
    local spec = inst.mocks.__world.specs[1][2]
    local mine = NS.Outfits.Create("Rogue: " .. spec, {}, { icon = 5 })
    NS.Outfits.LoadPass()
    local rec = NS.Outfits.Get(mine)
    -- red under: seedOne's adoption ignoring opts.icon (the icon stays 5).
    assertEqual(rec.icon, 1001, "the spec's icon")
    assertEqual(rec.builtin, "SPEC_1"); assertEqual(rec.trigger.id, "SPEC_1")
end)

test("outfits: an Equipment Manager mirror adopted by name keeps its set's icon", function()
    -- Smoke round 2 design G1: the set and the glyph override are an EM mirror's only icon homes
    -- (setEMIcon's invariant), so the seed never writes rec.icon on one.
    local inst, NS = scene({ class = "ROGUE" })
    engineFakes(NS)
    local spec = inst.mocks.__world.specs[1][2]
    local mine = NS.Outfits.Create("Rogue: " .. spec, {}, { kind = "em", setID = 7 })
    NS.Outfits.LoadPass()
    local rec = NS.Outfits.Get(mine)
    -- red under: seedOne writing the spec icon onto the adopted mirror.
    assertNil(rec.icon, "the seed wrote an icon onto an EM mirror")
    assertEqual(rec.kind, "em")
end)

-- ── LoadPass: repair ──────────────────────────────────────────────────────────────────────────

test("outfits: the repair prunes stale ids and duplicates, re-asserts nextID and rebuilds the orders", function()
    local _, NS = scene()
    engineFakes(NS)
    local c = NS.db.char
    c.seeded = true
    c.outfits.o1 = { id = "o1", name = "One", kind = "native", category = "Complete", items = {} }
    c.outfits.o5 = { id = "o5", name = "Five", kind = "native", category = "Accessory", items = itemsExcept({}) }
    c.nextID = 2
    c.order = { Complete = { "o1", "o99" }, Accessory = {} }
    c.recent = { "o1", "o99", "o1", "o5" }
    c.stack = { { id = "o99" }, { temp = { HeadSlot = { id = 7 } } }, { id = "o1", layer = "zone" } }
    c.bindings = { [3] = "o99", [4] = "o1" }
    NS.Outfits.LoadPass()
    assertEqual(table.concat(c.recent, ","), "o1,o5", "missing ids and duplicates pruned (Outfitter.lua:5334)")
    assertEqual(#c.stack, 2, "the stale entry dropped, the temp entry kept")
    assertEqual(c.stack[1].temp.HeadSlot.id, 7)
    assertEqual(c.stack[2].id, "o1"); assertEqual(c.stack[2].layer, "zone")
    assertNil(c.bindings[3]); assertEqual(c.bindings[4], "o1")
    assertEqual(c.nextID, 6, "max + 1")
    -- o1 holds nothing (Accessory); o5 holds every slot (Complete): both moved to their order.
    assertEqual(table.concat(NS.Outfits.Ids("Complete"), ","), "o5")
    assertEqual(table.concat(NS.Outfits.Ids("Accessory"), ","), "o1")
    assertEqual(c.outfits.o1.category, "Accessory")
end)

test("outfits: the repair points the Argent Lance at the player's faction lance (quirk 23)", function()
    local _, NS = scene({ faction = "Horde" })
    engineFakes(NS)
    NS.db.char.seeded = true
    NS.Outfits.LoadPass()
    assertEqual(NS.ItemData.ALIASES[46106], 46070)
end)

-- ── the LoadPass timer (design §5.7, §5.12) ───────────────────────────────────────────────────

test("outfits: the first PLAYER_ENTERING_WORLD arms a 1 s LoadPass; Suspend cancels and Resume re-arms it", function()
    local _, NS, M = scene()
    local fakes = engineFakes(NS)
    local O = NS.Outfits
    O.Resume()
    assertNil(O.loadTimer, "nothing is armed before the first PEW")
    M.__fire("PLAYER_ENTERING_WORLD")
    assertTrue(O.loadTimer ~= nil, "the first PEW arms the timer")
    O.Suspend()
    assertNil(O.loadTimer, "Suspend cancels it")
    M.__fireTimers()
    assertEqual(fakes.stack.__count("Init"), 0, "a canceled timer ran the LoadPass")
    O.Resume()
    assertTrue(O.loadTimer ~= nil, "Resume re-arms it: the PEW was seen and the LoadPass has not run")
    M.__fireTimers()
    assertEqual(fakes.stack.__count("Init"), 1)
    assertNil(O.loadTimer)
    M.__fire("PLAYER_ENTERING_WORLD")
    assertNil(O.loadTimer, "a later PEW does not arm another")
    O.Suspend(); O.Resume()
    -- red under: Resume re-arming without the "first LoadPass has not run" check.
    assertNil(O.loadTimer, "the LoadPass ran; Resume does not re-arm it")
    O.Suspend()
end)

test("outfits: a session that logged in stood down arms the LoadPass when it stands up (design §5.12)", function()
    local _, NS, M = scene()
    local fakes = engineFakes(NS)
    local O = NS.Outfits
    O.Suspend()                          -- the disabled login's stand-down, before any Resume
    M.__fire("PLAYER_ENTERING_WORLD")    -- unheard: nothing is registered
    assertNil(O.loadTimer)
    O.Resume()                           -- the player re-enables, in the world
    -- red under: Resume arming only `if pewSeen` (the store stays unbuilt until the next loading screen).
    assertTrue(O.loadTimer ~= nil, "the stand-up arms the first LoadPass")
    M.__fireTimers()
    assertEqual(fakes.stack.__count("Init"), 1)
    assertTrue(NS.db.char.seeded, "a fresh character is seeded")
    O.Suspend()
end)

-- ── Rename and Delete ─────────────────────────────────────────────────────────────────────────

test("outfits: Rename refuses a duplicate and sends OUTFIT_RENAMED with no wear or remove (O16)", function()
    local _, NS = scene()
    local O = NS.Outfits
    local a = O.Create("Fishing", {})
    O.Create("Riding", {})
    T.fake(NS, "Stack", {})   -- any Stack call raises: a rename neither unwears nor wears
    local renamed = hear(NS, "OUTFIT_RENAMED")
    local ok, err = O.Rename(a, "riding")
    -- red under: Rename without the FindByName duplicate check.
    assertFalse(ok); assertEqual(err, "That name is already used")
    assertEqual(O.Get(a).name, "Fishing")
    -- red under: Rename without its `name == ""` refusal.
    assertFalse((O.Rename(a, "")), "an empty name is refused")
    assertEqual(#renamed, 0)
    assertTrue(O.Rename(a, "Angling"))
    assertEqual(O.Get(a).name, "Angling")
    assertEqual(#renamed, 1)
    assertEqual(table.concat(renamed[1], ","), a .. ",Fishing,Angling")
    assertTrue(O.Rename(a, "ANGLING"), "a change of case is the same outfit, not a duplicate")
end)

test("outfits: an EM outfit's rename goes through EM.Rename, and its refusal stops the rename", function()
    local _, NS = scene()
    local O = NS.Outfits
    local refuse = true
    local em = T.fake(NS, "EM", { Items = function(rec) return rec.items end,
                                  Rename = function() if refuse then return false, "nope" end return true end })
    local id = O.Create("Set", {}, { kind = "em", setID = 4 })
    local ok, err = O.Rename(id, "Other")
    assertFalse(ok); assertEqual(err, "nope"); assertEqual(O.Get(id).name, "Set")
    refuse = false
    assertTrue(O.Rename(id, "Other"))
    assertEqual(O.Get(id).name, "Other")
    assertEqual(em.__count("Rename"), 2)
    assertEqual(em.__calls[2][3], "Other")
end)

test("outfits: Delete unwears, then unbinds, then unlinks, then deletes the EM set, then announces", function()
    local _, NS = scene()
    local O = NS.Outfits
    local snapshot = {}
    local function where(tag) return function()
        snapshot[tag] = { linked = #O.Ids("Accessory") == 1, bound = O.BoundTo(2) ~= nil }
    end end
    local _, seq = engineFakes(NS, nil, { ["Binder.Unbind"] = where("unbind"), ["EM.DeleteSet"] = where("deleteSet") })
    local id = O.Create("Set", {}, { kind = "em", setID = 4 })
    O.SetBinding(id, 2)
    local deleted = hear(NS, "OUTFIT_DELETED")
    NS.NewBusTarget():RegisterMessage(NS.MSG.OUTFIT_DELETED, function() seq[#seq + 1] = "OUTFIT_DELETED" end)
    assertTrue(O.Delete(id))
    assertEqual(table.concat(seq, ","), "Stack.Remove,Binder.Unbind,EM.DeleteSet,OUTFIT_DELETED")
    assertTrue(snapshot.unbind.linked and snapshot.unbind.bound, "unbound while still linked")
    assertFalse(snapshot.deleteSet.linked or snapshot.deleteSet.bound, "unlinked before the set goes")
    assertNil(O.Get(id)); assertEqual(#O.Ids("Accessory"), 0); assertNil(O.BoundTo(2))
    assertEqual(table.concat(deleted[1], ","), id .. ",Set")
    assertFalse(O.Delete(id), "a second delete finds nothing")
end)

test("outfits: a native outfit's Delete never touches the Equipment Manager", function()
    local _, NS = scene()
    local id = NS.Outfits.Create("Mine", {})
    local fakes = engineFakes(NS)
    NS.Outfits.Delete(id)
    -- red under: Delete calling NS.EM.DeleteSet without its `rec.kind == "em"` check.
    assertEqual(fakes.em.__count("DeleteSet"), 0)
end)

-- ── items, slots and the tri-state ────────────────────────────────────────────────────────────

test("outfits: SetToCurrent snapshots the enabled slots, wears now, and prints the legacy line", function()
    local _, NS, M = scene({ scenario = "geared" })
    local O = NS.Outfits
    local fakes = engineFakes(NS)
    local id = O.Create("Mine", { HeadSlot = { id = 1 }, ChestSlot = { id = 0 } })
    local edited = hear(NS, "OUTFIT_EDITED")
    M.__resetPrinted()
    local ok, msg = O.SetToCurrent(id)
    assertTrue(ok)
    assertEqual(msg, "Updated the outfit 'Mine' to currently equipped items")
    assertTrue(table.concat(M.__printed(), "\n"):find(msg, 1, true) ~= nil, "the line was printed")
    local rec = O.Get(id)
    assertEqual(rec.items.HeadSlot.id, M.__gear:equipped("HeadSlot").def.id)
    assertEqual(rec.items.ChestSlot.id, M.__gear:equipped("ChestSlot").def.id)
    assertNil(rec.items.LegsSlot, "a slot the outfit does not use stays unused")
    assertEqual(fakes.stack.__count("Wear"), 1)
    local wear = fakes.stack.__calls[1]
    assertEqual(wear[2], id); assertTrue(wear[3].now == true, "worn now")
    assertEqual(#edited, 1)
end)

test("outfits: SetToCurrent with no outfit names the Complete outfit it lacks (INV §5 Fix)", function()
    local _, NS = scene()
    local ok, msg = NS.Outfits.SetToCurrent(nil)
    assertFalse(ok)
    assertEqual(msg, "No Complete outfit is equipped.")
end)

test("outfits: SetSlotEnabled records the worn item or the empty marker; off clears the slot", function()
    local _, NS, M = scene({ scenario = "geared" })
    local O = NS.Outfits
    local id = O.Create("Mine", {})
    O.SetSlotEnabled(id, "HeadSlot", true)
    assertEqual(O.Get(id).items.HeadSlot.id, M.__gear:equipped("HeadSlot").def.id)
    O.SetSlotEnabled(id, "HeadSlot", false)
    assertNil(O.Get(id).items.HeadSlot)
    O.SetAllSlotsEnabled(id, true)
    assertEqual(O.Get(id).category, "Complete")
    O.SetAllSlotsEnabled(id, false)
    assertEqual(next(O.Get(id).items), nil)
    assertEqual(O.Get(id).category, "Accessory")
end)

test("outfits: SlotState is off, on or unknown (enabled, not worn), and UnknownSlots lists the last", function()
    local _, NS = scene()
    local O = NS.Outfits
    local id = O.Create("Mine", { HeadSlot = { id = 1 }, ChestSlot = { id = 2 } })
    local cache = { SlotHas = function(_, slot) return slot == "HeadSlot" end }
    assertEqual(O.SlotState(id, "HeadSlot", cache), "on")
    -- red under: SlotState answering "on" for an enabled slot without asking the cache.
    assertEqual(O.SlotState(id, "ChestSlot", cache), "unknown")
    assertEqual(O.SlotState(id, "LegsSlot", cache), "off")
    local unknown = O.UnknownSlots(id, cache)
    assertTrue(unknown.ChestSlot); assertNil(unknown.HeadSlot); assertNil(unknown.LegsSlot)
end)

test("outfits: AddNewItems records the new items but never over an unknown slot", function()
    local _, NS = scene()
    local O = NS.Outfits
    local id = O.Create("Mine", { HeadSlot = { id = 1 }, ChestSlot = { id = 2 } })
    T.fake(NS, "Inventory", { Cache = function()
        return { SlotHas = function(_, slot) return slot == "HeadSlot" end }
    end })
    O.AddNewItems(id, { HeadSlot = { id = 11 }, ChestSlot = { id = 12 }, LegsSlot = { id = 13 } })
    local items = O.Get(id).items
    assertEqual(items.HeadSlot.id, 11); assertEqual(items.LegsSlot.id, 13)
    assertEqual(items.ChestSlot.id, 2, "the unknown slot kept its item")
end)

test("outfits: Status reads the trigger's disabled flag first, then the inventory's missing and banked", function()
    local _, NS = scene()
    local O = NS.Outfits
    local id = O.Create("Mine", { HeadSlot = { id = 1 } }, { trigger = "FISHING" })
    local missing, banked, argc = {}, {}, nil
    T.fake(NS, "Inventory", { Missing = function(...) argc = select("#", ...); return missing, banked end })
    assertEqual(O.Status(id), "normal")
    -- red under: O.Status passing a second argument to NS.Inventory.Missing, which takes the record
    -- alone (F-010: the window's status cache was handed on and silently dropped).
    assertEqual(argc, 1, "Inventory.Missing takes the record alone")
    banked[1] = "HeadSlot"
    assertEqual(O.Status(id), "banked")
    missing[1] = "HeadSlot"
    assertEqual(O.Status(id), "missing")
    NS.db.char.outfits[id].trigger.disabled = true
    assertEqual(O.Status(id), "disabled")
end)

test("outfits: SetFlag takes the allow-list only, and stores a cleared flag as absent", function()
    local _, NS = scene()
    local O = NS.Outfits
    local id = O.Create("Mine", {})
    local edited = hear(NS, "OUTFIT_EDITED")
    assertTrue(O.SetFlag(id, "unequipOthers", true))
    assertTrue(O.SetFlag(id, "titleID", 42))
    assertTrue(O.Get(id).unequipOthers); assertEqual(O.Get(id).titleID, 42)
    assertTrue(O.SetFlag(id, "unequipOthers", false))
    assertNil(O.Get(id).unequipOthers)
    -- red under: SetFlag without the allow-list (the icon is an instance row, design §3.5).
    assertFalse(O.SetFlag(id, "icon", 5)); assertNil(O.Get(id).icon)
    assertEqual(#edited, 3)
    assertEqual(edited[1][2], "unequipOthers")
end)

test("outfits: SetBinding keeps one outfit per key, and a rebind moves the outfit's key", function()
    local _, NS = scene()
    local O = NS.Outfits
    local a, b = O.Create("A", {}), O.Create("B", {})
    assertTrue(O.SetBinding(a, 3))
    assertTrue(O.SetBinding(b, 3))
    assertEqual(O.BoundTo(3), b); assertNil(O.BindingOf(a))
    assertTrue(O.SetBinding(b, 5))
    -- red under: SetBinding without its unbindKeys(id) (the outfit keeps key 3 beside key 5).
    assertNil(O.BoundTo(3), "the outfit's old key was released"); assertEqual(O.BindingOf(b), 5)
    assertTrue(O.SetBinding(b, nil)); assertNil(O.BindingOf(b))
    -- red under: validKey without its range and integer checks (keys 0, 11 and 2.5 are stored).
    assertFalse(O.SetBinding(a, 0)); assertFalse(O.SetBinding(a, 11)); assertFalse(O.SetBinding(a, 2.5))
    NS.db.char.bindings[7] = "o99"
    assertNil(O.BoundTo(7), "a stale binding is none")
end)

test("outfits: CreateFromItem names the outfit after the item and holds it in its slot", function()
    local _, NS = scene()
    local O = NS.Outfits
    local def = T.fixtures.items.db.greatsword
    local link = def.link
    local id = O.CreateFromItem(link)
    local rec = O.Get(id)
    assertEqual(rec.name, def.name)
    assertEqual(rec.items.MainHandSlot.id, def.id)
    -- red under: CreateFromItem without its `if not slot then return nil` (indexing the nil slot raises).
    assertNil(O.CreateFromItem("not a link"))
end)

test("outfits: UsingItem reads the link into an item info, and answers the outfits that use it", function()
    local _, NS = scene({ scenario = "geared" })
    local O = NS.Outfits
    local head = NS.ItemInfo.FromSlot("HeadSlot")
    local id = O.Create("Helm", { HeadSlot = NS.ItemInfo.Snapshot(head) })
    O.Create("Other", {})
    -- red under: UsingItem passing the raw link to Inventory.OutfitsUsing (always {}).
    assertEqual(table.concat(O.UsingItem(head.link), ","), id)
    -- red under: Inventory.OutfitsUsing without its `info and info.slot` guard (a nil info raises).
    assertEqual(#O.UsingItem("not a link"), 0)
end)

test("outfits: the kind dispatch sends an EM outfit's items and slot edits to the EM", function()
    local _, NS = scene()
    local O = NS.Outfits
    local em = T.fake(NS, "EM", { Items = function() return { HeadSlot = { id = 3 } } end,
                                  SetItem = true, ClearSlot = true })
    local id = O.Create("Set", {}, { kind = "em", setID = 9 })
    assertTrue(O.IsEM(id))
    assertEqual(O.Items(O.Get(id)).HeadSlot.id, 3)
    O.SetItem(id, "LegsSlot", { id = 4 })
    O.ClearSlot(id, "HeadSlot")
    assertEqual(em.__count("SetItem"), 1); assertEqual(em.__count("ClearSlot"), 1)
    assertNil(O.Get(id).items.LegsSlot, "the record's own items are not the EM's")
end)
