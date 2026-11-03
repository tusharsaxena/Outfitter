-- tests/test_list_model.lua — P4.19 (design §7.3, INV §7.2): modules/Window_ListModel.lua, the pure
-- model the outfit list renders from. Section order, both sorts, nil names last, the EM tiebreak,
-- collapse and the status cache.
--
-- The model reads NS.Outfits and NS.Inventory only; both are replaced for the case by recorded
-- fakes over a small table, so the order under test is the model's and nothing else's.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

-- A store of { id = { name, kind, category } } and item sections, faked as Outfits and Inventory.
local function model(outfits, sections)
    local NS = T.load().NS
    local order = { Complete = {}, Accessory = {} }
    for _, row in ipairs(outfits) do
        local list = order[row.category or "Complete"]
        list[#list + 1] = row.id
    end
    local byId = {}
    for _, row in ipairs(outfits) do byId[row.id] = { name = row.name, kind = row.kind or "native" } end
    local statusCalls = 0
    T.fake(NS, "Outfits", {
        Categories = function() return { "Complete", "Accessory" } end,
        Ids = function(cat)
            local out = {}
            for i, id in ipairs(order[cat] or {}) do out[i] = id end
            return out
        end,
        Get = function(id) return byId[id] end,
        Status = function()
            statusCalls = statusCalls + 1
            return "normal"
        end,
    })
    T.fake(NS, "Inventory", { ItemSections = function() return sections or {} end })
    return NS, NS.WindowListModel, function() return statusCalls end
end

-- The entries as "kind:id" (an item as "item:<its name>"), joined.
local function shape(entries)
    local out = {}
    for _, e in ipairs(entries) do
        out[#out + 1] = e.kind .. ":" .. (e.kind == "item" and tostring(e.item.name) or tostring(e.id))
    end
    return table.concat(out, ",")
end

test("list model: NS.WindowListModel is published with Build, Status and the outfit compare", function()
    local LM = T.NS.WindowListModel
    assertEqual(type(LM), "table")
    for _, k in ipairs({ "Build", "Status", "SortedIds", "CompareOutfits" }) do
        assertEqual(type(LM[k]), "function", k)
    end
end)

test("list model: the sections run Complete, Accessory, then the item sections in Inventory's order", function()
    local _, LM = model({
        { id = "o1", name = "Hat", category = "Accessory" },
        { id = "o2", name = "Normal" },
    }, {
        { key = "unused", labelKey = "Odds 'n ends", items = { { name = "Ring" } } },
        { key = "warbound", labelKey = "Warbound until equipped", items = { { name = "Cloak" } } },
        { key = "boe", labelKey = "Unopened", items = { { name = "Belt" } } },
    })
    local entries = LM.Build({}, {})
    -- red under: build the item sections ahead of the outfit categories in Build.
    assertEqual(shape(entries), "category:Complete,outfit:o2,category:Accessory,outfit:o1,"
        .. "category:unused,item:Ring,category:warbound,item:Cloak,category:boe,item:Belt")
    assertEqual(entries[1].depth, 0); assertEqual(entries[2].depth, 1)
    assertEqual(entries[1].label, "Complete outfits")
    assertEqual(entries[3].label, "Accessories")
    assertEqual(entries[5].label, "Odds 'n ends")
    assertEqual(entries[7].label, "Warbound until equipped")
    assertEqual(entries[9].label, "Unopened")
    assertTrue(type(entries[1].desc) == "string" and #entries[1].desc > 0, "a category carries its description")
end)

test("list model: an outfit category with no outfits still shows its header", function()
    local _, LM = model({}, {})
    assertEqual(shape(LM.Build({}, {})), "category:Complete,category:Accessory")
end)

test("list model: outfits sort by name, nil names last, the EM copy first on a tie", function()
    local _, LM = model({
        { id = "o1", name = "Zeta" },
        { id = "o2", name = nil },
        { id = "o3", name = "Alpha" },
        { id = "o4", name = "Mid" },
        { id = "o5", name = "Mid", kind = "em" },
    })
    -- red under: make CompareOutfits answer `false` when a.name is nil and b.name is not (nil first).
    -- red under: drop the EM tiebreak (the store order o4, o5 stands).
    assertEqual(table.concat(LM.SortedIds("Complete"), ","), "o3,o5,o4,o1,o2")
end)

test("list model: the items keep Inventory's level-then-name order inside each section", function()
    -- ItemSections sorts with NS.Inventory.CompareItems (design §5.5); the model never re-sorts.
    local _, LM = model({}, {
        { key = "unused", items = { { name = "B", level = 400 }, { name = "A", level = 300 } } },
    })
    assertEqual(shape(LM.Build({}, {})), "category:Complete,category:Accessory,category:unused,item:B,item:A")
end)

test("list model: a collapsed category keeps its header and drops its rows", function()
    local _, LM = model({
        { id = "o1", name = "Normal" },
        { id = "o2", name = "Hat", category = "Accessory" },
    }, { { key = "unused", items = { { name = "Ring" } } } })
    local entries = LM.Build({ Complete = true, unused = true }, {})
    -- red under: skip the `collapsed[cat]` test in Build (the rows stay).
    assertEqual(shape(entries), "category:Complete,category:Accessory,outfit:o2,category:unused")
    assertTrue(entries[1].collapsed, "the collapsed header says so")
    assertNil(entries[2].collapsed, "an open header is not marked")
end)

test("list model: Status caches O.Status in the table it is handed, until that is wiped", function()
    local _, LM, calls = model({ { id = "o1", name = "Normal" } })
    local cache = {}
    assertEqual(LM.Status("o1", cache), "normal")
    assertEqual(LM.Status("o1", cache), "normal")
    -- red under: read O.Status on every call (no cache write).
    assertEqual(calls(), 1)
    local entries = LM.Build({}, cache)
    assertEqual(entries[2].status, "normal")
    assertEqual(calls(), 1, "Build reads through the same cache")
    LM.Build({}, {})
    assertEqual(calls(), 2, "a fresh cache reads again")
end)
