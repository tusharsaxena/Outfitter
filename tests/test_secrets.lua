-- tests/test_secrets.lua — the secret-value seam (design §2.2, BP §6.9; P3 C6 part): NS.Secrets'
-- conversions with the secrets system absent and present, the bounded walk, NS.Compat's guards on
-- both arms (the library's and the library-absent stub), the C6 unit/CVar/addon/spec reads answering
-- plain-or-nil, and the seam scan: no securable client API is named outside the compat family,
-- core/Secrets.lua and modules/States.lua. The Compat accessor part joins in P4.2, the states part in
-- P4.14 and the engine cases (PlayerIsFull, the aura scan, the balanced count) in P4.27.

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local S, C = NS.Secrets, NS.Compat

-- Run `fn` with the client's `issecretvalue` installed (the kit's simulator) and any mock overrides
-- in `over`, restoring both however `fn` leaves.
local function with(over, fn)
    local restoreSecret = T.installSecretValue()
    local saved = {}
    for k, v in pairs(over or {}) do
        saved[k] = { v = rawget(T.mocks, k) }
        T.mocks[k] = v
    end
    local ok, err = pcall(fn)
    for k, box in pairs(saved) do T.mocks[k] = box.v end
    restoreSecret()
    if not ok then error(err, 0) end
end

-- ── the surface ───────────────────────────────────────────────────────────────────────────────

test("secrets: NS.Secrets publishes the §2.2 surface and the NS aliases", function()
    for _, name in ipairs({ "IsSecret", "CanAccess", "IsSafeKey", "IsSealed", "Unsecret", "PlainNumber",
                            "PlainString", "UnsecretNumber", "PlainTruth", "PlainEquals",
                            "CanAccessTable", "SafeIterate" }) do
        assertEqual(type(S[name]), "function", "NS.Secrets." .. name)
    end
    assertEqual(S.ITERATION_LIMIT, 512)
    assertEqual(NS.IsSecret, S.IsSecret)
    assertEqual(NS.Unsecret, S.Unsecret)
    assertEqual(NS.SafeNumber, S.UnsecretNumber)
end)

test("secrets: the guards are NS.Compat's, routed through LibKa0s-Compat-1.0 when it loads", function()
    local lib = T.mocks.LibStub("LibKa0s-Compat-1.0", true)
    assertTrue(lib ~= nil, "the vendored Compat major registered")
    assertEqual(C.IsSecret, lib.IsSecret)
    assertEqual(C.CanAccess, lib.CanAccess)
    assertEqual(C.IsSafeKey, lib.IsSafeKey)
    assertEqual(C.GetSpecialization, lib.GetSpecialization)
    assertEqual(C.GetSpecializationInfo, lib.GetSpecializationInfo)
    assertEqual(S.IsSecret, C.IsSecret)
    assertEqual(S.CanAccess, C.CanAccess)
    assertEqual(S.IsSafeKey, C.IsSafeKey)
end)

-- ── conversions, secrets system absent ────────────────────────────────────────────────────────

test("secrets: without the secrets system every value is plain", function()
    assertFalse(S.IsSecret(5))
    assertFalse(S.IsSealed("x"))
    assertFalse(S.IsSealed(nil), "nil is absent, not sealed")
    assertEqual(S.Unsecret(7), 7)
    assertEqual(S.Unsecret("link"), "link")
    assertEqual(S.PlainNumber(3.5), 3.5)
    assertNil(S.PlainNumber("3"), "a string is not a number")
    assertNil(S.PlainNumber(nil))
    assertEqual(S.PlainString("x"), "x")
    assertNil(S.PlainString(4), "a number is not a string")
    assertEqual(S.UnsecretNumber(0, 9), 0, "0 is a plain number, not a miss")
    assertEqual(S.UnsecretNumber(nil, 9), 9)
    assertEqual(S.UnsecretNumber("4", 9), 9)
    assertNil(S.UnsecretNumber(nil), "the fallback defaults to nil")
    assertTrue(S.IsSafeKey("k"))
    assertFalse(S.IsSafeKey(nil), "nil is never a key")
    assertTrue(S.PlainEquals(2, 2))
    assertFalse(S.PlainEquals(2, 3))
end)

test("secrets: PlainTruth answers true, false or nil, reading 1 and 0 as the old flags", function()
    assertEqual(S.PlainTruth(true), true)
    assertEqual(S.PlainTruth(1), true)
    assertEqual(S.PlainTruth(false), false)
    assertEqual(S.PlainTruth(0), false)
    assertNil(S.PlainTruth(nil))
    assertNil(S.PlainTruth("yes"), "any other type is no claim")
end)

