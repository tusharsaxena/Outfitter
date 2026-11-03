local _, NS = ...
-- settings/Slash.lua — the ordered NS.COMMANDS table, the LibKa0s-Slash-1.0 descriptor and the macro-
-- conditional routing wrapper (H25); `/of` and `/outfitter` both reach the one dispatcher.

NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local L = NS.L

local function out(line) NS.Print(line) end

local cli   -- built at the bottom, once NS.COMMANDS exists; handlers reach it at CALL time
local doEnabled, doDebug, doPerf

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
-- `version` and arrive with modules/Commands.lua in P4.24.
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
--- (the library's LIVE_VERBS plus these) and the library-absent stub's gate. Empty until P4.24 adds
--- `auto` (one setting, as `get`/`set` are), `zone` and `iteminfo` (read-only) with their verbs.
local HOST_LIVE_VERBS = {}
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

--- `enable` / `disable`: the composed `enabled` row, through the seam, echoed by the CLI so the stored
--- value is what the player reads back (slash-commands-§2). Degraded, the write goes through the
--- seam's writeThrough list and is acknowledged only if it landed (options-ui-§1); a written-through
--- value runs no onChange, so ApplyEnabled stands in for it.
function doEnabled(want)
    if not degraded and NS.FindSchemaRow("enabled") then
        cli:CliSet("enabled " .. tostring(want))
        return
    end
    local ok, err = NS.SetByPath("enabled", want)
    if ok then
        NS.ApplyEnabled(want)
        out(L["%s = %s"]:format("enabled", tostring(want)))
    else
        out(tostring(err))
    end
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
