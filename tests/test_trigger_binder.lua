-- tests/test_trigger_binder.lua — P4.15 (design §6.9, H14, O2): modules/Triggers_Binder.lua binds
-- every outfit with a trigger to a target of its own, routes game events, pseudo events, the ticker
-- and the BIND evaluation, gates, isolates and applies each verdict inside one equipment bracket, and
-- follows auto.enabled, the outfit messages and the lifecycle.
--
-- NS.Stack is a recorded stand-in in most cases, so a case reads exactly which wear or removal a
-- verdict asked for; the bespoke conditions (P4.16a-c) are stand-ins given through
-- NS.TriggerConditions. NS.Outfits, NS.States.Demand, NS.Equip (where the bracket matters) and the
-- schema seam are the real modules.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- A fresh instance at t = 100 whose bespoke ids answer from `conds` ({ [id] = fn }); everything
-- else is the shipped catalog.
local function scene(conds, mutate)
    local inst = T.load({ mutate = mutate })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.TriggerConditions = conds or {}
    NS.Triggers.Finalize()
    return NS, M
end

-- The recorded Stack: worn set, trigger-wear marks, and the OUTFIT_WORN/REMOVED sends the real one makes.
local function fakeStack(NS, st)
    st = st or {}
    st.worn, st.did, st.didUn, st.log = st.worn or {}, {}, {}, {}
    T.fake(NS, "Stack", {
        IsWorn = function(id) return st.worn[id] == true end,
        DidEquip = function(id) return st.did[id] == true end,
        DidUnequip = function(id) return st.didUn[id] == true end,
        Wear = function(id, opts)
            st.log[#st.log + 1] = "wear " .. id .. (opts.layer and ("/" .. opts.layer) or "")
            local was = st.worn[id]
            st.worn[id], st.did[id], st.didUn[id] = true, opts.byTrigger == true, false
            if not was then NS.SendBus(NS.MSG.OUTFIT_WORN, id, opts.layer, opts.byTrigger) end
            return true
        end,
        Remove = function(id, opts)
            st.log[#st.log + 1] = "remove " .. id
            st.worn[id], st.did[id], st.didUn[id] = nil, false, opts.byTrigger == true
            NS.SendBus(NS.MSG.OUTFIT_REMOVED, id, opts.byTrigger)
            return true
        end,
        TagLayer = function(id, layer) st.log[#st.log + 1] = "tag " .. id .. "/" .. tostring(layer) end,
    })
    return st
end

local function fakeEquip(NS)
    return T.fake(NS, "Equip", {
        Batch = function(fn, ...) return true, fn(...) end,
        SetUpdateDelay = true,
    })
end

local function log(st) return table.concat(st.log, ",") end
local function state(NS, id, on) NS.SendBus(NS.MSG.STATE_CHANGED, id, on) end

-- ── fan-out, isolation, the ticker ────────────────────────────────────────────────────────────

test("binder: one STATE_CHANGED fans out to every binding that names the state", function()
    local NS = scene()
    local a = NS.Outfits.Create("Prowl", {}, { trigger = "DRUID_PROWL" })
    local b = NS.Outfits.Create("Stealth", {}, { trigger = "ROGUE_STEALTH" })
    local c = NS.Outfits.Create("Swim", {}, { trigger = "SWIMMING" })
    local st = fakeStack(NS)
    fakeEquip(NS)
    assertEqual(NS.TriggerBinder.BindAll(), 3)
    state(NS, "STEALTH", true)
    assertTrue(st.worn[a] and st.worn[b], "both stealth outfits worn")
    -- red under: the STATE_CHANGED handler skipping its `ctx.desc.states[stateId]` filter.
    assertNil(st.worn[c], "the swimming one heard nothing")
    state(NS, "NO_SUCH_STATE", true)
    assertEqual(#st.log, 2)
end)

test("binder: a raising condition leaves depth 0 and faults only its own binding, once", function()
    local NS, M = scene({ RESTING = function() error("boom") end,
                          FALLING = function() return "equip" end })
    local bad = NS.Outfits.Create("Bad", {}, { trigger = "RESTING" })
    local good = NS.Outfits.Create("Good", {}, { trigger = "FALLING" })
    local st = fakeStack(NS)
    NS.TriggerBinder.BindAll()
    M.__resetPrinted()
    M.__fireTimers()                          -- RESTING's BIND evaluation raises; FALLING ticks
    assertEqual(NS.Equip.__state.depth, 0, "the bracket's counter is not stranded")
    assertFalse(NS.TriggerBinder.IsBound(bad), "the raising binding is switched off")
    assertTrue(NS.TriggerBinder.IsBound(good))
    assertTrue(st.worn[good], "the other binding still applies")
    M.__fire("PLAYER_UPDATE_RESTING")
    NS.TriggerBinder.BindAll()
    -- red under: Bind ignoring B.faulted (the binding comes back on the next BindAll).
    assertFalse(NS.TriggerBinder.IsBound(bad), "faulted for the session: not bound again")
    M.__fireTimers()
    local lines = table.concat(M.__printed(), "\n")
    local _, n = lines:gsub("failed and was switched off", "")
    assertEqual(n, 1, "one line, once")
    assertTrue(lines:find("RESTING", 1, true) ~= nil and lines:find("boom", 1, true) ~= nil)
end)

test("binder: the ticker is idempotent, and unbind cancels it and a pending BIND", function()
    local ticks = 0
    local NS, M = scene({ FALLING = function(ctx, event)
        if event == "TIMER" then ticks = ticks + 1 end
        ctx:StartTicker(0.5)                  -- a second start while running is a no-op
    end, RESTING = function() ticks = ticks + 100 end })
    local id = NS.Outfits.Create("Fall", {}, { trigger = "FALLING" })
    local r = NS.Outfits.Create("Rest", {}, { trigger = "RESTING" })
    fakeStack(NS)
    NS.TriggerBinder.BindAll()
    local ctx = NS.TriggerBinder.Context(id)
    assertFalse(ctx:StartTicker(0.5), "already ticking")
    M.__fireTimers()
    M.__fireTimers()
    assertEqual(ticks, 102, "one tick per pass (two passes), and RESTING's BIND once")
    NS.TriggerBinder.Unbind(r)
    NS.TriggerBinder.Unbind(id)
    -- red under: Unbind skipping CancelAllTimers (the ticker stays armed on a dead binding's target).
    local live = 0
    for _, timer in pairs(M.LibStub("AceTimer-3.0").activeTimers) do
        if timer.object == ctx.target then live = live + 1 end
    end
    assertEqual(live, 0, "no timer left armed on the binding's target")
    for _ = 1, 3 do M.__fireTimers() end
    assertEqual(ticks, 102)
    assertTrue(ctx.dead)
end)

-- ── the verdict ───────────────────────────────────────────────────────────────────────────────

test("binder: a delay applies only when the outfit changed, in each of its classes", function()
    local verdict = {}
    local NS = scene({ RESTING = function() return verdict.a, verdict.d end })
    local id = NS.Outfits.Create("Rest", {}, { trigger = "RESTING" })
    local st = fakeStack(NS)
    local equip = fakeEquip(NS)
    NS.TriggerBinder.BindAll()
    local ctx = NS.TriggerBinder.Context(id)
    for _, d in ipairs({ 2, 0.1, 1, 2.5, 0.5 }) do
        verdict.a, verdict.d = "equip", d
        NS.TriggerBinder.Dispatch(ctx, "PLAYER_UPDATE_RESTING")      -- changed: the delay applies
        NS.TriggerBinder.Dispatch(ctx, "PLAYER_UPDATE_RESTING")      -- already worn: no delay
        verdict.a = "unequip"
        NS.TriggerBinder.Dispatch(ctx, "PLAYER_UPDATE_RESTING")      -- changed again
        NS.TriggerBinder.Dispatch(ctx, "PLAYER_UPDATE_RESTING")      -- not worn: no change, no delay
    end
    local delays = {}
    for _, c in ipairs(equip.__calls) do
        if c[1] == "SetUpdateDelay" then
            assertEqual(c[2], 100, "from the dispatch time")
            delays[#delays + 1] = tostring(c[3])
        end
    end
    -- red under: `if delay then` without `changed` (every no-change dispatch would add a delay).
    assertEqual(table.concat(delays, ","), "2,2,0.1,0.1,1,1,2.5,2.5,0.5,0.5")
    assertEqual(#st.log, 10, "five wears and five removals")
end)

test("binder: a Complete outfit is re-worn on EQUIP, an Accessory one is not", function()
    local NS = scene({ RESTING = function() return "equip" end })
    local items = {}
    for _, s in ipairs({ "HeadSlot", "ChestSlot", "LegsSlot", "MainHandSlot" }) do items[s] = { id = 0 } end
    local full = NS.Outfits.Create("Full", items, { trigger = "RESTING" })
    local hat = NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } }, { trigger = "RESTING" })
    NS.db.char.outfits[full].category = "Complete"
    NS.db.char.outfits[hat].category = "Accessory"
    local st = fakeStack(NS)
    fakeEquip(NS)
    st.worn[full], st.worn[hat] = true, true
    NS.TriggerBinder.BindAll()
    for _, id in ipairs({ full, hat }) do NS.TriggerBinder.Dispatch(NS.TriggerBinder.Context(id), "BIND") end
    -- red under: applyBody wearing only what is not worn (OutfitterScripting.lua:2160's Complete rule lost).
    assertEqual(log(st), "wear " .. full, "the stack clears under a Complete outfit")
end)

test("binder: smart unequip never removes a manual wear, and TAG moves a worn outfit's layer", function()
    local NS, M = scene(nil, function(M) M.__world:setClass("DRUID", 1) end)
    M.HasFullControl = function() return true end
    NS.PlayerState.Refresh()
    local swim = NS.Outfits.Create("Swim", {}, { trigger = "SWIMMING" })
    local bear = NS.Outfits.Create("Bear", {}, { trigger = "DRUID_BEAR" })
    local st = fakeStack(NS)
    fakeEquip(NS)
    NS.TriggerBinder.BindAll()
    st.worn[swim] = true                       -- worn by hand: DidEquip is false
    state(NS, "SWIMMING", false)
    -- red under: smartUnequip unequipping without DidEquip.
    assertEqual(log(st), "", "a manual wear stays")
    st.worn[swim] = nil
    state(NS, "SWIMMING", true)
    state(NS, "SWIMMING", false)
    assertEqual(log(st), "wear " .. swim .. ",remove " .. swim, "its own wear comes off")
    st.log = {}
    NS.SendBus(NS.MSG.OUTFIT_WORN, bear, nil, false)   -- a manual wear of the bear outfit
    NS.SendBus(NS.MSG.OUTFIT_WORN, swim, nil, false)   -- another outfit's edge: filtered out
    -- red under: the OUTFIT_WORN handler dropping its own-outfit filter (the swim edge would tag too).
    assertEqual(log(st), "tag " .. bear .. "/shapeshift")
end)

test("binder: combatDisabled gates every event in combat, and trigger.disabled binds nothing", function()
    local hits = 0
    local NS, M = scene({ RESTING = function() hits = hits + 1 end })
    NS.Outfits.Create("Rest", {}, { trigger = { id = "RESTING", combatDisabled = true } })
    local off = NS.Outfits.Create("Off", {}, { trigger = { id = "RESTING", disabled = true } })
    fakeStack(NS)
    NS.TriggerBinder.BindAll()
    assertFalse(NS.TriggerBinder.IsBound(off), "a disabled trigger is not bound")
    M.__fireTimers()
    assertEqual(hits, 1, "the BIND evaluation out of combat")
    M.__world:setCombat(true)
    NS.PlayerState.Refresh()
    M.__fire("PLAYER_UPDATE_RESTING")
    -- red under: Dispatch running without its Gate.
    assertEqual(hits, 1, "gated in combat")
    NS.PlayerState.SetMaybeInCombat(false)
    M.__world:setCombat(false)
    NS.PlayerState.Refresh()
    M.__fire("PLAYER_UPDATE_RESTING")
    assertEqual(hits, 2)
end)

test("binder: BIND runs once 0 s after bind, game-event arguments reach the condition, unit filters", function()
    local seen = {}
    local NS, M = scene({
        RESTING = function(_, event, ...) seen[#seen + 1] = event .. ":" .. select("#", ...) end,
        SPELLCAST = function(_, event, unit, guid, spellID)
            seen[#seen + 1] = event .. ":" .. tostring(unit) .. ":" .. tostring(guid) .. ":" .. tostring(spellID)
        end,
    })
    NS.Outfits.Create("Rest", {}, { trigger = "RESTING" })
    NS.Outfits.Create("Cast", {}, { trigger = "SPELLCAST" })
    fakeStack(NS)
    NS.TriggerBinder.BindAll()
    assertEqual(#seen, 0, "nothing inside BindAll")
    M.__fireTimers()
    assertEqual(table.concat(seen, ","), "BIND:0")
    M.__fire("UNIT_SPELLCAST_START", "player", "Cast-1", 7620)
    M.__fire("UNIT_SPELLCAST_START", "party1", "Cast-2", 7620)
    M.__fire("PLAYER_ENTERING_WORLD", true, false)
    -- red under: unitPasses answering true for every first argument (party1's cast would reach SPELLCAST).
    assertEqual(table.concat(seen, ","), "BIND:0,UNIT_SPELLCAST_START:player:Cast-1:7620,PLAYER_ENTERING_WORLD:2")
end)

-- ── the edges and their hooks ─────────────────────────────────────────────────────────────────

test("binder: this outfit's own wear runs its effects, a stand-down restores them, a hook's return is no error", function()
    local NS, M = scene({ DANCE = { condition = function() return nil end,
                                    onWorn = function() return false, "not an error" end } })
    M.__cvars.autoLootDefault = "0"
    local id = NS.Outfits.Create("Stealth", {}, { trigger = "ROGUE_STEALTH" })
    local dance = NS.Outfits.Create("Dance", {}, { trigger = "DANCE" })
    NS.SetByPath("trigger.ROGUE_STEALTH.autoLoot", true, id)
    local st = fakeStack(NS)
    fakeEquip(NS)
    NS.TriggerBinder.BindAll()
    state(NS, "STEALTH", true)
    assertEqual(M.__cvars.autoLootDefault, "1", "auto loot on while worn")
    assertTrue(NS.db.char.outfits[id].triggerState.ROGUE_STEALTH.AutoLoot ~= nil, "recorded in triggerState")
    NS.SendBus(NS.MSG.OUTFIT_WORN, dance, nil, false)
    assertTrue(NS.TriggerBinder.IsBound(dance), "a hook returning false is not a fault")
    NS.TriggerBinder.Suspend()
    -- red under: unbind skipping onSuspend for a worn outfit.
    assertEqual(M.__cvars.autoLootDefault, "0", "the stand-down restored it")
    assertTrue(st.worn[id], "the outfit itself is the stack's")
end)

test("binder: a rebind onto the same trigger keeps a worn outfit's effects; disabling or switching restores them", function()
    local NS, M = scene()
    M.__cvars.autoLootDefault = "0"
    local id = NS.Outfits.Create("Stealth", {}, { trigger = "ROGUE_STEALTH" })
    NS.SetByPath("trigger.ROGUE_STEALTH.autoLoot", true, id)
    local st = fakeStack(NS)
    fakeEquip(NS)
    NS.TriggerBinder.BindAll()
    state(NS, "STEALTH", true)
    assertEqual(M.__cvars.autoLootDefault, "1")
    assertTrue(NS.SetByPath("outfit.trigger.combatDisabled", true, id))
    M.__fireTimers()
    assertTrue(NS.TriggerBinder.IsBound(id))
    assertEqual(M.__cvars.autoLootDefault, "1", "the same trigger rebound: its effects stay applied")
    assertTrue(NS.SetByPath("outfit.trigger.disabled", true, id))
    M.__fireTimers()
    assertFalse(NS.TriggerBinder.IsBound(id))
    -- red under: the rebind unbinding with keepEffects always, as flushDirty and B.Bind did (auto loot
    -- stays on for good).
    assertEqual(M.__cvars.autoLootDefault, "0", "disabled: the restore ran")
    assertTrue(NS.SetByPath("outfit.trigger.disabled", false, id))
    M.__fireTimers()
    st.worn[id] = nil                      -- taken off meanwhile: the next wear applies the effects again
    state(NS, "STEALTH", true)
    assertEqual(M.__cvars.autoLootDefault, "1")
    assertTrue(NS.SetByPath("outfit.trigger.id", "SWIMMING", id))
    M.__fireTimers()
    assertEqual(NS.TriggerBinder.Context(id).desc.id, "SWIMMING")
    -- red under: keepEffects for any rebind that binds something (not only the same trigger id).
    assertEqual(M.__cvars.autoLootDefault, "0", "switched: the restore ran")
end)

-- ── auto.enabled, the legacy addon, the messages ──────────────────────────────────────────────

test("binder: auto.enabled off unbinds all and on rebinds, through SETTINGS_CHANGED alone", function()
    local NS = scene()
    local id = NS.Outfits.Create("Swim", {}, { trigger = "SWIMMING" })
    fakeStack(NS)
    NS.TriggerBinder.BindAll()
    assertTrue(NS.TriggerBinder.IsBound(id))
    assertTrue(NS.SetByPath("auto.enabled", false))
    -- red under: BindAll not reading auto.enabled, or the SETTINGS_CHANGED handler missing.
    assertFalse(NS.TriggerBinder.IsBound(id), "off unbinds")
    assertEqual(NS.TriggerBinder.BindAll(), 0, "BindAll refuses while off")
    assertTrue(NS.SetByPath("auto.enabled", true))
    assertTrue(NS.TriggerBinder.IsBound(id), "on rebinds")
    -- The one route: no file but the binder calls SetActive (design §6.9).
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") and rel ~= "modules/Triggers_Binder.lua" and not rel:match("^libs/") then
            local f = assert(io.open(T.root .. "/" .. rel, "rb"))
            local text = f:read("*a"):gsub("%-%-[^\n]*", "")
            f:close()
            assertTrue(not text:find("TriggerBinder%.SetActive%("), rel .. " calls SetActive")
        end
    end
end)

test("binder: a loaded legacy Outfitter does not hold binding (O2: warn only)", function()
    local NS = scene(nil, function(M)
        local loaded = M.C_AddOns.IsAddOnLoaded
        M.C_AddOns.IsAddOnLoaded = function(name) return name == "Outfitter" or loaded(name) end
    end)
    local id = NS.Outfits.Create("Swim", {}, { trigger = "SWIMMING" })
    fakeStack(NS)
    -- red under: a legacy-loaded check in BindAll (the C36 hold the owner ruled out, O2).
    assertEqual(NS.TriggerBinder.BindAll(), 1)
    assertTrue(NS.TriggerBinder.IsBound(id))
end)

test("binder: a 5-entry SetMany on one outfit rebinds it once; OUTFIT_ADDED binds, OUTFIT_DELETED unbinds", function()
    local binds = 0
    local NS, M = scene({ RESTING = function(_, event) if event == "BIND" then binds = binds + 1 end end })
    local id = NS.Outfits.Create("Rest", {}, { trigger = "RESTING" })
    fakeStack(NS)
    NS.TriggerBinder.BindAll()
    M.__fireTimers()
    assertEqual(binds, 1)
    local first = NS.TriggerBinder.Context(id)
    assertTrue(NS.Schema.SetMany({
        { path = "trigger.SWIMMING.disableBG", value = true }, { path = "trigger.SWIMMING.disablePVP", value = true },
        { path = "trigger.SWIMMING.disableInstance", value = true }, { path = "trigger.SWIMMING.disableVashjir", value = false },
        { path = "outfit.trigger.combatDisabled", value = true },
    }, { instanceId = id }))
    -- red under: onEdited rebinding at once (five unbind/binds and five BIND evaluations).
    assertTrue(NS.TriggerBinder.Context(id) == first, "coalesced: nothing yet")
    M.__fireTimers()
    M.__fireTimers()
    assertTrue(NS.TriggerBinder.Context(id) ~= first, "rebound")
    assertEqual(binds, 2, "one unbind/bind and one BIND evaluation")
    assertTrue(NS.TriggerBinder.Context(id).outfit.trigger.combatDisabled)
    -- Switching the trigger itself rebinds onto the new descriptor.
    assertTrue(NS.SetByPath("outfit.trigger.id", "SWIMMING", id))
    M.__fireTimers()
    assertEqual(NS.TriggerBinder.Context(id).desc.id, "SWIMMING")
    local added = NS.Outfits.Create("Late", {}, { trigger = "DRUID_PROWL" })
    assertTrue(NS.TriggerBinder.IsBound(added), "bound at once on OUTFIT_ADDED")
    T.fake(NS, "Stack", { Remove = true, Selected = function() return nil end, IsWorn = function() return false end })
    NS.Outfits.Delete(added)
    assertFalse(NS.TriggerBinder.IsBound(added), "unbound on delete")
end)

-- ── refusals and diagnostics ──────────────────────────────────────────────────────────────────

test("binder: an unknown or unwritten trigger prints once and binds nothing; refuseEM; ctx:Disable", function()
    local NS, M = scene({ FALLING = function(ctx) ctx:Disable("too much falling") end })
    local unknown = NS.Outfits.Create("Old", {}, { trigger = "RESTING" })     -- no condition yet
    local em = NS.Outfits.Create("EM trinkets", {}, { trigger = "TRINKET_QUEUE" })
    NS.db.char.outfits[em].kind = "em"
    local fall = NS.Outfits.Create("Fall", {}, { trigger = "FALLING" })
    fakeStack(NS)
    M.__resetPrinted()
    NS.TriggerBinder.BindAll()
    NS.TriggerBinder.BindAll()
    assertFalse(NS.TriggerBinder.IsBound(unknown))
    assertFalse(NS.TriggerBinder.IsBound(em), "TRINKET_QUEUE refuses an Equipment Manager set")
    local printed = table.concat(M.__printed(), "\n")
    local _, n = printed:gsub("Trigger RESTING is not available", "")
    -- red under: bindable printing on every refusal (B.unavailable dropped).
    assertEqual(n, 1, "printed once")
    M.__fireTimers()
    assertTrue(NS.db.char.outfits[fall].trigger.disabled, "ctx:Disable wrote the one Disabled flag")
    assertFalse(NS.TriggerBinder.IsBound(fall))
    M.__fireTimers()
    assertFalse(NS.TriggerBinder.IsBound(fall), "the rebind refuses a disabled trigger")
    assertTrue(table.concat(M.__printed(), "\n"):find("too much falling", 1, true) ~= nil)
end)

test("binder: Perf notes the one static triggerDispatch key; the demands follow the bindings", function()
    local NS = scene({ RESTING = function() return nil end })
    local id = NS.Outfits.Create("Herb", {}, { trigger = "GATHER_HERBALISM" })
    local r = NS.Outfits.Create("Rest", {}, { trigger = "RESTING" })
    local s = NS.Outfits.Create("Spirit", {}, { trigger = "SPIRIT_REGEN" })
    fakeStack(NS)
    NS.TriggerBinder.BindAll()
    assertEqual(NS.States.Demand("TOOLTIP"), 1)
    assertEqual(NS.States.Demand("STATE:SPIRIT_REGEN"), 1)
    local keys = {}
    NS.Perf.on = true
    local note = NS.Perf.Note
    NS.Perf.Note = function(key) keys[#keys + 1] = key end
    NS.TriggerBinder.Dispatch(NS.TriggerBinder.Context(r), "PLAYER_UPDATE_RESTING")
    NS.Perf.Note, NS.Perf.on = note, false
    -- red under: a dynamic bucket key (the trigger id) in Perf.Note (performance-§3).
    assertEqual(table.concat(keys, ","), "triggerDispatch")
    NS.TriggerBinder.Unbind(id)
    NS.TriggerBinder.Unbind(s)
    assertEqual(NS.States.Demand("TOOLTIP"), 0, "released")
    assertEqual(NS.States.Demand("STATE:SPIRIT_REGEN"), 0)
end)

test("binder: stand-down unbinds and a stand-up rebinds, an outfit added while down included", function()
    local NS = scene()
    local id = NS.Outfits.Create("Swim", {}, { trigger = "SWIMMING" })
    T.fake(NS, "Stack", { IsWorn = function() return false end, Suspend = true, Resume = true })
    T.fake(NS, "States", { Suspend = true, Resume = true, Demand = function() return 0 end })
    NS.TriggerBinder.BindAll()
    NS.SetByPath("enabled", false)
    assertFalse(NS.TriggerBinder.IsBound(id))
    local late = NS.Outfits.Create("Late", {}, { trigger = "DRUID_PROWL" })
    -- red under: OUTFIT_ADDED's receiver surviving the stand-down.
    assertFalse(NS.TriggerBinder.IsBound(late), "nothing binds while down")
    NS.SetByPath("enabled", true)
    assertTrue(NS.TriggerBinder.IsBound(id) and NS.TriggerBinder.IsBound(late))
end)
