-- tests/test_equip_bracket.lua — P4.8 (design §5.10): modules/Equip.lua's one bracket (E.Batch /
-- E.BatchNow), its belt and braces (the depth floor, Suspend, the PLAYER_ENTERING_WORLD reset), the
-- ordered gates and the throttle, execution with the SFX mute (B3, B8, INV §16 #4, #13), the
-- specialty-bag empty-then-equip, the equip-error lines and E.Diagnostic().
--
-- NS.Stack lands in P4.9 and NS.EM in P4.10: E.Update's and the PLAYER_ENTERING_WORLD batch's calls
-- into them run against recorded fakes (design §12, the fake rule). PlayerState, Inventory, Changes
-- and Moves are the real modules, and the items move for real in tests/mock_gear.lua.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DB = T.fixtures.items.db

-- A fresh instance at t = 100 with PlayerState and Equip resumed.
local function scene(scenario, overrides)
    local inst = T.load({ mutate = function(M)
        if scenario then M.__gear:load(scenario, overrides) end
    end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Equip.Resume()
    return NS, M, NS.Equip, NS.Equip.__state
end

-- The outfit stack, as P4.9 will answer it: Compile hands back `compiled`.
local function fakeStack(NS, compiled)
    return T.fake(NS, "Stack", { Compile = function() return compiled or {} end, SetExpected = true })
end

local function printedMatching(M, needle)
    local n = 0
    for _, line in ipairs(M.__printed()) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function sfxWrites(M)
    local out = {}
    for _, w in ipairs(M.__cvarWrites) do
        if w[1] == "Sound_EnableSFX" then out[#out + 1] = w[2] end
    end
    return table.concat(out, ",")
end

local function callNames(M)
    local out = {}
    for _, c in ipairs(M.__equipCalls) do out[#out + 1] = c[1] end
    return out
end

local function stackChanged(NS)
    local n = { count = 0 }
    NS.NewBusTarget():RegisterMessage(NS.MSG.STACK_CHANGED, function() n.count = n.count + 1 end)
    return n
end

-- ── the bracket ───────────────────────────────────────────────────────────────────────────────

test("equip bracket: NS.Equip is published with the bracket and no public Begin/End", function()
    local E = T.NS.Equip
    assertEqual(type(E), "table")
    for _, k in ipairs({ "Batch", "BatchNow", "Request", "Pending", "DelayUntil", "SetUpdateDelay",
                         "SuspendedForLoad", "Update", "Execute", "ShowEquipError", "Diagnostic",
                         "Suspend", "Resume" }) do
        assertEqual(type(E[k]), "function", k)
    end
    assertNil(rawget(E, "Begin"), "no Begin")
    assertNil(rawget(E, "End"), "no End")
end)

test("equip bracket: Batch hands fn every argument, a nil hole included", function()
    local _, _, E = scene()
    local got
    E.Batch(function(...) got = { n = select("#", ...), ... } end, 1, nil, 3)
    -- red under: xpcall(fn, traceback, ...) (Lua 5.1's xpcall forwards no extra arguments).
    assertEqual(got.n, 3, "three arguments arrive")
    assertEqual(got[1], 1)
    assertNil(got[2])
    assertEqual(got[3], 3)
end)

test("equip bracket: the depth is balanced on success and on a raise; the raise is surfaced once", function()
    local _, M, E, st = scene()
    local handled, depthAtHandler = {}, nil
    M.geterrorhandler = function()
        return function(err) depthAtHandler = st.depth; handled[#handled + 1] = err end
    end
    local inside
    assertTrue(E.Batch(function() inside = st.depth end))
    assertEqual(inside, 1, "raised inside")
    assertEqual(st.depth, 0, "lowered after a clean fn")
    local ok, err = E.Batch(function() error("boom") end)
    assertFalse(ok)
    assertTrue(tostring(err):find("boom", 1, true) ~= nil, "the error comes back")
    -- red under: decrementing only on success (the legacy stranded count).
    assertEqual(st.depth, 0, "lowered after a raise")
    -- red under: surfacing before the depth is restored.
    assertEqual(depthAtHandler, 0, "the client's handler runs after the depth is restored")
    assertEqual(#handled, 1)
    assertEqual(st.lastError.tag, "batch")
    assertEqual(printedMatching(M, "(batch)"), 1, "one chat line")
    E.Batch(function() error("again") end)
    assertEqual(#handled, 2, "every raise reaches the handler")
    -- red under: printing on every raise (one line per tag per session).
    assertEqual(printedMatching(M, "(batch)"), 1, "still one chat line")
end)

test("equip bracket: after a raise the next Request still schedules", function()
    local _, _, E, st = scene()
    E.Batch(function() E.Request(); error("boom") end)
    assertTrue(st.timer ~= nil, "the raising batch's own request was scheduled at its close")
    E.Suspend()
    E.Resume()
    E.Batch(function() error("boom") end)
    E.Request()
    assertTrue(E.Pending())
    assertTrue(st.timer ~= nil, "scheduled")
end)

test("equip bracket: the depth never goes below zero", function()
    local _, _, E, st = scene()
    E.Batch(function() E.Batch(function() E.Suspend() end) end)
    -- red under: dropping the `depth < 0` floor (it ends at -2 and the == 0 flush never fires again).
    assertEqual(st.depth, 0)
    E.Batch(function() E.Request() end)
    assertTrue(st.timer ~= nil, "a later balanced pair still flushes")
end)

test("equip bracket: only the outermost close flushes; Request inside a batch waits for it", function()
    local NS, _, E, st = scene()
    local heard = stackChanged(NS)
    local timerInside = false
    E.Batch(function()
        E.Batch(function() E.Request() end)
        timerInside = st.timer ~= nil   -- read here, asserted outside: a raise in fn is surfaced, not thrown
    end)
    -- red under: scheduling from Request whatever the depth.
    assertFalse(timerInside, "nothing scheduled inside the bracket")
    assertTrue(st.timer ~= nil, "scheduled at the close")
    -- red under: flushing at every close rather than at depth 0.
    assertEqual(heard.count, 1, "one STACK_CHANGED")
end)

test("equip bracket: BatchNow updates at the close, Batch only schedules", function()
    local NS, _, E = scene("geared")
    local stack = fakeStack(NS, {})
    E.Batch(function() E.Request() end)
    assertEqual(stack.__count("Compile"), 0, "Batch schedules")
    E.BatchNow(function() E.Request() end)
    assertEqual(stack.__count("Compile"), 1, "BatchNow ran the update")
    assertEqual(stack.__count("SetExpected"), 1)
    assertFalse(E.Pending())
end)

-- ── the load screen ───────────────────────────────────────────────────────────────────────────

test("equip bracket: PLAYER_ENTERING_WORLD zeroes a stranded depth before its own batch", function()
    local NS, M, _, st = scene("geared")
    local depthAtSync
    local em = T.fake(NS, "EM", { Sync = function() depthAtSync = st.depth end })
    st.depth = 2   -- stranded, as no Batch can leave it
    M.__fire("PLAYER_ENTERING_WORLD")
    assertEqual(st.pewTimer.delay, 0.05, "debounced 0.05 s")
    M.__fireTimers()
    assertEqual(em.__count("Sync"), 1, "the batch runs EM.Sync")
    -- red under: opening the batch before the reset (it would clear the count it had just raised).
    assertEqual(depthAtSync, 1, "the batch ran on a zeroed count")
    assertEqual(st.depth, 0)
    assertEqual(st.lastError.tag, "pew")
    assertTrue(st.lastError.err:find("stranded depth 2", 1, true) ~= nil)
end)

test("equip bracket: the load screen holds SuspendedForLoad between leaving and entering", function()
    local _, M, E = scene()
    assertFalse(E.SuspendedForLoad())
    M.__fire("PLAYER_LEAVING_WORLD")
    assertTrue(E.SuspendedForLoad())
    M.__fire("PLAYER_ENTERING_WORLD")
    assertFalse(E.SuspendedForLoad())
end)

-- ── the gates ─────────────────────────────────────────────────────────────────────────────────

local function wanted(E, st)
    st.needsUpdate = true
    return E.Update()
end

test("equip bracket: nothing wanted, nothing compiled", function()
    local NS, _, E = scene("geared")
    local stack = fakeStack(NS, {})
    assertEqual(E.Update(), "idle")
    assertEqual(stack.__count("Compile"), 0)
end)

test("equip bracket: dead defers with the update kept; coming back asks again", function()
    local NS, M, E, st = scene("geared")
    local stack = fakeStack(NS, {})
    M.__fire("PLAYER_DEAD")
    -- red under: dropping the dead gate.
    assertEqual(wanted(E, st), "dead")
    assertEqual(stack.__count("Compile"), 0)
    assertTrue(E.Pending(), "still wanted")
    M.__fire("PLAYER_ALIVE")
    assertTrue(st.timer ~= nil, "PLAYER_ALIVE requested it")
end)

test("equip bracket: a cast defers, unless a trigger may interrupt it", function()
    local NS, M, E, st = scene("geared")
    local stack = fakeStack(NS, {})
    M.__fire("UNIT_SPELLCAST_START", "player", "c1", 133)
    -- red under: dropping the casting gate.
    assertEqual(wanted(E, st), "casting")
    assertEqual(stack.__count("Compile"), 0)
    NS.PlayerState.SetInterruptCasting(true)
    -- red under: ignoring InterruptCasting in the casting gate.
    assertNil(wanted(E, st), "interruptible: it runs")
    assertEqual(stack.__count("Compile"), 1)
    assertFalse(NS.PlayerState.InterruptCasting(), "the update cleared the interrupt flag")
end)

test("equip bracket: combat, MaybeInCombat or lockdown keep it wanted and retry", function()
    local NS, M, E, st = scene("geared")
    local stack = fakeStack(NS, {})
    local PS = NS.PlayerState
    M.__world:setCombat(true)
    assertEqual(wanted(E, st), "combat")
    assertTrue(E.Pending())
    assertTrue(st.timer ~= nil, "rescheduled")
    M.__world:setCombat(false)
    M.__now = 110
    PS.SetMaybeInCombat(true)
    -- red under: the combat gate reading only PS.InCombat().
    assertEqual(wanted(E, st), "combat")
    assertFalse(PS.MaybeInCombat(), "the gate cleared MaybeInCombat")
    M.__now = 120
    M.__lockdown = true
    assertEqual(wanted(E, st), "combat", "the lockdown alone is enough")
    M.__lockdown = false
    assertEqual(stack.__count("Compile"), 0, "never compiled in combat")
    M.__now = 130
    assertNil(wanted(E, st))
    assertEqual(stack.__count("Compile"), 1)
end)

test("equip bracket: leaving combat flushes the queued update through PlayerState's batch", function()
    local NS, M, E, st = scene("geared")
    local stack = fakeStack(NS, {})
    local heard = stackChanged(NS)
    M.__world:setCombat(true)
    E.Request()
    M.__fireTimers()
    assertTrue(E.Pending(), "held in combat")
    local held = st.timer
    M.__now = 105
    M.__world:setCombat(false)
    assertEqual(heard.count, 1, "REGEN_ENABLED's empty batch closed")
    assertTrue(st.timer ~= nil and st.timer ~= held, "and rescheduled the queued update")
    M.__fireTimers()
    assertEqual(stack.__count("Compile"), 1)
    assertFalse(E.Pending())
end)

test("equip bracket: the 1.5 s throttle schedules at max(0.05, 1.5 - elapsed)", function()
    local NS, M, E, st = scene("geared")
    fakeStack(NS, {})
    E.Request()
    assertEqual(st.timer.delay, 0.05, "the first update: the floor")
    M.__fireTimers()
    assertEqual(st.lastUpdate, 100)
    M.__now = 100.5
    -- red under: dropping the throttle gate.
    assertEqual(wanted(E, st), "throttle")
    -- red under: a fixed 1.5 s delay.
    assertEqual(st.timer.delay, 1.0, "1.5 - 0.5")
    M.__now = 101.48
    E.Request()
    assertEqual(st.timer.delay, 0.05, "never sooner than 0.05 s")
end)

test("equip bracket: DelayUntil holds the update until its time", function()
    local NS, M, E, st = scene("geared")
    local stack = fakeStack(NS, {})
    st.needsUpdate = true
    E.DelayUntil(100.5)
    assertEqual(st.timer.delay, 0.5, "rescheduled to the delay")
    assertEqual(E.Update(), "delay")
    E.DelayUntil(100.2)
    assertEqual(st.delayUntil, 100.5, "an earlier time never shortens it")
    M.__now = 100.6
    assertNil(E.Update())
    assertEqual(stack.__count("Compile"), 1)
end)

test("equip bracket: SetUpdateDelay keeps the legacy start + delay - 1.5 rule", function()
    local NS, M, E, st = scene("geared")
    local stack = fakeStack(NS, {})
    E.SetUpdateDelay(100, 3)
    assertEqual(st.lastUpdate, 101.5, "the throttle's clock moved to start + delay - 1.5")
    E.Request()
    assertEqual(st.timer.delay, 3, "the next update is 3 s after the start")
    E.SetUpdateDelay(100, 0.5)
    assertEqual(st.lastUpdate, 101.5, "a shorter delay never moves it back")
    M.__now = 102.9
    assertEqual(E.Update(), "throttle")
    M.__now = 103
    assertNil(E.Update())
    assertEqual(stack.__count("Compile"), 1)
end)

-- ── execution ─────────────────────────────────────────────────────────────────────────────────

test("equip bracket: the swap mutes SFX and restores it, the cursor cleared first", function()
    local NS, M, E, st = scene("geared")
    fakeStack(NS, { HeadSlot = NS.ItemInfo.EMPTY })
    assertEqual(NS.GetSetting("equip.muteSounds"), true, "muted by default")
    wanted(E, st)
    assertNil(M.__gear:equipped("HeadSlot"), "the helm went to the bags")
    assertEqual(sfxWrites(M), "0,1")
    assertEqual(M.__cvars.Sound_EnableSFX, "1")
    local names = callNames(M)
    assertEqual(names[#names], "ClearCursor", "the cursor is cleared after the moves")
end)

test("equip bracket: with muteSounds off the SFX CVar is not touched", function()
    local NS, M, E, st = scene("geared")
    fakeStack(NS, { HeadSlot = NS.ItemInfo.EMPTY })
    NS.db.profile.equip.muteSounds = false
    assertEqual(NS.GetSetting("equip.muteSounds"), false)
    wanted(E, st)
    assertNil(M.__gear:equipped("HeadSlot"))
    assertEqual(sfxWrites(M), "")
end)

test("equip bracket: a raise mid-swap still restores SFX and clears the cursor (B8)", function()
    local NS, M, E = scene("geared")
    local real = NS.Moves.ToEmpty
    NS.Moves.ToEmpty = function() error("moves raised") end
    local ok = E.Execute({ { slot = "HeadSlot", slotID = 1, unique = {} } }, NS.Moves.EmptyBagSlots())
    NS.Moves.ToEmpty = real
    assertFalse(ok)
    -- red under: calling runChanges unprotected (SFX stays off for good, the legacy B8).
    assertEqual(M.__cvars.Sound_EnableSFX, "1", "restored")
    assertEqual(sfxWrites(M), "0,1")
    local names = callNames(M)
    assertEqual(names[#names], "ClearCursor")
    assertEqual(E.__state.lastError.tag, "execute")
end)

test("equip bracket: an empty change list touches nothing (B3)", function()
    local NS, M, E, st = scene("geared")
    local stack = fakeStack(NS, {})
    -- red under: dropping the `#changes == 0` early return (SFX toggled and the cursor cleared).
    assertTrue(E.Execute({}, {}))
    assertNil(wanted(E, st))
    assertEqual(stack.__count("Compile"), 1)
    assertEqual(sfxWrites(M), "")
    assertEqual(#M.__equipCalls, 0, "no cursor or item call")
end)

test("equip bracket: the worn item goes to a specialty bag with room before the new one comes in", function()
    local chest = DB.chest_plate
    local prev = chest.family
    chest.family = 0x0020   -- a breastplate herb bags take, so the specialty rule has something to bite on
    local ok, err = pcall(function()
        local NS, M, E = scene("specialty_bags", {
            equipped = { ChestSlot = "chest_plate" },
            bags = { [0] = { items = { [1] = "chest_hero" } }, [1] = { bag = "bag_herb", items = {} } },
        })
        local change = { slot = "ChestSlot", slotID = 5, to = { bag = 0, slot = 1 }, unique = {} }
        E.Execute({ change }, NS.Moves.EmptyBagSlots())
        local names = table.concat(callNames(M), ",")
        -- red under: needsEmptyThenEquip ignoring the empty specialty slots (a straight swap).
        assertTrue(names:find("^ClearCursor,PickupInventoryItem,PickupContainerItem,ClearCursor,PickupContainerItem,EquipCursorItem") ~= nil,
            "emptied first, then equipped: " .. names)
        assertEqual(M.__equipCalls[3][2], 1, "into the herb bag")
        local _, at = M.__gear:find("chest_plate")
        assertEqual(at and at.bag, 1, "the breastplate sits in the herb bag")
        assertEqual(M.__gear:equipped("ChestSlot").def.id, DB.chest_hero.id)
    end)
    chest.family = prev
    if not ok then error(err, 0) end
end)

test("equip bracket: a plain swap does not empty first", function()
    local NS, M, E = scene("geared")
    local _, at = M.__gear:find("chest_hero")
    local change = { slot = "ChestSlot", slotID = 5, to = { bag = at.bag, slot = at.slot }, unique = {} }
    E.Execute({ change }, NS.Moves.EmptyBagSlots())
    assertEqual(table.concat(callNames(M), ","), "ClearCursor,PickupContainerItem,EquipCursorItem,ClearCursor")
    assertEqual(M.__gear:equipped("ChestSlot").def.id, DB.chest_hero.id)
end)

test("equip bracket: an unequip with every bag full prints the bags-full line", function()
    local NS, M, E, st = scene("full_bags")
    fakeStack(NS, { HeadSlot = NS.ItemInfo.EMPTY })
    wanted(E, st)
    assertEqual(printedMatching(M, "because all bags are full"), 1)
    assertTrue(M.__gear:equipped("HeadSlot") ~= nil, "the helm stays on")
end)

test("equip bracket: equip errors print unless equip.showErrors is off", function()
    local NS, M, E, st = scene("geared")
    fakeStack(NS, { HeadSlot = { id = 999999, name = "Ghost Helm" } })
    wanted(E, st)
    assertEqual(printedMatching(M, "Can't find item Ghost Helm for slot Head"), 1)
    E.ShowEquipError({ name = "Band" }, true, "Finger0Slot")
    assertEqual(printedMatching(M,
        "Can't put Band in the First finger slot because it's already being used in another slot"), 1)
    NS.db.profile.equip.showErrors = false
    M.__now = 110
    wanted(E, st)
    E.ShowEquipError({ name = "Band" }, true, "Finger0Slot")
    -- red under: dropping the equip.showErrors gate.
    assertEqual(printedMatching(M, "Ghost Helm"), 1, "silenced")
    assertEqual(printedMatching(M, "Can't put Band"), 1, "silenced")
end)

-- ── lifecycle and diagnostics ─────────────────────────────────────────────────────────────────

test("equip bracket: Suspend zeroes the count and the wish, cancels the timer and restores SFX", function()
    local _, M, E, st = scene("geared")
    E.Request()
    local timer = st.timer
    st.depth, st.sfxSaved = 3, "1"
    M.__cvars.Sound_EnableSFX = "0"
    E.Suspend()
    assertEqual(st.depth, 0)
    assertFalse(E.Pending())
    assertNil(st.timer)
    assertTrue(timer.cancelled == true, "the pending update was canceled")
    -- red under: Suspend leaving the SFX restore out (H26).
    assertEqual(M.__cvars.Sound_EnableSFX, "1")
    M.__fire("PLAYER_LEAVING_WORLD")
    assertFalse(E.SuspendedForLoad(), "nothing registered while suspended")
end)

test("equip bracket: Diagnostic reports depth, the next update, the last error and the tripwire", function()
    local NS, M, E, st = scene("geared")
    fakeStack(NS, {})
    local lines = E.Diagnostic()
    assertEqual(table.concat(lines, "|"),
        "Equipment updates: depth 0, update wanted: false|No equipment update scheduled|No equipment errors this session")
    E.Request()
    M.__fireTimers()
    M.__now = 100.5
    E.Batch(function() E.Request(); error("boom") end)
    M.__now = 103.5
    lines = E.Diagnostic()
    assertEqual(lines[1], "Equipment updates: depth 0, update wanted: true")
    assertEqual(lines[2], "Next equipment update in 0.0 s")
    assertEqual(lines[3], "Last equipment error: batch, 3 s ago")
    assertEqual(#lines, 3, "no tripwire")
    local inside
    E.Batch(function() inside = E.Diagnostic() end)
    -- red under: the tripwire testing `depth > 0` (a running Batch would read as stuck).
    assertEqual(#inside, 3, "a running batch is not stuck")
    st.depth = 2
    lines = E.Diagnostic()
    assertEqual(lines[4], "Equipment updates are STUCK (count 2) -- reload to clear")
end)
