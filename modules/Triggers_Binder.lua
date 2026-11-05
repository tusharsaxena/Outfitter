local _, NS = ...
-- modules/Triggers_Binder.lua — NS.TriggerBinder: bind, unbind, dispatch and apply (design §6.9).
--
-- ONE TARGET PER BOUND OUTFIT (H14). Each binding owns an AceEvent+AceTimer target from
-- NS.NewBusTarget (kept per outfit id and reused, so a rebind adds nothing to the bus record; a
-- deleted outfit's target goes to a free list the next new id takes from, so the record is bounded
-- by the most outfits held at once and not by every id the session ever bound), a
-- context `ctx` (design §6.3) and nothing else. Game events go through NS.SafeRegisterEvent; the
-- pseudo events arrive as bus messages through Triggers.PSEUDO; TIMER is the binding's ticker and BIND
-- its one 0 s evaluation. No pseudo key ever reaches RegisterEvent (quirk 8).
--
-- ONE PLAYER UNIT-FILTER FRAME (events-frames-taint-§1). A UNIT_* event of a descriptor with
-- unit = "player" (Spellcast, the vehicle quests) is not on the binding's target: AceEvent has no
-- RegisterUnitEvent, so every unit's cast would enter Lua once per bound outfit. It rides B.unitFrame,
-- one hidden frame held on the module and reused across stand-downs, whose only job is
-- RegisterUnitEvent(event, "player") and one OnEvent that fans out to the contexts bound to it. Its
-- registrations follow the bindings and the stand-down empties it (AceAddon cannot reach it). A non-UNIT
-- event with a unit (PLAYER_FLAGS_CHANGED) keeps the target and the Lua filter.
--
-- DISPATCH is gate -> call -> apply. The condition runs OUTSIDE any equipment bracket, under xpcall,
-- so a raising condition cannot strand the bracket's counter: it faults only its own binding, which is
-- switched off for the session with one line. Its verdict `(action, delay, layer, interrupt)` is
-- applied inside one NS.Equip.Batch (the legacy _ScriptContext:PostProcess, OutfitterScripting.lua:
-- 2155-2186): a Complete outfit is always re-worn so the stack clears, a delay applies only when the
-- outfit changed, and a TAG moves an already-worn outfit to a layer.
--
-- ONE ROUTE FOR auto.enabled. The binder's own SETTINGS_CHANGED handler is how every writer (the
-- panel, /or auto, the AutoOn/AutoOff bindings) reaches SetActive; a profile change reaches it through
-- PROFILE_CHANGED, re-read from the new profile. A loaded legacy Outfitter does not hold binding (O2:
-- warn only).
--
-- REBIND IS COALESCED. OUTFIT_EDITED(id, "trigger") marks the outfit dirty, and one 0 s timer rebinds
-- every dirty outfit: a dialog's SetMany of N params costs one unbind/bind and one BIND evaluation.
-- OUTFIT_ADDED binds at once, OUTFIT_DELETED unbinds at once.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits, NS.Stack, NS.Equip, NS.PlayerState,
-- NS.States.Demand, NS.Triggers, NS.SetByPath, NS.GetSetting.

local B = {}
NS.TriggerBinder = B

local L, Perf = NS.L, NS.Perf
local TRIGGER = "trigger"
local TOOLTIP_KEY = "TOOLTIP"

--- Event names SafeRegisterEvent refused (listed in /or diagnostics).
B.rejected = {}
--- [outfitId .. ":" .. triggerId] = the error text: bindings switched off for this session.
B.faulted = {}
--- [triggerId] = true: ids no descriptor (or no condition) answers, each printed once.
B.unavailable = {}

local bound = {}          -- [outfitId] = ctx
local targets = {}        -- [outfitId] = the reused target
local freeTargets = {}    -- deleted outfits' unbound targets, taken before NS.NewBusTarget
local dirty = {}          -- [outfitId] = true, awaiting the coalesced rebind
local active = false      -- BindAll ran and nothing has unbound everything since
local mod                 -- the module's own target: OUTFIT_*, SETTINGS_CHANGED, PROFILE_CHANGED, the rebind timer
local rebindTimer
local disabledSaid = {}   -- [outfitId] = true: ctx:Disable printed once
local unitBound = {}      -- [UNIT_* event] = { [ctx] = true }: the player unit-filter frame's fan-out

