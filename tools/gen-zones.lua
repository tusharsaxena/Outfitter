-- tools/gen-zones.lua — diffs a wago.tools Map.db2 export against defaults/Zones.lua (design §6.5).
-- Never loaded by the client, never shipped (.pkgmeta ignores tools/).
--
--   curl -o Map.csv https://wago.tools/db2/Map/csv
--   lua tools/gen-zones.lua Map.csv [defaults/Zones.lua]
--
-- It reads every map of InstanceType 3 (battleground) or 4 (arena) from the export and reports:
--   added      a map the export has and the table does not: a new row, a new map id on an existing
--              row, or a brawl to add to BRAWL_MAP_IDS -- decided by hand, from its name
--   removed    a map the table has and the export does not
--   wrongKind  a map whose row kind disagrees with its InstanceType (an arena row is type 4; a bg row
--              and a brawl are type 3)
-- The exit status is 0 when all three are empty and 1 otherwise. The tool edits nothing: the zone
-- table is hand-kept, so a new row gets its id, its place in the wear order and its trigger reviewed.
--
-- `dofile`d (tests/test_zones.lua), it runs nothing and returns its functions.

local M = {}

local KIND_TYPE = { bg = 3, arena = 4, brawl = 3 }

--- The export's rows as arrays of fields. RFC 4180: a quoted field may hold commas, newlines and a
--- doubled quote; a CR before a row's LF is dropped. The real Map.db2 export has all three, in the
--- PvP description columns.
local function rows(text)
    local out, row, buf = {}, {}, {}
    local i, n, quoted = 1, #text, false
    local function endField() row[#row + 1] = table.concat(buf); buf = {} end
    local function endRow()
        endField()
        if not (#row == 1 and row[1] == "") then out[#out + 1] = row end
        row = {}
    end
    while i <= n do
        local c = text:sub(i, i)
        if quoted then
            if c == '"' and text:sub(i + 1, i + 1) == '"' then
                buf[#buf + 1] = '"'
                i = i + 1
            elseif c == '"' then
                quoted = false
            else
                buf[#buf + 1] = c
            end
        elseif c == '"' then
            quoted = true
        elseif c == "," then
            endField()
        elseif c == "\n" then
            endRow()
        elseif c ~= "\r" then
            buf[#buf + 1] = c
        end
        i = i + 1
    end
    if #buf > 0 or #row > 0 then endRow() end
    return out
end

--- The export as an array of records keyed by its header row.
function M.parseCSV(text)
    local all, records = rows(text), {}
    local header = all[1] or {}
    for r = 2, #all do
        local rec = {}
        for k, name in ipairs(header) do rec[name] = all[r][k] end
        records[#records + 1] = rec
    end
    return records
end

--- map id -> { kind, owner } for every map the zone table names.
local function knownMaps(zones)
    local known = {}
    for _, row in ipairs(zones.rows) do
        for _, mapID in ipairs(row.mapIDs or {}) do known[mapID] = { kind = row.kind, owner = row.id } end
    end
    for _, mapID in ipairs(zones.BRAWL_MAP_IDS or {}) do known[mapID] = { kind = "brawl", owner = "BRAWL_MAP_IDS" } end
    return known
end

local function byId(a, b) return a.id < b.id end

--- The three lists the header describes, each sorted by map id.
function M.diff(zones, records)
    local known, seen = knownMaps(zones), {}
    local d = { added = {}, removed = {}, wrongKind = {} }
    for _, rec in ipairs(records) do
        local id, itype = tonumber(rec.ID), tonumber(rec.InstanceType)
        if id and (itype == 3 or itype == 4) then
            seen[id] = true
            local k = known[id]
            if not k then
                d.added[#d.added + 1] = { id = id, instanceType = itype, name = rec.MapName_lang or "" }
            elseif KIND_TYPE[k.kind] ~= itype then
                d.wrongKind[#d.wrongKind + 1] = { id = id, instanceType = itype, owner = k.owner }
            end
        end
    end
    for id, k in pairs(known) do
        if not seen[id] then d.removed[#d.removed + 1] = { id = id, owner = k.owner } end
    end
    table.sort(d.added, byId)
    table.sort(d.removed, byId)
    table.sort(d.wrongKind, byId)
    return d
end

--- The diff as the lines a person reads.
function M.report(d)
    local out = {}
    for _, e in ipairs(d.added) do
        out[#out + 1] = ("added      %5d  InstanceType %d  %s"):format(e.id, e.instanceType, e.name)
    end
    for _, e in ipairs(d.removed) do
        out[#out + 1] = ("removed    %5d  (%s)"):format(e.id, e.owner)
    end
    for _, e in ipairs(d.wrongKind) do
        out[#out + 1] = ("wrongKind  %5d  InstanceType %d, listed under %s"):format(e.id, e.instanceType, e.owner)
    end
    if #out == 0 then out[1] = "defaults/Zones.lua matches the export: no map added, removed or moved" end
    return table.concat(out, "\n")
end

--- Loads defaults/Zones.lua outside the client: its NS gets an L that answers every key with itself,
--- and reads as Retail with every row admitted, so `rows` is the whole table (Zones.ALL) the export
--- is diffed against.
function M.loadZones(path)
    local chunk = assert(loadfile(path))
    local NS = { L = setmetatable({}, { __index = function(_, k) return k end }), CLIENT = "retail" }
    function NS.PerClient(pair) return pair and pair.retail end
    function NS.ForClientRows(list) return list end
    chunk("OutfitterReborn", NS)
    return NS.Zones
end

local function readAll(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local function main(csvPath, zonesPath)
    if not csvPath then
        io.stderr:write("usage: lua tools/gen-zones.lua Map.csv [defaults/Zones.lua]\n")
        return 2
    end
    local d = M.diff(M.loadZones(zonesPath or "defaults/Zones.lua"), M.parseCSV(readAll(csvPath)))
    print(M.report(d))
    return (#d.added + #d.removed + #d.wrongKind == 0) and 0 or 1
end

if arg and type(arg[0]) == "string" and arg[0]:match("gen%-zones%.lua$") then
    os.exit(main(arg[1], arg[2]))
end

return M
