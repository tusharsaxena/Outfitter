-- tests/perf.lua — the offline scenario runner (performance-§9, testing-§7).
--
--   lua tests/perf.lua [--out <path>] [--label <text>]
--
-- OUTSIDE THE GREEN GATE: `lua tests/run.lua` never runs it, and no commit depends on it. It asserts
-- only deterministic quantities, bytes allocated per iteration and bracket notes per iteration, each
-- measured loop isolated by a full collect on either side with the collector stopped inside it.
-- Timings are printed for orientation only: compare scenarios within a run, never across machines.
--
-- THE SCENARIOS (P4.31), each measured with capture OFF and ON on a whole addon of its own. Their
-- drivers are tests/perf_scenes.lua's, which tests/test_perf_harness.lua proves reach their buckets:
--   equipPlan      full-bag plan: one E.Update with one change, its events and Inv.Sync
--                  (equipUpdate, equipExecute, bagSync)
--   zoneFlips      50 BG zone flips through the zone producer (zoneUpdate; the battleground
--                  outfit's binding dispatches on each state edge, triggerDispatch)
--   triggerFanout  one PLAYER_UPDATE_RESTING edge through 40 bindings (triggerDispatch)
--   tooltips       the "Used by outfits" line on 100 bag items (tooltipUsedBy)
--   gaGeneration   one genetic generation, 275 children over whole resumes (optimizeStep)
--   dockIdle       the docked window shown with nothing changing: one States poll tick and one
--                  follow tick (dockFollow); the idle bracket announces nothing, so nothing redraws
-- and THE INSTRUMENTATION-ABSENT ARM (performance-§9): tooltipsAbsent, the tooltips step on an
-- instance whose Tooltips.OnItem has no bracket at all (Scenes.ABSENT), measured with capture off.
-- tooltipsCaptureOff must allocate no more than it: the off/on pair cannot show "free when off", since
-- a dormant bracket that allocates pays the same bytes in both halves.
-- With a ceiling per scenario in BYTE_CEILING and a pinned note count in NOTES_PER_ITER. A ceiling
-- sits a little above the measured figure; raise one only by re-measuring and saying why: a rise is
-- the finding.
--
-- CEILINGS. Measured 2026-11-04 on Lua 5.1, identical over repeat runs and in both halves of every
-- pair bar an occasional one-off in an off window (Scenes.PAIR_WINDOW_BYTES): equipPlan 224208, zoneFlips 118023, triggerFanout 104748, tooltips 138494, gaGeneration
-- 468127 bytes/iter. Each ceiling is about 2% over its figure. zoneFlips (149134) and triggerFanout
-- (119534) were re-measured when the Equip bracket stopped allocating: each zone flip and each binding
-- dispatch runs through E.Batch, so the old vararg table and two xpcall closures were in every call. The figures are large because a step
-- is a whole path on the real addon (an equipment update builds its change list and moves items
-- through mock_gear; a generation breeds 275 children) and include the mocks' own recording.
-- dockIdle is the exception, 192 bytes/iter: 96 the follow tick and 96 Scenes.quiet's own list; the
-- poll's E.Batch bracket allocates nothing (it cost 344 with the vararg table and two xpcall closures that
-- modules/Equip.lua's run used to build). With the C-01 gate reverted the idle bracket redraws the
-- window and the step costs about 180 KB. Its 200 ceiling holds the idle window quiet and the bracket
-- allocation-free.
--
-- ITERATIONS. ITERS[scene] steps per measured loop (N when absent): a step of the zone, fan-out,
-- tooltip and genetic scenes is 40 to 275 calls of its path, so they take fewer steps.
-- gaGeneration's step makes only 3 bracket calls, so it runs 200 steps: the off-side window
-- allowance spread over a window's calls must stay under Scenes.SMALLEST_ALLOC bytes a call, or a
-- per-call allocation could hide in it (Scenes.pairFailures refuses the pair).
--
-- WHAT THE BYTES INCLUDE. The mocks record as they go (M.__timers takes a queue entry per armed
-- timer, mock_gear its event queue per move, the printed list each chat line), so a figure is the
-- addon's allocation plus the recorder's, the same in both halves of a pair.

local root = (arg and arg[0] and arg[0]:match("^(.*)/tests/perf%.lua$")) or "."
package.path = root .. "/tests/?.lua;" .. package.path

local Loader  = dofile(root .. "/tests/_kit/loader.lua")
local mockmod = assert(loadfile(root .. "/tests/wow_mock.lua"))(root)
Loader.addonName = "OutfitterReborn"

local N = 2000
local USAGE = "usage: lua tests/perf.lua [--out <path>] [--label <text>]\n"

local ITERS = { equipPlan = 500, zoneFlips = 50, triggerFanout = 100, tooltips = 50, gaGeneration = 200 }

-- Per scenario: the bytes/iter ceiling and the bracket notes/iter it is pinned at.
local BYTE_CEILING = {
    equipPlanCaptureOff = 229000, equipPlanCaptureOn = 229000,
    zoneFlipsCaptureOff = 120500, zoneFlipsCaptureOn = 120500,         -- red under: run()'s vararg table and xpcall closures
    triggerFanoutCaptureOff = 107000, triggerFanoutCaptureOn = 107000, -- red under: the same
    tooltipsCaptureOff = 141000, tooltipsCaptureOn = 141000, tooltipsAbsent = 141000,
    gaGenerationCaptureOff = 478000, gaGenerationCaptureOn = 478000,
    dockIdleCaptureOff = 200, dockIdleCaptureOn = 200,         -- red under: reverting C-01's st.touched gate, or run()'s vararg table
}
local NOTES_PER_ITER = {
    equipPlanCaptureOff = 0, equipPlanCaptureOn = 3,            -- equipUpdate, equipExecute, bagSync
    zoneFlipsCaptureOff = 0, zoneFlipsCaptureOn = 100,          -- 50 zoneUpdate, 50 triggerDispatch
    triggerFanoutCaptureOff = 0, triggerFanoutCaptureOn = 40,   -- one triggerDispatch per binding
    tooltipsCaptureOff = 0, tooltipsCaptureOn = 100,            -- one tooltipUsedBy per item
    tooltipsAbsent = 0,                                         -- no bracket to note
    gaGenerationCaptureOff = 0, gaGenerationCaptureOn = 3,      -- three 100-child resumes
    dockIdleCaptureOff = 0, dockIdleCaptureOn = 1,              -- one dockFollow per follow tick
}
-- The capture-off/capture-on pairs, judged by Scenes.pairFailures (tests/perf_scenes.lua, where the
-- slack, the noise and the off-side window allowance live and the harness suite pins them).
local PAIRS = {
    equipPlanCaptureOff = "equipPlanCaptureOn", zoneFlipsCaptureOff = "zoneFlipsCaptureOn",
    triggerFanoutCaptureOff = "triggerFanoutCaptureOn", tooltipsCaptureOff = "tooltipsCaptureOn",
    gaGenerationCaptureOff = "gaGenerationCaptureOn", dockIdleCaptureOff = "dockIdleCaptureOn",
}

local opts = { out = nil, label = "offline" }
do
    local i = 1
    while arg and arg[i] do
        local a = arg[i]
        if a == "--out" and arg[i + 1] then opts.out = arg[i + 1]; i = i + 2
        elseif a == "--label" and arg[i + 1] then opts.label = arg[i + 1]; i = i + 2
        else
            io.stderr:write("unknown argument: " .. tostring(a) .. "\n")
            io.stderr:write(USAGE)
            os.exit(2)
        end
    end
end

-- ── environment ─────────────────────────────────────────────────────────────────────────────────
-- Both load lists are DERIVED (testing-§9): the library's from LibKa0s.xml, the addon's from the TOC,
-- so this runner measures what the client loads and never a hand-kept list.

local LIB_FILES = Loader.xmlFiles(root .. "/libs/LibKa0s/LibKa0s.xml")
local ADDON_REL = Loader.tocFiles(root .. "/OutfitterReborn.toc")
local ADDON_FILES = {}
for i, rel in ipairs(ADDON_REL) do ADDON_FILES[i] = root .. "/" .. rel end

--- `strip.file`'s source with every line matching one of `strip.patterns` blanked (its line ending
--- kept, so line numbers stay). Each pattern must match exactly one line: one that matches nothing
--- has gone stale, and the "absent" instance would be the bracketed one.
local function stripped(strip)
    local src = Loader.readFile(root .. "/" .. strip.file)
    local hits = {}
    src = src:gsub("([^\n]*)(\n?)", function(line, nl)
        for i, pat in ipairs(strip.patterns) do
            if line:find(pat) then
                hits[i] = (hits[i] or 0) + 1
                return nl
            end
        end
    end)
    for i, pat in ipairs(strip.patterns) do
        assert(hits[i] == 1, ("%s: the strip pattern %q matched %d lines, not 1"):format(strip.file, pat, hits[i] or 0))
    end
    return src
