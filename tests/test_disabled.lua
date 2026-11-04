-- tests/test_disabled.lua — the disabled state is total (slash-commands-§7): all ten steps of the
-- conformance test, driven through the kit's recording mocks, on the REAL addon (P4.27).
--
-- THE SCENE. One whole login (T.load: OnEnable resumes every module in NS.LIFECYCLE_MODULES), the
-- first zone-in seeded through the real LoadPass, an outfit with an IN_DUNGEON trigger worn in a
-- 5-man, the outfit bar and the docked window on screen, the slot checkboxes showing its selection,
-- the first-run skin picker up, and the States poll, the bar and the Dock driver armed. Nothing is a
-- stand-in: the latch (core/LifecycleSetup.lua), the bus record (core/Bus.lua), the dispatcher
-- (settings/Slash.lua), the launcher and the binding buttons (core/LauncherSetup.lua), the skin
-- picker (core/SkinSetup.lua) and every module stand down and up for real. The Outfitter cases at
-- the end pin design §9.3's list: the trigger's events and timers, the Equip bracket, the equipment
-- event, the latch-gated hook bodies, the Dock driver and the sheet button, the auto presses, the
-- LoadPass timer and the Pawn/WeightsWatcher watch, and the rebuild from current state.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local installPaint = dofile(T.root .. "/tests/_kit/mock_paint.lua")

-- slash-commands-§2's never-feature verbs: these keep answering, normally, while disabled. `skin` is
-- NOT among them: §2 MUSTs its refusal and forbids listing it in `liveVerbs`.
local RESERVED = {
    help = true, config = true, version = true, enable = true, disable = true, debug = true,
    diagnostics = true, perf = true, get = true, set = true, list = true, reset = true, resetall = true,
}

-- Pinned here: no library constant carries it (slash-commands-§7, "Which refusal, by hold").
local PERF_LINE = "Not available during a performance capture."

