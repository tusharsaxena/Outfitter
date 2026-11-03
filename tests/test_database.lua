-- tests/test_database.lua — the store (§3.1, §3.5): the migration stamp survives AceDB's logout
-- strip, a raising step holds it, the profile and char walks reach entries nobody is logged in on,
-- nothing reads the legacy gOutfitter_* tables (R4), and both resolveRoot functions answer their arms.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- AceDB-3.0's removeDefaults, which its logout handler runs over every section before the client
-- writes the file: a scalar equal to its default goes, a table emptied by that goes with it.
local function removeDefaults(dest, src)
    for k, v in pairs(src or {}) do
        if type(v) == "table" and type(dest[k]) == "table" then
            removeDefaults(dest[k], v)
            if next(dest[k]) == nil then dest[k] = nil end
        elseif dest[k] == v then
            dest[k] = nil
        end
    end
end

--- A fresh instance with the files loaded and nothing initialized, the SavedVariables seeded with
--- `sv` and the runner's step list replaced by `steps`. Answers the instance and a restore.
local function seeded(sv, steps)
    local inst = T.load{ init = false }
    _G.OutfitterRebornDB = sv
    local list = inst.NS.__migrationSteps
    local saved = {}
    for i, s in ipairs(list) do saved[i] = s end
    if steps then
        for i = #list, 1, -1 do list[i] = nil end
        for i, s in ipairs(steps) do list[i] = s end
    end
    local function restore()
        for i = #list, 1, -1 do list[i] = nil end
        for i, s in ipairs(saved) do list[i] = s end
    end
    return inst, restore
end

local function initialize(inst)
    inst.mocks.LibStub("AceAddon-3.0"):InitializeAddon(inst.NS)
end

test("database: the schemaVersion stamp survives the logout strip", function()
    local inst = T.load()
    local NS = inst.NS
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION ~= NS.defaults.global.schemaVersion,
        "the current version must differ from the default, or AceDB strips it")
    removeDefaults(NS.db.global, NS.defaults.global)
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: a raising step holds the stamp where the last good step left it", function()
    local inst, restore = seeded(nil, {
        { to = 1, run = function() end },
        { to = 2, run = function() error("step 2 raised") end },
    })
    local ok, err = pcall(initialize, inst)
    restore()
    assertFalse(ok, "the raise reaches the caller")
    assertTrue(tostring(err):find("step 2 raised", 1, true) ~= nil, tostring(err))
    assertEqual(inst.NS.db.global.schemaVersion, 1)
end)

test("database: a profile step walks every stored profile, active or not", function()
    local seen = {}
    local inst, restore = seeded({ profiles = { Default = {}, Raid = { marker = "raid" }, Alt = {} } }, {
        { to = 1, scope = "profile", run = function(_, profile)
            seen[#seen + 1] = profile.marker or "?"
            profile.walked = true
        end },
    })
    initialize(inst)
    restore()
    assertEqual(#seen, 3, "every profile, the never-activated ones included")
    local sv = _G.OutfitterRebornDB
    assertTrue(sv.profiles.Raid.walked == true and sv.profiles.Alt.walked == true)
    assertEqual(inst.NS.db.global.schemaVersion, 1)
end)

test("database: a char step walks every stored character, logged in or not", function()
    local seen = {}
    local inst, restore = seeded({ char = { ["Other - Realm"] = { nextID = 9 }, ["Third - Realm"] = {} } }, {
        { to = 1, scope = "char", run = function(_, char)
            seen[#seen + 1] = char
            char.walked = true
        end },
    })
    initialize(inst)
    restore()
    assertEqual(#seen, 3, "both stored characters and the one logged in")
    local sv = _G.OutfitterRebornDB
    assertTrue(sv.char["Other - Realm"].walked == true, "a character nobody is logged in on")
    assertEqual(sv.char["Other - Realm"].nextID, 9, "a stored value is never replaced")
end)

test("database: a step already stamped never runs again", function()
    local runs = 0
    local inst, restore = seeded({ global = { schemaVersion = 1 } }, {
        { to = 1, run = function() runs = runs + 1 end },
    })
    initialize(inst)
    restore()
    assertEqual(runs, 0)
end)

test("database: a profile reset re-runs the steps over the reset profile, and keeps db.char", function()
    local inst = T.load()
    local NS = inst.NS
    NS.db.char.outfits.o1 = { id = "o1", name = "Kept" }
    NS.db.profile.auto.enabled = false
    NS.db:ResetProfile()
    assertEqual(NS.db.profile.auto.enabled, true)
    assertEqual(NS.db.char.outfits.o1.name, "Kept", "a profile reset never reaches the outfits (H7)")
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: nothing reads the legacy gOutfitter_* SavedVariables (R4)", function()
    for _, rel in ipairs(T.loadedAddonFiles) do
        local f = assert(io.open(T.root .. "/" .. rel, "r"))
        local text = f:read("*a")
        f:close()
        assertFalse(text:find("gOutfitter_", 1, true) ~= nil, rel .. " names a gOutfitter_ table")
    end
end)

test("database: the settings root answers global.* under db.global and the rest under db.profile", function()
    local NS = T.NS
    local root, first = NS.ResolveSettingsRoot({ "global", "minimap", "hide" })
    assertEqual(root, NS.db.global)
    assertEqual(first, 2)
    root, first = NS.ResolveSettingsRoot({ "auto", "enabled" })
    assertEqual(root, NS.db.profile)
    assertEqual(first, 1)
    -- It has no outfit arm: an `outfit.*` path lands in the profile, never in db.char.
    root = NS.ResolveSettingsRoot({ "outfit", "icon" }, "o1")
    assertEqual(root, NS.db.profile)
end)

test("database: the outfit root answers outfit.* and trigger.* for a known id", function()
    local inst = T.load()
    local NS = inst.NS
    local rec = { id = "o3", name = "Fishing" }
    NS.db.char.outfits.o3 = rec
    local root, first = NS.ResolveOutfitRoot({ "outfit", "icon" }, "o3")
    assertEqual(root, rec)
    assertEqual(first, 2)
    root, first = NS.ResolveOutfitRoot({ "trigger", "FISHING", "delay" }, "o3")
    assertEqual(type(rec.triggerParams), "table", "triggerParams is created on demand")
    assertEqual(root, rec.triggerParams)
    assertEqual(first, 2)
end)

test("database: the outfit root refuses a nil id, an unknown id and any other first segment", function()
    local inst = T.load()
    local NS = inst.NS
    NS.db.char.outfits.o1 = { id = "o1" }
    local root, why = NS.ResolveOutfitRoot({ "outfit", "icon" }, nil)
    assertEqual(root, nil)
    assertEqual(why, "no outfit")
    root, why = NS.ResolveOutfitRoot({ "outfit", "icon" }, "o99")
    assertEqual(root, nil)
    assertEqual(why, "no outfit")
    root = NS.ResolveOutfitRoot({ "auto", "enabled" }, "o1")
    assertEqual(root, nil)
end)
