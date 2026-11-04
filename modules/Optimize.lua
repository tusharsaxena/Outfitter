local _, NS = ...
-- modules/Optimize.lua — NS.Optimize: the smart-outfit driver, the simple search, Trial and Rebuild
-- (design §5.14; OutfitterOptimize.lua:21-297 and Outfitter.lua:2165-2214 at 7ea3dc3).
--
-- THE CFG is the stat rows an outfit is built for: `{ { stat = id, min = n, max = n }, complex = bool }`
-- (the record's `stat` field, design §3.3). No cfg, or an empty one, is `{ { stat = "STA" } }`, and a
-- row with no stat reads STA, as the legacy config line did. A stat id NS.Stats does not know (a
-- Pawn scale since deleted) refuses the search: Generate returns nil and the message, and never
-- names a nil (B16: the legacy multi-stat check formatted the table's StatID, which is always nil).
--
-- THE SEARCH is simple for one row with no min or max on a stat not marked complex: a greedy pass
-- per slot, which bumps a beaten ring, trinket or one-hander to its second slot, then picks the best
-- main hand and off hand (below). Anything else is the genetic search (modules/Optimize_Genetic.lua),
-- spread over frames.
--
-- THE CANDIDATES are the cache's items that are not an unbound BoE, that the player can use, and that
-- no row drops (NS.Stats answers nil for an item above the player's level: not a candidate, never
-- scored 0). Scores are cached on the job (job.scores, weak) for its length.
--
-- THE WEAPONS. A one-hander pairs on its meta slot (Weapon0/Weapon1), a two-hander on TwoHandSlot
-- (unless gripped, when it pairs like a one-hander). The pairs tried are the legacy six, or three for
-- ITEM_LEVEL, which never leaves the main hand empty; a pair that puts a one-hander in the off hand is
-- tried only when the player can dual wield (B15). A two-hander then replaces the pair only if it
-- scores strictly more.
--
-- DELIVERY (B7). The result reaches the caller exactly once, through onDone(items, reason): items is
-- slot -> ItemRecord (NS.ItemInfo.Snapshot copies, never the cache's live infos, B15), or nil with
-- the reason "empty", "canceled", "stood-down" or "error". Generate returns the job, never the
-- items. A refusal (unknown stat) is returned instead and delivers nothing. The simple search
-- delivers before Generate returns; the genetic one delivers from its ticker.
--
-- ONE SEARCH AT A TIME. A genetic search is the running job (Opt.Running); starting another cancels
-- it. OPTIMIZE_STARTED, OPTIMIZE_PROGRESS and OPTIMIZE_DONE bracket the genetic search for the
-- progress dialog; the simple search sends none. A stand-down (Opt.Suspend) cancels it with
-- "stood-down".
--
-- CALLS (at call time, no nil guard; design §12): NS.Stats.Get/ConfigName, NS.Inventory.Cache,
-- NS.ItemInfo.Bind/Usable/MetaSlot/Snapshot, NS.PlayerState.CanDualWield/CanDualWield2H,
-- NS.OptimizeGA.Start/Stop, and for Rebuild NS.Outfits.Get/Items/SetItems, NS.Stack.Wear and
-- NS.EM.SetItems.

local Opt = {}
NS.Optimize = Opt

local L = NS.L
local Compat = NS.Compat

local DEFAULT_STAT = "STA"
local WEAK_KEYS = { __mode = "k" }

local running      -- the genetic job in progress, or nil
local told = {}    -- [tag] = true once the player has been told about a failure this session

-- ── surfacing ─────────────────────────────────────────────────────────────────────────────────

-- Record the failure, write it to the console, tell the player once per tag, then hand it to the
-- client's error handler.
local function surface(tag, err)
    local text = NS.SafeToString(err)
    Opt.lastError = { tag = tag, err = text, at = Compat.GetTime() }
    if NS.DebugLog and NS.DebugLog.Add then NS.DebugLog:Add("Opt", tag .. ": " .. text) end
    if not told[tag] then
        told[tag] = true
        NS.Print(L["The outfit optimizer failed (%s); the details are in the debug console"]:format(tag))
    end
    local geh = _G.geterrorhandler
    local handler = type(geh) == "function" and geh()
    if handler then handler(err) end
end

-- ── the cfg ───────────────────────────────────────────────────────────────────────────────────

-- A plain copy of cfg with the default applied: rows { stat, min, max } and the complex flag.
local function normalize(cfg)
    if type(cfg) ~= "table" or #cfg == 0 then cfg = { { stat = DEFAULT_STAT } } end
    local out = { complex = cfg.complex == true }
    for i, row in ipairs(cfg) do
        local stat = row.stat
        if stat == nil then stat = DEFAULT_STAT end
        out[i] = { stat = stat, min = tonumber(row.min), max = tonumber(row.max) }
    end
    return out
end

-- The rows with their stat objects, or nil and the refusal message.
local function resolve(rows)
    local out = {}
    for i, row in ipairs(rows) do
        local stat = NS.Stats.Get(row.stat)
        if not stat then return nil, L["Unknown stat ID: %s"]:format(NS.SafeToString(row.stat)) end
        out[i] = { stat = stat, min = row.min, max = row.max }
    end
    return out
end

local function isComplex(rows, resolved)
    local first = rows[1]
    return #rows > 1 or first.min ~= nil or first.max ~= nil or resolved[1].stat.complex == true
end

-- ── candidates ────────────────────────────────────────────────────────────────────────────────

local function scoredByAll(info, resolved, job)
    for _, row in ipairs(resolved) do
        if row.stat:Score(info, job) == nil then return false end
    end
    return true
end

local function isCandidate(info, resolved, job)
    local II = NS.ItemInfo
    return info.slot ~= nil and II.Bind(info) ~= "boe" and II.Usable(info) and scoredByAll(info, resolved, job)
end

local function candidates(cache, resolved, job)
    local out = {}
    for _, info in ipairs(cache and cache.all or {}) do
        if isCandidate(info, resolved, job) then out[#out + 1] = info end
    end
    return out
end

-- ── the simple search ─────────────────────────────────────────────────────────────────────────

-- Put `info` in `slot` if it beats what is there, bumping the beaten item to the alternate slot; else
-- try it in the alternate slot (OutfitterOptimize.lua:153-187).
local function placeIfBetter(o, slot, info, score, ctx)
    local current = o[slot]
    local alt = NS.ItemData.HALF_ALT_SLOT[slot]
    local currentScore = current and ctx.stat:Score(current, ctx.job)
    if not currentScore or score > currentScore then
        if currentScore and alt then placeIfBetter(o, alt, current, currentScore, ctx) end
        o[slot] = info
    elseif alt then
        placeIfBetter(o, alt, info, score, ctx)
    end
end

local function sum(ctx, a, b)
    local stat, job = ctx.stat, ctx.job
    return (a and stat:Score(a, job) or 0) + (b and stat:Score(b, job) or 0)
end

-- The main hand / off hand pairs to try: { mh, oh, needsMainHand, weaponInOffHand }
-- (OutfitterOptimize.lua:220-239).
local function weaponPairs(o, itemLevel)
    local mh, oh, w0, w1 = o.MainHandSlot, o.SecondaryHandSlot, o.Weapon0Slot, o.Weapon1Slot
    if itemLevel then
        return { { mh, w1, true, true }, { w0, oh, true, false }, { w1, oh, true, false } }
    end
    return {
        { mh, oh, false, false }, { mh, w0, true, true }, { mh, w1, true, true },
        { w0, oh, false, false }, { w1, oh, false, false }, { w0, w1, true, true },
    }
end

local function pairAllowed(p, canDW)
    return (canDW or not p[4]) and (not p[3] or p[1] ~= nil)
end

-- The best pair wins the hands (the first of equal pairs); the meta slots go either way.
local function bestPair(o, ctx)
    if o.Weapon0Slot or o.Weapon1Slot then
        local best, bestValue
        for _, p in ipairs(weaponPairs(o, ctx.stat.id == "ITEM_LEVEL")) do
            if pairAllowed(p, ctx.canDW) then
                local v = sum(ctx, p[1], p[2])
                if not best or v > bestValue then best, bestValue = p, v end
            end
        end
        if best then o.MainHandSlot, o.SecondaryHandSlot = best[1], best[2] end
    end
    o.Weapon0Slot, o.Weapon1Slot = nil, nil
end

-- A two-hander takes both hands only when it scores strictly more than the pair.
local function twoHander(o, ctx)
    local th = o.TwoHandSlot
    if not th then return end
    if ctx.stat:Score(th, ctx.job) > sum(ctx, o.MainHandSlot, o.SecondaryHandSlot) then
        o.MainHandSlot, o.SecondaryHandSlot = th, nil
    end
    o.TwoHandSlot = nil
end

-- slot -> info for the best single-stat outfit over `list` (OutfitterOptimize.lua:114-151).
local function simple(stat, job, list)
    local ctx = { stat = stat, job = job, canDW = NS.PlayerState.CanDualWield() }
    local o = {}
    for _, info in ipairs(list) do
        local slot = NS.ItemInfo.MetaSlot(info) or info.slot
        placeIfBetter(o, slot, info, stat:Score(info, job), ctx)
    end
    bestPair(o, ctx)
    twoHander(o, ctx)
    return o
end

-- ── delivery ──────────────────────────────────────────────────────────────────────────────────

local function snapshot(items)
    local out = {}
    for slot, info in pairs(items) do out[slot] = NS.ItemInfo.Snapshot(info) end
    return out
end

-- The one way a job ends (B7): a second call for the same job does nothing.
local function deliver(job, items, reason)
    if job.done then return end
    job.done = true
    job.candidates = nil
    if job.genetic then
        NS.OptimizeGA.Stop(job)
        if running == job then running = nil end
        NS.SendBus(NS.MSG.OPTIMIZE_DONE, job, items ~= nil, reason)
    end
    if job.onDone then job.onDone(items, reason) end
end

local function deliverItems(job, items)
    if next(items) == nil and not job.allowEmpty then return deliver(job, nil, "empty") end
    deliver(job, snapshot(items))
end

-- The legacy FormatThousands: 28075 -> "28,075", rounded to the nearest whole number.
local function thousands(n)
    local s = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (s:sub(1, 1) == ",") and s:sub(2) or s
end

-- The two chat lines a finished genetic search prints. With no time elapsed the rate is the count
-- itself, so the line never says "inf" (B16).
local function printSummary(job)
    local elapsed = Compat.GetTime() - job.startedAt
    local n = job.generated
    local rate = (elapsed > 0) and (n / elapsed) or n
    NS.Print(L["Checked %s outfits in %s seconds (%s outfits per second)"]:format(
        thousands(n), math.floor(elapsed), thousands(rate)))
    NS.Print(L["Best outfit score: %s"]:format(job.bestText or ""))
end

-- ── the search ────────────────────────────────────────────────────────────────────────────────

local function newJob(name, rows, resolved, opts, onDone)
    return { name = name, cfg = rows, rows = resolved, complex = isComplex(rows, resolved),
             statName = NS.Stats.ConfigName(rows), allowEmpty = opts.allowEmpty == true,
             highSpeed = opts.highSpeed == true, onDone = onDone, scores = setmetatable({}, WEAK_KEYS) }
end

local function startGenetic(job, rng)
    if running then Opt.Cancel(running) end
    job.genetic = true
    job.canDW, job.canDW2H = NS.PlayerState.CanDualWield(), NS.PlayerState.CanDualWield2H()
    job.startedAt = Compat.GetTime()
    job.progress = function(noChange, maxNoChange, text)
        job.bestText = text
        NS.SendBus(NS.MSG.OPTIMIZE_PROGRESS, job, noChange, maxNoChange, text)
    end
    job.complete = function(items)
        printSummary(job)
        deliverItems(job, items)
    end
    job.fail = function(err)
        surface("optimize", err)
        deliver(job, nil, "error")
    end
    running = job
    NS.SendBus(NS.MSG.OPTIMIZE_STARTED, job)
    NS.OptimizeGA.Start(job.name, job.rows, job, rng)
end

--- Build an outfit named `name` for `cfg` from the inventory.
--- `opts = { cache = Inv.Cache(), allowEmpty, highSpeed, rng = math.random }`.
--- The result reaches `onDone(items|nil, reason)` exactly once (see the header).
--- @return table|nil job, string|nil refusal
function Opt.Generate(name, cfg, opts, onDone)
    opts = opts or {}
    local rows = normalize(cfg)
    local resolved, err = resolve(rows)
    if not resolved then return nil, err end
    local job = newJob(name, rows, resolved, opts, onDone)
    job.candidates = candidates(opts.cache or NS.Inventory.Cache(), resolved, job)
    if job.complex then
        startGenetic(job, opts.rng)
    else
        deliverItems(job, simple(resolved[1].stat, job, job.candidates))
    end
    return job
end

--- The new-outfit dialog's check: whether a simple cfg finds any item. A complex cfg is not tried
--- (true), as the legacy dialog did not try one.
--- @return boolean ok, string|nil message  the localized warning or refusal
function Opt.Trial(cfg)
    local rows = normalize(cfg)
    local resolved, err = resolve(rows)
    if not resolved then return false, err end
    if isComplex(rows, resolved) then return true end
    local job = { scores = setmetatable({}, WEAK_KEYS) }
    local found = simple(resolved[1].stat, job, candidates(NS.Inventory.Cache(), resolved, job))
    if next(found) ~= nil then return true end
    return false, L["Warning: None of your items have that attribute"]
end

-- ── rebuild ───────────────────────────────────────────────────────────────────────────────────

-- The rebuilt items; a Complete outfit keeps its old item in every slot the result left empty.
local function merged(rec, items, complete)
    if not complete then return items end
    local out = {}
    for slot, item in pairs(NS.Outfits.Items(rec)) do out[slot] = item end
    for slot, item in pairs(items) do out[slot] = item end
    return out
end

local function applyRebuild(id, items, complete)
    local O = NS.Outfits
    local rec = O.Get(id)
    if not rec then return end
    items = merged(rec, items, complete)
    if rec.kind == "em" then
        NS.EM.SetItems(rec, items)       -- saves the set and wears it
        return
    end
    O.SetItems(id, items)
    NS.Stack.Wear(id, { now = true })
end

--- Rebuild an outfit for `cfg` (default: its own `stat`), then wear it. Answers the job, or nil and
--- the refusal (printed) for an unknown stat; nil for an unknown outfit.
--- @param id string
--- @param cfg table|nil
--- @return table|nil job, string|nil refusal
function Opt.Rebuild(id, cfg)
    local rec = NS.Outfits.Get(id)
    if not rec then return nil end
    local complete = rec.category == "Complete"
    local job, err = Opt.Generate(rec.name, cfg or rec.stat, {}, function(items, reason)
        if items then return applyRebuild(id, items, complete) end
        if reason == "empty" then NS.Print(L["Couldn't generate an outfit because no items with that stat were found"]) end
    end)
    if not job then NS.Print(err) end
    return job, err
end

-- ── control ───────────────────────────────────────────────────────────────────────────────────

--- End a job (default: the running one) with nil, "canceled". False when there is nothing to end.
--- @param job table|nil
--- @return boolean
function Opt.Cancel(job)
    job = job or running
    if not job or job.done then return false end
    deliver(job, nil, "canceled")
    return true
end

--- The genetic job in progress, or nil.
function Opt.Running() return running end

--- Stand-down (design §5.12): the running search ends with nil, "stood-down".
function Opt.Suspend()
    if running then deliver(running, nil, "stood-down") end
end

--- Stand-up: nothing to restore; a search is only ever started by the player.
function Opt.Resume() end
