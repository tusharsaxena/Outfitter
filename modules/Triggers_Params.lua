local _, NS = ...
-- modules/Triggers_Params.lua — NS.TriggerParams: typed trigger parameters, validate, normalize, display and capture (design §6.4).
--
-- THE NINE TYPES (H13). `NS.TriggerParams.TYPES[type] = { default, validate, normalize, display }`:
-- validate(value, param) -> ok, why refuses; normalize(value, param) -> value is what is stored (a list
-- deduped in order, a number rounded to its step, a string trimmed). Every list holds IDs, never names
-- (localization-§4): spellIDs, itemIDs, uiMapIDs, `{ npcID = n }` or `{ player = "Name-Realm" }`. The
-- one list of strings is `subzonelist`, the minimap sub-zone texts the player captured on their own
-- client (deviation D3). The Schema rows modules/Triggers.lua builds call these two functions, so a
-- stored value is always one these accept.
--
-- DISPLAY goes from ID to name, and names never flow back into logic. CAPTURE answers the value a
-- dialog button adds: the last plain cast, a player aura, the cursor's item, a worn slot's item, the
-- current map, the current sub-zone, the target, the summoned pet. Every client read leaves through
-- NS.Secrets: a secret value is never captured and never displayed.
--
-- CLIENT READS (design §1.5). The trigger stanza in .luacheckrc names what these files may touch; the
-- reads below that P4.0 did not declare are taken off `_G` by name (the QuickSlots precedent) until the
-- stanza gains them.

local P = {}
NS.TriggerParams = P

local Secrets, Compat = NS.Secrets, NS.Compat
local L = NS.L

P.MAX_LIST = 32                     -- a list holds at most this many entries
P.MAX_STRING = 64                   -- a string param's longest value

-- ── shared checks ─────────────────────────────────────────────────────────────────────────────

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function isPositiveInt(v)
    return type(v) == "number" and v > 0 and v == math.floor(v)
end

-- A plain array of at most MAX_LIST entries, each accepted by `entryOK`. Bounded: a table with a key
-- outside 1..n, or more than MAX_LIST of them, is refused before its entries are read.
local function listOK(v, entryOK)
    if type(v) ~= "table" then return false, "not a list" end
    local n = 0
    for k in pairs(v) do
        n = n + 1
        if n > P.MAX_LIST then return false, "more than " .. P.MAX_LIST .. " entries" end
        if not isPositiveInt(k) then return false, "not a list" end
    end
    for i = 1, n do
        if v[i] == nil then return false, "not a list" end
        if not entryOK(v[i]) then return false, "entry " .. i .. " is not valid" end
    end
    return true
end

