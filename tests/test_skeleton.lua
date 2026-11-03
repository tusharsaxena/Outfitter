-- tests/test_skeleton.lua — the scaffold's own contract: the addon registers under its folder name,
-- NS.Print is the tagged printer, the DB defaults load, the declared icons resolve, every authored
-- file opens with the NS bootstrap, the bus wire names keep their shape, and the source stays Lua
-- 5.1. The slash case arrives with its seam (P3 C12).

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

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
