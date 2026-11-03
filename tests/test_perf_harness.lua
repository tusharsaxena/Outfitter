-- tests/test_perf_harness.lua — the performance harness's wiring and the latch it stands the addon
-- down through (design §2.1, §5.12; performance-§1/§3/§6, testing-§8): the ten buckets declared in
-- order with the one declared nesting, the descriptor's single teardown path, no dynamic bucket key
-- anywhere in the shipped source, and the perf hold making the addon inert (P3 C10). P4.31 adds the
-- reach: every bucket is noted when its path is driven on the whole addon, equipExecute only inside
-- equipUpdate, and each of tests/perf.lua's five scenarios does the work it is named for. The
-- drivers are tests/perf_scenes.lua's, the ones the offline runner measures.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- Design §2.1, in declaration order.
local BUCKETS = {
    "auraScan", "zoneUpdate", "bagSync", "equipUpdate", "equipExecute", "triggerDispatch",
    "optimizeStep", "dockFollow", "barRender", "tooltipUsedBy",
}
local DECLARED = {}
for _, key in ipairs(BUCKETS) do DECLARED[key] = true end
local ITEM_NAMES = { sword_1h = T.fixtures.items.db.sword_1h.name }

-- ── the descriptor ─────────────────────────────────────────────────────────────────────────────

test("perf: the descriptor declares the ten buckets in order, the SavedVariable and the one latch", function()
    local NS = T.load().NS
    local d = assert(NS.Perf.descriptor, "NS.Perf carries no descriptor; was the stub loaded?")
    local keys = {}
    for i, b in ipairs(d.buckets) do keys[i] = b.key end
    assertEqual(table.concat(keys, ","), table.concat(BUCKETS, ","))
    assertEqual(d.sv, "OutfitterRebornPerfDB")
    assertEqual(d.name, "OutfitterReborn")
    assertEqual(d.slash, "/of")
    assertTrue(d.lifecycle == NS.lifecycle, "the harness holds a latch other than NS.lifecycle")
    assertNil(d.suspend, "a second teardown path beside the latch (performance-§6)")
    assertNil(d.resume, "a second stand-up path beside the latch (performance-§6)")
end)

