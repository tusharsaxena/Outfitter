-- tests/test_slash.lua — the slash descriptor's reserved part (design §4.3): the verb table, bare /of,
-- help and the landing rows, enable/disable through the seam, the debug and perf verbs, the schema
-- CLI, resetall, both chat commands, the H25 macro-conditional routing and the library-absent
-- dispatcher; then (P4.24) the outfit verbs of design §4.3.2 on the real modules: their order, their
-- parity with /of help, the README's Usage and the user manual, the live set on both arms, the
-- outfit-argument rules, the lines legacy printed (fixtures/legacy/commands.lua), the old-verb table
-- and each verb's route. NS.Popups lands with P4.21 (parallel, group J): the deleteall case fakes it
-- (design §12, the fake rule).

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

test("slash: the live dispatcher's live set is the library's LIVE_VERBS, then auto, zone and iteminfo", function()
    -- red under: drop "zone" from HOST_LIVE_VERBS in settings/Slash.lua
    local lib = T.mocks.LibStub("LibKa0s-Slash-1.0")
    assertEqual(table.concat(T.NS.Slash.LIVE_VERBS, ","), table.concat(lib.LIVE_VERBS, ",") .. ",auto,zone,iteminfo")
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

-- ── the outfit verbs (P4.24, design §4.3.2) ──────────────────────────────────────────────────────

local OUTFIT_VERBS = { "show", "hide", "wear", "unwear", "toggle", "update", "deposit", "depositunique",
    "depositothers", "withdraw", "withdrawothers", "missing", "unequip", "updatetitle", "auto", "zone",
    "iteminfo", "test", "lock", "unlock", "deleteall" }

--- A fresh instance at t = 100 on a gear scenario, PlayerState, Inventory and Equip resumed and the
--- first scan settled (the bank frame opened when `opened`). Every other module is the real one.
local function scene(scenario, opened)
    local inst = T.load({ mutate = function(M) M.__gear:load(scenario or "geared") end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Inventory.Resume()
    NS.Equip.Resume()
    if opened then M.__gear:openBank() end
    M.__fireTimers()
    NS.Inventory.Sync()
    M.__resetPrinted()
    return NS, M
end

--- Every worn slot as an outfit stores it (the empty marker for an empty slot): a Complete outfit.
local function wornItems(NS)
    local items = {}
    for _, s in ipairs(NS.ItemData.SLOT_NAMES) do
        local info = NS.ItemInfo.FromSlot(s)
        items[s] = info and NS.ItemInfo.Snapshot(info) or { id = 0 }
    end
    return items
end

--- Wrap `tbl[name]` so its calls are recorded and still run: the real module answers.
local function spy(tbl, name)
    local calls, real = {}, tbl[name]
    tbl[name] = function(...)
        calls[#calls + 1] = { ... }
        return real(...)
    end
    return calls
end

local function readSource(path)
    local f = assert(io.open(T.root .. "/" .. path, "rb"))
    local src = f:read("*a")
    f:close()
    return src
end

--- The `## <heading>` section of a markdown file, up to the next `## `.
local function section(path, heading)
    local text = readSource(path)
    local from = assert(text:find("\n## " .. heading .. "\r?\n"), path .. " has no ## " .. heading)
    local to = text:find("\n## ", from + 1, true)
    return text:sub(from, to and (to - 1) or #text)
end

test("slash: the outfit verbs follow the reserved ones, in design §4.3.2's order", function()
    local names = {}
    for i = #RESERVED + 1, #T.NS.COMMANDS do names[#names + 1] = T.NS.COMMANDS[i][1] end
    assertEqual(table.concat(names, ","), table.concat(OUTFIT_VERBS, ","))
end)

test("slash: every verb is in /of help, the README's Usage and the user manual", function()
    -- red under: drop the `/of zone` row from docs/users-manual.md's Slash commands table
    local inst = T.load()
    inst.mocks.__resetPrinted()
    inst.NS.Slash:OnSlash("help")
    local help = table.concat(inst.mocks.__printed(), "\n") .. "\n"
    local usage = section("README.md", "Usage")
    local manual = section("docs/users-manual.md", "Slash commands")
    for _, row in ipairs(inst.NS.COMMANDS) do
        local want = "/of " .. row[1]
        assertTrue(help:find(want .. "[^%w]") ~= nil, "help lacks " .. want)
        assertTrue(usage:find("`" .. want .. "[%s`]") ~= nil, "README Usage lacks " .. want)
        assertTrue(manual:find("`" .. want .. "[%s`]") ~= nil, "the manual's Slash commands lacks " .. want)
    end
end)

test("slash: auto, zone and iteminfo answer while disabled on both arms; wear is refused", function()
    -- red under: drop "iteminfo" from HOST_LIVE_VERBS (both arms read the one list)
    for _, opts in ipairs({ {}, { libFiles = {} } }) do
        local inst = T.load(opts)
        local NS, M = inst.NS, inst.mocks
        NS.RunVerb("disable")
        assertTrue(NS.IsDisabled())
        local refusal = NS.Slash:DisabledLine()
        for _, verb in ipairs({ "auto", "zone", "iteminfo" }) do
            M.__resetPrinted()
            NS.Slash:OnSlash(verb)
            local out = bare(M)
            assertTrue(#out > 0, verb .. " printed nothing")
            assertFalse(out[1] == refusal, verb .. " was refused while disabled")
        end
        M.__resetPrinted()
        NS.Slash:OnSlash("wear Normal")
        local out = bare(M)
        assertEqual(#out, 1)
        assertEqual(out[1], refusal, "wear is a feature verb")
    end
end)

-- ── the outfit argument (Commands.ResolveOutfit, INV §4) ─────────────────────────────────────────

test("slash: an outfit name matches case-insensitively, and every wear passes now and hw", function()
    -- red under: a Commands.Wear that drops `hw = true` (INV §16 quirk 22)
    local NS = scene()
    local id = NS.Outfits.Create("Fishing Gear", { HeadSlot = { id = 0 } })
    local wear = spy(NS.Stack, "Wear")
    local remove = spy(NS.Stack, "Remove")
    local toggle = spy(NS.Stack, "Toggle")
    NS.Slash:OnSlash("wear fishing GEAR")
    assertEqual(wear[1][1], id)
    assertTrue(wear[1][2].now and wear[1][2].hw, "wear: now and hw")
    assertTrue(NS.Stack.IsWorn(id))
    NS.Slash:OnSlash("unwear Fishing Gear")
    assertEqual(remove[1][1], id)
    assertTrue(remove[1][2].now and remove[1][2].hw, "unwear: now and hw")
    assertFalse(NS.Stack.IsWorn(id))
    NS.Slash:OnSlash("toggle FISHING gear")
    assertEqual(toggle[1][1], id)
    assertTrue(toggle[1][2].now and toggle[1][2].hw, "toggle: now and hw")
    assertTrue(NS.Stack.IsWorn(id))
end)

test("slash: an empty argument means the current Complete outfit, or says there is none", function()
    -- red under: a ResolveOutfit that answers nil for "" without the line (a silent no-op)
    local NS, M = scene()
    NS.Slash:OnSlash("wear")
    assertEqual(table.concat(bare(M), "|"), "No Complete outfit is equipped.")
    local normal = NS.Outfits.Create("Everyday", wornItems(NS))
    NS.Stack.Wear(normal, { now = true })
    -- The only Complete outfit is put straight back by the remove's fallback walk, so the call is read.
    local remove = spy(NS.Stack, "Remove")
    M.__resetPrinted()
    NS.Slash:OnSlash("unwear")
    assertEqual(remove[1] and remove[1][1], normal, "the empty argument did not name the Complete outfit")
    assertEqual(#M.__printed(), 0)
end)

test("slash: an outfit argument opening with `[` is decided by the client's parser", function()
    local NS, M = scene()
    local tank = NS.Outfits.Create("Tank", { HeadSlot = { id = 0 } })
    local dps = NS.Outfits.Create("DPS", { HeadSlot = { id = 0 } })
    M.__spec = 1
    NS.Slash.Route("wear [spec:1] Tank; DPS")
    -- red under: ParseArgument taking the last clause whatever the spec.
    assertFalse(NS.Stack.IsWorn(dps), "spec 1 wore the second clause")
    assertTrue(NS.Stack.IsWorn(tank), "spec 1 wears the first clause")
    NS.Stack.Remove(tank)
    M.__spec = 2
    NS.Slash.Route("wear [spec:1] Tank; DPS")
    -- red under: ParseArgument taking the first clause whatever the spec.
    assertFalse(NS.Stack.IsWorn(tank), "spec 2 wore the first clause")
    assertTrue(NS.Stack.IsWorn(dps), "spec 2 wears the second clause")
    NS.Stack.Remove(dps)
    M.__resetPrinted()
    NS.Slash.Route("wear [spec:1] Tank")
    -- red under: ParseArgument answering "" for no clause (the empty argument's line prints).
    assertEqual(#M.__printed(), 0, "no clause: a silent no-op")
    -- red under: ParseArgument falling back to the clause's text when no condition matches.
    assertFalse(NS.Stack.IsWorn(tank), "no clause wore the outfit")
end)

--- The lines legacy printed (fixtures/legacy/commands.lua), in this addon's words. Each rename has
--- its reason: the article and the full stop are design §4.3.2's keys; the zone table is no longer
--- named by its code name (cInstanceMapIDZoneIDs).
local LEGACY_RENAMES = {
    ["No Complete outfit is equipped"] = "No Complete outfit is equipped.",
    ["Couldn't find outfit named NoSuchOutfit"] = "Couldn't find an outfit named NoSuchOutfit.",
    ["This map has no entry in cInstanceMapIDZoneIDs"] = "This map has no entry in the zone table",
}

local function legacyLines(run)
    local out = {}
    for i, l in ipairs(run.lines) do
        l = l:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%[ERROR%] ", ""):gsub("^%[Outfitter%] ", "")
        out[i] = LEGACY_RENAMES[l] or l
    end
    return out
end

test("slash: wear, wear <unknown> and zone print the lines legacy printed (fixtures/legacy)", function()
    -- red under: a missing-name line without the article ("Couldn't find outfit named %s.")
    local runs = {}
    for _, run in ipairs(T.legacy.commands.runs) do runs[run.input] = run end
    for _, input in ipairs({ "wear", "wear NoSuchOutfit", "zone" }) do
        local NS, M = scene()
        M.__world.instance = { name = "Somewhere", type = "none" }
        NS.Slash:OnSlash(input)
        local want = legacyLines(runs[input])
        if input == "zone" then
            for _, l in ipairs(NS.Equip.Diagnostic()) do want[#want + 1] = l end
        end
        assertEqual(table.concat(bare(M), "|"), table.concat(want, "|"), input)
    end
end)

test("slash: /of zone routes to Commands.Zone: the zone lines, then the equipment bracket's", function()
    local NS, M = scene()
    local zone = spy(NS.Commands, "Zone")
    NS.Slash:OnSlash("zone")
    assertEqual(#zone, 1, "the verb did not reach Commands.Zone")
    local want = NS.States.ZoneInfo()
    for _, l in ipairs(NS.Equip.Diagnostic()) do want[#want + 1] = l end
    assertEqual(table.concat(bare(M), "|"), table.concat(want, "|"))
end)

-- ── the old verbs (design §4.3.2) ────────────────────────────────────────────────────────────────

test("slash: the dropped verbs are unknown commands, and no /unequip is registered", function()
    -- red under: keep a `sound` row in NS.COMMANDS
    local NS, M = scene()
    for _, verb in ipairs({ "sound", "errors", "daxdax", "summary", "rating", "itemstats" }) do
        M.__resetPrinted()
        NS.Slash:OnSlash(verb .. " on")
        assertTrue(anyLine(M, "unknown command '" .. verb .. "'"), verb .. " is still a verb")
    end
    local console = M.LibStub("AceConsole-3.0")
    assertEqual(console.commands.unequip, nil, "bare /unequip is registered (H5 drops it)")
end)

test("slash: `set equip.muteSounds` is the old `sound`, and its echo is not inverted", function()
    local NS, M = scene()
    NS.Slash:OnSlash("set equip.muteSounds true")
    assertEqual(NS.GetSetting("equip.muteSounds"), true)
    assertTrue(anyLine(M, "true") and not anyLine(M, "false"), "the echo: " .. tostring(bare(M)[1]))
    M.__resetPrinted()
    NS.Slash:OnSlash("set equip.muteSounds false")
    assertEqual(NS.GetSetting("equip.muteSounds"), false)
    assertTrue(anyLine(M, "false") and not anyLine(M, "true"), "the echo: " .. tostring(bare(M)[1]))
    NS.Slash:OnSlash("set equip.showErrors false")
    assertEqual(NS.GetSetting("equip.showErrors"), false, "the old `errors off`")
end)

test("slash: `reset bar.position` is the old `reset bar`; `deleteall` is the old `reset`", function()
    local NS = scene()
    local default = NS.GetSetting("bar.position")
    NS.Slash:OnSlash("set bar.position TOPLEFT 10 -10")
    assertFalse(NS.GetSetting("bar.position") == default, "the set did not move the bar")
    NS.Slash:OnSlash("reset bar.position")
    assertEqual(NS.GetSetting("bar.position"), default)
    local popups = T.fake(NS, "Popups", { ShowDeleteAll = true })
    NS.Slash:OnSlash("deleteall")
    assertEqual(popups.__count("ShowDeleteAll"), 1, "deleteall asks through the one popup")
    NS.SetByPath("enabled", false)
    NS.Slash:OnSlash("deleteall")
    -- red under: deleteall on HOST_LIVE_VERBS with its row's feature() refusal dropped.
    assertEqual(popups.__count("ShowDeleteAll"), 1, "deleteall ran while disabled")
end)

test("slash: `auto` writes auto.enabled; on/off and enable/disable are synonyms; bare reads it", function()
    -- red under: an AUTO_WORDS table without `disable`
    local NS, M = scene()
    for _, case in ipairs({ { "off", false }, { "on", true }, { "disable", false }, { "enable", true } }) do
        M.__resetPrinted()
        NS.Slash:OnSlash("auto " .. case[1])
        assertEqual(NS.GetSetting("auto.enabled"), case[2], "auto " .. case[1])
        assertTrue(anyLine(M, "auto.enabled"), "auto " .. case[1] .. " echoes the stored value")
    end
    M.__resetPrinted()
    NS.Slash:OnSlash("auto")
    assertTrue(anyLine(M, "auto.enabled"), "bare auto reads the setting")
    for _, prior in ipairs({ false, true }) do
        NS.SetByPath("auto.enabled", prior)
        M.__resetPrinted()
        NS.Slash:OnSlash("auto maybe")
        -- red under: an unknown word read as on (prior false) or as off (prior true).
        assertEqual(NS.GetSetting("auto.enabled"), prior, "an unknown word wrote over " .. tostring(prior))
        assertEqual(#M.__printed(), 1, "an unknown word answers one line")
    end
    assertTrue(NS.SetByPath("enabled", false))
    NS.Slash:OnSlash("auto off")
    assertEqual(NS.GetSetting("auto.enabled"), false, "auto is live while disabled")
    NS.Slash:OnSlash("auto on")
    assertEqual(NS.GetSetting("auto.enabled"), true, "auto is live while disabled")
    -- red under: doAuto writing the addon switch beside auto.enabled (`auto on` would re-enable it).
    assertEqual(NS.db.profile.enabled, false, "auto touched the addon switch")
end)

test("slash: `lock` and `unlock` write the Lock frame row and echo it", function()
    local NS, M = scene()
    NS.Slash:OnSlash("lock")
    assertEqual(NS.db.profile.locked, true)
    assertTrue(anyLine(M, "locked"))
    NS.Slash:OnSlash("unlock")
    assertEqual(NS.db.profile.locked, false)
end)

-- ── each verb's route ────────────────────────────────────────────────────────────────────────────

test("slash: `show` and `hide` open and close the window; no window toggle verb (C35)", function()
    local NS = scene()
    local opened, closed = spy(NS.Dock, "Open"), spy(NS.Dock, "Close")
    NS.Slash:OnSlash("show")
    NS.Slash:OnSlash("hide")
    assertEqual(#opened, 1)
    assertEqual(#closed, 1)
    local src = readSource("settings/Slash.lua")
    assertTrue(src:find("no window-toggle verb", 1, true) ~= nil, "the declined SHOULD is not recorded")
end)

test("slash: `update` snapshots the named or Complete outfit, or says there is none", function()
    -- red under: an Update that skips the title (the legacy verb ran inside HasHWEvent)
    local NS, M = scene()
    NS.Slash:OnSlash("update")
    assertEqual(table.concat(bare(M), "|"), "No Complete outfit is equipped.")
    local id = NS.Outfits.Create("Everyday", wornItems(NS))
    NS.Outfits.SetFlag(id, "titleID", 3)
    local set = spy(NS.Outfits, "SetToCurrent")
    M.__resetPrinted()
    NS.Slash:OnSlash("update everyday")
    assertEqual(set[1][1], id)
    assertTrue(anyLine(M, "Updated the outfit 'Everyday'"))
    assertEqual(M.__world.currentTitle, 3, "the update's wear did not set the title")
end)

test("slash: `updatetitle` re-applies the worn outfit's title", function()
    local NS, M = scene()
    local id = NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    NS.Outfits.SetFlag(id, "titleID", 2)
    NS.Stack.Wear(id, { now = true })
    assertFalse(M.__world.currentTitle == 2, "a wear with no hardware event set the title")
    NS.Slash:OnSlash("updatetitle")
    assertEqual(M.__world.currentTitle, 2)
end)

test("slash: the bank verbs and `missing` print the refusal while the bank is closed", function()
    local NS, M = scene()
    NS.Outfits.Create("Lower", { HeadSlot = { id = 0 } })
    for _, verb in ipairs({ "deposit", "depositunique", "depositothers", "withdraw", "withdrawothers" }) do
        M.__resetPrinted()
        NS.Slash:OnSlash(verb .. " lower")
        assertEqual(table.concat(bare(M), "|"), "The bank must be open", verb)
    end
    M.__resetPrinted()
    NS.Slash:OnSlash("missing")
    -- red under: a Missing that prints nothing when the report answers nil
    assertEqual(table.concat(bare(M), "|"), "You must have your bank open to generate a missing items report")
end)

test("slash: `withdrawothers` brings every other outfit's banked items (INV §3.7 Fix)", function()
    local NS, M = scene("bank_open", true)
    local function rec(key)
        local _, loc = M.__gear:find(key)
        return NS.ItemInfo.Snapshot(NS.ItemInfo.FromBag(loc.bag, loc.slot))
    end
    NS.Outfits.Create("Kept", { LegsSlot = rec("legs_plate") })
    NS.Outfits.Create("Other", { FeetSlot = rec("feet_plate") })
    NS.Slash:OnSlash("withdrawothers kept")
    local _, feet = M.__gear:find("feet_plate")
    local _, legs = M.__gear:find("legs_plate")
    assertTrue(feet.bag ~= nil and feet.bag < 6, "the other outfit's feet stayed in the bank")
    assertTrue(legs.bag ~= nil and legs.bag >= 6, "the kept outfit's legs left the bank")
    M.__resetPrinted()
    NS.Slash:OnSlash("missing")
    assertTrue(#M.__printed() > 0, "the report printed nothing")
end)

test("slash: `unequip` takes the argument, moves one item, and stops after a miss", function()
    -- red under: an unequip row that prints the miss line a second time
    local NS, M = scene()
    assertTrue(NS.ItemInfo.FromSlot("HeadSlot") ~= nil, "the scenario wears a helm")
    NS.Slash:OnSlash("unequip nosuchitem")
    assertEqual(table.concat(bare(M), "|"), "Couldn't find an item named nosuchitem")
    assertTrue(NS.ItemInfo.FromSlot("HeadSlot") ~= nil)
    NS.Slash:OnSlash("unequip 1")
    M.__fireTimers()
    assertEqual(NS.ItemInfo.FromSlot("HeadSlot"), nil, "slot 1 was not emptied")
end)

test("slash: `iteminfo` prints the link's fields through the secret-safe reader", function()
    local NS, M = scene()
    local link = "|cffffffff|Hitem:6948::::::::|h[Hearthstone]|h|r"
    NS.Slash.Route("iteminfo " .. link)
    assertEqual(table.concat(bare(M), "|"), table.concat(NS.ItemInfo.LinkInfoLines(link), "|"))
end)

test("slash: `test` flips test mode", function()
    local NS = scene()
    local toggled = spy(NS.Preview, "Toggle")
    NS.Slash:OnSlash("test")
    assertEqual(#toggled, 1)
end)
