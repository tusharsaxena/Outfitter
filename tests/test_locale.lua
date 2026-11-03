-- tests/test_locale.lua — the locale gates (design §4.6; localization-§1, §3, §6).
--
-- NS.L is ONE table that locales/enUS.lua creates and its topic files (locales/enUS_Triggers.lua,
-- locales/enUS_Window.lua) fill. Every gate here measures the union of the enUS files, and the list
-- of them is read from the TOC, never written by hand: a topic file added later is read without
-- editing this suite. The files load in TOC order into one namespace, and the table is read RAW, so
-- the key-on-miss fallback cannot answer for a missing key. A key written in two files is found from
-- the files' text, because the loaded table keeps only the last write.
--
-- Both directions: every literal `L["..."]` / `NS.L["..."]` in an addon file has an enUS entry, and
-- every enUS key appears as a literal somewhere in the addon's files (localization-§3: enUS keeps no
-- key nothing reads).
--
-- The six overlays (deDE frFR zhCN zhTW koKR ruRU) carry only their gate line until the re-key
-- (P4.28). Their gates already hold: each one's first statement is its own GetLocale() guard, and
-- what it writes is a subset of the enUS keys. Coverage against the legacy translations is P4.28's.
--
-- red under: delete an entry another file reads from any enUS file; or leave an entry behind after
-- its last reader goes; or write one key in two enUS files; or drop a topic line's LOAD-BEARING
-- note; or give a topic file a table of its own; or ungate an overlay, or gate it on another locale;
-- or put a key in an overlay that no enUS file defines; or pass NS.L as a descriptor's `L`.

local T = _G.OUTFITTERREBORN_TEST
local test, assertTrue, assertEqual, assertFalse = T.test, T.assertTrue, T.assertEqual, T.assertFalse

local TOC = T.root .. "/OutfitterReborn.toc"

local function readFile(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "rb"))
    local text = f:read("*a")
    f:close()
    return (text:gsub("\r\n", "\n"))
end

