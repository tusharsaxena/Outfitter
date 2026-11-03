local _, NS = ...
-- modules/States.lua — NS.States: auras, forms, the poll, Dining, Spirit and the tooltip hooks (design §6.10).
--
-- THE STATE PRODUCERS. Each named state (MOUNTED, SWIMMING, DINING, SPIRIT_REGEN, STEALTH, GHOST_WOLF,
-- FEIGN_DEATH, the six druid forms, and the 33 zone ids modules/States_Zone.lua drives) is a boolean
-- held here and changed only through States.Set, which publishes STATE_CHANGED (stateId, isActive) on
-- each edge. The binder turns the pseudo key "STATE:<id>" into a subscription to that one message
-- (design §6.7, §6.9): no state ever reaches RegisterEvent.
--
-- SECRET VALUES (design §6.12). This is the one module outside the compat family allowed to name the
-- securable unit and aura reads, and every one of them leaves through NS.Secrets before it is
-- compared: a secret aura is skipped (IsSecret BEFORE the nil test, INV §8.1), a secret field matches
-- nothing, and a secret health or power reading never counts as full. While an add-on restriction is
-- active the aura getters raise, so they are not called at all and every aura state reads false.
--
-- REGISTRANTS (events-frames-taint-§1). The game events and every timer ride this module's own
-- AceEvent+AceTimer target; each unit event rides a hidden frame of its own, registered for the
-- player only: the aura frame always, the Dining frame only while DINING is on (INV §8.1 Fix), the
-- Spirit frame only while some binding demands STATE:SPIRIT_REGEN (design §6.10).
--
-- STAND-DOWN (slash-commands-§7). Suspend drops every registration and timer and clears the state
-- table; Resume rebuilds them and re-runs the zone, aura and form checks from the client's current
-- state. Every handler and timer body also reads the latch first. The GameTooltip hooks cannot be
-- unhooked: they are installed once and their bodies gate on the latch and on Demand("TOOLTIP").
--
-- CALLS (at call time, no nil guard; design §12): NS.Equip.Batch around every group of Sets, so the
-- equipment update they ask for runs once; NS.Equip.SuspendedForLoad (UNIT_AURA is dropped and the
-- forms re-poll during a load); NS.Triggers.ForState and NS.Stack.IsWorn for the first-sighting seed;
-- NS.PlayerState.InCombat and SetMaybeInCombat; NS.Outfits for the worn outfits' triggers.

local S = {}
NS.States = S

local Compat, Secrets, D = NS.Compat, NS.Secrets, NS.TriggerData

local MAX_AURAS = 100              -- the scan's bound (Outfitter.cMaxScannedAuras)
local COMBAT_SCAN_DELAY = 2.0      -- the unique in-combat re-scan
local FORM_POLL_DELAY = 0.01       -- the form poll after a scan ("since 2.3 shapeshift info is late")
local FORM_REPOLL_DELAY = 0.1      -- the form re-poll while suspended for a load (4787-4796)
local POLL_PERIOD = 0.5            -- the mounted / swimming poll
local SPIRIT_WINDOW = 10           -- a mana drop this long after UNIT_SPELLCAST_SENT is the cast's
local SPIRIT_REENABLE = 5.0        -- the five-second rule
local FULL = 0.85                  -- PlayerIsFull's threshold
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0

local SPIRIT_KEY, TOOLTIP_KEY = "STATE:SPIRIT_REGEN", "TOOLTIP"

--- The non-zone state ids, in a fixed order (design §6.10).
S.STATES = { "MOUNTED", "SWIMMING", "DINING", "SPIRIT_REGEN", "STEALTH", "GHOST_WOLF", "FEIGN_DEATH",
             "FORM_CASTER", "FORM_BEAR", "FORM_CAT", "FORM_TRAVEL", "FORM_MOONKIN", "FORM_TREE" }

local known = {}
for _, id in ipairs(S.STATES) do known[id] = true end
for _, row in ipairs(NS.Zones.rows) do known[row.id] = true end

