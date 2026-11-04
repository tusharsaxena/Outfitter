local _, NS = ...
-- defaults/TriggerData.lua — the aura, form, NPC, difficulty, map, skill-line and pet ID tables the
-- triggers and their state producers read (design §6.2, §6.8, §6.10). Pure data: no builder, no
-- client read. Every match key is an ID (design §6.12), never a name.
--
-- Sources: the legacy tables at 7ea3dc3 (Outfitter.lua, OutfitterScripting.lua, cited per table) and,
-- where the design asks for one, a wago.tools db2 export (cited with the date it was read).

NS.TriggerData = NS.TriggerData or {}                -- architecture-§3 idempotent
local D = NS.TriggerData

-- ── states (modules/States.lua) ───────────────────────────────────────────────────────────────

-- A player aura's icon -> the state it sets; matched before the spell (Outfitter.lua:1122-1126).
D.AURA_ICON_STATE = {
    [134062] = "DINING",
    [132805] = "DINING",
}

-- A player aura's spellID -> the state it sets (Outfitter.lua:1114-1120). Evocation (12051) is gone:
-- nothing consumed its state. Prowl (5215) is new (O27): before it only Shadowmeld fed STEALTH.
D.AURA_SPELL_STATE = {
    [2645]  = "GHOST_WOLF",   -- Ghost Wolf
    [5384]  = "FEIGN_DEATH",  -- Feign Death
    [58984] = "STEALTH",      -- Shadowmeld
    [5215]  = "STEALTH",      -- Prowl
}

-- A shapeshift form's spellID (GetShapeshiftFormInfo's 4th return) -> the state it sets
-- (Outfitter.lua:1297-1307). A druid with no form active is FORM_CASTER, which has no spell.
-- Tree of Life (33891) is new: the legacy table had none, so the Tree outfit never fired (O27).
D.FORM_SPELL_STATE = {
    [5487]  = "FORM_BEAR",    -- Bear Form
    [768]   = "FORM_CAT",     -- Cat Form
    [783]   = "FORM_TRAVEL",  -- Travel Form
    [24858] = "FORM_MOONKIN", -- Moonkin Form
    [33891] = "FORM_TREE",    -- Incarnation: Tree of Life
    [1784]  = "STEALTH",      -- rogue Stealth
}

-- Forms that mean the player may be in combat before PLAYER_REGEN_DISABLED says so (the legacy
-- MaybeInCombat flag on Bear Form): the producer calls PS.SetMaybeInCombat(true) on entering one.
D.FORM_MAYBE_IN_COMBAT = { FORM_BEAR = true }

-- ── activity and quest triggers ───────────────────────────────────────────────────────────────

-- The Argent Tournament mounts, by the player's faction: UnitFactionGroup's FIRST return, the English
-- token (H10). Each set holds its faction's mounts and the two either faction rides
-- (OutfitterScripting.lua:1410-1437).
local ARGENT_EITHER = {
    [33870] = true, -- Stabled Argent Warhorse
    [34125] = true, -- Stabled Campaign Warhorse
}
local function withEither(set)
    for npcID in pairs(ARGENT_EITHER) do set[npcID] = true end
    return set
end
D.ARGENT_MOUNTS = {
    Alliance = withEither({
        [33790] = true, -- Stabled Exodar Elekk
        [33793] = true, -- Stabled Gnomeregan Mechanostrider
        [33794] = true, -- Stabled Darnassian Nightsaber
        [33795] = true, -- Stabled Ironforge Ram
        [33800] = true, -- Stabled Stormwind Steed
        [33843] = true, -- Stabled Quel'dorei Steed
        [36557] = true, -- Argent Warhorse
    }),
    Horde = withEither({
        [33791] = true, -- Stabled Silvermoon Hawkstrider
        [33792] = true, -- Stabled Thunder Bluff Kodo
        [33796] = true, -- Stabled Darkspear Raptor
        [33798] = true, -- Stabled Forsaken Warhorse
        [33799] = true, -- Stabled Orgrimmar Wolf
        [33842] = true, -- Stabled Sunreaver Hawkstrider
        [36558] = true, -- Argent Battleworg
    }),
}
-- Any other faction value, nil before the faction data loads or a Neutral pandaren, reads the Horde
-- set, as the legacy `if Alliance ... else <Horde>` did, so `ARGENT_MOUNTS[faction]` is never nil.
setmetatable(D.ARGENT_MOUNTS, { __index = function() return D.ARGENT_MOUNTS.Horde end })

