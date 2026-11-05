-- tests/test_optimize.lua — P4.12 (design §5.14, B7, B15, B16): modules/Optimize.lua's smart-outfit
-- driver (the simple greedy search, Trial, Rebuild, Cancel, Suspend) and modules/Optimize_Genetic.lua's
-- genetic search, run on a seeded RNG so every case is deterministic.
--
-- The simple picks are pinned against tests/fixtures/legacy/plans.lua's `smart` cases (captured from
-- OutfitterOptimize.lua:114 at 7ea3dc3). Most cases score through a recorded stand-in for NS.Stats, so
-- a case states its scores rather than deriving them from item stats; one case runs the real Stats
-- and Inventory on the geared scenario.
--
-- THE FAKE RULE (design §12). NS.EM lands in P4.10, in the same group: Rebuild's EM path runs against
-- a recorded fake. Rebuild's native wear is asserted on a recorded NS.Stack, since the Stack suite owns
-- what a wear does.

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- ── helpers ───────────────────────────────────────────────────────────────────────────────────

-- The Park-Miller minimal standard generator, shaped like math.random: rng() is in [0, 1), rng(m)
-- is an integer in 1..m. The products stay below 2^53, so Lua 5.1's doubles keep it exact.
local function lcg(seed)
    local s = seed
    return function(m)
        s = (s * 16807) % 2147483647
        local f = (s - 1) / 2147483646
        if m == nil then return f end
        return math.floor(f * m) + 1
    end
end

-- An item info the way the optimizer reads one: its slot and meta slot, already bound or not, usable.
local function item(id, invType, extra)
    local slotRow = assert(T.NS.ItemData.INVTYPE_TO_SLOT[invType], invType)
    local info = { id = id, name = "Item " .. id, invType = invType, slot = slotRow.slot, meta = slotRow.meta,
                   bind = "bound", usable = true }
    for k, v in pairs(extra or {}) do info[k] = v end
    return info
end

-- A recorded NS.Stats whose stats score from tables: defs = { STA = { [itemID] = score } }. A score
-- that is a function is called (a case can make it raise). An id with no entry scores nil: dropped.
local function fakeStats(NS, defs)
    local stats = {}
    for id, scores in pairs(defs) do
        stats[id] = { id = id, label = "Label " .. id, Score = function(_, info)
            local v = scores[info.id]
            if type(v) == "function" then return v() end
            return v
        end }
    end
    local function configName(cfg)
        local names = {}
        for i, row in ipairs(cfg) do
            if not stats[row.stat] then return nil end
            names[i] = stats[row.stat].label
        end
        return table.concat(names, ", ")
    end
    -- Suspend and Resume: a stand-down walks every module (core/LifecycleSetup.lua MODULES).
    T.fake(NS, "Stats", { Get = function(id) return stats[id] end, ConfigName = configName,
                          Suspend = true, Resume = true })
    return stats
end

-- slot -> item id, from what onDone delivered.
local function ids(items)
    local out = {}
    for slot, rec in pairs(items or {}) do out[slot] = rec.id end
    return out
end

local function sameMap(a, b, label)
    for k, v in pairs(a) do assertEqual(b[k], v, (label or "") .. " " .. k) end
    for k, v in pairs(b) do assertEqual(a[k], v, (label or "") .. " " .. k) end
end

