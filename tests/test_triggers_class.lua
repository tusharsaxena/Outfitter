-- tests/test_triggers_class.lua — P4.16d (design §6.8.3 rows 70-83): the class and spec triggers,
-- end to end. The client's forms and auras (tests/mock_world.lua) feed the real state producers
-- (modules/States.lua), whose edges reach the real binder (modules/Triggers_Binder.lua) and the
-- families P4.15 landed (modules/Triggers_Families.lua): caster form's 0.1 s wait, the five shapes on
-- the shapeshift layer with the 2 s combat delay and unequipComplete, Tree of Life and Prowl that
-- fire at last (O27), rogue Stealth with its auto loot, Ghost Wolf, Feign Death, and SPEC_1..N built
-- per class, acting only when the spec changed, half a second late.
--
-- The family-level verdicts are pinned in tests/test_triggers.lua; this suite pins that the producer,
-- the catalog row and the family meet. NS.Stack and NS.Equip are recorded stand-ins (as in
-- tests/test_trigger_binder.lua), so a case reads exactly which wear, removal or delay a state asked for.

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- The druid's shapes, by form index, and the state each one sets (defaults/TriggerData.lua).
local FORMS = { { spellID = 5487 }, { spellID = 768 }, { spellID = 783 }, { spellID = 24858 }, { spellID = 33891 } }
local FORM_TRIGGER = { "DRUID_BEAR", "DRUID_CAT", "DRUID_TRAVEL", "DRUID_MOONKIN", "DRUID_TREE" }

local function aura(spellId) return { spellId = spellId, icon = 136000, name = "aura" .. spellId } end