-- The states an aura can set, from the two aura tables, sorted: the scan sets each of them every
-- time, on or off, so a fade is an edge.
local AURA_STATES = {}
do
    local seen = {}
    for _, t in ipairs({ D.AURA_ICON_STATE, D.AURA_SPELL_STATE }) do
        for _, id in pairs(t) do
            if not seen[id] then
                seen[id] = true
                AURA_STATES[#AURA_STATES + 1] = id
            end
        end
    end
    table.sort(AURA_STATES)
end

-- The restriction types the aura reads avoid, resolved BY NAME: Combat is 0, and a lookup that read
-- nil would leave a hole a truthiness test cannot see (INV §8.1).
local RESTRICTIONS = {}
do
    local E = Enum and Enum.AddOnRestrictionType
    if E then
        for _, name in ipairs({ "Combat", "Encounter", "ChallengeMode", "PvPMatch" }) do
            if E[name] ~= nil then RESTRICTIONS[#RESTRICTIONS + 1] = E[name] end
        end
    end
end

local state = {}                   -- [id] = true | false; nil until first seen
local demand = {}                  -- [key] = count, from the binder (Demand)
local formCache = {}               -- [form index] = state id: the runtime form-index cache (C9)
local auraSpells = {}              -- the plain spell ids of the last scan, for PlayerHasSpell
local feigning = false
local auraStealth, formStealth = false, false
local formsRead = false            -- a form poll (or the scan's own read) has run since the stand-up
local prevMana, sentAt             -- Spirit: the last plain mana reading, the last cast's send time
local active = false               -- resumed
local diningWatched = false

local target                       -- the AceEvent + AceTimer target
local auraFrame, diningFrame, spiritFrame
local combatTimer, formTimer, spiritTimer
local hooked = false

-- ── Set and the seed ──────────────────────────────────────────────────────────────────────────

--- Whether any worn outfit carries a trigger that subscribes to `id` (WearingOutfitWithScriptID,
--- Outfitter.lua:4881-4885): a state first seen while its outfit is already on is no edge.
local function wornFor(id)
    local want, any = {}, false
    for _, tid in ipairs(NS.Triggers.ForState(id)) do
        want[tid] = true
        any = true
    end
    if not any then return false end
    local O = NS.Outfits
    for _, category in ipairs(O.Categories()) do
        for oid, rec in O.Each(category) do
            local trigger = rec.trigger
            if type(trigger) == "table" and want[trigger.id] and NS.Stack.IsWorn(oid) then return true end
        end
    end
    return false
end

local function setDiningWatch(on)
    if diningWatched == on then return end
    diningWatched = on
    if not diningFrame then return end
    diningFrame:UnregisterAllEvents()
    if not on then return end
    NS.SafeRegisterUnitEvent(diningFrame, "UNIT_HEALTH", NS.rejectedEvents, "player")
    NS.SafeRegisterUnitEvent(diningFrame, "UNIT_POWER_UPDATE", NS.rejectedEvents, "player")
end

--- Set a state (SetSpecialOutfitEnabled, Outfitter.lua:4876-4915): the value is coerced to a boolean,
--- a nil state is seeded from the worn outfits, an unchanged value is a no-op, and an edge publishes
--- STATE_CHANGED. The Dining watch follows DINING. An unknown id is a debug line, never a raise.
--- @param id string
--- @param on any
--- @return boolean changed
function S.Set(id, on)
    if not known[id] then
        NS.Debug("States", "unknown state %s", tostring(id))
        return false
    end
    on = on and true or false
    if state[id] == nil then state[id] = wornFor(id) end
    if id == "DINING" then setDiningWatch(on) end
    if state[id] == on then return false end
    state[id] = on
    NS.SendBus(NS.MSG.STATE_CHANGED, id, on)
    return true
end

--- @param id string
--- @return boolean
function S.IsActive(id) return state[id] == true end

-- ── the reads ─────────────────────────────────────────────────────────────────────────────────

--- Whether an add-on restriction that makes the aura getters raise is active (INV §8.1). A sealed
--- answer is taken as restricted: the safe side is not to read.
--- @return boolean
function S.AuraRestricted()
    local api = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
    if not api then return false end
    for _, kind in ipairs(RESTRICTIONS) do
        local on = api(kind)
        if Secrets.IsSealed(on) or on == true then return true end
    end
    return false
end

--- Health at least 85 %, and mana above 85 % (a power other than mana counts as full). Every unreadable
--- or secret reading means NOT full (Outfitter.lua:1887-1930, both past bugs kept fixed).
--- @return boolean
function S.PlayerIsFull()
    local hp, hpMax = Secrets.PlainNumber(UnitHealth("player")), Secrets.PlainNumber(UnitHealthMax("player"))
    if not hp or not hpMax or hpMax == 0 or hp < hpMax * FULL then return false end
    local powerType = Secrets.PlainNumber(UnitPowerType("player"))
    if not powerType then return false end
    if powerType ~= MANA then return true end
    local p, pMax = Secrets.PlainNumber(UnitPower("player")), Secrets.PlainNumber(UnitPowerMax("player"))
    if not p or not pMax or pMax == 0 then return false end
    return p > pMax * FULL
end

--- Whether the last aura scan saw this plain spell id on the player (HAS_BUFF, design §6.8 row 19).
--- @param spellID number
--- @return boolean
function S.PlayerHasSpell(spellID) return auraSpells[spellID] == true end

--- Feign Death is up (Companion reads it, design §6.10).
--- @return boolean
function S.IsFeigning() return feigning end

--- The binder's demand count for `key` ("STATE:SPIRIT_REGEN", "TOOLTIP"): `delta` adds (never below
--- zero); without one it reads. The Spirit watch is registered while its count is above zero.
--- @param key string
--- @param delta number|nil
--- @return number
function S.Demand(key, delta)
    local n = demand[key] or 0
    if delta == nil then return n end
    local after = math.max(0, n + delta)
    demand[key] = after
    if key == SPIRIT_KEY and (n == 0) ~= (after == 0) then S.SyncSpiritWatch() end
    return after
end

-- ── the aura scan ─────────────────────────────────────────────────────────────────────────────

-- One aura's state, icon first (cAuraIconSpecialID), then spell; and its plain spell id.
local function noteAura(aura, want, spells)
    local icon, spell = Secrets.PlainNumber(aura.icon), Secrets.PlainNumber(aura.spellId)
    local id = (icon and D.AURA_ICON_STATE[icon]) or (spell and D.AURA_SPELL_STATE[spell])
    if id then want[id] = true end
    if spell then spells[spell] = true end
end

-- Bounded rather than to the first empty index: a secret aura cannot be told from the end of the
-- list without inspecting it, so IsSecret runs first and a secret is skipped (INV §8.1).
local function readAuras(want, spells)
    if S.AuraRestricted() then return end
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return end
    for i = 1, MAX_AURAS do
        local aura = get("player", i)
        if not Secrets.IsSecret(aura) then
            if aura == nil then return end
            noteAura(aura, want, spells)
        end
    end
end

local readForms

-- Rogue Stealth is a form with no aura (FORM_SPELL_STATE only): until the first form poll after a
-- stand-up, read the forms here, or the merge below would see formStealth false and take a worn
-- Stealth outfit off for the 0.01 s until the poll puts it back.
local function primeFormStealth()
    if formsRead then return end
    formsRead = true
    local _, on = readForms()
    formStealth = on == "STEALTH"
end

-- Riding: on a mount and not on a taxi. The aura scan reads it as well as the poll, since mounting
-- fires UNIT_AURA (UpdateAuraStates ran UpdateMountedState, Outfitter.lua:4768).
local function applyMounted()
    S.Set("MOUNTED", Secrets.PlainTruth(IsMounted()) == true and Secrets.PlainTruth(UnitOnTaxi("player")) ~= true)
end

local function applyAuras(want)
    primeFormStealth()
    for _, id in ipairs(AURA_STATES) do
        local on = want[id] == true
        if id == "STEALTH" then
            auraStealth = on
            on = on or formStealth
        elseif id == "DINING" then
            -- Don't wear the dining outfit when health and mana are almost topped up (INV §8.4).
            on = on and not S.PlayerIsFull()
        end
        S.Set(id, on)
    end
    applyMounted()
end

local pollForms

local function scheduleFormPoll(delay)
    if formTimer then target:CancelTimer(formTimer) end
    formTimer = target:ScheduleTimer(pollForms, delay)
end

--- Scan the player's auras and set every aura state and MOUNTED, inside one Batch; then publish AURAS_SCANNED
--- and poll the forms 0.01 s later. Perf bucket auraScan.
local function scanAuras()
    if combatTimer then target:CancelTimer(combatTimer) end
    combatTimer = nil
    if not active or NS.IsStoodDown() then return end
    local Perf = NS.Perf
    local t0 = Perf.on and debugprofilestop()
    local want, spells = {}, {}
    readAuras(want, spells)
    auraSpells = spells
    feigning = want.FEIGN_DEATH == true
    NS.Equip.Batch(applyAuras, want)
    NS.SendBus(NS.MSG.AURAS_SCANNED)
    scheduleFormPoll(FORM_POLL_DELAY)
    if t0 then Perf.Note("auraScan", debugprofilestop() - t0) end
end

-- The player's UNIT_AURA: dropped during a load, a unique 2 s scan in combat, otherwise at once.
local function onAura(_, _, unit)
    if NS.IsStoodDown() or unit ~= "player" then return end
    if NS.Equip.SuspendedForLoad() then return end
    if NS.PlayerState.InCombat() then
        if not combatTimer then combatTimer = target:ScheduleTimer(scanAuras, COMBAT_SCAN_DELAY) end
        return
    end
    scanAuras()
end

-- ── the forms ─────────────────────────────────────────────────────────────────────────────────

-- The forms the client lists: the states seen inactive (in index order) and the active one. An index
-- whose spell id cannot be read answers from the cache; a druid in no form is FORM_CASTER.
readForms = function()
    local off, on = {}, nil
    local n = Secrets.PlainNumber(GetNumShapeshiftForms()) or 0
    for index = 1, n do
        local _, isActive, _, spellID = GetShapeshiftFormInfo(index)
        local spell = Secrets.PlainNumber(spellID)
        local id = spell and D.FORM_SPELL_STATE[spell]
        if id then formCache[index] = id else id = formCache[index] end
        if id then
            if Secrets.PlainTruth(isActive) then on = id else off[#off + 1] = id end
        end
    end
    if Compat.PlayerClass() == "DRUID" then
        if on then off[#off + 1] = "FORM_CASTER" else on = "FORM_CASTER" end
    end
    return off, on
end

local function setForm(id, on)
    if id == "STEALTH" then
        formStealth = on
        S.Set("STEALTH", auraStealth or formStealth)
        return
    end
    if S.Set(id, on) and on and D.FORM_MAYBE_IN_COMBAT[id] then NS.PlayerState.SetMaybeInCombat(true) end
end

local function applyForms(off, on)
    formsRead = true
    for _, id in ipairs(off) do setForm(id, false) end
    if on then setForm(on, true) end
end

-- During a loading screen the forms vanish briefly: re-poll every 0.1 s until the load is over,
-- rather than strip the gear and put it back (4787-4796).
pollForms = function()
    formTimer = nil
    if not active or NS.IsStoodDown() then return end
    if NS.Equip.SuspendedForLoad() then return scheduleFormPoll(FORM_REPOLL_DELAY) end
    NS.Equip.Batch(applyForms, readForms())
end

-- ── the poll ──────────────────────────────────────────────────────────────────────────────────

local function applyPoll()
    applyMounted()
    S.Set("SWIMMING", Secrets.PlainTruth(IsSwimming()) == true)
end

local function poll()
    if not active or NS.IsStoodDown() then return end
    NS.Equip.Batch(applyPoll)
end

-- ── Dining and Spirit ─────────────────────────────────────────────────────────────────────────

-- While dining, a full reading takes the outfit off (INV §8.4).
local function onDining(_, _, unit)
    if NS.IsStoodDown() or unit ~= "player" or state.DINING ~= true then return end
    if S.PlayerIsFull() then NS.Equip.Batch(S.Set, "DINING", false) end
end

local function spiritReenable()
    spiritTimer = nil
    if not active or NS.IsStoodDown() then return end
    NS.Equip.Batch(S.Set, "SPIRIT_REGEN", true)
end

-- A mana drop within ten seconds of a cast begins the five-second rule. The last plain reading is
-- kept through a secret sample: a nil would make the next real one look like a drop (INV §8.4).
local function checkManaDrop()
    local mana = Secrets.PlainNumber(UnitPower("player", MANA))
    if mana and (prevMana == nil or mana < prevMana) and sentAt and Compat.GetTime() < sentAt + SPIRIT_WINDOW then
        sentAt = nil
        S.Set("SPIRIT_REGEN", false)
        if spiritTimer then target:CancelTimer(spiritTimer) end
        spiritTimer = target:ScheduleTimer(spiritReenable, SPIRIT_REENABLE)
    end
    if mana then prevMana = mana end
end

local function onSpirit(_, event, unit, powerToken)
    if NS.IsStoodDown() or unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_SENT" then
        sentAt = Compat.GetTime()
    elseif Secrets.PlainEquals(powerToken, "MANA") then
        NS.Equip.Batch(checkManaDrop)
    end
end

--- Register the Spirit watch while resumed and demanded; drop it (and its re-enable) otherwise.
function S.SyncSpiritWatch()
    if not spiritFrame then return end
    spiritFrame:UnregisterAllEvents()
    if not (active and (demand[SPIRIT_KEY] or 0) > 0) then
        if spiritTimer then target:CancelTimer(spiritTimer) end
        spiritTimer, sentAt = nil, nil
        return
    end
    NS.SafeRegisterUnitEvent(spiritFrame, "UNIT_SPELLCAST_SENT", NS.rejectedEvents, "player")
    NS.SafeRegisterUnitEvent(spiritFrame, "UNIT_POWER_UPDATE", NS.rejectedEvents, "player")
end

-- ── the tooltip ───────────────────────────────────────────────────────────────────────────────

local function tooltipWanted()
    return not NS.IsStoodDown() and (demand[TOOLTIP_KEY] or 0) > 0
end

local function onTipShow() if tooltipWanted() then NS.SendBus(NS.MSG.TOOLTIP_SHOWN) end end
local function onTipHide() if tooltipWanted() then NS.SendBus(NS.MSG.TOOLTIP_HIDDEN) end end

-- Once: a hook cannot be taken off, so its body is what stands down (design §5.12). The MobInfo2
-- tooltip hook is dropped (INV §17).
local function installTooltipHooks()
    if hooked or not (GameTooltip and GameTooltip.HookScript) then return end
    hooked = true
    GameTooltip:HookScript("OnShow", onTipShow)
    GameTooltip:HookScript("OnHide", onTipHide)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

-- The aura triggers besides UNIT_AURA: a buff that survived a fight fires no UNIT_AURA, and every
-- loading screen re-reads (INV §6.1).
local EVENT_NAMES = { "PLAYER_REGEN_ENABLED", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD" }

local function onEvent()
    if NS.IsStoodDown() then return end
    scanAuras()
end

local function unitFrame(handler)
    local f = CreateFrame("Frame")
    f:Hide()
    f:SetScript("OnEvent", handler)
    return f
end

local function ensureRegistrants()
    if not target then
        target = LibStub("AceEvent-3.0"):Embed({})
        LibStub("AceTimer-3.0"):Embed(target)
    end
    if not auraFrame then
        auraFrame, diningFrame, spiritFrame = unitFrame(onAura), unitFrame(onDining), unitFrame(onSpirit)
    end
end

--- The lifecycle's stand-down (design §5.12): every registration and timer goes, and the state table
--- clears, so the next sighting of each state is seeded afresh.
function S.Suspend()
    active = false
    if target then
        target:UnregisterAllEvents()
        target:CancelAllTimers()
    end
    combatTimer, formTimer, spiritTimer = nil, nil, nil
    if auraFrame then auraFrame:UnregisterAllEvents() end
    if spiritFrame then spiritFrame:UnregisterAllEvents() end
    if diningFrame then diningFrame:UnregisterAllEvents() end
    diningWatched = false
    for id in pairs(state) do state[id] = nil end
    auraSpells, feigning, auraStealth, formStealth, formsRead = {}, false, false, false, false
    prevMana, sentAt = nil, nil
    S.SuspendZone()
end

--- The stand-up: register from scratch, then re-run the zone, aura and form checks from the client's
--- current state (the scan and the zone update run on their timers, so nothing equips inside the
--- latch's callback).
function S.Resume()
    ensureRegistrants()
    S.Suspend()
    for _, event in ipairs(EVENT_NAMES) do
        NS.SafeRegisterEvent(target, event, onEvent, NS.rejectedEvents)
    end
    NS.SafeRegisterUnitEvent(auraFrame, "UNIT_AURA", NS.rejectedEvents, "player")
    active = true
    S.SyncSpiritWatch()
    installTooltipHooks()
    target:ScheduleRepeatingTimer(poll, POLL_PERIOD)
    target:ScheduleTimer(scanAuras, 0)
    S.ResumeZone()
end
