local _, NS = ...
-- modules/Companion.lua — NS.Companion: the battle-pet reconciler (design §5.15, INV §3.10).
--
-- A DESIRED STATE, not a command queue. A summon or a dismiss records one wish,
-- `want = { act, guid, tries, deadline }`, and reconcile() makes the journal match it the first time
-- the player can act. A later wish replaces an earlier one, and dismissing the pet of a pending
-- summon cancels the summon.
--
-- THE BLOCKERS (CanAct): flying, combat, dead, feign death, casting, channeling, and less than 3 s
-- since any SummonPetByGUID call (the player's, another addon's, or ours). The call time comes from
-- a post-hook on C_PetJournal.SummonPetByGUID, installed once on the first Resume; a hook cannot be
-- removed, so its body reads the latch first.
--
-- THE CAP (INV §3.10 Fix; the legacy retry ran forever). A blocked pass retries in 1 s and counts a
-- try: at MAX_TRIES it gives up with a debug line. A dismiss also carries a deadline 60 s out, which
-- bounds the auto-summon watch below as well.
--
-- SECRETS. Every name and GUID goes through NS.Secrets.PlainString first (Compat does it too), so a
-- nil or secret value answers false and never raises (INV §3.10 Fix). GUIDs compared here are
-- plain strings from Compat.
--
-- STAND-DOWN (slash-commands-§7). Suspend cancels the ticker and drops the wish; Resume installs the
-- hook once and is otherwise a no-op (a wish does not survive a stand-down). A public call made while
-- stood down answers false and arms nothing.
--
-- CALLS (at call time, no nil guard; design §12): NS.PlayerState for combat, death and the cast
-- flags; NS.States.IsFeigning (P4.14); NS.Compat for the journal, the clock and IsFlying.

local Companion = {}
NS.Companion = Companion

local Compat, Secrets = NS.Compat, NS.Secrets

local MAX_TRIES       = 30   -- blocked passes before a wish is abandoned
local RETRY_DELAY     = 1    -- seconds between passes
local DISMISS_WINDOW  = 60   -- a dismiss (and its auto-summon watch) gives up this long after it is asked
local SUMMON_COOLDOWN = 3    -- seconds after any SummonPetByGUID call before the next one is safe

local want            -- nil | { act = "summon"|"dismiss", guid, tries, deadline }
local ticker          -- the pending reconcile, an AceTimer handle
local lastSummonCall  -- Compat.GetTime() of the last SummonPetByGUID call, nil before the first
local timers          -- the AceTimer target
local hooked = false

local function debug(fmt, ...) NS.Debug("Pet", fmt, ...) end

-- ── the blockers ──────────────────────────────────────────────────────────────────────────────

local function recentSummon()
    return lastSummonCall ~= nil and Compat.GetTime() - lastSummonCall < SUMMON_COOLDOWN
end

-- In order: the first that holds is the reason CanAct answers.
local BLOCKERS = {
    { "flying",     function() return Compat.IsFlying() end },
    { "combat",     function() return NS.PlayerState.InCombat() end },
    { "dead",       function() return NS.PlayerState.IsDead() end },
    { "feign",      function() return NS.States.IsFeigning() end },
    { "casting",    function() return NS.PlayerState.IsCasting() end },
    { "channeling", function() return NS.PlayerState.IsChanneling() end },
    { "recent",     recentSummon },
}

--- Whether a summon or a dismiss can go through now.
--- @return boolean ok, string|nil reason  the first blocker that holds ("flying", "combat", ...)
function Companion.CanAct()
    for i = 1, #BLOCKERS do
        local b = BLOCKERS[i]
        if b[2]() then return false, b[1] end
    end
    return true
end

--- The summoned companion's GUID, or nil.
--- @return string|nil
function Companion.Summoned() return Compat.SummonedPetGUID() end

-- ── the reconciler ────────────────────────────────────────────────────────────────────────────

local reconcile

local function cancelTicker()
    if ticker and timers then timers:CancelTimer(ticker) end
    ticker = nil
end

local function schedule(delay)
    cancelTicker()
    ticker = timers:ScheduleTimer(reconcile, delay)
end

local function giveUp(why)
    debug("%s %s: gave up (%s)", want.act, want.guid, why)
    want = nil
end

--- Come back in a second, unless the wish has run out: `blocked` passes count against MAX_TRIES,
--- and every pass of a dismiss is bounded by its deadline.
local function retry(blocked)
    if blocked then want.tries = want.tries + 1 end
    if want.tries >= MAX_TRIES then return giveUp("tries") end
    if want.deadline and Compat.GetTime() >= want.deadline then return giveUp("deadline") end
    schedule(RETRY_DELAY)
