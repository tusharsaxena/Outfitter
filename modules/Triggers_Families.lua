local _, NS = ...
-- modules/Triggers_Families.lua — NS.TriggerFamilies: the condition factories, guards and TooltipHasLine (design §6.6).
--
-- A FAMILY is a factory: `NS.TriggerFamilies[name](familyArgs, desc) -> condition`, where a condition
-- is `fn(ctx, event, ...) -> action, delay, layer, interrupt` (design §6.3). Each reproduces one of the
-- legacy script generators (OutfitterScripting.lua:217-492) or a body three presets shared, and
-- modules/Triggers.lua's Finalize resolves a catalog row's `family` through this table. A bespoke
-- trigger has no family: its condition is NS.TriggerConditions[id] (the three Triggers_Cond*.lua files).
--
-- EVENTS AS THE BINDER DELIVERS THEM (modules/Triggers_Binder.lua). A state edge arrives as
-- ("STATE", stateId, isActive); a tick as "TIMER"; the bind-time evaluation as "BIND"; this outfit's
-- own wear and removal as "OUTFIT_WORN"/"OUTFIT_REMOVED"; the tooltip edges as "TOOLTIP_SHOW"/
-- "TOOLTIP_HIDE"; a game event as its own name with its own arguments. A condition answers nil for
-- "no change", never raises on purpose, and allocates nothing per event (performance-§2).
--
-- GUARDS (NS.TriggerGuards, G): each answers true when it BLOCKS, and only when its toggle is set in the
-- binding's params, so a row without the toggle is never blocked by it.
--
-- CLIENT READS: the trigger stanza in .luacheckrc; IsInInstance and the map and tooltip reads P4.0 did
-- not declare are taken off `_G` by name until the stanza gains them. A tooltip line's fontstring is
-- found as modules/Tooltips.lua finds it (NS.Tooltips.FontString, at call time).

local F = {}
NS.TriggerFamilies = F
local G = {}
NS.TriggerGuards = G
F.GUARDS = G

local Secrets, Compat, D = NS.Secrets, NS.Compat, NS.TriggerData
local L = NS.L

local EQUIP, UNEQUIP, TAG = "equip", "unequip", "tag"   -- NS.TRIG's values (modules/Triggers.lua)
local SHAPESHIFT = "shapeshift"

-- ── guards ────────────────────────────────────────────────────────────────────────────────────

local function instanceType()
    local get = _G.IsInInstance
    if not get then return nil end
    local _, itype = get()
    return Secrets.PlainString(itype)
end

--- `disableInstance` and the player is in a party or raid instance.
function G.instance(ctx)
    if not ctx.params.disableInstance then return false end
    local itype = instanceType()
    return itype == "party" or itype == "raid"
end

--- `disableBG` and the player is in a battleground or an arena.
function G.bg(ctx)
    return ctx.params.disableBG == true and NS.States.InPvPInstance()
end

--- `disablePVP` and the player is PvP-flagged.
function G.pvp(ctx)
    return ctx.params.disablePVP == true and Secrets.PlainTruth(UnitIsPVP("player")) == true
end

--- `disableVashjir` and the best map is one of Vashj'ir's three.
function G.vashjir(ctx)
    if not ctx.params.disableVashjir then return false end
    local api = _G.C_Map
    local mapID = api and api.GetBestMapForUnit and Secrets.PlainNumber(api.GetBestMapForUnit("player"))
    for _, id in ipairs(D.VASHJIR_MAP_IDS) do
        if id == mapID then return true end
    end
    return false
end

-- The active spec, read from the client as the legacy scripts did (GetSpecialization()). Not
-- NS.PlayerState.Spec(): a binding can hear ACTIVE_PLAYER_SPECIALIZATION_CHANGED before PlayerState
-- has refreshed that cache (CallbackHandler walks its targets in next() order).
local function liveSpec()
    return Secrets.PlainNumber(Compat.GetSpecialization())
end

--- The spec toggle for the active spec is off.
function G.specOff(ctx)
    local spec = liveSpec()
    return spec ~= nil and ctx.params["spec" .. spec] == false
end

--- Alive and not in full control (stunned, feared, on a taxi): a form change then is not the player's.
function G.noControl()
    if NS.PlayerState.IsDead() then return false end
    return Secrets.PlainTruth(HasFullControl()) ~= true
end

-- The guards a `skipAll` row runs; each is a no-op without its toggle.
local SKIP_ALL = { G.instance, G.bg, G.pvp, G.vashjir }

local function anyBlocks(ctx, guards)
    for _, g in ipairs(guards) do
        if g(ctx) then return true end
    end
    return false
end

-- ── the spec toggles ──────────────────────────────────────────────────────────────────────────

F.MAX_SPECS = 4

--- spec1..spec4 with `default` (design §6.6). The label is the spec's own name at display time
--- (NS.TriggerParams.Label); spec N is hidden when the class has fewer than N specs.
--- @return table[]
function F.SPEC_PARAMS(default)
    local out = {}
    for i = 1, F.MAX_SPECS do
        out[i] = { key = "spec" .. i, type = "bool", default = default, specIndex = i,
                   label = L["Spec %d"]:format(i),
                   hidden = function() return Compat.NumSpecializations() < i end }
    end
    return out
