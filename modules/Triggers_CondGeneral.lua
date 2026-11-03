local _, NS = ...
-- modules/Triggers_CondGeneral.lua — the bespoke GENERAL (and PvP-flag) trigger conditions (design §6.8.1).
--
-- Rows 5-10, 17, 19 and 21 of design §6.8.1: PVP_FLAGGED, IN_DUNGEON, TRINKET_QUEUE, FEET_QUEUE,
-- IN_ZONES, TALENT_TREE, INSTANCE_DIFFICULTY, HAS_BUFF and TARGET. Row 16 (SPIRIT_REGEN) is a family
-- row (`smartUnequip`, defaults/Triggers.lua) and has nothing here. Each entry is the condition
-- function itself, `fn(ctx, event, ...) -> action, delay, layer, interrupt` (design §6.3), which
-- modules/Triggers.lua's Finalize reads at call time: this file loads before Triggers.lua.
--
-- Every condition answers nil for "no change". Most allocate nothing per event; three allocate a
-- little, on events that do not come in bursts: TARGET (CaptureTarget's answer table, per target
-- change), IN_ZONES (the trimmed sub-zone string, per zone change) and TALENT_TREE (the "spec<n>"
-- key, per spec event). A client read goes through the Secrets seam: a secret or unreadable answer is never compared, it is
-- "no match" (TARGET, IN_ZONES) or "no change" (PVP_FLAGGED, INSTANCE_DIFFICULTY, TALENT_TREE).
--
-- MATCH KEYS ARE IDS (design §6.12): uiMapIDs, spellIDs, itemIDs, creatureIDs, difficultyIDs. The
-- two string matches left are the minimap sub-zone text a player captured on their own client (D3)
-- and a player target's "Name-Realm".
--
-- CALLS (at call time, no nil guard; design §12): NS.States.PlayerHasSpell, NS.TriggerGuards,
-- NS.TriggerParams.CaptureTarget, NS.Inventory.NextCooldownItem/SlotItemActive/Cache, NS.Outfits.SetItem,
-- NS.ItemInfo.Snapshot, NS.Equip.Batch/Request.
--
-- CLIENT READS: the trigger stanza in .luacheckrc.

NS.TriggerConditions = NS.TriggerConditions or {}    -- architecture-§3 idempotent; Finalize reads it
local Cond = NS.TriggerConditions

local Secrets, Compat, D = NS.Secrets, NS.Compat, NS.TriggerData

local EQUIP, UNEQUIP = "equip", "unequip"            -- NS.TRIG's values (modules/Triggers.lua)
local MAX_MAP_DEPTH = 8                              -- IN_ZONES walks the best map and at most 8 ancestors

-- The player's live spec index (GetSpecialization), plain or nil.
local function liveSpec()
    return Secrets.PlainNumber(Compat.GetSpecialization())
end

-- ── PVP_FLAGGED (row 5) ───────────────────────────────────────────────────────────────────────

--- Edge-triggered on UnitIsPVP: nothing while the flag reads as last time (outfit.triggerState
--- .PVP_FLAGGED.wasPvP, the legacy outfit.wasPvP), else remember it and wear or remove. A secret
--- flag is no reading at all.
function Cond.PVP_FLAGGED(ctx)
    local isPvP = Secrets.PlainTruth(UnitIsPVP("player"))
    if isPvP == nil then return nil end
    isPvP = isPvP == true
    local persist = ctx.persist
    if persist.wasPvP == isPvP then return nil end
    persist.wasPvP = isPvP
    if isPvP then return EQUIP end
    return UNEQUIP
end

-- ── IN_DUNGEON (row 6) ────────────────────────────────────────────────────────────────────────

-- The instance type -> the param that enables it. Arena reads enableArena (the legacy read
-- EnableBG twice, OutfitterScripting.lua:565; INV §19).
local DUNGEON_FLAG = { party = "enable5Man", raid = "enableRaid", pvp = "enableBG", arena = "enableArena" }

