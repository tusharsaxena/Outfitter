-- tests/test_triggers_parity.lua — P4.16e (design §6.8, INV §9.7, §18): the trigger catalog against
-- the legacy preset menu. tests/fixtures/legacy/presets.lua is every preset the legacy addon offered
-- a DRUID with four specs (so SPECIALIZATION_1..4 are in it), in menu order; PARITY below is design
-- §6.8 as data. Every legacy id maps to a new trigger or to a drop reason; each ported row keeps the
-- legacy events (renamed to the new pseudo keys, minus CITY and ARGENT_DAWN), the legacy params
-- (name, type, default, label, suffix), the legacy category or class and the legacy sort. Every
-- difference is a listed exception carrying its reason, so a catalog edit that is not in §6.8 turns
-- this suite red. The counts are the §6.8 totals: 77 ported, 6 retired, 1 dropped by H1.
--
-- The instance is the legacy capture's own stand-in (fixtures/legacy/README.md): a DRUID whose four
-- specs are named Spec1..Spec4, and a client that names each PvP map the way the legacy preset did.
-- The behavior of every trigger is pinned in the test_triggers_* suites; this one pins the menu.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local LEGACY = T.legacy.presets

-- ── the §6.8 parity table ─────────────────────────────────────────────────────────────────────
-- A ported row: `id` (the new trigger), and only what differs from the legacy preset:
--   keys     legacy $SETTING field -> new param key, where the default rule (Tree<n> -> spec<n>, else
--            the field with its first letter lower-cased) does not give it
--   types    new param key -> its new type, where the legacy type was retyped (INV §19 fixes)
--   labels   new param key -> its new label, where the legacy label changed
--   addParams  new param keys with no legacy $SETTING (appended after the legacy ones)
--   params   a string: the params were redesigned; the reason (the case pins the new set itself)
--   addEvents / dropEvents  events the new row gained or lost beyond the global renames
--   name     the new name, where it changed; `refiled` the new category, where it changed
-- A dropped row: `drop` = "retired" (INV §18) or "H1", and `why`.