end

local function reconcileDismiss(summoned)
    -- If there's not a pet summoned but there's a pet to be dismissed
    -- then reschedule in order to watch for the pet getting auto-summoned
    -- by the game.  For example, if you summon Ragnaros upon opening the
    -- cooking window, then mount up and fly off without closing the window,
    -- there will no longer be a pet summoned.  If you then close the cooking
    -- window it will try to dismiss Ragnaros but won't see anything currently
    -- summoned (the game auto-dismissed Ragnaros when you started flying).
    -- We want to watch for a pet to be auto-summoned by the game and then dismiss
    -- it if it's the one we were trying to get rid of
    if not summoned then return retry(false) end
    -- SummonPetByGUID on the pet that is out dismisses it; another pet out is left alone.
    if summoned == want.guid then Compat.SummonPet(want.guid) end
    debug("dismiss %s: done", want.guid)
    want = nil
end

reconcile = function()
    ticker = nil
    if NS.IsStoodDown() or not want then return end
    local ok, why = Companion.CanAct()
    if not ok then
        debug("%s %s: blocked (%s)", want.act, want.guid, why)
        return retry(true)
    end
    local summoned = Compat.SummonedPetGUID()
    if want.act == "dismiss" then return reconcileDismiss(summoned) end
    -- The pet already out is the one wished for: a call would toggle it away.
    if summoned ~= want.guid then Compat.SummonPet(want.guid) end
    debug("summon %s: done", want.guid)
    want = nil
end

--- Record a wish and reconcile now, or after `delay` seconds.
local function wish(act, guid, delay)
    want = { act = act, guid = guid, tries = 0,
             deadline = act == "dismiss" and Compat.GetTime() + DISMISS_WINDOW or nil }
    delay = Secrets.PlainNumber(delay)
    if delay and delay > 0 then
        schedule(delay)
    else
        cancelTicker()
        reconcile()
    end
    return true
end

-- A plain GUID while standing up, else nil.
local function usable(guid)
    if NS.IsStoodDown() then return nil end
    return Secrets.PlainString(guid)
end

-- ── the surface ───────────────────────────────────────────────────────────────────────────────

--- Summon the pet `guid`, now or after `delay` seconds.
--- @return boolean accepted  false for a nil or secret GUID, or while stood down
function Companion.SummonByGUID(guid, delay)
    guid = usable(guid)
    if not guid then return false end
    return wish("summon", guid, delay)
end

--- Summon the first owned pet whose species name is `name` (case-insensitive).
--- @return boolean accepted  false for a nil, secret or unknown name
function Companion.SummonByName(name, delay)
    local plain = usable(name) and Compat.PetGUIDByName(name)
    if not plain then
        debug("summon by name: no pet named %s", NS.SafeToString(name))
        return false
    end
    return wish("summon", plain, delay)
end

--- Summon the first owned pet of `speciesID`.
--- @return boolean accepted
function Companion.SummonBySpecies(speciesID, delay)
    if NS.IsStoodDown() then return false end
    local guid = Compat.PetGUIDBySpecies(speciesID)
    if not guid then return false end
    return wish("summon", guid, delay)
end

--- Dismiss the pet `guid` (now, or after `delay` seconds). Dismissing the pet of a pending summon
--- cancels the summon instead.
--- @return boolean accepted
function Companion.DismissByGUID(guid, delay)
    guid = usable(guid)
    if not guid then return false end
    if want and want.act == "summon" and want.guid == guid then
        cancelTicker()
        want = nil
        debug("summon %s: canceled by a dismiss", guid)
        return true
    end
    return wish("dismiss", guid, delay)
end

--- Dismiss the first owned pet whose species name is `name` (case-insensitive).
--- @return boolean accepted
function Companion.DismissByName(name)
    local plain = usable(name) and Compat.PetGUIDByName(name)
    if not plain then return false end
    return Companion.DismissByGUID(plain)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

local function onSummonCall()
    if NS.IsStoodDown() then return end
    lastSummonCall = Compat.GetTime()
end

--- The lifecycle's stand-down (design §5.12): the ticker goes and the wish with it.
function Companion.Suspend()
    cancelTicker()
    want = nil
end

--- The stand-up: install the SummonPetByGUID hook the first time; nothing else to rebuild.
function Companion.Resume()
    if not timers then timers = LibStub("AceTimer-3.0"):Embed({}) end
    if not hooked then hooked = Compat.HookPetSummon(onSummonCall) end
end