-- Every TOC line, CR stripped.
local function tocLines()
    local f = assert(io.open(TOC, "r"))
    local lines = {}
    for line in f:lines() do lines[#lines + 1] = (line:gsub("\r$", "")) end
    f:close()
    return lines
end

local function isEnUS(rel) return rel == "locales/enUS.lua" or rel:match("^locales/enUS_.+%.lua$") ~= nil end

-- The enUS files, from the TOC in its order (localization-§6).
local function enUSFiles()
    local out = {}
    for _, rel in ipairs(T.Loader.tocFiles(TOC)) do
        if isEnUS(rel) then out[#out + 1] = rel end
    end
    return out
end
local ENUS_FILES = enUSFiles()

-- Every other locale's files, from the TOC: { rel, locale }.
local function overlayFiles()
    local out = {}
    for _, rel in ipairs(T.Loader.tocFiles(TOC)) do
        local loc = rel:match("^locales/(%l%l%u%u)[%w_]*%.lua$")
        if loc and loc ~= "enUS" then out[#out + 1] = { rel = rel, locale = loc } end
    end
    return out
end

-- The addon's own files in TOC order, less the locales (libs/ never reach tocFiles).
local function addonFiles()
    local out = {}
    for _, rel in ipairs(T.Loader.tocFiles(TOC)) do
        if not rel:match("^locales/") then out[#out + 1] = rel end
    end
    return out
end

-- One file's key lines as { path, line, raw }, the key as written with its quotes kept.
local function keyLinesOf(path, text)
    local out, n = {}, 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        local raw = line:match('^L%[(".-")%]%s*=')
        if raw then out[#out + 1] = { path = path, line = n, raw = raw } end
    end
    return out
end

local function keyLines()
    local out = {}
    for _, path in ipairs(ENUS_FILES) do
        for _, k in ipairs(keyLinesOf(path, readFile(path))) do out[#out + 1] = k end
    end
    return out
end

-- Repeated raw keys across a key-line list, each "path:line: key, first at path:line".
local function duplicates(lines)
    local seen, dups = {}, {}
    for _, k in ipairs(lines) do
        local at = k.path .. ":" .. k.line
        if seen[k.raw] then dups[#dups + 1] = at .. ": " .. k.raw .. ", first at " .. seen[k.raw]
        else seen[k.raw] = at end
    end
    return dups
end

-- The enUS table, loaded in TOC order into one namespace, read raw (metatable stripped).
local function enUS()
    local NS = {}
    for _, path in ipairs(ENUS_FILES) do assert(loadfile(T.root .. "/" .. path))("OutfitterReborn", NS) end
    assertTrue(type(NS.L) == "table", "locales/enUS.lua publishes NS.L")
    return NS.L
end

-- The raw (still escaped) bodies of every `L["..."]` on one line, `NS.L[` included. A backslash
-- takes the next byte with it, and an unescaped quote closes the literal, which must be followed by
-- `]` to count.
local function literals(line)
    local out, pos = {}, 1
    while true do
        local s = line:find('L["', pos, true)
        if not s then return out end
        local before = s > 1 and line:sub(s - 1, s - 1) or ""
        local i, closed = s + 3, nil
        while i <= #line do
            local c = line:sub(i, i)
            if c == "\\" then i = i + 2
            elseif c == '"' then closed = i; break
            else i = i + 1 end
        end
        if closed and line:sub(closed + 1, closed + 1) == "]" and not before:match("[%w_]") then
            out[#out + 1] = line:sub(s + 3, closed - 1)
        end
        pos = (closed or #line) + 1
    end
end

-- Every routed literal as { file, line, key }, the key unescaped as Lua would read it.
local function routedKeys()
    local out = {}
    for _, rel in ipairs(addonFiles()) do
        local n = 0
        for line in (readFile(rel) .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            for _, raw in ipairs(literals(line)) do
                local key = assert(loadstring('return "' .. raw .. '"'))()
                out[#out + 1] = { file = rel, line = n, key = key }
            end
        end
    end
    return out
end

-- The first statement of a chunk: its first line that is neither blank nor a comment.
local function firstStatement(text)
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line:find("%S") and not line:find("^%s*%-%-") then return line end
    end
    return nil
end

local function gateLine(locale)
    return 'if GetLocale() ~= "' .. locale .. '" then return end'
end

-- An overlay run on a client of `clientLocale`, writing into a fresh recording NS.L: the keys it
-- wrote, in order. The chunk sees only GetLocale beyond the base globals.
local function overlayWrites(text, path, clientLocale)
    local written = {}
    local L = setmetatable({}, { __newindex = function(t, k, v)
        written[#written + 1] = k
        rawset(t, k, v)
    end })
    local chunk = assert(loadstring(text, "@" .. path))
    setfenv(chunk, setmetatable({ GetLocale = function() return clientLocale end }, { __index = _G }))
    chunk("OutfitterReborn", { L = L })
    return written
end

-- Each place a code line hands NS.L (or the local `L` bound to it) to a field named `L`: the
-- descriptor trap (BP §4) — the fallback answers EVERY key and shadows the library's own strings.
local function descriptorLHandoffs(text)
    local hits, n = {}, 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        local code = line:gsub("%-%-.*$", "")
        local s = 1
        while true do
            local a, b, rhs = code:find("%f[%w_]L%s*=%s*([%w_%.]+)", s)
            if not a then break end
            local lead = code:sub(1, a - 1)
            local isLocal = lead:match("local%s+$") ~= nil
            if not isLocal and (rhs == "NS.L" or rhs == "L") then hits[#hits + 1] = n end
            s = b + 1
        end
    end
    return hits
end

-- Legacy strings the port retires (design §4.6, Dropped): no locale key may carry one. Matched as
-- plain substrings of a key, case-sensitive. The re-key (P4.28) is what would bring them back.
local RETIRED = {
    "Argent Dawn", "Low Health", "Has Debuff", "Void Storage", "TankPoints", "FuBar",
    "Error at line", "Typing", "{{",
}

local function retiredHits(keys)
    local hits = {}
    for _, key in ipairs(keys) do
        for _, s in ipairs(RETIRED) do
            if key:find(s, 1, true) then hits[#hits + 1] = key .. " (" .. s .. ")" end
        end
        -- A legacy field name (cFoo) is the old key, not an English string: the re-key unfolds it.
        if key:match("^c%u%w*$") then hits[#hits + 1] = key .. " (a legacy cFoo field name)" end
    end
    return hits
end

test("locale: the enUS files are the TOC's, the base first and its topic files contiguous after it", function()
    assertTrue(#ENUS_FILES >= 3, "the TOC lists locales/enUS.lua and both topic files")
    assertEqual(ENUS_FILES[1], "locales/enUS.lua", "the base file is the TOC's first enUS line")
    local toc = T.Loader.tocFiles(TOC)
    local start
    for i, rel in ipairs(toc) do if rel == "locales/enUS.lua" then start = i break end end
    assertTrue(start ~= nil, "locales/enUS.lua is in the TOC")
    for i, path in ipairs(ENUS_FILES) do
        assertEqual(toc[start + i - 1], path, path .. " sits in the contiguous block the base file opens")
    end
    -- Every other locale loads after all of enUS.
    for _, o in ipairs(overlayFiles()) do
        local at
        for i, rel in ipairs(toc) do if rel == o.rel then at = i end end
        assertTrue(at > start + #ENUS_FILES - 1, o.rel .. " loads after every enUS file")
    end
end)

test("locale: a topic file is named enUS_<Topic> and fills the base file's NS.L, keeping no table", function()
    local topics = 0
    for i, path in ipairs(ENUS_FILES) do
        if i > 1 then
            topics = topics + 1
            assertTrue(path:match("^locales/enUS_%u%w*%.lua$") ~= nil, path .. " is named enUS_<Topic>")
            local text = readFile(path)
            assertTrue(text:find("\nlocal L = NS%.L\n") ~= nil, path .. " binds local L = NS.L")
            assertFalse(text:find("NS%.L%s*=") ~= nil, path .. " assigns NS.L")
            assertFalse(text:find("setmetatable", 1, true) ~= nil, path .. " sets a metatable")
        end
    end
    assertEqual(topics, 2, "the topic files are enUS_Triggers.lua and enUS_Window.lua (design §4.6)")
    local base = readFile("locales/enUS.lua")
    assertTrue(base:find("\nNS%.L = L\n") ~= nil, "locales/enUS.lua is the one file that creates NS.L")
end)

test("locale: each enUS line in the TOC carries its LOAD-BEARING note", function()
    local lines = tocLines()
    local checked = 0
    for i, line in ipairs(lines) do
        local rel = line:gsub("\\", "/")
        if isEnUS(rel) then
            checked = checked + 1
            local note = lines[i - 1] or ""
            assertTrue(note:find("^# LOAD%-BEARING:") ~= nil, line .. " has no LOAD-BEARING note directly above it")
            if rel == "locales/enUS.lua" then
                assertTrue(note:find("creates NS.L", 1, true) ~= nil, "the base note says it creates NS.L")
            else
                assertTrue(note:find("reads NS.L", 1, true) ~= nil and note:find("locales\\enUS.lua", 1, true) ~= nil,
                    line .. "'s note names what it reads (NS.L) and from which file (locales\\enUS.lua)")
            end
        end
    end
    assertEqual(checked, #ENUS_FILES, "a TOC enUS line went unread")
end)

test("locale: every enUS key lives in exactly one enUS file", function()
    -- Mutation self-test: the scan sees a key written twice across two files, and nothing else.
    local probe = {}
    for _, k in ipairs(keyLinesOf("a.lua", 'L["One"] = "One"\nL["Two"] = "Two"\n')) do probe[#probe + 1] = k end
    for _, k in ipairs(keyLinesOf("b.lua", 'L["Two"] = "Two"\n')) do probe[#probe + 1] = k end
    assertEqual(#duplicates(probe), 1, "the duplicate scan misses a cross-file repeat")

    local dups = duplicates(keyLines())
    assertEqual(#dups, 0, #dups .. " enUS key(s) written twice:\n" .. table.concat(dups, "\n", 1, math.min(#dups, 20)))
end)

test("locale: the scan finds the routed literals in the addon's files", function()
    assertTrue(#routedKeys() > 30, "expected the scan to find the addon's L[...] call sites")
    assertEqual(#literals('x = L["a \\"b\\""] .. NS.L["c"] .. LL["d"]'), 2, "the literal scan")
end)

test("locale: the enUS union carries every string routed through NS.L", function()
    local L = enUS()
    local missing = {}
    for _, use in ipairs(routedKeys()) do
        if rawget(L, use.key) == nil then
            missing[#missing + 1] = ('%s:%d: missing enUS key "%s"'):format(use.file, use.line, use.key)
        end
    end
    assertEqual(#missing, 0, #missing .. " routed key(s) missing from every enUS file:\n"
        .. table.concat(missing, "\n", 1, math.min(#missing, 20)))
end)

test("locale: every enUS key is still read by the addon's files", function()
    local parts = {}
    for _, rel in ipairs(addonFiles()) do parts[#parts + 1] = readFile(rel) end
    local src = table.concat(parts, "\n")
    local orphans = {}
    for _, k in ipairs(keyLines()) do
        if not src:find(k.raw, 1, true) then orphans[#orphans + 1] = k.path .. ":" .. k.line .. ": " .. k.raw end
    end
    assertEqual(#orphans, 0, #orphans .. " enUS key(s) nothing reads:\n"
        .. table.concat(orphans, "\n", 1, math.min(#orphans, 20)))
end)

test("locale: the overlays are the six the port ships, each gated on its own locale first", function()
    local want = { deDE = true, frFR = true, zhCN = true, zhTW = true, koKR = true, ruRU = true }
    local got = {}
    for _, o in ipairs(overlayFiles()) do
        got[o.locale] = true
        assertTrue(want[o.locale] ~= nil, o.rel .. " is not one of the six overlays (no esES ships, design §4.6)")
        local text = readFile(o.rel)
        assertEqual(firstStatement(text), gateLine(o.locale), o.rel .. "'s first statement is its own gate")
        -- The gate holds: on an enUS client the overlay writes nothing.
        assertEqual(#overlayWrites(text, o.rel, "enUS"), 0, o.rel .. " writes on an enUS client")
    end
    for loc in pairs(want) do assertTrue(got[loc], "locales/" .. loc .. ".lua is missing from the TOC") end

    -- Mutation self-test: an ungated overlay writes on every client; a gate on another locale passes
    -- the first-statement check for nobody.
    assertEqual(#overlayWrites('local _, NS = ...\nNS.L["Yes"] = "Ja"\n', "probe.lua", "enUS"), 1)
    assertFalse(firstStatement('-- x\nif GetLocale() ~= "frFR" then return end\n') == gateLine("deDE"))
end)

test("locale: an overlay writes only keys an enUS file defines", function()
    local L = enUS()
    local function strays(text, path, locale)
        local out = {}
        for _, key in ipairs(overlayWrites(text, path, locale)) do
            if rawget(L, key) == nil then out[#out + 1] = path .. ': "' .. tostring(key) .. '"' end
        end
        return out
    end
    -- Mutation self-test: a translation of a key no enUS file defines is caught; one it defines is not.
    local probe = 'if GetLocale() ~= "deDE" then return end\nlocal _, NS = ...\nNS.L["Yes"] = "Ja"\nNS.L["Nope"] = "x"\n'
    assertEqual(#strays(probe, "probe.lua", "deDE"), 1, "the overlay-key check")

    local all = {}
    for _, o in ipairs(overlayFiles()) do
        for _, s in ipairs(strays(readFile(o.rel), o.rel, o.locale)) do all[#all + 1] = s end
    end
    assertEqual(#all, 0, #all .. " overlay key(s) with no enUS entry:\n" .. table.concat(all, "\n", 1, math.min(#all, 20)))
end)

test("locale: no locale key carries a retired string", function()
    assertEqual(#retiredHits({ "Low Health outfit", "cAutoSwitch", "Yes" }), 2, "the retired-string check")
    local keys = {}
    for k in pairs(enUS()) do keys[#keys + 1] = k end
    for _, o in ipairs(overlayFiles()) do
        for _, k in ipairs(overlayWrites(readFile(o.rel), o.rel, o.locale)) do keys[#keys + 1] = k end
    end
    local hits = retiredHits(keys)
    assertEqual(#hits, 0, #hits .. " retired key(s):\n" .. table.concat(hits, "\n", 1, math.min(#hits, 20)))
end)

test("locale: NS.L is never handed to a descriptor's L", function()
    -- Mutation self-test: a descriptor field set to NS.L or the local L is caught; the binding is not.
    assertEqual(#descriptorLHandoffs("local L = NS.L\n"), 0)
    assertEqual(#descriptorLHandoffs("local d = { title = 'x', L = NS.L }\n"), 1)
    assertEqual(#descriptorLHandoffs("desc.L = L\n"), 1)
    assertEqual(#descriptorLHandoffs("-- never { L = NS.L }\n"), 0)

    local hits = {}
    for _, rel in ipairs(addonFiles()) do
        for _, n in ipairs(descriptorLHandoffs(readFile(rel))) do hits[#hits + 1] = rel .. ":" .. n end
    end
    assertEqual(#hits, 0, "NS.L passed as a descriptor L at " .. table.concat(hits, ", "))
end)

test("locale: each overlay covers the legacy translations it re-keys",
    function() end,
    "pending P4.28: the overlays carry only their gate line until tools/rekey-locales.lua writes them; "
        .. "the case then holds each locale at or above fixtures/legacy/locale_keys.lua less the retired keys")