-- Vigilance on Wings: Aviana's Guardian, every variant (OutfitterScripting.lua:1481-1484).
D.VIGILANCE_NPCS = { [39710] = true, [40719] = true, [40720] = true, [40723] = true }

-- Flame Leviathan: the Ulduar vehicles (OutfitterScripting.lua:1529-1531).
D.LEVIATHAN_NPCS = {
    [33060] = true, -- Salvaged Siege Engine
    [33109] = true, -- Salvaged Demolisher
    [33062] = true, -- Salvaged Chopper
}

-- INSTANCE_DIFFICULTY's groups: GetInstanceInfo's 3rd return (0 outside an instance) -> the param that
-- enables it (design §6.8.1 row 17). Confirmed 2026-11-03 against https://wago.tools/db2/Difficulty
-- (O24): every id below is the db2 row its group names. The export also has ids no group lists, left
-- out as the design lists the groups: 24 and 33 (Timewalking), 151 (a second Looking For Raid row),
-- 205 (Follower), 220 (Story), 233 (a second Mythic raid row) and the scenario ids.
D.DIFFICULTY_GROUPS = {
    openWorld     = { 0 },
    dungeonNormal = { 1 },
    dungeonHeroic = { 2 },
    dungeonMythic = { 23 },
    mythicPlus    = { 8 },          -- Mythic Keystone
    raidFinder    = { 17, 7 },      -- Looking For Raid, and the legacy one
    raidNormal    = { 14, 3, 4 },   -- Normal, and the legacy 10 and 25 Player
    raidHeroic    = { 15, 5, 6 },   -- Heroic, and the legacy 10 and 25 Player (Heroic)
    raidMythic    = { 16 },
    raid40        = { 9 },          -- 40 Player
    delve         = { 208 },        -- Delves
}
-- The params in the trigger dialog's order.
D.DIFFICULTY_ORDER = {
    "openWorld", "dungeonNormal", "dungeonHeroic", "dungeonMythic", "mythicPlus",
    "raidFinder", "raidNormal", "raidHeroic", "raidMythic", "raid40", "delve",
}

-- Vashj'ir's uiMapIDs, for SWIMMING's disableVashjir guard (OutfitterScripting.lua:798-801).
D.VASHJIR_MAP_IDS = {
    201, -- Kelp'thar Forest
    204, -- Abyssal Depths
    205, -- Shimmering Expanse
}

-- Profession skill lines (design §6.12). The gathering tooltip text is the client's own
-- GetTradeSkillDisplayName(id), never a hardcoded name (H9, D10); 633 is O22's lockpicking line.
D.SKILL_LINES = {
    HERBALISM   = 182,
    MINING      = 186,
    SKINNING    = 393,
    COOKING     = 185,
    LOCKPICKING = 633,
}

-- Find Fish tracking: matched by spellID in C_Minimap.GetTrackingInfo, falling back to the texture
-- (O5; OutfitterScripting.lua:834).
D.FIND_FISH = { spell = 43308, texture = 133888 }

-- The COOKING trigger's pets: each param -> the battle-pet speciesID it summons, in the order a random
-- pick reads them. Taken 2026-11-03 from https://wago.tools/db2/BattlePetSpecies by CreatureID
-- (O21): Lil' Ragnaros is creature 51600, Pierre creature 70082.
D.COOKING_PETS = {
    { param = "summonRagnaros", species = 297 },   -- Lil' Ragnaros
    { param = "summonPierre",   species = 1204 },  -- Pierre
}
