-- tests/test_companion.lua — P4.13 (design §5.15, INV §3.10): NS.Companion, the battle-pet
-- reconciler. Summon and dismiss by name, GUID and species; the blockers (flying, combat, dead,
-- feign, casting, channeling, 3 s after the SummonPetByGUID hook); the auto-summon watch; the retry
-- cap (30 tries, a 60 s dismiss deadline); a nil or secret name answers false and never raises;
-- Suspend cancels the ticker and drops the wish.
--
-- NS.States lands in P4.14 (a parallel task): IsFeigning runs against a recorded fake (design §12,
-- the fake rule). NS.Equip lands in P4.8: PlayerState's calls into it are faked the same way.
-- PlayerState itself is real (P4.4) and driven through the client's events.
--
-- Compat.IsFlying is not in core/Compat.lua yet (its client global is a .luacheckrc spine edit,
-- handed back). Until it lands, `scene` installs a stand-in that reads the mock's IsFlying flag;
-- the stand-in steps aside on its own once the real accessor exists.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local SQUIRREL = "BattlePet-0-000000000001"   -- species 39, "Mechanical Squirrel"
local CAT      = "BattlePet-0-000000000002"   -- species 40, "Bombay Cat", renamed "Whiskers"
local RAGNAROS = "BattlePet-0-000000000003"   -- species 1426, "Lil' Ragnaros"

