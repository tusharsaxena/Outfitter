-- tests/test_item_stats.lua — P4.11 (design §5.14, B13, H15, H16): NS.Stats on C_Item.GetItemStats
-- and C_Item.GetDetailedItemLevelInfo, labeled from the client's own GlobalStrings so a deDE client
-- scores Versatility, Crit and item level (B13); the combined-primary alias lists (O20); the level
-- filter (a too-high item is dropped, a secret player level lets it through); the per-job score
-- cache; the Pawn and WeightsWatcher sources, guarded, installed at Resume and on ADDON_LOADED, never
-- twice, and absent without their addon (the built-in fallback, H16); and the dropped third-party
-- category surface: no GetNumStats/GetIndexedStat alias, no registration path outside the addon.
--
-- Nothing here calls into a module that has not landed: ItemStats reads only Compat, Secrets and the
-- bus, so the suite needs no fake (design §12).

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DB = T.fixtures.items.db

-- The deDE client's GlobalStrings for the nine stats (the client's own translations).
local DE = {
    ITEM_MOD_STAMINA_SHORT = "Ausdauer", ITEM_MOD_STRENGTH_SHORT = "Stärke",
    ITEM_MOD_INTELLECT_SHORT = "Intelligenz", ITEM_MOD_AGILITY_SHORT = "Beweglichkeit",
    ITEM_MOD_SPIRIT_SHORT = "Willenskraft", ITEM_MOD_HASTE_RATING_SHORT = "Tempo",
    ITEM_MOD_VERSATILITY = "Vielseitigkeit", ITEM_MOD_MASTERY_RATING_SHORT = "Meisterschaft",
    ITEM_MOD_CRIT_RATING_SHORT = "Kritischer Trefferwert",
}

local function deInstance(extra)
    return T.load({ mutate = function(M)
        M.GetLocale = function() return "deDE" end
        for k, v in pairs(DE) do M[k] = v end
        if extra then extra(M) end
    end })
end

-- An info as NS.ItemInfo hands it out, for fixture `key`.
local function info(NS, key)
    return NS.ItemInfo.FromLink(DB[key].link)
end

-- Which addons the client reports loaded: `set` = { Pawn = true, ... }; everything else is not.
local function loaded(M, set)
    M.C_AddOns.IsAddOnLoaded = function(name) return set[name] == true, set[name] == true end
end

