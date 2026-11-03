local _, NS = ...
-- modules/ItemStats_Sources.lua — NS.StatSources: Pawn and WeightsWatcher as optional stat sources
-- (design §5.14, H16).
--
-- INSTALL. Src.Install asks Compat.IsAddOnLoaded for each source and registers its category through
-- NS.Stats.RegisterCategory, once per session (installed[name]). It runs at Resume (the login
-- stand-up) and again on every ADDON_LOADED that names a source, so an addon that loads after this
-- one is still found. Without either addon only the built-in category exists: the fallback. A source
-- never replaces the built-in category, and a category stays once installed.
--
-- PAWN: one stat per visible scale (Compat.PawnVisibleScales), re-read each time the category is
-- listed. Compat.PawnItemValue is pcall-wrapped and plain, and a nil value scores 0.
--
-- WEIGHTSWATCHER has the same shape: one stat per active weight of the player's class
-- (ww_charVars.activeWeights[class], when ww_vars.weightsList[class] exists), scored from
-- ww_weightCache[class][weight][link]. These are another addon's saved tables, not the client: they
-- are read by name through _G inside a pcall, every value through the Secrets seam, and a missing or
-- malformed table reads as no weights and a score of 0.
--
-- Each stat is made once and kept, so its identity is stable for the optimizer's per-job cache.

local Src = {}
NS.StatSources = Src

local Compat, Secrets = NS.Compat, NS.Secrets

local SOURCES = { "Pawn", "WeightsWatcher" }
local IS_SOURCE = { Pawn = true, WeightsWatcher = true }

local installed = {}   -- [addon name] = true once its category is registered
local events           -- the AceEvent target for the ADDON_LOADED watch

-- ── Pawn ──────────────────────────────────────────────────────────────────────────────────────

local pawnStats = {}   -- [scale name] = stat

local function pawnStat(scale)
    local stat = pawnStats[scale]
    if not stat then
        stat = NS.Stats.NewStat("Pawn_" .. scale, scale, function(_, link)
            return Compat.PawnItemValue(link, scale) or 0
        end)
        pawnStats[scale] = stat
    end
    return stat
end

local function pawnCategory()
    return {
        id = "Pawn", label = "Pawn",
        stats = function()
            local out = {}
            for _, scale in ipairs(Compat.PawnVisibleScales()) do out[#out + 1] = pawnStat(scale) end
            return out
        end,
    }
end

-- ── WeightsWatcher ────────────────────────────────────────────────────────────────────────────

-- The addon's saved tables, by name.
local WW_GLOBALS = { vars = "ww_vars", charVars = "ww_charVars", cache = "ww_weightCache" }

-- Index `t` along the path; nil at the first step that is not a table.
local function dig(t, ...)
    for i = 1, select("#", ...) do
        if type(t) ~= "table" then return nil end
        t = t[(select(i, ...))]
    end
    return t
end

--- The value at WeightsWatcher table `root` along the path, or nil (absent, or a raise).
local function wwRead(root, ...)
    local ok, v = pcall(dig, _G[WW_GLOBALS[root]], ...)
    if ok then return v end
    return nil
end

local wwStats = {}     -- [class .. "\0" .. weight] = stat

local function wwStat(class, weight)
    local key = class .. "\0" .. weight
    local stat = wwStats[key]
    if not stat then
        stat = NS.Stats.NewStat("WW_" .. weight, weight, function(_, link)
            return Secrets.PlainNumber(wwRead("cache", class, weight, link)) or 0
        end)
        wwStats[key] = stat
    end
    return stat
end

-- The player's class's active weight names, plain.
local function activeWeights(class)
    local out = {}
    if not class or wwRead("vars", "weightsList", class) == nil then return out end
    local names = wwRead("charVars", "activeWeights", class)
    if type(names) ~= "table" then return out end
    for _, raw in Secrets.SafeIterate(names) do
        local name = Secrets.PlainString(raw)
        if name then out[#out + 1] = name end
    end
    return out
end

local function wwCategory()
    return {
        id = "WW", label = "WeightsWatcher",
        stats = function()
            local class, out = Compat.PlayerClass(), {}
            for _, weight in ipairs(activeWeights(class)) do out[#out + 1] = wwStat(class, weight) end
            return out
        end,
    }
end

local BUILD = { Pawn = pawnCategory, WeightsWatcher = wwCategory }

-- ── install and the watch ─────────────────────────────────────────────────────────────────────

--- Register every source whose addon is loaded and is not yet installed.
function Src.Install()
    for _, name in ipairs(SOURCES) do
        if not installed[name] and Compat.IsAddOnLoaded(name) then
            installed[name] = true
            NS.Stats.RegisterCategory(BUILD[name]())
        end
    end
end

local function onAddonLoaded(_, name)
    if NS.IsStoodDown() or not IS_SOURCE[name] then return end
    Src.Install()
end

--- The stand-down: the ADDON_LOADED watch goes. Installed categories stay.
function Src.Suspend()
    if events then events:UnregisterAllEvents() end
end

--- The stand-up: the watch comes back, and Install runs from the client's current state.
function Src.Resume()
    if not events then events = LibStub("AceEvent-3.0"):Embed({}) end
    Src.Suspend()
    NS.SafeRegisterEvent(events, "ADDON_LOADED", onAddonLoaded, NS.rejectedEvents)
    Src.Install()
end
