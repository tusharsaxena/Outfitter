-- tests/test_credits.lua — the credits survive the conversion (R8, INV §1, design §4.2, §1.4). The
-- landing page carries the one host credits line; the README's `## Credits` carries the full table the
-- old About panel showed (tests/fixtures/legacy/credits.lua, captured at 7ea3dc3) and the icon sets
-- this build ships; LICENSE keeps John Stephen's copyright with the Ka0s line under it.

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local VendorSync = dofile(T.root .. "/tests/_kit/vendor_sync.lua")

local function read(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "rb"))
    local s = f:read("*a")
    f:close()
    return (s:gsub("\r\n", "\n"))
end

-- The body of README.md's `## <heading>` section, and whether it is the last H2 in the file.
local function readmeSection(heading)
    local md = "\n" .. read("README.md")
    local start = md:find("\n## " .. heading .. "\n", 1, true)
    if not start then return nil, false end
    local bodyAt = start + #heading + 5
    local nextAt = md:find("\n## ", bodyAt, true)
    return md:sub(bodyAt, (nextAt or #md + 1) - 1), nextAt == nil
end

-- A legacy credit's display name: its first line (the second is a guild tag), with the two entries
-- the old table wrote as prose cut to the name ("Nulian.. We applaude you!", "The guild of Bloodforged").
local function displayName(raw)
    local name = raw:match("^[^\n]*")
    name = name:gsub("%.%..*$", ""):gsub("^The guild of ", "")
    return name
end

-- Every person the old About panel credited, by group. The "Ace Library" group credits libraries,
-- which the README does not roll-call (DEPENDENCIES.md lists them), and the Korean localizer's
-- recorded name is "Unknown".
local function legacyPeople()
    local out = {}
    for group, list in pairs(T.legacy.credits.groups) do
        if group ~= "Ace Library" then
            for _, entry in ipairs(list) do
                if entry.name ~= "Unknown" then
                    out[#out + 1] = { group = group, name = displayName(entry.name) }
                end
            end
        end
    end
    return out
end

local function credits()
    local body = readmeSection("Credits")
    assertTrue(body ~= nil, "README.md has a ## Credits section")
    return body or ""
end

local function has(text, needle) return text:find(needle, 1, true) ~= nil end

-- ── The landing page ────────────────────────────────────────────────────────────────────────────

test("credits: the landing page's Credits section is the one host credits line", function()
    local found
    for _, s in ipairs(NS.LANDING.sections) do
        if s.heading == NS.L["Credits"] then found = s end
    end
    assertTrue(found ~= nil, "NS.LANDING has a Credits section")
    local rows = found.rows()
    assertEqual(#rows, 1)
    assertEqual(rows[1], NS.CREDITS_LINE)
end)

test("credits: the landing line names the author, his handle, the maintainer and Nulian", function()
    for _, who in ipairs({ "John Stephen", "mundocani", "aDd1kTeD2Ka0s", "Nulian" }) do
        assertTrue(has(NS.CREDITS_LINE, who), "the landing credits line names " .. who)
    end
end)

-- ── README.md ───────────────────────────────────────────────────────────────────────────────────

test("credits: README.md's Credits is its last section", function()
    local body, last = readmeSection("Credits")
    assertTrue(body ~= nil, "README.md has a ## Credits section")
    -- red under: a `## License` section left after `## Credits`
    assertTrue(last, "no ## section follows ## Credits")
end)

test("credits: the README names the author, the maintainers and the license", function()
    local body = credits()
    for _, who in ipairs({ "John Stephen", "mundocani", "aDd1kTeD2Ka0s", "Nulian", "NokeHarrier", "kionik",
                           "UppyDan", "Bruce Quinton", "MIT", "LICENSE" }) do
        assertTrue(has(body, who), "README Credits names " .. who)
    end
end)

test("credits: the README carries every localizer, under the language they translated", function()
    local body, n = credits(), 0
    for _, p in ipairs(legacyPeople()) do
        local lang = p.group:match("^(%a+) Localization$")
        if lang then
            n = n + 1
            local line = body:match("\n[^\n]*" .. lang .. "[^\n]*")
            assertTrue(line ~= nil, "README Credits has a line for the " .. lang .. " translation")
            assertTrue(line ~= nil and has(line, p.name), p.name .. " is credited for " .. lang)
        end
    end
    assertTrue(n >= 12, "the fixture names the localizers")
end)

test("credits: the README carries every developer, tester, supporter and friend the old panel did", function()
    local body, n = credits(), 0
    for _, p in ipairs(legacyPeople()) do
        n = n + 1
        assertTrue(has(body, p.name), p.name .. " (" .. p.group .. ") is credited in the README")
    end
    assertTrue(n > 90, "the fixture's people are read")
end)

test("credits: the README credits exactly the icon sets this build ships", function()
    local decl = assert(VendorSync.iconDeclaration(read("CLAUDE.md")), "CLAUDE.md declares its icons")
    local shipped = {}
    if decl.mode == "all" then
        -- `all (icon browser)` ships every set, so every set is credited (releasing.md: Attribution).
        shipped = { [""] = true, ph = true, gi = true }
    end
    for _, name in ipairs(decl.names or {}) do
        local prefix = name:match("^(%a+):") or ""
        shipped[prefix] = true
    end
    local body = credits()
    for prefix, set in pairs({ [""] = "Open Iconic", ph = "Phosphor", gi = "Game-icons" }) do
        if shipped[prefix] then
            assertTrue(has(body, set), "README Credits names " .. set .. ", whose icons ship")
        else
            -- red under: a `gi:` credit with no `gi:` icon declared
            assertFalse(has(body, set), "README Credits names " .. set .. ", which does not ship")
        end
    end
    -- red under: drop "by Waybury" or "by Phosphor Icons" from the README's Credits (documentation-§1
    -- item 12: each MIT set is named with its author).
    if shipped[""] then assertTrue(has(body, "Waybury"), "Open Iconic is credited to Waybury") end
    if shipped.ph then assertTrue(has(body, "Phosphor Icons"), "Phosphor is credited to Phosphor Icons") end
    -- Game-icons.net is CC BY 3.0: a MUST to credit with its license, its link, the authors of the
    -- shipped marks and that they were modified (documentation-§1 item 12).
    -- red under: drop "Zeromancer" (or any author the shipped AUTHORS.txt names) from the Credits.
    if shipped.gi then
        assertTrue(has(body, "CC BY 3.0"), "Game-icons is credited under CC BY 3.0")
        assertTrue(has(body, "https://game-icons.net"), "Game-icons is linked")
        assertTrue(has(body, "AUTHORS.txt"), "the Credits point at the per-mark authors file")
        assertTrue(has(body, "recolored"), "the Credits say the marks were modified")
        local flat = body:gsub("%s+", " ")
        local authors = read("libs/LibKa0s/media/icons/game-icons/AUTHORS.txt")
        local seen, count = {}, 0
        for author in authors:gmatch("\ngi:[^\t\n]+\t([^\n]+)") do
            if not seen[author] then
                seen[author], count = true, count + 1
                assertTrue(has(flat, author), "README Credits names Game-icons author " .. author)
            end
        end
        assertTrue(count > 0, "AUTHORS.txt lists no mark; nothing above can fail")
    end
    -- red under: name LibKa0s anywhere in the Credits (item 12: credit names the set, never LibKa0s).
    assertFalse(has(body, "LibKa0s"), "README Credits names LibKa0s")
end)

-- ── LICENSE ─────────────────────────────────────────────────────────────────────────────────────

test("credits: LICENSE keeps John Stephen's copyright with the Ka0s line directly under it", function()
    local lines = {}
    for line in (read("LICENSE") .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
    assertEqual(lines[1], "MIT License")
    local at
    for i, line in ipairs(lines) do
        if line == "Copyright (c) 2018 John Stephen" then at = i end
    end
    assertTrue(at ~= nil, "LICENSE keeps `Copyright (c) 2018 John Stephen`")
    assertEqual(lines[(at or 0) + 1], "Copyright (c) 2026 Ka0s")
    assertTrue(has(read("LICENSE"), "The above copyright notice and this permission notice shall be included"),
        "LICENSE is the MIT text")
end)
