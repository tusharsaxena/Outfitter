local _, NS = ...
-- modules/Equip.lua — NS.Equip: the bracket that cannot strand, its gates, execution and SFX (design
-- §5.10; OutfitterEquipment.lua:466-535, 802-985 and Outfitter.lua:1525-1561, 7536-7542 at 7ea3dc3).
--
-- THE ONE BRACKET. E.Batch(fn, ...) runs fn with the depth raised and lowers it again however fn
-- leaves: the legacy Begin/End pair was manual, and a raise between them stranded the count and
-- stopped every swap for the session (INV §3.3). The last Batch to close flushes: it runs the update
-- now (E.BatchNow) or schedules it, then announces STACK_CHANGED when the stack moved inside it
-- (E.Request or E.Touch marked it): a bracket that only grouped producer Sets stays quiet. A raise is surfaced, never
-- swallowed: the trace goes to the debug console, one line per tag per session goes to chat, and
-- the client's error handler gets the error AFTER the depth is restored.
--
-- BELT AND BRACES. The depth never goes below zero; Suspend and Resume zero it; the debounced
-- PLAYER_ENTERING_WORLD zeroes a stranded one (and says so) before opening its own Batch (INV §16
-- #4), and E.Diagnostic() carries the STUCK tripwire.
--
-- THE UPDATE. E.Update walks GATES in order and the first that matches decides: nothing needed,
-- dead, casting (unless a trigger may interrupt it), an explicit delay, the 1.5 s throttle, combat.
-- Past them it compiles the stack, builds the change list (NS.Changes, pure) and executes it.
--
-- EXECUTION. E.Execute does nothing for an empty list (B3). With `equip.muteSounds` on it mutes the
-- SFX CVar for the swap and ALWAYS restores it, a raise included (B8, INV §16 #13), after clearing
-- the cursor.
--
-- CALLS (at call time, no nil guard; design §12): NS.Stack.Compile/SetExpected/CheckComplete and NS.EM.Sync (the
-- PLAYER_ENTERING_WORLD batch); NS.PlayerState, NS.Inventory, NS.Changes, NS.Moves.

local E = {}
NS.Equip = E

local Compat = NS.Compat
local L = NS.L
local Perf = NS.Perf

local MIN_INTERVAL = 1.5   -- cMinEquipmentUpdateInterval (Outfitter.lua:453)
local MIN_DELAY = 0.05     -- ScheduleEquipmentUpdate's floor (OutfitterEquipment.lua:977)
local PEW_DELAY = 0.05     -- SchedulePlayerEnteringWorld's debounce (Outfitter.lua:1521)
local SFX_CVAR = "Sound_EnableSFX"
local GENERAL = 0          -- the general bag family

-- The session state (design §5.10). `frames` counts the Batch calls on the stack, so the tripwire can
-- tell a depth that belongs to a running Batch from one nothing will ever lower. `touched`: the
-- stack moved inside the open bracket, so its close announces STACK_CHANGED.
local st = { depth = 0, frames = 0, needsUpdate = false, lastUpdate = nil, delayUntil = 0, timer = nil,
             pewTimer = nil, lastError = nil, sfxSaved = nil, pendingNow = false, suspendedForLoad = false,
             touched = false, told = {} }
E.__state = st   -- test seam only

local target     -- the AceEvent + AceTimer target

local function ensureTarget()
    if not target then
        target = LibStub("AceEvent-3.0"):Embed({})
        LibStub("AceTimer-3.0"):Embed(target)
    end
    return target
end

-- ── surfacing ─────────────────────────────────────────────────────────────────────────────────

-- The error and its stack: the client's debugstack, else Lua's own traceback.
local function traceback(err)
    local msg = tostring(err)
    local ds = debugstack
    if type(ds) == "function" then return msg .. "\n" .. tostring(ds(2)) end
    return debug.traceback(msg, 2)
end

--- Record the failure, write its trace to the console (ungated), tell the player once per tag per
--- session, then hand it to the client's error handler. Called only once the depth is restored.
local function surface(tag, err)
    local text = NS.SafeToString(err)
    st.lastError = { tag = tag, err = text, at = Compat.GetTime() }
    if NS.DebugLog and NS.DebugLog.Add then NS.DebugLog:Add("Equip", tag .. ": " .. text) end
    if not st.told[tag] then
        st.told[tag] = true
        NS.Print(L["An equipment update failed (%s); the details are in the debug console"]:format(tag))
    end
    local geh = geterrorhandler
    local handler = type(geh) == "function" and geh()
    if handler then handler(err) end
end

-- ── scheduling ────────────────────────────────────────────────────────────────────────────────

local function runTimer()
    st.timer = nil
    local ok, err = xpcall(E.Update, traceback)
    if not ok then surface("update", err) end
end

--- The next update: when the throttle and any explicit delay allow, never sooner than 0.05 s
--- (max(0.05, 1.5 - elapsed), OutfitterEquipment.lua:967-985). Nothing when nothing is needed.
local function scheduleUpdate()
    if not st.needsUpdate or NS.IsStoodDown() then return end
    local now = Compat.GetTime()
    local due = st.lastUpdate and st.lastUpdate + MIN_INTERVAL or now
    if st.delayUntil > due then due = st.delayUntil end
    local delay = due - now
    if delay < MIN_DELAY then delay = MIN_DELAY end
    local t = ensureTarget()
    if st.timer then t:CancelTimer(st.timer) end
    st.timer = t:ScheduleTimer(runTimer, delay)
end

local function flush(now)
    if now then E.Update() else scheduleUpdate() end
    if st.touched then
        st.touched = false
        NS.SendBus(NS.MSG.STACK_CHANGED)
    end
end

-- ── the bracket ───────────────────────────────────────────────────────────────────────────────

-- Lua 5.1's xpcall forwards no extra arguments, and the kit runs 5.1, so they travel in a closure.
local function run(now, fn, ...)
    st.depth = st.depth + 1
    st.frames = st.frames + 1
    if now then st.pendingNow = true end
    local n, args = select("#", ...), { ... }
    local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, traceback)
    st.frames = st.frames - 1
    st.depth = st.depth - 1
    if st.depth < 0 then st.depth = 0 end   -- the unmatched-close guard (OutfitterEquipment.lua:825-836)
    if st.depth == 0 then
        local pending = st.pendingNow
        st.pendingNow = false
        local fok, ferr = xpcall(function() flush(pending) end, traceback)
        if not fok then surface("flush", ferr) end
    end
    if not ok then surface("batch", err) end
    return ok, err
end

--- Run fn(...) inside the bracket; the last Batch to close schedules the update.
--- @return boolean ok
--- @return string|nil err  the trace, when fn raised
function E.Batch(fn, ...) return run(false, fn, ...) end

--- The same, and the last Batch to close updates NOW (the old EndEquipmentUpdate(nil, true)).
function E.BatchNow(fn, ...) return run(true, fn, ...) end

--- An equipment update is wanted: scheduled at once outside a Batch, at the close inside one, and
--- the open bracket marked so its close announces STACK_CHANGED.
function E.Request()
    if NS.IsStoodDown() then return end
    st.needsUpdate = true
    if st.depth == 0 then scheduleUpdate() else st.touched = true end
end

--- The stack moved without asking for an update (a layer tag, the temporary outfit, a clear): the
--- open bracket's close announces it; outside a bracket it is announced at once.
function E.Touch()
    if st.depth > 0 then
        st.touched = true
    else
        NS.SendBus(NS.MSG.STACK_CHANGED)
    end
end

--- @return boolean  an update is wanted and has not run
function E.Pending() return st.needsUpdate end

--- No update before `t` (a cast's end, PlayerState). A pending one is rescheduled to honor it.
--- @param t number
function E.DelayUntil(t)
    if type(t) ~= "number" then return end
    if t > st.delayUntil then st.delayUntil = t end
    if st.depth == 0 then scheduleUpdate() end
end

--- The legacy rule kept whole (Outfitter.lua:7536-7542): the throttle's clock moves to
--- `start + delay - 1.5`, so the next update is `delay` seconds after `start`.
--- @param start number
--- @param delay number
function E.SetUpdateDelay(start, delay)
    local t = start + (delay - MIN_INTERVAL)
    if st.lastUpdate == nil or t > st.lastUpdate then st.lastUpdate = t end
    if st.depth == 0 then scheduleUpdate() end
end

--- Between PLAYER_LEAVING_WORLD and PLAYER_ENTERING_WORLD (the scans drop their events then).
--- @return boolean
function E.SuspendedForLoad() return st.suspendedForLoad end

-- ── the gates ─────────────────────────────────────────────────────────────────────────────────

local function inCombat(PS)
    return PS.InCombat() or PS.MaybeInCombat() or Compat.InCombatLockdown()
end

-- Combat keeps the update wanted and retries after the throttle (OutfitterEquipment.lua:897-907):
-- automated swaps have been refused in combat since 3.3.
local function waitOutCombat(PS, now)
    st.lastUpdate = now
    PS.SetMaybeInCombat(false)
    scheduleUpdate()
end

-- In order; the first whose pred holds decides. "wait" returns with the update still wanted (the
-- edge that ends the wait asks again), "reschedule" sets the timer.
local GATES = {
    { name = "idle",     pred = function() return not st.needsUpdate end, action = "return" },
    { name = "dead",     pred = function(PS) return PS.IsDead() end, action = "wait" },
    { name = "casting",  pred = function(PS)
        return (PS.IsCasting() or PS.IsChanneling()) and not PS.InterruptCasting()
    end, action = "wait" },
    { name = "delay",    pred = function(_, now) return now < st.delayUntil end, action = "reschedule" },
    { name = "throttle", pred = function(_, now)
        return st.lastUpdate ~= nil and now - st.lastUpdate < MIN_INTERVAL
    end, action = "reschedule" },
    { name = "combat",   pred = inCombat, action = waitOutCombat },
}
E.GATES = GATES

-- The first gate that holds, acted on; nil when every gate passed.
local function gate(PS, now)
    for _, g in ipairs(GATES) do
        if g.pred(PS, now) then
            if type(g.action) == "function" then g.action(PS, now)
            elseif g.action == "reschedule" then scheduleUpdate() end
            return g.name
        end
    end
    return nil
end

--- Take the worn gear to the compiled stack, unless a gate says not now. Answers the gate that
--- stopped it, or nil when it ran.
--- @return string|nil gate
function E.Update()
    if NS.IsStoodDown() then return "stoodDown" end
    local t0 = Perf.on and debugprofilestop()
    local PS = NS.PlayerState
    local now = Compat.GetTime()
    local stopped = gate(PS, now)
    if not stopped then
        st.lastUpdate = now
        st.needsUpdate = false
        local St = NS.Stack
        local compiled = St.Compile()
        local changes = NS.Changes.Build(compiled, NS.Inventory.Cache(),
            { canDW2H = PS.CanDualWield2H(), showError = E.ShowEquipError })
        if #changes > 0 then
            local t1 = Perf.on and debugprofilestop()
            E.Execute(changes, NS.Moves.EmptyBagSlots())
            if t1 then Perf.Note("equipExecute", debugprofilestop() - t1) end
        end
        St.SetExpected(compiled)
        PS.SetInterruptCasting(false)
        if #changes == 0 then St.CheckComplete() end
    end
    if t0 then Perf.Note("equipUpdate", debugprofilestop() - t0) end
    return stopped
end

-- ── execution ─────────────────────────────────────────────────────────────────────────────────

local function muteSFX()
    if not NS.GetSetting("equip.muteSounds") or st.sfxSaved ~= nil then return end
    local v = Compat.GetCVar(SFX_CVAR)
    if v == nil then return end
    st.sfxSaved = v
    Compat.SetCVar(SFX_CVAR, "0")
end

local function restoreSFX()
    if st.sfxSaved == nil then return end
    local v = st.sfxSaved
    st.sfxSaved = nil
    Compat.SetCVar(SFX_CVAR, v)
end

-- A bag's family: the backpack's is general; any other answers its container's family.
local function bagFamily(bag)
    if bag == 0 then return GENERAL end
    local _, family = Compat.ContainerNumFreeSlots(bag)
    return family
end

local function hasSpecialtySlot(slots, family)
    for _, s in ipairs(slots or {}) do
        if Compat.BitAnd(s.bagType or GENERAL, family) ~= 0 then return true end
    end
    return false
end

--- Whether the worn item has to go to the bags before the new one comes in, rather than swap
--- places with it (OutfitterEquipment.lua:477-500): the new item sits in a specialty bag the worn
--- one cannot enter, or a specialty bag has room for the worn one.
local function needsEmptyThenEquip(change, slots)
    local link = Compat.InventoryItemLink(change.slotID)
    local worn = link and Compat.ItemFamily(link)
    if worn == nil then return false end
    local from = change.to.bag ~= nil and bagFamily(change.to.bag) or nil
    if from and from ~= GENERAL and Compat.BitAnd(from, worn) == 0 then return true end
    return hasSpecialtySlot(slots, worn)
end

-- One change (OutfitterEquipment.lua:501-528): equip into the slot (emptying it first when the bag
-- types say so), move a ForMoves item out, or empty the slot.
local function executeChange(change, slots, errKey)
    local Moves = NS.Moves
    if change.to then
        if needsEmptyThenEquip(change, slots) then
            Moves.ToEmpty({ slotID = change.slotID, slotName = change.slot }, slots, errKey)
        end
        Compat.ClearCursor()   -- holding anything already makes the pickups go wrong
        Moves.Pickup(change.to)
        Compat.EquipCursorItem(change.slotID)
    elseif change.from then
        Moves.ToEmpty(change.from, slots, errKey)
    else
        Moves.ToEmpty({ slotID = change.slotID, slotName = change.slot }, slots, errKey)
    end
end

local function runChanges(changes, slots, errKey)
    for _, change in ipairs(changes) do executeChange(change, slots, errKey) end
end

--- Carry out a change list. Nothing at all for an empty one (B3). The cursor is cleared and the SFX
--- CVar restored however the moves end (B8); a raise is surfaced as "execute".
--- @param changes table[]
--- @param slots table[]|nil   an empty-slot list (NS.Moves.EmptyBagSlots), spent as items land
--- @param fullErrKey string|nil  the bags-full line's key for NS.Moves.ToEmpty (default bagsFull)
--- @return boolean ok
function E.Execute(changes, slots, fullErrKey)
    if not changes or #changes == 0 then return true end
    muteSFX()
    local ok, err = xpcall(function() runChanges(changes, slots, fullErrKey) end, traceback)
    Compat.ClearCursor()
    restoreSFX()
    if not ok then surface("execute", err) end
    return ok, err
end

-- The slot's display label: the ring and trinket L strings, else the client's GlobalString.
local function slotLabel(slot)
    local D = NS.ItemData
    local label = D.SLOT_LABELS[slot]
    if label then return label end
    local key = D.SLOT_LABEL_KEYS[slot]
    local g = key and _G[key]
    if type(g) == "string" then return g end
    return tostring(slot)
end

--- An outfit item that could not be placed (NS.Changes' showError), unless `equip.showErrors` is off
--- (OutfitterEquipment.lua:649-670).
--- @param item table      the ItemRecord
--- @param claimedDup any  truthy: the item is there but another slot already took it
--- @param slot string
function E.ShowEquipError(item, claimedDup, slot)
    if not NS.GetSetting("equip.showErrors") then return end
    local name = NS.SafeToString(item and (item.link or item.name) or "?")
    if claimedDup then
        NS.Print(L["Can't put %s in the %s slot because it's already being used in another slot"]
            :format(name, slotLabel(slot)))
    else
        NS.Print(L["Can't find item %s for slot %s"]:format(name, slotLabel(slot)))
    end
end

-- ── diagnostics ───────────────────────────────────────────────────────────────────────────────

--- The bracket's state for /of zone and the diagnostics dump (design §5.10): depth, whether an
--- update is wanted, when the next one runs, the last error, and the STUCK tripwire.
--- @return string[]
function E.Diagnostic()
    local lines = {}
    local now = Compat.GetTime()
    lines[#lines + 1] = L["Equipment updates: depth %d, update wanted: %s"]
        :format(st.depth, tostring(st.needsUpdate))
    if st.timer and target then
        lines[#lines + 1] = L["Next equipment update in %.1f s"]:format(math.max(0, target:TimeLeft(st.timer)))
    else
        lines[#lines + 1] = L["No equipment update scheduled"]
    end
    if st.lastError then
        lines[#lines + 1] = L["Last equipment error: %s, %d s ago"]
            :format(st.lastError.tag, math.floor(now - st.lastError.at))
    else
        lines[#lines + 1] = L["No equipment errors this session"]
    end
    if st.depth > st.frames then
        lines[#lines + 1] = L["Equipment updates are STUCK (count %d) -- reload to clear"]:format(st.depth)
    end
    return lines
end

-- ── the load screen ───────────────────────────────────────────────────────────────────────────

-- The debounced PLAYER_ENTERING_WORLD (Outfitter.lua:1525-1550): a depth stranded in the last zone is
-- cleared BEFORE this Batch opens (inside it, it would clear the count it had just raised).
local function enteredWorld()
    st.pewTimer = nil
    if NS.IsStoodDown() then return end
    if st.depth ~= 0 then
        local n = st.depth
        st.depth = 0
        surface("pew", ("stranded depth %d"):format(n))
    end
    E.Batch(function()
        local Inv = NS.Inventory
        Inv.Flush()
        Inv.ScheduleSync()
        NS.EM.Sync()
    end)
end

local ON = {
    PLAYER_ENTERING_WORLD = function()
        st.suspendedForLoad = false
        local t = ensureTarget()
        if st.pewTimer then t:CancelTimer(st.pewTimer) end
        st.pewTimer = t:ScheduleTimer(enteredWorld, PEW_DELAY)
    end,
    PLAYER_LEAVING_WORLD = function() st.suspendedForLoad = true end,
}
local EVENT_NAMES = { "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD" }

local function onEvent(event)
    if NS.IsStoodDown() then return end
    local fn = ON[event]
    if fn then fn() end
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

--- The lifecycle's stand-down (design §5.12): the count and the wish go, the timers are canceled,
--- the SFX CVar comes back (H26), and nothing stays registered. The load flag goes too: with the
--- events unregistered, a PLAYER_ENTERING_WORLD missed while stood down could never clear it.
function E.Suspend()
    st.depth, st.needsUpdate, st.pendingNow, st.suspendedForLoad, st.touched = 0, false, false, false, false
    if target then
        target:UnregisterAllEvents()
        target:CancelAllTimers()
    end
    st.timer, st.pewTimer = nil, nil
    restoreSFX()
end

--- The stand-up: a zero count, and the load-screen events registered from scratch.
function E.Resume()
    local t = ensureTarget()
    E.Suspend()
    for _, event in ipairs(EVENT_NAMES) do
        NS.SafeRegisterEvent(t, event, onEvent, NS.rejectedEvents)
    end
end
