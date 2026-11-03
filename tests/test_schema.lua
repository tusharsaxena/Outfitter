-- tests/test_schema.lua — the settings rows, the single write seam, its forward to the outfit instance,
-- and the reset's reach (architecture-§5, design §3.5). P3 C12 pins the seam and the Master rows;
-- P4.6 adds the outfit rows and P4.23 the rest of the profile rows (design §9.3).

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

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
    -- modules/Outfits_Schema.lua builds NS.OutfitSchema at OnInitialize (P4.6); without it every
    -- addressed call refuses rather than falling through to the settings rows.
    local inst = T.load()
    local NSi = inst.NS
    NSi.OutfitSchema = nil
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
    -- The outfit instance is built on the same degradation stub: an unknown id is refused, a known
    -- one lands in the record (P4.6).
    assertEqual(type(NSi.OutfitSchema), "table", "the degraded load builds the outfit instance")
    assertFalse((NSi.SetByPath("outfit.icon", 1, "o1")))
    NSi.db.char.outfits.o1 = { id = "o1", name = "Kept", kind = "native", items = {} }
    assertTrue(NSi.SetByPath("outfit.icon", 136245, "o1"))
    assertEqual(NSi.db.char.outfits.o1.icon, 136245)
    assertFalse(NSi.Schema.SetMany({ { path = "enabled", value = true }, { path = "no.such", value = 1 } }))
    assertEqual(NSi.db.profile.enabled, false, "the degraded batch is all or nothing too")
end)

-- ── the outfit instance (P4.6, design §3.5) ──────────────────────────────────────────────────────

-- The five outfit rows every later NS.SetByPath("outfit.*", v, id) writes through.
local OUTFIT_ROWS = { "outfit.trigger.id", "outfit.trigger.disabled", "outfit.trigger.combatDisabled",
                      "outfit.icon", "outfit.bar.hide" }

--- A fresh instance with one native outfit, and a fake trigger catalog that knows FISHING only.
local function outfitScene()
    local inst = T.load()
    local NSi = inst.NS
    T.fake(NSi, "Triggers", { Get = function(tid) if tid == "FISHING" then return { id = tid } end end })
    local id = NSi.Outfits.Create("Fishing", {})
    return inst, NSi, id
end

test("schema: the outfit instance holds the five outfit rows, each on page outfit in group outfit", function()
    local O = T.NS.OutfitSchema
    for _, path in ipairs(OUTFIT_ROWS) do
        local row = O.FindRow(path)
        assertTrue(row ~= nil, path .. " has a row")
        assertEqual(row.page, "outfit", path)
        assertEqual(row.group, "outfit", path)
        assertTrue(T.NS.Schema.FindRow(path) == nil, path .. " is not on the settings instance")
    end
    assertEqual(#O.AllRows(), #OUTFIT_ROWS, "no trigger rows until NS.Triggers.Finalize (P4.15)")
end)

test("schema: the outfit instance's shape check is clean against { outfit = true } and the instance types", function()
    -- red under: an outfit row with no `group` (anti-patterns #69), or with page "general".
    local errors = T.NS.ValidateOutfitSchema()
    assertEqual(errors, 0)
end)

test("schema: an outfit write lands in the record and announces OUTFIT_EDITED, never SETTINGS_CHANGED", function()
    local _, NSi, id = outfitScene()
    local edited, settings = {}, 0
    local bus = NSi.NewBusTarget()
    bus:RegisterMessage(NSi.MSG.OUTFIT_EDITED, function(_, oid, what) edited[#edited + 1] = oid .. ":" .. what end)
    bus:RegisterMessage(NSi.MSG.SETTINGS_CHANGED, function() settings = settings + 1 end)
    assertTrue(NSi.SetByPath("outfit.icon", 136245, id))
    assertTrue(NSi.SetByPath("outfit.bar.hide", true, id))
    assertTrue(NSi.SetByPath("outfit.trigger.id", "FISHING", id))
    assertTrue(NSi.SetByPath("outfit.trigger.combatDisabled", true, id))
    local rec = NSi.Outfits.Get(id)
    assertEqual(rec.icon, 136245); assertTrue(rec.bar.hide)
    assertEqual(rec.trigger.id, "FISHING"); assertTrue(rec.trigger.combatDisabled)
    assertEqual(NSi.GetSetting("outfit.trigger.id", id), "FISHING")
    assertEqual(table.concat(edited, ","), id .. ":icon," .. id .. ":bar," .. id .. ":trigger," .. id .. ":trigger")
    -- red under: the outfit announce calling NS.AnnounceSettingsChanged (design §3.5, C12).
    assertEqual(settings, 0)
end)

test("schema: the outfit rows refuse an unknown trigger, a bad icon, a nil id and an unknown id", function()
    local _, NSi, id = outfitScene()
    assertFalse((NSi.SetByPath("outfit.trigger.id", "NO_SUCH", id)), "an unknown trigger id")
    assertFalse((NSi.SetByPath("outfit.icon", -3, id)), "a non-positive icon")
    assertFalse((NSi.SetByPath("outfit.icon", "x", id)))
    assertFalse((NSi.SetByPath("outfit.bar.hide", "yes", id)), "a bool row takes a bool")
    assertFalse((NSi.SetByPath("outfit.icon", 1, "o99")), "an unknown outfit")
    assertFalse((NSi.OutfitSchema.Set("outfit.icon", 1, nil)), "a nil id never reaches an outfit")
    assertEqual(NSi.Outfits.Get(id).icon, nil)
end)

test("schema: the wildcard icon 134400 and an empty trigger id store as absent (INV §7.6)", function()
    local _, NSi, id = outfitScene()
    assertTrue(NSi.SetByPath("outfit.icon", 136245, id))
    assertTrue(NSi.SetByPath("outfit.icon", 134400, id))
    -- red under: the icon row's onChange not clearing the wildcard (134400 stored).
    assertNil(NSi.Outfits.Get(id).icon)
    assertTrue(NSi.SetByPath("outfit.trigger.id", "FISHING", id))
    assertTrue(NSi.SetByPath("outfit.trigger.id", "", id))
    assertNil(NSi.Outfits.Get(id).trigger, "no trigger is no trigger table")
end)

test("schema: an outfit batch is all or nothing and forwards through NS.Schema.SetMany", function()
    local _, NSi, id = outfitScene()
    local ok = NSi.Schema.SetMany({ { path = "outfit.trigger.id", value = "FISHING" },
                                    { path = "outfit.icon", value = -1 } }, { instanceId = id })
    assertFalse(ok)
    assertNil(NSi.Outfits.Get(id).trigger, "a refused batch stored its first entry")
    assertTrue(NSi.Schema.SetMany({ { path = "outfit.trigger.id", value = "FISHING" },
                                    { path = "outfit.trigger.disabled", value = true } }, { instanceId = id }))
    assertTrue(NSi.Outfits.Get(id).trigger.disabled)
    assertEqual(NSi.Outfits.Status(id), "disabled")
end)
