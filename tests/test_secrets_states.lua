-- tests/test_secrets_states.lua — the states part of the secret-value seam (design §2.2, §6.10, §6.12;
-- INV §8.1, §8.4), split out of tests/test_secrets.lua at the group A merge (that file stood at 841
-- lines after P4.2): PlayerIsFull's truth table over real, secret and missing readings; the aura scan
-- (the restriction resolved by name, Combat = 0 included; the getter never called while restricted;
-- IsSecret before the nil test, so a secret aura is skipped and is not the end of the list; a secret
-- field read as no match); and Spirit's prevMana surviving a secret sample. Run against
-- modules/States.lua with the client's issecretvalue installed (the kit's simulator).
--
-- NS.Equip (P4.8), NS.Triggers (P4.15) and NS.Stack (P4.9) are recorded fakes (design §12).

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function scene()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    T.fake(NS, "Equip", { Batch = function(fn, ...) return true, fn(...) end,
                          SuspendedForLoad = function() return false end, Request = true, DelayUntil = true })
    T.fake(NS, "Triggers", { ForState = function() return {} end })
    T.fake(NS, "Stack", { IsWorn = function() return false end })
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.STATE_CHANGED, function(_, id, on)
        heard[#heard + 1] = id .. "=" .. tostring(on)
    end)
    NS.States.Resume()
    for _ = 1, 3 do M.__fireTimers() end
    for i = #heard, 1, -1 do heard[i] = nil end
    return { NS = NS, M = M, S = NS.States, W = M.__world, heard = heard }
end

-- Run `fn(s)` with issecretvalue installed, restored however fn leaves.
local function withSecrets(fn)
    local restore = T.installSecretValue()
    local ok, err = pcall(fn, scene())
    restore()
    if not ok then error(err, 0) end
end

local function aura(spellId, icon) return { spellId = spellId, icon = icon or 136000 } end

-- ── PlayerIsFull (Outfitter.lua:1887-1930) ────────────────────────────────────────────────────

-- Each row: the player unit fields, and whether that reads as full.
local FULL_TABLE = {
    { "everything topped up",            { health = 100, healthMax = 100, powerType = 0, power = 100, powerMax = 100 }, true },
    { "health at exactly 85 %",          { health = 85, healthMax = 100, powerType = 0, power = 100, powerMax = 100 }, true },
    { "health just under 85 %",          { health = 84, healthMax = 100, powerType = 0, power = 100, powerMax = 100 }, false },
    { "mana at exactly 85 %",            { health = 100, healthMax = 100, powerType = 0, power = 85, powerMax = 100 }, false },
    { "mana just over 85 %",             { health = 100, healthMax = 100, powerType = 0, power = 86, powerMax = 100 }, true },
    { "a rage user at full health",      { health = 100, healthMax = 100, powerType = 1, power = 0, powerMax = 100 }, true },
    { "a rage user low on health",       { health = 10, healthMax = 100, powerType = 1, power = 0, powerMax = 100 }, false },
    { "a zero health maximum",           { health = 0, healthMax = 0, powerType = 1, power = 0, powerMax = 0 }, false },
    { "a zero mana maximum",             { health = 100, healthMax = 100, powerType = 0, power = 0, powerMax = 0 }, false },
}

test("secrets states: PlayerIsFull over plain readings, both 85 % edges and the power type", function()
    local s = scene()
    for _, row in ipairs(FULL_TABLE) do
        s.W:setUnit("player", row[2])
        assertEqual(s.S.PlayerIsFull(), row[3], row[1])
    end
end)

test("secrets states: every secret or missing reading means not full", function()
    withSecrets(function(s)
        local base = { health = 100, healthMax = 100, powerType = 0, power = 100, powerMax = 100 }
        -- The client read behind each field: "missing" is that read answering nil.
        local READ = { health = "UnitHealth", healthMax = "UnitHealthMax", powerType = "UnitPowerType",
                       power = "UnitPower", powerMax = "UnitPowerMax" }
        for _, key in ipairs({ "health", "healthMax", "powerType", "power", "powerMax" }) do
            for _, kind in ipairs({ "secret", "missing" }) do
                local u = {}
                for k, v in pairs(base) do u[k] = v end
                if kind == "secret" then u[key] = T.secret(base[key]) end
                s.M.__units.player = u
                local real = s.M[READ[key]]
                if kind == "missing" then s.M[READ[key]] = function() return nil end end
                local full = s.S.PlayerIsFull()
                s.M[READ[key]] = real
                -- legacy: an unreadable power type defaulted to -1 and read as full (INV §8.4); fixed:
                -- red under: `if not powerType then return true end` in PlayerIsFull.
                assertFalse(full, kind .. " " .. key .. " read as full")
            end
        end
        -- A secret rage user's health is still unreadable: not full, even though power does not count.
        s.M.__units.player = { health = T.secret(100), healthMax = 100, powerType = 1 }
        assertFalse(s.S.PlayerIsFull(), "secret health, rage")
    end)
end)

-- ── the aura scan ─────────────────────────────────────────────────────────────────────────────

