local _, NS = ...
-- modules/Triggers_Effects.lua — the triggers' save-and-restore side effects: auto-loot, tracking, click-to-move, bar page, pets.
--
-- NS.TriggerEffects (design §6.2). Each effect changes one thing on the client while an outfit is worn
-- and puts it back afterwards (the Fishing and Rogue Stealth scripts, OutfitterScripting.lua:160-207,
-- 813-884). What it changed is RECORDED in `ctx.persist[<effect>]` (the outfit's triggerState, named
-- non-setting state, design §3.4), so the restore puts back exactly what was there, survives a
-- /reload, and runs only when an apply really happened. The legacy kept that record in the settings
-- the dialog wiped (INV §9.8).
--
--   NS.TriggerEffects.Apply(ctx, names)     each named effect whose param is on, not applied twice
--   NS.TriggerEffects.Restore(ctx, names)   each named effect with a record, whatever its param says now
--   NS.TriggerEffects.SavePet(ctx) / RestorePet(ctx)   COOKING's summoned pet (Triggers_CondTrade.lua)
--
-- A catalog row lists its effects in `effects`; Finalize wires Apply to the outfit's own OUTFIT_WORN
-- and Restore to its OUTFIT_REMOVED and to the stand-down (`onSuspend`).
--
-- PROTECTED: ChangeActionBarPage may be refused in combat (O23), so the page change goes through
-- NS.SecureQueue: it runs now out of lockdown, and when combat ends otherwise.

local E = {}
NS.TriggerEffects = E

local Secrets, Compat, D = NS.Secrets, NS.Compat, NS.TriggerData

-- ── tracking (C_Minimap, O5) ──────────────────────────────────────────────────────────────────

-- The tracking index of Find Fish: matched by spellID, else by its texture, and whether it is on.
local function findFishIndex()
    local api = C_Minimap
    if not (api and api.GetNumTrackingTypes and api.GetTrackingInfo) then return nil end
    local n = Secrets.UnsecretNumber(api.GetNumTrackingTypes(), 0)
    for i = 1, n do
        local info = api.GetTrackingInfo(i)
        if type(info) == "table" and not Secrets.IsSecret(info) then
            local spell, texture = Secrets.PlainNumber(info.spellID), Secrets.PlainNumber(info.texture)
            if spell == D.FIND_FISH.spell or texture == D.FIND_FISH.texture then
                return i, Secrets.PlainTruth(info.active) == true
            end
        end
    end
    return nil
end

local function setTracking(on)
    local index, active = findFishIndex()
    if index and active ~= on then C_Minimap.SetTracking(index, on) end
    return index ~= nil
end

-- ── the action bar page ───────────────────────────────────────────────────────────────────────

local PAGE_KEY = "triggerActionBarPage"

local function setPage(page)
    if type(page) ~= "number" then return end
    NS.SecureQueue.Run(PAGE_KEY, function() ChangeActionBarPage(page) end)
end

local function currentPage()
    local get = _G.GetActionBarPage
    return get and Secrets.PlainNumber(get()) or nil
end

-- ── the effects: { param, apply(ctx) -> record|nil, restore(ctx, record) } ────────────────────

E.EFFECTS = {
    AutoLoot = {
        param = "autoLoot",
        apply = function()
            local saved = Compat.GetCVar("autoLootDefault")
            Compat.SetCVar("autoLootDefault", "1")
            return { saved = saved }
        end,
        restore = function(_, rec) Compat.SetCVar("autoLootDefault", rec.saved) end,
    },
    FishTracking = {
        param = "trackFish",
        apply = function()
            local _, active = findFishIndex()
            if not setTracking(true) then return nil end
            return { saved = active == true }
        end,
        restore = function(_, rec) setTracking(rec.saved == true) end,
    },
    ClickToMove = {
        param = "disableClickToMove",
        apply = function()
            local saved = Compat.GetCVar("autoInteract")
            Compat.SetCVar("autoInteract", "0")
            return { saved = saved }
        end,
        restore = function(_, rec) Compat.SetCVar("autoInteract", rec.saved) end,
    },
    ActionBarPage = {
        param = "changeActionBar",
        apply = function(ctx)
            local saved = currentPage()
            setPage(ctx.params.actionBarPage)
            return { saved = saved }
        end,
        restore = function(_, rec) setPage(rec.saved) end,
    },
}

local function persistOf(ctx)
    local p = ctx.persist
    if type(p) ~= "table" then return nil end
    return p
end

--- Apply each named effect whose param is on in `ctx.params`; one already recorded is left alone.
--- @param ctx table  the binding's context
--- @param names string[]
--- @return number applied
function E.Apply(ctx, names)
    local persist, n = persistOf(ctx), 0
    if not persist then return 0 end
    for _, name in ipairs(names or {}) do
        local fx = E.EFFECTS[name]
        if fx and ctx.params[fx.param] and persist[name] == nil then
            persist[name] = fx.apply(ctx) or nil
            if persist[name] then n = n + 1 end
        end
    end
    return n
end

--- Restore each named effect that has a record, then drop the record.
--- @return number restored
function E.Restore(ctx, names)
    local persist, n = persistOf(ctx), 0
    if not persist then return 0 end
    for _, name in ipairs(names or {}) do
        local fx, rec = E.EFFECTS[name], persist[name]
        if fx and rec then
            persist[name] = nil
            fx.restore(ctx, rec)
            n = n + 1
        end
    end
    return n
end

-- ── the summoned pet (COOKING) ────────────────────────────────────────────────────────────────

--- Remember the summoned pet ("" for none), once per wear.
function E.SavePet(ctx)
    local persist = persistOf(ctx)
    if not persist or persist.pet then return false end
    persist.pet = { saved = Secrets.PlainString(Compat.SummonedPetGUID()) or "" }
    return true
end

--- Put the remembered pet back, or dismiss the one summoned since when there was none.
function E.RestorePet(ctx, delay)
    local persist = persistOf(ctx)
    local rec = persist and persist.pet
    if not rec then return false end
    persist.pet = nil
    if rec.saved ~= "" then return NS.Companion.SummonByGUID(rec.saved, delay) end
    local now = Secrets.PlainString(Compat.SummonedPetGUID())
    if now then return NS.Companion.DismissByGUID(now, delay) end
    return true
end
