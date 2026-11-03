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
--   Compat.PlayerClassName()     the localized class name ("Warrior"), or nil (P4.6)
--   Compat.PlayerFaction()       UnitFactionGroup's FIRST return ("Horde"), or nil (H10)
--   Compat.UnitLevel(unit)       a plain level, or nil (nil means "don't filter")
--   Compat.IsDeadOrGhost(unit)   true / false, or nil when unreadable
--   Compat.InCombatLockdown()    true / false
--   Compat.GetCVar(name)         a plain string, or nil
--   Compat.SetCVar(name, value)  true when the client took the write
--   Compat.GetTime()             the client clock, 0 without one
--   Compat.IsAddOnLoaded(name)   true / false
-- The P4.2 accessors (design §5.13), below the C6 reads: item links, info, stats and cooldowns;
-- binding, uniqueness, usability, upgrade and azerite reads by location; tooltip data; pets and the
-- two hooks; the Equipment Manager; titles; the bank; containers (and the last equipped bag, P4.5)
-- and the cursor; macro icons; Pawn; dual wield and BitAnd. One file, because the family stays under
-- the 1000-line split line (compat.md :11, design C39).
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

--- The player's class as the client shows it ("Druid"): UnitClass's FIRST return, already in the
--- player's gender form, which the seeded spec outfits are named after (P4.6, design §5.7).
--- @return string|nil
function Compat.PlayerClassName()
    if not UnitClass then return nil end
    return NS.Secrets.PlainString((UnitClass("player")))
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

--- Whether the player is casting and whether channeling, each nil when it cannot be read (no API,
--- or a sealed answer). PlayerState.Refresh re-reads both after a stand-down (design §5.2).
--- @return boolean|nil casting, boolean|nil channeling
function Compat.PlayerCasting()
    local function read(fn)
        if not fn then return nil end
        local name = fn("player")
        if NS.Secrets.IsSealed(name) then return nil end
        return name ~= nil
    end
    return read(UnitCastingInfo), read(UnitChannelInfo)
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

-- ===========================================================================
-- The P4.2 accessors (design §5.13): items, containers, the Equipment Manager, pets, tooltip data,
-- titles, the bank, the cursor, macro icons and Pawn. Each read answers plain-or-nil; a write answers
-- true when the client call was made and false when the API is absent.
--
-- A LOCATION (`loc`) is the addon's own plain table: `{ bag = bagID, slot = index }` for a container
-- slot, `{ slotID = inventorySlotID }` for an equipped one. Only this file turns one into the client's
-- ItemLocation. The client APIs still to be confirmed in game (O17: uniqueness, the warbound flag,
-- CanUseItem, the azerite reads) are pcall'd, and a raise reads as "unknown" (nil): the answer that
-- sends the caller to its tooltip fallback.
-- ===========================================================================

-- The client function `ns[name]`, or nil when the namespace or the member is absent.
local function member(ns, name)
    if type(ns) ~= "table" then return nil end
    local fn = ns[name]
    if type(fn) ~= "function" then return nil end
    return fn
end

-- Whether this context may index `t`: present, not sealed, a table, readable. The sealed test runs
-- first, because on the client type() answers a secret's underlying type.
local function readable(t)
    local Secrets = NS.Secrets
    if t == nil or Secrets.IsSealed(t) then return false end
    return Secrets.CanAccessTable(t)
end

-- A sealed argument is refused before the client is asked: it could identify nothing.
local function sealed(v)
    return v == nil or NS.Secrets.IsSealed(v)
end

-- "bag", "inv" or nil: which shape of location `loc` is, its coordinates plain.
local function locKind(loc)
    if not readable(loc) then return nil end
    local P = NS.Secrets.PlainNumber
    if P(loc.bag) and P(loc.slot) then return "bag" end
    if P(loc.slotID) then return "inv" end
    return nil
end

-- The client's ItemLocation for `loc`, or nil.
local function itemLocation(loc)
    local kind, IL = locKind(loc), ItemLocation
    if not kind or type(IL) ~= "table" then return nil end
    if kind == "bag" then return IL:CreateFromBagAndSlot(loc.bag, loc.slot) end
    return IL:CreateFromEquipmentSlot(loc.slotID)
end