-- ── the context ───────────────────────────────────────────────────────────────────────────────

local Ctx = {}
Ctx.__index = Ctx

function Ctx:IsWorn() return NS.Stack.IsWorn(self.outfitId) end
function Ctx:DidEquip() return NS.Stack.DidEquip(self.outfitId) end
function Ctx:DidUnequip() return NS.Stack.DidUnequip(self.outfitId) end
function Ctx:IsComplete() return self.outfit.category == "Complete" end

--- Start the binding's repeating tick; a second start while it runs is a no-op (the legacy double
--- RegisterEvent("TIMER") is gone).
function Ctx:StartTicker(seconds)
    if self.ticker or self.dead then return false end
    self.ticker = self.target:ScheduleRepeatingTimer(function() B.Dispatch(self, "TIMER") end, seconds)
    return true
end

function Ctx:StopTicker()
    if not self.ticker then return false end
    self.target:CancelTimer(self.ticker)
    self.ticker = nil
    return true
end

--- Turn this outfit's trigger off (the outfit's one Disabled flag, design §3.3), say so once, unbind.
--- @param reason string  a display line, already localized by the caller
function Ctx:Disable(reason)
    local id = self.outfitId
    NS.SetByPath("outfit.trigger.disabled", true, id)
    if not disabledSaid[id] then
        disabledSaid[id] = true
        NS.Print(L["The trigger for outfit %s was turned off: %s"]:format(tostring(self.outfit.name), tostring(reason)))
    end
    B.Unbind(id)
end

-- ── dispatch ──────────────────────────────────────────────────────────────────────────────────

local function errorHandler(err) return tostring(err) end

-- The old cScriptPrefix gate (OutfitterScripting.lua:1836-1840).
local function Gate(ctx)
    local tr = ctx.outfit.trigger
    if ctx.faulted or ctx.dead or type(tr) ~= "table" or tr.disabled then return false end
    local PS = NS.PlayerState
    if tr.combatDisabled and (PS.InCombat() or PS.MaybeInCombat()) then return false end
    return true
end
B.__gate = Gate   -- test seam only

local function Fault(ctx, err)
    local key = ctx.outfitId .. ":" .. ctx.desc.id
    ctx.faulted = true
    if not B.faulted[key] then
        B.faulted[key] = tostring(err)
        NS.Print(L["Trigger %s for outfit %s failed and was switched off for this session: %s"]:format(
            ctx.desc.id, tostring(ctx.outfit.name), NS.SafeToString(err)))
    end
    B.Unbind(ctx.outfitId)
end

local function applyBody(ctx, action, delay, layer, interrupt)
    local St, id, changed = NS.Stack, ctx.outfitId, false
    if action == NS.TRIG.EQUIP then
        local worn = St.IsWorn(id)
        if not worn or ctx:IsComplete() then St.Wear(id, { layer = layer or ctx.desc.layer, byTrigger = true }) end
        changed = not worn
    elseif action == NS.TRIG.UNEQUIP then
        if St.IsWorn(id) then
            St.Remove(id, { byTrigger = true })
            changed = true
        end
    elseif action == NS.TRIG.TAG then
        St.TagLayer(id, layer)
    end
    if interrupt then NS.PlayerState.SetInterruptCasting(true) end
    if changed and delay then NS.Equip.SetUpdateDelay(ctx.now, delay) end
end

--- Apply one verdict inside one equipment bracket (PostProcess).
function B.Apply(ctx, action, delay, layer, interrupt)
    return NS.Equip.Batch(applyBody, ctx, action, delay, layer, interrupt)
end

--- Gate, call and apply one event for one binding (design §6.9). Perf bucket triggerDispatch, one
--- static key; the trigger id goes to NS.Debug only.
function B.Dispatch(ctx, event, ...)
    if not Gate(ctx) then return end
    local t0 = Perf.on and debugprofilestop()
    ctx.now = GetTime()
    local n, args = select("#", ...), { ... }            -- 5.1's xpcall forwards no arguments
    local ok, action, delay, layer, interrupt = xpcall(function()
        return ctx.desc.condition(ctx, event, unpack(args, 1, n))
    end, errorHandler)
    if t0 then Perf.Note("triggerDispatch", debugprofilestop() - t0) end
    if not ok then return Fault(ctx, action) end
    if action then
        NS.Debug("Trigger", "%s on %s: %s", ctx.desc.id, ctx.outfitId, action)
        B.Apply(ctx, action, delay, layer, interrupt)
    end