-- Every NS.SendBus call from here on, as a list of message names (the catalog keeps no stats key).
local function sends(NS)
    local out, was = {}, NS.SendBus
    NS.SendBus = function(name, ...)
        out[#out + 1] = name
        return was(name, ...)
    end
    return out
end

-- Every NS.Stats.RegisterCategory call from here on, as a list of category ids.
local function registrations(NS)
    local out, was = {}, NS.Stats.RegisterCategory
    NS.Stats.RegisterCategory = function(cat)
        out[#out + 1] = cat and cat.id
        return was(cat)
    end
    return out
end

local function category(NS, id)
    for _, c in ipairs(NS.Stats.Categories()) do if c.id == id then return c end end
    return nil
end

local function statIDs(cat)
    local out = {}
    for _, s in ipairs(cat.stats()) do out[#out + 1] = s.id end
    return table.concat(out, ",")
end

local function readFile(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "r"))
    local text = f:read("*a")
    f:close()
    return (text:gsub("\r\n", "\n"))
end

-- ── the built-in stats (B13) ──────────────────────────────────────────────────────────────────

test("stats: the built-in category holds the nine stats, TOTAL_STATS and ITEM_LEVEL in order", function()
    -- red under: drop SPI from STAT_KEYS, or reorder the list
    local NS = T.load().NS
    local cat = category(NS, "Stat")
    assertTrue(cat ~= nil, "no built-in category")
    assertEqual(statIDs(cat), "STA,STR,INT,AGI,SPI,HAS,VER,MAS,CRI,TOTAL_STATS,ITEM_LEVEL")
    assertEqual(NS.Stats.Get("TOTAL_STATS").label, NS.L["Total stats"])
    assertEqual(NS.Stats.Get("ITEM_LEVEL").label, NS.L["Item level"])
    assertEqual(cat.label, NS.L["Base stats"])
    assertNil(NS.Stats.Get("FISHING"), "the Fishing stat is retired (INV §18)")
end)

test("stats: labels are the client's GlobalStrings, so a deDE client reads its own names (B13)", function()
    -- red under: hard-code an English label ("Versatility") for VER instead of _G[key]
    local NS = deInstance().NS
    assertEqual(NS.Stats.Get("STA").label, "Ausdauer")
    assertEqual(NS.Stats.Get("VER").label, "Vielseitigkeit")
    assertEqual(NS.Stats.Get("CRI").label, "Kritischer Trefferwert")
    assertEqual(NS.Stats.ConfigName({ { stat = "VER" }, { stat = "CRI" } }), "Vielseitigkeit, Kritischer Trefferwert")
end)

test("stats: a deDE client scores VER, CRI, MAS, HAS and ITEM_LEVEL from the stat tokens (B13)", function()
    -- red under: read VER through an English stat name rather than ITEM_MOD_VERSATILITY
    local NS = deInstance().NS
    local S = NS.Stats
    assertEqual(S.Get("VER"):Score(info(NS, "ring_plain_b")), 500)
    assertEqual(S.Get("MAS"):Score(info(NS, "ring_plain_a")), 500)
    assertEqual(S.Get("CRI"):Score(info(NS, "head_plate")), 210)
    assertEqual(S.Get("HAS"):Score(info(NS, "neck_chain")), 600)
    assertEqual(S.Get("ITEM_LEVEL"):Score(info(NS, "head_plate")), DB.head_plate.level)
    assertEqual(S.Get("STR"):Score(info(NS, "neck_chain")), 0, "a stat the item lacks scores 0")
end)

test("stats: ItemStats maps the tokens, TOTAL_STATS sums the nine, ITEM_LEVEL is the detailed level", function()
    -- red under: leave CRI out of the TOTAL_STATS sum
    local NS = T.load().NS
    local s = NS.Stats.ItemStats(DB.head_plate.link)
    assertEqual(s.values.STA, 900)
    assertEqual(s.values.STR, 520)
    assertEqual(s.values.CRI, 210)
    assertEqual(s.values.TOTAL_STATS, 900 + 520 + 210)
    assertEqual(s.values.ITEM_LEVEL, DB.head_plate.level)
    assertNil(NS.Stats.ItemStats(nil), "no link, no stats")
end)

test("stats: an item the client has no stats for yet scores 0 and keeps its item level", function()
    -- legacy: 0 (statsForLink always answered an object, and the score was `or 0`;
    -- MC2ItemStatsLib.lua:57-61, OutfitterItemStats.lua:148); kept: still a candidate, not dropped.
    -- red under: Stats.ItemStats answering nil when Compat.ItemStats does (the item drops out).
    local inst = T.load()
    local NS = inst.NS
    inst.mocks.C_Item.GetItemStats = function() return nil end
    local s = NS.Stats.ItemStats(DB.head_plate.link)
    assertTrue(s ~= nil, "no stats object")
    assertEqual(s.values.ITEM_LEVEL, DB.head_plate.level, "the level is read on its own")
    assertEqual(s.values.TOTAL_STATS, 0)
    assertEqual(NS.Stats.Get("STA"):Score(info(NS, "head_plate")), 0, "scores 0, not nil")
    assertEqual(NS.Stats.Get("ITEM_LEVEL"):Score(info(NS, "head_plate")), DB.head_plate.level)
end)

test("stats: the built-in category's label is the client's PLAYERSTAT_BASE_STATS", function()
    -- red under: labeling the category with L["Base stats"] alone (a deDE client reads English)
    local NS = deInstance(function(M) M.PLAYERSTAT_BASE_STATS = "Grundwerte" end).NS
    assertEqual(category(NS, "Stat").label, "Grundwerte")
end)

test("stats: a combined primary key scores for each primary it names, and counts once in the total (O20)", function()
    -- red under: drop the alias lists (STR, AGI and INT then read 0 on adaptive gear)
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local link = DB.chest_plate.link
    M.C_Item.GetItemStats = function()
        return { ITEM_MOD_STRENGTH_AGILITY_INTELLECT_SHORT = 800, ITEM_MOD_STAMINA_SHORT = 1000 }
    end
    local v = NS.Stats.ItemStats(link).values
    assertEqual(v.STR, 800)
    assertEqual(v.AGI, 800)
    assertEqual(v.INT, 800)
    assertEqual(v.TOTAL_STATS, 1800, "the combined key is one stat line, summed once")
end)

test("stats: a secret link is unreadable, so it has no stats and no score", function()
    -- red under: drop both the link's PlainString in Stats.ItemStats and Compat.ItemStats' sealed
    -- check (the secret then reaches a GetItemStats that answers anything)
    local inst = T.load()
    local NS = inst.NS
    inst.mocks.C_Item.GetItemStats = function() return { ITEM_MOD_STAMINA_SHORT = 1 } end
    assertNil(NS.Stats.ItemStats(T.secret(DB.head_plate.link)))
    assertNil(NS.Stats.Get("STA"):Score({ link = T.secret(DB.head_plate.link) }))
end)

-- ── the level filter ──────────────────────────────────────────────────────────────────────────

test("stats: an item above the player's level is dropped (nil); at the level it scores", function()
    -- red under: drop the minLevel comparison from the scorer
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    M.UnitLevel = function() return 80 end
    local helm = info(NS, "unusable_helm")   -- minLevel 90
    assertNil(NS.Stats.Get("STA"):Score(helm), "a level-90 item scored at level 80")
    M.UnitLevel = function() return 90 end
    assertEqual(NS.Stats.Get("STA"):Score(info(NS, "unusable_helm")), 0)
end)

test("stats: a secret player level lets the item through (INV §3.6)", function()
    -- red under: treat an unreadable level as 0 (every item with a minLevel is dropped)
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    M.UnitLevel = function() return T.secret(80) end
    assertEqual(NS.Stats.Get("STA"):Score(info(NS, "unusable_helm")), 0)
    assertEqual(NS.Stats.Get("STA"):Score(info(NS, "head_plate")), 900)
end)

-- ── scores, outfits and the cache ─────────────────────────────────────────────────────────────

test("stats: Score is cached per job on a weak table; without a job nothing is kept", function()
    -- red under: skip the cache (GetItemStats is asked again for the second score)
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local calls, real = 0, M.C_Item.GetItemStats
    M.C_Item.GetItemStats = function(...) calls = calls + 1; return real(...) end
    local job, helm, sta = {}, info(NS, "head_plate"), NS.Stats.Get("STA")
    assertEqual(sta:Score(helm, job), 900)
    assertEqual(sta:Score(helm, job), 900)
    assertEqual(calls, 1, "the second score in one job read the client again")
    assertEqual(getmetatable(job.scores).__mode, "k", "the job's score cache is not weak-keyed")
    sta:Score(helm)
    sta:Score(helm)
    assertEqual(calls, 3, "a jobless score was cached")
end)

test("stats: ConfigName joins the labels, and answers nil when any stat is missing", function()
    -- red under: skip the unknown stat instead of answering nil
    local NS = T.load().NS
    local sta, mas = NS.Stats.Get("STA").label, NS.Stats.Get("MAS").label
    assertEqual(NS.Stats.ConfigName({ { stat = "STA" }, { stat = "MAS" } }), sta .. ", " .. mas)
    assertNil(NS.Stats.ConfigName({ { stat = "STA" }, { stat = "Pawn_Gone" } }))
    assertNil(NS.Stats.ConfigName(nil))
end)

-- ── registration ──────────────────────────────────────────────────────────────────────────────

test("stats: RegisterCategory adds a category and sends nothing on the bus; a built-in is never replaced", function()
    -- red under: let a category with the built-in's id overwrite it, or a NS.SendBus put back in
    -- RegisterCategory (no receiver: the Rebuild dialog reads Categories() when it opens).
    local NS = T.load().NS
    local got = sends(NS)
    local stat = NS.Stats.NewStat("X_ONE", "One", function() return 7 end)
    assertTrue(NS.Stats.RegisterCategory({ id = "X", label = "X", stats = function() return { stat } end }))
    assertEqual(NS.Stats.Get("X_ONE"):Score(info(NS, "head_plate")), 7)
    assertFalse(NS.Stats.RegisterCategory({ id = "Stat", label = "Mine", stats = function() return {} end }))
    assertEqual(category(NS, "Stat").label, NS.L["Base stats"], "the built-in category was replaced")
    assertEqual(table.concat(got, ","), "", "RegisterCategory sent a bus message")
end)

-- ── Pawn and WeightsWatcher (H16) ─────────────────────────────────────────────────────────────

-- Pawn's globals with two visible scales and one hidden; `values[link][scale]` its scores.
local function installPawn(M, values)
    M.PawnGetAllScales = function() return { "Tank", "Hidden", "Dps" } end
    M.PawnIsScaleVisible = function(name) return name ~= "Hidden" end
    M.PawnGetItemData = function(link)
        local out = { Values = {} }
        for scale, v in pairs(values[link] or {}) do out.Values[#out.Values + 1] = { scale, v, v } end
        return out
    end
end

test("sources: without Pawn or WeightsWatcher only the built-in category exists (fallback, H16)", function()
    -- red under: install a source without asking Compat.IsAddOnLoaded
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    loaded(M, {})
    NS.Stats.Resume()
    assertEqual(#NS.Stats.Categories(), 1)
    assertTrue(category(NS, "Stat") ~= nil)
end)

test("sources: Pawn loaded at Resume adds one stat per visible scale; a missing value scores 0", function()
    -- red under: list Pawn's hidden scales too
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    loaded(M, { Pawn = true })
    installPawn(M, { [DB.head_plate.link] = { Tank = 41.5 } })
    NS.Stats.Resume()
    local cat = category(NS, "Pawn")
    assertTrue(cat ~= nil, "no Pawn category")
    assertEqual(statIDs(cat), "Pawn_Dps,Pawn_Tank")
    assertEqual(NS.Stats.Get("Pawn_Tank"):Score(info(NS, "head_plate")), 41.5)
    assertEqual(NS.Stats.Get("Pawn_Dps"):Score(info(NS, "head_plate")), 0, "nil scores 0")
    assertTrue(NS.Stats.Get("Pawn_Tank") == NS.Stats.Get("Pawn_Tank"), "a scale's stat is not stable")
end)

test("sources: a raising Pawn scores 0 and breaks nothing (guarded)", function()
    -- red under: call PawnGetItemData unprotected (the raise escapes Score)
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    loaded(M, { Pawn = true })
    installPawn(M, {})
    NS.Stats.Resume()
    M.PawnGetItemData = function() error("Pawn exploded") end
    assertEqual(NS.Stats.Get("Pawn_Tank"):Score(info(NS, "head_plate")), 0)
end)

test("sources: Pawn loading later is caught by the ADDON_LOADED re-check, once", function()
    -- red under: drop the installed[name] guard (a second ADDON_LOADED adds Pawn twice)
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    loaded(M, {})
    NS.Stats.Resume()
    local got = registrations(NS)
    loaded(M, { Pawn = true })
    installPawn(M, {})
    M.__fire("ADDON_LOADED", "SomethingElse")
    assertNil(category(NS, "Pawn"), "an unrelated ADDON_LOADED installed Pawn")
    M.__fire("ADDON_LOADED", "Pawn")
    assertTrue(category(NS, "Pawn") ~= nil, "the re-check missed Pawn")
    M.__fire("ADDON_LOADED", "Pawn")
    NS.Stats.Resume()
    local n = 0
    for _, c in ipairs(NS.Stats.Categories()) do if c.id == "Pawn" then n = n + 1 end end
    assertEqual(n, 1)
    assertEqual(table.concat(got, ","), "Pawn", "Pawn registered more than once")
end)

test("sources: WeightsWatcher's active weights for the player's class score from its cache", function()
    -- red under: read another class's active weights
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    loaded(M, { WeightsWatcher = true })
    local token = NS.Compat.PlayerClass()
    M.ww_vars = { weightsList = { [token] = { Melee = {}, Caster = {} } } }
    M.ww_charVars = { activeWeights = { [token] = { "Melee" }, OTHER = { "Caster" } } }
    M.ww_weightCache = { [token] = { Melee = { [DB.head_plate.link] = 123 } } }
    NS.Stats.Resume()
    assertEqual(statIDs(category(NS, "WW")), "WW_Melee")
    assertEqual(NS.Stats.Get("WW_Melee"):Score(info(NS, "head_plate")), 123)
    assertEqual(NS.Stats.Get("WW_Melee"):Score(info(NS, "neck_chain")), 0, "an uncached item scores 0")
end)

test("sources: WeightsWatcher without its tables lists no stats and raises nothing", function()
    -- red under: index ww_vars without the guard (nil ww_vars raises)
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    loaded(M, { WeightsWatcher = true })
    NS.Stats.Resume()
    assertEqual(statIDs(category(NS, "WW")), "")
    M.ww_vars = { weightsList = {} }
    assertEqual(statIDs(category(NS, "WW")), "")
end)

test("sources: Suspend drops the ADDON_LOADED watch; Resume brings it back", function()
    -- red under: leave the watch registered across Suspend
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    loaded(M, {})
    local function watching()
        for _, r in ipairs(M.__registrations()) do if r.event == "ADDON_LOADED" and r.kind == "event"
            and r.target ~= NS.addon then return true end end
        return false
    end
    NS.Stats.Resume()
    assertTrue(watching(), "Resume registered no watch")
    NS.Stats.Suspend()
    assertFalse(watching(), "Suspend left the watch")
    loaded(M, { Pawn = true })
    installPawn(M, {})
    M.__fire("ADDON_LOADED", "Pawn")
    assertNil(category(NS, "Pawn"), "Pawn installed while suspended")
    NS.Stats.Resume()
    assertTrue(watching())
    assertTrue(category(NS, "Pawn") ~= nil, "Resume did not re-run Install")
end)

-- ── the dropped surface (§5.14, §5.16) ────────────────────────────────────────────────────────

test("stats: no GetNumStats/GetIndexedStat alias and no StatCategories table survive", function()
    -- red under: give a category a GetNumStats method for third-party compatibility
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    loaded(M, { Pawn = true, WeightsWatcher = true })
    NS.Stats.Resume()
    for _, c in ipairs(NS.Stats.Categories()) do
        assertNil(c.GetNumStats, c.id .. ".GetNumStats")
        assertNil(c.GetIndexedStat, c.id .. ".GetIndexedStat")
    end
    assertNil(NS.Stats.StatCategories)
    for _, rel in ipairs({ "modules/ItemStats.lua", "modules/ItemStats_Sources.lua" }) do
        local text = readFile(rel)
        assertFalse(text:find("GetNumStats", 1, true) ~= nil, rel .. " names GetNumStats")
        assertFalse(text:find("GetIndexedStat", 1, true) ~= nil, rel .. " names GetIndexedStat")
    end
end)

test("stats: RegisterCategory is reachable from inside the addon only", function()
    -- red under: publish RegisterCategory on the public API table or a global
    local inst = T.load()
    local api = inst.mocks._G.OutfitterReborn
    local v1 = type(api) == "table" and type(api.API) == "table" and api.API.v1 or {}
    for k in pairs(v1) do assertFalse(tostring(k):find("Categor", 1, true) ~= nil, "API.v1." .. tostring(k)) end
    assertNil(rawget(_G, "Outfitter"), "the Outfitter global is back")
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") and not rel:match("^libs/") and not rel:match("^modules/ItemStats") then
            assertFalse(readFile(rel):find("RegisterCategory", 1, true) ~= nil, rel .. " calls RegisterCategory")
        end
    end
end)