-- A pcall'd location query answered as a plain flag; nil when absent, raised, secret or no location.
local function locFlag(ns, name, loc)
    local fn = member(ns, name)
    local il = fn and itemLocation(loc)
    if not il then return nil end
    local ok, v = pcall(fn, il)
    if not ok then return nil end
    return NS.Secrets.PlainTruth(v)
end

-- Call `ns[name](...)` when it exists: true when the call was made.
local function invoke(ns, name, ...)
    local fn = member(ns, name)
    if not fn then return false end
    fn(...)
    return true
end

-- Call a bare client function when it exists: true when the call was made.
local function invokeBare(fn, ...)
    if type(fn) ~= "function" then return false end
    fn(...)
    return true
end

-- ---------------------------------------------------------------------------
-- Links, item info and slots
-- ---------------------------------------------------------------------------

--- A container slot's item link, or nil (empty, or secret: a secret link reads as an empty slot, Q12).
function Compat.ContainerItemLink(bag, slot)
    local fn = member(C_Container, "GetContainerItemLink")
    if not fn then return nil end
    return NS.Secrets.PlainString(fn(bag, slot))
end

--- The player's equipped item link in `slotID`, or nil.
function Compat.InventoryItemLink(slotID)
    if not GetInventoryItemLink then return nil end
    return NS.Secrets.PlainString(GetInventoryItemLink("player", slotID))
end

--- The player's equipped item ID in `slotID`, or nil.
function Compat.InventoryItemID(slotID)
    if not GetInventoryItemID then return nil end
    return NS.Secrets.PlainNumber(GetInventoryItemID("player", slotID))
end

--- The inventory slot ID of a slot name ("MainHandSlot"), or nil. The client raises on a bad name.
function Compat.InventorySlotID(slotName)
    if not GetInventorySlotInfo or type(slotName) ~= "string" then return nil end
    local ok, id = pcall(GetInventorySlotInfo, slotName)
    if not ok then return nil end
    return NS.Secrets.PlainNumber(id)
end

--- name, quality, level, minLevel, bindType of an item (link, ID or name), each plain or nil.
function Compat.ItemInfo(item)
    local fn = member(C_Item, "GetItemInfo")
    if not fn or sealed(item) then return nil end
    local name, _, quality, level, minLevel, _, _, _, _, _, _, _, _, bindType = fn(item)
    local S = NS.Secrets
    return S.PlainString(name), S.PlainNumber(quality), S.PlainNumber(level), S.PlainNumber(minLevel),
        S.PlainNumber(bindType)
end

--- itemID, invType ("INVTYPE_HEAD"), icon, classID, subclassID, or nil. Answered from the client's
--- static data, so it never waits on the item cache.
function Compat.ItemInfoInstant(item)
    local fn = member(C_Item, "GetItemInfoInstant")
    if not fn or sealed(item) then return nil end
    local id, _, _, invType, icon, classID, subclassID = fn(item)
    local S = NS.Secrets
    return S.PlainNumber(id), S.PlainString(invType), S.Unsecret(icon), S.PlainNumber(classID),
        S.PlainNumber(subclassID)
end

--- The item's actual item level (the first return), or nil.
function Compat.DetailedItemLevel(item)
    local fn = member(C_Item, "GetDetailedItemLevelInfo")
    if not fn or sealed(item) then return nil end
    return NS.Secrets.PlainNumber((fn(item)))
end

--- The item's stats as `{ [ITEM_MOD_*] = plain number }`, or nil. A secret key or value is dropped.
function Compat.ItemStats(item)
    local fn = member(C_Item, "GetItemStats")
    if not fn or sealed(item) then return nil end
    local raw = fn(item)
    if not readable(raw) then return nil end
    local S, out, n = NS.Secrets, {}, 0
    for k, v in pairs(raw) do
        n = n + 1
        if n > S.ITERATION_LIMIT then break end
        local key, value = S.PlainString(k), S.PlainNumber(v)
        if key and value then out[key] = value end
    end
    return out
end

--- An item ID's icon file ID, or nil.
function Compat.ItemIcon(itemID)
    local fn = member(C_Item, "GetItemIconByID")
    if not fn or sealed(itemID) then return nil end
    return NS.Secrets.Unsecret(fn(itemID))
end