end

-- The addon's load, the TOC's files in order, with `strip.file` (when given) loaded stripped.
local function loadAddon(NS, mocks, strip)
    local found = false
    for i, rel in ipairs(ADDON_REL) do
        if strip and rel == strip.file then
            found = true
            Loader.loadSource(stripped(strip), "@" .. ADDON_FILES[i], NS, mocks)
        else
            Loader.load(ADDON_FILES[i], NS, mocks)
        end
    end
    assert(found or not strip, "the strip names a file the TOC does not load")
end

-- The client's load and login, as tests/run.lua's T.load gives it: `o.mutate(mocks)` runs before
-- anything loads, and PLAYER_LOGIN reaches the skin library's retry frame beside OnEnable. `o.strip`
-- is the instrumentation-absent arm's source transform (Scenes.ABSENT).
local function loadInstance(o)
    o = o or {}
    local mocks = mockmod.build()
    if o.mutate then o.mutate(mocks) end
    mocks._G = Loader.makeEnv(mocks)
    _G.OutfitterRebornDB, _G.OutfitterRebornPerfDB = nil, nil
    local NS = {}
    Loader.loadAll(LIB_FILES, NS, mocks)
    loadAddon(NS, mocks, o.strip)
    local AceAddon = mocks.LibStub("AceAddon-3.0")
    AceAddon:InitializeAddon(NS)
    local skin = mocks.LibStub("LibKa0s-Skin-1.0", true)
    local retry = skin and skin.__euiEventFrame
    if retry and retry.__fire then retry:__fire("OnEvent", "PLAYER_LOGIN") end
    AceAddon:EnableAddon(NS)
    if mocks.__fireTimers then mocks.__fireTimers() end
    return { NS = NS, mocks = mocks }
