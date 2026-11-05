local _, NS = ...
-- settings/Schema.lua — the settings rows, the ONE write seam every path goes through, the page filter,
-- and the forward that sends an instance write to NS.OutfitSchema, over LibKa0s-Schema-1.0
-- (architecture-§5, design §3.5).
--
-- TWO SCHEMA INSTANCES. This file's runtime holds every SETTINGS row, and it is the one the Options
-- pages, the slash CLI and Reset all read, so none of them can ever reach an outfit. The instance rows
-- (`outfit.<field>`, `trigger.<TID>.<key>`) live on NS.OutfitSchema (modules/Outfits_Schema.lua, P4.6).
-- A caller never picks between them: NS.SetByPath, NS.GetSetting and NS.Schema.SetMany take an optional
-- instance id, and a non-nil id forwards there at call time.

-- NS.Schema is the settings rows array (the DpsRace shape every page file registers into). Its
-- runtime members (AllRows, FindRow, SetMany) hang off a metatable below, so `ipairs(NS.Schema)` and
-- `#NS.Schema` still see rows and nothing else.
NS.Schema = NS.Schema or {}
local ROWS = NS.Schema

-- The Minimap button row (launcher-§3). Its CLI name says SHOWN; it stores at LibDBIcon's own
-- `global.minimap.hide` through the row's get/set, and no reset ever touches it (anti-pattern #83).
NS.MINIMAP_PATH = "global.minimap.shown"
local RESET_EXEMPT = { [NS.MINIMAP_PATH] = true }

-- The answer every instance-addressed call gives while modules/Outfits_Schema.lua has not built its
-- instance (it lands in P4.6, and is built at OnInitialize).
local NO_OUTFIT_SCHEMA = "no outfit schema"

-- ── The library-absent runtime ─────────────────────────────────────────────────────────────────
-- Answers every member this file binds. Copies none of the library's logging or bulk tally: a
-- degraded write stores, reacts and announces, and that is all.
local Stub = {}

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

function Stub.SplitPath(path)
    local parts = {}
    for seg in tostring(path or ""):gmatch("[^%.]+") do parts[#parts + 1] = seg end
    return parts
end

function Stub.Read(root, path, first)
    local parts = type(path) == "table" and path or Stub.SplitPath(path)
    first = first or 1
    if type(root) ~= "table" or #parts < first then return nil end
    local node = root
    for i = first, #parts do
        if type(node) ~= "table" then return nil end
        node = node[parts[i]]
    end
    return node
end

function Stub.Write(root, path, value, first)
    local parts = type(path) == "table" and path or Stub.SplitPath(path)
    first = first or 1
    if type(root) ~= "table" or #parts < first then return end
    local node = root
    for i = first, #parts - 1 do
        if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

local function stubFind(rows, path)
    if type(path) ~= "string" then return nil end
    for _, row in ipairs(rows) do
        if type(row) == "table" and row.path == path then return row end
    end
end

local function stubStore(d, row, path, value, id)
    if type(row.set) == "function" then row.set(value) return true end
    if row.sessionOnly then return true end
    local parts = Stub.SplitPath(path)
    local root, first = d.resolveRoot(parts, id)
    if type(root) ~= "table" then return false end
    Stub.Write(root, parts, copy(value), first)
    return true
end

function Stub.New(_, d)
    local S, rows = {}, d.rows
    local through = {}
    for _, p in ipairs(d.writeThrough or {}) do through[p] = { path = p, writeThrough = true } end
    local function rowFor(path) return stubFind(rows, path) or through[path] end
    local function refusal(row, path, value, id)
        if not row then return "Setting not found: " .. tostring(path) end
        if row.validate and not row.validate(value, id) then return "Invalid value for " .. path end
    end
    function S.AllRows() return rows end
    function S.FindRow(path) return stubFind(rows, path) end
    function S.AddRows(list)
        for _, row in ipairs(list or {}) do rows[#rows + 1] = row end
        return #(list or {})
    end
    function S.Get(path, id)
        local row = stubFind(rows, path)
        if row and type(row.get) == "function" then return row.get(id) end
        if type(path) ~= "string" or (row and row.sessionOnly) then return nil end
        local parts = Stub.SplitPath(path)
        local root, first = d.resolveRoot(parts, id)
        return Stub.Read(root, parts, first)
    end
    function S.Set(path, value, id)
        local row = rowFor(path)
        local err = refusal(row, path, value, id)
        if err then return false, err end
        if not stubStore(d, row, path, value, id) then return false, "Setting has nowhere to be stored yet: " .. path end
        if row.onChange then row.onChange(value, id) end
        if d.announce then d.announce(row, path, value, id) end
        return true
    end
    -- All or nothing, as the library's: every entry is checked before the first one is stored.
    function S.SetMany(entries, opts)
        local id = type(opts) == "table" and opts.instanceId or nil
        for i, e in ipairs(entries or {}) do
            local err = refusal(rowFor(e.path), e.path, e.value, id)
            if err then return false, err, "refused", i end
        end
        for _, e in ipairs(entries or {}) do S.Set(e.path, e.value, id) end
        return true
    end
    function S.ApplyDefault(row, id)
        if type(row) ~= "table" or type(row.path) ~= "string" or row.default == nil then return false end
        if RESET_EXEMPT[row.path] then return false end
        return S.Set(row.path, copy(row.default), id)
    end
    function S.BulkBegin() end
    function S.BulkEnd() end
    function S.BulkRun(_, _, fn) fn({ profileReset = false }) end
    function S.Validate() return 0, 0, 0 end
    return S
end

local SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true) or Stub
NS.__schemaLib = SchemaLib

-- ── The runtime ────────────────────────────────────────────────────────────────────────────────
local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)