end

-- An edge hook (onWorn / onRemoved / onSuspend), isolated: a raise faults the binding, a return
-- value is never read (INV §6.4, a handler's return value is not an error).
local function runHook(ctx, fn)
    if not fn then return end
    local ok, err = xpcall(function() fn(ctx) end, errorHandler)
    if not ok then Fault(ctx, err) end
end

-- ── registration ──────────────────────────────────────────────────────────────────────────────

-- A unit-filtered game event: a string first argument must be the descriptor's unit; an event that
-- carries no unit (UPDATE_MOUSEOVER_UNIT, PLAYER_ENTERING_WORLD's booleans) passes.
local function unitPasses(unit, first)
    if not unit or type(first) ~= "string" then return true end
    return NS.Secrets.PlainEquals(first, unit)
end

local function demand(ctx, key)
    if ctx.demands[key] then return end
    ctx.demands[key] = true
    NS.States.Demand(key, 1)
end

local function onOwnEdge(ctx, event, hookName)
    return function(_, id, ...)
        if id ~= ctx.outfitId then return end
        if hookName == "onWorn" and not Gate(ctx) then return end
        runHook(ctx, ctx.desc[hookName])
        if not ctx.dead then B.Dispatch(ctx, event, id, ...) end
    end
end

local EDGE_HOOK = { OUTFIT_WORN = "onWorn", OUTFIT_REMOVED = "onRemoved" }

-- The client delivers the player's events only; the cheap unit read stays as a guard.
local function onUnitEvent(_, event, unit, ...)
    if unit ~= "player" then return end
    local set = unitBound[event]
    if not set then return end
    local list = {}
    for ctx in pairs(set) do list[#list + 1] = ctx end   -- a dispatch may unbind (a fault, Disable)
    for _, ctx in ipairs(list) do
        if not ctx.dead then B.Dispatch(ctx, event, unit, ...) end
    end
end

local function ensureUnitFrame()
    if B.unitFrame then return B.unitFrame end
    local f = CreateFrame("Frame")
    f:Hide()
    f:SetScript("OnEvent", onUnitEvent)
    B.unitFrame = f
    return f
end

local function isPlayerUnitEvent(ctx, e)
    return ctx.desc.unit == "player" and e:find("^UNIT_") ~= nil
end

local function bindUnitEvent(ctx, e)
    local set = unitBound[e]
    if not set then
        set = {}
        unitBound[e] = set
        NS.SafeRegisterUnitEvent(ensureUnitFrame(), e, B.rejected, "player")
    end
    set[ctx] = true
end

-- Drop ctx from every set; when one empties, the frame is re-registered from the sets that remain
-- (one UnregisterAllEvents, then one RegisterUnitEvent per live event), so it holds exactly them.
local function unbindUnitEvents(ctx)
    local emptied = false
    for e, set in pairs(unitBound) do
        if set[ctx] then
            set[ctx] = nil
            if not next(set) then
                unitBound[e] = nil
                emptied = true
            end
        end
    end
    if not emptied or not B.unitFrame then return end
    B.unitFrame:UnregisterAllEvents()
    for e in pairs(unitBound) do NS.SafeRegisterUnitEvent(B.unitFrame, e, B.rejected, "player") end
end

local function clearUnitFrame()
    for e in pairs(unitBound) do unitBound[e] = nil end
    if B.unitFrame then B.unitFrame:UnregisterAllEvents() end
end

local function registerOne(ctx, t, e)
    local Tr = NS.Triggers
    if e:find("^STATE:") then
        demand(ctx, e)
    elseif EDGE_HOOK[e] then
        t:RegisterMessage(NS.MSG[Tr.PSEUDO[e]], onOwnEdge(ctx, e, EDGE_HOOK[e]))
    elseif Tr.PSEUDO[e] then
        if e == "TOOLTIP_SHOW" or e == "TOOLTIP_HIDE" then demand(ctx, TOOLTIP_KEY) end
        t:RegisterMessage(NS.MSG[Tr.PSEUDO[e]], function() B.Dispatch(ctx, e) end)
    elseif Tr.PSEUDO[e] == nil and isPlayerUnitEvent(ctx, e) then
        bindUnitEvent(ctx, e)
    elseif Tr.PSEUDO[e] == nil then
        NS.SafeRegisterEvent(t, e, function(event, ...)
            if unitPasses(ctx.desc.unit, (...)) then B.Dispatch(ctx, event, ...) end
        end, B.rejected)
    end
end

local function registerAll(ctx, t)
    for _, e in ipairs(ctx.desc.events) do registerOne(ctx, t, e) end
    if next(ctx.desc.states) then
        t:RegisterMessage(NS.MSG.STATE_CHANGED, function(_, stateId, isActive)
            if ctx.desc.states[stateId] then B.Dispatch(ctx, "STATE", stateId, isActive) end
        end)
    end
end

local function targetFor(id)
    local t = targets[id]
    if t then return t end
    t = table.remove(freeTargets)
    if not t then
        t = NS.NewBusTarget()
        LibStub("AceTimer-3.0"):Embed(t)
    end
    targets[id] = t
    return t
end

local function persistFor(rec, desc)
    if not desc.persist then return nil end
    rec.triggerState = rec.triggerState or {}
    rec.triggerState[desc.id] = rec.triggerState[desc.id] or {}
    return rec.triggerState[desc.id]
end

-- The descriptor an outfit's trigger may bind, or nil with nothing bound (and one line for an id the
-- registry does not answer).
local function bindable(rec)
    local tr = rec and rec.trigger
    if type(tr) ~= "table" or not tr.id or tr.id == "" or tr.disabled then return nil end
    local desc = NS.Triggers.Get(tr.id)
    if not desc or not desc.condition then
        if not B.unavailable[tr.id] then
            B.unavailable[tr.id] = true
            NS.Print(L["Trigger %s is not available"]:format(tostring(tr.id)))
        end
        return nil
    end
    if desc.refuseEM and rec.kind == "em" then return nil end
    if B.faulted[rec.id .. ":" .. desc.id] then return nil end
    return desc
end

local function unbind(id, keepEffects)
    local ctx = bound[id]
    if not ctx then return false end
    bound[id] = nil
    local t = ctx.target
    t:UnregisterAllEvents()
    t:UnregisterAllMessages()
    t:CancelAllTimers()
    unbindUnitEvents(ctx)
    ctx.ticker = nil
    for key in pairs(ctx.demands) do NS.States.Demand(key, -1) end
    if not keepEffects and ctx.desc.onSuspend and NS.Stack.IsWorn(id) then runHook(ctx, ctx.desc.onSuspend) end
    ctx.dead = true
    return true
end

--- Bind one outfit's trigger (design §6.9). Quietly false for no trigger, a disabled one, an unknown
--- or not-yet-available id (one line), a TRINKET_QUEUE on an Equipment Manager set, or a binding
--- faulted this session. Rebinding an already-bound outfit unbinds it first; a worn outfit's effects
--- stay applied only when the same trigger binds again, else its onSuspend restores them.
--- @param id string
--- @return boolean bound
function B.Bind(id)
    local rec = NS.Outfits.Get(id)
    local desc = bindable(rec)
    local old = bound[id]
    unbind(id, old ~= nil and desc ~= nil and old.desc.id == desc.id)
    if not desc then return false end
    local t = targetFor(id)
    local ctx = setmetatable({
        outfitId = id, outfit = rec, desc = desc, target = t, state = {}, demands = {},
        params = NS.TriggerParams.Resolve(desc, rec.triggerParams and rec.triggerParams[desc.id]),
        persist = persistFor(rec, desc),
    }, Ctx)
    bound[id] = ctx
    registerAll(ctx, t)
    if desc.ticker then ctx:StartTicker(desc.ticker) end
    if desc.initial then t:ScheduleTimer(function() B.Dispatch(ctx, "BIND") end, 0) end
    return true
end

--- Unbind one outfit: every registration and timer of its target goes, its demands are released, and
--- a worn outfit's stand-down restore (onSuspend) runs.
--- @return boolean  false when it was not bound
function B.Unbind(id)
    dirty[id] = nil
    return unbind(id, false)
end

--- @return table|nil  the binding's context (the suites' read: the addon holds it in `bound` only)
function B.Context(id) return bound[id] end

--- @return boolean
function B.IsBound(id) return bound[id] ~= nil end

--- @return boolean  BindAll ran and nothing has unbound everything since
function B.IsActive() return active end

-- ── the module's own receivers ────────────────────────────────────────────────────────────────

local function flushDirty()
    rebindTimer = nil
    local ids = {}
    for id in pairs(dirty) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        dirty[id] = nil
        if active then B.Bind(id) else unbind(id, false) end
    end
end

local function onEdited(_, id, what)
    if what ~= TRIGGER or not active then return end
    dirty[id] = true
    if not rebindTimer then rebindTimer = mod:ScheduleTimer(flushDirty, 0) end
end

local function onAdded(_, id) if active then B.Bind(id) end end
-- Unbound, the target holds no registration and no timer, so the next new id may reuse it (F-009).
local function onDeleted(_, id)
    B.Unbind(id)
    local t = targets[id]
    if not t then return end
    targets[id] = nil
    freeTargets[#freeTargets + 1] = t
end

local function onSettings(_, path, value)
    if path == "auto.enabled" then B.SetActive(value ~= false) end
end

local function onProfile() B.SetActive(NS.GetSetting("auto.enabled") ~= false) end

local function ensureListeners()
    if mod then return end
    mod = NS.NewBusTarget()
    LibStub("AceTimer-3.0"):Embed(mod)
    mod:RegisterMessage(NS.MSG.OUTFIT_ADDED, onAdded)
    mod:RegisterMessage(NS.MSG.OUTFIT_DELETED, onDeleted)
    mod:RegisterMessage(NS.MSG.OUTFIT_EDITED, onEdited)
    mod:RegisterMessage(NS.MSG.SETTINGS_CHANGED, onSettings)
    mod:RegisterMessage(NS.MSG.PROFILE_CHANGED, onProfile)
end

-- ── all of them ───────────────────────────────────────────────────────────────────────────────

--- Bind every outfit with a trigger, then send TRIGGERS_REBOUND(count). Nothing while stood down or
--- with auto.enabled off; a loaded legacy addon does not hold it (O2). Called at the end of LoadPass,
--- and, once the first LoadPass has run, from Resume and through SetActive(true).
--- @return number bound
function B.BindAll()
    if NS.IsStoodDown() then return 0 end
    ensureListeners()
    if NS.GetSetting("auto.enabled") == false then return 0 end
    for id in pairs(bound) do unbind(id, true) end
    active = true
    local n, O = 0, NS.Outfits
    for _, category in ipairs(O.Categories()) do
        for id in O.Each(category) do
            if B.Bind(id) then n = n + 1 end
        end
    end
    NS.SendBus(NS.MSG.TRIGGERS_REBOUND, n)
    return n
end

--- Unbind every outfit (stand-down, auto.enabled off, DeleteAll). Worn outfits' restores run.
--- @return number unbound
function B.UnbindAll()
    active = false
    if rebindTimer and mod then mod:CancelTimer(rebindTimer) end
    rebindTimer = nil
    for id in pairs(dirty) do dirty[id] = nil end
    local ids, n = {}, 0
    for id in pairs(bound) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if unbind(id, false) then n = n + 1 end
    end
    clearUnitFrame()   -- AceAddon's UnregisterAllEvents cannot reach the frame (events-frames-taint-§1)
    return n
end

--- BindAll or UnbindAll, once per change of state: the one reaction to auto.enabled. Before the
--- first LoadPass an "on" binds nothing: the setting holds the wish and the LoadPass binds.
function B.SetActive(on)
    on = on and true or false
    if on == active then return false end
    if not on then
        B.UnbindAll()
    elseif NS.Outfits.FirstPassDone() then
        B.BindAll()
    else
        return false
    end
    return true
end

--- The lifecycle's stand-down (design §5.12): every binding goes, and each worn outfit's restore runs.
function B.Suspend()
    B.UnbindAll()
end

--- The stand-up: the receivers, then every binding from the stored outfits and settings. The first
--- LoadPass binds (modules/Outfits_Seed.lua); before it the store is unrepaired and the world not
--- loaded (docs/data-flow.md, "Load and enable"), so the login stand-up binds nothing.
function B.Resume()
    ensureListeners()
    if NS.Outfits.FirstPassDone() then B.BindAll() end
end
