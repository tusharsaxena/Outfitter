-- tests/test_zones.lua — the single zone source (defaults/Zones.lua, design §6.5, INV §8.2) and its
-- regeneration tool (tools/gen-zones.lua), ported from the legacy suite's table-consistency half
-- (7ea3dc3 tests/test_zones.lua:15-80) and pinned against tests/fixtures/legacy/zones.lua.
--
-- This file is the TABLE half (P4.3). The rows are ordered, carry their own map ids and the brawl
-- list beside them; every legacy table that had to move in lockstep is derived from them, and the
-- derivation below is the §6.5 rule written once more so the legacy shapes can be compared. The
-- ENGINE half (the producer in modules/States_Zone.lua: instance type to generics, the three-field
-- early-out, the first-sighting seed, the wear-order emission, never reading a name) joins with
-- P4.14 under the heading at the bottom.

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local assertNil = T.assertNil

local function Z() return T.NS.Zones end
-- The whole table, every client's rows and the brawls (defaults/Zones.lua Z.ALL): what the TABLE half
-- and the regeneration tool pin. Z().rows is the running client's (clients-§5), pinned per client below.
local function All() return { rows = Z().ALL, BRAWL_MAP_IDS = Z().ALL_BRAWL_MAP_IDS } end
local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"

-- The legacy special id of each row, from the design §6.8.2 table (rows 37-69).
local OLD_TO_NEW = {
    Battleground = "PVP_BATTLEGROUND", Arena = "PVP_ARENA",
    AV = "BG_AV", AB = "BG_AB", WSG = "BG_WSG", EotS = "BG_EOTS", SotA = "BG_SOTA", IoC = "BG_IOC",
    TwinPeaks = "BG_TWINPEAKS", Gilneas = "BG_GILNEAS", Wintergrasp = "BG_WINTERGRASP",
    SilvershardMines = "BG_SILVERSHARD", TempleOfKotmogu = "BG_KOTMOGU", DeepwindGorge = "BG_DEEPWIND",
    SeethingShore = "BG_SEETHING", DeephaulRavine = "BG_DEEPHAUL", Ashran = "BG_ASHRAN",
    LordaeronArena = "ARENA_LORDAERON", Sewers = "ARENA_SEWERS", BladesEdgeArena = "ARENA_BLADESEDGE",
    NagrandArena = "ARENA_NAGRAND", TolVironArena = "ARENA_TOLVIRON", TigersPeakArena = "ARENA_TIGERSPEAK",
    BlackRookArena = "ARENA_BLACKROOK", AshamanesFallArena = "ARENA_ASHAMANE",
    HookPointArena = "ARENA_HOOKPOINT", MugambalaArena = "ARENA_MUGAMBALA",
    RobodromeArena = "ARENA_ROBODROME", EmpyreanDomainArena = "ARENA_EMPYREAN",
    MaldraxxusArena = "ARENA_MALDRAXXUS", EnigmaCrucibleArena = "ARENA_ENIGMA",
    NokhudonArena = "ARENA_NOKHUDON", CageOfCarnageArena = "ARENA_CAGEOFCARNAGE",
}

local KINDS = { generic = true, bg = true, arena = true }

