local _, NS = ...
-- modules/Inventory.lua — NS.Inventory: the bag and equipment scan, its cache and the bank-open rules
-- (design §5.4). The lists built on the cache (missing, unused, BoE, warbound, in-use, cooldowns)
-- are modules/Inventory_Lists.lua's.
--
-- THE SCAN. Sync compares each worn slot's and each bag slot's PLAIN link (Secrets.PlainString, or
-- "" for an empty or secret slot: Q12) with the last one it saw. A changed bag, or a change in the
-- bag range, flushes that part of the cache and announces INVENTORY_CHANGED (equippedChanged,
-- bagsChanged). The bag and inventory events only schedule it: ScheduleSync is a 0.01 s debounce
-- (cancel, then reschedule). They are dropped during a load (NS.Equip.SuspendedForLoad, between
-- PLAYER_LEAVING_WORLD and PLAYER_ENTERING_WORLD); PLAYER_ENTERING_WORLD itself always flushes and
-- schedules.
--
-- THE CACHE is built lazily, part by part (the worn slots, then each bag in Inv.BagIDs order), from
-- NS.ItemInfo infos: worn gear, and bag gear (an INVTYPE_TO_SLOT entry) that is not an unbound BoE.
-- The minimum-level check stays off (Q3: "new drops pre WoD are showing as minLevel 100 despite only
-- requiring 90", Outfitter.lua:5851). GET_ITEM_INFO_RECEIVED flushes it, through ONE registration on
-- this module's own target (B5: the legacy cache registered one per instance and never let go).
--
-- CLAIMS (B9). A matching pass that must not hand one item to two slots opens `cache:BeginPass()`
-- and passes it to Find. The claims live in `pass.claimed[info]`, never on the item, so the next pass
-- starts clean.
--
-- THE BANK. The bag range is 0 through the reagent bag; with the bank open the character bank's
-- containers (Compat.BankBagIDs) join it. Those containers are the bank-bag set IsBankBag answers
-- from, which replaces the legacy `i > NUM_TOTAL_EQUIPPED_BAG_SLOTS or i < 0` guess. The warband bank
-- is not scanned (INV §3.4, O19; docs/known-limitations.md).
--
-- CALLS (at call time, no nil guard; design §12): NS.Equip.SuspendedForLoad from the scan events.

local Inv = {}
NS.Inventory = Inv

local Compat = NS.Compat

local SYNC_DELAY = 0.01   -- the legacy RescheduleTask(0.01, Synchronize)

local events        -- the AceEvent (and AceTimer) target for the game events
local unitFrame     -- the per-unit frame for the player's UNIT_INVENTORY_CHANGED
local syncTimer     -- the pending debounce, an AceTimer handle
local active = false
local bankOpen = false
local bankSet       -- [bagID] = true for the character bank's containers, built lazily

-- What the last sync saw: [slotName] = plain link or "", and [bag] = { [slot] = plain link or "" }.
local seenWorn, seenBags, seenRange = {}, {}, nil
local live          -- the module's cache, nil until first asked for

-- ── the bag range ─────────────────────────────────────────────────────────────────────────────

-- The last equipped bag: the reagent bag, NUM_TOTAL_EQUIPPED_BAG_SLOTS read through the Compat seam
-- (as the legacy addon read it), 5 when the client has no such constant.
local REAGENT_FALLBACK = 5
local function lastEquippedBag()
    return Compat.LastEquippedBagID() or REAGENT_FALLBACK
end

--- The bags the scan reads: 0 through the reagent bag, plus the character bank while it is open.
--- @return number[]
function Inv.BagIDs()
    local out = {}
    for bag = 0, lastEquippedBag() do out[#out + 1] = bag end
    if bankOpen then
        for _, bag in ipairs(Compat.BankBagIDs()) do out[#out + 1] = bag end
    end
    return out
end

local function buildBankSet()
    bankSet = {}
    for _, bag in ipairs(Compat.BankBagIDs()) do bankSet[bag] = true end
end

--- Whether a container is one of the character bank's (not a carried bag, not a warband tab).
--- @param bag any
--- @return boolean
function Inv.IsBankBag(bag)
    if not bankSet then buildBankSet() end
    return bag ~= nil and bankSet[bag] == true
end

--- Whether the bank frame is open (its contents are readable and in the scan).
--- @return boolean
function Inv.BankOpen()
    return bankOpen
end

-- ── the cache ─────────────────────────────────────────────────────────────────────────────────

local Cache = {}
Cache.__index = Cache

-- Rebuild the indexes from the parts: `all` in scan order (worn first, then the bags in range),
-- `byID[id]` in the same order, and `worn[slotName]`.
local function reindex(c)
    local all, byID, worn = {}, {}, {}
    for _, key in ipairs(c.order) do
        for _, info in ipairs(c.parts[key] or {}) do
            all[#all + 1] = info
            local family = byID[info.id]
            if not family then
                family = {}
                byID[info.id] = family
            end
            family[#family + 1] = info
            if info.loc and info.loc.slotName then worn[info.loc.slotName] = info end
        end
    end
    c.all, c.byID, c.worn, c.stale = all, byID, worn, false
end

local function newCache(order, parts)
    local c = setmetatable({ order = order, parts = parts }, Cache)
    reindex(c)
    return c
end

--- A cache over a given list of infos (each with a `loc`), outside the scan: the pure planner's and
--- the suites' way to match against a known inventory.
--- @param infos table[]
--- @return table cache
function Inv.NewCache(infos)
    return newCache({ "list" }, { list = infos or {} })
end

local function scanWorn()
    local out = {}
    for _, slotName in ipairs(NS.ItemData.SLOT_NAMES) do
        local info = NS.ItemInfo.FromSlot(slotName)
        if info and info.slot and info.id ~= 0 then out[#out + 1] = info end
    end
    return out
end

-- Bag gear an outfit can hold: it goes in a slot and is not an unbound BoE (the min-level check off).
local function admitBagItem(info)
    return info ~= nil and info.slot ~= nil and info.id ~= 0 and NS.ItemInfo.Bind(info) ~= "boe"
end

local function scanBag(bag)
    local out = {}
    for slot = 1, Compat.ContainerNumSlots(bag) do
        local info = NS.ItemInfo.FromBag(bag, slot)
        if admitBagItem(info) then out[#out + 1] = info end
    end
    return out
end

-- The scan order: the worn slots, then the bags in range.
local function scanOrder()
    local order = { "worn" }
    for _, bag in ipairs(Inv.BagIDs()) do order[#order + 1] = bag end
    return order
end

-- Bring the module cache up to date: drop parts that left the range, scan the missing ones.
local function refresh(c)
    local order = scanOrder()
    local want = {}
    for _, key in ipairs(order) do want[key] = true end
    for key in pairs(c.parts) do
        if not want[key] then
            c.parts[key] = nil
            c.stale = true
        end
    end
    for _, key in ipairs(order) do
        if not c.parts[key] then
            c.parts[key] = (key == "worn") and scanWorn() or scanBag(key)
            c.stale = true
        end
    end
    c.order = order
    if c.stale then reindex(c) end
end

--- The inventory cache, current: the worn gear and the bag gear outfits can hold (see the header).
--- Ask for it each time: a flush rebuilds it lazily on the next call.
--- @return table cache
function Inv.Cache()
    if not live then live = setmetatable({ order = {}, parts = {}, stale = true }, Cache) end
    refresh(live)
    return live
end

local function flushPart(key)
    if live and live.parts[key] then
        live.parts[key] = nil
        live.stale = true
    end
end

--- Drop the whole cache; the next Inv.Cache() rebuilds it (PEW, GET_ITEM_INFO_RECEIVED).
function Inv.Flush()
    live = nil
end

--- A new matching pass: its claims live in `pass.claimed[info]` and nowhere else (B9).
--- @return table pass
function Cache.BeginPass(_)
    return { claimed = {} }
end

local function suffixOf(item) return item.suffix or 0 end

-- How `info` matches `item`: "exact", "partial" (same id and suffix, other fields differ) or nil.
-- A wildcard query with no suffix takes the first copy of the id as exact (the legacy SubCode
-- wildcard).
local function classify(info, item, wildcard)
    if wildcard and item.suffix == nil then return "exact" end
    if suffixOf(info) ~= suffixOf(item) then return nil end
    if NS.ItemInfo.Exact(info, item) then return "exact" end
    return "partial"
end

local function claim(pass, info, opts)
    if pass and not (opts and opts.peek) then pass.claimed[info] = true end
    return info
end

--- The cached copy of `item` (an info or an ItemRecord), or nil. The first exact unclaimed copy
--- wins; else the ONLY unclaimed partial one (same id and suffix). With a pass, the copy found is
--- claimed in it (unless opts.peek) and claimed copies are skipped; the second answer is then a
--- claimed copy that would have matched, or nil.
--- @param item table
--- @param pass table|nil  from cache:BeginPass()
--- @param opts table|nil  { wildcard = any suffix when item.suffix is nil, peek = do not claim }
--- @return table|nil info
--- @return table|nil claimedDup
function Cache:Find(item, pass, opts)
    local family = item and self.byID[item.id]
    if not family then return nil end
    local wildcard = opts and opts.wildcard
    local claimed = pass and pass.claimed
    local partial, partials, dup = nil, 0, nil
    for _, info in ipairs(family) do
        local kind = classify(info, item, wildcard)
        if kind and claimed and claimed[info] then
            if kind == "exact" or not dup then dup = info end
        elseif kind == "exact" then
            return claim(pass, info, opts)
        elseif kind then
            partial, partials = info, partials + 1
        end
    end
    if partials == 1 then return claim(pass, partial, opts) end
    return nil, dup
end

--- Find, then the item's alias (ALIASES, any suffix) when the item itself is not there.
--- @return table|nil info
--- @return table|nil claimedDup
function Cache:FindOrAlt(item, pass, opts)
    local info, dup = self:Find(item, pass, opts)
    if info then return info end
    local alt = item and NS.ItemData.ALIASES[item.id]
    if not alt then return nil, dup end
    return self:Find({ id = alt }, pass, { wildcard = true, peek = opts and opts.peek })
end

local function collect(family, item, wildcard, out)
    for _, info in ipairs(family or {}) do
        if (wildcard and item.suffix == nil) or suffixOf(info) == suffixOf(item) then out[#out + 1] = info end
    end
end

--- Every cached copy of `item` with its suffix (any suffix under `wildcard`), then every copy of
--- its alias. No claims.
--- @param item table
--- @param wildcard boolean|nil
--- @return table[]
function Cache:FindAll(item, wildcard)
    local out = {}
    if not item then return out end
    collect(self.byID[item.id], item, wildcard, out)
    local alt = NS.ItemData.ALIASES[item.id]
    if alt then collect(self.byID[alt], { id = alt }, true, out) end
    return out
end

--- Whether two items (records or infos) are the same item, as the legacy ItemsAreSame answered it
--- (OutfitterInventory.lua:1234-1308), with the exact test unified with Find's (diff, mods and
--- azerite included): one owned copy (or an aliased pair) is the same whatever its fields; several
--- copies must match exactly.
--- @return boolean
function Cache:Same(a, b)
    if a == nil or b == nil then return a == nil and b == nil end
    if a.id == 0 then return b.id == 0 end
    if not NS.ItemInfo.SameIdentity(a, b) then return false end
    local n = #self:FindAll(a)
    if n == 0 then return false end
    if n == 1 or NS.ItemData.ALIASES[a.id] then return true end
    return NS.ItemInfo.Exact(a, b)
end

--- Whether the worn slot holds `item` (OutfitterInventory.lua:1310): the empty marker wants an empty
--- slot; one owned copy needs only to be in the slot; with several, the one in the slot must be exact.
--- @return boolean
--- @return table|nil info  the copy found in the slot
function Cache:SlotHas(slotName, item)
    if item == nil then return false end
    if item.id == 0 then return self.worn[slotName] == nil end
    local copies = self:FindAll(item)
    if #copies == 1 then
        local only = copies[1]
        return only.loc ~= nil and only.loc.slotName == slotName, only
    end
    for _, info in ipairs(copies) do
        if info.loc and info.loc.slotName == slotName then return NS.ItemInfo.Exact(info, item), info end
    end
    return false
end

-- ── the scan ──────────────────────────────────────────────────────────────────────────────────

-- The link as the snapshot keeps it. Compat's link reads are already plain-or-nil (a secret link is
-- nil there), so an empty and a secret slot both read "" (Q12).
local function plainLink(link)
    return link or ""
end

local function syncWorn()
    local changed = false
    for _, slotName in ipairs(NS.ItemData.SLOT_NAMES) do
        local slotID = Compat.InventorySlotID(slotName)
        local link = plainLink(slotID and Compat.InventoryItemLink(slotID))
        if seenWorn[slotName] ~= link then
            seenWorn[slotName] = link
            changed = true
        end
    end
    if changed then flushPart("worn") end
    return changed
end

local function syncBag(bag)
    local seen = seenBags[bag]
    local n = Compat.ContainerNumSlots(bag)
    local changed = false
    if not seen or #seen ~= n then
        seen = {}
        seenBags[bag] = seen
        changed = true
    end
    for slot = 1, n do
        local link = plainLink(Compat.ContainerItemLink(bag, slot))
        if seen[slot] ~= link then
            seen[slot] = link
            changed = true
        end
    end
    if changed then flushPart(bag) end
    return changed
end

-- A change in the bag range (the bank opened or closed) is a bag change; a bag that left the range
-- is forgotten, so it reads as changed when it comes back.
local function syncRange(bags)
    local key = table.concat(bags, ",")
    if key == seenRange then return false end
    seenRange = key
    local keep = {}
    for _, bag in ipairs(bags) do keep[bag] = true end
    for bag in pairs(seenBags) do
        if not keep[bag] then seenBags[bag] = nil end
    end
    return true
end

--- Compare the worn slots and the bags with the last scan, flush what changed, and announce it.
--- @return boolean any
--- @return boolean equippedChanged
--- @return boolean bagsChanged
function Inv.Sync()
    local Perf = NS.Perf
    local t0 = Perf.on and debugprofilestop()
    local worn = syncWorn()
    local bags = Inv.BagIDs()
    local bagsChanged = syncRange(bags)
    for _, bag in ipairs(bags) do
        if syncBag(bag) then bagsChanged = true end
    end
    if worn or bagsChanged then NS.SendBus(NS.MSG.INVENTORY_CHANGED, worn, bagsChanged) end
    if t0 then Perf.Note("bagSync", debugprofilestop() - t0) end
    return worn or bagsChanged, worn, bagsChanged
end

local function runSync()
    syncTimer = nil
    if NS.IsStoodDown() then return end
    Inv.Sync()
end

--- Schedule a sync 0.01 s out, canceling the pending one. Nothing while the module is suspended.
function Inv.ScheduleSync()
    if not active or NS.IsStoodDown() then return end
    if syncTimer then events:CancelTimer(syncTimer) end
    syncTimer = events:ScheduleTimer(runSync, SYNC_DELAY)
end

-- ── the events ────────────────────────────────────────────────────────────────────────────────

local function setBank(open)
    if bankOpen == open then return end
    bankOpen = open
    buildBankSet()
    Inv.ScheduleSync()
end

local function onWorld()
    Inv.Flush()
    Inv.ScheduleSync()
end

-- The scan events: each only schedules a sync, and only outside a load.
local SCAN = { BAG_UPDATE = true, BAG_UPDATE_DELAYED = true, PLAYERBANKSLOTS_CHANGED = true }

local ON = {
    PLAYER_ENTERING_WORLD = onWorld,
    GET_ITEM_INFO_RECEIVED = function() Inv.Flush() end,
    BANKFRAME_OPENED = function() setBank(true) end,
    BANKFRAME_CLOSED = function() setBank(false) end,
    PLAYER_INTERACTION_MANAGER_FRAME_SHOW = function(kind)
        if Compat.IsBankerInteraction(kind) then setBank(true) end
    end,
    PLAYER_INTERACTION_MANAGER_FRAME_HIDE = function(kind)
        if Compat.IsBankerInteraction(kind) then setBank(false) end
    end,
}

local EVENT_NAMES = { "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYER_ENTERING_WORLD",
                      "GET_ITEM_INFO_RECEIVED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
                      "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }

local function scanEvent()
    if NS.Equip.SuspendedForLoad() then return end
    Inv.ScheduleSync()
end

local function onEvent(event, ...)
    if NS.IsStoodDown() then return end
    if SCAN[event] then return scanEvent() end
    local fn = ON[event]
    if fn then fn(...) end
end

local function onUnitEvent(_, _, unit)
    if NS.IsStoodDown() or unit ~= "player" then return end
    scanEvent()
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

local function ensureRegistrants()
    if not events then
        events = LibStub("AceEvent-3.0"):Embed({})
        LibStub("AceTimer-3.0"):Embed(events)
    end
    if not unitFrame then
        unitFrame = CreateFrame("Frame")
        unitFrame:Hide()
        unitFrame:SetScript("OnEvent", onUnitEvent)
    end
end

--- The lifecycle's stand-down (design §5.12): every registration and the pending sync go, and the
--- bank reads as closed. No BANKFRAME_CLOSED is heard while down, so a bank open at the stand-down
--- would otherwise stay in the scan after it closed; failing closed, the next open reopens it.
function Inv.Suspend()
    active = false
    bankOpen = false
    if events then
        events:UnregisterAllEvents()
        if syncTimer then events:CancelTimer(syncTimer) end
    end
    syncTimer = nil
    if unitFrame then unitFrame:UnregisterAllEvents() end
    Inv.Flush()
end

--- The stand-up: register from scratch, flush, and schedule a sync from the client's current state.
function Inv.Resume()
    ensureRegistrants()
    Inv.Suspend()
    for _, event in ipairs(EVENT_NAMES) do
        NS.SafeRegisterEvent(events, event, onEvent, NS.rejectedEvents)
    end
    NS.SafeRegisterUnitEvent(unitFrame, "UNIT_INVENTORY_CHANGED", NS.rejectedEvents, "player")
    active = true
    Inv.Flush()
    Inv.ScheduleSync()
end
