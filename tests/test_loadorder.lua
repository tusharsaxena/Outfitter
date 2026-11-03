-- tests/test_loadorder.lua — the runner's load list IS the TOC's (testing-§9): fed exactly the TOC's
-- files in the TOC's order, every derived path on disk, no libs/ path leaked in, the folders in the
-- layout-§1 order, and none of the legacy files back.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- Every TOC line, CR stripped.
local function tocLines()
    local f = assert(io.open(T.root .. "/OutfitterReborn.toc", "r"))
    local lines = {}
    for line in f:lines() do lines[#lines + 1] = (line:gsub("\r$", "")) end
    f:close()
    return lines
end

test("load order: the runner loaded exactly the TOC's files, in the TOC's order", function()
    local fresh = T.Loader.tocFiles(T.root .. "/OutfitterReborn.toc")
    local loaded = T.loadedAddonFiles
    assertTrue(#fresh > 0, "the TOC derivation is empty; nothing below can fail")
    assertEqual(#loaded, #fresh, "the runner's list and the TOC differ in length")
    for i, path in ipairs(fresh) do assertEqual(loaded[i], path, "position " .. i) end
end)

test("load order: every derived path exists on disk", function()
    for _, path in ipairs(T.loadedAddonFiles) do
        local f = io.open(T.root .. "/" .. path, "rb")
        assertTrue(f ~= nil, path .. " is in the TOC but not on disk")
        if f then f:close() end
    end
end)

test("load order: no libs/ path leaked into the addon's own list", function()
    for _, path in ipairs(T.loadedAddonFiles) do
        assertFalse(path:find("^libs[/\\]") ~= nil, path .. " is a library file in the addon's list")
    end
end)

-- The folder rank of each TOC file line; nil for a comment, a blank or a header.
local RANK = { libs = 1, locales = 2, core = 3, defaults = 4, modules = 5, settings = 6 }

test("load order: the folders load libs, locales, core, defaults, modules, settings", function()
    local last, seen = 0, 0
    for _, line in ipairs(tocLines()) do
        if line ~= "" and not line:find("^#") then
            local folder = line:match("^([%w_]+)[\\/]")
            local rank = folder and RANK[folder]
            assertTrue(rank ~= nil, "a TOC line outside the six folders: " .. line)
            assertTrue(rank >= last, line .. " loads after a later folder")
            last, seen = rank, seen + 1
        end
    end
    assertTrue(seen > 0, "no file lines read")
end)

test("load order: each LOAD-BEARING note sits directly above a file line", function()
    local lines, notes = tocLines(), 0
    for i, line in ipairs(lines) do
        if line:find("^# LOAD%-BEARING:") then
            notes = notes + 1
            local j = i + 1
            -- A note may wrap onto further comment lines; the file line follows them.
            while lines[j] and lines[j]:find("^#") and not lines[j]:find("^# LOAD%-BEARING:") do j = j + 1 end
            local nextLine = lines[j] or ""
            assertTrue(nextLine ~= "" and not nextLine:find("^#"), "the note at line " .. i .. " is above no file")
        end
    end
    assertTrue(notes > 0, "the TOC carries no LOAD-BEARING note")
end)

test("load order: Bindings.xml, Deprecated.lua and the legacy files are not in the TOC", function()
    for _, line in ipairs(tocLines()) do
        if not line:find("^#") then
            assertFalse(line:find("Bindings%.xml") ~= nil, "Bindings.xml loads itself; it is never listed")
            assertFalse(line:find("Deprecated%.lua") ~= nil, "Deprecated.lua is dropped (R6)")
            assertFalse(line:find("^Libraries[\\/]") ~= nil, "Libraries/ is deleted (H15)")
            assertFalse(line == "Compat.lua", "the compat family is core/Compat.lua")
        end
    end
end)

test("load order: the namespace loads first in core and the printer before the addon object", function()
    local at = {}
    for i, path in ipairs(T.loadedAddonFiles) do at[(path:gsub("\\", "/"))] = i end
    assertTrue(at["locales/enUS.lua"] < at["core/Namespace.lua"], "NS.L before core")
    assertTrue(at["core/Namespace.lua"] < at["core/MediaSetup.lua"])
    assertTrue(at["core/MediaSetup.lua"] < at["core/Constants.lua"], "FONT_MONO resolves at file scope")
    assertTrue(at["core/CoreSetup.lua"] < at["core/OutfitterReborn.lua"], "the NS.Print reclaim")
    assertTrue(at["core/OutfitterReborn.lua"] < at["core/Database.lua"])
end)
