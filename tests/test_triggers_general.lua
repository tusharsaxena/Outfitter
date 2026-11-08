-- tests/test_triggers_general.lua — P4.16a (design §6.8.1 rows 5-10, 16, 17, 19, 21): the bespoke
-- GENERAL conditions of modules/Triggers_CondGeneral.lua (PVP_FLAGGED, IN_DUNGEON, TRINKET_QUEUE,
-- FEET_QUEUE, IN_ZONES, TALENT_TREE, INSTANCE_DIFFICULTY, HAS_BUFF, TARGET) and the family-only
-- SPIRIT_REGEN row.
--
-- Most cases call a condition directly on a hand-made context and read its verdict. The ones whose
-- point is the wiring (HAS_BUFF at bind and through the real aura scan, PVP_FLAGGED's edge kept in
-- outfit.triggerState, TRINKET_QUEUE refusing an Equipment Manager set) bind through the real
-- binder with a recorded Stack. NS.Inventory is a recorded stand-in for the queues: its cooldown
-- choice is test_inventory's to pin, the queue's own rules are pinned here.

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local IDS = { "PVP_FLAGGED", "IN_DUNGEON", "TRINKET_QUEUE", "FEET_QUEUE", "IN_ZONES", "TALENT_TREE",
              "INSTANCE_DIFFICULTY", "HAS_BUFF", "TARGET" }

-- A hand-made context for calling a condition directly (as tests/test_triggers.lua builds one).
local function ctxFor(ns, id, over)
    over = over or {}
    local desc = ns.Triggers.Get(id)
    local ctx = { desc = desc, outfitId = over.outfitId or "o1", outfit = over.outfit or { items = {} },
                  state = {}, now = 100, persist = over.persist or {},
                  params = ns.TriggerParams.Resolve(desc, over.params) }
    function ctx.IsWorn() return over.worn == true end
    function ctx.DidEquip() return over.did == true end
    function ctx.DidUnequip() return false end
    function ctx.IsComplete() return false end
    return ctx
end

local function call(ns, id, over, event, ...)
    local ctx = ctxFor(ns, id, over)
    return ctx.desc.condition(ctx, event or "BIND", ...)
end

local function fresh(mutate)
    local inst = unitLoad({ mutate = mutate })
    return inst.NS, inst.mocks
end

