-- tests/test_triggers_quest.lua — P4.16c (design §6.8.1 rows 24-28, 30, 31, 36): the QUEST and
-- ENTERTAIN triggers. The three vehicle quests run the `vehicleMount` family (modules/Triggers_Families.lua,
-- P4.15) on defaults/TriggerData.lua's NPC sets; the five bespoke conditions are
-- modules/Triggers_CondQuest.lua's: QUEST_MULTIPHASE_SURVEY, QUEST_TURNIN, PET_BATTLE, DANCE and COMPANION.
--
-- Every case runs on a fresh instance whose descriptors are the shipped ones: the conditions here are
-- the real ones, resolved by Finalize at OnInitialize. A condition is called on a hand-made context, as
-- tests/test_triggers.lua does; the last cases bind real outfits so the binder delivers the events.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function fresh(mutate)
    local inst = T.load({ mutate = mutate })
    inst.mocks.__now = 100
    return inst.NS, inst.mocks
end

-- A hand-made context for calling a condition or a hook directly.
local function ctxFor(ns, id, over)
    over = over or {}
    local desc = assert(ns.Triggers.Get(id), id)
    local ctx = { desc = desc, outfitId = "o1", state = over.state or {}, now = over.now or 100,
                  params = ns.TriggerParams.Resolve(desc, over.params) }
    function ctx.IsWorn() return over.worn == true end
    function ctx.DidEquip() return over.did == true end
    function ctx.DidUnequip() return over.didUn == true end
    function ctx.IsComplete() return over.complete == true end
    return ctx
end

local function call(ns, id, over, event, ...)
    local ctx = ctxFor(ns, id, over)
    return ctx.desc.condition(ctx, event, ...)
end

-- The four content quests and Pet Battle are Retail's alone (clients-§4; rulings D5, D6): a case
-- that drives one of them skips on the forever kit profile, where the trigger does not exist.
local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"
local RETAIL_ONLY = { "QUEST_ARGENT_TOURNAMENT", "QUEST_VIGILANCE_ON_WINGS", "QUEST_FLAME_LEVIATHAN",
                      "QUEST_MULTIPHASE_SURVEY", "PET_BATTLE" }
local function retailOnly()
    if FOREVER then T.skip("a Retail-only trigger, absent on WoW Forever (clients-§4)") end
end

local function guid(unitType, npcID) return ("%s-0-3767-571-11063-%d-0000ABCDEF"):format(unitType, npcID) end