end

-- ── the tooltip line ──────────────────────────────────────────────────────────────────────────

-- The legacy RGBToHSV (Outfitter.lua:7354-7418), kept as written: its saturation is 1 minus the
-- smallest channel, not the textbook value, and the difficulty thresholds below were tuned on it.
-- The dominant channel `v` and the other two, x before y in the legacy order: x >= y takes 1 - y as
-- the saturation and pushes the hue by x; otherwise 1 - x and y the other way.
local function dominant(v, x, y, base, sign)
    if v == 0 then return 0, 0, 0 end
    if x >= y then return v, 1 - y, base + sign * (x / v) * 60 end
    return v, 1 - x, base - sign * (y / v) * 60
end

local function hsv(r, g, b)
    if not (r and g and b) then return 0, 0, 1 end
    local v, s, h
    if r >= g and r >= b then
        v, s, h = dominant(r, g, b, 0, 1)
    elseif g >= b then
        v, s, h = dominant(g, r, b, 120, -1)
    else
        v, s, h = dominant(b, r, g, 240, 1)
    end
    if h < 0 then h = h + 360 end
    return h, s, v
end
F.__hsv = hsv   -- test seam only

-- Orange or red to the player: saturated, bright, and not green, yellow or gray.
local function difficult(fontString)
    local r, g, b = fontString:GetTextColor()
    local h, s, v = hsv(Secrets.PlainNumber(r), Secrets.PlainNumber(g), Secrets.PlainNumber(b))
    return s > 0.2 and v > 0.2 and (h < 50 or h > 150)
end

F.MAX_TOOLTIP_LINES = 30

--- Whether GameTooltip holds a line containing `text` (TooltipContainsLine, Outfitter.lua:7328-7351):
--- `found, difficult, exact, line`. A PLAIN find, so "-" and "(" match themselves (the old pattern
--- find did not), at most 30 lines, and a secret line text is no match.
--- @param text string
--- @return boolean found, boolean difficult, boolean exact, number|nil line
function F.TooltipHasLine(text)
    local tip = _G.GameTooltip
    if type(text) ~= "string" or text == "" or not tip then return false, false, false, nil end
    local count = Secrets.UnsecretNumber(tip:NumLines(), 0)
    for line = 1, math.min(count, F.MAX_TOOLTIP_LINES) do
        local fs = NS.Tooltips.FontString(tip, "Left", line)
        if not fs then break end
        local s = Secrets.PlainString(fs:GetText())
        if s and s:find(text, 1, true) then
            return true, difficult(fs), s == text, line
        end
    end
    return false, false, false, nil
end

-- ── the families ──────────────────────────────────────────────────────────────────────────────

-- Whether the family's state is on: the edge's value for a STATE event, the producer's current value
-- for any other (a spec change re-evaluates where the player stands).
local function stateOn(args, event, active)
    if event == "STATE" then return active == true end
    return NS.States.IsActive(args.state)
end

--- On -> EQUIP, off -> UNEQUIP (GenerateSimpleScript).
function F.simple(args)
    return function(_, event, _, active)
        if event ~= "STATE" then return nil end
        if stateOn(args, event, active) then return EQUIP end
        return UNEQUIP
    end
end

--- On -> EQUIP; off and this trigger equipped it -> UNEQUIP after `unequipDelay` (GenerateSmart-
--- UnequipScript). `spec`: a disabled spec unequips outright. `guards = "skipAll"`: any blocking guard
--- means no change at all.
function F.smartUnequip(args)
    return function(ctx, event, _, active)
        if args.spec and G.specOff(ctx) then return UNEQUIP end
        if args.guards == "skipAll" and anyBlocks(ctx, SKIP_ALL) then return nil end
        if stateOn(args, event, active) then return EQUIP end
        if ctx:DidEquip() then return UNEQUIP, args.unequipDelay end
        return nil
    end
end

--- A zone trigger: smartUnequip with the spec toggles (its events add the spec change, O10).
function F.zone(args)
    return F.smartUnequip({ state = args.state, spec = true })
end

local DRUID_FORM_GUARDS = { G.bg, G.pvp, G.specOff, G.noControl }

--- A druid shape (GenerateDruidShapeshiftScript): manual wear tags the shapeshift layer; entering the
--- form wears it on that layer; leaving takes it off unless it is Complete (or unequipComplete), two
--- seconds late in combat so a heal can start without the global cooldown.
function F.druidForm()
    return function(ctx, event, _, active)
        if anyBlocks(ctx, DRUID_FORM_GUARDS) then return nil end
        if event == "OUTFIT_WORN" then return TAG, nil, SHAPESHIFT end
        if event ~= "STATE" then return nil end
        if active then
            if ctx:IsWorn() then return nil end
            return EQUIP, nil, SHAPESHIFT
        end
        if ctx.params.unequipComplete or not ctx:IsComplete() then
            return UNEQUIP, NS.PlayerState.InCombat() and 2 or nil
        end
        return nil
    end