-- The recorded Stack the binder applies verdicts to (tests/test_trigger_binder.lua's shape).
local function fakeStack(NS)
    local st = { worn = {}, did = {}, log = {} }
    T.fake(NS, "Stack", {
        IsWorn = function(id) return st.worn[id] == true end,
        DidEquip = function(id) return st.did[id] == true end,
        DidUnequip = function() return false end,
        Wear = function(id, opts)
            st.log[#st.log + 1] = "wear " .. id
            st.worn[id], st.did[id] = true, opts.byTrigger == true
            return true
        end,
        Remove = function(id)
            st.log[#st.log + 1] = "remove " .. id
            st.worn[id], st.did[id] = nil, false
            return true
        end,
    })
    T.fake(NS, "Equip", {
        Batch = function(fn, ...) return true, fn(...) end,
        SuspendedForLoad = function() return false end,
        SetUpdateDelay = true, Request = true, DelayUntil = true,
    })
    return st
end

local function log(st) return table.concat(st.log, ",") end

-- ── the wiring ────────────────────────────────────────────────────────────────────────────────

test("general: each bespoke id resolves to this file's condition; SPIRIT_REGEN stays a family row", function()
    local NS = fresh()
    for _, id in ipairs(IDS) do
        local fn = NS.TriggerConditions[id]
        assertEqual(type(fn), "function", id .. " has a condition")
        -- red under: a Cond entry Finalize does not pick up (the descriptor keeps no condition).
        assertTrue(NS.Triggers.Get(id).condition == fn, id .. " is resolved from NS.TriggerConditions")
    end
    assertNil(NS.TriggerConditions.SPIRIT_REGEN, "SPIRIT_REGEN has no bespoke condition")
    assertEqual(NS.Triggers.Get("SPIRIT_REGEN").family, "smartUnequip")
end)

test("general: SPIRIT_REGEN equips on its state and unequips half a second later, only its own", function()
    local NS = fresh()
    assertEqual(call(NS, "SPIRIT_REGEN", {}, "STATE", "SPIRIT_REGEN", true), "equip")
    local action, delay = call(NS, "SPIRIT_REGEN", { did = true }, "STATE", "SPIRIT_REGEN", false)
    assertEqual(action, "unequip")
    -- red under: SPIRIT_REGEN's familyArgs losing unequipDelay = 0.5.
    assertEqual(delay, 0.5)
    assertNil(call(NS, "SPIRIT_REGEN", { did = false }, "STATE", "SPIRIT_REGEN", false), "smart: not its own")
end)

-- ── IN_DUNGEON ────────────────────────────────────────────────────────────────────────────────

test("general: IN_DUNGEON equips by instance type, and arena reads enableArena", function()
    local NS, M = fresh()
    local W = M.__world
    W:setInstance({ type = "party", difficultyID = 1 })
    assertEqual(call(NS, "IN_DUNGEON"), "equip", "5-man on by default")
    W:setInstance({ type = "raid", difficultyID = 14 })
    assertEqual(call(NS, "IN_DUNGEON"), "unequip", "raid off by default")
    assertEqual(call(NS, "IN_DUNGEON", { params = { enableRaid = true } }), "equip")
    W:setInstance({ type = "pvp" })
    assertEqual(call(NS, "IN_DUNGEON", { params = { enableBG = true } }), "equip")
    W:setInstance({ type = "arena" })
    -- red under: the legacy arena arm reading enableBG (OutfitterScripting.lua:565).
    assertEqual(call(NS, "IN_DUNGEON", { params = { enableBG = true } }), "unequip", "BG does not enable arenas")
    assertEqual(call(NS, "IN_DUNGEON", { params = { enableArena = true } }), "equip")
    W:setInstance({ type = "scenario" })
    assertEqual(call(NS, "IN_DUNGEON", { params = { enable5Man = true, enableRaid = true } }), "unequip")
    W:setInstance(nil)
    assertEqual(call(NS, "IN_DUNGEON"), "unequip", "the open world")
end)

-- ── INSTANCE_DIFFICULTY ───────────────────────────────────────────────────────────────────────

test("general: INSTANCE_DIFFICULTY equips in every id of an enabled group, and only there", function()
    local NS, M = fresh()
    local W, groups = M.__world, NS.TriggerData.DIFFICULTY_GROUPS
    local n = 0
    for param, ids in pairs(groups) do
        for _, id in ipairs(ids) do
            n = n + 1
            W:setInstance(id == 0 and nil or { type = "party", difficultyID = id })
            assertEqual(call(NS, "INSTANCE_DIFFICULTY", { params = { [param] = true } }), "equip",
                param .. " at difficulty " .. id)
            -- red under: an enabled group matching any difficulty (the group's ids not consulted).
            local other = param == "delve" and "openWorld" or "delve"
            assertNil(call(NS, "INSTANCE_DIFFICULTY", { params = { [other] = true } }), other .. " at " .. id)
            assertEqual(call(NS, "INSTANCE_DIFFICULTY", { params = { [other] = true }, did = true }), "unequip",
                "smart: its own outfit comes off")
        end
    end
    -- WoW Forever's four groups hold one id each (ruling D7: 0, 1, 148, 9).
    local forever = dofile("tests/_kit/mock_client.lua").current() == "forever"
    assertEqual(n, forever and 4 or 16, "every id design §6.8.1 row 17 lists")
end)

test("general: INSTANCE_DIFFICULTY matches the open world (0) and leaves an unreadable id alone", function()
    local NS, M = fresh()
    local W = M.__world
    W:setInstance(nil)
    -- red under: the legacy SOLO, which never matched outside an instance (O24).
    assertEqual(call(NS, "INSTANCE_DIFFICULTY", { params = { openWorld = true } }), "equip")
    W:setInstance({ type = "party", difficultyID = 24 })        -- Timewalking: no group lists it
    assertEqual(call(NS, "INSTANCE_DIFFICULTY", { params = { dungeonNormal = true }, did = true }), "unequip")
    W:setInstance({ type = "party", difficultyID = T.secret(1) })
    -- red under: comparing the raw difficulty (a secret never equals 1, so the arm would unequip).
    assertNil(call(NS, "INSTANCE_DIFFICULTY", { params = { dungeonNormal = true }, did = true }),
        "a secret difficulty changes nothing")
end)

-- ── HAS_BUFF ──────────────────────────────────────────────────────────────────────────────────

test("general: HAS_BUFF matches any listed spellID; a guard blocks; no match unequips its own", function()
    local NS, M = fresh()
    local have = { [5384] = true }
    T.fake(NS, "States", { PlayerHasSpell = function(id) return have[id] == true end,
                           InPvPInstance = function() return false end })
    local list = { spellIDs = { 2645, 5384 } }
    assertEqual(call(NS, "HAS_BUFF", { params = list }), "equip", "the second id")
    have = {}
    assertNil(call(NS, "HAS_BUFF", { params = list }), "no match, not its own")
    assertEqual(call(NS, "HAS_BUFF", { params = list, did = true }), "unequip")
    have = { [2645] = true }
    M.__units.player.pvp = true
    local blocked = { spellIDs = { 2645 }, disablePVP = true }
    -- red under: a blocking guard answering UNEQUIP (or EQUIP) instead of no change.
    assertNil(call(NS, "HAS_BUFF", { params = blocked, did = true }), "PvP-flagged: no change")
    M.__units.player.pvp = false
    assertEqual(call(NS, "HAS_BUFF", { params = blocked }), "equip", "not flagged: the guard is quiet")
end)

test("general: HAS_BUFF evaluates at bind, follows the aura scan, and reads false while restricted", function()
    local NS, M = fresh()
    local W = M.__world
    W:setAuras("player", "HELPFUL", { { spellId = 2645, icon = 136000, name = "Ghost Wolf" } })
    local st = fakeStack(NS)
    NS.PlayerState.Resume()
    NS.States.Resume()
    for _ = 1, 3 do M.__fireTimers() end
    local id = NS.Outfits.Create("Wolf", {}, { trigger = "HAS_BUFF" })
    assertTrue(NS.SetByPath("trigger.HAS_BUFF.spellIDs", { 2645 }, id))
    NS.TriggerBinder.BindAll()
    assertEqual(log(st), "", "nothing before the bind-time evaluation")
    M.__fireTimers()
    -- red under: HAS_BUFF without BIND (the legacy ignored PEW; INV §19).
    assertEqual(log(st), "wear " .. id, "worn at bind")
    W:setRestricted(true)
    M.__fire("UNIT_AURA", "player")
    for _ = 1, 3 do M.__fireTimers() end
    assertEqual(log(st), "wear " .. id .. ",remove " .. id, "restricted: every buff reads false (O28)")
    W:setRestricted(false)
    M.__fire("UNIT_AURA", "player")
    for _ = 1, 3 do M.__fireTimers() end
    assertEqual(log(st), "wear " .. id .. ",remove " .. id .. ",wear " .. id, "back with the next scan")
end)

-- ── TARGET ────────────────────────────────────────────────────────────────────────────────────

test("general: TARGET matches NPCs by creatureID and players by full name", function()
    local NS, M = fresh()
    local npcs = { targets = { { npcID = 39710 }, { player = "Ann-Realm" }, { player = "Bob" } } }
    M.__units.target = { guid = "Creature-0-3767-571-11063-39710-0000ABCDEF" }
    assertEqual(call(NS, "TARGET", { params = npcs }), "equip", "by creatureID")
    M.__units.target = { guid = "Creature-0-3767-571-11063-39711-0000ABCDEF" }
    M.UnitName = function() return "Bob", "Realm" end
    -- red under: a name match for creatures (the NPC answers to a listed player's name).
    assertNil(call(NS, "TARGET", { params = npcs }), "another creature, whatever its name")
    M.__units.target = { guid = "Player-1-0000BEEF" }
    M.UnitName = function() return "Ann", "Realm" end
    assertEqual(call(NS, "TARGET", { params = npcs }), "equip", "Ann-Realm")
    M.UnitName = function() return "Ann", "Elsewhere" end
    assertNil(call(NS, "TARGET", { params = npcs }), "another realm's Ann")
    M.UnitName = function() return "Bob", "Anywhere" end
    assertEqual(call(NS, "TARGET", { params = npcs }), "equip", "an entry without a realm")
end)

test("general: TARGET is nil-safe and secret-guarded, and unequips on a change when asked", function()
    local NS, M = fresh()
    local list = { targets = { { npcID = 39710 } } }
    M.__units.target = nil
    assertNil(call(NS, "TARGET", { params = list }), "no target (the legacy raised on it), not its own")
    -- red under: no unequipOnChange arm (the legacy never unequipped; INV §19).
    assertEqual(call(NS, "TARGET", { params = list, did = true }), "unequip", "the legacy never unequipped")
    list.unequipOnChange = false
    assertNil(call(NS, "TARGET", { params = list, did = true }), "unequipOnChange off")
    list.unequipOnChange = true
    M.__units.target = { guid = T.secret("Creature-0-3767-571-11063-39710-0000ABCDEF") }
    assertEqual(call(NS, "TARGET", { params = list, did = true }), "unequip", "a secret GUID is no match")
    M.__units.target = { guid = "Player-1-0000BEEF" }
    M.UnitName = function() return T.secret("Ann"), "Realm" end
    assertNil(call(NS, "TARGET", { params = { targets = { { player = "Ann-Realm" } } } }), "a secret name")
end)

-- ── TRINKET_QUEUE and FEET_QUEUE ──────────────────────────────────────────────────────────────

-- A recorded Inventory: NextCooldownItem answers the first listed id as an info, `same` and `active`
-- name what Cache:Same and SlotItemActive say.
local function fakeQueue(NS, opts)
    opts = opts or {}
    local calls = {}
    T.fake(NS, "Inventory", {
        NextCooldownItem = function(ids, ignore)
            calls[#calls + 1] = table.concat(ids, "/") .. ":" .. tostring(ignore)
            return { id = ids[1], link = "item:" .. ids[1], loc = { bag = 0, slot = 1 } }
        end,
        SlotItemActive = function(slot) return (opts.active or {})[slot] == true end,
        Cache = function()
            return { Same = function(_, a, b) return b ~= nil and (opts.same or {})[a.id] == true end }
        end,
    })
    local eq = T.fake(NS, "Equip", { Batch = function(fn, ...) return true, fn(...) end, Request = true })
    return calls, eq
end

test("general: TRINKET_QUEUE fills each slot from its own list, in one Batch, only while worn", function()
    local NS = fresh()
    local calls, eq = fakeQueue(NS)
    local id = NS.Outfits.Create("Trinkets", {})
    local rec = NS.Outfits.Get(id)
    local params = { trinkets = { 111, 222 }, trinkets2 = { 333 } }
    assertNil(call(NS, "TRINKET_QUEUE", { outfitId = id, outfit = rec, params = params, worn = false }, "TIMER"))
    -- red under: no IsWorn gate (the queue would rewrite an outfit nobody wears).
    assertEqual(#calls, 0, "not worn: nothing read")
    assertNil(call(NS, "TRINKET_QUEUE", { outfitId = id, outfit = rec, params = params, worn = true }, "TIMER"),
        "no verdict: the outfit's items change, the stack does not")
    -- red under: the lower list feeding the upper slot, or the swap cooldown counted.
    assertEqual(table.concat(calls, ","), "111/222:true,333:true", "the lists in priority order, upper first")
    assertEqual(rec.items.Trinket0Slot.id, 111)
    assertEqual(rec.items.Trinket1Slot.id, 333)
    assertNil(rec.items.Trinket0Slot.loc, "stored as an ItemRecord snapshot")
    assertEqual(eq.__count("Batch"), 1)
    assertEqual(eq.__count("Request"), 1)
end)

test("general: TRINKET_QUEUE skips the outfit's own item and an active trinket; an empty list reads nothing", function()
    local NS = fresh()
    local calls, eq = fakeQueue(NS, { same = { [111] = true }, active = { Trinket1Slot = true } })
    local id = NS.Outfits.Create("Trinkets", {})
    local rec = NS.Outfits.Get(id)
    rec.items.Trinket0Slot = { id = 111 }
    call(NS, "TRINKET_QUEUE", { outfitId = id, outfit = rec, worn = true,
                                params = { trinkets = { 111 }, trinkets2 = { 333 } } }, "TIMER")
    assertEqual(rec.items.Trinket0Slot.id, 111, "already the outfit's")
    -- red under: no SlotItemActive skip (a trinket mid-effect would be swapped out).
    assertNil(rec.items.Trinket1Slot, "the worn lower trinket is mid-effect")
    assertEqual(eq.__count("Batch"), 0, "nothing changed: no update asked for")
    for i = #calls, 1, -1 do calls[i] = nil end
    call(NS, "TRINKET_QUEUE", { outfitId = id, outfit = rec, worn = true, params = { trinkets2 = { 333 } } }, "TIMER")
    -- red under: reading an empty list (NextCooldownItem would be asked about nothing).
    assertEqual(table.concat(calls, ","), "333:true", "the empty upper list is not read; the active lower one is")
    assertNil(rec.items.Trinket1Slot)
end)

test("general: TRINKET_QUEUE refuses an Equipment Manager set at bind", function()
    local NS = fresh()
    fakeStack(NS)
    local em = NS.Outfits.Create("EM trinkets", {}, { trigger = "TRINKET_QUEUE" })
    NS.db.char.outfits[em].kind = "em"
    local own = NS.Outfits.Create("Own trinkets", {}, { trigger = "TRINKET_QUEUE" })
    NS.TriggerBinder.BindAll()
    assertTrue(NS.Triggers.Get("TRINKET_QUEUE").refuseEM)
    assertFalse(NS.TriggerBinder.IsBound(em), "refused (OutfitterScripting.lua:590-594)")
    assertTrue(NS.TriggerBinder.IsBound(own), "a native outfit binds")
    assertTrue(NS.TriggerBinder.Context(own).ticker ~= nil, "on its 0.5 s ticker")
end)

test("general: FEET_QUEUE puts the soonest boots in FeetSlot, the swap cooldown counted", function()
    local NS = fresh()
    local calls, eq = fakeQueue(NS)
    local id = NS.Outfits.Create("Boots", {})
    local rec = NS.Outfits.Get(id)
    assertNil(call(NS, "FEET_QUEUE", { outfitId = id, outfit = rec, worn = true, params = { boots = { 444, 555 } } },
        "TIMER"))
    assertEqual(table.concat(calls, ","), "444/555:false")
    assertEqual(rec.items.FeetSlot.id, 444)
    assertNil(rec.items.Trinket0Slot, "no other slot")
    assertEqual(eq.__count("Request"), 1)
end)

test("general: FEET_QUEUE refuses an Equipment Manager set at bind, as TRINKET_QUEUE does", function()
    local NS = fresh()
    fakeStack(NS)
    local em = NS.Outfits.Create("EM boots", {}, { trigger = "FEET_QUEUE" })
    NS.db.char.outfits[em].kind = "em"
    local own = NS.Outfits.Create("Own boots", {}, { trigger = "FEET_QUEUE" })
    NS.TriggerBinder.BindAll()
    -- red under: FEET_QUEUE's descriptor without refuseEM (design §6.8.1 row 8 is "as #7"): EM.SetItem
    -- re-saves the set from what is worn, so the pick never lands and every 0.5 s tick saves it again.
    assertTrue(NS.Triggers.Get("FEET_QUEUE").refuseEM)
    assertFalse(NS.TriggerBinder.IsBound(em), "an Equipment Manager set is refused")
    assertTrue(NS.TriggerBinder.IsBound(own), "a native outfit binds")
    assertTrue(NS.TriggerBinder.Context(own).ticker ~= nil, "on its 0.5 s ticker")
end)

-- ── IN_ZONES ──────────────────────────────────────────────────────────────────────────────────

test("general: IN_ZONES matches the best map or an ancestor, at most eight up", function()
    local NS, M = fresh()
    local W = M.__world
    -- A chain 1001 -> 1002 -> ... -> 1011, each the parent of the one before.
    for i = 1001, 1011 do W.maps[i] = { mapID = i, parentMapID = i < 1011 and i + 1 or 0 } end
    W:setMap(1001)
    assertEqual(call(NS, "IN_ZONES", { params = { maps = { 1001 } } }), "equip", "the best map")
    -- red under: matching the best map only (no parentMapID walk).
    assertEqual(call(NS, "IN_ZONES", { params = { maps = { 1003 } } }), "equip", "an ancestor")
    assertEqual(call(NS, "IN_ZONES", { params = { maps = { 1009 } } }), "equip", "the eighth ancestor")
    -- red under: an unbounded walk.
    assertNil(call(NS, "IN_ZONES", { params = { maps = { 1010 } } }), "the ninth is past the bound")
    W.maps[1001].parentMapID = 1001                            -- a cycle ends at the bound too
    assertNil(call(NS, "IN_ZONES", { params = { maps = { 4 } } }))
end)

test("general: IN_ZONES matches a captured sub-zone; no match unequips its own; secret text is no match", function()
    local NS, M = fresh()
    M.__world:setMap(84)
    M.GetMinimapZoneText = function() return " Trade District " end
    local p = { maps = { 1 }, subzones = { "Trade District" } }
    assertEqual(call(NS, "IN_ZONES", { params = p }), "equip", "the trimmed minimap text")
    M.GetMinimapZoneText = function() return "Old Town" end
    assertNil(call(NS, "IN_ZONES", { params = p }), "not its own")
    assertEqual(call(NS, "IN_ZONES", { params = p, did = true }), "unequip", "smart unequip")
    M.GetMinimapZoneText = function() return T.secret("Trade District") end
    assertEqual(call(NS, "IN_ZONES", { params = p, did = true }), "unequip", "a secret sub-zone")
    M.__world:setMap(T.secret(1))
    assertNil(call(NS, "IN_ZONES", { params = p }), "a secret map id")
end)

-- ── TALENT_TREE ───────────────────────────────────────────────────────────────────────────────

test("general: TALENT_TREE equips for an enabled spec and unequips for another, half a second late", function()
    local NS = fresh(function(M) M.__world:setClass("DRUID", 2) end)
    local action, delay = call(NS, "TALENT_TREE", { params = { spec2 = true } }, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    assertEqual(action, "equip")
    -- red under: TALENT_TREE dropping the legacy 0.5 s delay.
    assertEqual(delay, 0.5)
    assertNil(call(NS, "TALENT_TREE", { params = { spec2 = true }, worn = true }), "already worn")
    action, delay = call(NS, "TALENT_TREE", { params = { spec1 = true } }, "PLAYER_TALENT_UPDATE")
    assertEqual(action, "unequip")
    assertEqual(delay, 0.5)
    assertEqual(call(NS, "TALENT_TREE"), "unequip", "every toggle off by default")
end)

-- ── PVP_FLAGGED ───────────────────────────────────────────────────────────────────────────────

test("general: PVP_FLAGGED is edge-triggered through outfit.triggerState, the player's flag only", function()
    local NS, M = fresh()
    local st = fakeStack(NS)
    local id = NS.Outfits.Create("Flagged", {}, { trigger = "PVP_FLAGGED" })
    NS.TriggerBinder.BindAll()
    M.__fireTimers()
    local persist = NS.db.char.outfits[id].triggerState.PVP_FLAGGED
    assertEqual(persist.wasPvP, false, "the bind-time reading is remembered")
    M.__units.player.pvp = true
    M.__fire("PLAYER_FLAGS_CHANGED", "target")
    -- red under: no unit filter on PLAYER_FLAGS_CHANGED (another unit's flags would be read).
    assertEqual(log(st), "", "another unit's flags")
    M.__fire("PLAYER_FLAGS_CHANGED", "player")
    assertEqual(log(st), "wear " .. id)
    assertTrue(persist.wasPvP)
    st.worn[id] = nil                                        -- the player takes it off by hand
    M.__fire("PLAYER_FLAGS_CHANGED", "player")
    M.__fire("PLAYER_ENTERING_WORLD", false, false)
    -- red under: no wasPvP early-out (every flags event would re-wear a removed outfit).
    assertEqual(log(st), "wear " .. id, "no edge, no verdict")
    st.worn[id] = true
    M.__units.player.pvp = T.secret(false)
    M.__fire("PLAYER_FLAGS_CHANGED", "player")
    assertTrue(persist.wasPvP, "a secret flag is no reading")
    M.__units.player.pvp = false
    M.__fire("PLAYER_FLAGS_CHANGED", "player")
    assertEqual(log(st), "wear " .. id .. ",remove " .. id)
end)
