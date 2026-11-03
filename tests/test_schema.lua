-- tests/test_schema.lua — the settings rows, the single write seam, its forward to the outfit instance,
-- and the reset's reach (architecture-§5, design §3.5). P3 C12 pins the seam and the Master rows;
-- P4.6 adds the outfit rows and P4.23 the rest of the profile rows (design §9.3).

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

--- `parts` read out of `root` from index `first`.
local function read(root, path, first)
    local node = root
    local i = 0
    for seg in path:gmatch("[^%.]+") do
        i = i + 1
        if i >= first then
            if type(node) ~= "table" then return nil end
            node = node[seg]
        end
    end
    return node
end

test("schema: the load-time shape check finds no error and every stored path resolves", function()
    local errors, _, missing = NS.ValidateSchema()
    assertEqual(errors, 0)
    assertEqual(missing, 0)
end)

test("schema: the settings pages are general, bar and profiles", function()
    local keys = {}
    for k in pairs(NS.VALID_PAGES) do keys[#keys + 1] = k end
    table.sort(keys)
    assertEqual(table.concat(keys, ","), "bar,general,profiles")
    for _, row in ipairs(NS.Schema.AllRows()) do
        assertTrue(NS.VALID_PAGES[row.page] == true, tostring(row.path) .. " is on page " .. tostring(row.page))
        assertEqual(type(row.group), "string", tostring(row.path))
        assertEqual(type(row.label), "string", tostring(row.path))
    end
end)

test("schema: every stored row's default is the one in defaults/Profile.lua", function()
    -- savedvariables-§2: the defaults tree is the only place a default is written down. The session
    -- rows and the Minimap row (LibDBIcon's inverted `hide`) store nothing under their own path.
    local checked = 0
    for _, row in ipairs(NS.Schema.AllRows()) do
        if not row.sessionOnly and row.path ~= NS.MINIMAP_PATH and type(row.set) ~= "function" then
            local global = row.path:find("^global%.") ~= nil
            local want = global and read(NS.defaults.global, row.path, 2) or read(NS.defaults.profile, row.path, 1)
            assertTrue(want ~= nil, row.path .. " resolves in no defaults tree")
            assertEqual(row.default, want, row.path)
            checked = checked + 1
        end
    end
    assertTrue(checked >= 5, "only " .. checked .. " stored rows were checked")
end)

test("schema: Master controls carries every canonical row, in order, labeled with the brand", function()
    local paths = {}
    for _, row in ipairs(NS.SchemaForPage("general")) do
        if row.group == NS.Helpers.MASTER_GROUP then paths[#paths + 1] = row.path end
    end
    assertEqual(table.concat(paths, ","),
        "enabled,visibility,scale,alpha,locked,state.debugConsole,global.minimap.shown,state.testMode")
    assertEqual(NS.FindSchemaRow("enabled").label, "Enable Ka0s Outfitter Reborn")
    assertEqual(NS.FindSchemaRow("state.testMode").default, false, "the host stamps Test mode's default")
end)

test("schema: NS.Schema is the rows array, and its runtime members are no rows", function()
    -- `ipairs` and `#` see rows only; AllRows, FindRow and SetMany come from the metatable.
    assertEqual(#NS.Schema, #NS.Schema.AllRows())
    assertTrue(rawequal(NS.Schema.AllRows(), NS.Schema), "AllRows answers the array itself")
    for k in pairs(NS.Schema) do assertEqual(type(k), "number", "a non-row key on the array: " .. tostring(k)) end
    assertTrue(NS.Schema.FindRow("enabled") == NS.FindSchemaRow("enabled"))
end)

test("schema: no instance row is on the settings instance, so no list, page or reset can show one", function()
    -- design §3.5 / O12: outfit rows live on NS.OutfitSchema, never here.
    for _, row in ipairs(NS.Schema.AllRows()) do
        assertFalse(row.path:find("^outfit%.") ~= nil, row.path)
        assertFalse(row.path:find("^trigger%.") ~= nil, row.path)
        assertTrue(row.page ~= "outfit", row.path)
    end
end)

test("schema: a write goes through the seam, reacts, and announces SETTINGS_CHANGED once", function()
    local inst = T.load()
    local seen = {}
    inst.NS.NewBusTarget():RegisterMessage(inst.NS.MSG.SETTINGS_CHANGED, function(_, path, value)
        seen[#seen + 1] = { path, value }
    end)
    assertTrue(inst.NS.SetByPath("visibility", "never"))
    assertEqual(inst.NS.db.profile.visibility, "never")
    assertEqual(#seen, 1)
    assertEqual(seen[1][1], "visibility")
    assertEqual(seen[1][2], "never")
end)

test("schema: a session row stores nothing and announces nothing", function()
    local inst = T.load()
    local seen = 0
    inst.NS.NewBusTarget():RegisterMessage(inst.NS.MSG.SETTINGS_CHANGED, function() seen = seen + 1 end)
    assertTrue(inst.NS.SetByPath("state.testMode", false))
    assertEqual(inst.NS.db.profile.state, nil)
    assertEqual(seen, 0)
end)

test("schema: an unknown path is refused and stores nothing", function()
    local inst = T.load()
    assertFalse(inst.NS.SetByPath("no.such.path", 3))
    assertEqual(inst.NS.db.profile.no, nil)
end)

test("schema: the Minimap row reads SHOWN and stores LibDBIcon's inverted `hide`", function()
    local inst = T.load()
    local NSi = inst.NS
    assertEqual(NSi.GetSetting(NSi.MINIMAP_PATH), true)
    assertTrue(NSi.SetByPath(NSi.MINIMAP_PATH, false))
    assertEqual(NSi.db.global.minimap.hide, true)
    assertEqual(NSi.db.global.minimap.shown, nil, "no `shown` twin is ever stored")
    assertEqual(NSi.GetSetting(NSi.MINIMAP_PATH), false)
end)

test("schema: Reset all settings resets the profile and never touches the Minimap button or db.char", function()
    -- H7: the active profile only; outfits are per character and survive.
    local inst = T.load()
    local NSi = inst.NS
    NSi.SetByPath("visibility", "never")
    NSi.SetByPath(NSi.MINIMAP_PATH, false)
    NSi.db.char.outfits.o1 = { id = "o1", name = "Kept" }
    NSi.Helpers.RestoreAllDefaults()
    assertEqual(NSi.GetSetting("visibility"), "always")
    assertEqual(NSi.db.global.minimap.hide, true, "the minimap button stayed hidden")
    assertEqual(NSi.db.char.outfits.o1.name, "Kept", "an outfit survived the reset")
end)

-- ── the forward to the outfit instance (design §3.5) ─────────────────────────────────────────────

test("schema: an instance id with no outfit schema answers false, \"no outfit schema\" and stores nothing", function()
    -- modules/Outfits_Schema.lua lands in P4.6; until it builds NS.OutfitSchema every addressed call
    -- refuses rather than falling through to the settings rows.
    local inst = T.load()
    local NSi = inst.NS
    assertEqual(NSi.OutfitSchema, nil)
    local ok, err = NSi.SetByPath("outfit.icon", 134400, "o1")
    assertFalse(ok); assertEqual(err, "no outfit schema")
    ok, err = NSi.Schema.SetMany({ { path = "outfit.icon", value = 1 } }, { instanceId = "o1" })
    assertFalse(ok); assertEqual(err, "no outfit schema")
    local v, why = NSi.GetSetting("outfit.icon", "o1")
    assertEqual(v, nil); assertEqual(why, "no outfit schema")
    -- And a nil id is still a settings write: the same path is unknown here.
    assertFalse(NSi.SetByPath("outfit.icon", 134400))
end)

test("schema: a non-nil instance id forwards Set, Get and SetMany to NS.OutfitSchema", function()
    local inst = T.load()
    local NSi = inst.NS
    local calls = {}
    NSi.OutfitSchema = {
        Set     = function(path, value, id) calls[#calls + 1] = { "Set", path, value, id } return true end,
        Get     = function(path, id) calls[#calls + 1] = { "Get", path, id } return 42 end,
        SetMany = function(entries, opts) calls[#calls + 1] = { "SetMany", #entries, opts.instanceId } return true end,
    }
    assertTrue(NSi.SetByPath("trigger.IN_DUNGEON.enableArena", true, "o7"))
    assertEqual(NSi.GetSetting("outfit.icon", "o7"), 42)
    assertTrue(NSi.Schema.SetMany({ { path = "outfit.icon", value = 1 }, { path = "outfit.bar.hide", value = true } },
        { instanceId = "o7" }))
    assertEqual(#calls, 3)
    assertEqual(table.concat(calls[1], "|", 1, 2) .. "|" .. tostring(calls[1][3]) .. "|" .. calls[1][4],
        "Set|trigger.IN_DUNGEON.enableArena|true|o7")
    assertEqual(calls[2][1] .. "|" .. calls[2][2] .. "|" .. calls[2][3], "Get|outfit.icon|o7")
    assertEqual(calls[3][1] .. "|" .. calls[3][2] .. "|" .. calls[3][3], "SetMany|2|o7")
    -- A nil id never reaches the outfit instance.
    assertTrue(NSi.SetByPath("visibility", "never"))
    assertEqual(NSi.GetSetting("visibility"), "never")
    assertEqual(#calls, 3, "a settings write was forwarded")
end)

test("schema: SetMany with no instance id is the settings instance's, all or nothing", function()
    local inst = T.load()
    local NSi = inst.NS
    assertFalse(NSi.Schema.SetMany({ { path = "visibility", value = "never" }, { path = "no.such", value = 1 } }))
    assertEqual(NSi.GetSetting("visibility"), "always", "a refused batch stored its first entry")
    assertTrue(NSi.Schema.SetMany({ { path = "visibility", value = "never" }, { path = "locked", value = true } }))
    assertEqual(NSi.db.profile.visibility, "never")
    assertEqual(NSi.db.profile.locked, true)
end)

test("schema: library absent, the seam still stores, forwards and refuses alike", function()
    local inst = T.load{ libFiles = {} }
    local NSi = inst.NS
    assertTrue(NSi.SetByPath("enabled", false), "the written-through switch landed")
    assertEqual(NSi.db.profile.enabled, false)
    local ok, err = NSi.SetByPath("outfit.icon", 1, "o1")
    assertFalse(ok); assertEqual(err, "no outfit schema")
    assertFalse(NSi.Schema.SetMany({ { path = "enabled", value = true }, { path = "no.such", value = 1 } }))
    assertEqual(NSi.db.profile.enabled, false, "the degraded batch is all or nothing too")
end)
