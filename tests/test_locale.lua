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
-- The six overlays (deDE frFR zhCN zhTW koKR ruRU) are written by tools/rekey-locales.lua from the
-- legacy translations (design §4.6 Re-key, P4.28). Each one's first statement is its own
-- GetLocale() guard, and what it writes is a subset of the enUS keys. Coverage: every field a legacy
-- locale translated (tests/fixtures/legacy/locale_keys.lua) is accounted for by its overlay — a line
-- whose `-- legacy:` note names it, or an `untranslated` / `format mismatch` note — unless the legacy
-- English it translated is one the port retired (LEGACY_RETIRED below). Each kept translation
-- carries the same format directives as its English, so string.format cannot raise on it.
--
-- red under: delete an entry another file reads from any enUS file; or leave an entry behind after
-- its last reader goes; or write one key in two enUS files; or drop a topic line's LOAD-BEARING
-- note; or give a topic file a table of its own; or ungate an overlay, or gate it on another locale;
-- or put a key in an overlay that no enUS file defines; or pass NS.L as a descriptor's `L`; or
-- delete a kept translation's line from an overlay; or keep a field LEGACY_RETIRED lists; or drop a
-- `%s` from a translation.

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

-- The body of a double-quoted literal, unescaped the way Lua 5.1 reads it: the named escapes, \ddd
-- (one to three digits), an escaped newline, and any other escaped character standing for itself.
-- Decoded by hand rather than by compiling `return "..."`: test_no_loadstring (design §9) bans run-
-- time compilation in every file outside libs/, tests/_kit/ and tools/.
local NAMED_ESCAPES = { a = "\a", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", v = "\v" }
local function unescape(raw)
    local out, i = {}, 1
    while i <= #raw do
        local c = raw:sub(i, i)
        if c ~= "\\" then
            out[#out + 1], i = c, i + 1
        else
            local digits = raw:match("^%d%d?%d?", i + 1)
            if digits then
                out[#out + 1], i = string.char(tonumber(digits)), i + 1 + #digits
            else
                local e = raw:sub(i + 1, i + 1)
                out[#out + 1], i = NAMED_ESCAPES[e] or e, i + 2
            end
        end
    end
    return table.concat(out)
end

-- Every routed literal as { file, line, key }, the key unescaped as Lua would read it.
local function routedKeys()
    local out = {}
    for _, rel in ipairs(addonFiles()) do
        local n = 0
        for line in (readFile(rel) .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            for _, raw in ipairs(literals(line)) do
                local key = unescape(raw)
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
-- wrote, in order. The chunk sees GetLocale as a mock over the base globals, compiled by the kit's
-- loader (tests/_kit/ is outside test_no_loadstring's scope; this suite is not).
local function overlayWrites(text, path, clientLocale)
    local written = {}
    local L = setmetatable({}, { __newindex = function(t, k, v)
        written[#written + 1] = k
        rawset(t, k, v)
    end })
    T.Loader.loadSource(text, "@" .. path, { L = L }, { GetLocale = function() return clientLocale end })
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
    -- The hand decoder reads a literal's body the way the compiler does.
    assertEqual(unescape([[a \"b\" \\ \n \65\0669 \q]]), "a \"b\" \\ \n AB9 q", "the unescape")
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

-- ── the re-key (tools/rekey-locales.lua, design §4.6, P4.28) ────────────────────────────────

local function rekeyTool() return dofile(T.root .. "/tools/rekey-locales.lua") end

-- Every legacy English field whose English no enUS file carries: the Dropped, Re-homed and Rewritten
-- lists of design §4.6, and the English the port no longer shows at all. A translation of one of
-- these falls away in the re-key. Written out rather than derived, so a kept translation can never
-- quietly become a retired one, nor a retired one come back, without this list changing with it.
local LEGACY_RETIRED = {}
for _, field in ipairs({
    "_G.BINDING_NAME_OUTFITTER_DISABLEAUTOMATION", "_G.BINDING_NAME_OUTFITTER_ENABLEAUTOMATION",
    "_G.BINDING_NAME_OUTFITTER_OUTFIT", "_G.BINDING_NAME_OUTFITTER_OUTFIT1",
    "_G.BINDING_NAME_OUTFITTER_OUTFIT10", "_G.BINDING_NAME_OUTFITTER_OUTFIT2",
    "_G.BINDING_NAME_OUTFITTER_OUTFIT3", "_G.BINDING_NAME_OUTFITTER_OUTFIT4",
    "_G.BINDING_NAME_OUTFITTER_OUTFIT5", "_G.BINDING_NAME_OUTFITTER_OUTFIT6",
    "_G.BINDING_NAME_OUTFITTER_OUTFIT7", "_G.BINDING_NAME_OUTFITTER_OUTFIT8",
    "_G.BINDING_NAME_OUTFITTER_OUTFIT9", "_G.BINDING_NAME_OUTFITTER_UPDATEOUTFIT", "cABOutfit",
    "cABOutfitDescription", "cAVOutfit", "cAVOutfitDescription", "cAbilityIcons", "cAboutAuthor",
    "cAboutCopyright", "cAboutMaintainer", "cAboutTabTitle", "cAboutThanks", "cAboutTitle",
    "cAccessoryCategoryDescription", "cArenaOutfit", "cArgentDawnOutfit",
    "cArgentDawnOutfitDescription", "cArgentTournamentOutfitDescription", "cAshamanesFallArenaOutfit",
    "cAshamanesFallArenaOutfitDescription", "cAshranOutfit", "cAshranOutfitDescription",
    "cAutoChangesDisabled", "cAutoChangesEnabled", "cAutoSwitch", "cAutoSwitchOffDescription",
    "cAutoSwitchOnDescription", "cAutomation", "cBankedItemsLabel", "cBlackRookArenaOutfit",
    "cBlackRookArenaOutfitDescription", "cBladesEdgeArenaOutfit", "cBladesEdgeArenaOutfitDescription",
    "cBoEsCategoryDescription", "cBuild", "cCageOfCarnageArenaOutfit",
    "cCageOfCarnageArenaOutfitDescription", "cCantReloadUI", "cCantSetIcon",
    "cCantUnequipCompleteError", "cChangeIcon", "cChineseLocalization", "cChooseIconTitle",
    "cCityOutfit", "cCityOutfitDescription", "cCombatHealthRegenStatName", "cCombatManaRegenStatName",
    "cCompleteCategoryDescription", "cConfirmDeleteMsg", "cConfirmResetMsg", "cConfirmSetCurrentMsg",
    "cContributingDeveloper", "cCreateUsingTitle", "cDeephaulRavineOutfit",
    "cDeephaulRavineOutfitDescription", "cDeepwindGorgeOutfit", "cDeepwindGorgeOutfitDescription",
    "cDepositToVoidStorage", "cDepositUniqueToVoidStorage", "cDiningOutfitDescription",
    "cDisableAlways", "cDisableIn", "cDisableOutfit", "cDisableOutfitInAQ40", "cDisableOutfitInBG",
    "cDisableOutfitInCombat", "cDisableOutfitInNaxx", "cDisableScript", "cDontChange",
    "cDragonFlightCompatiblity", "cDruidAquaticForm", "cDruidFlightForm", "cDruidSwiftFlightForm",
    "cEditScriptEllide", "cEditScriptTitle", "cEmpyreanDomainArenaOutfit",
    "cEmpyreanDomainArenaOutfitDescription", "cEnableAll", "cEnableNone", "cEnigmaCrucibleArenaOutfit",
    "cEnigmaCrucibleArenaOutfitDescription", "cEotSOutfit", "cEotSOutfitDescription",
    "cEquipOutfitMessageFormat", "cEventsLabel", "cEveryIcon", "cExtractErrorFormat",
    "cFinger0SlotName", "cFinger1SlotName", "cFishingOutfitDescription", "cFlyingMountSpeedFormat",
    "cFrenchLocalization", "cGermanLocalization", "cGilneasOutfit", "cGilneasOutfitDescription",
    "cGlobalCategory", "cGuildCreditFormat", "cHasBuffDescription", "cHasDebuffDescription",
    "cHasDebuffOutfit", "cHide", "cHookPointArenaOutfit", "cHookPointArenaOutfitDescription",
    "cIconFilterLabel", "cIconSetLabel", "cInfo", "cInsertFormat", "cIoCOutfit",
    "cIoCOutfitDescription", "cItemComparisons", "cItemComparisonsOffDescription",
    "cItemComparisonsOnDescription", "cItemIcons", "cItemLevelName", "cKeyBinding",
    "cKoreanLocalization", "cLordaeronArenaOutfit", "cLordaeronArenaOutfitDescription",
    "cLowHealthDescription", "cLowHealthOutfit", "cMageEvocate", "cMageEvocateDescription",
    "cMaldraxxusArenaOutfit", "cMaldraxxusArenaOutfitDescription", "cMinimapButtonDescription",
    "cMinimapButtonTitle", "cMissingItemReportIntro", "cMissingItemsLabel", "cMissingItemsSeparator",
    "cMountSpeedFormat", "cMugambalaArenaOutfit", "cMugambalaArenaOutfitDescription",
    "cMultiItemFormat", "cNagrandArenaOutfit", "cNagrandArenaOutfitDescription",
    "cNameAlreadyUsedError", "cNoScriptSettings", "cNokhudonArenaOutfit",
    "cNokhudonArenaOutfitDescription", "cOddsNEndsCategoryDescription", "cOpenOutfitter",
    "cOptionsTabTitle", "cOptionsTitle", "cOutfitBarAlphaLabel", "cOutfitBarCombatAlphaLabel",
    "cOutfitBarHideBackgroundLabel", "cOutfitBarLargeSizeLabel", "cOutfitBarLockPositionLabel",
    "cOutfitBarSizeLabel", "cOutfitBarSmallSizeLabel", "cOutfitBarVerticalLabel",
    "cOutfitCategoryTitle", "cOutfitDisplay", "cOutfitterDecides", "cPositionLockedError",
    "cPresetScript", "cPriestShadowform", "cPriestShadowformDescription", "cProwl", "cRequiresPrefix",
    "cReset", "cResistCategory", "cRobodromeArenaOutfit", "cRobodromeArenaOutfitDescription",
    "cRussianLocalization", "cScriptErrorFormat", "cScriptFormat", "cScriptLabel", "cScriptSettings",
    "cSeethingShoreOutfit", "cSeethingShoreOutfitDescription", "cSettings", "cSewersOutfit",
    "cSewersOutfitDescription", "cShow", "cShowHotkeyMessages", "cShowHotkeyMessagesOffDescription",
    "cShowHotkeyMessagesOnDescription", "cShowInCombat", "cShowMinimapButton",
    "cShowMinimapButtonOffDescription", "cShowMinimapButtonOnDescription", "cShowOutfitBarDescription",
    "cSilvershardMinesOutfit", "cSilvershardMinesOutfitDescription", "cSilverwingHold",
    "cSingleItemFormat", "cSlotEnableDescription", "cSlotEnableTitle", "cSoloOutfit",
    "cSoloOutfitDescription", "cSotAOutfit", "cSotAOutfitDescription", "cSource",
    "cSpanishLocalization", "cSpellbookIcons", "cSpiritOutfitDescription", "cStats", "cStoreOnServer",
    "cStoreOnServerOffDescription", "cStoreOnServerOnDescription", "cSuggestedIcons", "cTankPoints",
    "cTempleOfKotmoguOutfit", "cTempleOfKotmoguOutfitDescription", "cTester", "cTigersPeakArenaOutfit",
    "cTigersPeakArenaOutfitDescription", "cTitleVersion", "cTolVironArenaOutfit",
    "cTolVironArenaOutfitDescription", "cTooManyServerOutfits", "cTooltipInfo",
    "cTooltipInfoOffDescription", "cTooltipInfoOnDescription", "cTooltipMultibuffSeparator1",
    "cTooltipMultibuffSeparator2", "cTotalStatsName", "cTradeCategory", "cTrinket0SlotName",
    "cTrinket1SlotName", "cTwinPeaksOutfit", "cTwinPeaksOutfitDescription", "cTwoItemFormat",
    "cTyping", "cUnequipOutfitMessageFormat", "cUniqueEquippedSearchPattern", "cUseCurrentOutfit",
    "cUseEmptyOutfit", "cUseTooltipLineFormat", "cVersion", "cVoidStorageCategoryTitle", "cWSGOutfit",
    "cWSGOutfitDescription", "cWarboundCategoryDescription", "cWarsongLumberMill",
    "cWintergraspOutfit", "cWintergraspOutfitDescription", "cWithdrawFromVoidStorage",
    "cYourItemIcons",
}) do LEGACY_RETIRED[field] = true end

-- The legacy capture: { [locale] = { [field] = true } }; enUS is the legacy English file.
local function legacyFields()
    local fixture = dofile(T.root .. "/tests/fixtures/legacy/locale_keys.lua")
    local out = {}
    for _, f in ipairs(fixture.files) do
        local set = {}
        for _, k in ipairs(f.keys) do set[k] = true end
        out[f.locale] = set
    end
    return out, fixture.commit
end

local function splitFields(list, into)
    for field in list:gmatch("[^,]+") do into[(field:gsub("^%s+", ""):gsub("%s+$", ""))] = true end
end

-- The legacy fields one overlay accounts for: each `L[...] = ... -- legacy: a, b` line's fields, and
-- the `-- untranslated:` / `-- format mismatch:` notes' fields.
local function accounted(text)
    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        local kept = line:match("^L%[.*%-%- legacy: ([%w_%.,%s]+)$")
        local noted = line:match("^%-%- untranslated: (.+)$") or line:match("^%-%- format mismatch: (.+)$")
        if kept then splitFields(kept, out) end
        if noted then splitFields(noted, out) end
    end
    return out
end

-- One overlay's coverage problems, appended to `out`: a field the legacy locale translated (`want`)
-- from English it did not retire that the overlay does not account for (`have`), a retired field it
-- keeps, and a field the legacy locale never translated.
local function coverageProblems(rel, have, want, english, out)
    for field in pairs(want) do
        if english[field] and not LEGACY_RETIRED[field] and not have[field] then
            out[#out + 1] = rel .. ": " .. field .. " was translated and is not re-keyed"
        end
    end
    for field in pairs(have) do
        if LEGACY_RETIRED[field] then
            out[#out + 1] = rel .. ": " .. field .. " is retired but kept"
        elseif not want[field] and not field:match("^c%u%w*%.%w+$") then
            -- A table field (cScriptCategoryName.PVP) is unfolded by the tool; the capture records a
            -- table only when it is assigned whole.
            out[#out + 1] = rel .. ": " .. field .. " is not a field the legacy locale translated"
        end
    end
end

test("rekey: the tool names the conversion base the legacy capture was taken at", function()
    local M = rekeyTool()
    local _, commit = legacyFields()
    assertEqual(M.BASE, commit, "tools/rekey-locales.lua reads the commit tests/fixtures/legacy/ captured")
    local locales = {}
    for _, spec in ipairs(M.LOCALES) do locales[#locales + 1] = spec.locale end
    assertEqual(table.concat(locales, " "), "deDE frFR zhCN zhTW koKR ruRU", "the six overlays, in TOC order")
end)

test("rekey: a translation is kept only when its English is an enUS key and its directives match", function()
    local M = rekeyTool()
    local english = { cA = "New Outfit", cB = "Gone", cC = "%s equipped", cD = "Name:", cE = "None", cF = "None" }
    local overlay = { cA = "Neues Outfit", cB = "Weg", cC = "ausgerüstet", cD = "Name:", cE = "Keins",
        cF = "Nichts", cZ = "Waise" }
    local keys = { ["New Outfit"] = true, ["%s equipped"] = true, ["Name:"] = true, None = true }
    local r = M.rekey(english, function(s) return keys[s] == true end, overlay)
    assertEqual(r.entries["New Outfit"].text, "Neues Outfit", "an English match is kept")
    assertEqual(r.entries.Gone, nil, "a retired English is not kept")
    assertEqual(table.concat(r.dropped, ","), "cB", "the retired field is reported dropped")
    assertEqual(table.concat(r.orphaned, ","), "cZ", "a field with no legacy English is orphaned")
    assertEqual(table.concat(r.formats, ","), "cC", "a translation that lost its %s is held back")
    assertEqual(table.concat(r.untranslated, ","), "cD", "a translation equal to its English gets no line")
    assertEqual(r.entries.None.text, "Keins", "the first field in sorted order wins a shared English")
    assertEqual(table.concat(r.entries.None.fields, ","), "cE,cF", "both fields are named on the line")
    assertEqual(table.concat(r.conflicts, ","), "cF (kept cE)", "the loser is reported")
end)

test("rekey: format directives compare as a multiset, %% left out", function()
    local M = rekeyTool()
    assertEqual(M.formats("%s and %d%%"), M.formats("%d und %s"), "reordered directives match")
    assertTrue(M.formats("%s and %s") ~= M.formats("%s"), "a lost %s is caught")
    assertEqual(M.formats("Next update in %.1f s"), "f", "a precision directive")
    assertEqual(M.formats("100%%"), "", "%% is not a directive")
end)

test("rekey: a rendered overlay is gated first, notes its fields, and writes only on its locale", function()
    local M = rekeyTool()
    local r = { entries = { ['Say "hi"\n'] = { text = 'Sag "hallo"\n', fields = { "cHi" } } },
        untranslated = { "cName" }, formats = { "cFmt" } }
    local text = M.render("deDE", "OutfitterStrings_de.lua", r)
    assertEqual(text:match("^[^\r\n]*"), gateLine("deDE"), "the gate is the first line")
    assertFalse(text:find("[^\r]\n") ~= nil, "every line ends CRLF")
    local seen = accounted(text)
    assertTrue(seen.cHi and seen.cName and seen.cFmt, "the line's note and both end notes are read back")
    assertEqual(#overlayWrites(text, "probe.lua", "enUS"), 0, "the rendered gate holds on enUS")
    local NS = { L = {} }
    T.Loader.loadSource(text, "@probe.lua", NS, { GetLocale = function() return "deDE" end })
    assertEqual(NS.L['Say "hi"\n'], 'Sag "hallo"\n', "the quoting round-trips")
end)

test("locale: each overlay covers the legacy translations it re-keys", function()
    local legacy = legacyFields()
    -- Mutation self-test: the note reader sees a line's fields and the end notes, nothing else.
    local probe = accounted('L["A"] = "B -- legacy: cX" -- legacy: cA, cB\r\n-- untranslated: cC\r\n-- cD\r\n')
    assertTrue(probe.cA and probe.cB and probe.cC, "the note reader")
    assertFalse(probe.cD or probe.cX, "the note reader reads a stray comment or a string's text")

    for field in pairs(LEGACY_RETIRED) do
        assertTrue(legacy.enUS[field], "LEGACY_RETIRED names " .. field .. ", which the legacy English never had")
    end
    local problems = {}
    for _, o in ipairs(overlayFiles()) do
        assertTrue(legacy[o.locale] ~= nil, o.rel .. " has no legacy capture")
        coverageProblems(o.rel, accounted(readFile(o.rel)), legacy[o.locale] or {}, legacy.enUS, problems)
    end
    table.sort(problems)
    assertEqual(#problems, 0, #problems .. " coverage problem(s):\n" .. table.concat(problems, "\n", 1, math.min(#problems, 20)))
end)

test("locale: every overlay translation carries its English's format directives", function()
    local M = rekeyTool()
    local bad = {}
    for _, o in ipairs(overlayFiles()) do
        local NS = { L = {} }
        T.Loader.loadSource(readFile(o.rel), "@" .. o.rel, NS, { GetLocale = function() return o.locale end })
        for key, text in pairs(NS.L) do
            if M.formats(key) ~= M.formats(text) then bad[#bad + 1] = o.rel .. ": " .. key end
        end
    end
    table.sort(bad)
    assertEqual(#bad, 0, #bad .. " translation(s) whose directives differ:\n" .. table.concat(bad, "\n", 1, math.min(#bad, 20)))
end)

test("locale: the overlays carry the legacy translations", function()
    -- The re-key is not an empty pass: each overlay keeps a share of what its legacy file translated.
    for _, o in ipairs(overlayFiles()) do
        local n = 0
        for _ in pairs(accounted(readFile(o.rel))) do n = n + 1 end
        assertTrue(n >= 40, o.rel .. " accounts for only " .. n .. " legacy field(s)")
    end
end)
