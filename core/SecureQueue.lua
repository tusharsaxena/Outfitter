local _, NS = ...
-- core/SecureQueue.lua — NS.SecureQueue: a protected write runs now, or waits out combat lockdown (events-frames-taint-§2).
--
-- One queue for every secure-environment write this addon makes: the outfit list's and the bar's
-- secure attributes, and the strata, level and toplevel writes on the outfit window, which holds
-- secure children (frame-layering-§4). The old addon dropped such a write in combat without a word.
--
--   NS.SecureQueue.Run(key, fn)  out of lockdown, runs fn now and answers true. In lockdown, files fn
--                                under key and answers false; a later Run of the same key replaces
--                                it (latest wins), and a Run out of lockdown drops a stale one.
--   NS.SecureQueue.Flush()       runs every waiting fn, in first-queued key order, once lockdown has
--                                lifted; answers how many ran. Driven by PLAYER_REGEN_ENABLED, and
--                                safe to call again from another handler of that event (design §7.2).
--   NS.SecureQueue.Clear()       drops every waiting fn and the registration: the stand-down's half
--                                (slash-commands-§7), since AceAddon's UnregisterAllEvents never
--                                reaches this target.
--
-- REGISTERED ONLY WHILE SOMETHING WAITS. The PLAYER_REGEN_ENABLED registration is taken when the
-- first fn is filed and dropped when the queue empties, on one plain AceEvent target built once and
-- re-used, so an idle addon holds no registration here. A plain target, not a bus one: a dropped
-- queue must stay dropped across a stand-up.
--
-- ONE RAISING WRITE CANNOT STRAND THE REST. Each fn runs under pcall; an error goes to the client's
-- error handler and the next key still runs.
--
-- Lockdown is read through NS.Compat.InCombatLockdown (core/Compat.lua) at call time, never
-- UnitAffectingCombat: the two diverge at the combat boundary (events-frames-taint-§2).

local Q = {}
NS.SecureQueue = Q

local EVENT = "PLAYER_REGEN_ENABLED"

local waiting = {}   -- key -> fn
local order = {}     -- the waiting keys, first-queued first (pairs order is not deterministic)
local target         -- the AceEvent target, built on the first deferral and kept

local function locked()
    return NS.Compat.InCombatLockdown()
end

local function arm()
    if not target then
        local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
        if not AceEvent then return end
        target = AceEvent:Embed({})
    end
    NS.SafeRegisterEvent(target, EVENT, function() Q.Flush() end, NS.rejectedEvents)
end

local function disarm()
    if target then target:UnregisterEvent(EVENT) end
end

--- Drop the waiting fn under `key`, and the registration with the last one.
local function drop(key)
    waiting[key] = nil
    for i = #order, 1, -1 do
        if order[i] == key then table.remove(order, i) end
    end
    if #order == 0 then disarm() end
end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

--- Run `fn` now, or file it under `key` until lockdown lifts.
--- @param key string what the write is for ("dock.layers"); one waiting fn per key
--- @param fn function the protected write
--- @return boolean ran  true when fn ran now
function Q.Run(key, fn)
    if not locked() then
        if waiting[key] then drop(key) end
        fn()
        return true
    end
    local first = #order == 0
    if waiting[key] == nil then order[#order + 1] = key end
    waiting[key] = fn
    if first then arm() end
    return false
end

--- Run every waiting fn once lockdown has lifted.
--- @return number ran  0 while still locked or with nothing waiting
function Q.Flush()
    if #order == 0 or locked() then return 0 end
    local keys, fns = order, waiting
    order, waiting = {}, {}
    disarm()
    for _, key in ipairs(keys) do
        local ok, err = pcall(fns[key])
        if not ok then report(err) end
    end
    return #keys
end

--- Drop every waiting fn and the registration.
function Q.Clear()
    order, waiting = {}, {}
    disarm()
end
