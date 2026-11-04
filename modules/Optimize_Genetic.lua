local _, NS = ...
-- modules/Optimize_Genetic.lua — NS.OptimizeGA: the genetic search behind a complex smart outfit
-- (design §5.14; OutfitterOptimize.lua:346-589, 656-896 at 7ea3dc3).
--
-- THE SEARCH. A population of 300 random outfits drawn from the candidates, sorted best first. Each
-- generation keeps the 25 best as parents and replaces the other 275 with children: a slot-by-slot
-- splice of two different parents, then a mutation that re-draws each slot with chance 0.2. It ends
-- after 1000 generations, or at the 100th generation in a row whose best score did not change. All
-- of these are the legacy constants (PARAMS below).
--
-- THE SCORE is one total per cfg row, then the number of empty slots: two outfits equal on every
-- stat compare on the empties, so a tie favors the outfit that leaves more slots alone (Q6). A row
-- with a min or a max compares as the legacy did (CompareCompound).
--
-- THE SLOTS (B15). Each candidate is drawn for the slot its type goes in. A ring or a trinket is also
-- drawn for the second ring or trinket slot, and a one-hander (or a gripped two-hander) for the off
-- hand when the player can dual wield: the legacy search never put a one-hander in the off hand. The
-- paired slots never hold the same item twice, and an ungripped two-hander empties the off hand.
--
-- THE TICKER. The search is a coroutine resumed by an AceTimer ticker. Each resume runs for a budget,
-- 0.02 s or 0.1 s in high speed (job.highSpeed), measured on debugprofilestop, and also yields after
-- 5000 children per second of budget, as the legacy loop count did, so a frozen clock still yields.
-- One resume is the `optimizeStep` perf bracket. The ticker is canceled on every way out.
--
-- THE RNG is injected (default math.random) and is the only source of chance, so a seeded generator
-- replays a search exactly.
--
-- THE JOB is modules/Optimize.lua's. This file reads job.candidates, job.canDW, job.canDW2H and
-- job.highSpeed, and answers through job.progress, job.complete and job.fail; Optimize sends every
-- bus message and delivers the result.

local GA = {}
NS.OptimizeGA = GA

local Perf = NS.Perf

GA.PARAMS = { population = 300, parents = 25, mutation = 0.2, maxGenerations = 1000, maxNoChange = 100 }
local P = GA.PARAMS

local LOOPS_PER_SECOND = 5000    -- the legacy vLoopCountYieldFactor
local BREED_TRIES = 8            -- a second parent equal to the first is re-drawn at most this often
local REDRAW_TRIES = 8           -- a slot that drew its pair's item re-draws at most this often
local TWO_HANDER = "INVTYPE_2HWEAPON"

-- The slots that must not hold the same item, both directions.
local PAIR = {
    Finger0Slot = "Finger1Slot", Finger1Slot = "Finger0Slot",
    Trinket0Slot = "Trinket1Slot", Trinket1Slot = "Trinket0Slot",
    MainHandSlot = "SecondaryHandSlot", SecondaryHandSlot = "MainHandSlot",
}
-- A candidate of the first slot is drawn for the second one too.
local ALSO = { Finger0Slot = "Finger1Slot", Trinket0Slot = "Trinket1Slot" }

local timers   -- the AceTimer target, made on first use

local function timerTarget()
    if not timers then timers = LibStub("AceTimer-3.0"):Embed({}) end
    return timers
end

-- ── the slots ─────────────────────────────────────────────────────────────────────────────────