test("secrets states: while any of the four restrictions is active the getter is never called", function()
    local s = scene()
    s.W:setAuras("player", "HELPFUL", { aura(2645) })
    s.M.__fire("UNIT_AURA", "player")
    assertTrue(s.S.IsActive("GHOST_WOLF"))
    assertTrue(s.S.PlayerHasSpell(2645))
    local E = s.M.Enum.AddOnRestrictionType
    for _, name in ipairs({ "Combat", "Encounter", "ChallengeMode", "PvPMatch" }) do
        s.W:setRestricted({ [E[name]] = true })
        assertTrue(s.S.AuraRestricted(), name)
        -- The mock's getters raise while restricted, as the client's do since 12.1.
        local ok, err = pcall(s.M.__fire, "UNIT_AURA", "player")
        -- red under: no AuraRestricted() read before the scan.
        assertTrue(ok, name .. ": the scan read the auras: " .. tostring(err))
        assertFalse(s.S.IsActive("GHOST_WOLF"), name .. ": every aura state reads false")
        assertFalse(s.S.PlayerHasSpell(2645), name .. ": no spell is known")
        s.W:setRestricted(false)
        s.M.__fire("UNIT_AURA", "player")
        assertTrue(s.S.IsActive("GHOST_WOLF"), name .. ": UNIT_AURA restores it")
    end
    -- Combat is 0: the type is looked up by name, and 0 is a real type, not a missing one.
    assertEqual(E.Combat, 0, "the mock keeps the client's Combat = 0")
    -- Map is not one of the four.
    s.W:setRestricted({ [E.Map] = true })
    -- red under: reading every Enum.AddOnRestrictionType member instead of the four by name.
    assertFalse(s.S.AuraRestricted(), "Map")
    s.W:setRestricted(false)
end)

test("secrets states: a secret aura is skipped, not taken for the end of the list", function()
    withSecrets(function(s)
        s.W:setAuras("player", "HELPFUL", { T.secret(aura(5384)), aura(2645) })
        local ok, err = pcall(s.M.__fire, "UNIT_AURA", "player")
        -- red under: the nil test before IsSecret (`if not aura then break end` first raises on a
        -- secret under the client, and the simulator raises the same way).
        assertTrue(ok, tostring(err))
        -- red under: `if NS.IsSecret(aura) then break end` (the secret would end the scan).
        assertTrue(s.S.IsActive("GHOST_WOLF"), "the aura after the secret one")
        assertFalse(s.S.IsActive("FEIGN_DEATH"), "the secret aura itself")
    end)
end)

test("secrets states: a secret icon falls through to the spell; a secret spell id matches nothing", function()
    withSecrets(function(s)
        s.W:setAuras("player", "HELPFUL", { { icon = T.secret(134062), spellId = 2645 } })
        s.M.__fire("UNIT_AURA", "player")
        assertFalse(s.S.IsActive("DINING"), "the secret icon")
        assertTrue(s.S.IsActive("GHOST_WOLF"), "the plain spell id under it")
        s.W:setAuras("player", "HELPFUL", { { icon = 136000, spellId = T.secret(5384) } })
        s.M.__fire("UNIT_AURA", "player")
        -- red under: keying AURA_SPELL_STATE with the raw spellId (a secret key raises in the client).
        assertFalse(s.S.IsActive("FEIGN_DEATH"))
        assertFalse(s.S.PlayerHasSpell(5384), "a secret spell id is never recorded")
    end)
end)

-- ── Spirit's prevMana ─────────────────────────────────────────────────────────────────────────

test("secrets states: the last mana reading survives a secret sample", function()
    withSecrets(function(s)
        local now = 1000
        s.M.GetTime = function() return now end
        s.S.Demand("STATE:SPIRIT_REGEN", 1)
        s.S.Set("SPIRIT_REGEN", true)
        s.W:setUnit("player", { power = 500, powerMax = 1000, powerType = 0 })
        s.M.__fire("UNIT_POWER_UPDATE", "player", "MANA")
        s.W:setUnit("player", { power = T.secret(400) })
        s.M.__fire("UNIT_SPELLCAST_SENT", "player", "", "cast-1", 133)
        s.M.__fire("UNIT_POWER_UPDATE", "player", "MANA")
        assertTrue(s.S.IsActive("SPIRIT_REGEN"), "a secret sample is no drop")
        now = 1002
        s.W:setUnit("player", { power = 500 })
        s.M.__fire("UNIT_POWER_UPDATE", "player", "MANA")
        -- legacy: the secret sample set PreviousManaLevel to nil, and this one read as a drop
        -- (INV §8.4); fixed:
        -- red under: `prevMana = mana` with no nil check in the Spirit handler.
        assertTrue(s.S.IsActive("SPIRIT_REGEN"), "500 after 500 is no drop")
        s.W:setUnit("player", { power = 450 })
        s.M.__fire("UNIT_POWER_UPDATE", "player", "MANA")
        assertFalse(s.S.IsActive("SPIRIT_REGEN"), "a real drop still counts")
    end)
end)
