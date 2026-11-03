local _, NS = ...
-- modules/Triggers_CondTrade.lua — the bespoke TRADE trigger conditions (design §6.8.1 rows 4, 11, 22, 23, 29, 32).
--
-- NS.TriggerConditions[id] for LOCKPICKING, RIDING, FALLING, RESTING, SPELLCAST and COOKING. Each is
-- a condition `fn(ctx, event, ...) -> action, delay, layer, interrupt` (design §6.3), or a table whose
-- `condition` is one; modules/Triggers.lua's Finalize reads this table at call time, so this file
-- loads before it. The other TRADE rows are families (gathering, smartUnequip) or descriptor effects
-- (FISHING) in defaults/Triggers.lua, and need nothing here.
--
-- EACH PORTS ITS LEGACY SCRIPT (OutfitterScripting.lua at 7ea3dc3, cited per condition) with the
-- design's fixes: the per-binding ticker is idempotent (ctx:StartTicker), SPELLCAST matches the
-- spellID rather than the cast GUID, COOKING summons by speciesID (O21) and records the pet it
-- replaced in ctx.persist, which the dead TRADE_SKILL_UPDATE branch never reached.
--
-- SECRETS (design §6.12): the cast's spellID, the targeting flag and the profession id are read
-- through NS.Secrets, so a secret value is never a match and never raises.
--
-- CALLS (at call time, no nil guard; design §12): NS.TriggerEffects (it loads after this file),
-- NS.Companion.

NS.TriggerConditions = NS.TriggerConditions or {}
local C = NS.TriggerConditions

local Secrets, D, L = NS.Secrets, NS.TriggerData, NS.L
local F, G = NS.TriggerFamilies, NS.TriggerGuards

local EQUIP, UNEQUIP = "equip", "unequip"   -- NS.TRIG's values (modules/Triggers.lua)
local TICK = 0.5                            -- the dynamic tickers' period (design §6.11)
local PET_DELAY = 0.2                       -- COOKING's summon and restore wait

local function plainTrue(v) return Secrets.PlainTruth(v) == true end

-- ── LOCKPICKING (OutfitterScripting.lua:461-492) ──────────────────────────────────────────────

-- The lock line: the client's own "Requires %s" with its own name for the lockpicking skill line,
-- else the localized fallback (deviation D4, O22).
local function composedLockLine()
    local fmt = Secrets.PlainString(_G.LOCKED_WITH_SPELL)
    local api = C_TradeSkillUI
    local get = api and api.GetTradeSkillDisplayName
    local name = get and Secrets.PlainString(get(D.SKILL_LINES.LOCKPICKING))
    if not (fmt and name and fmt:find("%s", 1, true)) then return nil end
    return fmt:format(name)
end

-- Whether the tooltip holds a lock line the player finds hard (orange or red).
local function hardLock()
    local composed = composedLockLine()
    if composed then
        local found, hard = F.TooltipHasLine(composed)
        if found then return hard end
    end
    local found, hard = F.TooltipHasLine(L["Requires Lockpicking"])
    return found and hard
end

--- A rogue's lockbox under the cursor: the show starts a half-second tick, because the pick spell
--- goes on the cursor after the tooltip shows; while the spell is targeting and the lock is hard the
--- outfit equips. The hide stops the tick and takes the outfit off a second later, so a cursor that
--- slips off the box for a moment keeps it.
C.LOCKPICKING = function(ctx, event)
    if event == "TOOLTIP_HIDE" then
        ctx:StopTicker()
        if ctx:DidEquip() then return UNEQUIP, 1 end
        return nil
    end
    if event == "TOOLTIP_SHOW" then
        ctx:StartTicker(TICK)
    elseif event ~= "TIMER" then
        return nil
    end
    if plainTrue(SpellIsTargeting()) and hardLock() then return EQUIP end
    return nil
end

-- ── RIDING (OutfitterScripting.lua:712-776) ───────────────────────────────────────────────────

-- The guards the MOUNT edge alone reads, so a manual wear after mounting still comes off on the
-- dismount.
local RIDING_GUARDS = { G.instance, G.bg, G.pvp }

local function ridingBlocked(ctx)
    for _, g in ipairs(RIDING_GUARDS) do
        if g(ctx) then return true end
    end
    return false
end

local function stopWaiting(ctx)
    ctx.state.waitLand, ctx.state.dismountAt = nil, nil
    ctx:StopTicker()
end

