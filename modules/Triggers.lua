local _, NS = ...
-- modules/Triggers.lua — NS.Triggers: the trigger registry, the PSEUDO table and the schema rows (design §6.7).
--
-- FINALIZE (OnInitialize, between NS.BuildOutfitSchema and NS.ValidateOutfitSchema) turns the data
-- into descriptors: every defaults/Triggers.lua row, one `zone` trigger per defaults/Zones.lua row, and
-- SPEC_1..N for the player's class (retried by the reads below while the spec data is not ready). Each
-- descriptor is a COPY of its row, so the catalog is never written: BIND leaves `events` and becomes
-- `initial = true`; the params gain their defaults and, with `specDefault`, the spec toggles; and the
-- condition is resolved from the family (NS.TriggerFamilies) or from NS.TriggerConditions[id].
--
-- A BESPOKE CONDITION (the three Triggers_Cond*.lua files) is either the condition function itself or
-- a table `{ condition = fn, onWorn = fn, onRemoved = fn, onSuspend = fn }`. A row with neither a family
-- nor a bespoke entry has no condition: it is listed, but the binder refuses to bind it ("Trigger %s
-- is not available") until its condition lands.
--
-- THE SCHEMA ROWS. Every param becomes a `trigger.<TID>.<key>` row on NS.OutfitSchema (design §3.5),
-- page "outfit", group <TID>, validated and normalized by NS.TriggerParams, so the dialog's writes are
-- the typed ones and Options, Slash and Reset never see them.
--
-- PSEUDO KEYS never reach RegisterEvent (quirk 8): `T.PSEUDO` is the one translation table from a
-- descriptor's pseudo event to the NS.MSG key the binder subscribes to (H14).

local T = {}
NS.Triggers = T

local L, Compat, Secrets = NS.L, NS.Compat, NS.Secrets

--- The verdict's actions (design §6.3).
NS.TRIG = { EQUIP = "equip", UNEQUIP = "unequip", TAG = "tag" }

T.PSEUDO = {                                       -- H14: the ONE translation table, Catalog-backed
    STATE          = "STATE_CHANGED",              -- NS.MSG key; payload (stateId, isActive)
    AURAS          = "AURAS_SCANNED",
    TOOLTIP_SHOW   = "TOOLTIP_SHOWN",
    TOOLTIP_HIDE   = "TOOLTIP_HIDDEN",
    OUTFIT_WORN    = "OUTFIT_WORN",                -- payload (id, layer, byTrigger)
    OUTFIT_REMOVED = "OUTFIT_REMOVED",             -- payload (id, byTrigger)
    TIMER = false, BIND = false,                   -- binder-internal (AceTimer / bind-time), never a message
}

T.SPEC_CATEGORY = "SPEC"
local SPEC_EVENTS = { "PLAYER_ENTERING_WORLD", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "BIND" }
local ZONE_SPEC_EVENT = "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
local EMPTY = {}                                   -- ForState's answer for a state nobody subscribes to; never written

local byId, byState, sorted = {}, {}, {}
local schemaTarget                                 -- the NS.OutfitSchema instance the rows went to
local specsReady = false                           -- SPEC_1..N are built (the spec data was there)

--- Whether `name` is a pseudo event: "STATE:<id>" or a T.PSEUDO key.
--- @param name string
--- @return boolean
function T.IsPseudo(name)
    return type(name) == "string" and (name:find("^STATE:") ~= nil or T.PSEUDO[name] ~= nil)
end

-- ── building one descriptor ───────────────────────────────────────────────────────────────────

local function copyParam(p)
    local out = {}
    for k, v in pairs(p) do out[k] = v end
    if out.default == nil then out.default = NS.TriggerParams.TYPES[out.type].default end
    return out
end

local function buildParams(row)
    local out = {}
    for i, p in ipairs(row.params or {}) do out[i] = copyParam(p) end
    if row.specDefault ~= nil then
        for _, p in ipairs(NS.TriggerFamilies.SPEC_PARAMS(row.specDefault)) do out[#out + 1] = copyParam(p) end
    end
    return out
end

-- The events without BIND, whether BIND was there, and the state ids the STATE:<id> keys name.
local function splitEvents(row)
    local events, states, initial = {}, {}, false
    for _, e in ipairs(row.events or {}) do
        if e == "BIND" then
            initial = true
        else
            events[#events + 1] = e
            local sid = e:match("^STATE:(.+)$")
            if sid then states[sid] = true end
        end
    end
    return events, states, initial
end

local function wireEffects(desc)
    local names = desc.effects
    if not names then return end
    local E = NS.TriggerEffects
    desc.onWorn = desc.onWorn or function(ctx) E.Apply(ctx, names) end
    desc.onRemoved = desc.onRemoved or function(ctx) E.Restore(ctx, names) end
    desc.onSuspend = desc.onSuspend or function(ctx) E.Restore(ctx, names) end
    desc.persist = true
end

local function resolveCondition(desc)
    if desc.family then
        local factory = NS.TriggerFamilies[desc.family]
        desc.condition = factory and factory(desc.familyArgs or {}, desc) or nil
        return
    end
    local bespoke = (NS.TriggerConditions or EMPTY)[desc.id]
    if type(bespoke) == "function" then
        desc.condition = bespoke
    elseif type(bespoke) == "table" then
        desc.condition = bespoke.condition
        desc.onWorn, desc.onRemoved, desc.onSuspend = bespoke.onWorn, bespoke.onRemoved, bespoke.onSuspend
    end
end

local function debugEvents(desc)
    for _, e in ipairs(desc.events) do
        if not (T.IsPseudo(e) or e:find("^[%u_]+$")) then
            NS.Debug("Triggers", "%s: event %s is neither a pseudo key nor a game event", desc.id, e)
        end
    end
end

local function build(row)
    local desc = {}
    for k, v in pairs(row) do desc[k] = v end
    desc.events, desc.states, desc.initial = splitEvents(row)
    desc.params = buildParams(row)
    resolveCondition(desc)
    wireEffects(desc)
    debugEvents(desc)
    return desc
end

-- ── the generated rows ────────────────────────────────────────────────────────────────────────

local KIND_FORMAT = { bg = L["Battleground: %s"], arena = L["Arena: %s"] }

-- A zone row's name: its own for a generic, else the client's localized name for its first map.
local function zoneName(z)
    if z.name then return z.name end
    local get = _G.GetRealZoneText
    local mapName = get and Secrets.PlainString(get(z.mapIDs[1]))
    if not mapName or mapName == "" then mapName = z.id end
    return (KIND_FORMAT[z.kind] or "%s"):format(mapName)
end

local function zoneRow(z)
    local C = NS.TriggerCatalog
    local name = zoneName(z)
    return { id = z.id, category = "PVP", icon = C.ZONE_ICONS[z.id] or false, name = name,
             desc = C.ZONE_DESC[z.id] or L["Equips the outfit when you're in %s"]:format(name),
             events = { "STATE:" .. z.id, ZONE_SPEC_EVENT },
             family = "zone", familyArgs = { state = z.id }, specDefault = true }
end

-- SPEC_1..N named "<class>: <spec>" (InstallTalentTreeScripts). nil when the spec data is not ready.
local function specRows()
    local n = Compat.NumSpecializations()
    local classFile = Compat.PlayerClass()
    if n <= 0 or not classFile then return nil end
    local className = Compat.PlayerClassName() or classFile
    local rows = {}
    for i = 1, math.min(n, NS.TriggerFamilies.MAX_SPECS) do
        local _, specName, _, icon = Compat.GetSpecializationInfo(i)
        specName = Secrets.PlainString(specName) or L["Spec %d"]:format(i)
        rows[i] = { id = "SPEC_" .. i, category = T.SPEC_CATEGORY, class = classFile,
                    icon = Secrets.PlainNumber(icon) or false,
                    name = ("%s: %s"):format(className, specName),
                    desc = L["Equips the outfit when you switch to this specialization"],
                    events = SPEC_EVENTS, family = "spec", familyArgs = { index = i } }
    end
    return rows
end

-- ── the indexes ───────────────────────────────────────────────────────────────────────────────

local function categoryRank(category)
    for i, c in ipairs(NS.TriggerCatalog.CATEGORY_ORDER) do
        if c == category then return i end
    end
    return #NS.TriggerCatalog.CATEGORY_ORDER + 1     -- SPEC after the catalog's own
end

local function before(a, b)
    local ra, rb = categoryRank(a.category), categoryRank(b.category)
    if ra ~= rb then return ra < rb end
    local na, nb = a.name:lower(), b.name:lower()
    if na ~= nb then return na < nb end
    return a.id < b.id
end

local function reindex()
    for k in pairs(byState) do byState[k] = nil end
    for i = #sorted, 1, -1 do sorted[i] = nil end
    for _, desc in pairs(byId) do sorted[#sorted + 1] = desc end
    table.sort(sorted, before)
    for _, desc in ipairs(sorted) do
        for sid in pairs(desc.states) do
            local list = byState[sid] or {}
            byState[sid] = list
            list[#list + 1] = desc.id
        end
    end
end

local function addSpecs()
    for id in pairs(byId) do
        if id:find("^SPEC_%d+$") then byId[id] = nil end
    end
    local rows = specRows()
    for _, row in ipairs(rows or EMPTY) do byId[row.id] = build(row) end
    return rows ~= nil
end

-- The spec data arrives with the player: until it has, every read below retries the spec rows first
-- (InstallTalentTreeScripts ran at PLAYER_LOGIN). A retry registers nothing, so a stood-down addon
-- holds no event for it.
local function ensureSpecs()
    if specsReady then return end
    if addSpecs() then
        specsReady = true
        reindex()
    end
end

--- Build every descriptor, index them and hand their params to NS.OutfitSchema once (design §6.7).
--- Safe to call again: the indexes are rebuilt from the data, and the schema rows go to one instance once.
--- @return number descriptors
function T.Finalize()
    for k in pairs(byId) do byId[k] = nil end
    for _, row in ipairs(NS.TriggerCatalog.rows) do byId[row.id] = build(row) end
    for _, z in ipairs(NS.Zones.rows) do byId[z.id] = build(zoneRow(z)) end
    specsReady = addSpecs()
    reindex()
    local schema = NS.OutfitSchema
    if schema and schemaTarget ~= schema then
        schemaTarget = schema
        schema.AddRows(T.SchemaRows())
    end
    return #sorted
end

-- ── reads ─────────────────────────────────────────────────────────────────────────────────────

--- The descriptor, or nil.
--- @param id string
--- @return table|nil
function T.Get(id)
    if id == nil then return nil end
    ensureSpecs()
    return byId[id]
end

--- Every descriptor, in picker order (a fresh array).
--- @return table[]
function T.All()
    ensureSpecs()
    local out = {}
    for i, d in ipairs(sorted) do out[i] = d end
    return out
end

local function visible(desc, classFile)
    return desc.class == nil or desc.class == classFile
end

--- The descriptors of one category a player of `classFile` is offered, by lower-cased name.
--- @return table[]
function T.List(category, classFile)
    ensureSpecs()
    local out = {}
    for _, d in ipairs(sorted) do
        if d.category == category and visible(d, classFile) then out[#out + 1] = d end
    end
    return out
end

--- The categories with at least one trigger for `classFile`, in CATEGORY_ORDER, then SPEC.
--- @return string[]
function T.Categories(classFile)
    ensureSpecs()
    local out, seen = {}, {}
    for _, d in ipairs(sorted) do
        if visible(d, classFile) and not seen[d.category] then
            seen[d.category] = true
            out[#out + 1] = d.category
        end
    end
    return out
end

--- The trigger ids subscribing to STATE:<stateId>: an array, empty rather than nil (NS.States.Set
--- iterates it unguarded on a first sighting). The answer is the registry's own: read it, never write it.
--- @return string[]
function T.ForState(stateId)
    return byState[stateId] or EMPTY
end

--- A param of `desc` by key.
local function paramOf(desc, key)
    for _, p in ipairs(desc and desc.params or EMPTY) do
        if p.key == key then return p end
    end
    return nil
end

--- @return boolean ok, string|nil err
function T.ValidateParam(desc, key, value)
    local p = paramOf(desc, key)
    if not p then return false, "no param " .. tostring(key) end
    return NS.TriggerParams.Validate(p, value)
end

-- ── the schema rows (design §3.5) ─────────────────────────────────────────────────────────────

local function schemaRow(desc, p)
    local P = NS.TriggerParams
    return {
        path = "trigger." .. desc.id .. "." .. p.key, type = p.type, default = P.CopyDefault(p),
        page = "outfit", group = desc.id,
        validate = function(v) return P.Validate(p, v) end,
        normalize = function(v) return P.Normalize(p, v) end,
    }
end

--- One `trigger.<TID>.<key>` row per param of every descriptor, in picker order.
--- @return table[]
function T.SchemaRows()
    local rows = {}
    for _, desc in ipairs(sorted) do
        for _, p in ipairs(desc.params) do rows[#rows + 1] = schemaRow(desc, p) end
    end
    return rows
end