local function addTo(lists, slot, info)
    local list = lists[slot]
    if not list then
        list = {}
        lists[slot] = list
    end
    list[#list + 1] = info
end

local function offHandWeapon(info, canDW)
    return canDW and info.slot == "MainHandSlot" and NS.ItemInfo.MetaSlot(info) == "Weapon0Slot"
end

--- The slots the search draws for: { { slot, items } } in SLOT_NAMES order, a slot only when some
--- candidate can go in it.
--- @param candidates table[]  item infos
--- @param canDW boolean       whether a one-hander may go in the off hand (B15)
--- @return table[]
function GA.Slots(candidates, canDW)
    local lists = {}
    for _, info in ipairs(candidates) do
        addTo(lists, info.slot, info)
        if ALSO[info.slot] then addTo(lists, ALSO[info.slot], info) end
        if offHandWeapon(info, canDW) then addTo(lists, "SecondaryHandSlot", info) end
    end
    local out = {}
    for _, name in ipairs(NS.ItemData.SLOT_NAMES) do
        if lists[name] then out[#out + 1] = { slot = name, items = lists[name] } end
    end
    return out
end

-- ── outfits ───────────────────────────────────────────────────────────────────────────────────

-- One draw from `list`: an item, or nil for the empty slot (index 0), and the index.
local function draw(list, rng)
    local i = rng(#list + 1) - 1
    return (i > 0) and list[i] or nil, i
end

-- A draw for `s` that is not the item already in the paired slot (OutfitterOptimize.lua:787-829).
local function setRandom(ctx, items, s)
    local list, alt = s.items, PAIR[s.slot]
    local item, i = draw(list, ctx.rng)
    if not item or not alt or items[alt] ~= item then
        items[s.slot] = item
        return
    end
    if #list < 2 then
        items[s.slot] = nil
    elseif #list == 2 then
        items[s.slot] = list[3 - i]
    else
        for _ = 1, REDRAW_TRIES do
            item = draw(list, ctx.rng)
            if items[alt] ~= item then break end
        end
        items[s.slot] = (items[alt] ~= item) and item or nil
    end
end

-- An ungripped two-hander in the main hand leaves no room for an off hand.
local function fixHands(ctx, items)
    local mh = items.MainHandSlot
    if mh and mh.invType == TWO_HANDER and not ctx.canDW2H then items.SecondaryHandSlot = nil end
end

local function emptyCount(items)
    local n = 0
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
        if items[slot] == nil then n = n + 1 end
    end
    return n
end

-- One total per cfg row, then the empty-slot count (Q6: ties favor the emptier outfit).
local function scoreWithEmpty(ctx, items)
    local out = {}
    for i, row in ipairs(ctx.rows) do
        local total = 0
        for _, info in pairs(items) do total = total + (row.stat:Score(info, ctx.job) or 0) end
        out[i] = total
    end
    out[#out + 1] = emptyCount(items)
    return out
end

local function citizen(ctx, items)
    fixHands(ctx, items)
    return { items = items, score = scoreWithEmpty(ctx, items) }
end

local function randomOutfit(ctx)
    local items = {}
    for _, s in ipairs(ctx.slots) do setRandom(ctx, items, s) end
    return items
end

-- Each slot from one parent or the other; the second of a pair holding the same item stays empty.
local function splice(ctx, a, b)
    local items = {}
    for _, s in ipairs(ctx.slots) do
        local from = (ctx.rng() < 0.5) and a or b
        local item, alt = from.items[s.slot], PAIR[s.slot]
        if item and (not alt or items[alt] ~= item) then items[s.slot] = item end
    end
    return items
end

local function mutate(ctx, items)
    for _, s in ipairs(ctx.slots) do
        if ctx.rng() < P.mutation then setRandom(ctx, items, s) end
    end
end

-- ── comparing ─────────────────────────────────────────────────────────────────────────────────

-- Whether `a` beats `b` on one row: true, false, or nil when they are equal.
local function compareOne(a, b, row)
    if a == b then return nil end
    local min, max = row and row.min, row and row.max
    if min then
        if a >= min and b >= min then return a < b end   -- both meet it: the closer one
        return a > b
    end
    if max then
        if a <= max and b <= max then return a > b end   -- both under it: the closer one
        return a < b
    end
    return a > b
end

--- Whether score `a` beats score `b` (OutfitterOptimize.lua:374-406): the first row they differ on
--- decides; equal is not better.
--- @param a number[]
--- @param b number[]
--- @param rows table[]  the cfg rows ({ min, max }); an index past them compares higher-is-better
--- @return boolean
function GA.CompareCompound(a, b, rows)
    for i, x in ipairs(a) do
        local r = compareOne(x, b[i], rows[i])
        if r ~= nil then return r end
    end
    return false
end

local function sortCitizens(ctx)
    local rows = ctx.rows
    table.sort(ctx.citizens, function(x, y) return GA.CompareCompound(x.score, y.score, rows) end)
end

-- ── the coroutine ─────────────────────────────────────────────────────────────────────────────

local function newBudget(job)
    local seconds = job.highSpeed and 0.1 or 0.02
    return { deadline = debugprofilestop() + seconds * 1000, loops = LOOPS_PER_SECOND * seconds }
end

-- Count one child; yield once the resume's budget is spent.
local function spend(ctx)
    local b = ctx.budget
    b.loops = b.loops - 1
    if b.loops <= 0 or debugprofilestop() >= b.deadline then
        coroutine.yield()
        ctx.budget = newBudget(ctx.job)
    end
end

local function seedPopulation(ctx)
    for i = 1, P.population do ctx.citizens[i] = citizen(ctx, randomOutfit(ctx)) end
    ctx.job.generated = P.population
    sortCitizens(ctx)
end

-- Two different parents among the best (the legacy `while p2 == p1`, bounded).
local function parents(ctx)
    local rng = ctx.rng
    local p1, p2 = rng(P.parents), rng(P.parents)
    for _ = 1, BREED_TRIES do
        if p2 ~= p1 then break end
        p2 = rng(P.parents)
    end
    if p2 == p1 then p2 = p1 % P.parents + 1 end
    return p1, p2
end

local function breed(ctx)
    local p1, p2 = parents(ctx)
    local items = splice(ctx, ctx.citizens[p1], ctx.citizens[p2])
    mutate(ctx, items)
    return citizen(ctx, items)
end

local function generation(ctx)
    local job = ctx.job
    for i = P.parents + 1, P.population do
        ctx.citizens[i] = breed(ctx)
        job.generated = job.generated + 1
        spend(ctx)
    end
    sortCitizens(ctx)
end

-- Count an unchanged best; true once it has held for maxNoChange generations.
local function converged(ctx)
    local key = table.concat(ctx.citizens[1].score, ",")
    if key == ctx.lastKey then
        ctx.noChange = ctx.noChange + 1
    else
        ctx.noChange, ctx.lastKey = 0, key
    end
    return ctx.noChange >= P.maxNoChange
end

-- The best outfit's stat totals, without the empty count: "Best score: 22, 1".
local function bestText(ctx)
    local score, parts = ctx.citizens[1].score, {}
    for i = 1, #ctx.rows do parts[i] = tostring(score[i]) end
    return table.concat(parts, ", ")
end

local function search(ctx)
    seedPopulation(ctx)
    for _ = 1, P.maxGenerations do
        generation(ctx)
        local done = converged(ctx)
        ctx.job.progress(ctx.noChange, P.maxNoChange, bestText(ctx))
        if done then break end
    end
    return ctx.citizens[1].items
end

-- ── the ticker ────────────────────────────────────────────────────────────────────────────────

local function step(ctx)
    local t0 = Perf.on and debugprofilestop()
    ctx.budget = newBudget(ctx.job)
    local ok, result = coroutine.resume(ctx.co)
    if t0 then Perf.Note("optimizeStep", debugprofilestop() - t0) end
    if not ok then
        GA.Stop(ctx.job)
        return ctx.job.fail(result)
    end
    if coroutine.status(ctx.co) == "dead" then
        GA.Stop(ctx.job)
        ctx.job.complete(result)
    end
end

--- Start the search for `job` and arm its ticker; the first resume is the first tick.
--- @param name string   the outfit's name (for the debug console only)
--- @param rows table[]  the resolved cfg rows: { stat = <stat object>, min, max }
--- @param job table     modules/Optimize.lua's job (see the header)
--- @param rng function|nil  shaped like math.random; default math.random
function GA.Start(name, rows, job, rng)
    local ctx = { job = job, name = name, rows = rows, rng = rng or math.random, canDW2H = job.canDW2H,
                  slots = GA.Slots(job.candidates, job.canDW), citizens = {}, noChange = 0 }
    ctx.co = coroutine.create(function() return search(ctx) end)
    job.ga = ctx
    job.generated = 0
    ctx.ticker = timerTarget():ScheduleRepeatingTimer(function() step(ctx) end, 0)
    NS.Debug("Opt", "genetic search for %s over %d slots", NS.SafeToString(name), #ctx.slots)
end

--- Cancel the job's ticker; safe to call twice, and for a job the search never started.
--- @param job table
function GA.Stop(job)
    local ctx = job and job.ga
    if ctx and ctx.ticker then
        timerTarget():CancelTimer(ctx.ticker)
        ctx.ticker = nil
    end
end