-- Record every delivery: calls[i] = { items, reason }.
local function recorder()
    local calls = {}
    return calls, function(items, reason) calls[#calls + 1] = { items = items, reason = reason } end
end

local function hear(NS, key)
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG[key], function(_, ...) heard[#heard + 1] = { ... } end)
    return heard
end

-- Fire the timer queue until it runs dry (bounded: the ticker must end on its own).
local function drain(M)
    for _ = 1, 20000 do
        if M.__fireTimers() == 0 then return true end
    end
    return false
end

local function printedMatching(M, needle)
    local n = 0
    for _, line in ipairs(M.__printed()) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

-- The legacy FormatThousands, restated: "28075" -> "28,075", rounded to the nearest whole number.
local function thousands(n)
    local s = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (s:sub(1, 1) == ",") and s:sub(2) or s
end

local function run(NS, name, cfg, infos, opts)
    opts = opts or {}
    opts.cache = NS.Inventory.NewCache(infos)
    local calls, onDone = recorder()
    local job, err = NS.Optimize.Generate(name, cfg, opts, onDone)
    return calls, job, err
end

-- ── the simple search (legacy pins) ───────────────────────────────────────────────────────────

test("optimize: the simple picks equal the legacy smart fixtures (STA, ITEM_LEVEL)", function()
    -- red under: drop the BoE skip, the alternate-slot bump or the 2H-versus-pair compare (each breaks
    -- one fixture case). No fixture case depends on the ITEM_LEVEL list or the needsMainHand gate: each
    -- has its own case below.
    for _, case in ipairs(T.legacy.plans.smart) do
        local NS = unitLoad().NS
        local infos = {}
        for _, it in ipairs(case.items) do
            infos[#infos + 1] = item(it.code, it.invType, { slot = it.slot, meta = it.meta,
                                                           bind = it.boe and "boe" or "bound" })
        end
        fakeStats(NS, { [case.stat] = case.scores })
        local calls = run(NS, case.name, { { stat = case.stat } }, infos, { allowEmpty = true })
        assertEqual(#calls, 1, case.name .. ": delivered once")
        sameMap(ids(calls[1].items), case.output, case.name)
    end
end)

test("optimize: a better trinket bumps the current one to the alternate slot", function()
    -- red under: replace the current item without trying it in the alternate slot
    local NS = unitLoad().NS
    fakeStats(NS, { STA = { [21] = 3, [22] = 8, [23] = 5 } })
    local infos = { item(21, "INVTYPE_TRINKET"), item(22, "INVTYPE_TRINKET"), item(23, "INVTYPE_TRINKET") }
    local calls = run(NS, "t", { { stat = "STA" } }, infos)
    sameMap(ids(calls[1].items), { Trinket0Slot = 22, Trinket1Slot = 23 })
end)

test("optimize: ITEM_LEVEL never leaves the main hand empty where STA would", function()
    -- red under: give ITEM_LEVEL the STA combination list (the empty main hand wins the tie)
    local infos = function() return { item(31, "INVTYPE_WEAPON"), item(32, "INVTYPE_HOLDABLE") } end
    local NS = unitLoad().NS
    fakeStats(NS, { STA = { [31] = 0, [32] = 9 } })
    sameMap(ids(run(NS, "s", { { stat = "STA" } }, infos())[1].items), { SecondaryHandSlot = 32 }, "STA")
    NS = unitLoad().NS
    fakeStats(NS, { ITEM_LEVEL = { [31] = 0, [32] = 9 } })
    sameMap(ids(run(NS, "i", { { stat = "ITEM_LEVEL" } }, infos())[1].items),
        { MainHandSlot = 31, SecondaryHandSlot = 32 }, "ITEM_LEVEL")
end)

test("optimize: a dual wielder's only one-hander goes in the main hand, not the off hand", function()
    -- red under: drop pairAllowed's needsMainHand gate (the empty main hand and the weapon in the off
    -- hand comes first of the equal pairs)
    local NS = unitLoad().NS
    fakeStats(NS, { STA = { [61] = 5 } })
    sameMap(ids(run(NS, "one", { { stat = "STA" } }, { item(61, "INVTYPE_WEAPON") })[1].items),
        { MainHandSlot = 61 })
end)

test("optimize: a one-hander goes in the off hand only when the player can dual wield (B15)", function()
    -- red under: drop the PS.CanDualWield gate on the weapon-in-off-hand pairs
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    local infos = function() return { item(41, "INVTYPE_WEAPON"), item(42, "INVTYPE_WEAPON") } end
    fakeStats(NS, { STA = { [41] = 4, [42] = 6 } })
    sameMap(ids(run(NS, "dw", { { stat = "STA" } }, infos())[1].items),
        { MainHandSlot = 42, SecondaryHandSlot = 41 }, "dual wield")
    M.CanDualWield = function() return false end
    sameMap(ids(run(NS, "no", { { stat = "STA" } }, infos())[1].items), { MainHandSlot = 42 }, "no dual wield")
end)

test("optimize: an empty simple result is delivered as nil, \"empty\" unless empties are allowed", function()
    -- red under: drop deliverItems' empty check (the empty table is delivered when empties are not allowed)
    local NS = unitLoad().NS
    fakeStats(NS, { STA = {} })
    local calls = run(NS, "e", { { stat = "STA" } }, { item(51, "INVTYPE_HEAD") })
    assertEqual(#calls, 1)
    assertNil(calls[1].items)
    assertEqual(calls[1].reason, "empty")
    calls = run(NS, "e", { { stat = "STA" } }, { item(51, "INVTYPE_HEAD") }, { allowEmpty = true })
    assertEqual(next(calls[1].items), nil, "an allowed empty outfit is an empty table")
end)

-- ── the cfg ───────────────────────────────────────────────────────────────────────────────────

test("optimize: the cfg defaults to { { stat = \"STA\" } }, and a row with no stat reads STA", function()
    -- red under: a default cfg other than STA, or a nil cfg that raises
    local NS = unitLoad().NS
    fakeStats(NS, { STA = { [61] = 2 } })
    local calls, job = run(NS, "d", nil, { item(61, "INVTYPE_HEAD") })
    assertEqual(job.cfg[1].stat, "STA")
    assertFalse(job.complex, "the default is the simple search")
    sameMap(ids(calls[1].items), { HeadSlot = 61 })
    local _, job2 = run(NS, "d", { {} }, { item(61, "INVTYPE_HEAD") })
    assertEqual(job2.cfg[1].stat, "STA")
end)

test("optimize: an unknown stat returns nil and the message, and delivers nothing (B16: no nil)", function()
    -- red under: format the message from the cfg table rather than the row's stat (prints "nil")
    local NS = unitLoad().NS
    fakeStats(NS, { STA = {} })
    local calls, job, err = run(NS, "u", { { stat = "BOGUS" } }, {})
    assertNil(job)
    assertEqual(err, NS.L["Unknown stat ID: %s"]:format("BOGUS"))
    assertEqual(#calls, 0, "a refusal is returned, never delivered")
    local _, _, err2 = run(NS, "u", { { stat = 7 } }, {})
    assertEqual(err2, NS.L["Unknown stat ID: %s"]:format("7"))
    assertFalse(err2:find("nil", 1, true) ~= nil)
end)

test("optimize: complex is #cfg > 1, a min or a max, or a stat marked complex", function()
    -- red under: an isComplex that answers true (a single plain row goes to the genetic search)
    local NS = unitLoad().NS
    local stats = fakeStats(NS, { A = { [71] = 1 }, B = { [71] = 1 } })
    local function complex(cfg) local _, job = run(NS, "c", cfg, { item(71, "INVTYPE_HEAD") }) return job.complex end
    assertFalse(complex({ { stat = "A" } }))
    assertTrue(complex({ { stat = "A" }, { stat = "B" } }))
    assertTrue(complex({ { stat = "A", min = 5 } }))
    assertTrue(complex({ { stat = "A", max = 5 } }))
    stats.A.complex = true
    assertTrue(complex({ { stat = "A" } }))
    NS.Optimize.Cancel()
end)

-- ── delivery (B7) ─────────────────────────────────────────────────────────────────────────────

test("optimize: the result is delivered exactly once and never returned (B7)", function()
    -- red under: drop the job.done guard from both deliver and Opt.Cancel in modules/Optimize.lua (a
    -- finished job is delivered again)
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    fakeStats(NS, { STA = { [81] = 2 }, HAS = { [81] = 1 } })
    local calls, job = run(NS, "once", { { stat = "STA" } }, { item(81, "INVTYPE_HEAD") })
    assertNil(job.HeadSlot, "Generate returned the items")
    assertEqual(#calls, 1)
    NS.Optimize.Cancel(job)
    NS.Optimize.Suspend()
    assertEqual(#calls, 1, "a finished job was delivered again")
    local gcalls, gjob = run(NS, "ga", { { stat = "STA" }, { stat = "HAS" } }, { item(81, "INVTYPE_HEAD") },
        { rng = lcg(7) })
    assertEqual(#gcalls, 0, "the genetic search delivered synchronously")
    assertTrue(drain(M), "the ticker never ended")
    assertEqual(#gcalls, 1)
    NS.Optimize.Cancel(gjob)
    NS.Optimize.Suspend()
    assertTrue(drain(M))
    assertEqual(#gcalls, 1, "a finished genetic job was delivered again")
end)

-- ── live objects (B15) ────────────────────────────────────────────────────────────────────────

test("optimize: on the real Stats and Inventory the result holds item records, no live objects", function()
    -- red under: deliver the cache infos rather than NS.ItemInfo.Snapshot copies (loc, bind and the
    -- score cache would be saved into the outfit)
    local inst = unitLoad({ mutate = function(M) M.__gear:load("geared") end })
    local NS = inst.NS
    local got
    NS.Optimize.Generate("Stamina", { { stat = "STA" } }, {}, function(items) got = items end)
    assertTrue(got ~= nil and got.HeadSlot ~= nil, "no head picked")
    assertEqual(got.HeadSlot.id, T.fixtures.items.db.head_plate.id)
    local allowed = {}
    for k in pairs(NS.ItemInfo.Snapshot({ id = 1 })) do allowed[k] = true end
    for _, k in ipairs({ "id", "suffix", "enchant", "gems", "uid", "upType", "diff", "bonus", "mods", "azerite",
                         "link", "name", "invType", "quality", "level" }) do allowed[k] = true end
    for slot, rec in pairs(got) do
        assertNil(rec.loc, slot .. " carries its location")
        assertNil(rec.bind, slot .. " carries the bind cache")
        assertNil(rec.usable, slot .. " carries the usable cache")
        for k in pairs(rec) do assertTrue(allowed[k], slot .. " carries " .. tostring(k)) end
    end
end)

-- ── the genetic search ────────────────────────────────────────────────────────────────────────

-- Two heads, three rings and two one-handers, no off hand: the best outfit on A is the first head,
-- the two best rings and both weapons when the player dual wields.
local function gaInventory()
    return {
        item(101, "INVTYPE_HEAD"), item(102, "INVTYPE_HEAD"),
        item(111, "INVTYPE_FINGER"), item(112, "INVTYPE_FINGER"), item(113, "INVTYPE_FINGER"),
        item(121, "INVTYPE_WEAPON"), item(122, "INVTYPE_WEAPON"),
    }
end
local GA_SCORES = {
    A = { [101] = 5, [102] = 3, [111] = 2, [112] = 4, [113] = 1, [121] = 6, [122] = 5 },
    B = { [101] = 1, [102] = 4, [111] = 0, [112] = 0, [113] = 0, [121] = 0, [122] = 0 },
}
local GA_CFG = { { stat = "A" }, { stat = "B" } }

local function gaRun(seed, mutate)
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    if mutate then mutate(M) end
    fakeStats(NS, GA_SCORES)
    local progress = hear(NS, "OPTIMIZE_PROGRESS")
    M.__now = 100
    local calls, job = run(NS, "Best", GA_CFG, gaInventory(), { rng = lcg(seed) })
    M.__now = 104
    assertTrue(drain(M), "the ticker never ended")
    return { NS = NS, M = M, calls = calls, job = job, progress = progress }
end

-- The pair slots as a sorted pair, so "both rings" reads the same in either order.
local function pairOf(got, a, b)
    local x, y = got[a], got[b]
    if x and y and x > y then x, y = y, x end
    return tostring(x) .. "+" .. tostring(y)
end

test("optimize: the genetic search keeps the legacy constants (300/25/0.2/1000/100)", function()
    -- red under: change any constant in Optimize_Genetic.lua's PARAMS
    local P = T.NS.OptimizeGA.PARAMS
    assertEqual(P.population, 300)
    assertEqual(P.parents, 25)
    assertEqual(P.mutation, 0.2)
    assertEqual(P.maxGenerations, 1000)
    assertEqual(P.maxNoChange, 100)
end)

test("optimize: the genetic search finds the best outfit and is deterministic on a seeded RNG", function()
    -- red under: read math.random inside the search instead of the injected rng (the two runs differ)
    local a, b = gaRun(11), gaRun(11)
    assertEqual(#a.calls, 1)
    local got = ids(a.calls[1].items)
    assertEqual(got.HeadSlot, 101)
    assertEqual(pairOf(got, "Finger0Slot", "Finger1Slot"), "111+112")
    assertEqual(pairOf(got, "MainHandSlot", "SecondaryHandSlot"), "121+122", "a one-hander tried in the off hand (B15)")
    sameMap(got, ids(b.calls[1].items), "second run")
    assertEqual(#a.progress, #b.progress, "the runs took different generation counts")
    assertEqual(a.job.generated, b.job.generated)
end)

test("optimize: without dual wield the genetic search leaves the off hand empty (B15)", function()
    -- red under: drop the PS.CanDualWield gate on the off-hand candidate list
    local r = gaRun(5, function(M) M.CanDualWield = function() return false end end)
    local got = ids(r.calls[1].items)
    assertEqual(got.MainHandSlot, 121)
    assertNil(got.SecondaryHandSlot)
end)

test("optimize: a two-hander empties the off hand in the genetic search unless gripped", function()
    -- red under: drop the genetic search's ungripped two-hander rule (fixHands keeps the shield)
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    local scores = { A = { [131] = 10, [132] = 3 }, B = { [131] = 0, [132] = 0 } }
    fakeStats(NS, scores)
    local calls = run(NS, "2h", GA_CFG, { item(131, "INVTYPE_2HWEAPON"), item(132, "INVTYPE_SHIELD") }, { rng = lcg(3) })
    assertTrue(drain(M))
    local got = ids(calls[1].items)
    assertEqual(got.MainHandSlot, 131)
    assertNil(got.SecondaryHandSlot, "a shield beside an ungripped two-hander")
end)

test("optimize: ties favor empty slots (Q6)", function()
    -- red under: drop the empty-slot count from scoreWithEmpty (the zero-score head stays in)
    for _, seed in ipairs({ 1, 2, 3, 4, 5 }) do
        local inst = unitLoad()
        local NS, M = inst.NS, inst.mocks
        fakeStats(NS, { A = { [141] = 0, [142] = 3 }, B = { [141] = 0, [142] = 0 } })
        local calls = run(NS, "tie", GA_CFG, { item(141, "INVTYPE_HEAD"), item(142, "INVTYPE_NECK") },
            { rng = lcg(seed) })
        assertTrue(drain(M))
        local got = ids(calls[1].items)
        assertEqual(got.NeckSlot, 142, "seed " .. seed)
        assertNil(got.HeadSlot, "seed " .. seed .. ": a zero-score head beat an empty slot")
    end
end)

test("optimize: the compound compare honors min and max as the legacy did", function()
    -- red under: compare a min row as plain "higher is better"
    local cmp = T.NS.OptimizeGA.CompareCompound
    local MIN, MAX = { { min = 10 } }, { { max = 10 } }
    assertTrue(cmp({ 12 }, { 15 }, MIN), "both above the min: the closer one")
    assertTrue(cmp({ 15 }, { 5 }, MIN), "one below the min: the higher one")
    assertFalse(cmp({ 5 }, { 15 }, MIN))
    assertTrue(cmp({ 9 }, { 3 }, MAX), "both under the max: the higher one")
    assertTrue(cmp({ 3 }, { 12 }, MAX), "one over the max: the lower one")
    assertTrue(cmp({ 4, 2 }, { 4, 1 }, { {} }), "equal first, the second decides")
    assertFalse(cmp({ 4, 1 }, { 4, 1 }, { {} }), "equal is not better")
end)

test("optimize: exact progress messages and summary lines", function()
    -- red under: print the summary through tostring of a nil best score; or stop at the 101st unchanged
    -- generation (the legacy `>`); or change the population (the count is no longer 300 + 275 a generation)
    local r = gaRun(11)
    local NS, M, job = r.NS, r.M, r.job
    local gens = #r.progress
    assertTrue(gens > 0)
    for i, p in ipairs(r.progress) do
        assertTrue(p[1] == job, "progress " .. i .. " names another job")
        assertEqual(p[3], 100, "maxNoChange")
        if i == 1 then assertEqual(p[2], 0) end
        if i > 1 then assertTrue(p[2] == 0 or p[2] == r.progress[i - 1][2] + 1, "noChange stepped by more than one") end
    end
    assertEqual(r.progress[gens][2], 100, "the search ends at the 100th unchanged generation")
    assertEqual(r.progress[gens][4], "22, 1", "best text")
    local n = 300 + 275 * gens
    assertEqual(job.generated, n)
    local L = NS.L
    assertEqual(printedMatching(M, L["Checked %s outfits in %s seconds (%s outfits per second)"]:format(
        thousands(n), 4, thousands(n / 4))), 1, "the checked line")
    assertEqual(printedMatching(M, L["Best outfit score: %s"]:format("22, 1")), 1, "the best line")
    for _, line in ipairs(M.__printed()) do
        assertFalse(line:find("nil", 1, true) ~= nil, "a nil printed: " .. line)
    end
end)

test("optimize: a zero elapsed time prints a finite rate (B16)", function()
    -- red under: divide by the elapsed time unguarded ("inf outfits per second")
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    fakeStats(NS, GA_SCORES)
    run(NS, "z", GA_CFG, { item(101, "INVTYPE_HEAD") }, { rng = lcg(2) })
    assertTrue(drain(M))
    for _, line in ipairs(M.__printed()) do
        assertFalse(line:find("inf", 1, true) ~= nil or line:find("nan", 1, true) ~= nil, line)
    end
    assertEqual(printedMatching(M, "in 0 seconds"), 1)
end)

test("optimize: STARTED and DONE bracket the genetic search, and the finished job is let go", function()
    -- red under: a deliver that leaves `running` on the finished genetic job (the module holds it, so
    -- it is never collected)
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    fakeStats(NS, GA_SCORES)
    local held = setmetatable({}, { __mode = "v" })
    -- The search runs in its own call, so nothing on this case's stack holds the job afterwards.
    local function search()
        local started, done = hear(NS, "OPTIMIZE_STARTED"), hear(NS, "OPTIMIZE_DONE")
        local _, job = run(NS, "b", GA_CFG, gaInventory(), { rng = lcg(9) })
        assertEqual(#started, 1)
        assertTrue(started[1][1] == job)
        assertEqual(job.statName, "Label A, Label B")
        assertFalse(job.done == true, "the search is not running")
        assertTrue(drain(M))
        assertEqual(#done, 1)
        assertTrue(done[1][1] == job and done[1][2] == true)
        started[1], done[1] = nil, nil
        held[1] = job
    end
    search()
    collectgarbage("collect")
    collectgarbage("collect")
    assertNil(held[1], "the finished job is still held")
end)

-- ── cancel, stand-down, errors ────────────────────────────────────────────────────────────────

test("optimize: Cancel ends the ticker and delivers nil, \"canceled\" once", function()
    -- red under: leave the ticker armed on Cancel (the search keeps running and delivers later)
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    fakeStats(NS, GA_SCORES)
    local base = #M.__timers()
    local done = hear(NS, "OPTIMIZE_DONE")
    local calls, job = run(NS, "c", GA_CFG, gaInventory(), { rng = lcg(4) })
    assertEqual(#M.__timers(), base + 1, "no ticker armed")
    M.__fireTimers()
    assertTrue(NS.Optimize.Cancel(job))
    assertEqual(#M.__timers(), base, "the ticker is still armed")
    assertTrue(drain(M))
    assertEqual(#calls, 1)
    assertNil(calls[1].items)
    assertEqual(calls[1].reason, "canceled")
    assertTrue(done[1][2] == false and done[1][3] == "canceled")
    assertFalse(NS.Optimize.Cancel(), "nothing left to cancel")
end)

test("optimize: a stand-down ends the search with nil, \"stood-down\"", function()
    -- red under: an Optimize.Suspend that does not cancel the running job
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    fakeStats(NS, GA_SCORES)
    local progress = hear(NS, "OPTIMIZE_PROGRESS")
    local calls = run(NS, "s", GA_CFG, gaInventory(), { rng = lcg(4) })
    M.__fireTimers()
    assertTrue(NS.SetByPath("enabled", false))
    assertEqual(#calls, 1)
    assertEqual(calls[1].reason, "stood-down")
    local seen = #progress
    drain(M)
    assertEqual(#progress, seen, "the search ran on after the stand-down")
    assertFalse(NS.Optimize.Cancel(), "a search outlived the stand-down")
end)

test("optimize: a second search cancels the running one", function()
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    fakeStats(NS, GA_SCORES)
    local first = run(NS, "one", GA_CFG, gaInventory(), { rng = lcg(4) })
    local second, job2 = run(NS, "two", GA_CFG, gaInventory(), { rng = lcg(5) })
    assertEqual(#first, 1)
    assertEqual(first[1].reason, "canceled")
    assertFalse(job2.done == true, "the second search is not running")
    assertTrue(drain(M))
    assertEqual(#second, 1)
    assertTrue(second[1].items ~= nil)
end)

test("optimize: a resume error is surfaced once and delivers nil, \"error\"", function()
    -- red under: deliver nothing on a resume error (the caller waits forever)
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    local boom = false
    local scores = { A = { [151] = function() if boom then error("kaboom") end return 1 end }, B = { [151] = 0 } }
    fakeStats(NS, scores)
    local calls = run(NS, "e", GA_CFG, { item(151, "INVTYPE_HEAD") }, { rng = lcg(4) })
    boom = true
    assertTrue(drain(M), "the ticker survived the error")
    assertEqual(#calls, 1)
    assertNil(calls[1].items)
    assertEqual(calls[1].reason, "error")
    assertEqual(printedMatching(M, NS.L["The outfit optimizer failed (%s); the details are in the debug console"]
        :format("optimize")), 1)
    assertFalse(NS.Optimize.Cancel(), "the failed search is still running")
end)

-- ── Trial ─────────────────────────────────────────────────────────────────────────────────────

test("optimize: Trial answers the new-outfit dialog's no-items warning", function()
    -- red under: answer true for a simple cfg no item scores on
    local NS = unitLoad().NS
    fakeStats(NS, { STA = { [161] = 1 }, HAS = {} })
    local started = hear(NS, "OPTIMIZE_STARTED")
    local cache = NS.Inventory.NewCache({ item(161, "INVTYPE_HEAD") })
    T.fake(NS, "Inventory", { Cache = function() return cache end })
    assertTrue(NS.Optimize.Trial({ { stat = "STA" } }))
    local ok, msg = NS.Optimize.Trial({ { stat = "HAS" } })
    assertFalse(ok)
    assertEqual(msg, NS.L["Warning: None of your items have that attribute"])
    assertTrue(NS.Optimize.Trial({ { stat = "HAS" }, { stat = "STA" } }), "a complex cfg is not tried")
    assertEqual(#started, 0, "Trial started a search")
    local ok2, msg2 = NS.Optimize.Trial({ { stat = "GONE" } })
    assertFalse(ok2)
    assertEqual(msg2, NS.L["Unknown stat ID: %s"]:format("GONE"))
end)

-- ── Rebuild ───────────────────────────────────────────────────────────────────────────────────

local ALL_SLOTS = {
    "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "MainHandSlot", "SecondaryHandSlot", "BackSlot", "NeckSlot", "ShirtSlot", "TabardSlot", "Finger0Slot",
    "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
}

local function rebuildScene()
    local NS = unitLoad().NS
    fakeStats(NS, { STA = { [171] = 9 } })
    local cache = NS.Inventory.NewCache({ item(171, "INVTYPE_HEAD") })
    T.fake(NS, "Inventory", { Cache = function() return cache end })
    local stack = T.fake(NS, "Stack", { Wear = true })
    return NS, stack
end

test("optimize: Rebuild of a Complete outfit keeps its old items where the result is empty", function()
    -- red under: replace the items wholesale for a Complete outfit (every other slot is lost)
    local NS, stack = rebuildScene()
    local items = {}
    for i, s in ipairs(ALL_SLOTS) do items[s] = { id = 900 + i } end
    local id = NS.Outfits.Create("Full", items)
    assertEqual(NS.Outfits.Get(id).category, "Complete")
    local edited = hear(NS, "OUTFIT_EDITED")
    assertTrue(NS.Optimize.Rebuild(id, { { stat = "STA" } }) ~= nil)
    local rec = NS.Outfits.Get(id)
    assertEqual(rec.items.HeadSlot.id, 171)
    assertEqual(rec.items.ChestSlot.id, items.ChestSlot.id, "an old item was dropped")
    assertEqual(#edited, 1, "one OUTFIT_EDITED for the rebuild")
    assertEqual(stack.__count("Wear"), 1)
    assertEqual(stack.__calls[1][2], id)
    assertTrue(stack.__calls[1][3].now == true, "the rebuilt outfit is worn now")
end)

test("optimize: Rebuild of an Accessory outfit takes the result as it is", function()
    -- red under: merge the old items for every outfit, not only a Complete one
    local NS = rebuildScene()
    local id = NS.Outfits.Create("Bits", { NeckSlot = { id = 5 } })
    NS.Optimize.Rebuild(id, { { stat = "STA" } })
    local rec = NS.Outfits.Get(id)
    assertEqual(rec.items.HeadSlot.id, 171)
    assertNil(rec.items.NeckSlot, "the accessory kept an item the rebuild did not pick")
end)

test("optimize: Rebuild reads the outfit's own stat cfg when none is passed", function()
    local NS = rebuildScene()
    local id = NS.Outfits.Create("Bits", { NeckSlot = { id = 5 } })
    NS.Outfits.Get(id).stat = { { stat = "STA" } }
    NS.Optimize.Rebuild(id)
    assertEqual(NS.Outfits.Get(id).items.HeadSlot.id, 171)
end)

test("optimize: Rebuild of an EM outfit goes through EM.SetItems, which wears it", function()
    -- red under: fall through from EM.SetItems to O.SetItems and NS.Stack.Wear
    local NS, stack = rebuildScene()
    local em = T.fake(NS, "EM", { Items = function() return { NeckSlot = { id = 5 } } end, SetItems = true })
    local id = NS.Outfits.Create("Set", {}, { kind = "em", setID = 3 })
    NS.Optimize.Rebuild(id, { { stat = "STA" } })
    assertEqual(em.__count("SetItems"), 1)
    local call = em.__calls[#em.__calls]
    assertEqual(call[1], "SetItems")
    assertTrue(call[2] == NS.Outfits.Get(id), "SetItems was handed another record")
    assertEqual(call[3].HeadSlot.id, 171)
    assertEqual(stack.__count("Wear"), 0, "EM.SetItems wears the set itself")
end)

test("optimize: Rebuild with nothing to pick says so and leaves the outfit alone", function()
    -- red under: apply an empty result (the outfit emptied and worn), or drop Rebuild's unknown-outfit
    -- guard (it raises on a nil record)
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    fakeStats(NS, { STA = {} })
    local cache = NS.Inventory.NewCache({ item(171, "INVTYPE_HEAD") })
    T.fake(NS, "Inventory", { Cache = function() return cache end })
    local stack = T.fake(NS, "Stack", { Wear = true })
    local id = NS.Outfits.Create("Bits", { NeckSlot = { id = 5 } })
    NS.Optimize.Rebuild(id, { { stat = "STA" } })
    assertEqual(NS.Outfits.Get(id).items.NeckSlot.id, 5)
    assertEqual(stack.__count("Wear"), 0)
    assertEqual(printedMatching(M, NS.L["Couldn't generate an outfit because no items with that stat were found"]), 1)
    assertNil(NS.Optimize.Rebuild("o999", { { stat = "STA" } }), "an unknown outfit")
    local _, err = NS.Optimize.Rebuild(id, { { stat = "NOPE" } })
    assertEqual(err, NS.L["Unknown stat ID: %s"]:format("NOPE"))
    assertEqual(printedMatching(M, NS.L["Unknown stat ID: %s"]:format("NOPE")), 1)
end)
