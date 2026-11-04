local addonName, NS = ...
-- core/DebugLogSetup.lua — NS.DebugLog, the one debug console from LibKa0s-DebugLog-1.0; publishes the
-- gated sink NS.Debug and the console's change gates (debug-logging-§5, §8, §9).
--
-- Tags (one word each, design §1.1): Equip, Stack, Trigger, States, Zone, Dock, Bar, EM, Opt, Pet and
-- Test for the engine and the UI, plus the seams' own Set (core/Database.lua), Skin (core/SkinSetup.lua)
-- and Perf (core/PerfSetup.lua). docs/debug.md's ## Tags is the register (tests/test_skeleton.lua holds
-- every literal tag to it). A trigger id, an outfit name or a slot goes in the message, never the tag.

local L = NS.L
local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

if not lib then
    -- Degrade, never error. Every member the addon calls, and SetEnabled still flips OUR flag and
    -- still acknowledges, because a player who types `/of debug on` must not be told nothing. What
    -- is lost is the window, said once.
    local missing = NS.LIBKA0S_MISSING .. ", so the debug console window is unavailable."
    local announced = false
    local function sayOnce()
        if announced then return end
        announced = true
        NS.Print(missing)
    end
    local D = {
        buffer          = {},
        Add             = function() end,
        Debug           = function() end,
        Clear           = function() end,
        Show            = function() sayOnce() end,
        Hide            = function() end,
        Toggle          = function() sayOnce() end,
        IsShown         = function() return false end,
        IsEnabled       = function() return NS.State.debug or false end,
        SetEnabled      = function(_, on)
            NS.State.debug = on and true or false
            NS.Print((on and L["Debug logging is on."]) or L["Debug logging is off."])
            if on then sayOnce() end
        end,
        ConsoleCheckbox = function()
            return {
                label   = L["Debug console"],
                tooltip = missing,
                get     = function() return false end,
                set     = function() sayOnce() end,
            }
        end,
        RunDiagnostics  = function()
            NS.Print(L["%s is unavailable: the LibKa0s library did not load."]:format(NS.SLASH .. " diagnostics"))
            return 0
        end,
        DebugVerb       = function() return false end,
        DebugOnce       = function() return false end,
        DebugChanged    = function() return false end,
        DebugForget     = function() end,
        DebugAtEnable   = function() return false end,
    }
    NS.DebugLog = D
    NS.Debug = D.Debug
    NS.DebugOnce, NS.DebugChanged, NS.DebugAtEnable = D.DebugOnce, D.DebugChanged, D.DebugAtEnable
    return
end

--- The two counts the init line carries: every outfit of this character, and those with a trigger.
--- Walked at call time over db.char.outfits (design §3.3); a record whose trigger has no id is not
--- counted as triggered.
local function outfitCounts(db)
    local outfits = db and db.char and db.char.outfits
    local n, m = 0, 0
    if type(outfits) == "table" then
        for _, outfit in pairs(outfits) do
            n = n + 1
            local trigger = type(outfit) == "table" and outfit.trigger or nil
            if type(trigger) == "table" and trigger.id then m = m + 1 end
        end
    end
    return n, m
end

NS.DebugLog = lib:New({
    name      = addonName,                    -- seeds the frame globals and UISpecialFrames entries
    addonName = addonName,                    -- the FOLDER: the console's close/copy/clear marks, the skin owner
    title     = NS.BRAND,
    font      = NS.Constants.FONT_MONO,
    slash     = NS.SLASH,

    -- The flag stays the ADDON's (debug-logging-§5): session-only, never in SavedVariables.
    isEnabled  = function() return NS.State.debug or false end,
    setEnabled = function(on) NS.State.debug = on and true or false end,

    -- Call-time forwarders: NS.Print is reclaimed from AceConsole's embed in a later file.
    print        = function(line) NS.Print(line) end,
    safeToString = function(v) return NS.SafeToString(v) end,

    initSummary = function()
        local db = NS.db
        local schema = db and db.global and db.global.schemaVersion or "?"
        local profile = db and db.GetCurrentProfile and db:GetCurrentProfile() or "?"
        local n, m = outfitCounts(db)
        local S = NS.SafeToString
        return ("%s v%s, schema v%s, profile '%s', %d outfits, %d with triggers"):format(S(NS.BRAND),
            S(NS.version), S(schema), S(profile), S(n), S(m))
    end,

    -- So a console opened by `/of debug` moves the checkbox on an already-open options panel.
    -- NS.Helpers lands with settings/OptionsSetup.lua, after this file: resolved at call time.
    onVisibilityChanged = function()
        local H = NS.Helpers
        if H and H.RefreshAllPanels then H.RefreshAllPanels() end
    end,

    -- The diagnostics dump (debug-logging-§14): the full brand in both markers, the sections read at
    -- RUN time because modules/Diagnostics.lua loads after this file. A run turns logging on for the
    -- session; this addon takes no opt-out and never calls SetEnabled around a run.
    brandName   = NS.BRAND,
    diagnostics = function()
        local Diag = NS.Diagnostics
        return Diag and Diag.Sections and Diag.Sections() or {}
    end,
})

-- The gated sink, bare: call sites stay `NS.Debug("Equip", "%s -> %s", from, to)`.
NS.Debug = NS.DebugLog.Debug

-- The console's gates (DebugLog minor 18): a repeating path logs on change, a one-time line once, and
-- a state line written at OnEnable is held until logging is turned on (debug-logging-§8, §9).
NS.DebugOnce     = NS.DebugLog.DebugOnce
NS.DebugChanged  = NS.DebugLog.DebugChanged
NS.DebugAtEnable = NS.DebugLog.DebugAtEnable
