-- tests/unit_load.lua — a UNIT instance: the client's whole load and login, without the login resume
-- walk (core/OutfitterReborn.lua NS:OnEnable, P4.27).
--
-- Loaded as `dofile(T.root .. "/tests/unit_load.lua")(T)`; answers `load(opts)`, which takes T.load's
-- options and answers what it answers.
--
-- WHY. Since P4.27 every T.load() logs in the way the client does: OnEnable resumes every module in
-- NS.LIFECYCLE_MODULES, so the instance holds the whole graph live (the States poll, the binder, the
-- dock, the bar, the first-run skin picker's timer). A suite that pins ONE module drives that module's
-- Resume itself, with recorded fakes for its neighbors (design §12, the fake rule), and the live
-- graph would answer its events, timers and fakes too. This instance logs in with the walk emptied:
-- OnEnable still runs (the legacy guard, the host's game events), PLAYER_LOGIN still settles the skin
-- library's retry frame (tests/run.lua), and the picker's login timer is canceled, so the instance
-- is the one every such suite was written against. The whole-graph cases (test_disabled,
-- test_surface_parity, test_skeleton) use T.load().

return function(T)
    return function(opts)
        opts = opts or {}
        local copy = {}
        for k, v in pairs(opts) do copy[k] = v end
        copy.enable = false
        local inst = T.load(copy)
        if opts.init == false or opts.enable == false then return inst end
        local NS, M = inst.NS, inst.mocks
        local skin = M.LibStub("LibKa0s-Skin-1.0", true)
        local retry = skin and skin.__euiEventFrame
        if retry and retry.__fire then retry:__fire("OnEvent", "PLAYER_LOGIN") end
        -- Emptied IN PLACE: the login's NS.StandUp walks the table core/LifecycleSetup.lua holds,
        -- which NS.LIFECYCLE_MODULES names, so a fresh table there would not empty it.
        local walk, saved = NS.LIFECYCLE_MODULES, {}
        for i = #walk, 1, -1 do saved[i], walk[i] = walk[i], nil end
        local ok, err = pcall(M.LibStub("AceAddon-3.0").EnableAddon, M.LibStub("AceAddon-3.0"), NS)
        for i = 1, #saved do walk[i] = saved[i] end
        if not ok then error(err, 0) end
        NS.addon:CancelAllTimers()
        if M.__fireTimers then M.__fireTimers() end
        return inst
    end
end
