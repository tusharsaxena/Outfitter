-- tests/perf_scenes.lua — the drivers of the ten bracketed paths (design §2.1, performance-§3), shared
-- by the offline scenario runner (tests/perf.lua) and the harness suite (tests/test_perf_harness.lua),
-- so the runner measures exactly the path the suite proves is reached (P4.31).
--
-- Loaded as `dofile(root .. "/tests/perf_scenes.lua")(env)`, env = { root, load }: `load(opts)` takes
-- T.load's options (`mutate`) and answers { NS, mocks }. Each scene answers `step, NS, M`: the
-- instance is built and settled once, and `step()` drives ONE iteration of the path, leaving the
-- instance in a state the next call can repeat. Every module is the real one (no fakes, design §12:
-- P4.27 has landed), and every item moves for real in tests/mock_gear.lua.
--
-- THE SIX PERF SCENARIOS (perf.lua's header):
--   equipPlan      full-bag plan: a full-bag Warrior's weapon outfit worn and taken off at once
--                  (St.Wear/Remove with `now`), so each step is one E.Update with one change
--                  (equipUpdate, equipExecute), then the moved items' events and Inv.Sync (bagSync)
--   zoneFlips      50 BG zone flips: Warsong Gulch and the open world in turn, each one read by the
--                  zone producer (zoneUpdate) with a battleground outfit bound to the zone state
--   triggerFanout  40 outfits on the RESTING trigger, one PLAYER_UPDATE_RESTING edge through each
--                  binding (triggerDispatch x 40)
--   tooltips       the "Used by outfits" line on 100 bag items, 5 passes over a full bag set
--                  (tooltipUsedBy x 100)
--   gaGeneration   one genetic generation: the optimizer's ticker resumed until 275 children (one
--                  generation's worth) were bred, the search started afresh on the same seed every
--                  GA_RESTART steps (optimizeStep). The restart is on a fixed step count, never on
--                  the search ending (it cannot converge in fewer than 100 generations), so every
--                  window of a multiple of GA_RESTART steps bills the same seeding. Its fourth
--                  return answers the search in progress.
--   dockIdle       the docked window shown on full_bags with nothing changing: one States poll tick
--                  (the 0.5 s repeater's own function, the clock moved on by its period) and one
--                  follow tick of the driver (dockFollow). Idle must stay quiet: no STACK_CHANGED,
--                  so no list rebuild (F-001, F-006).
-- THE OTHER THREE BUCKETS (the suite only): auraScan (the player's UNIT_AURA), dockFollow (one
-- throttled follow tick of the docked window), barRender (Bar.Render of the live source).

return function(env)
    local installPaint = dofile(env.root .. "/tests/_kit/mock_paint.lua")
    local ITEMS = dofile(env.root .. "/tests/fixtures/items.lua").db

    local Scenes = {}

    -- Fire every armed timer, a few rounds: the States poll repeats, so the queue never empties.
    local function settle(M)
        for _ = 1, 4 do
            if M.__fireTimers() == 0 then break end
        end
    end
    Scenes.settle = settle

    --- The recorder's housekeeping after a step, in place so it allocates nothing: the canceled
    --- entries leave the timer queue (AceTimer frees a canceled timer; the mock keeps its entry until
    --- the queue is fired), and the equip-call and CVar-write logs are emptied. Without it a step's
    --- figure would carry the queue's growth, and the halves of a pair would differ by where its
    --- rehashes fall. Live timers stay queued, as they stay armed in the client.
    local function quiet(M)
        local q, j = M.__timers, 0
        for i = 1, #q do
            local e = q[i]
            q[i] = nil
            if not (e.cancelled or (e.timer and e.timer.cancelled)) then
                j = j + 1
                q[j] = e
            end
        end
        for _, log in ipairs({ M.__equipCalls, M.__cvarWrites }) do
            for i = #log, 1, -1 do log[i] = nil end
        end
    end
    Scenes.quiet = quiet

    --- The whole addon up on `scenario` (fixtures/inventories.lua, `overrides` merged over it), at
    --- t = 100, past its first zone-in. `strip` (the offline runner's only) names source lines taken
    --- out of one addon file before it loads: an instrumentation-absent instance (Scenes.ABSENT).
    --- @return table NS, table M
    function Scenes.world(scenario, overrides, strip)
        local inst = env.load({ strip = strip, mutate = function(M)
            installPaint(M)
            M.__gear:load(scenario, overrides)
        end })
        local NS, M = inst.NS, inst.mocks
        M.__now = 100
        M.__fire("PLAYER_ENTERING_WORLD")
        settle(M)
        return NS, M
    end

    local function snap(NS, key) return NS.ItemInfo.Snapshot(NS.ItemInfo.FromLink(ITEMS[key].link)) end

    -- The carried instance of a fixture key, as an outfit holds it (its bag link, not the fixture's).
    local function carried(NS, M, key)
        local _, at = M.__gear:find(key)
        assert(at and at.bag, "the scenario carries no " .. key)
        return NS.ItemInfo.Snapshot(NS.ItemInfo.FromBag(at.bag, at.slot))
    end

    -- Every worn slot, as an outfit's items.
    local function wornItems(NS)
        local items = {}
        for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
            local info = NS.ItemInfo.FromSlot(slot)
            if info then items[slot] = NS.ItemInfo.Snapshot(info) end
        end
        return items
    end

    -- ── the six perf scenarios ──────────────────────────────────────────────────────────────────

    -- full_bags with a second one-hander in the bags: the swap the plan makes is in place, so it
    -- succeeds with every bag slot taken (an unbound BoE is no outfit item, Inventory admitBagItem).
    local HERBS = {}
    for i = 1, 16 do HERBS[i] = "herb_silverleaf" end
    local FULL_BAGS = {
        [0] = { items = HERBS },
        [1] = { bag = "bag_small4", items = { "sword_1h_b", "hearthstone", "boe_legs", "staff" } },
    }

    function Scenes.equipPlan()
        local NS, M = Scenes.world("full_bags", { bags = FULL_BAGS })
        local O, St = NS.Outfits, NS.Stack
        local base = O.Create("Base", wornItems(NS))
        local swap = O.Create("Spies", { MainHandSlot = carried(NS, M, "sword_1h_b") })
        St.Wear(base, { now = true })
        M.__gear:deliver()
        NS.Inventory.Sync()
        local on = false
        return function()
            M.__now = M.__now + 2                    -- past the 1.5 s throttle
            on = not on
            if on then St.Wear(swap, { now = true }) else St.Remove(swap, { now = true }) end
            M.__gear:deliver()
            NS.Inventory.Sync()
            quiet(M)
        end, NS, M
    end

    Scenes.FLIPS = 50
    function Scenes.zoneFlips()
        local NS, M = Scenes.world("geared")
        NS.Outfits.Create("Warsong", { HeadSlot = snap(NS, "head_plate") }, { trigger = "PVP_BATTLEGROUND" })
        local WSG = { name = "Warsong Gulch", type = "pvp", instanceID = 2106, mapID = 2106, zone = "Warsong Gulch" }
        local inBG = false
        return function()
            for _ = 1, Scenes.FLIPS do
                inBG = not inBG
                M.__world:setInstance(inBG and WSG or nil)
                if not inBG then M.__context.zone = "Elwynn Forest" end
                NS.States.UpdateZone()
            end
            quiet(M)
        end, NS, M
    end

    Scenes.FANOUT = 40
    function Scenes.triggerFanout()
        local NS, M = Scenes.world("geared")
        local ids = {}
        for i = 1, Scenes.FANOUT do ids[i] = NS.Outfits.Create("Rest " .. i, {}, { trigger = "RESTING" }) end
        NS.TriggerBinder.BindAll()
        settle(M)
        local resting = false
        return function()
            resting = not resting
            M.__world:setFlag("IsResting", resting)
            M.__fire("PLAYER_UPDATE_RESTING")
            quiet(M)
        end, NS, M, ids
    end

    Scenes.TOOLTIPS = 100
    function Scenes.tooltips(strip)
        local NS, M = Scenes.world("full_bags", nil, strip)
        NS.Outfits.Create("Herbalist", { MainHandSlot = snap(NS, "greatsword"), LegsSlot = snap(NS, "boe_legs") })
        NS.Outfits.Create("Caster", { MainHandSlot = snap(NS, "staff") })
        local slots = {}
        for _, bag in ipairs({ 0, 1 }) do
            for slot = 1, M.C_Container.GetContainerNumSlots(bag) do
                if M.__gear:bagItem(bag, slot) then slots[#slots + 1] = { bag, slot } end
            end
        end
        local tip, kind = M.GameTooltip, M.Enum.TooltipDataType.Item
        return function()
            for i = 1, Scenes.TOOLTIPS do
                local at = slots[(i - 1) % #slots + 1]
                tip:SetBagItem(at[1], at[2])
                M.__world:tooltipPostCall(kind, tip, nil)
            end
        end, NS, M, slots
    end

    -- The Park-Miller minimal standard generator, shaped like math.random (tests/test_optimize.lua).
    local function lcg(seed)
        local s = seed
        return function(m)
            s = (s * 16807) % 2147483647
            local f = (s - 1) / 2147483646
            if m == nil then return f end
            return math.floor(f * m) + 1
        end
    end

    Scenes.GA_RESTART = 20
    function Scenes.gaGeneration()
        local NS, M = Scenes.world("full_bags")
        local P = NS.OptimizeGA.PARAMS
        local children = P.population - P.parents
        local job, last, steps = nil, nil, 0
        local function start()
            job = assert(NS.Optimize.Generate("Best", { { stat = "STA" }, { stat = "ITEM_LEVEL" } },
                { rng = lcg(7) }, function() end), "the genetic search did not start")
            assert(job.ga and job.ga.ticker, "the cfg did not take the genetic search")
            last = P.population                      -- the seed population is not bred
        end
        return function()
            if steps % Scenes.GA_RESTART == 0 then start() end
            steps = steps + 1
            local want = children
            while want > 0 do
                assert(not job.done, "the search ended inside a restart window")
                job.ga.ticker.func()                 -- one resume: what the client's ticker runs
                want = want - (job.generated - last)
                last = job.generated
            end
        end, NS, M, function() return job end
    end

    -- The docked window, shown, on a world that does not change. The States poll is the one armed
    -- 0.5 s repeater (POLL_PERIOD, modules/States.lua); its function is called directly, so a step
    -- is exactly one poll tick and the timer queue is not rebuilt.
    Scenes.POLL_PERIOD = 0.5
    function Scenes.dockIdle()
        local NS, M = Scenes.world("full_bags")
        NS.Outfits.Create("Idle", wornItems(NS))
        M.__world:openCharacter()
        NS.Dock.Open()
        M.OutfitterRebornWindow:__fire("OnShow")     -- the Dock's OnShow hook arms the follow
        local driver = M.OutfitterRebornDockDriver
        -- The clock moves past the 1.5 s throttle before the settle, so the update the setup asked for
        -- runs: on a frozen clock it stays throttled and every poll's flush re-arms its timer, a cost
        -- the client (whose timer fires on time) never pays at idle.
        M.__now = M.__now + 2
        settle(M)
        assert(not NS.Equip.Pending(), "the idle scene has an equipment update pending")
        driver:__fire("OnUpdate", NS.Dock.FOLLOW_INTERVAL)   -- the first render, done before measuring
        local poll
        for _, h in ipairs(M.__timers()) do
            if type(h) == "table" and h.looping and h.delay == Scenes.POLL_PERIOD then poll = h end
        end
        assert(poll, "the States poll is not armed")
        local tick = poll.func                       -- AceTimer calls it with the schedule's args: none
        return function()
            M.__now = M.__now + Scenes.POLL_PERIOD
            tick()
            driver:__fire("OnUpdate", NS.Dock.FOLLOW_INTERVAL)
            quiet(M)
        end, NS, M
    end

    Scenes.PERF = { "equipPlan", "zoneFlips", "triggerFanout", "tooltips", "gaGeneration", "dockIdle" }

    -- ── the instrumentation-absent arm (performance-§9) ─────────────────────────────────────────
    -- The zero-overhead claim is that capture OFF costs nothing over no instrumentation at all, which
    -- the off/on pair cannot show: a dormant bracket that allocates pays the same bytes in both its
    -- halves. Scenes.ABSENT.tooltips is the tooltips step on an instance whose modules/Tooltips.lua is
    -- the TOC's own file with Tooltips.OnItem's two bracket lines blanked (whole lines, so anything
    -- built beside the dormant t0 goes with them; line numbers kept), so the same gates and the same
    -- Tooltips.Decorate call run. Each pattern must match exactly one line, or the runner refuses
    -- the arm: a stale pattern would measure the bracketed file under the absent arm's name.
    Scenes.ABSENT = {
        tooltips = {
            file = "modules/Tooltips.lua",
            patterns = { "^%s*local t0 = Perf%.on and debugprofilestop%(%)",
                         "^%s*if t0 then Perf%.Note%(\"tooltipUsedBy\"" },
        },
    }
    function Scenes.tooltipsAbsent() return Scenes.tooltips(Scenes.ABSENT.tooltips) end

    -- ── the other three buckets ─────────────────────────────────────────────────────────────────

    function Scenes.auraScan()
        local NS, M = Scenes.world("geared")
        return function() M.__fire("UNIT_AURA", "player") end, NS, M
    end

    function Scenes.dockFollow()
        local NS, M = Scenes.world("geared")
        M.__world:openCharacter()
        NS.Dock.Open()
        M.OutfitterRebornWindow:__fire("OnShow")     -- the Dock's OnShow hook arms the follow
        local driver = M.OutfitterRebornDockDriver
        return function() driver:__fire("OnUpdate", NS.Dock.FOLLOW_INTERVAL) end, NS, M
    end

    function Scenes.barRender()
        local NS, M = Scenes.world("geared")
        NS.Outfits.Create("Shown", { HeadSlot = snap(NS, "head_plate") })
        assert(NS.SetByPath("bar.shown", true), "the bar did not take bar.shown")
        settle(M)
        return function() NS.Bar.Render(NS.Bar.LiveSource) end, NS, M
    end

    Scenes.OTHERS = { "auraScan", "dockFollow", "barRender" }

    -- ── the capture-off/capture-on pair verdict ─────────────────────────────────────────────────
    -- The zero-overhead evidence performance-§2 asks for: off allocates nothing over on (PAIR_NOISE
    -- for the float), and on no more than PAIR_SLACK bytes/iter over off. PAIR_WINDOW_BYTES is a
    -- one-off growth an OFF window may carry in total, not per iteration: zoneFlips' off window
    -- carried 4128 bytes its on window did not (82.6 bytes/iter over 50, 68.8 over 60: the same
    -- total), gaGeneration's once 480, and where it lands moved with the load path's length and with
    -- an extra window run first. It is granted off over on only (the on side never needed it), and
    -- only while, spread over the window's bracket calls, it stays under SMALLEST_ALLOC bytes a call:
    -- a scenario with too few calls is refused rather than let a per-call allocation hide in it.
    Scenes.PAIR_SLACK = 64
    Scenes.PAIR_NOISE = 1
    Scenes.PAIR_WINDOW_BYTES = 8192
    Scenes.SMALLEST_ALLOC = 16

    --- The failures of one pair: `off`/`on` are { iterations, bytesPerIter, notesPerIter } records of
    --- scenario `base`. Answers a list of messages, empty when the pair agrees.
    function Scenes.pairFailures(base, off, on)
        local out = {}
        local offName, onName = base .. "CaptureOff", base .. "CaptureOn"
        local window = Scenes.PAIR_WINDOW_BYTES
        local calls = off.iterations * on.notesPerIter
        if calls <= 0 or window / calls >= Scenes.SMALLEST_ALLOC then
            out[#out + 1] = ("%s: the %d-byte window allowance over %d bracket calls would hide a per-call allocation; raise its iterations")
                :format(base, window, calls)
        end
        if off.bytesPerIter > on.bytesPerIter + Scenes.PAIR_NOISE + window / off.iterations then
            out[#out + 1] = ("%s allocated %.1f bytes/iter, more than %s's %.1f: the off bracket is not free")
                :format(offName, off.bytesPerIter, onName, on.bytesPerIter)
        end
        if on.bytesPerIter > off.bytesPerIter + Scenes.PAIR_SLACK then
            out[#out + 1] = ("%s allocated %.1f bytes/iter, over %s's %.1f by more than %d")
                :format(onName, on.bytesPerIter, offName, off.bytesPerIter, Scenes.PAIR_SLACK)
        end
        return out
    end

    return Scenes
end
