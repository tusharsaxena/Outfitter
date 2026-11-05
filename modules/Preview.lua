local _, NS = ...
-- modules/Preview.lua — NS.Preview: test mode (design §8; smoke round 2 design G7; preview-mode).
--
-- Test mode turns the outfit bar and the outfit window over to the sample outfits of
-- defaults/PreviewOutfits.lua, each under its own amber test strip, so both can be placed and skinned
-- without real outfits. The surfaces do the drawing on every PREVIEW_CHANGED this module sends. The bar
-- (modules/Bar.lua) reads IsActive() in its show decision and draws Preview.Source instead of its live
-- source. The window (modules/Dock.lua, Window.lua, Window_ListModel.lua) lists the samples with no item
-- section, docked beside an open sheet or alone where a stock sheet would open; X or Escape hides it
-- for the rest of the session without ending the mode (design D10, which reverses H17). Nothing is
-- equipped and nothing is saved: the samples never reach NS.Outfits or NS.Stack, and the one flag is
-- the session-only NS.State.testMode.
--
-- Session-only and on until turned off. It ENDS on its own switch (the General row, the launcher's
-- entry, `/or test`), on combat (PLAYER_STATE_CHANGED "combat", which PlayerState sends on
-- PLAYER_REGEN_DISABLED: one line, NS.SayTestModeEnded), on Reset all (the row's default, false) and,
-- silently, on the stand-down. Re-locking the bar does not end it. A start is refused in combat with
-- one line, and is silent while stood down.

local Preview = { active = false, openedBar = false }
NS.Preview = Preview

local L = NS.L

--- The bar's source while test mode is on (Bar.Render's contract: Rows() -> the category rows).
Preview.Source = { Rows = function() return NS.PreviewOutfits.Rows() end }

local bus   -- the module's own bus target, built at the first start or resume

local function debug(fmt, ...) NS.Debug("Test", fmt, ...) end

-- The General row's Test mode checkbox reads IsActive() only when a refresher runs: every start and
-- stop repaints an open panel in place (options-ui-§15), whoever turned it (the launcher, the strip,
-- the skin picker's eye, combat, the stand-down, `/or test`). NS.Helpers is resolved at call time.
local function repaintPanel()
    local H = NS.Helpers
    if H and type(H.RefreshScalars) == "function" then H.RefreshScalars() end
end

local function onPlayerState(_, key, value)
    if key == "combat" and value == true and Preview.active then Preview.Stop("combat") end
end

local function ensureListener()
    if bus then return end
    bus = NS.NewBusTarget()
    bus:RegisterMessage(NS.MSG.PLAYER_STATE_CHANGED, onPlayerState)
end

--- @return boolean whether test mode is on
function Preview.IsActive() return Preview.active end

--- Turn test mode on. Silent while stood down; refused, with one line, in combat. Already on: a no-op.
--- @return boolean on
function Preview.Start()
    if NS.IsStoodDown() then return false end
    if Preview.active then return true end
    if NS.Compat.InCombatLockdown() then
        NS.Print(L["Test mode is not available in combat."])
        return false
    end
    ensureListener()
    Preview.active, NS.State.testMode = true, true
    -- The bar it shows only for test mode goes away again at the end (Bar.ShouldShow decides).
    Preview.openedBar = NS.GetSetting("bar.shown") ~= true
    NS.SendBus(NS.MSG.PREVIEW_CHANGED, true)
    repaintPanel()
    debug("on (bar opened=%s)", tostring(Preview.openedBar))
    return true
end

--- Turn test mode off. `reason` "combat" says so once; any other ("switch", "reset", nil) is quiet.
--- @param reason string|nil
--- @return boolean stopped
function Preview.Stop(reason)
    if not Preview.active then return false end
    Preview.active, NS.State.testMode, Preview.openedBar = false, false, false
    if reason == "combat" then NS.SayTestModeEnded() end
    NS.SendBus(NS.MSG.PREVIEW_CHANGED, false)
    repaintPanel()
    debug("off (%s)", reason or "switch")
    return true
end

--- Flip test mode (the launcher's entry and `/or test`).
--- @return boolean on
function Preview.Toggle()
    if Preview.active then
        Preview.Stop("switch")
        return false
    end
    return Preview.Start()
end

--- The stand-down ends test mode silently: the player turned the addon off, not the mode. The bar
--- hides itself in its own Suspend, so nothing is sent.
function Preview.Suspend()
    local was = Preview.active
    Preview.active, NS.State.testMode, Preview.openedBar = false, false, false
    if was then repaintPanel() end
end

--- The stand-up: test mode stays off; the combat receiver is in place for the next start.
function Preview.Resume()
    ensureListener()
end

--- What test mode is doing, for the diagnostics report and the suites.
--- @return table { active, openedBar, outfits }
function Preview.Diagnose()
    local n = 0
    if Preview.active then
        for _, row in ipairs(Preview.Source.Rows()) do n = n + #row.outfits end
    end
    return { active = Preview.active, openedBar = Preview.openedBar, outfits = n }
end
