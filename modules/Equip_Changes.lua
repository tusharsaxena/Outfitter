local _, NS = ...
-- modules/Equip_Changes.lua — NS.Changes: the pure change-list builder, unique-equip order and
-- optimize rules (design §5.11; OutfitterEquipment.lua:1-464, 537-700 at 7ea3dc3).
--
-- PURE. Build takes the compiled outfit (slot -> ItemRecord, NS.Stack.Compile's answer), an
-- inventory cache (NS.Inventory.Cache() or Inv.NewCache(infos)) and a ctx, and returns a list. It
-- reads no client state of its own; the slot ids come from Compat.InventorySlotID and the
-- unique-equip keys from NS.ItemInfo.UniqueKeys, which an info carries cached once read.
--
--   ctx = { slotLink  = function(slotName) -> info|nil   what is worn there now (default: cache.worn)
--           canDW2H   = boolean                          Titan's Grip (NS.PlayerState.CanDualWield2H)
--           phantom   = { [itemID] = true }              default NS.ItemData.PHANTOM_IDS
--           showError = function(item, claimedDup, slotName)   a slot's item is not in the cache }
--
-- A CHANGE (design §5.11):
--   { slot, slotID, itemName, to = loc|nil (nil: empty the slot), from = loc|nil (a ForMoves move),
--     meta, tgFix, done, unique = { [key] = delta }, rank, rank2 }
--
-- What the legacy engine meant and never did, now done: the optimize runs (B1: findChangeForSlot
-- tested `not change and change.SlotName`, so it always answered nil); a two-hander inserts ONE
-- off-hand clear (B2: it re-inserted one on every visit); there are no classes, so no constructor
-- returns an undefined global (B4); and the four swap fixes have one spelling (the legacy
-- FixSlotSwapChange call named a fixSlotSwapChange method).

local Changes = {}
NS.Changes = Changes

local Compat = NS.Compat

local OH, MH = "SecondaryHandSlot", "MainHandSlot"
local TWO_HAND, ONE_HAND = "TwoHandSlot", "Weapon0Slot"
local MAX_PASSES = 20      -- Unique.Order's re-rank bound (OutfitterEquipment.lua:186)
local MAX_STEPS = 64       -- Opt.Apply's loop bound

local function newChange(slot, itemName)
    return { slot = slot, slotID = Compat.InventorySlotID(slot), itemName = itemName, unique = {} }
end

-- Add `delta` to the change's count for each unique-equip key `info` carries.
local function addUnique(change, info, delta)
    local keys = info and NS.ItemInfo.UniqueKeys(info)
    if not keys then return end
    for key in pairs(keys) do change.unique[key] = (change.unique[key] or 0) + delta end
end

local function isEmptyMarker(item)
    return item.id == nil or item.id == 0
end

-- The meta slot a change pairs on: a two-hander the player grips counts as a one-hander
-- (OutfitterEquipment.lua:145-149).
local function metaOf(info, canDW2H)
    local meta = info.meta
    if meta == nil then
        local s = info.invType and NS.ItemData.INVTYPE_TO_SLOT[info.invType]
        meta = s and s.meta
    end
    if meta == TWO_HAND and canDW2H then return ONE_HAND end
    return meta
end

-- ── Build ─────────────────────────────────────────────────────────────────────────────────────

-- Step 1 (OutfitterEquipment.lua:28-48): the slots that already hold their target leave a WORKING
-- COPY, and the item found there is claimed in the pass, so no other slot is handed it.
local function workingCopy(compiled, env)
    local work = {}
    for slot, item in pairs(compiled) do
        local has, info = env.cache:SlotHas(slot, item)
        if has then
            if info then env.pass.claimed[info] = true end
        else
            work[slot] = item
        end
    end
    return work
end

-- Step 2 (OutfitterEquipment.lua:50-74): WoW's dual-spec bug can leave a two-hander in the off hand
-- without Titan's Grip; an unequip for it goes in first.
local function addTGFix(env)
    local held = env.worn(OH)
    if env.ctx.canDW2H or not held or held.invType ~= "INVTYPE_2HWEAPON" then return false end
    local change = newChange(OH, held.name)
    change.tgFix = true
    addUnique(change, held, -1)
    env.changes[#env.changes + 1] = change
    return true
end

-- Step 3 (OutfitterEquipment.lua:103-158): one slot's change, or none.
local function addSlot(env, work, slot, glitch)
    local item = work[slot]
    if not item or env.phantom[item.id] then return end
    local current = env.worn(slot)
    -- Under the glitch the off hand reads empty: the TGFix change already takes it off.
    if glitch and slot == OH then current = nil end
    local change = newChange(slot, item.name)
    addUnique(change, current, -1)
    if isEmptyMarker(item) then
        if not current then return end
        change.itemName = current.name
    else
        local info, dup = env.cache:FindOrAlt(item, env.pass)
        if not info then
            if env.ctx.showError then env.ctx.showError(item, dup, slot) end
            return
        end
        addUnique(change, info, 1)
        change.to = info.loc
        change.meta = metaOf(info, env.ctx.canDW2H)
    end
    env.changes[#env.changes + 1] = change
end

local function wornReader(cache, ctx)
    if ctx.slotLink then return ctx.slotLink end
    return function(slot) return cache.worn and cache.worn[slot] end
end

--- The ordered change list that takes the worn gear to `compiled` (design §5.11). Pure; an empty
--- list (never nil) when nothing needs to move, so the caller can skip Execute (B3).
--- @param compiled table  [slotName] = ItemRecord (`{ id = 0 }` = must be empty)
--- @param cache table     an inventory cache
--- @param ctx table|nil   see the header
--- @return table[] changes
function Changes.Build(compiled, cache, ctx)
    ctx = ctx or {}
    local env = { cache = cache, pass = cache:BeginPass(), ctx = ctx, worn = wornReader(cache, ctx),
                  phantom = ctx.phantom or NS.ItemData.PHANTOM_IDS, changes = {} }
    local work = workingCopy(compiled or {}, env)
    local glitch = addTGFix(env)
    -- The durability order (Q4): the slots that carry durability go first, so an unequip before a
    -- wipe cuts the repair bill.
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do addSlot(env, work, slot, glitch) end
    if #env.changes == 0 then return env.changes end
    Changes.Unique.Order(env.changes)
    Changes.Opt.Apply(env.changes)
    return env.changes
end

--- The moves that take an outfit's items out of where they are (the bank's deposit and withdraw
--- lists; Outfitter.lua:6954-7130): one `{ from = loc, itemName, info }` per item found, in
--- SLOT_NAMES order, each claimed once. `filter(info)` keeps a move (nil keeps all). A `pass` from
--- an earlier call carries its claims over (deposit-others marks the kept outfit first).
--- @param items table  [slotName] = ItemRecord
--- @param cache table
--- @param filter function|nil
--- @param pass table|nil
--- @return table[] changes
--- @return table pass
function Changes.ForMoves(items, cache, filter, pass)
    pass = pass or cache:BeginPass()
    local out, phantom = {}, NS.ItemData.PHANTOM_IDS
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
        local item = items and items[slot]
        if item and not isEmptyMarker(item) and not phantom[item.id] then
            local info = cache:FindOrAlt(item, pass)
            if info and (filter == nil or filter(info)) then
                out[#out + 1] = { from = info.loc, itemName = info.name, info = info }
            end
        end
    end
    return out, pass
end

-- ── Unique.Order (Q7; OutfitterEquipment.lua:165-250, 609-644) ────────────────────────────────

local Unique = {}
Changes.Unique = Unique

-- 1 = no net increase (first), 2 = mixed (a unique swapped for another kind), 3 = increase only
-- (last), with `offsets` added to the change's own deltas.
local function rankOf(change, offsets)
    local neg, pos = false, false
    for key, count in pairs(change.unique) do
        if offsets then count = count + (offsets[key] or 0) end
        if count < 0 then neg = true elseif count > 0 then pos = true end
        if neg and pos then return 2 end
    end
    if pos then return 3 end
    return 1
end
Unique.RankOf = rankOf

-- By rank, then rank2; `seq` (the position before this sort) breaks the remaining ties, so the
-- order is as stable as the passes need.
local function compare(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.rank2 ~= b.rank2 then return a.rank2 < b.rank2 end
    return a.seq < b.seq
end

-- Each returns true to stop the whole order where it stands (the legacy early returns).
local function onRank1(change, index, st)
    for key, count in pairs(change.unique) do st.start[key] = (st.start[key] or 0) + count end
    change.rank2 = index
    st.r1 = st.r1 + 1
end

local function onRank2(change, index, st)
    if st.r1 == 0 then return true end
    change.rank = rankOf(change, st.start)
    if change.rank == 1 then
        st.r1 = st.r1 + 1
        change.rank2 = index
    elseif change.rank == 2 then
        st.r2 = st.r2 + 1
    else
        change.rank2 = index
    end
end

local function onRank3(change, index, st)
    if st.r1 == 0 or st.r2 == 0 then return true end
    change.rank2 = index
end

local ON_RANK = { onRank1, onRank2, onRank3 }

local function orderPasses(changes)
    local prev1, prev2
    for _ = 1, MAX_PASSES do
        for i, c in ipairs(changes) do c.seq = i end
        table.sort(changes, compare)
        local st = { start = {}, r1 = 0, r2 = 0 }
        for index, c in ipairs(changes) do
            if ON_RANK[c.rank](c, index, st) then return end
        end
        if prev1 == st.r1 and prev2 == st.r2 then return end
        prev1, prev2 = st.r1, st.r2
    end
end

--- Order the changes so no unique-equip count rises before another change has freed it (no
--- "already equipped" errors). In place; each change gets `rank` and `rank2`.
--- @param changes table[]
--- @return table[] changes
function Unique.Order(changes)
    for i, c in ipairs(changes) do
        c.unique = c.unique or {}
        c.rank = rankOf(c)
        c.rank2 = NS.ItemData.SLOT_ORDER[c.slot] or i
    end
    orderPasses(changes)
    for _, c in ipairs(changes) do c.seq = nil end
    return changes
end

-- ── Opt.Apply (OutfitterEquipment.lua:351-464, the optimize that never ran) ───────────────────

local Opt = {}
Changes.Opt = Opt

-- The change for `slot` and its index (B1: `c and c.slot == slot`). A TGFix change is a fix-up, not
-- the slot's plan, so it is passed over.
local function findSlot(changes, slot)
    for i, c in ipairs(changes) do
        if c and c.slot == slot and not c.tgFix then return c, i end
    end
    return nil
end
Opt.FindSlot = findSlot

local function moveTo(changes, from, to)
    local c = table.remove(changes, from)
    table.insert(changes, to, c)
end

local function emptyChange(slot)
    local c = newChange(slot)
    c.done = true
    return c
end

-- A change re-aimed to empty `slot` instead (the slot its partner is moving into).
local function reaim(c, slot, slotID)
    c.slot, c.slotID, c.to = slot, slotID, nil
    return c
end

-- The four swap fixes: each answers the changes to run, in order (OutfitterEquipment.lua:252-349).
-- c1 is slot 1's change, c2 slot 2's.
local SWAP = {
    -- slot 1's item moves to slot 2, and slot 1 takes a new item: clear 2, move 1 to 2, fill 1.
    moveOneToTwo = function(c1, c2) return { emptyChange(c2.slot), c2, c1 } end,
    -- slot 1's item moves to slot 2, and slot 1 is left empty: clear 2 instead, then move.
    emptyOneForTwo = function(c1, c2) return { reaim(c1, c2.slot, c2.slotID), c2 } end,
    -- slot 2's item moves to slot 1, and slot 2 takes a new item: clear 1, move 2 to 1, fill 2.
    moveTwoToOne = function(c1, c2) return { emptyChange(c1.slot), c1, c2 } end,
    -- slot 2's item moves to slot 1, and slot 2 is left empty: clear 1 instead, then move.
    emptyTwoForOne = function(c1, c2) return { reaim(c2, c1.slot, c1.slotID), c1 } end,
}

local function swapKind(c1, c2)
    if not c1.to and not c2.to then return nil end
    local twoToOne = c1.to ~= nil and c1.to.slotName == c2.slot
    local oneToTwo = c2.to ~= nil and c2.to.slotName == c1.slot
    -- A straight swap is the client's to do; no move between them needs nothing.
    if twoToOne == oneToTwo then return nil end
    if oneToTwo then return c1.to and "moveOneToTwo" or "emptyOneForTwo" end
    return c2.to and "moveTwoToOne" or "emptyTwoForOne"
end

-- Replace the pair (at i and j) with `seq` where the earlier of them stood. Answers the index the
-- loop resumes after: past `seq` when i came first, else past the changes between them, which the
-- loop has already visited.
local function splice(changes, i, j, seq)
    local lo, hi = math.min(i, j), math.max(i, j)
    table.remove(changes, hi)
    table.remove(changes, lo)
    for k, c in ipairs(seq) do
        c.done = true
        table.insert(changes, lo + k - 1, c)
    end
    if i == lo then return lo + #seq - 1 end
    return hi + #seq - 2
end

local function fixSwap(changes, i, c1, j, c2)
    local kind = swapKind(c1, c2)
    if not kind then return i end
    return splice(changes, i, j, SWAP[kind](c1, c2))
end

local RULES = {}

-- Titan's Grip fix first: it clears the off hand before any main/off-hand move.
function RULES.tgfix(changes, i, c)
    if i ~= 1 then moveTo(changes, i, 1) end
    c.done = true
    return i
end

-- An equipping off hand goes after the main hand (it fails while a two-hander is held); an emptying
-- one goes before it (the Argent Lance fix for Titan's Grip).
function RULES.offhand(changes, i, c)
    local _, j = findSlot(changes, MH)
    if not j then return i end
    if c.to ~= nil and j > i then
        moveTo(changes, i, j)
        return i - 1
    end
    if c.to == nil and j < i then moveTo(changes, i, j) end
    return i
end

-- A two-hander: the off-hand changes go, and ONE clear of the off hand runs before it, unless a
-- TGFix change already clears it (B2).
function RULES.twohand(changes, i, c)
    local k, cleared = 1, false
    while k <= #changes do
        local o = changes[k]
        if o.slot == OH and o.tgFix then cleared = true end
        if o.slot == OH and not o.tgFix then
            table.remove(changes, k)
            if k < i then i = i - 1 end
        else
            k = k + 1
        end
    end
    c.done = true
    if cleared then return i end
    table.insert(changes, i, emptyChange(OH))
    return i + 1
end

-- Rings, trinkets and the weapon pair: re-ordered so each move finds its slot free.
function RULES.swap(changes, i, c, didSlot)
    if didSlot[c.slot] then return i end
    didSlot[c.slot] = true
    local c2, j = findSlot(changes, NS.ItemData.SLOT_SWAP[c.slot])
    if not j then return i end
    return fixSwap(changes, i, c, j, c2)
end

local function classify(c)
    if c.done then return nil end
    if c.tgFix then return "tgfix" end
    if c.slot == OH then return "offhand" end
    if c.meta == TWO_HAND then return "twohand" end
    if NS.ItemData.SLOT_SWAP[c.slot] then return "swap" end
    return nil
end
Opt.Classify = classify

--- Re-order the changes so the client accepts each in turn (INV §3.3). In place, bounded.
--- @param changes table[]
--- @return table[] changes
function Opt.Apply(changes)
    local didSlot, i, steps = {}, 1, 0
    while i <= #changes and steps < MAX_STEPS do
        steps = steps + 1
        local c = changes[i]
        local kind = classify(c)
        if kind then i = RULES[kind](changes, i, c, didSlot) end
        i = i + 1
    end
    return changes
end