-- A fresh instance: Equip and States faked, PlayerState and Companion resumed, the clock at 100 s
-- (clear of the 3 s summon window), the journal's calls and the debug lines recorded.
local function scene()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    -- Suspend and Resume: the stand-down walk reaches every NS.LIFECYCLE_MODULES entry.
    T.fake(NS, "Equip", { Batch = function(fn) fn() end, DelayUntil = true, Request = true,
                          Suspend = true, Resume = true })
    local feign = { on = false }
    T.fake(NS, "States", { IsFeigning = function() return feign.on end, Suspend = true, Resume = true })
    if rawget(NS.Compat, "IsFlying") == nil then
        NS.Compat.IsFlying = function() return M.IsFlying() == true end
    end
    local debug = {}
    NS.Debug = function(tag, fmt, ...) debug[#debug + 1] = tag .. ": " .. fmt:format(...) end
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Companion.Resume()
    M.__world.petCalls = {}
    return inst, NS, M, feign, debug
end

local function calls(M) return M.__world.petCalls end

-- Run the queued timers `n` times (default once), the clock moving `step` seconds before each.
local function tick(M, n, step)
    for _ = 1, n or 1 do
        M.__now = M.__now + (step or 1)
        M.__fireTimers()
    end
end

local function pending(M)
    local n = 0
    for _, t in ipairs(M.__timers) do
        if not (t.cancelled or (t.timer and t.timer.cancelled)) then n = n + 1 end
    end
    return n
end

local function found(lines, needle)
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then return true end end
    return false
end

-- ── the surface ───────────────────────────────────────────────────────────────────────────────

test("companion: NS.Companion is published with the design's surface", function()
    local C = T.NS.Companion
    assertEqual(type(C), "table")
    for _, name in ipairs({ "SummonByName", "SummonByGUID", "SummonBySpecies", "DismissByName", "DismissByGUID",
                            "Summoned", "CanAct", "Suspend", "Resume" }) do
        assertEqual(type(C[name]), "function", name)
    end
end)

-- ── summon ────────────────────────────────────────────────────────────────────────────────────

test("companion: SummonByName matches the species name case-insensitively and summons now", function()
    local _, NS, M = scene()
    assertTrue(NS.Companion.SummonByName("mechanical SQUIRREL"))
    assertEqual(#calls(M), 1)
    assertEqual(calls(M)[1], SQUIRREL)
    assertEqual(NS.Companion.Summoned(), SQUIRREL)
    -- red under: matching the custom name (the renamed cat answers to its species only).
    assertFalse(NS.Companion.SummonByName("Whiskers"), "a custom name is not a species")
    M.__now = M.__now + 5   -- past the 3 s window the squirrel's own summon opened
    assertTrue(NS.Companion.SummonByName("bombay cat"))
    assertEqual(calls(M)[#calls(M)], CAT)
end)

test("companion: a nil, secret or unknown name answers false and never raises", function()
    local _, NS, M = scene()
    -- red under: the legacy `nameToFind:lower()` on a nil name (INV §3.10 Fix).
    local ok, res = pcall(NS.Companion.SummonByName, nil)
    assertTrue(ok, "a nil name raised: " .. tostring(res))
    assertFalse(res)
    assertFalse(NS.Companion.SummonByName(T.secret("Mechanical Squirrel")), "a secret name is refused")
    assertFalse(NS.Companion.SummonByName("No Such Pet"))
    ok, res = pcall(NS.Companion.DismissByName, nil)
    assertTrue(ok, "a nil dismiss name raised: " .. tostring(res))
    assertFalse(res)
    assertFalse(NS.Companion.SummonByGUID(nil))
    assertFalse(NS.Companion.SummonByGUID(T.secret(SQUIRREL)), "a secret GUID is refused")
    assertFalse(NS.Companion.DismissByGUID(nil))
    assertEqual(#calls(M), 0, "nothing reached the journal")
    assertEqual(pending(M), 0, "nothing was scheduled")
end)

test("companion: SummonBySpecies summons the first owned pet of the species", function()
    local _, NS, M = scene()
    assertTrue(NS.Companion.SummonBySpecies(1426))
    assertEqual(calls(M)[1], RAGNAROS)
    assertFalse(NS.Companion.SummonBySpecies(99999))
    assertFalse(NS.Companion.SummonBySpecies(nil))
end)

test("companion: summoning the pet already out calls nothing (the call would dismiss it)", function()
    local _, NS, M = scene()
    M.__world.summonedPet = SQUIRREL
    -- red under: summoning without comparing to Summoned() (SummonPetByGUID toggles it away).
    assertTrue(NS.Companion.SummonByGUID(SQUIRREL))
    assertEqual(#calls(M), 0)
    assertEqual(NS.Companion.Summoned(), SQUIRREL)
end)

test("companion: a delayed summon waits for its timer", function()
    local _, NS, M = scene()
    assertTrue(NS.Companion.SummonByGUID(CAT, 2))
    assertEqual(#calls(M), 0, "nothing before the delay")
    assertEqual(pending(M), 1)
    tick(M, 1, 2)
    assertEqual(#calls(M), 1)
    assertEqual(calls(M)[1], CAT)
    assertEqual(pending(M), 0, "done: no retry left behind")
end)

-- ── dismiss ───────────────────────────────────────────────────────────────────────────────────

test("companion: DismissByName dismisses the summoned pet; another pet out is left alone", function()
    local _, NS, M = scene()
    M.__world.summonedPet = RAGNAROS
    assertTrue(NS.Companion.DismissByName("lil' ragnaros"))
    assertEqual(calls(M)[1], RAGNAROS)
    assertNil(NS.Companion.Summoned())
    M.__world.summonedPet, M.__world.petCalls = CAT, {}
    M.__now = M.__now + 5   -- past the 3 s window the dismiss call opened
    -- red under: dismissing whatever is out (the call would toggle the cat away).
    assertTrue(NS.Companion.DismissByGUID(SQUIRREL))
    assertEqual(#calls(M), 0, "the cat stays: it is not the pet asked to go")
    assertEqual(pending(M), 0, "and the wish is finished")
end)

test("companion: dismissing the pet of a pending summon cancels the summon", function()
    local _, NS, M = scene()
    NS.Companion.SummonByGUID(CAT, 2)
    -- red under: DismissByGUID ignoring the pending summon (it turns into a dismiss watch instead).
    assertTrue(NS.Companion.DismissByGUID(CAT))
    assertEqual(pending(M), 0, "the summon's ticker went and no watch replaced it")
    tick(M, 3)
    assertEqual(#calls(M), 0, "the summon was canceled")
    assertNil(NS.Companion.Summoned())
end)

test("companion: the auto-summon watch dismisses the pet when the game brings it back", function()
    local _, NS, M = scene()
    -- The game dismissed Ragnaros on its own (a flight); the dismiss finds nothing out and watches.
    assertTrue(NS.Companion.DismissByGUID(RAGNAROS))
    assertEqual(#calls(M), 0)
    assertEqual(pending(M), 1, "it reschedules to watch for the pet coming back")
    tick(M, 5)
    assertEqual(#calls(M), 0, "still nothing out: still watching")
    M.__world.summonedPet = RAGNAROS   -- the game auto-summons it
    tick(M)
    assertEqual(#calls(M), 1)
    assertEqual(calls(M)[1], RAGNAROS)
    assertNil(NS.Companion.Summoned())
    assertEqual(pending(M), 0)
end)

test("companion: the dismiss watch gives up at its 60 s deadline", function()
    local _, NS, M, _, debug = scene()
    NS.Companion.DismissByGUID(RAGNAROS)
    tick(M, 58)
    assertEqual(pending(M), 1, "still watching inside the deadline")
    -- red under: the legacy watch with no cap (it reschedules every second forever).
    tick(M, 3)
    assertEqual(pending(M), 0, "the watch stopped at the deadline")
    assertTrue(found(debug, "gave up"), "the give-up is a debug line")
    M.__world.summonedPet = RAGNAROS
    tick(M, 2)
    assertEqual(#calls(M), 0, "a pet summoned after the deadline stays")
end)

-- ── the blockers ──────────────────────────────────────────────────────────────────────────────

-- Each blocker: `on` sets it, `off` clears it. A summon asked while it holds waits, retrying each
-- second, and goes through on the first pass after it clears.
local BLOCKERS = {
    flying = { on = function(M) M.__world:setFlag("IsFlying", true) end,
               off = function(M) M.__world:setFlag("IsFlying", false) end },
    combat = { on = function(M) M.__fire("PLAYER_REGEN_DISABLED") end,
               off = function(M) M.__fire("PLAYER_REGEN_ENABLED") end },
    dead = { on = function(M) M.__fire("PLAYER_DEAD") end,
             off = function(M) M.__fire("PLAYER_ALIVE") end },
    feign = { on = function(_, feign) feign.on = true end, off = function(_, feign) feign.on = false end },
    casting = { on = function(M) M.__fire("UNIT_SPELLCAST_START", "player", "c1", 133) end,
                off = function(M) M.__fire("UNIT_SPELLCAST_STOP", "player", "c1", 133) end },
    channeling = { on = function(M) M.__fire("UNIT_SPELLCAST_CHANNEL_START", "player", "c2", 5143) end,
                   off = function(M) M.__fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "c2", 5143) end },
}

for _, name in ipairs({ "flying", "combat", "dead", "feign", "casting", "channeling" }) do
    test("companion: " .. name .. " blocks a summon until it clears", function()
        local _, NS, M, feign = scene()
        local b = BLOCKERS[name]
        b.on(M, feign)
        local ok, why = NS.Companion.CanAct()
        -- red under: dropping the blocker's row from BLOCKERS in modules/Companion.lua.
        assertFalse(ok, name .. " did not block")
        assertEqual(why, name)
        assertTrue(NS.Companion.SummonByGUID(SQUIRREL))
        tick(M, 3)
        assertEqual(#calls(M), 0, "nothing while " .. name)
        assertEqual(pending(M), 1, "a 1 s retry is armed")
        b.off(M, feign)
        assertTrue((NS.Companion.CanAct()))
        tick(M)
        assertEqual(#calls(M), 1, "summoned on the first pass after " .. name .. " cleared")
        assertEqual(calls(M)[1], SQUIRREL)
    end)
end

test("companion: a SummonPetByGUID call from anywhere blocks for 3 s (the hook)", function()
    local _, NS, M = scene()
    M.C_PetJournal.SummonPetByGUID(CAT)    -- the player, or another addon, through the journal
    M.__world.petCalls = {}
    local ok, why = NS.Companion.CanAct()
    -- red under: no hook installed, or a hook body that does not stamp the call time.
    assertFalse(ok)
    assertEqual(why, "recent")
    M.__now = M.__now + 2.9
    assertFalse((NS.Companion.CanAct()), "still inside the 3 s window")
    M.__now = M.__now + 0.2
    assertTrue((NS.Companion.CanAct()), "clear at 3 s")
end)

test("companion: Resume installs the hook once", function()
    local _, NS, M = scene()
    local function count()
        local n = 0
        for _, h in ipairs(M.__hooks) do
            if h.target == M.C_PetJournal and h.name == "SummonPetByGUID" then n = n + 1 end
        end
        return n
    end
    assertEqual(count(), 1)
    NS.Companion.Resume()
    NS.Companion.Suspend()
    NS.Companion.Resume()
    -- red under: hooking on every Resume (each would stamp, and a hook is never removed).
    assertEqual(count(), 1)
end)

test("companion: the hook body writes nothing while stood down", function()
    local _, NS, M = scene()
    local real = NS.IsStoodDown
    NS.IsStoodDown = function() return true end
    M.C_PetJournal.SummonPetByGUID(CAT)
    NS.IsStoodDown = real
    -- red under: a hook body without the stand-down check (the call time is stamped while down).
    assertTrue((NS.Companion.CanAct()), "the call made while down was not stamped")
end)

test("companion: blocked retries are capped at 30, with a debug line", function()
    local _, NS, M, _, debug = scene()
    M.__world:setFlag("IsFlying", true)
    NS.Companion.SummonByGUID(SQUIRREL)   -- try 1, blocked
    tick(M, 28)                           -- tries 2 .. 29
    assertEqual(pending(M), 1, "still retrying under the cap")
    -- red under: the legacy retry with no cap (INV §3.10 Fix).
    tick(M)                               -- try 30: the cap
    assertEqual(pending(M), 0, "gave up at the cap")
    assertTrue(found(debug, "gave up"))
    M.__world:setFlag("IsFlying", false)
    tick(M, 2)
    assertEqual(#calls(M), 0, "the abandoned wish never fires")
end)

-- ── the lifecycle ─────────────────────────────────────────────────────────────────────────────

test("companion: Suspend cancels the ticker and drops the wish; Resume does not bring it back", function()
    local _, NS, M = scene()
    NS.Companion.SummonByGUID(CAT, 2)
    assertEqual(pending(M), 1)
    NS.Companion.Suspend()
    -- red under: a Suspend that leaves the ticker armed.
    assertEqual(pending(M), 0, "the ticker was canceled")
    NS.Companion.Resume()
    tick(M, 3)
    assertEqual(#calls(M), 0, "the wish did not survive the stand-down")
    assertEqual(pending(M), 0)
end)

test("companion: the stand-down walk reaches Companion, and a stood-down summon is refused", function()
    local _, NS, M = scene()
    NS.Companion.SummonByGUID(CAT, 2)
    NS.ApplyEnabled(false)
    assertTrue(NS.IsStoodDown())
    assertEqual(pending(M), 0, "the walk canceled the ticker")
    -- red under: the public calls not reading the latch (a timer armed while down).
    assertFalse(NS.Companion.SummonByGUID(SQUIRREL))
    assertFalse(NS.Companion.DismissByGUID(SQUIRREL))
    assertEqual(#calls(M), 0)
    assertEqual(pending(M), 0, "nothing armed while down")
end)