end

local DRUID_CASTER_GUARDS = { G.instance, G.bg, G.pvp, G.specOff, G.noControl }

--- Caster form (OutfitterScripting.lua:1111-1162): as a shape, but the wear waits 0.1 s so the caster
--- form a druid passes through between two shapes is canceled before it equips.
function F.druidCaster()
    return function(ctx, event, _, active)
        if anyBlocks(ctx, DRUID_CASTER_GUARDS) then return nil end
        if event == "OUTFIT_WORN" then return TAG, nil, SHAPESHIFT end
        if event ~= "STATE" then return nil end
        if active then return EQUIP, 0.1, SHAPESHIFT end
        if not ctx:IsComplete() then return UNEQUIP end
        return nil
    end
end

-- The tooltip line a gathering trigger looks for: a GlobalString when the row names one, else the
-- client's own display name for the skill line (D10), never a hardcoded name.
local function gatherText(args)
    if args.textGlobal then return Secrets.PlainString(_G[args.textGlobal]) end
    local api = C_TradeSkillUI
    local get = api and api.GetTradeSkillDisplayName
    return get and Secrets.PlainString(get(args.skillLine)) or nil
end

--- A gathering node under the cursor (GenerateGatheringScript): the skill's line, exact, below the
--- title and orange or red (or any color with ignoreDifficulty) equips; the tooltip hiding unequips a
--- second later, so a cursor that slips off the node for a moment keeps the outfit.
function F.gathering(args)
    return function(ctx, event)
        if event == "TOOLTIP_HIDE" then
            if ctx:DidEquip() then return UNEQUIP, 1 end
            return nil
        end
        if event ~= "TOOLTIP_SHOW" then return nil end
        local found, hard, exact, line = F.TooltipHasLine(gatherText(args))
        if found and exact and line > 1 and (ctx.params.ignoreDifficulty or hard) then return EQUIP end
        return nil
    end
end

-- The NPC set a vehicle quest rides: the TriggerData table, by faction for the tournament's mounts
-- (UnitFactionGroup's first return, H10).
local function npcSet(args)
    local set = D[args.npcs]
    if args.byFaction then set = set[Compat.PlayerFaction()] end
    return set or {}
end

local function inVehicle() return Secrets.PlainTruth(UnitInVehicle("player")) == true end

local function onMouseover(_, args)
    local unitType, npcID = NS.TriggerParams.ParseGUID(UnitGUID("mouseover"))
    if unitType == args.unitType and npcID and npcSet(args)[npcID] then return EQUIP end
    return nil
end

local VEHICLE_STEPS = {
    TOOLTIP_SHOW = onMouseover,
    UPDATE_MOUSEOVER_UNIT = onMouseover,
    -- The tooltip vanishes for a moment when a mount is clicked: wait a second, and remember when.
    TOOLTIP_HIDE = function(ctx)
        if not ctx:DidEquip() or inVehicle() then return nil end
        ctx.state.unequipAt = ctx.now
        return UNEQUIP, 1
    end,
    -- Boarding within 3 s of that unequip cancels it.
    UNIT_ENTERED_VEHICLE = function(ctx)
        local at = ctx.state.unequipAt
        if ctx:DidUnequip() and at and ctx.now - at < 3 then return EQUIP end
        return nil
    end,
    UNIT_EXITED_VEHICLE = function(ctx, args)
        if not ctx:DidEquip() then return nil end
        if args.regenUnequip then
            if NS.PlayerState.InCombat() then return nil end
        elseif inVehicle() then
            return nil
        end
        return UNEQUIP
    end,
    PLAYER_REGEN_ENABLED = function(ctx, args)
        if args.regenUnequip and ctx:DidEquip() and not inVehicle() then return UNEQUIP end
        return nil
    end,
}

--- A quest vehicle or mount (OutfitterScripting.lua:1376-1567, design §6.8 rows 24-26): mousing over
--- one of `npcs` (by GUID type and creature ID; a secret GUID is no match) equips, and leaving it
--- unequips. `regenUnequip` (Flame Leviathan) waits for combat to end.
function F.vehicleMount(args)
    return function(ctx, event)
        local step = VEHICLE_STEPS[event]
        if not step then return nil end
        return step(ctx, args)
    end
end

--- A specialization trigger (InstallTalentTreeScripts, OutfitterScripting.lua:1771-1803): it acts
--- only when the spec actually changed, and the half-second delay lets an artifact equip properly.
function F.spec(args)
    return function(ctx)
        local spec = liveSpec()
        if spec == ctx.state.prevSpec then return nil end
        ctx.state.prevSpec = spec
        if spec == args.index then return EQUIP, 0.5 end
        return UNEQUIP, 0.5
    end
end

--- A trigger that never changes the stack itself: its effects are the whole of it (FISHING).
function F.passive()
    return function() return nil end
end