-- ── conversions, secrets system present ───────────────────────────────────────────────────────

test("secrets: a secret is sealed and every conversion refuses it without inspecting it", function()
    with(nil, function()
        local s = T.secret(42)
        assertTrue(S.IsSecret(s))
        assertTrue(NS.IsSecret(s), "the alias answers the same")
        assertTrue(S.IsSealed(s))
        assertFalse(S.CanAccess(s), "no canaccessvalue: accessible unless known secret")
        assertFalse(S.IsSafeKey(s))
        assertNil(S.Unsecret(s))
        assertNil(NS.Unsecret(s))
        assertNil(S.PlainNumber(s))
        assertNil(S.PlainString(T.secret("|cffffffff|Hitem:1|h[x]|h|r")))
        assertEqual(S.UnsecretNumber(s, 0), 0)
        assertEqual(NS.SafeNumber(s, -1), -1)
        assertNil(S.PlainTruth(T.secret(true)), "a secret boolean is never truth-tested")
        assertFalse(S.PlainEquals(s, 42))
        assertFalse(S.PlainEquals(42, s))
        assertFalse(S.PlainEquals(s, T.secret(42)), "two secrets never reach the trapped ==")
        -- A plain value is untouched with the system installed.
        assertEqual(S.PlainNumber(42), 42)
        assertFalse(S.IsSecret(42))
    end)
end)

test("secrets: canaccessvalue decides access where the client has it", function()
    with({ canaccessvalue = function(v) return v ~= "hidden" end }, function()
        assertTrue(S.CanAccess("shown"))
        assertFalse(S.CanAccess("hidden"))
        assertTrue(S.IsSealed("hidden"), "inaccessible is sealed even when not secret")
        assertNil(S.PlainString("hidden"))
        assertEqual(S.PlainString("shown"), "shown")
    end)
end)

-- ── the bounded walk ──────────────────────────────────────────────────────────────────────────

