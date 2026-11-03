-- tests/test_perf_harness.lua — the performance harness's wiring and the latch it stands the addon
-- down through (design §2.1, §5.12; performance-§1/§3/§6, testing-§8). The P3 C10 part: the ten
-- buckets declared in order with the one declared nesting, the descriptor's single teardown path, no
-- dynamic bucket key anywhere in the shipped source, and the perf hold making the addon inert. The
-- "every bucket is reached" case is a declared skip until P4.31, when the ten bracketed paths exist.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- Design §2.1, in declaration order.
local BUCKETS = {
    "auraScan", "zoneUpdate", "bagSync", "equipUpdate", "equipExecute", "triggerDispatch",
    "optimizeStep", "dockFollow", "barRender", "tooltipUsedBy",
}

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

test("perf: every declared bucket is reached, and equipExecute only within equipUpdate", function()
end, "P4.31: the ten bracketed paths (design §2.1) land in P4; the drivers are written with them")

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

--- The registrations an instance holds for one event.
local function regsFor(mocks, event)
    local n = 0
    for _, reg in ipairs(mocks.__registrations()) do
        if reg.event == event then n = n + 1 end
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
    assertEqual(regsFor(M, "BAG_UPDATE"), 1, "the baseline holds no registration; nothing below can fail")

    assertFalse(NS.IsStoodDown())
    assertNil(NS.StoodDownRefusal(), "a refusal while standing up")
    assertTrue(NS.Perf.Suspend(), "Suspend refused")
    assertTrue(NS.Perf.suspended, "the harness does not read the latch")
    assertTrue(NS.lifecycle:IsHeld(NS.HOLD_PERF))
    assertTrue(NS.IsStoodDown())
    assertFalse(NS.IsDisabled(), "the perf hold reads as the disabled hold")
    assertEqual(regsFor(M, "BAG_UPDATE"), 0, "a registration survived the perf hold")
    assertEqual(NS.StoodDownRefusal(), "Not available during a performance capture.")
    assertFalse(NS.Perf.Suspend(), "a second Suspend took the hold twice")

    assertTrue(NS.Perf.Resume(), "Resume refused")
    assertFalse(NS.IsStoodDown())
    assertEqual(regsFor(M, "BAG_UPDATE"), 1, "Resume did not rebuild the registrations")
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
    local list = NS.LIFECYCLE_MODULES
    assertEqual(#list, 0, "P3 declares no module; P4.0 fills the list")
    list[1], list[2], list[3], list[4] = "TestFirst", "TestMissing", "TestBare", "TestLast"
    local ok, err = pcall(function()
        NS.lifecycle:Hold(NS.HOLD_PERF)
        NS.lifecycle:Release(NS.HOLD_PERF)
    end)
    for i = #list, 1, -1 do list[i] = nil end
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