--- In an instance whose type is enabled -> EQUIP, anywhere else -> UNEQUIP (not smart, as before).
function Cond.IN_DUNGEON(ctx)
    local get = _G.IsInInstance
    local inInstance, itype
    if get then inInstance, itype = get() end
    local flag = Secrets.PlainTruth(inInstance) == true and DUNGEON_FLAG[Secrets.PlainString(itype)]
    if flag and ctx.params[flag] then return EQUIP end
    return UNEQUIP
end

-- ── INSTANCE_DIFFICULTY (row 17) ──────────────────────────────────────────────────────────────

-- difficultyID -> the DIFFICULTY_GROUPS param that enables it, derived once from the data table.
local DIFFICULTY_PARAM = {}
for param, ids in pairs(D.DIFFICULTY_GROUPS) do
    for _, id in ipairs(ids) do DIFFICULTY_PARAM[id] = param end
end

--- GetInstanceInfo's 3rd return (0 in the open world) in an enabled group -> EQUIP; otherwise the
--- outfit comes off only if this trigger put it on. An unreadable difficulty changes nothing.
function Cond.INSTANCE_DIFFICULTY(ctx)
    local get = GetInstanceInfo
    if not get then return nil end
    local _, _, difficultyID = get()
    difficultyID = Secrets.PlainNumber(difficultyID)
    if difficultyID == nil then return nil end
    local param = DIFFICULTY_PARAM[difficultyID]
    if param and ctx.params[param] then return EQUIP end
    if ctx:DidEquip() then return UNEQUIP end
    return nil
end

-- ── HAS_BUFF (row 19) ─────────────────────────────────────────────────────────────────────────

local function hasAnySpell(ids)
    local S = NS.States
    for _, id in ipairs(ids) do
        if S.PlayerHasSpell(id) then return true end
    end
    return false
end

--- Any listed spellID on the player at the last aura scan -> EQUIP, unless a guard toggle blocks
--- (then nothing changes); no match -> UNEQUIP if this trigger equipped it. While an add-on
--- restriction is active the scan reads nothing, so every buff reads false (O28, ported as is).
function Cond.HAS_BUFF(ctx)
    if hasAnySpell(ctx.params.spellIDs) then
        local G = NS.TriggerGuards
        if G.instance(ctx) or G.bg(ctx) or G.pvp(ctx) then return nil end
        return EQUIP
    end
    if ctx:DidEquip() then return UNEQUIP end
    return nil
end

-- ── TARGET (row 21, was EQUIP_ON_TARGET) ──────────────────────────────────────────────────────

