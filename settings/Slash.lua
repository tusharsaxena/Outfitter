local _, NS = ...
-- settings/Slash.lua — the ordered NS.COMMANDS table, the LibKa0s-Slash-1.0 descriptor and the macro-
-- conditional routing wrapper (H25); `/of` and `/outfitter` both reach the one dispatcher.

NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local L = NS.L

local function out(line) NS.Print(line) end

local cli   -- built at the bottom, once NS.COMMANDS exists; handlers reach it at CALL time
local doEnabled, doDebug, doPerf, doAuto, writeRow

--- A feature verb's handler behind the stand-down: the dispatcher refuses every feature verb while the
--- `disabled` hold is taken, and this answers the `perf` hold's line (slash-commands-§7, "Which
--- refusal, by hold") before the handler can act.
local function feature(fn)
    return function(rest)
        local line = NS.StoodDownRefusal()
        if line then return out(line) end
        return fn(rest)
    end
end

-- Positional triples {name, desc, fn}: a table of named fields is invisible to the library. The
-- reserved verbs come first, in the DpsRace order, and mean the same thing in every Ka0s addon
-- (slash-commands-§2); `diagnostics` has no alias of any kind. The outfit verbs (design §4.3.2) follow
-- `version`; their handlers are modules/Commands.lua's, reached at call time.
--
-- Declined SHOULD (standalone-windows :52): `show` and `hide` exist, but there is no window-toggle verb,
-- because `toggle` has been the outfit verb in players' macros since before this fork (C35;
-- docs/slash-dispatch.md; a row in docs/ARCHITECTURE.md's deviation register). The old verbs map as
-- design §4.3.2's table says: `sound` and `errors` are `/of set equip.muteSounds|equip.showErrors`,
-- `reset bar` is `/of reset bar.position`, the old `reset` is `deleteall`, the old automation
-- `enable`/`disable` is `auto on|off`; `summary`, `rating`, `itemstats` and the bare `/unequip` are
-- gone (INV §18, H5).
NS.COMMANDS = {
    { "help",        L["Show this help"],                          function() cli:PrintHelp() end },
    { "config",      L["Open the settings panel"],                 function() NS.OpenOptionsPanel() end },
    -- The reserved `skin` verb (O.SkinVerb), right after `config`: the skin picker a new profile
    -- shows, on demand (core/SkinSetup.lua's NS.RunSkinVerb). Not a live verb, so the dispatcher
    -- refuses it while disabled; behind feature() for the perf hold's line.
    { "skin",        L["Choose a skin: open the skin picker"],     feature(function() NS.RunSkinVerb() end) },
    { "enable",      L["Turn the addon on"],                       function() doEnabled(true) end },
    { "disable",     L["Turn the addon off without unloading it"], function() doEnabled(false) end },
    { "list",        L["List every setting"],                      function() cli:CliList() end },
    { "get",         L["Read one setting: /of get path"],          function(rest) cli:CliGet(rest) end },
    { "set",         L["Write one setting: /of set path value"],   function(rest) cli:CliSet(rest) end },
    { "reset",       L["Reset one setting: /of reset path"],       function(rest) cli:CliReset(rest) end },
    { "resetall",    L["Reset every setting (asks first)"],        function() NS.ShowResetAll() end },
    { "debug",       L["Debug console; on/off set logging, diagnostics writes the report"],
                                                                   function(rest) doDebug(rest) end },
    { "diagnostics", L["Write the diagnostics report to the debug console"],
                                                                   function() NS.DebugLog:RunDiagnostics() end },
    { "perf",        L["Performance capture; try /of perf help"], function(rest) doPerf(rest) end },
    { "version",     L["Print the addon version"],                 function() cli:CliVersion() end },
    { "show",        L["Show the outfit window on the character sheet"], feature(function() NS.Dock.Open() end) },
    { "hide",        L["Hide the outfit window"],                  feature(function() NS.Dock.Close() end) },
    { "wear",        L["Wear an outfit (default: the current Complete outfit)"],
                                                                   feature(function(rest) NS.Commands.Wear(rest) end) },
    { "unwear",      L["Take an outfit off"],                      feature(function(rest) NS.Commands.Unwear(rest) end) },
    { "toggle",      L["Wear an outfit, or take it off if it is worn"],
                                                                   feature(function(rest) NS.Commands.Toggle(rest) end) },
    { "update",      L["Update an outfit to the items you have equipped"],
                                                                   feature(function(rest) NS.Commands.Update(rest) end) },
    { "deposit",     L["Put an outfit's items in the bank (bank must be open)"],
                                                                   feature(function(rest) NS.Commands.Bank("Deposit", rest) end) },
    { "depositunique", L["Put in the bank only the items no other outfit uses"],
                                                                   feature(function(rest) NS.Commands.Bank("DepositUnique", rest) end) },
    { "depositothers", L["Put every other outfit's items in the bank"],
                                                                   feature(function(rest) NS.Commands.Bank("DepositOthers", rest) end) },
    { "withdraw",    L["Take an outfit's items out of the bank"],  feature(function(rest) NS.Commands.Bank("Withdraw", rest) end) },
    { "withdrawothers", L["Take every other outfit's items out of the bank"],
                                                                   feature(function(rest) NS.Commands.Bank("WithdrawOthers", rest) end) },
    { "missing",     L["List the outfit items you no longer have (bank must be open)"],
                                                                   feature(function() NS.Commands.Missing() end) },
    -- Moves.UnequipByName prints its own miss and full-bags lines, so nothing is printed here.
    { "unequip",     L["Move one equipped item to your bags"],
                                                                   feature(function(rest) NS.Moves.UnequipByName(rest) end) },
    { "updatetitle", L["Re-apply the title of the outfit you are wearing"],
                                                                   feature(function() NS.Stack.UpdateTitle(true) end) },
    -- Live (HOST_LIVE_VERBS): one setting, as `set` is; the key bindings refuse it themselves.
    { "auto",        L["Automatic outfit changes: /of auto on, off, or no word to see the state"],
                                                                   function(rest) doAuto(rest) end },
    { "zone",        L["Show what Outfitter knows about where you are"], function() NS.Commands.Zone() end },
    { "iteminfo",    L["Print an item link's fields"], function(rest) NS.Commands.ItemInfo(rest) end },
    { "test",        L["Sample outfits on the outfit bar: /of test"], feature(function() NS.Preview.Toggle() end) },
    -- slash-commands-§8: the Lock frame row's path, through the one seam.
    { "lock",        L["Lock the outfit bar in place"],            feature(function() writeRow("locked", true) end) },
    { "unlock",      L["Unlock the outfit bar to move it"],        feature(function() writeRow("locked", false) end) },
    { "deleteall",   L["Delete every outfit on this character (asks first)"],
                                                                   feature(function() NS.Popups.ShowDeleteAll() end) },
}

--- Run one verb's handler by name: the launcher's Enabled entry and the AutoOn/AutoOff/Update key
--- bindings reach their verbs through here, so the menu, the key and the verb are one handler
--- (launcher-§2).
function NS.RunVerb(verb, rest)
    for _, entry in ipairs(NS.COMMANDS) do
        if entry[1] == verb then return entry[3](rest or "") end
    end
end

--- slash-commands-§2's thirteen reserved verbs: they answer while disabled. Named once, here, for the
--- library-absent stub's gate; the live dispatcher reads its own lib.LIVE_VERBS (pinned equal by
--- tests/test_slash.lua).
NS.SLASH_LIVE_VERBS = {
    help = true, config = true, version = true, enable = true, disable = true, debug = true,
    diagnostics = true, perf = true, get = true, set = true, list = true, reset = true, resetall = true,
}

