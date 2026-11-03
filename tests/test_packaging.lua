-- tests/test_packaging.lua — what reaches players (packaging, §1.6): the package folder is the TOC's
-- basename, every maintainer file is ignored, nothing ignored is loaded, and every media path the
-- addon names resolves under Interface\AddOns\OutfitterReborn\ to a shipped file. The tail holds the
-- doc set to the rest (P4.32): no pending suite, docs/testing.md's suite and retired-harness
-- tables, docs/module-map.md's Not shipped rows, and the README badge against docs/test-cases.md.

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- `.pkgmeta`: `package-as` and the `ignore:` list, comments and quotes stripped.
local function pkgmeta()
    local f = assert(io.open(T.root .. "/.pkgmeta", "r"))
    local packageAs, ignore, inIgnore = nil, {}, false
    for line in f:lines() do
        line = line:gsub("\r$", ""):gsub("%s+#.*$", "")
        local v = line:match("^package%-as:%s*(%S+)")
        if v then packageAs = v end
        if line:match("^ignore:") then
            inIgnore = true
        elseif line:match("^%S") then
            inIgnore = false
        elseif inIgnore then
            local entry = line:match("^%s*%-%s*(.-)%s*$")
            if entry and entry ~= "" then ignore[#ignore + 1] = (entry:gsub('^"(.*)"$', "%1")) end
        end
    end
    f:close()
    return packageAs, ignore
end

-- True when the packager's ignore `entry` (a path, a folder, or a `*` glob) covers `path`.
local function covers(entry, path)
    if entry:find("*", 1, true) then
        local pat = "^" .. entry:gsub("[%.%-%+%?%(%)%[%]%^%$]", "%%%0"):gsub("%*", "[^/]*") .. "$"
        return path:match(pat) ~= nil
    end
    return path == entry or path:sub(1, #entry + 1) == entry .. "/"
end

local function ignored(path, list)
    for _, entry in ipairs(list) do
        if covers(entry, path) then return entry end
    end
    return nil
end

test("packaging: the package folder is the TOC basename and the addon's folder name", function()
    local packageAs = pkgmeta()
    assertEqual(packageAs, "OutfitterReborn")
    assertEqual(packageAs, NS.name)
    local f = io.open(T.root .. "/" .. packageAs .. ".toc", "r")
    assertTrue(f ~= nil, packageAs .. ".toc is on disk")
    if f then f:close() end
end)

test("packaging: every maintainer file and folder is ignored", function()
    local _, list = pkgmeta()
    for _, path in ipairs({ ".luacheckrc", ".pkgmeta", ".gitignore", ".gitattributes", "docs/ARCHITECTURE.md",
                            "tests/run.lua", "tools/legacy_capture.lua", "CLAUDE.md", "DEPENDENCIES.md",
                            "media/logos/outfitterreborn.logo.png", "media/logos/outfitterreborn.logo.jpg",
                            "media/screenshots/outfitterreborn.screenshot.01.png", "_dev/x.lua", "a.bak" }) do
        assertTrue(ignored(path, list) ~= nil, path .. " would ship")
    end
end)

test("packaging: the player-facing files and the runtime logos ship", function()
    local _, list = pkgmeta()
    for _, path in ipairs({ "OutfitterReborn.toc", "README.md", "LICENSE", "Bindings.xml",
                            "media/logos/outfitterreborn.logo.tga", "media/logos/outfitterreborn.logo.128.tga",
                            "core/Namespace.lua", "libs/LibKa0s/LibKa0s.xml" }) do
        assertFalse(ignored(path, list) ~= nil, path .. " is ignored by " .. tostring(ignored(path, list)))
    end
end)

test("packaging: nothing the TOC loads is ignored", function()
    local _, list = pkgmeta()
    local f = assert(io.open(T.root .. "/OutfitterReborn.toc", "r"))
    for line in f:lines() do
        line = line:gsub("\r$", "")
        if line ~= "" and not line:find("^#") then
            local path = line:gsub("\\", "/")
            assertFalse(ignored(path, list) ~= nil, path .. " is loaded but ignored")
        end
    end
    f:close()
end)

test("packaging: every media path the addon names resolves to a shipped file", function()
    local _, list = pkgmeta()
    local prefix = "Interface\\AddOns\\OutfitterReborn\\"
    for _, full in ipairs({ NS.Constants.LOGO, NS.Constants.LOGO_128 }) do
        assertEqual(full:sub(1, #prefix), prefix, full)
        local rel = full:sub(#prefix + 1):gsub("\\", "/")
        local file = io.open(T.root .. "/" .. rel, "rb")
        assertTrue(file ~= nil, rel .. " is on disk")
        if file then file:close() end
        assertFalse(ignored(rel, list) ~= nil, rel .. " is named at run time but not shipped")
    end
end)

-- A path the addon hands the client, made relative to the package root: nil when it does not sit
-- under Interface\AddOns\OutfitterReborn\. Icon paths are extensionless (LibKa0s-Media `Icon`: the
-- client appends `.tga`), so `ext` names the file the client then opens.
local PREFIX = "Interface\\AddOns\\OutfitterReborn\\"
local function packaged(full, ext)
    if type(full) ~= "string" or full:sub(1, #PREFIX) ~= PREFIX then return nil end
    return full:sub(#PREFIX + 1):gsub("\\", "/") .. (ext or "")
end

local function onDisk(rel)
    local file = io.open(T.root .. "/" .. rel, "rb")
    if file then file:close() end
    return file ~= nil
end

-- The names of root CLAUDE.md's `LibKa0s icons:` line, read by the kit's own parser.
local function declaredIcons()
    local VendorSync = dofile(T.root .. "/tests/_kit/vendor_sync.lua")
    local f = assert(io.open(T.root .. "/CLAUDE.md", "rb"))
    local doc = f:read("*a")
    f:close()
    local decl = assert(VendorSync.iconDeclaration(doc), "CLAUDE.md declares its icons")
    return decl.names or {}
end

test("packaging: every declared icon resolves to a shipped file under the package folder", function()
    local _, list = pkgmeta()
    local names = declaredIcons()
    assertTrue(#names > 0, "the declaration names icons")
    for _, name in ipairs(names) do
        local rel = packaged(NS.Icon(name), ".tga")
        assertTrue(rel ~= nil, name .. " resolves under " .. PREFIX .. " (got " .. tostring(NS.Icon(name)) .. ")")
        if rel then
            assertTrue(onDisk(rel), rel .. " is on disk")
            -- red under: `- libs/LibKa0s/media/icons` added to the .pkgmeta ignores
            assertFalse(ignored(rel, list) ~= nil, rel .. " is drawn at run time but not shipped")
        end
    end
end)

-- Every icon name a literal in `src` hands NS.Icon: each string in the call's parentheses, so the
-- window's `NS.Icon(e.collapsed and "chevron-right" or "chevron-down")` yields both. Comments are
-- stripped first, so a documented call is not one.
local function iconCalls(src, into)
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        local code = line:gsub("%-%-.*$", "")
        for args in code:gmatch("NS%.Icon(%b())") do
            for name in args:gmatch('"([%w:%-]+)"') do into[name] = true end
        end
    end
    return into
end

local function readFile(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "rb"))
    local src = f:read("*a")
    f:close()
    return src
end

test("packaging: the icon declaration is exactly what is drawn (design §1.4, P4.31)", function()
    -- red under: a declared name nothing draws (`edit` back on the CLAUDE.md line), or a new
    -- `NS.Icon("search")` with the line left alone (the pruned payload lacks the file).
    local drawn = {}
    -- The scanner itself first, or an empty scan proves nothing.
    local probe = iconCalls('x(NS.Icon(a and "b" or "c")) -- NS.Icon("d")', {})
    assertTrue(probe.b and probe.c and not probe.d, "the call scanner misreads a ternary or a comment")
    for _, rel in ipairs(T.loadedAddonFiles) do iconCalls(readFile(rel), drawn) end
    -- What the library draws for this addon: the marks every host owes (the kit's list) and the debug
    -- console's title-bar buttons (NS.DebugLog), read out of the vendored window.
    local VendorSync = dofile(T.root .. "/tests/_kit/vendor_sync.lua")
    for _, name in ipairs(VendorSync.LIBRARY_MARKS) do drawn[name] = true end
    local console = readFile("libs/LibKa0s/DebugLogWindow.lua")
    local buttons = 0
    for name in console:gmatch('makeIconButton%(titleBar, spec%.addonName, "([%w:%-]+)"') do
        drawn[name], buttons = true, buttons + 1
    end
    assertEqual(buttons, 2, "the debug console's clear and copy buttons were not found")
    local declared = {}
    for _, name in ipairs(declaredIcons()) do declared[name] = true end
    for name in pairs(drawn) do assertTrue(declared[name] == true, name .. " is drawn but not declared") end
    for name in pairs(declared) do assertTrue(drawn[name] == true, name .. " is declared but nothing draws it") end
end)

test("packaging: each shipped icon set ships its license file beside it", function()
    local _, list = pkgmeta()
    local LICENSES = {
        [""] = "libs/LibKa0s/media/icons/LICENSE-open-iconic.txt",
        ph   = "libs/LibKa0s/media/icons/phosphor/LICENSE-phosphor.txt",
        gi   = "libs/LibKa0s/media/icons/game-icons/LICENSE-game-icons.txt",
    }
    local sets = {}
    for _, name in ipairs(declaredIcons()) do sets[name:match("^(%a+):") or ""] = true end
    for prefix in pairs(sets) do
        local rel = assert(LICENSES[prefix], "a license is known for the `" .. prefix .. "` set")
        assertTrue(onDisk(rel), rel .. " is on disk")
        -- red under: `- libs/LibKa0s/media/icons/LICENSE-open-iconic.txt` added to the .pkgmeta ignores
        assertFalse(ignored(rel, list) ~= nil, rel .. " is ignored by " .. tostring(ignored(rel, list)))
    end
end)

test("packaging: the debug console's face resolves to a shipped font", function()
    local _, list = pkgmeta()
    local rel = packaged(NS.Constants.FONT_MONO)
    assertTrue(rel ~= nil, "FONT_MONO resolves under " .. PREFIX .. " (got " .. tostring(NS.Constants.FONT_MONO) .. ")")
    if rel then
        assertTrue(onDisk(rel), rel .. " is on disk")
        -- red under: `- libs/LibKa0s/media/fonts` added to the .pkgmeta ignores
        assertFalse(ignored(rel, list) ~= nil, rel .. " is named at run time but not shipped")
    end
end)

-- ── The doc set's account of what does not ship and how it is tested (P4.32) ────────────────────
-- These read the tree and the runner, never a hand list: a helper added to tests/ or tools/, a suite
-- added to SUITES, or a case that moves the pass count goes red here until the docs follow it
-- (testing-§5, testing-§6).

-- The runner's SUITES table, read out of tests/run.lua's text: each suite name in declared order and
-- the `pending` reason of each pending entry.
local function declaredSuites()
    local src = readFile("tests/run.lua"):gsub("\r", "")
    local body = assert(src:match("\nlocal SUITES = (%b{})"), "tests/run.lua declares SUITES")
    local names, pending = {}, {}
    for line in body:gmatch("[^\n]+") do
        local code = line:gsub("%-%-.*$", "")
        local name = code:match('"(test_[%w_]+)"')
        if name then
            names[#names + 1] = name
            pending[name] = code:match('pending%s*=%s*"([^"]*)"')
        end
    end
    return names, pending
end

-- The body of `## <title>` in a markdown file: everything up to the next `## ` heading.
local function section(rel, title)
    local doc = readFile(rel):gsub("\r", "") .. "\n## "
    local start = doc:find("\n## " .. title .. "\n", 1, true)
    if not start then return nil end
    local from = start + #title + 5
    return doc:sub(from, doc:find("\n## ", from, true) - 1)
end

-- Every backticked token in the first cell of each table row of `body`.
local function firstCellTokens(body)
    local tokens = {}
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local cell = line:match("^|%s*([^|]-)%s*|")
        if cell and not cell:match("^%-+$") then
            for tok in cell:gmatch("`([^`]+)`") do tokens[#tokens + 1] = tok end
        end
    end
    return tokens
end

local function trackedUnder(prefixes)
    local p = io.popen('git -C "' .. T.root .. '" ls-files --cached --others --exclude-standard -- '
        .. table.concat(prefixes, " ") .. ' 2>/dev/null')
    local files = {}
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    return files
end

-- True when a module-map row token (a path, a `dir/` folder, or a `*` glob) names `path`.
local function rowCovers(tok, path)
    if tok:sub(-1) == "/" then return path:sub(1, #tok) == tok end
    return covers(tok, path)
end

test("packaging: SUITES holds no pending entry, test_refactor_pins dropped at P5 (design §13 step 1)", function()
    -- red under: `pending = "P4.x"` put back on any SUITES line
    local names, pending = declaredSuites()
    assertTrue(#names > 50, "the SUITES reader found " .. #names .. " suites")
    local held = {}
    for _, name in ipairs(names) do
        if pending[name] then held[#held + 1] = name .. " (" .. pending[name] .. ")" end
    end
    assertEqual(table.concat(held, ", "), "")
end)

test("packaging: docs/testing.md's suite table names every declared suite and nothing else (P4.32)", function()
    -- red under: a SUITES line with no row in `## The suites`, or a row naming no declared suite
    local body = assert(section("docs/testing.md", "The suites"), "docs/testing.md has `## The suites`")
    local listed = {}
    for _, tok in ipairs(firstCellTokens(body)) do
        if tok:match("^test_[%w_]+$") then listed[tok] = true end
    end
    local names = declaredSuites()
    local declared = {}
    for _, name in ipairs(names) do
        declared[name] = true
        assertTrue(listed[name] == true, name .. " is declared but has no row in docs/testing.md")
    end
    for name in pairs(listed) do
        assertTrue(declared[name] == true, name .. " has a row in docs/testing.md but is not declared")
    end
end)

-- Each suite named in a table's first cell under a `**Group**` heading of `body`, in order, as
-- "Group: test_name" lines (a heading's trailing colon dropped).
local function groupedSuites(body)
    local out, group = {}, nil
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local heading = line:match("^%*%*(.-)%*%*%s*$")
        if heading then group = heading:gsub(":$", "") end
        local cell = line:match("^|%s*([^|]-)%s*|")
        if cell and group then
            for tok in cell:gmatch("`(test_[%w_]+)`") do out[#out + 1] = group .. ": " .. tok end
        end
    end
    return table.concat(out, "\n")
end

local DESIGN = "docs/superpowers/specs/2026-11-03-design.md"

test("packaging: docs/testing.md groups and orders the suites as design §9.3 does (M2 review)", function()
    -- red under: `test_database` moved back under Standard-required and structural, or the
    -- `test_zones` and `test_itemlink` rows swapped
    local f = io.open(T.root .. "/" .. DESIGN, "rb")
    if not f then return T.skip(DESIGN .. " is not in this tree, so there is no §9.3 to mirror") end
    local design = f:read("*a"):gsub("\r", "")
    f:close()
    local from = assert(design:find("\n### 9.3 ", 1, true), "the design has §9.3")
    local to = assert(design:find("\n### 9.4 ", from, true), "the design has §9.4")
    local body = assert(section("docs/testing.md", "The suites"), "docs/testing.md has `## The suites`")
    assertEqual(groupedSuites(body), groupedSuites(design:sub(from, to)))
end)

test("packaging: docs/testing.md maps the retired harness's 144 cases, suite by suite (design §9.4)", function()
    -- red under: an old suite's row deleted from `## Retired harness`, or a case count changed
    local body = assert(section("docs/testing.md", "Retired harness"), "docs/testing.md has `## Retired harness`")
    -- The fourteen suites P3 C5 deleted, as `git show 7ea3dc3:tests/` holds them: history, not tree.
    local OLD = { "harness", "syntax", "eol", "toc", "xml", "load", "compat", "locale", "deprecated",
                  "zones", "scripts", "secrets", "outfits", "commands" }
    local counts, total = {}, 0
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local suite, n = line:match("^|%s*(%a+)%s*%((%d+)%)%s*|")
        if suite then counts[suite], total = tonumber(n), total + tonumber(n) end
    end
    for _, suite in ipairs(OLD) do
        assertTrue(counts[suite] ~= nil, "the retired `" .. suite .. "` suite has no row")
    end
    assertEqual(total, 144, "the retired rows' case counts")
end)

test("packaging: docs/module-map.md's Not shipped table names every helper in tests/ and tools/ (P4.32)", function()
    -- red under: the `tests/spy.lua` row deleted, or a row naming a file that is not in the tree
    local body = assert(section("docs/module-map.md", "Not shipped"), "docs/module-map.md has `## Not shipped`")
    local tokens = firstCellTokens(body)
    local files = trackedUnder({ "tests", "tools", "media/logos", "media/screenshots" })
    assertTrue(#files > 20, "git ls-files listed " .. #files .. " files")
    local _, list = pkgmeta()
    for _, path in ipairs(files) do
        if path:match("^tests/") or path:match("^tools/") or ignored(path, list) then
            local hit = false
            for _, tok in ipairs(tokens) do hit = hit or rowCovers(tok, path) end
            assertTrue(hit, path .. " does not ship but has no row in docs/module-map.md `## Not shipped`")
        end
    end
    for _, tok in ipairs(tokens) do
        if not tok:find("*", 1, true) and tok ~= "docs/" then
            local hit = false
            for _, path in ipairs(files) do hit = hit or rowCovers(tok, path) end
            assertTrue(hit, "`" .. tok .. "` has a Not shipped row but is not in the tree")
        end
    end
end)

test("packaging: the README badge and docs/test-cases.md agree, a Totals row per live suite (testing-§5)", function()
    -- red under: the badge left at a stale count, or a suite added to SUITES without regenerating
    local readme = readFile("README.md")
    local passed, all = readme:match("!%[Tests%]%(https://img%.shields%.io/badge/Tests%-(%d+)%%2F(%d+)_passing%-green%)")
    assertTrue(passed ~= nil, "README carries the static Tests badge")
    local inv = readFile("docs/test-cases.md")
    local total = tonumber(inv:match("| %*%*Total%*%* | %*%*(%d+)%*%* |"))
    assertTrue(total ~= nil, "docs/test-cases.md has its Total row")
    assertEqual(tonumber(passed), total, "the badge's passing count")
    assertEqual(tonumber(all), total, "the badge's total")
    local rows, sum = {}, 0
    for cell, n in inv:gmatch("\n| ([^|\r\n]-) | (%d+) |") do
        local name = cell:gsub("%.lua$", "")
        rows[name] = tonumber(n)
        if name ~= "Skipped" then sum = sum + tonumber(n) end
    end
    assertEqual(sum, total, "the Totals rows sum to Total")
    local names, pending = declaredSuites()
    for _, name in ipairs(names) do
        if not pending[name] then
            assertTrue(rows[name] ~= nil, name .. " is live but docs/test-cases.md has no Totals row for it")
        end
    end
end)
