local _, NS = ...
-- modules/States_Zone.lua — the zone producer, its derived tables and /or zone info (design §6.5).
--
-- THE ONE ZONE SOURCE is defaults/Zones.lua's rows. What the legacy addon kept by hand in lockstep is
-- derived here at load, and nowhere else:
--
--   NS.Zones.ORDER        the row ids in row order: WEAR ORDER, so a specific outfit is worn over
--                         the generic one (cZoneSpecialIDs, Outfitter.lua:1128-1137)
--   NS.Zones.BY_MAP_ID    instance map id -> the ids it sets: the generics its kind implies, then its
--                         own row; a brawl map sets the generic battleground only
--                         (cInstanceMapIDZoneIDs)
--
-- The pseudo events are "STATE:" .. id, and the zone triggers are Triggers.Finalize's (P4.15): no
-- table for either.
--
-- IDS, NEVER NAMES (H9). The instance type gives the generics, so a map Blizzard ships tomorrow
-- still sets them; the instance map id gives the specifics. GetZoneText() is read only as a change
-- detector in the early-out, and GetInstanceInfo's name only for /or zone's report.
--
-- CALLS (at call time, no nil guard; design §12): NS.Equip.Batch around the emission; NS.States.Set,
-- whose first sighting of a state reads NS.Triggers.ForState and NS.Stack.IsWorn.

local S, Z, L = NS.States, NS.Zones, NS.L
local Perf = NS.Perf

local ZONE_DELAY = 0.01            -- the cancel-and-reschedule debounce
local EVENT_NAMES = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD" }

-- The instance type a specific row's maps report, so its generics follow from the generic rows.
local KIND_TYPE = { bg = "pvp", arena = "arena" }

-- ── the derived tables ────────────────────────────────────────────────────────────────────────

-- The generic row ids an instance type sets, in row order.
local function genericsFor(instanceType)
    local ids = {}
    for _, row in ipairs(Z.rows) do
        if row.kind == "generic" and row.instanceTypes[instanceType] then ids[#ids + 1] = row.id end
    end
    return ids
end

local function withRow(generics, id)
    local ids = {}
    for i, g in ipairs(generics) do ids[i] = g end
    ids[#ids + 1] = id
    return ids
end

local ORDER, BY_MAP_ID = {}, {}
for _, row in ipairs(Z.rows) do
    ORDER[#ORDER + 1] = row.id
    local itype = KIND_TYPE[row.kind]
    if itype then
        local generics = genericsFor(itype)
        for _, mapID in ipairs(row.mapIDs) do BY_MAP_ID[mapID] = withRow(generics, row.id) end
    end
end
for _, mapID in ipairs(Z.BRAWL_MAP_IDS) do BY_MAP_ID[mapID] = genericsFor("pvp") end
Z.ORDER, Z.BY_MAP_ID = ORDER, BY_MAP_ID

-- ── the producer ──────────────────────────────────────────────────────────────────────────────

local current = {}                 -- the ids set at the last update
local last                         -- { type, mapID, text } of the last update, or nil
local zoneActive = false
local target, timer

--- The zone ids that apply to an instance type and an instance map id: a plain set (GetCurrentZoneIDs,
--- Outfitter.lua:4983-5003). It never matches a name.
--- @param instanceType string|nil
--- @param mapID number|nil
--- @return table set
function S.CurrentIds(instanceType, mapID)
    local ids = {}
    if instanceType ~= nil then
        for _, id in ipairs(genericsFor(instanceType)) do ids[id] = true end
    end
    for _, id in ipairs(mapID ~= nil and BY_MAP_ID[mapID] or {}) do ids[id] = true end
    return ids
end

-- The instance's plain name, type and map id (GetInstanceInfo's 1st, 2nd and 8th returns).
local function readInstance()
    local name, itype, _, _, _, _, _, mapID = GetInstanceInfo()
    local Sec = NS.Secrets
    return Sec.PlainString(name), Sec.PlainString(itype), Sec.PlainNumber(mapID)
end

local function emit()
    for _, id in ipairs(ORDER) do S.Set(id, current[id] == true) end
end

-- The early-out compares the three things that can move (UpdateZone, Outfitter.lua:4929-4938):
-- Ashran and Battle for Wintergrasp each name both an outdoor zone and a battleground, so the map id
-- and type are compared, and the zone text is kept as a change detector only.
local function unchanged(itype, mapID, text)
    return last ~= nil and last.type == itype and last.mapID == mapID and last.text == text
end

--- Re-read where the player is and, when it moved, set every zone state in wear order inside one
--- Batch. Perf bucket zoneUpdate.
function S.UpdateZone()
    timer = nil
    if not zoneActive or NS.IsStoodDown() then return end
    local t0 = Perf.on and debugprofilestop()
    local _, itype, mapID = readInstance()
    local text = NS.Secrets.PlainString(GetZoneText())
    if not unchanged(itype, mapID, text) then
        last = { type = itype, mapID = mapID, text = text }
        current = S.CurrentIds(itype, mapID)
        NS.Equip.Batch(emit)
    end
    if t0 then Perf.Note("zoneUpdate", debugprofilestop() - t0) end
end

--- Schedule the update 0.01 s out, canceling the pending one. Nothing while suspended.
function S.ScheduleZoneUpdate()
    if not zoneActive or NS.IsStoodDown() then return end
    if timer then target:CancelTimer(timer) end
    timer = target:ScheduleTimer(S.UpdateZone, ZONE_DELAY)
end

local function onEvent()
    if NS.IsStoodDown() then return end
    S.ScheduleZoneUpdate()
end

-- ── the reads ─────────────────────────────────────────────────────────────────────────────────

--- Whether the player is in a battleground or an arena right now (InBattlegroundZone).
--- @return boolean
function S.InPvPInstance()
    local _, itype = readInstance()
    return itype == "pvp" or itype == "arena"
end

--- What the zone detection sees, as lines for /or zone (ShowZoneInfo, Outfitter.lua:5017-5049): the
--- instance with its map id, a missing table entry, and the zone ids in force. The equipment bracket's
--- own lines (Equip.Diagnostic) follow them in the command.
--- @return string[]
function S.ZoneInfo()
    local name, itype, mapID = readInstance()
    local lines = { L["Instance: %s (type %s, map ID %s)"]:format(tostring(name), tostring(itype), tostring(mapID)) }
    if mapID == nil or BY_MAP_ID[mapID] == nil then lines[#lines + 1] = L["This map has no entry in the zone table"] end
    local on = {}
    for _, id in ipairs(ORDER) do
        if current[id] then on[#on + 1] = id end
    end
    if #on == 0 then
        lines[#lines + 1] = L["No zone outfits apply here"]
    else
        lines[#lines + 1] = L["Zone outfits active: %s"]:format(table.concat(on, ", "))
    end
    return lines
end

-- ── lifecycle (called from NS.States.Suspend / Resume) ────────────────────────────────────────

--- Drop the zone events and the pending update, and forget where the player was.
function S.SuspendZone()
    zoneActive = false
    if target then
        target:UnregisterAllEvents()
        target:CancelAllTimers()
    end
    timer, last, current = nil, nil, {}
end

--- Register the zone events and schedule a fresh read.
function S.ResumeZone()
    if not target then
        target = LibStub("AceEvent-3.0"):Embed({})
        LibStub("AceTimer-3.0"):Embed(target)
    end
    S.SuspendZone()
    for _, event in ipairs(EVENT_NAMES) do
        NS.SafeRegisterEvent(target, event, onEvent, NS.rejectedEvents)
    end
    zoneActive = true
    S.ScheduleZoneUpdate()
end
