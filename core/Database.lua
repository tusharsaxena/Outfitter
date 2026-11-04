local addonName, NS = ...
-- core/Database.lua — AceDB setup, the profile callbacks, the schemaVersion migration runner (profile
-- and char walks) and the two Schema instances' resolveRoot functions.

-- The runner's target: the highest step's `to` (savedvariables-§1).
NS.SCHEMA_VERSION = 1

-- Each step is idempotent against a fresh default store. A step may declare `scope = "profile"`, run
-- once for every stored profile (`sv.profiles`), or `scope = "char"`, run once for every stored
-- character (`sv.char`). The standard names only the profile walk (savedvariables-§1); the char walk
-- exists because this addon keeps its outfits per character (H30), and a step that reshapes an
-- outfit record has to reach the characters that are not logged in.
local STEPS = {
    { to = 1, run = function() end },   -- 0 -> 1: the fresh 1.1.0 store, a no-op
}
NS.__migrationSteps = STEPS   -- test seam only

--- A profile switch, copy or reset replaces the whole profile: re-take the hold and re-decide
--- (slash-commands-§7: these callbacks are SETUP and stay live while disabled). `db.char` is never
--- touched here (H7): outfits are per character, not per profile.
--- Everything else a switch changes is each module's own reaction to PROFILE_CHANGED: the bar redraws,
--- the trigger binder re-reads auto.enabled, the window redraws its trigger marks.
function NS.OnProfileChanged(event, _db, key)
    if NS.Debug then
        NS.Debug("Set", "%s '%s'", event or "profile", key or (NS.db and NS.db:GetCurrentProfile()) or "?")
    end
    -- The first-run skin picker goes down first, then the new profile's skin (core/SkinSetup.lua).
    if NS.HideSkinPicker then NS.HideSkinPicker() end
    if NS.ApplySkinChoice then NS.ApplySkinChoice() end
    -- A reset profile starts from the defaults: its steps run again over it.
    if event == "OnProfileReset" then NS:RunMigrations() end
    if NS.SyncEnabledHold then NS.SyncEnabledHold() end
    if NS.MaybeShowSkinPicker then NS.MaybeShowSkinPicker() end
    -- Announced through core/Bus.lua (§2.3: this file is PROFILE_CHANGED's one sender).
    if NS.SendBus and NS.MSG and NS.MSG.PROFILE_CHANGED then NS.SendBus(NS.MSG.PROFILE_CHANGED, key) end
end

function NS:InitDB()
    -- The shared "Default" profile (H30): one profile every character starts on.
    NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)
    local db = NS.db
    if db.RegisterCallback then
        db.RegisterCallback(NS, "OnProfileChanged", function(event, d, key) NS.OnProfileChanged(event, d, key) end)
        db.RegisterCallback(NS, "OnProfileCopied", function(event, d, key) NS.OnProfileChanged(event, d, key) end)
        db.RegisterCallback(NS, "OnProfileReset", function(event, d) NS.OnProfileChanged(event, d) end)
    end
end

-- The tables one step walks: every stored profile, every stored character, or the whole store.
local function stepTargets(step, sv)
    if step.scope == "profile" then return sv and sv.profiles or {} end
    if step.scope == "char" then return sv and sv.char or {} end
    return nil
end

function NS:RunMigrations()
    local g, sv = NS.db.global, _G[addonName .. "DB"]
    for _, step in ipairs(STEPS) do
        if (g.schemaVersion or 0) < step.to then
            local targets = stepTargets(step, sv)
            if targets then
                for _, entry in pairs(targets) do step.run(sv, entry) end
            else
                step.run(sv)
            end
            -- The runner owns the stamp; reached only if the step returned.
            g.schemaVersion = step.to
        end
    end
end

-- ── resolveRoot (LibKa0s-Schema-1.0 v3: `function(parts, instanceId) -> root, first`) ──────────
-- One per Schema instance (§3.5). The settings instance has no outfit arm and the outfit instance
-- refuses a nil id, so a profile reset can never reach an outfit (H7).

--- NS.Schema's root: `global.*` under db.global, everything else under db.profile.
function NS.ResolveSettingsRoot(parts)
    local db = NS.db
    if not db then return nil end
    if parts[1] == "global" then return db.global, 2 end
    return db.profile, 1
end

--- NS.OutfitSchema's root: `outfit.*` under the outfit record, `trigger.*` under its triggerParams
--- (created on demand). A nil id, an unknown id or any other first segment is refused.
function NS.ResolveOutfitRoot(parts, instanceId)
    if instanceId == nil then return nil, "no outfit" end
    local db = NS.db
    local outfits = db and db.char and db.char.outfits
    local outfit = type(outfits) == "table" and outfits[instanceId] or nil
    if type(outfit) ~= "table" then return nil, "no outfit" end
    if parts[1] == "outfit" then return outfit, 2 end
    if parts[1] == "trigger" then
        if type(outfit.triggerParams) ~= "table" then outfit.triggerParams = {} end
        return outfit.triggerParams, 2
    end
    return nil, "no outfit"
end
