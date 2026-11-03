-- tests/test_disabled.lua — the disabled state is total (slash-commands-§7): all ten steps of the
-- conformance test, driven through the kit's recording mocks.
--
-- THE P3 BASELINE. No feature module exists before P4, so the addon as it stands registers nothing
-- at login and step 1's non-empty R_on would pass every later step trivially. The scene therefore
-- seeds a STAND-IN shaped exactly as a P4 module will be (design §5.12): a game-event set on the
-- addon object behind NS.RegisterGameEvents, which the latch's stand-up calls; a module in
-- NS.LIFECYCLE_MODULES with its own frame, a per-unit registration, an OnUpdate and a show decision,
-- whose Resume rebuilds from the stored settings; a bus receiver from NS.NewBusTarget; and an
-- AceTimer standing in for the LoadPass timer. Everything that stands it down and up is the real
-- latch (core/LifecycleSetup.lua), the real bus record (core/Bus.lua), the real dispatcher
-- (settings/Slash.lua), the real launcher and binding buttons (core/LauncherSetup.lua) and the real
-- skin picker (core/SkinSetup.lua). P4.27 replaces the stand-in with the real modules and adds the
-- Outfitter cases (design §9.3): the active-trigger seed below is pending until then.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- slash-commands-§2's never-feature verbs: these keep answering, normally, while disabled. `skin` is
-- NOT among them: §2 MUSTs its refusal and forbids listing it in `liveVerbs`.
local RESERVED = {
    help = true, config = true, version = true, enable = true, disable = true, debug = true,
    diagnostics = true, perf = true, get = true, set = true, list = true, reset = true, resetall = true,
}

-- Pinned here: no library constant carries it (slash-commands-§7, "Which refusal, by hold").
local PERF_LINE = "Not available during a performance capture."

local BINDING_BUTTONS = { "OutfitterRebornToggleWindow" }

local function regKey(r)
    return ("%s|%s|%s|%s"):format(tostring(r.target or r.owner), tostring(r.kind), tostring(r.event),
        tostring(r.unit))
end

