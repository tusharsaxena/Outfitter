local _, NS = ...
-- defaults/Triggers.lua — NS.TriggerCatalog: one data row per non-zone trigger, and CATEGORY_ORDER (design §6.3).
--
-- PURE DATA (savedvariables-§2: the only place a trigger's defaults are written). Each row is a native
-- trigger descriptor before modules/Triggers.lua's Finalize resolves it: id, category, class, the
-- localized name and description, events, typed params, icon, and the family (with its args) or, for a
-- bespoke trigger, nothing, because its condition is NS.TriggerConditions[id] in one of the three
-- Triggers_Cond*.lua files. An outfit stores only the id, its two flags and its param values, so
-- whatever ships here is what every outfit runs (INV §9.4: "preset scripts resolve live").
--
-- THE ZONE TRIGGERS ARE NOT HERE. Finalize emits one per defaults/Zones.lua row (family `zone`), and
-- the spec triggers SPEC_1..N from the player's class; ZONE_ICONS and ZONE_DESC below are their data.
--
-- Row fields (design §6.3): `events` names game events (UPPER_SNAKE) and the pseudo keys STATE:<ID>,
-- TIMER, TOOLTIP_SHOW, TOOLTIP_HIDE, OUTFIT_WORN, OUTFIT_REMOVED, AURAS and BIND. BIND is written here
-- and only here: Finalize strips it and sets `initial`, which no row ever writes. `unit` filters a
-- game event whose first argument is a unit token. `ticker` is an always-on repeating tick while
-- bound. `specDefault` makes Finalize append the spec1..spec4 toggles with that default. `effects`
-- names NS.TriggerEffects entries applied on this outfit's OUTFIT_WORN and restored on its
-- OUTFIT_REMOVED and on stand-down. `persist` gives the condition `ctx.persist`. `icon` is the bar's
-- default icon, ported from OutfitterBar.lua:9-53 (C30); `false` where the legacy table had none, so
-- the bar draws the outfit's own icon as it always did.

local L = NS.L

NS.TriggerCatalog = NS.TriggerCatalog or {}          -- architecture-§3 idempotent
local C = NS.TriggerCatalog

-- The picker's category order (OutfitterScripting.lua:1761-1769); the generated spec rows follow
-- under SPEC (design §6.7).
C.CATEGORY_ORDER = { "GENERAL", "TRADE", "PVP", "QUEST", "ENTERTAIN", "CLASS" }

-- The four guard toggles, shared by name (design §6.6).
local function disableInstance(default)
    return { key = "disableInstance", type = "bool", label = L["Don't equip in dungeons"], default = default }
end
local function disableBG(default)
    return { key = "disableBG", type = "bool", label = L["Don't equip in Battlegrounds"], default = default }
end
local function disablePVP(default)
    return { key = "disablePVP", type = "bool", label = L["Don't equip while PvP flagged"], default = default }
end
local function ignoreDifficulty()
    return { key = "ignoreDifficulty", type = "bool", label = L["Ignore difficulty"], default = false }
end
local function unequipComplete()
    return { key = "unequipComplete", type = "bool", label = L["Allow Complete outfits to unequip"], default = false }
end

-- The three vehicle quests share their events (OutfitterScripting.lua:1376-1567).
local VEHICLE_EVENTS = { "TOOLTIP_SHOW", "UPDATE_MOUSEOVER_UNIT", "TOOLTIP_HIDE", "UNIT_ENTERED_VEHICLE",
                         "UNIT_EXITED_VEHICLE" }
local function vehicleEvents(extra)
    local out = {}
    for i, e in ipairs(VEHICLE_EVENTS) do out[i] = e end
    if extra then out[#out + 1] = extra end
    return out
end

-- A druid shape: the bar icon, the state and the family (design §6.8.3 rows 71-75).
local function druidForm(id, name, desc, state, icon)
    return { id = id, category = "CLASS", class = "DRUID", icon = icon, name = name, desc = desc,
             events = { "STATE:" .. state, "OUTFIT_WORN" }, layer = "shapeshift",
             family = "druidForm", familyArgs = { state = state }, specDefault = true,
             params = { disableBG(false), disablePVP(false), unequipComplete() } }
end

C.rows = {
    -- ── GENERAL ─────────────────────────────────────────────────────────────────────────────────
    { id = "IN_DUNGEON", category = "GENERAL", icon = false,
      name = L["In Dungeon"],
      desc = L["Equips the outfit when you're in a dungeon, raid, or battleground instance based on the settings"],
      events = { "PLAYER_ENTERING_WORLD", "BIND" },
      params = {
          { key = "enable5Man",  type = "bool", label = L["Equip in 5-man instances"],        default = true },
          { key = "enableRaid",  type = "bool", label = L["Equip in Raid instances"],         default = false },
          { key = "enableBG",    type = "bool", label = L["Equip in Battleground instances"], default = false },
          { key = "enableArena", type = "bool", label = L["Equip in Arena instances"],        default = false },
      } },
    { id = "INSTANCE_DIFFICULTY", category = "GENERAL", icon = 132132,
      name = L["Instance Difficulty"],
      desc = L["Equips the outfit in the open world or the instance difficulties you select"],
      events = { "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_DIFFICULTY_CHANGED", "BIND" },
      -- One toggle per NS.TriggerData.DIFFICULTY_GROUPS key, in DIFFICULTY_ORDER.
      params = {
          { key = "openWorld",     type = "bool", label = L["Equip in the open world"],       default = false },
          { key = "dungeonNormal", type = "bool", label = L["Equip in normal dungeons"],      default = false },
          { key = "dungeonHeroic", type = "bool", label = L["Equip in heroic dungeons"],      default = false },
          { key = "dungeonMythic", type = "bool", label = L["Equip in mythic dungeons"],      default = false },
          { key = "mythicPlus",    type = "bool", label = L["Equip in Mythic+ dungeons"],     default = false },
          { key = "raidFinder",    type = "bool", label = L["Equip in raid finder"],          default = false },
          { key = "raidNormal",    type = "bool", label = L["Equip in normal raids"],         default = false },
          { key = "raidHeroic",    type = "bool", label = L["Equip in heroic raids"],         default = false },
          { key = "raidMythic",    type = "bool", label = L["Equip in mythic raids"],         default = false },
          { key = "raid40",        type = "bool", label = L["Equip in 40 player raids"],      default = false },
          { key = "delve",         type = "bool", label = L["Equip in delves"],               default = false },
      } },
    { id = "HAS_BUFF", category = "GENERAL", icon = 135826,
      name = L["Has Buff"],
      desc = L["Equips the outfit when you have one of the listed buffs"],
      events = { "AURAS", "BIND" },
      params = {
          { key = "spellIDs", type = "spelllist", label = L["Buffs"] },
          disableInstance(false), disableBG(false), disablePVP(false),
      } },
    { id = "TARGET", category = "GENERAL", icon = false,
      name = L["Equip on target"],
      desc = L["Equips the outfit when your target is one of the listed creatures or players"],
      events = { "PLAYER_TARGET_CHANGED", "BIND" },
      params = {
          { key = "targets",         type = "unitlist", label = L["Targets"] },
          { key = "unequipOnChange", type = "bool",     label = L["Unequip when the target changes"], default = true },
      } },
    { id = "TRINKET_QUEUE", category = "GENERAL", icon = false, refuseEM = true,
      name = L["Trinket Queue"],
      desc = L["The highest trinket in the list that isn't on cooldown will automatically be equipped for you"],
      events = { "TIMER" }, ticker = 0.5,
      params = {
          { key = "trinkets",  type = "itemlist", label = L["Upper slot"] },
          { key = "trinkets2", type = "itemlist", label = L["Lower slot"] },
      } },
    { id = "FEET_QUEUE", category = "GENERAL", icon = false,
      name = L["Rocket Boots"],
      desc = L["The boots in the list with the earliest availability will automatically be equipped"],
      events = { "TIMER" }, ticker = 0.5,
      params = { { key = "boots", type = "itemlist", label = L["Boots"] } } },
    { id = "IN_ZONES", category = "GENERAL", icon = false,
      name = L["In Zones"],
      desc = L["Equips the outfit when you are in one of the zones or minimap sub-zones listed below"],
      events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "BIND" },
      params = {
          { key = "maps",     type = "maplist",     label = L["Zones"] },
          { key = "subzones", type = "subzonelist", label = L["Minimap zones"] },
      } },
    { id = "TALENT_TREE", category = "GENERAL", icon = false,
      name = L["Talent Tree"],
      desc = L["Equips the outfit when you activate specs for the selected talent tree"],
      events = { "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE" },
      specDefault = false },
    { id = "SPIRIT_REGEN", category = "GENERAL", icon = 135934,
      name = L["Spirit Regen"],
      desc = L["Equips the outfit when you are regenerating mana (out of the five-second rule)"],
      events = { "STATE:SPIRIT_REGEN" },
      family = "smartUnequip", familyArgs = { state = "SPIRIT_REGEN", unequipDelay = 0.5 } },

    -- ── TRADE ───────────────────────────────────────────────────────────────────────────────────
    { id = "GATHER_HERBALISM", category = "TRADE", icon = 136246,
      name = L["Herbalism"],
      desc = L["Equips the outfit when your cursor is over an herb node that is orange or red to you"],
      events = { "TOOLTIP_SHOW", "TOOLTIP_HIDE" },
      family = "gathering", familyArgs = { skillLine = 182 },
      params = { ignoreDifficulty() } },
    { id = "GATHER_MINING", category = "TRADE", icon = 134708,
      name = L["Mining"],
      desc = L["Equips the outfit when your cursor is over a mining node that is orange or red to you"],
      events = { "TOOLTIP_SHOW", "TOOLTIP_HIDE" },
      family = "gathering", familyArgs = { skillLine = 186 },
      params = { ignoreDifficulty() } },
    { id = "GATHER_SKINNING", category = "TRADE", icon = 134366,
      name = L["Skinning"],
      desc = L["Equips the outfit when your cursor is over a skinnable creature that is orange or red to you"],
      events = { "TOOLTIP_SHOW", "TOOLTIP_HIDE" },
      -- The client's own "Skinnable" line (a GlobalString, localization-§4), read at call time.
      family = "gathering", familyArgs = { skillLine = 393, textGlobal = "UNIT_SKINNABLE_LEATHER" },
      params = { ignoreDifficulty() } },
    { id = "LOCKPICKING", category = "TRADE", class = "ROGUE", icon = 136058,
      name = L["Rogue: Lockpicking"],
      desc = L["Equips the outfit when your cursor is over a lock that is orange or red to you"],
      events = { "TOOLTIP_SHOW", "TOOLTIP_HIDE", "TIMER" } },
    { id = "RIDING", category = "TRADE", icon = 132261,
      name = L["Riding"],
      desc = L["Equips the outfit when you're mounted"],
      events = { "STATE:MOUNTED", "TIMER" },
      params = {
          disableBG(true), disableInstance(true), disablePVP(false),
          { key = "stayWhileFalling", type = "bool", label = L["Leave equipped while falling"], default = false },
          { key = "unequipDelay", type = "number", label = L["Wait"], default = 0, min = 0, max = 30, step = 1,
            suffix = L["seconds before unequipping"] },
      } },
    { id = "SWIMMING", category = "TRADE", icon = 136148,
      name = L["Swimming"],
      desc = L["Equips the outfit when you're swimming"],
      events = { "STATE:SWIMMING" },
      family = "smartUnequip", familyArgs = { state = "SWIMMING", unequipDelay = 2.5, guards = "skipAll" },
      params = {
          disableInstance(false), disableBG(false), disablePVP(false),
          { key = "disableVashjir", type = "bool", label = L["Don't equip in Vashj'ir"], default = true },
      } },
    { id = "FISHING", category = "TRADE", icon = 136245, persist = true,
      name = L["Fishing"],
      desc = L["Turns on Find Fish, auto loot and the other fishing helpers while the outfit is worn"],
      events = { "OUTFIT_WORN", "OUTFIT_REMOVED" },
      -- Never equips by itself: the effects are the whole trigger (design §6.8.1 row 13).
      family = "passive", effects = { "AutoLoot", "FishTracking", "ClickToMove", "ActionBarPage" },
      params = {
          { key = "trackFish",          type = "bool", label = L["Select Track Fish while equipped"],     default = true },
          { key = "autoLoot",           type = "bool", label = L["Enable auto loot while equipped"],      default = false },
          { key = "disableClickToMove", type = "bool", label = L["Disable Click-to-Move while equipped"], default = true },
          { key = "changeActionBar",    type = "bool", label = L["Switch action bars while equipped"],    default = false },
          { key = "actionBarPage", type = "number", label = L["Action bar (1 - 6)"], default = 1, min = 1, max = 6, step = 1 },
      } },
    { id = "DINING", category = "TRADE", icon = 134062,
      name = L["Dining"],
      desc = L["Equips the outfit when you're eating or drinking until your health and mana are above 85%"],
      events = { "STATE:DINING" },
      family = "smartUnequip", familyArgs = { state = "DINING" } },
    { id = "FALLING", category = "TRADE", icon = false,
      name = L["Falling"],
      desc = L["Equips the outfit when you're falling"],
      events = { "TIMER" }, ticker = 0.5 },
    { id = "RESTING", category = "TRADE", icon = false,
      name = L["Resting"],
      desc = L["Equips the outfit when you're in an inn"],
      events = { "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD", "BIND" } },
    { id = "SPELLCAST", category = "TRADE", icon = false, unit = "player",
      name = L["Spellcast"],
      desc = L["Equips when you start casting one of the listed spells, unequips when you cast something else"],
      events = { "UNIT_SPELLCAST_START" },
      params = {
          { key = "spellIDs", type = "spelllist", label = L["Spells"] },
          { key = "dontWait", type = "bool",      label = L["Don't wait for spellcast to end"], default = false },
      } },
    { id = "COOKING", category = "TRADE", icon = 133971, persist = true,
      name = L["Cooking"],
      desc = L["Equips the outfit whenever your Cooking window is open"],
      events = { "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE" },
      -- One toggle per NS.TriggerData.COOKING_PETS param, then the random pick.
      params = {
          { key = "summonRagnaros", type = "bool", label = L["Summon Lil' Ragnaros"], default = false },
          { key = "summonPierre",   type = "bool", label = L["Summon Pierre"],        default = false },
          { key = "randomPet",      type = "bool", label = L["Randomly summon a permitted cooking fire pet"], default = false },
      } },

    -- ── PVP (the zone rows follow from defaults/Zones.lua) ──────────────────────────────────────
    { id = "PVP_FLAGGED", category = "PVP", icon = false, unit = "player", persist = true,
      name = L["PvP Flagged"],
      desc = L["Equips the outfit when you're PvP-flagged"],
      events = { "PLAYER_FLAGS_CHANGED", "PLAYER_ENTERING_WORLD", "BIND" } },

    -- ── QUEST ───────────────────────────────────────────────────────────────────────────────────
    { id = "QUEST_ARGENT_TOURNAMENT", category = "QUEST", icon = false, unit = "player",
      name = L["Argent Tournament"],
      desc = L["Equips the outfit when you mount an Argent Tournament steed"],
      events = vehicleEvents(),
      family = "vehicleMount", familyArgs = { unitType = "Vehicle", npcs = "ARGENT_MOUNTS", byFaction = true } },
    { id = "QUEST_VIGILANCE_ON_WINGS", category = "QUEST", icon = false, unit = "player",
      name = L["Vigilance on Wings"],
      desc = L["Equips the outfit when you ride an Aviana's Guardian for the Vigilance on Wings quest"],
      events = vehicleEvents(),
      family = "vehicleMount", familyArgs = { unitType = "Creature", npcs = "VIGILANCE_NPCS" } },
    { id = "QUEST_FLAME_LEVIATHAN", category = "QUEST", icon = false, unit = "player",
      name = L["Flame Leviathan"],
      desc = L["Equips the outfit when you enter a Flame Leviathan encounter vehicle, unequips it when you exit and combat is ended"],
      events = vehicleEvents("PLAYER_REGEN_ENABLED"),
      family = "vehicleMount", familyArgs = { unitType = "Vehicle", npcs = "LEVIATHAN_NPCS", regenUnequip = true } },
    { id = "QUEST_MULTIPHASE_SURVEY", category = "QUEST", icon = false,
      name = L["The Multiphase Survey"],
      desc = L["Equips the outfit when you're on the Multiphase Survey quest and enter Nagrand, unequips when you complete the quest or leave Nagrand"],
      events = { "QUEST_LOG_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "BIND" } },
    { id = "QUEST_TURNIN", category = "QUEST", icon = false,
      name = L["Quest Turn-in"],
      desc = L["Use this to automatically equip your bonus XP gear before you turn in quests"],
      events = { "QUEST_PROGRESS", "QUEST_FINISHED" } },
    -- Pet Battle: contributed by Bruce Quinton (credited in the README).
    { id = "PET_BATTLE", category = "QUEST", icon = false,
      name = L["Pet Battle"],
      desc = L["Equips the outfit when engaging in a pet battle"],
      events = { "PET_BATTLE_OPENING_DONE", "PET_BATTLE_CLOSE" } },

    -- ── ENTERTAIN ───────────────────────────────────────────────────────────────────────────────
    { id = "DANCE", category = "ENTERTAIN", icon = false,
      name = L["Dance on equip"],
      desc = L["Makes you dance when you equip the outfit"],
      events = { "OUTFIT_WORN" } },
    { id = "COMPANION", category = "ENTERTAIN", icon = false,
      name = L["Summon pet on equip"],
      desc = L["Summons a companion pet 2 seconds after the outfit is equipped"],
      events = { "OUTFIT_WORN" },
      params = { { key = "pet", type = "pet", label = L["Pet"], default = "" } } },

    -- ── CLASS ───────────────────────────────────────────────────────────────────────────────────
    { id = "DRUID_CASTER", category = "CLASS", class = "DRUID", icon = 135157,
      name = L["Druid: Caster Form"],
      desc = L["Equips the outfit when you are not in any druid form"],
      events = { "STATE:FORM_CASTER", "OUTFIT_WORN" }, layer = "shapeshift",
      family = "druidCaster", familyArgs = { state = "FORM_CASTER" }, specDefault = true,
      params = { disableInstance(false), disableBG(false), disablePVP(false) } },
    druidForm("DRUID_BEAR", L["Druid: Bear Form"],
        L["This outfit will be worn whenever you're in Bear Form"], "FORM_BEAR", 132276),
    druidForm("DRUID_CAT", L["Druid: Cat Form"],
        L["This outfit will be worn whenever you're in Cat Form"], "FORM_CAT", 132115),
    druidForm("DRUID_TRAVEL", L["Druid: Travel Form"],
        L["This outfit will be worn whenever you're in Travel Form"], "FORM_TRAVEL", 132144),
    druidForm("DRUID_MOONKIN", L["Druid: Moonkin Form"],
        L["This outfit will be worn whenever you're in Moonkin Form"], "FORM_MOONKIN", 136096),
    druidForm("DRUID_TREE", L["Druid: Tree of Life"],
        L["This outfit will be worn whenever you're in Tree Form"], "FORM_TREE", 136041),
    { id = "DRUID_PROWL", category = "CLASS", class = "DRUID", icon = 132089,
      name = L["Druid: Prowl"],
      desc = L["This outfit will be worn whenever you're prowling"],
      events = { "STATE:STEALTH" },
      family = "simple", familyArgs = { state = "STEALTH" } },
    { id = "ROGUE_STEALTH", category = "CLASS", class = "ROGUE", icon = 132320, persist = true,
      name = L["Rogue: Stealth"],
      desc = L["This outfit will be worn whenever you're stealthed"],
      events = { "STATE:STEALTH", "OUTFIT_WORN", "OUTFIT_REMOVED" },
      family = "simple", familyArgs = { state = "STEALTH" }, effects = { "AutoLoot" },
      params = { { key = "autoLoot", type = "bool", label = L["Enable auto loot while equipped"], default = false } } },
    { id = "SHAMAN_GHOST_WOLF", category = "CLASS", class = "SHAMAN", icon = 136095,
      name = L["Shaman: Ghost Wolf"],
      desc = L["Equips the outfit when you are in ghost wolf form"],
      events = { "STATE:GHOST_WOLF" },
      family = "simple", familyArgs = { state = "GHOST_WOLF" } },
    { id = "HUNTER_FEIGN_DEATH", category = "CLASS", class = "HUNTER", icon = 132293,
      name = L["Hunter: Feign Death"],
      desc = L["Equips the outfit when you are feigning death"],
      events = { "STATE:FEIGN_DEATH" },
      family = "simple", familyArgs = { state = "FEIGN_DEATH" } },
}

-- The zone triggers' bar icons: the legacy table named the two generics and the four classic
-- battlegrounds (OutfitterBar.lua:16-21); every other zone outfit draws its own icon.
C.ZONE_ICONS = {
    PVP_BATTLEGROUND = 1376041, PVP_ARENA = 1376041,
    BG_AB = 1376041, BG_AV = 1376041, BG_WSG = 1376041, BG_EOTS = 1376041,
}

-- The two generic zone triggers' own descriptions; every map row reads "...when you're in <map>".
C.ZONE_DESC = {
    PVP_BATTLEGROUND = L["Equips the outfit when you're in any battleground"],
    PVP_ARENA        = L["Equips the outfit when you're in a PvP Arena"],
}
