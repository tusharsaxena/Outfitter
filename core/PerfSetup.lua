local addonName, NS = ...
-- core/PerfSetup.lua — NS.Perf, the one performance-harness instance from LibKa0s-Perf-1.0
-- (performance-§1); the reserved `perf` verb in settings/Slash.lua drives it.
--
-- The bucket list is FIXED (design §2.1, performance-§3): ten static keys, declared here in report
-- order, each bracketed by exactly one call site. A bracket reads `NS.Perf.on` (a plain boolean) and
-- notes only inside an experiment window:
--
--   local t0 = Perf.on and debugprofilestop()
--   ...
--   if t0 then Perf.Note("bagSync", debugprofilestop() - t0) end
--
-- Never a dynamic key: a trigger id, an outfit name or a slot goes to NS.Debug, not to a bucket name.

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)

if not lib then
    -- Degrade, never error: the gate, the sink and what the slash layer touches.
    NS.Perf = {
        on        = false,
        suspended = false,
        Note      = function() end,
        Open      = function() end,
        Close     = function() end,
        OnCommand = function()
            return { NS.LIBKA0S_MISSING .. ", so performance measurement is unavailable." }
        end,
    }
    return
end

NS.Perf = lib:New({
    name      = addonName,
    addonName = addonName,
    title     = NS.BRAND,
    slash     = NS.SLASH,
    sv        = addonName .. "PerfDB",   -- OutfitterRebornPerfDB, declared in the TOC (toc-file-§2)
    version   = NS.Version(),
    buckets = {
        { key = "auraScan" },                            -- modules/States.lua, the player UNIT_AURA scan
        { key = "zoneUpdate" },                          -- modules/States_Zone.lua, the debounced zone producer
        { key = "bagSync" },                             -- modules/Inventory.lua, Inv.Sync
        { key = "equipUpdate" },                         -- modules/Equip.lua, E.Update
        { key = "equipExecute", within = "equipUpdate" }, -- modules/Equip.lua, E.Execute from E.Update only
        { key = "triggerDispatch" },                     -- modules/Triggers_Binder.lua, Binder.Dispatch
        { key = "optimizeStep" },                        -- modules/Optimize*.lua, one resume of the GA
        { key = "dockFollow" },                          -- modules/Dock.lua, one throttled follow tick
        { key = "barRender" },                           -- modules/Bar.lua, Bar.Render
        { key = "tooltipUsedBy" },                       -- modules/Tooltips.lua, Tooltips.OnItem past its gates
    },
    -- The latch the capture's suspended arm takes its `perf` hold on. suspend/resume are NOT passed:
    -- the latch's standDown/standUp (core/LifecycleSetup.lua) are the one teardown.
    lifecycle = NS.lifecycle,
    -- NS.DebugLog and NS.Print are resolved at call time: the console lands after this file.
    log = function(line)
        if NS.DebugLog and NS.DebugLog.Add then NS.DebugLog:Add("Perf", line) else NS.Print(line) end
    end,
    print   = function(line) NS.Print(line) end,
    showLog = function()
        if NS.DebugLog and NS.DebugLog.Show and not NS.DebugLog:IsShown() then NS.DebugLog:Show() end
    end,
    -- No `decorate`: the library draws the step panel's close control from addonName itself
    -- (performance-§4).
})