-- The §6.5 derivation: map id -> the row ids it sets, generics first. A bg row sets the generic
-- battleground; an arena row sets both generics; a brawl sets the generic battleground only.
local function deriveByMapID(zones)
    local by = {}
    for _, row in ipairs(zones.rows) do
        for _, mapID in ipairs(row.mapIDs or {}) do
            local ids = { "PVP_BATTLEGROUND" }
            if row.kind == "arena" then ids[#ids + 1] = "PVP_ARENA" end
            ids[#ids + 1] = row.id
            by[mapID] = ids
        end
    end
    for _, mapID in ipairs(zones.BRAWL_MAP_IDS) do by[mapID] = { "PVP_BATTLEGROUND" } end
    return by
end

local function rowById(id)
    for _, row in ipairs(Z().ALL) do if row.id == id then return row end end
    return nil
end

local function readFile(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local function genZones() return dofile(T.root .. "/tools/gen-zones.lua") end

-- ── the table ────────────────────────────────────────────────────────────────────────────────

test("zones: NS.Zones is published with its rows and the brawl list", function()
    assertEqual(type(All()), "table", "NS.Zones")
    assertEqual(type(All().rows), "table", "NS.Zones.rows")
    assertEqual(type(All().BRAWL_MAP_IDS), "table", "NS.Zones.BRAWL_MAP_IDS")
    assertEqual(#All().rows, 33, "the 33 zone ids (design §6.10)")
end)

test("zones: every row has a unique SCREAMING_SNAKE id and a known kind", function()
    local seen = {}
    for i, row in ipairs(All().rows) do
        assertTrue(type(row.id) == "string" and row.id:match("^[A-Z][A-Z0-9_]*$") ~= nil, "row " .. i .. " id")
        -- red under: a second row with `id = "BG_AB"` in defaults/Zones.lua.
        assertFalse(seen[row.id] ~= nil, row.id .. " appears twice")
        seen[row.id] = true
        assertTrue(KINDS[row.kind] == true, row.id .. " kind " .. tostring(row.kind))
    end
end)

test("zones: every map id is a positive integer used once, across the rows and the brawls", function()
    local owner, n = {}, 0
    local function claim(mapID, who)
        assertEqual(type(mapID), "number", who .. " map id type")
        assertTrue(mapID > 0 and mapID == math.floor(mapID), who .. " map id " .. tostring(mapID))
        -- red under: list 2107 under BG_WSG as well as BG_AB (the one-use check is what catches it).
        assertFalse(owner[mapID] ~= nil, ("map %s is claimed by %s and %s"):format(mapID, tostring(owner[mapID]), who))
        owner[mapID] = who
        n = n + 1
    end
    for _, row in ipairs(All().rows) do
        for _, mapID in ipairs(row.mapIDs or {}) do claim(mapID, row.id) end
    end
    for _, mapID in ipairs(All().BRAWL_MAP_IDS) do claim(mapID, "a brawl") end
    assertEqual(n, 44, "the full battleground, arena and brawl set")
end)

test("zones: a generic row matches by instance type and lists no map; a specific row the reverse", function()
    for _, row in ipairs(All().rows) do
        if row.kind == "generic" then
            assertEqual(type(row.instanceTypes), "table", row.id .. " instanceTypes")
            assertNil(row.mapIDs, row.id .. " lists maps")
        else
            assertNil(row.instanceTypes, row.id .. " matches by instance type")
            assertTrue(type(row.mapIDs) == "table" and #row.mapIDs >= 1, row.id .. " lists no map")
        end
    end
    -- The point of reading the instance type separately: a map Blizzard ships tomorrow is not in
    -- the table and must still count as a battleground (legacy "an unknown battleground ...").
    local bg, arena = rowById("PVP_BATTLEGROUND"), rowById("PVP_ARENA")
    assertTrue(bg.instanceTypes.pvp and bg.instanceTypes.arena, "an unknown bg or arena sets Battleground")
    assertTrue(arena.instanceTypes.arena, "an unknown arena sets Arena")
    -- red under: `instanceTypes = { pvp = true, arena = true }` on PVP_ARENA (a bg would set Arena).
    assertFalse(arena.instanceTypes.pvp == true, "a battleground never sets Arena")
    -- red under: `instanceTypes = { pvp = true, arena = true, party = true }` on PVP_BATTLEGROUND.
    assertFalse(bg.instanceTypes.party == true or bg.instanceTypes.none == true, "a dungeon is not a battleground")
end)

test("zones: every row has one name source", function()
    for _, row in ipairs(All().rows) do
        if row.kind == "generic" then
            -- The generics have no map to name them; the L key is theirs.
            assertTrue(type(row.name) == "string" and row.name ~= "", row.id .. " name")
        else
            -- Per-map names come from GetRealZoneText(mapIDs[1]) at Finalize, so no row carries one:
            -- red under: a hardcoded `name = "Alterac Valley"` on BG_AV (a name in logic, localization-§4).
            assertNil(row.name, row.id .. " carries a hardcoded name")
        end
    end
end)

test("zones: the rows are the legacy cZoneSpecialIDs, in its wear order", function()
    local want = T.legacy.zones.zoneSpecialIDs
    local rows = All().rows
    assertEqual(#rows, #want, "the zone id count")
    for i, old in ipairs(want) do assertEqual(rows[i].id, OLD_TO_NEW[old], "row " .. i .. " (" .. old .. ")") end
end)

test("zones: wear order puts both generics first, Battleground under Arena", function()
    local rows = All().rows
    assertEqual(rows[1].id, "PVP_BATTLEGROUND", "the first row")
    assertEqual(rows[2].id, "PVP_ARENA", "the second row")
    -- red under: a generic row moved after a specific one (it would then be worn over the
    -- map-specific outfit, Outfitter.lua:1128-1137).
    for i = 3, #rows do assertFalse(rows[i].kind == "generic", rows[i].id .. " is generic at " .. i) end
end)

test("zones: the derived map table equals the legacy cInstanceMapIDZoneIDs", function()
    local got = deriveByMapID(All())
    local want, n = T.legacy.zones.instanceMapIDZoneIDs, 0
    for mapID, oldIds in pairs(want) do
        n = n + 1
        local ids = got[mapID]
        assertTrue(ids ~= nil, "map " .. mapID .. " is gone")
        assertEqual(#ids, #oldIds, "map " .. mapID .. " id count")
        for i, old in ipairs(oldIds) do assertEqual(ids[i], OLD_TO_NEW[old], ("map %d id %d"):format(mapID, i)) end
    end
    local extra = 0
    for mapID in pairs(got) do if not want[mapID] then extra = extra + 1 end end
    assertEqual(extra, 0, "maps the legacy table did not have")
    assertEqual(n, 44, "the legacy map count")
end)

test("zones: every special id a map sets is a row the engine iterates", function()
    local declared = {}
    for _, row in ipairs(All().rows) do declared[row.id] = true end
    for mapID, ids in pairs(deriveByMapID(All())) do
        for _, id in ipairs(ids) do assertTrue(declared[id], id .. " (map " .. mapID .. ") is not a row") end
    end
end)

test("zones: Arathi Basin comes from all four of its map ids", function()
    assertEqual(table.concat(rowById("BG_AB").mapIDs, ","), "529,1681,2107,2177", "BG_AB")
end)

test("zones: the re-issued maps sit beside their originals", function()
    for id, ids in pairs({ BG_WSG = "489,2106", BG_EOTS = "566,968", BG_DEEPWIND = "1105,2245",
                           ARENA_BLADESEDGE = "562,1672", ARENA_NAGRAND = "559,1505", BG_AV = "30,2197" }) do
        assertEqual(table.concat(rowById(id).mapIDs, ","), ids, id)
    end
end)

test("zones: one battleground never sets another's outfit", function()
    local ids = deriveByMapID(All())[30]                         -- Alterac Valley
    assertEqual(table.concat(ids, ","), "PVP_BATTLEGROUND,BG_AV", "Alterac Valley")
end)

test("zones: a brawl map sets the generic battleground and nothing specific", function()
    -- red under: 1691 (Cooking: Impossible) moved out of BRAWL_MAP_IDS into a bg row's mapIDs (it
    -- would then set that row's outfit; listed in both places, the one-use case above fails instead).
    assertEqual(table.concat(All().BRAWL_MAP_IDS, ","), "1170,1280,1691,2799", "the brawls")
    local by = deriveByMapID(All())
    for _, mapID in ipairs(All().BRAWL_MAP_IDS) do
        assertEqual(table.concat(by[mapID], ","), "PVP_BATTLEGROUND", "brawl " .. mapID)
    end
end)

test("zones: an arena map sets both generics and its own row", function()
    for _, row in ipairs(All().rows) do
        if row.kind == "arena" then
            for _, mapID in ipairs(row.mapIDs) do
                assertEqual(table.concat(deriveByMapID(All())[mapID], ","), "PVP_BATTLEGROUND,PVP_ARENA," .. row.id,
                    row.id .. " map " .. mapID)
            end
        end
    end
end)

test("zones: the rows are picked per client: Forever keeps the generic and the three vanilla battlegrounds", function()
    local ids = {}
    for i, row in ipairs(Z().rows) do ids[i] = row.id end
    if FOREVER then
        -- red under: an arena, a later battleground or PVP_ARENA left on Forever (ruling D3).
        assertEqual(table.concat(ids, ","), "PVP_BATTLEGROUND,BG_AV,BG_AB,BG_WSG", "Forever's rows")
        assertEqual(#Z().BRAWL_MAP_IDS, 0, "no brawls on Forever")
    else
        -- red under: a Retail row dropped by a stray `clients` declaration.
        assertEqual(#ids, 33, "Retail keeps every row")
        assertEqual(table.concat(Z().BRAWL_MAP_IDS, ","), "1170,1280,1691,2799", "Retail's brawls")
    end
    for _, row in ipairs(Z().ALL) do
        local kept = false
        for _, id in ipairs(ids) do kept = kept or id == row.id end
        assertEqual(kept, T.NS.Compat.ForClient(row.clients), row.id .. " follows its clients")
    end
end)

test("zones: the regeneration header is in place", function()
    local src = readFile("defaults/Zones.lua")
    assertTrue(src:find("ORDER IS WEAR ORDER", 1, true) ~= nil, "the wear-order note")
    assertTrue(src:find("Map.db2", 1, true) ~= nil, "the Map.db2 source note")
    assertTrue(src:find("tools/gen-zones.lua", 1, true) ~= nil, "the tool named")
    assertTrue(src:find("NEVER from memory", 1, true) ~= nil, "the never-from-memory rule")
end)

test("zones: no legacy lockstep table is kept by hand", function()
    -- The derivation is the only source (design §6.5, C23): neither the five old tables nor their
    -- derived replacements (built in modules/States_Zone.lua) are written in the data file.
    -- red under: a hand-kept `Z.BY_MAP_ID = { [30] = ... }` in defaults/Zones.lua.
    local src = readFile("defaults/Zones.lua")
    for _, name in ipairs({ "cInstanceMapIDZoneIDs", "cZoneSpecialIDs", "cSpecialIDEvents", "BuiltinEvents",
                            "BY_MAP_ID", "ORDER", "PresetScripts" }) do
        assertFalse(src:find("%f[%w_]" .. name .. "%s*=") ~= nil, name .. " is assigned in defaults/Zones.lua")
    end
end)

-- ── tools/gen-zones.lua ──────────────────────────────────────────────────────────────────────

-- A short Map.db2 export: one known battleground, one map nobody has added yet, one arena and one
-- continent. The new map's name carries the comma, the doubled quote and the newline a real export
-- has in its quoted columns (the PvP descriptions hold paragraphs).
local CSV = table.concat({
    "ID,Directory,MapName_lang,MapType,InstanceType,ExpansionID",
    '30,PVPZone01,"Alterac Valley",3,3,0',
    '9001,NewBG,"Gilneas, ""Again""\nfor real",3,3,11',
    '572,PVPLordaeron,"Ruins of Lordaeron",3,4,2',
    '1,Kalimdor,Kalimdor,1,0,0',
}, "\r\n") .. "\r\n"

test("gen-zones: the CSV reader keeps a quoted field's commas, quotes and newlines in one field", function()
    local recs = genZones().parseCSV(CSV)
    -- red under: a line-at-a-time reader (the export's quoted newlines split one row in two, and
    -- 22 known maps then read as removed against the real Map.db2).
    assertEqual(#recs, 4, "record count")
    assertEqual(recs[2].MapName_lang, 'Gilneas, "Again"\nfor real', "a quoted field")
    assertEqual(recs[2].InstanceType, "3", "the field after it")
    assertEqual(recs[4].ID, "1", "the row after it")
end)

test("gen-zones: a clean export diffs clean", function()
    local G = genZones()
    -- Every map the table knows, as an export would list it: rows by kind, brawls as battlegrounds.
    local lines = { "ID,MapName_lang,InstanceType" }
    for _, row in ipairs(All().rows) do
        for _, mapID in ipairs(row.mapIDs or {}) do
            lines[#lines + 1] = ("%d,%s,%d"):format(mapID, row.id, row.kind == "arena" and 4 or 3)
        end
    end
    for _, mapID in ipairs(All().BRAWL_MAP_IDS) do lines[#lines + 1] = mapID .. ",brawl,3" end
    local d = G.diff(All(), G.parseCSV(table.concat(lines, "\n")))
    assertEqual(#d.added + #d.removed + #d.wrongKind, 0, G.report(d))
end)

test("gen-zones: the diff names a new map, a vanished one and a kind that moved", function()
    local G = genZones()
    local d = G.diff(All(), G.parseCSV(CSV))
    -- red under: a diff that skips InstanceType 3 rows (9001 would not be reported).
    assertEqual(#d.added, 1, "added")
    assertEqual(d.added[1].id, 9001, "the new map")
    assertEqual(d.added[1].instanceType, 3, "its instance type")
    -- Every known map but 30 and 572 is absent from the three-line export.
    assertEqual(#d.removed, 42, "removed")
    assertEqual(#d.wrongKind, 0, "kind")
    local moved = G.diff(All(), G.parseCSV("ID,MapName_lang,InstanceType\n30,AV,4\n"))
    assertEqual(#moved.wrongKind, 1, "AV exported as an arena")
    assertEqual(moved.wrongKind[1].id, 30, "the moved map")
    assertTrue(G.report(d):find("9001", 1, true) ~= nil, "the report names the new map")
end)

test("gen-zones: it loads defaults/Zones.lua without the client", function()
    local zones = genZones().loadZones(T.root .. "/defaults/Zones.lua")
    assertEqual(#zones.rows, #All().rows, "the rows it read")
    assertEqual(#zones.BRAWL_MAP_IDS, #All().BRAWL_MAP_IDS, "the brawls it read")
end)

-- ── defaults/TriggerData.lua ─────────────────────────────────────────────────────────────────
-- The trigger ID tables sit beside the zone table: the same "IDs, never names" data, and no suite
-- of their own in the design §9.3 catalog (the triggers' suites, P4.15 on, pin how they are read).

local function D() return T.NS.TriggerData end

local function setList(t)
    local ids = {}
    for k, v in pairs(t) do
        assertEqual(v, true, "set member " .. tostring(k))
        ids[#ids + 1] = k
    end
    table.sort(ids)
    return table.concat(ids, ",")
end

local function mapList(t)
    local out = {}
    for k, v in pairs(t) do out[#out + 1] = tostring(k) .. "=" .. tostring(v) end
    table.sort(out)
    return table.concat(out, ",")
end

-- The states design §6.10 names; every state an aura or a form sets is one of them.
local STATES = {
    MOUNTED = true, SWIMMING = true, DINING = true, SPIRIT_REGEN = true, STEALTH = true, GHOST_WOLF = true,
    FEIGN_DEATH = true, FORM_CASTER = true, FORM_BEAR = true, FORM_CAT = true, FORM_TRAVEL = true,
    FORM_MOONKIN = true, FORM_TREE = true,
}

test("trigger data: NS.TriggerData is published by defaults/TriggerData.lua", function()
    assertEqual(type(D()), "table", "NS.TriggerData")
end)

test("trigger data: the aura and form tables are design §6.10's, each naming a known state", function()
    assertEqual(mapList(D().AURA_ICON_STATE), "132805=DINING,134062=DINING", "AURA_ICON_STATE")
    -- red under: Evocation's 12051 kept (no consumer; design §6.8 "Pseudo-events that disappear").
    -- Shadowmeld is 20580 on WoW Forever (probe P4), 58984 on Retail.
    -- red under: Retail's 58984 kept on Forever (a night elf's Shadowmeld would never feed STEALTH).
    assertEqual(mapList(D().AURA_SPELL_STATE), FOREVER and "20580=STEALTH,2645=GHOST_WOLF,5215=STEALTH,5384=FEIGN_DEATH"
        or "2645=GHOST_WOLF,5215=STEALTH,5384=FEIGN_DEATH,58984=STEALTH", "AURA_SPELL_STATE")
    -- red under: 33891 kept on Forever, a FORM_TREE state no trigger there reads (clients-§4).
    assertEqual(mapList(D().FORM_SPELL_STATE), FOREVER
        and "1784=STEALTH,24858=FORM_MOONKIN,5487=FORM_BEAR,768=FORM_CAT,783=FORM_TRAVEL"
        or "1784=STEALTH,24858=FORM_MOONKIN,33891=FORM_TREE,5487=FORM_BEAR,768=FORM_CAT,783=FORM_TRAVEL",
        "FORM_SPELL_STATE")
    for _, t in ipairs({ D().AURA_ICON_STATE, D().AURA_SPELL_STATE, D().FORM_SPELL_STATE, D().FORM_MAYBE_IN_COMBAT }) do
        for k, v in pairs(t) do
            local state = type(k) == "string" and k or v
            assertTrue(STATES[state], tostring(k) .. " -> " .. tostring(v) .. " is not a §6.10 state")
        end
    end
    assertEqual(setList(D().FORM_MAYBE_IN_COMBAT), "FORM_BEAR", "FORM_MAYBE_IN_COMBAT")
end)

test("trigger data: the Argent mounts are per faction, each with the two either faction rides", function()
    local m = D().ARGENT_MOUNTS
    assertEqual(setList(m.Alliance), "33790,33793,33794,33795,33800,33843,33870,34125,36557", "Alliance")
    assertEqual(setList(m.Horde), "33791,33792,33796,33798,33799,33842,33870,34125,36558", "Horde")
    -- Keyed by the English token (H10): the table holds no localized second return.
    -- red under: a table also keyed `["Allianz"]` (the deDE second return).
    local keys = {}
    for k in pairs(m) do keys[#keys + 1] = k end
    table.sort(keys)
    assertEqual(table.concat(keys, ","), "Alliance,Horde", "ARGENT_MOUNTS' keys")
    -- Legacy `if Alliance ... else <Horde>`: every other faction value reads the Horde set, so
    -- `ARGENT_MOUNTS[faction]` is never nil (faction data not loaded yet, a Neutral pandaren).
    -- red under: drop the __index fallback from D.ARGENT_MOUNTS (defaults/TriggerData.lua).
    assertTrue(rawequal(m[nil], m.Horde), "a nil faction")
    assertTrue(rawequal(m.Neutral, m.Horde), "Neutral")
end)

test("trigger data: the vehicle quests' NPCs are the legacy ids", function()
    assertEqual(setList(D().VIGILANCE_NPCS), "39710,40719,40720,40723", "VIGILANCE_NPCS")
    assertEqual(setList(D().LEVIATHAN_NPCS), "33060,33062,33109", "LEVIATHAN_NPCS")
end)

test("trigger data: DIFFICULTY_GROUPS are design §6.8.1 row 17's, no id in two groups", function()
    -- WoW Forever's four (ruling D7): the open world, normal dungeons, the 20- and 40-player raids.
    -- red under: a Retail-only group (heroic, mythic, LFR, delve) left on Forever.
    local want = FOREVER and { openWorld = "0", dungeonNormal = "1", raid20 = "148", raid40 = "9" } or {
        openWorld = "0", dungeonNormal = "1", dungeonHeroic = "2", dungeonMythic = "23", mythicPlus = "8",
        raidFinder = "17,7", raidNormal = "14,3,4", raidHeroic = "15,5,6", raidMythic = "16", raid40 = "9",
        delve = "208",
    }
    local g, owner, n = D().DIFFICULTY_GROUPS, {}, 0
    for key, ids in pairs(g) do
        n = n + 1
        assertEqual(table.concat(ids, ","), want[key], key)
        for _, id in ipairs(ids) do
            -- red under: 14 listed under raidHeroic as well as raidNormal.
            assertFalse(owner[id] ~= nil, ("difficulty %d is in %s and %s"):format(id, tostring(owner[id]), key))
            owner[id] = key
        end
    end
    assertEqual(n, FOREVER and 4 or 11, "the group count")
    assertEqual(table.concat(D().DIFFICULTY_ORDER, ","), FOREVER and "openWorld,dungeonNormal,raid20,raid40"
        or "openWorld,dungeonNormal,dungeonHeroic,dungeonMythic,mythicPlus,raidFinder,raidNormal,raidHeroic,"
        .. "raidMythic,raid40,delve", "DIFFICULTY_ORDER")
    -- DIFFICULTY_ORDER lists every group once.
    local seen = {}
    for _, key in ipairs(D().DIFFICULTY_ORDER) do
        assertTrue(g[key] ~= nil, key .. " is ordered but not a group")
        -- red under: "raidNormal" listed twice in DIFFICULTY_ORDER (defaults/TriggerData.lua).
        assertFalse(seen[key], key .. " is ordered twice")
        seen[key] = true
    end
    assertEqual(#D().DIFFICULTY_ORDER, n, "DIFFICULTY_ORDER covers every group")
end)

test("trigger data: the maps, skill lines, Find Fish and the cooking pets", function()
    assertEqual(table.concat(D().VASHJIR_MAP_IDS, ","), "201,204,205", "VASHJIR_MAP_IDS")
    assertEqual(mapList(D().SKILL_LINES), "COOKING=185,HERBALISM=182,LOCKPICKING=633,MINING=186,SKINNING=393",
        "SKILL_LINES")
    assertEqual(D().FIND_FISH.spell, 43308, "FIND_FISH.spell")
    assertEqual(D().FIND_FISH.texture, 133888, "FIND_FISH.texture")
    local pets = {}
    for i, p in ipairs(D().COOKING_PETS) do pets[i] = p.param .. "=" .. p.species end
    assertEqual(table.concat(pets, ","), "summonRagnaros=297,summonPierre=1204", "COOKING_PETS")
end)

-- ── the engine (P4.14) ───────────────────────────────────────────────────────────────────────
-- modules/States_Zone.lua's producer (design §6.5, INV §8.2): the derived tables, CurrentIds (the
-- instance type gives the generics, the map id the specifics, a name never), the debounced update
-- with its three-field early-out, the wear-order emission inside one Batch, the first-sighting seed,
-- and the public reads. NS.Equip (P4.8), NS.Triggers (P4.15) and NS.Stack (P4.9) are recorded fakes
-- (design §12, the fake rule). "Every row has one trigger" is P4.16d's test_triggers_pvp: the zone
-- triggers are emitted by Triggers.Finalize (P4.15).

local function zoneScene(opts)
    opts = opts or {}
    local inst = unitLoad()
    local NS, M = inst.NS, inst.mocks
    local ctl = { worn = opts.worn or {}, forState = opts.forState or {} }
    local equip = T.fake(NS, "Equip", { Batch = function(fn, ...) return true, fn(...) end,
                                        SuspendedForLoad = function() return false end })
    T.fake(NS, "Triggers", { ForState = function(id) return ctl.forState[id] or {} end })
    T.fake(NS, "Stack", { IsWorn = function(id) return ctl.worn[id] == true end })
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.STATE_CHANGED, function(_, id, on)
        heard[#heard + 1] = id .. "=" .. tostring(on)
    end)
    NS.States.ResumeZone()
    M.__fireTimers()
    for i = #heard, 1, -1 do heard[i] = nil end
    return { NS = NS, M = M, S = NS.States, W = M.__world, equip = equip, heard = heard, ctl = ctl }
end

local function idList(set)
    local out = {}
    for _, row in ipairs(Z().rows) do if set[row.id] then out[#out + 1] = row.id end end
    return table.concat(out, ",")
end

local function enter(s, spec)
    s.W:setInstance(spec)
    s.M.__fire("ZONE_CHANGED_NEW_AREA")
    s.M.__fireTimers()
end

-- Whether zone id `id` applied at the last update, as `/or zone` reports it: an id on ZoneInfo's
-- "Zone outfits active" line.
local function inZone(s, id)
    local lines = s.S.ZoneInfo()
    local active = lines[#lines]:match("^Zone outfits active: (.*)$")
    if not active then return false end
    for each in (active .. ", "):gmatch("(.-), ") do
        if each == id then return true end
    end
    return false
end

test("zone engine: ORDER and BY_MAP_ID are derived from the rows at load", function()
    local order = {}
    for i, row in ipairs(Z().rows) do order[i] = row.id end
    assertEqual(table.concat(Z().ORDER, ","), table.concat(order, ","), "ORDER")
    local want, n = deriveByMapID(Z()), 0
    for mapID, ids in pairs(want) do
        n = n + 1
        assertEqual(table.concat(Z().BY_MAP_ID[mapID] or {}, ","), table.concat(ids, ","), "map " .. mapID)
    end
    local extra = 0
    for mapID in pairs(Z().BY_MAP_ID) do if not want[mapID] then extra = extra + 1 end end
    assertEqual(extra, 0, "maps the rows do not list")
    -- Forever's eight are AV's two, AB's four and WSG's two (ruling D3).
    assertEqual(n, FOREVER and 8 or 44)
end)

test("zone engine: an unknown battleground gives the generic only; an unknown arena both generics", function()
    local S = T.NS.States
    -- red under: generics only from BY_MAP_ID (a map Blizzard adds tomorrow would set nothing).
    assertEqual(idList(S.CurrentIds("pvp", 99999)), "PVP_BATTLEGROUND", "an unknown battleground")
    -- Forever has no PVP_ARENA row (ruling D3), so an arena-typed instance sets the battleground only.
    assertEqual(idList(S.CurrentIds("arena", 99999)), FOREVER and "PVP_BATTLEGROUND" or "PVP_BATTLEGROUND,PVP_ARENA",
        "an unknown arena")
    assertEqual(idList(S.CurrentIds("none", nil)), "", "the open world")
    assertEqual(idList(S.CurrentIds("party", 1)), "", "a dungeon")
    assertEqual(idList(S.CurrentIds(nil, nil)), "", "nothing readable")
end)

test("zone engine: every map gives its own row plus the generics, and nothing else", function()
    local S = T.NS.States
    for _, row in ipairs(Z().rows) do
        for _, mapID in ipairs(row.mapIDs or {}) do
            local itype = row.kind == "arena" and "arena" or "pvp"
            local want = row.kind == "arena" and ("PVP_BATTLEGROUND,PVP_ARENA," .. row.id)
                or ("PVP_BATTLEGROUND," .. row.id)
            -- red under: an arena row deriving only PVP_BATTLEGROUND in BY_MAP_ID (read on a "pvp" type).
            assertEqual(idList(S.CurrentIds("pvp", mapID)), want, row.id .. " map " .. mapID .. " (by map)")
            assertEqual(idList(S.CurrentIds(itype, mapID)), want, row.id .. " map " .. mapID)
        end
    end
    for _, mapID in ipairs({ 529, 1681, 2107, 2177 }) do
        assertEqual(idList(S.CurrentIds("pvp", mapID)), "PVP_BATTLEGROUND,BG_AB", "AB map " .. mapID)
    end
    for _, mapID in ipairs(Z().BRAWL_MAP_IDS) do
        assertEqual(idList(S.CurrentIds("pvp", mapID)), "PVP_BATTLEGROUND", "brawl " .. mapID)
    end
end)

test("zone engine: the map decides, never the name", function()
    local s = zoneScene()
    -- An instance named for Alterac Valley on a map the table does not know.
    s.M.__context.zone = "Alterac Valley"
    s.M.GetRealZoneText = function() return "Alterac Valley" end
    s.M.GetMinimapZoneText = function() return "Alterac Valley" end
    enter(s, { name = "Alterac Valley", type = "pvp", instanceID = 99999 })
    -- red under: any name match in CurrentIds or the update (the zone texts reached the decision).
    assertFalse(inZone(s, "BG_AV"), "a name set the AV outfit")
    assertTrue(inZone(s, "PVP_BATTLEGROUND"))
    enter(s, { name = "Somewhere", type = "pvp", instanceID = 30 })
    assertTrue(inZone(s, "BG_AV"), "the map id")
end)

test("zone engine: one battleground never sets another, and leaving clears both", function()
    local s = zoneScene()
    enter(s, { type = "pvp", instanceID = 30 })
    assertTrue(inZone(s, "BG_AV"))
    for _, row in ipairs(Z().rows) do
        if row.id ~= "BG_AV" and row.id ~= "PVP_BATTLEGROUND" then
            assertFalse(inZone(s, row.id), row.id .. " in Alterac Valley")
        end
    end
    assertTrue(s.S.InPvPInstance())
    enter(s, nil)
    assertFalse(inZone(s, "BG_AV"))
    assertFalse(inZone(s, "PVP_BATTLEGROUND"))
    assertFalse(s.S.InPvPInstance())
end)

test("zone engine: the states go out in wear order, generic first, inside one Batch", function()
    local s = zoneScene()
    local b = s.equip.__count("Batch")
    -- Forever has no arenas (ruling D3): Alterac Valley's two ids stand in for the three.
    local ids = FOREVER and { "PVP_BATTLEGROUND", "BG_AV" } or { "PVP_BATTLEGROUND", "PVP_ARENA", "ARENA_LORDAERON" }
    local function heard(on)
        local out = {}
        for i, id in ipairs(ids) do out[i] = id .. "=" .. tostring(on) end
        return table.concat(out, ",")
    end
    enter(s, FOREVER and { type = "pvp", instanceID = 30 } or { type = "arena", instanceID = 572 })
    assertEqual(s.equip.__count("Batch"), b + 1, "one bracket")
    -- red under: iterating the current ids with pairs (the specific outfit could go on under the generic).
    assertEqual(table.concat(s.heard, ","), heard(true))
    for i = #s.heard, 1, -1 do s.heard[i] = nil end
    enter(s, nil)
    assertEqual(table.concat(s.heard, ","), heard(false))
end)

test("zone engine: the zone events are debounced into one update 0.01 s out", function()
    local s = zoneScene()
    s.W:setInstance({ type = "pvp", instanceID = 30 })
    for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD" }) do
        s.M.__fire(ev)
    end
    local live = 0
    for _, t in ipairs(s.M.__timers()) do
        live = live + 1
        assertEqual(t.delay, 0.01, "the debounce delay")
    end
    -- red under: scheduling without canceling the pending update (four updates for one move).
    assertEqual(live, 1, "one pending update")
    assertFalse(inZone(s, "BG_AV"), "nothing before the debounce")
    s.M.__fireTimers()
    assertTrue(inZone(s, "BG_AV"))
end)

test("zone engine: the update returns early only when type, map id and zone text all hold", function()
    local s = zoneScene()
    enter(s, { type = "pvp", instanceID = 30 })
    local b = s.equip.__count("Batch")
    s.M.__fire("ZONE_CHANGED")
    s.M.__fireTimers()
    -- red under: no early-out (every subzone step re-ran the zone states).
    assertEqual(s.equip.__count("Batch"), b, "nothing moved")
    -- Ashran and Wintergrasp each name a zone and a battleground: the text is a change detector too.
    s.M.__context.zone = "Somewhere else"
    s.M.__fire("ZONE_CHANGED")
    s.M.__fireTimers()
    -- red under: an early-out on the map id and type alone.
    assertEqual(s.equip.__count("Batch"), b + 1, "the zone text moved")
    s.W:setInstance({ type = "pvp", instanceID = 529 })
    s.M.__context.zone = "Somewhere else"
    s.M.__fire("ZONE_CHANGED")
    s.M.__fireTimers()
    assertEqual(s.equip.__count("Batch"), b + 2, "the map id moved")
    assertTrue(inZone(s, "BG_AB"))
end)

test("zone engine: a first sighting is seeded from the worn outfit whose trigger subscribes", function()
    local s = zoneScene({ forState = { BG_AV = { "BG_AV" } } })
    local O = s.NS.Outfits
    local id = O.Create("AV", {}, { trigger = "BG_AV" })
    s.ctl.worn[id] = true                                       -- a /reload inside Alterac Valley
    -- The scene's first update already saw every zone id; a stand-down forgets the states.
    s.S.Suspend()
    s.S.ResumeZone()
    enter(s, { type = "pvp", instanceID = 30 })
    -- red under: seeding a nil zone state as false (the AV outfit would be worn a second time).
    assertEqual(table.concat(s.heard, ","), "PVP_BATTLEGROUND=true", "no edge for the worn AV outfit")
    assertTrue(inZone(s, "BG_AV"))
end)

test("zone engine: ZoneInfo reports the instance, a missing map entry and the active zone ids", function()
    local s = zoneScene()
    if FOREVER then
        -- Forever has no arenas (ruling D3): Alterac Valley and an unknown battleground instead.
        enter(s, { name = "Alterac Valley", type = "pvp", instanceID = 30 })
        local lines = s.S.ZoneInfo()
        assertEqual(lines[1], "Instance: Alterac Valley (type pvp, map ID 30)")
        assertEqual(lines[2], "Zone outfits active: PVP_BATTLEGROUND, BG_AV")
        assertEqual(#lines, 2)
        enter(s, { name = "New Battleground", type = "pvp", instanceID = 99999 })
        lines = s.S.ZoneInfo()
        assertEqual(lines[2], "This map has no entry in the zone table")
        assertEqual(lines[3], "Zone outfits active: PVP_BATTLEGROUND")
        enter(s, nil)
        lines = s.S.ZoneInfo()
        assertEqual(lines[#lines], "No zone outfits apply here")
        return
    end
    enter(s, { name = "Ruins of Lordaeron", type = "arena", instanceID = 572 })
    local lines = s.S.ZoneInfo()
    assertEqual(lines[1], "Instance: Ruins of Lordaeron (type arena, map ID 572)")
    assertEqual(lines[2], "Zone outfits active: PVP_BATTLEGROUND, PVP_ARENA, ARENA_LORDAERON")
    assertEqual(#lines, 2)
    enter(s, { name = "New Arena", type = "arena", instanceID = 99999 })
    lines = s.S.ZoneInfo()
    -- red under: no BY_MAP_ID check in ZoneInfo (a map the table misses reads as known).
    assertEqual(lines[2], "This map has no entry in the zone table")
    assertEqual(lines[3], "Zone outfits active: PVP_BATTLEGROUND, PVP_ARENA")
    enter(s, nil)
    lines = s.S.ZoneInfo()
    assertEqual(lines[#lines], "No zone outfits apply here")
end)

test("zone engine: SuspendZone drops the events and the pending update; ResumeZone re-reads", function()
    local s = zoneScene()
    enter(s, { type = "pvp", instanceID = 30 })
    s.M.__fire("ZONE_CHANGED")
    s.S.SuspendZone()
    local n = 0
    for _, r in ipairs(s.M.__registrations()) do
        if r.event:find("^ZONE_CHANGED") then n = n + 1 end
    end
    -- red under: SuspendZone leaving the zone target registered.
    assertEqual(n, 0, "a zone event survived")
    assertEqual(s.M.__fireTimers(), 0, "the pending update survived")
    assertFalse(inZone(s, "BG_AV"), "the current ids cleared")
    s.S.ResumeZone()
    s.M.__fireTimers()
    -- The early-out memory went with the stand-down, so the same place is read again.
    assertTrue(inZone(s, "BG_AV"))
end)