--- The host verbs that also answer while disabled, on BOTH arms: the descriptor's `liveVerbs` below
--- (the library's LIVE_VERBS plus these) and the library-absent stub's gate. `auto` writes one
--- setting, as `get`/`set` do; `zone` and `iteminfo` are read-only (design §4.3.2).
local HOST_LIVE_VERBS = { "auto", "zone", "iteminfo" }
local HOST_LIVE = {}
for _, verb in ipairs(HOST_LIVE_VERBS) do HOST_LIVE[verb] = true end

local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
local degraded = false

if not SlashLib then
    -- Degrade, never error: `/of` is registered unconditionally, so something must answer it. The
    -- host verbs keep working; the schema CLI names the missing library. The ONE library string this
    -- stub carries is DISABLED_LINE_FORMAT, pinned by tests/test_slash.lua against the live major;
    -- every other line below is the stub's own plain wording, never a copy of the library's.
    degraded = true
    local MISSING = L["%s is unavailable: the LibKa0s library did not load."]
    SlashLib = { DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r" }
    Sl.__stubFormat = SlashLib.DISABLED_LINE_FORMAT
    function SlashLib.New(_, d)
        local stub = {}
        local function absent(verb) return function() out(MISSING:format(d.slash .. " " .. verb)) end end
        for _, verb in ipairs({ "List", "Get", "Set", "Reset", "ResetAll", "Profile" }) do
            stub["Cli" .. verb] = absent(verb:lower())
        end
        stub.SetRowAnnotator = function() end
        stub.ProfileSwitch = function() return false end
        stub.DisabledLine = function()
            return SlashLib.DISABLED_LINE_FORMAT:format(d.brandName, d.slash .. " enable")
        end
        local function version() return tostring(d.version and d.version() or "?") end
        stub.CliVersion = function() out(L["%s version %s"]:format(d.brandName, version())) end
        stub.LandingRows = function()
            local rows = {}
            for _, e in ipairs(d.commands) do rows[#rows + 1] = d.slash .. " " .. e[1] .. "  " .. e[2] end
            return rows
        end
        stub.HelpRows = function()
            local rows = {}
            for _, r in ipairs(stub.LandingRows()) do rows[#rows + 1] = "  " .. r end
            return rows
        end
        stub.PrintHelp = function()
            out(L["%s commands (reduced: the LibKa0s library is missing)"]:format(d.slash))
            for _, r in ipairs(stub.HelpRows()) do out(r) end
        end
        -- Minimal dispatch is the host's own routing (slash-commands-§1): split, look up, call.
        stub.OnSlash = function(_, msg)
            local raw = tostring(msg or ""):match("^%s*(.-)%s*$")
            if raw == "" then return NS.RunVerb("config") end
            local verb, rest = raw:match("^(%S+)%s*(.*)$")
            verb = verb:lower()
            for _, e in ipairs(d.commands) do
                if e[1] == verb then
                    -- The disabled gate the live dispatcher applies: a feature verb refuses with the
                    -- one line while the `disabled` hold is taken (slash-commands-§7).
                    if d.isEnabled and not d.isEnabled() and not NS.SLASH_LIVE_VERBS[verb]
                        and not HOST_LIVE[verb] then
                        return out(stub.DisabledLine())
                    end
                    return e[3](rest or "")
                end
            end
            stub.PrintHelp()
        end
        return stub
    end
end

-- The live set: the library's reserved verbs, then this addon's own. The stub has no LIVE_VERBS and
-- reads NS.SLASH_LIVE_VERBS and HOST_LIVE_VERBS itself.
local liveVerbs = {}
for i, verb in ipairs(SlashLib.LIVE_VERBS or {}) do liveVerbs[i] = verb end
for _, verb in ipairs(HOST_LIVE_VERBS) do liveVerbs[#liveVerbs + 1] = verb end
Sl.LIVE_VERBS = liveVerbs

cli = SlashLib:New({
    slash        = NS.SLASH,
    slashAliases = { NS.SLASH_LONG },
    commands     = NS.COMMANDS,                       -- passed IN, never owned by the library
    -- The disabled gate: every verb not on the library's live list answers the one refusal line
    -- while the `disabled` hold is taken (slash-commands-§2, §7). Not IsStoodDown: the `perf` hold
    -- alone must not print the disabled line.
    isEnabled    = function() return not NS.IsDisabled() end,
    liveVerbs    = liveVerbs,
    brandName    = NS.BRAND,
    print        = function(line) out(line) end,
    version      = function() return NS.Version() end,
    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, value) return NS.SetByPath(path, value) end,   -- the single write seam
    findRow      = function(path) return NS.FindSchemaRow(path) end,
    -- The SETTINGS instance only: no outfit row can be listed, read or written here (design §3.5).
    allRows      = function() return NS.Schema.AllRows() end,
    applyDefault = function(row) return NS.ApplyDefault(row) end,
    bulkBegin    = function(act, scope) NS.Bulk.Begin(act, scope) end,
    bulkEnd      = function(act, scope, count, err, info) NS.Bulk.End(act, scope, count, err, info) end,
    groupKey     = function(row) return (row.page or "?") .. " \226\128\186 " .. (row.group or "?") end,
    format       = function(row, value) return NS.FormatSchemaValue(row, value) end,
    -- The dispatcher's own refusals land in the console as one `Cmd` line each (debug-logging-§4).
    debug        = function(tag, message) NS.Debug(tag, "%s", message) end,
})
Sl.__dispatcher = cli

--- One boolean row from a verb: through the CLI, echoed so the stored value is what the player reads
--- back (slash-commands-§2, §8). Degraded, or on a load where the row is hollow, the write goes through
--- the seam's writeThrough list (`enabled`, `locked`, `auto.enabled`) and is acknowledged only if it
--- landed (options-ui-§1). A written-through value runs no onChange, so `apply`, when given, stands in.
function writeRow(path, want, apply)
    if not degraded and NS.FindSchemaRow(path) then
        cli:CliSet(path .. " " .. tostring(want))
        return
    end
    local ok, err = NS.SetByPath(path, want)
    if ok then
        if apply then apply(want) end
        out(L["%s = %s"]:format(path, tostring(want)))
    else
        out(tostring(err))
    end
end

--- `enable` / `disable`: the composed `enabled` row; written through, ApplyEnabled is its onChange.
function doEnabled(want)
    writeRow("enabled", want, NS.ApplyEnabled)
end

-- `/of auto` words: on/off, with the old verbs' `enable`/`disable` as synonyms (design §4.3.2).
local AUTO_WORDS = { on = true, enable = true, off = false, disable = false }

--- `auto`: write `auto.enabled`, or read it back with no word.
function doAuto(rest)
    local word = tostring(rest or ""):match("^%s*(%S*)"):lower()
    if word == "" then
        if degraded then return out(L["%s = %s"]:format("auto.enabled", tostring(NS.GetSetting("auto.enabled")))) end
        return cli:CliGet("auto.enabled")
    end
    local want = AUTO_WORDS[word]
    if want == nil then return out(L["%s auto takes on or off"]:format(NS.SLASH)) end
    writeRow("auto.enabled", want)
end

--- `diagnostics` is tested FIRST (debug-logging-§14), then `on`/`off`; any other word, or none,
--- toggles the WINDOW with the flag untouched. A retired `diag` is just an unknown word.
function doDebug(rest)
    if not NS.DebugLog:DebugVerb(rest) then NS.DebugLog:Toggle() end
end

--- `perf`: the reserved verb the HOST registers (performance-§4). The library returns lines.
function doPerf(rest)
    local lines = NS.Perf.OnCommand(rest)
    if type(lines) ~= "table" then return end
    for _, line in ipairs(lines) do out(line) end
end

function Sl:OnSlash(msg) return cli:OnSlash(msg) end
function Sl:PrintHelp() return cli:PrintHelp() end
function Sl:LandingRows() return cli:LandingRows() end
function Sl:DisabledLine() return cli:DisabledLine() end

-- ── Macro conditionals (H25) ─────────────────────────────────────────────────────────────────────
-- The old addon took `/outfitter wear [combat] Tank; Normal` from macros. The client's own option
-- parser decides the clause, then the one dispatcher runs what it chose: host ROUTING ahead of the
-- library, not a second dispatcher. A message carrying a hyperlink (`|h`, as `/of iteminfo <link>`
-- does) is never parsed, because an item name may hold `[` or `;`.
--
-- Only a message OPENING with `[` is parsed at the top level. A `;` after a verb belongs to that
-- verb's argument: parsing `wear [spec:1] Tank; DPS` whole would return the unconditional first
-- clause `wear [spec:1] Tank` and drop `; DPS`, so the argument parse (Sl.ParseArgument) could never
-- reach its second clause.

--- True when `text` is a conditional the client parser should decide.
local function isConditional(text)
    if text:find("|h", 1, true) then return false end
    return text:sub(1, 1) == "["
end

--- The whole message: a leading `[` goes through SecureCmdOptionParse first. A message no clause
--- matches is a silent no-op, as the old addon's was (INV §4).
function Sl.Route(msg)
    msg = tostring(msg or "")
    if isConditional(msg) then
        local parsed = SecureCmdOptionParse(msg)
        if parsed == nil then return end
        msg = parsed
    end
    return Sl:OnSlash(msg)
end

--- An outfit verb's argument (modules/Commands.lua, P4.24): one starting with `[` is decided alone,
--- so `/of wear [spec:1] Tank; DPS` wears Tank on the first spec and DPS otherwise. Answers the
--- chosen text, or nil when no clause matched.
function Sl.ParseArgument(rest)
    rest = tostring(rest or "")
    if rest:sub(1, 1) ~= "[" or rest:find("|h", 1, true) then return rest end
    return SecureCmdOptionParse(rest)
end

--- Both chat commands on the one route, through AceConsole (never raw SLASH_*).
function Sl:Register()
    NS.addon:RegisterChatCommand(NS.SLASH:sub(2), Sl.Route)
    NS.addon:RegisterChatCommand(NS.SLASH_LONG:sub(2), Sl.Route)
end