--- spellName, spellID of an item's use effect, or nil (no use effect).
function Compat.ItemSpell(item)
    local fn = member(C_Item, "GetItemSpell")
    if not fn or sealed(item) then return nil end
    local name, spellID = fn(item)
    local S = NS.Secrets
    return S.PlainString(name), S.PlainNumber(spellID)
end

--- The item's bag-family bit field, or nil.
function Compat.ItemFamily(item)
    local fn = member(C_Item, "GetItemFamily")
    if not fn or sealed(item) then return nil end
    return NS.Secrets.PlainNumber(fn(item))
end

-- The upgrade-track fields the quick-slot sort reads (INV §3.11). trackString is localized, so it is
-- not copied: the sort keys on the numbers.
local UPGRADE_FIELDS = { "trackStringID", "maxItemLevel", "currentLevel", "maxLevel" }

--- `{ trackStringID, maxItemLevel, currentLevel, maxLevel }` (each plain or nil), or nil.
function Compat.ItemUpgradeInfo(item)
    local fn = member(C_Item, "GetItemUpgradeInfo")
    if not fn or sealed(item) then return nil end
    local raw = fn(item)
    if not readable(raw) then return nil end
    local out = {}
    for _, key in ipairs(UPGRADE_FIELDS) do out[key] = NS.Secrets.PlainNumber(raw[key]) end
    return out
end

-- ---------------------------------------------------------------------------
-- Cooldowns
-- ---------------------------------------------------------------------------

