local _, NS = ...
-- modules/PlayerState.lua — NS.PlayerState: the combat, dead, cast and spec flags (design §5.2).
--
-- THE ONE OWNER of the player flags (design C18). The triggers, the bar and test mode read them here
-- and never register these events themselves. Each flag that moves is announced once on the bus as
-- PLAYER_STATE_CHANGED (key, value), key one of combat, dead, casting, spec.
--
-- TWO REGISTRANTS (events-frames-taint-§1). The game events ride this module's own AceEvent target;
-- the player's casts ride a hidden frame whose only job is RegisterUnitEvent(..., "player"), so no
-- other unit's cast enters Lua. Both go through the SafeRegister family, so an event a client does
-- not know costs only itself and lands in NS.rejectedEvents.
--
-- STAND-DOWN (slash-commands-§7). Suspend drops both registrations; Resume rebuilds them and then
-- re-reads every flag from the client (Refresh), never from what was held when it went down. Every
-- handler also reads the latch first, so a handler reached anyway writes nothing.
--
-- CASTING rides the cast events, and Refresh also re-reads it through Compat.PlayerCasting (design
-- §5.2), so a cast begun or ended while the module was down is seen on Resume.
--
-- CALLS (at call time, no nil guard; design §12): NS.Equip.Batch on leaving combat (the empty
-- bracket's close flushes the queued swaps), NS.Equip.DelayUntil half a second after a cast or a
-- channel ends (the combat edge arrives after the cast), NS.Equip.Request on coming back to life.

local PS = {}
NS.PlayerState = PS

local Compat, Secrets = NS.Compat, NS.Secrets

local CAST_END_DELAY = 0.5   -- the legacy SetUpdateDelay(GetTime(), 0.5) after a cast or a channel

local flags = { combat = false, maybeCombat = false, dead = false, casting = false, channeling = false,
                spec = nil, interrupt = false }
local lastCastSpellID

local events            -- the AceEvent target for the game events
local castFrame         -- the per-unit frame for the player's casts

-- ── the flags ─────────────────────────────────────────────────────────────────────────────────

--- Set a flag and announce it on the bus as `key` when it moved; answers whether it moved.
local function set(name, value, key)
    if flags[name] == value then return false end
    flags[name] = value
    NS.SendBus(NS.MSG.PLAYER_STATE_CHANGED, key, value)
    return true
end

--- The cast and the channel flags share one bus key, "casting", which reports their union: it is
--- announced only when the union moves (a channel's SENT then CHANNEL_START is one edge, not two).
--- Answers whether the named flag itself moved.
local function setCast(name, value)
    if flags[name] == value then return false end
    local before = flags.casting or flags.channeling
    flags[name] = value
    local after = flags.casting or flags.channeling
    if after ~= before then NS.SendBus(NS.MSG.PLAYER_STATE_CHANGED, "casting", after) end
    return true
end

--- @return boolean  in combat (between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED)
function PS.InCombat() return flags.combat end
--- @return boolean  probably in combat: a form that only combat produces is up (States, design §6.10)
function PS.MaybeInCombat() return flags.maybeCombat end
--- @param on boolean
function PS.SetMaybeInCombat(on) flags.maybeCombat = on and true or false end
--- @return boolean
function PS.IsDead() return flags.dead end
--- @return boolean
function PS.IsCasting() return flags.casting end
--- @return boolean
function PS.IsChanneling() return flags.channeling end
--- The triggers' "may interrupt a cast" flag (OutfitterEquipment.lua:868).
--- @param on boolean
function PS.SetInterruptCasting(on) flags.interrupt = on and true or false end
--- @return boolean
function PS.InterruptCasting() return flags.interrupt end
--- The current specialization index, or nil before the client knows it.
--- @return number|nil
function PS.Spec() return flags.spec end
--- The spell id of the player's last successful cast, plain only (NS.TriggerParams.CaptureLastCast).
--- @return number|nil
function PS.LastCastSpellID() return lastCastSpellID end

--- A Fury warrior grips a two-hander in each hand (Titan's Grip, Outfitter.lua:2249).
--- @return boolean
function PS.CanDualWield2H()
    return Compat.PlayerClass() == "WARRIOR" and flags.spec == 2
end

--- Whether the player can dual wield at all (B15).
--- @return boolean
function PS.CanDualWield() return Compat.CanDualWield() end

--- Both cast flags at once from Compat, announcing the union once if it moved (a cast that became a
--- channel while the module was down is no edge). An unreadable (nil) reading keeps its flag.
local function refreshCast()
    local casting, channeling = Compat.PlayerCasting()
    local before = flags.casting or flags.channeling
    if casting ~= nil then flags.casting = casting end
    if channeling ~= nil then flags.channeling = channeling end
    local after = flags.casting or flags.channeling
    if after ~= before then NS.SendBus(NS.MSG.PLAYER_STATE_CHANGED, "casting", after) end
end

local function readSpec()
    set("spec", Secrets.PlainNumber(Compat.GetSpecialization()), "spec")
end

--- Re-read combat, death, the cast, the channel and spec from the client, announcing each key that
--- moved. Out of combat lockdown it clears both combat flags (the old RegenEnabled); in it, it sets
--- combat. A cast or channel reading that cannot be had (nil) leaves its flag as it was, and a cast
--- found ended here does not delay the equip path: Refresh never equips.
function PS.Refresh()
    local locked = Compat.InCombatLockdown()
    set("combat", locked, "combat")
    if not locked then flags.maybeCombat = false end
    set("dead", Compat.IsDeadOrGhost("player") == true, "dead")
    refreshCast()
    readSpec()
end

-- ── the handlers ──────────────────────────────────────────────────────────────────────────────

local function castEnded()
    NS.Equip.DelayUntil(Compat.GetTime() + CAST_END_DELAY)
end

local function onCastStart() setCast("casting", true) end

local function onCastStop()
    if setCast("casting", false) then castEnded() end
end

local function onSucceeded(_, spellID)
    local id = Secrets.PlainNumber(spellID)
    if id then lastCastSpellID = id end
    onCastStop()
end

local function onChannelStart() setCast("channeling", true) end

local function onChannelStop()
    if not flags.channeling then return end
    setCast("casting", false)
    setCast("channeling", false)
    castEnded()
end

local function onAlive()
    set("dead", Compat.IsDeadOrGhost("player") == true, "dead")
    NS.Equip.Request()
end

local ON = {
    PLAYER_REGEN_DISABLED = function() set("combat", true, "combat") end,
    PLAYER_REGEN_ENABLED = function()
        flags.maybeCombat = false
        set("combat", false, "combat")
        NS.Equip.Batch(function() end)
    end,
    PLAYER_DEAD = function() set("dead", true, "dead") end,
    PLAYER_ALIVE = onAlive,
    PLAYER_UNGHOST = onAlive,
    PLAYER_TALENT_UPDATE = readSpec,
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED = readSpec,
    PLAYER_ENTERING_WORLD = function() PS.Refresh() end,
}

-- The casts, each event with what it means; every one is the player's only.
local ON_CAST = {
    UNIT_SPELLCAST_SENT = onCastStart,
    UNIT_SPELLCAST_START = onCastStart,
    UNIT_SPELLCAST_STOP = onCastStop,
    UNIT_SPELLCAST_INTERRUPTED = onCastStop,
    UNIT_SPELLCAST_FAILED = onCastStop,
    UNIT_SPELLCAST_FAILED_QUIET = onCastStop,
    UNIT_SPELLCAST_SUCCEEDED = onSucceeded,
    UNIT_SPELLCAST_CHANNEL_START = onChannelStart,
    UNIT_SPELLCAST_CHANNEL_STOP = onChannelStop,
}

-- Registration order is fixed (pairs is not): the event names, in a stable order.
local EVENT_NAMES = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE",
                      "PLAYER_UNGHOST", "PLAYER_TALENT_UPDATE", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
                      "PLAYER_ENTERING_WORLD" }
local CAST_NAMES = { "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
                     "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET",
                     "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }

local function onEvent(event, ...)
    if NS.IsStoodDown() then return end
    local fn = ON[event]
    if fn then fn(...) end
end

-- unit, castGUID, spellID: the client's argument order for every UNIT_SPELLCAST_* above.
local function onCastEvent(_, event, unit, _, spellID)
    if NS.IsStoodDown() or unit ~= "player" then return end
    local fn = ON_CAST[event]
    if fn then fn(unit, spellID) end
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

local function ensureRegistrants()
    if not events then events = LibStub("AceEvent-3.0"):Embed({}) end
    if not castFrame then
        castFrame = CreateFrame("Frame")
        castFrame:Hide()
        castFrame:SetScript("OnEvent", onCastEvent)
    end
end

--- The lifecycle's stand-down (design §5.12): every registration goes.
function PS.Suspend()
    if events then events:UnregisterAllEvents() end
    if castFrame then castFrame:UnregisterAllEvents() end
end

--- The stand-up: register from scratch, then read the current state.
function PS.Resume()
    ensureRegistrants()
    PS.Suspend()
    for _, event in ipairs(EVENT_NAMES) do
        NS.SafeRegisterEvent(events, event, onEvent, NS.rejectedEvents)
    end
    for _, event in ipairs(CAST_NAMES) do
        NS.SafeRegisterUnitEvent(castFrame, event, NS.rejectedEvents, "player")
    end
    PS.Refresh()
end