-- Whether one unitlist entry names the target `live` (CaptureTarget's answer). A player entry stored
-- without a realm matches the name on any realm.
local function entryMatches(entry, live)
    if entry.npcID then return live.npcID == entry.npcID end
    local name = live.player
    if not name or not entry.player then return false end
    return name == entry.player or name:match("^[^%-]+") == entry.player
end

local function targetListed(targets)
    local live = NS.TriggerParams.CaptureTarget()
    if not live then return false end
    for _, entry in ipairs(targets) do
        if entryMatches(entry, live) then return true end
    end
    return false
end

--- The target's creatureID or full player name is listed -> EQUIP. Otherwise, with unequipOnChange,
--- UNEQUIP if this trigger equipped it. No target, or a secret GUID or name, is no match (the legacy
--- raised on a nil target and never unequipped; INV §19).
function Cond.TARGET(ctx)
    if targetListed(ctx.params.targets) then return EQUIP end
    if ctx.params.unequipOnChange and ctx:DidEquip() then return UNEQUIP end
    return nil
end

-- ── TRINKET_QUEUE and FEET_QUEUE (rows 7 and 8) ───────────────────────────────────────────────

-- The item a queue would put in `slot`, or nil: the soonest-usable owned copy of the list, unless it
-- is already the outfit's item there or the slot's own item is mid-effect (an active trinket or
-- rocket boots are never swapped out).
local function queuePick(rec, slot, ids, ignoreSwapCooldown)
    if #ids == 0 then return nil end
    local Inv = NS.Inventory
    local info = Inv.NextCooldownItem(ids, ignoreSwapCooldown)
    if not info then return nil end
    if Inv.Cache():Same(info, rec.items and rec.items[slot]) or Inv.SlotItemActive(slot) then return nil end
    return info
end

-- One Batch: the picks go into the outfit, then one equipment update is asked for.
local function storePicks(id, slotA, infoA, slotB, infoB)
    local O, II = NS.Outfits, NS.ItemInfo
    if infoA then O.SetItem(id, slotA, II.Snapshot(infoA)) end
    if infoB then O.SetItem(id, slotB, II.Snapshot(infoB)) end
    NS.Equip.Request()
end

local function runQueue(ctx, slotA, idsA, slotB, idsB, ignoreSwapCooldown)
    if not ctx:IsWorn() then return nil end
    local rec = ctx.outfit
    local infoA = queuePick(rec, slotA, idsA, ignoreSwapCooldown)
    local infoB = slotB and queuePick(rec, slotB, idsB, ignoreSwapCooldown) or nil
    if infoA or infoB then NS.Equip.Batch(storePicks, ctx.outfitId, slotA, infoA, slotB, infoB) end
    return nil
end

--- Each tick while worn: per trinket slot, the highest listed trinket that is off cooldown (the swap
--- cooldown ignored, as before) goes into the outfit and is worn. No verdict: the outfit's items
--- change, the stack does not. An Equipment Manager set is refused by the binder (refuseEM).
function Cond.TRINKET_QUEUE(ctx)
    local p = ctx.params
    return runQueue(ctx, "Trinket0Slot", p.trinkets, "Trinket1Slot", p.trinkets2, true)
end

--- As TRINKET_QUEUE for the feet: the listed boots usable soonest (the swap cooldown counted, as the
--- legacy FEET_QUEUE counted it). An Equipment Manager set is refused at bind too (refuseEM, design
--- §6.8.1 row 8 "as #7"): EM.SetItem re-saves the set from what is worn, so the pick would never land
--- and every tick would save the set again.
function Cond.FEET_QUEUE(ctx)
    return runQueue(ctx, "FeetSlot", ctx.params.boots, nil, nil, false)
end

-- ── IN_ZONES (row 9) ──────────────────────────────────────────────────────────────────────────

local function listHas(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

-- The best map or one of its ancestors (parentMapID, at most MAX_MAP_DEPTH up) is listed.
local function mapListed(maps)
    if #maps == 0 then return false end
    local api = _G.C_Map
    if not (api and api.GetBestMapForUnit) then return false end
    local mapID = Secrets.PlainNumber(api.GetBestMapForUnit("player"))
    for _ = 0, MAX_MAP_DEPTH do
        if not mapID or mapID == 0 then return false end
        if listHas(maps, mapID) then return true end
        local info = api.GetMapInfo and api.GetMapInfo(mapID)
        if Secrets.IsSecret(info) or type(info) ~= "table" then return false end
        mapID = Secrets.PlainNumber(info.parentMapID)
    end
    return false
end

-- The minimap's sub-zone text, trimmed as the capture stored it, is listed (D3).
local function subzoneListed(subzones)
    if #subzones == 0 then return false end
    local get = _G.GetMinimapZoneText
    local text = get and Secrets.PlainString(get())
    if not text then return false end
    return listHas(subzones, (text:gsub("^%s+", ""):gsub("%s+$", "")))
end

--- The best map, an ancestor of it, or the minimap sub-zone is listed -> EQUIP; else UNEQUIP if
--- this trigger equipped it (by uiMapID now, never GetZoneText's localized name).
function Cond.IN_ZONES(ctx)
    local p = ctx.params
    if mapListed(p.maps) or subzoneListed(p.subzones) then return EQUIP end
    if ctx:DidEquip() then return UNEQUIP end
    return nil
end

-- ── TALENT_TREE (row 10) ──────────────────────────────────────────────────────────────────────

--- The active spec's toggle is on -> EQUIP half a second later (nothing if already worn); off ->
--- UNEQUIP half a second later. An unreadable spec changes nothing.
function Cond.TALENT_TREE(ctx)
    local spec = liveSpec()
    if not spec then return nil end
    if ctx.params["spec" .. spec] then
        if ctx:IsWorn() then return nil end
        return EQUIP, 0.5
    end
    return UNEQUIP, 0.5
end
