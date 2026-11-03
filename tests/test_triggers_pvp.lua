-- tests/test_triggers_pvp.lua — P4.16d (design §6.8.2 rows 37-69): the PvP zone triggers, enumerated
-- from defaults/Zones.lua so a row added there is covered here with no edit. Every NS.Zones row has a
-- PVP trigger of family `zone` firing on STATE:<id> and the spec change, with spec1..4 on by default;
-- entering a row's map through the real zone producer (modules/States_Zone.lua) wears its outfit and
-- the generics' in wear order, leaving takes off only what the trigger wore (smart unequip), and a
-- disabled spec takes it off on the spec change.
--
-- NS.Stack and NS.Equip are recorded stand-ins (as in tests/test_trigger_binder.lua); the producer,
-- the binder and the family are the real modules. The zone table itself is tests/test_zones.lua.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local KIND_TYPE = { bg = "pvp", arena = "arena" }
local SPEC_EVENT = "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"

-- The recorded Stack: the worn set, the trigger-wear marks and the order of the wears.
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
    return st
end

-- A fresh instance at t = 100 with one outfit per trigger id in `tids` (named after it; nil means
-- every zone row), bound, the producers resumed in the open world and settled.
-- Answers { NS, M, W, st, byTrigger = { [tid] = outfitId }, byOutfit = { [outfitId] = tid } }.
local function scene(tids, opts)
    opts = opts or {}
    local inst = T.load({ mutate = function(M) M.__world:setClass(opts.class or "DRUID", opts.spec or 1) end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    local st = fakeStack(NS)
    T.fake(NS, "Equip", {
        Batch = function(fn, ...) return true, fn(...) end,
        SetUpdateDelay = true, SuspendedForLoad = function() return false end,
        DelayUntil = true, Request = true,
    })
    if not tids then
        tids = {}
        for i, z in ipairs(NS.Zones.rows) do tids[i] = z.id end
    end
    local byTrigger, byOutfit = {}, {}
    for _, tid in ipairs(tids) do
        local id = NS.Outfits.Create(tid, {}, { trigger = tid })
        byTrigger[tid], byOutfit[id] = id, tid
    end
    if opts.params then opts.params(NS, byTrigger) end
    NS.PlayerState.Resume()
    NS.TriggerBinder.BindAll()
    NS.States.Resume()
    for _ = 1, 3 do M.__fireTimers() end
    return { NS = NS, M = M, W = M.__world, st = st, byTrigger = byTrigger, byOutfit = byOutfit }
end

-- Go to `instance` (nil = the open world) and let the zone update's 0.01 s debounce run.
local function go(s, instance)
    s.W:setInstance(instance)
    s.M.__fire("ZONE_CHANGED_NEW_AREA")
    s.M.__fireTimers()
end

-- The trigger ids of the wears (or removals) logged since the last clear, in order.
local function logged(s, verb)
    local out = {}
    for _, line in ipairs(s.st.log) do
        local v, id = line:match("^(%a+) (.+)$")
        if v == verb then out[#out + 1] = s.byOutfit[id] end
    end
    return table.concat(out, ",")
end

local function wornIds(s)
    local out = {}
    for id in pairs(s.st.worn) do out[#out + 1] = s.byOutfit[id] end
    table.sort(out)
    return table.concat(out, ",")
end

local function clear(s) s.st.log = {} end

-- The generic rows an instance type sets, in table (wear) order.
local function generics(NS, itype)
    local out = {}
    for _, z in ipairs(NS.Zones.rows) do
        if z.kind == "generic" and z.instanceTypes[itype] then out[#out + 1] = z.id end
    end
    return out
end

-- ── the descriptors ───────────────────────────────────────────────────────────────────────────

test("pvp: every NS.Zones row has a PVP zone trigger on STATE:<id> and the spec change, spec1..4 on", function()
    local inst = T.load({ mutate = function(M) M.__world:setClass("DRUID", 1) end })
    local NS = inst.NS
    local n = 0
    for _, z in ipairs(NS.Zones.rows) do
        n = n + 1
        local d = NS.Triggers.Get(z.id)
        assertTrue(d ~= nil, z.id .. " has a trigger")
        assertEqual(d.category, "PVP", z.id)
        assertNil(d.class, z.id .. " is for every class")
        assertEqual(d.family, "zone", z.id)
        assertEqual(type(d.condition), "function", z.id .. " has a condition")
        -- red under: zoneRow without ZONE_SPEC_EVENT (a disabled spec would keep the outfit on, O10).
        assertEqual(table.concat(d.events, ","), "STATE:" .. z.id .. "," .. SPEC_EVENT, z.id)
        assertFalse(d.initial, z.id .. " has no BIND evaluation: the producer's first update is its edge")
        local specs = {}
        for _, p in ipairs(d.params) do
            if p.specIndex then specs[#specs + 1] = p.key .. "=" .. tostring(p.default) end
        end
        assertEqual(table.concat(specs, ","), "spec1=true,spec2=true,spec3=true,spec4=true", z.id)
        assertEqual(#d.params, 4, z.id .. ": the spec toggles and nothing else")
        assertEqual(table.concat(NS.Triggers.ForState(z.id), ","), z.id, z.id .. " is the one subscriber")
        assertTrue(NS.OutfitSchema.FindRow("trigger." .. z.id .. ".spec1") ~= nil, z.id .. " schema row")
    end
    -- Design §6.8.2: rows 37-69, the two generics and 31 maps.
    assertEqual(n, 33)
    local pvp = 0
    for _, d in ipairs(NS.Triggers.List("PVP", "WARRIOR")) do
        if d.family == "zone" then pvp = pvp + 1 end
    end
    assertEqual(pvp, n, "every zone trigger is offered under PVP")
end)

test("pvp: a map row is named after the client's map, a generic keeps its own name", function()
    local inst = T.load({ mutate = function(M)
        M.GetRealZoneText = function(mapID) return "Map" .. mapID end
    end })
    local Tr = inst.NS.Triggers
    Tr.Finalize()
    assertEqual(Tr.Get("BG_AV").name, "Battleground: Map30")
    assertEqual(Tr.Get("ARENA_NAGRAND").name, "Arena: Map559")
    assertEqual(Tr.Get("PVP_BATTLEGROUND").name, "Battleground")
    assertEqual(Tr.Get("PVP_ARENA").name, "Arena")
end)

-- ── entering and leaving ──────────────────────────────────────────────────────────────────────

test("pvp: every map of every row wears its outfit over the generics, and the open world takes them off", function()
    local s = scene()
    local covered = 0
    for _, z in ipairs(s.NS.Zones.rows) do
        local itype = KIND_TYPE[z.kind]
        for _, mapID in ipairs(z.mapIDs or {}) do
            covered = covered + 1
            clear(s)
            go(s, { type = itype, instanceID = mapID })
            local want = generics(s.NS, itype)
            want[#want + 1] = z.id
            -- red under: States_Zone's emit walking the rows in another order (a generic over the map's).
            assertEqual(logged(s, "wear"), table.concat(want, ","), z.id .. " map " .. mapID)
            assertEqual(logged(s, "remove"), "", z.id .. ": nothing to take off on the way in")
            clear(s)
            go(s, nil)
            table.sort(want)
            local removed = {}
            for _, line in ipairs(s.st.log) do removed[#removed + 1] = s.byOutfit[line:match("^remove (.+)$")] end
            table.sort(removed)
            assertEqual(table.concat(removed, ","), table.concat(want, ","), z.id .. " left")
            assertEqual(wornIds(s), "", z.id .. ": nothing left on")
        end
    end
    assertEqual(covered, 40, "every map ID of design §6.8.2")
end)

test("pvp: a brawl wears only the generic battleground; an unknown arena still sets both generics", function()
    local s = scene()
    for _, mapID in ipairs(s.NS.Zones.BRAWL_MAP_IDS) do
        clear(s)
        go(s, { type = "pvp", instanceID = mapID })
        assertEqual(logged(s, "wear"), "PVP_BATTLEGROUND", "brawl " .. mapID)
        go(s, nil)
    end
    clear(s)
    go(s, { type = "arena", instanceID = 99999 })
    assertEqual(logged(s, "wear"), "PVP_BATTLEGROUND,PVP_ARENA", "matched by instance type")
end)

test("pvp: leaving takes off only the outfits the trigger wore", function()
    local s = scene({ "PVP_BATTLEGROUND", "BG_WSG" })
    go(s, { type = "pvp", instanceID = 489 })
    local bg = s.byTrigger.PVP_BATTLEGROUND
    s.st.did[bg] = false                                 -- re-worn by hand while inside
    clear(s)
    go(s, nil)
    -- red under: F.smartUnequip unequipping without ctx:DidEquip().
    assertEqual(logged(s, "remove"), "BG_WSG", "the hand-worn generic stays")
    assertTrue(s.st.worn[bg])
    clear(s)
    go(s, { type = "pvp", instanceID = 2106 })            -- the other WSG map, the generic already on
    go(s, { type = "pvp", instanceID = 489 })             -- a move between two maps of one row
    assertEqual(logged(s, "wear"), "BG_WSG", "WSG once; the generic is no edge")
    assertEqual(logged(s, "remove"), "", "no flicker between the row's maps")
end)

-- ── the spec toggles ──────────────────────────────────────────────────────────────────────────

test("pvp: a disabled spec keeps the outfit off, and the spec change puts it on or takes it off", function()
    local s = scene({ "BG_AB", "BG_AV" }, { spec = 2, params = function(NS, by)
        NS.SetByPath("trigger.BG_AB.spec1", false, by.BG_AB)
        NS.SetByPath("trigger.BG_AV.spec2", false, by.BG_AV)
    end })
    go(s, { type = "pvp", instanceID = 30 })
    assertEqual(logged(s, "wear"), "", "spec 2 is off for the AV outfit")
    go(s, { type = "pvp", instanceID = 529 })
    assertEqual(wornIds(s), "BG_AB")
    clear(s)
    s.M.__spec = 1
    s.M.__fire(SPEC_EVENT)
    -- red under: F.zone without `spec = true` (the disabled spec is ignored).
    assertEqual(logged(s, "remove"), "BG_AB", "spec 1 is off for the AB outfit")
    clear(s)
    s.M.__spec = 2
    s.M.__fire(SPEC_EVENT)
    -- red under: stateOn answering only the STATE edge (the spec change cannot re-read the zone).
    assertEqual(logged(s, "wear"), "BG_AB", "back in an enabled spec, still in AB")
    clear(s)
    go(s, nil)
    s.M.__fire(SPEC_EVENT)
    assertEqual(logged(s, "wear"), "", "out of the zone a spec change wears nothing")
end)

test("pvp: every zone trigger honors each of the four spec toggles", function()
    local s = scene()
    for _, z in ipairs(s.NS.Zones.rows) do
        local ctx = s.NS.TriggerBinder.Context(s.byTrigger[z.id])
        for spec = 1, 4 do
            s.M.__spec = spec
            ctx.params["spec" .. spec] = false
            assertEqual(ctx.desc.condition(ctx, "STATE", z.id, true), "unequip", z.id .. " spec" .. spec .. " off")
            ctx.params["spec" .. spec] = true
            assertEqual(ctx.desc.condition(ctx, "STATE", z.id, true), "equip", z.id .. " spec" .. spec .. " on")
        end
    end
end)