--- One formatter for the `[Set]` line and the CLI echo, so the two never disagree.
function NS.FormatSchemaValue(row, value)
    if SlashLib and SlashLib.FormatValue then return SlashLib.FormatValue(row, value) end
    return tostring(value)
end

--- The one sender of SETTINGS_CHANGED (architecture-§4, design §2.3): the write seam's tail below.
--- Profile and global paths only; an instance row's write announces OUTFIT_EDITED through
--- NS.OutfitSchema's own announce instead.
function NS.AnnounceSettingsChanged(path, value)
    NS.SendBus(NS.MSG.SETTINGS_CHANGED, path, value)
end

local S = SchemaLib:New({
    rows = ROWS,
    -- `global.<...>` paths live in the global store; everything else in the active profile. The
    -- function is core/Database.lua's, beside the outfit instance's (design §3.5).
    resolveRoot = function(parts) return NS.ResolveSettingsRoot(parts) end,
    -- The post-write tail: one bus message per stored write. Session rows (debug console, test
    -- mode) announce nothing -- nothing downstream stores or redraws from them.
    announce = function(row, path, value)
        if row.sessionOnly then return end
        NS.AnnounceSettingsChanged(path, value)
    end,
    debug        = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
    debugEnabled = function() return NS.State.debug end,
    format       = function(row, value) return NS.FormatSchemaValue(row, value) end,
    print        = function(line) NS.Print(line) end,
    resetExempt  = RESET_EXEMPT,
    -- options-ui-§1 route (a): on a load where the Master-controls composer is hollow, the host
    -- verbs that write these rows still land (`/or enable`, `/or lock`, `/or auto on`).
    writeThrough = { "enabled", "locked", "auto.enabled" },
})
NS.SchemaRuntime = S

--- The outfit instance, or nil while modules/Outfits_Schema.lua has not built it.
local function outfitSchema() return NS.OutfitSchema end