--- The 14 binding buttons, by global name (NS.BINDINGS, core/LauncherSetup.lua).
local function bindingButtons(NS)
    local out = {}
    for _, row in ipairs(NS.BINDINGS) do out[#out + 1] = row.command:match("^CLICK (.-):LeftButton$") end
    return out
end

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

local function refusalLine(inst)
    return inst.mocks.LibStub("LibKa0s-Slash-1.0").DISABLED_LINE_FORMAT:format("Ka0s Outfitter Reborn", "/or enable")
end

--- The printed lines, with the chat tag stripped, so a line compares against its bare text.
local function printedBare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[OR%]|r ", "")) end
    return out
end

--- Fire every armed timer, a few rounds: the States poll repeats, so the queue never empties.
local function settle(M)
    for _ = 1, 4 do
        if M.__fireTimers() == 0 then break end
    end
end

--- The outfits a 5-man wears: one with the IN_DUNGEON trigger (its defaults equip in 5-man
--- instances), worn at the zone-in.
local function seedDungeon(NS, M)
    local head = NS.ItemInfo.Snapshot(NS.ItemInfo.FromSlot("HeadSlot"))
    local id = NS.Outfits.Create("Dungeon", { HeadSlot = head }, { trigger = "IN_DUNGEON" })
    M.__world:setInstance({ type = "party", instanceID = 1001 })
    M.__fire("PLAYER_ENTERING_WORLD")
    settle(M)
    return id
end

--- Baseline: the whole addon up on the geared scenario (see the header), the stores watched and the
--- records reset. Answers inst, NS, M, S where S = { outfit = id, ctx = the binding's context }.
local function scene(opts)
    opts = opts or {}
    -- The kit's paint recorder, so a font string is an object of its own and not the frame that made
    -- it (mock_base.lua's "Known divergence"): without it the window's footer label hides the window.
    local inst = T.load({ libFiles = opts.libFiles, mutate = function(M)
        installPaint(M)
        M.__gear:load("geared")
        if opts.mutate then opts.mutate(M) end
    end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    M.__fire("PLAYER_ENTERING_WORLD")          -- the first zone-in arms the LoadPass
    settle(M)
    local S = { outfit = seedDungeon(NS, M) }
    S.ctx = NS.TriggerBinder.Context(S.outfit)
    assertTrue(NS.SetByPath("bar.shown", true))
    M.__world:openCharacter()
    NS.Dock.Open()
    -- The client runs the window's OnShow when it shows (the base mock only flips the flag); the
    -- Dock's OnShow hook is what arms the follow on the driver frame.
    M.OutfitterRebornWindow:__fire("OnShow")
    NS.Stack.Select(S.outfit)
    settle(M)
    M.__watchSv("OutfitterRebornPerfDB")
    M.__resetSvWrites()
    M.__resetPrinted()
    return inst, NS, M, S
end

--- The frames this addon shows, by global name: the docked window, the sheet button and the slot
--- checkboxes (the bar is NS.Bar.Frame(), the picker NS.RunSkinVerb()'s answer).
local OWN_FRAMES = { "OutfitterRebornWindow", "OutfitterRebornSheetButton", "OutfitterRebornSlotEnables" }

--- Every display the scene put on screen, as { label = frame }.
local function displays(NS, M)
    local out = { bar = NS.Bar.Frame(), picker = NS.RunSkinVerb() }
    for _, name in ipairs(OWN_FRAMES) do out[name] = M._G[name] end
    return out
end

test("Disabled 1: enabled, the addon registers something, arms something and shows something", function()
    local inst, NS, M, S = scene()
    assertTrue(#regKeys(inst) > 0, "the baseline registration set is empty; nothing below can fail")
    assertTrue(#M.__timers() > 0, "the baseline armed nothing; step 4 could not fail")
    for label, frame in pairs(displays(NS, M)) do
        assertTrue(frame ~= nil and frame:IsShown(), label .. " is not on screen to be hidden")
    end
    assertTrue(NS.TriggerBinder.IsBound(S.outfit), "the dungeon outfit's trigger is not bound")
    assertTrue(NS.Stack.IsWorn(S.outfit), "the dungeon outfit is not worn in the 5-man")
    assertFalse(NS.IsStoodDown())
end)

test("Disabled 2+3: disabling through the write seam leaves NO registration behind", function()
    -- red under: drop the module walk from standDown in core/LifecycleSetup.lua (PlayerState, States,
    -- Inventory and the binder's targets keep their events), or NS.BusStandDown() (every module's
    -- bus receiver stays registered).
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
    NS.HideSkinPicker()                     -- the login's picker closed, so a start can be held
    local locked = true
    M.InCombatLockdown = function() return locked end
    local wrote = 0
    assertFalse(NS.SecureQueue.Run("test.attrs", function()
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
    -- red under: an empty States.Suspend in modules/States.lua (its repeating poll stays armed), or an
    -- empty Dock.Suspend in modules/Dock.lua (the driver's OnUpdate survives).
    local _, NS, M = scene()
    assertTrue(#M.__timers() >= 2, "the fixture needs the States poll and the Dock driver armed")
    assertTrue(NS.SetByPath("enabled", false))
    local live = M.__timers()
    assertEqual(#live, 0, "still armed: " .. #live)
    M.__fireTimers()
    assertEqual(#M.__timers(), 0, "something re-armed itself while disabled")
    assertEqual(#M.__printed(), 0, "a canceled timer printed")
    assertEqual(M.OutfitterRebornDockDriver.__scripts.OnUpdate, nil, "the Dock driver's OnUpdate survived")
end)

test("Disabled 4 (combat): the skin notice's combat retry is canceled at stand-down and writes nothing", function()
    -- red under: arm the retry in NS.MaybeShowSkinNotice (core/SkinSetup.lua) with the bare
    -- `_G.C_Timer.After(NOTICE_RETRY, ...)` (no stand-down can cancel it: it stays armed, then fires
    -- into the notice's "claimed" branch and writes db.global.skinNotice while disabled)
    local inst, NS, M = scene()
    local Options = inst.mocks.LibStub("LibKa0s-Options-1.0")
    NS.HideSkinPicker()
    NS.db.global.skinNotice = nil              -- an account that has not seen this notice version
    Options.__noticeClaimed = nil
    local locked = true
    M.InCombatLockdown = function() return locked end
    local before = #M.__timers()
    local _, why = NS.MaybeShowSkinNotice()
    assertEqual(why, "combat", "the fixture needs the notice deferred by combat")
    assertTrue(#M.__timers() > before, "the combat retry was not armed; nothing below can fail")
    assertTrue(NS.SetByPath("enabled", false))
    assertEqual(#M.__timers(), 0, "the notice's combat retry survived the stand-down")
    -- Combat ends and another addon claims the notice: a surviving retry would record it here.
    locked = false
    Options.__noticeClaimed = Options.SKIN_NOTICE_VERSION
    M.__resetSvWrites()
    M.__resetPrinted()
    M.__fireTimers()
    assertEqual(#M.__svWrites(), 0, "a retry wrote SavedVariables while disabled")
    assertEqual(#M.__printed(), 0, "a canceled retry printed")
    -- red under: drop the stood-down `noticeWaiting = false` from NS.HideSkinPicker (the canceled
    -- retry's flag stays up, so the next stand-up never asks again)
    assertTrue(NS.SetByPath("enabled", true))
    NS.db.global.skinNotice = nil
    Options.__noticeClaimed = nil
    locked = true
    before = #M.__timers()
    _, why = NS.MaybeShowSkinNotice()
    assertEqual(why, "combat")
    assertTrue(#M.__timers() > before, "the stand-up's notice in combat armed no retry")
end)

test("Disabled 5: every display that was shown is hidden, refused at the source", function()
    -- red under: drop NS.HideSkinPicker() from standDown in core/LifecycleSetup.lua (the picker
    -- stays on screen), or the IsStoodDown read from Bar.ShouldShow in modules/Bar.lua (a refresh
    -- while down re-shows the bar).
    local _, NS, M = scene()
    local shown = displays(NS, M)
    assertTrue(NS.SetByPath("enabled", false))
    for label, frame in pairs(shown) do assertFalse(frame:IsShown(), label .. " stayed on screen") end
    -- A show request while down is refused by the decision itself, not hidden after the fact.
    NS.Bar.Refresh()
    NS.Dock.Open()
    NS.SlotEnables.Show(NS.Stack.Selected())
    assertEqual(NS.MaybeShowSkinPicker(), nil, "the first-run picker showed while disabled")
    for label, frame in pairs(shown) do assertFalse(frame:IsShown(), label .. " re-showed while down") end
    for _, name in ipairs(bindingButtons(NS)) do assertFalse(M._G[name]:IsShown(), name .. " is shown") end
end)

test("Disabled 6: every event fired anyway writes nothing, prints nothing, shows nothing", function()
    -- red under: make NS.IsStoodDown in core/LifecycleSetup.lua read only the `perf` hold (a disabled
    -- addon then reads as up: the EQUIPMENT_SETS_CHANGED handler syncs the new set into db.char).
    local inst, NS, M = scene()
    local events, holders = eventTargets(inst)
    assertTrue(#events > 0)
    local combatEntry = false
    for _, e in ipairs(events) do if e == "PLAYER_REGEN_DISABLED" then combatEntry = true end end
    assertTrue(combatEntry, "the combat-entry event is in the baseline set")
    assertTrue(NS.SetByPath("enabled", false))
    -- The world moves on while the addon is down: a new equipment set, which a running Equipment
    -- Manager mirror would copy into db.char on EQUIPMENT_SETS_CHANGED.
    M.__gear:addSet({ name = "Made while down" })
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
    settle(M)
    assertEqual(#M.__svWrites(), 0, "a game event wrote SavedVariables while disabled")
    assertEqual(#M.__printed(), 0, "a game event printed while disabled: " .. tostring(M.__printed()[1]))
    assertEqual(#M.__shownFrames(), shownBefore, "a game event showed a frame while disabled")
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
    assertEqual(opened, 1, "bare /or opens the panel while disabled")

    local refusal = refusalLine(inst)
    assertTrue(verbsWhileDisabled(NS, M, refusal) >= 2, "skin and the probe were not both exercised")
    assertEqual(probe.calls, 0, "the dispatcher let a feature verb through while disabled")
    assertTrue(opened >= 2, "`config` opened the panel")
    -- The report's second form (debug-logging-§14) answers while disabled too.
    -- red under: route the `diagnostics` word of doDebug in settings/Slash.lua through feature() (the
    -- bare `debug` row still answers, so the walk above passes; the disabled hold's refusal prints
    -- instead of the report)
    local ran, run = 0, NS.DebugLog.RunDiagnostics
    NS.DebugLog.RunDiagnostics = function(...) ran = ran + 1; return run(...) end
    M.__resetPrinted()
    NS.Slash:OnSlash("debug diagnostics")
    NS.DebugLog.RunDiagnostics = run
    if NS.DebugLog:IsShown() then NS.DebugLog:Hide() end
    assertEqual(ran, 1, "`debug diagnostics` did not reach RunDiagnostics while disabled")
    for _, line in ipairs(printedBare(M)) do
        assertTrue(line ~= refusal, "`debug diagnostics` was refused while disabled")
    end
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

    -- The 14 key bindings (CLICK bindings): one refusal line each, no handler, no write, no show.
    -- The two auto presses are among them, and `auto.enabled` stays as it was.
    local refusal = refusalLine(inst)
    local auto = NS.GetSetting("auto.enabled")
    for _, name in ipairs(bindingButtons(NS)) do
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
    -- red under: a binding OnClick in core/LauncherSetup.lua without its NS.StoodDownRefusal() read
    -- (AutoOff then runs `/or auto off`, a live verb, and writes auto.enabled while disabled).
    assertEqual(NS.GetSetting("auto.enabled"), auto, "an auto press changed auto.enabled while disabled")

    -- Enabled again, the perf hold alone: the capture line, never the disabled one, and no handler.
    assertTrue(NS.SetByPath("enabled", true))
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    for _, name in ipairs(bindingButtons(NS)) do
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

test("disabled: the broker shows the brand and refuses outfit clicks", function()
    -- The Outfits data source (modules/Broker.lua, plan Task 3.8): the object stays, its text goes
    -- back to the brand, its menu's outfit rows are grayed and refuse with the one line, and its
    -- right-click shows nothing. Its menu is drawn through NS.OpenMenu, so W.ContextMenu is recorded.
    local inst, NS, M, S = scene()
    local obj = M.LibStub("LibDataBroker-1.1"):GetDataObjectByName("OutfitterRebornOutfits")
    assertEqual(obj.text, "Dungeon", "the worn outfit is not on the broker; nothing below can fail")
    assertTrue(NS.SetByPath("enabled", false))
    -- red under: a Broker.Suspend that leaves the outfit's name up.
    assertEqual(obj.text, NS.BRAND, "the stood-down broker still names the outfit")
    assertEqual(obj.icon, NS.Constants.DEFAULT_OUTFIT_ICON)

    local menus = {}
    M.LibStub("LibKa0s-Widgets-1.0").ContextMenu = function(_, rows) menus[#menus + 1] = rows; return {} end
    M.__resetSvWrites()
    M.__resetPrinted()
    local shownBefore = #M.__shownFrames()
    obj.OnClick(M.UIParent, "LeftButton")
    assertEqual(#menus, 1, "left-click opened no menu")
    local row
    for _, r in ipairs(menus[1]) do
        if r.label and r.label:find("Dungeon", 1, true) then row = r end
    end
    assertTrue(row ~= nil, "the outfit is not in the menu")
    assertTrue(row.disabled, "an outfit row is live while disabled")
    row.onClick()
    local refusal = refusalLine(inst)
    assertEqual(table.concat(printedBare(M), "\n"), refusal, "the outfit click did not refuse with the one line")
    assertTrue(NS.Stack.IsWorn(S.outfit), "a stood-down click changed the stack")

    M.__resetPrinted()
    obj.OnClick(M.UIParent, "RightButton")
    assertEqual(table.concat(printedBare(M), "\n"), refusal, "the right-click did not refuse")
    assertEqual(#M.__svWrites(), 0, "a broker click wrote SavedVariables")
    assertEqual(#M.__shownFrames(), shownBefore, "a broker click showed a frame")

    assertTrue(NS.SetByPath("enabled", true))
    settle(M)
    assertEqual(obj.text, "Dungeon", "the stand-up did not bring the outfit back")
end)

--- How many registrations `target` holds.
local function holds(inst, target)
    local n = 0
    for _, r in ipairs(inst.mocks.__registrations()) do
        if r.target == target or r.owner == target then n = n + 1 end
    end
    return n
end

test("Disabled 9: re-enabling restores the set FROM CURRENT STATE, not a snapshot", function()
    local inst, NS, M, S = scene()
    local on = table.concat(regKeys(inst), ",")
    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.SetByPath("enabled", true))
    settle(M)
    assertEqual(table.concat(regKeys(inst), ","), on)
    assertTrue(NS.Bar.Frame():IsShown(), "the bar did not come back on screen")

    -- A setting changed while disabled decides the rebuilt set: with auto.enabled off the binder
    -- binds nothing on the way up, so the dungeon trigger's events stay unregistered.
    local trigger = S.ctx.target
    assertTrue(holds(inst, trigger) > 0, "the trigger holds no event to lose; nothing below can fail")
    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.SetByPath("auto.enabled", false))
    assertEqual(#regKeys(inst), 0, "a write while disabled registered something")
    assertTrue(NS.SetByPath("enabled", true))
    settle(M)
    assertFalse(NS.TriggerBinder.IsBound(S.outfit), "the stand-up bound a trigger auto.enabled turned off")
    assertEqual(holds(inst, trigger), 0, "the trigger's events came back from a snapshot")
    assertTrue(#regKeys(inst) > 0, "the stand-up rebuilt nothing")
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
    -- The stub latch in core/LifecycleSetup.lua, written through `/or enable` and `/or disable`: on
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

-- ── the Outfitter cases (design §9.3) ───────────────────────────────────────────────────────────

test("Disabled (Outfitter): an outfit's active IN_DUNGEON trigger holds no event and no timer while down", function()
    -- red under: an empty TriggerBinder.Suspend in modules/Triggers_Binder.lua (the binding's target
    -- keeps PLAYER_ENTERING_WORLD and its timers).
    local inst, NS, M, S = scene()
    assertTrue(NS.Stack.IsWorn(S.outfit), "the trigger is not active; nothing below can fail")
    assertTrue(holds(inst, S.ctx.target) > 0, "the binding holds no event")
    S.ctx.target:ScheduleTimer(function() NS.Print("the trigger's timer fired") end, 5)
    assertTrue(NS.SetByPath("enabled", false))
    assertEqual(holds(inst, S.ctx.target), 0, "the dungeon trigger kept an event while down")
    assertEqual(#M.__timers(), 0, "an AceTimer is live while down")
    M.__resetPrinted()
    M.__fireTimers()
    assertEqual(#M.__printed(), 0, "the trigger's canceled timer fired")
end)

test("Disabled (Outfitter): the Equip bracket is zeroed, nothing is wanted and SFX is back, down and up", function()
    -- red under: Equip.Suspend in modules/Equip.lua without its restoreSFX() (the swap's mute stays).
    local _, NS, M = scene()
    local E, st = NS.Equip, NS.Equip.__state
    M.__cvars.Sound_EnableSFX = "1"
    E.Batch(function()
        E.Request()
        st.sfxSaved = M.__cvars.Sound_EnableSFX     -- a swap's mute, mid-flight
        M.__cvars.Sound_EnableSFX = "0"
        assertTrue(st.depth > 0 and E.Pending(), "the fixture needs an open Batch and a pending update")
        assertTrue(NS.SetByPath("enabled", false))
    end)
    assertEqual(st.depth, 0, "a Batch closing over the stand-down left a depth")
    assertFalse(E.Pending(), "an update is still wanted while down")
    assertEqual(M.__cvars.Sound_EnableSFX, "1", "the stand-down left the swap's SFX mute on")
    assertTrue(NS.SetByPath("enabled", true))
    assertEqual(st.depth, 0, "the stand-up left a depth")
    assertEqual(M.__cvars.Sound_EnableSFX, "1")
end)

--- A stable rendering of a table, keys sorted, for a before/after compare.
local function dump(v, seen)
    if type(v) ~= "table" then return tostring(v) end
    seen = seen or {}
    if seen[v] then return "<cycle>" end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. dump(v[k], seen) end
    return "{" .. table.concat(out, ",") .. "}"
end

test("Disabled (Outfitter): PLAYER_EQUIPMENT_CHANGED while down leaves db.char unchanged", function()
    -- Three independent gates hold it, so no single edit turns it red: the scan path's NS.IsStoodDown()
    -- reads, Inventory's `active` flag and the bus stand-down. red under: all three together --
    -- NS.IsStoodDown in core/LifecycleSetup.lua reading only the `perf` hold, `NS.BusStandDown()`
    -- dropped from standDown, and Inv.Suspend in modules/Inventory.lua leaving `active` set (the scan
    -- runs, the Watch hears INVENTORY_CHANGED and records the swap into db.char).
    local inst, NS, M = scene()
    local _, holders = eventTargets(inst)
    assertTrue(NS.SetByPath("enabled", false))
    local before = dump(NS.db.char)
    -- A hand swap while down: the hero chest from bag 0 slot 5 onto the chest slot.
    M.PickupContainerItem(0, 5)
    M.PickupInventoryItem(5)
    M.__gear:deliver()
    for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "BAG_UPDATE",
                             "BAG_UPDATE_DELAYED" }) do
        M.__fire(event, event == "UNIT_INVENTORY_CHANGED" and "player" or 0)
        for _, h in ipairs(holders[event] or {}) do M.__fireUnconditional(h.target, event, h.unit or 0) end
    end
    settle(M)
    assertEqual(dump(NS.db.char), before, "db.char changed while down")
end)

--- What each latch-gated hook body did, as { effect = true|false }: the used-by line, a compare
--- tooltip, the pet-summon stamp (a Compat.GetTime read), the quick slot's PreClick and the sheet
--- button's re-show on the PaperDollFrame OnShow.
local function hookEffects(NS, M)
    local tip = M.GameTooltip
    tip:SetBagItem(0, 1)
    M.__world:tooltipPostCall(M.Enum.TooltipDataType.Item, tip, nil)
    local usedBy = false
    for i = 1, tip:NumLines() do
        local text = tip["TextLeft" .. i]:GetText()
        if type(text) == "string" and text:find("Equipment Sets: ", 1, true) == 1 then usedBy = true end
    end
    M.GameTooltip:SetHyperlink(T.fixtures.items.db.head_plate.link)
    M.GameTooltip:Show()
    M.GameTooltip_ShowCompareItem(M.GameTooltip)
    local compares = 0
    for i = 1, 10 do
        local c = M["OutfitterRebornCompareTooltip" .. i]
        if c and c:IsShown() then compares = compares + 1 end
    end
    local C, reads = NS.Compat, 0
    local getTime = C.GetTime
    C.GetTime = function() reads = reads + 1; return getTime() end
    M.C_PetJournal.SummonPetByGUID("BattlePet-0-000000000001")
    C.GetTime = getTime
    M.__slotButtons.HeadSlot:__fire("PreClick", "LeftButton", false)
    M.__world:closeCharacter()
    M.__world:openCharacter()
    return { usedBy = usedBy, compare = compares > 0, petStamp = reads > 0,
             quickSlot = NS.QuickSlots.CurrentSlot() ~= nil,
             sheetButton = M.OutfitterRebornSheetButton:IsShown() }
end

test("Disabled (Outfitter): the tooltip, compare, pet, quick-slot and PaperDoll hook bodies no-op while down", function()
    -- red under: drop the NS.IsStoodDown() read from the Compare gate in modules/Tooltips_Compare.lua,
    -- or the `button:Hide()` from Dock.Suspend in modules/Dock.lua (the sheet button is up through
    -- the PaperDollFrame OnShow).
    local _, NS, M = scene()
    local greatsword = NS.ItemInfo.Snapshot(NS.ItemInfo.FromBag(0, 1))
    NS.Outfits.Create("Hands", { MainHandSlot = greatsword,
        HeadSlot = { id = 219001, invType = "INVTYPE_HEAD", quality = 3, level = 600, name = "Helm 1",
                     link = "|cff0070dd|Hitem:219001::::::::80:::::::::|h[Helm 1]|h|r" } })
    M.__world:setCompare(true, true)
    local up = hookEffects(NS, M)
    for what, acted in pairs(up) do assertTrue(acted, what .. " did not act standing up; its silence below proves nothing") end
    assertTrue(NS.SetByPath("enabled", false))
    M.__resetSvWrites()
    M.__resetPrinted()
    local down = hookEffects(NS, M)
    for what, acted in pairs(down) do assertFalse(acted, what .. " acted while down") end
    assertEqual(#M.__svWrites(), 0, "a hook body wrote SavedVariables while down")
    assertEqual(#M.__printed(), 0, "a hook body printed while down")
end)

test("Disabled (Outfitter): the outward drawer goes back to Blizzard's at stand-down and stays there", function()
    -- The head slot's popout arrow, a recorder: Blizzard anchors it `LEFT` -> slot `RIGHT` (-8, 0)
    -- (wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:1532).
    local arrow = { pts = {} }
    function arrow:ClearAllPoints() self.pts = {} end
    function arrow:SetPoint(...) self.pts[#self.pts + 1] = { ... } end
    local _, NS, M = scene({ mutate = function(M) M.__slotButtons.HeadSlot.popoutButton = arrow end })
    assertEqual(arrow.pts[1] and arrow.pts[1][1], "RIGHT", "the open window did not turn the drawer outward")
    assertTrue(NS.SetByPath("enabled", false))
    -- red under: drop the QuickSlots.DrawerSync() call from QuickSlots.Suspend.
    assertEqual(arrow.pts[1] and arrow.pts[1][1], "LEFT", "the stand-down left the arrow outward")
    M.OutfitterRebornWindow:__fire("OnShow")
    assertEqual(#arrow.pts, 1)
    assertEqual(arrow.pts[1][1], "LEFT", "a window show while down turned the drawer outward")
end)

test("Disabled (Outfitter): the LoadPass timer and the Pawn/WeightsWatcher watch are canceled", function()
    -- red under: an Outfits.Suspend in modules/Outfits_Seed.lua that leaves O.loadTimer armed, or a
    -- Stats.Suspend in modules/ItemStats_Sources.lua that keeps its ADDON_LOADED watch.
    local inst = T.load({ mutate = function(M) M.__gear:load("geared") end })
    local NS, M = inst.NS, inst.mocks
    M.__fire("PLAYER_ENTERING_WORLD")                -- the first zone-in arms the 1 s LoadPass
    assertTrue(NS.Outfits.loadTimer ~= nil, "the LoadPass timer is not armed; nothing below can fail")
    local function watching()
        for _, r in ipairs(M.__registrations()) do
            if r.event == "ADDON_LOADED" and r.kind == "event" and r.target ~= NS.addon then return true end
        end
        return false
    end
    assertTrue(watching(), "the Pawn/WeightsWatcher watch is not registered")
    assertTrue(NS.SetByPath("enabled", false))
    assertEqual(NS.Outfits.loadTimer, nil, "the LoadPass timer is still armed")
    assertFalse(watching(), "the ADDON_LOADED watch survived the stand-down")
    M.__fireTimers()
    assertFalse(NS.db.char.seeded == true, "the LoadPass ran while down")
end)

test("Disabled (Outfitter): the stand-up rebuilds: an outfit added while down binds on resume", function()
    local _, NS, M = scene()
    assertTrue(NS.SetByPath("enabled", false))
    local late = NS.Outfits.Create("Late", {}, { trigger = "IN_DUNGEON" })
    assertFalse(NS.TriggerBinder.IsBound(late), "a binding was made while down")
    assertTrue(NS.SetByPath("enabled", true))
    settle(M)
    -- red under: a TriggerBinder.Resume in modules/Triggers_Binder.lua without its BindAll() (the
    -- stand-up rebinds nothing from the stored outfits).
    assertTrue(NS.TriggerBinder.IsBound(late), "the outfit added while down did not bind on resume")
    assertTrue(NS.Bar.Frame():IsShown(), "the bar did not come back")
    assertTrue(M.OutfitterRebornSheetButton:IsShown(), "the sheet button did not come back")
end)
