local _, NS = ...
-- modules/Outfits_Schema.lua — NS.OutfitSchema: the instance rows, `outfit.*` and (from P4.15)
-- `trigger.<TID>.*`, on a Schema instance of their own (design §3.5).
--
-- TWO SCHEMA INSTANCES (LibKa0s-Schema-1.0 v3 `lib:New` is one runtime for one host, and a host may
-- hold more than one). NS.Schema (settings/Schema.lua) holds every settings row and is the one the
-- Options pages, the slash CLI and Reset read; this one holds the per-outfit rows only, so none of
-- those can ever show or reset an outfit, with no filter to forget. NS.SetByPath, NS.GetSetting and
-- NS.Schema.SetMany forward here at call time whenever they are given an instance id.
--
-- BUILT AT OnInitialize (core/OutfitterReborn.lua), not at file scope: the library-or-stub it is
-- built on is settings/Schema.lua's NS.__schemaLib, and settings/ loads after modules/. On a
-- library-absent load that is the same degradation stub NS.Schema runs on (BP §9.1).
--
-- THE ANNOUNCE sends no SETTINGS_CHANGED. It calls NS.Outfits.Changed(id, what), so OUTFIT_EDITED is
-- the one per-outfit message (C12) and the trigger binder has one rebind route (design §6.9).
--
-- NO LABELS. No panel draws these rows: the outfit and trigger dialogs (P4.21) label their own fields,
-- and Options and Slash never see this instance.

-- The value types the outfit rows and the trigger params take (Validate's `types` replaces the
-- library's default set, so the four widget types are named again).
local TYPES = { bool = true, number = true, string = true, color = true,
                spelllist = true, itemlist = true, maplist = true, subzonelist = true, unitlist = true, pet = true }
local PAGES = { outfit = true }

-- The wildcard question-mark icon: choosing it means "Outfitter chooses" (INV §7.6).
local WILDCARD_ICON = 134400

local function isBool(v) return type(v) == "boolean" end

local function validTrigger(v)
    if type(v) ~= "string" then return false end
    return v == "" or NS.Triggers.Get(v) ~= nil
end

-- An outfit's icon (sheet and window feedback plan Task 3.5): none, a game icon's fileID, or a glyph
-- path NS.Glyph (the LibKa0s-IconBrowser seam) reads back to a catalog name. 1.1.0 stored numbers only.
local function validIcon(v)
    if v == nil then return true end
    if type(v) == "number" then return v > 0 and v == math.floor(v) end
    return NS.Glyph.IsGlyph(v) ~= nil
end

-- A glyph's color: none (white), or six lowercase hex digits.
local function validColor(v) return NS.Glyph.ValidColor(v) end

local function record(id) return NS.Outfits.Get(id) end

-- A trigger flag's reaction: an outfit with no trigger cannot be disabled (design §3.3), so a flag
-- written onto one (the write created `trigger = { disabled = ... }` with no id) goes with its table.
-- An onChange, not a validate: a batch that sets the trigger id and a flag together validates both
-- before either is stored, and its reactions run after every store (Schema v2 SetMany phase 3).
local function dropIdlessTrigger(_, id)
    local rec = record(id)
    if rec and type(rec.trigger) == "table" and not rec.trigger.id then rec.trigger = nil end
end

-- The six outfit rows (design §3.5; `outfit.iconColor` from the sheet and window feedback round).
-- Every row carries page "outfit" and group "outfit" (anti-patterns #69); a trigger's params arrive
-- with group = <TID> from NS.Triggers.Finalize.
local ROWS = {
    { path = "outfit.trigger.id", type = "string", default = "", page = "outfit", group = "outfit",
      validate = validTrigger,
      -- "" is no trigger, and no trigger is no trigger table: its flags go with it.
      onChange = function(v, id)
          local rec = record(id)
          if v == "" and rec then rec.trigger = nil end
      end },
    { path = "outfit.trigger.disabled", type = "bool", default = false, page = "outfit", group = "outfit",
      validate = isBool, onChange = dropIdlessTrigger },
    { path = "outfit.trigger.combatDisabled", type = "bool", default = false, page = "outfit", group = "outfit",
      validate = isBool, onChange = dropIdlessTrigger },
    { path = "outfit.icon", type = "number", page = "outfit", group = "outfit",
      validate = validIcon,
      -- 134400 is "Outfitter chooses": stored as none. Only a glyph takes a color, so any other icon
      -- drops the one a glyph left (after every store of a batch, so a glyph and its color together keep it).
      onChange = function(v, id)
          local rec = record(id)
          if not rec then return end
          if v == WILDCARD_ICON then rec.icon = nil end
          if not NS.Glyph.IsGlyph(rec.icon) then rec.iconColor = nil end
      end },
    { path = "outfit.iconColor", type = "string", page = "outfit", group = "outfit",
      validate = validColor },
    { path = "outfit.bar.hide", type = "bool", default = false, page = "outfit", group = "outfit",
      validate = isBool },
}

--- What an instance-row write changed, for OUTFIT_EDITED: "trigger" for a trigger param, else the
--- outfit field (`outfit.icon` and `outfit.iconColor` -> "icon", `outfit.trigger.id` -> "trigger",
--- `outfit.bar.hide` -> "bar").
local function whatOf(path)
    local first, second = path:match("^([^%.]+)%.([^%.]+)")
    if first == "trigger" then return "trigger" end
    if second == "iconColor" then return "icon" end
    return second
end

--- Build NS.OutfitSchema on settings/Schema.lua's library-or-stub. Called once, from OnInitialize.
--- @return table
function NS.BuildOutfitSchema()
    NS.OutfitSchema = NS.__schemaLib:New({
        rows         = ROWS,
        resolveRoot  = function(parts, instanceId) return NS.ResolveOutfitRoot(parts, instanceId) end,
        announce     = function(_, path, _, instanceId) NS.Outfits.Changed(instanceId, whatOf(path)) end,
        debug        = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
        debugEnabled = function() return NS.State.debug end,
        format       = function(row, value) return NS.FormatSchemaValue(row, value) end,
        print        = function(line) NS.Print(line) end,
    })
    return NS.OutfitSchema
end

--- The outfit instance's load-time shape check: errors, resolved, missing. NS.Triggers.Finalize
--- (P4.15) adds its rows first, so this runs after it in OnInitialize.
function NS.ValidateOutfitSchema()
    return NS.OutfitSchema.Validate({ pages = PAGES, types = TYPES })
end