test("perf: equipExecute is the one bucket declared within another, and within equipUpdate", function()
    -- red under: dropping `within = "equipUpdate"` from core/PerfSetup.lua, or nesting a second bucket.
    local NS = T.load().NS
    local within = {}
    for _, b in ipairs(NS.Perf.descriptor.buckets) do
        if b.within ~= nil then within[#within + 1] = b.key .. "<" .. tostring(b.within) end
    end
    assertEqual(table.concat(within, ","), "equipExecute<equipUpdate")
    assertEqual(NS.Perf.BUCKET_WITHIN.equipExecute, "equipUpdate", "the library did not read the nesting")
end)

-- ── every bucket is reached ────────────────────────────────────────────────────────────────────

local Scenes = dofile(T.root .. "/tests/perf_scenes.lua")({ root = T.root, load = T.load })

--- Watch an instance's notes with capture on: `seen.counts[key]` per bucket, and `seen.outside` the
--- equipExecute notes made while no E.Update was running. `seen.stop()` puts both seams back.
local function watch(NS)
    local seen = { counts = {}, outside = 0 }
    local E, Perf = NS.Equip, NS.Perf
    local update, note, depth = E.Update, Perf.Note, 0
    E.Update = function(...)
        depth = depth + 1
        local stopped = update(...)
        depth = depth - 1
        return stopped
    end
    Perf.Note = function(key, ...)
        seen.counts[key] = (seen.counts[key] or 0) + 1
        if key == "equipExecute" and depth == 0 then seen.outside = seen.outside + 1 end
        return note(key, ...)
    end
    Perf.on = true
    function seen.stop()
        Perf.on = false
        E.Update, Perf.Note = update, note
    end
    return seen
end

--- Build `name`'s scene and run its step `n` times under watch.
local function drive(name, n)
    local step, NS, M, extra = Scenes[name]()
    local seen = watch(NS)
    local ok, err = pcall(function() for _ = 1, n do step() end end)
    seen.stop()
    if not ok then error(err, 0) end
    return seen, NS, M, extra
end

test("perf: every declared bucket is reached, and equipExecute only within equipUpdate", function()
    -- red under: dropping any one bracket's Perf.Note (e.g. Tooltips.OnItem's tooltipUsedBy), or
    -- bracketing equipExecute in E.Execute instead of around its call in E.Update (the direct
    -- Execute below then notes outside the update).
    local total, outside = {}, 0
    local names = {}
    for _, name in ipairs(Scenes.PERF) do names[#names + 1] = name end
    for _, name in ipairs(Scenes.OTHERS) do names[#names + 1] = name end
    for _, name in ipairs(names) do
        local seen = drive(name, 2)
        for key, n in pairs(seen.counts) do total[key] = (total[key] or 0) + n end
        outside = outside + seen.outside
    end
    for _, key in ipairs(BUCKETS) do
        assertTrue((total[key] or 0) > 0, key .. " was never noted: its path is unbracketed or undriven")
    end
    for key in pairs(total) do
        assertTrue(DECLARED[key] == true, "a note for an undeclared bucket: " .. key)
    end
    -- An Execute outside an update (the bank's deposit and withdraw) is no equipExecute.
    local _, NS, M = Scenes.equipPlan()
    local seen = watch(NS)
    local _, at = M.__gear:find("sword_1h_b")
    local change = { slot = "MainHandSlot", slotID = 16, to = { bag = at.bag, slot = at.slot }, unique = {} }
    NS.Equip.Execute({ change }, NS.Moves.EmptyBagSlots())
    seen.stop()
    assertEqual(M.__gear:equipped("MainHandSlot").def.name, "Shortsword of Spies", "the direct Execute moved nothing")
    outside = outside + seen.outside
    assertEqual(outside, 0, "equipExecute noted outside equipUpdate")
end)

-- ── the five offline scenarios do what they are named for ─────────────────────────────────────

test("perf scenes: the full-bag plan is one update with one change and one bag sync per step", function()
    -- red under: an equipPlan step that leaves the throttle in force (no `M.__now` advance: the
    -- second update stops at the throttle gate and executes nothing).
    local seen, NS, M = drive("equipPlan", 4)
    assertEqual(seen.counts.equipUpdate, 4)
    assertEqual(seen.counts.equipExecute, 4)
    assertEqual(seen.counts.bagSync, 4)
    assertEqual(#NS.Moves.EmptyBagSlots(), 0, "the bags are not full: the plan is no full-bag plan")
    assertEqual(M.__gear:equipped("MainHandSlot").def.name, ITEM_NAMES.sword_1h, "four swaps end where they began")
    local printed = M.__printed()
    assertEqual(#printed, 0, "the plan printed: " .. tostring(printed[1]))
end)

test("perf scenes: 50 zone flips are 50 zone reads, and the battleground outfit follows them", function()
    local seen, NS = drive("zoneFlips", 1)
    assertEqual(seen.counts.zoneUpdate, Scenes.FLIPS)
    -- red under: a flip that never changes the instance (every read after the first takes the
    -- early-out, and no zone state moves).
    assertTrue((seen.counts.triggerDispatch or 0) >= Scenes.FLIPS, "the zone state never reached the binding")
    assertFalse(NS.States.InZone("PVP_BATTLEGROUND"), "an even flip count ends in the open world")
end)

test("perf scenes: the fan-out dispatches each of the 40 bindings once per edge", function()
    local seen, NS, _, ids = drive("triggerFanout", 3)
    assertEqual(seen.counts.triggerDispatch, 3 * Scenes.FANOUT)
    local worn = 0
    for _, id in ipairs(ids) do
        if NS.Stack.IsWorn(id) then worn = worn + 1 end
    end
    -- red under: a step that does not toggle IsResting (each dispatch unequips what is not worn).
    assertEqual(worn, Scenes.FANOUT, "three edges end resting, with every outfit worn")
end)

test("perf scenes: the tooltip pass draws 100 bag items and decorates the used ones", function()
    local seen, NS, M = drive("tooltips", 1)
    assertEqual(seen.counts.tooltipUsedBy, Scenes.TOOLTIPS)
    local tip = M.GameTooltip
    local _, at = M.__gear:find("staff")
    tip:SetBagItem(at.bag, at.slot)
    M.__world:tooltipPostCall(M.Enum.TooltipDataType.Item, tip, nil)
    local found = false
    for i = 1, tip:NumLines() do
        local s = tip["TextLeft" .. i]:GetText()
        if type(s) == "string" and s:find("Caster", 1, true) then found = true end
    end
    assertTrue(found, "the staff's tooltip names no outfit: the pass decorates nothing")
    assertTrue(NS.Outfits.FindByName("Caster") ~= nil)
end)

test("perf scenes: one genetic generation breeds 275 children over whole resumes", function()
    local seen, NS = drive("gaGeneration", 4)
    local P = NS.OptimizeGA.PARAMS
    local job = NS.Optimize.Running()
    assertTrue(job ~= nil, "no search is running")
    -- red under: a step that resumes once (100 children) instead of breeding one generation's worth.
    assertTrue(job.generated >= P.population + 4 * (P.population - P.parents), "fewer than four generations bred")
    assertTrue(seen.counts.optimizeStep >= 4 * 2, "a generation in fewer than two resumes")
end)

-- ── no dynamic bucket key ──────────────────────────────────────────────────────────────────────

--- Every `Perf.Note(` call in `src` whose first argument is not a string literal, and every literal
--- key that is not declared. Comments are stripped first, so a documented bracket is not a call.
local function noteProblems(src, declared)
    local problems = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        local code = line:gsub("%-%-.*$", "")
        for arg in code:gmatch("Perf[.:]Note%(%s*([^,%)]*)") do
            local key = arg:match('^"([%w_]+)"$') or arg:match("^'([%w_]+)'$")
            if not key then
                problems[#problems + 1] = "a non-literal key: " .. arg
            elseif not declared[key] then
                problems[#problems + 1] = "an undeclared key: " .. key
            end
        end
    end
    return problems
end

test("perf: no shipped file notes a dynamic or undeclared bucket key", function()
    local declared = {}
    for _, key in ipairs(BUCKETS) do declared[key] = true end
    -- The scanner itself first, or an empty scan proves nothing.
    -- red under: a scanner that matches no call (both samples come back clean).
    assertEqual(#noteProblems('if t0 then Perf.Note(id, debugprofilestop() - t0) end', declared), 1)
    assertEqual(#noteProblems('Perf.Note("bagSyncX", 1)', declared), 1)
    assertEqual(#noteProblems('Perf.Note("bagSync", 1) -- Perf.Note(id)', declared), 0)
    for _, rel in ipairs(T.loadedAddonFiles) do
        local f = assert(io.open(T.root .. "/" .. rel, "rb"))
        local src = f:read("*a")
        f:close()
        local problems = noteProblems(src, declared)
        assertEqual(#problems, 0, rel .. ": " .. table.concat(problems, "; "))
    end
end)

-- ── the perf hold ──────────────────────────────────────────────────────────────────────────────

--- The registrations an instance holds for one event, on `target` (the addon object): a module that
--- lands its own registration of the same event (Inventory's BAG_UPDATE, P4.5) is not the stand-in's.
local function regsFor(mocks, event, target)
    local n = 0
    for _, reg in ipairs(mocks.__registrations()) do
        if reg.event == event and reg.target == target then n = n + 1 end
    end
    return n
end

test("perf: Suspend takes the perf hold and stands the addon down; Resume stands it back up", function()
    -- red under: a standDown that skips addon:UnregisterAllEvents or NS.BusStandDown, or a Resume
    -- path that never reaches NS.BusStandUp / NS.RegisterGameEvents.
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local calls = {}
    local realDown, realUp = NS.BusStandDown, NS.BusStandUp
    NS.BusStandDown = function() calls[#calls + 1] = "busDown"; return realDown() end
    NS.BusStandUp = function(...) calls[#calls + 1] = "busUp"; return realUp(...) end
    -- What the scaffold has no game events of its own to show: one registration, rebuilt on stand-up.
    NS.RegisterGameEvents = function()
        calls[#calls + 1] = "events"
        NS.addon:RegisterEvent("BAG_UPDATE", function() end)
    end
    NS.RegisterGameEvents()
    calls = {}
    assertEqual(regsFor(M, "BAG_UPDATE", NS.addon), 1, "the baseline holds no registration; nothing below can fail")

    assertFalse(NS.IsStoodDown())
    assertNil(NS.StoodDownRefusal(), "a refusal while standing up")
    assertTrue(NS.Perf.Suspend(), "Suspend refused")
    assertTrue(NS.Perf.suspended, "the harness does not read the latch")
    assertTrue(NS.lifecycle:IsHeld(NS.HOLD_PERF))
    assertTrue(NS.IsStoodDown())
    assertFalse(NS.IsDisabled(), "the perf hold reads as the disabled hold")
    assertEqual(regsFor(M, "BAG_UPDATE", NS.addon), 0, "a registration survived the perf hold")
    assertEqual(NS.StoodDownRefusal(), "Not available during a performance capture.")
    assertFalse(NS.Perf.Suspend(), "a second Suspend took the hold twice")

    assertTrue(NS.Perf.Resume(), "Resume refused")
    assertFalse(NS.IsStoodDown())
    assertEqual(regsFor(M, "BAG_UPDATE", NS.addon), 1, "Resume did not rebuild the registrations")
    assertEqual(table.concat(calls, ","), "busDown,busUp,events")
end)

test("perf: the disabled hold outlasts the perf hold, and its refusal wins", function()
    -- red under: an ApplyEnabled or a Resume that calls standUp directly instead of releasing a hold.
    local NS = T.load().NS
    assertTrue(NS.Perf.Suspend())
    NS.ApplyEnabled(false)
    assertTrue(NS.IsDisabled())
    assertEqual(NS.StoodDownRefusal(),
        "Ka0s Outfitter Reborn is disabled \226\128\148 enable it with |cFFFFFF00/of enable|r",
        "the capture line answered while the addon is disabled")
    assertTrue(NS.Perf.Resume())
    assertTrue(NS.IsStoodDown(), "releasing perf stood a disabled addon up")
    NS.ApplyEnabled(true)
    assertFalse(NS.IsStoodDown())
    -- Until settings/Schema.lua lands there is no stored switch, and it reads as on.
    NS.SyncEnabledHold()
    assertFalse(NS.IsDisabled())
end)

-- Design §5.12, in stand-down order: jobs that want to equip cancel before the engine resets, and
-- States resumes before TriggerBinder binds on the way up (the reverse walk).
local MODULES = {
    "Preview", "TriggerBinder", "States", "Optimize", "Companion", "EM", "Equip", "Stack",
    "Outfits", "Inventory", "PlayerState", "Stats", "Tooltips", "Compare", "QuickSlots", "Bar",
    "Dock", "SlotEnables", "Dialogs", "IconChooser",
}

test("lifecycle: the module list is design §5.12's, in its order", function()
    local list = T.load().NS.LIFECYCLE_MODULES
    assertEqual(#list, #MODULES, "the module list's length")
    for i, name in ipairs(MODULES) do assertEqual(list[i], name, "position " .. i) end
end)

test("lifecycle: the module walk is top to bottom down, bottom to top up, and skips a missing module", function()
    -- red under: an unguarded NS[m].Suspend() (the missing module raises), or a forward stand-up walk.
    local NS = T.load().NS
    local seen = {}
    local function module(name)
        return {
            Suspend = function() seen[#seen + 1] = "down:" .. name end,
            Resume = function() seen[#seen + 1] = "up:" .. name end,
        }
    end
    NS.TestFirst, NS.TestBare, NS.TestLast = module("first"), {}, module("last")
    -- The real list is swapped out for the four probes and put back, so the order seen is theirs alone.
    local list, saved = NS.LIFECYCLE_MODULES, {}
    for i = #list, 1, -1 do saved[i], list[i] = list[i], nil end
    list[1], list[2], list[3], list[4] = "TestFirst", "TestMissing", "TestBare", "TestLast"
    local ok, err = pcall(function()
        NS.lifecycle:Hold(NS.HOLD_PERF)
        NS.lifecycle:Release(NS.HOLD_PERF)
    end)
    for i = #list, 1, -1 do list[i] = nil end
    for i = 1, #saved do list[i] = saved[i] end
    if not ok then error(err, 0) end
    assertEqual(table.concat(seen, ","), "down:first,down:last,up:last,up:first")
end)

-- ── the library-absent arm ─────────────────────────────────────────────────────────────────────

test("lifecycle: without the library the stub latch keeps both holds and the Perf stub is inert", function()
    local inst = T.load{ libFiles = {} }
    local NS = inst.NS
    assertEqual(NS.HOLD_DISABLED, "disabled")
    assertEqual(NS.HOLD_PERF, "perf")
    assertTrue(NS.Lifecycle == NS.lifecycle)
    assertTrue(NS.lifecycle:Hold(NS.HOLD_PERF), "the first hold is an edge")
    assertFalse(NS.ApplyEnabled(false), "a second hold is no edge")
    assertEqual(table.concat(NS.lifecycle:Holds(), ","), "disabled,perf")
    assertFalse(NS.lifecycle:Release(NS.HOLD_PERF), "released while another hold is taken")
    assertTrue(NS.IsStoodDown())
    assertTrue(NS.ApplyEnabled(true), "the last release is an edge")
    assertFalse(NS.IsStoodDown())

    assertFalse(NS.Perf.on)
    assertFalse(NS.Perf.suspended)
    NS.Perf.Note("bagSync", 1)
    local lines = NS.Perf.OnCommand()
    assertTrue(lines[1]:find("LibKa0s library is missing", 1, true) ~= nil, "the stub's verb names no cause")
end)