-- The list deduped by `keyOf`, order kept.
local function dedupe(v, keyOf)
    local out, seen = {}, {}
    for _, e in ipairs(v) do
        local k = keyOf(e)
        if not seen[k] then
            seen[k] = true
            out[#out + 1] = e
        end
    end
    return out
end

local function same(e) return e end

-- ── unit entries ──────────────────────────────────────────────────────────────────────────────

-- Exactly one of npcID (a positive integer) or player (a non-empty string).
local function unitEntryOK(e)
    if type(e) ~= "table" then return false end
    local n = 0
    for _ in pairs(e) do n = n + 1 end
    if n ~= 1 then return false end
    if e.npcID ~= nil then return isPositiveInt(e.npcID) end
    return type(e.player) == "string" and trim(e.player) ~= ""
end

local function unitKey(e)
    if e.npcID then return "npc:" .. e.npcID end
    return "player:" .. e.player
end

local function copyUnit(e)
    if e.npcID then return { npcID = e.npcID } end
    return { player = trim(e.player) }
end

-- ── display ───────────────────────────────────────────────────────────────────────────────────

-- A plain name from a client lookup, or the fallback (the ID, until an async name resolves).
local function nameOr(name, fallback)
    local plain = Secrets.PlainString(name)
    if plain and plain ~= "" then return plain end
    return fallback
end

local function mapName(id)
    local api = _G.C_Map
    local info = api and api.GetMapInfo and api.GetMapInfo(id)
    return nameOr(type(info) == "table" and info.name or nil, tostring(id))
end

local function spellName(id)
    local api = _G.C_Spell
    return nameOr(api and api.GetSpellName and api.GetSpellName(id), tostring(id))
end

local function itemName(id)
    local api = _G.C_Item
    return nameOr(api and api.GetItemNameByID and api.GetItemNameByID(id), tostring(id))
end

local function petName(guid)
    local api = _G.C_PetJournal
    if not (api and api.GetPetInfoByPetID) then return guid end
    local _, customName, _, _, _, _, _, name = api.GetPetInfoByPetID(guid)
    return nameOr(customName, nameOr(name, guid))
end

local function unitName(e)
    if e.npcID then return L["NPC %d"]:format(e.npcID) end
    return e.player
end

local function joined(v, nameOf)
    local out = {}
    for i, e in ipairs(v or {}) do out[i] = nameOf(e) end
    return table.concat(out, ", ")
end

-- ── the types ─────────────────────────────────────────────────────────────────────────────────

local function list(entryOK, keyOf, copyOf, nameOf)
    return {
        default   = {},
        validate  = function(v) return listOK(v, entryOK) end,
        normalize = function(v)
            local out = dedupe(v, keyOf)
            for i, e in ipairs(out) do out[i] = copyOf(e) end
            return out
        end,
        display   = function(v) return joined(v, nameOf) end,
    }
end

local function nonEmptyString(e) return type(e) == "string" and trim(e) ~= "" and #trim(e) <= P.MAX_STRING end

P.TYPES = {
    bool = {
        default   = false,
        validate  = function(v) return type(v) == "boolean" end,
        normalize = same,
        display   = function(v) return v and L["On"] or L["Off"] end,
    },
    number = {
        default   = 0,
        validate  = function(v, p)
            if type(v) ~= "number" or v ~= v then return false, "not a number" end
            if p and p.min and v < p.min then return false, "below " .. p.min end
            if p and p.max and v > p.max then return false, "above " .. p.max end
            return true
        end,
        normalize = function(v, p)
            local step = p and p.step
            if not step or step <= 0 then return v end
            local base = p.min or 0
            return base + math.floor((v - base) / step + 0.5) * step
        end,
        display   = function(v) return tostring(v) end,
    },
    string = {
        default   = "",
        validate  = function(v)
            if type(v) ~= "string" then return false, "not a string" end
            if #trim(v) > P.MAX_STRING then return false, "longer than " .. P.MAX_STRING end
            return true
        end,
        normalize = trim,
        display   = function(v) return v end,
    },
    spelllist   = list(isPositiveInt, same, same, spellName),
    itemlist    = list(isPositiveInt, same, same, itemName),
    maplist     = list(isPositiveInt, same, same, mapName),
    subzonelist = list(nonEmptyString, trim, trim, same),
    unitlist    = list(unitEntryOK, unitKey, copyUnit, unitName),
    pet = {
        default   = "",
        validate  = function(v)
            if type(v) ~= "string" then return false, "not a pet" end
            return v == "" or v:find("^BattlePet%-") ~= nil, "not a pet"
        end,
        normalize = same,
        display   = function(v) if v == "" then return L["None"] end return petName(v) end,
    },
}

--- A stored value against its param: the type's validate, with the param's bounds.
--- @return boolean ok, string|nil why
function P.Validate(param, value)
    local t = P.TYPES[param.type]
    if not t then return false, "unknown type " .. tostring(param.type) end
    return t.validate(value, param)
end

--- The value to store for `value` (already validated).
function P.Normalize(param, value)
    return P.TYPES[param.type].normalize(value, param)
end

--- A param's value as the dialog shows it.
--- @return string
function P.Display(param, value)
    local t = P.TYPES[param.type]
    if not t or value == nil then return "" end
    return t.display(value, param)
end

--- A copy of a param's default (a list default is never shared between outfits).
function P.CopyDefault(param)
    local d = param.default
    if type(d) ~= "table" then return d end
    local out = {}
    for i, e in ipairs(d) do out[i] = e end
    return out
end

--- The params a binding runs on (design §6.3 `ctx.params`): each stored value the type accepts, else
--- the DESCRIPTOR's default (INV §9.8's fix: the type's default never shadows the descriptor's).
--- @param desc table  the finalized descriptor
--- @param stored table|nil  outfit.triggerParams[desc.id]
--- @return table
function P.Resolve(desc, stored)
    local out = {}
    for _, p in ipairs(desc.params or {}) do
        local v = stored and stored[p.key]
        if v == nil or not P.Validate(p, v) then v = P.CopyDefault(p) end
        out[p.key] = v
    end
    return out
