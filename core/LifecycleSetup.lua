local addonName, NS = ...
-- core/LifecycleSetup.lua — the ONE stand-down latch, from LibKa0s-Lifecycle-1.0 (design §5.12, H26).
--
-- Two holds take it: `disabled` (the stored `enabled` row) and `perf` (a capture's suspended arm,
-- core/PerfSetup.lua). The addon is down while either is held and comes back only when both are
-- released (slash-commands-§7, performance-§6).
--
--   NS.lifecycle / NS.Lifecycle   the latch (the same object)
--   NS.HOLD_DISABLED, NS.HOLD_PERF the two hold names, read off the major
--   NS.LIFECYCLE_MODULES          the module names standDown walks top to bottom, standUp bottom to top
--   NS.StandDown, NS.StandUp      the latch's two callbacks
--   NS.ApplyEnabled(enabled)      the `enabled` row's reaction: take or release the `disabled` hold
--   NS.SyncEnabledHold()          re-read the stored switch (login, every profile change/copy/reset)
--   NS.IsStoodDown()              either hold is taken
--   NS.IsDisabled()               the `disabled` hold is taken
--   NS.StoodDownRefusal()         THE one refusal line, or nil while standing up

local Lifecycle = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)
local L = NS.L

-- Stand-down runs top to bottom; stand-up runs bottom to top. Jobs that want to equip cancel before
-- the engine resets; States.Resume runs before TriggerBinder.BindAll on the way up (design §5.12).
-- Every name is a module that ships; a name whose NS table is absent, or has no Suspend/Resume, is
-- skipped by the walks below rather than raised on.
local MODULES = { "Preview", "TriggerBinder", "States", "Optimize", "Companion", "EM", "Equip", "Stack",
                  "Outfits", "Inventory", "PlayerState", "Stats", "Tooltips", "Compare", "QuickSlots", "Bar",
                  "Dock", "SlotEnables", "Dialogs", "IconBrowser" }
NS.LIFECYCLE_MODULES = MODULES

--- Disabled means NOT RUNNING. Every registration goes -- not gated -- every timer is canceled, and
--- every frame is hidden at the source of its show decision. Everything reached here is resolved at
--- CALL time: the modules load after this file.
local function standDown()
    local addon = NS.addon
    if addon then
        if addon.UnregisterAllEvents then addon:UnregisterAllEvents() end
        if addon.UnregisterAllMessages then addon:UnregisterAllMessages() end
        if addon.CancelAllTimers then addon:CancelAllTimers() end
    end
    NS.BusStandDown()
    -- The queue's own AceEvent target is out of AceAddon's reach. Cleared BEFORE the modules: a
    -- module that must hide a secure frame in combat (Dock, design §5.12) queues it in its Suspend,
    -- and that write has to survive the stand-down.
    if NS.SecureQueue and NS.SecureQueue.Clear then NS.SecureQueue.Clear() end
    for i = 1, #MODULES do
        local m = NS[MODULES[i]]
        if m and m.Suspend then m.Suspend() end
    end
    -- The first-run skin picker is a frame this addon shows: it goes down unmarked, so it comes back
    -- on the next login the addon stands up for (core/SkinSetup.lua).
    if NS.HideSkinPicker then NS.HideSkinPicker() end
end

--- Back up FROM CURRENT STATE, never from a snapshot taken at stand-down (performance-§6): a setting
--- changed while down comes back correctly because the registrations are rebuilt from it.
local function standUp()
    NS.BusStandUp()
    NS.RegisterGameEvents()
    for i = #MODULES, 1, -1 do
        local m = NS[MODULES[i]]
        if m and m.Resume then m.Resume() end
    end
end

NS.StandDown, NS.StandUp = standDown, standUp

if Lifecycle then
    NS.lifecycle = Lifecycle:New({
        name      = addonName,
        standDown = standDown,
        standUp   = standUp,
        print     = function(line) NS.Print(line) end,
        -- The library logs every edge with its holds; the callbacks above write no edge line.
        -- NS.Debug arrives with core/DebugLogSetup.lua, after this file: resolved at call time.
        debug     = function(tag, message) if NS.Debug then NS.Debug(tag, "%s", message) end end,
    })
else
    -- Degrade, never error: the same two-hold latch, every member the addon calls.
    local held, down = {}, false
    local function edge()
        local want = next(held) ~= nil
        if want == down then return false end
        down = want
        if down then standDown() else standUp() end
        return true
    end
    local lc = { name = addonName }
    function lc.Hold(_, key) held[key] = true; return edge() end
    function lc.Release(_, key) held[key] = nil; return edge() end
    function lc.Set(self, key, want)
        if want then return self:Hold(key) end
        return self:Release(key)
    end
    function lc.IsHeld(_, key) return held[key] == true end
    function lc.IsDown() return down end
    function lc.Reevaluate() return edge() end
    function lc.Holds()
        local out = {}
        for key in pairs(held) do out[#out + 1] = key end
        table.sort(out)
        return out
    end
    function lc.PrintHolds() return false end
    NS.lifecycle = lc
end

-- The two hold names, read off the major so the arm that takes a hold and the arm that releases it
-- cannot disagree about what it is called.
NS.HOLD_DISABLED = Lifecycle and Lifecycle.HOLD_DISABLED or "disabled"
NS.HOLD_PERF     = Lifecycle and Lifecycle.HOLD_PERF or "perf"

-- The capitalized alias the kit's latch helper names; the same object.
NS.Lifecycle = NS.lifecycle

--- The `enabled` row's reaction: take or release the `disabled` hold. Never a direct stand-up, so
--- re-enabling during a capture does not resurrect an addon the `perf` hold still holds down.
function NS.ApplyEnabled(enabled)
    return NS.lifecycle:Set(NS.HOLD_DISABLED, enabled == false)
end

--- Re-read the stored switch. NS.GetSetting arrives with settings/Schema.lua: until it does, the
--- switch reads as on.
function NS.SyncEnabledHold()
    local on = NS.GetSetting and NS.GetSetting("enabled")
    return NS.ApplyEnabled(on ~= false)
end

function NS.IsStoodDown()
    return NS.lifecycle:IsDown() == true
end

function NS.IsDisabled()
    return NS.lifecycle:IsHeld(NS.HOLD_DISABLED) == true
end

--- THE one refusal helper (slash-commands-§7, "Which refusal, by hold"): the line a stood-down
--- feature prints, or nil while standing up. The slash feature() wrapper, the 14 binding handlers,
--- the launcher toggles and Delete-all all ask here. The `disabled` hold answers the dispatcher's
--- refusal line and wins over `perf`; the `perf` hold alone answers the capture line.
function NS.StoodDownRefusal()
    if not NS.IsStoodDown() then return nil end
    if NS.IsDisabled() then
        local Sl = NS.Slash
        if Sl and Sl.DisabledLine then return Sl:DisabledLine() end
        -- Before settings/Slash.lua lands (or with it absent): the same library line Sl:DisabledLine
        -- builds, formatted the same way, so the wording does not change when the dispatcher arrives.
        local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
        -- The library is vendored and in the TOC; its absence leaves the same words, uncolored.
        local fmt = SlashLib and SlashLib.DISABLED_LINE_FORMAT or "%s is disabled \226\128\148 enable it with %s"
        return fmt:format(tostring(NS.BRAND or NS.SLASH), NS.SLASH .. " enable")
    end
    return L["Not available during a performance capture."]
end