local BIND = "BIND"
local PARITY = {
    -- GENERAL
    EQUIP_ON_TARGET = { id = "TARGET", keys = { targetName = "targets" }, types = { targets = "unitlist" },
                        labels = { targets = "Targets" }, addParams = { "unequipOnChange" },
                        addEvents = { BIND } },                          -- no nil raise, can unequip, NPCs by ID
    HAS_BUFF        = { id = "HAS_BUFF", keys = { buffName = "spellIDs" }, types = { spellIDs = "spelllist" },
                        labels = { spellIDs = "Buffs" }, addEvents = { BIND }, dropEvents = { "PLAYER_ENTERING_WORLD" } },
    HAS_DEBUFF      = { drop = "retired", why = "UnitDebuff is gone (INV §18); revivable as a harmful flag (O25)" },
    IN_DUNGEON      = { id = "IN_DUNGEON", addEvents = { BIND } },
    IN_ZONES        = { id = "IN_ZONES", keys = { zoneList = "maps", minimapZoneList = "subzones" },
                        types = { maps = "maplist", subzones = "subzonelist" }, addEvents = { BIND } },
    LOW_HEALTH      = { drop = "retired", why = "health is a secret value that may not be compared (INV §18)" },
    FEET_QUEUE      = { id = "FEET_QUEUE", types = { boots = "itemlist" } },
    SOLO            = { id = "INSTANCE_DIFFICULTY", name = "Instance Difficulty",
                        params = "modern difficulty IDs and the open world (O24)",
                        addEvents = { "PLAYER_DIFFICULTY_CHANGED", BIND } },
    Spirit          = { id = "SPIRIT_REGEN" },
    TalentTree      = { id = "TALENT_TREE" },
    TRINKET_QUEUE   = { id = "TRINKET_QUEUE", types = { trinkets = "itemlist", trinkets2 = "itemlist" } },
    -- TRADE
    COOKING         = { id = "COOKING", keys = { Ragnaros = "summonRagnaros", Pierre = "summonPierre",
                                                 RandomCookFirePet = "randomPet" } },
    Dining          = { id = "DINING" },
    FALLING         = { id = "FALLING" },
    Fishing         = { id = "FISHING", keys = { EnableFishTracking = "trackFish", EnableAutoLoot = "autoLoot",
                                                 DisableClicktoMove = "disableClickToMove",
                                                 ActionBarNumber = "actionBarPage" } },
    HERBALISM       = { id = "GATHER_HERBALISM" },
    MINING          = { id = "GATHER_MINING" },
    RESTING         = { id = "RESTING", addEvents = { BIND } },
    Riding          = { id = "RIDING", keys = { StayEquippedWhileFalling = "stayWhileFalling" },
                        addEvents = { "TIMER" } },                       -- the dynamic ticker, now declared
    LOCKPICKING     = { id = "LOCKPICKING", addEvents = { "TIMER" } },   -- the dynamic ticker, now declared
    SKINNING        = { id = "GATHER_SKINNING" },
    SPELLCAST       = { id = "SPELLCAST", keys = { spell = "spellIDs" }, types = { spellIDs = "spelllist" },
                        labels = { spellIDs = "Spells" } },               -- by spellID, not the castGUID
    Swimming        = { id = "SWIMMING" },
    -- PVP (design §6.8.2)
    Battleground = { id = "PVP_BATTLEGROUND" },
    Arena = { id = "PVP_ARENA", name = "Arena" },                        -- a generic keeps its own name
    AV = { id = "BG_AV" }, AB = { id = "BG_AB" }, WSG = { id = "BG_WSG" }, EotS = { id = "BG_EOTS" },
    SotA = { id = "BG_SOTA" }, IoC = { id = "BG_IOC" }, TwinPeaks = { id = "BG_TWINPEAKS" },
    Gilneas = { id = "BG_GILNEAS" }, Wintergrasp = { id = "BG_WINTERGRASP" },
    SilvershardMines = { id = "BG_SILVERSHARD" }, TempleOfKotmogu = { id = "BG_KOTMOGU" },
    DeepwindGorge = { id = "BG_DEEPWIND" }, SeethingShore = { id = "BG_SEETHING" },
    DeephaulRavine = { id = "BG_DEEPHAUL" }, Ashran = { id = "BG_ASHRAN" },
    LordaeronArena = { id = "ARENA_LORDAERON" },
    Sewers = { id = "ARENA_SEWERS", name = "Arena: Sewers" },             -- an arena row reads "Arena: <map>"
    BladesEdgeArena = { id = "ARENA_BLADESEDGE" }, NagrandArena = { id = "ARENA_NAGRAND" },
    TolVironArena = { id = "ARENA_TOLVIRON" }, TigersPeakArena = { id = "ARENA_TIGERSPEAK" },
    BlackRookArena = { id = "ARENA_BLACKROOK" }, AshamanesFallArena = { id = "ARENA_ASHAMANE" },
    HookPointArena = { id = "ARENA_HOOKPOINT" }, MugambalaArena = { id = "ARENA_MUGAMBALA" },
    RobodromeArena = { id = "ARENA_ROBODROME" }, EmpyreanDomainArena = { id = "ARENA_EMPYREAN" },
    MaldraxxusArena = { id = "ARENA_MALDRAXXUS" }, EnigmaCrucibleArena = { id = "ARENA_ENIGMA" },
    NokhudonArena = { id = "ARENA_NOKHUDON" }, CageOfCarnageArena = { id = "ARENA_CAGEOFCARNAGE" },
    PVP_FLAGGED     = { id = "PVP_FLAGGED", addEvents = { BIND } },
    -- QUEST
    ARGENT_TOURNY      = { id = "QUEST_ARGENT_TOURNAMENT" },
    CHAMPCATACLYSM     = { drop = "retired", why = "GetMapNameByID and championing are gone (INV §18)" },
    CHAMPFACTION       = { drop = "retired", why = "GetMapNameByID and championing are gone (INV §18)" },
    CHAMP              = { drop = "retired", why = "GetMapNameByID and championing are gone (INV §18)" },
    FLAME_LEVIATHAN    = { id = "QUEST_FLAME_LEVIATHAN" },
    PETBATTLE          = { id = "PET_BATTLE" },
    QUEST_TURNIN       = { id = "QUEST_TURNIN" },
    MULTI_SURVEY       = { id = "QUEST_MULTIPHASE_SURVEY", addEvents = { BIND } },
    VIGILANCE_ON_WINGS = { id = "QUEST_VIGILANCE_ON_WINGS" },
    -- ENTERTAIN
    City      = { drop = "retired", why = "CITY is never produced (INV §18); IN_ZONES with the city's uiMapID" },
    DANCE     = { id = "DANCE" },
    COMPANION = { id = "COMPANION", types = { pet = "pet" }, labels = { pet = "Pet" } },   -- a petGUID picker
    -- CLASS (design §6.8.3)
    Bear = { id = "DRUID_BEAR" }, Caster = { id = "DRUID_CASTER" }, Cat = { id = "DRUID_CAT" },
    Moonkin = { id = "DRUID_MOONKIN" }, Prowl = { id = "DRUID_PROWL" }, Travel = { id = "DRUID_TRAVEL" },
    Tree = { id = "DRUID_TREE" },
    SPECIALIZATION_1 = { id = "SPEC_1", refiled = "SPEC", addEvents = { BIND } },
    SPECIALIZATION_2 = { id = "SPEC_2", refiled = "SPEC", addEvents = { BIND } },
    SPECIALIZATION_3 = { id = "SPEC_3", refiled = "SPEC", addEvents = { BIND } },
    SPECIALIZATION_4 = { id = "SPEC_4", refiled = "SPEC", addEvents = { BIND } },
    Feigning  = { id = "HUNTER_FEIGN_DEATH" },
    Stealth   = { id = "ROGUE_STEALTH", keys = { EnableAutoLoot = "autoLoot" } },
    GhostWolf = { id = "SHAMAN_GHOST_WOLF" },
}

