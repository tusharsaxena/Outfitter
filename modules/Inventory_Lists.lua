local _, NS = ...
-- modules/Inventory_Lists.lua — the missing, unused, BoE, warbound, in-use and cooldown lists and their
-- sections (design §5.5). Extends NS.Inventory (modules/Inventory.lua, which loads first).
--
-- Every list reads the cache through Inv.Cache() and matches with its Find family; the one that must
-- not count an item twice (Unused) does it inside one cache:BeginPass(), so its claims end with it
-- (B9). The outfits are read through NS.Outfits (Categories, Ids, Get, Items), which also resolves an
-- Equipment Manager outfit's items; an EM outfit's missing items are NS.EM's to answer.
--
-- COOLDOWNS (the trinket queue). NextCooldownItem reads plain cooldowns only, through Compat, whose
-- `enabled` is already a boolean (B19: the container call answers one, the inventory call a 1/0).
-- An item with no use effect counts as 30 s (lowest priority) and a bag item needs a swap, so it is
-- never under 30 s unless the caller ignores the swap cooldown (Q10, INV §16 #16). A cooldown whose
-- start cannot be read (a secret) counts as 30 s too.
--
-- SlotItemActive reads the use effect's duration off the tooltip with the two `L` patterns below:
-- no GlobalString or ID route gives it yet (O15, the D8 deviation row in docs/ARCHITECTURE.md).
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Categories/Ids/Get/Items, NS.EM.Missing.

local Inv = NS.Inventory
local Compat = NS.Compat
local L = NS.L

local SWAP_FLOOR = 30      -- a bag item's minimum, and an item with no use effect
local SECTIONS = {
    { key = "unused",   labelKey = "Odds 'n ends" },
    { key = "warbound", labelKey = "Warbound until equipped" },
    { key = "boe",      labelKey = "Unopened" },
}

-- ── outfits ───────────────────────────────────────────────────────────────────────────────────

-- fn(id, rec, items) for every stored outfit, category by category, in each category's order.
local function eachOutfit(fn)
    local O = NS.Outfits
    for _, category in ipairs(O.Categories()) do
        for _, id in ipairs(O.Ids(category)) do
            local rec = O.Get(id)
            if rec then fn(id, rec, O.Items(rec) or {}) end
        end
    end
end

local function counts(item)
    return item ~= nil and item.id ~= 0 and not NS.ItemData.PHANTOM_IDS[item.id]
end

--- An outfit's missing and banked items: each item no cached copy (or alias) matches is missing; one
--- found in a bank bag is banked. Phantoms and empty markers are skipped. EM outfits ask NS.EM.
--- @param rec table  an outfit record (design §3.3)
--- @return table[] missing
--- @return table[] banked
function Inv.Missing(rec)
    if rec.kind == "em" then return NS.EM.Missing(rec) end
    local cache = Inv.Cache()
    local missing, banked = {}, {}
    local items = rec.items or {}
    for _, slotName in ipairs(NS.ItemData.SLOT_NAMES) do
        local item = items[slotName]
        if counts(item) then
            local info = cache:FindOrAlt(item)
            if not info then
                missing[#missing + 1] = item
            elseif info.loc and Inv.IsBankBag(info.loc.bag) then
                banked[#banked + 1] = item
            end
        end
    end
    return missing, banked
end

--- Odds 'n Ends: the cached items no outfit uses, less IGNORED_UNUSED and warbound items. Every
--- outfit's items are claimed in one pass first, so two copies serve two outfits and a deleted
--- outfit frees its items at once (B9).
--- @return table[] infos
function Inv.Unused()
    local cache = Inv.Cache()
    local pass = cache:BeginPass()
    eachOutfit(function(_, _, items)
        for _, slotName in ipairs(NS.ItemData.SLOT_NAMES) do
            local item = items[slotName]
            if item and item.id ~= 0 then cache:FindOrAlt(item, pass) end
        end
    end)
    local ignored, out = NS.ItemData.IGNORED_UNUSED, {}
    for _, info in ipairs(cache.all) do
        if not pass.claimed[info] and not ignored[info.id] and NS.ItemInfo.Bind(info) ~= "warbound" then
            out[#out + 1] = info
        end
    end
    return out
end

-- Every bag item that goes in a slot and passes `pred`, over the bags in range (the cache leaves
-- BoEs out, so these lists walk the bags themselves).
local function walkBags(pred)
    local out = {}
    for _, bag in ipairs(Inv.BagIDs()) do
        for slot = 1, Compat.ContainerNumSlots(bag) do
            local info = NS.ItemInfo.FromBag(bag, slot)
            if info and info.slot and pred(info) then out[#out + 1] = info end
        end
    end
    return out
end

--- The carried gear that still binds when equipped.
--- @return table[]
function Inv.BoE()
    return walkBags(function(info) return NS.ItemInfo.Bind(info) == "boe" end)
end

--- The carried gear that is warbound until equipped.
--- @return table[]
function Inv.Warbound()
    return walkBags(function(info) return NS.ItemInfo.Bind(info) == "warbound" end)
end

-- Worn copies (no bag) sort ahead of carried ones, then by bag, then by slot.
local function locationBefore(a, b)
    local la, lb = a.loc or {}, b.loc or {}
    local ba, bb = la.bag or -100, lb.bag or -100
    if ba ~= bb then return ba < bb end
    if la.bag == nil then return (la.slotID or 0) < (lb.slotID or 0) end
    return (la.slot or 0) < (lb.slot or 0)
end

--- The window's item order (Outfitter.lua:3096): level descending, then name (an uncached name last),
--- then id, then location.
--- @return boolean
function Inv.CompareItems(a, b)
    local la, lb = a.level or 0, b.level or 0
    if la ~= lb then return la > lb end
    if a.name ~= b.name then
        if a.name == nil then return false end
        if b.name == nil then return true end
        return a.name < b.name
    end
    if (a.id or 0) ~= (b.id or 0) then return (a.id or 0) < (b.id or 0) end
    return locationBefore(a, b)
end

local SECTION_LIST = { unused = Inv.Unused, warbound = Inv.Warbound, boe = Inv.BoE }

--- The window's item sections after the outfits (INV §7.2): Odds 'n Ends, Warbound, then the BoEs,
--- each sorted with CompareItems; an empty one is left out. labelKey is the section's NS.L key.
--- @return table[] { { key, labelKey, items } }
function Inv.ItemSections()
    local out = {}
    for _, s in ipairs(SECTIONS) do
        local items = SECTION_LIST[s.key]()
        if #items > 0 then
            table.sort(items, Inv.CompareItems)
            out[#out + 1] = { key = s.key, labelKey = s.labelKey, items = items }
        end
    end
    return out
end

-- The outfit slots an item can sit in: both fingers, both trinkets, both hands for a one-hander.
local PAIRS = {
    Finger0Slot = { "Finger0Slot", "Finger1Slot" },
    Trinket0Slot = { "Trinket0Slot", "Trinket1Slot" },
}
local HANDS = { "MainHandSlot", "SecondaryHandSlot" }

local function slotsFor(info)
    if PAIRS[info.slot] then return PAIRS[info.slot] end
    if NS.ItemInfo.MetaSlot(info) == "Weapon0Slot" then return HANDS end
    return { info.slot }
end

--- The ids of the outfits that use `info` (an info or a record with a slot), in store order: the
--- item's own slot, or either slot of its pair (OutfitterOutfits.lua:325-349).
--- @param info table|nil
--- @return string[]
function Inv.OutfitsUsing(info)
    local out = {}
    if not (info and info.slot) then return out end
    local cache, slots = Inv.Cache(), slotsFor(info)
    eachOutfit(function(id, _, items)
        for _, slotName in ipairs(slots) do
            local item = items[slotName]
            if item and cache:Same(item, info) then
                out[#out + 1] = id
                return
            end
        end
    end)
    return out
end

-- ── cooldowns ─────────────────────────────────────────────────────────────────────────────────

--- Whether the item has a use effect ("Use:"): it has an item spell. False for a secret link.
--- @param link any
--- @return boolean
function Inv.HasUseEffect(link)
    local name, spellID = Compat.ItemSpell(link)
    return name ~= nil or spellID ~= nil
end

local function cooldownOf(info)
    local loc = info.loc or {}
    if loc.bag then return Compat.ContainerItemCooldown(loc.bag, loc.slot) end
    return Compat.InventoryItemCooldown(loc.slotID)
end

-- Seconds until `info` could be used: its running cooldown, 0 when ready with a use effect, 30 with
-- none or an unreadable start; a bag copy needs a swap, so 30 at least unless the caller ignores it.
local function remaining(info, ignoreSwapCooldown)
    local start, duration, enabled = cooldownOf(info)
    local secs
    if start == nil then
        secs = SWAP_FLOOR
    elseif enabled == true and start ~= 0 then
        secs = (duration or 0) - (Compat.GetTime() - start)
    elseif Inv.HasUseEffect(info.link) then
        secs = 0
    else
        secs = SWAP_FLOOR
    end
    if info.loc and info.loc.bag and not ignoreSwapCooldown and secs < SWAP_FLOOR then secs = SWAP_FLOOR end
    return secs
end

--- Of the owned copies of `itemIDs`, the one that can be used soonest, and in how many seconds
--- (script API FindNextCooldownItem, OutfitterInventory.lua:5-60). nil when none is owned.
--- @param itemIDs number[]
--- @param ignoreSwapCooldown boolean|nil
--- @return table|nil info
--- @return number|nil seconds
function Inv.NextCooldownItem(itemIDs, ignoreSwapCooldown)
    local cache = Inv.Cache()
    local best, bestSecs
    for _, id in ipairs(itemIDs or {}) do
        for _, info in ipairs(cache.byID[id] or {}) do
            local secs = remaining(info, ignoreSwapCooldown)
            if not bestSecs or secs < bestSecs then best, bestSecs = info, secs end
        end
    end
    return best, bestSecs
end

-- The use effect's duration in seconds from the tooltip, 0 when it shows none; kept per item id.
local DURATION_PATTERNS = { L["^Use:.*for (%d+) sec"], L["^Use:.*Lasts (%d+) sec"] }
local durations = {}

local function useDuration(info)
    local known = durations[info.id]
    if known then return known end
    local secs = 0
    for _, line in ipairs(Compat.TooltipLines(info.loc or info.link)) do
        for _, pattern in ipairs(DURATION_PATTERNS) do
            local n = line.text:match(pattern)
            if n then secs = tonumber(n) or 0 end
        end
        if secs > 0 then break end
    end
    durations[info.id] = secs
    return secs
end

--- Whether the worn item in `slotName` has its use effect running now (the trinket queue leaves it
--- on): its cooldown started less than the effect's duration ago.
--- @param slotName string
--- @return boolean
function Inv.SlotItemActive(slotName)
    local info = NS.ItemInfo.FromSlot(slotName)
    if not info then return false end
    local start = Compat.InventoryItemCooldown(info.loc.slotID)
    if not start or start == 0 then return false end
    return Compat.GetTime() < start + useDuration(info)
end