end

--- A param's label for display: a spec toggle reads the spec's own name (GetSpecializationInfo's 2nd
--- return, display only), every other param its localized label.
--- @return string
function P.Label(param)
    if param.specIndex then
        local _, name = Compat.GetSpecializationInfo(param.specIndex)
        return nameOr(name, param.label)
    end
    return param.label
end

-- ── GUIDs ─────────────────────────────────────────────────────────────────────────────────────

--- A plain unit GUID's type and creature ID: "Vehicle-0-3767-571-11063-33790-0000..." answers
--- "Vehicle", 33790. A player GUID answers "Player", nil; anything else nil.
--- @return string|nil unitType, number|nil npcID
function P.ParseGUID(guid)
    guid = Secrets.PlainString(guid)
    if not guid then return nil end
    local unitType = guid:match("^(%a+)%-")
    if not unitType then return nil end
    local npcID = guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    return unitType, tonumber(npcID)
end

-- ── capture (the dialog's buttons) ────────────────────────────────────────────────────────────

--- The spell ID of the player's last plain successful cast.
function P.CaptureLastCast()
    return Secrets.PlainNumber(NS.PlayerState.LastCastSpellID())
end

--- The spell ID of the player's `index`th helpful aura. Nothing while an add-on restriction is active:
--- the aura getters raise then (INV §8.1).
function P.CapturePlayerAura(index)
    local api = _G.C_UnitAuras
    if not (api and api.GetAuraDataByIndex) or NS.States.AuraRestricted() then return nil end
    local aura = api.GetAuraDataByIndex("player", index, "HELPFUL")
    if Secrets.IsSecret(aura) or type(aura) ~= "table" then return nil end
    return Secrets.PlainNumber(aura.spellId)
end

--- The item ID on the cursor.
function P.CaptureCursorItem()
    local get = _G.GetCursorInfo
    if not get then return nil end
    local kind, itemID = get()
    if Secrets.PlainString(kind) ~= "item" then return nil end
    return Secrets.PlainNumber(itemID)
end

--- The item ID worn in `slotName` ("Trinket0Slot").
function P.CaptureSlotItem(slotName)
    local slotID = Compat.InventorySlotID(slotName)
    if not slotID then return nil end
    return Secrets.PlainNumber(Compat.InventoryItemID(slotID))
end

--- The player's best uiMapID.
function P.CaptureCurrentMap()
    local api = _G.C_Map
    if not (api and api.GetBestMapForUnit) then return nil end
    return Secrets.PlainNumber(api.GetBestMapForUnit("player"))
end

--- The minimap's sub-zone text, on this client (D3).
function P.CaptureCurrentSubzone()
    local get = _G.GetMinimapZoneText
    local text = get and Secrets.PlainString(get())
    if not text or trim(text) == "" then return nil end
    return trim(text)
end

-- A player target's full name: "Name-Realm", the realm normalized when the target is on ours. With
-- regional names (WoW Forever) a character is "First Surname" and has no realm (client-quirks-§5).
local function playerEntry()
    local name, realm = Compat.UnitCharacterName("target")
    if not name or name == "" then return nil end
    if Compat.RegionalNames() then return { player = name } end
    if not realm or realm == "" then
        local own = _G.GetNormalizedRealmName
        realm = own and Secrets.PlainString(own())
    end
    if realm and realm ~= "" then return { player = name .. "-" .. realm } end
    return { player = name }
end

--- The target as a unitlist entry: `{ npcID = n }` for a creature or vehicle, `{ player = ... }` for a
--- player, nil for no target or a secret GUID.
function P.CaptureTarget()
    local unitType, npcID = P.ParseGUID(UnitGUID("target"))
    if unitType == "Player" then return playerEntry() end
    if npcID then return { npcID = npcID } end
    return nil
end

--- The summoned battle pet's GUID, or "".
function P.CaptureSummonedPet()
    return Secrets.PlainString(Compat.SummonedPetGUID()) or ""
end
