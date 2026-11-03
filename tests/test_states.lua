-- tests/test_states.lua — P4.14's state producers (design §6.10, INV §8.1, §8.4): NS.States.Set (the
-- coercion, the no-op, the first-sighting seed, the unknown id), the aura triggers (PEW, the regen
-- and life edges, UNIT_AURA dropped during a load, the unique 2 s scan in combat), icon before spell,
-- the STEALTH merge, the forms and their 0.01 s / 0.1 s polls, the 0.5 s mounted/swimming poll,
-- Dining's own registration edges and its full checks, Spirit on demand, the tooltip hooks, and
-- Suspend/Resume. The secret-value half (PlayerIsFull, the restricted and secret scans, prevMana) is
-- tests/test_secrets_states.lua.
--
-- NS.Equip lands in P4.8, NS.Triggers in P4.15 and NS.Stack in P4.9: every call into them runs
-- against a recorded fake (design §12, the fake rule); their own suites pin the real side. The real
-- NS.PlayerState (P4.4) and NS.Outfits (P4.6) take part.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- A fresh instance with the three fakes, PlayerState and States resumed, the first scans run, and
-- the STATE_CHANGED log emptied. `opts.forState[stateId]` is what Triggers.ForState answers;
-- `opts.worn[outfitId]` what Stack.IsWorn does; `opts.class` the player's class.
local function scene(opts)
    opts = opts or {}
    local inst = T.load({ mutate = function(M)
        if opts.class then M.__world:setClass(opts.class, 1) end
        if opts.mutate then opts.mutate(M) end
    end })
    local NS, M = inst.NS, inst.mocks
    local ctl = { loading = false, worn = opts.worn or {}, forState = opts.forState or {} }
    local equip = T.fake(NS, "Equip", {
        Batch = function(fn, ...) return true, fn(...) end,
        SuspendedForLoad = function() return ctl.loading end,
        Request = true, DelayUntil = true, Suspend = true, Resume = true,
    })
    T.fake(NS, "Triggers", { ForState = function(id) return ctl.forState[id] or {} end })
    -- Suspend and Resume: a case that takes the latch walks every module the lifecycle names.
    T.fake(NS, "Stack", { IsWorn = function(id) return ctl.worn[id] == true end, Suspend = true, Resume = true })
    local heard = {}
    local bus = NS.NewBusTarget()
    bus:RegisterMessage(NS.MSG.STATE_CHANGED, function(_, id, on) heard[#heard + 1] = id .. "=" .. tostring(on) end)
    local scans = { n = 0 }
    bus:RegisterMessage(NS.MSG.AURAS_SCANNED, function() scans.n = scans.n + 1 end)
    NS.PlayerState.Resume()
    NS.States.Resume()
    for _ = 1, 3 do M.__fireTimers() end
    for i = #heard, 1, -1 do heard[i] = nil end
    scans.n = 0
    return { NS = NS, M = M, S = NS.States, W = M.__world, equip = equip, heard = heard, ctl = ctl,
             scans = scans }
end

local function clear(list) for i = #list, 1, -1 do list[i] = nil end end

local function aura(spellId, icon) return { spellId = spellId, icon = icon or 136000, name = "aura" .. spellId } end

-- The registrations of `event` for the player, across every frame and target.
local function regCount(M, event)
    local n = 0
    for _, r in ipairs(M.__registrations()) do if r.event == event then n = n + 1 end end
    return n
end

-- The delays of the live timers (the kit's survey: queued one-shots and armed repeaters), sorted.
local function delays(M)
    local out = {}
    for _, t in ipairs(M.__timers()) do out[#out + 1] = t.delay end
    table.sort(out)
    return out
end

local function has(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

-- ── States.Set ────────────────────────────────────────────────────────────────────────────────

test("states: NS.States publishes the §6.10 surface and the 13 state ids", function()
    local s = scene()
    for _, name in ipairs({ "Set", "IsActive", "Demand", "PlayerIsFull", "AuraRestricted", "PlayerHasSpell",
                            "IsFeigning", "Suspend", "Resume", "InZone", "InPvPInstance", "ZoneInfo",
                            "CurrentIds" }) do
        assertEqual(type(s.S[name]), "function", "NS.States." .. name)
    end
    assertEqual(table.concat(s.S.STATES, ","), "MOUNTED,SWIMMING,DINING,SPIRIT_REGEN,STEALTH,GHOST_WOLF,"
        .. "FEIGN_DEATH,FORM_CASTER,FORM_BEAR,FORM_CAT,FORM_TRAVEL,FORM_MOONKIN,FORM_TREE")
end)

test("states: Set coerces to a boolean, publishes the edge once, and an unchanged value is a no-op", function()
    local s = scene()
    assertTrue(s.S.Set("GHOST_WOLF", 1), "1 is on")
    assertTrue(s.S.IsActive("GHOST_WOLF"))
    -- red under: dropping the coercion (`state[id] = active`; 1 ~= true, so the second Set publishes).
    assertFalse(s.S.Set("GHOST_WOLF", true), "already on")
    assertTrue(s.S.Set("GHOST_WOLF", nil), "nil is off")
    assertFalse(s.S.Set("GHOST_WOLF", false))
    assertEqual(table.concat(s.heard, ","), "GHOST_WOLF=true,GHOST_WOLF=false")
end)

test("states: an unknown id is a debug line, not a raise, and publishes nothing", function()
    local s = scene()
    local lines = {}
    local prev = s.NS.Debug
    s.NS.Debug = function(tag, fmt, ...) lines[#lines + 1] = tag .. ":" .. fmt:format(...) end
    local ok, changed = pcall(s.S.Set, "NOT_A_STATE", true)
    s.NS.Debug = prev
    -- red under: the legacy ErrorMessage path written as error("No events found for " .. id).
    assertTrue(ok, tostring(changed))
    assertFalse(changed)
    assertEqual(#s.heard, 0)
    assertEqual(#lines, 1, "one debug line")
    assertTrue(lines[1]:find("NOT_A_STATE", 1, true) ~= nil, lines[1])
    assertFalse(s.S.IsActive("NOT_A_STATE"))
end)

test("states: a nil state is seeded from the worn outfits whose trigger subscribes to it", function()
    local s = scene({ forState = { GHOST_WOLF = { "SHAMAN_GHOST_WOLF" } } })
    local O = s.NS.Outfits
    local id = O.Create("Wolf", {}, { trigger = "SHAMAN_GHOST_WOLF" })
    s.ctl.worn[id] = true
    -- The scene's first scan already saw every aura state; a stand-down forgets them all.
    s.S.Suspend()
    s.S.Resume()
    -- Worn already (a /reload in wolf form): the first sighting is no edge.
    -- red under: seeding nil as false (the legacy aura path), which would publish GHOST_WOLF=true and
    -- wear the outfit a second time.
    assertFalse(s.S.Set("GHOST_WOLF", true), "seeded on from the stack")
    assertEqual(#s.heard, 0)
    assertTrue(s.S.Set("GHOST_WOLF", false))
    -- Not worn: a first sighting off is no edge either.
    assertFalse(s.S.Set("FEIGN_DEATH", false))
    assertEqual(table.concat(s.heard, ","), "GHOST_WOLF=false")
end)

-- ── the aura triggers ─────────────────────────────────────────────────────────────────────────

test("states: PEW runs the aura scan, then the form poll, and PS.Refresh clears a stale combat flag", function()
    local s = scene({ class = "DRUID" })
    s.M.__lockdown = true
    s.M.__fire("PLAYER_REGEN_DISABLED")
    assertTrue(s.NS.PlayerState.InCombat())
    s.M.__lockdown = false                                     -- REGEN_ENABLED lost in the loading screen
    s.W:setAuras("player", "HELPFUL", { aura(2645) })
    s.W:setForms({ { spellID = 768 } }, 1)
    s.M.__fire("PLAYER_ENTERING_WORLD")
    -- red under: dropping PLAYER_ENTERING_WORLD from the States events (INV §6.1 UpdateAuraStates).
    assertEqual(s.scans.n, 1, "the scan ran on PEW")
    assertTrue(s.S.IsActive("GHOST_WOLF"))
    assertFalse(s.NS.PlayerState.InCombat(), "PlayerState's own PEW refresh")
    assertFalse(s.S.IsActive("FORM_CAT"), "the form poll waits its 0.01 s")
    s.M.__fireTimers()
    assertTrue(s.S.IsActive("FORM_CAT"), "the form poll followed the scan")
end)

test("states: leaving combat and coming back to life re-scan", function()
    local s = scene()
    for _, ev in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
        s.scans.n = 0
        s.M.__fire(ev)
        assertEqual(s.scans.n, 1, ev)
    end
end)

test("states: UNIT_AURA is dropped between PLAYER_LEAVING_WORLD and PEW", function()
    local s = scene()
    s.W:setAuras("player", "HELPFUL", { aura(2645) })
    s.ctl.loading = true
    s.M.__fire("UNIT_AURA", "player")
    -- red under: no Equip.SuspendedForLoad() read in the UNIT_AURA handler.
    assertEqual(s.scans.n, 0, "scanned during a load")
    assertFalse(s.S.IsActive("GHOST_WOLF"))
    s.ctl.loading = false
    s.M.__fire("UNIT_AURA", "player")
    assertEqual(s.scans.n, 1)
    assertTrue(s.S.IsActive("GHOST_WOLF"))
end)

test("states: another unit's UNIT_AURA is not the player's", function()
    local s = scene()
    s.W:setAuras("player", "HELPFUL", { aura(2645) })
    -- red under: dropping the unit check (the harness fires a unit event at every holder).
    s.M.__fire("UNIT_AURA", "target")
    assertEqual(s.scans.n, 0)
end)

test("states: in combat UNIT_AURA waits for one unique 2 s scan; out of combat it scans at once", function()
    local s = scene()
    s.M.__lockdown = true
    s.M.__fire("PLAYER_REGEN_DISABLED")
    s.M.__fireTimers()                                         -- drain the poll's own pass
    s.W:setAuras("player", "HELPFUL", { aura(5384) })
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fire("UNIT_AURA", "player")
    assertEqual(s.scans.n, 0, "no scan in combat")
    local d = delays(s.M)
    local twos = 0
    for _, v in ipairs(d) do if v == 2 then twos = twos + 1 end end
    -- red under: rescheduling on every UNIT_AURA in combat (a busy fight never scans) or one timer each.
    assertEqual(twos, 1, "one 2 s scan: " .. table.concat(d, ","))
    s.M.__fireTimers()
    assertEqual(s.scans.n, 1)
    assertTrue(s.S.IsActive("FEIGN_DEATH"))
    assertTrue(s.S.IsFeigning(), "IsFeigning, for Companion")
    s.M.__lockdown = false
    s.M.__fire("PLAYER_REGEN_ENABLED")
    s.scans.n = 0
    s.W:setAuras("player", "HELPFUL", {})
    s.M.__fire("UNIT_AURA", "player")
    assertEqual(s.scans.n, 1, "immediate out of combat")
    assertFalse(s.S.IsFeigning())
end)

test("states: an aura's icon is matched before its spell", function()
    local s = scene()
    s.W:setUnit("player", { health = 40, healthMax = 100 })      -- hungry, so DINING may go on
    -- A Ghost Wolf spell id under a food icon: the icon decides (Outfitter.lua cAuraIconSpecialID first).
    s.W:setAuras("player", "HELPFUL", { aura(2645, 134062) })
    s.M.__fire("UNIT_AURA", "player")
    -- red under: trying AURA_SPELL_STATE before AURA_ICON_STATE.
    assertTrue(s.S.IsActive("DINING"), "the icon")
    assertFalse(s.S.IsActive("GHOST_WOLF"), "the spell under it")
    assertTrue(s.S.PlayerHasSpell(2645), "the plain spell id is still known to HAS_BUFF")
    assertFalse(s.S.PlayerHasSpell(1))
end)

test("states: the aura scan publishes AURAS_SCANNED inside one Batch and stops at 100 auras", function()
    local s = scene()
    local list = {}
    for i = 1, 100 do list[i] = aura(90000 + i) end
    list[101] = aura(2645)
    s.W:setAuras("player", "HELPFUL", list)
    local batches = s.equip.__count("Batch")
    s.M.__fire("UNIT_AURA", "player")
    assertEqual(s.equip.__count("Batch"), batches + 1, "one bracket around the aura states")
    assertEqual(s.scans.n, 1)
    -- red under: MAX_AURAS = 101, or a scan to the first nil.
    assertFalse(s.S.IsActive("GHOST_WOLF"), "the 101st aura was read")
    assertTrue(s.S.PlayerHasSpell(90100))
    assertFalse(s.S.PlayerHasSpell(2645))
end)

test("states: STEALTH is the aura's or the form's, so neither edge drops the other", function()
    local s = scene({ class = "ROGUE" })
    s.W:setForms({ { spellID = 1784 } }, 1)                    -- rogue Stealth, a form
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fireTimers()
    assertTrue(s.S.IsActive("STEALTH"), "the form")
    clear(s.heard)
    s.W:setAuras("player", "HELPFUL", { aura(58984) })         -- Shadowmeld on as well
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fireTimers()
    s.W:setAuras("player", "HELPFUL", {})                      -- Shadowmeld fades, the form stays
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fireTimers()
    -- legacy: NOT_STEALTH fired here though the form was still up (INV §19); fixed:
    -- red under: `S.Set("STEALTH", want.STEALTH)` in the aura apply (no merge).
    assertTrue(s.S.IsActive("STEALTH"), "the aura's fade left the form's stealth")
    assertEqual(#s.heard, 0, table.concat(s.heard, ","))
    s.W:setForms({ { spellID = 1784 } }, 0)
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fireTimers()
    assertFalse(s.S.IsActive("STEALTH"))
    assertEqual(table.concat(s.heard, ","), "STEALTH=false")
end)

-- ── the forms ─────────────────────────────────────────────────────────────────────────────────

local FORMS = { { spellID = 5487 }, { spellID = 768 }, { spellID = 783 }, { spellID = 24858 }, { spellID = 33891 } }
local FORM_STATE = { "FORM_BEAR", "FORM_CAT", "FORM_TRAVEL", "FORM_MOONKIN", "FORM_TREE" }

test("states: each druid form id sets its own state, and no active form is FORM_CASTER", function()
    local s = scene({ class = "DRUID" })
    s.W:setForms(FORMS, 0)
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fireTimers()
    assertTrue(s.S.IsActive("FORM_CASTER"), "a druid in no form")
    for i, id in ipairs(FORM_STATE) do
        s.W:setForms(FORMS, i)
        s.M.__fire("UNIT_AURA", "player")
        s.M.__fireTimers()
        -- red under: dropping 33891 from FORM_SPELL_STATE (the Tree outfit never fired, O27).
        assertTrue(s.S.IsActive(id), id)
        assertFalse(s.S.IsActive("FORM_CASTER"), id .. " is not caster")
        for j, other in ipairs(FORM_STATE) do
            if j ~= i then assertFalse(s.S.IsActive(other), other .. " under " .. id) end
        end
    end
end)

test("states: Bear Form marks maybe-in-combat on its edge; another class has no caster form", function()
    local s = scene({ class = "DRUID" })
    s.W:setForms(FORMS, 1)
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fireTimers()
    -- red under: dropping the FORM_MAYBE_IN_COMBAT read in the form apply.
    assertTrue(s.NS.PlayerState.MaybeInCombat(), "bear")
    s.NS.PlayerState.SetMaybeInCombat(false)
    s.W:setForms(FORMS, 2)
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fireTimers()
    assertFalse(s.NS.PlayerState.MaybeInCombat(), "cat is no combat form")
    local w = scene({ class = "WARRIOR" })
    w.M.__fire("UNIT_AURA", "player")
    w.M.__fireTimers()
    -- red under: the caster substitution without the DRUID check.
    assertFalse(w.S.IsActive("FORM_CASTER"), "a warrior is no caster druid")
end)

test("states: a form index once seen keeps its state when its spell id goes unreadable", function()
    local s = scene({ class = "DRUID" })
    s.W:setForms({ { spellID = 5487 } }, 1)
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fireTimers()
    assertTrue(s.S.IsActive("FORM_BEAR"))
    s.W:setForms({ { spellID = T.secret(5487) } }, 0)          -- the runtime index cache answers
    s.M.__fire("UNIT_AURA", "player")
    s.M.__fireTimers()
    -- red under: no index cache (the inactive bear form would never be switched off).
    assertFalse(s.S.IsActive("FORM_BEAR"))
    assertTrue(s.S.IsActive("FORM_CASTER"))
end)

test("states: the form poll runs 0.01 s after a scan and re-polls every 0.1 s while loading", function()
    local s = scene({ class = "DRUID" })
    s.M.__fireTimers()                                         -- drain
    s.W:setForms(FORMS, 2)
    s.M.__fire("UNIT_AURA", "player")
    assertTrue(has(delays(s.M), 0.01), "the 0.01 s form poll: " .. table.concat(delays(s.M), ","))
    s.ctl.loading = true
    s.M.__fireTimers()
    -- red under: polling the forms during a load (they vanish briefly on a loading screen).
    assertFalse(s.S.IsActive("FORM_CAT"), "polled while suspended for a load")
    assertTrue(has(delays(s.M), 0.1), "the 0.1 s re-poll: " .. table.concat(delays(s.M), ","))
    s.M.__fireTimers()
    assertTrue(has(delays(s.M), 0.1), "still re-polling")
    s.ctl.loading = false
    s.M.__fireTimers()
    assertTrue(s.S.IsActive("FORM_CAT"))
end)

-- ── the poll ──────────────────────────────────────────────────────────────────────────────────

test("states: the 0.5 s poll sets MOUNTED (not on a taxi) and SWIMMING inside one Batch", function()
    local s = scene()
    assertTrue(has(delays(s.M), 0.5), "the repeating 0.5 s poll")
    s.W:setFlag("IsMounted", true)
    local b = s.equip.__count("Batch")
    s.M.__fireTimers()
    assertTrue(s.S.IsActive("MOUNTED"))
    assertTrue(s.equip.__count("Batch") > b)
    s.W:setFlag("UnitOnTaxi", true)
    s.M.__fireTimers()
    -- red under: `MOUNTED = IsMounted()` alone (a flight path wore the riding outfit).
    assertFalse(s.S.IsActive("MOUNTED"), "on a taxi")
    s.W:setFlag("IsSwimming", true)
    s.M.__fireTimers()
    assertTrue(s.S.IsActive("SWIMMING"))
    s.W:setFlag("IsSwimming", false)
    s.M.__fireTimers()
    assertFalse(s.S.IsActive("SWIMMING"))
end)

-- ── Dining ────────────────────────────────────────────────────────────────────────────────────

local function hungry(s) s.W:setUnit("player", { health = 40, healthMax = 100, powerType = 0, power = 40, powerMax = 100 }) end
local function full(s) s.W:setUnit("player", { health = 100, healthMax = 100, power = 100, powerMax = 100 }) end

test("states: Dining registers its unit events on its own on edge and drops them only on its off edge", function()
    local s = scene()
    hungry(s)
    assertEqual(regCount(s.M, "UNIT_HEALTH"), 0, "nothing while not dining")
    s.W:setAuras("player", "HELPFUL", { aura(433, 134062) })
    s.M.__fire("UNIT_AURA", "player")
    assertTrue(s.S.IsActive("DINING"))
    assertEqual(regCount(s.M, "UNIT_HEALTH"), 1, "UNIT_HEALTH on the on edge")
    assertTrue(regCount(s.M, "UNIT_POWER_UPDATE") >= 1, "UNIT_POWER_UPDATE on the on edge")
    s.S.Set("GHOST_WOLF", true)
    s.S.Set("GHOST_WOLF", false)
    -- legacy: any other state change unregistered UNIT_HEALTH (Outfitter.lua:4895-4899); fixed:
    -- red under: unregistering the Dining watch in Set for every id but DINING.
    assertEqual(regCount(s.M, "UNIT_HEALTH"), 1, "another state's edge kept the watch")
    s.S.Set("DINING", false)
    assertEqual(regCount(s.M, "UNIT_HEALTH"), 0, "the off edge dropped it")
    assertEqual(regCount(s.M, "UNIT_POWER_UPDATE"), 0)
end)

for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_POWER_UPDATE" }) do
    test("states: a full reading on " .. ev .. " while dining turns DINING off", function()
        local s = scene()
        hungry(s)
        s.W:setAuras("player", "HELPFUL", { aura(433, 132805) })
        s.M.__fire("UNIT_AURA", "player")
        assertTrue(s.S.IsActive("DINING"))
        s.M.__fire(ev, "player", "MANA")
        assertTrue(s.S.IsActive("DINING"), "still hungry")
        full(s)
        s.M.__fire(ev, "target", "MANA")
        assertTrue(s.S.IsActive("DINING"), "another unit's reading")
        s.M.__fire(ev, "player", "MANA")
        -- red under: dropping " .. ev .. " from the Dining watch's events.
        assertFalse(s.S.IsActive("DINING"), "full: the outfit comes off mid-meal no more")
        assertEqual(table.concat(s.heard, ","), "DINING=true,DINING=false")
    end)
end

test("states: the aura scan leaves DINING off when the player is already full", function()
    local s = scene()
    full(s)
    s.W:setAuras("player", "HELPFUL", { aura(433, 134062) })
    s.M.__fire("UNIT_AURA", "player")
    -- red under: `DINING = want.DINING` (no PlayerIsFull in the aura apply, INV §8.4).
    assertFalse(s.S.IsActive("DINING"))
    assertEqual(#s.heard, 0)
end)

-- ── Spirit ────────────────────────────────────────────────────────────────────────────────────

local function spiritScene()
    local s = scene()
    s.now = 1000
    s.M.GetTime = function() return s.now end
    s.W:setUnit("player", { power = 500, powerMax = 1000, powerType = 0 })
    return s
end

test("states: Spirit registers its two events only while something demands STATE:SPIRIT_REGEN", function()
    local s = spiritScene()
    -- red under: registering UNIT_SPELLCAST_SENT at Resume (every player pays for the watch).
    assertEqual(regCount(s.M, "UNIT_SPELLCAST_SENT"), 1, "PlayerState's own SENT only")
    assertEqual(s.S.Demand("STATE:SPIRIT_REGEN", 1), 1)
    assertEqual(regCount(s.M, "UNIT_SPELLCAST_SENT"), 2)
    assertEqual(regCount(s.M, "UNIT_POWER_UPDATE"), 1)
    assertEqual(s.S.Demand("STATE:SPIRIT_REGEN", 1), 2)
    assertEqual(regCount(s.M, "UNIT_SPELLCAST_SENT"), 2, "a second demand is no second watch")
    s.S.Demand("STATE:SPIRIT_REGEN", -1)
    assertEqual(regCount(s.M, "UNIT_POWER_UPDATE"), 1)
    s.S.Demand("STATE:SPIRIT_REGEN", -1)
    assertEqual(regCount(s.M, "UNIT_SPELLCAST_SENT"), 1)
    assertEqual(regCount(s.M, "UNIT_POWER_UPDATE"), 0)
    assertEqual(s.S.Demand("STATE:SPIRIT_REGEN", -1), 0, "never below zero")
    assertEqual(s.S.Demand("STATE:SPIRIT_REGEN"), 0, "a read")
end)

test("states: a mana drop within 10 s of a cast turns Spirit off, and it comes back 5 s later", function()
    local s = spiritScene()
    s.S.Demand("STATE:SPIRIT_REGEN", 1)
    s.S.Set("SPIRIT_REGEN", true)
    clear(s.heard)
    s.M.__fire("UNIT_POWER_UPDATE", "player", "MANA")          -- the first sample
    assertTrue(s.S.IsActive("SPIRIT_REGEN"), "no cast yet")
    s.M.__fire("UNIT_SPELLCAST_SENT", "player", "", "cast-1", 133)
    s.now = 1004
    s.W:setUnit("player", { power = 450 })
    s.M.__fire("UNIT_POWER_UPDATE", "player", "MANA")
    assertFalse(s.S.IsActive("SPIRIT_REGEN"), "the five-second rule began")
    assertTrue(has(delays(s.M), 5), "the 5 s re-enable: " .. table.concat(delays(s.M), ","))
    s.M.__fireTimers()
    assertTrue(s.S.IsActive("SPIRIT_REGEN"), "re-enabled")
    assertEqual(table.concat(s.heard, ","), "SPIRIT_REGEN=false,SPIRIT_REGEN=true")
end)

test("states: a drop more than 10 s after the cast, or a mana gain, leaves Spirit alone", function()
    local s = spiritScene()
    s.S.Demand("STATE:SPIRIT_REGEN", 1)
    s.S.Set("SPIRIT_REGEN", true)
    s.M.__fire("UNIT_POWER_UPDATE", "player", "MANA")
    s.M.__fire("UNIT_SPELLCAST_SENT", "player", "", "cast-1", 133)
    s.now = 1003
    s.W:setUnit("player", { power = 600 })
    s.M.__fire("UNIT_POWER_UPDATE", "player", "MANA")
    assertTrue(s.S.IsActive("SPIRIT_REGEN"), "a gain is no drop")
    s.now = 1011
    s.W:setUnit("player", { power = 550 })
    s.M.__fire("UNIT_POWER_UPDATE", "player", "MANA")
    -- red under: SPIRIT_WINDOW = 15 (the legacy rule is ten seconds from UNIT_SPELLCAST_SENT).
    assertTrue(s.S.IsActive("SPIRIT_REGEN"), "eleven seconds after the cast")
    s.W:setUnit("player", { power = 500 })
    s.M.__fire("UNIT_POWER_UPDATE", "player", "RAGE")
    assertTrue(s.S.IsActive("SPIRIT_REGEN"), "another power's update")
end)

-- ── the tooltip ───────────────────────────────────────────────────────────────────────────────

test("states: the GameTooltip hooks are installed once and speak only on demand and standing up", function()
    local s = scene()
    local shown, hidden = 0, 0
    local bus = s.NS.NewBusTarget()
    bus:RegisterMessage(s.NS.MSG.TOOLTIP_SHOWN, function() shown = shown + 1 end)
    bus:RegisterMessage(s.NS.MSG.TOOLTIP_HIDDEN, function() hidden = hidden + 1 end)
    local tip = s.M.GameTooltip
    tip:__fire("OnShow")
    -- red under: no Demand("TOOLTIP") gate in the hook bodies.
    assertEqual(shown, 0, "nothing demands the tooltip")
    s.S.Demand("TOOLTIP", 1)
    tip:__fire("OnShow")
    tip:__fire("OnHide")
    assertEqual(shown, 1)
    assertEqual(hidden, 1)
    s.S.Suspend()
    s.S.Resume()
    tip:__fire("OnShow")
    -- red under: hooking again on every Resume (each show would send twice).
    assertEqual(shown, 2, "one hook, however many resumes")
    s.NS.ApplyEnabled(false)
    tip:__fire("OnShow")
    assertEqual(shown, 2, "a stood-down body is silent")
    s.NS.ApplyEnabled(true)
end)

-- ── Suspend / Resume ──────────────────────────────────────────────────────────────────────────

test("states: Suspend drops every registration and timer and clears the states; Resume rebuilds", function()
    local s = scene()
    s.S.Demand("STATE:SPIRIT_REGEN", 1)
    hungry(s)
    s.W:setAuras("player", "HELPFUL", { aura(433, 134062) })
    s.M.__fire("UNIT_AURA", "player")
    assertTrue(s.S.IsActive("DINING"))
    local auraRegs = regCount(s.M, "UNIT_AURA")
    assertTrue(auraRegs >= 1)
    s.S.Suspend()
    -- red under: Suspend leaving the Dining or the Spirit frame registered.
    for _, ev in ipairs({ "UNIT_AURA", "UNIT_HEALTH", "UNIT_POWER_UPDATE", "ZONE_CHANGED" }) do
        assertEqual(regCount(s.M, ev), 0, ev .. " survived the stand-down")
    end
    for _, ev in ipairs({ "PLAYER_ALIVE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
        assertEqual(regCount(s.M, ev), 1, ev .. ": only PlayerState's is left")
    end
    assertEqual(regCount(s.M, "UNIT_SPELLCAST_SENT"), 1, "only PlayerState's")
    assertEqual(#delays(s.M), 0, "a timer survived: " .. table.concat(delays(s.M), ","))
    assertFalse(s.S.IsActive("DINING"), "the state table cleared")
    s.S.Resume()
    assertEqual(regCount(s.M, "UNIT_AURA"), auraRegs)
    assertEqual(regCount(s.M, "UNIT_SPELLCAST_SENT"), 2, "the standing demand re-armed the Spirit watch")
    for _ = 1, 2 do s.M.__fireTimers() end
    assertTrue(s.S.IsActive("DINING"), "the re-run scan found the meal")
    assertEqual(regCount(s.M, "UNIT_HEALTH"), 1)
end)

test("states: a handler reached while stood down writes nothing", function()
    local s = scene()
    s.W:setAuras("player", "HELPFUL", { aura(2645) })
    -- Every handler the module registered, captured while up, then called with the latch down: the
    -- registrations are gone by then, so this is the body's own gate (the conformance suite's step 6).
    local handlers = {}
    for _, r in ipairs(s.M.__registrations()) do
        if (r.event == "UNIT_AURA" or r.event == "PLAYER_ENTERING_WORLD") and r.target then
            handlers[#handlers + 1] = r
        end
    end
    assertTrue(#handlers >= 2, "the fixture needs the aura and PEW registrations")
    s.NS.ApplyEnabled(false)
    assertFalse(s.S.IsActive("GHOST_WOLF"))
    local asked = s.equip.__count("SuspendedForLoad")
    for _, r in ipairs(handlers) do s.M.__fireUnconditional(r.target, r.event, r.unit or "player") end
    s.M.__fireTimers()
    -- red under: dropping the NS.IsStoodDown() read from onAura in modules/States.lua (the stood-down
    -- body went on to ask Equip whether a load is in progress).
    assertEqual(s.equip.__count("SuspendedForLoad"), asked, "the UNIT_AURA body ran past the latch")
    -- red under: dropping the `not active or NS.IsStoodDown()` read from scanAuras as well.
    assertFalse(s.S.IsActive("GHOST_WOLF"))
    assertEqual(#s.heard, 0)
    s.NS.ApplyEnabled(true)
end)
