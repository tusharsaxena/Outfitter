local _, NS = ...
-- modules/Triggers_CondQuest.lua — the bespoke QUEST and ENTERTAIN trigger conditions (design §6.8.1
-- rows 27, 28, 30, 31, 36): QUEST_MULTIPHASE_SURVEY, QUEST_TURNIN, PET_BATTLE, DANCE and COMPANION.
--
-- Each entry of NS.TriggerConditions is the condition `fn(ctx, event, ...) -> action, delay` or a table
-- `{ condition, onWorn, onRemoved, onSuspend }` (modules/Triggers.lua's Finalize reads it at call time;
-- this file loads before Triggers.lua). The three vehicle quests (rows 24-26) are no entry here: they
-- run the `vehicleMount` family on defaults/TriggerData.lua's NPC sets.
--
-- DANCE and COMPANION never change the stack themselves: their whole effect is the hook on this
-- outfit's own wear, which the binder runs only when its gate passes.
--
-- CLIENT READS: the trigger stanza in .luacheckrc. Every map, quest and pet answer passes through
-- NS.Secrets before it is compared, so a secret answer is no match and never raises.

NS.TriggerConditions = NS.TriggerConditions or {}
local Cond = NS.TriggerConditions

local Secrets, L = NS.Secrets, NS.L

local EQUIP, UNEQUIP = "equip", "unequip"   -- NS.TRIG's values (modules/Triggers.lua)

local function none() return nil end

-- ── QUEST_MULTIPHASE_SURVEY (OutfitterScripting.lua:1560-1583) ────────────────────────────────

local SURVEY_QUEST = 11880   -- The Multiphase Survey
local NAGRAND_MAP  = 107     -- Nagrand (Outland), a uiMapID
local SURVEY_DELAY = 5

local function bestMap()
    local api = C_Map
    local get = api and api.GetBestMapForUnit
    return get and Secrets.PlainNumber(get("player")) or nil
end

-- On the quest and not yet done with it (the legacy PlayerIsOnQuestID, now C_QuestLog's).
local function onSurvey()
    local api = C_QuestLog
    if not (api and api.IsOnQuest and api.IsComplete) then return false end
    if Secrets.PlainTruth(api.IsOnQuest(SURVEY_QUEST)) ~= true then return false end
    return Secrets.PlainTruth(api.IsComplete(SURVEY_QUEST)) ~= true
end

--- In Nagrand on the survey: on, five seconds late; anywhere else, or done with it: off.
function Cond.QUEST_MULTIPHASE_SURVEY()
    if bestMap() == NAGRAND_MAP and onSurvey() then return EQUIP, SURVEY_DELAY end
    return UNEQUIP
end

-- ── QUEST_TURNIN (OutfitterScripting.lua:1584-1596; O26) ──────────────────────────────────────

--- The quest window's progress page puts the outfit on; finishing takes it off if this trigger put it on.
function Cond.QUEST_TURNIN(ctx, event)
    if event == "QUEST_PROGRESS" then return EQUIP end
    if event == "QUEST_FINISHED" and ctx:DidEquip() then return UNEQUIP end
    return nil
end

-- ── PET_BATTLE (OutfitterScripting.lua:1747-1758; Bruce Quinton's script) ─────────────────────

local PET_BATTLE_VERDICT = { PET_BATTLE_OPENING_DONE = EQUIP, PET_BATTLE_CLOSE = UNEQUIP }

--- A pet battle's opening puts the outfit on and its close takes it off.
function Cond.PET_BATTLE(_, event)
    return PET_BATTLE_VERDICT[event]
end

-- ── DANCE (OutfitterScripting.lua:1620-1633) ──────────────────────────────────────────────────

local function dance()
    local emote = DoEmote
    if type(emote) == "function" then emote("DANCE") end
end

Cond.DANCE = { condition = none, onWorn = dance }

-- ── COMPANION (OutfitterScripting.lua:1634-1648) ──────────────────────────────────────────────

local PET_DELAY = 2

-- Whether the journal holds the pet `guid` (a stored petGUID, or "" for none chosen).
local function ownedPet(guid)
    if type(guid) ~= "string" or guid == "" then return false end
    local api = C_PetJournal
    local get = api and api.GetPetInfoByPetID
    if not get then return false end
    local ok, speciesID = pcall(get, guid)
    return ok and Secrets.PlainNumber(speciesID) ~= nil
end

local function summonPet(ctx)
    local guid = ctx.params.pet
    if ownedPet(guid) and NS.Companion.SummonByGUID(guid, PET_DELAY) then return end
    NS.Print(L["Couldn't find that pet"])
end

Cond.COMPANION = { condition = none, onWorn = summonPet }
