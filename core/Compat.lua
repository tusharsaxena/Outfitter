local _, NS = ...
-- core/Compat.lua — NS.Compat, the compat family's root and only file (compat.md :7, :11): every
-- version-variant client call the addon makes, and every LibKa0s-Compat-1.0 member it consumes. No
-- other file names these APIs, and the family has no other file.
--
-- Routed through LibKa0s-Compat-1.0 (library-stack-§7), each with its library-absent stub:
--   Compat.IsSecret(v)  Compat.CanAccess(v)  Compat.IsSafeKey(v)   the three secret-value guards
--   Compat.GetSpecialization()  Compat.GetSpecializationInfo(index)
--                                C_SpecializationInfo first, then the deprecated globals
-- Hand-written ladders and reads (P3 C6):
--   Compat.CanAccessTable(t)     canaccesstable, then issecrettable, then "readable"
--   Compat.NumSpecializations()  the class's spec count, 0 when unknown
--   Compat.PlayerSpecID()        the active spec's ID, or nil
--   Compat.PlayerClass()         the class token ("WARRIOR"), or nil
--   Compat.PlayerFaction()       UnitFactionGroup's FIRST return ("Horde"), or nil (H10)
--   Compat.UnitLevel(unit)       a plain level, or nil (nil means "don't filter")
--   Compat.IsDeadOrGhost(unit)   true / false, or nil when unreadable
--   Compat.InCombatLockdown()    true / false
--   Compat.GetCVar(name)         a plain string, or nil
--   Compat.SetCVar(name, value)  true when the client took the write
--   Compat.GetTime()             the client clock, 0 without one
--   Compat.IsAddOnLoaded(name)   true / false
-- The item, container, equipment-manager, pet, bank, tooltip, title and macro-icon accessors join
-- this file in P4.2 (design §5.13); one file, because the family stays under the 1000-line split
-- line (compat.md :11, design C39).
--
-- Every client global is read BARE and at CALL time, so a client (or the harness's mock) that adds an
-- API later is seen, and a suite can take a rung away after load and watch the ladder move.
--
-- EVERY MEMBER ANSWERS PLAIN-OR-NIL. A read that may come back secret is passed through NS.Secrets
-- before it leaves this file, so no module ever holds a raw value that might be secret (INV §12).
-- NS.Secrets is reached at CALL time only: core/Secrets.lua binds this file's guards at FILE SCOPE,
-- so this file loads first, and a file-scope capture here would read nil (test_loadorder pins it).

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

-- ---------------------------------------------------------------------------
-- The secret guards: LibKa0s-Compat-1.0's, with the stub arm
-- ---------------------------------------------------------------------------
--
-- THE GUARD ARM is a deliberate, documented duplication (LibKa0s docs/api/Compat/version-1-docs.md,
-- "Degradation: two kinds of member, two stub rules"). "The library is missing" is not "the client
-- has no secrets system": a stub answering IsSecret -> false on a 12.x client would send a secret
-- into a comparison mid-swap, on exactly the degraded path the stub exists to survive. The client
-- globals are read BARE and at CALL time, as the library reads them, so the mock reaches both arms.

local function isSecretStub(v)
    local fn = issecretvalue
    if not fn then return false end
    return fn(v) and true or false
end

local function canAccessStub(v)
    local fn = canaccessvalue
    if fn then return fn(v) and true or false end
    return not isSecretStub(v)
end

local function isSafeKeyStub(v)
    if isSecretStub(v) then return false end
    return v ~= nil
end

--- Whether `v` is a secret value. False on a client without the secrets system.
--- @param v any
--- @return boolean
Compat.IsSecret = CompatLib and CompatLib.IsSecret or isSecretStub

--- Whether this context may look at `v`. A plain value always answers true.
--- @param v any
--- @return boolean
Compat.CanAccess = CompatLib and CompatLib.CanAccess or canAccessStub

--- Whether `v` may be a table KEY right now (not secret, not nil).
--- @param v any
--- @return boolean
Compat.IsSafeKey = CompatLib and CompatLib.IsSafeKey or isSafeKeyStub

--- Whether this context may read the CONTENTS of table `t` (the caller has checked it is a table).
--- No LibKa0s major carries it. Without either client global every table is readable.
--- @param t table
--- @return boolean
function Compat.CanAccessTable(t)
    local can = canaccesstable
    if can then return can(t) and true or false end
    local isSecretTable = issecrettable
    if isSecretTable then return not isSecretTable(t) end
    return true
end

-- ---------------------------------------------------------------------------
-- The player's specialization: LibKa0s-Compat-1.0's, with the stub arm
-- ---------------------------------------------------------------------------
-- The stubs walk the library's two rungs: C_SpecializationInfo where it exists, else the deprecated
-- global. Both read the client at CALL time.

local function getSpecializationStub()
    local api = C_SpecializationInfo
    if api and api.GetSpecialization then return (api.GetSpecialization()) end
    local bare = GetSpecialization
    if bare then return (bare()) end
    return nil
end

local function getSpecializationInfoStub(index)
    if not index then return nil end
    local api = C_SpecializationInfo
    if api and api.GetSpecializationInfo then return api.GetSpecializationInfo(index) end
    local bare = GetSpecializationInfo
    if bare then return bare(index) end
    return nil
end

--- The player's active specialization index, or nil.
--- @return number|nil
Compat.GetSpecialization = CompatLib and CompatLib.GetSpecialization or getSpecializationStub

--- The specialization's info for `index` (specID, name, description, icon, role, ...), or nil.
--- @param index number
Compat.GetSpecializationInfo = CompatLib and CompatLib.GetSpecializationInfo or getSpecializationInfoStub

--- How many specializations the player's class has; 0 when the client cannot say.
--- @return number
function Compat.NumSpecializations()
    local api = C_SpecializationInfo
    local fn = (api and api.GetNumSpecializations) or GetNumSpecializations
    if not fn then return 0 end
    return NS.Secrets.UnsecretNumber(fn(), 0)
end

--- The active specialization's ID (71 = Arms), or nil with no spec chosen or an unreadable answer.
--- @return number|nil
function Compat.PlayerSpecID()
    local index = NS.Secrets.PlainNumber(Compat.GetSpecialization())
    if not index then return nil end
    return NS.Secrets.PlainNumber((Compat.GetSpecializationInfo(index)))
end

-- ---------------------------------------------------------------------------
-- Unit reads
-- ---------------------------------------------------------------------------

--- The player's class token ("WARRIOR"): UnitClass's SECOND return, which is locale-independent.
--- @return string|nil
function Compat.PlayerClass()
    if not UnitClass then return nil end
    local _, token = UnitClass("player")
    return NS.Secrets.PlainString(token)
end

--- The player's faction group ("Alliance", "Horde", "Neutral"): UnitFactionGroup's FIRST return,
--- never the localized second (H10; the Horde lance alias keys on it, design §5.1).
--- @return string|nil
function Compat.PlayerFaction()
    if not UnitFactionGroup then return nil end
    local faction = UnitFactionGroup("player")
    return NS.Secrets.PlainString(faction)
end

--- A unit's level as a plain number, or nil. nil means "unknown": the item filters that read it let
--- the item through rather than guess (INV §12, UnitLevel).
--- @param unit string|nil  defaults to "player"
--- @return number|nil
function Compat.UnitLevel(unit)
    if not UnitLevel then return nil end
    return NS.Secrets.PlainNumber(UnitLevel(unit or "player"))
end

--- Whether a unit is dead or a ghost; nil when the answer cannot be read.
--- @param unit string|nil  defaults to "player"
--- @return boolean|nil
function Compat.IsDeadOrGhost(unit)
    if not UnitIsDeadOrGhost then return nil end
    return NS.Secrets.PlainTruth(UnitIsDeadOrGhost(unit or "player"))
end

--- Whether the client is in combat lockdown (secure frames frozen). False without the API.
--- @return boolean
function Compat.InCombatLockdown()
    if not InCombatLockdown then return false end
    return NS.Secrets.PlainTruth(InCombatLockdown()) == true
end

-- ---------------------------------------------------------------------------
-- Console variables, the clock and other addons
-- ---------------------------------------------------------------------------

--- A console variable's value as a plain string, or nil when unset, unknown or unreadable. The
--- equip path saves "Sound_EnableSFX" only when this answers (design §5.10).
--- @param name string
--- @return string|nil
function Compat.GetCVar(name)
    if not GetCVar or type(name) ~= "string" then return nil end
    return NS.Secrets.PlainString(GetCVar(name))
end

--- Write a console variable. True when the client took it; false without the API.
--- @param name string
--- @param value any  a string or a number, as the client takes
--- @return boolean
function Compat.SetCVar(name, value)
    if not SetCVar or type(name) ~= "string" then return false end
    return SetCVar(name, value) ~= false
end

--- The client clock in seconds. 0 without it, so a comparison never meets nil.
--- @return number
function Compat.GetTime()
    if not GetTime then return 0 end
    return NS.Secrets.UnsecretNumber(GetTime(), 0)
end

--- Whether another addon is loaded (Pawn, WeightsWatcher, the legacy Outfitter): C_AddOns since
--- 10.1, then the bare global it replaced. False without either.
--- @param name string
--- @return boolean
function Compat.IsAddOnLoaded(name)
    if type(name) ~= "string" then return false end
    local api = C_AddOns
    local fn = (api and api.IsAddOnLoaded) or IsAddOnLoaded
    if not fn then return false end
    return NS.Secrets.PlainTruth((fn(name))) == true
end
