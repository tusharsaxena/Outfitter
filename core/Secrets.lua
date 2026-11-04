local _, NS = ...
-- core/Secrets.lua — NS.Secrets, the ONLY file that inspects a value that may be secret (BP §6.9):
-- the secret guards (NS.Compat's, which core/Compat.lua routes through LibKa0s-Compat-1.0 with its
-- stub arm), plain-value conversion and the bounded array walk; plus the NS.IsSecret, NS.Unsecret and
-- NS.SafeNumber aliases that replace the legacy Outfitter API helpers.
--
-- THE CONTRACT (WoW 12.0 secret values): while an addon restriction is active, health, power, stats,
-- levels, item links and aura fields may arrive SECRET. Tainted code may store one, pass it, put it in
-- a table VALUE and hand it to a widget setter. It may NOT do arithmetic on it, compare it, truth-test
-- a secret boolean, concatenate it, key a table with it, apply `#` to it or index it. A NON-boolean
-- secret may be tested for nil-ness, which is the one operation SafeIterate leans on.
--
-- THE RULE (INV §12, design §2.2): no module receives a raw value that might be secret. Every risky
-- read happens in core/Compat.lua and leaves through one of the Plain* members below BEFORE any
-- engine state moves. That is what keeps the legacy failure mode out: an error between
-- BeginEquipmentUpdate and its end stranded the update counter and silently stopped every later
-- equipment change.
--
-- DEGRADATION: every member is correct with the secrets system ABSENT (an older client, the headless
-- harness): nothing is secret, everything is accessible, iteration is plain array semantics.
--
-- No perf brackets here: core/PerfSetup.lua loads after this file, and a per-value NS lookup is the
-- cost the perf contract forbids. Callers carry the brackets.
--
-- LOAD ORDER: binds NS.Compat's guards at FILE SCOPE, so core/Compat.lua loads first (the TOC says
-- so). This file names no client global: the detectors and their ladders live in the compat family.

local Secrets = {}
NS.Secrets = Secrets
local Compat = NS.Compat

-- ---------------------------------------------------------------------------
-- The three guards: NS.Compat's (LibKa0s-Compat-1.0's, or core/Compat.lua's stub arm)
-- ---------------------------------------------------------------------------

--- Whether `v` is a secret value. False on a client without the secrets system.
--- @param v any
--- @return boolean
Secrets.IsSecret = Compat.IsSecret

--- Whether this context may look at `v`: the question that decides whether arithmetic or a
--- comparison on it is legal. A plain value always answers true.
--- @param v any
--- @return boolean
Secrets.CanAccess = Compat.CanAccess

--- Whether `v` may be a table KEY right now (not secret, not nil).
--- @param v any
--- @return boolean
Secrets.IsSafeKey = Compat.IsSafeKey

-- ---------------------------------------------------------------------------
-- Value conversion
-- ---------------------------------------------------------------------------

--- Whether `v` is present but may not be looked at: secret, or inaccessible to this context. nil is
--- absent, not sealed.
--- @param v any
--- @return boolean
function Secrets.IsSealed(v)
    if Secrets.IsSecret(v) then return true end
    return not Secrets.CanAccess(v)
end

--- `v` itself when it is plain, nil when it is sealed. The legacy API's Unsecret.
--- @param v any
--- @return any
function Secrets.Unsecret(v)
    if Secrets.IsSealed(v) then return nil end
    return v
end

--- `v` as a plain Lua number, or nil when it is nil, sealed or not a number. The sealed test runs
--- FIRST, so a secret never meets type() on a client where type() answers its underlying type.
--- @param v any
--- @return number|nil
function Secrets.PlainNumber(v)
    if Secrets.IsSealed(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

--- `v` as a plain Lua string, or nil when it is nil, sealed or not a string. An item link is stored
--- only after this answers (design §3.3): a secret must never reach SavedVariables.
--- @param v any
--- @return string|nil
function Secrets.PlainString(v)
    if Secrets.IsSealed(v) then return nil end
    if type(v) ~= "string" then return nil end
    return v
end

--- `v` as a plain number, or `fallback` when it is not one. The legacy API's UnsecretNumber:
--- a secret health sample reads as `fallback`, and the caller takes its conservative branch.
--- @param v any
--- @param fallback any
--- @return any
function Secrets.UnsecretNumber(v, fallback)
    local n = Secrets.PlainNumber(v)
    if n == nil then return fallback end
    return n
end

--- A client flag as a plain boolean: true for true or 1, false for false or 0 (the 1/0 flags the
--- older APIs still return), nil when it is nil, sealed or of any other type. `if flag then` on a
--- secret boolean raises; a nil answer is "no claim", and every caller treats it as unknown.
--- @param v any
--- @return boolean|nil
function Secrets.PlainTruth(v)
    if Secrets.IsSealed(v) then return nil end
    local kind = type(v)
    if kind == "boolean" then return v end
    if kind == "number" then return v ~= 0 end
    return nil
end

--- True only when both operands are plain and equal. One sealed operand answers false without the
--- comparison ever running.
--- @param a any
--- @param b any
--- @return boolean
function Secrets.PlainEquals(a, b)
    if Secrets.IsSealed(a) or Secrets.IsSealed(b) then return false end
    return a == b
end

-- ---------------------------------------------------------------------------
-- Table inspection
-- ---------------------------------------------------------------------------

--- Whether this context may read the CONTENTS of `t`. A non-table answers false. Without the client
--- globals every table is readable.
--- @param t any
--- @return boolean
function Secrets.CanAccessTable(t)
    if type(t) ~= "table" then return false end
    return Compat.CanAccessTable(t)
end

-- The default ceiling on one walk. `#` is forbidden on a secret, and a table dense past any sane
-- length would spin the client; 512 is far beyond any equipment-set, aura or title list.
local ITERATION_LIMIT = 512
Secrets.ITERATION_LIMIT = ITERATION_LIMIT

local function emptyIterator() return nil end

--- An iterator over a possibly-secret array: `for i, e in Secrets.SafeIterate(t) do ... end`.
---
--- Never applies `#` and never uses ipairs; refuses an inaccessible table (yields nothing); stops at
--- the first nil (a nil-ness test, the one operation legal on a non-boolean secret); bounded at `max`
--- (default 512, a non-plain or non-positive `max` takes the default); never inspects the entry it
--- yields, so an entry may itself be secret and the caller decides what to do with it.
--- @param t table|nil
--- @param max number|nil
--- @return function
function Secrets.SafeIterate(t, max)
    if not Secrets.CanAccessTable(t) then return emptyIterator end
    local limit = Secrets.PlainNumber(max)
    if not limit or limit < 1 then limit = ITERATION_LIMIT end
    local i = 0
    return function()
        if i >= limit then return nil end
        i = i + 1
        local e = t[i]
        if e == nil then
            i = limit
            return nil
        end
        return i, e
    end
end

-- ---------------------------------------------------------------------------
-- The NS aliases (BP §6.9): the names the legacy Outfitter API helpers had, one hop shorter
-- ---------------------------------------------------------------------------

NS.IsSecret = Secrets.IsSecret
NS.Unsecret = Secrets.Unsecret
NS.SafeNumber = Secrets.UnsecretNumber
