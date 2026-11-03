local _, NS = ...
-- modules/EquipmentManager.lua — NS.EM: the Blizzard Equipment Manager mirror (design §5.13; INV §3.5;
-- OutfitterOutfits.lua:433-1071 and Outfitter.lua:5557-5680 at 7ea3dc3).
--
-- THE MIRROR. Every Blizzard equipment set is an outfit of kind "em" whose items the set's locations
-- resolve (EM.Items); the record's `items` is the last resolved snapshot, read when a slot cannot be.
-- Sync runs on EQUIPMENT_SETS_CHANGED and from the equipment bracket's PLAYER_ENTERING_WORLD: each set
-- is matched to an em outfit by name, case-insensitively, else restored from char.emPreserved, else
-- mirrored by a new stub; an em outfit no set matched is removed (its set is already gone). A native
-- outfit of the same name is never taken for a set's mirror (the legacy FindEMOutfitByName).
--
-- ZERO SETS (Q8) means the EM is flaking: every em outfit is copied into char.emPreserved (this
-- module is its one writer) and nothing is deleted. The first sync that sees sets again clears it.
--
-- OWN SAVES (INV §16 #14, O18). Every client write runs inside withSaving: a pcall-balanced counter
-- that Sync refuses under, then a 0.5 s window it refuses inside, so the addon never re-processes the
-- EQUIPMENT_SETS_CHANGED its own save raised, whether the client fires it inside the call or later.
--
-- THE STORES (B17). StoreOnServer turns a native outfit into a set and its mirror; StoreLocally turns
-- a mirror back into a native outfit. Both carry the same settings (COPY below) and the key binding,
-- and hand them to NS.Outfits.Create as `fields`, so the record is whole when OUTFIT_ADDED binds its
-- trigger. StoreLocally deletes the set too, as the legacy one did: a set left behind would be
-- mirrored again by the next sync, beside the local copy.
--
-- THE REBUILD PATH. SetItems holds the new items as the outfit's (pendingSave), wears them, and saves
-- the set from what is worn on the next SWAP_COMPLETE; a pending save is dropped after 10 s, by any
-- slot edit to the outfit, and by a stand-down.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Get/Create/Delete/Changed/Items/BindingOf/
-- SetBinding, NS.Stack.Wear/Select, NS.Inventory.IsBankBag and NS.ItemInfo.

local EM = {}
NS.EM = EM

local Compat = NS.Compat
local L = NS.L
local ID = NS.ItemData

local NO_ICON = 134400          -- the question mark: "no icon" both ways (INV §3.5)
local NAME_BYTES = 31           -- the longest set name the client keeps
local IGNORE_WINDOW = 0.5       -- seconds an own save's EQUIPMENT_SETS_CHANGED is ignored (O18)
local PENDING_TIMEOUT = 10      -- seconds a rebuild waits for its SWAP_COMPLETE
local LOC_EMPTY, LOC_IGNORED = 0, 1   -- the client's packed "empty slot" and "ignored slot"

-- What a store carries between a native outfit and its mirror (B17), beside the key binding.
local COPY = { "trigger", "triggerParams", "triggerState", "stat", "unequipOthers", "titleID", "bar",
               "ignoreComparisons" }

-- Session state. `keep[id]` marks a mirror being removed because its set is gone: DeleteSet leaves the
-- set id alone, which the client may already have handed to a new set.
local st = { saving = 0, ignoreUntil = 0, pending = nil, timer = nil, keep = {} }
EM.__state = st   -- test seam only

local events            -- the AceEvent/AceTimer target
local swapTarget        -- the bus receiver for SWAP_COMPLETE, made once
local synced = false    -- a sync has run this session

local function store() return NS.db.char end

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

local function ensure()
    if events then return events end
    events = LibStub("AceEvent-3.0"):Embed({})
    LibStub("AceTimer-3.0"):Embed(events)
    return events
end

-- ── slots ─────────────────────────────────────────────────────────────────────────────────────

local slotMap   -- { byName = { [slotName] = slotID }, byID = { [slotID] = slotName } }

local function slots()
    if slotMap then return slotMap end
    local map, any = { byName = {}, byID = {} }, false
    for _, name in ipairs(ID.SLOT_NAMES) do
        local sid = Compat.InventorySlotID(name)
        if sid then
            map.byName[name], map.byID[sid], any = sid, name, true
        end
    end
    if any then slotMap = map end   -- a client that answered nothing is asked again next time
    return map
end

-- ── own saves ─────────────────────────────────────────────────────────────────────────────────

-- Run one client write with Sync held off, the counter balanced however it ends; a raise reaches the
-- caller after the counter is back down.
local function withSaving(fn, ...)
    st.saving = st.saving + 1
    local ok, result = pcall(fn, ...)
    st.saving = st.saving - 1
    if st.saving < 0 then st.saving = 0 end
    st.ignoreUntil = Compat.GetTime() + IGNORE_WINDOW
    if not ok then error(result, 0) end
    return result
end

-- ── the pending save ──────────────────────────────────────────────────────────────────────────

-- Drop the pending save (only `id`'s, when given) and its timer.
local function dropPending(id)
    local p = st.pending
    if not p or (id ~= nil and p.id ~= id) then return end
    if st.timer and events then events:CancelTimer(st.timer) end
    st.pending, st.timer = nil, nil
end

-- ── reading a set ─────────────────────────────────────────────────────────────────────────────

-- Where a packed location is: "worn", "bags" or "bank" and its unpacked data, or nil. A bag location
-- in a character bank tab is the bank's, whatever the BAGS bit says (Inv.IsBankBag).
local function where(packed)
    local d = Compat.EMLocation(packed)
    if not d then return nil end
    if d.isBags and d.bag ~= nil then
        if d.isBank or NS.Inventory.IsBankBag(d.bag) then return "bank", d end
        return "bags", d
    end
    if d.isBank then return "bank", d end
    if d.isPlayer then return "worn", d end
    return nil
end

local function readAt(kind, d)
    if kind == "worn" then
        local name = slots().byID[d.slot]
        return name and NS.ItemInfo.FromSlot(name)
    end
    if d.bag ~= nil then return NS.ItemInfo.FromBag(d.bag, d.slot) end
    return nil
end

-- One used slot's item: the empty marker for an empty-slot entry, the item where the set says it is,
-- else (gone, unreadable, a closed bank, a secret location) the last snapshot.
local function resolveSlot(rec, slotName, packed)
    if packed == LOC_EMPTY then return { id = 0 } end
    local kind, d
    if packed ~= nil and packed > LOC_IGNORED then kind, d = where(packed) end
    local info = kind and readAt(kind, d)
    if info then return NS.ItemInfo.Snapshot(info) end
    return rec.items and rec.items[slotName]
end

--- An em outfit's items, slot -> ItemRecord: the pending rebuild's, else the set's own resolved from
--- its locations (an ignored slot is unused), written back as the record's snapshot.
--- @param rec table
--- @return table
function EM.Items(rec)
    local p = st.pending
    if p and p.id == rec.id then return p.items end
    if not rec.setID then return rec.items or {} end
    local locs, ignored = Compat.EMLocations(rec.setID), Compat.EMIgnoredSlots(rec.setID)
    local items = {}
    for slotName, sid in pairs(slots().byName) do
        local packed = locs[sid]
        if not ignored[sid] and packed ~= LOC_IGNORED then items[slotName] = resolveSlot(rec, slotName, packed) end
    end
    rec.items = items
    return items
end

local function counts(item)
    return item ~= nil and item.id ~= 0 and not ID.PHANTOM_IDS[item.id]
end

--- An em outfit's missing and banked items, from the set's locations (OutfitterOutfits.lua:1033-1069):
--- an item the set places in the bank is banked; one it cannot place is missing.
--- @param rec table
--- @return table[] missing
--- @return table[] banked
function EM.Missing(rec)
    local items, missing, banked = EM.Items(rec), {}, {}
    local locs = rec.setID and Compat.EMLocations(rec.setID) or {}
    for _, slotName in ipairs(ID.SLOT_NAMES) do
        local item, packed = items[slotName], locs[slots().byName[slotName]]
        if counts(item) and packed ~= nil and packed ~= LOC_EMPTY and packed ~= LOC_IGNORED then
            local kind = packed > LOC_IGNORED and where(packed) or nil
            if kind == "bank" then
                banked[#banked + 1] = item
            elseif kind == nil then
                missing[#missing + 1] = item
            end
        end
    end
    return missing, banked
end

-- ── writing a set ─────────────────────────────────────────────────────────────────────────────

-- Mark for the next save every slot `enabled(slotName)` answers false for.
local function markSlots(enabled)
    Compat.EMClearIgnored()
    for slotName, sid in pairs(slots().byName) do
        if not enabled(slotName) then Compat.EMIgnoreSlot(sid, true) end
    end
end

--- Mark the slots for the next save from an items table: a slot the items leave out is ignored (an
--- empty marker is a used slot). The slot checkboxes are not read.
--- @param items table
function EM.SetSlotsFromItems(items)
    markSlots(function(slot) return items[slot] ~= nil end)
end

-- The set's own enabled slots, as a predicate.
local function setSlots(rec)
    local ignored, map = Compat.EMIgnoredSlots(rec.setID), slots().byName
    return function(slot) return not ignored[map[slot]] end
end

--- Save the worn gear into the outfit's set, in the slots marked for the save.
--- @param rec table
--- @param icon number|nil
--- @return boolean
function EM.Save(rec, icon)
    if not rec.setID then return false end
    return withSaving(Compat.EMSaveSet, rec.setID, icon)
end

--- Use one slot (the outfit store's SetItem): the set saves what is worn there now, its other slots
--- as they were. Drops a pending rebuild of this outfit.
function EM.SetItem(rec, slot, _)
    if not rec.setID then return false end
    dropPending(rec.id)
    local on = setSlots(rec)
    markSlots(function(s) return s == slot or on(s) end)
    return EM.Save(rec)
end

--- Stop using one slot: the set ignores it from now on.
function EM.ClearSlot(rec, slot)
    if not rec.setID then return false end
    dropPending(rec.id)
    local on = setSlots(rec)
    markSlots(function(s) return s ~= slot and on(s) end)
    return EM.Save(rec)
end

--- The set's icon, or nil for the 134400 wildcard and for no set.
--- @param rec table
--- @return number|nil
function EM.Icon(rec)
    local info = rec.setID and Compat.EMSetInfo(rec.setID)
    local icon = info and info.icon
    if icon == nil or icon == NO_ICON then return nil end
    return icon
end

--- Set the set's icon; nil writes the 134400 wildcard.
function EM.SetIcon(rec, icon)
    if not rec.setID then return false end
    return withSaving(Compat.EMModifySet, rec.setID, rec.name, icon or NO_ICON)
end

--- Rename the set (the outfit store renames the record when this answers true). A name longer than
--- the client keeps is refused, so the set and the record can never disagree.
--- @return boolean ok, string|nil err
function EM.Rename(rec, name)
    if #name > NAME_BYTES then return false, L["That name is too long for the Equipment Manager"] end
    if rec.setID then withSaving(Compat.EMModifySet, rec.setID, name, EM.Icon(rec) or NO_ICON) end
    return true
end

--- Delete the outfit's set (the outfit store's Delete). A mirror removed because its set is gone
--- leaves the set id alone.
function EM.DeleteSet(rec)
    dropPending(rec.id)
    if st.keep[rec.id] or not rec.setID then return false end
    return withSaving(Compat.EMDeleteSet, rec.setID)
end

--- `name` cut to 31 bytes on a UTF-8 character boundary.
--- @param name string
--- @return string
function EM.TruncateName(name)
    if #name <= NAME_BYTES then return name end
    local cut = NAME_BYTES
    while cut > 0 do
        local b = name:byte(cut + 1)
        if b < 0x80 or b >= 0xC0 then break end   -- the next byte starts a character
        cut = cut - 1
    end
    return name:sub(1, cut)
end

-- ── sync ──────────────────────────────────────────────────────────────────────────────────────

-- Every em outfit, [id] = record.
local function mirrors()
    local out = {}
    for id, rec in pairs(store().outfits) do
        if rec.kind == "em" and NS.Outfits.Get(id) then out[id] = rec end
    end
    return out
end

local function preserveAll(recs)
    local c = store()
    c.emPreserved = c.emPreserved or {}
    for _, rec in pairs(recs) do
        if type(rec.name) == "string" then c.emPreserved[rec.name:lower()] = copy(rec) end
    end
end

local function fieldsOf(rec)
    local f = {}
    for _, k in ipairs(COPY) do f[k] = rec[k] end
    return f
end

local function findByName(recs, lower)
    for id, rec in pairs(recs) do
        if type(rec.name) == "string" and rec.name:lower() == lower then return id, rec end
    end
    return nil
end

-- A mirror for a set no outfit matched: the preserved one when there is one, else a stub.
local function restoreOrStub(setID, name)
    local pres = store().emPreserved
    local saved = pres and pres[name:lower()]
    local opts = { kind = "em", setID = setID }
    if saved then opts.fields = fieldsOf(saved) end
    return NS.Outfits.Create(name, saved and saved.items or {}, opts)
end

-- Match one set; false when the set cannot be read (its name is not plain).
local function adoptSet(setID, unused)
    local info = Compat.EMSetInfo(setID)
    if not info then return false end
    local id, rec = findByName(unused, info.name:lower())
    if not id then
        restoreOrStub(setID, info.name)
        return true
    end
    unused[id] = nil
    rec.setID = setID
    NS.Outfits.Changed(id, "items")
    return true
end

-- Remove the mirrors no set matched, in id order. The sets are gone already: they are not deleted.
local function pruneUnused(unused)
    local ids = {}
    for id in pairs(unused) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        st.keep[id] = true
        NS.Outfits.Delete(id)
        st.keep[id] = nil
    end
end

local function adoptAll(ids, unused)
    local readable = true
    for _, setID in ipairs(ids) do
        if not adoptSet(setID, unused) then readable = false end
    end
    return readable
end

--- Mirror the Equipment Manager. Refused inside and just after an own save (INV §16 #14). Zero sets
--- preserve every mirror and delete nothing (Q8); a set that cannot be read holds the prune back.
--- Sends EM_SYNCED.
--- @return boolean  false when refused
function EM.Sync()
    if st.saving > 0 or Compat.GetTime() < st.ignoreUntil then return false end
    synced = true
    local unused, ids = mirrors(), Compat.EMSetIDs()
    if #ids == 0 then
        preserveAll(unused)
    elseif adoptAll(ids, unused) then
        pruneUnused(unused)
        store().emPreserved = nil
    end
    NS.SendBus(NS.MSG.EM_SYNCED)
    return true
end

-- ── the stores (B17) ──────────────────────────────────────────────────────────────────────────

local function moveBinding(from, to)
    local n = NS.Outfits.BindingOf(from)
    if n then NS.Outfits.SetBinding(to, n) end
end

-- The new outfit takes the old one's place: the binding, worn and selected, then the old one goes.
local function replace(oldId, newId)
    moveBinding(oldId, newId)
    NS.Stack.Wear(newId)
    NS.Stack.Select(newId)
    NS.Outfits.Delete(oldId)
end

--- Store a native outfit on the server: a set from its slots (the name cut to 31 bytes, the icon its
--- own or 134400), mirrored by an em outfit that carries its settings (B17) and binding, worn and
--- selected; then the native outfit is deleted. Refused at the client's cap with the EM-full popup.
--- @param id string
--- @return boolean ok, string|nil popupKey, string|nil newId
function EM.StoreOnServer(id)
    local O = NS.Outfits
    local rec = O.Get(id)
    if not rec or rec.kind == "em" then return false end
    if Compat.EMNumSets() >= Compat.EMMaxSets() then return false, "OUTFITTERREBORN_EM_FULL" end
    local name = EM.TruncateName(rec.name or "")
    EM.SetSlotsFromItems(O.Items(rec))
    withSaving(Compat.EMCreateSet, name, rec.icon or NO_ICON)
    local setID = Compat.EMSetID(name)
    if not setID then return false end
    local newId = O.Create(name, {}, { kind = "em", setID = setID, fields = fieldsOf(rec) })
    replace(id, newId)
    return true, nil, newId
end

--- Store an em outfit locally: a native outfit with the set's resolved items, its icon, settings and
--- binding, worn and selected; then the mirror and its set are deleted.
--- @param id string
--- @return string|nil newId
function EM.StoreLocally(id)
    local O = NS.Outfits
    local rec = O.Get(id)
    if not rec or rec.kind ~= "em" then return nil end
    local newId = O.Create(rec.name, EM.Items(rec), { icon = EM.Icon(rec), fields = fieldsOf(rec) })
    replace(id, newId)
    return newId
end

-- ── the rebuild path ──────────────────────────────────────────────────────────────────────────

local function expire()
    st.pending, st.timer = nil, nil
end

local function onSwapComplete()
    local p = st.pending
    if not p then return end
    dropPending()
    local rec = NS.Outfits.Get(p.id)
    if not rec then return end
    EM.SetSlotsFromItems(p.items)
    EM.Save(rec)
    NS.Print(L["Saved outfit to Equipment Manager"])
    NS.Outfits.Changed(p.id, "items")
end

--- The rebuild path: `items` become the outfit's until the next SWAP_COMPLETE, when the worn gear is
--- saved into the set from their slots; worn now. Dropped after 10 s.
--- @param rec table
--- @param items table
function EM.SetItems(rec, items)
    local t = ensure()
    if not swapTarget then
        swapTarget = NS.NewBusTarget()
        if swapTarget then swapTarget:RegisterMessage(NS.MSG.SWAP_COMPLETE, onSwapComplete) end
    end
    dropPending()
    st.pending = { id = rec.id, items = copy(items) }
    st.timer = t:ScheduleTimer(expire, PENDING_TIMEOUT)
    NS.Stack.Wear(rec.id)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

local function onSetsChanged()
    if NS.IsStoodDown() then return end
    EM.Sync()
end

--- The stand-down (design §5.12): the pending save and its timer go, the counter is zeroed, and
--- nothing stays registered.
function EM.Suspend()
    dropPending()
    st.saving = 0
    if events then
        events:UnregisterAllEvents()
        events:CancelAllTimers()
    end
end

--- The stand-up: EQUIPMENT_SETS_CHANGED registered from scratch, and the mirror brought up to date
--- when a sync has run this session (the sets may have changed while the addon was down).
function EM.Resume()
    local t = ensure()
    EM.Suspend()
    NS.SafeRegisterEvent(t, "EQUIPMENT_SETS_CHANGED", onSetsChanged, NS.rejectedEvents)
    if synced then EM.Sync() end
end
