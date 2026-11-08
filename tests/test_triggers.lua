-- tests/test_triggers.lua — P4.15 (design §6.1-§6.7, H1, H13, H14): the trigger catalog
-- (defaults/Triggers.lua), the registry and its Finalize (modules/Triggers.lua), the typed params
-- (modules/Triggers_Params.lua), the families, guards and TooltipHasLine (modules/Triggers_Families.lua)
-- and the save-and-restore effects (modules/Triggers_Effects.lua).
--
-- The binder is tests/test_trigger_binder.lua. The bespoke conditions (P4.16a-c) have their own
-- suites; a case here that needs every descriptor bound gives each bespoke id a stand-in condition
-- through NS.TriggerConditions before re-running Finalize.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local NS = T.NS

-- The bespoke ids (no family), whose conditions P4.16a, P4.16b and P4.16c wrote. This suite answers
-- them with stand-ins; the real conditions are covered by the test_triggers_* suites.
local BESPOKE = {
    IN_DUNGEON = true, INSTANCE_DIFFICULTY = true, HAS_BUFF = true, TARGET = true, TRINKET_QUEUE = true,
    FEET_QUEUE = true, IN_ZONES = true, TALENT_TREE = true, PVP_FLAGGED = true,
    LOCKPICKING = true, RIDING = true, FALLING = true, RESTING = true, SPELLCAST = true, COOKING = true,
    QUEST_MULTIPHASE_SURVEY = true, QUEST_TURNIN = true, PET_BATTLE = true, DANCE = true, COMPANION = true,
}
local CLASS_FILES = {}
for token in pairs(T.world.CLASSES) do CLASS_FILES[token] = true end
local TYPE_NAMES = { "bool", "number", "string", "spelllist", "itemlist", "maplist", "subzonelist", "unitlist", "pet" }

local function allBespoke(fn)
    local out = {}
    for id in pairs(BESPOKE) do out[id] = fn end
    return out
end

-- A fresh instance with every bespoke id answered by `fn` (stand-ins for the real P4.16 conditions).
local function finalized(fn, mutate)
    local inst = T.load({ mutate = mutate })
    inst.NS.TriggerConditions = allBespoke(fn or function() return nil end)
    inst.NS.Triggers.Finalize()
    return inst.NS, inst.mocks
end

