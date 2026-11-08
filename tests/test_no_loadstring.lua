-- tests/test_no_loadstring.lua — P4.15 (H1, R3, anti-patterns #20): no code runs from text, anywhere.
--
-- The Custom script editor is dropped and every preset is a native descriptor, so nothing this repo
-- ships or tests compiles a string or reaches for a function environment: no load-from-string, no
-- bare load(, no setfenv/getfenv, no RunScript or DevTools_RunScript in any tracked .lua outside the
-- vendored libs/, tests/_kit/ and the never-loaded tools/. No descriptor carries a Script or Source
-- field, no trigger answers to CUSTOM, and the old script editor's dialog frame name is gone from
-- every tracked file, comments included.
--
-- The banned names are spelled in pieces below, so this file does not trip its own scan.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function word(...) return table.concat({ ... }) end

-- { pattern, what }: each name anchored at an identifier frontier, so `loadfile(` and a suite named
-- test_no_<name> are not hits.
local BANNED = {
    { "%f[%w_]" .. word("load", "string") .. "%f[^%w_]", word("load", "string") },
    { "%f[%w_.:]load%s*%(", word("lo", "ad(") },
    { "%f[%w_]" .. word("set", "fenv") .. "%f[^%w_]", word("set", "fenv") },
    { "%f[%w_]" .. word("get", "fenv") .. "%f[^%w_]", word("get", "fenv") },
    { "%f[%w_]" .. word("Run", "Script") .. "%f[^%w_]", word("Run", "Script") },
    { "%f[%w_]" .. word("DevTools_", "Run", "Script") .. "%f[^%w_]", word("DevTools_", "Run", "Script") },
}
local EDITOR = word("Outfitter", "Edit", "Script", "Dialog")

--- Lua source with its comments removed: long comments first, then line comments. Strings stay, so
--- a name built for a _G lookup is still a hit.
local function stripComments(text)
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    return (text:gsub("%-%-[^\n]*", ""))
end

--- The banned names in one file's text: "what" strings, one per hit.
local function hits(text)
    local code, out = stripComments(text), {}
    for _, rule in ipairs(BANNED) do
        if code:find(rule[1]) then out[#out + 1] = rule[2] end
    end
    if text:find(EDITOR, 1, true) then out[#out + 1] = EDITOR end
    return out
end

local function scanned(path)
    return path:find("%.lua$") ~= nil and not path:find("^libs/") and not path:find("^tests/_kit/")
        and not path:find("^tools/")
end

--- Every tracked .lua and every new one not yet added, walked from git (design §9.1).
local function files()
    local out = {}
    local p = io.popen('git -C "' .. T.root .. '" ls-files --cached --others --exclude-standard -- "*.lua" 2>/dev/null')
    if p then
        for line in p:lines() do
            if scanned(line) then out[#out + 1] = line end
        end
        p:close()
    end
    return out
end

local function read(rel)
    local f = io.open(T.root .. "/" .. rel, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

test("no code from text: the scanner catches each banned name in code and lets prose through (mutation self-test)", function()
    -- red under: hits() returning {} (the scan below would pass with no check at all), or the frontier
    -- dropped (loadfile( and a suite name would turn the scan red).
    assertEqual(#hits("local f = " .. word("load", "string") .. "(src)"), 1)
    assertEqual(#hits("local f = _G['" .. word("load", "string") .. "']"), 1, "a name built for _G is a hit")
    assertEqual(#hits("local f = " .. word("lo", "ad") .. "(src)"), 1)
    assertEqual(#hits(word("set", "fenv") .. "(f, {})\n" .. word("get", "fenv") .. "(1)"), 2)
    assertEqual(#hits(word("Run", "Script") .. "('x')"), 1)
    assertEqual(#hits("local x = " .. EDITOR), 1)
    assertEqual(#hits("-- " .. EDITOR .. " is gone"), 1, "the editor's name is banned in comments too")
    assertEqual(#hits("-- never " .. word("load", "string") .. "(x)\nlocal ok = loadfile(path)"), 0)
    assertEqual(#hits("{ name = 'test_no_" .. word("load", "string") .. "' }\nM.LoadAddOn(x)\nt:load(x)"), 0)
end)

test("no code from text: no tracked Lua outside libs/, tests/_kit/ and tools/ names a banned call", function()
    local list, found = files(), {}
    assertTrue(#list > 40, "the scan saw the tracked files (" .. #list .. ")")
    for _, rel in ipairs(list) do
        local text = read(rel)
        for _, what in ipairs(text and hits(text) or {}) do found[#found + 1] = rel .. ": " .. what end
    end
    assertEqual(table.concat(found, "\n"), "")
end)

test("no code from text: no descriptor or catalog row carries a Script or Source field", function()
    local NS = T.NS
    local function clean(t, label)
        for _, key in ipairs({ "Script", "Source", "script", "source", "SavedScript", "ScriptID" }) do
            assertTrue(t[key] == nil, label .. " carries " .. key)
        end
    end
    local n = 0
    for _, row in ipairs(NS.TriggerCatalog.rows) do clean(row, "row " .. row.id) end
    for _, desc in ipairs(NS.Triggers.All()) do
        n = n + 1
        clean(desc, "descriptor " .. desc.id)
    end
    -- WoW Forever's registry holds four of the 33 zone rows (ruling D3), so 44 rather than 73.
    assertTrue(n > 40, "the registry is finalized (" .. n .. ")")
end)

test("no code from text: no trigger answers to CUSTOM, and nothing can name one", function()
    local NS = T.NS
    assertTrue(NS.Triggers.Get("CUSTOM") == nil, "the Custom preset is dropped (H1)")
    for _, desc in ipairs(NS.Triggers.All()) do
        assertTrue(not desc.id:find("CUSTOM", 1, true), desc.id .. " is a Custom trigger")
    end
    -- The outfit row refuses the id, so a stored CUSTOM can never come back through the dialog.
    local inst = T.load()
    local id = inst.NS.Outfits.Create("Scripted", {})
    assertTrue(not (inst.NS.SetByPath("outfit.trigger.id", "CUSTOM", id)), "outfit.trigger.id took CUSTOM")
end)