local function keys(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return table.concat(out, ",")
end

local function sorted(list)
    table.sort(list)
    return table.concat(list, ",")
end

-- ── the vehicle quests (rows 24-26) ───────────────────────────────────────────────────────────

-- The legacy NPC lists as OutfitterScripting.lua@7ea3dc3 wrote them: the Argent Tournament's mounts
-- by faction (1412-1432) plus the two either faction rides (1435-1436), Aviana's Guardian
-- (1481-1484) and the Ulduar siege vehicles (1528-1532).
local LEGACY = {
    ALLIANCE  = { 33790, 33793, 33794, 33795, 33800, 33843, 36557, 33870, 34125 },
    HORDE     = { 33791, 33792, 33796, 33798, 33799, 33842, 36558, 33870, 34125 },
    VIGILANCE = { 39710, 40719, 40720, 40723 },
    LEVIATHAN = { 33060, 33109, 33062 },
}

test("quest: the vehicle NPC lists equal the legacy scripts', by faction", function()
    local ns = fresh()
    local D = ns.TriggerData
    assertEqual(keys(D.ARGENT_MOUNTS.Alliance), sorted(LEGACY.ALLIANCE))
    assertEqual(keys(D.ARGENT_MOUNTS.Horde), sorted(LEGACY.HORDE))
    assertEqual(keys(D.VIGILANCE_NPCS), sorted(LEGACY.VIGILANCE))
    assertEqual(keys(D.LEVIATHAN_NPCS), sorted(LEGACY.LEVIATHAN))
    -- The legacy `if Alliance ... else <Horde>`: any other faction value reads the Horde set.
    assertEqual(keys(D.ARGENT_MOUNTS.Neutral), sorted(LEGACY.HORDE))
end)

test("quest: each vehicle trigger equips on every NPC of its list, by its own GUID type", function()
    retailOnly()
    local ns, M = fresh()
    local cases = {
        { id = "QUEST_ARGENT_TOURNAMENT",  unitType = "Vehicle",  other = "Creature", list = LEGACY.ALLIANCE },
        { id = "QUEST_VIGILANCE_ON_WINGS", unitType = "Creature", other = "Vehicle",  list = LEGACY.VIGILANCE },
        { id = "QUEST_FLAME_LEVIATHAN",    unitType = "Vehicle",  other = "Creature", list = LEGACY.LEVIATHAN },
    }
    M.__units.player.faction = "Alliance"
    for _, c in ipairs(cases) do
        for _, npcID in ipairs(c.list) do
            M.__units.mouseover = { guid = guid(c.unitType, npcID) }
            assertEqual(call(ns, c.id, {}, "TOOLTIP_SHOW"), "equip", c.id .. " " .. npcID)
            assertEqual(call(ns, c.id, {}, "UPDATE_MOUSEOVER_UNIT"), "equip", c.id .. " " .. npcID .. " mouseover")
            M.__units.mouseover = { guid = guid(c.other, npcID) }
            assertNil(call(ns, c.id, {}, "TOOLTIP_SHOW"), c.id .. " " .. npcID .. " as a " .. c.other)
        end
        M.__units.mouseover = { guid = guid(c.unitType, 12345) }
        assertNil(call(ns, c.id, {}, "TOOLTIP_SHOW"), c.id .. ": an NPC off the list")
        M.__units.mouseover = nil
        assertNil(call(ns, c.id, {}, "TOOLTIP_SHOW"), c.id .. ": no mouseover unit")
    end
    M.__units.player.faction = "Horde"
    M.__units.mouseover = { guid = guid("Vehicle", 33799) }
    assertEqual(call(ns, "QUEST_ARGENT_TOURNAMENT", {}, "TOOLTIP_SHOW"), "equip", "a Horde mount for a Horde player")
    M.__units.mouseover = { guid = guid("Vehicle", 33790) }
    assertNil(call(ns, "QUEST_ARGENT_TOURNAMENT", {}, "TOOLTIP_SHOW"), "an Alliance mount is not a Horde one")
    M.__units.mouseover = { guid = T.secret(guid("Vehicle", 33799)) }
    assertNil(call(ns, "QUEST_ARGENT_TOURNAMENT", {}, "TOOLTIP_SHOW"), "a secret GUID is no match")
end)

test("quest: the tooltip hiding unequips a second late, unless the player is in the vehicle", function()
    retailOnly()
    local ns, M = fresh()
    for _, id in ipairs({ "QUEST_ARGENT_TOURNAMENT", "QUEST_VIGILANCE_ON_WINGS", "QUEST_FLAME_LEVIATHAN" }) do
        local ctx = ctxFor(ns, id, { did = true, now = 50 })
        local a, d = ctx.desc.condition(ctx, "TOOLTIP_HIDE")
        assertEqual(a, "unequip", id)
        assertEqual(d, 1, id .. ": the 1 s delay")
        assertEqual(ctx.state.unequipAt, 50, id .. ": the unequip time is kept for the cancel")
        assertNil(call(ns, id, {}, "TOOLTIP_HIDE"), id .. ": nothing to take off when it did not equip")
        M.__world:setFlag("UnitInVehicle", true)
        ctx = ctxFor(ns, id, { did = true, now = 60 })
        assertNil(ctx.desc.condition(ctx, "TOOLTIP_HIDE"), id .. ": aboard, the outfit stays")
        assertNil(ctx.state.unequipAt, id .. ": no unequip time recorded")
        M.__world:setFlag("UnitInVehicle", false)
    end
end)

test("quest: boarding within 3 s of that unequip cancels it, and not at 3 s or later", function()
    retailOnly()
    local ns = fresh()
    for _, id in ipairs({ "QUEST_ARGENT_TOURNAMENT", "QUEST_VIGILANCE_ON_WINGS", "QUEST_FLAME_LEVIATHAN" }) do
        local within = call(ns, id, { didUn = true, now = 52.9, state = { unequipAt = 50 } }, "UNIT_ENTERED_VEHICLE", "player")
        assertEqual(within, "equip", id .. ": boarded 2.9 s after")
        -- red under: the family's `ctx.now - at < 3` written `<= 3` (a boarding at exactly 3 s re-equips).
        assertNil(call(ns, id, { didUn = true, now = 53, state = { unequipAt = 50 } }, "UNIT_ENTERED_VEHICLE", "player"),
            id .. ": 3 s is too late")
        assertNil(call(ns, id, { didUn = true, now = 51 }, "UNIT_ENTERED_VEHICLE", "player"), id .. ": no unequip time")
        assertNil(call(ns, id, { now = 51, state = { unequipAt = 50 } }, "UNIT_ENTERED_VEHICLE", "player"),
            id .. ": the trigger did not unequip")
    end
end)

test("quest: leaving the vehicle unequips; Flame Leviathan waits for combat to end", function()
    retailOnly()
    local ns, M = fresh()
    for _, id in ipairs({ "QUEST_ARGENT_TOURNAMENT", "QUEST_VIGILANCE_ON_WINGS" }) do
        assertEqual(call(ns, id, { did = true }, "UNIT_EXITED_VEHICLE", "player"), "unequip", id)
        assertNil(call(ns, id, {}, "UNIT_EXITED_VEHICLE", "player"), id .. ": it did not equip")
        M.__world:setFlag("UnitInVehicle", true)
        assertNil(call(ns, id, { did = true }, "UNIT_EXITED_VEHICLE", "player"), id .. ": still in a vehicle")
        M.__world:setFlag("UnitInVehicle", false)
        assertNil(call(ns, id, { did = true }, "PLAYER_REGEN_ENABLED"), id .. ": combat's end is Leviathan's alone")
    end
    local LEV = "QUEST_FLAME_LEVIATHAN"
    local hears = {}
    for _, e in ipairs(ns.Triggers.Get(LEV).events) do hears[e] = true end
    assertTrue(hears.PLAYER_REGEN_ENABLED, "Leviathan hears PLAYER_REGEN_ENABLED")
    assertEqual(call(ns, LEV, { did = true }, "UNIT_EXITED_VEHICLE", "player"), "unequip", "out of combat: off at once")
    M.__world:setCombat(true)
    ns.PlayerState.Refresh()
    assertTrue(ns.PlayerState.InCombat(), "the player state saw combat start")
    -- red under: the family's UNIT_EXITED_VEHICLE ignoring regenUnequip (Leviathan unequips mid-fight).
    assertNil(call(ns, LEV, { did = true }, "UNIT_EXITED_VEHICLE", "player"), "in combat: wait")
    M.__world:setCombat(false)
    ns.PlayerState.Refresh()
    assertEqual(call(ns, LEV, { did = true }, "PLAYER_REGEN_ENABLED"), "unequip", "combat over: off")
    assertNil(call(ns, LEV, {}, "PLAYER_REGEN_ENABLED"), "it did not equip")
    M.__world:setFlag("UnitInVehicle", true)
    assertNil(call(ns, LEV, { did = true }, "PLAYER_REGEN_ENABLED"), "back in a vehicle when combat ended")
end)

-- ── QUEST_MULTIPHASE_SURVEY (row 27) ──────────────────────────────────────────────────────────

test("quest: the Multiphase Survey equips in Nagrand on quest 11880, five seconds late", function()
    retailOnly()
    local ns, M = fresh()
    local asked = {}
    local isOn, isComplete = M.C_QuestLog.IsOnQuest, M.C_QuestLog.IsComplete
    M.C_QuestLog.IsOnQuest = function(id) asked[#asked + 1] = "on:" .. id; return isOn(id) end
    M.C_QuestLog.IsComplete = function(id) asked[#asked + 1] = "done:" .. id; return isComplete(id) end
    local desc = ns.Triggers.Get("QUEST_MULTIPHASE_SURVEY")
    assertTrue(desc.initial, "evaluated at bind")
    M.__world:setMap(107)
    M.__world.quests[11880] = { complete = false }
    local a, d = call(ns, "QUEST_MULTIPHASE_SURVEY", {}, "QUEST_LOG_UPDATE")
    assertEqual(a, "equip")
    assertEqual(d, 5, "the legacy 5 s delay")
    assertTrue(table.concat(asked, ","):find("on:11880", 1, true) ~= nil, "C_QuestLog.IsOnQuest(11880)")
    assertEqual(call(ns, "QUEST_MULTIPHASE_SURVEY", {}, "BIND"), "equip", "at bind too")
    -- red under: the survey condition not reading IsComplete (a finished survey keeps the outfit on).
    M.__world.quests[11880].complete = true
    assertEqual(call(ns, "QUEST_MULTIPHASE_SURVEY", {}, "QUEST_LOG_UPDATE"), "unequip", "the quest is complete")
    M.__world.quests[11880] = nil
    assertEqual(call(ns, "QUEST_MULTIPHASE_SURVEY", {}, "ZONE_CHANGED"), "unequip", "not on the quest")
    M.__world.quests[11880] = { complete = false }
    M.__world:setMap(100)
    -- red under: the survey condition skipping its map check (on the quest anywhere equips).
    assertEqual(call(ns, "QUEST_MULTIPHASE_SURVEY", {}, "ZONE_CHANGED_NEW_AREA"), "unequip", "out of Nagrand")
    -- The kit cannot trap `secret == 107` or `secret ~= true` (tests/_kit/secrets.lua: `==` against a
    -- non-table is answered false without __eq), so the seam is asserted explicitly: each secret
    -- answer must reach NS.Secrets before anything compares it.
    local seamSaw = {}
    local Sec = ns.Secrets
    local plainNumber, plainTruth = Sec.PlainNumber, Sec.PlainTruth
    Sec.PlainNumber = function(v, ...)
        if T.isSecret(v) then seamSaw[#seamSaw + 1] = "number" end
        return plainNumber(v, ...)
    end
    Sec.PlainTruth = function(v, ...)
        if T.isSecret(v) then seamSaw[#seamSaw + 1] = "truth" end
        return plainTruth(v, ...)
    end
    M.__world.mapID = T.secret(107)
    assertEqual(call(ns, "QUEST_MULTIPHASE_SURVEY", {}, "ZONE_CHANGED_INDOORS"), "unequip", "a secret map is not Nagrand")
    -- red under: bestMap comparing GetBestMapForUnit's answer without Secrets.PlainNumber.
    assertEqual(table.concat(seamSaw, ","), "number", "the secret map went through the seam")
    M.__world:setMap(107)
    M.C_QuestLog.IsOnQuest = function() return T.secret(true) end
    seamSaw = {}
    assertEqual(call(ns, "QUEST_MULTIPHASE_SURVEY", {}, "QUEST_LOG_UPDATE"), "unequip", "a secret answer is not on the quest")
    -- red under: onSurvey comparing IsOnQuest's answer without Secrets.PlainTruth.
    assertEqual(table.concat(seamSaw, ","), "truth", "the secret answer went through the seam")
    Sec.PlainNumber, Sec.PlainTruth = plainNumber, plainTruth
end)

-- ── QUEST_TURNIN (row 28) and PET_BATTLE (row 36) ─────────────────────────────────────────────

test("quest: the turn-in outfit goes on at QUEST_PROGRESS and off at QUEST_FINISHED if it put it on", function()
    local ns = fresh()
    assertEqual(call(ns, "QUEST_TURNIN", {}, "QUEST_PROGRESS"), "equip")
    assertEqual(call(ns, "QUEST_TURNIN", { worn = true, did = true }, "QUEST_PROGRESS"), "equip", "re-worn while on")
    assertEqual(call(ns, "QUEST_TURNIN", { did = true }, "QUEST_FINISHED"), "unequip")
    -- red under: QUEST_TURNIN's finish arm dropping its DidEquip check (a manual wear comes off).
    assertNil(call(ns, "QUEST_TURNIN", { worn = true }, "QUEST_FINISHED"), "smart: worn by hand, it stays")
    assertNil(call(ns, "QUEST_TURNIN", { did = true }, "BIND"), "no other event acts")
    assertFalse(ns.Triggers.Get("QUEST_TURNIN").initial == true, "no bind-time evaluation")
end)

test("quest: a pet battle's opening equips and its close unequips", function()
    retailOnly()
    local ns = fresh()
    assertEqual(call(ns, "PET_BATTLE", {}, "PET_BATTLE_OPENING_DONE"), "equip")
    assertEqual(call(ns, "PET_BATTLE", {}, "PET_BATTLE_CLOSE"), "unequip")
    assertEqual(call(ns, "PET_BATTLE", { worn = true }, "PET_BATTLE_CLOSE"), "unequip", "not smart: it always comes off")
    assertNil(call(ns, "PET_BATTLE", {}, "BIND"))
end)

-- ── DANCE (row 30) and COMPANION (row 31) ─────────────────────────────────────────────────────

test("quest: DANCE dances when its outfit is worn, and changes nothing itself", function()
    local ns, M = fresh()
    local emotes = {}
    M.DoEmote = function(token) emotes[#emotes + 1] = token end
    local ctx = ctxFor(ns, "DANCE")
    assertNil(ctx.desc.condition(ctx, "OUTFIT_WORN", "o1"), "no verdict")
    assertEqual(#emotes, 0, "the condition itself does not dance")
    ctx.desc.onWorn(ctx)
    assertEqual(table.concat(emotes, ","), "DANCE")
    assertNil(ctx.desc.onRemoved, "nothing to undo")
end)

test("quest: DANCE asks C_ChatInfo.PerformEmote before the DoEmote shim (OR-F4)", function()
    local ns, M = fresh()
    local modern, bare = {}, {}
    M.C_ChatInfo = { PerformEmote = function(token) modern[#modern + 1] = token end }
    M.DoEmote = function(token) bare[#bare + 1] = token end
    local ctx = ctxFor(ns, "DANCE")
    ctx.desc.onWorn(ctx)
    -- red under: Compat.PerformEmote calling DoEmote first.
    assertEqual(table.concat(modern, ","), "DANCE")
    assertEqual(#bare, 0, "the shim is not asked")
    M.C_ChatInfo, M.DoEmote = false, false
    assertFalse(ns.Compat.PerformEmote("DANCE"), "neither API: no emote, no raise")
end)

test("quest: COMPANION summons its pet two seconds after the wear, or says it couldn't find it", function()
    local ns, M = fresh()
    local pet = M.__world.pets[2].guid
    local companion = T.fake(ns, "Companion", { SummonByGUID = function() return true end })
    local ctx = ctxFor(ns, "COMPANION", { params = { pet = pet } })
    assertNil(ctx.desc.condition(ctx, "OUTFIT_WORN", "o1"), "no verdict")
    M.__resetPrinted()
    ctx.desc.onWorn(ctx)
    local c = companion.__calls
    assertEqual(#c, 1)
    assertEqual(c[1][1], "SummonByGUID")
    assertEqual(c[1][2], pet, "by the stored petGUID")
    assertEqual(c[1][3], 2, "two seconds late")
    assertEqual(#M.__printed(), 0, "found: nothing printed")

    -- red under: COMPANION's onWorn skipping its owned-pet check (an unowned GUID is summoned, silently).
    ctx = ctxFor(ns, "COMPANION", { params = { pet = "BattlePet-0-0000000000FF" } })
    ctx.desc.onWorn(ctx)
    assertEqual(companion.__count("SummonByGUID"), 1, "a pet the journal does not hold is not summoned")
    assertTrue(table.concat(M.__printed(), "\n"):find("Couldn't find that pet", 1, true) ~= nil)

    M.__resetPrinted()
    ctx = ctxFor(ns, "COMPANION")
    assertEqual(ctx.params.pet, "", "no pet chosen")
    ctx.desc.onWorn(ctx)
    assertEqual(companion.__count("SummonByGUID"), 1, "no pet: no summon")
    assertTrue(table.concat(M.__printed(), "\n"):find("Couldn't find that pet", 1, true) ~= nil)
end)

test("quest: COMPANION says it couldn't find the pet when the summon is refused", function()
    local ns, M = fresh()
    T.fake(ns, "Companion", { SummonByGUID = function() return false end })
    local ctx = ctxFor(ns, "COMPANION", { params = { pet = M.__world.pets[1].guid } })
    M.__resetPrinted()
    ctx.desc.onWorn(ctx)
    assertTrue(table.concat(M.__printed(), "\n"):find("Couldn't find that pet", 1, true) ~= nil)
end)

-- ── through the binder ────────────────────────────────────────────────────────────────────────

-- The recorded Stack (as tests/test_trigger_binder.lua's): the worn set, the trigger-wear marks, and
-- the OUTFIT_WORN/REMOVED sends the real one makes.
local function fakeStack(NS)
    local st = { worn = {}, did = {}, didUn = {}, log = {} }
    T.fake(NS, "Stack", {
        Top = true,   -- the Outfits broker redraws at stand-up (modules/Broker.lua)
        IsWorn = function(id) return st.worn[id] == true end,
        DidEquip = function(id) return st.did[id] == true end,
        DidUnequip = function(id) return st.didUn[id] == true end,
        IsComplete = function() return false end,
        Wear = function(id, opts)
            st.log[#st.log + 1] = "wear " .. id
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
    })
    T.fake(NS, "Equip", { Batch = function(fn, ...) return true, fn(...) end, SetUpdateDelay = true })
    return st
end

test("quest: bound, the shipped conditions answer the binder's events", function()
    local ns, M = fresh()
    local emotes = {}
    M.DoEmote = function(token) emotes[#emotes + 1] = token end
    -- On WoW Forever the joust and pet-battle outfits name absent triggers: they bind nothing.
    local argent = ns.Outfits.Create("Joust", {}, { trigger = "QUEST_ARGENT_TOURNAMENT" })
    local turnin = ns.Outfits.Create("XP", {}, { trigger = "QUEST_TURNIN" })
    local battle = ns.Outfits.Create("Pets", {}, { trigger = "PET_BATTLE" })
    local dance = ns.Outfits.Create("Dance", {}, { trigger = "DANCE" })
    local st = fakeStack(ns)
    assertEqual(ns.TriggerBinder.BindAll(), FOREVER and 2 or 4, "every one this client has binds")
    M.__units.player.faction = "Alliance"
    M.__units.mouseover = { guid = guid("Vehicle", 33800) }
    M.__fire("UPDATE_MOUSEOVER_UNIT")
    assertEqual(st.worn[argent] == true, not FOREVER, "the mount under the cursor, on Retail only")
    M.__fire("QUEST_PROGRESS")
    assertTrue(st.worn[turnin])
    M.__fire("QUEST_FINISHED")
    assertNil(st.worn[turnin])
    M.__fire("PET_BATTLE_OPENING_DONE")
    assertEqual(st.worn[battle] == true, not FOREVER, "a pet battle, on Retail only")
    M.__fire("PET_BATTLE_CLOSE")
    assertNil(st.worn[battle])
    ns.Stack.Wear(dance, { byTrigger = false })
    assertEqual(table.concat(emotes, ","), "DANCE", "its own wear dances")
    ns.SendBus(ns.MSG.OUTFIT_WORN, argent, nil, true)
    assertEqual(#emotes, 1, "another outfit's wear does not")
end)

test("quest: the four content quests and Pet Battle exist on Retail only; Quest Turn-in on both", function()
    local ns = fresh()
    local quest = {}
    for _, d in ipairs(ns.Triggers.List("QUEST")) do quest[#quest + 1] = d.id end
    for _, id in ipairs(RETAIL_ONLY) do
        -- red under: Finalize building a `clients = { "retail" }` row on Forever (rulings D5, D6).
        assertEqual(ns.Triggers.Get(id) ~= nil, not FOREVER, id .. " is Retail's alone")
    end
    assertTrue(ns.Triggers.Get("QUEST_TURNIN") ~= nil, "Quest Turn-in stays on both clients")
    assertEqual(table.concat(quest, ","), FOREVER and "QUEST_TURNIN"
        or "QUEST_ARGENT_TOURNAMENT,QUEST_FLAME_LEVIATHAN,PET_BATTLE,QUEST_TURNIN,QUEST_MULTIPHASE_SURVEY,"
        .. "QUEST_VIGILANCE_ON_WINGS", "the QUEST picker")
end)
