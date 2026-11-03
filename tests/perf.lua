-- tests/perf.lua — the offline scenario runner (performance-§9, testing-§7).
--
--   lua tests/perf.lua [--out <path>] [--label <text>]
--
-- OUTSIDE THE GREEN GATE: `lua tests/run.lua` never runs it, and no commit depends on it. It asserts
-- only deterministic quantities, bytes allocated per iteration and bracket notes per iteration, each
-- measured loop isolated by a full collect on either side with the collector stopped inside it.
-- Timings are printed for orientation only: compare scenarios within a run, never across machines.
--
-- THE SKELETON (P3 C10). The environment, the measuring loop, the report and the record are here;
-- the SCENARIOS are not, because none of the bracketed paths exists yet (core/PerfSetup.lua declares
-- the ten buckets ahead of them). P4.31 adds them, each measured with capture OFF and ON:
--   full-bag plan                 E.Update over a full bag set (equipUpdate, equipExecute, bagSync)
--   50 BG zone flips              the debounced zone producer (zoneUpdate)
--   trigger fan-out, 40 outfits   one state change through Binder.Dispatch (triggerDispatch)
--   tooltip on 100 bag items      Tooltips.OnItem past its gates (tooltipUsedBy)
--   one genetic generation        the optimizer's coroutine resumes (optimizeStep)
-- with a ceiling per scenario in BYTE_CEILING and a pinned note count in NOTES_PER_ITER. A ceiling
-- sits a little above the measured figure; raise one only by re-measuring and saying why.

local root = (arg and arg[0] and arg[0]:match("^(.*)/tests/perf%.lua$")) or "."
package.path = root .. "/tests/?.lua;" .. package.path

local Loader  = dofile(root .. "/tests/_kit/loader.lua")
local mockmod = assert(loadfile(root .. "/tests/wow_mock.lua"))(root)
Loader.addonName = "OutfitterReborn"

local N = 2000
local USAGE = "usage: lua tests/perf.lua [--out <path>] [--label <text>]\n"

-- Per scenario: the bytes/iter ceiling and the bracket notes/iter it is pinned at. Empty until P4.31.
local BYTE_CEILING = {}
local NOTES_PER_ITER = {}
-- The capture-off/capture-on pairs: off may allocate nothing over on, and on no more than PAIR_SLACK
-- over off (the zero-overhead evidence performance-§2 asks for).
local PAIRS = {}
local PAIR_SLACK = 64
local PAIR_NOISE = 1

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
local ADDON_FILES = {}
for i, rel in ipairs(Loader.tocFiles(root .. "/OutfitterReborn.toc")) do ADDON_FILES[i] = root .. "/" .. rel end

local function loadInstance()
    local mocks = mockmod.build()
    mocks._G = Loader.makeEnv(mocks)
    _G.OutfitterRebornDB, _G.OutfitterRebornPerfDB = nil, nil
    local NS = {}
    Loader.loadAll(LIB_FILES, NS, mocks)
    Loader.loadAll(ADDON_FILES, NS, mocks)
    local AceAddon = mocks.LibStub("AceAddon-3.0")
    AceAddon:InitializeAddon(NS)
    AceAddon:EnableAddon(NS)
    if mocks.__fireTimers then mocks.__fireTimers() end
    return { NS = NS, mocks = mocks }
end

local NS = loadInstance().NS

local failures = {}
local function check(ok, msg) if not ok then failures[#failures + 1] = msg end end

check(NS.Perf.BuildRecord ~= nil, "NS.Perf is the degradation stub: every scenario would measure a stub")

-- Count the bracket's notes without allocating: a counter, not a list.
local notes = 0
local realNote = NS.Perf.Note
NS.Perf.Note = function(key, ms, parent)
    notes = notes + 1
    return realNote(key, ms, parent)
end

local results = {}

-- The warm-up and the measured loop run through this one function, at the same stack depth.
local function loop(n, fn)
    for _ = 1, n do fn() end
end

-- A step this large either way is a table rehashing with the collector stopped, far past anything
-- one call of a bracketed path allocates: skipped, so it bills neither half of a pair.
local REHASH_KB = 64

--- Run `fn` n times after a warm-up of the same length, the collector stopped inside the loop.
local function measure(name, n, fn)
    loop(n, fn)
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

--- One scenario measured with capture off, then on. P4.31's scenarios call this.
local function pair(base, fn)
    NS.Perf.on = false
    measure(base .. "CaptureOff", N, fn)
    NS.Perf.on = true
    measure(base .. "CaptureOn", N, fn)
    NS.Perf.on = false
end
local _ = pair

-- ── scenarios ───────────────────────────────────────────────────────────────────────────────────
-- None yet (P4.31; see the header).

NS.Perf.Note = realNote

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
        check(off.bytesPerIter <= on.bytesPerIter + PAIR_NOISE,
            ("%s allocated %.1f bytes/iter, more than %s's %.1f: the off bracket is not free"):format(
                offName, off.bytesPerIter, onName, on.bytesPerIter))
        check(on.bytesPerIter <= off.bytesPerIter + PAIR_SLACK,
            ("%s allocated %.1f bytes/iter, over %s's %.1f by more than %d"):format(
                onName, on.bytesPerIter, offName, off.bytesPerIter, PAIR_SLACK))
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
if #results == 0 then print("no scenarios yet \226\128\148 they land with the bracketed paths (P4.31)") end
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