-- Custom was the menu's own "no preset" entry, never a preset, so the capture does not hold it.
local NOT_CAPTURED = { Custom = { drop = "H1", why = "no hand-written scripts (H1, anti-patterns #20)" } }

-- The INV §18 retired presets, by legacy id.
local RETIRED = { "CHAMP", "CHAMPCATACLYSM", "CHAMPFACTION", "City", "HAS_DEBUFF", "LOW_HEALTH" }

-- ── the global renames (design §6.8 "Pseudo-events that disappear", O10) ──────────────────────

local EVENT_RENAME = {
    GAMETOOLTIP_SHOW = "TOOLTIP_SHOW", GAMETOOLTIP_HIDE = "TOOLTIP_HIDE",
    OUTFIT_EQUIPPED = "OUTFIT_WORN", OUTFIT_UNEQUIPPED = "OUTFIT_REMOVED",
    UNIT_AURA = "AURAS", INITIALIZE = BIND,
    ACTIVE_TALENT_GROUP_CHANGED = "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",   -- O10
}
local NEVER_PRODUCED = { CITY = true, ARGENT_DAWN = true }

-- A legacy special state -> the new state id (the X / NOT_X pair becomes one STATE:<id> key).
local STATE_RENAME = {
    SPIRIT_REGEN = "SPIRIT_REGEN", DINING = "DINING", MOUNTED = "MOUNTED", SWIMMING = "SWIMMING",
    STEALTH = "STEALTH", GHOST_WOLF = "GHOST_WOLF", FEIGN_DEATH = "FEIGN_DEATH",
    CASTER_FORM = "FORM_CASTER", BEAR_FORM = "FORM_BEAR", CAT_FORM = "FORM_CAT",
    TRAVEL_FORM = "FORM_TRAVEL", MOONKIN_FORM = "FORM_MOONKIN", TREE_FORM = "FORM_TREE",
}

local TYPE_RENAME = { boolean = "bool", number = "number", string = "string" }

-- One legacy event as the new row names it, or nil when it has no new form. A BATTLEGROUND* state
-- is the zone row's own (the new zone trigger's id is its state id, design §6.8.2).
local function newEvent(e, newId)
    if NEVER_PRODUCED[e] or e:find("^NOT_") then return nil end
    if EVENT_RENAME[e] then return EVENT_RENAME[e] end
    if STATE_RENAME[e] then return "STATE:" .. STATE_RENAME[e] end
    if e:find("^BATTLEGROUND") then return "STATE:" .. newId end
    return e
end

