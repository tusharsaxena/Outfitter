local _, NS = ...
-- modules/Equip_Moves.lua — NS.Moves: pickup, a move to an empty bag slot, the empty-slot lists and
-- /or unequip (design §5.11; OutfitterEquipment.lua:711-797, Outfitter.lua:2119-2147, 4099-4195 at
-- 7ea3dc3).
--
-- A LOCATION is a bag slot `{ bag, slot }` or an equipment slot `{ slotID, slotName }` (the infos'
-- `loc`, Compat.PickupItemLocation's shapes). An EMPTY-SLOT LIST is `{ { bag, slot, bagType } ... }`,
-- bagType being the container's family bits (0 = a general bag); ToEmpty spends from it.
--
-- The client is read and written only through NS.Compat. A container slot whose link the client
-- hands out as a secret reads empty there (Q12); the walk stops at the container's free count, so
-- it cannot list more slots than the client says are free.

local Moves = {}
NS.Moves = Moves

local Compat = NS.Compat
local L = NS.L

local GENERAL = 0              -- the general bag family (Outfitter.lua:3945)
local REAGENT_FALLBACK = 5     -- the reagent bag, when the client has no NUM_TOTAL_EQUIPPED_BAG_SLOTS

-- The failure line ToEmpty prints for each error key; any other key reads as `bagsFull`.
local ERRORS = {
    bagsFull     = L["Can't remove %s because all bags are full"],
    withdrawFull = L["Can't withdraw %s because all bags are full"],
    bankFull     = L["Can't deposit %s because all bank bags are full"],
}

--- Pick up (or drop onto) a location. False for a location of neither shape.
--- @param loc table
--- @return boolean
function Moves.Pickup(loc)
    return Compat.PickupItemLocation(loc)
end

-- ── empty-slot lists ──────────────────────────────────────────────────────────────────────────

-- Append the bag's empty slots to `out`, at most as many as the client says are free.
local function walkBag(bag, out)
    local free, family = Compat.ContainerNumFreeSlots(bag)
    if free <= 0 then return end
    local found = 0
    for slot = 1, Compat.ContainerNumSlots(bag) do
        if not Compat.ContainerItemLink(bag, slot) then
            out[#out + 1] = { bag = bag, slot = slot, bagType = family or GENERAL }
            found = found + 1
            if found >= free then return end
        end
    end
end

--- The carried bags' empty slots, from the last bag down to the backpack (Outfitter.lua:4156). The
--- reagent bag, the last equipped one, takes no gear and is left out.
--- @return table[]
function Moves.EmptyBagSlots()
    local out = {}
    local last = (Compat.LastEquippedBagID() or REAGENT_FALLBACK) - 1
    for bag = last, 0, -1 do walkBag(bag, out) end
    return out
end

--- The character bank's empty slots (Outfitter.lua:4176); none while the bank is closed, as the
--- client answers no slots for it then. The warband bank is not used (O19).
--- @return table[]
function Moves.EmptyBankSlots()
    local out = {}
    for _, bag in ipairs(Compat.BankBagIDs()) do walkBag(bag, out) end
    return out
end

-- ── moves ─────────────────────────────────────────────────────────────────────────────────────

local function linkAt(loc)
    if loc.bag ~= nil then return Compat.ContainerItemLink(loc.bag, loc.slot) end
    if loc.slotID ~= nil then return Compat.InventoryItemLink(loc.slotID) end
    return nil
end

-- Take the slot an item of family `itemType` goes in from `slots`: a specialty bag that takes it
-- first, else a general bag (OutfitterEquipment.lua:743-767). Gear (family 0) never lands in a
-- specialty bag.
local function pickTarget(slots, itemType)
    if not slots then return nil end
    if itemType ~= GENERAL then
        for i, s in ipairs(slots) do
            if Compat.BitAnd(s.bagType, itemType) ~= 0 then return table.remove(slots, i) end
        end
    end
    for i, s in ipairs(slots) do
        if (s.bagType or GENERAL) == GENERAL then return table.remove(slots, i) end
    end
    return nil
end

--- Move the item at `loc` into a slot from `slots` (which loses it). True when moved, or when `loc`
--- holds nothing. When no slot takes it, prints the `errKey` line (`bagsFull`, the default;
--- `withdrawFull`; `bankFull`) with the item's link and answers false.
--- @param loc table
--- @param slots table[]|nil
--- @param errKey string|nil
--- @return boolean ok
function Moves.ToEmpty(loc, slots, errKey)
    local link = linkAt(loc)
    if not link then return true end
    local target = pickTarget(slots, Compat.ItemFamily(link) or GENERAL)
    if not target then
        NS.Print((ERRORS[errKey] or ERRORS.bagsFull):format(NS.SafeToString(link)))
        return false
    end
    Compat.ClearCursor()   -- holding anything already makes the pickups go wrong
    Moves.Pickup(loc)
    Moves.Pickup(target)
    return true
end

-- The worn slot `arg` names: a slot number, or an item's name (case-insensitive, the plain name).
local function slotFor(arg)
    local n = tonumber(arg)
    for _, slotName in ipairs(NS.ItemData.SLOT_NAMES) do
        if n and tostring(n) == arg then
            if Compat.InventorySlotID(slotName) == n then return slotName end
        else
            local info = NS.ItemInfo.FromSlot(slotName)
            if info and info.name and info.name:lower() == arg:lower() then return slotName end
        end
    end
    return nil
end

--- /or unequip: move one worn item, named or by slot number, into the bags. On a name or slot that
--- holds nothing, prints `"Couldn't find an item named %s"` and RETURNS (the legacy function went
--- on to pick up nothing; INV §4, §19). A full bag prints ToEmpty's line.
--- @param arg string
--- @return boolean ok
--- @return string|nil msg  the line printed on a miss
function Moves.UnequipByName(arg)
    arg = tostring(arg or "")
    local slotName = arg ~= "" and slotFor(arg)
    local slotID = slotName and Compat.InventorySlotID(slotName)
    local loc = slotID and { slotID = slotID, slotName = slotName }
    if not loc or not linkAt(loc) then
        local msg = L["Couldn't find an item named %s"]:format(arg)
        NS.Print(msg)
        return false, msg
    end
    return Moves.ToEmpty(loc, Moves.EmptyBagSlots(), "bagsFull")
end
