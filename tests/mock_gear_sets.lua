-- tests/mock_gear_sets.lua — C_EquipmentSet for tests/mock_gear.lua (design §9.2 "mock_gear"):
-- real set tables whose items are the gear half's own instances, so a set follows an item wherever
-- it moves, as the client's sets follow an item's GUID. GetItemLocations answers the packed
-- location (0 for an empty-slot entry, 1 for an ignored slot, -1 for an item that is gone),
-- UseEquipmentSet wears the set FOR REAL through the gear half's move rules, and `M.__emFlake =
-- true` answers zero sets without forgetting any (Q8); clearing it restores them.
--
-- A file of its own so tests/mock_gear.lua keeps headroom under the 1000-line budget
-- (test_file_budget). Loaded by tests/wow_mock.lua and handed to the gear installer as deps.sets.

local Sets = {}

local PLAYER_BIT, BAGS_BIT = 0x00100000, 0x00200000

--- The packed location the client's sets answer: PLAYER + slot for a worn item, PLAYER + BAGS +
--- bag * 256 + slot for a carried one (ITEM_INVENTORY_BAG_BIT_OFFSET is 8).
local function pack(loc)
    if loc.equip then return PLAYER_BIT + loc.equip end
    return PLAYER_BIT + BAGS_BIT + loc.bag * 256 + loc.slot
end
Sets.pack = pack

--- Install C_EquipmentSet and EquipmentManager_GetLocationData on `M`, over the gear state `G`
--- and the move helpers `h` mock_gear.lua hands over, walking the slots in `EQUIP_IDS` order.
function Sets.install(M, G, h, EQUIP_IDS)
    local function visible()
        if M.__emFlake then return {} end
        local ids = {}
        for id in pairs(G.sets) do ids[#ids + 1] = id end
        table.sort(ids)
        return ids
    end
    local function setOf(id) return not M.__emFlake and G.sets[id] or nil end
    local function snapshot(set)
        set.items, set.ignored = {}, {}
        for _, slotID in ipairs(EQUIP_IDS) do
            if G.ignoreForSave[slotID] then set.ignored[slotID] = true
            else set.items[slotID] = G.worn[slotID] or false end
        end
    end

    local EM = {}
    M.C_EquipmentSet = EM
    function EM.GetEquipmentSetIDs() return visible() end
    function EM.GetNumEquipmentSets() return #visible() end
    function EM.CanUseEquipmentSets() return true end
    function EM.GetEquipmentSetID(name)
        for _, id in ipairs(visible()) do if G.sets[id].name == name then return id end end
        return nil
    end
    function EM.GetEquipmentSetInfo(id)
        local set = setOf(id)
        if not set then return nil end
        local numItems, numEquipped, numInInventory, numLost, numIgnored = 0, 0, 0, 0, 0
        for _, slotID in ipairs(EQUIP_IDS) do
            local inst = set.items[slotID]
            if set.ignored[slotID] then numIgnored = numIgnored + 1
            elseif inst then
                numItems = numItems + 1
                local loc = h.where(inst)
                if not loc then numLost = numLost + 1
                elseif loc.equip == slotID then numEquipped = numEquipped + 1
                else numInInventory = numInInventory + 1 end
            end
        end
        return set.name, set.icon, set.id, numEquipped == numItems and numItems > 0, numItems, numEquipped,
               numInInventory, numLost, numIgnored
    end
    function EM.GetItemLocations(id)
        local set = setOf(id)
        if not set then return nil end
        local out = {}
        for _, slotID in ipairs(EQUIP_IDS) do
            local inst = set.items[slotID]
            if set.ignored[slotID] then out[slotID] = 1
            elseif not inst then out[slotID] = 0
            else
                local loc = h.where(inst)
                out[slotID] = loc and pack(loc) or -1
            end
        end
        return out
    end
    function EM.GetItemIDs(id)
        local set = setOf(id)
        if not set then return nil end
        local out = {}
        for slotID, inst in pairs(set.items) do if inst then out[slotID] = inst.def.id end end
        return out
    end
    function EM.GetIgnoredSlots(id)
        local set = setOf(id)
        if not set then return nil end
        local out = {}
        for _, slotID in ipairs(EQUIP_IDS) do out[slotID] = set.ignored[slotID] == true end
        return out
    end
    function EM.CreateEquipmentSet(name, icon)
        h.record("CreateEquipmentSet", name, icon)
        if EM.GetNumEquipmentSets() >= M.MAX_EQUIPMENT_SETS_PER_PLAYER then return end
        local id = G:addSet({ name = name, icon = icon })
        snapshot(G.sets[id])
        h.queue("EQUIPMENT_SETS_CHANGED")
    end
    function EM.SaveEquipmentSet(id, icon)
        h.record("SaveEquipmentSet", id, icon)
        local set = setOf(id)
        if not set then return end
        snapshot(set)
        if icon then set.icon = icon end
        h.queue("EQUIPMENT_SETS_CHANGED")
    end
    function EM.ModifyEquipmentSet(id, newName, newIcon)
        h.record("ModifyEquipmentSet", id, newName, newIcon)
        local set = setOf(id)
        if not set then return end
        set.name = newName or set.name
        set.icon = newIcon or set.icon
        h.queue("EQUIPMENT_SETS_CHANGED")
    end
    function EM.DeleteEquipmentSet(id)
        h.record("DeleteEquipmentSet", id)
        if not setOf(id) then return end
        G.sets[id] = nil
        h.queue("EQUIPMENT_SETS_CHANGED")
    end
    function EM.IgnoreSlotForSave(slotID) h.record("IgnoreSlotForSave", slotID); G.ignoreForSave[slotID] = true end
    function EM.UnignoreSlotForSave(slotID) h.record("UnignoreSlotForSave", slotID); G.ignoreForSave[slotID] = nil end
    function EM.ClearIgnoredSlotsForSave() h.record("ClearIgnoredSlotsForSave"); G.ignoreForSave = {} end
    function EM.IsSlotIgnoredForSave(slotID) return G.ignoreForSave[slotID] == true end
    function EM.EquipmentSetContainsLockedItems() return false end
    -- Wear the set FOR REAL, slot by slot, under the same rules a hand-made plan meets.
    function EM.UseEquipmentSet(id)
        h.record("UseEquipmentSet", id)
        local set = setOf(id)
        if not set or G.cursor then return false end
        for _, slotID in ipairs(EQUIP_IDS) do
            local inst = set.items[slotID]
            if not set.ignored[slotID] then
                local loc = inst and h.where(inst)
                if inst and loc and loc.equip ~= slotID then
                    -- A banked item stays put while the bank is closed (h.lift refuses it).
                    if h.lift(loc) and not h.equipFromCursor(slotID) then h.clearCursor() end
                elseif inst == false and G.worn[slotID] then
                    local dest = h.freeSlot(G.worn[slotID])
                    if dest then h.lift({ equip = slotID }); h.dropInBag(dest) end
                end
            end
        end
        h.queue("EQUIPMENT_SWAP_FINISHED", true, id)
        return true
    end

    M.EquipmentManager_GetLocationData = function(location)
        if type(location) ~= "number" or location <= 1 then return {} end
        local flags = math.floor(location / PLAYER_BIT)
        local data = { isPlayer = flags % 2 == 1, isBags = math.floor(flags / 2) % 2 == 1,
                       isBank = math.floor(flags / 4) % 2 == 1, slot = location % 256 }
        if data.isBags then data.bag = math.floor(location / 256) % 256 end
        return data
    end
end

return Sets