local function ridingEdge(ctx, mounted)
    if mounted then
        stopWaiting(ctx)                    -- a remount cancels a landing still awaited
        if ridingBlocked(ctx) then return nil end
        return EQUIP
    end
    if ctx.params.stayWhileFalling then
        ctx.state.waitLand, ctx.state.dismountAt = true, ctx.now
        ctx:StartTicker(TICK)
        return nil
    end
    local wait = ctx.params.unequipDelay
    return UNEQUIP, (type(wait) == "number" and wait > 0) and wait or nil
end

-- The landing a stay-while-falling dismount waits for: at least a second on, and not falling.
local function ridingTick(ctx)
    local s = ctx.state
    if not s.waitLand then
        ctx:StopTicker()
        return nil
    end
    if ctx.now < s.dismountAt + 1 or plainTrue(IsFalling()) then return nil end
    stopWaiting(ctx)
    return UNEQUIP
end

--- Mounting equips unless a guard blocks; dismounting unequips after `unequipDelay`, or, with
--- `stayWhileFalling`, once the player has landed.
C.RIDING = function(ctx, event, stateId, active)
    if event == "STATE" and stateId == "MOUNTED" then return ridingEdge(ctx, active == true) end
    if event == "TIMER" then return ridingTick(ctx) end
    return nil
end

-- ── FALLING and RESTING (OutfitterScripting.lua:1364-1391) ────────────────────────────────────

--- On every tick: falling equips four seconds on (a short drop never swaps gear); landed, the
--- trigger's own wear comes off.
C.FALLING = function(ctx)
    if plainTrue(IsFalling()) then return EQUIP, 4 end
    if ctx:DidEquip() then return UNEQUIP end
    return nil
end

--- Resting equips and leaving the rest area unequips, whoever wore the outfit.
C.RESTING = function()
    if plainTrue(IsResting()) then return EQUIP end
    return UNEQUIP
end

-- ── SPELLCAST (OutfitterScripting.lua:1597-1617) ──────────────────────────────────────────────

--- The player starting a listed spell equips (interrupting the cast with `dontWait`, so the gear is
--- on for it); any other spell unequips. The binder already filtered the unit to the player. A secret
--- spellID gives no verdict at all: it is neither the spell nor proof of another.
C.SPELLCAST = function(ctx, _, _, _, spellID)
    local id = Secrets.PlainNumber(spellID)
    if not id then return nil end
    for _, want in ipairs(ctx.params.spellIDs or {}) do
        if want == id then return EQUIP, nil, nil, ctx.params.dontWait == true end
    end
    return UNEQUIP
end

-- ── COOKING (OutfitterScripting.lua:1649-1700) ────────────────────────────────────────────────

local function cookingOpen()
    local api = C_TradeSkillUI
    local info = api and api.GetBaseProfessionInfo and api.GetBaseProfessionInfo()
    if type(info) ~= "table" or Secrets.IsSecret(info) then return false end
    return Secrets.PlainNumber(info.professionID) == D.SKILL_LINES.COOKING
end

local COOKING = {}
C.COOKING = COOKING

--- The random pick: `fn(n) -> 1..n`. A seam a suite may replace.
COOKING.random = function(n) return math.random(n) end

-- The fire pet to summon: the first enabled one, or with `randomPet` one of the enabled at random
-- (the legacy pick); nil with none enabled.
local function cookingPet(ctx)
    local enabled = {}
    for _, pet in ipairs(D.COOKING_PETS) do
        if ctx.params[pet.param] then enabled[#enabled + 1] = pet.species end
    end
    if #enabled == 0 then return nil end
    if ctx.params.randomPet then return enabled[COOKING.random(#enabled)] end
    return enabled[1]
end

local function cookingShow(ctx)
    if not cookingOpen() then return nil end
    local species = cookingPet(ctx)
    if species then
        NS.TriggerEffects.SavePet(ctx, not ctx:DidEquip())
        NS.Companion.SummonBySpecies(species, PET_DELAY)
    end
    return EQUIP
end

--- The Cooking window opening equips, and summons a cooking fire pet when one is enabled, keeping
--- the pet that was out; closing it takes the trigger's own wear off and puts that pet back (or
--- dismisses the fire pet when none was out).
COOKING.condition = function(ctx, event)
    if event == "TRADE_SKILL_SHOW" then return cookingShow(ctx) end
    if event == "TRADE_SKILL_CLOSE" and ctx:DidEquip() then
        NS.TriggerEffects.RestorePet(ctx, PET_DELAY)
        return UNEQUIP
    end
    return nil
end