local function sortedList(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return table.concat(out, ",")
end

local function show(v)
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. show(x) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

-- ── the instance ──────────────────────────────────────────────────────────────────────────────

local STAND_IN_SPECS = { { 102, "Spec1" }, { 103, "Spec2" }, { 104, "Spec3" }, { 105, "Spec4" } }
local PREFIX = { "^Arena: ", "^Battleground: " }

-- The legacy preset's map name for a zone row ("Battleground: Alterac Valley" -> "Alterac Valley").
local function legacyMapName(name)
    for _, p in ipairs(PREFIX) do name = name:gsub(p, "") end
    return name
end

local function legacyById()
    local out = {}
    for i, p in ipairs(LEGACY.presets) do out[p.id] = p; p.order = i end
    return out
end

local function zoneNames(NS)
    local byNew, names = {}, {}
    for _, p in ipairs(LEGACY.presets) do
        local row = PARITY[p.id]
        if row and row.id then byNew[row.id] = p end
    end
    for _, z in ipairs(NS.Zones.rows) do
        local p = byNew[z.id]
        if p and z.mapIDs then names[z.mapIDs[1]] = legacyMapName(p.name) end
    end
    return names
end

-- A DRUID with the capture's four stand-in specs, and the client naming each map as legacy did.
local function instance()
    local names = {}
    local inst = T.load({ mutate = function(M)
        M.__world:setClass("DRUID", 1)
        M.__world.specs = STAND_IN_SPECS
        M.GetRealZoneText = function(mapID) return names[mapID] end
    end })
    for k, v in pairs(zoneNames(inst.NS)) do names[k] = v end
    inst.NS.Triggers.Finalize()
    return inst.NS
end

local NSI = instance()
local Tr, Params = NSI.Triggers, NSI.TriggerParams

local function ported()
    local out = {}
    for _, p in ipairs(LEGACY.presets) do
        local row = PARITY[p.id]
        if row and row.id then out[#out + 1] = { legacy = p, row = row, desc = Tr.Get(row.id) } end
    end
    return out
end

-- ── the mapping ───────────────────────────────────────────────────────────────────────────────

test("parity: every legacy preset maps to a new trigger or a listed drop reason", function()
    for _, p in ipairs(LEGACY.presets) do
        local row = PARITY[p.id]
        assertTrue(row ~= nil, "legacy " .. p.id .. " has no parity row")
        if row.id then
            assertTrue(Tr.Get(row.id) ~= nil, p.id .. " -> " .. row.id .. " is not a trigger")
        else
            assertTrue(row.drop == "retired" and type(row.why) == "string", p.id .. " drops with a reason")
        end
    end
    local captured = legacyById()
    for id in pairs(PARITY) do assertTrue(captured[id] ~= nil, "parity row " .. id .. " names no legacy preset") end
    for id in pairs(NOT_CAPTURED) do assertNil(captured[id], id .. " is not in the capture") end
end)

test("parity: every trigger is the image of exactly one legacy preset", function()
    local seen = {}
    for legacyId, row in pairs(PARITY) do
        if row.id then
            assertNil(seen[row.id], row.id .. " is mapped from " .. tostring(seen[row.id]) .. " and " .. legacyId)
            seen[row.id] = legacyId
        end
    end
    -- red under: a catalog row added to defaults/Triggers.lua with no §6.8 origin
    for _, d in ipairs(Tr.All()) do assertTrue(seen[d.id] ~= nil, d.id .. " has no legacy preset") end
end)

test("parity: the retired rows are exactly INV §18's presets, and Custom is dropped by H1", function()
    local got = {}
    for id, row in pairs(PARITY) do
        if row.drop then got[#got + 1] = id end
    end
    table.sort(got)
    assertEqual(table.concat(got, ","), table.concat(RETIRED, ","))
    assertEqual(NOT_CAPTURED.Custom.drop, "H1")
    assertNil(Tr.Get("Custom"))
    assertNil(Tr.Get("CUSTOM"))
end)

test("parity: 77 ported, 6 retired, 1 dropped by H1, 84 in all (design §6.8 totals)", function()
    local n = { ported = 0, retired = 0, H1 = 0 }
    for _, p in ipairs(LEGACY.presets) do
        local row = PARITY[p.id]
        local k = row.id and "ported" or row.drop
        n[k] = n[k] + 1
    end
    for _, row in pairs(NOT_CAPTURED) do n[row.drop] = n[row.drop] + 1 end
    assertEqual(n.ported, 77)
    assertEqual(n.retired, 6)
    assertEqual(n.H1, 1)
    assertEqual(#LEGACY.presets + 1, 84)
    assertEqual(#Tr.All(), 77, "the registry holds exactly the ported rows")
end)

-- ── events ────────────────────────────────────────────────────────────────────────────────────

local function expectedEvents(e)
    local set = {}
    for _, ev in ipairs(e.legacy.events) do
        local n = newEvent(ev, e.row.id)
        if n then set[n] = true end
    end
    for _, ev in ipairs(e.row.dropEvents or {}) do
        assertTrue(set[ev], e.row.id .. " drops " .. ev .. ", which legacy did not have")
        set[ev] = nil
    end
    for _, ev in ipairs(e.row.addEvents or {}) do
        assertNil(set[ev], e.row.id .. " adds " .. ev .. ", which legacy already had")
        set[ev] = true
    end
    return set
end

local function actualEvents(desc)
    local set = {}
    for _, ev in ipairs(desc.events) do set[ev] = true end
    if desc.initial then set[BIND] = true end
    return set
end

test("parity: each ported row's events equal legacy's, renamed, minus CITY/ARGENT_DAWN", function()
    -- red under: BIND taken out of RESTING's events in defaults/Triggers.lua
    for _, e in ipairs(ported()) do
        assertEqual(sortedList(actualEvents(e.desc)), sortedList(expectedEvents(e)), e.legacy.id .. " -> " .. e.row.id)
    end
end)

test("parity: no retired pseudo event survives in any descriptor", function()
    for _, d in ipairs(Tr.All()) do
        for _, ev in ipairs(d.events) do
            assertNil(NEVER_PRODUCED[ev], d.id .. " listens to " .. ev)
            assertNil(EVENT_RENAME[ev], d.id .. " still names the legacy " .. ev)
            assertNil(STATE_RENAME[ev], d.id .. " still names the legacy state " .. ev)
            assertTrue(not ev:find("^NOT_") and not ev:find("^BATTLEGROUND"), d.id .. " still names " .. ev)
        end
    end
end)

-- ── params ────────────────────────────────────────────────────────────────────────────────────

local function newKey(row, field)
    if row.keys and row.keys[field] then return row.keys[field] end
    local n = field:match("^Tree(%d)$")
    if n then return "spec" .. n end
    return field:sub(1, 1):lower() .. field:sub(2)
end

-- What legacy's $SETTING lines say each param is: key, type, default, label, suffix.
local function expectedParams(e)
    local out = {}
    for _, input in ipairs(e.legacy.inputs or {}) do
        local key = newKey(e.row, input.field)
        local ptype = (e.row.types and e.row.types[key]) or TYPE_RENAME[input.type]
        local default = input.default
        if default == nil or (e.row.types and e.row.types[key]) then default = Params.TYPES[ptype].default end
        out[#out + 1] = { key = key, type = ptype, default = default, suffix = input.suffix,
                          label = (e.row.labels and e.row.labels[key]) or input.label }
    end
    return out
end

-- The fields of one param that differ from what legacy's $SETTING line says, as "where field: want/got".
local function paramDiffs(where, want, got, out)
    local have = { key = got.key, type = got.type, default = show(got.default),
                   label = Params.Label(got), suffix = tostring(got.suffix) }
    local need = { key = want.key, type = want.type, default = show(want.default),
                   label = want.label, suffix = tostring(want.suffix) }
    for _, field in ipairs({ "key", "type", "default", "label", "suffix" }) do
        if have[field] ~= need[field] then
            out[#out + 1] = ("%s %s: want %s, got %s"):format(where, field, tostring(need[field]), tostring(have[field]))
        end
    end
end

local function rowParamDiffs(e, out)
    local want, got = expectedParams(e), e.desc.params
    local added = e.row.addParams or {}
    if #got ~= #want + #added then
        out[#out + 1] = ("%s: %d params, want %d"):format(e.row.id, #got, #want + #added)
        return
    end
    for i, w in ipairs(want) do paramDiffs(e.row.id .. "." .. w.key, w, got[i], out) end
    for j, key in ipairs(added) do
        if got[#want + j].key ~= key then out[#out + 1] = e.row.id .. ": added param " .. key .. " missing" end
    end
end

test("parity: each ported row's params equal legacy's $SETTING lines (default from the descriptor)", function()
    -- red under: IN_DUNGEON's enableArena default flipped to true in defaults/Triggers.lua
    local diffs = {}
    for _, e in ipairs(ported()) do
        if type(e.row.params) ~= "string" then rowParamDiffs(e, diffs) end
    end
    assertEqual(table.concat(diffs, "; "), "")
end)

test("parity: INSTANCE_DIFFICULTY's redesigned params are one off toggle per difficulty group (O24)", function()
    local d = Tr.Get("INSTANCE_DIFFICULTY")
    local order = NSI.TriggerData.DIFFICULTY_ORDER
    assertEqual(#d.params, #order)
    for i, key in ipairs(order) do
        assertEqual(d.params[i].key, key)
        assertEqual(d.params[i].type, "bool")
        assertEqual(d.params[i].default, false, key)
    end
    for _, input in ipairs(legacyById().SOLO.inputs) do
        assertNil(input.default, "every legacy SOLO toggle defaulted off: " .. input.field)
    end
end)

-- ── filing and sort ───────────────────────────────────────────────────────────────────────────

test("parity: the category order is legacy's, with the generated spec rows after CLASS", function()
    local legacyOrder = {}
    for cat, rank in pairs(LEGACY.categoryOrder) do legacyOrder[rank + 1] = cat end
    assertEqual(table.concat(NSI.TriggerCatalog.CATEGORY_ORDER, ","), table.concat(legacyOrder, ","))
    assertEqual(Tr.SPEC_CATEGORY, "SPEC")
    assertEqual(table.concat(Tr.Categories("DRUID"), ","), table.concat(legacyOrder, ",") .. ",SPEC")
end)

test("parity: each ported row keeps legacy's category, or CLASS for a class preset, and its class", function()
    -- red under: DANCE refiled under GENERAL in defaults/Triggers.lua
    for _, e in ipairs(ported()) do
        local want = e.row.refiled or e.legacy.category or "CLASS"
        assertEqual(e.desc.category, want, e.row.id .. " category")
        assertEqual(e.desc.class, e.legacy.class, e.row.id .. " class")
    end
end)

test("parity: each ported row keeps legacy's name, bar the listed renames", function()
    -- red under: "Druid: Prowl" renamed in defaults/Triggers.lua
    for _, e in ipairs(ported()) do
        assertEqual(e.desc.name, e.row.name or e.legacy.name, e.legacy.id .. " -> " .. e.row.id)
        if e.row.name then assertTrue(e.row.name ~= e.legacy.name, e.row.id .. "'s rename is a real change") end
    end
end)

test("parity: the menu sorts as legacy's, and a renamed or refiled row by the same rule", function()
    local moved, wantIds = {}, {}
    for _, e in ipairs(ported()) do
        if e.row.name or e.row.refiled then moved[e.row.id] = true else wantIds[#wantIds + 1] = e.row.id end
    end
    local gotIds, rank = {}, {}
    for i, c in ipairs(NSI.TriggerCatalog.CATEGORY_ORDER) do rank[c] = i end
    rank.SPEC = #NSI.TriggerCatalog.CATEGORY_ORDER + 1
    local prev
    for _, d in ipairs(Tr.All()) do
        if not moved[d.id] then gotIds[#gotIds + 1] = d.id end
        local key = ("%02d %s"):format(rank[d.category], d.name:lower())
        if prev then assertTrue(prev <= key, d.id .. " sorts after " .. prev) end
        prev = key
    end
    -- red under: modules/Triggers.lua's `before` comparing ids ahead of names
    assertEqual(table.concat(gotIds, ","), table.concat(wantIds, ","))
end)

-- Legacy offered a preset when `not presetScript.Class or presetScript.Class == PlayerClass`
-- (Outfitter.lua:2625, OutfitterScriptDialog.lua:423).
test("parity: a class row is offered to its own class only, as the legacy menu filtered it", function()
    local function has(list, id)
        for _, d in ipairs(list) do if d.id == id then return true end end
        return false
    end
    assertTrue(has(Tr.List("TRADE", "ROGUE"), "LOCKPICKING"))
    assertTrue(not has(Tr.List("TRADE", "DRUID"), "LOCKPICKING"))
    assertTrue(has(Tr.List("CLASS", "ROGUE"), "ROGUE_STEALTH"))
    assertTrue(not has(Tr.List("CLASS", "ROGUE"), "DRUID_BEAR"))
    assertTrue(has(Tr.List("SPEC", "DRUID"), "SPEC_4"))
end)
