-- tests/test_file_budget.lua — every authored Lua file stays under 1000 lines (design §12 "Files",
-- R10). Authored means everything this repo writes, tests/ and tools/ included; libs/ and tests/_kit/
-- are byte copies of LibKa0s and gated there. The kit's test_layout_cap gates 1500 (layout-§1); this
-- is the tighter line the design holds every file to, so a file is split long before that census.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LIMIT = 1000

--- Lines in a text: one per newline, plus an unterminated last line.
local function lineCount(text)
    local _, n = text:gsub("\n", "")
    if #text > 0 and text:sub(-1) ~= "\n" then n = n + 1 end
    return n
end

--- Over budget: the design's line is "< 1000", so 1000 itself is over.
local function overBudget(n)
    return n >= LIMIT
end

--- A path the budget covers: Lua, and not one of the two vendored copies.
local function authored(path)
    return path:find("%.lua$") ~= nil and not path:find("^libs/") and not path:find("^tests/_kit/")
end

--- Every tracked .lua and every new one not yet added (a file over budget fails before it is ever
--- committed), walked from git rather than a hand list (design §9.1). A tracked path deleted from the
--- working tree is no file and is passed over.
local function authoredFiles()
    local out = {}
    local p = io.popen('git -C "' .. T.root .. '" ls-files --cached --others --exclude-standard -- "*.lua" 2>/dev/null')
    if p then
        for line in p:lines() do
            if authored(line) then out[#out + 1] = line end
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

test("file budget: the counter and the filter measure what the gate claims (mutation self-test)", function()
    assertEqual(lineCount(""), 0)
    assertEqual(lineCount("a\n"), 1)
    assertEqual(lineCount("a\nb"), 2, "an unterminated last line counts")
    assertEqual(lineCount("a\r\nb\r\n"), 2, "CRLF counts once per line")
    -- red under: overBudget written `n > LIMIT` (a file of exactly 1000 lines would pass).
    assertTrue(overBudget(lineCount(("x\n"):rep(LIMIT))), "a 1000-line file is over budget")
    assertFalse(overBudget(lineCount(("x\n"):rep(LIMIT - 1))), "a 999-line file is within it")
    assertTrue(authored("modules/Equip.lua"))
    assertTrue(authored("tests/fixtures/legacy/zones.lua"), "generated fixtures are held to it too")
    assertTrue(authored("tools/legacy_capture.lua"))
    assertFalse(authored("libs/LibKa0s/Core.lua"))
    assertFalse(authored("tests/_kit/framework.lua"))
    assertFalse(authored("docs/ARCHITECTURE.md"))
end)

test("file budget: every authored .lua is under 1000 lines", function()
    local files, seen, over = authoredFiles(), {}, {}
    for _, rel in ipairs(files) do
        local text = read(rel)
        if text then
            seen[rel] = true
            local n = lineCount(text)
            if overBudget(n) then over[#over + 1] = rel .. " (" .. n .. ")" end
        end
    end
    -- The walk itself: an empty or partial listing would pass everything below.
    assertTrue(seen["core/Namespace.lua"] and seen["tests/run.lua"] and seen["tools/legacy_capture.lua"],
        "git listed none of the files the budget must see; is git missing?")
    assertEqual(#over, 0, "over budget: " .. table.concat(over, ", "))
end)
