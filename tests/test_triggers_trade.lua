-- tests/test_triggers_trade.lua — P4.16b (design §6.8.1 rows 1-4, 11-14, 22, 23, 29, 32): the TRADE
-- triggers. The bespoke conditions are modules/Triggers_CondTrade.lua (LOCKPICKING, RIDING, FALLING,
-- RESTING, SPELLCAST, COOKING); the gathering rows, SWIMMING, DINING and FISHING are families and
-- descriptor effects that P4.15 landed, pinned here as the trade catalog behaves.
--
-- Every case runs the REAL conditions through the real binder (modules/Triggers_Binder.lua), so the
-- ticker, the unit filter and the verdict's delay are the shipped ones. NS.Stack and NS.Equip are
-- recorded stand-ins (the test_trigger_binder shape), so a case reads exactly which wear or removal a
-- verdict asked for and which delay it set; NS.Companion is a recorded stand-in for COOKING's pets.

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- A fresh instance at t = 100, with the shipped catalog and conditions.
local function scene(mutate)
    local inst = unitLoad({ mutate = mutate })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.Triggers.Finalize()
    return NS, M
end

-- The recorded Stack: worn set, trigger-wear marks, and the OUTFIT_WORN/REMOVED sends the real one makes.
local function fakeStack(NS)
    local st = { worn = {}, did = {}, didUn = {}, log = {} }
    T.fake(NS, "Stack", {
        IsWorn = function(id) return st.worn[id] == true end,
        DidEquip = function(id) return st.did[id] == true end,
        DidUnequip = function(id) return st.didUn[id] == true end,
        Wear = function(id, opts)
            st.log[#st.log + 1] = "wear"
            local was = st.worn[id]
            st.worn[id], st.did[id], st.didUn[id] = true, opts.byTrigger == true, false
            if not was then NS.SendBus(NS.MSG.OUTFIT_WORN, id, opts.layer, opts.byTrigger) end
            return true
        end,
        Remove = function(id, opts)
            st.log[#st.log + 1] = "remove"
            st.worn[id], st.did[id], st.didUn[id] = nil, false, opts.byTrigger == true
            NS.SendBus(NS.MSG.OUTFIT_REMOVED, id, opts.byTrigger)
            return true
        end,
        TagLayer = function() st.log[#st.log + 1] = "tag" end,
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

-- The delays the verdicts set, in order ("" for none).
local function delays(equip)
    local out = {}
    for _, c in ipairs(equip.__calls) do
        if c[1] == "SetUpdateDelay" then out[#out + 1] = tostring(c[3]) end
    end
    return table.concat(out, ",")
end

-- One outfit on `tid` with `params` stored, bound through BindAll; answers id, stack, equip, ctx.
local function bound(NS, tid, params)
    local id = NS.Outfits.Create(tid, {}, { trigger = tid })
    for k, v in pairs(params or {}) do
        assertTrue(NS.SetByPath("trigger." .. tid .. "." .. k, v, id), tid .. "." .. k .. " stored")
    end
    local st, equip = fakeStack(NS), fakeEquip(NS)
    NS.TriggerBinder.BindAll()
    return id, st, equip, NS.TriggerBinder.Context(id)
end

-- The repeating timers armed on the binding's own target.
local function tickers(M, ctx)
    local n = 0
    for _, timer in pairs(M.LibStub("AceTimer-3.0").activeTimers) do
        if timer.object == ctx.target and timer.looping and not timer.cancelled then n = n + 1 end
    end
    return n
end

local function state(NS, id, on) NS.SendBus(NS.MSG.STATE_CHANGED, id, on) end
local function tick(NS, ctx) NS.TriggerBinder.Dispatch(ctx, "TIMER") end

local OWN = { "LOCKPICKING", "RIDING", "FALLING", "RESTING", "SPELLCAST", "COOKING" }

-- ── the file ──────────────────────────────────────────────────────────────────────────────────

test("trade: every bespoke TRADE id has its condition from Triggers_CondTrade.lua", function()
    local NS = scene()
    for _, tid in ipairs(OWN) do
        local entry = NS.TriggerConditions[tid]
        -- red under: dropping a C.<ID> entry from Triggers_CondTrade.lua.
        assertTrue(entry ~= nil, tid .. " has a bespoke entry")
        local desc = NS.Triggers.Get(tid)
        assertEqual(desc.category, "TRADE", tid)
        assertEqual(type(desc.condition), "function", tid .. " resolved a condition")
        assertNil(desc.family, tid .. " is bespoke")
    end
    assertEqual(NS.Triggers.Get("LOCKPICKING").class, "ROGUE")
end)

-- ── gathering (rows 1-3) ──────────────────────────────────────────────────────────────────────

test("trade: gathering reads skill lines 182, 186 and 393, equips on a found line and waits 1 s on hide", function()
    local NS, M = scene()
    assertEqual(NS.Triggers.Get("GATHER_HERBALISM").familyArgs.skillLine, 182)
    assertEqual(NS.Triggers.Get("GATHER_MINING").familyArgs.skillLine, 186)
    assertEqual(NS.Triggers.Get("GATHER_SKINNING").familyArgs.skillLine, 393)
    M.__world.tradeSkills[186] = "Mining"
    local id, st, equip = bound(NS, "GATHER_MINING")
    local tip = M.GameTooltip
    tip:ClearLines(); tip:AddLine("Copper Vein"); tip:AddLine("Mining", 1, 0.1, 0.1)
    NS.SendBus(NS.MSG.TOOLTIP_SHOWN)
    assertTrue(st.worn[id], "a red Mining line under the title equips")
    NS.SendBus(NS.MSG.TOOLTIP_HIDDEN)
    assertEqual(log(st), "wear,remove")
    assertEqual(delays(equip), "1", "the hide waits a second")
    tip:ClearLines(); tip:AddLine("Copper Vein"); tip:AddLine("Mining", 0.25, 0.75, 0.25)
    NS.SendBus(NS.MSG.TOOLTIP_SHOWN)
    -- red under: the gathering family equipping on `found` without `difficult`.
    assertEqual(log(st), "wear,remove", "a green node does not")
end)

-- ── LOCKPICKING (row 4) ───────────────────────────────────────────────────────────────────────

-- A lockbox tooltip: the title, then the lock line in `r, g, b`.
local function lockTip(M, text, r, g, b)
    local tip = M.GameTooltip
    tip:ClearLines()
    tip:AddLine("Lockbox")
    tip:AddLine(text, r, g, b)
end

test("trade: lockpicking starts its ticker once on show, equips while targeting a hard lock, stops on hide", function()
    local NS, M = scene()
    M.LOCKED_WITH_SPELL = "Requires %s"
    M.__world.tradeSkills[633] = "Lockpicking"
    local targeting = false
    M.SpellIsTargeting = function() return targeting end
    local id, st, equip, ctx = bound(NS, "LOCKPICKING")
    assertEqual(tickers(M, ctx), 0, "no ticker until a tooltip shows")
    lockTip(M, "Requires Lockpicking", 1, 0.1, 0.1)
    NS.SendBus(NS.MSG.TOOLTIP_SHOWN)
    NS.SendBus(NS.MSG.TOOLTIP_SHOWN)
    -- red under: StartTicker on every show without the idempotent guard (ctx:StartTicker answers it).
    assertEqual(tickers(M, ctx), 1, "one ticker, however many shows")
    -- red under: the show and tick skipping the SpellIsTargeting() test.
    assertEqual(log(st), "", "not targeting a spell: nothing")
    targeting = true
    tick(NS, ctx)
    -- red under: the TIMER branch returning nil (the show-then-cast order never equips).
    assertTrue(st.worn[id], "the pick spell is out and the lock is red")
    NS.SendBus(NS.MSG.TOOLTIP_HIDDEN)
    -- red under: the hide branch skipping StopTicker.
    assertEqual(tickers(M, ctx), 0, "the hide stops the ticker")
    assertEqual(log(st), "wear,remove")
    assertEqual(delays(equip), "1")
end)

test("trade: lockpicking wants a difficult line, and falls back to the L line when the composed one is missing (D4)", function()
    local NS, M = scene()
    M.SpellIsTargeting = function() return true end
    local id, st, _, ctx = bound(NS, "LOCKPICKING")
    lockTip(M, "Requires Lockpicking", 0.25, 0.75, 0.25)
    NS.SendBus(NS.MSG.TOOLTIP_SHOWN)
    -- red under: equipping on `found` without `difficult`.
    assertEqual(log(st), "", "a green lock is easy")
    lockTip(M, "Requires Lockpicking", 1, 0.5, 0)
    tick(NS, ctx)
    -- red under: no L["Requires Lockpicking"] fallback (no LOCKED_WITH_SPELL and no skill name here).
    assertTrue(st.worn[id], "the localized fallback line matched")
    M.SpellIsTargeting = function() return T.secret(true) end
    NS.SendBus(NS.MSG.TOOLTIP_HIDDEN)
    NS.SendBus(NS.MSG.TOOLTIP_SHOWN)
    -- red under: reading SpellIsTargeting() without Secrets.PlainTruth.
    assertEqual(log(st), "wear,remove", "a secret targeting flag is not targeting")
    M.LOCKED_WITH_SPELL = "Requires %s"
    M.__world.tradeSkills[633] = "Serrurerie"
    lockTip(M, "Requires Serrurerie", 1, 0, 0)
    M.SpellIsTargeting = function() return true end
    tick(NS, ctx)
    assertEqual(log(st), "wear,remove,wear", "the composed GlobalString line, in the client's language")
end)

-- ── RIDING (row 11) ───────────────────────────────────────────────────────────────────────────

test("trade: riding's guards apply only on mounting, and the dismount waits unequipDelay", function()
    local NS, M = scene()
    local id, st, equip = bound(NS, "RIDING", { unequipDelay = 3 })
    M.__world:setInstance({ type = "party" })
    state(NS, "MOUNTED", true)
    -- red under: the mount edge skipping ridingBlocked.
    assertEqual(log(st), "", "disableInstance is on by default")
    M.__world:setInstance({ type = "pvp" })
    state(NS, "MOUNTED", true)
    assertEqual(log(st), "", "disableBG is on by default")
    M.__world:setInstance(nil)
    state(NS, "MOUNTED", true)
    assertTrue(st.worn[id], "the open world")
    M.__world:setInstance({ type = "party" })
    state(NS, "MOUNTED", false)
    -- red under: running the guards on the dismount too (the outfit would stay on in a dungeon).
    assertEqual(log(st), "wear,remove", "the guards never hold the dismount")
    assertEqual(delays(equip), "3", "the param's wait")
    st.worn[id] = true                       -- worn by hand: the dismount takes it off all the same
    state(NS, "MOUNTED", false)
    assertEqual(log(st), "wear,remove,remove", "the legacy dismount is not smart")
end)

test("trade: riding with stayWhileFalling waits for a landing at least 1 s after the dismount, on one ticker", function()
    local NS, M = scene()
    local id, st, _, ctx = bound(NS, "RIDING", { stayWhileFalling = true })
    state(NS, "MOUNTED", true)
    M.__world:setFlag("IsFalling", true)
    state(NS, "MOUNTED", false)
    state(NS, "MOUNTED", false)
    -- red under: the stay-while-falling branch returning UNEQUIP at once.
    assertTrue(st.worn[id], "still on while falling")
    assertEqual(tickers(M, ctx), 1, "one ticker for two dismount edges")
    M.__now = 100.5
    M.__world:setFlag("IsFalling", false)
    tick(NS, ctx)
    -- red under: dropping the `dismountAt + 1` wait (a hop off the mount on the ground unequips at once).
    assertTrue(st.worn[id], "landed, but within a second of the dismount")
    M.__now = 101.5
    M.__world:setFlag("IsFalling", true)
    tick(NS, ctx)
    -- red under: the tick dropping its `not IsFalling()` test.
    assertTrue(st.worn[id], "a second on, but falling again")
    M.__world:setFlag("IsFalling", false)
    tick(NS, ctx)
    assertEqual(log(st), "wear,remove", "landed a second on")
    -- red under: the landing tick leaving the ticker running.
    assertEqual(tickers(M, ctx), 0, "the ticker stops with the landing")
end)

test("trade: remounting while waiting to land cancels the landing unequip", function()
    local NS, M = scene()
    local id, st, _, ctx = bound(NS, "RIDING", { stayWhileFalling = true })
    state(NS, "MOUNTED", true)
    M.__world:setFlag("IsFalling", true)
    state(NS, "MOUNTED", false)
    state(NS, "MOUNTED", true)
    M.__world:setFlag("IsFalling", false)
    M.__now = 105
    tick(NS, ctx)
    -- red under: the mount edge leaving state.waitLand set (the landing would unequip a mounted player).
    assertTrue(st.worn[id], "mounted again: stays on")
    assertEqual(tickers(M, ctx), 0, "and the ticker is gone")
end)

-- ── SWIMMING, FISHING, DINING (rows 12-14) ────────────────────────────────────────────────────

test("trade: swimming waits 2.5 s to unequip and skips Vashj'ir's three maps by default", function()
    local NS, M = scene()
    local id, st, equip = bound(NS, "SWIMMING")
    state(NS, "SWIMMING", true)
    state(NS, "SWIMMING", false)
    assertEqual(log(st), "wear,remove")
    assertEqual(delays(equip), "2.5")
    for _, map in ipairs({ 201, 204, 205 }) do
        M.__world:setMap(map)
        state(NS, "SWIMMING", true)
        -- red under: G.vashjir answering false (the swim outfit going on in Vashj'ir).
        assertNil(st.worn[id], "Vashj'ir map " .. map)
    end
    M.__world:setMap(203)
    state(NS, "SWIMMING", true)
    assertTrue(st.worn[id], "a map next door is not Vashj'ir")
end)

test("trade: fishing never equips itself, records Find Fish (spell 43308 or texture 133888) and restores it", function()
    local NS, M = scene()
    local tracking = { { name = "Find Herbs", texture = 1, active = false, spellID = 2383 },
                       { name = "Find Fish", texture = 133888, active = false } }      -- no spellID: the texture
    M.C_Minimap = {
        GetNumTrackingTypes = function() return #tracking end,
        GetTrackingInfo = function(i) return tracking[i] end,
        SetTracking = function(i, on) tracking[i].active = on end,
    }
    M.__cvars.autoLootDefault, M.__cvars.autoInteract = "0", "1"
    local id, st = bound(NS, "FISHING", { autoLoot = true })
    local rec = NS.db.char.outfits[id]
    NS.SendBus(NS.MSG.STATE_CHANGED, "SWIMMING", true)
    NS.TriggerBinder.Dispatch(NS.TriggerBinder.Context(id), "BIND")
    -- red under: the passive family answering EQUIP.
    assertEqual(log(st), "", "no event of its own wears it")
    st.worn[id] = true
    NS.SendBus(NS.MSG.OUTFIT_WORN, id, nil, false)
    assertTrue(tracking[2].active, "Find Fish found by its texture")
    -- red under: findFishIndex matching the first tracking type whatever its spell and texture.
    assertFalse(tracking[1].active, "Find Herbs is left alone")
    assertEqual(M.__cvars.autoLootDefault, "1"); assertEqual(M.__cvars.autoInteract, "0")
    assertTrue(rec.triggerState.FISHING.FishTracking ~= nil, "recorded in the outfit's triggerState")
    st.worn[id] = nil
    NS.SendBus(NS.MSG.OUTFIT_REMOVED, id, false)
    assertFalse(tracking[2].active); assertEqual(M.__cvars.autoLootDefault, "0")
    -- red under: Restore keeping the record (a second removal would restore again).
    assertNil(next(rec.triggerState.FISHING), "the record is gone with the restore")
    -- The stand-down restores a worn outfit's effects (onSuspend); the spellID matches too.
    tracking[2] = { name = "Find Fish", texture = 0, active = false, spellID = 43308 }
    st.worn[id] = true
    NS.SendBus(NS.MSG.OUTFIT_WORN, id, nil, false)
    assertTrue(tracking[2].active, "Find Fish found by its spellID")
    NS.TriggerBinder.Suspend()
    -- red under: wireEffects leaving onSuspend unset.
    assertFalse(tracking[2].active, "the stand-down put tracking back")
    assertEqual(M.__cvars.autoInteract, "1")
end)

test("trade: dining is a smart unequip on STATE:DINING", function()
    local NS = scene()
    local id, st = bound(NS, "DINING")
    st.worn[id] = true
    state(NS, "DINING", false)
    -- red under: smartUnequip unequipping without DidEquip.
    assertEqual(log(st), "", "a manual wear stays")
    st.worn[id] = nil
    state(NS, "DINING", true)
    state(NS, "DINING", false)
    assertEqual(log(st), "wear,remove")
end)

-- ── FALLING, RESTING (rows 22, 23) ────────────────────────────────────────────────────────────

test("trade: falling ticks every 0.5 s, equips with a 4 s delay and smart-unequips on landing", function()
    local NS, M = scene()
    local id, st, equip, ctx = bound(NS, "FALLING")
    assertEqual(tickers(M, ctx), 1, "the always-on ticker")
    M.__fireTimers()
    -- red under: FALLING equipping without IsFalling().
    assertEqual(log(st), "", "on the ground")
    M.__world:setFlag("IsFalling", true)
    M.__fireTimers()
    assertTrue(st.worn[id])
    assertEqual(delays(equip), "4")
    M.__world:setFlag("IsFalling", false)
    M.__fireTimers()
    assertEqual(log(st), "wear,remove")
    st.worn[id] = true
    M.__fireTimers()
    -- red under: unequipping without DidEquip.
    assertEqual(log(st), "wear,remove", "a manual wear stays")
end)

test("trade: resting evaluates at bind and on PLAYER_UPDATE_RESTING, not smart", function()
    local NS, M = scene(function(M) M.__world:setFlag("IsResting", true) end)
    local id, st = bound(NS, "RESTING")
    assertTrue(NS.Triggers.Get("RESTING").initial)
    M.__fireTimers()
    -- red under: no BIND evaluation (the login in an inn is missed).
    assertTrue(st.worn[id], "the bind-time evaluation, in an inn")
    M.__world:setFlag("IsResting", false)
    M.__fire("PLAYER_UPDATE_RESTING")
    assertEqual(log(st), "wear,remove")
    st.worn[id] = true
    M.__fire("PLAYER_ENTERING_WORLD", false, false)
    assertEqual(log(st), "wear,remove,remove", "leaving the inn takes it off whoever wore it")
end)

-- ── SPELLCAST (row 29) ────────────────────────────────────────────────────────────────────────

test("trade: spellcast matches the player's cast by spellID, interrupts with dontWait, and unequips on another", function()
    local NS, M = scene()
    local interrupts = {}
    local id, st = bound(NS, "SPELLCAST", { spellIDs = { 7620, 131474 }, dontWait = true })
    local PS = NS.PlayerState
    local orig = PS.SetInterruptCasting
    PS.SetInterruptCasting = function(on) interrupts[#interrupts + 1] = tostring(on); return orig(on) end
    M.__fire("UNIT_SPELLCAST_START", "target", "Cast-1", 131474)
    -- red under: the binder's unit filter passing every unit.
    assertEqual(log(st), "", "another unit's cast")
    -- red under: matching the castGUID (the 2nd argument) as the legacy did.
    M.__fire("UNIT_SPELLCAST_START", "player", "Cast-2", 131474)
    assertTrue(st.worn[id], "the listed spell")
    assertEqual(table.concat(interrupts, ","), "true", "dontWait interrupts the cast")
    M.__fire("UNIT_SPELLCAST_START", "player", "Cast-3", 133)
    assertEqual(log(st), "wear,remove", "another spell takes it off")
    M.__fire("UNIT_SPELLCAST_START", "player", "Cast-4", 7620)
    M.__fire("UNIT_SPELLCAST_START", "player", "Cast-5", T.secret(133))
    -- red under: reading the spellID without Secrets.PlainNumber (a secret is "another spell" or raises).
    assertEqual(log(st), "wear,remove,wear", "a secret spellID is no verdict at all")
    PS.SetInterruptCasting = orig
end)

test("trade: spellcast without dontWait does not interrupt", function()
    local NS, M = scene()
    local interrupted = false
    local id, st = bound(NS, "SPELLCAST", { spellIDs = { 7620 } })
    local orig = NS.PlayerState.SetInterruptCasting
    NS.PlayerState.SetInterruptCasting = function(on) interrupted = interrupted or on; return orig(on) end
    M.__fire("UNIT_SPELLCAST_START", "player", "Cast-1", 7620)
    assertTrue(st.worn[id])
    -- red under: returning `interrupt = true` unconditionally.
    assertFalse(interrupted, "it waits for the cast to end")
    NS.PlayerState.SetInterruptCasting = orig
end)

-- ── COOKING (row 32) ──────────────────────────────────────────────────────────────────────────

local function fakePets(NS)
    local calls = {}
    T.fake(NS, "Companion", {
        SummonBySpecies = function(s, d) calls[#calls + 1] = "species " .. s .. "@" .. tostring(d); return true end,
        SummonByGUID = function(g, d) calls[#calls + 1] = "summon " .. g .. "@" .. tostring(d); return true end,
        DismissByGUID = function(g, d) calls[#calls + 1] = "dismiss " .. g .. "@" .. tostring(d); return true end,
    })
    return calls
end

test("trade: cooking equips on the Cooking window (profession 185) only, and smart-unequips on close", function()
    local NS, M = scene()
    local calls = fakePets(NS)
    local id, st = bound(NS, "COOKING")
    M.__world.profession = { professionID = 171 }
    M.__fire("TRADE_SKILL_SHOW")
    -- red under: equipping on any TRADE_SKILL_SHOW.
    assertEqual(log(st), "", "Alchemy is not Cooking")
    M.__world.profession = { professionID = 185 }
    M.__fire("TRADE_SKILL_SHOW")
    assertTrue(st.worn[id])
    M.__fire("TRADE_SKILL_CLOSE")
    assertEqual(log(st), "wear,remove")
    st.worn[id] = true
    M.__fire("TRADE_SKILL_CLOSE")
    -- red under: the close dropping its DidEquip test.
    assertEqual(log(st), "wear,remove", "a manual wear stays")
    -- red under: cookingPet answering the first COOKING_PETS species with no flag set.
    assertEqual(#calls, 0, "no pet flag: no pet")
end)

test("trade: cooking summons its fire pet 0.2 s on, saves the pet that was out, and puts it back on close", function()
    local NS, M = scene()
    local calls = fakePets(NS)
    M.__world.summonedPet = "BattlePet-0-000000000001"
    local id = bound(NS, "COOKING", { summonRagnaros = true, summonPierre = true })
    local rec = NS.db.char.outfits[id]
    M.__world.profession = { professionID = 185 }
    M.__fire("TRADE_SKILL_SHOW")
    -- red under: preferring Pierre (the legacy order is Lil' Ragnaros first without randomPet).
    assertEqual(table.concat(calls, ","), "species 297@0.2")
    assertEqual(rec.triggerState.COOKING.pet.saved, "BattlePet-0-000000000001", "the pet that was out")
    M.__fire("TRADE_SKILL_CLOSE")
    -- red under: the close skipping RestorePet.
    assertEqual(table.concat(calls, ","), "species 297@0.2,summon BattlePet-0-000000000001@0.2")
    assertNil(rec.triggerState.COOKING.pet, "the record goes with the restore")
end)

test("trade: a cooking wear that never reached its restore leaves no stale pet for the next one", function()
    local NS, M = scene()
    local calls = fakePets(NS)
    M.__world.summonedPet = "BattlePet-0-00000000000A"
    local id, st = bound(NS, "COOKING", { summonPierre = true })
    local rec = NS.db.char.outfits[id]
    M.__world.profession = { professionID = 185 }
    M.__fire("TRADE_SKILL_SHOW")
    assertEqual(rec.triggerState.COOKING.pet.saved, "BattlePet-0-00000000000A")
    st.worn[id], st.did[id] = nil, false                 -- taken off by hand while cooking
    M.__fire("TRADE_SKILL_CLOSE")
    assertEqual(#calls, 1, "no DidEquip: no restore at this close")
    M.__world.summonedPet = "BattlePet-0-00000000000B"   -- a later session, another pet out
    M.__fire("TRADE_SKILL_SHOW")
    -- red under: SavePet keeping a record a wear left behind (the legacy re-read the pet at each show).
    assertEqual(rec.triggerState.COOKING.pet.saved, "BattlePet-0-00000000000B", "the pet out at this show")
    M.__fire("TRADE_SKILL_CLOSE")
    assertEqual(calls[#calls], "summon BattlePet-0-00000000000B@0.2", "the pet that was out comes back")
    st.worn[id], st.did[id] = true, true                 -- worn by this trigger: a second show keeps the record
    rec.triggerState.COOKING.pet = { saved = "BattlePet-0-00000000000B" }
    M.__world.summonedPet = "BattlePet-0-000000000F1E"   -- the fire pet is out now
    M.__fire("TRADE_SKILL_SHOW")
    -- red under: SavePet dropping the record on every show (a second show would save the fire pet).
    assertEqual(rec.triggerState.COOKING.pet.saved, "BattlePet-0-00000000000B", "once per wear")
end)

test("trade: cooking with randomPet picks among the enabled pets only, and dismisses when none was out", function()
    local NS, M = scene()
    local calls = fakePets(NS)
    local id = bound(NS, "COOKING", { summonPierre = true, randomPet = true })
    local picks = {}
    NS.TriggerConditions.COOKING.random = function(n) picks[#picks + 1] = n; return n end
    M.__world.profession = { professionID = 185 }
    M.__fire("TRADE_SKILL_SHOW")
    -- red under: the random pick reading every COOKING_PETS row rather than the enabled ones.
    assertEqual(table.concat(picks, ","), "1", "one pet enabled: a pick of one")
    assertEqual(calls[1], "species 1204@0.2", "Pierre")
    M.__world.summonedPet = "BattlePet-0-000000000009"           -- the fire pet came out
    M.__fire("TRADE_SKILL_CLOSE")
    assertEqual(calls[2], "dismiss BattlePet-0-000000000009@0.2", "none was out before: dismissed")
    NS.SetByPath("trigger.COOKING.summonRagnaros", true, id)
    NS.TriggerBinder.Bind(id)
    M.__world.summonedPet = nil
    M.__fire("TRADE_SKILL_SHOW")
    assertEqual(table.concat(picks, ","), "1,2", "two enabled")
    assertEqual(calls[3], "species 1204@0.2", "the pick's second: Pierre")
end)