local function regKeys(inst)
    local out = {}
    for _, r in ipairs(inst.mocks.__registrations()) do out[#out + 1] = regKey(r) end
    table.sort(out)
    return out
end

--- Every GAME event registered, with each target that held it, so a stood-down handler can be
--- reached straight. Bus messages (kind "message") are not game events to fire; the bus cases
--- below cover them.
local function eventTargets(inst)
    local out, names = {}, {}
    for _, r in ipairs(inst.mocks.__registrations()) do
        if r.event and r.kind ~= "message" then
            if not out[r.event] then
                out[r.event] = {}
                names[#names + 1] = r.event
            end
            out[r.event][#out[r.event] + 1] = { target = r.target, unit = r.unit }
        end
    end
    table.sort(names)
    return names, out
end

local function eventNames(inst)
    return (eventTargets(inst))
end

local function refusalLine(inst)
    return inst.mocks.LibStub("LibKa0s-Slash-1.0").DISABLED_LINE_FORMAT:format("Ka0s Outfitter Reborn", "/of enable")
end

--- The printed lines, with the chat tag stripped, so a line compares against its bare text.
local function printedBare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[OR%]|r ", "")) end
    return out
end

--- The stand-in for a P4 feature module (see the header). Its handlers are written the way the
--- pre-adoption addons wrote them, behind the one stood-down read: entering combat writes
--- `locked = true` and prints, the slash-commands-§7 failure in its purest form.
local function installStandIn(NS, M)
    local S = { heard = 0, wanted = true }
    local frame = M.CreateFrame("Frame", nil, M.UIParent)
    frame:Hide()
    S.frame = frame

    local function onCombat()
        if NS.IsStoodDown() then return end
        NS.db.profile.locked = true
        NS.Print("entering combat")
    end
    local function onWorld()
        if NS.IsStoodDown() then return end
        NS.Print("entering the world")
    end
    frame:SetScript("OnEvent", function(_, event)
        if NS.IsStoodDown() then return end
        NS.db.char.standInSeen = event
        frame:Show()
    end)

    -- The addon object's own set: the latch's stand-down unregisters it wholesale
    -- (addon:UnregisterAllEvents) and its stand-up calls this to rebuild it.
    NS.RegisterGameEvents = function()
        NS.SafeRegisterEvent(NS.addon, "PLAYER_REGEN_DISABLED", onCombat, NS.rejectedEvents)
        NS.SafeRegisterEvent(NS.addon, "PLAYER_ENTERING_WORLD", onWorld, NS.rejectedEvents)
    end

    --- Show at the SOURCE: the decision reads the latch, so a stood-down module cannot be re-shown.
    function S.Refresh()
        frame:SetShown(S.wanted and not NS.IsStoodDown())
    end
    --- Rebuilt FROM CURRENT STATE: the locked setting decides one registration (step 9).
    function S.Resume()
        NS.SafeRegisterUnitEvent(frame, "UNIT_AURA", NS.rejectedEvents, "player")
        if NS.GetSetting("locked") then
            NS.SafeRegisterEvent(frame, "PLAYER_TARGET_CHANGED", nil, NS.rejectedEvents)
        end
        frame:SetScript("OnUpdate", function() S.heard = S.heard + 1 end)
        S.Refresh()
    end
    function S.Suspend()
        frame:UnregisterAllEvents()
        frame:SetScript("OnUpdate", nil)
        S.Refresh()
    end

    NS.StandIn = S
    NS.LIFECYCLE_MODULES[#NS.LIFECYCLE_MODULES + 1] = "StandIn"

    -- The module's own bus receiver: dropped by the record at stand-down and replayed at stand-up.
    S.bus = assert(NS.NewBusTarget(), "no bus target (AceEvent absent?)")
    S.bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function() S.heard = S.heard + 1 end)

    -- What the login path does once P4 lands: register the game events and resume every module the
    -- latch walks, bottom to top as standUp does, so the baseline holds the real modules that have
    -- landed (PlayerState from P4.4) beside the stand-in, and a stand-up rebuilds exactly that set.
    NS.RegisterGameEvents()
    for i = #NS.LIFECYCLE_MODULES, 1, -1 do
        local m = NS[NS.LIFECYCLE_MODULES[i]]
        if m and m.Resume then m.Resume() end
    end
    return S
end

--- Baseline: enabled, the stand-in up and shown, the skin picker on screen, one AceTimer armed,
--- the stores watched and the records reset.
local function scene(opts)
    local inst = T.load(opts)
    local NS, M = inst.NS, inst.mocks
    local S = installStandIn(NS, M)
    NS.addon:ScheduleTimer(function() NS.Print("the timer fired") end, 5)
    M.__watchSv("OutfitterRebornPerfDB")
    M.__resetSvWrites()
    M.__resetPrinted()
    return inst, NS, M, S
end

--- The first-run skin picker, shown through the reserved verb (core/SkinSetup.lua NS.RunSkinVerb).
local function showPicker(M, NS)
    local before = #M.__shownFrames()
    local win = NS.RunSkinVerb()
    assertTrue(win ~= nil, "the fixture needs the skin picker on screen")
    assertTrue(#M.__shownFrames() > before, "the picker showed no frame")
    return win
end

test("Disabled 1: enabled, the addon registers something, arms something and shows something", function()
    local inst, NS, M, S = scene()
    assertTrue(#regKeys(inst) > 0, "the baseline registration set is empty; nothing below can fail")
    assertTrue(#M.__timers() > 0, "the baseline armed nothing; step 4 could not fail")
    assertTrue(S.frame:IsShown(), "the stand-in is not on screen to be hidden")
    assertFalse(NS.IsStoodDown())
end)

test("Disabled 2+3: disabling through the write seam leaves NO registration behind", function()
    -- red under: drop `addon:UnregisterAllEvents()` from standDown in core/LifecycleSetup.lua (the
    -- addon object keeps PLAYER_REGEN_DISABLED and PLAYER_ENTERING_WORLD), or drop the module walk
    -- (the stand-in's frame keeps UNIT_AURA).
    local inst, NS = scene()
    local before = regKeys(inst)
    assertTrue(#before > 0)
    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.IsDisabled() and NS.IsStoodDown(), "the write did not take the disabled hold")
    local after = regKeys(inst)
    assertEqual(#after, 0, "still registered: " .. table.concat(after, ", "))
end)

test("Disabled 2+3 (combat): a held secure write and a held picker start go at stand-down", function()
    -- red under: drop `NS.SecureQueue.Clear()` from standDown in core/LifecycleSetup.lua (the queue's
    -- PLAYER_REGEN_ENABLED survives), or drop NS.HideSkinPicker() (the picker's one-shot survives).
    local inst, NS, M = scene()
    local locked = true
    M.InCombatLockdown = function() return locked end
    local wrote = 0
    assertFalse(NS.SecureQueue.Run("standin.attrs", function()
        wrote = wrote + 1
        NS.db.profile.locked = true
    end), "the write ran in lockdown")
    NS.MaybeShowSkinPicker()
    locked = false
    local names, holders = eventTargets(inst)
    local regen = 0
    for _, h in ipairs(holders.PLAYER_REGEN_ENABLED or {}) do regen = regen + (h and 1 or 0) end
    assertTrue(regen >= 2, "the fixture needs the queue's and the picker's PLAYER_REGEN_ENABLED")
    assertTrue(#names > 0)

    assertTrue(NS.SetByPath("enabled", false))
    assertEqual(#regKeys(inst), 0, "still registered: " .. table.concat(regKeys(inst), ", "))
    M.__resetSvWrites()
    M.__resetPrinted()
    local shownBefore = #M.__shownFrames()
    for _, h in ipairs(holders.PLAYER_REGEN_ENABLED) do
        assertTrue(M.__fireUnconditional(h.target, "PLAYER_REGEN_ENABLED") >= 1,
            "PLAYER_REGEN_ENABLED reached no handler, so its silence proves nothing")
    end
    assertEqual(wrote, 0, "the dropped secure write ran")
    assertEqual(#M.__svWrites(), 0, "a held write landed while disabled")
    assertEqual(#M.__shownFrames(), shownBefore, "the held picker start showed while disabled")
end)

for _, arm in ipairs({ { label = "live", opts = nil }, { label = "degraded", opts = { libFiles = {} } } }) do
    test("Disabled 2+3 (" .. arm.label .. "): a module's bus receiver goes at stand-down and comes back", function()
        -- red under (degraded): make the Bus stub's StandDown in core/Bus.lua `return 0` before it
        -- unregisters (the receiver keeps hearing the bus while disabled)
        local inst = T.load(arm.opts)
        local NS = inst.NS
        local hits = 0
        local target = assert(NS.NewBusTarget(), "no bus target (AceEvent absent?)")
        target:RegisterMessage(NS.MSG.STACK_CHANGED, function() hits = hits + 1 end)
        NS.SendBus(NS.MSG.STACK_CHANGED)
        assertEqual(hits, 1, "the fixture's receiver never heard the bus")
        NS.RunVerb("disable")
        assertTrue(NS.IsDisabled())
        NS.SendBus(NS.MSG.STACK_CHANGED)
        assertEqual(hits, 1, "a bus receiver fired while disabled")
        local left = regKeys(inst)
        assertEqual(#left, 0, "still registered: " .. table.concat(left, ", "))
        NS.RunVerb("enable")
        assertFalse(NS.IsStoodDown())
        NS.SendBus(NS.MSG.STACK_CHANGED)
        assertEqual(hits, 2, "the receiver was not replayed at stand-up")
    end)
end

test("Disabled 4: no timer, ticker or OnUpdate is left armed, and none re-arms", function()
    -- red under: drop `addon:CancelAllTimers()` from standDown in core/LifecycleSetup.lua (the
    -- stand-in LoadPass timer stays armed and prints when fired)
    local _, NS, M, S = scene()
    assertTrue(#M.__timers() >= 2, "the fixture needs the AceTimer and the OnUpdate armed")
    assertTrue(NS.SetByPath("enabled", false))
    local live = M.__timers()
    assertEqual(#live, 0, "still armed: " .. #live)
    M.__fireTimers()
    assertEqual(#M.__timers(), 0, "something re-armed itself while disabled")
    assertEqual(#M.__printed(), 0, "a canceled timer printed")
    assertEqual(S.frame.__scripts and S.frame.__scripts.OnUpdate, nil, "the OnUpdate survived")
end)

test("Disabled 5: every display that was shown is hidden, refused at the source", function()
    -- red under: drop NS.HideSkinPicker() from standDown in core/LifecycleSetup.lua (the picker
    -- stays on screen), or the IsStoodDown read from the stand-in's show decision
    local _, NS, M, S = scene()
    local picker = showPicker(M, NS)
    assertTrue(S.frame:IsShown())
    assertTrue(NS.SetByPath("enabled", false))
    assertFalse(S.frame:IsShown(), "the stand-in stayed on screen")
    assertFalse(picker:IsShown(), "the skin picker stayed on screen")
    -- A show request while down is refused by the decision itself, not hidden after the fact.
    S.Refresh()
    assertFalse(S.frame:IsShown(), "the show decision re-showed a stood-down frame")
    assertEqual(NS.MaybeShowSkinPicker(), nil, "the first-run picker showed while disabled")
    assertFalse(picker:IsShown())
    for _, name in ipairs(BINDING_BUTTONS) do
        assertFalse(M._G[name]:IsShown(), name .. " is shown")
    end
end)

test("Disabled 6: every event fired anyway writes nothing, prints nothing, shows nothing", function()
    -- red under: make NS.IsStoodDown in core/LifecycleSetup.lua read only the `perf` hold (a disabled
    -- addon then reads as up: the stand-in's combat handler writes `locked = true` and prints)
    local inst, NS, M = scene()
    local events, holders = eventTargets(inst)
    assertTrue(#events > 0)
    local combatEntry = false
    for _, e in ipairs(events) do if e == "PLAYER_REGEN_DISABLED" then combatEntry = true end end
    assertTrue(combatEntry, "the combat-entry event is in the baseline set")
    assertTrue(NS.SetByPath("enabled", false))
    M.__resetSvWrites()
    M.__resetPrinted()
    -- The kit's frame survey is weak-keyed: collect first, so an unreferenced frame dropping out
    -- mid-loop never reads as an event hiding one.
    collectgarbage("collect")
    local shownBefore = #M.__shownFrames()
    for _, event in ipairs(events) do
        M.__fire(event)
        for _, h in ipairs(holders[event]) do
            local reached = M.__fireUnconditional(h.target, event, h.unit)
            assertTrue(reached >= 1, event .. " reached no handler, so its silence proves nothing")
        end
    end
    assertEqual(#M.__svWrites(), 0, "a game event wrote SavedVariables while disabled")
    assertEqual(#M.__printed(), 0, "a game event printed while disabled: " .. tostring(M.__printed()[1]))
    assertEqual(#M.__shownFrames(), shownBefore, "a game event showed a frame while disabled")
    assertFalse(NS.db.profile.locked == true, "entering combat locked the addon while disabled")
end)

--- A probe feature verb appended to THIS instance's table (the dispatcher holds the same table): it
--- is not behind the feature() wrapper, so its call count pins the dispatcher's own gate. `skin` is
--- the one shipped feature verb until P4.24, and its wrapper prints the same line, which would hide
--- a dispatcher that let it through.
local function addProbeVerb(NS)
    local probe = { calls = 0 }
    NS.COMMANDS[#NS.COMMANDS + 1] = { "probe", "a feature verb for the test", function()
        probe.calls = probe.calls + 1
        NS.db.profile.locked = not NS.db.profile.locked
    end }
    return probe
end

--- The verbs that answer while disabled: the reserved ones and the host's live verbs (`auto`, `zone`,
--- `iteminfo`, settings/Slash.lua's HOST_LIVE_VERBS, design §4.3.2), as the dispatcher reads them.
local function liveSet(NS)
    local live = {}
    for verb in pairs(RESERVED) do live[verb] = true end
    for _, verb in ipairs(NS.Slash.LIVE_VERBS) do live[verb] = true end
    return live
end

--- Walk every verb while disabled; returns how many feature (non-live) verbs were checked.
local function verbsWhileDisabled(NS, M, refusal)
    local features = 0
    local live = liveSet(NS)
    for _, row in ipairs(NS.COMMANDS) do
        local verb = row[1]
        M.__resetPrinted()
        M.__resetSvWrites()
        NS.Slash:OnSlash(verb)
        local out = printedBare(M)
        if live[verb] then
            -- `help` may name the disabled state above its index; refused means the line ALONE.
            assertFalse(#out == 1 and out[1] == refusal, verb .. " was refused while disabled")
        else
            features = features + 1
            assertEqual(#out, 1, verb .. ": exactly one line")
            assertEqual(out[1], refusal, verb)
            assertEqual(#M.__svWrites(), 0, verb .. " reached a write seam")
        end
        if verb == "enable" then
            assertFalse(NS.IsDisabled(), "`enable` switched the addon back on")
            assertTrue(NS.SetByPath("enabled", false))
        end
        -- `debug` toggles the console window; put it back so the next verb starts from the same screen.
        if NS.DebugLog:IsShown() then NS.DebugLog:Hide() end
    end
    return features
end

--- Under the `perf` hold alone a feature refuses with the capture line, never the disabled one.
local function verbsUnderPerfHold(NS, M, refusal)
    assertTrue(NS.SetByPath("enabled", true))
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    assertEqual(NS.StoodDownRefusal(), PERF_LINE)
    local features = 0
    local live = liveSet(NS)
    for _, row in ipairs(NS.COMMANDS) do
        if not live[row[1]] then
            features = features + 1
            M.__resetPrinted()
            NS.Slash:OnSlash(row[1])
            local out = printedBare(M)
            assertEqual(#out, 1, row[1])
            assertEqual(out[1], PERF_LINE, row[1])
            assertTrue(out[1] ~= refusal, row[1] .. " printed the disabled line under the perf hold")
        end
    end
    NS.Lifecycle:Release(NS.HOLD_PERF)
    return features
end

test("Disabled 7: every verb answers while disabled; a feature verb answers one refusal line", function()
    -- red under: drop `isEnabled` from the descriptor in settings/Slash.lua (the probe's handler then
    -- runs while disabled)
    local inst, NS, M = scene()
    local probe = addProbeVerb(NS)
    -- Under the perf hold the dispatcher lets a feature verb through and the handler refuses itself:
    -- the probe takes the same wrapper the shipped feature verbs do.
    local raw = NS.COMMANDS[#NS.COMMANDS][3]
    NS.COMMANDS[#NS.COMMANDS][3] = function(rest)
        local line = NS.StoodDownRefusal()
        if line and not NS.IsDisabled() then return NS.Print(line) end
        return raw(rest)
    end
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    assertTrue(NS.SetByPath("enabled", false))

    NS.Slash:OnSlash("")
    assertEqual(opened, 1, "bare /of opens the panel while disabled")

    local refusal = refusalLine(inst)
    assertTrue(verbsWhileDisabled(NS, M, refusal) >= 2, "skin and the probe were not both exercised")
    assertEqual(probe.calls, 0, "the dispatcher let a feature verb through while disabled")
    assertTrue(opened >= 2, "`config` opened the panel")
    assertTrue(verbsUnderPerfHold(NS, M, refusal) >= 2, "no feature verb was exercised under the perf hold")
    assertEqual(probe.calls, 0, "under the perf hold alone the handler itself refuses")
end)

test("Disabled 7 (degraded): the library-absent dispatcher gates a feature verb the same way", function()
    -- red under: drop the `d.isEnabled` check from the stub's OnSlash in settings/Slash.lua
    local inst = T.load{ libFiles = {} }
    local NS, M = inst.NS, inst.mocks
    NS.OpenOptionsPanel = function() end
    NS.RunVerb("disable")
    assertTrue(NS.IsDisabled())
    local probeRan = false
    NS.COMMANDS[#NS.COMMANDS + 1] = { "probe", "a feature verb", function() probeRan = true end }
    M.__resetPrinted()
    NS.Slash:OnSlash("probe")
    local out = printedBare(M)
    assertFalse(probeRan, "the stub dispatched a feature verb while disabled")
    assertEqual(out[#out], NS.Slash:DisabledLine(), "the stub's refusal is not the one disabled line")
    M.__resetPrinted()
    NS.Slash:OnSlash("version")
    assertTrue(#M.__printed() > 0, "version was refused while disabled")
end)

--- The client's MenuUtil, recorded for one right-click and taken away after it (the mock carries
--- none of its own; see tests/test_launcher.lua).
local function openMenu(M, obj)
    local menu = { entries = {} }
    local function entry(text, onClick)
        local e = { text = text, click = onClick, enabled = true }
        menu.entries[#menu.entries + 1] = e
        return { SetEnabled = function(_, on) e.enabled = on and true or false end }
    end
    local root = {
        CreateTitle    = function() end,
        CreateDivider  = function() end,
        CreateCheckbox = function(_, text, _, onClick) return entry(text, onClick) end,
        CreateButton   = function(_, text, onClick) return entry(text, onClick) end,
    }
    M.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    local ok, err = pcall(obj.OnClick, M.UIParent, "RightButton")
    M.MenuUtil = nil
    assert(ok, err)
    return menu
end

test("Disabled 8: launcher clicks and the key binding write nothing and show nothing", function()
    local inst, NS, M = scene()
    assertTrue(NS.SetByPath("enabled", false))
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    M.__resetSvWrites()
    collectgarbage("collect")
    local shownBefore = #M.__shownFrames()
    local obj = M.LibStub("LibDataBroker-1.1"):GetDataObjectByName("OutfitterReborn")

    obj.OnClick(M.UIParent, "LeftButton")
    assertEqual(opened, 1, "left-click still opens the panel")

    local menu = openMenu(M, obj)
    assertTrue(#menu.entries > 0, "right-click opened no menu")
    for _, e in ipairs(menu.entries) do
        local live = e.text == "Enabled" or e.text == "Open settings"
        assertEqual(e.enabled, live, e.text .. (live and " must stay live" or " must be grayed"))
    end
    assertEqual(#M.__svWrites(), 0, "a launcher click wrote SavedVariables")
    assertEqual(#M.__shownFrames(), shownBefore, "a launcher click showed a frame")

    -- The key binding (a CLICK binding): one refusal line, no handler, no write, no show.
    local refusal = refusalLine(inst)
    for _, name in ipairs(BINDING_BUTTONS) do
        M.__resetPrinted()
        local before = opened
        M._G[name]:__fire("OnClick", "LeftButton", true)
        local out = printedBare(M)
        assertEqual(#out, 1, name)
        assertEqual(out[1], refusal, name)
        assertEqual(opened, before, name .. " ran its handler while disabled")
    end
    assertEqual(#M.__svWrites(), 0, "a key press wrote SavedVariables")
    assertEqual(#M.__shownFrames(), shownBefore, "a key press showed a frame")

    -- Enabled again, the perf hold alone: the capture line, never the disabled one, and no handler.
    assertTrue(NS.SetByPath("enabled", true))
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    for _, name in ipairs(BINDING_BUTTONS) do
        M.__resetPrinted()
        local before = opened
        M._G[name]:__fire("OnClick", "LeftButton", true)
        local out = printedBare(M)
        assertEqual(#out, 1, name)
        assertEqual(out[1], PERF_LINE, name)
        assertEqual(opened, before, name .. " ran its handler under the perf hold")
    end
    NS.Lifecycle:Release(NS.HOLD_PERF)
end)

test("Disabled 9: re-enabling restores the set FROM CURRENT STATE, not a snapshot", function()
    local inst, NS = scene()
    local on = table.concat(regKeys(inst), ",")
    local onNames = eventNames(inst)
    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.SetByPath("enabled", true))
    assertEqual(table.concat(regKeys(inst), ","), on)
    assertTrue(NS.StandIn.frame:IsShown(), "the stand-in did not come back on screen")

    -- A setting changed while disabled comes back in the rebuilt set.
    assertFalse(table.concat(eventNames(inst), ","):find("PLAYER_TARGET_CHANGED", 1, true) ~= nil)
    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.SetByPath("locked", true))
    assertEqual(#regKeys(inst), 0, "a write while disabled registered something")
    assertTrue(NS.SetByPath("enabled", true))
    -- The baseline's event names (the stand-in's and the landed modules') plus the one the setting adds.
    local want = { PLAYER_TARGET_CHANGED = true }
    for _, e in ipairs(onNames) do want[e] = true end
    local wantNames = {}
    for e in pairs(want) do wantNames[#wantNames + 1] = e end
    table.sort(wantNames)
    assertEqual(table.concat(eventNames(inst), ","), table.concat(wantNames, ","))
end)

test("Disabled 10: releasing ONE hold does not resurrect an addon the other holds down", function()
    -- red under: make NS.ApplyEnabled in core/LifecycleSetup.lua call NS.StandUp() on enable instead
    -- of releasing the `disabled` hold -- order B then comes back up while the `perf` hold is taken.
    local inst, NS = scene()
    T.assertLatchHoldOrder{
        lifecycle  = NS.Lifecycle,
        perfHold   = NS.HOLD_PERF,
        setEnabled = function(on) assertTrue(NS.SetByPath("enabled", on)) end,
        regSet     = function() return inst.mocks.__registrations() end,
        label      = "OutfitterReborn",
    }
end)

test("Disabled 10 (degraded): the library-absent latch holds the same order", function()
    -- The stub latch in core/LifecycleSetup.lua, written through `/of enable` and `/of disable`: on
    -- this arm a written-through `enabled` runs no onChange, and the verb takes the hold itself.
    local inst, NS = scene{ libFiles = {} }
    T.assertLatchHoldOrder{
        lifecycle  = NS.Lifecycle,
        perfHold   = NS.HOLD_PERF,
        setEnabled = function(on) NS.RunVerb(on and "enable" or "disable") end,
        regSet     = function() return inst.mocks.__registrations() end,
        label      = "OutfitterReborn (degraded)",
    }
end)

test("Disabled: a profile switch re-reads the stored switch while disabled", function()
    local _, NS = scene()
    assertTrue(NS.SetByPath("enabled", false))
    NS.db:SetProfile("Other")
    assertFalse(NS.IsDisabled(), "the new profile's default `enabled = true` did not stand the addon up")
    NS.db:SetProfile("Default")
    assertTrue(NS.IsDisabled(), "switching back did not re-take the hold")
end)

test("Disabled (Outfitter): an outfit's active IN_DUNGEON trigger holds no event and no timer while down",
    function() end,
    "pending P4.27: the trigger binder, the zone producer and the Equip bracket land in P4; the case "
        .. "seeds an outfit with an active IN_DUNGEON trigger before the stand-down (design §9.3)")