--- THE write seam. A nil `instanceId` writes a settings row; a non-nil one forwards to the outfit
--- instance (design §3.5), or answers `false, "no outfit schema"` without one.
function NS.SetByPath(path, value, instanceId)
    if instanceId == nil then return S.Set(path, value) end
    local O = outfitSchema()
    if not O then return false, NO_OUTFIT_SCHEMA end
    return O.Set(path, value, instanceId)
end

--- Several rows as one act, all or nothing. `opts.instanceId` forwards the batch the way
--- NS.SetByPath forwards one write: the trigger dialog's OK is the caller (design §3.5).
local function setMany(entries, opts)
    if type(opts) == "table" and opts.instanceId ~= nil then
        local O = outfitSchema()
        if not O then return false, NO_OUTFIT_SCHEMA end
        return O.SetMany(entries, opts)
    end
    return S.SetMany(entries, opts)
end

NS.RegisterSchemaRows = function(rows) return S.AddRows(rows) end
NS.FindSchemaRow      = S.FindRow
NS.ApplyDefault       = S.ApplyDefault
NS.Bulk               = { Begin = S.BulkBegin, End = S.BulkEnd, Run = S.BulkRun }

setmetatable(ROWS, { __index = {
    AllRows = S.AllRows,
    FindRow = S.FindRow,
    SetMany = setMany,
} })

--- A setting's current value, falling back to the shipped default when the store cannot answer yet
--- (before InitDB) so a load-time reader never sees nil for a row that has a default. A non-nil
--- `instanceId` reads the outfit instance; without one built it answers nil and the reason.
function NS.GetSetting(path, instanceId)
    if instanceId ~= nil then
        local O = outfitSchema()
        if not O then return nil, NO_OUTFIT_SCHEMA end
        return O.Get(path, instanceId)
    end
    local v = S.Get(path)
    if v ~= nil then return v end
    local row = S.FindRow(path)
    if row and row.default ~= nil then return row.default end
    local parts = SchemaLib.SplitPath(path)
    if parts[1] == "global" then return SchemaLib.Read(NS.defaults and NS.defaults.global, parts, 2) end
    return SchemaLib.Read(NS.defaults and NS.defaults.profile, parts, 1)
end

--- The rows of one page, grouped by tab in first-appearance order, then by `order`, then in
--- declaration order (table.sort is not stable, so the position is the last key).
function NS.SchemaForPage(pageKey)
    local out, groupIndex, position = {}, {}, {}
    for _, row in ipairs(ROWS) do
        if row.page == pageKey and not row.hidden then
            out[#out + 1] = row
            position[row] = #out
            local g = row.group or ""
            if groupIndex[g] == nil then groupIndex[g] = #out end
        end
    end
    table.sort(out, function(a, b)
        local ga, gb = groupIndex[a.group or ""], groupIndex[b.group or ""]
        if ga ~= gb then return ga < gb end
        local oa, ob = a.order or 0, b.order or 0
        if oa ~= ob then return oa < ob end
        return position[a] < position[b]
    end)
    return out
end

-- The page keys a settings row may name (the panel order is the TOC's: settings/General.lua first,
-- settings/Profiles.lua last). The outfit instance validates against { outfit = true } instead.
NS.VALID_PAGES = { general = true, bar = true, window = true, profiles = true }

-- The Minimap row declares no stored `shown`: it answers no root here, and its stored key
-- (`global.minimap.hide`) is checked against the defaults by the suite instead (architecture-§5).
-- Nor does a row whose own get/set is its storage: `bar.position` (settings/OutfitBar.lua) encodes
-- the named state `profile.windows.bar`, and its default is that tree's, encoded.
local function defaultsRoot(parts, row)
    if RESET_EXEMPT[row.path] or type(row.set) == "function" then return nil end
    if parts[1] == "global" then return NS.defaults and NS.defaults.global, 2 end
    return NS.defaults and NS.defaults.profile, 1
end

--- The load-time shape check: errors, resolved, missing.
function NS.ValidateSchema()
    return S.Validate({ pages = NS.VALID_PAGES, defaultsRoot = defaultsRoot })
end