local function collect(t, max)
    local out = {}
    for i, e in S.SafeIterate(t, max) do out[#out + 1] = { i, e } end
    return out
end

test("secrets: SafeIterate walks in order and stops at the first nil", function()
    local got = collect({ "a", "b", nil, "d" })
    assertEqual(#got, 2)
    assertEqual(got[1][1], 1)
    assertEqual(got[1][2], "a")
    assertEqual(got[2][2], "b")
    assertEqual(#collect({}), 0)
end)

test("secrets: SafeIterate is bounded at max, and at 512 by default", function()
    local big = {}
    for i = 1, 600 do big[i] = i end
    assertEqual(#collect(big), 512)
    assertEqual(#collect(big, 100), 100)
    assertEqual(#collect(big, 0), 512, "a non-positive max takes the default")
    assertEqual(#collect(big, "9"), 512, "a non-number max takes the default")
end)

test("secrets: SafeIterate never measures the table with #", function()
    -- A proxy whose entries live behind __index: `#` on it answers 0 in Lua, so a walk that measured
    -- the table first would yield nothing.
    local backing = { "x", "y", "z" }
    local proxy = setmetatable({}, { __index = backing })
    assertEqual(#proxy, 0)
    assertEqual(#collect(proxy), 3)
end)

test("secrets: SafeIterate yields secret entries uninspected and refuses unreadable tables", function()
    with({ canaccesstable = function(t) return not t.locked end }, function()
        local s = T.secret(7)
        local got = collect({ s, 2 })
        assertEqual(#got, 2, "a secret entry is not the end of the list")
        assertTrue(T.isSecret(got[1][2]), "the entry is handed over as it came")
        assertEqual(#collect({ 1, 2, locked = true }), 0, "an inaccessible table yields nothing")
    end)
    assertEqual(#collect(nil), 0)
    assertEqual(#collect("not a table"), 0)
end)

test("secrets: issecrettable is the CanAccessTable rung without canaccesstable", function()
    with({ issecrettable = function(t) return t.sealed == true end }, function()
        assertFalse(S.CanAccessTable({ sealed = true }))
        assertTrue(S.CanAccessTable({}))
    end)
    assertTrue(S.CanAccessTable({}), "with neither global every table is readable")
    assertFalse(S.CanAccessTable(5), "a non-table is never readable")
end)

-- ── the library-absent arm ────────────────────────────────────────────────────────────────────

test("secrets: without LibKa0s the Compat stubs still detect a secret", function()
    -- The guard arm is the documented duplication: "the library is missing" is not "the client has
    -- no secrets system", so the stub must answer IsSecret -> true for a real secret.
    local inst = T.load({ libFiles = {}, init = false })
    local lib = T.mocks.LibStub("LibKa0s-Compat-1.0", true)
    assertTrue(inst.NS.Compat.IsSecret ~= lib.IsSecret, "the stub, not the library's member")
    with(nil, function()
        local s = T.secret(1)
        assertTrue(inst.NS.Secrets.IsSecret(s))
        assertFalse(inst.NS.Secrets.CanAccess(s))
        assertFalse(inst.NS.Secrets.IsSafeKey(s))
        assertNil(inst.NS.Secrets.PlainNumber(s))
        assertFalse(inst.NS.Secrets.IsSecret(1))
    end)
    assertFalse(inst.NS.Compat.IsSecret(T.secret(1)), "no client detector: nothing is secret")
end)

test("secrets: the library-absent spec stubs walk C_SpecializationInfo, then the globals", function()
    local inst = T.load({ libFiles = {}, init = false })
    local Cs = inst.NS.Compat
    assertEqual(Cs.GetSpecialization(), 1, "the bare global rung")
    assertEqual((Cs.GetSpecializationInfo(1)), 250)
    assertNil(Cs.GetSpecializationInfo(nil), "no index, no client call")
    inst.mocks.C_SpecializationInfo = {
        GetSpecialization = function() return 3 end,
        GetSpecializationInfo = function(i) return 260 + i end,
    }
    assertEqual(Cs.GetSpecialization(), 3, "the namespaced rung, seen at call time")
    assertEqual((Cs.GetSpecializationInfo(2)), 262)
    inst.mocks.C_SpecializationInfo, inst.mocks.GetSpecialization = nil, false
    assertNil(Cs.GetSpecialization(), "no rung: nil")
end)

-- ── the C6 reads, plain-or-nil ────────────────────────────────────────────────────────────────

test("compat: the unit reads answer plain values", function()
    with({ UnitFactionGroup = function() return "Horde", "Horde (localized)" end,
           UnitLevel = function(unit) return unit == "player" and 80 or 1 end,
           UnitIsDeadOrGhost = function() return false end }, function()
        assertEqual(C.PlayerClass(), T.mocks.__context.classToken)
        assertEqual(C.PlayerFaction(), "Horde", "UnitFactionGroup's FIRST return (H10)")
        assertEqual(C.UnitLevel(), 80, "defaults to the player")
        assertEqual(C.UnitLevel("target"), 1)
        assertEqual(C.IsDeadOrGhost(), false)
        assertEqual(C.InCombatLockdown(), false)
        assertEqual(C.PlayerSpecID(), 250)
    end)
end)

test("compat: a secret read leaves Compat as nil, never as the secret", function()
    with({ UnitFactionGroup = function() return T.secret("Horde") end,
           UnitLevel = function() return T.secret(80) end,
           UnitIsDeadOrGhost = function() return T.secret(true) end,
           UnitClass = function() return "Warrior", T.secret("WARRIOR") end,
           GetCVar = function() return T.secret("1") end,
           GetSpecialization = function() return T.secret(1) end }, function()
        assertNil(C.PlayerFaction())
        assertNil(C.UnitLevel(), "a secret level reads as unknown: the filters let the item through")
        assertNil(C.IsDeadOrGhost())
        assertNil(C.PlayerClass())
        assertNil(C.GetCVar("Sound_EnableSFX"), "a secret CVar: the SFX mute is skipped")
        assertNil(C.PlayerSpecID())
    end)
end)

test("compat: an absent API answers its no-answer value", function()
    with({ UnitFactionGroup = false, UnitLevel = false, UnitIsDeadOrGhost = false, GetCVar = false,
           SetCVar = false, GetNumSpecializations = false }, function()
        -- `false` stands for "absent" here: the mock's __index would otherwise fall through to it.
        assertNil(C.UnitLevel())
        assertNil(C.PlayerFaction())
        assertNil(C.IsDeadOrGhost())
        assertNil(C.GetCVar("x"))
        assertFalse(C.SetCVar("x", "1"))
        assertEqual(C.NumSpecializations(), 0)
    end)
end)

test("compat: CVars, the clock, the spec count and other addons", function()
    local written = {}
    with({ GetCVar = function(name) return name == "Sound_EnableSFX" and "1" or nil end,
           SetCVar = function(name, value) written[name] = value end,
           GetNumSpecializations = function() return 3 end,
           GetTime = function() return 12.5 end }, function()
        assertEqual(C.GetCVar("Sound_EnableSFX"), "1")
        assertNil(C.GetCVar("unknownCVar"))
        assertNil(C.GetCVar(nil))
        assertTrue(C.SetCVar("Sound_EnableSFX", "0"))
        assertEqual(written.Sound_EnableSFX, "0")
        assertEqual(C.NumSpecializations(), 3)
        assertEqual(C.GetTime(), 12.5)
        assertEqual(C.IsAddOnLoaded("Pawn"), true)
        assertEqual(C.IsAddOnLoaded(nil), false)
    end)
    with({ C_AddOns = { IsAddOnLoaded = function(name) return name == "Pawn", name == "Pawn" end } }, function()
        assertEqual(C.IsAddOnLoaded("Pawn"), true)
        assertEqual(C.IsAddOnLoaded("WeightsWatcher"), false)
    end)
end)

-- ── the seam scan ─────────────────────────────────────────────────────────────────────────────

-- The client APIs whose answers may be secret: a module that names one has read a value it may not
-- inspect. Each is matched as a bare global (not `X.UnitLevel`, not `X:UnitLevel`), as a prefix, so
-- UnitHealthMax and UnitPowerType count too.
local SECURABLE = { "UnitHealth", "UnitPower", "UnitStat", "UnitLevel", "C_UnitAuras", "UnitAura",
                    "UnitBuff", "UnitDebuff", "AuraUtil", "GetPlayerAuraBySpellID" }

-- The files allowed to name them: the compat family, the secrets seam and the state producer.
local function allowed(rel)
    return rel:find("^core/Compat[%w]*%.lua$") ~= nil or rel == "core/Secrets.lua"
        or rel == "modules/States.lua"
end

-- Comments and string literals stripped, so a mention in prose or a message is not a call.
local function stripped(text)
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    text = text:gsub("%[(=*)%[.-%]%1%]", '""')
    text = text:gsub("%-%-[^\n]*", "")
    text = text:gsub('"[^"\n]*"', '""'):gsub("'[^'\n]*'", "''")
    return text
end

-- The securable names `text` reads as globals.
local function securableReads(text)
    local code = "\n" .. stripped(text)
    local hits = {}
    for _, name in ipairs(SECURABLE) do
        if code:find("[^%w_%.:]" .. name) then hits[#hits + 1] = name end
    end
    return hits
end

-- Every authored Lua file: the TOC's, plus any on disk in the addon folders the TOC does not list yet.
local function authoredFiles()
    local seen, out = {}, {}
    local function add(rel)
        rel = rel:gsub("\\", "/"):gsub("^%./", "")
        if not seen[rel] then
            seen[rel] = true
            out[#out + 1] = rel
        end
    end
    for _, rel in ipairs(T.loadedAddonFiles) do add(rel) end
    local p = io.popen('cd "' .. T.root .. '" && find core defaults locales modules settings -name "*.lua" 2>/dev/null')
    if p then
        for line in p:lines() do add(line) end
        p:close()
    end
    return out
end

test("secrets seam: the scanner catches a securable read and nothing else (mutation self-test)", function()
    assertEqual(#securableReads("local h = UnitHealth('player')"), 1)
    assertEqual(#securableReads("local m = UnitPowerMax('player', 0)"), 1, "the prefix catches the variants")
    assertEqual(#securableReads("if C_UnitAuras.GetAuraDataByIndex then end"), 1)
    assertEqual(#securableReads("return UnitLevel(unit)"), 1)
    assertEqual(#securableReads("local l = NS.Compat.UnitLevel()"), 0, "a Compat member is not the global")
    assertEqual(#securableReads("local l = Compat:UnitLevel()"), 0)
    assertEqual(#securableReads("-- UnitHealth is read in Compat only"), 0, "a comment is not a read")
    assertEqual(#securableReads('print("UnitStat")'), 0, "a string is not a read")
    assertEqual(#securableReads("local MyUnitLevel = 1"), 0, "a longer identifier is not the global")
    assertTrue(allowed("core/Compat.lua"))
    assertTrue(allowed("core/Secrets.lua"))
    assertTrue(allowed("modules/States.lua"))
    assertFalse(allowed("modules/Equip.lua"))
    assertFalse(allowed("modules/States_Zone.lua"))
end)

test("secrets seam: no securable client API is named outside the compat family, Secrets and States", function()
    local files = authoredFiles()
    assertTrue(#files > 0, "no authored files found; nothing below can fail")
    local scanned = 0
    for _, rel in ipairs(files) do
        if not allowed(rel) then
            local f = assert(io.open(T.root .. "/" .. rel, "r"))
            local text = f:read("*a")
            f:close()
            scanned = scanned + 1
            local hits = securableReads(text)
            assertEqual(#hits, 0, rel .. " names " .. table.concat(hits, ", "))
        end
    end
    assertTrue(scanned > 0, "every file was allowed; the scan scanned nothing")
end)