end

local Scenes = dofile(root .. "/tests/perf_scenes.lua")({ root = root, load = loadInstance })
local NS = loadInstance().NS

local failures = {}
local function check(ok, msg) if not ok then failures[#failures + 1] = msg end end

check(NS.Perf.BuildRecord ~= nil, "NS.Perf is the degradation stub: every scenario would measure a stub")

-- Count the bracket's notes without allocating: a counter, not a list. Each scene's instance gets the
-- counter on its own NS.Perf.
local notes = 0
local function countNotes(perf)
    local real = perf.Note
    perf.Note = function(key, ms, parent)
        notes = notes + 1
        return real(key, ms, parent)
    end
end

local results = {}

-- The warm-up and the measured loop run through this one function, at the same stack depth.
local function loop(n, fn)
    for _ = 1, n do fn() end
end

-- A step this large either way is a table rehashing with the collector stopped, far past anything
-- one step of a scenario allocates (the heaviest, gaGeneration, is about 480 KB): skipped, so it
-- bills neither half of a pair.
local REHASH_KB = 1024

--- Run `fn` n times after a warm-up of the same length, the collector stopped inside the loop. A
--- second warm-up with the collector stopped keeps nothing and lets a table that only grows while it
--- is stopped reach its size there, so neither half of a pair is billed for that rehash.
local function measure(name, n, fn)
    loop(n, fn)
    collectgarbage("collect"); collectgarbage("stop")
    loop(n, fn)
    collectgarbage("restart")
    notes = 0
    collectgarbage("collect"); collectgarbage("collect")
    collectgarbage("stop")
    local grown, last = 0, collectgarbage("count")
    local t0 = os.clock()
    for _ = 1, n do
        fn()
        local now = collectgarbage("count")
        local step = now - last
        if step > 0 and step < REHASH_KB then grown = grown + step end
        last = now
    end
    local t1 = os.clock()
    collectgarbage("restart")
    results[#results + 1] = {
        name = name, iterations = n, totalMs = (t1 - t0) * 1000, msPerIter = (t1 - t0) * 1000 / n,
        notesPerIter = notes / n, bytesPerIter = grown * 1024 / n,
    }
end

--- One stopped-collector pass in each capture mode, recording nothing: the first window measured on
--- a fresh scene came in heavier than the later ones (triggerFanout by 3 bytes/iter), so the scene is
--- settled before either half is measured.
local function settle(perf, n, fn)
    for _, on in ipairs({ false, true }) do
        perf.on = on
        collectgarbage("collect"); collectgarbage("stop")
        loop(n, fn)
        collectgarbage("restart")
    end
end

--- One scenario measured with capture off, then on, on the instance `perf` belongs to.
local function pair(perf, base, n, fn)
    settle(perf, n, fn)
    perf.on = false
    measure(base .. "CaptureOff", n, fn)
    perf.on = true
    measure(base .. "CaptureOn", n, fn)
    perf.on = false
end

-- ── scenarios ───────────────────────────────────────────────────────────────────────────────────

for _, name in ipairs(Scenes.PERF) do
    local ok, step, sceneNS = pcall(Scenes[name])
    check(ok, ("the %s scene did not build: %s"):format(name, tostring(step)))
    if ok then
        check(sceneNS.Perf.BuildRecord ~= nil, name .. ": NS.Perf is the degradation stub")
        countNotes(sceneNS.Perf)
        local ran, err = pcall(pair, sceneNS.Perf, name, ITERS[name] or N, step)
        check(ran, ("the %s scene raised: %s"):format(name, tostring(err)))
    end
end

-- The instrumentation-absent arm: settled like a pair, measured with capture off. A short pass with
-- capture on first proves the strip took the bracket (the bracketed file notes 100 times a step).
do
    local ok, step, sceneNS = pcall(Scenes.tooltipsAbsent)
    check(ok, ("the tooltipsAbsent scene did not build: %s"):format(tostring(step)))
    if ok then
        local perf = sceneNS.Perf
        countNotes(perf)
        local ran, err = pcall(function()
            settle(perf, ITERS.tooltips, step)
            notes = 0
            perf.on = true
            step()
            perf.on = false
            check(notes == 0, ("tooltipsAbsent noted %d times with capture on: the strip left a bracket"):format(notes))
            measure("tooltipsAbsent", ITERS.tooltips, step)
        end)
        perf.on = false
        check(ran, ("the tooltipsAbsent scene raised: %s"):format(tostring(err)))
    end
end

for _, r in ipairs(results) do
    local ceiling = BYTE_CEILING[r.name]
    check(ceiling ~= nil and r.bytesPerIter <= ceiling,
        ("%s allocated %.1f bytes/iter, over its %s-byte ceiling"):format(r.name, r.bytesPerIter, tostring(ceiling)))
    local want = NOTES_PER_ITER[r.name]
    check(want ~= nil and math.abs(r.notesPerIter - want) < 1e-9,
        ("%s noted %.2f times/iter, pinned at %s"):format(r.name, r.notesPerIter, tostring(want)))
end

local byName = {}
for _, r in ipairs(results) do byName[r.name] = r end
for offName, onName in pairs(PAIRS) do
    local off, on = byName[offName], byName[onName]
    check(off ~= nil and on ~= nil, ("the pair %s / %s was not measured"):format(offName, onName))
    if off and on then
        for _, msg in ipairs(Scenes.pairFailures((offName:gsub("CaptureOff$", "")), off, on)) do check(false, msg) end
    end
end

-- Capture off against no instrumentation at all: the zero-overhead evidence (performance-§2, §9).
-- red under: a table built beside the dormant t0 in Tooltips.OnItem, on its line
-- (`local t0 = Perf.on and debugprofilestop(); local probe = { link }`).
do
    local off, absent = byName.tooltipsCaptureOff, byName.tooltipsAbsent
    check(off ~= nil and absent ~= nil, "the tooltips capture-off / instrumentation-absent pair was not measured")
    if off and absent and off.bytesPerIter > absent.bytesPerIter + Scenes.PAIR_NOISE then
        check(false, ("tooltipsCaptureOff allocated %.1f bytes/iter, more than tooltipsAbsent's %.1f: the dormant bracket is not free")
            :format(off.bytesPerIter, absent.bytesPerIter))
    end
end

-- ── report ──────────────────────────────────────────────────────────────────────────────────────

print(("Ka0s Outfitter Reborn \226\128\148 offline perf  (v%s, label '%s')"):format(tostring(NS.Version()), opts.label))
print()
-- Five columns, exactly: tests/_kit/run-automated-tests.sh counts scenarios structurally as the
-- five-field rows under this header.
print(("%-24s %8s %11s %10s %11s"):format("scenario", "iters", "ms/iter", "notes/iter", "bytes/iter"))
for _, r in ipairs(results) do
    print(("%-24s %8d %11.5f %10.2f %11.1f"):format(r.name, r.iterations, r.msPerIter, r.notesPerIter, r.bytesPerIter))
end
print()
print("timings are for orientation only \226\128\148 compare scenarios within a run, never across machines")
if #failures > 0 then
    print()
    print(("%d assertion%s FAILED:"):format(#failures, #failures == 1 and "" or "s"))
    for _, msg in ipairs(failures) do print("  - " .. msg) end
end

-- ── the record ──────────────────────────────────────────────────────────────────────────────────

local function writeRecord(path)
    local buckets = {}
    for _, r in ipairs(results) do
        buckets[r.name] = { calls = r.iterations, totalMs = r.totalMs, maxMs = r.msPerIter,
                            notesPerIter = r.notesPerIter, bytesPerIter = r.bytesPerIter }
    end
    local fh, err = io.open(path, "w")
    if not fh then
        io.stderr:write("cannot write " .. path .. ": " .. tostring(err) .. "\n")
        os.exit(2)
    end
    fh:write(NS.Perf.EncodeJSON({
        schema = 1, addon = "OutfitterReborn", source = "offline",
        version = tostring(NS.Version()), interface = 0, timestamp = os.time(),
        label = opts.label, buckets = buckets, failures = failures,
    }), "\n")
    fh:close()
    print("wrote " .. path)
end

if opts.out then writeRecord(opts.out) end

os.exit(#failures == 0 and 0 or 1)
