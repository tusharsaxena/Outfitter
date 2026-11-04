local _, NS = ...
-- defaults/Zones.lua — NS.Zones.rows and BRAWL_MAP_IDS: the single zone source (design §6.5, INV §8.2).
--
-- This one table replaces the five the legacy addon had to keep in lockstep (cInstanceMapIDZoneIDs,
-- cZoneSpecialIDs, cSpecialIDEvents, BuiltinEvents and the zone PresetScripts). Everything they held
-- is derived from the rows at load (modules/States_Zone.lua) and by Triggers.Finalize, so adding a
-- battleground or an arena is one row here and nothing else.
--
-- ORDER IS WEAR ORDER: later rows are worn over earlier ones (the cZoneSpecialIDs note,
-- Outfitter.lua:1128-1137), so the two generics come first and a map-specific outfit beats them.
-- mapIDs are Map.db2 row IDs (the 8th return of GetInstanceInfo), InstanceType 3 (bg) / 4 (arena).
-- Regenerate with tools/gen-zones.lua against a wago.tools export; NEVER from memory.
-- Last confirmed 2026-11-03 against https://wago.tools/db2/Map: every InstanceType 3 and 4 map is
-- below, and no map below is gone.
--
-- A generic row matches by instance type, so a map Blizzard ships tomorrow still sets it. A specific
-- row has no name: Triggers.Finalize names it GetRealZoneText(mapIDs[1]), the client's own localized
-- name for that map.

local L = NS.L

NS.Zones = NS.Zones or {}                            -- architecture-§3 idempotent
local Z = NS.Zones

Z.rows = {
    { id = "PVP_BATTLEGROUND", kind = "generic", instanceTypes = { pvp = true, arena = true }, name = L["Battleground"] },
    { id = "PVP_ARENA",        kind = "generic", instanceTypes = { arena = true },             name = L["Arena"] },

    -- Battlegrounds
    { id = "BG_AV",          kind = "bg", mapIDs = { 30, 2197 } },             -- Alterac Valley, Korrak's Revenge
    { id = "BG_AB",          kind = "bg", mapIDs = { 529, 1681, 2107, 2177 } }, -- Classic, Winter, current, Comp Stomp
    { id = "BG_WSG",         kind = "bg", mapIDs = { 489, 2106 } },            -- Classic, current
    { id = "BG_EOTS",        kind = "bg", mapIDs = { 566, 968 } },             -- Eye of the Storm, Rated
    { id = "BG_SOTA",        kind = "bg", mapIDs = { 607 } },                  -- Strand of the Ancients
    { id = "BG_IOC",         kind = "bg", mapIDs = { 628 } },                  -- Isle of Conquest
    { id = "BG_TWINPEAKS",   kind = "bg", mapIDs = { 726 } },                  -- Twin Peaks
    { id = "BG_GILNEAS",     kind = "bg", mapIDs = { 761 } },                  -- The Battle for Gilneas
    { id = "BG_WINTERGRASP", kind = "bg", mapIDs = { 2118 } },                 -- Battle for Wintergrasp (epic)
    { id = "BG_SILVERSHARD", kind = "bg", mapIDs = { 727 } },                  -- Silvershard Mines
    { id = "BG_KOTMOGU",     kind = "bg", mapIDs = { 998 } },                  -- Temple of Kotmogu
    { id = "BG_DEEPWIND",    kind = "bg", mapIDs = { 1105, 2245 } },           -- Deepwind Gorge (Legacy), current
    { id = "BG_SEETHING",    kind = "bg", mapIDs = { 1803 } },                 -- Seething Shore
    { id = "BG_DEEPHAUL",    kind = "bg", mapIDs = { 2656 } },                 -- Deephaul Ravine
    { id = "BG_ASHRAN",      kind = "bg", mapIDs = { 1191 } },                 -- Ashran

    -- Arenas: each also sets both generics
    { id = "ARENA_LORDAERON",     kind = "arena", mapIDs = { 572 } },          -- Ruins of Lordaeron
    { id = "ARENA_SEWERS",        kind = "arena", mapIDs = { 617 } },          -- Dalaran Sewers
    { id = "ARENA_BLADESEDGE",    kind = "arena", mapIDs = { 562, 1672 } },    -- Blade's Edge, old and current
    { id = "ARENA_NAGRAND",       kind = "arena", mapIDs = { 559, 1505 } },    -- Nagrand, old and current
    { id = "ARENA_TOLVIRON",      kind = "arena", mapIDs = { 980 } },          -- Tol'Viron
    { id = "ARENA_TIGERSPEAK",    kind = "arena", mapIDs = { 1134 } },         -- The Tiger's Peak
    { id = "ARENA_BLACKROOK",     kind = "arena", mapIDs = { 1504 } },         -- Black Rook Hold
    { id = "ARENA_ASHAMANE",      kind = "arena", mapIDs = { 1552 } },         -- Ashamane's Fall
    { id = "ARENA_HOOKPOINT",     kind = "arena", mapIDs = { 1825 } },         -- Hook Point
    { id = "ARENA_MUGAMBALA",     kind = "arena", mapIDs = { 1911 } },         -- Mugambala
    { id = "ARENA_ROBODROME",     kind = "arena", mapIDs = { 2167 } },         -- The Robodrome
    { id = "ARENA_EMPYREAN",      kind = "arena", mapIDs = { 2373 } },         -- Empyrean Domain
    { id = "ARENA_MALDRAXXUS",    kind = "arena", mapIDs = { 2509 } },         -- Maldraxxus Coliseum
    { id = "ARENA_ENIGMA",        kind = "arena", mapIDs = { 2547 } },         -- Enigma Crucible
    { id = "ARENA_NOKHUDON",      kind = "arena", mapIDs = { 2563 } },         -- Nokhudon Proving Grounds
    { id = "ARENA_CAGEOFCARNAGE", kind = "arena", mapIDs = { 2759 } },         -- Cage of Carnage
}

-- Brawls (InstanceType 3) set the generic battleground only: no outfit is made for a rotating map.
-- Shado-Pan Showdown, Southshore vs. Tarren Mill, Cooking: Impossible, Slayer's Rise.
Z.BRAWL_MAP_IDS = { 1170, 1280, 1691, 2799 }