-- start and duration as plain numbers, enabled as a plain flag (B19: the client's 1/0 normalized).
local function cooldown(start, duration, enabled)
    local S = NS.Secrets
    return S.PlainNumber(start), S.PlainNumber(duration), S.PlainTruth(enabled)
end

--- start, duration, enabled of a container item's cooldown; a secret part reads nil.
function Compat.ContainerItemCooldown(bag, slot)
    local fn = member(C_Container, "GetContainerItemCooldown")
    if not fn then return nil end
    return cooldown(fn(bag, slot))
end

--- start, duration, enabled of an equipped item's cooldown; a secret part reads nil.
function Compat.InventoryItemCooldown(slotID)
    if not GetInventoryItemCooldown then return nil end
    return cooldown(GetInventoryItemCooldown("player", slotID))
end

-- ---------------------------------------------------------------------------
-- Binding, uniqueness, usability and azerite (O17: unconfirmed shapes, each pcall'd)
-- ---------------------------------------------------------------------------

--- `{ unique, categoryID, count }` of an item ID, or nil when the client cannot say.
function Compat.ItemUniqueness(itemID)
    local fn = member(C_Item, "GetItemUniquenessByID")
    if not fn or NS.Secrets.PlainNumber(itemID) == nil then return nil end
    local ok, isUnique, _, count, categoryID = pcall(fn, itemID)
    if not ok then return nil end
    local S = NS.Secrets
    local unique = S.PlainTruth(isUnique)
    if unique == nil then return nil end
    return { unique = unique, categoryID = S.PlainNumber(categoryID), count = S.PlainNumber(count) }
end

--- Whether the item at `loc` is bound; nil when unknown.
function Compat.IsBound(loc)
    return locFlag(C_Item, "IsBound", loc)
end

--- Whether the item at `loc` is warbound until equipped; nil when unknown.
function Compat.IsWarboundUntilEquip(loc)
    return locFlag(C_Item, "IsBoundToAccountUntilEquip", loc)
end

--- Whether the player can use an item ID; nil when unknown (the caller's red-line fallback, B14).
function Compat.CanUseItem(itemID)
    local fn = member(C_PlayerInfo, "CanUseItem")
    if not fn or NS.Secrets.PlainNumber(itemID) == nil then return nil end
    local ok, v = pcall(fn, itemID)
    if not ok then return nil end
    return NS.Secrets.PlainTruth(v)
end

--- Whether the item at `loc` can still be upgraded; nil when unknown (no item there, no API).
function Compat.CanUpgradeItem(loc)
    if not locFlag(C_Item, "DoesItemExist", loc) then return nil end
    return locFlag(C_ItemUpgrade, "CanUpgradeItem", loc)
end

-- One azerite tier's selected power IDs, appended to `out`; a secret ID is skipped.
local function selectedPowers(api, il, tier, out)
    if not readable(tier) or not readable(tier.azeritePowerIDs) then return end
    local S = NS.Secrets
    for _, raw in S.SafeIterate(tier.azeritePowerIDs) do
        local id = S.PlainNumber(raw)
        if id then
            local ok, selected = pcall(api.IsPowerSelected, il, id)
            if ok and S.PlainTruth(selected) == true then out[#out + 1] = id end
        end
    end
end

--- The sorted selected azerite power IDs of the item at `loc`, or nil off azerite gear or when the
--- client cannot say (O17: a missing or raising C_AzeriteEmpoweredItem call reads as unknown; a
--- power whose IsPowerSelected raises is left out).
function Compat.AzeritePowers(loc)
    local api = C_AzeriteEmpoweredItem
    local il = member(api, "IsAzeriteEmpoweredItem") and itemLocation(loc)
    if not il then return nil end
    local ok, isAzerite = pcall(api.IsAzeriteEmpoweredItem, il)
    if not ok or NS.Secrets.PlainTruth(isAzerite) ~= true then return nil end
    local okTiers, tiers = pcall(api.GetAllTierInfo, il)
    if not okTiers then return nil end
    local out = {}
    if not readable(tiers) then return out end
    for _, tier in NS.Secrets.SafeIterate(tiers) do selectedPowers(api, il, tier, out) end
    table.sort(out)
    return out
end

-- ---------------------------------------------------------------------------
-- Tooltip data
-- ---------------------------------------------------------------------------

-- The client's tooltip data for a location or a link, or nil.
local function tooltipData(loc)
    local api, kind = C_TooltipInfo, locKind(loc)
    local fn
    if kind == "bag" then
        fn = member(api, "GetBagItem")
        return fn and fn(loc.bag, loc.slot)
    elseif kind == "inv" then
        fn = member(api, "GetInventoryItem")
        return fn and fn("player", loc.slotID)
    end
    local link = NS.Secrets.PlainString(loc)
    fn = link and member(api, "GetHyperlink")
    return fn and fn(link)
end

-- One tooltip line as `{ text, r, g, b }`, or nil when its text cannot be read.
local function tooltipLine(line)
    if not readable(line) then return nil end
    local S = NS.Secrets
    local text = S.PlainString(line.leftText)
    if not text then return nil end
    local out, color = { text = text }, line.leftColor
    if readable(color) then
        out.r, out.g, out.b = S.PlainNumber(color.r), S.PlainNumber(color.g), S.PlainNumber(color.b)
    end
    return out
end

--- The left-hand lines of an item's tooltip (a location or a link) as `{ {text, r, g, b} }`. A line
--- whose text is secret is skipped; a secret color component reads nil. Empty when unreadable.
function Compat.TooltipLines(loc)
    local data, out = tooltipData(loc), {}
    if not readable(data) or not readable(data.lines) then return out end
    for _, raw in NS.Secrets.SafeIterate(data.lines) do
        local line = tooltipLine(raw)
        if line then out[#out + 1] = line end
    end
    return out
end

--- The unit whose inventory item `tooltip` shows ("player", "target"), or nil when it shows anything
--- else or its info cannot be read (O41: the getter field names are unconfirmed; nil fails safe).
function Compat.TooltipInventoryUnit(tooltip)
    local get = type(tooltip) == "table" and tooltip.GetPrimaryTooltipInfo
    if type(get) ~= "function" then return nil end
    local ok, info = pcall(get, tooltip)
    if not ok or not readable(info) then return nil end
    if not NS.Secrets.PlainEquals(info.getterName, "GetInventoryItem") then return nil end
    local args = info.getterArgs
    if not readable(args) then return nil end
    return NS.Secrets.PlainString(args[1])
end

-- ---------------------------------------------------------------------------
-- Pets and hooks
-- ---------------------------------------------------------------------------

-- A ceiling on one walk of the pet journal, far beyond any collection.
local PET_LIMIT = 5000

--- The summoned companion's GUID, or nil.
function Compat.SummonedPetGUID()
    local fn = member(C_PetJournal, "GetSummonedPetGUID")
    if not fn then return nil end
    return NS.Secrets.PlainString(fn())
end

-- The GUID of the first owned journal pet that `match(speciesID, speciesName)` accepts, each
-- argument plain or nil. A pet whose GUID is secret is never a handle.
local function findPet(match)
    local api, S = C_PetJournal, NS.Secrets
    local count, info = member(api, "GetNumPets"), member(api, "GetPetInfoByIndex")
    if not count or not info then return nil end
    local n = math.min(S.UnsecretNumber((count()), 0), PET_LIMIT)
    for i = 1, n do
        local guid, species, owned, _, _, _, _, name = info(i)
        guid = S.PlainString(guid)
        if guid and S.PlainTruth(owned) == true and match(S.PlainNumber(species), S.PlainString(name)) then
            return guid
        end
    end
    return nil
end

--- The GUID of the first owned pet whose SPECIES name matches `name` case-insensitively, or nil
--- (INV §3.10, Keep: a pet the player renamed is found by its species, never its custom name).
--- The compare runs here, on plain names only: a secret name is skipped, never compared.
function Compat.PetGUIDByName(name)
    local want = NS.Secrets.PlainString(name)
    if not want then return nil end
    want = want:lower()
    return findPet(function(_, species) return species ~= nil and species:lower() == want end)
end

--- The GUID of the first owned pet of `speciesID`, or nil.
function Compat.PetGUIDBySpecies(speciesID)
    local want = NS.Secrets.PlainNumber(speciesID)
    if not want then return nil end
    return findPet(function(species) return species == want end)
end

--- Summon (or, when it is out, dismiss) the pet `guid`. False without the API or a plain GUID.
function Compat.SummonPet(guid)
    local plain = NS.Secrets.PlainString(guid)
    if not plain then return false end
    return invoke(C_PetJournal, "SummonPetByGUID", plain)
end

--- Post-hook C_PetJournal.SummonPetByGUID with `fn` (the companion's summon cooldown). False when
--- there is nothing to hook. A hook cannot be removed: its body checks the stand-down itself.
function Compat.HookPetSummon(fn)
    if type(hooksecurefunc) ~= "function" or not member(C_PetJournal, "SummonPetByGUID") then return false end
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", fn)
    return true
end

--- Post-hook the client's GameTooltip_ShowCompareItem with `fn`. False without hooksecurefunc, or when
--- the client has no such function (hooksecurefunc raises on one).
function Compat.HookCompare(fn)
    if type(hooksecurefunc) ~= "function" then return false end
    return (pcall(hooksecurefunc, "GameTooltip_ShowCompareItem", fn))
end

-- ---------------------------------------------------------------------------
-- The Equipment Manager (C_EquipmentSet)
-- ---------------------------------------------------------------------------

-- The slots a set table is keyed by (INVSLOT_FIRST_EQUIPPED .. INVSLOT_LAST_EQUIPPED). A bounded
-- numeric walk: `#` is never applied, and a hole is not the end of the table.
local EQUIP_SLOT_FIRST, EQUIP_SLOT_LAST = 1, 19

-- `{ [slotID] = convert(raw) }` over a slot-keyed client table, entries converting to nil dropped.
local function slotTable(raw, convert)
    local out = {}
    if not readable(raw) then return out end
    for slot = EQUIP_SLOT_FIRST, EQUIP_SLOT_LAST do
        local v = convert(raw[slot])
        if v ~= nil then out[slot] = v end
    end
    return out
end

local function trueOrNil(v)
    return NS.Secrets.PlainTruth(v) or nil
end

--- The player's equipment set IDs, plain, in client order. Empty when there are none or the list is
--- unreadable: either way the caller takes the zero-sets path (preserve, never delete; Q8).
function Compat.EMSetIDs()
    local fn, out = member(C_EquipmentSet, "GetEquipmentSetIDs"), {}
    if not fn then return out end
    local ids = fn()
    if not readable(ids) then return out end
    for _, raw in NS.Secrets.SafeIterate(ids) do
        local id = NS.Secrets.PlainNumber(raw)
        if id then out[#out + 1] = id end
    end
    return out
end

--- `{ name, icon, setID, isEquipped }` of a set, or nil: an unknown set, or one whose name is not
--- plain (a set that cannot be matched by name is unreadable).
function Compat.EMSetInfo(setID)
    local fn = member(C_EquipmentSet, "GetEquipmentSetInfo")
    if not fn or sealed(setID) then return nil end
    local name, icon, id, isEquipped = fn(setID)
    local S = NS.Secrets
    name = S.PlainString(name)
    if not name then return nil end
    return { name = name, icon = S.Unsecret(icon), setID = S.PlainNumber(id), isEquipped = S.PlainTruth(isEquipped) }
end

--- `{ [slotID] = packed location }` of a set; a secret location is dropped.
function Compat.EMLocations(setID)
    local fn = member(C_EquipmentSet, "GetItemLocations")
    if not fn or sealed(setID) then return {} end
    return slotTable(fn(setID), NS.Secrets.PlainNumber)
end

--- `{ [slotID] = true }` for the slots a set ignores.
function Compat.EMIgnoredSlots(setID)
    local fn = member(C_EquipmentSet, "GetIgnoredSlots")
    if not fn or sealed(setID) then return {} end
    return slotTable(fn(setID), trueOrNil)
end

local LOCATION_FLAGS, LOCATION_NUMBERS = { "isPlayer", "isBank", "isBags" }, { "slot", "bag" }

--- A packed equipment location unpacked to `{ isPlayer, isBank, isBags, slot, bag }`, or nil. The
--- flyout reads the same data (`Compat.FlyoutLocationData`); the legacy unpack is retired.
function Compat.EMLocation(location)
    local fn = EquipmentManager_GetLocationData
    if type(fn) ~= "function" or sealed(location) then return nil end
    local raw = fn(location)
    if not readable(raw) then return nil end
    local S, out = NS.Secrets, {}
    for _, key in ipairs(LOCATION_FLAGS) do out[key] = S.PlainTruth(raw[key]) end
    for _, key in ipairs(LOCATION_NUMBERS) do out[key] = S.PlainNumber(raw[key]) end
    return out
end
Compat.FlyoutLocationData = Compat.EMLocation

--- Create a set from the worn gear. Each EM write answers true when the client call was made.
function Compat.EMCreateSet(name, icon) return invoke(C_EquipmentSet, "CreateEquipmentSet", name, icon) end
--- Save the worn gear into a set.
function Compat.EMSaveSet(setID, icon) return invoke(C_EquipmentSet, "SaveEquipmentSet", setID, icon) end
--- Rename a set and change its icon.
function Compat.EMModifySet(setID, name, icon) return invoke(C_EquipmentSet, "ModifyEquipmentSet", setID, name, icon) end
--- Delete a set.
function Compat.EMDeleteSet(setID) return invoke(C_EquipmentSet, "DeleteEquipmentSet", setID) end
--- Clear the ignored-slot marks the next save reads.
function Compat.EMClearIgnored() return invoke(C_EquipmentSet, "ClearIgnoredSlotsForSave") end

--- Mark (`ignore` true) or unmark a slot as ignored for the next save.
function Compat.EMIgnoreSlot(slotID, ignore)
    return invoke(C_EquipmentSet, ignore and "IgnoreSlotForSave" or "UnignoreSlotForSave", slotID)
end

--- A set's ID by name, or nil.
function Compat.EMSetID(name)
    local fn = member(C_EquipmentSet, "GetEquipmentSetID")
    if not fn or sealed(name) then return nil end
    return NS.Secrets.PlainNumber(fn(name))
end

--- How many sets the player has; 0 when unknown.
function Compat.EMNumSets()
    local fn = member(C_EquipmentSet, "GetNumEquipmentSets")
    if not fn then return 0 end
    return NS.Secrets.UnsecretNumber(fn(), 0)
end

-- The client's cap, MAX_EQUIPMENT_SETS_PER_PLAYER, has been 10 since the manager shipped.
local DEFAULT_MAX_SETS = 10

--- The most sets a player may keep.
function Compat.EMMaxSets()
    return NS.Secrets.UnsecretNumber(MAX_EQUIPMENT_SETS_PER_PLAYER, DEFAULT_MAX_SETS)
end

-- ---------------------------------------------------------------------------
-- Titles
-- ---------------------------------------------------------------------------

-- A ceiling on one walk of the title list, far beyond the client's count.
local TITLE_LIMIT = 2000

local function byTitleName(a, b)
    local la, lb = a.name:lower(), b.name:lower()
    if la ~= lb then return la < lb end
    return a.id < b.id
end

--- The player's known titles as `{ {id, name} }`, sorted case-insensitively by a plain compare (the
--- legacy sort compared raw names, INV §12). A secret or missing name is skipped.
function Compat.KnownTitles()
    local out = {}
    if not (GetNumTitles and IsTitleKnown and GetTitleName) then return out end
    local S = NS.Secrets
    local n = math.min(S.UnsecretNumber(GetNumTitles(), 0), TITLE_LIMIT)
    for i = 1, n do
        local name = S.PlainTruth(IsTitleKnown(i)) and S.PlainString(GetTitleName(i))
        if name then out[#out + 1] = { id = i, name = name } end
    end
    table.sort(out, byTitleName)
    return out
end

--- Show title `id` (-1 for none). The client wants a hardware event; the caller holds one.
function Compat.SetCurrentTitle(id) return invokeBare(SetCurrentTitle, id) end

-- ---------------------------------------------------------------------------
-- The bank
-- ---------------------------------------------------------------------------

-- A ceiling on one Enum series (BankBag_1 .. BankBag_n).
local SERIES_LIMIT = 16

-- Append index[prefix .. 1], index[prefix .. 2], ... to `out`, up to the first missing one.
local function appendSeries(out, index, prefix)
    for i = 1, SERIES_LIMIT do
        local id = NS.Secrets.PlainNumber(index[prefix .. i])
        if id == nil then return end
        out[#out + 1] = id
    end
end

--- The character bank's container IDs: the bank tabs where the client has them (11.2 on), else the
--- bank container and its bags. The warband tabs are not scanned (INV §3.4, O19).
function Compat.BankBagIDs()
    local index = type(Enum) == "table" and Enum.BagIndex
    local out = {}
    if type(index) ~= "table" then return out end
    if index.CharacterBankTab_1 ~= nil then
        appendSeries(out, index, "CharacterBankTab_")
        return out
    end
    local bank = NS.Secrets.PlainNumber(index.Bank)
    if bank then out[1] = bank end
    appendSeries(out, index, "BankBag_")
    return out
end

--- Whether a PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE type is the character banker.
function Compat.IsBankerInteraction(kind)
    local types = type(Enum) == "table" and Enum.PlayerInteractionType
    local plain = NS.Secrets.PlainNumber(kind)
    if type(types) ~= "table" or plain == nil then return false end
    return plain == types.Banker or (types.CharacterBanker ~= nil and plain == types.CharacterBanker)
end

-- ---------------------------------------------------------------------------
-- Containers and the cursor
-- ---------------------------------------------------------------------------

--- A container's slot count; 0 when unknown.
function Compat.ContainerNumSlots(bag)
    local fn = member(C_Container, "GetContainerNumSlots")
    if not fn then return 0 end
    return NS.Secrets.UnsecretNumber(fn(bag), 0)
end

--- free slots (0 when unknown) and the bag-family bit field (nil when unknown) of a container.
function Compat.ContainerNumFreeSlots(bag)
    local fn = member(C_Container, "GetContainerNumFreeSlots")
    if not fn then return 0, nil end
    local free, family = fn(bag)
    local S = NS.Secrets
    return S.UnsecretNumber(free, 0), S.PlainNumber(family)
end

--- The inventory slot a bag sits in, or nil (the backpack and the bank have none; the client raises).
function Compat.ContainerIDToInventoryID(bag)
    local fn = member(C_Container, "ContainerIDToInventoryID")
    if not fn then return nil end
    local ok, id = pcall(fn, bag)
    if not ok then return nil end
    return NS.Secrets.PlainNumber(id)
end

--- The last equipped bag's ID (the reagent bag, 5): NUM_TOTAL_EQUIPPED_BAG_SLOTS, or nil (P4.5).
function Compat.LastEquippedBagID()
    return NS.Secrets.PlainNumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS)
end

--- Pick up (or drop onto) a container slot. Each cursor write answers true when the call was made.
function Compat.PickupContainerItem(bag, slot) return invoke(C_Container, "PickupContainerItem", bag, slot) end
--- Use a container item (equip it, or move it to or from the open bank).
function Compat.UseContainerItem(bag, slot) return invoke(C_Container, "UseContainerItem", bag, slot) end
--- Show the merchant's sell cursor over a container slot.
function Compat.ShowContainerSellCursor(bag, slot) return invoke(C_Container, "ShowContainerSellCursor", bag, slot) end
--- Pick up (or drop onto) an equipment slot.
function Compat.PickupInventoryItem(slotID) return invokeBare(PickupInventoryItem, slotID) end
--- Equip the cursor's item into an equipment slot.
function Compat.EquipCursorItem(slotID) return invokeBare(EquipCursorItem, slotID) end
--- Drop whatever the cursor holds.
function Compat.ClearCursor() return invokeBare(ClearCursor) end

--- Pick up the item at `loc` (a bag slot or an equipment slot). False for a location of neither shape.
function Compat.PickupItemLocation(loc)
    local kind = locKind(loc)
    if kind == "bag" then return Compat.PickupContainerItem(loc.bag, loc.slot) end
    if kind == "inv" then return Compat.PickupInventoryItem(loc.slotID) end
    return false
end

-- ---------------------------------------------------------------------------
-- Macro icons, Pawn, dual wield and bits
-- ---------------------------------------------------------------------------

-- The icon list is long (tens of thousands of entries) but finite.
local ICON_LIMIT = 100000

--- The client's icon list for `kind` ("item" or "ability"), plain entries only. Empty for any other
--- kind, or without the API (O33).
function Compat.MacroIcons(kind)
    local fill = (kind == "item" and GetMacroItemIcons) or (kind == "ability" and GetMacroIcons) or nil
    local out = {}
    if type(fill) ~= "function" then return out end
    local raw = {}
    fill(raw)
    for _, icon in NS.Secrets.SafeIterate(raw, ICON_LIMIT) do
        local plain = NS.Secrets.Unsecret(icon)
        if plain ~= nil then out[#out + 1] = plain end
    end
    return out
end

-- Whether Pawn shows scale `name`: without the check every scale shows; a raising check hides it.
local function pawnVisible(name)
    if type(PawnIsScaleVisible) ~= "function" then return true end
    local ok, v = pcall(PawnIsScaleVisible, name)
    return ok and NS.Secrets.PlainTruth(v) == true
end

--- Pawn's visible scale names, plain and sorted. Empty without Pawn, or when it raises (H16).
function Compat.PawnVisibleScales()
    local out = {}
    if type(PawnGetAllScales) ~= "function" then return out end
    local ok, names = pcall(PawnGetAllScales)
    if not ok or not readable(names) then return out end
    for _, raw in NS.Secrets.SafeIterate(names) do
        local name = NS.Secrets.PlainString(raw)
        if name and pawnVisible(name) then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

-- Scale `scale`'s value in Pawn's item data (`Values = { {scaleName, value, ...} }`), or nil.
local function pawnScaleValue(item, scale)
    if not readable(item) or not readable(item.Values) then return nil end
    local S = NS.Secrets
    for _, entry in S.SafeIterate(item.Values) do
        if readable(entry) and S.PlainEquals(entry[1], scale) then return S.PlainNumber(entry[2]) end
    end
    return nil
end

--- Pawn's score of `link` on scale `scale`, or nil (no Pawn, a raise, an unknown scale, a secret
--- score). The caller scores nil as 0.
function Compat.PawnItemValue(link, scale)
    local S = NS.Secrets
    link, scale = S.PlainString(link), S.PlainString(scale)
    if type(PawnGetItemData) ~= "function" or not link or not scale then return nil end
    local ok, item = pcall(PawnGetItemData, link)
    if not ok then return nil end
    return pawnScaleValue(item, scale)
end

--- Whether the player can dual wield (B15). False without the API.
function Compat.CanDualWield()
    if type(CanDualWield) ~= "function" then return false end
    return NS.Secrets.PlainTruth(CanDualWield()) == true
end

--- The bitwise AND of two non-negative integers (the specialty-bag family test). Plain arithmetic, so
--- it needs no bit library; a non-number counts as no bits.
function Compat.BitAnd(a, b)
    a, b = NS.Secrets.UnsecretNumber(a, 0), NS.Secrets.UnsecretNumber(b, 0)
    local result, bitValue = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then result = result + bitValue end
        a, b, bitValue = math.floor(a / 2), math.floor(b / 2), bitValue * 2
    end
    return result
end