-- The recorded Stack: the worn set, the trigger-wear marks, and the OUTFIT_WORN/REMOVED sends the
-- real one makes (so a worn outfit's effects run).
local function fakeStack(NS)
    local st = { worn = {}, did = {}, didUn = {}, log = {} }
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

-- A fresh instance at t = 100 for `class` in `spec`, with the outfits `make(NS)` creates bound and the
-- producers resumed and settled. Answers { NS, M, W, st, equip, ids = make's answer }.
local function scene(class, spec, make, mutate)
    local inst = unitLoad({ mutate = function(M)
        M.__world:setClass(class, spec or 1)
        if mutate then mutate(M) end
    end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    M.HasFullControl = function() return true end
    local st = fakeStack(NS)
    local equip = T.fake(NS, "Equip", {
        Batch = function(fn, ...) return true, fn(...) end,
        SetUpdateDelay = true, SuspendedForLoad = function() return false end,
        DelayUntil = true, Request = true,
    })
    local ids = make and make(NS) or {}
    NS.PlayerState.Resume()
    NS.TriggerBinder.BindAll()
    NS.States.Resume()
    for _ = 1, 3 do M.__fireTimers() end
    return { NS = NS, M = M, W = M.__world, st = st, equip = equip, ids = ids }
end

-- One aura or form change: UNIT_AURA, the scan, then the form poll 0.01 s later.
local function settle(s)
    s.M.__fire("UNIT_AURA", "player")
    for _ = 1, 3 do s.M.__fireTimers() end
end

local function log(s) return table.concat(s.st.log, ",") end
local function clear(s) s.st.log = {}; for i = #s.equip.__calls, 1, -1 do s.equip.__calls[i] = nil end end

-- The SetUpdateDelay delays asked for since the last clear, as text.
local function delays(s)
    local out = {}
    for _, c in ipairs(s.equip.__calls) do
        if c[1] == "SetUpdateDelay" then out[#out + 1] = tostring(c[3]) end
    end
    return table.concat(out, ",")
end

-- A trigger's own wear of a shape outfit: worn on the shapeshift layer, then the OUTFIT_WORN edge the
-- Stack sends tags that layer again, as the legacy OUTFIT_EQUIPPED branch did for every wear
-- (OutfitterScripting.lua:393-394). The repeat tag is a no-op on the real Stack.
local function shifted(id) return "wear " .. id .. "/shapeshift,tag " .. id .. "/shapeshift" end

-- An outfit on `trigger`; `complete` fills every slot, so NS.Outfits files it as Complete and keeps it
-- there through an edit (Outfits.Changed re-categorizes from the items).
local function create(NS, name, trigger, complete)
    local items = {}
    if complete then
        for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do items[slot] = { id = 0 } end
    end
    local id = NS.Outfits.Create(name, items, { trigger = trigger })
    assertEqual(NS.Outfits.Get(id).category, complete and "Complete" or "Accessory", name)
    return id
end

-- ── the druid ─────────────────────────────────────────────────────────────────────────────────

test("class: caster form wears 0.1 s late on the shapeshift layer and comes off for a shape", function()
    local s = scene("DRUID", 1, function(NS) return { caster = create(NS, "Caster", "DRUID_CASTER") } end,
                    function(M) M.__world:setForms(FORMS, 0) end)
    local id = s.ids.caster
    -- red under: readForms dropping the druid's FORM_CASTER substitution (no form active is no state).
    assertEqual(log(s), shifted(id), "a druid in no form is in caster form")
    -- red under: F.druidCaster answering EQUIP with no delay (the passing caster form would equip).
    assertEqual(delays(s), "0.1")
    clear(s)
    s.W:setForms(FORMS, 2)
    settle(s)
    assertEqual(log(s), "remove " .. id, "cat form: caster is off")
    -- red under: F.druidCaster's unequip given the 0.1 s wear delay (the shape would wait in caster gear).
    assertEqual(delays(s), "", "taken off at once")
    clear(s)
    s.W:setForms(FORMS, 0)
    s.W:setInstance({ type = "party", instanceID = 1 })
    s.NS.SetByPath("trigger.DRUID_CASTER.disableInstance", true, id)
    s.M.__fireTimers()                                   -- the coalesced rebind
    settle(s)
    -- red under: DRUID_CASTER_GUARDS without G.instance (the guard row 70 alone carries).
    assertEqual(log(s), "", "disableInstance: no caster outfit in a dungeon")
end)

test("class: each shape wears its own outfit on the shapeshift layer, Tree of Life included", function()
    local s = scene("DRUID", 1, function(NS)
        local ids = {}
        for i, tid in ipairs(FORM_TRIGGER) do ids[i] = create(NS, tid, tid) end
        return ids
    end)
    for i, tid in ipairs(FORM_TRIGGER) do
        clear(s)
        s.W:setForms(FORMS, i)
        settle(s)
        local want = shifted(s.ids[i])
        if i > 1 then want = "remove " .. s.ids[i - 1] .. "," .. want end
        -- legacy: the Tree outfit never fires, cShapeshiftIDInfo has no 33891 (Outfitter.lua:1297-1307;
        -- a Fix row of design §6.8.3, row 75, O27; INV §19 has no entry for it); fixed: Tree of Life
        -- sets FORM_TREE and wears its outfit like every other shape.
        -- red under: dropping 33891 from FORM_SPELL_STATE (the Tree outfit never fired, O27).
        assertEqual(log(s), want, tid)
        -- red under: F.druidForm's unequip delay without its InCombat test (2 s out of combat too).
        assertEqual(delays(s), "", tid .. ": no delay out of combat")
    end
    for i in ipairs(FORM_TRIGGER) do
        assertEqual(s.st.worn[s.ids[i]] == true, i == #FORM_TRIGGER, FORM_TRIGGER[i] .. " worn")
    end
end)

test("class: leaving a shape in combat waits two seconds; a Complete outfit stays unless unequipComplete", function()
    local s = scene("DRUID", 1, function(NS)
        return { bear = create(NS, "Bear", "DRUID_BEAR"), cat = create(NS, "Cat", "DRUID_CAT", true),
                 travel = create(NS, "Travel", "DRUID_TRAVEL", true) }
    end)
    s.NS.SetByPath("trigger.DRUID_TRAVEL.unequipComplete", true, s.ids.travel)
    s.M.__fireTimers()
    s.W:setForms(FORMS, 1)
    settle(s)
    assertTrue(s.st.worn[s.ids.bear])
    clear(s)
    s.W:setCombat(true)
    s.W:setForms(FORMS, 0)
    settle(s)                                            -- in combat the scan waits its 2 s, then runs
    assertEqual(log(s), "remove " .. s.ids.bear)
    -- red under: F.druidForm's `InCombat() and 2 or nil` gone (a heal waits for the global cooldown).
    assertEqual(delays(s), "2", "two seconds in combat")
    s.W:setCombat(false)
    s.W:setForms(FORMS, 2)
    settle(s)
    clear(s)
    s.W:setForms(FORMS, 3)
    settle(s)
    -- red under: F.druidForm unequipping a Complete outfit without unequipComplete.
    assertEqual(log(s), shifted(s.ids.travel), "the Complete cat outfit stays on")
    assertTrue(s.st.worn[s.ids.cat])
    clear(s)
    s.W:setForms(FORMS, 0)
    settle(s)
    -- red under: F.druidForm ignoring ctx.params.unequipComplete.
    assertEqual(log(s), "remove " .. s.ids.travel, "unequipComplete takes the Complete one off")
end)

test("class: a manual wear of a shape outfit tags the shapeshift layer; a stun's shift is not the player's", function()
    local s = scene("DRUID", 1, function(NS) return { cat = create(NS, "Cat", "DRUID_CAT") } end)
    clear(s)
    s.NS.SendBus(s.NS.MSG.OUTFIT_WORN, s.ids.cat, nil, false)
    assertEqual(log(s), "tag " .. s.ids.cat .. "/shapeshift")
    clear(s)
    s.st.worn[s.ids.cat] = nil
    s.M.HasFullControl = function() return false end
    s.W:setForms(FORMS, 2)
    settle(s)
    -- red under: DRUID_FORM_GUARDS without G.noControl.
    assertEqual(log(s), "", "no full control: no wear")
end)

test("class: Prowl and Shadowmeld feed the druid's Prowl outfit", function()
    local s = scene("DRUID", 1, function(NS) return { prowl = create(NS, "Prowl", "DRUID_PROWL") } end)
    local id = s.ids.prowl
    s.W:setAuras("player", "HELPFUL", { aura(5215) })
    settle(s)
    -- legacy: only Shadowmeld (58984) fed STEALTH, so Prowl wore nothing (cSpellIDToSpecialID; a Fix
    -- row of design §6.8.3, row 76, O27; INV §19 has no entry for it); fixed: Prowl 5215 feeds it.
    -- red under: dropping 5215 from AURA_SPELL_STATE (only Shadowmeld fed STEALTH, O27).
    assertEqual(log(s), "wear " .. id, "Prowl")
    s.W:setAuras("player", "HELPFUL", {})
    settle(s)
    assertEqual(log(s), "wear " .. id .. ",remove " .. id)
    clear(s)
    -- Shadowmeld's spell is per client (probe P4): 20580 on WoW Forever, 58984 on Retail.
    local forever = dofile("tests/_kit/mock_client.lua").current() == "forever"
    s.W:setAuras("player", "HELPFUL", { aura(forever and 20580 or 58984) })
    settle(s)
    assertEqual(log(s), "wear " .. id, "Shadowmeld")
end)

-- ── the rogue, the shaman, the hunter ─────────────────────────────────────────────────────────

test("class: rogue Stealth wears its outfit, turning auto loot on only while worn and only when asked", function()
    local s = scene("ROGUE", 1, function(NS)
        return { loot = create(NS, "Loot", "ROGUE_STEALTH"), plain = create(NS, "Plain", "ROGUE_STEALTH") }
    end, function(M) M.__cvars.autoLootDefault = "0" end)
    s.NS.SetByPath("trigger.ROGUE_STEALTH.autoLoot", true, s.ids.loot)
    s.M.__fireTimers()
    s.M.__cvarWrites = {}
    s.W:setForms({ { spellID = 1784 } }, 1)
    settle(s)
    assertTrue(s.st.worn[s.ids.loot] and s.st.worn[s.ids.plain], "both stealth outfits on")
    assertEqual(s.M.__cvars.autoLootDefault, "1", "auto loot while stealthed")
    -- red under: Effects.Apply ignoring the effect's param (the plain outfit would write it too).
    assertEqual(#s.M.__cvarWrites, 1, "one write: the plain outfit leaves auto loot alone")
    s.W:setForms({ { spellID = 1784 } }, 0)
    settle(s)
    assertNil(s.st.worn[s.ids.loot])
    -- red under: ROGUE_STEALTH without OUTFIT_REMOVED in its events (the restore never runs).
    assertEqual(s.M.__cvars.autoLootDefault, "0", "restored on removal")
end)

test("class: Ghost Wolf and Feign Death wear their outfits on the aura and take them off when it fades", function()
    for _, c in ipairs({ { "SHAMAN", "SHAMAN_GHOST_WOLF", 2645 }, { "HUNTER", "HUNTER_FEIGN_DEATH", 5384 } }) do
        local s = scene(c[1], 1, function(NS) return { o = create(NS, c[2], c[2]) } end)
        local id = s.ids.o
        -- Precondition, not a pin: the log asserted below counts from the stand-up. No mutation of the
        -- simple family reaches it (a stand-up publishes no edge; test_states pins that rule).
        assertEqual(log(s), "", c[2] .. ": nothing at the stand-up")
        s.W:setAuras("player", "HELPFUL", { aura(c[3]) })
        settle(s)
        s.W:setAuras("player", "HELPFUL", {})
        settle(s)
        assertEqual(log(s), "wear " .. id .. ",remove " .. id, c[2])
        clear(s)
        s.W:setAuras("player", "HELPFUL", { aura(c[3] + 1) })
        settle(s)
        -- red under: an off-by-one AURA_SPELL_STATE lookup in noteAura (a neighboring spell id feeds it).
        assertEqual(log(s), "", c[2] .. ": another aura is nothing")
    end
end)

test("class: each class is offered its own class triggers and no other class's", function()
    local s = scene("DRUID", 1)
    local mine = {
        DRUID = "DRUID_BEAR,DRUID_CASTER,DRUID_CAT,DRUID_MOONKIN,DRUID_PROWL,DRUID_TRAVEL,DRUID_TREE",
        ROGUE = "ROGUE_STEALTH", SHAMAN = "SHAMAN_GHOST_WOLF", HUNTER = "HUNTER_FEIGN_DEATH", WARRIOR = "",
    }
    for class, want in pairs(mine) do
        local ids = {}
        for _, d in ipairs(s.NS.Triggers.List("CLASS", class)) do ids[#ids + 1] = d.id end
        table.sort(ids)
        assertEqual(table.concat(ids, ","), want, class)
    end
end)

-- ── the specializations ───────────────────────────────────────────────────────────────────────

test("class: SPEC_1..N are generated for every class, named '<class>: <spec>', and no more", function()
    local s = scene("DRUID", 1)
    local Tr = s.NS.Triggers
    local classes = {}
    for token in pairs(T.world.CLASSES) do classes[#classes + 1] = token end
    table.sort(classes)
    for _, token in ipairs(classes) do
        local c = T.world.CLASSES[token]
        s.W:setClass(token, 1)
        Tr.Finalize()
        for i, spec in ipairs(c[2]) do
            local d = Tr.Get("SPEC_" .. i)
            assertTrue(d ~= nil, token .. " SPEC_" .. i)
            assertEqual(d.name, c[1] .. ": " .. spec[2])
            assertEqual(d.class, token)
            assertEqual(d.category, "SPEC")
            assertEqual(d.family, "spec")
            assertTrue(d.initial, "evaluated at bind")
        end
        -- red under: specRows building MAX_SPECS rows whatever the class has (a warrior would get a SPEC_4).
        assertNil(Tr.Get("SPEC_" .. (#c[2] + 1)), token .. ": no spec past its own")
        local ids = {}
        for _, d in ipairs(Tr.List("SPEC", token)) do ids[#ids + 1] = d.id end
        assertEqual(#ids, #c[2], token .. " lists its own")
    end
end)

test("class: a spec outfit acts only when the spec changed, half a second late", function()
    local s = scene("DRUID", 1, function(NS)
        return { one = create(NS, "One", "SPEC_1"), two = create(NS, "Two", "SPEC_2") }
    end)
    local one, two = s.ids.one, s.ids.two
    assertEqual(log(s), "wear " .. one, "the BIND evaluation wears the active spec's outfit")
    assertEqual(delays(s), "0.5")
    clear(s)
    s.st.worn[one] = nil                                 -- taken off by hand
    s.M.__fire("PLAYER_ENTERING_WORLD", false, true)
    s.M.__fireTimers()
    -- red under: F.spec without its prevSpec check (a loading screen would put it back on).
    assertEqual(log(s), "", "the spec did not change: nothing")
    s.M.__spec = 2
    s.M.__fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    assertEqual(log(s), "wear " .. two, "the new spec's outfit")
    assertEqual(delays(s), "0.5")
    clear(s)
    s.st.worn[two] = nil                                 -- taken off by hand: only prevSpec keeps it off
    s.M.__fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    -- red under: F.spec skipping its prevSpec check on the spec-change event (a repeat re-wears it).
    assertEqual(log(s), "", "the same spec again: nothing")
    s.st.worn[two] = true
    s.M.__spec = 1
    s.M.__fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    -- The two bindings hear the event in the bus's order (CallbackHandler walks next()): read the set.
    assertEqual(#s.st.log, 2, log(s))
    assertTrue(s.st.worn[one] and not s.st.worn[two], "spec 1's outfit on, spec 2's off")
    assertEqual(delays(s), "0.5,0.5", "both changes wait half a second")
end)

test("class: a stand-in class with fewer specs hides the spec toggles past its own", function()
    local s = scene("WARRIOR", 1)
    local d = s.NS.Triggers.Get("DRUID_BEAR")
    local hidden = {}
    for _, p in ipairs(d.params) do
        if p.specIndex then hidden[#hidden + 1] = tostring(p.hidden()) end
    end
    -- red under: the spec toggle's hidden() answering false (a three-spec class would show spec4).
    assertEqual(table.concat(hidden, ","), "false,false,false,true")
    assertFalse(s.NS.Triggers.Get("SPEC_3") == nil)
end)