-- A hand-made context for calling a condition directly.
local function ctxFor(ns, id, over)
    over = over or {}
    local desc = ns.Triggers.Get(id)
    local ctx = { desc = desc, outfitId = "o1", state = {}, now = over.now or 100, persist = over.persist,
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

-- ── the catalog and the descriptors ───────────────────────────────────────────────────────────

-- The zone rows are per client (defaults/Zones.lua, ruling D3): WoW Forever keeps four of the 33.
local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"

test("triggers: CATEGORY_ORDER, ids unique SCREAMING_SNAKE, categories and real classFiles", function()
    local C = NS.TriggerCatalog
    assertEqual(table.concat(C.CATEGORY_ORDER, ","), "GENERAL,TRADE,PVP,QUEST,ENTERTAIN,CLASS")
    local cats, seen = {}, {}
    for _, c in ipairs(C.CATEGORY_ORDER) do cats[c] = true end
    for _, row in ipairs(C.rows) do
        assertTrue(row.id:find("^%u[%u%d_]*$") ~= nil, row.id .. " is not SCREAMING_SNAKE")
        assertNil(seen[row.id], row.id .. " is declared twice")
        seen[row.id] = true
        assertTrue(cats[row.category] == true, row.id .. ": category " .. tostring(row.category))
        assertTrue(row.class == nil or CLASS_FILES[row.class] == true, row.id .. ": class " .. tostring(row.class))
        assertTrue(type(row.name) == "string" and row.name ~= "", row.id .. " has a name")
        assertTrue(type(row.desc) == "string" and row.desc ~= "", row.id .. " has a description")
        assertTrue((row.family ~= nil) ~= (BESPOKE[row.id] == true), row.id .. ": a family XOR a bespoke condition")
    end
    -- 40 static rows + 33 zone rows = the 73 static ports of design §6.8 (Forever: 40 + 4).
    assertEqual(#C.rows, 40)
    for _, z in ipairs(NS.Zones.rows) do assertNil(seen[z.id], z.id .. " is also a catalog row") end
    assertEqual(#NS.Triggers.All(), FOREVER and 44 or 73, "no spec rows without a class (the shared instance)")
end)

test("triggers: every event is a pseudo key or UPPER_SNAKE, and every state one is produced", function()
    local produced = {}
    for _, id in ipairs(NS.States.STATES) do produced[id] = true end
    for _, z in ipairs(NS.Zones.rows) do produced[z.id] = true end
    for _, desc in ipairs(NS.Triggers.All()) do
        assertTrue(#desc.events > 0, desc.id .. " has events")
        for _, e in ipairs(desc.events) do
            assertTrue(NS.Triggers.IsPseudo(e) or e:find("^[%u_]+$") ~= nil, desc.id .. ": event " .. e)
            local sid = e:match("^STATE:(.+)$")
            if sid then assertTrue(produced[sid] == true, desc.id .. ": no producer for " .. e) end
        end
    end
    assertTrue(NS.Triggers.IsPseudo("STATE:SWIMMING") and NS.Triggers.IsPseudo("TOOLTIP_HIDE"))
    assertTrue(NS.Triggers.IsPseudo("BIND") and NS.Triggers.IsPseudo("TIMER"))
    assertFalse(NS.Triggers.IsPseudo("PLAYER_ENTERING_WORLD"))
end)

test("triggers: no pseudo key reaches RegisterEvent when every descriptor is bound (quirk 8)", function()
    -- red under: the binder's game-event arm taking every event that is not STATE:<id> (TIMER, AURAS,
    -- TOOLTIP_* or OUTFIT_* would reach SafeRegisterEvent).
    local ns = finalized(function() return nil end)
    local names, orig = {}, ns.SafeRegisterEvent
    ns.SafeRegisterEvent = function(target, event, ...)
        names[#names + 1] = event
        return orig(target, event, ...)
    end
    local n = 0
    for _, desc in ipairs(ns.Triggers.All()) do
        n = n + 1
        ns.Outfits.Create("Outfit " .. n, {}, { trigger = desc.id })
    end
    assertEqual(ns.TriggerBinder.BindAll(), n, "every descriptor bound")
    assertTrue(#names > 20, "game events were registered")
    for _, e in ipairs(names) do
        assertFalse(ns.Triggers.IsPseudo(e), e .. " reached RegisterEvent")
        assertTrue(e:find(":", 1, true) == nil, e .. " reached RegisterEvent")
    end
end)

test("triggers: params have known types, valid defaults, unique keys and a label", function()
    local P = NS.TriggerParams
    for _, desc in ipairs(NS.Triggers.All()) do
        local keys = {}
        for _, p in ipairs(desc.params) do
            assertTrue(P.TYPES[p.type] ~= nil, desc.id .. "." .. p.key .. ": type " .. tostring(p.type))
            assertTrue(P.Validate(p, p.default) == true, desc.id .. "." .. p.key .. ": its default is not valid")
            assertNil(keys[p.key], desc.id .. "." .. p.key .. " twice")
            keys[p.key] = true
            assertTrue(type(p.label) == "string" and p.label ~= "", desc.id .. "." .. p.key .. " has a label")
        end
    end
    local swim = NS.Triggers.Get("SWIMMING")
    assertEqual(swim.params[4].key, "disableVashjir")
    assertTrue(swim.params[4].default, "Vashj'ir is off by default (design §6.8 row 12)")
end)

test("triggers: the generated schema rows validate, store typed values and refuse bad ones", function()
    local O = NS.OutfitSchema
    assertEqual(NS.ValidateOutfitSchema(), 0)
    local n = 0
    for _, desc in ipairs(NS.Triggers.All()) do n = n + #desc.params end
    assertEqual(#NS.Triggers.SchemaRows(), n)
    local row = O.FindRow("trigger.SWIMMING.disableVashjir")
    assertTrue(row ~= nil and row.page == "outfit" and row.group == "SWIMMING" and row.type == "bool")
    assertTrue(O.FindRow("trigger.BG_AV.spec4") ~= nil, "a zone trigger's spec toggles have rows")
    assertNil(NS.Schema.FindRow("trigger.SWIMMING.disableVashjir"), "never on the settings instance")

    local inst = T.load()
    local ns = inst.NS
    local id = ns.Outfits.Create("Typed", {}, { trigger = "RIDING" })
    assertTrue(ns.SetByPath("trigger.RIDING.unequipDelay", 4.6, id))
    assertEqual(ns.db.char.outfits[id].triggerParams.RIDING.unequipDelay, 5, "rounded to the step")
    -- red under: a schema row with no validate (any value would store).
    assertFalse((ns.SetByPath("trigger.RIDING.unequipDelay", 31, id)), "above max")
    assertFalse((ns.SetByPath("trigger.RIDING.stayWhileFalling", "yes", id)), "a string is no bool")
    assertTrue(ns.SetByPath("trigger.HAS_BUFF.spellIDs", { 2645, 5384, 2645 }, id))
    assertEqual(table.concat(ns.GetSetting("trigger.HAS_BUFF.spellIDs", id), ","), "2645,5384", "deduped, in order")
    assertFalse((ns.SetByPath("trigger.HAS_BUFF.spellIDs", { 1.5 }, id)), "not an integer")
    assertFalse((ns.SetByPath("trigger.SWIMMING.disableBG", true)), "no instance id")
end)

test("triggers: every descriptor declares an icon, the legacy default where there was one", function()
    for _, desc in ipairs(NS.Triggers.All()) do
        local icon = desc.icon
        assertTrue(icon == false or (type(icon) == "number" and icon > 0), desc.id .. ": icon " .. tostring(icon))
    end
    local want = { SWIMMING = 136148, FISHING = 136245, RIDING = 132261, DRUID_BEAR = 132276, DRUID_CASTER = 135157,
                   PVP_BATTLEGROUND = 1376041, BG_AV = 1376041, INSTANCE_DIFFICULTY = 132132, GATHER_MINING = 134708 }
    for id, icon in pairs(want) do assertEqual(NS.Triggers.Get(id).icon, icon, id) end
    -- red under: a zone row taking another row's icon (ZONE_ICONS read for every zone).
    if FOREVER then assertNil(NS.Triggers.Get("BG_DEEPHAUL"), "a Retail-only zone row is absent") return end
    assertEqual(NS.Triggers.Get("BG_DEEPHAUL").icon, false, "no legacy icon: the outfit's own")
end)

test("triggers: no catalog row writes initial; Finalize sets it exactly for BIND rows and strips BIND", function()
    local withBind = {}
    for _, row in ipairs(NS.TriggerCatalog.rows) do
        assertNil(row.initial, row.id .. " writes initial")
        for _, e in ipairs(row.events) do if e == "BIND" then withBind[row.id] = true end end
    end
    assertTrue(withBind.RESTING and withBind.IN_DUNGEON and not withBind.SWIMMING)
    for _, desc in ipairs(NS.Triggers.All()) do
        -- red under: build() keeping BIND in `events`, or setting `initial` on every row.
        assertEqual(desc.initial, withBind[desc.id] == true, desc.id .. ".initial")
        for _, e in ipairs(desc.events) do assertTrue(e ~= "BIND", desc.id .. " kept BIND in its events") end
    end
end)

test("triggers: ForState answers an array, empty rather than nil", function()
    local T2 = NS.Triggers
    assertEqual(table.concat(T2.ForState("SWIMMING"), ","), "SWIMMING")
    local stealth = table.concat(T2.ForState("STEALTH"), ",")
    assertTrue(stealth:find("DRUID_PROWL", 1, true) and stealth:find("ROGUE_STEALTH", 1, true), stealth)
    assertEqual(table.concat(T2.ForState("BG_AV"), ","), "BG_AV")
    -- red under: ForState answering byState[id] alone (nil: NS.States.Set's first sighting would raise).
    assertEqual(type(T2.ForState("NO_SUCH")), "table")
    assertEqual(#T2.ForState("NO_SUCH"), 0)
end)

test("triggers: List and Categories offer class rows to their class only, sorted by name", function()
    local T2 = NS.Triggers
    local function ids(list)
        local out = {}
        for i, d in ipairs(list) do out[i] = d.id end
        return table.concat(out, ",")
    end
    assertEqual(table.concat(T2.Categories("WARRIOR"), ","), "GENERAL,TRADE,PVP,QUEST,ENTERTAIN")
    assertEqual(table.concat(T2.Categories("DRUID"), ","), "GENERAL,TRADE,PVP,QUEST,ENTERTAIN,CLASS")
    -- red under: visible() ignoring `class`.
    assertTrue(not ids(T2.List("TRADE", "WARRIOR")):find("LOCKPICKING"), "a rogue's row for a warrior")
    assertTrue(ids(T2.List("TRADE", "ROGUE")):find("LOCKPICKING") ~= nil)
    local names, prev = T2.List("TRADE", "ROGUE"), ""
    for _, d in ipairs(names) do
        assertTrue(d.name:lower() >= prev, d.name .. " out of order")
        prev = d.name:lower()
    end
    assertEqual(ids(T2.List("CLASS", "SHAMAN")), "SHAMAN_GHOST_WOLF")
end)

test("triggers: one zone trigger per zone row, family zone, spec toggles on, the client's map name", function()
    local ns = finalized(nil, function(M)
        M.GetRealZoneText = function(mapID) if mapID == 30 then return "Alterac Valley" end return nil end
    end)
    for _, z in ipairs(ns.Zones.rows) do
        local d = ns.Triggers.Get(z.id)
        assertEqual(d.category, "PVP", z.id)
        assertEqual(d.family, "zone", z.id)
        assertEqual(table.concat(d.events, ","), "STATE:" .. z.id .. ",ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
        assertEqual(#d.params, 4, z.id .. " carries spec1..spec4")
        for _, p in ipairs(d.params) do assertTrue(p.default, z.id .. "." .. p.key .. " defaults on") end
    end
    assertEqual(ns.Triggers.Get("BG_AV").name, "Battleground: Alterac Valley")
    if FOREVER then
        assertNil(ns.Triggers.Get("ARENA_NAGRAND"), "no arena rows on Forever (ruling D3)")
    else
        assertEqual(ns.Triggers.Get("ARENA_NAGRAND").name, "Arena: ARENA_NAGRAND", "no client name: the id")
    end
    assertEqual(ns.Triggers.Get("PVP_BATTLEGROUND").name, "Battleground")
end)

test("triggers: SPEC_1..N are named '<class>: <spec>', and retried until the spec data is there", function()
    local ns, M = finalized(nil, function(M) M.__world:setClass("DRUID", 2) end)
    local d = ns.Triggers.Get("SPEC_2")
    assertEqual(d.name, "Druid: Feral")
    assertEqual(d.class, "DRUID")
    assertEqual(d.category, "SPEC")
    assertTrue(d.initial, "evaluated at bind")
    assertNil(ns.Triggers.Get("SPEC_5"))
    assertEqual(table.concat(ns.Triggers.Categories("DRUID"), ","), "GENERAL,TRADE,PVP,QUEST,ENTERTAIN,CLASS,SPEC")
    assertTrue(M ~= nil)

    -- red under: building the spec rows once at Finalize only (a login with the data late keeps none).
    local inst = T.load()
    assertNil(inst.NS.Triggers.Get("SPEC_1"), "no class yet, no spec rows")
    inst.mocks.__world:setClass("WARRIOR", 1)
    assertEqual(inst.NS.Triggers.Get("SPEC_3").name, "Warrior: Protection", "built on the next read")
end)

test("triggers: live resolution, a swapped descriptor changes behavior with no migration", function()
    local ns = finalized()
    local id = ns.Outfits.Create("Swim", {}, { trigger = "SWIMMING" })
    local stored = ns.db.char.outfits[id].trigger
    -- smartUnequip: off with no trigger wear is no change.
    assertNil(call(ns, "SWIMMING", {}, "STATE", "SWIMMING", false))
    for i, row in ipairs(ns.TriggerCatalog.rows) do
        if row.id == "SWIMMING" then
            local swapped = {}
            for k, v in pairs(row) do swapped[k] = v end
            swapped.family = "simple"
            ns.TriggerCatalog.rows[i] = swapped
        end
    end
    ns.Triggers.Finalize()
    assertEqual(call(ns, "SWIMMING", {}, "STATE", "SWIMMING", false), "unequip", "the new family answers")
    assertEqual(ns.db.char.outfits[id].trigger, stored, "the record was not touched")
    assertEqual(stored.id, "SWIMMING")
end)

-- ── the types ─────────────────────────────────────────────────────────────────────────────────

test("triggers: the nine types validate and normalize", function()
    local P = NS.TriggerParams
    local present = {}
    for name in pairs(P.TYPES) do present[#present + 1] = name end
    table.sort(present)
    local want = {}
    for i, n in ipairs(TYPE_NAMES) do want[i] = n end
    table.sort(want)
    assertEqual(table.concat(present, ","), table.concat(want, ","))
    local function ok(type_, v, p) p = p or {}; p.type = type_; return P.Validate(p, v) == true end
    local function norm(type_, v, p) p = p or {}; p.type = type_; return P.Normalize(p, v) end
    assertTrue(ok("bool", false)); assertFalse(ok("bool", 1))
    assertTrue(ok("number", 3, { min = 1, max = 6 })); assertFalse(ok("number", 7, { min = 1, max = 6 }))
    assertFalse(ok("number", 0 / 0), "NaN")
    assertEqual(norm("number", 2.4, { min = 1, step = 1 }), 2)
    assertEqual(norm("string", "  x  "), "x")
    assertFalse(ok("string", string.rep("a", 65)))
    local big = {}
    for i = 1, 33 do big[i] = i end
    assertFalse(ok("itemlist", big), "33 entries")
    assertFalse(ok("maplist", { [1] = 1, [3] = 3 }), "a hole")
    assertFalse(ok("spelllist", { x = 1 }), "not a list")
    assertTrue(ok("subzonelist", { "Bank" })); assertFalse(ok("subzonelist", { "" }))
    assertEqual(table.concat(norm("subzonelist", { " Bank ", "Bank", "Inn" }), ","), "Bank,Inn")
    assertTrue(ok("unitlist", { { npcID = 33790 }, { player = "Ann-Realm" } }))
    assertFalse(ok("unitlist", { { npcID = 1, player = "x" } }), "exactly one key")
    assertFalse(ok("unitlist", { { npcID = -1 } }))
    assertEqual(#norm("unitlist", { { npcID = 5 }, { npcID = 5 }, { player = "A" } }), 2)
    assertTrue(ok("pet", "")); assertTrue(ok("pet", "BattlePet-0-000000000001")); assertFalse(ok("pet", "Whiskers"))
end)

test("triggers: the capture helpers answer IDs, plain only", function()
    local inst = T.load()
    local ns, M = inst.NS, inst.mocks
    local P = ns.TriggerParams
    M.__units.target = { guid = "Vehicle-0-3767-571-11063-33790-0000ABCDEF" }
    assertEqual(P.CaptureTarget().npcID, 33790)
    M.__units.target = { guid = "Player-1-0000BEEF", name = "Ann" }
    M.UnitName = function(unit) if unit == "target" then return "Ann", "Realm" end end
    assertEqual(P.CaptureTarget().player, "Ann-Realm")
    M.__units.target = { guid = T.secret("Creature-0-1-2-3-55-6") }
    -- red under: ParseGUID matching the raw argument instead of Secrets.PlainString's answer.
    assertNil(P.CaptureTarget(), "a secret GUID is not captured")
    assertEqual(select(2, P.ParseGUID("Creature-0-1-2-3-39710-00")), 39710)
    M.__world:setMap(107)
    assertEqual(P.CaptureCurrentMap(), 107)
    M.GetMinimapZoneText = function() return " The Bank " end
    assertEqual(P.CaptureCurrentSubzone(), "The Bank")
    M.C_PetJournal.SummonPetByGUID("BattlePet-0-000000000002")
    assertEqual(P.CaptureSummonedPet(), "BattlePet-0-000000000002")
    M.__world:setAuras("player", "HELPFUL", { { spellId = 2645, icon = 1, name = "w" } })
    assertEqual(P.CapturePlayerAura(1), 2645)
    M.__world:setRestricted(true)
    assertNil(P.CapturePlayerAura(1), "nothing while the aura getters raise")
end)

-- ── the tooltip line ──────────────────────────────────────────────────────────────────────────

test("triggers: TooltipHasLine is a plain find, exact, numbered and colored; a secret line is no match", function()
    local inst = T.load()
    local ns, M = inst.NS, inst.mocks
    local F = ns.TriggerFamilies
    local tip = M.GameTooltip
    tip:ClearLines()
    tip:AddLine("Peacebloom", 1, 1, 1)
    tip:AddLine("Herbalism", 1, 0.5, 0)            -- orange: difficult
    tip:AddLine("Requires Skill (Herb-1)", 0.5, 0.5, 0.5)
    local found, hard, exact, line = F.TooltipHasLine("Herbalism")
    assertTrue(found and hard and exact)
    assertEqual(line, 2)
    -- red under: a pattern find (the "(" and "-" are magic there).
    found, hard, exact, line = F.TooltipHasLine("(Herb-1)")
    assertTrue(found and not exact and not hard, "plain, not exact, gray is easy")
    assertEqual(line, 3)
    tip:ClearLines()
    tip:AddLine("Herbalism", 0.25, 0.75, 0.25)      -- green: not difficult
    assertTrue(select(1, F.TooltipHasLine("Herbalism")) and not select(2, F.TooltipHasLine("Herbalism")))
    tip:ClearLines()
    tip:AddLine("Title")
    tip:AddLine(T.secret("Herbalism"), 1, 0, 0)
    -- red under: reading fs:GetText() without Secrets.PlainString.
    assertFalse((F.TooltipHasLine("Herbalism")), "a secret text matched")
    tip:ClearLines()
    for _ = 1, 31 do tip:AddLine("x") end
    tip:AddLine("Herbalism")
    assertFalse((F.TooltipHasLine("Herbalism")), "line 32 is past the bound")
end)

-- ── the families ──────────────────────────────────────────────────────────────────────────────

local function guardsWorld(M, over)
    M.HasFullControl = function() return over.control ~= false end
    M.UnitIsPVP = function() return over.pvp == true end
end

test("triggers: simple and smartUnequip, with the skipAll guards and the spec gate", function()
    local ns, M = finalized()
    guardsWorld(M, {})
    assertEqual(call(ns, "DRUID_PROWL", {}, "STATE", "STEALTH", true), "equip")
    assertEqual(call(ns, "DRUID_PROWL", {}, "STATE", "STEALTH", false), "unequip")
    assertEqual(call(ns, "SWIMMING", {}, "STATE", "SWIMMING", true), "equip")
    -- red under: smartUnequip unequipping without DidEquip (a manual wear taken off).
    assertNil(call(ns, "SWIMMING", { did = false }, "STATE", "SWIMMING", false))
    local action, delay = call(ns, "SWIMMING", { did = true }, "STATE", "SWIMMING", false)
    assertEqual(action, "unequip"); assertEqual(delay, 2.5)
    M.__world:setMap(204)
    assertNil(call(ns, "SWIMMING", {}, "STATE", "SWIMMING", true), "Vashj'ir blocks by default")
    assertEqual(call(ns, "SWIMMING", { params = { disableVashjir = false } }, "STATE", "SWIMMING", true), "equip")
    M.__world:setInstance({ type = "party" })
    assertNil(call(ns, "SWIMMING", { params = { disableVashjir = false, disableInstance = true } }, "STATE", "SWIMMING", true))
    -- The zone family: a disabled spec unequips; a spec change re-reads the state.
    ns.PlayerState.Refresh()
    assertEqual(call(ns, "BG_AV", { params = { spec1 = false } }, "STATE", "BG_AV", true), "unequip")
    assertNil(call(ns, "BG_AV", {}, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"), "not in AV, not worn by it")
end)

test("triggers: the druid forms tag, wear on the shapeshift layer and wait in combat", function()
    local ns, M = finalized(nil, function(M) M.__world:setClass("DRUID", 1) end)
    guardsWorld(M, {})
    ns.PlayerState.Refresh()
    local a, d, layer = call(ns, "DRUID_BEAR", {}, "OUTFIT_WORN", "o1")
    assertEqual(a, "tag"); assertNil(d); assertEqual(layer, "shapeshift")
    a, d, layer = call(ns, "DRUID_BEAR", {}, "STATE", "FORM_BEAR", true)
    assertEqual(a, "equip"); assertNil(d); assertEqual(layer, "shapeshift")
    assertNil(call(ns, "DRUID_BEAR", { worn = true }, "STATE", "FORM_BEAR", true), "already worn")
    assertEqual(call(ns, "DRUID_BEAR", {}, "STATE", "FORM_BEAR", false), "unequip")
    assertNil(call(ns, "DRUID_BEAR", { complete = true }, "STATE", "FORM_BEAR", false), "Complete stays")
    assertEqual(call(ns, "DRUID_BEAR", { complete = true, params = { unequipComplete = true } }, "STATE", "FORM_BEAR", false), "unequip")
    M.__world:setCombat(true)
    ns.PlayerState.Refresh()
    a, d = call(ns, "DRUID_BEAR", {}, "STATE", "FORM_BEAR", false)
    assertEqual(a, "unequip"); assertEqual(d, 2, "two seconds in combat")
    M.__world:setCombat(false)
    ns.PlayerState.Refresh()
    a, d, layer = call(ns, "DRUID_CASTER", {}, "STATE", "FORM_CASTER", true)
    assertEqual(a, "equip"); assertEqual(d, 0.1); assertEqual(layer, "shapeshift")
    assertNil(call(ns, "DRUID_CASTER", { complete = true }, "STATE", "FORM_CASTER", false))
    guardsWorld(M, { control = false })
    assertNil(call(ns, "DRUID_BEAR", {}, "STATE", "FORM_BEAR", true), "stunned: not the player's shift")
    guardsWorld(M, { pvp = true })
    assertNil(call(ns, "DRUID_CAT", { params = { disablePVP = true } }, "STATE", "FORM_CAT", true))
    assertNil(call(ns, "DRUID_CAT", { params = { spec1 = false } }, "STATE", "FORM_CAT", true), "spec off")
end)

test("triggers: gathering, the vehicle quests and the spec rows", function()
    local ns, M = finalized(nil, function(M) M.__world:setClass("DRUID", 1) end)
    M.__world.tradeSkills[182] = "Herbalism"
    local tip = M.GameTooltip
    tip:ClearLines(); tip:AddLine("Peacebloom"); tip:AddLine("Herbalism", 1, 0, 0)
    assertEqual(call(ns, "GATHER_HERBALISM", {}, "TOOLTIP_SHOW"), "equip")
    tip:ClearLines(); tip:AddLine("Herbalism", 1, 0, 0)
    assertNil(call(ns, "GATHER_HERBALISM", {}, "TOOLTIP_SHOW"), "line 1 is the title")
    local a, d = call(ns, "GATHER_HERBALISM", { did = true }, "TOOLTIP_HIDE")
    assertEqual(a, "unequip"); assertEqual(d, 1)
    M.UNIT_SKINNABLE_LEATHER = "Skinnable"
    tip:ClearLines(); tip:AddLine("Wolf"); tip:AddLine("Skinnable", 0.1, 0.9, 0.1)
    assertEqual(call(ns, "GATHER_SKINNING", { params = { ignoreDifficulty = true } }, "TOOLTIP_SHOW"), "equip")

    M.__units.mouseover = { guid = "Vehicle-0-1-2-3-33790-00" }
    assertEqual(call(ns, "QUEST_ARGENT_TOURNAMENT", {}, "UPDATE_MOUSEOVER_UNIT"), "equip", "Alliance mount")
    M.__units.player.faction = "Horde"
    -- red under: npcSet ignoring byFaction (the Alliance mount would match for a Horde player).
    assertNil(call(ns, "QUEST_ARGENT_TOURNAMENT", {}, "TOOLTIP_SHOW"), "not a Horde mount")
    M.__units.mouseover = { guid = T.secret("Vehicle-0-1-2-3-33791-00") }
    assertNil(call(ns, "QUEST_ARGENT_TOURNAMENT", {}, "TOOLTIP_SHOW"), "a secret GUID is no match")
    local ctx = ctxFor(ns, "QUEST_FLAME_LEVIATHAN", { did = true, now = 50 })
    a, d = ctx.desc.condition(ctx, "TOOLTIP_HIDE")
    assertEqual(a, "unequip"); assertEqual(d, 1); assertEqual(ctx.state.unequipAt, 50)
    ctx = ctxFor(ns, "QUEST_FLAME_LEVIATHAN", { didUn = true, now = 52 })
    ctx.state.unequipAt = 50
    assertEqual(ctx.desc.condition(ctx, "UNIT_ENTERED_VEHICLE", "player"), "equip", "boarded within 3 s")
    assertEqual(call(ns, "QUEST_FLAME_LEVIATHAN", { did = true }, "PLAYER_REGEN_ENABLED"), "unequip")
    assertNil(call(ns, "QUEST_VIGILANCE_ON_WINGS", { did = true }, "PLAYER_REGEN_ENABLED"), "Leviathan only")

    ns.PlayerState.Refresh()
    ctx = ctxFor(ns, "SPEC_1")
    a, d = ctx.desc.condition(ctx, "BIND")
    assertEqual(a, "equip"); assertEqual(d, 0.5)
    assertNil(ctx.desc.condition(ctx, "PLAYER_ENTERING_WORLD"), "the spec did not change")
    assertEqual(call(ns, "SPEC_2", {}, "BIND"), "unequip")
end)

test("triggers: a spec change reads the client's spec, not PlayerState's cache of it", function()
    local ns, M = finalized(nil, function(M) M.__world:setClass("WARRIOR", 1) end)
    ns.PlayerState.Refresh()
    local ctx = ctxFor(ns, "SPEC_2")
    assertEqual(ctx.desc.condition(ctx, "BIND"), "unequip")
    -- The binding hears ACTIVE_PLAYER_SPECIALIZATION_CHANGED before PlayerState does (CallbackHandler
    -- walks its targets in next() order): the cache still says spec 1.
    M.__spec = 2
    -- red under: F.spec reading NS.PlayerState.Spec() (the old spec equals prevSpec: no swap).
    local a, d = ctx.desc.condition(ctx, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    assertEqual(a, "equip"); assertEqual(d, 0.5)
    -- red under: G.specOff reading NS.PlayerState.Spec() (the enabled old spec keeps the outfit on).
    assertEqual(call(ns, "BG_AV", { params = { spec2 = false } }, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"), "unequip")
end)

-- ── the effects ───────────────────────────────────────────────────────────────────────────────

test("triggers: the effects record what they changed and restore exactly that", function()
    local inst = T.load()
    local ns, M = inst.NS, inst.mocks
    local E = ns.TriggerEffects
    local tracking = { { name = "Find Fish", texture = 133888, active = false, spellID = 43308 } }
    M.C_Minimap = {
        GetNumTrackingTypes = function() return #tracking end,
        GetTrackingInfo = function(i) return tracking[i] end,
        SetTracking = function(i, on) tracking[i].active = on end,
    }
    local page = 1
    M.GetActionBarPage = function() return page end
    M.ChangeActionBarPage = function(p) page = p end
    M.__cvars.autoLootDefault, M.__cvars.autoInteract = "0", "1"
    local ctx = { persist = {}, params = { autoLoot = true, trackFish = true, disableClickToMove = true,
                                          changeActionBar = true, actionBarPage = 4 } }
    local names = ns.TriggerCatalog.rows[16].effects   -- FISHING's
    assertEqual(ns.TriggerCatalog.rows[16].id, "FISHING")
    assertEqual(E.Apply(ctx, names), 4)
    assertEqual(M.__cvars.autoLootDefault, "1"); assertEqual(M.__cvars.autoInteract, "0")
    assertTrue(tracking[1].active); assertEqual(page, 4)
    -- red under: Apply overwriting an existing record (a second wear would save the changed value).
    assertEqual(E.Apply(ctx, names), 0, "not applied twice")
    ctx.params.autoLoot = false
    assertEqual(E.Restore(ctx, names), 4, "restored from the record, whatever the param says now")
    assertEqual(M.__cvars.autoLootDefault, "0"); assertEqual(M.__cvars.autoInteract, "1")
    assertFalse(tracking[1].active); assertEqual(page, 1)
    assertNil(next(ctx.persist), "the record is gone")
    assertEqual(E.Restore(ctx, names), 0, "nothing to restore twice")
    -- The page waits out combat lockdown (O23).
    ctx.params.autoLoot, ctx.params.trackFish, ctx.params.disableClickToMove = false, false, false
    M.__world:setCombat(true)
    E.Apply(ctx, names)
    -- red under: setPage calling ChangeActionBarPage directly (O23).
    assertEqual(page, 1, "no page change in lockdown")
    M.__world:setCombat(false)
    assertEqual(page, 4, "changed when combat ended")
end)

test("triggers: the action bar page uses C_ActionBar.SetActionBarPage, then the old global, then does nothing and says so", function()
    local inst = T.load()
    local ns, M = inst.NS, inst.mocks
    local E = ns.TriggerEffects
    local ctx = { persist = {}, params = { changeActionBar = true, actionBarPage = 3 } }
    local names = { "ActionBarPage" }
    local page, viaGlobal = 1, 0
    -- the live client: only C_ActionBar exists, with no old getter or setter global
    M.GetActionBarPage, M.ChangeActionBarPage = nil, nil
    M.C_ActionBar = { SetActionBarPage = function(p) page = p end, GetActionBarPage = function() return page end }
    assertEqual(E.Apply(ctx, names), 1)
    assertEqual(page, 3, "the C_ function ran")
    assertEqual(E.Restore(ctx, names), 1)
    assertEqual(page, 1)
    -- an older client: only the globals exist
    M.C_ActionBar = nil
    M.GetActionBarPage = function() return page end
    M.ChangeActionBarPage = function(p) page = p; viaGlobal = viaGlobal + 1 end
    E.Apply(ctx, names)
    assertEqual(page, 3); assertEqual(viaGlobal, 1, "the global ran when there is no C_ function")
    assertEqual(E.Restore(ctx, names), 1)
    assertEqual(page, 1, "Restore returned to the original page via the old global")
    -- neither: the effect does nothing and writes one debug line
    M.ChangeActionBarPage = nil
    local lines = {}
    ns.Debug = function(tag, fmt, ...) lines[#lines + 1] = tag .. ": " .. fmt:format(...) end
    E.Apply(ctx, names)
    assertEqual(page, 1, "no page function, no change")
    assertEqual(#lines, 1, "one debug line")
    assertTrue(lines[1]:find("no action bar page function", 1, true) ~= nil, lines[1])
end)

test("triggers: SavePet and RestorePet put the cook's pet back, or dismiss the one summoned", function()
    local inst = T.load()
    local ns, M = inst.NS, inst.mocks
    local E = ns.TriggerEffects
    local calls = {}
    T.fake(ns, "Companion", {
        SummonByGUID = function(g) calls[#calls + 1] = "summon " .. g; return true end,
        DismissByGUID = function(g) calls[#calls + 1] = "dismiss " .. g; return true end,
    })
    local ctx = { persist = {} }
    M.C_PetJournal.SummonPetByGUID("BattlePet-0-000000000001")
    assertTrue(E.SavePet(ctx)); assertFalse(E.SavePet(ctx), "once per wear")
    M.C_PetJournal.SummonPetByGUID("BattlePet-0-000000000003")
    assertTrue(E.RestorePet(ctx))
    ctx.persist = {}
    M.C_PetJournal.SummonPetByGUID("BattlePet-0-000000000003")   -- toggles off: none summoned
    E.SavePet(ctx)
    M.C_PetJournal.SummonPetByGUID("BattlePet-0-000000000003")
    E.RestorePet(ctx)
    assertEqual(table.concat(calls, ","), "summon BattlePet-0-000000000001,dismiss BattlePet-0-000000000003")
end)
