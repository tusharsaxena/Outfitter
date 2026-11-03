local _, NS = ...
-- modules/OutfitStack_Watch.lua — the inventory watch: the temporary outfit, window-open recording and
-- SWAP_COMPLETE (design §5.9; Outfitter.lua:1938-1983, 4369-4536 at 7ea3dc3). Extends NS.Stack
-- (modules/OutfitStack.lua), whose Resume installs the receiver.
--
-- ON INVENTORY_CHANGED, inside one NS.Equip.Batch:
--   1. the worn gear is diffed against what the Watch last saw (II.Exact plus an id check, which
--      replaces GetInventoryOutfit's 15-field compare and its UpgradeItemID typo, INV §19); the
--      off-hand is skipped under a two-hander the player cannot grip one-handed;
--   2. what the stack expected is subtracted;
--   3. anything left is a hand swap: with a selection and the window open it is recorded into the
--      selected outfit ("Adding %s to %s outfit"), else it goes into the temporary outfit on top;
--      either way the expected outfit takes it;
--   4. with no update pending and the worn gear the expected outfit, SWAP_COMPLETE.
--
-- THE TEMPORARY OUTFIT (UpdateTemporaryOutfit) merges into the top temp entry or becomes a new one,
-- then loses what the stack below it already expects; an emptied one leaves the stack.
--
-- The comparisons are the cache's (cache:Same), with FULL_ALT_SLOT: a ring or a trinket worn in the
-- pair's other slot is the same ring.
--
-- CALLS (at call time, no nil guard; design §12): NS.Inventory.Cache, NS.ItemInfo, NS.Outfits,
-- NS.Equip.Batch/Pending and NS.Dock.IsShown.

local St = NS.Stack
local L = NS.L
local ID = NS.ItemData

local OFF_HAND = "SecondaryHandSlot"

local current   -- slot -> ItemRecord: the worn gear as the Watch last saw it
local bus       -- the receiver, built once

-- Every slot as an outfit would store it: the empty marker for an empty slot.
local function snapshotWorn()
    local out = {}
    local worn = NS.Inventory.Cache().worn
    for _, slot in ipairs(ID.SLOT_NAMES) do
        local info = worn[slot]
        out[slot] = info and NS.ItemInfo.Snapshot(info) or NS.ItemInfo.EMPTY
    end
    return out
end

local function sameCopy(a, b)
    return a ~= nil and b ~= nil and a.id == b.id and NS.ItemInfo.Exact(a, b)
end

local function holdsBothHands(item)
    return item ~= nil and item.id ~= 0 and NS.ItemInfo.UsesBothHands(item)
end

-- The slots whose item changed since `prev` (GetNewItemsOutfit), each with what is worn there now.
local function diffAgainst(prev, now)
    local out, any = {}, false
    local skipOffHand = holdsBothHands(prev.MainHandSlot)
    for _, slot in ipairs(ID.SLOT_NAMES) do
        if not (slot == OFF_HAND and skipOffHand) and not sameCopy(prev[slot], now[slot]) then
            out[slot] = now[slot]
            any = true
        end
    end
    return out, any
end

-- `item` in `slot` is what `other` holds there, or in the pair's other slot.
local function matches(cache, other, slot, item)
    if cache:Same(item, other[slot]) then return true end
    local alt = ID.FULL_ALT_SLOT[slot]
    return alt ~= nil and cache:Same(item, other[alt])
end

local function subtract(items, other, cache)
    for slot, item in pairs(items) do
        if matches(cache, other, slot, item) then items[slot] = nil end
    end
end

local function sameOutfit(a, b, cache)
    for _, slot in ipairs(ID.SLOT_NAMES) do
        if not matches(cache, b, slot, a[slot]) then return false end
    end
    return true
end

-- UpdateTemporaryOutfit (Outfitter.lua:4481-4536).
local function updateTemp(newItems, cache)
    local s = NS.db.char.stack
    local top = s[#s]
    local existing = top and top.temp and top or nil
    local temp = existing and existing.temp or {}
    for slot, item in pairs(newItems) do temp[slot] = item end
    subtract(temp, St.Layered(existing), cache)
    if next(temp) == nil then
        if existing then
            table.remove(s, #s)
            St.__collapseTemps()
        end
    elseif not existing then
        s[#s + 1] = { temp = temp }
    end
end

-- The slots of the outfit in the "unknown" state BEFORE the swap (used, its item not the one worn):
-- the window's tri-state as the player saw it, which a hand swap never overwrites (INV §3.2).
local function unknownBefore(rec, prev, cache)
    local out = {}
    local items = NS.Outfits.Items(rec)
    for slot, want in pairs(items) do
        if not cache:Same(want, prev[slot]) then out[slot] = true end
    end
    return out
end

-- Window-open recording (Outfitter.lua:4369, OutfitterOutfits.lua:46-60).
local function recordInto(id, newItems, prev, cache)
    local rec = NS.Outfits.Get(id)
    local unknown = unknownBefore(rec, prev, cache)
    NS.Outfits.AddNewItems(id, newItems, unknown)
    for slot, item in pairs(newItems) do
        if not unknown[slot] and item.id ~= 0 then
            NS.Print(L["Adding %s to %s outfit"]:format(NS.SafeToString(item.name or item.link), tostring(rec.name)))
        end
    end
end

local function absorb(newItems, prev, cache)
    local sel = St.Selected()
    if sel and NS.Dock.IsShown() then
        recordInto(sel, newItems, prev, cache)
    else
        updateTemp(newItems, cache)
    end
    local exp = St.Expected()
    for slot, item in pairs(newItems) do exp[slot] = item end
end

--- The inventory changed (InventoryChanged, Outfitter.lua:1938-1983). Runs inside NS.Equip.Batch.
function St.OnInventoryChanged()
    local cache = NS.Inventory.Cache()
    local now = snapshotWorn()
    local prev = current or now
    current = now
    local newItems, any = diffAgainst(prev, now)
    if any then
        subtract(newItems, St.Expected(), cache)
        if next(newItems) ~= nil then absorb(newItems, prev, cache) end
    end
    if not NS.Equip.Pending() and sameOutfit(now, St.Expected(), cache) then
        NS.SendBus(NS.MSG.SWAP_COMPLETE)
    end
end

--- The receiver (St.Resume): once per session; the bus record drops and replays it across a
--- stand-down.
function St.__watchInstall()
    if bus then return end
    bus = NS.NewBusTarget()
    if not bus then return end
    bus:RegisterMessage(NS.MSG.INVENTORY_CHANGED, function()
        NS.Equip.Batch(St.OnInventoryChanged)
    end)
end

--- What the Watch compares the next change with: the gear worn now (St.Init, St.Resume).
function St.__watchReset()
    current = snapshotWorn()
end
