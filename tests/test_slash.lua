-- tests/test_slash.lua — the slash descriptor's reserved part (design §4.3): the verb table, bare /of,
-- help and the landing rows, enable/disable through the seam, the debug and perf verbs, the schema
-- CLI, resetall, both chat commands, the H25 macro-conditional routing and the library-absent
-- dispatcher. P4.24 adds the outfit verbs, their parity with the README and the manual, and the
-- legacy command lines (design §9.3).

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local RESERVED = { "help", "config", "skin", "enable", "disable", "list", "get", "set", "reset", "resetall",
    "debug", "diagnostics", "perf", "version" }

local function anyLine(M, needle)
    for _, l in ipairs(M.__printed()) do
        if l:find(needle, 1, true) then return true end
    end
    return false
end

--- The printed lines without the chat tag.
local function bare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[OR%]|r ", "")) end
    return out
end

test("slash: the reserved verbs open NS.COMMANDS, in the DpsRace order", function()
    local names = {}
    for i, row in ipairs(T.NS.COMMANDS) do
        names[i] = row[1]
        assertEqual(type(row[2]), "string", row[1] .. " has no description")
        assertEqual(type(row[3]), "function", row[1] .. " has no handler")
    end
    assertEqual(table.concat(names, ",", 1, #RESERVED), table.concat(RESERVED, ","))
end)

test("slash: bare /of opens the settings panel", function()
    local inst = T.load()
    local opened = 0
    inst.NS.OpenOptionsPanel = function() opened = opened + 1 end
    inst.NS.Slash:OnSlash("")
    assertEqual(opened, 1)
end)

test("slash: help lists every COMMANDS verb, in order", function()
    local inst = T.load()
    inst.mocks.__resetPrinted()
    inst.NS.Slash:OnSlash("help")
    local text = table.concat(inst.mocks.__printed(), "\n")
    local last = 0
    for _, row in ipairs(inst.NS.COMMANDS) do
        local at = text:find("/of " .. row[1], 1, true)
        assertTrue(at ~= nil, "help names " .. row[1])
        assertTrue(at > last, row[1] .. " is in COMMANDS order")
        last = at
    end
end)

test("slash: the landing page's rows come from the same table", function()
    local inst = T.load()
    assertEqual(#inst.NS.Slash:LandingRows(), #inst.NS.COMMANDS)
end)

test("slash: disable and enable write the `enabled` row through the seam and echo it", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    M.__resetPrinted()
    NS.Slash:OnSlash("disable")
    assertEqual(NS.db.profile.enabled, false)
    assertTrue(NS.IsDisabled())
    assertTrue(anyLine(M, "enabled"), "the stored value is echoed")
    NS.Slash:OnSlash("enable")
    assertEqual(NS.db.profile.enabled, true)
    assertFalse(NS.IsStoodDown())
end)

test("slash: `debug on`/`off` flip the session flag; bare `debug` toggles only the window", function()
    local inst = T.load()
    local NS = inst.NS
    NS.Slash:OnSlash("debug on")
    assertTrue(NS.State.debug)
    NS.Slash:OnSlash("debug off")
    assertFalse(NS.State.debug)
    local shown = NS.DebugLog:IsShown()
    NS.Slash:OnSlash("debug")
    assertEqual(NS.DebugLog:IsShown(), not shown)
    assertFalse(NS.State.debug, "the window toggle leaves the flag alone")
    assertEqual(NS.db.profile.debug, nil, "the flag is never stored")
end)

test("slash: `perf` is the host's verb and prints the harness's lines", function()
    local inst = T.load()
    inst.mocks.__resetPrinted()
    inst.NS.Slash:OnSlash("perf")
    assertTrue(#inst.mocks.__printed() > 0)
end)

test("slash: the schema CLI reads and writes through the seam", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    NS.Slash:OnSlash("set visibility never")
    assertEqual(NS.db.profile.visibility, "never")
    M.__resetPrinted()
    NS.Slash:OnSlash("get visibility")
    assertTrue(anyLine(M, "never"))
    NS.Slash:OnSlash("reset visibility")
    assertEqual(NS.GetSetting("visibility"), "always")
end)

test("slash: `list` shows settings rows only", function()
    local inst = T.load()
    local M = inst.mocks
    M.__resetPrinted()
    inst.NS.Slash:OnSlash("list")
    assertTrue(anyLine(M, "visibility"), "list names a settings row")
    assertFalse(anyLine(M, "outfit."), "list reached an outfit row")
end)

test("slash: `resetall` asks first, through the one popup", function()
    local inst = T.load()
    local shown = {}
    inst.mocks.StaticPopup_Show = function(name) shown[#shown + 1] = name end
    inst.NS.Slash:OnSlash("resetall")
    assertEqual(shown[1], "OUTFITTERREBORN_RESET_ALL")
end)

test("slash: /of and /outfitter both reach the dispatcher", function()
    local inst = T.load()
    local M = inst.mocks
    local console = M.LibStub("AceConsole-3.0")
    for _, command in ipairs({ "of", "outfitter" }) do
        assertTrue(console.commands[command] ~= nil, "/" .. command .. " is not registered")
        M.__resetPrinted()
        console:__slash(command, "version")
        assertTrue(anyLine(M, "1.1.0"), "/" .. command .. " did not reach the dispatcher")
    end
end)

test("slash: `skin` is refused with the enable line while disabled; the live verbs still answer", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    assertTrue(NS.SetByPath("enabled", false))
    M.__resetPrinted()
    NS.Slash:OnSlash("skin")
    local out = bare(M)
    assertEqual(#out, 1)
    assertEqual(out[1], NS.Slash:DisabledLine())
    assertEqual(out[1], "Ka0s Outfitter Reborn is disabled \226\128\148 enable it with |cFFFFFF00/of enable|r",
        "the library's DISABLED_LINE_FORMAT")
    M.__resetPrinted()
    NS.Slash:OnSlash("version")
    assertTrue(anyLine(M, "1.1.0"), "version answers while disabled")
end)

-- ── H25: macro conditionals ──────────────────────────────────────────────────────────────────────

--- An instance whose dispatcher only records the message it was handed.
local function routeSpy(mutate)
    local inst = T.load{ mutate = mutate }
    local seen = {}
    inst.NS.Slash.OnSlash = function(_, msg) seen[#seen + 1] = msg end
    return inst, seen
end

test("slash H25: a top-level conditional is decided by the client's parser", function()
    local inst, seen = routeSpy()
    inst.NS.Slash.Route("[combat] version; help")
    assertEqual(seen[1], "help", "out of combat the second clause runs")
    inst.mocks.InCombatLockdown = function() return true end
    inst.NS.Slash.Route("[combat] version; help")
    assertEqual(seen[2], "version", "in combat the first clause runs")
end)

test("slash H25: no matching clause is a silent no-op", function()
    local inst, seen = routeSpy()
    inst.mocks.__resetPrinted()
    inst.NS.Slash.Route("[combat] version")
    assertEqual(#seen, 0, "the dispatcher ran")
    assertEqual(#inst.mocks.__printed(), 0, "a line was printed")
end)

test("slash H25: a message carrying a hyperlink is never parsed", function()
    local inst, seen = routeSpy()
    local link = "iteminfo |cffffffff|Hitem:6948::::::::|h[Hearth; Stone]|h|r"
    inst.NS.Slash.Route(link)
    assertEqual(seen[1], link, "a `;` inside a link split the message")
    inst.NS.Slash.Route("help")
    assertEqual(seen[2], "help", "a plain message passes through untouched")
end)

test("slash H25: an outfit verb's argument is decided alone", function()
    -- `/of wear [spec:1] Tank; DPS`: the message opens with a verb, so the top level passes it whole
    -- and the argument carries its own; modules/Commands.lua (P4.24) decides it here.
    local inst = T.load()
    local Sl, M = inst.NS.Slash, inst.mocks
    assertEqual(Sl.ParseArgument("[spec:1] Tank; DPS"), "Tank")
    M.__spec = 2
    assertEqual(Sl.ParseArgument("[spec:1] Tank; DPS"), "DPS")
    assertEqual(Sl.ParseArgument("[spec:1] Tank"), nil, "no clause: nil")
    assertEqual(Sl.ParseArgument("Tank; DPS"), "Tank; DPS", "an argument not opening with `[` is the name")
    M.__modifiers.shift = true
    assertEqual(Sl.ParseArgument("[mod:shift] Fishing; Normal"), "Fishing")
end)

test("slash H25: a verb's `;` reaches the argument parse whole", function()
    -- Route then ParseArgument, as the outfit verbs (P4.24) will compose them: a top-level split at
    -- the `;` would keep `wear [spec:1] Tank` and drop `; DPS`, a silent no-op on any other spec.
    local inst, seen = routeSpy()
    local Sl, M = inst.NS.Slash, inst.mocks
    M.__spec = 2
    Sl.Route("wear [spec:1] Tank; DPS")
    assertEqual(seen[1], "wear [spec:1] Tank; DPS", "the top level split a verb's argument")
    assertEqual(Sl.ParseArgument((seen[1]:match("^%S+%s+(.*)$"))), "DPS", "the second clause was lost")
    M.__spec = 1
    Sl.Route("wear [spec:1] Tank; DPS")
    assertEqual(Sl.ParseArgument((seen[2]:match("^%S+%s+(.*)$"))), "Tank")
    Sl.Route("version; help")
    assertEqual(seen[3], "version; help", "a `;` with no leading `[` is not a top-level conditional")
end)

test("slash H25: both chat commands are registered on the routing wrapper", function()
    local inst = T.load()
    local M = inst.mocks
    local console = M.LibStub("AceConsole-3.0")
    M.InCombatLockdown = function() return true end
    M.__resetPrinted()
    console:__slash("outfitter", "[nocombat] help; version")
    assertTrue(anyLine(M, "1.1.0"), "the conditional was not routed through the parser")
end)

-- ── the library-absent dispatcher ────────────────────────────────────────────────────────────────

test("slash: the stub's refusal format is byte-equal to the live library's", function()
    local degraded = T.load{ libFiles = {} }
    T.assertLibraryConstant(degraded.NS.Slash.__stubFormat, "LibKa0s-Slash-1.0", "DISABLED_LINE_FORMAT")
end)

test("slash: library absent, /of still answers, and enable/disable still land", function()
    local inst = T.load{ libFiles = {} }
    local NS, M = inst.NS, inst.mocks
    M.__resetPrinted()
    NS.Slash:OnSlash("version")
    assertTrue(anyLine(M, "1.1.0"))
    NS.Slash:OnSlash("disable")
    assertEqual(NS.db.profile.enabled, false)
    assertTrue(NS.IsDisabled(), "the written-through switch still took the hold")
    NS.Slash:OnSlash("enable")
    assertEqual(NS.db.profile.enabled, true)
    assertFalse(NS.IsStoodDown())
    M.__resetPrinted()
    NS.Slash:OnSlash("list")
    assertTrue(anyLine(M, "LibKa0s library did not load"), "the schema CLI names the missing library")
end)

test("slash: the stub's live-verb set is the library's LIVE_VERBS, no more and no less", function()
    local lib = T.mocks.LibStub("LibKa0s-Slash-1.0")
    local want, got = {}, {}
    for _, v in ipairs(lib.LIVE_VERBS) do want[#want + 1] = v end
    for v in pairs(T.NS.SLASH_LIVE_VERBS) do got[#got + 1] = v end
    table.sort(want)
    table.sort(got)
    assertEqual(table.concat(got, ","), table.concat(want, ","))
end)

test("slash: the live dispatcher's live set is the library's LIVE_VERBS and nothing more yet", function()
    -- P4.24 appends auto, zone and iteminfo (design §4.3.2) on both arms.
    local lib = T.mocks.LibStub("LibKa0s-Slash-1.0")
    assertEqual(table.concat(T.NS.Slash.LIVE_VERBS, ","), table.concat(lib.LIVE_VERBS, ","))
end)

test("slash: the stub carries no library string but the refusal format", function()
    -- red under: put a copy of the library's HELP_HEADER, VERSION or UNKNOWN_COMMAND back in the stub
    local strings = T.mocks.LibStub("LibKa0s-Slash-1.0").STRINGS
    local inst = T.load{ libFiles = {} }
    local NS, M = inst.NS, inst.mocks
    M.__resetPrinted()
    for _, verb in ipairs({ "help", "version", "nosuchverb" }) do NS.Slash:OnSlash(verb) end
    local printed = table.concat(M.__printed(), "\n")
    for _, key in ipairs({ "HELP_HEADER", "UNKNOWN_COMMAND", "VERSION" }) do
        local pattern = "^" .. strings[key]:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", ".-") .. "$"
        for line in printed:gmatch("[^\n]+") do
            local b = line:gsub("^|cff00ffff%[OR%]|r ", "")
            assertFalse(b:find(pattern) ~= nil, key .. " copied into the stub: " .. b)
        end
    end
end)
