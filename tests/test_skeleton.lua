-- tests/test_skeleton.lua — the scaffold's own contract: the addon registers under its folder name,
-- NS.Print is the tagged printer, the DB defaults load, the declared icons resolve, every authored
-- file opens with the NS bootstrap, the bus wire names keep their shape, and the source stays Lua
-- 5.1, and every literal debug tag the code writes is in docs/debug.md's register. The slash case
-- is tests/test_slash.lua's (P3 C12). P4.27 adds the login: every module the latch walks has landed
-- and the login resumes each one, and the legacy guard (design §4.7) warns once, flags the state and
-- sends LEGACY_DETECTED when the first LoadPass finishes.

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

test("skeleton: the addon registers with AceAddon under its folder name", function()
    local AceAddon = T.mocks.LibStub("AceAddon-3.0")
    assertEqual(AceAddon:GetAddon("OutfitterReborn", true), NS)
    assertEqual(NS.addon, NS)
    assertEqual(NS.name, "OutfitterReborn")
    assertEqual(NS.BRAND, "Ka0s Outfitter Reborn")
    assertEqual(NS.SLASH, "/of")
    assertEqual(NS.SLASH_LONG, "/outfitter")
    assertEqual(NS.version, "1.1.0")
end)

test("skeleton: NS.Print is the tagged printer, reclaimed from AceConsole", function()
    assertEqual(NS.Print, NS.Util.print)
    T.mocks.__resetPrinted()
    NS.Print("hello")
    local printed = T.mocks.__printed()
    assertEqual(#printed, 1)
    assertTrue(printed[1]:find("[OR]", 1, true) ~= nil, "the line carries the cyan [OR] tag")
end)

-- Every leaf of `want` read back through `got`, which is AceDB's defaults-backed view.
local function assertLeaves(want, got, where)
    for k, v in pairs(want) do
        local path = where .. "." .. tostring(k)
        if type(v) == "table" then
            assertEqual(type(got[k]), "table", path)
            assertLeaves(v, got[k], path)
        else
            assertEqual(got[k], v, path)
        end
    end
end

test("skeleton: the DB defaults load and equal NS.defaults, schemaVersion stamped", function()
    assertEqual(type(NS.defaults), "table")
    assertLeaves(NS.defaults.profile, NS.db.profile, "profile")
    assertLeaves(NS.defaults.char, NS.db.char, "char")
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(NS.db.global.minimap.hide, false)
    assertEqual(NS.db.profile.enabled, true)
    assertEqual(NS.db.profile.auto.enabled, true)
    assertEqual(NS.db.profile.bar.shown, false)
end)

test("skeleton: the produced interfaces exist", function()
    for _, name in ipairs({ "Print", "SafeRegisterEvent", "SafeRegisterUnitEvent", "SafeToString",
                            "MakeCloseButton", "ApplySkin", "RaiseStaticPopups", "Icon", "MediaFont",
                            "Meta", "Version", "InitDB", "RunMigrations", "OnProfileChanged",
                            "ResolveSettingsRoot", "ResolveOutfitRoot" }) do
        assertEqual(type(NS[name]), "function", "NS." .. name)
    end
    assertEqual(type(NS.rejectedEvents), "table")
    assertEqual(type(NS.LIBKA0S_MISSING), "string")
    assertEqual(type(NS.L), "table")
    assertEqual(NS.L["Ka0s Outfitter Reborn"], NS.BRAND)
    assertEqual(NS.State.debug, false)
    assertEqual(NS.State.testMode, false)
    assertEqual(NS.State.legacyLoaded, false)
end)

test("skeleton: the logo paths derive from the folder name", function()
    local C = NS.Constants
    assertEqual(C.LOGO_128, "Interface\\AddOns\\OutfitterReborn\\media\\logos\\outfitterreborn.logo.128.tga")
    assertEqual(C.LOGO, "Interface\\AddOns\\OutfitterReborn\\media\\logos\\outfitterreborn.logo.tga")
    for _, rel in ipairs({ "media/logos/outfitterreborn.logo.128.tga", "media/logos/outfitterreborn.logo.tga" }) do
        local f = io.open(T.root .. "/" .. rel, "rb")
        assertTrue(f ~= nil, rel .. " is on disk")
        if f then f:close() end
    end
    assertEqual(type(C.LAYERS.STRATA), "table")
    assertEqual(type(C.LAYERS.LEVEL), "table")
end)

test("skeleton: every NS.MSG wire name is Ka0s_OutfitterReborn_<PascalCase>", function()
    local count = 0
    for key, wire in pairs(NS.MSG) do
        count = count + 1
        assertEqual(type(wire), "string", key)
        assertTrue(wire:match("^Ka0s_OutfitterReborn_%u%a+$") ~= nil, key .. " = " .. tostring(wire))
    end
    assertEqual(count, 25, "the full §2.3 catalog")
end)

-- The CLAUDE.md declaration (§1.4), read back from the file the vendoring gate reads.
local function declaredIcons()
    local f = assert(io.open(T.root .. "/CLAUDE.md", "r"))
    local text = f:read("*a")
    f:close()
    local line = assert(text:match("LibKa0s icons: ([^\r\n]+)"), "CLAUDE.md has no `LibKa0s icons:` line")
    local names = {}
    for name in line:gsub("%.%s*$", ""):gmatch("[^,%s]+") do names[#names + 1] = name end
    return names
end

test("skeleton: every declared icon resolves to a shipped path", function()
    local names = declaredIcons()
    assertTrue(#names > 0, "the declaration names no icon; nothing below can fail")
    for _, name in ipairs(names) do
        local path = NS.Icon(name)
        assertEqual(type(path), "string", name)
        assertTrue(path:find("Interface\\AddOns\\OutfitterReborn\\", 1, true) == 1, path)
    end
    assertTrue(NS.Constants.FONT_MONO:find("OutfitterReborn", 1, true) ~= nil, "the mono face is the shipped one")
end)

test("skeleton: every authored Lua file opens with the NS bootstrap (an overlay, its gate) and a path comment", function()
    for _, rel in ipairs(T.loadedAddonFiles) do
        local f = assert(io.open(T.root .. "/" .. rel, "r"))
        local first = (f:read("*l") or ""):gsub("\r$", "")
        local second = (f:read("*l") or ""):gsub("\r$", "")
        f:close()
        -- A translation's first statement is its own locale gate instead (localization-§1, §6): an
        -- ungated overlay overwrites enUS on every client. tests/test_locale.lua pins the gate itself.
        local overlay = rel:match("^locales/(%l%l%u%u)[%w_]*%.lua$")
        if overlay and overlay ~= "enUS" then
            assertEqual(first, 'if GetLocale() ~= "' .. overlay .. '" then return end', rel .. ": " .. first)
        else
            assertTrue(first == "local addonName, NS = ..." or first == "local _, NS = ...", rel .. ": " .. first)
        end
        assertTrue(second:find("-- " .. rel .. " — ", 1, true) == 1, rel .. " line 2: " .. second)
    end
end)

-- The Lua 5.2+ constructs the client's 5.1 cannot run: goto and labels, the integer-division and
-- bitwise operators, and the 5.2+ library calls. Comments and string literals are stripped first.
local LUA52 = {
    { "%f[%w_]goto%f[^%w_]", "goto" }, { "::[%a_][%w_]*::", "a label" }, { "//", "integer division" },
    { "[^~=<>]~[^=]", "bitwise not / xor" }, { "<<", "a shift" }, { ">>", "a shift" },
    { "%f[%w_]table%.unpack%f[^%w_]", "table.unpack" }, { "%f[%w_]table%.pack%f[^%w_]", "table.pack" },
    { "%f[%w_]utf8%.", "utf8" }, { "%f[%w_]_ENV%f[^%w_]", "_ENV" },
}

local function stripped(text)
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    text = text:gsub("%[(=*)%[.-%]%1%]", '""')
    text = text:gsub("%-%-[^\n]*", "")
    text = text:gsub('"[^"\n]*"', '""'):gsub("'[^'\n]*'", "''")
    return text
end

test("skeleton: the addon's source is Lua 5.1 only", function()
    for _, rel in ipairs(T.loadedAddonFiles) do
        local f = assert(io.open(T.root .. "/" .. rel, "r"))
        local code = stripped(f:read("*a"))
        f:close()
        for _, rule in ipairs(LUA52) do
            assertTrue(code:find(rule[1]) == nil, rel .. " uses " .. rule[2])
        end
    end
end)

--- The tags of docs/debug.md's `## Tags` table, as a set.
local function documentedTags()
    local f = assert(io.open(T.root .. "/docs/debug.md", "r"))
    local text = f:read("*a")
    f:close()
    local section = text:match("\n## Tags\r?\n(.-)\n## ") or text:match("\n## Tags\r?\n(.*)$") or ""
    local tags = {}
    for tag in section:gmatch("\n| `([%w]+)` |") do tags[tag] = true end
    return tags
end

test("skeleton: every literal debug tag the code writes is in docs/debug.md's tag register", function()
    local documented, seen = documentedTags(), 0
    assertTrue(documented.Init and documented.Set, "the register parse found no rows; nothing below can fail")
    for _, rel in ipairs(T.loadedAddonFiles) do
        local f = assert(io.open(T.root .. "/" .. rel, "r"))
        local code = f:read("*a")
        f:close()
        for tag in code:gmatch('NS%.Debug%(%s*"([^"]+)"') do
            seen = seen + 1
            -- red under: docs/debug.md without its `Test` row (modules/Preview.lua writes it)
            assertTrue(documented[tag] == true, rel .. " writes the undocumented debug tag " .. tag)
        end
    end
    assertTrue(seen > 0, "no NS.Debug call was found; the scan is broken")
end)

-- ── the login (P4.27, design §4.7, §5.12) ─────────────────────────────────────────────────────

test("skeleton: every module the latch walks has landed, with Suspend and Resume", function()
    -- red under: a name in core/LifecycleSetup.lua's MODULES whose module publishes no NS table (the
    -- login walk itself raises on it, so every instance fails to load).
    assertEqual(#NS.LIFECYCLE_MODULES, 20, "design §5.12's list")
    for _, name in ipairs(NS.LIFECYCLE_MODULES) do
        local m = NS[name]
        assertEqual(type(m), "table", "NS." .. name)
        assertEqual(type(m.Suspend), "function", "NS." .. name .. ".Suspend")
        assertEqual(type(m.Resume), "function", "NS." .. name .. ".Resume")
    end
end)

test("skeleton: the login resumes every module bottom to top, and nothing while stood down", function()
    -- red under: an NS:OnEnable in core/OutfitterReborn.lua that walks top to bottom, or skips the
    -- walk (nothing resumes at login).
    local order = {}
    local inst = T.load({ enable = false })
    for _, name in ipairs(inst.NS.LIFECYCLE_MODULES) do
        local m = inst.NS[name]
        local resume = m.Resume
        m.Resume = function(...) order[#order + 1] = name; return resume(...) end
    end
    inst.mocks.LibStub("AceAddon-3.0"):EnableAddon(inst.NS)
    local want = {}
    for i = #inst.NS.LIFECYCLE_MODULES, 1, -1 do want[#want + 1] = inst.NS.LIFECYCLE_MODULES[i] end
    assertEqual(table.concat(order, ","), table.concat(want, ","))
    assertTrue(#inst.mocks.__timers() > 0, "the login armed nothing")

    -- The login is the latch's stand-up (NS.StandUp, core/LifecycleSetup.lua): a listed name whose
    -- module has not landed is skipped there, never a load error (F-008).
    -- red under: an NS:OnEnable in core/OutfitterReborn.lua that walks NS[modules[i]].Resume()
    -- itself, unguarded (the login raises on the missing module).
    local gap = T.load({ enable = false })
    local list = gap.NS.LIFECYCLE_MODULES
    table.insert(list, 1, "TestMissing")
    local ok, err = pcall(gap.mocks.LibStub("AceAddon-3.0").EnableAddon, gap.mocks.LibStub("AceAddon-3.0"), gap.NS)
    table.remove(list, 1)
    assertTrue(ok, "a missing module raised at login: " .. tostring(err))
    assertTrue(gap.NS.TriggerBinder ~= nil and #gap.mocks.__timers() > 0, "the login stopped short")

    -- Stood down at login (a stored `enabled = false`): OnEnable returns before the walk.
    -- red under: an NS:OnEnable in core/OutfitterReborn.lua without its
    -- `if NS.IsStoodDown() then return end` (a stood-down login resumes every module).
    local down = T.load({ enable = false })
    local resumed = 0
    for _, name in ipairs(down.NS.LIFECYCLE_MODULES) do
        local m = down.NS[name]
        local resume = m.Resume
        m.Resume = function(...) resumed = resumed + 1; return resume(...) end
    end
    down.NS.ApplyEnabled(false)
    down.mocks.LibStub("AceAddon-3.0"):EnableAddon(down.NS)
    assertEqual(resumed, 0, "a stood-down login resumed a module")
end)

--- A login with the legacy Outfitter reported loaded beside this addon; `opts.disabled` logs in
--- with `enabled = false` stored.
local function legacyLogin(opts)
    opts = opts or {}
    local inst = T.load({ enable = false, mutate = function(M)
        M.__loadedAddOns.Outfitter = true
        M.__gear:load("geared")
    end })
    local ns, M = inst.NS, inst.mocks
    if opts.disabled then ns.ApplyEnabled(false) end
    local sent = 0
    ns.NewBusTarget():RegisterMessage(ns.MSG.LEGACY_DETECTED, function() sent = sent + 1 end)
    M.__resetPrinted()
    M.LibStub("AceAddon-3.0"):EnableAddon(ns)
    return ns, M, function() return sent end
end

local LEGACY_LINE = "The old Outfitter addon is also loaded. Disable it: both change your gear and both own /outfitter."

local function legacyLines(M)
    local n = 0
    for _, line in ipairs(M.__printed()) do
        if line:find(LEGACY_LINE, 1, true) then n = n + 1 end
    end
    return n
end

test("skeleton: a loaded legacy Outfitter is warned once, flagged, and LEGACY_DETECTED waits for the LoadPass", function()
    -- red under: an empty checkLegacy in core/OutfitterReborn.lua (no line, no flag), or a send in
    -- OnEnable instead of NS.OnLoadPassDone (the message goes out before the LoadPass).
    local ns, M, sent = legacyLogin()
    assertEqual(legacyLines(M), 1, "the warning, once")
    assertTrue(ns.State.legacyLoaded, "the diagnostics flag")
    assertEqual(sent(), 0, "LEGACY_DETECTED went out before the first LoadPass")
    M.__fire("PLAYER_ENTERING_WORLD")
    for _ = 1, 4 do if M.__fireTimers() == 0 then break end end
    assertTrue(ns.db.char.seeded == true, "the first LoadPass did not run")
    assertEqual(sent(), 1, "the first LoadPass sends LEGACY_DETECTED once")
    -- Warn only (owner ruling 2026-11-03): nothing is held.
    assertFalse(ns.IsStoodDown(), "the legacy guard stood the addon down")
    assertTrue(ns.TriggerBinder.IsActive(), "the legacy guard held the trigger binder")
end)

test("skeleton: a disabled login flags the legacy addon for /of diagnostics and prints nothing", function()
    -- red under: a checkLegacy that prints before its NS.IsStoodDown() read.
    local ns, M = legacyLogin({ disabled = true })
    assertTrue(ns.State.legacyLoaded, "the flag is set while stood down too")
    assertEqual(legacyLines(M), 0, "a stood-down login printed the warning")
end)

test("skeleton: without the legacy addon nothing is said, flagged or sent", function()
    local inst = T.load({ enable = false, mutate = function(M) M.__gear:load("geared") end })
    local ns, M = inst.NS, inst.mocks
    local sent = 0
    ns.NewBusTarget():RegisterMessage(ns.MSG.LEGACY_DETECTED, function() sent = sent + 1 end)
    M.__resetPrinted()
    M.LibStub("AceAddon-3.0"):EnableAddon(ns)
    M.__fire("PLAYER_ENTERING_WORLD")
    for _ = 1, 4 do if M.__fireTimers() == 0 then break end end
    assertEqual(legacyLines(M), 0)
    assertFalse(ns.State.legacyLoaded == true)
    -- red under: an NS.OnLoadPassDone that sends LEGACY_DETECTED unconditionally.
    assertEqual(sent, 0, "LEGACY_DETECTED went out with no legacy addon")
end)
